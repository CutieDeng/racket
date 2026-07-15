
(load-relative "loadtest.rktl"
) ; end load-relative

(Section 'swisstable
) ; end Section

(require racket/swisstable
         racket/dict
         (prefix-in raw: racket/private/swisstable-runtime-adapter
         ) ; end prefix-in
         (prefix-in fb: racket/private/swisstable
         ) ; end prefix-in
) ; end require

;; ----------------------------------------
;; constructors and kinds

(test #t swisstable? (make-swisstable
                     ) ; end make-swisstable
) ; end test
(test #t swisstable? (make-swisstable-eqv
                     ) ; end make-swisstable-eqv
) ; end test
(test #t swisstable? (make-swisstable-eq
                     ) ; end make-swisstable-eq
) ; end test
(test #f swisstable? (make-hash
                     ) ; end make-hash
) ; end test
(test #f swisstable? 17
) ; end test
(test 'equal swisstable-kind (make-swisstable
                             ) ; end make-swisstable
) ; end test
(test 'eqv swisstable-kind (make-swisstable-eqv
                           ) ; end make-swisstable-eqv
) ; end test
(test 'eq swisstable-kind (make-swisstable-eq
                          ) ; end make-swisstable-eq
) ; end test
(test 0 swisstable-count (make-swisstable
                         ) ; end make-swisstable
) ; end test
(test #t swisstable-empty? (make-swisstable
                           ) ; end make-swisstable
) ; end test
(test #t swisstable? (make-swisstable 1000
                     ) ; end make-swisstable
) ; end test

;; ----------------------------------------
;; basic set/ref/remove semantics per kind

(define (basic-battery mk
        ) ; end basic-battery
  (define st (mk
             ) ; end mk
  ) ; end define
  (swisstable-set! st 'a 1
  ) ; end swisstable-set!
  (swisstable-set! st 'b 2
  ) ; end swisstable-set!
  (swisstable-set! st 'a 10
  ) ; end swisstable-set!
  (test 2 swisstable-count st
  ) ; end test
  (test 10 swisstable-ref st 'a
  ) ; end test
  (test 2 swisstable-ref st 'b
  ) ; end test
  (test 'none swisstable-ref st 'zzz 'none
  ) ; end test
  (test 'thunked swisstable-ref st 'zzz (lambda () 'thunked
                                        ) ; end lambda
  ) ; end test
  (test #t swisstable-has-key? st 'a
  ) ; end test
  (test #f swisstable-has-key? st 'zzz
  ) ; end test
  (test #t swisstable-remove! st 'a
  ) ; end test
  (test #f swisstable-remove! st 'a
  ) ; end test
  (test 1 swisstable-count st
  ) ; end test
  (test #f swisstable-has-key? st 'a
  ) ; end test
  (swisstable-clear! st
  ) ; end swisstable-clear!
  (test 0 swisstable-count st
  ) ; end test
  (test #t swisstable-empty? st
  ) ; end test
) ; end define

(basic-battery make-swisstable
) ; end basic-battery
(basic-battery make-swisstable-eqv
) ; end basic-battery
(basic-battery make-swisstable-eq
) ; end basic-battery

;; ----------------------------------------
;; kind-specific key semantics

(let ([st (make-swisstable
          ) ; end make-swisstable
      ] ; end st
     ) ; end let args
  (swisstable-set! st (string-append "he" "llo"
                      ) ; end string-append
                   1
  ) ; end swisstable-set!
  (test 1 swisstable-ref st "hello"
  ) ; end test
  (swisstable-set! st (list 1 2 (vector 3
                                ) ; end vector
                      ) ; end list
                   'deep
  ) ; end swisstable-set!
  (test 'deep swisstable-ref st (list 1 2 (vector 3
                                          ) ; end vector
                                ) ; end list
  ) ; end test
) ; end let

