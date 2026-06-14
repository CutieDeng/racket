;; Fixed-measure persistent vector core candidate.
;;
;; This version is the no-chunk baseline described in
;; `pvector-runtime-native-design.md`: values do not maintain chunk leaves,
;; chunk-index vectors, ref caches, or flat payload vectors. The shape follows
;; the standard finger-tree split: empty, single, and deep values with
;; prefix/suffix digits and a size-measured node2/node3 middle tree.

(define core-pvector-inline-max 1)
(define core-pvector-digit-max 4)

(define-record-type core-pvector-empty-record
  [fields]
  [nongenerative #{core-pvector-empty-record cutie-pvector-runtime-native-1}]
  [sealed #t])

(define-record-type core-pvector-inline
  [fields (immutable length)
          (immutable e0)
          (immutable e1)
          (immutable e2)
          (immutable e3)]
  [nongenerative #{core-pvector-inline cutie-pvector-runtime-native-2}]
  [sealed #t])

(define-record-type core-pvector-node2
  [fields (immutable measure)
          (immutable level)
          (immutable a)
          (immutable b)]
  [nongenerative #{core-pvector-node2 cutie-pvector-runtime-native-4}]
  [sealed #t])

(define-record-type core-pvector-node3
  [fields (immutable measure)
          (immutable level)
          (immutable a)
          (immutable b)
          (immutable c)]
  [nongenerative #{core-pvector-node3 cutie-pvector-runtime-native-5}]
  [sealed #t])

(define-record-type core-pvector-large-finger
  [fields (immutable length)
          (immutable prefix)
          (immutable middle)
          (immutable suffix)]
  [nongenerative #{core-pvector-large-finger cutie-pvector-runtime-native-6}]
  [sealed #t])

(define empty-core-pvector (make-core-pvector-empty-record))

(define (core-pvector? v)
  (or (core-pvector-empty-record? v)
      (core-pvector-inline? v)
      (core-pvector-large-finger? v)))

(define (core-pvector-empty)
  empty-core-pvector)

(define (core-pvector-empty? pv)
  (eq? pv empty-core-pvector))

(define (core-pvector-length pv)
  (cond
   [(core-pvector-empty-record? pv) 0]
   [(core-pvector-inline? pv) (core-pvector-inline-length pv)]
   [else (core-pvector-large-finger-length pv)]))

(define (core-vector-copy-range vec start end)
  (let* ([len (fx- end start)]
         [copy
          (cond
           [(fx= len 1)
            (vector (#3%vector-ref vec start))]
           [(fx= len 2)
            (vector (#3%vector-ref vec start)
                    (#3%vector-ref vec (fx+ start 1)))]
           [(fx= len 3)
            (vector (#3%vector-ref vec start)
                    (#3%vector-ref vec (fx+ start 1))
                    (#3%vector-ref vec (fx+ start 2)))]
           [(fx= len 4)
            (vector (#3%vector-ref vec start)
                    (#3%vector-ref vec (fx+ start 1))
                    (#3%vector-ref vec (fx+ start 2))
                    (#3%vector-ref vec (fx+ start 3)))]
           [else
            (let ([copy (make-vector len)])
              (let loop ([i 0])
                (unless (fx= i len)
                  (#3%vector-set! copy i (#3%vector-ref vec (fx+ start i)))
                  (loop (fx+ i 1))))
              copy)])])
    copy))

(define (core-vector-copy-range/immutable vec start end)
  (let ([len (fx- end start)])
    (cond
     [(fx= len 0)
      (inline:vector-immutable)]
     [(fx= len 1)
      (core-immutable-vector1
       (#3%vector-ref vec start))]
     [(fx= len 2)
      (core-immutable-vector2
       (#3%vector-ref vec start)
       (#3%vector-ref vec (fx+ start 1)))]
     [(fx= len 3)
      (core-immutable-vector3
       (#3%vector-ref vec start)
       (#3%vector-ref vec (fx+ start 1))
       (#3%vector-ref vec (fx+ start 2)))]
     [(fx= len 4)
      (core-immutable-vector4
       (#3%vector-ref vec start)
       (#3%vector-ref vec (fx+ start 1))
       (#3%vector-ref vec (fx+ start 2))
       (#3%vector-ref vec (fx+ start 3)))]
     [else
      (#3%vector->immutable-vector
       (core-vector-copy-range vec start end))])))

(define (core-vector-copy/immutable vec)
  (core-vector-copy-range/immutable vec 0 (#%vector-length vec)))

(define (core-pvector-range->immutable-vector/known-length pv len start end)
  (let ([range-len (fx- end start)])
    (cond
     [(fx= range-len 0)
      (inline:vector-immutable)]
     [(fx= range-len 1)
      (core-immutable-vector1
       (core-pvector-ref-edge/unchecked pv len start))]
     [(fx= range-len 2)
      (if (core-pvector-large-finger? pv)
          (core-pvector-large-finger-range->immutable-vector-short/known-length
           pv
           len
           start
           range-len)
          (core-immutable-vector2
           (core-pvector-ref-start-edge/unchecked pv len start)
           (core-pvector-ref-end-edge/unchecked pv len (fx+ start 1))))]
     [(fx= range-len 3)
      (if (core-pvector-large-finger? pv)
          (core-pvector-large-finger-range->immutable-vector-short/known-length
           pv
           len
           start
           range-len)
          (core-immutable-vector3
           (core-pvector-ref-start-edge/unchecked pv len start)
           (core-pvector-ref/unchecked/known-length pv len (fx+ start 1))
           (core-pvector-ref-end-edge/unchecked pv len (fx+ start 2))))]
     [(fx= range-len 4)
      (if (core-pvector-large-finger? pv)
          (core-pvector-large-finger-range->immutable-vector-short/known-length
           pv
           len
           start
           range-len)
          (core-immutable-vector4
           (core-pvector-ref-start-edge/unchecked pv len start)
           (core-pvector-ref/unchecked/known-length pv len (fx+ start 1))
           (core-pvector-ref/unchecked/known-length pv len (fx+ start 2))
           (core-pvector-ref-end-edge/unchecked pv len (fx+ start 3))))]
     [else
      (let ([vec (make-vector range-len)])
        (core-pvector-fill-range!/known-length vec 0 pv len start end)
        (#3%vector->immutable-vector vec))])))

(define (core-pvector-range->immutable-vector pv start end)
  (core-pvector-range->immutable-vector/known-length
   pv
   (core-pvector-length pv)
   start
   end))

(define (core-vector-set/immutable vec len index value)
  (cond
   [(fx= len 1)
    (core-immutable-vector1 value)]
   [(fx= len 2)
    (let ([a (#3%vector-ref vec 0)]
          [b (#3%vector-ref vec 1)])
      (if (fx= index 0)
          (core-immutable-vector2 value b)
          (core-immutable-vector2 a value)))]
   [(fx= len 3)
    (let ([a (#3%vector-ref vec 0)]
          [b (#3%vector-ref vec 1)]
          [c (#3%vector-ref vec 2)])
      (cond
       [(fx= index 0) (core-immutable-vector3 value b c)]
       [(fx= index 1) (core-immutable-vector3 a value c)]
       [else (core-immutable-vector3 a b value)]))]
   [(fx= len 4)
    (let ([a (#3%vector-ref vec 0)]
          [b (#3%vector-ref vec 1)]
          [c (#3%vector-ref vec 2)]
          [d (#3%vector-ref vec 3)])
      (cond
       [(fx= index 0) (core-immutable-vector4 value b c d)]
       [(fx= index 1) (core-immutable-vector4 a value c d)]
       [(fx= index 2) (core-immutable-vector4 a b value d)]
       [else (core-immutable-vector4 a b c value)]))]
   [else
    (let ([new-vec (core-vector-copy-range vec 0 len)])
      (#3%vector-set! new-vec index value)
      (#3%vector->immutable-vector new-vec))]))

(define (core-vector-insert/immutable vec len index value)
  (cond
   [(fx= len 1)
    (let ([a (#3%vector-ref vec 0)])
      (if (fx= index 0)
          (core-immutable-vector2 value a)
          (core-immutable-vector2 a value)))]
   [(fx= len 2)
    (let ([a (#3%vector-ref vec 0)]
          [b (#3%vector-ref vec 1)])
      (cond
       [(fx= index 0) (core-immutable-vector3 value a b)]
       [(fx= index 1) (core-immutable-vector3 a value b)]
       [else (core-immutable-vector3 a b value)]))]
   [(fx= len 3)
    (let ([a (#3%vector-ref vec 0)]
          [b (#3%vector-ref vec 1)]
          [c (#3%vector-ref vec 2)])
      (cond
       [(fx= index 0) (core-immutable-vector4 value a b c)]
       [(fx= index 1) (core-immutable-vector4 a value b c)]
       [(fx= index 2) (core-immutable-vector4 a b value c)]
       [else (core-immutable-vector4 a b c value)]))]
   [else
    (let ([new-vec (make-vector (fx+ len 1))])
      (let loop ([i 0])
        (unless (fx= i index)
          (#3%vector-set! new-vec i (#3%vector-ref vec i))
          (loop (fx+ i 1))))
      (#3%vector-set! new-vec index value)
      (let loop ([i index])
        (unless (fx= i len)
          (#3%vector-set! new-vec (fx+ i 1) (#3%vector-ref vec i))
          (loop (fx+ i 1))))
      (#3%vector->immutable-vector new-vec))]))

(define (core-vector-remove/immutable vec len index)
  (cond
   [(fx= len 2)
    (core-immutable-vector1
     (#3%vector-ref vec (if (fx= index 0) 1 0)))]
   [(fx= len 3)
    (let ([a (#3%vector-ref vec 0)]
          [b (#3%vector-ref vec 1)]
          [c (#3%vector-ref vec 2)])
      (cond
       [(fx= index 0) (core-immutable-vector2 b c)]
       [(fx= index 1) (core-immutable-vector2 a c)]
       [else (core-immutable-vector2 a b)]))]
   [(fx= len 4)
    (let ([a (#3%vector-ref vec 0)]
          [b (#3%vector-ref vec 1)]
          [c (#3%vector-ref vec 2)]
          [d (#3%vector-ref vec 3)])
      (cond
       [(fx= index 0) (core-immutable-vector3 b c d)]
       [(fx= index 1) (core-immutable-vector3 a c d)]
       [(fx= index 2) (core-immutable-vector3 a b d)]
       [else (core-immutable-vector3 a b c)]))]
   [else
    (let ([new-vec (make-vector (fx- len 1))])
      (let loop ([i 0])
        (unless (fx= i index)
          (#3%vector-set! new-vec i (#3%vector-ref vec i))
          (loop (fx+ i 1))))
      (let loop ([i (fx+ index 1)])
        (unless (fx= i len)
          (#3%vector-set! new-vec (fx- i 1) (#3%vector-ref vec i))
          (loop (fx+ i 1))))
      (#3%vector->immutable-vector new-vec))]))

(define (core-list-length lst)
  (let loop ([lst lst] [len 0])
    (if (null? lst)
        len
        (loop (cdr lst) (fx+ len 1)))))

(define (core-reverse-list->vector lst)
  (let* ([len (core-list-length lst)]
         [vec (make-vector len)])
    (let loop ([lst lst] [i (fx- len 1)])
      (unless (null? lst)
        (#3%vector-set! vec i (car lst))
        (loop (cdr lst) (fx- i 1))))
    vec))

(define (core-make-leaf-node2 a b)
  (make-core-pvector-node2 2 1 a b))

(define (core-make-leaf-node3 a b c)
  (make-core-pvector-node3 3 1 a b c))

(define (core-pvector-node-leaf-slice/aligned node start end)
  (let ([slice-len (fx- end start)])
    (cond
     [(fx< slice-len 2) #f]
     [(core-pvector-node2? node) node]
     [(fx= slice-len 3) node]
     [(fx= start 0)
      (core-make-leaf-node2
       (core-pvector-node3-a node)
       (core-pvector-node3-b node))]
     [else
      (core-make-leaf-node2
       (core-pvector-node3-b node)
       (core-pvector-node3-c node))])))

(define (core-make-node2 node-level a b)
  (if (fx= node-level 1)
      (core-make-leaf-node2 a b)
      (make-core-pvector-node2
       (fx+ (core-pvector-node-measure a)
            (core-pvector-node-measure b))
       node-level
       a
       b)))

(define (core-make-node3 node-level a b c)
  (if (fx= node-level 1)
      (core-make-leaf-node3 a b c)
      (make-core-pvector-node3
       (fx+ (core-pvector-node-measure a)
            (fx+ (core-pvector-node-measure b)
                 (core-pvector-node-measure c)))
       node-level
       a
       b
       c)))

(define (core-pvector-node-measure node)
  (if (core-pvector-node2? node)
      (core-pvector-node2-measure node)
      (core-pvector-node3-measure node)))

(define (core-pvector-node-level node)
  (if (core-pvector-node2? node)
      (core-pvector-node2-level node)
      (core-pvector-node3-level node)))

(define (core-pvector-node-link2 a b)
  (core-make-node2
   (fx+ (fxmax (core-pvector-node-level a)
               (core-pvector-node-level b))
        1)
   a
   b))

(define (core-pvector-node-link3 a b c)
  (core-make-node3
   (fx+ (fxmax (core-pvector-node-level a)
               (fxmax (core-pvector-node-level b)
                      (core-pvector-node-level c)))
        1)
   a
   b
   c))

(define (core-pvector-node-vector-max-level nodes)
  (let ([len (#%vector-length nodes)])
    (let loop ([i 0] [max-level 1])
      (if (fx= i len)
          max-level
          (loop (fx+ i 1)
                (fxmax max-level
                       (core-pvector-node-level (#3%vector-ref nodes i))))))))

(define (core-build-node-tree/nodes reversed-nodes)
  (cond
   [(null? reversed-nodes) #f]
   [(null? (cdr reversed-nodes)) (car reversed-nodes)]
   [(null? (cddr reversed-nodes))
    (core-pvector-node-link2
     (cadr reversed-nodes)
     (car reversed-nodes))]
   [(null? (cdddr reversed-nodes))
    (core-pvector-node-link3
     (caddr reversed-nodes)
     (cadr reversed-nodes)
     (car reversed-nodes))]
   [else
    (let ([nodes (core-reverse-list->vector reversed-nodes)])
      (core-build-node-tree/level
       nodes
       (fx+ (core-pvector-node-vector-max-level nodes) 1)))]))

(define (core-pvector-node-ref node index)
  (let ([level (core-pvector-node-level node)])
    (if (fx= level 1)
        (if (core-pvector-node2? node)
            (if (fx= index 0)
                (core-pvector-node2-a node)
                (core-pvector-node2-b node))
            (cond
             [(fx= index 0) (core-pvector-node3-a node)]
             [(fx= index 1) (core-pvector-node3-b node)]
             [else (core-pvector-node3-c node)]))
        (if (core-pvector-node2? node)
            (let* ([a (core-pvector-node2-a node)]
                   [a-measure (core-pvector-node-measure a)])
              (if (fx< index a-measure)
                  (core-pvector-node-ref a index)
                  (core-pvector-node-ref
                   (core-pvector-node2-b node)
                   (fx- index a-measure))))
            (let* ([a (core-pvector-node3-a node)]
                   [b (core-pvector-node3-b node)]
                   [a-measure (core-pvector-node-measure a)]
                   [b-measure (core-pvector-node-measure b)]
                   [ab-measure (fx+ a-measure b-measure)])
              (cond
               [(fx< index a-measure)
                (core-pvector-node-ref a index)]
               [(fx< index ab-measure)
                (core-pvector-node-ref b (fx- index a-measure))]
               [else
                (core-pvector-node-ref
                 (core-pvector-node3-c node)
                 (fx- index ab-measure))]))))))

(define (core-next-node-count entry-count)
  (let loop ([remaining entry-count] [count 0])
    (cond
     [(fx= remaining 0) count]
     [(fx= remaining 1) (fx+ count 1)]
     [(fx= remaining 2) (fx+ count 1)]
     [(fx= remaining 3) (fx+ count 1)]
     [(fx= remaining 4) (fx+ count 2)]
     [else (loop (fx- remaining 3) (fx+ count 1))])))

(define (core-build-next-node-level entries node-level)
  (let* ([entry-count (#%vector-length entries)]
         [nodes (make-vector (core-next-node-count entry-count))])
    (let loop ([entry-index 0] [node-index 0])
      (let ([remaining (fx- entry-count entry-index)])
        (cond
         [(fx= remaining 0)
          nodes]
         [(fx= remaining 1)
          (#3%vector-set!
           nodes
           node-index
           (#3%vector-ref entries entry-index))
          nodes]
         [(fx= remaining 2)
          (#3%vector-set!
           nodes
           node-index
           (core-make-node2 node-level
                            (#3%vector-ref entries entry-index)
                            (#3%vector-ref entries (fx+ entry-index 1))))
          nodes]
         [(fx= remaining 3)
          (#3%vector-set!
           nodes
           node-index
           (core-make-node3 node-level
                            (#3%vector-ref entries entry-index)
                            (#3%vector-ref entries (fx+ entry-index 1))
                            (#3%vector-ref entries (fx+ entry-index 2))))
          nodes]
         [(fx= remaining 4)
          (#3%vector-set!
           nodes
           node-index
           (core-make-node2 node-level
                            (#3%vector-ref entries entry-index)
                            (#3%vector-ref entries (fx+ entry-index 1))))
          (#3%vector-set!
           nodes
           (fx+ node-index 1)
           (core-make-node2 node-level
                            (#3%vector-ref entries (fx+ entry-index 2))
                            (#3%vector-ref entries (fx+ entry-index 3))))
          nodes]
         [else
          (#3%vector-set!
           nodes
           node-index
           (core-make-node3 node-level
                            (#3%vector-ref entries entry-index)
                            (#3%vector-ref entries (fx+ entry-index 1))
                            (#3%vector-ref entries (fx+ entry-index 2))))
          (loop (fx+ entry-index 3) (fx+ node-index 1))])))))

(define (core-build-node-tree/reversed-level reversed-entries node-level)
  (cond
   [(null? reversed-entries) #f]
   [(null? (cdr reversed-entries)) (car reversed-entries)]
   [(null? (cddr reversed-entries))
    (core-make-node2
     node-level
     (cadr reversed-entries)
     (car reversed-entries))]
   [(null? (cdddr reversed-entries))
    (core-make-node3
     node-level
     (caddr reversed-entries)
     (cadr reversed-entries)
     (car reversed-entries))]
   [else
    (core-build-node-tree/level
     (core-reverse-list->vector reversed-entries)
     node-level)]))

(define (core-build-node-tree/level entries node-level)
  (let loop ([entries entries] [node-level node-level])
    (let ([entry-count (#%vector-length entries)])
      (cond
       [(fx= entry-count 0) #f]
       [(fx= entry-count 1) (#3%vector-ref entries 0)]
       [else
        (loop (core-build-next-node-level entries node-level)
              (fx+ node-level 1))]))))

(define (core-build-node-tree entries)
  (core-build-node-tree/level entries 1))

(define (core-pvector-full-digit->node digit)
  (make-core-pvector-node2
   4
   2
   (core-make-leaf-node2
    (#3%vector-ref digit 0)
    (#3%vector-ref digit 1))
   (core-make-leaf-node2
    (#3%vector-ref digit 2)
    (#3%vector-ref digit 3))))

(define (core-pvector-node-slice-child-piece entry entry-start start end pieces)
  (let* ([entry-measure (core-pvector-node-measure entry)]
         [entry-end (fx+ entry-start entry-measure)]
         [copy-start (fxmax start entry-start)]
         [copy-end (fxmin end entry-end)])
    (if (fx< copy-start copy-end)
        (if (and (fx= copy-start entry-start)
                 (fx= copy-end entry-end))
            (values (cons entry pieces) #f)
            (let ([slice
                   (core-pvector-node-slice/aligned
                    entry
                    (fx- copy-start entry-start)
                    (fx- copy-end entry-start))])
              (if slice
                  (values (cons slice pieces) #f)
                  (values pieces #t))))
        (values pieces #f))))

(define (core-pvector-node-slice-child-piece/continue entry entry-start start end pieces failed?)
  (if failed?
      (values pieces failed?)
      (core-pvector-node-slice-child-piece entry entry-start start end pieces)))

(define (core-pvector-node-slice-child-finish pieces failed?)
  (and (not failed?)
       (core-build-node-tree/reversed-level pieces 2)))

(define (core-pvector-node-slice/aligned node start end)
  (let ([node-measure (core-pvector-node-measure node)])
    (cond
     [(fx= start end) #f]
     [(and (fx= start 0) (fx= end node-measure)) node]
     [else
      (let ([level (core-pvector-node-level node)])
        (if (fx= level 1)
            (core-pvector-node-leaf-slice/aligned node start end)
            (if (core-pvector-node2? node)
                (let* ([a (core-pvector-node2-a node)]
                       [a-measure (core-pvector-node-measure a)])
                  (let-values ([(pieces failed?)
                                (core-pvector-node-slice-child-piece
                                 a 0 start end '())])
                    (let-values ([(pieces failed?)
                                  (core-pvector-node-slice-child-piece/continue
                                   (core-pvector-node2-b node)
                                   a-measure
                                   start
                                   end
                                   pieces
                                   failed?)])
                      (core-pvector-node-slice-child-finish pieces failed?))))
                (let* ([a (core-pvector-node3-a node)]
                       [b (core-pvector-node3-b node)]
                       [a-measure (core-pvector-node-measure a)]
                       [b-start a-measure]
                       [c-start (fx+ a-measure (core-pvector-node-measure b))])
                  (let-values ([(pieces failed?)
                                (core-pvector-node-slice-child-piece
                                 a 0 start end '())])
                    (let-values ([(pieces failed?)
                                  (core-pvector-node-slice-child-piece/continue
                                   b b-start start end pieces failed?)])
                      (let-values ([(pieces failed?)
                                    (core-pvector-node-slice-child-piece/continue
                                     (core-pvector-node3-c node)
                                     c-start
                                     start
                                     end
                                     pieces
                                     failed?)])
                        (core-pvector-node-slice-child-finish
                         pieces
                         failed?))))))))])))

(define (core-pvector-deep-edge-lengths len)
  (if (fx<= len (fx* 2 core-pvector-digit-max))
      (let ([prefix-len (fxquotient len 2)])
        (values prefix-len (fx- len prefix-len)))
      (if (fx= len (fx+ (fx* 2 core-pvector-digit-max) 1))
          (values core-pvector-digit-max (fx- core-pvector-digit-max 1))
          (values core-pvector-digit-max core-pvector-digit-max))))

(define (core-vector->large-finger vec len)
  (let-values ([(prefix-len suffix-len)
                (core-pvector-deep-edge-lengths len)])
    (let* ([suffix-start (fx- len suffix-len)]
           [middle-len (fx- suffix-start prefix-len)]
           [prefix (core-vector-copy-range/immutable vec 0 prefix-len)]
           [middle
            (if (fx= middle-len 0)
                #f
                (core-build-node-tree
                 (core-vector-copy-range
                  vec
                  prefix-len
                  suffix-start)))]
           [suffix (core-vector-copy-range/immutable vec suffix-start len)])
      (make-core-pvector-large-finger len prefix middle suffix))))

(define (core-pvector-large-finger-ref/known-length pv len index)
  (let* ([prefix (core-pvector-large-finger-prefix pv)]
         [prefix-len (#%vector-length prefix)])
    (if (fx< index prefix-len)
        (#3%vector-ref prefix index)
        (let* ([suffix (core-pvector-large-finger-suffix pv)]
               [suffix-len (#%vector-length suffix)]
               [suffix-start (fx- len suffix-len)])
          (if (fx< index suffix-start)
              (core-pvector-node-ref
               (core-pvector-large-finger-middle pv)
               (fx- index prefix-len))
              (#3%vector-ref suffix (fx- index suffix-start)))))))

(define (core-pvector-large-finger-ref/known-pieces
         prefix prefix-len middle suffix suffix-start index)
  (if (fx< index prefix-len)
      (#3%vector-ref prefix index)
      (if (fx< index suffix-start)
          (core-pvector-node-ref middle (fx- index prefix-len))
          (#3%vector-ref suffix (fx- index suffix-start)))))

(define (core-pvector-large-finger-range->immutable-vector-short/known-length
         pv len start range-len)
  (let* ([end (fx+ start range-len)]
         [prefix (core-pvector-large-finger-prefix pv)]
         [prefix-len (#%vector-length prefix)])
    (if (fx<= end prefix-len)
        (core-vector-copy-range/immutable prefix start end)
        (let* ([suffix (core-pvector-large-finger-suffix pv)]
               [suffix-len (#%vector-length suffix)]
               [suffix-start (fx- len suffix-len)])
          (if (fx>= start suffix-start)
              (core-vector-copy-range/immutable
               suffix
               (fx- start suffix-start)
               (fx- end suffix-start))
              (let ([middle (core-pvector-large-finger-middle pv)])
                (cond
                 [(fx= range-len 2)
                  (core-immutable-vector2
                   (core-pvector-large-finger-ref/known-pieces
                    prefix prefix-len middle suffix suffix-start start)
                   (core-pvector-large-finger-ref/known-pieces
                    prefix prefix-len middle suffix suffix-start (fx+ start 1)))]
                 [(fx= range-len 3)
                  (core-immutable-vector3
                   (core-pvector-large-finger-ref/known-pieces
                    prefix prefix-len middle suffix suffix-start start)
                   (core-pvector-large-finger-ref/known-pieces
                    prefix prefix-len middle suffix suffix-start (fx+ start 1))
                   (core-pvector-large-finger-ref/known-pieces
                    prefix prefix-len middle suffix suffix-start (fx+ start 2)))]
                 [else
                  (core-immutable-vector4
                   (core-pvector-large-finger-ref/known-pieces
                    prefix prefix-len middle suffix suffix-start start)
                   (core-pvector-large-finger-ref/known-pieces
                    prefix prefix-len middle suffix suffix-start (fx+ start 1))
                   (core-pvector-large-finger-ref/known-pieces
                    prefix prefix-len middle suffix suffix-start (fx+ start 2))
                   (core-pvector-large-finger-ref/known-pieces
                    prefix prefix-len middle suffix suffix-start (fx+ start 3)))])))))))

(define (core-pvector-short-copy-from-vector vec offset new-len)
  (cond
   [(fx= new-len 2)
    (core-make-deep2-pvector
     (#3%vector-ref vec offset)
     (#3%vector-ref vec (fx+ offset 1)))]
   [(fx= new-len 3)
    (core-make-deep3-pvector
     (#3%vector-ref vec offset)
     (#3%vector-ref vec (fx+ offset 1))
     (#3%vector-ref vec (fx+ offset 2)))]
   [else
    (core-make-deep4-pvector
     (#3%vector-ref vec offset)
     (#3%vector-ref vec (fx+ offset 1))
     (#3%vector-ref vec (fx+ offset 2))
     (#3%vector-ref vec (fx+ offset 3)))]))

(define (core-pvector-short-copy-from-known-pieces
         prefix prefix-len middle suffix suffix-start start new-len)
  (cond
   [(fx= new-len 2)
    (core-make-deep2-pvector
     (core-pvector-large-finger-ref/known-pieces
      prefix prefix-len middle suffix suffix-start start)
     (core-pvector-large-finger-ref/known-pieces
      prefix prefix-len middle suffix suffix-start (fx+ start 1)))]
   [(fx= new-len 3)
    (core-make-deep3-pvector
     (core-pvector-large-finger-ref/known-pieces
      prefix prefix-len middle suffix suffix-start start)
     (core-pvector-large-finger-ref/known-pieces
      prefix prefix-len middle suffix suffix-start (fx+ start 1))
     (core-pvector-large-finger-ref/known-pieces
      prefix prefix-len middle suffix suffix-start (fx+ start 2)))]
   [else
    (core-make-deep4-pvector
     (core-pvector-large-finger-ref/known-pieces
      prefix prefix-len middle suffix suffix-start start)
     (core-pvector-large-finger-ref/known-pieces
      prefix prefix-len middle suffix suffix-start (fx+ start 1))
     (core-pvector-large-finger-ref/known-pieces
      prefix prefix-len middle suffix suffix-start (fx+ start 2))
     (core-pvector-large-finger-ref/known-pieces
      prefix prefix-len middle suffix suffix-start (fx+ start 3)))]))

(define (core-pvector-large-finger-copy-short/known-length pv len start new-len)
  (let* ([end (fx+ start new-len)]
         [prefix (core-pvector-large-finger-prefix pv)]
         [prefix-len (#%vector-length prefix)])
    (if (fx<= end prefix-len)
        (core-pvector-short-copy-from-vector prefix start new-len)
        (let* ([suffix (core-pvector-large-finger-suffix pv)]
               [suffix-len (#%vector-length suffix)]
               [suffix-start (fx- len suffix-len)])
          (if (fx>= start suffix-start)
              (core-pvector-short-copy-from-vector
               suffix
               (fx- start suffix-start)
               new-len)
              (core-pvector-short-copy-from-known-pieces
               prefix
               prefix-len
               (core-pvector-large-finger-middle pv)
               suffix
               suffix-start
               start
               new-len))))))

(define (core-pvector-large-finger-edge-range->immutable-vector
         pv len prefix prefix-len suffix suffix-len middle-end start end)
  (cond
   [(fx<= end prefix-len)
    (if (and (fx= start 0) (fx= end prefix-len))
        prefix
        (core-vector-copy-range/immutable prefix start end))]
   [(fx>= start middle-end)
    (let ([suffix-start (fx- start middle-end)]
          [suffix-end (fx- end middle-end)])
      (if (and (fx= suffix-start 0) (fx= suffix-end suffix-len))
          suffix
          (core-vector-copy-range/immutable
           suffix
           suffix-start
           suffix-end)))]
   [else
    (core-pvector-range->immutable-vector/known-length pv len start end)]))

(define (core-pvector-large-finger-copy/known-length pv len start end)
  (let* ([new-len (fx- end start)]
         [middle (core-pvector-large-finger-middle pv)]
         [prefix (core-pvector-large-finger-prefix pv)]
         [suffix (core-pvector-large-finger-suffix pv)]
         [prefix-len (#%vector-length prefix)]
         [suffix-len (#%vector-length suffix)]
         [middle-start prefix-len]
         [middle-end (fx- len suffix-len)])
    (and (fx> new-len core-pvector-inline-max)
         (let ([min-prefix-len
                (fxmax 1
                       (if (fx< start middle-start)
                           (fx- middle-start start)
                           0))]
               [min-suffix-len
                (fxmax 1
                       (if (fx> end middle-end)
                           (fx- end middle-end)
                           0))])
           (let prefix-loop ([edge-prefix-len min-prefix-len])
             (and (fx<= edge-prefix-len core-pvector-digit-max)
                  (let suffix-loop ([edge-suffix-len min-suffix-len])
                    (cond
                     [(fx> edge-suffix-len core-pvector-digit-max)
                      (prefix-loop (fx+ edge-prefix-len 1))]
                     [else
                      (let ([middle-copy-start (fx+ start edge-prefix-len)]
                            [middle-copy-end (fx- end edge-suffix-len)])
                        (if (and (fx>= middle-copy-start middle-start)
                                 (fx<= middle-copy-end middle-end)
                                 (fx< middle-copy-start middle-copy-end))
                            (let ([new-middle
                                   (core-pvector-node-slice/aligned
                                    middle
                                    (fx- middle-copy-start middle-start)
                                    (fx- middle-copy-end middle-start))])
                              (if new-middle
                                  (make-core-pvector-large-finger
                                   new-len
                                   (core-pvector-large-finger-edge-range->immutable-vector
                                    pv
                                    len
                                    prefix
                                    prefix-len
                                    suffix
                                    suffix-len
                                    middle-end
                                    start
                                    middle-copy-start)
                                   new-middle
                                   (core-pvector-large-finger-edge-range->immutable-vector
                                    pv
                                    len
                                    prefix
                                    prefix-len
                                    suffix
                                    suffix-len
                                    middle-end
                                    middle-copy-end
                                    end))
                                  (suffix-loop (fx+ edge-suffix-len 1))))
                            (suffix-loop (fx+ edge-suffix-len 1))))]))))))))

(define (core-pvector-large-finger-cons-left/known-length pv len value)
  (let* ([prefix (core-pvector-large-finger-prefix pv)]
         [prefix-len (#%vector-length prefix)]
         [new-len (fx+ len 1)])
    (if (fx< prefix-len core-pvector-digit-max)
        (make-core-pvector-large-finger
         new-len
         (core-vector-insert/immutable prefix prefix-len 0 value)
         (core-pvector-large-finger-middle pv)
         (core-pvector-large-finger-suffix pv))
        (let* ([bridge (core-pvector-full-digit->node prefix)]
               [old-middle (core-pvector-large-finger-middle pv)]
               [middle (if old-middle
                           (core-pvector-node-link2 bridge old-middle)
                           bridge)])
          (make-core-pvector-large-finger
           new-len
           (core-immutable-vector1 value)
           middle
           (core-pvector-large-finger-suffix pv))))))

(define (core-pvector-large-finger-cons-left pv value)
  (core-pvector-large-finger-cons-left/known-length
   pv
   (core-pvector-large-finger-length pv)
   value))

(define (core-pvector-large-finger-cons-right/known-length pv len value)
  (let* ([suffix (core-pvector-large-finger-suffix pv)]
         [suffix-len (#%vector-length suffix)]
         [new-len (fx+ len 1)])
    (if (fx< suffix-len core-pvector-digit-max)
        (make-core-pvector-large-finger
         new-len
         (core-pvector-large-finger-prefix pv)
         (core-pvector-large-finger-middle pv)
         (core-vector-insert/immutable suffix suffix-len suffix-len value))
        (let* ([bridge (core-pvector-full-digit->node suffix)]
               [old-middle (core-pvector-large-finger-middle pv)]
               [middle (if old-middle
                           (core-pvector-node-link2 old-middle bridge)
                           bridge)])
          (make-core-pvector-large-finger
           new-len
           (core-pvector-large-finger-prefix pv)
           middle
           (core-immutable-vector1 value))))))

(define (core-pvector-large-finger-cons-right pv value)
  (core-pvector-large-finger-cons-right/known-length
   pv
   (core-pvector-large-finger-length pv)
   value))

(define (core-pvector-node-set node index value)
  (let ([level (core-pvector-node-level node)])
    (if (fx= level 1)
        (if (core-pvector-node2? node)
            (if (fx= index 0)
                (core-make-leaf-node2 value (core-pvector-node2-b node))
                (core-make-leaf-node2 (core-pvector-node2-a node) value))
            (let ([a (core-pvector-node3-a node)]
                  [b (core-pvector-node3-b node)]
                  [c (core-pvector-node3-c node)])
              (cond
               [(fx= index 0) (core-make-leaf-node3 value b c)]
               [(fx= index 1) (core-make-leaf-node3 a value c)]
               [else (core-make-leaf-node3 a b value)])))
        (if (core-pvector-node2? node)
            (let* ([a (core-pvector-node2-a node)]
                   [b (core-pvector-node2-b node)]
                   [a-measure (core-pvector-node-measure a)])
              (if (fx< index a-measure)
                  (core-make-node2
                   level
                   (core-pvector-node-set a index value)
                   b)
                  (core-make-node2 level
                                   a
                                   (core-pvector-node-set
                                    b (fx- index a-measure) value))))
            (let* ([a (core-pvector-node3-a node)]
                   [b (core-pvector-node3-b node)]
                   [c (core-pvector-node3-c node)]
                   [a-measure (core-pvector-node-measure a)]
                   [b-measure (core-pvector-node-measure b)]
                   [ab-measure (fx+ a-measure b-measure)])
              (cond
               [(fx< index a-measure)
                (core-make-node3
                 level
                 (core-pvector-node-set a index value)
                 b
                 c)]
               [(fx< index ab-measure)
                (core-make-node3 level
                                 a
                                 (core-pvector-node-set
                                  b (fx- index a-measure) value)
                                 c)]
               [else
                (core-make-node3 level
                                 a
                                 b
                                 (core-pvector-node-set
                                  c (fx- index ab-measure) value))]))))))

(define (core-pvector-large-finger-set/known-length pv len index value)
  (let* ([prefix (core-pvector-large-finger-prefix pv)]
         [prefix-len (#%vector-length prefix)])
    (if (fx< index prefix-len)
        (if (eq? (#3%vector-ref prefix index) value)
            pv
            (make-core-pvector-large-finger
             len
             (core-vector-set/immutable prefix prefix-len index value)
             (core-pvector-large-finger-middle pv)
             (core-pvector-large-finger-suffix pv)))
        (let* ([suffix (core-pvector-large-finger-suffix pv)]
               [suffix-len (#%vector-length suffix)]
               [suffix-start (fx- len suffix-len)])
          (if (fx>= index suffix-start)
              (let ([suffix-index (fx- index suffix-start)])
                (if (eq? (#3%vector-ref suffix suffix-index) value)
                    pv
                    (make-core-pvector-large-finger
                     len
                     prefix
                     (core-pvector-large-finger-middle pv)
                     (core-vector-set/immutable
                      suffix
                      suffix-len
                      suffix-index
                      value))))
              (let* ([middle (core-pvector-large-finger-middle pv)]
                     [middle-index (fx- index prefix-len)])
                (if (eq? (core-pvector-node-ref middle middle-index) value)
                    pv
                    (make-core-pvector-large-finger
                     len
                     prefix
                     (core-pvector-node-set middle middle-index value)
                     suffix))))))))

(define (core-pvector-insert-by-copy/unchecked pv len index value)
  (let ([left (core-pvector-cons-right/known-length
               (core-pvector-copy/unchecked pv len 0 index)
               index
               value)]
        [right (core-pvector-copy/unchecked pv len index len)])
    (core-pvector-append/known-length
     left
     (fx+ index 1)
     right
     (fx- len index))))

(define (core-pvector-delete-by-copy/unchecked pv len index)
  (core-pvector-append/known-length
   (core-pvector-copy/unchecked pv len 0 index)
   index
   (core-pvector-copy/unchecked pv len (fx+ index 1) len)
   (fx- len (fx+ index 1))))

(define (core-pvector-large-finger-insert/known-length pv len index value)
  (let* ([prefix (core-pvector-large-finger-prefix pv)]
         [prefix-len (#%vector-length prefix)]
         [new-len (fx+ len 1)])
    (if (and (fx<= index prefix-len)
             (fx< prefix-len core-pvector-digit-max))
        (make-core-pvector-large-finger
         new-len
         (core-vector-insert/immutable prefix prefix-len index value)
         (core-pvector-large-finger-middle pv)
         (core-pvector-large-finger-suffix pv))
        (let* ([suffix (core-pvector-large-finger-suffix pv)]
               [suffix-len (#%vector-length suffix)]
               [suffix-start (fx- len suffix-len)])
          (if (and (fx>= index suffix-start)
                   (fx< suffix-len core-pvector-digit-max))
              (make-core-pvector-large-finger
               new-len
               prefix
               (core-pvector-large-finger-middle pv)
               (core-vector-insert/immutable
                suffix
                suffix-len
                (fx- index suffix-start)
                value))
              (core-pvector-insert-by-copy/unchecked pv len index value))))))

(define (core-pvector-large-finger-delete/known-length pv len index)
  (let* ([new-len (fx- len 1)]
         [prefix (core-pvector-large-finger-prefix pv)]
         [prefix-len (#%vector-length prefix)])
    (cond
     [(fx< index prefix-len)
      (if (fx> prefix-len 1)
           (make-core-pvector-large-finger
            new-len
            (core-vector-remove/immutable prefix prefix-len index)
            (core-pvector-large-finger-middle pv)
            (core-pvector-large-finger-suffix pv))
          (core-pvector-delete-by-copy/unchecked pv len index))]
     [else
      (let* ([suffix (core-pvector-large-finger-suffix pv)]
             [suffix-len (#%vector-length suffix)]
             [suffix-start (fx- len suffix-len)])
        (if (and (fx>= index suffix-start)
                 (fx> suffix-len 1))
            (make-core-pvector-large-finger
             new-len
             prefix
             (core-pvector-large-finger-middle pv)
             (core-vector-remove/immutable
              suffix
              suffix-len
              (fx- index suffix-start)))
            (core-pvector-delete-by-copy/unchecked pv len index)))])))

(define (core-pvector-large-finger-delete-edge-view+rest/known-length pv len index)
  (let* ([new-len (fx- len 1)]
         [prefix (core-pvector-large-finger-prefix pv)]
         [prefix-len (#%vector-length prefix)])
    (cond
     [(fx< index prefix-len)
      (if (fx> prefix-len 1)
          (values
           (#3%vector-ref prefix index)
           (make-core-pvector-large-finger
            new-len
            (core-vector-remove/immutable prefix prefix-len index)
            (core-pvector-large-finger-middle pv)
            (core-pvector-large-finger-suffix pv)))
          (values #f #f))]
     [else
      (let* ([suffix (core-pvector-large-finger-suffix pv)]
             [suffix-len (#%vector-length suffix)]
             [suffix-start (fx- len suffix-len)])
        (if (and (fx>= index suffix-start)
                 (fx> suffix-len 1))
            (let ([suffix-index (fx- index suffix-start)])
              (values
               (#3%vector-ref suffix suffix-index)
               (make-core-pvector-large-finger
                new-len
                prefix
                (core-pvector-large-finger-middle pv)
                (core-vector-remove/immutable
                 suffix
                 suffix-len
                 suffix-index))))
            (values #f #f)))])))

(define (core-pvector-large-finger-split-edge/known-length pv len index)
  (let* ([prefix (core-pvector-large-finger-prefix pv)]
         [prefix-len (#%vector-length prefix)])
    (cond
     [(and (fx< index prefix-len)
           (fx< (fx+ index 1) prefix-len))
      (let ([middle (core-pvector-large-finger-middle pv)]
            [suffix (core-pvector-large-finger-suffix pv)])
        (values
         (if (fx= index 1)
             (core-make-single-pvector (#3%vector-ref prefix 0))
             (core-pvector-short-copy-from-vector prefix 0 index))
         (#3%vector-ref prefix index)
         (make-core-pvector-large-finger
          (fx- len (fx+ index 1))
          (core-vector-copy-range/immutable prefix (fx+ index 1) prefix-len)
          middle
          suffix)
         #t))]
     [else
      (let* ([suffix (core-pvector-large-finger-suffix pv)]
             [suffix-len (#%vector-length suffix)]
             [suffix-start (fx- len suffix-len)])
        (if (and (fx>= index suffix-start)
                 (fx> (fx- index suffix-start) 0))
            (let ([suffix-index (fx- index suffix-start)]
                  [middle (core-pvector-large-finger-middle pv)])
              (values
               (make-core-pvector-large-finger
                index
                prefix
                middle
                (core-vector-copy-range/immutable suffix 0 suffix-index))
               (#3%vector-ref suffix suffix-index)
               (let* ([right-offset (fx+ suffix-index 1)]
                      [right-len (fx- suffix-len right-offset)])
                 (if (fx= right-len 1)
                     (core-make-single-pvector
                      (#3%vector-ref suffix right-offset))
                     (core-pvector-short-copy-from-vector
                      suffix
                      right-offset
                      right-len)))
               #t))
            (values #f #f #f #f)))])))

(define (core-pvector-large-finger-split-at-edge/known-length pv len pos)
  (let* ([prefix (core-pvector-large-finger-prefix pv)]
         [prefix-len (#%vector-length prefix)])
    (cond
     [(and (fx> pos 1)
           (fx< pos prefix-len))
      (let ([right-len (fx- len pos)]
            [middle (core-pvector-large-finger-middle pv)]
            [suffix (core-pvector-large-finger-suffix pv)])
        (values
         (core-pvector-short-copy-from-vector prefix 0 pos)
         (if (fx<= right-len core-pvector-digit-max)
             (let* ([suffix-len (#%vector-length suffix)]
                    [suffix-start (fx- len suffix-len)])
               (core-pvector-short-copy-from-known-pieces
                prefix
                prefix-len
                middle
                suffix
                suffix-start
                pos
                right-len))
             (make-core-pvector-large-finger
              right-len
              (core-vector-copy-range/immutable prefix pos prefix-len)
              middle
              suffix))
         #t))]
     [else
      (let* ([suffix (core-pvector-large-finger-suffix pv)]
             [suffix-len (#%vector-length suffix)]
             [suffix-start (fx- len suffix-len)])
        (if (and (fx> pos suffix-start)
                 (fx< pos (fx- len 1)))
            (let* ([suffix-index (fx- pos suffix-start)]
                   [left-len pos]
                   [right-len (fx- len pos)]
                   [middle (core-pvector-large-finger-middle pv)])
              (values
               (if (fx<= left-len core-pvector-digit-max)
                   (core-pvector-short-copy-from-known-pieces
                    prefix
                    prefix-len
                    middle
                    suffix
                    suffix-start
                    0
                    left-len)
                   (make-core-pvector-large-finger
                    left-len
                    prefix
                    middle
                    (core-vector-copy-range/immutable suffix 0 suffix-index)))
               (core-pvector-short-copy-from-vector suffix suffix-index right-len)
               #t))
            (values #f #f #f)))])))

(define (core-pvector-large-finger-pop-left-rest/known-length pv len)
  (let* ([prefix (core-pvector-large-finger-prefix pv)]
         [prefix-len (#%vector-length prefix)])
    (and (fx> prefix-len 1)
         (make-core-pvector-large-finger
          (fx- len 1)
          (core-vector-remove/immutable prefix prefix-len 0)
          (core-pvector-large-finger-middle pv)
          (core-pvector-large-finger-suffix pv)))))

(define (core-pvector-large-finger-pop-left-rest/direct pv)
  (core-pvector-large-finger-pop-left-rest/known-length
   pv
   (core-pvector-large-finger-length pv)))

(define (core-pvector-large-finger-pop-left-view+rest/known-length pv len)
  (let* ([prefix (core-pvector-large-finger-prefix pv)]
         [prefix-len (#%vector-length prefix)]
         [value (#3%vector-ref prefix 0)])
    (values value
            (and (fx> prefix-len 1)
                 (make-core-pvector-large-finger
                  (fx- len 1)
                  (core-vector-remove/immutable prefix prefix-len 0)
                  (core-pvector-large-finger-middle pv)
                  (core-pvector-large-finger-suffix pv))))))

(define (core-pvector-large-finger-pop-right-rest/known-length pv len)
  (let* ([suffix (core-pvector-large-finger-suffix pv)]
         [suffix-len (#%vector-length suffix)])
    (and (fx> suffix-len 1)
         (make-core-pvector-large-finger
          (fx- len 1)
          (core-pvector-large-finger-prefix pv)
          (core-pvector-large-finger-middle pv)
          (core-vector-remove/immutable suffix suffix-len (fx- suffix-len 1))))))

(define (core-pvector-large-finger-pop-right-rest/direct pv)
  (core-pvector-large-finger-pop-right-rest/known-length
   pv
   (core-pvector-large-finger-length pv)))

(define (core-pvector-large-finger-pop-right-view+rest/known-length pv len)
  (let* ([suffix (core-pvector-large-finger-suffix pv)]
         [suffix-len (#%vector-length suffix)]
         [value (#3%vector-ref suffix (fx- suffix-len 1))])
    (values value
            (and (fx> suffix-len 1)
                 (make-core-pvector-large-finger
                  (fx- len 1)
                  (core-pvector-large-finger-prefix pv)
                  (core-pvector-large-finger-middle pv)
                  (core-vector-remove/immutable suffix suffix-len (fx- suffix-len 1)))))))

(define (core-pvector-large-finger-trim-left-edge/known-length pv len count)
  (let* ([prefix (core-pvector-large-finger-prefix pv)]
         [prefix-len (#%vector-length prefix)])
    (and (fx> count 0)
         (fx< count prefix-len)
         (make-core-pvector-large-finger
          (fx- len count)
          (core-vector-copy-range/immutable prefix count prefix-len)
          (core-pvector-large-finger-middle pv)
          (core-pvector-large-finger-suffix pv)))))

(define (core-pvector-large-finger-trim-right-edge/known-length pv len count)
  (let* ([suffix (core-pvector-large-finger-suffix pv)]
         [suffix-len (#%vector-length suffix)])
    (and (fx> count 0)
         (fx< count suffix-len)
         (make-core-pvector-large-finger
          (fx- len count)
          (core-pvector-large-finger-prefix pv)
          (core-pvector-large-finger-middle pv)
          (core-vector-copy-range/immutable suffix 0 (fx- suffix-len count))))))

(define (core-pvector-large-finger-append-right left left-len right right-len)
  (let* ([suffix (core-pvector-large-finger-suffix left)]
         [suffix-len (#%vector-length suffix)]
         [new-suffix-len (fx+ suffix-len right-len)])
    (cond
     [(fx<= new-suffix-len core-pvector-digit-max)
      (make-core-pvector-large-finger
       (fx+ left-len right-len)
       (core-pvector-large-finger-prefix left)
       (core-pvector-large-finger-middle left)
       (core-vector-insert/immutable
        suffix
        suffix-len
        suffix-len
        (core-pvector-inline-e0 right)))]
     [else
      (let* ([bridge (core-pvector-full-digit->node suffix)]
             [old-middle (core-pvector-large-finger-middle left)]
             [middle (if old-middle
                         (core-pvector-node-link2 old-middle bridge)
                         bridge)])
        (make-core-pvector-large-finger
         (fx+ left-len right-len)
         (core-pvector-large-finger-prefix left)
         middle
         (core-pvector-single->immutable-vector right)))])))

(define (core-pvector-large-finger-append-left left left-len right right-len)
  (let* ([prefix (core-pvector-large-finger-prefix right)]
         [prefix-len (#%vector-length prefix)]
         [new-prefix-len (fx+ left-len prefix-len)])
    (cond
     [(fx<= new-prefix-len core-pvector-digit-max)
      (make-core-pvector-large-finger
       (fx+ left-len right-len)
       (core-vector-insert/immutable
        prefix
        prefix-len
        0
        (core-pvector-inline-e0 left))
       (core-pvector-large-finger-middle right)
       (core-pvector-large-finger-suffix right))]
     [else
      (let* ([bridge (core-pvector-full-digit->node prefix)]
             [old-middle (core-pvector-large-finger-middle right)]
             [middle (if old-middle
                         (core-pvector-node-link2 bridge old-middle)
                         bridge)])
        (make-core-pvector-large-finger
         (fx+ left-len right-len)
         (core-pvector-single->immutable-vector left)
         middle
         (core-pvector-large-finger-suffix right)))])))

(define (core-pvector-full-digits-bridge-node left-suffix right-prefix)
  (make-core-pvector-node3
   8
   2
   (core-make-leaf-node3
    (#3%vector-ref left-suffix 0)
    (#3%vector-ref left-suffix 1)
    (#3%vector-ref left-suffix 2))
   (core-make-leaf-node3
    (#3%vector-ref left-suffix 3)
    (#3%vector-ref right-prefix 0)
    (#3%vector-ref right-prefix 1))
   (core-make-leaf-node2
    (#3%vector-ref right-prefix 2)
    (#3%vector-ref right-prefix 3))))

(define (core-pvector-digit-bridge-node left-suffix right-prefix)
  (let* ([left-len (#%vector-length left-suffix)]
         [right-len (#%vector-length right-prefix)])
    (cond
     [(and (fx= left-len core-pvector-digit-max)
           (fx= right-len core-pvector-digit-max))
      (core-pvector-full-digits-bridge-node left-suffix right-prefix)]
     [(fx= left-len 1)
      (let ([l0 (#3%vector-ref left-suffix 0)]
            [r0 (#3%vector-ref right-prefix 0)])
        (cond
         [(fx= right-len 1)
          (core-make-leaf-node2 l0 r0)]
         [(fx= right-len 2)
          (core-make-leaf-node3
           l0
           r0
           (#3%vector-ref right-prefix 1))]
         [(fx= right-len 3)
          (make-core-pvector-node2
           4
           2
           (core-make-leaf-node2 l0 r0)
           (core-make-leaf-node2
            (#3%vector-ref right-prefix 1)
            (#3%vector-ref right-prefix 2)))]
         [else
          (make-core-pvector-node2
           5
           2
           (core-make-leaf-node3
            l0
            r0
            (#3%vector-ref right-prefix 1))
           (core-make-leaf-node2
            (#3%vector-ref right-prefix 2)
            (#3%vector-ref right-prefix 3)))]))]
     [(fx= left-len 2)
      (let ([l0 (#3%vector-ref left-suffix 0)]
            [l1 (#3%vector-ref left-suffix 1)]
            [r0 (#3%vector-ref right-prefix 0)])
        (cond
         [(fx= right-len 1)
          (core-make-leaf-node3 l0 l1 r0)]
         [(fx= right-len 2)
          (make-core-pvector-node2
           4
           2
           (core-make-leaf-node2 l0 l1)
           (core-make-leaf-node2
            r0
            (#3%vector-ref right-prefix 1)))]
         [(fx= right-len 3)
          (make-core-pvector-node2
           5
           2
           (core-make-leaf-node3 l0 l1 r0)
           (core-make-leaf-node2
            (#3%vector-ref right-prefix 1)
            (#3%vector-ref right-prefix 2)))]
         [else
          (make-core-pvector-node2
           6
           2
           (core-make-leaf-node3 l0 l1 r0)
           (core-make-leaf-node3
            (#3%vector-ref right-prefix 1)
            (#3%vector-ref right-prefix 2)
            (#3%vector-ref right-prefix 3)))]))]
     [(fx= left-len 3)
      (let ([l0 (#3%vector-ref left-suffix 0)]
            [l1 (#3%vector-ref left-suffix 1)]
            [l2 (#3%vector-ref left-suffix 2)]
            [r0 (#3%vector-ref right-prefix 0)])
        (cond
         [(fx= right-len 1)
          (make-core-pvector-node2
           4
           2
           (core-make-leaf-node2 l0 l1)
           (core-make-leaf-node2 l2 r0))]
         [(fx= right-len 2)
          (make-core-pvector-node2
           5
           2
           (core-make-leaf-node3 l0 l1 l2)
           (core-make-leaf-node2
            r0
            (#3%vector-ref right-prefix 1)))]
         [(fx= right-len 3)
          (make-core-pvector-node2
           6
           2
           (core-make-leaf-node3 l0 l1 l2)
           (core-make-leaf-node3
            r0
            (#3%vector-ref right-prefix 1)
            (#3%vector-ref right-prefix 2)))]
         [else
          (make-core-pvector-node3
           7
           2
           (core-make-leaf-node3 l0 l1 l2)
           (core-make-leaf-node2
            r0
            (#3%vector-ref right-prefix 1))
           (core-make-leaf-node2
            (#3%vector-ref right-prefix 2)
            (#3%vector-ref right-prefix 3)))]))]
     [else
      (let ([l0 (#3%vector-ref left-suffix 0)]
            [l1 (#3%vector-ref left-suffix 1)]
            [l2 (#3%vector-ref left-suffix 2)]
            [l3 (#3%vector-ref left-suffix 3)]
            [r0 (#3%vector-ref right-prefix 0)])
        (cond
         [(fx= right-len 1)
          (make-core-pvector-node2
           5
           2
           (core-make-leaf-node3 l0 l1 l2)
           (core-make-leaf-node2 l3 r0))]
         [(fx= right-len 2)
          (make-core-pvector-node2
           6
           2
           (core-make-leaf-node3 l0 l1 l2)
           (core-make-leaf-node3
            l3
            r0
            (#3%vector-ref right-prefix 1)))]
         [else
          (make-core-pvector-node3
           7
           2
           (core-make-leaf-node3 l0 l1 l2)
           (core-make-leaf-node2 l3 r0)
           (core-make-leaf-node2
            (#3%vector-ref right-prefix 1)
            (#3%vector-ref right-prefix 2)))]))])))

(define (core-pvector-large-finger-append/known-length left left-len right right-len)
  (let* ([left-suffix (core-pvector-large-finger-suffix left)]
         [right-prefix (core-pvector-large-finger-prefix right)]
         [left-middle (core-pvector-large-finger-middle left)]
         [right-middle (core-pvector-large-finger-middle right)]
         [bridge (core-pvector-digit-bridge-node left-suffix right-prefix)]
         [middle (if left-middle
                     (if right-middle
                         (core-pvector-node-link3 left-middle bridge right-middle)
                         (core-pvector-node-link2 left-middle bridge))
                     (if right-middle
                         (core-pvector-node-link2 bridge right-middle)
                         bridge))])
    (make-core-pvector-large-finger
     (fx+ left-len right-len)
     (core-pvector-large-finger-prefix left)
     middle
     (core-pvector-large-finger-suffix right))))

(define (core-pvector-large-finger-append left right)
  (core-pvector-large-finger-append/known-length
   left
   (core-pvector-large-finger-length left)
   right
   (core-pvector-large-finger-length right)))

(define (core-pvector-node-count node)
  (let ([level (core-pvector-node-level node)])
    (if (fx= level 1)
        1
        (if (core-pvector-node2? node)
            (fx+ 1
                 (fx+ (core-pvector-node-count (core-pvector-node2-a node))
                      (core-pvector-node-count (core-pvector-node2-b node))))
            (fx+ 1
                 (fx+ (core-pvector-node-count (core-pvector-node3-a node))
                      (fx+ (core-pvector-node-count (core-pvector-node3-b node))
                           (core-pvector-node-count
                            (core-pvector-node3-c node)))))))))

(define (core-pvector-node2-count node)
  (let ([level (core-pvector-node-level node)])
    (if (fx= level 1)
        (if (core-pvector-node2? node) 1 0)
        (if (core-pvector-node2? node)
            (fx+ 1
                 (fx+ (core-pvector-node2-count (core-pvector-node2-a node))
                      (core-pvector-node2-count (core-pvector-node2-b node))))
            (fx+ (core-pvector-node2-count (core-pvector-node3-a node))
                 (fx+ (core-pvector-node2-count (core-pvector-node3-b node))
                      (core-pvector-node2-count
                       (core-pvector-node3-c node))))))))

(define (core-pvector-node3-count node)
  (let ([level (core-pvector-node-level node)])
    (if (fx= level 1)
        (if (core-pvector-node3? node) 1 0)
        (if (core-pvector-node2? node)
            (fx+ (core-pvector-node3-count (core-pvector-node2-a node))
                 (core-pvector-node3-count (core-pvector-node2-b node)))
            (fx+ 1
                 (fx+ (core-pvector-node3-count (core-pvector-node3-a node))
                      (fx+ (core-pvector-node3-count (core-pvector-node3-b node))
                           (core-pvector-node3-count
                            (core-pvector-node3-c node)))))))))

(define (core-vector->inline vec len)
  (make-core-pvector-inline
   len
   (if (fx< 0 len) (#3%vector-ref vec 0) #f)
   (if (fx< 1 len) (#3%vector-ref vec 1) #f)
   (if (fx< 2 len) (#3%vector-ref vec 2) #f)
   (if (fx< 3 len) (#3%vector-ref vec 3) #f)))

(define (core-make-single-pvector value)
  (make-core-pvector-inline 1 value #f #f #f))

(define (core-immutable-vector1 value)
  (inline:vector-immutable value))

(define (core-immutable-vector2 a b)
  (inline:vector-immutable a b))

(define (core-immutable-vector3 a b c)
  (inline:vector-immutable a b c))

(define (core-immutable-vector4 a b c d)
  (inline:vector-immutable a b c d))

(define (core-pvector-single->immutable-vector pv)
  (core-immutable-vector1 (core-pvector-inline-e0 pv)))

(define (core-make-deep2-pvector left-value right-value)
  (make-core-pvector-large-finger
   2
   (core-immutable-vector1 left-value)
   #f
   (core-immutable-vector1 right-value)))

(define (core-make-deep3-pvector a b c)
  (make-core-pvector-large-finger
   3
   (core-immutable-vector1 a)
   #f
   (core-immutable-vector2 b c)))

(define (core-make-deep4-pvector a b c d)
  (make-core-pvector-large-finger
   4
   (core-immutable-vector2 a b)
   #f
   (core-immutable-vector2 c d)))

(define (core-vector->pvector/no-copy immutable-vec)
  (let ([len (#%vector-length immutable-vec)])
    (cond
     [(fx= len 0)
      empty-core-pvector]
     [(fx= len 1)
      (core-make-single-pvector (#3%vector-ref immutable-vec 0))]
     [(fx= len 2)
      (core-make-deep2-pvector
       (#3%vector-ref immutable-vec 0)
       (#3%vector-ref immutable-vec 1))]
     [(fx= len 3)
      (core-make-deep3-pvector
       (#3%vector-ref immutable-vec 0)
       (#3%vector-ref immutable-vec 1)
       (#3%vector-ref immutable-vec 2))]
     [(fx= len 4)
      (core-make-deep4-pvector
       (#3%vector-ref immutable-vec 0)
       (#3%vector-ref immutable-vec 1)
       (#3%vector-ref immutable-vec 2)
       (#3%vector-ref immutable-vec 3))]
     [else
      (core-vector->large-finger immutable-vec len)])))

(define (core-immutable-vector->pvector immutable-vec)
  (core-vector->pvector/no-copy immutable-vec))

(define (core-fresh-vector->pvector vec)
  (core-vector->pvector/no-copy vec))

(define (core-vector->pvector vec)
  (core-vector->pvector/no-copy (core-vector-copy/immutable vec)))

(define (core-list->pvector lst)
  (let ([len (core-list-length lst)])
    (cond
     [(fx= len 0) empty-core-pvector]
     [(fx= len 1) (core-make-single-pvector (car lst))]
     [(fx= len 2) (core-make-deep2-pvector (car lst) (cadr lst))]
     [(fx= len 3)
      (core-make-deep3-pvector
       (car lst)
       (cadr lst)
       (car (cddr lst)))]
     [(fx= len 4)
      (core-make-deep4-pvector
       (car lst)
       (cadr lst)
       (car (cddr lst))
       (car (cdddr lst)))]
     [else
      (let ([vec (make-vector len)])
        (let loop ([lst lst] [i 0])
          (unless (null? lst)
            (#3%vector-set! vec i (car lst))
            (loop (cdr lst) (fx+ i 1))))
        (core-vector->pvector/no-copy vec))])))

(define (core-make-pvector len value)
  (cond
   [(fx= len 0)
    empty-core-pvector]
   [(fx= len 1)
    (core-make-single-pvector value)]
   [(fx= len 2)
    (core-make-deep2-pvector value value)]
   [(fx= len 3)
    (core-make-deep3-pvector value value value)]
   [(fx= len 4)
    (core-make-deep4-pvector value value value value)]
   [else
    (core-vector->pvector/no-copy (make-vector len value))]))

(define (core-pvector-inline-ref pv index)
  (cond
   [(fx= index 0) (core-pvector-inline-e0 pv)]
   [(fx= index 1) (core-pvector-inline-e1 pv)]
   [(fx= index 2) (core-pvector-inline-e2 pv)]
   [else (core-pvector-inline-e3 pv)]))

(define (core-pvector-ref/unchecked pv index)
  (cond
   [(core-pvector-inline? pv)
    (core-pvector-inline-ref pv index)]
   [(core-pvector-large-finger? pv)
    (core-pvector-large-finger-ref pv index)]
   [else
    (error 'core-pvector-ref "index out of bounds")]))

(define (core-pvector-large-finger-ref pv index)
  (core-pvector-large-finger-ref/known-length
   pv
   (core-pvector-large-finger-length pv)
   index))

(define (core-pvector-ref/unchecked/known-length pv len index)
  (cond
   [(core-pvector-inline? pv)
    (core-pvector-inline-ref pv index)]
   [(core-pvector-large-finger? pv)
    (core-pvector-large-finger-ref/known-length pv len index)]
   [else
    (error 'core-pvector-ref "index out of bounds")]))

(define (core-vector-fill-range! dest dest-offset src start end)
  (let loop ([i start] [offset dest-offset])
    (if (fx= i end)
        offset
        (begin
          (#3%vector-set! dest offset (#3%vector-ref src i))
          (loop (fx+ i 1) (fx+ offset 1))))))

(define (core-vector-map-range! dest dest-offset src start end proc)
  (let loop ([i start] [offset dest-offset])
    (if (fx= i end)
        offset
        (begin
          (#3%vector-set! dest offset (proc (#3%vector-ref src i)))
          (loop (fx+ i 1) (fx+ offset 1))))))

(define (core-vector-segment-fill-range! dest offset src start end segment-start segment-end)
  (let ([copy-start (fxmax start segment-start)]
        [copy-end (fxmin end segment-end)])
    (if (fx< copy-start copy-end)
        (core-vector-fill-range!
         dest
         offset
         src
         (fx- copy-start segment-start)
         (fx- copy-end segment-start))
        offset)))

(define (core-vector-segment-map-range! dest offset src start end segment-start segment-end proc)
  (let ([map-start (fxmax start segment-start)]
        [map-end (fxmin end segment-end)])
    (if (fx< map-start map-end)
        (core-vector-map-range!
         dest
         offset
         src
         (fx- map-start segment-start)
         (fx- map-end segment-start)
         proc)
        offset)))

(define (core-pvector-node-leaf-fill-range! dest offset node start end)
  (if (core-pvector-node2? node)
      (let ([offset (if (and (fx< start 1) (fx< 0 end))
                        (begin
                          (#3%vector-set! dest offset (core-pvector-node2-a node))
                          (fx+ offset 1))
                        offset)])
        (if (and (fx< start 2) (fx< 1 end))
            (begin
              (#3%vector-set! dest offset (core-pvector-node2-b node))
              (fx+ offset 1))
            offset))
      (let* ([offset (if (and (fx< start 1) (fx< 0 end))
                         (begin
                           (#3%vector-set! dest offset (core-pvector-node3-a node))
                           (fx+ offset 1))
                         offset)]
             [offset (if (and (fx< start 2) (fx< 1 end))
                         (begin
                           (#3%vector-set! dest offset (core-pvector-node3-b node))
                           (fx+ offset 1))
                         offset)])
        (if (and (fx< start 3) (fx< 2 end))
            (begin
              (#3%vector-set! dest offset (core-pvector-node3-c node))
              (fx+ offset 1))
            offset))))

(define (core-pvector-node-leaf-map-range! dest offset node start end proc)
  (if (core-pvector-node2? node)
      (let ([offset (if (and (fx< start 1) (fx< 0 end))
                        (begin
                          (#3%vector-set!
                           dest
                           offset
                           (proc (core-pvector-node2-a node)))
                          (fx+ offset 1))
                        offset)])
        (if (and (fx< start 2) (fx< 1 end))
            (begin
              (#3%vector-set!
               dest
               offset
               (proc (core-pvector-node2-b node)))
              (fx+ offset 1))
            offset))
      (let* ([offset (if (and (fx< start 1) (fx< 0 end))
                         (begin
                           (#3%vector-set!
                            dest
                            offset
                            (proc (core-pvector-node3-a node)))
                           (fx+ offset 1))
                         offset)]
             [offset (if (and (fx< start 2) (fx< 1 end))
                         (begin
                           (#3%vector-set!
                            dest
                            offset
                            (proc (core-pvector-node3-b node)))
                           (fx+ offset 1))
                         offset)])
        (if (and (fx< start 3) (fx< 2 end))
            (begin
              (#3%vector-set!
               dest
               offset
               (proc (core-pvector-node3-c node)))
              (fx+ offset 1))
            offset))))

(define (core-pvector-node-leaf-for-each-range node start end proc)
  (if (core-pvector-node2? node)
      (begin
        (when (and (fx< start 1) (fx< 0 end))
          (proc (core-pvector-node2-a node)))
        (when (and (fx< start 2) (fx< 1 end))
          (proc (core-pvector-node2-b node))))
      (begin
        (when (and (fx< start 1) (fx< 0 end))
          (proc (core-pvector-node3-a node)))
        (when (and (fx< start 2) (fx< 1 end))
          (proc (core-pvector-node3-b node)))
        (when (and (fx< start 3) (fx< 2 end))
          (proc (core-pvector-node3-c node))))))

(define (core-pvector-node-leaf->list-range node start end acc)
  (if (core-pvector-node2? node)
      (let* ([acc (if (and (fx< start 2) (fx< 1 end))
                      (cons (core-pvector-node2-b node) acc)
                      acc)]
             [acc (if (and (fx< start 1) (fx< 0 end))
                      (cons (core-pvector-node2-a node) acc)
                      acc)])
        acc)
      (let* ([acc (if (and (fx< start 3) (fx< 2 end))
                      (cons (core-pvector-node3-c node) acc)
                      acc)]
             [acc (if (and (fx< start 2) (fx< 1 end))
                      (cons (core-pvector-node3-b node) acc)
                      acc)]
             [acc (if (and (fx< start 1) (fx< 0 end))
                      (cons (core-pvector-node3-a node) acc)
                      acc)])
        acc)))

(define (core-pvector-node-leaf-fill-all! dest offset node)
  (if (core-pvector-node2? node)
      (begin
        (#3%vector-set! dest offset (core-pvector-node2-a node))
        (#3%vector-set! dest (fx+ offset 1) (core-pvector-node2-b node))
        (fx+ offset 2))
      (begin
        (#3%vector-set! dest offset (core-pvector-node3-a node))
        (#3%vector-set! dest (fx+ offset 1) (core-pvector-node3-b node))
        (#3%vector-set! dest (fx+ offset 2) (core-pvector-node3-c node))
        (fx+ offset 3))))

(define (core-pvector-node-leaf-map-all! dest offset node proc)
  (if (core-pvector-node2? node)
      (begin
        (#3%vector-set! dest offset (proc (core-pvector-node2-a node)))
        (#3%vector-set! dest (fx+ offset 1) (proc (core-pvector-node2-b node)))
        (fx+ offset 2))
      (begin
        (#3%vector-set! dest offset (proc (core-pvector-node3-a node)))
        (#3%vector-set! dest (fx+ offset 1) (proc (core-pvector-node3-b node)))
        (#3%vector-set! dest (fx+ offset 2) (proc (core-pvector-node3-c node)))
        (fx+ offset 3))))

(define (core-pvector-node-leaf-for-each-all node proc)
  (if (core-pvector-node2? node)
      (begin
        (proc (core-pvector-node2-a node))
        (proc (core-pvector-node2-b node)))
      (begin
        (proc (core-pvector-node3-a node))
        (proc (core-pvector-node3-b node))
        (proc (core-pvector-node3-c node)))))

(define (core-pvector-node-leaf->list-all node acc)
  (if (core-pvector-node2? node)
      (cons (core-pvector-node2-a node)
            (cons (core-pvector-node2-b node) acc))
      (cons (core-pvector-node3-a node)
            (cons (core-pvector-node3-b node)
                  (cons (core-pvector-node3-c node) acc)))))

(define (core-pvector-node-fill-all! dest offset node)
  (let ([level (core-pvector-node-level node)])
    (if (fx= level 1)
        (core-pvector-node-leaf-fill-all! dest offset node)
        (if (core-pvector-node2? node)
            (let ([offset (core-pvector-node-fill-all!
                           dest
                           offset
                           (core-pvector-node2-a node))])
              (core-pvector-node-fill-all!
               dest
               offset
               (core-pvector-node2-b node)))
            (let* ([offset (core-pvector-node-fill-all!
                            dest
                            offset
                            (core-pvector-node3-a node))]
                   [offset (core-pvector-node-fill-all!
                            dest
                            offset
                            (core-pvector-node3-b node))])
              (core-pvector-node-fill-all!
               dest
               offset
               (core-pvector-node3-c node)))))))

(define (core-pvector-node-map-all! dest offset node proc)
  (let ([level (core-pvector-node-level node)])
    (if (fx= level 1)
        (core-pvector-node-leaf-map-all! dest offset node proc)
        (if (core-pvector-node2? node)
            (let ([offset (core-pvector-node-map-all!
                           dest
                           offset
                           (core-pvector-node2-a node)
                           proc)])
              (core-pvector-node-map-all!
               dest
               offset
               (core-pvector-node2-b node)
               proc))
            (let* ([offset (core-pvector-node-map-all!
                            dest
                            offset
                            (core-pvector-node3-a node)
                            proc)]
                   [offset (core-pvector-node-map-all!
                            dest
                            offset
                            (core-pvector-node3-b node)
                            proc)])
              (core-pvector-node-map-all!
               dest
               offset
               (core-pvector-node3-c node)
               proc))))))

(define (core-pvector-node-for-each-all node proc)
  (let ([level (core-pvector-node-level node)])
    (if (fx= level 1)
        (core-pvector-node-leaf-for-each-all node proc)
        (if (core-pvector-node2? node)
            (begin
              (core-pvector-node-for-each-all (core-pvector-node2-a node) proc)
              (core-pvector-node-for-each-all (core-pvector-node2-b node) proc))
            (begin
              (core-pvector-node-for-each-all (core-pvector-node3-a node) proc)
              (core-pvector-node-for-each-all (core-pvector-node3-b node) proc)
              (core-pvector-node-for-each-all (core-pvector-node3-c node) proc))))))

(define (core-pvector-node->list-all node acc)
  (let ([level (core-pvector-node-level node)])
    (if (fx= level 1)
        (core-pvector-node-leaf->list-all node acc)
        (if (core-pvector-node2? node)
            (let ([acc (core-pvector-node->list-all
                        (core-pvector-node2-b node)
                        acc)])
              (core-pvector-node->list-all
               (core-pvector-node2-a node)
               acc))
            (let* ([acc (core-pvector-node->list-all
                         (core-pvector-node3-c node)
                         acc)]
                   [acc (core-pvector-node->list-all
                         (core-pvector-node3-b node)
                         acc)])
              (core-pvector-node->list-all
               (core-pvector-node3-a node)
               acc))))))

(define (core-pvector-node-fill-entry! dest offset entry entry-start start end)
  (let* ([entry-measure (core-pvector-node-measure entry)]
         [entry-end (fx+ entry-start entry-measure)]
         [copy-start (fxmax start entry-start)]
         [copy-end (fxmin end entry-end)])
    (if (fx< copy-start copy-end)
        (core-pvector-node-fill-range!
         dest
         offset
         entry
         (fx- copy-start entry-start)
         (fx- copy-end entry-start))
        offset)))

(define (core-pvector-node-map-entry! dest offset entry entry-start start end proc)
  (let* ([entry-measure (core-pvector-node-measure entry)]
         [entry-end (fx+ entry-start entry-measure)]
         [map-start (fxmax start entry-start)]
         [map-end (fxmin end entry-end)])
    (if (fx< map-start map-end)
        (core-pvector-node-map-range!
         dest
         offset
         entry
         (fx- map-start entry-start)
         (fx- map-end entry-start)
         proc)
        offset)))

(define (core-pvector-node-fill-range! dest dest-offset node start end)
  (if (and (fx= start 0)
           (fx= end (core-pvector-node-measure node)))
      (core-pvector-node-fill-all! dest dest-offset node)
      (let ([level (core-pvector-node-level node)])
        (if (fx= level 1)
            (core-pvector-node-leaf-fill-range! dest dest-offset node start end)
            (if (core-pvector-node2? node)
                (let* ([a (core-pvector-node2-a node)]
                       [a-measure (core-pvector-node-measure a)]
                       [offset (core-pvector-node-fill-entry!
                                dest dest-offset a 0 start end)])
                  (core-pvector-node-fill-entry!
                   dest offset (core-pvector-node2-b node) a-measure start end))
                (let* ([a (core-pvector-node3-a node)]
                       [b (core-pvector-node3-b node)]
                       [a-measure (core-pvector-node-measure a)]
                       [b-start a-measure]
                       [c-start (fx+ a-measure (core-pvector-node-measure b))]
                       [offset (core-pvector-node-fill-entry!
                                dest dest-offset a 0 start end)]
                       [offset (core-pvector-node-fill-entry!
                                dest offset b b-start start end)])
                  (core-pvector-node-fill-entry!
                   dest offset (core-pvector-node3-c node) c-start start end)))))))

(define (core-pvector-node-map-range! dest dest-offset node start end proc)
  (if (and (fx= start 0)
           (fx= end (core-pvector-node-measure node)))
      (core-pvector-node-map-all! dest dest-offset node proc)
      (let ([level (core-pvector-node-level node)])
        (if (fx= level 1)
            (core-pvector-node-leaf-map-range! dest dest-offset node start end proc)
            (if (core-pvector-node2? node)
                (let* ([a (core-pvector-node2-a node)]
                       [a-measure (core-pvector-node-measure a)]
                       [offset (core-pvector-node-map-entry!
                                dest dest-offset a 0 start end proc)])
                  (core-pvector-node-map-entry!
                   dest offset (core-pvector-node2-b node) a-measure start end proc))
                (let* ([a (core-pvector-node3-a node)]
                       [b (core-pvector-node3-b node)]
                       [a-measure (core-pvector-node-measure a)]
                       [b-start a-measure]
                       [c-start (fx+ a-measure (core-pvector-node-measure b))]
                       [offset (core-pvector-node-map-entry!
                                dest dest-offset a 0 start end proc)]
                       [offset (core-pvector-node-map-entry!
                                dest offset b b-start start end proc)])
                  (core-pvector-node-map-entry!
                   dest offset (core-pvector-node3-c node) c-start start end proc)))))))

(define (core-pvector-large-finger-fill-range!/known-length dest dest-offset pv len start end)
  (let* ([prefix (core-pvector-large-finger-prefix pv)]
         [prefix-len (#%vector-length prefix)])
    (cond
     [(fx= start end) dest-offset]
     [(fx<= end prefix-len)
      (core-vector-fill-range! dest dest-offset prefix start end)]
     [else
      (let* ([suffix (core-pvector-large-finger-suffix pv)]
             [suffix-len (#%vector-length suffix)]
             [middle-start prefix-len]
             [suffix-start (fx- len suffix-len)])
        (cond
         [(and (fx= start 0)
               (fx= end len))
          (let ([offset (core-vector-fill-range! dest dest-offset prefix 0 prefix-len)])
            (core-vector-fill-range!
             dest
             (if (fx= suffix-start prefix-len)
                 offset
                 (core-pvector-node-fill-all!
                  dest
                  offset
                  (core-pvector-large-finger-middle pv)))
             suffix
             0
             suffix-len))]
         [(fx>= start suffix-start)
          (core-vector-fill-range!
           dest
           dest-offset
           suffix
           (fx- start suffix-start)
           (fx- end suffix-start))]
         [(and (fx>= start middle-start)
               (fx<= end suffix-start))
          (core-pvector-node-fill-range!
           dest
           dest-offset
           (core-pvector-large-finger-middle pv)
           (fx- start middle-start)
           (fx- end middle-start))]
         [else
          (let* ([offset (core-vector-segment-fill-range!
                          dest
                          dest-offset
                          prefix
                          start
                          end
                          0
                          prefix-len)]
                 [copy-start (fxmax start middle-start)]
                 [copy-end (fxmin end suffix-start)]
                 [offset (if (fx< copy-start copy-end)
                             (core-pvector-node-fill-range!
                              dest
                              offset
                              (core-pvector-large-finger-middle pv)
                              (fx- copy-start middle-start)
                              (fx- copy-end middle-start))
                             offset)])
            (core-vector-segment-fill-range!
             dest
             offset
             suffix
             start
             end
             suffix-start
             len))]))])))

(define (core-pvector-large-finger-fill-range! dest dest-offset pv start end)
  (core-pvector-large-finger-fill-range!/known-length
   dest
   dest-offset
   pv
   (core-pvector-large-finger-length pv)
   start
   end))

(define (core-pvector-large-finger-map-range!/known-length dest dest-offset pv len start end proc)
  (let* ([prefix (core-pvector-large-finger-prefix pv)]
         [prefix-len (#%vector-length prefix)])
    (cond
     [(fx= start end) dest-offset]
     [(fx<= end prefix-len)
      (core-vector-map-range! dest dest-offset prefix start end proc)]
     [else
      (let* ([suffix (core-pvector-large-finger-suffix pv)]
             [suffix-len (#%vector-length suffix)]
             [middle-start prefix-len]
             [suffix-start (fx- len suffix-len)])
        (cond
         [(and (fx= start 0)
               (fx= end len))
          (let ([offset (core-vector-map-range! dest dest-offset prefix 0 prefix-len proc)])
            (core-vector-map-range!
             dest
             (if (fx= suffix-start prefix-len)
                 offset
                 (core-pvector-node-map-all!
                  dest
                  offset
                  (core-pvector-large-finger-middle pv)
                  proc))
             suffix
             0
             suffix-len
             proc))]
         [(fx>= start suffix-start)
          (core-vector-map-range!
           dest
           dest-offset
           suffix
           (fx- start suffix-start)
           (fx- end suffix-start)
           proc)]
         [(and (fx>= start middle-start)
               (fx<= end suffix-start))
          (core-pvector-node-map-range!
           dest
           dest-offset
           (core-pvector-large-finger-middle pv)
           (fx- start middle-start)
           (fx- end middle-start)
           proc)]
         [else
          (let* ([offset (core-vector-segment-map-range!
                          dest
                          dest-offset
                          prefix
                          start
                          end
                          0
                          prefix-len
                          proc)]
                 [map-start (fxmax start middle-start)]
                 [map-end (fxmin end suffix-start)]
                 [offset (if (fx< map-start map-end)
                             (core-pvector-node-map-range!
                              dest
                              offset
                              (core-pvector-large-finger-middle pv)
                              (fx- map-start middle-start)
                              (fx- map-end middle-start)
                              proc)
                             offset)])
            (core-vector-segment-map-range!
             dest
             offset
             suffix
             start
             end
             suffix-start
             len
             proc))]))])))

(define (core-pvector-large-finger-map-range! dest dest-offset pv start end proc)
  (core-pvector-large-finger-map-range!/known-length
   dest
   dest-offset
   pv
   (core-pvector-large-finger-length pv)
   start
   end
   proc))

(define (core-pvector-fill-range!/known-length vec offset pv len start end)
  (cond
   [(fx= start end)
    offset]
   [(core-pvector-inline? pv)
    (let loop ([i start] [offset offset])
      (if (fx= i end)
          offset
          (begin
            (#3%vector-set! vec offset (core-pvector-inline-ref pv i))
            (loop (fx+ i 1) (fx+ offset 1)))))]
   [(core-pvector-large-finger? pv)
    (core-pvector-large-finger-fill-range!/known-length vec offset pv len start end)]
   [else offset]))

(define (core-pvector-fill-range! vec offset pv start end)
  (cond
   [(fx= start end)
    offset]
   [(core-pvector-inline? pv)
    (let loop ([i start] [offset offset])
      (if (fx= i end)
          offset
          (begin
            (#3%vector-set! vec offset (core-pvector-inline-ref pv i))
            (loop (fx+ i 1) (fx+ offset 1)))))]
   [(core-pvector-large-finger? pv)
    (core-pvector-large-finger-fill-range! vec offset pv start end)]
   [else offset]))

(define (core-pvector-map-range!/known-length vec offset pv len start end proc)
  (cond
   [(fx= start end)
    offset]
   [(core-pvector-inline? pv)
    (let loop ([i start] [offset offset])
      (if (fx= i end)
          offset
          (begin
            (#3%vector-set! vec offset (proc (core-pvector-inline-ref pv i)))
            (loop (fx+ i 1) (fx+ offset 1)))))]
   [(core-pvector-large-finger? pv)
    (core-pvector-large-finger-map-range!/known-length vec offset pv len start end proc)]
   [else offset]))

(define (core-pvector-map-range! vec offset pv start end proc)
  (cond
   [(fx= start end)
    offset]
   [(core-pvector-inline? pv)
    (let loop ([i start] [offset offset])
      (if (fx= i end)
          offset
          (begin
            (#3%vector-set! vec offset (proc (core-pvector-inline-ref pv i)))
            (loop (fx+ i 1) (fx+ offset 1)))))]
   [(core-pvector-large-finger? pv)
    (core-pvector-large-finger-map-range! vec offset pv start end proc)]
   [else offset]))

(define (core-vector-for-each-range vec start end proc)
  (let loop ([i start])
    (unless (fx= i end)
      (proc (#3%vector-ref vec i))
      (loop (fx+ i 1)))))

(define (core-vector->list-range vec start end acc)
  (let loop ([i (fx- end 1)] [acc acc])
    (if (fx< i start)
        acc
        (loop (fx- i 1)
              (cons (#3%vector-ref vec i) acc)))))

(define (core-vector-segment-for-each-range vec start end segment-start segment-end proc)
  (let ([visit-start (fxmax start segment-start)]
        [visit-end (fxmin end segment-end)])
    (when (fx< visit-start visit-end)
      (core-vector-for-each-range
       vec
       (fx- visit-start segment-start)
       (fx- visit-end segment-start)
       proc))))

(define (core-vector-segment->list-range vec start end segment-start segment-end acc)
  (let ([copy-start (fxmax start segment-start)]
        [copy-end (fxmin end segment-end)])
    (if (fx< copy-start copy-end)
        (core-vector->list-range
         vec
         (fx- copy-start segment-start)
         (fx- copy-end segment-start)
         acc)
        acc)))

(define (core-pvector-node-for-each-entry entry entry-start start end proc)
  (let* ([entry-measure (core-pvector-node-measure entry)]
         [entry-end (fx+ entry-start entry-measure)]
         [visit-start (fxmax start entry-start)]
         [visit-end (fxmin end entry-end)])
    (when (fx< visit-start visit-end)
      (core-pvector-node-for-each-range
       entry
       (fx- visit-start entry-start)
       (fx- visit-end entry-start)
       proc))))

(define (core-pvector-node->list-entry entry entry-start start end acc)
  (let* ([entry-measure (core-pvector-node-measure entry)]
         [entry-end (fx+ entry-start entry-measure)]
         [copy-start (fxmax start entry-start)]
         [copy-end (fxmin end entry-end)])
    (if (fx< copy-start copy-end)
        (core-pvector-node->list-range
         entry
         (fx- copy-start entry-start)
         (fx- copy-end entry-start)
         acc)
        acc)))

(define (core-pvector-node-for-each-range node start end proc)
  (if (and (fx= start 0)
           (fx= end (core-pvector-node-measure node)))
      (core-pvector-node-for-each-all node proc)
      (let ([level (core-pvector-node-level node)])
        (if (fx= level 1)
            (core-pvector-node-leaf-for-each-range node start end proc)
            (if (core-pvector-node2? node)
                (let* ([a (core-pvector-node2-a node)]
                       [a-measure (core-pvector-node-measure a)])
                  (core-pvector-node-for-each-entry a 0 start end proc)
                  (core-pvector-node-for-each-entry
                   (core-pvector-node2-b node) a-measure start end proc))
                (let* ([a (core-pvector-node3-a node)]
                       [b (core-pvector-node3-b node)]
                       [a-measure (core-pvector-node-measure a)]
                       [b-start a-measure]
                       [c-start (fx+ a-measure (core-pvector-node-measure b))])
                  (core-pvector-node-for-each-entry a 0 start end proc)
                  (core-pvector-node-for-each-entry b b-start start end proc)
                  (core-pvector-node-for-each-entry
                   (core-pvector-node3-c node) c-start start end proc)))))))

(define (core-pvector-node->list-range node start end acc)
  (if (and (fx= start 0)
           (fx= end (core-pvector-node-measure node)))
      (core-pvector-node->list-all node acc)
      (let ([level (core-pvector-node-level node)])
        (if (fx= level 1)
            (core-pvector-node-leaf->list-range node start end acc)
            (if (core-pvector-node2? node)
                (let* ([a (core-pvector-node2-a node)]
                       [a-measure (core-pvector-node-measure a)]
                       [acc (core-pvector-node->list-entry
                             (core-pvector-node2-b node) a-measure start end acc)])
                  (core-pvector-node->list-entry a 0 start end acc))
                (let* ([a (core-pvector-node3-a node)]
                       [b (core-pvector-node3-b node)]
                       [a-measure (core-pvector-node-measure a)]
                       [b-start a-measure]
                       [c-start (fx+ a-measure (core-pvector-node-measure b))]
                       [acc (core-pvector-node->list-entry
                             (core-pvector-node3-c node) c-start start end acc)]
                       [acc (core-pvector-node->list-entry
                             b b-start start end acc)])
                  (core-pvector-node->list-entry a 0 start end acc)))))))

(define (core-pvector-large-finger-for-each-range/known-length pv len start end proc)
  (let* ([prefix (core-pvector-large-finger-prefix pv)]
         [prefix-len (#%vector-length prefix)])
    (cond
     [(fx= start end) (void)]
     [(fx<= end prefix-len)
      (core-vector-for-each-range prefix start end proc)]
     [else
      (let* ([suffix (core-pvector-large-finger-suffix pv)]
             [suffix-len (#%vector-length suffix)]
             [middle-start prefix-len]
             [suffix-start (fx- len suffix-len)])
        (cond
         [(and (fx= start 0)
               (fx= end len))
          (core-vector-for-each-range prefix 0 prefix-len proc)
          (unless (fx= suffix-start prefix-len)
            (core-pvector-node-for-each-all
             (core-pvector-large-finger-middle pv)
             proc))
          (core-vector-for-each-range suffix 0 suffix-len proc)]
         [(fx>= start suffix-start)
          (core-vector-for-each-range
           suffix
           (fx- start suffix-start)
           (fx- end suffix-start)
           proc)]
         [(and (fx>= start middle-start)
               (fx<= end suffix-start))
          (core-pvector-node-for-each-range
           (core-pvector-large-finger-middle pv)
           (fx- start middle-start)
           (fx- end middle-start)
           proc)]
         [else
          (core-vector-segment-for-each-range prefix start end 0 prefix-len proc)
          (let ([visit-start (fxmax start middle-start)]
                [visit-end (fxmin end suffix-start)])
            (when (fx< visit-start visit-end)
              (core-pvector-node-for-each-range
               (core-pvector-large-finger-middle pv)
               (fx- visit-start middle-start)
               (fx- visit-end middle-start)
               proc)))
          (core-vector-segment-for-each-range
           suffix
           start
           end
           suffix-start
           len
           proc)]))])))

(define (core-pvector-large-finger-for-each-range pv start end proc)
  (core-pvector-large-finger-for-each-range/known-length
   pv
   (core-pvector-large-finger-length pv)
   start
   end
   proc))

(define (core-pvector-large-finger->list-range/known-length pv len start end acc)
  (let* ([prefix (core-pvector-large-finger-prefix pv)]
         [prefix-len (#%vector-length prefix)])
    (cond
     [(fx= start end) acc]
     [(fx<= end prefix-len)
      (core-vector->list-range prefix start end acc)]
     [else
      (let* ([suffix (core-pvector-large-finger-suffix pv)]
             [suffix-len (#%vector-length suffix)]
             [middle-start prefix-len]
             [suffix-start (fx- len suffix-len)])
        (cond
         [(and (fx= start 0)
               (fx= end len))
          (core-vector->list-range
           prefix
           0
           prefix-len
           (let ([acc (core-vector->list-range suffix 0 suffix-len acc)])
             (if (fx= suffix-start prefix-len)
                 acc
                 (core-pvector-node->list-all
                  (core-pvector-large-finger-middle pv)
                  acc))))]
         [(fx>= start suffix-start)
          (core-vector->list-range
           suffix
           (fx- start suffix-start)
           (fx- end suffix-start)
           acc)]
         [(and (fx>= start middle-start)
               (fx<= end suffix-start))
          (core-pvector-node->list-range
           (core-pvector-large-finger-middle pv)
           (fx- start middle-start)
           (fx- end middle-start)
           acc)]
         [else
          (let* ([acc (core-vector-segment->list-range
                       suffix
                       start
                       end
                       suffix-start
                       len
                       acc)]
                 [copy-start (fxmax start middle-start)]
                 [copy-end (fxmin end suffix-start)]
                 [acc (if (fx< copy-start copy-end)
                          (core-pvector-node->list-range
                           (core-pvector-large-finger-middle pv)
                           (fx- copy-start middle-start)
                           (fx- copy-end middle-start)
                           acc)
                          acc)])
            (core-vector-segment->list-range prefix start end 0 prefix-len acc))]))])))

(define (core-pvector-large-finger->list-range pv start end acc)
  (core-pvector-large-finger->list-range/known-length
   pv
   (core-pvector-large-finger-length pv)
   start
   end
   acc))

(define (core-pvector-for-each-range/known-length pv len start end proc)
  (cond
   [(fx= start end) (void)]
   [(core-pvector-inline? pv)
    (let loop ([i start])
      (unless (fx= i end)
        (proc (core-pvector-inline-ref pv i))
        (loop (fx+ i 1))))]
   [(core-pvector-large-finger? pv)
    (core-pvector-large-finger-for-each-range/known-length pv len start end proc)]
   [else (void)]))

(define (core-pvector-for-each-range pv start end proc)
  (cond
   [(fx= start end) (void)]
   [(core-pvector-inline? pv)
    (let loop ([i start])
      (unless (fx= i end)
        (proc (core-pvector-inline-ref pv i))
        (loop (fx+ i 1))))]
   [(core-pvector-large-finger? pv)
    (core-pvector-large-finger-for-each-range pv start end proc)]
   [else (void)]))

(define (core-pvector->list-range/known-length pv len start end acc)
  (cond
   [(fx= start end) acc]
   [(core-pvector-inline? pv)
    (let loop ([i (fx- end 1)] [acc acc])
      (if (fx< i start)
          acc
          (loop (fx- i 1)
                (cons (core-pvector-inline-ref pv i) acc))))]
   [(core-pvector-large-finger? pv)
    (core-pvector-large-finger->list-range/known-length pv len start end acc)]
   [else acc]))

(define (core-pvector->list-range pv start end acc)
  (cond
   [(fx= start end) acc]
   [(core-pvector-inline? pv)
    (let loop ([i (fx- end 1)] [acc acc])
      (if (fx< i start)
          acc
          (loop (fx- i 1)
                (cons (core-pvector-inline-ref pv i) acc))))]
   [(core-pvector-large-finger? pv)
    (core-pvector-large-finger->list-range pv start end acc)]
   [else acc]))

(define (core-check-index who pv index)
  (let ([len (core-pvector-length pv)])
    (unless (and (fixnum? index)
                 (fx>= index 0)
                 (fx< index len))
      (error who "index out of bounds"))
    len))

(define (core-check-end-index who pv index)
  (let ([len (core-pvector-length pv)])
    (core-check-end-index/known-length who index len)
    len))

(define (core-check-end-index/known-length who index len)
  (unless (and (fixnum? index)
               (fx>= index 0)
               (fx<= index len))
    (error who "index out of bounds")))

(define (core-pvector-ref pv index)
  (let ([len (core-check-index 'core-pvector-ref pv index)])
    (core-pvector-ref-edge/unchecked pv len index)))

(define (core-pvector-view-left pv)
  (cond
   [(core-pvector-inline? pv)
    (core-pvector-inline-e0 pv)]
   [(core-pvector-large-finger? pv)
    (#3%vector-ref (core-pvector-large-finger-prefix pv) 0)]
   [else
    (error 'core-pvector-view-left "empty pvector")]))

(define (core-pvector-view-right pv)
  (cond
   [(core-pvector-inline? pv)
    (core-pvector-inline-e0 pv)]
   [(core-pvector-large-finger? pv)
    (let ([suffix (core-pvector-large-finger-suffix pv)])
      (#3%vector-ref suffix (fx- (#%vector-length suffix) 1)))]
   [else
    (error 'core-pvector-view-right "empty pvector")]))

(define (core-pvector-ref-edge/unchecked pv len index)
  (cond
   [(fx= index 0) (core-pvector-view-left pv)]
   [(fx= index (fx- len 1)) (core-pvector-view-right pv)]
   [else (core-pvector-ref/unchecked/known-length pv len index)]))

(define (core-pvector-ref-start-edge/unchecked pv len index)
  (if (fx= index 0)
      (core-pvector-view-left pv)
      (core-pvector-ref/unchecked/known-length pv len index)))

(define (core-pvector-ref-end-edge/unchecked pv len index)
  (if (fx= index (fx- len 1))
      (core-pvector-view-right pv)
      (core-pvector-ref/unchecked/known-length pv len index)))

(define (core-pvector-fill-vector! vec offset pv)
  (let ([len (core-pvector-length pv)])
    (core-pvector-fill-range!/known-length vec offset pv len 0 len)))

(define (core-pvector->vector pv)
  (let ([len (core-pvector-length pv)])
    (cond
     [(fx= len 0)
      (make-vector 0)]
     [(fx= len 1)
      (vector (core-pvector-view-left pv))]
     [(fx= len 2)
      (let ([prefix (core-pvector-large-finger-prefix pv)]
            [suffix (core-pvector-large-finger-suffix pv)])
        (vector
         (#3%vector-ref prefix 0)
         (#3%vector-ref suffix 0)))]
     [(fx= len 3)
      (let* ([prefix (core-pvector-large-finger-prefix pv)]
             [suffix (core-pvector-large-finger-suffix pv)]
             [prefix-len (#%vector-length prefix)])
        (if (fx= prefix-len 1)
            (vector
             (#3%vector-ref prefix 0)
             (#3%vector-ref suffix 0)
             (#3%vector-ref suffix 1))
            (vector
             (#3%vector-ref prefix 0)
             (#3%vector-ref prefix 1)
             (#3%vector-ref suffix 0))))]
     [(fx= len 4)
      (let* ([prefix (core-pvector-large-finger-prefix pv)]
             [middle (core-pvector-large-finger-middle pv)]
             [suffix (core-pvector-large-finger-suffix pv)]
             [prefix-len (#%vector-length prefix)])
        (if middle
            (vector
             (#3%vector-ref prefix 0)
             (core-pvector-node2-a middle)
             (core-pvector-node2-b middle)
             (#3%vector-ref suffix 0))
            (cond
             [(fx= prefix-len 1)
              (vector
               (#3%vector-ref prefix 0)
               (#3%vector-ref suffix 0)
               (#3%vector-ref suffix 1)
               (#3%vector-ref suffix 2))]
             [(fx= prefix-len 2)
              (vector
               (#3%vector-ref prefix 0)
               (#3%vector-ref prefix 1)
               (#3%vector-ref suffix 0)
               (#3%vector-ref suffix 1))]
             [else
              (vector
               (#3%vector-ref prefix 0)
               (#3%vector-ref prefix 1)
               (#3%vector-ref prefix 2)
               (#3%vector-ref suffix 0))])))]
     [else
      (let ([vec (make-vector len)])
        (core-pvector-fill-range!/known-length vec 0 pv len 0 len)
        vec)])))

(define (core-pvector-set pv index value)
  (let ([len (core-check-index 'core-pvector-set pv index)])
    (cond
     [(fx= len 1)
      (let ([current (core-pvector-view-left pv)])
        (if (eq? current value)
            pv
            (core-make-single-pvector value)))]
     [(fx= len 2)
      (let* ([prefix (core-pvector-large-finger-prefix pv)]
             [suffix (core-pvector-large-finger-suffix pv)]
             [left (#3%vector-ref prefix 0)]
             [right (#3%vector-ref suffix 0)])
        (if (fx= index 0)
            (if (eq? left value)
                pv
                (core-make-deep2-pvector value right))
            (if (eq? right value)
                pv
                (core-make-deep2-pvector left value))))]
     [(core-pvector-large-finger? pv)
      (core-pvector-large-finger-set/known-length pv len index value)]
     [(eq? (core-pvector-ref-edge/unchecked pv len index) value)
      pv]
     [(core-pvector-inline? pv)
      (core-make-single-pvector value)]
     [else
      (let ([vec (core-pvector->vector pv)])
        (#3%vector-set! vec index value)
        (core-vector->pvector/no-copy vec))])))

(define (core-pvector-cons-left pv value)
  (cond
   [(core-pvector-empty-record? pv)
    (core-make-single-pvector value)]
   [(core-pvector-inline? pv)
    (core-make-deep2-pvector value (core-pvector-inline-e0 pv))]
   [else
    (core-pvector-large-finger-cons-left pv value)]))

(define (core-pvector-cons-left/known-length pv len value)
  (cond
   [(fx= len 0)
    (core-make-single-pvector value)]
   [(core-pvector-inline? pv)
    (core-make-deep2-pvector value (core-pvector-inline-e0 pv))]
   [else
    (core-pvector-large-finger-cons-left/known-length pv len value)]))

(define (core-pvector-cons-right pv value)
  (cond
   [(core-pvector-empty-record? pv)
    (core-make-single-pvector value)]
   [(core-pvector-inline? pv)
    (core-make-deep2-pvector (core-pvector-inline-e0 pv) value)]
   [else
    (core-pvector-large-finger-cons-right pv value)]))

(define (core-pvector-cons-right/known-length pv len value)
  (cond
   [(fx= len 0)
    (core-make-single-pvector value)]
   [(core-pvector-inline? pv)
    (core-make-deep2-pvector (core-pvector-inline-e0 pv) value)]
   [else
    (core-pvector-large-finger-cons-right/known-length pv len value)]))

(define (core-pvector-pop-left pv)
  (let ([len (core-check-index 'core-pvector-pop-left pv 0)])
    (cond
     [(fx= len 1)
      (values (core-pvector-view-left pv) empty-core-pvector)]
     [(fx= len 2)
      (values (core-pvector-view-left pv)
              (core-make-single-pvector (core-pvector-view-right pv)))]
     [(core-pvector-large-finger? pv)
      (let-values ([(value direct)
                    (core-pvector-large-finger-pop-left-view+rest/known-length
                     pv
                     len)])
        (values value
                (or direct
                    (core-pvector-copy/unchecked pv len 1 len))))]
     [else
      (values (core-pvector-view-left pv)
              (core-pvector-copy/unchecked pv len 1 len))])))

(define (core-pvector-pop-right pv)
  (let ([len (core-pvector-length pv)])
    (when (fx= len 0)
      (error 'core-pvector-pop-right "empty pvector"))
    (cond
     [(fx= len 1)
      (values (core-pvector-view-right pv) empty-core-pvector)]
     [(fx= len 2)
      (values (core-pvector-view-right pv)
              (core-make-single-pvector (core-pvector-view-left pv)))]
     [(core-pvector-large-finger? pv)
      (let-values ([(value direct)
                    (core-pvector-large-finger-pop-right-view+rest/known-length
                     pv
                     len)])
        (values value
                (or direct
                    (core-pvector-copy/unchecked pv len 0 (fx- len 1)))))]
     [else
      (values (core-pvector-view-right pv)
              (core-pvector-copy/unchecked pv len 0 (fx- len 1)))])))

(define (core-pvector-small-append left right)
  (core-make-deep2-pvector
   (core-pvector-inline-e0 left)
   (core-pvector-inline-e0 right)))

(define (core-pvector-append/known-length left left-len right right-len)
  (cond
   [(fx= left-len 0) right]
   [(fx= right-len 0) left]
   [(and (core-pvector-large-finger? left)
         (core-pvector-large-finger? right))
    (core-pvector-large-finger-append/known-length
     left left-len right right-len)]
   [(core-pvector-large-finger? left)
    (core-pvector-large-finger-append-right left left-len right right-len)]
   [(core-pvector-large-finger? right)
    (core-pvector-large-finger-append-left left left-len right right-len)]
   [else
    (core-pvector-small-append left right)]))

(define (core-pvector-append left right)
  (core-pvector-append/known-length
   left
   (core-pvector-length left)
   right
   (core-pvector-length right)))

(define (core-pvector-copy/unchecked pv len start end)
  (cond
   [(fx= start end) empty-core-pvector]
   [(and (fx= start 0) (fx= end len)) pv]
   [else
    (let ([new-len (fx- end start)])
      (cond
       [(fx= new-len 1)
        (core-make-single-pvector
         (core-pvector-ref-edge/unchecked pv len start))]
       [(fx= new-len 2)
        (if (core-pvector-large-finger? pv)
            (core-pvector-large-finger-copy-short/known-length
             pv len start new-len)
            (core-make-deep2-pvector
             (core-pvector-ref-start-edge/unchecked pv len start)
             (core-pvector-ref-end-edge/unchecked pv len (fx+ start 1))))]
       [(fx= new-len 3)
        (if (core-pvector-large-finger? pv)
            (core-pvector-large-finger-copy-short/known-length
             pv len start new-len)
            (core-make-deep3-pvector
             (core-pvector-ref-start-edge/unchecked pv len start)
             (core-pvector-ref/unchecked/known-length pv len (fx+ start 1))
             (core-pvector-ref-end-edge/unchecked pv len (fx+ start 2))))]
       [(fx= new-len 4)
        (if (core-pvector-large-finger? pv)
            (core-pvector-large-finger-copy-short/known-length
             pv len start new-len)
            (core-make-deep4-pvector
             (core-pvector-ref-start-edge/unchecked pv len start)
             (core-pvector-ref/unchecked/known-length pv len (fx+ start 1))
             (core-pvector-ref/unchecked/known-length pv len (fx+ start 2))
             (core-pvector-ref-end-edge/unchecked pv len (fx+ start 3))))]
	       [else
	        (let ([direct (if (core-pvector-large-finger? pv)
	                          (or (and (fx= end len)
	                                   (core-pvector-large-finger-trim-left-edge/known-length
	                                    pv
	                                    len
	                                    start))
	                              (and (fx= start 0)
	                                   (core-pvector-large-finger-trim-right-edge/known-length
	                                    pv
	                                    len
	                                    (fx- len end)))
	                              (core-pvector-large-finger-copy/known-length
	                               pv
	                               len
	                               start
                               end))
                          #f)])
          (if direct
              direct
              (let ([vec (make-vector new-len)])
                (core-pvector-fill-range!/known-length vec 0 pv len start end)
                (core-vector->pvector/no-copy vec))))]))]))

(define (core-pvector-copy pv start end)
  (let ([len (core-pvector-length pv)])
    (core-check-end-index/known-length 'core-pvector-copy start len)
    (core-check-end-index/known-length 'core-pvector-copy end len)
    (when (fx> start end)
      (error 'core-pvector-copy "starting index is greater than ending index"))
    (core-pvector-copy/unchecked pv len start end)))

(define (core-pvector-split-at-left-edge/known-length pv len)
  (if (core-pvector-large-finger? pv)
      (let-values ([(value direct)
                    (core-pvector-large-finger-pop-left-view+rest/known-length
                     pv
                     len)])
        (values (core-make-single-pvector value)
                (or direct
                    (core-pvector-copy/unchecked pv len 1 len))))
      (values (core-make-single-pvector (core-pvector-view-left pv))
              (core-pvector-copy/unchecked pv len 1 len))))

(define (core-pvector-split-at-right-edge/known-length pv len)
  (if (core-pvector-large-finger? pv)
      (let-values ([(value direct)
                    (core-pvector-large-finger-pop-right-view+rest/known-length
                     pv
                     len)])
        (values (or direct
                    (core-pvector-copy/unchecked pv len 0 (fx- len 1)))
                (core-make-single-pvector value)))
      (values (core-pvector-copy/unchecked pv len 0 (fx- len 1))
              (core-make-single-pvector (core-pvector-view-right pv)))))

(define (core-pvector-take pv pos)
  (let ([len (core-check-end-index 'core-pvector-take pv pos)])
    (cond
     [(fx= pos 0) empty-core-pvector]
     [(fx= pos len) pv]
     [else (core-pvector-copy/unchecked pv len 0 pos)])))

(define (core-pvector-drop pv pos)
  (let ([len (core-check-end-index 'core-pvector-drop pv pos)])
    (cond
     [(fx= pos 0) pv]
     [(fx= pos len) empty-core-pvector]
     [else (core-pvector-copy/unchecked pv len pos len)])))

(define (core-pvector-take-right pv pos)
  (let ([len (core-check-end-index 'core-pvector-take-right pv pos)])
    (cond
     [(fx= pos 0) empty-core-pvector]
     [(fx= pos len) pv]
     [else (core-pvector-copy/unchecked pv len (fx- len pos) len)])))

(define (core-pvector-drop-right pv pos)
  (let ([len (core-check-end-index 'core-pvector-drop-right pv pos)])
    (cond
     [(fx= pos 0) pv]
     [(fx= pos len) empty-core-pvector]
     [else (core-pvector-copy/unchecked pv len 0 (fx- len pos))])))

(define (core-pvector-split-at pv pos)
  (let ([len (core-check-end-index 'core-pvector-split-at pv pos)])
    (cond
     [(fx= pos 0)
      (values empty-core-pvector pv)]
     [(fx= pos len)
      (values pv empty-core-pvector)]
     [(fx= pos 1)
      (core-pvector-split-at-left-edge/known-length pv len)]
     [(fx= pos (fx- len 1))
      (core-pvector-split-at-right-edge/known-length pv len)]
     [else
      (if (core-pvector-large-finger? pv)
          (let-values ([(left right direct?)
                        (core-pvector-large-finger-split-at-edge/known-length
                         pv
                         len
                         pos)])
            (if direct?
                (values left right)
                (values (core-pvector-copy/unchecked pv len 0 pos)
                        (core-pvector-copy/unchecked pv len pos len))))
          (values (core-pvector-copy/unchecked pv len 0 pos)
                  (core-pvector-copy/unchecked pv len pos len)))])))

(define (core-pvector-split-at-right pv pos)
  (let ([len (core-check-end-index 'core-pvector-split-at-right pv pos)])
    (cond
     [(fx= pos 0)
      (values empty-core-pvector pv)]
     [(fx= pos len)
      (values pv empty-core-pvector)]
     [(fx= pos 1)
      (let-values ([(left right)
                    (core-pvector-split-at-right-edge/known-length pv len)])
        (values right left))]
     [(fx= pos (fx- len 1))
      (let-values ([(left right)
                    (core-pvector-split-at-left-edge/known-length pv len)])
        (values right left))]
     [else
      (let ([split-pos (fx- len pos)])
        (if (core-pvector-large-finger? pv)
            (let-values ([(left right direct?)
                          (core-pvector-large-finger-split-at-edge/known-length
                           pv
                           len
                           split-pos)])
              (if direct?
                  (values right left)
                  (values (core-pvector-copy/unchecked pv len split-pos len)
                          (core-pvector-copy/unchecked pv len 0 split-pos))))
            (values (core-pvector-copy/unchecked pv len split-pos len)
                    (core-pvector-copy/unchecked pv len 0 split-pos))))])))

(define (core-pvector-split pv index)
  (let ([len (core-check-index 'core-pvector-split pv index)])
    (cond
     [(fx= index 0)
      (if (core-pvector-large-finger? pv)
          (let-values ([(value direct)
                        (core-pvector-large-finger-pop-left-view+rest/known-length
                         pv
                         len)])
            (values empty-core-pvector
                    value
                    (or direct
                        (core-pvector-copy/unchecked pv len 1 len))))
          (values empty-core-pvector
                  (core-pvector-view-left pv)
                  (core-pvector-copy/unchecked pv len 1 len)))]
     [(fx= index (fx- len 1))
      (if (core-pvector-large-finger? pv)
          (let-values ([(value direct)
                        (core-pvector-large-finger-pop-right-view+rest/known-length
                         pv
                         len)])
            (values (or direct
                        (core-pvector-copy/unchecked pv len 0 index))
                    value
                    empty-core-pvector))
          (values (core-pvector-copy/unchecked pv len 0 index)
                  (core-pvector-view-right pv)
                  empty-core-pvector))]
     [else
      (if (core-pvector-large-finger? pv)
          (let-values ([(left value right direct?)
                        (core-pvector-large-finger-split-edge/known-length
                         pv
                         len
                         index)])
            (if direct?
                (values left value right)
                (values (core-pvector-copy/unchecked pv len 0 index)
                        (core-pvector-ref/unchecked/known-length pv len index)
                        (core-pvector-copy/unchecked pv len (fx+ index 1) len))))
          (values (core-pvector-copy/unchecked pv len 0 index)
                  (core-pvector-ref/unchecked/known-length pv len index)
                  (core-pvector-copy/unchecked pv len (fx+ index 1) len)))])))

(define (core-pvector-insert pv index value)
  (let ([len (core-check-end-index 'core-pvector-insert pv index)])
    (cond
     [(fx= index 0) (core-pvector-cons-left/known-length pv len value)]
     [(fx= index len) (core-pvector-cons-right/known-length pv len value)]
     [else
      (core-pvector-large-finger-insert/known-length pv len index value)])))

(define (core-pvector-delete pv index)
  (let ([len (core-check-index 'core-pvector-delete pv index)])
    (cond
     [(fx= len 1)
      (values empty-core-pvector (core-pvector-view-left pv))]
     [(fx= len 2)
      (if (fx= index 0)
          (values (core-make-single-pvector (core-pvector-view-right pv))
                  (core-pvector-view-left pv))
          (values (core-make-single-pvector (core-pvector-view-left pv))
                  (core-pvector-view-right pv)))]
     [(fx= index 0)
      (let-values ([(deleted direct)
                    (core-pvector-large-finger-pop-left-view+rest/known-length
                     pv
                     len)])
        (values (or direct
                    (core-pvector-copy/unchecked pv len 1 len))
                deleted))]
     [(fx= index (fx- len 1))
      (let-values ([(deleted direct)
                    (core-pvector-large-finger-pop-right-view+rest/known-length
                     pv
                     len)])
       (values (or direct
                    (core-pvector-copy/unchecked pv len 0 index))
                deleted))]
     [else
      (let-values ([(deleted direct)
                    (core-pvector-large-finger-delete-edge-view+rest/known-length
                     pv
                     len
                     index)])
	        (if direct
	            (values direct deleted)
	            (let ([deleted (core-pvector-ref/unchecked/known-length pv len index)])
	              (values
	               (core-pvector-delete-by-copy/unchecked pv len index)
	               deleted))))])))

(define (core-pvector-map pv proc)
  (let ([len (core-pvector-length pv)])
    (cond
     [(fx= len 0) empty-core-pvector]
     [(eq? proc values) pv]
     [(eq? proc void) (core-make-pvector len (void))]
     [(fx= len 1)
      (core-make-single-pvector
       (proc (core-pvector-view-left pv)))]
     [(fx= len 2)
      (let ([prefix (core-pvector-large-finger-prefix pv)]
            [suffix (core-pvector-large-finger-suffix pv)])
        (core-make-deep2-pvector
         (proc (#3%vector-ref prefix 0))
         (proc (#3%vector-ref suffix 0))))]
     [(fx= len 3)
      (let* ([prefix (core-pvector-large-finger-prefix pv)]
             [suffix (core-pvector-large-finger-suffix pv)]
             [prefix-len (#%vector-length prefix)])
        (if (fx= prefix-len 1)
            (core-make-deep3-pvector
             (proc (#3%vector-ref prefix 0))
             (proc (#3%vector-ref suffix 0))
             (proc (#3%vector-ref suffix 1)))
            (core-make-deep3-pvector
             (proc (#3%vector-ref prefix 0))
             (proc (#3%vector-ref prefix 1))
             (proc (#3%vector-ref suffix 0)))))]
     [(fx= len 4)
      (let* ([prefix (core-pvector-large-finger-prefix pv)]
             [middle (core-pvector-large-finger-middle pv)]
             [suffix (core-pvector-large-finger-suffix pv)]
             [prefix-len (#%vector-length prefix)])
        (if middle
            (core-make-deep4-pvector
             (proc (#3%vector-ref prefix 0))
             (proc (core-pvector-node2-a middle))
             (proc (core-pvector-node2-b middle))
             (proc (#3%vector-ref suffix 0)))
            (cond
             [(fx= prefix-len 1)
              (core-make-deep4-pvector
               (proc (#3%vector-ref prefix 0))
               (proc (#3%vector-ref suffix 0))
               (proc (#3%vector-ref suffix 1))
               (proc (#3%vector-ref suffix 2)))]
             [(fx= prefix-len 2)
              (core-make-deep4-pvector
               (proc (#3%vector-ref prefix 0))
               (proc (#3%vector-ref prefix 1))
               (proc (#3%vector-ref suffix 0))
               (proc (#3%vector-ref suffix 1)))]
             [else
              (core-make-deep4-pvector
               (proc (#3%vector-ref prefix 0))
               (proc (#3%vector-ref prefix 1))
               (proc (#3%vector-ref prefix 2))
               (proc (#3%vector-ref suffix 0)))])))]
     [else
      (let ([vec (make-vector len)])
        (core-pvector-map-range!/known-length vec 0 pv len 0 len proc)
        (core-vector->pvector/no-copy vec))])))

(define (core-pvector-for-each pv proc)
  (unless (or (eq? proc values) (eq? proc void))
    (let ([len (core-pvector-length pv)])
      (cond
       [(fx= len 0) (void)]
       [(fx= len 1)
        (proc (core-pvector-view-left pv))]
       [(fx= len 2)
        (let ([prefix (core-pvector-large-finger-prefix pv)]
              [suffix (core-pvector-large-finger-suffix pv)])
          (proc (#3%vector-ref prefix 0))
          (proc (#3%vector-ref suffix 0)))]
       [(fx= len 3)
        (let* ([prefix (core-pvector-large-finger-prefix pv)]
               [suffix (core-pvector-large-finger-suffix pv)]
               [prefix-len (#%vector-length prefix)])
          (if (fx= prefix-len 1)
              (begin
                (proc (#3%vector-ref prefix 0))
                (proc (#3%vector-ref suffix 0))
                (proc (#3%vector-ref suffix 1)))
              (begin
                (proc (#3%vector-ref prefix 0))
                (proc (#3%vector-ref prefix 1))
                (proc (#3%vector-ref suffix 0)))))]
       [(fx= len 4)
        (let* ([prefix (core-pvector-large-finger-prefix pv)]
               [middle (core-pvector-large-finger-middle pv)]
               [suffix (core-pvector-large-finger-suffix pv)]
               [prefix-len (#%vector-length prefix)])
          (if middle
              (begin
                (proc (#3%vector-ref prefix 0))
                (proc (core-pvector-node2-a middle))
                (proc (core-pvector-node2-b middle))
                (proc (#3%vector-ref suffix 0)))
              (cond
               [(fx= prefix-len 1)
                (proc (#3%vector-ref prefix 0))
                (proc (#3%vector-ref suffix 0))
                (proc (#3%vector-ref suffix 1))
                (proc (#3%vector-ref suffix 2))]
               [(fx= prefix-len 2)
                (proc (#3%vector-ref prefix 0))
                (proc (#3%vector-ref prefix 1))
                (proc (#3%vector-ref suffix 0))
                (proc (#3%vector-ref suffix 1))]
               [else
                (proc (#3%vector-ref prefix 0))
                (proc (#3%vector-ref prefix 1))
                (proc (#3%vector-ref prefix 2))
                (proc (#3%vector-ref suffix 0))])))]
       [else
        (core-pvector-for-each-range/known-length pv len 0 len proc)])))
  (void))

(define (core-pvector->list pv)
  (let ([len (core-pvector-length pv)])
    (cond
     [(fx= len 0) '()]
     [(fx= len 1) (list (core-pvector-view-left pv))]
     [(fx= len 2)
      (let ([prefix (core-pvector-large-finger-prefix pv)]
            [suffix (core-pvector-large-finger-suffix pv)])
        (list
         (#3%vector-ref prefix 0)
         (#3%vector-ref suffix 0)))]
     [(fx= len 3)
      (let* ([prefix (core-pvector-large-finger-prefix pv)]
             [suffix (core-pvector-large-finger-suffix pv)]
             [prefix-len (#%vector-length prefix)])
        (if (fx= prefix-len 1)
            (list
             (#3%vector-ref prefix 0)
             (#3%vector-ref suffix 0)
             (#3%vector-ref suffix 1))
            (list
             (#3%vector-ref prefix 0)
             (#3%vector-ref prefix 1)
             (#3%vector-ref suffix 0))))]
     [(fx= len 4)
      (let* ([prefix (core-pvector-large-finger-prefix pv)]
             [middle (core-pvector-large-finger-middle pv)]
             [suffix (core-pvector-large-finger-suffix pv)]
             [prefix-len (#%vector-length prefix)])
        (if middle
            (list
             (#3%vector-ref prefix 0)
             (core-pvector-node2-a middle)
             (core-pvector-node2-b middle)
             (#3%vector-ref suffix 0))
            (cond
             [(fx= prefix-len 1)
              (list
               (#3%vector-ref prefix 0)
               (#3%vector-ref suffix 0)
               (#3%vector-ref suffix 1)
               (#3%vector-ref suffix 2))]
             [(fx= prefix-len 2)
              (list
               (#3%vector-ref prefix 0)
               (#3%vector-ref prefix 1)
               (#3%vector-ref suffix 0)
               (#3%vector-ref suffix 1))]
             [else
              (list
               (#3%vector-ref prefix 0)
               (#3%vector-ref prefix 1)
               (#3%vector-ref prefix 2)
               (#3%vector-ref suffix 0))])))]
     [else
      (core-pvector->list-range/known-length pv len 0 len '())])))

(define (core-pvector-shape-stats pv)
  (let ([h (make-hasheq)]
        [len (core-pvector-length pv)])
    (define (put! k v) (hash-set! h k v))
    (put! 'backend 'core)
    (put! 'chunked-tree? #f)
    (put! 'chunk-index-vectors 0)
    (put! 'chunk-index-slots 0)
    (put! 'ref-cache? #f)
    (put! 'length len)
    (cond
     [(core-pvector-empty-record? pv)
      (put! 'representation 'empty)
      (put! 'empty 1)]
     [(core-pvector-inline? pv)
      (put! 'representation 'single)
      (put! 'single 1)]
     [else
      (let ([middle (core-pvector-large-finger-middle pv)])
        (put! 'representation 'large-finger)
        (put! 'large-finger 1)
        (put! 'digit-vectors 2)
        (put! 'prefix-length
              (#%vector-length (core-pvector-large-finger-prefix pv)))
        (put! 'suffix-length
              (#%vector-length (core-pvector-large-finger-suffix pv)))
        (put! 'middle-measure
              (if middle (core-pvector-node-measure middle) 0))
        (put! 'finger-depth
              (if middle (core-pvector-node-level middle) 0))
        (put! 'finger-nodes
              (if middle (core-pvector-node-count middle) 0))
        (put! 'node2
              (if middle (core-pvector-node2-count middle) 0))
        (put! 'node3
              (if middle (core-pvector-node3-count middle) 0))
        (put! 'payload-vectors 0))])
    h))
