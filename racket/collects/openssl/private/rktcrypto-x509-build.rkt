#lang racket/base

;; Minimal X.509 certificate construction (ECDSA P-256 / SHA-256) — enough to
;; issue a self-signed certificate from a freshly generated key, entirely on
;; librktcrypto (no OpenSSL). DER is encoded here; the key generation and
;; signature run in the C library.

(require "rktcrypto-ffi.rkt"
         "rktcrypto-der.rkt"
         racket/date
         racket/random)

(provide create-self-signed-certificate    ; -> (values cert-der ec-private-scalar-bytes)
         create-certificate                 ; CA-issued leaf -> (values cert-der ec-private-scalar-bytes)
         create-certificate-request         ; -> (values csr-der ec-private-scalar-bytes)
         ec-private-key->pem                ; 32-byte P-256 scalar -> SEC1 "EC PRIVATE KEY" PEM
         ec-private-key->pkcs8-pem)         ; ... -> PKCS#8 "PRIVATE KEY" PEM

;; ---- DER encoders ----
(define (der-len n)
  (cond [(< n 128) (bytes n)]
        [(< n 256) (bytes #x81 n)]
        [(< n 65536) (bytes #x82 (arithmetic-shift n -8) (bitwise-and n 255))]
        [else (bytes #x83 (bitwise-and (arithmetic-shift n -16) 255)
                     (bitwise-and (arithmetic-shift n -8) 255) (bitwise-and n 255))]))
(define (tlv tag c) (bytes-append (bytes tag) (der-len (bytes-length c)) c))
(define (d-seq . items) (tlv #x30 (apply bytes-append items)))
(define (d-set . items) (tlv #x31 (apply bytes-append items)))
(define (d-oid content) (tlv #x06 content))
(define (d-null) (bytes #x05 #x00))
(define (d-bitstring bs) (tlv #x03 (bytes-append (bytes 0) bs))) ; 0 unused bits
(define (d-int-bytes bs) ; INTEGER from big-endian magnitude bytes (prepend 0 if top bit set)
  (define b (let strip ([i 0]) (if (and (< i (sub1 (bytes-length bs))) (zero? (bytes-ref bs i))) (strip (add1 i)) (subbytes bs i))))
  (tlv #x02 (if (>= (bytes-ref b 0) #x80) (bytes-append (bytes 0) b) b)))
(define (d-int-small n) (tlv #x02 (bytes n)))
(define (d-utf8 s) (tlv #x0c (string->bytes/utf-8 s)))
(define (d-ia5 s) (tlv #x16 (string->bytes/latin-1 s)))
(define (d-utctime s) (tlv #x17 (string->bytes/latin-1 s)))
(define (d-ctx-explicit n c) (tlv (bitwise-ior #xA0 n) c))   ; [n] EXPLICIT (constructed)
(define (d-bool v) (tlv #x01 (bytes (if v #xff 0))))

;; ---- OIDs (content bytes) ----
(define oid-ec-pubkey    #"\x2a\x86\x48\xce\x3d\x02\x01")        ; 1.2.840.10045.2.1
(define oid-p256         #"\x2a\x86\x48\xce\x3d\x03\x01\x07")    ; prime256v1
(define oid-ecdsa-sha256 #"\x2a\x86\x48\xce\x3d\x04\x03\x02")    ; ecdsa-with-SHA256
(define oid-cn           #"\x55\x04\x03")                        ; 2.5.4.3
(define oid-san          #"\x55\x1d\x11")                        ; 2.5.29.17
(define oid-basic        #"\x55\x1d\x13")                        ; 2.5.29.19

(define (p256-priv)
  (let loop () (define k (crypto-random-bytes 32))
    (if (eqv? 1 (rktcrypto_p256_pubkey (make-bytes 65) k)) k (loop))))

;; raw r||s (32+32) -> DER SEQUENCE { INTEGER r, INTEGER s }
(define (raw->ecdsa-der raw)
  (d-seq (d-int-bytes (subbytes raw 0 32)) (d-int-bytes (subbytes raw 32 64))))

(define (secs->utctime s)
  (define d (seconds->date s #f))                    ; UTC
  (define (p2 n) (if (< n 10) (string-append "0" (number->string n)) (number->string n)))
  (string-append (p2 (modulo (date-year d) 100)) (p2 (date-month d)) (p2 (date-day d))
                 (p2 (date-hour d)) (p2 (date-minute d)) (p2 (date-second d)) "Z"))

;; base64 PEM wrapping
(define b64c "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")
(define (der->pem-body der label)
  (define n (bytes-length der)) (define o (open-output-string))
  (write-string (string-append "-----BEGIN " label "-----\n") o)
  (let loop ([i 0] [col 0])
    (when (< i n)
      (define t (+ (arithmetic-shift (bytes-ref der i) 16)
                   (arithmetic-shift (if (< (+ i 1) n) (bytes-ref der (+ i 1)) 0) 8)
                   (if (< (+ i 2) n) (bytes-ref der (+ i 2)) 0)))
      (define rem (- n i))
      (write-char (string-ref b64c (bitwise-and (arithmetic-shift t -18) 63)) o)
      (write-char (string-ref b64c (bitwise-and (arithmetic-shift t -12) 63)) o)
      (write-char (if (>= rem 2) (string-ref b64c (bitwise-and (arithmetic-shift t -6) 63)) #\=) o)
      (write-char (if (>= rem 3) (string-ref b64c (bitwise-and t 63)) #\=) o)
      (define col* (+ col 4)) (when (= col* 64) (write-char #\newline o))
      (loop (+ i 3) (if (= col* 64) 0 col*))))
  (write-string (string-append "\n-----END " label "-----\n") o)
  (get-output-string o))
;; SEC1 ECPrivateKey { version=1, privateKey OCTET STRING(scalar) }.
(define (sec1-ec-der scalar) (d-seq (d-int-small 1) (tlv #x04 scalar)))
(define (ec-private-key->pem scalar)
  (der->pem-body (sec1-ec-der scalar) "EC PRIVATE KEY"))
;; PKCS#8 PrivateKeyInfo { version=0, {ecPublicKey, prime256v1}, OCTET STRING(SEC1) }.
(define (ec-private-key->pkcs8-pem scalar)
  (der->pem-body (d-seq (d-int-small 0)
                        (d-seq (d-oid oid-ec-pubkey) (d-oid oid-p256))
                        (tlv #x04 (sec1-ec-der scalar)))
                 "PRIVATE KEY"))

(define (create-self-signed-certificate #:common-name cn
                                        #:days [days 365]
                                        #:dns-names [dns '()]
                                        #:ca? [ca? #f])
  (define priv (p256-priv))
  (define name (d-seq (d-set (d-seq (d-oid oid-cn) (d-utf8 cn)))))
  (values (assemble-cert name cn priv priv days dns ca?) priv)) ; issuer=subject (self-signed)

;; Extract the raw subject Name TLV from a certificate DER (its issuer field for
;; certs it signs).
(define (cert-subject-name-tlv cert-der)
  (define tbs (car (der-children (der-read cert-der))))
  (define ch (der-children tbs))
  (define ch* (if (and (pair? ch) (= #xA0 (der-tag (car ch)))) (cdr ch) ch))
  (define subj (list-ref ch* 4))
  (define vlen (- (der-end subj) (der-start subj)))
  (define h (cond [(< vlen 128) 2] [(< vlen 256) 3] [(< vlen 65536) 4] [else 5]))
  (subbytes (der-bytes subj) (- (der-start subj) h) (der-end subj)))

;; Build + sign a certificate. issuer-name is a raw Name TLV; the subject key is
;; freshly generated; signing-key signs the TBS.
(define (assemble-cert issuer-name subject-cn subject-key signing-key days dns ca?)
  (define pub (make-bytes 65)) (rktcrypto_p256_pubkey pub subject-key)
  (define sig-algid (d-seq (d-oid oid-ecdsa-sha256)))
  (define subject-name (d-seq (d-set (d-seq (d-oid oid-cn) (d-utf8 subject-cn)))))
  (define now (current-seconds))
  (define validity (d-seq (d-utctime (secs->utctime (- now 3600)))
                          (d-utctime (secs->utctime (+ now (* days 86400))))))
  (define spki (d-seq (d-seq (d-oid oid-ec-pubkey) (d-oid oid-p256)) (d-bitstring pub)))
  (define exts
    (apply bytes-append
           (append
            (if (pair? dns)
                (list (d-seq (d-oid oid-san)
                             (tlv #x04 (apply d-seq (for/list ([h (in-list dns)]) (tlv #x82 (string->bytes/latin-1 h)))))))
                '())
            (if ca? (list (d-seq (d-oid oid-basic) (d-bool #t) (tlv #x04 (d-seq (d-bool #t))))) '()))))
  (define serial (let ([b (crypto-random-bytes 16)]) (bytes-append (bytes (bitwise-and (bytes-ref b 0) #x7f)) (subbytes b 1))))
  (define tbs
    (d-seq (d-ctx-explicit 0 (d-int-small 2)) (d-int-bytes serial) sig-algid
           issuer-name validity subject-name spki
           (if (> (bytes-length exts) 0) (d-ctx-explicit 3 (d-seq exts)) #"")))
  (define sig-raw (make-bytes 64))
  (unless (eqv? 1 (rktcrypto_p256_ecdsa_sign sig-raw tbs (bytes-length tbs) signing-key))
    (error 'assemble-cert "signing failed"))
  (d-seq tbs sig-algid (d-bitstring (raw->ecdsa-der sig-raw))))

;; Issue a leaf certificate signed by a CA (its cert DER + private scalar).
(define (create-certificate #:ca-cert-der ca-der #:ca-key ca-key #:common-name cn
                            #:days [days 365] #:dns-names [dns '()] #:ca? [ca? #f])
  (define subject-key (p256-priv))
  (values (assemble-cert (cert-subject-name-tlv ca-der) cn subject-key ca-key days dns ca?)
          subject-key))

;; PKCS#10 CertificationRequest (ECDSA P-256 / SHA-256), self-signed by the key.
(define (create-certificate-request #:common-name cn #:private-key [priv0 #f])
  (define priv (or priv0 (p256-priv)))
  (define pub (make-bytes 65)) (rktcrypto_p256_pubkey pub priv)
  (define sig-algid (d-seq (d-oid oid-ecdsa-sha256)))
  (define name (d-seq (d-set (d-seq (d-oid oid-cn) (d-utf8 cn)))))
  (define spki (d-seq (d-seq (d-oid oid-ec-pubkey) (d-oid oid-p256)) (d-bitstring pub)))
  (define cri (d-seq (d-int-small 0)                   ; version v1
                     name                              ; subject
                     spki
                     (tlv #xA0 #"")))                  ; [0] attributes (empty)
  (define sig-raw (make-bytes 64))
  (unless (eqv? 1 (rktcrypto_p256_ecdsa_sign sig-raw cri (bytes-length cri) priv))
    (error 'create-certificate-request "signing failed"))
  (values (d-seq cri sig-algid (d-bitstring (raw->ecdsa-der sig-raw))) priv))

;; ============================================================================
;; CMS / PKCS#7 SignedData creation (RFC 5652), ECDSA P-256 / SHA-256, with
;; signed attributes (contentType + messageDigest). Supports multiple signers.
;; Verifiable by rktcrypto_cms_verify (single signer) and `openssl cms -verify`.
;; ============================================================================
(define oid-signed-data #"\x2a\x86\x48\x86\xf7\x0d\x01\x07\x02") ; 1.2.840.113549.1.7.2
(define oid-id-data      #"\x2a\x86\x48\x86\xf7\x0d\x01\x07\x01") ; 1.2.840.113549.1.7.1
(define oid-sha256-dig   #"\x60\x86\x48\x01\x65\x03\x04\x02\x01") ; 2.16.840.1.101.3.4.2.1
(define oid-attr-ct      #"\x2a\x86\x48\x86\xf7\x0d\x01\x09\x03") ; id-contentType
(define oid-attr-md      #"\x2a\x86\x48\x86\xf7\x0d\x01\x09\x04") ; id-messageDigest

;; full TLV bytes of a der node (recovers the header from the content length)
(define (der->tlv-bytes node)
  (define vlen (- (der-end node) (der-start node)))
  (define h (cond [(< vlen 128) 2] [(< vlen 256) 3] [(< vlen 65536) 4] [else 5]))
  (subbytes (der-bytes node) (- (der-start node) h) (der-end node)))

;; issuerAndSerialNumber components (raw TLVs) from a certificate DER
(define (cert-issuer+serial cert-der)
  (define tbs (car (der-children (der-read cert-der))))
  (define ch (der-children tbs))
  (define ch* (if (and (pair? ch) (= #xA0 (der-tag (car ch)))) (cdr ch) ch)) ; drop [0] version
  (values (der->tlv-bytes (list-ref ch* 2))   ; issuer Name
          (der->tlv-bytes (car ch*))))         ; serialNumber INTEGER

;; one SignerInfo (EC P-256) over the content digest; `signer` = (cons cert-der (cons 'p256 scalar))
(define (cms-signer-info signer content-digest)
  (define cert-der (car signer))
  (define key (cdr signer))
  (unless (eq? (car key) 'p256) (error 'create-cms-signed-data "only P-256 signers are supported"))
  (define-values (issuer serial) (cert-issuer+serial cert-der))
  (define ct-attr (d-seq (d-oid oid-attr-ct) (d-set (d-oid oid-id-data))))
  (define md-attr (d-seq (d-oid oid-attr-md) (d-set (tlv #x04 content-digest))))
  ;; SET OF Attribute must be DER-sorted by encoding
  (define attrs-content (apply bytes-append (sort (list ct-attr md-attr) bytes<?)))
  (define attrs-signed  (tlv #x31 attrs-content))   ; SET tag — this is what gets signed
  (define attrs-in-msg  (tlv #xA0 attrs-content))   ; [0] IMPLICIT in the message
  (define sig-raw (make-bytes 64))
  (unless (eqv? 1 (rktcrypto_p256_ecdsa_sign sig-raw attrs-signed (bytes-length attrs-signed) (cdr key)))
    (error 'create-cms-signed-data "signing failed"))
  (d-seq (d-int-small 1)                             ; version (issuerAndSerialNumber)
         (d-seq issuer serial)                       ; sid
         (d-seq (d-oid oid-sha256-dig))              ; digestAlgorithm
         attrs-in-msg                                ; signedAttrs [0] IMPLICIT
         (d-seq (d-oid oid-ecdsa-sha256))            ; signatureAlgorithm
         (tlv #x04 (raw->ecdsa-der sig-raw))))       ; signature

;; content: bytes to embed & sign. signers: list of (cons cert-der (cons 'p256 scalar)).
;; #:detached? omits the encapsulated eContent (the signature still binds
;; messageDigest = SHA-256(content)); the verifier supplies the external content.
(define (create-cms-signed-data content signers #:detached? [detached? #f])
  (when (null? signers) (error 'create-cms-signed-data "at least one signer required"))
  (define content-digest (digest SHA256 content))
  (define digest-algs (d-set (d-seq (d-oid oid-sha256-dig))))
  (define eci (if detached?
                  (d-seq (d-oid oid-id-data))                                     ; detached: no eContent
                  (d-seq (d-oid oid-id-data) (d-ctx-explicit 0 (tlv #x04 content)))))
  (define certs (tlv #xA0 (apply bytes-append (map car signers))))  ; [0] IMPLICIT certificates
  (define sinfos (apply d-set (for/list ([s (in-list signers)]) (cms-signer-info s content-digest))))
  (define signed-data (d-seq (d-int-small 1) digest-algs eci certs sinfos))
  (d-seq (d-oid oid-signed-data) (d-ctx-explicit 0 signed-data)))
(provide create-cms-signed-data)

;; ============================================================================
;; CMS / PKCS#7 EnvelopedData (RFC 5652): RSAES-OAEP-SHA256 key transport of a
;; random AES-256-CBC content-encryption key. Decryptable by `openssl cms -decrypt`.
;; ============================================================================
(define oid-enveloped-data #"\x2a\x86\x48\x86\xf7\x0d\x01\x07\x03") ; 1.2.840.113549.1.7.3
(define oid-aes256cbc      #"\x60\x86\x48\x01\x65\x03\x04\x01\x2a") ; 2.16.840.1.101.3.4.1.42
;; the exact RSAES-OAEP AlgorithmIdentifier (hash SHA-256, MGF1-SHA-256) that
;; OpenSSL/LibreSSL emit and accept
(define rsaes-oaep-sha256-algid
  (bytes #x30 #x38 #x06 #x09 #x2a #x86 #x48 #x86 #xf7 #x0d #x01 #x01 #x07 #x30 #x2b
         #xa0 #x0d #x30 #x0b #x06 #x09 #x60 #x86 #x48 #x01 #x65 #x03 #x04 #x02 #x01
         #xa1 #x1a #x30 #x18 #x06 #x09 #x2a #x86 #x48 #x86 #xf7 #x0d #x01 #x01 #x08
         #x30 #x0b #x06 #x09 #x60 #x86 #x48 #x01 #x65 #x03 #x04 #x02 #x01))

;; recipient RSA (n,e) big-endian magnitudes from their certificate DER
(define (cert-rsa-n+e cert-der)
  (define tbs (car (der-children (der-read cert-der))))
  (define ch (der-children tbs))
  (define ch* (if (and (pair? ch) (= #xA0 (der-tag (car ch)))) (cdr ch) ch))
  (define spki-k (der-children (list-ref ch* 5)))          ; SubjectPublicKeyInfo -> [alg, BIT STRING]
  (define rsapk-der (subbytes (der-content (cadr spki-k)) 1)) ; drop unused-bits octet
  (define ne (der-children (der-read rsapk-der)))
  (define (mag node) (let ([v (der-content node)])
                       (if (and (> (bytes-length v) 1) (zero? (bytes-ref v 0))) (subbytes v 1) v)))
  (values (mag (car ne)) (mag (cadr ne))))

(define (pkcs7-pad bs block)
  (define n (- block (modulo (bytes-length bs) block)))
  (bytes-append bs (make-bytes n n)))

;; content: bytes to encrypt. recip-cert-der: an RSA recipient certificate.
(define (create-cms-enveloped-data content recip-cert-der)
  (define-values (n e) (cert-rsa-n+e recip-cert-der))
  (define cek (crypto-random-bytes 32))                    ; AES-256 content-encryption key
  (define iv (crypto-random-bytes 16))
  (define padded (pkcs7-pad content 16))
  (define ct (make-bytes (bytes-length padded)))
  (rktcrypto_aes_cbc_encrypt cek 32 iv padded ct (bytes-length padded))
  (define enc-key (make-bytes (bytes-length n)))
  (define klen (rktcrypto_rsa_oaep_encrypt_pub n (bytes-length n) e (bytes-length e) cek 32 enc-key))
  (when (zero? klen) (error 'create-cms-enveloped-data "RSA-OAEP key wrap failed"))
  (define-values (issuer serial) (cert-issuer+serial recip-cert-der))
  (define ktri (d-seq (d-int-small 0)                      ; KeyTransRecipientInfo
                      (d-seq issuer serial)                ; rid = issuerAndSerialNumber
                      rsaes-oaep-sha256-algid              ; keyEncryptionAlgorithm
                      (tlv #x04 (subbytes enc-key 0 klen)))) ; encryptedKey
  (define eci (d-seq (d-oid oid-id-data)                   ; EncryptedContentInfo
                     (d-seq (d-oid oid-aes256cbc) (tlv #x04 iv))
                     (tlv #x80 ct)))                        ; encryptedContent [0] IMPLICIT
  (d-seq (d-oid oid-enveloped-data)
         (d-ctx-explicit 0 (d-seq (d-int-small 0) (d-set ktri) eci))))
(provide create-cms-enveloped-data)
