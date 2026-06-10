#lang racket/base

(require (prefix-in fallback: "pvector-chunked.rkt"))

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
         pvector-view-left
         pvector-view-right
         pvector-cons-left
         pvector-cons-right
         pvector-pop-left
         pvector-pop-right
         pvector-append
         pvector-insert
         pvector-delete
         pvector-take
         pvector-drop
         pvector-take-right
         pvector-drop-right
         pvector-copy
         pvector-split
         pvector-split-at
         pvector-split-at-right
         in-pvector
         in-pvector-reverse
         in-pvector/index
         in-pvector-indexed
         for/pvector
         for*/pvector
         pvector-ref/fast
         pvector-set/fast
         pvector-shape-stats
         pvector-runtime-adapter-backend
         pvector-runtime-adapter-core-available?)

(define (maybe-kernel name)
  (with-handlers ([exn:fail? (lambda (_) #f)])
    (dynamic-require ''#%kernel name)))

(define core-pvector? (maybe-kernel 'core-pvector?))
(define core-pvector-empty (maybe-kernel 'core-pvector-empty))
(define core-pvector-empty? (maybe-kernel 'core-pvector-empty?))
(define core-pvector-length (maybe-kernel 'core-pvector-length))
(define core-vector->pvector (maybe-kernel 'core-vector->pvector))
(define core-list->pvector (maybe-kernel 'core-list->pvector))
(define core-make-pvector (maybe-kernel 'core-make-pvector))
(define core-pvector->vector (maybe-kernel 'core-pvector->vector))
(define core-pvector->list (maybe-kernel 'core-pvector->list))
(define core-pvector-ref (maybe-kernel 'core-pvector-ref))
(define core-pvector-set (maybe-kernel 'core-pvector-set))
(define core-pvector-cons-left (maybe-kernel 'core-pvector-cons-left))
(define core-pvector-cons-right (maybe-kernel 'core-pvector-cons-right))
(define core-pvector-pop-left (maybe-kernel 'core-pvector-pop-left))
(define core-pvector-pop-right (maybe-kernel 'core-pvector-pop-right))
(define core-pvector-append (maybe-kernel 'core-pvector-append))
(define core-pvector-split-at (maybe-kernel 'core-pvector-split-at))
(define core-pvector-split-at-right (maybe-kernel 'core-pvector-split-at-right))
(define core-pvector-take (maybe-kernel 'core-pvector-take))
(define core-pvector-drop (maybe-kernel 'core-pvector-drop))
(define core-pvector-copy (maybe-kernel 'core-pvector-copy))

(define core-bindings
  (list core-pvector?
        core-pvector-empty
        core-pvector-empty?
        core-pvector-length
        core-vector->pvector
        core-list->pvector
        core-make-pvector
        core-pvector->vector
        core-pvector->list
        core-pvector-ref
        core-pvector-set
        core-pvector-cons-left
        core-pvector-cons-right
        core-pvector-pop-left
        core-pvector-pop-right
        core-pvector-append
        core-pvector-split-at
        core-pvector-split-at-right
        core-pvector-take
        core-pvector-drop
        core-pvector-copy))

(define core-available?
  (andmap procedure? core-bindings))

(define (pvector-runtime-adapter-core-available?)
  core-available?)

(define (pvector-runtime-adapter-backend)
  (if core-available? 'core 'chunked))

(define (pvector? v)
  (if core-available?
      (core-pvector? v)
      (fallback:pvector? v)))

(define (pvector-empty)
  (if core-available?
      (core-pvector-empty)
      (fallback:pvector-empty)))

(define (pvector-empty? pv)
  (if core-available?
      (core-pvector-empty? pv)
      (fallback:pvector-empty? pv)))

(define (pvector-length pv)
  (if core-available?
      (core-pvector-length pv)
      (fallback:pvector-length pv)))

(define (vector->pvector vec)
  (if core-available?
      (core-vector->pvector vec)
      (fallback:vector->pvector vec)))

(define (list->pvector lst)
  (if core-available?
      (core-list->pvector lst)
      (fallback:list->pvector lst)))

(define (make-pvector n [value #f])
  (if core-available?
      (core-make-pvector n value)
      (fallback:make-pvector n value)))

(define (pvector . elems)
  (list->pvector elems))

(define (pvector->vector pv)
  (if core-available?
      (core-pvector->vector pv)
      (fallback:pvector->vector pv)))

(define (pvector->list pv)
  (if core-available?
      (core-pvector->list pv)
      (fallback:pvector->list pv)))

(define (sequence->pvector seq)
  (cond
    [(pvector? seq) seq]
    [(list? seq) (list->pvector seq)]
    [(vector? seq) (vector->pvector seq)]
    [else
     (for/fold ([pv (pvector-empty)]) ([elem seq])
       (pvector-cons-right pv elem))]))

(define (pvector-ref pv idx)
  (if core-available?
      (core-pvector-ref pv idx)
      (fallback:pvector-ref pv idx)))

(define pvector-ref/fast pvector-ref)

(define (pvector-set pv idx value)
  (if core-available?
      (core-pvector-set pv idx value)
      (fallback:pvector-set pv idx value)))

(define pvector-set/fast pvector-set)

(define (pvector-view-left pv)
  (pvector-ref pv 0))

(define (pvector-view-right pv)
  (pvector-ref pv (sub1 (pvector-length pv))))

(define (pvector-cons-left pv value)
  (if core-available?
      (core-pvector-cons-left pv value)
      (fallback:pvector-cons-left pv value)))

(define (pvector-cons-right pv value)
  (if core-available?
      (core-pvector-cons-right pv value)
      (fallback:pvector-cons-right pv value)))

(define (pvector-pop-left pv)
  (if core-available?
      (core-pvector-pop-left pv)
      (fallback:pvector-pop-left pv)))

(define (pvector-pop-right pv)
  (if core-available?
      (core-pvector-pop-right pv)
      (fallback:pvector-pop-right pv)))

(define (pvector-append left right)
  (if core-available?
      (core-pvector-append left right)
      (fallback:pvector-append left right)))

(define (pvector-split-at pv pos)
  (if core-available?
      (core-pvector-split-at pv pos)
      (fallback:pvector-split-at pv pos)))

(define (pvector-split-at-right pv pos)
  (if core-available?
      (core-pvector-split-at-right pv pos)
      (fallback:pvector-split-at-right pv pos)))

(define (pvector-take pv pos)
  (if core-available?
      (core-pvector-take pv pos)
      (fallback:pvector-take pv pos)))

(define (pvector-drop pv pos)
  (if core-available?
      (core-pvector-drop pv pos)
      (fallback:pvector-drop pv pos)))

(define (pvector-take-right pv pos)
  (pvector-drop pv (- (pvector-length pv) pos)))

(define (pvector-drop-right pv pos)
  (pvector-take pv (- (pvector-length pv) pos)))

(define (pvector-copy pv start [end (pvector-length pv)])
  (if core-available?
      (core-pvector-copy pv start end)
      (fallback:pvector-copy pv start end)))

(define (pvector-split pv idx)
  (define-values (left right) (pvector-split-at pv idx))
  (define-values (value right*) (pvector-pop-left right))
  (values left value right*))

(define (pvector-insert pv idx value)
  (define-values (left right) (pvector-split-at pv idx))
  (pvector-append left (pvector-cons-left right value)))

(define (pvector-delete pv idx)
  (define-values (left value right) (pvector-split pv idx))
  (values (pvector-append left right) value))

(define (in-pvector pv)
  (define vec (pvector->vector pv))
  (make-do-sequence
   (lambda ()
     (values (lambda (idx) (vector-ref vec idx))
             add1
             0
             (lambda (idx) (< idx (vector-length vec)))
             (lambda (elem) #t)
             (lambda (idx elem) #t)))))

(define (in-pvector-reverse pv)
  (define vec (pvector->vector pv))
  (make-do-sequence
   (lambda ()
     (values (lambda (idx) (vector-ref vec idx))
             sub1
             (sub1 (vector-length vec))
             (lambda (idx) (>= idx 0))
             (lambda (elem) #t)
             (lambda (idx elem) #t)))))

(define (in-pvector/index pv)
  (in-indexed (in-pvector pv)))

(define in-pvector-indexed in-pvector/index)

(define (pvector-shape-stats pv)
  (if core-available?
      (hasheq 'backend 'core
              'length (pvector-length pv))
      (fallback:pvector-shape-stats pv)))

(define-syntax-rule (for/pvector (clause ...) body ...)
  (list->pvector (for/list (clause ...) body ...)))

(define-syntax-rule (for*/pvector (clause ...) body ...)
  (list->pvector (for*/list (clause ...) body ...)))
