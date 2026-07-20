#lang racket/base

(require racket/contract/base
         (prefix-in core: "../private/crypto-core.rkt"))

(provide (contract-out
          [crypto-random-bytes (-> exact-nonnegative-integer? bytes?)]
          [crypto-random-bytes! (->* ((and/c bytes? (not/c immutable?)))
                                     (exact-nonnegative-integer?
                                      exact-nonnegative-integer?)
                                     void?)]))

;; Returns n cryptographically secure random bytes from the operating
;; system.
(define (crypto-random-bytes n)
  (core:crypto-random-bytes n))

;; Fills bstr[start..end) with cryptographically secure random bytes;
;; a zero-allocation alternative to `crypto-random-bytes` for hot
;; paths.
(define (crypto-random-bytes! bstr [start 0] [end (bytes-length bstr)])
  (core:crypto-random-bytes! bstr start end))
