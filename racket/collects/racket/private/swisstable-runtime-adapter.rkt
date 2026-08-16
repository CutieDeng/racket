#lang racket/base

;; Dual-backend dispatch for the SwissTable mutable hash table: uses
;; the Chez-level core primitives (core-swisstable-*) when the running
;; runtime provides them, and otherwise falls back to the pure-Racket
;; implementation in "swisstable.rkt".
;;
;; The backend is selected once at module load: every exported
;; procedure is bound directly to the core primitive (which performs
;; its own argument checking) or to a checking wrapper over the
;; fallback, so no per-call backend test remains on hot paths.

(require (prefix-in fallback: "swisstable.rkt"
         ) ; end prefix-in
) ; end require

(provide make-swisstable
         swisstable?
         swisstable-kind
         swisstable-weakness
         swisstable-count
         swisstable-ref
         swisstable-has-key?
         swisstable-set!
         swisstable-remove!
         swisstable-clear!
         swisstable-stats
         swisstable-iterate-first
         swisstable-iterate-next
         swisstable-iterate-key
         swisstable-iterate-value
         swisstable-iterate-key+value
         swisstable-runtime-adapter-backend
         swisstable-runtime-adapter-core-available?
         swisstable-install-struct-property!
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

(define core-swisstable? (maybe-kernel 'core-swisstable?
                         ) ; end maybe-kernel
) ; end define
(define core-make-swisstable (maybe-kernel 'core-make-swisstable
                             ) ; end maybe-kernel
) ; end define
(define core-swisstable-kind (maybe-kernel 'core-swisstable-kind
                             ) ; end maybe-kernel
) ; end define
(define core-swisstable-weakness (maybe-kernel 'core-swisstable-weakness
                                 ) ; end maybe-kernel
) ; end define
(define core-swisstable-count (maybe-kernel 'core-swisstable-count
                              ) ; end maybe-kernel
) ; end define
(define core-swisstable-ref (maybe-kernel 'core-swisstable-ref
                            ) ; end maybe-kernel
) ; end define
(define core-swisstable-has-key? (maybe-kernel 'core-swisstable-has-key?
                                 ) ; end maybe-kernel
) ; end define
(define core-swisstable-set! (maybe-kernel 'core-swisstable-set!
                             ) ; end maybe-kernel
) ; end define
(define core-swisstable-remove! (maybe-kernel 'core-swisstable-remove!
                                ) ; end maybe-kernel
) ; end define
(define core-swisstable-clear! (maybe-kernel 'core-swisstable-clear!
                               ) ; end maybe-kernel
) ; end define
(define core-swisstable-stats (maybe-kernel 'core-swisstable-stats
                              ) ; end maybe-kernel
) ; end define
(define core-swisstable-iterate-first (maybe-kernel 'core-swisstable-iterate-first
                                      ) ; end maybe-kernel
) ; end define
(define core-swisstable-iterate-next (maybe-kernel 'core-swisstable-iterate-next
                                     ) ; end maybe-kernel
) ; end define
(define core-swisstable-iterate-key (maybe-kernel 'core-swisstable-iterate-key
                                    ) ; end maybe-kernel
) ; end define
(define core-swisstable-iterate-value (maybe-kernel 'core-swisstable-iterate-value
                                      ) ; end maybe-kernel
) ; end define
(define core-swisstable-iterate-key+value (maybe-kernel 'core-swisstable-iterate-key+value
                                          ) ; end maybe-kernel
) ; end define
(define core-swisstable-install-struct-property!
  (maybe-kernel 'core-swisstable-install-struct-property!
  ) ; end maybe-kernel
) ; end define

(define core-bindings
  (list core-swisstable?
        core-make-swisstable
        core-swisstable-kind
        core-swisstable-weakness
        core-swisstable-count
        core-swisstable-ref
        core-swisstable-has-key?
        core-swisstable-set!
        core-swisstable-remove!
        core-swisstable-clear!
        core-swisstable-stats
        core-swisstable-iterate-first
        core-swisstable-iterate-next
        core-swisstable-iterate-key
        core-swisstable-iterate-value
        core-swisstable-iterate-key+value
  ) ; end list
) ; end define

(define core-available?
  (and (andmap procedure? core-bindings
       ) ; end andmap
       (with-handlers ([exn:fail? (lambda (_) #f
                                  ) ; end lambda
                       ] ; end exn:fail?
                      ) ; end form
         (define st (core-make-swisstable 'eq 'strong 0
                    ) ; end core-make-swisstable
         ) ; end define
         (core-swisstable-set! st 1 'one
         ) ; end core-swisstable-set!
         (core-swisstable-set! st 2 'two
         ) ; end core-swisstable-set!
         (and (core-swisstable? st
              ) ; end core-swisstable?
              (eq? 'one (core-swisstable-ref st 1 #f
                        ) ; end core-swisstable-ref
              ) ; end eq?
              (core-swisstable-remove! st 1
              ) ; end core-swisstable-remove!
              (= 1 (core-swisstable-count st
                   ) ; end core-swisstable-count
              ) ; end =
              (not (core-swisstable-ref st 1 #f
                   ) ; end core-swisstable-ref
              ) ; end not
         ) ; end and
       ) ; end with-handlers
  ) ; end and
) ; end define

