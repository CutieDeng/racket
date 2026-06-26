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
         (only-in racket/pretty pretty-write)
         (only-in racket/vector vector-copy)
         racket/unsafe/ops
         (for-syntax racket/base))

(provide (rename-out [exported-pvector? pvector?]
                     [exported-pvector-empty pvector-empty]
                     [exported-pvector-empty? pvector-empty?]
                     [exported-pvector->list pvector->list]
                     [exported-pvector->vector pvector->vector]
                     [exported-pvector-length pvector-length]
                     [exported-pvector-ref pvector-ref]
                     [exported-pvector-set pvector-set]
                     [exported-pvector-first pvector-first]
                     [exported-pvector-last pvector-last]
                     [exported-pvector-cons-left pvector-cons-left]
                     [exported-pvector-cons-right pvector-cons-right]
                     [exported-pvector-pop-left pvector-pop-left]
                     [exported-pvector-pop-right pvector-pop-right]
                     [exported-pvector-append pvector-append]
                     [exported-pvector-map pvector-map]
                     [exported-pvector-for-each pvector-for-each]
                     [exported-pvector-insert pvector-insert]
                     [exported-pvector-delete pvector-delete]
                     [exported-pvector-take pvector-take]
                     [exported-pvector-drop pvector-drop]
                     [exported-pvector-take-right pvector-take-right]
                     [exported-pvector-drop-right pvector-drop-right]
                     [exported-pvector-split pvector-split]
                     [exported-pvector-split-at pvector-split-at])
         pvector
         make-pvector
         list->pvector
         vector->pvector
         sequence->pvector
         pvector-subvector
         in-pvector
         in-pvector-reverse
         make-pvector-literal-pool
         pvector-literal-pool?
         pvector->literal-datum
         pvectors->literal-datum
         literal-datum->pvector
         write-pvector-literal
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
   (lambda (pv) (unsafe-fx= 0 (pvector-length/unsafe pv)))
   (lambda (pv) (raw:pvector-view-left/fast (pvector-tree/unsafe pv)))
   (lambda (pv)
     (define len (pvector-length/unsafe pv))
     (if (unsafe-fx= len 1)
         empty-pvector
         (let-values ([(_ rest)
                       (raw:pvector-pop-left (pvector-tree/unsafe pv))])
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

(define direct-raw-sequence?
  (raw:pvector-runtime-adapter-core-available?))

(define direct-raw-cursor?
  (raw:pvector-runtime-adapter-cursor-available?))

;; Historically, the raw-public path was enabled only for BC, whose native
;; pvector values already carried the public struct properties. CS can use the
;; same raw-public path once the runtime exposes a safe property-install hook.
(define bc-native-public?
  (and direct-raw-sequence?
       (or (eq? (system-type 'vm) 'racket)
           (raw:pvector-runtime-adapter-public-properties-available?))))

(define empty-pvector
  (if bc-native-public?
      (raw:pvector-empty)
      (pvector-wrapper (raw:pvector-empty) 0)))

(define (raw-core-pvector? v)
  (and bc-native-public?
       (raw:pvector? v)))

(define (pvector? v)
  (if bc-native-public?
      (raw:pvector? v)
      (pvector-wrapper? v)))

(define (pvector-tree/unsafe pv)
  (if (pvector-wrapper? pv)
      (unsafe-struct-ref pv 0)
      pv))

(define (pvector-length/unsafe pv)
  (if (pvector-wrapper? pv)
      (unsafe-struct-ref pv 1)
      (raw:pvector-length/fast pv)))

(define (wrap/len tree len)
  (cond
    [bc-native-public? tree]
    [(zero? len) empty-pvector]
    [else (pvector-wrapper tree len)]))

(define (wrap tree)
  (cond
    [bc-native-public? tree]
    [(raw:pvector-empty? tree) empty-pvector]
    [else (pvector-wrapper tree (raw:pvector-length tree))]))

(define (check-pvector who v)
  (unless (pvector? v)
    (raise-argument-error who "pvector?" v))
  v)

(define (unwrap who v)
  (pvector-tree/unsafe (check-pvector who v)))

(define (check-nonnegative-integer who n)
  (unless (exact-nonnegative-integer? n)
    (raise-argument-error who "exact-nonnegative-integer?" n))
  n)

(define (checked-wrapper+length who pv)
  (define pv* (check-pvector who pv))
  (values pv* (pvector-length/unsafe pv*)))

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

(struct pvector-literal-pool (state)
  #:sealed)

(define (make-pvector-literal-pool)
  (pvector-literal-pool (raw:make-pvector-literal-state)))

(define (check-pvector-literal-pool who pool)
  (unless (pvector-literal-pool? pool)
    (raise-argument-error who "pvector-literal-pool?" pool))
  pool)

(define (pvector-flat-literal-datum pv)
  (list (pvector->list pv) #f))

(define (check-pvector-literal-mode who mode)
  (case mode
    [(raw expanded) mode]
    [else (raise-argument-error who "(or/c 'raw 'expanded)" mode)]))

(define (pvector-literal-root! who pv pool)
  (define pv* (check-pvector who pv))
  (define pool* (check-pvector-literal-pool who pool))
  (raw:pvector-literal-emit!
   (pvector-tree/unsafe pv*)
   (pvector-literal-pool-state pool*)))

(define (pvector-raw-literal-datum who pv pool)
  (let ([root (pvector-literal-root! who pv pool)])
    (list root
          (raw:pvector-literal-state-defs
           (pvector-literal-pool-state pool)))))

(define (pvector->literal-datum pv
                                [pool (make-pvector-literal-pool)]
                                #:mode [mode 'raw])
  (define pv* (check-pvector 'pvector->literal-datum pv))
  (define pool* (check-pvector-literal-pool 'pvector->literal-datum pool))
  (case (check-pvector-literal-mode 'pvector->literal-datum mode)
    [(expanded) (pvector-flat-literal-datum pv*)]
    [(raw)
     (if (raw:pvector-runtime-adapter-literal-available?)
         (pvector-raw-literal-datum 'pvector->literal-datum pv* pool*)
         (pvector-flat-literal-datum pv*))]))

(define (pvectors->literal-datum pvs
                                 [pool (make-pvector-literal-pool)]
                                 #:mode [mode 'raw])
  (define pool* (check-pvector-literal-pool 'pvectors->literal-datum pool))
  (case (check-pvector-literal-mode 'pvectors->literal-datum mode)
    [(expanded)
     (list
      (for/list ([pv pvs])
        (pvector->list (check-pvector 'pvectors->literal-datum pv)))
      #f)]
    [(raw)
     (if (raw:pvector-runtime-adapter-literal-available?)
         (let ([roots
                (for/list ([pv pvs])
                  (pvector-literal-root! 'pvectors->literal-datum pv pool*))])
           (list roots
                 (raw:pvector-literal-state-defs
                  (pvector-literal-pool-state pool*))))
         (list
          (for/list ([pv pvs])
            (pvector->list (check-pvector 'pvectors->literal-datum pv)))
          #f))]))

(define (literal-datum->pvector datum)
  (if (raw:pvector-runtime-adapter-literal-available?)
      (wrap (raw:pvector-literal->pvector datum))
      (cond
        [(and (pair? datum)
              (pair? (cdr datum))
              (null? (cddr datum))
              (eq? (cadr datum) #f)
              (list? (car datum)))
         (list->pvector (car datum))]
        [else
         (raise-arguments-error
          'literal-datum->pvector
          "native pvector literal input is not available for raw literals"
          "datum" datum)])))

(define (write-pvector-literal pv
                               [port (current-output-port)]
                               [pool (make-pvector-literal-pool)]
                               #:mode [mode 'raw]
                               #:pretty? [pretty? #f])
  (unless (boolean? pretty?)
    (raise-argument-error 'write-pvector-literal "boolean?" pretty?))
  (display "#pvector" port)
  (let ([datum (pvector->literal-datum pv pool #:mode mode)])
    (if pretty?
        (pretty-write datum port)
        (write datum port)))
  (void))

(define (pvector-empty)
  empty-pvector)

(define (pvector-empty? v)
  (eq? v empty-pvector))

(define (pvector-gen-sequence pv)
  (define tree (pvector-tree/unsafe pv))
  (cond
    [direct-raw-cursor?
     (values
      raw:pvector-cursor-value/fast
      #f
      raw:pvector-cursor-next/fast
      (raw:pvector-cursor-start/fast tree #f)
      (lambda (cursor) cursor)
      #f
      #f)]
    [direct-raw-sequence?
     (define len (pvector-length/unsafe pv))
     (values
      (lambda (index) (raw:pvector-ref/fast tree index))
      #f
      (lambda (index) (unsafe-fx+ index 1))
      0
      (lambda (index) (unsafe-fx< index len))
      #f
      #f)]
    [else
     (define vec (raw:pvector->vector tree))
     (define len (unsafe-vector-length vec))
     (values
      (lambda (index) (unsafe-vector-ref vec index))
      #f
      (lambda (index) (unsafe-fx+ index 1))
      0
      (lambda (index) (unsafe-fx< index len))
      #f
      #f)]))

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
  (define pvector-inline-vector-arity-limit 64)
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
      [(<= len pvector-inline-vector-arity-limit)
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
    [(pvector? pv)
     (define tree (pvector-tree/unsafe pv))
     (case (pvector-length/unsafe pv)
       [(1) (list (raw:pvector-view-left/fast tree))]
       [(2) (list (raw:pvector-view-left/fast tree)
                  (raw:pvector-view-right/fast tree))]
       [(3) (list (raw:pvector-view-left/fast tree)
                  (raw:pvector-ref/fast tree 1)
                  (raw:pvector-view-right/fast tree))]
       [(4) (list (raw:pvector-view-left/fast tree)
                  (raw:pvector-ref/fast tree 1)
                  (raw:pvector-ref/fast tree 2)
                  (raw:pvector-view-right/fast tree))]
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
    [(pvector? pv)
     (define tree (pvector-tree/unsafe pv))
     (case (pvector-length/unsafe pv)
       [(1) (vector (raw:pvector-view-left/fast tree))]
       [(2) (vector (raw:pvector-view-left/fast tree)
                    (raw:pvector-view-right/fast tree))]
       [(3) (vector (raw:pvector-view-left/fast tree)
                    (raw:pvector-ref/fast tree 1)
                    (raw:pvector-view-right/fast tree))]
       [(4) (vector (raw:pvector-view-left/fast tree)
                    (raw:pvector-ref/fast tree 1)
                    (raw:pvector-ref/fast tree 2)
                    (raw:pvector-view-right/fast tree))]
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
        [(pvector? seq) seq]
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
         (if (pvector? pv)
             pv
             (sequence->pvector/proc (in-pvector pv))))]
    [(_ (in-pvector-reverse pv-expr))
     #'(let ([pv pv-expr])
         (if (pvector? pv)
             (for/pvector #:length (pvector-length/unsafe pv)
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

(define (in-range-end->pvector end)
  (if (exact-nonnegative-integer? end)
      (sequence->pvector end)
      (sequence->pvector (in-range end))))

(begin-encourage-inline
  (define (pvector-length pv)
    (unless (pvector? pv)
      (raise-argument-error 'pvector-length "pvector?" pv))
    (pvector-length/unsafe pv))

  (define (pvector-ref pv index)
    (cond
      [(and (fixnum? index) (unsafe-fx>= index 0))
       (unless (pvector? pv)
         (raise-argument-error 'pvector-ref "pvector?" pv))
       (if (unsafe-fx= index 0)
           (begin
             (when (eq? pv empty-pvector)
               (raise-range-error 'pvector-ref "pvector" "" index pv 0 -1))
             (raw:pvector-view-left/fast (pvector-tree/unsafe pv)))
           (let ([len (pvector-length/unsafe pv)])
             (when (unsafe-fx>= index len)
               (raise-range-error 'pvector-ref "pvector" "" index pv 0 (sub1 len)))
             (define tree (pvector-tree/unsafe pv))
             (if (unsafe-fx= index (unsafe-fx- len 1))
                 (raw:pvector-view-right/fast tree)
                 (raw:pvector-ref/fast tree index))))]
      [else
       (check-nonnegative-integer 'pvector-ref index)
       (unless (pvector? pv)
         (raise-argument-error 'pvector-ref "pvector?" pv))
       (define len (pvector-length/unsafe pv))
       (when (>= index len)
         (raise-range-error 'pvector-ref "pvector" "" index pv 0 (sub1 len)))
       (define tree (pvector-tree/unsafe pv))
       (cond
         [(zero? index) (raw:pvector-view-left/fast tree)]
         [(= index (sub1 len)) (raw:pvector-view-right/fast tree)]
         [else (raw:pvector-ref tree index)])]))

  (define (pvector-set pv index value)
    (cond
      [(and (fixnum? index) (unsafe-fx>= index 0))
       (unless (pvector? pv)
         (raise-argument-error 'pvector-set "pvector?" pv))
       (define len (pvector-length/unsafe pv))
       (when (unsafe-fx>= index len)
         (raise-range-error 'pvector-set "pvector" "" index pv 0 (sub1 len)))
       (define tree (pvector-tree/unsafe pv))
       (define tree^ (raw:pvector-set tree index value))
       (if (eq? tree^ tree)
           pv
           (wrap/len tree^ len))]
      [else
       (check-nonnegative-integer 'pvector-set index)
       (unless (pvector? pv)
         (raise-argument-error 'pvector-set "pvector?" pv))
       (define len (pvector-length/unsafe pv))
       (when (>= index len)
         (raise-range-error 'pvector-set "pvector" "" index pv 0 (sub1 len)))
       (define tree (pvector-tree/unsafe pv))
       (define tree^ (raw:pvector-set tree index value))
       (if (eq? tree^ tree)
           pv
           (wrap/len tree^ len))]))

  (define (pvector-first pv)
    (when (eq? pv empty-pvector)
      (raise-arguments-error 'pvector-first "pvector is empty" "pvector" pv))
    (unless (pvector? pv)
      (raise-argument-error 'pvector-first "pvector?" pv))
    (raw:pvector-view-left/fast (pvector-tree/unsafe pv)))

  (define (pvector-last pv)
    (when (eq? pv empty-pvector)
      (raise-arguments-error 'pvector-last "pvector is empty" "pvector" pv))
    (unless (pvector? pv)
      (raise-argument-error 'pvector-last "pvector?" pv))
    (raw:pvector-view-right/fast (pvector-tree/unsafe pv)))

  (define (pvector-cons-left pv value)
    (unless (pvector? pv)
      (raise-argument-error 'pvector-cons-left "pvector?" pv))
    (wrap/len (raw:pvector-cons-left (pvector-tree/unsafe pv) value)
              (unsafe-fx+ (pvector-length/unsafe pv) 1)))

  (define (pvector-cons-right pv value)
    (unless (pvector? pv)
      (raise-argument-error 'pvector-cons-right "pvector?" pv))
    (wrap/len (raw:pvector-cons-right (pvector-tree/unsafe pv) value)
              (unsafe-fx+ (pvector-length/unsafe pv) 1)))

  (define (pvector-pop-left pv)
    (cond
      [(pvector? pv)
       (define len (pvector-length/unsafe pv))
       (define tree (pvector-tree/unsafe pv))
       (cond
         [(unsafe-fx= len 0)
          (raise-arguments-error 'pvector-pop-left "pvector is empty" "pvector" pv)]
         [(unsafe-fx= len 1)
          (values (raw:pvector-view-left/fast tree) empty-pvector)]
         [else
          (let-values ([(value rest) (raw:pvector-pop-left tree)])
            (values value (wrap/len rest (unsafe-fx- len 1))))])]
      [else
       (raise-argument-error 'pvector-pop-left "pvector?" pv)]))

  (define (pvector-pop-right pv)
    (cond
      [(pvector? pv)
       (define len (pvector-length/unsafe pv))
       (define tree (pvector-tree/unsafe pv))
       (cond
         [(unsafe-fx= len 0)
          (raise-arguments-error 'pvector-pop-right "pvector is empty" "pvector" pv)]
         [(unsafe-fx= len 1)
          (values (raw:pvector-view-right/fast tree) empty-pvector)]
         [else
          (let-values ([(value rest) (raw:pvector-pop-right tree)])
            (values value (wrap/len rest (unsafe-fx- len 1))))])]
      [else
       (raise-argument-error 'pvector-pop-right "pvector?" pv)])))

(define (pvector-append pv0 pv1)
  (cond
    [(and (pvector? pv0) (pvector? pv1))
     (define left-len (pvector-length/unsafe pv0))
     (define right-len (pvector-length/unsafe pv1))
     (cond
       [(unsafe-fx= left-len 0) pv1]
       [(unsafe-fx= right-len 0) pv0]
       [else
        (wrap/len (raw:pvector-append (pvector-tree/unsafe pv0)
                                      (pvector-tree/unsafe pv1))
                  (unsafe-fx+ left-len right-len))])]
    [else
     (define left (check-pvector 'pvector-append pv0))
     (define right (check-pvector 'pvector-append pv1))
     (define left-len (pvector-length/unsafe left))
     (define right-len (pvector-length/unsafe right))
     (cond
       [(unsafe-fx= left-len 0) right]
       [(unsafe-fx= right-len 0) left]
       [else
        (wrap/len (raw:pvector-append (pvector-tree/unsafe left)
                                      (pvector-tree/unsafe right))
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
    [(and (eq? proc values) (pvector? pv)) pv]
    [else
     (define pv* (check-pvector 'pvector-map pv))
     (if (eq? proc values)
         pv*
         (let ([len (pvector-length/unsafe pv*)])
           (cond
             [(eq? proc void) (make-pvector/known-length len (void))]
             [else
              (check-unary-procedure 'pvector-map proc)
              (cond
                [(unsafe-fx> len 0)
                 (wrap/len (raw:pvector-map (pvector-tree/unsafe pv*) proc) len)]
                [else empty-pvector])])))]))

(define (pvector-for-each pv proc)
  (cond
    [(and (or (eq? proc void)
              (eq? proc values))
          (pvector? pv))
     (void)]
    [else
     (define pv* (check-pvector 'pvector-for-each pv))
     (unless (or (eq? proc void)
                 (eq? proc values))
       (check-unary-procedure 'pvector-for-each proc)
       (define len (pvector-length/unsafe pv*))
       (cond
         [(unsafe-fx> len 1)
          (raw:pvector-for-each (pvector-tree/unsafe pv*) proc)]
         [(unsafe-fx= len 1)
          (proc (raw:pvector-view-left/fast (pvector-tree/unsafe pv*)))]))
     (void)]))

(define (pvector-insert pv index value)
  (cond
    [(and (fixnum? index) (unsafe-fx>= index 0))
     (unless (pvector? pv)
       (raise-argument-error 'pvector-insert "pvector?" pv))
     (define len (pvector-length/unsafe pv))
     (when (unsafe-fx> index len)
       (raise-range-error 'pvector-insert "pvector" "" index pv 0 len))
     (wrap/len (raw:pvector-insert (pvector-tree/unsafe pv) index value)
               (unsafe-fx+ len 1))]
    [else
     (define-values (pv* len) (check-end-index/wrapper 'pvector-insert pv index))
     (wrap/len (raw:pvector-insert (pvector-tree/unsafe pv*) index value)
               (unsafe-fx+ len 1))]))

(define (pvector-delete pv index)
  (cond
    [(and (eqv? index 0) (pvector? pv))
     (define len (pvector-length/unsafe pv))
     (define tree (pvector-tree/unsafe pv))
     (cond
       [(unsafe-fx= len 0)
        (raise-range-error 'pvector-delete "pvector" "" index pv 0 -1)]
       [(unsafe-fx= len 1)
        (values empty-pvector (raw:pvector-view-left/fast tree))]
       [else
        (let-values ([(value rest) (raw:pvector-pop-left tree)])
          (values (wrap/len rest (unsafe-fx- len 1)) value))])]
    [(and (fixnum? index) (unsafe-fx>= index 0))
     (unless (pvector? pv)
       (raise-argument-error 'pvector-delete "pvector?" pv))
     (define len (pvector-length/unsafe pv))
     (define tree (pvector-tree/unsafe pv))
     (cond
       [(unsafe-fx>= index len)
        (raise-range-error 'pvector-delete "pvector" "" index pv 0 (unsafe-fx- len 1))]
       [(unsafe-fx= len 1)
        (values empty-pvector (raw:pvector-view-left/fast tree))]
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
     (define tree (pvector-tree/unsafe pv*))
     (if (unsafe-fx= len 1)
         (values empty-pvector (raw:pvector-view-left/fast tree))
         (let-values ([(rest value) (raw:pvector-delete tree index)])
           (values (wrap/len rest (unsafe-fx- len 1)) value)))]))

(define (pvector-take pv pos)
  (cond
    [(eqv? pos 0)
     (if (pvector? pv)
         empty-pvector
         (begin
           (check-pvector 'pvector-take pv)
           empty-pvector))]
    [(and (fixnum? pos) (unsafe-fx>= pos 0))
     (unless (pvector? pv)
       (raise-argument-error 'pvector-take "pvector?" pv))
     (define len (pvector-length/unsafe pv))
     (cond
       [(unsafe-fx> pos len)
        (raise-range-error 'pvector-take "pvector" "" pos pv 0 len)]
       [(unsafe-fx= pos len) pv]
       [else (wrap/len (raw:pvector-take (pvector-tree/unsafe pv) pos) pos)])]
    [else
     (define-values (pv* len) (check-end-index/wrapper 'pvector-take pv pos))
     (cond
       [(zero? pos) empty-pvector]
       [(= pos len) pv*]
       [else (wrap/len (raw:pvector-take (pvector-tree/unsafe pv*) pos) pos)])]))

(define (pvector-drop pv pos)
  (cond
    [(eqv? pos 0)
     (if (pvector? pv)
         pv
         (check-pvector 'pvector-drop pv))]
    [(and (fixnum? pos) (unsafe-fx>= pos 0))
     (unless (pvector? pv)
       (raise-argument-error 'pvector-drop "pvector?" pv))
     (define len (pvector-length/unsafe pv))
     (cond
       [(unsafe-fx> pos len)
        (raise-range-error 'pvector-drop "pvector" "" pos pv 0 len)]
       [(unsafe-fx= pos len) empty-pvector]
       [else (wrap/len (raw:pvector-drop (pvector-tree/unsafe pv) pos)
                       (unsafe-fx- len pos))])]
    [else
     (define-values (pv* len) (check-end-index/wrapper 'pvector-drop pv pos))
     (cond
       [(zero? pos) pv*]
       [(= pos len) empty-pvector]
       [else (wrap/len (raw:pvector-drop (pvector-tree/unsafe pv*) pos)
                       (unsafe-fx- len pos))])]))

(define (pvector-take-right pv pos)
  (cond
    [(eqv? pos 0)
     (if (pvector? pv)
         empty-pvector
         (begin
           (check-pvector 'pvector-take-right pv)
           empty-pvector))]
    [(and (fixnum? pos) (unsafe-fx>= pos 0))
     (unless (pvector? pv)
       (raise-argument-error 'pvector-take-right "pvector?" pv))
     (define len (pvector-length/unsafe pv))
     (cond
       [(unsafe-fx> pos len)
        (raise-range-error 'pvector-take-right "pvector" "" pos pv 0 len)]
       [(unsafe-fx= pos len) pv]
       [else (wrap/len (raw:pvector-take-right (pvector-tree/unsafe pv) pos) pos)])]
    [else
     (define-values (pv* len) (check-end-index/wrapper 'pvector-take-right pv pos))
     (cond
       [(zero? pos) empty-pvector]
       [(= pos len) pv*]
       [else (wrap/len (raw:pvector-take-right (pvector-tree/unsafe pv*) pos) pos)])]))

(define (pvector-drop-right pv pos)
  (cond
    [(eqv? pos 0)
     (if (pvector? pv)
         pv
         (check-pvector 'pvector-drop-right pv))]
    [(and (fixnum? pos) (unsafe-fx>= pos 0))
     (unless (pvector? pv)
       (raise-argument-error 'pvector-drop-right "pvector?" pv))
     (define len (pvector-length/unsafe pv))
     (cond
       [(unsafe-fx> pos len)
        (raise-range-error 'pvector-drop-right "pvector" "" pos pv 0 len)]
       [(unsafe-fx= pos len) empty-pvector]
       [else (wrap/len (raw:pvector-drop-right (pvector-tree/unsafe pv) pos)
                       (unsafe-fx- len pos))])]
    [else
     (define-values (pv* len) (check-end-index/wrapper 'pvector-drop-right pv pos))
     (cond
       [(zero? pos) pv*]
       [(= pos len) empty-pvector]
       [else (wrap/len (raw:pvector-drop-right (pvector-tree/unsafe pv*) pos)
                       (unsafe-fx- len pos))])]))

(define (pvector-subvector/finish pv* len start end)
  (define new-len (unsafe-fx- end start))
  (cond
    [(unsafe-fx= new-len 0) empty-pvector]
    [(and (unsafe-fx= start 0) (unsafe-fx= end len)) pv*]
    [(unsafe-fx= start 0)
     (wrap/len (raw:pvector-take (pvector-tree/unsafe pv*) end) new-len)]
    [(unsafe-fx= end len)
     (wrap/len (raw:pvector-drop (pvector-tree/unsafe pv*) start) new-len)]
    [else (wrap/len (raw:pvector-copy (pvector-tree/unsafe pv*) start end)
                    new-len)]))

(define pvector-subvector
  (case-lambda
    [(pv start)
     (cond
       [(eqv? start 0)
       (if (pvector? pv)
           pv
           (check-pvector 'pvector-subvector pv))]
       [(and (fixnum? start) (unsafe-fx>= start 0))
        (unless (pvector? pv)
          (raise-argument-error 'pvector-subvector "pvector?" pv))
        (define len (pvector-length/unsafe pv))
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
        (if (pvector? pv)
            empty-pvector
            (begin
              (check-pvector 'pvector-subvector pv)
              empty-pvector))]
       [(and (fixnum? start) (unsafe-fx>= start 0)
             (fixnum? end) (unsafe-fx>= end 0))
        (unless (pvector? pv)
          (raise-argument-error 'pvector-subvector "pvector?" pv))
        (define pv* pv)
        (define len (pvector-length/unsafe pv*))
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
               (wrap/len (raw:pvector-copy (pvector-tree/unsafe pv*) start end)
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
           (wrap/len (raw:pvector-copy (pvector-tree/unsafe pv*) start end)
                     (unsafe-fx- end start))])]
       [else
        (define-values (pv* len start* end*)
          (check-subrange/wrapper 'pvector-subvector pv start end))
        (pvector-subvector/finish pv* len start* end*)])]))

(define (pvector-split pv index)
  (cond
    [(and (fixnum? index) (unsafe-fx>= index 0))
     (unless (pvector? pv)
       (raise-argument-error 'pvector-split "pvector?" pv))
     (define len (pvector-length/unsafe pv))
     (when (unsafe-fx>= index len)
       (raise-range-error 'pvector-split "pvector" "" index pv 0 (unsafe-fx- len 1)))
     (define tree (pvector-tree/unsafe pv))
     (if (unsafe-fx= len 1)
         (values empty-pvector (raw:pvector-view-left/fast tree) empty-pvector)
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
     (define tree (pvector-tree/unsafe pv*))
     (if (unsafe-fx= len 1)
         (values empty-pvector (raw:pvector-view-left/fast tree) empty-pvector)
         (let-values ([(left value right) (raw:pvector-split tree index)])
           (values (wrap/len left index)
                   value
                   (wrap/len right (unsafe-fx- (unsafe-fx- len index) 1)))))]))

(define (pvector-split-at pv pos)
  (cond
    [(eqv? pos 0)
     (if (pvector? pv)
         (values empty-pvector pv)
         (values empty-pvector (check-pvector 'pvector-split-at pv)))]
    [(and (fixnum? pos) (unsafe-fx> pos 0))
     (unless (pvector? pv)
       (raise-argument-error 'pvector-split-at "pvector?" pv))
     (define len (pvector-length/unsafe pv))
     (cond
       [(unsafe-fx> pos len)
        (raise-range-error 'pvector-split-at "pvector" "" pos pv 0 len)]
       [(unsafe-fx= pos len) (values pv empty-pvector)]
       [else
        (define-values (left right)
          (raw:pvector-split-at (pvector-tree/unsafe pv) pos))
        (values (wrap/len left pos)
                (wrap/len right (unsafe-fx- len pos)))])]
    [else
     (define-values (pv* len) (check-end-index/wrapper 'pvector-split-at pv pos))
     (cond
       [(zero? pos) (values empty-pvector pv*)]
       [(= pos len) (values pv* empty-pvector)]
       [else
        (define-values (left right)
          (raw:pvector-split-at (pvector-tree/unsafe pv*) pos))
        (values (wrap/len left pos)
                (wrap/len right (unsafe-fx- len pos)))])]))

(define (raw-tree-in-pvector/proc tree len)
  (cond
    [direct-raw-cursor?
     (make-do-sequence
      (lambda ()
        (values raw:pvector-cursor-value/fast
                raw:pvector-cursor-next/fast
                (raw:pvector-cursor-start/fast tree #f)
                (lambda (cursor) cursor)
                (lambda (elem) #t)
                (lambda (pos elem) #t))))]
    [direct-raw-sequence?
      (make-do-sequence
       (lambda ()
         (values (lambda (index) (raw:pvector-ref/fast tree index))
                 (lambda (index) (unsafe-fx+ index 1))
                 0
                 (lambda (index) (unsafe-fx< index len))
                 (lambda (elem) #t)
                 (lambda (pos elem) #t))))]
    [else
      (let ([vec (raw:pvector->vector tree)])
        (make-do-sequence
         (lambda ()
           (values (lambda (index) (unsafe-vector-ref vec index))
                   (lambda (index) (unsafe-fx+ index 1))
                   0
                   (lambda (index) (unsafe-fx< index len))
                   (lambda (elem) #t)
                   (lambda (pos elem) #t)))))]))

(define (raw-tree-in-pvector-reverse/proc tree len)
  (cond
    [direct-raw-cursor?
     (make-do-sequence
      (lambda ()
        (values raw:pvector-cursor-value/fast
                raw:pvector-cursor-next/fast
                (raw:pvector-cursor-start/fast tree #t)
                (lambda (cursor) cursor)
                (lambda (elem) #t)
                (lambda (pos elem) #t))))]
    [direct-raw-sequence?
      (make-do-sequence
       (lambda ()
         (values (lambda (index) (raw:pvector-ref/fast tree index))
                 (lambda (index) (unsafe-fx- index 1))
                 (unsafe-fx- len 1)
                 (lambda (index) (unsafe-fx>= index 0))
                 (lambda (elem) #t)
                 (lambda (pos elem) #t))))]
    [else
      (let ([vec (raw:pvector->vector tree)])
        (make-do-sequence
         (lambda ()
           (values (lambda (index) (unsafe-vector-ref vec index))
                   (lambda (index) (unsafe-fx- index 1))
                   (unsafe-fx- len 1)
                   (lambda (index) (unsafe-fx>= index 0))
                   (lambda (elem) #t)
                   (lambda (pos elem) #t)))))]))

(define (in-pvector/proc pv)
  (if (pvector? pv)
      (raw-tree-in-pvector/proc
       (pvector-tree/unsafe pv)
       (pvector-length/unsafe pv))
      (let ([pv* (check-pvector 'in-pvector pv)])
        (raw-tree-in-pvector/proc
         (pvector-tree/unsafe pv*)
         (pvector-length/unsafe pv*)))))

(define (in-pvector-reverse/proc pv)
  (if (pvector? pv)
      (raw-tree-in-pvector-reverse/proc
       (pvector-tree/unsafe pv)
       (pvector-length/unsafe pv))
      (let ([pv* (check-pvector 'in-pvector-reverse pv)])
        (raw-tree-in-pvector-reverse/proc
         (pvector-tree/unsafe pv*)
         (pvector-length/unsafe pv*)))))

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
                    (check-pvector 'in-pvector pv)))
              (define tree (pvector-tree/unsafe pv*))
              (define use-cursor? direct-raw-cursor?)
              (define len (and (not use-cursor?) (pvector-length/unsafe pv*))))
            ([elem-pos (if use-cursor?
                           (raw:pvector-cursor-start/fast tree #f)
                           0)])
            (if use-cursor?
                elem-pos
                (unsafe-fx< elem-pos len))
            ([(elem next-elem-pos)
              (if use-cursor?
                  (raw:pvector-cursor-value+next/fast elem-pos)
                  (values (raw:pvector-ref/fast tree elem-pos)
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
                   (check-pvector 'in-pvector-reverse pv)))
             (define tree (pvector-tree/unsafe pv*))
             (define use-cursor? direct-raw-cursor?)
             (define len (and (not use-cursor?) (pvector-length/unsafe pv*))))
           ([elem-pos (if use-cursor?
                          (raw:pvector-cursor-start/fast tree #t)
                          (unsafe-fx- len 1))])
           (if use-cursor?
               elem-pos
               (unsafe-fx>= elem-pos 0))
           ([(elem next-elem-pos)
             (if use-cursor?
                 (raw:pvector-cursor-value+next/fast elem-pos)
                 (values (raw:pvector-ref/fast tree elem-pos)
                         (unsafe-fx- elem-pos 1)))])
           #t
           #t
           (next-elem-pos))]]
      [_ #f])))

(define exported-pvector?
  (if bc-native-public? raw:pvector? pvector?))

(define exported-pvector-empty
  (if bc-native-public? raw:pvector-empty pvector-empty))

(define exported-pvector-empty?
  (if bc-native-public? raw:pvector-empty? pvector-empty?))

(define exported-pvector->list
  (if bc-native-public? raw:pvector->list pvector->list))

(define exported-pvector->vector
  (if bc-native-public? raw:pvector->vector pvector->vector))

(define exported-pvector-length
  (if bc-native-public? raw:pvector-length pvector-length))

(define exported-pvector-ref
  (if bc-native-public? raw:pvector-ref pvector-ref))

(define exported-pvector-set
  (if bc-native-public? raw:pvector-set pvector-set))

(define exported-pvector-first
  (if bc-native-public? raw:pvector-view-left pvector-first))

(define exported-pvector-last
  (if bc-native-public? raw:pvector-view-right pvector-last))

(define exported-pvector-cons-left
  (if bc-native-public? raw:pvector-cons-left pvector-cons-left))

(define exported-pvector-cons-right
  (if bc-native-public? raw:pvector-cons-right pvector-cons-right))

(define exported-pvector-pop-left
  (if bc-native-public? raw:pvector-pop-left pvector-pop-left))

(define exported-pvector-pop-right
  (if bc-native-public? raw:pvector-pop-right pvector-pop-right))

(define exported-pvector-append
  (if bc-native-public? raw:pvector-append pvector-append))

(define exported-pvector-map
  (if bc-native-public? raw:pvector-map pvector-map))

(define exported-pvector-for-each
  (if bc-native-public? raw:pvector-for-each pvector-for-each))

(define exported-pvector-insert
  (if bc-native-public? raw:pvector-insert pvector-insert))

(define exported-pvector-delete
  (if bc-native-public? raw:pvector-delete pvector-delete))

(define exported-pvector-take
  (if bc-native-public? raw:pvector-take pvector-take))

(define exported-pvector-drop
  (if bc-native-public? raw:pvector-drop pvector-drop))

(define exported-pvector-take-right
  (if bc-native-public? raw:pvector-take-right pvector-take-right))

(define exported-pvector-drop-right
  (if bc-native-public? raw:pvector-drop-right pvector-drop-right))

(define exported-pvector-split
  (if bc-native-public? raw:pvector-split pvector-split))

(define exported-pvector-split-at
  (if bc-native-public? raw:pvector-split-at pvector-split-at))

(module+ unsafe
  (provide unsafe-pvector-length
           unsafe-pvector->list
           unsafe-pvector->vector
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
    (pvector-tree/unsafe pv))

  (define-syntax-rule (define-native-unsafe id native-expr fallback-def)
    (define id
      (if bc-native-public?
          native-expr
          (let ()
            fallback-def
            id))))

  (define-native-unsafe unsafe-pvector-length
    raw:pvector-length/fast
    (define (unsafe-pvector-length pv)
      (pvector-length/unsafe pv)))

  (define-native-unsafe unsafe-pvector->list
    raw:pvector->list
    (define (unsafe-pvector->list pv)
      (if (eq? pv empty-pvector)
          null
          (let ([tree (unsafe-tree pv)]
                [len (pvector-length/unsafe pv)])
            (case len
              [(1) (list (raw:pvector-view-left/fast tree))]
              [(2) (list (raw:pvector-view-left/fast tree)
                         (raw:pvector-view-right/fast tree))]
              [(3) (list (raw:pvector-view-left/fast tree)
                         (raw:pvector-ref/fast tree 1)
                         (raw:pvector-view-right/fast tree))]
              [(4) (list (raw:pvector-view-left/fast tree)
                         (raw:pvector-ref/fast tree 1)
                         (raw:pvector-ref/fast tree 2)
                         (raw:pvector-view-right/fast tree))]
              [else (raw:pvector->list tree)])))))

  (define-native-unsafe unsafe-pvector->vector
    raw:pvector->vector
    (define (unsafe-pvector->vector pv)
      (if (eq? pv empty-pvector)
          (make-vector 0)
          (let ([tree (unsafe-tree pv)]
                [len (pvector-length/unsafe pv)])
            (case len
              [(1) (vector (raw:pvector-view-left/fast tree))]
              [(2) (vector (raw:pvector-view-left/fast tree)
                           (raw:pvector-view-right/fast tree))]
              [(3) (vector (raw:pvector-view-left/fast tree)
                           (raw:pvector-ref/fast tree 1)
                           (raw:pvector-view-right/fast tree))]
              [(4) (vector (raw:pvector-view-left/fast tree)
                           (raw:pvector-ref/fast tree 1)
                           (raw:pvector-ref/fast tree 2)
                           (raw:pvector-view-right/fast tree))]
              [else (raw:pvector->vector tree)])))))

  (define-native-unsafe unsafe-pvector-ref
    raw:pvector-ref/fast
    (define (unsafe-pvector-ref pv index)
      (raw:pvector-ref/fast (unsafe-tree pv) index)))

  (define-native-unsafe unsafe-pvector-set
    raw:pvector-set
    (define (unsafe-pvector-set pv index value)
      (define tree (unsafe-tree pv))
      (define tree^ (raw:pvector-set tree index value))
      (if (eq? tree^ tree)
          pv
          (wrap/len tree^ (pvector-length/unsafe pv)))))

  (define-native-unsafe unsafe-pvector-first
    raw:pvector-view-left/fast
    (define (unsafe-pvector-first pv)
      (raw:pvector-view-left/fast (unsafe-tree pv))))

  (define-native-unsafe unsafe-pvector-last
    raw:pvector-view-right/fast
    (define (unsafe-pvector-last pv)
      (raw:pvector-view-right/fast (unsafe-tree pv))))

  (define-native-unsafe unsafe-pvector-cons-left
    raw:pvector-cons-left
    (define (unsafe-pvector-cons-left pv value)
      (wrap/len (raw:pvector-cons-left (unsafe-tree pv) value)
                (unsafe-fx+ (pvector-length/unsafe pv) 1))))

  (define-native-unsafe unsafe-pvector-cons-right
    raw:pvector-cons-right
    (define (unsafe-pvector-cons-right pv value)
      (wrap/len (raw:pvector-cons-right (unsafe-tree pv) value)
                (unsafe-fx+ (pvector-length/unsafe pv) 1))))

  (define-native-unsafe unsafe-pvector-pop-left
    raw:pvector-pop-left
    (define (unsafe-pvector-pop-left pv)
      (define len (pvector-length/unsafe pv))
      (define tree (unsafe-tree pv))
      (if (unsafe-fx= len 1)
          (values (raw:pvector-view-left/fast tree) empty-pvector)
          (let-values ([(value rest) (raw:pvector-pop-left tree)])
            (values value (wrap/len rest (unsafe-fx- len 1)))))))

  (define-native-unsafe unsafe-pvector-pop-right
    raw:pvector-pop-right
    (define (unsafe-pvector-pop-right pv)
      (define len (pvector-length/unsafe pv))
      (define tree (unsafe-tree pv))
      (if (unsafe-fx= len 1)
          (values (raw:pvector-view-right/fast tree) empty-pvector)
          (let-values ([(value rest) (raw:pvector-pop-right tree)])
            (values value (wrap/len rest (unsafe-fx- len 1)))))))

  (define-native-unsafe unsafe-pvector-append
    raw:pvector-append
    (define (unsafe-pvector-append pv0 pv1)
      (define left-len (pvector-length/unsafe pv0))
      (define right-len (pvector-length/unsafe pv1))
      (cond
        [(zero? left-len) pv1]
        [(zero? right-len) pv0]
        [else
         (wrap/len (raw:pvector-append (unsafe-tree pv0)
                                       (unsafe-tree pv1))
                   (unsafe-fx+ left-len right-len))])))

  (define-native-unsafe unsafe-pvector-insert
    raw:pvector-insert
    (define (unsafe-pvector-insert pv index value)
      (wrap/len (raw:pvector-insert (unsafe-tree pv) index value)
                (unsafe-fx+ (pvector-length/unsafe pv) 1))))

  (define-native-unsafe unsafe-pvector-delete
    raw:pvector-delete
    (define (unsafe-pvector-delete pv index)
      (define len (pvector-length/unsafe pv))
      (define tree (unsafe-tree pv))
      (if (unsafe-fx= len 1)
          (values empty-pvector (raw:pvector-view-left/fast tree))
          (cond
            [(zero? index)
             (let-values ([(value rest) (raw:pvector-pop-left tree)])
               (values (wrap/len rest (unsafe-fx- len 1)) value))]
            [(= index (unsafe-fx- len 1))
             (let-values ([(value rest) (raw:pvector-pop-right tree)])
               (values (wrap/len rest (unsafe-fx- len 1)) value))]
            [else
             (let-values ([(rest value) (raw:pvector-delete tree index)])
               (values (wrap/len rest (unsafe-fx- len 1)) value))]))))

  (define-native-unsafe unsafe-pvector-take
    raw:pvector-take
    (define (unsafe-pvector-take pv pos)
      (cond
        [(zero? pos) empty-pvector]
        [(= pos (pvector-length/unsafe pv)) pv]
        [else (wrap/len (raw:pvector-take (unsafe-tree pv) pos) pos)])))

  (define-native-unsafe unsafe-pvector-drop
    raw:pvector-drop
    (define (unsafe-pvector-drop pv pos)
      (define len (pvector-length/unsafe pv))
      (cond
        [(zero? pos) pv]
        [(= pos len) empty-pvector]
        [else (wrap/len (raw:pvector-drop (unsafe-tree pv) pos)
                        (unsafe-fx- len pos))])))

  (define-native-unsafe unsafe-pvector-take-right
    raw:pvector-take-right
    (define (unsafe-pvector-take-right pv pos)
      (cond
        [(zero? pos) empty-pvector]
        [(= pos (pvector-length/unsafe pv)) pv]
        [else (wrap/len (raw:pvector-take-right (unsafe-tree pv) pos) pos)])))

  (define-native-unsafe unsafe-pvector-drop-right
    raw:pvector-drop-right
    (define (unsafe-pvector-drop-right pv pos)
      (define len (pvector-length/unsafe pv))
      (cond
        [(zero? pos) pv]
        [(= pos len) empty-pvector]
        [else (wrap/len (raw:pvector-drop-right (unsafe-tree pv) pos)
                        (unsafe-fx- len pos))])))

  (define-native-unsafe unsafe-pvector-subvector
    raw:pvector-copy
    (define (unsafe-pvector-subvector pv start end)
      (define len (pvector-length/unsafe pv))
      (define new-len (unsafe-fx- end start))
      (cond
        [(unsafe-fx= new-len 0) empty-pvector]
        [(and (unsafe-fx= start 0) (unsafe-fx= end len)) pv]
        [(unsafe-fx= start 0)
         (wrap/len (raw:pvector-copy (unsafe-tree pv) start end) new-len)]
        [(unsafe-fx= end len)
         (wrap/len (raw:pvector-copy (unsafe-tree pv) start end) new-len)]
        [else (wrap/len (raw:pvector-copy (unsafe-tree pv) start end)
                        new-len)])))

  (define-native-unsafe unsafe-pvector-split
    raw:pvector-split
    (define (unsafe-pvector-split pv index)
      (define len (pvector-length/unsafe pv))
      (define tree (unsafe-tree pv))
      (cond
        [(and (unsafe-fx= len 1) (unsafe-fx= index 0))
         (values empty-pvector (raw:pvector-view-left/fast tree) empty-pvector)]
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
                   (wrap/len right (unsafe-fx- (unsafe-fx- len index) 1))))])))

  (define-native-unsafe unsafe-pvector-split-at
    raw:pvector-split-at
    (define (unsafe-pvector-split-at pv pos)
      (define len (pvector-length/unsafe pv))
      (cond
        [(zero? pos) (values empty-pvector pv)]
        [(= pos len) (values pv empty-pvector)]
        [else
         (define-values (left right)
           (raw:pvector-split-at (unsafe-tree pv) pos))
         (values (wrap/len left pos)
                 (wrap/len right (unsafe-fx- len pos)))])))

  (define (unsafe-in-pvector/proc pv)
    (raw-tree-in-pvector/proc
     (unsafe-tree pv)
     (pvector-length/unsafe pv)))

  (define (unsafe-in-pvector-reverse/proc pv)
    (raw-tree-in-pvector-reverse/proc
     (unsafe-tree pv)
     (pvector-length/unsafe pv)))

  (define-sequence-syntax unsafe-in-pvector
    (lambda () #'unsafe-in-pvector/proc)
    (lambda (stx)
      (syntax-case stx ()
        [[(elem) (_ pv-expr)]
         #'[(elem)
             (:do-in
              ([(pv) pv-expr])
              (begin
               (define tree (unsafe-tree pv))
               (define use-cursor? direct-raw-cursor?)
               (define len (and (not use-cursor?) (pvector-length/unsafe pv))))
             ([elem-pos (if use-cursor?
                            (raw:pvector-cursor-start/fast tree #f)
                            0)])
             (if use-cursor?
                 elem-pos
                 (unsafe-fx< elem-pos len))
             ([(elem next-elem-pos)
               (if use-cursor?
                   (raw:pvector-cursor-value+next/fast elem-pos)
                   (values (raw:pvector-ref/fast tree elem-pos)
                           (unsafe-fx+ elem-pos 1)))])
             #t
             #t
             (next-elem-pos))]]
        [_ #f])))

  (define-sequence-syntax unsafe-in-pvector-reverse
    (lambda () #'unsafe-in-pvector-reverse/proc)
    (lambda (stx)
      (syntax-case stx ()
        [[(elem) (_ pv-expr)]
         #'[(elem)
             (:do-in
              ([(pv) pv-expr])
              (begin
               (define tree (unsafe-tree pv))
               (define use-cursor? direct-raw-cursor?)
               (define len (and (not use-cursor?) (pvector-length/unsafe pv))))
             ([elem-pos (if use-cursor?
                            (raw:pvector-cursor-start/fast tree #t)
                            (unsafe-fx- len 1))])
             (if use-cursor?
                 elem-pos
                 (unsafe-fx>= elem-pos 0))
             ([(elem next-elem-pos)
               (if use-cursor?
                   (raw:pvector-cursor-value+next/fast elem-pos)
                   (values (raw:pvector-ref/fast tree elem-pos)
                           (unsafe-fx- elem-pos 1)))])
             #t
             #t
             (next-elem-pos))]]
        [_ #f]))))

(define (pvector-match-tail->list tree start end)
  (let loop ([i (sub1 end)] [acc null])
    (if (< i start)
        acc
        (loop (sub1 i) (cons (raw:pvector-ref/fast tree i) acc)))))

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
               (if (and (pvector? pv)
                        (= len (pvector-length/unsafe pv)))
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
                 [(and (pvector? seq)
                       (= len (pvector-length/unsafe seq)))
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
         (if (pvector? pv)
             pv
             (wrap (raw:for/pvector ([elem (in-pvector pv)]) elem))))]
    [(_ ([elem (in-pvector-reverse pv-expr)]) body)
     (same-identifier? #'elem #'body)
     #'(let ([pv pv-expr])
         (if (pvector? pv)
             (for/pvector #:length (pvector-length/unsafe pv)
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
         (if (pvector? seq)
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
    [(_ ([elem (in-range end)]) body)
     (same-identifier? #'elem #'body)
     #'(in-range-end->pvector end)]
    [(_ ([elem (in-range range-arg ...)]) body)
     (same-identifier? #'elem #'body)
     #'(sequence->pvector (in-range range-arg ...))]
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
               (if (and (pvector? pv)
                        (= len (pvector-length/unsafe pv)))
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
                 [(and (pvector? seq)
                       (= len (pvector-length/unsafe seq)))
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
         (if (pvector? pv)
             pv
             (wrap (raw:for*/pvector ([elem (in-pvector pv)]) elem))))]
    [(_ ([elem (in-pvector-reverse pv-expr)]) body)
     (same-identifier? #'elem #'body)
     #'(let ([pv pv-expr])
         (if (pvector? pv)
             (for*/pvector #:length (pvector-length/unsafe pv)
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
         (if (pvector? seq)
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
    [(_ ([elem (in-range end)]) body)
     (same-identifier? #'elem #'body)
     #'(in-range-end->pvector end)]
    [(_ ([elem (in-range range-arg ...)]) body)
     (same-identifier? #'elem #'body)
     #'(sequence->pvector (in-range range-arg ...))]
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
                      #'(? pvector?
                           (? (lambda (pv)
                                (>= (pvector-length/unsafe pv)
                                    (+ prefix-len min-repeat)))
                              (and
                               (app (lambda (pv)
                                      (raw:pvector-ref/fast
                                       (pvector-tree/unsafe pv)
                                       idx))
                                    prefix-pat)
                               ...
                               (app (lambda (pv)
                                      (pvector-match-tail->list
                                       (pvector-tree/unsafe pv)
                                       prefix-len
                                       (pvector-length/unsafe pv)))
                                    repeat-pat))))))
                  #'(? pvector?
                       (app pvector->list (list pat ...)))))]
           [else
            (with-syntax ([(idx ...)
                           (for/list ([idx (in-range (length elems))])
                             idx)]
                          [len (length elems)])
              #'(? pvector?
                   (? (lambda (pv) (= (pvector-length/unsafe pv) len))
                      (app pvector-tree/unsafe
                           (and
                            (app (lambda (tree) (raw:pvector-ref/fast tree idx)) pat)
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
           [(<= len pvector-inline-vector-arity-limit)
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
                            #`(raw:pvector-ref/fast tree #,start)
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
       #`(? pvector?
            (app (lambda (pv)
                   (define tree (pvector-tree/unsafe pv))
                   (define total-len (pvector-length/unsafe pv))
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
  (for ([elem (raw:in-pvector (pvector-tree/unsafe pv))])
    (display " " port)
    (case mode
      [(#t) (write elem port)]
      [(#f) (display elem port)]
      [else (print elem port)]))
  (display ")" port))

(define (pvector-equal? pv other recur)
  (or (eq? pv other)
      (and (pvector? other)
           (let ([len (pvector-length/unsafe pv)]
                 [other-len (pvector-length/unsafe other)])
            (and (unsafe-fx= len other-len)
                 (let ([tree (pvector-tree/unsafe pv)]
                       [other-tree (pvector-tree/unsafe other)])
                   (let/ec return
                     (let ([index 0])
                       (raw:pvector-for-each
                        tree
                        (lambda (elem)
                          (define other-elem
                            (raw:pvector-ref/fast other-tree index))
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
              (recur (raw:pvector-ref/fast tree pos))))])))

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
                (recur (raw:pvector-ref/fast tree pos))))])))
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

(define (pvector-hash/tree pv recur seed)
  (define len (pvector-length/unsafe pv))
  (define tree (pvector-tree/unsafe pv))
  (if (>= len sampled-hash-total-count)
      (pvector-hash-sampled tree len recur seed)
      (pvector-hash-full tree len recur seed)))

(define (pvector-hash-code pv recur)
  (pvector-hash/tree pv recur 16381))

(define (pvector-secondary-hash-code pv recur)
  (pvector-hash/tree pv recur 32749))

(define (install-native-public-properties!)
  (when (and bc-native-public?
             (raw:pvector-runtime-adapter-public-properties-available?))
    (raw:pvector-install-struct-property!
     prop:custom-print-quotable
     'never)
    (raw:pvector-install-struct-property!
     prop:custom-write
     (lambda (pv port mode) (pvector-print pv port mode)))
    (raw:pvector-install-struct-property!
     prop:gen-sequence
     (lambda (pv) (pvector-gen-sequence pv)))
    (raw:pvector-install-struct-property!
     prop:sequence
     (lambda (pv) (in-pvector pv)))
    (raw:pvector-install-struct-property!
     prop:stream
     (vector
      (lambda (pv) (unsafe-fx= 0 (pvector-length/unsafe pv)))
      (lambda (pv) (raw:pvector-view-left/fast (pvector-tree/unsafe pv)))
      (lambda (pv)
        (define len (pvector-length/unsafe pv))
        (if (unsafe-fx= len 1)
            empty-pvector
            (let-values ([(_ rest)
                          (raw:pvector-pop-left (pvector-tree/unsafe pv))])
              (wrap/len rest (unsafe-fx- len 1)))))))
    (raw:pvector-install-struct-property!
     prop:serializable
     (make-serialize-info
      (lambda (pv) (vector (pvector->vector pv)))
      (cons 'deserialize-pvector
            (module-path-index-join '(submod "." deserialize)
                                    (variable-reference->module-path-index
                                     (#%variable-reference))))
      #f
      (or (current-load-relative-directory)
          (current-directory))))))

(install-native-public-properties!)
