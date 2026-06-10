#lang racket/base

(require racket/match racket/sequence)
(require "pvector-core.rkt")

(define (pvector-cons-left pv value)
  (size-consL:impl pv value))

(define (pvector-cons-right pv value)
  (size-consR:impl pv value))

(define (pvector-pop-left pv)
  (size-hdL:impl pv))

(define (pvector-pop-right pv)
  (size-hdR:impl pv))

(define (pvector-append pv0 pv1)
  (size-concat:impl pv0 pv1))

(define pvector-empty:impl (ft:empty))
(define (pvector-empty) pvector-empty:impl)

;; Helper for node->digit conversion (used in split operations)
(define node->list (match-lambda
  [(node:2 _ a b) `(,a ,b)]
  [(node:3 _ a b c) `(,a ,b ,c)]
  )) ; match-lambda: node->list

(define (digit-add-list digit rest)
  (cond
    [(digit:1? digit)
     (cons (digit:1-a digit) rest)]
    [(digit:2? digit)
     (cons (digit:2-a digit)
           (cons (digit:2-b digit) rest))]
    [(digit:3? digit)
     (cons (digit:3-a digit)
           (cons (digit:3-b digit)
                 (cons (digit:3-c digit) rest)))]
    [else
     (cons (digit:4-a digit)
           (cons (digit:4-b digit)
                 (cons (digit:4-c digit)
                       (cons (digit:4-d digit) rest))))]))

