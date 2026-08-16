#lang racket/base

;; X.509 certificate parsing on top of the DER reader. Extracts everything
;; the TLS backend needs: the exact TBSCertificate span (handed to the C
;; signature verifier without copying), the signature algorithm and value,
;; the SubjectPublicKeyInfo (algorithm + key material), validity window,
;; subject/issuer DNs, and the extensions that matter for path validation
;; (basicConstraints, keyUsage, extendedKeyUsage, subjectAltName). Signature
;; verification and hostname matching live in rktcrypto-verify.rkt.

(require "rktcrypto-der.rkt"
         "rktcrypto-ffi.rkt"
         racket/string)

(provide (struct-out certificate)
         (struct-out pubkey)
         parse-certificate
         pem->der-list
         cert-signature-inputs)

;; A parsed certificate. `der` is the whole certificate; `tbs-start`/
;; `tbs-end` bound its TBSCertificate for signature verification.
(struct certificate
  (der tbs-start tbs-end
   sig-alg          ; symbol: 'rsa-pkcs1 'rsa-pss 'ecdsa 'ed25519 (+ digest in sig-digest)
   sig-digest       ; 'sha256 'sha384 'sha512 or #f
   signature        ; bytes (BIT STRING content, unused-bits octet dropped)
   pub              ; pubkey
   not-before not-after   ; strings (UTCTime/GeneralizedTime raw)
   subject issuer   ; assoc lists of (oid-string . string)
   san-dns          ; list of dNSName strings
   is-ca            ; boolean (basicConstraints CA)
   path-len         ; integer or #f
   key-usage        ; list of symbols or #f
   eku)             ; list of oid-strings or #f
  #:transparent)

;; Public key: type is 'rsa 'ec 'ed25519; for RSA (n . e) big-endian
;; bytes; for EC the named curve symbol and the 0x04||x||y point bytes.
(struct pubkey (type rsa-n rsa-e ec-curve ec-point) #:transparent)

;; ---- OID constants ----
(define oid-rsa-encryption #"\x2a\x86\x48\x86\xf7\x0d\x01\x01\x01")
(define oid-rsassa-pss     #"\x2a\x86\x48\x86\xf7\x0d\x01\x01\x0a")
(define oid-sha256-rsa     #"\x2a\x86\x48\x86\xf7\x0d\x01\x01\x0b")
(define oid-sha384-rsa     #"\x2a\x86\x48\x86\xf7\x0d\x01\x01\x0c")
(define oid-sha512-rsa     #"\x2a\x86\x48\x86\xf7\x0d\x01\x01\x0d")
(define oid-ec-pubkey      #"\x2a\x86\x48\xce\x3d\x02\x01")
(define oid-ecdsa-sha256   #"\x2a\x86\x48\xce\x3d\x04\x03\x02")
(define oid-ecdsa-sha384   #"\x2a\x86\x48\xce\x3d\x04\x03\x03")
(define oid-ecdsa-sha512   #"\x2a\x86\x48\xce\x3d\x04\x03\x04")
(define oid-ed25519        #"\x2b\x65\x70")
(define oid-p256           #"\x2a\x86\x48\xce\x3d\x03\x01\x07")
(define oid-p384           #"\x2b\x81\x04\x00\x22")
(define oid-p521           #"\x2b\x81\x04\x00\x23")
(define oid-cn             #"\x55\x04\x03")
(define oid-ext-san        #"\x55\x1d\x11")
(define oid-ext-bc         #"\x55\x1d\x13")
(define oid-ext-ku         #"\x55\x1d\x0f")
(define oid-ext-eku        #"\x55\x1d\x25")

(define (oid-symbol d)
  (cond
    [(der-oid=? d oid-sha256-rsa) (values 'rsa-pkcs1 'sha256)]
    [(der-oid=? d oid-sha384-rsa) (values 'rsa-pkcs1 'sha384)]
    [(der-oid=? d oid-sha512-rsa) (values 'rsa-pkcs1 'sha512)]
    [(der-oid=? d oid-rsassa-pss) (values 'rsa-pss #f)]  ; digest read from params
    [(der-oid=? d oid-ecdsa-sha256) (values 'ecdsa 'sha256)]
    [(der-oid=? d oid-ecdsa-sha384) (values 'ecdsa 'sha384)]
    [(der-oid=? d oid-ecdsa-sha512) (values 'ecdsa 'sha512)]
    [(der-oid=? d oid-ed25519) (values 'ed25519 #f)]
    [else (values 'unknown #f)]))

;; Digest OID inside RSASSA-PSS-params (hashAlgorithm [0]).
(define oid-sha256 #"\x60\x86\x48\x01\x65\x03\x04\x02\x01")
(define oid-sha384 #"\x60\x86\x48\x01\x65\x03\x04\x02\x02")
(define oid-sha512 #"\x60\x86\x48\x01\x65\x03\x04\x02\x03")

(define (pss-digest algid-seq)
  ;; AlgorithmIdentifier { OID rsassa-pss, params SEQUENCE { [0] hashAlg ... } }
  (define kids (der-children algid-seq))
  (cond
    [(and (>= (length kids) 2) (= #x30 (der-tag (cadr kids))))
     (let ([params (der-children (cadr kids))])
       (let loop ([ps params])
         (cond
           [(null? ps) 'sha256]
           [(and (der-tag-context? (car ps)) (= 0 (der-tag-number (car ps))))
            (let* ([h (der-explicit (car ps))]
                   [hoid (car (der-children h))])
              (cond [(der-oid=? hoid oid-sha384) 'sha384]
                    [(der-oid=? hoid oid-sha512) 'sha512]
                    [else 'sha256]))]
           [else (loop (cdr ps))])))]
    [else 'sha256]))

(define (parse-name seq)
  ;; Name ::= SEQUENCE OF RelativeDistinguishedName (SET OF AttrTypeAndValue)
  (for*/list ([rdn (in-list (der-children seq))]
              [atv (in-list (der-children rdn))])
    (define kids (der-children atv))
    (cons (bytes->oid-string (car kids))
          (subbytes (der-bytes (cadr kids)) (der-start (cadr kids)) (der-end (cadr kids))))))

(define (name->string name-alist)
  ;; A readable RFC2253-ish rendering, CN first.
  (string-join
   (for/list ([kv (in-list name-alist)])
     (string-append (attr-short (car kv)) "=" (bytes->string/latin-1 (cdr kv))))
   ", "))

(define (attr-short oid)
  (cond [(string=? oid "2.5.4.3") "CN"]
        [(string=? oid "2.5.4.10") "O"]
        [(string=? oid "2.5.4.11") "OU"]
        [(string=? oid "2.5.4.6") "C"]
        [(string=? oid "2.5.4.7") "L"]
        [(string=? oid "2.5.4.8") "ST"]
        [else oid]))

(define (bit-string-content d)
  ;; drop the leading unused-bits octet
  (subbytes (der-bytes d) (add1 (der-start d)) (der-end d)))

(define (parse-spki spki)
  (define kids (der-children spki))
  (define alg (car kids))
  (define key-bits (cadr kids))
  (define alg-oid (car (der-children alg)))
  (cond
    [(der-oid=? alg-oid oid-rsa-encryption)
     (define rsa (der-read (bit-string-content key-bits)))
     (define rk (der-children rsa))
     (define n (trim-int (int-bytes (car rk))))
     (define e (trim-int (int-bytes (cadr rk))))
     (pubkey 'rsa n e #f #f)]
    [(der-oid=? alg-oid oid-ec-pubkey)
     (define curve
       (let ([params (cadr (der-children alg))])
         (cond [(der-oid=? params oid-p256) 'p256]
               [(der-oid=? params oid-p384) 'p384]
               [(der-oid=? params oid-p521) 'p521]
               [else 'unknown])))
     (pubkey 'ec #f #f curve (bit-string-content key-bits))]
    [(der-oid=? alg-oid oid-ed25519)
     (pubkey 'ed25519 #f #f #f (bit-string-content key-bits))]
    [else (pubkey 'unknown #f #f #f #f)]))

(define (int-bytes d) (subbytes (der-bytes d) (der-start d) (der-end d)))
(define (trim-int bs)
  (let loop ([i 0])
    (if (and (< i (sub1 (bytes-length bs))) (zero? (bytes-ref bs i)))
        (loop (add1 i))
        (subbytes bs i))))

(define (parse-extensions ext-explicit)
  ;; ext-explicit is the [3] EXPLICIT wrapper; inside is SEQUENCE OF Extension
  (define seq (der-explicit ext-explicit))
  (define san '()) (define is-ca #f) (define path-len #f)
  (define ku #f) (define eku #f)
  (for ([ext (in-list (der-children seq))])
    (define kids (der-children ext))
    (define oid (car kids))
    ;; optional critical BOOLEAN then OCTET STRING
    (define val-oct (if (= #x01 (der-tag (cadr kids))) (caddr kids) (cadr kids)))
    (define val (der-read (subbytes (der-bytes val-oct) (der-start val-oct) (der-end val-oct))))
    (cond
      [(der-oid=? oid oid-ext-san)
       (set! san (for/list ([gn (in-list (der-children val))]
                            #:when (and (der-tag-context? gn) (= 2 (der-tag-number gn))))
                   (bytes->string/latin-1 (der-content gn))))]
      [(der-oid=? oid oid-ext-bc)
       (define bkids (der-children val))
       (when (and (pair? bkids) (= #x01 (der-tag (car bkids))))
         (set! is-ca (not (zero? (bytes-ref (der-bytes (car bkids)) (der-start (car bkids)))))))
       (for ([k (in-list bkids)] #:when (= #x02 (der-tag k)))
         (set! path-len (der-uint k)))]
      [(der-oid=? oid oid-ext-ku)
       (set! ku (parse-key-usage val))]
      [(der-oid=? oid oid-ext-eku)
       (set! eku (for/list ([o (in-list (der-children val))]) (bytes->oid-string o)))]))
  (values san is-ca path-len ku eku))

(define ku-bits '(digital-signature non-repudiation key-encipherment
                  data-encipherment key-agreement key-cert-sign
                  crl-sign encipher-only decipher-only))
(define (parse-key-usage bitstr)
  ;; BIT STRING: first content octet = unused bits, then the bits MSB-first
  (define bs (der-bytes bitstr))
  (define start (add1 (der-start bitstr)))
  (for/list ([bit (in-naturals)]
             [name (in-list ku-bits)]
             #:when (let ([byte-i (+ start (quotient bit 8))])
                      (and (< byte-i (der-end bitstr))
                           (bitwise-bit-set? (bytes-ref bs byte-i) (- 7 (remainder bit 8))))))
    name))

;; Parses a DER certificate into a `certificate` struct.
(define (parse-certificate der-bytes*)
  (define cert (der-read der-bytes*))
  (define kids (der-children cert))
  (define tbs (car kids))
  (define sig-algid (cadr kids))
  (define sig-bits (caddr kids))
  (define tbs-kids (der-children tbs))
  ;; optional version [0]
  (define after-ver
    (if (and (pair? tbs-kids) (der-tag-context? (car tbs-kids))
             (= 0 (der-tag-number (car tbs-kids))))
        (cdr tbs-kids) tbs-kids))
  ;; serial, sigalg, issuer, validity, subject, spki, then optional [1][2][3]
  (define serial (car after-ver))
  (define _sig (cadr after-ver))
  (define issuer (caddr after-ver))
  (define validity (cadddr after-ver))
  (define subject (list-ref after-ver 4))
  (define spki (list-ref after-ver 5))
  (define rest (list-tail after-ver 6))
  (define val-kids (der-children validity))
  (define-values (sig-alg sig-digest0) (oid-symbol (car (der-children sig-algid))))
  (define sig-digest (if (eq? sig-alg 'rsa-pss) (pss-digest sig-algid) sig-digest0))
  (define-values (san is-ca path-len ku eku)
    (let ([ext (for/or ([r (in-list rest)]
                        #:when (and (der-tag-context? r) (= 3 (der-tag-number r)))) r)])
      (if ext (parse-extensions ext) (values '() #f #f #f #f))))
  (certificate
   der-bytes* (der-start cert) (der-end tbs)   ; full TBSCertificate TLV (tag..end)
   sig-alg sig-digest
   (bit-string-content sig-bits)
   (parse-spki spki)
   (raw-time (car val-kids)) (raw-time (cadr val-kids))
   (parse-name subject) (parse-name issuer)
   san is-ca path-len ku eku))

(define (raw-time d) (bytes->string/latin-1 (der-content d)))

;; Convenience: returns (values tbs-bytes sig-alg sig-digest signature).
(define (cert-signature-inputs c)
  (values (subbytes (certificate-der c) (certificate-tbs-start c) (certificate-tbs-end c))
          (certificate-sig-alg c) (certificate-sig-digest c) (certificate-signature c)))

;; Splits a PEM file (bytes) into a list of DER byte strings, one per
;; CERTIFICATE block (ignoring any private-key or other blocks). Uses the
;; C base64 decoder.
(define (pem->der-list pem [want #rx#"CERTIFICATE"])
  (define s (if (bytes? pem) pem (string->bytes/utf-8 pem)))
  (let loop ([pos 0] [acc '()])
    (define b (regexp-match-positions #rx#"-----BEGIN ([A-Z0-9 ]*)-----" s pos))
    (cond
      [(not b) (reverse acc)]
      [else
       (define label (subbytes s (caadr b) (cdadr b)))
       (define body-start (cdar b))
       (define e (regexp-match-positions #rx#"-----END [A-Z0-9 ]*-----" s body-start))
       (cond
         [(not e) (reverse acc)]
         [else
          (define keep? (and (regexp-match? want label)
                             (not (regexp-match? #rx#"PRIVATE" label))))
          (define der (and keep? (base64-decode (subbytes s body-start (caar e)))))
          (loop (cdar e) (if der (cons der acc) acc))])])))

(provide name->string)

;; Loads a private key from PEM bytes. Returns (cons type der/scalar):
;;   'rsa  -> PKCS#1 RSAPrivateKey DER (what rktcrypto_rsa_sign_msg wants)
;;   'p256 -> 32-byte raw private scalar
;; Handles "RSA PRIVATE KEY" (PKCS#1), "EC PRIVATE KEY" (SEC1), and
;; "PRIVATE KEY" (PKCS#8 wrapping either).
(define (pem->private-key pem [password #f])
  (define s (if (bytes? pem) pem (string->bytes/utf-8 pem)))
  (define m (regexp-match #rx#"-----BEGIN ([A-Z0-9 ]*PRIVATE KEY)-----(.*?)-----END" s))
  (unless m (error 'pem->private-key "no private key block found"))
  (define label (cadr m))
  (define der (base64-decode (caddr m)))
  (cond
    [(regexp-match? #rx#"ENCRYPTED PRIVATE KEY" label)           ; PKCS#8 PBES2
     (unless password (error 'pem->private-key "encrypted private key requires a password"))
     (pkcs8->key (decrypt-pkcs8-pbes2 der password))]
    [(regexp-match? #rx#"RSA PRIVATE KEY" label) (cons 'rsa der)]
    [(regexp-match? #rx#"EC PRIVATE KEY" label) (cons 'p256 (sec1-scalar der))]
    [else (pkcs8->key der)]))

;; SEC1 ECPrivateKey ::= SEQUENCE { version INTEGER, privateKey OCTET STRING, ... }
(define (sec1-scalar der)
  (define kids (der-children (der-read der)))
  (define oct (cadr kids))
  (define raw (der-content oct))
  (if (< (bytes-length raw) 32)
      (bytes-append (make-bytes (- 32 (bytes-length raw)) 0) raw)
      raw))

;; PKCS#8 PrivateKeyInfo ::= SEQUENCE { version, algId SEQ{OID..}, key OCTET STRING }
(define (pkcs8->key der)
  (define kids (der-children (der-read der)))
  (define algid (cadr kids))
  (define alg-oid (car (der-children algid)))
  (define inner (der-content (caddr kids)))
  (cond
    [(der-oid=? alg-oid oid-rsa-encryption) (cons 'rsa inner)]
    [(der-oid=? alg-oid oid-ec-pubkey) (cons 'p256 (sec1-scalar inner))]
    [else (error 'pem->private-key "unsupported PKCS#8 key algorithm")]))

;; ---- Encrypted PKCS#8 (PBES2 = PBKDF2 + AES-CBC), RFC 8018 §6.2 ----
;;   EncryptedPrivateKeyInfo ::= SEQUENCE { encAlg AlgorithmIdentifier, encData OCTET STRING }
;;   PBES2-params ::= SEQUENCE { keyDerivationFunc(PBKDF2), encryptionScheme(AES-CBC) }
;;   PBKDF2-params ::= SEQUENCE { salt OCTET STRING, iter INTEGER, [keyLen INTEGER], [prf SEQ] }
(define oid-pbes2       #"\x2a\x86\x48\x86\xf7\x0d\x01\x05\x0d") ; 1.2.840.113549.1.5.13
(define oid-pbkdf2      #"\x2a\x86\x48\x86\xf7\x0d\x01\x05\x0c") ; 1.2.840.113549.1.5.12
(define oid-aes128-cbc  #"\x60\x86\x48\x01\x65\x03\x04\x01\x02") ; 2.16.840.1.101.3.4.1.2
(define oid-aes192-cbc  #"\x60\x86\x48\x01\x65\x03\x04\x01\x16")
(define oid-aes256-cbc  #"\x60\x86\x48\x01\x65\x03\x04\x01\x2a")
(define oid-hmac-sha1   #"\x2a\x86\x48\x86\xf7\x0d\x02\x07") ; 1.2.840.113549.2.7
(define oid-hmac-sha256 #"\x2a\x86\x48\x86\xf7\x0d\x02\x09")
(define oid-hmac-sha384 #"\x2a\x86\x48\x86\xf7\x0d\x02\x0a")
(define oid-hmac-sha512 #"\x2a\x86\x48\x86\xf7\x0d\x02\x0b")
(define RKT-SHA1 14)                                          ; RKTCRYPTO_SHA1

(define (pbes2-prf->alg oid)
  (cond [(der-oid=? oid oid-hmac-sha256) SHA256]
        [(der-oid=? oid oid-hmac-sha384) SHA384]
        [(der-oid=? oid oid-hmac-sha512) SHA512]
        [(der-oid=? oid oid-hmac-sha1)   RKT-SHA1]
        [else (error 'pem->private-key "unsupported PBKDF2 PRF")]))
(define (pbes2-aes-keylen oid)
  (cond [(der-oid=? oid oid-aes128-cbc) 16]
        [(der-oid=? oid oid-aes192-cbc) 24]
        [(der-oid=? oid oid-aes256-cbc) 32]
        [else (error 'pem->private-key "unsupported PBES2 encryption scheme (only AES-CBC)")]))

(define (decrypt-pkcs8-pbes2 der password)
  (define kids (der-children (der-read der)))
  (define enc-alg (car kids))
  (define ct (der-content (cadr kids)))
  (define ea (der-children enc-alg))
  (unless (der-oid=? (car ea) oid-pbes2) (error 'pem->private-key "only PBES2 encrypted keys are supported"))
  (define params (der-children (cadr ea)))                  ; [kdf, enc]
  (define kdf (der-children (car params)))                  ; [oid-pbkdf2, pbkdf2-params]
  (unless (der-oid=? (car kdf) oid-pbkdf2) (error 'pem->private-key "only PBKDF2 key derivation is supported"))
  (define pk (der-children (cadr kdf)))                      ; [salt, iter, opt keyLen, opt prf]
  (define salt (der-content (car pk)))
  (define iters (der-uint (cadr pk)))
  (define rest (cddr pk))
  (define explicit-keylen (for/or ([c (in-list rest)] #:when (= #x02 (der-tag c))) (der-uint c)))
  (define prf-alg (let ([p (for/or ([c (in-list rest)] #:when (= #x30 (der-tag c))) c)])
                    (if p (pbes2-prf->alg (car (der-children p))) RKT-SHA1)))  ; default hmacWithSHA1
  (define enc (der-children (cadr params)))                 ; [enc-oid, iv]
  (define keylen (or explicit-keylen (pbes2-aes-keylen (car enc))))
  (define iv (der-content (cadr enc)))
  (define pw (if (bytes? password) password (string->bytes/utf-8 password)))
  (define dk (make-bytes keylen))
  (unless (eqv? 1 (rktcrypto_pbkdf2 prf-alg pw (bytes-length pw) salt (bytes-length salt) iters dk keylen))
    (error 'pem->private-key "PBKDF2 failed"))
  (define pt (make-bytes (bytes-length ct)))
  (rktcrypto_aes_cbc_decrypt dk keylen iv ct pt (bytes-length ct))
  ;; strip PKCS#7 padding — a wrong password almost always yields invalid padding
  (define n (bytes-ref pt (sub1 (bytes-length pt))))
  (unless (and (>= n 1) (<= n 16) (<= n (bytes-length pt))
               (for/and ([i (in-range (- (bytes-length pt) n) (bytes-length pt))]) (= (bytes-ref pt i) n)))
    (error 'pem->private-key "PKCS#8 decryption failed (wrong password?)"))
  (subbytes pt 0 (- (bytes-length pt) n)))

(provide pem->private-key pkcs8->key)