(let ([st (make-swisstable-eq
          ) ; end make-swisstable-eq
      ] ; end st
     ) ; end let args
  (define s1 (string-append "he" "llo"
             ) ; end string-append
  ) ; end define
  (define s2 (string-append "he" "llo"
             ) ; end string-append
  ) ; end define
  (swisstable-set! st s1 1
  ) ; end swisstable-set!
  (swisstable-set! st s2 2
  ) ; end swisstable-set!
  (test 2 swisstable-count st
  ) ; end test
  (test 1 swisstable-ref st s1
  ) ; end test
  (test 2 swisstable-ref st s2
  ) ; end test
) ; end let

(let ([st (make-swisstable-eqv
          ) ; end make-swisstable-eqv
      ] ; end st
     ) ; end let args
  (swisstable-set! st 1.5 'flo
  ) ; end swisstable-set!
  (swisstable-set! st #\x 'ch
  ) ; end swisstable-set!
  (test 'flo swisstable-ref st 1.5
  ) ; end test
  (test 'ch swisstable-ref st #\x
  ) ; end test
) ; end let

;; #f, 0, and removed-slot sentinels must not confuse lookup
(let ([st (make-swisstable
          ) ; end make-swisstable
      ] ; end st
     ) ; end let args
  (swisstable-set! st #f 'false-key
  ) ; end swisstable-set!
  (swisstable-set! st 0 'zero-key
  ) ; end swisstable-set!
  (swisstable-set! st 'k #f
  ) ; end swisstable-set!
  (test 'false-key swisstable-ref st #f
  ) ; end test
  (test 'zero-key swisstable-ref st 0
  ) ; end test
  (test #f swisstable-ref st 'k 'nope
  ) ; end test
  (test #t swisstable-remove! st #f
  ) ; end test
  (test #f swisstable-has-key? st #f
  ) ; end test
  (test 'gone swisstable-ref st #f 'gone
  ) ; end test
) ; end let

;; ----------------------------------------
;; growth, tombstones, and differential check against make-hash

(define (differential-battery mk-gold mk-st key-space iters seed
        ) ; end differential-battery
  (random-seed seed
  ) ; end random-seed
  (define gold (mk-gold
               ) ; end mk-gold
  ) ; end define
  (define st (mk-st
             ) ; end mk-st
  ) ; end define
  (for ([step (in-range iters
              ) ; end in-range
        ] ; end step
       ) ; end for args
    (define k (random key-space
              ) ; end random
    ) ; end define
    (define op (random 10
               ) ; end random
    ) ; end define
    (cond
      [(< op 5
       ) ; end <
       (define v (random 1000000
                 ) ; end random
       ) ; end define
       (hash-set! gold k v
       ) ; end hash-set!
       (swisstable-set! st k v
       ) ; end swisstable-set!
      ] ; end clause
      [(< op 8
       ) ; end <
       (define had (hash-has-key? gold k
                   ) ; end hash-has-key?
       ) ; end define
       (hash-remove! gold k
       ) ; end hash-remove!
       (unless (eq? had (swisstable-remove! st k
                        ) ; end swisstable-remove!
               ) ; end eq?
         (error 'differential "remove mismatch"
         ) ; end error
       ) ; end unless
      ] ; end clause
      [else
       (unless (equal? (hash-ref gold k 'none
                       ) ; end hash-ref
                       (swisstable-ref st k 'none
                       ) ; end swisstable-ref
               ) ; end equal?
         (error 'differential "ref mismatch"
         ) ; end error
      ) ; end unless
      ] ; end else
    ) ; end cond
  ) ; end for
  (test (hash-count gold) swisstable-count st
  ) ; end test
  (test #t values
        (for/and ([(k v) (in-hash gold
                         ) ; end in-hash
                 ] ; end k v
                 ) ; end for/and args
          (equal? v (swisstable-ref st k 'none
                    ) ; end swisstable-ref
          ) ; end equal?
        ) ; end for/and
  ) ; end test
  (test #t values
        (for/and ([(k v) (in-swisstable st
                         ) ; end in-swisstable
                 ] ; end k v
                 ) ; end for/and args
          (equal? v (hash-ref gold k 'none
                    ) ; end hash-ref
          ) ; end equal?
        ) ; end for/and
  ) ; end test
) ; end define

(differential-battery make-hash make-swisstable 400 12000 20260715
) ; end differential-battery
(differential-battery make-hasheqv make-swisstable-eqv 900 12000 424242
) ; end differential-battery
(differential-battery make-hasheq make-swisstable-eq 900 12000 31337
) ; end differential-battery

