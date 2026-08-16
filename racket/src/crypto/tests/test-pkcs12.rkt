#lang racket
;; C2: PKCS#12 (PFX) loading — RFC 7292. Ground truth: ec.p12 / rsa.p12 were made
;; by `openssl pkcs12 -export` (LibreSSL: PKCS12-KDF/SHA1, RC2-40 certs,
;; 3DES shrouded key, SHA1 HMAC). The extracted key must equal the matching
;; *-plain.pem, and the extracted cert must be the self-signed cert we bundled.
(require racket/runtime-path
         (only-in "../../../collects/openssl/private/rktcrypto-pkcs12.rkt" pkcs12-parse)
         (only-in "../../../collects/openssl/private/rktcrypto-x509.rkt" pem->private-key)
         (only-in "../../../collects/openssl/x509.rkt" read-certificate certificate-subject-common-name))

(define-runtime-path vec-dir "pkcs8-vectors")
(define pw "secret123")
(define fails 0)
(define (check! name ok?) (printf "  ~a ~a\n" (if ok? "ok:" "FAIL:") name) (unless ok? (set! fails (add1 fails))))

(printf "PKCS#12 (PFX) loading:\n")

(for ([spec (in-list '(("ec.p12"  "ec-plain.pem"  "p12.test")
                        ("rsa.p12" "rsa-plain.pem" "p12rsa.test")))])
  (define-values (key certs)
    (pkcs12-parse (file->bytes (build-path vec-dir (car spec))) pw))
  (define expect-key (pem->private-key (file->bytes (build-path vec-dir (cadr spec)))))
  (check! (format "~a: private key matches the plaintext key" (car spec))
          (and key (eq? (car key) (car expect-key)) (equal? (cdr key) (cdr expect-key))))
  (check! (format "~a: exactly one certificate extracted" (car spec)) (= 1 (length certs)))
  (check! (format "~a: certificate CN is ~a" (car spec) (caddr spec))
          (and (pair? certs)
               (equal? (caddr spec) (certificate-subject-common-name (read-certificate (car certs)))))))

;; wrong password must fail the MAC check (not silently mis-load)
(check! "wrong password is rejected (MAC mismatch)"
        (with-handlers ([exn:fail? (lambda (_) #t)])
          (pkcs12-parse (file->bytes (build-path vec-dir "ec.p12")) "wrongpw") #f))

(printf (if (zero? fails) "pkcs12: 0 failure(s)\n" (format "pkcs12: ~a FAILURE(S)\n" fails)))
(exit (if (zero? fails) 0 1))
