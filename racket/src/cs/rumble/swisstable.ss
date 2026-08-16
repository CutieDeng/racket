;; Mutable SwissTable-style hash table with strong, weak, and
;; ephemeron variants.
;;
;; Layout per design.md: a flat control-byte bytevector plus a flat
;; slot vector (key at 2i, value at 2i+1).  Groups are 16 bytes wide
;; and group-aligned; all control-byte scanning happens in kernel C
;; probe loops (ChezScheme/c/prim5.c) using SSE2/NEON group matching
;; with an exact bytewise fallback:
;;
;;   - eq tables (and fixnum/char keys of eqv tables, where eqv? is
;;     eq?) run the entire probe, including key comparison, in one C
;;     call;
;;   - equal tables and non-immediate eqv keys use the kind-agnostic
;;     C candidate iterator (swiss_scan) and apply equal?/eqv? here,
;;     so arbitrary Scheme comparison code never runs inside C; the
;;     scan's resume state is packed into a fixnum, which bounds the
;;     capacity to 2^28 slots (enforced below);
;;   - narrow-fixnum platforms (30-bit) cannot hold that state
;;     encoding, so they keep portable bytewise Scheme loops.
;;
;; Weakness (see swisstable-weak-design.md): a strong table stores
;; the key and value directly in the flat slots.  A weak or ephemeron
;; table stores one GC-managed cell per entry in the key slot --- a
;; weak pair (weak-cons key val) or an ephemeron pair
;; (ephemeron-cons key val) --- with the value in the cell's cdr and
;; the flat value slot unused.  The GC clears a dead entry by
;; rewriting the pair contents to #!bwp and never touches control
;; bytes, so the probe-termination invariant and the SIMD prefilter
;; are unaffected; dead entries look like candidates whose key
;; comparison fails.  Reclamation is lazy: a global GC epoch bumps in
;; the collect handler (rumble/memory.ss), and tables sweep when a
;; counting, iteration-starting, or mutating operation observes a
;; stale epoch.  Read operations never write, so concurrent reads
;; stay harmless.
;;
;; Control byte encoding (hashbrown encoding):
;;   #xFF        EMPTY
;;   #x80        DELETED (tombstone)
;;   #x00..#x7F  full slot storing H2 (low 7 bits of the mixed hash)
;;
;; Invariants:
;;   - capacity is a power of two, >= 16, a multiple of the group size
;;   - count + deleted <= capacity * 7/8 (load factor; for weak
;;     tables `count` may overcount until the next sweep, which only
;;     makes growth conservative)
;;   - group probing is triangular over group indexes, so every group
;;     is visited exactly once before the sequence repeats
;;   - removed/empty slots hold a private hole record, never user data,
;;     so the GC drops references promptly
;;
;; Tables are not safe for concurrent mutation from multiple Racket
;; threads, and mutating a table from within a user hash/equality
;; callback on the same table is unspecified (though memory-safe);
;; callers must serialize access themselves.

(define swisstable-group-size 16
) ; end define
(define swisstable-ctrl-empty #xFF
) ; end define
(define swisstable-ctrl-deleted #x80
) ; end define
(define swisstable-min-capacity 16
) ; end define
;; capacity bound imposed by the fixnum-packed scan state (g << 28)
(define swisstable-max-capacity (fxsll 1 28
                                ) ; end fxsll
) ; end define

;; Bumped by the collect handler in "rumble/memory.ss"; weak and
;; ephemeron tables compare their swept-epoch against this to decide
;; whether a sweep is due.
(define swisstable-gc-epoch 0
) ; end define

(define (swisstable-note-gc!
        ) ; end swisstable-note-gc!
  (set! swisstable-gc-epoch (fx1+ swisstable-gc-epoch
                            ) ; end fx1+
  ) ; end set!
) ; end define

(define-record-type swisstable-hole-record
  [fields
  ] ; end fields
  [nongenerative #{swisstable-hole-record cutie-swisstable-runtime-0}
  ] ; end nongenerative
  [sealed #t
  ] ; end sealed
  [opaque #t
  ] ; end opaque
) ; end define-record-type

(define swisstable-hole (make-swisstable-hole-record
                        ) ; end make-swisstable-hole-record
) ; end define

;; kind codes: 0 = eq, 1 = eqv, 2 = equal
;; weakness codes: 0 = strong, 1 = weak, 2 = ephemeron
(define-record-type core-swisstable
  [fields (mutable ctrl swisstable-ctrl swisstable-ctrl-set!
          ) ; end mutable
          (mutable slots swisstable-slots swisstable-slots-set!
          ) ; end mutable
          (mutable count swisstable-count swisstable-count-set!
          ) ; end mutable
          (mutable deleted swisstable-deleted swisstable-deleted-set!
          ) ; end mutable
          (mutable capacity swisstable-capacity swisstable-capacity-set!
          ) ; end mutable
          (immutable kind-code swisstable-kind-code
          ) ; end immutable
          (immutable weakness-code swisstable-weakness-code
          ) ; end immutable
          (mutable swept-epoch swisstable-swept-epoch swisstable-swept-epoch-set!
          ) ; end mutable
          ;; #f, or an eq-hashtable mapping stored keys to the pairs
          ;; of the current iteration snapshot (built-in mutable-hash
          ;; backend only); lets set!/remove! keep snapshot pairs
          ;; live-cell-accurate without rehashing any key
          (mutable snapshot swisstable-snapshot swisstable-snapshot-set!
          ) ; end mutable
  ] ; end fields
  [nongenerative #{core-swisstable cutie-swisstable-runtime-1}
  ] ; end nongenerative
  [sealed #t
  ] ; end sealed
) ; end define-record-type

;; Kernel C probe loops (ChezScheme/c/prim5.c).  They do group
;; scanning in one C call each: no allocation and no Scheme
;; callbacks, so the GC cannot move the arrays mid-probe.  The -ind
;; variants dereference the per-entry cell of weak/ephemeron tables
;; before comparing.
(define swisstable-c-ref-eq
  (foreign-procedure "(cs)swiss_ref_eq" (ptr ptr ptr uptr uptr ptr) ptr
  ) ; end foreign-procedure
) ; end define
(define swisstable-c-locate-eq
  (foreign-procedure "(cs)swiss_locate_eq" (ptr ptr ptr uptr uptr) iptr
  ) ; end foreign-procedure
) ; end define
(define swisstable-c-probe-eq
  (foreign-procedure "(cs)swiss_probe_eq" (ptr ptr ptr uptr uptr) iptr
  ) ; end foreign-procedure
) ; end define
(define swisstable-c-locate-eq-ind
  (foreign-procedure "(cs)swiss_locate_eq_ind" (ptr ptr ptr uptr uptr) iptr
  ) ; end foreign-procedure
) ; end define
(define swisstable-c-probe-eq-ind
  (foreign-procedure "(cs)swiss_probe_eq_ind" (ptr ptr ptr uptr uptr) iptr
  ) ; end foreign-procedure
) ; end define
(define swisstable-c-scan
  (foreign-procedure "(cs)swiss_scan" (ptr uptr uptr iptr) iptr
  ) ; end foreign-procedure
) ; end define
(define swisstable-c-find-slot
  (foreign-procedure "(cs)swiss_find_slot" (ptr uptr uptr) iptr
  ) ; end foreign-procedure
) ; end define

(define (core-check-swisstable who st
        ) ; end core-check-swisstable
  (unless (core-swisstable? st
          ) ; end core-swisstable?
    (raise-argument-error who "swisstable?" st
    ) ; end raise-argument-error
  ) ; end unless
) ; end define

(define swisstable-wide-fixnum? (fx>= (fixnum-width) 56
                                ) ; end fx>=
) ; end define

;; Hashing.  Racket hash codes are stable across GC (see design.md),
;; but they are not group-ready: the SwissTable split sends the low 7
;; bits to H2 and the next bits to the group index, so an
;; identity-style code (fixnums, the counter-based eq registry) would
;; cram 128 consecutive keys into one group.  A cheap multiplicative
;; mixer decorrelates the two.  The same mixed value feeds both the
;; Scheme paths and the kernel C probes, so all paths agree on
;; placement.  The eq/eqv registry is itself key-weak, so hashing
;; never retains a weak table's keys.  All arithmetic stays within
;; fixnum range; the wide path needs >= 56-bit fixnums, the narrow
;; path only 30-bit.  The inline fixnum tests below skip the
;; hash-code call on the hot fixnum path.

