#lang racket/base

(require racket/list
         racket/match
         racket/pvector
         (prefix-in unsafe: (submod racket/pvector unsafe))
         racket/serialize
         racket/stream
         rackunit)

(define (check-pvector-model pv xs)
  (check-true (pvector? pv))
  (check-equal? (pvector-length pv) (length xs))
  (check-equal? (pvector->list pv) xs)
  (check-equal? (vector->list (pvector->vector pv)) xs)
  (for ([x (in-list xs)]
        [i (in-naturals)])
    (check-equal? (pvector-ref pv i) x)))

(define (list-set xs i v)
  (append (take xs i) (list v) (drop xs (add1 i))))

(define (list-insert xs i v)
  (append (take xs i) (list v) (drop xs i)))

(define (list-delete xs i)
  (values (append (take xs i) (drop xs (add1 i)))
          (list-ref xs i)))

(test-case "construction and conversion"
  (check-pvector-model (pvector-empty) '())
  (check-pred pvector-empty? (pvector-empty))
  (check-false (pvector-empty? '(not a pvector)))
  (check-pvector-model (pvector 1 2 3) '(1 2 3))
  (check-pvector-model (make-pvector 4 'x) '(x x x x))
  (check-pvector-model (list->pvector '(a b c)) '(a b c))
  (check-pvector-model (vector->pvector #(a b c)) '(a b c))
  (check-pvector-model (sequence->pvector (in-range 5)) '(0 1 2 3 4)))

(test-case "ref and set"
  (define pv (pvector 'a 'b 'c 'd))
  (check-equal? (pvector-ref pv 2) 'c)
  (define pv* (pvector-set pv 2 'x))
  (check-pvector-model pv '(a b c d))
  (check-pvector-model pv* '(a b x d)))

(test-case "left and right endpoints"
  (define pv
    (for/fold ([pv (pvector-empty)])
              ([i (in-range 8)])
      (pvector-cons-right pv i)))
  (check-pvector-model pv '(0 1 2 3 4 5 6 7))
  (check-equal? (pvector-first pv) 0)
  (check-equal? (pvector-last pv) 7)
  (define-values (left rest-left) (pvector-pop-left pv))
  (check-equal? left 0)
  (check-pvector-model rest-left '(1 2 3 4 5 6 7))
  (define-values (right rest-right) (pvector-pop-right pv))
  (check-equal? right 7)
  (check-pvector-model rest-right '(0 1 2 3 4 5 6))
  (check-pvector-model (pvector-cons-left pv 'z) '(z 0 1 2 3 4 5 6 7))
  (check-pvector-model (pvector-cons-right pv 'z) '(0 1 2 3 4 5 6 7 z)))

(test-case "append, split, take, drop, and subvector"
  (define pv (list->pvector (range 12)))
  (check-pvector-model (pvector-append (pvector 0 1 2) (pvector 3 4))
                       '(0 1 2 3 4))
  (for ([pos (in-range 13)])
    (define-values (left right) (pvector-split-at pv pos))
    (check-pvector-model left (take (range 12) pos))
    (check-pvector-model right (drop (range 12) pos))
    (check-pvector-model (pvector-take pv pos) (take (range 12) pos))
    (check-pvector-model (pvector-drop pv pos) (drop (range 12) pos)))
  (define-values (left mid right) (pvector-split pv 6))
  (check-pvector-model left '(0 1 2 3 4 5))
  (check-equal? mid 6)
  (check-pvector-model right '(7 8 9 10 11))
  (check-pvector-model (pvector-take pv 0) '())
  (check-pvector-model (pvector-take pv 4) '(0 1 2 3))
  (check-pvector-model (pvector-drop pv 8) '(8 9 10 11))
  (check-pvector-model (pvector-drop pv 12) '())
  (check-pvector-model (pvector-take-right pv 3) '(9 10 11))
  (check-pvector-model (pvector-drop-right pv 9) '(0 1 2))
  (for* ([start (in-range 13)]
         [end (in-range start 13)])
    (check-pvector-model (pvector-subvector pv start end)
                         (take (drop (range 12) start) (- end start)))))

(test-case "insert and delete"
  (define pv0 (list->pvector '(a b c d)))
  (define pv1 (pvector-insert pv0 0 'z))
  (check-pvector-model pv1 '(z a b c d))
  (define pv2 (pvector-insert pv1 3 'x))
  (check-pvector-model pv2 '(z a b x c d))
  (define pv3 (pvector-insert pv2 (pvector-length pv2) 'end))
  (check-pvector-model pv3 '(z a b x c d end))
  (define-values (pv4 deleted) (pvector-delete pv3 3))
  (check-equal? deleted 'x)
  (check-pvector-model pv4 '(z a b c d end)))

(test-case "sequence, comprehensions, equality, and printing"
  (define pv (pvector 1 2 3))
  (check-equal? (for/list ([x pv]) x) '(1 2 3))
  (check-equal? (for/list ([x (in-pvector-reverse pv)]) x) '(3 2 1))
  (check-pvector-model (for/pvector ([x (in-range 4)]) (* x x))
                       '(0 1 4 9))
  (check-pvector-model (for*/pvector ([x (in-range 2)] [y (in-range 2)])
                         (list x y))
                       '((0 0) (0 1) (1 0) (1 1)))
  (check-equal? (pvector 1 2 3) (list->pvector '(1 2 3)))
  (check-not-equal? (pvector 1 2 3) '(1 2 3))
  (check-equal? (equal-hash-code (pvector 1 2 3))
                (equal-hash-code (list->pvector '(1 2 3))))
  (check-equal? (format "~s" pv) "(pvector 1 2 3)"))

(test-case "stream"
  (define pv (pvector 1 2 3))
  (check-true (stream? pv))
  (check-false (stream-empty? pv))
  (check-true (stream-empty? (pvector-empty)))
  (check-equal? (stream-first pv) 1)
  (check-equal? (stream-first (stream-rest pv)) 2)
  (check-equal? (stream->list pv) '(1 2 3)))

(test-case "serialization"
  (define pv (pvector 'a "b" 3))
  (define pv* (deserialize (serialize pv)))
  (check-true (pvector? pv*))
  (check-false (pvector? '(not a pvector)))
  (check-equal? pv* pv)
  (check-equal? (pvector->list pv*) '(a "b" 3)))

(test-case "unsafe submodule"
  (define pv (list->pvector (range 6)))
  (check-equal? (unsafe:unsafe-pvector-length pv) 6)
  (check-equal? (unsafe:unsafe-pvector-ref pv 4) 4)
  (check-pvector-model (unsafe:unsafe-pvector-set pv 2 'x)
                       '(0 1 x 3 4 5))
  (define-values (left right) (unsafe:unsafe-pvector-split-at pv 3))
  (check-pvector-model left '(0 1 2))
  (check-pvector-model right '(3 4 5))
  (check-equal? (for/list ([x (unsafe:unsafe-in-pvector-reverse pv)]) x)
                '(5 4 3 2 1 0)))

(test-case "errors"
  (check-exn exn:fail? (lambda () (pvector-length '(not a pvector))))
  (check-exn exn:fail? (lambda () (list->pvector '#(not a list))))
  (check-exn exn:fail? (lambda () (vector->pvector '(not a vector))))
  (check-exn exn:fail? (lambda () (sequence->pvector values)))
  (check-exn exn:fail? (lambda () (pvector-ref (pvector 1) 1)))
  (check-exn exn:fail? (lambda () (pvector-ref (pvector 1) -1)))
  (check-exn exn:fail? (lambda () (pvector-set (pvector 1) 1 'x)))
  (check-exn exn:fail? (lambda () (pvector-first (pvector-empty))))
  (check-exn exn:fail? (lambda () (pvector-last (pvector-empty))))
  (check-exn exn:fail? (lambda () (pvector-pop-left (pvector-empty))))
  (check-exn exn:fail? (lambda () (pvector-pop-right (pvector-empty))))
  (check-exn exn:fail? (lambda () (pvector-insert (pvector 1) 2 'x)))
  (check-exn exn:fail? (lambda () (pvector-delete (pvector 1) 1)))
  (check-exn exn:fail? (lambda () (pvector-subvector (pvector 1 2) 2 1))))

(test-case "list-model operation trace"
  (define ops
    '((cons-right 0)
      (cons-right 1)
      (cons-left z)
      (insert 1 a)
      (set 2 b)
      (cons-right 4)
      (delete 3)
      (insert 4 end)
      (set 0 start)
      (delete 1)))
  (let loop ([ops ops] [pv (pvector-empty)] [xs '()])
    (check-pvector-model pv xs)
    (match ops
      ['() (void)]
      [(cons op rest)
       (define-values (pv* xs*)
         (match op
           [`(cons-right ,v)
            (values (pvector-cons-right pv v) (append xs (list v)))]
           [`(cons-left ,v)
            (values (pvector-cons-left pv v) (cons v xs))]
           [`(insert ,i ,v)
            (values (pvector-insert pv i v) (list-insert xs i v))]
           [`(set ,i ,v)
            (values (pvector-set pv i v) (list-set xs i v))]
           [`(delete ,i)
            (define-values (pv-rest pv-deleted) (pvector-delete pv i))
            (define-values (xs-rest xs-deleted) (list-delete xs i))
            (check-equal? pv-deleted xs-deleted)
            (values pv-rest xs-rest)]))
       (loop rest pv* xs*)])))

(test-case "seeded randomized list model"
  (random-seed 20260611)
  (let loop ([step 0] [pv (pvector-empty)] [xs '()])
    (check-pvector-model pv xs)
    (when (< step 250)
      (define len (length xs))
      (define op (if (zero? len) (random 2) (random 7)))
      (define-values (pv* xs*)
        (case op
          [(0)
           (define value (list 'r step))
           (values (pvector-cons-right pv value)
                   (append xs (list value)))]
          [(1)
           (define value (list 'l step))
           (values (pvector-cons-left pv value)
                   (cons value xs))]
          [(2)
           (define i (random len))
           (define value (list 's step))
           (values (pvector-set pv i value)
                   (list-set xs i value))]
          [(3)
           (define i (random (add1 len)))
           (define value (list 'i step))
           (values (pvector-insert pv i value)
                   (list-insert xs i value))]
          [(4)
           (define i (random len))
           (define-values (pv-rest pv-deleted) (pvector-delete pv i))
           (define-values (xs-rest xs-deleted) (list-delete xs i))
           (check-equal? pv-deleted xs-deleted)
           (values pv-rest xs-rest)]
          [(5)
           (define i (random (add1 len)))
           (define-values (left right) (pvector-split-at pv i))
           (check-pvector-model left (take xs i))
           (check-pvector-model right (drop xs i))
           (values (pvector-append left right) xs)]
          [else
           (define i (random (add1 len)))
           (values (pvector-drop (pvector-cons-left (pvector-take pv i) 'tmp) 1)
                   (take xs i))]))
      (loop (add1 step) pv* xs*))))
