
(load-relative "loadtest.rktl"
) ; end load-relative

(Section 'intmap
) ; end Section

(test "#intmap((1 . a) (2 . b))"
      values
      (let ([out (open-output-string)])
        (write (read (open-input-string "#intmap((1 . a) (2 . b))")) out)
        (get-output-string out)))
(test "#intmap((1 . a) (2 . b))"
      values
      (let ([out (open-output-string)])
        (print (read (open-input-string "#intmap((1 . a) (2 . b))")) out)
        (get-output-string out)))

(require racket/intmap
         (prefix-in raw: racket/private/intmap-runtime-adapter
         ) ; end prefix-in
) ; end require

(define big (arithmetic-shift 1 80
            ) ; end arithmetic-shift
) ; end define
(define bigger (+ big 7
               ) ; end +
) ; end define

(test #t intmap? intmap-empty
) ; end test
(test #t intmap-empty? intmap-empty
) ; end test
(test 0 intmap-count intmap-empty
) ; end test
(test #f intmap-has-key? intmap-empty 0
) ; end test
(test 'missing intmap-ref intmap-empty 0 (lambda () 'missing
                                         ) ; end lambda
) ; end test
(err/rt-test (intmap-ref intmap-empty 0) exn:fail:contract?
) ; end err/rt-test
(err/rt-test (intmap-set intmap-empty 1.0 'bad) exn:fail:contract?
) ; end err/rt-test
(err/rt-test (intmap-update intmap-empty 1.0 'bad 'bad) exn:fail:contract?
) ; end err/rt-test
(err/rt-test (intmap-set/absent intmap-empty 1.0 'bad) exn:fail:contract?
) ; end err/rt-test
(err/rt-test (intmap-replace/eq intmap-empty 1.0 'old 'new) exn:fail:contract?
) ; end err/rt-test
(err/rt-test (intmap-remove/equal intmap-empty 1.0 'old) exn:fail:contract?
) ; end err/rt-test

(define m
  (for/fold ([m intmap-empty]) ([k '(5 1 3 2 4
                                    ) ; end 5
                                ] ; end k
                               ) ; end form
    (intmap-set m k (string->symbol (format "v~a" k
                                    ) ; end format
                    ) ; end string->symbol
    ) ; end intmap-set
  ) ; end for/fold
) ; end define

(test 5 intmap-count m
) ; end test
(test #f intmap-empty? m
) ; end test
(test 'v3 intmap-ref m 3
) ; end test
(test #t intmap-has-key? m 4
) ; end test
(test #f intmap-has-key? m 99
) ; end test
(test '((1 . v1) (2 . v2) (3 . v3) (4 . v4) (5 . v5
                                            ) ; end 5
       ) ; end form
      intmap-range->list m #f #f
) ; end test
(test '((2 . v2) (3 . v3) (4 . v4
                          ) ; end 4
       ) ; end form
      intmap-range->list m 2 5
) ; end test
(test '((3 . v3) (4 . v4
                 ) ; end 4
       ) ; end form
      intmap-range->list m 2 5 #f #f
) ; end test
(test '((2 . v2) (3 . v3) (4 . v4) (5 . v5
                                   ) ; end 5
       ) ; end form
      intmap-range->list m 2 5 #t #t
) ; end test

(test '(1 . v1) intmap-min-entry m
) ; end test
(test '(5 . v5) intmap-max-entry m
) ; end test
(test '(3 . v3) intmap-entry< m 4
) ; end test
(test '(4 . v4) intmap-entry<= m 4
) ; end test
(test '(5 . v5) intmap-entry> m 4
) ; end test
(test '(4 . v4) intmap-entry>= m 4
) ; end test
(test #f intmap-entry< m 1
) ; end test
(test #f intmap-entry> m 5
) ; end test

