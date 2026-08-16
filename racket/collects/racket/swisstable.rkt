#lang racket/base

;; Public library for the SwissTable-style mutable hash table.  The
;; table is a new data structure alongside (not replacing) the
;; standard mutable hash tables; see design.md and the reference
;; documentation for the design rationale.

(require (rename-in "private/swisstable-runtime-adapter.rkt"
                    [make-swisstable make-swisstable/kind
                    ] ; end rename
         ) ; end rename-in
         racket/private/generic-methods
         (only-in racket/private/dict gen:dict
         ) ; end only-in
         (for-syntax racket/base
         ) ; end for-syntax
) ; end require

(provide make-swisstable
         make-swisstable-eqv
         make-swisstable-eq
         make-swisstable-weak
         make-swisstable-weak-eqv
         make-swisstable-weak-eq
         make-swisstable-ephemeron
         make-swisstable-ephemeron-eqv
         make-swisstable-ephemeron-eq
         swisstable?
         swisstable-kind
         swisstable-weakness
         swisstable-count
         swisstable-empty?
         swisstable-ref
         swisstable-ref!
         swisstable-has-key?
         swisstable-set!
         swisstable-remove!
         swisstable-clear!
         swisstable-update!
         swisstable-copy
         swisstable->list
         swisstable-keys
         swisstable-values
         swisstable-for-each
         swisstable-map
         in-swisstable
         in-swisstable-keys
         in-swisstable-values
         swisstable-iterate-first
         swisstable-iterate-next
         swisstable-iterate-key
         swisstable-iterate-value
         swisstable-iterate-key+value
         swisstable-stats
         swisstable-runtime-adapter-backend
         swisstable-runtime-adapter-core-available?
         swisstable->hash
         hash->swisstable
         for/swisstable
         for*/swisstable
) ; end provide

(define (swisstable-custom-write st port mode
        ) ; end swisstable-custom-write
  (fprintf port "#<swisstable:~a count=~a>"
           (swisstable-kind st
           ) ; end swisstable-kind
           (swisstable-count st
           ) ; end swisstable-count
  ) ; end fprintf
) ; end define

(swisstable-install-struct-property! prop:custom-write swisstable-custom-write
) ; end swisstable-install-struct-property!

;; Structural equality: two swisstables are equal? when they have
;; the same key-comparison kind, the same key-retention mode, and
;; equal? key/value entries (order-independent).  The hash
;; combination is commutative, so iteration order does not matter.
;; This also makes swisstables usable as keys of equal?-based tables.
(define swisstable-equal+hash
  (list (lambda (a b recur
                ) ; end lambda args
          (and (swisstable? b
               ) ; end swisstable?
               (eq? (swisstable-kind a
                    ) ; end swisstable-kind
                    (swisstable-kind b
                    ) ; end swisstable-kind
               ) ; end eq?
               (eq? (swisstable-weakness a
                    ) ; end swisstable-weakness
                    (swisstable-weakness b
                    ) ; end swisstable-weakness
               ) ; end eq?
               (= (swisstable-count a
                  ) ; end swisstable-count
                  (swisstable-count b
                  ) ; end swisstable-count
               ) ; end =
               (let loop ([i (swisstable-iterate-first a
                             ) ; end swisstable-iterate-first
                          ] ; end i
                         ) ; end loop args
                 (or (not i
                     ) ; end not
                     (let-values ([(k v) (swisstable-iterate-key+value a i
                                         ) ; end swisstable-iterate-key+value
                                  ] ; end k v
                                 ) ; end let-values args
                       (define bv (swisstable-ref b k missing
                                  ) ; end swisstable-ref
                       ) ; end define
                       (and (not (eq? bv missing
                                 ) ; end eq?
                            ) ; end not
                            (recur v bv
                            ) ; end recur
                            (loop (swisstable-iterate-next a i
                                  ) ; end swisstable-iterate-next
                            ) ; end loop
                       ) ; end and
                     ) ; end let-values
                 ) ; end or
               ) ; end let
          ) ; end and
        ) ; end lambda
        (lambda (a recur
                ) ; end lambda args
          (let loop ([i (swisstable-iterate-first a
                        ) ; end swisstable-iterate-first
                     ] ; end i
                     [acc (recur (swisstable-kind a
                                 ) ; end swisstable-kind
                          ) ; end recur
                     ] ; end acc
                    ) ; end loop args
            (if i
                (let-values ([(k v) (swisstable-iterate-key+value a i
                                    ) ; end swisstable-iterate-key+value
                             ] ; end k v
                            ) ; end let-values args
                  (loop (swisstable-iterate-next a i
                        ) ; end swisstable-iterate-next
                        (+ acc (bitwise-xor (* 3 (recur k
                                                 ) ; end recur
                                            ) ; end *
                                            (recur v
                                            ) ; end recur
                               ) ; end bitwise-xor
                        ) ; end +
                  ) ; end loop
                ) ; end let-values
                acc
            ) ; end if
          ) ; end let
        ) ; end lambda
        (lambda (a recur
                ) ; end lambda args
          (let loop ([i (swisstable-iterate-first a
                        ) ; end swisstable-iterate-first
                     ] ; end i
                     [acc 43
                     ] ; end acc
                    ) ; end loop args
            (if i
                (let-values ([(k v) (swisstable-iterate-key+value a i
                                    ) ; end swisstable-iterate-key+value
                             ] ; end k v
                            ) ; end let-values args
                  (loop (swisstable-iterate-next a i
                        ) ; end swisstable-iterate-next
                        (+ acc (recur k
                               ) ; end recur
                               (* 5 (recur v
                                    ) ; end recur
                               ) ; end *
                        ) ; end +
                  ) ; end loop
                ) ; end let-values
                acc
            ) ; end if
          ) ; end let
        ) ; end lambda
  ) ; end list
) ; end define