(define (digit->list digit)
  (digit-add-list digit '()))

(define (list->digit lst _depth)
  (match lst
    [`(,a ,b ,c ,d) (digit:4 a b c d)]
    [`(,a ,b ,c) (digit:3 a b c)]
    [`(,a ,b) (digit:2 a b)]
    [`(,a) (digit:1 a)]))

(define (pvector-view-left ft)
  (cond
    [(ft:single? ft) (ft:single-a ft)]
    [(ft:deep? ft)
     (define digit (ft:deep-left ft))
     (cond
       [(digit:1? digit) (digit:1-a digit)]
       [(digit:2? digit) (digit:2-a digit)]
       [(digit:3? digit) (digit:3-a digit)]
       [else (digit:4-a digit)])]
    [else (assert-unreachable)]))

(define (pvector-view-right ft)
  (cond
    [(ft:single? ft) (ft:single-a ft)]
    [(ft:deep? ft)
     (define digit (ft:deep-right ft))
     (cond
       [(digit:1? digit) (digit:1-a digit)]
       [(digit:2? digit) (digit:2-b digit)]
       [(digit:3? digit) (digit:3-c digit)]
       [else (digit:4-d digit)])]
    [else (assert-unreachable)]))

;; ========================================
;; Size-specialized ref implementation
;; ========================================

(define (size:node node depth)
  (if (zero? depth)
      1
      (if (node:2? node)
          (node:2-v node)
          (node:3-v node)))
  ) ; define size:node

(define (size:digit digit depth)
  (cond
    [(digit:1? digit)
     (size:node (digit:1-a digit) depth)]
    [(digit:2? digit)
     (define a (digit:2-a digit))
     (define b (digit:2-b digit))
     (+ (size:node a depth)
        (size:node b depth))]
    [(digit:3? digit)
     (define a (digit:3-a digit))
     (define b (digit:3-b digit))
     (define c (digit:3-c digit))
     (+ (size:node a depth)
        (size:node b depth)
        (size:node c depth))]
    [else
     (define a (digit:4-a digit))
     (define b (digit:4-b digit))
     (define c (digit:4-c digit))
     (define d (digit:4-d digit))
     (+ (size:node a depth)
        (size:node b depth)
        (size:node c depth)
        (size:node d depth))]
    ) ; cond: digit
  ) ; define size:digit

(define (size:ft ft depth)
  (cond
    [(ft:empty? ft) 0]
    [(ft:single? ft) (size:node (ft:single-a ft) depth)]
    [else (ft:deep-v ft)]
    ) ; cond: ft
  ) ; define size:ft

(define (build-size-node2 a b depth)
  (node:2 (+ (size:node a depth)
             (size:node b depth))
          a
          b)
  ) ; define build-size-node2

(define (build-size-node3 a b c depth)
  (node:3 (+ (size:node a depth)
             (size:node b depth)
             (size:node c depth))
          a
          b
          c)
  ) ; define build-size-node3

;; ========================================
;; Size-specialized endpoint implementation
;; ========================================

(define (size-consL:impl ft value [depth 0])
  (cond
    [(ft:empty? ft) (ft:single value)]
    [(ft:single? ft)
     (define a (ft:single-a ft))
     (ft:deep (+ (size:node value depth)
                 (size:node a depth))
              (digit:1 value)
              pvector-empty:impl
              (digit:1 a))]
    [else
     (define total (ft:deep-v ft))
     (define left (ft:deep-left ft))
     (define inner (ft:deep-inner ft))
     (define right (ft:deep-right ft))
     (define new-total (+ (size:node value depth) total))
     (cond
       [(digit:4? left)
        (define a (digit:4-a left))
        (define b (digit:4-b left))
        (define c (digit:4-c left))
        (define d (digit:4-d left))
        (define left^ (digit:2 value a))
        (define inner^
          (size-consL:impl inner (build-size-node3 b c d depth) (add1 depth)))
        (ft:deep new-total left^ inner^ right)]
       [(digit:1? left)
        (define a (digit:1-a left))
        (ft:deep new-total (digit:2 value a) inner right)]
       [(digit:2? left)
        (define a (digit:2-a left))
        (define b (digit:2-b left))
        (ft:deep new-total (digit:3 value a b) inner right)]
       [else
        (define a (digit:3-a left))
        (define b (digit:3-b left))
        (define c (digit:3-c left))
        (ft:deep new-total (digit:4 value a b c) inner right)])]))

(define (size-consR:impl ft value [depth 0])
  (cond
    [(ft:empty? ft) (ft:single value)]
    [(ft:single? ft)
     (define a (ft:single-a ft))
     (ft:deep (+ (size:node a depth)
                 (size:node value depth))
              (digit:1 a)
              pvector-empty:impl
              (digit:1 value))]
    [else
     (define total (ft:deep-v ft))
     (define left (ft:deep-left ft))
     (define inner (ft:deep-inner ft))
     (define right (ft:deep-right ft))
     (define new-total (+ total (size:node value depth)))
     (cond
       [(digit:4? right)
        (define a (digit:4-a right))
        (define b (digit:4-b right))
        (define c (digit:4-c right))
        (define d (digit:4-d right))
        (define right^ (digit:2 d value))
        (define inner^
          (size-consR:impl inner (build-size-node3 a b c depth) (add1 depth)))
        (ft:deep new-total left inner^ right^)]
       [(digit:1? right)
        (define a (digit:1-a right))
        (ft:deep new-total left inner (digit:2 a value))]
       [(digit:2? right)
        (define a (digit:2-a right))
        (define b (digit:2-b right))
        (ft:deep new-total left inner (digit:3 a b value))]
       [else
        (define a (digit:3-a right))
        (define b (digit:3-b right))
        (define c (digit:3-c right))
        (ft:deep new-total left inner (digit:4 a b c value))])]))

(define (size-hdL:impl ft [depth 0])
  (cond
    [(ft:empty? ft) (values #f ft)]
    [(ft:single? ft)
     (define a (ft:single-a ft))
     (values a pvector-empty:impl)]
    [else
     (define left (ft:deep-left ft))
     (define inner (ft:deep-inner ft))
     (define right (ft:deep-right ft))
     (cond
       [(digit:1? left)
        (define a (digit:1-a left))
        (cond
          [(ft:empty? inner)
           (define empty-inner pvector-empty:impl)
           (cond
             [(digit:1? right)
              (values a (ft:single (digit:1-a right)))]
             [(digit:2? right)
              (define b (digit:2-a right))
              (define c (digit:2-b right))
              (values a
                      (ft:deep (+ (size:node b depth)
                                  (size:node c depth))
                               (digit:1 b)
                               empty-inner
                               (digit:1 c)))]
             [(digit:3? right)
              (define b (digit:3-a right))
              (define c (digit:3-b right))
              (define d (digit:3-c right))
              (values a
                      (ft:deep (+ (size:node b depth)
                                  (size:node c depth)
                                  (size:node d depth))
                               (digit:1 b)
                               empty-inner
                               (digit:2 c d)))]
             [else
              (define b (digit:4-a right))
              (define c (digit:4-b right))
              (define d (digit:4-c right))
              (define e (digit:4-d right))
              (values a
                      (ft:deep (+ (size:node b depth)
                                  (size:node c depth)
                                  (size:node d depth)
                                  (size:node e depth))
                               (digit:2 b c)
                               empty-inner
                               (digit:2 d e)))])]
          [else
           (define inner-depth (add1 depth))
           (define-values (lhs inner^) (size-hdL:impl inner inner-depth))
           (define-values (left-size left-digit)
             (if (node:2? lhs)
                 (values (node:2-v lhs)
                         (digit:2 (node:2-a lhs) (node:2-b lhs)))
                 (values (node:3-v lhs)
                         (digit:3 (node:3-a lhs) (node:3-b lhs) (node:3-c lhs)))))
           (define total (+ left-size
                           (size:ft inner^ inner-depth)
                           (size:digit right depth)))
           (values a (ft:deep total left-digit inner^ right))])]
       [(digit:2? left)
        (define a (digit:2-a left))
        (define b (digit:2-b left))
        (define left^ (digit:1 b))
        (define inner-depth (add1 depth))
        (define total (+ (size:digit left^ depth)
                         (size:ft inner inner-depth)
                         (size:digit right depth)))
        (values a (ft:deep total left^ inner right))]
       [(digit:3? left)
        (define a (digit:3-a left))
        (define b (digit:3-b left))
        (define c (digit:3-c left))
        (define left^ (digit:2 b c))
        (define inner-depth (add1 depth))
        (define total (+ (size:digit left^ depth)
                         (size:ft inner inner-depth)
                         (size:digit right depth)))
        (values a (ft:deep total left^ inner right))]
       [else
        (define a (digit:4-a left))
        (define b (digit:4-b left))
        (define c (digit:4-c left))
        (define d (digit:4-d left))
        (define left^ (digit:3 b c d))
        (define inner-depth (add1 depth))
        (define total (+ (size:digit left^ depth)
                         (size:ft inner inner-depth)
                         (size:digit right depth)))
        (values a (ft:deep total left^ inner right))])]))

(define (size-hdR:impl ft [depth 0])
  (cond
    [(ft:empty? ft) (values #f ft)]
    [(ft:single? ft)
     (define a (ft:single-a ft))
     (values a pvector-empty:impl)]
    [else
     (define left (ft:deep-left ft))
     (define inner (ft:deep-inner ft))
     (define right (ft:deep-right ft))
     (cond
       [(digit:1? right)
        (define a (digit:1-a right))
        (cond
          [(ft:empty? inner)
           (define empty-inner pvector-empty:impl)
           (cond
             [(digit:1? left)
              (values a (ft:single (digit:1-a left)))]
             [(digit:2? left)
              (define b (digit:2-a left))
              (define c (digit:2-b left))
              (values a
                      (ft:deep (+ (size:node b depth)
                                  (size:node c depth))
                               (digit:1 b)
                               empty-inner
                               (digit:1 c)))]
             [(digit:3? left)
              (define b (digit:3-a left))
              (define c (digit:3-b left))
              (define d (digit:3-c left))
              (values a
                      (ft:deep (+ (size:node b depth)
                                  (size:node c depth)
                                  (size:node d depth))
                               (digit:1 b)
                               empty-inner
                               (digit:2 c d)))]
             [else
              (define b (digit:4-a left))
              (define c (digit:4-b left))
              (define d (digit:4-c left))
              (define e (digit:4-d left))
              (values a
                      (ft:deep (+ (size:node b depth)
                                  (size:node c depth)
                                  (size:node d depth)
                                  (size:node e depth))
                               (digit:2 b c)
                               empty-inner
                               (digit:2 d e)))])]
          [else
           (define inner-depth (add1 depth))
           (define-values (rhs inner^) (size-hdR:impl inner inner-depth))
           (define-values (right-size right-digit)
             (if (node:2? rhs)
                 (values (node:2-v rhs)
                         (digit:2 (node:2-a rhs) (node:2-b rhs)))
                 (values (node:3-v rhs)
                         (digit:3 (node:3-a rhs) (node:3-b rhs) (node:3-c rhs)))))
           (define total (+ (size:digit left depth)
                           (size:ft inner^ inner-depth)
                           right-size))
           (values a (ft:deep total left inner^ right-digit))])]
       [(digit:2? right)
        (define a (digit:2-a right))
        (define b (digit:2-b right))
        (define right^ (digit:1 a))
        (define inner-depth (add1 depth))
        (define total (+ (size:digit left depth)
                         (size:ft inner inner-depth)
                         (size:digit right^ depth)))
        (values b (ft:deep total left inner right^))]
       [(digit:3? right)
        (define a (digit:3-a right))
        (define b (digit:3-b right))
        (define c (digit:3-c right))
        (define right^ (digit:2 a b))
        (define inner-depth (add1 depth))
        (define total (+ (size:digit left depth)
                         (size:ft inner inner-depth)
                         (size:digit right^ depth)))
        (values c (ft:deep total left inner right^))]
       [else
        (define a (digit:4-a right))
        (define b (digit:4-b right))
        (define c (digit:4-c right))
        (define d (digit:4-d right))
        (define right^ (digit:3 a b c))
        (define inner-depth (add1 depth))
        (define total (+ (size:digit left depth)
                         (size:ft inner inner-depth)
                         (size:digit right^ depth)))
        (values d (ft:deep total left inner right^))])]))

(define (size-build-ft0 lhs inner rhs depth)
  (define inner-depth (add1 depth))
  (ft:deep (+ (size:digit lhs depth)
              (size:ft inner inner-depth)
              (size:digit rhs depth))
           lhs
           inner
           rhs))

(define (size-list->nodes:impl nodes depth)
  (match nodes
    [`(,a ,b ,c ,d)
     (list (build-size-node2 a b depth)
           (build-size-node2 c d depth))]
    [`(,a ,b ,c)
     (list (build-size-node3 a b c depth))]
    [`(,a ,b)
     (list (build-size-node2 a b depth))]
    [`(,a ,b ,c ,rest ...)
     (cons (build-size-node3 a b c depth)
           (size-list->nodes:impl rest depth))]))

(define (size-concat:impl lhs rhs [depth 0])
  (match* (lhs rhs)
    [(_ (ft:empty)) lhs]
    [((ft:empty) _) rhs]
    [((ft:single a) _) (size-consL:impl rhs a depth)]
    [(_ (ft:single a)) (size-consR:impl lhs a depth)]
    [((ft:deep lhs-size lhs-left lhs-inner lhs-right)
      (ft:deep rhs-size rhs-left rhs-inner rhs-right))
     (define mid
       (digit-add-list lhs-right (digit-add-list rhs-left '())))
     (define mid-nodes (size-list->nodes:impl mid depth))
     (define inner-depth (add1 depth))
     (define lhs-inner^
       (for/fold ([inner lhs-inner]) ([node mid-nodes])
         (size-consR:impl inner node inner-depth)))
     (define inner^ (size-concat:impl lhs-inner^ rhs-inner inner-depth))
     (ft:deep (+ lhs-size rhs-size) lhs-left inner^ rhs-right)]))

(define (pvector-ref-node:impl node idx depth)
  (if (zero? depth)
      node
      (let ([sub-depth (sub1 depth)])
        (if (node:2? node)
            (let* ([a (node:2-a node)]
                   [b (node:2-b node)]
                   [a-size (size:node a sub-depth)])
              (if (< idx a-size)
                  (pvector-ref-node:impl a idx sub-depth)
                  (pvector-ref-node:impl b (- idx a-size) sub-depth)))
            (let* ([a (node:3-a node)]
                   [b (node:3-b node)]
                   [c (node:3-c node)]
                   [a-size (size:node a sub-depth)]
                   [b-size (size:node b sub-depth)]
                   [ab-size (+ a-size b-size)])
              (cond
                [(< idx a-size)
                 (pvector-ref-node:impl a idx sub-depth)]
                [(< idx ab-size)
                 (pvector-ref-node:impl b (- idx a-size) sub-depth)]
                [else
                 (pvector-ref-node:impl c (- idx ab-size) sub-depth)])))))
  ) ; define pvector-ref-node:impl

(define (pvector-ref-digit:impl digit idx depth)
  (cond
    [(digit:1? digit)
     (define a (digit:1-a digit))
     (pvector-ref-node:impl a idx depth)]
    [(digit:2? digit)
     (define a (digit:2-a digit))
     (define b (digit:2-b digit))
     (define a-size (size:node a depth))
     (if (< idx a-size)
         (pvector-ref-node:impl a idx depth)
         (pvector-ref-node:impl b (- idx a-size) depth)
         ) ; if: idx in a?
     ] ; cond branch: digit:2
    [(digit:3? digit)
     (define a (digit:3-a digit))
     (define b (digit:3-b digit))
     (define c (digit:3-c digit))
     (define a-size (size:node a depth))
     (define b-size (size:node b depth))
     (define ab-size (+ a-size b-size))
     (cond
       [(< idx a-size)
        (pvector-ref-node:impl a idx depth)]
       [(< idx ab-size)
        (pvector-ref-node:impl b (- idx a-size) depth)]
       [else
        (pvector-ref-node:impl c (- idx ab-size) depth)]
           ) ; cond: digit:3
     ] ; cond branch: digit:3
    [else
     (define a (digit:4-a digit))
     (define b (digit:4-b digit))
     (define c (digit:4-c digit))
     (define d (digit:4-d digit))
     (define a-size (size:node a depth))
     (define b-size (size:node b depth))
     (define c-size (size:node c depth))
     (define ab-size (+ a-size b-size))
     (define abc-size (+ ab-size c-size))
     (cond
       [(< idx a-size)
        (pvector-ref-node:impl a idx depth)]
       [(< idx ab-size)
        (pvector-ref-node:impl b (- idx a-size) depth)]
       [(< idx abc-size)
        (pvector-ref-node:impl c (- idx ab-size) depth)]
       [else
        (pvector-ref-node:impl d (- idx abc-size) depth)]
       ) ; cond: digit:4
     ] ; cond branch: digit:4
    ) ; cond: digit
  ) ; define pvector-ref-digit:impl

(define (pvector-ref:impl pv idx depth)
  (cond
    [(ft:single? pv)
     (pvector-ref-node:impl (ft:single-a pv) idx depth)]
    [(ft:deep? pv)
      (define lhs (ft:deep-left pv))
      (define inner (ft:deep-inner pv))
      (define rhs (ft:deep-right pv))
      (define inner-depth (add1 depth))
      (define lhs-measure (size:digit lhs depth))
      (define inner-size (size:ft inner inner-depth))
      (define inner-measure (+ lhs-measure inner-size))
      (cond
        [(< idx lhs-measure) (pvector-ref-digit:impl lhs idx depth)]
        [(< idx inner-measure) (pvector-ref:impl inner (- idx lhs-measure) inner-depth)]
        [else
         (define rhs-idx (- idx inner-measure))
         (pvector-ref-digit:impl rhs rhs-idx depth)]
        ) ; cond: idx region
      ] ; cond branch: ft:deep
    [else (assert-unreachable)]
    )) ; cond: pv

(define (pvector-ref pv idx)
  (cond
    [(< idx 0) (error 'pvector-ref "index out of bounds: ~a" idx)]
    [(>= idx (size:ft pv 0)) (error 'pvector-ref "index out of bounds: ~a" idx)]
    [else (pvector-ref:impl pv idx 0)]
    )) ; cond: pvector-ref guards

;; ========================================
;; Size-specialized set implementation
;; ========================================

(define (pvector-set-node:impl node idx value depth)
  (if (zero? depth)
      value
      (let ([sub-depth (sub1 depth)])
        (if (node:2? node)
            (let* ([a (node:2-a node)]
                   [b (node:2-b node)]
                   [a-size (size:node a sub-depth)])
              (if (< idx a-size)
                  (build-size-node2
                   (pvector-set-node:impl a idx value sub-depth)
                   b
                   sub-depth)
                  (build-size-node2
                   a
                   (pvector-set-node:impl b (- idx a-size) value sub-depth)
                   sub-depth)))
            (let* ([a (node:3-a node)]
                   [b (node:3-b node)]
                   [c (node:3-c node)]
                   [a-size (size:node a sub-depth)]
                   [b-size (size:node b sub-depth)]
                   [ab-size (+ a-size b-size)])
              (cond
                [(< idx a-size)
                 (build-size-node3
                  (pvector-set-node:impl a idx value sub-depth)
                  b
                  c
                  sub-depth)]
                [(< idx ab-size)
                 (build-size-node3
                  a
                  (pvector-set-node:impl b (- idx a-size) value sub-depth)
                  c
                  sub-depth)]
                [else
                 (build-size-node3
                  a
                  b
                  (pvector-set-node:impl c (- idx ab-size) value sub-depth)
                  sub-depth)])))))
  ) ; define pvector-set-node:impl

(define (pvector-set-digit:impl digit idx value depth)
  (cond
    [(digit:1? digit)
     (define a (digit:1-a digit))
     (digit:1 (pvector-set-node:impl a idx value depth))]
    [(digit:2? digit)
     (define a (digit:2-a digit))
     (define b (digit:2-b digit))
     (define a-size (size:node a depth))
     (if (< idx a-size)
         (digit:2 (pvector-set-node:impl a idx value depth) b)
         (digit:2 a (pvector-set-node:impl b (- idx a-size) value depth))
         ) ; if: idx in a?
     ] ; cond branch: digit:2
    [(digit:3? digit)
     (define a (digit:3-a digit))
     (define b (digit:3-b digit))
     (define c (digit:3-c digit))
     (define a-size (size:node a depth))
     (define b-size (size:node b depth))
     (define ab-size (+ a-size b-size))
     (cond
       [(< idx a-size)
        (digit:3 (pvector-set-node:impl a idx value depth) b c)]
       [(< idx ab-size)
        (digit:3 a (pvector-set-node:impl b (- idx a-size) value depth) c)]
       [else
        (digit:3 a b (pvector-set-node:impl c (- idx ab-size) value depth))]
       ) ; cond: digit:3
     ] ; cond branch: digit:3
    [else
     (define a (digit:4-a digit))
     (define b (digit:4-b digit))
     (define c (digit:4-c digit))
     (define d (digit:4-d digit))
     (define a-size (size:node a depth))
     (define b-size (size:node b depth))
     (define c-size (size:node c depth))
     (define ab-size (+ a-size b-size))
     (define abc-size (+ ab-size c-size))
     (cond
       [(< idx a-size)
        (digit:4 (pvector-set-node:impl a idx value depth) b c d)]
       [(< idx ab-size)
        (digit:4 a (pvector-set-node:impl b (- idx a-size) value depth) c d)]
       [(< idx abc-size)
        (digit:4 a b (pvector-set-node:impl c (- idx ab-size) value depth) d)]
       [else
        (digit:4 a b c (pvector-set-node:impl d (- idx abc-size) value depth))]
       ) ; cond: digit:4
     ] ; cond branch: digit:4
    ) ; cond: digit
  ) ; define pvector-set-digit:impl

(define (pvector-set:impl pv idx value depth)
  (cond
    [(ft:single? pv)
     (define r^ (pvector-set-node:impl (ft:single-a pv) idx value depth))
     (ft:single r^)]
    [(ft:deep? pv)
      (define v (ft:deep-v pv))
      (define lhs (ft:deep-left pv))
      (define inner (ft:deep-inner pv))
      (define rhs (ft:deep-right pv))
      (define inner-depth (add1 depth))
      (define lhs-measure (size:digit lhs depth))
      (define inner-size (size:ft inner inner-depth))
      (define inner-measure (+ lhs-measure inner-size))
      (cond
        [(< idx lhs-measure)
          (ft:deep v (pvector-set-digit:impl lhs idx value depth) inner rhs)]
        [(< idx inner-measure)
          (ft:deep v lhs (pvector-set:impl inner (- idx lhs-measure) value inner-depth) rhs)]
        [(< idx v)
          (define rhs-idx (- idx inner-measure))
          (define rhs^ (pvector-set-digit:impl rhs rhs-idx value depth))
          (ft:deep v lhs inner rhs^)]
        [else
         (error 'pvector-set "index out of bounds")]
        ) ; cond: idx region
      ] ; cond branch: ft:deep
    [else (assert-unreachable)]
    )) ; cond: pv

(define (pvector-set pv idx val)
  (cond
    [(< idx 0) (error 'pvector-set "index out of bounds: ~a" idx)]
    [(>= idx (size:ft pv 0)) (error 'pvector-set "index out of bounds: ~a" idx)]
    [else (pvector-set:impl pv idx val 0)]
    )) ; cond: pvector-set guards

;; Backwards compatibility aliases
(define pvector-ref/fast pvector-ref)
(define pvector-set/fast pvector-set)

;; Original index-based implementation (O(n log n) total)
(define (in-pvector/index pv)
  (make-do-sequence
   (lambda ()
     (initiate-sequence
      #:init-pos (cons pv 0)
      #:next-pos
      (lambda (x)
        (match-define (cons pv n) x)
        (cons pv (add1 n))
        ) ; lambda: next-pos
      #:pos->element
      (lambda (x)
        (match-define (cons pv n) x)
        (pvector-ref pv n)
        ) ; lambda: pos->element
      #:continue-with-pos?
      (lambda (x)
        (match-define (cons pv n) x)
        (define nt (size:ft pv 0))
        (< n nt)
        ) ; lambda: continue-with-pos?
      ) ; initiate-sequence
     ) ; lambda for make-do-sequence
   )) ; make-do-sequence

(define (make-sequence-entry item depth)
  (cons item depth))

(define (sequence-entry-item entry)
  (car entry))

(define (sequence-entry-depth entry)
  (cdr entry))

(define (push-node node depth stack)
  (if (zero? depth)
      (cons (make-sequence-entry node depth) stack)
      (let ([sub-depth (sub1 depth)])
        (match node
          [(node:2 _ x0 x1)
           (cons (make-sequence-entry x0 sub-depth)
                 (cons (make-sequence-entry x1 sub-depth) stack))]
          [(node:3 _ x0 x1 x2)
           (cons (make-sequence-entry x0 sub-depth)
                 (cons (make-sequence-entry x1 sub-depth)
                       (cons (make-sequence-entry x2 sub-depth) stack)))]))))

(define (push-node-reverse node depth stack)
  (if (zero? depth)
      (cons (make-sequence-entry node depth) stack)
      (let ([sub-depth (sub1 depth)])
        (match node
          [(node:2 _ x0 x1)
           (cons (make-sequence-entry x1 sub-depth)
                 (cons (make-sequence-entry x0 sub-depth) stack))]
          [(node:3 _ x0 x1 x2)
           (cons (make-sequence-entry x2 sub-depth)
                 (cons (make-sequence-entry x1 sub-depth)
                       (cons (make-sequence-entry x0 sub-depth) stack)))]))))

(define (push-digit digit depth stack)
  (match digit
    [(digit:1 x0) (push-node x0 depth stack)]
    [(digit:2 x0 x1)
     (push-node x0 depth
                (push-node x1 depth stack))]
    [(digit:3 x0 x1 x2)
     (push-node x0 depth
                (push-node x1 depth
                           (push-node x2 depth stack)))]
    [(digit:4 x0 x1 x2 x3)
     (push-node x0 depth
                (push-node x1 depth
                           (push-node x2 depth
                                      (push-node x3 depth stack))))]))

(define (push-digit-reverse digit depth stack)
  (match digit
    [(digit:1 x0) (push-node-reverse x0 depth stack)]
    [(digit:2 x0 x1)
     (push-node-reverse x1 depth
                        (push-node-reverse x0 depth stack))]
    [(digit:3 x0 x1 x2)
     (push-node-reverse x2 depth
                        (push-node-reverse x1 depth
                                           (push-node-reverse x0 depth stack)))]
    [(digit:4 x0 x1 x2 x3)
     (push-node-reverse x3 depth
                        (push-node-reverse x2 depth
                                           (push-node-reverse x1 depth
                                                              (push-node-reverse x0 depth stack))))]))

(define (push-ft ft depth stack)
  (match ft
    [(ft:empty) stack]
    [(ft:single node) (push-node node depth stack)]
    [(ft:deep _ left inner right)
     (push-digit left depth
                 (push-ft inner (add1 depth)
                          (push-digit right depth stack)))]))

(define (push-ft-reverse ft depth stack)
  (match ft
    [(ft:empty) stack]
    [(ft:single node) (push-node-reverse node depth stack)]
    [(ft:deep _ left inner right)
     (push-digit-reverse right depth
                         (push-ft-reverse inner (add1 depth)
                                          (push-digit-reverse left depth stack)))]))

(define (next-forward-stack stack)
  (let loop ([stack stack])
    (match stack
      ['() #f]
      [(cons entry rest)
       (define item (sequence-entry-item entry))
       (define depth (sequence-entry-depth entry))
       (cond
         [(zero? depth) (cons item rest)]
         [else (loop (push-node item depth rest))])])))

(define (next-reverse-stack stack)
  (let loop ([stack stack])
    (match stack
      ['() #f]
      [(cons entry rest)
       (define item (sequence-entry-item entry))
       (define depth (sequence-entry-depth entry))
       (cond
         [(zero? depth) (cons item rest)]
         [else (loop (push-node-reverse item depth rest))])])))

(define (in-pvector pv)
  (make-do-sequence
   (lambda ()
     (values car
             (lambda (state) (next-forward-stack (cdr state)))
             (next-forward-stack (push-ft pv 0 '()))
             values
             #f
             #f))))

(define (in-pvector-reverse pv)
  (make-do-sequence
   (lambda ()
     (values car
             (lambda (state) (next-reverse-stack (cdr state)))
             (next-reverse-stack (push-ft-reverse pv 0 '()))
             values
             #f
             #f))))

(define (pvector-for-each:impl proc pv)
  (define (each-node node depth)
    (match depth
      [0 (proc node)]
      [_
       (define sub-depth (sub1 depth))
       (match node
         [(node:2 _ x0 x1)
          (each-node x0 sub-depth)
          (each-node x1 sub-depth)]
         [(node:3 _ x0 x1 x2)
          (each-node x0 sub-depth)
          (each-node x1 sub-depth)
          (each-node x2 sub-depth)])]))
  (define (each-digit digit depth)
    (match digit
      [(digit:1 x0) (each-node x0 depth)]
      [(digit:2 x0 x1)
       (each-node x0 depth)
       (each-node x1 depth)]
      [(digit:3 x0 x1 x2)
       (each-node x0 depth)
       (each-node x1 depth)
       (each-node x2 depth)]
      [(digit:4 x0 x1 x2 x3)
       (each-node x0 depth)
       (each-node x1 depth)
       (each-node x2 depth)
       (each-node x3 depth)]))
  (define (each-ft ft depth)
    (match ft
      [(ft:empty) (void)]
      [(ft:single node) (each-node node depth)]
      [(ft:deep _ left inner right)
       (each-digit left depth)
       (each-ft inner (add1 depth))
       (each-digit right depth)]))
  (each-ft pv 0))

(define (pvector-length pv) (size:ft pv 0))

(define (pvector-split pv idx)
  (define-values (i l m r) (pvector-split:impl pv idx 0))
  (unless (zero? i) (assert-unreachable))
  (values l m r))

(define (pvector-split-digit:impl digit idx depth)
  (match digit
    [(digit:1 a)
     (cond
       [(< idx (size:node a depth))
        (values idx '() a '())
        ]
       [else
        (assert-unreachable)]
       ) ; cond: digit:1 split
     ] ; match branch: digit:1
    [(digit:2 a b)
     (define a-size (size:node a depth))
     (define b-size (size:node b depth))
     (cond
       [(< idx a-size)
        (values idx '() a (list b))
        ]
       [(< idx (+ a-size b-size))
        (values (- idx a-size) (list a) b '())
        ]
       [else
        (assert-unreachable)]
       ) ; cond: digit:2 split
     ] ; match branch: digit:2
    [(digit:3 a b c)
     (define a-size (size:node a depth))
     (define b-size (size:node b depth))
     (define c-size (size:node c depth))
     (cond
       [(< idx a-size)
        (values idx '() a (list b c))
        ]
       [(< idx (+ a-size b-size))
        (values (- idx a-size) (list a) b (list c))
        ]
       [(< idx (+ a-size b-size c-size))
        (values (- idx a-size b-size) (list a b) c '())
        ]
       [else
        (assert-unreachable)]
       ) ; cond: digit:3 split
     ] ; match branch: digit:3
    [(digit:4 a b c d)
     (define a-size (size:node a depth))
     (define b-size (size:node b depth))
     (define c-size (size:node c depth))
     (define d-size (size:node d depth))
     (cond
       [(< idx a-size)
        (values idx '() a (list b c d))
        ]
       [(< idx (+ a-size b-size))
        (values (- idx a-size) (list a) b (list c d))
        ]
       [(< idx (+ a-size b-size c-size))
        (values (- idx a-size b-size) (list a b) c (list d))
        ]
       [(< idx (+ a-size b-size c-size d-size))
        (values (- idx a-size b-size c-size) (list a b c) d '())
        ]
       [else
        (assert-unreachable)]
       ) ; cond: digit:4 split
     ] ; match branch: digit:4
    )) ; match: digit

(define (digit-list->ft lst depth)
  (match lst
    [`() (pvector-empty)]
    [`(,a) (ft:single a)]
    [`(,a ,b)
     (ft:deep
      (+ (size:node a depth)
         (size:node b depth)
         ) ; +: pair size
      (digit:1 a)
      (pvector-empty)
      (digit:1 b)
      ) ; ft:deep for 2 elems
      ] ; match branch: 2 elems
    [`(,a ,b ,c)
     (ft:deep
      (+ (size:node a depth)
         (size:node b depth)
         (size:node c depth)
         ) ; +: triple size
      (digit:1 a)
      (pvector-empty)
      (digit:2 b c)
      ) ; ft:deep for 3 elems
      ] ; match branch: 3 elems
    [`(,a ,b ,c ,d)
     (ft:deep
      (+ (size:node a depth)
         (size:node b depth)
         (size:node c depth)
         (size:node d depth)
         ) ; +: quad size
      (digit:2 a b)
      (pvector-empty)
      (digit:2 c d)
      ) ; ft:deep for 4 elems
      ] ; match branch: 4 elems
    )) ; match: digit-list->ft lst

(define (digit-list2->ft lst depth)
  (if (<= (length lst) 4)
      (digit-list->ft lst depth)
      (let ([v (for/fold ([i 0]) ([j lst])
                 (+ i (size:node j depth))
                 ) ; for/fold body: aggregate measure
               ]) ; binding: v
        (match lst
          [`(,a ,b ,c ,d ,e)
           (ft:deep v (digit:2 a b) pvector-empty:impl (digit:3 c d e))
           ]
          [`(,a ,b ,c ,d ,e ,f)
           (ft:deep v (digit:3 a b c) pvector-empty:impl (digit:3 d e f))
           ]
          [`(,a ,b ,c ,d ,e ,f ,g)
           (ft:deep v (digit:3 a b c) pvector-empty:impl (digit:4 d e f g))
           ]
          ) ; match: lst
        ) ; let: v
      ) ; if: digit-list2->ft
  ) ; define digit-list2->ft

(define (digit-list+ft->digit lst ft depth pop)
  (define inner-depth (add1 depth))
  (match lst
    ['()
      (define-values (h ft^) (pop ft inner-depth))
      ;; 从 inner finger tree 弹出的是更深一层的 node，
      ;; 必须先展开成当前 depth 对应的 digit，不能把 node 直接塞进 digit。
      (values (node->digit h inner-depth) ft^)]
    [`(,a) (values (digit:1 a) ft)]
    [`(,a ,b) (values (digit:2 a b) ft)]
    [`(,a ,b ,c) (values (digit:3 a b c) ft)]
    [`(,a ,b ,c ,d) (values (digit:4 a b c d) ft)]
    ) ; match: lst
  ) ; define digit-list+ft->digit

(define (node->digit node depth)
  (list->digit (node->list node) (sub1 depth))
  ) ; define node->digit

(define (left-digit+ft->ft digit ft depth)
  (define inner-depth (add1 depth))
  (match ft
    [(ft:empty)
     (define empty-list '())
     (define digit^ (digit-add-list digit empty-list))
     (digit-list->ft digit^ depth)]
    [_
     (define-values (r ft^) (size-hdR:impl ft inner-depth))
     (size-build-ft0 digit ft^ (node->digit r inner-depth) depth)]
    ) ; match: ft
  ) ; define left-digit+ft->ft

(define (right-digit+ft->ft digit ft depth)
  (define inner-depth (add1 depth))
  (match ft
    [(ft:empty)
     (define empty-list '())
     (define digit^ (digit-add-list digit empty-list))
     (digit-list->ft digit^ depth)]
    [_
     (define-values (l ft^) (size-hdL:impl ft inner-depth))
     (size-build-ft0 (node->digit l inner-depth) ft^ digit depth)]
    ) ; match: ft
  ) ; define right-digit+ft->ft

(define (pvector-split-node:impl node idx depth)
  (define sub-depth (sub1 depth))
  (match node
    [(node:2 v a b)
     (define a-size (size:node a sub-depth))
     (cond
       [(< idx a-size)
        (values idx
                '()
                a
                (list b)
                ) ; values: split node:2 left
        ] ; cond branch: idx in a
       [(< idx v)
        (define idx^ (- idx a-size))
        (values idx^
                (list a)
                b
                '()
                ) ; values: split node:2 right
        ] ; cond branch: idx in b
       [else (assert-unreachable)]
       ) ; cond: node:2
     ] ; match branch: node:2
    [(node:3 v a b c)
     (define a-size (size:node a sub-depth))
     (define b-size (size:node b sub-depth))
     (define ab-size (+ a-size b-size))
     (cond
       [(< idx a-size)
        (values idx
                '()
                a
                (list b c)
                ) ; values: split node:3 at first
        ] ; cond branch: idx in a
       [(< idx ab-size)
        (define idx^ (- idx a-size))
        (values idx^
                (list a)
                b
                (list c)
                ) ; values: split node:3 at second
        ] ; cond branch: idx in b
       [(< idx v)
        (define idx^ (- idx a-size b-size))
        (values idx^
                (list a b)
                c
                '()
                ) ; values: split node:3 at third
        ] ; cond branch: idx in c
       ) ; cond: node:3
     ] ; match branch: node:3
    ) ; match: node
  ) ; define pvector-split-node:impl

(define (pvector-split:impl pv idx depth)
  (match pv
    [(ft:empty) (assert-unreachable)]
    [(ft:single v)
     (cond
       [(>= idx (size:node v depth)) (assert-unreachable)]
       [else
        (define empty-left (pvector-empty))
        (define empty-right (pvector-empty))
        (values idx empty-left v empty-right)
        ] ; cond branch: idx in ft:single
       ) ; cond: ft:single
     ] ; match branch: ft:single
    [(ft:deep v lhs inner rhs)
     (define inner-depth (add1 depth))
     (define lhs-measure (size:digit lhs depth))
     (define inner-size (size:ft inner inner-depth))
     (define inner-measure (+ lhs-measure inner-size))
     (cond
       [(< idx lhs-measure)
        (define-values (idx^ l m r) (pvector-split-digit:impl lhs idx depth))
        (define left (digit-list->ft l depth))
        (match inner
          [(ft:empty)
           (define empty-list '())
           (define rhs-list (digit-add-list rhs empty-list))
           (define r+rhs (append r rhs-list))
           (define right^ (digit-list2->ft r+rhs depth))
           (values idx^ left m right^)
           ] ; match branch: ft:empty
          [_
           (define-values (right inner^) (digit-list+ft->digit r inner depth size-hdL:impl))
           (define right^ (size-build-ft0 right inner^ rhs depth))
           (values idx^ left m right^)
           ] ; match branch: inner non-empty
          ) ; match: inner after lhs split
        ] ; cond branch: idx in lhs
       [(< idx inner-measure)
        (define-values (rest-idx l m r)
          (pvector-split:impl inner (- idx lhs-measure) inner-depth))
        (define left (left-digit+ft->ft lhs l depth))
        (define right (right-digit+ft->ft rhs r depth))
        (define-values (idx^ l^ m^ r^) (pvector-split-node:impl m rest-idx inner-depth))
        ;; l^ / r^ 中的元素是当前 depth 层的 node，
        ;; 这里必须显式传入 depth，不能落回 consL/consR 的默认 0。
        (define left^
          (for/fold ([init left]) ([i l^])
            (size-consR:impl init i depth)
            ) ; for/fold: left^
          ) ; define left^
        (define right^
          (for/foldr ([init right]) ([i r^])
            (size-consL:impl init i depth)
            ) ; for/foldr: right^
          ) ; define right^
        (values idx^ left^ m^ right^)]
       [(< idx v)
        (define-values (idx^ l m r)
          (pvector-split-digit:impl rhs (- idx inner-measure) depth))
        (define right (digit-list->ft r depth))
        (match inner
          [(ft:empty)
            (values idx^
                    (digit-list2->ft (append (digit-add-list lhs '()) l) depth)
                    m
                    right)]
          [_
           ;; 右 digit 被拆开后，左半边必须接上 l；
           ;; 如果误用 r，会把右残片同时挂到左右两棵子树里。
           (define-values (left inner^) (digit-list+ft->digit l inner depth size-hdR:impl))
           (values idx^
                   (size-build-ft0 lhs inner^ left depth)
                   m
                   right)]
          ) ; match: inner after rhs split
        ] ; cond branch: idx in rhs
       [else (assert-unreachable)]
       ) ; cond: ft:deep
     ] ; match branch: ft:deep
    ) ; match: pv
  ) ; define pvector-split:impl

(define (pvector-split-left:impl pv idx depth)
  (match pv
    [(ft:empty) (assert-unreachable)]
    [(ft:single v)
     (cond
       [(>= idx (size:node v depth)) (assert-unreachable)]
       [else
        (define empty-left (pvector-empty))
        (values idx empty-left v)
        ] ; cond branch: idx in ft:single
       ) ; cond: ft:single
     ] ; match branch: ft:single
    [(ft:deep v lhs inner rhs)
     (define inner-depth (add1 depth))
     (define lhs-measure (size:digit lhs depth))
     (define inner-size (size:ft inner inner-depth))
     (define inner-measure (+ lhs-measure inner-size))
     (cond
       [(< idx lhs-measure)
        (define-values (idx^ l m r) (pvector-split-digit:impl lhs idx depth))
        (define left (digit-list->ft l depth))
        (values idx^ left m)]
       [(< idx inner-measure)
        (define-values (rest-idx l m)
          (pvector-split-left:impl inner (- idx lhs-measure) inner-depth))
        (define left (left-digit+ft->ft lhs l depth))
        (define-values (idx^ l^ m^ r^) (pvector-split-node:impl m rest-idx inner-depth))
        (define left^
          (for/fold ([init left]) ([i l^])
            (size-consR:impl init i depth)
            ) ; for/fold: left^
          ) ; define left^
        (values idx^ left^ m^)]
       [(< idx v)
        (define-values (idx^ l m r)
          (pvector-split-digit:impl rhs (- idx inner-measure) depth))
        (define left
          (match inner
            [(ft:empty)
             (digit-list2->ft (append (digit-add-list lhs '()) l) depth)]
            [_
             (define-values (left-digit inner^) (digit-list+ft->digit l inner depth size-hdR:impl))
             (size-build-ft0 lhs inner^ left-digit depth)]))
        (values idx^ left m)]
       [else (assert-unreachable)]
       ) ; cond: ft:deep
     ] ; match branch: ft:deep
    ) ; match: pv
  ) ; define pvector-split-left:impl

(define (pvector-split-right:impl pv idx depth)
  (match pv
    [(ft:empty) (assert-unreachable)]
    [(ft:single v)
     (cond
       [(>= idx (size:node v depth)) (assert-unreachable)]
       [else
        (define empty-right (pvector-empty))
        (values idx v empty-right)
        ] ; cond branch: idx in ft:single
       ) ; cond: ft:single
     ] ; match branch: ft:single
    [(ft:deep v lhs inner rhs)
     (define inner-depth (add1 depth))
     (define lhs-measure (size:digit lhs depth))
     (define inner-size (size:ft inner inner-depth))
     (define inner-measure (+ lhs-measure inner-size))
     (cond
       [(< idx lhs-measure)
        (define-values (idx^ l m r) (pvector-split-digit:impl lhs idx depth))
        (define right
          (match inner
            [(ft:empty)
             (define rhs-list (digit-add-list rhs '()))
             (digit-list2->ft (append r rhs-list) depth)]
            [_
             (define-values (right-digit inner^) (digit-list+ft->digit r inner depth size-hdL:impl))
             (size-build-ft0 right-digit inner^ rhs depth)]))
        (values idx^ m right)]
       [(< idx inner-measure)
        (define-values (rest-idx m r)
          (pvector-split-right:impl inner (- idx lhs-measure) inner-depth))
        (define right (right-digit+ft->ft rhs r depth))
        (define-values (idx^ l^ m^ r^) (pvector-split-node:impl m rest-idx inner-depth))
        (define right^
          (for/foldr ([init right]) ([i r^])
            (size-consL:impl init i depth)
            ) ; for/foldr: right^
          ) ; define right^
        (values idx^ m^ right^)]
       [(< idx v)
        (define-values (idx^ l m r)
          (pvector-split-digit:impl rhs (- idx inner-measure) depth))
        (define right (digit-list->ft r depth))
        (values idx^ m right)]
       [else (assert-unreachable)]
       ) ; cond: ft:deep
     ] ; match branch: ft:deep
    ) ; match: pv
  ) ; define pvector-split-right:impl

(define (vector->node3vector vec start len depth)
  (define new-length (quotient len 3))
  (define new-vec (make-vector new-length))
  (for ([i (in-range new-length)])
    (define offset (* 3 i))
    (define idx0 (+ start offset))
    (define idx1 (+ start 1 offset))
    (define idx2 (+ start 2 offset))
    (define x0 (vector-ref vec idx0))
    (define x1 (vector-ref vec idx1))
    (define x2 (vector-ref vec idx2))
    (vector-set!
     new-vec
     i
     (node:3 (+
              (size:node x0 depth)
             (size:node x1 depth)
             (size:node x2 depth)
              ) ; +: node:3 measure
             x0
             x1
             x2)
     )) ; vector-set! loop body
  new-vec)

(define (vector->pvector:impl vec sz depth)
  (define vec-len (vector-length vec))
  (define inner-depth (add1 depth))
  (cond
    ;; Fast-path small vectors (including empty) before touching vec[0] —
    ;; the `head0` binding below is only needed for the general path.
    [(<= vec-len 8) (small-vector->pvector:impl vec depth)]
    [else
     (define head0 (vector-ref vec 0))
      (match (modulo vec-len 3)
        [0
          (define lhs
            (digit:3
             (vector-ref vec 0)
             (vector-ref vec 1)
             (vector-ref vec 2)
             ) ; digit:3 lhs constructor
            ) ; define lhs
          (define rhs
            (digit:3
             (vector-ref vec (- vec-len 3))
             (vector-ref vec (- vec-len 2))
             (vector-ref vec (- vec-len 1))
             ) ; digit:3 rhs constructor
            ) ; define rhs
          (define head0-size (size:node head0 depth))
          (define sub-sz (* 6 head0-size))
          (define mid (vector->node3vector vec 3 (- vec-len 6) depth))
          (ft:deep sz lhs (vector->pvector:impl mid (- sz sub-sz) inner-depth) rhs)]
        [1
          (define lhs
            (digit:4
             (vector-ref vec 0)
             (vector-ref vec 1)
             (vector-ref vec 2)
             (vector-ref vec 3)
             ) ; digit:4 lhs constructor (case 1)
            ) ; define lhs
          (define rhs
            (digit:3
             (vector-ref vec (- vec-len 3))
             (vector-ref vec (- vec-len 2))
             (vector-ref vec (- vec-len 1))
             ) ; digit:3 rhs constructor (case 1)
            ) ; define rhs
          (define head0-size (size:node head0 depth))
          (define sub-sz (* 7 head0-size))
          (define mid (vector->node3vector vec 4 (- vec-len 7) depth))
          (ft:deep sz lhs (vector->pvector:impl mid (- sz sub-sz) inner-depth) rhs)]
        [2
          (define lhs
            (digit:4
             (vector-ref vec 0)
             (vector-ref vec 1)
             (vector-ref vec 2)
             (vector-ref vec 3)
             ) ; digit:4 lhs constructor (case 2)
            ) ; define lhs
          (define rhs
            (digit:4
             (vector-ref vec (- vec-len 4))
             (vector-ref vec (- vec-len 3))
             (vector-ref vec (- vec-len 2))
             (vector-ref vec (- vec-len 1))
             ) ; digit:4 rhs constructor (case 2)
            ) ; define rhs
          (define head0-size (size:node head0 depth))
          (define sub-sz (* 8 head0-size))
          (define mid (vector->node3vector vec 4 (- vec-len 8) depth))
          (ft:deep sz lhs (vector->pvector:impl mid (- sz sub-sz) inner-depth) rhs)]
        ) ; match: modulo vec-len 3
      ] ; cond branch: else
    ) ; cond: vector->pvector:impl
  ) ; define vector->pvector:impl

(define (small-vector->pvector:impl vec depth)
  (define vec-seq (in-vector vec))
  (define v
    (for/fold ([v 0]) ([k vec-seq])
      (+ v (size:node k depth))
      ) ; for/fold: compute small-vector size
    ) ; define v
  (match vec
    [(vector) pvector-empty:impl]
    [(vector x0) (ft:single x0)]
    [(vector x0 x1)
     (ft:deep v (digit:1 x0) (pvector-empty) (digit:1 x1))
     ]
    [(vector x0 x1 x2)
     (ft:deep v (digit:1 x0) (pvector-empty) (digit:2 x1 x2))
     ]
    [(vector x0 x1 x2 x3)
     (ft:deep v (digit:2 x0 x1) (pvector-empty) (digit:2 x2 x3))
     ]
    [(vector x0 x1 x2 x3 x4)
     (ft:deep v (digit:2 x0 x1) (pvector-empty) (digit:3 x2 x3 x4))
     ]
    [(vector x0 x1 x2 x3 x4 x5)
     (ft:deep v (digit:3 x0 x1 x2) (pvector-empty) (digit:3 x3 x4 x5))
     ]
    [(vector x0 x1 x2 x3 x4 x5 x6)
     (ft:deep v (digit:3 x0 x1 x2) (pvector-empty) (digit:4 x3 x4 x5 x6))
     ]
    [(vector x0 x1 x2 x3 x4 x5 x6 x7)
     (define empty-mid (pvector-empty))
     (ft:deep v (digit:4 x0 x1 x2 x3) empty-mid (digit:4 x4 x5 x6 x7))
     ] ; match branch: 8 elements
    ) ; match: vec
  ) ; define small-vector->pvector:impl

(define (vector->pvector vec)
  (vector->pvector:impl vec (vector-length vec) 0))

(define (pvector->vector pv)
  (define n (pvector-length pv))
  (define vec (make-vector n))
  (define i 0)
  (pvector-for-each:impl
   (lambda (value)
     (vector-set! vec i value)
     (set! i (add1 i)))
   pv)
  vec
  ) ; define pvector->vector

(define (pvector-copy pv start end)
  (define len (- end start))
  (define pv-len (pvector-length pv))
  (cond
    [(= len 0) (pvector-empty)]
    [(and (= start 0) (= end pv-len))
     pv]
    [(= start 0)
     (pvector-take pv end)]
    [(= end pv-len)
     (pvector-drop pv start)]
    [else
     (pvector-drop (pvector-take pv end) start)]
    ) ; cond: pvector-copy
  ) ; define pvector-copy

(define (pvector-empty? pv)
  (match pv
    [(ft:empty) #t]
    [_ #f]
    ) ; match: pv
  ) ; define pvector-empty?

(define (pvector-take pv pos)
  (cond
    [(= pos 0) (pvector-empty)]
    [(= pos (pvector-length pv)) pv]
    [else
     (match-define-values (i l _) (pvector-split-left:impl pv pos 0))
     (unless (zero? i) (assert-unreachable))
     l]
    ) ; cond: pvector-take
  ) ; define pvector-take

(define (pvector-take-right pv pos)
  (define n (pvector-length pv))
  (pvector-drop pv (- n pos))
  ) ; define pvector-take-right

(define (pvector-drop pv pos)
  (define pos-1 (sub1 pos))
  (cond
    [(= pos 0) pv]
    [(= pos (pvector-length pv)) (pvector-empty)]
    [else
     (match-define-values (i _ r) (pvector-split-right:impl pv pos-1 0))
     (unless (zero? i) (assert-unreachable))
     r]
    ) ; cond: pvector-drop
  ) ; define pvector-drop

(define (pvector-drop-right pv pos)
  (define n (pvector-length pv))
  (pvector-take pv (- n pos))
  ) ; define pvector-drop-right

(define (pvector-split-at pv pos)
  (cond
    [(= pos 0)
     (define empty-left (pvector-empty))
     (values empty-left pv)
     ] ; cond branch: split at start
    [(= pos (pvector-length pv))
     (define empty-right (pvector-empty))
     (values pv empty-right)
     ] ; cond branch: split at end
    [else
     (match-define-values (l m r) (pvector-split pv (sub1 pos)))
     (define left^ (pvector-cons-right l m))
     (values left^ r)
     ] ; cond branch: split in middle
    ) ; cond: pvector-split-at
  ) ; define pvector-split-at

(define (pvector-split-at-right pv pos)
  (define n (pvector-length pv))
  (define split-pos (- n pos))
  (match-define-values (l r) (pvector-split-at pv split-pos))
  (values r l)
  ) ; define: pvector-split-at-right

(define pvector? finger-tree?/c)

(define (pvector-insert-ft:impl ft idx value depth)
  (match ft
    [(ft:single x)
     (define-values (x0 x1) (pvector-insert-node:impl x idx value depth))
     (if x1
         (ft:deep (add1 (size:ft ft depth)) (digit:1 x0) pvector-empty:impl (digit:1 x1))
         (ft:single x0)
         ) ; if: node split?
     ] ; match branch: ft:single
    [(ft:deep o left inner right)
     (define inner-depth (add1 depth))
     (define left-size (size:digit left depth))
     (define inner-size (size:ft inner inner-depth))
     (define left-inner-size (+ left-size inner-size))
     (cond
       [(<= left-inner-size idx)
        (define right^ (pvector-insert-digit:impl right (- idx left-inner-size) value depth))
        (match right^
          [`(,x0 ,x1 ,x2, x3 ,x4)
           (define right-pop (build-size-node3 x0 x1 x2 depth))
           (define inner^ (size-consR:impl inner right-pop inner-depth))
           (ft:deep (add1 o) left inner^ (digit:2 x3 x4))
           ] ; match branch: overflow right digit
          [_
           (define right-digit (list->digit right^ depth))
           (ft:deep (add1 o) left inner right-digit)
           ]
          ) ; match: right^
       ] ; cond branch: idx in right span
       [(<= left-size idx)
        (define inner^ (pvector-insert-ft:impl inner (- idx left-size) value inner-depth))
        (ft:deep (add1 o) left inner^ right)]
       [else
        (define left^ (pvector-insert-digit:impl left idx value depth))
        (match left^
         [`(,x0 ,x1 ,x2, x3 ,x4)
           (define left-pop (build-size-node3 x2 x3 x4 depth))
           (define inner-level (add1 depth))
           (define inner^ (size-consL:impl inner left-pop inner-level))
           (ft:deep (add1 o) (digit:2 x0 x1) inner^ right)]
          [_
           (define left-digit (list->digit left^ depth))
           (ft:deep (add1 o) left-digit inner right)
           ]
          ) ; match: left^
        ] ; cond branch: idx in left span
       ) ; cond: ft:deep
     ] ; match branch: ft:deep
    ) ; match: ft
  ) ; define pvector-insert-ft:impl

(define (pvector-insert-digit:impl digit idx value depth)
  (define l (digit->list digit))
  (match-define-values (r _ i)
    (for/fold ([rst '()] [idx idx] [ignore #f]) ([i l])
      (define s (size:node i depth))
      (cond
        [ignore
          (values (cons i rst) idx ignore)]
        [(<= s idx)
          (values (cons i rst) (- idx s) ignore)]
        [else
          (define-values (x0 x1) (pvector-insert-node:impl i idx value depth))
          (if x1
            (values (cons x1 (cons x0 rst)) idx #t)
            (values (cons x0 rst) idx #t)
            ) ; if: x1 split?
          ] ; cond branch: insert here
        ) ; cond: fold step
      ) ; for/fold: digit traversal
    ) ; match-define-values source
  (unless i (assert-unreachable))
  (reverse r))

(define (pvector-insert-node:impl node idx value depth)
  (match depth
    [0 (values value node)]
    [_
     (define sub-depth (sub1 depth))
     (match node
       [(node:2 i x0 x1)
        (define x0-size (size:node x0 sub-depth))
        (cond
          [(<= x0-size idx)
           (define-values (x1^ x2^)
             (pvector-insert-node:impl x1 (- idx x0-size) value sub-depth))
           (values
            (if x2^
                (node:3 (add1 i) x0 x1^ x2^)
                (node:2 (add1 i) x0 x1^))
            #f)]
          [else
           (define-values (x0^ x1^)
             (pvector-insert-node:impl x0 idx value sub-depth))
           (values
            (if x1^
                (node:3 (add1 i) x0^ x1^ x1)
                (node:2 (add1 i) x0^ x1))
            #f)]
          ) ; cond: node:2
       ] ; match: node:2
       [(node:3 i x0 x1 x2)
        (define x0-size (size:node x0 sub-depth))
        (define x1-size (size:node x1 sub-depth))
        (define x0-x1-size (+ x0-size x1-size))
        (cond
          [(<= x0-x1-size idx)
           (define-values (x2^ x3^)
             (pvector-insert-node:impl x2 (- idx x0-x1-size) value sub-depth))
           (if x3^
               (values
                (node:2 x0-x1-size x0 x1)
               (node:2 (+ (size:node x2^ sub-depth)
                           (size:node x3^ sub-depth))
                        x2^
                        x3^)
                ) ; values RHS node close (branch 1)
               (values
                (node:3 (+ i 1) x0 x1 x2^)
                #f
                ) ; values: node:3 branch 1 fallback
               ) ; if: x3^ split
               ] ; cond branch: insert into x2
          [(<= x0-size idx)
           (define-values (x1^ x2^)
             (pvector-insert-node:impl x1 (- idx x0-size) value sub-depth))
           (if x2^
               (values
                (node:2 (+ x0-size (size:node x1^ sub-depth))
                        x0
                        x1^)
                (node:2 (+ (size:node x2^ sub-depth)
                           (size:node x2 sub-depth))
                        x2^
                        x2)
               ) ; values RHS node close (branch 2)
               ;; 中间子节点未分裂时，必须保留更新后的 x1^，
               ;; 否则会把旧 x1 留下并污染右侧结构。
               (values
                (node:3 (+ i 1) x0 x1^ x2)
                #f
                ) ; values: node:3 branch 2 fallback
               ) ; if: x2^ split
               ] ; cond branch: insert into x1
          [else
           (define-values (x0^ x1^)
             (pvector-insert-node:impl x0 idx value sub-depth))
           (if x1^
               (values
                (node:2 (+ (size:node x0^ sub-depth)
                           (size:node x1^ sub-depth))
                        x0^
                        x1^)
                (node:2 (+ (size:node x1 sub-depth)
                           (size:node x2 sub-depth))
                        x1
                        x2)
                ) ; values RHS node close (branch 3)
               (values
                (node:3 (+ i 1) x0^ x1 x2)
                #f
                ) ; values: node:3 branch 3 fallback
               ) ; if: x1^ split
               ] ; cond branch: insert into x0
          ) ; cond: node:3
        ] ; match: node:3
       ) ; match node
     ] ; match depth > 0
    ) ; match depth
  ) ; define pvector-insert-node:impl

(define (pvector-insert ft idx value)
  (define ft-size (size:ft ft 0))
  (cond
    [(= ft-size idx) (size-consR:impl ft value 0)]
    [(< ft-size idx) (error 'ArgumentError "insert invalid pos ~a in ft (sz ~a)" idx ft-size)]
    [else (pvector-insert-ft:impl ft idx value 0)]
    ) ; cond: pvector-insert
  ) ; define pvector-insert

(define (pvector-delete ft idx)
  (match-define-values (l v r) (pvector-split ft idx))
  (values (pvector-append l r) v)
  ) ; define pvector-delete

;; New functions: list conversion
(define (list->pvector lst)
  (define vec (list->vector lst))
  (vector->pvector vec)
  ) ; define list->pvector

(define (pvector->list pv)
  (define elems '())
  (pvector-for-each:impl
   (lambda (v)
     (set! elems (cons v elems)))
   pv)
  (reverse elems)
  ) ; define pvector->list

;; ========================================
;; Indexed sequence (like in-indexed for lists)
;; ========================================

(define (in-pvector-indexed pv)
  (define seq (in-pvector pv))
  (in-indexed seq)
  ) ; define in-pvector-indexed

;; ========================================
;; for/pvector comprehension
;; ========================================

(require (for-syntax racket/base))

(define pvector-empty/runtime (pvector-empty))

(define-syntax (for/pvector stx)
  (syntax-case stx ()
    [(_ clauses body ...)
     #'(let ([init-pv pvector-empty/runtime])
         (for/fold ([pv init-pv])
           clauses
           (pvector-cons-right
            pv
            (let ()
              body ...
              ) ; let: comprehension body
            ) ; pvector-cons-right
           ) ; for/fold
         ) ; let: init-pv
     ] ; syntax-case branch: for/pvector
    ) ; syntax-case: for/pvector
  ) ; define-syntax for/pvector

(define-syntax (for*/pvector stx)
  (syntax-case stx ()
    [(_ clauses body ...)
     #'(let ([init-pv pvector-empty/runtime])
         (for*/fold ([pv init-pv])
           clauses
           (pvector-cons-right
            pv
            (let ()
              body ...
              ) ; let: comprehension body
            ) ; pvector-cons-right
           ) ; for*/fold
         ) ; let: init-pv
     ] ; syntax-case branch: for*/pvector
    ) ; syntax-case: for*/pvector
  ) ; define-syntax for*/pvector

;; ========================================
;; Match expander for pvector
;; ========================================

(require racket/match)

;; Match empty or specific elements: (pvector) or (pvector a b c)
(define-match-expander pvector
  (lambda (stx)
    (syntax-case stx ()
      [(_) #'(? pvector-empty?)]
      [(_ pat ...)
       #'(? pvector?
            (app pvector->list (list pat ...))
            ) ; ?: pvector matcher
       ] ; syntax-case branch: pvector matcher
      ) ; syntax-case: pvector matcher
    ) ; lambda: pvector matcher
  (lambda (stx)
    (syntax-case stx ()
      [(_ elem ...)
       #'(list->pvector
          (list elem ...)
          ) ; list->pvector ctor args
       ] ; syntax-case branch: pvector constructor
      [_ #'list->pvector]
      ) ; syntax-case: pvector constructor
    ) ; lambda: pvector constructor
  ) ; define-match-expander pvector

;; Match with rest: (pvector* a b . rest)
(define-match-expander pvector*
  (lambda (stx)
    (syntax-case stx ()
      [(_ pat ... . rest-pat)
       #'(? pvector?
            (app pvector->list (list-rest pat ... rest-pat))
            ) ; ?: pvector* matcher
       ] ; syntax-case branch: pvector* matcher
      ) ; syntax-case: pvector* matcher
    ) ; lambda: pvector* matcher
  ) ; define-match-expander pvector*

;; ========================================
;; Advanced match expander: pvector**
;; Supports: (pvector** (pvector n x) elem1 elem2 (pvector _ y))
;; - (pvector _ pv-pat): REST match, takes all remaining elements (only ONE allowed)
;; - (pvector n pv-pat): FIXED match, n is already-bound variable, takes n elements
;; - other patterns: single element match
;; ========================================

(require (for-syntax racket/base racket/syntax))
(require (for-syntax racket/list))

;; Helper: check if a syntax is a pvector segment pattern
(define-for-syntax (pvector-segment? stx)
  (syntax-case stx (pvector)
    [(pvector _ _) #t]
    [_ #f]
    ) ; syntax-case: pvector-segment?
  ) ; define-for-syntax pvector-segment?

;; Helper: check if length pattern is `_` (rest match)
(define-for-syntax (rest-match? len-stx)
  (and (identifier? len-stx)
       (free-identifier=? len-stx #'_)
       ) ; and: rest-match?
  ) ; define-for-syntax rest-match?

;; Helper: parse segments into (prefix-var? fixed-pats suffix-var?)
(define-for-syntax (parse-pvector**-segments segs)
  (define seg-list (syntax->list segs))
  (when (null? seg-list)
    (raise-syntax-error 'pvector** "empty pattern" segs))

  ;; Check if first segment is pvector (prefix)
  (define-values (prefix-var rest-segs)
    (if (pvector-segment? (car seg-list))
        (values (car seg-list) (cdr seg-list))
        (values #f seg-list)
        ) ; if: prefix segment
    ) ; define-values: prefix-var/rest-segs

  ;; Check if last segment is pvector (suffix)
  (define-values (suffix-var middle-segs)
    (if (and (not (null? rest-segs))
             (let ()
               (define last-seg (last rest-segs))
               (pvector-segment? last-seg)
               ) ; let: suffix segment predicate
             )
        (let ()
          (define last-seg (last rest-segs))
          (values last-seg (drop-right rest-segs 1))
          ) ; let: suffix values
        (values #f rest-segs)
        ) ; if: suffix segment
    ) ; define-values: suffix-var/middle-segs

  ;; Check for multiple rest matches
  (define prefix-is-rest?
    (and prefix-var
         (syntax-case prefix-var (pvector)
           [(pvector len _) (rest-match? #'len)]
           [_ #f]
           ) ; syntax-case: prefix-var
         ) ; and: prefix-is-rest?
    ) ; define prefix-is-rest?
  (define suffix-is-rest?
    (and suffix-var
         (syntax-case suffix-var (pvector)
           [(pvector len _) (rest-match? #'len)]
           [_ #f]
           ) ; syntax-case: suffix-var
         ) ; and: suffix-is-rest?
    ) ; define suffix-is-rest?

  (when (and prefix-is-rest? suffix-is-rest?)
    (raise-syntax-error 'pvector**
      "cannot have two rest matches (pvector _ ...); only one allowed"
      segs))

  (values prefix-var middle-segs suffix-var)
  ) ; define-for-syntax parse-pvector**-segments

;; Generate the match code
(define-for-syntax (generate-pvector**-match input-stx segments)
  (define-values (prefix-var fixed-pats suffix-var)
    (parse-pvector**-segments segments))
  (define fixed-count (length fixed-pats))

  (with-syntax ([fixed-n fixed-count])
    (cond
      ;; No variable segments - just match fixed elements
      [(and (not prefix-var) (not suffix-var))
       (with-syntax ([(pat ...) fixed-pats])
         #'(and
            (? pvector?)
            (? (lambda (pv)
                 (define len (pvector-length pv))
                 (= len fixed-n)
                 ) ; lambda: fixed length check
               ) ; ? predicate: fixed length
            (app
             pvector->list
             (list pat ...)
             ) ; app: fixed pattern list
            ) ; and: no variable segments
         ) ; with-syntax: fixed-only branch
       ] ; cond branch: fixed-only

      ;; Only prefix variable segment
      [(and prefix-var (not suffix-var))
       (syntax-case prefix-var (pvector)
         [(pvector len-pat pv-pat)
          (with-syntax ([(fixed-pat ...) fixed-pats])
            (if (rest-match? #'len-pat)
                ;; REST match: prefix takes all remaining after fixed
                #'(? pvector?
                     (app (lambda (pv)
                            (define len (pvector-length pv))
                            (define prefix-len (- len fixed-n))
                            (if (>= prefix-len 0)
                                (let ()
                                  (define suffix-pv (pvector-drop pv prefix-len))
                                  (list (pvector-take pv prefix-len)
                                        (pvector->list suffix-pv))
                                  ) ; let: rest prefix split
                                #f))
                          (let ()
                            (define fixed-list-pat (list fixed-pat ...))
                            (list pv-pat fixed-list-pat)
                            ) ; let: app result pattern
                          )
                     ) ; ?: rest prefix match
                ;; FIXED match: prefix takes exactly len-pat elements
                #'(? pvector?
                     (app (lambda (pv)
                            (define len (pvector-length pv))
                            (define expect-len (+ len-pat fixed-n))
                            (if (and (>= len-pat 0)
                                     (= len expect-len))
                                (let ()
                                  (define suffix-pv (pvector-drop pv len-pat))
                                  (list (pvector-take pv len-pat)
                                        (pvector->list suffix-pv))
                                  ) ; let: fixed prefix split
                                #f))
                          (let ()
                            (define fixed-list-pat (list fixed-pat ...))
                            (list pv-pat fixed-list-pat)
                            ) ; let: app result pattern
                          )
                      ) ; ?: fixed prefix match
                ) ; if: rest/fixed prefix
            ) ; with-syntax: fixed-pat for prefix branch
          ] ; syntax-case branch: prefix-var
        ) ; syntax-case: prefix-var
       ] ; cond branch: only prefix var

      ;; Only suffix variable segment
      [(and (not prefix-var) suffix-var)
       (syntax-case suffix-var (pvector)
         [(pvector len-pat pv-pat)
          (with-syntax ([(fixed-pat ...) fixed-pats])
            (if (rest-match? #'len-pat)
                ;; REST match: suffix takes all remaining after fixed
                #'(? pvector?
                     (app (lambda (pv)
                            (define len (pvector-length pv))
                            (define suffix-len (- len fixed-n))
                            (if (>= suffix-len 0)
                                (list (pvector->list (pvector-take pv fixed-n))
                                      (pvector-drop pv fixed-n))
                                #f))
                          (let ()
                            (define fixed-list-pat (list fixed-pat ...))
                            (list fixed-list-pat pv-pat)
                            ) ; let: app result pattern
                          )
                     ) ; ?: rest suffix match
                ;; FIXED match: suffix takes exactly len-pat elements
                #'(? pvector?
                     (app (lambda (pv)
                            (define len (pvector-length pv))
                            (define expect-len (+ fixed-n len-pat))
                            (if (and (>= len-pat 0)
                                     (= len expect-len))
                                (list (pvector->list (pvector-take pv fixed-n))
                                      (pvector-drop pv fixed-n))
                                #f))
                          (let ()
                            (define fixed-list-pat (list fixed-pat ...))
                            (list fixed-list-pat pv-pat)
                            ) ; let: app result pattern
                          )
                      ) ; ?: fixed suffix match
                ) ; if: rest/fixed suffix
            ) ; with-syntax: fixed-pat for suffix branch
          ] ; syntax-case branch: suffix-var
        ) ; syntax-case: suffix-var
       ] ; cond branch: only suffix var

      ;; Both prefix and suffix variable segments
      [else
       (syntax-case prefix-var (pvector)
         [(pvector prefix-len-pat prefix-pv-pat)
          (syntax-case suffix-var (pvector)
            [(pvector suffix-len-pat suffix-pv-pat)
             (with-syntax ([(fixed-pat ...) fixed-pats])
               (cond
                 ;; Suffix is REST, prefix is FIXED
                 [(rest-match? #'suffix-len-pat)
                  #'(? pvector?
                       (app (lambda (pv)
                              (define len (pvector-length pv))
                              (define suffix-len (- len fixed-n prefix-len-pat))
                              (if (and (>= prefix-len-pat 0) (>= suffix-len 0))
                                  (let ()
                                    (define fixed-end (+ prefix-len-pat fixed-n))
                                    (define fixed-pv
                                      (pvector-copy pv prefix-len-pat fixed-end))
                                    (define suffix-pv (pvector-drop pv fixed-end))
                                    (list (pvector-take pv prefix-len-pat)
                                          (pvector->list fixed-pv)
                                          suffix-pv)
                                    ) ; let: fixed-prefix rest-suffix
                                  #f))
                            (let ()
                              (define fixed-list-pat (list fixed-pat ...))
                              (list prefix-pv-pat fixed-list-pat suffix-pv-pat)
                              ) ; let: app result pattern
                            )
                       ) ; ?: suffix rest (prefix fixed)
                       ] ; cond branch: suffix rest
                 ;; Prefix is REST, suffix is FIXED
                 [(rest-match? #'prefix-len-pat)
                  #'(? pvector?
                       (app (lambda (pv)
                              (define len (pvector-length pv))
                              (define prefix-len (- len fixed-n suffix-len-pat))
                              (if (and (>= suffix-len-pat 0) (>= prefix-len 0))
                                  (let ()
                                    (define fixed-end (+ prefix-len fixed-n))
                                    (define fixed-pv
                                      (pvector-copy pv prefix-len fixed-end))
                                    (define suffix-pv (pvector-drop pv fixed-end))
                                    (list (pvector-take pv prefix-len)
                                          (pvector->list fixed-pv)
                                          suffix-pv)
                                    ) ; let: rest-prefix fixed-suffix
                                  #f))
                            (let ()
                              (define fixed-list-pat (list fixed-pat ...))
                              (list prefix-pv-pat fixed-list-pat suffix-pv-pat)
                              ) ; let: app result pattern
                            )
                       ) ; ?: prefix rest (suffix fixed)
                       ] ; cond branch: prefix rest
                 ;; Both are FIXED
                 [else
                  #'(? pvector?
                       (app (lambda (pv)
                              (define len (pvector-length pv))
                              (if (= len (+ prefix-len-pat fixed-n suffix-len-pat))
                                  (let ()
                                    (define fixed-end (+ prefix-len-pat fixed-n))
                                    (define fixed-pv
                                      (pvector-copy pv prefix-len-pat fixed-end))
                                    (define suffix-pv (pvector-drop pv fixed-end))
                                    (list (pvector-take pv prefix-len-pat)
                                          (pvector->list fixed-pv)
                                          suffix-pv)
                                    ) ; let: fixed-prefix fixed-suffix
                                  #f))
                            (let ()
                              (define fixed-list-pat (list fixed-pat ...))
                              (list prefix-pv-pat fixed-list-pat suffix-pv-pat)
                              ) ; let: app result pattern
                            )
                       ) ; ?: both fixed
                       ] ; cond branch: both fixed
                 ) ; cond: both prefix/suffix vars
               ) ; with-syntax: fixed-pat for both-vars branch
             ] ; syntax-case branch: suffix-var
           ) ; syntax-case: suffix-var
          ] ; syntax-case branch: prefix-var
        ) ; syntax-case: prefix-var
       ] ; cond branch: both vars
      ) ; cond: generate-pvector**-match
    ) ; with-syntax: fixed-n
  ) ; define-for-syntax generate-pvector**-match

(define-match-expander pvector**
  (lambda (stx)
    (syntax-case stx ()
      [(_ seg ...)
       (generate-pvector**-match #'input #'(seg ...))
       ] ; syntax-case branch: pvector**
      ) ; syntax-case: pvector**
    ) ; lambda: pvector**
  ) ; define-match-expander pvector**

;; Exports
(provide pvector-delete)
(provide pvector? pvector-empty?)
(provide pvector-take pvector-take-right pvector-drop pvector-drop-right pvector-split-at pvector-split-at-right)
(provide pvector-copy)
(provide pvector-view-left pvector-view-right)
(provide pvector-empty pvector-cons-left pvector-cons-right pvector-pop-left pvector-pop-right pvector-split pvector-append)
(provide pvector-ref pvector-set pvector-length)
(provide in-pvector in-pvector-reverse in-pvector/index in-pvector-indexed)
(provide vector->pvector pvector->vector)
(provide list->pvector pvector->list)
(provide pvector-insert)
;; Comprehensions
(provide for/pvector for*/pvector)
;; Match expanders
(provide pvector pvector* pvector**)
;; Backwards compatibility (now aliases to default)
(provide pvector-ref/fast pvector-set/fast)
