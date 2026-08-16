#lang racket
;; OCSP stapling verifier (rktcrypto-ocsp) acceptance: a python-generated CA +
;; leaf + GOOD/REVOKED OCSP responses, checking the verifier accepts good,
;; reports revoked, and rejects a tampered signature / wrong issuer / stale time.
(require racket/runtime-path racket/date
         (file "../../../collects/openssl/private/rktcrypto-ocsp.rkt"))

(define-runtime-path here ".")
(define (der name) (file->bytes (build-path here "ocsp-vectors" name)))
(define ca (der "ca.der")) (define leaf (der "leaf.der"))
(define good (der "good.der")) (define revoked (der "revoked.der"))
;; vectors' thisUpdate ~2026-08-01; pick a `now` inside [thisUpdate, nextUpdate]
(define now (find-seconds 0 0 12 1 8 2026 #f))

(define failures 0)
(define (check! name ok?)
  (printf "  ~a: ~a\n" (if ok? "ok" "FAIL") name)
  (unless ok? (set! failures (add1 failures))))
(define (raises? thunk) (with-handlers ([exn:fail? (lambda (_) #t)]) (thunk) #f))

(printf "OCSP verifier acceptance:\n")
(check! "GOOD response -> 'good"
        (eq? 'good (verify-ocsp-staple good leaf ca now)))
(check! "REVOKED response -> 'revoked"
        (eq? 'revoked (verify-ocsp-staple revoked leaf ca now)))
(check! "tampered signature rejected"
        (raises? (lambda ()
                   (define b (bytes-copy good))
                   (bytes-set! b (- (bytes-length b) 1) (bitwise-xor 1 (bytes-ref b (- (bytes-length b) 1))))
                   (verify-ocsp-staple b leaf ca now))))
(check! "wrong issuer (leaf as issuer) rejected"
        (raises? (lambda () (verify-ocsp-staple good leaf leaf now))))
(check! "stale response rejected (now past nextUpdate)"
        (raises? (lambda () (verify-ocsp-staple good leaf ca (find-seconds 0 0 12 1 1 2030 #f)))))
(check! "response for a different cert rejected (ca as leaf)"
        (raises? (lambda () (verify-ocsp-staple good ca ca now))))

(printf "OCSP verifier: ~a failure(s)\n" failures)
(when (> failures 0) (error 'test-ocsp "~a check(s) failed" failures))
