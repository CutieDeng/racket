#lang racket/base

;; Key exchange over the built-in elliptic curves.
;;
;; X25519 (RFC 7748): Diffie-Hellman on Curve25519. A private key is 32
;; random bytes (clamped internally); the public key is the private key
;; applied to the curve base point.

(require racket/contract/base
         "random.rkt"
         (only-in '#%kernel crypto-x25519))

(define x25519-base-point
  (bytes-append (bytes 9) (make-bytes 31 0)))

;; Generates a fresh 32-byte X25519 private key.
(define (x25519-generate-private-key)
  (crypto-random-bytes 32))

;; Derives the 32-byte public key for a private key.
(define (x25519-public-key private-key)
  (define pub (crypto-x25519 private-key x25519-base-point))
  (or pub (error 'x25519-public-key "degenerate private key")))

;; Computes the shared secret between our private key and a peer's
;; public key. Returns #f if the peer key is a low-order point (the
;; shared secret would be all-zero); callers must treat #f as a failed
;; exchange.
(define (x25519 private-key peer-public-key)
  (crypto-x25519 private-key peer-public-key))

(provide (contract-out
          [x25519-generate-private-key (-> bytes?)]
          [x25519-public-key (-> bytes? bytes?)]
          [x25519 (-> bytes? bytes? (or/c bytes? #f))]))
