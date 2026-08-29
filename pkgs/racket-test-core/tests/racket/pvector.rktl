
(load-relative "loadtest.rktl"
) ; end load-relative

(Section 'pvector
) ; end Section

(require racket/list
         racket/match
         racket/pretty
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

(define (leaf-node2-def? def
                         ) ; end leaf-node2-def? args
  (match (def-val def
         ) ; end def-val
    [`(Node/val 2 ,_ ,_) #t
    ]
    [_ #f
    ]
  ) ; end match
) ; end define

(define (defs-ref defs id
                  ) ; end defs-ref args
  (for/or ([def (in-list defs
                   ) ; end in-list
            ] ; end def
           ) ; end for/or clauses
    (and (equal? (def-id def
                 ) ; end def-id
                 id
         ) ; end equal?
         (def-val def
         ) ; end def-val
    ) ; end and
  ) ; end for/or
) ; end define

(define (single-internal-node-def? defs def
                                   ) ; end single-internal-node-def? args
  (match (def-val def
         ) ; end def-val
    [`(Single ,node-id)
     (match (defs-ref defs node-id
            ) ; end defs-ref
       [`(Node ,_ ,_ ...) #t
       ]
       [_ #f
       ]
     ) ; end match
    ]
    [_ #f
    ]
  ) ; end match
) ; end define

(define (bulk-shape-summary n
                            ) ; end bulk-shape-summary args
  (define stats (raw:pvector-shape-stats (list->pvector (range n
                                                        ) ; end range
                                         ) ; end list->pvector
                ) ; end raw:pvector-shape-stats
  ) ; end define
  (list n
        (hash-ref stats 'prefix-length
        ) ; end hash-ref
        (hash-ref stats 'suffix-length
        ) ; end hash-ref
        (hash-ref stats 'middle-measure
        ) ; end hash-ref
  ) ; end list
) ; end define

(define (literal-tree-shape-ok? n
                                ) ; end literal-tree-shape-ok? args
  (define datum (pvector->literal-datum (list->pvector (range n
                                                       ) ; end range
                                        ) ; end list->pvector
                ) ; end pvector->literal-datum
  ) ; end define
  (define defs (literal-defs datum
               ) ; end literal-defs
  ) ; end define
  (and (equal? (range n
               ) ; end range
               (literal-datum->list datum
               ) ; end literal-datum->list
       ) ; end equal?
       (dense-ascending-defs? defs
       ) ; end dense-ascending-defs?
       (forward-refs-ok? defs
       ) ; end forward-refs-ok?
       (not (ormap leaf-node2-def? defs
            ) ; end ormap
       ) ; end not
       (not (ormap (lambda (def
                            ) ; end def
                     (single-internal-node-def? defs def
                     ) ; end single-internal-node-def?
                   ) ; end lambda
                   defs
            ) ; end ormap
       ) ; end not
  ) ; end and
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
                              '(Digit/val Node/val Digit Deep Deep/val
                                ) ; end quote
                       ) ; end andmap
      ) ; end test

      (define ten (list->pvector (range 10
                                 ) ; end range
                  ) ; end list->pvector
      ) ; end define
      (define ten-datum (pvector->literal-datum ten
                         ) ; end pvector->literal-datum
      ) ; end define
      (test (range 10
            ) ; end range
            literal-datum->list ten-datum
      ) ; end test
      (test #f
            values
            (ormap leaf-node2-def? (literal-defs ten-datum
                                    ) ; end literal-defs
            ) ; end ormap
      ) ; end test
      (test #f
            values
            (let ([defs (literal-defs ten-datum
                        ) ; end literal-defs
                  ] ; end defs
                 ) ; end let args
              (ormap (lambda (def
                              ) ; end def
                       (single-internal-node-def? defs def
                       ) ; end single-internal-node-def?
                     ) ; end lambda
                     defs
              ) ; end ormap
            ) ; end let
      ) ; end test
      (test '((9 3 3 3)
              (10 2 2 6)
              (11 3 2 6)
              (12 3 3 6)
              (25 2 2 21)
              (26 3 2 21)
              (27 3 3 21)
              (100 2 2 96))
            values
            (map bulk-shape-summary
                 '(9 10 11 12 25 26 27 100
                   ) ; end quote
            ) ; end map
      ) ; end test
      (test #t
            values
            (andmap literal-tree-shape-ok?
                    '(9 10 11 12 25 26 27 100
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
            (read (open-input-string
                   (let ([out (open-output-string
                              ) ; end open-output-string
                         ] ; end out
                        ) ; end let args
                     (write (pvector 'a 'b
                            ) ; end pvector
                            out
                     ) ; end write
                     (get-output-string out
                     ) ; end get-output-string
                   ) ; end let
                  ) ; end open-input-string
            ) ; end read
      ) ; end test

      (test '(a b)
            pvector->list
            (read (open-input-string "#pvector((a b) #f)"
                  ) ; end open-input-string
            ) ; end read
      ) ; end test
      (test #t
            values
            (let ([in (open-input-string "#pvector((1 2 3 4) #f)"
                      ) ; end open-input-string
                 ] ; end in
                 ) ; end let args
              (read in
              ) ; end read
              (eof-object? (read in
                           ) ; end read
              ) ; end eof-object?
            ) ; end let
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

      (test (range 12
            ) ; end range
            pvector->list
            (read (open-input-string
                   (let ([out (open-output-string
                              ) ; end open-output-string
                         ] ; end out
                        ) ; end let args
                     (pretty-write many out
                     ) ; end pretty-write
                     (get-output-string out
                     ) ; end get-output-string
                   ) ; end let
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
                                            #:pretty? #t
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
      (define (read-after-pvector-error s
                                        ) ; end read-after-pvector-error args
        (let ([in (open-input-string s
                  ) ; end open-input-string
             ] ; end in
             ) ; end let args
          (with-handlers ([exn:fail:read? (lambda (e)
                                            (read in
                                            ) ; end read
                                          ) ; end lambda
                         ] ; end exn:fail:read?
                        ) ; end with-handlers handlers
            (read in
            ) ; end read
            'not-an-error
          ) ; end with-handlers
        ) ; end let
      ) ; end define
      (test 42
            values
            (read-after-pvector-error "#pv\"\"\n42"
            ) ; end read-after-pvector-error
      ) ; end test
      (test #t values
            (regexp-match?
             #rx"`#pvector` forms not enabled"
             (parameterize ([read-accept-pvector #f
                            ] ; end read-accept-pvector
                           ) ; end parameterize args
               (read-pvector-error-message "#pvector((1) #f)"
               ) ; end read-pvector-error-message
             ) ; end parameterize
            ) ; end regexp-match?
      ) ; end test
      (test #t values
            (regexp-match?
             #rx"`#pvector` forms not enabled"
             (parameterize ([read-accept-pvector #f
                            ] ; end read-accept-pvector
                           ) ; end parameterize args
               (read-pvector-error-message
                "#pvector(0 ((0 (Single/val 1))))"
               ) ; end read-pvector-error-message
             ) ; end parameterize
            ) ; end regexp-match?
      ) ; end test
      (test 42
            values
            (parameterize ([read-accept-pvector #f
                           ] ; end read-accept-pvector
                          ) ; end parameterize args
              (read-after-pvector-error
               "#pvector((1) #f) \"leftover attack payload\"\n42"
              ) ; end read-after-pvector-error
            ) ; end parameterize
      ) ; end test
      (test '(1)
            pvector->list
            (parameterize ([read-accept-pvector-raw #f
                           ] ; end read-accept-pvector-raw
                          ) ; end parameterize args
              (read (open-input-string "#pvector((1) #f)"
                    ) ; end open-input-string
              ) ; end read
            ) ; end parameterize
      ) ; end test
      (test #t values
            (regexp-match?
             #rx"`#pvector` raw literals not enabled"
             (parameterize ([read-accept-pvector-raw #f
                            ] ; end read-accept-pvector-raw
                           ) ; end parameterize args
               (read-pvector-error-message
                "#pvector(0 ((0 (Single/val 1))))"
               ) ; end read-pvector-error-message
             ) ; end parameterize
            ) ; end regexp-match?
      ) ; end test
      (test #t values
            (regexp-match?
             #rx"`#pvector` raw literals not enabled"
             (parameterize ([read-accept-pvector-raw #f
                            ] ; end read-accept-pvector-raw
                           ) ; end parameterize args
               (read-pvector-error-message
                "#pvector(0 ((0 (BadVariant 1))))"
               ) ; end read-pvector-error-message
             ) ; end parameterize
            ) ; end regexp-match?
      ) ; end test
      (test #t values
            (regexp-match?
             #rx"expanded element list is not a proper list: 1$"
             (parameterize ([read-accept-pvector-raw #f
                            ] ; end read-accept-pvector-raw
                           ) ; end parameterize args
               (read-pvector-error-message "#pvector(1 #f)"
               ) ; end read-pvector-error-message
             ) ; end parameterize
            ) ; end regexp-match?
      ) ; end test
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
      (test #t values
            (regexp-match?
             #rx"definition id must be dense and ascending: expected 0, got 2"
             (read-pvector-error-message
              "#pvector(2 ((2 (Deep/val 2 0 1 Empty)) (1 (Digit/val 1 b)) (0 (Digit/val 1 a))))"
             ) ; end read-pvector-error-message
            ) ; end regexp-match?
      ) ; end test
      (test '(a b)
            pvector->list
            (read (open-input-string
                   "#pvector(2 (#:allow-forward-refs ((2 (Deep/val 2 0 1 Empty)) (1 (Digit/val 1 b)) (0 (Digit/val 1 a)))))"
                  ) ; end open-input-string
            ) ; end read
      ) ; end test
      (test #t values
            (regexp-match?
             #rx"`#pvector` raw literals not enabled"
             (parameterize ([read-accept-pvector-raw #f
                            ] ; end read-accept-pvector-raw
                           ) ; end parameterize args
               (read-pvector-error-message
                "#pvector(2 (#:allow-forward-refs ((2 (Deep/val 2 0 1 Empty)) (1 (Digit/val 1 b)) (0 (Digit/val 1 a)))))"
               ) ; end read-pvector-error-message
             ) ; end parameterize
            ) ; end regexp-match?
      ) ; end test
      (test #t values
            (regexp-match?
             #rx"definition id must be dense and ascending: expected 0, got 1"
             (read-pvector-error-message
              "#pvector(0 ((1 (Single/val 1))))"
             ) ; end read-pvector-error-message
            ) ; end regexp-match?
      ) ; end test
      (test #t values
            (regexp-match?
             #rx"invalid reference id: 0"
             (read-pvector-error-message
              "#pvector(0 ((0 (Single 0))))"
             ) ; end read-pvector-error-message
            ) ; end regexp-match?
      ) ; end test
      (test #t values
            (regexp-match?
             #rx"cyclic reference id: 0"
             (read-pvector-error-message
              "#pvector(0 (#:allow-forward-refs ((0 (Single 0)))))"
             ) ; end read-pvector-error-message
            ) ; end regexp-match?
      ) ; end test
      (test #t values
            (regexp-match?
             #rx"cyclic reference id: 0"
             (read-pvector-error-message
              "#pvector(0 (#:allow-forward-refs ((0 (Single 1)) (1 (Single 0)))))"
             ) ; end read-pvector-error-message
            ) ; end regexp-match?
      ) ; end test
      (test #t values
            (regexp-match?
             #rx"duplicate definition id: 0"
             (read-pvector-error-message
              "#pvector(0 (#:allow-forward-refs ((0 (Single/val a)) (0 (Single/val b)))))"
             ) ; end read-pvector-error-message
            ) ; end regexp-match?
      ) ; end test
      (test #t values
            (regexp-match?
             #rx"definition-value is not a proper list: #f"
             (read-pvector-error-message
              "#pvector(0 (#:allow-forward-refs ((0 #f))))"
             ) ; end read-pvector-error-message
            ) ; end regexp-match?
      ) ; end test
      (test #t values
            (regexp-match?
             #rx"forward-reference option expects one definition list"
             (read-pvector-error-message
              "#pvector(0 (#:allow-forward-refs))"
             ) ; end read-pvector-error-message
            ) ; end regexp-match?
      ) ; end test
      (test #t values
            (regexp-match?
             #rx"Digit/val size mismatch: expected 1, got 999"
             (read-pvector-error-message
              "#pvector(0 ((0 (Digit/val 999 a))))"
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

;; ---------- pvector-apply ----------

(arity-test pvector-apply 2 -1
) ; end arity-test

;; the pvector's elements become the trailing arguments
(test '() pvector-apply list (pvector
                             ) ; end pvector
) ; end test
(test '(1) pvector-apply list (pvector 1
                              ) ; end pvector
) ; end test
(test '(1 2) pvector-apply list (pvector 1 2
                                ) ; end pvector
) ; end test
(test '(1 2 3) pvector-apply list (pvector 1 2 3
                                  ) ; end pvector
) ; end test
(test '(1 2 3 4 5) pvector-apply list (pvector 1 2 3 4 5
                                      ) ; end pvector
) ; end test
(test 36 pvector-apply + (pvector 1 2 3 4 5 6 7 8
                          ) ; end pvector
) ; end test

;; leading arguments precede the elements
(test '(a) pvector-apply list 'a (pvector
                                 ) ; end pvector
) ; end test
(test '(a b 1 2) pvector-apply list 'a 'b (pvector 1 2
                                          ) ; end pvector
) ; end test
(test '(a b c d e f 1 2) pvector-apply list 'a 'b 'c 'd 'e 'f (pvector 1 2
                                                              ) ; end pvector
) ; end test