;; strided keys stress probe chains and group wraparound
(let ([st (make-swisstable-eq
          ) ; end make-swisstable-eq
      ] ; end st
      [gold (make-hasheq
            ) ; end make-hasheq
      ] ; end gold
     ) ; end let args
  (for ([i (in-range 3000
           ) ; end in-range
        ] ; end i
       ) ; end for args
    (let ([k (* i 131072
             ) ; end *
          ] ; end k
         ) ; end let args
      (swisstable-set! st k i
      ) ; end swisstable-set!
      (hash-set! gold k i
      ) ; end hash-set!
    ) ; end let
  ) ; end for
  (for ([i (in-range 0 3000 2
           ) ; end in-range
        ] ; end i
       ) ; end for args
    (swisstable-remove! st (* i 131072
                           ) ; end *
    ) ; end swisstable-remove!
    (hash-remove! gold (* i 131072
                       ) ; end *
    ) ; end hash-remove!
  ) ; end for
  (test (hash-count gold) swisstable-count st
  ) ; end test
  (test #t values
        (for/and ([(k v) (in-hash gold
                         ) ; end in-hash
                  ] ; end k v
                 ) ; end for/and args
          (equal? v (swisstable-ref st k 'none
                    ) ; end swisstable-ref
          ) ; end equal?
        ) ; end for/and
  ) ; end test
) ; end let

;; custom equal+hash struct keys exercise user comparison callbacks
;; between candidate-scan steps
(let (
     ) ; end let args
  (struct wrap (v
               ) ; end fields
    #:property prop:equal+hash
    (list (lambda (a b rec) (equal? (wrap-v a
                                    ) ; end wrap-v
                                    (wrap-v b
                                    ) ; end wrap-v
                            ) ; end equal?
          ) ; end lambda
          (lambda (a rec) (rec (wrap-v a
                               ) ; end wrap-v
                          ) ; end rec
          ) ; end lambda
          (lambda (a rec) (rec (wrap-v a
                               ) ; end wrap-v
                          ) ; end rec
          ) ; end lambda
    ) ; end list
  ) ; end struct
  (define st (make-swisstable
             ) ; end make-swisstable
  ) ; end define
  (for ([i (in-range 500
           ) ; end in-range
        ] ; end i
       ) ; end for args
    (swisstable-set! st (wrap i) i
    ) ; end swisstable-set!
  ) ; end for
  (test 500 swisstable-count st
  ) ; end test
  (test #t values
        (for/and ([i (in-range 500
                     ) ; end in-range
                  ] ; end i
                 ) ; end for/and args
          (equal? i (swisstable-ref st (wrap i) 'none
                    ) ; end swisstable-ref
          ) ; end equal?
        ) ; end for/and
  ) ; end test
  (test #t swisstable-remove! st (wrap 123
                                 ) ; end wrap
  ) ; end test
  (test 'gone swisstable-ref st (wrap 123) 'gone
  ) ; end test
) ; end let

;; stats sanity: capacity stays a power of two and load stays bounded
(let ([st (make-swisstable-eq
          ) ; end make-swisstable-eq
      ] ; end st
     ) ; end let args
  (for ([i (in-range 1000
           ) ; end in-range
       ] ; end i
       ) ; end for args
    (swisstable-set! st i i
    ) ; end swisstable-set!
  ) ; end for
  (define stats (swisstable-stats st
                ) ; end swisstable-stats
  ) ; end define
  (define cap (vector-ref stats 1
              ) ; end vector-ref
  ) ; end define
  (test 'eq vector-ref stats 0
  ) ; end test
  (test 1000 vector-ref stats 2
  ) ; end test
  (test #t values (= (expt 2 (sub1 (integer-length cap
                                   ) ; end integer-length
                            ) ; end sub1
                     ) ; end expt
                     cap
                  ) ; end =
  ) ; end test
  (test #t values (<= (* 8 1000) (* 7 cap 2
                                 ) ; end *
                  ) ; end <=
  ) ; end test
) ; end let

