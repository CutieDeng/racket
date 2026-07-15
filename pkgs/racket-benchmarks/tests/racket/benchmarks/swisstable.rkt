#lang racket/base

;; Benchmark for racket/swisstable against the standard mutable hash
;; tables.  Run with the CS core backend (in-tree racket) and with the
;; pure-Racket fallback to compare; the backend is reported first.

(require racket/cmdline
         racket/swisstable
) ; end require

(define N 200000
) ; end define
(define LOOKUPS 2000000
) ; end define

(command-line
 #:once-each
 [("--n") n "number of keys (default 200000)"
  (set! N (string->number n
          ) ; end string->number
  ) ; end set!
 ] ; end clause
 [("--lookups") n "number of lookups (default 2000000)"
  (set! LOOKUPS (string->number n
                ) ; end string->number
  ) ; end set!
 ] ; end clause
) ; end command-line

(printf "swisstable backend: ~a\n" (swisstable-runtime-adapter-backend
                                   ) ; end swisstable-runtime-adapter-backend
) ; end printf

(define (bench name thunk
        ) ; end bench
  (collect-garbage
  ) ; end collect-garbage
  (collect-garbage
  ) ; end collect-garbage
  (define-values (r cpu real gc) (time-apply thunk '(
                                                    ) ; end quote
                                 ) ; end time-apply
  ) ; end define-values
  (printf "~a: cpu ~a ms (gc ~a ms)\n" name cpu gc
  ) ; end printf
) ; end define

(define fixnum-keys (build-list N values
                    ) ; end build-list
) ; end define
(define string-keys (for/list ([i (in-range N
                                  ) ; end in-range
                               ] ; end i
                              ) ; end for/list args
                      (string-append "key-" (number->string i
                                            ) ; end number->string
                      ) ; end string-append
                    ) ; end for/list
) ; end define

(printf "== insert ~a fixnum keys ==\n" N
) ; end printf
(bench "make-hash        "
       (lambda (
               ) ; end lambda args
         (define h (make-hash
                   ) ; end make-hash
         ) ; end define
         (for ([k (in-list fixnum-keys
                  ) ; end in-list
               ] ; end k
              ) ; end for args
           (hash-set! h k k
           ) ; end hash-set!
         ) ; end for
         h
       ) ; end lambda
) ; end bench
(bench "make-hasheq      "
       (lambda (
               ) ; end lambda args
         (define h (make-hasheq
                   ) ; end make-hasheq
         ) ; end define
         (for ([k (in-list fixnum-keys
                  ) ; end in-list
               ] ; end k
              ) ; end for args
           (hash-set! h k k
           ) ; end hash-set!
         ) ; end for
         h
       ) ; end lambda
) ; end bench
(bench "swisstable       "
       (lambda (
               ) ; end lambda args
         (define s (make-swisstable
                   ) ; end make-swisstable
         ) ; end define
         (for ([k (in-list fixnum-keys
                  ) ; end in-list
               ] ; end k
              ) ; end for args
           (swisstable-set! s k k
           ) ; end swisstable-set!
         ) ; end for
         s
       ) ; end lambda
) ; end bench
(bench "swisstable-eq    "
       (lambda (
               ) ; end lambda args
         (define s (make-swisstable-eq
                   ) ; end make-swisstable-eq
         ) ; end define
         (for ([k (in-list fixnum-keys
                  ) ; end in-list
               ] ; end k
              ) ; end for args
           (swisstable-set! s k k
           ) ; end swisstable-set!
         ) ; end for
         s
       ) ; end lambda
) ; end bench

(printf "== insert ~a string keys ==\n" N
) ; end printf
(bench "make-hash        "
       (lambda (
               ) ; end lambda args
         (define h (make-hash
                   ) ; end make-hash
         ) ; end define
         (for ([k (in-list string-keys
                  ) ; end in-list
               ] ; end k
              ) ; end for args
           (hash-set! h k k
           ) ; end hash-set!
         ) ; end for
         h
       ) ; end lambda
) ; end bench
(bench "swisstable       "
       (lambda (
               ) ; end lambda args
         (define s (make-swisstable
                   ) ; end make-swisstable
         ) ; end define
         (for ([k (in-list string-keys
                  ) ; end in-list
               ] ; end k
              ) ; end for args
           (swisstable-set! s k k
           ) ; end swisstable-set!
         ) ; end for
         s
       ) ; end lambda
) ; end bench

