
(load-relative "loadtest.rktl")

(Section 'crypto-aead)

(require racket/crypto
         file/sha1)

;; ----------------------------------------
;; ChaCha20-Poly1305 (RFC 8439 2.8.2)

(define rfc-key (list->bytes (for/list ([i (in-range 32)]) (+ #x80 i))))
(define rfc-nonce (bytes #x07 0 0 0 #x40 #x41 #x42 #x43 #x44 #x45 #x46 #x47))
(define rfc-aad (bytes #x50 #x51 #x52 #x53 #xc0 #xc1 #xc2 #xc3 #xc4 #xc5 #xc6 #xc7))
(define rfc-pt #"Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it.")

(define rfc-sealed
  (aead-encrypt 'chacha20-poly1305 rfc-key rfc-nonce rfc-pt #:aad rfc-aad))

(test "1ae10b594f09e26a7e902ecbd0600691"
      bytes->hex-string (subbytes rfc-sealed (bytes-length rfc-pt)))
(test "d31a8d34648e60db7b86afbc53ef7ec2"
      bytes->hex-string (subbytes rfc-sealed 0 16))
;; round-trip
(test rfc-pt aead-decrypt 'chacha20-poly1305 rfc-key rfc-nonce rfc-sealed #:aad rfc-aad)

;; sizes
(test 32 aead-key-size 'chacha20-poly1305)
(test 12 aead-nonce-size 'chacha20-poly1305)
(test 16 aead-tag-size 'chacha20-poly1305)
(test 24 aead-nonce-size 'xchacha20-poly1305)

;; ----------------------------------------
;; AES-256-GCM (NIST vectors)

;; all-zero key/nonce, empty plaintext -> tag 530f8afb...
(test "530f8afbc74536b9a963b4f1c4cb738b"
      bytes->hex-string
      (aead-encrypt 'aes-256-gcm (make-bytes 32 0) (make-bytes 12 0) #""))
;; all-zero key/nonce, 16 zero bytes -> ct cea7403d..., tag d0d1c8a7...
(test "cea7403d4d606b6e074ec5d3baf39d18d0d1c8a799996bf0265b98b5d48ab919"
      bytes->hex-string
      (aead-encrypt 'aes-256-gcm (make-bytes 32 0) (make-bytes 12 0) (make-bytes 16 0)))
(test 32 aead-key-size 'aes-256-gcm)
(test 12 aead-nonce-size 'aes-256-gcm)
(test 16 aead-tag-size 'aes-256-gcm)

;; AES-256-GCM round-trips across sizes and AAD
(let ([k (make-bytes 32 5)] [n (make-bytes 12 9)])
  (for ([len (list 0 1 15 16 17 64 100)])
    (define pt (make-bytes len (modulo (* len 3) 256)))
    (define aad (make-bytes (modulo len 7) 4))
    (define ct (aead-encrypt 'aes-256-gcm k n pt #:aad aad))
    (test pt aead-decrypt 'aes-256-gcm k n ct #:aad aad))
  ;; tampering rejected
  (let ([ct (aead-encrypt 'aes-256-gcm k n #"secret data here")])
    (bytes-set! ct 0 (bitwise-xor (bytes-ref ct 0) 1))
    (test #f aead-decrypt 'aes-256-gcm k n ct)))

;; ----------------------------------------
;; XChaCha20-Poly1305 round-trips across sizes and AAD

(let ([k (make-bytes 32 7)]
      [n (make-bytes 24 3)])
  (for ([len (list 0 1 15 16 17 63 64 65 1000)])
    (define pt (make-bytes len (modulo len 256)))
    (define aad (make-bytes (modulo len 13) 9))
    (define ct (aead-encrypt 'xchacha20-poly1305 k n pt #:aad aad))
    (test pt aead-decrypt 'xchacha20-poly1305 k n ct #:aad aad)))

;; ----------------------------------------
;; Negative cases (Wycheproof-style)

;; truncated tag / too-short input
(test #f aead-decrypt 'chacha20-poly1305 rfc-key rfc-nonce #"short" #:aad rfc-aad)
(test #f aead-decrypt 'chacha20-poly1305 rfc-key rfc-nonce (subbytes rfc-sealed 0 (sub1 (bytes-length rfc-sealed))) #:aad rfc-aad)
;; flipped ciphertext byte
(let ([bad (bytes-copy rfc-sealed)])
  (bytes-set! bad 0 (bitwise-xor (bytes-ref bad 0) 1))
  (test #f aead-decrypt 'chacha20-poly1305 rfc-key rfc-nonce bad #:aad rfc-aad))
;; flipped tag byte
(let ([bad (bytes-copy rfc-sealed)])
  (bytes-set! bad (sub1 (bytes-length bad)) (bitwise-xor (bytes-ref bad (sub1 (bytes-length bad))) 1))
  (test #f aead-decrypt 'chacha20-poly1305 rfc-key rfc-nonce bad #:aad rfc-aad))
;; wrong AAD
(test #f aead-decrypt 'chacha20-poly1305 rfc-key rfc-nonce rfc-sealed #:aad #"different")
;; wrong key / nonce
(test #f aead-decrypt 'chacha20-poly1305 (make-bytes 32 0) rfc-nonce rfc-sealed #:aad rfc-aad)
(test #f aead-decrypt 'chacha20-poly1305 rfc-key (make-bytes 12 0) rfc-sealed #:aad rfc-aad)

;; bad argument sizes / algorithm
(err/rt-test (aead-encrypt 'chacha20-poly1305 (make-bytes 16) rfc-nonce #"x") exn:fail?)
(err/rt-test (aead-encrypt 'chacha20-poly1305 rfc-key (make-bytes 8) #"x") exn:fail?)
(err/rt-test (aead-encrypt 'aes-gcm rfc-key rfc-nonce #"x") exn:fail:contract?)

;; ----------------------------------------
;; secretbox (high-level, auto nonce, misuse-resistant)

(let ([key (secretbox-key)])
  (test 32 bytes-length key)
  (for ([msg (list #"" #"hello" (make-bytes 5000 42))])
    (define sealed (secretbox-encrypt key msg))
    ;; sealed carries version + 24-byte nonce + ciphertext + 16-byte tag
    (test (+ 1 24 (bytes-length msg) 16) bytes-length sealed)
    (test msg secretbox-decrypt key sealed))
  ;; fresh nonce each time: two seals of the same message differ
  (test #f equal? (secretbox-encrypt key #"same") (secretbox-encrypt key #"same"))
  ;; wrong key fails
  (test #f secretbox-decrypt (secretbox-key) (secretbox-encrypt key #"secret"))
  ;; tampering fails
  (let ([s (secretbox-encrypt key #"secret")])
    (bytes-set! s 30 (bitwise-xor (bytes-ref s 30) 1))
    (test #f secretbox-decrypt key s))
  ;; bad version byte fails
  (let ([s (secretbox-encrypt key #"secret")])
    (bytes-set! s 0 99)
    (test #f secretbox-decrypt key s))
  ;; malformed (too short) fails
  (test #f secretbox-decrypt key #"tiny")
  ;; AAD binding
  (let ([s (secretbox-encrypt key #"payload" #:aad #"context")])
    (test #"payload" secretbox-decrypt key s #:aad #"context")
    (test #f secretbox-decrypt key s #:aad #"wrong")))

(report-errs)