(define (swisstable-mix h0
        ) ; end swisstable-mix
  (if swisstable-wide-fixnum?
      (let* ([h (fxand h0 #x3FFFFFFFFFFF)
             ] ; end h
             [h (fxxor h (fxsrl h 23
                         ) ; end fxsrl
                ) ; end fxxor
             ] ; end h
             [lo (fxand h #x3FFFFFF)
             ] ; end lo
             [hi (fxsrl h 26
                 ) ; end fxsrl
             ] ; end hi
             [h (fxxor (fx* lo 99990001
                       ) ; end fx*
                       (fx* hi 67867967
                       ) ; end fx*
                ) ; end fxxor
             ] ; end h
            ) ; end let* args
        (fxxor h (fxsrl h 13
                 ) ; end fxsrl
        ) ; end fxxor
      ) ; end let*
      (let* ([h (fxand h0 #xFFFFFFF)
             ] ; end h
             [h (fxxor h (fxsrl h 15
                         ) ; end fxsrl
                ) ; end fxxor
             ] ; end h
             [lo (fxand h #x3FFF)
             ] ; end lo
             [hi (fxsrl h 14
                 ) ; end fxsrl
             ] ; end hi
             [h (fxxor (fx* lo 24593
                       ) ; end fx*
                       (fx* hi 12289
                       ) ; end fx*
                ) ; end fxxor
             ] ; end h
            ) ; end let* args
        (fxxor h (fxsrl h 9
                 ) ; end fxsrl
        ) ; end fxxor
      ) ; end let*
  ) ; end if
) ; end define

(define-syntax swisstable-eq-hash
  (syntax-rules (
                ) ; end literals
    [(_ key) (swisstable-mix (if (fixnum? key
                                 ) ; end fixnum?
                                 key
                                 (eq-hash-code key
                                 ) ; end eq-hash-code
                             ) ; end if
             ) ; end swisstable-mix
    ] ; end clause
  ) ; end syntax-rules
) ; end define-syntax

(define-syntax swisstable-eqv-hash
  (syntax-rules (
                ) ; end literals
    [(_ key) (swisstable-mix (if (fixnum? key
                                 ) ; end fixnum?
                                 key
                                 (eqv-hash-code key
                                 ) ; end eqv-hash-code
                             ) ; end if
             ) ; end swisstable-mix
    ] ; end clause
  ) ; end syntax-rules
) ; end define-syntax

(define-syntax swisstable-equal-hash
  (syntax-rules (
                ) ; end literals
    [(_ key) (swisstable-mix (equal-hash-code key
                             ) ; end equal-hash-code
             ) ; end swisstable-mix
    ] ; end clause
  ) ; end syntax-rules
) ; end define-syntax

;; Kinds 3 and 4 serve as the backend for Racket's built-in mutable
;; hash tables (rumble/hash.ss): they use the key-equal-* functions,
;; which honor the equality-wrap redirection that hash impersonators
;; install via continuation marks.
(define-syntax swisstable-keyequal-hash
  (syntax-rules (
                ) ; end literals
    [(_ key) (swisstable-mix (key-equal-hash-code key
                             ) ; end key-equal-hash-code
             ) ; end swisstable-mix
    ] ; end clause
  ) ; end syntax-rules
) ; end define-syntax

(define-syntax swisstable-keyalw-hash
  (syntax-rules (
                ) ; end literals
    [(_ key) (swisstable-mix (key-equal-always-hash-code key
                             ) ; end key-equal-always-hash-code
             ) ; end swisstable-mix
    ] ; end clause
  ) ; end syntax-rules
) ; end define-syntax

(define-syntax swisstable-keyequal-same?
  (syntax-rules (
                ) ; end literals
    [(_ a b) (key-equal? a b
             ) ; end key-equal?
    ] ; end clause
  ) ; end syntax-rules
) ; end define-syntax

(define-syntax swisstable-keyalw-same?
  (syntax-rules (
                ) ; end literals
    [(_ a b) (key-equal-always? a b
             ) ; end key-equal-always?
    ] ; end clause
  ) ; end syntax-rules
) ; end define-syntax

;; Comparison macros for the locate loops.  The plain variants
;; compare the slot content directly (strong tables); the -cell
;; variants dereference the weak/ephemeron pair, where a bwp'd car
;; fails the comparison and a hole record fails the pair check.
(define-syntax swisstable-eqv-same?
  (syntax-rules (
                ) ; end literals
    [(_ a b) (eqv? a b
             ) ; end eqv?
    ] ; end clause
  ) ; end syntax-rules
) ; end define-syntax

(define-syntax swisstable-equal-same?
  (syntax-rules (
                ) ; end literals
    [(_ a b) (equal? a b
             ) ; end equal?
    ] ; end clause
  ) ; end syntax-rules
) ; end define-syntax

(define-syntax swisstable-eqv-cell-same?
  (syntax-rules (
                ) ; end literals
    [(_ cell b) (and (pair? cell
                     ) ; end pair?
                     (eqv? (car cell
                           ) ; end car
                           b
                     ) ; end eqv?
                ) ; end and
    ] ; end clause
  ) ; end syntax-rules
) ; end define-syntax

(define-syntax swisstable-equal-cell-same?
  (syntax-rules (
                ) ; end literals
    [(_ cell b) (and (pair? cell
                     ) ; end pair?
                     (let ([k (car cell
                              ) ; end car
                           ] ; end k
                          ) ; end let args
                       (and (not (bwp-object? k
                                 ) ; end bwp-object?
                            ) ; end not
                            (equal? k b
                            ) ; end equal?
                       ) ; end and
                     ) ; end let
                ) ; end and
    ] ; end clause
  ) ; end syntax-rules
) ; end define-syntax

(define-syntax swisstable-keyequal-cell-same?
  (syntax-rules (
                ) ; end literals
    [(_ cell b) (and (pair? cell
                     ) ; end pair?
                     (let ([k (car cell
                              ) ; end car
                           ] ; end k
                          ) ; end let args
                       (and (not (bwp-object? k
                                 ) ; end bwp-object?
                            ) ; end not
                            (key-equal? k b
                            ) ; end key-equal?
                       ) ; end and
                     ) ; end let
                ) ; end and
    ] ; end clause
  ) ; end syntax-rules
) ; end define-syntax

(define-syntax swisstable-keyalw-cell-same?
  (syntax-rules (
                ) ; end literals
    [(_ cell b) (and (pair? cell
                     ) ; end pair?
                     (let ([k (car cell
                              ) ; end car
                           ] ; end k
                          ) ; end let args
                       (and (not (bwp-object? k
                                 ) ; end bwp-object?
                            ) ; end not
                            (key-equal-always? k b
                            ) ; end key-equal-always?
                       ) ; end and
                     ) ; end let
                ) ; end and
    ] ; end clause
  ) ; end syntax-rules
) ; end define-syntax

(define-syntax swisstable-eqv-immediate?
  (syntax-rules (
                ) ; end literals
    [(_ key) (or (fixnum? key
                 ) ; end fixnum?
                 (char? key
                 ) ; end char?
             ) ; end or
    ] ; end clause
  ) ; end syntax-rules
) ; end define-syntax

;; kind codes: 0 = eq, 1 = eqv, 2 = equal (plain), 3 = key-equal,
;; 4 = key-equal-always (3 and 4 are the built-in mutable-hash
;; backend kinds)
(define (swisstable-hash-for st key
        ) ; end swisstable-hash-for
  (let ([kind (swisstable-kind-code st
              ) ; end swisstable-kind-code
        ] ; end kind
       ) ; end let args
    (cond
      [(fx= kind 0) (swisstable-eq-hash key
                    ) ; end swisstable-eq-hash
      ] ; end clause
      [(fx= kind 1) (swisstable-eqv-hash key
                    ) ; end swisstable-eqv-hash
      ] ; end clause
      [(fx= kind 2) (swisstable-equal-hash key
                    ) ; end swisstable-equal-hash
      ] ; end clause
      [(fx= kind 3) (swisstable-keyequal-hash key
                    ) ; end swisstable-keyequal-hash
      ] ; end clause
      [else (swisstable-keyalw-hash key
            ) ; end swisstable-keyalw-hash
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

;; Fresh cell for a weak (code 1), ephemeron (code 2), or strong-cell
;; (code 3, the built-in mutable-hash backend) entry; the value lives
;; in the cdr in all cases.  Strong cells are ordinary pairs, so they
;; behave like Chez hashtable cells: set-cdr! updates the mapped
;; value through any iteration snapshot that holds the cell.
(define (swisstable-make-cell weakness key val
        ) ; end swisstable-make-cell
  (cond
    [(fx= weakness 1
     ) ; end fx=
     (weak-cons key val
     ) ; end weak-cons
    ] ; end clause
    [(fx= weakness 2
     ) ; end fx=
     (ephemeron-cons key val
     ) ; end ephemeron-cons
    ] ; end clause
    [else (cons key val
          ) ; end cons
    ] ; end else
  ) ; end cond
) ; end define

(define (swisstable-cell-dead? cell
        ) ; end swisstable-cell-dead?
  (or (not (pair? cell
           ) ; end pair?
      ) ; end not
      (bwp-object? (car cell
                   ) ; end car
      ) ; end bwp-object?
  ) ; end or
) ; end define

(define (swisstable-capacity-for-hint hint
        ) ; end swisstable-capacity-for-hint
  (let loop ([cap swisstable-min-capacity
             ] ; end cap
            ) ; end loop args
    (cond
      [(fx> (fxsll hint 3
            ) ; end fxsll
            (fx* 7 cap
            ) ; end fx*
       ) ; end fx>
       (when (fx>= cap swisstable-max-capacity
             ) ; end fx>=
         (raise-arguments-error 'make-swisstable "requested capacity is too large"
                                "expected-count" hint
         ) ; end raise-arguments-error
       ) ; end when
       (loop (fxsll cap 1
             ) ; end fxsll
       ) ; end loop
      ] ; end clause
      [else cap
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (swisstable-make-ctrl cap
        ) ; end swisstable-make-ctrl
  (make-bytevector cap swisstable-ctrl-empty
  ) ; end make-bytevector
) ; end define

(define (swisstable-make-slots cap
        ) ; end swisstable-make-slots
  (make-vector (fxsll cap 1
               ) ; end fxsll
               swisstable-hole
  ) ; end make-vector
) ; end define

(define (core-make-swisstable kind weakness hint
        ) ; end core-make-swisstable
  (let ([kind-code (case kind
                     [(eq) 0
                     ] ; end clause
                     [(eqv) 1
                     ] ; end clause
                     [(equal) 2
                     ] ; end clause
                     [else (raise-argument-error 'make-swisstable
                                                 "(or/c 'eq 'eqv 'equal)"
                                                 kind
                           ) ; end raise-argument-error
                     ] ; end else
                   ) ; end case
        ] ; end kind-code
        [weakness-code (case weakness
                         [(strong) 0
                         ] ; end clause
                         [(weak) 1
                         ] ; end clause
                         [(ephemeron) 2
                         ] ; end clause
                         [else (raise-argument-error 'make-swisstable
                                                     "(or/c 'strong 'weak 'ephemeron)"
                                                     weakness
                               ) ; end raise-argument-error
                         ] ; end else
                       ) ; end case
        ] ; end weakness-code
       ) ; end let args
    (unless (and (fixnum? hint
                 ) ; end fixnum?
                 (fx>= hint 0
                 ) ; end fx>=
            ) ; end and
      (raise-argument-error 'make-swisstable "exact-nonnegative-integer?" hint
      ) ; end raise-argument-error
    ) ; end unless
    (let ([cap (swisstable-capacity-for-hint hint
               ) ; end swisstable-capacity-for-hint
          ] ; end cap
         ) ; end let args
      (make-core-swisstable (swisstable-make-ctrl cap
                            ) ; end swisstable-make-ctrl
                            (swisstable-make-slots cap
                            ) ; end swisstable-make-slots
                            0
                            0
                            cap
                            kind-code
                            weakness-code
                            swisstable-gc-epoch
                            #f
      ) ; end make-core-swisstable
    ) ; end let
  ) ; end let
) ; end define

;; Locate via the C candidate iterator: C yields H2-matching slot
;; indexes in probe order, the comparison macro runs here.  The scan
;; state lives in locals, so a comparison callback that re-enters
;; this table cannot corrupt an ongoing scan.  Returns the slot
;; index, or -1 when absent.
(define-syntax swisstable-define-scan-locate
  (syntax-rules (
                ) ; end literals
    [(_ name key-same?
     ) ; end pattern
     (define (name st key h
             ) ; end name
       (let ([ctrl (swisstable-ctrl st
                   ) ; end swisstable-ctrl
             ] ; end ctrl
             [slots (swisstable-slots st
                    ) ; end swisstable-slots
             ] ; end slots
             [cap (swisstable-capacity st
                  ) ; end swisstable-capacity
             ] ; end cap
            ) ; end let args
         (let loop ([state -1
                    ] ; end state
                   ) ; end loop args
           (let ([r (swisstable-c-scan ctrl cap h state
                    ) ; end swisstable-c-scan
                 ] ; end r
                ) ; end let args
             (if (fx< r 0
                 ) ; end fx<
                 -1
                 (let ([i (fx+ (fxsll (fxsrl r 28
                                      ) ; end fxsrl
                                      4
                               ) ; end fxsll
                               (fxand r 15
                               ) ; end fxand
                          ) ; end fx+
                       ] ; end i
                      ) ; end let args
                   (if (key-same? (#3%vector-ref slots (fxsll i 1
                                                       ) ; end fxsll
                                  ) ; end vector-ref
                                  key
                       ) ; end key-same?
                       i
                       (loop r
                       ) ; end loop
                   ) ; end if
                 ) ; end let
             ) ; end if
           ) ; end let
         ) ; end let
       ) ; end let
     ) ; end define
    ] ; end clause
  ) ; end syntax-rules
) ; end define-syntax

(swisstable-define-scan-locate swisstable-scan-locate-eqv swisstable-eqv-same?
) ; end swisstable-define-scan-locate
(swisstable-define-scan-locate swisstable-scan-locate-equal swisstable-equal-same?
) ; end swisstable-define-scan-locate
(swisstable-define-scan-locate swisstable-scan-locate-eqv/cell swisstable-eqv-cell-same?
) ; end swisstable-define-scan-locate
(swisstable-define-scan-locate swisstable-scan-locate-equal/cell swisstable-equal-cell-same?
) ; end swisstable-define-scan-locate
(swisstable-define-scan-locate swisstable-scan-locate-keyequal swisstable-keyequal-same?
) ; end swisstable-define-scan-locate
(swisstable-define-scan-locate swisstable-scan-locate-keyalw swisstable-keyalw-same?
) ; end swisstable-define-scan-locate
(swisstable-define-scan-locate swisstable-scan-locate-keyequal/cell swisstable-keyequal-cell-same?
) ; end swisstable-define-scan-locate
(swisstable-define-scan-locate swisstable-scan-locate-keyalw/cell swisstable-keyalw-cell-same?
) ; end swisstable-define-scan-locate

;; Portable bytewise locate for narrow-fixnum platforms, where the
;; packed C scan state does not fit a fixnum.
(define-syntax swisstable-define-bytewise-locate
  (syntax-rules (
                ) ; end literals
    [(_ name key-same?
     ) ; end pattern
     (define (name st key h
             ) ; end name
       (let* ([ctrl (swisstable-ctrl st
                    ) ; end swisstable-ctrl
              ] ; end ctrl
              [slots (swisstable-slots st
                     ) ; end swisstable-slots
              ] ; end slots
              [gmask (fx- (fxsrl (swisstable-capacity st
                                 ) ; end swisstable-capacity
                                 4
                          ) ; end fxsrl
                          1
                     ) ; end fx-
              ] ; end gmask
              [h2 (fxand h #x7F)
              ] ; end h2
             ) ; end let* args
         (let loop ([g (fxand (fxsrl h 7
                              ) ; end fxsrl
                              gmask
                       ) ; end fxand
                    ] ; end g
                    [step 1
                    ] ; end step
                   ) ; end loop args
           (let ([base (fxsll g 4
                       ) ; end fxsll
                 ] ; end base
                ) ; end let args
             (let scan ([j 0] [saw-empty? #f
                              ] ; end saw-empty?
                       ) ; end scan args
               (cond
                 [(fx= j swisstable-group-size
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
                  (let* ([i (fx+ base j
                            ) ; end fx+
                         ] ; end i
                         [b (#3%bytevector-u8-ref ctrl i
                            ) ; end bytevector-u8-ref
                         ] ; end b
                        ) ; end let* args
                    (cond
                      [(and (fx= b h2
                            ) ; end fx=
                            (key-same? (#3%vector-ref slots (fxsll i 1
                                                            ) ; end fxsll
                                       ) ; end vector-ref
                                       key
                            ) ; end key-same?
                       ) ; end and
                       i
                      ] ; end clause
                      [(fx= b swisstable-ctrl-empty
                       ) ; end fx=
                       (scan (fx+ j 1
                             ) ; end fx+
                             #t
                       ) ; end scan
                      ] ; end clause
                      [else (scan (fx+ j 1
                                  ) ; end fx+
                                  saw-empty?
                            ) ; end scan
                      ] ; end else
                    ) ; end cond
                  ) ; end let*
                 ] ; end else
               ) ; end cond
             ) ; end let
           ) ; end let
         ) ; end let
       ) ; end let*
     ) ; end define
    ] ; end clause
  ) ; end syntax-rules
) ; end define-syntax

(swisstable-define-bytewise-locate swisstable-bytewise-locate-eqv swisstable-eqv-same?
) ; end swisstable-define-bytewise-locate
(swisstable-define-bytewise-locate swisstable-bytewise-locate-equal swisstable-equal-same?
) ; end swisstable-define-bytewise-locate
(swisstable-define-bytewise-locate swisstable-bytewise-locate-eqv/cell swisstable-eqv-cell-same?
) ; end swisstable-define-bytewise-locate
(swisstable-define-bytewise-locate swisstable-bytewise-locate-equal/cell swisstable-equal-cell-same?
) ; end swisstable-define-bytewise-locate
(swisstable-define-bytewise-locate swisstable-bytewise-locate-keyequal swisstable-keyequal-same?
) ; end swisstable-define-bytewise-locate
(swisstable-define-bytewise-locate swisstable-bytewise-locate-keyalw swisstable-keyalw-same?
) ; end swisstable-define-bytewise-locate
(swisstable-define-bytewise-locate swisstable-bytewise-locate-keyequal/cell swisstable-keyequal-cell-same?
) ; end swisstable-define-bytewise-locate
(swisstable-define-bytewise-locate swisstable-bytewise-locate-keyalw/cell swisstable-keyalw-cell-same?
) ; end swisstable-define-bytewise-locate

;; For eq keys (and eqv immediates) the pointer comparison happens
;; entirely in C: direct slots for strong tables, cell dereference
;; for weak/ephemeron tables.
(define (swisstable-locate-eq-like st key h
        ) ; end swisstable-locate-eq-like
  (if (fx= (swisstable-weakness-code st
           ) ; end swisstable-weakness-code
           0
      ) ; end fx=
      (swisstable-c-locate-eq (swisstable-ctrl st
                              ) ; end swisstable-ctrl
                              (swisstable-slots st
                              ) ; end swisstable-slots
                              key
                              h
                              (swisstable-capacity st
                              ) ; end swisstable-capacity
      ) ; end swisstable-c-locate-eq
      (swisstable-c-locate-eq-ind (swisstable-ctrl st
                                  ) ; end swisstable-ctrl
                                  (swisstable-slots st
                                  ) ; end swisstable-slots
                                  key
                                  h
                                  (swisstable-capacity st
                                  ) ; end swisstable-capacity
      ) ; end swisstable-c-locate-eq-ind
  ) ; end if
) ; end define

(define (swisstable-locate-eqv-slow st key h
        ) ; end swisstable-locate-eqv-slow
  (if (fx= (swisstable-weakness-code st
           ) ; end swisstable-weakness-code
           0
      ) ; end fx=
      (if swisstable-wide-fixnum?
          (swisstable-scan-locate-eqv st key h
          ) ; end swisstable-scan-locate-eqv
          (swisstable-bytewise-locate-eqv st key h
          ) ; end swisstable-bytewise-locate-eqv
      ) ; end if
      (if swisstable-wide-fixnum?
          (swisstable-scan-locate-eqv/cell st key h
          ) ; end swisstable-scan-locate-eqv/cell
          (swisstable-bytewise-locate-eqv/cell st key h
          ) ; end swisstable-bytewise-locate-eqv/cell
      ) ; end if
  ) ; end if
) ; end define

(define (swisstable-locate-equal-slow st key h
        ) ; end swisstable-locate-equal-slow
  (if (fx= (swisstable-weakness-code st
           ) ; end swisstable-weakness-code
           0
      ) ; end fx=
      (if swisstable-wide-fixnum?
          (swisstable-scan-locate-equal st key h
          ) ; end swisstable-scan-locate-equal
          (swisstable-bytewise-locate-equal st key h
          ) ; end swisstable-bytewise-locate-equal
      ) ; end if
      (if swisstable-wide-fixnum?
          (swisstable-scan-locate-equal/cell st key h
          ) ; end swisstable-scan-locate-equal/cell
          (swisstable-bytewise-locate-equal/cell st key h
          ) ; end swisstable-bytewise-locate-equal/cell
      ) ; end if
  ) ; end if
) ; end define

(define (swisstable-locate-keyequal-slow st key h
        ) ; end swisstable-locate-keyequal-slow
  (if (fx= (swisstable-weakness-code st
           ) ; end swisstable-weakness-code
           0
      ) ; end fx=
      (if swisstable-wide-fixnum?
          (swisstable-scan-locate-keyequal st key h
          ) ; end swisstable-scan-locate-keyequal
          (swisstable-bytewise-locate-keyequal st key h
          ) ; end swisstable-bytewise-locate-keyequal
      ) ; end if
      (if swisstable-wide-fixnum?
          (swisstable-scan-locate-keyequal/cell st key h
          ) ; end swisstable-scan-locate-keyequal/cell
          (swisstable-bytewise-locate-keyequal/cell st key h
          ) ; end swisstable-bytewise-locate-keyequal/cell
      ) ; end if
  ) ; end if
) ; end define

(define (swisstable-locate-keyalw-slow st key h
        ) ; end swisstable-locate-keyalw-slow
  (if (fx= (swisstable-weakness-code st
           ) ; end swisstable-weakness-code
           0
      ) ; end fx=
      (if swisstable-wide-fixnum?
          (swisstable-scan-locate-keyalw st key h
          ) ; end swisstable-scan-locate-keyalw
          (swisstable-bytewise-locate-keyalw st key h
          ) ; end swisstable-bytewise-locate-keyalw
      ) ; end if
      (if swisstable-wide-fixnum?
          (swisstable-scan-locate-keyalw/cell st key h
          ) ; end swisstable-scan-locate-keyalw/cell
          (swisstable-bytewise-locate-keyalw/cell st key h
          ) ; end swisstable-bytewise-locate-keyalw/cell
      ) ; end if
  ) ; end if
) ; end define

(define (swisstable-locate st key
        ) ; end swisstable-locate
  (let ([kind (swisstable-kind-code st
              ) ; end swisstable-kind-code
        ] ; end kind
       ) ; end let args
    (cond
      [(fx= kind 0)
       (swisstable-locate-eq-like st key (swisstable-eq-hash key
                                         ) ; end swisstable-eq-hash
       ) ; end swisstable-locate-eq-like
      ] ; end clause
      [(fx= kind 1)
       (let ([h (swisstable-eqv-hash key
                ) ; end swisstable-eqv-hash
             ] ; end h
            ) ; end let args
         (if (swisstable-eqv-immediate? key
             ) ; end swisstable-eqv-immediate?
             (swisstable-locate-eq-like st key h
             ) ; end swisstable-locate-eq-like
             (swisstable-locate-eqv-slow st key h
             ) ; end swisstable-locate-eqv-slow
         ) ; end if
       ) ; end let
      ] ; end clause
      [(fx= kind 2)
       (swisstable-locate-equal-slow st key (swisstable-equal-hash key
                                            ) ; end swisstable-equal-hash
       ) ; end swisstable-locate-equal-slow
      ] ; end clause
      [(fx= kind 3)
       (swisstable-locate-keyequal-slow st key (swisstable-keyequal-hash key
                                               ) ; end swisstable-keyequal-hash
       ) ; end swisstable-locate-keyequal-slow
      ] ; end clause
      [else
       (swisstable-locate-keyalw-slow st key (swisstable-keyalw-hash key
                                             ) ; end swisstable-keyalw-hash
       ) ; end swisstable-locate-keyalw-slow
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

;; Value of the (known-full) slot i, or `default` when the entry died
;; between location and fetch (possible for ephemerons when user
;; comparison code allowed an interrupt-driven collection).
(define (swisstable-slot-value st i default
        ) ; end swisstable-slot-value
  (if (fx= (swisstable-weakness-code st
           ) ; end swisstable-weakness-code
           0
      ) ; end fx=
      (#3%vector-ref (swisstable-slots st
                     ) ; end swisstable-slots
                     (fx+ (fxsll i 1
                          ) ; end fxsll
                          1
                     ) ; end fx+
      ) ; end vector-ref
      (let ([cell (#3%vector-ref (swisstable-slots st
                                 ) ; end swisstable-slots
                                 (fxsll i 1
                                 ) ; end fxsll
                  ) ; end vector-ref
            ] ; end cell
           ) ; end let args
        (if (pair? cell
            ) ; end pair?
            (let ([v (cdr cell
                     ) ; end cdr
                  ] ; end v
                 ) ; end let args
              (if (bwp-object? v
                  ) ; end bwp-object?
                  default
                  v
              ) ; end if
            ) ; end let
            default
        ) ; end if
      ) ; end let
  ) ; end if
) ; end define

;; Insert a key known to be absent into fresh arrays (no tombstones,
;; no duplicate check); used by rehashing.  key-slot/val-slot are the
;; raw slot contents (cell + hole for weak tables).  On wide
;; platforms the C probe finds the slot (always the odd/empty
;; encoding on a fresh table); narrow platforms scan bytewise.
(define (swisstable-insert-fresh! ctrl slots cap key-slot val-slot h
        ) ; end swisstable-insert-fresh!
  (define (place i
          ) ; end place
    (#3%bytevector-u8-set! ctrl i (fxand h #x7F
                                  ) ; end fxand
    ) ; end bytevector-u8-set!
    (#3%vector-set! slots (fxsll i 1
                          ) ; end fxsll
                    key-slot
    ) ; end vector-set!
    (#3%vector-set! slots (fx+ (fxsll i 1
                               ) ; end fxsll
                               1
                    ) ; end fx+
                    val-slot
    ) ; end vector-set!
  ) ; end define
  (if swisstable-wide-fixnum?
      (let ([r (swisstable-c-find-slot ctrl cap h
               ) ; end swisstable-c-find-slot
            ] ; end r
           ) ; end let args
        (place (fxsrl (fx- (fx- r
                           ) ; end fx-
                           3
                      ) ; end fx-
                      1
               ) ; end fxsrl
        ) ; end place
      ) ; end let
      (let ([gmask (fx- (fxsrl cap 4
                        ) ; end fxsrl
                        1
                   ) ; end fx-
            ] ; end gmask
           ) ; end let args
        (let loop ([g (fxand (fxsrl h 7
                             ) ; end fxsrl
                             gmask
                      ) ; end fxand
                   ] ; end g
                   [step 1
                   ] ; end step
                  ) ; end loop args
          (let ([base (fxsll g 4
                      ) ; end fxsll
                ] ; end base
               ) ; end let args
            (let scan ([j 0
                       ] ; end j
                      ) ; end scan args
              (cond
                [(fx= j swisstable-group-size
                 ) ; end fx=
                 (loop (fxand (fx+ g step
                              ) ; end fx+
                              gmask
                       ) ; end fxand
                       (fx+ step 1
                       ) ; end fx+
                 ) ; end loop
                ] ; end clause
                [(fx= (#3%bytevector-u8-ref ctrl (fx+ base j
                                             ) ; end fx+
                      ) ; end bytevector-u8-ref
                      swisstable-ctrl-empty
                 ) ; end fx=
                 (place (fx+ base j
                        ) ; end fx+
                 ) ; end place
                ] ; end clause
                [else (scan (fx+ j 1
                            ) ; end fx+
                      ) ; end scan
                ] ; end else
              ) ; end cond
            ) ; end let
          ) ; end let
        ) ; end let
      ) ; end let
  ) ; end if
) ; end define

;; Rebuild: grow when at least half full, otherwise purge tombstones
;; at the same capacity.  For weak tables this also drops dead
;; entries (a rehash is a full sweep) and preserves surviving cells,
;; so entry identity and GC registration carry over.  The old arrays
;; stay intact until the rebuild completes, so an escape from a user
;; hash procedure cannot corrupt the table.
(define (swisstable-rehash! st
        ) ; end swisstable-rehash!
  (let* ([old-ctrl (swisstable-ctrl st
                   ) ; end swisstable-ctrl
         ] ; end old-ctrl
         [old-slots (swisstable-slots st
                    ) ; end swisstable-slots
         ] ; end old-slots
         [old-cap (swisstable-capacity st
                  ) ; end swisstable-capacity
         ] ; end old-cap
         [weakness (swisstable-weakness-code st
                   ) ; end swisstable-weakness-code
         ] ; end weakness
         [count (swisstable-count st
                ) ; end swisstable-count
         ] ; end count
         [new-cap (if (fx>= (fxsll count 1
                            ) ; end fxsll
                            old-cap
                      ) ; end fx>=
                      (fxsll old-cap 1
                      ) ; end fxsll
                      old-cap
                  ) ; end if
         ] ; end new-cap
        ) ; end let* args
    (when (fx> new-cap swisstable-max-capacity
          ) ; end fx>
      (raise-arguments-error 'swisstable "table is too large to grow"
                             "count" count
      ) ; end raise-arguments-error
    ) ; end when
    (let ([new-ctrl (swisstable-make-ctrl new-cap
                    ) ; end swisstable-make-ctrl
          ] ; end new-ctrl
          [new-slots (swisstable-make-slots new-cap
                     ) ; end swisstable-make-slots
          ] ; end new-slots
         ) ; end let args
      (let loop ([i 0
                 ] ; end i
                 [live 0
                 ] ; end live
                ) ; end loop args
        (cond
          [(fx= i old-cap
           ) ; end fx=
           (swisstable-count-set! st live
           ) ; end swisstable-count-set!
          ] ; end clause
          [(fx>= (#3%bytevector-u8-ref old-ctrl i
                 ) ; end bytevector-u8-ref
                 #x80
           ) ; end fx>=
           (loop (fx+ i 1
                 ) ; end fx+
                 live
           ) ; end loop
          ] ; end clause
          [(fx= weakness 0
           ) ; end fx=
           (let ([key (#3%vector-ref old-slots (fxsll i 1
                                               ) ; end fxsll
                      ) ; end vector-ref
                 ] ; end key
                ) ; end let args
             (swisstable-insert-fresh! new-ctrl
                                       new-slots
                                       new-cap
                                       key
                                       (#3%vector-ref old-slots (fx+ (fxsll i 1
                                                                     ) ; end fxsll
                                                                     1
                                                                ) ; end fx+
                                       ) ; end vector-ref
                                       (swisstable-hash-for st key
                                       ) ; end swisstable-hash-for
             ) ; end swisstable-insert-fresh!
             (loop (fx+ i 1
                   ) ; end fx+
                   (fx+ live 1
                   ) ; end fx+
             ) ; end loop
           ) ; end let
          ] ; end clause
          [else
           (let ([cell (#3%vector-ref old-slots (fxsll i 1
                                                ) ; end fxsll
                       ) ; end vector-ref
                 ] ; end cell
                ) ; end let args
             (if (swisstable-cell-dead? cell
                 ) ; end swisstable-cell-dead?
                 (loop (fx+ i 1
                       ) ; end fx+
                       live
                 ) ; end loop
                 (begin
                   (swisstable-insert-fresh! new-ctrl
                                             new-slots
                                             new-cap
                                             cell
                                             swisstable-hole
                                             (swisstable-hash-for st (car cell
                                                                     ) ; end car
                                             ) ; end swisstable-hash-for
                   ) ; end swisstable-insert-fresh!
                   (loop (fx+ i 1
                         ) ; end fx+
                         (fx+ live 1
                         ) ; end fx+
                   ) ; end loop
                 ) ; end begin
             ) ; end if
           ) ; end let
          ] ; end else
        ) ; end cond
      ) ; end let
      (swisstable-ctrl-set! st new-ctrl
      ) ; end swisstable-ctrl-set!
      (swisstable-slots-set! st new-slots
      ) ; end swisstable-slots-set!
      (swisstable-capacity-set! st new-cap
      ) ; end swisstable-capacity-set!
      (swisstable-deleted-set! st 0
      ) ; end swisstable-deleted-set!
      (swisstable-swept-epoch-set! st swisstable-gc-epoch
      ) ; end swisstable-swept-epoch-set!
    ) ; end let
  ) ; end let*
) ; end define

;; Clear one full slot: EMPTY-revert when the group still has an
;; EMPTY byte (see the invariant argument at remove!), otherwise a
;; tombstone.  Updates `deleted` but not `count`.
(define (swisstable-clear-slot! st ctrl slots i
        ) ; end swisstable-clear-slot!
  (let ([base (fxand i (fxnot 15
                       ) ; end fxnot
              ) ; end fxand
        ] ; end base
       ) ; end let args
    (let scan ([j 0
               ] ; end j
              ) ; end scan args
      (cond
        [(fx= j swisstable-group-size
         ) ; end fx=
         (bytevector-u8-set! ctrl i swisstable-ctrl-deleted
         ) ; end bytevector-u8-set!
         (swisstable-deleted-set! st (fx+ (swisstable-deleted st
                                          ) ; end swisstable-deleted
                                          1
                                     ) ; end fx+
         ) ; end swisstable-deleted-set!
        ] ; end clause
        [(fx= (#3%bytevector-u8-ref ctrl (fx+ base j
                                     ) ; end fx+
              ) ; end bytevector-u8-ref
              swisstable-ctrl-empty
         ) ; end fx=
         (bytevector-u8-set! ctrl i swisstable-ctrl-empty
         ) ; end bytevector-u8-set!
        ] ; end clause
        [else (scan (fx+ j 1
                    ) ; end fx+
              ) ; end scan
        ] ; end else
      ) ; end cond
    ) ; end let
  ) ; end let
  (vector-set! slots (fxsll i 1
                     ) ; end fxsll
               swisstable-hole
  ) ; end vector-set!
  (vector-set! slots (fx+ (fxsll i 1
                          ) ; end fxsll
                          1
               ) ; end fx+
               swisstable-hole
  ) ; end vector-set!
) ; end define

;; Full sweep of a weak/ephemeron table: drop entries whose keys the
;; GC has cleared, and recompute `count`.
(define (swisstable-sweep! st
        ) ; end swisstable-sweep!
  (let ([ctrl (swisstable-ctrl st
              ) ; end swisstable-ctrl
        ] ; end ctrl
        [slots (swisstable-slots st
               ) ; end swisstable-slots
        ] ; end slots
        [cap (swisstable-capacity st
             ) ; end swisstable-capacity
        ] ; end cap
       ) ; end let args
    (let loop ([i 0] [live 0
                     ] ; end live
              ) ; end loop args
      (cond
        [(fx= i cap
         ) ; end fx=
         (swisstable-count-set! st live
         ) ; end swisstable-count-set!
        ] ; end clause
        [(fx>= (#3%bytevector-u8-ref ctrl i
               ) ; end bytevector-u8-ref
               #x80
         ) ; end fx>=
         (loop (fx+ i 1
               ) ; end fx+
               live
         ) ; end loop
        ] ; end clause
        [(swisstable-cell-dead? (#3%vector-ref slots (fxsll i 1
                                                     ) ; end fxsll
                                ) ; end vector-ref
         ) ; end swisstable-cell-dead?
         (swisstable-clear-slot! st ctrl slots i
         ) ; end swisstable-clear-slot!
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
  ) ; end let
  (swisstable-swept-epoch-set! st swisstable-gc-epoch
  ) ; end swisstable-swept-epoch-set!
) ; end define

(define (swisstable-maybe-sweep! st
        ) ; end swisstable-maybe-sweep!
  (let ([w (swisstable-weakness-code st
           ) ; end swisstable-weakness-code
        ] ; end w
       ) ; end let args
    ;; strong-cell tables (code 3) hold their keys strongly, so
    ;; nothing ever dies and no sweep is needed
    (when (and (or (fx= w 1
                   ) ; end fx=
                   (fx= w 2
                   ) ; end fx=
               ) ; end or
               (not (fx= (swisstable-swept-epoch st
                         ) ; end swisstable-swept-epoch
                         swisstable-gc-epoch
                    ) ; end fx=
               ) ; end not
          ) ; end and
      (swisstable-sweep! st
      ) ; end swisstable-sweep!
    ) ; end when
  ) ; end let
) ; end define

;; Place a key known to be absent: one C probe finds a reusable
;; tombstone or the target empty slot (see prim5.c for the return
;; encoding); the load-factor check runs before an empty slot is
;; consumed.
(define (swisstable-insert-absent! st key val h
        ) ; end swisstable-insert-absent!
  (let retry (
             ) ; end retry args
    (let* ([ctrl (swisstable-ctrl st
                 ) ; end swisstable-ctrl
           ] ; end ctrl
           [slots (swisstable-slots st
                  ) ; end swisstable-slots
           ] ; end slots
           [cap (swisstable-capacity st
                ) ; end swisstable-capacity
           ] ; end cap
           [r (if swisstable-wide-fixnum?
                  (swisstable-c-find-slot ctrl cap h
                  ) ; end swisstable-c-find-slot
                  (swisstable-narrow-find-slot ctrl cap h
                  ) ; end swisstable-narrow-find-slot
              ) ; end if
           ] ; end r
          ) ; end let* args
      (define (place! i
              ) ; end place!
        (let ([weakness (swisstable-weakness-code st
                        ) ; end swisstable-weakness-code
              ] ; end weakness
             ) ; end let args
          (#3%bytevector-u8-set! ctrl i (fxand h #x7F
                                        ) ; end fxand
          ) ; end bytevector-u8-set!
          (if (fx= weakness 0
              ) ; end fx=
              (begin
                (#3%vector-set! slots (fxsll i 1
                                      ) ; end fxsll
                                key
                ) ; end vector-set!
                (#3%vector-set! slots (fx+ (fxsll i 1
                                           ) ; end fxsll
                                           1
                                ) ; end fx+
                                val
                ) ; end vector-set!
              ) ; end begin
              (#3%vector-set! slots (fxsll i 1
                                    ) ; end fxsll
                              (swisstable-make-cell weakness key val
                              ) ; end swisstable-make-cell
              ) ; end vector-set!
          ) ; end if
          (swisstable-count-set! st (fx+ (swisstable-count st
                                         ) ; end swisstable-count
                                         1
                                    ) ; end fx+
          ) ; end swisstable-count-set!
        ) ; end let
      ) ; end define
      (cond
        [(fxodd? r
         ) ; end fxodd?
         (if (fx> (fxsll (fx+ (swisstable-count st
                              ) ; end swisstable-count
                              (swisstable-deleted st
                              ) ; end swisstable-deleted
                              1
                         ) ; end fx+
                         3
                  ) ; end fxsll
                  (fx* 7 cap
                  ) ; end fx*
             ) ; end fx>
             (begin
               (swisstable-rehash! st
               ) ; end swisstable-rehash!
               (retry
               ) ; end retry
             ) ; end begin
             (place! (fxsrl (fx- (fx- r
                                 ) ; end fx-
                                 3
                            ) ; end fx-
                            1
                     ) ; end fxsrl
             ) ; end place!
         ) ; end if
        ] ; end clause
        [else
         (place! (fxsrl (fx- (fx- r
                             ) ; end fx-
                             2
                        ) ; end fx-
                        1
                 ) ; end fxsrl
         ) ; end place!
         (swisstable-deleted-set! st (fx- (swisstable-deleted st
                                          ) ; end swisstable-deleted
                                          1
                                     ) ; end fx-
         ) ; end swisstable-deleted-set!
        ] ; end else
      ) ; end cond
    ) ; end let*
  ) ; end let
  (void
  ) ; end void
) ; end define