;; churn: repeated fill/drain must not grow the table without bound
(let ([st (make-swisstable-eq
          ) ; end make-swisstable-eq
      ] ; end st
     ) ; end let args
  (for ([round (in-range 40
               ) ; end in-range
        ] ; end round
       ) ; end for args
    (for ([i (in-range 100
             ) ; end in-range
          ] ; end i
         ) ; end for args
      (swisstable-set! st i i
      ) ; end swisstable-set!
    ) ; end for
    (for ([i (in-range 100
             ) ; end in-range
          ] ; end i
         ) ; end for args
      (swisstable-remove! st i
      ) ; end swisstable-remove!
    ) ; end for
  ) ; end for
  (test 0 swisstable-count st
  ) ; end test
  (test #t values (<= (vector-ref (swisstable-stats st
                                  ) ; end swisstable-stats
                                  1
                      ) ; end vector-ref
                      1024
                  ) ; end <=
  ) ; end test
) ; end let

;; ----------------------------------------
;; iteration, sequences, conveniences

(let ([st (make-swisstable
          ) ; end make-swisstable
      ] ; end st
     ) ; end let args
  (for ([i (in-range 100
           ) ; end in-range
        ] ; end i
       ) ; end for args
    (swisstable-set! st i (* i i
                          ) ; end *
    ) ; end swisstable-set!
  ) ; end for
  (test 100 length (swisstable->list st
                   ) ; end swisstable->list
  ) ; end test
  (test (for/list ([i (in-range 100
                      ) ; end in-range
                   ] ; end i
                  ) ; end for/list args
          i
        ) ; end for/list
        values
        (sort (swisstable-keys st
              ) ; end swisstable-keys
              <
        ) ; end sort
  ) ; end test
  (test (for/sum ([i (in-range 100
                     ) ; end in-range
                  ] ; end i
                 ) ; end for/sum args
          (* i i
          ) ; end *
        ) ; end for/sum
        values
        (for/sum ([v (in-swisstable-values st
                     ) ; end in-swisstable-values
                  ] ; end v
                 ) ; end for/sum args
          v
        ) ; end for/sum
  ) ; end test
  (test 4950 values (for/sum ([k (in-swisstable-keys st
                                 ) ; end in-swisstable-keys
                              ] ; end k
                             ) ; end for/sum args
                      k
                    ) ; end for/sum
  ) ; end test
  (test #t values (for/and ([(k v) (in-swisstable st
                                   ) ; end in-swisstable
                            ] ; end k v
                           ) ; end for/and args
                    (= v (* k k
                         ) ; end *
                    ) ; end =
                  ) ; end for/and
  ) ; end test
  ;; manual cursor walk
  (test 100 values
        (let loop ([i (swisstable-iterate-first st
                      ) ; end swisstable-iterate-first
                   ] ; end i
                   [n 0
                   ] ; end n
                  ) ; end loop args
          (if i
              (let-values ([(k v) (swisstable-iterate-key+value st i
                                  ) ; end swisstable-iterate-key+value
                           ] ; end k v
                          ) ; end let-values args
                (unless (and (= v (* k k
                                  ) ; end *
                             ) ; end =
                             (equal? k (swisstable-iterate-key st i
                                       ) ; end swisstable-iterate-key
                             ) ; end equal?
                             (equal? v (swisstable-iterate-value st i
                                       ) ; end swisstable-iterate-value
                             ) ; end equal?
                        ) ; end and
                  (error 'cursor "mismatch"
                  ) ; end error
                ) ; end unless
                (loop (swisstable-iterate-next st i
                      ) ; end swisstable-iterate-next
                      (add1 n
                      ) ; end add1
                ) ; end loop
              ) ; end let-values
              n
          ) ; end if
        ) ; end let
  ) ; end test
  (swisstable-update! st 5 add1
  ) ; end swisstable-update!
  (test 26 swisstable-ref st 5
  ) ; end test
  (swisstable-update! st 'fresh add1 10
  ) ; end swisstable-update!
  (test 11 swisstable-ref st 'fresh
  ) ; end test
  (test 7 swisstable-ref! st 'newkey 7
  ) ; end test
  (test 7 swisstable-ref! st 'newkey 99
  ) ; end test
  (define c (swisstable-copy st
            ) ; end swisstable-copy
  ) ; end define
  (swisstable-set! st 'only-orig 1
  ) ; end swisstable-set!
  (test #t swisstable-has-key? c 'newkey
  ) ; end test
  (test #f swisstable-has-key? c 'only-orig
  ) ; end test
  (test 'equal swisstable-kind c
  ) ; end test
) ; end let

