#lang racket/base

(require racket/cmdline
         racket/list
         racket/pvector
         (prefix-in adapter: racket/private/pvector-runtime-adapter)
         racket/string
         racket/treelist
         racket/vector)

(define COUNT 50000)
(define sizes '(0 1 2 3 4 8 16 32 64))
(define impl-names '(list vector treelist pvector adapter-pvector))
(define ops #f)

(define (parse-count who s)
  (define n (string->number s))
  (unless (exact-positive-integer? n)
    (raise-user-error who "expected a positive exact integer, got ~e" s))
  n)

(define (parse-size-list who s)
  (for/list ([part (in-list (string-split s ","))]
             #:unless (string=? part ""))
    (define n (string->number part))
    (unless (exact-nonnegative-integer? n)
      (raise-user-error who "expected a nonnegative exact integer, got ~e" part))
    n))

(define (parse-symbol-list s)
  (for/list ([part (in-list (string-split s ","))]
             #:unless (string=? part ""))
    (string->symbol part)))

(command-line
 #:program "pvector-list-workload"
 #:once-each
 [("--count") n "Number of live small containers"
              (set! COUNT (parse-count '--count n))]
 [("--sizes") s "Comma-separated small container sizes"
              (set! sizes (parse-size-list '--sizes s))]
 [("--impls") s "Comma-separated implementations: list,vector,treelist,pvector,adapter-pvector"
              (set! impl-names (parse-symbol-list s))]
 [("--ops") s "Comma-separated operations"
           (set! ops (parse-symbol-list s))])

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
  (name build length ref sum cons-left cons-right drop-left append)
  #:transparent)

(define list-impl
  (impl 'list
        (lambda (len seed)
          (for/list ([i (in-range len)]) (+ seed i)))
        length
        list-ref
        (lambda (xs)
          (for/fold ([sum 0]) ([x (in-list xs)]) (+ sum x)))
        cons
        (lambda (value xs) (append xs (list value)))
        cdr
        append))

(define vector-impl
  (impl 'vector
        (lambda (len seed)
          (for/vector #:length len ([i (in-range len)]) (+ seed i)))
        vector-length
        vector-ref
        (lambda (vec)
          (for/fold ([sum 0]) ([x (in-vector vec)]) (+ sum x)))
        (lambda (value vec) (vector-cons-left vec value))
        (lambda (value vec) (vector-cons-right vec value))
        (lambda (vec) (vector-copy vec 1))
        vector-append))

(define treelist-impl
  (impl 'treelist
        (lambda (len seed)
          (for/treelist ([i (in-range len)]) (+ seed i)))
        treelist-length
        treelist-ref
        (lambda (tl)
          (for/fold ([sum 0]) ([x (in-treelist tl)]) (+ sum x)))
        (lambda (value tl) (treelist-cons tl value))
        (lambda (value tl) (treelist-add tl value))
        (lambda (tl) (treelist-drop tl 1))
        treelist-append))

(define pvector-impl
  (impl 'pvector
        (lambda (len seed)
          (for/pvector ([i (in-range len)]) (+ seed i)))
        pvector-length
        pvector-ref
        (lambda (pv)
          (for/fold ([sum 0]) ([x (in-pvector pv)]) (+ sum x)))
        (lambda (value pv) (pvector-cons-left pv value))
        (lambda (value pv) (pvector-cons-right pv value))
        (lambda (pv) (pvector-drop pv 1))
        pvector-append))

(define adapter-pvector-impl
  (impl 'adapter-pvector
        (lambda (len seed)
          (adapter:for/pvector ([i (in-range len)]) (+ seed i)))
        adapter:pvector-length
        adapter:pvector-ref
        (lambda (pv)
          (for/fold ([sum 0]) ([x (adapter:in-pvector pv)]) (+ sum x)))
        (lambda (value pv) (adapter:pvector-cons-left pv value))
        (lambda (value pv) (adapter:pvector-cons-right pv value))
        (lambda (pv) (adapter:pvector-drop pv 1))
        adapter:pvector-append))

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

(define (build-live imp len count)
  (for/vector #:length count ([i (in-range count)])
    ((impl-build imp) len i)))

(define (ref-live imp live len)
  (define last-index (sub1 len))
  (define mid-index (quotient len 2))
  (for/fold ([sum 0]) ([container (in-vector live)])
    (+ sum
       ((impl-ref imp) container 0)
       (if (= mid-index 0) 0 ((impl-ref imp) container mid-index))
       (if (= last-index mid-index) 0 ((impl-ref imp) container last-index)))))

(define (sum-live imp live)
  (for/fold ([sum 0]) ([container (in-vector live)])
    (+ sum ((impl-sum imp) container))))

(define (map-live live proc)
  (for/vector #:length (vector-length live)
              ([container (in-vector live)]
               [i (in-naturals)])
    (proc container i)))

(define (container-length-or-false imp v)
  (with-handlers ([exn:fail? (lambda (_) #f)])
    ((impl-length imp) v)))

(define (summarize-result imp result)
  (cond
    [(vector? result)
     (define len (vector-length result))
     (cond
       [(zero? len) "vector:0"]
       [else
        (define first-len
          (container-length-or-false imp (vector-ref result 0)))
        (if first-len
            (format "live-vector:~a first-len:~a" len first-len)
            (format "vector:~a" len))])]
    [(list? result) (format "list:~a" (length result))]
    [(treelist? result) (format "treelist:~a" (treelist-length result))]
    [(pvector? result) (format "pvector:~a" (pvector-length result))]
    [(adapter:pvector? result)
     (format "adapter-pvector:~a" (adapter:pvector-length result))]
    [else (format "~s" result)]))

(define (bench size count op imp thunk #:when [ok? #t])
  (when (and ok? (enabled-op? op))
    (collect-garbage)
    (collect-garbage)
    (define before-bytes (current-memory-use))
    (define-values (vals cpu real gc) (time-apply thunk null))
    (define result (if (pair? vals) (car vals) (void)))
    (collect-garbage)
    (define after-bytes (current-memory-use))
    (printf "~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\n"
            size
            count
            op
            (impl-name imp)
            cpu
            real
            gc
            (- after-bytes before-bytes)
            (summarize-result imp result))
    (flush-output)))

(printf "size\tcount\top\timpl\tcpu-ms\treal-ms\tgc-ms\tlive-bytes\tresult\n")

(for ([size (in-list sizes)])
  (for ([imp (in-list selected-impls)])
    (bench size
           COUNT
           'build-live
           imp
           (lambda () (build-live imp size COUNT)))
    (define live (build-live imp size COUNT))
    (bench size
           COUNT
           'sum-live
           imp
           (lambda () (sum-live imp live)))
    (bench size
           COUNT
           'ref-live
           imp
           (lambda () (ref-live imp live size))
           #:when (> size 0))
    (bench size
           COUNT
           'cons-left-live
           imp
           (lambda ()
             (map-live live
                       (lambda (container i)
                         ((impl-cons-left imp) (- i) container)))))
    (bench size
           COUNT
           'cons-right-live
           imp
           (lambda ()
             (map-live live
                       (lambda (container i)
                         ((impl-cons-right imp) (- i) container)))))
    (bench size
           COUNT
           'drop-left-live
           imp
           (lambda ()
             (map-live live
                       (lambda (container i)
                         ((impl-drop-left imp) container))))
           #:when (> size 0))
    (bench size
           COUNT
           'append-self-live
           imp
           (lambda ()
             (map-live live
                       (lambda (container i)
                         ((impl-append imp) container container)))))))