;; Narrow-platform substitute for the C find-slot probe's negative
;; encoding: first tombstone in probe order, else the first empty
;; byte of the terminating group.
(define (swisstable-narrow-find-slot ctrl cap h
        ) ; end swisstable-narrow-find-slot
  (let ([gmask (fx- (fxsrl cap 4
                    ) ; end fxsrl
                    1
               ) ; end fx-
        ] ; end gmask
       ) ; end let args
    (let loop ([g (fxand (fxsrl h 7
                         ) ; end fxsrl
                         gmask
                  ) ; end fxand
               ] ; end g
               [step 1
               ] ; end step
               [tomb -1
               ] ; end tomb
              ) ; end loop args
      (let ([base (fxsll g 4
                  ) ; end fxsll
            ] ; end base
           ) ; end let args
        (let scan ([j 0] [tomb tomb] [empty-i -1
                                     ] ; end empty-i
                  ) ; end scan args
          (cond
            [(fx= j swisstable-group-size
             ) ; end fx=
             (cond
               [(fx>= empty-i 0
                ) ; end fx>=
                (if (fx>= tomb 0
                    ) ; end fx>=
                    (fx- -2 (fxsll tomb 1
                            ) ; end fxsll
                    ) ; end fx-
                    (fx- -3 (fxsll empty-i 1
                            ) ; end fxsll
                    ) ; end fx-
                ) ; end if
               ] ; end clause
               [else (loop (fxand (fx+ g step
                                  ) ; end fx+
                                  gmask
                           ) ; end fxand
                           (fx+ step 1
                           ) ; end fx+
                           tomb
                     ) ; end loop
               ] ; end else
             ) ; end cond
            ] ; end clause
            [else
             (let ([b (#3%bytevector-u8-ref ctrl (fx+ base j
                                            ) ; end fx+
                      ) ; end bytevector-u8-ref
                   ] ; end b
                  ) ; end let args
               (cond
                 [(and (fx= b swisstable-ctrl-deleted
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
                 [(and (fx= b swisstable-ctrl-empty
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
             ) ; end let
            ] ; end else
          ) ; end cond
        ) ; end let
      ) ; end let
    ) ; end let
  ) ; end let
) ; end define

;; Overwrite the value of the existing entry at slot i.
(define (swisstable-overwrite! st i val
        ) ; end swisstable-overwrite!
  (if (fx= (swisstable-weakness-code st
           ) ; end swisstable-weakness-code
           0
      ) ; end fx=
      (#3%vector-set! (swisstable-slots st
                      ) ; end swisstable-slots
                      (fx+ (fxsll i 1
                           ) ; end fxsll
                           1
                      ) ; end fx+
                      val
      ) ; end vector-set!
      (set-cdr! (#3%vector-ref (swisstable-slots st
                               ) ; end swisstable-slots
                               (fxsll i 1
                               ) ; end fxsll
                ) ; end vector-ref
                val
      ) ; end set-cdr!
  ) ; end if
) ; end define

;; Insert via the kernel C eq probes: one C call finds the existing
;; slot, a reusable tombstone, or the target empty slot.
(define (swisstable-eq-like-set! st key val h
        ) ; end swisstable-eq-like-set!
  (let retry (
             ) ; end retry args
    (let* ([ctrl (swisstable-ctrl st
                 ) ; end swisstable-ctrl
           ] ; end ctrl
           [slots (swisstable-slots st
                  ) ; end swisstable-slots
           ] ; end slots
           [cap (swisstable-capacity st
                ) ; end swisstable-capacity
           ] ; end cap
           [weakness (swisstable-weakness-code st
                     ) ; end swisstable-weakness-code
           ] ; end weakness
           [r (if (fx= weakness 0
                  ) ; end fx=
                  (swisstable-c-probe-eq ctrl slots key h cap
                  ) ; end swisstable-c-probe-eq
                  (swisstable-c-probe-eq-ind ctrl slots key h cap
                  ) ; end swisstable-c-probe-eq-ind
              ) ; end if
           ] ; end r
          ) ; end let* args
      (define (place! i reuse-tomb?
              ) ; end place!
        (#3%bytevector-u8-set! ctrl i (fxand h #x7F
                                      ) ; end fxand
        ) ; end bytevector-u8-set!
        (if (fx= weakness 0
            ) ; end fx=
            (begin
              (#3%vector-set! slots (fxsll i 1
                                    ) ; end fxsll
                              key
              ) ; end vector-set!
              (#3%vector-set! slots (fx+ (fxsll i 1
                                         ) ; end fxsll
                                         1
                              ) ; end fx+
                              val
              ) ; end vector-set!
            ) ; end begin
            (#3%vector-set! slots (fxsll i 1
                                  ) ; end fxsll
                            (swisstable-make-cell weakness key val
                            ) ; end swisstable-make-cell
            ) ; end vector-set!
        ) ; end if
        (swisstable-count-set! st (fx+ (swisstable-count st
                                       ) ; end swisstable-count
                                       1
                                  ) ; end fx+
        ) ; end swisstable-count-set!
        (when reuse-tomb?
          (swisstable-deleted-set! st (fx- (swisstable-deleted st
                                           ) ; end swisstable-deleted
                                           1
                                      ) ; end fx-
          ) ; end swisstable-deleted-set!
        ) ; end when
      ) ; end define
      (cond
        [(fx>= r 0
         ) ; end fx>=
         (swisstable-overwrite! st r val
         ) ; end swisstable-overwrite!
         r
        ] ; end clause
        [(fxodd? r
         ) ; end fxodd?
         (if (fx> (fxsll (fx+ (swisstable-count st
                              ) ; end swisstable-count
                              (swisstable-deleted st
                              ) ; end swisstable-deleted
                              1
                         ) ; end fx+
                         3
                  ) ; end fxsll
                  (fx* 7 cap
                  ) ; end fx*
             ) ; end fx>
             (begin
               (swisstable-rehash! st
               ) ; end swisstable-rehash!
               (retry
               ) ; end retry
             ) ; end begin
             (begin
               (place! (fxsrl (fx- (fx- r
                                   ) ; end fx-
                                   3
                              ) ; end fx-
                              1
                       ) ; end fxsrl
                       #f
               ) ; end place!
               -1
             ) ; end begin
         ) ; end if
        ] ; end clause
        [else
         (place! (fxsrl (fx- (fx- r
                             ) ; end fx-
                             2
                        ) ; end fx-
                        1
                 ) ; end fxsrl
                 #t
         ) ; end place!
         -1
        ] ; end else
      ) ; end cond
    ) ; end let*
  ) ; end let
) ; end define