(test '((1 . v1) (2 . v2) (3 . v3) (4 . v4) (5 . v5
                                            ) ; end 5
       ) ; end form
      values
      (for/list ([(k v) (in-intmap m)]) (cons k v
                                        ) ; end cons
      ) ; end for/list
) ; end test
(test '((1 . v1) (2 . v2) (3 . v3) (4 . v4) (5 . v5
                                            ) ; end 5
       ) ; end form
      values
      (for/list ([(k v) m]) (cons k v
                            ) ; end cons
      ) ; end for/list
) ; end test
(test '(1 2 3 4 5) values (for/list ([k (in-intmap-keys m)]) k
                          ) ; end for/list
) ; end test
(test '(v1 v2 v3 v4 v5) values (for/list ([v (in-intmap-values m)]) v
                               ) ; end for/list
) ; end test
(test '((1 . v1) (2 . v2) (3 . v3) (4 . v4) (5 . v5
                                            ) ; end 5
       ) ; end form
      values
      (for/list ([p (in-intmap-pairs m)]) p
      ) ; end for/list
) ; end test
(test '((2 . v2) (3 . v3) (4 . v4
                          ) ; end 4
       ) ; end form
      values
      (for/list ([(k v) (in-intmap-range m 2 5)]) (cons k v
                                                  ) ; end cons
      ) ; end for/list
) ; end test
(test '(2 3 4) values (for/list ([k (in-intmap-range-keys m 2 5)]) k
                      ) ; end for/list
) ; end test
(test '(v2 v3 v4) values (for/list ([v (in-intmap-range-values m 2 5)]) v
                         ) ; end for/list
) ; end test
(test '((2 . v2) (3 . v3) (4 . v4
                          ) ; end 4
       ) ; end form
      values
      (for/list ([p (in-intmap-range-pairs m 2 5)]) p
      ) ; end for/list
) ; end test
(test '((5 . v5) (4 . v4) (3 . v3) (2 . v2) (1 . v1
                                            ) ; end 1
       ) ; end form
      values
      (for/list ([(k v) (in-intmap m #:reverse? #t)]) (cons k v
                                                         ) ; end cons
      ) ; end for/list
) ; end test
(test '(5 4 3 2 1) values (for/list ([k (in-intmap-keys m #:reverse? #t)]) k
                          ) ; end for/list
) ; end test
(test '(v5 v4 v3 v2 v1) values (for/list ([v (in-intmap-values m #:reverse? #t)]) v
                               ) ; end for/list
) ; end test
(test '((5 . v5) (4 . v4) (3 . v3) (2 . v2) (1 . v1
                                            ) ; end 1
       ) ; end form
      values
      (for/list ([p (in-intmap-pairs m #:reverse? #t)]) p
      ) ; end for/list
) ; end test
(test '((4 . v4) (3 . v3) (2 . v2
                          ) ; end 2
       ) ; end form
      values
      (for/list ([(k v) (in-intmap-range m 2 5 #:reverse? #t)]) (cons k v
                                                                  ) ; end cons
      ) ; end for/list
) ; end test
(test '(4 3 2) values (for/list ([k (in-intmap-range-keys m 2 5 #:reverse? #t)]) k
                      ) ; end for/list
) ; end test
(test '(v4 v3 v2) values (for/list ([v (in-intmap-range-values m 2 5 #:reverse? #t)]) v
                         ) ; end for/list
) ; end test
(test '((4 . v4) (3 . v3) (2 . v2
                          ) ; end 2
       ) ; end form
      values
      (for/list ([p (in-intmap-range-pairs m 2 5 #:reverse? #t)]) p
      ) ; end for/list
) ; end test

(define m1 (intmap-set intmap-empty 1 'old
           ) ; end intmap-set
) ; end define
(define m2 (intmap-set m1 1 'new
           ) ; end intmap-set
) ; end define
(define m3 (intmap-remove m2 1
           ) ; end intmap-remove
) ; end define
(test 'old intmap-ref m1 1
) ; end test
(test 'new intmap-ref m2 1
) ; end test
(test #f intmap-has-key? m3 1
) ; end test
(test 1 intmap-count m1
) ; end test
(test 1 intmap-count m2
) ; end test
(test 0 intmap-count m3
) ; end test

(define update-base
  (intmap 1 (list 'old
            ) ; end list
          2 'two
  ) ; end intmap
) ; end define
(define update-same-shape (list 'old
                          ) ; end list
) ; end define
(define update-present
  (intmap-update update-base
                 2
                 'absent
                 (lambda (v) (list v 'seen
                             ) ; end list
                 ) ; end lambda
  ) ; end intmap-update
) ; end define
(define update-absent
  (intmap-update update-present 3 (lambda () 'three
                                  ) ; end lambda
                 'present
  ) ; end intmap-update
) ; end define
(define update-constant
  (intmap-update update-absent 2 'absent 'dos
  ) ; end intmap-update
) ; end define
(test '(two seen) intmap-ref update-present 2
) ; end test
(test 'three intmap-ref update-absent 3
) ; end test
(test 'dos intmap-ref update-constant 2
) ; end test
(test 'two intmap-ref update-base 2
) ; end test

(define-values (set-absent-map set-absent?)
  (intmap-set/absent update-base 3 'three
  ) ; end intmap-set/absent
) ; end define-values
(define-values (set-present-map set-present?)
  (intmap-set/absent update-base 2 'TWO
  ) ; end intmap-set/absent
) ; end define-values
(test #t values set-absent?
) ; end test
(test #f values set-present?
) ; end test
(test 'three intmap-ref set-absent-map 3
) ; end test
(test #t eq? set-present-map update-base
) ; end test

(define-values (replace-map replace?)
  (intmap-replace update-base 2 'TWO
  ) ; end intmap-replace
) ; end define-values
(define-values (replace-missing-map replace-missing?)
  (intmap-replace update-base 9 'nine
  ) ; end intmap-replace
) ; end define-values
(test #t values replace?
) ; end test
(test #f values replace-missing?
) ; end test
(test 'TWO intmap-ref replace-map 2
) ; end test
(test #t eq? replace-missing-map update-base
) ; end test

(define-values (replace-eq-fail replace-eq-fail?)
  (intmap-replace/eq update-base 1 update-same-shape 'new
  ) ; end intmap-replace/eq
) ; end define-values
(define-values (replace-eq-ok replace-eq-ok?)
  (intmap-replace/eq update-base 1 (intmap-ref update-base 1) 'new
  ) ; end intmap-replace/eq
) ; end define-values
(define-values (replace-equal-ok replace-equal-ok?)
  (intmap-replace/equal update-base 1 update-same-shape 'new
  ) ; end intmap-replace/equal
) ; end define-values
(test #f values replace-eq-fail?
) ; end test
(test #t eq? replace-eq-fail update-base
) ; end test
(test #t values replace-eq-ok?
) ; end test
(test #t values replace-equal-ok?
) ; end test
(test 'new intmap-ref replace-eq-ok 1
) ; end test
(test 'new intmap-ref replace-equal-ok 1
) ; end test

(define-values (remove-eq-fail remove-eq-fail?)
  (intmap-remove/eq update-base 1 update-same-shape
  ) ; end intmap-remove/eq
) ; end define-values
(define-values (remove-equal-ok remove-equal-ok?)
  (intmap-remove/equal update-base 1 update-same-shape
  ) ; end intmap-remove/equal
) ; end define-values
(test #f values remove-eq-fail?
) ; end test
(test #t eq? remove-eq-fail update-base
) ; end test
(test #t values remove-equal-ok?
) ; end test
(test #f intmap-has-key? remove-equal-ok 1
) ; end test

(define mixed
  (intmap-set
   (intmap-set
    (intmap-set
     (intmap-set intmap-empty -1 'negative
     ) ; end intmap-set
     0 'zero
    ) ; end intmap-set
    big 'big
   ) ; end intmap-set
   bigger 'bigger
  ) ; end intmap-set
) ; end define
(test '((1 . one) (2 . two) (3 . three
                            ) ; end 3
       ) ; end form
      intmap-range->list
      (sorted-list->intmap '((1 . one) (2 . two) (3 . three
                                                 ) ; end 3
                            ) ; end form
      ) ; end sorted-list->intmap
      #f
      #f
) ; end test
(test '((-1 . negative) (0 . zero)) intmap-range->list mixed -2 big
) ; end test
(test `(,big . big) intmap-entry>= mixed 1
) ; end test
(test `(,big . big) intmap-entry< mixed bigger
) ; end test
(test `(,bigger . bigger) intmap-entry> mixed big
) ; end test
(define mixed-updated
  (intmap-update mixed big 'missing (lambda (v) (list v 'seen
                                                ) ; end list
                                     ) ; end lambda
  ) ; end intmap-update
) ; end define
(test '(big seen) intmap-ref mixed-updated big
) ; end test
(test 'big intmap-ref mixed big
) ; end test
(define-values (mixed-big-removed mixed-big-removed?
                ) ; end mixed-big-removed
  (intmap-remove/eq mixed big 'big
  ) ; end intmap-remove/eq
) ; end define-values
(define-values (mixed-bigger-fail mixed-bigger-fail?
                ) ; end mixed-bigger-fail
  (intmap-remove/equal mixed bigger 'nope
  ) ; end intmap-remove/equal
) ; end define-values
(test #t values mixed-big-removed?
) ; end test
(test #f intmap-has-key? mixed-big-removed big
) ; end test
(test #f values mixed-bigger-fail?
) ; end test
(test #t eq? mixed-bigger-fail mixed
) ; end test

(define sorted-vec (vector (cons -4 'a) (cons 10 'b) (cons big 'c
                                                     ) ; end cons
                   ) ; end vector
) ; end define
(test `((-4 . a) (10 . b) (,big . c
                          ) ; end big
       ) ; end form
      values
      (intmap-range->list (sorted-vector->intmap sorted-vec) #f #f
      ) ; end intmap-range->list
) ; end test
(err/rt-test (sorted-vector->intmap (vector (cons 1 'a) (cons 1 'b
                                                        ) ; end cons
                                    ) ; end vector
             ) ; end sorted-vector->intmap
             exn:fail:contract?
) ; end err/rt-test
(err/rt-test (sorted-vector->intmap (vector (cons 2 'a) (cons 1 'b
                                                        ) ; end cons
                                    ) ; end vector
             ) ; end sorted-vector->intmap
             exn:fail:contract?
) ; end err/rt-test

