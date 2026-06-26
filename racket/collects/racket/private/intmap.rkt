#lang racket/base

(require racket/fixnum
         "serialize-structs.rkt"
         (only-in "for.rkt" prop:sequence prop:stream
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
 intmap-shape-stats
 intmap-install-struct-property!
) ; end provide

(define (intmap-rest-stream m
        ) ; end intmap-rest-stream
  (intmap-remove m (car (intmap-min-entry m
                        ) ; end intmap-min-entry
                   ) ; end car
  ) ; end intmap-remove
) ; end define

(define (intmap-first-stream m
        ) ; end intmap-first-stream
  (intmap-min-entry m
  ) ; end intmap-min-entry
) ; end define

(struct empty-intmap-record (
                            ) ; end form
  #:sealed
  #:authentic
  #:property prop:custom-write
  (lambda (_ out mode
          ) ; end _
    (if mode
        (write-string "(intmap)" out
        ) ; end write-string
        (write-string "#<intmap:0>" out
        ) ; end write-string
    ) ; end if
  ) ; end lambda
  #:property prop:equal+hash
  (list (lambda (a b equal?-recur) (equal?-recur (intmap-range->list a #f #f) (intmap-range->list b #f #f
                                                                              ) ; end intmap-range->list
                                   ) ; end equal?-recur
        ) ; end lambda
        (lambda (a hash-recur) (hash-recur (intmap-range->list a #f #f
                                           ) ; end intmap-range->list
                               ) ; end hash-recur
        ) ; end lambda
        (lambda (a hash2-recur) (hash2-recur (intmap-range->list a #f #f
                                             ) ; end intmap-range->list
                                ) ; end hash2-recur
        ) ; end lambda
  ) ; end list
  #:property prop:sequence
  (lambda (m) (in-intmap m
              ) ; end in-intmap
  ) ; end lambda
  #:property prop:stream
  (vector (lambda (_) #t
          ) ; end lambda
          intmap-first-stream
          intmap-rest-stream
  ) ; end vector
  #:property prop:serializable
  (make-serialize-info
   (lambda (m) (vector (intmap-range->list m #f #f
                       ) ; end intmap-range->list
               ) ; end vector
   ) ; end lambda
   (cons 'deserialize-intmap
         (module-path-index-join '(submod "." deserialize
                                  ) ; end submod
                                 (variable-reference->module-path-index
                                  (#%variable-reference
                                  ) ; end %variable-reference
                                 ) ; end variable-reference->module-path-index
         ) ; end module-path-index-join
   ) ; end cons
   #f
   (or (current-load-relative-directory
       ) ; end current-load-relative-directory
       (current-directory
       ) ; end current-directory
   ) ; end or
  ) ; end make-serialize-info
) ; end struct

(struct intmap-node (size key value left right
                    ) ; end size
  #:sealed
  #:authentic
  #:property prop:custom-write
  (lambda (m out mode
          ) ; end m
    (if mode
        (fprintf out "(sorted-list->intmap '~s)" (intmap-range->list m #f #f
                                                 ) ; end intmap-range->list
        ) ; end fprintf
        (fprintf out "#<intmap:~a>" (intmap-node-size m
                                    ) ; end intmap-node-size
        ) ; end fprintf
    ) ; end if
  ) ; end lambda
  #:property prop:equal+hash
  (list (lambda (a b equal?-recur) (equal?-recur (intmap-range->list a #f #f) (intmap-range->list b #f #f
                                                                              ) ; end intmap-range->list
                                   ) ; end equal?-recur
        ) ; end lambda
        (lambda (a hash-recur) (hash-recur (intmap-range->list a #f #f
                                           ) ; end intmap-range->list
                               ) ; end hash-recur
        ) ; end lambda
        (lambda (a hash2-recur) (hash2-recur (intmap-range->list a #f #f
                                             ) ; end intmap-range->list
                                ) ; end hash2-recur
        ) ; end lambda
  ) ; end list
  #:property prop:sequence
  (lambda (m) (in-intmap m
              ) ; end in-intmap
  ) ; end lambda
  #:property prop:stream
  (vector (lambda (_) #f
          ) ; end lambda
          intmap-first-stream
          intmap-rest-stream
  ) ; end vector
  #:property prop:serializable
  (make-serialize-info
   (lambda (m) (vector (intmap-range->list m #f #f
                       ) ; end intmap-range->list
               ) ; end vector
   ) ; end lambda
   (cons 'deserialize-intmap
         (module-path-index-join '(submod "." deserialize
                                  ) ; end submod
                                 (variable-reference->module-path-index
                                  (#%variable-reference
                                  ) ; end %variable-reference
                                 ) ; end variable-reference->module-path-index
         ) ; end module-path-index-join
   ) ; end cons
   #f
   (or (current-load-relative-directory
       ) ; end current-load-relative-directory
       (current-directory
       ) ; end current-directory
   ) ; end or
  ) ; end make-serialize-info
) ; end struct