(swisstable-install-struct-property! prop:equal+hash swisstable-equal+hash
) ; end swisstable-install-struct-property!

(swisstable-install-struct-property! prop:sequence
                                     (lambda (st) (in-swisstable st
                                                  ) ; end in-swisstable
                                     ) ; end lambda
) ; end swisstable-install-struct-property!

;; Dict-interface integration for the core backend: attach the
;; gen:dict method table to the core record type, so swisstables
;; work with dict-ref, in-dict, dict-map, and the rest of
;; racket/dict.  (The pure-Racket fallback struct declares the same
;; methods in its definition.)
(swisstable-install-struct-property!
 (generic-property gen:dict
 ) ; end generic-property
 (generic-method-table gen:dict
   (define dict-ref
     (case-lambda
       [(d k) (swisstable-ref d k
              ) ; end swisstable-ref
       ] ; end clause
       [(d k failure) (swisstable-ref d k failure
                      ) ; end swisstable-ref
       ] ; end clause
     ) ; end case-lambda
   ) ; end define
   (define (dict-set! d k v
           ) ; end dict-set!
     (swisstable-set! d k v
     ) ; end swisstable-set!
   ) ; end define
   (define (dict-remove! d k
           ) ; end dict-remove!
     (swisstable-remove! d k
     ) ; end swisstable-remove!
     (void
     ) ; end void
   ) ; end define
   (define (dict-count d
           ) ; end dict-count
     (swisstable-count d
     ) ; end swisstable-count
   ) ; end define
   (define (dict-iterate-first d
           ) ; end dict-iterate-first
     (swisstable-iterate-first d
     ) ; end swisstable-iterate-first
   ) ; end define
   (define (dict-iterate-next d i
           ) ; end dict-iterate-next
     (swisstable-iterate-next d i
     ) ; end swisstable-iterate-next
   ) ; end define
   (define (dict-iterate-key d i
           ) ; end dict-iterate-key
     (swisstable-iterate-key d i
     ) ; end swisstable-iterate-key
   ) ; end define
   (define (dict-iterate-value d i
           ) ; end dict-iterate-value
     (swisstable-iterate-value d i
     ) ; end swisstable-iterate-value
   ) ; end define
 ) ; end generic-method-table
) ; end swisstable-install-struct-property!

;; Conversions to and from the built-in hash tables.
(define (swisstable->hash st
        ) ; end swisstable->hash
  (define h
    (case (swisstable-weakness st
          ) ; end swisstable-weakness
      [(strong
       ) ; end strong
       (case (swisstable-kind st
             ) ; end swisstable-kind
         [(eq) (make-hasheq
               ) ; end make-hasheq
         ] ; end clause
         [(eqv) (make-hasheqv
                ) ; end make-hasheqv
         ] ; end clause
         [else (make-hash
               ) ; end make-hash
         ] ; end else
       ) ; end case
      ] ; end clause
      [(weak
       ) ; end weak
       (case (swisstable-kind st
             ) ; end swisstable-kind
         [(eq) (make-weak-hasheq
               ) ; end make-weak-hasheq
         ] ; end clause
         [(eqv) (make-weak-hasheqv
                ) ; end make-weak-hasheqv
         ] ; end clause
         [else (make-weak-hash
               ) ; end make-weak-hash
         ] ; end else
       ) ; end case
      ] ; end clause
      [else
       (case (swisstable-kind st
             ) ; end swisstable-kind
         [(eq) (make-ephemeron-hasheq
               ) ; end make-ephemeron-hasheq
         ] ; end clause
         [(eqv) (make-ephemeron-hasheqv
                ) ; end make-ephemeron-hasheqv
         ] ; end clause
         [else (make-ephemeron-hash
               ) ; end make-ephemeron-hash
         ] ; end else
       ) ; end case
      ] ; end else
    ) ; end case
  ) ; end define
  (swisstable-for-each st (lambda (k v) (hash-set! h k v
                                        ) ; end hash-set!
                          ) ; end lambda
  ) ; end swisstable-for-each
  h
) ; end define

