#lang racket/base

;; Throughput / latency benchmark for the built-in rktcrypto subsystem.
;;
;; Run with the in-tree Racket:
;;   racket/bin/racket racket/src/crypto/benchmarks/crypto-benchmark.rkt
;;
;; Reports MB/s for the streaming primitives (digests, AEAD, MAC) and
;; ops/s for the public-key and post-quantum primitives. This is the
;; performance-acceptance instrument for the crypto milestones: it is not
;; a pass/fail test, but a regression tripwire and a sanity check that
;; the from-scratch code is in the right ballpark (roughly OpenSSL-class
;; for the software paths, faster where the ARMv8 crypto extensions kick
;; in for SHA-256 and AES).

(require racket/crypto
         racket/format)

(define (now) (current-inexact-monotonic-milliseconds))

;; Time `thunk` repeatedly for at least `min-ms`, return seconds/op.
(define (time-per-op thunk #:min-ms [min-ms 400])
  (collect-garbage)
  (let loop ([iters 1])
    (define t0 (now))
    (for ([_ (in-range iters)]) (thunk))
    (define dt (- (now) t0))
    (if (< dt min-ms)
        (loop (* iters 2))
        (/ (/ dt 1000.0) iters))))

(define (mb/s bytes-per-op s/op)
  (/ (/ bytes-per-op 1048576.0) s/op))

(define (row label rhs) (printf "  ~a~a\n" (~a label #:min-width 34) rhs))

(define (bench-throughput label size thunk)
  (define s/op (time-per-op thunk))
  (row label (~a (~r (mb/s size s/op) #:precision 0) " MB/s")))

(define (bench-ops label thunk)
  (define s/op (time-per-op thunk))
  (row label (~a (~r (/ 1.0 s/op) #:precision 0) " ops/s"
                 "  (" (~r (* s/op 1e6) #:precision 1) " us/op)")))

(define SIZE (* 1 1024 1024))
(define data (make-bytes SIZE 97))
(define small (make-bytes 64 97))

(printf "\n=== rktcrypto benchmark (~a MiB blocks; ops/s over fresh keys) ===\n"
        (quotient SIZE 1048576))

(printf "\n[digests]\n")
(for ([alg '(sha1 md5 sha256 sha512 sha3-256 sha3-512 blake2b blake3)])
  (bench-throughput (~a alg) SIZE (lambda () (digest-bytes alg data))))

(printf "\n[MAC]\n")
(let ([key (make-bytes 32 1)])
  (bench-throughput "hmac-sha256" SIZE (lambda () (hmac-bytes 'sha256 key data)))
  (bench-throughput "siphash-2-4" SIZE (lambda () (siphash-2-4 (make-bytes 16 2) data))))

(printf "\n[AEAD, seal 1 MiB]\n")
(let ([k32 (make-bytes 32 3)])
  (bench-throughput "chacha20-poly1305"
                    SIZE (lambda () (aead-encrypt 'chacha20-poly1305 k32 (make-bytes 12 0) data)))
  (bench-throughput "xchacha20-poly1305"
                    SIZE (lambda () (aead-encrypt 'xchacha20-poly1305 k32 (make-bytes 24 0) data)))
  (bench-throughput "aes-256-gcm"
                    SIZE (lambda () (aead-encrypt 'aes-256-gcm k32 (make-bytes 12 0) data))))

(printf "\n[KDF]\n")
(let ([s/op (time-per-op (lambda () (pbkdf2 'sha256 #"password" #"salt" #:iterations 10000 #:length 32)))])
  (row "pbkdf2-hmac-sha256 (10k iters)" (~a (~r (* s/op 1000.0) #:precision 2) " ms")))
(let ([s/op (time-per-op #:min-ms 800
                         (lambda () (argon2id #"password" #"saltsalt" #:iterations 3
                                              #:memory 65536 #:parallelism 1 #:length 32)))])
  (row "argon2id (t=3, m=64MiB)" (~a (~r (* s/op 1000.0) #:precision 1) " ms")))

(printf "\n[classic public key]\n")
(let* ([a (x25519-generate-private-key)] [A (x25519-public-key a)]
       [b (x25519-generate-private-key)] [B (x25519-public-key b)])
  (bench-ops "x25519 keygen" (lambda () (x25519-public-key (x25519-generate-private-key))))
  (bench-ops "x25519 shared" (lambda () (x25519 a B))))
(let* ([sk (ed25519-generate-private-key)] [pk (ed25519-public-key sk)]
       [sig (ed25519-sign sk small)])
  (bench-ops "ed25519 sign" (lambda () (ed25519-sign sk small)))
  (bench-ops "ed25519 verify" (lambda () (ed25519-verify pk small sig))))
(let* ([sk (p256-generate-private-key)] [pk (p256-public-key sk)]
       [sig (p256-ecdsa-sign sk small)] [B (p256-public-key (p256-generate-private-key))])
  (bench-ops "p256 ecdh" (lambda () (p256-ecdh sk B)))
  (bench-ops "p256 ecdsa sign" (lambda () (p256-ecdsa-sign sk small)))
  (bench-ops "p256 ecdsa verify" (lambda () (p256-ecdsa-verify pk small sig))))

(printf "\n[post-quantum]\n")
(let*-values ([(ek dk) (mlkem768-generate-key)])
  (define-values (ct ss) (mlkem768-encaps ek))
  (bench-ops "ml-kem-768 keygen" (lambda () (mlkem768-generate-key)))
  (bench-ops "ml-kem-768 encaps" (lambda () (mlkem768-encaps ek)))
  (bench-ops "ml-kem-768 decaps" (lambda () (mlkem768-decaps ct dk))))
(let*-values ([(vk sk) (mldsa65-generate-key)])
  (define sig (mldsa65-sign sk small))
  (bench-ops "ml-dsa-65 keygen" (lambda () (mldsa65-generate-key)))
  (bench-ops "ml-dsa-65 sign" (lambda () (mldsa65-sign sk small)))
  (bench-ops "ml-dsa-65 verify" (lambda () (mldsa65-verify vk small sig))))
(let*-values ([(ek dk) (x25519mlkem768-generate-key)])
  (define-values (ct ss) (x25519mlkem768-encaps ek))
  (bench-ops "x25519mlkem768 keygen" (lambda () (x25519mlkem768-generate-key)))
  (bench-ops "x25519mlkem768 encaps" (lambda () (x25519mlkem768-encaps ek)))
  (bench-ops "x25519mlkem768 decaps" (lambda () (x25519mlkem768-decaps ct dk))))

(printf "\ndone.\n")
