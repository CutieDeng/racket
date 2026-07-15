#lang racket/base

;; Pure-Racket fallback implementation of the SwissTable-style mutable
;; hash table.  Mirrors racket/src/cs/rumble/swisstable.ss: flat
;; control-byte string plus flat slot vector, 4-byte aligned groups,
;; triangular group probing, 7/8 load factor, tombstone reuse.  This
;; backend scans group bytes directly (no SWAR), so all arithmetic is
;; safe on every fixnum width.
;;
;; Control byte encoding: #xFF EMPTY, #x80 DELETED, #x00..#x7F = H2.
;;
;; Weakness: strong entries store key and value directly in the flat
;; slots.  Weak entries store a cell (vector weak-box-of-key value);
;; ephemeron entries store (vector weak-box-of-key ephemeron), where
;; the ephemeron maps the key to the value so key/value cycles can be
;; collected and values release promptly.  Dead entries are skipped
;; by comparison and reclaimed by sweeps; this backend favors
;; simplicity, so counting and iteration-start operations on weak
;; tables always sweep.
;;
;; Operations here are unchecked; racket/private/swisstable-runtime-adapter
;; performs argument checking before dispatching.

(require racket/fixnum
         (only-in racket/private/dict gen:dict
         ) ; end only-in
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
) ; end provide

(define GROUP-SIZE 4
) ; end define
(define CTRL-EMPTY #xFF
) ; end define
(define CTRL-DELETED #x80
) ; end define
(define MIN-CAPACITY 8
) ; end define

(define hole (gensym 'swisstable-hole
             ) ; end gensym
) ; end define
(define dead (gensym 'swisstable-dead
             ) ; end gensym
) ; end define

