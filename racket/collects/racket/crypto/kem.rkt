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

(provide MLKEM768-PUBLIC-KEY-BYTES
         MLKEM768-SECRET-KEY-BYTES
         MLKEM768-CIPHERTEXT-BYTES
         MLKEM768-SHARED-SECRET-BYTES
         (contract-out
          [mlkem768-generate-key (-> (values bytes? bytes?))]
          [mlkem768-encaps (-> bytes? (values bytes? bytes?))]
          [mlkem768-decaps (-> bytes? bytes? bytes?)]))
