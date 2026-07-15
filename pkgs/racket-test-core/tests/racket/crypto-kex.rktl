
(load-relative "loadtest.rktl")

(Section 'crypto-kex)

(require racket/crypto
         file/sha1)

(define (unhex s) (hex-string->bytes s))

;; ----------------------------------------
;; X25519 (RFC 7748 Section 6.1 test vector)

(define alice-priv (unhex "77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a"))
(define alice-pub  (unhex "8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a"))
(define bob-priv   (unhex "5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb"))
(define bob-pub    (unhex "de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f"))
(define shared     (unhex "4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742"))

;; Public keys derived from private keys match the RFC.
(test alice-pub x25519-public-key alice-priv)
(test bob-pub   x25519-public-key bob-priv)

;; Both sides compute the same shared secret (RFC value).
(test shared x25519 alice-priv bob-pub)
(test shared x25519 bob-priv alice-pub)

;; ----------------------------------------
;; Diffie-Hellman consistency with fresh random keys

(for ([i (in-range 20)])
  (define a (x25519-generate-private-key))
  (define b (x25519-generate-private-key))
  (define A (x25519-public-key a))
  (define B (x25519-public-key b))
  (test 32 bytes-length a)
  (test 32 bytes-length A)
  ;; shared secrets agree
  (test (x25519 a B) values (x25519 b A)))

;; different keypairs give different shared secrets
(let ([a (x25519-generate-private-key)]
      [b (x25519-generate-private-key)]
      [c (x25519-generate-private-key)])
  (test #f equal? (x25519 a (x25519-public-key b)) (x25519 a (x25519-public-key c))))

;; ----------------------------------------
;; Low-order point yields #f (all-zero shared secret)

(test #f x25519 (x25519-generate-private-key) (make-bytes 32 0))

;; ----------------------------------------
;; P-256 ECDH

;; public key from priv = 01 02 .. 20 (verified against OpenSSL)
(test (string-append "04515c3d6eb9e396b904d3feca7f54fdcd0cc1e997bf375dca515ad0a6c3b403"
                     "5f4536be3a50f318fbf9a5475902a221502bef0d57e08c53b2cc0a56f17d9f9354")
      bytes->hex-string (p256-public-key (list->bytes (for/list ([i (in-range 32)]) (add1 i)))))

;; Diffie-Hellman consistency with fresh random keys
(for ([i (in-range 15)])
  (define a (p256-generate-private-key))
  (define b (p256-generate-private-key))
  (define A (p256-public-key a))
  (define B (p256-public-key b))
  (test 32 bytes-length a)
  (test 65 bytes-length A)
  (test 4 bytes-ref A 0)   ; uncompressed marker
  (test (p256-ecdh a B) values (p256-ecdh b A)))

;; different keypairs give different shared secrets
(let ([a (p256-generate-private-key)]
      [b (p256-generate-private-key)]
      [c (p256-generate-private-key)])
  (test #f equal? (p256-ecdh a (p256-public-key b)) (p256-ecdh a (p256-public-key c))))

;; malformed peer point -> #f
(test #f p256-ecdh (p256-generate-private-key) (make-bytes 64 0))

;; ----------------------------------------
;; Negative cases

(err/rt-test (x25519 (make-bytes 16) (make-bytes 32)) exn:fail?)   ; wrong scalar size
(err/rt-test (x25519 (make-bytes 32) (make-bytes 31)) exn:fail?)   ; wrong point size
(err/rt-test (x25519-public-key "not bytes") exn:fail:contract?)

(report-errs)