(define h-fx (make-hash
             ) ; end make-hash
) ; end define
(define he-fx (make-hasheq
              ) ; end make-hasheq
) ; end define
(define s-fx (make-swisstable
             ) ; end make-swisstable
) ; end define
(define se-fx (make-swisstable-eq
              ) ; end make-swisstable-eq
) ; end define
(define h-str (make-hash
              ) ; end make-hash
) ; end define
(define s-str (make-swisstable
              ) ; end make-swisstable
) ; end define
(for ([k (in-list fixnum-keys
         ) ; end in-list
      ] ; end k
     ) ; end for args
  (hash-set! h-fx k k
  ) ; end hash-set!
  (hash-set! he-fx k k
  ) ; end hash-set!
  (swisstable-set! s-fx k k
  ) ; end swisstable-set!
  (swisstable-set! se-fx k k
  ) ; end swisstable-set!
) ; end for
(for ([k (in-list string-keys
         ) ; end in-list
      ] ; end k
     ) ; end for args
  (hash-set! h-str k k
  ) ; end hash-set!
  (swisstable-set! s-str k k
  ) ; end swisstable-set!
) ; end for

(printf "== ~a hit lookups, fixnum keys ==\n" LOOKUPS
) ; end printf
(bench "make-hash        "
       (lambda (
               ) ; end lambda args
         (for/fold ([acc 0
                    ] ; end acc
                   ) ; end for/fold accum
                   ([i (in-range LOOKUPS
                       ) ; end in-range
                    ] ; end i
                   ) ; end for/fold args
           (+ acc (hash-ref h-fx (modulo i N
                                 ) ; end modulo
                            0
                  ) ; end hash-ref
           ) ; end +
         ) ; end for/fold
       ) ; end lambda
) ; end bench
(bench "make-hasheq      "
       (lambda (
               ) ; end lambda args
         (for/fold ([acc 0
                    ] ; end acc
                   ) ; end for/fold accum
                   ([i (in-range LOOKUPS
                       ) ; end in-range
                    ] ; end i
                   ) ; end for/fold args
           (+ acc (hash-ref he-fx (modulo i N
                                  ) ; end modulo
                            0
                  ) ; end hash-ref
           ) ; end +
         ) ; end for/fold
       ) ; end lambda
) ; end bench
(bench "swisstable       "
       (lambda (
               ) ; end lambda args
         (for/fold ([acc 0
                    ] ; end acc
                   ) ; end for/fold accum
                   ([i (in-range LOOKUPS
                       ) ; end in-range
                    ] ; end i
                   ) ; end for/fold args
           (+ acc (swisstable-ref s-fx (modulo i N
                                       ) ; end modulo
                                  0
                  ) ; end swisstable-ref
           ) ; end +
         ) ; end for/fold
       ) ; end lambda
) ; end bench
(bench "swisstable-eq    "
       (lambda (
               ) ; end lambda args
         (for/fold ([acc 0
                    ] ; end acc
                   ) ; end for/fold accum
                   ([i (in-range LOOKUPS
                       ) ; end in-range
                    ] ; end i
                   ) ; end for/fold args
           (+ acc (swisstable-ref se-fx (modulo i N
                                        ) ; end modulo
                                  0
                  ) ; end swisstable-ref
           ) ; end +
         ) ; end for/fold
       ) ; end lambda
) ; end bench