(struct swisstable ([ctrl #:mutable
                    ] ; end ctrl
                    [slots #:mutable
                    ] ; end slots
                    [cnt #:mutable
                    ] ; end cnt
                    [deleted #:mutable
                    ] ; end deleted
                    [capacity #:mutable
                    ] ; end capacity
                    kind
                    weakness
                   ) ; end fields
  #:authentic
  #:property prop:custom-write
  (lambda (st port mode
          ) ; end lambda args
    (fprintf port "#<swisstable:~a count=~a>"
             (swisstable-kind st
             ) ; end swisstable-kind
             (swisstable-count st
             ) ; end swisstable-count
    ) ; end fprintf
  ) ; end lambda
  #:property prop:sequence
  (lambda (st
          ) ; end lambda args
    (make-do-sequence
     (lambda (
             ) ; end lambda args
       (values (lambda (i) (swisstable-iterate-key+value st i dead
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
  ) ; end lambda
  #:property prop:equal+hash
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
                     (let ([k (swisstable-iterate-key a i dead
                              ) ; end swisstable-iterate-key
                           ] ; end k
                           [v (swisstable-iterate-value a i dead
                              ) ; end swisstable-iterate-value
                           ] ; end v
                          ) ; end let args
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
                     ) ; end let
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
                (loop (swisstable-iterate-next a i
                      ) ; end swisstable-iterate-next
                      (+ acc (bitwise-xor (* 3 (recur (swisstable-iterate-key a i dead
                                                      ) ; end swisstable-iterate-key
                                               ) ; end recur
                                          ) ; end *
                                          (recur (swisstable-iterate-value a i dead
                                                 ) ; end swisstable-iterate-value
                                          ) ; end recur
                             ) ; end bitwise-xor
                      ) ; end +
                ) ; end loop
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
                (loop (swisstable-iterate-next a i
                      ) ; end swisstable-iterate-next
                      (+ acc (recur (swisstable-iterate-key a i dead
                                    ) ; end swisstable-iterate-key
                             ) ; end recur
                             (* 5 (recur (swisstable-iterate-value a i dead
                                         ) ; end swisstable-iterate-value
                                  ) ; end recur
                             ) ; end *
                      ) ; end +
                ) ; end loop
                acc
            ) ; end if
          ) ; end let
        ) ; end lambda
  ) ; end list
  #:methods gen:dict
  [(define (dict-ref d k [failure (lambda (
                                          ) ; end lambda args
                                    (raise-arguments-error 'dict-ref
                                                           "no value found for key"
                                                           "key" k
                                    ) ; end raise-arguments-error
                                  ) ; end lambda
                          ] ; end failure
           ) ; end dict-ref
     (define v (swisstable-ref d k missing
               ) ; end swisstable-ref
     ) ; end define
     (cond
       [(not (eq? v missing)) v
       ] ; end clause
       [(and (procedure? failure
             ) ; end procedure?
             (procedure-arity-includes? failure 0
             ) ; end procedure-arity-includes?
        ) ; end and
        (failure
        ) ; end failure
       ] ; end clause
       [else failure
       ] ; end else
     ) ; end cond
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
     (define k (swisstable-iterate-key d i missing
               ) ; end swisstable-iterate-key
     ) ; end define
     (if (eq? k missing
         ) ; end eq?
         (raise-arguments-error 'dict-iterate-key "invalid position"
                                "position" i
         ) ; end raise-arguments-error
         k
     ) ; end if
   ) ; end define
   (define (dict-iterate-value d i
           ) ; end dict-iterate-value
     (define v (swisstable-iterate-value d i missing
               ) ; end swisstable-iterate-value
     ) ; end define
     (if (eq? v missing
         ) ; end eq?
         (raise-arguments-error 'dict-iterate-value "invalid position"
                                "position" i
         ) ; end raise-arguments-error
         v
     ) ; end if
   ) ; end define
  ] ; end methods
) ; end struct

(define (hash-code kind key
        ) ; end hash-code
  (case kind
    [(eq) (eq-hash-code key
          ) ; end eq-hash-code
    ] ; end clause
    [(eqv) (eqv-hash-code key
           ) ; end eqv-hash-code
    ] ; end clause
    [else (equal-hash-code key
          ) ; end equal-hash-code
    ] ; end else
  ) ; end case
) ; end define

(define (key=? kind a b
        ) ; end key=?
  (case kind
    [(eq) (eq? a b
          ) ; end eq?
    ] ; end clause
    [(eqv) (eqv? a b
           ) ; end eqv?
    ] ; end clause
    [else (equal? a b
          ) ; end equal?
    ] ; end else
  ) ; end case
) ; end define

;; Multiplicative mixer over 28 bits; all products stay below 2^29,
;; so this is fixnum-safe on every platform Racket supports.
(define (mix h0
        ) ; end mix
  (let* ([h (fxand h0 #xFFFFFFF)
         ] ; end h
         [h (fxxor h (fxrshift h 15
                     ) ; end fxrshift
            ) ; end fxxor
         ] ; end h
         [lo (fxand h #x3FFF)
         ] ; end lo
         [hi (fxrshift h 14
             ) ; end fxrshift
         ] ; end hi
         [h (fxxor (fx* lo 24593
                   ) ; end fx*
                   (fx* hi 12289
                   ) ; end fx*
            ) ; end fxxor
         ] ; end h
        ) ; end let* args
    (fxxor h (fxrshift h 9
             ) ; end fxrshift
    ) ; end fxxor
  ) ; end let*
) ; end define

;; --- weakness cells -------------------------------------------------
;; weak cell:      (vector weak-box value)
;; ephemeron cell: (vector weak-box ephemeron)

(define (weakness-code w
        ) ; end weakness-code
  (case w
    [(strong) 0
    ] ; end clause
    [(weak) 1
    ] ; end clause
    [else 2
    ] ; end else
  ) ; end case
) ; end define

(define (make-cell w key val
        ) ; end make-cell
  (if (eq? w 'weak
      ) ; end eq?
      (vector (make-weak-box key
              ) ; end make-weak-box
              val
      ) ; end vector
      (vector (make-weak-box key
              ) ; end make-weak-box
              (make-ephemeron key val
              ) ; end make-ephemeron
      ) ; end vector
  ) ; end if
) ; end define

;; Key of a cell, or the `dead` sentinel.
(define (cell-key cell
        ) ; end cell-key
  (if (vector? cell
      ) ; end vector?
      (weak-box-value (vector-ref cell 0
                      ) ; end vector-ref
                      dead
      ) ; end weak-box-value
      dead
  ) ; end if
) ; end define

(define (cell-dead? cell
        ) ; end cell-dead?
  (eq? (cell-key cell
       ) ; end cell-key
       dead
  ) ; end eq?
) ; end define

;; Value of a live cell, or `default` when the entry died.
(define (cell-value w cell default
        ) ; end cell-value
  (if (eq? w 'weak
      ) ; end eq?
      (vector-ref cell 1
      ) ; end vector-ref
      (let ([v (ephemeron-value (vector-ref cell 1
                                ) ; end vector-ref
                                dead
               ) ; end ephemeron-value
            ] ; end v
           ) ; end let args
        (if (eq? v dead
            ) ; end eq?
            default
            v
        ) ; end if
      ) ; end let
  ) ; end if
) ; end define

(define (cell-set-value! w cell key val
        ) ; end cell-set-value!
  (if (eq? w 'weak
      ) ; end eq?
      (vector-set! cell 1 val
      ) ; end vector-set!
      (vector-set! cell 1 (make-ephemeron key val
                          ) ; end make-ephemeron
      ) ; end vector-set!
  ) ; end if
) ; end define

;; Key of the (known-full) slot for comparison purposes: the slot
;; content itself for strong tables, the dereferenced cell key (or
;; the never-equal `dead` sentinel) otherwise.
(define (slot-key-for-compare w content
        ) ; end slot-key-for-compare
  (if (eq? w 'strong
      ) ; end eq?
      content
      (cell-key content
      ) ; end cell-key
  ) ; end if
) ; end define

;; ---------------------------------------------------------------------

(define (capacity-for-hint hint
        ) ; end capacity-for-hint
  (let loop ([cap MIN-CAPACITY
             ] ; end cap
            ) ; end loop args
    (if (fx> (fxlshift hint 3
             ) ; end fxlshift
             (fx* 7 cap
             ) ; end fx*
        ) ; end fx>
        (loop (fxlshift cap 1
              ) ; end fxlshift
        ) ; end loop
        cap
    ) ; end if
  ) ; end let
) ; end define

(define (make-ctrl cap
        ) ; end make-ctrl
  (make-bytes cap CTRL-EMPTY
  ) ; end make-bytes
) ; end define

(define (make-slots cap
        ) ; end make-slots
  (make-vector (fxlshift cap 1
               ) ; end fxlshift
               hole
  ) ; end make-vector
) ; end define

(define (make-swisstable kind weakness hint
        ) ; end make-swisstable
  (unless (memq kind '(eq eqv equal
                      ) ; end list
          ) ; end memq
    (raise-argument-error 'make-swisstable "(or/c 'eq 'eqv 'equal)" kind
    ) ; end raise-argument-error
  ) ; end unless
  (unless (memq weakness '(strong weak ephemeron
                          ) ; end list
          ) ; end memq
    (raise-argument-error 'make-swisstable "(or/c 'strong 'weak 'ephemeron)" weakness
    ) ; end raise-argument-error
  ) ; end unless
  (unless (and (fixnum? hint
               ) ; end fixnum?
               (fx>= hint 0
               ) ; end fx>=
          ) ; end and
    (raise-argument-error 'make-swisstable "exact-nonnegative-integer?" hint
    ) ; end raise-argument-error
  ) ; end unless
  (let ([cap (capacity-for-hint hint
             ) ; end capacity-for-hint
        ] ; end cap
       ) ; end let args
    (swisstable (make-ctrl cap
                ) ; end make-ctrl
                (make-slots cap
                ) ; end make-slots
                0
                0
                cap
                kind
                weakness
    ) ; end swisstable
  ) ; end let
) ; end define

