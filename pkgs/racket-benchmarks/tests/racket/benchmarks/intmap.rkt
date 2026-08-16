#lang racket/base

(require racket/cmdline
         racket/intmap
         (prefix-in adapter: racket/private/intmap-runtime-adapter
         ) ; end prefix-in
) ; end require

(define N 10000
) ; end define
(define suite 'quick
) ; end define
(define gate? #f
) ; end define

(define (parse-positive who s
        ) ; end parse-positive
  (define n (string->number s
            ) ; end string->number
  ) ; end define
  (unless (exact-positive-integer? n
          ) ; end exact-positive-integer?
    (raise-user-error who "expected a positive exact integer, got ~e" s
    ) ; end raise-user-error
  ) ; end unless
  n
) ; end define

(define (parse-suite s
        ) ; end parse-suite
  (define sym (string->symbol s
              ) ; end string->symbol
  ) ; end define
  (unless (memq sym '(quick full
                     ) ; end quick
          ) ; end memq
    (raise-user-error '--suite "expected quick or full, got ~e" s
    ) ; end raise-user-error
  ) ; end unless
  sym
) ; end define

(command-line
 #:program "intmap"
 #:once-each
 [("--gate") "Check result correctness and loose performance thresholds"
             (set! gate? #t
             ) ; end set!
 ] ; end clause
 [("--suite") s "Benchmark suite: quick or full"
              (set! suite (parse-suite s
                          ) ; end parse-suite
              ) ; end set!
 ] ; end s
 [("--n") n "Number of entries/probes"
          (set! N (parse-positive '--n n
                  ) ; end parse-positive
          ) ; end set!
 ] ; end n
 #:args maybe-n
 (when (pair? maybe-n
       ) ; end pair?
   (set! N (parse-positive 'intmap (car maybe-n
                                   ) ; end car
           ) ; end parse-positive
   ) ; end set!
 ) ; end when
) ; end command-line

(struct sample (name impl cpu real gc live result) #:transparent
) ; end struct

(define (sum-n n
        ) ; end sum-n
  (quotient (* n (sub1 n)) 2
  ) ; end quotient
) ; end define

(define (range-count n
        ) ; end range-count
  (for/sum ([i (in-range 0 n 32
               ) ; end in-range
            ] ; end i
           ) ; end form
    (min 16 (- n i
            ) ; end -
    ) ; end min
  ) ; end for/sum
) ; end define

(define (range-sum n
        ) ; end range-sum
  (for/sum ([i (in-range 0 n 32
               ) ; end in-range
            ] ; end i
           ) ; end form
    (for/sum ([j (in-range i (min n (+ i 16
                                    ) ; end +
                             ) ; end min
                 ) ; end in-range
              ] ; end j
             ) ; end form
      j
    ) ; end for/sum
  ) ; end for/sum
) ; end define

(define (vector-entry< vec key
        ) ; end vector-entry<
  (let loop ([lo 0] [hi (vector-length vec)] [best #f
                                             ] ; end best
            ) ; end form
    (if (= lo hi
        ) ; end =
        best
        (let* ([mid (quotient (+ lo hi) 2
                    ) ; end quotient
               ] ; end mid
               [entry (vector-ref vec mid
                      ) ; end vector-ref
               ] ; end entry
               [k (car entry
                  ) ; end car
               ] ; end k
              ) ; end form
          (if (< k key
              ) ; end <
              (loop (add1 mid) hi entry
              ) ; end loop
              (loop lo mid best
              ) ; end loop
          ) ; end if
        ) ; end let*
    ) ; end if
  ) ; end let
) ; end define

(define (bench name impl thunk
        ) ; end bench
  (collect-garbage
  ) ; end collect-garbage
  (collect-garbage
  ) ; end collect-garbage
  (define before-bytes (current-memory-use
                       ) ; end current-memory-use
  ) ; end define
  (define start (current-inexact-milliseconds
                ) ; end current-inexact-milliseconds
  ) ; end define
  (define-values (vals cpu real gc) (time-apply thunk null
                                    ) ; end time-apply
  ) ; end define-values
  (define elapsed (- (current-inexact-milliseconds) start
                  ) ; end -
  ) ; end define
  (define result (if (pair? vals) (car vals) (void
                                             ) ; end void
                 ) ; end if
  ) ; end define
  (collect-garbage
  ) ; end collect-garbage
  (define live (- (current-memory-use) before-bytes
               ) ; end -
  ) ; end define
  (printf "~a\t~a\t~a\t~a\t~a\t~a\t~s\n"
          name impl cpu elapsed gc live result
  ) ; end printf
  (flush-output
  ) ; end flush-output
  (sample name impl cpu elapsed gc live result
  ) ; end sample
) ; end define

