#lang racket/base

(require racket/cmdline
         racket/list
         racket/string
         racket/private/pvector
         racket/private/pvector-core)

(define ns '(10 100 1000 10000 100000))

(define (parse-size-list s)
  (for/list ([part (in-list (string-split s ","))]
             #:unless (string=? part ""))
    (define n (string->number part))
    (unless (exact-positive-integer? n)
      (raise-user-error 'pvector-shape "expected a positive exact integer, got ~e" part))
    n))

(command-line
 #:program "pvector-shape"
 #:once-each
 [("--ns") s "Comma-separated sizes"
          (set! ns (parse-size-list s))])

(define (inc! h k [n 1])
  (hash-set! h k (+ (hash-ref h k 0) n)))

(define (shape-stats pv)
  (define h (make-hasheq))
  (define max-depth 0)
  (define (note-depth! depth)
    (when (> depth max-depth)
      (set! max-depth depth)))
  (define (walk-node node depth)
    (note-depth! depth)
    (cond
      [(zero? depth)
       (inc! h 'leaves)]
      [(node:2? node)
       (inc! h 'node2)
       (define sub-depth (sub1 depth))
       (walk-node (node:2-a node) sub-depth)
       (walk-node (node:2-b node) sub-depth)]
      [else
       (inc! h 'node3)
       (define sub-depth (sub1 depth))
       (walk-node (node:3-a node) sub-depth)
       (walk-node (node:3-b node) sub-depth)
       (walk-node (node:3-c node) sub-depth)]))
  (define (walk-digit digit depth)
    (note-depth! depth)
    (cond
      [(digit:1? digit)
       (inc! h 'digit1)
       (walk-node (digit:1-a digit) depth)]
      [(digit:2? digit)
       (inc! h 'digit2)
       (walk-node (digit:2-a digit) depth)
       (walk-node (digit:2-b digit) depth)]
      [(digit:3? digit)
       (inc! h 'digit3)
       (walk-node (digit:3-a digit) depth)
       (walk-node (digit:3-b digit) depth)
       (walk-node (digit:3-c digit) depth)]
      [else
       (inc! h 'digit4)
       (walk-node (digit:4-a digit) depth)
       (walk-node (digit:4-b digit) depth)
       (walk-node (digit:4-c digit) depth)
       (walk-node (digit:4-d digit) depth)]))
  (define (walk-ft ft depth)
    (note-depth! depth)
    (cond
      [(ft:empty? ft)
       (inc! h 'ft-empty)]
      [(ft:single? ft)
       (inc! h 'ft-single)
       (walk-node (ft:single-a ft) depth)]
      [else
       (inc! h 'ft-deep)
       (walk-digit (ft:deep-left ft) depth)
       (walk-ft (ft:deep-inner ft) (add1 depth))
       (walk-digit (ft:deep-right ft) depth)]))
  (walk-ft pv 0)
  (hash-set! h 'max-depth max-depth)
  h)

(define (href h k)
  (hash-ref h k 0))

(define (total-struct-refs h)
  (+ (href h 'ft-empty)
     (href h 'ft-single)
     (href h 'ft-deep)
     (href h 'digit1)
     (href h 'digit2)
     (href h 'digit3)
     (href h 'digit4)
     (href h 'node2)
     (href h 'node3)))

(define (print-stats n pv h)
  (define struct-refs (total-struct-refs h))
  (printf "~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\n"
          n
          (href h 'max-depth)
          (href h 'leaves)
          (href h 'ft-empty)
          (href h 'ft-single)
          (href h 'ft-deep)
          (+ (href h 'digit1) (href h 'digit2) (href h 'digit3) (href h 'digit4))
          (href h 'node2)
          (href h 'node3)
          struct-refs
          (real->decimal-string (/ struct-refs (max 1 n)) 3)
          (pvector-length pv)))

(printf "n\tmax-depth\tleaves\tft-empty\tft-single\tft-deep\tdigits\tnode2\tnode3\tstruct-refs\tstructs/elem\tlength\n")
(for ([n (in-list ns)])
  (define pv (list->pvector (build-list n values)))
  (print-stats n pv (shape-stats pv)))
