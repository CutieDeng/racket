#lang racket/base
;; PKCS#12 (PFX) loading — RFC 7292. Parses the common OpenSSL/LibreSSL layout
;; (PKCS12-KDF over SHA-1 with pbeWithSHA1And3-KeyTripleDES / pbeWithSHA1And40BitRC2
;; bags, plus PBES2 shrouded keys) and returns the private key + certificate chain.
;; Verifies the SHA-1 HMAC MacData before trusting any content.
(require racket/list
         "rktcrypto-der.rkt"
         "rktcrypto-ffi.rkt"
         (only-in "rktcrypto-x509.rkt" pkcs8->key))
(provide pkcs12-parse)

(define RKT-SHA1 14)

;; ---- OIDs ----
(define oid-data           #"\x2a\x86\x48\x86\xf7\x0d\x01\x07\x01")
(define oid-encrypted-data #"\x2a\x86\x48\x86\xf7\x0d\x01\x07\x06")
(define oid-shrouded-key   #"\x2a\x86\x48\x86\xf7\x0d\x01\x0c\x0a\x01\x02")
(define oid-cert-bag       #"\x2a\x86\x48\x86\xf7\x0d\x01\x0c\x0a\x01\x03")
(define oid-keybag         #"\x2a\x86\x48\x86\xf7\x0d\x01\x0c\x0a\x01\x01")
(define oid-pbe-3des       #"\x2a\x86\x48\x86\xf7\x0d\x01\x0c\x01\x03") ; pbeWithSHA1And3-KeyTripleDES-CBC
(define oid-pbe-rc2-40     #"\x2a\x86\x48\x86\xf7\x0d\x01\x0c\x01\x06") ; pbeWithSHA1And40BitRC2-CBC
(define oid-pbes2          #"\x2a\x86\x48\x86\xf7\x0d\x01\x05\x0d")
(define oid-pbkdf2         #"\x2a\x86\x48\x86\xf7\x0d\x01\x05\x0c")
(define oid-aes128-cbc     #"\x60\x86\x48\x01\x65\x03\x04\x01\x02")
(define oid-aes192-cbc     #"\x60\x86\x48\x01\x65\x03\x04\x01\x16")
(define oid-aes256-cbc     #"\x60\x86\x48\x01\x65\x03\x04\x01\x2a")

;; ---- password as a BMPString (UTF-16BE + 0x0000 terminator) ----
(define (str->bmp s)
  (define bs (if (bytes? s) s (string->bytes/utf-8 s)))
  (bytes-append (apply bytes-append (for/list ([c (in-bytes bs)]) (bytes 0 c))) (bytes 0 0)))

;; ---- PKCS#12 KDF (RFC 7292 Appendix B.2) ----
(define (build-repeat src len)
  (if (zero? (bytes-length src)) (make-bytes len 0)
      (let ([o (make-bytes len)])
        (for ([i (in-range len)]) (bytes-set! o i (bytes-ref src (modulo i (bytes-length src)))))
        o)))
(define (bytes->uint bs)
  (for/fold ([a 0]) ([b (in-bytes bs)]) (+ (* a 256) b)))
(define (uint->bytes v nbytes)
  (define o (make-bytes nbytes))
  (let loop ([i (sub1 nbytes)] [x v])
    (when (>= i 0) (bytes-set! o i (bitwise-and x 255)) (loop (sub1 i) (arithmetic-shift x -8))))
  o)
;; per RFC B.2 step 6c: I_j = (I_j + B + 1) mod 2^(8v) for each v-byte block
(define (pkcs12-I+B+1 I B v)
  (define inc (add1 (bytes->uint B)))
  (define m (arithmetic-shift 1 (* 8 v)))
  (apply bytes-append
         (for/list ([off (in-range 0 (bytes-length I) v)])
           (uint->bytes (modulo (+ (bytes->uint (subbytes I off (+ off v))) inc) m) v))))
(define (pkcs12-kdf halg id pw salt iters n)
  (define u (digest-size halg))
  (define v (if (memv halg (list SHA384 SHA512)) 128 64))   ; SHA1/224/256 block = 64
  (define D (make-bytes v id))
  (define S (build-repeat salt (* v (quotient (+ (bytes-length salt) v -1) (max 1 v)))))
  (define P (build-repeat pw   (* v (quotient (+ (bytes-length pw)   v -1) (max 1 v)))))
  (define out (make-bytes n))
  (let loop ([produced 0] [I (bytes-append S P)])
    (cond
      [(>= produced n) (subbytes out 0 n)]
      [else
       (define A (let it ([i 0] [a (bytes-append D I)])
                   (if (>= i iters) a (it (add1 i) (digest halg a)))))
       (bytes-copy! out produced A 0 (min u (- n produced)))
       (if (>= (+ produced u) n)
           (subbytes out 0 n)
           (loop (+ produced u) (pkcs12-I+B+1 I (build-repeat A v) v)))])))

;; ---- padding ----
(define (unpad bs block)
  (define n (bytes-ref bs (sub1 (bytes-length bs))))
  (unless (and (>= n 1) (<= n block) (<= n (bytes-length bs))
               (for/and ([i (in-range (- (bytes-length bs) n) (bytes-length bs))]) (= (bytes-ref bs i) n)))
    (error 'pkcs12 "bad padding (wrong password?)"))
  (subbytes bs 0 (- (bytes-length bs) n)))

;; ---- PBE decrypt (legacy PKCS#12 PBE, or PBES2) given an AlgorithmIdentifier ----
(define (pbe-decrypt alg-node password ct)
  (define ak (der-children alg-node))
  (define oid (car ak))
  (define pw-bmp (str->bmp password))
  (cond
    [(or (der-oid=? oid oid-pbe-3des) (der-oid=? oid oid-pbe-rc2-40))
     (define params (der-children (cadr ak)))           ; pkcs-12PbeParams { salt, iter }
     (define salt (der-content (car params)))
     (define iters (der-uint (cadr params)))
     (define 3des? (der-oid=? oid oid-pbe-3des))
     (define keylen (if 3des? 24 5))
     (define key (pkcs12-kdf RKT-SHA1 1 pw-bmp salt iters keylen))
     (define iv  (pkcs12-kdf RKT-SHA1 2 pw-bmp salt iters 8))
     (define out (make-bytes (bytes-length ct)))
     (if 3des?
         (rktcrypto_des3_cbc key iv ct out (quotient (bytes-length ct) 8) 0)
         (rktcrypto_rc2_cbc key keylen 40 iv ct out (quotient (bytes-length ct) 8) 0))
     (unpad out 8)]
    [(der-oid=? oid oid-pbes2) (pbes2-decrypt (cadr ak) pw-bmp password ct)]
    [else (error 'pkcs12 "unsupported PKCS#12 bag encryption ~a" (bytes->oid-string (der-content oid)))]))

;; PBES2 (PBKDF2 + AES-CBC) used by newer shrouded keys.
(define (pbes2-decrypt params-node pw-bmp password ct)
  (define params (der-children params-node))            ; [kdf, enc]
  (define kdf (der-children (car params)))
  (define pk (der-children (cadr kdf)))                  ; [salt, iter, ...]
  (define salt (der-content (car pk)))
  (define iters (der-uint (cadr pk)))
  (define enc (der-children (cadr params)))             ; [enc-oid, iv]
  (define enc-oid (car enc))
  (define keylen (cond [(der-oid=? enc-oid oid-aes128-cbc) 16]
                       [(der-oid=? enc-oid oid-aes192-cbc) 24]
                       [(der-oid=? enc-oid oid-aes256-cbc) 32]
                       [else (error 'pkcs12 "unsupported PBES2 scheme")]))
  (define iv (der-content (cadr enc)))
  (define pw (if (bytes? password) password (string->bytes/utf-8 password)))
  (define dk (make-bytes keylen))
  (unless (eqv? 1 (rktcrypto_pbkdf2 SHA256 pw (bytes-length pw) salt (bytes-length salt) iters dk keylen))
    (error 'pkcs12 "PBKDF2 failed"))
  (define out (make-bytes (bytes-length ct)))
  (rktcrypto_aes_cbc_decrypt dk keylen iv ct out (bytes-length ct))
  (unpad out 16))

;; ---- bag walking ----
;; returns (values key-or-#f  (listof cert-der))
(define (walk-safe-contents sc-der password)
  (define bags (der-children (der-read sc-der)))
  (for/fold ([key #f] [certs '()]) ([bag (in-list bags)])
    (define bk (der-children bag))
    (define bag-oid (car bk))
    (define bag-value (der-explicit (cadr bk)))          ; [0] EXPLICIT -> inner TLV node
    (cond
      [(der-oid=? bag-oid oid-keybag)
       ;; der-content of the [0] wrapper is exactly the inner PrivateKeyInfo TLV
       (values (pkcs8->key (der-content (cadr bk))) certs)]
      [(der-oid=? bag-oid oid-shrouded-key)
       ;; EncryptedPrivateKeyInfo { AlgorithmIdentifier, OCTET STRING }
       (define kids (der-children bag-value))
       (define pt (pbe-decrypt (car kids) password (der-content (cadr kids))))
       (values (pkcs8->key pt) certs)]
      [(der-oid=? bag-oid oid-cert-bag)
       ;; CertBag { certId, [0] EXPLICIT OCTET STRING }
       (define cb (der-children bag-value))
       (define cert (der-content (der-explicit (cadr cb))))
       (values key (append certs (list cert)))]
      [else (values key certs)])))            ; ignore secretBag/safeContentsBag/etc.

(define (content-info->safecontents ci password)
  (define k (der-children ci))
  (define oid (car k))
  (cond
    [(der-oid=? oid oid-data)
     (der-content (der-explicit (cadr k)))]              ; [0] EXPLICIT OCTET STRING -> SafeContents
    [(der-oid=? oid oid-encrypted-data)
     ;; [0] EXPLICIT EncryptedData { version, EncryptedContentInfo }
     (define ed (der-children (der-explicit (cadr k))))
     (define eci (der-children (cadr ed)))               ; { contentType, algId, [0] IMPLICIT encContent }
     (pbe-decrypt (cadr eci) password (der-content (caddr eci)))]
    [else #f]))

(define (verify-mac mac-data authsafe-content password)
  (define md (der-children mac-data))                    ; { DigestInfo, macSalt, iter }
  (define di (der-children (car md)))                    ; { AlgorithmIdentifier, OCTET STRING }
  (define mac (der-content (cadr di)))
  (define salt (der-content (cadr md)))
  (define iters (if (>= (length md) 3) (der-uint (caddr md)) 1))
  (define key (pkcs12-kdf RKT-SHA1 3 (str->bmp password) salt iters 20))
  (define expected (hmac RKT-SHA1 key authsafe-content))
  (unless (equal? expected mac) (error 'pkcs12 "MAC verification failed (wrong password?)")))

;; PFX -> (values key (listof cert-der))
(define (pkcs12-parse der password)
  (define pfx (der-children (der-read der)))
  (define authsafe-ci (der-children (cadr pfx)))
  (define authsafe-content (der-content (der-explicit (cadr authsafe-ci)))) ; AuthenticatedSafe DER
  (when (>= (length pfx) 3) (verify-mac (caddr pfx) authsafe-content password))
  (define safes (der-children (der-read authsafe-content)))
  (for/fold ([key #f] [certs '()] #:result (values key certs)) ([ci (in-list safes)])
    (define sc (content-info->safecontents ci password))
    (if sc
        (let-values ([(k cs) (walk-safe-contents sc password)])
          (values (or k key) (append certs cs)))
        (values key certs))))