(define (swisstable-runtime-adapter-backend
        ) ; end swisstable-runtime-adapter-backend
  (if core-available? 'cs-core 'racket
  ) ; end if
) ; end define

;; Attach a struct property to the core record type; the fallback
;; struct declares its properties statically, so this is a no-op on
;; the pure-Racket backend.
(define (swisstable-install-struct-property! prop value
        ) ; end swisstable-install-struct-property!
  (when (and core-available?
             (procedure? core-swisstable-install-struct-property!
             ) ; end procedure?
        ) ; end and
    (core-swisstable-install-struct-property! prop value
    ) ; end core-swisstable-install-struct-property!
  ) ; end when
  (void
  ) ; end void
) ; end define

(define (swisstable-runtime-adapter-core-available?
        ) ; end swisstable-runtime-adapter-core-avail...
  core-available?
) ; end define

;; fallback-side checking wrappers (the fallback implementation is
;; unchecked); the core side checks inside the primitives

(define swisstable?
  (if core-available?
      core-swisstable?
      fallback:swisstable?
  ) ; end if
) ; end define

(define (check-swisstable who st
        ) ; end check-swisstable
  (unless (swisstable? st
          ) ; end swisstable?
    (raise-argument-error who "swisstable?" st
    ) ; end raise-argument-error
  ) ; end unless
) ; end define

(define (check-index who i
        ) ; end check-index
  (unless (exact-nonnegative-integer? i
          ) ; end exact-nonnegative-integer?
    (raise-argument-error who "exact-nonnegative-integer?" i
    ) ; end raise-argument-error
  ) ; end unless
) ; end define

(define make-swisstable
  (if core-available?
      (lambda (kind weakness [hint 0
                             ] ; end hint
              ) ; end lambda args
        (core-make-swisstable kind weakness hint
        ) ; end core-make-swisstable
      ) ; end lambda
      (lambda (kind weakness [hint 0
                             ] ; end hint
              ) ; end lambda args
        (fallback:make-swisstable kind weakness hint
        ) ; end fallback:make-swisstable
      ) ; end lambda
  ) ; end if
) ; end define

(define swisstable-kind
  (if core-available?
      core-swisstable-kind
      (lambda (st
              ) ; end lambda args
        (check-swisstable 'swisstable-kind st
        ) ; end check-swisstable
        (fallback:swisstable-kind st
        ) ; end fallback:swisstable-kind
      ) ; end lambda
  ) ; end if
) ; end define

(define swisstable-weakness
  (if core-available?
      core-swisstable-weakness
      (lambda (st
              ) ; end lambda args
        (check-swisstable 'swisstable-weakness st
        ) ; end check-swisstable
        (fallback:swisstable-weakness st
        ) ; end fallback:swisstable-weakness
      ) ; end lambda
  ) ; end if
) ; end define

(define swisstable-count
  (if core-available?
      core-swisstable-count
      (lambda (st
              ) ; end lambda args
        (check-swisstable 'swisstable-count st
        ) ; end check-swisstable
        (fallback:swisstable-count st
        ) ; end fallback:swisstable-count
      ) ; end lambda
  ) ; end if
) ; end define

