#lang racket/base

;; High-level symmetric authenticated encryption with a safe default:
;; the caller supplies only a key, and each message gets a fresh random
;; nonce that is carried in the output. Built on XChaCha20-Poly1305,
;; whose 192-bit nonce makes random nonces collision-safe.
;;
;; The sealed format is: version(1) || nonce(24) || ciphertext || tag(16).
;; The version byte lets the algorithm change in a future revision
;; without ambiguity.

(require racket/contract/base
         "random.rkt"
         (prefix-in a: "aead.rkt")
         (prefix-in u: "util.rkt"))

(define alg 'xchacha20-poly1305)
(define version-byte 1)
(define nonce-size (a:aead-nonce-size alg))
(define key-size (a:aead-key-size alg))
(define header-size (+ 1 nonce-size))

;; Generates a fresh random secretbox key.
(define (secretbox-key)
  (crypto-random-bytes key-size))

;; Encrypts `plaintext` under `key`, returning a self-describing sealed
;; byte string (version || nonce || ciphertext || tag).
(define (secretbox-encrypt key plaintext #:aad [aad #""])
  (define nonce (crypto-random-bytes nonce-size))
  (define ct (a:aead-encrypt alg key nonce plaintext #:aad aad))
  (bytes-append (bytes version-byte) nonce ct))

;; Decrypts a sealed byte string produced by `secretbox-encrypt`,
;; returning the plaintext, or #f if it is malformed or authentication
;; fails (the two are not distinguished).
(define (secretbox-decrypt key sealed #:aad [aad #""])
  (cond
    [(< (bytes-length sealed) header-size) #f]
    [(not (= (bytes-ref sealed 0) version-byte)) #f]
    [else
     (define nonce (subbytes sealed 1 header-size))
     (define ct (subbytes sealed header-size))
     (a:aead-decrypt alg key nonce ct #:aad aad)]))

(provide (contract-out
          [secretbox-key (-> bytes?)]
          [secretbox-encrypt (->* (bytes? bytes?) (#:aad bytes?) bytes?)]
          [secretbox-decrypt (->* (bytes? bytes?) (#:aad bytes?) (or/c bytes? #f))]))
