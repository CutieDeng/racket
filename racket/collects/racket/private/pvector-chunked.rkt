#lang racket/base

(require racket/list
         racket/match
         racket/vector
         "pvector-core.rkt")

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
         pvector-shape-stats)

(define default-chunk-size 64)
(define endpoint-pack-limit 4)

(struct chunked-pvector (tree length chunk-size) #:sealed)
(struct leaf-chunk (vec start end) #:sealed)

(define empty-tree (ft:empty))
(define empty-pvector (chunked-pvector empty-tree 0 default-chunk-size))

(define pvector? chunked-pvector?)

(define (pvector-empty) empty-pvector)

(define (pvector-empty? pv)
  (and (chunked-pvector? pv)
       (zero? (chunked-pvector-length pv))))

(define (pvector-length pv)
  (chunked-pvector-length pv))

(define (chunk-length chunk)
  (if (vector? chunk)
      (vector-length chunk)
      (- (leaf-chunk-end chunk) (leaf-chunk-start chunk))))

(define (chunk-ref chunk idx)
  (if (vector? chunk)
      (vector-ref chunk idx)
      (vector-ref (leaf-chunk-vec chunk)
                  (+ (leaf-chunk-start chunk) idx))))

(define (chunk-slice chunk start end)
  (cond
    [(= start end) #f]
    [(and (zero? start) (= end (chunk-length chunk))) chunk]
    [(vector? chunk)
     (leaf-chunk chunk start end)]
    [else
     (leaf-chunk (leaf-chunk-vec chunk)
                 (+ (leaf-chunk-start chunk) start)
                 (+ (leaf-chunk-start chunk) end))]))

(define (chunk-set chunk idx value)
  (define vec
    (if (vector? chunk)
        (vector-copy chunk)
        (vector-copy (leaf-chunk-vec chunk)
                     (leaf-chunk-start chunk)
                     (leaf-chunk-end chunk))))
  (vector-set! vec idx value)
  (vector->immutable-vector vec))

(define (chunk-for-each proc chunk)
  (cond
    [(vector? chunk)
     (for ([elem (in-vector chunk)])
       (proc elem))]
    [else
     (define vec (leaf-chunk-vec chunk))
     (for ([i (in-range (leaf-chunk-start chunk) (leaf-chunk-end chunk))])
       (proc (vector-ref vec i)))]))

(define (chunk-prepend chunk value)
  (define len (chunk-length chunk))
  (define vec (make-vector (add1 len)))
  (vector-set! vec 0 value)
  (for ([i (in-range len)])
    (vector-set! vec (add1 i) (chunk-ref chunk i)))
  (vector->immutable-vector vec))

(define (chunk-append chunk value)
  (define len (chunk-length chunk))
  (define vec (make-vector (add1 len)))
  (for ([i (in-range len)])
    (vector-set! vec i (chunk-ref chunk i)))
  (vector-set! vec len value)
  (vector->immutable-vector vec))

(define (node-size node depth)
  (if (zero? depth)
      (chunk-length node)
      (if (node:2? node)
          (node:2-v node)
          (node:3-v node))))

(define (digit-size digit depth)
  (cond
    [(digit:1? digit)
     (node-size (digit:1-a digit) depth)]
    [(digit:2? digit)
     (+ (node-size (digit:2-a digit) depth)
        (node-size (digit:2-b digit) depth))]
    [(digit:3? digit)
     (+ (node-size (digit:3-a digit) depth)
        (node-size (digit:3-b digit) depth)
        (node-size (digit:3-c digit) depth))]
    [else
     (+ (node-size (digit:4-a digit) depth)
        (node-size (digit:4-b digit) depth)
        (node-size (digit:4-c digit) depth)
        (node-size (digit:4-d digit) depth))]))

(define (tree-size tree depth)
  (cond
    [(ft:empty? tree) 0]
    [(ft:single? tree) (node-size (ft:single-a tree) depth)]
    [else (ft:deep-v tree)]))

(define (build-node2 a b depth)
  (node:2 (+ (node-size a depth)
             (node-size b depth))
          a
          b))

(define (build-node3 a b c depth)
  (node:3 (+ (node-size a depth)
             (node-size b depth)
             (node-size c depth))
          a
          b
          c))

(define (small-vector->tree vec depth)
  (define total
    (for/fold ([sum 0]) ([node (in-vector vec)])
      (+ sum (node-size node depth))))
  (match vec
    [(vector) empty-tree]
    [(vector a) (ft:single a)]
    [(vector a b)
     (ft:deep total (digit:1 a) empty-tree (digit:1 b))]
    [(vector a b c)
     (ft:deep total (digit:1 a) empty-tree (digit:2 b c))]
    [(vector a b c d)
     (ft:deep total (digit:2 a b) empty-tree (digit:2 c d))]
    [(vector a b c d e)
     (ft:deep total (digit:2 a b) empty-tree (digit:3 c d e))]
    [(vector a b c d e f)
     (ft:deep total (digit:3 a b c) empty-tree (digit:3 d e f))]
    [(vector a b c d e f g)
     (ft:deep total (digit:3 a b c) empty-tree (digit:4 d e f g))]
    [(vector a b c d e f g h)
     (ft:deep total (digit:4 a b c d) empty-tree (digit:4 e f g h))]))

(define (vector->node3-vector vec start len depth)
  (define new-len (quotient len 3))
  (define new-vec (make-vector new-len))
  (for ([i (in-range new-len)])
    (define offset (* 3 i))
    (define idx0 (+ start offset))
    (define idx1 (+ start offset 1))
    (define idx2 (+ start offset 2))
    (vector-set! new-vec i
                 (build-node3 (vector-ref vec idx0)
                              (vector-ref vec idx1)
                              (vector-ref vec idx2)
                              depth)))
  new-vec)

(define (nodes-vector->tree vec total depth)
  (define len (vector-length vec))
  (define inner-depth (add1 depth))
  (cond
    [(<= len 8)
     (small-vector->tree vec depth)]
    [else
     (match (modulo len 3)
       [0
        (define left (digit:3 (vector-ref vec 0)
                              (vector-ref vec 1)
                              (vector-ref vec 2)))
        (define right (digit:3 (vector-ref vec (- len 3))
                               (vector-ref vec (- len 2))
                               (vector-ref vec (- len 1))))
        (define mid-total (- total (digit-size left depth) (digit-size right depth)))
        (define mid (vector->node3-vector vec 3 (- len 6) depth))
        (ft:deep total left (nodes-vector->tree mid mid-total inner-depth) right)]
       [1
        (define left (digit:4 (vector-ref vec 0)
                              (vector-ref vec 1)
                              (vector-ref vec 2)
                              (vector-ref vec 3)))
        (define right (digit:3 (vector-ref vec (- len 3))
                               (vector-ref vec (- len 2))
                               (vector-ref vec (- len 1))))
        (define mid-total (- total (digit-size left depth) (digit-size right depth)))
        (define mid (vector->node3-vector vec 4 (- len 7) depth))
        (ft:deep total left (nodes-vector->tree mid mid-total inner-depth) right)]
       [2
        (define left (digit:4 (vector-ref vec 0)
                              (vector-ref vec 1)
                              (vector-ref vec 2)
                              (vector-ref vec 3)))
        (define right (digit:4 (vector-ref vec (- len 4))
                               (vector-ref vec (- len 3))
                               (vector-ref vec (- len 2))
                               (vector-ref vec (- len 1))))
        (define mid-total (- total (digit-size left depth) (digit-size right depth)))
        (define mid (vector->node3-vector vec 4 (- len 8) depth))
        (ft:deep total left (nodes-vector->tree mid mid-total inner-depth) right)])]))

(define (vector->chunks vec size)
  (define len (vector-length vec))
  (define chunk-count (quotient (+ len size -1) size))
  (for/vector #:length chunk-count ([chunk-idx (in-range chunk-count)])
    (define start (* chunk-idx size))
    (define end (min len (+ start size)))
    (vector->immutable-vector (vector-copy vec start end))))

(define (chunks->pvector chunks len [size default-chunk-size])
  (if (zero? len)
      (chunked-pvector empty-tree 0 size)
      (chunked-pvector (nodes-vector->tree chunks len 0) len size)))

(define (vector->pvector vec)
  (define len (vector-length vec))
  (chunks->pvector (vector->chunks vec default-chunk-size) len default-chunk-size))

(define (list->pvector lst)
  (vector->pvector (list->vector lst)))

(define (make-pvector n [value #f])
  (vector->pvector (make-vector n value)))

(define (pvector . elems)
  (list->pvector elems))

(define (sequence->pvector seq)
  (cond
    [(chunked-pvector? seq) seq]
    [(list? seq) (list->pvector seq)]
    [(vector? seq) (vector->pvector seq)]
    [else
     (for/fold ([pv empty-pvector]) ([elem seq])
       (pvector-cons-right pv elem))]))

(define (ref-node node idx depth)
  (if (zero? depth)
      (chunk-ref node idx)
      (let ([sub-depth (sub1 depth)])
        (cond
          [(node:2? node)
           (define a (node:2-a node))
           (define a-size (node-size a sub-depth))
           (if (< idx a-size)
               (ref-node a idx sub-depth)
               (ref-node (node:2-b node) (- idx a-size) sub-depth))]
          [else
           (define a (node:3-a node))
           (define b (node:3-b node))
           (define a-size (node-size a sub-depth))
           (define b-size (node-size b sub-depth))
           (define ab-size (+ a-size b-size))
           (cond
             [(< idx a-size) (ref-node a idx sub-depth)]
             [(< idx ab-size) (ref-node b (- idx a-size) sub-depth)]
             [else (ref-node (node:3-c node) (- idx ab-size) sub-depth)])]))))

(define (ref-digit digit idx depth)
  (cond
    [(digit:1? digit)
     (ref-node (digit:1-a digit) idx depth)]
    [(digit:2? digit)
     (define a (digit:2-a digit))
     (define a-size (node-size a depth))
     (if (< idx a-size)
         (ref-node a idx depth)
         (ref-node (digit:2-b digit) (- idx a-size) depth))]
    [(digit:3? digit)
     (define a (digit:3-a digit))
     (define b (digit:3-b digit))
     (define a-size (node-size a depth))
     (define b-size (node-size b depth))
     (define ab-size (+ a-size b-size))
     (cond
       [(< idx a-size) (ref-node a idx depth)]
       [(< idx ab-size) (ref-node b (- idx a-size) depth)]
       [else (ref-node (digit:3-c digit) (- idx ab-size) depth)])]
    [else
     (define a (digit:4-a digit))
     (define b (digit:4-b digit))
     (define c (digit:4-c digit))
     (define a-size (node-size a depth))
     (define b-size (node-size b depth))
     (define c-size (node-size c depth))
     (define ab-size (+ a-size b-size))
     (define abc-size (+ ab-size c-size))
     (cond
       [(< idx a-size) (ref-node a idx depth)]
       [(< idx ab-size) (ref-node b (- idx a-size) depth)]
       [(< idx abc-size) (ref-node c (- idx ab-size) depth)]
       [else (ref-node (digit:4-d digit) (- idx abc-size) depth)])]))

(define (ref-tree tree idx depth)
  (cond
    [(ft:single? tree)
     (ref-node (ft:single-a tree) idx depth)]
    [(ft:deep? tree)
     (define left (ft:deep-left tree))
     (define inner (ft:deep-inner tree))
     (define right (ft:deep-right tree))
     (define inner-depth (add1 depth))
     (define left-size (digit-size left depth))
     (define inner-size (tree-size inner inner-depth))
     (define left+inner-size (+ left-size inner-size))
     (cond
       [(< idx left-size) (ref-digit left idx depth)]
       [(< idx left+inner-size) (ref-tree inner (- idx left-size) inner-depth)]
       [else (ref-digit right (- idx left+inner-size) depth)])]
    [else
     (error 'pvector-ref "index out of bounds")]))

(define (pvector-ref pv idx)
  (ref-tree (chunked-pvector-tree pv) idx 0))

(define pvector-ref/fast pvector-ref)

(define (set-node node idx value depth)
  (if (zero? depth)
      (chunk-set node idx value)
      (let ([sub-depth (sub1 depth)])
        (cond
          [(node:2? node)
           (define a (node:2-a node))
           (define b (node:2-b node))
           (define a-size (node-size a sub-depth))
           (if (< idx a-size)
               (node:2 (node:2-v node) (set-node a idx value sub-depth) b)
               (node:2 (node:2-v node) a (set-node b (- idx a-size) value sub-depth)))]
          [else
           (define a (node:3-a node))
           (define b (node:3-b node))
           (define c (node:3-c node))
           (define a-size (node-size a sub-depth))
           (define b-size (node-size b sub-depth))
           (define ab-size (+ a-size b-size))
           (cond
             [(< idx a-size)
              (node:3 (node:3-v node) (set-node a idx value sub-depth) b c)]
             [(< idx ab-size)
              (node:3 (node:3-v node) a (set-node b (- idx a-size) value sub-depth) c)]
             [else
              (node:3 (node:3-v node) a b (set-node c (- idx ab-size) value sub-depth))])]))))

(define (set-digit digit idx value depth)
  (cond
    [(digit:1? digit)
     (digit:1 (set-node (digit:1-a digit) idx value depth))]
    [(digit:2? digit)
     (define a (digit:2-a digit))
     (define b (digit:2-b digit))
     (define a-size (node-size a depth))
     (if (< idx a-size)
         (digit:2 (set-node a idx value depth) b)
         (digit:2 a (set-node b (- idx a-size) value depth)))]
    [(digit:3? digit)
     (define a (digit:3-a digit))
     (define b (digit:3-b digit))
     (define c (digit:3-c digit))
     (define a-size (node-size a depth))
     (define b-size (node-size b depth))
     (define ab-size (+ a-size b-size))
     (cond
       [(< idx a-size) (digit:3 (set-node a idx value depth) b c)]
       [(< idx ab-size) (digit:3 a (set-node b (- idx a-size) value depth) c)]
       [else (digit:3 a b (set-node c (- idx ab-size) value depth))])]
    [else
     (define a (digit:4-a digit))
     (define b (digit:4-b digit))
     (define c (digit:4-c digit))
     (define d (digit:4-d digit))
     (define a-size (node-size a depth))
     (define b-size (node-size b depth))
     (define c-size (node-size c depth))
     (define ab-size (+ a-size b-size))
     (define abc-size (+ ab-size c-size))
     (cond
       [(< idx a-size) (digit:4 (set-node a idx value depth) b c d)]
       [(< idx ab-size) (digit:4 a (set-node b (- idx a-size) value depth) c d)]
       [(< idx abc-size) (digit:4 a b (set-node c (- idx ab-size) value depth) d)]
       [else (digit:4 a b c (set-node d (- idx abc-size) value depth))])]))

(define (set-tree tree idx value depth)
  (cond
    [(ft:single? tree)
     (ft:single (set-node (ft:single-a tree) idx value depth))]
    [(ft:deep? tree)
     (define total (ft:deep-v tree))
     (define left (ft:deep-left tree))
     (define inner (ft:deep-inner tree))
     (define right (ft:deep-right tree))
     (define inner-depth (add1 depth))
     (define left-size (digit-size left depth))
     (define inner-size (tree-size inner inner-depth))
     (define left+inner-size (+ left-size inner-size))
     (cond
       [(< idx left-size)
        (ft:deep total (set-digit left idx value depth) inner right)]
       [(< idx left+inner-size)
        (ft:deep total left (set-tree inner (- idx left-size) value inner-depth) right)]
       [else
        (ft:deep total left inner (set-digit right (- idx left+inner-size) value depth))])]
    [else
     (error 'pvector-set "index out of bounds")]))

(define (pvector-set pv idx value)
  (chunked-pvector (set-tree (chunked-pvector-tree pv) idx value 0)
                   (chunked-pvector-length pv)
                   (chunked-pvector-chunk-size pv)))

(define pvector-set/fast pvector-set)

(define (tree-build left inner right depth)
  (define inner-depth (add1 depth))
  (ft:deep (+ (digit-size left depth)
              (tree-size inner inner-depth)
              (digit-size right depth))
           left
           inner
           right))

(define (tree-cons-left tree node depth)
  (cond
    [(ft:empty? tree) (ft:single node)]
    [(ft:single? tree)
     (define a (ft:single-a tree))
     (ft:deep (+ (node-size node depth)
                 (node-size a depth))
              (digit:1 node)
              empty-tree
              (digit:1 a))]
    [else
     (define total (ft:deep-v tree))
     (define left (ft:deep-left tree))
     (define inner (ft:deep-inner tree))
     (define right (ft:deep-right tree))
     (define new-total (+ (node-size node depth) total))
     (cond
       [(digit:4? left)
        (define a (digit:4-a left))
        (define b (digit:4-b left))
        (define c (digit:4-c left))
        (define d (digit:4-d left))
        (ft:deep new-total
                 (digit:2 node a)
                 (tree-cons-left inner (build-node3 b c d depth) (add1 depth))
                 right)]
       [(digit:1? left)
        (ft:deep new-total (digit:2 node (digit:1-a left)) inner right)]
       [(digit:2? left)
        (ft:deep new-total (digit:3 node (digit:2-a left) (digit:2-b left)) inner right)]
       [else
        (ft:deep new-total
                 (digit:4 node (digit:3-a left) (digit:3-b left) (digit:3-c left))
                 inner
                 right)])]))

(define (tree-cons-right tree node depth)
  (cond
    [(ft:empty? tree) (ft:single node)]
    [(ft:single? tree)
     (define a (ft:single-a tree))
     (ft:deep (+ (node-size a depth)
                 (node-size node depth))
              (digit:1 a)
              empty-tree
              (digit:1 node))]
    [else
     (define total (ft:deep-v tree))
     (define left (ft:deep-left tree))
     (define inner (ft:deep-inner tree))
     (define right (ft:deep-right tree))
     (define new-total (+ total (node-size node depth)))
     (cond
       [(digit:4? right)
        (define a (digit:4-a right))
        (define b (digit:4-b right))
        (define c (digit:4-c right))
        (define d (digit:4-d right))
        (ft:deep new-total
                 left
                 (tree-cons-right inner (build-node3 a b c depth) (add1 depth))
                 (digit:2 d node))]
       [(digit:1? right)
        (ft:deep new-total left inner (digit:2 (digit:1-a right) node))]
       [(digit:2? right)
        (ft:deep new-total left inner (digit:3 (digit:2-a right) (digit:2-b right) node))]
       [else
        (ft:deep new-total
                 left
                 inner
                 (digit:4 (digit:3-a right) (digit:3-b right) (digit:3-c right) node))])]))

(define (digit-first-node digit)
  (cond
    [(digit:1? digit) (digit:1-a digit)]
    [(digit:2? digit) (digit:2-a digit)]
    [(digit:3? digit) (digit:3-a digit)]
    [else (digit:4-a digit)]))

(define (digit-last-node digit)
  (cond
    [(digit:1? digit) (digit:1-a digit)]
    [(digit:2? digit) (digit:2-b digit)]
    [(digit:3? digit) (digit:3-c digit)]
    [else (digit:4-d digit)]))

(define (digit-replace-first digit node)
  (cond
    [(digit:1? digit) (digit:1 node)]
    [(digit:2? digit) (digit:2 node (digit:2-b digit))]
    [(digit:3? digit) (digit:3 node (digit:3-b digit) (digit:3-c digit))]
    [else (digit:4 node (digit:4-b digit) (digit:4-c digit) (digit:4-d digit))]))

(define (digit-replace-last digit node)
  (cond
    [(digit:1? digit) (digit:1 node)]
    [(digit:2? digit) (digit:2 (digit:2-a digit) node)]
    [(digit:3? digit) (digit:3 (digit:3-a digit) (digit:3-b digit) node)]
    [else (digit:4 (digit:4-a digit) (digit:4-b digit) (digit:4-c digit) node)]))

(define (tree-first-node tree)
  (cond
    [(ft:single? tree) (ft:single-a tree)]
    [(ft:deep? tree) (digit-first-node (ft:deep-left tree))]
    [else (error 'tree-first-node "empty tree")]))

(define (tree-last-node tree)
  (cond
    [(ft:single? tree) (ft:single-a tree)]
    [(ft:deep? tree) (digit-last-node (ft:deep-right tree))]
    [else (error 'tree-last-node "empty tree")]))

(define (tree-replace-first tree node depth)
  (cond
    [(ft:single? tree) (ft:single node)]
    [(ft:deep? tree)
     (define total (ft:deep-v tree))
     (define left (ft:deep-left tree))
     (define old (digit-first-node left))
     (ft:deep (+ total
                 (- (node-size node depth)
                    (node-size old depth)))
              (digit-replace-first left node)
              (ft:deep-inner tree)
              (ft:deep-right tree))]
    [else (error 'tree-replace-first "empty tree")]))

(define (tree-replace-last tree node depth)
  (cond
    [(ft:single? tree) (ft:single node)]
    [(ft:deep? tree)
     (define total (ft:deep-v tree))
     (define right (ft:deep-right tree))
     (define old (digit-last-node right))
     (ft:deep (+ total
                 (- (node-size node depth)
                    (node-size old depth)))
              (ft:deep-left tree)
              (ft:deep-inner tree)
              (digit-replace-last right node))]
    [else (error 'tree-replace-last "empty tree")]))

(define (node->list node)
  (if (node:2? node)
      (list (node:2-a node) (node:2-b node))
      (list (node:3-a node) (node:3-b node) (node:3-c node))))

(define (digit->list digit)
  (cond
    [(digit:1? digit) (list (digit:1-a digit))]
    [(digit:2? digit) (list (digit:2-a digit) (digit:2-b digit))]
    [(digit:3? digit) (list (digit:3-a digit) (digit:3-b digit) (digit:3-c digit))]
    [else (list (digit:4-a digit) (digit:4-b digit) (digit:4-c digit) (digit:4-d digit))]))

(define (list->digit nodes)
  (match nodes
    [(list a) (digit:1 a)]
    [(list a b) (digit:2 a b)]
    [(list a b c) (digit:3 a b c)]
    [(list a b c d) (digit:4 a b c d)]))

(define (node->digit node)
  (list->digit (node->list node)))

(define (digit-list->tree nodes depth)
  (define total
    (for/fold ([sum 0]) ([node (in-list nodes)])
      (+ sum (node-size node depth))))
  (match nodes
    ['() empty-tree]
    [(list a) (ft:single a)]
    [(list a b) (ft:deep total (digit:1 a) empty-tree (digit:1 b))]
    [(list a b c) (ft:deep total (digit:1 a) empty-tree (digit:2 b c))]
    [(list a b c d) (ft:deep total (digit:2 a b) empty-tree (digit:2 c d))]))

(define (digit-list2->tree nodes depth)
  (if (<= (length nodes) 4)
      (digit-list->tree nodes depth)
      (let ([total
             (for/fold ([sum 0]) ([node (in-list nodes)])
               (+ sum (node-size node depth)))])
        (match nodes
          [(list a b c d e)
           (ft:deep total (digit:2 a b) empty-tree (digit:3 c d e))]
          [(list a b c d e f)
           (ft:deep total (digit:3 a b c) empty-tree (digit:3 d e f))]
          [(list a b c d e f g)
           (ft:deep total (digit:3 a b c) empty-tree (digit:4 d e f g))]))))

(define (tree-pop-left tree depth)
  (cond
    [(ft:empty? tree) (error 'tree-pop-left "empty tree")]
    [(ft:single? tree) (values (ft:single-a tree) empty-tree)]
    [else
     (define left (ft:deep-left tree))
     (define inner (ft:deep-inner tree))
     (define right (ft:deep-right tree))
     (cond
       [(digit:1? left)
        (define a (digit:1-a left))
        (cond
          [(ft:empty? inner)
           (match (digit->list right)
             [(list b) (values a (ft:single b))]
             [rest (values a (digit-list->tree rest depth))])]
          [else
           (define inner-depth (add1 depth))
           (define-values (left-node inner^) (tree-pop-left inner inner-depth))
           (values a (tree-build (node->digit left-node) inner^ right depth))])]
       [else
        (define nodes (digit->list left))
        (values (car nodes)
                (tree-build (list->digit (cdr nodes)) inner right depth))])]))

(define (tree-pop-right tree depth)
  (cond
    [(ft:empty? tree) (error 'tree-pop-right "empty tree")]
    [(ft:single? tree) (values (ft:single-a tree) empty-tree)]
    [else
     (define left (ft:deep-left tree))
     (define inner (ft:deep-inner tree))
     (define right (ft:deep-right tree))
     (cond
       [(digit:1? right)
        (define a (digit:1-a right))
        (cond
          [(ft:empty? inner)
           (match (digit->list left)
             [(list b) (values a (ft:single b))]
             [rest (values a (digit-list->tree rest depth))])]
          [else
           (define inner-depth (add1 depth))
           (define-values (right-node inner^) (tree-pop-right inner inner-depth))
           (values a (tree-build left inner^ (node->digit right-node) depth))])]
       [else
        (define nodes (digit->list right))
        (values (last nodes)
                (tree-build left inner (list->digit (drop-right nodes 1)) depth))])]))

(define (digit-list+tree->digit nodes tree depth pop)
  (cond
    [(null? nodes)
     (define-values (node tree^) (pop tree (add1 depth)))
     (values (node->digit node) tree^)]
    [else
     (values (list->digit nodes) tree)]))

(define (left-digit+tree->tree digit tree depth)
  (cond
    [(ft:empty? tree)
     (digit-list->tree (digit->list digit) depth)]
    [else
     (define-values (node tree^) (tree-pop-right tree (add1 depth)))
     (tree-build digit tree^ (node->digit node) depth)]))

(define (right-digit+tree->tree digit tree depth)
  (cond
    [(ft:empty? tree)
     (digit-list->tree (digit->list digit) depth)]
    [else
     (define-values (node tree^) (tree-pop-left tree (add1 depth)))
     (tree-build (node->digit node) tree^ digit depth)]))

(define (node-list->nodes nodes depth)
  (match nodes
    [(list a b c d)
     (list (build-node2 a b depth)
           (build-node2 c d depth))]
    [(list a b c)
     (list (build-node3 a b c depth))]
    [(list a b)
     (list (build-node2 a b depth))]
    [(list a b c rest ...)
     (cons (build-node3 a b c depth)
           (node-list->nodes rest depth))]))

(define (tree-concat left right depth)
  (cond
    [(ft:empty? left) right]
    [(ft:empty? right) left]
    [(ft:single? left)
     (tree-cons-left right (ft:single-a left) depth)]
    [(ft:single? right)
     (tree-cons-right left (ft:single-a right) depth)]
    [else
     (define left-size (ft:deep-v left))
     (define left-left (ft:deep-left left))
     (define left-inner (ft:deep-inner left))
     (define left-right (ft:deep-right left))
     (define right-size (ft:deep-v right))
     (define right-left (ft:deep-left right))
     (define right-inner (ft:deep-inner right))
     (define right-right (ft:deep-right right))
     (define middle-nodes
       (node-list->nodes (append (digit->list left-right)
                                 (digit->list right-left))
                         depth))
     (define inner-depth (add1 depth))
     (define left-inner^
       (for/fold ([inner left-inner]) ([node (in-list middle-nodes)])
         (tree-cons-right inner node inner-depth)))
     (ft:deep (+ left-size right-size)
              left-left
              (tree-concat left-inner^ right-inner inner-depth)
              right-right)]))

(define (split-digit digit idx depth)
  (let loop ([before '()] [nodes (digit->list digit)] [idx idx])
    (match nodes
      [(cons node rest)
       (define size (node-size node depth))
       (if (< idx size)
           (values idx (reverse before) node rest)
           (loop (cons node before) rest (- idx size)))]
      ['()
       (error 'split-digit "index out of digit: ~a" idx)])))

(define (split-node node idx depth)
  (define sub-depth (sub1 depth))
  (let loop ([before '()] [nodes (node->list node)] [idx idx])
    (match nodes
      [(cons child rest)
       (define size (node-size child sub-depth))
       (if (< idx size)
           (values idx (reverse before) child rest)
           (loop (cons child before) rest (- idx size)))]
      ['()
       (error 'split-node "index out of node: ~a" idx)])))

(define (split-tree tree idx depth)
  (cond
    [(ft:empty? tree) (error 'split-tree "empty tree")]
    [(ft:single? tree)
     (define node (ft:single-a tree))
     (when (>= idx (node-size node depth))
       (error 'split-tree "index out of single node: ~a" idx))
     (values idx empty-tree node empty-tree)]
    [else
     (define total (ft:deep-v tree))
     (define left (ft:deep-left tree))
     (define inner (ft:deep-inner tree))
     (define right (ft:deep-right tree))
     (define inner-depth (add1 depth))
     (define left-size (digit-size left depth))
     (define inner-size (tree-size inner inner-depth))
     (define left+inner-size (+ left-size inner-size))
     (cond
       [(< idx left-size)
        (define-values (idx^ l node r) (split-digit left idx depth))
        (define left^ (digit-list->tree l depth))
        (define right^
          (cond
            [(ft:empty? inner)
             (digit-list2->tree (append r (digit->list right)) depth)]
            [else
             (define-values (right-digit inner^)
               (digit-list+tree->digit r inner depth tree-pop-left))
             (tree-build right-digit inner^ right depth)]))
        (values idx^ left^ node right^)]
       [(< idx left+inner-size)
        (define-values (rest-idx inner-left node inner-right)
          (split-tree inner (- idx left-size) inner-depth))
        (define left^ (left-digit+tree->tree left inner-left depth))
        (define right^ (right-digit+tree->tree right inner-right depth))
        (define-values (idx^ l node^ r) (split-node node rest-idx inner-depth))
        (define left^^
          (for/fold ([acc left^]) ([child (in-list l)])
            (tree-cons-right acc child depth)))
        (define right^^
          (for/foldr ([acc right^]) ([child (in-list r)])
            (tree-cons-left acc child depth)))
        (values idx^ left^^ node^ right^^)]
       [(< idx total)
        (define-values (idx^ l node r)
          (split-digit right (- idx left+inner-size) depth))
        (define right^ (digit-list->tree r depth))
        (define left^
          (cond
            [(ft:empty? inner)
             (digit-list2->tree (append (digit->list left) l) depth)]
            [else
             (define-values (left-digit inner^)
               (digit-list+tree->digit l inner depth tree-pop-right))
             (tree-build left inner^ left-digit depth)]))
        (values idx^ left^ node right^)]
       [else
        (error 'split-tree "index out of tree: ~a" idx)])]))

(define (pvector-split-at pv pos)
  (define len (chunked-pvector-length pv))
  (define size (chunked-pvector-chunk-size pv))
  (cond
    [(zero? pos)
     (values (chunked-pvector empty-tree 0 size) pv)]
    [(= pos len)
     (values pv (chunked-pvector empty-tree 0 size))]
    [else
     (define-values (chunk-idx left chunk right)
       (split-tree (chunked-pvector-tree pv) pos 0))
     (define prefix (chunk-slice chunk 0 chunk-idx))
     (define suffix (chunk-slice chunk chunk-idx (chunk-length chunk)))
     (define left^
       (if prefix
           (tree-cons-right left prefix 0)
           left))
     (define right^
       (if suffix
           (tree-cons-left right suffix 0)
           right))
     (values (chunked-pvector left^ pos size)
             (chunked-pvector right^ (- len pos) size))]))

(define (pvector-split-at-right pv pos)
  (define split-pos (- (chunked-pvector-length pv) pos))
  (define-values (left right) (pvector-split-at pv split-pos))
  (values right left))

(define (pvector-take pv pos)
  (cond
    [(zero? pos) (chunked-pvector empty-tree 0 (chunked-pvector-chunk-size pv))]
    [(= pos (chunked-pvector-length pv)) pv]
    [else
     (define-values (left right) (pvector-split-at pv pos))
     left]))

(define (pvector-drop pv pos)
  (cond
    [(zero? pos) pv]
    [(= pos (chunked-pvector-length pv))
     (chunked-pvector empty-tree 0 (chunked-pvector-chunk-size pv))]
    [else
     (define-values (left right) (pvector-split-at pv pos))
     right]))

(define (pvector-take-right pv pos)
  (pvector-drop pv (- (chunked-pvector-length pv) pos)))

(define (pvector-drop-right pv pos)
  (pvector-take pv (- (chunked-pvector-length pv) pos)))

(define (pvector-copy pv start end)
  (cond
    [(= start end)
     (chunked-pvector empty-tree 0 (chunked-pvector-chunk-size pv))]
    [(and (zero? start) (= end (chunked-pvector-length pv)))
     pv]
    [(zero? start)
     (pvector-take pv end)]
    [(= end (chunked-pvector-length pv))
     (pvector-drop pv start)]
    [else
     (define-values (prefix after-end) (pvector-split-at pv end))
     (define-values (before-start middle) (pvector-split-at prefix start))
     middle]))

(define (pvector-split pv idx)
  (define-values (left right) (pvector-split-at pv idx))
  (define-values (value right^) (pvector-pop-left right))
  (values left value right^))

(define (pvector-view-left pv)
  (pvector-ref pv 0))

(define (pvector-view-right pv)
  (pvector-ref pv (sub1 (chunked-pvector-length pv))))

(define (pvector-cons-left pv value)
  (define size (chunked-pvector-chunk-size pv))
  (cond
    [(zero? (chunked-pvector-length pv))
     (chunked-pvector (ft:single (vector->immutable-vector (vector value))) 1 size)]
    [else
     (define tree (chunked-pvector-tree pv))
     (define first-chunk (tree-first-node tree))
     (chunked-pvector
      (if (< (chunk-length first-chunk) endpoint-pack-limit)
          (tree-replace-first tree (chunk-prepend first-chunk value) 0)
          (tree-cons-left tree
                          (vector->immutable-vector (vector value))
                          0))
      (add1 (chunked-pvector-length pv))
      size)]))

(define (pvector-cons-right pv value)
  (define size (chunked-pvector-chunk-size pv))
  (cond
    [(zero? (chunked-pvector-length pv))
     (chunked-pvector (ft:single (vector->immutable-vector (vector value))) 1 size)]
    [else
     (define tree (chunked-pvector-tree pv))
     (define last-chunk (tree-last-node tree))
     (chunked-pvector
      (if (< (chunk-length last-chunk) endpoint-pack-limit)
          (tree-replace-last tree (chunk-append last-chunk value) 0)
          (tree-cons-right tree
                           (vector->immutable-vector (vector value))
                           0))
      (add1 (chunked-pvector-length pv))
      size)]))

(define (pvector-pop-left pv)
  (define size (chunked-pvector-chunk-size pv))
  (define tree (chunked-pvector-tree pv))
  (define chunk (tree-first-node tree))
  (define value (chunk-ref chunk 0))
  (define chunk-len (chunk-length chunk))
  (define rest-tree
    (if (= chunk-len 1)
        (let-values ([(popped rest) (tree-pop-left tree 0)])
          rest)
        (tree-replace-first tree (chunk-slice chunk 1 chunk-len) 0)))
  (values value (chunked-pvector rest-tree (sub1 (chunked-pvector-length pv)) size)))

(define (pvector-pop-right pv)
  (define size (chunked-pvector-chunk-size pv))
  (define tree (chunked-pvector-tree pv))
  (define chunk (tree-last-node tree))
  (define chunk-len (chunk-length chunk))
  (define value (chunk-ref chunk (sub1 chunk-len)))
  (define rest-tree
    (if (= chunk-len 1)
        (let-values ([(popped rest) (tree-pop-right tree 0)])
          rest)
        (tree-replace-last tree (chunk-slice chunk 0 (sub1 chunk-len)) 0)))
  (values value (chunked-pvector rest-tree (sub1 (chunked-pvector-length pv)) size)))

(define (pvector-append left right)
  (cond
    [(zero? (chunked-pvector-length left)) right]
    [(zero? (chunked-pvector-length right)) left]
    [else
     (define size (chunked-pvector-chunk-size left))
     (chunked-pvector (tree-concat (chunked-pvector-tree left)
                                   (chunked-pvector-tree right)
                                   0)
                      (+ (chunked-pvector-length left)
                         (chunked-pvector-length right))
                      size)]))

(define (pvector-insert pv idx value)
  (define-values (left right) (pvector-split-at pv idx))
  (pvector-append left (pvector-cons-left right value)))

(define (pvector-delete pv idx)
  (define-values (left value right) (pvector-split pv idx))
  (values (pvector-append left right) value))

(define (pvector-for-each proc pv)
  (define (each-node node depth)
    (if (zero? depth)
        (chunk-for-each proc node)
        (let ([sub-depth (sub1 depth)])
          (if (node:2? node)
              (begin
                (each-node (node:2-a node) sub-depth)
                (each-node (node:2-b node) sub-depth))
              (begin
                (each-node (node:3-a node) sub-depth)
                (each-node (node:3-b node) sub-depth)
                (each-node (node:3-c node) sub-depth))))))
  (define (each-digit digit depth)
    (for ([node (in-list (digit->list digit))])
      (each-node node depth)))
  (define (each-tree tree depth)
    (cond
      [(ft:empty? tree) (void)]
      [(ft:single? tree)
       (each-node (ft:single-a tree) depth)]
      [else
       (each-digit (ft:deep-left tree) depth)
       (each-tree (ft:deep-inner tree) (add1 depth))
       (each-digit (ft:deep-right tree) depth)]))
  (each-tree (chunked-pvector-tree pv) 0))

(define (pvector->vector pv)
  (define len (chunked-pvector-length pv))
  (define vec (make-vector len))
  (define i 0)
  (pvector-for-each
   (lambda (elem)
     (vector-set! vec i elem)
     (set! i (add1 i)))
   pv)
  vec)

(define (pvector->list pv)
  (for/list ([elem (in-vector (pvector->vector pv))])
    elem))

(define (in-pvector pv)
  (in-vector (pvector->vector pv)))

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
  (define h (make-hasheq))
  (define max-depth 0)
  (define slice-bases (make-hasheq))
  (define (inc! k [n 1])
    (hash-set! h k (+ (hash-ref h k 0) n)))
  (define (note-depth! depth)
    (when (> depth max-depth)
      (set! max-depth depth)))
  (define (walk-leaf chunk)
    (define len (chunk-length chunk))
    (inc! 'leaves)
    (inc! 'visible-elems len)
    (when (= len 1)
      (inc! 'singleton-leaves))
    (when (= len (chunked-pvector-chunk-size pv))
      (inc! 'full-leaves))
    (if (vector? chunk)
        (begin
          (inc! 'vector-leaves)
          (inc! 'retained-elems len))
        (begin
          (inc! 'slice-leaves)
          (inc! 'retained-elems (vector-length (leaf-chunk-vec chunk)))
          (hash-set! slice-bases (leaf-chunk-vec chunk) #t))))
  (define (walk-node node depth)
    (note-depth! depth)
    (cond
      [(zero? depth)
       (walk-leaf node)]
      [(node:2? node)
       (inc! 'node2)
       (define sub-depth (sub1 depth))
       (walk-node (node:2-a node) sub-depth)
       (walk-node (node:2-b node) sub-depth)]
      [else
       (inc! 'node3)
       (define sub-depth (sub1 depth))
       (walk-node (node:3-a node) sub-depth)
       (walk-node (node:3-b node) sub-depth)
       (walk-node (node:3-c node) sub-depth)]))
  (define (walk-digit digit depth)
    (note-depth! depth)
    (cond
      [(digit:1? digit)
       (inc! 'digit1)
       (walk-node (digit:1-a digit) depth)]
      [(digit:2? digit)
       (inc! 'digit2)
       (walk-node (digit:2-a digit) depth)
       (walk-node (digit:2-b digit) depth)]
      [(digit:3? digit)
       (inc! 'digit3)
       (walk-node (digit:3-a digit) depth)
       (walk-node (digit:3-b digit) depth)
       (walk-node (digit:3-c digit) depth)]
      [else
       (inc! 'digit4)
       (walk-node (digit:4-a digit) depth)
       (walk-node (digit:4-b digit) depth)
       (walk-node (digit:4-c digit) depth)
       (walk-node (digit:4-d digit) depth)]))
  (define (walk-tree tree depth)
    (note-depth! depth)
    (cond
      [(ft:empty? tree)
       (inc! 'ft-empty)]
      [(ft:single? tree)
       (inc! 'ft-single)
       (walk-node (ft:single-a tree) depth)]
      [else
       (inc! 'ft-deep)
       (walk-digit (ft:deep-left tree) depth)
       (walk-tree (ft:deep-inner tree) (add1 depth))
       (walk-digit (ft:deep-right tree) depth)]))
  (walk-tree (chunked-pvector-tree pv) 0)
  (hash-set! h 'max-depth max-depth)
  (hash-set! h 'length (chunked-pvector-length pv))
  (hash-set! h 'chunk-size (chunked-pvector-chunk-size pv))
  (hash-set! h 'slice-base-vectors (hash-count slice-bases))
  h)

(define-syntax-rule (for/pvector (clause ...) body ...)
  (list->pvector (for/list (clause ...) body ...)))

(define-syntax-rule (for*/pvector (clause ...) body ...)
  (list->pvector (for*/list (clause ...) body ...)))