(define (ref-result v key default
        ) ; end ref-result
  (cond
    [(not (eq? v missing-default)) v
    ] ; end clause
    [(eq? default missing-default
     ) ; end eq?
     (raise-arguments-error 'swisstable-ref "no value found for key"
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

(define swisstable-ref
  (if core-available?
      (case-lambda
        [(st key
         ) ; end args
         (let ([v (core-swisstable-ref st key missing-default
                  ) ; end core-swisstable-ref
               ] ; end v
              ) ; end let args
           (if (eq? v missing-default
               ) ; end eq?
               (raise-arguments-error 'swisstable-ref "no value found for key"
                                      "key" key
               ) ; end raise-arguments-error
               v
           ) ; end if
         ) ; end let
        ] ; end clause
        [(st key default
         ) ; end args
         (let ([v (core-swisstable-ref st key missing-default
                  ) ; end core-swisstable-ref
               ] ; end v
              ) ; end let args
           (ref-result v key default
           ) ; end ref-result
         ) ; end let
        ] ; end clause
      ) ; end case-lambda
      (case-lambda
        [(st key
         ) ; end args
         (check-swisstable 'swisstable-ref st
         ) ; end check-swisstable
         (ref-result (fallback:swisstable-ref st key missing-default
                     ) ; end fallback:swisstable-ref
                     key
                     missing-default
         ) ; end ref-result
        ] ; end clause
        [(st key default
         ) ; end args
         (check-swisstable 'swisstable-ref st
         ) ; end check-swisstable
         (ref-result (fallback:swisstable-ref st key missing-default
                     ) ; end fallback:swisstable-ref
                     key
                     default
         ) ; end ref-result
        ] ; end clause
      ) ; end case-lambda
  ) ; end if
) ; end define

(define swisstable-has-key?
  (if core-available?
      core-swisstable-has-key?
      (lambda (st key
              ) ; end lambda args
        (check-swisstable 'swisstable-has-key? st
        ) ; end check-swisstable
        (fallback:swisstable-has-key? st key
        ) ; end fallback:swisstable-has-key?
      ) ; end lambda
  ) ; end if
) ; end define

(define swisstable-set!
  (if core-available?
      core-swisstable-set!
      (lambda (st key val
              ) ; end lambda args
        (check-swisstable 'swisstable-set! st
        ) ; end check-swisstable
        (fallback:swisstable-set! st key val
        ) ; end fallback:swisstable-set!
      ) ; end lambda
  ) ; end if
) ; end define

(define swisstable-remove!
  (if core-available?
      core-swisstable-remove!
      (lambda (st key
              ) ; end lambda args
        (check-swisstable 'swisstable-remove! st
        ) ; end check-swisstable
        (fallback:swisstable-remove! st key
        ) ; end fallback:swisstable-remove!
      ) ; end lambda
  ) ; end if
) ; end define

(define swisstable-clear!
  (if core-available?
      core-swisstable-clear!
      (lambda (st
              ) ; end lambda args
        (check-swisstable 'swisstable-clear! st
        ) ; end check-swisstable
        (fallback:swisstable-clear! st
        ) ; end fallback:swisstable-clear!
      ) ; end lambda
  ) ; end if
) ; end define

(define swisstable-stats
  (if core-available?
      core-swisstable-stats
      (lambda (st
              ) ; end lambda args
        (check-swisstable 'swisstable-stats st
        ) ; end check-swisstable
        (fallback:swisstable-stats st
        ) ; end fallback:swisstable-stats
      ) ; end lambda
  ) ; end if
) ; end define

(define swisstable-iterate-first
  (if core-available?
      core-swisstable-iterate-first
      (lambda (st
              ) ; end lambda args
        (check-swisstable 'swisstable-iterate-first st
        ) ; end check-swisstable
        (fallback:swisstable-iterate-first st
        ) ; end fallback:swisstable-iterate-first
      ) ; end lambda
  ) ; end if
) ; end define

(define swisstable-iterate-next
  (if core-available?
      (lambda (st i
              ) ; end lambda args
        (check-index 'swisstable-iterate-next i
        ) ; end check-index
        (if (fixnum? i
            ) ; end fixnum?
            (core-swisstable-iterate-next st i
            ) ; end core-swisstable-iterate-next
            (begin
              (core-swisstable-count st
              ) ; end core-swisstable-count
              #f
            ) ; end begin
        ) ; end if
      ) ; end lambda
      (lambda (st i
              ) ; end lambda args
        (check-swisstable 'swisstable-iterate-next st
        ) ; end check-swisstable
        (check-index 'swisstable-iterate-next i
        ) ; end check-index
        (if (fixnum? i
            ) ; end fixnum?
            (fallback:swisstable-iterate-next st i
            ) ; end fallback:swisstable-iterate-next
            #f
        ) ; end if
      ) ; end lambda
  ) ; end if
) ; end define

(define (bad-index who st i
        ) ; end bad-index
  (raise-arguments-error who "no element at index"
                         "index" i
                         "table" st
  ) ; end raise-arguments-error
) ; end define

(define swisstable-iterate-key
  (if core-available?
      (lambda (st i
              ) ; end lambda args
        (check-index 'swisstable-iterate-key i
        ) ; end check-index
        (let ([v (if (fixnum? i
                     ) ; end fixnum?
                     (core-swisstable-iterate-key st i missing-default
                     ) ; end core-swisstable-iterate-key
                     missing-default
                 ) ; end if
              ] ; end v
             ) ; end let args
          (if (eq? v missing-default
              ) ; end eq?
              (bad-index 'swisstable-iterate-key st i
              ) ; end bad-index
              v
          ) ; end if
        ) ; end let
      ) ; end lambda
      (lambda (st i
              ) ; end lambda args
        (check-swisstable 'swisstable-iterate-key st
        ) ; end check-swisstable
        (check-index 'swisstable-iterate-key i
        ) ; end check-index
        (let ([v (if (fixnum? i
                     ) ; end fixnum?
                     (fallback:swisstable-iterate-key st i missing-default
                     ) ; end fallback:swisstable-iterate-key
                     missing-default
                 ) ; end if
              ] ; end v
             ) ; end let args
          (if (eq? v missing-default
              ) ; end eq?
              (bad-index 'swisstable-iterate-key st i
              ) ; end bad-index
              v
          ) ; end if
        ) ; end let
      ) ; end lambda
  ) ; end if
) ; end define

(define swisstable-iterate-value
  (if core-available?
      (lambda (st i
              ) ; end lambda args
        (check-index 'swisstable-iterate-value i
        ) ; end check-index
        (let ([v (if (fixnum? i
                     ) ; end fixnum?
                     (core-swisstable-iterate-value st i missing-default
                     ) ; end core-swisstable-iterate-value
                     missing-default
                 ) ; end if
              ] ; end v
             ) ; end let args
          (if (eq? v missing-default
              ) ; end eq?
              (bad-index 'swisstable-iterate-value st i
              ) ; end bad-index
              v
          ) ; end if
        ) ; end let
      ) ; end lambda
      (lambda (st i
              ) ; end lambda args
        (check-swisstable 'swisstable-iterate-value st
        ) ; end check-swisstable
        (check-index 'swisstable-iterate-value i
        ) ; end check-index
        (let ([v (if (fixnum? i
                     ) ; end fixnum?
                     (fallback:swisstable-iterate-value st i missing-default
                     ) ; end fallback:swisstable-iterate-value
                     missing-default
                 ) ; end if
              ] ; end v
             ) ; end let args
          (if (eq? v missing-default
              ) ; end eq?
              (bad-index 'swisstable-iterate-value st i
              ) ; end bad-index
              v
          ) ; end if
        ) ; end let
      ) ; end lambda
  ) ; end if
) ; end define

(define swisstable-iterate-key+value
  (if core-available?
      (lambda (st i
              ) ; end lambda args
        (check-index 'swisstable-iterate-key+value i
        ) ; end check-index
        (unless (fixnum? i
                ) ; end fixnum?
          (bad-index 'swisstable-iterate-key+value st i
          ) ; end bad-index
        ) ; end unless
        (let-values ([(k v) (core-swisstable-iterate-key+value st i missing-default
                            ) ; end core-swisstable-iterate-key+value
                     ] ; end k v
                    ) ; end let-values args
          (if (eq? k missing-default
              ) ; end eq?
              (bad-index 'swisstable-iterate-key+value st i
              ) ; end bad-index
              (values k v
              ) ; end values
          ) ; end if
        ) ; end let-values
      ) ; end lambda
      (lambda (st i
              ) ; end lambda args
        (check-swisstable 'swisstable-iterate-key+value st
        ) ; end check-swisstable
        (check-index 'swisstable-iterate-key+value i
        ) ; end check-index
        (unless (fixnum? i
                ) ; end fixnum?
          (bad-index 'swisstable-iterate-key+value st i
          ) ; end bad-index
        ) ; end unless
        (let-values ([(k v) (fallback:swisstable-iterate-key+value st i missing-default
                            ) ; end fallback:swisstable-iterate-key+value
                     ] ; end k v
                    ) ; end let-values args
          (if (eq? k missing-default
              ) ; end eq?
              (bad-index 'swisstable-iterate-key+value st i
              ) ; end bad-index
              (values k v
              ) ; end values
          ) ; end if
        ) ; end let-values
      ) ; end lambda
  ) ; end if
) ; end define