;; ----------------------------------------
;; weak and ephemeron variants

(test 'strong swisstable-weakness (make-swisstable
                                  ) ; end make-swisstable
) ; end test
(test 'weak swisstable-weakness (make-swisstable-weak-eq
                                ) ; end make-swisstable-weak-eq
) ; end test
(test 'ephemeron swisstable-weakness (make-swisstable-ephemeron
                                     ) ; end make-swisstable-ephemeron
) ; end test

;; held keys survive collection; dropped keys disappear
(let ([st (make-swisstable-weak-eq
          ) ; end make-swisstable-weak-eq
      ] ; end st
      [held (for/list ([i (in-range 16
                          ) ; end in-range
                       ] ; end i
                      ) ; end for/list args
              (vector i
              ) ; end vector
            ) ; end for/list
      ] ; end held
     ) ; end let args
  (for ([k (in-list held
           ) ; end in-list
        ] ; end k
        [i (in-naturals
           ) ; end in-naturals
        ] ; end i
       ) ; end for args
    (swisstable-set! st k i
    ) ; end swisstable-set!
  ) ; end for
  (for ([i (in-range 200
           ) ; end in-range
        ] ; end i
       ) ; end for args
    (swisstable-set! st (vector 'drop i
                        ) ; end vector
                     'junk
    ) ; end swisstable-set!
  ) ; end for
  (collect-garbage
  ) ; end collect-garbage
  (collect-garbage
  ) ; end collect-garbage
  (test #t values (<= 16 (swisstable-count st) 40
                  ) ; end <=
  ) ; end test
  (test #t values
        (for/and ([k (in-list held
                     ) ; end in-list
                  ] ; end k
                  [i (in-naturals
                     ) ; end in-naturals
                  ] ; end i
                 ) ; end for/and args
          (equal? i (swisstable-ref st k 'none
                    ) ; end swisstable-ref
          ) ; end equal?
        ) ; end for/and
  ) ; end test
  ;; iteration only visits live entries
  (test #t values
        (for/and ([(k v) (in-swisstable st
                         ) ; end in-swisstable
                  ] ; end k v
                 ) ; end for/and args
          (vector? k
          ) ; end vector?
        ) ; end for/and
  ) ; end test
) ; end let

;; weak: a value that references its key pins the entry;
;; ephemeron: the same cycle is collected
(let ([wst (make-swisstable-weak-eq
           ) ; end make-swisstable-weak-eq
      ] ; end wst
      [est (make-swisstable-ephemeron-eq
           ) ; end make-swisstable-ephemeron-eq
      ] ; end est
     ) ; end let args
  (let ([k1 (vector 'pinned
            ) ; end vector
        ] ; end k1
        [k2 (vector 'cyclic
            ) ; end vector
        ] ; end k2
       ) ; end let args
    (swisstable-set! wst k1 (list k1
                            ) ; end list
    ) ; end swisstable-set!
    (swisstable-set! est k2 (list k2
                            ) ; end list
    ) ; end swisstable-set!
  ) ; end let
  (collect-garbage
  ) ; end collect-garbage
  (collect-garbage
  ) ; end collect-garbage
  (test 1 swisstable-count wst
  ) ; end test
  (test 0 swisstable-count est
  ) ; end test
) ; end let

;; overwrite on weak and ephemeron entries; immediates never weaken
(let ([st (make-swisstable-weak-eqv
          ) ; end make-swisstable-weak-eqv
      ] ; end st
     ) ; end let args
  (for ([i (in-range 50
           ) ; end in-range
        ] ; end i
       ) ; end for args
    (swisstable-set! st i i
    ) ; end swisstable-set!
  ) ; end for
  (swisstable-set! st 7 'seven
  ) ; end swisstable-set!
  (collect-garbage
  ) ; end collect-garbage
  (test 50 swisstable-count st
  ) ; end test
  (test 'seven swisstable-ref st 7
  ) ; end test
) ; end let

