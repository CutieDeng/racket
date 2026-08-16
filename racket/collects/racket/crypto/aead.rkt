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
                  crypto-aead-open!))

(define algorithms '(chacha20-poly1305 xchacha20-poly1305 aes-256-gcm aes-256-ccm aes-128-ccm))
(define (aead-algorithm? v) (and (memq v algorithms) #t))
(define aead-algorithm/c (flat-named-contract 'aead-algorithm/c aead-algorithm?))

(define (aead-key-size alg) (crypto-aead-key-size alg))
(define (aead-nonce-size alg) (crypto-aead-nonce-size alg))
(define (aead-tag-size alg) (crypto-aead-tag-size alg))

;; Encrypts and authenticates `plaintext`, returning ciphertext with
;; the authentication tag appended.
(define (aead-encrypt alg key nonce plaintext #:aad [aad #""])
  (define out (make-bytes (+ (bytes-length plaintext) (crypto-aead-tag-size alg))))
  (crypto-aead-seal! alg key nonce aad plaintext out)
  out)

;; Verifies and decrypts `ciphertext+tag`, returning the plaintext, or
;; #f if authentication fails. Failure is not distinguished by reason.
(define (aead-decrypt alg key nonce ciphertext+tag #:aad [aad #""])
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
          [aead-encrypt (->* (aead-algorithm/c bytes? bytes? bytes?)
                             (#:aad bytes?)
                             bytes?)]
          [aead-decrypt (->* (aead-algorithm/c bytes? bytes? bytes?)
                             (#:aad bytes?)
                             (or/c bytes? #f))]))

(define (aead-algorithms) algorithms)
