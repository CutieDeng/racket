;; Fixed-measure persistent vector core candidate.
;;
;; This file is deliberately not exported yet. It establishes the Chez/Rumble
;; object model that the current Racket-level pvector backend can move to after
;; the shape and benchmark gates remain green.

(define default-core-pvector-chunk-size 64)
(define core-pvector-endpoint-pack-limit 4)

(define-record-type core-pvector
  [fields (immutable tree)
          (immutable length)
          (immutable chunk-size)]
  [nongenerative #{core-pvector cutie-pvector-runtime-0}]
  [sealed #t])

(define-record-type pvector-leaf-chunk
  [fields (immutable vector)
          (immutable start)
          (immutable end)]
  [nongenerative #{pvector-leaf-chunk cutie-pvector-runtime-1}]
  [sealed #t])

(define-record-type pvector-digit1
  [fields (immutable a)]
  [nongenerative #{pvector-digit1 cutie-pvector-runtime-2}]
  [sealed #t])

(define-record-type pvector-digit2
  [fields (immutable a)
          (immutable b)]
  [nongenerative #{pvector-digit2 cutie-pvector-runtime-3}]
  [sealed #t])

(define-record-type pvector-digit3
  [fields (immutable a)
          (immutable b)
          (immutable c)]
  [nongenerative #{pvector-digit3 cutie-pvector-runtime-4}]
  [sealed #t])

(define-record-type pvector-digit4
  [fields (immutable a)
          (immutable b)
          (immutable c)
          (immutable d)]
  [nongenerative #{pvector-digit4 cutie-pvector-runtime-5}]
  [sealed #t])

(define-record-type pvector-node2
  [fields (immutable measure)
          (immutable a)
          (immutable b)]
  [nongenerative #{pvector-node2 cutie-pvector-runtime-6}]
  [sealed #t])

(define-record-type pvector-node3
  [fields (immutable measure)
          (immutable a)
          (immutable b)
          (immutable c)]
  [nongenerative #{pvector-node3 cutie-pvector-runtime-7}]
  [sealed #t])

(define-record-type pvector-empty-tree
  [fields]
  [nongenerative #{pvector-empty-tree cutie-pvector-runtime-8}]
  [sealed #t])

(define-record-type pvector-single-tree
  [fields (immutable a)]
  [nongenerative #{pvector-single-tree cutie-pvector-runtime-9}]
  [sealed #t])

(define-record-type pvector-deep-tree
  [fields (immutable measure)
          (immutable left)
          (immutable inner)
          (immutable right)]
  [nongenerative #{pvector-deep-tree cutie-pvector-runtime-10}]
  [sealed #t])

(define empty-core-pvector-tree (make-pvector-empty-tree))
(define empty-core-pvector
  (make-core-pvector empty-core-pvector-tree 0 default-core-pvector-chunk-size))

(define (core-pvector-empty)
  empty-core-pvector)

(define (core-pvector-empty? pv)
  (and (core-pvector? pv)
       (fx= 0 (core-pvector-length pv))))

(define (pvector-leaf-vector? v)
  (#%vector? v))

(define (pvector-chunk? v)
  (or (pvector-leaf-vector? v)
      (pvector-leaf-chunk? v)))

(define (pvector-digit? v)
  (or (pvector-digit1? v)
      (pvector-digit2? v)
      (pvector-digit3? v)
      (pvector-digit4? v)))

(define (pvector-node? v)
  (or (pvector-node2? v)
      (pvector-node3? v)))

(define (pvector-tree? v)
  (or (pvector-empty-tree? v)
      (pvector-single-tree? v)
      (pvector-deep-tree? v)))

(define (pvector-chunk-length chunk)
  (if (pvector-leaf-vector? chunk)
      (#%vector-length chunk)
      (fx- (pvector-leaf-chunk-end chunk)
           (pvector-leaf-chunk-start chunk))))

(define (pvector-chunk-ref chunk index)
  (if (pvector-leaf-vector? chunk)
      (#3%vector-ref chunk index)
      (#3%vector-ref (pvector-leaf-chunk-vector chunk)
                     (fx+ (pvector-leaf-chunk-start chunk) index))))

(define (pvector-chunk-slice chunk start end)
  (cond
   [(fx= start end) #f]
   [(and (fx= start 0)
         (fx= end (pvector-chunk-length chunk)))
    chunk]
   [(pvector-leaf-vector? chunk)
    (make-pvector-leaf-chunk chunk start end)]
   [else
    (make-pvector-leaf-chunk
     (pvector-leaf-chunk-vector chunk)
     (fx+ (pvector-leaf-chunk-start chunk) start)
     (fx+ (pvector-leaf-chunk-start chunk) end))]))

(define (pvector-copy-chunk-range chunk start end)
  (let* ([len (fx- end start)]
         [vec (make-vector len)])
    (let loop ([i 0])
      (unless (fx= i len)
        (#3%vector-set! vec i (pvector-chunk-ref chunk (fx+ start i)))
        (loop (fx+ i 1))))
    (vector->immutable-vector vec)))

(define (pvector-chunk-set chunk index value)
  (let ([vec (if (pvector-leaf-vector? chunk)
                 (vector-copy chunk)
                 (vector-copy (pvector-leaf-chunk-vector chunk)
                              (pvector-leaf-chunk-start chunk)
                              (pvector-leaf-chunk-end chunk)))])
    (#3%vector-set! vec index value)
    (vector->immutable-vector vec)))

(define (pvector-chunk-prepend chunk value)
  (let* ([len (pvector-chunk-length chunk)]
         [vec (make-vector (fx+ len 1))])
    (#3%vector-set! vec 0 value)
    (let loop ([i 0])
      (unless (fx= i len)
        (#3%vector-set! vec (fx+ i 1) (pvector-chunk-ref chunk i))
        (loop (fx+ i 1))))
    (vector->immutable-vector vec)))

(define (pvector-chunk-append chunk value)
  (let* ([len (pvector-chunk-length chunk)]
         [vec (make-vector (fx+ len 1))])
    (let loop ([i 0])
      (unless (fx= i len)
        (#3%vector-set! vec i (pvector-chunk-ref chunk i))
        (loop (fx+ i 1))))
    (#3%vector-set! vec len value)
    (vector->immutable-vector vec)))

(define (pvector-subtree-measure v)
  (cond
   [(pvector-chunk? v) (pvector-chunk-length v)]
   [(pvector-node2? v) (pvector-node2-measure v)]
   [(pvector-node3? v) (pvector-node3-measure v)]
   [else 0]))

(define (pvector-make-node2 a b)
  (make-pvector-node2 (fx+ (pvector-subtree-measure a)
                           (pvector-subtree-measure b))
                      a
                      b))

(define (pvector-make-node3 a b c)
  (make-pvector-node3 (fx+ (pvector-subtree-measure a)
                           (fx+ (pvector-subtree-measure b)
                                (pvector-subtree-measure c)))
                      a
                      b
                      c))

(define (pvector-digit-measure digit)
  (cond
   [(pvector-digit1? digit)
    (pvector-subtree-measure (pvector-digit1-a digit))]
   [(pvector-digit2? digit)
    (fx+ (pvector-subtree-measure (pvector-digit2-a digit))
         (pvector-subtree-measure (pvector-digit2-b digit)))]
   [(pvector-digit3? digit)
    (fx+ (pvector-subtree-measure (pvector-digit3-a digit))
         (fx+ (pvector-subtree-measure (pvector-digit3-b digit))
              (pvector-subtree-measure (pvector-digit3-c digit))))]
   [else
    (fx+ (pvector-subtree-measure (pvector-digit4-a digit))
         (fx+ (pvector-subtree-measure (pvector-digit4-b digit))
              (fx+ (pvector-subtree-measure (pvector-digit4-c digit))
                   (pvector-subtree-measure (pvector-digit4-d digit)))))]))

(define (pvector-tree-measure tree)
  (cond
   [(pvector-empty-tree? tree) 0]
   [(pvector-single-tree? tree)
    (pvector-subtree-measure (pvector-single-tree-a tree))]
   [else
    (pvector-deep-tree-measure tree)]))

(define (pvector-make-deep-tree left inner right)
  (make-pvector-deep-tree (fx+ (pvector-digit-measure left)
                               (fx+ (pvector-tree-measure inner)
                                    (pvector-digit-measure right)))
                          left
                          inner
                          right))

(define (pvector-vector-measure vec start len)
  (let loop ([i 0] [sum 0])
    (if (fx= i len)
        sum
        (loop (fx+ i 1)
              (fx+ sum (pvector-subtree-measure
                        (#3%vector-ref vec (fx+ start i))))))))

(define (pvector-small-vector->tree vec)
  (let* ([len (#%vector-length vec)]
         [total (pvector-vector-measure vec 0 len)])
    (cond
     [(fx= len 0)
      empty-core-pvector-tree]
     [(fx= len 1)
      (make-pvector-single-tree (#3%vector-ref vec 0))]
     [(fx= len 2)
      (make-pvector-deep-tree
       total
       (make-pvector-digit1 (#3%vector-ref vec 0))
       empty-core-pvector-tree
       (make-pvector-digit1 (#3%vector-ref vec 1)))]
     [(fx= len 3)
      (make-pvector-deep-tree
       total
       (make-pvector-digit1 (#3%vector-ref vec 0))
       empty-core-pvector-tree
       (make-pvector-digit2 (#3%vector-ref vec 1)
                            (#3%vector-ref vec 2)))]
     [(fx= len 4)
      (make-pvector-deep-tree
       total
       (make-pvector-digit2 (#3%vector-ref vec 0)
                            (#3%vector-ref vec 1))
       empty-core-pvector-tree
       (make-pvector-digit2 (#3%vector-ref vec 2)
                            (#3%vector-ref vec 3)))]
     [(fx= len 5)
      (make-pvector-deep-tree
       total
       (make-pvector-digit2 (#3%vector-ref vec 0)
                            (#3%vector-ref vec 1))
       empty-core-pvector-tree
       (make-pvector-digit3 (#3%vector-ref vec 2)
                            (#3%vector-ref vec 3)
                            (#3%vector-ref vec 4)))]
     [(fx= len 6)
      (make-pvector-deep-tree
       total
       (make-pvector-digit3 (#3%vector-ref vec 0)
                            (#3%vector-ref vec 1)
                            (#3%vector-ref vec 2))
       empty-core-pvector-tree
       (make-pvector-digit3 (#3%vector-ref vec 3)
                            (#3%vector-ref vec 4)
                            (#3%vector-ref vec 5)))]
     [(fx= len 7)
      (make-pvector-deep-tree
       total
       (make-pvector-digit3 (#3%vector-ref vec 0)
                            (#3%vector-ref vec 1)
                            (#3%vector-ref vec 2))
       empty-core-pvector-tree
       (make-pvector-digit4 (#3%vector-ref vec 3)
                            (#3%vector-ref vec 4)
                            (#3%vector-ref vec 5)
                            (#3%vector-ref vec 6)))]
     [else
      (make-pvector-deep-tree
       total
       (make-pvector-digit4 (#3%vector-ref vec 0)
                            (#3%vector-ref vec 1)
                            (#3%vector-ref vec 2)
                            (#3%vector-ref vec 3))
       empty-core-pvector-tree
       (make-pvector-digit4 (#3%vector-ref vec 4)
                            (#3%vector-ref vec 5)
                            (#3%vector-ref vec 6)
                            (#3%vector-ref vec 7)))])))

(define (pvector-vector->node3-vector vec start len)
  (let* ([new-len (fxquotient len 3)]
         [new-vec (make-vector new-len)])
    (let loop ([i 0])
      (unless (fx= i new-len)
        (let* ([offset (fx* 3 i)]
               [idx0 (fx+ start offset)]
               [idx1 (fx+ idx0 1)]
               [idx2 (fx+ idx0 2)])
          (#3%vector-set!
           new-vec
           i
           (pvector-make-node3 (#3%vector-ref vec idx0)
                               (#3%vector-ref vec idx1)
                               (#3%vector-ref vec idx2))))
        (loop (fx+ i 1))))
    new-vec))

(define (pvector-nodes-vector->tree vec total)
  (let ([len (#%vector-length vec)])
    (cond
     [(fx<= len 8)
      (pvector-small-vector->tree vec)]
     [else
      (case (modulo len 3)
        [(0)
         (let* ([left (make-pvector-digit3 (#3%vector-ref vec 0)
                                           (#3%vector-ref vec 1)
                                           (#3%vector-ref vec 2))]
                [right (make-pvector-digit3 (#3%vector-ref vec (fx- len 3))
                                            (#3%vector-ref vec (fx- len 2))
                                            (#3%vector-ref vec (fx- len 1)))]
                [mid-total (fx- total
                                (fx+ (pvector-digit-measure left)
                                     (pvector-digit-measure right)))]
                [mid (pvector-vector->node3-vector vec 3 (fx- len 6))])
           (make-pvector-deep-tree total left (pvector-nodes-vector->tree mid mid-total) right))]
        [(1)
         (let* ([left (make-pvector-digit4 (#3%vector-ref vec 0)
                                           (#3%vector-ref vec 1)
                                           (#3%vector-ref vec 2)
                                           (#3%vector-ref vec 3))]
                [right (make-pvector-digit3 (#3%vector-ref vec (fx- len 3))
                                            (#3%vector-ref vec (fx- len 2))
                                            (#3%vector-ref vec (fx- len 1)))]
                [mid-total (fx- total
                                (fx+ (pvector-digit-measure left)
                                     (pvector-digit-measure right)))]
                [mid (pvector-vector->node3-vector vec 4 (fx- len 7))])
           (make-pvector-deep-tree total left (pvector-nodes-vector->tree mid mid-total) right))]
        [else
         (let* ([left (make-pvector-digit4 (#3%vector-ref vec 0)
                                           (#3%vector-ref vec 1)
                                           (#3%vector-ref vec 2)
                                           (#3%vector-ref vec 3))]
                [right (make-pvector-digit4 (#3%vector-ref vec (fx- len 4))
                                            (#3%vector-ref vec (fx- len 3))
                                            (#3%vector-ref vec (fx- len 2))
                                            (#3%vector-ref vec (fx- len 1)))]
                [mid-total (fx- total
                                (fx+ (pvector-digit-measure left)
                                     (pvector-digit-measure right)))]
                [mid (pvector-vector->node3-vector vec 4 (fx- len 8))])
           (make-pvector-deep-tree total left (pvector-nodes-vector->tree mid mid-total) right))])])))

(define (pvector-vector->chunks vec size)
  (let* ([len (#%vector-length vec)]
         [chunk-count (fxquotient (fx+ len (fx- size 1)) size)]
         [chunks (make-vector chunk-count)])
    (let loop ([chunk-index 0])
      (unless (fx= chunk-index chunk-count)
        (let* ([start (fx* chunk-index size)]
               [end (fxmin len (fx+ start size))])
          (#3%vector-set! chunks chunk-index
                          (vector->immutable-vector (vector-copy vec start end))))
        (loop (fx+ chunk-index 1))))
    chunks))

(define (pvector-tree-build left inner right depth)
  (let ([inner-depth (fx+ depth 1)])
    (make-pvector-deep-tree
     (fx+ (pvector-digit-measure left)
          (fx+ (pvector-tree-measure inner)
               (pvector-digit-measure right)))
     left
     inner
     right)))

(define (pvector-tree-cons-left tree node depth)
  (cond
   [(pvector-empty-tree? tree)
    (make-pvector-single-tree node)]
   [(pvector-single-tree? tree)
    (let ([a (pvector-single-tree-a tree)])
      (make-pvector-deep-tree
       (fx+ (pvector-subtree-measure node) (pvector-subtree-measure a))
       (make-pvector-digit1 node)
       empty-core-pvector-tree
       (make-pvector-digit1 a)))]
   [else
    (let* ([total (pvector-deep-tree-measure tree)]
           [left (pvector-deep-tree-left tree)]
           [inner (pvector-deep-tree-inner tree)]
           [right (pvector-deep-tree-right tree)]
           [new-total (fx+ (pvector-subtree-measure node) total)])
      (cond
       [(pvector-digit4? left)
        (let ([a (pvector-digit4-a left)]
              [b (pvector-digit4-b left)]
              [c (pvector-digit4-c left)]
              [d (pvector-digit4-d left)])
          (make-pvector-deep-tree
           new-total
           (make-pvector-digit2 node a)
           (pvector-tree-cons-left inner (pvector-make-node3 b c d) (fx+ depth 1))
           right))]
       [(pvector-digit1? left)
        (make-pvector-deep-tree
         new-total
         (make-pvector-digit2 node (pvector-digit1-a left))
         inner
         right)]
       [(pvector-digit2? left)
        (make-pvector-deep-tree
         new-total
         (make-pvector-digit3 node (pvector-digit2-a left) (pvector-digit2-b left))
         inner
         right)]
       [else
        (make-pvector-deep-tree
         new-total
         (make-pvector-digit4 node
                              (pvector-digit3-a left)
                              (pvector-digit3-b left)
                              (pvector-digit3-c left))
         inner
         right)]))]))

(define (pvector-tree-cons-right tree node depth)
  (cond
   [(pvector-empty-tree? tree)
    (make-pvector-single-tree node)]
   [(pvector-single-tree? tree)
    (let ([a (pvector-single-tree-a tree)])
      (make-pvector-deep-tree
       (fx+ (pvector-subtree-measure a) (pvector-subtree-measure node))
       (make-pvector-digit1 a)
       empty-core-pvector-tree
       (make-pvector-digit1 node)))]
   [else
    (let* ([total (pvector-deep-tree-measure tree)]
           [left (pvector-deep-tree-left tree)]
           [inner (pvector-deep-tree-inner tree)]
           [right (pvector-deep-tree-right tree)]
           [new-total (fx+ total (pvector-subtree-measure node))])
      (cond
       [(pvector-digit4? right)
        (let ([a (pvector-digit4-a right)]
              [b (pvector-digit4-b right)]
              [c (pvector-digit4-c right)]
              [d (pvector-digit4-d right)])
          (make-pvector-deep-tree
           new-total
           left
           (pvector-tree-cons-right inner (pvector-make-node3 a b c) (fx+ depth 1))
           (make-pvector-digit2 d node)))]
       [(pvector-digit1? right)
        (make-pvector-deep-tree
         new-total
         left
         inner
         (make-pvector-digit2 (pvector-digit1-a right) node))]
       [(pvector-digit2? right)
        (make-pvector-deep-tree
         new-total
         left
         inner
         (make-pvector-digit3 (pvector-digit2-a right) (pvector-digit2-b right) node))]
       [else
        (make-pvector-deep-tree
         new-total
         left
         inner
         (make-pvector-digit4 (pvector-digit3-a right)
                              (pvector-digit3-b right)
                              (pvector-digit3-c right)
                              node))]))]))

(define (pvector-digit-first-node digit)
  (cond
   [(pvector-digit1? digit) (pvector-digit1-a digit)]
   [(pvector-digit2? digit) (pvector-digit2-a digit)]
   [(pvector-digit3? digit) (pvector-digit3-a digit)]
   [else (pvector-digit4-a digit)]))

(define (pvector-digit-last-node digit)
  (cond
   [(pvector-digit1? digit) (pvector-digit1-a digit)]
   [(pvector-digit2? digit) (pvector-digit2-b digit)]
   [(pvector-digit3? digit) (pvector-digit3-c digit)]
   [else (pvector-digit4-d digit)]))

(define (pvector-digit-replace-first digit node)
  (cond
   [(pvector-digit1? digit) (make-pvector-digit1 node)]
   [(pvector-digit2? digit)
    (make-pvector-digit2 node (pvector-digit2-b digit))]
   [(pvector-digit3? digit)
    (make-pvector-digit3 node (pvector-digit3-b digit) (pvector-digit3-c digit))]
   [else
    (make-pvector-digit4 node
                         (pvector-digit4-b digit)
                         (pvector-digit4-c digit)
                         (pvector-digit4-d digit))]))

(define (pvector-digit-replace-last digit node)
  (cond
   [(pvector-digit1? digit) (make-pvector-digit1 node)]
   [(pvector-digit2? digit)
    (make-pvector-digit2 (pvector-digit2-a digit) node)]
   [(pvector-digit3? digit)
    (make-pvector-digit3 (pvector-digit3-a digit) (pvector-digit3-b digit) node)]
   [else
    (make-pvector-digit4 (pvector-digit4-a digit)
                         (pvector-digit4-b digit)
                         (pvector-digit4-c digit)
                         node)]))

(define (pvector-tree-first-node tree)
  (cond
   [(pvector-single-tree? tree) (pvector-single-tree-a tree)]
   [(pvector-deep-tree? tree) (pvector-digit-first-node (pvector-deep-tree-left tree))]
   [else (error 'pvector-tree-first-node "empty tree")]))

(define (pvector-tree-last-node tree)
  (cond
   [(pvector-single-tree? tree) (pvector-single-tree-a tree)]
   [(pvector-deep-tree? tree) (pvector-digit-last-node (pvector-deep-tree-right tree))]
   [else (error 'pvector-tree-last-node "empty tree")]))

(define (pvector-tree-replace-first tree node depth)
  (cond
   [(pvector-single-tree? tree)
    (make-pvector-single-tree node)]
   [(pvector-deep-tree? tree)
    (let* ([total (pvector-deep-tree-measure tree)]
           [left (pvector-deep-tree-left tree)]
           [old (pvector-digit-first-node left)])
      (make-pvector-deep-tree
       (fx+ total
            (fx- (pvector-subtree-measure node)
                 (pvector-subtree-measure old)))
       (pvector-digit-replace-first left node)
       (pvector-deep-tree-inner tree)
       (pvector-deep-tree-right tree)))]
   [else (error 'pvector-tree-replace-first "empty tree")]))

(define (pvector-tree-replace-last tree node depth)
  (cond
   [(pvector-single-tree? tree)
    (make-pvector-single-tree node)]
   [(pvector-deep-tree? tree)
    (let* ([total (pvector-deep-tree-measure tree)]
           [right (pvector-deep-tree-right tree)]
           [old (pvector-digit-last-node right)])
      (make-pvector-deep-tree
       (fx+ total
            (fx- (pvector-subtree-measure node)
                 (pvector-subtree-measure old)))
       (pvector-deep-tree-left tree)
       (pvector-deep-tree-inner tree)
       (pvector-digit-replace-last right node)))]
   [else (error 'pvector-tree-replace-last "empty tree")]))

(define (pvector-node->list node)
  (if (pvector-node2? node)
      (list (pvector-node2-a node) (pvector-node2-b node))
      (list (pvector-node3-a node) (pvector-node3-b node) (pvector-node3-c node))))

(define (pvector-digit->list digit)
  (cond
   [(pvector-digit1? digit)
    (list (pvector-digit1-a digit))]
   [(pvector-digit2? digit)
    (list (pvector-digit2-a digit) (pvector-digit2-b digit))]
   [(pvector-digit3? digit)
    (list (pvector-digit3-a digit) (pvector-digit3-b digit) (pvector-digit3-c digit))]
   [else
    (list (pvector-digit4-a digit)
          (pvector-digit4-b digit)
          (pvector-digit4-c digit)
          (pvector-digit4-d digit))]))

(define (pvector-list->digit nodes)
  (let ([a (car nodes)]
        [rest (cdr nodes)])
    (cond
     [(null? rest)
      (make-pvector-digit1 a)]
     [(null? (cdr rest))
      (make-pvector-digit2 a (car rest))]
     [(null? (cddr rest))
      (make-pvector-digit3 a (car rest) (cadr rest))]
     [else
      (make-pvector-digit4 a (car rest) (cadr rest) (caddr rest))])))

(define (pvector-node->digit node)
  (pvector-list->digit (pvector-node->list node)))

(define (pvector-list-measure nodes)
  (let loop ([nodes nodes] [sum 0])
    (if (null? nodes)
        sum
        (loop (cdr nodes) (fx+ sum (pvector-subtree-measure (car nodes)))))))

(define (pvector-digit-list->tree nodes depth)
  (let ([total (pvector-list-measure nodes)])
    (cond
     [(null? nodes)
      empty-core-pvector-tree]
     [(null? (cdr nodes))
      (make-pvector-single-tree (car nodes))]
     [(null? (cddr nodes))
      (make-pvector-deep-tree
       total
       (make-pvector-digit1 (car nodes))
       empty-core-pvector-tree
       (make-pvector-digit1 (cadr nodes)))]
     [(null? (cdddr nodes))
      (make-pvector-deep-tree
       total
       (make-pvector-digit1 (car nodes))
       empty-core-pvector-tree
       (make-pvector-digit2 (cadr nodes) (caddr nodes)))]
     [else
      (make-pvector-deep-tree
       total
       (make-pvector-digit2 (car nodes) (cadr nodes))
       empty-core-pvector-tree
       (make-pvector-digit2 (caddr nodes) (cadddr nodes)))])))

(define (pvector-digit-list2->tree nodes depth)
  (cond
   ((fx<= (length nodes) 4)
    (pvector-digit-list->tree nodes depth))
   (else
    (let ([total (pvector-list-measure nodes)])
      (cond
       ((fx= (length nodes) 5)
        (make-pvector-deep-tree
         total
         (make-pvector-digit2 (car nodes) (cadr nodes))
         empty-core-pvector-tree
         (make-pvector-digit3 (caddr nodes) (cadddr nodes) (car (cddddr nodes)))))
       ((fx= (length nodes) 6)
        (make-pvector-deep-tree
         total
         (make-pvector-digit3 (car nodes) (cadr nodes) (caddr nodes))
         empty-core-pvector-tree
         (make-pvector-digit3 (cadddr nodes) (car (cddddr nodes)) (cadr (cddddr nodes)))))
       (else
        (make-pvector-deep-tree
         total
         (make-pvector-digit3 (car nodes) (cadr nodes) (caddr nodes))
         empty-core-pvector-tree
         (make-pvector-digit4 (cadddr nodes)
                              (car (cddddr nodes))
                              (cadr (cddddr nodes))
                              (caddr (cddddr nodes))))))))))

(define (pvector-tree-pop-left tree depth)
  (cond
   [(pvector-empty-tree? tree)
    (error 'pvector-tree-pop-left "empty tree")]
   [(pvector-single-tree? tree)
    (values (pvector-single-tree-a tree) empty-core-pvector-tree)]
   [else
    (let ([left (pvector-deep-tree-left tree)]
          [inner (pvector-deep-tree-inner tree)]
          [right (pvector-deep-tree-right tree)])
      (cond
       [(pvector-digit1? left)
        (let ([a (pvector-digit1-a left)])
          (cond
           [(pvector-empty-tree? inner)
            (let ([right-nodes (pvector-digit->list right)])
              (if (null? (cdr right-nodes))
                  (values a (make-pvector-single-tree (car right-nodes)))
                  (values a (pvector-digit-list->tree right-nodes depth))))]
           [else
            (let-values ([(left-node inner^) (pvector-tree-pop-left inner (fx+ depth 1))])
              (values a
                      (pvector-tree-build
                       (pvector-node->digit left-node)
                       inner^
                       right
                       depth)))]))]
       [else
        (let ([nodes (pvector-digit->list left)])
          (values (car nodes)
                  (pvector-tree-build (pvector-list->digit (cdr nodes))
                                      inner
                                      right
                                      depth)))]))]))

(define (pvector-list-last nodes)
  (if (null? (cdr nodes))
      (car nodes)
      (pvector-list-last (cdr nodes))))

(define (pvector-list-drop-last nodes)
  (if (null? (cdr nodes))
      null
      (cons (car nodes) (pvector-list-drop-last (cdr nodes)))))

(define (pvector-tree-pop-right tree depth)
  (cond
   [(pvector-empty-tree? tree)
    (error 'pvector-tree-pop-right "empty tree")]
   [(pvector-single-tree? tree)
    (values (pvector-single-tree-a tree) empty-core-pvector-tree)]
   [else
    (let ([left (pvector-deep-tree-left tree)]
          [inner (pvector-deep-tree-inner tree)]
          [right (pvector-deep-tree-right tree)])
      (cond
       [(pvector-digit1? right)
        (let ([a (pvector-digit1-a right)])
          (cond
           [(pvector-empty-tree? inner)
            (let ([left-nodes (pvector-digit->list left)])
              (if (null? (cdr left-nodes))
                  (values a (make-pvector-single-tree (car left-nodes)))
                  (values a (pvector-digit-list->tree left-nodes depth))))]
           [else
            (let-values ([(right-node inner^) (pvector-tree-pop-right inner (fx+ depth 1))])
              (values a
                      (pvector-tree-build
                       left
                       inner^
                       (pvector-node->digit right-node)
                       depth)))]))]
       [else
        (let ([nodes (pvector-digit->list right)])
          (values (pvector-list-last nodes)
                  (pvector-tree-build left
                                      inner
                                      (pvector-list->digit (pvector-list-drop-last nodes))
                                      depth)))]))]))

(define (pvector-digit-list+tree->digit nodes tree depth pop)
  (cond
   [(null? nodes)
    (let-values ([(node tree^) (pop tree (fx+ depth 1))])
      (values (pvector-node->digit node) tree^))]
   [else
    (values (pvector-list->digit nodes) tree)]))

(define (pvector-left-digit+tree->tree digit tree depth)
  (cond
   [(pvector-empty-tree? tree)
    (pvector-digit-list->tree (pvector-digit->list digit) depth)]
   [else
    (let-values ([(node tree^) (pvector-tree-pop-right tree (fx+ depth 1))])
      (pvector-tree-build digit tree^ (pvector-node->digit node) depth))]))

(define (pvector-right-digit+tree->tree digit tree depth)
  (cond
   [(pvector-empty-tree? tree)
    (pvector-digit-list->tree (pvector-digit->list digit) depth)]
   [else
    (let-values ([(node tree^) (pvector-tree-pop-left tree (fx+ depth 1))])
      (pvector-tree-build (pvector-node->digit node) tree^ digit depth))]))

(define (pvector-node-list->nodes nodes depth)
  (cond
   [(null? (cddr nodes))
    (list (pvector-make-node2 (car nodes) (cadr nodes)))]
   [(null? (cdddr nodes))
    (list (pvector-make-node3 (car nodes) (cadr nodes) (caddr nodes)))]
   [(null? (cddddr nodes))
    (list (pvector-make-node2 (car nodes) (cadr nodes))
          (pvector-make-node2 (caddr nodes) (cadddr nodes)))]
   [else
    (cons (pvector-make-node3 (car nodes) (cadr nodes) (caddr nodes))
          (pvector-node-list->nodes (cdddr nodes) depth))]))

(define (pvector-tree-concat left right depth)
  (cond
   [(pvector-empty-tree? left) right]
   [(pvector-empty-tree? right) left]
   [(pvector-single-tree? left)
    (pvector-tree-cons-left right (pvector-single-tree-a left) depth)]
   [(pvector-single-tree? right)
    (pvector-tree-cons-right left (pvector-single-tree-a right) depth)]
   [else
    (let* ([left-size (pvector-deep-tree-measure left)]
           [left-left (pvector-deep-tree-left left)]
           [left-inner (pvector-deep-tree-inner left)]
           [left-right (pvector-deep-tree-right left)]
           [right-size (pvector-deep-tree-measure right)]
           [right-left (pvector-deep-tree-left right)]
           [right-inner (pvector-deep-tree-inner right)]
           [right-right (pvector-deep-tree-right right)]
           [middle-nodes
            (pvector-node-list->nodes
             (append (pvector-digit->list left-right)
                     (pvector-digit->list right-left))
             depth)]
           [inner-depth (fx+ depth 1)]
           [left-inner^
            (let loop ([inner left-inner] [nodes middle-nodes])
              (if (null? nodes)
                  inner
                  (loop (pvector-tree-cons-right inner (car nodes) inner-depth)
                        (cdr nodes))))])
      (make-pvector-deep-tree
       (fx+ left-size right-size)
       left-left
       (pvector-tree-concat left-inner^ right-inner inner-depth)
       right-right))]))

(define (pvector-split-digit digit index depth)
  (let loop ([before null] [nodes (pvector-digit->list digit)] [index index])
    (cond
     [(null? nodes)
      (error 'pvector-split-digit "index out of digit")]
     [else
      (let* ([node (car nodes)]
             [rest (cdr nodes)]
             [size (pvector-subtree-measure node)])
        (if (fx< index size)
            (values index (reverse before) node rest)
            (loop (cons node before) rest (fx- index size))))])))

(define (pvector-split-node node index depth)
  (let loop ([before null] [nodes (pvector-node->list node)] [index index])
    (cond
     [(null? nodes)
      (error 'pvector-split-node "index out of node")]
     [else
      (let* ([child (car nodes)]
             [rest (cdr nodes)]
             [size (pvector-subtree-measure child)])
        (if (fx< index size)
            (values index (reverse before) child rest)
            (loop (cons child before) rest (fx- index size))))])))

(define (pvector-tree-add-right-list tree nodes depth)
  (let loop ([acc tree] [nodes nodes])
    (if (null? nodes)
        acc
        (loop (pvector-tree-cons-right acc (car nodes) depth)
              (cdr nodes)))))

(define (pvector-tree-add-left-list tree nodes depth)
  (let loop ([acc tree] [nodes (reverse nodes)])
    (if (null? nodes)
        acc
        (loop (pvector-tree-cons-left acc (car nodes) depth)
              (cdr nodes)))))

(define (pvector-split-tree tree index depth)
  (cond
   ((pvector-empty-tree? tree)
    (error 'pvector-split-tree "empty tree"))
   ((pvector-single-tree? tree)
    (let ([node (pvector-single-tree-a tree)])
      (when (fx>= index (pvector-subtree-measure node))
        (error 'pvector-split-tree "index out of single node"))
      (values index empty-core-pvector-tree node empty-core-pvector-tree)))
   (else
    (let* ([total (pvector-deep-tree-measure tree)]
           [left (pvector-deep-tree-left tree)]
           [inner (pvector-deep-tree-inner tree)]
           [right (pvector-deep-tree-right tree)]
           [inner-depth (fx+ depth 1)]
           [left-size (pvector-digit-measure left)]
           [inner-size (pvector-tree-measure inner)]
           [left+inner-size (fx+ left-size inner-size)])
      (cond
       ((fx< index left-size)
        (let-values ([(index^ l node r) (pvector-split-digit left index depth)])
          (let ([left^ (pvector-digit-list->tree l depth)]
                [right^
                 (if (pvector-empty-tree? inner)
                     (pvector-digit-list2->tree
                      (append r (pvector-digit->list right))
                      depth)
                     (let-values ([(right-digit inner^)
                                   (pvector-digit-list+tree->digit
                                    r
                                    inner
                                    depth
                                    pvector-tree-pop-left)])
                       (pvector-tree-build right-digit inner^ right depth)))])
            (values index^ left^ node right^))))
       ((fx< index left+inner-size)
        (let-values ([(rest-index inner-left node inner-right)
                      (pvector-split-tree inner (fx- index left-size) inner-depth)])
          (let* ([left^ (pvector-left-digit+tree->tree left inner-left depth)]
                 [right^ (pvector-right-digit+tree->tree right inner-right depth)])
            (let-values ([(index^ l node^ r)
                          (pvector-split-node node rest-index inner-depth)])
              (values index^
                      (pvector-tree-add-right-list left^ l depth)
                      node^
                      (pvector-tree-add-left-list right^ r depth))))))
       ((fx< index total)
        (let-values ([(index^ l node r)
                      (pvector-split-digit right (fx- index left+inner-size) depth)])
          (let ([right^ (pvector-digit-list->tree r depth)]
                [left^
                 (if (pvector-empty-tree? inner)
                     (pvector-digit-list2->tree
                      (append (pvector-digit->list left) l)
                      depth)
                     (let-values ([(left-digit inner^)
                                   (pvector-digit-list+tree->digit
                                    l
                                    inner
                                    depth
                                    pvector-tree-pop-right)])
                       (pvector-tree-build left inner^ left-digit depth)))])
            (values index^ left^ node right^))))
       (else
        (error 'pvector-split-tree "index out of tree")))))))

(define (core-pvector-ref-node node index depth)
  (if (fx= depth 0)
      (pvector-chunk-ref node index)
      (let ([sub-depth (fx- depth 1)])
        (cond
         [(pvector-node2? node)
          (let* ([a (pvector-node2-a node)]
                 [a-size (pvector-subtree-measure a)])
            (if (fx< index a-size)
                (core-pvector-ref-node a index sub-depth)
                (core-pvector-ref-node (pvector-node2-b node)
                                       (fx- index a-size)
                                       sub-depth)))]
         [else
          (let* ([a (pvector-node3-a node)]
                 [b (pvector-node3-b node)]
                 [a-size (pvector-subtree-measure a)]
                 [b-size (pvector-subtree-measure b)]
                 [ab-size (fx+ a-size b-size)])
            (cond
             [(fx< index a-size)
              (core-pvector-ref-node a index sub-depth)]
             [(fx< index ab-size)
              (core-pvector-ref-node b (fx- index a-size) sub-depth)]
             [else
              (core-pvector-ref-node (pvector-node3-c node)
                                     (fx- index ab-size)
                                     sub-depth)]))]))))

(define (core-pvector-ref-digit digit index depth)
  (cond
   [(pvector-digit1? digit)
    (core-pvector-ref-node (pvector-digit1-a digit) index depth)]
   [(pvector-digit2? digit)
    (let* ([a (pvector-digit2-a digit)]
           [a-size (pvector-subtree-measure a)])
      (if (fx< index a-size)
          (core-pvector-ref-node a index depth)
          (core-pvector-ref-node (pvector-digit2-b digit) (fx- index a-size) depth)))]
   [(pvector-digit3? digit)
    (let* ([a (pvector-digit3-a digit)]
           [b (pvector-digit3-b digit)]
           [a-size (pvector-subtree-measure a)]
           [b-size (pvector-subtree-measure b)]
           [ab-size (fx+ a-size b-size)])
      (cond
       [(fx< index a-size)
        (core-pvector-ref-node a index depth)]
       [(fx< index ab-size)
        (core-pvector-ref-node b (fx- index a-size) depth)]
       [else
        (core-pvector-ref-node (pvector-digit3-c digit) (fx- index ab-size) depth)]))]
   [else
    (let* ([a (pvector-digit4-a digit)]
           [b (pvector-digit4-b digit)]
           [c (pvector-digit4-c digit)]
           [a-size (pvector-subtree-measure a)]
           [b-size (pvector-subtree-measure b)]
           [c-size (pvector-subtree-measure c)]
           [ab-size (fx+ a-size b-size)]
           [abc-size (fx+ ab-size c-size)])
      (cond
       [(fx< index a-size)
        (core-pvector-ref-node a index depth)]
       [(fx< index ab-size)
        (core-pvector-ref-node b (fx- index a-size) depth)]
       [(fx< index abc-size)
        (core-pvector-ref-node c (fx- index ab-size) depth)]
       [else
        (core-pvector-ref-node (pvector-digit4-d digit) (fx- index abc-size) depth)]))]))

(define (core-pvector-ref-tree tree index depth)
  (cond
   [(pvector-single-tree? tree)
    (core-pvector-ref-node (pvector-single-tree-a tree) index depth)]
   [(pvector-deep-tree? tree)
    (let* ([left (pvector-deep-tree-left tree)]
           [inner (pvector-deep-tree-inner tree)]
           [right (pvector-deep-tree-right tree)]
           [inner-depth (fx+ depth 1)]
           [left-size (pvector-digit-measure left)]
           [inner-size (pvector-tree-measure inner)]
           [left+inner-size (fx+ left-size inner-size)])
      (cond
       [(fx< index left-size)
        (core-pvector-ref-digit left index depth)]
       [(fx< index left+inner-size)
        (core-pvector-ref-tree inner (fx- index left-size) inner-depth)]
       [else
        (core-pvector-ref-digit right (fx- index left+inner-size) depth)]))]
   [else
    (error 'core-pvector-ref "index out of bounds")]))

(define (core-pvector-ref pv index)
  (core-pvector-ref-tree (core-pvector-tree pv) index 0))

(define (core-pvector-set-node node index value depth)
  (if (fx= depth 0)
      (pvector-chunk-set node index value)
      (let ([sub-depth (fx- depth 1)])
        (cond
         [(pvector-node2? node)
          (let* ([a (pvector-node2-a node)]
                 [b (pvector-node2-b node)]
                 [a-size (pvector-subtree-measure a)])
            (if (fx< index a-size)
                (make-pvector-node2 (pvector-node2-measure node)
                                    (core-pvector-set-node a index value sub-depth)
                                    b)
                (make-pvector-node2 (pvector-node2-measure node)
                                    a
                                    (core-pvector-set-node b (fx- index a-size) value sub-depth))))]
         [else
          (let* ([a (pvector-node3-a node)]
                 [b (pvector-node3-b node)]
                 [c (pvector-node3-c node)]
                 [a-size (pvector-subtree-measure a)]
                 [b-size (pvector-subtree-measure b)]
                 [ab-size (fx+ a-size b-size)])
            (cond
             [(fx< index a-size)
              (make-pvector-node3 (pvector-node3-measure node)
                                  (core-pvector-set-node a index value sub-depth)
                                  b
                                  c)]
             [(fx< index ab-size)
              (make-pvector-node3 (pvector-node3-measure node)
                                  a
                                  (core-pvector-set-node b (fx- index a-size) value sub-depth)
                                  c)]
             [else
              (make-pvector-node3 (pvector-node3-measure node)
                                  a
                                  b
                                  (core-pvector-set-node c (fx- index ab-size) value sub-depth))]))]))))

(define (core-pvector-set-digit digit index value depth)
  (cond
   [(pvector-digit1? digit)
    (make-pvector-digit1
     (core-pvector-set-node (pvector-digit1-a digit) index value depth))]
   [(pvector-digit2? digit)
    (let* ([a (pvector-digit2-a digit)]
           [b (pvector-digit2-b digit)]
           [a-size (pvector-subtree-measure a)])
      (if (fx< index a-size)
          (make-pvector-digit2 (core-pvector-set-node a index value depth) b)
          (make-pvector-digit2 a (core-pvector-set-node b (fx- index a-size) value depth))))]
   [(pvector-digit3? digit)
    (let* ([a (pvector-digit3-a digit)]
           [b (pvector-digit3-b digit)]
           [c (pvector-digit3-c digit)]
           [a-size (pvector-subtree-measure a)]
           [b-size (pvector-subtree-measure b)]
           [ab-size (fx+ a-size b-size)])
      (cond
       [(fx< index a-size)
        (make-pvector-digit3 (core-pvector-set-node a index value depth) b c)]
       [(fx< index ab-size)
        (make-pvector-digit3 a (core-pvector-set-node b (fx- index a-size) value depth) c)]
       [else
        (make-pvector-digit3 a b (core-pvector-set-node c (fx- index ab-size) value depth))]))]
   [else
    (let* ([a (pvector-digit4-a digit)]
           [b (pvector-digit4-b digit)]
           [c (pvector-digit4-c digit)]
           [d (pvector-digit4-d digit)]
           [a-size (pvector-subtree-measure a)]
           [b-size (pvector-subtree-measure b)]
           [c-size (pvector-subtree-measure c)]
           [ab-size (fx+ a-size b-size)]
           [abc-size (fx+ ab-size c-size)])
      (cond
       [(fx< index a-size)
        (make-pvector-digit4 (core-pvector-set-node a index value depth) b c d)]
       [(fx< index ab-size)
        (make-pvector-digit4 a (core-pvector-set-node b (fx- index a-size) value depth) c d)]
       [(fx< index abc-size)
        (make-pvector-digit4 a b (core-pvector-set-node c (fx- index ab-size) value depth) d)]
       [else
        (make-pvector-digit4 a b c (core-pvector-set-node d (fx- index abc-size) value depth))]))]))

(define (core-pvector-set-tree tree index value depth)
  (cond
   [(pvector-single-tree? tree)
    (make-pvector-single-tree
     (core-pvector-set-node (pvector-single-tree-a tree) index value depth))]
   [(pvector-deep-tree? tree)
    (let* ([total (pvector-deep-tree-measure tree)]
           [left (pvector-deep-tree-left tree)]
           [inner (pvector-deep-tree-inner tree)]
           [right (pvector-deep-tree-right tree)]
           [inner-depth (fx+ depth 1)]
           [left-size (pvector-digit-measure left)]
           [inner-size (pvector-tree-measure inner)]
           [left+inner-size (fx+ left-size inner-size)])
      (cond
       [(fx< index left-size)
        (make-pvector-deep-tree total
                                (core-pvector-set-digit left index value depth)
                                inner
                                right)]
       [(fx< index left+inner-size)
        (make-pvector-deep-tree total
                                left
                                (core-pvector-set-tree inner (fx- index left-size) value inner-depth)
                                right)]
       [else
        (make-pvector-deep-tree total
                                left
                                inner
                                (core-pvector-set-digit right (fx- index left+inner-size) value depth))]))]
   [else
    (error 'core-pvector-set "index out of bounds")]))

(define (core-pvector-set pv index value)
  (make-core-pvector (core-pvector-set-tree (core-pvector-tree pv) index value 0)
                     (core-pvector-length pv)
                     (core-pvector-chunk-size pv)))

(define (core-pvector-singleton-chunk value)
  (vector-immutable value))

(define (core-pvector-cons-left pv value)
  (let ([size (core-pvector-chunk-size pv)])
    (cond
     [(fx= 0 (core-pvector-length pv))
      (make-core-pvector
       (make-pvector-single-tree (core-pvector-singleton-chunk value))
       1
       size)]
     [else
      (let* ([tree (core-pvector-tree pv)]
             [first-chunk (pvector-tree-first-node tree)]
             [tree^
              (if (fx< (pvector-chunk-length first-chunk) core-pvector-endpoint-pack-limit)
                  (pvector-tree-replace-first tree (pvector-chunk-prepend first-chunk value) 0)
                  (pvector-tree-cons-left tree (core-pvector-singleton-chunk value) 0))])
        (make-core-pvector tree^ (fx+ (core-pvector-length pv) 1) size))])))

(define (core-pvector-cons-right pv value)
  (let ([size (core-pvector-chunk-size pv)])
    (cond
     [(fx= 0 (core-pvector-length pv))
      (make-core-pvector
       (make-pvector-single-tree (core-pvector-singleton-chunk value))
       1
       size)]
     [else
      (let* ([tree (core-pvector-tree pv)]
             [last-chunk (pvector-tree-last-node tree)]
             [tree^
              (if (fx< (pvector-chunk-length last-chunk) core-pvector-endpoint-pack-limit)
                  (pvector-tree-replace-last tree (pvector-chunk-append last-chunk value) 0)
                  (pvector-tree-cons-right tree (core-pvector-singleton-chunk value) 0))])
        (make-core-pvector tree^ (fx+ (core-pvector-length pv) 1) size))])))

(define (core-pvector-pop-left pv)
  (let* ([size (core-pvector-chunk-size pv)]
         [tree (core-pvector-tree pv)]
         [chunk (pvector-tree-first-node tree)]
         [value (pvector-chunk-ref chunk 0)]
         [chunk-len (pvector-chunk-length chunk)]
         [rest-tree
          (if (fx= chunk-len 1)
              (let-values ([(popped rest) (pvector-tree-pop-left tree 0)])
                rest)
              (pvector-tree-replace-first tree
                                          (pvector-chunk-slice chunk 1 chunk-len)
                                          0))])
    (values value
            (make-core-pvector rest-tree
                               (fx- (core-pvector-length pv) 1)
                               size))))

(define (core-pvector-pop-right pv)
  (let* ([size (core-pvector-chunk-size pv)]
         [tree (core-pvector-tree pv)]
         [chunk (pvector-tree-last-node tree)]
         [chunk-len (pvector-chunk-length chunk)]
         [value (pvector-chunk-ref chunk (fx- chunk-len 1))]
         [rest-tree
          (if (fx= chunk-len 1)
              (let-values ([(popped rest) (pvector-tree-pop-right tree 0)])
                rest)
              (pvector-tree-replace-last tree
                                         (pvector-chunk-slice chunk 0 (fx- chunk-len 1))
                                         0))])
    (values value
            (make-core-pvector rest-tree
                               (fx- (core-pvector-length pv) 1)
                               size))))

(define (core-pvector-append left right)
  (cond
   [(fx= 0 (core-pvector-length left)) right]
   [(fx= 0 (core-pvector-length right)) left]
   [else
    (make-core-pvector
     (pvector-tree-concat (core-pvector-tree left)
                          (core-pvector-tree right)
                          0)
     (fx+ (core-pvector-length left) (core-pvector-length right))
     (core-pvector-chunk-size left))]))

(define (core-pvector-split-at pv pos)
  (let ([len (core-pvector-length pv)]
        [size (core-pvector-chunk-size pv)])
    (cond
     [(fx= pos 0)
      (values (make-core-pvector empty-core-pvector-tree 0 size) pv)]
     [(fx= pos len)
      (values pv (make-core-pvector empty-core-pvector-tree 0 size))]
     [else
      (let-values ([(chunk-index left chunk right)
                    (pvector-split-tree (core-pvector-tree pv) pos 0)])
        (let* ([prefix (pvector-chunk-slice chunk 0 chunk-index)]
               [suffix (pvector-chunk-slice chunk chunk-index (pvector-chunk-length chunk))]
               [left^ (if prefix
                          (pvector-tree-cons-right left prefix 0)
                          left)]
               [right^ (if suffix
                           (pvector-tree-cons-left right suffix 0)
                           right)])
          (values (make-core-pvector left^ pos size)
                  (make-core-pvector right^ (fx- len pos) size))))])))

(define (core-pvector-split-at-right pv pos)
  (let ([split-pos (fx- (core-pvector-length pv) pos)])
    (let-values ([(left right) (core-pvector-split-at pv split-pos)])
      (values right left))))

(define (core-pvector-take pv pos)
  (cond
   [(fx= pos 0)
    (make-core-pvector empty-core-pvector-tree 0 (core-pvector-chunk-size pv))]
   [(fx= pos (core-pvector-length pv))
    pv]
   [else
    (let-values ([(left right) (core-pvector-split-at pv pos)])
      left)]))

(define (core-pvector-drop pv pos)
  (cond
   [(fx= pos 0) pv]
   [(fx= pos (core-pvector-length pv))
    (make-core-pvector empty-core-pvector-tree 0 (core-pvector-chunk-size pv))]
   [else
    (let-values ([(left right) (core-pvector-split-at pv pos)])
      right)]))

(define (core-pvector-copy pv start end)
  (cond
   [(fx= start end)
    (make-core-pvector empty-core-pvector-tree 0 (core-pvector-chunk-size pv))]
   [(and (fx= start 0) (fx= end (core-pvector-length pv)))
    pv]
   [(fx= start 0)
    (core-pvector-take pv end)]
   [(fx= end (core-pvector-length pv))
    (core-pvector-drop pv start)]
   [else
    (let-values ([(prefix after-end) (core-pvector-split-at pv end)])
      (let-values ([(before-start middle) (core-pvector-split-at prefix start)])
        middle))]))

(define (core-vector->pvector vec)
  (let ([len (#%vector-length vec)]
        [size default-core-pvector-chunk-size])
    (cond
     [(fx= len 0)
      empty-core-pvector]
     [else
      (let ([chunks (pvector-vector->chunks vec size)])
        (make-core-pvector (pvector-nodes-vector->tree chunks len) len size))])))

(define (core-list->pvector lst)
  (core-vector->pvector (list->vector lst)))

(define (core-make-pvector len value)
  (core-vector->pvector (make-vector len value)))

(define (core-pvector-fill-chunk! vec offset chunk)
  (let ([len (pvector-chunk-length chunk)])
    (let loop ([i 0])
      (unless (fx= i len)
        (#3%vector-set! vec (fx+ offset i) (pvector-chunk-ref chunk i))
        (loop (fx+ i 1))))
    (fx+ offset len)))

(define (core-pvector-fill-node! vec offset node depth)
  (cond
   [(fx= depth 0)
    (core-pvector-fill-chunk! vec offset node)]
   [(pvector-node2? node)
    (core-pvector-fill-node! vec
                             (core-pvector-fill-node! vec offset (pvector-node2-a node) (fx- depth 1))
                             (pvector-node2-b node)
                             (fx- depth 1))]
   [else
    (let ([sub-depth (fx- depth 1)])
      (core-pvector-fill-node! vec
                               (core-pvector-fill-node!
                                vec
                                (core-pvector-fill-node! vec offset (pvector-node3-a node) sub-depth)
                                (pvector-node3-b node)
                                sub-depth)
                               (pvector-node3-c node)
                               sub-depth))]))

(define (core-pvector-fill-digit! vec offset digit depth)
  (cond
   [(pvector-digit1? digit)
    (core-pvector-fill-node! vec offset (pvector-digit1-a digit) depth)]
   [(pvector-digit2? digit)
    (core-pvector-fill-node! vec
                             (core-pvector-fill-node! vec offset (pvector-digit2-a digit) depth)
                             (pvector-digit2-b digit)
                             depth)]
   [(pvector-digit3? digit)
    (core-pvector-fill-node! vec
                             (core-pvector-fill-node!
                              vec
                              (core-pvector-fill-node! vec offset (pvector-digit3-a digit) depth)
                              (pvector-digit3-b digit)
                              depth)
                             (pvector-digit3-c digit)
                             depth)]
   [else
    (core-pvector-fill-node! vec
                             (core-pvector-fill-node!
                              vec
                              (core-pvector-fill-node!
                               vec
                               (core-pvector-fill-node! vec offset (pvector-digit4-a digit) depth)
                               (pvector-digit4-b digit)
                               depth)
                              (pvector-digit4-c digit)
                              depth)
                             (pvector-digit4-d digit)
                             depth)]))

(define (core-pvector-fill-tree! vec offset tree depth)
  (cond
   [(pvector-empty-tree? tree) offset]
   [(pvector-single-tree? tree)
    (core-pvector-fill-node! vec offset (pvector-single-tree-a tree) depth)]
   [else
    (let ([inner-depth (fx+ depth 1)])
      (core-pvector-fill-digit!
       vec
       (core-pvector-fill-tree!
        vec
        (core-pvector-fill-digit! vec offset (pvector-deep-tree-left tree) depth)
        (pvector-deep-tree-inner tree)
        inner-depth)
       (pvector-deep-tree-right tree)
       depth))]))

(define (core-pvector->vector pv)
  (let ([vec (make-vector (core-pvector-length pv))])
    (core-pvector-fill-tree! vec 0 (core-pvector-tree pv) 0)
    vec))

(define (core-pvector->list pv)
  (vector->list (core-pvector->vector pv)))