;; Insert for equal tables and non-immediate eqv keys: the locate
;; step (with user-level comparisons) establishes presence/absence,
;; then absent keys are placed without further comparisons.
(define (swisstable-compare-set! st key val h i
        ) ; end swisstable-compare-set!
  (if (fx>= i 0
      ) ; end fx>=
      (begin
        (swisstable-overwrite! st i val
        ) ; end swisstable-overwrite!
        i
      ) ; end begin
      (begin
        (swisstable-insert-absent! st key val h
        ) ; end swisstable-insert-absent!
        -1
      ) ; end begin
  ) ; end if
) ; end define

(define (swisstable-do-set! st key val
        ) ; end swisstable-do-set!
  (let ([kind (swisstable-kind-code st
              ) ; end swisstable-kind-code
        ] ; end kind
       ) ; end let args
    (cond
      [(fx= kind 0)
       (swisstable-eq-like-set! st key val (swisstable-eq-hash key
                                           ) ; end swisstable-eq-hash
       ) ; end swisstable-eq-like-set!
      ] ; end clause
      [(fx= kind 1)
       (let ([h (swisstable-eqv-hash key
                ) ; end swisstable-eqv-hash
             ] ; end h
            ) ; end let args
         (if (swisstable-eqv-immediate? key
             ) ; end swisstable-eqv-immediate?
             (swisstable-eq-like-set! st key val h
             ) ; end swisstable-eq-like-set!
             (swisstable-compare-set! st key val h
                                      (swisstable-locate-eqv-slow st key h
                                      ) ; end swisstable-locate-eqv-slow
             ) ; end swisstable-compare-set!
         ) ; end if
       ) ; end let
      ] ; end clause
      [(fx= kind 2)
       (let ([h (swisstable-equal-hash key
                ) ; end swisstable-equal-hash
             ] ; end h
            ) ; end let args
         (swisstable-compare-set! st key val h
                                  (swisstable-locate-equal-slow st key h
                                  ) ; end swisstable-locate-equal-slow
         ) ; end swisstable-compare-set!
       ) ; end let
      ] ; end clause
      [(fx= kind 3)
       (let ([h (swisstable-keyequal-hash key
                ) ; end swisstable-keyequal-hash
             ] ; end h
            ) ; end let args
         (swisstable-compare-set! st key val h
                                  (swisstable-locate-keyequal-slow st key h
                                  ) ; end swisstable-locate-keyequal-slow
         ) ; end swisstable-compare-set!
       ) ; end let
      ] ; end clause
      [else
       (let ([h (swisstable-keyalw-hash key
                ) ; end swisstable-keyalw-hash
             ] ; end h
            ) ; end let args
         (swisstable-compare-set! st key val h
                                  (swisstable-locate-keyalw-slow st key h
                                  ) ; end swisstable-locate-keyalw-slow
         ) ; end swisstable-compare-set!
       ) ; end let
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (core-swisstable-set! st key val
        ) ; end core-swisstable-set!
  (core-check-swisstable 'swisstable-set! st
  ) ; end core-check-swisstable
  (swisstable-maybe-sweep! st
  ) ; end swisstable-maybe-sweep!
  (swisstable-do-set! st key val
  ) ; end swisstable-do-set!
  (void
  ) ; end void
) ; end define

;; Like set!, but reports the outcome: -1 when a new key was added
;; (the built-in mutable-hash layer then flushes any iteration
;; snapshot), otherwise the slot index of the overwritten entry.
(define (swisstable-table-set!* st key val
        ) ; end swisstable-table-set!*
  (swisstable-do-set! st key val
  ) ; end swisstable-do-set!
) ; end define

;; Propagate an overwritten value into the snapshot pair for slot i,
;; if a snapshot is active, so (cdr pair) readers stay accurate.
(define (swisstable-snapshot-update! st i val
        ) ; end swisstable-snapshot-update!
  (let ([reg (swisstable-snapshot st
             ) ; end swisstable-snapshot
        ] ; end reg
       ) ; end let args
    (when reg
      (let ([pair (eq-hashtable-ref reg
                                    (#3%vector-ref (swisstable-slots st
                                                   ) ; end swisstable-slots
                                                   (fxsll i 1
                                                   ) ; end fxsll
                                    ) ; end vector-ref
                                    #f
                  ) ; end eq-hashtable-ref
            ] ; end pair
           ) ; end let args
        (when pair
          (set-cdr! pair val
          ) ; end set-cdr!
        ) ; end when
      ) ; end let
    ) ; end when
  ) ; end let
  (void
  ) ; end void
) ; end define

(define (swisstable-drop-snapshot! st
        ) ; end swisstable-drop-snapshot!
  (swisstable-snapshot-set! st #f
  ) ; end swisstable-snapshot-set!
) ; end define

(define (core-swisstable-ref st key default
        ) ; end core-swisstable-ref
  (core-check-swisstable 'swisstable-ref st
  ) ; end core-check-swisstable
  (let ([kind (swisstable-kind-code st
              ) ; end swisstable-kind-code
        ] ; end kind
       ) ; end let args
    (cond
      [(and (fx= kind 0
            ) ; end fx=
            (fx= (swisstable-weakness-code st
                 ) ; end swisstable-weakness-code
                 0
            ) ; end fx=
       ) ; end and
       (swisstable-c-ref-eq (swisstable-ctrl st
                            ) ; end swisstable-ctrl
                            (swisstable-slots st
                            ) ; end swisstable-slots
                            key
                            (swisstable-eq-hash key
                            ) ; end swisstable-eq-hash
                            (swisstable-capacity st
                            ) ; end swisstable-capacity
                            default
       ) ; end swisstable-c-ref-eq
      ] ; end clause
      [(and (fx= kind 1
            ) ; end fx=
            (fx= (swisstable-weakness-code st
                 ) ; end swisstable-weakness-code
                 0
            ) ; end fx=
            (swisstable-eqv-immediate? key
            ) ; end swisstable-eqv-immediate?
       ) ; end and
       (swisstable-c-ref-eq (swisstable-ctrl st
                            ) ; end swisstable-ctrl
                            (swisstable-slots st
                            ) ; end swisstable-slots
                            key
                            (swisstable-eqv-hash key
                            ) ; end swisstable-eqv-hash
                            (swisstable-capacity st
                            ) ; end swisstable-capacity
                            default
       ) ; end swisstable-c-ref-eq
      ] ; end clause
      [else
       (let ([i (swisstable-locate st key
                ) ; end swisstable-locate
             ] ; end i
            ) ; end let args
         (if (fx< i 0
             ) ; end fx<
             default
             (swisstable-slot-value st i default
             ) ; end swisstable-slot-value
         ) ; end if
       ) ; end let
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (core-swisstable-has-key? st key
        ) ; end core-swisstable-has-key?
  (core-check-swisstable 'swisstable-has-key? st
  ) ; end core-check-swisstable
  (fx>= (swisstable-locate st key
        ) ; end swisstable-locate
        0
  ) ; end fx>=
) ; end define

(define (core-swisstable-remove! st key
        ) ; end core-swisstable-remove!
  (core-check-swisstable 'swisstable-remove! st
  ) ; end core-check-swisstable
  (swisstable-maybe-sweep! st
  ) ; end swisstable-maybe-sweep!
  (let ([i (swisstable-locate st key
           ) ; end swisstable-locate
        ] ; end i
       ) ; end let args
    (cond
      [(fx< i 0
       ) ; end fx<
       #f
      ] ; end clause
      [else
       (cond
         [(fx> (swisstable-weakness-code st
               ) ; end swisstable-weakness-code
               0
          ) ; end fx>
          ;; the entry cell doubles as the iteration snapshot cell,
          ;; so clear it directly, mirroring the Chez backend
          (let ([cell (#3%vector-ref (swisstable-slots st
                                     ) ; end swisstable-slots
                                     (fxsll i 1
                                     ) ; end fxsll
                      ) ; end vector-ref
                ] ; end cell
               ) ; end let args
            (when (pair? cell
                  ) ; end pair?
              (set-car! cell #!bwp
              ) ; end set-car!
              (set-cdr! cell #!bwp
              ) ; end set-cdr!
            ) ; end when
          ) ; end let
         ] ; end clause
         [else
          (let ([reg (swisstable-snapshot st
                     ) ; end swisstable-snapshot
                ] ; end reg
               ) ; end let args
            (when reg
              ;; invalidate the snapshot pair, mirroring the Chez
              ;; backend's cell clearing on removal
              (let* ([sk (#3%vector-ref (swisstable-slots st
                                        ) ; end swisstable-slots
                                        (fxsll i 1
                                        ) ; end fxsll
                         ) ; end vector-ref
                     ] ; end sk
                     [pair (eq-hashtable-ref reg sk #f
                           ) ; end eq-hashtable-ref
                     ] ; end pair
                    ) ; end let* args
                (when pair
                  (set-car! pair #!bwp
                  ) ; end set-car!
                  (set-cdr! pair #!bwp
                  ) ; end set-cdr!
                  (eq-hashtable-delete! reg sk
                  ) ; end eq-hashtable-delete!
                ) ; end when
              ) ; end let*
            ) ; end when
          ) ; end let
         ] ; end else
       ) ; end cond
       (swisstable-clear-slot! st
                               (swisstable-ctrl st
                               ) ; end swisstable-ctrl
                               (swisstable-slots st
                               ) ; end swisstable-slots
                               i
       ) ; end swisstable-clear-slot!
       (swisstable-count-set! st (fx- (swisstable-count st
                                      ) ; end swisstable-count
                                      1
                                 ) ; end fx-
       ) ; end swisstable-count-set!
       #t
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (core-swisstable-clear! st
        ) ; end core-swisstable-clear!
  (core-check-swisstable 'swisstable-clear! st
  ) ; end core-check-swisstable
  (bytevector-fill! (swisstable-ctrl st
                    ) ; end swisstable-ctrl
                    swisstable-ctrl-empty
  ) ; end bytevector-fill!
  (vector-fill! (swisstable-slots st
                ) ; end swisstable-slots
                swisstable-hole
  ) ; end vector-fill!
  (swisstable-count-set! st 0
  ) ; end swisstable-count-set!
  (swisstable-deleted-set! st 0
  ) ; end swisstable-deleted-set!
  (swisstable-swept-epoch-set! st swisstable-gc-epoch
  ) ; end swisstable-swept-epoch-set!
  (swisstable-snapshot-set! st #f
  ) ; end swisstable-snapshot-set!
  (void
  ) ; end void
) ; end define

(define (core-swisstable-count st
        ) ; end core-swisstable-count
  (core-check-swisstable 'swisstable-count st
  ) ; end core-check-swisstable
  (swisstable-maybe-sweep! st
  ) ; end swisstable-maybe-sweep!
  (swisstable-count st
  ) ; end swisstable-count
) ; end define

(define (core-swisstable-kind st
        ) ; end core-swisstable-kind
  (core-check-swisstable 'swisstable-kind st
  ) ; end core-check-swisstable
  (let ([kind (swisstable-kind-code st
              ) ; end swisstable-kind-code
        ] ; end kind
       ) ; end let args
    (cond
      [(fx= kind 0) 'eq
      ] ; end clause
      [(fx= kind 1) 'eqv
      ] ; end clause
      [(fx= kind 4) 'equal-always
      ] ; end clause
      [else 'equal
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (core-swisstable-weakness st
        ) ; end core-swisstable-weakness
  (core-check-swisstable 'swisstable-weakness st
  ) ; end core-check-swisstable
  (let ([w (swisstable-weakness-code st
           ) ; end swisstable-weakness-code
        ] ; end w
       ) ; end let args
    (cond
      [(fx= w 0) 'strong
      ] ; end clause
      [(fx= w 1) 'weak
      ] ; end clause
      [else 'ephemeron
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (core-swisstable-stats st
        ) ; end core-swisstable-stats
  (core-check-swisstable 'swisstable-stats st
  ) ; end core-check-swisstable
  (swisstable-maybe-sweep! st
  ) ; end swisstable-maybe-sweep!
  (vector (core-swisstable-kind st
          ) ; end core-swisstable-kind
          (swisstable-capacity st
          ) ; end swisstable-capacity
          (swisstable-count st
          ) ; end swisstable-count
          (swisstable-deleted st
          ) ; end swisstable-deleted
          (core-swisstable-weakness st
          ) ; end core-swisstable-weakness
  ) ; end vector
) ; end define

;; Iteration positions are slot indexes; full slots whose entry died
;; (weak tables, before the next sweep) are skipped.
(define (swisstable-live-index? st i
        ) ; end swisstable-live-index?
  (or (fx= (swisstable-weakness-code st
           ) ; end swisstable-weakness-code
           0
      ) ; end fx=
      (not (swisstable-cell-dead? (#3%vector-ref (swisstable-slots st
                                                 ) ; end swisstable-slots
                                                 (fxsll i 1
                                                 ) ; end fxsll
                                  ) ; end vector-ref
           ) ; end swisstable-cell-dead?
      ) ; end not
  ) ; end or
) ; end define

(define (swisstable-next-full st i
        ) ; end swisstable-next-full
  (let ([ctrl (swisstable-ctrl st
              ) ; end swisstable-ctrl
        ] ; end ctrl
        [cap (swisstable-capacity st
             ) ; end swisstable-capacity
        ] ; end cap
       ) ; end let args
    (let loop ([i i
               ] ; end i
              ) ; end loop args
      (cond
        [(fx>= i cap
         ) ; end fx>=
         #f
        ] ; end clause
        [(and (fx< (#3%bytevector-u8-ref ctrl i
                   ) ; end bytevector-u8-ref
                   #x80
              ) ; end fx<
              (swisstable-live-index? st i
              ) ; end swisstable-live-index?
         ) ; end and
         i
        ] ; end clause
        [else (loop (fx+ i 1
                    ) ; end fx+
              ) ; end loop
        ] ; end else
      ) ; end cond
    ) ; end let
  ) ; end let
) ; end define

(define (core-swisstable-iterate-first st
        ) ; end core-swisstable-iterate-first
  (core-check-swisstable 'swisstable-iterate-first st
  ) ; end core-check-swisstable
  (swisstable-maybe-sweep! st
  ) ; end swisstable-maybe-sweep!
  (swisstable-next-full st 0
  ) ; end swisstable-next-full
) ; end define

(define (core-swisstable-iterate-next st i
        ) ; end core-swisstable-iterate-next
  (core-check-swisstable 'swisstable-iterate-next st
  ) ; end core-check-swisstable
  (unless (and (fixnum? i
               ) ; end fixnum?
               (fx>= i 0
               ) ; end fx>=
          ) ; end and
    (raise-argument-error 'swisstable-iterate-next "exact-nonnegative-integer?" i
    ) ; end raise-argument-error
  ) ; end unless
  (swisstable-next-full st (fx+ i 1
                           ) ; end fx+
  ) ; end swisstable-next-full
) ; end define

(define (swisstable-valid-index? st i
        ) ; end swisstable-valid-index?
  (and (fixnum? i
       ) ; end fixnum?
       (fx>= i 0
       ) ; end fx>=
       (fx< i (swisstable-capacity st
              ) ; end swisstable-capacity
       ) ; end fx<
       (fx< (bytevector-u8-ref (swisstable-ctrl st
                               ) ; end swisstable-ctrl
                               i
            ) ; end bytevector-u8-ref
            #x80
       ) ; end fx<
       (swisstable-live-index? st i
       ) ; end swisstable-live-index?
  ) ; end and
) ; end define

(define (swisstable-slot-key st i
        ) ; end swisstable-slot-key
  (if (fx= (swisstable-weakness-code st
           ) ; end swisstable-weakness-code
           0
      ) ; end fx=
      (vector-ref (swisstable-slots st
                  ) ; end swisstable-slots
                  (fxsll i 1
                  ) ; end fxsll
      ) ; end vector-ref
      (car (vector-ref (swisstable-slots st
                       ) ; end swisstable-slots
                       (fxsll i 1
                       ) ; end fxsll
           ) ; end vector-ref
      ) ; end car
  ) ; end if
) ; end define

(define (core-swisstable-iterate-key st i fail
        ) ; end core-swisstable-iterate-key
  (core-check-swisstable 'swisstable-iterate-key st
  ) ; end core-check-swisstable
  (if (swisstable-valid-index? st i
      ) ; end swisstable-valid-index?
      (swisstable-slot-key st i
      ) ; end swisstable-slot-key
      fail
  ) ; end if
) ; end define

(define (core-swisstable-iterate-value st i fail
        ) ; end core-swisstable-iterate-value
  (core-check-swisstable 'swisstable-iterate-value st
  ) ; end core-check-swisstable
  (if (swisstable-valid-index? st i
      ) ; end swisstable-valid-index?
      (swisstable-slot-value st i fail
      ) ; end swisstable-slot-value
      fail
  ) ; end if
) ; end define

(define (core-swisstable-iterate-key+value st i fail
        ) ; end core-swisstable-iterate-key+value
  (core-check-swisstable 'swisstable-iterate-key+value st
  ) ; end core-check-swisstable
  (if (swisstable-valid-index? st i
      ) ; end swisstable-valid-index?
      (values (swisstable-slot-key st i
              ) ; end swisstable-slot-key
              (swisstable-slot-value st i fail
              ) ; end swisstable-slot-value
      ) ; end values
      (values fail fail
      ) ; end values
  ) ; end if
) ; end define

;; --------------------------------------------------------------------
;; Backend operations for Racket's built-in mutable hash tables
;; (rumble/hash.ss).  Backend tables run in plain strong (direct)
;; mode, so lookups and updates get the full flat-slot speed.
;; Iteration snapshots are materialized as fresh (key . value) pairs
;; by swisstable-table-cells; the readers in hash.ss re-consult the
;; table by key, so value updates stay visible and removed keys
;; disappear, matching the live-cell behavior of the Chez backend.

(define (swisstable-make-hash-backend kind-code weakness-code
        ) ; end swisstable-make-hash-backend
  (make-core-swisstable (swisstable-make-ctrl swisstable-min-capacity
                        ) ; end swisstable-make-ctrl
                        (swisstable-make-slots swisstable-min-capacity
                        ) ; end swisstable-make-slots
                        0
                        0
                        swisstable-min-capacity
                        kind-code
                        weakness-code
                        swisstable-gc-epoch
                        #f
  ) ; end make-core-swisstable
) ; end define

;; Stored key for `key`, or `none-v` when absent; used by
;; hash-ref-key.
(define (swisstable-table-ref-key st key none-v
        ) ; end swisstable-table-ref-key
  (let ([i (swisstable-locate st key
           ) ; end swisstable-locate
        ] ; end i
       ) ; end let args
    (if (fx>= i 0
        ) ; end fx>=
        (let ([content (#3%vector-ref (swisstable-slots st
                                      ) ; end swisstable-slots
                                      (fxsll i 1
                                      ) ; end fxsll
                       ) ; end vector-ref
              ] ; end content
             ) ; end let args
          (if (fx= (swisstable-weakness-code st
                   ) ; end swisstable-weakness-code
                   0
              ) ; end fx=
              content
              ;; weak/ephemeron entries store a cell; return its key,
              ;; guarding against a collection racing the lookup
              (let ([k (car content
                       ) ; end car
                    ] ; end k
                   ) ; end let args
                (if (bwp-object? k
                    ) ; end bwp-object?
                    none-v
                    k
                ) ; end if
              ) ; end let
          ) ; end if
        ) ; end let
        none-v
    ) ; end if
  ) ; end let
) ; end define

;; Full iteration snapshot: a vector of freshly allocated
;; (key . value) pairs for every current entry, in slot order.  The
;; result is complete, so hash.ss never needs to re-fetch or merge
;; snapshots for this backend.
(define (swisstable-table-cells st n
        ) ; end swisstable-table-cells
  (if (fx> (swisstable-weakness-code st
           ) ; end swisstable-weakness-code
           0
      ) ; end fx>
      (swisstable-weak-table-cells st
      ) ; end swisstable-weak-table-cells
      (swisstable-strong-table-cells st
      ) ; end swisstable-strong-table-cells
  ) ; end if
) ; end define

(define (swisstable-strong-table-cells st
        ) ; end swisstable-strong-table-cells
  (let* ([ctrl (swisstable-ctrl st
               ) ; end swisstable-ctrl
         ] ; end ctrl
         [slots (swisstable-slots st
                ) ; end swisstable-slots
         ] ; end slots
         [cap (swisstable-capacity st
              ) ; end swisstable-capacity
         ] ; end cap
         [want (swisstable-count st
               ) ; end swisstable-count
         ] ; end want
         [vec (#%make-vector want
              ) ; end make-vector
         ] ; end vec
         [reg (make-eq-hashtable
              ) ; end make-eq-hashtable
         ] ; end reg
        ) ; end let* args
    (let loop ([i 0] [j 0
                     ] ; end j
              ) ; end loop args
      (cond
        [(or (fx= j want
             ) ; end fx=
             (fx= i cap
             ) ; end fx=
         ) ; end or
         (swisstable-snapshot-set! st reg
         ) ; end swisstable-snapshot-set!
         vec
        ] ; end clause
        [(fx< (#3%bytevector-u8-ref ctrl i
              ) ; end bytevector-u8-ref
              #x80
         ) ; end fx<
         (let* ([key (#3%vector-ref slots (fxsll i 1
                                          ) ; end fxsll
                     ) ; end vector-ref
                ] ; end key
                [pair (cons key (#3%vector-ref slots (fx+ (fxsll i 1
                                                          ) ; end fxsll
                                                          1
                                                     ) ; end fx+
                                ) ; end vector-ref
                      ) ; end cons
                ] ; end pair
               ) ; end let* args
           (#%vector-set! vec j pair
           ) ; end vector-set!
           (eq-hashtable-set! reg key pair
           ) ; end eq-hashtable-set!
         ) ; end let*
         (loop (fx+ i 1
               ) ; end fx+
               (fx+ j 1
               ) ; end fx+
         ) ; end loop
        ] ; end clause
        [else (loop (fx+ i 1
                    ) ; end fx+
                    j
              ) ; end loop
        ] ; end else
      ) ; end cond
    ) ; end let
  ) ; end let*
) ; end define

;; Weak/ephemeron entries are GC-managed pairs with the value in the
;; cdr, so they double as live iteration cells: value overwrites go
;; through set-cdr!, explicit removal and dead keys show up as bwp,
;; exactly like Chez hashtable cells.  No snapshot registry needed.
(define (swisstable-weak-table-cells st
        ) ; end swisstable-weak-table-cells
  (swisstable-maybe-sweep! st
  ) ; end swisstable-maybe-sweep!
  (let* ([ctrl (swisstable-ctrl st
               ) ; end swisstable-ctrl
         ] ; end ctrl
         [slots (swisstable-slots st
                ) ; end swisstable-slots
         ] ; end slots
         [cap (swisstable-capacity st
              ) ; end swisstable-capacity
         ] ; end cap
         [want (swisstable-count st
               ) ; end swisstable-count
         ] ; end want
         [vec (#%make-vector want '(#!bwp . #!bwp)
              ) ; end make-vector
         ] ; end vec
        ) ; end let* args
    (let loop ([i 0] [j 0
                     ] ; end j
              ) ; end loop args
      (cond
        [(or (fx= j want
             ) ; end fx=
             (fx= i cap
             ) ; end fx=
         ) ; end or
         vec
        ] ; end clause
        [(and (fx< (#3%bytevector-u8-ref ctrl i
                   ) ; end bytevector-u8-ref
                   #x80
              ) ; end fx<
              (not (swisstable-cell-dead? (#3%vector-ref slots (fxsll i 1
                                                               ) ; end fxsll
                                          ) ; end vector-ref
                   ) ; end swisstable-cell-dead?
              ) ; end not
         ) ; end and
         (#%vector-set! vec j (#3%vector-ref slots (fxsll i 1
                                                   ) ; end fxsll
                              ) ; end vector-ref
         ) ; end vector-set!
         (loop (fx+ i 1
               ) ; end fx+
               (fx+ j 1
               ) ; end fx+
         ) ; end loop
        ] ; end clause
        [else (loop (fx+ i 1
                    ) ; end fx+
                    j
              ) ; end loop
        ] ; end else
      ) ; end cond
    ) ; end let
  ) ; end let*
) ; end define

;; Fresh backend table with the same kind and copies of all entries.
(define (swisstable-table-copy st
        ) ; end swisstable-table-copy
  (let ([new-st (swisstable-make-hash-backend (swisstable-kind-code st
                                              ) ; end swisstable-kind-code
                                              (swisstable-weakness-code st
                                              ) ; end swisstable-weakness-code
                ) ; end swisstable-make-hash-backend
        ] ; end new-st
        [weakness (swisstable-weakness-code st
                  ) ; end swisstable-weakness-code
        ] ; end weakness
        [ctrl (swisstable-ctrl st
              ) ; end swisstable-ctrl
        ] ; end ctrl
        [slots (swisstable-slots st
               ) ; end swisstable-slots
        ] ; end slots
        [cap (swisstable-capacity st
             ) ; end swisstable-capacity
        ] ; end cap
       ) ; end let args
    (let loop ([i 0
               ] ; end i
              ) ; end loop args
      (unless (fx= i cap
              ) ; end fx=
        (when (fx< (#3%bytevector-u8-ref ctrl i
                   ) ; end bytevector-u8-ref
                   #x80
              ) ; end fx<
          (if (fx= weakness 0
              ) ; end fx=
              (let ([key (#3%vector-ref slots (fxsll i 1
                                              ) ; end fxsll
                         ) ; end vector-ref
                    ] ; end key
                   ) ; end let args
                (swisstable-insert-absent! new-st
                                           key
                                           (#3%vector-ref slots (fx+ (fxsll i 1
                                                                     ) ; end fxsll
                                                                     1
                                                                ) ; end fx+
                                           ) ; end vector-ref
                                           (swisstable-hash-for new-st key
                                           ) ; end swisstable-hash-for
                ) ; end swisstable-insert-absent!
              ) ; end let
              (let ([cell (#3%vector-ref slots (fxsll i 1
                                               ) ; end fxsll
                          ) ; end vector-ref
                    ] ; end cell
                   ) ; end let args
                (unless (swisstable-cell-dead? cell
                        ) ; end swisstable-cell-dead?
                  (swisstable-insert-absent! new-st
                                             (car cell
                                             ) ; end car
                                             (cdr cell
                                             ) ; end cdr
                                             (swisstable-hash-for new-st (car cell
                                                                         ) ; end car
                                             ) ; end swisstable-hash-for
                  ) ; end swisstable-insert-absent!
                ) ; end unless
              ) ; end let
          ) ; end if
        ) ; end when
        (loop (fx+ i 1
              ) ; end fx+
        ) ; end loop
      ) ; end unless
    ) ; end let
    new-st
  ) ; end let
) ; end define

;; Lets the Racket layer attach struct properties (custom-write and
;; friends) to the core record type, following the intmap pattern.
(define (core-swisstable-install-struct-property! prop value
        ) ; end core-swisstable-install-struct-property!
  (let ([rtd (record-type-descriptor core-swisstable
             ) ; end record-type-descriptor
        ] ; end rtd
       ) ; end let args
    (unless (struct-property-ref prop rtd #f
            ) ; end struct-property-ref
      (struct-property-set! prop rtd value
      ) ; end struct-property-set!
    ) ; end unless
  ) ; end let
  (void
  ) ; end void
) ; end define