(define (hash->swisstable h
        ) ; end hash->swisstable
  (unless (hash? h
          ) ; end hash?
    (raise-argument-error 'hash->swisstable "hash?" h
    ) ; end raise-argument-error
  ) ; end unless
  (when (hash-equal-always? h
        ) ; end hash-equal-always?
    (raise-arguments-error 'hash->swisstable
                           "equal-always? hash tables are not supported"
                           "hash" h
    ) ; end raise-arguments-error
  ) ; end when
  (define kind (cond
                 [(hash-eq? h) 'eq
                 ] ; end clause
                 [(hash-eqv? h) 'eqv
                 ] ; end clause
                 [else 'equal
                 ] ; end else
               ) ; end cond
  ) ; end define
  (define weakness (cond
                     [(hash-ephemeron? h) 'ephemeron
                     ] ; end clause
                     [(hash-weak? h) 'weak
                     ] ; end clause
                     [else 'strong
                     ] ; end else
                   ) ; end cond
  ) ; end define
  (define st (make-swisstable/kind kind weakness (hash-count h
                                                 ) ; end hash-count
             ) ; end make-swisstable/kind
  ) ; end define
  (for ([(k v) (in-hash h
               ) ; end in-hash
        ] ; end k v
       ) ; end for args
    (swisstable-set! st k v
    ) ; end swisstable-set!
  ) ; end for
  st
) ; end define

;; for/hash-style comprehensions; each body must produce two values,
;; a key and a value.
(define-syntax (for/swisstable stx
        ) ; end for/swisstable
  (syntax-case stx (
                   ) ; end literals
    [(_ clauses body ... tail-expr
     ) ; end pattern
     (with-syntax ([original stx
                   ] ; end original
                  ) ; end with-syntax args
       #'(let ([st (make-swisstable
                   ) ; end make-swisstable
               ] ; end st
              ) ; end let args
           (for/fold/derived original (
                                      ) ; end accums
                             clauses
             body ...
             (let-values ([(k v) tail-expr
                          ] ; end k v
                         ) ; end let-values args
               (swisstable-set! st k v
               ) ; end swisstable-set!
               (values
               ) ; end values
             ) ; end let-values
           ) ; end for/fold/derived
           st
         ) ; end let
     ) ; end with-syntax
    ] ; end clause
  ) ; end syntax-case
) ; end define-syntax

(define-syntax (for*/swisstable stx
        ) ; end for*/swisstable
  (syntax-case stx (
                   ) ; end literals
    [(_ clauses body ... tail-expr
     ) ; end pattern
     (with-syntax ([original stx
                   ] ; end original
                  ) ; end with-syntax args
       #'(let ([st (make-swisstable
                   ) ; end make-swisstable
               ] ; end st
              ) ; end let args
           (for*/fold/derived original (
                                       ) ; end accums
                              clauses
             body ...
             (let-values ([(k v) tail-expr
                          ] ; end k v
                         ) ; end let-values args
               (swisstable-set! st k v
               ) ; end swisstable-set!
               (values
               ) ; end values
             ) ; end let-values
           ) ; end for*/fold/derived
           st
         ) ; end let
     ) ; end with-syntax
    ] ; end clause
  ) ; end syntax-case
) ; end define-syntax

(define (make-swisstable [hint 0
                         ] ; end hint
        ) ; end make-swisstable
  (make-swisstable/kind 'equal 'strong hint
  ) ; end make-swisstable/kind
) ; end define

(define (make-swisstable-eqv [hint 0
                             ] ; end hint
        ) ; end make-swisstable-eqv
  (make-swisstable/kind 'eqv 'strong hint
  ) ; end make-swisstable/kind
) ; end define

(define (make-swisstable-eq [hint 0
                            ] ; end hint
        ) ; end make-swisstable-eq
  (make-swisstable/kind 'eq 'strong hint
  ) ; end make-swisstable/kind
) ; end define

