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

(define-record-type (core-pvector-large-finger
                     %make-core-pvector-large-finger
                     core-pvector-large-finger?)
  [fields (immutable length)
          (immutable prefix-length)
          (immutable middle)
          (immutable suffix-length)
          (immutable p0)
          (immutable p1)
          (immutable p2)
          (immutable p3)
          (immutable s0)
          (immutable s1)
          (immutable s2)
          (immutable s3)]
  [nongenerative #{core-pvector-large-finger cutie-pvector-runtime-native-7-inline-digits}]
  [sealed #t])

(define-record-type core-pvector-cursor
  [fields (mutable value)
          (mutable stack)]
  [nongenerative #{core-pvector-cursor cutie-pvector-runtime-native-cursor-1}]
  [sealed #t])

(define-record-type core-pvector-cursor-digit-frame
  [fields (immutable pv)
          (immutable prefix?)
          (mutable index)
          (immutable end)
          (immutable step)]
  [nongenerative #{core-pvector-cursor-digit-frame cutie-pvector-runtime-native-cursor-4-inline-digits}]
  [sealed #t])

(define-record-type core-pvector-cursor-node-frame
  [fields (immutable node)
          (immutable reverse?)
          (mutable index)
          (immutable end)
          (immutable step)]
  [nongenerative #{core-pvector-cursor-node-frame cutie-pvector-runtime-native-cursor-3}]
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

(define (core-check-pvector who pv)
  (unless (core-pvector? pv)
    (raise-argument-error who "pvector?" pv))
  pv)

(define (core-pvector-length/unchecked pv)
  (cond
   [(core-pvector-empty-record? pv) 0]
   [(core-pvector-inline? pv) (core-pvector-inline-length pv)]
   [else (core-pvector-large-finger-length pv)]))

(define (core-pvector-length pv)
  (core-pvector-length/unchecked
   (core-check-pvector 'core-pvector-length pv)))

(define (make-core-pvector-large-finger/inline
         len prefix-len middle suffix-len p0 p1 p2 p3 s0 s1 s2 s3)
  (%make-core-pvector-large-finger
   len prefix-len middle suffix-len p0 p1 p2 p3 s0 s1 s2 s3))

(define (make-core-pvector-large-finger len prefix middle suffix)
  (let ([prefix-len (#%vector-length prefix)]
        [suffix-len (#%vector-length suffix)])
    (make-core-pvector-large-finger/inline
     len
     prefix-len
     middle
     suffix-len
     (if (fx< 0 prefix-len) (#3%vector-ref prefix 0) #f)
     (if (fx< 1 prefix-len) (#3%vector-ref prefix 1) #f)
     (if (fx< 2 prefix-len) (#3%vector-ref prefix 2) #f)
     (if (fx< 3 prefix-len) (#3%vector-ref prefix 3) #f)
     (if (fx< 0 suffix-len) (#3%vector-ref suffix 0) #f)
     (if (fx< 1 suffix-len) (#3%vector-ref suffix 1) #f)
     (if (fx< 2 suffix-len) (#3%vector-ref suffix 2) #f)
     (if (fx< 3 suffix-len) (#3%vector-ref suffix 3) #f))))

(define (make-core-pvector-large-finger/from-vector-ranges
         len vec prefix-start prefix-len middle suffix-start suffix-len)
  (make-core-pvector-large-finger/inline
   len
   prefix-len
   middle
   suffix-len
   (if (fx< 0 prefix-len) (#3%vector-ref vec prefix-start) #f)
   (if (fx< 1 prefix-len) (#3%vector-ref vec (fx+ prefix-start 1)) #f)
   (if (fx< 2 prefix-len) (#3%vector-ref vec (fx+ prefix-start 2)) #f)
   (if (fx< 3 prefix-len) (#3%vector-ref vec (fx+ prefix-start 3)) #f)
   (if (fx< 0 suffix-len) (#3%vector-ref vec suffix-start) #f)
   (if (fx< 1 suffix-len) (#3%vector-ref vec (fx+ suffix-start 1)) #f)
   (if (fx< 2 suffix-len) (#3%vector-ref vec (fx+ suffix-start 2)) #f)
   (if (fx< 3 suffix-len) (#3%vector-ref vec (fx+ suffix-start 3)) #f)))

(define (core-pvector-large-finger-prefix-ref pv index)
  (cond
   [(fx= index 0) (core-pvector-large-finger-p0 pv)]
   [(fx= index 1) (core-pvector-large-finger-p1 pv)]
   [(fx= index 2) (core-pvector-large-finger-p2 pv)]
   [else (core-pvector-large-finger-p3 pv)]))

(define (core-pvector-large-finger-suffix-ref pv index)
  (cond
   [(fx= index 0) (core-pvector-large-finger-s0 pv)]
   [(fx= index 1) (core-pvector-large-finger-s1 pv)]
   [(fx= index 2) (core-pvector-large-finger-s2 pv)]
   [else (core-pvector-large-finger-s3 pv)]))

(define (core-pvector-large-finger-prefix pv)
  (let ([len (core-pvector-large-finger-prefix-length pv)])
    (cond
     [(fx= len 1)
      (core-immutable-vector1 (core-pvector-large-finger-p0 pv))]
     [(fx= len 2)
      (core-immutable-vector2 (core-pvector-large-finger-p0 pv)
                              (core-pvector-large-finger-p1 pv))]
     [(fx= len 3)
      (core-immutable-vector3 (core-pvector-large-finger-p0 pv)
                              (core-pvector-large-finger-p1 pv)
                              (core-pvector-large-finger-p2 pv))]
     [else
      (core-immutable-vector4 (core-pvector-large-finger-p0 pv)
                              (core-pvector-large-finger-p1 pv)
                              (core-pvector-large-finger-p2 pv)
                              (core-pvector-large-finger-p3 pv))])))

(define (core-pvector-large-finger-suffix pv)
  (let ([len (core-pvector-large-finger-suffix-length pv)])
    (cond
     [(fx= len 1)
      (core-immutable-vector1 (core-pvector-large-finger-s0 pv))]
     [(fx= len 2)
      (core-immutable-vector2 (core-pvector-large-finger-s0 pv)
                              (core-pvector-large-finger-s1 pv))]
     [(fx= len 3)
      (core-immutable-vector3 (core-pvector-large-finger-s0 pv)
                              (core-pvector-large-finger-s1 pv)
                              (core-pvector-large-finger-s2 pv))]
     [else
      (core-immutable-vector4 (core-pvector-large-finger-s0 pv)
                              (core-pvector-large-finger-s1 pv)
                              (core-pvector-large-finger-s2 pv)
                              (core-pvector-large-finger-s3 pv))])))

(define (core-pvector-large-finger-edge-length pv prefix?)
  (if prefix?
      (core-pvector-large-finger-prefix-length pv)
      (core-pvector-large-finger-suffix-length pv)))

(define (core-pvector-large-finger-edge-ref pv prefix? index)
  (if prefix?
      (core-pvector-large-finger-prefix-ref pv index)
      (core-pvector-large-finger-suffix-ref pv index)))

(define (core-pvector-large-finger-prefix->list-all pv len acc)
  (cond
   [(fx= len 0) acc]
   [(fx= len 1)
    (cons (core-pvector-large-finger-p0 pv) acc)]
   [(fx= len 2)
    (cons (core-pvector-large-finger-p0 pv)
          (cons (core-pvector-large-finger-p1 pv) acc))]
   [(fx= len 3)
    (cons (core-pvector-large-finger-p0 pv)
          (cons (core-pvector-large-finger-p1 pv)
                (cons (core-pvector-large-finger-p2 pv) acc)))]
   [else
    (cons (core-pvector-large-finger-p0 pv)
          (cons (core-pvector-large-finger-p1 pv)
                (cons (core-pvector-large-finger-p2 pv)
                      (cons (core-pvector-large-finger-p3 pv) acc))))]))

(define (core-pvector-large-finger-suffix->list-all pv len acc)
  (cond
   [(fx= len 0) acc]
   [(fx= len 1)
    (cons (core-pvector-large-finger-s0 pv) acc)]
   [(fx= len 2)
    (cons (core-pvector-large-finger-s0 pv)
          (cons (core-pvector-large-finger-s1 pv) acc))]
   [(fx= len 3)
    (cons (core-pvector-large-finger-s0 pv)
          (cons (core-pvector-large-finger-s1 pv)
                (cons (core-pvector-large-finger-s2 pv) acc)))]
   [else
    (cons (core-pvector-large-finger-s0 pv)
          (cons (core-pvector-large-finger-s1 pv)
                (cons (core-pvector-large-finger-s2 pv)
                      (cons (core-pvector-large-finger-s3 pv) acc))))]))

(define (core-pvector-large-finger-prefix-fill-all! dest offset pv len)
  (cond
   [(fx= len 0) offset]
   [(fx= len 1)
    (#3%vector-set! dest offset (core-pvector-large-finger-p0 pv))
    (fx+ offset 1)]
   [(fx= len 2)
    (#3%vector-set! dest offset (core-pvector-large-finger-p0 pv))
    (#3%vector-set! dest (fx+ offset 1) (core-pvector-large-finger-p1 pv))
    (fx+ offset 2)]
   [(fx= len 3)
    (#3%vector-set! dest offset (core-pvector-large-finger-p0 pv))
    (#3%vector-set! dest (fx+ offset 1) (core-pvector-large-finger-p1 pv))
    (#3%vector-set! dest (fx+ offset 2) (core-pvector-large-finger-p2 pv))
    (fx+ offset 3)]
   [else
    (#3%vector-set! dest offset (core-pvector-large-finger-p0 pv))
    (#3%vector-set! dest (fx+ offset 1) (core-pvector-large-finger-p1 pv))
    (#3%vector-set! dest (fx+ offset 2) (core-pvector-large-finger-p2 pv))
    (#3%vector-set! dest (fx+ offset 3) (core-pvector-large-finger-p3 pv))
    (fx+ offset 4)]))

(define (core-pvector-large-finger-suffix-fill-all! dest offset pv len)
  (cond
   [(fx= len 0) offset]
   [(fx= len 1)
    (#3%vector-set! dest offset (core-pvector-large-finger-s0 pv))
    (fx+ offset 1)]
   [(fx= len 2)
    (#3%vector-set! dest offset (core-pvector-large-finger-s0 pv))
    (#3%vector-set! dest (fx+ offset 1) (core-pvector-large-finger-s1 pv))
    (fx+ offset 2)]
   [(fx= len 3)
    (#3%vector-set! dest offset (core-pvector-large-finger-s0 pv))
    (#3%vector-set! dest (fx+ offset 1) (core-pvector-large-finger-s1 pv))
    (#3%vector-set! dest (fx+ offset 2) (core-pvector-large-finger-s2 pv))
    (fx+ offset 3)]
   [else
    (#3%vector-set! dest offset (core-pvector-large-finger-s0 pv))
    (#3%vector-set! dest (fx+ offset 1) (core-pvector-large-finger-s1 pv))
    (#3%vector-set! dest (fx+ offset 2) (core-pvector-large-finger-s2 pv))
    (#3%vector-set! dest (fx+ offset 3) (core-pvector-large-finger-s3 pv))
    (fx+ offset 4)]))

(define (core-pvector-large-finger-prefix-map-all! dest offset pv len proc)
  (cond
   [(fx= len 0) offset]
   [(fx= len 1)
    (#3%vector-set! dest offset (proc (core-pvector-large-finger-p0 pv)))
    (fx+ offset 1)]
   [(fx= len 2)
    (#3%vector-set! dest offset (proc (core-pvector-large-finger-p0 pv)))
    (#3%vector-set! dest (fx+ offset 1) (proc (core-pvector-large-finger-p1 pv)))
    (fx+ offset 2)]
   [(fx= len 3)
    (#3%vector-set! dest offset (proc (core-pvector-large-finger-p0 pv)))
    (#3%vector-set! dest (fx+ offset 1) (proc (core-pvector-large-finger-p1 pv)))
    (#3%vector-set! dest (fx+ offset 2) (proc (core-pvector-large-finger-p2 pv)))
    (fx+ offset 3)]
   [else
    (#3%vector-set! dest offset (proc (core-pvector-large-finger-p0 pv)))
    (#3%vector-set! dest (fx+ offset 1) (proc (core-pvector-large-finger-p1 pv)))
    (#3%vector-set! dest (fx+ offset 2) (proc (core-pvector-large-finger-p2 pv)))
    (#3%vector-set! dest (fx+ offset 3) (proc (core-pvector-large-finger-p3 pv)))
    (fx+ offset 4)]))

(define (core-pvector-large-finger-suffix-map-all! dest offset pv len proc)
  (cond
   [(fx= len 0) offset]
   [(fx= len 1)
    (#3%vector-set! dest offset (proc (core-pvector-large-finger-s0 pv)))
    (fx+ offset 1)]
   [(fx= len 2)
    (#3%vector-set! dest offset (proc (core-pvector-large-finger-s0 pv)))
    (#3%vector-set! dest (fx+ offset 1) (proc (core-pvector-large-finger-s1 pv)))
    (fx+ offset 2)]
   [(fx= len 3)
    (#3%vector-set! dest offset (proc (core-pvector-large-finger-s0 pv)))
    (#3%vector-set! dest (fx+ offset 1) (proc (core-pvector-large-finger-s1 pv)))
    (#3%vector-set! dest (fx+ offset 2) (proc (core-pvector-large-finger-s2 pv)))
    (fx+ offset 3)]
   [else
    (#3%vector-set! dest offset (proc (core-pvector-large-finger-s0 pv)))
    (#3%vector-set! dest (fx+ offset 1) (proc (core-pvector-large-finger-s1 pv)))
    (#3%vector-set! dest (fx+ offset 2) (proc (core-pvector-large-finger-s2 pv)))
    (#3%vector-set! dest (fx+ offset 3) (proc (core-pvector-large-finger-s3 pv)))
    (fx+ offset 4)]))

(define (core-pvector-large-finger-prefix-for-each-all pv len proc)
  (cond
   [(fx= len 0) (void)]
   [(fx= len 1)
    (proc (core-pvector-large-finger-p0 pv))]
   [(fx= len 2)
    (proc (core-pvector-large-finger-p0 pv))
    (proc (core-pvector-large-finger-p1 pv))]
   [(fx= len 3)
    (proc (core-pvector-large-finger-p0 pv))
    (proc (core-pvector-large-finger-p1 pv))
    (proc (core-pvector-large-finger-p2 pv))]
   [else
    (proc (core-pvector-large-finger-p0 pv))
    (proc (core-pvector-large-finger-p1 pv))
    (proc (core-pvector-large-finger-p2 pv))
    (proc (core-pvector-large-finger-p3 pv))]))

(define (core-pvector-large-finger-suffix-for-each-all pv len proc)
  (cond
   [(fx= len 0) (void)]
   [(fx= len 1)
    (proc (core-pvector-large-finger-s0 pv))]
   [(fx= len 2)
    (proc (core-pvector-large-finger-s0 pv))
    (proc (core-pvector-large-finger-s1 pv))]
   [(fx= len 3)
    (proc (core-pvector-large-finger-s0 pv))
    (proc (core-pvector-large-finger-s1 pv))
    (proc (core-pvector-large-finger-s2 pv))]
   [else
    (proc (core-pvector-large-finger-s0 pv))
    (proc (core-pvector-large-finger-s1 pv))
    (proc (core-pvector-large-finger-s2 pv))
    (proc (core-pvector-large-finger-s3 pv))]))

(define (core-pvector-large-finger-prefix-fold-left-all pv len acc proc)
  (cond
   [(fx= len 0) acc]
   [(fx= len 1)
    (proc acc (core-pvector-large-finger-p0 pv))]
   [(fx= len 2)
    (let ([acc (proc acc (core-pvector-large-finger-p0 pv))])
      (proc acc (core-pvector-large-finger-p1 pv)))]
   [(fx= len 3)
    (let* ([acc (proc acc (core-pvector-large-finger-p0 pv))]
           [acc (proc acc (core-pvector-large-finger-p1 pv))])
      (proc acc (core-pvector-large-finger-p2 pv)))]
   [else
    (let* ([acc (proc acc (core-pvector-large-finger-p0 pv))]
           [acc (proc acc (core-pvector-large-finger-p1 pv))]
           [acc (proc acc (core-pvector-large-finger-p2 pv))])
      (proc acc (core-pvector-large-finger-p3 pv)))]))

(define (core-pvector-large-finger-suffix-fold-left-all pv len acc proc)
  (cond
   [(fx= len 0) acc]
   [(fx= len 1)
    (proc acc (core-pvector-large-finger-s0 pv))]
   [(fx= len 2)
    (let ([acc (proc acc (core-pvector-large-finger-s0 pv))])
      (proc acc (core-pvector-large-finger-s1 pv)))]
   [(fx= len 3)
    (let* ([acc (proc acc (core-pvector-large-finger-s0 pv))]
           [acc (proc acc (core-pvector-large-finger-s1 pv))])
      (proc acc (core-pvector-large-finger-s2 pv)))]
   [else
    (let* ([acc (proc acc (core-pvector-large-finger-s0 pv))]
           [acc (proc acc (core-pvector-large-finger-s1 pv))]
           [acc (proc acc (core-pvector-large-finger-s2 pv))])
      (proc acc (core-pvector-large-finger-s3 pv)))]))

(define (core-pvector-large-finger-edge-copy-range/immutable
         pv prefix? start end)
  (let ([len (fx- end start)])
    (cond
     [(fx= len 0)
      (inline:vector-immutable)]
     [(fx= len 1)
      (core-immutable-vector1
       (core-pvector-large-finger-edge-ref pv prefix? start))]
     [(fx= len 2)
      (core-immutable-vector2
       (core-pvector-large-finger-edge-ref pv prefix? start)
       (core-pvector-large-finger-edge-ref pv prefix? (fx+ start 1)))]
     [(fx= len 3)
      (core-immutable-vector3
       (core-pvector-large-finger-edge-ref pv prefix? start)
       (core-pvector-large-finger-edge-ref pv prefix? (fx+ start 1))
       (core-pvector-large-finger-edge-ref pv prefix? (fx+ start 2)))]
     [else
      (core-immutable-vector4
       (core-pvector-large-finger-edge-ref pv prefix? start)
       (core-pvector-large-finger-edge-ref pv prefix? (fx+ start 1))
       (core-pvector-large-finger-edge-ref pv prefix? (fx+ start 2))
       (core-pvector-large-finger-edge-ref pv prefix? (fx+ start 3)))])))

(define (core-pvector-large-finger-edge-fill-range!
         dest dest-offset pv prefix? start end)
  (let loop ([i start] [offset dest-offset])
    (if (fx= i end)
        offset
        (begin
          (#3%vector-set!
           dest
           offset
           (core-pvector-large-finger-edge-ref pv prefix? i))
          (loop (fx+ i 1) (fx+ offset 1))))))

(define (core-pvector-large-finger-edge-map-range!
         dest dest-offset pv prefix? start end proc)
  (let loop ([i start] [offset dest-offset])
    (if (fx= i end)
        offset
        (begin
          (#3%vector-set!
           dest
           offset
           (proc (core-pvector-large-finger-edge-ref pv prefix? i)))
          (loop (fx+ i 1) (fx+ offset 1))))))

(define (core-pvector-large-finger-edge-segment-fill-range!
         dest offset pv prefix? start end segment-start segment-end)
  (let ([copy-start (fxmax start segment-start)]
        [copy-end (fxmin end segment-end)])
    (if (fx< copy-start copy-end)
        (core-pvector-large-finger-edge-fill-range!
         dest
         offset
         pv
         prefix?
         (fx- copy-start segment-start)
         (fx- copy-end segment-start))
        offset)))

(define (core-pvector-large-finger-edge-segment-map-range!
         dest offset pv prefix? start end segment-start segment-end proc)
  (let ([map-start (fxmax start segment-start)]
        [map-end (fxmin end segment-end)])
    (if (fx< map-start map-end)
        (core-pvector-large-finger-edge-map-range!
         dest
         offset
         pv
         prefix?
         (fx- map-start segment-start)
         (fx- map-end segment-start)
         proc)
        offset)))

(define (core-pvector-large-finger-edge-for-each-range
         pv prefix? start end proc)
  (let loop ([i start])
    (unless (fx= i end)
      (proc (core-pvector-large-finger-edge-ref pv prefix? i))
      (loop (fx+ i 1)))))

(define (core-pvector-large-finger-edge-segment-for-each-range
         pv prefix? start end segment-start segment-end proc)
  (let ([visit-start (fxmax start segment-start)]
        [visit-end (fxmin end segment-end)])
    (when (fx< visit-start visit-end)
      (core-pvector-large-finger-edge-for-each-range
       pv
       prefix?
       (fx- visit-start segment-start)
       (fx- visit-end segment-start)
       proc))))

(define (core-pvector-large-finger-edge->list-range
         pv prefix? start end acc)
  (let loop ([i (fx- end 1)] [acc acc])
    (if (fx< i start)
        acc
        (loop (fx- i 1)
              (cons (core-pvector-large-finger-edge-ref pv prefix? i) acc)))))

(define (core-pvector-large-finger-edge-segment->list-range
         pv prefix? start end segment-start segment-end acc)
  (let ([copy-start (fxmax start segment-start)]
        [copy-end (fxmin end segment-end)])
    (if (fx< copy-start copy-end)
        (core-pvector-large-finger-edge->list-range
         pv
         prefix?
         (fx- copy-start segment-start)
         (fx- copy-end segment-start)
         acc)
        acc)))

(define (core-pvector-large-finger-with-prefix-vector pv len prefix middle)
  (let ([prefix-len (#%vector-length prefix)]
        [suffix-len (core-pvector-large-finger-suffix-length pv)])
    (make-core-pvector-large-finger/inline
     len
     prefix-len
     middle
     suffix-len
     (if (fx< 0 prefix-len) (#3%vector-ref prefix 0) #f)
     (if (fx< 1 prefix-len) (#3%vector-ref prefix 1) #f)
     (if (fx< 2 prefix-len) (#3%vector-ref prefix 2) #f)
     (if (fx< 3 prefix-len) (#3%vector-ref prefix 3) #f)
     (core-pvector-large-finger-s0 pv)
     (core-pvector-large-finger-s1 pv)
     (core-pvector-large-finger-s2 pv)
     (core-pvector-large-finger-s3 pv))))

(define (core-pvector-large-finger-with-suffix-vector pv len middle suffix)
  (let ([prefix-len (core-pvector-large-finger-prefix-length pv)]
        [suffix-len (#%vector-length suffix)])
    (make-core-pvector-large-finger/inline
     len
     prefix-len
     middle
     suffix-len
     (core-pvector-large-finger-p0 pv)
     (core-pvector-large-finger-p1 pv)
     (core-pvector-large-finger-p2 pv)
     (core-pvector-large-finger-p3 pv)
     (if (fx< 0 suffix-len) (#3%vector-ref suffix 0) #f)
     (if (fx< 1 suffix-len) (#3%vector-ref suffix 1) #f)
     (if (fx< 2 suffix-len) (#3%vector-ref suffix 2) #f)
     (if (fx< 3 suffix-len) (#3%vector-ref suffix 3) #f))))

(define (core-pvector-large-finger-with-middle pv len middle)
  (make-core-pvector-large-finger/inline
   len
   (core-pvector-large-finger-prefix-length pv)
   middle
   (core-pvector-large-finger-suffix-length pv)
   (core-pvector-large-finger-p0 pv)
   (core-pvector-large-finger-p1 pv)
   (core-pvector-large-finger-p2 pv)
   (core-pvector-large-finger-p3 pv)
   (core-pvector-large-finger-s0 pv)
   (core-pvector-large-finger-s1 pv)
   (core-pvector-large-finger-s2 pv)
   (core-pvector-large-finger-s3 pv)))

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

(define (core-pvector-large-finger-full-edge->node pv prefix?)
  (make-core-pvector-node2
   4
   2
   (core-make-leaf-node2
    (core-pvector-large-finger-edge-ref pv prefix? 0)
    (core-pvector-large-finger-edge-ref pv prefix? 1))
   (core-make-leaf-node2
    (core-pvector-large-finger-edge-ref pv prefix? 2)
    (core-pvector-large-finger-edge-ref pv prefix? 3))))

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
      (let ([remainder (fx- len (fx* 3 (fxquotient len 3)))])
        (cond
         [(fx= remainder 1) (values 2 2)]
         [(fx= remainder 2) (values 3 2)]
         [else (values 3 3)]))))

(define (core-vector->large-finger vec len)
  (let-values ([(prefix-len suffix-len)
                (core-pvector-deep-edge-lengths len)])
    (let* ([suffix-start (fx- len suffix-len)]
           [middle-len (fx- suffix-start prefix-len)]
           [middle
            (if (fx= middle-len 0)
                #f
                (core-build-node-tree
                 (core-vector-copy-range
                  vec
                  prefix-len
                  suffix-start)))])
      (make-core-pvector-large-finger/from-vector-ranges
       len
       vec
       0
       prefix-len
       middle
       suffix-start
       suffix-len))))

(define (core-pvector-large-finger-ref/known-length pv len index)
  (let ([prefix-len (core-pvector-large-finger-prefix-length pv)])
    (if (fx< index prefix-len)
        (core-pvector-large-finger-prefix-ref pv index)
        (let* ([suffix-len (core-pvector-large-finger-suffix-length pv)]
               [suffix-start (fx- len suffix-len)])
          (if (fx< index suffix-start)
              (core-pvector-node-ref
               (core-pvector-large-finger-middle pv)
               (fx- index prefix-len))
              (core-pvector-large-finger-suffix-ref
               pv
               (fx- index suffix-start)))))))

(define (core-pvector-large-finger-ref/known-pieces
         prefix prefix-len middle suffix suffix-start index)
  (if (fx< index prefix-len)
      (#3%vector-ref prefix index)
      (if (fx< index suffix-start)
          (core-pvector-node-ref middle (fx- index prefix-len))
          (#3%vector-ref suffix (fx- index suffix-start)))))

(define (core-pvector-large-finger-range->immutable-vector-short/known-length
         pv len start range-len)
  (cond
   [(fx= range-len 2)
    (core-immutable-vector2
     (core-pvector-large-finger-ref/known-length pv len start)
     (core-pvector-large-finger-ref/known-length pv len (fx+ start 1)))]
   [(fx= range-len 3)
    (core-immutable-vector3
     (core-pvector-large-finger-ref/known-length pv len start)
     (core-pvector-large-finger-ref/known-length pv len (fx+ start 1))
     (core-pvector-large-finger-ref/known-length pv len (fx+ start 2)))]
   [else
    (core-immutable-vector4
     (core-pvector-large-finger-ref/known-length pv len start)
     (core-pvector-large-finger-ref/known-length pv len (fx+ start 1))
     (core-pvector-large-finger-ref/known-length pv len (fx+ start 2))
     (core-pvector-large-finger-ref/known-length pv len (fx+ start 3)))]))

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
  (cond
   [(fx= new-len 2)
    (core-make-deep2-pvector
     (core-pvector-large-finger-ref/known-length pv len start)
     (core-pvector-large-finger-ref/known-length pv len (fx+ start 1)))]
   [(fx= new-len 3)
    (core-make-deep3-pvector
     (core-pvector-large-finger-ref/known-length pv len start)
     (core-pvector-large-finger-ref/known-length pv len (fx+ start 1))
     (core-pvector-large-finger-ref/known-length pv len (fx+ start 2)))]
   [else
    (core-make-deep4-pvector
     (core-pvector-large-finger-ref/known-length pv len start)
     (core-pvector-large-finger-ref/known-length pv len (fx+ start 1))
     (core-pvector-large-finger-ref/known-length pv len (fx+ start 2))
     (core-pvector-large-finger-ref/known-length pv len (fx+ start 3)))]))

(define (core-pvector-large-finger-edge-range->immutable-vector
         pv len prefix-len suffix-len middle-end start end)
  (cond
   [(fx<= end prefix-len)
    (if (and (fx= start 0) (fx= end prefix-len))
        (core-pvector-large-finger-prefix pv)
        (core-pvector-large-finger-edge-copy-range/immutable
         pv #t start end))]
   [(fx>= start middle-end)
    (let ([suffix-start (fx- start middle-end)]
          [suffix-end (fx- end middle-end)])
      (if (and (fx= suffix-start 0) (fx= suffix-end suffix-len))
          (core-pvector-large-finger-suffix pv)
          (core-pvector-large-finger-edge-copy-range/immutable
           pv
           #f
           suffix-start
           suffix-end)))]
   [else
    (core-pvector-range->immutable-vector/known-length pv len start end)]))

(define (core-pvector-large-finger-copy/known-length pv len start end)
  (let* ([new-len (fx- end start)]
         [middle (core-pvector-large-finger-middle pv)]
         [prefix-len (core-pvector-large-finger-prefix-length pv)]
         [suffix-len (core-pvector-large-finger-suffix-length pv)]
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
                                   prefix-len
                                   suffix-len
                                   middle-end
                                   start
                                    middle-copy-start)
                                   new-middle
                                   (core-pvector-large-finger-edge-range->immutable-vector
                                   pv
                                   len
                                   prefix-len
                                   suffix-len
                                   middle-end
                                   middle-copy-end
                                    end))
                                  (suffix-loop (fx+ edge-suffix-len 1))))
                            (suffix-loop (fx+ edge-suffix-len 1))))]))))))))

(define (core-pvector-large-finger-cons-left/known-length pv len value)
  (let* ([prefix-len (core-pvector-large-finger-prefix-length pv)]
         [new-len (fx+ len 1)])
    (if (fx< prefix-len core-pvector-digit-max)
        (core-pvector-large-finger-with-prefix-vector
         pv
         new-len
         (core-vector-insert/immutable
          (core-pvector-large-finger-prefix pv)
          prefix-len
          0
          value)
         (core-pvector-large-finger-middle pv))
        (let* ([bridge (core-pvector-large-finger-full-edge->node pv #t)]
               [old-middle (core-pvector-large-finger-middle pv)]
               [middle (if old-middle
                           (core-pvector-node-link2 bridge old-middle)
                           bridge)])
          (core-pvector-large-finger-with-prefix-vector
           pv
           new-len
           (core-immutable-vector1 value)
           middle)))))

(define (core-pvector-large-finger-cons-left pv value)
  (core-pvector-large-finger-cons-left/known-length
   pv
   (core-pvector-large-finger-length pv)
   value))

(define (core-pvector-large-finger-cons-right/known-length pv len value)
  (let* ([suffix-len (core-pvector-large-finger-suffix-length pv)]
         [new-len (fx+ len 1)])
    (if (fx< suffix-len core-pvector-digit-max)
        (core-pvector-large-finger-with-suffix-vector
         pv
         new-len
         (core-pvector-large-finger-middle pv)
         (core-vector-insert/immutable
          (core-pvector-large-finger-suffix pv)
          suffix-len
          suffix-len
          value))
        (let* ([bridge (core-pvector-large-finger-full-edge->node pv #f)]
               [old-middle (core-pvector-large-finger-middle pv)]
               [middle (if old-middle
                           (core-pvector-node-link2 old-middle bridge)
                           bridge)])
          (core-pvector-large-finger-with-suffix-vector
           pv
           new-len
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
  (let ([prefix-len (core-pvector-large-finger-prefix-length pv)])
    (if (fx< index prefix-len)
        (if (eq? (core-pvector-large-finger-prefix-ref pv index) value)
            pv
            (core-pvector-large-finger-with-prefix-vector
             pv
             len
             (core-vector-set/immutable
              (core-pvector-large-finger-prefix pv)
              prefix-len
              index
              value)
             (core-pvector-large-finger-middle pv)))
        (let* ([suffix-len (core-pvector-large-finger-suffix-length pv)]
               [suffix-start (fx- len suffix-len)])
          (if (fx>= index suffix-start)
              (let ([suffix-index (fx- index suffix-start)])
                (if (eq? (core-pvector-large-finger-suffix-ref pv suffix-index) value)
                    pv
                    (core-pvector-large-finger-with-suffix-vector
                     pv
                     len
                     (core-pvector-large-finger-middle pv)
                     (core-vector-set/immutable
                      (core-pvector-large-finger-suffix pv)
                      suffix-len
                      suffix-index
                      value))))
              (let* ([middle (core-pvector-large-finger-middle pv)]
                     [middle-index (fx- index prefix-len)])
                (if (eq? (core-pvector-node-ref middle middle-index) value)
                    pv
                    (core-pvector-large-finger-with-middle
                     pv
                     len
                     (core-pvector-node-set middle middle-index value)))))))))

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
  (let* ([prefix-len (core-pvector-large-finger-prefix-length pv)]
         [new-len (fx+ len 1)])
    (if (and (fx<= index prefix-len)
             (fx< prefix-len core-pvector-digit-max))
        (core-pvector-large-finger-with-prefix-vector
         pv
         new-len
         (core-vector-insert/immutable
          (core-pvector-large-finger-prefix pv)
          prefix-len
          index
          value)
         (core-pvector-large-finger-middle pv))
        (let* ([suffix-len (core-pvector-large-finger-suffix-length pv)]
               [suffix-start (fx- len suffix-len)])
          (if (and (fx>= index suffix-start)
                   (fx< suffix-len core-pvector-digit-max))
              (core-pvector-large-finger-with-suffix-vector
               pv
               new-len
               (core-pvector-large-finger-middle pv)
               (core-vector-insert/immutable
                (core-pvector-large-finger-suffix pv)
                suffix-len
                (fx- index suffix-start)
                value))
              (core-pvector-insert-by-copy/unchecked pv len index value))))))

(define (core-pvector-large-finger-delete/known-length pv len index)
  (let* ([new-len (fx- len 1)]
         [prefix-len (core-pvector-large-finger-prefix-length pv)])
    (cond
     [(fx< index prefix-len)
      (if (fx> prefix-len 1)
           (core-pvector-large-finger-with-prefix-vector
            pv
            new-len
            (core-vector-remove/immutable
             (core-pvector-large-finger-prefix pv)
             prefix-len
             index)
            (core-pvector-large-finger-middle pv))
          (core-pvector-delete-by-copy/unchecked pv len index))]
     [else
      (let* ([suffix-len (core-pvector-large-finger-suffix-length pv)]
             [suffix-start (fx- len suffix-len)])
        (if (and (fx>= index suffix-start)
                 (fx> suffix-len 1))
            (core-pvector-large-finger-with-suffix-vector
             pv
             new-len
             (core-pvector-large-finger-middle pv)
             (core-vector-remove/immutable
              (core-pvector-large-finger-suffix pv)
              suffix-len
              (fx- index suffix-start)))
            (core-pvector-delete-by-copy/unchecked pv len index)))])))

(define (core-pvector-large-finger-delete-edge-view+rest/known-length pv len index)
  (let* ([new-len (fx- len 1)]
         [prefix-len (core-pvector-large-finger-prefix-length pv)])
    (cond
     [(fx< index prefix-len)
      (if (fx> prefix-len 1)
          (values
           (core-pvector-large-finger-prefix-ref pv index)
           (core-pvector-large-finger-with-prefix-vector
            pv
            new-len
            (core-vector-remove/immutable
             (core-pvector-large-finger-prefix pv)
             prefix-len
             index)
            (core-pvector-large-finger-middle pv)))
          (values #f #f))]
     [else
      (let* ([suffix-len (core-pvector-large-finger-suffix-length pv)]
             [suffix-start (fx- len suffix-len)])
        (if (and (fx>= index suffix-start)
                 (fx> suffix-len 1))
            (let ([suffix-index (fx- index suffix-start)])
              (values
               (core-pvector-large-finger-suffix-ref pv suffix-index)
               (core-pvector-large-finger-with-suffix-vector
                pv
                new-len
                (core-pvector-large-finger-middle pv)
                (core-vector-remove/immutable
                 (core-pvector-large-finger-suffix pv)
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
  (let ([prefix-len (core-pvector-large-finger-prefix-length pv)])
    (and (fx> prefix-len 1)
         (core-pvector-large-finger-with-prefix-vector
          pv
          (fx- len 1)
          (core-vector-remove/immutable
           (core-pvector-large-finger-prefix pv)
           prefix-len
           0)
          (core-pvector-large-finger-middle pv)))))

(define (core-pvector-large-finger-pop-left-rest/direct pv)
  (core-pvector-large-finger-pop-left-rest/known-length
   pv
   (core-pvector-large-finger-length pv)))

(define (core-pvector-large-finger-pop-left-view+rest/known-length pv len)
  (let* ([prefix-len (core-pvector-large-finger-prefix-length pv)]
         [value (core-pvector-large-finger-p0 pv)])
    (values value
            (and (fx> prefix-len 1)
                 (core-pvector-large-finger-with-prefix-vector
                  pv
                  (fx- len 1)
                  (core-vector-remove/immutable
                   (core-pvector-large-finger-prefix pv)
                   prefix-len
                   0)
                  (core-pvector-large-finger-middle pv))))))

(define (core-pvector-large-finger-pop-right-rest/known-length pv len)
  (let ([suffix-len (core-pvector-large-finger-suffix-length pv)])
    (and (fx> suffix-len 1)
         (core-pvector-large-finger-with-suffix-vector
          pv
          (fx- len 1)
          (core-pvector-large-finger-middle pv)
          (core-vector-remove/immutable
           (core-pvector-large-finger-suffix pv)
           suffix-len
           (fx- suffix-len 1))))))

(define (core-pvector-large-finger-pop-right-rest/direct pv)
  (core-pvector-large-finger-pop-right-rest/known-length
   pv
   (core-pvector-large-finger-length pv)))

(define (core-pvector-large-finger-pop-right-view+rest/known-length pv len)
  (let* ([suffix-len (core-pvector-large-finger-suffix-length pv)]
         [value (core-pvector-large-finger-suffix-ref pv (fx- suffix-len 1))])
    (values value
            (and (fx> suffix-len 1)
                 (core-pvector-large-finger-with-suffix-vector
                  pv
                  (fx- len 1)
                  (core-pvector-large-finger-middle pv)
                  (core-vector-remove/immutable
                   (core-pvector-large-finger-suffix pv)
                   suffix-len
                   (fx- suffix-len 1)))))))

(define (core-pvector-large-finger-trim-left-edge/known-length pv len count)
  (let ([prefix-len (core-pvector-large-finger-prefix-length pv)])
    (and (fx> count 0)
         (fx< count prefix-len)
         (core-pvector-large-finger-with-prefix-vector
          pv
          (fx- len count)
          (core-pvector-large-finger-edge-copy-range/immutable pv #t count prefix-len)
          (core-pvector-large-finger-middle pv)))))

(define (core-pvector-large-finger-trim-right-edge/known-length pv len count)
  (let ([suffix-len (core-pvector-large-finger-suffix-length pv)])
    (and (fx> count 0)
         (fx< count suffix-len)
         (core-pvector-large-finger-with-suffix-vector
          pv
          (fx- len count)
          (core-pvector-large-finger-middle pv)
          (core-pvector-large-finger-edge-copy-range/immutable
           pv
           #f
           0
           (fx- suffix-len count))))))

(define (core-pvector-large-finger-append-right left left-len right right-len)
  (let* ([suffix-len (core-pvector-large-finger-suffix-length left)]
         [new-suffix-len (fx+ suffix-len right-len)])
    (cond
     [(fx<= new-suffix-len core-pvector-digit-max)
      (core-pvector-large-finger-with-suffix-vector
       left
       (fx+ left-len right-len)
       (core-pvector-large-finger-middle left)
       (core-vector-insert/immutable
        (core-pvector-large-finger-suffix left)
        suffix-len
        suffix-len
        (core-pvector-inline-e0 right)))]
     [else
      (let* ([bridge (core-pvector-large-finger-full-edge->node left #f)]
             [old-middle (core-pvector-large-finger-middle left)]
             [middle (if old-middle
                         (core-pvector-node-link2 old-middle bridge)
                         bridge)])
        (core-pvector-large-finger-with-suffix-vector
         left
         (fx+ left-len right-len)
         middle
         (core-pvector-single->immutable-vector right)))])))

(define (core-pvector-large-finger-append-left left left-len right right-len)
  (let* ([prefix-len (core-pvector-large-finger-prefix-length right)]
         [new-prefix-len (fx+ left-len prefix-len)])
    (cond
     [(fx<= new-prefix-len core-pvector-digit-max)
      (core-pvector-large-finger-with-prefix-vector
       right
       (fx+ left-len right-len)
       (core-vector-insert/immutable
        (core-pvector-large-finger-prefix right)
        prefix-len
        0
        (core-pvector-inline-e0 left))
       (core-pvector-large-finger-middle right))]
     [else
      (let* ([bridge (core-pvector-large-finger-full-edge->node right #t)]
             [old-middle (core-pvector-large-finger-middle right)]
             [middle (if old-middle
                         (core-pvector-node-link2 bridge old-middle)
                         bridge)])
        (core-pvector-large-finger-with-prefix-vector
         right
         (fx+ left-len right-len)
         (core-pvector-single->immutable-vector left)
         middle))])))

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
  (make-core-pvector-large-finger/inline
   2
   1
   #f
   1
   left-value
   #f
   #f
   #f
   right-value
   #f
   #f
   #f))

(define (core-make-deep3-pvector a b c)
  (make-core-pvector-large-finger/inline
   3
   1
   #f
   2
   a
   #f
   #f
   #f
   b
   c
   #f
   #f))

(define (core-make-deep4-pvector a b c d)
  (make-core-pvector-large-finger/inline
   4
   2
   #f
   2
   a
   b
   #f
   #f
   c
   d
   #f
   #f))

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
  (let ([prefix-len (core-pvector-large-finger-prefix-length pv)])
    (cond
     [(fx= start end) dest-offset]
     [(fx<= end prefix-len)
      (core-pvector-large-finger-edge-fill-range!
       dest dest-offset pv #t start end)]
     [else
      (let* ([suffix-len (core-pvector-large-finger-suffix-length pv)]
             [middle-start prefix-len]
             [suffix-start (fx- len suffix-len)])
        (cond
         [(and (fx= start 0)
               (fx= end len))
          (let ([offset (core-pvector-large-finger-prefix-fill-all!
                         dest dest-offset pv prefix-len)])
            (core-pvector-large-finger-suffix-fill-all!
             dest
             (if (fx= suffix-start prefix-len)
                 offset
                 (core-pvector-node-fill-all!
                  dest
                  offset
                  (core-pvector-large-finger-middle pv)))
             pv
             suffix-len))]
         [(fx>= start suffix-start)
          (core-pvector-large-finger-edge-fill-range!
           dest
           dest-offset
           pv
           #f
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
          (let* ([offset (core-pvector-large-finger-edge-segment-fill-range!
                          dest
                          dest-offset
                          pv
                          #t
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
            (core-pvector-large-finger-edge-segment-fill-range!
             dest
             offset
             pv
             #f
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
  (let ([prefix-len (core-pvector-large-finger-prefix-length pv)])
    (cond
     [(fx= start end) dest-offset]
     [(fx<= end prefix-len)
      (core-pvector-large-finger-edge-map-range!
       dest dest-offset pv #t start end proc)]
     [else
      (let* ([suffix-len (core-pvector-large-finger-suffix-length pv)]
             [middle-start prefix-len]
             [suffix-start (fx- len suffix-len)])
        (cond
         [(and (fx= start 0)
               (fx= end len))
          (let ([offset (core-pvector-large-finger-prefix-map-all!
                         dest dest-offset pv prefix-len proc)])
            (core-pvector-large-finger-suffix-map-all!
             dest
             (if (fx= suffix-start prefix-len)
                 offset
                 (core-pvector-node-map-all!
                  dest
                  offset
                  (core-pvector-large-finger-middle pv)
                  proc))
             pv
             suffix-len
             proc))]
         [(fx>= start suffix-start)
          (core-pvector-large-finger-edge-map-range!
           dest
           dest-offset
           pv
           #f
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
          (let* ([offset (core-pvector-large-finger-edge-segment-map-range!
                          dest
                          dest-offset
                          pv
                          #t
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
            (core-pvector-large-finger-edge-segment-map-range!
             dest
             offset
             pv
             #f
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
  (let ([prefix-len (core-pvector-large-finger-prefix-length pv)])
    (cond
     [(fx= start end) (void)]
     [(fx<= end prefix-len)
      (core-pvector-large-finger-edge-for-each-range pv #t start end proc)]
     [else
      (let* ([suffix-len (core-pvector-large-finger-suffix-length pv)]
             [middle-start prefix-len]
             [suffix-start (fx- len suffix-len)])
        (cond
         [(and (fx= start 0)
               (fx= end len))
          (core-pvector-large-finger-prefix-for-each-all pv prefix-len proc)
          (unless (fx= suffix-start prefix-len)
            (core-pvector-node-for-each-all
             (core-pvector-large-finger-middle pv)
             proc))
          (core-pvector-large-finger-suffix-for-each-all pv suffix-len proc)]
         [(fx>= start suffix-start)
          (core-pvector-large-finger-edge-for-each-range
           pv
           #f
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
          (core-pvector-large-finger-edge-segment-for-each-range
           pv #t start end 0 prefix-len proc)
          (let ([visit-start (fxmax start middle-start)]
                [visit-end (fxmin end suffix-start)])
            (when (fx< visit-start visit-end)
              (core-pvector-node-for-each-range
               (core-pvector-large-finger-middle pv)
               (fx- visit-start middle-start)
               (fx- visit-end middle-start)
               proc)))
          (core-pvector-large-finger-edge-segment-for-each-range
           pv
           #f
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

(define (core-pvector-large-finger-edge-fold-left-range
         pv prefix? start end acc proc)
  (let loop ([i start] [acc acc])
    (if (fx= i end)
        acc
        (loop (fx+ i 1)
              (proc acc
                    (core-pvector-large-finger-edge-ref
                     pv prefix? i))))))

(define (core-pvector-node-leaf-fold-left-all node acc proc)
  (if (core-pvector-node2? node)
      (let ([acc (proc acc (core-pvector-node2-a node))])
        (proc acc (core-pvector-node2-b node)))
      (let* ([acc (proc acc (core-pvector-node3-a node))]
             [acc (proc acc (core-pvector-node3-b node))])
        (proc acc (core-pvector-node3-c node)))))

(define (core-pvector-node-fold-left-all node acc proc)
  (let ([level (core-pvector-node-level node)])
    (if (fx= level 1)
        (core-pvector-node-leaf-fold-left-all node acc proc)
        (if (core-pvector-node2? node)
            (let ([acc
                   (core-pvector-node-fold-left-all
                    (core-pvector-node2-a node)
                    acc
                    proc)])
              (core-pvector-node-fold-left-all
               (core-pvector-node2-b node)
               acc
               proc))
            (let* ([acc
                    (core-pvector-node-fold-left-all
                     (core-pvector-node3-a node)
                     acc
                     proc)]
                   [acc
                    (core-pvector-node-fold-left-all
                     (core-pvector-node3-b node)
                     acc
                     proc)])
              (core-pvector-node-fold-left-all
               (core-pvector-node3-c node)
               acc
               proc))))))

(define (core-pvector-large-finger-fold-left-all/known-length pv len acc proc)
  (let* ([prefix-len (core-pvector-large-finger-prefix-length pv)]
         [acc (core-pvector-large-finger-prefix-fold-left-all
               pv prefix-len acc proc)]
         [suffix-len (core-pvector-large-finger-suffix-length pv)]
         [suffix-start (fx- len suffix-len)]
         [acc (if (fx= suffix-start prefix-len)
                  acc
                  (core-pvector-node-fold-left-all
                   (core-pvector-large-finger-middle pv)
                   acc
                   proc))])
    (core-pvector-large-finger-suffix-fold-left-all
     pv suffix-len acc proc)))

(define (core-pvector-large-finger->list-range/known-length pv len start end acc)
  (let ([prefix-len (core-pvector-large-finger-prefix-length pv)])
    (cond
     [(fx= start end) acc]
     [(fx<= end prefix-len)
      (core-pvector-large-finger-edge->list-range pv #t start end acc)]
     [else
      (let* ([suffix-len (core-pvector-large-finger-suffix-length pv)]
             [middle-start prefix-len]
             [suffix-start (fx- len suffix-len)])
        (cond
         [(and (fx= start 0)
               (fx= end len))
          (core-pvector-large-finger-prefix->list-all
           pv
           prefix-len
           (let ([acc (core-pvector-large-finger-suffix->list-all
                       pv suffix-len acc)])
             (if (fx= suffix-start prefix-len)
                 acc
                 (core-pvector-node->list-all
                  (core-pvector-large-finger-middle pv)
                  acc))))]
         [(fx>= start suffix-start)
          (core-pvector-large-finger-edge->list-range
           pv
           #f
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
          (let* ([acc (core-pvector-large-finger-edge-segment->list-range
                       pv
                       #f
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
            (core-pvector-large-finger-edge-segment->list-range
             pv #t start end 0 prefix-len acc))]))])))

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
  (unless (and (fixnum? index)
               (fx>= index 0))
    (if (exact-nonnegative-integer? index)
        (error who "index out of bounds")
        (raise-argument-error who "exact-nonnegative-integer?" index)))
  (let ([len (core-pvector-length/unchecked (core-check-pvector who pv))])
    (unless (and (fixnum? index)
                 (fx< index len))
      (error who "index out of bounds"))
    len))

(define (core-check-end-index who pv index)
  (unless (and (fixnum? index)
               (fx>= index 0))
    (if (exact-nonnegative-integer? index)
        (error who "index out of bounds")
        (raise-argument-error who "exact-nonnegative-integer?" index)))
  (let ([len (core-pvector-length/unchecked (core-check-pvector who pv))])
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
    (core-pvector-large-finger-p0 pv)]
   [(not (core-pvector-empty-record? pv))
    (raise-argument-error 'core-pvector-view-left "pvector?" pv)]
   [else
    (error 'core-pvector-view-left "empty pvector")]))

(define (core-pvector-view-right pv)
  (cond
   [(core-pvector-inline? pv)
    (core-pvector-inline-e0 pv)]
   [(core-pvector-large-finger? pv)
    (let ([suffix-len (core-pvector-large-finger-suffix-length pv)])
      (core-pvector-large-finger-suffix-ref pv (fx- suffix-len 1)))]
   [(not (core-pvector-empty-record? pv))
    (raise-argument-error 'core-pvector-view-right "pvector?" pv)]
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

(define core-unsafe-pvector-length core-pvector-length/unchecked)
(define core-unsafe-pvector-ref core-pvector-ref/unchecked)
(define core-unsafe-pvector-view-left core-pvector-view-left)
(define core-unsafe-pvector-view-right core-pvector-view-right)
(define core-unsafe-pvector-first core-pvector-view-left)
(define core-unsafe-pvector-last core-pvector-view-right)

(define (core-pvector-node-arity node)
  (if (core-pvector-node2? node) 2 3))

(define (core-pvector-node-leaf-ref node index)
  (if (core-pvector-node2? node)
      (if (fx= index 0)
          (core-pvector-node2-a node)
          (core-pvector-node2-b node))
      (cond
       [(fx= index 0) (core-pvector-node3-a node)]
       [(fx= index 1) (core-pvector-node3-b node)]
       [else (core-pvector-node3-c node)])))

(define (core-pvector-make-node-cursor-frame node reverse?)
  (let ([arity (core-pvector-node-arity node)])
    (if reverse?
        (make-core-pvector-cursor-node-frame node #t (fx- arity 1) -1 -1)
        (make-core-pvector-cursor-node-frame node #f 0 arity 1))))

(define (core-pvector-push-digit-cursor-frame pv prefix? reverse? stack)
  (let ([len (if prefix?
                 (core-pvector-large-finger-prefix-length pv)
                 (core-pvector-large-finger-suffix-length pv))])
    (cond
     [(fx= len 0) stack]
     [reverse?
      (cons (make-core-pvector-cursor-digit-frame pv prefix? (fx- len 1) -1 -1)
            stack)]
     [else
      (cons (make-core-pvector-cursor-digit-frame pv prefix? 0 len 1)
            stack)])))

(define (core-pvector-push-node-cursor-frame node reverse? stack)
  (if node
      (cons (core-pvector-make-node-cursor-frame node reverse?) stack)
      stack))

(define (core-pvector-push-node-children-cursor-frames node reverse? stack)
  (cond
   [(core-pvector-node2? node)
    (if reverse?
        (core-pvector-push-node-cursor-frame
         (core-pvector-node2-b node)
         reverse?
         (core-pvector-push-node-cursor-frame
          (core-pvector-node2-a node)
          reverse?
          stack))
        (core-pvector-push-node-cursor-frame
         (core-pvector-node2-a node)
         reverse?
         (core-pvector-push-node-cursor-frame
          (core-pvector-node2-b node)
          reverse?
          stack)))]
   [reverse?
    (core-pvector-push-node-cursor-frame
     (core-pvector-node3-c node)
     reverse?
     (core-pvector-push-node-cursor-frame
      (core-pvector-node3-b node)
      reverse?
      (core-pvector-push-node-cursor-frame
       (core-pvector-node3-a node)
       reverse?
       stack)))]
   [else
    (core-pvector-push-node-cursor-frame
     (core-pvector-node3-a node)
     reverse?
     (core-pvector-push-node-cursor-frame
      (core-pvector-node3-b node)
      reverse?
      (core-pvector-push-node-cursor-frame
       (core-pvector-node3-c node)
       reverse?
       stack)))]))

(define (core-pvector-push-large-finger-cursor-frames pv reverse? stack)
  (let ([middle (core-pvector-large-finger-middle pv)])
    (if reverse?
        (core-pvector-push-digit-cursor-frame
         pv
         #f
         reverse?
         (core-pvector-push-node-cursor-frame
          middle
          reverse?
          (core-pvector-push-digit-cursor-frame pv #t reverse? stack)))
        (core-pvector-push-digit-cursor-frame
         pv
         #t
         reverse?
         (core-pvector-push-node-cursor-frame
          middle
          reverse?
          (core-pvector-push-digit-cursor-frame pv #f reverse? stack))))))

(define (core-pvector-cursor-pop! cursor rest)
  (core-pvector-cursor-stack-set! cursor rest)
  (core-pvector-cursor-advance! cursor))

(define (core-pvector-cursor-digit-next! cursor frame rest)
  (let ([index (core-pvector-cursor-digit-frame-index frame)])
    (if (fx= index (core-pvector-cursor-digit-frame-end frame))
        (core-pvector-cursor-pop! cursor rest)
        (let ([next-index
               (fx+ index (core-pvector-cursor-digit-frame-step frame))])
          (core-pvector-cursor-value-set!
           cursor
           (if (core-pvector-cursor-digit-frame-prefix? frame)
               (core-pvector-large-finger-prefix-ref
                (core-pvector-cursor-digit-frame-pv frame)
                index)
               (core-pvector-large-finger-suffix-ref
                (core-pvector-cursor-digit-frame-pv frame)
                index)))
          (if (fx= next-index (core-pvector-cursor-digit-frame-end frame))
              (core-pvector-cursor-stack-set! cursor rest)
              (core-pvector-cursor-digit-frame-index-set! frame next-index))
          cursor))))

(define (core-pvector-cursor-node-leaf-next! cursor frame rest)
  (let ([index (core-pvector-cursor-node-frame-index frame)])
    (if (fx= index (core-pvector-cursor-node-frame-end frame))
        (core-pvector-cursor-pop! cursor rest)
        (let ([next-index
               (fx+ index (core-pvector-cursor-node-frame-step frame))])
          (core-pvector-cursor-value-set!
           cursor
           (core-pvector-node-leaf-ref
            (core-pvector-cursor-node-frame-node frame)
            index))
          (if (fx= next-index (core-pvector-cursor-node-frame-end frame))
              (core-pvector-cursor-stack-set! cursor rest)
              (core-pvector-cursor-node-frame-index-set! frame next-index))
          cursor))))

(define (core-pvector-cursor-node-next! cursor frame rest)
  (let ([node (core-pvector-cursor-node-frame-node frame)])
    (cond
     [(fx= (core-pvector-node-level node) 1)
      (core-pvector-cursor-node-leaf-next! cursor frame rest)]
     [else
      (core-pvector-cursor-stack-set!
       cursor
       (core-pvector-push-node-children-cursor-frames
        node
        (core-pvector-cursor-node-frame-reverse? frame)
        rest))
      (core-pvector-cursor-advance! cursor)])))

(define (core-pvector-cursor-advance! cursor)
  (let loop ()
    (let ([stack (core-pvector-cursor-stack cursor)])
      (cond
       [(null? stack) #f]
       [else
        (let ([frame (car stack)]
              [rest (cdr stack)])
          (cond
           [(core-pvector-cursor-digit-frame? frame)
            (core-pvector-cursor-digit-next! cursor frame rest)]
           [else
            (core-pvector-cursor-node-next! cursor frame rest)]))]))))

(define (core-pvector-cursor-start pv reverse?)
  (cond
   [(core-pvector-empty-record? pv) #f]
   [(core-pvector-inline? pv)
    (make-core-pvector-cursor (core-pvector-inline-e0 pv) '())]
   [(not (core-pvector-large-finger? pv))
    (error 'core-pvector-cursor-start "expected a pvector")]
   [else
    (core-pvector-cursor-advance!
     (make-core-pvector-cursor
      #f
      (core-pvector-push-large-finger-cursor-frames pv reverse? '())))]))

(define (core-pvector-cursor-next cursor)
  (core-pvector-cursor-advance! cursor))

(define (core-pvector-cursor-value+next cursor)
  (let ([value (core-pvector-cursor-value cursor)])
    (values value
            (core-pvector-cursor-next cursor))))

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
      (vector
       (core-pvector-large-finger-ref/known-length pv len 0)
       (core-pvector-large-finger-ref/known-length pv len 1))]
     [(fx= len 3)
      (vector
       (core-pvector-large-finger-ref/known-length pv len 0)
       (core-pvector-large-finger-ref/known-length pv len 1)
       (core-pvector-large-finger-ref/known-length pv len 2))]
     [(fx= len 4)
      (vector
       (core-pvector-large-finger-ref/known-length pv len 0)
       (core-pvector-large-finger-ref/known-length pv len 1)
       (core-pvector-large-finger-ref/known-length pv len 2)
       (core-pvector-large-finger-ref/known-length pv len 3))]
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
      (let ([left (core-pvector-view-left pv)]
            [right (core-pvector-view-right pv)])
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
   [(not (core-pvector-large-finger? pv))
    (raise-argument-error 'core-pvector-cons-left "pvector?" pv)]
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
   [(not (core-pvector-large-finger? pv))
    (raise-argument-error 'core-pvector-cons-right "pvector?" pv)]
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
  (let ([len (core-pvector-length/unchecked
              (core-check-pvector 'core-pvector-pop-right pv))])
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
  (let ([left-len (core-pvector-length/unchecked
                   (core-check-pvector 'core-pvector-append left))]
        [right-len (core-pvector-length/unchecked
                    (core-check-pvector 'core-pvector-append right))])
    (core-pvector-append/known-length left left-len right right-len)))

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
  (let ([len (core-pvector-length/unchecked
              (core-check-pvector 'core-pvector-copy pv))])
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
  (unless (procedure? proc)
    (raise-argument-error 'core-pvector-map "procedure?" proc))
  (unless (procedure-arity-includes? proc 1)
    (error 'core-pvector-map "procedure does not accept one argument"))
  (let ([len (core-pvector-length/unchecked
              (core-check-pvector 'core-pvector-map pv))])
    (cond
     [(fx= len 0) empty-core-pvector]
     [(eq? proc values) pv]
     [(eq? proc void) (core-make-pvector len (void))]
     [(fx= len 1)
      (core-make-single-pvector
       (proc (core-pvector-view-left pv)))]
     [(fx= len 2)
      (core-make-deep2-pvector
       (proc (core-pvector-large-finger-ref/known-length pv len 0))
       (proc (core-pvector-large-finger-ref/known-length pv len 1)))]
     [(fx= len 3)
      (core-make-deep3-pvector
       (proc (core-pvector-large-finger-ref/known-length pv len 0))
       (proc (core-pvector-large-finger-ref/known-length pv len 1))
       (proc (core-pvector-large-finger-ref/known-length pv len 2)))]
     [(fx= len 4)
      (core-make-deep4-pvector
       (proc (core-pvector-large-finger-ref/known-length pv len 0))
       (proc (core-pvector-large-finger-ref/known-length pv len 1))
       (proc (core-pvector-large-finger-ref/known-length pv len 2))
       (proc (core-pvector-large-finger-ref/known-length pv len 3)))]
     [else
      (let ([vec (make-vector len)])
        (core-pvector-map-range!/known-length vec 0 pv len 0 len proc)
        (core-vector->pvector/no-copy vec))])))

(define (core-unsafe-pvector-for-each pv proc)
  (let ([len (core-pvector-length/unchecked pv)])
    (unless (or (eq? proc values) (eq? proc void))
      (cond
       [(fx= len 0) (void)]
       [(fx= len 1)
        (proc (core-pvector-view-left pv))]
       [(fx= len 2)
        (proc (core-pvector-large-finger-ref/known-length pv len 0))
        (proc (core-pvector-large-finger-ref/known-length pv len 1))]
       [(fx= len 3)
        (proc (core-pvector-large-finger-ref/known-length pv len 0))
        (proc (core-pvector-large-finger-ref/known-length pv len 1))
        (proc (core-pvector-large-finger-ref/known-length pv len 2))]
       [(fx= len 4)
        (proc (core-pvector-large-finger-ref/known-length pv len 0))
        (proc (core-pvector-large-finger-ref/known-length pv len 1))
        (proc (core-pvector-large-finger-ref/known-length pv len 2))
        (proc (core-pvector-large-finger-ref/known-length pv len 3))]
       [else
        (core-pvector-for-each-range/known-length pv len 0 len proc)])))
  (void))

(define (core-pvector-for-each pv proc)
  (unless (procedure? proc)
    (raise-argument-error 'core-pvector-for-each "procedure?" proc))
  (unless (procedure-arity-includes? proc 1)
    (error 'core-pvector-for-each "procedure does not accept one argument"))
  (core-unsafe-pvector-for-each
   (core-check-pvector 'core-pvector-for-each pv)
   proc))

(define (core-unsafe-pvector-fold-left pv init proc)
  (let ([len (core-pvector-length/unchecked pv)])
    (cond
     [(fx= len 0) init]
     [(fx= len 1)
      (proc init (core-pvector-view-left pv))]
     [(fx= len 2)
      (let ([acc
             (proc init
                   (core-pvector-large-finger-ref/known-length pv len 0))])
        (proc acc
              (core-pvector-large-finger-ref/known-length pv len 1)))]
     [(fx= len 3)
      (let* ([acc
              (proc init
                    (core-pvector-large-finger-ref/known-length pv len 0))]
             [acc
              (proc acc
                    (core-pvector-large-finger-ref/known-length pv len 1))])
        (proc acc
              (core-pvector-large-finger-ref/known-length pv len 2)))]
     [(fx= len 4)
      (let* ([acc
              (proc init
                    (core-pvector-large-finger-ref/known-length pv len 0))]
             [acc
              (proc acc
                    (core-pvector-large-finger-ref/known-length pv len 1))]
             [acc
              (proc acc
                    (core-pvector-large-finger-ref/known-length pv len 2))])
        (proc acc
              (core-pvector-large-finger-ref/known-length pv len 3)))]
     [(core-pvector-large-finger? pv)
      (core-pvector-large-finger-fold-left-all/known-length
       pv len init proc)]
     [else init])))

(define (core-pvector-fold-left pv init proc)
  (unless (procedure? proc)
    (raise-argument-error 'core-pvector-fold-left "procedure?" proc))
  (unless (procedure-arity-includes? proc 2)
    (error 'core-pvector-fold-left "procedure does not accept two arguments"))
  (core-unsafe-pvector-fold-left
   (core-check-pvector 'core-pvector-fold-left pv)
   init
   proc))

(define (core-pvector->list pv)
  (let ([len (core-pvector-length pv)])
    (cond
     [(fx= len 0) '()]
     [(fx= len 1) (list (core-pvector-view-left pv))]
     [(fx= len 2)
      (list
       (core-pvector-large-finger-ref/known-length pv len 0)
       (core-pvector-large-finger-ref/known-length pv len 1))]
     [(fx= len 3)
      (list
       (core-pvector-large-finger-ref/known-length pv len 0)
       (core-pvector-large-finger-ref/known-length pv len 1)
       (core-pvector-large-finger-ref/known-length pv len 2))]
     [(fx= len 4)
      (list
       (core-pvector-large-finger-ref/known-length pv len 0)
       (core-pvector-large-finger-ref/known-length pv len 1)
       (core-pvector-large-finger-ref/known-length pv len 2)
       (core-pvector-large-finger-ref/known-length pv len 3))]
     [else
      (core-pvector->list-range/known-length pv len 0 len '())])))

(define (core-pvector-record-equal? left right recur)
  (and (core-pvector? right)
       (let ([len (core-pvector-length left)])
         (and (fx= len (core-pvector-length right))
              (let loop ([i 0])
                (or (fx= i len)
                    (let ([a (core-pvector-ref/unchecked/known-length left len i)]
                          [b (core-pvector-ref/unchecked/known-length right len i)])
                      (and (or (eq? a b)
                               (recur a b))
                           (loop (fx+ i 1))))))))))

(define core-pvector-record-hash-edge-count 16)
(define core-pvector-record-hash-total-count 48)

(define (core-pvector-record-hash-range pv len start count recur hc)
  (let loop ([remaining count] [pos start] [hc hc])
    (if (fx= remaining 0)
        hc
        (loop (fx- remaining 1)
              (fx+ pos 1)
              (hash-code-combine
               hc
               (recur (core-pvector-ref/unchecked/known-length pv len pos)))))))

(define (core-pvector-record-hash pv recur seed)
  (let* ([len (core-pvector-length pv)]
         [hc0 (hash-code-combine seed len)])
    (if (fx>= len core-pvector-record-hash-total-count)
        (let* ([hc1 (core-pvector-record-hash-range
                     pv len 0 core-pvector-record-hash-edge-count recur hc0)]
               [middle-len (fx- len (fx* 2 core-pvector-record-hash-edge-count))]
               [hc2
                (let loop ([i 0] [hc hc1])
                  (if (fx= i core-pvector-record-hash-edge-count)
                      hc
                      (let ([pos (fx+ core-pvector-record-hash-edge-count
                                      (fxquotient
                                       (fx* i middle-len)
                                       core-pvector-record-hash-edge-count))])
                        (loop (fx+ i 1)
                              (hash-code-combine
                               hc
                               (recur
                                (core-pvector-ref/unchecked/known-length
                                 pv len pos)))))))])
          (core-pvector-record-hash-range
           pv
           len
           (fx- len core-pvector-record-hash-edge-count)
           core-pvector-record-hash-edge-count
           recur
           hc2))
        (core-pvector-record-hash-range pv len 0 len recur hc0))))

(define (core-pvector-record-hash-code pv recur)
  (core-pvector-record-hash pv recur 16381))

(define (core-pvector-record-secondary-hash-code pv recur)
  (core-pvector-record-hash pv recur 32749))

(define core-pvector-record-equal+hash
  (list core-pvector-record-equal?
        core-pvector-record-hash-code
        core-pvector-record-secondary-hash-code))

(define (set-core-pvector-record-properties!)
  (define (install! rtd)
    (struct-property-set! prop:equal+hash rtd core-pvector-record-equal+hash))
  (install! (record-type-descriptor core-pvector-empty-record))
  (install! (record-type-descriptor core-pvector-inline))
  (install! (record-type-descriptor core-pvector-large-finger)))

(define (core-pvector-install-struct-property! prop value)
  (define (install! rtd)
    (unless (struct-property-ref prop rtd #f)
      (struct-property-set! prop rtd value)))
  (install! (record-type-descriptor core-pvector-empty-record))
  (install! (record-type-descriptor core-pvector-inline))
  (install! (record-type-descriptor core-pvector-large-finger))
  (void))

(define (core-pvector-literal-state-ref state index)
  (#3%vector-ref state index))

(define (core-pvector-literal-state-set! state index value)
  (#3%vector-set! state index value))

(define (core-pvector-literal-value-map state)
  (core-pvector-literal-state-ref state 0))

(define (core-pvector-literal-node-map state)
  (core-pvector-literal-state-ref state 1))

(define (core-pvector-literal-node-tree-map state)
  (core-pvector-literal-state-ref state 2))

(define (core-pvector-literal-next-id! state)
  (let ([id (core-pvector-literal-state-ref state 3)])
    (core-pvector-literal-state-set! state 3 (fx+ id 1))
    id))

(define (core-pvector-literal-add-def! state id val)
  (core-pvector-literal-state-set!
   state
   4
   (cons (list id val)
         (core-pvector-literal-state-ref state 4))))

(define (core-pvector-literal-emit-def! state val)
  (let ([id (core-pvector-literal-next-id! state)])
    (core-pvector-literal-add-def! state id val)
    id))

(define (core-pvector-literal-emit-digit/val! state len a b c d)
  (core-pvector-literal-emit-def!
   state
   (cond
    [(fx= len 1) (list 'Digit/val len a)]
    [(fx= len 2) (list 'Digit/val len a b)]
    [(fx= len 3) (list 'Digit/val len a b c)]
    [else (list 'Digit/val len a b c d)])))

(define (core-pvector-literal-emit-edge-digit/val! state pv prefix?)
  (let ([len (core-pvector-large-finger-edge-length pv prefix?)])
    (core-pvector-literal-emit-digit/val!
     state
     len
     (if (fx< 0 len) (core-pvector-large-finger-edge-ref pv prefix? 0) #f)
     (if (fx< 1 len) (core-pvector-large-finger-edge-ref pv prefix? 1) #f)
     (if (fx< 2 len) (core-pvector-large-finger-edge-ref pv prefix? 2) #f)
     (if (fx< 3 len) (core-pvector-large-finger-edge-ref pv prefix? 3) #f))))

(define (core-pvector-literal-emit-node-digit1! state a)
  (let ([a-id (core-pvector-literal-emit-node! state a)])
    (core-pvector-literal-emit-def!
     state
     (list 'Digit (core-pvector-node-measure a) a-id))))

(define (core-pvector-literal-emit-node-digit2! state a b)
  (let ([a-id (core-pvector-literal-emit-node! state a)]
        [b-id (core-pvector-literal-emit-node! state b)])
    (core-pvector-literal-emit-def!
     state
     (list 'Digit
           (fx+ (core-pvector-node-measure a)
                (core-pvector-node-measure b))
           a-id
           b-id))))

(define (core-pvector-literal-emit-node/uncached! state node)
  (let ([measure (core-pvector-node-measure node)])
    (cond
     [(fx= (core-pvector-node-level node) 1)
      (if (core-pvector-node2? node)
          (core-pvector-literal-emit-def!
           state
           (list 'Node/val
                 measure
                 (core-pvector-node2-a node)
                 (core-pvector-node2-b node)))
          (core-pvector-literal-emit-def!
           state
           (list 'Node/val
                 measure
                 (core-pvector-node3-a node)
                 (core-pvector-node3-b node)
                 (core-pvector-node3-c node))))]
     [(core-pvector-node2? node)
      (let ([a-id (core-pvector-literal-emit-node!
                   state
                   (core-pvector-node2-a node))]
            [b-id (core-pvector-literal-emit-node!
                   state
                   (core-pvector-node2-b node))])
        (core-pvector-literal-emit-def!
         state
         (list 'Node measure a-id b-id)))]
     [else
      (let ([a-id (core-pvector-literal-emit-node!
                   state
                   (core-pvector-node3-a node))]
            [b-id (core-pvector-literal-emit-node!
                   state
                   (core-pvector-node3-b node))]
            [c-id (core-pvector-literal-emit-node!
                   state
                   (core-pvector-node3-c node))])
        (core-pvector-literal-emit-def!
         state
         (list 'Node measure a-id b-id c-id)))])))

(define (core-pvector-literal-emit-node! state node)
  (let* ([node-map (core-pvector-literal-node-map state)]
         [cached (hash-ref node-map node #f)])
    (if cached
        cached
        (let ([id (core-pvector-literal-emit-node/uncached! state node)])
          (hash-set! node-map node id)
          id))))

(define (core-pvector-literal-emit-node-tree! state node)
  (if node
      (let* ([tree-map (core-pvector-literal-node-tree-map state)]
             [cached (hash-ref tree-map node #f)])
        (if cached
            cached
            (let ([id
                   (if (fx= (core-pvector-node-level node) 1)
                       (let ([node-id
                              (core-pvector-literal-emit-node! state node)])
                         (core-pvector-literal-emit-def!
                          state
                          (list 'Single node-id)))
                       (let* ([left-id
                               (if (core-pvector-node2? node)
                                   (core-pvector-literal-emit-node-digit1!
                                    state
                                    (core-pvector-node2-a node))
                                   (core-pvector-literal-emit-node-digit1!
                                    state
                                    (core-pvector-node3-a node)))]
                              [right-id
                               (if (core-pvector-node2? node)
                                   (core-pvector-literal-emit-node-digit1!
                                    state
                                    (core-pvector-node2-b node))
                                   (core-pvector-literal-emit-node-digit2!
                                    state
                                    (core-pvector-node3-b node)
                                    (core-pvector-node3-c node)))])
                         (core-pvector-literal-emit-def!
                          state
                          (list 'Deep
                                (core-pvector-node-measure node)
                                left-id
                                right-id
                                'Empty))))])
              (hash-set! tree-map node id)
              id)))
      'Empty))

(define (core-pvector-literal-emit! pv state)
  (let ([pv (core-check-pvector 'core-pvector-literal-emit! pv)])
    (cond
     [(core-pvector-empty-record? pv) 'Empty]
     [else
      (let* ([value-map (core-pvector-literal-value-map state)]
             [cached (hash-ref value-map pv #f)])
        (if cached
            cached
            (let ([id
                   (cond
                    [(core-pvector-inline? pv)
                     (core-pvector-literal-emit-def!
                      state
                      (list 'Single/val (core-pvector-inline-e0 pv)))]
                    [else
                     (let* ([left-id
                             (core-pvector-literal-emit-edge-digit/val!
                              state
                              pv
                              #t)]
                            [right-id
                             (core-pvector-literal-emit-edge-digit/val!
                              state
                              pv
                              #f)]
                            [inner-id
                             (core-pvector-literal-emit-node-tree!
                              state
                              (core-pvector-large-finger-middle pv))])
                       (core-pvector-literal-emit-def!
                        state
                        (list 'Deep/val
                              (core-pvector-large-finger-length pv)
                              left-id
                              right-id
                              inner-id)))])])
              (hash-set! value-map pv id)
              id)))])))

(define (core-pvector-literal-error msg . args)
  (error 'core-pvector-literal->pvector (apply format msg args)))

(define (core-pvector-literal-proper-list? v)
  (let loop ([v v])
    (cond
     [(null? v) #t]
     [(pair? v) (loop (cdr v))]
     [else #f])))

(define (core-pvector-literal-node? v)
  (or (core-pvector-node2? v)
      (core-pvector-node3? v)))

(define (core-pvector-literal-object-kind v)
  (cond
   [(core-pvector? v) 'pvector]
   [(core-pvector-literal-node? v) 'node]
   [(and (pair? v) (eq? (car v) 'Digit/val)) 'digit/val]
   [(and (pair? v) (eq? (car v) 'Digit)) 'digit]
   [else #f]))

(define (core-pvector-literal-check-proper-list who v)
  (unless (core-pvector-literal-proper-list? v)
    (core-pvector-literal-error "~a is not a proper list: ~s" who v))
  v)

(define (core-pvector-literal-check-size variant size expected)
  (unless (and (fixnum? size)
               (fx= size expected))
    (core-pvector-literal-error
     "~a size mismatch: expected ~a, got ~s"
     variant
     expected
     size)))

(define (core-pvector-literal-id? v)
  (and (fixnum? v)
       (fx>= v 0)))

(define core-pvector-literal-missing
  (list 'missing))

(define (core-pvector-literal-forward-option? v)
  (and (keyword? v)
       (string=? (keyword->string v) "allow-forward-refs")))

(define (core-pvector-literal-ref table limit id expected-kind)
  (unless (and (core-pvector-literal-id? id)
               (fx< id limit))
    (core-pvector-literal-error "invalid reference id: ~s" id))
  (let ([v (#3%vector-ref table id)])
    (unless v
      (core-pvector-literal-error
       "reference id is not defined before use: ~s"
       id))
    (let ([kind (core-pvector-literal-object-kind v)])
      (unless (eq? kind expected-kind)
        (core-pvector-literal-error
         "reference id ~a has kind ~s, expected ~s"
         id
         kind
         expected-kind)))
    v))

(define (core-pvector-literal-node-ref table limit id)
  (core-pvector-literal-ref table limit id 'node))

(define (core-pvector-literal-digit/val-ref table limit id)
  (core-pvector-literal-ref table limit id 'digit/val))

(define (core-pvector-literal-digit-ref table limit id)
  (core-pvector-literal-ref table limit id 'digit))

(define (core-pvector-literal-inner-ref table limit id)
  (cond
   [(eq? id 'Empty) #f]
   [else (core-pvector-literal-node-ref table limit id)]))

(define (core-pvector-literal-pvector-ref table limit id)
  (cond
   [(eq? id 'Empty) empty-core-pvector]
   [else (core-pvector-literal-ref table limit id 'pvector)]))

(define (core-pvector-literal-digit-length digit)
  (core-list-length (cdr digit)))

(define (core-pvector-literal-digit-measure digit)
  (let loop ([nodes (cdr digit)] [measure 0])
    (if (null? nodes)
        measure
        (loop (cdr nodes)
              (fx+ measure (core-pvector-node-measure (car nodes)))))))

(define (core-pvector-literal-node-list-measure nodes)
  (let loop ([nodes nodes] [measure 0])
    (if (null? nodes)
        measure
        (loop (cdr nodes)
              (fx+ measure (core-pvector-node-measure (car nodes)))))))

(define (core-pvector-literal-check-digit-arity variant len)
  (unless (and (fx>= len 1)
               (fx<= len core-pvector-digit-max))
    (core-pvector-literal-error
     "~a expects 1 to 4 elements, got ~a"
     variant
     len)))

(define (core-pvector-literal-check-node-arity variant len)
  (unless (or (fx= len 2)
              (fx= len 3))
    (core-pvector-literal-error
     "~a expects 2 or 3 elements, got ~a"
     variant
     len)))

(define (core-pvector-literal-list-ref/fill lst index)
  (cond
   [(null? lst) #f]
   [(fx= index 0) (car lst)]
   [else (core-pvector-literal-list-ref/fill (cdr lst) (fx- index 1))]))

(define (core-pvector-literal-make-large size left inner right)
  (let ([left-values (cdr left)]
        [right-values (cdr right)])
    (make-core-pvector-large-finger/inline
     size
     (core-list-length left-values)
     inner
     (core-list-length right-values)
     (core-pvector-literal-list-ref/fill left-values 0)
     (core-pvector-literal-list-ref/fill left-values 1)
     (core-pvector-literal-list-ref/fill left-values 2)
     (core-pvector-literal-list-ref/fill left-values 3)
     (core-pvector-literal-list-ref/fill right-values 0)
     (core-pvector-literal-list-ref/fill right-values 1)
     (core-pvector-literal-list-ref/fill right-values 2)
     (core-pvector-literal-list-ref/fill right-values 3))))

(define (core-pvector-literal-node-same-level? nodes)
  (or (null? nodes)
      (let ([level (core-pvector-node-level (car nodes))])
        (let loop ([nodes (cdr nodes)])
          (cond
           [(null? nodes) #t]
           [(fx= level (core-pvector-node-level (car nodes)))
            (loop (cdr nodes))]
           [else #f])))))

(define (core-pvector-literal-build-node variant size nodes)
  (let ([len (core-list-length nodes)])
    (core-pvector-literal-check-node-arity variant len)
    (unless (core-pvector-literal-node-same-level? nodes)
      (core-pvector-literal-error
       "~a child nodes do not have the same level"
       variant))
    (core-pvector-literal-check-size
     variant
     size
     (core-pvector-literal-node-list-measure nodes))
    (let ([node-level (fx+ (core-pvector-node-level (car nodes)) 1)])
      (cond
       [(fx= len 2)
        (core-make-node2 node-level (car nodes) (cadr nodes))]
       [else
        (core-make-node3 node-level (car nodes) (cadr nodes) (caddr nodes))]))))

(define (core-pvector-literal-parse-def-value
         val node-ref digit/val-ref digit-ref inner-ref)
  (core-pvector-literal-check-proper-list 'definition-value val)
  (unless (pair? val)
    (core-pvector-literal-error "empty definition value"))
  (let ([variant (car val)]
        [args (cdr val)])
    (case variant
      [(Single/val)
       (unless (and (pair? args) (null? (cdr args)))
         (core-pvector-literal-error "Single/val expects one element"))
       (core-make-single-pvector (car args))]
      [(Digit/val)
       (unless (pair? args)
         (core-pvector-literal-error "Digit/val expects a size"))
       (let* ([size (car args)]
              [values (cdr args)]
              [len (core-list-length values)])
         (core-pvector-literal-check-digit-arity 'Digit/val len)
         (core-pvector-literal-check-size 'Digit/val size len)
         (cons 'Digit/val values))]
      [(Node/val)
       (unless (pair? args)
         (core-pvector-literal-error "Node/val expects a size"))
       (let* ([size (car args)]
              [values (cdr args)]
              [len (core-list-length values)])
         (core-pvector-literal-check-node-arity 'Node/val len)
         (core-pvector-literal-check-size 'Node/val size len)
         (cond
          [(fx= len 2) (core-make-leaf-node2 (car values) (cadr values))]
          [else (core-make-leaf-node3
                 (car values)
                 (cadr values)
                 (caddr values))]))]
      [(Single)
       (unless (and (pair? args) (null? (cdr args)))
         (core-pvector-literal-error "Single expects one node id"))
       (node-ref (car args))]
      [(One/val)
       (core-pvector-literal-error
        "obsolete definition variant: One/val; use Single/val")]
      [(One)
       (core-pvector-literal-error
        "obsolete definition variant: One; use Single")]
      [(Digit)
       (unless (pair? args)
         (core-pvector-literal-error "Digit expects a size"))
       (let* ([size (car args)]
              [node-ids (cdr args)]
              [nodes (let loop ([ids node-ids])
                       (if (null? ids)
                           '()
                           (cons (node-ref (car ids))
                                 (loop (cdr ids)))))]
              [len (core-list-length nodes)])
         (core-pvector-literal-check-digit-arity 'Digit len)
         (core-pvector-literal-check-size
          'Digit
          size
          (core-pvector-literal-node-list-measure nodes))
         (cons 'Digit nodes))]
      [(Node)
       (unless (pair? args)
         (core-pvector-literal-error "Node expects a size"))
       (let ([size (car args)]
             [node-ids (cdr args)])
         (core-pvector-literal-build-node
          'Node
          size
          (let loop ([ids node-ids])
            (if (null? ids)
                '()
                (cons (node-ref (car ids))
                      (loop (cdr ids)))))))]
      [(Deep/val)
       (unless (and (pair? args)
                    (pair? (cdr args))
                    (pair? (cddr args))
                    (pair? (cdddr args))
                    (null? (cddddr args)))
         (core-pvector-literal-error
          "Deep/val expects size, left digit id, right digit id, and inner id"))
       (let* ([size (car args)]
              [left (digit/val-ref (cadr args))]
              [right (digit/val-ref (caddr args))]
              [inner (inner-ref (cadddr args))]
              [expected (fx+ (core-pvector-literal-digit-length left)
                             (fx+ (if inner
                                      (core-pvector-node-measure inner)
                                      0)
                                  (core-pvector-literal-digit-length right)))])
         (core-pvector-literal-check-size 'Deep/val size expected)
         (core-pvector-literal-make-large size left inner right))]
      [(Deep)
       (unless (and (pair? args)
                    (pair? (cdr args))
                    (pair? (cddr args))
                    (pair? (cdddr args))
                    (null? (cddddr args)))
         (core-pvector-literal-error
          "Deep expects size, left digit id, right digit id, and inner id"))
       (let* ([size (car args)]
              [left (digit-ref (cadr args))]
              [right (digit-ref (caddr args))]
              [inner (inner-ref (cadddr args))]
              [nodes (append (cdr left)
                             (if inner (list inner) '())
                             (cdr right))]
              [expected (core-pvector-literal-node-list-measure nodes)])
         (core-pvector-literal-check-size 'Deep size expected)
         (core-build-node-tree/nodes (reverse nodes)))]
      [else
       (core-pvector-literal-error
        "unknown definition variant: ~s"
        variant)])))

(define (core-pvector-literal-parse-def! def table expected-id)
  (core-pvector-literal-check-proper-list 'definition def)
  (unless (and (pair? def)
               (pair? (cdr def))
               (null? (cddr def)))
    (core-pvector-literal-error
     "definition must have an id and a value: ~s"
     def))
  (let ([id (car def)])
    (unless (and (core-pvector-literal-id? id)
                 (fx= id expected-id))
      (core-pvector-literal-error
       "definition id must be dense and ascending: expected ~a, got ~s"
       expected-id
       id))
    (#3%vector-set!
     table
     id
     (core-pvector-literal-parse-def-value
      (cadr def)
      (lambda (ref-id) (core-pvector-literal-node-ref table id ref-id))
      (lambda (ref-id) (core-pvector-literal-digit/val-ref table id ref-id))
      (lambda (ref-id) (core-pvector-literal-digit-ref table id ref-id))
      (lambda (ref-id) (core-pvector-literal-inner-ref table id ref-id))))))

(define (core-pvector-literal-forward-ref
         raw-table value-table state limit id expected-kind)
  (unless (and (core-pvector-literal-id? id)
               (fx< id limit))
    (core-pvector-literal-error "invalid reference id: ~s" id))
  (case (#3%vector-ref state id)
    [(done)
     (let ([v (#3%vector-ref value-table id)])
       (let ([kind (core-pvector-literal-object-kind v)])
         (unless (eq? kind expected-kind)
           (core-pvector-literal-error
            "reference id ~a has kind ~s, expected ~s"
            id
            kind
            expected-kind)))
       v)]
    [(visiting)
     (core-pvector-literal-error "cyclic reference id: ~s" id)]
    [else
     (let ([raw (#3%vector-ref raw-table id)])
       (when (eq? raw core-pvector-literal-missing)
         (core-pvector-literal-error "definition id missing: ~s" id))
       (#3%vector-set! state id 'visiting)
       (let ([v (core-pvector-literal-parse-def-value
                 raw
                 (lambda (ref-id)
                   (core-pvector-literal-forward-ref
                    raw-table value-table state limit ref-id 'node))
                 (lambda (ref-id)
                   (core-pvector-literal-forward-ref
                    raw-table value-table state limit ref-id 'digit/val))
                 (lambda (ref-id)
                   (core-pvector-literal-forward-ref
                    raw-table value-table state limit ref-id 'digit))
                 (lambda (ref-id)
                   (core-pvector-literal-forward-inner-ref
                    raw-table value-table state limit ref-id)))])
         (#3%vector-set! value-table id v)
         (#3%vector-set! state id 'done)
         (let ([kind (core-pvector-literal-object-kind v)])
           (unless (eq? kind expected-kind)
             (core-pvector-literal-error
              "reference id ~a has kind ~s, expected ~s"
              id
              kind
              expected-kind)))
         v))]))

(define (core-pvector-literal-forward-inner-ref raw-table value-table state limit id)
  (cond
   [(eq? id 'Empty) #f]
   [else
    (core-pvector-literal-forward-ref
     raw-table value-table state limit id 'node)]))

(define (core-pvector-literal-forward-pvector-ref raw-table value-table state limit id)
  (cond
   [(eq? id 'Empty) empty-core-pvector]
   [else
    (core-pvector-literal-forward-ref
     raw-table value-table state limit id 'pvector)]))

(define (core-pvector-literal-install-forward-def! def raw-table limit)
  (core-pvector-literal-check-proper-list 'definition def)
  (unless (and (pair? def)
               (pair? (cdr def))
               (null? (cddr def)))
    (core-pvector-literal-error
     "definition must have an id and a value: ~s"
     def))
  (let ([id (car def)])
    (unless (and (core-pvector-literal-id? id)
                 (fx< id limit))
      (core-pvector-literal-error "invalid definition id: ~s" id))
    (unless (eq? (#3%vector-ref raw-table id)
                 core-pvector-literal-missing)
      (core-pvector-literal-error "duplicate definition id: ~s" id))
    (#3%vector-set! raw-table id (cadr def))))

(define (core-pvector-literal-check-forward-defs-complete raw-table limit)
  (let loop ([id 0])
    (unless (fx= id limit)
      (when (eq? (#3%vector-ref raw-table id)
                 core-pvector-literal-missing)
        (core-pvector-literal-error "definition id missing: ~s" id))
      (loop (fx+ id 1)))))

(define (core-pvector-literal-forward-raw->pvector root defs)
  (core-pvector-literal-check-proper-list 'definition-list defs)
  (let* ([len (core-list-length defs)]
         [raw-table (make-vector len core-pvector-literal-missing)]
         [value-table (make-vector len #f)]
         [state (make-vector len #f)])
    (let loop ([defs defs])
      (unless (null? defs)
        (core-pvector-literal-install-forward-def! (car defs) raw-table len)
        (loop (cdr defs))))
    (core-pvector-literal-check-forward-defs-complete raw-table len)
    (core-pvector-literal-forward-pvector-ref
     raw-table value-table state len root)))

(define (core-pvector-literal-raw->pvector root defs)
  (core-pvector-literal-check-proper-list 'definition-list defs)
  (let* ([len (core-list-length defs)]
         [table (make-vector len #f)])
    (let loop ([defs defs] [id 0])
      (unless (null? defs)
        (core-pvector-literal-parse-def! (car defs) table id)
        (loop (cdr defs) (fx+ id 1))))
    (core-pvector-literal-pvector-ref table len root)))

(define (core-pvector-literal->pvector datum)
  (core-pvector-literal-check-proper-list 'literal datum)
  (unless (and (pair? datum)
               (pair? (cdr datum))
               (null? (cddr datum)))
    (core-pvector-literal-error
     "literal must be ((element ...) #f) or (root-id definitions): ~s"
     datum))
  (let ([head (car datum)]
        [tail (cadr datum)])
    (cond
     [(eq? tail #f)
      (core-pvector-literal-check-proper-list "expanded element list" head)
      (core-list->pvector head)]
     [(and (pair? tail)
           (core-pvector-literal-forward-option? (car tail)))
      (core-pvector-literal-check-proper-list
       'forward-reference-option
       tail)
      (unless (and (pair? (cdr tail))
                   (null? (cddr tail)))
        (core-pvector-literal-error
         "forward-reference option expects one definition list: ~s"
         tail))
      (core-pvector-literal-forward-raw->pvector head (cadr tail))]
     [else
      (core-pvector-literal-raw->pvector head tail)])))

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
        (put! 'digit-storage 'inline)
        (put! 'inline-digits 2)
        (put! 'digit-vectors 0)
        (put! 'prefix-length
              (core-pvector-large-finger-prefix-length pv))
        (put! 'suffix-length
              (core-pvector-large-finger-suffix-length pv))
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