;; rest-argument and fixed-arity receivers
(test '(a b (1 2)) pvector-apply (lambda (x y . r) (list x y r
                                                   ) ; end list
                                 ) ; end lambda
                                 'a 'b (pvector 1 2
                                       ) ; end pvector
) ; end test
(test '(1 2 3) pvector-apply (lambda (x y z) (list x y z
                                             ) ; end list
                             ) ; end lambda
                             (pvector 1 2 3
                             ) ; end pvector
) ; end test

;; the same elements under different construction histories
(test '(0 1 2 3 4 5 6 7) pvector-apply list (list->pvector (build-list 8 values
                                                           ) ; end build-list
                                            ) ; end list->pvector
) ; end test
(test '(0 1 2 3 4 5 6 7) pvector-apply list (vector->pvector (build-vector 8 values
                                                             ) ; end build-vector
                                            ) ; end vector->pvector
) ; end test
(test '(0 1 2 3 4 5 6 7) pvector-apply list (pvector-append (pvector 0 1 2 3
                                                            ) ; end pvector
                                                            (pvector 4 5 6 7
                                                            ) ; end pvector
                                            ) ; end pvector-append
) ; end test
(test '(0 1 2 3 4 5 6 7)
      pvector-apply
      list
      (let loop ([pv (list->pvector (append (build-list 8 values
                                            ) ; end build-list
                                            (build-list 40 (lambda (i) 'junk
                                                           ) ; end lambda
                                            ) ; end build-list
                                    ) ; end append
                 ) ; end list->pvector
                 ] ; end pv
                 [k 40
                 ] ; end k
                ) ; end loop bindings
        (if (zero? k
            ) ; end zero?
            pv
            (let-values ([(v rest) (pvector-pop-right pv
                                   ) ; end pvector-pop-right
                         ] ; end binding
                        ) ; end let-values bindings
              (loop rest (sub1 k
                         ) ; end sub1
              ) ; end loop
            ) ; end let-values
        ) ; end if
      ) ; end let loop
) ; end test