(define (time<=factor? elapsed baseline factor
        ) ; end time<=factor?
  (or (<= elapsed (* factor baseline
                  ) ; end *
      ) ; end <=
      (and (< baseline 0.001) (< elapsed 1.0
                              ) ; end <
      ) ; end and
  ) ; end or
) ; end define

(define (find-sample samples name impl
        ) ; end find-sample
  (for/first ([s (in-list samples
                 ) ; end in-list
              ] ; end s
              #:when (and (eq? (sample-name s) name
                          ) ; end eq?
                          (eq? (sample-impl s) impl
                          ) ; end eq?
                     ) ; end and
             ) ; end :when
    s
  ) ; end for/first
) ; end define

(define (sample-real-ref samples name impl
        ) ; end sample-real-ref
  (sample-real (find-sample samples name impl
               ) ; end find-sample
  ) ; end sample-real
) ; end define

(define (ratio samples name-a impl-a name-b impl-b
        ) ; end ratio
  (define b (sample-real-ref samples name-b impl-b
            ) ; end sample-real-ref
  ) ; end define
  (if (zero? b
      ) ; end zero?
      +inf.0
      (/ (sample-real-ref samples name-a impl-a) b
      ) ; end /
  ) ; end if
) ; end define

(define (print-ratio samples label name-a impl-a name-b impl-b
        ) ; end print-ratio
  (printf "finding\t~a\t~a\n"
          label
          (let ([r (ratio samples name-a impl-a name-b impl-b
                   ) ; end ratio
                ] ; end r
               ) ; end form
            (if (rational? r
                ) ; end rational?
                (real->decimal-string r 2
                ) ; end real->decimal-string
                (format "~a" r
                ) ; end format
            ) ; end if
          ) ; end let
  ) ; end printf
) ; end define

