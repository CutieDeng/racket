#lang racket/base

(require (prefix-in fallback: "intmap.rkt"
         ) ; end prefix-in
         (only-in racket/pretty pretty-write
         ) ; end only-in
) ; end require

(provide
 intmap?
 intmap
 intmap-empty
 intmap-empty?
 intmap-count
 intmap-ref
 intmap-has-key?
 intmap-set
 intmap-update
 intmap-replace
 intmap-set/absent
 intmap-remove
 intmap-remove/eq
 intmap-remove/equal
 intmap-replace/eq
 intmap-replace/equal
 intmap-entry<
 intmap-entry<=
 intmap-entry>
 intmap-entry>=
 intmap-min-entry
 intmap-max-entry
 intmap-range->list
 in-intmap
 in-intmap-keys
 in-intmap-values
 in-intmap-pairs
 in-intmap-range
 in-intmap-range-keys
 in-intmap-range-values
 in-intmap-range-pairs
 sorted-list->intmap
 sorted-vector->intmap
 intmap->literal-datum
 literal-datum->intmap
 write-intmap-literal
 intmap-shape-stats
 intmap-runtime-adapter-backend
 intmap-runtime-adapter-core-available?
 intmap-runtime-adapter-cursor-available?
 intmap-runtime-adapter-public-properties-available?
 intmap-install-struct-property!
) ; end provide

(define missing-default (gensym 'missing
                        ) ; end gensym
) ; end define

(define (maybe-kernel name
        ) ; end maybe-kernel
  (with-handlers ([exn:fail? (lambda (_) #f
                             ) ; end lambda
                  ] ; end exn:fail?
                 ) ; end form
    (dynamic-require ''#%kernel name
    ) ; end dynamic-require
  ) ; end with-handlers
) ; end define

(define core-intmap? (maybe-kernel 'core-intmap?
                     ) ; end maybe-kernel
) ; end define
(define core-intmap-empty (maybe-kernel 'core-intmap-empty
                          ) ; end maybe-kernel
) ; end define
(define core-intmap-empty? (maybe-kernel 'core-intmap-empty?
                           ) ; end maybe-kernel
) ; end define
(define core-intmap-count (maybe-kernel 'core-intmap-count
                          ) ; end maybe-kernel
) ; end define
(define core-intmap-ref (maybe-kernel 'core-intmap-ref
                        ) ; end maybe-kernel
) ; end define
(define core-intmap-has-key? (maybe-kernel 'core-intmap-has-key?
                             ) ; end maybe-kernel
) ; end define
(define core-intmap-set (maybe-kernel 'core-intmap-set
                        ) ; end maybe-kernel
) ; end define
(define core-intmap-update (maybe-kernel 'core-intmap-update
                           ) ; end maybe-kernel
) ; end define
(define core-intmap-replace (maybe-kernel 'core-intmap-replace
                            ) ; end maybe-kernel
) ; end define
(define core-intmap-set/absent (maybe-kernel 'core-intmap-set/absent
                               ) ; end maybe-kernel
) ; end define
(define core-intmap-remove (maybe-kernel 'core-intmap-remove
                           ) ; end maybe-kernel
) ; end define
(define core-intmap-remove/eq (maybe-kernel 'core-intmap-remove/eq
                              ) ; end maybe-kernel
) ; end define
(define core-intmap-remove/equal (maybe-kernel 'core-intmap-remove/equal
                                 ) ; end maybe-kernel
) ; end define
(define core-intmap-replace/eq (maybe-kernel 'core-intmap-replace/eq
                               ) ; end maybe-kernel
) ; end define
(define core-intmap-replace/equal (maybe-kernel 'core-intmap-replace/equal
                                  ) ; end maybe-kernel
) ; end define
(define core-intmap-entry< (maybe-kernel 'core-intmap-entry<
                           ) ; end maybe-kernel
) ; end define
(define core-intmap-entry<= (maybe-kernel 'core-intmap-entry<=
                            ) ; end maybe-kernel
) ; end define
(define core-intmap-entry> (maybe-kernel 'core-intmap-entry>
                           ) ; end maybe-kernel
) ; end define
(define core-intmap-entry>= (maybe-kernel 'core-intmap-entry>=
                            ) ; end maybe-kernel
) ; end define
(define core-intmap-min-entry (maybe-kernel 'core-intmap-min-entry
                              ) ; end maybe-kernel
) ; end define
(define core-intmap-max-entry (maybe-kernel 'core-intmap-max-entry
                              ) ; end maybe-kernel
) ; end define
(define core-intmap-range->list (maybe-kernel 'core-intmap-range->list
                                ) ; end maybe-kernel
) ; end define
(define core-sorted-vector->intmap (maybe-kernel 'core-sorted-vector->intmap
                                   ) ; end maybe-kernel
) ; end define
(define core-intmap-literal->intmap (maybe-kernel 'core-intmap-literal->intmap
                                    ) ; end maybe-kernel
) ; end define
(define core-intmap-shape-stats (maybe-kernel 'core-intmap-shape-stats
                                ) ; end maybe-kernel
) ; end define
(define core-intmap-install-struct-property!
  (maybe-kernel 'core-intmap-install-struct-property!
  ) ; end maybe-kernel
) ; end define
(define core-intmap-cursor-start (maybe-kernel 'core-intmap-cursor-start
                                 ) ; end maybe-kernel
) ; end define
(define core-intmap-cursor-key (maybe-kernel 'core-intmap-cursor-key
                               ) ; end maybe-kernel
) ; end define
(define core-intmap-cursor-value (maybe-kernel 'core-intmap-cursor-value
                                 ) ; end maybe-kernel
) ; end define
(define core-intmap-cursor-next (maybe-kernel 'core-intmap-cursor-next
                                ) ; end maybe-kernel
) ; end define
(define core-intmap-cursor-key+value+next
  (maybe-kernel 'core-intmap-cursor-key+value+next
  ) ; end maybe-kernel
) ; end define

