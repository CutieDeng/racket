
(load-relative "loadtest.rktl"
) ; end load-relative

(Section 'intbits
) ; end Section

(require racket/intbits
) ; end require

(define bits (list->intbits '(0 2 5 2
                            ) ; end quote
             ) ; end list->intbits
) ; end define
(define all-but-bits (intbits-complement bits
                     ) ; end intbits-complement
) ; end define

(test #t intbits? -1
) ; end test
(test #t intbits? 0
) ; end test
(test #f intbits? 1.0
) ; end test
(test #f intbits-finite? -1
) ; end test
(test #t intbits-finite? bits
) ; end test
(test 0 values intbits-empty
) ; end test
(test #t intbits-empty? intbits-empty
) ; end test
(test #f intbits-empty? -1
) ; end test

(test '(0 2 5) intbits->list bits
) ; end test
(test 3 intbits-count bits
) ; end test
(test 6 intbits-width bits
) ; end test
(test 0 intbits-first bits
) ; end test
(test 5 intbits-last bits
) ; end test
(test #f intbits-first intbits-empty
) ; end test
(test #f intbits-last intbits-empty
) ; end test

(test #t intbits-ref bits 2
) ; end test
(test #f intbits-ref bits 3
) ; end test
(test '(0 1 2 5) intbits->list (intbits-set bits 1
                                 ) ; end intbits-set
) ; end test
(test '(0 5) intbits->list (intbits-clear bits 2
                            ) ; end intbits-clear
) ; end test
(test '(0 5) intbits->list (intbits-set bits 2 #f
                            ) ; end intbits-set
) ; end test
(test '(0 2 3 5) intbits->list (intbits-toggle bits 3
                                 ) ; end intbits-toggle
) ; end test
(test '(0 5) intbits->list (intbits-toggle bits 2
                            ) ; end intbits-toggle
) ; end test

(test '(0 1 2 5) intbits->list (intbits-union bits #b10
                                 ) ; end intbits-union
) ; end test
(test '(2 5) intbits->list (intbits-intersect bits #b100100
                            ) ; end intbits-intersect
) ; end test
(test '(0) intbits->list (intbits-subtract bits #b100100
                          ) ; end intbits-subtract
) ; end test
(test '(0 1 5) intbits->list (intbits-xor bits #b110
                              ) ; end intbits-xor
) ; end test
(test #t intbits-subset? #b101 #b111
) ; end test
(test #f intbits-subset? #b101 #b011
) ; end test
(test #t intbits-intersects? bits #b100
) ; end test
(test #t intbits-disjoint? bits #b10010
) ; end test

(test #f intbits-ref all-but-bits 0
) ; end test
(test #t intbits-ref all-but-bits 1
) ; end test
(test #f intbits-ref all-but-bits 2
) ; end test
(test #t intbits-ref all-but-bits 100
) ; end test
(test 1 intbits-first all-but-bits
) ; end test
(test 3 intbits-next all-but-bits 2
) ; end test
(test 4 intbits-prev all-but-bits 4
) ; end test
(test #f intbits-prev -8 2
) ; end test
(test 3 intbits-prev -8 3
) ; end test

(test 4 intbits-count-range -1 3 7
) ; end test
(test '(1 3 4 6) intbits->list/range all-but-bits 0 7
) ; end test
(test '(3 4 5 6) values (for/list ([i (in-intbits-range -1 3 7
                                      ) ; end in-intbits-range
                                ] ; end i
                               ) ; end form
                         i
                       ) ; end for/list
) ; end test
(test '(0 2 5) values (let ([seen null
                            ] ; end seen
                           ) ; end form
                       (intbits-for-each bits
                                         (lambda (i
                                                  ) ; end i
                                           (set! seen (cons i seen
                                                      ) ; end cons
                                           ) ; end set!
                                         ) ; end lambda
                       ) ; end intbits-for-each
                       (reverse seen
                       ) ; end reverse
                     ) ; end let
) ; end test
(test '(1 3 4 6) values (let ([seen null
                              ] ; end seen
                             ) ; end form
                         (intbits-for-each/range all-but-bits 0 7
                                                 (lambda (i
                                                          ) ; end i
                                                   (set! seen (cons i seen
                                                              ) ; end cons
                                                   ) ; end set!
                                                 ) ; end lambda
                         ) ; end intbits-for-each/range
                         (reverse seen
                         ) ; end reverse
                       ) ; end let
) ; end test
(test 7 intbits-fold bits 0
      (lambda (acc i
               ) ; end lambda args
        (+ acc i
        ) ; end +
      ) ; end lambda
) ; end test
(test 18 intbits-fold/range -1 3 7 0
      (lambda (acc i
               ) ; end lambda args
        (+ acc i
        ) ; end +
      ) ; end lambda
) ; end test
(test 'seed intbits-fold intbits-empty 'seed
      (lambda (acc i
               ) ; end lambda args
        'bad
      ) ; end lambda
) ; end test

