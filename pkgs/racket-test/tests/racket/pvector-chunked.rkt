#lang racket/base

(require racket/list
         racket/match
         (prefix-in chunked: racket/private/pvector-chunked)
         rackunit)

(define (check-model pv xs)
  (check-true (chunked:pvector? pv))
  (check-equal? (chunked:pvector-length pv) (length xs))
  (check-equal? (chunked:pvector->list pv) xs)
  (check-equal? (vector->list (chunked:pvector->vector pv)) xs)
  (for ([x (in-list xs)]
        [i (in-naturals)])
    (check-equal? (chunked:pvector-ref pv i) x)))

(define (list-set xs i v)
  (append (take xs i) (list v) (drop xs (add1 i))))

(define (list-insert xs i v)
  (append (take xs i) (list v) (drop xs i)))

(define (list-delete xs i)
  (values (append (take xs i) (drop xs (add1 i)))
          (list-ref xs i)))

(test-case "construction and conversion"
  (check-model (chunked:pvector-empty) '())
  (check-true (chunked:pvector-empty? (chunked:pvector-empty)))
  (check-false (chunked:pvector-empty? '(not a pvector)))
  (check-model (chunked:pvector 1 2 3) '(1 2 3))
  (check-model (chunked:make-pvector 5 'x) '(x x x x x))
  (check-model (chunked:list->pvector (range 130)) (range 130))
  (check-model (chunked:vector->pvector (list->vector (range 130))) (range 130))
  (check-model (chunked:sequence->pvector (in-range 130)) (range 130)))

(test-case "ref set and endpoints"
  (define pv (chunked:list->pvector (range 130)))
  (check-equal? (chunked:pvector-view-left pv) 0)
  (check-equal? (chunked:pvector-view-right pv) 129)
  (check-equal? (chunked:pvector-ref pv 64) 64)
  (check-model (chunked:pvector-set pv 64 'x)
               (list-set (range 130) 64 'x))
  (check-model (chunked:pvector-cons-left pv 'left)
               (cons 'left (range 130)))
  (check-model (chunked:pvector-cons-right pv 'right)
               (append (range 130) '(right)))
  (define-values (left rest-left) (chunked:pvector-pop-left pv))
  (check-equal? left 0)
  (check-model rest-left (range 1 130))
  (define-values (right rest-right) (chunked:pvector-pop-right pv))
  (check-equal? right 129)
  (check-model rest-right (range 129)))

(test-case "append split take drop and copy"
  (define xs (range 130))
  (define pv (chunked:list->pvector xs))
  (check-model (chunked:pvector-append (chunked:list->pvector (take xs 65))
                                       (chunked:list->pvector (drop xs 65)))
               xs)
  (for ([pos (in-list '(0 1 63 64 65 100 129 130))])
    (define-values (left right) (chunked:pvector-split-at pv pos))
    (check-model left (take xs pos))
    (check-model right (drop xs pos))
    (check-model (chunked:pvector-take pv pos) (take xs pos))
    (check-model (chunked:pvector-drop pv pos) (drop xs pos)))
  (define-values (left value right) (chunked:pvector-split pv 64))
  (check-model left (take xs 64))
  (check-equal? value 64)
  (check-model right (drop xs 65))
  (for* ([start (in-list '(0 1 63 64 65 100 130))]
         [end (in-list '(0 1 63 64 65 100 130))]
         #:when (<= start end))
    (check-model (chunked:pvector-copy pv start end)
                 (take (drop xs start) (- end start)))))

(test-case "insert delete and sequence"
  (define pv0 (chunked:list->pvector (range 70)))
  (check-model (chunked:pvector-insert pv0 0 'a)
               (list-insert (range 70) 0 'a))
  (check-model (chunked:pvector-insert pv0 64 'b)
               (list-insert (range 70) 64 'b))
  (check-model (chunked:pvector-insert pv0 70 'c)
               (list-insert (range 70) 70 'c))
  (define-values (pv1 deleted) (chunked:pvector-delete pv0 64))
  (check-equal? deleted 64)
  (check-model pv1 (let-values ([(xs _) (list-delete (range 70) 64)]) xs))
  (check-equal? (for/list ([x (chunked:in-pvector pv0)]) x)
                (range 70))
  (check-equal? (for/list ([x (chunked:in-pvector-reverse pv0)]) x)
                (reverse (range 70)))
  (check-model (chunked:for/pvector ([x (in-range 5)]) (* x x))
               '(0 1 4 9 16))
  (check-model (chunked:for*/pvector ([x (in-range 2)] [y (in-range 2)])
                 (list x y))
               '((0 0) (0 1) (1 0) (1 1))))

(test-case "seeded randomized list model"
  (random-seed 20260611)
  (let loop ([step 0] [pv (chunked:pvector-empty)] [xs '()])
    (check-model pv xs)
    (when (< step 250)
      (define len (length xs))
      (define op (if (zero? len) (random 2) (random 7)))
      (define-values (pv* xs*)
        (case op
          [(0)
           (define value (list 'r step))
           (values (chunked:pvector-cons-right pv value)
                   (append xs (list value)))]
          [(1)
           (define value (list 'l step))
           (values (chunked:pvector-cons-left pv value)
                   (cons value xs))]
          [(2)
           (define i (random len))
           (define value (list 's step))
           (values (chunked:pvector-set pv i value)
                   (list-set xs i value))]
          [(3)
           (define i (random (add1 len)))
           (define value (list 'i step))
           (values (chunked:pvector-insert pv i value)
                   (list-insert xs i value))]
          [(4)
           (define i (random len))
           (define-values (pv-rest pv-deleted) (chunked:pvector-delete pv i))
           (define-values (xs-rest xs-deleted) (list-delete xs i))
           (check-equal? pv-deleted xs-deleted)
           (values pv-rest xs-rest)]
          [(5)
           (define i (random (add1 len)))
           (values (chunked:pvector-take pv i) (take xs i))]
          [else
           (define i (random (add1 len)))
           (values (chunked:pvector-drop pv i) (drop xs i))]))
      (loop (add1 step) pv* xs*))))