(define core-bindings
  (list core-intmap?
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
        core-intmap-shape-stats
  ) ; end list
) ; end define

(define compiled-core-available?
  (andmap procedure? core-bindings
  ) ; end andmap
) ; end define

(define core-available?
  (and compiled-core-available?
       (with-handlers ([exn:fail? (lambda (_) #f
                                  ) ; end lambda
                       ] ; end exn:fail?
                      ) ; end form
         (define m (core-intmap-set (core-intmap-empty) 1 'one
                   ) ; end core-intmap-set
         ) ; end define
         (and (core-intmap? m
              ) ; end core-intmap?
              (= 1 (core-intmap-count m
                   ) ; end core-intmap-count
              ) ; end =
              (equal? 'one (core-intmap-ref m 1 missing-default
                           ) ; end core-intmap-ref
              ) ; end equal?
              (equal? '((1 . one
                        ) ; end 1
                       ) ; end form
                      (core-intmap-range->list m #f #f #t #f
                      ) ; end core-intmap-range->list
              ) ; end equal?
         ) ; end and
       ) ; end with-handlers
  ) ; end and
) ; end define

(define core-cursor-available?
  (and core-available?
       (procedure? core-intmap-cursor-start
       ) ; end procedure?
       (procedure? core-intmap-cursor-key
       ) ; end procedure?
       (procedure? core-intmap-cursor-value
       ) ; end procedure?
       (procedure? core-intmap-cursor-next
       ) ; end procedure?
  ) ; end and
) ; end define

(define core-cursor-combined-available?
  (and core-cursor-available?
       (procedure? core-intmap-cursor-key+value+next
       ) ; end procedure?
  ) ; end and
) ; end define

(define core-public-properties-available?
  (and core-available?
       (procedure? core-intmap-install-struct-property!
       ) ; end procedure?
  ) ; end and
) ; end define

(define (intmap-runtime-adapter-backend
        ) ; end intmap-runtime-adapter-backend
  (if core-available? 'cs-core 'racket
  ) ; end if
) ; end define

(define (intmap-runtime-adapter-core-available?
        ) ; end intmap-runtime-adapter-core-available?
  core-available?
) ; end define

(define (intmap-runtime-adapter-cursor-available?
        ) ; end intmap-runtime-adapter-cursor-available?
  core-cursor-available?
) ; end define

(define (intmap-runtime-adapter-public-properties-available?
        ) ; end intmap-runtime-adapter-public-propert...
  core-public-properties-available?
) ; end define

