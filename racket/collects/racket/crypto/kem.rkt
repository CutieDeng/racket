#lang racket/base

;; Post-quantum key encapsulation.
;;
;; ML-KEM-768 (FIPS 203), the NIST-standardized lattice KEM derived
;; from CRYSTALS-Kyber. A key pair is an encapsulation key (public,
;; 1184 bytes) and a decapsulation key (secret, 2400 bytes). Encapsulation
;; against a public key produces a 1088-byte ciphertext and a 32-byte
;; shared secret; the holder of the secret key recovers the same shared
;; secret from the ciphertext. Category-3 security (comparable to
;; AES-192) against both classical and quantum attackers.
;;
;; The KEM uses implicit rejection: `mlkem768-decaps` never signals an
;; error on a malformed ciphertext, returning a pseudorandom secret
;; instead. This is by design (it removes a decryption-failure oracle);
;; the shared secret only agrees when the ciphertext was honestly
;; produced against the matching public key.

(require racket/contract/base
         "kex.rkt"
         (only-in '#%kernel
                  crypto-mlkem768-keypair
                  crypto-mlkem768-encaps
                  crypto-mlkem768-decaps))

(define MLKEM768-PUBLIC-KEY-BYTES 1184)
(define MLKEM768-SECRET-KEY-BYTES 2400)
(define MLKEM768-CIPHERTEXT-BYTES 1088)
(define MLKEM768-SHARED-SECRET-BYTES 32)

;; Generates a fresh key pair, returning (values public-key secret-key).
(define (mlkem768-generate-key)
  (call-with-values crypto-mlkem768-keypair values))

;; Encapsulates to a public (encapsulation) key, returning
;; (values ciphertext shared-secret).
(define (mlkem768-encaps public-key)
  (unless (= (bytes-length public-key) MLKEM768-PUBLIC-KEY-BYTES)
    (error 'mlkem768-encaps "encapsulation key must be ~a bytes; given ~a"
           MLKEM768-PUBLIC-KEY-BYTES (bytes-length public-key)))
  (call-with-values (lambda () (crypto-mlkem768-encaps public-key)) values))

;; Decapsulates a ciphertext with a secret (decapsulation) key,
;; returning the 32-byte shared secret. Implicit rejection: a malformed
;; ciphertext yields a pseudorandom secret rather than an error.
(define (mlkem768-decaps ciphertext secret-key)
  (or (crypto-mlkem768-decaps ciphertext secret-key)
      (error 'mlkem768-decaps
             "ciphertext must be ~a bytes and secret key ~a bytes"
             MLKEM768-CIPHERTEXT-BYTES MLKEM768-SECRET-KEY-BYTES)))

;; ----------------------------------------
;; X25519MLKEM768 hybrid KEM (draft-ietf-tls-ecdhe-mlkem).
;;
;; Combines ML-KEM-768 with X25519 so that the shared secret stays secure
;; as long as *either* component does -- classical safety today plus
;; post-quantum safety against a future quantum attacker ("harvest now,
;; decrypt later"). This is the construction TLS 1.3 negotiates under the
;; X25519MLKEM768 group. Everything is plain concatenation, in the wire
;; order fixed by the draft (ML-KEM first): the encapsulation key is
;; ml-kem-ek || x25519-pub, the ciphertext is ml-kem-ct || x25519-ephem,
;; and the shared secret is ml-kem-ss || x25519-ss (no extra KDF -- the
;; consumer, e.g. the TLS key schedule, does that). Interoperable with
;; OpenSSL's X25519MLKEM768.

(define X25519MLKEM768-PUBLIC-KEY-BYTES (+ 1184 32))     ; 1216
(define X25519MLKEM768-SECRET-KEY-BYTES (+ 2400 32))     ; 2432
(define X25519MLKEM768-CIPHERTEXT-BYTES (+ 1088 32))     ; 1120
(define X25519MLKEM768-SHARED-SECRET-BYTES (+ 32 32))    ; 64

;; Generates a hybrid key pair, returning (values encaps-key decaps-key).
(define (x25519mlkem768-generate-key)
  (define-values (mlek mldk) (mlkem768-generate-key))
  (define xsk (x25519-generate-private-key))
  (define xpk (x25519-public-key xsk))
  (values (bytes-append mlek xpk) (bytes-append mldk xsk)))

;; Encapsulates to a hybrid encapsulation key, returning
;; (values ciphertext shared-secret).
(define (x25519mlkem768-encaps ek)
  (unless (= (bytes-length ek) X25519MLKEM768-PUBLIC-KEY-BYTES)
    (error 'x25519mlkem768-encaps "encapsulation key must be ~a bytes; given ~a"
           X25519MLKEM768-PUBLIC-KEY-BYTES (bytes-length ek)))
  (define mlek (subbytes ek 0 1184))
  (define xpk-peer (subbytes ek 1184 1216))
  (define-values (mlct mlss) (mlkem768-encaps mlek))
  (define xsk (x25519-generate-private-key))
  (define xct (x25519-public-key xsk))
  (define xss (x25519 xsk xpk-peer))
  (unless xss (error 'x25519mlkem768-encaps "peer X25519 key is a low-order point"))
  (values (bytes-append mlct xct) (bytes-append mlss xss)))

;; Decapsulates a hybrid ciphertext with a hybrid decapsulation key,
;; returning the 64-byte shared secret. The ML-KEM half uses implicit
;; rejection; a malformed X25519 half (low-order ephemeral) errors.
(define (x25519mlkem768-decaps ct dk)
  (unless (= (bytes-length ct) X25519MLKEM768-CIPHERTEXT-BYTES)
    (error 'x25519mlkem768-decaps "ciphertext must be ~a bytes; given ~a"
           X25519MLKEM768-CIPHERTEXT-BYTES (bytes-length ct)))
  (unless (= (bytes-length dk) X25519MLKEM768-SECRET-KEY-BYTES)
    (error 'x25519mlkem768-decaps "decapsulation key must be ~a bytes; given ~a"
           X25519MLKEM768-SECRET-KEY-BYTES (bytes-length dk)))
  (define mldk (subbytes dk 0 2400))
  (define xsk (subbytes dk 2400 2432))
  (define mlct (subbytes ct 0 1088))
  (define xct (subbytes ct 1088 1120))
  (define mlss (mlkem768-decaps mlct mldk))
  (define xss (x25519 xsk xct))
  (unless xss (error 'x25519mlkem768-decaps "X25519 ephemeral is a low-order point"))
  (bytes-append mlss xss))

(provide MLKEM768-PUBLIC-KEY-BYTES
         MLKEM768-SECRET-KEY-BYTES
         MLKEM768-CIPHERTEXT-BYTES
         MLKEM768-SHARED-SECRET-BYTES
         X25519MLKEM768-PUBLIC-KEY-BYTES
         X25519MLKEM768-SECRET-KEY-BYTES
         X25519MLKEM768-CIPHERTEXT-BYTES
         X25519MLKEM768-SHARED-SECRET-BYTES
         (contract-out
          [mlkem768-generate-key (-> (values bytes? bytes?))]
          [mlkem768-encaps (-> bytes? (values bytes? bytes?))]
          [mlkem768-decaps (-> bytes? bytes? bytes?)]
          [x25519mlkem768-generate-key (-> (values bytes? bytes?))]
          [x25519mlkem768-encaps (-> bytes? (values bytes? bytes?))]
          [x25519mlkem768-decaps (-> bytes? bytes? bytes?)]))
