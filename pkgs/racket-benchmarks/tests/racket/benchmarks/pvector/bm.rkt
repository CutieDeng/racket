#lang racket/base

(require racket/cmdline
         racket/list
         (prefix-in cutie: (file "/Users/cutiedeng/Y2026/M03/D28/cutie-ftree.rkt/pvector.rkt"))
         racket/pvector
         (prefix-in chunked: racket/private/pvector-chunked)
         (prefix-in raw: racket/private/pvector)
         (prefix-in unsafe: (submod racket/pvector unsafe))
         racket/string
         racket/stream
         racket/treelist
         racket/vector)

(define M 20)
(define N 1000)
(define list-limit 2000)
(define impls '(list vector treelist cutie-pvector raw-pvector chunked-pvector pvector unsafe-pvector))
(define ops #f)

(define (parse-count who s)
  (define n (string->number s))
  (unless (exact-positive-integer? n)
    (raise-user-error who "expected a positive exact integer, got ~e" s))
  n)

(define (parse-symbol-list s)
  (for/list ([part (in-list (string-split s ","))]
             #:unless (string=? part ""))
    (string->symbol part)))

(command-line
 #:program "pvector-bm"
 #:once-each
 [("--m") m "Outer repeat count"
          (set! M (parse-count '--m m))]
 [("--n") n "Sequence length"
          (set! N (parse-count '--n n))]
 [("--list-limit") n "Maximum N for O(N^2) list baselines"
                   (set! list-limit (parse-count '--list-limit n))]
 [("--impls") s "Comma-separated implementations: list,vector,treelist,cutie-pvector,raw-pvector,chunked-pvector,pvector,unsafe-pvector"
              (set! impls (parse-symbol-list s))]
 [("--ops") s "Comma-separated benchmark names"
           (set! ops (parse-symbol-list s))])

(define (enabled? xs x)
  (or (not xs) (memq x xs)))

(define (build-list-data n)
  (for/list ([i (in-range n)]) i))

(define (build-vector-data n)
  (for/vector #:length n ([i (in-range n)]) i))

(define (vector-set/persistent vec i value)
  (define vec* (vector-copy vec))
  (vector-set! vec* i value)
  vec*)

(define (vector-take vec n)
  (vector-copy vec 0 n))

(define (vector-drop vec n)
  (vector-copy vec n))

(define (summarize-value v)
  (cond
    [(list? v) (format "list:~a" (length v))]
    [(vector? v) (format "vector:~a" (vector-length v))]
    [(treelist? v) (format "treelist:~a" (treelist-length v))]
    [(cutie:pvector? v) (format "cutie-pvector:~a" (cutie:pvector-length v))]
    [(raw:pvector? v) (format "raw-pvector:~a" (raw:pvector-length v))]
    [(chunked:pvector? v) (format "chunked-pvector:~a" (chunked:pvector-length v))]
    [(pvector? v) (format "pvector:~a" (pvector-length v))]
    [else (format "~s" v)]))

(define (bench op impl thunk #:when [ok? #t])
  (when (and ok? (enabled? ops op) (memq impl impls))
    (collect-garbage)
    (collect-garbage)
    (define-values (vals cpu real gc) (time-apply thunk null))
    (define result (if (pair? vals) (car vals) (void)))
    (printf "~a\t~a\t~a\t~a\t~a\t~a\n"
            op impl cpu real gc (summarize-value result))
    (flush-output)))

(define (measure m n)
  (printf "M=~a N=~a\n" m n)
  (printf "op\timpl\tcpu-ms\treal-ms\tgc-ms\tresult\n")

  (define base-list (build-list-data n))
  (define base-vector (list->vector base-list))
  (define base-treelist (list->treelist base-list))
  (define base-cutie-pvector (cutie:list->pvector base-list))
  (define base-raw-pvector (raw:list->pvector base-list))
  (define base-chunked-pvector (chunked:list->pvector base-list))
  (define base-pvector (list->pvector base-list))
  (define base-list-reverse (reverse base-list))
  (define base-vector-reverse (list->vector base-list-reverse))
  (define base-treelist-reverse (treelist-reverse base-treelist))
  (define half (quotient n 2))
  (define quarter (quotient n 4))
  (define three-quarter (- n quarter))
  (define left-list (take base-list half))
  (define right-list (drop base-list half))
  (define left-vector (vector-copy base-vector 0 half))
  (define right-vector (vector-copy base-vector half n))
  (define left-treelist (treelist-take base-treelist half))
  (define right-treelist (treelist-drop base-treelist half))
  (define left-cutie-pvector (cutie:pvector-take base-cutie-pvector half))
  (define right-cutie-pvector (cutie:pvector-drop base-cutie-pvector half))
  (define left-raw-pvector (raw:pvector-take base-raw-pvector half))
  (define right-raw-pvector (raw:pvector-drop base-raw-pvector half))
  (define left-chunked-pvector (chunked:pvector-take base-chunked-pvector half))
  (define right-chunked-pvector (chunked:pvector-drop base-chunked-pvector half))
  (define left-pvector (pvector-take base-pvector half))
  (define right-pvector (pvector-drop base-pvector half))

  (bench 'build-native 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (build-list-data n))))
  (bench 'build-native 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (build-vector-data n))))
  (bench 'build-native 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (for/treelist ([i (in-range n)]) i))))
  (bench 'build-native 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (cutie:for/pvector ([i (in-range n)]) i))))
  (bench 'build-native 'chunked-pvector
         (lambda ()
           (for/fold ([r (chunked:pvector-empty)]) ([j (in-range m)])
             (chunked:for/pvector ([i (in-range n)]) i))))
  (bench 'build-native 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/pvector ([i (in-range n)]) i))))
  (bench 'build-native 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv (pvector-empty)]) ([i (in-range n)])
               (unsafe:unsafe-pvector-cons-right pv i)))))

  (bench 'cons-left-chain 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (for/fold ([xs null]) ([i (in-range n)])
               (cons i xs)))))
  (bench 'cons-left-chain 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (for/fold ([vec #()]) ([i (in-range n)])
               (vector-append (vector i) vec))))
         #:when (n . <= . list-limit))
  (bench 'cons-left-chain 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (for/fold ([tl empty-treelist]) ([i (in-range n)])
               (treelist-cons tl i)))))
  (bench 'cons-left-chain 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv (cutie:pvector-empty)]) ([i (in-range n)])
               (cutie:pvector-cons-left pv i)))))
  (bench 'cons-left-chain 'chunked-pvector
         (lambda ()
           (for/fold ([r (chunked:pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv (chunked:pvector-empty)]) ([i (in-range n)])
               (chunked:pvector-cons-left pv i)))))
  (bench 'cons-left-chain 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv (pvector-empty)]) ([i (in-range n)])
               (pvector-cons-left pv i)))))
  (bench 'cons-left-chain 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv (pvector-empty)]) ([i (in-range n)])
               (unsafe:unsafe-pvector-cons-left pv i)))))

  (bench 'cons-right-chain 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (for/fold ([xs null]) ([i (in-range n)])
               (append xs (list i)))))
         #:when (n . <= . list-limit))
  (bench 'cons-right-chain 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (for/fold ([vec #()]) ([i (in-range n)])
               (vector-append vec (vector i)))))
         #:when (n . <= . list-limit))
  (bench 'cons-right-chain 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (for/fold ([tl empty-treelist]) ([i (in-range n)])
               (treelist-add tl i)))))
  (bench 'cons-right-chain 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv (cutie:pvector-empty)]) ([i (in-range n)])
               (cutie:pvector-cons-right pv i)))))
  (bench 'cons-right-chain 'chunked-pvector
         (lambda ()
           (for/fold ([r (chunked:pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv (chunked:pvector-empty)]) ([i (in-range n)])
               (chunked:pvector-cons-right pv i)))))
  (bench 'cons-right-chain 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv (pvector-empty)]) ([i (in-range n)])
               (pvector-cons-right pv i)))))
  (bench 'cons-right-chain 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv (pvector-empty)]) ([i (in-range n)])
               (unsafe:unsafe-pvector-cons-right pv i)))))

  (bench 'pop-left-chain 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (for/fold ([xs base-list]) ([i (in-range n)])
               (cdr xs)))))
  (bench 'pop-left-chain 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (for/fold ([vec base-vector]) ([i (in-range n)])
               (vector-drop vec 1))))
         #:when (n . <= . list-limit))
  (bench 'pop-left-chain 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (for/fold ([tl base-treelist]) ([i (in-range n)])
               (treelist-rest tl)))))
  (bench 'pop-left-chain 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv base-cutie-pvector]) ([i (in-range n)])
               (define-values (_ rest) (cutie:pvector-pop-left pv))
               rest))))
  (bench 'pop-left-chain 'chunked-pvector
         (lambda ()
           (for/fold ([r (chunked:pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv base-chunked-pvector]) ([i (in-range n)])
               (define-values (_ rest) (chunked:pvector-pop-left pv))
               rest))))
  (bench 'pop-left-chain 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv base-pvector]) ([i (in-range n)])
               (define-values (_ rest) (pvector-pop-left pv))
               rest))))
  (bench 'pop-left-chain 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv base-pvector]) ([i (in-range n)])
               (define-values (_ rest) (unsafe:unsafe-pvector-pop-left pv))
               rest))))

  (bench 'pop-right-chain 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (for/fold ([xs base-list] [len n] #:result xs) ([i (in-range n)])
               (values (take xs (sub1 len)) (sub1 len)))))
         #:when (n . <= . list-limit))
  (bench 'pop-right-chain 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (for/fold ([vec base-vector] [len n] #:result vec) ([i (in-range n)])
               (values (vector-take vec (sub1 len)) (sub1 len)))))
         #:when (n . <= . list-limit))
  (bench 'pop-right-chain 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (for/fold ([tl base-treelist]) ([i (in-range n)])
               (treelist-drop-right tl 1)))))
  (bench 'pop-right-chain 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv base-cutie-pvector]) ([i (in-range n)])
               (define-values (_ rest) (cutie:pvector-pop-right pv))
               rest))))
  (bench 'pop-right-chain 'chunked-pvector
         (lambda ()
           (for/fold ([r (chunked:pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv base-chunked-pvector]) ([i (in-range n)])
               (define-values (_ rest) (chunked:pvector-pop-right pv))
               rest))))
  (bench 'pop-right-chain 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv base-pvector]) ([i (in-range n)])
               (define-values (_ rest) (pvector-pop-right pv))
               rest))))
  (bench 'pop-right-chain 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv base-pvector]) ([i (in-range n)])
               (define-values (_ rest) (unsafe:unsafe-pvector-pop-right pv))
               rest))))

  (bench 'append-halves 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (append left-list right-list))))
  (bench 'append-halves 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (vector-append left-vector right-vector))))
  (bench 'append-halves 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (treelist-append left-treelist right-treelist))))
  (bench 'append-halves 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (cutie:pvector-append left-cutie-pvector right-cutie-pvector))))
  (bench 'append-halves 'raw-pvector
         (lambda ()
           (for/fold ([r (raw:pvector-empty)]) ([j (in-range m)])
             (raw:pvector-append left-raw-pvector right-raw-pvector))))
  (bench 'append-halves 'chunked-pvector
         (lambda ()
           (for/fold ([r (chunked:pvector-empty)]) ([j (in-range m)])
             (chunked:pvector-append left-chunked-pvector right-chunked-pvector))))
  (bench 'append-halves 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-append left-pvector right-pvector))))
  (bench 'append-halves 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-append left-pvector right-pvector))))

  (bench 'first-repeated 'list
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (car base-list)))))
  (bench 'first-repeated 'vector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (vector-ref base-vector 0)))))
  (bench 'first-repeated 'treelist
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (treelist-first base-treelist)))))
  (bench 'first-repeated 'cutie-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (cutie:pvector-view-left base-cutie-pvector)))))
  (bench 'first-repeated 'raw-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (raw:pvector-view-left base-raw-pvector)))))
  (bench 'first-repeated 'chunked-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (chunked:pvector-view-left base-chunked-pvector)))))
  (bench 'first-repeated 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (pvector-first base-pvector)))))
  (bench 'first-repeated 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (unsafe:unsafe-pvector-first base-pvector)))))

  (bench 'last-repeated 'list
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (last base-list))))
         #:when (n . <= . list-limit))
  (bench 'last-repeated 'vector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (vector-ref base-vector (sub1 n))))))
  (bench 'last-repeated 'treelist
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (treelist-last base-treelist)))))
  (bench 'last-repeated 'cutie-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (cutie:pvector-view-right base-cutie-pvector)))))
  (bench 'last-repeated 'raw-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (raw:pvector-view-right base-raw-pvector)))))
  (bench 'last-repeated 'chunked-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (chunked:pvector-view-right base-chunked-pvector)))))
  (bench 'last-repeated 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (pvector-last base-pvector)))))
  (bench 'last-repeated 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (unsafe:unsafe-pvector-last base-pvector)))))

  (bench 'split-middle 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (list (take base-list half) (drop base-list half)))))
  (bench 'split-middle 'vector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (list (vector-copy base-vector 0 half)
                   (vector-copy base-vector half n)))))
  (bench 'split-middle 'treelist
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (list (treelist-take base-treelist half)
                   (treelist-drop base-treelist half)))))
  (bench 'split-middle 'cutie-pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (define-values (left right) (cutie:pvector-split-at base-cutie-pvector half))
             (list left right))))
  (bench 'split-middle 'raw-pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (define-values (left right) (raw:pvector-split-at base-raw-pvector half))
             (list left right))))
  (bench 'split-middle 'chunked-pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (define-values (left right) (chunked:pvector-split-at base-chunked-pvector half))
             (list left right))))
  (bench 'split-middle 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (define-values (left right) (pvector-split-at base-pvector half))
             (list left right))))
  (bench 'split-middle 'unsafe-pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (define-values (left right) (unsafe:unsafe-pvector-split-at base-pvector half))
             (list left right))))

  (bench 'take-middle 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (take base-list half))))
  (bench 'take-middle 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (vector-take base-vector half))))
  (bench 'take-middle 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (treelist-take base-treelist half))))
  (bench 'take-middle 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (cutie:pvector-take base-cutie-pvector half))))
  (bench 'take-middle 'raw-pvector
         (lambda ()
           (for/fold ([r (raw:pvector-empty)]) ([j (in-range m)])
             (raw:pvector-take base-raw-pvector half))))
  (bench 'take-middle 'chunked-pvector
         (lambda ()
           (for/fold ([r (chunked:pvector-empty)]) ([j (in-range m)])
             (chunked:pvector-take base-chunked-pvector half))))
  (bench 'take-middle 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-take base-pvector half))))
  (bench 'take-middle 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-take base-pvector half))))

  (bench 'drop-middle 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (drop base-list half))))
  (bench 'drop-middle 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (vector-drop base-vector half))))
  (bench 'drop-middle 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (treelist-drop base-treelist half))))
  (bench 'drop-middle 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (cutie:pvector-drop base-cutie-pvector half))))
  (bench 'drop-middle 'raw-pvector
         (lambda ()
           (for/fold ([r (raw:pvector-empty)]) ([j (in-range m)])
             (raw:pvector-drop base-raw-pvector half))))
  (bench 'drop-middle 'chunked-pvector
         (lambda ()
           (for/fold ([r (chunked:pvector-empty)]) ([j (in-range m)])
             (chunked:pvector-drop base-chunked-pvector half))))
  (bench 'drop-middle 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-drop base-pvector half))))
  (bench 'drop-middle 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-drop base-pvector half))))

  (bench 'subvector-middle 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (take (drop base-list quarter) (- three-quarter quarter)))))
  (bench 'subvector-middle 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (vector-copy base-vector quarter three-quarter))))
  (bench 'subvector-middle 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (treelist-drop (treelist-take base-treelist three-quarter) quarter))))
  (bench 'subvector-middle 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (cutie:pvector-copy base-cutie-pvector quarter three-quarter))))
  (bench 'subvector-middle 'raw-pvector
         (lambda ()
           (for/fold ([r (raw:pvector-empty)]) ([j (in-range m)])
             (raw:pvector-copy base-raw-pvector quarter three-quarter))))
  (bench 'subvector-middle 'chunked-pvector
         (lambda ()
           (for/fold ([r (chunked:pvector-empty)]) ([j (in-range m)])
             (chunked:pvector-copy base-chunked-pvector quarter three-quarter))))
  (bench 'subvector-middle 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (pvector-subvector base-pvector quarter three-quarter))))
  (bench 'subvector-middle 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (unsafe:unsafe-pvector-subvector base-pvector quarter three-quarter))))

  (bench 'ref-sequential 'list
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (list-ref base-list i))))
         #:when (n . <= . list-limit))
  (bench 'ref-sequential 'vector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (vector-ref base-vector i)))))
  (bench 'ref-sequential 'treelist
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (treelist-ref base-treelist i)))))
  (bench 'ref-sequential 'cutie-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (cutie:pvector-ref base-cutie-pvector i)))))
  (bench 'ref-sequential 'raw-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (raw:pvector-ref base-raw-pvector i)))))
  (bench 'ref-sequential 'chunked-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (chunked:pvector-ref base-chunked-pvector i)))))
  (bench 'ref-sequential 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (pvector-ref base-pvector i)))))
  (bench 'ref-sequential 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-range n)])
             (+ sum (unsafe:unsafe-pvector-ref base-pvector i)))))

  (bench 'set-sequential 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (for/fold ([xs base-list]) ([i (in-range n)])
               (list-set xs i (+ i j)))))
         #:when (n . <= . list-limit))
  (bench 'set-sequential 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (for/fold ([vec base-vector]) ([i (in-range n)])
               (vector-set/persistent vec i (+ i j)))))
         #:when (n . <= . list-limit))
  (bench 'set-sequential 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (for/fold ([tl base-treelist]) ([i (in-range n)])
               (treelist-set tl i (+ i j))))))
  (bench 'set-sequential 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv base-cutie-pvector]) ([i (in-range n)])
               (cutie:pvector-set pv i (+ i j))))))
  (bench 'set-sequential 'raw-pvector
         (lambda ()
           (for/fold ([r (raw:pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv base-raw-pvector]) ([i (in-range n)])
               (raw:pvector-set pv i (+ i j))))))
  (bench 'set-sequential 'chunked-pvector
         (lambda ()
           (for/fold ([r (chunked:pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv base-chunked-pvector]) ([i (in-range n)])
               (chunked:pvector-set pv i (+ i j))))))
  (bench 'set-sequential 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv base-pvector]) ([i (in-range n)])
               (pvector-set pv i (+ i j))))))
  (bench 'set-sequential 'unsafe-pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (for/fold ([pv base-pvector]) ([i (in-range n)])
               (unsafe:unsafe-pvector-set pv i (+ i j))))))

  (bench 'iterate 'list
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-list base-list)])
             (+ sum i))))
  (bench 'iterate 'vector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-vector base-vector)])
             (+ sum i))))
  (bench 'iterate 'treelist
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-treelist base-treelist)])
             (+ sum i))))
  (bench 'iterate 'cutie-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (cutie:in-pvector base-cutie-pvector)])
             (+ sum i))))
  (bench 'iterate 'raw-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (raw:in-pvector base-raw-pvector)])
             (+ sum i))))
  (bench 'iterate 'chunked-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (chunked:in-pvector base-chunked-pvector)])
             (+ sum i))))
  (bench 'iterate 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-pvector base-pvector)])
             (+ sum i))))
  (bench 'iterate 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (unsafe:unsafe-in-pvector base-pvector)])
             (+ sum i))))

  (bench 'iterate-reverse 'list
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-list base-list-reverse)])
             (+ sum i))))
  (bench 'iterate-reverse 'vector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-vector base-vector-reverse)])
             (+ sum i))))
  (bench 'iterate-reverse 'treelist
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-treelist base-treelist-reverse)])
             (+ sum i))))
  (bench 'iterate-reverse 'cutie-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (cutie:in-pvector-reverse base-cutie-pvector)])
             (+ sum i))))
  (bench 'iterate-reverse 'raw-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (raw:in-pvector-reverse base-raw-pvector)])
             (+ sum i))))
  (bench 'iterate-reverse 'chunked-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (chunked:in-pvector-reverse base-chunked-pvector)])
             (+ sum i))))
  (bench 'iterate-reverse 'pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (in-pvector-reverse base-pvector)])
             (+ sum i))))
  (bench 'iterate-reverse 'unsafe-pvector
         (lambda ()
           (for*/fold ([sum 0]) ([j (in-range m)] [i (unsafe:unsafe-in-pvector-reverse base-pvector)])
             (+ sum i))))

  (bench 'list->seq 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (append base-list null))))
  (bench 'list->seq 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (list->vector base-list))))
  (bench 'list->seq 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (list->treelist base-list))))
  (bench 'list->seq 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (cutie:list->pvector base-list))))
  (bench 'list->seq 'chunked-pvector
         (lambda ()
           (for/fold ([r (chunked:pvector-empty)]) ([j (in-range m)])
             (chunked:list->pvector base-list))))
  (bench 'list->seq 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (list->pvector base-list))))

  (bench 'vector->seq 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (vector->list base-vector))))
  (bench 'vector->seq 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (vector-copy base-vector))))
  (bench 'vector->seq 'treelist
         (lambda ()
           (for/fold ([r empty-treelist]) ([j (in-range m)])
             (vector->treelist base-vector))))
  (bench 'vector->seq 'cutie-pvector
         (lambda ()
           (for/fold ([r (cutie:pvector-empty)]) ([j (in-range m)])
             (cutie:vector->pvector base-vector))))
  (bench 'vector->seq 'chunked-pvector
         (lambda ()
           (for/fold ([r (chunked:pvector-empty)]) ([j (in-range m)])
             (chunked:vector->pvector base-vector))))
  (bench 'vector->seq 'pvector
         (lambda ()
           (for/fold ([r (pvector-empty)]) ([j (in-range m)])
             (vector->pvector base-vector))))

  (bench 'seq->list 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (append base-list null))))
  (bench 'seq->list 'vector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (vector->list base-vector))))
  (bench 'seq->list 'treelist
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (treelist->list base-treelist))))
  (bench 'seq->list 'cutie-pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (cutie:pvector->list base-cutie-pvector))))
  (bench 'seq->list 'raw-pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (raw:pvector->list base-raw-pvector))))
  (bench 'seq->list 'chunked-pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (chunked:pvector->list base-chunked-pvector))))
  (bench 'seq->list 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (pvector->list base-pvector))))
  (bench 'seq->list 'unsafe-pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (for/list ([i (unsafe:unsafe-in-pvector base-pvector)]) i))))

  (bench 'seq->vector 'list
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (list->vector base-list))))
  (bench 'seq->vector 'vector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (vector-copy base-vector))))
  (bench 'seq->vector 'treelist
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (treelist->vector base-treelist))))
  (bench 'seq->vector 'cutie-pvector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (cutie:pvector->vector base-cutie-pvector))))
  (bench 'seq->vector 'raw-pvector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (raw:pvector->vector base-raw-pvector))))
  (bench 'seq->vector 'chunked-pvector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (chunked:pvector->vector base-chunked-pvector))))
  (bench 'seq->vector 'pvector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (pvector->vector base-pvector))))
  (bench 'seq->vector 'unsafe-pvector
         (lambda ()
           (for/fold ([r #()]) ([j (in-range m)])
             (for/vector #:length n ([i (unsafe:unsafe-in-pvector base-pvector)]) i))))

  (bench 'stream-list 'list
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list base-list))))
  (bench 'stream-list 'treelist
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list base-treelist))))
  (bench 'stream-list 'pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list base-pvector))))
  (bench 'stream-list 'unsafe-pvector
         (lambda ()
           (for/fold ([r null]) ([j (in-range m)])
             (stream->list base-pvector))))
  )

(module+ main
  (measure M N))