(define (run-suite
        ) ; end run-suite
  (define big (arithmetic-shift 1 80
              ) ; end arithmetic-shift
  ) ; end define
  (define n N
  ) ; end define
  (define expected-sum (sum-n n
                       ) ; end sum-n
  ) ; end define
  (define entries
    (for/list ([i (in-range n
                  ) ; end in-range
               ] ; end i
              ) ; end form
      (cons i i
      ) ; end cons
    ) ; end for/list
  ) ; end define
  (define vec (list->vector entries
              ) ; end list->vector
  ) ; end define
  (define im (sorted-vector->intmap vec
             ) ; end sorted-vector->intmap
  ) ; end define
  (define ht (for/hash ([p (in-list entries
                           ) ; end in-list
                        ] ; end p
                       ) ; end form
               (values (car p) (cdr p
                               ) ; end cdr
               ) ; end values
             ) ; end for/hash
  ) ; end define
  (define big-entries
    (for/list ([i (in-range n
                  ) ; end in-range
               ] ; end i
              ) ; end form
      (cons (+ big i) i
      ) ; end cons
    ) ; end for/list
  ) ; end define
  (define big-vec (list->vector big-entries
                  ) ; end list->vector
  ) ; end define
  (define big-im (sorted-vector->intmap big-vec
                 ) ; end sorted-vector->intmap
  ) ; end define
  (define big-ht (for/hash ([p (in-list big-entries
                               ) ; end in-list
                            ] ; end p
                           ) ; end form
                   (values (car p) (cdr p
                                   ) ; end cdr
                   ) ; end values
                 ) ; end for/hash
  ) ; end define
  (define half (quotient n 2
               ) ; end quotient
  ) ; end define
  (define mixed-entries
    (append
     (for/list ([i (in-range half
                   ) ; end in-range
                ] ; end i
               ) ; end form
       (cons i i
       ) ; end cons
     ) ; end for/list
     (for/list ([i (in-range (- n half
                             ) ; end -
                   ) ; end in-range
                ] ; end i
               ) ; end form
       (cons (+ big i) (+ half i
                       ) ; end +
       ) ; end cons
     ) ; end for/list
    ) ; end append
  ) ; end define
  (define mixed-im (sorted-list->intmap mixed-entries
                   ) ; end sorted-list->intmap
  ) ; end define

  (printf "intmap benchmark n=~a backend=~a suite=~a\n"
          n
          (adapter:intmap-runtime-adapter-backend
          ) ; end adapter:intmap-runtime-adapter-backend
          suite
  ) ; end printf
  (printf "case\timpl\tcpu-ms\treal-ms\tgc-ms\tlive-bytes\tresult\n"
  ) ; end printf

  (define samples
    (append
     (list
      (bench 'lookup-fixnum 'intmap
             (lambda (
                     ) ; end form
               (for/fold ([acc 0]) ([i (in-range n
                                       ) ; end in-range
                                    ] ; end i
                                   ) ; end form
                 (+ acc (intmap-ref im i
                        ) ; end intmap-ref
                 ) ; end +
               ) ; end for/fold
             ) ; end lambda
      ) ; end bench
      (bench 'lookup-fixnum 'hash
             (lambda (
                     ) ; end form
               (for/fold ([acc 0]) ([i (in-range n
                                       ) ; end in-range
                                    ] ; end i
                                   ) ; end form
                 (+ acc (hash-ref ht i
                        ) ; end hash-ref
                 ) ; end +
               ) ; end for/fold
             ) ; end lambda
      ) ; end bench
      (bench 'predecessor-fixnum 'intmap
             (lambda (
                     ) ; end form
               (for/fold ([acc 0]) ([i (in-range n
                                       ) ; end in-range
                                    ] ; end i
                                   ) ; end form
                 (+ acc (cdr (intmap-entry< im (add1 i
                                               ) ; end add1
                             ) ; end intmap-entry<
                        ) ; end cdr
                 ) ; end +
               ) ; end for/fold
             ) ; end lambda
      ) ; end bench
      (bench 'predecessor-fixnum 'vector
             (lambda (
                     ) ; end form
               (for/fold ([acc 0]) ([i (in-range n
                                       ) ; end in-range
                                    ] ; end i
                                   ) ; end form
                 (+ acc (cdr (vector-entry< vec (add1 i
                                                ) ; end add1
                             ) ; end vector-entry<
                        ) ; end cdr
                 ) ; end +
               ) ; end for/fold
             ) ; end lambda
      ) ; end bench
      (bench 'range-count 'intmap-list
             (lambda (
                     ) ; end form
               (for/fold ([acc 0]) ([i (in-range 0 n 32
                                       ) ; end in-range
                                    ] ; end i
                                   ) ; end form
                 (+ acc (length (intmap-range->list im i (min n (+ i 16
                                                                ) ; end +
                                                         ) ; end min
                                ) ; end intmap-range->list
                        ) ; end length
                 ) ; end +
               ) ; end for/fold
             ) ; end lambda
      ) ; end bench
      (bench 'iterate 'intmap-cursor
             (lambda (
                     ) ; end form
               (for/fold ([acc 0]) ([(k v) (in-intmap im
                                           ) ; end in-intmap
                                    ] ; end clause
                                   ) ; end form
                 (+ acc k v
                 ) ; end +
               ) ; end for/fold
             ) ; end lambda
      ) ; end bench
      (bench 'many-version 'intmap
             (lambda (
                     ) ; end form
               (define-values (last sum
                              ) ; end last
                 (for/fold ([m intmap-empty] [acc 0]) ([i (in-range n
                                                          ) ; end in-range
                                                       ] ; end i
                                                      ) ; end form
                   (define m* (intmap-set m i i
                              ) ; end intmap-set
                   ) ; end define
                   (values m* (+ acc (intmap-count m*
                                     ) ; end intmap-count
                              ) ; end +
                   ) ; end values
                 ) ; end for/fold
               ) ; end define-values
               (+ sum (intmap-count last
                      ) ; end intmap-count
               ) ; end +
             ) ; end lambda
      ) ; end bench
     ) ; end list
     (if (eq? suite 'full
         ) ; end eq?
         (list
          (bench 'lookup-bignum 'intmap
                 (lambda (
                         ) ; end form
                   (for/fold ([acc 0]) ([i (in-range n
                                           ) ; end in-range
                                        ] ; end i
                                       ) ; end form
                     (+ acc (intmap-ref big-im (+ big i
                                               ) ; end +
                            ) ; end intmap-ref
                     ) ; end +
                   ) ; end for/fold
                 ) ; end lambda
          ) ; end bench
          (bench 'lookup-bignum 'hash
                 (lambda (
                         ) ; end form
                   (for/fold ([acc 0]) ([i (in-range n
                                           ) ; end in-range
                                        ] ; end i
                                       ) ; end form
                     (+ acc (hash-ref big-ht (+ big i
                                             ) ; end +
                            ) ; end hash-ref
                     ) ; end +
                   ) ; end for/fold
                 ) ; end lambda
          ) ; end bench
          (bench 'lookup-mixed 'intmap
                 (lambda (
                         ) ; end form
                   (for/fold ([acc 0]) ([p (in-list mixed-entries
                                           ) ; end in-list
                                        ] ; end p
                                       ) ; end form
                     (+ acc (intmap-ref mixed-im (car p
                                                 ) ; end car
                            ) ; end intmap-ref
                     ) ; end +
                   ) ; end for/fold
                 ) ; end lambda
          ) ; end bench
          (bench 'miss-fixnum 'intmap
                 (lambda (
                         ) ; end form
                   (for/fold ([acc 0]) ([i (in-range n
                                           ) ; end in-range
                                        ] ; end i
                                       ) ; end form
                     (+ acc (intmap-ref im (+ n i) 0
                            ) ; end intmap-ref
                     ) ; end +
                   ) ; end for/fold
                 ) ; end lambda
          ) ; end bench
          (bench 'miss-fixnum 'hash
                 (lambda (
                         ) ; end form
                   (for/fold ([acc 0]) ([i (in-range n
                                           ) ; end in-range
                                        ] ; end i
                                       ) ; end form
                     (+ acc (hash-ref ht (+ n i) 0
                            ) ; end hash-ref
                     ) ; end +
                   ) ; end for/fold
                 ) ; end lambda
          ) ; end bench
          (bench 'predecessor-bignum 'intmap
                 (lambda (
                         ) ; end form
                   (for/fold ([acc 0]) ([i (in-range n
                                           ) ; end in-range
                                        ] ; end i
                                       ) ; end form
                     (+ acc (cdr (intmap-entry< big-im (+ big i 1
                                                       ) ; end +
                                 ) ; end intmap-entry<
                            ) ; end cdr
                     ) ; end +
                   ) ; end for/fold
                 ) ; end lambda
          ) ; end bench
          (bench 'predecessor-bignum 'vector
                 (lambda (
                         ) ; end form
                   (for/fold ([acc 0]) ([i (in-range n
                                           ) ; end in-range
                                        ] ; end i
                                       ) ; end form
                     (+ acc (cdr (vector-entry< big-vec (+ big i 1
                                                        ) ; end +
                                 ) ; end vector-entry<
                            ) ; end cdr
                     ) ; end +
                   ) ; end for/fold
                 ) ; end lambda
          ) ; end bench
          (bench 'range-sum 'intmap-cursor
                 (lambda (
                         ) ; end form
                   (for/fold ([acc 0]) ([i (in-range 0 n 32
                                           ) ; end in-range
                                        ] ; end i
                                       ) ; end form
                     (+ acc
                        (for/fold ([inner 0]) ([(k v) (in-intmap-range im i (min n (+ i 16
                                                                                   ) ; end +
                                                                            ) ; end min
                                                      ) ; end in-intmap-range
                                               ] ; end clause
                                              ) ; end form
                          (+ inner v
                          ) ; end +
                        ) ; end for/fold
                     ) ; end +
                   ) ; end for/fold
                 ) ; end lambda
          ) ; end bench
          (bench 'range-sum 'intmap-list
                 (lambda (
                         ) ; end form
                   (for/fold ([acc 0]) ([i (in-range 0 n 32
                                           ) ; end in-range
                                        ] ; end i
                                       ) ; end form
                     (+ acc
                        (for/fold ([inner 0]) ([p (in-list (intmap-range->list im i (min n (+ i 16
                                                                                           ) ; end +
                                                                                    ) ; end min
                                                           ) ; end intmap-range->list
                                                  ) ; end in-list
                                               ] ; end p
                                              ) ; end form
                          (+ inner (cdr p
                                   ) ; end cdr
                          ) ; end +
                        ) ; end for/fold
                     ) ; end +
                   ) ; end for/fold
                 ) ; end lambda
          ) ; end bench
          (bench 'build 'sorted-vector
                 (lambda (
                         ) ; end form
                   (intmap-count (sorted-vector->intmap vec
                                 ) ; end sorted-vector->intmap
                   ) ; end intmap-count
                 ) ; end lambda
          ) ; end bench
          (bench 'build 'repeated-set
                 (lambda (
                         ) ; end form
                   (intmap-count
                    (for/fold ([m intmap-empty]) ([i (in-range n
                                                     ) ; end in-range
                                                  ] ; end i
                                                 ) ; end form
                      (intmap-set m i i
                      ) ; end intmap-set
                    ) ; end for/fold
                   ) ; end intmap-count
                 ) ; end lambda
          ) ; end bench
          (bench 'remove-half 'intmap
                 (lambda (
                         ) ; end form
                   (intmap-count
                    (for/fold ([m im]) ([i (in-range 0 n 2
                                           ) ; end in-range
                                        ] ; end i
                                       ) ; end form
                      (intmap-remove m i
                      ) ; end intmap-remove
                    ) ; end for/fold
                   ) ; end intmap-count
                 ) ; end lambda
          ) ; end bench
          (bench 'update-present 'intmap
                 (lambda (
                         ) ; end form
                   (define updated
                     (for/fold ([m im]) ([i (in-range n
                                             ) ; end in-range
                                          ] ; end i
                                         ) ; end form
                       (intmap-update m i 'missing add1
                       ) ; end intmap-update
                     ) ; end for/fold
                   ) ; end define
                   (for/fold ([acc 0]) ([i (in-range n
                                           ) ; end in-range
                                        ] ; end i
                                       ) ; end form
                     (+ acc (intmap-ref updated i
                            ) ; end intmap-ref
                     ) ; end +
                   ) ; end for/fold
                 ) ; end lambda
          ) ; end bench
          (bench 'set/absent-present 'intmap
                 (lambda (
                         ) ; end form
                   (for/fold ([acc 0]) ([i (in-range n
                                           ) ; end in-range
                                        ] ; end i
                                       ) ; end form
                     (define-values (m* inserted?
                                    ) ; end m*
                       (intmap-set/absent im i 'present
                       ) ; end intmap-set/absent
                     ) ; end define-values
                     (+ acc (if inserted? 1 0
                            ) ; end if
                     ) ; end +
                   ) ; end for/fold
                 ) ; end lambda
          ) ; end bench
          (bench 'replace/eq-present 'intmap
                 (lambda (
                         ) ; end form
                   (for/fold ([acc 0]) ([i (in-range n
                                           ) ; end in-range
                                        ] ; end i
                                       ) ; end form
                     (define-values (m* replaced?
                                    ) ; end m*
                       (intmap-replace/eq im i i (add1 i
                                                 ) ; end add1
                       ) ; end intmap-replace/eq
                     ) ; end define-values
                     (+ acc (if replaced?
                                (intmap-ref m* i
                                ) ; end intmap-ref
                                0
                            ) ; end if
                     ) ; end +
                   ) ; end for/fold
                 ) ; end lambda
          ) ; end bench
          (bench 'replace/eq-mismatch 'intmap
                 (lambda (
                         ) ; end form
                   (for/fold ([acc 0]) ([i (in-range n
                                           ) ; end in-range
                                        ] ; end i
                                       ) ; end form
                     (define-values (m* replaced?
                                    ) ; end m*
                       (intmap-replace/eq im i -1 (add1 i
                                                  ) ; end add1
                       ) ; end intmap-replace/eq
                     ) ; end define-values
                     (+ acc (if replaced?
                                (intmap-ref m* i
                                ) ; end intmap-ref
                                0
                            ) ; end if
                     ) ; end +
                   ) ; end for/fold
                 ) ; end lambda
          ) ; end bench
         ) ; end list
         null
     ) ; end if
    ) ; end append
  ) ; end define

  (print-ratio samples "lookup intmap/hash" 'lookup-fixnum 'intmap 'lookup-fixnum 'hash
  ) ; end print-ratio
  (print-ratio samples "predecessor intmap/vector" 'predecessor-fixnum 'intmap 'predecessor-fixnum 'vector
  ) ; end print-ratio
  (when (eq? suite 'full
        ) ; end eq?
    (print-ratio samples "bignum/fixnum intmap lookup" 'lookup-bignum 'intmap 'lookup-fixnum 'intmap
    ) ; end print-ratio
    (print-ratio samples "mixed/fixnum intmap lookup" 'lookup-mixed 'intmap 'lookup-fixnum 'intmap
    ) ; end print-ratio
    (print-ratio samples "range cursor/list" 'range-sum 'intmap-cursor 'range-sum 'intmap-list
    ) ; end print-ratio
    (print-ratio samples "repeated-set/sorted-vector build" 'build 'repeated-set 'build 'sorted-vector
    ) ; end print-ratio
  ) ; end when

  (when gate?
    (define versions-expected (+ (quotient (* n (add1 n)) 2) n
                              ) ; end +
    ) ; end define
    (define checks
      (append
       (list
        (cons 'cs-core-backend
              (eq? (adapter:intmap-runtime-adapter-backend) 'cs-core
              ) ; end eq?
        ) ; end cons
        (cons 'lookup-result
              (= (sample-result (find-sample samples 'lookup-fixnum 'intmap
                                ) ; end find-sample
                 ) ; end sample-result
                 expected-sum
                 (sample-result (find-sample samples 'lookup-fixnum 'hash
                                ) ; end find-sample
                 ) ; end sample-result
              ) ; end =
        ) ; end cons
        (cons 'lookup-within-hash-5x
              (time<=factor? (sample-real-ref samples 'lookup-fixnum 'intmap
                             ) ; end sample-real-ref
                             (sample-real-ref samples 'lookup-fixnum 'hash
                             ) ; end sample-real-ref
                             5.0
              ) ; end time<=factor?
        ) ; end cons
        (cons 'predecessor-result
              (= (sample-result (find-sample samples 'predecessor-fixnum 'intmap
                                ) ; end find-sample
                 ) ; end sample-result
                 expected-sum
                 (sample-result (find-sample samples 'predecessor-fixnum 'vector
                                ) ; end find-sample
                 ) ; end sample-result
              ) ; end =
        ) ; end cons
        (cons 'predecessor-within-vector-3x
              (time<=factor? (sample-real-ref samples 'predecessor-fixnum 'intmap
                             ) ; end sample-real-ref
                             (sample-real-ref samples 'predecessor-fixnum 'vector
                             ) ; end sample-real-ref
                             3.0
              ) ; end time<=factor?
        ) ; end cons
        (cons 'range-count-result
              (= (sample-result (find-sample samples 'range-count 'intmap-list
                                ) ; end find-sample
                 ) ; end sample-result
                 (range-count n
                 ) ; end range-count
              ) ; end =
        ) ; end cons
        (cons 'iterate-result
              (= (sample-result (find-sample samples 'iterate 'intmap-cursor
                                ) ; end find-sample
                 ) ; end sample-result
                 (* 2 expected-sum
                 ) ; end *
              ) ; end =
        ) ; end cons
        (cons 'many-version-result
              (= (sample-result (find-sample samples 'many-version 'intmap
                                ) ; end find-sample
                 ) ; end sample-result
                 versions-expected
              ) ; end =
        ) ; end cons
       ) ; end list
       (if (eq? suite 'full
           ) ; end eq?
           (list
            (cons 'bignum-lookup-result
                  (= (sample-result (find-sample samples 'lookup-bignum 'intmap
                                    ) ; end find-sample
                     ) ; end sample-result
                     expected-sum
                     (sample-result (find-sample samples 'lookup-bignum 'hash
                                    ) ; end find-sample
                     ) ; end sample-result
                  ) ; end =
            ) ; end cons
            (cons 'mixed-lookup-result
                  (= (sample-result (find-sample samples 'lookup-mixed 'intmap
                                    ) ; end find-sample
                     ) ; end sample-result
                     expected-sum
                  ) ; end =
            ) ; end cons
            (cons 'miss-result
                  (= (sample-result (find-sample samples 'miss-fixnum 'intmap
                                    ) ; end find-sample
                     ) ; end sample-result
                     0
                     (sample-result (find-sample samples 'miss-fixnum 'hash
                                    ) ; end find-sample
                     ) ; end sample-result
                  ) ; end =
            ) ; end cons
            (cons 'bignum-predecessor-result
                  (= (sample-result (find-sample samples 'predecessor-bignum 'intmap
                                    ) ; end find-sample
                     ) ; end sample-result
                     expected-sum
                     (sample-result (find-sample samples 'predecessor-bignum 'vector
                                    ) ; end find-sample
                     ) ; end sample-result
                  ) ; end =
            ) ; end cons
            (cons 'range-sum-result
                  (= (sample-result (find-sample samples 'range-sum 'intmap-cursor
                                    ) ; end find-sample
                     ) ; end sample-result
                     (range-sum n
                     ) ; end range-sum
                     (sample-result (find-sample samples 'range-sum 'intmap-list
                                    ) ; end find-sample
                     ) ; end sample-result
                  ) ; end =
            ) ; end cons
            (cons 'build-result
                  (= (sample-result (find-sample samples 'build 'sorted-vector
                                    ) ; end find-sample
                     ) ; end sample-result
                     n
                     (sample-result (find-sample samples 'build 'repeated-set
                                    ) ; end find-sample
                     ) ; end sample-result
                  ) ; end =
            ) ; end cons
            (cons 'remove-half-result
                  (= (sample-result (find-sample samples 'remove-half 'intmap
                                    ) ; end find-sample
                     ) ; end sample-result
                     (- n (quotient (add1 n) 2
                          ) ; end quotient
                     ) ; end -
                  ) ; end =
            ) ; end cons
            (cons 'update-present-result
                  (= (sample-result (find-sample samples 'update-present 'intmap
                                    ) ; end find-sample
                     ) ; end sample-result
                     (+ expected-sum n
                     ) ; end +
                  ) ; end =
            ) ; end cons
            (cons 'set-absent-present-result
                  (= (sample-result (find-sample samples 'set/absent-present 'intmap
                                    ) ; end find-sample
                     ) ; end sample-result
                     0
                  ) ; end =
            ) ; end cons
            (cons 'replace-eq-present-result
                  (= (sample-result (find-sample samples 'replace/eq-present 'intmap
                                    ) ; end find-sample
                     ) ; end sample-result
                     (+ expected-sum n
                     ) ; end +
                  ) ; end =
            ) ; end cons
            (cons 'replace-eq-mismatch-result
                  (= (sample-result (find-sample samples 'replace/eq-mismatch 'intmap
                                    ) ; end find-sample
                     ) ; end sample-result
                     0
                  ) ; end =
            ) ; end cons
           ) ; end list
           null
       ) ; end if
      ) ; end append
    ) ; end define
    (define passed (for/sum ([check (in-list checks
                                    ) ; end in-list
                             ] ; end check
                            ) ; end form
                     (if (cdr check) 1 0
                     ) ; end if
                   ) ; end for/sum
    ) ; end define
    (printf "gate score: ~a/~a\n" passed (length checks
                                         ) ; end length
    ) ; end printf
    (for ([check (in-list checks)] #:unless (cdr check
                                            ) ; end cdr
         ) ; end :unless
      (printf "gate failure: ~a\n" (car check
                                   ) ; end car
      ) ; end printf
    ) ; end for
    (unless (= passed (length checks
                      ) ; end length
            ) ; end =
      (exit 1
      ) ; end exit
    ) ; end unless
  ) ; end when
) ; end define

(run-suite
) ; end run-suite
