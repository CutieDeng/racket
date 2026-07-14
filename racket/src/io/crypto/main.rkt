#lang racket/base
(require "../common/check.rkt"
         "../host/rktcrypto.rkt")

(provide crypto-random-bytes!
         crypto-bytes=?
         crypto-bytes-clear!
         crypto-subsystem-self-test?)

(define mutable-bytes-contract "(and/c bytes? (not/c immutable?))")

(define (check-mutable-bytes who bstr)
  (check who (lambda (v) (and (bytes? v) (not (immutable? v))))
         #:contract mutable-bytes-contract
         bstr))

(define (check-start/end who bstr start end)
  (check who exact-nonnegative-integer? start)
  (check who exact-nonnegative-integer? end)
  (check-range who start end (bytes-length bstr) bstr))

;; Fills `bstr[start..end)` with cryptographically secure random
;; bytes from the operating system. Raises `exn:fail` if the system
;; entropy source is unavailable.
(define/who (crypto-random-bytes! bstr [start 0] [end (and (bytes? bstr) (bytes-length bstr))])
  (check-mutable-bytes who bstr)
  (check-start/end who bstr start end)
  (unless (eqv? 1 (rktcrypto_system_random bstr start end))
    (raise (exn:fail
            (string-append (symbol->string who)
                           ": system entropy source is unavailable")
            (current-continuation-marks))))
  (void))

;; Constant-time comparison with respect to buffer contents. Byte
;; strings of different lengths compare `#f` immediately; lengths are
;; not treated as secrets.
(define/who (crypto-bytes=? a b)
  (check who bytes? a)
  (check who bytes? b)
  (and (eqv? (bytes-length a) (bytes-length b))
       (eqv? 1 (rktcrypto_ct_bytes_equal a 0 b 0 (bytes-length a)))))

;; Zeroes `bstr[start..end)` such that the clearing cannot be elided
;; by compiler optimization. Best-effort at the process level: copies
;; made by the garbage collector or the operating system are outside
;; its reach.
(define/who (crypto-bytes-clear! bstr [start 0] [end (and (bytes? bstr) (bytes-length bstr))])
  (check-mutable-bytes who bstr)
  (check-start/end who bstr start end)
  (rktcrypto_secure_clear bstr start end))

;; Runs the rktcrypto known-answer self-tests; `#t` means all passed.
(define/who (crypto-subsystem-self-test?)
  (eqv? 1 (rktcrypto_selftest_core)))
