;; Fixed-measure persistent vector core candidate.
;;
;; This file is deliberately not exported yet. It establishes the Chez/Rumble
;; object model that the current Racket-level pvector backend can move to after
;; the shape and benchmark gates remain green.

(define default-core-pvector-chunk-size 64)
(define core-pvector-endpoint-pack-limit 8)
(define core-pvector-large-copy-composition-threshold 4096)
(define core-pvector-append-cache-chunk-limit 256)
(define core-pvector-endpoint-cache-chunk-limit 256)
(define core-pvector-slice-cache-chunk-limit 64)
(define core-pvector-copy-cache-chunk-limit 128)
(define core-pvector-edit-chunk-limit 8)

(define-record-type (core-pvector make-core-pvector* core-pvector?)
  [fields (immutable tree)
          (immutable length)
          (immutable chunk-size)
          (immutable chunks)]
  [nongenerative #{core-pvector cutie-pvector-runtime-11}]
  [sealed #t])

(define (make-core-pvector tree len size)
  (make-core-pvector* tree len size #f))

(define core-pvector-shifted-cache-chunk-limit 128)

(define-record-type core-pvector-shifted-cache
  [fields (immutable chunks)
          (immutable source-start)
          (immutable front-length)]
  [nongenerative #{core-pvector-shifted-cache cutie-pvector-runtime-13}]
  [sealed #t])

(define-record-type core-pvector-append-ref-cache
  [fields (immutable left)
          (immutable right)
          (immutable left-length)]
  [nongenerative #{core-pvector-append-ref-cache cutie-pvector-runtime-14}]
  [sealed #t])

(define-record-type pvector-leaf-chunk
  [fields (immutable vector)
          (immutable start)
          (immutable end)]
  [nongenerative #{pvector-leaf-chunk cutie-pvector-runtime-1}]
  [sealed #t])

(define-record-type pvector-edit-chunk
  [fields (immutable base)
          (immutable edits)
          (immutable count)]
  [nongenerative #{pvector-edit-chunk cutie-pvector-runtime-15}]
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

(define (core-empty-pvector/size size)
  (if (fx= size default-core-pvector-chunk-size)
      empty-core-pvector
      (make-core-pvector empty-core-pvector-tree 0 size)))

(define (make-core-pvector/with-chunks tree len size chunks)
  (make-core-pvector* tree len size chunks))

(define (core-pvector-cached-chunks pv)
  (let ([chunks (core-pvector-chunks pv)])
    (and (#%vector? chunks) chunks)))

(define (core-pvector-ref-cache pv)
  (let ([cache (core-pvector-chunks pv)])
    (cond
     [(#%vector? cache) cache]
     [(core-pvector-shifted-cache? cache) cache]
     [else #f])))

(define (core-pvector-ref-cache-slot-count cache)
  (cond
   [(#%vector? cache) (#%vector-length cache)]
   [(core-pvector-shifted-cache? cache)
    (#%vector-length (core-pvector-shifted-cache-chunks cache))]
   [else 0]))

(define (core-pvector-chunks-fixed-indexed? chunks len size)
  (let ([count (#%vector-length chunks)])
    (let loop ([index 0] [remaining len])
      (cond
       [(fx= index count)
        (fx= remaining 0)]
       [else
        (let ([chunk-len (pvector-chunk-length (#3%vector-ref chunks index))])
          (and (if (fx= index (fx- count 1))
                   (and (fx<= remaining size)
                        (fx= chunk-len remaining))
                   (fx= chunk-len size))
               (loop (fx+ index 1) (fx- remaining chunk-len))))]))))

(define (core-pvector-empty)
  empty-core-pvector)

(define (core-pvector-empty? pv)
  (and (core-pvector? pv)
       (fx= 0 (core-pvector-length pv))))

(define (pvector-leaf-vector? v)
  (#%vector? v))

(define (pvector-chunk? v)
  (or (pvector-leaf-vector? v)
      (pvector-leaf-chunk? v)
      (pvector-edit-chunk? v)))

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
  (cond
   [(pvector-leaf-vector? chunk)
    (#%vector-length chunk)]
   [(pvector-leaf-chunk? chunk)
    (fx- (pvector-leaf-chunk-end chunk)
         (pvector-leaf-chunk-start chunk))]
   [else
    (pvector-chunk-length (pvector-edit-chunk-base chunk))]))

(define (pvector-edit-chunk-ref chunk index)
  (let loop ([edits (pvector-edit-chunk-edits chunk)])
    (if (null? edits)
        (pvector-chunk-ref (pvector-edit-chunk-base chunk) index)
        (let ([edit (car edits)])
          (if (fx= index (car edit))
              (cdr edit)
              (loop (cdr edits)))))))

(define (pvector-chunk-ref chunk index)
  (cond
   [(pvector-leaf-vector? chunk)
    (#3%vector-ref chunk index)]
   [(pvector-leaf-chunk? chunk)
    (#3%vector-ref (pvector-leaf-chunk-vector chunk)
                   (fx+ (pvector-leaf-chunk-start chunk) index))]
   [else
    (pvector-edit-chunk-ref chunk index)]))

(define (pvector-vector-copy vec)
  (#%vector-copy vec))

(define (pvector-vector-copy-range vec start end)
  (#%vector-copy vec start (fx- end start)))

(define (pvector-vector-set/copy vec index value)
  (#2%vector-set/copy vec index value))

(define (pvector-vector->immutable vec)
  (#3%vector->immutable-vector vec))

(define (pvector-chunk-slice chunk start end)
  (cond
   [(fx= start end) #f]
   [(and (fx= start 0)
         (fx= end (pvector-chunk-length chunk)))
    chunk]
   [(pvector-leaf-vector? chunk)
    (make-pvector-leaf-chunk chunk start end)]
   [(pvector-edit-chunk? chunk)
    (pvector-chunk-slice (pvector-chunk->vector chunk) start end)]
   [else
    (make-pvector-leaf-chunk
     (pvector-leaf-chunk-vector chunk)
     (fx+ (pvector-leaf-chunk-start chunk) start)
     (fx+ (pvector-leaf-chunk-start chunk) end))]))

(define (pvector-chunk-split2 chunk)
  (let* ([len (pvector-chunk-length chunk)]
         [mid (fxquotient len 2)])
    (values (pvector-chunk-slice chunk 0 mid)
            (pvector-chunk-slice chunk mid len))))

(define (pvector-copy-chunk-range chunk start end)
  (let* ([len (fx- end start)]
         [vec (make-vector len)])
    (pvector-copy-chunk-range-to-vector! vec 0 chunk start end)
    (pvector-vector->immutable vec)))

(define (pvector-chunk-insert chunk index value)
  (let* ([len (pvector-chunk-length chunk)]
         [vec (make-vector (fx+ len 1))])
    (pvector-copy-chunk-range-to-vector! vec 0 chunk 0 index)
    (#3%vector-set! vec index value)
    (pvector-copy-chunk-range-to-vector! vec (fx+ index 1) chunk index len)
    (pvector-vector->immutable vec)))

(define (pvector-chunk-delete chunk index)
  (let* ([len (pvector-chunk-length chunk)]
         [vec (make-vector (fx- len 1))])
    (pvector-copy-chunk-range-to-vector! vec 0 chunk 0 index)
    (pvector-copy-chunk-range-to-vector! vec index chunk (fx+ index 1) len)
    (pvector-vector->immutable vec)))

(define (pvector-copy-vector-range-to-vector! dest dest-start src src-start src-end)
  (let ([len (fx- src-end src-start)])
    (let loop ([i len])
      (unless (fx= i 0)
        (let ([i (fx1- i)])
          (#3%vector-set! dest
                          (fx+ dest-start i)
                          (#3%vector-ref src (fx+ src-start i)))
          (loop i))))))

(define (pvector-copy-chunk-range-to-vector! dest dest-start chunk start end)
  (cond
   [(fx= start end)
    (void)]
   [(pvector-leaf-vector? chunk)
    (pvector-copy-vector-range-to-vector! dest dest-start chunk start end)]
   [(pvector-leaf-chunk? chunk)
    (pvector-copy-vector-range-to-vector! dest
                                          dest-start
                                          (pvector-leaf-chunk-vector chunk)
                                          (fx+ (pvector-leaf-chunk-start chunk) start)
                                          (fx+ (pvector-leaf-chunk-start chunk) end))]
   [else
    (let loop ([i start])
      (unless (fx= i end)
        (#3%vector-set! dest
                        (fx+ dest-start (fx- i start))
                        (pvector-chunk-ref chunk i))
        (loop (fx+ i 1))))]))

(define (pvector-copy-chunk-to-vector! dest dest-start chunk)
  (pvector-copy-chunk-range-to-vector! dest
                                       dest-start
                                       chunk
                                       0
                                       (pvector-chunk-length chunk)))

(define (pvector-chunk->vector chunk)
  (cond
   [(pvector-leaf-vector? chunk)
    (pvector-vector-copy chunk)]
   [(pvector-leaf-chunk? chunk)
    (pvector-vector-copy-range (pvector-leaf-chunk-vector chunk)
                               (pvector-leaf-chunk-start chunk)
                               (pvector-leaf-chunk-end chunk))]
   [else
    (let* ([len (pvector-chunk-length chunk)]
           [vec (make-vector len)])
      (pvector-copy-chunk-range-to-vector! vec 0 chunk 0 len)
      vec)]))

(define (pvector-chunk->list/reverse chunk acc)
  (cond
   [(pvector-leaf-vector? chunk)
    (let loop ([i (fx- (#%vector-length chunk) 1)] [acc acc])
      (if (fx< i 0)
          acc
          (loop (fx- i 1) (cons (#3%vector-ref chunk i) acc))))]
   [(pvector-leaf-chunk? chunk)
    (let ([vec (pvector-leaf-chunk-vector chunk)]
          [start (pvector-leaf-chunk-start chunk)])
      (let loop ([i (fx- (pvector-leaf-chunk-end chunk) 1)] [acc acc])
        (if (fx< i start)
            acc
            (loop (fx- i 1) (cons (#3%vector-ref vec i) acc)))))]
   [else
    (let loop ([i (fx- (pvector-chunk-length chunk) 1)] [acc acc])
      (if (fx< i 0)
          acc
          (loop (fx- i 1) (cons (pvector-chunk-ref chunk i) acc))))]))

(define (pvector-chunk-set chunk index value)
  (if (eq? (pvector-chunk-ref chunk index) value)
      chunk
      (cond
       [(pvector-edit-chunk? chunk)
        (if (fx< (pvector-edit-chunk-count chunk) core-pvector-edit-chunk-limit)
            (make-pvector-edit-chunk
             (pvector-edit-chunk-base chunk)
             (cons (cons index value) (pvector-edit-chunk-edits chunk))
             (fx+ (pvector-edit-chunk-count chunk) 1))
            (let ([vec (pvector-chunk->vector chunk)])
              (#3%vector-set! vec index value)
              (pvector-vector->immutable vec)))]
       [(pvector-leaf-vector? chunk)
        (make-pvector-edit-chunk chunk (list (cons index value)) 1)]
       [else
        (let ([start (pvector-leaf-chunk-start chunk)]
              [end (pvector-leaf-chunk-end chunk)]
              [vec (pvector-leaf-chunk-vector chunk)])
          (if (and (fx= start 0)
                   (fx= end (#%vector-length vec)))
              (make-pvector-edit-chunk chunk (list (cons index value)) 1)
              (let ([vec (pvector-vector-copy-range vec start end)])
                (#3%vector-set! vec index value)
                (pvector-vector->immutable vec))))])))

(define (pvector-chunk-prepend chunk value)
  (let* ([len (pvector-chunk-length chunk)]
         [vec (make-vector (fx+ len 1))])
    (#3%vector-set! vec 0 value)
    (pvector-copy-chunk-range-to-vector! vec 1 chunk 0 len)
    (pvector-vector->immutable vec)))

(define (pvector-chunk-append chunk value)
  (let* ([len (pvector-chunk-length chunk)]
         [vec (make-vector (fx+ len 1))])
    (pvector-copy-chunk-range-to-vector! vec 0 chunk 0 len)
    (#3%vector-set! vec len value)
    (pvector-vector->immutable vec)))

(define (pvector-chunk-append-chunk left right)
  (if (and (pvector-leaf-vector? left)
           (pvector-leaf-vector? right))
      (immutable-vector-append left right)
      (let* ([left-len (pvector-chunk-length left)]
             [right-len (pvector-chunk-length right)]
             [vec (make-vector (fx+ left-len right-len))])
        (pvector-copy-chunk-to-vector! vec 0 left)
        (pvector-copy-chunk-to-vector! vec left-len right)
        (pvector-vector->immutable vec))))

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

(define (core-pvector-shape-stats pv)
  (let ([h (make-hasheq)]
        [slice-bases (make-hasheq)]
        [max-depth 0])
    (define (inc! k n)
      (hash-set! h k (+ (hash-ref h k 0) n)))
    (define (note-depth! depth)
      (when (> depth max-depth)
        (set! max-depth depth)))
    (define (walk-chunk chunk)
      (let ([len (pvector-chunk-length chunk)])
        (inc! 'leaves 1)
        (inc! 'visible-elems len)
        (when (= len 1)
          (inc! 'singleton-leaves 1))
        (when (= len (core-pvector-chunk-size pv))
          (inc! 'full-leaves 1))
        (cond
         [(pvector-leaf-vector? chunk)
          (inc! 'vector-leaves 1)
          (inc! 'retained-elems len)]
         [else
          (let ([vec (pvector-leaf-chunk-vector chunk)])
            (inc! 'slice-leaves 1)
            (unless (hash-ref slice-bases vec #f)
              (inc! 'retained-elems (#%vector-length vec))
              (hash-set! slice-bases vec #t)))])))
    (define (walk-node node depth)
      (note-depth! depth)
      (cond
       [(fx= depth 0)
        (walk-chunk node)]
       [(pvector-node2? node)
        (inc! 'node2 1)
        (let ([sub-depth (fx- depth 1)])
          (walk-node (pvector-node2-a node) sub-depth)
          (walk-node (pvector-node2-b node) sub-depth))]
       [else
        (inc! 'node3 1)
        (let ([sub-depth (fx- depth 1)])
          (walk-node (pvector-node3-a node) sub-depth)
          (walk-node (pvector-node3-b node) sub-depth)
          (walk-node (pvector-node3-c node) sub-depth))]))
    (define (walk-digit digit depth)
      (note-depth! depth)
      (cond
       [(pvector-digit1? digit)
        (inc! 'digit1 1)
        (walk-node (pvector-digit1-a digit) depth)]
       [(pvector-digit2? digit)
        (inc! 'digit2 1)
        (walk-node (pvector-digit2-a digit) depth)
        (walk-node (pvector-digit2-b digit) depth)]
       [(pvector-digit3? digit)
        (inc! 'digit3 1)
        (walk-node (pvector-digit3-a digit) depth)
        (walk-node (pvector-digit3-b digit) depth)
        (walk-node (pvector-digit3-c digit) depth)]
       [else
        (inc! 'digit4 1)
        (walk-node (pvector-digit4-a digit) depth)
        (walk-node (pvector-digit4-b digit) depth)
        (walk-node (pvector-digit4-c digit) depth)
        (walk-node (pvector-digit4-d digit) depth)]))
    (define (walk-tree tree depth)
      (note-depth! depth)
      (cond
       [(pvector-empty-tree? tree)
        (inc! 'ft-empty 1)]
       [(pvector-single-tree? tree)
        (inc! 'ft-single 1)
        (walk-node (pvector-single-tree-a tree) depth)]
       [else
        (inc! 'ft-deep 1)
        (walk-digit (pvector-deep-tree-left tree) depth)
        (walk-tree (pvector-deep-tree-inner tree) (fx+ depth 1))
        (walk-digit (pvector-deep-tree-right tree) depth)]))
    (walk-tree (core-pvector-tree pv) 0)
    (let ([cache (core-pvector-chunks pv)])
      (cond
       [(#%vector? cache)
        (inc! 'chunk-index-vectors 1)
        (inc! 'chunk-index-slots (#%vector-length cache))]
       [(core-pvector-shifted-cache? cache)
        (let ([chunks (core-pvector-shifted-cache-chunks cache)])
          (inc! 'chunk-index-vectors 1)
          (inc! 'chunk-index-slots (#%vector-length chunks))
          (inc! 'shifted-cache-index-vectors 1)
          (hash-set! h
                     'shifted-cache-source-start
                     (core-pvector-shifted-cache-source-start cache))
          (hash-set! h
                     'shifted-cache-front-length
                     (core-pvector-shifted-cache-front-length cache)))]
       [(core-pvector-append-ref-cache? cache)
        (let* ([left (core-pvector-append-ref-cache-left cache)]
               [right (core-pvector-append-ref-cache-right cache)]
               [left-cache (core-pvector-ref-cache left)]
               [right-cache (core-pvector-ref-cache right)]
               [left-slots (core-pvector-ref-cache-slot-count left-cache)]
               [right-slots (core-pvector-ref-cache-slot-count right-cache)])
          (inc! 'append-ref-cache-index-vectors 1)
          (inc! 'chunk-index-vectors
                (fx+ (if left-cache 1 0) (if right-cache 1 0)))
          (inc! 'chunk-index-slots (fx+ left-slots right-slots))
          (hash-set! h 'append-ref-cache-left-length
                     (core-pvector-append-ref-cache-left-length cache))
          (hash-set! h 'append-ref-cache-left-slots left-slots)
          (hash-set! h 'append-ref-cache-right-slots right-slots))]))
    (hash-set! h 'backend 'core)
    (hash-set! h 'max-depth max-depth)
    (hash-set! h 'length (core-pvector-length pv))
    (hash-set! h 'chunk-size (core-pvector-chunk-size pv))
    (hash-set! h 'slice-base-vectors (hash-count slice-bases))
    h))

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
                          (pvector-vector->immutable
                           (pvector-vector-copy-range vec start end))))
        (loop (fx+ chunk-index 1))))
    chunks))

(define (pvector-immutable-vector->slice-chunks vec size)
  (let* ([len (#%vector-length vec)]
         [chunk-count (fxquotient (fx+ len (fx- size 1)) size)]
         [chunks (make-vector chunk-count)])
    (let loop ([chunk-index 0])
      (unless (fx= chunk-index chunk-count)
        (let* ([start (fx* chunk-index size)]
               [end (fxmin len (fx+ start size))])
          (#3%vector-set! chunks chunk-index
                          (make-pvector-leaf-chunk vec start end)))
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
  (cond
   [(pvector-digit1? digit)
    (let* ([a (pvector-digit1-a digit)]
           [a-size (pvector-subtree-measure a)])
      (if (fx< index a-size)
          (values index null a null)
          (error 'pvector-split-digit "index out of digit")))]
   [(pvector-digit2? digit)
    (let* ([a (pvector-digit2-a digit)]
           [b (pvector-digit2-b digit)]
           [a-size (pvector-subtree-measure a)]
           [ab-size (fx+ a-size (pvector-subtree-measure b))])
      (cond
       [(fx< index a-size)
        (values index null a (list b))]
       [(fx< index ab-size)
        (values (fx- index a-size) (list a) b null)]
       [else
        (error 'pvector-split-digit "index out of digit")]))]
   [(pvector-digit3? digit)
    (let* ([a (pvector-digit3-a digit)]
           [b (pvector-digit3-b digit)]
           [c (pvector-digit3-c digit)]
           [a-size (pvector-subtree-measure a)]
           [b-size (pvector-subtree-measure b)]
           [ab-size (fx+ a-size b-size)]
           [abc-size (fx+ ab-size (pvector-subtree-measure c))])
      (cond
       [(fx< index a-size)
        (values index null a (list b c))]
       [(fx< index ab-size)
        (values (fx- index a-size) (list a) b (list c))]
       [(fx< index abc-size)
        (values (fx- index ab-size) (list a b) c null)]
       [else
        (error 'pvector-split-digit "index out of digit")]))]
   [else
    (let* ([a (pvector-digit4-a digit)]
           [b (pvector-digit4-b digit)]
           [c (pvector-digit4-c digit)]
           [d (pvector-digit4-d digit)]
           [a-size (pvector-subtree-measure a)]
           [b-size (pvector-subtree-measure b)]
           [c-size (pvector-subtree-measure c)]
           [ab-size (fx+ a-size b-size)]
           [abc-size (fx+ ab-size c-size)]
           [abcd-size (fx+ abc-size (pvector-subtree-measure d))])
      (cond
       [(fx< index a-size)
        (values index null a (list b c d))]
       [(fx< index ab-size)
        (values (fx- index a-size) (list a) b (list c d))]
       [(fx< index abc-size)
        (values (fx- index ab-size) (list a b) c (list d))]
       [(fx< index abcd-size)
        (values (fx- index abc-size) (list a b c) d null)]
       [else
        (error 'pvector-split-digit "index out of digit")]))]))

(define (pvector-split-node node index depth)
  (cond
   [(pvector-node2? node)
    (let* ([a (pvector-node2-a node)]
           [b (pvector-node2-b node)]
           [a-size (pvector-subtree-measure a)]
           [ab-size (fx+ a-size (pvector-subtree-measure b))])
      (cond
       [(fx< index a-size)
        (values index null a (list b))]
       [(fx< index ab-size)
        (values (fx- index a-size) (list a) b null)]
       [else
        (error 'pvector-split-node "index out of node")]))]
   [else
    (let* ([a (pvector-node3-a node)]
           [b (pvector-node3-b node)]
           [c (pvector-node3-c node)]
           [a-size (pvector-subtree-measure a)]
           [b-size (pvector-subtree-measure b)]
           [ab-size (fx+ a-size b-size)]
           [abc-size (fx+ ab-size (pvector-subtree-measure c))])
      (cond
       [(fx< index a-size)
        (values index null a (list b c))]
       [(fx< index ab-size)
        (values (fx- index a-size) (list a) b (list c))]
       [(fx< index abc-size)
        (values (fx- index ab-size) (list a b) c null)]
       [else
        (error 'pvector-split-node "index out of node")]))]))

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

(define (pvector-insert-node/direct node index value depth size)
  (if (fx= depth 0)
      (if (fx< (pvector-chunk-length node) size)
          (values (pvector-chunk-insert node index value) #t)
          (values #f #f))
      (let ([sub-depth (fx- depth 1)])
        (cond
         [(pvector-node2? node)
          (let* ([a (pvector-node2-a node)]
                 [b (pvector-node2-b node)]
                 [a-size (pvector-subtree-measure a)])
            (if (fx< index a-size)
                (let-values ([(a^ ok?)
                              (pvector-insert-node/direct a index value sub-depth size)])
                  (if ok?
                      (values (make-pvector-node2 (fx+ (pvector-node2-measure node) 1)
                                                  a^
                                                  b)
                              #t)
                      (values #f #f)))
                (let-values ([(b^ ok?)
                              (pvector-insert-node/direct b
                                                          (fx- index a-size)
                                                          value
                                                          sub-depth
                                                          size)])
                  (if ok?
                      (values (make-pvector-node2 (fx+ (pvector-node2-measure node) 1)
                                                  a
                                                  b^)
                              #t)
                      (values #f #f)))))]
         [else
          (let* ([a (pvector-node3-a node)]
                 [b (pvector-node3-b node)]
                 [c (pvector-node3-c node)]
                 [a-size (pvector-subtree-measure a)]
                 [b-size (pvector-subtree-measure b)]
                 [ab-size (fx+ a-size b-size)])
            (cond
             [(fx< index a-size)
              (let-values ([(a^ ok?)
                            (pvector-insert-node/direct a index value sub-depth size)])
                (if ok?
                    (values (make-pvector-node3 (fx+ (pvector-node3-measure node) 1)
                                                a^
                                                b
                                                c)
                            #t)
                    (values #f #f)))]
             [(fx< index ab-size)
              (let-values ([(b^ ok?)
                            (pvector-insert-node/direct b
                                                        (fx- index a-size)
                                                        value
                                                        sub-depth
                                                        size)])
                (if ok?
                    (values (make-pvector-node3 (fx+ (pvector-node3-measure node) 1)
                                                a
                                                b^
                                                c)
                            #t)
                    (values #f #f)))]
             [else
              (let-values ([(c^ ok?)
                            (pvector-insert-node/direct c
                                                        (fx- index ab-size)
                                                        value
                                                        sub-depth
                                                        size)])
                (if ok?
                    (values (make-pvector-node3 (fx+ (pvector-node3-measure node) 1)
                                                a
                                                b
                                                c^)
                            #t)
                    (values #f #f)))]))]))))

(define (pvector-insert-digit/direct digit index value depth size)
  (cond
   [(pvector-digit1? digit)
    (let-values ([(a^ ok?)
                  (pvector-insert-node/direct (pvector-digit1-a digit)
                                              index
                                              value
                                              depth
                                              size)])
      (if ok?
          (values (make-pvector-digit1 a^) #t)
          (values #f #f)))]
   [(pvector-digit2? digit)
    (let* ([a (pvector-digit2-a digit)]
           [b (pvector-digit2-b digit)]
           [a-size (pvector-subtree-measure a)])
      (if (fx< index a-size)
          (let-values ([(a^ ok?)
                        (pvector-insert-node/direct a index value depth size)])
            (if ok?
                (values (make-pvector-digit2 a^ b) #t)
                (values #f #f)))
          (let-values ([(b^ ok?)
                        (pvector-insert-node/direct b
                                                    (fx- index a-size)
                                                    value
                                                    depth
                                                    size)])
            (if ok?
                (values (make-pvector-digit2 a b^) #t)
                (values #f #f)))))]
   [(pvector-digit3? digit)
    (let* ([a (pvector-digit3-a digit)]
           [b (pvector-digit3-b digit)]
           [c (pvector-digit3-c digit)]
           [a-size (pvector-subtree-measure a)]
           [b-size (pvector-subtree-measure b)]
           [ab-size (fx+ a-size b-size)])
      (cond
       [(fx< index a-size)
        (let-values ([(a^ ok?)
                      (pvector-insert-node/direct a index value depth size)])
          (if ok?
              (values (make-pvector-digit3 a^ b c) #t)
              (values #f #f)))]
       [(fx< index ab-size)
        (let-values ([(b^ ok?)
                      (pvector-insert-node/direct b
                                                  (fx- index a-size)
                                                  value
                                                  depth
                                                  size)])
          (if ok?
              (values (make-pvector-digit3 a b^ c) #t)
              (values #f #f)))]
       [else
        (let-values ([(c^ ok?)
                      (pvector-insert-node/direct c
                                                  (fx- index ab-size)
                                                  value
                                                  depth
                                                  size)])
          (if ok?
              (values (make-pvector-digit3 a b c^) #t)
              (values #f #f)))]))]
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
        (let-values ([(a^ ok?)
                      (pvector-insert-node/direct a index value depth size)])
          (if ok?
              (values (make-pvector-digit4 a^ b c d) #t)
              (values #f #f)))]
       [(fx< index ab-size)
        (let-values ([(b^ ok?)
                      (pvector-insert-node/direct b
                                                  (fx- index a-size)
                                                  value
                                                  depth
                                                  size)])
          (if ok?
              (values (make-pvector-digit4 a b^ c d) #t)
              (values #f #f)))]
       [(fx< index abc-size)
        (let-values ([(c^ ok?)
                      (pvector-insert-node/direct c
                                                  (fx- index ab-size)
                                                  value
                                                  depth
                                                  size)])
          (if ok?
              (values (make-pvector-digit4 a b c^ d) #t)
              (values #f #f)))]
       [else
        (let-values ([(d^ ok?)
                      (pvector-insert-node/direct d
                                                  (fx- index abc-size)
                                                  value
                                                  depth
                                                  size)])
          (if ok?
              (values (make-pvector-digit4 a b c d^) #t)
              (values #f #f)))]))]))

(define (pvector-insert-tree/direct tree index value depth size)
  (cond
   [(pvector-empty-tree? tree)
    (error 'pvector-insert-tree/direct "empty tree")]
   [(pvector-single-tree? tree)
    (let ([node (pvector-single-tree-a tree)])
      (when (fx>= index (pvector-subtree-measure node))
        (error 'pvector-insert-tree/direct "index out of single node"))
      (let-values ([(node^ ok?)
                    (pvector-insert-node/direct node index value depth size)])
        (if ok?
            (values (make-pvector-single-tree node^) #t)
            (values #f #f))))]
   [else
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
        (let-values ([(left^ ok?)
                      (pvector-insert-digit/direct left index value depth size)])
          (if ok?
              (values (make-pvector-deep-tree (fx+ total 1) left^ inner right) #t)
              (values #f #f)))]
       [(fx< index left+inner-size)
        (let-values ([(inner^ ok?)
                      (pvector-insert-tree/direct inner
                                                  (fx- index left-size)
                                                  value
                                                  inner-depth
                                                  size)])
          (if ok?
              (values (make-pvector-deep-tree (fx+ total 1) left inner^ right) #t)
              (values #f #f)))]
       [(fx< index total)
        (let-values ([(right^ ok?)
                      (pvector-insert-digit/direct right
                                                   (fx- index left+inner-size)
                                                   value
                                                   depth
                                                   size)])
          (if ok?
              (values (make-pvector-deep-tree (fx+ total 1) left inner right^) #t)
              (values #f #f)))]
       [else
        (error 'pvector-insert-tree/direct "index out of tree")]))]))

(define (pvector-chunk-insert/splice chunk index value size)
  (let ([len (pvector-chunk-length chunk)])
    (if (fx< len size)
        (list (pvector-chunk-insert chunk index value))
        (let ([prefix (pvector-chunk-slice chunk 0 index)]
              [middle (core-pvector-singleton-chunk value)]
              [suffix (pvector-chunk-slice chunk index len)])
          (if prefix
              (list prefix middle suffix)
              (list middle suffix))))))

(define (pvector-insert-node/splice node index value depth size)
  (if (fx= depth 0)
      (pvector-chunk-insert/splice node index value size)
      (let ([sub-depth (fx- depth 1)])
        (cond
         [(pvector-node2? node)
          (let* ([a (pvector-node2-a node)]
                 [b (pvector-node2-b node)]
                 [a-size (pvector-subtree-measure a)])
            (if (fx< index a-size)
                (pvector-node-list->nodes
                 (append (pvector-insert-node/splice a index value sub-depth size)
                         (list b))
                 depth)
                (pvector-node-list->nodes
                 (cons a
                       (pvector-insert-node/splice b
                                                   (fx- index a-size)
                                                   value
                                                   sub-depth
                                                   size))
                 depth)))]
         [else
          (let* ([a (pvector-node3-a node)]
                 [b (pvector-node3-b node)]
                 [c (pvector-node3-c node)]
                 [a-size (pvector-subtree-measure a)]
                 [b-size (pvector-subtree-measure b)]
                 [ab-size (fx+ a-size b-size)])
            (cond
             [(fx< index a-size)
              (pvector-node-list->nodes
               (append (pvector-insert-node/splice a index value sub-depth size)
                       (list b c))
               depth)]
             [(fx< index ab-size)
              (pvector-node-list->nodes
               (cons a
                     (append (pvector-insert-node/splice b
                                                         (fx- index a-size)
                                                         value
                                                         sub-depth
                                                         size)
                             (list c)))
               depth)]
             [else
              (pvector-node-list->nodes
               (cons a
                     (cons b
                           (pvector-insert-node/splice c
                                                       (fx- index ab-size)
                                                       value
                                                       sub-depth
                                                       size)))
               depth)]))]))))

(define (pvector-insert-digit/splice digit index value depth size)
  (cond
   [(pvector-digit1? digit)
    (pvector-insert-node/splice (pvector-digit1-a digit) index value depth size)]
   [(pvector-digit2? digit)
    (let* ([a (pvector-digit2-a digit)]
           [b (pvector-digit2-b digit)]
           [a-size (pvector-subtree-measure a)])
      (if (fx< index a-size)
          (append (pvector-insert-node/splice a index value depth size)
                  (list b))
          (cons a
                (pvector-insert-node/splice b (fx- index a-size) value depth size))))]
   [(pvector-digit3? digit)
    (let* ([a (pvector-digit3-a digit)]
           [b (pvector-digit3-b digit)]
           [c (pvector-digit3-c digit)]
           [a-size (pvector-subtree-measure a)]
           [b-size (pvector-subtree-measure b)]
           [ab-size (fx+ a-size b-size)])
      (cond
       [(fx< index a-size)
        (append (pvector-insert-node/splice a index value depth size)
                (list b c))]
       [(fx< index ab-size)
        (cons a
              (append (pvector-insert-node/splice b
                                                  (fx- index a-size)
                                                  value
                                                  depth
                                                  size)
                      (list c)))]
       [else
        (cons a
              (cons b
                    (pvector-insert-node/splice c
                                                (fx- index ab-size)
                                                value
                                                depth
                                                size)))]))]
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
        (append (pvector-insert-node/splice a index value depth size)
                (list b c d))]
       [(fx< index ab-size)
        (cons a
              (append (pvector-insert-node/splice b
                                                  (fx- index a-size)
                                                  value
                                                  depth
                                                  size)
                      (list c d)))]
       [(fx< index abc-size)
        (cons a
              (cons b
                    (append (pvector-insert-node/splice c
                                                        (fx- index ab-size)
                                                        value
                                                        depth
                                                        size)
                            (list d))))]
       [else
        (cons a
              (cons b
                    (cons c
                          (pvector-insert-node/splice d
                                                      (fx- index abc-size)
                                                      value
                                                      depth
                                                      size))))]))]))

(define (pvector-deep-tree-left-splice total nodes inner right depth)
  (let ([len (length nodes)])
    (cond
     [(fx<= len 4)
      (make-pvector-deep-tree total (pvector-list->digit nodes) inner right)]
     [(fx= len 5)
      (make-pvector-deep-tree
       total
       (make-pvector-digit2 (car nodes) (cadr nodes))
       (pvector-tree-cons-left inner
                               (pvector-make-node3 (caddr nodes)
                                                   (cadddr nodes)
                                                   (car (cddddr nodes)))
                               (fx+ depth 1))
       right)]
     [else
      (make-pvector-deep-tree
       total
       (make-pvector-digit3 (car nodes) (cadr nodes) (caddr nodes))
       (pvector-tree-cons-left inner
                               (pvector-make-node3 (cadddr nodes)
                                                   (car (cddddr nodes))
                                                   (cadr (cddddr nodes)))
                               (fx+ depth 1))
       right)])))

(define (pvector-deep-tree-right-splice total left inner nodes depth)
  (let ([len (length nodes)])
    (cond
     [(fx<= len 4)
      (make-pvector-deep-tree total left inner (pvector-list->digit nodes))]
     [(fx= len 5)
      (make-pvector-deep-tree
       total
       left
       (pvector-tree-cons-right inner
                                (pvector-make-node3 (car nodes)
                                                    (cadr nodes)
                                                    (caddr nodes))
                                (fx+ depth 1))
       (make-pvector-digit2 (cadddr nodes)
                            (car (cddddr nodes))))]
     [else
      (make-pvector-deep-tree
       total
       left
       (pvector-tree-cons-right inner
                                (pvector-make-node3 (car nodes)
                                                    (cadr nodes)
                                                    (caddr nodes))
                                (fx+ depth 1))
       (make-pvector-digit3 (cadddr nodes)
                            (car (cddddr nodes))
                            (cadr (cddddr nodes))))])))

(define (pvector-insert-tree/splice tree index value depth size)
  (cond
   [(pvector-empty-tree? tree)
    (error 'pvector-insert-tree/splice "empty tree")]
   [(pvector-single-tree? tree)
    (let ([node (pvector-single-tree-a tree)])
      (when (fx>= index (pvector-subtree-measure node))
        (error 'pvector-insert-tree/splice "index out of single node"))
      (pvector-digit-list->tree
       (pvector-insert-node/splice node index value depth size)
       depth))]
   [else
    (let* ([total (pvector-deep-tree-measure tree)]
           [new-total (fx+ total 1)]
           [left (pvector-deep-tree-left tree)]
           [inner (pvector-deep-tree-inner tree)]
           [right (pvector-deep-tree-right tree)]
           [inner-depth (fx+ depth 1)]
           [left-size (pvector-digit-measure left)]
           [inner-size (pvector-tree-measure inner)]
           [left+inner-size (fx+ left-size inner-size)])
      (cond
       [(fx< index left-size)
        (pvector-deep-tree-left-splice
         new-total
         (pvector-insert-digit/splice left index value depth size)
         inner
         right
         depth)]
       [(fx< index left+inner-size)
        (make-pvector-deep-tree
         new-total
         left
         (pvector-insert-tree/splice inner
                                     (fx- index left-size)
                                     value
                                     inner-depth
                                     size)
         right)]
       [(fx< index total)
        (pvector-deep-tree-right-splice
         new-total
         left
         inner
         (pvector-insert-digit/splice right
                                      (fx- index left+inner-size)
                                      value
                                      depth
                                      size)
         depth)]
       [else
        (error 'pvector-insert-tree/splice "index out of tree")]))]))

(define (pvector-split-tree-left tree index depth)
  (cond
   ((pvector-empty-tree? tree)
    (error 'pvector-split-tree-left "empty tree"))
   ((pvector-single-tree? tree)
    (let ([node (pvector-single-tree-a tree)])
      (when (fx>= index (pvector-subtree-measure node))
        (error 'pvector-split-tree-left "index out of single node"))
      (values index empty-core-pvector-tree node)))
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
          (values index^ (pvector-digit-list->tree l depth) node)))
       ((fx< index left+inner-size)
        (let-values ([(rest-index inner-left node)
                      (pvector-split-tree-left inner (fx- index left-size) inner-depth)])
          (let* ([left^ (pvector-left-digit+tree->tree left inner-left depth)])
            (let-values ([(index^ l node^ r)
                          (pvector-split-node node rest-index inner-depth)])
              (values index^
                      (pvector-tree-add-right-list left^ l depth)
                      node^)))))
       ((fx< index total)
        (let-values ([(index^ l node r)
                      (pvector-split-digit right (fx- index left+inner-size) depth)])
          (let ([left^
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
            (values index^ left^ node))))
       (else
        (error 'pvector-split-tree-left "index out of tree")))))))

(define (pvector-split-tree-right tree index depth)
  (cond
   ((pvector-empty-tree? tree)
    (error 'pvector-split-tree-right "empty tree"))
   ((pvector-single-tree? tree)
    (let ([node (pvector-single-tree-a tree)])
      (when (fx>= index (pvector-subtree-measure node))
        (error 'pvector-split-tree-right "index out of single node"))
      (values index node empty-core-pvector-tree)))
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
          (let ([right^
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
            (values index^ node right^))))
       ((fx< index left+inner-size)
        (let-values ([(rest-index node inner-right)
                      (pvector-split-tree-right inner (fx- index left-size) inner-depth)])
          (let* ([right^ (pvector-right-digit+tree->tree right inner-right depth)])
            (let-values ([(index^ l node^ r)
                          (pvector-split-node node rest-index inner-depth)])
              (values index^
                      node^
                      (pvector-tree-add-left-list right^ r depth))))))
       ((fx< index total)
        (let-values ([(index^ l node r)
                      (pvector-split-digit right (fx- index left+inner-size) depth)])
          (values index^ node (pvector-digit-list->tree r depth))))
       (else
        (error 'pvector-split-tree-right "index out of tree")))))))

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

(define (core-pvector-ref-node1 node index)
  (cond
   [(pvector-node2? node)
    (let* ([a (pvector-node2-a node)]
           [a-size (pvector-chunk-length a)])
      (if (fx< index a-size)
          (pvector-chunk-ref a index)
          (pvector-chunk-ref (pvector-node2-b node) (fx- index a-size))))]
   [else
    (let* ([a (pvector-node3-a node)]
           [b (pvector-node3-b node)]
           [a-size (pvector-chunk-length a)]
           [b-size (pvector-chunk-length b)]
           [ab-size (fx+ a-size b-size)])
      (cond
       [(fx< index a-size)
        (pvector-chunk-ref a index)]
       [(fx< index ab-size)
        (pvector-chunk-ref b (fx- index a-size))]
       [else
        (pvector-chunk-ref (pvector-node3-c node) (fx- index ab-size))]))]))

(define (core-pvector-ref-node2 node index)
  (cond
   [(pvector-node2? node)
    (let* ([a (pvector-node2-a node)]
           [a-size (pvector-subtree-measure a)])
      (if (fx< index a-size)
          (core-pvector-ref-node1 a index)
          (core-pvector-ref-node1 (pvector-node2-b node) (fx- index a-size))))]
   [else
    (let* ([a (pvector-node3-a node)]
           [b (pvector-node3-b node)]
           [a-size (pvector-subtree-measure a)]
           [b-size (pvector-subtree-measure b)]
           [ab-size (fx+ a-size b-size)])
      (cond
       [(fx< index a-size)
        (core-pvector-ref-node1 a index)]
       [(fx< index ab-size)
        (core-pvector-ref-node1 b (fx- index a-size))]
       [else
        (core-pvector-ref-node1 (pvector-node3-c node) (fx- index ab-size))]))]))

(define (core-pvector-ref-digit1 digit index)
  (cond
   [(pvector-digit1? digit)
    (core-pvector-ref-node1 (pvector-digit1-a digit) index)]
   [(pvector-digit2? digit)
    (let* ([a (pvector-digit2-a digit)]
           [a-size (pvector-subtree-measure a)])
      (if (fx< index a-size)
          (core-pvector-ref-node1 a index)
          (core-pvector-ref-node1 (pvector-digit2-b digit) (fx- index a-size))))]
   [(pvector-digit3? digit)
    (let* ([a (pvector-digit3-a digit)]
           [b (pvector-digit3-b digit)]
           [a-size (pvector-subtree-measure a)]
           [b-size (pvector-subtree-measure b)]
           [ab-size (fx+ a-size b-size)])
      (cond
       [(fx< index a-size)
        (core-pvector-ref-node1 a index)]
       [(fx< index ab-size)
        (core-pvector-ref-node1 b (fx- index a-size))]
       [else
        (core-pvector-ref-node1 (pvector-digit3-c digit) (fx- index ab-size))]))]
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
        (core-pvector-ref-node1 a index)]
       [(fx< index ab-size)
        (core-pvector-ref-node1 b (fx- index a-size))]
       [(fx< index abc-size)
        (core-pvector-ref-node1 c (fx- index ab-size))]
       [else
        (core-pvector-ref-node1 (pvector-digit4-d digit) (fx- index abc-size))]))]))

(define (core-pvector-ref-digit2 digit index)
  (cond
   [(pvector-digit1? digit)
    (core-pvector-ref-node2 (pvector-digit1-a digit) index)]
   [(pvector-digit2? digit)
    (let* ([a (pvector-digit2-a digit)]
           [a-size (pvector-subtree-measure a)])
      (if (fx< index a-size)
          (core-pvector-ref-node2 a index)
          (core-pvector-ref-node2 (pvector-digit2-b digit) (fx- index a-size))))]
   [(pvector-digit3? digit)
    (let* ([a (pvector-digit3-a digit)]
           [b (pvector-digit3-b digit)]
           [a-size (pvector-subtree-measure a)]
           [b-size (pvector-subtree-measure b)]
           [ab-size (fx+ a-size b-size)])
      (cond
       [(fx< index a-size)
        (core-pvector-ref-node2 a index)]
       [(fx< index ab-size)
        (core-pvector-ref-node2 b (fx- index a-size))]
       [else
        (core-pvector-ref-node2 (pvector-digit3-c digit) (fx- index ab-size))]))]
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
        (core-pvector-ref-node2 a index)]
       [(fx< index ab-size)
        (core-pvector-ref-node2 b (fx- index a-size))]
       [(fx< index abc-size)
        (core-pvector-ref-node2 c (fx- index ab-size))]
       [else
        (core-pvector-ref-node2 (pvector-digit4-d digit) (fx- index abc-size))]))]))

(define (core-pvector-ref-node3 node index)
  (cond
   [(pvector-node2? node)
    (let* ([a (pvector-node2-a node)]
           [a-size (pvector-subtree-measure a)])
      (if (fx< index a-size)
          (core-pvector-ref-node2 a index)
          (core-pvector-ref-node2 (pvector-node2-b node) (fx- index a-size))))]
   [else
    (let* ([a (pvector-node3-a node)]
           [b (pvector-node3-b node)]
           [a-size (pvector-subtree-measure a)]
           [b-size (pvector-subtree-measure b)]
           [ab-size (fx+ a-size b-size)])
      (cond
       [(fx< index a-size)
        (core-pvector-ref-node2 a index)]
       [(fx< index ab-size)
        (core-pvector-ref-node2 b (fx- index a-size))]
       [else
        (core-pvector-ref-node2 (pvector-node3-c node) (fx- index ab-size))]))]))

(define (core-pvector-ref-digit3 digit index)
  (cond
   [(pvector-digit1? digit)
    (core-pvector-ref-node3 (pvector-digit1-a digit) index)]
   [(pvector-digit2? digit)
    (let* ([a (pvector-digit2-a digit)]
           [a-size (pvector-subtree-measure a)])
      (if (fx< index a-size)
          (core-pvector-ref-node3 a index)
          (core-pvector-ref-node3 (pvector-digit2-b digit) (fx- index a-size))))]
   [(pvector-digit3? digit)
    (let* ([a (pvector-digit3-a digit)]
           [b (pvector-digit3-b digit)]
           [a-size (pvector-subtree-measure a)]
           [b-size (pvector-subtree-measure b)]
           [ab-size (fx+ a-size b-size)])
      (cond
       [(fx< index a-size)
        (core-pvector-ref-node3 a index)]
       [(fx< index ab-size)
        (core-pvector-ref-node3 b (fx- index a-size))]
       [else
        (core-pvector-ref-node3 (pvector-digit3-c digit) (fx- index ab-size))]))]
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
        (core-pvector-ref-node3 a index)]
       [(fx< index ab-size)
        (core-pvector-ref-node3 b (fx- index a-size))]
       [(fx< index abc-size)
        (core-pvector-ref-node3 c (fx- index ab-size))]
       [else
        (core-pvector-ref-node3 (pvector-digit4-d digit) (fx- index abc-size))]))]))

(define (core-pvector-ref-tree3 tree index)
  (cond
   [(pvector-single-tree? tree)
    (core-pvector-ref-node3 (pvector-single-tree-a tree) index)]
   [(pvector-deep-tree? tree)
    (let* ([left (pvector-deep-tree-left tree)]
           [inner (pvector-deep-tree-inner tree)]
           [right (pvector-deep-tree-right tree)]
           [left-size (pvector-digit-measure left)]
           [inner-size (pvector-tree-measure inner)]
           [left+inner-size (fx+ left-size inner-size)])
      (cond
       [(fx< index left-size)
        (core-pvector-ref-digit3 left index)]
       [(fx< index left+inner-size)
        (core-pvector-ref-tree inner (fx- index left-size) 4)]
       [else
        (core-pvector-ref-digit3 right (fx- index left+inner-size))]))]
   [else
    (error 'core-pvector-ref "index out of bounds")]))

(define (core-pvector-ref-tree2 tree index)
  (cond
   [(pvector-single-tree? tree)
    (core-pvector-ref-node2 (pvector-single-tree-a tree) index)]
   [(pvector-deep-tree? tree)
    (let* ([left (pvector-deep-tree-left tree)]
           [inner (pvector-deep-tree-inner tree)]
           [right (pvector-deep-tree-right tree)]
           [left-size (pvector-digit-measure left)]
           [inner-size (pvector-tree-measure inner)]
           [left+inner-size (fx+ left-size inner-size)])
      (cond
       [(fx< index left-size)
        (core-pvector-ref-digit2 left index)]
       [(fx< index left+inner-size)
        (core-pvector-ref-tree3 inner (fx- index left-size))]
       [else
        (core-pvector-ref-digit2 right (fx- index left+inner-size))]))]
   [else
    (error 'core-pvector-ref "index out of bounds")]))

(define (core-pvector-ref-tree1 tree index)
  (cond
   [(pvector-single-tree? tree)
    (core-pvector-ref-node1 (pvector-single-tree-a tree) index)]
   [(pvector-deep-tree? tree)
    (let* ([left (pvector-deep-tree-left tree)]
           [inner (pvector-deep-tree-inner tree)]
           [right (pvector-deep-tree-right tree)]
           [left-size (pvector-digit-measure left)]
           [inner-size (pvector-tree-measure inner)]
           [left+inner-size (fx+ left-size inner-size)])
      (cond
       [(fx< index left-size)
        (core-pvector-ref-digit1 left index)]
       [(fx< index left+inner-size)
        (core-pvector-ref-tree2 inner (fx- index left-size))]
       [else
        (core-pvector-ref-digit1 right (fx- index left+inner-size))]))]
   [else
    (error 'core-pvector-ref "index out of bounds")]))

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

(define (core-pvector-ref-chunks chunks index size)
  (let* ([default-size? (fx= size default-core-pvector-chunk-size)]
         [chunk-pos (if default-size?
                        (fxrshift index 6)
                        (fxquotient index size))]
         [chunk (#3%vector-ref chunks chunk-pos)])
    (pvector-chunk-ref
     chunk
     (if default-size?
         (fxand index 63)
         (fx- index (fx* chunk-pos size))))))

(define (core-pvector-ref-tree-top tree index)
  (cond
   [(pvector-single-tree? tree)
    (pvector-chunk-ref (pvector-single-tree-a tree) index)]
   [(pvector-deep-tree? tree)
    (let* ([left (pvector-deep-tree-left tree)]
           [inner (pvector-deep-tree-inner tree)]
           [right (pvector-deep-tree-right tree)]
           [left-size (pvector-digit-measure left)]
           [inner-size (pvector-tree-measure inner)]
           [left+inner-size (fx+ left-size inner-size)])
      (cond
       [(fx< index left-size)
        (core-pvector-ref-digit left index 0)]
       [(fx< index left+inner-size)
        (core-pvector-ref-tree1 inner (fx- index left-size))]
       [else
        (core-pvector-ref-digit right (fx- index left+inner-size) 0)]))]
   [else
    (error 'core-pvector-ref "index out of bounds")]))

(define (core-pvector-ref pv index)
  (let ([cache (core-pvector-chunks pv)]
        [size (core-pvector-chunk-size pv)])
    (cond
     [(#%vector? cache)
      (core-pvector-ref-chunks cache index size)]
     [(core-pvector-shifted-cache? cache)
      (let ([front-len (core-pvector-shifted-cache-front-length cache)])
        (if (fx< index front-len)
            (core-pvector-ref-tree-top (core-pvector-tree pv) index)
            (core-pvector-ref-chunks
             (core-pvector-shifted-cache-chunks cache)
             (fx+ (fx- index front-len)
                  (core-pvector-shifted-cache-source-start cache))
             size)))]
     [(core-pvector-append-ref-cache? cache)
      (let ([left-len (core-pvector-append-ref-cache-left-length cache)])
        (if (fx< index left-len)
            (core-pvector-ref (core-pvector-append-ref-cache-left cache) index)
            (core-pvector-ref (core-pvector-append-ref-cache-right cache)
                              (fx- index left-len))))]
     [else
      (core-pvector-ref-tree-top (core-pvector-tree pv) index)])))

(define (core-pvector-view-left pv)
  (let ([chunks (core-pvector-cached-chunks pv)])
    (if chunks
        (pvector-chunk-ref (#3%vector-ref chunks 0) 0)
        (pvector-chunk-ref (pvector-tree-first-node (core-pvector-tree pv)) 0))))

(define (core-pvector-view-right pv)
  (let ([chunks (core-pvector-cached-chunks pv)])
    (if chunks
        (let* ([chunk (#3%vector-ref chunks (fx- (#%vector-length chunks) 1))]
               [chunk-len (pvector-chunk-length chunk)])
          (pvector-chunk-ref chunk (fx- chunk-len 1)))
        (let ([chunk (pvector-tree-last-node (core-pvector-tree pv))])
          (pvector-chunk-ref chunk (fx- (pvector-chunk-length chunk) 1))))))

(define (pvector-chunk-lookup-node node index depth)
  (if (fx= depth 0)
      (values index node)
      (let ([sub-depth (fx- depth 1)])
        (cond
         [(pvector-node2? node)
          (let* ([a (pvector-node2-a node)]
                 [a-size (pvector-subtree-measure a)])
            (if (fx< index a-size)
                (pvector-chunk-lookup-node a index sub-depth)
                (pvector-chunk-lookup-node (pvector-node2-b node)
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
              (pvector-chunk-lookup-node a index sub-depth)]
             [(fx< index ab-size)
              (pvector-chunk-lookup-node b (fx- index a-size) sub-depth)]
             [else
              (pvector-chunk-lookup-node (pvector-node3-c node)
                                         (fx- index ab-size)
                                         sub-depth)]))]))))

(define (pvector-chunk-lookup-digit digit index depth)
  (cond
   [(pvector-digit1? digit)
    (pvector-chunk-lookup-node (pvector-digit1-a digit) index depth)]
   [(pvector-digit2? digit)
    (let* ([a (pvector-digit2-a digit)]
           [a-size (pvector-subtree-measure a)])
      (if (fx< index a-size)
          (pvector-chunk-lookup-node a index depth)
          (pvector-chunk-lookup-node (pvector-digit2-b digit)
                                     (fx- index a-size)
                                     depth)))]
   [(pvector-digit3? digit)
    (let* ([a (pvector-digit3-a digit)]
           [b (pvector-digit3-b digit)]
           [a-size (pvector-subtree-measure a)]
           [b-size (pvector-subtree-measure b)]
           [ab-size (fx+ a-size b-size)])
      (cond
       [(fx< index a-size)
        (pvector-chunk-lookup-node a index depth)]
       [(fx< index ab-size)
        (pvector-chunk-lookup-node b (fx- index a-size) depth)]
       [else
        (pvector-chunk-lookup-node (pvector-digit3-c digit) (fx- index ab-size) depth)]))]
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
        (pvector-chunk-lookup-node a index depth)]
       [(fx< index ab-size)
        (pvector-chunk-lookup-node b (fx- index a-size) depth)]
       [(fx< index abc-size)
        (pvector-chunk-lookup-node c (fx- index ab-size) depth)]
       [else
        (pvector-chunk-lookup-node (pvector-digit4-d digit)
                                   (fx- index abc-size)
                                   depth)]))]))

(define (pvector-chunk-lookup-tree tree index depth)
  (cond
   [(pvector-single-tree? tree)
    (pvector-chunk-lookup-node (pvector-single-tree-a tree) index depth)]
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
        (pvector-chunk-lookup-digit left index depth)]
       [(fx< index left+inner-size)
        (pvector-chunk-lookup-tree inner (fx- index left-size) inner-depth)]
       [else
        (pvector-chunk-lookup-digit right (fx- index left+inner-size) depth)]))]
   [else
    (error 'core-pvector-copy "index out of bounds")]))

(define (pvector-maybe-node2 node a b)
  (if (and (eq? a (pvector-node2-a node))
           (eq? b (pvector-node2-b node)))
      node
      (make-pvector-node2 (pvector-node2-measure node) a b)))

(define (pvector-maybe-node3 node a b c)
  (if (and (eq? a (pvector-node3-a node))
           (eq? b (pvector-node3-b node))
           (eq? c (pvector-node3-c node)))
      node
      (make-pvector-node3 (pvector-node3-measure node) a b c)))

(define (pvector-maybe-digit1 digit a)
  (if (eq? a (pvector-digit1-a digit))
      digit
      (make-pvector-digit1 a)))

(define (pvector-maybe-digit2 digit a b)
  (if (and (eq? a (pvector-digit2-a digit))
           (eq? b (pvector-digit2-b digit)))
      digit
      (make-pvector-digit2 a b)))

(define (pvector-maybe-digit3 digit a b c)
  (if (and (eq? a (pvector-digit3-a digit))
           (eq? b (pvector-digit3-b digit))
           (eq? c (pvector-digit3-c digit)))
      digit
      (make-pvector-digit3 a b c)))

(define (pvector-maybe-digit4 digit a b c d)
  (if (and (eq? a (pvector-digit4-a digit))
           (eq? b (pvector-digit4-b digit))
           (eq? c (pvector-digit4-c digit))
           (eq? d (pvector-digit4-d digit)))
      digit
      (make-pvector-digit4 a b c d)))

(define (pvector-maybe-single-tree tree a)
  (if (eq? a (pvector-single-tree-a tree))
      tree
      (make-pvector-single-tree a)))

(define (pvector-maybe-deep-tree tree left inner right)
  (if (and (eq? left (pvector-deep-tree-left tree))
           (eq? inner (pvector-deep-tree-inner tree))
           (eq? right (pvector-deep-tree-right tree)))
      tree
      (make-pvector-deep-tree (pvector-deep-tree-measure tree) left inner right)))

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
	                (pvector-maybe-node2 node
	                                      (core-pvector-set-node a index value sub-depth)
	                                      b)
	                (pvector-maybe-node2 node
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
	              (pvector-maybe-node3 node
	                                    (core-pvector-set-node a index value sub-depth)
	                                    b
	                                    c)]
	             [(fx< index ab-size)
	              (pvector-maybe-node3 node
	                                    a
	                                    (core-pvector-set-node b (fx- index a-size) value sub-depth)
	                                    c)]
	             [else
	              (pvector-maybe-node3 node
	                                    a
	                                    b
	                                    (core-pvector-set-node c (fx- index ab-size) value sub-depth))]))]))))

(define (core-pvector-set-node1 node index value)
  (cond
	   [(pvector-node2? node)
	    (let* ([a (pvector-node2-a node)]
	           [b (pvector-node2-b node)]
	           [a-size (pvector-chunk-length a)])
	      (if (fx< index a-size)
	          (pvector-maybe-node2 node
	                                (pvector-chunk-set a index value)
	                                b)
	          (pvector-maybe-node2 node
	                                a
	                                (pvector-chunk-set b (fx- index a-size) value))))]
   [else
    (let* ([a (pvector-node3-a node)]
           [b (pvector-node3-b node)]
           [c (pvector-node3-c node)]
           [a-size (pvector-chunk-length a)]
           [b-size (pvector-chunk-length b)]
           [ab-size (fx+ a-size b-size)])
	      (cond
	       [(fx< index a-size)
	        (pvector-maybe-node3 node
	                              (pvector-chunk-set a index value)
	                              b
	                              c)]
	       [(fx< index ab-size)
	        (pvector-maybe-node3 node
	                              a
	                              (pvector-chunk-set b (fx- index a-size) value)
	                              c)]
	       [else
	        (pvector-maybe-node3 node
	                              a
	                              b
	                              (pvector-chunk-set c (fx- index ab-size) value))]))]))

(define (core-pvector-set-node2 node index value)
  (cond
	   [(pvector-node2? node)
	    (let* ([a (pvector-node2-a node)]
	           [b (pvector-node2-b node)]
	           [a-size (pvector-subtree-measure a)])
	      (if (fx< index a-size)
	          (pvector-maybe-node2 node
	                                (core-pvector-set-node1 a index value)
	                                b)
	          (pvector-maybe-node2 node
	                                a
	                                (core-pvector-set-node1 b (fx- index a-size) value))))]
   [else
    (let* ([a (pvector-node3-a node)]
           [b (pvector-node3-b node)]
           [c (pvector-node3-c node)]
           [a-size (pvector-subtree-measure a)]
           [b-size (pvector-subtree-measure b)]
           [ab-size (fx+ a-size b-size)])
	      (cond
	       [(fx< index a-size)
	        (pvector-maybe-node3 node
	                              (core-pvector-set-node1 a index value)
	                              b
	                              c)]
	       [(fx< index ab-size)
	        (pvector-maybe-node3 node
	                              a
	                              (core-pvector-set-node1 b (fx- index a-size) value)
	                              c)]
	       [else
	        (pvector-maybe-node3 node
	                              a
	                              b
	                              (core-pvector-set-node1 c (fx- index ab-size) value))]))]))

(define (core-pvector-set-digit1 digit index value)
  (cond
	   [(pvector-digit1? digit)
	    (pvector-maybe-digit1
	     digit
	     (core-pvector-set-node1 (pvector-digit1-a digit) index value))]
   [(pvector-digit2? digit)
    (let* ([a (pvector-digit2-a digit)]
           [b (pvector-digit2-b digit)]
           [a-size (pvector-subtree-measure a)])
	      (if (fx< index a-size)
	          (pvector-maybe-digit2 digit (core-pvector-set-node1 a index value) b)
	          (pvector-maybe-digit2 digit a (core-pvector-set-node1 b (fx- index a-size) value))))]
   [(pvector-digit3? digit)
    (let* ([a (pvector-digit3-a digit)]
           [b (pvector-digit3-b digit)]
           [c (pvector-digit3-c digit)]
           [a-size (pvector-subtree-measure a)]
           [b-size (pvector-subtree-measure b)]
           [ab-size (fx+ a-size b-size)])
	      (cond
	       [(fx< index a-size)
	        (pvector-maybe-digit3 digit (core-pvector-set-node1 a index value) b c)]
	       [(fx< index ab-size)
	        (pvector-maybe-digit3 digit a (core-pvector-set-node1 b (fx- index a-size) value) c)]
	       [else
	        (pvector-maybe-digit3 digit a b (core-pvector-set-node1 c (fx- index ab-size) value))]))]
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
	        (pvector-maybe-digit4 digit (core-pvector-set-node1 a index value) b c d)]
	       [(fx< index ab-size)
	        (pvector-maybe-digit4 digit a (core-pvector-set-node1 b (fx- index a-size) value) c d)]
	       [(fx< index abc-size)
	        (pvector-maybe-digit4 digit a b (core-pvector-set-node1 c (fx- index ab-size) value) d)]
	       [else
	        (pvector-maybe-digit4 digit a b c (core-pvector-set-node1 d (fx- index abc-size) value))]))]))

(define (core-pvector-set-digit2 digit index value)
  (cond
	   [(pvector-digit1? digit)
	    (pvector-maybe-digit1
	     digit
	     (core-pvector-set-node2 (pvector-digit1-a digit) index value))]
   [(pvector-digit2? digit)
    (let* ([a (pvector-digit2-a digit)]
           [b (pvector-digit2-b digit)]
           [a-size (pvector-subtree-measure a)])
	      (if (fx< index a-size)
	          (pvector-maybe-digit2 digit (core-pvector-set-node2 a index value) b)
	          (pvector-maybe-digit2 digit a (core-pvector-set-node2 b (fx- index a-size) value))))]
   [(pvector-digit3? digit)
    (let* ([a (pvector-digit3-a digit)]
           [b (pvector-digit3-b digit)]
           [c (pvector-digit3-c digit)]
           [a-size (pvector-subtree-measure a)]
           [b-size (pvector-subtree-measure b)]
           [ab-size (fx+ a-size b-size)])
	      (cond
	       [(fx< index a-size)
	        (pvector-maybe-digit3 digit (core-pvector-set-node2 a index value) b c)]
	       [(fx< index ab-size)
	        (pvector-maybe-digit3 digit a (core-pvector-set-node2 b (fx- index a-size) value) c)]
	       [else
	        (pvector-maybe-digit3 digit a b (core-pvector-set-node2 c (fx- index ab-size) value))]))]
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
	        (pvector-maybe-digit4 digit (core-pvector-set-node2 a index value) b c d)]
	       [(fx< index ab-size)
	        (pvector-maybe-digit4 digit a (core-pvector-set-node2 b (fx- index a-size) value) c d)]
	       [(fx< index abc-size)
	        (pvector-maybe-digit4 digit a b (core-pvector-set-node2 c (fx- index ab-size) value) d)]
	       [else
	        (pvector-maybe-digit4 digit a b c (core-pvector-set-node2 d (fx- index abc-size) value))]))]))

(define (core-pvector-set-tree2 tree index value)
  (cond
	   [(pvector-single-tree? tree)
	    (pvector-maybe-single-tree
	     tree
	     (core-pvector-set-node2 (pvector-single-tree-a tree) index value))]
   [(pvector-deep-tree? tree)
    (let* ([total (pvector-deep-tree-measure tree)]
           [left (pvector-deep-tree-left tree)]
           [inner (pvector-deep-tree-inner tree)]
           [right (pvector-deep-tree-right tree)]
           [left-size (pvector-digit-measure left)]
           [inner-size (pvector-tree-measure inner)]
           [left+inner-size (fx+ left-size inner-size)])
	      (cond
	       [(fx< index left-size)
	        (pvector-maybe-deep-tree tree
	                                  (core-pvector-set-digit2 left index value)
	                                  inner
	                                  right)]
	       [(fx< index left+inner-size)
	        (pvector-maybe-deep-tree tree
	                                  left
	                                  (core-pvector-set-tree inner (fx- index left-size) value 3)
	                                  right)]
	       [else
	        (pvector-maybe-deep-tree tree
	                                  left
	                                  inner
	                                  (core-pvector-set-digit2 right (fx- index left+inner-size) value))]))]
   [else
    (error 'core-pvector-set "index out of bounds")]))

(define (core-pvector-set-tree1 tree index value)
  (cond
	   [(pvector-single-tree? tree)
	    (pvector-maybe-single-tree
	     tree
	     (core-pvector-set-node1 (pvector-single-tree-a tree) index value))]
   [(pvector-deep-tree? tree)
    (let* ([total (pvector-deep-tree-measure tree)]
           [left (pvector-deep-tree-left tree)]
           [inner (pvector-deep-tree-inner tree)]
           [right (pvector-deep-tree-right tree)]
           [left-size (pvector-digit-measure left)]
           [inner-size (pvector-tree-measure inner)]
           [left+inner-size (fx+ left-size inner-size)])
	      (cond
	       [(fx< index left-size)
	        (pvector-maybe-deep-tree tree
	                                  (core-pvector-set-digit1 left index value)
	                                  inner
	                                  right)]
	       [(fx< index left+inner-size)
	        (pvector-maybe-deep-tree tree
	                                  left
	                                  (core-pvector-set-tree2 inner (fx- index left-size) value)
	                                  right)]
	       [else
	        (pvector-maybe-deep-tree tree
	                                  left
	                                  inner
	                                  (core-pvector-set-digit1 right (fx- index left+inner-size) value))]))]
   [else
    (error 'core-pvector-set "index out of bounds")]))

(define (core-pvector-set-digit digit index value depth)
  (cond
	   [(pvector-digit1? digit)
	    (pvector-maybe-digit1
	     digit
	     (core-pvector-set-node (pvector-digit1-a digit) index value depth))]
   [(pvector-digit2? digit)
    (let* ([a (pvector-digit2-a digit)]
           [b (pvector-digit2-b digit)]
           [a-size (pvector-subtree-measure a)])
	      (if (fx< index a-size)
	          (pvector-maybe-digit2 digit (core-pvector-set-node a index value depth) b)
	          (pvector-maybe-digit2 digit a (core-pvector-set-node b (fx- index a-size) value depth))))]
   [(pvector-digit3? digit)
    (let* ([a (pvector-digit3-a digit)]
           [b (pvector-digit3-b digit)]
           [c (pvector-digit3-c digit)]
           [a-size (pvector-subtree-measure a)]
           [b-size (pvector-subtree-measure b)]
           [ab-size (fx+ a-size b-size)])
	      (cond
	       [(fx< index a-size)
	        (pvector-maybe-digit3 digit (core-pvector-set-node a index value depth) b c)]
	       [(fx< index ab-size)
	        (pvector-maybe-digit3 digit a (core-pvector-set-node b (fx- index a-size) value depth) c)]
	       [else
	        (pvector-maybe-digit3 digit a b (core-pvector-set-node c (fx- index ab-size) value depth))]))]
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
	        (pvector-maybe-digit4 digit (core-pvector-set-node a index value depth) b c d)]
	       [(fx< index ab-size)
	        (pvector-maybe-digit4 digit a (core-pvector-set-node b (fx- index a-size) value depth) c d)]
	       [(fx< index abc-size)
	        (pvector-maybe-digit4 digit a b (core-pvector-set-node c (fx- index ab-size) value depth) d)]
	       [else
	        (pvector-maybe-digit4 digit a b c (core-pvector-set-node d (fx- index abc-size) value depth))]))]))

(define (core-pvector-set-tree tree index value depth)
  (cond
	   [(pvector-single-tree? tree)
	    (pvector-maybe-single-tree
	     tree
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
	        (pvector-maybe-deep-tree tree
	                                  (core-pvector-set-digit left index value depth)
	                                  inner
	                                  right)]
	       [(fx< index left+inner-size)
	        (pvector-maybe-deep-tree tree
	                                  left
	                                  (core-pvector-set-tree inner (fx- index left-size) value inner-depth)
	                                  right)]
	       [else
	        (pvector-maybe-deep-tree tree
	                                  left
	                                  inner
	                                  (core-pvector-set-digit right (fx- index left+inner-size) value depth))]))]
   [else
    (error 'core-pvector-set "index out of bounds")]))

(define (core-pvector-set/tree pv index value)
  (let ([tree (core-pvector-tree pv)])
    (let ([tree^
           (if (pvector-single-tree? tree)
               (pvector-maybe-single-tree
                tree
                (pvector-chunk-set (pvector-single-tree-a tree)
                                   index
                                   value))
               (if (pvector-deep-tree? tree)
                   (let* ([left (pvector-deep-tree-left tree)]
                          [inner (pvector-deep-tree-inner tree)]
                          [right (pvector-deep-tree-right tree)]
                          [left-size (pvector-digit-measure left)]
                          [inner-size (pvector-tree-measure inner)]
                          [left+inner-size (fx+ left-size inner-size)])
                     (cond
                      [(fx< index left-size)
                       (pvector-maybe-deep-tree tree
                                                 (core-pvector-set-digit left index value 0)
                                                 inner
                                                 right)]
                      [(fx< index left+inner-size)
                       (pvector-maybe-deep-tree tree
                                                 left
                                                 (core-pvector-set-tree1 inner
                                                                         (fx- index left-size)
                                                                         value)
                                                 right)]
                      [else
                       (pvector-maybe-deep-tree tree
                                                 left
                                                 inner
                                                 (core-pvector-set-digit right
                                                                         (fx- index left+inner-size)
                                                                         value
                                                                         0))]))
                   (core-pvector-set-tree tree index value 0)))])
      (if (eq? tree^ tree)
          pv
          (make-core-pvector tree^
                             (core-pvector-length pv)
                             (core-pvector-chunk-size pv))))))

(define (core-pvector-set/cached pv chunks index value)
  (let* ([size (core-pvector-chunk-size pv)]
         [default-size? (fx= size default-core-pvector-chunk-size)]
         [chunk-pos (if default-size?
                        (fxrshift index 6)
                        (fxquotient index size))]
         [elem-index (if default-size?
                         (fxand index 63)
                         (fx- index (fx* chunk-pos size)))]
         [chunk (#3%vector-ref chunks chunk-pos)])
    (if (eq? (pvector-chunk-ref chunk elem-index) value)
        pv
        (let ([result (core-pvector-set/tree pv index value)])
          (if (core-pvector-chunks-plain? chunks)
              (let* ([chunk^ (core-pvector-derived-cache-chunk
                              (pvector-chunk-set chunk elem-index value))]
                     [chunks^ (#%vector-copy chunks)])
                (#3%vector-set! chunks^ chunk-pos chunk^)
                (make-core-pvector/with-chunks
                 (core-pvector-tree result)
                 (core-pvector-length result)
                 size
                 chunks^))
              result)))))

(define (core-pvector-set pv index value)
  (let ([chunks (core-pvector-cached-chunks pv)])
    (if (and chunks
             (fixnum? index)
             (fx>= index 0)
             (fx< index (core-pvector-length pv)))
        (core-pvector-set/cached pv chunks index value)
        (core-pvector-set/tree pv index value))))

(define (core-pvector-singleton-chunk value)
  (vector-immutable value))

(define (core-pvector-derived-cache-chunk chunk)
  (if (pvector-leaf-vector? chunk)
      (make-pvector-leaf-chunk chunk 0 (#%vector-length chunk))
      chunk))

(define core-pvector-derived-cache-tail core-pvector-derived-cache-chunk)

(define (core-pvector-make-shifted-cache chunks source-start front-len)
  (make-core-pvector-shifted-cache chunks source-start front-len))

(define (core-pvector-cached-cons-right-chunks chunks value size)
  (let ([count (#%vector-length chunks)])
    (and (fx<= count core-pvector-endpoint-cache-chunk-limit)
         (let* ([last-slot (fx- count 1)]
                [last-chunk (#3%vector-ref chunks last-slot)]
                [last-len (pvector-chunk-length last-chunk)])
           (and (pvector-leaf-vector? last-chunk)
                (if (fx< last-len size)
                    (let ([chunks^ (#%vector-copy chunks)])
                      (#3%vector-set!
                       chunks^
                       last-slot
                       (core-pvector-derived-cache-tail
                        (pvector-chunk-append last-chunk value)))
                      chunks^)
                    (#%vector-append
                     chunks
                     (vector (core-pvector-derived-cache-tail
                              (core-pvector-singleton-chunk value))))))))))

(define (core-pvector-cached-pop-right-chunks chunks rest-len)
  (let ([count (#%vector-length chunks)])
    (and (fx<= count core-pvector-endpoint-cache-chunk-limit)
         (let* ([last-slot (fx- count 1)]
                [last-chunk (#3%vector-ref chunks last-slot)]
                [last-len (pvector-chunk-length last-chunk)])
           (and (pvector-leaf-vector? last-chunk)
                (cond
                 [(fx= last-len 1)
                  (and (fx> rest-len 0)
                       (#%vector-copy chunks 0 (fx- count 1)))]
                 [else
                  (let ([chunks^ (#%vector-copy chunks)])
                    (#3%vector-set!
                     chunks^
                     last-slot
                     (pvector-chunk-slice last-chunk 0 (fx- last-len 1)))
                    chunks^)]))))))

(define (core-pvector-cons-left pv value)
  (let ([size (core-pvector-chunk-size pv)])
    (cond
     [(fx= 0 (core-pvector-length pv))
      (make-core-pvector
       (make-pvector-single-tree (core-pvector-singleton-chunk value))
       1
       size)]
     [else
      (let ([chunks (core-pvector-cached-chunks pv)])
        (let-values ([(fill? fill-value)
                      (if chunks
                          (core-pvector-shared-fill-value chunks)
                          (values #f #f))])
          (if (and fill? (eq? fill-value value))
              (core-make-pvector/size (fx+ (core-pvector-length pv) 1) value size)
              (let* ([tree (core-pvector-tree pv)]
                     [tree^
                      (if (pvector-single-tree? tree)
                          (let* ([chunk (pvector-single-tree-a tree)]
                                 [chunk-len (pvector-chunk-length chunk)])
                            (if (fx< chunk-len core-pvector-endpoint-pack-limit)
                                (make-pvector-single-tree (pvector-chunk-prepend chunk value))
                                (pvector-tree-cons-left tree (core-pvector-singleton-chunk value) 0)))
                          (let ([first-chunk (pvector-tree-first-node tree)])
                            (if (fx< (pvector-chunk-length first-chunk) core-pvector-endpoint-pack-limit)
                                (pvector-tree-replace-first tree (pvector-chunk-prepend first-chunk value) 0)
                                (pvector-tree-cons-left tree (core-pvector-singleton-chunk value) 0))))])
                (let ([new-len (fx+ (core-pvector-length pv) 1)])
                  (if chunks
                      (make-core-pvector/with-chunks
                       tree^
                       new-len
                       size
                       (core-pvector-make-shifted-cache chunks 0 1))
                      (make-core-pvector tree^ new-len size)))))))])))

(define (core-pvector-cons-right pv value)
  (let ([size (core-pvector-chunk-size pv)])
    (cond
     [(fx= 0 (core-pvector-length pv))
      (make-core-pvector
       (make-pvector-single-tree (core-pvector-singleton-chunk value))
       1
       size)]
     [else
      (let ([chunks (core-pvector-cached-chunks pv)])
        (let-values ([(fill? fill-value)
                      (if chunks
                          (core-pvector-shared-fill-value chunks)
                          (values #f #f))])
          (if (and fill? (eq? fill-value value))
              (core-make-pvector/size (fx+ (core-pvector-length pv) 1) value size)
              (let* ([tree (core-pvector-tree pv)]
                     [tree^
                      (if (pvector-single-tree? tree)
                          (let* ([chunk (pvector-single-tree-a tree)]
                                 [chunk-len (pvector-chunk-length chunk)])
                            (if (fx< chunk-len core-pvector-endpoint-pack-limit)
                                (make-pvector-single-tree (pvector-chunk-append chunk value))
                                (pvector-tree-cons-right tree (core-pvector-singleton-chunk value) 0)))
                          (let ([last-chunk (pvector-tree-last-node tree)])
                            (if (fx< (pvector-chunk-length last-chunk) core-pvector-endpoint-pack-limit)
                                (pvector-tree-replace-last tree (pvector-chunk-append last-chunk value) 0)
                                (pvector-tree-cons-right tree (core-pvector-singleton-chunk value) 0))))])
                (let* ([new-len (fx+ (core-pvector-length pv) 1)]
                       [chunks^ (and chunks
                                      (core-pvector-cached-cons-right-chunks
                                       chunks
                                       value
                                       size))])
                  (if chunks^
                      (make-core-pvector/with-chunks tree^ new-len size chunks^)
                      (make-core-pvector tree^ new-len size)))))))])))

(define (core-pvector-pop-left pv)
  (let* ([size (core-pvector-chunk-size pv)]
         [rest-len (fx- (core-pvector-length pv) 1)]
         [chunks (core-pvector-cached-chunks pv)])
    (let-values ([(fill? fill-value)
                  (if chunks
                      (core-pvector-shared-fill-value chunks)
                      (values #f #f))])
      (if fill?
          (values fill-value
                  (if (fx= rest-len 0)
                      (core-empty-pvector/size size)
                      (core-make-pvector/size rest-len fill-value size)))
          (let* ([tree (core-pvector-tree pv)]
                 [chunk (pvector-tree-first-node tree)]
                 [value (pvector-chunk-ref chunk 0)]
                 [chunk-len (pvector-chunk-length chunk)]
                 [rest-tree
                  (cond
                   [(fx= chunk-len 1)
                    (if (pvector-single-tree? tree)
                        empty-core-pvector-tree
                        (let-values ([(popped rest) (pvector-tree-pop-left tree 0)])
                          rest))]
                   [(pvector-single-tree? tree)
                    (make-pvector-single-tree (pvector-chunk-slice chunk 1 chunk-len))]
                   [else
                    (pvector-tree-replace-first tree
                                                (pvector-chunk-slice chunk 1 chunk-len)
                                                0)])])
            (values value
                    (if (fx= rest-len 0)
                        (core-empty-pvector/size size)
                        (if chunks
                            (make-core-pvector/with-chunks
                             rest-tree
                             rest-len
                             size
                             (core-pvector-make-shifted-cache chunks 1 0))
                            (make-core-pvector rest-tree rest-len size)))))))))

(define (core-pvector-pop-right pv)
  (let* ([size (core-pvector-chunk-size pv)]
         [rest-len (fx- (core-pvector-length pv) 1)]
         [chunks (core-pvector-cached-chunks pv)])
    (let-values ([(fill? fill-value)
                  (if chunks
                      (core-pvector-shared-fill-value chunks)
                      (values #f #f))])
      (if fill?
          (values fill-value
                  (if (fx= rest-len 0)
                      (core-empty-pvector/size size)
                      (core-make-pvector/size rest-len fill-value size)))
          (let* ([tree (core-pvector-tree pv)]
                 [chunk (pvector-tree-last-node tree)]
                 [chunk-len (pvector-chunk-length chunk)]
                 [value (pvector-chunk-ref chunk (fx- chunk-len 1))]
                 [rest-tree
                  (cond
                   [(fx= chunk-len 1)
                    (if (pvector-single-tree? tree)
                        empty-core-pvector-tree
                        (let-values ([(popped rest) (pvector-tree-pop-right tree 0)])
                          rest))]
                   [(pvector-single-tree? tree)
                    (make-pvector-single-tree (pvector-chunk-slice chunk 0 (fx- chunk-len 1)))]
                   [else
                    (pvector-tree-replace-last tree
                                               (pvector-chunk-slice chunk 0 (fx- chunk-len 1))
                                               0)])])
            (values value
                    (if (fx= rest-len 0)
                        (core-empty-pvector/size size)
                        (let ([chunks^ (and chunks
                                            (core-pvector-cached-pop-right-chunks
                                             chunks
                                             rest-len))])
                          (if chunks^
                              (make-core-pvector/with-chunks rest-tree rest-len size chunks^)
                              (make-core-pvector rest-tree rest-len size))))))))))

(define (core-pvector-append/concat-tree left right total-len size)
  (let* ([left-tree (core-pvector-tree left)]
         [right-tree (core-pvector-tree right)]
         [left-last (pvector-tree-last-node left-tree)]
         [right-first (pvector-tree-first-node right-tree)]
         [tree
          (cond
           [(and (fx<= total-len size)
                 (pvector-single-tree? left-tree)
                 (pvector-single-tree? right-tree))
            (make-pvector-single-tree
             (pvector-chunk-append-chunk (pvector-single-tree-a left-tree)
                                         (pvector-single-tree-a right-tree)))]
           [(and (pvector-single-tree? right-tree)
                 (fx<= (fx+ (pvector-chunk-length left-last)
                            (pvector-chunk-length (pvector-single-tree-a right-tree)))
                       size))
            (pvector-tree-replace-last
             left-tree
             (pvector-chunk-append-chunk left-last
                                         (pvector-single-tree-a right-tree))
             0)]
           [(and (pvector-single-tree? left-tree)
                 (fx<= (fx+ (pvector-chunk-length (pvector-single-tree-a left-tree))
                            (pvector-chunk-length right-first))
                       size))
            (pvector-tree-replace-first
             right-tree
             (pvector-chunk-append-chunk (pvector-single-tree-a left-tree)
                                         right-first)
             0)]
           [(and (or (pvector-single-tree? left-tree)
                     (pvector-single-tree? right-tree))
                 (fx<= (fx+ (pvector-chunk-length left-last)
                            (pvector-chunk-length right-first))
                       size))
            (let-values ([(popped-left left-rest) (pvector-tree-pop-right left-tree 0)])
              (let-values ([(popped-right right-rest) (pvector-tree-pop-left right-tree 0)])
                (pvector-tree-concat
                 (pvector-tree-cons-right left-rest
                                          (pvector-chunk-append-chunk popped-left popped-right)
                                          0)
                 right-rest
                 0)))]
           [else
            (pvector-tree-concat left-tree right-tree 0)])])
    tree))

(define (core-pvector-append/concat left right total-len size)
  (make-core-pvector
   (core-pvector-append/concat-tree left right total-len size)
   total-len
   size))

(define (core-pvector-boundary-aligned? len size)
  (fx= len (fx* (fxquotient len size) size)))

(define (core-pvector-append-chunks left-chunks right-chunks)
  (#%vector-append left-chunks right-chunks))

(define (core-pvector-append/cache-preserving left
                                              right
                                              left-len
                                              total-len
                                              size
                                              left-chunks
                                              right-chunks)
  (let* ([left-count (#%vector-length left-chunks)]
         [right-count (#%vector-length right-chunks)]
         [total-count (fx+ left-count right-count)])
    (and (fx= size (core-pvector-chunk-size right))
         (fx<= total-count core-pvector-append-cache-chunk-limit)
         (core-pvector-boundary-aligned? left-len size)
         (let ([chunks (core-pvector-append-chunks left-chunks right-chunks)])
           (make-core-pvector/with-chunks
            (core-pvector-append/concat-tree left right total-len size)
            total-len
            size
            chunks)))))

(define (core-pvector-append/ref-cache-preserving left
                                                  right
                                                  left-len
                                                  total-len
                                                  size)
  (let ([left-cache (core-pvector-ref-cache left)]
        [right-cache (core-pvector-ref-cache right)])
    (and left-cache
         right-cache
         (fx= size (core-pvector-chunk-size right))
         (fx<= (fx+ (core-pvector-ref-cache-slot-count left-cache)
                    (core-pvector-ref-cache-slot-count right-cache))
               core-pvector-append-cache-chunk-limit)
         (make-core-pvector/with-chunks
          (core-pvector-append/concat-tree left right total-len size)
          total-len
          size
          (make-core-pvector-append-ref-cache left right left-len)))))

(define (core-pvector-append left right)
  (cond
   [(fx= 0 (core-pvector-length left)) right]
   [(fx= 0 (core-pvector-length right)) left]
   [else
    (let* ([left-len (core-pvector-length left)]
           [right-len (core-pvector-length right)]
           [total-len (fx+ left-len right-len)]
           [size (core-pvector-chunk-size left)]
           [left-chunks (core-pvector-cached-chunks left)]
           [right-chunks (core-pvector-cached-chunks right)])
      (let-values ([(left-fill? left-value)
                    (if left-chunks
                        (core-pvector-shared-fill-value left-chunks)
                        (values #f #f))])
	      (if left-fill?
	          (let-values ([(right-fill? right-value)
	                        (if right-chunks
	                            (core-pvector-shared-fill-value right-chunks)
	                            (values #f #f))])
	            (if (and right-fill? (eq? left-value right-value))
	                (core-make-pvector/size total-len left-value size)
	                (core-pvector-append/concat left right total-len size)))
	          (or (and left-chunks
	                   right-chunks
	                   (core-pvector-append/cache-preserving left
	                                                         right
	                                                         left-len
	                                                         total-len
	                                                         size
	                                                         left-chunks
	                                                         right-chunks))
	              (core-pvector-append/ref-cache-preserving left
	                                                        right
	                                                        left-len
	                                                        total-len
	                                                        size)
	              (core-pvector-append/concat left right total-len size)))))]))

(define (core-pvector-split-at pv pos)
  (let ([len (core-pvector-length pv)]
        [size (core-pvector-chunk-size pv)])
    (cond
     [(fx= pos 0)
      (values (core-empty-pvector/size size) pv)]
     [(fx= pos len)
      (values pv (core-empty-pvector/size size))]
     [else
      (let ([chunks (core-pvector-cached-chunks pv)])
        (let-values ([(fill? value)
                      (if chunks
                          (core-pvector-shared-fill-value chunks)
                          (values #f #f))])
          (if fill?
              (values (core-make-pvector/size pos value size)
                      (core-make-pvector/size (fx- len pos) value size))
              (let ([tree (core-pvector-tree pv)])
                (if (pvector-single-tree? tree)
                    (let* ([chunk (pvector-single-tree-a tree)]
                           [prefix (pvector-chunk-slice chunk 0 pos)]
                           [suffix (pvector-chunk-slice chunk pos (pvector-chunk-length chunk))])
                      (values (make-core-pvector/cached-slice
                               (make-pvector-single-tree prefix)
                               pos
                               size
                               chunks
                               0)
                              (make-core-pvector/cached-slice
                               (make-pvector-single-tree suffix)
                               (fx- len pos)
                               size
                               chunks
                               pos)))
                    (let* ([first-chunk (pvector-tree-first-node tree)]
                           [first-len (pvector-chunk-length first-chunk)])
                      (cond
                       [(fx<= pos first-len)
                        (let* ([left-tree
                                (make-pvector-single-tree (pvector-chunk-slice first-chunk 0 pos))]
                               [right-tree
                                (if (fx= pos first-len)
                                    (let-values ([(popped rest) (pvector-tree-pop-left tree 0)])
                                      rest)
                                    (pvector-tree-replace-first
                                     tree
                                     (pvector-chunk-slice first-chunk pos first-len)
                                     0))])
                          (values (make-core-pvector/cached-slice
                                   left-tree
                                   pos
                                   size
                                   chunks
                                   0)
                                  (make-core-pvector/cached-slice
                                   right-tree
                                   (fx- len pos)
                                   size
                                   chunks
                                   pos)))]
                       [else
                        (let* ([suffix-len (fx- len pos)]
                               [last-chunk (pvector-tree-last-node tree)]
                               [last-len (pvector-chunk-length last-chunk)])
                          (cond
                           [(fx<= suffix-len last-len)
                            (let* ([keep-len (fx- last-len suffix-len)]
                                   [left-tree
                                    (if (fx= keep-len 0)
                                        (let-values ([(popped rest) (pvector-tree-pop-right tree 0)])
                                          rest)
                                        (pvector-tree-replace-last
                                         tree
                                         (pvector-chunk-slice last-chunk 0 keep-len)
                                         0))]
                                   [right-tree
                                    (make-pvector-single-tree
                                     (pvector-chunk-slice last-chunk keep-len last-len))])
                              (values (make-core-pvector/cached-slice
                                       left-tree
                                       pos
                                       size
                                       chunks
                                       0)
                                      (make-core-pvector/cached-slice
                                       right-tree
                                       suffix-len
                                       size
                                       chunks
                                       pos)))]
                           [else
                            (let-values ([(chunk-index left chunk right)
                                          (pvector-split-tree tree pos 0)])
                              (let* ([prefix (pvector-chunk-slice chunk 0 chunk-index)]
                                     [suffix (pvector-chunk-slice chunk
                                                                  chunk-index
                                                                  (pvector-chunk-length chunk))]
                                     [left^ (if prefix
                                                (pvector-tree-cons-right left prefix 0)
                                                left)]
                                     [right^ (if suffix
                                                 (pvector-tree-cons-left right suffix 0)
                                                 right)])
                                (values (make-core-pvector/cached-slice
                                         left^
                                         pos
                                         size
                                         chunks
                                         0)
                                        (make-core-pvector/cached-slice
                                         right^
                                         (fx- len pos)
                                         size
                                         chunks
                                         pos))))]))])))))))])))

(define (core-pvector-split-at-right pv pos)
  (let ([split-pos (fx- (core-pvector-length pv) pos)])
    (let-values ([(left right) (core-pvector-split-at pv split-pos)])
      (values right left))))

(define (core-pvector-split pv index)
  (let ([len (core-pvector-length pv)]
        [size (core-pvector-chunk-size pv)])
    (let* ([right-len (fx- (fx- len index) 1)]
           [chunks (core-pvector-cached-chunks pv)]
           [split-chunks (and chunks
                              (not (core-pvector-repeated-first-chunk? chunks))
                              chunks)])
      (let ([tree (core-pvector-tree pv)])
        (if (pvector-single-tree? tree)
            (let* ([chunk (pvector-single-tree-a tree)]
                   [value (pvector-chunk-ref chunk index)]
                   [prefix (pvector-chunk-slice chunk 0 index)]
                   [suffix (pvector-chunk-slice chunk
                                                (fx+ index 1)
                                                (pvector-chunk-length chunk))]
                   [left^ (if prefix
                              (make-pvector-single-tree prefix)
                              empty-core-pvector-tree)]
                   [right^ (if suffix
                               (make-pvector-single-tree suffix)
                               empty-core-pvector-tree)])
              (values (make-core-pvector/cached-split-slice
                       left^
                       index
                       size
                       split-chunks
                       0)
                      value
                      (make-core-pvector/cached-split-slice
                       right^
                       right-len
                       size
                       split-chunks
                       (fx+ index 1))))
            (let* ([first-chunk (pvector-tree-first-node tree)]
                   [first-len (pvector-chunk-length first-chunk)])
              (cond
               [(fx< index first-len)
                (let* ([value (pvector-chunk-ref first-chunk index)]
                       [prefix (pvector-chunk-slice first-chunk 0 index)]
                       [suffix (pvector-chunk-slice first-chunk
                                                    (fx+ index 1)
                                                    first-len)]
                       [left-tree (if prefix
                                      (make-pvector-single-tree prefix)
                                      empty-core-pvector-tree)]
                       [right-tree (if suffix
                                       (pvector-tree-replace-first tree suffix 0)
                                       (let-values ([(popped rest)
                                                     (pvector-tree-pop-left tree 0)])
                                         rest))])
                  (values (make-core-pvector/cached-split-slice
                           left-tree
                           index
                           size
                           split-chunks
                           0)
                          value
                          (make-core-pvector/cached-split-slice
                           right-tree
                           right-len
                           size
                           split-chunks
                           (fx+ index 1))))]
               [else
                (let* ([last-chunk (pvector-tree-last-node tree)]
                       [last-len (pvector-chunk-length last-chunk)]
                       [last-start (fx- len last-len)])
                  (if (fx>= index last-start)
                      (let* ([chunk-index (fx- index last-start)]
                             [value (pvector-chunk-ref last-chunk chunk-index)]
                             [prefix (pvector-chunk-slice last-chunk 0 chunk-index)]
                             [suffix (pvector-chunk-slice last-chunk
                                                          (fx+ chunk-index 1)
                                                          last-len)]
                             [left-tree (if prefix
                                            (pvector-tree-replace-last tree prefix 0)
                                            (let-values ([(popped rest)
                                                          (pvector-tree-pop-right tree 0)])
                                              rest))]
                             [right-tree (if suffix
                                             (make-pvector-single-tree suffix)
                                             empty-core-pvector-tree)])
                        (values (make-core-pvector/cached-split-slice
                                 left-tree
                                 index
                                 size
                                 split-chunks
                                 0)
                                value
                                (make-core-pvector/cached-split-slice
                                 right-tree
                                 right-len
                                 size
                                 split-chunks
                                 (fx+ index 1))))
                      (let-values ([(chunk-index left chunk right)
                                    (pvector-split-tree tree index 0)])
                        (let* ([value (pvector-chunk-ref chunk chunk-index)]
                               [prefix (pvector-chunk-slice chunk 0 chunk-index)]
                               [suffix (pvector-chunk-slice
                                        chunk
                                        (fx+ chunk-index 1)
                                        (pvector-chunk-length chunk))]
                               [left^ (if prefix
                                          (pvector-tree-cons-right left prefix 0)
                                          left)]
                               [right^ (if suffix
                                           (pvector-tree-cons-left right suffix 0)
                                           right)])
                          (values (make-core-pvector/cached-split-slice
                                   left^
                                   index
                                   size
                                   split-chunks
                                   0)
                                  value
                                  (make-core-pvector/cached-split-slice
                                   right^
                                   right-len
                                   size
                                   split-chunks
                                   (fx+ index 1)))))))])))))))

(define (core-pvector-insert-tree tree index value size)
  (let-values ([(tree^ ok?)
                (pvector-insert-tree/direct tree index value 0 size)])
    (if ok?
        tree^
        (pvector-insert-tree/splice tree index value 0 size))))

(define (core-pvector-insert pv index value)
  (let ([len (core-pvector-length pv)]
        [size (core-pvector-chunk-size pv)])
    (cond
     [(fx= index 0) (core-pvector-cons-left pv value)]
     [(fx= index len) (core-pvector-cons-right pv value)]
     [else
      (let ([chunks (core-pvector-cached-chunks pv)])
        (let-values ([(fill? fill-value)
                      (if chunks
                          (core-pvector-shared-fill-value chunks)
                          (values #f #f))])
          (if (and fill? (eq? value fill-value))
              (core-make-pvector/size (fx+ len 1) fill-value size)
              (let ([tree (core-pvector-tree pv)])
                (make-core-pvector
                 (if (pvector-single-tree? tree)
                     (let* ([chunk (pvector-single-tree-a tree)]
                            [chunk-len (pvector-chunk-length chunk)])
                       (if (fx< chunk-len size)
                           (make-pvector-single-tree (pvector-chunk-insert chunk index value))
                           (core-pvector-insert-tree tree index value size)))
                     (let* ([first-chunk (pvector-tree-first-node tree)]
                            [first-len (pvector-chunk-length first-chunk)])
                       (cond
                        [(and (fx<= index first-len)
                              (fx< first-len size))
                         (pvector-tree-replace-first
                          tree
                          (pvector-chunk-insert first-chunk index value)
                          0)]
                        [else
                         (let* ([last-chunk (pvector-tree-last-node tree)]
                                [last-len (pvector-chunk-length last-chunk)]
                                [last-start (fx- len last-len)])
                           (if (and (fx>= index last-start)
                                    (fx< last-len size))
                               (pvector-tree-replace-last
                                tree
                                (pvector-chunk-insert last-chunk
                                                      (fx- index last-start)
                                                      value)
                                0)
                               (core-pvector-insert-tree tree index value size)))])))
                 (fx+ len 1)
                 size)))))])))

(define (pvector-delete-node/direct node index depth)
  (if (fx= depth 0)
      (let* ([len (pvector-chunk-length node)]
             [value (pvector-chunk-ref node index)])
        (if (fx= len 1)
            (values #f value #f)
            (values (pvector-chunk-delete node index) value #t)))
      (let ([sub-depth (fx- depth 1)])
        (cond
         [(pvector-node2? node)
          (let* ([a (pvector-node2-a node)]
                 [b (pvector-node2-b node)]
                 [a-size (pvector-subtree-measure a)])
            (if (fx< index a-size)
                (let-values ([(a^ value ok?)
                              (pvector-delete-node/direct a index sub-depth)])
                  (if ok?
                      (values (make-pvector-node2 (fx- (pvector-node2-measure node) 1)
                                                  a^
                                                  b)
                              value
                              #t)
                      (if (and (fx= sub-depth 0)
                               (fx> (pvector-chunk-length b) 1))
                          (let-values ([(b0 b1) (pvector-chunk-split2 b)])
                            (values (pvector-make-node2 b0 b1) value #t))
                          (values #f value #f))))
                (let-values ([(b^ value ok?)
                              (pvector-delete-node/direct b
                                                          (fx- index a-size)
                                                          sub-depth)])
                  (if ok?
                      (values (make-pvector-node2 (fx- (pvector-node2-measure node) 1)
                                                  a
                                                  b^)
                              value
                              #t)
                      (if (and (fx= sub-depth 0)
                               (fx> (pvector-chunk-length a) 1))
                          (let-values ([(a0 a1) (pvector-chunk-split2 a)])
                            (values (pvector-make-node2 a0 a1) value #t))
                          (values #f value #f))))))]
         [else
          (let* ([a (pvector-node3-a node)]
                 [b (pvector-node3-b node)]
                 [c (pvector-node3-c node)]
                 [a-size (pvector-subtree-measure a)]
                 [b-size (pvector-subtree-measure b)]
                 [ab-size (fx+ a-size b-size)])
            (cond
             [(fx< index a-size)
              (let-values ([(a^ value ok?)
                            (pvector-delete-node/direct a index sub-depth)])
                (if ok?
                    (values (make-pvector-node3 (fx- (pvector-node3-measure node) 1)
                                                a^
                                                b
                                                c)
                            value
                            #t)
                    (if (fx= sub-depth 0)
                        (values (pvector-make-node2 b c) value #t)
                        (values #f value #f))))]
             [(fx< index ab-size)
              (let-values ([(b^ value ok?)
                            (pvector-delete-node/direct b
                                                        (fx- index a-size)
                                                        sub-depth)])
                (if ok?
                    (values (make-pvector-node3 (fx- (pvector-node3-measure node) 1)
                                                a
                                                b^
                                                c)
                            value
                            #t)
                    (if (fx= sub-depth 0)
                        (values (pvector-make-node2 a c) value #t)
                        (values #f value #f))))]
             [else
              (let-values ([(c^ value ok?)
                            (pvector-delete-node/direct c
                                                        (fx- index ab-size)
                                                        sub-depth)])
                (if ok?
                    (values (make-pvector-node3 (fx- (pvector-node3-measure node) 1)
                                                a
                                                b
                                                c^)
                            value
                            #t)
                    (if (fx= sub-depth 0)
                        (values (pvector-make-node2 a b) value #t)
                        (values #f value #f))))]))]))))

(define (pvector-delete-digit/direct digit index depth)
  (cond
   [(pvector-digit1? digit)
    (let-values ([(a^ value ok?)
                  (pvector-delete-node/direct (pvector-digit1-a digit) index depth)])
      (if ok?
          (values (make-pvector-digit1 a^) value #t)
          (values #f value #f)))]
   [(pvector-digit2? digit)
    (let* ([a (pvector-digit2-a digit)]
           [b (pvector-digit2-b digit)]
           [a-size (pvector-subtree-measure a)])
      (if (fx< index a-size)
          (let-values ([(a^ value ok?)
                        (pvector-delete-node/direct a index depth)])
            (if ok?
                (values (make-pvector-digit2 a^ b) value #t)
                (if (fx= depth 0)
                    (values (make-pvector-digit1 b) value #t)
                    (values #f value #f))))
          (let-values ([(b^ value ok?)
                        (pvector-delete-node/direct b (fx- index a-size) depth)])
            (if ok?
                (values (make-pvector-digit2 a b^) value #t)
                (if (fx= depth 0)
                    (values (make-pvector-digit1 a) value #t)
                    (values #f value #f))))))]
   [(pvector-digit3? digit)
    (let* ([a (pvector-digit3-a digit)]
           [b (pvector-digit3-b digit)]
           [c (pvector-digit3-c digit)]
           [a-size (pvector-subtree-measure a)]
           [b-size (pvector-subtree-measure b)]
           [ab-size (fx+ a-size b-size)])
      (cond
       [(fx< index a-size)
        (let-values ([(a^ value ok?)
                      (pvector-delete-node/direct a index depth)])
          (if ok?
              (values (make-pvector-digit3 a^ b c) value #t)
              (if (fx= depth 0)
                  (values (make-pvector-digit2 b c) value #t)
                  (values #f value #f))))]
       [(fx< index ab-size)
        (let-values ([(b^ value ok?)
                      (pvector-delete-node/direct b (fx- index a-size) depth)])
          (if ok?
              (values (make-pvector-digit3 a b^ c) value #t)
              (if (fx= depth 0)
                  (values (make-pvector-digit2 a c) value #t)
                  (values #f value #f))))]
       [else
        (let-values ([(c^ value ok?)
                      (pvector-delete-node/direct c (fx- index ab-size) depth)])
          (if ok?
              (values (make-pvector-digit3 a b c^) value #t)
              (if (fx= depth 0)
                  (values (make-pvector-digit2 a b) value #t)
                  (values #f value #f))))]))]
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
        (let-values ([(a^ value ok?)
                      (pvector-delete-node/direct a index depth)])
          (if ok?
              (values (make-pvector-digit4 a^ b c d) value #t)
              (if (fx= depth 0)
                  (values (make-pvector-digit3 b c d) value #t)
                  (values #f value #f))))]
       [(fx< index ab-size)
        (let-values ([(b^ value ok?)
                      (pvector-delete-node/direct b (fx- index a-size) depth)])
          (if ok?
              (values (make-pvector-digit4 a b^ c d) value #t)
              (if (fx= depth 0)
                  (values (make-pvector-digit3 a c d) value #t)
                  (values #f value #f))))]
       [(fx< index abc-size)
        (let-values ([(c^ value ok?)
                      (pvector-delete-node/direct c (fx- index ab-size) depth)])
          (if ok?
              (values (make-pvector-digit4 a b c^ d) value #t)
              (if (fx= depth 0)
                  (values (make-pvector-digit3 a b d) value #t)
                  (values #f value #f))))]
       [else
        (let-values ([(d^ value ok?)
                      (pvector-delete-node/direct d (fx- index abc-size) depth)])
          (if ok?
              (values (make-pvector-digit4 a b c d^) value #t)
              (if (fx= depth 0)
                  (values (make-pvector-digit3 a b c) value #t)
                  (values #f value #f))))]))]))

(define (pvector-delete-tree/direct tree index depth)
  (cond
   [(pvector-single-tree? tree)
    (let-values ([(node^ value ok?)
                  (pvector-delete-node/direct (pvector-single-tree-a tree) index depth)])
      (if ok?
          (values (make-pvector-single-tree node^) value #t)
          (values #f value #f)))]
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
        (let-values ([(left^ value ok?)
                      (pvector-delete-digit/direct left index depth)])
          (if ok?
              (values (make-pvector-deep-tree (fx- total 1) left^ inner right)
                      value
                      #t)
              (values #f value #f)))]
       [(fx< index left+inner-size)
        (let-values ([(inner^ value ok?)
                      (pvector-delete-tree/direct inner
                                                  (fx- index left-size)
                                                  inner-depth)])
          (if ok?
              (values (make-pvector-deep-tree (fx- total 1) left inner^ right)
                      value
                      #t)
              (values #f value #f)))]
       [else
        (let-values ([(right^ value ok?)
                      (pvector-delete-digit/direct right
                                                   (fx- index left+inner-size)
                                                   depth)])
          (if ok?
              (values (make-pvector-deep-tree (fx- total 1) left inner right^)
                      value
                      #t)
              (values #f value #f)))]))]
   [else
    (error 'core-pvector-delete "index out of bounds")]))

(define (core-pvector-delete pv index)
  (let ([len (core-pvector-length pv)]
        [size (core-pvector-chunk-size pv)])
    (cond
     [(fx= index 0)
      (let-values ([(value rest) (core-pvector-pop-left pv)])
        (values rest value))]
     [(fx= index (fx- len 1))
      (let-values ([(value rest) (core-pvector-pop-right pv)])
        (values rest value))]
     [else
      (let ([chunks (core-pvector-cached-chunks pv)])
        (let-values ([(fill? fill-value)
                      (if chunks
                          (core-pvector-shared-fill-value chunks)
                          (values #f #f))])
          (if fill?
              (values (core-make-pvector/size (fx- len 1) fill-value size)
                      fill-value)
              (let ([tree (core-pvector-tree pv)])
                (if (pvector-single-tree? tree)
                    (let* ([chunk (pvector-single-tree-a tree)]
                           [value (pvector-chunk-ref chunk index)])
                      (values (make-core-pvector
                               (make-pvector-single-tree (pvector-chunk-delete chunk index))
                               (fx- len 1)
                               size)
                              value))
                    (let-values ([(tree^ value ok?)
                                  (pvector-delete-tree/direct tree index 0)])
                      (if ok?
                          (values (make-core-pvector tree^ (fx- len 1) size)
                                  value)
                          (let-values ([(chunk-index left chunk right)
                                        (pvector-split-tree tree index 0)])
                            (let* ([value (pvector-chunk-ref chunk chunk-index)]
                                   [chunk-len (pvector-chunk-length chunk)]
                                   [tree^
                                    (if (fx= chunk-len 1)
                                        (pvector-tree-concat left right 0)
                                        (pvector-tree-concat
                                         (pvector-tree-cons-right left
                                                                  (pvector-chunk-delete chunk chunk-index)
                                                                  0)
                                         right
                                         0))])
                              (values (make-core-pvector tree^ (fx- len 1) size)
                                      value))))))))))])))

(define (core-pvector-index->chunk-position index size)
  (if (fx= size default-core-pvector-chunk-size)
      (fxrshift index 6)
      (fxquotient index size)))

(define (core-pvector-index->chunk-offset index chunk-pos size)
  (if (fx= size default-core-pvector-chunk-size)
      (fxand index 63)
      (fx- index (fx* chunk-pos size))))

(define (core-pvector-cached-slice-chunks/limit chunks start len size limit)
  (let* ([end (fx+ start len)]
         [last-index (fx- end 1)]
         [first-chunk-pos (core-pvector-index->chunk-position start size)]
         [last-chunk-pos (core-pvector-index->chunk-position last-index size)]
         [start-index (core-pvector-index->chunk-offset start first-chunk-pos size)]
         [end-index (fx+ (core-pvector-index->chunk-offset last-index last-chunk-pos size) 1)]
         [span (fx+ (fx- last-chunk-pos first-chunk-pos) 1)])
    (and (fx<= span limit)
         (or (fx= start-index 0)
             (fx= first-chunk-pos last-chunk-pos))
         (let ([chunks^ (#%vector-copy chunks first-chunk-pos span)])
           (if (fx= first-chunk-pos last-chunk-pos)
               (#3%vector-set!
                chunks^
                0
                (pvector-chunk-slice (#3%vector-ref chunks^ 0)
                                     start-index
                                     end-index))
               (let* ([last-slot (fx- span 1)]
                      [last-chunk (#3%vector-ref chunks^ last-slot)])
                 (unless (fx= end-index (pvector-chunk-length last-chunk))
                   (#3%vector-set!
                    chunks^
                    last-slot
                 (pvector-chunk-slice last-chunk 0 end-index)))))
           chunks^))))

(define (core-pvector-cached-slice-chunks chunks start len size)
  (core-pvector-cached-slice-chunks/limit
   chunks
   start
   len
   size
   core-pvector-slice-cache-chunk-limit))

(define (core-pvector-cached-shifted-slice chunks start len size)
  (let* ([end (fx+ start len)]
         [last-index (fx- end 1)]
         [first-chunk-pos (core-pvector-index->chunk-position start size)]
         [last-chunk-pos (core-pvector-index->chunk-position last-index size)]
         [start-index (core-pvector-index->chunk-offset start first-chunk-pos size)]
         [span (fx+ (fx- last-chunk-pos first-chunk-pos) 1)])
    (and (fx<= span core-pvector-shifted-cache-chunk-limit)
         (core-pvector-make-shifted-cache
          (#%vector-copy chunks first-chunk-pos span)
          start-index
          0))))

(define (make-core-pvector/cached-slice tree len size chunks start)
  (let ([chunks^
         (and chunks
              (core-pvector-cached-slice-chunks chunks start len size))])
    (cond
     [chunks^
      (make-core-pvector/with-chunks tree len size chunks^)]
     [(and chunks
           (core-pvector-cached-shifted-slice chunks start len size))
      =>
      (lambda (cache)
        (make-core-pvector/with-chunks tree len size cache))]
     [else
      (make-core-pvector tree len size)])))

(define (make-core-pvector/cached-split-slice tree len size chunks start)
  (if (fx= len 0)
      (core-empty-pvector/size size)
      (make-core-pvector/cached-slice tree len size chunks start)))

(define (core-pvector-repeated-first-chunk? chunks)
  (let ([count (#%vector-length chunks)])
    (and (fx> count 1)
         (eq? (#3%vector-ref chunks 0)
              (#3%vector-ref chunks 1)))))

(define (core-pvector-preserve-copy-cache result chunks start len size)
  (let ([chunks^
         (core-pvector-cached-slice-chunks/limit
          chunks
          start
          len
          size
          core-pvector-copy-cache-chunk-limit)])
    (if chunks^
        (make-core-pvector/with-chunks (core-pvector-tree result) len size chunks^)
        result)))

(define (core-pvector-copy/preserve-edge-cache pv result start len size)
  (let ([chunks (core-pvector-cached-chunks pv)])
    (if (and chunks
             (fx> len core-pvector-large-copy-composition-threshold))
        (let-values ([(fill? value) (core-pvector-shared-fill-value chunks)])
          (if fill?
              result
              (core-pvector-preserve-copy-cache result chunks start len size)))
        result)))

(define (core-pvector-take-tree pv pos len size)
  (let* ([tree (core-pvector-tree pv)]
         [first-chunk (pvector-tree-first-node tree)]
         [first-len (pvector-chunk-length first-chunk)])
    (cond
     [(fx<= pos first-len)
      (make-pvector-single-tree (pvector-chunk-slice first-chunk 0 pos))]
     [else
      (let* ([suffix-len (fx- len pos)]
             [last-chunk (pvector-tree-last-node tree)]
             [last-len (pvector-chunk-length last-chunk)])
        (cond
         [(fx<= suffix-len last-len)
          (let ([keep-len (fx- last-len suffix-len)])
            (if (fx= keep-len 0)
                (let-values ([(popped rest) (pvector-tree-pop-right tree 0)])
                  rest)
                (pvector-tree-replace-last
                 tree
                 (pvector-chunk-slice last-chunk 0 keep-len)
                 0)))]
         [else
          (let-values ([(chunk-index left chunk)
                        (pvector-split-tree-left tree pos 0)])
            (let ([prefix (pvector-chunk-slice chunk 0 chunk-index)])
              (if prefix
                  (pvector-tree-cons-right left prefix 0)
                  left)))]))])))

(define (core-pvector-drop-tree pv pos len size)
  (let* ([tree (core-pvector-tree pv)]
         [new-len (fx- len pos)]
         [first-chunk (pvector-tree-first-node tree)]
         [first-len (pvector-chunk-length first-chunk)])
    (cond
     [(fx<= pos first-len)
      (if (fx= pos first-len)
          (let-values ([(popped rest) (pvector-tree-pop-left tree 0)])
            rest)
          (pvector-tree-replace-first
           tree
           (pvector-chunk-slice first-chunk pos first-len)
           0))]
     [else
      (let* ([suffix-len new-len]
             [last-chunk (pvector-tree-last-node tree)]
             [last-len (pvector-chunk-length last-chunk)])
        (cond
         [(fx<= suffix-len last-len)
          (make-pvector-single-tree
           (pvector-chunk-slice last-chunk (fx- last-len suffix-len) last-len))]
         [else
          (let-values ([(chunk-index chunk right)
                        (pvector-split-tree-right tree pos 0)])
            (let ([suffix (pvector-chunk-slice chunk
                                               chunk-index
                                               (pvector-chunk-length chunk))])
              (if suffix
                  (pvector-tree-cons-left right suffix 0)
                  right)))]))])))

(define (core-pvector-take-right-tree pv pos len size)
  (let* ([tree (core-pvector-tree pv)]
         [last-chunk (pvector-tree-last-node tree)]
         [last-len (pvector-chunk-length last-chunk)])
    (if (fx<= pos last-len)
        (make-pvector-single-tree
         (pvector-chunk-slice last-chunk (fx- last-len pos) last-len))
        (let ([split-pos (fx- len pos)])
          (let-values ([(chunk-index chunk right)
                        (pvector-split-tree-right tree split-pos 0)])
            (let ([suffix (pvector-chunk-slice chunk
                                               chunk-index
                                               (pvector-chunk-length chunk))])
              (if suffix
                  (pvector-tree-cons-left right suffix 0)
                  right)))))))

(define (core-pvector-drop-right-tree pv pos len size)
  (let* ([tree (core-pvector-tree pv)]
         [new-len (fx- len pos)]
         [last-chunk (pvector-tree-last-node tree)]
         [last-len (pvector-chunk-length last-chunk)])
    (if (fx<= pos last-len)
        (let ([keep-len (fx- last-len pos)])
          (if (fx= keep-len 0)
              (let-values ([(popped rest) (pvector-tree-pop-right tree 0)])
                rest)
              (pvector-tree-replace-last
               tree
               (pvector-chunk-slice last-chunk 0 keep-len)
               0)))
        (let ([split-pos new-len])
          (let-values ([(chunk-index left chunk)
                        (pvector-split-tree-left tree split-pos 0)])
            (let ([prefix (pvector-chunk-slice chunk 0 chunk-index)])
              (if prefix
                  (pvector-tree-cons-right left prefix 0)
                  left)))))))

(define (core-pvector-take pv pos)
  (let ([len (core-pvector-length pv)]
        [size (core-pvector-chunk-size pv)])
    (cond
     [(fx= pos 0)
      (core-empty-pvector/size size)]
     [(fx= pos len)
      pv]
     [else
      (let ([chunks (core-pvector-cached-chunks pv)])
        (let-values ([(fill? value)
                      (if chunks
                          (core-pvector-shared-fill-value chunks)
                          (values #f #f))])
          (if fill?
              (core-make-pvector/size pos value size)
              (make-core-pvector/cached-slice
               (core-pvector-take-tree pv pos len size)
               pos
               size
               chunks
               0))))])))

(define (core-pvector-drop pv pos)
  (let ([len (core-pvector-length pv)]
        [size (core-pvector-chunk-size pv)])
    (cond
     [(fx= pos 0) pv]
     [(fx= pos len)
      (core-empty-pvector/size size)]
     [else
      (let* ([new-len (fx- len pos)]
             [chunks (core-pvector-cached-chunks pv)])
        (let-values ([(fill? value)
                      (if chunks
                          (core-pvector-shared-fill-value chunks)
                          (values #f #f))])
          (if fill?
              (core-make-pvector/size new-len value size)
              (make-core-pvector/cached-slice
               (core-pvector-drop-tree pv pos len size)
               new-len
               size
               chunks
               pos))))])))

(define (core-pvector-take-right pv pos)
  (let ([len (core-pvector-length pv)]
        [size (core-pvector-chunk-size pv)])
    (cond
     [(fx= pos 0)
      (core-empty-pvector/size size)]
     [(fx= pos len)
      pv]
     [else
      (let ([chunks (core-pvector-cached-chunks pv)])
        (let-values ([(fill? value)
                      (if chunks
                          (core-pvector-shared-fill-value chunks)
                          (values #f #f))])
          (if fill?
              (core-make-pvector/size pos value size)
              (make-core-pvector/cached-slice
               (core-pvector-take-right-tree pv pos len size)
               pos
               size
               chunks
               (fx- len pos)))))])))

(define (core-pvector-drop-right pv pos)
  (let ([len (core-pvector-length pv)]
        [size (core-pvector-chunk-size pv)])
    (cond
     [(fx= pos 0)
      pv]
     [(fx= pos len)
      (core-empty-pvector/size size)]
     [else
      (let* ([new-len (fx- len pos)]
             [chunks (core-pvector-cached-chunks pv)])
        (let-values ([(fill? value)
                      (if chunks
                          (core-pvector-shared-fill-value chunks)
                          (values #f #f))])
          (if fill?
              (core-make-pvector/size new-len value size)
              (make-core-pvector/cached-slice
               (core-pvector-drop-right-tree pv pos len size)
               new-len
               size
               chunks
               0))))])))

(define (core-pvector-copy/split pv start end)
  (let* ([len (fx- end start)]
         [size (core-pvector-chunk-size pv)]
         [tree (core-pvector-tree pv)])
    (let-values ([(start-index start-chunk right)
                  (pvector-split-tree-right tree start 0)])
      (let* ([chunk-len (pvector-chunk-length start-chunk)]
             [suffix-len (fxmin len (fx- chunk-len start-index))]
             [suffix (pvector-chunk-slice start-chunk
                                           start-index
                                           (fx+ start-index suffix-len))])
        (cond
         [(fx= suffix-len len)
          (make-core-pvector (make-pvector-single-tree suffix) len size)]
         [else
          (let* ([rest-len (fx- len suffix-len)]
                 [rest
                  (cond
                   [(fx= rest-len 0)
                    empty-core-pvector-tree]
                   [(fx= rest-len (pvector-tree-measure right))
                    right]
                   [else
                    (let-values ([(chunk-index left chunk)
                                  (pvector-split-tree-left right rest-len 0)])
                      (let ([prefix (pvector-chunk-slice chunk 0 chunk-index)])
                        (if prefix
                            (pvector-tree-cons-right left prefix 0)
                            left)))])])
            (make-core-pvector
             (pvector-tree-cons-left rest suffix 0)
             len
             size))])))))

(define (core-pvector-copy-small/across pv start end len size start-index start-chunk)
  (let-values ([(end-index end-chunk)
                (pvector-chunk-lookup-tree (core-pvector-tree pv) (fx- end 1) 0)])
    (let* ([start-len (pvector-chunk-length start-chunk)]
           [left-len (fx- start-len start-index)]
           [right-len (fx+ end-index 1)]
           [edge-len (fx+ left-len right-len)])
      (cond
       [(fx= edge-len len)
        (core-chunks->pvector
         (vector (pvector-chunk-slice start-chunk start-index start-len)
                 (pvector-chunk-slice end-chunk 0 right-len))
         len
         size)]
       [else
        (let ([middle-len (fx- len edge-len)])
          (if (fx<= middle-len size)
              (let-values ([(middle-index middle-chunk)
                            (pvector-chunk-lookup-tree
                             (core-pvector-tree pv)
                             (fx+ start left-len)
                             0)])
                (if (and (fx= middle-index 0)
                         (fx= middle-len (pvector-chunk-length middle-chunk)))
                    (core-chunks->pvector
                     (vector (pvector-chunk-slice start-chunk start-index start-len)
                             middle-chunk
                             (pvector-chunk-slice end-chunk 0 right-len))
                     len
                     size)
                    (core-pvector-copy/split pv start end)))
              (core-pvector-copy/split pv start end)))]))))

(define (core-pvector-copy/cached chunks start end len size)
  (let* ([default-size? (fx= size default-core-pvector-chunk-size)]
         [first-chunk-pos (if default-size?
                              (fxrshift start 6)
                              (fxquotient start size))]
         [last-index (fx- end 1)]
         [last-chunk-pos (if default-size?
                             (fxrshift last-index 6)
                             (fxquotient last-index size))]
         [start-index (if default-size?
                          (fxand start 63)
                          (fx- start (fx* first-chunk-pos size)))]
         [first-chunk (#3%vector-ref chunks first-chunk-pos)])
    (cond
     [(fx= first-chunk-pos last-chunk-pos)
      (make-core-pvector
       (make-pvector-single-tree
        (pvector-chunk-slice first-chunk start-index (fx+ start-index len)))
       len
       size)]
     [else
      (let* ([last-chunk (#3%vector-ref chunks last-chunk-pos)]
             [end-index (fx+ (if default-size?
                                 (fxand last-index 63)
                                 (fx- last-index (fx* last-chunk-pos size)))
                              1)]
             [first (pvector-chunk-slice first-chunk
                                         start-index
                                         (pvector-chunk-length first-chunk))]
             [last (pvector-chunk-slice last-chunk 0 end-index)]
             [span (fx+ (fx- last-chunk-pos first-chunk-pos) 1)]
             [chunks^ (#%vector-copy chunks first-chunk-pos span)])
        (#3%vector-set! chunks^ 0 first)
        (#3%vector-set! chunks^ (fx- span 1) last)
        (core-chunks->pvector chunks^ len size))])))

(define (core-pvector-copy pv start end)
  (cond
   [(fx= start end)
    (core-empty-pvector/size (core-pvector-chunk-size pv))]
   [(and (fx= start 0) (fx= end (core-pvector-length pv)))
    pv]
   [(fx= start 0)
    (let ([size (core-pvector-chunk-size pv)])
      (core-pvector-copy/preserve-edge-cache
       pv
       (core-pvector-take pv end)
       0
       end
       size))]
   [(fx= end (core-pvector-length pv))
    (let* ([len (fx- end start)]
           [size (core-pvector-chunk-size pv)])
      (core-pvector-copy/preserve-edge-cache
       pv
       (core-pvector-drop pv start)
       start
       len
       size))]
   [else
    (let ([len (fx- end start)]
          [size (core-pvector-chunk-size pv)])
      (let ([chunks (core-pvector-cached-chunks pv)])
        (if chunks
            (let-values ([(fill? value) (core-pvector-shared-fill-value chunks)])
              (if fill?
	                  (core-make-pvector/size len value size)
	                  (if (fx> len core-pvector-large-copy-composition-threshold)
	                      (core-pvector-preserve-copy-cache
	                       (core-pvector-take (core-pvector-drop pv start) len)
	                       chunks
	                       start
	                       len
	                       size)
	                      (core-pvector-copy/cached chunks start end len size))))
            (if (fx<= len (fx* size 2))
                (let-values ([(chunk-index chunk)
                              (pvector-chunk-lookup-tree (core-pvector-tree pv) start 0)])
                  (let ([chunk-end (fx+ chunk-index len)])
                    (if (fx<= chunk-end (pvector-chunk-length chunk))
                        (make-core-pvector
                         (make-pvector-single-tree (pvector-chunk-slice chunk chunk-index chunk-end))
                         len
                         size)
                        (core-pvector-copy-small/across pv
                                                        start
                                                        end
                                                        len
                                                        size
                                                        chunk-index
                                                        chunk))))
                (core-pvector-copy/split pv start end)))))]))

(define (core-vector->pvector vec)
  (let ([len (#%vector-length vec)]
        [size default-core-pvector-chunk-size])
    (cond
     [(fx= len 0)
      empty-core-pvector]
     [(and (fx<= len size)
           (#%immutable-vector? vec))
      (core-fixed-chunks->pvector (vector vec) len size)]
     [(#%immutable-vector? vec)
      (core-fixed-chunks->pvector
       (pvector-immutable-vector->slice-chunks vec size)
       len
       size)]
     [else
      (let ([first (#3%vector-ref vec 0)])
        (cond
         [(or (fx= len 1)
              (eq? (#3%vector-ref vec 1) first))
          (let loop ([i 2])
            (cond
             [(fx= i len)
              (core-make-pvector/size len first size)]
             [(eq? (#3%vector-ref vec i) first)
              (loop (fx+ i 1))]
             [else
              (let ([chunks (pvector-vector->chunks vec size)])
                (core-fixed-chunks->pvector chunks len size))]))]
         [else
          (let ([chunks (pvector-vector->chunks vec size)])
            (core-fixed-chunks->pvector chunks len size))]))])))

(define (core-fixed-chunks->pvector chunks len size)
  (if (fx= len 0)
      empty-core-pvector
      (make-core-pvector/with-chunks
       (pvector-nodes-vector->tree chunks len)
       len
       size
       chunks)))

(define (core-chunks->pvector chunks len size)
  (if (fx= len 0)
      empty-core-pvector
      (if (core-pvector-chunks-fixed-indexed? chunks len size)
          (core-fixed-chunks->pvector chunks len size)
          (make-core-pvector (pvector-nodes-vector->tree chunks len) len size))))

	(define (core-list->pvector/build rest chunks chunk-count len chunk chunk-pos size)
	  (cond
	   [(null? rest)
	    (let* ([chunks^
	            (if (fx= chunk-pos 0)
	                chunks
	                (cons (pvector-vector->immutable
	                       (pvector-vector-copy-range chunk 0 chunk-pos))
	                      chunks))]
	           [chunk-count^
	            (if (fx= chunk-pos 0)
	                chunk-count
	                (fx+ chunk-count 1))]
	           [chunk-vector (make-vector chunk-count^)])
	      (let fill ([chunks chunks^]
	                 [chunk-index (fx- chunk-count^ 1)])
	        (unless (null? chunks)
	          (#3%vector-set! chunk-vector chunk-index (car chunks))
	          (fill (cdr chunks) (fx- chunk-index 1))))
	      (core-fixed-chunks->pvector chunk-vector len size))]
	   [else
	    (#3%vector-set! chunk chunk-pos (car rest))
	    (let ([rest^ (cdr rest)]
	          [len^ (fx+ len 1)]
	          [chunk-pos^ (fx+ chunk-pos 1)])
	      (if (fx= chunk-pos^ size)
	          (core-list->pvector/build rest^
	                                     (cons (pvector-vector->immutable chunk) chunks)
	                                     (fx+ chunk-count 1)
	                                     len^
	                                     (make-vector size)
	                                     0
	                                     size)
	          (core-list->pvector/build rest^
	                                     chunks
	                                     chunk-count
	                                     len^
	                                     chunk
	                                     chunk-pos^
	                                     size)))]))

	(define (core-list->pvector/mixed first prefix-len rest size)
	  (let prefix-loop ([remaining prefix-len]
	                    [chunks '()]
	                    [chunk-count 0]
	                    [len 0]
	                    [chunk (make-vector size)]
	                    [chunk-pos 0])
	    (if (fx= remaining 0)
	        (core-list->pvector/build rest chunks chunk-count len chunk chunk-pos size)
	        (begin
	          (#3%vector-set! chunk chunk-pos first)
	          (let ([remaining^ (fx- remaining 1)]
	                [len^ (fx+ len 1)]
	                [chunk-pos^ (fx+ chunk-pos 1)])
	            (if (fx= chunk-pos^ size)
	                (prefix-loop remaining^
	                             (cons (pvector-vector->immutable chunk) chunks)
	                             (fx+ chunk-count 1)
	                             len^
	                             (make-vector size)
	                             0)
	                (prefix-loop remaining^
	                             chunks
	                             chunk-count
	                             len^
	                             chunk
	                             chunk-pos^)))))))

	(define (core-list->pvector lst)
	  (let ([size default-core-pvector-chunk-size])
	    (cond
	     [(null? lst) empty-core-pvector]
	     [else
	      (let ([first (car lst)])
	        (let uniform-loop ([rest (cdr lst)] [len 1])
	          (cond
	           [(null? rest)
	            (core-make-pvector/size len first size)]
	           [(eq? (car rest) first)
	            (uniform-loop (cdr rest) (fx+ len 1))]
	           [else
	            (core-list->pvector/mixed first len rest size)])))])))

(define (core-make-pvector/size len value size)
  (cond
   [(fx= len 0)
    (core-empty-pvector/size size)]
   [else
    (let* ([chunk-count (fxquotient (fx+ len (fx- size 1)) size)]
           [last-len (fx- len (fx* (fx- chunk-count 1) size))]
           [full-count (if (fx= last-len size)
                           chunk-count
                           (fx- chunk-count 1))]
           [full-chunk (and (fx> full-count 0)
                            (pvector-vector->immutable
                             (make-vector size value)))]
           [chunks (if full-chunk
                       (make-vector chunk-count full-chunk)
                       (make-vector chunk-count))])
      (unless (fx= full-count chunk-count)
        (#3%vector-set!
         chunks
         full-count
         (pvector-vector->immutable (make-vector last-len value))))
      (core-fixed-chunks->pvector chunks len size))]))

(define (core-make-pvector len value)
  (core-make-pvector/size len value default-core-pvector-chunk-size))

(define (core-pvector-fill-chunk! vec offset chunk)
  (let ([len (pvector-chunk-length chunk)])
    (pvector-copy-chunk-to-vector! vec offset chunk)
    (fx+ offset len)))

(define (core-pvector-fill-node! vec offset node depth)
  (cond
   [(fx= depth 0)
    (core-pvector-fill-chunk! vec offset node)]
   [(fx= depth 1)
    (if (pvector-node2? node)
        (core-pvector-fill-chunk! vec
                                  (core-pvector-fill-chunk!
                                   vec
                                   offset
                                   (pvector-node2-a node))
                                  (pvector-node2-b node))
        (core-pvector-fill-chunk! vec
                                  (core-pvector-fill-chunk!
                                   vec
                                   (core-pvector-fill-chunk!
                                    vec
                                    offset
                                    (pvector-node3-a node))
                                   (pvector-node3-b node))
                                  (pvector-node3-c node)))]
   [(fx= depth 2)
    (if (pvector-node2? node)
        (core-pvector-fill-node! vec
                                 (core-pvector-fill-node!
                                  vec
                                  offset
                                  (pvector-node2-a node)
                                  1)
                                 (pvector-node2-b node)
                                 1)
        (core-pvector-fill-node! vec
                                 (core-pvector-fill-node!
                                  vec
                                  (core-pvector-fill-node!
                                   vec
                                   offset
                                   (pvector-node3-a node)
                                   1)
                                  (pvector-node3-b node)
                                  1)
                                 (pvector-node3-c node)
                                 1))]
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

(define (core-pvector-fill-chunks! vec chunks)
  (let ([chunk-count (#%vector-length chunks)])
    (let loop ([chunk-i 0] [offset 0])
      (if (fx= chunk-i chunk-count)
          offset
          (loop (fx+ chunk-i 1)
                (core-pvector-fill-chunk!
                 vec
                 offset
                 (#3%vector-ref chunks chunk-i)))))))

(define (pvector-chunk-uniform-eq? chunk value)
  (let ([len (pvector-chunk-length chunk)])
    (let loop ([i 0])
      (or (fx= i len)
          (and (eq? (pvector-chunk-ref chunk i) value)
               (loop (fx+ i 1)))))))

(define (core-pvector-shared-fill-value chunks)
  (let ([chunk-count (#%vector-length chunks)])
    (if (fx< chunk-count 2)
        (values #f #f)
        (let ([first-chunk (#3%vector-ref chunks 0)])
          (if (not (eq? (#3%vector-ref chunks 1) first-chunk))
              (values #f #f)
              (let ([value (pvector-chunk-ref first-chunk 0)])
                (if (pvector-chunk-uniform-eq? first-chunk value)
                    (let loop ([chunk-i 2])
                      (cond
                       [(fx= chunk-i chunk-count) (values #t value)]
                       [else
                        (let ([chunk (#3%vector-ref chunks chunk-i)])
                          (if (or (eq? chunk first-chunk)
                                  (pvector-chunk-uniform-eq? chunk value))
                              (loop (fx+ chunk-i 1))
                              (values #f #f)))]))
                    (values #f #f))))))))

(define (core-pvector->vector pv)
  (let ([len (core-pvector-length pv)]
        [tree (core-pvector-tree pv)]
        [chunks (core-pvector-cached-chunks pv)])
    (cond
     [(fx= len 0)
      (make-vector 0)]
     [chunks
      (let-values ([(fill? value) (core-pvector-shared-fill-value chunks)])
        (if fill?
            (make-vector len value)
            (let ([vec (make-vector len)])
              (core-pvector-fill-chunks! vec chunks)
              vec)))]
     [(pvector-single-tree? tree)
      (pvector-chunk->vector (pvector-single-tree-a tree))]
     [else
      (let ([vec (make-vector len)])
        (core-pvector-fill-tree! vec 0 tree 0)
        vec)])))

(define (core-pvector-count-node-chunks node depth count)
  (cond
   [(fx= depth 0) (fx+ count 1)]
   [(pvector-node2? node)
    (let ([sub-depth (fx- depth 1)])
      (core-pvector-count-node-chunks
       (pvector-node2-b node)
       sub-depth
       (core-pvector-count-node-chunks (pvector-node2-a node) sub-depth count)))]
   [else
    (let ([sub-depth (fx- depth 1)])
      (core-pvector-count-node-chunks
       (pvector-node3-c node)
       sub-depth
       (core-pvector-count-node-chunks
        (pvector-node3-b node)
        sub-depth
        (core-pvector-count-node-chunks (pvector-node3-a node) sub-depth count))))]))

(define (core-pvector-count-digit-chunks digit depth count)
  (cond
   [(pvector-digit1? digit)
    (core-pvector-count-node-chunks (pvector-digit1-a digit) depth count)]
   [(pvector-digit2? digit)
    (core-pvector-count-node-chunks
     (pvector-digit2-b digit)
     depth
     (core-pvector-count-node-chunks (pvector-digit2-a digit) depth count))]
   [(pvector-digit3? digit)
    (core-pvector-count-node-chunks
     (pvector-digit3-c digit)
     depth
     (core-pvector-count-node-chunks
      (pvector-digit3-b digit)
      depth
      (core-pvector-count-node-chunks (pvector-digit3-a digit) depth count)))]
   [else
    (core-pvector-count-node-chunks
     (pvector-digit4-d digit)
     depth
     (core-pvector-count-node-chunks
      (pvector-digit4-c digit)
      depth
      (core-pvector-count-node-chunks
       (pvector-digit4-b digit)
       depth
       (core-pvector-count-node-chunks (pvector-digit4-a digit) depth count))))]))

(define (core-pvector-count-tree-chunks tree depth count)
  (cond
   [(pvector-empty-tree? tree) count]
   [(pvector-single-tree? tree)
    (core-pvector-count-node-chunks (pvector-single-tree-a tree) depth count)]
   [else
    (let ([inner-depth (fx+ depth 1)])
      (core-pvector-count-digit-chunks
       (pvector-deep-tree-right tree)
       depth
       (core-pvector-count-tree-chunks
        (pvector-deep-tree-inner tree)
        inner-depth
        (core-pvector-count-digit-chunks
         (pvector-deep-tree-left tree)
         depth
         count))))]))

(define (core-pvector-chunk->plain-vector chunk)
  (if (pvector-leaf-vector? chunk)
      chunk
      (pvector-vector->immutable
       (pvector-vector-copy-range (pvector-leaf-chunk-vector chunk)
                                  (pvector-leaf-chunk-start chunk)
                                  (pvector-leaf-chunk-end chunk)))))

(define (core-pvector-chunks-plain? chunks)
  (let ([count (#%vector-length chunks)])
    (let loop ([i 0])
      (or (fx= i count)
          (and (pvector-leaf-vector? (#3%vector-ref chunks i))
               (loop (fx+ i 1)))))))

(define (core-pvector-chunks->plain-vector chunks)
  (let* ([count (#%vector-length chunks)]
         [chunks^ (make-vector count)])
    (let loop ([i 0])
      (unless (fx= i count)
        (#3%vector-set! chunks^
                        i
                        (core-pvector-chunk->plain-vector
                         (#3%vector-ref chunks i)))
        (loop (fx+ i 1))))
    chunks^))

(define (core-pvector-lookup-chunk-node node index depth)
  (if (fx= depth 0)
      (values index node)
      (let ([sub-depth (fx- depth 1)])
        (cond
         [(pvector-node2? node)
          (let* ([a (pvector-node2-a node)]
                 [a-size (pvector-subtree-measure a)])
            (if (fx< index a-size)
                (core-pvector-lookup-chunk-node a index sub-depth)
                (core-pvector-lookup-chunk-node (pvector-node2-b node)
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
              (core-pvector-lookup-chunk-node a index sub-depth)]
             [(fx< index ab-size)
              (core-pvector-lookup-chunk-node b (fx- index a-size) sub-depth)]
             [else
              (core-pvector-lookup-chunk-node (pvector-node3-c node)
                                              (fx- index ab-size)
                                              sub-depth)]))]))))

(define (core-pvector-lookup-chunk-digit digit index depth)
  (cond
   [(pvector-digit1? digit)
    (core-pvector-lookup-chunk-node (pvector-digit1-a digit) index depth)]
   [(pvector-digit2? digit)
    (let* ([a (pvector-digit2-a digit)]
           [a-size (pvector-subtree-measure a)])
      (if (fx< index a-size)
          (core-pvector-lookup-chunk-node a index depth)
          (core-pvector-lookup-chunk-node (pvector-digit2-b digit)
                                          (fx- index a-size)
                                          depth)))]
   [(pvector-digit3? digit)
    (let* ([a (pvector-digit3-a digit)]
           [b (pvector-digit3-b digit)]
           [a-size (pvector-subtree-measure a)]
           [b-size (pvector-subtree-measure b)]
           [ab-size (fx+ a-size b-size)])
      (cond
       [(fx< index a-size)
        (core-pvector-lookup-chunk-node a index depth)]
       [(fx< index ab-size)
        (core-pvector-lookup-chunk-node b (fx- index a-size) depth)]
       [else
        (core-pvector-lookup-chunk-node (pvector-digit3-c digit)
                                        (fx- index ab-size)
                                        depth)]))]
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
        (core-pvector-lookup-chunk-node a index depth)]
       [(fx< index ab-size)
        (core-pvector-lookup-chunk-node b (fx- index a-size) depth)]
       [(fx< index abc-size)
        (core-pvector-lookup-chunk-node c (fx- index ab-size) depth)]
       [else
        (core-pvector-lookup-chunk-node (pvector-digit4-d digit)
                                        (fx- index abc-size)
                                        depth)]))]))

(define (core-pvector-lookup-chunk-tree tree index depth)
  (cond
   [(pvector-single-tree? tree)
    (core-pvector-lookup-chunk-node (pvector-single-tree-a tree) index depth)]
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
        (core-pvector-lookup-chunk-digit left index depth)]
       [(fx< index left+inner-size)
        (core-pvector-lookup-chunk-tree inner (fx- index left-size) inner-depth)]
       [else
        (core-pvector-lookup-chunk-digit right
                                         (fx- index left+inner-size)
                                         depth)]))]
   [else
    (error 'core-pvector-lookup-chunk "index out of bounds")]))

(define (core-pvector-lookup-chunk pv index)
  (let ([chunks (core-pvector-cached-chunks pv)])
    (if chunks
        (let* ([size (core-pvector-chunk-size pv)]
               [default-size? (fx= size default-core-pvector-chunk-size)]
               [chunk-pos (if default-size?
                              (fxrshift index 6)
                              (fxquotient index size))]
               [index^ (if default-size?
                           (fxand index 63)
                           (fx- index (fx* chunk-pos size)))]
               [chunk (#3%vector-ref chunks chunk-pos)])
          (values index^ (core-pvector-chunk->plain-vector chunk)))
        (let-values ([(index^ chunk)
                      (core-pvector-lookup-chunk-tree (core-pvector-tree pv) index 0)])
          (values index^ (core-pvector-chunk->plain-vector chunk))))))

(define (core-pvector-fill-chunk-vector! chunks index chunk)
  (#3%vector-set! chunks index (core-pvector-chunk->plain-vector chunk))
  (fx+ index 1))

(define (core-pvector-fill-node-chunk-vector! chunks index node depth)
  (cond
   [(fx= depth 0)
    (core-pvector-fill-chunk-vector! chunks index node)]
   [(fx= depth 1)
    (if (pvector-node2? node)
        (core-pvector-fill-chunk-vector!
         chunks
         (core-pvector-fill-chunk-vector! chunks index (pvector-node2-a node))
         (pvector-node2-b node))
        (core-pvector-fill-chunk-vector!
         chunks
         (core-pvector-fill-chunk-vector!
          chunks
          (core-pvector-fill-chunk-vector! chunks index (pvector-node3-a node))
          (pvector-node3-b node))
         (pvector-node3-c node)))]
   [(fx= depth 2)
    (if (pvector-node2? node)
        (core-pvector-fill-node-chunk-vector!
         chunks
         (core-pvector-fill-node-chunk-vector! chunks index (pvector-node2-a node) 1)
         (pvector-node2-b node)
         1)
        (core-pvector-fill-node-chunk-vector!
         chunks
         (core-pvector-fill-node-chunk-vector!
          chunks
          (core-pvector-fill-node-chunk-vector! chunks index (pvector-node3-a node) 1)
          (pvector-node3-b node)
          1)
         (pvector-node3-c node)
         1))]
   [(pvector-node2? node)
    (let ([sub-depth (fx- depth 1)])
      (core-pvector-fill-node-chunk-vector!
       chunks
       (core-pvector-fill-node-chunk-vector! chunks index (pvector-node2-a node) sub-depth)
       (pvector-node2-b node)
       sub-depth))]
   [else
    (let ([sub-depth (fx- depth 1)])
      (core-pvector-fill-node-chunk-vector!
       chunks
       (core-pvector-fill-node-chunk-vector!
        chunks
        (core-pvector-fill-node-chunk-vector! chunks index (pvector-node3-a node) sub-depth)
        (pvector-node3-b node)
        sub-depth)
       (pvector-node3-c node)
       sub-depth))]))

(define (core-pvector-fill-digit-chunk-vector! chunks index digit depth)
  (cond
   [(pvector-digit1? digit)
    (core-pvector-fill-node-chunk-vector! chunks index (pvector-digit1-a digit) depth)]
   [(pvector-digit2? digit)
    (core-pvector-fill-node-chunk-vector!
     chunks
     (core-pvector-fill-node-chunk-vector! chunks index (pvector-digit2-a digit) depth)
     (pvector-digit2-b digit)
     depth)]
   [(pvector-digit3? digit)
    (core-pvector-fill-node-chunk-vector!
     chunks
     (core-pvector-fill-node-chunk-vector!
      chunks
      (core-pvector-fill-node-chunk-vector! chunks index (pvector-digit3-a digit) depth)
      (pvector-digit3-b digit)
      depth)
     (pvector-digit3-c digit)
     depth)]
   [else
    (core-pvector-fill-node-chunk-vector!
     chunks
     (core-pvector-fill-node-chunk-vector!
      chunks
      (core-pvector-fill-node-chunk-vector!
       chunks
       (core-pvector-fill-node-chunk-vector! chunks index (pvector-digit4-a digit) depth)
       (pvector-digit4-b digit)
       depth)
      (pvector-digit4-c digit)
      depth)
     (pvector-digit4-d digit)
     depth)]))

(define (core-pvector-fill-tree-chunk-vector! chunks index tree depth)
  (cond
   [(pvector-empty-tree? tree) index]
   [(pvector-single-tree? tree)
    (core-pvector-fill-node-chunk-vector! chunks index (pvector-single-tree-a tree) depth)]
   [else
    (let ([inner-depth (fx+ depth 1)])
      (core-pvector-fill-digit-chunk-vector!
       chunks
       (core-pvector-fill-tree-chunk-vector!
        chunks
        (core-pvector-fill-digit-chunk-vector!
         chunks
         index
         (pvector-deep-tree-left tree)
         depth)
        (pvector-deep-tree-inner tree)
        inner-depth)
       (pvector-deep-tree-right tree)
       depth))]))

(define (core-pvector->chunk-vector/shared pv)
  (let ([chunks (core-pvector-cached-chunks pv)])
    (if chunks
        (if (core-pvector-chunks-plain? chunks)
            chunks
            (core-pvector-chunks->plain-vector chunks))
        (let ([tree (core-pvector-tree pv)])
          (cond
           [(fx= 0 (core-pvector-length pv))
            (make-vector 0)]
           [(pvector-single-tree? tree)
            (vector (core-pvector-chunk->plain-vector (pvector-single-tree-a tree)))]
           [else
            (let* ([count (core-pvector-count-tree-chunks tree 0 0)]
                   [chunks (make-vector count)])
              (core-pvector-fill-tree-chunk-vector! chunks 0 tree 0)
              chunks)])))))

	(define (core-pvector->chunk-vector pv)
	  (#%vector-copy (core-pvector->chunk-vector/shared pv)))

	(define (core-pvector-map-shared-fill/mixed len size value proc first diff-index diff-value)
	  (let* ([chunk-count (fxquotient (fx+ len (fx- size 1)) size)]
	         [chunks (make-vector chunk-count)]
	         [first-full-chunk #f])
	    (let chunk-loop ([chunk-i 0] [offset 0])
	      (if (fx= chunk-i chunk-count)
	          (core-fixed-chunks->pvector chunks len size)
	          (let* ([chunk-len (fxmin size (fx- len offset))]
	                 [chunk-end (fx+ offset chunk-len)])
	            (if (fx<= chunk-end diff-index)
	                (#3%vector-set!
	                 chunks
	                 chunk-i
	                 (if (fx= chunk-len size)
	                     (if first-full-chunk
	                         first-full-chunk
	                         (let ([chunk (pvector-vector->immutable
	                                       (make-vector size first))])
	                           (set! first-full-chunk chunk)
	                           chunk))
	                     (pvector-vector->immutable (make-vector chunk-len first))))
	                (let ([chunk (make-vector chunk-len)])
	                  (let elem-loop ([elem-i 0] [index offset])
	                    (unless (fx= elem-i chunk-len)
	                      (#3%vector-set!
	                       chunk
	                       elem-i
	                       (cond
	                        [(fx< index diff-index) first]
	                        [(fx= index diff-index) diff-value]
	                        [else (proc value)]))
	                      (elem-loop (fx+ elem-i 1) (fx+ index 1))))
	                  (#3%vector-set! chunks chunk-i (pvector-vector->immutable chunk))))
	            (chunk-loop (fx+ chunk-i 1) (fx+ offset chunk-len)))))))

	(define (core-pvector-map-shared-fill len size value proc)
	  (let ([first (proc value)])
	    (let loop ([index 1])
	      (cond
	       [(fx= index len)
	        (core-make-pvector/size len first size)]
	       [else
	        (let ([next (proc value)])
	          (if (eq? next first)
	              (loop (fx+ index 1))
	              (core-pvector-map-shared-fill/mixed
	               len
	               size
	               value
	               proc
	               first
	               index
	               next)))]))))

	(define (core-pvector-map pv proc)
	  (let ([len (core-pvector-length pv)])
	    (if (fx= len 0)
	        empty-core-pvector
	        (if (eq? proc values)
	            pv
	            (if (eq? proc void)
	                (core-make-pvector len (void))
	                (let* ([size (core-pvector-chunk-size pv)]
	                       [cached-chunks (core-pvector-cached-chunks pv)])
	                  (let-values ([(fill? value)
	                                (if cached-chunks
	                                    (core-pvector-shared-fill-value cached-chunks)
	                                    (values #f #f))])
	                    (if fill?
	                        (core-pvector-map-shared-fill len size value proc)
	                        (let* ([chunks (if cached-chunks
	                                           (if (core-pvector-chunks-plain? cached-chunks)
	                                               cached-chunks
	                                               (core-pvector-chunks->plain-vector cached-chunks))
	                                           (core-pvector->chunk-vector/shared pv))]
	                               [chunk-count (#%vector-length chunks)]
	                               [mapped-chunks (make-vector chunk-count)])
	                          (let chunk-loop ([chunk-i 0])
	                            (if (fx= chunk-i chunk-count)
	                                (core-chunks->pvector mapped-chunks len size)
	                                (let* ([chunk (#3%vector-ref chunks chunk-i)]
	                                       [chunk-len (#%vector-length chunk)]
	                                       [mapped (make-vector chunk-len)])
	                                  (let elem-loop ([elem-i 0])
	                                    (unless (fx= elem-i chunk-len)
	                                      (#3%vector-set! mapped
	                                                      elem-i
	                                                      (proc (#3%vector-ref chunk elem-i)))
	                                      (elem-loop (fx+ elem-i 1))))
	                                  (#3%vector-set! mapped-chunks
	                                                  chunk-i
	                                                  (pvector-vector->immutable mapped))
	                                  (chunk-loop (fx+ chunk-i 1))))))))))))))

(define (core-pvector-for-each-chunk chunk proc)
  (cond
   [(pvector-leaf-vector? chunk)
    (let ([len (#%vector-length chunk)])
      (let loop ([elem-i 0])
        (unless (fx= elem-i len)
          (proc (#3%vector-ref chunk elem-i))
          (loop (fx+ elem-i 1)))))]
   [else
    (let ([vec (pvector-leaf-chunk-vector chunk)]
          [end (pvector-leaf-chunk-end chunk)])
      (let loop ([elem-i (pvector-leaf-chunk-start chunk)])
        (unless (fx= elem-i end)
          (proc (#3%vector-ref vec elem-i))
          (loop (fx+ elem-i 1)))))]))

(define (core-pvector-for-each-node node depth proc)
  (cond
   [(fx= depth 0)
    (core-pvector-for-each-chunk node proc)]
   [(pvector-node2? node)
    (let ([sub-depth (fx- depth 1)])
      (core-pvector-for-each-node (pvector-node2-a node) sub-depth proc)
      (core-pvector-for-each-node (pvector-node2-b node) sub-depth proc))]
   [else
    (let ([sub-depth (fx- depth 1)])
      (core-pvector-for-each-node (pvector-node3-a node) sub-depth proc)
      (core-pvector-for-each-node (pvector-node3-b node) sub-depth proc)
      (core-pvector-for-each-node (pvector-node3-c node) sub-depth proc))]))

(define (core-pvector-for-each-digit digit depth proc)
  (cond
   [(pvector-digit1? digit)
    (core-pvector-for-each-node (pvector-digit1-a digit) depth proc)]
   [(pvector-digit2? digit)
    (core-pvector-for-each-node (pvector-digit2-a digit) depth proc)
    (core-pvector-for-each-node (pvector-digit2-b digit) depth proc)]
   [(pvector-digit3? digit)
    (core-pvector-for-each-node (pvector-digit3-a digit) depth proc)
    (core-pvector-for-each-node (pvector-digit3-b digit) depth proc)
    (core-pvector-for-each-node (pvector-digit3-c digit) depth proc)]
   [else
    (core-pvector-for-each-node (pvector-digit4-a digit) depth proc)
    (core-pvector-for-each-node (pvector-digit4-b digit) depth proc)
    (core-pvector-for-each-node (pvector-digit4-c digit) depth proc)
    (core-pvector-for-each-node (pvector-digit4-d digit) depth proc)]))

(define (core-pvector-for-each-tree tree depth proc)
  (cond
   [(pvector-empty-tree? tree)
    (void)]
   [(pvector-single-tree? tree)
    (core-pvector-for-each-node (pvector-single-tree-a tree) depth proc)]
   [else
    (let ([inner-depth (fx+ depth 1)])
      (core-pvector-for-each-digit (pvector-deep-tree-left tree) depth proc)
      (core-pvector-for-each-tree (pvector-deep-tree-inner tree) inner-depth proc)
      (core-pvector-for-each-digit (pvector-deep-tree-right tree) depth proc))]))

(define (core-pvector-fragmented-endpoint-tree? tree)
  (and (pvector-deep-tree? tree)
       (or (fx<= (pvector-chunk-length (pvector-tree-first-node tree))
                 core-pvector-endpoint-pack-limit)
           (fx<= (pvector-chunk-length (pvector-tree-last-node tree))
                 core-pvector-endpoint-pack-limit))))

(define (core-pvector-for-each-chunks chunks proc)
  (let ([chunk-count (#%vector-length chunks)])
    (let chunk-loop ([chunk-i 0])
      (unless (fx= chunk-i chunk-count)
        (let* ([chunk (#3%vector-ref chunks chunk-i)]
               [chunk-len (#%vector-length chunk)])
          (let elem-loop ([elem-i 0])
            (unless (fx= elem-i chunk-len)
              (proc (#3%vector-ref chunk elem-i))
              (elem-loop (fx+ elem-i 1)))))
        (chunk-loop (fx+ chunk-i 1))))))

(define (core-pvector-for-each pv proc)
  (unless (or (eq? proc void)
              (eq? proc values))
    (let ([chunks (core-pvector-cached-chunks pv)])
      (if chunks
          (let ([chunks (if (core-pvector-chunks-plain? chunks)
                            chunks
                            (core-pvector-chunks->plain-vector chunks))])
            (core-pvector-for-each-chunks chunks proc))
          (let ([tree (core-pvector-tree pv)])
            (if (core-pvector-fragmented-endpoint-tree? tree)
                (core-pvector-for-each-tree tree 0 proc)
                (core-pvector-for-each-chunks
                 (core-pvector->chunk-vector/shared pv)
                 proc)))))))

(define (core-pvector-node->list/reverse node depth acc)
  (cond
   [(fx= depth 0)
    (pvector-chunk->list/reverse node acc)]
   [(pvector-node2? node)
    (let ([sub-depth (fx- depth 1)])
      (core-pvector-node->list/reverse
       (pvector-node2-a node)
       sub-depth
       (core-pvector-node->list/reverse
        (pvector-node2-b node)
        sub-depth
        acc)))]
   [else
    (let ([sub-depth (fx- depth 1)])
      (core-pvector-node->list/reverse
       (pvector-node3-a node)
       sub-depth
       (core-pvector-node->list/reverse
        (pvector-node3-b node)
        sub-depth
        (core-pvector-node->list/reverse
         (pvector-node3-c node)
         sub-depth
         acc))))]))

(define (core-pvector-digit->list/reverse digit depth acc)
  (cond
   [(pvector-digit1? digit)
    (core-pvector-node->list/reverse (pvector-digit1-a digit) depth acc)]
   [(pvector-digit2? digit)
    (core-pvector-node->list/reverse
     (pvector-digit2-a digit)
     depth
     (core-pvector-node->list/reverse
      (pvector-digit2-b digit)
      depth
      acc))]
   [(pvector-digit3? digit)
    (core-pvector-node->list/reverse
     (pvector-digit3-a digit)
     depth
     (core-pvector-node->list/reverse
      (pvector-digit3-b digit)
      depth
      (core-pvector-node->list/reverse
       (pvector-digit3-c digit)
       depth
       acc)))]
   [else
    (core-pvector-node->list/reverse
     (pvector-digit4-a digit)
     depth
     (core-pvector-node->list/reverse
      (pvector-digit4-b digit)
      depth
      (core-pvector-node->list/reverse
       (pvector-digit4-c digit)
       depth
       (core-pvector-node->list/reverse
        (pvector-digit4-d digit)
        depth
        acc))))]))

(define (core-pvector-tree->list/reverse tree depth acc)
  (cond
   [(pvector-empty-tree? tree) acc]
   [(pvector-single-tree? tree)
    (core-pvector-node->list/reverse (pvector-single-tree-a tree) depth acc)]
   [else
    (let ([inner-depth (fx+ depth 1)])
      (core-pvector-digit->list/reverse
       (pvector-deep-tree-left tree)
       depth
       (core-pvector-tree->list/reverse
        (pvector-deep-tree-inner tree)
        inner-depth
        (core-pvector-digit->list/reverse
         (pvector-deep-tree-right tree)
         depth
         acc))))]))

(define (core-pvector-chunks->list chunks)
  (let loop ([chunk-i (fx- (#%vector-length chunks) 1)] [acc '()])
    (if (fx< chunk-i 0)
        acc
        (loop (fx- chunk-i 1)
              (pvector-chunk->list/reverse (#3%vector-ref chunks chunk-i)
                                           acc)))))

(define (core-pvector-make-list len value)
  (let loop ([i len] [acc '()])
    (if (fx= i 0)
        acc
        (loop (fx- i 1) (cons value acc)))))

(define (core-pvector->list pv)
  (let ([chunks (core-pvector-cached-chunks pv)])
    (if chunks
        (let-values ([(fill? value) (core-pvector-shared-fill-value chunks)])
          (if fill?
              (core-pvector-make-list (core-pvector-length pv) value)
              (core-pvector-chunks->list chunks)))
        (core-pvector-tree->list/reverse (core-pvector-tree pv) 0 '()))))
