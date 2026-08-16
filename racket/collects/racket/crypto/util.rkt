#lang racket/base

(require racket/contract/base
         (prefix-in core: "../private/crypto-core.rkt"))

(provide (contract-out
          [crypto-bytes=? (-> bytes? bytes? boolean?)]
          [crypto-bytes-clear! (->* ((and/c bytes? (not/c immutable?)))
                                    (exact-nonnegative-integer?
                                     exact-nonnegative-integer?)
                                    void?)]
          [call-with-secret-bytes (-> exact-nonnegative-integer?
                                      (-> bytes? any)
                                      any)]
          [crypto-subsystem-self-test? (-> boolean?)]))

;; Compares two byte strings in constant time with respect to their
;; contents, for MAC/token verification. Byte strings of different
;; lengths compare #f immediately; lengths are not treated as secrets.
(define (crypto-bytes=? a b)
  (core:crypto-bytes=? a b))

;; Zeroes bstr[start..end) such that the clearing is not elided by
;; compiler optimization. Best-effort at the process level: copies
;; made by the garbage collector or the operating system are outside
;; its reach.
(define (crypto-bytes-clear! bstr [start 0] [end (bytes-length bstr)])
  (core:crypto-bytes-clear! bstr start end))

;; Calls `proc` with a fresh mutable byte string of length n, and
;; clears it when control leaves `proc` (including on escape). If
;; control re-enters `proc` via a continuation, the byte string will
;; have been cleared.
(define (call-with-secret-bytes n proc)
  (define bs (make-bytes n 0))
  (dynamic-wind
   void
   (lambda () (proc bs))
   (lambda () (core:crypto-bytes-clear! bs 0 (bytes-length bs)))))

;; Runs the crypto subsystem's known-answer self-tests; #t means all
;; passed. Returns #f on hosts without the built-in subsystem.
(define (crypto-subsystem-self-test?)
  (core:crypto-subsystem-self-test?))
