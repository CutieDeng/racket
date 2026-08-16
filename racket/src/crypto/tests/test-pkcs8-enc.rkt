#lang racket
;; C2: encrypted PKCS#8 (PBES2 = PBKDF2 + AES-CBC, RFC 8018) private-key loading.
;; Ground truth: the vectors under pkcs8-vectors/ were produced by `openssl pkcs8
;; -topk8 -v2 <aes-cbc>`; decrypting each with its password must yield exactly the
;; key in the matching *-plain.pem (unencrypted PKCS#8).
(require racket/runtime-path
         (only-in "../../../collects/openssl/private/rktcrypto-x509.rkt" pem->private-key))

(define-runtime-path vec-dir "pkcs8-vectors")
(define pw "secret123")
(define fails 0)
(define (check! name ok?) (printf "  ~a ~a\n" (if ok? "ok:" "FAIL:") name) (unless ok? (set! fails (add1 fails))))
(define (load name [password #f]) (pem->private-key (file->bytes (build-path vec-dir name)) password))

(printf "encrypted PKCS#8 (PBES2) loading:\n")

;; each encrypted key must decrypt to the same (type . material) as its plaintext
(for ([pair (in-list '(("ec-plain.pem"  "ec-aes256.pem")
                        ("ec-plain.pem"  "ec-aes128.pem")
                        ("rsa-plain.pem" "rsa-aes256.pem")))])
  (define plain (load (car pair)))
  (define dec   (load (cadr pair) pw))
  (check! (format "~a decrypts to the plaintext key" (cadr pair))
          (and (eq? (car plain) (car dec)) (equal? (cdr plain) (cdr dec)))))

;; wrong password must be rejected (PKCS#7 padding check), not silently mis-load
(check! "wrong password is rejected"
        (with-handlers ([exn:fail? (lambda (_) #t)]) (load "ec-aes256.pem" "wrongpw") #f))

;; a missing password on an encrypted key must error clearly
(check! "encrypted key without a password errors"
        (with-handlers ([exn:fail? (lambda (_) #t)]) (load "ec-aes256.pem" #f) #f))

;; unencrypted keys still load with no password (no regression)
(check! "unencrypted EC PKCS#8 still loads"  (eq? 'p256 (car (load "ec-plain.pem"))))
(check! "unencrypted RSA PKCS#8 still loads" (eq? 'rsa (car (load "rsa-plain.pem"))))

(printf (if (zero? fails) "pkcs8-enc: 0 failure(s)\n" (format "pkcs8-enc: ~a FAILURE(S)\n" fails)))
(exit (if (zero? fails) 0 1))
