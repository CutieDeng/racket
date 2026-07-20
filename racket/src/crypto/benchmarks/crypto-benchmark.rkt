#lang racket/base

;; Throughput / latency benchmark for the built-in rktcrypto subsystem.
;;
;; Run with the in-tree Racket:
;;   racket/bin/racket racket/src/crypto/benchmarks/crypto-benchmark.rkt
;;
;; Reports MB/s for the streaming primitives (digests, AEAD, MAC) and
;; ops/s for the public-key and post-quantum primitives. Roughly
;; OpenSSL-class for the software paths, faster where the ARMv8 crypto
;; extensions kick in (SHA-256, AES).
;;
;; Performance-regression mode (the tripwire that guards the OpenSSL
;; removal from silent throughput loss):
;;   ... crypto-benchmark.rkt --update-baseline   ; record current numbers
;;   ... crypto-benchmark.rkt --check             ; fail if any metric
;;                                                ; regressed > tolerance
;; The baseline lives next to this script as crypto-benchmark-baseline.rktd
;; and is machine-local (absolute MB/s vary by host); --check compares a
;; fresh run to it, so run --update-baseline once per machine/build.

(require racket/crypto
         racket/format
         racket/runtime-path
         racket/list)

(define-runtime-path baseline-path "crypto-benchmark-baseline.rktd")

;; Regression tolerance: --check fails a metric that is more than this
;; fraction slower than baseline (0.20 = 20% slower). Loose enough to
;; ride out normal run-to-run noise, tight enough to catch a real drop.
(define TOLERANCE 0.20)

;; CLI mode
(define mode
  (let ([args (current-command-line-arguments)])
    (cond
      [(and (positive? (vector-length args)) (equal? (vector-ref args 0) "--check")) 'check]
      [(and (positive? (vector-length args)) (equal? (vector-ref args 0) "--update-baseline")) 'update]
      [else 'report])))

;; Every bench records (label . value); value is "higher is better" for
;; throughput/ops, and we store the metric kind so --check knows the
;; direction. Latency rows (ms) are lower-is-better.
(define results '())   ; list of (vector label kind value) newest-first
(define (record! label kind value) (set! results (cons (vector label kind value) results)))

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

(define (row label rhs) (when (eq? mode 'report) (printf "  ~a~a\n" (~a label #:min-width 34) rhs)))

(define (bench-throughput label size thunk)
  (define s/op (time-per-op thunk))
  (record! label 'higher (mb/s size s/op))
  (row label (~a (~r (mb/s size s/op) #:precision 0) " MB/s")))

(define (bench-ops label thunk)
  (define s/op (time-per-op thunk))
  (record! label 'higher (/ 1.0 s/op))
  (row label (~a (~r (/ 1.0 s/op) #:precision 0) " ops/s"
                 "  (" (~r (* s/op 1e6) #:precision 1) " us/op)")))

;; latency metric (ms), lower is better
(define (bench-latency label thunk #:min-ms [min-ms 400])
  (define s/op (time-per-op thunk #:min-ms min-ms))
  (record! label 'lower (* s/op 1000.0))
  (row label (~a (~r (* s/op 1000.0) #:precision 2) " ms")))

(define SIZE (* 1 1024 1024))
(define data (make-bytes SIZE 97))
(define small (make-bytes 64 97))

(printf "\n=== rktcrypto benchmark (~a MiB blocks; ops/s over fresh keys) ===\n"
        (quotient SIZE 1048576))

(printf "\n[digests]\n")
(for ([alg '(sha1 md5 md4 sha256 sha512 sha3-256 sha3-512 blake2b blake3
             ripemd160 sm3 whirlpool)])
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
(bench-latency "pbkdf2-hmac-sha256 (10k iters)"
               (lambda () (pbkdf2 'sha256 #"password" #"salt" #:iterations 10000 #:length 32)))
(bench-latency "argon2id (t=3, m=64MiB)" #:min-ms 800
               (lambda () (argon2id #"password" #"saltsalt" #:iterations 3
                                    #:memory 65536 #:parallelism 1 #:length 32)))

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

;; ---- regression driver ------------------------------------------------

(define (results->hash) (for/hash ([r (in-list results)]) (values (vector-ref r 0) (vector-ref r 2))))

(define (write-baseline!)
  (call-with-output-file baseline-path #:exists 'replace
    (lambda (o)
      (write (for/list ([r (in-list (reverse results))])
               (list (vector-ref r 0) (vector-ref r 1) (vector-ref r 2)))
             o)
      (newline o)))
  (printf "\nwrote baseline: ~a metrics -> ~a\n" (length results) baseline-path))

(define (check-baseline!)
  (unless (file-exists? baseline-path)
    (eprintf "no baseline at ~a; run --update-baseline first\n" baseline-path)
    (exit 2))
  (define base (with-input-from-file baseline-path read))   ; list of (label kind value)
  (define cur (results->hash))
  (define regressions '())
  (printf "\n=== performance regression check (tolerance ~a%) ===\n" (inexact->exact (round (* 100 TOLERANCE))))
  (for ([b (in-list base)])
    (define label (car b))
    (define kind (cadr b))
    (define want (caddr b))
    (define got (hash-ref cur label #f))
    (when got
      ;; ratio > 1 means current is better; regressed if worse than tolerance
      (define ratio (if (eq? kind 'lower) (/ want got) (/ got want)))
      (define regressed? (< ratio (- 1.0 TOLERANCE)))
      (when regressed?
        (set! regressions (cons (list label want got ratio) regressions))
        (printf "  REGRESS ~a: baseline ~a, now ~a (~a% of baseline)\n"
                (~a label #:min-width 30) (~r want #:precision 1) (~r got #:precision 1)
                (~r (* 100 ratio) #:precision 0)))))
  (cond
    [(null? regressions) (printf "  OK: no metric regressed beyond ~a%\n" (inexact->exact (round (* 100 TOLERANCE))))]
    [else
     (printf "  ~a metric(s) regressed\n" (length regressions))
     (exit 1)]))

(case mode
  [(update) (write-baseline!)]
  [(check)  (check-baseline!)]
  [else     (printf "\ndone.\n")])
