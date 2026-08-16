#lang racket/base

(require racket/match
         racket/vector
         racket/unsafe/ops
         (only-in "for.rkt"
                  define-sequence-syntax
                  range-sequence->exact-integer-range-info
                  range-sequence->exact-nonnegative-integer)
         (prefix-in fallback: "pvector.rkt")
         (for-syntax racket/base))

(provide pvector?
         pvector-empty
         pvector-empty?
         pvector
         make-pvector
         fresh-vector->pvector
         small-immutable-vector->pvector
         single-value->pvector
         two-values->pvector
         three-values->pvector
         four-values->pvector
         list->pvector
         pvector->list
         vector->pvector
         pvector->vector
         pvector->chunk-vector
         pvector->chunk-vector/shared
         pvector-lookup-chunk
         sequence->pvector
         pvector-length
         pvector-length/fast
         pvector-ref
         pvector-set
         pvector-view-left
         pvector-view-right
         pvector-view-left/fast
         pvector-view-right/fast
         pvector-cons-left
         pvector-cons-right
         pvector-pop-left
         pvector-pop-right
         pvector-append
         pvector-map
         pvector-insert
         pvector-delete
         pvector-take
         pvector-drop
         pvector-take-right
         pvector-drop-right
         pvector-copy
         pvector-split
         pvector-split-at
         pvector-split-at-right
         pvector-for-each
         in-pvector
         in-pvector-reverse
         in-pvector/index
         in-pvector-indexed
         for/pvector
         for*/pvector
         pvector-ref/fast
         pvector-set/fast
         pvector-shape-stats
         make-pvector-literal-state
         pvector-literal-state-defs
         pvector-literal-emit!
         pvector-literal->pvector
         pvector-runtime-adapter-backend
         pvector-runtime-adapter-core-available?
         pvector-runtime-adapter-cursor-available?
         pvector-runtime-adapter-literal-available?
         pvector-runtime-adapter-public-properties-available?
         pvector-install-struct-property!
         pvector-cursor-start
         pvector-cursor-value
         pvector-cursor-next
         pvector-cursor-start/fast
         pvector-cursor-value/fast
         pvector-cursor-next/fast
         pvector-cursor-value+next/fast)