;; Slot index of `key`, or -1 when absent.  Probes groups
;; triangularly; stops at the first group containing an EMPTY byte.
(define (locate st key
        ) ; end locate
  (define ctrl (swisstable-ctrl st
               ) ; end swisstable-ctrl
  ) ; end define
  (define slots (swisstable-slots st
                ) ; end swisstable-slots
  ) ; end define
  (define kind (swisstable-kind st
               ) ; end swisstable-kind
  ) ; end define
  (define w (swisstable-weakness st
            ) ; end swisstable-weakness
  ) ; end define
  (define gmask (fx- (fxrshift (swisstable-capacity st
                               ) ; end swisstable-capacity
                               2
                     ) ; end fxrshift
                     1
                ) ; end fx-
  ) ; end define
  (define h (mix (hash-code kind key
                 ) ; end hash-code
            ) ; end mix
  ) ; end define
  (define h2 (fxand h #x7F
             ) ; end fxand
  ) ; end define
  (let loop ([g (fxand (fxrshift h 7
                       ) ; end fxrshift
                       gmask
                ) ; end fxand
             ] ; end g
             [step 1
             ] ; end step
            ) ; end loop args
    (define base (fxlshift g 2
                 ) ; end fxlshift
    ) ; end define
    (let scan ([i 0] [saw-empty? #f
                     ] ; end saw-empty?
              ) ; end scan args
      (cond
        [(fx= i GROUP-SIZE
         ) ; end fx=
         (if saw-empty?
             -1
             (loop (fxand (fx+ g step
                          ) ; end fx+
                          gmask
                   ) ; end fxand
                   (fx+ step 1
                   ) ; end fx+
             ) ; end loop
         ) ; end if
        ] ; end clause
        [else
         (define idx (fx+ base i
                     ) ; end fx+
         ) ; end define
         (define b (bytes-ref ctrl idx
                   ) ; end bytes-ref
         ) ; end define
         (cond
           [(and (fx= b h2
                 ) ; end fx=
                 (let ([k (slot-key-for-compare w
                                                (vector-ref slots (fxlshift idx 1
                                                                  ) ; end fxlshift
                                                ) ; end vector-ref
                          ) ; end slot-key-for-compare
                       ] ; end k
                      ) ; end let args
                   (and (not (eq? k dead
                             ) ; end eq?
                        ) ; end not
                        (key=? kind k key
                        ) ; end key=?
                   ) ; end and
                 ) ; end let
            ) ; end and
            idx
           ] ; end clause
           [(fx= b CTRL-EMPTY
            ) ; end fx=
            (scan (fx+ i 1
                  ) ; end fx+
                  #t
            ) ; end scan
           ] ; end clause
           [else (scan (fx+ i 1
                       ) ; end fx+
                       saw-empty?
                 ) ; end scan
           ] ; end else
         ) ; end cond
        ] ; end else
      ) ; end cond
    ) ; end let
  ) ; end let
) ; end define

