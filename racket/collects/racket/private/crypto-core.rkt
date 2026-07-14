#lang racket/base

;; Core implementations behind `racket/crypto/...` and
;; `racket/random`, without contracts.
;;
;; On the CS backend, the rktcrypto primitives are available from
;; `#%kernel`; on hosts without them (BC), this module falls back to
;; the historical entropy paths and to best-effort Racket
;; implementations of the byte utilities.

(require "unix-rand.rkt" "windows-rand.rkt")

(provide crypto-random-bytes
         crypto-random-bytes!
         crypto-bytes=?
         crypto-bytes-clear!
         crypto-subsystem-self-test?
         crypto-primitives-available?)

(define (primitive name)
  (dynamic-require ''#%kernel name (lambda () #f)))

(define prim-random-bytes! (primitive 'crypto-random-bytes!))
(define prim-bytes=? (primitive 'crypto-bytes=?))
(define prim-bytes-clear! (primitive 'crypto-bytes-clear!))
(define prim-self-test? (primitive 'crypto-subsystem-self-test?))

(define (crypto-primitives-available?)
  (and prim-random-bytes! #t))

;; ----------------------------------------
;; Entropy

(define (fallback-random-bytes n)
  (case (system-type 'os)
    [(unix macosx) (crypto-random-unix-bytes n)]
    [(windows) (crypto-random-windows-bytes n)]
    [else (raise (make-exn:fail:unsupported
                  "crypto-random-bytes: not supported on the current platform"
                  (current-continuation-marks)))]))

(define (crypto-random-bytes n)
  (cond
    [prim-random-bytes!
     (define bs (make-bytes n))
     (prim-random-bytes! bs 0 n)
     bs]
    [else (fallback-random-bytes n)]))

(define (crypto-random-bytes! bs [start 0] [end (and (bytes? bs) (bytes-length bs))])
  (cond
    [prim-random-bytes!
     (prim-random-bytes! bs start end)]
    [else
     (check-fill-range 'crypto-random-bytes! bs start end)
     (bytes-copy! bs start (fallback-random-bytes (- end start)))
     (void)]))

;; ----------------------------------------
;; Constant-time utilities

;; The fallback comparison avoids an early exit, but only the C
;; primitive comes with a constant-time claim.
(define (fallback-bytes=? a b len)
  (let loop ([i 0] [acc 0])
    (if (eqv? i len)
        (eqv? acc 0)
        (loop (add1 i)
              (bitwise-ior acc (bitwise-xor (bytes-ref a i) (bytes-ref b i)))))))

(define (crypto-bytes=? a b)
  (unless (bytes? a)
    (raise-argument-error 'crypto-bytes=? "bytes?" 0 a b))
  (unless (bytes? b)
    (raise-argument-error 'crypto-bytes=? "bytes?" 1 a b))
  (cond
    [prim-bytes=? (prim-bytes=? a b)]
    [else
     (and (eqv? (bytes-length a) (bytes-length b))
          (fallback-bytes=? a b (bytes-length a)))]))

(define (crypto-bytes-clear! bs [start 0] [end (and (bytes? bs) (bytes-length bs))])
  (cond
    [prim-bytes-clear!
     (prim-bytes-clear! bs start end)]
    [else
     (check-fill-range 'crypto-bytes-clear! bs start end)
     (for ([i (in-range start end)])
       (bytes-set! bs i 0))
     (void)]))

(define (crypto-subsystem-self-test?)
  (if prim-self-test?
      (prim-self-test?)
      ;; No C subsystem to test on this host:
      #f))

;; ----------------------------------------

(define (check-fill-range who bs start end)
  (unless (and (bytes? bs) (not (immutable? bs)))
    (raise-argument-error who "(and/c bytes? (not/c immutable?))" bs))
  (unless (exact-nonnegative-integer? start)
    (raise-argument-error who "exact-nonnegative-integer?" start))
  (unless (exact-nonnegative-integer? end)
    (raise-argument-error who "exact-nonnegative-integer?" end))
  (unless (<= start end (bytes-length bs))
    (raise-range-error who "byte string" "ending " end bs start (bytes-length bs) 0)))
