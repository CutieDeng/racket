#lang racket/base

(require rackunit
         racket/intmap
         racket/list
         racket/serialize
         racket/stream
         (prefix-in adapter: racket/private/intmap-runtime-adapter
         ) ; end prefix-in
) ; end require

(define (kernel-value name
        ) ; end kernel-value
  (dynamic-require ''#%kernel name
  ) ; end dynamic-require
) ; end define

(define (kernel-procedure? name
        ) ; end kernel-procedure?
  (with-handlers ([exn:fail? (lambda (_) #f
                             ) ; end lambda
                  ] ; end exn:fail?
                 ) ; end form
    (procedure? (kernel-value name
                ) ; end kernel-value
    ) ; end procedure?
  ) ; end with-handlers
) ; end define

(define core-required?
  (eq? (system-type 'vm) 'chez-scheme
  ) ; end eq?
) ; end define

(define core-intmap-names
  '(core-intmap?
    core-intmap-empty
    core-intmap-empty?
    core-intmap-count
    core-intmap-ref
    core-intmap-has-key?
    core-intmap-set
    core-intmap-update
    core-intmap-replace
    core-intmap-set/absent
    core-intmap-remove
    core-intmap-remove/eq
    core-intmap-remove/equal
    core-intmap-replace/eq
    core-intmap-replace/equal
    core-intmap-entry<
    core-intmap-entry<=
    core-intmap-entry>
    core-intmap-entry>=
    core-intmap-min-entry
    core-intmap-max-entry
    core-intmap-range->list
    core-sorted-vector->intmap
    core-intmap-cursor-start
    core-intmap-cursor-key
    core-intmap-cursor-value
    core-intmap-cursor-next
    core-intmap-cursor-key+value+next
    core-intmap-shape-stats
    core-intmap-install-struct-property!
   ) ; end core-intmap?
) ; end define

(when core-required?
  (for ([name (in-list core-intmap-names
              ) ; end in-list
        ] ; end name
       ) ; end form
    (unless (kernel-procedure? name
            ) ; end kernel-procedure?
      (error 'intmap-runtime-adapter
             "missing CS kernel primitive: ~s"
             name
      ) ; end error
    ) ; end unless
  ) ; end for
) ; end when

(define expected-entries
  '((-5 . neg
    ) ; end -5
    (0 . zero
    ) ; end 0
    (1 . one
    ) ; end 1
    (7 . seven
    ) ; end 7
    (1208925819614629174706176 . big
    ) ; end 1208925819614629174706176
   ) ; end form
) ; end define

