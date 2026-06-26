
(load-relative "loadtest.rktl"
) ; end load-relative

(Section 'pvector
) ; end Section

(require racket/list
         racket/match
         racket/pvector
         (prefix-in raw: racket/private/pvector-runtime-adapter
         ) ; end prefix-in
) ; end require

(define (def-id def
                ) ; end def-id
  (car def
  ) ; end car
) ; end define

(define (def-val def
                 ) ; end def-val
  (cadr def
  ) ; end cadr
) ; end define

(define (literal-root datum
                      ) ; end literal-root
  (car datum
  ) ; end car
) ; end define

(define (literal-defs datum
                      ) ; end literal-defs
  (cadr datum
  ) ; end cadr
) ; end define

(define (variant-refs val
                      ) ; end variant-refs
  (match val
    [`(Single ,node-id) (list node-id
                        ) ; end list
    ]
    [`(Digit ,_ ,node-ids ...) node-ids
    ]
    [`(Node ,_ ,node-ids ...) node-ids
    ]
    [`(Deep/val ,_ ,left-id ,right-id ,inner-id)
     (if (eq? inner-id 'Empty
         ) ; end eq?
         (list left-id right-id
         ) ; end list
         (list left-id right-id inner-id
         ) ; end list
     ) ; end if
    ]
    [`(Deep ,_ ,left-id ,right-id ,inner-id)
     (if (eq? inner-id 'Empty
         ) ; end eq?
         (list left-id right-id
         ) ; end list
         (list left-id right-id inner-id
         ) ; end list
     ) ; end if
    ]
    [_ null
    ]
  ) ; end match
) ; end define

(define (dense-ascending-defs? defs
                               ) ; end dense-ascending-defs?
  (let loop ([defs defs
             ] ; end defs
             [id 0
             ] ; end id
            ) ; end loop args
    (cond
      [(null? defs) #t
      ]
      [(equal? (def-id (car defs
                       ) ; end car
               ) ; end def-id
               id
       ) ; end equal?
       (loop (cdr defs
             ) ; end cdr
             (add1 id
             ) ; end add1
       ) ; end loop
      ]
      [else #f
      ]
    ) ; end cond
  ) ; end let
) ; end define

(define (forward-refs-ok? defs
                          ) ; end forward-refs-ok?
  (for/and ([def (in-list defs
                    ) ; end in-list
             ] ; end def
            ) ; end for/and clauses
    (define id (def-id def
               ) ; end def-id
    ) ; end define
    (for/and ([ref-id (in-list (variant-refs (def-val def
                                             ) ; end def-val
                               ) ; end variant-refs
                         ) ; end in-list
               ] ; end ref-id
              ) ; end for/and clauses
      (and (exact-nonnegative-integer? ref-id
           ) ; end exact-nonnegative-integer?
           (< ref-id id
           ) ; end <
      ) ; end and
    ) ; end for/and
  ) ; end for/and
) ; end define

(define (literal-datum->list datum
                             ) ; end literal-datum->list
  (define table (make-hasheqv
                ) ; end make-hasheqv
  ) ; end define
  (define (id->list id
                    ) ; end id->list
    (if (eq? id 'Empty
        ) ; end eq?
        null
        (hash-ref table id
        ) ; end hash-ref
    ) ; end if
  ) ; end define
  (define (ids->list ids
                     ) ; end ids->list
    (apply append
           (map id->list ids
           ) ; end map
    ) ; end apply
  ) ; end define
  (define (val->list val
                     ) ; end val->list
    (match val
      [`(Single/val ,x) (list x
                        ) ; end list
      ]
      [`(Single ,node-id) (id->list node-id
                          ) ; end id->list
      ]
      [`(Digit/val ,_ ,xs ...) xs
      ]
      [`(Digit ,_ ,node-ids ...) (ids->list node-ids
                                  ) ; end ids->list
      ]
      [`(Node/val ,_ ,xs ...) xs
      ]
      [`(Node ,_ ,node-ids ...) (ids->list node-ids
                                ) ; end ids->list
      ]
      [`(Deep/val ,_ ,left-id ,right-id ,inner-id)
       (append (id->list left-id
               ) ; end id->list
               (id->list inner-id
               ) ; end id->list
               (id->list right-id
               ) ; end id->list
       ) ; end append
      ]
      [`(Deep ,_ ,left-id ,right-id ,inner-id)
       (append (id->list left-id
               ) ; end id->list
               (id->list inner-id
               ) ; end id->list
               (id->list right-id
               ) ; end id->list
       ) ; end append
      ]
    ) ; end match
  ) ; end define
  (for ([def (in-list (literal-defs datum
                       ) ; end literal-defs
                 ) ; end in-list
        ] ; end def
       ) ; end for clauses
    (hash-set! table
               (def-id def
               ) ; end def-id
               (val->list (def-val def
                          ) ; end def-val
               ) ; end val->list
    ) ; end hash-set!
  ) ; end for
  (id->list (literal-root datum
            ) ; end literal-root
  ) ; end id->list
) ; end define

(test #t pvector-literal-pool? (make-pvector-literal-pool
                               ) ; end make-pvector-literal-pool
) ; end test

(if (raw:pvector-runtime-adapter-literal-available?
    ) ; end raw:pvector-runtime-adapter-literal-available?
    (let ()
      (test '(Empty ()) pvector->literal-datum (pvector-empty
                                               ) ; end pvector-empty
      ) ; end test

      (test '(0 ((0 (Single/val a)))) pvector->literal-datum (pvector 'a
                                                              ) ; end pvector
      ) ; end test

      (test '(2 ((0 (Digit/val 1 a))
                 (1 (Digit/val 1 b))
                 (2 (Deep/val 2 0 1 Empty
                    ) ; end Deep/val
                 ) ; end 2
                ) ; end defs
             ) ; end datum
            pvector->literal-datum
            (pvector 'a 'b
            ) ; end pvector
      ) ; end test

      (test '((a b) #f)
            values
            (pvector->literal-datum (pvector 'a 'b
                                     ) ; end pvector
                                     #:mode 'expanded
            ) ; end pvector->literal-datum
      ) ; end test

      (define many (list->pvector (range 12
                                  ) ; end range
                   ) ; end list->pvector
      ) ; end define
      (define many-datum (pvector->literal-datum many
                         ) ; end pvector->literal-datum
      ) ; end define
      (define many-defs (literal-defs many-datum
                        ) ; end literal-defs
      ) ; end define
      (define many-tags (map (lambda (def
                                      ) ; end def
                               (car (def-val def
                                    ) ; end def-val
                               ) ; end car
                             ) ; end lambda
                             many-defs
                       ) ; end map
      ) ; end define

      (test (range 12
            ) ; end range
            literal-datum->list many-datum
      ) ; end test
      (test (range 12
            ) ; end range
            pvector->list
            (literal-datum->pvector many-datum
            ) ; end literal-datum->pvector
      ) ; end test
      (test #t dense-ascending-defs? many-defs
      ) ; end test
      (test #t forward-refs-ok? many-defs
      ) ; end test
      (test #t values (andmap (lambda (tag
                                      ) ; end tag
                                (and (memq tag many-tags
                                     ) ; end memq
                                     #t
                                ) ; end and
                              ) ; end lambda
                              '(Digit/val Node/val Node Single Deep/val
                                ) ; end quote
                       ) ; end andmap
      ) ; end test

      (define pool (make-pvector-literal-pool
                   ) ; end make-pvector-literal-pool
      ) ; end define
      (define pooled-1 (pvector->literal-datum many pool
                       ) ; end pvector->literal-datum
      ) ; end define
      (define pooled-count (length (literal-defs pooled-1
                                    ) ; end literal-defs
                           ) ; end length
      ) ; end define
      (define pooled-2 (pvector->literal-datum many pool
                       ) ; end pvector->literal-datum
      ) ; end define
      (test (literal-root pooled-1
            ) ; end literal-root
            literal-root pooled-2
      ) ; end test
      (test pooled-count length (literal-defs pooled-2
                                ) ; end literal-defs
      ) ; end test

      (define group (pvectors->literal-datum (list many many
                                            ) ; end list
                                             (make-pvector-literal-pool
                                             ) ; end make-pvector-literal-pool
                    ) ; end pvectors->literal-datum
      ) ; end define
      (test (list (literal-root pooled-1
                  ) ; end literal-root
                  (literal-root pooled-1
                  ) ; end literal-root
            ) ; end list
            literal-root group
      ) ; end test
      (test pooled-count length (literal-defs group
                                ) ; end literal-defs
      ) ; end test

      (test #t values (regexp-match?
                       #rx"^#pvector"
                       (let ([out (open-output-string
                                  ) ; end open-output-string
                             ] ; end out
                            ) ; end let args
                         (write-pvector-literal (pvector 'a 'b
                                                ) ; end pvector
                                                out
                         ) ; end write-pvector-literal
                         (get-output-string out
                         ) ; end get-output-string
                       ) ; end let
                      ) ; end regexp-match?
      ) ; end test

      (test "#pvector((a b) #f)"
            values
            (let ([out (open-output-string
                       ) ; end open-output-string
                  ] ; end out
                 ) ; end let args
              (write-pvector-literal (pvector 'a 'b
                                     ) ; end pvector
                                     out
                                     #:mode 'expanded
              ) ; end write-pvector-literal
              (get-output-string out
              ) ; end get-output-string
            ) ; end let
      ) ; end test

      (test '(a b)
            pvector->list
            (read (open-input-string "#pvector((a b) #f)"
                  ) ; end open-input-string
            ) ; end read
      ) ; end test

      (test (range 12
            ) ; end range
            pvector->list
            (read (open-input-string
                   (let ([out (open-output-string
                              ) ; end open-output-string
                         ] ; end out
                        ) ; end let args
                     (write-pvector-literal many out
                     ) ; end write-pvector-literal
                     (get-output-string out
                     ) ; end get-output-string
                   ) ; end let
                  ) ; end open-input-string
            ) ; end read
      ) ; end test

      (define (read-pvector-error-message s
                                          ) ; end read-pvector-error-message args
        (with-handlers ([exn:fail:read? exn-message
                        ] ; end exn:fail:read?
                       ) ; end with-handlers handlers
          (read (open-input-string s
                ) ; end open-input-string
          ) ; end read
          #f
        ) ; end with-handlers
      ) ; end define
      (test #t values
            (regexp-match?
             #rx"expected `e` to continue `#pvector` after `#pv`"
             (read-pvector-error-message "#pv"
             ) ; end read-pvector-error-message
            ) ; end regexp-match?
      ) ; end test
      (test #t values
            (regexp-match?
             #rx"expanded element list is not a proper list: 1$"
             (read-pvector-error-message "#pvector(1 #f)"
             ) ; end read-pvector-error-message
            ) ; end regexp-match?
      ) ; end test
      (test #t values
            (regexp-match?
             #rx"obsolete definition variant: One/val; use Single/val"
             (read-pvector-error-message
              "#pvector(1 ([0 (One/val 1)] [1 (One/val 2)]))"
             ) ; end read-pvector-error-message
            ) ; end regexp-match?
      ) ; end test
    ) ; end let
    (let ()
      (test '((a b) #f) pvector->literal-datum (pvector 'a 'b
                                               ) ; end pvector
      ) ; end test
    ) ; end let
) ; end if

(err/rt-test (pvector->literal-datum '(not a pvector
                                      ) ; end quote
              ) ; end pvector->literal-datum
             exn:fail:contract?
) ; end err/rt-test

(err/rt-test (pvector->literal-datum (pvector
                                     ) ; end pvector
                                      'not-a-pool
              ) ; end pvector->literal-datum
             exn:fail:contract?
) ; end err/rt-test

(err/rt-test (pvector->literal-datum (pvector
                                     ) ; end pvector
                                      #:mode 'not-a-mode
              ) ; end pvector->literal-datum
             exn:fail:contract?
) ; end err/rt-test
