#lang racket

(provide canonical-codes
         huffman-code-lengths
         code-length-rle-events
         (struct-out cl-event)
         dynamic-litonly-raw-deflate
         dynamic-balanced-literal-raw-deflate
         dynamic-literal-frequency-raw-deflate
         dynamic-lz77-frequency-counts
         dynamic-lz77-raw-deflate
         deflate-length-symbol
         deflate-distance-symbol
         balanced-literal-lengths
         literal-frequency-lengths
         dynamic-litonly-literal-lengths)

(define code-length-order
  '(16 17 18 0 8 7 9 6 10 5 11 4 12 3 13 2 14 1 15))

;; A complete literal/length tree with all literal bytes and EOB present:
;; 226 * 2^-8 + 60 * 2^-9 = 1.  This is deliberately not frequency-optimal;
;; it is the smallest reference tree that keeps the dynamic block machinery
;; unambiguous before the real length-limited tree builder lands.
(define dynamic-litonly-literal-lengths
  (append (make-list 226 8)
          (make-list 60 9)))

(define dynamic-litonly-distance-lengths
  '(0))

(define dynamic-litonly-code-length-lengths
  (append (make-list 16 4)
          (make-list 3 0)))

(struct huff-node (freq tie symbol left right) #:transparent)
(struct cl-event (symbol extra extra-bits) #:transparent)

(define (node<? left right)
  (or (< (huff-node-freq left) (huff-node-freq right))
      (and (= (huff-node-freq left) (huff-node-freq right))
           (< (huff-node-tie left) (huff-node-tie right)))))

(define (insert-node node nodes)
  (cond
    [(null? nodes) (list node)]
    [(node<? node (car nodes)) (cons node nodes)]
    [else (cons (car nodes) (insert-node node (cdr nodes)))]))

(define (sorted-nodes nodes)
  (foldl insert-node '() nodes))

(define (first-unused-symbol freqs used)
  (for/first ([symbol (in-range (vector-length freqs))]
              #:unless (hash-has-key? used symbol))
    symbol))

(define (active-frequency-symbols freqs)
  (for/list ([freq (in-vector freqs)]
             [symbol (in-naturals)]
             #:when (positive? freq))
    symbol))

(define (huffman-tree-lengths freqs)
  (define leaves
    (for/list ([freq (in-vector freqs)]
               [symbol (in-naturals)]
               #:when (positive? freq))
      (huff-node freq symbol symbol #f #f)))
  (define root
    (let loop ([nodes (sorted-nodes leaves)])
      (cond
        [(null? nodes) #f]
        [(null? (cdr nodes)) (car nodes)]
        [else
         (define a (car nodes))
         (define b (cadr nodes))
         (define parent
           (huff-node (+ (huff-node-freq a) (huff-node-freq b))
                      (min (huff-node-tie a) (huff-node-tie b))
                      #f
                      a
                      b))
         (loop (insert-node parent (cddr nodes)))])))
  (define lengths (make-vector (vector-length freqs) 0))
  (define (walk node depth)
    (cond
      [(not node) (void)]
      [(huff-node-symbol node)
       (vector-set! lengths (huff-node-symbol node) (max depth 1))]
      [else
       (walk (huff-node-left node) (add1 depth))
       (walk (huff-node-right node) (add1 depth))]))
  (walk root 0)
  lengths)

(define (limit-length-counts raw-lengths freqs max-bits)
  (define bl-count (make-vector (add1 max-bits) 0))
  (define overflow 0)
  (for ([len (in-vector raw-lengths)]
        [freq (in-vector freqs)]
        #:when (positive? freq))
    (cond
      [(> len max-bits)
       (vector-set! bl-count max-bits
                    (add1 (vector-ref bl-count max-bits)))
       (set! overflow (add1 overflow))]
      [else
       (vector-set! bl-count len (add1 (vector-ref bl-count len)))]))
  (let loop ()
    (when (positive? overflow)
      (define bits
        (for/first ([candidate (in-range (sub1 max-bits) 0 -1)]
                    #:when (positive? (vector-ref bl-count candidate)))
          candidate))
      (unless bits
        (error 'huffman-code-lengths
               "cannot repair Huffman length overflow for max bits ~a"
               max-bits))
      (vector-set! bl-count bits (sub1 (vector-ref bl-count bits)))
      (vector-set! bl-count (add1 bits)
                   (+ (vector-ref bl-count (add1 bits)) 2))
      (vector-set! bl-count max-bits
                   (sub1 (vector-ref bl-count max-bits)))
      (set! overflow (- overflow 2))
      (loop)))
  bl-count)

(define (assign-limited-lengths freqs bl-count)
  (define lengths (make-vector (vector-length freqs) 0))
  (define symbols
    (sort
     (for/list ([freq (in-vector freqs)]
                [symbol (in-naturals)]
                #:when (positive? freq))
       (cons symbol freq))
     (lambda (a b)
       (or (< (cdr a) (cdr b))
           (and (= (cdr a) (cdr b))
                (> (car a) (car b)))))))
  (define remaining symbols)
  (for ([bits (in-range (sub1 (vector-length bl-count)) 0 -1)])
    (for ([_ (in-range (vector-ref bl-count bits))])
      (when (null? remaining)
        (error 'huffman-code-lengths "length count exceeds active symbol count"))
      (vector-set! lengths (caar remaining) bits)
      (set! remaining (cdr remaining))))
  (unless (null? remaining)
    (error 'huffman-code-lengths "not all active symbols received lengths"))
  lengths)

(define (huffman-code-lengths frequencies max-bits #:min-codes [min-codes 2])
  (define freqs (vector-copy frequencies))
  (define active (active-frequency-symbols freqs))
  (when (zero? (length active))
    (error 'huffman-code-lengths "at least one frequency is required"))
  (let loop ()
    (when (< (length (active-frequency-symbols freqs)) min-codes)
      (define used (for/hash ([symbol (in-list (active-frequency-symbols freqs))])
                     (values symbol #t)))
      (define dummy (first-unused-symbol freqs used))
      (unless dummy
        (error 'huffman-code-lengths "cannot add dummy symbol"))
      (vector-set! freqs dummy 1)
      (loop)))
  (define raw-lengths (huffman-tree-lengths freqs))
  (define max-raw (for/fold ([m 0]) ([len (in-vector raw-lengths)]) (max m len)))
  (if (<= max-raw max-bits)
      raw-lengths
      (assign-limited-lengths
       freqs
       (limit-length-counts raw-lengths freqs max-bits))))

(define (bit-reverse value width)
  (for/fold ([result 0])
            ([i (in-range width)])
    (bitwise-ior (arithmetic-shift result 1)
                 (bitwise-and (arithmetic-shift value (- i)) 1))))

(define (canonical-codes lengths)
  (define max-bits (if (null? lengths) 0 (apply max lengths)))
  (define bl-count (make-vector (add1 max-bits) 0))
  (for ([len (in-list lengths)]
        #:when (positive? len))
    (vector-set! bl-count len (add1 (vector-ref bl-count len))))
  (define next-code (make-vector (add1 max-bits) 0))
  (define code 0)
  (for ([bits (in-range 1 (add1 max-bits))])
    (set! code (arithmetic-shift (+ code (vector-ref bl-count (sub1 bits))) 1))
    (vector-set! next-code bits code))
  (define codes (make-vector (length lengths) #f))
  (for ([len (in-list lengths)]
        [symbol (in-naturals)]
        #:when (positive? len))
    (define symbol-code (vector-ref next-code len))
    (vector-set! codes symbol (cons symbol-code len))
    (vector-set! next-code len (add1 symbol-code)))
  codes)

(define (last-positive-index lengths)
  (for/fold ([last #f])
            ([len (in-list lengths)]
             [index (in-naturals)])
    (if (positive? len) index last)))

(define (trim-code-count lengths min-count)
  (max min-count (add1 (or (last-positive-index lengths) 0))))

(define (list-take-count items count)
  (for/list ([item (in-list items)]
             [_ (in-range count)])
    item))

(define (run-length-at items start)
  (define value (list-ref items start))
  (let loop ([index start])
    (if (and (< index (length items))
             (= (list-ref items index) value))
        (loop (add1 index))
        (- index start))))

(define (code-length-rle-events lengths)
  (define n (length lengths))
  (let loop ([index 0] [events '()])
    (cond
      [(>= index n) (reverse events)]
      [else
       (define len (list-ref lengths index))
       (define run (run-length-at lengths index))
       (cond
         [(zero? len)
          (let zero-loop ([left run] [acc events])
            (cond
              [(>= left 11)
               (define count (min left 138))
               (zero-loop (- left count)
                          (cons (cl-event 18 (- count 11) 7) acc))]
              [(>= left 3)
               (define count (min left 10))
               (zero-loop (- left count)
                          (cons (cl-event 17 (- count 3) 3) acc))]
              [(positive? left)
               (zero-loop (sub1 left)
                          (cons (cl-event 0 0 0) acc))]
              [else
               (loop (+ index run) acc)]))]
         [else
          (let nonzero-loop ([left (sub1 run)]
                             [acc (cons (cl-event len 0 0) events)])
            (cond
              [(>= left 3)
               (define count (min left 6))
               (nonzero-loop (- left count)
                             (cons (cl-event 16 (- count 3) 2) acc))]
              [(positive? left)
               (nonzero-loop (sub1 left)
                             (cons (cl-event len 0 0) acc))]
              [else
               (loop (+ index run) acc)]))])])))

(define (make-bit-writer)
  (define bits '())
  (define (write-bits value width)
    (for ([i (in-range width)])
      (set! bits
            (cons (bitwise-and (arithmetic-shift value (- i)) 1)
                  bits))))
  (define (write-code codes symbol)
    (define entry (vector-ref codes symbol))
    (unless entry
      (error 'dynamic-litonly-raw-deflate "symbol has no code: ~a" symbol))
    (define code (car entry))
    (define width (cdr entry))
    (write-bits (bit-reverse code width) width))
  (define (finish)
    (define ordered (list->vector (reverse bits)))
    (define byte-count (quotient (+ (vector-length ordered) 7) 8))
    (define out (make-bytes byte-count 0))
    (for ([i (in-range (vector-length ordered))])
      (when (= (vector-ref ordered i) 1)
        (define byte-index (quotient i 8))
        (define bit-index (remainder i 8))
        (bytes-set! out byte-index
                    (bitwise-ior (bytes-ref out byte-index)
                                 (arithmetic-shift 1 bit-index)))))
    out)
  (values write-bits write-code finish))

(define (dynamic-litonly-raw-deflate input)
  (unless (bytes? input)
    (raise-argument-error 'dynamic-litonly-raw-deflate "bytes?" input))
  (define src input)
  (define-values (write-bits write-code finish) (make-bit-writer))
  (define cl-codes (canonical-codes dynamic-litonly-code-length-lengths))
  (define ll-codes (canonical-codes dynamic-litonly-literal-lengths))

  ;; BFINAL=1, BTYPE=10. Bits are emitted least-significant first.
  (write-bits #b101 3)
  (write-bits 29 5) ; HLIT: 286 literal/length codes - 257
  (write-bits 0 5)  ; HDIST: one distance code - 1
  (write-bits 15 4) ; HCLEN: nineteen code-length codes - 4

  (for ([symbol (in-list code-length-order)])
    (write-bits (list-ref dynamic-litonly-code-length-lengths symbol) 3))

  (for ([len (in-list dynamic-litonly-literal-lengths)])
    (write-code cl-codes len))
  (for ([len (in-list dynamic-litonly-distance-lengths)])
    (write-code cl-codes len))

  (for ([byte (in-bytes src)])
    (write-code ll-codes byte))
  (write-code ll-codes 256)
  (finish))

(define (literal-frequency-lengths input)
  (define freqs (make-vector 286 0))
  (for ([byte (in-bytes input)])
    (vector-set! freqs byte (add1 (vector-ref freqs byte))))
  (vector-set! freqs 256 (add1 (vector-ref freqs 256)))
  (vector->list (huffman-code-lengths freqs 15 #:min-codes 2)))

(define (literal-frequencies input)
  (define freqs (make-vector 286 0))
  (for ([byte (in-bytes input)])
    (vector-set! freqs byte (add1 (vector-ref freqs byte))))
  (vector-set! freqs 256 (add1 (vector-ref freqs 256)))
  freqs)

(define (deflate-length-symbol len)
  (cond
    [(= len 258) 285]
    [(<= len 10) (+ len 254)]
    [else
     (define n (- len 11))
     (define-values (extra-bits first-code threshold)
       (cond
         [(< n 8) (values 1 265 0)]
         [(< n 24) (values 2 269 8)]
         [(< n 56) (values 3 273 24)]
         [(< n 120) (values 4 277 56)]
         [else (values 5 281 120)]))
     (define local (- n threshold))
     (+ first-code (arithmetic-shift local (- extra-bits)))]))

(define (deflate-length-code len)
  (cond
    [(= len 258) (values 285 0 0)]
    [(<= len 10) (values (+ len 254) 0 0)]
    [else
     (define n (- len 11))
     (define-values (extra-bits first-code threshold)
       (cond
         [(< n 8) (values 1 265 0)]
         [(< n 24) (values 2 269 8)]
         [(< n 56) (values 3 273 24)]
         [(< n 120) (values 4 277 56)]
         [else (values 5 281 120)]))
     (define local (- n threshold))
     (define slot (arithmetic-shift local (- extra-bits)))
     (define extra-value (- local (arithmetic-shift slot extra-bits)))
     (values (+ first-code slot) extra-bits extra-value)]))

(define (deflate-distance-symbol dist)
  (define n (sub1 dist))
  (if (< n 4)
      n
      (let* ([floor-log (sub1 (integer-length n))]
             [extra-bits (sub1 floor-log)]
             [bit (bitwise-and (arithmetic-shift n (- extra-bits)) 1)])
        (+ (* 2 extra-bits) 2 bit))))

(define (deflate-distance-code dist)
  (define n (sub1 dist))
  (if (< n 4)
      (values n 0 0)
      (let* ([floor-log (sub1 (integer-length n))]
             [extra-bits (sub1 floor-log)]
             [bit (bitwise-and (arithmetic-shift n (- extra-bits)) 1)]
             [symbol (+ (* 2 extra-bits) 2 bit)]
             [base-n (arithmetic-shift (+ 2 bit) extra-bits)]
             [extra-value (- n base-n)])
        (values symbol extra-bits extra-value))))

(define (lz77-hash4 input pos)
  (define word
    (bitwise-ior
     (bytes-ref input pos)
     (arithmetic-shift (bytes-ref input (+ pos 1)) 8)
     (arithmetic-shift (bytes-ref input (+ pos 2)) 16)
     (arithmetic-shift (bytes-ref input (+ pos 3)) 24)))
  (bitwise-and (bitwise-xor word (arithmetic-shift word -16)) #x7fff))

(define (dynamic-lz77-frequency-counts input)
  (unless (bytes? input)
    (raise-argument-error 'dynamic-lz77-frequency-counts "bytes?" input))
  (define len (bytes-length input))
  (define ll-freq (make-vector 286 0))
  (define dist-freq (make-vector 30 0))
  (define head (make-vector 32768 #f))
  (define prev (make-vector 32768 #f))
  (define (bump! vec index)
    (vector-set! vec index (add1 (vector-ref vec index))))
  (define (insert! pos)
    (define hash (lz77-hash4 input pos))
    (vector-set! prev (bitwise-and pos #x7fff) (vector-ref head hash))
    (vector-set! head hash pos))
  (define (search find-pos first-candidate)
    (let loop ([scan first-candidate]
               [chain-left 32]
               [best-len 0]
               [best-dist 0])
      (cond
        [(or (not scan) (zero? chain-left))
         (values best-len best-dist)]
        [else
         (define dist (- find-pos scan))
         (cond
           [(zero? dist)
            (define next (vector-ref prev (bitwise-and scan #x7fff)))
            (if (equal? next scan)
                (values best-len best-dist)
                (loop next (sub1 chain-left) best-len best-dist))]
           [(> dist 32768)
            (values best-len best-dist)]
           [(or (not (= (bytes-ref input find-pos)
                        (bytes-ref input scan)))
                (not (= (bytes-ref input (+ find-pos 1))
                        (bytes-ref input (+ scan 1))))
                (not (= (bytes-ref input (+ find-pos 2))
                        (bytes-ref input (+ scan 2)))))
            (define next (vector-ref prev (bitwise-and scan #x7fff)))
            (if (equal? next scan)
                (values best-len best-dist)
                (loop next (sub1 chain-left) best-len best-dist))]
           [else
            (define max-len (min 258 (- len find-pos)))
            (define match-len
              (let extend ([match-len 3])
                (if (or (>= match-len max-len)
                        (not (= (bytes-ref input (+ find-pos match-len))
                                (bytes-ref input (+ scan match-len)))))
                    match-len
                    (extend (add1 match-len)))))
            (define-values (new-best-len new-best-dist)
              (if (> match-len best-len)
                  (values match-len dist)
                  (values best-len best-dist)))
            (if (= new-best-len 258)
                (values new-best-len new-best-dist)
                (let ([next (vector-ref prev (bitwise-and scan #x7fff))])
                  (if (equal? next scan)
                      (values new-best-len new-best-dist)
                      (loop next
                            (sub1 chain-left)
                            new-best-len
                            new-best-dist))))])])))
  (define (count-literal! pos)
    (bump! ll-freq (bytes-ref input pos)))
  (define (count-match! match-len dist)
    (bump! ll-freq (deflate-length-symbol match-len))
    (bump! dist-freq (deflate-distance-symbol dist)))
  (define (tail-literals! pos)
    (for ([i (in-range pos len)])
      (count-literal! i)))
  (let ([last-hash-pos (and (>= len 4) (- len 4))])
    (let loop ([pos 0])
      (cond
        [(or (not last-hash-pos) (> pos last-hash-pos))
         (tail-literals! pos)]
        [else
         (define hash (lz77-hash4 input pos))
         (define candidate (vector-ref head hash))
         (insert! pos)
         (define-values (best-len best-dist) (search pos candidate))
         (cond
           [(< best-len 3)
            (count-literal! pos)
            (loop (add1 pos))]
           [else
            (define emit-current?
              (cond
                [(= best-len 258) #t]
                [(> (add1 pos) last-hash-pos) #t]
                [else
                 (define lazy-pos (add1 pos))
                 (define lazy-hash (lz77-hash4 input lazy-pos))
                 (define-values (lazy-len _lazy-dist)
                   (search lazy-pos (vector-ref head lazy-hash)))
                 (not (> lazy-len best-len))]))
            (if (not emit-current?)
                (begin
                  (count-literal! pos)
                  (loop (add1 pos)))
                (let ([next-pos (+ pos best-len)])
                  (count-match! best-len best-dist)
                  (for ([insert-pos (in-range (add1 pos) next-pos)]
                        #:break (> insert-pos last-hash-pos))
                    (insert! insert-pos))
                  (loop next-pos)))])])))
  (bump! ll-freq 256)
  (values (vector->list ll-freq) (vector->list dist-freq)))

(define (dynamic-lz77-tokens input)
  (unless (bytes? input)
    (raise-argument-error 'dynamic-lz77-tokens "bytes?" input))
  (define len (bytes-length input))
  (define head (make-vector 32768 #f))
  (define prev (make-vector 32768 #f))
  (define tokens '())
  (define (emit-literal! pos)
    (set! tokens (cons (vector 'lit (bytes-ref input pos)) tokens)))
  (define (emit-match! match-len dist)
    (set! tokens (cons (vector 'match match-len dist) tokens)))
  (define (insert! pos)
    (define hash (lz77-hash4 input pos))
    (vector-set! prev (bitwise-and pos #x7fff) (vector-ref head hash))
    (vector-set! head hash pos))
  (define (search find-pos first-candidate)
    (let loop ([scan first-candidate]
               [chain-left 32]
               [best-len 0]
               [best-dist 0])
      (cond
        [(or (not scan) (zero? chain-left))
         (values best-len best-dist)]
        [else
         (define dist (- find-pos scan))
         (cond
           [(zero? dist)
            (define next (vector-ref prev (bitwise-and scan #x7fff)))
            (if (equal? next scan)
                (values best-len best-dist)
                (loop next (sub1 chain-left) best-len best-dist))]
           [(> dist 32768)
            (values best-len best-dist)]
           [(or (not (= (bytes-ref input find-pos)
                        (bytes-ref input scan)))
                (not (= (bytes-ref input (+ find-pos 1))
                        (bytes-ref input (+ scan 1))))
                (not (= (bytes-ref input (+ find-pos 2))
                        (bytes-ref input (+ scan 2)))))
            (define next (vector-ref prev (bitwise-and scan #x7fff)))
            (if (equal? next scan)
                (values best-len best-dist)
                (loop next (sub1 chain-left) best-len best-dist))]
           [else
            (define max-len (min 258 (- len find-pos)))
            (define match-len
              (let extend ([match-len 3])
                (if (or (>= match-len max-len)
                        (not (= (bytes-ref input (+ find-pos match-len))
                                (bytes-ref input (+ scan match-len)))))
                    match-len
                    (extend (add1 match-len)))))
            (define-values (new-best-len new-best-dist)
              (if (> match-len best-len)
                  (values match-len dist)
                  (values best-len best-dist)))
            (if (= new-best-len 258)
                (values new-best-len new-best-dist)
                (let ([next (vector-ref prev (bitwise-and scan #x7fff))])
                  (if (equal? next scan)
                      (values new-best-len new-best-dist)
                      (loop next
                            (sub1 chain-left)
                            new-best-len
                            new-best-dist))))])])))
  (define (tail-literals! pos)
    (for ([i (in-range pos len)])
      (emit-literal! i)))
  (let ([last-hash-pos (and (>= len 4) (- len 4))])
    (let loop ([pos 0])
      (cond
        [(or (not last-hash-pos) (> pos last-hash-pos))
         (tail-literals! pos)]
        [else
         (define hash (lz77-hash4 input pos))
         (define candidate (vector-ref head hash))
         (insert! pos)
         (define-values (best-len best-dist) (search pos candidate))
         (cond
           [(< best-len 3)
            (emit-literal! pos)
            (loop (add1 pos))]
           [else
            (define emit-current?
              (cond
                [(= best-len 258) #t]
                [(> (add1 pos) last-hash-pos) #t]
                [else
                 (define lazy-pos (add1 pos))
                 (define lazy-hash (lz77-hash4 input lazy-pos))
                 (define-values (lazy-len _lazy-dist)
                   (search lazy-pos (vector-ref head lazy-hash)))
                 (not (> lazy-len best-len))]))
            (if (not emit-current?)
                (begin
                  (emit-literal! pos)
                  (loop (add1 pos)))
                (let ([next-pos (+ pos best-len)])
                  (emit-match! best-len best-dist)
                  (for ([insert-pos (in-range (add1 pos) next-pos)]
                        #:break (> insert-pos last-hash-pos))
                    (insert! insert-pos))
                  (loop next-pos)))])])))
  (reverse tokens))

(define (distance-frequency-lengths dist-freqs)
  (if (andmap zero? dist-freqs)
      (make-list 30 0)
      (vector->list (huffman-code-lengths (list->vector dist-freqs) 15 #:min-codes 2))))

(define (balanced-lengths-from-frequencies freqs)
  (define lengths (make-vector 286 0))
  (define active
    (for/list ([freq (in-vector freqs)]
               [symbol (in-naturals)]
               #:when (positive? freq))
      symbol))
  (define active-count (length active))
  (cond
    [(zero? active-count)
     (error 'balanced-lengths-from-frequencies "at least one frequency is required")]
    [(<= active-count 2)
     (for ([symbol (in-list active)])
       (vector-set! lengths symbol 1))
     (when (= active-count 1)
       (define dummy (if (positive? (vector-ref freqs 0)) 1 0))
       (vector-set! lengths dummy 1))]
    [else
     (define-values (pow2 long-len)
       (let loop ([pow2 1] [bits 0])
         (if (>= pow2 active-count)
             (values pow2 bits)
             (loop (* pow2 2) (add1 bits)))))
     (define short-len (sub1 long-len))
     (define short-count (- pow2 active-count))
     (for ([symbol (in-list active)]
           [i (in-naturals)])
       (vector-set! lengths
                    symbol
                    (if (< i short-count) short-len long-len)))])
  (vector->list lengths))

(define (balanced-literal-lengths input)
  (balanced-lengths-from-frequencies (literal-frequencies input)))

(define (dynamic-balanced-literal-raw-deflate input)
  (unless (bytes? input)
    (raise-argument-error 'dynamic-balanced-literal-raw-deflate "bytes?" input))
  (define ll-lengths (balanced-literal-lengths input))
  (define-values (write-bits write-code finish) (make-bit-writer))
  (define cl-codes (canonical-codes dynamic-litonly-code-length-lengths))
  (define ll-codes (canonical-codes ll-lengths))

  ;; BFINAL=1, BTYPE=10.
  (write-bits #b101 3)
  (write-bits 29 5) ; HLIT: 286 literal/length codes - 257
  (write-bits 0 5)  ; HDIST: one distance code - 1
  (write-bits 15 4) ; HCLEN: nineteen code-length codes - 4

  (for ([symbol (in-list code-length-order)])
    (write-bits (list-ref dynamic-litonly-code-length-lengths symbol) 3))

  (for ([len (in-list ll-lengths)])
    (write-code cl-codes len))
  (write-code cl-codes 0)

  (for ([byte (in-bytes input)])
    (write-code ll-codes byte))
  (write-code ll-codes 256)
  (finish))

(define (dynamic-literal-frequency-raw-deflate input)
  (unless (bytes? input)
    (raise-argument-error 'dynamic-literal-frequency-raw-deflate "bytes?" input))
  (define ll-lengths (literal-frequency-lengths input))
  (define lcodes (trim-code-count ll-lengths 257))
  (define dist-lengths '(0))
  (define dcodes 1)
  (define combined-lengths
    (append (list-take-count ll-lengths lcodes)
            (list-take-count dist-lengths dcodes)))
  (define cl-events (code-length-rle-events combined-lengths))
  (define bl-freqs (make-vector 19 0))
  (for ([event (in-list cl-events)])
    (define symbol (cl-event-symbol event))
    (vector-set! bl-freqs symbol (add1 (vector-ref bl-freqs symbol))))
  (define bl-lengths (vector->list (huffman-code-lengths bl-freqs 7 #:min-codes 2)))
  (define blcodes
    (max 4
         (add1
          (or (for/fold ([last #f])
                         ([symbol (in-list code-length-order)]
                          [index (in-naturals)])
                (if (positive? (list-ref bl-lengths symbol)) index last))
              0))))
  (define-values (write-bits write-code finish) (make-bit-writer))
  (define bl-codes (canonical-codes bl-lengths))
  (define ll-codes (canonical-codes ll-lengths))

  ;; BFINAL=1, BTYPE=10.
  (write-bits #b101 3)
  (write-bits (- lcodes 257) 5)
  (write-bits (- dcodes 1) 5)
  (write-bits (- blcodes 4) 4)

  (for ([symbol (in-list (list-take-count code-length-order blcodes))])
    (write-bits (list-ref bl-lengths symbol) 3))

  (for ([event (in-list cl-events)])
    (write-code bl-codes (cl-event-symbol event))
    (when (positive? (cl-event-extra-bits event))
      (write-bits (cl-event-extra event) (cl-event-extra-bits event))))

  (for ([byte (in-bytes input)])
    (write-code ll-codes byte))
  (write-code ll-codes 256)
  (finish))

(define (dynamic-lz77-raw-deflate input)
  (unless (bytes? input)
    (raise-argument-error 'dynamic-lz77-raw-deflate "bytes?" input))
  (define-values (ll-freqs dist-freqs) (dynamic-lz77-frequency-counts input))
  (define tokens (dynamic-lz77-tokens input))
  (define ll-lengths (vector->list (huffman-code-lengths (list->vector ll-freqs) 15 #:min-codes 2)))
  (define dist-lengths (distance-frequency-lengths dist-freqs))
  (define lcodes (trim-code-count ll-lengths 257))
  (define dcodes (trim-code-count dist-lengths 1))
  (define combined-lengths
    (append (list-take-count ll-lengths lcodes)
            (list-take-count dist-lengths dcodes)))
  (define cl-events (code-length-rle-events combined-lengths))
  (define bl-freqs (make-vector 19 0))
  (for ([event (in-list cl-events)])
    (define symbol (cl-event-symbol event))
    (vector-set! bl-freqs symbol (add1 (vector-ref bl-freqs symbol))))
  (define bl-lengths (vector->list (huffman-code-lengths bl-freqs 7 #:min-codes 2)))
  (define blcodes
    (max 4
         (add1
          (or (for/fold ([last #f])
                         ([symbol (in-list code-length-order)]
                          [index (in-naturals)])
                (if (positive? (list-ref bl-lengths symbol)) index last))
              0))))
  (define-values (write-bits write-code finish) (make-bit-writer))
  (define bl-codes (canonical-codes bl-lengths))
  (define ll-codes (canonical-codes ll-lengths))
  (define dist-codes (canonical-codes dist-lengths))

  ;; BFINAL=1, BTYPE=10.
  (write-bits #b101 3)
  (write-bits (- lcodes 257) 5)
  (write-bits (- dcodes 1) 5)
  (write-bits (- blcodes 4) 4)

  (for ([symbol (in-list (list-take-count code-length-order blcodes))])
    (write-bits (list-ref bl-lengths symbol) 3))

  (for ([event (in-list cl-events)])
    (write-code bl-codes (cl-event-symbol event))
    (when (positive? (cl-event-extra-bits event))
      (write-bits (cl-event-extra event) (cl-event-extra-bits event))))

  (for ([token (in-list tokens)])
    (case (vector-ref token 0)
      [(lit)
       (write-code ll-codes (vector-ref token 1))]
      [(match)
       (define len (vector-ref token 1))
       (define dist (vector-ref token 2))
       (define-values (len-symbol len-extra-bits len-extra-value)
         (deflate-length-code len))
       (define-values (dist-symbol dist-extra-bits dist-extra-value)
         (deflate-distance-code dist))
       (write-code ll-codes len-symbol)
       (when (positive? len-extra-bits)
         (write-bits len-extra-value len-extra-bits))
       (write-code dist-codes dist-symbol)
       (when (positive? dist-extra-bits)
         (write-bits dist-extra-value dist-extra-bits))]))
  (write-code ll-codes 256)
  (finish))
