#lang racket/base

;; Low-level authenticated encryption (AEAD) with an explicit nonce.
;; This is the expert-facing interface: the caller is responsible for
;; never reusing a (key, nonce) pair. For a misuse-resistant default,
;; use `racket/crypto/secretbox` instead.

(require racket/contract/base
         (only-in '#%kernel
                  crypto-aead-key-size
                  crypto-aead-nonce-size
                  crypto-aead-tag-size
                  crypto-aead-seal!
                  crypto-aead-open!
                  crypto-aead-expand-key))

(define algorithms '(chacha20-poly1305 xchacha20-poly1305 aes-256-gcm aes-256-ccm aes-128-ccm))
(define (aead-algorithm? v) (and (memq v algorithms) #t))
(define aead-algorithm/c (flat-named-contract 'aead-algorithm/c aead-algorithm?))

(define (aead-key-size alg) (crypto-aead-key-size alg))
(define (aead-nonce-size alg) (crypto-aead-nonce-size alg))
(define (aead-tag-size alg) (crypto-aead-tag-size alg))

;; Precomputes the per-key state (key schedule; for AES-GCM the hash key
;; and, where the fused kernel runs, its table) once: the result is
;; accepted wherever a key is, and skips that work on every call. It is
;; as secret as the key.
(define (aead-expand-key alg key)
  (crypto-aead-expand-key alg key))

;; An expanded key is longer than the raw key and starts with a header
;; (the magic 0x4b58414e and the algorithm id, both 32-bit little-endian,
;; as laid out by rktcrypto_cipher.h). Two algorithms can have expanded
;; keys of the same length, so a key of expanded length is checked here
;; against the algorithm it was expanded for; the primitive would otherwise
;; report a mismatch as a failed operation (encrypt) or as #f (decrypt).
(define xkey-magic #x4b58414e)
(define (alg-id alg)
  (case alg
    [(chacha20-poly1305) 1] [(xchacha20-poly1305) 2]
    [(aes-256-gcm) 3] [(aes-128-gcm) 4]
    [(aes-256-ccm) 5] [(aes-128-ccm) 6]
    [else #f]))
(define (check-expanded-key who alg key)
  (when (and (bytes? key)
             (> (bytes-length key) (crypto-aead-key-size alg))
             (>= (bytes-length key) 8))
    (unless (and (eqv? (integer-bytes->integer key #f #f 0 4) xkey-magic)
                 (eqv? (integer-bytes->integer key #f #f 4 8) (alg-id alg)))
      (raise-arguments-error who "expanded key is not for this algorithm"
                             "algorithm" alg))))

;; Encrypts and authenticates `plaintext`, returning ciphertext with
;; the authentication tag appended.
(define (aead-encrypt alg key nonce plaintext #:aad [aad #""])
  (check-expanded-key 'aead-encrypt alg key)
  (define out (make-bytes (+ (bytes-length plaintext) (crypto-aead-tag-size alg))))
  (crypto-aead-seal! alg key nonce aad plaintext out)
  out)

;; Verifies and decrypts `ciphertext+tag`, returning the plaintext, or
;; #f if authentication fails. Failure is not distinguished by reason.
(define (aead-decrypt alg key nonce ciphertext+tag #:aad [aad #""])
  (check-expanded-key 'aead-decrypt alg key)
  (define n (- (bytes-length ciphertext+tag) (crypto-aead-tag-size alg)))
  (cond
    [(< n 0) #f]
    [else
     (define out (make-bytes n))
     (and (crypto-aead-open! alg key nonce aad ciphertext+tag out) out)]))

(provide aead-algorithm/c
         (contract-out
          [aead-algorithms (-> (listof symbol?))]
          [aead-key-size (-> aead-algorithm/c exact-positive-integer?)]
          [aead-nonce-size (-> aead-algorithm/c exact-positive-integer?)]
          [aead-tag-size (-> aead-algorithm/c exact-positive-integer?)]
          [aead-expand-key (-> aead-algorithm/c bytes? bytes?)]
          [aead-encrypt (->* (aead-algorithm/c bytes? bytes? bytes?)
                             (#:aad bytes?)
                             bytes?)]
          [aead-decrypt (->* (aead-algorithm/c bytes? bytes? bytes?)
                             (#:aad bytes?)
                             (or/c bytes? #f))]))

(define (aead-algorithms) algorithms)