(define (intmap? v
        ) ; end intmap?
  (if core-available?
      (core-intmap? v
      ) ; end core-intmap?
      (fallback:intmap? v
      ) ; end fallback:intmap?
  ) ; end if
) ; end define

(define (check-intmap who v
        ) ; end check-intmap
  (unless (intmap? v
          ) ; end intmap?
    (raise-argument-error who "intmap?" v
    ) ; end raise-argument-error
  ) ; end unless
) ; end define

(define (check-key who k
        ) ; end check-key
  (unless (exact-integer? k
          ) ; end exact-integer?
    (raise-argument-error who "exact-integer?" k
    ) ; end raise-argument-error
  ) ; end unless
) ; end define

(define intmap-empty
  (if core-available?
      (core-intmap-empty
      ) ; end core-intmap-empty
      fallback:intmap-empty
  ) ; end if
) ; end define

(define (intmap-empty? v
        ) ; end intmap-empty?
  (if core-available?
      (core-intmap-empty? v
      ) ; end core-intmap-empty?
      (fallback:intmap-empty? v
      ) ; end fallback:intmap-empty?
  ) ; end if
) ; end define

(define (intmap . kvs
        ) ; end intmap
  (let loop ([kvs kvs] [m intmap-empty
                       ] ; end m
            ) ; end form
    (cond
      [(null? kvs) m
      ] ; end m
      [(null? (cdr kvs
              ) ; end cdr
       ) ; end null?
       (raise-arguments-error 'intmap "expected an even number of key/value arguments"
       ) ; end raise-arguments-error
      ] ; end clause
      [else (loop (cddr kvs) (intmap-set m (car kvs) (cadr kvs
                                                     ) ; end cadr
                             ) ; end intmap-set
            ) ; end loop
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (intmap-count m
        ) ; end intmap-count
  (check-intmap 'intmap-count m
  ) ; end check-intmap
  (if core-available?
      (core-intmap-count m
      ) ; end core-intmap-count
      (fallback:intmap-count m
      ) ; end fallback:intmap-count
  ) ; end if
) ; end define

(define (intmap-ref m k [default missing-default
                        ] ; end default
        ) ; end intmap-ref
  (check-intmap 'intmap-ref m
  ) ; end check-intmap
  (check-key 'intmap-ref k
  ) ; end check-key
  (if core-available?
      (let ([v (core-intmap-ref m k missing-default
               ) ; end core-intmap-ref
            ] ; end v
           ) ; end form
        (cond
          [(not (eq? v missing-default)) v
          ] ; end v
          [(eq? default missing-default
           ) ; end eq?
           (raise-arguments-error 'intmap-ref "no value found for key" "key" k
           ) ; end raise-arguments-error
          ] ; end clause
          [(procedure? default) (default
                                ) ; end default
          ] ; end clause
          [else default
          ] ; end else
        ) ; end cond
      ) ; end let
      (if (eq? default missing-default
          ) ; end eq?
          (fallback:intmap-ref m k
          ) ; end fallback:intmap-ref
          (fallback:intmap-ref m k default
          ) ; end fallback:intmap-ref
      ) ; end if
  ) ; end if
) ; end define

(define (intmap-has-key? m k
        ) ; end intmap-has-key?
  (check-intmap 'intmap-has-key? m
  ) ; end check-intmap
  (check-key 'intmap-has-key? k
  ) ; end check-key
  (if core-available?
      (core-intmap-has-key? m k
      ) ; end core-intmap-has-key?
      (fallback:intmap-has-key? m k
      ) ; end fallback:intmap-has-key?
  ) ; end if
) ; end define

(define (intmap-set m k v
        ) ; end intmap-set
  (check-intmap 'intmap-set m
  ) ; end check-intmap
  (check-key 'intmap-set k
  ) ; end check-key
  (if core-available?
      (core-intmap-set m k v
      ) ; end core-intmap-set
      (fallback:intmap-set m k v
      ) ; end fallback:intmap-set
  ) ; end if
) ; end define

(define (intmap-update m k absent present
        ) ; end intmap-update
  (check-intmap 'intmap-update m
  ) ; end check-intmap
  (check-key 'intmap-update k
  ) ; end check-key
  (if core-available?
      (core-intmap-update m k absent present
      ) ; end core-intmap-update
      (fallback:intmap-update m k absent present
      ) ; end fallback:intmap-update
  ) ; end if
) ; end define

(define (intmap-replace m k v
        ) ; end intmap-replace
  (check-intmap 'intmap-replace m
  ) ; end check-intmap
  (check-key 'intmap-replace k
  ) ; end check-key
  (if core-available?
      (core-intmap-replace m k v
      ) ; end core-intmap-replace
      (fallback:intmap-replace m k v
      ) ; end fallback:intmap-replace
  ) ; end if
) ; end define

(define (intmap-set/absent m k v
        ) ; end intmap-set/absent
  (check-intmap 'intmap-set/absent m
  ) ; end check-intmap
  (check-key 'intmap-set/absent k
  ) ; end check-key
  (if core-available?
      (core-intmap-set/absent m k v
      ) ; end core-intmap-set/absent
      (fallback:intmap-set/absent m k v
      ) ; end fallback:intmap-set/absent
  ) ; end if
) ; end define

(define (intmap-remove m k
        ) ; end intmap-remove
  (check-intmap 'intmap-remove m
  ) ; end check-intmap
  (check-key 'intmap-remove k
  ) ; end check-key
  (if core-available?
      (core-intmap-remove m k
      ) ; end core-intmap-remove
      (fallback:intmap-remove m k
      ) ; end fallback:intmap-remove
  ) ; end if
) ; end define

(define (intmap-remove/eq m k expected
        ) ; end intmap-remove/eq
  (check-intmap 'intmap-remove/eq m
  ) ; end check-intmap
  (check-key 'intmap-remove/eq k
  ) ; end check-key
  (if core-available?
      (core-intmap-remove/eq m k expected
      ) ; end core-intmap-remove/eq
      (fallback:intmap-remove/eq m k expected
      ) ; end fallback:intmap-remove/eq
  ) ; end if
) ; end define

(define (intmap-remove/equal m k expected
        ) ; end intmap-remove/equal
  (check-intmap 'intmap-remove/equal m
  ) ; end check-intmap
  (check-key 'intmap-remove/equal k
  ) ; end check-key
  (if core-available?
      (core-intmap-remove/equal m k expected
      ) ; end core-intmap-remove/equal
      (fallback:intmap-remove/equal m k expected
      ) ; end fallback:intmap-remove/equal
  ) ; end if
) ; end define

(define (intmap-replace/eq m k expected v
        ) ; end intmap-replace/eq
  (check-intmap 'intmap-replace/eq m
  ) ; end check-intmap
  (check-key 'intmap-replace/eq k
  ) ; end check-key
  (if core-available?
      (core-intmap-replace/eq m k expected v
      ) ; end core-intmap-replace/eq
      (fallback:intmap-replace/eq m k expected v
      ) ; end fallback:intmap-replace/eq
  ) ; end if
) ; end define

(define (intmap-replace/equal m k expected v
        ) ; end intmap-replace/equal
  (check-intmap 'intmap-replace/equal m
  ) ; end check-intmap
  (check-key 'intmap-replace/equal k
  ) ; end check-key
  (if core-available?
      (core-intmap-replace/equal m k expected v
      ) ; end core-intmap-replace/equal
      (fallback:intmap-replace/equal m k expected v
      ) ; end fallback:intmap-replace/equal
  ) ; end if
) ; end define

(define (intmap-entry< m k [default #f
                           ] ; end default
        ) ; end intmap-entry<
  (check-intmap 'intmap-entry< m
  ) ; end check-intmap
  (check-key 'intmap-entry< k
  ) ; end check-key
  (if core-available?
      (core-intmap-entry< m k default
      ) ; end core-intmap-entry<
      (fallback:intmap-entry< m k default
      ) ; end fallback:intmap-entry<
  ) ; end if
) ; end define

(define (intmap-entry<= m k [default #f
                            ] ; end default
        ) ; end intmap-entry<=
  (check-intmap 'intmap-entry<= m
  ) ; end check-intmap
  (check-key 'intmap-entry<= k
  ) ; end check-key
  (if core-available?
      (core-intmap-entry<= m k default
      ) ; end core-intmap-entry<=
      (fallback:intmap-entry<= m k default
      ) ; end fallback:intmap-entry<=
  ) ; end if
) ; end define

(define (intmap-entry> m k [default #f
                           ] ; end default
        ) ; end intmap-entry>
  (check-intmap 'intmap-entry> m
  ) ; end check-intmap
  (check-key 'intmap-entry> k
  ) ; end check-key
  (if core-available?
      (core-intmap-entry> m k default
      ) ; end core-intmap-entry>
      (fallback:intmap-entry> m k default
      ) ; end fallback:intmap-entry>
  ) ; end if
) ; end define

(define (intmap-entry>= m k [default #f
                            ] ; end default
        ) ; end intmap-entry>=
  (check-intmap 'intmap-entry>= m
  ) ; end check-intmap
  (check-key 'intmap-entry>= k
  ) ; end check-key
  (if core-available?
      (core-intmap-entry>= m k default
      ) ; end core-intmap-entry>=
      (fallback:intmap-entry>= m k default
      ) ; end fallback:intmap-entry>=
  ) ; end if
) ; end define

(define (intmap-min-entry m [default missing-default
                            ] ; end default
        ) ; end intmap-min-entry
  (check-intmap 'intmap-min-entry m
  ) ; end check-intmap
  (if core-available?
      (let ([v (core-intmap-min-entry m missing-default
               ) ; end core-intmap-min-entry
            ] ; end v
           ) ; end form
        (cond
          [(not (eq? v missing-default)) v
          ] ; end v
          [(eq? default missing-default
           ) ; end eq?
           (raise-arguments-error 'intmap-min-entry "empty intmap"
           ) ; end raise-arguments-error
          ] ; end clause
          [else default
          ] ; end else
        ) ; end cond
      ) ; end let
      (if (eq? default missing-default
          ) ; end eq?
          (fallback:intmap-min-entry m
          ) ; end fallback:intmap-min-entry
          (fallback:intmap-min-entry m default
          ) ; end fallback:intmap-min-entry
      ) ; end if
  ) ; end if
) ; end define

(define (intmap-max-entry m [default missing-default
                            ] ; end default
        ) ; end intmap-max-entry
  (check-intmap 'intmap-max-entry m
  ) ; end check-intmap
  (if core-available?
      (let ([v (core-intmap-max-entry m missing-default
               ) ; end core-intmap-max-entry
            ] ; end v
           ) ; end form
        (cond
          [(not (eq? v missing-default)) v
          ] ; end v
          [(eq? default missing-default
           ) ; end eq?
           (raise-arguments-error 'intmap-max-entry "empty intmap"
           ) ; end raise-arguments-error
          ] ; end clause
          [else default
          ] ; end else
        ) ; end cond
      ) ; end let
      (if (eq? default missing-default
          ) ; end eq?
          (fallback:intmap-max-entry m
          ) ; end fallback:intmap-max-entry
          (fallback:intmap-max-entry m default
          ) ; end fallback:intmap-max-entry
      ) ; end if
  ) ; end if
) ; end define

(define (intmap-range->list m [lo #f] [hi #f
                                      ] ; end hi
                            [inclusive-lo? #t] [inclusive-hi? #f
                                               ] ; end inclusive-hi?
        ) ; end intmap-range->list
  (check-intmap 'intmap-range->list m
  ) ; end check-intmap
  (when lo (check-key 'intmap-range->list lo
           ) ; end check-key
  ) ; end when
  (when hi (check-key 'intmap-range->list hi
           ) ; end check-key
  ) ; end when
  (if core-available?
      (core-intmap-range->list m lo hi inclusive-lo? inclusive-hi?
      ) ; end core-intmap-range->list
      (fallback:intmap-range->list m lo hi inclusive-lo? inclusive-hi?
      ) ; end fallback:intmap-range->list
  ) ; end if
) ; end define

(define (cursor-sequence start mode
        ) ; end cursor-sequence
  (make-do-sequence
   (lambda (
           ) ; end form
     (values
      (case mode
        [(entries
         ) ; end entries
         (lambda (cursor
                 ) ; end cursor
           (values (core-intmap-cursor-key cursor
                   ) ; end core-intmap-cursor-key
                   (core-intmap-cursor-value cursor
                   ) ; end core-intmap-cursor-value
           ) ; end values
         ) ; end lambda
        ] ; end clause
        [(keys) core-intmap-cursor-key
        ] ; end core-intmap-cursor-key
        [(values) core-intmap-cursor-value
        ] ; end core-intmap-cursor-value
        [(pairs
         ) ; end pairs
         (lambda (cursor
                 ) ; end cursor
           (cons (core-intmap-cursor-key cursor
                 ) ; end core-intmap-cursor-key
                 (core-intmap-cursor-value cursor
                 ) ; end core-intmap-cursor-value
           ) ; end cons
         ) ; end lambda
        ] ; end clause
      ) ; end case
      core-intmap-cursor-next
      start
      values
      #f
      #f
     ) ; end values
   ) ; end lambda
  ) ; end make-do-sequence
) ; end define

(define (core-sequence m reverse? lo hi inclusive-lo? inclusive-hi? mode
        ) ; end core-sequence
  (cursor-sequence
   (core-intmap-cursor-start m reverse? lo hi inclusive-lo? inclusive-hi?
   ) ; end core-intmap-cursor-start
   mode
  ) ; end cursor-sequence
) ; end define

(define (in-intmap m #:reverse? [reverse? #f
                                ] ; end reverse?
        ) ; end in-intmap
  (if core-cursor-available?
      (core-sequence m reverse? #f #f #t #f 'entries
      ) ; end core-sequence
      (fallback:in-intmap m #:reverse? reverse?
      ) ; end fallback:in-intmap
  ) ; end if
) ; end define

(define (in-intmap-keys m #:reverse? [reverse? #f
                                     ] ; end reverse?
        ) ; end in-intmap-keys
  (if core-cursor-available?
      (core-sequence m reverse? #f #f #t #f 'keys
      ) ; end core-sequence
      (fallback:in-intmap-keys m #:reverse? reverse?
      ) ; end fallback:in-intmap-keys
  ) ; end if
) ; end define

(define (in-intmap-values m #:reverse? [reverse? #f
                                       ] ; end reverse?
        ) ; end in-intmap-values
  (if core-cursor-available?
      (core-sequence m reverse? #f #f #t #f 'values
      ) ; end core-sequence
      (fallback:in-intmap-values m #:reverse? reverse?
      ) ; end fallback:in-intmap-values
  ) ; end if
) ; end define