;; copy preserves weakness
(let ([st (make-swisstable-weak-eq
          ) ; end make-swisstable-weak-eq
      ] ; end st
      [k (vector 'copy-key
         ) ; end vector
      ] ; end k
     ) ; end let args
  (swisstable-set! st k 1
  ) ; end swisstable-set!
  (test 'weak swisstable-weakness (swisstable-copy st
                                  ) ; end swisstable-copy
  ) ; end test
) ; end let

;; ----------------------------------------
;; dict interface, comprehensions, and hash conversions

(let ([st (make-swisstable
          ) ; end make-swisstable
      ] ; end st
     ) ; end let args
  (test #t dict? st
  ) ; end test
  (dict-set! st "a" 1
  ) ; end dict-set!
  (dict-set! st "b" 2
  ) ; end dict-set!
  (test 2 dict-count st
  ) ; end test
  (test 1 dict-ref st "a"
  ) ; end test
  (test 'none dict-ref st "zzz" 'none
  ) ; end test
  (test #t dict-mutable? st
  ) ; end test
  (test #t dict-can-remove-keys? st
  ) ; end test
  (test #f dict-can-functional-set? st
  ) ; end test
  (test 3 values (for/sum ([(k v) (in-dict st
                                  ) ; end in-dict
                           ] ; end k v
                          ) ; end for/sum args
                   v
                 ) ; end for/sum
  ) ; end test
  (test '(1 2) values (sort (dict-map st (lambda (k v) v
                                         ) ; end lambda
                            ) ; end dict-map
                            <
                      ) ; end sort
  ) ; end test
  (dict-update! st "a" add1
  ) ; end dict-update!
  (test 2 dict-ref st "a"
  ) ; end test
  (dict-remove! st "a"
  ) ; end dict-remove!
  (test 1 dict-count st
  ) ; end test
  (test '("b") values (sort (dict-keys st
                            ) ; end dict-keys
                            string<?
                      ) ; end sort
  ) ; end test
) ; end let

;; dict interface on the pure-Racket fallback backend
(let ([st (fb:make-swisstable 'equal 'strong 0
          ) ; end fb:make-swisstable
      ] ; end st
     ) ; end let args
  (test #t dict? st
  ) ; end test
  (dict-set! st 'k 'v
  ) ; end dict-set!
  (test 'v dict-ref st 'k
  ) ; end test
  (test 1 dict-count st
  ) ; end test
  (test '((k . v)) dict->list st
  ) ; end test
  (dict-remove! st 'k
  ) ; end dict-remove!
  (test 0 dict-count st
  ) ; end test
) ; end let

;; for/swisstable and for*/swisstable
(let ([st (for/swisstable ([i (in-range 20
                              ) ; end in-range
           ] ; end i
          ) ; end clauses
            (values i (* i i
                      ) ; end *
            ) ; end values
          ) ; end for/swisstable
      ] ; end st
     ) ; end let args
  (test 20 swisstable-count st
  ) ; end test
  (test 81 swisstable-ref st 9
  ) ; end test
) ; end let

(let ([st (for*/swisstable ([i (in-range 3
                               ) ; end in-range
                            ] ; end i
                            [j (in-range 3
                               ) ; end in-range
                            ] ; end j
           ) ; end clauses
            (values (cons i j) (+ i j
                               ) ; end +
            ) ; end values
          ) ; end for*/swisstable
      ] ; end st
     ) ; end let args
  (test 9 swisstable-count st
  ) ; end test
  (test 3 swisstable-ref st '(1 . 2)
  ) ; end test
) ; end let