(define (insert-fresh! ctrl slots gmask key-slot val-slot h h2
        ) ; end insert-fresh!
  (let loop ([g (fxand (fxrshift h 7
                       ) ; end fxrshift
                       gmask
                ) ; end fxand
             ] ; end g
             [step 1
             ] ; end step
            ) ; end loop args
    (define base (fxlshift g 2
                 ) ; end fxlshift
    ) ; end define
    (let scan ([i 0
               ] ; end i
              ) ; end scan args
      (cond
        [(fx= i GROUP-SIZE
         ) ; end fx=
         (loop (fxand (fx+ g step
                      ) ; end fx+
                      gmask
               ) ; end fxand
               (fx+ step 1
               ) ; end fx+
         ) ; end loop
        ] ; end clause
        [(fx= (bytes-ref ctrl (fx+ base i
                              ) ; end fx+
              ) ; end bytes-ref
              CTRL-EMPTY
         ) ; end fx=
         (define idx (fx+ base i
                     ) ; end fx+
         ) ; end define
         (bytes-set! ctrl idx h2
         ) ; end bytes-set!
         (vector-set! slots (fxlshift idx 1
                            ) ; end fxlshift
                      key-slot
         ) ; end vector-set!
         (vector-set! slots (fx+ (fxlshift idx 1
                                 ) ; end fxlshift
                                 1
                      ) ; end fx+
                      val-slot
         ) ; end vector-set!
        ] ; end clause
        [else (scan (fx+ i 1
                    ) ; end fx+
              ) ; end scan
        ] ; end else
      ) ; end cond
    ) ; end let
  ) ; end let
) ; end define

;; Rebuild: grow when at least half full, otherwise purge tombstones
;; at the same capacity.  Weak tables also drop dead entries here.
(define (rehash! st
        ) ; end rehash!
  (define old-ctrl (swisstable-ctrl st
                   ) ; end swisstable-ctrl
  ) ; end define
  (define old-slots (swisstable-slots st
                    ) ; end swisstable-slots
  ) ; end define
  (define old-cap (swisstable-capacity st
                  ) ; end swisstable-capacity
  ) ; end define
  (define kind (swisstable-kind st
               ) ; end swisstable-kind
  ) ; end define
  (define w (swisstable-weakness st
            ) ; end swisstable-weakness
  ) ; end define
  (define new-cap (if (fx>= (fxlshift (swisstable-cnt st
                                      ) ; end swisstable-cnt
                                      1
                            ) ; end fxlshift
                            old-cap
                      ) ; end fx>=
                      (fxlshift old-cap 1
                      ) ; end fxlshift
                      old-cap
                  ) ; end if
  ) ; end define
  (define new-ctrl (make-ctrl new-cap
                   ) ; end make-ctrl
  ) ; end define
  (define new-slots (make-slots new-cap
                    ) ; end make-slots
  ) ; end define
  (define new-gmask (fx- (fxrshift new-cap 2
                         ) ; end fxrshift
                         1
                    ) ; end fx-
  ) ; end define
  (let loop ([i 0] [live 0
                   ] ; end live
            ) ; end loop args
    (cond
      [(fx= i old-cap
       ) ; end fx=
       (set-swisstable-cnt! st live
       ) ; end set-swisstable-cnt!
      ] ; end clause
      [(fx>= (bytes-ref old-ctrl i
             ) ; end bytes-ref
             #x80
       ) ; end fx>=
       (loop (fx+ i 1
             ) ; end fx+
             live
       ) ; end loop
      ] ; end clause
      [else
       (define content (vector-ref old-slots (fxlshift i 1
                                             ) ; end fxlshift
                       ) ; end vector-ref
       ) ; end define
       (define k (slot-key-for-compare w content
                 ) ; end slot-key-for-compare
       ) ; end define
       (cond
         [(eq? k dead
          ) ; end eq?
          (loop (fx+ i 1
                ) ; end fx+
                live
          ) ; end loop
         ] ; end clause
         [else
          (define h (mix (hash-code kind k
                         ) ; end hash-code
                    ) ; end mix
          ) ; end define
          (insert-fresh! new-ctrl new-slots new-gmask
                         content
                         (vector-ref old-slots (fx+ (fxlshift i 1
                                                    ) ; end fxlshift
                                                    1
                                               ) ; end fx+
                         ) ; end vector-ref
                         h
                         (fxand h #x7F
                         ) ; end fxand
          ) ; end insert-fresh!
          (loop (fx+ i 1
                ) ; end fx+
                (fx+ live 1
                ) ; end fx+
          ) ; end loop
         ] ; end else
       ) ; end cond
      ] ; end else
    ) ; end cond
  ) ; end let
  (set-swisstable-ctrl! st new-ctrl
  ) ; end set-swisstable-ctrl!
  (set-swisstable-slots! st new-slots
  ) ; end set-swisstable-slots!
  (set-swisstable-capacity! st new-cap
  ) ; end set-swisstable-capacity!
  (set-swisstable-deleted! st 0
  ) ; end set-swisstable-deleted!
) ; end define