;; Scattered access pattern: sequential-key scans favor bucket-chain
;; tables whose nodes were allocated in key order (prefetch-friendly);
;; scattered keys show the flat-array advantage instead.
(printf "== ~a scattered hit lookups, fixnum keys ==\n" LOOKUPS
) ; end printf
(define scattered-keys
  (for/vector ([i (in-range 65536
               ) ; end in-range
               ] ; end i
              ) ; end for/vector args
    (modulo (* i 2654435761) N
    ) ; end modulo
  ) ; end for/vector
) ; end define
(bench "make-hash        "
       (lambda (
               ) ; end lambda args
         (for/fold ([acc 0
                    ] ; end acc
                   ) ; end for/fold accum
                   ([i (in-range LOOKUPS
                       ) ; end in-range
                    ] ; end i
                   ) ; end for/fold args
           (+ acc (hash-ref h-fx (vector-ref scattered-keys (bitwise-and i 65535
                                                            ) ; end bitwise-and
                                 ) ; end vector-ref
                            0
                  ) ; end hash-ref
           ) ; end +
         ) ; end for/fold
       ) ; end lambda
) ; end bench
(bench "make-hasheq      "
       (lambda (
               ) ; end lambda args
         (for/fold ([acc 0
                    ] ; end acc
                   ) ; end for/fold accum
                   ([i (in-range LOOKUPS
                       ) ; end in-range
                    ] ; end i
                   ) ; end for/fold args
           (+ acc (hash-ref he-fx (vector-ref scattered-keys (bitwise-and i 65535
                                                             ) ; end bitwise-and
                                  ) ; end vector-ref
                            0
                  ) ; end hash-ref
           ) ; end +
         ) ; end for/fold
       ) ; end lambda
) ; end bench
(bench "swisstable       "
       (lambda (
               ) ; end lambda args
         (for/fold ([acc 0
                    ] ; end acc
                   ) ; end for/fold accum
                   ([i (in-range LOOKUPS
                       ) ; end in-range
                    ] ; end i
                   ) ; end for/fold args
           (+ acc (swisstable-ref s-fx (vector-ref scattered-keys (bitwise-and i 65535
                                                                  ) ; end bitwise-and
                                       ) ; end vector-ref
                                  0
                  ) ; end swisstable-ref
           ) ; end +
         ) ; end for/fold
       ) ; end lambda
) ; end bench
(bench "swisstable-eq    "
       (lambda (
               ) ; end lambda args
         (for/fold ([acc 0
                    ] ; end acc
                   ) ; end for/fold accum
                   ([i (in-range LOOKUPS
                       ) ; end in-range
                    ] ; end i
                   ) ; end for/fold args
           (+ acc (swisstable-ref se-fx (vector-ref scattered-keys (bitwise-and i 65535
                                                                   ) ; end bitwise-and
                                        ) ; end vector-ref
                                  0
                  ) ; end swisstable-ref
           ) ; end +
         ) ; end for/fold
       ) ; end lambda
) ; end bench

(printf "== ~a hit lookups, string keys ==\n" (quotient LOOKUPS 5
                                              ) ; end quotient
) ; end printf
(define lookup-strings
  (for/vector ([i (in-range (quotient LOOKUPS 5
                            ) ; end quotient
               ) ; end in-range
               ] ; end i
              ) ; end for/vector args
    (list-ref string-keys (modulo (* i 7919) N
                          ) ; end modulo
    ) ; end list-ref
  ) ; end for/vector
) ; end define
(bench "make-hash        "
       (lambda (
               ) ; end lambda args
         (for/fold ([acc 0
                    ] ; end acc
                   ) ; end for/fold accum
                   ([k (in-vector lookup-strings
                       ) ; end in-vector
                    ] ; end k
                   ) ; end for/fold args
           (+ acc (string-length (hash-ref h-str k "x"
                                 ) ; end hash-ref
                  ) ; end string-length
           ) ; end +
         ) ; end for/fold
       ) ; end lambda
) ; end bench
(bench "swisstable       "
       (lambda (
               ) ; end lambda args
         (for/fold ([acc 0
                    ] ; end acc
                   ) ; end for/fold accum
                   ([k (in-vector lookup-strings
                       ) ; end in-vector
                    ] ; end k
                   ) ; end for/fold args
           (+ acc (string-length (swisstable-ref s-str k "x"
                                 ) ; end swisstable-ref
                  ) ; end string-length
           ) ; end +
         ) ; end for/fold
       ) ; end lambda
) ; end bench

(printf "== churn: 50x (insert 10000 + remove 10000), eq keys ==\n"
) ; end printf
(bench "make-hasheq      "
       (lambda (
               ) ; end lambda args
         (define h (make-hasheq
                   ) ; end make-hasheq
         ) ; end define
         (for ([round (in-range 50
                      ) ; end in-range
               ] ; end round
              ) ; end for args
           (for ([i (in-range 10000
                    ) ; end in-range
                 ] ; end i
                ) ; end for args
             (hash-set! h i i
             ) ; end hash-set!
           ) ; end for
           (for ([i (in-range 10000
                    ) ; end in-range
                 ] ; end i
                ) ; end for args
             (hash-remove! h i
             ) ; end hash-remove!
           ) ; end for
         ) ; end for
         h
       ) ; end lambda
) ; end bench
(bench "swisstable-eq    "
       (lambda (
               ) ; end lambda args
         (define s (make-swisstable-eq
                   ) ; end make-swisstable-eq
         ) ; end define
         (for ([round (in-range 50
                      ) ; end in-range
               ] ; end round
              ) ; end for args
           (for ([i (in-range 10000
                    ) ; end in-range
                 ] ; end i
                ) ; end for args
             (swisstable-set! s i i
             ) ; end swisstable-set!
           ) ; end for
           (for ([i (in-range 10000
                    ) ; end in-range
                 ] ; end i
                ) ; end for args
             (swisstable-remove! s i
             ) ; end swisstable-remove!
           ) ; end for
         ) ; end for
         s
       ) ; end lambda
) ; end bench