;; conversions
(let* ([st (for/swisstable ([i (in-range 10
                               ) ; end in-range
                            ] ; end i
            ) ; end clauses
             (values i (- i
                       ) ; end -
             ) ; end values
           ) ; end for/swisstable
       ] ; end st
       [h (swisstable->hash st
          ) ; end swisstable->hash
       ] ; end h
      ) ; end let* args
  (test #t hash? h
  ) ; end test
  (test #t hash-equal? h
  ) ; end test
  (test 10 hash-count h
  ) ; end test
  (test -7 hash-ref h 7
  ) ; end test
) ; end let*

(let ([st (hash->swisstable (make-hasheq '((1 . one) (2 . two)
                                          ) ; end alist
                            ) ; end make-hasheq
          ) ; end hash->swisstable
      ] ; end st
     ) ; end let args
  (test 'eq swisstable-kind st
  ) ; end test
  (test 'strong swisstable-weakness st
  ) ; end test
  (test 'one swisstable-ref st 1
  ) ; end test
) ; end let

(test 'weak swisstable-weakness (hash->swisstable (make-weak-hasheqv
                                                  ) ; end make-weak-hasheqv
                                ) ; end hash->swisstable
) ; end test
(test 'ephemeron swisstable-weakness (hash->swisstable (make-ephemeron-hash
                                                       ) ; end make-ephemeron-hash
                                     ) ; end hash->swisstable
) ; end test
(err/rt-test (hash->swisstable (make-hashalw
                               ) ; end make-hashalw
             ) ; end hash->swisstable
             exn:fail:contract?
) ; end err/rt-test

;; ----------------------------------------
;; structural equality, hashing, and direct sequence iteration

(let ([a (for/swisstable ([i (in-range 40
                             ) ; end in-range
          ] ; end i
         ) ; end clauses
           (values i (* i i
                     ) ; end *
           ) ; end values
         ) ; end for/swisstable
      ] ; end a
      [b (for/swisstable ([i (in-range 40
                             ) ; end in-range
          ] ; end i
         ) ; end clauses
           (values (- 39 i) (* (- 39 i) (- 39 i)
                            ) ; end *
           ) ; end values
         ) ; end for/swisstable
      ] ; end b
      [c (for/swisstable ([i (in-range 39
                             ) ; end in-range
          ] ; end i
         ) ; end clauses
           (values i (* i i
                     ) ; end *
           ) ; end values
         ) ; end for/swisstable
      ] ; end c
     ) ; end let args
  (test #t equal? a b
  ) ; end test
  (test #f equal? a c
  ) ; end test
  (test #f equal? a (make-swisstable-eq
                    ) ; end make-swisstable-eq
  ) ; end test
  (test #f equal? a (make-swisstable-weak
                    ) ; end make-swisstable-weak
  ) ; end test
  (test #t values (= (equal-hash-code a) (equal-hash-code b
                                         ) ; end equal-hash-code
                  ) ; end =
  ) ; end test
  ;; usable as a key of an equal?-based table
  (let ([outer (make-hash
               ) ; end make-hash
        ] ; end outer
       ) ; end let args
    (hash-set! outer a 'found
    ) ; end hash-set!
    (test 'found hash-ref outer b 'missing
    ) ; end test
  ) ; end let
  ;; direct iteration: a swisstable is a two-valued sequence
  (test (for/sum ([i (in-range 40
                     ) ; end in-range
                  ] ; end i
                 ) ; end for/sum args
          (* i i
          ) ; end *
        ) ; end for/sum
        values
        (for/sum ([(k v) a
                  ] ; end k v
                 ) ; end for/sum args
          v
        ) ; end for/sum
  ) ; end test
) ; end let

;; nested equal? through recur; fallback backend parity
(let ([n1 (make-swisstable
          ) ; end make-swisstable
      ] ; end n1
      [n2 (make-swisstable
          ) ; end make-swisstable
      ] ; end n2
      [f1 (fb:make-swisstable 'equal 'strong 0
          ) ; end fb:make-swisstable
      ] ; end f1
      [f2 (fb:make-swisstable 'equal 'strong 0
          ) ; end fb:make-swisstable
      ] ; end f2
     ) ; end let args
  (swisstable-set! n1 (string-append "k" "1"
                      ) ; end string-append
                   (list 1 2
                   ) ; end list
  ) ; end swisstable-set!
  (swisstable-set! n2 "k1" (list 1 2
                           ) ; end list
  ) ; end swisstable-set!
  (test #t equal? n1 n2
  ) ; end test
  (fb:swisstable-set! f1 'x 1
  ) ; end fb:swisstable-set!
  (fb:swisstable-set! f2 'x 1
  ) ; end fb:swisstable-set!
  (test #t equal? f1 f2
  ) ; end test
  (test 1 values (for/sum ([(k v) f1
                           ] ; end k v
                          ) ; end for/sum args
                   v
                 ) ; end for/sum
  ) ; end test
) ; end let