(define (maybe-kernel name)
  (with-handlers ([exn:fail? (lambda (_) #f)])
    (dynamic-require ''#%kernel name)))

(define core-pvector? (maybe-kernel 'core-pvector?))
(define core-pvector-empty (maybe-kernel 'core-pvector-empty))
(define core-pvector-empty? (maybe-kernel 'core-pvector-empty?))
(define core-pvector-length (maybe-kernel 'core-pvector-length))
(define core-pvector-shape-stats (maybe-kernel 'core-pvector-shape-stats))
(define core-vector->pvector (maybe-kernel 'core-vector->pvector))
(define core-immutable-vector->pvector
  (maybe-kernel 'core-immutable-vector->pvector))
(define core-fresh-vector->pvector (maybe-kernel 'core-fresh-vector->pvector))
(define core-list->pvector (maybe-kernel 'core-list->pvector))
(define core-make-single-pvector (maybe-kernel 'core-make-single-pvector))
(define core-make-deep2-pvector (maybe-kernel 'core-make-deep2-pvector))
(define core-make-deep3-pvector (maybe-kernel 'core-make-deep3-pvector))
(define core-make-deep4-pvector (maybe-kernel 'core-make-deep4-pvector))
(define core-make-pvector (maybe-kernel 'core-make-pvector))
(define core-pvector->vector (maybe-kernel 'core-pvector->vector))
(define core-pvector->list (maybe-kernel 'core-pvector->list))
(define core-pvector-ref (maybe-kernel 'core-pvector-ref))
(define core-unsafe-pvector-length (maybe-kernel 'core-unsafe-pvector-length))
(define core-unsafe-pvector-ref (maybe-kernel 'core-unsafe-pvector-ref))
(define core-unsafe-pvector-view-left
  (maybe-kernel 'core-unsafe-pvector-view-left))
(define core-unsafe-pvector-view-right
  (maybe-kernel 'core-unsafe-pvector-view-right))
(define core-unsafe-pvector-first
  (or (maybe-kernel 'core-unsafe-pvector-first)
      core-unsafe-pvector-view-left))
(define core-unsafe-pvector-last
  (or (maybe-kernel 'core-unsafe-pvector-last)
      core-unsafe-pvector-view-right))
(define core-pvector-cursor-start (maybe-kernel 'core-pvector-cursor-start))
(define core-pvector-cursor-value (maybe-kernel 'core-pvector-cursor-value))
(define core-pvector-cursor-next (maybe-kernel 'core-pvector-cursor-next))
(define core-pvector-cursor-value+next
  (maybe-kernel 'core-pvector-cursor-value+next))
(define core-pvector-view-left (maybe-kernel 'core-pvector-view-left))
(define core-pvector-view-right (maybe-kernel 'core-pvector-view-right))
(define core-pvector-set (maybe-kernel 'core-pvector-set))
(define core-pvector-cons-left (maybe-kernel 'core-pvector-cons-left))
(define core-pvector-cons-right (maybe-kernel 'core-pvector-cons-right))
(define core-pvector-pop-left (maybe-kernel 'core-pvector-pop-left))
(define core-pvector-pop-right (maybe-kernel 'core-pvector-pop-right))
(define core-pvector-append (maybe-kernel 'core-pvector-append))
(define core-pvector-map (maybe-kernel 'core-pvector-map))
(define core-pvector-for-each (maybe-kernel 'core-pvector-for-each))
(define core-pvector-split-at (maybe-kernel 'core-pvector-split-at))
(define core-pvector-split-at-right (maybe-kernel 'core-pvector-split-at-right))
(define core-pvector-split (maybe-kernel 'core-pvector-split))
(define core-pvector-insert (maybe-kernel 'core-pvector-insert))
(define core-pvector-delete (maybe-kernel 'core-pvector-delete))
(define core-pvector-take (maybe-kernel 'core-pvector-take))
(define core-pvector-drop (maybe-kernel 'core-pvector-drop))
(define core-pvector-take-right (maybe-kernel 'core-pvector-take-right))
(define core-pvector-drop-right (maybe-kernel 'core-pvector-drop-right))
(define core-pvector-copy (maybe-kernel 'core-pvector-copy))
(define core-pvector-install-struct-property!
  (maybe-kernel 'core-pvector-install-struct-property!))
(define core-pvector-literal-emit!
  (maybe-kernel 'core-pvector-literal-emit!))
(define core-pvector-literal->pvector
  (maybe-kernel 'core-pvector-literal->pvector))

(define core-bindings
  (list core-pvector?
        core-pvector-empty
        core-pvector-empty?
        core-pvector-length
        core-pvector-shape-stats
        core-vector->pvector
        core-immutable-vector->pvector
        core-fresh-vector->pvector
        core-list->pvector
        core-make-single-pvector
        core-make-deep2-pvector
        core-make-deep3-pvector
        core-make-deep4-pvector
        core-make-pvector
        core-pvector->vector
        core-pvector->list
        core-pvector-ref
        core-pvector-view-left
        core-pvector-view-right
        core-pvector-set
        core-pvector-cons-left
        core-pvector-cons-right
        core-pvector-pop-left
        core-pvector-pop-right
        core-pvector-append
        core-pvector-map
        core-pvector-for-each
        core-pvector-split-at
        core-pvector-split-at-right
        core-pvector-split
        core-pvector-insert
        core-pvector-delete
        core-pvector-take
        core-pvector-drop
        core-pvector-take-right
        core-pvector-drop-right
        core-pvector-copy))

(define compiled-core-available?
  (andmap procedure? core-bindings))

(define (compiled-core-no-chunk?)
  (and compiled-core-available?
       (with-handlers ([exn:fail? (lambda (_) #f)])
         (define pv (core-list->pvector '(0 1 2 3 4 5 6 7 8)))
         (define stats (core-pvector-shape-stats pv))
         (and (core-pvector? pv)
              (eq? (hash-ref stats 'chunked-tree? #t) #f)
              (zero? (hash-ref stats 'chunk-index-vectors 1))
              (eq? (hash-ref stats 'ref-cache? #t) #f)))))

;; Enable kernel core only after the installed primitive reports the no-chunk
;; runtime shape. Older local builds may still provide obsolete pvector
;; primitives, and those must stay behind the finger fallback.
(define core-available? (compiled-core-no-chunk?))

(define core-sequence-available?
  (and core-available?
       (procedure? core-unsafe-pvector-length)
       (procedure? core-unsafe-pvector-ref)))

(define core-fast-view-available?
  (and core-available?
       (procedure? core-unsafe-pvector-first)
       (procedure? core-unsafe-pvector-last)))

(define core-cursor-available?
  (and core-sequence-available?
       (procedure? core-pvector-cursor-start)
       (procedure? core-pvector-cursor-value)
       (procedure? core-pvector-cursor-next)))

(define core-cursor-combined-available?
  (and core-cursor-available?
       (procedure? core-pvector-cursor-value+next)))

(define core-public-properties-available?
  (and core-available?
       (procedure? core-pvector-install-struct-property!)))

(define core-literal-available?
  (and core-available?
       (procedure? core-pvector-literal-emit!)
       (procedure? core-pvector-literal->pvector)))

(define (pvector-runtime-adapter-core-available?)
  core-available?)

(define (pvector-runtime-adapter-cursor-available?)
  core-cursor-available?)

(define (pvector-runtime-adapter-public-properties-available?)
  core-public-properties-available?)

(define (pvector-runtime-adapter-literal-available?)
  core-literal-available?)

(define (pvector-runtime-adapter-backend)
  (if core-available? 'core 'finger))

(define (pvector-install-struct-property! prop value)
  (unless core-public-properties-available?
    (error 'pvector-install-struct-property!
           "native pvector public properties are not available"))
  (core-pvector-install-struct-property! prop value))

(define (make-pvector-literal-state)
  (vector (make-hasheq)
          (make-hasheq)
          (make-hasheq)
          0
          null))

(define (pvector-literal-state-defs state)
  (reverse (vector-ref state 4)))

(define (pvector-literal-emit! pv state)
  (unless core-literal-available?
    (error 'pvector-literal-emit!
           "native pvector literal output is not available"))
  (core-pvector-literal-emit! pv state))

(define (pvector-literal->pvector datum)
  (unless core-literal-available?
    (error 'pvector-literal->pvector
           "native pvector literal input is not available"))
  (core-pvector-literal->pvector datum))

(define core-builder-block-size 64)

(define (fresh-vector->pvector vec)
  (if core-available?
      (core-fresh-vector->pvector vec)
      (fallback:vector->pvector vec)))

(define (fresh-vector->core-pvector vec)
  (core-fresh-vector->pvector vec))

(define-syntax-rule (with-core-pvector-builder emit body ...)
  (let* ([len 0]
         [capacity core-builder-block-size]
         [uniform? #t]
         [uniform-value #f]
         [vec (make-vector capacity)])
    (define (grow!)
      (define new-capacity (unsafe-fx* capacity 2))
      (define new-vec (make-vector new-capacity))
      (let loop ([i 0])
        (unless (unsafe-fx= i len)
          (unsafe-vector-set! new-vec i (unsafe-vector-ref vec i))
          (loop (unsafe-fx+ i 1))))
      (set! vec new-vec)
      (set! capacity new-capacity))
    (let-syntax ([emit
                  (syntax-rules ()
                    [(_ value)
                     (let ([value* value])
                       (when uniform?
                         (if (unsafe-fx= len 0)
                             (set! uniform-value value*)
                             (unless (eq? value* uniform-value)
                               (set! uniform? #f))))
                       (when (unsafe-fx= len capacity)
                         (grow!))
                       (unsafe-vector-set! vec len value*)
                       (set! len (unsafe-fx+ len 1)))])])
      body ...)
    (cond
      [(unsafe-fx= len 0)
       (core-pvector-empty)]
      [uniform?
       (core-make-pvector len uniform-value)]
      [else
       (fresh-vector->core-pvector
        (if (unsafe-fx= len capacity)
            vec
            (vector-copy vec 0 len)))])))

(define (small-immutable-vector->pvector vec len)
  (cond
    [(not core-available?)
     (fallback:vector->pvector
      (if (= len (vector-length vec))
          vec
          (vector-copy vec 0 len)))]
    [(= len 1)
     (core-make-single-pvector (vector-ref vec 0))]
    [(= len 2)
     (core-make-deep2-pvector (vector-ref vec 0) (vector-ref vec 1))]
    [(= len 3)
     (core-make-deep3-pvector
      (vector-ref vec 0)
      (vector-ref vec 1)
      (vector-ref vec 2))]
    [(= len 4)
     (core-make-deep4-pvector
      (vector-ref vec 0)
      (vector-ref vec 1)
      (vector-ref vec 2)
      (vector-ref vec 3))]
    [else
     (core-immutable-vector->pvector
      (cond
        [(= len (vector-length vec))
         (if (immutable? vec)
             vec
             (vector->immutable-vector vec))]
        [else
         (vector->immutable-vector (vector-copy vec 0 len))]))]))

(define (single-value->pvector value)
  (if core-available?
      (core-make-single-pvector value)
      (fallback:pvector value)))

(define (two-values->pvector left-value right-value)
  (if core-available?
      (core-make-deep2-pvector left-value right-value)
      (fallback:pvector left-value right-value)))

(define (three-values->pvector a b c)
  (if core-available?
      (core-make-deep3-pvector a b c)
      (fallback:pvector a b c)))

(define (four-values->pvector a b c d)
  (if core-available?
      (core-make-deep4-pvector a b c d)
      (fallback:pvector a b c d)))

(define (small-vector->pvector vec len)
  (if core-available?
      (fresh-vector->pvector
       (if (= len (vector-length vec))
           vec
           (vector-copy vec 0 len)))
      (fallback:vector->pvector vec)))

(define pvector?
  (if core-available? core-pvector? fallback:pvector?))

(define pvector-empty
  (if core-available? core-pvector-empty fallback:pvector-empty))

(define pvector-empty?
  (if core-available? core-pvector-empty? fallback:pvector-empty?))

(define pvector-length
  (if core-available? core-pvector-length fallback:pvector-length))

(define pvector-length/fast
  (if core-sequence-available?
      core-unsafe-pvector-length
      pvector-length))

(define vector->pvector/backend
  (if core-available? core-vector->pvector fallback:vector->pvector))

(define list->pvector/backend
  (if core-available? core-list->pvector fallback:list->pvector))

(define (vector->pvector vec)
  (if (and core-available? (vector? vec))
      (case (vector-length vec)
        [(0) (pvector-empty)]
        [(1) (core-make-single-pvector (vector-ref vec 0))]
        [(2) (core-make-deep2-pvector (vector-ref vec 0) (vector-ref vec 1))]
        [(3)
         (core-make-deep3-pvector
          (vector-ref vec 0)
          (vector-ref vec 1)
          (vector-ref vec 2))]
        [(4)
         (core-make-deep4-pvector
          (vector-ref vec 0)
          (vector-ref vec 1)
          (vector-ref vec 2)
          (vector-ref vec 3))]
        [else (vector->pvector/backend vec)])
      (if (and (vector? vec) (zero? (vector-length vec)))
          (pvector-empty)
          (vector->pvector/backend vec))))

(define (list->pvector lst)
  (match lst
    ['() (pvector-empty)]
    [(list a) (pvector a)]
    [(list a b) (pvector a b)]
    [(list a b c) (pvector a b c)]
    [(list a b c d) (pvector a b c d)]
    [(list a b c d e) (pvector a b c d e)]
    [(list a b c d e f) (pvector a b c d e f)]
    [(list a b c d e f g) (pvector a b c d e f g)]
    [(list a b c d e f g h) (pvector a b c d e f g h)]
    [(list a b c d e f g h i)
     (pvector a b c d e f g h i)]
    [(list a b c d e f g h i j)
     (pvector a b c d e f g h i j)]
    [(list a b c d e f g h i j k)
     (pvector a b c d e f g h i j k)]
    [(list a b c d e f g h i j k l)
     (pvector a b c d e f g h i j k l)]
    [(list a b c d e f g h i j k l m)
     (pvector a b c d e f g h i j k l m)]
    [(list a b c d e f g h i j k l m n)
     (pvector a b c d e f g h i j k l m n)]
    [(list a b c d e f g h i j k l m n o)
     (pvector a b c d e f g h i j k l m n o)]
    [(list a b c d e f g h i j k l m n o p)
     (pvector a b c d e f g h i j k l m n o p)]
    [(list a b c d e f g h i j k l m n o p q)
     (pvector a b c d e f g h i j k l m n o p q)]
    [(list a b c d e f g h i j k l m n o p q r)
     (pvector a b c d e f g h i j k l m n o p q r)]
    [(list a b c d e f g h i j k l m n o p q r s)
     (pvector a b c d e f g h i j k l m n o p q r s)]
    [(list a b c d e f g h i j k l m n o p q r s t)
     (pvector a b c d e f g h i j k l m n o p q r s t)]
    [(list a b c d e f g h i j k l m n o p q r s t u)
     (pvector a b c d e f g h i j k l m n o p q r s t u)]
    [(list a b c d e f g h i j k l m n o p q r s t u v)
     (pvector a b c d e f g h i j k l m n o p q r s t u v)]
    [(list a b c d e f g h i j k l m n o p q r s t u v w)
     (pvector a b c d e f g h i j k l m n o p q r s t u v w)]
    [(list a b c d e f g h i j k l m n o p q r s t u v w x)
     (pvector a b c d e f g h i j k l m n o p q r s t u v w x)]
    [(list a b c d e f g h i j k l m n o p q r s t u v w x y)
     (pvector a b c d e f g h i j k l m n o p q r s t u v w x y)]
    [(list a b c d e f g h i j k l m n o p q r s t u v w x y z)
     (pvector a b c d e f g h i j k l m n o p q r s t u v w x y z)]
    [(list a b c d e f g h i j k l m n o p q r s t u v w x y z aa)
     (pvector a b c d e f g h i j k l m n o p q r s t u v w x y z aa)]
    [(list a b c d e f g h i j k l m n o p q r s t u v w x y z aa ab)
     (pvector a b c d e f g h i j k l m n o p q r s t u v w x y z aa ab)]
    [(list a b c d e f g h i j k l m n o p q r s t u v w x y z aa ab ac)
     (pvector a b c d e f g h i j k l m n o p q r s t u v w x y z aa ab ac)]
    [(list a b c d e f g h i j k l m n o p q r s t u v w x y z aa ab ac ad)
     (pvector a b c d e f g h i j k l m n o p q r s t u v w x y z aa ab ac ad)]
    [(list a b c d e f g h i j k l m n o p q r s t u v w x y z aa ab ac ad ae)
     (pvector a b c d e f g h i j k l m n o p q r s t u v w x y z aa ab ac ad ae)]
    [(list a b c d e f g h i j k l m n o p q r s t u v w x y z aa ab ac ad ae af)
     (pvector a b c d e f g h i j k l m n o p q r s t u v w x y z aa ab ac ad ae af)]
    [(list a b c d e f g h i j k l m n o p q r s t u v w x y z aa ab ac ad ae af ag)
     (pvector a b c d e f g h i j k l m n o p q r s t u v w x y z aa ab ac ad ae af ag)]
    [_ (list->pvector/backend lst)]))

(begin-for-syntax
  (define (small-make-pvector-clause stx len value-id)
    (with-syntax ([(elem ...)
                   (for/list ([i (in-range len)])
                     value-id)]
                  [len (datum->syntax stx len)])
      #'[(len) (pvector elem ...)]))

  (define (small-make-pvector-clauses stx value-id)
    (for/list ([len (in-range 1 5)])
      (small-make-pvector-clause stx len value-id))))

(define-syntax (small-make-pvector-dispatch stx)
  (syntax-case stx ()
    [(_ len-expr value-id)
     (with-syntax ([(small-clause ...)
                    (small-make-pvector-clauses stx #'value-id)])
       #'(case len-expr
           [(0) (core-pvector-empty)]
           small-clause ...))]))

(define (make-pvector len [value #f])
  (cond
    [(and core-available?
          (fixnum? len)
          (unsafe-fx<= 0 len)
          (unsafe-fx<= len 4))
     (small-make-pvector-dispatch len value)]
    [core-available?
     (core-make-pvector len value)]
    [else
     (fallback:make-pvector len value)]))

(begin-for-syntax
  (define pvector-inline-vector-arity-limit 64)
  (define pvector-fixed-vector-arity-limit 112)

  (define (small-pvector-proc-clause stx len)
    (define ids (generate-temporaries
                 (for/list ([i (in-range len)]) 'elem)))
    (cond
      [(= len 1)
       (with-syntax ([(elem) ids])
         #'[(elem) (single-value->pvector elem)])]
      [(= len 2)
       (with-syntax ([(left right) ids])
         #'[(left right) (two-values->pvector left right)])]
      [(= len 3)
       (with-syntax ([(a b c) ids])
         #'[(a b c) (three-values->pvector a b c)])]
      [(= len 4)
       (with-syntax ([(a b c d) ids])
         #'[(a b c d) (four-values->pvector a b c d)])]
      [(<= len pvector-inline-vector-arity-limit)
       (with-syntax ([(elem ...) ids]
                     [len (datum->syntax stx len)])
         #'[(elem ...)
            (small-immutable-vector->pvector (vector-immutable elem ...) len)])]
      [else
       (with-syntax ([(elem ...) ids])
         #'[(elem ...)
            (vector->pvector/backend (vector-immutable elem ...))])]))

  (define (small-pvector-proc-clauses stx)
    (for/list ([len (in-range 1 (add1 pvector-fixed-vector-arity-limit))])
      (small-pvector-proc-clause stx len))))

(define-syntax (make-pvector/proc stx)
  (syntax-case stx ()
    [(_)
     (with-syntax ([(small-clause ...)
                    (small-pvector-proc-clauses stx)])
       #'(case-lambda
           [() (pvector-empty)]
           small-clause ...
           [elems (list->pvector elems)]))]))

(define pvector (make-pvector/proc))

(define pvector->vector
  (if core-available? core-pvector->vector fallback:pvector->vector))

(define adapter-view-chunk-size core-builder-block-size)

(define (vector->adapter-chunk-vector vec)
  (define len (vector-length vec))
  (cond
    [(zero? len) #()]
    [else
     (define chunk-count
       (add1 (quotient (sub1 len) adapter-view-chunk-size)))
     (for/vector #:length chunk-count ([chunk-index (in-range chunk-count)])
       (define start (* chunk-index adapter-view-chunk-size))
       (define end (min len (+ start adapter-view-chunk-size)))
       (vector->immutable-vector (vector-copy vec start end)))]))

(define (pvector->chunk-vector/shared pv)
  (vector->adapter-chunk-vector (pvector->vector pv)))

(define (pvector->chunk-vector pv)
  (vector-copy (pvector->chunk-vector/shared pv)))

(define (pvector-lookup-chunk pv index)
  (define len (pvector-length pv))
  (unless (and (exact-nonnegative-integer? index)
               (< index len))
    (error 'pvector-lookup-chunk "index out of bounds: ~a" index))
  (values index (pvector->vector pv)))

(define pvector->list
  (if core-available? core-pvector->list fallback:pvector->list))

(define (small-integer-range->pvector len)
  (case len
    [(0) (core-pvector-empty)]
    [(1) (core-make-single-pvector 0)]
    [(2) (core-make-deep2-pvector 0 1)]
    [(3) (core-make-deep3-pvector 0 1 2)]
    [(4) (core-make-deep4-pvector 0 1 2 3)]
    [else
     (define vec (make-vector len))
     (let loop ([i 0])
       (unless (unsafe-fx= i len)
         (unsafe-vector-set! vec i i)
         (loop (unsafe-fx+ i 1))))
     (small-vector->pvector vec len)]))

(define (integer-range->pvector len)
  (cond
    [(unsafe-fx= len 0)
     (core-pvector-empty)]
    [(unsafe-fx<= len core-builder-block-size)
     (small-integer-range->pvector len)]
    [else
     (define vec (make-vector len))
     (let loop ([i 0])
       (unless (unsafe-fx= i len)
         (unsafe-vector-set! vec i i)
         (loop (unsafe-fx+ i 1))))
     (fresh-vector->core-pvector vec)]))

(define (arithmetic-range->pvector start step len)
  (cond
    [(unsafe-fx= len 0)
     (core-pvector-empty)]
    [(unsafe-fx= len 1)
     (core-make-single-pvector start)]
    [(unsafe-fx= len 2)
     (core-make-deep2-pvector start (+ start step))]
    [(unsafe-fx= len 3)
     (let* ([b (+ start step)]
            [c (+ b step)])
       (core-make-deep3-pvector start b c))]
    [(unsafe-fx= len 4)
     (let* ([b (+ start step)]
            [c (+ b step)]
            [d (+ c step)])
       (core-make-deep4-pvector start b c d))]
    [else
     (define vec (make-vector len))
     (let loop ([i 0] [elem start])
       (unless (unsafe-fx= i len)
         (unsafe-vector-set! vec i elem)
         (loop (unsafe-fx+ i 1) (+ elem step))))
     (fresh-vector->core-pvector vec)]))

(define (arithmetic-range-info->pvector info)
  (define start (vector-ref info 0))
  (define step (vector-ref info 1))
  (define len (vector-ref info 2))
  (if (and core-available? (fixnum? len))
      (arithmetic-range->pvector start step len)
      (fresh-vector->pvector
       (for/vector #:length len ([i (in-range len)])
         (+ start (* i step))))))

(define (sequence->pvector seq)
  (cond
    [(pvector? seq) seq]
    [(range-sequence->exact-nonnegative-integer seq)
     => (lambda (len)
          (if (and core-available? (fixnum? len))
              (integer-range->pvector len)
              (fresh-vector->pvector
               (for/vector #:length len ([elem (in-range len)])
                 elem))))]
    [(range-sequence->exact-integer-range-info seq)
     => arithmetic-range-info->pvector]
    [(exact-nonnegative-integer? seq)
     (if (and core-available? (fixnum? seq))
         (integer-range->pvector seq)
         (fresh-vector->pvector
          (for/vector #:length seq ([elem (in-range seq)])
            elem)))]
    [(list? seq) (list->pvector seq)]
    [(vector? seq) (vector->pvector seq)]
    [(not core-available?) (fallback:sequence->pvector seq)]
    [else
     (with-core-pvector-builder add!
       (for ([elem seq])
         (add! elem)))]))

(define (in-range-end->pvector end)
  (if (exact-nonnegative-integer? end)
      (sequence->pvector end)
      (sequence->pvector (in-range end))))

(define (in-range-length-end->pvector end)
  (if (exact-nonnegative-integer? end)
      (sequence->pvector end)
      (fresh-vector->pvector
       (for/vector #:length end ([elem (in-range end)])
         elem))))

(define pvector-ref
  (if core-available? core-pvector-ref fallback:pvector-ref))

(define pvector-ref/fast
  (if core-sequence-available?
      core-unsafe-pvector-ref
      pvector-ref))

(define pvector-set
  (if core-available? core-pvector-set fallback:pvector-set))

(define pvector-set/fast pvector-set)

(define pvector-view-left
  (if core-available? core-pvector-view-left fallback:pvector-view-left))

(define pvector-view-right
  (if core-available? core-pvector-view-right fallback:pvector-view-right))

(define pvector-view-left/fast
  (if core-fast-view-available?
      core-unsafe-pvector-first
      pvector-view-left))

(define pvector-view-right/fast
  (if core-fast-view-available?
      core-unsafe-pvector-last
      pvector-view-right))

(define (pvector-cursor-start pv reverse?)
  (unless core-cursor-available?
    (error 'pvector-cursor-start "native pvector cursor is not available"))
  (unless (core-pvector? pv)
    (raise-argument-error 'pvector-cursor-start "pvector?" pv))
  (core-pvector-cursor-start pv reverse?))

(define (pvector-cursor-value cursor)
  (unless core-cursor-available?
    (error 'pvector-cursor-value "native pvector cursor is not available"))
  (core-pvector-cursor-value cursor))

(define (pvector-cursor-next cursor)
  (unless core-cursor-available?
    (error 'pvector-cursor-next "native pvector cursor is not available"))
  (core-pvector-cursor-next cursor))

(define pvector-cursor-start/fast
  (if core-cursor-available?
      core-pvector-cursor-start
      pvector-cursor-start))

(define pvector-cursor-value/fast
  (if core-cursor-available?
      core-pvector-cursor-value
      pvector-cursor-value))

(define pvector-cursor-next/fast
  (if core-cursor-available?
      core-pvector-cursor-next
      pvector-cursor-next))

(define (pvector-cursor-value+next/fallback cursor)
  (values (pvector-cursor-value/fast cursor)
          (pvector-cursor-next/fast cursor)))

(define pvector-cursor-value+next/fast
  (if core-cursor-combined-available?
      core-pvector-cursor-value+next
      pvector-cursor-value+next/fallback))

(define pvector-cons-left
  (if core-available? core-pvector-cons-left fallback:pvector-cons-left))

(define pvector-cons-right
  (if core-available? core-pvector-cons-right fallback:pvector-cons-right))

(define pvector-pop-left
  (if core-available? core-pvector-pop-left fallback:pvector-pop-left))

(define pvector-pop-right
  (if core-available? core-pvector-pop-right fallback:pvector-pop-right))

(define pvector-append
  (if core-available? core-pvector-append fallback:pvector-append))

(define pvector-map
  (if core-available?
      core-pvector-map
      (lambda (pv proc)
        (cond
          [(fallback:pvector-empty? pv) (fallback:pvector-empty)]
          [(eq? proc values) pv]
          [(eq? proc void)
           (fallback:make-pvector (fallback:pvector-length pv) (void))]
          [else
           (fallback:for/pvector ([elem (fallback:in-pvector pv)])
             (proc elem))]))))

(define pvector-split-at
  (if core-available? core-pvector-split-at fallback:pvector-split-at))

(define pvector-split-at-right
  (if core-available? core-pvector-split-at-right fallback:pvector-split-at-right))

(define pvector-take
  (if core-available? core-pvector-take fallback:pvector-take))

(define pvector-drop
  (if core-available? core-pvector-drop fallback:pvector-drop))

(define pvector-take-right
  (if core-available? core-pvector-take-right fallback:pvector-take-right))

(define pvector-drop-right
  (if core-available? core-pvector-drop-right fallback:pvector-drop-right))

(define pvector-copy
  (if core-available? core-pvector-copy fallback:pvector-copy))

(define pvector-split
  (if core-available? core-pvector-split fallback:pvector-split))

(define pvector-insert
  (if core-available? core-pvector-insert fallback:pvector-insert))

(define pvector-delete
  (if core-available? core-pvector-delete fallback:pvector-delete))

(define (in-pvector/proc pv)
  (cond
    [core-cursor-available?
     (unless (core-pvector? pv)
       (raise-argument-error 'in-pvector "pvector?" pv))
     (make-do-sequence
      (lambda ()
        (values core-pvector-cursor-value
                core-pvector-cursor-next
                (core-pvector-cursor-start pv #f)
                (lambda (cursor) cursor)
                (lambda (elem) #t)
                (lambda (pos elem) #t))))]
    [core-sequence-available?
     (unless (core-pvector? pv)
       (raise-argument-error 'in-pvector "pvector?" pv))
     (define len (core-unsafe-pvector-length pv))
     (make-do-sequence
      (lambda ()
        (values (lambda (index) (core-unsafe-pvector-ref pv index))
                (lambda (index) (unsafe-fx+ index 1))
                0
                (lambda (index) (unsafe-fx< index len))
                (lambda (elem) #t)
                (lambda (pos elem) #t))))]
    [else
     (define vec (pvector->vector pv))
     (define len (unsafe-vector-length vec))
     (make-do-sequence
      (lambda ()
        (values (lambda (index) (unsafe-vector-ref vec index))
                (lambda (index) (unsafe-fx+ index 1))
                0
                (lambda (index) (unsafe-fx< index len))
                (lambda (elem) #t)
                (lambda (pos elem) #t))))]))

(define (in-pvector-reverse/proc pv)
  (cond
    [core-cursor-available?
     (unless (core-pvector? pv)
       (raise-argument-error 'in-pvector-reverse "pvector?" pv))
     (make-do-sequence
      (lambda ()
        (values core-pvector-cursor-value
                core-pvector-cursor-next
                (core-pvector-cursor-start pv #t)
                (lambda (cursor) cursor)
                (lambda (elem) #t)
                (lambda (pos elem) #t))))]
    [core-sequence-available?
     (unless (core-pvector? pv)
       (raise-argument-error 'in-pvector-reverse "pvector?" pv))
     (define len (core-unsafe-pvector-length pv))
     (make-do-sequence
      (lambda ()
        (values (lambda (index) (core-unsafe-pvector-ref pv index))
                (lambda (index) (unsafe-fx- index 1))
                (unsafe-fx- len 1)
                (lambda (index) (unsafe-fx>= index 0))
                (lambda (elem) #t)
                (lambda (pos elem) #t))))]
    [else
     (define vec (pvector->vector pv))
     (define len (unsafe-vector-length vec))
     (make-do-sequence
      (lambda ()
        (values (lambda (index) (unsafe-vector-ref vec index))
                (lambda (index) (unsafe-fx- index 1))
                (unsafe-fx- len 1)
                (lambda (index) (unsafe-fx>= index 0))
                (lambda (elem) #t)
                (lambda (pos elem) #t))))]))

(define-sequence-syntax in-pvector
  (lambda () #'in-pvector/proc)
  (lambda (stx)
    (syntax-case stx ()
      [[(elem) (_ pv-expr)]
       (syntax-property
        #'[(elem)
           (:do-in
            ([(pv) pv-expr])
            (begin
              (define pv*
                (if (pvector? pv)
                    pv
                    (raise-argument-error 'in-pvector "pvector?" pv)))
              (define use-cursor? core-cursor-available?)
              (define len (and (not use-cursor?) (pvector-length pv*))))
            ([elem-pos (if use-cursor?
                           (core-pvector-cursor-start pv* #f)
                           0)])
            (if use-cursor?
                elem-pos
                (unsafe-fx< elem-pos len))
            ([(elem next-elem-pos)
              (if use-cursor?
                  (pvector-cursor-value+next/fast elem-pos)
                  (values (pvector-ref/fast pv* elem-pos)
                          (unsafe-fx+ elem-pos 1)))])
            #t
            #t
            (next-elem-pos))]
        'pvector-direct-fold
        #t)]
      [_ #f])))

(define-sequence-syntax in-pvector-reverse
  (lambda () #'in-pvector-reverse/proc)
  (lambda (stx)
    (syntax-case stx ()
      [[(elem) (_ pv-expr)]
       #'[(elem)
          (:do-in
           ([(pv) pv-expr])
           (begin
             (define pv*
               (if (pvector? pv)
                   pv
                   (raise-argument-error 'in-pvector-reverse "pvector?" pv)))
             (define use-cursor? core-cursor-available?)
             (define len (and (not use-cursor?) (pvector-length pv*))))
           ([elem-pos (if use-cursor?
                          (core-pvector-cursor-start pv* #t)
                          (unsafe-fx- len 1))])
           (if use-cursor?
               elem-pos
               (unsafe-fx>= elem-pos 0))
           ([(elem next-elem-pos)
             (if use-cursor?
                 (pvector-cursor-value+next/fast elem-pos)
                 (values (pvector-ref/fast pv* elem-pos)
                         (unsafe-fx- elem-pos 1)))])
           #t
           #t
           (next-elem-pos))]]
      [_ #f])))

(define (in-pvector/index/proc pv)
  (cond
    [core-sequence-available?
     (unless (core-pvector? pv)
       (raise-argument-error 'in-pvector/index "pvector?" pv))
     (define len (core-unsafe-pvector-length pv))
     (make-do-sequence
      (lambda ()
        (values (lambda (index)
                  (values (core-unsafe-pvector-ref pv index) index))
                (lambda (index) (unsafe-fx+ index 1))
                0
                (lambda (index) (unsafe-fx< index len))
                (lambda (elem index) #t)
                (lambda (pos elem index) #t))))]
    [else
     (define vec (pvector->vector pv))
     (define len (unsafe-vector-length vec))
     (make-do-sequence
      (lambda ()
        (values (lambda (index)
                  (values (unsafe-vector-ref vec index) index))
                (lambda (index) (unsafe-fx+ index 1))
                0
                (lambda (index) (unsafe-fx< index len))
                (lambda (elem index) #t)
                (lambda (pos elem index) #t))))]))

(define-sequence-syntax in-pvector/index
  (lambda () #'in-pvector/index/proc)
  (lambda (stx)
    (syntax-case stx ()
      [[(elem index) (_ pv-expr)]
       #'[(elem index)
          (:do-in
           ([(pv) pv-expr])
           (begin
             (define len (pvector-length pv)))
           ([elem-idx 0])
           (unsafe-fx< elem-idx len)
           ([(elem index next-elem-idx)
             (values (pvector-ref/fast pv elem-idx)
                     elem-idx
                     (unsafe-fx+ elem-idx 1))])
           #t
           #t
           (next-elem-idx))]]
      [_ #f])))

(define-syntax in-pvector-indexed
  (make-rename-transformer #'in-pvector/index))

(define (pvector-shape-stats pv)
  (cond
    [core-available?
     (unless (core-pvector? pv)
       (raise-argument-error 'pvector-shape-stats "pvector?" pv))
     (core-pvector-shape-stats pv)]
    [else
     (fallback:pvector-shape-stats pv)]))

(begin-for-syntax
  (define (small-core-length-literal? stx)
    (define v (syntax-e stx))
    (and (exact-positive-integer? v)
         (<= v 64))))

(define-syntax (for/pvector stx)
  (syntax-case stx (in-range in-list in-vector in-pvector in-pvector-reverse)
    [(_ #:length len #:fill fill-expr (clause ...) body ...)
     (small-core-length-literal? #'len)
     #'(small-vector->pvector
        (for/vector #:length len #:fill fill-expr
                    (clause ...) body ...)
        len)]
    [(_ #:length length-expr #:fill fill-expr (clause ...) body ...)
     #'(fresh-vector->pvector
        (for/vector #:length length-expr #:fill fill-expr
                    (clause ...) body ...))]
    [(_ #:length end ([elem (in-range end*)]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (free-identifier=? #'elem #'body)
          (identifier? #'end)
          (identifier? #'end*)
          (free-identifier=? #'end #'end*))
     #'(in-range-length-end->pvector end)]
    [(_ #:length len ([elem (in-range end)]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (free-identifier=? #'elem #'body)
          (exact-nonnegative-integer? (syntax-e #'len))
          (equal? (syntax-e #'len) (syntax-e #'end)))
     #'(sequence->pvector len)]
    [(_ #:length end ([elem (in-range start end*)]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (free-identifier=? #'elem #'body)
          (identifier? #'end)
          (identifier? #'end*)
          (free-identifier=? #'end #'end*)
          (equal? (syntax-e #'start) 0))
     #'(sequence->pvector end)]
    [(_ #:length end ([elem (in-range start end* step)]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (free-identifier=? #'elem #'body)
          (identifier? #'end)
          (identifier? #'end*)
          (free-identifier=? #'end #'end*)
          (equal? (syntax-e #'start) 0)
          (equal? (syntax-e #'step) 1))
     #'(sequence->pvector end)]
    [(_ #:length length-expr ([elem (in-pvector pv-expr)]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (free-identifier=? #'elem #'body))
     #'(let ([len length-expr])
         (if (exact-nonnegative-integer? len)
             (let ([pv pv-expr])
               (if (and (pvector? pv)
                        (= len (pvector-length pv)))
                   pv
                   (fresh-vector->pvector
                    (for/vector #:length len ([elem (in-pvector pv)])
                      elem))))
             (fresh-vector->pvector
              (for/vector #:length len ([elem (in-pvector pv-expr)])
                elem))))]
    [(_ #:length length-expr ([elem (in-vector vec-expr)]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (free-identifier=? #'elem #'body))
     #'(let ([len length-expr])
         (if (exact-nonnegative-integer? len)
             (let ([vec vec-expr])
               (if (and (vector? vec)
                        (= len (vector-length vec)))
                   (vector->pvector vec)
                   (fresh-vector->pvector
                    (for/vector #:length len ([elem (in-vector vec)])
                      elem))))
             (fresh-vector->pvector
              (for/vector #:length len ([elem (in-vector vec-expr)])
                elem))))]
    [(_ #:length length-expr ([elem seq-id]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (identifier? #'seq-id)
          (free-identifier=? #'elem #'body))
     #'(let ([len length-expr])
         (if (exact-nonnegative-integer? len)
             (let ([seq seq-id])
               (cond
                 [(and (pvector? seq)
                       (= len (pvector-length seq)))
                  seq]
                 [(and (vector? seq)
                       (= len (vector-length seq)))
                  (vector->pvector seq)]
                 [else
                  (fresh-vector->pvector
                   (for/vector #:length len ([elem seq])
                     elem))]))
             (fresh-vector->pvector
              (for/vector #:length len ([elem seq-id])
                elem))))]
    [(_ #:length len (clause ...) body ...)
     (small-core-length-literal? #'len)
     #'(small-vector->pvector
        (for/vector #:length len
                    (clause ...) body ...)
        len)]
    [(_ #:length length-expr (clause ...) body ...)
     #'(fresh-vector->pvector
        (for/vector #:length length-expr
                    (clause ...) body ...))]
    [(_ ([elem (in-pvector pv-expr)]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (free-identifier=? #'elem #'body))
     #'(let ([pv pv-expr])
         (if (pvector? pv)
             pv
             (if core-available?
                 (with-core-pvector-builder add!
                   (for ([elem (in-pvector pv)])
                     (add! elem)))
                 (fallback:for/pvector ([elem (in-pvector pv)]) elem))))]
    [(_ ([elem (in-pvector-reverse pv-expr)]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (free-identifier=? #'elem #'body))
     #'(let ([pv pv-expr])
         (if (pvector? pv)
             (for/pvector #:length (pvector-length pv)
                          ([elem (in-pvector-reverse pv)])
               elem)
             (if core-available?
                 (with-core-pvector-builder add!
                   (for ([elem (in-pvector-reverse pv)])
                     (add! elem)))
                 (fallback:for/pvector ([elem (in-pvector-reverse pv)]) elem))))]
    [(_ ([elem (in-list lst-expr)]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (free-identifier=? #'elem #'body))
     #'(let ([lst lst-expr])
         (if (list? lst)
             (list->pvector lst)
             (if core-available?
                 (with-core-pvector-builder add!
                   (for ([elem (in-list lst)])
                     (add! elem)))
                 (fallback:for/pvector ([elem (in-list lst)]) elem))))]
    [(_ ([elem (in-vector vec-expr)]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (free-identifier=? #'elem #'body))
     #'(let ([vec vec-expr])
         (if (vector? vec)
             (vector->pvector vec)
             (if core-available?
                 (with-core-pvector-builder add!
                   (for ([elem (in-vector vec)])
                     (add! elem)))
                 (fallback:for/pvector ([elem (in-vector vec)]) elem))))]
    [(_ ([elem seq-id]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (identifier? #'seq-id)
          (free-identifier=? #'elem #'body))
     #'(let ([seq seq-id])
         (if (pvector? seq)
             seq
             (if core-available?
                 (with-core-pvector-builder add!
                   (for ([elem seq])
                     (add! elem)))
                 (fallback:for/pvector ([elem seq]) elem))))]
    [(_ ([elem (in-range end)]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (free-identifier=? #'elem #'body))
     #'(in-range-end->pvector end)]
    [(_ ([elem (in-range range-arg ...)]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (free-identifier=? #'elem #'body))
     #'(sequence->pvector (in-range range-arg ...))]
    [(_ (clause ...) body ...)
     #'(if core-available?
           (with-core-pvector-builder add!
             (for (clause ...)
               (add! (let () body ...))))
           (fallback:for/pvector (clause ...) body ...))]))

(define-syntax (for*/pvector stx)
  (syntax-case stx (in-range in-list in-vector in-pvector in-pvector-reverse)
    [(_ #:length len #:fill fill-expr (clause ...) body ...)
     (small-core-length-literal? #'len)
     #'(small-vector->pvector
        (for*/vector #:length len #:fill fill-expr
                     (clause ...) body ...)
        len)]
    [(_ #:length length-expr #:fill fill-expr (clause ...) body ...)
     #'(fresh-vector->pvector
        (for*/vector #:length length-expr #:fill fill-expr
                     (clause ...) body ...))]
    [(_ #:length end ([elem (in-range end*)]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (free-identifier=? #'elem #'body)
          (identifier? #'end)
          (identifier? #'end*)
          (free-identifier=? #'end #'end*))
     #'(in-range-length-end->pvector end)]
    [(_ #:length len ([elem (in-range end)]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (free-identifier=? #'elem #'body)
          (exact-nonnegative-integer? (syntax-e #'len))
          (equal? (syntax-e #'len) (syntax-e #'end)))
     #'(sequence->pvector len)]
    [(_ #:length end ([elem (in-range start end*)]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (free-identifier=? #'elem #'body)
          (identifier? #'end)
          (identifier? #'end*)
          (free-identifier=? #'end #'end*)
          (equal? (syntax-e #'start) 0))
     #'(sequence->pvector end)]
    [(_ #:length end ([elem (in-range start end* step)]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (free-identifier=? #'elem #'body)
          (identifier? #'end)
          (identifier? #'end*)
          (free-identifier=? #'end #'end*)
          (equal? (syntax-e #'start) 0)
          (equal? (syntax-e #'step) 1))
     #'(sequence->pvector end)]
    [(_ #:length length-expr ([elem (in-pvector pv-expr)]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (free-identifier=? #'elem #'body))
     #'(let ([len length-expr])
         (if (exact-nonnegative-integer? len)
             (let ([pv pv-expr])
               (if (and (pvector? pv)
                        (= len (pvector-length pv)))
                   pv
                   (fresh-vector->pvector
                    (for*/vector #:length len ([elem (in-pvector pv)])
                      elem))))
             (fresh-vector->pvector
              (for*/vector #:length len ([elem (in-pvector pv-expr)])
                elem))))]
    [(_ #:length length-expr ([elem (in-vector vec-expr)]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (free-identifier=? #'elem #'body))
     #'(let ([len length-expr])
         (if (exact-nonnegative-integer? len)
             (let ([vec vec-expr])
               (if (and (vector? vec)
                        (= len (vector-length vec)))
                   (vector->pvector vec)
                   (fresh-vector->pvector
                    (for*/vector #:length len ([elem (in-vector vec)])
                      elem))))
             (fresh-vector->pvector
              (for*/vector #:length len ([elem (in-vector vec-expr)])
                elem))))]
    [(_ #:length length-expr ([elem seq-id]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (identifier? #'seq-id)
          (free-identifier=? #'elem #'body))
     #'(let ([len length-expr])
         (if (exact-nonnegative-integer? len)
             (let ([seq seq-id])
               (cond
                 [(and (pvector? seq)
                       (= len (pvector-length seq)))
                  seq]
                 [(and (vector? seq)
                       (= len (vector-length seq)))
                  (vector->pvector seq)]
                 [else
                  (fresh-vector->pvector
                   (for*/vector #:length len ([elem seq])
                     elem))]))
             (fresh-vector->pvector
              (for*/vector #:length len ([elem seq-id])
                elem))))]
    [(_ #:length len (clause ...) body ...)
     (small-core-length-literal? #'len)
     #'(small-vector->pvector
        (for*/vector #:length len
                     (clause ...) body ...)
        len)]
    [(_ #:length length-expr (clause ...) body ...)
     #'(fresh-vector->pvector
        (for*/vector #:length length-expr
                     (clause ...) body ...))]
    [(_ ([elem (in-pvector pv-expr)]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (free-identifier=? #'elem #'body))
     #'(let ([pv pv-expr])
         (if (pvector? pv)
             pv
             (if core-available?
                 (with-core-pvector-builder add!
                   (for* ([elem (in-pvector pv)])
                     (add! elem)))
                 (fallback:for*/pvector ([elem (in-pvector pv)]) elem))))]
    [(_ ([elem (in-pvector-reverse pv-expr)]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (free-identifier=? #'elem #'body))
     #'(let ([pv pv-expr])
         (if (pvector? pv)
             (for*/pvector #:length (pvector-length pv)
                           ([elem (in-pvector-reverse pv)])
               elem)
             (if core-available?
                 (with-core-pvector-builder add!
                   (for* ([elem (in-pvector-reverse pv)])
                     (add! elem)))
                 (fallback:for*/pvector ([elem (in-pvector-reverse pv)]) elem))))]
    [(_ ([elem (in-list lst-expr)]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (free-identifier=? #'elem #'body))
     #'(let ([lst lst-expr])
         (if (list? lst)
             (list->pvector lst)
             (if core-available?
                 (with-core-pvector-builder add!
                   (for* ([elem (in-list lst)])
                     (add! elem)))
                 (fallback:for*/pvector ([elem (in-list lst)]) elem))))]
    [(_ ([elem (in-vector vec-expr)]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (free-identifier=? #'elem #'body))
     #'(let ([vec vec-expr])
         (if (vector? vec)
             (vector->pvector vec)
             (if core-available?
                 (with-core-pvector-builder add!
                   (for* ([elem (in-vector vec)])
                     (add! elem)))
                 (fallback:for*/pvector ([elem (in-vector vec)]) elem))))]
    [(_ ([elem seq-id]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (identifier? #'seq-id)
          (free-identifier=? #'elem #'body))
     #'(let ([seq seq-id])
         (if (pvector? seq)
             seq
             (if core-available?
                 (with-core-pvector-builder add!
                   (for* ([elem seq])
                     (add! elem)))
                 (fallback:for*/pvector ([elem seq]) elem))))]
    [(_ ([elem (in-range end)]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (free-identifier=? #'elem #'body))
     #'(in-range-end->pvector end)]
    [(_ ([elem (in-range range-arg ...)]) body)
     (and (identifier? #'elem)
          (identifier? #'body)
          (free-identifier=? #'elem #'body))
     #'(sequence->pvector (in-range range-arg ...))]
    [(_ (clause ...) body ...)
     #'(if core-available?
           (with-core-pvector-builder add!
             (for* (clause ...)
               (add! (let () body ...))))
           (fallback:for*/pvector (clause ...) body ...))]))

(define pvector-for-each
  (if core-available?
      core-pvector-for-each
      fallback:pvector-for-each))
