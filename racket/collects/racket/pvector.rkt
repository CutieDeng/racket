#lang racket/base

(require (prefix-in raw: "private/pvector-runtime-adapter.rkt")
         "private/serialize-structs.rkt"
         (only-in "private/for.rkt"
                  define-sequence-syntax
                  prop:gen-sequence
                  prop:stream
                  range-sequence->exact-integer-range-info
                  range-sequence->exact-nonnegative-integer)
         '#%flfxnum
         racket/match
         racket/performance-hint
         (only-in racket/vector vector-copy)
         racket/unsafe/ops
         (for-syntax racket/base))

(provide pvector?
         pvector-empty
         pvector-empty?
         pvector
         make-pvector
         list->pvector
         pvector->list
         vector->pvector
         pvector->vector
         sequence->pvector
         pvector-length
         pvector-ref
         pvector-set
         pvector-first
         pvector-last
         pvector-cons-left
         pvector-cons-right
         pvector-pop-left
         pvector-pop-right
         pvector-append
         pvector-map
         pvector-for-each
         pvector-insert
         pvector-delete
         pvector-take
         pvector-drop
         pvector-take-right
         pvector-drop-right
         pvector-subvector
         pvector-split
         pvector-split-at
         in-pvector
         in-pvector-reverse
         for/pvector
         for*/pvector
         pvector*)

