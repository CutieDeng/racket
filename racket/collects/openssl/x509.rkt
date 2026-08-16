#lang racket/base

;; Public X.509 read API over the in-tree rktcrypto parser — parse a certificate
;; (PEM or DER) and read its subject/issuer, validity, SANs, key usage, and
;; public-key type, plus PEM<->DER conversion. No OpenSSL. (Construction / CSR /
;; PKCS#8/#12 are a separate, larger follow-on.)

(require racket/contract/base
         racket/file
         racket/date
         (prefix-in i: "private/rktcrypto-x509.rkt")
         "private/rktcrypto-der.rkt"
         "private/rktcrypto-x509-build.rkt")

(define certificate? i:certificate?)

;; DN attribute OID -> short label (fallback: the dotted OID string).
(define dn-labels
  (hash "2.5.4.3" "CN" "2.5.4.10" "O" "2.5.4.11" "OU" "2.5.4.6" "C"
        "2.5.4.7" "L" "2.5.4.8" "ST" "1.2.840.113549.1.9.1" "emailAddress"))
(define (->str v) (if (bytes? v) (bytes->string/latin-1 v) v))
(define (name->assoc n)
  (for/list ([kv (in-list n)])
    (cons (hash-ref dn-labels (car kv) (car kv)) (->str (cdr kv)))))
(define (cn-of n) (let ([p (assoc "2.5.4.3" n)]) (and p (->str (cdr p)))))

;; X.509 time (UTCTime "YYMMDDHHMMSSZ" 2-digit year, or GeneralizedTime
;; "YYYYMMDDHHMMSSZ") -> UTC seconds.
(define (x509-time->seconds s)
  (define (n a b) (string->number (substring s a b)))
  (cond
    [(= (string-length s) 13)   ; UTCTime, 2-digit year (RFC 5280: <50 => 20xx)
     (define yy (n 0 2))
     (find-seconds (n 10 12) (n 8 10) (n 6 8) (n 4 6) (n 2 4) (+ (if (< yy 50) 2000 1900) yy) #f)]
    [(>= (string-length s) 15)  ; GeneralizedTime
     (find-seconds (n 12 14) (n 10 12) (n 8 10) (n 6 8) (n 4 6) (n 0 4) #f)]
    [else (error 'x509-time->seconds "unrecognized time ~a" s)]))

(define (read-certificate src)
  (define bs (cond [(bytes? src) src] [else (file->bytes src)]))
  (define der (if (regexp-match? #rx#"-----BEGIN" bs) (car (i:pem->der-list bs)) bs))
  (i:parse-certificate der))

;; serial number (INTEGER) — extract from the DER TBSCertificate.
(define (certificate-serial-number c)
  (define tbs (car (der-children (der-read (i:certificate-der c)))))
  (define ch (der-children tbs))
  (der-uint (if (and (pair? ch) (= #xA0 (der-tag (car ch)))) (cadr ch) (car ch))))

(define (certificate-subject c) (name->assoc (i:certificate-subject c)))
(define (certificate-issuer c)  (name->assoc (i:certificate-issuer c)))
(define (certificate-subject-common-name c) (cn-of (i:certificate-subject c)))
(define (certificate-issuer-common-name c)  (cn-of (i:certificate-issuer c)))
(define (certificate-not-before c) (i:certificate-not-before c))
(define (certificate-not-after c)  (i:certificate-not-after c))
(define (certificate-valid-from c) (x509-time->seconds (i:certificate-not-before c)))
(define (certificate-valid-to c)   (x509-time->seconds (i:certificate-not-after c)))
(define (certificate-dns-names c)  (i:certificate-san-dns c))
(define (certificate-ca? c)        (and (i:certificate-is-ca c) #t))
(define (certificate-key-usage c)  (i:certificate-key-usage c))
(define (certificate-extended-key-usage c) (i:certificate-eku c))
(define (certificate-public-key-type c) (i:pubkey-type (i:certificate-pub c)))
(define (certificate-der c) (i:certificate-der c))

;; PEM <-> DER for a single certificate.
(define (pem->der pem) (car (i:pem->der-list pem)))
(define b64-chars "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")
(define (der->pem der)
  (define n (bytes-length der))
  (define out (open-output-string))
  (write-string "-----BEGIN CERTIFICATE-----\n" out)
  (let loop ([i 0] [col 0])
    (when (< i n)
      (define b0 (bytes-ref der i))
      (define b1 (if (< (+ i 1) n) (bytes-ref der (+ i 1)) 0))
      (define b2 (if (< (+ i 2) n) (bytes-ref der (+ i 2)) 0))
      (define trip (+ (arithmetic-shift b0 16) (arithmetic-shift b1 8) b2))
      (define rem (- n i))
      (write-char (string-ref b64-chars (bitwise-and (arithmetic-shift trip -18) 63)) out)
      (write-char (string-ref b64-chars (bitwise-and (arithmetic-shift trip -12) 63)) out)
      (write-char (if (>= rem 2) (string-ref b64-chars (bitwise-and (arithmetic-shift trip -6) 63)) #\=) out)
      (write-char (if (>= rem 3) (string-ref b64-chars (bitwise-and trip 63)) #\=) out)
      (define col* (+ col 4))
      (when (= col* 64) (write-char #\newline out))
      (loop (+ i 3) (if (= col* 64) 0 col*))))
  (write-string "\n-----END CERTIFICATE-----\n" out)
  (get-output-string out))

(provide
 (contract-out
  [certificate? (-> any/c boolean?)]
  [read-certificate (-> (or/c bytes? path-string?) certificate?)]
  [certificate-subject (-> certificate? (listof (cons/c string? string?)))]
  [certificate-issuer  (-> certificate? (listof (cons/c string? string?)))]
  [certificate-subject-common-name (-> certificate? (or/c string? #f))]
  [certificate-issuer-common-name  (-> certificate? (or/c string? #f))]
  [certificate-serial-number (-> certificate? exact-nonnegative-integer?)]
  [certificate-not-before (-> certificate? string?)]
  [certificate-not-after  (-> certificate? string?)]
  [certificate-valid-from (-> certificate? exact-integer?)]
  [certificate-valid-to   (-> certificate? exact-integer?)]
  [certificate-dns-names  (-> certificate? (listof string?))]
  [certificate-ca? (-> certificate? boolean?)]
  [certificate-key-usage (-> certificate? (or/c (listof symbol?) #f))]
  [certificate-extended-key-usage (-> certificate? (or/c (listof string?) #f))]
  [certificate-public-key-type (-> certificate? (or/c 'rsa 'ec 'ed25519))]
  [certificate-der (-> certificate? bytes?)]
  [pem->der (-> (or/c bytes? string?) bytes?)]
  [der->pem (-> bytes? string?)]
  ;; Construct a self-signed ECDSA-P256/SHA-256 certificate; returns the cert DER
  ;; and the EC private scalar (32 bytes).
  [create-self-signed-certificate
   (->* (#:common-name string?)
        (#:days exact-positive-integer? #:dns-names (listof string?) #:ca? any/c)
        (values bytes? bytes?))]
  ;; Construct a PKCS#10 CertificationRequest (CSR), self-signed by the key.
  [create-certificate-request
   (->* (#:common-name string?) (#:private-key (or/c bytes? #f)) (values bytes? bytes?))]
  ;; Issue a leaf certificate signed by a CA (its cert DER + private scalar).
  [create-certificate
   (->* (#:ca-cert-der bytes? #:ca-key bytes? #:common-name string?)
        (#:days exact-positive-integer? #:dns-names (listof string?) #:ca? any/c)
        (values bytes? bytes?))]
  ;; Encode a 32-byte P-256 private scalar as a SEC1 "EC PRIVATE KEY" PEM.
  [ec-private-key->pem (-> bytes? string?)]
  ;; ... or as a PKCS#8 "PRIVATE KEY" PEM.
  [ec-private-key->pkcs8-pem (-> bytes? string?)]))