(define (in-intmap-pairs m #:reverse? [reverse? #f
                                      ] ; end reverse?
        ) ; end in-intmap-pairs
  (if core-cursor-available?
      (core-sequence m reverse? #f #f #t #f 'pairs
      ) ; end core-sequence
      (fallback:in-intmap-pairs m #:reverse? reverse?
      ) ; end fallback:in-intmap-pairs
  ) ; end if
) ; end define

(define (in-intmap-range m lo hi #:reverse? [reverse? #f
                                            ] ; end reverse?
        ) ; end in-intmap-range
  (if core-cursor-available?
      (core-sequence m reverse? lo hi #t #f 'entries
      ) ; end core-sequence
      (fallback:in-intmap-range m lo hi #:reverse? reverse?
      ) ; end fallback:in-intmap-range
  ) ; end if
) ; end define

(define (in-intmap-range-keys m lo hi #:reverse? [reverse? #f
                                                 ] ; end reverse?
        ) ; end in-intmap-range-keys
  (if core-cursor-available?
      (core-sequence m reverse? lo hi #t #f 'keys
      ) ; end core-sequence
      (fallback:in-intmap-range-keys m lo hi #:reverse? reverse?
      ) ; end fallback:in-intmap-range-keys
  ) ; end if
) ; end define