;; sizes past the argument-register count and into the frame
(test 40 pvector-apply + (make-pvector 40 1
                         ) ; end make-pvector
) ; end test
(test 1000 pvector-apply + (make-pvector 1000 1
                           ) ; end make-pvector
) ; end test
(test 100000 pvector-apply + (make-pvector 100000 1
                             ) ; end make-pvector
) ; end test

;; type errors: the last argument must be a pvector, the first a procedure
(err/rt-test (pvector-apply 5 (pvector 1
                              ) ; end pvector
              ) ; end pvector-apply
             exn:fail:contract?
) ; end err/rt-test
(err/rt-test (pvector-apply + (vector 1 2
                              ) ; end vector
              ) ; end pvector-apply
             exn:fail:contract?
) ; end err/rt-test
(err/rt-test (pvector-apply + '(1 2
                              ) ; end quote
              ) ; end pvector-apply
             exn:fail:contract?
) ; end err/rt-test
(err/rt-test (pvector-apply + 1 2
              ) ; end pvector-apply
             exn:fail:contract?
) ; end err/rt-test

;; `apply` itself still rejects pvectors
(err/rt-test (apply + (pvector 1 2
                      ) ; end pvector
              ) ; end apply
             exn:fail:contract?
) ; end err/rt-test

;; ---------- pvector constructor in value position ----------
;; The constructor is a hand-coded entry, so `apply` and
;; `call-with-values` reach it natively for every argument count.