(test-case "public intmap basics"
  (define m (sorted-list->intmap expected-entries
            ) ; end sorted-list->intmap
  ) ; end define
  (check-true (intmap? m
              ) ; end intmap?
  ) ; end check-true
  (check-equal? (intmap-count m) (length expected-entries
                                 ) ; end length
  ) ; end check-equal?
  (check-equal? (intmap-range->list m #f #f) expected-entries
  ) ; end check-equal?
  (check-equal? (for/list ([(k v) m]) (cons k v)) expected-entries
  ) ; end check-equal?
  (check-equal? (for/list ([(k v) (in-intmap m #:reverse? #t)]) (cons k v
                                                                 ) ; end cons
                  ) ; end for/list
                (reverse expected-entries
                ) ; end reverse
  ) ; end check-equal?
  (check-equal? (for/list ([k (in-intmap-keys m #:reverse? #t)]) k
                ) ; end for/list
                (map car (reverse expected-entries
                         ) ; end reverse
                ) ; end map
  ) ; end check-equal?
  (check-equal? (for/list ([v (in-intmap-values m #:reverse? #t)]) v
                ) ; end for/list
                (map cdr (reverse expected-entries
                         ) ; end reverse
                ) ; end map
  ) ; end check-equal?
  (check-equal? (for/list ([p (in-intmap-pairs m #:reverse? #t)]) p
                ) ; end for/list
                (reverse expected-entries
                ) ; end reverse
  ) ; end check-equal?
  (check-equal? (intmap-ref m 7) 'seven
  ) ; end check-equal?
  (check-equal? (intmap-entry< m 7) '(1 . one
                                     ) ; end 1
  ) ; end check-equal?
  (check-equal? (intmap-entry>= m 2) '(7 . seven
                                      ) ; end 7
  ) ; end check-equal?
  (check-equal? (intmap-range->list m 0 8) '((0 . zero) (1 . one) (7 . seven
                                                                  ) ; end 7
                                            ) ; end form
  ) ; end check-equal?
  (define range-entries '((0 . zero) (1 . one) (7 . seven
                                               ) ; end 7
                         ) ; end form
  ) ; end define
  (check-equal? (for/list ([(k v) (in-intmap-range m 0 8 #:reverse? #t)])
                  (cons k v
                  ) ; end cons
                ) ; end for/list
                (reverse range-entries
                ) ; end reverse
  ) ; end check-equal?
  (check-equal? (for/list ([k (in-intmap-range-keys m 0 8 #:reverse? #t)]) k
                ) ; end for/list
                (map car (reverse range-entries
                         ) ; end reverse
                ) ; end map
  ) ; end check-equal?
  (check-equal? (for/list ([v (in-intmap-range-values m 0 8 #:reverse? #t)]) v
                ) ; end for/list
                (map cdr (reverse range-entries
                         ) ; end reverse
                ) ; end map
  ) ; end check-equal?
  (check-equal? (for/list ([p (in-intmap-range-pairs m 0 8 #:reverse? #t)]) p
                ) ; end for/list
                (reverse range-entries
                ) ; end reverse
  ) ; end check-equal?
) ; end test-case

(test-case "public conditional update operations"
  (define old-list (list 'old
                   ) ; end list
  ) ; end define
  (define same-shape-list (list 'old
                          ) ; end list
  ) ; end define
  (define m (intmap 1 old-list 2 'two
            ) ; end intmap
  ) ; end define
  (define m1 (intmap-update m 3 (lambda () 'three
                                ) ; end lambda
                            (lambda (_) 'bad
                            ) ; end lambda
             ) ; end intmap-update
  ) ; end define
  (define m2 (intmap-update m1 2 'absent (lambda (v) (list v 'seen
                                                   ) ; end list
                                          ) ; end lambda
             ) ; end intmap-update
  ) ; end define
  (define m3 (intmap-update m2 4 'four 'present-value
             ) ; end intmap-update
  ) ; end define
  (define m4 (intmap-update m3 2 'absent 'dos
             ) ; end intmap-update
  ) ; end define
  (check-equal? (intmap-ref m1 3) 'three
  ) ; end check-equal?
  (check-equal? (intmap-ref m2 2) '(two seen
                                        ) ; end two
  ) ; end check-equal?
  (check-equal? (intmap-ref m3 4) 'four
  ) ; end check-equal?
  (check-equal? (intmap-ref m4 2) 'dos
  ) ; end check-equal?
  (check-equal? (intmap-ref m 2) 'two
  ) ; end check-equal?

  (define-values (inserted-map inserted?)
    (intmap-set/absent m 5 'five
    ) ; end intmap-set/absent
  ) ; end define-values
  (define-values (not-inserted-map not-inserted?)
    (intmap-set/absent m 2 'TWO
    ) ; end intmap-set/absent
  ) ; end define-values
  (check-true inserted?
  ) ; end check-true
  (check-false not-inserted?
  ) ; end check-false
  (check-equal? (intmap-ref inserted-map 5) 'five
  ) ; end check-equal?
  (check-eq? not-inserted-map m
  ) ; end check-eq?

  (define-values (replaced-map replaced?)
    (intmap-replace m 2 'TWO
    ) ; end intmap-replace
  ) ; end define-values
  (define-values (not-replaced-map not-replaced?)
    (intmap-replace m 9 'nine
    ) ; end intmap-replace
  ) ; end define-values
  (check-true replaced?
  ) ; end check-true
  (check-false not-replaced?
  ) ; end check-false
  (check-equal? (intmap-ref replaced-map 2) 'TWO
  ) ; end check-equal?
  (check-eq? not-replaced-map m
  ) ; end check-eq?

  (define-values (eq-fail-map eq-fail?)
    (intmap-replace/eq m 1 same-shape-list 'new
    ) ; end intmap-replace/eq
  ) ; end define-values
  (define-values (eq-ok-map eq-ok?)
    (intmap-replace/eq m 1 old-list 'new
    ) ; end intmap-replace/eq
  ) ; end define-values
  (define-values (equal-ok-map equal-ok?)
    (intmap-replace/equal m 1 same-shape-list 'new
    ) ; end intmap-replace/equal
  ) ; end define-values
  (check-false eq-fail?
  ) ; end check-false
  (check-eq? eq-fail-map m
  ) ; end check-eq?
  (check-true eq-ok?
  ) ; end check-true
  (check-true equal-ok?
  ) ; end check-true
  (check-equal? (intmap-ref eq-ok-map 1) 'new
  ) ; end check-equal?
  (check-equal? (intmap-ref equal-ok-map 1) 'new
  ) ; end check-equal?

  (define-values (remove-eq-fail-map remove-eq-fail?)
    (intmap-remove/eq m 1 same-shape-list
    ) ; end intmap-remove/eq
  ) ; end define-values
  (define-values (remove-equal-map remove-equal?)
    (intmap-remove/equal m 1 same-shape-list
    ) ; end intmap-remove/equal
  ) ; end define-values
  (check-false remove-eq-fail?
  ) ; end check-false
  (check-eq? remove-eq-fail-map m
  ) ; end check-eq?
  (check-true remove-equal?
  ) ; end check-true
  (check-false (intmap-has-key? remove-equal-map 1
                ) ; end intmap-has-key?
  ) ; end check-false
) ; end test-case

(test-case "public stream and serialization"
  (define m (sorted-list->intmap expected-entries
            ) ; end sorted-list->intmap
  ) ; end define
  (check-true (stream? m
              ) ; end stream?
  ) ; end check-true
  (check-false (stream-empty? m
               ) ; end stream-empty?
  ) ; end check-false
  (check-equal? (stream-first m) '(-5 . neg
                                  ) ; end -5
  ) ; end check-equal?
  (check-equal? (stream->list m) expected-entries
  ) ; end check-equal?
  (check-equal? (stream->list (stream-rest m)) (cdr expected-entries
                                               ) ; end cdr
  ) ; end check-equal?
  (check-true (stream-empty? intmap-empty
              ) ; end stream-empty?
  ) ; end check-true
  (check-equal? (deserialize (serialize m)) m
  ) ; end check-equal?
) ; end test-case

(define (entry-key<? a b
        ) ; end entry-key<?
  (< (car a) (car b
             ) ; end car
  ) ; end <
) ; end define

(define (model-entries h
        ) ; end model-entries
  (sort (hash->list h) entry-key<?
  ) ; end sort
) ; end define

(define (model-entry< entries k
        ) ; end model-entry<
  (for/fold ([best #f]) ([entry (in-list entries
                                ) ; end in-list
                         ] ; end entry
                        ) ; end form
    (if (< (car entry) k) entry best
    ) ; end if
  ) ; end for/fold
) ; end define

(define (model-entry>= entries k
        ) ; end model-entry>=
  (for/first ([entry (in-list entries
                     ) ; end in-list
              ] ; end entry
              #:when (>= (car entry) k
                     ) ; end >=
             ) ; end :when
    entry
  ) ; end for/first
) ; end define

(test-case "random differential operations"
  (define big (arithmetic-shift 1 80
              ) ; end arithmetic-shift
  ) ; end define
  (define key-pool
    (append (for/list ([i (in-range -25 26)]) i
            ) ; end for/list
            (for/list ([i (in-range 8)]) (+ big i
                                         ) ; end +
            ) ; end for/list
    ) ; end append
  ) ; end define
  (random-seed 20260626
  ) ; end random-seed
  (let loop ([i 0] [m intmap-empty] [model (hash
                                           ) ; end hash
                                    ] ; end model
            ) ; end form
    (when (< i 300
          ) ; end <
      (define k (list-ref key-pool (random (length key-pool
                                           ) ; end length
                                   ) ; end random
                ) ; end list-ref
      ) ; end define
      (define-values (m* model*
                     ) ; end m*
        (if (zero? (random 3
                   ) ; end random
            ) ; end zero?
            (values (intmap-remove m k) (hash-remove model k
                                        ) ; end hash-remove
            ) ; end values
            (let ([v (list 'v i k
                     ) ; end list
                  ] ; end v
                 ) ; end form
              (values (intmap-set m k v) (hash-set model k v
                                         ) ; end hash-set
              ) ; end values
            ) ; end let
        ) ; end if
      ) ; end define-values
      (define entries (model-entries model*
                      ) ; end model-entries
      ) ; end define
      (check-equal? (intmap-count m*) (length entries
                                      ) ; end length
      ) ; end check-equal?
      (check-equal? (intmap-range->list m* #f #f) entries
      ) ; end check-equal?
      (for ([probe (in-list key-pool
                   ) ; end in-list
            ] ; end probe
           ) ; end form
        (check-equal? (intmap-has-key? m* probe) (hash-has-key? model* probe
                                                 ) ; end hash-has-key?
        ) ; end check-equal?
        (check-equal? (intmap-ref m* probe #f) (hash-ref model* probe #f
                                               ) ; end hash-ref
        ) ; end check-equal?
      ) ; end for
      (define lo (list-ref key-pool (random (length key-pool
                                            ) ; end length
                                    ) ; end random
                 ) ; end list-ref
      ) ; end define
      (define hi (list-ref key-pool (random (length key-pool
                                            ) ; end length
                                    ) ; end random
                 ) ; end list-ref
      ) ; end define
      (define lo* (min lo hi
                  ) ; end min
      ) ; end define
      (define hi* (max lo hi
                  ) ; end max
      ) ; end define
      (check-equal? (intmap-range->list m* lo* hi*
                    ) ; end intmap-range->list
                    (filter (lambda (entry
                                    ) ; end entry
                              (and (<= lo* (car entry
                                           ) ; end car
                                   ) ; end <=
                                   (< (car entry) hi*
                                   ) ; end <
                              ) ; end and
                            ) ; end lambda
                            entries
                    ) ; end filter
      ) ; end check-equal?
      (define q (list-ref key-pool (random (length key-pool
                                           ) ; end length
                                   ) ; end random
                ) ; end list-ref
      ) ; end define
      (check-equal? (intmap-entry< m* q) (model-entry< entries q
                                         ) ; end model-entry<
      ) ; end check-equal?
      (check-equal? (intmap-entry>= m* q) (model-entry>= entries q
                                          ) ; end model-entry>=
      ) ; end check-equal?
      (loop (add1 i) m* model*
      ) ; end loop
    ) ; end when
  ) ; end let
) ; end test-case

(test-case "random differential conditional operations"
  (define missing (gensym 'missing
                  ) ; end gensym
  ) ; end define
  (define big (arithmetic-shift 1 80
              ) ; end arithmetic-shift
  ) ; end define
  (define key-pool
    (append (for/list ([i (in-range -12 13)]) i
            ) ; end for/list
            (for/list ([i (in-range 5)]) (+ big i
                                         ) ; end +
            ) ; end for/list
    ) ; end append
  ) ; end define
  (define (bad-branch
          ) ; end bad-branch
    (error 'intmap-test "inactive update branch called"
    ) ; end error
  ) ; end define
  (define (checked-model m model
          ) ; end checked-model
    (define entries (model-entries model
                    ) ; end model-entries
    ) ; end define
    (check-equal? (intmap-count m) (length entries
                                   ) ; end length
    ) ; end check-equal?
    (check-equal? (intmap-range->list m #f #f) entries
    ) ; end check-equal?
    (for ([probe (in-list key-pool
                 ) ; end in-list
          ] ; end probe
         ) ; end form
      (check-equal? (intmap-ref m probe missing)
                    (hash-ref model probe missing
                    ) ; end hash-ref
      ) ; end check-equal?
    ) ; end for
  ) ; end define
  (random-seed 20260627
  ) ; end random-seed
  (let loop ([i 0] [m intmap-empty] [model (hash
                                           ) ; end hash
                                    ] ; end model
            ) ; end form
    (when (< i 250
          ) ; end <
      (define k (list-ref key-pool (random (length key-pool
                                           ) ; end length
                                   ) ; end random
                ) ; end list-ref
      ) ; end define
      (define old (hash-ref model k missing
                  ) ; end hash-ref
      ) ; end define
      (define present? (not (eq? old missing
                            ) ; end eq?
                       ) ; end not
      ) ; end define
      (define fresh (list 'v i k
                    ) ; end list
      ) ; end define
      (define-values (m* model*
                     ) ; end m*
        (case (random 8
              ) ; end random
          [(0
           ) ; end 0
           (values (intmap-set m k fresh
                   ) ; end intmap-set
                   (hash-set model k fresh
                   ) ; end hash-set
           ) ; end values
          ] ; end clause
          [(1
           ) ; end 1
           (if present?
               (let ([replacement (list 'updated old i
                                  ) ; end list
                     ] ; end replacement
                    ) ; end form
                 (values (intmap-update m k bad-branch (lambda (v
                                                            ) ; end v
                                                        replacement
                                                     ) ; end lambda
                         ) ; end intmap-update
                         (hash-set model k replacement
                         ) ; end hash-set
                 ) ; end values
               ) ; end let
               (values (intmap-update m k (lambda (
                                           ) ; end form
                                      fresh
                                   ) ; end lambda
                                   (lambda (_) (bad-branch
                                               ) ; end bad-branch
                                   ) ; end lambda
                       ) ; end intmap-update
                       (hash-set model k fresh
                       ) ; end hash-set
               ) ; end values
           ) ; end if
          ] ; end clause
          [(2
           ) ; end 2
           (let-values ([(m2 inserted?
                         ) ; end m2
                         (intmap-set/absent m k fresh
                         ) ; end intmap-set/absent
                        ] ; end clause
                       ) ; end form
             (check-equal? inserted? (not present?
                                      ) ; end not
             ) ; end check-equal?
             (values m2
                     (if present? model (hash-set model k fresh
                                        ) ; end hash-set
                     ) ; end if
             ) ; end values
           ) ; end let-values
          ] ; end clause
          [(3
           ) ; end 3
           (let-values ([(m2 replaced?
                         ) ; end m2
                         (intmap-replace m k fresh
                         ) ; end intmap-replace
                        ] ; end clause
                       ) ; end form
             (check-equal? replaced? present?
             ) ; end check-equal?
             (values m2
                     (if present? (hash-set model k fresh
                                  ) ; end hash-set
                         model
                     ) ; end if
             ) ; end values
           ) ; end let-values
          ] ; end clause
          [(4
           ) ; end 4
           (define expected (if (and present? (even? i
                                             ) ; end even?
                                ) ; end and
                                old
                                (list 'miss old
                                ) ; end list
                            ) ; end if
           ) ; end define
           (define should-change? (and present? (equal? expected old
                                                 ) ; end equal?
                                  ) ; end and
           ) ; end define
           (let-values ([(m2 changed?
                         ) ; end m2
                         (intmap-replace/equal m k expected fresh
                         ) ; end intmap-replace/equal
                        ] ; end clause
                       ) ; end form
             (check-equal? changed? should-change?
             ) ; end check-equal?
             (values m2
                     (if should-change? (hash-set model k fresh
                                        ) ; end hash-set
                         model
                     ) ; end if
             ) ; end values
           ) ; end let-values
          ] ; end clause
          [(5
           ) ; end 5
           (define expected (if (and present? (even? i
                                             ) ; end even?
                                ) ; end and
                                old
                                (list 'miss old
                                ) ; end list
                            ) ; end if
           ) ; end define
           (define should-change? (and present? (eq? expected old
                                              ) ; end eq?
                                  ) ; end and
           ) ; end define
           (let-values ([(m2 changed?
                         ) ; end m2
                         (intmap-replace/eq m k expected fresh
                         ) ; end intmap-replace/eq
                        ] ; end clause
                       ) ; end form
             (check-equal? changed? should-change?
             ) ; end check-equal?
             (values m2
                     (if should-change? (hash-set model k fresh
                                        ) ; end hash-set
                         model
                     ) ; end if
             ) ; end values
           ) ; end let-values
          ] ; end clause
          [(6
           ) ; end 6
           (define expected (if (and present? (even? i
                                             ) ; end even?
                                ) ; end and
                                old
                                (list 'miss old
                                ) ; end list
                            ) ; end if
           ) ; end define
           (define should-remove? (and present? (equal? expected old
                                                ) ; end equal?
                                  ) ; end and
           ) ; end define
           (let-values ([(m2 removed?
                         ) ; end m2
                         (intmap-remove/equal m k expected
                         ) ; end intmap-remove/equal
                        ] ; end clause
                       ) ; end form
             (check-equal? removed? should-remove?
             ) ; end check-equal?
             (values m2
                     (if should-remove? (hash-remove model k
                                        ) ; end hash-remove
                         model
                     ) ; end if
             ) ; end values
           ) ; end let-values
          ] ; end clause
          [else
           (define expected (if (and present? (even? i
                                             ) ; end even?
                                ) ; end and
                                old
                                (list 'miss old
                                ) ; end list
                            ) ; end if
           ) ; end define
           (define should-remove? (and present? (eq? expected old
                                             ) ; end eq?
                                  ) ; end and
           ) ; end define
           (let-values ([(m2 removed?
                         ) ; end m2
                         (intmap-remove/eq m k expected
                         ) ; end intmap-remove/eq
                        ] ; end clause
                       ) ; end form
             (check-equal? removed? should-remove?
             ) ; end check-equal?
             (values m2
                     (if should-remove? (hash-remove model k
                                        ) ; end hash-remove
                         model
                     ) ; end if
             ) ; end values
           ) ; end let-values
          ] ; end else
        ) ; end case
      ) ; end define-values
      (checked-model m* model*
      ) ; end checked-model
      (loop (add1 i) m* model*
      ) ; end loop
    ) ; end when
  ) ; end let
) ; end test-case

(test-case "CS kernel intmap primitives"
  (when core-required?
    (for ([name (in-list core-intmap-names
                ) ; end in-list
          ] ; end name
         ) ; end form
      (check-true (kernel-procedure? name) (symbol->string name
                                           ) ; end symbol->string
      ) ; end check-true
    ) ; end for

    (define core-empty (kernel-value 'core-intmap-empty
                       ) ; end kernel-value
    ) ; end define
    (define core-set (kernel-value 'core-intmap-set
                     ) ; end kernel-value
    ) ; end define
    (define core-update (kernel-value 'core-intmap-update
                        ) ; end kernel-value
    ) ; end define
    (define core-replace (kernel-value 'core-intmap-replace
                         ) ; end kernel-value
    ) ; end define
    (define core-set/absent (kernel-value 'core-intmap-set/absent
                            ) ; end kernel-value
    ) ; end define
    (define core-count (kernel-value 'core-intmap-count
                       ) ; end kernel-value
    ) ; end define
    (define core-ref (kernel-value 'core-intmap-ref
                     ) ; end kernel-value
    ) ; end define
    (define core-range->list (kernel-value 'core-intmap-range->list
                             ) ; end kernel-value
    ) ; end define
    (define core-entry< (kernel-value 'core-intmap-entry<
                        ) ; end kernel-value
    ) ; end define
    (define core-entry>= (kernel-value 'core-intmap-entry>=
                         ) ; end kernel-value
    ) ; end define
    (define core-remove (kernel-value 'core-intmap-remove
                        ) ; end kernel-value
    ) ; end define
    (define core-remove/eq (kernel-value 'core-intmap-remove/eq
                           ) ; end kernel-value
    ) ; end define
    (define core-remove/equal (kernel-value 'core-intmap-remove/equal
                              ) ; end kernel-value
    ) ; end define
    (define core-replace/eq (kernel-value 'core-intmap-replace/eq
                            ) ; end kernel-value
    ) ; end define
    (define core-replace/equal (kernel-value 'core-intmap-replace/equal
                               ) ; end kernel-value
    ) ; end define
    (define core-cursor-start (kernel-value 'core-intmap-cursor-start
                              ) ; end kernel-value
    ) ; end define
    (define core-cursor-key (kernel-value 'core-intmap-cursor-key
                            ) ; end kernel-value
    ) ; end define
    (define core-cursor-value (kernel-value 'core-intmap-cursor-value
                              ) ; end kernel-value
    ) ; end define
    (define core-cursor-next (kernel-value 'core-intmap-cursor-next
                             ) ; end kernel-value
    ) ; end define
    (define core-shape-stats (kernel-value 'core-intmap-shape-stats
                             ) ; end kernel-value
    ) ; end define

    (define m
      (for/fold ([m (core-empty)]) ([p (in-list expected-entries
                                       ) ; end in-list
                                    ] ; end p
                                   ) ; end form
        (core-set m (car p) (cdr p
                            ) ; end cdr
        ) ; end core-set
      ) ; end for/fold
    ) ; end define

    (check-equal? (core-count m) (length expected-entries
                                 ) ; end length
    ) ; end check-equal?
    (check-equal? (core-ref m 7 'missing) 'seven
    ) ; end check-equal?
    (check-equal? (core-entry< m 7 #f) '(1 . one
                                        ) ; end 1
    ) ; end check-equal?
    (check-equal? (core-entry>= m 2 #f) '(7 . seven
                                         ) ; end 7
    ) ; end check-equal?
    (check-equal? (core-range->list m 0 8 #t #f
                  ) ; end core-range->list
                  '((0 . zero) (1 . one) (7 . seven
                                         ) ; end 7
                   ) ; end form
    ) ; end check-equal?
    (check-equal? (core-range->list (core-remove m 1) #f #f #t #f
                  ) ; end core-range->list
                  '((-5 . neg) (0 . zero) (7 . seven) (1208925819614629174706176 . big
                                                      ) ; end 1208925819614629174706176
                   ) ; end form
    ) ; end check-equal?

    (define core-updated
      (core-update m 7 'missing (lambda (v) (list v 'updated
                                            ) ; end list
                                 ) ; end lambda
      ) ; end core-update
    ) ; end define
    (define core-inserted-by-update
      (core-update core-updated 42 (lambda () 'forty-two
                                   ) ; end lambda
                   'present
      ) ; end core-update
    ) ; end define
    (check-equal? (core-ref core-updated 7 #f) '(seven updated
                                                       ) ; end seven
    ) ; end check-equal?
    (check-equal? (core-ref core-inserted-by-update 42 #f) 'forty-two
    ) ; end check-equal?

    (define-values (core-inserted core-inserted?)
      (core-set/absent m 42 'forty-two
      ) ; end core-set/absent
    ) ; end define-values
    (define-values (core-not-inserted core-not-inserted?)
      (core-set/absent m 7 'SEVEN
      ) ; end core-set/absent
    ) ; end define-values
    (check-true core-inserted?
    ) ; end check-true
    (check-false core-not-inserted?
    ) ; end check-false
    (check-equal? (core-ref core-inserted 42 #f) 'forty-two
    ) ; end check-equal?
    (check-eq? core-not-inserted m
    ) ; end check-eq?

    (define-values (core-replaced core-replaced?)
      (core-replace m 7 'SEVEN
      ) ; end core-replace
    ) ; end define-values
    (define-values (core-not-replaced core-not-replaced?)
      (core-replace m 99 'ninety-nine
      ) ; end core-replace
    ) ; end define-values
    (check-true core-replaced?
    ) ; end check-true
    (check-false core-not-replaced?
    ) ; end check-false
    (check-equal? (core-ref core-replaced 7 #f) 'SEVEN
    ) ; end check-equal?
    (check-eq? core-not-replaced m
    ) ; end check-eq?

    (define core-old-list (list 'old
                          ) ; end list
    ) ; end define
    (define core-same-shape-list (list 'old
                                 ) ; end list
    ) ; end define
    (define core-list-map (core-set (core-empty) 1 core-old-list
                          ) ; end core-set
    ) ; end define
    (define-values (core-eq-fail core-eq-fail?)
      (core-replace/eq core-list-map 1 core-same-shape-list 'new
      ) ; end core-replace/eq
    ) ; end define-values
    (define-values (core-eq-ok core-eq-ok?)
      (core-replace/eq core-list-map 1 core-old-list 'new
      ) ; end core-replace/eq
    ) ; end define-values
    (define-values (core-equal-ok core-equal-ok?)
      (core-replace/equal core-list-map 1 core-same-shape-list 'new
      ) ; end core-replace/equal
    ) ; end define-values
    (check-false core-eq-fail?
    ) ; end check-false
    (check-eq? core-eq-fail core-list-map
    ) ; end check-eq?
    (check-true core-eq-ok?
    ) ; end check-true
    (check-true core-equal-ok?
    ) ; end check-true
    (check-equal? (core-ref core-eq-ok 1 #f) 'new
    ) ; end check-equal?
    (check-equal? (core-ref core-equal-ok 1 #f) 'new
    ) ; end check-equal?

    (define-values (core-remove-eq-fail core-remove-eq-fail?)
      (core-remove/eq core-list-map 1 core-same-shape-list
      ) ; end core-remove/eq
    ) ; end define-values
    (define-values (core-remove-equal-ok core-remove-equal-ok?)
      (core-remove/equal core-list-map 1 core-same-shape-list
      ) ; end core-remove/equal
    ) ; end define-values
    (check-false core-remove-eq-fail?
    ) ; end check-false
    (check-eq? core-remove-eq-fail core-list-map
    ) ; end check-eq?
    (check-true core-remove-equal-ok?
    ) ; end check-true
    (check-equal? (core-count core-remove-equal-ok) 0
    ) ; end check-equal?

    (check-equal? (hash-ref (core-shape-stats m) 'backend) 'core
    ) ; end check-equal?

    (let loop ([cursor (core-cursor-start m #f 0 8 #t #f)] [acc '(
                                                                 ) ; end form
                                                           ] ; end acc
              ) ; end form
      (if cursor
          (loop (core-cursor-next cursor
                ) ; end core-cursor-next
                (cons (cons (core-cursor-key cursor
                            ) ; end core-cursor-key
                            (core-cursor-value cursor
                            ) ; end core-cursor-value
                      ) ; end cons
                      acc
                ) ; end cons
          ) ; end loop
          (check-equal? (reverse acc) '((0 . zero) (1 . one) (7 . seven
                                                             ) ; end 7
                                       ) ; end form
          ) ; end check-equal?
      ) ; end if
    ) ; end let
    (let loop ([cursor (core-cursor-start m #t 0 8 #t #f)] [acc '(
                                                                 ) ; end form
                                                           ] ; end acc
              ) ; end form
      (if cursor
          (loop (core-cursor-next cursor
                ) ; end core-cursor-next
                (cons (cons (core-cursor-key cursor
                            ) ; end core-cursor-key
                            (core-cursor-value cursor
                            ) ; end core-cursor-value
                      ) ; end cons
                      acc
                ) ; end cons
          ) ; end loop
          (check-equal? (reverse acc) '((7 . seven) (1 . one) (0 . zero
                                                              ) ; end 0
                                       ) ; end form
          ) ; end check-equal?
      ) ; end if
    ) ; end let
  ) ; end when
) ; end test-case

(test-case "adapter selects CS backend when available"
  (when core-required?
    (check-eq? (adapter:intmap-runtime-adapter-backend) 'cs-core
    ) ; end check-eq?
    (check-true (adapter:intmap-runtime-adapter-core-available?
                ) ; end adapter:intmap-runtime-adapter-core-a...
    ) ; end check-true
    (check-true (adapter:intmap-runtime-adapter-cursor-available?
                ) ; end adapter:intmap-runtime-adapter-cursor...
    ) ; end check-true
  ) ; end when
) ; end test-case