;; ----------------------------------------
;; printing via installed custom-write

(let ([st (make-swisstable-eq
          ) ; end make-swisstable-eq
      ] ; end st
     ) ; end let args
  (swisstable-set! st 'a 1
  ) ; end swisstable-set!
  (swisstable-set! st 'b 2
  ) ; end swisstable-set!
  (test #t values
        (and (regexp-match? #rx"swisstable:eq count=2"
                            (format "~a" st
                            ) ; end format
             ) ; end regexp-match?
             #t
        ) ; end and
  ) ; end test
) ; end let

;; ----------------------------------------
;; error cases

(err/rt-test (swisstable-ref (make-swisstable
                             ) ; end make-swisstable
                             'missing-key
             ) ; end swisstable-ref
             exn:fail:contract?
) ; end err/rt-test
(err/rt-test (swisstable-count 5
             ) ; end swisstable-count
             exn:fail:contract?
) ; end err/rt-test
(err/rt-test (swisstable-set! "not a table" 'k 'v
             ) ; end swisstable-set!
             exn:fail:contract?
) ; end err/rt-test
(err/rt-test (make-swisstable -1
             ) ; end make-swisstable
             exn:fail:contract?
) ; end err/rt-test
(err/rt-test (raw:make-swisstable 'bogus-kind 0
             ) ; end raw:make-swisstable
             exn:fail:contract?
) ; end err/rt-test
(err/rt-test (swisstable-iterate-key (make-swisstable
                                     ) ; end make-swisstable
                                     0
             ) ; end swisstable-iterate-key
             exn:fail:contract?
) ; end err/rt-test

;; ----------------------------------------
;; adapter/back-end introspection and the pure-Racket fallback

(test #t values (and (memq (swisstable-runtime-adapter-backend
                           ) ; end swisstable-runtime-adapter-backend
                           '(cs-core racket
                            ) ; end list
                     ) ; end memq
                     #t
                ) ; end and
) ; end test
(test #t boolean? (swisstable-runtime-adapter-core-available?
                  ) ; end swisstable-runtime-adapter-core-avail...
) ; end test

;; exercise the fallback implementation directly, regardless of the
;; backend the adapter picked
(let ([st (fb:make-swisstable 'equal 'strong 0
          ) ; end fb:make-swisstable
      ] ; end st
     ) ; end let args
  (random-seed 5150
  ) ; end random-seed
  (define gold (make-hash
               ) ; end make-hash
  ) ; end define
  (for ([step (in-range 8000
              ) ; end in-range
        ] ; end step
       ) ; end for args
    (define k (random 300
              ) ; end random
    ) ; end define
    (if (< (random 10) 6
        ) ; end <
        (let ([v (random 1000
                 ) ; end random
              ] ; end v
             ) ; end let args
          (hash-set! gold k v
          ) ; end hash-set!
          (fb:swisstable-set! st k v
          ) ; end fb:swisstable-set!
        ) ; end let
        (begin
          (hash-remove! gold k
          ) ; end hash-remove!
          (fb:swisstable-remove! st k
          ) ; end fb:swisstable-remove!
        ) ; end begin
    ) ; end if
  ) ; end for
  (test (hash-count gold) fb:swisstable-count st
  ) ; end test
  (test #t values
        (for/and ([(k v) (in-hash gold
                         ) ; end in-hash
                  ] ; end k v
                 ) ; end for/and args
          (equal? v (fb:swisstable-ref st k 'none
                    ) ; end fb:swisstable-ref
          ) ; end equal?
        ) ; end for/and
  ) ; end test
) ; end let

(report-errs
) ; end report-errs