(define (in-intmap-range-values m lo hi #:reverse? [reverse? #f
                                                   ] ; end reverse?
        ) ; end in-intmap-range-values
  (if core-cursor-available?
      (core-sequence m reverse? lo hi #t #f 'values
      ) ; end core-sequence
      (fallback:in-intmap-range-values m lo hi #:reverse? reverse?
      ) ; end fallback:in-intmap-range-values
  ) ; end if
) ; end define

(define (in-intmap-range-pairs m lo hi #:reverse? [reverse? #f
                                                  ] ; end reverse?
        ) ; end in-intmap-range-pairs
  (if core-cursor-available?
      (core-sequence m reverse? lo hi #t #f 'pairs
      ) ; end core-sequence
      (fallback:in-intmap-range-pairs m lo hi #:reverse? reverse?
      ) ; end fallback:in-intmap-range-pairs
  ) ; end if
) ; end define

(define (sorted-vector->intmap vec
        ) ; end sorted-vector->intmap
  (unless (vector? vec
          ) ; end vector?
    (raise-argument-error 'sorted-vector->intmap "vector?" vec
    ) ; end raise-argument-error
  ) ; end unless
  (if core-available?
      (core-sorted-vector->intmap vec
      ) ; end core-sorted-vector->intmap
      (fallback:sorted-vector->intmap vec
      ) ; end fallback:sorted-vector->intmap
  ) ; end if
) ; end define