(test 2 intbits-rank bits 5
) ; end test
(test 5 intbits-select bits 2
) ; end test
(test #f intbits-select bits 3
) ; end test
(test 3 intbits-select -8 0
) ; end test
(test 6 intbits-select -8 3
) ; end test

(test #b11100 intbits-range-mask 2 5
) ; end test
(test #b1111 intbits-field -1 2 6
) ; end test
(test '(0 2 3 4 5) intbits->list (intbits-set-range bits 3 5
                                      ) ; end intbits-set-range
) ; end test
(test '(0 5) intbits->list (intbits-clear-range bits 1 4
                            ) ; end intbits-clear-range
) ; end test
(test '(0 3 5) intbits->list (intbits-toggle-range bits 2 4
                              ) ; end intbits-toggle-range
) ; end test
(test #b110001 values (intbits-replace-field #b111111 1 4 0
                       ) ; end intbits-replace-field
) ; end test
(test #b111110 values (intbits-replace-field 0 1 6 -1
                       ) ; end intbits-replace-field
) ; end test

(test "101001" intbits->string bits
) ; end test
(test "01" intbits->string #b10
) ; end test
(test "101001" intbits->string/range bits 0 6
) ; end test
(test "0101" intbits->string/range all-but-bits 0 4
) ; end test
(test bits string->intbits "101001"
) ; end test
(test '(0 2 5) values (for/list ([i (in-intbits bits
                                  ) ; end in-intbits
                            ] ; end i
                           ) ; end form
                     i
                   ) ; end for/list
) ; end test

(err/rt-test (intbits-count -1) exn:fail:contract?
) ; end err/rt-test
(err/rt-test (intbits-last -1) exn:fail:contract?
) ; end err/rt-test
(err/rt-test (intbits-width -1) exn:fail:contract?
) ; end err/rt-test
(err/rt-test (intbits->list -1) exn:fail:contract?
) ; end err/rt-test
(err/rt-test (intbits->string -1) exn:fail:contract?
) ; end err/rt-test
(err/rt-test (for/list ([i (in-intbits -1
                            ) ; end in-intbits
                      ] ; end i
                     ) ; end form
               i
             ) ; end for/list
             exn:fail:contract?
) ; end err/rt-test
(err/rt-test (intbits-for-each -1 values) exn:fail:contract?
) ; end err/rt-test
(err/rt-test (intbits-for-each/range bits 0 6
                                      (lambda (
                                               ) ; end form
                                        #t
                                      ) ; end lambda
             ) ; end intbits-for-each/range
             exn:fail:contract?
) ; end err/rt-test
(err/rt-test (intbits-fold/range bits 6 0 0
                                 (lambda (acc i
                                          ) ; end lambda args
                                   acc
                                 ) ; end lambda
             ) ; end intbits-fold/range
             exn:fail:contract?
) ; end err/rt-test
(err/rt-test (intbits-ref bits -1) exn:fail:contract?
) ; end err/rt-test
(err/rt-test (intbits-range-mask 5 2) exn:fail:contract?
) ; end err/rt-test
(err/rt-test (string->intbits "102") exn:fail:contract?
) ; end err/rt-test

;; ---------- 变参构造器与推导式 (2026-08-07 增补) ----------

(test '(1 3 5) intbits->list (intbits 1 3 5)
) ; end test
(test 0 'intbits-nullary (intbits
                          ) ; end intbits
) ; end test
(test '(1 3) intbits->list (for/intbits ([i (in-range 5
                                            ) ; end in-range
                                         ] ; end i
                                         #:when (odd? i
                                                ) ; end odd?
                                        ) ; end clauses
                             i
                           ) ; end for/intbits
) ; end test
(test '(0 1 2 3) intbits->list (for*/intbits ([i (in-range 2
                                                  ) ; end in-range
                                               ] ; end i
                                              [j (in-range 2
                                                  ) ; end in-range
                                               ] ; end j
                                             ) ; end clauses
                                 (+ (* 2 i) j
                                 ) ; end +
                               ) ; end for*/intbits
) ; end test