(module+ deserialize
  (provide deserialize-intmap
  ) ; end provide
  (define deserialize-intmap
    (make-deserialize-info
     (lambda (entries
             ) ; end entries
       (if (list? entries
           ) ; end list?
           (sorted-list->intmap entries
           ) ; end sorted-list->intmap
           (error 'intmap "invalid deserialization"
           ) ; end error
       ) ; end if
     ) ; end lambda
     (lambda () (error "should not get here; cycles not supported"
                ) ; end error
     ) ; end lambda
    ) ; end make-deserialize-info
  ) ; end define
  (module declare-preserve-for-embedding racket/kernel
  ) ; end module
) ; end module+

(define empty-intmap (empty-intmap-record
                     ) ; end empty-intmap-record
) ; end define
(define missing-default (gensym 'missing
                        ) ; end gensym
) ; end define
(define delta 5
) ; end define
(define ratio 2
) ; end define

(define (intmap? v
        ) ; end intmap?
  (or (empty-intmap-record? v) (intmap-node? v
                               ) ; end intmap-node?
  ) ; end or
) ; end define

(define intmap-empty empty-intmap
) ; end define

(define (intmap-empty? v
        ) ; end intmap-empty?
  (eq? v empty-intmap
  ) ; end eq?
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

(define (key=? a b
        ) ; end key=?
  (if (and (fixnum? a) (fixnum? b
                       ) ; end fixnum?
      ) ; end and
      (fx= a b
      ) ; end fx=
      (= a b
      ) ; end =
  ) ; end if
) ; end define

(define (key<? a b
        ) ; end key<?
  (if (and (fixnum? a) (fixnum? b
                       ) ; end fixnum?
      ) ; end and
      (fx< a b
      ) ; end fx<
      (< a b
      ) ; end <
  ) ; end if
) ; end define

(define (key>? a b
        ) ; end key>?
  (key<? b a
  ) ; end key<?
) ; end define

(define (key<=? a b
        ) ; end key<=?
  (not (key>? a b
       ) ; end key>?
  ) ; end not
) ; end define

(define (key>=? a b
        ) ; end key>=?
  (not (key<? a b
       ) ; end key<?
  ) ; end not
) ; end define

(define (size t
        ) ; end size
  (if (intmap-node? t) (intmap-node-size t) 0
  ) ; end if
) ; end define

(define (make-node k v l r
        ) ; end make-node
  (intmap-node (+ 1 (size l) (size r)) k v l r
  ) ; end intmap-node
) ; end define

(define (single-left k v l r
        ) ; end single-left
  (make-node (intmap-node-key r
             ) ; end intmap-node-key
             (intmap-node-value r
             ) ; end intmap-node-value
             (make-node k v l (intmap-node-left r
                              ) ; end intmap-node-left
             ) ; end make-node
             (intmap-node-right r
             ) ; end intmap-node-right
  ) ; end make-node
) ; end define

(define (double-left k v l r
        ) ; end double-left
  (define rl (intmap-node-left r
             ) ; end intmap-node-left
  ) ; end define
  (make-node (intmap-node-key rl
             ) ; end intmap-node-key
             (intmap-node-value rl
             ) ; end intmap-node-value
             (make-node k v l (intmap-node-left rl
                              ) ; end intmap-node-left
             ) ; end make-node
             (make-node (intmap-node-key r
                        ) ; end intmap-node-key
                        (intmap-node-value r
                        ) ; end intmap-node-value
                        (intmap-node-right rl
                        ) ; end intmap-node-right
                        (intmap-node-right r
                        ) ; end intmap-node-right
             ) ; end make-node
  ) ; end make-node
) ; end define

(define (single-right k v l r
        ) ; end single-right
  (make-node (intmap-node-key l
             ) ; end intmap-node-key
             (intmap-node-value l
             ) ; end intmap-node-value
             (intmap-node-left l
             ) ; end intmap-node-left
             (make-node k v (intmap-node-right l) r
             ) ; end make-node
  ) ; end make-node
) ; end define

(define (double-right k v l r
        ) ; end double-right
  (define lr (intmap-node-right l
             ) ; end intmap-node-right
  ) ; end define
  (make-node (intmap-node-key lr
             ) ; end intmap-node-key
             (intmap-node-value lr
             ) ; end intmap-node-value
             (make-node (intmap-node-key l
                        ) ; end intmap-node-key
                        (intmap-node-value l
                        ) ; end intmap-node-value
                        (intmap-node-left l
                        ) ; end intmap-node-left
                        (intmap-node-left lr
                        ) ; end intmap-node-left
             ) ; end make-node
             (make-node k v (intmap-node-right lr) r
             ) ; end make-node
  ) ; end make-node
) ; end define

(define (balance k v l r
        ) ; end balance
  (define ls (size l
             ) ; end size
  ) ; end define
  (define rs (size r
             ) ; end size
  ) ; end define
  (cond
    [(<= (+ ls rs) 1) (make-node k v l r
                      ) ; end make-node
    ] ; end clause
    [(>= rs (* delta ls
            ) ; end *
     ) ; end >=
     (cond
       [(not (intmap-node? r)) (make-node k v l r
                               ) ; end make-node
       ] ; end clause
       [(or (not (intmap-node? (intmap-node-left r
                               ) ; end intmap-node-left
                 ) ; end intmap-node?
            ) ; end not
            (< (size (intmap-node-left r
                     ) ; end intmap-node-left
               ) ; end size
               (* ratio (size (intmap-node-right r
                              ) ; end intmap-node-right
                        ) ; end size
               ) ; end *
            ) ; end <
        ) ; end or
        (single-left k v l r
        ) ; end single-left
       ] ; end clause
       [else (double-left k v l r
             ) ; end double-left
       ] ; end else
     ) ; end cond
    ] ; end clause
    [(>= ls (* delta rs
            ) ; end *
     ) ; end >=
     (cond
       [(not (intmap-node? l)) (make-node k v l r
                               ) ; end make-node
       ] ; end clause
       [(or (not (intmap-node? (intmap-node-right l
                               ) ; end intmap-node-right
                 ) ; end intmap-node?
            ) ; end not
            (< (size (intmap-node-right l
                     ) ; end intmap-node-right
               ) ; end size
               (* ratio (size (intmap-node-left l
                              ) ; end intmap-node-left
                        ) ; end size
               ) ; end *
            ) ; end <
        ) ; end or
        (single-right k v l r
        ) ; end single-right
       ] ; end clause
       [else (double-right k v l r
             ) ; end double-right
       ] ; end else
     ) ; end cond
    ] ; end clause
    [else (make-node k v l r
          ) ; end make-node
    ] ; end else
  ) ; end cond
) ; end define

(define (intmap . kvs
        ) ; end intmap
  (let loop ([kvs kvs] [m empty-intmap
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
  (size m
  ) ; end size
) ; end define

(define (intmap-ref m k [default missing-default
                        ] ; end default
        ) ; end intmap-ref
  (check-intmap 'intmap-ref m
  ) ; end check-intmap
  (check-key 'intmap-ref k
  ) ; end check-key
  (let loop ([t m
             ] ; end t
            ) ; end form
    (cond
      [(empty-intmap-record? t
       ) ; end empty-intmap-record?
       (cond
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
      ] ; end clause
      [else
       (define tk (intmap-node-key t
                  ) ; end intmap-node-key
       ) ; end define
       (cond
         [(key<? k tk) (loop (intmap-node-left t
                             ) ; end intmap-node-left
                       ) ; end loop
         ] ; end clause
         [(key>? k tk) (loop (intmap-node-right t
                             ) ; end intmap-node-right
                       ) ; end loop
         ] ; end clause
         [else (intmap-node-value t
               ) ; end intmap-node-value
         ] ; end else
       ) ; end cond
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (intmap-has-key? m k
        ) ; end intmap-has-key?
  (check-intmap 'intmap-has-key? m
  ) ; end check-intmap
  (check-key 'intmap-has-key? k
  ) ; end check-key
  (let loop ([t m
             ] ; end t
            ) ; end form
    (cond
      [(empty-intmap-record? t) #f
      ] ; end f
      [else
       (define tk (intmap-node-key t
                  ) ; end intmap-node-key
       ) ; end define
       (cond
         [(key<? k tk) (loop (intmap-node-left t
                             ) ; end intmap-node-left
                       ) ; end loop
         ] ; end clause
         [(key>? k tk) (loop (intmap-node-right t
                             ) ; end intmap-node-right
                       ) ; end loop
         ] ; end clause
         [else #t
         ] ; end else
       ) ; end cond
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (intmap-set m k v
        ) ; end intmap-set
  (check-intmap 'intmap-set m
  ) ; end check-intmap
  (check-key 'intmap-set k
  ) ; end check-key
  (let loop ([t m
             ] ; end t
            ) ; end form
    (cond
      [(empty-intmap-record? t) (make-node k v empty-intmap empty-intmap
                                ) ; end make-node
      ] ; end clause
      [else
       (define tk (intmap-node-key t
                  ) ; end intmap-node-key
       ) ; end define
       (cond
         [(key<? k tk
          ) ; end key<?
          (balance tk (intmap-node-value t
                      ) ; end intmap-node-value
                   (loop (intmap-node-left t
                         ) ; end intmap-node-left
                   ) ; end loop
                   (intmap-node-right t
                   ) ; end intmap-node-right
          ) ; end balance
         ] ; end clause
         [(key>? k tk
          ) ; end key>?
          (balance tk (intmap-node-value t
                      ) ; end intmap-node-value
                   (intmap-node-left t
                   ) ; end intmap-node-left
                   (loop (intmap-node-right t
                         ) ; end intmap-node-right
                   ) ; end loop
          ) ; end balance
         ] ; end clause
         [else
          (intmap-node (intmap-node-size t) k v (intmap-node-left t) (intmap-node-right t
                                                                     ) ; end intmap-node-right
          ) ; end intmap-node
         ] ; end else
       ) ; end cond
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (produced-value producer old-value present?
        ) ; end produced-value
  (if (procedure? producer)
      (if present?
          (producer old-value
          ) ; end producer
          (producer
          ) ; end producer
      ) ; end if
      producer
  ) ; end if
) ; end define

(define (intmap-update m k absent present
        ) ; end intmap-update
  (check-intmap 'intmap-update m
  ) ; end check-intmap
  (check-key 'intmap-update k
  ) ; end check-key
  (define old (intmap-ref m k missing-default
              ) ; end intmap-ref
  ) ; end define
  (if (eq? old missing-default
      ) ; end eq?
      (intmap-set m k (produced-value absent #f #f
                      ) ; end produced-value
      ) ; end intmap-set
      (intmap-set m k (produced-value present old #t
                      ) ; end produced-value
      ) ; end intmap-set
  ) ; end if
) ; end define

(define (intmap-replace m k v
        ) ; end intmap-replace
  (check-intmap 'intmap-replace m
  ) ; end check-intmap
  (check-key 'intmap-replace k
  ) ; end check-key
  (define old (intmap-ref m k missing-default
              ) ; end intmap-ref
  ) ; end define
  (if (eq? old missing-default
      ) ; end eq?
      (values m #f
      ) ; end values
      (values (intmap-set m k v
              ) ; end intmap-set
              #t
      ) ; end values
  ) ; end if
) ; end define

(define (intmap-set/absent m k v
        ) ; end intmap-set/absent
  (check-intmap 'intmap-set/absent m
  ) ; end check-intmap
  (check-key 'intmap-set/absent k
  ) ; end check-key
  (define old (intmap-ref m k missing-default
              ) ; end intmap-ref
  ) ; end define
  (if (eq? old missing-default
      ) ; end eq?
      (values (intmap-set m k v
              ) ; end intmap-set
              #t
      ) ; end values
      (values m #f
      ) ; end values
  ) ; end if
) ; end define

(define (intmap-replace/check who same? m k expected v
        ) ; end intmap-replace/check
  (check-intmap who m
  ) ; end check-intmap
  (check-key who k
  ) ; end check-key
  (define old (intmap-ref m k missing-default
              ) ; end intmap-ref
  ) ; end define
  (if (and (not (eq? old missing-default
               ) ; end eq?
           ) ; end not
           (same? expected old
           ) ; end same?
      ) ; end and
      (values (intmap-set m k v
              ) ; end intmap-set
              #t
      ) ; end values
      (values m #f
      ) ; end values
  ) ; end if
) ; end define

(define (intmap-replace/eq m k expected v
        ) ; end intmap-replace/eq
  (intmap-replace/check 'intmap-replace/eq eq? m k expected v
  ) ; end intmap-replace/check
) ; end define

(define (intmap-replace/equal m k expected v
        ) ; end intmap-replace/equal
  (intmap-replace/check 'intmap-replace/equal equal? m k expected v
  ) ; end intmap-replace/check
) ; end define

(define (delete-find-min t
        ) ; end delete-find-min
  (cond
    [(empty-intmap-record? (intmap-node-left t
                           ) ; end intmap-node-left
     ) ; end empty-intmap-record?
     (values (intmap-node-key t) (intmap-node-value t) (intmap-node-right t
                                                       ) ; end intmap-node-right
     ) ; end values
    ] ; end clause
    [else
     (define-values (k v l*) (delete-find-min (intmap-node-left t
                                              ) ; end intmap-node-left
                             ) ; end delete-find-min
     ) ; end define-values
     (values k v (balance (intmap-node-key t
                          ) ; end intmap-node-key
                          (intmap-node-value t
                          ) ; end intmap-node-value
                          l*
                          (intmap-node-right t
                          ) ; end intmap-node-right
                 ) ; end balance
     ) ; end values
    ] ; end else
  ) ; end cond
) ; end define

(define (delete-find-max t
        ) ; end delete-find-max
  (cond
    [(empty-intmap-record? (intmap-node-right t
                           ) ; end intmap-node-right
     ) ; end empty-intmap-record?
     (values (intmap-node-key t) (intmap-node-value t) (intmap-node-left t
                                                       ) ; end intmap-node-left
     ) ; end values
    ] ; end clause
    [else
     (define-values (k v r*) (delete-find-max (intmap-node-right t
                                              ) ; end intmap-node-right
                             ) ; end delete-find-max
     ) ; end define-values
     (values k v (balance (intmap-node-key t
                          ) ; end intmap-node-key
                          (intmap-node-value t
                          ) ; end intmap-node-value
                          (intmap-node-left t
                          ) ; end intmap-node-left
                          r*
                 ) ; end balance
     ) ; end values
    ] ; end else
  ) ; end cond
) ; end define

(define (glue l r
        ) ; end glue
  (cond
    [(empty-intmap-record? l) r
    ] ; end r
    [(empty-intmap-record? r) l
    ] ; end l
    [(> (size l) (size r
                 ) ; end size
     ) ; end >
     (define-values (k v l*) (delete-find-max l
                             ) ; end delete-find-max
     ) ; end define-values
     (balance k v l* r
     ) ; end balance
    ] ; end clause
    [else
     (define-values (k v r*) (delete-find-min r
                             ) ; end delete-find-min
     ) ; end define-values
     (balance k v l r*
     ) ; end balance
    ] ; end else
  ) ; end cond
) ; end define

(define (intmap-remove m k
        ) ; end intmap-remove
  (check-intmap 'intmap-remove m
  ) ; end check-intmap
  (check-key 'intmap-remove k
  ) ; end check-key
  (let loop ([t m
             ] ; end t
            ) ; end form
    (cond
      [(empty-intmap-record? t) t
      ] ; end t
      [else
       (define tk (intmap-node-key t
                  ) ; end intmap-node-key
       ) ; end define
       (cond
         [(key<? k tk
          ) ; end key<?
          (balance tk (intmap-node-value t
                      ) ; end intmap-node-value
                   (loop (intmap-node-left t
                         ) ; end intmap-node-left
                   ) ; end loop
                   (intmap-node-right t
                   ) ; end intmap-node-right
          ) ; end balance
         ] ; end clause
         [(key>? k tk
          ) ; end key>?
          (balance tk (intmap-node-value t
                      ) ; end intmap-node-value
                   (intmap-node-left t
                   ) ; end intmap-node-left
                   (loop (intmap-node-right t
                         ) ; end intmap-node-right
                   ) ; end loop
          ) ; end balance
         ] ; end clause
         [else (glue (intmap-node-left t) (intmap-node-right t
                                          ) ; end intmap-node-right
               ) ; end glue
         ] ; end else
       ) ; end cond
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (intmap-remove/check who same? m k expected
        ) ; end intmap-remove/check
  (check-intmap who m
  ) ; end check-intmap
  (check-key who k
  ) ; end check-key
  (define old (intmap-ref m k missing-default
              ) ; end intmap-ref
  ) ; end define
  (if (and (not (eq? old missing-default
               ) ; end eq?
           ) ; end not
           (same? expected old
           ) ; end same?
      ) ; end and
      (values (intmap-remove m k
              ) ; end intmap-remove
              #t
      ) ; end values
      (values m #f
      ) ; end values
  ) ; end if
) ; end define

(define (intmap-remove/eq m k expected
        ) ; end intmap-remove/eq
  (intmap-remove/check 'intmap-remove/eq eq? m k expected
  ) ; end intmap-remove/check
) ; end define

(define (intmap-remove/equal m k expected
        ) ; end intmap-remove/equal
  (intmap-remove/check 'intmap-remove/equal equal? m k expected
  ) ; end intmap-remove/check
) ; end define

(define (search-entry m k better?
        ) ; end search-entry
  (let loop ([t m] [best #f
                   ] ; end best
            ) ; end form
    (cond
      [(empty-intmap-record? t) best
      ] ; end best
      [else
       (define tk (intmap-node-key t
                  ) ; end intmap-node-key
       ) ; end define
       (cond
         [(better? tk k) (loop (intmap-node-right t) t
                         ) ; end loop
         ] ; end clause
         [else (loop (intmap-node-left t) best
               ) ; end loop
         ] ; end else
       ) ; end cond
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (search-entry-reverse m k better?
        ) ; end search-entry-reverse
  (let loop ([t m] [best #f
                   ] ; end best
            ) ; end form
    (cond
      [(empty-intmap-record? t) best
      ] ; end best
      [else
       (define tk (intmap-node-key t
                  ) ; end intmap-node-key
       ) ; end define
       (cond
         [(better? tk k) (loop (intmap-node-left t) t
                         ) ; end loop
         ] ; end clause
         [else (loop (intmap-node-right t) best
               ) ; end loop
         ] ; end else
       ) ; end cond
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (node->entry t
        ) ; end node->entry
  (and t (cons (intmap-node-key t) (intmap-node-value t
                                   ) ; end intmap-node-value
         ) ; end cons
  ) ; end and
) ; end define

(define (intmap-entry< m k [default #f
                           ] ; end default
        ) ; end intmap-entry<
  (check-intmap 'intmap-entry< m
  ) ; end check-intmap
  (check-key 'intmap-entry< k
  ) ; end check-key
  (or (node->entry (search-entry m k key<?)) default
  ) ; end or
) ; end define

(define (intmap-entry<= m k [default #f
                            ] ; end default
        ) ; end intmap-entry<=
  (check-intmap 'intmap-entry<= m
  ) ; end check-intmap
  (check-key 'intmap-entry<= k
  ) ; end check-key
  (or (node->entry (search-entry m k key<=?)) default
  ) ; end or
) ; end define

(define (intmap-entry> m k [default #f
                           ] ; end default
        ) ; end intmap-entry>
  (check-intmap 'intmap-entry> m
  ) ; end check-intmap
  (check-key 'intmap-entry> k
  ) ; end check-key
  (or (node->entry (search-entry-reverse m k key>?)) default
  ) ; end or
) ; end define

(define (intmap-entry>= m k [default #f
                            ] ; end default
        ) ; end intmap-entry>=
  (check-intmap 'intmap-entry>= m
  ) ; end check-intmap
  (check-key 'intmap-entry>= k
  ) ; end check-key
  (or (node->entry (search-entry-reverse m k key>=?)) default
  ) ; end or
) ; end define

(define (intmap-min-entry m [default missing-default
                            ] ; end default
        ) ; end intmap-min-entry
  (check-intmap 'intmap-min-entry m
  ) ; end check-intmap
  (let loop ([t m
             ] ; end t
            ) ; end form
    (cond
      [(empty-intmap-record? t
       ) ; end empty-intmap-record?
       (if (eq? default missing-default
           ) ; end eq?
           (raise-arguments-error 'intmap-min-entry "empty intmap"
           ) ; end raise-arguments-error
           default
       ) ; end if
      ] ; end clause
      [(empty-intmap-record? (intmap-node-left t
                             ) ; end intmap-node-left
       ) ; end empty-intmap-record?
       (cons (intmap-node-key t) (intmap-node-value t
                                 ) ; end intmap-node-value
       ) ; end cons
      ] ; end clause
      [else (loop (intmap-node-left t
                  ) ; end intmap-node-left
            ) ; end loop
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (intmap-max-entry m [default missing-default
                            ] ; end default
        ) ; end intmap-max-entry
  (check-intmap 'intmap-max-entry m
  ) ; end check-intmap
  (let loop ([t m
             ] ; end t
            ) ; end form
    (cond
      [(empty-intmap-record? t
       ) ; end empty-intmap-record?
       (if (eq? default missing-default
           ) ; end eq?
           (raise-arguments-error 'intmap-max-entry "empty intmap"
           ) ; end raise-arguments-error
           default
       ) ; end if
      ] ; end clause
      [(empty-intmap-record? (intmap-node-right t
                             ) ; end intmap-node-right
       ) ; end empty-intmap-record?
       (cons (intmap-node-key t) (intmap-node-value t
                                 ) ; end intmap-node-value
       ) ; end cons
      ] ; end clause
      [else (loop (intmap-node-right t
                  ) ; end intmap-node-right
            ) ; end loop
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (bound-ok? cmp bound k
        ) ; end bound-ok?
  (or (not bound) (cmp bound k
                  ) ; end cmp
  ) ; end or
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
  (define (above-lo? k
          ) ; end above-lo?
    (or (not lo) (if inclusive-lo? (key>=? k lo) (key>? k lo
                                                 ) ; end key>?
                 ) ; end if
    ) ; end or
  ) ; end define
  (define (below-hi? k
          ) ; end below-hi?
    (or (not hi) (if inclusive-hi? (key<=? k hi) (key<? k hi
                                                 ) ; end key<?
                 ) ; end if
    ) ; end or
  ) ; end define
  (define (maybe-left? k
          ) ; end maybe-left?
    (or (not lo) (if inclusive-lo? (key>? k lo) (key>? k lo
                                                ) ; end key>?
                 ) ; end if
    ) ; end or
  ) ; end define
  (define (maybe-right? k
          ) ; end maybe-right?
    (or (not hi) (if inclusive-hi? (key<? k hi) (key<? k hi
                                                ) ; end key<?
                 ) ; end if
    ) ; end or
  ) ; end define
  (let loop ([t m] [acc null
                   ] ; end acc
            ) ; end form
    (cond
      [(empty-intmap-record? t) acc
      ] ; end acc
      [else
       (define k (intmap-node-key t
                 ) ; end intmap-node-key
       ) ; end define
       (define acc* (if (maybe-right? k) (loop (intmap-node-right t) acc) acc
                    ) ; end if
       ) ; end define
       (define acc** (if (and (above-lo? k) (below-hi? k
                                            ) ; end below-hi?
                         ) ; end and
                         (cons (cons k (intmap-node-value t)) acc*
                         ) ; end cons
                         acc*
                     ) ; end if
       ) ; end define
       (if (maybe-left? k
           ) ; end maybe-left?
           (loop (intmap-node-left t) acc**
           ) ; end loop
           acc**
       ) ; end if
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (pairs->sequence pairs mode
        ) ; end pairs->sequence
  (make-do-sequence
   (lambda (
           ) ; end form
     (values
      (case mode
        [(entries) (lambda (pos) (values (caar pos) (cdar pos
                                                    ) ; end cdar
                                 ) ; end values
                   ) ; end lambda
        ] ; end clause
        [(keys) (lambda (pos) (caar pos
                              ) ; end caar
                ) ; end lambda
        ] ; end clause
        [(values) (lambda (pos) (cdar pos
                                ) ; end cdar
                  ) ; end lambda
        ] ; end clause
        [(pairs) (lambda (pos) (car pos
                               ) ; end car
                 ) ; end lambda
        ] ; end clause
      ) ; end case
      cdr
      pairs
      pair?
      #f
      #f
     ) ; end values
   ) ; end lambda
  ) ; end make-do-sequence
) ; end define

(define (maybe-reverse-pairs pairs reverse?
        ) ; end maybe-reverse-pairs
  (if reverse?
      (reverse pairs
      ) ; end reverse
      pairs
  ) ; end if
) ; end define

(define (in-intmap m #:reverse? [reverse? #f
                                ] ; end reverse?
        ) ; end in-intmap
  (pairs->sequence (maybe-reverse-pairs (intmap-range->list m #f #f) reverse?
                   ) ; end maybe-reverse-pairs
                   'entries
  ) ; end pairs->sequence
) ; end define

(define (in-intmap-keys m #:reverse? [reverse? #f
                                     ] ; end reverse?
        ) ; end in-intmap-keys
  (pairs->sequence (maybe-reverse-pairs (intmap-range->list m #f #f) reverse?
                   ) ; end maybe-reverse-pairs
                   'keys
  ) ; end pairs->sequence
) ; end define

(define (in-intmap-values m #:reverse? [reverse? #f
                                       ] ; end reverse?
        ) ; end in-intmap-values
  (pairs->sequence (maybe-reverse-pairs (intmap-range->list m #f #f) reverse?
                   ) ; end maybe-reverse-pairs
                   'values
  ) ; end pairs->sequence
) ; end define

(define (in-intmap-pairs m #:reverse? [reverse? #f
                                      ] ; end reverse?
        ) ; end in-intmap-pairs
  (pairs->sequence (maybe-reverse-pairs (intmap-range->list m #f #f) reverse?
                   ) ; end maybe-reverse-pairs
                   'pairs
  ) ; end pairs->sequence
) ; end define

(define (in-intmap-range m lo hi #:reverse? [reverse? #f
                                            ] ; end reverse?
        ) ; end in-intmap-range
  (pairs->sequence (maybe-reverse-pairs (intmap-range->list m lo hi) reverse?
                   ) ; end maybe-reverse-pairs
                   'entries
  ) ; end pairs->sequence
) ; end define

(define (in-intmap-range-keys m lo hi #:reverse? [reverse? #f
                                                 ] ; end reverse?
        ) ; end in-intmap-range-keys
  (pairs->sequence (maybe-reverse-pairs (intmap-range->list m lo hi) reverse?
                   ) ; end maybe-reverse-pairs
                   'keys
  ) ; end pairs->sequence
) ; end define

(define (in-intmap-range-values m lo hi #:reverse? [reverse? #f
                                                   ] ; end reverse?
        ) ; end in-intmap-range-values
  (pairs->sequence (maybe-reverse-pairs (intmap-range->list m lo hi) reverse?
                   ) ; end maybe-reverse-pairs
                   'values
  ) ; end pairs->sequence
) ; end define

(define (in-intmap-range-pairs m lo hi #:reverse? [reverse? #f
                                                  ] ; end reverse?
        ) ; end in-intmap-range-pairs
  (pairs->sequence (maybe-reverse-pairs (intmap-range->list m lo hi) reverse?
                   ) ; end maybe-reverse-pairs
                   'pairs
  ) ; end pairs->sequence
) ; end define

(define (entry-key who e
        ) ; end entry-key
  (cond
    [(pair? e) (car e
               ) ; end car
    ] ; end clause
    [else (raise-argument-error who "(or/c pair? vector?)" e
          ) ; end raise-argument-error
    ] ; end else
  ) ; end cond
) ; end define

(define (entry-value who e
        ) ; end entry-value
  (cond
    [(pair? e) (cdr e
               ) ; end cdr
    ] ; end clause
    [else (raise-argument-error who "(or/c pair? vector?)" e
          ) ; end raise-argument-error
    ] ; end else
  ) ; end cond
) ; end define

(define (sorted-vector->intmap vec
        ) ; end sorted-vector->intmap
  (unless (vector? vec
          ) ; end vector?
    (raise-argument-error 'sorted-vector->intmap "vector?" vec
    ) ; end raise-argument-error
  ) ; end unless
  (define len (vector-length vec
              ) ; end vector-length
  ) ; end define
  (for/fold ([prev #f]) ([i (in-range len
                            ) ; end in-range
                         ] ; end i
                        ) ; end form
    (define e (vector-ref vec i
              ) ; end vector-ref
    ) ; end define
    (define k (entry-key 'sorted-vector->intmap e
              ) ; end entry-key
    ) ; end define
    (check-key 'sorted-vector->intmap k
    ) ; end check-key
    (when (and prev (not (key<? prev k
                         ) ; end key<?
                    ) ; end not
          ) ; end and
      (raise-arguments-error 'sorted-vector->intmap
                             "expected strictly increasing integer keys"
                             "previous key" prev
                             "key" k
      ) ; end raise-arguments-error
    ) ; end when
    k
  ) ; end for/fold
  (let build ([start 0] [end len
                        ] ; end end
             ) ; end form
    (if (>= start end
        ) ; end >=
        empty-intmap
        (let* ([mid (quotient (+ start end) 2
                    ) ; end quotient
               ] ; end mid
               [e (vector-ref vec mid
                  ) ; end vector-ref
               ] ; end e
              ) ; end form
          (make-node (entry-key 'sorted-vector->intmap e
                     ) ; end entry-key
                     (entry-value 'sorted-vector->intmap e
                     ) ; end entry-value
                     (build start mid
                     ) ; end build
                     (build (add1 mid) end
                     ) ; end build
          ) ; end make-node
        ) ; end let*
    ) ; end if
  ) ; end let
) ; end define

(define (sorted-list->intmap entries
        ) ; end sorted-list->intmap
  (unless (list? entries
          ) ; end list?
    (raise-argument-error 'sorted-list->intmap "list?" entries
    ) ; end raise-argument-error
  ) ; end unless
  (sorted-vector->intmap (list->vector entries
                         ) ; end list->vector
  ) ; end sorted-vector->intmap
) ; end define

(define (height t
        ) ; end height
  (if (empty-intmap-record? t
      ) ; end empty-intmap-record?
      0
      (+ 1 (max (height (intmap-node-left t
                        ) ; end intmap-node-left
                ) ; end height
                (height (intmap-node-right t
                        ) ; end intmap-node-right
                ) ; end height
           ) ; end max
      ) ; end +
  ) ; end if
) ; end define

(define (max-imbalance t
        ) ; end max-imbalance
  (if (empty-intmap-record? t
      ) ; end empty-intmap-record?
      0
      (max (abs (- (size (intmap-node-left t
                         ) ; end intmap-node-left
                   ) ; end size
                   (size (intmap-node-right t
                         ) ; end intmap-node-right
                   ) ; end size
                ) ; end -
           ) ; end abs
           (max-imbalance (intmap-node-left t
                          ) ; end intmap-node-left
           ) ; end max-imbalance
           (max-imbalance (intmap-node-right t
                          ) ; end intmap-node-right
           ) ; end max-imbalance
      ) ; end max
  ) ; end if
) ; end define

(define (intmap-shape-stats m
        ) ; end intmap-shape-stats
  (check-intmap 'intmap-shape-stats m
  ) ; end check-intmap
  (hasheq 'backend 'racket
          'count (size m
                 ) ; end size
          'height (height m
                  ) ; end height
          'max-imbalance (max-imbalance m
                         ) ; end max-imbalance
  ) ; end hasheq
) ; end define

(define (intmap-install-struct-property! . _
        ) ; end intmap-install-struct-property!
  #f
) ; end define
