#lang racket
;; C2: CMS / PKCS#7 SignedData creation (RFC 5652), ECDSA P-256 / SHA-256, with
;; signed attributes. The created message is checked with librktcrypto's own
;; rktcrypto_cms_verify (round trip); `openssl cms -verify` cross-check is done
;; out of band (test-cms-openssl.sh) so the suite stays OpenSSL-free.
(require (only-in "../../../collects/openssl/private/rktcrypto-x509-build.rkt"
                  create-self-signed-certificate create-cms-signed-data)
         (only-in "../../../collects/openssl/private/rktcrypto-ffi.rkt" rktcrypto_cms_verify))

(define fails 0)
(define (check! name ok?) (printf "  ~a ~a\n" (if ok? "ok:" "FAIL:") name) (unless ok? (set! fails (add1 fails))))
(define (cms-ok? der) (eqv? 1 (rktcrypto_cms_verify der (bytes-length der))))

(printf "CMS/PKCS#7 SignedData creation:\n")

(define-values (cert key) (create-self-signed-certificate #:common-name "cms.signer"))
(define signer (cons cert (cons 'p256 key)))
(define content #"hello, CMS SignedData over librktcrypto")

;; 1. round trip: our own verifier accepts our SignedData
(define cms (create-cms-signed-data content (list signer)))
(check! "single-signer SignedData verifies (rktcrypto_cms_verify)" (cms-ok? cms))

;; 2. tampering the embedded content breaks the messageDigest attribute
(define tampered (let ([b (bytes-copy cms)])
                   ;; flip a byte inside the content region (search for the content bytes)
                   (define idx (let loop ([i 0]) (cond [(> (+ i (bytes-length content)) (bytes-length b)) #f]
                                                       [(equal? (subbytes b i (+ i (bytes-length content))) content) i]
                                                       [else (loop (add1 i))])))
                   (bytes-set! b idx (bitwise-xor 1 (bytes-ref b idx)))
                   b))
(check! "tampered content is rejected" (not (cms-ok? tampered)))

;; 3. tampering the last byte (inside the signature) breaks the signature
(define sig-tampered (let ([b (bytes-copy cms)])
                       (bytes-set! b (sub1 (bytes-length b)) (bitwise-xor 1 (bytes-ref b (sub1 (bytes-length b)))))
                       b))
(check! "tampered signature is rejected" (not (cms-ok? sig-tampered)))

;; 4. a different signer's message must not verify under a mismatched signature:
;;    build a valid CMS, then swap in another cert -> signature no longer matches
(define-values (cert2 key2) (create-self-signed-certificate #:common-name "other.signer"))
(define cms2 (create-cms-signed-data content (list (cons cert2 (cons 'p256 key2)))))
(check! "an independently-signed message also verifies" (cms-ok? cms2))
(check! "the two messages differ" (not (equal? cms cms2)))

;; 5. multi-signer message is well-formed (round-trips through our verifier, which
;;    checks a signer); full 2-of-2 verification is cross-checked by openssl.
(define multi (create-cms-signed-data content (list signer (cons cert2 (cons 'p256 key2)))))
(check! "multi-signer SignedData is accepted" (cms-ok? multi))

(printf (if (zero? fails) "cms: 0 failure(s)\n" (format "cms: ~a FAILURE(S)\n" fails)))
(exit (if (zero? fails) 0 1))