(test '((1 . v1) (2 . v2) (3 . v3) (4 . v4) (5 . v5
                                            ) ; end 5
       ) ; end form
      intmap->literal-datum
      m
) ; end test
(test '((1 . a) (2 . b)
       ) ; end form
      intmap-range->list
      (literal-datum->intmap '((1 . a) (2 . b
                                      ) ; end 2
                             ) ; end form
      ) ; end literal-datum->intmap
      #f
      #f
) ; end test
(test "#intmap((1 . a) (2 . b))"
      values
      (let ([out (open-output-string
                 ) ; end open-output-string
            ] ; end out
           ) ; end let args
        (write-intmap-literal (intmap 2 'b 1 'a
                              ) ; end intmap
                              out
        ) ; end write-intmap-literal
        (get-output-string out
        ) ; end get-output-string
      ) ; end let
) ; end test
(test '((1 . a) (2 . b)
       ) ; end form
      intmap-range->list
      (read (open-input-string "#intmap((1 . a) (2 . b))"
            ) ; end open-input-string
      ) ; end read
      #f
      #f
) ; end test
(test '()
      intmap-range->list
      (read (open-input-string "#intmap()"
            ) ; end open-input-string
      ) ; end read
      #f
      #f
) ; end test
(test '((1 . a) (2 . b)
       ) ; end form
      intmap-range->list
      (read (open-input-string
             (let ([out (open-output-string
                        ) ; end open-output-string
                   ] ; end out
                  ) ; end let args
               (write (intmap 2 'b 1 'a
                      ) ; end intmap
                      out
               ) ; end write
               (get-output-string out
               ) ; end get-output-string
             ) ; end let
            ) ; end open-input-string
      ) ; end read
      #f
      #f
) ; end test
(test '((1 . a) (2 . b)
       ) ; end form
      intmap-range->list
      (read (open-input-string
             (let ([out (open-output-string
                        ) ; end open-output-string
                   ] ; end out
                  ) ; end let args
               (pretty-write (intmap 2 'b 1 'a
                             ) ; end intmap
                             out
               ) ; end pretty-write
               (get-output-string out
               ) ; end get-output-string
             ) ; end let
            ) ; end open-input-string
      ) ; end read
      #f
      #f
) ; end test
(test '((1 . a) (2 . b)
       ) ; end form
      intmap-range->list
      (read (open-input-string
             (let ([out (open-output-string
                        ) ; end open-output-string
                   ] ; end out
                  ) ; end let args
               (write-intmap-literal (intmap 2 'b 1 'a
                                     ) ; end intmap
                                     out
                                     #:pretty? #t
               ) ; end write-intmap-literal
               (get-output-string out
               ) ; end get-output-string
             ) ; end let
            ) ; end open-input-string
      ) ; end read
      #f
      #f
) ; end test