;; Clear one full slot per the EMPTY-revert/tombstone rule; updates
;; `deleted` but not the count.
(define (clear-slot! st ctrl slots i
        ) ; end clear-slot!
  (define base (fxand i (fxnot 3
                        ) ; end fxnot
               ) ; end fxand
  ) ; end define
  (define group-has-empty?
    (let scan ([j 0
               ] ; end j
              ) ; end scan args
      (cond
        [(fx= j GROUP-SIZE) #f
        ] ; end clause
        [(fx= (bytes-ref ctrl (fx+ base j
                              ) ; end fx+
              ) ; end bytes-ref
              CTRL-EMPTY
         ) ; end fx=
         #t
        ] ; end clause
        [else (scan (fx+ j 1
                    ) ; end fx+
              ) ; end scan
        ] ; end else
      ) ; end cond
    ) ; end let
  ) ; end define
  (cond
    [group-has-empty?
     (bytes-set! ctrl i CTRL-EMPTY
     ) ; end bytes-set!
    ] ; end clause
    [else
     (bytes-set! ctrl i CTRL-DELETED
     ) ; end bytes-set!
     (set-swisstable-deleted! st (fx+ (swisstable-deleted st
                                      ) ; end swisstable-deleted
                                      1
                                 ) ; end fx+
     ) ; end set-swisstable-deleted!
    ] ; end else
  ) ; end cond
  (vector-set! slots (fxlshift i 1
                     ) ; end fxlshift
               hole
  ) ; end vector-set!
  (vector-set! slots (fx+ (fxlshift i 1
                          ) ; end fxlshift
                          1
               ) ; end fx+
               hole
  ) ; end vector-set!
) ; end define