(struct pvector-wrapper (tree length)
  #:sealed
  #:property prop:custom-write
  (lambda (pv port mode) (pvector-print pv port mode))
  #:property prop:equal+hash
  (list (lambda (pv other recur) (pvector-equal? pv other recur))
        (lambda (pv recur) (pvector-hash-code pv recur))
        (lambda (pv recur) (pvector-secondary-hash-code pv recur)))
  #:property prop:gen-sequence
  (lambda (pv) (pvector-gen-sequence pv))
  #:property prop:sequence
  (lambda (pv) (in-pvector pv))
  #:property prop:stream
  (vector
   (lambda (pv) (unsafe-fx= 0 (pvector-wrapper-length/unsafe pv)))
   (lambda (pv) (raw:pvector-view-left (pvector-wrapper-tree/unsafe pv)))
   (lambda (pv)
     (define len (pvector-wrapper-length/unsafe pv))
     (if (unsafe-fx= len 1)
         empty-pvector
         (let-values ([(_ rest)
                       (raw:pvector-pop-left (pvector-wrapper-tree/unsafe pv))])
           (wrap/len rest (unsafe-fx- len 1))))))
  #:property prop:serializable
  (make-serialize-info
   (lambda (pv) (vector (pvector->vector pv)))
   (cons 'deserialize-pvector
         (module-path-index-join '(submod "." deserialize)
                                 (variable-reference->module-path-index
                                  (#%variable-reference))))
   #f
   (or (current-load-relative-directory)
       (current-directory))))

(module+ deserialize
  (provide deserialize-pvector)
  (define deserialize-pvector
    (make-deserialize-info
     (lambda (vec)
       (if (vector? vec)
           (vector->pvector vec)
           (error 'pvector "invalid deserialization")))
     (lambda () (error "should not get here; cycles not supported"))))
  (module declare-preserve-for-embedding racket/kernel))

(define empty-pvector
  (pvector-wrapper (raw:pvector-empty) 0))

(define pvector? pvector-wrapper?)

(define (pvector-wrapper-tree/unsafe pv)
  (unsafe-struct-ref pv 0))

(define (pvector-wrapper-length/unsafe pv)
  (unsafe-struct-ref pv 1))

(define (wrap/len tree len)
  (if (zero? len)
      empty-pvector
      (pvector-wrapper tree len)))

(define (wrap tree)
  (if (raw:pvector-empty? tree)
      empty-pvector
      (pvector-wrapper tree (raw:pvector-length tree))))

(define (check-pvector who v)
  (unless (pvector-wrapper? v)
    (raise-argument-error who "pvector?" v))
  v)

(define (unwrap who v)
  (pvector-wrapper-tree/unsafe (check-pvector who v)))

(define (check-nonnegative-integer who n)
  (unless (exact-nonnegative-integer? n)
    (raise-argument-error who "exact-nonnegative-integer?" n))
  n)

(define (checked-wrapper+length who pv)
  (define pv* (check-pvector who pv))
  (values pv* (pvector-wrapper-length/unsafe pv*)))

(define (check-index/wrapper who pv index)
  (check-nonnegative-integer who index)
  (define-values (pv* len) (checked-wrapper+length who pv))
  (when (>= index len)
    (raise-range-error who "pvector" "" index pv 0 (sub1 len)))
  (values pv* len))

(define (check-end-index/wrapper who pv index)
  (check-nonnegative-integer who index)
  (define-values (pv* len) (checked-wrapper+length who pv))
  (when (> index len)
    (raise-range-error who "pvector" "" index pv 0 len))
  (values pv* len))

(define (check-subrange/wrapper who pv start end)
  (check-nonnegative-integer who start)
  (define-values (pv* len) (checked-wrapper+length who pv))
  (when (> start len)
    (raise-range-error who "pvector" "" start pv 0 len))
  (check-nonnegative-integer who end)
  (when (> end len)
    (raise-range-error who "pvector" "" end pv 0 len))
  (when (> start end)
    (raise-arguments-error who
                           "starting index is greater than ending index"
                           "starting index" start
                           "ending index" end
                           "pvector" pv))
  (values pv* len start end))

(define (pvector-empty)
  empty-pvector)

(define (pvector-empty? v)
  (eq? v empty-pvector))

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
               (and (unsafe-fx<= (unsafe-vector-length (unsafe-vector-ref chunks chunk-pos))
                                  size)
                    size)]
              [(unsafe-fx= (unsafe-vector-length (unsafe-vector-ref chunks chunk-pos))
                           size)
               (loop (unsafe-fx+ chunk-pos 1))]
              [else #f])))]))

(define (shifted-regular-chunk-layout chunks chunk-count)
  (and (unsafe-fx> chunk-count 1)
       (let ([first-len (unsafe-vector-length (unsafe-vector-ref chunks 0))]
             [size (unsafe-vector-length (unsafe-vector-ref chunks 1))])
         (and (unsafe-fx> first-len 0)
              (unsafe-fx> size 0)
              (unsafe-fx<= first-len size)
              (let loop ([chunk-pos 2])
                (cond
                  [(unsafe-fx= chunk-pos chunk-count) (cons first-len size)]
                  [(unsafe-fx= chunk-pos (unsafe-fx- chunk-count 1))
                   (and (unsafe-fx<=
                         (unsafe-vector-length (unsafe-vector-ref chunks chunk-pos))
                         size)
                        (cons first-len size))]
                  [(unsafe-fx= (unsafe-vector-length
                                (unsafe-vector-ref chunks chunk-pos))
                               size)
                   (loop (unsafe-fx+ chunk-pos 1))]
                  [else #f]))))))

(define (pvector-gen-sequence pv)
  (define vec (raw:pvector->vector (pvector-wrapper-tree/unsafe pv)))
  (define len (unsafe-vector-length vec))
  (values
   (lambda (index) (unsafe-vector-ref vec index))
   #f
   (lambda (index) (unsafe-fx+ index 1))
   0
   (lambda (index) (unsafe-fx< index len))
   #f
   #f))

(define (small-immutable-vector->pvector vec len)
  (wrap/len (raw:small-immutable-vector->pvector vec len) len))

(define (single-value->pvector value)
  (wrap/len (raw:single-value->pvector value) 1))

(define (two-values->pvector left-value right-value)
  (wrap/len (raw:two-values->pvector left-value right-value) 2))

(define (three-values->pvector a b c)
  (wrap/len (raw:three-values->pvector a b c) 3))

(define (four-values->pvector a b c d)
  (wrap/len (raw:four-values->pvector a b c d) 4))

(define (small-mutable-vector->pvector vec len)
  (wrap/len (raw:fresh-vector->pvector
             (if (unsafe-fx= len (unsafe-vector-length vec))
                 vec
                 (vector-copy vec 0 len)))
            len))

(begin-for-syntax
  (define pvector-single-chunk-arity-limit 64)
  (define pvector-fixed-vector-arity-limit 112)

  (define (direct-small-values->pvector elem-stxs)
    (case (length elem-stxs)
      [(0) #'empty-pvector]
      [(1)
       (with-syntax ([(a) elem-stxs])
         #'(single-value->pvector a))]
      [(2)
       (with-syntax ([(a b) elem-stxs])
         #'(two-values->pvector a b))]
      [(3)
       (with-syntax ([(a b c) elem-stxs])
         #'(three-values->pvector a b c))]
      [(4)
       (with-syntax ([(a b c d) elem-stxs])
         #'(four-values->pvector a b c d))]
      [else #f]))

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
      [(<= len pvector-single-chunk-arity-limit)
       (with-syntax ([(elem ...) ids]
                     [len (datum->syntax stx len)])
         #'[(elem ...)
            (small-immutable-vector->pvector (vector-immutable elem ...) len)])]
      [else
       (with-syntax ([(elem ...) ids]
                     [len (datum->syntax stx len)])
         #'[(elem ...)
            (wrap/len (raw:vector->pvector (vector-immutable elem ...)) len)])]))

  (define (small-pvector-proc-clauses stx)
    (for/list ([len (in-range 1 (add1 pvector-fixed-vector-arity-limit))])
      (small-pvector-proc-clause stx len)))

  (define (small-make-pvector-clause stx len v-id)
    (cond
      [(= len 3)
       (with-syntax ([v v-id]
                     [len (datum->syntax stx len)])
         #'[(len) (three-values->pvector v v v)])]
      [(= len 4)
       (with-syntax ([v v-id]
                     [len (datum->syntax stx len)])
         #'[(len) (four-values->pvector v v v v)])]
      [else
       (with-syntax ([(elem ...)
                      (for/list ([i (in-range len)])
                        v-id)]
                     [len (datum->syntax stx len)])
         #'[(len)
            (small-immutable-vector->pvector (vector-immutable elem ...) len)])]))

  (define (small-make-pvector-clauses stx v-id)
    (for/list ([len (in-range 3 5)])
      (small-make-pvector-clause stx len v-id))))

(define-syntax (make-pvector/proc stx)
  (syntax-case stx ()
    [(_)
     (with-syntax ([(small-clause ...)
                    (small-pvector-proc-clauses stx)])
       #'(case-lambda
           [() empty-pvector]
           small-clause ...
           [elems (wrap (raw:list->pvector elems))]))]))

(define pvector/proc (make-pvector/proc))

(define-syntax (define-make-pvector/known-length stx)
  (with-syntax ([make-pvector/known-length
                 (datum->syntax stx 'make-pvector/known-length)]
                [n (datum->syntax stx 'n)]
                [v (datum->syntax stx 'v)]
                [(small-clause ...)
                 (small-make-pvector-clauses
                  stx
                  (datum->syntax stx 'v))])
    #'(define (make-pvector/known-length n v)
        (case n
          [(0) empty-pvector]
          [(1) (single-value->pvector v)]
          [(2) (two-values->pvector v v)]
          small-clause ...
          [else
           (wrap/len (raw:make-pvector n v) n)]))))

(define-make-pvector/known-length)

(define (make-pvector n [v #f])
  (check-nonnegative-integer 'make-pvector n)
  (make-pvector/known-length n v))

(define (list->pvector lst)
  (cond
    [(null? lst) empty-pvector]
    [(not (pair? lst))
     (raise-argument-error 'list->pvector "list?" lst)]
    [else
     (define a (car lst))
     (define rest (cdr lst))
     (cond
       [(null? rest)
        (single-value->pvector a)]
       [(not (pair? rest))
        (raise-argument-error 'list->pvector "list?" lst)]
       [else
        (define b (car rest))
        (define rest2 (cdr rest))
        (cond
          [(null? rest2)
           (two-values->pvector a b)]
          [(not (pair? rest2))
           (raise-argument-error 'list->pvector "list?" lst)]
          [else
           (define c (car rest2))
           (define rest3 (cdr rest2))
           (cond
             [(null? rest3)
              (three-values->pvector a b c)]
             [(not (pair? rest3))
              (raise-argument-error 'list->pvector "list?" lst)]
             [else
              (define d (car rest3))
              (define rest4 (cdr rest3))
              (cond
                [(null? rest4)
                 (four-values->pvector a b c d)]
                [else
                 (unless (list? rest4)
                   (raise-argument-error 'list->pvector "list?" lst))
                 (wrap (raw:list->pvector lst))])])])])]))

(define (pvector->list pv)
  (cond
    [(eq? pv empty-pvector) null]
    [(pvector-wrapper? pv)
     (define tree (pvector-wrapper-tree/unsafe pv))
     (case (pvector-wrapper-length/unsafe pv)
       [(1) (list (raw:pvector-view-left tree))]
       [(2) (list (raw:pvector-view-left tree)
                  (raw:pvector-view-right tree))]
       [(3) (list (raw:pvector-view-left tree)
                  (raw:pvector-ref tree 1)
                  (raw:pvector-view-right tree))]
       [(4) (list (raw:pvector-view-left tree)
                  (raw:pvector-ref tree 1)
                  (raw:pvector-ref tree 2)
                  (raw:pvector-view-right tree))]
       [else (raw:pvector->list tree)])]
    [else
     (raw:pvector->list (unwrap 'pvector->list pv))]))

(define (vector->pvector vec)
  (unless (vector? vec)
    (raise-argument-error 'vector->pvector "vector?" vec))
  (define len (vector-length vec))
  (cond
    [(zero? len) empty-pvector]
    [(= len 1) (single-value->pvector (vector-ref vec 0))]
    [(= len 2) (two-values->pvector (vector-ref vec 0) (vector-ref vec 1))]
    [(= len 3)
     (three-values->pvector
      (vector-ref vec 0)
      (vector-ref vec 1)
      (vector-ref vec 2))]
    [(= len 4)
     (four-values->pvector
      (vector-ref vec 0)
      (vector-ref vec 1)
      (vector-ref vec 2)
      (vector-ref vec 3))]
    [(<= len 64)
     (small-immutable-vector->pvector
      (if (immutable? vec)
          vec
          (vector->immutable-vector vec))
      len)]
    [else (wrap/len (raw:vector->pvector vec) len)]))

(define (pvector->vector pv)
  (cond
    [(eq? pv empty-pvector) (make-vector 0)]
    [(pvector-wrapper? pv)
     (define tree (pvector-wrapper-tree/unsafe pv))
     (case (pvector-wrapper-length/unsafe pv)
       [(1) (vector (raw:pvector-view-left tree))]
       [(2) (vector (raw:pvector-view-left tree)
                    (raw:pvector-view-right tree))]
       [(3) (vector (raw:pvector-view-left tree)
                    (raw:pvector-ref tree 1)
                    (raw:pvector-view-right tree))]
       [(4) (vector (raw:pvector-view-left tree)
                    (raw:pvector-ref tree 1)
                    (raw:pvector-ref tree 2)
                    (raw:pvector-view-right tree))]
       [else (raw:pvector->vector tree)])]
    [else
     (raw:pvector->vector (unwrap 'pvector->vector pv))]))

(begin-for-syntax
  (define (small-arithmetic-range-case stx len start-id step-id)
    (define ids (generate-temporaries
                 (for/list ([i (in-range len)]) 'elem)))
    (define bindings
      (for/list ([id (in-list ids)]
                 [i (in-naturals)])
        (if (zero? i)
            #`[#,id #,start-id]
            #`[#,id (+ #,(list-ref ids (sub1 i)) #,step-id)])))
    (with-syntax ([(binding ...) bindings]
                  [(elem ...) ids]
                  [len (datum->syntax stx len)])
      #'[(len)
         (let* (binding ...)
           (wrap/len (raw:pvector elem ...) len))]))

  (define (small-arithmetic-range-cases stx start-id step-id)
    (for/list ([len (in-range 1 33)])
      (small-arithmetic-range-case stx len start-id step-id))))

(begin-for-syntax
  (define (small-length-literal? stx)
    (define v (syntax-e stx))
    (and (exact-positive-integer? v)
         (<= v 64)))

  (define (small-literal-range->pvector stx len)
    (cond
      [(zero? len) #'empty-pvector]
      [(<= len 64)
       (define elems
         (for/list ([i (in-range len)])
           (datum->syntax stx i)))
       (or (direct-small-values->pvector elems)
           (with-syntax ([(elem ...) elems]
                         [len (datum->syntax stx len)])
             #'(small-immutable-vector->pvector (vector-immutable elem ...) len)))]
      [else
       (with-syntax ([len (datum->syntax stx len)])
         #'(wrap/len (raw:sequence->pvector len) len))])))

(begin-for-syntax
  (define (literal-range-length start end step)
    (cond
      [(zero? step) #f]
      [(positive? step)
       (and (< start end)
            (quotient (+ (- end start) step -1) step))]
      [else
       (define neg-step (- step))
       (and (> start end)
            (quotient (+ (- start end) neg-step -1) neg-step))]))

  (define (small-literal-arithmetic-range->pvector stx start step len)
    (and len
         (cond
           [(zero? len) #'empty-pvector]
           [(<= len 64)
            (define elems
              (for/list ([i (in-range len)])
                (datum->syntax stx (+ start (* i step)))))
            (or (direct-small-values->pvector elems)
                (with-syntax ([(elem ...) elems]
                              [len (datum->syntax stx len)])
                  #'(small-immutable-vector->pvector
                     (vector-immutable elem ...)
                     len)))]
           [else #f])))

  (define (small-literal-in-range->pvector stx start-stx end-stx step-stx)
    (define start (syntax-e start-stx))
    (define end (syntax-e end-stx))
    (define step (syntax-e step-stx))
    (and (exact-integer? start)
         (exact-integer? end)
         (exact-integer? step)
         (small-literal-arithmetic-range->pvector
          stx
          start
          step
          (literal-range-length start end step))))

  (define (small-literal-in-range/length->pvector stx len-stx start-stx end-stx step-stx)
    (define len (syntax-e len-stx))
    (define start (syntax-e start-stx))
    (define end (syntax-e end-stx))
    (define step (syntax-e step-stx))
    (and (exact-nonnegative-integer? len)
         (exact-integer? start)
         (exact-integer? end)
         (exact-integer? step)
         (let ([range-len (literal-range-length start end step)])
           (and (equal? len range-len)
                (small-literal-arithmetic-range->pvector
                 stx
                 start
                 step
                 len)))))

  (define (same-identifier? a b)
    (and (identifier? a)
         (identifier? b)
         (free-identifier=? a b))))

(define-syntax (small-arithmetic-range-dispatch stx)
  (syntax-case stx ()
    [(_ start-expr step-expr len-expr)
     (with-syntax ([(case-clause ...)
                    (small-arithmetic-range-cases stx
                                                  #'start-expr
                                                  #'step-expr)])
       #'(case len-expr
           case-clause ...))]))

(define-syntax (integer-range-64-pvector stx)
  (syntax-case stx ()
    [(_)
     (small-literal-range->pvector stx 64)]))

(define (small-arithmetic-range->pvector start step len)
  (cond
    [(zero? len) empty-pvector]
    [(<= len 32) (small-arithmetic-range-dispatch start step len)]
    [else #f]))

(define (small-arithmetic-range-vector->pvector start step len)
  (define vec (make-vector len))
  (let loop ([i 0] [elem start])
    (unless (unsafe-fx= i len)
      (unsafe-vector-set! vec i elem)
      (loop (unsafe-fx+ i 1) (+ elem step))))
  (small-mutable-vector->pvector vec len))

(define (small-integer-range->pvector len)
  (if (= len 64)
      (integer-range-64-pvector)
      (small-arithmetic-range->pvector 0 1 len)))

(define (range-info->pvector seq info)
  (define start (vector-ref info 0))
  (define step (vector-ref info 1))
  (define len (vector-ref info 2))
  (or (small-arithmetic-range->pvector start step len)
      (and (fixnum? len)
           (unsafe-fx<= len 64)
           (small-arithmetic-range-vector->pvector start step len))
      (wrap/len (raw:sequence->pvector seq) len)))

(define sequence->pvector/proc
  (let ()
    (define (sequence->pvector seq)
      (cond
        [(pvector-wrapper? seq) seq]
        [(list? seq) (list->pvector seq)]
        [(vector? seq) (vector->pvector seq)]
        [(exact-nonnegative-integer? seq)
         (or (small-integer-range->pvector seq)
             (wrap/len (raw:sequence->pvector seq) seq))]
        [(range-sequence->exact-nonnegative-integer seq)
         => (lambda (len)
              (or (small-integer-range->pvector len)
                  (wrap/len (raw:sequence->pvector len) len)))]
        [(range-sequence->exact-integer-range-info seq)
         => (lambda (info) (range-info->pvector seq info))]
        [(sequence? seq)
         (wrap (raw:sequence->pvector seq))]
        [else
         (raise-argument-error 'sequence->pvector "sequence?" seq)]))
    sequence->pvector))

(define-syntax (sequence->pvector stx)
  (syntax-case stx (in-range in-list in-vector in-pvector in-pvector-reverse)
    [(_ (in-pvector pv-expr))
     #'(let ([pv pv-expr])
         (if (pvector-wrapper? pv)
             pv
             (sequence->pvector/proc (in-pvector pv))))]
    [(_ (in-pvector-reverse pv-expr))
     #'(let ([pv pv-expr])
         (if (pvector-wrapper? pv)
             (for/pvector #:length (pvector-wrapper-length/unsafe pv)
                          ([elem (in-pvector-reverse pv)])
               elem)
             (sequence->pvector/proc (in-pvector-reverse pv))))]
    [(_ (in-list lst-expr))
     #'(let ([lst lst-expr])
         (if (list? lst)
             (list->pvector lst)
             (sequence->pvector/proc (in-list lst))))]
    [(_ (in-vector vec-expr))
     #'(let ([vec vec-expr])
         (if (vector? vec)
             (vector->pvector vec)
             (sequence->pvector/proc (in-vector vec))))]
    [(_ (in-range end))
     (or (small-literal-in-range->pvector
          stx
          (datum->syntax stx 0)
          #'end
          (datum->syntax stx 1))
         #'(sequence->pvector/proc (in-range end)))]
    [(_ (in-range start end))
     (or (small-literal-in-range->pvector
          stx
          #'start
          #'end
          (datum->syntax stx 1))
         #'(sequence->pvector/proc (in-range start end)))]
    [(_ (in-range start end step))
     (or (small-literal-in-range->pvector stx #'start #'end #'step)
         #'(sequence->pvector/proc (in-range start end step)))]
    [(_ len-expr)
     (let ([len (syntax-e #'len-expr)])
       (if (exact-nonnegative-integer? len)
           (or (small-literal-range->pvector stx len)
               #'(sequence->pvector/proc len-expr))
           #'(sequence->pvector/proc len-expr)))]
    [_ #'sequence->pvector/proc]))

(begin-encourage-inline
  (define (pvector-length pv)
    (unless (pvector-wrapper? pv)
      (raise-argument-error 'pvector-length "pvector?" pv))
    (pvector-wrapper-length/unsafe pv))

  (define (pvector-ref pv index)
    (cond
      [(and (fixnum? index) (unsafe-fx>= index 0))
       (unless (pvector-wrapper? pv)
         (raise-argument-error 'pvector-ref "pvector?" pv))
       (if (unsafe-fx= index 0)
           (begin
             (when (eq? pv empty-pvector)
               (raise-range-error 'pvector-ref "pvector" "" index pv 0 -1))
             (raw:pvector-view-left (pvector-wrapper-tree/unsafe pv)))
           (let ([len (pvector-wrapper-length/unsafe pv)])
             (when (unsafe-fx>= index len)
               (raise-range-error 'pvector-ref "pvector" "" index pv 0 (sub1 len)))
             (define tree (pvector-wrapper-tree/unsafe pv))
             (if (unsafe-fx= index (unsafe-fx- len 1))
                 (raw:pvector-view-right tree)
                 (raw:pvector-ref tree index))))]
      [else
       (check-nonnegative-integer 'pvector-ref index)
       (unless (pvector-wrapper? pv)
         (raise-argument-error 'pvector-ref "pvector?" pv))
       (define len (pvector-wrapper-length/unsafe pv))
       (when (>= index len)
         (raise-range-error 'pvector-ref "pvector" "" index pv 0 (sub1 len)))
       (define tree (pvector-wrapper-tree/unsafe pv))
       (cond
         [(zero? index) (raw:pvector-view-left tree)]
         [(= index (sub1 len)) (raw:pvector-view-right tree)]
         [else (raw:pvector-ref tree index)])]))

  (define (pvector-set pv index value)
    (cond
      [(and (fixnum? index) (unsafe-fx>= index 0))
       (unless (pvector-wrapper? pv)
         (raise-argument-error 'pvector-set "pvector?" pv))
       (define len (pvector-wrapper-length/unsafe pv))
       (when (unsafe-fx>= index len)
         (raise-range-error 'pvector-set "pvector" "" index pv 0 (sub1 len)))
       (define tree (pvector-wrapper-tree/unsafe pv))
       (define tree^ (raw:pvector-set tree index value))
       (if (eq? tree^ tree)
           pv
           (wrap/len tree^ len))]
      [else
       (check-nonnegative-integer 'pvector-set index)
       (unless (pvector-wrapper? pv)
         (raise-argument-error 'pvector-set "pvector?" pv))
       (define len (pvector-wrapper-length/unsafe pv))
       (when (>= index len)
         (raise-range-error 'pvector-set "pvector" "" index pv 0 (sub1 len)))
       (define tree (pvector-wrapper-tree/unsafe pv))
       (define tree^ (raw:pvector-set tree index value))
       (if (eq? tree^ tree)
           pv
           (wrap/len tree^ len))]))

  (define (pvector-first pv)
    (when (eq? pv empty-pvector)
      (raise-arguments-error 'pvector-first "pvector is empty" "pvector" pv))
    (unless (pvector-wrapper? pv)
      (raise-argument-error 'pvector-first "pvector?" pv))
    (raw:pvector-view-left (pvector-wrapper-tree/unsafe pv)))

  (define (pvector-last pv)
    (when (eq? pv empty-pvector)
      (raise-arguments-error 'pvector-last "pvector is empty" "pvector" pv))
    (unless (pvector-wrapper? pv)
      (raise-argument-error 'pvector-last "pvector?" pv))
    (raw:pvector-view-right (pvector-wrapper-tree/unsafe pv)))

  (define (pvector-cons-left pv value)
    (unless (pvector-wrapper? pv)
      (raise-argument-error 'pvector-cons-left "pvector?" pv))
    (wrap/len (raw:pvector-cons-left (pvector-wrapper-tree/unsafe pv) value)
              (unsafe-fx+ (pvector-wrapper-length/unsafe pv) 1)))

  (define (pvector-cons-right pv value)
    (unless (pvector-wrapper? pv)
      (raise-argument-error 'pvector-cons-right "pvector?" pv))
    (wrap/len (raw:pvector-cons-right (pvector-wrapper-tree/unsafe pv) value)
              (unsafe-fx+ (pvector-wrapper-length/unsafe pv) 1)))

  (define (pvector-pop-left pv)
    (cond
      [(pvector-wrapper? pv)
       (define len (pvector-wrapper-length/unsafe pv))
       (define tree (pvector-wrapper-tree/unsafe pv))
       (cond
         [(unsafe-fx= len 0)
          (raise-arguments-error 'pvector-pop-left "pvector is empty" "pvector" pv)]
         [(unsafe-fx= len 1)
          (values (raw:pvector-view-left tree) empty-pvector)]
         [else
          (let-values ([(value rest) (raw:pvector-pop-left tree)])
            (values value (wrap/len rest (unsafe-fx- len 1))))])]
      [else
       (raise-argument-error 'pvector-pop-left "pvector?" pv)]))

  (define (pvector-pop-right pv)
    (cond
      [(pvector-wrapper? pv)
       (define len (pvector-wrapper-length/unsafe pv))
       (define tree (pvector-wrapper-tree/unsafe pv))
       (cond
         [(unsafe-fx= len 0)
          (raise-arguments-error 'pvector-pop-right "pvector is empty" "pvector" pv)]
         [(unsafe-fx= len 1)
          (values (raw:pvector-view-right tree) empty-pvector)]
         [else
          (let-values ([(value rest) (raw:pvector-pop-right tree)])
            (values value (wrap/len rest (unsafe-fx- len 1))))])]
      [else
       (raise-argument-error 'pvector-pop-right "pvector?" pv)])))

(define (pvector-append pv0 pv1)
  (cond
    [(and (pvector-wrapper? pv0) (pvector-wrapper? pv1))
     (define left-len (pvector-wrapper-length/unsafe pv0))
     (define right-len (pvector-wrapper-length/unsafe pv1))
     (cond
       [(unsafe-fx= left-len 0) pv1]
       [(unsafe-fx= right-len 0) pv0]
       [else
        (wrap/len (raw:pvector-append (pvector-wrapper-tree/unsafe pv0)
                                      (pvector-wrapper-tree/unsafe pv1))
                  (unsafe-fx+ left-len right-len))])]
    [else
     (define left (check-pvector 'pvector-append pv0))
     (define right (check-pvector 'pvector-append pv1))
     (define left-len (pvector-wrapper-length/unsafe left))
     (define right-len (pvector-wrapper-length/unsafe right))
     (cond
       [(unsafe-fx= left-len 0) right]
       [(unsafe-fx= right-len 0) left]
       [else
        (wrap/len (raw:pvector-append (pvector-wrapper-tree/unsafe left)
                                      (pvector-wrapper-tree/unsafe right))
                  (unsafe-fx+ left-len right-len))])]))

(define (check-unary-procedure who proc)
  (unless (procedure? proc)
    (raise-argument-error who "procedure?" proc))
  (unless (procedure-arity-includes? proc 1)
    (raise-arguments-error who
                           "procedure does not accept one argument"
                           "procedure" proc))
  proc)

(define (pvector-map pv proc)
  (cond
    [(and (eq? proc values) (pvector-wrapper? pv)) pv]
    [else
     (define pv* (check-pvector 'pvector-map pv))
     (if (eq? proc values)
         pv*
         (let ([len (pvector-wrapper-length/unsafe pv*)])
           (cond
             [(eq? proc void) (make-pvector/known-length len (void))]
             [else
              (check-unary-procedure 'pvector-map proc)
              (cond
                [(unsafe-fx> len 0)
                 (wrap/len (raw:pvector-map (pvector-wrapper-tree/unsafe pv*) proc) len)]
                [else empty-pvector])])))]))

(define (pvector-for-each pv proc)
  (cond
    [(and (or (eq? proc void)
              (eq? proc values))
          (pvector-wrapper? pv))
     (void)]
    [else
     (define pv* (check-pvector 'pvector-for-each pv))
     (unless (or (eq? proc void)
                 (eq? proc values))
       (check-unary-procedure 'pvector-for-each proc)
       (define len (pvector-wrapper-length/unsafe pv*))
       (cond
         [(unsafe-fx> len 1)
          (raw:pvector-for-each (pvector-wrapper-tree/unsafe pv*) proc)]
         [(unsafe-fx= len 1)
          (proc (raw:pvector-view-left (pvector-wrapper-tree/unsafe pv*)))]))
     (void)]))

(define (pvector-insert pv index value)
  (cond
    [(and (fixnum? index) (unsafe-fx>= index 0))
     (unless (pvector-wrapper? pv)
       (raise-argument-error 'pvector-insert "pvector?" pv))
     (define len (pvector-wrapper-length/unsafe pv))
     (when (unsafe-fx> index len)
       (raise-range-error 'pvector-insert "pvector" "" index pv 0 len))
     (wrap/len (raw:pvector-insert (pvector-wrapper-tree/unsafe pv) index value)
               (unsafe-fx+ len 1))]
    [else
     (define-values (pv* len) (check-end-index/wrapper 'pvector-insert pv index))
     (wrap/len (raw:pvector-insert (pvector-wrapper-tree/unsafe pv*) index value)
               (unsafe-fx+ len 1))]))

(define (pvector-delete pv index)
  (cond
    [(and (eqv? index 0) (pvector-wrapper? pv))
     (define len (pvector-wrapper-length/unsafe pv))
     (define tree (pvector-wrapper-tree/unsafe pv))
     (cond
       [(unsafe-fx= len 0)
        (raise-range-error 'pvector-delete "pvector" "" index pv 0 -1)]
       [(unsafe-fx= len 1)
        (values empty-pvector (raw:pvector-view-left tree))]
       [else
        (let-values ([(value rest) (raw:pvector-pop-left tree)])
          (values (wrap/len rest (unsafe-fx- len 1)) value))])]
    [(and (fixnum? index) (unsafe-fx>= index 0))
     (unless (pvector-wrapper? pv)
       (raise-argument-error 'pvector-delete "pvector?" pv))
     (define len (pvector-wrapper-length/unsafe pv))
     (define tree (pvector-wrapper-tree/unsafe pv))
     (cond
       [(unsafe-fx>= index len)
        (raise-range-error 'pvector-delete "pvector" "" index pv 0 (unsafe-fx- len 1))]
       [(unsafe-fx= len 1)
        (values empty-pvector (raw:pvector-view-left tree))]
       [(unsafe-fx= index 0)
        (let-values ([(value rest) (raw:pvector-pop-left tree)])
          (values (wrap/len rest (unsafe-fx- len 1)) value))]
       [(unsafe-fx= index (unsafe-fx- len 1))
        (let-values ([(value rest) (raw:pvector-pop-right tree)])
          (values (wrap/len rest (unsafe-fx- len 1)) value))]
       [else
        (let-values ([(rest value) (raw:pvector-delete tree index)])
          (values (wrap/len rest (unsafe-fx- len 1)) value))])]
    [else
     (define-values (pv* len) (check-index/wrapper 'pvector-delete pv index))
     (define tree (pvector-wrapper-tree/unsafe pv*))
     (if (unsafe-fx= len 1)
         (values empty-pvector (raw:pvector-view-left tree))
         (let-values ([(rest value) (raw:pvector-delete tree index)])
           (values (wrap/len rest (unsafe-fx- len 1)) value)))]))

(define (pvector-take pv pos)
  (cond
    [(eqv? pos 0)
     (if (pvector-wrapper? pv)
         empty-pvector
         (begin
           (check-pvector 'pvector-take pv)
           empty-pvector))]
    [(and (fixnum? pos) (unsafe-fx>= pos 0))
     (unless (pvector-wrapper? pv)
       (raise-argument-error 'pvector-take "pvector?" pv))
     (define len (pvector-wrapper-length/unsafe pv))
     (cond
       [(unsafe-fx> pos len)
        (raise-range-error 'pvector-take "pvector" "" pos pv 0 len)]
       [(unsafe-fx= pos len) pv]
       [else (wrap/len (raw:pvector-take (pvector-wrapper-tree/unsafe pv) pos) pos)])]
    [else
     (define-values (pv* len) (check-end-index/wrapper 'pvector-take pv pos))
     (cond
       [(zero? pos) empty-pvector]
       [(= pos len) pv*]
       [else (wrap/len (raw:pvector-take (pvector-wrapper-tree/unsafe pv*) pos) pos)])]))

(define (pvector-drop pv pos)
  (cond
    [(eqv? pos 0)
     (if (pvector-wrapper? pv)
         pv
         (check-pvector 'pvector-drop pv))]
    [(and (fixnum? pos) (unsafe-fx>= pos 0))
     (unless (pvector-wrapper? pv)
       (raise-argument-error 'pvector-drop "pvector?" pv))
     (define len (pvector-wrapper-length/unsafe pv))
     (cond
       [(unsafe-fx> pos len)
        (raise-range-error 'pvector-drop "pvector" "" pos pv 0 len)]
       [(unsafe-fx= pos len) empty-pvector]
       [else (wrap/len (raw:pvector-drop (pvector-wrapper-tree/unsafe pv) pos)
                       (unsafe-fx- len pos))])]
    [else
     (define-values (pv* len) (check-end-index/wrapper 'pvector-drop pv pos))
     (cond
       [(zero? pos) pv*]
       [(= pos len) empty-pvector]
       [else (wrap/len (raw:pvector-drop (pvector-wrapper-tree/unsafe pv*) pos)
                       (unsafe-fx- len pos))])]))

(define (pvector-take-right pv pos)
  (cond
    [(eqv? pos 0)
     (if (pvector-wrapper? pv)
         empty-pvector
         (begin
           (check-pvector 'pvector-take-right pv)
           empty-pvector))]
    [(and (fixnum? pos) (unsafe-fx>= pos 0))
     (unless (pvector-wrapper? pv)
       (raise-argument-error 'pvector-take-right "pvector?" pv))
     (define len (pvector-wrapper-length/unsafe pv))
     (cond
       [(unsafe-fx> pos len)
        (raise-range-error 'pvector-take-right "pvector" "" pos pv 0 len)]
       [(unsafe-fx= pos len) pv]
       [else (wrap/len (raw:pvector-take-right (pvector-wrapper-tree/unsafe pv) pos) pos)])]
    [else
     (define-values (pv* len) (check-end-index/wrapper 'pvector-take-right pv pos))
     (cond
       [(zero? pos) empty-pvector]
       [(= pos len) pv*]
       [else (wrap/len (raw:pvector-take-right (pvector-wrapper-tree/unsafe pv*) pos) pos)])]))

(define (pvector-drop-right pv pos)
  (cond
    [(eqv? pos 0)
     (if (pvector-wrapper? pv)
         pv
         (check-pvector 'pvector-drop-right pv))]
    [(and (fixnum? pos) (unsafe-fx>= pos 0))
     (unless (pvector-wrapper? pv)
       (raise-argument-error 'pvector-drop-right "pvector?" pv))
     (define len (pvector-wrapper-length/unsafe pv))
     (cond
       [(unsafe-fx> pos len)
        (raise-range-error 'pvector-drop-right "pvector" "" pos pv 0 len)]
       [(unsafe-fx= pos len) empty-pvector]
       [else (wrap/len (raw:pvector-drop-right (pvector-wrapper-tree/unsafe pv) pos)
                       (unsafe-fx- len pos))])]
    [else
     (define-values (pv* len) (check-end-index/wrapper 'pvector-drop-right pv pos))
     (cond
       [(zero? pos) pv*]
       [(= pos len) empty-pvector]
       [else (wrap/len (raw:pvector-drop-right (pvector-wrapper-tree/unsafe pv*) pos)
                       (unsafe-fx- len pos))])]))

(define (pvector-subvector/finish pv* len start end)
  (define new-len (unsafe-fx- end start))
  (cond
    [(unsafe-fx= new-len 0) empty-pvector]
    [(and (unsafe-fx= start 0) (unsafe-fx= end len)) pv*]
    [(unsafe-fx= start 0)
     (wrap/len (raw:pvector-take (pvector-wrapper-tree/unsafe pv*) end) new-len)]
    [(unsafe-fx= end len)
     (wrap/len (raw:pvector-drop (pvector-wrapper-tree/unsafe pv*) start) new-len)]
    [else (wrap/len (raw:pvector-copy (pvector-wrapper-tree/unsafe pv*) start end)
                    new-len)]))

(define pvector-subvector
  (case-lambda
    [(pv start)
     (cond
       [(eqv? start 0)
       (if (pvector-wrapper? pv)
           pv
           (check-pvector 'pvector-subvector pv))]
       [(and (fixnum? start) (unsafe-fx>= start 0))
        (unless (pvector-wrapper? pv)
          (raise-argument-error 'pvector-subvector "pvector?" pv))
        (define len (pvector-wrapper-length/unsafe pv))
        (when (unsafe-fx> start len)
          (raise-range-error 'pvector-subvector "pvector" "" start pv 0 len))
        (pvector-subvector/finish pv len start len)]
       [else
        (define-values (pv* len) (checked-wrapper+length 'pvector-subvector pv))
        (check-nonnegative-integer 'pvector-subvector start)
        (when (> start len)
          (raise-range-error 'pvector-subvector "pvector" "" start pv 0 len))
        (pvector-subvector/finish pv* len start len)])]
    [(pv start end)
     (cond
       [(and (eqv? start 0) (eqv? end 0))
        (if (pvector-wrapper? pv)
            empty-pvector
            (begin
              (check-pvector 'pvector-subvector pv)
              empty-pvector))]
       [(and (fixnum? start) (unsafe-fx>= start 0)
             (fixnum? end) (unsafe-fx>= end 0))
        (unless (pvector-wrapper? pv)
          (raise-argument-error 'pvector-subvector "pvector?" pv))
        (define pv* pv)
        (define len (pvector-wrapper-length/unsafe pv*))
        (cond
          [(unsafe-fx= start end)
           (when (unsafe-fx> start len)
             (raise-range-error 'pvector-subvector "pvector" "" start pv 0 len))
           empty-pvector]
          [(unsafe-fx= start 0)
           (when (unsafe-fx> end len)
             (raise-range-error 'pvector-subvector "pvector" "" end pv 0 len))
           (if (unsafe-fx= end len)
               pv*
               (wrap/len (raw:pvector-copy (pvector-wrapper-tree/unsafe pv*) start end)
                         end))]
          [else
           (when (unsafe-fx> start len)
             (raise-range-error 'pvector-subvector "pvector" "" start pv 0 len))
           (when (unsafe-fx> end len)
             (raise-range-error 'pvector-subvector "pvector" "" end pv 0 len))
           (when (unsafe-fx> start end)
             (raise-arguments-error 'pvector-subvector
                                    "starting index is greater than ending index"
                                    "starting index" start
                                    "ending index" end
                                    "pvector" pv))
           (wrap/len (raw:pvector-copy (pvector-wrapper-tree/unsafe pv*) start end)
                     (unsafe-fx- end start))])]
       [else
        (define-values (pv* len start* end*)
          (check-subrange/wrapper 'pvector-subvector pv start end))
        (pvector-subvector/finish pv* len start* end*)])]))

(define (pvector-split pv index)
  (cond
    [(and (fixnum? index) (unsafe-fx>= index 0))
     (unless (pvector-wrapper? pv)
       (raise-argument-error 'pvector-split "pvector?" pv))
     (define len (pvector-wrapper-length/unsafe pv))
     (when (unsafe-fx>= index len)
       (raise-range-error 'pvector-split "pvector" "" index pv 0 (unsafe-fx- len 1)))
     (define tree (pvector-wrapper-tree/unsafe pv))
     (if (unsafe-fx= len 1)
         (values empty-pvector (raw:pvector-view-left tree) empty-pvector)
         (cond
           [(unsafe-fx= index 0)
            (let-values ([(value right) (raw:pvector-pop-left tree)])
              (values empty-pvector value (wrap/len right (unsafe-fx- len 1))))]
           [(unsafe-fx= index (unsafe-fx- len 1))
            (let-values ([(value left) (raw:pvector-pop-right tree)])
              (values (wrap/len left (unsafe-fx- len 1)) value empty-pvector))]
           [else
            (let-values ([(left value right) (raw:pvector-split tree index)])
              (values (wrap/len left index)
                      value
                      (wrap/len right (unsafe-fx- (unsafe-fx- len index) 1))))]))]
    [else
     (define-values (pv* len) (check-index/wrapper 'pvector-split pv index))
     (define tree (pvector-wrapper-tree/unsafe pv*))
     (if (unsafe-fx= len 1)
         (values empty-pvector (raw:pvector-view-left tree) empty-pvector)
         (let-values ([(left value right) (raw:pvector-split tree index)])
           (values (wrap/len left index)
                   value
                   (wrap/len right (unsafe-fx- (unsafe-fx- len index) 1)))))]))

(define (pvector-split-at pv pos)
  (cond
    [(eqv? pos 0)
     (if (pvector-wrapper? pv)
         (values empty-pvector pv)
         (values empty-pvector (check-pvector 'pvector-split-at pv)))]
    [(and (fixnum? pos) (unsafe-fx> pos 0))
     (unless (pvector-wrapper? pv)
       (raise-argument-error 'pvector-split-at "pvector?" pv))
     (define len (pvector-wrapper-length/unsafe pv))
     (cond
       [(unsafe-fx> pos len)
        (raise-range-error 'pvector-split-at "pvector" "" pos pv 0 len)]
       [(unsafe-fx= pos len) (values pv empty-pvector)]
       [else
        (define-values (left right)
          (raw:pvector-split-at (pvector-wrapper-tree/unsafe pv) pos))
        (values (wrap/len left pos)
                (wrap/len right (unsafe-fx- len pos)))])]
    [else
     (define-values (pv* len) (check-end-index/wrapper 'pvector-split-at pv pos))
     (cond
       [(zero? pos) (values empty-pvector pv*)]
       [(= pos len) (values pv* empty-pvector)]
       [else
        (define-values (left right)
          (raw:pvector-split-at (pvector-wrapper-tree/unsafe pv*) pos))
        (values (wrap/len left pos)
                (wrap/len right (unsafe-fx- len pos)))])]))

(define (raw-tree-in-pvector/proc tree len)
  (define vec (raw:pvector->vector tree))
  (make-do-sequence
   (lambda ()
     (values (lambda (index) (unsafe-vector-ref vec index))
             (lambda (index) (unsafe-fx+ index 1))
             0
             (lambda (index) (unsafe-fx< index len))
             (lambda (elem) #t)
             (lambda (pos elem) #t)))))

(define (raw-tree-in-pvector-reverse/proc tree len)
  (define vec (raw:pvector->vector tree))
  (make-do-sequence
   (lambda ()
     (values (lambda (index) (unsafe-vector-ref vec index))
             (lambda (index) (unsafe-fx- index 1))
             (unsafe-fx- len 1)
             (lambda (index) (unsafe-fx>= index 0))
             (lambda (elem) #t)
             (lambda (pos elem) #t)))))

(define (in-pvector/proc pv)
  (if (pvector-wrapper? pv)
      (raw-tree-in-pvector/proc
       (pvector-wrapper-tree/unsafe pv)
       (pvector-wrapper-length/unsafe pv))
      (let ([pv* (check-pvector 'in-pvector pv)])
        (raw-tree-in-pvector/proc
         (pvector-wrapper-tree/unsafe pv*)
         (pvector-wrapper-length/unsafe pv*)))))

(define (in-pvector-reverse/proc pv)
  (if (pvector-wrapper? pv)
      (raw-tree-in-pvector-reverse/proc
       (pvector-wrapper-tree/unsafe pv)
       (pvector-wrapper-length/unsafe pv))
      (let ([pv* (check-pvector 'in-pvector-reverse pv)])
        (raw-tree-in-pvector-reverse/proc
         (pvector-wrapper-tree/unsafe pv*)
         (pvector-wrapper-length/unsafe pv*)))))

(define-sequence-syntax in-pvector
  (lambda () #'in-pvector/proc)
  (lambda (stx)
    (syntax-case stx ()
      [[(elem) (_ pv-expr)]
       #'[(elem)
          (:do-in
           ([(vec) (raw:pvector->vector
                    (let ([pv pv-expr])
                      (if (pvector-wrapper? pv)
                          (pvector-wrapper-tree/unsafe pv)
                          (unwrap 'in-pvector pv))))])
           (begin
             (define len (unsafe-vector-length vec)))
           ([elem-idx 0])
           (unsafe-fx< elem-idx len)
           ([(elem next-elem-idx)
             (values (unsafe-vector-ref vec elem-idx)
                     (unsafe-fx+ elem-idx 1))])
           #t
           #t
           (next-elem-idx))]]
      [_ #f])))

(define-sequence-syntax in-pvector-reverse
  (lambda () #'in-pvector-reverse/proc)
  (lambda (stx)
    (syntax-case stx ()
      [[(elem) (_ pv-expr)]
       #'[(elem)
          (:do-in
           ([(vec) (raw:pvector->vector
                    (let ([pv pv-expr])
                      (if (pvector-wrapper? pv)
                          (pvector-wrapper-tree/unsafe pv)
                          (unwrap 'in-pvector-reverse pv))))])
           (begin
             (define len (unsafe-vector-length vec)))
           ([elem-idx (unsafe-fx- len 1)])
           (unsafe-fx>= elem-idx 0)
           ([(elem next-elem-idx)
             (values (unsafe-vector-ref vec elem-idx)
                     (unsafe-fx- elem-idx 1))])
           #t
           #t
           (next-elem-idx))]]
      [_ #f])))

(module+ unsafe
  (provide unsafe-pvector-length
           unsafe-pvector->list
           unsafe-pvector->vector
           unsafe-pvector->chunk-vector
           unsafe-pvector-ref
           unsafe-pvector-set
           unsafe-pvector-first
           unsafe-pvector-last
           unsafe-pvector-cons-left
           unsafe-pvector-cons-right
           unsafe-pvector-pop-left
           unsafe-pvector-pop-right
           unsafe-pvector-append
           unsafe-pvector-insert
           unsafe-pvector-delete
           unsafe-pvector-take
           unsafe-pvector-drop
           unsafe-pvector-take-right
           unsafe-pvector-drop-right
           unsafe-pvector-subvector
           unsafe-pvector-split
           unsafe-pvector-split-at
           unsafe-in-pvector
           unsafe-in-pvector-reverse)

  (define (unsafe-tree pv)
    (pvector-wrapper-tree/unsafe pv))

  (begin-encourage-inline
    (define (unsafe-pvector-length pv)
      (pvector-wrapper-length/unsafe pv)))

  (define (unsafe-pvector->list pv)
    (if (eq? pv empty-pvector)
        null
        (let ([tree (unsafe-tree pv)]
              [len (pvector-wrapper-length/unsafe pv)])
          (case len
            [(1) (list (raw:pvector-view-left tree))]
            [(2) (list (raw:pvector-view-left tree)
                       (raw:pvector-view-right tree))]
            [(3) (list (raw:pvector-view-left tree)
                       (raw:pvector-ref tree 1)
                       (raw:pvector-view-right tree))]
            [(4) (list (raw:pvector-view-left tree)
                       (raw:pvector-ref tree 1)
                       (raw:pvector-ref tree 2)
                       (raw:pvector-view-right tree))]
            [else (raw:pvector->list tree)]))))

  (define (unsafe-pvector->vector pv)
    (if (eq? pv empty-pvector)
        (make-vector 0)
        (let ([tree (unsafe-tree pv)]
              [len (pvector-wrapper-length/unsafe pv)])
          (case len
            [(1) (vector (raw:pvector-view-left tree))]
            [(2) (vector (raw:pvector-view-left tree)
                         (raw:pvector-view-right tree))]
            [(3) (vector (raw:pvector-view-left tree)
                         (raw:pvector-ref tree 1)
                         (raw:pvector-view-right tree))]
            [(4) (vector (raw:pvector-view-left tree)
                         (raw:pvector-ref tree 1)
                         (raw:pvector-ref tree 2)
                         (raw:pvector-view-right tree))]
            [else (raw:pvector->vector tree)]))))

  (define (unsafe-pvector->chunk-vector pv)
    (raw:pvector->chunk-vector (unsafe-tree pv)))

  (begin-encourage-inline
    (define (unsafe-pvector-ref pv index)
      (raw:pvector-ref (unsafe-tree pv) index))

    (define (unsafe-pvector-set pv index value)
      (define tree (unsafe-tree pv))
      (define tree^ (raw:pvector-set tree index value))
      (if (eq? tree^ tree)
          pv
          (wrap/len tree^ (pvector-wrapper-length/unsafe pv))))

    (define (unsafe-pvector-first pv)
      (raw:pvector-view-left (unsafe-tree pv)))

    (define (unsafe-pvector-last pv)
      (raw:pvector-view-right (unsafe-tree pv)))

    (define (unsafe-pvector-cons-left pv value)
      (wrap/len (raw:pvector-cons-left (unsafe-tree pv) value)
                (unsafe-fx+ (pvector-wrapper-length/unsafe pv) 1)))

    (define (unsafe-pvector-cons-right pv value)
      (wrap/len (raw:pvector-cons-right (unsafe-tree pv) value)
                (unsafe-fx+ (pvector-wrapper-length/unsafe pv) 1)))

    (define (unsafe-pvector-pop-left pv)
      (define len (pvector-wrapper-length/unsafe pv))
      (define tree (unsafe-tree pv))
      (if (unsafe-fx= len 1)
          (values (raw:pvector-view-left tree) empty-pvector)
          (let-values ([(value rest) (raw:pvector-pop-left tree)])
            (values value (wrap/len rest (unsafe-fx- len 1))))))

    (define (unsafe-pvector-pop-right pv)
      (define len (pvector-wrapper-length/unsafe pv))
      (define tree (unsafe-tree pv))
      (if (unsafe-fx= len 1)
          (values (raw:pvector-view-right tree) empty-pvector)
          (let-values ([(value rest) (raw:pvector-pop-right tree)])
            (values value (wrap/len rest (unsafe-fx- len 1)))))))

  (define (unsafe-pvector-append pv0 pv1)
    (define left-len (pvector-wrapper-length/unsafe pv0))
    (define right-len (pvector-wrapper-length/unsafe pv1))
    (cond
      [(zero? left-len) pv1]
      [(zero? right-len) pv0]
      [else
       (wrap/len (raw:pvector-append (unsafe-tree pv0)
                                     (unsafe-tree pv1))
                 (unsafe-fx+ left-len right-len))]))

  (define (unsafe-pvector-insert pv index value)
    (wrap/len (raw:pvector-insert (unsafe-tree pv) index value)
              (unsafe-fx+ (pvector-wrapper-length/unsafe pv) 1)))

  (define (unsafe-pvector-delete pv index)
    (define len (pvector-wrapper-length/unsafe pv))
    (define tree (unsafe-tree pv))
    (if (unsafe-fx= len 1)
        (values empty-pvector (raw:pvector-view-left tree))
        (cond
          [(zero? index)
           (let-values ([(value rest) (raw:pvector-pop-left tree)])
             (values (wrap/len rest (unsafe-fx- len 1)) value))]
          [(= index (unsafe-fx- len 1))
           (let-values ([(value rest) (raw:pvector-pop-right tree)])
             (values (wrap/len rest (unsafe-fx- len 1)) value))]
          [else
           (let-values ([(rest value) (raw:pvector-delete tree index)])
             (values (wrap/len rest (unsafe-fx- len 1)) value))])))

  (define (unsafe-pvector-take pv pos)
    (cond
      [(zero? pos) empty-pvector]
      [(= pos (pvector-wrapper-length/unsafe pv)) pv]
      [else (wrap/len (raw:pvector-take (unsafe-tree pv) pos) pos)]))

  (define (unsafe-pvector-drop pv pos)
    (define len (pvector-wrapper-length/unsafe pv))
    (cond
      [(zero? pos) pv]
      [(= pos len) empty-pvector]
      [else (wrap/len (raw:pvector-drop (unsafe-tree pv) pos)
                      (unsafe-fx- len pos))]))

  (define (unsafe-pvector-take-right pv pos)
    (cond
      [(zero? pos) empty-pvector]
      [(= pos (pvector-wrapper-length/unsafe pv)) pv]
      [else (wrap/len (raw:pvector-take-right (unsafe-tree pv) pos) pos)]))

  (define (unsafe-pvector-drop-right pv pos)
    (define len (pvector-wrapper-length/unsafe pv))
    (cond
      [(zero? pos) pv]
      [(= pos len) empty-pvector]
      [else (wrap/len (raw:pvector-drop-right (unsafe-tree pv) pos)
                      (unsafe-fx- len pos))]))

  (define (unsafe-pvector-subvector pv start end)
    (define len (pvector-wrapper-length/unsafe pv))
    (define new-len (unsafe-fx- end start))
    (cond
      [(unsafe-fx= new-len 0) empty-pvector]
      [(and (unsafe-fx= start 0) (unsafe-fx= end len)) pv]
      [(unsafe-fx= start 0)
       (wrap/len (raw:pvector-copy (unsafe-tree pv) start end) new-len)]
      [(unsafe-fx= end len)
       (wrap/len (raw:pvector-copy (unsafe-tree pv) start end) new-len)]
      [else (wrap/len (raw:pvector-copy (unsafe-tree pv) start end)
                      new-len)]))

  (define (unsafe-pvector-split pv index)
    (define len (pvector-wrapper-length/unsafe pv))
    (define tree (unsafe-tree pv))
    (cond
      [(and (unsafe-fx= len 1) (unsafe-fx= index 0))
       (values empty-pvector (raw:pvector-view-left tree) empty-pvector)]
      [(zero? index)
       (let-values ([(value right) (raw:pvector-pop-left tree)])
         (values empty-pvector value (wrap/len right (unsafe-fx- len 1))))]
      [(= index (unsafe-fx- len 1))
       (let-values ([(value left) (raw:pvector-pop-right tree)])
         (values (wrap/len left (unsafe-fx- len 1)) value empty-pvector))]
      [else
       (let-values ([(left value right) (raw:pvector-split tree index)])
         (values (wrap/len left index)
                 value
                 (wrap/len right (unsafe-fx- (unsafe-fx- len index) 1))))]))

  (define (unsafe-pvector-split-at pv pos)
    (define len (pvector-wrapper-length/unsafe pv))
    (cond
      [(zero? pos) (values empty-pvector pv)]
      [(= pos len) (values pv empty-pvector)]
      [else
       (define-values (left right)
         (raw:pvector-split-at (unsafe-tree pv) pos))
       (values (wrap/len left pos)
               (wrap/len right (unsafe-fx- len pos)))]))

  (define (unsafe-in-pvector/proc pv)
    (raw-tree-in-pvector/proc
     (unsafe-tree pv)
     (pvector-wrapper-length/unsafe pv)))

  (define (unsafe-in-pvector-reverse/proc pv)
    (raw-tree-in-pvector-reverse/proc
     (unsafe-tree pv)
     (pvector-wrapper-length/unsafe pv)))

  (define-sequence-syntax unsafe-in-pvector
    (lambda () #'unsafe-in-pvector/proc)
    (lambda (stx)
      (syntax-case stx ()
        [[(elem) (_ pv-expr)]
         #'[(elem)
            (:do-in
             ([(vec) (raw:pvector->vector (unsafe-tree pv-expr))])
             (begin
               (define len (unsafe-vector-length vec)))
             ([elem-idx 0])
             (unsafe-fx< elem-idx len)
             ([(elem next-elem-idx)
               (values (unsafe-vector-ref vec elem-idx)
                       (unsafe-fx+ elem-idx 1))])
             #t
             #t
             (next-elem-idx))]]
        [_ #f])))

  (define-sequence-syntax unsafe-in-pvector-reverse
    (lambda () #'unsafe-in-pvector-reverse/proc)
    (lambda (stx)
      (syntax-case stx ()
        [[(elem) (_ pv-expr)]
         #'[(elem)
            (:do-in
             ([(vec) (raw:pvector->vector (unsafe-tree pv-expr))])
             (begin
               (define len (unsafe-vector-length vec)))
             ([elem-idx (unsafe-fx- len 1)])
             (unsafe-fx>= elem-idx 0)
             ([(elem next-elem-idx)
               (values (unsafe-vector-ref vec elem-idx)
                       (unsafe-fx- elem-idx 1))])
             #t
             #t
             (next-elem-idx))]]
        [_ #f]))))

(define (pvector-match-tail->list tree start end)
  (let loop ([i (sub1 end)] [acc null])
    (if (< i start)
        acc
        (loop (sub1 i) (cons (raw:pvector-ref tree i) acc)))))

(define-syntax (for/pvector stx)
  (syntax-case stx (in-range in-list in-vector in-pvector in-pvector-reverse)
    [(_ #:length len ([elem (in-range end)]) body)
     (and (same-identifier? #'elem #'body)
          (exact-nonnegative-integer? (syntax-e #'len))
          (equal? (syntax-e #'len) (syntax-e #'end)))
     (small-literal-range->pvector stx (syntax-e #'len))]
    [(_ #:length len ([elem (in-range start end)]) body)
     (and (same-identifier? #'elem #'body)
          (small-literal-in-range/length->pvector
           stx
           #'len
           #'start
           #'end
           (datum->syntax stx 1)))
     (small-literal-in-range/length->pvector
      stx
      #'len
      #'start
      #'end
      (datum->syntax stx 1))]
    [(_ #:length len ([elem (in-range start end step)]) body)
     (and (same-identifier? #'elem #'body)
          (small-literal-in-range/length->pvector stx #'len #'start #'end #'step))
     (small-literal-in-range/length->pvector stx #'len #'start #'end #'step)]
    [(_ #:length len #:fill fill-expr (clause ...) body ...)
     (small-length-literal? #'len)
     #'(wrap/len (raw:for/pvector #:length len #:fill fill-expr
                                  (clause ...) body ...)
                 len)]
    [(_ #:length length-expr #:fill fill-expr (clause ...) body ...)
     #'(let ([len length-expr])
         (wrap/len (raw:for/pvector #:length len #:fill fill-expr
                                    (clause ...) body ...)
                   len))]
    [(_ #:length end ([elem (in-range end*)]) body ...)
     (and (identifier? #'end)
          (identifier? #'end*)
          (free-identifier=? #'end #'end*))
     #'(let ([len end])
         (wrap/len (raw:for/pvector #:length len ([elem (in-range len)])
                                    body ...)
                   len))]
    [(_ #:length end ([elem (in-range start end*)]) body)
     (and (same-identifier? #'elem #'body)
          (identifier? #'end)
          (identifier? #'end*)
          (free-identifier=? #'end #'end*)
          (equal? (syntax-e #'start) 0))
     #'(sequence->pvector end)]
    [(_ #:length end ([elem (in-range start end* step)]) body)
     (and (same-identifier? #'elem #'body)
          (identifier? #'end)
          (identifier? #'end*)
          (free-identifier=? #'end #'end*)
          (equal? (syntax-e #'start) 0)
          (equal? (syntax-e #'step) 1))
     #'(sequence->pvector end)]
    [(_ #:length len ([elem (in-range end)]) body ...)
     (and (exact-nonnegative-integer? (syntax-e #'len))
          (equal? (syntax-e #'len) (syntax-e #'end)))
     #'(wrap/len (raw:for/pvector #:length len ([elem (in-range end)])
                                  body ...)
                 len)]
    [(_ #:length length-expr ([elem (in-pvector pv-expr)]) body)
     (same-identifier? #'elem #'body)
     #'(let ([len length-expr])
         (if (exact-nonnegative-integer? len)
             (let ([pv pv-expr])
               (if (and (pvector-wrapper? pv)
                        (= len (pvector-wrapper-length/unsafe pv)))
                   pv
                   (wrap/len (raw:for/pvector #:length len
                                              ([elem (in-pvector pv)])
                                              elem)
                             len)))
             (wrap/len (raw:for/pvector #:length len
                                        ([elem (in-pvector pv-expr)])
                                        elem)
                       len)))]
    [(_ #:length length-expr ([elem (in-vector vec-expr)]) body)
     (same-identifier? #'elem #'body)
     #'(let ([len length-expr])
         (if (exact-nonnegative-integer? len)
             (let ([vec vec-expr])
               (if (and (vector? vec)
                        (= len (vector-length vec)))
                   (vector->pvector vec)
                   (wrap/len (raw:for/pvector #:length len
                                              ([elem (in-vector vec)])
                                              elem)
                             len)))
             (wrap/len (raw:for/pvector #:length len
                                        ([elem (in-vector vec-expr)])
                                        elem)
                       len)))]
    [(_ #:length length-expr ([elem seq-id]) body)
     (and (same-identifier? #'elem #'body)
          (identifier? #'seq-id))
     #'(let ([len length-expr])
         (if (exact-nonnegative-integer? len)
             (let ([seq seq-id])
               (cond
                 [(and (pvector-wrapper? seq)
                       (= len (pvector-wrapper-length/unsafe seq)))
                  seq]
                 [(and (vector? seq)
                       (= len (vector-length seq)))
                  (vector->pvector seq)]
                 [else
                  (wrap/len (raw:for/pvector #:length len
                                             ([elem seq])
                                             elem)
                            len)]))
             (wrap/len (raw:for/pvector #:length len
                                        ([elem seq-id])
                                        elem)
                       len)))]
    [(_ #:length len (clause ...) body ...)
     (small-length-literal? #'len)
     #'(wrap/len (raw:for/pvector #:length len
                                  (clause ...) body ...)
                 len)]
    [(_ #:length length-expr (clause ...) body ...)
     #'(let ([len length-expr])
         (wrap/len (raw:for/pvector #:length len
                                    (clause ...) body ...)
                   len))]
    [(_ ([elem (in-pvector pv-expr)]) body)
     (same-identifier? #'elem #'body)
     #'(let ([pv pv-expr])
         (if (pvector-wrapper? pv)
             pv
             (wrap (raw:for/pvector ([elem (in-pvector pv)]) elem))))]
    [(_ ([elem (in-pvector-reverse pv-expr)]) body)
     (same-identifier? #'elem #'body)
     #'(let ([pv pv-expr])
         (if (pvector-wrapper? pv)
             (for/pvector #:length (pvector-wrapper-length/unsafe pv)
                          ([elem (in-pvector-reverse pv)])
               elem)
             (wrap (raw:for/pvector ([elem (in-pvector-reverse pv)]) elem))))]
    [(_ ([elem (in-list lst-expr)]) body)
     (same-identifier? #'elem #'body)
     #'(let ([lst lst-expr])
         (if (list? lst)
             (list->pvector lst)
             (wrap (raw:for/pvector ([elem (in-list lst)]) elem))))]
    [(_ ([elem (in-vector vec-expr)]) body)
     (same-identifier? #'elem #'body)
     #'(let ([vec vec-expr])
         (if (vector? vec)
             (vector->pvector vec)
             (wrap (raw:for/pvector ([elem (in-vector vec)]) elem))))]
    [(_ ([elem seq-id]) body)
     (and (same-identifier? #'elem #'body)
          (identifier? #'seq-id))
     #'(let ([seq seq-id])
         (if (pvector-wrapper? seq)
             seq
             (wrap (raw:for/pvector ([elem seq]) elem))))]
    [(_ ([elem (in-range end)]) body)
     (and (same-identifier? #'elem #'body)
          (exact-nonnegative-integer? (syntax-e #'end)))
     (small-literal-range->pvector stx (syntax-e #'end))]
    [(_ ([elem (in-range start end)]) body)
     (and (same-identifier? #'elem #'body)
          (small-literal-in-range->pvector
           stx
           #'start
           #'end
           (datum->syntax stx 1)))
     (small-literal-in-range->pvector
      stx
      #'start
      #'end
      (datum->syntax stx 1))]
    [(_ ([elem (in-range start end step)]) body)
     (and (same-identifier? #'elem #'body)
          (small-literal-in-range->pvector stx #'start #'end #'step))
     (small-literal-in-range->pvector stx #'start #'end #'step)]
    [(_ ([elem (in-range end)]) body ...)
     (small-length-literal? #'end)
     #'(wrap/len (raw:for/pvector #:length end
                                  ([elem (in-range end)])
                                  body ...)
                 end)]
    [(_ (clause ...) body ...)
     #'(wrap (raw:for/pvector (clause ...) body ...))]))

(define-syntax (for*/pvector stx)
  (syntax-case stx (in-range in-list in-vector in-pvector in-pvector-reverse)
    [(_ #:length len ([elem (in-range end)]) body)
     (and (same-identifier? #'elem #'body)
          (exact-nonnegative-integer? (syntax-e #'len))
          (equal? (syntax-e #'len) (syntax-e #'end)))
     (small-literal-range->pvector stx (syntax-e #'len))]
    [(_ #:length len ([elem (in-range start end)]) body)
     (and (same-identifier? #'elem #'body)
          (small-literal-in-range/length->pvector
           stx
           #'len
           #'start
           #'end
           (datum->syntax stx 1)))
     (small-literal-in-range/length->pvector
      stx
      #'len
      #'start
      #'end
      (datum->syntax stx 1))]
    [(_ #:length len ([elem (in-range start end step)]) body)
     (and (same-identifier? #'elem #'body)
          (small-literal-in-range/length->pvector stx #'len #'start #'end #'step))
     (small-literal-in-range/length->pvector stx #'len #'start #'end #'step)]
    [(_ #:length len #:fill fill-expr (clause ...) body ...)
     (small-length-literal? #'len)
     #'(wrap/len (raw:for*/pvector #:length len #:fill fill-expr
                                   (clause ...) body ...)
                 len)]
    [(_ #:length length-expr #:fill fill-expr (clause ...) body ...)
     #'(let ([len length-expr])
         (wrap/len (raw:for*/pvector #:length len #:fill fill-expr
                                     (clause ...) body ...)
                   len))]
    [(_ #:length end ([elem (in-range end*)]) body ...)
     (and (identifier? #'end)
          (identifier? #'end*)
          (free-identifier=? #'end #'end*))
     #'(let ([len end])
         (wrap/len (raw:for*/pvector #:length len ([elem (in-range len)])
                                     body ...)
                   len))]
    [(_ #:length end ([elem (in-range start end*)]) body)
     (and (same-identifier? #'elem #'body)
          (identifier? #'end)
          (identifier? #'end*)
          (free-identifier=? #'end #'end*)
          (equal? (syntax-e #'start) 0))
     #'(sequence->pvector end)]
    [(_ #:length end ([elem (in-range start end* step)]) body)
     (and (same-identifier? #'elem #'body)
          (identifier? #'end)
          (identifier? #'end*)
          (free-identifier=? #'end #'end*)
          (equal? (syntax-e #'start) 0)
          (equal? (syntax-e #'step) 1))
     #'(sequence->pvector end)]
    [(_ #:length len ([elem (in-range end)]) body ...)
     (and (exact-nonnegative-integer? (syntax-e #'len))
          (equal? (syntax-e #'len) (syntax-e #'end)))
     #'(wrap/len (raw:for*/pvector #:length len ([elem (in-range end)])
                                   body ...)
                 len)]
    [(_ #:length length-expr ([elem (in-pvector pv-expr)]) body)
     (same-identifier? #'elem #'body)
     #'(let ([len length-expr])
         (if (exact-nonnegative-integer? len)
             (let ([pv pv-expr])
               (if (and (pvector-wrapper? pv)
                        (= len (pvector-wrapper-length/unsafe pv)))
                   pv
                   (wrap/len (raw:for*/pvector #:length len
                                               ([elem (in-pvector pv)])
                                               elem)
                             len)))
             (wrap/len (raw:for*/pvector #:length len
                                         ([elem (in-pvector pv-expr)])
                                         elem)
                       len)))]
    [(_ #:length length-expr ([elem (in-vector vec-expr)]) body)
     (same-identifier? #'elem #'body)
     #'(let ([len length-expr])
         (if (exact-nonnegative-integer? len)
             (let ([vec vec-expr])
               (if (and (vector? vec)
                        (= len (vector-length vec)))
                   (vector->pvector vec)
                   (wrap/len (raw:for*/pvector #:length len
                                               ([elem (in-vector vec)])
                                               elem)
                             len)))
             (wrap/len (raw:for*/pvector #:length len
                                         ([elem (in-vector vec-expr)])
                                         elem)
                       len)))]
    [(_ #:length length-expr ([elem seq-id]) body)
     (and (same-identifier? #'elem #'body)
          (identifier? #'seq-id))
     #'(let ([len length-expr])
         (if (exact-nonnegative-integer? len)
             (let ([seq seq-id])
               (cond
                 [(and (pvector-wrapper? seq)
                       (= len (pvector-wrapper-length/unsafe seq)))
                  seq]
                 [(and (vector? seq)
                       (= len (vector-length seq)))
                  (vector->pvector seq)]
                 [else
                  (wrap/len (raw:for*/pvector #:length len
                                              ([elem seq])
                                              elem)
                            len)]))
             (wrap/len (raw:for*/pvector #:length len
                                         ([elem seq-id])
                                         elem)
                       len)))]
    [(_ #:length len (clause ...) body ...)
     (small-length-literal? #'len)
     #'(wrap/len (raw:for*/pvector #:length len
                                   (clause ...) body ...)
                 len)]
    [(_ #:length length-expr (clause ...) body ...)
     #'(let ([len length-expr])
         (wrap/len (raw:for*/pvector #:length len
                                     (clause ...) body ...)
                   len))]
    [(_ ([elem (in-pvector pv-expr)]) body)
     (same-identifier? #'elem #'body)
     #'(let ([pv pv-expr])
         (if (pvector-wrapper? pv)
             pv
             (wrap (raw:for*/pvector ([elem (in-pvector pv)]) elem))))]
    [(_ ([elem (in-pvector-reverse pv-expr)]) body)
     (same-identifier? #'elem #'body)
     #'(let ([pv pv-expr])
         (if (pvector-wrapper? pv)
             (for*/pvector #:length (pvector-wrapper-length/unsafe pv)
                           ([elem (in-pvector-reverse pv)])
               elem)
             (wrap (raw:for*/pvector ([elem (in-pvector-reverse pv)]) elem))))]
    [(_ ([elem (in-list lst-expr)]) body)
     (same-identifier? #'elem #'body)
     #'(let ([lst lst-expr])
         (if (list? lst)
             (list->pvector lst)
             (wrap (raw:for*/pvector ([elem (in-list lst)]) elem))))]
    [(_ ([elem (in-vector vec-expr)]) body)
     (same-identifier? #'elem #'body)
     #'(let ([vec vec-expr])
         (if (vector? vec)
             (vector->pvector vec)
             (wrap (raw:for*/pvector ([elem (in-vector vec)]) elem))))]
    [(_ ([elem seq-id]) body)
     (and (same-identifier? #'elem #'body)
          (identifier? #'seq-id))
     #'(let ([seq seq-id])
         (if (pvector-wrapper? seq)
             seq
             (wrap (raw:for*/pvector ([elem seq]) elem))))]
    [(_ ([elem (in-range end)]) body)
     (and (same-identifier? #'elem #'body)
          (exact-nonnegative-integer? (syntax-e #'end)))
     (small-literal-range->pvector stx (syntax-e #'end))]
    [(_ ([elem (in-range start end)]) body)
     (and (same-identifier? #'elem #'body)
          (small-literal-in-range->pvector
           stx
           #'start
           #'end
           (datum->syntax stx 1)))
     (small-literal-in-range->pvector
      stx
      #'start
      #'end
      (datum->syntax stx 1))]
    [(_ ([elem (in-range start end step)]) body)
     (and (same-identifier? #'elem #'body)
          (small-literal-in-range->pvector stx #'start #'end #'step))
     (small-literal-in-range->pvector stx #'start #'end #'step)]
    [(_ ([elem (in-range end)]) body ...)
     (small-length-literal? #'end)
     #'(wrap/len (raw:for*/pvector #:length end
                                   ([elem (in-range end)])
                                   body ...)
                 end)]
    [(_ (clause ...) body ...)
     #'(wrap (raw:for*/pvector (clause ...) body ...))]))

(begin-for-syntax
  (define (match-ellipsis-id? stx)
    (and (identifier? stx)
         (let ([sym (syntax-e stx)])
           (and (symbol? sym)
                (let ([str (symbol->string sym)])
                  (or (equal? str "...")
                      (equal? str "___")
                      (regexp-match? #rx"^(\\.\\.|__)[0-9]+$" str)))))))

  (define (top-level-repetition? elems)
    (for/or ([elem (in-list elems)])
      (match-ellipsis-id? elem)))

  (define (match-ellipsis-min stx)
    (define str (symbol->string (syntax-e stx)))
    (cond
      [(or (equal? str "...") (equal? str "___")) 0]
      [(regexp-match #rx"^(\\.\\.|__)([0-9]+)$" str)
       => (lambda (m) (string->number (cadr m)))]
      [else #f]))

  (define (pattern-contains-identifier? v id)
    (cond
      [(identifier? v) (free-identifier=? v id)]
      [(syntax? v) (pattern-contains-identifier? (syntax-e v) id)]
      [(pair? v)
       (or (pattern-contains-identifier? (car v) id)
           (pattern-contains-identifier? (cdr v) id))]
      [(vector? v)
       (for/or ([elem (in-vector v)])
         (pattern-contains-identifier? elem id))]
      [else #f]))

	  (define (simple-final-repetition elems)
	    (define len (length elems))
	    (and (>= len 2)
	         (let* ([ellipsis (list-ref elems (sub1 len))]
                [repeat-pat (list-ref elems (- len 2))]
                [prefix-elems
                 (for/list ([i (in-range (- len 2))])
                   (list-ref elems i))])
           (and (match-ellipsis-id? ellipsis)
                (identifier? repeat-pat)
                (not (for/or ([prefix-elem (in-list prefix-elems)])
                       (pattern-contains-identifier? prefix-elem repeat-pat)))
	                (let ([min-repeat (match-ellipsis-min ellipsis)])
	                  (and min-repeat
	                       (list prefix-elems repeat-pat min-repeat)))))))

		  (define (pvector-pattern-transform stx)
	    (syntax-case stx ()
	      [(_) #'(? pvector-empty?)]
	      [(_ pat ...)
       (let ([elems (syntax->list #'(pat ...))])
         (cond
           [(top-level-repetition? elems)
            (let ([simple-repetition (simple-final-repetition elems)])
              (if simple-repetition
                  (let ([prefix-elems (car simple-repetition)]
                        [repeat-pat (cadr simple-repetition)]
                        [min-repeat (caddr simple-repetition)])
                    (with-syntax ([(idx ...)
                                   (for/list ([idx (in-range (length prefix-elems))])
                                     idx)]
                                  [(prefix-pat ...) prefix-elems]
                                  [repeat-pat repeat-pat]
                                  [prefix-len (length prefix-elems)]
                                  [min-repeat min-repeat])
                      #'(? pvector-wrapper?
                           (? (lambda (pv)
                                (>= (pvector-wrapper-length/unsafe pv)
                                    (+ prefix-len min-repeat)))
                              (and
                               (app (lambda (pv)
                                      (raw:pvector-ref
                                       (pvector-wrapper-tree/unsafe pv)
                                       idx))
                                    prefix-pat)
                               ...
                               (app (lambda (pv)
                                      (pvector-match-tail->list
                                       (pvector-wrapper-tree/unsafe pv)
                                       prefix-len
	                                       (pvector-wrapper-length/unsafe pv)))
	                                    repeat-pat))))))
		                  #'(? pvector?
		                       (app pvector->list (list pat ...)))))]
	           [else
	            (with-syntax ([(idx ...)
	                           (for/list ([idx (in-range (length elems))])
                             idx)]
                          [len (length elems)])
              #'(? pvector-wrapper?
                   (? (lambda (pv) (= (pvector-wrapper-length/unsafe pv) len))
                      (app pvector-wrapper-tree/unsafe
                           (and
                            (app (lambda (tree) (raw:pvector-ref tree idx)) pat)
                            ...)))))]))])))

(define-match-expander pvector
  pvector-pattern-transform
  (lambda (stx)
    (syntax-case stx ()
      [(_ elem ...)
       (let* ([elems (syntax->list #'(elem ...))]
              [len (length elems)])
         (cond
           [(zero? len) #'empty-pvector]
           [(direct-small-values->pvector elems)]
           [(<= len pvector-single-chunk-arity-limit)
            (with-syntax ([len (datum->syntax stx len)])
              #'(small-immutable-vector->pvector
                 (vector-immutable elem ...)
                 len))]
           [else
            (with-syntax ([len (datum->syntax stx len)])
              #'(wrap/len (raw:vector->pvector (vector-immutable elem ...))
                          len))]))]
      [_ #'pvector/proc])))

(begin-for-syntax
  (struct pvector*-piece (kind len pat stx) #:transparent)

  (define (pvector*-keyword? stx kw)
    (and (keyword? (syntax-e stx))
         (eq? (syntax-e stx) kw)))

  (define (parse-pvector*-pieces who stx elems)
    (let loop ([elems elems] [pieces null])
      (cond
        [(null? elems) (reverse pieces)]
        [(pvector*-keyword? (car elems) '#:span)
         (unless (and (pair? (cdr elems)) (pair? (cddr elems)))
           (raise-syntax-error
            who
            "expected a length expression and a pvector pattern after #:span"
            stx
            (car elems)))
         (loop (cdddr elems)
               (cons (pvector*-piece 'span (cadr elems) (caddr elems) (car elems))
                     pieces))]
        [(pvector*-keyword? (car elems) '#:rest)
         (unless (pair? (cdr elems))
           (raise-syntax-error
            who
            "expected a pvector pattern after #:rest"
            stx
            (car elems)))
         (loop (cddr elems)
               (cons (pvector*-piece 'rest #f (cadr elems) (car elems))
                     pieces))]
        [else
         (loop (cdr elems)
               (cons (pvector*-piece 'element #f (car elems) (car elems))
                     pieces))])))

  (define (count-rest-segments pieces)
    (for/sum ([piece (in-list pieces)])
      (if (eq? (pvector*-piece-kind piece) 'rest)
          1
          0)))

  (define (checked-pvector*-pieces who stx pieces)
    (define rest-count (count-rest-segments pieces))
    (when (> rest-count 1)
      (raise-syntax-error who
                          "expected at most one variable-length pvector segment"
                          stx))
    pieces)

  (define (generate-pvector*-match who stx pieces)
    (define checked-pieces (checked-pvector*-pieces who stx pieces))
    (let ()
       (define has-rest?
         (for/or ([piece (in-list checked-pieces)])
           (eq? (pvector*-piece-kind piece) 'rest)))
       (define fixed-segment-len-bindings null)
       (define fixed-segment-len-ids null)
       (define element-count 0)
       (define runtime-pieces
         (for/list ([piece (in-list checked-pieces)])
           (case (pvector*-piece-kind piece)
             [(element)
              (set! element-count (add1 element-count))
              (list #'1 (pvector*-piece-pat piece) #t)]
             [(rest)
              (list #'rest-len (pvector*-piece-pat piece) #f)]
             [else
              (define len-id
                (car (generate-temporaries
                      (list (pvector*-piece-stx piece)))))
              (set! fixed-segment-len-bindings
                    (cons #`[#,len-id #,(pvector*-piece-len piece)]
                          fixed-segment-len-bindings))
              (set! fixed-segment-len-ids
                    (cons len-id fixed-segment-len-ids))
              (list len-id (pvector*-piece-pat piece) #f)])))
       (define len-bindings (reverse fixed-segment-len-bindings))
       (define len-ids (reverse fixed-segment-len-ids))
       (define fixed-total-expr
         (if (null? len-ids)
             #`#,element-count
             #`(+ #,element-count #,@len-ids)))
       (define len-check-exprs
         (for/list ([len-id (in-list len-ids)])
           #`(exact-nonnegative-integer? #,len-id)))
       (define starts
         (generate-temporaries
          (for/list ([i (in-range (add1 (length runtime-pieces)))]) 'pos)))
       (define values
         (generate-temporaries
          (for/list ([piece (in-list runtime-pieces)]) 'piece)))
       (define extract-bindings
         (cons #`[#,(car starts) 0]
               (apply
                append
                (for/list ([runtime-piece (in-list runtime-pieces)]
                           [start (in-list starts)]
                           [next-start (in-list (cdr starts))]
                           [value (in-list values)])
                  (define len-expr (car runtime-piece))
                  (define element? (caddr runtime-piece))
                  (list
                   #`[#,value
                      #,(if element?
                            #`(raw:pvector-ref tree #,start)
                            #`(let ([end (+ #,start #,len-expr)])
                                (cond
                                  [(= #,start end) empty-pvector]
                                  [(and (zero? #,start) (= end total-len)) pv]
                                  [else
                                   (wrap/len (raw:pvector-copy tree #,start end)
                                             #,len-expr)])))]
                   #`[#,next-start (+ #,start #,len-expr)])))))
       (define pats
         (for/list ([runtime-piece (in-list runtime-pieces)])
           (cadr runtime-piece)))
       (define success-expr
         #`(let* (#,@extract-bindings)
             (list #,@values)))
       (define checked-expr
         #`(and #,@len-check-exprs
                (let ([fixed-total #,fixed-total-expr])
                  #,(if has-rest?
                        #`(let ([rest-len (- total-len fixed-total)])
                            (and (exact-nonnegative-integer? rest-len)
                                 #,success-expr))
                        #`(and (= total-len fixed-total)
                               #,success-expr)))))
       #`(? pvector-wrapper?
            (app (lambda (pv)
                   (define tree (pvector-wrapper-tree/unsafe pv))
                   (define total-len (pvector-wrapper-length/unsafe pv))
                   (let (#,@len-bindings)
                     #,checked-expr))
                 (list #,@pats)))))
  )

(define-match-expander pvector*
  (lambda (stx)
    (syntax-case stx ()
      [(_ seg ...)
       (generate-pvector*-match
        'pvector*
        stx
        (parse-pvector*-pieces 'pvector* stx (syntax->list #'(seg ...))))]
      [(_ seg ... . rest-pat)
       (generate-pvector*-match
        'pvector*
        stx
        (append
         (parse-pvector*-pieces 'pvector* stx (syntax->list #'(seg ...)))
         (list (pvector*-piece 'rest
                               #f
                               #'rest-pat
                               #'rest-pat))))])))

(define (pvector-print pv port mode)
  (display "(pvector" port)
  (for ([elem (raw:in-pvector (pvector-wrapper-tree/unsafe pv))])
    (display " " port)
    (case mode
      [(#t) (write elem port)]
      [(#f) (display elem port)]
      [else (print elem port)]))
  (display ")" port))

(define (pvector-equal? pv other recur)
  (or (eq? pv other)
      (and (pvector-wrapper? other)
           (let ([len (pvector-wrapper-length/unsafe pv)]
                 [other-len (pvector-wrapper-length/unsafe other)])
            (and (unsafe-fx= len other-len)
                 (let ([tree (pvector-wrapper-tree/unsafe pv)]
                       [other-tree (pvector-wrapper-tree/unsafe other)])
                   (let/ec return
                     (let ([index 0])
                       (raw:pvector-for-each
                        tree
                        (lambda (elem)
                          (define other-elem
                            (raw:pvector-ref other-tree index))
                          (unless (or (eq? elem other-elem)
                                      (recur elem other-elem))
                            (return #f))
                          (set! index (unsafe-fx+ index 1)))))
                     #t)))))))

(define sampled-hash-edge-count 16)
(define sampled-hash-total-count 48)

(define (pvector-hash->fx v)
  (cond
    [(fixnum? v) v]
    [else (bitwise-and v (most-positive-fixnum))]))

(define (pvector-hash-mix hc)
  (let ([hc2 (fx+/wraparound hc
                             (fxlshift/wraparound
                              (fx+/wraparound hc 1)
                              10))])
    (fxxor hc2 (fxrshift/logical hc2 6))))

(define (pvector-hash-combine a b)
  (define mxa (pvector-hash-mix (pvector-hash->fx a)))
  (fx+/wraparound
   mxa
   (pvector-hash-mix (fx+/wraparound mxa (pvector-hash->fx b)))))

(define (pvector-hash-range tree start count recur hc)
  (let loop ([remaining count] [pos start] [hc hc])
    (cond
      [(zero? remaining) hc]
      [else
       (loop (sub1 remaining)
             (add1 pos)
             (pvector-hash-combine
              hc
              (recur (raw:pvector-ref tree pos))))])))

(define (pvector-hash-sampled tree len recur seed)
  (define hc0 (pvector-hash-combine seed len))
  (define hc1
    (pvector-hash-range tree 0 sampled-hash-edge-count recur hc0))
  (define middle-len (- len (* 2 sampled-hash-edge-count)))
  (define hc2
    (let loop ([i 0] [hc hc1])
      (cond
        [(= i sampled-hash-edge-count) hc]
        [else
         (define pos
           (+ sampled-hash-edge-count
              (quotient (* i middle-len) sampled-hash-edge-count)))
         (loop (add1 i)
               (pvector-hash-combine
                hc
                (recur (raw:pvector-ref tree pos))))])))
  (pvector-hash-range tree
                      (- len sampled-hash-edge-count)
                      sampled-hash-edge-count
                      recur
                      hc2))

(define (pvector-hash-full tree len recur seed)
  (define hc (pvector-hash-combine seed len))
  (raw:pvector-for-each
   tree
   (lambda (elem)
     (set! hc (pvector-hash-combine hc (recur elem)))))
  hc)

(define (pvector-hash/chunks pv recur seed)
  (define len (pvector-wrapper-length/unsafe pv))
  (define tree (pvector-wrapper-tree/unsafe pv))
  (if (>= len sampled-hash-total-count)
      (pvector-hash-sampled tree len recur seed)
      (pvector-hash-full tree len recur seed)))

(define (pvector-hash-code pv recur)
  (pvector-hash/chunks pv recur 16381))

(define (pvector-secondary-hash-code pv recur)
  (pvector-hash/chunks pv recur 32749))
