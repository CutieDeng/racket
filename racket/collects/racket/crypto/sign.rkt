#lang racket/base

;; Digital signatures over the built-in elliptic curves.
;;
;; Ed25519 (RFC 8032): a private key is a 32-byte seed; the public key
;; and signatures are 32 and 64 bytes.

(require racket/contract/base
         "random.rkt"
         "kex.rkt"
         (only-in '#%kernel
                  crypto-ed25519-public-key
                  crypto-ed25519-sign
                  crypto-ed25519-verify
                  crypto-p256-ecdsa-sign
                  crypto-p256-ecdsa-verify))

;; Generates a fresh 32-byte Ed25519 private key (seed).
(define (ed25519-generate-private-key)
  (crypto-random-bytes 32))

;; Derives the 32-byte public key for a private key.
(define (ed25519-public-key private-key)
  (crypto-ed25519-public-key private-key))

;; Signs `message` with `private-key`, returning a 64-byte signature.
(define (ed25519-sign private-key message)
  (crypto-ed25519-sign private-key message))

;; Verifies `signature` over `message` under `public-key`.
(define (ed25519-verify public-key message signature)
  (crypto-ed25519-verify public-key message signature))

;; P-256 (NIST secp256r1) ECDSA with SHA-256. Private keys and key
;; generation come from racket/crypto/kex (p256-generate-private-key /
;; p256-public-key); a public key is a 65-byte uncompressed point.
(define (p256-ecdsa-sign private-key message)
  (crypto-p256-ecdsa-sign private-key message))

(define (p256-ecdsa-verify public-key message signature)
  (crypto-p256-ecdsa-verify public-key message signature))

(provide (contract-out
          [ed25519-generate-private-key (-> bytes?)]
          [ed25519-public-key (-> bytes? bytes?)]
          [ed25519-sign (-> bytes? bytes? bytes?)]
          [ed25519-verify (-> bytes? bytes? bytes? boolean?)]
          [p256-ecdsa-sign (-> bytes? bytes? bytes?)]
          [p256-ecdsa-verify (-> bytes? bytes? bytes? boolean?)]))
