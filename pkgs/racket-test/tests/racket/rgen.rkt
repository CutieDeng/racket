#lang racket/base

;; Tests for racket/random/generator (the rktrandom subsystem).

(require racket/random/generator
         racket/random
         racket/flonum
         racket/fixnum
         rackunit)

(when rktrandom-available?

  ;; known-answer: integer seeds match the C-level splitmix64
  ;; convention pinned by librktrandom's self-test
  (let ([g (make-rgen 42)])
    (check-equal? (rgen-u64 g) #xf08ee810b06b8f82))

  ;; reproducibility and stream separation
  (let ([g1 (make-rgen 12345)]
        [g2 (make-rgen 12345)]
        [g3 (make-rgen 12345 #:stream 1)])
    (check-equal? (for/list ([i 32]) (rgen-u64 g1))
                  (for/list ([i 32]) (rgen-u64 g2)))
    (check-not-equal? (rgen-u64 (make-rgen 12345)) (rgen-u64 g3)))

  ;; every algorithm works and streams differ
  (for ([alg (in-list (rgen-algorithms))])
    (define g (make-rgen 1 #:algorithm alg))
    (check-pred exact-nonnegative-integer? (rgen-u64 g) (format "~a" alg)))

  ;; bulk fill serializes the scalar stream
  (let ([ga (make-rgen 7)]
        [gb (make-rgen 7)])
    (check-equal? (rgen-bytes ga 24)
                  (apply bytes-append
                         (for/list ([i 3])
                           (integer->integer-bytes (rgen-u64 gb) 8 #f #f)))))

  ;; scalar draw ranges
  (let ([g (make-rgen 99)])
    (for ([i 1000])
      (check-true (fixnum? (rgen-fixnum g)))
      (let ([x (rgen-real g)]) (check-true (and (>= x 0.0) (< x 1.0))))
      (check-true (< (rgen-integer g 7) 7))
      (check-pred boolean? (rgen-boolean g)))
    ;; wide bound
    (check-true (< (rgen-integer g (expt 10 30)) (expt 10 30))))

  ;; distributions: crude moment checks (loose bounds; the tight
  ;; statistical validation lives in the C-level test harness)
  (let* ([g (make-rgen 5)]
         [n 200000]
         [nrm (rgen-flvector g n 'normal #:mu 10.0 #:sigma 2.0)]
         [ex (rgen-flvector g n 'exponential #:rate 4.0)]
         [mean (lambda (flv)
                 (/ (for/fold ([s 0.0]) ([x (in-flvector flv)]) (fl+ s x))
                    (exact->inexact (flvector-length flv))))])
    (check-= (mean nrm) 10.0 0.05)
    (check-= (mean ex) 0.25 0.01)
    (check-= (/ (for/fold ([s 0.0]) ([i (in-range n)]) (fl+ s (rgen-normal g)))
                (exact->inexact n))
             0.0 0.05)
    (check-= (/ (for/fold ([s 0.0]) ([i (in-range n)]) (fl+ s (rgen-exponential g 2.0)))
                (exact->inexact n))
             0.5 0.02))

  ;; bounded fills
  (let* ([g (make-rgen 11)]
         [fxv (rgen-fxvector g 10000 7)])
    (for ([x (in-fxvector fxv)])
      (check-true (and (fx>= x 0) (fx< x 7))))
    (let ([bs (make-bytes 800)])
      (rgen-bounded-bytes! g 1000 bs)
      (for ([i (in-range 100)])
        (check-true (< (integer-bytes->integer bs #f #f (* i 8) (* (add1 i) 8)) 1000)))))

  ;; deterministic distribution fills for a fixed seed (per platform)
  (let ([b1 (make-bytes 512)]
        [b2 (make-bytes 512)])
    (rgen-normal-bytes! (make-rgen 3) b1)
    (rgen-normal-bytes! (make-rgen 3) b2)
    (check-equal? b1 b2))

  ;; substreams
  (let ([g (make-rgen 21)])
    (define pre (rgen-u64 (rgen-copy g)))
    (rgen-jump! g)
    (check-not-equal? pre (rgen-u64 g)))
  (let* ([g (make-rgen 22)]
         [child (rgen-fork g)])
    (check-not-equal? (rgen-u64 g) (rgen-u64 child)))
  ;; sfc64 has no jump
  (check-exn exn:fail? (lambda () (rgen-jump! (make-rgen 1 #:algorithm 'sfc64))))

  ;; collection ops
  (let ([g (make-rgen 33)])
    (define v (build-vector 100 values))
    (rgen-shuffle! g v)
    (check-equal? (sort (vector->list v) <) (build-list 100 values))
    (check-not-false (member (rgen-ref g '(a b c)) '(a b c)) "rgen-ref")
    (check-true (< (rgen-weighted-index g #(1 2 3)) 3)))

  ;; racket/random interop
  (let ([g (make-rgen 44)])
    (check-not-false (member (random-ref '(1 2 3) g) '(1 2 3)) "random-ref/rgen")
    (check-equal? (length (random-sample (in-range 100) 5 g #:replacement? #f)) 5))

  ;; per-thread default
  (check-pred rgen? (current-rgen))
  (check-eq? (current-rgen) (current-rgen)))

(module+ test
  (module config info
    (define timeout 300)))
