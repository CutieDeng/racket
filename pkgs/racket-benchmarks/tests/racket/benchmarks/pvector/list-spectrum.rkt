#lang racket/base

(require racket/cmdline
         racket/list
         racket/pvector
         (prefix-in adapter: racket/private/pvector-runtime-adapter)
         racket/string
         racket/treelist
         racket/vector)

(define M 200)
(define max-size 1024)
(define explicit-sizes #f)
(define impl-names '(list vector treelist pvector adapter-pvector))
(define ops #f)

(define (parse-count who s)
  (define n (string->number s))
  (unless (exact-positive-integer? n)
    (raise-user-error who "expected a positive exact integer, got ~e" s))
  n)

(define (parse-size who s)
  (define n (string->number s))
  (unless (exact-nonnegative-integer? n)
    (raise-user-error who "expected a nonnegative exact integer, got ~e" s))
  n)

(define (parse-size-list who s)
  (for/list ([part (in-list (string-split s ","))]
             #:unless (string=? part ""))
    (parse-size who part)))

(define (parse-symbol-list s)
  (for/list ([part (in-list (string-split s ","))]
             #:unless (string=? part ""))
    (string->symbol part)))

(define (power-sizes limit)
  (define powers
    (let loop ([n 1] [acc null])
      (if (> n limit)
          (reverse acc)
          (loop (* n 2) (cons n acc)))))
  (cons 0 powers))

(command-line
 #:program "pvector-list-spectrum"
 #:once-each
 [("--m") n "Repeat count per operation"
          (set! M (parse-count '--m n))]
 [("--max-size") n "Largest generated power-of-two size"
                 (set! max-size (parse-count '--max-size n))]
 [("--sizes") s "Explicit comma-separated sizes; overrides --max-size"
              (set! explicit-sizes (parse-size-list '--sizes s))]
 [("--impls") s "Comma-separated implementations: list,vector,treelist,pvector,adapter-pvector"
              (set! impl-names (parse-symbol-list s))]
 [("--ops") s "Comma-separated operations"
           (set! ops (parse-symbol-list s))])

(define sizes
  (or explicit-sizes (power-sizes max-size)))

(define (enabled-op? op)
  (or (not ops) (memq op ops)))

(define (enabled-impl? name)
  (memq name impl-names))

(define (vector-cons-left vec value)
  (define len (vector-length vec))
  (define out (make-vector (add1 len)))
  (vector-set! out 0 value)
  (vector-copy! out 1 vec 0 len)
  out)

(define (vector-cons-right vec value)
  (define len (vector-length vec))
  (define out (make-vector (add1 len)))
  (vector-copy! out 0 vec 0 len)
  (vector-set! out len value)
  out)

(struct impl
  (name build length ref sum cons-left cons-right append take drop map to-list)
  #:transparent)

(define list-impl
  (impl 'list
        (lambda (len)
          (for/list ([i (in-range len)]) i))
        length
        list-ref
        (lambda (xs)
          (for/fold ([sum 0]) ([x (in-list xs)]) (+ sum x)))
        cons
        (lambda (value xs) (append xs (list value)))
        append
        take
        drop
        (lambda (xs proc) (map proc xs))
        values))

(define vector-impl
  (impl 'vector
        (lambda (len)
          (for/vector #:length len ([i (in-range len)]) i))
        vector-length
        vector-ref
        (lambda (vec)
          (for/fold ([sum 0]) ([x (in-vector vec)]) (+ sum x)))
        (lambda (value vec) (vector-cons-left vec value))
        (lambda (value vec) (vector-cons-right vec value))
        vector-append
        (lambda (vec pos) (vector-copy vec 0 pos))
        (lambda (vec pos) (vector-copy vec pos))
        (lambda (vec proc) (vector-map proc vec))
        vector->list))

(define treelist-impl
  (impl 'treelist
        (lambda (len)
          (for/treelist ([i (in-range len)]) i))
        treelist-length
        treelist-ref
        (lambda (tl)
          (for/fold ([sum 0]) ([x (in-treelist tl)]) (+ sum x)))
        (lambda (value tl) (treelist-cons tl value))
        (lambda (value tl) (treelist-add tl value))
        treelist-append
        treelist-take
        treelist-drop
        treelist-map
        treelist->list))

(define pvector-impl
  (impl 'pvector
        (lambda (len)
          (for/pvector ([i (in-range len)]) i))
        pvector-length
        pvector-ref
        (lambda (pv)
          (for/fold ([sum 0]) ([x (in-pvector pv)]) (+ sum x)))
        (lambda (value pv) (pvector-cons-left pv value))
        (lambda (value pv) (pvector-cons-right pv value))
        pvector-append
        pvector-take
        pvector-drop
        pvector-map
        pvector->list))

(define adapter-pvector-impl
  (impl 'adapter-pvector
        (lambda (len)
          (adapter:for/pvector ([i (in-range len)]) i))
        adapter:pvector-length
        adapter:pvector-ref
        (lambda (pv)
          (for/fold ([sum 0]) ([x (adapter:in-pvector pv)]) (+ sum x)))
        (lambda (value pv) (adapter:pvector-cons-left pv value))
        (lambda (value pv) (adapter:pvector-cons-right pv value))
        adapter:pvector-append
        adapter:pvector-take
        adapter:pvector-drop
        adapter:pvector-map
        adapter:pvector->list))

(define all-impls
  (list list-impl
        vector-impl
        treelist-impl
        pvector-impl
        adapter-pvector-impl))

(define selected-impls
  (for/list ([candidate (in-list all-impls)]
             #:when (enabled-impl? (impl-name candidate)))
    candidate))

(define (repeat-result m proc)
  (for/fold ([result #f]) ([i (in-range m)])
    (proc i)))

(define (summarize-result result)
  (cond
    [(list? result) (format "list:~a" (length result))]
    [(vector? result) (format "vector:~a" (vector-length result))]
    [(treelist? result) (format "treelist:~a" (treelist-length result))]
    [(pvector? result) (format "pvector:~a" (pvector-length result))]
    [(adapter:pvector? result)
     (format "adapter-pvector:~a" (adapter:pvector-length result))]
    [else (format "~s" result)]))

(define (bench size op imp thunk #:when [ok? #t])
  (when (and ok? (enabled-op? op))
    (collect-garbage)
    (collect-garbage)
    (define before-bytes (current-memory-use))
    (define-values (vals cpu real gc) (time-apply thunk null))
    (define result (if (pair? vals) (car vals) (void)))
    (collect-garbage)
    (define after-bytes (current-memory-use))
    (printf "~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\n"
            size
            op
            (impl-name imp)
            cpu
            real
            gc
            (- after-bytes before-bytes)
            (summarize-result result))
    (flush-output)))

(printf "size\top\timpl\tcpu-ms\treal-ms\tgc-ms\tlive-bytes\tresult\n")

(for ([size (in-list sizes)])
  (for ([imp (in-list selected-impls)])
    (define base ((impl-build imp) size))
    (define half (quotient size 2))
    (define last-index (sub1 size))
    (bench size
           'build
           imp
           (lambda ()
             (repeat-result M
                            (lambda (_)
                              ((impl-build imp) size)))))
    (bench size
           'length
           imp
           (lambda ()
             (repeat-result M
                            (lambda (_)
                              ((impl-length imp) base)))))
    (bench size
           'sum
           imp
           (lambda ()
             (repeat-result M
                            (lambda (_)
                              ((impl-sum imp) base)))))
    (bench size
           'ref-first
           imp
           (lambda ()
             (repeat-result M
                            (lambda (_)
                              ((impl-ref imp) base 0))))
           #:when (> size 0))
    (bench size
           'ref-middle
           imp
           (lambda ()
             (repeat-result M
                            (lambda (_)
                              ((impl-ref imp) base half))))
           #:when (> size 0))
    (bench size
           'ref-last
           imp
           (lambda ()
             (repeat-result M
                            (lambda (_)
                              ((impl-ref imp) base last-index))))
           #:when (> size 0))
    (bench size
           'cons-left
           imp
           (lambda ()
             (repeat-result M
                            (lambda (i)
                              ((impl-cons-left imp) (- i) base)))))
    (bench size
           'cons-right
           imp
           (lambda ()
             (repeat-result M
                            (lambda (i)
                              ((impl-cons-right imp) (- i) base)))))
    (bench size
           'append-self
           imp
           (lambda ()
             (repeat-result M
                            (lambda (_)
                              ((impl-append imp) base base)))))
    (bench size
           'take-half
           imp
           (lambda ()
             (repeat-result M
                            (lambda (_)
                              ((impl-take imp) base half)))))
    (bench size
           'drop-half
           imp
           (lambda ()
             (repeat-result M
                            (lambda (_)
                              ((impl-drop imp) base half)))))
    (bench size
           'map-add1
           imp
           (lambda ()
             (repeat-result M
                            (lambda (_)
                              ((impl-map imp) base add1)))))
    (bench size
           'to-list
           imp
           (lambda ()
             (repeat-result M
                            (lambda (_)
                              ((impl-to-list imp) base)))))))
