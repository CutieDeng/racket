#lang racket/base

(require racket/cmdline
         racket/list
         racket/match
         racket/pvector
         (prefix-in cutie: (file "/Users/cutiedeng/Y2026/M03/D28/cutie-ftree.rkt/pvector.rkt"))
         (prefix-in raw: racket/private/pvector)
         racket/private/pvector-core
         racket/string
         racket/treelist
         racket/vector)

(define M 100)
(define N 10000)
(define chunk-size 32)
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

(define (enabled? op)
  (or (not ops) (memq op ops)))

(command-line
 #:program "pvector-chunked-prototype"
 #:once-each
 [("--m") m "Outer repeat count"
          (set! M (parse-count '--m m))]
 [("--n") n "Sequence length"
          (set! N (parse-count '--n n))]
 [("--chunk-size") n "Leaf chunk size"
                   (set! chunk-size (parse-count '--chunk-size n))]
 [("--ops") s "Comma-separated benchmark names"
           (set! ops (parse-symbol-list s))])

(struct chunked-pvector (tree length chunk-size) #:sealed)

(define empty-tree (ft:empty))

(define (node-size node depth)
  (if (zero? depth)
      (vector-length node)
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

(define (build-node3 x0 x1 x2 depth)
  (node:3 (+ (node-size x0 depth)
             (node-size x1 depth)
             (node-size x2 depth))
          x0
          x1
          x2))

(define (build-node2 x0 x1 depth)
  (node:2 (+ (node-size x0 depth)
             (node-size x1 depth))
          x0
          x1))

(define (small-vector->tree vec depth)
  (define v
    (for/fold ([sum 0]) ([x (in-vector vec)])
      (+ sum (node-size x depth))))
  (match vec
    [(vector) empty-tree]
    [(vector x0) (ft:single x0)]
    [(vector x0 x1)
     (ft:deep v (digit:1 x0) empty-tree (digit:1 x1))]
    [(vector x0 x1 x2)
     (ft:deep v (digit:1 x0) empty-tree (digit:2 x1 x2))]
    [(vector x0 x1 x2 x3)
     (ft:deep v (digit:2 x0 x1) empty-tree (digit:2 x2 x3))]
    [(vector x0 x1 x2 x3 x4)
     (ft:deep v (digit:2 x0 x1) empty-tree (digit:3 x2 x3 x4))]
    [(vector x0 x1 x2 x3 x4 x5)
     (ft:deep v (digit:3 x0 x1 x2) empty-tree (digit:3 x3 x4 x5))]
    [(vector x0 x1 x2 x3 x4 x5 x6)
     (ft:deep v (digit:3 x0 x1 x2) empty-tree (digit:4 x3 x4 x5 x6))]
    [(vector x0 x1 x2 x3 x4 x5 x6 x7)
     (ft:deep v (digit:4 x0 x1 x2 x3) empty-tree (digit:4 x4 x5 x6 x7))]))

(define (vector->node3-vector vec start len depth)
  (define new-length (quotient len 3))
  (define new-vec (make-vector new-length))
  (for ([i (in-range new-length)])
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

(define (nodes-vector->tree vec sz depth)
  (define vec-len (vector-length vec))
  (define inner-depth (add1 depth))
  (cond
    [(<= vec-len 8)
     (small-vector->tree vec depth)]
    [else
     (match (modulo vec-len 3)
       [0
        (define lhs (digit:3 (vector-ref vec 0)
                             (vector-ref vec 1)
                             (vector-ref vec 2)))
        (define rhs (digit:3 (vector-ref vec (- vec-len 3))
                             (vector-ref vec (- vec-len 2))
                             (vector-ref vec (- vec-len 1))))
        (define mid-size (- sz (digit-size lhs depth) (digit-size rhs depth)))
        (define mid (vector->node3-vector vec 3 (- vec-len 6) depth))
        (ft:deep sz lhs (nodes-vector->tree mid mid-size inner-depth) rhs)]
       [1
        (define lhs (digit:4 (vector-ref vec 0)
                             (vector-ref vec 1)
                             (vector-ref vec 2)
                             (vector-ref vec 3)))
        (define rhs (digit:3 (vector-ref vec (- vec-len 3))
                             (vector-ref vec (- vec-len 2))
                             (vector-ref vec (- vec-len 1))))
        (define mid-size (- sz (digit-size lhs depth) (digit-size rhs depth)))
        (define mid (vector->node3-vector vec 4 (- vec-len 7) depth))
        (ft:deep sz lhs (nodes-vector->tree mid mid-size inner-depth) rhs)]
       [2
        (define lhs (digit:4 (vector-ref vec 0)
                             (vector-ref vec 1)
                             (vector-ref vec 2)
                             (vector-ref vec 3)))
        (define rhs (digit:4 (vector-ref vec (- vec-len 4))
                             (vector-ref vec (- vec-len 3))
                             (vector-ref vec (- vec-len 2))
                             (vector-ref vec (- vec-len 1))))
        (define mid-size (- sz (digit-size lhs depth) (digit-size rhs depth)))
        (define mid (vector->node3-vector vec 4 (- vec-len 8) depth))
        (ft:deep sz lhs (nodes-vector->tree mid mid-size inner-depth) rhs)])]))

(define (vector->chunks vec size)
  (define n (vector-length vec))
  (define chunk-count (quotient (+ n size -1) size))
  (for/vector #:length chunk-count ([chunk-idx (in-range chunk-count)])
    (define start (* chunk-idx size))
    (define end (min n (+ start size)))
    (vector->immutable-vector (vector-copy vec start end))))

(define (vector->chunked-pvector vec [size chunk-size])
  (define n (vector-length vec))
  (define chunks (vector->chunks vec size))
  (chunked-pvector (nodes-vector->tree chunks n 0) n size))

(define (chunked-ref-node node idx depth)
  (if (zero? depth)
      (vector-ref node idx)
      (let ([sub-depth (sub1 depth)])
        (cond
          [(node:2? node)
           (define a (node:2-a node))
           (define a-size (node-size a sub-depth))
           (if (< idx a-size)
               (chunked-ref-node a idx sub-depth)
               (chunked-ref-node (node:2-b node) (- idx a-size) sub-depth))]
          [else
           (define a (node:3-a node))
           (define b (node:3-b node))
           (define a-size (node-size a sub-depth))
           (define b-size (node-size b sub-depth))
           (define ab-size (+ a-size b-size))
           (cond
             [(< idx a-size)
              (chunked-ref-node a idx sub-depth)]
             [(< idx ab-size)
              (chunked-ref-node b (- idx a-size) sub-depth)]
             [else
              (chunked-ref-node (node:3-c node) (- idx ab-size) sub-depth)])]))))

(define (chunked-ref-digit digit idx depth)
  (cond
    [(digit:1? digit)
     (chunked-ref-node (digit:1-a digit) idx depth)]
    [(digit:2? digit)
     (define a (digit:2-a digit))
     (define a-size (node-size a depth))
     (if (< idx a-size)
         (chunked-ref-node a idx depth)
         (chunked-ref-node (digit:2-b digit) (- idx a-size) depth))]
    [(digit:3? digit)
     (define a (digit:3-a digit))
     (define b (digit:3-b digit))
     (define a-size (node-size a depth))
     (define b-size (node-size b depth))
     (define ab-size (+ a-size b-size))
     (cond
       [(< idx a-size)
        (chunked-ref-node a idx depth)]
       [(< idx ab-size)
        (chunked-ref-node b (- idx a-size) depth)]
       [else
        (chunked-ref-node (digit:3-c digit) (- idx ab-size) depth)])]
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
       [(< idx a-size)
        (chunked-ref-node a idx depth)]
       [(< idx ab-size)
        (chunked-ref-node b (- idx a-size) depth)]
       [(< idx abc-size)
        (chunked-ref-node c (- idx ab-size) depth)]
       [else
        (chunked-ref-node (digit:4-d digit) (- idx abc-size) depth)])]))

(define (chunked-ref-tree tree idx depth)
  (cond
    [(ft:single? tree)
     (chunked-ref-node (ft:single-a tree) idx depth)]
    [(ft:deep? tree)
     (define left (ft:deep-left tree))
     (define inner (ft:deep-inner tree))
     (define right (ft:deep-right tree))
     (define inner-depth (add1 depth))
     (define left-size (digit-size left depth))
     (define inner-size (tree-size inner inner-depth))
     (define left-inner-size (+ left-size inner-size))
     (cond
       [(< idx left-size)
        (chunked-ref-digit left idx depth)]
       [(< idx left-inner-size)
        (chunked-ref-tree inner (- idx left-size) inner-depth)]
       [else
        (chunked-ref-digit right (- idx left-inner-size) depth)])]
    [else
     (error 'chunked-pvector-ref "index out of bounds")]))

(define (chunked-pvector-ref pv idx)
  (unless (and (exact-nonnegative-integer? idx)
               (< idx (chunked-pvector-length pv)))
    (error 'chunked-pvector-ref "index out of bounds: ~a" idx))
  (chunked-ref-tree (chunked-pvector-tree pv) idx 0))

(define (chunked-for-each-node proc node depth)
  (if (zero? depth)
      (for ([x (in-vector node)])
        (proc x))
      (let ([sub-depth (sub1 depth)])
        (if (node:2? node)
            (begin
              (chunked-for-each-node proc (node:2-a node) sub-depth)
              (chunked-for-each-node proc (node:2-b node) sub-depth))
            (begin
              (chunked-for-each-node proc (node:3-a node) sub-depth)
              (chunked-for-each-node proc (node:3-b node) sub-depth)
              (chunked-for-each-node proc (node:3-c node) sub-depth))))))

(define (chunked-for-each-digit proc digit depth)
  (cond
    [(digit:1? digit)
     (chunked-for-each-node proc (digit:1-a digit) depth)]
    [(digit:2? digit)
     (chunked-for-each-node proc (digit:2-a digit) depth)
     (chunked-for-each-node proc (digit:2-b digit) depth)]
    [(digit:3? digit)
     (chunked-for-each-node proc (digit:3-a digit) depth)
     (chunked-for-each-node proc (digit:3-b digit) depth)
     (chunked-for-each-node proc (digit:3-c digit) depth)]
    [else
     (chunked-for-each-node proc (digit:4-a digit) depth)
     (chunked-for-each-node proc (digit:4-b digit) depth)
     (chunked-for-each-node proc (digit:4-c digit) depth)
     (chunked-for-each-node proc (digit:4-d digit) depth)]))

(define (chunked-for-each-tree proc tree depth)
  (cond
    [(ft:empty? tree) (void)]
    [(ft:single? tree)
     (chunked-for-each-node proc (ft:single-a tree) depth)]
    [else
     (chunked-for-each-digit proc (ft:deep-left tree) depth)
     (chunked-for-each-tree proc (ft:deep-inner tree) (add1 depth))
     (chunked-for-each-digit proc (ft:deep-right tree) depth)]))

(define (chunked-pvector-fold-sum pv)
  (define sum 0)
  (chunked-for-each-tree
   (lambda (x) (set! sum (+ sum x)))
   (chunked-pvector-tree pv)
   0)
  sum)

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
        (ft:deep new-total
                 (digit:2 node (digit:1-a left))
                 inner
                 right)]
       [(digit:2? left)
        (ft:deep new-total
                 (digit:3 node (digit:2-a left) (digit:2-b left))
                 inner
                 right)]
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
        (ft:deep new-total
                 left
                 inner
                 (digit:2 (digit:1-a right) node))]
       [(digit:2? right)
        (ft:deep new-total
                 left
                 inner
                 (digit:3 (digit:2-a right) (digit:2-b right) node))]
       [else
        (ft:deep new-total
                 left
                 inner
                 (digit:4 (digit:3-a right) (digit:3-b right) (digit:3-c right) node))])]))

(define (node->list node)
  (if (node:2? node)
      (list (node:2-a node) (node:2-b node))
      (list (node:3-a node) (node:3-b node) (node:3-c node))))

(define (digit->list digit)
  (cond
    [(digit:1? digit)
     (list (digit:1-a digit))]
    [(digit:2? digit)
     (list (digit:2-a digit) (digit:2-b digit))]
    [(digit:3? digit)
     (list (digit:3-a digit) (digit:3-b digit) (digit:3-c digit))]
    [else
     (list (digit:4-a digit) (digit:4-b digit) (digit:4-c digit) (digit:4-d digit))]))

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
    [(list a b)
     (ft:deep total (digit:1 a) empty-tree (digit:1 b))]
    [(list a b c)
     (ft:deep total (digit:1 a) empty-tree (digit:2 b c))]
    [(list a b c d)
     (ft:deep total (digit:2 a b) empty-tree (digit:2 c d))]))

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
    [(ft:empty? tree)
     (error 'tree-pop-left "empty tree")]
    [(ft:single? tree)
     (values (ft:single-a tree) empty-tree)]
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
        (define rest (cdr (digit->list left)))
        (values (car (digit->list left))
                (tree-build (list->digit rest) inner right depth))])]))

(define (tree-pop-right tree depth)
  (cond
    [(ft:empty? tree)
     (error 'tree-pop-right "empty tree")]
    [(ft:single? tree)
     (values (ft:single-a tree) empty-tree)]
    [else
     (define left (ft:deep-left tree))
     (define inner (ft:deep-inner tree))
     (define right (ft:deep-right tree))
     (cond
       [(digit:1? right)
        (define a (digit:1-a right))
        (cond
          [(ft:empty? inner)
           (define left-nodes (digit->list left))
           (match left-nodes
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
    [(ft:empty? tree)
     (error 'split-tree "empty tree")]
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

(define (chunk-slice chunk start end)
  (cond
    [(= start end) #f]
    [(and (zero? start) (= end (vector-length chunk))) chunk]
    [else (vector->immutable-vector (vector-copy chunk start end))]))

(define (chunked-subvector pv start end)
  (define len (chunked-pvector-length pv))
  (unless (and (exact-nonnegative-integer? start)
               (exact-nonnegative-integer? end)
               (<= start end)
               (<= end len))
    (error 'chunked-subvector "invalid range: ~a ~a" start end))
  (cond
    [(= start end)
     (chunked-pvector empty-tree 0 (chunked-pvector-chunk-size pv))]
    [(and (= start 0) (= end len))
     pv]
    [(zero? start)
     (chunked-take pv end)]
    [(= end len)
     (chunked-drop pv start)]
    [else
     (define-values (prefix after-end) (chunked-split-at pv end))
     (define-values (before-start middle) (chunked-split-at prefix start))
     middle]))

(define (chunked-take pv n)
  (define len (chunked-pvector-length pv))
  (unless (and (exact-nonnegative-integer? n) (<= n len))
    (error 'chunked-take "invalid length: ~a" n))
  (cond
    [(zero? n) (chunked-pvector empty-tree 0 (chunked-pvector-chunk-size pv))]
    [(= n len) pv]
    [else
     (define-values (left dropped-right) (chunked-split-at pv n))
     left]))

(define (chunked-drop pv n)
  (define len (chunked-pvector-length pv))
  (unless (and (exact-nonnegative-integer? n) (<= n len))
    (error 'chunked-drop "invalid length: ~a" n))
  (cond
    [(zero? n) pv]
    [(= n len) (chunked-pvector empty-tree 0 (chunked-pvector-chunk-size pv))]
    [else
     (define-values (dropped-left right) (chunked-split-at pv n))
     right]))

(define (chunked-split-at pv n)
  (define len (chunked-pvector-length pv))
  (unless (and (exact-nonnegative-integer? n) (<= n len))
    (error 'chunked-split-at "invalid split position: ~a" n))
  (define size (chunked-pvector-chunk-size pv))
  (cond
    [(zero? n)
     (values (chunked-pvector empty-tree 0 size) pv)]
    [(= n len)
     (values pv (chunked-pvector empty-tree 0 size))]
    [else
     (define-values (chunk-idx left chunk right)
       (split-tree (chunked-pvector-tree pv) n 0))
     (define prefix (chunk-slice chunk 0 chunk-idx))
     (define suffix (chunk-slice chunk chunk-idx (vector-length chunk)))
     (define left^
       (if prefix
           (tree-cons-right left prefix 0)
           left))
     (define right^
       (if suffix
           (tree-cons-left right suffix 0)
           right))
     (values (chunked-pvector left^ n size)
             (chunked-pvector right^ (- len n) size))]))

(define (shape-stats pv)
  (define h (make-hasheq))
  (define max-depth 0)
  (define (inc! k [n 1])
    (hash-set! h k (+ (hash-ref h k 0) n)))
  (define (note-depth! depth)
    (when (> depth max-depth)
      (set! max-depth depth)))
  (define (walk-node node depth)
    (note-depth! depth)
    (if (zero? depth)
        (begin
          (inc! 'chunks)
          (inc! 'leaves (vector-length node)))
        (let ([sub-depth (sub1 depth)])
          (if (node:2? node)
              (begin
                (inc! 'node2)
                (walk-node (node:2-a node) sub-depth)
                (walk-node (node:2-b node) sub-depth))
              (begin
                (inc! 'node3)
                (walk-node (node:3-a node) sub-depth)
                (walk-node (node:3-b node) sub-depth)
                (walk-node (node:3-c node) sub-depth))))))
  (define (walk-digit digit depth)
    (note-depth! depth)
    (inc! 'digits)
    (cond
      [(digit:1? digit)
       (walk-node (digit:1-a digit) depth)]
      [(digit:2? digit)
       (walk-node (digit:2-a digit) depth)
       (walk-node (digit:2-b digit) depth)]
      [(digit:3? digit)
       (walk-node (digit:3-a digit) depth)
       (walk-node (digit:3-b digit) depth)
       (walk-node (digit:3-c digit) depth)]
      [else
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
  h)

(define (href h k)
  (hash-ref h k 0))

(define (total-objects h)
  (+ (href h 'ft-empty)
     (href h 'ft-single)
     (href h 'ft-deep)
     (href h 'digits)
     (href h 'node2)
     (href h 'node3)
     (href h 'chunks)))

(define (build-list-data n)
  (for/list ([i (in-range n)]) i))

(define (build-vector-data n)
  (for/vector #:length n ([i (in-range n)]) i))

(define (summarize-value v)
  (cond
    [(list? v) (format "list:~a" (length v))]
    [(treelist? v) (format "treelist:~a" (treelist-length v))]
    [(cutie:pvector? v) (format "cutie-pvector:~a" (cutie:pvector-length v))]
    [(raw:pvector? v) (format "raw-pvector:~a" (raw:pvector-length v))]
    [(pvector? v) (format "pvector:~a" (pvector-length v))]
    [(chunked-pvector? v) (format "chunked-pvector:~a" (chunked-pvector-length v))]
    [else v]))

(define (bench op impl thunk)
  (when (enabled? op)
    (collect-garbage)
    (collect-garbage)
    (define-values (vals cpu real gc) (time-apply thunk null))
    (define result (if (pair? vals) (car vals) (void)))
    (printf "~a\t~a\t~a\t~a\t~a\t~a\n" op impl cpu real gc (summarize-value result))
    (flush-output)))

(define base-list (build-list-data N))
(define base-vector (list->vector base-list))
(define base-treelist (list->treelist base-list))
(define base-cutie-pvector (cutie:list->pvector base-list))
(define base-raw-pvector (raw:list->pvector base-list))
(define base-pvector (list->pvector base-list))
(define base-chunked-pvector (vector->chunked-pvector base-vector chunk-size))
(define half (quotient N 2))
(define quarter (quotient N 4))
(define three-quarter (- N quarter))

(define expected-sum (quotient (* N (sub1 N)) 2))
(for ([i (in-range N)])
  (unless (= (chunked-pvector-ref base-chunked-pvector i) i)
    (error 'chunked-pvector "ref self-check failed at index ~a" i)))
(unless (= (chunked-pvector-fold-sum base-chunked-pvector) expected-sum)
  (error 'chunked-pvector "iteration self-check failed"))

(define (check-split-at! pos)
  (define-values (left right) (chunked-split-at base-chunked-pvector pos))
  (unless (= (chunked-pvector-length left) pos)
    (error 'chunked-pvector "split-left length self-check failed at ~a" pos))
  (unless (= (chunked-pvector-length right) (- N pos))
    (error 'chunked-pvector "split-right length self-check failed at ~a" pos))
  (when (positive? pos)
    (unless (= (chunked-pvector-ref left (sub1 pos)) (sub1 pos))
      (error 'chunked-pvector "split-left ref self-check failed at ~a" pos)))
  (when (< pos N)
    (unless (= (chunked-pvector-ref right 0) pos)
      (error 'chunked-pvector "split-right ref self-check failed at ~a" pos))))

(define (check-subvector! start end)
  (define sub (chunked-subvector base-chunked-pvector start end))
  (define sub-len (- end start))
  (unless (= (chunked-pvector-length sub) sub-len)
    (error 'chunked-pvector "subvector length self-check failed at ~a ~a" start end))
  (when (positive? sub-len)
    (unless (= (chunked-pvector-ref sub 0) start)
      (error 'chunked-pvector "subvector first ref self-check failed at ~a ~a" start end))
    (unless (= (chunked-pvector-ref sub (sub1 sub-len)) (sub1 end))
      (error 'chunked-pvector "subvector last ref self-check failed at ~a ~a" start end))))

(define sample-split-positions
  (remove-duplicates
   (filter (lambda (pos) (and (exact-nonnegative-integer? pos) (<= pos N)))
           (list 0
                 1
                 (sub1 chunk-size)
                 chunk-size
                 (add1 chunk-size)
                 quarter
                 half
                 three-quarter
                 (sub1 N)
                 N))))

(for ([pos (in-list sample-split-positions)])
  (check-split-at! pos))

(check-subvector! 0 half)
(check-subvector! quarter three-quarter)
(check-subvector! half half)
(check-subvector! half N)

(define shape (shape-stats base-chunked-pvector))
(printf "M=~a N=~a chunk-size=~a\n" M N chunk-size)
(printf "shape\tmax-depth\tleaves\tchunks\tft-empty\tft-single\tft-deep\tdigits\tnode2\tnode3\tobjects\tobjects/elem\n")
(printf "shape\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\n"
        (href shape 'max-depth)
        (href shape 'leaves)
        (href shape 'chunks)
        (href shape 'ft-empty)
        (href shape 'ft-single)
        (href shape 'ft-deep)
        (href shape 'digits)
        (href shape 'node2)
        (href shape 'node3)
        (total-objects shape)
        (real->decimal-string (/ (total-objects shape) (max 1 N)) 4))
(printf "op\timpl\tcpu-ms\treal-ms\tgc-ms\tresult\n")

(bench 'build 'treelist
       (lambda ()
         (for/fold ([r base-treelist]) ([j (in-range M)])
           (list->treelist base-list))))
(bench 'build 'raw-pvector
       (lambda ()
         (for/fold ([r base-raw-pvector]) ([j (in-range M)])
           (raw:list->pvector base-list))))
(bench 'build 'pvector
       (lambda ()
         (for/fold ([r base-pvector]) ([j (in-range M)])
           (list->pvector base-list))))
(bench 'build 'chunked-pvector
       (lambda ()
         (for/fold ([r base-chunked-pvector]) ([j (in-range M)])
           (vector->chunked-pvector base-vector chunk-size))))

(bench 'ref-sequential 'treelist
       (lambda ()
         (for*/fold ([sum 0]) ([j (in-range M)] [i (in-range N)])
           (+ sum (treelist-ref base-treelist i)))))
(bench 'ref-sequential 'cutie-pvector
       (lambda ()
         (for*/fold ([sum 0]) ([j (in-range M)] [i (in-range N)])
           (+ sum (cutie:pvector-ref base-cutie-pvector i)))))
(bench 'ref-sequential 'raw-pvector
       (lambda ()
         (for*/fold ([sum 0]) ([j (in-range M)] [i (in-range N)])
           (+ sum (raw:pvector-ref base-raw-pvector i)))))
(bench 'ref-sequential 'pvector
       (lambda ()
         (for*/fold ([sum 0]) ([j (in-range M)] [i (in-range N)])
           (+ sum (pvector-ref base-pvector i)))))
(bench 'ref-sequential 'chunked-pvector
       (lambda ()
         (for*/fold ([sum 0]) ([j (in-range M)] [i (in-range N)])
           (+ sum (chunked-pvector-ref base-chunked-pvector i)))))

(bench 'iterate 'treelist
       (lambda ()
         (for*/fold ([sum 0]) ([j (in-range M)] [i (in-treelist base-treelist)])
           (+ sum i))))
(bench 'iterate 'cutie-pvector
       (lambda ()
         (for*/fold ([sum 0]) ([j (in-range M)] [i (cutie:in-pvector base-cutie-pvector)])
           (+ sum i))))
(bench 'iterate 'raw-pvector
       (lambda ()
         (for*/fold ([sum 0]) ([j (in-range M)] [i (raw:in-pvector base-raw-pvector)])
           (+ sum i))))
(bench 'iterate 'pvector
       (lambda ()
         (for*/fold ([sum 0]) ([j (in-range M)] [i (in-pvector base-pvector)])
           (+ sum i))))
(bench 'iterate 'chunked-pvector
       (lambda ()
         (for/fold ([sum 0]) ([j (in-range M)])
           (+ sum (chunked-pvector-fold-sum base-chunked-pvector)))))

(bench 'split-middle 'treelist
       (lambda ()
         (for/fold ([r null]) ([j (in-range M)])
           (list (treelist-take base-treelist half)
                 (treelist-drop base-treelist half)))))
(bench 'split-middle 'cutie-pvector
       (lambda ()
         (for/fold ([r null]) ([j (in-range M)])
           (define-values (left right) (cutie:pvector-split-at base-cutie-pvector half))
           (list left right))))
(bench 'split-middle 'raw-pvector
       (lambda ()
         (for/fold ([r null]) ([j (in-range M)])
           (define-values (left right) (raw:pvector-split-at base-raw-pvector half))
           (list left right))))
(bench 'split-middle 'pvector
       (lambda ()
         (for/fold ([r null]) ([j (in-range M)])
           (define-values (left right) (pvector-split-at base-pvector half))
           (list left right))))
(bench 'split-middle 'chunked-pvector
       (lambda ()
         (for/fold ([r null]) ([j (in-range M)])
           (define-values (left right) (chunked-split-at base-chunked-pvector half))
           (list left right))))

(bench 'take-middle 'treelist
       (lambda ()
         (for/fold ([r base-treelist]) ([j (in-range M)])
           (treelist-take base-treelist half))))
(bench 'take-middle 'cutie-pvector
       (lambda ()
         (for/fold ([r base-cutie-pvector]) ([j (in-range M)])
           (cutie:pvector-take base-cutie-pvector half))))
(bench 'take-middle 'raw-pvector
       (lambda ()
         (for/fold ([r base-raw-pvector]) ([j (in-range M)])
           (raw:pvector-take base-raw-pvector half))))
(bench 'take-middle 'pvector
       (lambda ()
         (for/fold ([r base-pvector]) ([j (in-range M)])
           (pvector-take base-pvector half))))
(bench 'take-middle 'chunked-pvector
       (lambda ()
         (for/fold ([r base-chunked-pvector]) ([j (in-range M)])
           (chunked-take base-chunked-pvector half))))

(bench 'drop-middle 'treelist
       (lambda ()
         (for/fold ([r base-treelist]) ([j (in-range M)])
           (treelist-drop base-treelist half))))
(bench 'drop-middle 'cutie-pvector
       (lambda ()
         (for/fold ([r base-cutie-pvector]) ([j (in-range M)])
           (cutie:pvector-drop base-cutie-pvector half))))
(bench 'drop-middle 'raw-pvector
       (lambda ()
         (for/fold ([r base-raw-pvector]) ([j (in-range M)])
           (raw:pvector-drop base-raw-pvector half))))
(bench 'drop-middle 'pvector
       (lambda ()
         (for/fold ([r base-pvector]) ([j (in-range M)])
           (pvector-drop base-pvector half))))
(bench 'drop-middle 'chunked-pvector
       (lambda ()
         (for/fold ([r base-chunked-pvector]) ([j (in-range M)])
           (chunked-drop base-chunked-pvector half))))

(bench 'subvector-middle 'treelist
       (lambda ()
         (for/fold ([r base-treelist]) ([j (in-range M)])
           (treelist-drop (treelist-take base-treelist three-quarter) quarter))))
(bench 'subvector-middle 'cutie-pvector
       (lambda ()
         (for/fold ([r base-cutie-pvector]) ([j (in-range M)])
           (cutie:pvector-copy base-cutie-pvector quarter three-quarter))))
(bench 'subvector-middle 'raw-pvector
       (lambda ()
         (for/fold ([r base-raw-pvector]) ([j (in-range M)])
           (raw:pvector-copy base-raw-pvector quarter three-quarter))))
(bench 'subvector-middle 'pvector
       (lambda ()
         (for/fold ([r base-pvector]) ([j (in-range M)])
           (pvector-subvector base-pvector quarter three-quarter))))
(bench 'subvector-middle 'chunked-pvector
       (lambda ()
         (for/fold ([r base-chunked-pvector]) ([j (in-range M)])
           (chunked-subvector base-chunked-pvector quarter three-quarter))))
