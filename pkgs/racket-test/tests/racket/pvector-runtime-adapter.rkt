#lang racket/base

(require racket/list
         (prefix-in adapter: racket/private/pvector-runtime-adapter)
         rackunit)

(define (check-model pv xs)
  (check-true (adapter:pvector? pv))
  (check-equal? (adapter:pvector-length pv) (length xs))
  (check-equal? (adapter:pvector->list pv) xs)
  (check-equal? (vector->list (adapter:pvector->vector pv)) xs)
  (for ([x (in-list xs)]
        [i (in-naturals)])
    (check-equal? (adapter:pvector-ref pv i) x)))

(test-case "backend probe"
  (define backend (adapter:pvector-runtime-adapter-backend))
  (check-not-false (memq backend '(core chunked)))
  (check-equal? backend
                (if (adapter:pvector-runtime-adapter-core-available?)
                    'core
                    'chunked)))

(test-case "adapter operations"
  (define xs (range 130))
  (define pv (adapter:list->pvector xs))
  (check-model pv xs)
  (check-model (adapter:vector->pvector (list->vector xs)) xs)
  (check-model (adapter:make-pvector 5 'x) '(x x x x x))
  (check-equal? (adapter:pvector-view-left pv) 0)
  (check-equal? (adapter:pvector-view-right pv) 129)
  (check-model (adapter:pvector-set pv 64 'x)
               (append (take xs 64) '(x) (drop xs 65)))
  (check-model (adapter:pvector-cons-left pv 'left)
               (cons 'left xs))
  (check-model (adapter:pvector-cons-right pv 'right)
               (append xs '(right)))
  (define-values (left rest-left) (adapter:pvector-pop-left pv))
  (check-equal? left 0)
  (check-model rest-left (range 1 130))
  (define-values (right rest-right) (adapter:pvector-pop-right pv))
  (check-equal? right 129)
  (check-model rest-right (range 129))
  (for ([pos (in-list '(0 1 63 64 65 100 129 130))])
    (define-values (l r) (adapter:pvector-split-at pv pos))
    (check-model l (take xs pos))
    (check-model r (drop xs pos))
    (check-model (adapter:pvector-take pv pos) (take xs pos))
    (check-model (adapter:pvector-drop pv pos) (drop xs pos)))
  (check-model (adapter:pvector-copy pv 63 100)
               (take (drop xs 63) 37))
  (check-equal? (for/list ([x (adapter:in-pvector pv)]) x)
                xs)
  (check-equal? (for/list ([x (adapter:in-pvector-reverse pv)]) x)
                (reverse xs)))