(define (sorted-list->intmap entries
        ) ; end sorted-list->intmap
  (unless (list? entries
          ) ; end list?
    (raise-argument-error 'sorted-list->intmap "list?" entries
    ) ; end raise-argument-error
  ) ; end unless
  (if core-available?
      (sorted-vector->intmap (list->vector entries
                             ) ; end list->vector
      ) ; end sorted-vector->intmap
      (fallback:sorted-list->intmap entries
      ) ; end fallback:sorted-list->intmap
  ) ; end if
) ; end define

(define (intmap->literal-datum m
        ) ; end intmap->literal-datum
  (check-intmap 'intmap->literal-datum m
  ) ; end check-intmap
  (intmap-range->list m #f #f
  ) ; end intmap-range->list
) ; end define

(define (literal-datum->intmap datum
        ) ; end literal-datum->intmap
  (unless (list? datum
          ) ; end list?
    (raise-argument-error 'literal-datum->intmap "list?" datum
    ) ; end raise-argument-error
  ) ; end unless
  (if (and (procedure? core-intmap-literal->intmap
           ) ; end procedure?
           (procedure-arity-includes? core-intmap-literal->intmap 3
           ) ; end procedure-arity-includes?
      ) ; end and
      (core-intmap-literal->intmap datum #f #f
      ) ; end core-intmap-literal->intmap
      (fallback:literal-datum->intmap datum
      ) ; end fallback:literal-datum->intmap
  ) ; end if
) ; end define