(define (make-swisstable-weak [hint 0
                              ] ; end hint
        ) ; end make-swisstable-weak
  (make-swisstable/kind 'equal 'weak hint
  ) ; end make-swisstable/kind
) ; end define

(define (make-swisstable-weak-eqv [hint 0
                                  ] ; end hint
        ) ; end make-swisstable-weak-eqv
  (make-swisstable/kind 'eqv 'weak hint
  ) ; end make-swisstable/kind
) ; end define

(define (make-swisstable-weak-eq [hint 0
                                 ] ; end hint
        ) ; end make-swisstable-weak-eq
  (make-swisstable/kind 'eq 'weak hint
  ) ; end make-swisstable/kind
) ; end define

(define (make-swisstable-ephemeron [hint 0
                                   ] ; end hint
        ) ; end make-swisstable-ephemeron
  (make-swisstable/kind 'equal 'ephemeron hint
  ) ; end make-swisstable/kind
) ; end define

(define (make-swisstable-ephemeron-eqv [hint 0
                                       ] ; end hint
        ) ; end make-swisstable-ephemeron-eqv
  (make-swisstable/kind 'eqv 'ephemeron hint
  ) ; end make-swisstable/kind
) ; end define

(define (make-swisstable-ephemeron-eq [hint 0
                                      ] ; end hint
        ) ; end make-swisstable-ephemeron-eq
  (make-swisstable/kind 'eq 'ephemeron hint
  ) ; end make-swisstable/kind
) ; end define

(define (swisstable-empty? st
        ) ; end swisstable-empty?
  (zero? (swisstable-count st
         ) ; end swisstable-count
  ) ; end zero?
) ; end define

(define missing (gensym 'missing
                ) ; end gensym
) ; end define

(define (swisstable-ref! st key to-set
        ) ; end swisstable-ref!
  (define v (swisstable-ref st key missing
            ) ; end swisstable-ref
  ) ; end define
  (cond
    [(not (eq? v missing)) v
    ] ; end clause
    [else
     (define new-v (if (and (procedure? to-set
                            ) ; end procedure?
                            (procedure-arity-includes? to-set 0
                            ) ; end procedure-arity-includes?
                       ) ; end and
                       (to-set
                       ) ; end to-set
                       to-set
                   ) ; end if
     ) ; end define
     (swisstable-set! st key new-v
     ) ; end swisstable-set!
     new-v
    ] ; end else
  ) ; end cond
) ; end define

(define (swisstable-update! st key updater [default missing
                                           ] ; end default
        ) ; end swisstable-update!
  (unless (and (procedure? updater
               ) ; end procedure?
               (procedure-arity-includes? updater 1
               ) ; end procedure-arity-includes?
          ) ; end and
    (raise-argument-error 'swisstable-update! "(procedure-arity-includes/c 1)" updater
    ) ; end raise-argument-error
  ) ; end unless
  (define v (swisstable-ref st key missing
            ) ; end swisstable-ref
  ) ; end define
  (define current
    (cond
      [(not (eq? v missing)) v
      ] ; end clause
      [(eq? default missing
       ) ; end eq?
       (raise-arguments-error 'swisstable-update! "no value found for key"
                              "key" key
       ) ; end raise-arguments-error
      ] ; end clause
      [(and (procedure? default
            ) ; end procedure?
            (procedure-arity-includes? default 0
            ) ; end procedure-arity-includes?
       ) ; end and
       (default
       ) ; end default
      ] ; end clause
      [else default
      ] ; end else
    ) ; end cond
  ) ; end define
  (swisstable-set! st key (updater current
                          ) ; end updater
  ) ; end swisstable-set!
) ; end define

(define (swisstable-fold st f init
        ) ; end swisstable-fold
  (let loop ([i (swisstable-iterate-first st
                ) ; end swisstable-iterate-first
             ] ; end i
             [acc init
             ] ; end acc
            ) ; end loop args
    (if i
        (let-values ([(k v) (swisstable-iterate-key+value st i
                            ) ; end swisstable-iterate-key+value
                     ] ; end k v
                    ) ; end let-values args
          (loop (swisstable-iterate-next st i
                ) ; end swisstable-iterate-next
                (f k v acc
                ) ; end f
          ) ; end loop
        ) ; end let-values
        acc
    ) ; end if
  ) ; end let
) ; end define

