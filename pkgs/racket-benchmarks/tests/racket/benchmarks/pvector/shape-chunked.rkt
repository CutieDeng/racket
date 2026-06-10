#lang racket/base

(require racket/cmdline
         racket/list
         (prefix-in chunked: racket/private/pvector-chunked)
         racket/string)

(define ns '(10000))

(define (parse-size-list s)
  (for/list ([part (in-list (string-split s ","))]
             #:unless (string=? part ""))
    (define n (string->number part))
    (unless (exact-positive-integer? n)
      (raise-user-error 'pvector-shape-chunked
                        "expected a positive exact integer, got ~e"
                        part))
    n))

(command-line
 #:program "pvector-shape-chunked"
 #:once-each
 [("--ns") s "Comma-separated sizes"
          (set! ns (parse-size-list s))])

(define (href h k)
  (hash-ref h k 0))

(define (struct-objects h)
  (+ (href h 'ft-empty)
     (href h 'ft-single)
     (href h 'ft-deep)
     (href h 'digit1)
     (href h 'digit2)
     (href h 'digit3)
     (href h 'digit4)
     (href h 'node2)
     (href h 'node3)
     (href h 'slice-leaves)))

(define (leaf-objects h)
  (+ (href h 'vector-leaves)
     (href h 'slice-leaves)))

(define (total-objects h)
  (+ (struct-objects h)
     (href h 'vector-leaves)))

(define (ratio numerator denominator digits)
  (real->decimal-string (/ numerator (max 1 denominator)) digits))

(define (print-stats scenario n h)
  (define len (href h 'length))
  (printf "~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\n"
          scenario
          n
          len
          (href h 'max-depth)
          (href h 'leaves)
          (href h 'vector-leaves)
          (href h 'slice-leaves)
          (href h 'slice-base-vectors)
          (href h 'singleton-leaves)
          (href h 'full-leaves)
          (+ (href h 'digit1)
             (href h 'digit2)
             (href h 'digit3)
             (href h 'digit4))
          (href h 'node2)
          (href h 'node3)
          (struct-objects h)
          (leaf-objects h)
          (total-objects h)
          (ratio (total-objects h) len 4)
          (href h 'retained-elems)
          (ratio (href h 'retained-elems) (href h 'visible-elems) 3)))

(define (build-compact n)
  (chunked:list->pvector (build-list n values)))

(define (build-cons-right n)
  (for/fold ([pv (chunked:pvector-empty)]) ([i (in-range n)])
    (chunked:pvector-cons-right pv i)))

(define (build-cons-left n)
  (for/fold ([pv (chunked:pvector-empty)]) ([i (in-range n)])
    (chunked:pvector-cons-left pv i)))

(define (pop-left-half pv n)
  (for/fold ([pv pv]) ([i (in-range (quotient n 2))])
    (define-values (_ rest) (chunked:pvector-pop-left pv))
    rest))

(define (pop-right-half pv n)
  (for/fold ([pv pv]) ([i (in-range (quotient n 2))])
    (define-values (_ rest) (chunked:pvector-pop-right pv))
    rest))

(define (split-left pv n)
  (define-values (left right) (chunked:pvector-split-at pv (quotient n 2)))
  left)

(define (split-right pv n)
  (define-values (left right) (chunked:pvector-split-at pv (quotient n 2)))
  right)

(define (subvector-middle pv n)
  (chunked:pvector-copy pv (quotient n 4) (- n (quotient n 4))))

(printf "scenario\tn\tlength\tmax-depth\tleaves\tvector-leaves\tslice-leaves\tslice-base-vectors\tsingleton-leaves\tfull-leaves\tdigits\tnode2\tnode3\tstruct-objects\tleaf-objects\ttotal-objects\tobjects/elem\tretained-elems\tretained/visible\n")

(for ([n (in-list ns)])
  (define compact (build-compact n))
  (define scenarios
    (list
     (cons 'compact compact)
     (cons 'cons-right (build-cons-right n))
     (cons 'cons-left (build-cons-left n))
     (cons 'pop-left-half (pop-left-half compact n))
     (cons 'pop-right-half (pop-right-half compact n))
     (cons 'split-left (split-left compact n))
     (cons 'split-right (split-right compact n))
     (cons 'subvector-middle (subvector-middle compact n))))
  (for ([scenario+pv (in-list scenarios)])
    (print-stats (car scenario+pv)
                 n
                 (chunked:pvector-shape-stats (cdr scenario+pv)))))
