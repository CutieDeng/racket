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
                  crypto-p256-ecdsa-verify
                  crypto-mldsa65-keypair
                  crypto-mldsa65-sign
                  crypto-mldsa65-verify))

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

;; ML-DSA-65 (Dilithium, FIPS 204): post-quantum signatures. A key pair
;; is a verification key (public, 1952 bytes) and a signing key (secret,
;; 4032 bytes); signatures are 3309 bytes. Signing is hedged (draws fresh
;; randomness), so `mldsa65-sign` of the same message varies -- this is
;; standard-conformant and does not weaken verification. The pure variant
;; with an empty context is used, interoperable with other FIPS 204
;; implementations.
(define (mldsa65-generate-key)
  (call-with-values crypto-mldsa65-keypair values))

(define (mldsa65-sign signing-key message)
  (crypto-mldsa65-sign signing-key message))

(define (mldsa65-verify verify-key message signature)
  (crypto-mldsa65-verify verify-key message signature))

(provide MLDSA65-PUBLIC-KEY-BYTES
         MLDSA65-SECRET-KEY-BYTES
         MLDSA65-SIGNATURE-BYTES
         (contract-out
          [ed25519-generate-private-key (-> bytes?)]
          [ed25519-public-key (-> bytes? bytes?)]
          [ed25519-sign (-> bytes? bytes? bytes?)]
          [ed25519-verify (-> bytes? bytes? bytes? boolean?)]
          [p256-ecdsa-sign (-> bytes? bytes? bytes?)]
          [p256-ecdsa-verify (-> bytes? bytes? bytes? boolean?)]
          [mldsa65-generate-key (-> (values bytes? bytes?))]
          [mldsa65-sign (-> bytes? bytes? bytes?)]
          [mldsa65-verify (-> bytes? bytes? bytes? boolean?)]))

(define MLDSA65-PUBLIC-KEY-BYTES 1952)
(define MLDSA65-SECRET-KEY-BYTES 4032)
(define MLDSA65-SIGNATURE-BYTES 3309)