(define (swisstable-copy st
        ) ; end swisstable-copy
  (define new-st (make-swisstable/kind (swisstable-kind st
                                       ) ; end swisstable-kind
                                       (swisstable-weakness st
                                       ) ; end swisstable-weakness
                                       (swisstable-count st
                                       ) ; end swisstable-count
                 ) ; end make-swisstable/kind
  ) ; end define
  (swisstable-fold st
                   (lambda (k v acc
                           ) ; end lambda args
                     (swisstable-set! new-st k v
                     ) ; end swisstable-set!
                     acc
                   ) ; end lambda
                   (void
                   ) ; end void
  ) ; end swisstable-fold
  new-st
) ; end define

(define (swisstable->list st
        ) ; end swisstable->list
  (swisstable-fold st
                   (lambda (k v acc) (cons (cons k v
                                           ) ; end cons
                                           acc
                                     ) ; end cons
                   ) ; end lambda
                   '(
                    ) ; end quote
  ) ; end swisstable-fold
) ; end define

(define (swisstable-keys st
        ) ; end swisstable-keys
  (swisstable-fold st
                   (lambda (k v acc) (cons k acc
                                     ) ; end cons
                   ) ; end lambda
                   '(
                    ) ; end quote
  ) ; end swisstable-fold
) ; end define

(define (swisstable-values st
        ) ; end swisstable-values
  (swisstable-fold st
                   (lambda (k v acc) (cons v acc
                                     ) ; end cons
                   ) ; end lambda
                   '(
                    ) ; end quote
  ) ; end swisstable-fold
) ; end define

(define (swisstable-for-each st proc
        ) ; end swisstable-for-each
  (unless (and (procedure? proc
               ) ; end procedure?
               (procedure-arity-includes? proc 2
               ) ; end procedure-arity-includes?
          ) ; end and
    (raise-argument-error 'swisstable-for-each "(procedure-arity-includes/c 2)" proc
    ) ; end raise-argument-error
  ) ; end unless
  (swisstable-fold st
                   (lambda (k v acc) (proc k v
                                     ) ; end proc
                   ) ; end lambda
                   (void
                   ) ; end void
  ) ; end swisstable-fold
  (void
  ) ; end void
) ; end define

(define (swisstable-map st proc
        ) ; end swisstable-map
  (unless (and (procedure? proc
               ) ; end procedure?
               (procedure-arity-includes? proc 2
               ) ; end procedure-arity-includes?
          ) ; end and
    (raise-argument-error 'swisstable-map "(procedure-arity-includes/c 2)" proc
    ) ; end raise-argument-error
  ) ; end unless
  (swisstable-fold st
                   (lambda (k v acc) (cons (proc k v
                                           ) ; end proc
                                           acc
                                     ) ; end cons
                   ) ; end lambda
                   '(
                    ) ; end quote
  ) ; end swisstable-fold
) ; end define

(define (in-swisstable st
        ) ; end in-swisstable
  (make-do-sequence
   (lambda (
           ) ; end lambda args
     (values (lambda (i) (swisstable-iterate-key+value st i
                         ) ; end swisstable-iterate-key+value
             ) ; end lambda
             (lambda (i) (swisstable-iterate-next st i
                         ) ; end swisstable-iterate-next
             ) ; end lambda
             (swisstable-iterate-first st
             ) ; end swisstable-iterate-first
             (lambda (i) (and i #t
                         ) ; end and
             ) ; end lambda
             #f
             #f
     ) ; end values
   ) ; end lambda
  ) ; end make-do-sequence
) ; end define

(define (in-swisstable-keys st
        ) ; end in-swisstable-keys
  (make-do-sequence
   (lambda (
           ) ; end lambda args
     (values (lambda (i) (swisstable-iterate-key st i
                         ) ; end swisstable-iterate-key
             ) ; end lambda
             (lambda (i) (swisstable-iterate-next st i
                         ) ; end swisstable-iterate-next
             ) ; end lambda
             (swisstable-iterate-first st
             ) ; end swisstable-iterate-first
             (lambda (i) (and i #t
                         ) ; end and
             ) ; end lambda
             #f
             #f
     ) ; end values
   ) ; end lambda
  ) ; end make-do-sequence
) ; end define

(define (in-swisstable-values st
        ) ; end in-swisstable-values
  (make-do-sequence
   (lambda (
           ) ; end lambda args
     (values (lambda (i) (swisstable-iterate-value st i
                         ) ; end swisstable-iterate-value
             ) ; end lambda
             (lambda (i) (swisstable-iterate-next st i
                         ) ; end swisstable-iterate-next
             ) ; end lambda
             (swisstable-iterate-first st
             ) ; end swisstable-iterate-first
             (lambda (i) (and i #t
                         ) ; end and
             ) ; end lambda
             #f
             #f
     ) ; end values
   ) ; end lambda
  ) ; end make-do-sequence
) ; end define