(test '() pvector->list (apply pvector '(
                                        ) ; end quote
                        ) ; end apply
) ; end test
(test '(1 2 3 4 5) pvector->list (apply pvector '(1 2 3 4 5
                                                 ) ; end quote
                                 ) ; end apply
) ; end test
(test 200 pvector-length (apply pvector (build-list 200 values
                                        ) ; end build-list
                         ) ; end apply
) ; end test
(test 100000 pvector-apply + (apply pvector (build-list 100000 (lambda (i) 1
                                                               ) ; end lambda
                                            ) ; end build-list
                             ) ; end apply
) ; end test
(test '(1 2 3 4 5 6) pvector->list (call-with-values (lambda () (values 1 2 3 4 5 6
                                                                ) ; end values
                                                     ) ; end lambda
                                                     pvector
                                   ) ; end call-with-values
) ; end test
(test '(1 1 1) map pvector-length (map pvector '(1 2 3
                                                ) ; end quote
                                  ) ; end map
) ; end test
(test #t procedure? pvector
) ; end test
(test 'pvector object-name pvector
) ; end test
;; the same value regardless of how the constructor was reached
(test #t equal? (pvector 1 2 3 4 5 6 7 8 9) (apply pvector '(1 2 3 4 5 6 7 8 9
                                                            ) ; end quote
                                            ) ; end apply
) ; end test