(define (read-intmap-error-message s
                                  ) ; end read-intmap-error-message
  (with-handlers ([exn:fail:read? exn-message
                  ] ; end exn:fail:read?
                 ) ; end with-handlers args
    (read (open-input-string s
          ) ; end open-input-string
    ) ; end read
    #f
  ) ; end with-handlers
) ; end define

(define (read-after-intmap-error s
                                ) ; end read-after-intmap-error
  (let ([in (open-input-string s
            ) ; end open-input-string
       ] ; end in
       ) ; end let args
    (with-handlers ([exn:fail:read? (lambda (e)
                                      (read in
                                      ) ; end read
                                    ) ; end lambda
                   ] ; end exn:fail:read?
                  ) ; end with-handlers args
      (read in
      ) ; end read
      'not-an-error
    ) ; end with-handlers
  ) ; end let
) ; end define

(test #t values
      (regexp-match?
       #rx"`#intmap` forms not enabled"
       (parameterize ([read-accept-intmap #f
                      ] ; end read-accept-intmap
                     ) ; end parameterize args
         (read-intmap-error-message "#intmap((1 . a))"
         ) ; end read-intmap-error-message
       ) ; end parameterize
      ) ; end regexp-match?
) ; end test
(test 42
      values
      (parameterize ([read-accept-intmap #f
                     ] ; end read-accept-intmap
                    ) ; end parameterize args
        (read-after-intmap-error "#intmap((1 . a)) \"payload\"\n42"
        ) ; end read-after-intmap-error
      ) ; end parameterize
) ; end test
(test #t values
      (regexp-match?
       #rx"expected `t` to continue `#intmap` after `#in`"
       (read-intmap-error-message "#in"
       ) ; end read-intmap-error-message
      ) ; end regexp-match?
) ; end test
(test 42 values
      (read-after-intmap-error "#in\"\"\n42"
      ) ; end read-after-intmap-error
) ; end test
(test #t values
      (regexp-match?
       #rx"entry-list is not a proper list"
       (read-intmap-error-message "#intmap(1 . 2)"
       ) ; end read-intmap-error-message
      ) ; end regexp-match?
) ; end test
(test #t values
      (regexp-match?
       #rx"exact-integer\\?"
       (read-intmap-error-message "#intmap((a . b))"
       ) ; end read-intmap-error-message
      ) ; end regexp-match?
) ; end test
(test #t values
      (regexp-match?
       #rx"expected strictly increasing integer keys"
       (read-intmap-error-message "#intmap((1 . a) (1 . b))"
       ) ; end read-intmap-error-message
      ) ; end regexp-match?
) ; end test
(test #t values
      (regexp-match?
       #rx"expected strictly increasing integer keys"
       (read-intmap-error-message "#intmap((2 . b) (1 . a))"
       ) ; end read-intmap-error-message
      ) ; end regexp-match?
) ; end test
(test '((1 . a) (2 . b)
       ) ; end form
      intmap-range->list
      (parameterize ([read-accept-intmap-unordered #t
                     ] ; end read-accept-intmap-unordered
                    ) ; end parameterize args
        (read (open-input-string "#intmap((2 . b) (1 . a))"
              ) ; end open-input-string
        ) ; end read
      ) ; end parameterize
      #f
      #f
) ; end test
(test #t values
      (regexp-match?
       #rx"duplicate key"
       (parameterize ([read-accept-intmap-unordered #t
                      ] ; end read-accept-intmap-unordered
                     ) ; end parameterize args
         (read-intmap-error-message "#intmap((1 . a) (2 . b) (1 . c))"
         ) ; end read-intmap-error-message
       ) ; end parameterize
      ) ; end regexp-match?
) ; end test
(test '((1 . c) (2 . b)
       ) ; end form
      intmap-range->list
      (parameterize ([read-accept-intmap-duplicate-keys #t
                     ] ; end read-accept-intmap-duplicate-keys
                    ) ; end parameterize args
        (read (open-input-string "#intmap((1 . a) (1 . c) (2 . b))"
              ) ; end open-input-string
        ) ; end read
      ) ; end parameterize
      #f
      #f
) ; end test
(test #t values
      (regexp-match?
       #rx"expected strictly increasing integer keys"
       (parameterize ([read-accept-intmap-duplicate-keys #t
                      ] ; end read-accept-intmap-duplicate-keys
                     ) ; end parameterize args
         (read-intmap-error-message "#intmap((2 . b) (1 . a))"
         ) ; end read-intmap-error-message
       ) ; end parameterize
      ) ; end regexp-match?
) ; end test
(test '((1 . c) (2 . b)
       ) ; end form
      intmap-range->list
      (parameterize ([read-accept-intmap-unordered #t
                     ] ; end read-accept-intmap-unordered
                     [read-accept-intmap-duplicate-keys #t
                     ] ; end read-accept-intmap-duplicate-keys
                    ) ; end parameterize args
        (read (open-input-string "#intmap((1 . a) (2 . b) (1 . c))"
              ) ; end open-input-string
        ) ; end read
      ) ; end parameterize
      #f
      #f
) ; end test
(define unordered-many-literal
  (string-append
   "#intmap("
   (apply string-append
          (for/list ([i (in-range 199 -1 -1
                                  ) ; end in-range
                        ] ; end i
                    ) ; end for/list args
            (format "(~a . ~a)" i i
            ) ; end format
          ) ; end for/list
   ) ; end apply
   ")"
  ) ; end string-append
) ; end define
(define unordered-many-literal-map
  (parameterize ([read-accept-intmap-unordered #t
                 ] ; end read-accept-intmap-unordered
                ) ; end parameterize args
    (read (open-input-string unordered-many-literal
          ) ; end open-input-string
    ) ; end read
  ) ; end parameterize
) ; end define
(test 200 intmap-count unordered-many-literal-map
) ; end test
(test #t values
      (<= (hash-ref (raw:intmap-shape-stats unordered-many-literal-map
                    ) ; end raw:intmap-shape-stats
                    'height
          ) ; end hash-ref
          10
      ) ; end <=
) ; end test
(err/rt-test (literal-datum->intmap '(1 . 2
                                      ) ; end quote
              ) ; end literal-datum->intmap
             exn:fail:contract?
) ; end err/rt-test
(err/rt-test (write-intmap-literal m (current-output-port
                                      ) ; end current-output-port
                                #:pretty? 'yes
              ) ; end write-intmap-literal
             exn:fail:contract?
) ; end err/rt-test

(define many
  (for/fold ([m intmap-empty]) ([i (in-range 200
                                   ) ; end in-range
                                ] ; end i
                               ) ; end form
    (intmap-set m i i
    ) ; end intmap-set
  ) ; end for/fold
) ; end define
(define many-stats (raw:intmap-shape-stats many
                   ) ; end raw:intmap-shape-stats
) ; end define
(test 200 hash-ref many-stats 'count
) ; end test
(test #t values (<= (hash-ref many-stats 'height) 40
                ) ; end <=
) ; end test
(test (for/list ([i (in-range 50 60)]) (cons i i
                                       ) ; end cons
      ) ; end for/list
      intmap-range->list many 50 60
) ; end test
