#lang racket/base

(require racket/list
         racket/match
         racket/vector
         racket/unsafe/ops
         (only-in "for.rkt"
                  define-sequence-syntax
                  range-sequence->exact-integer-range-info
                  range-sequence->exact-nonnegative-integer)
         "pvector-core.rkt"
         (for-syntax racket/base))

(provide pvector?
         pvector-empty
         pvector-empty?
         pvector
         make-pvector
         list->pvector
         pvector->list
         vector->pvector
         pvector->vector
         pvector->chunk-vector
         pvector->chunk-vector/shared
         pvector-lookup-chunk
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
(define endpoint-pack-limit 8)

(struct chunked-pvector (tree length chunk-size) #:sealed)
(struct leaf-chunk (vec start end) #:sealed)

(define empty-tree (ft:empty))
(define empty-pvector (chunked-pvector empty-tree 0 default-chunk-size))

(define (empty-pvector/size size)
  (if (= size default-chunk-size)
      empty-pvector
      (chunked-pvector empty-tree 0 size)))

(define pvector? chunked-pvector?)

(define (pvector-empty) empty-pvector)

(define (pvector-empty? pv)
  (and (chunked-pvector? pv)
       (zero? (chunked-pvector-length pv))))

(define (pvector-length pv)
  (chunked-pvector-length pv))

(define pvector-chunk-cache (make-weak-hasheq))

(define (pvector-cached-chunks pv)
  (hash-ref pvector-chunk-cache pv #f))

(define (fixed-chunks? chunks len size)
  (define chunk-count (vector-length chunks))
  (and (= chunk-count (quotient (+ len size -1) size))
       (let loop ([chunk-pos 0])
         (cond
           [(= chunk-pos chunk-count) #t]
           [else
            (define expected-len
              (if (= chunk-pos (sub1 chunk-count))
                  (- len (* chunk-pos size))
                  size))
            (and (= (chunk-length (vector-ref chunks chunk-pos)) expected-len)
                 (loop (add1 chunk-pos)))]))))

(define (install-fixed-chunk-cache! pv chunks len size)
  (when (fixed-chunks? chunks len size)
    (hash-set!
     pvector-chunk-cache
     pv
     (for/vector #:length (vector-length chunks)
                 ([chunk (in-vector chunks)])
       (chunk->plain-vector chunk))))
  pv)

(define (regular-chunk-size chunks chunk-count)
  (cond
    [(unsafe-fx= chunk-count 0) 1]
    [else
     (define size (unsafe-vector-length (unsafe-vector-ref chunks 0)))
     (and (unsafe-fx> size 0)
          (let loop ([chunk-pos 1])
            (cond
              [(unsafe-fx= chunk-pos chunk-count) size]
              [(unsafe-fx= chunk-pos (unsafe-fx- chunk-count 1))
               (and (unsafe-fx<= (unsafe-vector-length
                                   (unsafe-vector-ref chunks chunk-pos))
                                  size)
                    size)]
              [(unsafe-fx= (unsafe-vector-length
                            (unsafe-vector-ref chunks chunk-pos))
                           size)
               (loop (unsafe-fx+ chunk-pos 1))]
              [else #f])))]))

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
  (if (eq? (chunk-ref chunk idx) value)
      chunk
      (let ([vec
             (if (vector? chunk)
                 (vector-copy chunk)
                 (vector-copy (leaf-chunk-vec chunk)
                              (leaf-chunk-start chunk)
                              (leaf-chunk-end chunk)))])
        (vector-set! vec idx value)
        (vector->immutable-vector vec))))

(define (chunk-insert chunk idx value)
  (define len (chunk-length chunk))
  (define vec (make-vector (add1 len)))
  (for ([i (in-range idx)])
    (vector-set! vec i (chunk-ref chunk i)))
  (vector-set! vec idx value)
  (for ([i (in-range idx len)])
    (vector-set! vec (add1 i) (chunk-ref chunk i)))
  (vector->immutable-vector vec))

(define (chunk-delete chunk idx)
  (define len (chunk-length chunk))
  (define vec (make-vector (sub1 len)))
  (for ([i (in-range idx)])
    (vector-set! vec i (chunk-ref chunk i)))
  (for ([i (in-range (add1 idx) len)])
    (vector-set! vec (sub1 i) (chunk-ref chunk i)))
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

(define (chunk-for-each-reverse proc chunk)
  (cond
    [(vector? chunk)
     (for ([i (in-range (sub1 (vector-length chunk)) -1 -1)])
       (proc (vector-ref chunk i)))]
    [else
     (define vec (leaf-chunk-vec chunk))
     (for ([i (in-range (sub1 (leaf-chunk-end chunk))
                        (sub1 (leaf-chunk-start chunk))
                        -1)])
       (proc (vector-ref vec i)))]))

(define (chunk-copy-to-vector! dest dest-start chunk)
  (if (vector? chunk)
      (vector-copy! dest dest-start chunk)
      (vector-copy! dest dest-start
                    (leaf-chunk-vec chunk)
                    (leaf-chunk-start chunk)
                    (leaf-chunk-end chunk))))

(define (chunk->vector chunk)
  (if (vector? chunk)
      (vector-copy chunk)
      (vector-copy (leaf-chunk-vec chunk)
                   (leaf-chunk-start chunk)
                   (leaf-chunk-end chunk))))

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

(define (chunk-append-chunk left right)
  (define left-len (chunk-length left))
  (define right-len (chunk-length right))
  (define vec (make-vector (+ left-len right-len)))
  (chunk-copy-to-vector! vec 0 left)
  (chunk-copy-to-vector! vec left-len right)
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
  (define chunk-count
    (if (zero? len)
        0
        (unsafe-fx+ (unsafe-fxquotient (unsafe-fx- len 1) size) 1)))
  (define chunks (make-vector chunk-count))
  (let chunk-loop ([chunk-idx 0])
    (unless (unsafe-fx= chunk-idx chunk-count)
      (define start (unsafe-fx* chunk-idx size))
      (define remaining (unsafe-fx- len start))
      (define chunk-len
        (if (unsafe-fx< remaining size) remaining size))
      (define end (unsafe-fx+ start chunk-len))
      (unsafe-vector-set! chunks
                          chunk-idx
                          (vector->immutable-vector
                           (vector-copy vec start end)))
      (chunk-loop (unsafe-fx+ chunk-idx 1))))
  chunks)

(define (chunks->pvector chunks len [size default-chunk-size])
  (if (zero? len)
      (empty-pvector/size size)
      (install-fixed-chunk-cache!
       (chunked-pvector (nodes-vector->tree chunks len 0) len size)
       chunks
       len
       size)))

(define (make-pvector-builder [size default-chunk-size])
  (define chunks '())
  (define chunk-count 0)
  (define len 0)
  (define chunk (make-vector size))
  (define chunk-pos 0)
  (define (flush!)
    (when (positive? chunk-pos)
      (define chunk*
        (if (= chunk-pos size)
            chunk
            (vector-copy chunk 0 chunk-pos)))
      (set! chunks (cons (vector->immutable-vector chunk*) chunks))
      (set! chunk-count (add1 chunk-count))
      (set! chunk (make-vector size))
      (set! chunk-pos 0)))
  (define (add! value)
    (vector-set! chunk chunk-pos value)
    (set! chunk-pos (add1 chunk-pos))
    (set! len (add1 len))
    (when (= chunk-pos size)
      (flush!)))
  (define (finish)
    (flush!)
    (define chunk-vector (make-vector chunk-count))
    (let loop ([chunks chunks] [chunk-idx (sub1 chunk-count)])
      (unless (null? chunks)
        (vector-set! chunk-vector chunk-idx (car chunks))
        (loop (cdr chunks) (sub1 chunk-idx))))
    (chunks->pvector chunk-vector len size))
  (values add! finish))

(define (vector->pvector vec)
  (define len (vector-length vec))
  (chunks->pvector (vector->chunks vec default-chunk-size) len default-chunk-size))

(define (list->pvector lst)
  (define len (length lst))
  (cond
    [(zero? len) empty-pvector]
    [(fixnum? len)
     (define size default-chunk-size)
     (define chunk-count
       (unsafe-fx+ (unsafe-fxquotient (unsafe-fx- len 1) size) 1))
     (define chunks (make-vector chunk-count))
     (let chunk-loop ([chunk-idx 0] [rest lst])
       (unless (unsafe-fx= chunk-idx chunk-count)
         (define range-start (unsafe-fx* chunk-idx size))
         (define remaining (unsafe-fx- len range-start))
         (define chunk-len
           (if (unsafe-fx< remaining size) remaining size))
         (define chunk (make-vector chunk-len))
         (define next-rest
           (let elem-loop ([elem-idx 0] [rest rest])
             (if (unsafe-fx= elem-idx chunk-len)
                 rest
                 (begin
                   (unsafe-vector-set! chunk elem-idx (unsafe-car rest))
                   (elem-loop (unsafe-fx+ elem-idx 1)
                              (unsafe-cdr rest))))))
         (unsafe-vector-set! chunks
                             chunk-idx
                             (vector->immutable-vector chunk))
         (chunk-loop (unsafe-fx+ chunk-idx 1) next-rest)))
     (chunks->pvector chunks len size)]
    [else
     (define-values (add! finish) (make-pvector-builder))
     (for ([elem (in-list lst)])
       (add! elem))
     (finish)]))

(define (make-pvector n [value #f])
  (cond
    [(zero? n) empty-pvector]
    [else
     (define chunk-count (quotient (+ n default-chunk-size -1) default-chunk-size))
     (define chunks
       (for/vector #:length chunk-count ([chunk-idx (in-range chunk-count)])
         (define start (* chunk-idx default-chunk-size))
         (define len (min default-chunk-size (- n start)))
         (vector->immutable-vector (make-vector len value))))
     (chunks->pvector chunks n default-chunk-size)]))

(define (pvector . elems)
  (list->pvector elems))

(define (integer-range->pvector len)
  (cond
    [(zero? len) empty-pvector]
    [else
     (define size default-chunk-size)
     (define chunk-count
       (unsafe-fx+ (unsafe-fxquotient (unsafe-fx- len 1) size) 1))
     (define chunks (make-vector chunk-count))
     (let chunk-loop ([chunk-idx 0])
       (unless (unsafe-fx= chunk-idx chunk-count)
         (define range-start (unsafe-fx* chunk-idx size))
         (define remaining (unsafe-fx- len range-start))
         (define chunk-len
           (if (unsafe-fx< remaining size) remaining size))
         (define chunk (make-vector chunk-len))
         (let elem-loop ([elem-idx 0])
           (unless (unsafe-fx= elem-idx chunk-len)
             (unsafe-vector-set! chunk
                                 elem-idx
                                 (unsafe-fx+ range-start elem-idx))
             (elem-loop (unsafe-fx+ elem-idx 1))))
         (unsafe-vector-set! chunks
                             chunk-idx
                             (vector->immutable-vector chunk))
         (chunk-loop (unsafe-fx+ chunk-idx 1))))
     (chunks->pvector chunks len size)]))

(define (arithmetic-range->pvector start step len)
  (cond
    [(zero? len) empty-pvector]
    [else
     (define size default-chunk-size)
     (define chunk-count
       (unsafe-fx+ (unsafe-fxquotient (unsafe-fx- len 1) size) 1))
     (define chunks (make-vector chunk-count))
     (let chunk-loop ([chunk-idx 0])
       (unless (unsafe-fx= chunk-idx chunk-count)
         (define range-start (unsafe-fx* chunk-idx size))
         (define remaining (unsafe-fx- len range-start))
         (define chunk-len
           (if (unsafe-fx< remaining size) remaining size))
         (define chunk (make-vector chunk-len))
         (let elem-loop ([elem-idx 0]
                         [elem (+ start (* range-start step))])
           (unless (unsafe-fx= elem-idx chunk-len)
             (unsafe-vector-set! chunk elem-idx elem)
             (elem-loop (unsafe-fx+ elem-idx 1) (+ elem step))))
         (unsafe-vector-set! chunks
                             chunk-idx
                             (vector->immutable-vector chunk))
         (chunk-loop (unsafe-fx+ chunk-idx 1))))
     (chunks->pvector chunks len size)]))

(define (arithmetic-range-info->pvector info)
  (define start (vector-ref info 0))
  (define step (vector-ref info 1))
  (define len (vector-ref info 2))
  (if (fixnum? len)
      (arithmetic-range->pvector start step len)
      (let ()
        (define-values (add! finish) (make-pvector-builder))
        (for ([elem (in-range start (+ start (* len step)) step)])
          (add! elem))
        (finish))))

(define (sequence->pvector seq)
  (cond
    [(chunked-pvector? seq) seq]
    [(list? seq) (list->pvector seq)]
    [(vector? seq) (vector->pvector seq)]
    [(exact-nonnegative-integer? seq)
     (if (fixnum? seq)
         (integer-range->pvector seq)
         (let ()
           (define-values (add! finish) (make-pvector-builder))
           (for ([elem seq])
             (add! elem))
           (finish)))]
    [(range-sequence->exact-nonnegative-integer seq)
     => (lambda (len)
          (if (fixnum? len)
              (integer-range->pvector len)
              (let ()
                (define-values (add! finish) (make-pvector-builder))
                (for ([elem seq])
                  (add! elem))
                (finish))))]
    [(range-sequence->exact-integer-range-info seq)
     => arithmetic-range-info->pvector]
    [else
     (define-values (add! finish) (make-pvector-builder))
     (for ([elem seq])
       (add! elem))
     (finish)]))

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
  (define cached-chunks (pvector-cached-chunks pv))
  (if (and cached-chunks
           (fixnum? idx)
           (unsafe-fx>= idx 0)
           (unsafe-fx< idx (chunked-pvector-length pv)))
      (let* ([size (chunked-pvector-chunk-size pv)]
             [chunk-pos (unsafe-fxquotient idx size)]
             [chunk (unsafe-vector-ref cached-chunks chunk-pos)])
        (unsafe-vector-ref chunk
                           (unsafe-fx- idx
                                       (unsafe-fx* chunk-pos size))))
      (let ([tree (chunked-pvector-tree pv)])
        (cond
          [(ft:single? tree)
           (chunk-ref (ft:single-a tree) idx)]
          [(ft:deep? tree)
           (define left (ft:deep-left tree))
           (define inner (ft:deep-inner tree))
           (define right (ft:deep-right tree))
           (define left-size (digit-size left 0))
           (define inner-size (tree-size inner 1))
           (define left+inner-size (+ left-size inner-size))
           (cond
             [(< idx left-size) (ref-digit left idx 0)]
             [(< idx left+inner-size) (ref-tree inner (- idx left-size) 1)]
             [else (ref-digit right (- idx left+inner-size) 0)])]
          [else
           (error 'pvector-ref "index out of bounds")]))))

(define pvector-ref/fast pvector-ref)

(define (lookup-chunk-node node idx depth)
  (if (zero? depth)
      (values idx node)
      (let ([sub-depth (sub1 depth)])
        (cond
          [(node:2? node)
           (define a (node:2-a node))
           (define a-size (node-size a sub-depth))
           (if (< idx a-size)
               (lookup-chunk-node a idx sub-depth)
               (lookup-chunk-node (node:2-b node) (- idx a-size) sub-depth))]
          [else
           (define a (node:3-a node))
           (define b (node:3-b node))
           (define a-size (node-size a sub-depth))
           (define b-size (node-size b sub-depth))
           (define ab-size (+ a-size b-size))
           (cond
             [(< idx a-size) (lookup-chunk-node a idx sub-depth)]
             [(< idx ab-size) (lookup-chunk-node b (- idx a-size) sub-depth)]
             [else (lookup-chunk-node (node:3-c node) (- idx ab-size) sub-depth)])]))))

(define (lookup-chunk-digit digit idx depth)
  (cond
    [(digit:1? digit)
     (lookup-chunk-node (digit:1-a digit) idx depth)]
    [(digit:2? digit)
     (define a (digit:2-a digit))
     (define a-size (node-size a depth))
     (if (< idx a-size)
         (lookup-chunk-node a idx depth)
         (lookup-chunk-node (digit:2-b digit) (- idx a-size) depth))]
    [(digit:3? digit)
     (define a (digit:3-a digit))
     (define b (digit:3-b digit))
     (define a-size (node-size a depth))
     (define b-size (node-size b depth))
     (define ab-size (+ a-size b-size))
     (cond
       [(< idx a-size) (lookup-chunk-node a idx depth)]
       [(< idx ab-size) (lookup-chunk-node b (- idx a-size) depth)]
       [else (lookup-chunk-node (digit:3-c digit) (- idx ab-size) depth)])]
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
       [(< idx a-size) (lookup-chunk-node a idx depth)]
       [(< idx ab-size) (lookup-chunk-node b (- idx a-size) depth)]
       [(< idx abc-size) (lookup-chunk-node c (- idx ab-size) depth)]
       [else (lookup-chunk-node (digit:4-d digit) (- idx abc-size) depth)])]))

(define (lookup-chunk-tree tree idx depth)
  (cond
    [(ft:single? tree)
     (lookup-chunk-node (ft:single-a tree) idx depth)]
    [(ft:deep? tree)
     (define left (ft:deep-left tree))
     (define inner (ft:deep-inner tree))
     (define right (ft:deep-right tree))
     (define inner-depth (add1 depth))
     (define left-size (digit-size left depth))
     (define inner-size (tree-size inner inner-depth))
     (define left+inner-size (+ left-size inner-size))
     (cond
       [(< idx left-size) (lookup-chunk-digit left idx depth)]
       [(< idx left+inner-size) (lookup-chunk-tree inner (- idx left-size) inner-depth)]
       [else (lookup-chunk-digit right (- idx left+inner-size) depth)])]
    [else
     (error 'pvector-copy "index out of bounds")]))

(define (maybe-node:2 node a b)
  (if (and (eq? a (node:2-a node))
           (eq? b (node:2-b node)))
      node
      (node:2 (node:2-v node) a b)))

(define (maybe-node:3 node a b c)
  (if (and (eq? a (node:3-a node))
           (eq? b (node:3-b node))
           (eq? c (node:3-c node)))
      node
      (node:3 (node:3-v node) a b c)))

(define (maybe-digit:1 digit a)
  (if (eq? a (digit:1-a digit))
      digit
      (digit:1 a)))

(define (maybe-digit:2 digit a b)
  (if (and (eq? a (digit:2-a digit))
           (eq? b (digit:2-b digit)))
      digit
      (digit:2 a b)))

(define (maybe-digit:3 digit a b c)
  (if (and (eq? a (digit:3-a digit))
           (eq? b (digit:3-b digit))
           (eq? c (digit:3-c digit)))
      digit
      (digit:3 a b c)))

(define (maybe-digit:4 digit a b c d)
  (if (and (eq? a (digit:4-a digit))
           (eq? b (digit:4-b digit))
           (eq? c (digit:4-c digit))
           (eq? d (digit:4-d digit)))
      digit
      (digit:4 a b c d)))

(define (maybe-ft:single tree a)
  (if (eq? a (ft:single-a tree))
      tree
      (ft:single a)))

(define (maybe-ft:deep tree left inner right)
  (if (and (eq? left (ft:deep-left tree))
           (eq? inner (ft:deep-inner tree))
           (eq? right (ft:deep-right tree)))
      tree
      (ft:deep (ft:deep-v tree) left inner right)))

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
               (maybe-node:2 node (set-node a idx value sub-depth) b)
               (maybe-node:2 node a (set-node b (- idx a-size) value sub-depth)))]
          [else
           (define a (node:3-a node))
           (define b (node:3-b node))
           (define c (node:3-c node))
           (define a-size (node-size a sub-depth))
           (define b-size (node-size b sub-depth))
           (define ab-size (+ a-size b-size))
           (cond
             [(< idx a-size)
              (maybe-node:3 node (set-node a idx value sub-depth) b c)]
             [(< idx ab-size)
              (maybe-node:3 node a (set-node b (- idx a-size) value sub-depth) c)]
             [else
              (maybe-node:3 node a b (set-node c (- idx ab-size) value sub-depth))])]))))

(define (set-digit digit idx value depth)
  (cond
    [(digit:1? digit)
     (maybe-digit:1 digit (set-node (digit:1-a digit) idx value depth))]
    [(digit:2? digit)
     (define a (digit:2-a digit))
     (define b (digit:2-b digit))
     (define a-size (node-size a depth))
     (if (< idx a-size)
         (maybe-digit:2 digit (set-node a idx value depth) b)
         (maybe-digit:2 digit a (set-node b (- idx a-size) value depth)))]
    [(digit:3? digit)
     (define a (digit:3-a digit))
     (define b (digit:3-b digit))
     (define c (digit:3-c digit))
     (define a-size (node-size a depth))
     (define b-size (node-size b depth))
     (define ab-size (+ a-size b-size))
     (cond
       [(< idx a-size) (maybe-digit:3 digit (set-node a idx value depth) b c)]
       [(< idx ab-size) (maybe-digit:3 digit a (set-node b (- idx a-size) value depth) c)]
       [else (maybe-digit:3 digit a b (set-node c (- idx ab-size) value depth))])]
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
       [(< idx a-size) (maybe-digit:4 digit (set-node a idx value depth) b c d)]
       [(< idx ab-size) (maybe-digit:4 digit a (set-node b (- idx a-size) value depth) c d)]
       [(< idx abc-size) (maybe-digit:4 digit a b (set-node c (- idx ab-size) value depth) d)]
       [else (maybe-digit:4 digit a b c (set-node d (- idx abc-size) value depth))])]))

(define (set-tree tree idx value depth)
  (cond
    [(ft:single? tree)
     (maybe-ft:single tree (set-node (ft:single-a tree) idx value depth))]
    [(ft:deep? tree)
     (define left (ft:deep-left tree))
     (define inner (ft:deep-inner tree))
     (define right (ft:deep-right tree))
     (define inner-depth (add1 depth))
     (define left-size (digit-size left depth))
     (define inner-size (tree-size inner inner-depth))
     (define left+inner-size (+ left-size inner-size))
     (cond
       [(< idx left-size)
        (maybe-ft:deep tree (set-digit left idx value depth) inner right)]
       [(< idx left+inner-size)
        (maybe-ft:deep tree left (set-tree inner (- idx left-size) value inner-depth) right)]
       [else
        (maybe-ft:deep tree left inner (set-digit right (- idx left+inner-size) value depth))])]
    [else
     (error 'pvector-set "index out of bounds")]))

(define (pvector-set/tree pv idx value)
  (define tree (chunked-pvector-tree pv))
  (define tree^
    (if (ft:single? tree)
        (maybe-ft:single tree (chunk-set (ft:single-a tree) idx value))
        (if (ft:deep? tree)
            (let ()
              (define left (ft:deep-left tree))
              (define inner (ft:deep-inner tree))
              (define right (ft:deep-right tree))
              (define left-size (digit-size left 0))
              (define inner-size (tree-size inner 1))
              (define left+inner-size (+ left-size inner-size))
              (cond
                [(< idx left-size)
                 (maybe-ft:deep tree (set-digit left idx value 0) inner right)]
                [(< idx left+inner-size)
                 (maybe-ft:deep tree
                                left
                                (set-tree inner (- idx left-size) value 1)
                                right)]
                [else
                 (maybe-ft:deep tree
                                left
                                inner
                                (set-digit right (- idx left+inner-size) value 0))]))
            (set-tree tree idx value 0))))
  (if (eq? tree^ tree)
      pv
      (chunked-pvector tree^
                       (chunked-pvector-length pv)
                       (chunked-pvector-chunk-size pv))))

(define (pvector-set/cached pv cached-chunks idx value)
  (define size (chunked-pvector-chunk-size pv))
  (define chunk-pos (unsafe-fxquotient idx size))
  (define elem-idx (unsafe-fx- idx (unsafe-fx* chunk-pos size)))
  (define chunk (unsafe-vector-ref cached-chunks chunk-pos))
  (if (eq? (chunk-ref chunk elem-idx) value)
      pv
      (pvector-set/tree pv idx value)))

(define (pvector-set pv idx value)
  (define cached-chunks (pvector-cached-chunks pv))
  (if (and cached-chunks
           (fixnum? idx)
           (unsafe-fx>= idx 0)
           (unsafe-fx< idx (chunked-pvector-length pv)))
      (pvector-set/cached pv cached-chunks idx value)
      (pvector-set/tree pv idx value)))

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
  (cond
    [(digit:1? digit)
     (define a (digit:1-a digit))
     (define a-size (node-size a depth))
     (if (< idx a-size)
         (values idx '() a '())
         (error 'split-digit "index out of digit: ~a" idx))]
    [(digit:2? digit)
     (define a (digit:2-a digit))
     (define b (digit:2-b digit))
     (define a-size (node-size a depth))
     (define ab-size (+ a-size (node-size b depth)))
     (cond
       [(< idx a-size)
        (values idx '() a (list b))]
       [(< idx ab-size)
        (values (- idx a-size) (list a) b '())]
       [else
        (error 'split-digit "index out of digit: ~a" idx)])]
    [(digit:3? digit)
     (define a (digit:3-a digit))
     (define b (digit:3-b digit))
     (define c (digit:3-c digit))
     (define a-size (node-size a depth))
     (define b-size (node-size b depth))
     (define ab-size (+ a-size b-size))
     (define abc-size (+ ab-size (node-size c depth)))
     (cond
       [(< idx a-size)
        (values idx '() a (list b c))]
       [(< idx ab-size)
        (values (- idx a-size) (list a) b (list c))]
       [(< idx abc-size)
        (values (- idx ab-size) (list a b) c '())]
       [else
        (error 'split-digit "index out of digit: ~a" idx)])]
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
     (define abcd-size (+ abc-size (node-size d depth)))
     (cond
       [(< idx a-size)
        (values idx '() a (list b c d))]
       [(< idx ab-size)
        (values (- idx a-size) (list a) b (list c d))]
       [(< idx abc-size)
        (values (- idx ab-size) (list a b) c (list d))]
       [(< idx abcd-size)
        (values (- idx abc-size) (list a b c) d '())]
       [else
        (error 'split-digit "index out of digit: ~a" idx)])]))

(define (split-node node idx depth)
  (define sub-depth (sub1 depth))
  (cond
    [(node:2? node)
     (define a (node:2-a node))
     (define b (node:2-b node))
     (define a-size (node-size a sub-depth))
     (define ab-size (+ a-size (node-size b sub-depth)))
     (cond
       [(< idx a-size)
        (values idx '() a (list b))]
       [(< idx ab-size)
        (values (- idx a-size) (list a) b '())]
       [else
        (error 'split-node "index out of node: ~a" idx)])]
    [else
     (define a (node:3-a node))
     (define b (node:3-b node))
     (define c (node:3-c node))
     (define a-size (node-size a sub-depth))
     (define b-size (node-size b sub-depth))
     (define ab-size (+ a-size b-size))
     (define abc-size (+ ab-size (node-size c sub-depth)))
     (cond
       [(< idx a-size)
        (values idx '() a (list b c))]
       [(< idx ab-size)
        (values (- idx a-size) (list a) b (list c))]
       [(< idx abc-size)
        (values (- idx ab-size) (list a b) c '())]
       [else
        (error 'split-node "index out of node: ~a" idx)])]))

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

(define (insert-node/direct node idx value depth size)
  (if (zero? depth)
      (if (< (chunk-length node) size)
          (values (chunk-insert node idx value) #t)
          (values #f #f))
      (let ([sub-depth (sub1 depth)])
        (cond
          [(node:2? node)
           (define a (node:2-a node))
           (define b (node:2-b node))
           (define a-size (node-size a sub-depth))
           (if (< idx a-size)
               (let-values ([(a^ ok?) (insert-node/direct a idx value sub-depth size)])
                 (if ok?
                     (values (node:2 (add1 (node:2-v node)) a^ b) #t)
                     (values #f #f)))
               (let-values ([(b^ ok?) (insert-node/direct b (- idx a-size) value sub-depth size)])
                 (if ok?
                     (values (node:2 (add1 (node:2-v node)) a b^) #t)
                     (values #f #f))))]
          [else
           (define a (node:3-a node))
           (define b (node:3-b node))
           (define c (node:3-c node))
           (define a-size (node-size a sub-depth))
           (define b-size (node-size b sub-depth))
           (define ab-size (+ a-size b-size))
           (cond
             [(< idx a-size)
              (let-values ([(a^ ok?) (insert-node/direct a idx value sub-depth size)])
                (if ok?
                    (values (node:3 (add1 (node:3-v node)) a^ b c) #t)
                    (values #f #f)))]
             [(< idx ab-size)
              (let-values ([(b^ ok?) (insert-node/direct b (- idx a-size) value sub-depth size)])
                (if ok?
                    (values (node:3 (add1 (node:3-v node)) a b^ c) #t)
                    (values #f #f)))]
             [else
              (let-values ([(c^ ok?) (insert-node/direct c (- idx ab-size) value sub-depth size)])
                (if ok?
                    (values (node:3 (add1 (node:3-v node)) a b c^) #t)
                    (values #f #f)))])]))))

(define (insert-digit/direct digit idx value depth size)
  (cond
    [(digit:1? digit)
     (define a (digit:1-a digit))
     (define-values (a^ ok?) (insert-node/direct a idx value depth size))
     (if ok?
         (values (digit:1 a^) #t)
         (values #f #f))]
    [(digit:2? digit)
     (define a (digit:2-a digit))
     (define b (digit:2-b digit))
     (define a-size (node-size a depth))
     (if (< idx a-size)
         (let-values ([(a^ ok?) (insert-node/direct a idx value depth size)])
           (if ok?
               (values (digit:2 a^ b) #t)
               (values #f #f)))
         (let-values ([(b^ ok?) (insert-node/direct b (- idx a-size) value depth size)])
           (if ok?
               (values (digit:2 a b^) #t)
               (values #f #f))))]
    [(digit:3? digit)
     (define a (digit:3-a digit))
     (define b (digit:3-b digit))
     (define c (digit:3-c digit))
     (define a-size (node-size a depth))
     (define b-size (node-size b depth))
     (define ab-size (+ a-size b-size))
     (cond
       [(< idx a-size)
        (let-values ([(a^ ok?) (insert-node/direct a idx value depth size)])
          (if ok?
              (values (digit:3 a^ b c) #t)
              (values #f #f)))]
       [(< idx ab-size)
        (let-values ([(b^ ok?) (insert-node/direct b (- idx a-size) value depth size)])
          (if ok?
              (values (digit:3 a b^ c) #t)
              (values #f #f)))]
       [else
        (let-values ([(c^ ok?) (insert-node/direct c (- idx ab-size) value depth size)])
          (if ok?
              (values (digit:3 a b c^) #t)
              (values #f #f)))])]
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
       [(< idx a-size)
        (let-values ([(a^ ok?) (insert-node/direct a idx value depth size)])
          (if ok?
              (values (digit:4 a^ b c d) #t)
              (values #f #f)))]
       [(< idx ab-size)
        (let-values ([(b^ ok?) (insert-node/direct b (- idx a-size) value depth size)])
          (if ok?
              (values (digit:4 a b^ c d) #t)
              (values #f #f)))]
       [(< idx abc-size)
        (let-values ([(c^ ok?) (insert-node/direct c (- idx ab-size) value depth size)])
          (if ok?
              (values (digit:4 a b c^ d) #t)
              (values #f #f)))]
       [else
        (let-values ([(d^ ok?) (insert-node/direct d (- idx abc-size) value depth size)])
          (if ok?
              (values (digit:4 a b c d^) #t)
              (values #f #f)))])]))

(define (insert-tree/fused tree idx value depth size)
  (cond
    [(ft:empty? tree) (error 'insert-tree/fused "empty tree")]
    [(ft:single? tree)
     (define node (ft:single-a tree))
     (when (>= idx (node-size node depth))
       (error 'insert-tree/fused "index out of single node: ~a" idx))
     (define-values (node^ ok?) (insert-node/direct node idx value depth size))
     (if ok?
         (values #t (ft:single node^) #f #f #f)
         (values #f idx empty-tree node empty-tree))]
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
        (define-values (left^ ok?) (insert-digit/direct left idx value depth size))
        (if ok?
            (values #t (ft:deep (add1 total) left^ inner right) #f #f #f)
            (let-values ([(idx^ l node r) (split-digit left idx depth)])
              (define left^ (digit-list->tree l depth))
              (define right^
                (cond
                  [(ft:empty? inner)
                   (digit-list2->tree (append r (digit->list right)) depth)]
                  [else
                   (define-values (right-digit inner^)
                     (digit-list+tree->digit r inner depth tree-pop-left))
                   (tree-build right-digit inner^ right depth)]))
              (values #f idx^ left^ node right^)))]
       [(< idx left+inner-size)
        (define-values (direct? a b c d)
          (insert-tree/fused inner (- idx left-size) value inner-depth size))
        (if direct?
            (values #t (ft:deep (add1 total) left a right) #f #f #f)
            (let ([rest-idx a]
                  [inner-left b]
                  [node c]
                  [inner-right d])
              (define left^ (left-digit+tree->tree left inner-left depth))
              (define right^ (right-digit+tree->tree right inner-right depth))
              (define-values (idx^ l node^ r) (split-node node rest-idx inner-depth))
              (define left^^
                (for/fold ([acc left^]) ([child (in-list l)])
                  (tree-cons-right acc child depth)))
              (define right^^
                (for/foldr ([acc right^]) ([child (in-list r)])
                  (tree-cons-left acc child depth)))
              (values #f idx^ left^^ node^ right^^)))]
       [(< idx total)
        (define-values (right^ ok?)
          (insert-digit/direct right (- idx left+inner-size) value depth size))
        (if ok?
            (values #t (ft:deep (add1 total) left inner right^) #f #f #f)
            (let-values ([(idx^ l node r)
                          (split-digit right (- idx left+inner-size) depth)])
              (define right^ (digit-list->tree r depth))
              (define left^
                (cond
                  [(ft:empty? inner)
                   (digit-list2->tree (append (digit->list left) l) depth)]
                  [else
                   (define-values (left-digit inner^)
                     (digit-list+tree->digit l inner depth tree-pop-right))
                   (tree-build left inner^ left-digit depth)]))
              (values #f idx^ left^ node right^)))]
       [else
        (error 'insert-tree/fused "index out of tree: ~a" idx)])]))

(define (split-tree-left tree idx depth)
  (cond
    [(ft:empty? tree) (error 'split-tree-left "empty tree")]
    [(ft:single? tree)
     (define node (ft:single-a tree))
     (when (>= idx (node-size node depth))
       (error 'split-tree-left "index out of single node: ~a" idx))
     (values idx empty-tree node)]
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
        (values idx^ (digit-list->tree l depth) node)]
       [(< idx left+inner-size)
        (define-values (rest-idx inner-left node)
          (split-tree-left inner (- idx left-size) inner-depth))
        (define left^ (left-digit+tree->tree left inner-left depth))
        (define-values (idx^ l node^ r) (split-node node rest-idx inner-depth))
        (define left^^
          (for/fold ([acc left^]) ([child (in-list l)])
            (tree-cons-right acc child depth)))
        (values idx^ left^^ node^)]
       [(< idx total)
        (define-values (idx^ l node r)
          (split-digit right (- idx left+inner-size) depth))
        (define left^
          (cond
            [(ft:empty? inner)
             (digit-list2->tree (append (digit->list left) l) depth)]
            [else
             (define-values (left-digit inner^)
               (digit-list+tree->digit l inner depth tree-pop-right))
             (tree-build left inner^ left-digit depth)]))
        (values idx^ left^ node)]
       [else
        (error 'split-tree-left "index out of tree: ~a" idx)])]))

(define (split-tree-right tree idx depth)
  (cond
    [(ft:empty? tree) (error 'split-tree-right "empty tree")]
    [(ft:single? tree)
     (define node (ft:single-a tree))
     (when (>= idx (node-size node depth))
       (error 'split-tree-right "index out of single node: ~a" idx))
     (values idx node empty-tree)]
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
        (define right^
          (cond
            [(ft:empty? inner)
             (digit-list2->tree (append r (digit->list right)) depth)]
            [else
             (define-values (right-digit inner^)
               (digit-list+tree->digit r inner depth tree-pop-left))
             (tree-build right-digit inner^ right depth)]))
        (values idx^ node right^)]
       [(< idx left+inner-size)
        (define-values (rest-idx node inner-right)
          (split-tree-right inner (- idx left-size) inner-depth))
        (define right^ (right-digit+tree->tree right inner-right depth))
        (define-values (idx^ l node^ r) (split-node node rest-idx inner-depth))
        (define right^^
          (for/foldr ([acc right^]) ([child (in-list r)])
            (tree-cons-left acc child depth)))
        (values idx^ node^ right^^)]
       [(< idx total)
        (define-values (idx^ l node r)
          (split-digit right (- idx left+inner-size) depth))
        (values idx^ node (digit-list->tree r depth))]
       [else
        (error 'split-tree-right "index out of tree: ~a" idx)])]))

(define (pvector-split-at pv pos)
  (define len (chunked-pvector-length pv))
  (define size (chunked-pvector-chunk-size pv))
  (cond
    [(zero? pos)
     (values (empty-pvector/size size) pv)]
    [(= pos len)
     (values pv (empty-pvector/size size))]
    [else
     (define tree (chunked-pvector-tree pv))
     (cond
       [(ft:single? tree)
        (define chunk (ft:single-a tree))
        (define prefix (chunk-slice chunk 0 pos))
        (define suffix (chunk-slice chunk pos (chunk-length chunk)))
        (values (chunked-pvector (ft:single prefix) pos size)
                (chunked-pvector (ft:single suffix) (- len pos) size))]
       [else
        (define first-chunk (tree-first-node tree))
        (define first-len (chunk-length first-chunk))
        (cond
          [(<= pos first-len)
           (define left-tree
             (ft:single (chunk-slice first-chunk 0 pos)))
           (define right-tree
             (if (= pos first-len)
                 (let-values ([(popped rest) (tree-pop-left tree 0)])
                   rest)
                 (tree-replace-first tree (chunk-slice first-chunk pos first-len) 0)))
           (values (chunked-pvector left-tree pos size)
                   (chunked-pvector right-tree (- len pos) size))]
          [else
           (define suffix-len (- len pos))
           (define last-chunk (tree-last-node tree))
           (define last-len (chunk-length last-chunk))
           (cond
             [(<= suffix-len last-len)
              (define keep-len (- last-len suffix-len))
              (define left-tree
                (if (zero? keep-len)
                    (let-values ([(popped rest) (tree-pop-right tree 0)])
                      rest)
                    (tree-replace-last tree (chunk-slice last-chunk 0 keep-len) 0)))
              (define right-tree
                (ft:single (chunk-slice last-chunk keep-len last-len)))
              (values (chunked-pvector left-tree pos size)
                      (chunked-pvector right-tree suffix-len size))]
             [else
              (let-values ([(chunk-idx left chunk right)
                            (split-tree tree pos 0)])
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
                        (chunked-pvector right^ (- len pos) size)))])])])]))

(define (pvector-split-at-right pv pos)
  (define split-pos (- (chunked-pvector-length pv) pos))
  (define-values (left right) (pvector-split-at pv split-pos))
  (values right left))

(define (pvector-take pv pos)
  (define len (chunked-pvector-length pv))
  (define size (chunked-pvector-chunk-size pv))
  (cond
    [(zero? pos) (empty-pvector/size size)]
    [(= pos len) pv]
    [else
     (define tree (chunked-pvector-tree pv))
     (define first-chunk (tree-first-node tree))
     (define first-len (chunk-length first-chunk))
     (cond
       [(<= pos first-len)
        (chunked-pvector (ft:single (chunk-slice first-chunk 0 pos)) pos size)]
       [else
        (define suffix-len (- len pos))
        (define last-chunk (tree-last-node tree))
        (define last-len (chunk-length last-chunk))
        (cond
          [(<= suffix-len last-len)
           (define keep-len (- last-len suffix-len))
           (define tree^
             (if (zero? keep-len)
                 (let-values ([(popped rest) (tree-pop-right tree 0)])
                   rest)
                 (tree-replace-last tree (chunk-slice last-chunk 0 keep-len) 0)))
           (chunked-pvector tree^ pos size)]
          [else
           (define-values (chunk-idx left chunk)
             (split-tree-left tree pos 0))
           (define prefix (chunk-slice chunk 0 chunk-idx))
           (define left^
             (if prefix
                 (tree-cons-right left prefix 0)
                 left))
           (chunked-pvector left^ pos size)])])]))

(define (pvector-drop pv pos)
  (define len (chunked-pvector-length pv))
  (define size (chunked-pvector-chunk-size pv))
  (cond
    [(zero? pos) pv]
    [(= pos len)
     (empty-pvector/size size)]
    [else
     (define tree (chunked-pvector-tree pv))
     (define first-chunk (tree-first-node tree))
     (define first-len (chunk-length first-chunk))
     (cond
       [(<= pos first-len)
        (define tree^
          (if (= pos first-len)
              (let-values ([(popped rest) (tree-pop-left tree 0)])
                rest)
              (tree-replace-first tree (chunk-slice first-chunk pos first-len) 0)))
        (chunked-pvector tree^ (- len pos) size)]
       [else
        (define suffix-len (- len pos))
        (define last-chunk (tree-last-node tree))
        (define last-len (chunk-length last-chunk))
        (cond
          [(<= suffix-len last-len)
           (chunked-pvector (ft:single (chunk-slice last-chunk (- last-len suffix-len) last-len))
                            suffix-len
                            size)]
          [else
           (define-values (chunk-idx chunk right)
             (split-tree-right tree pos 0))
           (define suffix (chunk-slice chunk chunk-idx (chunk-length chunk)))
           (define right^
             (if suffix
                 (tree-cons-left right suffix 0)
                 right))
           (chunked-pvector right^ (- len pos) size)])])]))

(define (pvector-take-right pv pos)
  (define len (chunked-pvector-length pv))
  (define size (chunked-pvector-chunk-size pv))
  (cond
    [(zero? pos) (empty-pvector/size size)]
    [(= pos len) pv]
    [else
     (define tree (chunked-pvector-tree pv))
     (define last-chunk (tree-last-node tree))
     (define last-len (chunk-length last-chunk))
     (if (<= pos last-len)
         (chunked-pvector (ft:single (chunk-slice last-chunk (- last-len pos) last-len))
                          pos
                          size)
         (let ([split-pos (- len pos)])
           (define-values (chunk-idx chunk right)
             (split-tree-right tree split-pos 0))
           (define suffix (chunk-slice chunk chunk-idx (chunk-length chunk)))
           (define right^
             (if suffix
                 (tree-cons-left right suffix 0)
                 right))
           (chunked-pvector right^ pos size)))]))

(define (pvector-drop-right pv pos)
  (define len (chunked-pvector-length pv))
  (define size (chunked-pvector-chunk-size pv))
  (cond
    [(zero? pos) pv]
    [(= pos len) (empty-pvector/size size)]
    [else
     (define tree (chunked-pvector-tree pv))
     (define last-chunk (tree-last-node tree))
     (define last-len (chunk-length last-chunk))
     (if (<= pos last-len)
         (let* ([keep-len (- last-len pos)]
                [tree^
                 (if (zero? keep-len)
                     (let-values ([(popped rest) (tree-pop-right tree 0)])
                       rest)
                     (tree-replace-last tree (chunk-slice last-chunk 0 keep-len) 0))])
           (chunked-pvector tree^ (- len pos) size))
         (let ([split-pos (- len pos)])
           (define-values (chunk-idx left chunk)
             (split-tree-left tree split-pos 0))
           (define prefix (chunk-slice chunk 0 chunk-idx))
           (define left^
             (if prefix
                 (tree-cons-right left prefix 0)
                 left))
           (chunked-pvector left^ split-pos size)))]))

(define (pvector-copy/split pv start end)
  (define len (- end start))
  (define size (chunked-pvector-chunk-size pv))
  (define tree (chunked-pvector-tree pv))
  (define-values (start-idx start-chunk right)
    (split-tree-right tree start 0))
  (define chunk-len (chunk-length start-chunk))
  (define suffix-len (min len (- chunk-len start-idx)))
  (define suffix (chunk-slice start-chunk start-idx (+ start-idx suffix-len)))
  (cond
    [(= suffix-len len)
     (chunked-pvector (ft:single suffix) len size)]
    [else
     (define rest-len (- len suffix-len))
     (define rest
       (cond
         [(zero? rest-len) empty-tree]
         [(= rest-len (tree-size right 0)) right]
         [else
          (define-values (chunk-idx left chunk)
            (split-tree-left right rest-len 0))
          (define prefix (chunk-slice chunk 0 chunk-idx))
          (if prefix
              (tree-cons-right left prefix 0)
              left)]))
     (chunked-pvector (tree-cons-left rest suffix 0) len size)]))

(define (pvector-copy-small/across pv start end len size start-idx start-chunk)
  (define-values (end-idx end-chunk)
    (lookup-chunk-tree (chunked-pvector-tree pv) (sub1 end) 0))
  (define start-len (chunk-length start-chunk))
  (define left-len (- start-len start-idx))
  (define right-len (add1 end-idx))
  (define edge-len (+ left-len right-len))
  (cond
    [(= edge-len len)
     (chunks->pvector
      (vector (chunk-slice start-chunk start-idx start-len)
              (chunk-slice end-chunk 0 right-len))
      len
      size)]
    [else
     (define middle-len (- len edge-len))
     (if (<= middle-len size)
         (let-values ([(middle-idx middle-chunk)
                       (lookup-chunk-tree (chunked-pvector-tree pv) (+ start left-len) 0)])
           (if (and (zero? middle-idx)
                    (= middle-len (chunk-length middle-chunk)))
               (chunks->pvector
                (vector (chunk-slice start-chunk start-idx start-len)
                        middle-chunk
                        (chunk-slice end-chunk 0 right-len))
                len
                size)
               (pvector-copy/split pv start end)))
         (pvector-copy/split pv start end))]))

(define (pvector-copy pv start end)
  (cond
    [(= start end)
     (empty-pvector/size (chunked-pvector-chunk-size pv))]
    [(and (zero? start) (= end (chunked-pvector-length pv)))
     pv]
    [(zero? start)
     (pvector-take pv end)]
    [(= end (chunked-pvector-length pv))
     (pvector-drop pv start)]
    [else
     (define len (- end start))
     (define size (chunked-pvector-chunk-size pv))
     (if (<= len (* size 2))
         (let-values ([(chunk-idx chunk)
                       (lookup-chunk-tree (chunked-pvector-tree pv) start 0)])
           (define chunk-end (+ chunk-idx len))
           (cond
             [(<= chunk-end (chunk-length chunk))
              (chunked-pvector (ft:single (chunk-slice chunk chunk-idx chunk-end))
                               len
                               size)]
             [else
              (pvector-copy-small/across pv
                                         start
                                         end
                                         len
                                         size
                                         chunk-idx
                                         chunk)]))
         (pvector-copy/split pv start end))]))

(define (pvector-split pv idx)
  (define len (chunked-pvector-length pv))
  (define size (chunked-pvector-chunk-size pv))
  (define tree (chunked-pvector-tree pv))
  (cond
    [(ft:single? tree)
     (define chunk (ft:single-a tree))
     (define value (chunk-ref chunk idx))
     (define prefix (chunk-slice chunk 0 idx))
     (define suffix (chunk-slice chunk (add1 idx) (chunk-length chunk)))
     (values (chunked-pvector (if prefix (ft:single prefix) empty-tree) idx size)
             value
             (chunked-pvector (if suffix (ft:single suffix) empty-tree) (- len idx 1) size))]
    [else
     (define first-chunk (tree-first-node tree))
     (define first-len (chunk-length first-chunk))
     (cond
       [(< idx first-len)
        (define value (chunk-ref first-chunk idx))
        (define prefix (chunk-slice first-chunk 0 idx))
        (define suffix (chunk-slice first-chunk (add1 idx) first-len))
        (define left-tree (if prefix (ft:single prefix) empty-tree))
        (define right-tree
          (if suffix
              (tree-replace-first tree suffix 0)
              (let-values ([(popped rest) (tree-pop-left tree 0)])
                rest)))
        (values (chunked-pvector left-tree idx size)
                value
                (chunked-pvector right-tree (- len idx 1) size))]
       [else
        (define last-chunk (tree-last-node tree))
        (define last-len (chunk-length last-chunk))
        (define last-start (- len last-len))
        (cond
          [(>= idx last-start)
           (define chunk-idx (- idx last-start))
           (define value (chunk-ref last-chunk chunk-idx))
           (define prefix (chunk-slice last-chunk 0 chunk-idx))
           (define suffix (chunk-slice last-chunk (add1 chunk-idx) last-len))
           (define left-tree
             (if prefix
                 (tree-replace-last tree prefix 0)
                 (let-values ([(popped rest) (tree-pop-right tree 0)])
                   rest)))
           (define right-tree (if suffix (ft:single suffix) empty-tree))
           (values (chunked-pvector left-tree idx size)
                   value
                   (chunked-pvector right-tree (- len idx 1) size))]
          [else
           (define-values (chunk-idx left chunk right)
             (split-tree tree idx 0))
           (define value (chunk-ref chunk chunk-idx))
           (define prefix (chunk-slice chunk 0 chunk-idx))
           (define suffix (chunk-slice chunk (add1 chunk-idx) (chunk-length chunk)))
           (define left^
             (if prefix
                 (tree-cons-right left prefix 0)
                 left))
           (define right^
             (if suffix
                 (tree-cons-left right suffix 0)
                 right))
           (values (chunked-pvector left^ idx size)
                   value
                   (chunked-pvector right^ (- len idx 1) size))])])]))

(define (pvector-view-left pv)
  (chunk-ref (tree-first-node (chunked-pvector-tree pv)) 0))

(define (pvector-view-right pv)
  (define chunk (tree-last-node (chunked-pvector-tree pv)))
  (chunk-ref chunk (sub1 (chunk-length chunk))))

(define (pvector-cons-left pv value)
  (define size (chunked-pvector-chunk-size pv))
  (cond
    [(zero? (chunked-pvector-length pv))
     (chunked-pvector (ft:single (vector->immutable-vector (vector value))) 1 size)]
    [else
     (define tree (chunked-pvector-tree pv))
     (define tree^
       (if (ft:single? tree)
           (let* ([chunk (ft:single-a tree)]
                  [chunk-len (chunk-length chunk)])
             (if (< chunk-len endpoint-pack-limit)
                 (ft:single (chunk-prepend chunk value))
                 (tree-cons-left tree
                                 (vector->immutable-vector (vector value))
                                 0)))
           (let ([first-chunk (tree-first-node tree)])
             (if (< (chunk-length first-chunk) endpoint-pack-limit)
                 (tree-replace-first tree (chunk-prepend first-chunk value) 0)
                 (tree-cons-left tree
                                 (vector->immutable-vector (vector value))
                                 0)))))
     (chunked-pvector
      tree^
      (add1 (chunked-pvector-length pv))
      size)]))

(define (pvector-cons-right pv value)
  (define size (chunked-pvector-chunk-size pv))
  (cond
    [(zero? (chunked-pvector-length pv))
     (chunked-pvector (ft:single (vector->immutable-vector (vector value))) 1 size)]
    [else
     (define tree (chunked-pvector-tree pv))
     (define tree^
       (if (ft:single? tree)
           (let* ([chunk (ft:single-a tree)]
                  [chunk-len (chunk-length chunk)])
             (if (< chunk-len endpoint-pack-limit)
                 (ft:single (chunk-append chunk value))
                 (tree-cons-right tree
                                  (vector->immutable-vector (vector value))
                                  0)))
           (let ([last-chunk (tree-last-node tree)])
             (if (< (chunk-length last-chunk) endpoint-pack-limit)
                 (tree-replace-last tree (chunk-append last-chunk value) 0)
                 (tree-cons-right tree
                                  (vector->immutable-vector (vector value))
                                  0)))))
     (chunked-pvector
      tree^
      (add1 (chunked-pvector-length pv))
      size)]))

(define (pvector-pop-left pv)
  (define size (chunked-pvector-chunk-size pv))
  (define tree (chunked-pvector-tree pv))
  (define chunk (tree-first-node tree))
  (define value (chunk-ref chunk 0))
  (define chunk-len (chunk-length chunk))
  (define rest-tree
    (cond
      [(= chunk-len 1)
       (if (ft:single? tree)
           empty-tree
           (let-values ([(popped rest) (tree-pop-left tree 0)])
             rest))]
      [(ft:single? tree)
       (ft:single (chunk-slice chunk 1 chunk-len))]
      [else
       (tree-replace-first tree (chunk-slice chunk 1 chunk-len) 0)]))
  (define rest-len (sub1 (chunked-pvector-length pv)))
  (values value
          (if (zero? rest-len)
              (empty-pvector/size size)
              (chunked-pvector rest-tree rest-len size))))

(define (pvector-pop-right pv)
  (define size (chunked-pvector-chunk-size pv))
  (define tree (chunked-pvector-tree pv))
  (define chunk (tree-last-node tree))
  (define chunk-len (chunk-length chunk))
  (define value (chunk-ref chunk (sub1 chunk-len)))
  (define rest-tree
    (cond
      [(= chunk-len 1)
       (if (ft:single? tree)
           empty-tree
           (let-values ([(popped rest) (tree-pop-right tree 0)])
             rest))]
      [(ft:single? tree)
       (ft:single (chunk-slice chunk 0 (sub1 chunk-len)))]
      [else
       (tree-replace-last tree (chunk-slice chunk 0 (sub1 chunk-len)) 0)]))
  (define rest-len (sub1 (chunked-pvector-length pv)))
  (values value
          (if (zero? rest-len)
              (empty-pvector/size size)
              (chunked-pvector rest-tree rest-len size))))

(define (pvector-append left right)
  (cond
    [(zero? (chunked-pvector-length left)) right]
    [(zero? (chunked-pvector-length right)) left]
    [else
     (define left-len (chunked-pvector-length left))
     (define right-len (chunked-pvector-length right))
     (define total-len (+ left-len right-len))
     (define size (chunked-pvector-chunk-size left))
     (define left-tree (chunked-pvector-tree left))
     (define right-tree (chunked-pvector-tree right))
     (define left-last (tree-last-node left-tree))
     (define right-first (tree-first-node right-tree))
     (define tree
       (cond
         [(and (<= total-len size)
               (ft:single? left-tree)
               (ft:single? right-tree))
          (ft:single (chunk-append-chunk (ft:single-a left-tree)
                                         (ft:single-a right-tree)))]
         [(and (or (ft:single? left-tree)
                   (ft:single? right-tree))
               (<= (+ (chunk-length left-last) (chunk-length right-first)) size))
          (define-values (popped-left left-rest) (tree-pop-right left-tree 0))
          (define-values (popped-right right-rest) (tree-pop-left right-tree 0))
          (tree-concat (tree-cons-right left-rest
                                        (chunk-append-chunk popped-left popped-right)
                                        0)
                       right-rest
                       0)]
         [else
          (tree-concat left-tree right-tree 0)]))
     (chunked-pvector tree
                      total-len
                      size)]))

(define (pvector-insert-tree tree idx value size)
  (define-values (direct? a b c d)
    (insert-tree/fused tree idx value 0 size))
  (if direct?
      a
      (let ([chunk-idx a]
            [left b]
            [chunk c]
            [right d])
        (define chunk-len (chunk-length chunk))
        (cond
          [(< chunk-len size)
           (tree-concat
            (tree-cons-right left (chunk-insert chunk chunk-idx value) 0)
            right
            0)]
          [else
           (define prefix (chunk-slice chunk 0 chunk-idx))
           (define suffix (chunk-slice chunk chunk-idx chunk-len))
           (define left^
             (if prefix
                 (tree-cons-right left prefix 0)
                 left))
           (define right^
             (if suffix
                 (tree-cons-left right suffix 0)
                 right))
           (tree-concat
            (tree-cons-right left^ (vector->immutable-vector (vector value)) 0)
            right^
            0)]))))

(define (pvector-insert pv idx value)
  (cond
    [(zero? idx) (pvector-cons-left pv value)]
    [(= idx (chunked-pvector-length pv)) (pvector-cons-right pv value)]
    [else
     (define len (chunked-pvector-length pv))
     (define size (chunked-pvector-chunk-size pv))
     (define tree (chunked-pvector-tree pv))
     (define tree^
       (if (ft:single? tree)
           (let* ([chunk (ft:single-a tree)]
                  [chunk-len (chunk-length chunk)])
             (if (< chunk-len size)
                 (ft:single (chunk-insert chunk idx value))
                 (pvector-insert-tree tree idx value size)))
           (let* ([first-chunk (tree-first-node tree)]
                  [first-len (chunk-length first-chunk)])
             (cond
               [(and (<= idx first-len)
                     (< first-len size))
                (tree-replace-first tree (chunk-insert first-chunk idx value) 0)]
               [else
                (define last-chunk (tree-last-node tree))
                (define last-len (chunk-length last-chunk))
                (define last-start (- len last-len))
                (if (and (>= idx last-start)
                         (< last-len size))
                    (tree-replace-last tree
                                       (chunk-insert last-chunk
                                                     (- idx last-start)
                                                     value)
                                       0)
                    (pvector-insert-tree tree idx value size))]))))
     (chunked-pvector tree^ (add1 len) size)]))

(define (delete-node/direct node idx depth)
  (if (zero? depth)
      (let ([len (chunk-length node)]
            [value (chunk-ref node idx)])
        (if (= len 1)
            (values #f value #f)
            (values (chunk-delete node idx) value #t)))
      (let ([sub-depth (sub1 depth)])
        (cond
          [(node:2? node)
           (define a (node:2-a node))
           (define b (node:2-b node))
           (define a-size (node-size a sub-depth))
           (if (< idx a-size)
               (let-values ([(a^ value ok?) (delete-node/direct a idx sub-depth)])
                 (if ok?
                     (values (node:2 (sub1 (node:2-v node)) a^ b) value #t)
                     (values #f value #f)))
               (let-values ([(b^ value ok?) (delete-node/direct b (- idx a-size) sub-depth)])
                 (if ok?
                     (values (node:2 (sub1 (node:2-v node)) a b^) value #t)
                     (values #f value #f))))]
          [else
           (define a (node:3-a node))
           (define b (node:3-b node))
           (define c (node:3-c node))
           (define a-size (node-size a sub-depth))
           (define b-size (node-size b sub-depth))
           (define ab-size (+ a-size b-size))
           (cond
             [(< idx a-size)
              (let-values ([(a^ value ok?) (delete-node/direct a idx sub-depth)])
                (if ok?
                    (values (node:3 (sub1 (node:3-v node)) a^ b c) value #t)
                    (values #f value #f)))]
             [(< idx ab-size)
              (let-values ([(b^ value ok?) (delete-node/direct b (- idx a-size) sub-depth)])
                (if ok?
                    (values (node:3 (sub1 (node:3-v node)) a b^ c) value #t)
                    (values #f value #f)))]
             [else
              (let-values ([(c^ value ok?) (delete-node/direct c (- idx ab-size) sub-depth)])
                (if ok?
                    (values (node:3 (sub1 (node:3-v node)) a b c^) value #t)
                    (values #f value #f)))])]))))

(define (delete-digit/direct digit idx depth)
  (cond
    [(digit:1? digit)
     (let-values ([(a^ value ok?) (delete-node/direct (digit:1-a digit) idx depth)])
       (if ok?
           (values (digit:1 a^) value #t)
           (values #f value #f)))]
    [(digit:2? digit)
     (define a (digit:2-a digit))
     (define b (digit:2-b digit))
     (define a-size (node-size a depth))
     (if (< idx a-size)
         (let-values ([(a^ value ok?) (delete-node/direct a idx depth)])
           (if ok?
               (values (digit:2 a^ b) value #t)
               (values #f value #f)))
         (let-values ([(b^ value ok?) (delete-node/direct b (- idx a-size) depth)])
           (if ok?
               (values (digit:2 a b^) value #t)
               (values #f value #f))))]
    [(digit:3? digit)
     (define a (digit:3-a digit))
     (define b (digit:3-b digit))
     (define c (digit:3-c digit))
     (define a-size (node-size a depth))
     (define b-size (node-size b depth))
     (define ab-size (+ a-size b-size))
     (cond
       [(< idx a-size)
        (let-values ([(a^ value ok?) (delete-node/direct a idx depth)])
          (if ok?
              (values (digit:3 a^ b c) value #t)
              (values #f value #f)))]
       [(< idx ab-size)
        (let-values ([(b^ value ok?) (delete-node/direct b (- idx a-size) depth)])
          (if ok?
              (values (digit:3 a b^ c) value #t)
              (values #f value #f)))]
       [else
        (let-values ([(c^ value ok?) (delete-node/direct c (- idx ab-size) depth)])
          (if ok?
              (values (digit:3 a b c^) value #t)
              (values #f value #f)))])]
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
       [(< idx a-size)
        (let-values ([(a^ value ok?) (delete-node/direct a idx depth)])
          (if ok?
              (values (digit:4 a^ b c d) value #t)
              (values #f value #f)))]
       [(< idx ab-size)
        (let-values ([(b^ value ok?) (delete-node/direct b (- idx a-size) depth)])
          (if ok?
              (values (digit:4 a b^ c d) value #t)
              (values #f value #f)))]
       [(< idx abc-size)
        (let-values ([(c^ value ok?) (delete-node/direct c (- idx ab-size) depth)])
          (if ok?
              (values (digit:4 a b c^ d) value #t)
              (values #f value #f)))]
       [else
        (let-values ([(d^ value ok?) (delete-node/direct d (- idx abc-size) depth)])
          (if ok?
              (values (digit:4 a b c d^) value #t)
              (values #f value #f)))])]))

(define (delete-tree/direct tree idx depth)
  (cond
    [(ft:single? tree)
     (let-values ([(node^ value ok?) (delete-node/direct (ft:single-a tree) idx depth)])
       (if ok?
           (values (ft:single node^) value #t)
           (values #f value #f)))]
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
        (let-values ([(left^ value ok?) (delete-digit/direct left idx depth)])
          (if ok?
              (values (ft:deep (sub1 total) left^ inner right) value #t)
              (values #f value #f)))]
       [(< idx left+inner-size)
        (let-values ([(inner^ value ok?)
                      (delete-tree/direct inner (- idx left-size) inner-depth)])
          (if ok?
              (values (ft:deep (sub1 total) left inner^ right) value #t)
              (values #f value #f)))]
       [else
        (let-values ([(right^ value ok?)
                      (delete-digit/direct right (- idx left+inner-size) depth)])
          (if ok?
              (values (ft:deep (sub1 total) left inner right^) value #t)
              (values #f value #f)))])]
    [else
     (error 'pvector-delete "index out of bounds")]))

(define (pvector-delete pv idx)
  (cond
    [(zero? idx)
     (define-values (value rest) (pvector-pop-left pv))
     (values rest value)]
    [(= idx (sub1 (chunked-pvector-length pv)))
     (define-values (value rest) (pvector-pop-right pv))
     (values rest value)]
    [else
     (define len (chunked-pvector-length pv))
     (define size (chunked-pvector-chunk-size pv))
     (define tree (chunked-pvector-tree pv))
     (if (ft:single? tree)
         (let* ([chunk (ft:single-a tree)]
                [value (chunk-ref chunk idx)])
         (values (chunked-pvector (ft:single (chunk-delete chunk idx))
                                   (sub1 len)
                                   size)
                   value))
         (let-values ([(tree^ value ok?) (delete-tree/direct tree idx 0)])
           (if ok?
               (values (chunked-pvector tree^ (sub1 len) size) value)
               (let-values ([(chunk-idx left chunk right)
                             (split-tree tree idx 0)])
                 (define value (chunk-ref chunk chunk-idx))
                 (define chunk-len (chunk-length chunk))
                 (define tree^
                   (if (= chunk-len 1)
                       (tree-concat left right 0)
                       (tree-concat
                        (tree-cons-right left (chunk-delete chunk chunk-idx) 0)
                        right
                        0)))
                 (values (chunked-pvector tree^ (sub1 len) size) value)))))]))

(define (digit-for-each-node proc digit)
  (cond
    [(digit:1? digit)
     (proc (digit:1-a digit))]
    [(digit:2? digit)
     (proc (digit:2-a digit))
     (proc (digit:2-b digit))]
    [(digit:3? digit)
     (proc (digit:3-a digit))
     (proc (digit:3-b digit))
     (proc (digit:3-c digit))]
    [else
     (proc (digit:4-a digit))
     (proc (digit:4-b digit))
     (proc (digit:4-c digit))
     (proc (digit:4-d digit))]))

(define (digit-for-each-node-reverse proc digit)
  (cond
    [(digit:1? digit)
     (proc (digit:1-a digit))]
    [(digit:2? digit)
     (proc (digit:2-b digit))
     (proc (digit:2-a digit))]
    [(digit:3? digit)
     (proc (digit:3-c digit))
     (proc (digit:3-b digit))
     (proc (digit:3-a digit))]
    [else
     (proc (digit:4-d digit))
     (proc (digit:4-c digit))
     (proc (digit:4-b digit))
     (proc (digit:4-a digit))]))

(define (pvector-for-each-chunk proc pv)
  (define (each-node node depth)
    (if (zero? depth)
        (proc node)
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
    (digit-for-each-node (lambda (node) (each-node node depth)) digit))
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

(define (pvector-for-each-chunk-reverse proc pv)
  (define (each-node node depth)
    (if (zero? depth)
        (proc node)
        (let ([sub-depth (sub1 depth)])
          (if (node:2? node)
              (begin
                (each-node (node:2-b node) sub-depth)
                (each-node (node:2-a node) sub-depth))
              (begin
                (each-node (node:3-c node) sub-depth)
                (each-node (node:3-b node) sub-depth)
                (each-node (node:3-a node) sub-depth))))))
  (define (each-digit digit depth)
    (digit-for-each-node-reverse (lambda (node) (each-node node depth)) digit))
  (define (each-tree tree depth)
    (cond
      [(ft:empty? tree) (void)]
      [(ft:single? tree)
       (each-node (ft:single-a tree) depth)]
      [else
       (each-digit (ft:deep-right tree) depth)
       (each-tree (ft:deep-inner tree) (add1 depth))
       (each-digit (ft:deep-left tree) depth)]))
  (each-tree (chunked-pvector-tree pv) 0))

(define (pvector-for-each proc pv)
  (unless (or (eq? proc void)
              (eq? proc values))
    (pvector-for-each-chunk
     (lambda (chunk) (chunk-for-each proc chunk))
     pv)))

(define (pvector-for-each-reverse proc pv)
  (unless (or (eq? proc void)
              (eq? proc values))
    (pvector-for-each-chunk-reverse
     (lambda (chunk) (chunk-for-each-reverse proc chunk))
     pv)))

(define (pvector->vector pv)
  (define len (chunked-pvector-length pv))
  (define tree (chunked-pvector-tree pv))
  (cond
    [(zero? len)
     (make-vector 0)]
    [(pvector-cached-chunks pv)
     => (lambda (chunks)
          (cond
            [(= (unsafe-vector-length chunks) 1)
             (vector-copy (unsafe-vector-ref chunks 0))]
            [else
             (define vec (make-vector len))
             (let loop ([chunk-pos 0] [pos 0])
               (unless (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
                 (define chunk (unsafe-vector-ref chunks chunk-pos))
                 (vector-copy! vec pos chunk)
                 (loop (unsafe-fx+ chunk-pos 1)
                       (unsafe-fx+ pos (unsafe-vector-length chunk)))))
             vec]))]
    [(ft:single? tree)
     (chunk->vector (ft:single-a tree))]
    [else
     (define vec (make-vector len))
     (define i 0)
     (pvector-for-each-chunk
      (lambda (chunk)
        (chunk-copy-to-vector! vec i chunk)
        (set! i (+ i (chunk-length chunk))))
      pv)
     vec]))

(define (pvector->list pv)
  (define result '())
  (define cached-chunks (pvector-cached-chunks pv))
  (if cached-chunks
      (let chunk-loop ([chunk-pos (unsafe-fx- (unsafe-vector-length cached-chunks) 1)]
                       [acc null])
        (if (unsafe-fx< chunk-pos 0)
            (set! result acc)
            (let ([chunk (unsafe-vector-ref cached-chunks chunk-pos)])
              (let elem-loop ([i (unsafe-fx- (unsafe-vector-length chunk) 1)]
                              [acc acc])
                (if (unsafe-fx< i 0)
                    (chunk-loop (unsafe-fx- chunk-pos 1) acc)
                    (elem-loop (unsafe-fx- i 1)
                               (cons (unsafe-vector-ref chunk i) acc)))))))
      (pvector-for-each-chunk-reverse
       (lambda (chunk)
         (cond
           [(vector? chunk)
            (let loop ([i (unsafe-fx- (unsafe-vector-length chunk) 1)]
                       [acc result])
              (if (unsafe-fx< i 0)
                  (set! result acc)
                  (loop (unsafe-fx- i 1)
                        (cons (unsafe-vector-ref chunk i) acc))))]
           [else
            (let ([vec (leaf-chunk-vec chunk)]
                  [start (leaf-chunk-start chunk)])
              (let loop ([i (unsafe-fx- (leaf-chunk-end chunk) 1)]
                         [acc result])
                (if (unsafe-fx< i start)
                    (set! result acc)
                    (loop (unsafe-fx- i 1)
                          (cons (unsafe-vector-ref vec i) acc)))))]))
       pv))
  result)

(define (chunk->plain-vector chunk)
  (if (vector? chunk)
      chunk
      (vector->immutable-vector
       (vector-copy (leaf-chunk-vec chunk)
                    (leaf-chunk-start chunk)
                    (leaf-chunk-end chunk)))))

(define (pvector-lookup-chunk pv idx)
  (define cached-chunks (pvector-cached-chunks pv))
  (if (and cached-chunks
           (fixnum? idx)
           (unsafe-fx>= idx 0)
           (unsafe-fx< idx (chunked-pvector-length pv)))
      (let* ([size (chunked-pvector-chunk-size pv)]
             [chunk-pos (unsafe-fxquotient idx size)])
        (values (unsafe-fx- idx (unsafe-fx* chunk-pos size))
                (unsafe-vector-ref cached-chunks chunk-pos)))
      (let-values ([(idx^ chunk)
                    (lookup-chunk-tree (chunked-pvector-tree pv) idx 0)])
        (values idx^ (chunk->plain-vector chunk)))))

(define (pvector->chunk-vector/shared pv)
  (define cached-chunks (pvector-cached-chunks pv))
  (if cached-chunks
      cached-chunks
      (let ([tree (chunked-pvector-tree pv)])
        (cond
          [(zero? (chunked-pvector-length pv))
           (make-vector 0)]
          [(ft:single? tree)
           (vector (chunk->plain-vector (ft:single-a tree)))]
          [else
           (define chunks '())
           (define count 0)
           (pvector-for-each-chunk
            (lambda (chunk)
              (set! chunks (cons (chunk->plain-vector chunk) chunks))
              (set! count (add1 count)))
            pv)
           (define vec (make-vector count))
           (let loop ([chunks chunks] [idx (sub1 count)])
             (unless (null? chunks)
               (vector-set! vec idx (car chunks))
               (loop (cdr chunks) (sub1 idx))))
           vec]))))

(define (pvector->chunk-vector pv)
  (vector-copy (pvector->chunk-vector/shared pv)))

(define (in-pvector/proc pv)
  (define chunks (pvector->chunk-vector/shared pv))
  (define chunk-count (unsafe-vector-length chunks))
  (define size (regular-chunk-size chunks chunk-count))
  (cond
    [size
     (define len (chunked-pvector-length pv))
     (define pos-elem
       (if (unsafe-fx= size default-chunk-size)
           (lambda (index)
             (unsafe-vector-ref
              (unsafe-vector-ref chunks (unsafe-fxrshift index 6))
              (unsafe-fxand index 63)))
           (lambda (index)
             (define chunk-pos (unsafe-fxquotient index size))
             (unsafe-vector-ref
              (unsafe-vector-ref chunks chunk-pos)
              (unsafe-fx- index (unsafe-fx* chunk-pos size))))))
     (make-do-sequence
      (lambda ()
        (values pos-elem
                (lambda (index) (unsafe-fx+ index 1))
                0
                (lambda (index) (unsafe-fx< index len))
                (lambda (elem) #t)
                (lambda (pos elem) #t))))]
    [else
     (define first-chunk
       (if (unsafe-fx> chunk-count 0)
           (unsafe-vector-ref chunks 0)
           #f))
     (define first-len
       (if first-chunk (unsafe-vector-length first-chunk) 0))
     (define (pos-elem pos)
       (unsafe-vector-ref (unsafe-vector-ref pos 2) (unsafe-vector-ref pos 1)))
     (define (next-pos pos)
       (define chunk-pos (unsafe-vector-ref pos 0))
       (define elem-idx (unsafe-vector-ref pos 1))
       (define chunk-len (unsafe-vector-ref pos 3))
       (define next-elem-idx (unsafe-fx+ elem-idx 1))
       (cond
         [(unsafe-fx< next-elem-idx chunk-len)
          (unsafe-vector-set! pos 1 next-elem-idx)]
         [else
          (define next-chunk-pos (unsafe-fx+ chunk-pos 1))
          (unsafe-vector-set! pos 0 next-chunk-pos)
          (unsafe-vector-set! pos 1 0)
          (when (unsafe-fx< next-chunk-pos chunk-count)
            (define next-chunk (unsafe-vector-ref chunks next-chunk-pos))
            (unsafe-vector-set! pos 2 next-chunk)
            (unsafe-vector-set! pos 3 (unsafe-vector-length next-chunk)))])
       pos)
     (define (pos-more? pos)
       (unsafe-fx< (unsafe-vector-ref pos 0) chunk-count))
     (make-do-sequence
      (lambda ()
        (values pos-elem
                next-pos
                (vector 0 0 first-chunk first-len)
                pos-more?
                (lambda (elem) #t)
                (lambda (pos elem) #t))))]))

(define (in-pvector-reverse/proc pv)
  (define chunks (pvector->chunk-vector/shared pv))
  (define chunk-count (unsafe-vector-length chunks))
  (define last-chunk-pos (unsafe-fx- chunk-count 1))
  (define size (regular-chunk-size chunks chunk-count))
  (cond
    [size
     (define len (chunked-pvector-length pv))
     (define pos-elem
       (if (unsafe-fx= size default-chunk-size)
           (lambda (index)
             (unsafe-vector-ref
              (unsafe-vector-ref chunks (unsafe-fxrshift index 6))
              (unsafe-fxand index 63)))
           (lambda (index)
             (define chunk-pos (unsafe-fxquotient index size))
             (unsafe-vector-ref
              (unsafe-vector-ref chunks chunk-pos)
              (unsafe-fx- index (unsafe-fx* chunk-pos size))))))
     (make-do-sequence
      (lambda ()
        (values pos-elem
                (lambda (index) (unsafe-fx- index 1))
                (unsafe-fx- len 1)
                (lambda (index) (unsafe-fx>= index 0))
                (lambda (elem) #t)
                (lambda (pos elem) #t))))]
    [else
     (define last-chunk
       (if (unsafe-fx>= last-chunk-pos 0)
           (unsafe-vector-ref chunks last-chunk-pos)
           #f))
     (define last-elem-idx
       (if last-chunk
           (unsafe-fx- (unsafe-vector-length last-chunk) 1)
           -1))
     (define (pos-elem pos)
       (unsafe-vector-ref (unsafe-vector-ref pos 2) (unsafe-vector-ref pos 1)))
     (define (next-pos pos)
       (define chunk-pos (unsafe-vector-ref pos 0))
       (define elem-idx (unsafe-vector-ref pos 1))
       (define next-elem-idx (unsafe-fx- elem-idx 1))
       (cond
         [(unsafe-fx>= next-elem-idx 0)
          (unsafe-vector-set! pos 1 next-elem-idx)]
         [else
          (define next-chunk-pos (unsafe-fx- chunk-pos 1))
          (unsafe-vector-set! pos 0 next-chunk-pos)
          (if (unsafe-fx>= next-chunk-pos 0)
              (let ([next-chunk (unsafe-vector-ref chunks next-chunk-pos)])
                (unsafe-vector-set! pos 2 next-chunk)
                (unsafe-vector-set! pos 1
                                    (unsafe-fx- (unsafe-vector-length next-chunk) 1)))
              (unsafe-vector-set! pos 1 -1))])
       pos)
     (define (pos-more? pos)
       (unsafe-fx>= (unsafe-vector-ref pos 0) 0))
     (make-do-sequence
      (lambda ()
        (values pos-elem
                next-pos
                (vector last-chunk-pos last-elem-idx last-chunk)
                pos-more?
                (lambda (elem) #t)
                (lambda (pos elem) #t))))]))

(define-sequence-syntax in-pvector
  (lambda () #'in-pvector/proc)
  (lambda (stx)
    (syntax-case stx ()
      [[(elem) (_ pv-expr)]
       #'[(elem)
          (:do-in
           ([(chunks) (pvector->chunk-vector/shared pv-expr)])
           (begin
             (define chunk-count (unsafe-vector-length chunks))
             (define first-chunk
               (if (unsafe-fx> chunk-count 0)
                   (unsafe-vector-ref chunks 0)
                   #f))
             (define first-len
               (if first-chunk (unsafe-vector-length first-chunk) 0)))
           ([chunk-pos 0]
            [elem-idx 0]
            [chunk first-chunk]
            [chunk-len first-len])
           (unsafe-fx< chunk-pos chunk-count)
           ([(elem next-chunk-pos next-elem-idx next-chunk next-chunk-len)
             (let ([elem (unsafe-vector-ref chunk elem-idx)]
                   [next-elem-idx (unsafe-fx+ elem-idx 1)])
               (cond
                 [(unsafe-fx< next-elem-idx chunk-len)
                  (values elem chunk-pos next-elem-idx chunk chunk-len)]
                 [else
                  (define next-chunk-pos (unsafe-fx+ chunk-pos 1))
                  (if (unsafe-fx< next-chunk-pos chunk-count)
                      (let ([next-chunk (unsafe-vector-ref chunks next-chunk-pos)])
                        (values elem
                                next-chunk-pos
                                0
                                next-chunk
                                (unsafe-vector-length next-chunk)))
                      (values elem
                              next-chunk-pos
                              0
                              chunk
                              chunk-len))]))])
           #t
           #t
           (next-chunk-pos next-elem-idx next-chunk next-chunk-len))]]
      [_ #f])))

(define-sequence-syntax in-pvector-reverse
  (lambda () #'in-pvector-reverse/proc)
  (lambda (stx)
    (syntax-case stx ()
      [[(elem) (_ pv-expr)]
       #'[(elem)
          (:do-in
           ([(chunks) (pvector->chunk-vector/shared pv-expr)])
           (begin
             (define chunk-count (unsafe-vector-length chunks))
             (define last-chunk-pos (unsafe-fx- chunk-count 1))
             (define last-chunk
               (if (unsafe-fx>= last-chunk-pos 0)
                   (unsafe-vector-ref chunks last-chunk-pos)
                   #f))
             (define last-elem-idx
               (if last-chunk
                   (unsafe-fx- (unsafe-vector-length last-chunk) 1)
                   -1)))
           ([chunk-pos last-chunk-pos]
            [elem-idx last-elem-idx]
            [chunk last-chunk])
           (unsafe-fx>= chunk-pos 0)
           ([(elem next-chunk-pos next-elem-idx next-chunk)
             (let ([elem (unsafe-vector-ref chunk elem-idx)]
                   [next-elem-idx (unsafe-fx- elem-idx 1)])
               (cond
                 [(unsafe-fx>= next-elem-idx 0)
                  (values elem chunk-pos next-elem-idx chunk)]
                 [else
                  (define next-chunk-pos (unsafe-fx- chunk-pos 1))
                  (if (unsafe-fx>= next-chunk-pos 0)
                      (let ([next-chunk (unsafe-vector-ref chunks next-chunk-pos)])
                        (values elem
                                next-chunk-pos
                                (unsafe-fx- (unsafe-vector-length next-chunk) 1)
                                next-chunk))
                      (values elem
                              next-chunk-pos
                              -1
                              chunk))]))])
           #t
           #t
           (next-chunk-pos next-elem-idx next-chunk))]]
      [_ #f])))

(define (in-pvector/index/proc pv)
  (define chunks (pvector->chunk-vector/shared pv))
  (define chunk-count (unsafe-vector-length chunks))
  (define size (regular-chunk-size chunks chunk-count))
  (cond
    [size
     (define len (chunked-pvector-length pv))
     (define pos-elem
       (if (unsafe-fx= size default-chunk-size)
           (lambda (index)
             (values
              (unsafe-vector-ref
               (unsafe-vector-ref chunks (unsafe-fxrshift index 6))
               (unsafe-fxand index 63))
              index))
           (lambda (index)
             (define chunk-pos (unsafe-fxquotient index size))
             (values
              (unsafe-vector-ref
               (unsafe-vector-ref chunks chunk-pos)
               (unsafe-fx- index (unsafe-fx* chunk-pos size)))
              index))))
     (make-do-sequence
      (lambda ()
        (values pos-elem
                (lambda (index) (unsafe-fx+ index 1))
                0
                (lambda (index) (unsafe-fx< index len))
                (lambda (elem index) #t)
                (lambda (pos elem index) #t))))]
    [else
     (define first-chunk
       (if (unsafe-fx> chunk-count 0)
           (unsafe-vector-ref chunks 0)
           #f))
     (define first-len
       (if first-chunk (unsafe-vector-length first-chunk) 0))
     (define (pos-elem pos)
       (values (unsafe-vector-ref (unsafe-vector-ref pos 3)
                                  (unsafe-vector-ref pos 1))
               (unsafe-vector-ref pos 2)))
     (define (next-pos pos)
       (define chunk-pos (unsafe-vector-ref pos 0))
       (define elem-idx (unsafe-vector-ref pos 1))
       (define elem-pos (unsafe-vector-ref pos 2))
       (define chunk-len (unsafe-vector-ref pos 4))
       (define next-elem-idx (unsafe-fx+ elem-idx 1))
       (define next-elem-pos (unsafe-fx+ elem-pos 1))
       (unsafe-vector-set! pos 2 next-elem-pos)
       (cond
         [(unsafe-fx< next-elem-idx chunk-len)
          (unsafe-vector-set! pos 1 next-elem-idx)]
         [else
          (define next-chunk-pos (unsafe-fx+ chunk-pos 1))
          (unsafe-vector-set! pos 0 next-chunk-pos)
          (unsafe-vector-set! pos 1 0)
          (when (unsafe-fx< next-chunk-pos chunk-count)
            (define next-chunk (unsafe-vector-ref chunks next-chunk-pos))
            (unsafe-vector-set! pos 3 next-chunk)
            (unsafe-vector-set! pos 4 (unsafe-vector-length next-chunk)))])
       pos)
     (define (pos-more? pos)
       (unsafe-fx< (unsafe-vector-ref pos 0) chunk-count))
     (make-do-sequence
      (lambda ()
        (values pos-elem
                next-pos
                (vector 0 0 0 first-chunk first-len)
                pos-more?
                (lambda (elem index) #t)
                (lambda (pos elem index) #t))))]))

(define-sequence-syntax in-pvector/index
  (lambda () #'in-pvector/index/proc)
  (lambda (stx)
    (syntax-case stx ()
      [[(elem index) (_ pv-expr)]
       #'[(elem index)
          (:do-in
           ([(chunks) (pvector->chunk-vector/shared pv-expr)])
           (begin
             (define chunk-count (unsafe-vector-length chunks))
             (define first-chunk
               (if (unsafe-fx> chunk-count 0)
                   (unsafe-vector-ref chunks 0)
                   #f))
             (define first-len
               (if first-chunk (unsafe-vector-length first-chunk) 0)))
           ([chunk-pos 0]
            [elem-idx 0]
            [elem-pos 0]
            [chunk first-chunk]
            [chunk-len first-len])
           (unsafe-fx< chunk-pos chunk-count)
           ([(elem index next-chunk-pos next-elem-idx next-elem-pos next-chunk next-chunk-len)
             (let ([elem (unsafe-vector-ref chunk elem-idx)]
                   [next-elem-idx (unsafe-fx+ elem-idx 1)]
                   [next-elem-pos (unsafe-fx+ elem-pos 1)])
               (cond
                 [(unsafe-fx< next-elem-idx chunk-len)
                  (values elem
                          elem-pos
                          chunk-pos
                          next-elem-idx
                          next-elem-pos
                          chunk
                          chunk-len)]
                 [else
                  (define next-chunk-pos (unsafe-fx+ chunk-pos 1))
                  (if (unsafe-fx< next-chunk-pos chunk-count)
                      (let ([next-chunk (unsafe-vector-ref chunks next-chunk-pos)])
                        (values elem
                                elem-pos
                                next-chunk-pos
                                0
                                next-elem-pos
                                next-chunk
                                (unsafe-vector-length next-chunk)))
                      (values elem
                              elem-pos
                              next-chunk-pos
                              0
                              next-elem-pos
                              chunk
                              chunk-len))]))])
           #t
           #t
           (next-chunk-pos next-elem-idx next-elem-pos next-chunk next-chunk-len))]]
      [_ #f])))

(define-syntax in-pvector-indexed
  (make-rename-transformer #'in-pvector/index))

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
  (let-values ([(add! finish) (make-pvector-builder)])
    (for (clause ...)
      (add! (let () body ...)))
    (finish)))

(define-syntax-rule (for*/pvector (clause ...) body ...)
  (let-values ([(add! finish) (make-pvector-builder)])
    (for* (clause ...)
      (add! (let () body ...)))
    (finish)))
