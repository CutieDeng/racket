#lang racket/base

(require racket/match
         racket/vector
         racket/unsafe/ops
         (only-in "for.rkt"
                  define-sequence-syntax
                  range-sequence->exact-integer-range-info
                  range-sequence->exact-nonnegative-integer)
         (prefix-in fallback: "pvector-chunked.rkt")
         (for-syntax racket/base))

(provide pvector?
         pvector-empty
         pvector-empty?
         pvector
         make-pvector
         small-immutable-vector->pvector
         list->pvector
         pvector->list
         vector->pvector
         pvector->vector
         pvector->chunk-vector
         pvector->chunk-vector/shared
         pvector-lookup-chunk
         sequence->pvector
         pvector-length
         pvector-ref
         pvector-set
         pvector-view-left
         pvector-view-right
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
         pvector-runtime-adapter-backend
         pvector-runtime-adapter-core-available?)

(define (maybe-kernel name)
  (with-handlers ([exn:fail? (lambda (_) #f)])
    (dynamic-require ''#%kernel name)))

(define core-pvector? (maybe-kernel 'core-pvector?))
(define core-pvector-empty (maybe-kernel 'core-pvector-empty))
(define core-pvector-empty? (maybe-kernel 'core-pvector-empty?))
(define core-pvector-length (maybe-kernel 'core-pvector-length))
(define core-pvector-shape-stats (maybe-kernel 'core-pvector-shape-stats))
(define core-vector->pvector (maybe-kernel 'core-vector->pvector))
(define core-fixed-chunks->pvector (maybe-kernel 'core-fixed-chunks->pvector))
(define core-chunks->pvector (maybe-kernel 'core-chunks->pvector))
(define core-list->pvector (maybe-kernel 'core-list->pvector))
(define core-make-pvector (maybe-kernel 'core-make-pvector))
(define core-pvector->vector (maybe-kernel 'core-pvector->vector))
(define core-pvector->chunk-vector (maybe-kernel 'core-pvector->chunk-vector))
(define core-pvector->chunk-vector/shared
  (maybe-kernel 'core-pvector->chunk-vector/shared))
(define core-pvector-lookup-chunk (maybe-kernel 'core-pvector-lookup-chunk))
(define core-pvector->list (maybe-kernel 'core-pvector->list))
(define core-pvector-ref (maybe-kernel 'core-pvector-ref))
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

(define core-bindings
  (list core-pvector?
        core-pvector-empty
        core-pvector-empty?
        core-pvector-length
        core-pvector-shape-stats
        core-vector->pvector
        core-fixed-chunks->pvector
        core-chunks->pvector
        core-list->pvector
        core-make-pvector
        core-pvector->vector
        core-pvector->chunk-vector
        core-pvector-lookup-chunk
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

(define core-available?
  (andmap procedure? core-bindings))

(define (pvector-runtime-adapter-core-available?)
  core-available?)

(define (pvector-runtime-adapter-backend)
  (if core-available? 'core 'chunked))

(define core-builder-chunk-size 64)

(define-syntax-rule (with-core-pvector-builder emit body ...)
  (let* ([size core-builder-chunk-size]
         [chunks '()]
         [chunk-count 0]
         [len 0]
         [uniform? #t]
         [uniform-value #f]
         [chunk (make-vector size)]
         [chunk-pos 0])
    (define (flush!)
      (when (unsafe-fx> chunk-pos 0)
        (define chunk*
          (if (unsafe-fx= chunk-pos size)
              chunk
              (vector-copy chunk 0 chunk-pos)))
        (set! chunks (cons (vector->immutable-vector chunk*) chunks))
        (set! chunk-count (unsafe-fx+ chunk-count 1))
        (set! chunk (make-vector size))
        (set! chunk-pos 0)))
    (let-syntax ([emit
                  (syntax-rules ()
                    [(_ value)
                     (let ([value* value])
                       (when uniform?
                         (if (unsafe-fx= len 0)
                             (set! uniform-value value*)
                             (unless (eq? value* uniform-value)
                               (set! uniform? #f))))
                       (unsafe-vector-set! chunk chunk-pos value*)
                       (set! chunk-pos (unsafe-fx+ chunk-pos 1))
                       (set! len (unsafe-fx+ len 1))
                       (when (unsafe-fx= chunk-pos size)
                         (flush!)))])])
      body ...)
    (cond
      [(unsafe-fx= len 0)
       (core-pvector-empty)]
      [uniform?
       (core-make-pvector len uniform-value)]
      [else
       (flush!)
       (define chunk-vector (make-vector chunk-count))
       (let loop ([chunks chunks]
                  [chunk-idx (unsafe-fx- chunk-count 1)])
         (unless (null? chunks)
           (unsafe-vector-set! chunk-vector chunk-idx (car chunks))
           (loop (cdr chunks) (unsafe-fx- chunk-idx 1))))
       (core-fixed-chunks->pvector chunk-vector
                                   len
                                   size)])))

(define (small-immutable-vector->pvector chunk len)
  (if core-available?
      (core-fixed-chunks->pvector
       (vector chunk)
       len
       core-builder-chunk-size)
      (fallback:vector->pvector chunk)))

(define (small-vector->pvector vec len)
  (if core-available?
      (small-immutable-vector->pvector (vector->immutable-vector vec) len)
      (fallback:vector->pvector vec)))

(define pvector?
  (if core-available? core-pvector? fallback:pvector?))

(define pvector-empty
  (if core-available? core-pvector-empty fallback:pvector-empty))

(define pvector-empty?
  (if core-available? core-pvector-empty? fallback:pvector-empty?))

(define pvector-length
  (if core-available? core-pvector-length fallback:pvector-length))

(define vector->pvector/backend
  (if core-available? core-vector->pvector fallback:vector->pvector))

(define list->pvector/backend
  (if core-available? core-list->pvector fallback:list->pvector))

(define (vector->pvector vec)
  (if (and (vector? vec) (zero? (vector-length vec)))
      (pvector-empty)
      (vector->pvector/backend vec)))

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
    (for/list ([len (in-range 1 (add1 64))])
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
          (unsafe-fx<= len 64))
     (small-make-pvector-dispatch len value)]
    [core-available?
     (core-make-pvector len value)]
    [else
     (fallback:make-pvector len value)]))

(begin-for-syntax
  (define pvector-single-chunk-arity-limit 64)
  (define pvector-fixed-vector-arity-limit 112)

  (define (small-pvector-proc-clause stx len)
    (define ids (generate-temporaries
                 (for/list ([i (in-range len)]) 'elem)))
    (if (<= len pvector-single-chunk-arity-limit)
        (with-syntax ([(elem ...) ids]
                      [len (datum->syntax stx len)])
          #'[(elem ...)
             (small-immutable-vector->pvector (vector-immutable elem ...) len)])
        (with-syntax ([(elem ...) ids])
          #'[(elem ...)
             (vector->pvector/backend (vector-immutable elem ...))])))

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

(define pvector->chunk-vector
  (if core-available? core-pvector->chunk-vector fallback:pvector->chunk-vector))

(define pvector->chunk-vector/shared
  (cond
    [(and core-available? core-pvector->chunk-vector/shared)
     core-pvector->chunk-vector/shared]
    [core-available? core-pvector->chunk-vector]
    [else fallback:pvector->chunk-vector/shared]))

(define pvector-lookup-chunk
  (if core-available? core-pvector-lookup-chunk fallback:pvector-lookup-chunk))

(define pvector->list
  (if core-available? core-pvector->list fallback:pvector->list))

(define (regular-chunk-size chunks chunk-count)
  (cond
    [(unsafe-fx= chunk-count 0) 1]
    [else
     (define size (unsafe-vector-length (unsafe-vector-ref chunks 0)))
     (and (unsafe-fx> size 0)
          (let loop ([chunk-pos 1])
            (cond
              [(unsafe-fx= chunk-pos chunk-count) size]
              [(unsafe-fx= chunk-pos (unsafe-fx- chunk-count 1))
               (and (unsafe-fx<= (unsafe-vector-length
                                   (unsafe-vector-ref chunks chunk-pos))
                                  size)
                    size)]
              [(unsafe-fx= (unsafe-vector-length
                            (unsafe-vector-ref chunks chunk-pos))
                           size)
               (loop (unsafe-fx+ chunk-pos 1))]
              [else #f])))]))

(define (small-integer-range->pvector len)
  (define vec (make-vector len))
  (let loop ([i 0])
    (unless (unsafe-fx= i len)
      (unsafe-vector-set! vec i i)
      (loop (unsafe-fx+ i 1))))
  (small-vector->pvector vec len))

(define (integer-range->pvector len)
  (cond
    [(unsafe-fx= len 0)
     (core-pvector-empty)]
    [(unsafe-fx<= len core-builder-chunk-size)
     (small-integer-range->pvector len)]
    [else
     (define size core-builder-chunk-size)
     (define chunk-count
       (unsafe-fx+ (unsafe-fxquotient (unsafe-fx- len 1) size) 1))
     (define chunks (make-vector chunk-count))
     (let chunk-loop ([chunk-index 0])
       (unless (unsafe-fx= chunk-index chunk-count)
         (define start (unsafe-fx* chunk-index size))
         (define chunk-len (min size (unsafe-fx- len start)))
         (define chunk (make-vector chunk-len))
         (let elem-loop ([elem-index 0])
           (unless (unsafe-fx= elem-index chunk-len)
             (unsafe-vector-set! chunk
                                 elem-index
                                 (unsafe-fx+ start elem-index))
             (elem-loop (unsafe-fx+ elem-index 1))))
         (unsafe-vector-set! chunks
                             chunk-index
                             (vector->immutable-vector chunk))
         (chunk-loop (unsafe-fx+ chunk-index 1))))
     (core-fixed-chunks->pvector chunks len size)]))

(define (arithmetic-range->pvector start step len)
  (cond
    [(unsafe-fx= len 0)
     (core-pvector-empty)]
    [else
     (define size core-builder-chunk-size)
     (define chunk-count
       (unsafe-fx+ (unsafe-fxquotient (unsafe-fx- len 1) size) 1))
     (define chunks (make-vector chunk-count))
     (let chunk-loop ([chunk-index 0])
       (unless (unsafe-fx= chunk-index chunk-count)
         (define range-start (unsafe-fx* chunk-index size))
         (define chunk-len (min size (unsafe-fx- len range-start)))
         (define chunk (make-vector chunk-len))
         (let elem-loop ([elem-index 0]
                         [elem (+ start (* range-start step))])
           (unless (unsafe-fx= elem-index chunk-len)
             (unsafe-vector-set! chunk elem-index elem)
             (elem-loop (unsafe-fx+ elem-index 1) (+ elem step))))
         (unsafe-vector-set! chunks
                             chunk-index
                             (vector->immutable-vector chunk))
         (chunk-loop (unsafe-fx+ chunk-index 1))))
     (core-fixed-chunks->pvector chunks len size)]))

(define (arithmetic-range-info->pvector info)
  (define start (vector-ref info 0))
  (define step (vector-ref info 1))
  (define len (vector-ref info 2))
  (if (and core-available? (fixnum? len))
      (arithmetic-range->pvector start step len)
      (vector->pvector
       (for/vector #:length len ([i (in-range len)])
         (+ start (* i step))))))

(define (sequence->pvector seq)
  (cond
    [(pvector? seq) seq]
    [(range-sequence->exact-nonnegative-integer seq)
     => (lambda (len)
          (if (and core-available? (fixnum? len))
              (integer-range->pvector len)
              (vector->pvector
               (for/vector #:length len ([elem (in-range len)])
                 elem))))]
    [(range-sequence->exact-integer-range-info seq)
     => arithmetic-range-info->pvector]
    [(exact-nonnegative-integer? seq)
     (if (and core-available? (fixnum? seq))
         (integer-range->pvector seq)
         (vector->pvector
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
      (vector->pvector
       (for/vector #:length end ([elem (in-range end)])
         elem))))

(define pvector-ref
  (if core-available? core-pvector-ref fallback:pvector-ref))

(define pvector-ref/fast pvector-ref)

(define pvector-set
  (if core-available? core-pvector-set fallback:pvector-set))

(define pvector-set/fast pvector-set)

(define pvector-view-left
  (if core-available? core-pvector-view-left fallback:pvector-view-left))

(define pvector-view-right
  (if core-available? core-pvector-view-right fallback:pvector-view-right))

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
  (define chunks (pvector->chunk-vector/shared pv))
  (define chunk-count (unsafe-vector-length chunks))
  (define size (regular-chunk-size chunks chunk-count))
  (cond
    [size
     (define len (pvector-length pv))
     (define pos-elem
       (if (unsafe-fx= size core-builder-chunk-size)
           (lambda (index)
             (unsafe-vector-ref
              (unsafe-vector-ref chunks (unsafe-fxrshift index 6))
              (unsafe-fxand index 63)))
           (lambda (index)
             (define chunk-pos (unsafe-fxquotient index size))
             (unsafe-vector-ref
              (unsafe-vector-ref chunks chunk-pos)
              (unsafe-fx- index (unsafe-fx* chunk-pos size))))))
     (make-do-sequence
      (lambda ()
        (values pos-elem
                (lambda (index) (unsafe-fx+ index 1))
                0
                (lambda (index) (unsafe-fx< index len))
                (lambda (elem) #t)
                (lambda (pos elem) #t))))]
    [else
     (define first-chunk
       (if (unsafe-fx> chunk-count 0)
           (unsafe-vector-ref chunks 0)
           #f))
     (define first-len
       (if first-chunk (unsafe-vector-length first-chunk) 0))
     (define (pos-elem pos)
       (unsafe-vector-ref (unsafe-vector-ref pos 2) (unsafe-vector-ref pos 1)))
     (define (next-pos pos)
       (define chunk-pos (unsafe-vector-ref pos 0))
       (define elem-idx (unsafe-vector-ref pos 1))
       (define chunk-len (unsafe-vector-ref pos 3))
       (define next-elem-idx (unsafe-fx+ elem-idx 1))
       (cond
         [(unsafe-fx< next-elem-idx chunk-len)
          (unsafe-vector-set! pos 1 next-elem-idx)]
         [else
          (define next-chunk-pos (unsafe-fx+ chunk-pos 1))
          (unsafe-vector-set! pos 0 next-chunk-pos)
          (unsafe-vector-set! pos 1 0)
          (when (unsafe-fx< next-chunk-pos chunk-count)
            (define next-chunk (unsafe-vector-ref chunks next-chunk-pos))
            (unsafe-vector-set! pos 2 next-chunk)
            (unsafe-vector-set! pos 3 (unsafe-vector-length next-chunk)))])
       pos)
     (define (pos-more? pos)
       (unsafe-fx< (unsafe-vector-ref pos 0) chunk-count))
     (make-do-sequence
      (lambda ()
        (values pos-elem
                next-pos
                (vector 0 0 first-chunk first-len)
                pos-more?
                (lambda (elem) #t)
                (lambda (pos elem) #t))))]))

(define (in-pvector-reverse/proc pv)
  (define chunks (pvector->chunk-vector/shared pv))
  (define chunk-count (unsafe-vector-length chunks))
  (define last-chunk-pos (unsafe-fx- chunk-count 1))
  (define size (regular-chunk-size chunks chunk-count))
  (cond
    [size
     (define len (pvector-length pv))
     (define pos-elem
       (if (unsafe-fx= size core-builder-chunk-size)
           (lambda (index)
             (unsafe-vector-ref
              (unsafe-vector-ref chunks (unsafe-fxrshift index 6))
              (unsafe-fxand index 63)))
           (lambda (index)
             (define chunk-pos (unsafe-fxquotient index size))
             (unsafe-vector-ref
              (unsafe-vector-ref chunks chunk-pos)
              (unsafe-fx- index (unsafe-fx* chunk-pos size))))))
     (make-do-sequence
      (lambda ()
        (values pos-elem
                (lambda (index) (unsafe-fx- index 1))
                (unsafe-fx- len 1)
                (lambda (index) (unsafe-fx>= index 0))
                (lambda (elem) #t)
                (lambda (pos elem) #t))))]
    [else
     (define last-chunk
       (if (unsafe-fx>= last-chunk-pos 0)
           (unsafe-vector-ref chunks last-chunk-pos)
           #f))
     (define last-elem-idx
       (if last-chunk
           (unsafe-fx- (unsafe-vector-length last-chunk) 1)
           -1))
     (define (pos-elem pos)
       (unsafe-vector-ref (unsafe-vector-ref pos 2) (unsafe-vector-ref pos 1)))
     (define (next-pos pos)
       (define chunk-pos (unsafe-vector-ref pos 0))
       (define elem-idx (unsafe-vector-ref pos 1))
       (define next-elem-idx (unsafe-fx- elem-idx 1))
       (cond
         [(unsafe-fx>= next-elem-idx 0)
          (unsafe-vector-set! pos 1 next-elem-idx)]
         [else
          (define next-chunk-pos (unsafe-fx- chunk-pos 1))
          (unsafe-vector-set! pos 0 next-chunk-pos)
          (if (unsafe-fx>= next-chunk-pos 0)
              (let ([next-chunk (unsafe-vector-ref chunks next-chunk-pos)])
                (unsafe-vector-set! pos 2 next-chunk)
                (unsafe-vector-set! pos 1
                                    (unsafe-fx- (unsafe-vector-length next-chunk) 1)))
              (unsafe-vector-set! pos 1 -1))])
       pos)
     (define (pos-more? pos)
       (unsafe-fx>= (unsafe-vector-ref pos 0) 0))
     (make-do-sequence
      (lambda ()
        (values pos-elem
                next-pos
                (vector last-chunk-pos last-elem-idx last-chunk)
                pos-more?
                (lambda (elem) #t)
                (lambda (pos elem) #t))))]))

(define-sequence-syntax in-pvector
  (lambda () #'in-pvector/proc)
  (lambda (stx)
    (syntax-case stx ()
      [[(elem) (_ pv-expr)]
       #'[(elem)
          (:do-in
           ([(chunks) (pvector->chunk-vector/shared pv-expr)])
           (begin
             (define chunk-count (unsafe-vector-length chunks))
             (define first-chunk
               (if (unsafe-fx> chunk-count 0)
                   (unsafe-vector-ref chunks 0)
                   #f))
             (define first-len
               (if first-chunk (unsafe-vector-length first-chunk) 0)))
           ([chunk-pos 0]
            [elem-idx 0]
            [chunk first-chunk]
            [chunk-len first-len])
           (unsafe-fx< chunk-pos chunk-count)
           ([(elem next-chunk-pos next-elem-idx next-chunk next-chunk-len)
             (let ([elem (unsafe-vector-ref chunk elem-idx)]
                   [next-elem-idx (unsafe-fx+ elem-idx 1)])
               (cond
                 [(unsafe-fx< next-elem-idx chunk-len)
                  (values elem chunk-pos next-elem-idx chunk chunk-len)]
                 [else
                  (define next-chunk-pos (unsafe-fx+ chunk-pos 1))
                  (if (unsafe-fx< next-chunk-pos chunk-count)
                      (let ([next-chunk (unsafe-vector-ref chunks next-chunk-pos)])
                        (values elem
                                next-chunk-pos
                                0
                                next-chunk
                                (unsafe-vector-length next-chunk)))
                      (values elem
                              next-chunk-pos
                              0
                              chunk
                              chunk-len))]))])
           #t
           #t
           (next-chunk-pos next-elem-idx next-chunk next-chunk-len))]]
      [_ #f])))

(define-sequence-syntax in-pvector-reverse
  (lambda () #'in-pvector-reverse/proc)
  (lambda (stx)
    (syntax-case stx ()
      [[(elem) (_ pv-expr)]
       #'[(elem)
          (:do-in
           ([(chunks) (pvector->chunk-vector/shared pv-expr)])
           (begin
             (define chunk-count (unsafe-vector-length chunks))
             (define last-chunk-pos (unsafe-fx- chunk-count 1))
             (define last-chunk
               (if (unsafe-fx>= last-chunk-pos 0)
                   (unsafe-vector-ref chunks last-chunk-pos)
                   #f))
             (define last-elem-idx
               (if last-chunk
                   (unsafe-fx- (unsafe-vector-length last-chunk) 1)
                   -1)))
           ([chunk-pos last-chunk-pos]
            [elem-idx last-elem-idx]
            [chunk last-chunk])
           (unsafe-fx>= chunk-pos 0)
           ([(elem next-chunk-pos next-elem-idx next-chunk)
             (let ([elem (unsafe-vector-ref chunk elem-idx)]
                   [next-elem-idx (unsafe-fx- elem-idx 1)])
               (cond
                 [(unsafe-fx>= next-elem-idx 0)
                  (values elem chunk-pos next-elem-idx chunk)]
                 [else
                  (define next-chunk-pos (unsafe-fx- chunk-pos 1))
                  (if (unsafe-fx>= next-chunk-pos 0)
                      (let ([next-chunk (unsafe-vector-ref chunks next-chunk-pos)])
                        (values elem
                                next-chunk-pos
                                (unsafe-fx- (unsafe-vector-length next-chunk) 1)
                                next-chunk))
                      (values elem
                              next-chunk-pos
                              -1
                              chunk))]))])
           #t
           #t
           (next-chunk-pos next-elem-idx next-chunk))]]
      [_ #f])))

(define (in-pvector/index/proc pv)
  (define chunks (pvector->chunk-vector/shared pv))
  (define chunk-count (unsafe-vector-length chunks))
  (define size (regular-chunk-size chunks chunk-count))
  (cond
    [size
     (define len (pvector-length pv))
     (define pos-elem
       (if (unsafe-fx= size core-builder-chunk-size)
           (lambda (index)
             (values
              (unsafe-vector-ref
               (unsafe-vector-ref chunks (unsafe-fxrshift index 6))
               (unsafe-fxand index 63))
              index))
           (lambda (index)
             (define chunk-pos (unsafe-fxquotient index size))
             (values
              (unsafe-vector-ref
               (unsafe-vector-ref chunks chunk-pos)
               (unsafe-fx- index (unsafe-fx* chunk-pos size)))
              index))))
     (make-do-sequence
      (lambda ()
        (values pos-elem
                (lambda (index) (unsafe-fx+ index 1))
                0
                (lambda (index) (unsafe-fx< index len))
                (lambda (elem index) #t)
                (lambda (pos elem index) #t))))]
    [else
     (define first-chunk
       (if (unsafe-fx> chunk-count 0)
           (unsafe-vector-ref chunks 0)
           #f))
     (define first-len
       (if first-chunk (unsafe-vector-length first-chunk) 0))
     (define (pos-elem pos)
       (values (unsafe-vector-ref (unsafe-vector-ref pos 3)
                                  (unsafe-vector-ref pos 1))
               (unsafe-vector-ref pos 2)))
     (define (next-pos pos)
       (define chunk-pos (unsafe-vector-ref pos 0))
       (define elem-idx (unsafe-vector-ref pos 1))
       (define elem-pos (unsafe-vector-ref pos 2))
       (define chunk-len (unsafe-vector-ref pos 4))
       (define next-elem-idx (unsafe-fx+ elem-idx 1))
       (define next-elem-pos (unsafe-fx+ elem-pos 1))
       (unsafe-vector-set! pos 2 next-elem-pos)
       (cond
         [(unsafe-fx< next-elem-idx chunk-len)
          (unsafe-vector-set! pos 1 next-elem-idx)]
         [else
          (define next-chunk-pos (unsafe-fx+ chunk-pos 1))
          (unsafe-vector-set! pos 0 next-chunk-pos)
          (unsafe-vector-set! pos 1 0)
          (when (unsafe-fx< next-chunk-pos chunk-count)
            (define next-chunk (unsafe-vector-ref chunks next-chunk-pos))
            (unsafe-vector-set! pos 3 next-chunk)
            (unsafe-vector-set! pos 4 (unsafe-vector-length next-chunk)))])
       pos)
     (define (pos-more? pos)
       (unsafe-fx< (unsafe-vector-ref pos 0) chunk-count))
     (make-do-sequence
      (lambda ()
        (values pos-elem
                next-pos
                (vector 0 0 0 first-chunk first-len)
                pos-more?
                (lambda (elem index) #t)
                (lambda (pos elem index) #t))))]))

(define-sequence-syntax in-pvector/index
  (lambda () #'in-pvector/index/proc)
  (lambda (stx)
    (syntax-case stx ()
      [[(elem index) (_ pv-expr)]
       #'[(elem index)
          (:do-in
           ([(chunks) (pvector->chunk-vector/shared pv-expr)])
           (begin
             (define chunk-count (unsafe-vector-length chunks))
             (define first-chunk
               (if (unsafe-fx> chunk-count 0)
                   (unsafe-vector-ref chunks 0)
                   #f))
             (define first-len
               (if first-chunk (unsafe-vector-length first-chunk) 0)))
           ([chunk-pos 0]
            [elem-idx 0]
            [elem-pos 0]
            [chunk first-chunk]
            [chunk-len first-len])
           (unsafe-fx< chunk-pos chunk-count)
           ([(elem index next-chunk-pos next-elem-idx next-elem-pos next-chunk next-chunk-len)
             (let ([elem (unsafe-vector-ref chunk elem-idx)]
                   [next-elem-idx (unsafe-fx+ elem-idx 1)]
                   [next-elem-pos (unsafe-fx+ elem-pos 1)])
               (cond
                 [(unsafe-fx< next-elem-idx chunk-len)
                  (values elem
                          elem-pos
                          chunk-pos
                          next-elem-idx
                          next-elem-pos
                          chunk
                          chunk-len)]
                 [else
                  (define next-chunk-pos (unsafe-fx+ chunk-pos 1))
                  (if (unsafe-fx< next-chunk-pos chunk-count)
                      (let ([next-chunk (unsafe-vector-ref chunks next-chunk-pos)])
                        (values elem
                                elem-pos
                                next-chunk-pos
                                0
                                next-elem-pos
                                next-chunk
                                (unsafe-vector-length next-chunk)))
                      (values elem
                              elem-pos
                              next-chunk-pos
                              0
                              next-elem-pos
                              chunk
                              chunk-len))]))])
           #t
           #t
           (next-chunk-pos next-elem-idx next-elem-pos next-chunk next-chunk-len))]]
      [_ #f])))

(define-syntax in-pvector-indexed
  (make-rename-transformer #'in-pvector/index))

(define pvector-shape-stats
  (if core-available?
      core-pvector-shape-stats
      fallback:pvector-shape-stats))

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
     #'(vector->pvector
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
                   (vector->pvector
                    (for/vector #:length len ([elem (in-pvector pv)])
                      elem))))
             (vector->pvector
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
                   (vector->pvector
                    (for/vector #:length len ([elem (in-vector vec)])
                      elem))))
             (vector->pvector
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
                  (vector->pvector
                   (for/vector #:length len ([elem seq])
                     elem))]))
             (vector->pvector
              (for/vector #:length len ([elem seq-id])
                elem))))]
    [(_ #:length len (clause ...) body ...)
     (small-core-length-literal? #'len)
     #'(small-vector->pvector
        (for/vector #:length len
                    (clause ...) body ...)
        len)]
    [(_ #:length length-expr (clause ...) body ...)
     #'(vector->pvector
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
     #'(vector->pvector
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
                   (vector->pvector
                    (for*/vector #:length len ([elem (in-pvector pv)])
                      elem))))
             (vector->pvector
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
                   (vector->pvector
                    (for*/vector #:length len ([elem (in-vector vec)])
                      elem))))
             (vector->pvector
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
                  (vector->pvector
                   (for*/vector #:length len ([elem seq])
                     elem))]))
             (vector->pvector
              (for*/vector #:length len ([elem seq-id])
                elem))))]
    [(_ #:length len (clause ...) body ...)
     (small-core-length-literal? #'len)
     #'(small-vector->pvector
        (for*/vector #:length len
                     (clause ...) body ...)
        len)]
    [(_ #:length length-expr (clause ...) body ...)
     #'(vector->pvector
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
      (lambda (pv proc)
        (unless (or (eq? proc void)
                    (eq? proc values))
          (define chunks (pvector->chunk-vector/shared pv))
          (for* ([chunk (in-vector chunks)]
                 [elem (in-vector chunk)])
            (proc elem))))))
