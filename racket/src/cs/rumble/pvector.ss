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
         [copy (make-vector len)])
    (let loop ([i 0])
      (unless (fx= i len)
        (#3%vector-set! copy i (#3%vector-ref vec (fx+ start i)))
        (loop (fx+ i 1))))
    copy))

(define (core-vector-copy-range/immutable vec start end)
  (#3%vector->immutable-vector (core-vector-copy-range vec start end)))

(define (core-vector-copy/immutable vec)
  (core-vector-copy-range/immutable vec 0 (#%vector-length vec)))

(define (core-pvector-range->immutable-vector pv start end)
  (let* ([len (fx- end start)]
         [vec (make-vector len)])
    (core-pvector-fill-range! vec 0 pv start end)
    (#3%vector->immutable-vector vec)))

(define (core-vector-insert/immutable vec len index value)
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
    (#3%vector->immutable-vector new-vec)))

(define (core-vector-remove/immutable vec len index)
  (let ([new-vec (make-vector (fx- len 1))])
    (let loop ([i 0])
      (unless (fx= i index)
        (#3%vector-set! new-vec i (#3%vector-ref vec i))
        (loop (fx+ i 1))))
    (let loop ([i (fx+ index 1)])
      (unless (fx= i len)
        (#3%vector-set! new-vec (fx- i 1) (#3%vector-ref vec i))
        (loop (fx+ i 1))))
    (#3%vector->immutable-vector new-vec)))

(define (core-list-length lst)
  (let loop ([lst lst] [len 0])
    (if (null? lst)
        len
        (loop (cdr lst) (fx+ len 1)))))

(define (core-reverse-list->immutable-vector lst)
  (let* ([len (core-list-length lst)]
         [vec (make-vector len)])
    (let loop ([lst lst] [i (fx- len 1)])
      (unless (null? lst)
        (#3%vector-set! vec i (car lst))
        (loop (cdr lst) (fx- i 1))))
    (#3%vector->immutable-vector vec)))

(define (core-entry-measure node-level entry)
  (if (fx= node-level 1)
      1
      (core-pvector-node-measure entry)))

(define (core-make-node2 node-level a b)
  (make-core-pvector-node2
   (fx+ (core-entry-measure node-level a)
        (core-entry-measure node-level b))
   node-level
   a
   b))

(define (core-make-node3 node-level a b c)
  (make-core-pvector-node3
   (fx+ (core-entry-measure node-level a)
        (fx+ (core-entry-measure node-level b)
             (core-entry-measure node-level c)))
   node-level
   a
   b
   c))

(define (core-pvector-node-measure node)
  (if (core-pvector-node2? node)
      (core-pvector-node2-measure node)
      (core-pvector-node3-measure node)))

(define (core-pvector-node-level node)
  (if (core-pvector-node2? node)
      (core-pvector-node2-level node)
      (core-pvector-node3-level node)))

(define (core-pvector-node-vector-max-level nodes)
  (let ([len (#%vector-length nodes)])
    (let loop ([i 0] [max-level 1])
      (if (fx= i len)
          max-level
          (loop (fx+ i 1)
                (fxmax max-level
                       (core-pvector-node-level (#3%vector-ref nodes i))))))))

(define (core-build-node-tree/nodes reversed-nodes)
  (let* ([nodes (core-reverse-list->immutable-vector reversed-nodes)]
         [len (#%vector-length nodes)])
    (cond
     [(fx= len 0) #f]
     [(fx= len 1) (#3%vector-ref nodes 0)]
     [else
      (core-build-node-tree/level
       nodes
       (fx+ (core-pvector-node-vector-max-level nodes) 1))])))

(define (core-pvector-node-ref node index)
  (let ([level (core-pvector-node-level node)])
    (define (descend entry index)
      (if (fx= level 1)
          entry
          (core-pvector-node-ref entry index)))
    (if (core-pvector-node2? node)
        (let* ([a (core-pvector-node2-a node)]
               [a-measure (core-entry-measure level a)])
          (if (fx< index a-measure)
              (descend a index)
              (descend (core-pvector-node2-b node)
                       (fx- index a-measure))))
        (let* ([a (core-pvector-node3-a node)]
               [b (core-pvector-node3-b node)]
               [a-measure (core-entry-measure level a)]
               [b-measure (core-entry-measure level b)])
          (cond
           [(fx< index a-measure)
            (descend a index)]
           [(fx< index (fx+ a-measure b-measure))
            (descend b (fx- index a-measure))]
           [else
            (descend (core-pvector-node3-c node)
                     (fx- index (fx+ a-measure b-measure)))])))))

(define (core-build-next-node-level entries node-level)
  (let* ([entry-count (#%vector-length entries)]
         [nodes (make-vector entry-count)])
    (let loop ([entry-index 0] [node-index 0])
      (let ([remaining (fx- entry-count entry-index)])
        (cond
         [(fx= remaining 0)
          (core-vector-copy-range/immutable nodes 0 node-index)]
         [(fx= remaining 2)
          (#3%vector-set!
           nodes
           node-index
           (core-make-node2 node-level
                            (#3%vector-ref entries entry-index)
                            (#3%vector-ref entries (fx+ entry-index 1))))
          (core-vector-copy-range/immutable nodes 0 (fx+ node-index 1))]
         [(fx= remaining 3)
          (#3%vector-set!
           nodes
           node-index
           (core-make-node3 node-level
                            (#3%vector-ref entries entry-index)
                            (#3%vector-ref entries (fx+ entry-index 1))
                            (#3%vector-ref entries (fx+ entry-index 2))))
          (core-vector-copy-range/immutable nodes 0 (fx+ node-index 1))]
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
          (core-vector-copy-range/immutable nodes 0 (fx+ node-index 2))]
         [else
          (#3%vector-set!
           nodes
           node-index
           (core-make-node3 node-level
                            (#3%vector-ref entries entry-index)
                            (#3%vector-ref entries (fx+ entry-index 1))
                            (#3%vector-ref entries (fx+ entry-index 2))))
          (loop (fx+ entry-index 3) (fx+ node-index 1))])))))

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

(define (core-pvector-node-slice/aligned node start end)
  (let ([node-measure (core-pvector-node-measure node)])
    (cond
     [(fx= start end) #f]
     [(and (fx= start 0) (fx= end node-measure)) node]
     [else
      (let ([level (core-pvector-node-level node)]
            [failed? #f]
            [pieces '()])
        (define (add-piece! entry entry-start)
          (let* ([entry-measure (core-entry-measure level entry)]
                 [entry-end (fx+ entry-start entry-measure)]
                 [copy-start (fxmax start entry-start)]
                 [copy-end (fxmin end entry-end)])
            (when (fx< copy-start copy-end)
              (cond
               [(and (fx= copy-start entry-start)
                     (fx= copy-end entry-end))
                (set! pieces (cons entry pieces))]
               [(fx= level 1)
                (set! failed? #t)]
               [else
                (let ([slice
                       (core-pvector-node-slice/aligned
                        entry
                        (fx- copy-start entry-start)
                        (fx- copy-end entry-start))])
                  (if slice
                      (set! pieces (cons slice pieces))
                      (set! failed? #t)))]))))
        (if (core-pvector-node2? node)
            (let* ([a (core-pvector-node2-a node)]
                   [a-measure (core-entry-measure level a)])
              (add-piece! a 0)
              (add-piece! (core-pvector-node2-b node) a-measure))
            (let* ([a (core-pvector-node3-a node)]
                   [b (core-pvector-node3-b node)]
                   [a-measure (core-entry-measure level a)]
                   [b-start a-measure]
                   [c-start (fx+ a-measure (core-entry-measure level b))])
              (add-piece! a 0)
              (add-piece! b b-start)
              (add-piece! (core-pvector-node3-c node) c-start)))
        (and (not failed?)
             (let* ([entries (core-reverse-list->immutable-vector pieces)]
                    [entry-count (#%vector-length entries)])
               (and (not (and (fx= level 1) (fx= entry-count 1)))
                    (core-build-node-tree/level
                     entries
                     (if (fx= level 1) 1 2))))))])))

(define (core-pvector-deep-edge-lengths len)
  (if (fx<= len (fx* 2 core-pvector-digit-max))
      (let ([prefix-len (fxquotient len 2)])
        (values prefix-len (fx- len prefix-len)))
      (if (fx= len (fx+ (fx* 2 core-pvector-digit-max) 1))
          (values core-pvector-digit-max (fx- core-pvector-digit-max 1))
          (values core-pvector-digit-max core-pvector-digit-max))))

(define (core-vector->large-finger immutable-vec len)
  (let-values ([(prefix-len suffix-len)
                (core-pvector-deep-edge-lengths len)])
    (let* ([suffix-start (fx- len suffix-len)]
           [middle-len (fx- suffix-start prefix-len)]
           [prefix (core-vector-copy-range/immutable immutable-vec 0 prefix-len)]
           [middle
            (if (fx= middle-len 0)
                #f
                (core-build-node-tree
                 (core-vector-copy-range/immutable
                  immutable-vec
                  prefix-len
                  suffix-start)))]
           [suffix (core-vector-copy-range/immutable immutable-vec suffix-start len)])
      (make-core-pvector-large-finger len prefix middle suffix))))

(define (core-pvector-large-finger-ref pv index)
  (let* ([len (core-pvector-large-finger-length pv)]
         [prefix (core-pvector-large-finger-prefix pv)]
         [suffix (core-pvector-large-finger-suffix pv)]
         [prefix-len (#%vector-length prefix)]
         [suffix-len (#%vector-length suffix)]
         [middle-len (fx- len (fx+ prefix-len suffix-len))])
    (cond
     [(fx< index prefix-len)
      (#3%vector-ref prefix index)]
     [(fx< index (fx+ prefix-len middle-len))
      (core-pvector-node-ref (core-pvector-large-finger-middle pv)
                             (fx- index prefix-len))]
     [else
      (#3%vector-ref suffix
                     (fx- index (fx+ prefix-len middle-len)))])))

(define (core-pvector-large-finger-copy pv start end)
  (let* ([len (core-pvector-large-finger-length pv)]
         [new-len (fx- end start)]
         [middle (core-pvector-large-finger-middle pv)]
         [prefix-len (#%vector-length (core-pvector-large-finger-prefix pv))]
         [suffix-len (#%vector-length (core-pvector-large-finger-suffix pv))]
         [middle-start prefix-len]
         [middle-end (fx- len suffix-len)])
    (and (fx> new-len core-pvector-inline-max)
         (let ([min-prefix-len
                (if (fx< start middle-start)
                    (fx- middle-start start)
                    0)]
               [min-suffix-len
                (if (fx> end middle-end)
                    (fx- end middle-end)
                    0)])
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
                                   (core-pvector-range->immutable-vector
                                    pv
                                    start
                                    middle-copy-start)
                                   new-middle
                                   (core-pvector-range->immutable-vector
                                    pv
                                    middle-copy-end
                                    end))
                                  (suffix-loop (fx+ edge-suffix-len 1))))
                            (suffix-loop (fx+ edge-suffix-len 1))))]))))))))

(define (core-pvector-large-finger-cons-left pv value)
  (let* ([prefix (core-pvector-large-finger-prefix pv)]
         [prefix-len (#%vector-length prefix)])
    (and (fx< prefix-len core-pvector-digit-max)
         (let* ([new-prefix-len (fx+ prefix-len 1)]
                [new-prefix (make-vector new-prefix-len)])
           (#3%vector-set! new-prefix 0 value)
           (let loop ([i 0])
             (unless (fx= i prefix-len)
               (#3%vector-set! new-prefix (fx+ i 1) (#3%vector-ref prefix i))
               (loop (fx+ i 1))))
           (make-core-pvector-large-finger
            (fx+ (core-pvector-large-finger-length pv) 1)
            (#3%vector->immutable-vector new-prefix)
            (core-pvector-large-finger-middle pv)
            (core-pvector-large-finger-suffix pv))))))

(define (core-pvector-large-finger-cons-right pv value)
  (let* ([suffix (core-pvector-large-finger-suffix pv)]
         [suffix-len (#%vector-length suffix)])
    (and (fx< suffix-len core-pvector-digit-max)
         (let* ([new-suffix-len (fx+ suffix-len 1)]
                [new-suffix (make-vector new-suffix-len)])
           (let loop ([i 0])
             (unless (fx= i suffix-len)
               (#3%vector-set! new-suffix i (#3%vector-ref suffix i))
               (loop (fx+ i 1))))
           (#3%vector-set! new-suffix suffix-len value)
           (make-core-pvector-large-finger
            (fx+ (core-pvector-large-finger-length pv) 1)
            (core-pvector-large-finger-prefix pv)
            (core-pvector-large-finger-middle pv)
            (#3%vector->immutable-vector new-suffix))))))

(define (core-pvector-node-set node index value)
  (let ([level (core-pvector-node-level node)])
    (define (set-entry entry index)
      (if (fx= level 1)
          value
          (core-pvector-node-set entry index value)))
    (if (core-pvector-node2? node)
        (let* ([a (core-pvector-node2-a node)]
               [b (core-pvector-node2-b node)]
               [a-measure (core-entry-measure level a)])
          (if (fx< index a-measure)
              (core-make-node2 level (set-entry a index) b)
              (core-make-node2 level
                               a
                               (set-entry b (fx- index a-measure)))))
        (let* ([a (core-pvector-node3-a node)]
               [b (core-pvector-node3-b node)]
               [c (core-pvector-node3-c node)]
               [a-measure (core-entry-measure level a)]
               [b-measure (core-entry-measure level b)]
               [ab-measure (fx+ a-measure b-measure)])
          (cond
           [(fx< index a-measure)
            (core-make-node3 level (set-entry a index) b c)]
           [(fx< index ab-measure)
            (core-make-node3 level
                             a
                             (set-entry b (fx- index a-measure))
                             c)]
           [else
            (core-make-node3 level
                             a
                             b
                             (set-entry c (fx- index ab-measure)))])))))

(define (core-pvector-large-finger-set pv index value)
  (let* ([len (core-pvector-large-finger-length pv)]
         [prefix (core-pvector-large-finger-prefix pv)]
         [middle (core-pvector-large-finger-middle pv)]
         [suffix (core-pvector-large-finger-suffix pv)]
         [prefix-len (#%vector-length prefix)]
         [suffix-len (#%vector-length suffix)]
         [suffix-start (fx- len suffix-len)])
    (cond
     [(fx< index prefix-len)
      (let ([new-prefix (core-vector-copy-range prefix 0 prefix-len)])
        (#3%vector-set! new-prefix index value)
        (make-core-pvector-large-finger
         len
         (#3%vector->immutable-vector new-prefix)
         middle
         suffix))]
     [(fx>= index suffix-start)
      (let ([new-suffix (core-vector-copy-range suffix 0 suffix-len)])
        (#3%vector-set! new-suffix (fx- index suffix-start) value)
        (make-core-pvector-large-finger
         len
         prefix
         middle
         (#3%vector->immutable-vector new-suffix)))]
     [else
      (make-core-pvector-large-finger
       len
       prefix
       (core-pvector-node-set middle (fx- index prefix-len) value)
       suffix)])))

(define (core-pvector-large-finger-insert pv index value)
  (let* ([len (core-pvector-large-finger-length pv)]
         [prefix (core-pvector-large-finger-prefix pv)]
         [middle (core-pvector-large-finger-middle pv)]
         [suffix (core-pvector-large-finger-suffix pv)]
         [prefix-len (#%vector-length prefix)]
         [suffix-len (#%vector-length suffix)]
         [suffix-start (fx- len suffix-len)])
    (cond
     [(and (fx<= index prefix-len)
           (fx< prefix-len core-pvector-digit-max))
      (make-core-pvector-large-finger
       (fx+ len 1)
       (core-vector-insert/immutable prefix prefix-len index value)
       middle
       suffix)]
     [(and (fx>= index suffix-start)
           (fx< suffix-len core-pvector-digit-max))
      (make-core-pvector-large-finger
       (fx+ len 1)
       prefix
       middle
       (core-vector-insert/immutable
        suffix
        suffix-len
        (fx- index suffix-start)
        value))]
     [else
      (let ([singleton (make-core-pvector-inline 1 value #f #f #f)])
        (core-pvector-append
         (core-pvector-append
          (core-pvector-copy pv 0 index)
          singleton)
         (core-pvector-copy pv index len)))])))

(define (core-pvector-large-finger-delete pv index)
  (let* ([len (core-pvector-large-finger-length pv)]
         [new-len (fx- len 1)]
         [prefix (core-pvector-large-finger-prefix pv)]
         [middle (core-pvector-large-finger-middle pv)]
         [suffix (core-pvector-large-finger-suffix pv)]
         [prefix-len (#%vector-length prefix)]
         [suffix-len (#%vector-length suffix)]
         [suffix-start (fx- len suffix-len)])
    (and (fx> new-len core-pvector-inline-max)
         (cond
          [(and (fx< index prefix-len)
                (fx> prefix-len 1))
           (make-core-pvector-large-finger
            new-len
            (core-vector-remove/immutable prefix prefix-len index)
            middle
            suffix)]
          [(and (fx>= index suffix-start)
                (fx> suffix-len 1))
           (make-core-pvector-large-finger
            new-len
            prefix
            middle
            (core-vector-remove/immutable
             suffix
             suffix-len
             (fx- index suffix-start)))]
          [else
           (core-pvector-append
            (core-pvector-copy pv 0 index)
            (core-pvector-copy pv (fx+ index 1) len))]))))

(define (core-pvector-large-finger-append-right left right right-len)
  (let* ([suffix (core-pvector-large-finger-suffix left)]
         [suffix-len (#%vector-length suffix)]
         [new-suffix-len (fx+ suffix-len right-len)])
    (if (fx<= new-suffix-len core-pvector-digit-max)
        (let ([new-suffix (make-vector new-suffix-len)])
          (core-vector-fill-range! new-suffix 0 suffix 0 suffix-len)
          (core-pvector-fill-range! new-suffix suffix-len right 0 right-len)
          (make-core-pvector-large-finger
           (fx+ (core-pvector-large-finger-length left) right-len)
           (core-pvector-large-finger-prefix left)
           (core-pvector-large-finger-middle left)
           (#3%vector->immutable-vector new-suffix)))
        (let* ([bridge
                (core-pvector-vector+pvector-bridge-node
                 suffix
                 right
                 right-len)]
               [middle
                (core-build-node-tree/nodes
                 (let ([nodes '()])
                   (when (core-pvector-large-finger-middle left)
                     (set! nodes
                           (cons (core-pvector-large-finger-middle left)
                                 nodes)))
                   (when bridge
                     (set! nodes (cons bridge nodes)))
                   nodes))])
          (and middle
               (make-core-pvector-large-finger
                (fx+ (core-pvector-large-finger-length left) right-len)
                (core-pvector-large-finger-prefix left)
                middle
                (core-vector-copy-range/immutable suffix 0 0)))))))

(define (core-pvector-large-finger-append-left left left-len right)
  (let* ([prefix (core-pvector-large-finger-prefix right)]
         [prefix-len (#%vector-length prefix)]
         [new-prefix-len (fx+ left-len prefix-len)])
    (if (fx<= new-prefix-len core-pvector-digit-max)
        (let ([new-prefix (make-vector new-prefix-len)])
          (core-pvector-fill-range! new-prefix 0 left 0 left-len)
          (core-vector-fill-range!
           new-prefix
           left-len
           prefix
           0
           prefix-len)
          (make-core-pvector-large-finger
           (fx+ left-len (core-pvector-large-finger-length right))
           (#3%vector->immutable-vector new-prefix)
           (core-pvector-large-finger-middle right)
           (core-pvector-large-finger-suffix right)))
        (let* ([bridge
                (core-pvector-pvector+vector-bridge-node
                 left
                 left-len
                 prefix)]
               [middle
                (core-build-node-tree/nodes
                 (let ([nodes '()])
                   (when bridge
                     (set! nodes (cons bridge nodes)))
                   (when (core-pvector-large-finger-middle right)
                     (set! nodes
                           (cons (core-pvector-large-finger-middle right)
                                 nodes)))
                   nodes))])
          (and middle
               (make-core-pvector-large-finger
                (fx+ left-len (core-pvector-large-finger-length right))
                (core-vector-copy-range/immutable prefix 0 0)
                middle
                (core-pvector-large-finger-suffix right)))))))

(define (core-pvector-vector+pvector-bridge-node left-vec right right-len)
  (let* ([left-len (#%vector-length left-vec)]
         [bridge-len (fx+ left-len right-len)])
    (and (fx>= bridge-len 2)
         (let ([bridge (make-vector bridge-len)])
           (core-vector-fill-range! bridge 0 left-vec 0 left-len)
           (core-pvector-fill-range! bridge left-len right 0 right-len)
           (core-build-node-tree
            (#3%vector->immutable-vector bridge))))))

(define (core-pvector-pvector+vector-bridge-node left left-len right-vec)
  (let* ([right-len (#%vector-length right-vec)]
         [bridge-len (fx+ left-len right-len)])
    (and (fx>= bridge-len 2)
         (let ([bridge (make-vector bridge-len)])
           (core-pvector-fill-range! bridge 0 left 0 left-len)
           (core-vector-fill-range! bridge left-len right-vec 0 right-len)
           (core-build-node-tree
            (#3%vector->immutable-vector bridge))))))

(define (core-pvector-digit-bridge-node left-suffix right-prefix)
  (let* ([left-len (#%vector-length left-suffix)]
         [right-len (#%vector-length right-prefix)]
         [bridge-len (fx+ left-len right-len)])
    (and (fx>= bridge-len 2)
         (let ([bridge (make-vector bridge-len)])
           (core-vector-fill-range! bridge 0 left-suffix 0 left-len)
           (core-vector-fill-range! bridge left-len right-prefix 0 right-len)
           (core-build-node-tree
            (#3%vector->immutable-vector bridge))))))

(define (core-pvector-large-finger-append left right)
  (let* ([left-suffix (core-pvector-large-finger-suffix left)]
         [right-prefix (core-pvector-large-finger-prefix right)]
         [bridge-len (fx+ (#%vector-length left-suffix)
                          (#%vector-length right-prefix))])
    (and (not (fx= bridge-len 1))
         (let ([middle
                (core-build-node-tree/nodes
                 (let ([bridge
                        (core-pvector-digit-bridge-node
                         left-suffix
                         right-prefix)]
                       [nodes '()])
                   (when (core-pvector-large-finger-middle left)
                     (set! nodes
                           (cons (core-pvector-large-finger-middle left)
                                 nodes)))
                   (when bridge
                     (set! nodes (cons bridge nodes)))
                   (when (core-pvector-large-finger-middle right)
                     (set! nodes
                           (cons (core-pvector-large-finger-middle right)
                                 nodes)))
                   nodes))])
           (and middle
                (make-core-pvector-large-finger
                 (fx+ (core-pvector-large-finger-length left)
                      (core-pvector-large-finger-length right))
                 (core-pvector-large-finger-prefix left)
                 middle
                 (core-pvector-large-finger-suffix right)))))))

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

(define (core-vector->pvector/no-copy immutable-vec)
  (let ([len (#%vector-length immutable-vec)])
    (cond
     [(fx= len 0)
      empty-core-pvector]
     [(fx<= len core-pvector-inline-max)
      (core-vector->inline immutable-vec len)]
     [else
      (core-vector->large-finger immutable-vec len)])))

(define (core-immutable-vector->pvector immutable-vec)
  (core-vector->pvector/no-copy immutable-vec))

(define (core-vector->pvector vec)
  (core-vector->pvector/no-copy (core-vector-copy/immutable vec)))

(define (core-list->pvector lst)
  (let* ([len (core-list-length lst)]
         [vec (make-vector len)])
    (let loop ([lst lst] [i 0])
      (unless (null? lst)
        (#3%vector-set! vec i (car lst))
        (loop (cdr lst) (fx+ i 1))))
    (core-vector->pvector/no-copy (#3%vector->immutable-vector vec))))

(define (core-make-pvector len value)
  (cond
   [(fx= len 0)
    empty-core-pvector]
   [else
    (core-vector->pvector/no-copy (#3%vector->immutable-vector
                                   (make-vector len value)))]))

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

(define (core-vector-fill-range! dest dest-offset src start end)
  (let loop ([i start] [offset dest-offset])
    (if (fx= i end)
        offset
        (begin
          (#3%vector-set! dest offset (#3%vector-ref src i))
          (loop (fx+ i 1) (fx+ offset 1))))))

(define (core-pvector-node-fill-range! dest dest-offset node start end)
  (let ([level (core-pvector-node-level node)])
    (define (copy-entry entry entry-start offset)
      (let* ([entry-measure (core-entry-measure level entry)]
             [entry-end (fx+ entry-start entry-measure)]
             [copy-start (fxmax start entry-start)]
             [copy-end (fxmin end entry-end)])
        (if (fx< copy-start copy-end)
            (if (fx= level 1)
                (begin
                  (#3%vector-set! dest offset entry)
                  (fx+ offset 1))
                (core-pvector-node-fill-range!
                 dest
                 offset
                 entry
                 (fx- copy-start entry-start)
                 (fx- copy-end entry-start)))
            offset)))
    (if (core-pvector-node2? node)
        (let* ([a (core-pvector-node2-a node)]
               [a-measure (core-entry-measure level a)]
               [offset (copy-entry a 0 dest-offset)])
          (copy-entry (core-pvector-node2-b node) a-measure offset))
        (let* ([a (core-pvector-node3-a node)]
               [b (core-pvector-node3-b node)]
               [a-measure (core-entry-measure level a)]
               [b-start a-measure]
               [c-start (fx+ a-measure (core-entry-measure level b))]
               [offset (copy-entry a 0 dest-offset)]
               [offset (copy-entry b b-start offset)])
          (copy-entry (core-pvector-node3-c node) c-start offset)))))

(define (core-pvector-large-finger-fill-range! dest dest-offset pv start end)
  (let* ([len (core-pvector-large-finger-length pv)]
         [prefix (core-pvector-large-finger-prefix pv)]
         [suffix (core-pvector-large-finger-suffix pv)]
         [prefix-len (#%vector-length prefix)]
         [suffix-len (#%vector-length suffix)]
         [middle-start prefix-len]
         [suffix-start (fx- len suffix-len)]
         [offset dest-offset])
    (define (copy-vector-segment vec segment-start segment-end offset)
      (let ([copy-start (fxmax start segment-start)]
            [copy-end (fxmin end segment-end)])
        (if (fx< copy-start copy-end)
            (core-vector-fill-range!
             dest
             offset
             vec
             (fx- copy-start segment-start)
             (fx- copy-end segment-start))
            offset)))
    (set! offset (copy-vector-segment prefix 0 prefix-len offset))
    (let ([copy-start (fxmax start middle-start)]
          [copy-end (fxmin end suffix-start)])
      (when (fx< copy-start copy-end)
        (set! offset
              (core-pvector-node-fill-range!
               dest
               offset
               (core-pvector-large-finger-middle pv)
               (fx- copy-start middle-start)
               (fx- copy-end middle-start)))))
    (copy-vector-segment suffix suffix-start len offset)))

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

(define (core-vector-for-each-range vec start end proc)
  (let loop ([i start])
    (unless (fx= i end)
      (proc (#3%vector-ref vec i))
      (loop (fx+ i 1)))))

(define (core-pvector-node-for-each-range node start end proc)
  (let ([level (core-pvector-node-level node)])
    (define (visit-entry entry entry-start)
      (let* ([entry-measure (core-entry-measure level entry)]
             [entry-end (fx+ entry-start entry-measure)]
             [visit-start (fxmax start entry-start)]
             [visit-end (fxmin end entry-end)])
        (when (fx< visit-start visit-end)
          (if (fx= level 1)
              (proc entry)
              (core-pvector-node-for-each-range
               entry
               (fx- visit-start entry-start)
               (fx- visit-end entry-start)
               proc)))))
    (if (core-pvector-node2? node)
        (let* ([a (core-pvector-node2-a node)]
               [a-measure (core-entry-measure level a)])
          (visit-entry a 0)
          (visit-entry (core-pvector-node2-b node) a-measure))
        (let* ([a (core-pvector-node3-a node)]
               [b (core-pvector-node3-b node)]
               [a-measure (core-entry-measure level a)]
               [b-start a-measure]
               [c-start (fx+ a-measure (core-entry-measure level b))])
          (visit-entry a 0)
          (visit-entry b b-start)
          (visit-entry (core-pvector-node3-c node) c-start)))))

(define (core-pvector-large-finger-for-each-range pv start end proc)
  (let* ([len (core-pvector-large-finger-length pv)]
         [prefix (core-pvector-large-finger-prefix pv)]
         [suffix (core-pvector-large-finger-suffix pv)]
         [prefix-len (#%vector-length prefix)]
         [suffix-len (#%vector-length suffix)]
         [middle-start prefix-len]
         [suffix-start (fx- len suffix-len)])
    (define (visit-vector-segment vec segment-start segment-end)
      (let ([visit-start (fxmax start segment-start)]
            [visit-end (fxmin end segment-end)])
        (when (fx< visit-start visit-end)
          (core-vector-for-each-range
           vec
           (fx- visit-start segment-start)
           (fx- visit-end segment-start)
           proc))))
    (visit-vector-segment prefix 0 prefix-len)
    (let ([visit-start (fxmax start middle-start)]
          [visit-end (fxmin end suffix-start)])
      (when (fx< visit-start visit-end)
        (core-pvector-node-for-each-range
         (core-pvector-large-finger-middle pv)
         (fx- visit-start middle-start)
         (fx- visit-end middle-start)
         proc)))
    (visit-vector-segment suffix suffix-start len)))

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

(define (core-check-index who pv index)
  (let ([len (core-pvector-length pv)])
    (unless (and (fixnum? index)
                 (fx>= index 0)
                 (fx< index len))
      (error who "index out of bounds"))
    len))

(define (core-check-end-index who pv index)
  (let ([len (core-pvector-length pv)])
    (unless (and (fixnum? index)
                 (fx>= index 0)
                 (fx<= index len))
      (error who "index out of bounds"))
    len))

(define (core-pvector-ref pv index)
  (core-check-index 'core-pvector-ref pv index)
  (core-pvector-ref/unchecked pv index))

(define (core-pvector-view-left pv)
  (core-pvector-ref pv 0))

(define (core-pvector-view-right pv)
  (let ([len (core-pvector-length pv)])
    (when (fx= len 0)
      (error 'core-pvector-view-right "empty pvector"))
    (core-pvector-ref/unchecked pv (fx- len 1))))

(define (core-pvector-fill-vector! vec offset pv)
  (let ([len (core-pvector-length pv)])
    (core-pvector-fill-range! vec offset pv 0 len)))

(define (core-pvector->vector pv)
  (let* ([len (core-pvector-length pv)]
         [vec (make-vector len)])
    (core-pvector-fill-vector! vec 0 pv)
    vec))

(define (core-pvector-set pv index value)
  (let ([len (core-check-index 'core-pvector-set pv index)])
    (if (eq? (core-pvector-ref/unchecked pv index) value)
        pv
        (if (core-pvector-large-finger? pv)
            (core-pvector-large-finger-set pv index value)
            (let ([vec (core-pvector->vector pv)])
              (#3%vector-set! vec index value)
              (core-vector->pvector/no-copy
               (#3%vector->immutable-vector vec)))))))

(define (core-pvector-cons-left pv value)
  (let ([direct (if (core-pvector-large-finger? pv)
                    (core-pvector-large-finger-cons-left pv value)
                    #f)])
    (if direct
        direct
        (let* ([len (core-pvector-length pv)]
               [new-len (fx+ len 1)]
               [vec (make-vector new-len)])
          (#3%vector-set! vec 0 value)
          (core-pvector-fill-vector! vec 1 pv)
          (core-vector->pvector/no-copy (#3%vector->immutable-vector vec))))))

(define (core-pvector-cons-right pv value)
  (let ([direct (if (core-pvector-large-finger? pv)
                    (core-pvector-large-finger-cons-right pv value)
                    #f)])
    (if direct
        direct
        (let* ([len (core-pvector-length pv)]
               [new-len (fx+ len 1)]
               [vec (make-vector new-len)])
          (core-pvector-fill-vector! vec 0 pv)
          (#3%vector-set! vec len value)
          (core-vector->pvector/no-copy (#3%vector->immutable-vector vec))))))

(define (core-pvector-pop-left pv)
  (core-check-index 'core-pvector-pop-left pv 0)
  (values (core-pvector-ref/unchecked pv 0)
          (core-pvector-drop pv 1)))

(define (core-pvector-pop-right pv)
  (let ([len (core-pvector-length pv)])
    (when (fx= len 0)
      (error 'core-pvector-pop-right "empty pvector"))
    (values (core-pvector-ref/unchecked pv (fx- len 1))
            (core-pvector-take pv (fx- len 1)))))

(define (core-pvector-small-fill-vector! vec offset pv len)
  (cond
   [(fx= len 0) offset]
   [(core-pvector-inline? pv)
    (let loop ([i 0] [offset offset])
      (if (fx= i len)
          offset
          (begin
            (#3%vector-set! vec offset (core-pvector-inline-ref pv i))
            (loop (fx+ i 1) (fx+ offset 1)))))]
   [else
    (core-pvector-fill-range! vec offset pv 0 len)]))

(define (core-pvector-small-append left left-len right right-len total-len)
  (and (not (core-pvector-large-finger? left))
       (not (core-pvector-large-finger? right))
       (let ([vec (make-vector total-len)])
         (core-pvector-small-fill-vector! vec 0 left left-len)
         (core-pvector-small-fill-vector! vec left-len right right-len)
         (core-vector->pvector/no-copy (#3%vector->immutable-vector vec)))))

(define (core-pvector-append left right)
  (let* ([left-len (core-pvector-length left)]
         [right-len (core-pvector-length right)]
         [total-len (fx+ left-len right-len)])
    (cond
     [(fx= left-len 0) right]
     [(fx= right-len 0) left]
     [else
      (let ([direct (cond
                     [(and (core-pvector-large-finger? left)
                           (core-pvector-large-finger? right))
                      (core-pvector-large-finger-append left right)]
                     [(core-pvector-large-finger? left)
                      (core-pvector-large-finger-append-right
                       left
                       right
                       right-len)]
                     [(core-pvector-large-finger? right)
                      (core-pvector-large-finger-append-left
                       left
                       left-len
                       right)]
                     [else
                      (core-pvector-small-append
                       left
                       left-len
                       right
                       right-len
                       total-len)])])
        (if direct
            direct
            (let ([vec (make-vector total-len)])
              (core-pvector-fill-vector! vec 0 left)
              (core-pvector-fill-vector! vec left-len right)
              (core-vector->pvector/no-copy
               (#3%vector->immutable-vector vec)))))])))

(define (core-pvector-copy pv start end)
  (let ([len (core-check-end-index 'core-pvector-copy pv start)])
    (core-check-end-index 'core-pvector-copy pv end)
    (when (fx> start end)
      (error 'core-pvector-copy "starting index is greater than ending index"))
    (cond
     [(fx= start end) empty-core-pvector]
     [(and (fx= start 0) (fx= end len)) pv]
     [else
      (let ([direct (if (core-pvector-large-finger? pv)
                        (core-pvector-large-finger-copy pv start end)
                        #f)])
        (if direct
            direct
            (let* ([new-len (fx- end start)]
                   [vec (make-vector new-len)])
              (core-pvector-fill-range! vec 0 pv start end)
              (core-vector->pvector/no-copy
               (#3%vector->immutable-vector vec)))))])))

(define (core-pvector-take pv pos)
  (let ([len (core-check-end-index 'core-pvector-take pv pos)])
    (cond
     [(fx= pos 0) empty-core-pvector]
     [(fx= pos len) pv]
     [else (core-pvector-copy pv 0 pos)])))

(define (core-pvector-drop pv pos)
  (let ([len (core-check-end-index 'core-pvector-drop pv pos)])
    (cond
     [(fx= pos 0) pv]
     [(fx= pos len) empty-core-pvector]
     [else (core-pvector-copy pv pos len)])))

(define (core-pvector-take-right pv pos)
  (let ([len (core-check-end-index 'core-pvector-take-right pv pos)])
    (core-pvector-drop pv (fx- len pos))))

(define (core-pvector-drop-right pv pos)
  (let ([len (core-check-end-index 'core-pvector-drop-right pv pos)])
    (core-pvector-take pv (fx- len pos))))

(define (core-pvector-split-at pv pos)
  (core-check-end-index 'core-pvector-split-at pv pos)
  (values (core-pvector-take pv pos)
          (core-pvector-drop pv pos)))

(define (core-pvector-split-at-right pv pos)
  (let ([len (core-check-end-index 'core-pvector-split-at-right pv pos)])
    (let ([split-pos (fx- len pos)])
      (values (core-pvector-drop pv split-pos)
              (core-pvector-take pv split-pos)))))

(define (core-pvector-split pv index)
  (let ([len (core-check-index 'core-pvector-split pv index)])
    (values (core-pvector-take pv index)
            (core-pvector-ref/unchecked pv index)
            (core-pvector-drop pv (fx+ index 1)))))

(define (core-pvector-insert pv index value)
  (let ([len (core-check-end-index 'core-pvector-insert pv index)])
    (cond
     [(fx= index 0) (core-pvector-cons-left pv value)]
     [(fx= index len) (core-pvector-cons-right pv value)]
     [else
      (let ([direct (if (core-pvector-large-finger? pv)
                        (core-pvector-large-finger-insert pv index value)
                        #f)])
        (if direct
            direct
            (let ([vec (make-vector (fx+ len 1))])
              (let loop ([i 0])
                (unless (fx= i index)
                  (#3%vector-set! vec i (core-pvector-ref/unchecked pv i))
                  (loop (fx+ i 1))))
              (#3%vector-set! vec index value)
              (let loop ([i index])
                (unless (fx= i len)
                  (#3%vector-set! vec
                                  (fx+ i 1)
                                  (core-pvector-ref/unchecked pv i))
                  (loop (fx+ i 1))))
              (core-vector->pvector/no-copy
               (#3%vector->immutable-vector vec)))))])))

(define (core-pvector-delete pv index)
  (let* ([len (core-check-index 'core-pvector-delete pv index)]
         [deleted (core-pvector-ref/unchecked pv index)])
    (values
     (cond
      [(fx= len 1) empty-core-pvector]
      [else
       (let ([direct (if (core-pvector-large-finger? pv)
                         (core-pvector-large-finger-delete pv index)
                         #f)])
         (if direct
             direct
             (let ([vec (make-vector (fx- len 1))])
               (let loop ([i 0])
                 (unless (fx= i index)
                   (#3%vector-set! vec i (core-pvector-ref/unchecked pv i))
                   (loop (fx+ i 1))))
               (let loop ([i (fx+ index 1)])
                 (unless (fx= i len)
                   (#3%vector-set! vec
                                   (fx- i 1)
                                   (core-pvector-ref/unchecked pv i))
                   (loop (fx+ i 1))))
               (core-vector->pvector/no-copy
                (#3%vector->immutable-vector vec)))))])
     deleted)))

(define (core-pvector-map pv proc)
  (let ([len (core-pvector-length pv)])
    (cond
     [(fx= len 0) empty-core-pvector]
     [(eq? proc values) pv]
     [(eq? proc void) (core-make-pvector len (void))]
     [else
      (let ([vec (make-vector len)])
        (let ([i 0])
          (core-pvector-for-each-range
           pv
           0
           len
           (lambda (elem)
             (#3%vector-set! vec i (proc elem))
             (set! i (fx+ i 1)))))
        (core-vector->pvector/no-copy (#3%vector->immutable-vector vec)))])))

(define (core-pvector-for-each pv proc)
  (unless (or (eq? proc values) (eq? proc void))
    (let ([len (core-pvector-length pv)])
      (core-pvector-for-each-range pv 0 len proc)))
  (void))

(define (core-pvector->list pv)
  (let ([len (core-pvector-length pv)])
    (let ([vec (make-vector len)])
      (core-pvector-fill-vector! vec 0 pv)
      (let loop ([i (fx- len 1)] [acc '()])
        (if (fx< i 0)
            acc
            (loop (fx- i 1) (cons (#3%vector-ref vec i) acc)))))))

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