;; Drop entries whose keys were collected; recomputes the count.
(define (sweep! st
        ) ; end sweep!
  (define ctrl (swisstable-ctrl st
               ) ; end swisstable-ctrl
  ) ; end define
  (define slots (swisstable-slots st
                ) ; end swisstable-slots
  ) ; end define
  (define cap (swisstable-capacity st
              ) ; end swisstable-capacity
  ) ; end define
  (let loop ([i 0] [live 0
                   ] ; end live
            ) ; end loop args
    (cond
      [(fx= i cap
       ) ; end fx=
       (set-swisstable-cnt! st live
       ) ; end set-swisstable-cnt!
      ] ; end clause
      [(fx>= (bytes-ref ctrl i
             ) ; end bytes-ref
             #x80
       ) ; end fx>=
       (loop (fx+ i 1
             ) ; end fx+
             live
       ) ; end loop
      ] ; end clause
      [(cell-dead? (vector-ref slots (fxlshift i 1
                                     ) ; end fxlshift
                   ) ; end vector-ref
       ) ; end cell-dead?
       (clear-slot! st ctrl slots i
       ) ; end clear-slot!
       (loop (fx+ i 1
             ) ; end fx+
             live
       ) ; end loop
      ] ; end clause
      [else (loop (fx+ i 1
                  ) ; end fx+
                  (fx+ live 1
                  ) ; end fx+
            ) ; end loop
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (maybe-sweep! st
        ) ; end maybe-sweep!
  (unless (eq? (swisstable-weakness st
               ) ; end swisstable-weakness
               'strong
          ) ; end eq?
    (sweep! st
    ) ; end sweep!
  ) ; end unless
) ; end define

(define (swisstable-set! st key val
        ) ; end swisstable-set!
  (define kind (swisstable-kind st
               ) ; end swisstable-kind
  ) ; end define
  (define w (swisstable-weakness st
            ) ; end swisstable-weakness
  ) ; end define
  (define h (mix (hash-code kind key
                 ) ; end hash-code
            ) ; end mix
  ) ; end define
  (define i (locate st key
            ) ; end locate
  ) ; end define
  (cond
    [(fx>= i 0
     ) ; end fx>=
     (if (eq? w 'strong
         ) ; end eq?
         (vector-set! (swisstable-slots st
                      ) ; end swisstable-slots
                      (fx+ (fxlshift i 1
                           ) ; end fxlshift
                           1
                      ) ; end fx+
                      val
         ) ; end vector-set!
         (cell-set-value! w
                          (vector-ref (swisstable-slots st
                                      ) ; end swisstable-slots
                                      (fxlshift i 1
                                      ) ; end fxlshift
                          ) ; end vector-ref
                          key
                          val
         ) ; end cell-set-value!
     ) ; end if
    ] ; end clause
    [else
     (let retry (
                ) ; end retry args
       (define ctrl (swisstable-ctrl st
                    ) ; end swisstable-ctrl
       ) ; end define
       (define slots (swisstable-slots st
                     ) ; end swisstable-slots
       ) ; end define
       (define cap (swisstable-capacity st
                   ) ; end swisstable-capacity
       ) ; end define
       (define gmask (fx- (fxrshift cap 2
                          ) ; end fxrshift
                          1
                     ) ; end fx-
       ) ; end define
       (define h2 (fxand h #x7F
                  ) ; end fxand
       ) ; end define
       (define (place! idx reuse-tomb?
               ) ; end place!
         (bytes-set! ctrl idx h2
         ) ; end bytes-set!
         (if (eq? w 'strong
             ) ; end eq?
             (begin
               (vector-set! slots (fxlshift idx 1
                                  ) ; end fxlshift
                            key
               ) ; end vector-set!
               (vector-set! slots (fx+ (fxlshift idx 1
                                       ) ; end fxlshift
                                       1
                            ) ; end fx+
                            val
               ) ; end vector-set!
             ) ; end begin
             (vector-set! slots (fxlshift idx 1
                                ) ; end fxlshift
                          (make-cell w key val
                          ) ; end make-cell
             ) ; end vector-set!
         ) ; end if
         (set-swisstable-cnt! st (fx+ (swisstable-cnt st
                                      ) ; end swisstable-cnt
                                      1
                                 ) ; end fx+
         ) ; end set-swisstable-cnt!
         (when reuse-tomb?
           (set-swisstable-deleted! st (fx- (swisstable-deleted st
                                            ) ; end swisstable-deleted
                                            1
                                       ) ; end fx-
           ) ; end set-swisstable-deleted!
         ) ; end when
       ) ; end define
       ;; find first tombstone in probe order, else first empty of
       ;; the terminating group
       (let loop ([g (fxand (fxrshift h 7
                            ) ; end fxrshift
                            gmask
                     ) ; end fxand
                  ] ; end g
                  [step 1
                  ] ; end step
                  [tomb -1
                  ] ; end tomb
                 ) ; end loop args
         (define base (fxlshift g 2
                      ) ; end fxlshift
         ) ; end define
         (let scan ([j 0] [tomb tomb] [empty-i -1
                                      ] ; end empty-i
                   ) ; end scan args
           (cond
             [(fx= j GROUP-SIZE
              ) ; end fx=
              (cond
                [(fx< empty-i 0
                 ) ; end fx<
                 (loop (fxand (fx+ g step
                              ) ; end fx+
                              gmask
                       ) ; end fxand
                       (fx+ step 1
                       ) ; end fx+
                       tomb
                 ) ; end loop
                ] ; end clause
                [(fx>= tomb 0
                 ) ; end fx>=
                 (place! tomb #t
                 ) ; end place!
                ] ; end clause
                [(fx> (fxlshift (fx+ (swisstable-cnt st
                                     ) ; end swisstable-cnt
                                     (swisstable-deleted st
                                     ) ; end swisstable-deleted
                                     1
                                ) ; end fx+
                                3
                      ) ; end fxlshift
                      (fx* 7 cap
                      ) ; end fx*
                 ) ; end fx>
                 (rehash! st
                 ) ; end rehash!
                 (retry
                 ) ; end retry
                ] ; end clause
                [else (place! empty-i #f
                      ) ; end place!
                ] ; end else
              ) ; end cond
             ] ; end clause
             [else
              (define b (bytes-ref ctrl (fx+ base j
                                        ) ; end fx+
                        ) ; end bytes-ref
              ) ; end define
              (cond
                [(and (fx= b CTRL-DELETED
                      ) ; end fx=
                      (fx< tomb 0
                      ) ; end fx<
                 ) ; end and
                 (scan (fx+ j 1
                       ) ; end fx+
                       (fx+ base j
                       ) ; end fx+
                       empty-i
                 ) ; end scan
                ] ; end clause
                [(and (fx= b CTRL-EMPTY
                      ) ; end fx=
                      (fx< empty-i 0
                      ) ; end fx<
                 ) ; end and
                 (scan (fx+ j 1
                       ) ; end fx+
                       tomb
                       (fx+ base j
                       ) ; end fx+
                 ) ; end scan
                ] ; end clause
                [else (scan (fx+ j 1
                            ) ; end fx+
                            tomb
                            empty-i
                      ) ; end scan
                ] ; end else
              ) ; end cond
             ] ; end else
           ) ; end cond
         ) ; end let
       ) ; end let
     ) ; end let
    ] ; end else
  ) ; end cond
  (void
  ) ; end void
) ; end define

(define missing (gensym 'missing
                ) ; end gensym
) ; end define

(define (swisstable-ref st key default
        ) ; end swisstable-ref
  (define i (locate st key
            ) ; end locate
  ) ; end define
  (cond
    [(fx< i 0) default
    ] ; end clause
    [(eq? (swisstable-weakness st
          ) ; end swisstable-weakness
          'strong
     ) ; end eq?
     (vector-ref (swisstable-slots st
                 ) ; end swisstable-slots
                 (fx+ (fxlshift i 1
                      ) ; end fxlshift
                      1
                 ) ; end fx+
     ) ; end vector-ref
    ] ; end clause
    [else (cell-value (swisstable-weakness st
                      ) ; end swisstable-weakness
                      (vector-ref (swisstable-slots st
                                  ) ; end swisstable-slots
                                  (fxlshift i 1
                                  ) ; end fxlshift
                      ) ; end vector-ref
                      default
          ) ; end cell-value
    ] ; end else
  ) ; end cond
) ; end define

(define (swisstable-has-key? st key
        ) ; end swisstable-has-key?
  (fx>= (locate st key
        ) ; end locate
        0
  ) ; end fx>=
) ; end define

(define (swisstable-remove! st key
        ) ; end swisstable-remove!
  (define i (locate st key
            ) ; end locate
  ) ; end define
  (cond
    [(fx< i 0
     ) ; end fx<
     #f
    ] ; end clause
    [else
     (clear-slot! st
                  (swisstable-ctrl st
                  ) ; end swisstable-ctrl
                  (swisstable-slots st
                  ) ; end swisstable-slots
                  i
     ) ; end clear-slot!
     (set-swisstable-cnt! st (fx- (swisstable-cnt st
                                  ) ; end swisstable-cnt
                                  1
                             ) ; end fx-
     ) ; end set-swisstable-cnt!
     #t
    ] ; end else
  ) ; end cond
) ; end define

(define (swisstable-clear! st
        ) ; end swisstable-clear!
  (bytes-fill! (swisstable-ctrl st
               ) ; end swisstable-ctrl
               CTRL-EMPTY
  ) ; end bytes-fill!
  (vector-fill! (swisstable-slots st
                ) ; end swisstable-slots
                hole
  ) ; end vector-fill!
  (set-swisstable-cnt! st 0
  ) ; end set-swisstable-cnt!
  (set-swisstable-deleted! st 0
  ) ; end set-swisstable-deleted!
  (void
  ) ; end void
) ; end define

(define (swisstable-count st
        ) ; end swisstable-count
  (maybe-sweep! st
  ) ; end maybe-sweep!
  (swisstable-cnt st
  ) ; end swisstable-cnt
) ; end define

(define (swisstable-stats st
        ) ; end swisstable-stats
  (maybe-sweep! st
  ) ; end maybe-sweep!
  (vector (swisstable-kind st
          ) ; end swisstable-kind
          (swisstable-capacity st
          ) ; end swisstable-capacity
          (swisstable-cnt st
          ) ; end swisstable-cnt
          (swisstable-deleted st
          ) ; end swisstable-deleted
          (swisstable-weakness st
          ) ; end swisstable-weakness
  ) ; end vector
) ; end define

(define (live-index? st i
        ) ; end live-index?
  (or (eq? (swisstable-weakness st
           ) ; end swisstable-weakness
           'strong
      ) ; end eq?
      (not (cell-dead? (vector-ref (swisstable-slots st
                                   ) ; end swisstable-slots
                                   (fxlshift i 1
                                   ) ; end fxlshift
                       ) ; end vector-ref
           ) ; end cell-dead?
      ) ; end not
  ) ; end or
) ; end define

(define (next-full st i
        ) ; end next-full
  (define ctrl (swisstable-ctrl st
               ) ; end swisstable-ctrl
  ) ; end define
  (define cap (swisstable-capacity st
              ) ; end swisstable-capacity
  ) ; end define
  (let loop ([i i
             ] ; end i
            ) ; end loop args
    (cond
      [(fx>= i cap) #f
      ] ; end clause
      [(and (fx< (bytes-ref ctrl i
                 ) ; end bytes-ref
                 #x80
            ) ; end fx<
            (live-index? st i
            ) ; end live-index?
       ) ; end and
       i
      ] ; end clause
      [else (loop (fx+ i 1
                  ) ; end fx+
            ) ; end loop
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (swisstable-iterate-first st
        ) ; end swisstable-iterate-first
  (maybe-sweep! st
  ) ; end maybe-sweep!
  (next-full st 0
  ) ; end next-full
) ; end define

(define (swisstable-iterate-next st i
        ) ; end swisstable-iterate-next
  (next-full st (fx+ i 1
                ) ; end fx+
  ) ; end next-full
) ; end define

(define (valid-index? st i
        ) ; end valid-index?
  (and (fixnum? i
       ) ; end fixnum?
       (fx>= i 0
       ) ; end fx>=
       (fx< i (swisstable-capacity st
              ) ; end swisstable-capacity
       ) ; end fx<
       (fx< (bytes-ref (swisstable-ctrl st
                       ) ; end swisstable-ctrl
                       i
            ) ; end bytes-ref
            #x80
       ) ; end fx<
       (live-index? st i
       ) ; end live-index?
  ) ; end and
) ; end define

(define (slot-key st i
        ) ; end slot-key
  (define content (vector-ref (swisstable-slots st
                              ) ; end swisstable-slots
                              (fxlshift i 1
                              ) ; end fxlshift
                  ) ; end vector-ref
  ) ; end define
  (if (eq? (swisstable-weakness st
           ) ; end swisstable-weakness
           'strong
      ) ; end eq?
      content
      (cell-key content
      ) ; end cell-key
  ) ; end if
) ; end define

(define (swisstable-iterate-key st i fail
        ) ; end swisstable-iterate-key
  (if (valid-index? st i
      ) ; end valid-index?
      (let ([k (slot-key st i
               ) ; end slot-key
            ] ; end k
           ) ; end let args
        (if (eq? k dead
            ) ; end eq?
            fail
            k
        ) ; end if
      ) ; end let
      fail
  ) ; end if
) ; end define

(define (swisstable-iterate-value st i fail
        ) ; end swisstable-iterate-value
  (cond
    [(not (valid-index? st i
          ) ; end valid-index?
     ) ; end not
     fail
    ] ; end clause
    [(eq? (swisstable-weakness st
          ) ; end swisstable-weakness
          'strong
     ) ; end eq?
     (vector-ref (swisstable-slots st
                 ) ; end swisstable-slots
                 (fx+ (fxlshift i 1
                      ) ; end fxlshift
                      1
                 ) ; end fx+
     ) ; end vector-ref
    ] ; end clause
    [else (cell-value (swisstable-weakness st
                      ) ; end swisstable-weakness
                      (vector-ref (swisstable-slots st
                                  ) ; end swisstable-slots
                                  (fxlshift i 1
                                  ) ; end fxlshift
                      ) ; end vector-ref
                      fail
          ) ; end cell-value
    ] ; end else
  ) ; end cond
) ; end define

(define (swisstable-iterate-key+value st i fail
        ) ; end swisstable-iterate-key+value
  (cond
    [(not (valid-index? st i
          ) ; end valid-index?
     ) ; end not
     (values fail fail
     ) ; end values
    ] ; end clause
    [else
     (define k (swisstable-iterate-key st i fail
               ) ; end swisstable-iterate-key
     ) ; end define
     (define v (swisstable-iterate-value st i fail
               ) ; end swisstable-iterate-value
     ) ; end define
     (if (or (eq? k fail
             ) ; end eq?
             (eq? v fail
             ) ; end eq?
         ) ; end or
         (values fail fail
         ) ; end values
         (values k v
         ) ; end values
     ) ; end if
    ] ; end else
  ) ; end cond
) ; end define