(define (write-intmap-literal m [port (current-output-port
                                      ) ; end current-output-port
                               ] ; end port
                              #:pretty? [pretty? #f
                                         ] ; end pretty?
        ) ; end write-intmap-literal
  (check-intmap 'write-intmap-literal m
  ) ; end check-intmap
  (unless (output-port? port
          ) ; end output-port?
    (raise-argument-error 'write-intmap-literal "output-port?" port
    ) ; end raise-argument-error
  ) ; end unless
  (unless (boolean? pretty?
          ) ; end boolean?
    (raise-argument-error 'write-intmap-literal "boolean?" pretty?
    ) ; end raise-argument-error
  ) ; end unless
  (display "#intmap" port
  ) ; end display
  (let ([datum (intmap->literal-datum m
               ) ; end intmap->literal-datum
        ] ; end datum
       ) ; end let args
    (if pretty?
        (pretty-write datum port
        ) ; end pretty-write
        (write datum port
        ) ; end write
    ) ; end if
  ) ; end let
  (void
  ) ; end void
) ; end define

(define (intmap-shape-stats m
        ) ; end intmap-shape-stats
  (check-intmap 'intmap-shape-stats m
  ) ; end check-intmap
  (if core-available?
      (core-intmap-shape-stats m
      ) ; end core-intmap-shape-stats
      (fallback:intmap-shape-stats m
      ) ; end fallback:intmap-shape-stats
  ) ; end if
) ; end define

(define (intmap-install-struct-property! . args
        ) ; end intmap-install-struct-property!
  (if core-public-properties-available?
      (apply core-intmap-install-struct-property! args
      ) ; end apply
      (apply fallback:intmap-install-struct-property! args
      ) ; end apply
  ) ; end if
) ; end define
