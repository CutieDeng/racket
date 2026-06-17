#lang racket/base

(require racket/list
         racket/place
         racket/serialize
         racket/stream
         (prefix-in adapter: racket/private/pvector-runtime-adapter)
         (prefix-in public: racket/pvector)
         rackunit)

(define (check-model pv xs)
  (check-true (adapter:pvector? pv))
  (check-equal? (adapter:pvector-length pv) (length xs))
  (check-equal? (adapter:pvector->list pv) xs)
  (check-equal? (vector->list (adapter:pvector->vector pv)) xs)
  (for ([x (in-list xs)]
        [i (in-naturals)])
    (check-equal? (adapter:pvector-ref pv i) x)))

(define (chunk-vector->list chunks)
  (append*
   (for/list ([chunk (in-vector chunks)])
     (vector->list chunk))))

(define (chunk-vector-lengths chunks)
  (for/list ([chunk (in-vector chunks)])
    (vector-length chunk)))

(define (core-backend?)
  (eq? (adapter:pvector-runtime-adapter-backend) 'core))

(define (bc-vm?)
  (eq? (system-type 'vm) 'racket))

(define (kernel-procedure? name)
  (with-handlers ([exn:fail? (lambda (_) #f)])
    (procedure? (dynamic-require ''#%kernel name))))

(define (kernel-value name)
  (dynamic-require ''#%kernel name))

(define-namespace-anchor pvector-test-namespace-anchor)

(define (static-kernel-pvector-jit-score jit-enabled?)
  (parameterize ([eval-jit-enabled jit-enabled?])
    (eval
     '(let ()
        (local-require
         (only-in '#%kernel
                  core-pvector?
                  core-pvector-empty
                  core-pvector-empty?
                  core-pvector-length
                  core-make-single-pvector
                  core-make-deep2-pvector
                  core-make-deep3-pvector
                  core-make-deep4-pvector
                  core-pvector-ref
                  core-unsafe-pvector-length
                  core-unsafe-pvector-ref
                  core-pvector-view-left
                  core-pvector-view-right
                  core-unsafe-pvector-view-left
                  core-unsafe-pvector-view-right
                  core-unsafe-pvector-first
                  core-unsafe-pvector-last
                  core-pvector-cons-left
                  core-pvector-cons-right))
        (let loop ([i 0] [acc 0])
          (if (= i 40)
              acc
              (let* ([empty0 (core-pvector-empty)]
                     [empty1 (core-pvector-empty)]
                     [single (core-make-single-pvector 23)]
                     [deep2 (core-make-deep2-pvector 24 25)]
                     [deep3 (core-make-deep3-pvector 26 27 28)]
                     [deep4 (core-make-deep4-pvector 29 30 31 32)]
                     [zero-index (- i i)]
                     [wide-left (core-pvector-cons-left
                                 (core-pvector-cons-left
                                  (core-pvector-cons-left
                                   (core-pvector-cons-left deep4 28)
                                   27)
                                  26)
                                 25)]
                     [wide (core-pvector-cons-right
                            (core-pvector-cons-right
                             (core-pvector-cons-right
                              (core-pvector-cons-right deep4 33)
                              34)
                             35)
                            36)])
                (unless (eq? empty0 empty1)
                  (error 'static-kernel-pvector-jit-score
                         "empty pvector is not a singleton"))
                (loop (add1 i)
                      (+ acc
                         (if (core-pvector? empty0) 1 0)
                         (if (core-pvector-empty? empty0) 2 0)
                         (core-pvector-length single)
                         (core-unsafe-pvector-length deep4)
                         (core-pvector-ref deep2 zero-index)
                         (core-pvector-ref deep2 1)
                         (core-unsafe-pvector-ref deep3 2)
                         (core-pvector-view-left wide-left)
                         (core-pvector-view-right wide-left)
                         (core-unsafe-pvector-view-left wide-left)
                         (core-unsafe-pvector-view-right wide-left)
                         (core-unsafe-pvector-first wide-left)
                         (core-unsafe-pvector-last wide-left)
                         (core-pvector-view-left wide)
                         (core-pvector-view-right wide)
                         (core-unsafe-pvector-view-left wide)
                         (core-unsafe-pvector-view-right wide)
                         (core-unsafe-pvector-first wide)
                         (core-unsafe-pvector-last wide)))))))
     (namespace-anchor->namespace pvector-test-namespace-anchor))))

(define (check-no-chunk-shape-stats stats)
  (check-equal? (hash-ref stats 'chunked-tree? #t) #f)
  (check-equal? (hash-ref stats 'chunk-index-vectors #f) 0)
  (check-equal? (hash-ref stats 'chunk-index-slots #f) 0)
  (check-equal? (hash-ref stats 'ref-cache? #t) #f)
  (check-false (hash-has-key? stats 'append-ref-cache-index-vectors))
  (check-false (hash-has-key? stats 'shifted-cache-index-vectors))
  (define representation (hash-ref stats 'representation #f))
  (when representation
    (check-not-false (memq representation '(empty single large-finger))))
  (check-core-large-finger-tree-stats stats))

(define (check-core-large-finger-tree-stats stats)
  (when (and (core-backend?)
             (eq? (hash-ref stats 'representation #f) 'large-finger))
    (check-equal? (hash-ref stats 'payload-vectors #f) 0)
    (check-equal? (hash-ref stats 'digit-storage #f) 'inline)
    (check-equal? (hash-ref stats 'inline-digits #f) 2)
    (check-equal? (hash-ref stats 'digit-vectors #f) 0)
    (check-true (<= 1 (hash-ref stats 'prefix-length 0) 4))
    (check-true (<= 1 (hash-ref stats 'suffix-length 0) 4))
    (when (positive? (hash-ref stats 'middle-measure 0))
      (check-true (positive? (hash-ref stats 'finger-depth 0)))
      (check-true (positive? (hash-ref stats 'finger-nodes 0))))
    (check-equal? (+ (hash-ref stats 'node2 0)
                     (hash-ref stats 'node3 0))
                  (hash-ref stats 'finger-nodes 0))
    (check-equal? (hash-ref stats 'middle-measure #f)
                  (- (hash-ref stats 'length)
                     (hash-ref stats 'prefix-length)
                     (hash-ref stats 'suffix-length)))))

(test-case "kernel core pvector P0 primitives"
  (define core-pvector? (kernel-value 'core-pvector?))
  (define core-pvector-empty (kernel-value 'core-pvector-empty))
  (define core-pvector-empty? (kernel-value 'core-pvector-empty?))
  (define core-pvector-length (kernel-value 'core-pvector-length))
  (define core-pvector-shape-stats (kernel-value 'core-pvector-shape-stats))
  (define core-vector->pvector (kernel-value 'core-vector->pvector))
  (define core-list->pvector (kernel-value 'core-list->pvector))
  (define core-make-pvector (kernel-value 'core-make-pvector))
  (define core-pvector->vector (kernel-value 'core-pvector->vector))
  (define core-pvector->list (kernel-value 'core-pvector->list))
  (define core-pvector-ref (kernel-value 'core-pvector-ref))
  (define core-pvector-view-left (kernel-value 'core-pvector-view-left))
  (define core-pvector-view-right (kernel-value 'core-pvector-view-right))
  (define core-pvector-cursor-start
    (and (kernel-procedure? 'core-pvector-cursor-start)
         (kernel-value 'core-pvector-cursor-start)))
  (define core-pvector-cursor-next
    (and (kernel-procedure? 'core-pvector-cursor-next)
         (kernel-value 'core-pvector-cursor-next)))
  (define kernel-core-backend
    (hash-ref (core-pvector-shape-stats (core-pvector-empty)) 'backend #f))

  (define (check-core-model pv xs)
    (check-true (core-pvector? pv))
    (check-equal? (core-pvector-length pv) (length xs))
    (check-equal? (core-pvector->list pv) xs)
    (check-equal? (vector->list (core-pvector->vector pv)) xs)
    (check-true (sequence? pv))
    (check-equal? (for/list ([x pv]) x) xs)
    (check-true (stream? pv))
    (check-equal? (for/list ([x (in-stream pv)]) x) xs)
    (check-equal? (stream-empty? pv) (null? xs))
    (unless (null? xs)
      (check-equal? (stream-first pv) (car xs))
      (define rest (stream-rest pv))
      (check-true (core-pvector? rest))
      (check-equal? (core-pvector->list rest) (cdr xs)))
    (define stats (core-pvector-shape-stats pv))
    (check-no-chunk-shape-stats stats)
    (check-not-false (memq (hash-ref stats 'backend #f) '(core bc-native)))
    (cond
      [(null? xs)
       (check-true (core-pvector-empty? pv))
       (check-equal? (hash-ref stats 'representation #f) 'empty)]
      [(null? (cdr xs))
       (check-false (core-pvector-empty? pv))
       (check-equal? (hash-ref stats 'representation #f) 'single)
       (check-equal? (core-pvector-view-left pv) (car xs))
       (check-equal? (core-pvector-view-right pv) (car xs))]
      [else
       (check-false (core-pvector-empty? pv))
       (check-equal? (hash-ref stats 'representation #f) 'large-finger)
       (check-true (<= 1 (hash-ref stats 'prefix-length 0) 4))
       (check-true (<= 1 (hash-ref stats 'suffix-length 0) 4))
       (check-equal? (core-pvector-view-left pv) (car xs))
       (check-equal? (core-pvector-view-right pv) (last xs))])
    (for ([x (in-list xs)]
          [i (in-naturals)])
      (check-equal? (core-pvector-ref pv i) x)))

  (check-core-model (core-pvector-empty) '())
  (for ([size (in-list '(0 1 2 3 4 5 8 9 10 17 64))])
    (define xs (range size))
    (check-core-model (core-list->pvector xs) xs)
    (check-core-model (core-vector->pvector (list->vector xs)) xs))
  (check-core-model (core-list->pvector (range 130)) (range 130))
  (check-core-model (core-make-pvector 0 'x) '())
  (check-core-model (core-make-pvector 1 'x) '(x))
  (check-core-model (core-make-pvector 12 'x) (make-list 12 'x))
  (check-core-model (core-make-pvector 130 'x) (make-list 130 'x))
  (collect-garbage)
  (check-core-model (core-list->pvector (range 33)) (range 33))
  (when (eq? kernel-core-backend 'bc-native)
    (define (check-place-send-rejects v)
      (when (place-enabled?)
        (define p
          (place ch
            (define value (place-channel-get ch))
            (place-channel-put ch (format "~s" value))))
        (dynamic-wind
          void
          (lambda ()
            (check-exn #rx"cannot transmit a message containing value"
                       (lambda () (place-channel-put p v))))
          (lambda () (place-kill p)))))
    (let ([a (core-list->pvector '(a b (c)))]
          [b (core-list->pvector '(a b (c)))]
          [different (core-list->pvector '(a b (d)))])
      (check-equal? a b)
      (check-not-equal? a different)
      (check-false (equal? a '(a b (c))))
      (check-false (equal? a #(a b (c))))
      (check-equal? (equal-hash-code a) (equal-hash-code b))
      (check-equal? (equal-secondary-hash-code a)
                    (equal-secondary-hash-code b))
      (check-equal? (format "~s" a) "#<pvector:3>")
      (check-equal? (format "~s" (core-pvector-empty)) "#<pvector:0>")
      (check-exn #rx"expected: serializable\\?"
                 (lambda () (serialize a)))
      (check-exn #rx"expected: serializable\\?"
                 (lambda () (serialize (core-pvector-empty))))
      (check-false (place-message-allowed? a))
      (check-false (place-message-allowed? (vector a)))
      (check-false (place-message-allowed? (core-pvector-empty)))
      (check-place-send-rejects a)
      (check-place-send-rejects (core-pvector-empty)))
    (check-true (procedure? core-pvector-cursor-start))
    (check-true (procedure? core-pvector-cursor-next))
    (check-false (vector? (core-pvector-cursor-start (core-pvector-empty) #f)))
    (check-exn #rx"pvector cursor\\?"
               (lambda ()
                 (core-pvector-cursor-next
                  (vector (core-pvector-empty) #f #f #f #f #f #f #f #f))))
    (check-exn #rx"pvector cursor\\?"
               (lambda () (core-pvector-cursor-next 'not-a-cursor)))
    (define (cursor->list pv reverse?)
      (define len (core-pvector-length pv))
      (define cursor (core-pvector-cursor-start pv reverse?))
      (for/list ([i (in-range len)])
        (core-pvector-cursor-next cursor)))
    (define (check-cursor-survives-gc xs reverse?)
      (define expected (if reverse? (reverse xs) xs))
      (define pv (core-list->pvector xs))
      (define cursor (core-pvector-cursor-start pv reverse?))
      (define prefix-count 37)
      (define prefix
        (for/list ([i (in-range prefix-count)])
          (core-pvector-cursor-next cursor)))
      (collect-garbage)
      (collect-garbage)
      (define suffix
        (for/list ([i (in-range (- (length expected) prefix-count))])
          (core-pvector-cursor-next cursor)))
      (check-equal? (append prefix suffix) expected))
    (for ([xs (in-list (list null
                             '(a)
                             '(a b)
                             '(a b c d)
                             (range 17)
                             (range 130)
                             (range 513)))])
      (define pv (core-list->pvector xs))
      (check-equal? (cursor->list pv #f) xs)
      (check-equal? (cursor->list pv #t) (reverse xs)))
    (check-cursor-survives-gc (range 513) #f)
    (check-cursor-survives-gc (range 513) #t)
    (let* ([xs (range 513)]
           [whole (core-list->pvector xs)]
           [joined (core-pvector-append
                    (core-list->pvector (take xs 257))
                    (core-list->pvector (drop xs 257)))]
           [from-vector (core-vector->pvector (list->vector xs))]
           [different (core-pvector-set joined 256 'changed)])
      (check-equal? whole joined)
      (check-equal? whole from-vector)
      (check-not-equal? whole different)
      (check-equal? (equal-hash-code whole)
                    (equal-hash-code joined))
      (check-equal? (equal-hash-code whole)
                    (equal-hash-code from-vector))
      (check-equal? (equal-secondary-hash-code whole)
                    (equal-secondary-hash-code joined))
      (check-equal? (equal-secondary-hash-code whole)
                    (equal-secondary-hash-code from-vector)))
    (check-exn exn:fail:contract?
               (lambda () (core-pvector-length '(not a pvector)))))
  (check-exn exn:fail:contract?
             (lambda () (core-pvector-ref (core-list->pvector '(a b)) -1)))
  (check-exn exn:fail:contract?
             (lambda () (core-pvector-ref (core-list->pvector '(a b)) 2))))

(test-case "kernel core pvector GC retention"
  (define core-vector->pvector (kernel-value 'core-vector->pvector))
  (define core-make-pvector (kernel-value 'core-make-pvector))
  (define core-pvector-length (kernel-value 'core-pvector-length))
  (define core-pvector-shape-stats (kernel-value 'core-pvector-shape-stats))
  (define core-pvector->list (kernel-value 'core-pvector->list))
  (define core-pvector->vector (kernel-value 'core-pvector->vector))
  (define core-pvector-ref (kernel-value 'core-pvector-ref))
  (define core-pvector-set (kernel-value 'core-pvector-set))
  (define core-pvector-cons-left (kernel-value 'core-pvector-cons-left))
  (define core-pvector-cons-right (kernel-value 'core-pvector-cons-right))
  (define core-pvector-append (kernel-value 'core-pvector-append))
  (define core-pvector-take (kernel-value 'core-pvector-take))
  (define core-pvector-drop (kernel-value 'core-pvector-drop))

  (define (make-retained-pvector size)
    (define payload
      (for/vector ([i (in-range size)])
        (box (vector 'payload i))))
    (define weak-payload
      (for/vector ([value (in-vector payload)])
        (make-weak-box value)))
    (values (core-vector->pvector payload) weak-payload))

  (define (weak-payload-ref weak-payload index)
    (weak-box-value (vector-ref weak-payload index) #f))

  (define (check-retained pv len expected-ref)
    (collect-garbage)
    (collect-garbage)
    (check-equal? (core-pvector-length pv) len)
    (check-no-chunk-shape-stats (core-pvector-shape-stats pv))
    (define as-list (core-pvector->list pv))
    (define as-vector (core-pvector->vector pv))
    (check-equal? (length as-list) len)
    (check-equal? (vector-length as-vector) len)
    (for ([list-value (in-list as-list)]
          [vector-value (in-vector as-vector)]
          [index (in-range len)])
      (define expected (expected-ref index))
      (check-not-false expected)
      (check-eq? (core-pvector-ref pv index) expected)
      (check-eq? list-value expected)
      (check-eq? vector-value expected)))

  (define-values (base base-weak) (make-retained-pvector 257))
  (check-retained base
                  257
                  (lambda (index)
                    (weak-payload-ref base-weak index)))

  (let ()
    (define-values (pv weak-payload) (make-retained-pvector 257))
    (define sentinel (box 'left-sentinel))
    (define left (core-pvector-cons-left pv sentinel))
    (set! pv #f)
    (check-retained left
                    258
                    (lambda (index)
                      (if (zero? index)
                          sentinel
                          (weak-payload-ref weak-payload (sub1 index))))))

  (let ()
    (define-values (pv weak-payload) (make-retained-pvector 257))
    (define sentinel (box 'right-sentinel))
    (define right (core-pvector-cons-right pv sentinel))
    (set! pv #f)
    (check-retained right
                    258
                    (lambda (index)
                      (if (= index 257)
                          sentinel
                          (weak-payload-ref weak-payload index)))))

  (let ()
    (define-values (pv weak-payload) (make-retained-pvector 257))
    (define replacement (box 'replacement))
    (define changed (core-pvector-set pv 128 replacement))
    (set! pv #f)
    (check-retained changed
                    257
                    (lambda (index)
                      (if (= index 128)
                          replacement
                          (weak-payload-ref weak-payload index)))))

  (let ()
    (define-values (left left-weak) (make-retained-pvector 130))
    (define-values (right right-weak) (make-retained-pvector 127))
    (define appended (core-pvector-append left right))
    (set! left #f)
    (set! right #f)
    (check-retained appended
                    257
                    (lambda (index)
                      (if (< index 130)
                          (weak-payload-ref left-weak index)
                          (weak-payload-ref right-weak (- index 130))))))

  (let ()
    (define-values (pv weak-payload) (make-retained-pvector 257))
    (define repeated (box 'repeated))
    (define appended (core-pvector-append pv (core-make-pvector 5 repeated)))
    (define prefix (core-pvector-take appended 130))
    (define suffix (core-pvector-drop appended 130))
    (set! pv #f)
    (set! appended #f)
    (check-retained prefix
                    130
                    (lambda (index)
                      (weak-payload-ref weak-payload index)))
    (check-retained suffix
                    132
                    (lambda (index)
                      (if (< index 127)
                          (weak-payload-ref weak-payload (+ index 130))
                          repeated)))))

(test-case "kernel core pvector direct set primitive"
  (check-true (kernel-procedure? 'core-pvector-set))
  (define core-list->pvector (kernel-value 'core-list->pvector))
  (define core-pvector-shape-stats (kernel-value 'core-pvector-shape-stats))
  (define core-pvector->list (kernel-value 'core-pvector->list))
  (define core-pvector-ref (kernel-value 'core-pvector-ref))
  (define core-pvector-set (kernel-value 'core-pvector-set))

  (define (replace-nth xs idx value)
    (let loop ([xs xs] [i 0])
      (cond
        [(null? xs) '()]
        [(= i idx) (cons value (cdr xs))]
        [else (cons (car xs) (loop (cdr xs) (add1 i)))])))

  (define (check-core-set size indexes)
    (define xs (range size))
    (define pv (core-list->pvector xs))
    (for ([idx (in-list indexes)])
      (define value (string->symbol (format "changed-~a-~a" size idx)))
      (define expected (replace-nth xs idx value))
      (define pv* (core-pvector-set pv idx value))
      (check-no-chunk-shape-stats (core-pvector-shape-stats pv*))
      (check-equal? (core-pvector->list pv*) expected)
      (check-equal? (core-pvector-ref pv* idx) value)
      (check-equal? (core-pvector->list pv) xs)
      (check-true (eq? pv (core-pvector-set pv idx (list-ref xs idx))))
      (check-false (eq? pv pv*))))

  (check-core-set 1 '(0))
  (check-core-set 2 '(0 1))
  (check-core-set 4 '(0 1 2 3))
  (check-core-set 9 '(0 3 4 5 6 8))
  (check-core-set 17 '(0 3 4 8 12 16))
  (check-core-set 64 '(0 3 4 17 33 60 63))
  (check-exn exn:fail:contract?
             (lambda () (core-pvector-set (core-list->pvector '(a b)) -1 'x)))
  (check-exn exn:fail:contract?
             (lambda () (core-pvector-set (core-list->pvector '(a b)) 2 'x))))

(test-case "kernel core pvector direct cons primitives"
  (check-true (kernel-procedure? 'core-pvector-cons-left))
  (check-true (kernel-procedure? 'core-pvector-cons-right))
  (define core-list->pvector (kernel-value 'core-list->pvector))
  (define core-pvector-shape-stats (kernel-value 'core-pvector-shape-stats))
  (define core-pvector->list (kernel-value 'core-pvector->list))
  (define core-pvector-ref (kernel-value 'core-pvector-ref))
  (define core-pvector-cons-left (kernel-value 'core-pvector-cons-left))
  (define core-pvector-cons-right (kernel-value 'core-pvector-cons-right))

  (define (check-core-cons size)
    (define xs (range size))
    (define pv (core-list->pvector xs))
    (define left-value (string->symbol (format "left-~a" size)))
    (define right-value (string->symbol (format "right-~a" size)))
    (define left* (core-pvector-cons-left pv left-value))
    (define right* (core-pvector-cons-right pv right-value))
    (check-no-chunk-shape-stats (core-pvector-shape-stats left*))
    (check-no-chunk-shape-stats (core-pvector-shape-stats right*))
    (check-equal? (core-pvector->list left*) (cons left-value xs))
    (check-equal? (core-pvector->list right*) (append xs (list right-value)))
    (check-equal? (core-pvector-ref left* 0) left-value)
    (check-equal? (core-pvector-ref right* size) right-value)
    (check-equal? (core-pvector->list pv) xs))

  (for ([size (in-list '(0 1 2 3 4 5 8 9 10 17 64 129))])
    (check-core-cons size))
  (when (bc-vm?)
    (check-exn exn:fail:contract?
               (lambda () (core-pvector-cons-left '(not a pvector) 'x)))
    (check-exn exn:fail:contract?
               (lambda () (core-pvector-cons-right '(not a pvector) 'x)))))

(test-case "kernel core pvector direct pop primitives"
  (check-true (kernel-procedure? 'core-pvector-pop-left))
  (check-true (kernel-procedure? 'core-pvector-pop-right))
  (define core-list->pvector (kernel-value 'core-list->pvector))
  (define core-pvector-empty ((kernel-value 'core-pvector-empty)))
  (define core-pvector-shape-stats (kernel-value 'core-pvector-shape-stats))
  (define core-pvector->list (kernel-value 'core-pvector->list))
  (define core-pvector-pop-left (kernel-value 'core-pvector-pop-left))
  (define core-pvector-pop-right (kernel-value 'core-pvector-pop-right))

  (define (check-core-pop size)
    (define xs (range size))
    (define pv (core-list->pvector xs))
    (define-values (left-value left-rest) (core-pvector-pop-left pv))
    (define-values (right-value right-rest) (core-pvector-pop-right pv))
    (check-no-chunk-shape-stats (core-pvector-shape-stats left-rest))
    (check-no-chunk-shape-stats (core-pvector-shape-stats right-rest))
    (check-equal? left-value (car xs))
    (check-equal? (core-pvector->list left-rest) (cdr xs))
    (check-equal? right-value (last xs))
    (check-equal? (core-pvector->list right-rest) (drop-right xs 1))
    (check-equal? (core-pvector->list pv) xs))

  (for ([size (in-list '(1 2 3 4 5 8 9 10 17 64 129))])
    (check-core-pop size))
  (check-exn exn:fail?
             (lambda () (core-pvector-pop-left core-pvector-empty)))
  (check-exn exn:fail?
             (lambda () (core-pvector-pop-right core-pvector-empty)))
  (when (bc-vm?)
    (check-exn exn:fail:contract?
               (lambda () (core-pvector-pop-left '(not a pvector))))
    (check-exn exn:fail:contract?
               (lambda () (core-pvector-pop-right '(not a pvector))))))

(test-case "kernel core pvector direct append primitive"
  (check-true (kernel-procedure? 'core-pvector-append))
  (define core-list->pvector (kernel-value 'core-list->pvector))
  (define core-pvector-empty ((kernel-value 'core-pvector-empty)))
  (define core-pvector-length (kernel-value 'core-pvector-length))
  (define core-pvector-shape-stats (kernel-value 'core-pvector-shape-stats))
  (define core-pvector->list (kernel-value 'core-pvector->list))
  (define core-pvector-ref (kernel-value 'core-pvector-ref))
  (define core-pvector-set (kernel-value 'core-pvector-set))
  (define core-pvector-cons-left (kernel-value 'core-pvector-cons-left))
  (define core-pvector-cons-right (kernel-value 'core-pvector-cons-right))
  (define core-pvector-pop-left (kernel-value 'core-pvector-pop-left))
  (define core-pvector-pop-right (kernel-value 'core-pvector-pop-right))
  (define core-pvector-append (kernel-value 'core-pvector-append))

  (define (replace-nth xs idx value)
    (let loop ([xs xs] [i 0])
      (cond
        [(null? xs) '()]
        [(= i idx) (cons value (cdr xs))]
        [else (cons (car xs) (loop (cdr xs) (add1 i)))])))

  (define (check-core-state pv xs)
    (define len (length xs))
    (check-equal? (core-pvector-length pv) len)
    (check-no-chunk-shape-stats (core-pvector-shape-stats pv))
    (check-equal? (core-pvector->list pv) xs)
    (unless (zero? len)
      (define last-idx (sub1 len))
      (define middle-idx (quotient len 2))
      (check-equal? (core-pvector-ref pv 0) (car xs))
      (check-equal? (core-pvector-ref pv last-idx) (last xs))
      (check-equal? (core-pvector-ref pv middle-idx)
                    (list-ref xs middle-idx))))

  (define (check-core-append left-size right-size)
    (define left-xs (range left-size))
    (define right-xs (range left-size (+ left-size right-size)))
    (define expected (append left-xs right-xs))
    (define left-pv (core-list->pvector left-xs))
    (define right-pv (core-list->pvector right-xs))
    (define appended (core-pvector-append left-pv right-pv))
    (check-no-chunk-shape-stats (core-pvector-shape-stats appended))
    (check-equal? (core-pvector->list appended) expected)
    (unless (null? expected)
      (check-equal? (core-pvector-ref appended 0) (car expected))
      (check-equal? (core-pvector-ref appended (sub1 (length expected))) (last expected))
      (check-equal? (core-pvector-ref appended (quotient (length expected) 2))
                    (list-ref expected (quotient (length expected) 2))))
    (check-equal? (core-pvector->list left-pv) left-xs)
    (check-equal? (core-pvector->list right-pv) right-xs)
    (when (zero? left-size)
      (check-true (eq? appended right-pv)))
    (when (zero? right-size)
      (check-true (eq? appended left-pv))))

  (define (append-run-size)
    (case (random 7)
      [(0 1) 0]
      [(2) 1]
      [(3) (random 5)]
      [(4) (random 17)]
      [(5) (random 65)]
      [else (random 130)]))

  (define (check-random-append-model)
    (random-seed 20260615)
    (let loop ([step 0] [next 0] [xs '()] [pv core-pvector-empty])
      (check-core-state pv xs)
      (when (< step 500)
        (define len (length xs))
        (define op (if (> len 700) (+ 3 (random 2)) (random 7)))
        (case op
          [(0)
           (loop (add1 step)
                 (add1 next)
                 (cons next xs)
                 (core-pvector-cons-left pv next))]
          [(1)
           (loop (add1 step)
                 (add1 next)
                 (append xs (list next))
                 (core-pvector-cons-right pv next))]
          [(2)
           (define size (append-run-size))
           (define right-xs (range next (+ next size)))
           (define right-pv (core-list->pvector right-xs))
           (loop (add1 step)
                 (+ next size)
                 (append xs right-xs)
                 (core-pvector-append pv right-pv))]
          [(3)
           (if (null? xs)
               (loop (add1 step) next xs pv)
               (let-values ([(value rest) (core-pvector-pop-left pv)])
                 (check-equal? value (car xs))
                 (loop (add1 step) next (cdr xs) rest)))]
          [(4)
           (if (null? xs)
               (loop (add1 step) next xs pv)
               (let-values ([(value rest) (core-pvector-pop-right pv)])
                 (check-equal? value (last xs))
                 (loop (add1 step) next (drop-right xs 1) rest)))]
          [(5)
           (if (null? xs)
               (loop (add1 step) next xs pv)
               (let* ([idx (random len)]
                      [value (list 'set step idx)]
                      [xs* (replace-nth xs idx value)]
                      [pv* (core-pvector-set pv idx value)])
                 (loop (add1 step) next xs* pv*)))]
          [else
           (define size (random 33))
           (define left-xs (range next (+ next size)))
           (define left-pv (core-list->pvector left-xs))
           (loop (add1 step)
                 (+ next size)
                 (append left-xs xs)
                 (core-pvector-append left-pv pv))]))))

  (for ([sizes (in-list '((0 0) (0 1) (1 0) (1 1)
                          (2 3) (3 2) (4 4) (8 9) (9 8)
                          (17 64) (64 17) (129 130) (256 257)))])
    (check-core-append (car sizes) (cadr sizes)))
  (check-random-append-model)
  (when (bc-vm?)
    (check-exn exn:fail:contract?
               (lambda () (core-pvector-append '(not a pvector) core-pvector-empty)))
    (check-exn exn:fail:contract?
               (lambda () (core-pvector-append core-pvector-empty '(not a pvector))))))

(test-case "kernel core pvector direct map for-each fold primitives"
  (check-true (kernel-procedure? 'core-pvector-map))
  (check-true (kernel-procedure? 'core-pvector-for-each))
  (define core-list->pvector (kernel-value 'core-list->pvector))
  (define core-pvector-empty ((kernel-value 'core-pvector-empty)))
  (define core-pvector-length (kernel-value 'core-pvector-length))
  (define core-pvector-shape-stats (kernel-value 'core-pvector-shape-stats))
  (define core-pvector->list (kernel-value 'core-pvector->list))
  (define core-pvector-map (kernel-value 'core-pvector-map))
  (define core-pvector-for-each (kernel-value 'core-pvector-for-each))
  (define core-pvector-fold-left
    (and (kernel-procedure? 'core-pvector-fold-left)
         (kernel-value 'core-pvector-fold-left)))

  (define (check-core-list pv xs)
    (check-equal? (core-pvector-length pv) (length xs))
    (check-no-chunk-shape-stats (core-pvector-shape-stats pv))
    (check-equal? (core-pvector->list pv) xs))

  (define (check-core-map-for-each size)
    (define xs (range size))
    (define pv (core-list->pvector xs))
    (define seen-map null)
    (define mapped
      (core-pvector-map pv
                        (lambda (x)
                          (set! seen-map (cons x seen-map))
                          (add1 x))))
    (check-core-list mapped (map add1 xs))
    (when (bc-vm?)
      (check-equal? (reverse seen-map) xs))
    (check-true (eq? pv (core-pvector-map pv values)))
    (check-core-list (core-pvector-map pv void)
                     (make-list size (void)))
    (define seen-for-each null)
    (check-equal?
     (core-pvector-for-each pv
                            (lambda (x)
                              (set! seen-for-each (cons x seen-for-each))
                              (values x 'ignored)))
     (void))
    (check-equal? (reverse seen-for-each) xs)
    (check-equal? (core-pvector-for-each pv values) (void))
    (check-equal? (core-pvector-for-each pv void) (void))
    (when core-pvector-fold-left
      (check-equal? (core-pvector-fold-left pv 0 +)
                    (apply + xs))
      (check-equal? (core-pvector-fold-left
                     pv
                     null
                     (lambda (acc x) (cons x acc)))
                    (reverse xs)))
    (check-core-list pv xs))

  (for ([size (in-list '(0 1 2 3 4 5 8 9 17 64 129))])
    (check-core-map-for-each size))
  (check-exn exn:fail?
             (lambda ()
               (core-pvector-map (core-list->pvector '(1))
                                 (lambda (x) (values x x)))))
  (check-exn exn:fail?
             (lambda ()
               (core-pvector-map (core-list->pvector '(1 2))
                                 (lambda (x y) x))))
  (check-exn exn:fail?
             (lambda ()
               (core-pvector-for-each (core-list->pvector '(1 2))
                                      (lambda (x y) x))))
  (when core-pvector-fold-left
    (check-exn exn:fail?
               (lambda ()
                 (core-pvector-fold-left (core-list->pvector '(1 2))
                                         0
                                         (lambda (x) x)))))
  (when (bc-vm?)
    (check-exn exn:fail?
               (lambda () (core-pvector-map core-pvector-empty 'not-a-proc)))
    (check-exn exn:fail?
               (lambda () (core-pvector-for-each core-pvector-empty 'not-a-proc)))))

(test-case "kernel core pvector direct split copy insert delete primitives"
  (for ([name (in-list '(core-pvector-split-at
                         core-pvector-split-at-right
                         core-pvector-split
                         core-pvector-insert
                         core-pvector-delete
                         core-pvector-take
                         core-pvector-drop
                         core-pvector-take-right
                         core-pvector-drop-right
                         core-pvector-copy))])
    (check-true (kernel-procedure? name)))
  (define core-list->pvector (kernel-value 'core-list->pvector))
  (define core-pvector-empty ((kernel-value 'core-pvector-empty)))
  (define core-pvector-shape-stats (kernel-value 'core-pvector-shape-stats))
  (define core-pvector->list (kernel-value 'core-pvector->list))
  (define core-pvector-ref (kernel-value 'core-pvector-ref))
  (define core-pvector-append (kernel-value 'core-pvector-append))
  (define core-pvector-cons-left (kernel-value 'core-pvector-cons-left))
  (define core-pvector-cons-right (kernel-value 'core-pvector-cons-right))
  (define core-pvector-pop-left (kernel-value 'core-pvector-pop-left))
  (define core-pvector-pop-right (kernel-value 'core-pvector-pop-right))
  (define core-pvector-split-at (kernel-value 'core-pvector-split-at))
  (define core-pvector-split-at-right (kernel-value 'core-pvector-split-at-right))
  (define core-pvector-split (kernel-value 'core-pvector-split))
  (define core-pvector-insert (kernel-value 'core-pvector-insert))
  (define core-pvector-delete (kernel-value 'core-pvector-delete))
  (define core-pvector-take (kernel-value 'core-pvector-take))
  (define core-pvector-drop (kernel-value 'core-pvector-drop))
  (define core-pvector-take-right (kernel-value 'core-pvector-take-right))
  (define core-pvector-drop-right (kernel-value 'core-pvector-drop-right))
  (define core-pvector-copy (kernel-value 'core-pvector-copy))

  (define (list-insert xs idx value)
    (append (take xs idx) (list value) (drop xs idx)))

  (define (check-core-list pv xs)
    (check-no-chunk-shape-stats (core-pvector-shape-stats pv))
    (check-equal? (core-pvector->list pv) xs)
    (unless (null? xs)
      (check-equal? (core-pvector-ref pv 0) (car xs))
      (check-equal? (core-pvector-ref pv (sub1 (length xs))) (last xs))
      (check-equal? (core-pvector-ref pv (quotient (length xs) 2))
                    (list-ref xs (quotient (length xs) 2)))))

  (define (positions size)
    (remove-duplicates
     (filter (lambda (pos) (<= 0 pos size))
             (list 0 1 2 (quotient size 2) (max 0 (- size 2))
                   (max 0 (sub1 size)) size))))

  (define (indexes size)
    (remove-duplicates
     (filter (lambda (idx) (< -1 idx size))
             (list 0 1 (quotient size 2) (max 0 (- size 2))
                   (max 0 (sub1 size))))))

  (define (check-slice-size size)
    (define xs (range size))
    (define pv (core-list->pvector xs))
    (define front-value (list 'front size))
    (define back-value (list 'back size))
    (define front-inserted (core-pvector-insert pv 0 front-value))
    (define front-consed (core-pvector-cons-left pv front-value))
    (define back-inserted (core-pvector-insert pv size back-value))
    (define back-consed (core-pvector-cons-right pv back-value))
    (check-core-list front-inserted (cons front-value xs))
    (check-core-list front-consed (cons front-value xs))
    (check-core-list back-inserted (append xs (list back-value)))
    (check-core-list back-consed (append xs (list back-value)))
    (when (bc-vm?)
      (check-equal? front-inserted front-consed)
      (check-equal? back-inserted back-consed))
    (unless (zero? size)
      (define-values (front-rest front-deleted)
        (core-pvector-delete pv 0))
      (define-values (front-value* front-rest*)
        (core-pvector-pop-left pv))
      (define-values (back-rest back-deleted)
        (core-pvector-delete pv (sub1 size)))
      (define-values (back-value* back-rest*)
        (core-pvector-pop-right pv))
      (define-values (split-front-left split-front-value split-front-right)
        (core-pvector-split pv 0))
      (define-values (split-back-left split-back-value split-back-right)
        (core-pvector-split pv (sub1 size)))
      (check-equal? front-deleted front-value*)
      (check-core-list front-rest (cdr xs))
      (check-core-list front-rest* (cdr xs))
      (check-equal? back-deleted back-value*)
      (check-core-list back-rest (drop-right xs 1))
      (check-core-list back-rest* (drop-right xs 1))
      (check-core-list split-front-left '())
      (check-equal? split-front-value front-value*)
      (check-core-list split-front-right (cdr xs))
      (check-core-list split-back-left (drop-right xs 1))
      (check-equal? split-back-value back-value*)
      (check-core-list split-back-right '())
      (when (bc-vm?)
        (check-equal? front-rest front-rest*)
        (check-equal? back-rest back-rest*)
        (check-equal? split-front-left core-pvector-empty)
        (check-equal? split-front-right front-rest*)
        (check-equal? split-back-left back-rest*)
        (check-equal? split-back-right core-pvector-empty)))
    (for ([pos (in-list (positions size))])
      (define-values (left right) (core-pvector-split-at pv pos))
      (define-values (right-part left-part)
        (core-pvector-split-at-right pv (- size pos)))
      (check-core-list left (take xs pos))
      (check-core-list right (drop xs pos))
      (check-core-list right-part (drop xs pos))
      (check-core-list left-part (take xs pos))
      (when (zero? pos)
        (check-true (eq? left core-pvector-empty))
        (check-true (eq? right pv))
        (check-true (eq? right-part pv))
        (check-true (eq? left-part core-pvector-empty)))
      (when (= pos size)
        (check-true (eq? left pv))
        (check-true (eq? right core-pvector-empty))
        (check-true (eq? right-part core-pvector-empty))
        (check-true (eq? left-part pv)))
      (check-core-list (core-pvector-take pv pos) (take xs pos))
      (check-core-list (core-pvector-drop pv pos) (drop xs pos))
      (check-core-list (core-pvector-take-right pv pos) (take-right xs pos))
      (check-core-list (core-pvector-drop-right pv pos) (drop-right xs pos))
      (when (bc-vm?)
        (check-equal? (core-pvector-take pv pos) left)
        (check-equal? (core-pvector-drop pv pos) right)
        (check-equal? (core-pvector-take-right pv (- size pos)) right)
        (check-equal? (core-pvector-drop-right pv (- size pos)) left))
      (when (zero? pos)
        (check-true (eq? (core-pvector-take pv pos) core-pvector-empty))
        (check-true (eq? (core-pvector-drop pv pos) pv))
        (check-true (eq? (core-pvector-take-right pv pos) core-pvector-empty))
        (check-true (eq? (core-pvector-drop-right pv pos) pv)))
      (when (= pos size)
        (check-true (eq? (core-pvector-take pv pos) pv))
        (check-true (eq? (core-pvector-drop pv pos) core-pvector-empty))
        (check-true (eq? (core-pvector-take-right pv pos) pv))
        (check-true (eq? (core-pvector-drop-right pv pos) core-pvector-empty))))
    (for* ([start (in-list (positions size))]
           [end (in-list (positions size))]
           #:when (<= start end))
      (define copied (core-pvector-copy pv start end))
      (check-core-list copied (take (drop xs start) (- end start)))
      (when (and (zero? start) (= end size))
        (check-true (eq? copied pv))))
    (for ([idx (in-list (indexes size))])
      (define-values (left value right) (core-pvector-split pv idx))
      (define-values (rest deleted) (core-pvector-delete pv idx))
      (check-core-list left (take xs idx))
      (check-equal? value (list-ref xs idx))
      (check-core-list right (drop xs (add1 idx)))
      (when (zero? idx)
        (check-true (eq? left core-pvector-empty)))
      (when (= idx (sub1 size))
        (check-true (eq? right core-pvector-empty)))
      (check-equal? deleted (list-ref xs idx))
      (check-core-list rest (append (take xs idx) (drop xs (add1 idx)))))
    (for ([pos (in-list (positions size))])
      (define value (list 'insert size pos))
      (check-core-list (core-pvector-insert pv pos value)
                       (list-insert xs pos value))))

  (for ([size (in-list '(0 1 2 3 4 5 8 9 17 64 129))])
    (check-slice-size size))
  (let* ([left-xs (range 5000)]
         [right-xs (range 5000 10000)]
         [xs (append left-xs right-xs)]
         [pv (core-pvector-append (core-list->pvector left-xs)
                                  (core-list->pvector right-xs))])
    (for ([pos (in-list '(0 1 2 3 4 4096 5000 5001 8192
                          9996 9997 9998 9999 10000))])
      (define-values (left right) (core-pvector-split-at pv pos))
      (check-core-list left (take xs pos))
      (check-core-list right (drop xs pos))
      (check-core-list (core-pvector-take pv pos) (take xs pos))
      (check-core-list (core-pvector-drop pv pos) (drop xs pos))
      (check-core-list (core-pvector-take-right pv (- 10000 pos)) (drop xs pos))
      (check-core-list (core-pvector-drop-right pv (- 10000 pos)) (take xs pos))
      (when (bc-vm?)
        (check-equal? (core-pvector-take pv pos) left)
        (check-equal? (core-pvector-drop pv pos) right)
        (check-equal? (core-pvector-take-right pv (- 10000 pos)) right)
        (check-equal? (core-pvector-drop-right pv (- 10000 pos)) left)
        (when (memv pos '(9997 9998 9999))
          (check-equal? (core-pvector-shape-stats (core-pvector-take pv pos))
                        (core-pvector-shape-stats left))
          (check-equal? (core-pvector-shape-stats
                         (core-pvector-drop-right pv (- 10000 pos)))
                        (core-pvector-shape-stats left)))))
    (when (bc-vm?)
      (define stats (core-pvector-shape-stats pv))
      (define prefix-boundary (hash-ref stats 'prefix-length))
      (define suffix-boundary
        (- (hash-ref stats 'length) (hash-ref stats 'suffix-length)))
      (for ([pos (in-list (remove-duplicates
                           (list prefix-boundary suffix-boundary)))])
        (define-values (left right) (core-pvector-split-at pv pos))
        (check-equal? (core-pvector-take pv pos) left)
        (check-equal? (core-pvector-drop pv pos) right)
        (check-equal? (core-pvector-take-right pv (- 10000 pos)) right)
        (check-equal? (core-pvector-drop-right pv (- 10000 pos)) left)
        (check-equal? (core-pvector-shape-stats (core-pvector-take pv pos))
                      (core-pvector-shape-stats left))
        (check-equal? (core-pvector-shape-stats (core-pvector-drop pv pos))
                      (core-pvector-shape-stats right)))
      (when (> prefix-boundary 2)
        (define prefix-split-index 1)
        (define-values (left value right)
          (core-pvector-split pv prefix-split-index))
        (define right-stats (core-pvector-shape-stats right))
        (check-core-list left (take xs prefix-split-index))
        (check-equal? value prefix-split-index)
        (check-core-list right (drop xs (add1 prefix-split-index)))
        (check-equal? (hash-ref right-stats 'prefix-length)
                      (- prefix-boundary prefix-split-index 1))
        (check-equal? (hash-ref right-stats 'suffix-length)
                      (hash-ref stats 'suffix-length))
        (check-equal? (hash-ref right-stats 'middle-measure)
                      (hash-ref stats 'middle-measure)))
      (when (> (hash-ref stats 'suffix-length) 2)
        (define suffix-split-index (add1 suffix-boundary))
        (define-values (left value right)
          (core-pvector-split pv suffix-split-index))
        (define left-stats (core-pvector-shape-stats left))
        (check-core-list left (take xs suffix-split-index))
        (check-equal? value suffix-split-index)
        (check-core-list right (drop xs (add1 suffix-split-index)))
        (check-equal? (hash-ref left-stats 'prefix-length)
                      (hash-ref stats 'prefix-length))
        (check-equal? (hash-ref left-stats 'suffix-length) 1)
        (check-equal? (hash-ref left-stats 'middle-measure)
                      (hash-ref stats 'middle-measure)))
      (when (> prefix-boundary 1)
        (define prefix-delete-index (sub1 prefix-boundary))
        (define-values (rest deleted)
          (core-pvector-delete pv prefix-delete-index))
        (define rest-stats (core-pvector-shape-stats rest))
        (check-equal? deleted prefix-delete-index)
        (check-core-list rest (append (take xs prefix-delete-index)
                                      (drop xs (add1 prefix-delete-index))))
        (check-equal? (hash-ref rest-stats 'prefix-length)
                      (sub1 prefix-boundary))
        (check-equal? (hash-ref rest-stats 'suffix-length)
                      (hash-ref stats 'suffix-length))
        (check-equal? (hash-ref rest-stats 'middle-measure)
                      (hash-ref stats 'middle-measure)))
      (when (> (hash-ref stats 'suffix-length) 1)
        (define-values (rest deleted)
          (core-pvector-delete pv suffix-boundary))
        (define rest-stats (core-pvector-shape-stats rest))
        (check-equal? deleted suffix-boundary)
        (check-core-list rest (append (take xs suffix-boundary)
                                      (drop xs (add1 suffix-boundary))))
        (check-equal? (hash-ref rest-stats 'prefix-length)
                      (hash-ref stats 'prefix-length))
        (check-equal? (hash-ref rest-stats 'suffix-length)
                      (sub1 (hash-ref stats 'suffix-length)))
        (check-equal? (hash-ref rest-stats 'middle-measure)
                      (hash-ref stats 'middle-measure)))
      (when (> prefix-boundary 1)
        (define prefix-insert-index (sub1 prefix-boundary))
        (define-values (base deleted)
          (core-pvector-delete pv prefix-insert-index))
        (define base-stats (core-pvector-shape-stats base))
        (check-equal? deleted prefix-insert-index)
        (check-equal? (hash-ref base-stats 'prefix-length)
                      (sub1 prefix-boundary))
        (when (< (hash-ref base-stats 'prefix-length) 4)
          (define restored
            (core-pvector-insert base prefix-insert-index deleted))
          (check-core-list restored xs)
          (check-equal? (core-pvector-shape-stats restored) stats)))
      (when (> (hash-ref stats 'suffix-length) 1)
        (define-values (base deleted)
          (core-pvector-delete pv suffix-boundary))
        (define base-stats (core-pvector-shape-stats base))
        (check-equal? deleted suffix-boundary)
        (check-equal? (hash-ref base-stats 'suffix-length)
                      (sub1 (hash-ref stats 'suffix-length)))
        (when (< (hash-ref base-stats 'suffix-length) 4)
          (define restored
            (core-pvector-insert base suffix-boundary deleted))
          (check-core-list restored xs)
          (check-equal? (core-pvector-shape-stats restored) stats)))
      (when (and (> prefix-boundary 1)
                 (> (hash-ref stats 'suffix-length) 1))
        (define copied (core-pvector-copy pv 1 (sub1 (hash-ref stats 'length))))
        (define copied-stats (core-pvector-shape-stats copied))
        (check-core-list copied (take (drop xs 1) (- (length xs) 2)))
        (check-equal? (hash-ref copied-stats 'prefix-length)
                      (sub1 prefix-boundary))
        (check-equal? (hash-ref copied-stats 'suffix-length)
                      (sub1 (hash-ref stats 'suffix-length)))
        (check-equal? (hash-ref copied-stats 'middle-measure)
                      (hash-ref stats 'middle-measure))))
    (for ([range (in-list '((0 4096)
                            (0 5000)
                            (0 9996)
                            (4 10000)
                            (4096 10000)
                            (5000 10000)
                            (4 9996)
                            (4096 8192)))])
      (define start (first range))
      (define end (second range))
      (check-core-list (core-pvector-copy pv start end)
                       (take (drop xs start) (- end start))))
    (for ([idx (in-list '(0 1 2 4095 5000 5001 9998 9999))])
      (define-values (left value right) (core-pvector-split pv idx))
      (define-values (rest deleted) (core-pvector-delete pv idx))
      (check-core-list left (take xs idx))
      (check-equal? value (list-ref xs idx))
      (check-core-list right (drop xs (add1 idx)))
      (check-equal? deleted (list-ref xs idx))
      (check-core-list rest (append (take xs idx) (drop xs (add1 idx)))))
    (for ([pos (in-list '(0 1 4096 5000 5001 9999 10000))])
      (define inserted (core-pvector-insert pv pos 'joined-split-marker))
      (check-core-list inserted
                       (list-insert xs pos 'joined-split-marker))))
  (when (bc-vm?)
    (let* ([deep9 (core-list->pvector (range 9))]
           [copy4 (core-pvector-copy deep9 2 6)]
           [copy4-stats (core-pvector-shape-stats copy4)])
      (check-core-list copy4 '(2 3 4 5))
      (check-equal? (hash-ref copy4-stats 'representation #f) 'large-finger)
      (check-equal? (hash-ref copy4-stats 'prefix-length #f) 2)
      (check-equal? (hash-ref copy4-stats 'suffix-length #f) 2)
      (check-equal? (hash-ref copy4-stats 'middle-measure #f) 0))
    (let* ([large (core-list->pvector (range 8192))]
           [middle-only (core-pvector-copy large 4 8188)]
           [middle-stats (core-pvector-shape-stats middle-only)])
      (check-core-list middle-only (range 4 8188))
      (check-equal? (hash-ref middle-stats 'representation #f) 'large-finger)
      (check-true (positive? (hash-ref middle-stats 'finger-depth 0)))
      (check-equal? (hash-ref middle-stats 'middle-measure #f)
                    (- (hash-ref middle-stats 'length)
                       (hash-ref middle-stats 'prefix-length)
                       (hash-ref middle-stats 'suffix-length)))))
  (when (bc-vm?)
    (check-exn exn:fail:contract?
               (lambda () (core-pvector-copy '(not a pvector) 0 0)))
    (check-exn exn:fail?
               (lambda () (core-pvector-copy core-pvector-empty 1 0)))
    (check-exn exn:fail?
               (lambda () (core-pvector-take core-pvector-empty 1)))
    (check-exn exn:fail?
               (lambda () (core-pvector-split core-pvector-empty 0)))
    (check-exn exn:fail?
               (lambda () (core-pvector-delete core-pvector-empty 0)))
    (check-exn exn:fail?
               (lambda () (core-pvector-insert core-pvector-empty 1 'x)))))

(define (check-core-large-edge-stats stats prefix-len suffix-len middle-measure)
  (when (core-backend?)
    (with-check-info
      (['stats stats]
       ['expected-prefix prefix-len]
       ['expected-suffix suffix-len]
       ['expected-middle middle-measure])
      (check-equal? (hash-ref stats 'representation #f) 'large-finger)
      (check-true (<= 1 (hash-ref stats 'prefix-length 0) 4))
      (check-true (<= 1 (hash-ref stats 'suffix-length 0) 4))
      (check-equal? (hash-ref stats 'middle-measure #f)
                    (- (hash-ref stats 'length)
                       (hash-ref stats 'prefix-length)
                       (hash-ref stats 'suffix-length)))
      (check-core-large-finger-tree-stats stats))))

(define (check-chunk-vector-view pv)
  (check-equal? (chunk-vector->list (adapter:pvector->chunk-vector pv))
                (adapter:pvector->list pv)))

(define (check-shared-chunk-vector-view pv)
  (check-equal? (chunk-vector->list (adapter:pvector->chunk-vector/shared pv))
                (adapter:pvector->list pv)))

(define (check-chunk-vector-lengths pv expected-lengths)
  (check-chunk-vector-view pv)
  (void expected-lengths))

(define (check-chunk-vector-count pv expected-count)
  (check-chunk-vector-view pv)
  (void expected-count))

(test-case "backend probe"
  (define backend (adapter:pvector-runtime-adapter-backend))
  (check-not-false (memq backend '(core finger)))
  (check-equal? backend
                (if (adapter:pvector-runtime-adapter-core-available?)
                    'core
                    'finger))
  (when (memq backend '(core finger))
	  (define stats
	    (adapter:pvector-shape-stats
	     (adapter:list->pvector (range 130))))
    (define probe-pv (adapter:list->pvector (range 17)))
    (check-equal? (adapter:pvector-length/fast probe-pv)
                  (adapter:pvector-length probe-pv))
    (check-equal? (adapter:pvector-length/fast probe-pv) 17)
    (check-not-false
     (memq (hash-ref stats 'backend #f)
           (if (eq? backend 'core)
               '(core bc-native)
               '(finger))))
    (check-no-chunk-shape-stats stats))
  (when (eq? backend 'core)
    (check-true (kernel-procedure? 'core-fresh-vector->pvector))
    (check-true (kernel-procedure? 'core-make-single-pvector))
    (check-true (kernel-procedure? 'core-make-deep2-pvector))
    (check-true (kernel-procedure? 'core-make-deep3-pvector))
    (check-true (kernel-procedure? 'core-make-deep4-pvector))
    (check-true (kernel-procedure? 'core-pvector-cons-left))
    (check-true (kernel-procedure? 'core-pvector-cons-right))
    (when (bc-vm?)
      (check-true (kernel-procedure? 'core-unsafe-pvector-length))
      (check-true (kernel-procedure? 'core-unsafe-pvector-ref))
      (check-true (kernel-procedure? 'core-unsafe-pvector-view-left))
      (check-true (kernel-procedure? 'core-unsafe-pvector-view-right))
      (check-true (kernel-procedure? 'core-unsafe-pvector-first))
      (check-true (kernel-procedure? 'core-unsafe-pvector-last))
              (let* ([core-list->pvector (kernel-value 'core-list->pvector)]
                     [core-pvector? (kernel-value 'core-pvector?)]
                     [core-pvector-empty? (kernel-value 'core-pvector-empty?)]
                     [core-pvector-length (kernel-value 'core-pvector-length)]
                     [core-make-single-pvector
                      (kernel-value 'core-make-single-pvector)]
             [core-make-deep2-pvector
              (kernel-value 'core-make-deep2-pvector)]
             [core-make-deep3-pvector
              (kernel-value 'core-make-deep3-pvector)]
             [core-make-deep4-pvector
              (kernel-value 'core-make-deep4-pvector)]
             [core-unsafe-pvector-length
              (kernel-value 'core-unsafe-pvector-length)]
             [core-pvector-ref
             (kernel-value 'core-pvector-ref)]
             [core-unsafe-pvector-ref
              (kernel-value 'core-unsafe-pvector-ref)]
             [core-pvector-cons-left
              (kernel-value 'core-pvector-cons-left)]
             [core-pvector-cons-right
              (kernel-value 'core-pvector-cons-right)]
             [core-pvector-view-left
              (kernel-value 'core-pvector-view-left)]
             [core-pvector-view-right
              (kernel-value 'core-pvector-view-right)]
             [core-unsafe-pvector-view-left
              (kernel-value 'core-unsafe-pvector-view-left)]
             [core-unsafe-pvector-view-right
              (kernel-value 'core-unsafe-pvector-view-right)]
             [core-unsafe-pvector-first
              (kernel-value 'core-unsafe-pvector-first)]
             [core-unsafe-pvector-last
              (kernel-value 'core-unsafe-pvector-last)]
             [pv (core-list->pvector (range 17))])
        (check-equal? (core-unsafe-pvector-length pv) 17)
        (check-equal? (core-unsafe-pvector-view-left pv) 0)
        (check-equal? (core-unsafe-pvector-view-right pv) 16)
        (check-equal? (core-unsafe-pvector-first pv) 0)
        (check-equal? (core-unsafe-pvector-last pv) 16)
        (check-equal? (core-pvector-view-left pv) 0)
        (check-equal? (core-pvector-view-right pv) 16)
        (check-equal? (core-pvector-length pv) 17)
        (check-equal?
         (for/list ([i (in-range 17)])
           (core-unsafe-pvector-ref pv i))
         (range 17))
        (for ([jit-enabled? (in-list '(#f #t))])
          (parameterize ([eval-jit-enabled jit-enabled?])
            (check-true (core-pvector-empty? (core-pvector-empty)))
            (check-false (core-pvector-empty? pv))
            (check-false (core-pvector-empty? '(not a pvector)))
            (let* ([rounds 50]
                   [score
                    (lambda (value other rounds)
                       (let loop ([i 0] [acc 0])
                        (if (= i rounds)
                            acc
                            (let* ([empty0 (core-pvector-empty)]
                                   [empty1 (core-pvector-empty)]
                                   [single (core-make-single-pvector 23)]
                                   [deep2 (core-make-deep2-pvector 24 25)]
                                   [deep3 (core-make-deep3-pvector 26 27 28)]
                                   [deep4 (core-make-deep4-pvector 29 30 31 32)]
                                   [cons-left-empty
                                    (core-pvector-cons-left
                                     (core-pvector-empty) 40)]
                                   [cons-right-empty
                                    (core-pvector-cons-right
                                     (core-pvector-empty) 41)]
                                   [cons-left-single
                                    (core-pvector-cons-left single 22)]
                                   [cons-right-single
                                    (core-pvector-cons-right single 24)]
                                   [cons-left-deep3
                                    (core-pvector-cons-left deep3 25)]
                                   [cons-right-deep3
                                    (core-pvector-cons-right deep3 29)]
                                   [cons-left-full
                                    (core-pvector-cons-left
                                     (core-list->pvector (range 9))
                                     33)]
                                   [cons-right-full
                                    (core-pvector-cons-right
                                     (core-list->pvector (range 8))
                                     44)])
                              (check-true (eq? empty0 empty1))
                              (check-true (core-pvector-empty? empty0))
                              (check-no-chunk-shape-stats
                               (adapter:pvector-shape-stats single))
                              (check-no-chunk-shape-stats
                               (adapter:pvector-shape-stats deep2))
                              (check-no-chunk-shape-stats
                               (adapter:pvector-shape-stats deep3))
                              (check-no-chunk-shape-stats
                               (adapter:pvector-shape-stats deep4))
                              (check-equal? (core-pvector-length single) 1)
                              (check-equal? (core-pvector-length deep2) 2)
                              (check-equal? (core-pvector-length deep3) 3)
                              (check-equal? (core-pvector-length deep4) 4)
                              (check-equal? (core-pvector-ref single 0) 23)
                              (check-equal? (core-pvector-ref deep2 1) 25)
                              (check-equal? (core-pvector-ref deep3 2) 28)
                              (check-equal? (core-pvector-ref deep4 3) 32)
                              (check-equal? (core-pvector-view-left single) 23)
                              (check-equal? (core-pvector-view-right single) 23)
                              (check-equal? (core-pvector-view-left deep2) 24)
                              (check-equal? (core-pvector-view-right deep2) 25)
                              (check-equal? (core-pvector-view-left deep3) 26)
                              (check-equal? (core-pvector-view-right deep3) 28)
                              (check-equal? (core-pvector-view-left deep4) 29)
                              (check-equal? (core-pvector-view-right deep4) 32)
                              (check-equal? (core-unsafe-pvector-ref single 0) 23)
                              (check-equal? (core-unsafe-pvector-ref deep2 1) 25)
                              (check-equal? (core-unsafe-pvector-ref deep3 2) 28)
                              (check-equal? (core-unsafe-pvector-ref deep4 3) 32)
                              (check-equal?
                               (core-unsafe-pvector-view-left single)
                               23)
                              (check-equal?
                               (core-unsafe-pvector-view-right single)
                               23)
                              (check-equal?
                               (core-unsafe-pvector-view-left deep4)
                               29)
                              (check-equal?
                               (core-unsafe-pvector-view-right deep4)
                               32)
                              (check-equal? (core-pvector-ref cons-left-empty 0)
                                            40)
                              (check-equal? (core-pvector-ref cons-right-empty 0)
                                            41)
                              (check-equal? (core-pvector-length cons-left-single)
                                            2)
                              (check-equal? (core-pvector-view-left cons-left-single)
                                            22)
                              (check-equal? (core-pvector-view-right cons-left-single)
                                            23)
                              (check-equal? (core-pvector-length cons-right-single)
                                            2)
                              (check-equal? (core-pvector-view-left cons-right-single)
                                            23)
                              (check-equal? (core-pvector-view-right cons-right-single)
                                            24)
                              (check-equal? (core-pvector-length cons-left-deep3)
                                            4)
                              (check-equal? (core-pvector-view-left cons-left-deep3)
                                            25)
                              (check-equal? (core-pvector-view-right cons-left-deep3)
                                            28)
                              (check-equal? (core-pvector-length cons-right-deep3)
                                            4)
                              (check-equal? (core-pvector-view-left cons-right-deep3)
                                            26)
                              (check-equal? (core-pvector-view-right cons-right-deep3)
                                            29)
                              (check-equal?
                               (for/list ([j (in-range 10)])
                                 (core-pvector-ref cons-left-full j))
                               (cons 33 (range 9)))
                              (check-equal?
                               (for/list ([j (in-range 9)])
                                 (core-pvector-ref cons-right-full j))
                               (append (range 8) (list 44)))
                              (loop (add1 i)
                                    (+ acc
                                       (if (core-pvector? value) 1 0)
                                       (if (core-pvector? other) 100 0)
                                       (core-pvector-length value)
                                       (core-unsafe-pvector-length value)
                                       (core-unsafe-pvector-ref single 0)
                                       (core-unsafe-pvector-length deep2)
                                       (core-unsafe-pvector-ref deep2 0)
                                       (core-unsafe-pvector-ref deep2 1)
                                       (core-unsafe-pvector-length deep3)
                                       (core-unsafe-pvector-ref deep3 0)
                                       (core-unsafe-pvector-ref deep3 1)
                                       (core-unsafe-pvector-ref deep3 2)
                                       (core-unsafe-pvector-length deep4)
                                       (core-unsafe-pvector-ref deep4 0)
                                       (core-unsafe-pvector-ref deep4 1)
                                       (core-unsafe-pvector-ref deep4 2)
                                       (core-unsafe-pvector-ref deep4 3)
                                       (core-unsafe-pvector-ref value 0)
                                       (core-unsafe-pvector-ref value 8)
                                       (core-unsafe-pvector-ref value 16)
                                       (core-unsafe-pvector-ref value (modulo i 17))
                                       (core-pvector-ref value 0)
                                       (core-pvector-ref value 8)
                                       (core-pvector-ref value 16)
                                       (core-pvector-ref value (modulo i 17))
                                       (core-pvector-view-left value)
                                       (core-pvector-view-right value)
                                       (core-unsafe-pvector-view-left value)
                                       (core-unsafe-pvector-view-right value)))))))])
              (check-equal? (score pv '(not a pvector) rounds)
                            (+ (* rounds (+ 1 17 17 23
                                             2 24 25
                                             3 26 27 28
                                             4 29 30 31 32
                                             0 8 16
                                             0 8 16
                                             0 16
                                             0 16))
                               (* 2
                                  (for/sum ([i (in-range rounds)])
	                                    (modulo i 17)))))
	              (when jit-enabled?
                (check-equal? (static-kernel-pvector-jit-score #f)
                              18040)
                (check-equal? (static-kernel-pvector-jit-score #t)
                              18040))
	              (check-exn exn:fail:contract?
	                         (lambda () (core-pvector-ref '(not a pvector) 0)))
              (check-exn exn:fail:contract?
                         (lambda () (core-pvector-ref pv -1)))
              (check-exn exn:fail:contract?
                         (lambda () (core-pvector-ref pv 17)))
              (check-exn exn:fail:contract?
                         (lambda ()
                           (core-pvector-view-left '(not a pvector))))
              (check-exn exn:fail:contract?
                         (lambda ()
                           (core-pvector-view-right '(not a pvector))))
              (check-exn exn:fail?
                         (lambda ()
                           (core-pvector-view-left (core-pvector-empty))))
              (check-exn exn:fail?
                         (lambda ()
                           (core-pvector-view-right (core-pvector-empty))))
              (check-exn exn:fail:contract?
                         (lambda ()
                           (core-pvector-cons-left '(not a pvector) 'x)))
              (check-exn exn:fail:contract?
                         (lambda ()
                           (core-pvector-cons-right '(not a pvector) 'x))))))))
  (check-exn exn:fail:contract?
             (lambda ()
               (adapter:pvector-shape-stats '(not a pvector))))
  (if (and core-backend?
           (or (bc-vm?)
               (adapter:pvector-runtime-adapter-public-properties-available?)))
      (check-no-chunk-shape-stats
       (adapter:pvector-shape-stats (public:pvector 1 2 3)))
      (check-exn exn:fail:contract?
                 (lambda ()
                   (adapter:pvector-shape-stats (public:pvector 1 2 3)))))))

(test-case "adapter operations"
  (define xs (range 130))
  (define pv (adapter:list->pvector xs))
  (check-model (adapter:pvector 1 2 3) '(1 2 3))
  (check-model (adapter:pvector 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16)
               (range 17))
  (check-model (apply adapter:pvector (range 32))
               (range 32))
  (check-model (apply adapter:pvector (range 33))
               (range 33))
  (check-model (apply adapter:pvector (range 64))
               (range 64))
  (check-model (apply adapter:pvector (range 65))
               (range 65))
  (check-model (apply adapter:pvector (range 96))
               (range 96))
  (check-model (apply adapter:pvector (range 112))
               (range 112))
  (check-model (apply adapter:pvector (range 128))
               (range 128))
  (when (core-backend?)
    (let* ([core-list->pvector
            (dynamic-require ''#%kernel 'core-list->pvector)]
           [single1 (adapter:list->pvector (range 1))]
           [single1-stats (adapter:pvector-shape-stats single1)]
           [deep2 (adapter:list->pvector (range 2))]
           [deep2-stats (adapter:pvector-shape-stats deep2)]
           [deep3 (adapter:list->pvector (range 3))]
           [deep3-stats (adapter:pvector-shape-stats deep3)]
           [deep4 (adapter:list->pvector (range 4))]
           [deep4-stats (adapter:pvector-shape-stats deep4)]
           [direct3 (adapter:three-values->pvector 0 1 2)]
           [direct3-stats (adapter:pvector-shape-stats direct3)]
           [direct4 (adapter:four-values->pvector 0 1 2 3)]
           [direct4-stats (adapter:pvector-shape-stats direct4)]
           [mapped3 (adapter:pvector-map direct3 add1)]
           [mapped3-stats (adapter:pvector-shape-stats mapped3)]
           [mapped4 (adapter:pvector-map direct4 add1)]
           [mapped4-stats (adapter:pvector-shape-stats mapped4)]
           [fixed-arity3 (adapter:pvector 0 1 2)]
           [fixed-arity3-stats (adapter:pvector-shape-stats fixed-arity3)]
           [fixed-arity4 (adapter:pvector 0 1 2 3)]
           [fixed-arity4-stats (adapter:pvector-shape-stats fixed-arity4)]
           [vector3 (adapter:vector->pvector (vector 0 1 2))]
           [vector3-stats (adapter:pvector-shape-stats vector3)]
           [vector4 (adapter:vector->pvector (vector 0 1 2 3))]
           [vector4-stats (adapter:pvector-shape-stats vector4)]
           [range3 (adapter:sequence->pvector 3)]
           [range3-stats (adapter:pvector-shape-stats range3)]
           [range4 (adapter:sequence->pvector 4)]
           [range4-stats (adapter:pvector-shape-stats range4)]
           [arith4 (adapter:sequence->pvector (in-range 1 5))]
           [arith4-stats (adapter:pvector-shape-stats arith4)]
           [step4 (adapter:sequence->pvector (in-range 0 8 2))]
           [step4-stats (adapter:pvector-shape-stats step4)]
           [core-list2 (core-list->pvector (range 2))]
           [core-list2-stats (adapter:pvector-shape-stats core-list2)]
           [core-list3 (core-list->pvector (range 3))]
           [core-list3-stats (adapter:pvector-shape-stats core-list3)]
           [core-list4 (core-list->pvector (range 4))]
           [core-list4-stats (adapter:pvector-shape-stats core-list4)]
           [deep9 (adapter:list->pvector (range 9))]
           [deep9-stats (adapter:pvector-shape-stats deep9)]
           [deep9-copy1 (adapter:pvector-copy deep9 4 5)]
           [deep9-copy1-stats (adapter:pvector-shape-stats deep9-copy1)]
           [deep9-copy2 (adapter:pvector-copy deep9 4 6)]
           [deep9-copy2-stats (adapter:pvector-shape-stats deep9-copy2)]
           [deep9-copy3 (adapter:pvector-copy deep9 3 6)]
           [deep9-copy3-stats (adapter:pvector-shape-stats deep9-copy3)]
           [deep9-copy4 (adapter:pvector-copy deep9 2 6)]
           [deep9-copy4-stats (adapter:pvector-shape-stats deep9-copy4)]
           [deep9-left1 (adapter:pvector-copy deep9 0 1)]
           [deep9-left1-stats (adapter:pvector-shape-stats deep9-left1)]
           [deep9-right1 (adapter:pvector-copy deep9 8 9)]
           [deep9-right1-stats (adapter:pvector-shape-stats deep9-right1)]
           [deep9-left2 (adapter:pvector-copy deep9 0 2)]
           [deep9-left2-stats (adapter:pvector-shape-stats deep9-left2)]
           [deep9-right2 (adapter:pvector-copy deep9 7 9)]
           [deep9-right2-stats (adapter:pvector-shape-stats deep9-right2)]
           [appended64
            (adapter:pvector-append
             (adapter:list->pvector (range 64))
             (adapter:list->pvector (range 64 128)))]
           [appended64-stats (adapter:pvector-shape-stats appended64)]
           [appended256
            (adapter:pvector-append
             (adapter:list->pvector (range 256))
             (adapter:list->pvector (range 256 512)))]
           [appended256-stats (adapter:pvector-shape-stats appended256)])
      (check-model single1 (range 1))
      (check-model deep2 (range 2))
      (check-model deep3 (range 3))
      (check-model deep4 (range 4))
      (check-model direct3 (range 3))
      (check-model direct4 (range 4))
      (check-model mapped3 '(1 2 3))
      (check-model mapped4 '(1 2 3 4))
      (check-model fixed-arity3 (range 3))
      (check-model fixed-arity4 (range 4))
      (check-model vector3 (range 3))
      (check-model vector4 (range 4))
      (check-model range3 (range 3))
      (check-model range4 (range 4))
      (check-model arith4 '(1 2 3 4))
      (check-model step4 '(0 2 4 6))
      (check-model core-list2 (range 2))
      (check-model core-list3 (range 3))
      (check-model core-list4 (range 4))
      (check-model deep9 (range 9))
      (check-model deep9-copy1 '(4))
      (check-model deep9-copy2 '(4 5))
      (check-model deep9-copy3 '(3 4 5))
      (check-model deep9-copy4 '(2 3 4 5))
      (check-model deep9-left1 '(0))
      (check-model deep9-right1 '(8))
      (check-model deep9-left2 '(0 1))
      (check-model deep9-right2 '(7 8))
      (check-model appended64 (range 128))
      (check-model appended256 (range 512))
      (check-equal? (hash-ref single1-stats 'representation #f) 'single)
      (check-equal? (hash-ref deep9-copy1-stats 'representation #f) 'single)
      (check-equal? (hash-ref deep9-left1-stats 'representation #f) 'single)
      (check-equal? (hash-ref deep9-right1-stats 'representation #f) 'single)
      (check-core-large-edge-stats deep2-stats 1 1 0)
      (check-core-large-edge-stats deep3-stats 1 2 0)
      (check-core-large-edge-stats deep4-stats 2 2 0)
      (check-core-large-edge-stats direct3-stats 1 2 0)
      (check-core-large-edge-stats direct4-stats 2 2 0)
      (check-core-large-edge-stats mapped3-stats 1 2 0)
      (check-core-large-edge-stats mapped4-stats 2 2 0)
      (check-core-large-edge-stats fixed-arity3-stats 1 2 0)
      (check-core-large-edge-stats fixed-arity4-stats 2 2 0)
      (check-core-large-edge-stats vector3-stats 1 2 0)
      (check-core-large-edge-stats vector4-stats 2 2 0)
      (check-core-large-edge-stats range3-stats 1 2 0)
      (check-core-large-edge-stats range4-stats 2 2 0)
      (check-core-large-edge-stats arith4-stats 2 2 0)
      (check-core-large-edge-stats step4-stats 2 2 0)
      (check-core-large-edge-stats core-list2-stats 1 1 0)
      (check-core-large-edge-stats core-list3-stats 1 2 0)
      (check-core-large-edge-stats core-list4-stats 2 2 0)
      (check-core-large-edge-stats deep9-copy2-stats 1 1 0)
      (check-core-large-edge-stats deep9-copy3-stats 1 2 0)
      (check-core-large-edge-stats deep9-copy4-stats 2 2 0)
      (check-core-large-edge-stats deep9-left2-stats 1 1 0)
      (check-core-large-edge-stats deep9-right2-stats 1 1 0)
      (check-core-large-edge-stats deep9-stats 4 3 2)
      (check-core-large-edge-stats appended64-stats 4 4 120)
      (check-core-large-edge-stats appended256-stats 4 4 504)
      (check-no-chunk-shape-stats single1-stats)
      (check-no-chunk-shape-stats deep2-stats)
      (check-no-chunk-shape-stats deep3-stats)
      (check-no-chunk-shape-stats deep4-stats)
      (check-no-chunk-shape-stats direct3-stats)
      (check-no-chunk-shape-stats direct4-stats)
      (check-no-chunk-shape-stats mapped3-stats)
      (check-no-chunk-shape-stats mapped4-stats)
      (check-no-chunk-shape-stats fixed-arity3-stats)
      (check-no-chunk-shape-stats fixed-arity4-stats)
      (check-no-chunk-shape-stats vector3-stats)
      (check-no-chunk-shape-stats vector4-stats)
      (check-no-chunk-shape-stats range3-stats)
      (check-no-chunk-shape-stats range4-stats)
      (check-no-chunk-shape-stats arith4-stats)
      (check-no-chunk-shape-stats step4-stats)
      (check-no-chunk-shape-stats core-list3-stats)
      (check-no-chunk-shape-stats core-list4-stats)
      (check-no-chunk-shape-stats deep9-stats)
      (check-no-chunk-shape-stats deep9-copy1-stats)
      (check-no-chunk-shape-stats deep9-copy2-stats)
      (check-no-chunk-shape-stats deep9-copy3-stats)
      (check-no-chunk-shape-stats deep9-copy4-stats)
      (check-no-chunk-shape-stats deep9-left1-stats)
      (check-no-chunk-shape-stats deep9-right1-stats)
      (check-no-chunk-shape-stats deep9-left2-stats)
      (check-no-chunk-shape-stats deep9-right2-stats)
      (check-no-chunk-shape-stats appended64-stats)
      (check-no-chunk-shape-stats appended256-stats)
      (for* ([left-case (in-list '((1 . 2) (2 . 4) (3 . 6) (4 . 8)))]
             [right-case (in-list '((1 . 2) (2 . 4) (3 . 6) (4 . 8)))])
        (define left-suffix-len (car left-case))
        (define left-size (cdr left-case))
        (define right-prefix-len (car right-case))
        (define right-size (cdr right-case))
        (define left-xs (range left-size))
        (define right-xs (range 100 (+ 100 right-size)))
        (define bridge-append
          (adapter:pvector-append
           (adapter:list->pvector left-xs)
           (adapter:list->pvector right-xs)))
        (define bridge-stats (adapter:pvector-shape-stats bridge-append))
        (with-check-info
          (['left-suffix-length left-suffix-len]
           ['right-prefix-length right-prefix-len]
           ['bridge-length (+ left-suffix-len right-prefix-len)]
           ['stats bridge-stats])
          (check-model bridge-append (append left-xs right-xs))
          (check-no-chunk-shape-stats bridge-stats)))
      (let-values ([(left value right) (adapter:pvector-split deep9 0)])
        (define right-stats (adapter:pvector-shape-stats right))
        (check-true (adapter:pvector-empty? left))
        (check-equal? value 0)
        (check-model right (range 1 9))
        (check-core-large-edge-stats right-stats 3 3 2)
        (check-no-chunk-shape-stats right-stats))
      (let-values ([(left value right) (adapter:pvector-split deep9 8)])
        (define left-stats (adapter:pvector-shape-stats left))
        (check-model left (range 8))
        (check-equal? value 8)
        (check-true (adapter:pvector-empty? right))
        (check-core-large-edge-stats left-stats 4 2 2)
        (check-no-chunk-shape-stats left-stats))
      (let-values ([(left right) (adapter:pvector-split-at deep9 0)])
        (check-true (adapter:pvector-empty? left))
        (check-true (eq? right deep9)))
      (let-values ([(left right) (adapter:pvector-split-at deep9 9)])
        (check-true (eq? left deep9))
        (check-true (adapter:pvector-empty? right)))
      (let-values ([(right left) (adapter:pvector-split-at-right deep9 0)])
        (check-true (adapter:pvector-empty? right))
        (check-true (eq? left deep9)))
      (let-values ([(right left) (adapter:pvector-split-at-right deep9 9)])
        (check-true (eq? right deep9))
        (check-true (adapter:pvector-empty? left)))
      (check-true (adapter:pvector-empty? (adapter:pvector-take deep9 0)))
      (check-true (eq? deep9 (adapter:pvector-take deep9 9)))
      (check-true (eq? deep9 (adapter:pvector-drop deep9 0)))
      (check-true (adapter:pvector-empty? (adapter:pvector-drop deep9 9)))
      (check-true (adapter:pvector-empty? (adapter:pvector-take-right deep9 0)))
      (check-true (eq? deep9 (adapter:pvector-take-right deep9 9)))
      (check-true (eq? deep9 (adapter:pvector-drop-right deep9 0)))
      (check-true (adapter:pvector-empty? (adapter:pvector-drop-right deep9 9)))
      (let ([rest (adapter:pvector-copy deep9 1 9)])
        (define rest-stats (adapter:pvector-shape-stats rest))
        (check-model rest (range 1 9))
        (check-core-large-edge-stats rest-stats 3 3 2)
        (check-no-chunk-shape-stats rest-stats))
      (let ([rest (adapter:pvector-copy deep9 0 8)])
        (define rest-stats (adapter:pvector-shape-stats rest))
        (check-model rest (range 8))
        (check-core-large-edge-stats rest-stats 4 2 2)
        (check-no-chunk-shape-stats rest-stats))
      (let ([rest (adapter:pvector-drop deep9 1)])
        (define rest-stats (adapter:pvector-shape-stats rest))
        (check-model rest (range 1 9))
        (check-core-large-edge-stats rest-stats 3 3 2)
        (check-no-chunk-shape-stats rest-stats))
      (let ([rest (adapter:pvector-take-right deep9 8)])
        (define rest-stats (adapter:pvector-shape-stats rest))
        (check-model rest (range 1 9))
        (check-core-large-edge-stats rest-stats 3 3 2)
        (check-no-chunk-shape-stats rest-stats))
      (let ([rest (adapter:pvector-take deep9 8)])
        (define rest-stats (adapter:pvector-shape-stats rest))
        (check-model rest (range 8))
        (check-core-large-edge-stats rest-stats 4 2 2)
        (check-no-chunk-shape-stats rest-stats))
      (let ([rest (adapter:pvector-drop-right deep9 1)])
        (define rest-stats (adapter:pvector-shape-stats rest))
        (check-model rest (range 8))
        (check-core-large-edge-stats rest-stats 4 2 2)
        (check-no-chunk-shape-stats rest-stats))
      (let-values ([(value rest) (adapter:pvector-pop-left deep9)])
        (define rest-stats (adapter:pvector-shape-stats rest))
        (check-equal? value 0)
        (check-model rest (range 1 9))
        (check-core-large-edge-stats rest-stats 3 3 2)
        (check-no-chunk-shape-stats rest-stats))
      (let-values ([(value rest) (adapter:pvector-pop-right deep9)])
        (define rest-stats (adapter:pvector-shape-stats rest))
        (check-equal? value 8)
        (check-model rest (range 8))
        (check-core-large-edge-stats rest-stats 4 2 2)
        (check-no-chunk-shape-stats rest-stats))
      (let-values ([(rest value) (adapter:pvector-delete deep9 0)])
        (define rest-stats (adapter:pvector-shape-stats rest))
        (check-equal? value 0)
        (check-model rest (range 1 9))
        (check-core-large-edge-stats rest-stats 3 3 2)
        (check-no-chunk-shape-stats rest-stats))
      (let-values ([(rest value) (adapter:pvector-delete deep9 8)])
        (define rest-stats (adapter:pvector-shape-stats rest))
        (check-equal? value 8)
        (check-model rest (range 8))
        (check-core-large-edge-stats rest-stats 4 2 2)
        (check-no-chunk-shape-stats rest-stats))))
  (check-model (adapter:list->pvector (range 32))
               (range 32))
  (check-model (adapter:list->pvector (range 33))
               (range 33))
  (let* ([elem (box 'uniform-list)]
         [uniform-list (make-list 130 elem)]
         [pv (adapter:list->pvector uniform-list)])
    (check-model pv uniform-list)
    (check-eq? (vector-ref (adapter:pvector->vector pv) 64) elem)
    (check-eq? (list-ref (adapter:pvector->list pv) 129) elem))
  (let* ([elem (box 'mixed-list)]
         [mixed-list (cons elem (cons 'other (make-list 128 elem)))]
         [pv (adapter:list->pvector mixed-list)])
    (check-model pv mixed-list)
    (check-eq? (vector-ref (adapter:pvector->vector pv) 0) elem)
    (check-equal? (vector-ref (adapter:pvector->vector pv) 1) 'other)
    (check-eq? (list-ref (adapter:pvector->list pv) 129) elem))
  (define small-conversion (adapter:pvector 1 2 3 4 5))
  (define small-conversion-vector (adapter:pvector->vector small-conversion))
  (vector-set! small-conversion-vector 0 'changed)
  (check-equal? (vector->list small-conversion-vector) '(changed 2 3 4 5))
  (check-model small-conversion '(1 2 3 4 5))
  (check-model pv xs)
  (check-model (adapter:vector->pvector (list->vector xs)) xs)
  (define immutable-vector-pv
    (adapter:vector->pvector
     (vector->immutable-vector (list->vector xs))))
  (check-model immutable-vector-pv xs)
  (check-equal? (chunk-vector->list
                 (adapter:pvector->chunk-vector/shared immutable-vector-pv))
                xs)
  (check-equal? (for/list ([x (adapter:in-pvector immutable-vector-pv)]) x)
                xs)
  (check-equal? (for/list ([x (adapter:in-pvector-reverse immutable-vector-pv)]) x)
                (reverse xs))
  (check-model (adapter:pvector-map immutable-vector-pv add1)
               (map add1 xs))
  (let ([seen null])
    (adapter:pvector-for-each immutable-vector-pv
                              (lambda (x) (set! seen (cons x seen))))
    (check-equal? (reverse seen) xs))
  (let* ([src (vector 'a 'b 'c)]
         [pv (adapter:vector->pvector src)])
    (vector-set! src 0 'changed)
    (check-model pv '(a b c)))
  (let* ([elem (box 'uniform-vector)]
         [src (make-vector 130 elem)]
         [pv (adapter:vector->pvector src)])
    (vector-set! src 64 'changed)
    (check-model pv (make-list 130 elem))
    (check-eq? (vector-ref (adapter:pvector->vector pv) 64) elem)
    (check-eq? (list-ref (adapter:pvector->list pv) 129) elem)
    (when (core-backend?)
      (check-shared-chunk-vector-view pv)))
  (check-model (adapter:sequence->pvector (in-range 130)) xs)
  (check-model (adapter:sequence->pvector (in-range 0 130 1)) xs)
  (check-model (adapter:sequence->pvector (in-range 1 5)) '(1 2 3 4))
  (check-model (adapter:sequence->pvector (in-range 0 8 2)) '(0 2 4 6))
  (check-model (adapter:sequence->pvector 130) xs)
  (check-true (eq? (adapter:list->pvector null)
                   (adapter:pvector-empty)))
  (check-true (eq? (adapter:vector->pvector #())
                   (adapter:pvector-empty)))
  (check-true (eq? (adapter:sequence->pvector 0)
                   (adapter:pvector-empty)))
  (let* ([list1 (adapter:list->pvector '(1))]
         [direct1 (adapter:single-value->pvector 'direct)]
         [direct2 (adapter:two-values->pvector 'left 'right)]
         [direct3 (adapter:three-values->pvector 'a 'b 'c)]
         [direct4 (adapter:four-values->pvector 'a 'b 'c 'd)]
         [small-vec1
          (adapter:small-immutable-vector->pvector
           (vector-immutable 'vector-direct)
           1)]
         [small-vec2
          (adapter:small-immutable-vector->pvector
           (vector-immutable 'vector-left 'vector-right 'ignored)
           2)]
         [small-vec3
          (adapter:small-immutable-vector->pvector
           (vector-immutable 'vector-a 'vector-b 'vector-c 'ignored)
           3)]
         [small-vec4
          (adapter:small-immutable-vector->pvector
           (vector-immutable 'vector-a 'vector-b 'vector-c 'vector-d 'ignored)
           4)]
         [make1 (adapter:make-pvector 1 'x)]
         [make2 (adapter:make-pvector 2 'x)]
         [cons-left-empty
          (adapter:pvector-cons-left (adapter:pvector-empty) 'x)]
         [cons-right-empty
          (adapter:pvector-cons-right (adapter:pvector-empty) 'x)]
         [cons-left-single (adapter:pvector-cons-left (adapter:pvector 2) 1)]
         [cons-right-single (adapter:pvector-cons-right (adapter:pvector 1) 2)]
         [append-single
          (adapter:pvector-append (adapter:pvector 1) (adapter:pvector 2))]
         [map2 (adapter:pvector-map append-single add1)]
         [set-single (adapter:pvector-set (adapter:pvector 1) 0 2)]
         [set-deep2-left (adapter:pvector-set append-single 0 'left)]
         [set-deep2-right (adapter:pvector-set append-single 1 'right)])
    (check-model list1 '(1))
    (check-model direct1 '(direct))
    (check-model direct2 '(left right))
    (check-model direct3 '(a b c))
    (check-model direct4 '(a b c d))
    (check-model small-vec1 '(vector-direct))
    (check-model small-vec2 '(vector-left vector-right))
    (check-model small-vec3 '(vector-a vector-b vector-c))
    (check-model small-vec4 '(vector-a vector-b vector-c vector-d))
    (check-model make1 '(x))
    (check-model make2 '(x x))
    (check-model cons-left-empty '(x))
    (check-model cons-right-empty '(x))
    (check-model cons-left-single '(1 2))
    (check-model cons-right-single '(1 2))
    (check-model append-single '(1 2))
    (check-model map2 '(2 3))
    (check-model set-single '(2))
    (check-model set-deep2-left '(left 2))
    (check-model set-deep2-right '(1 right))
    (check-true (eq? append-single (adapter:pvector-set append-single 0 1)))
    (check-true (eq? append-single (adapter:pvector-set append-single 1 2)))
    (let ([seen null])
      (check-equal? (adapter:pvector-for-each
                     append-single
                     (lambda (v)
                       (set! seen (append seen (list v)))
                       (values v 'ignored)))
                    (void))
      (check-equal? seen '(1 2)))
    (let ([vec (adapter:pvector->vector direct2)])
      (check-equal? (vector->list vec) '(left right))
      (vector-set! vec 0 'changed)
      (check-model direct2 '(left right)))
    (check-equal? (adapter:pvector->list direct2) '(left right))
    (let ([vec (adapter:pvector->vector direct3)])
      (check-equal? (vector->list vec) '(a b c))
      (vector-set! vec 1 'changed)
      (check-model direct3 '(a b c)))
    (check-equal? (adapter:pvector->list direct3) '(a b c))
    (let ([vec (adapter:pvector->vector direct4)])
      (check-equal? (vector->list vec) '(a b c d))
      (vector-set! vec 2 'changed)
      (check-model direct4 '(a b c d)))
    (check-equal? (adapter:pvector->list direct4) '(a b c d))
    (let-values ([(value rest) (adapter:pvector-pop-left append-single)])
      (check-equal? value 1)
      (check-model rest '(2))
      (when (core-backend?)
        (check-equal? (hash-ref (adapter:pvector-shape-stats rest)
                                'representation
                                #f)
                      'single)))
    (let-values ([(value rest) (adapter:pvector-pop-right append-single)])
      (check-equal? value 2)
      (check-model rest '(1))
      (when (core-backend?)
        (check-equal? (hash-ref (adapter:pvector-shape-stats rest)
                                'representation
                                #f)
                      'single)))
    (let-values ([(rest value) (adapter:pvector-delete append-single 0)])
      (check-equal? value 1)
      (check-model rest '(2))
      (when (core-backend?)
        (check-equal? (hash-ref (adapter:pvector-shape-stats rest)
                                'representation
                                #f)
                      'single)))
    (let-values ([(rest value) (adapter:pvector-delete append-single 1)])
      (check-equal? value 2)
      (check-model rest '(1))
      (when (core-backend?)
        (check-equal? (hash-ref (adapter:pvector-shape-stats rest)
                                'representation
                                #f)
                      'single)))
    (let-values ([(value rest) (adapter:pvector-pop-left list1)])
      (check-equal? value 1)
      (check-true (adapter:pvector-empty? rest)))
    (let-values ([(value rest) (adapter:pvector-pop-right list1)])
      (check-equal? value 1)
      (check-true (adapter:pvector-empty? rest)))
    (when (core-backend?)
      (for ([pv (in-list (list list1
                                direct1
                                small-vec1
                                make1
                                cons-left-empty
                                cons-right-empty
                                set-single))])
        (check-equal? (hash-ref (adapter:pvector-shape-stats pv)
                                'representation
                                #f)
                      'single))
      (for ([pv (in-list (list direct2
                                small-vec2
                                make2
                                cons-left-single
                                cons-right-single
                                append-single
                                map2
                                set-deep2-left
                                set-deep2-right))])
        (check-core-large-edge-stats
         (adapter:pvector-shape-stats pv)
         1
         1
         0))))
  (let ([made5 (adapter:make-pvector 5 'x)])
    (check-model made5 '(x x x x x))
    (when (core-backend?)
      (define made5-stats (adapter:pvector-shape-stats made5))
      (check-core-large-edge-stats made5-stats 2 3 0)
      (check-no-chunk-shape-stats made5-stats)))
  (check-model (adapter:make-pvector 32 'x)
               '(x x x x x x x x x x x x x x x x
                 x x x x x x x x x x x x x x x x))
  (check-model (adapter:make-pvector 64 'x)
               (make-list 64 'x))
  (check-model (adapter:make-pvector 65 'x)
               (make-list 65 'x))
  (let* ([elem (box 'x)]
         [made (adapter:make-pvector 130 elem)]
         [made* (adapter:pvector-set made 64 'changed)]
         [made-mid (adapter:pvector-copy made 1 129)]
         [made*-mid (adapter:pvector-copy made* 1 129)]
         [made-prefix (adapter:pvector-take made 100)]
         [made-suffix (adapter:pvector-drop made 30)]
         [made*-prefix (adapter:pvector-take made* 100)]
         [made*-suffix (adapter:pvector-drop made* 30)]
         [made-append (adapter:pvector-append made made)]
         [made*-append (adapter:pvector-append made* made)]
         [made-diff-append (adapter:pvector-append
                            made
                            (adapter:make-pvector 130 'other))]
         [made-cons-left (adapter:pvector-cons-left made elem)]
         [made-cons-right (adapter:pvector-cons-right made elem)]
         [made-cons-diff (adapter:pvector-cons-left made 'other)]
         [made-insert-same (adapter:pvector-insert made 65 elem)]
         [made-insert-diff (adapter:pvector-insert made 65 'other)])
    (check-model made (make-list 130 elem))
    (check-eq? (adapter:pvector-ref made 0) elem)
    (check-eq? (adapter:pvector-ref made 64) elem)
    (check-eq? (adapter:pvector-ref made 129) elem)
    (check-eq? (adapter:pvector-ref made* 0) elem)
    (check-equal? (adapter:pvector-ref made* 64) 'changed)
    (check-eq? (adapter:pvector-ref made* 129) elem)
    (check-eq? (vector-ref (adapter:pvector->vector made) 64) elem)
    (check-eq? (vector-ref (adapter:pvector->vector made*) 0) elem)
    (check-equal? (vector-ref (adapter:pvector->vector made*) 64) 'changed)
    (check-eq? (vector-ref (adapter:pvector->vector made*) 129) elem)
    (check-eq? (list-ref (adapter:pvector->list made) 64) elem)
    (check-eq? (list-ref (adapter:pvector->list made*) 0) elem)
    (check-equal? (list-ref (adapter:pvector->list made*) 64) 'changed)
    (check-eq? (list-ref (adapter:pvector->list made*) 129) elem)
    (check-eq? (vector-ref (adapter:pvector->vector made-mid) 63) elem)
    (check-eq? (list-ref (adapter:pvector->list made-mid) 63) elem)
    (check-eq? (vector-ref (adapter:pvector->vector made*-mid) 0) elem)
    (check-equal? (vector-ref (adapter:pvector->vector made*-mid) 63) 'changed)
    (check-eq? (list-ref (adapter:pvector->list made*-mid) 127) elem)
    (check-eq? (vector-ref (adapter:pvector->vector made-prefix) 99) elem)
    (check-eq? (list-ref (adapter:pvector->list made-suffix) 0) elem)
    (check-eq? (vector-ref (adapter:pvector->vector made-suffix) 99) elem)
    (check-equal? (vector-ref (adapter:pvector->vector made*-prefix) 64) 'changed)
    (check-equal? (list-ref (adapter:pvector->list made*-suffix) 34) 'changed)
    (check-eq? (vector-ref (adapter:pvector->vector made-append) 129) elem)
    (check-eq? (vector-ref (adapter:pvector->vector made-append) 130) elem)
    (check-eq? (list-ref (adapter:pvector->list made-append) 259) elem)
    (check-equal? (vector-ref (adapter:pvector->vector made*-append) 64) 'changed)
    (check-eq? (list-ref (adapter:pvector->list made*-append) 130) elem)
    (check-eq? (vector-ref (adapter:pvector->vector made-diff-append) 129) elem)
    (check-equal? (list-ref (adapter:pvector->list made-diff-append) 130) 'other)
    (check-eq? (vector-ref (adapter:pvector->vector made-cons-left) 0) elem)
    (check-eq? (vector-ref (adapter:pvector->vector made-cons-left) 130) elem)
    (check-eq? (vector-ref (adapter:pvector->vector made-cons-right) 130) elem)
    (check-equal? (vector-ref (adapter:pvector->vector made-cons-diff) 0) 'other)
    (check-eq? (list-ref (adapter:pvector->list made-cons-diff) 1) elem)
    (check-eq? (vector-ref (adapter:pvector->vector made-insert-same) 65) elem)
    (check-eq? (vector-ref (adapter:pvector->vector made-insert-same) 130) elem)
    (check-eq? (list-ref (adapter:pvector->list made-insert-same) 66) elem)
    (check-equal? (vector-ref (adapter:pvector->vector made-insert-diff) 65) 'other)
    (check-eq? (vector-ref (adapter:pvector->vector made-insert-diff) 66) elem)
    (when (core-backend?)
      (let* ([left (adapter:list->pvector (range 128))]
             [right (adapter:list->pvector (range 128 192))]
             [appended (adapter:pvector-append left right)]
             [stats (adapter:pvector-shape-stats appended)])
        (check-model appended (range 192))
        (check-no-chunk-shape-stats stats))
      (let* ([left (adapter:list->pvector (range 130))]
             [right (adapter:list->pvector (range 130 192))]
             [appended (adapter:pvector-append left right)]
             [stats (adapter:pvector-shape-stats appended)])
        (check-model appended (range 192))
        (check-equal? (adapter:pvector-ref appended 129) 129)
        (check-equal? (adapter:pvector-ref appended 130) 130)
        (check-no-chunk-shape-stats stats))
      (let* ([left (adapter:list->pvector (range 5000))]
             [right (adapter:list->pvector (range 5000 10000))]
             [appended (adapter:pvector-append left right)]
             [stats (adapter:pvector-shape-stats appended)])
        (check-model appended (range 10000))
        (check-equal? (adapter:pvector-ref appended 4999) 4999)
        (check-equal? (adapter:pvector-ref appended 5000) 5000)
        (check-model (adapter:pvector-copy appended 4996 5004)
                     (range 4996 5004))
        (check-model (adapter:pvector-set appended 5000 'x)
                     (append (range 5000) '(x) (range 5001 10000)))
        (let-values ([(split-left split-right)
                      (adapter:pvector-split-at appended 5000)])
          (check-model split-left (range 5000))
          (check-model split-right (range 5000 10000)))
        (check-core-large-edge-stats stats 4 4 9992)
        (check-no-chunk-shape-stats stats))
      (let* ([base (adapter:list->pvector (range 10000))]
             [left (adapter:pvector-take base 5000)]
             [right (adapter:pvector-drop base 5000)]
             [appended (adapter:pvector-append left right)]
             [stats (adapter:pvector-shape-stats appended)])
        (check-model appended (range 10000))
        (check-equal? (adapter:pvector-ref appended 4999) 4999)
        (check-equal? (adapter:pvector-ref appended 5000) 5000)
        (check-model (adapter:pvector-copy appended 4996 5004)
                     (range 4996 5004))
        (check-model (adapter:pvector-set appended 5000 'x)
                     (append (range 5000) '(x) (range 5001 10000)))
        (let-values ([(split-left split-right)
                      (adapter:pvector-split-at appended 5000)])
          (check-model split-left (range 5000))
          (check-model split-right (range 5000 10000)))
        (check-core-large-edge-stats stats 4 4 9992)
        (check-no-chunk-shape-stats stats))
      (let* ([xs (range 10000)]
             [base (adapter:list->pvector xs)])
        (for ([small (in-list (list '(a)
                                    '(a b)
                                    '(a b c)
                                    '(a b c d)
                                    (range -64 0)))])
          (define small-len (length small))
          (define small-pv (apply adapter:pvector small))
          (define left-appended (adapter:pvector-append small-pv base))
          (define left-stats (adapter:pvector-shape-stats left-appended))
          (define right-appended (adapter:pvector-append base small-pv))
          (define right-stats (adapter:pvector-shape-stats right-appended))
          (define left-prefix-len
            (cond
              [(<= small-len 3) 1]
              [(= small-len 4) 2]
              [else 4]))
          (define right-suffix-len
            (cond
              [(<= small-len 2) 1]
              [(<= small-len 4) 2]
              [else 4]))
          (define total-len (+ 10000 small-len))
          (check-model left-appended (append small xs))
          (check-equal? (adapter:pvector-ref left-appended 0) (car small))
          (check-equal? (adapter:pvector-ref left-appended small-len) 0)
          (check-core-large-edge-stats
           left-stats
           left-prefix-len
           4
           (- total-len left-prefix-len 4))
          (check-no-chunk-shape-stats left-stats)
          (check-model right-appended (append xs small))
          (check-equal? (adapter:pvector-ref right-appended 9999) 9999)
          (check-equal? (adapter:pvector-ref right-appended 10000) (car small))
          (check-core-large-edge-stats
           right-stats
           4
           right-suffix-len
           (- total-len 4 right-suffix-len))
          (check-no-chunk-shape-stats right-stats)))
      (let* ([pv (adapter:list->pvector (range 8192))]
             [taken (adapter:pvector-take pv 4096)]
             [taken-stats (adapter:pvector-shape-stats taken)]
             [dropped (adapter:pvector-drop pv 4096)]
             [dropped-stats (adapter:pvector-shape-stats dropped)]
             [taken-right (adapter:pvector-take-right pv 4096)]
             [taken-right-stats (adapter:pvector-shape-stats taken-right)]
             [dropped-right (adapter:pvector-drop-right pv 4096)]
             [dropped-right-stats (adapter:pvector-shape-stats dropped-right)]
             [dropped-unaligned (adapter:pvector-drop pv 5000)]
             [dropped-unaligned-stats
              (adapter:pvector-shape-stats dropped-unaligned)])
        (check-model taken (range 4096))
        (check-model dropped (range 4096 8192))
        (check-model taken-right (range 4096 8192))
        (check-model dropped-right (range 4096))
        (check-model dropped-unaligned (range 5000 8192))
        (check-equal? (adapter:pvector-ref dropped-unaligned 0) 5000)
        (check-equal? (adapter:pvector-ref dropped-unaligned 3191) 8191)
        (for ([stats (in-list (list taken-stats dropped-stats
                                    taken-right-stats dropped-right-stats
                                    dropped-unaligned-stats))])
          (check-no-chunk-shape-stats stats)))
      (let* ([pv (adapter:list->pvector (range 8192))])
        (let-values ([(left right) (adapter:pvector-split-at pv 4096)])
          (let ([left-stats (adapter:pvector-shape-stats left)]
                [right-stats (adapter:pvector-shape-stats right)])
            (check-model left (range 4096))
            (check-model right (range 4096 8192))
            (check-no-chunk-shape-stats left-stats)
            (check-no-chunk-shape-stats right-stats)))
        (let-values ([(left right) (adapter:pvector-split-at pv 5000)])
          (let ([left-stats (adapter:pvector-shape-stats left)]
                [right-stats (adapter:pvector-shape-stats right)])
            (check-model left (range 5000))
            (check-equal? (adapter:pvector-ref left 4999) 4999)
            (check-model right (range 5000 8192))
            (check-equal? (adapter:pvector-ref right 0) 5000)
            (check-no-chunk-shape-stats left-stats)
            (check-no-chunk-shape-stats right-stats)))
        (let-values ([(left value right) (adapter:pvector-split pv 4095)])
          (let ([left-stats (adapter:pvector-shape-stats left)]
                [right-stats (adapter:pvector-shape-stats right)])
            (check-model left (range 4095))
            (check-equal? value 4095)
            (check-model right (range 4096 8192))
            (check-no-chunk-shape-stats left-stats)
            (check-no-chunk-shape-stats right-stats)))
        (let-values ([(left value right) (adapter:pvector-split pv 5000)])
          (let ([left-stats (adapter:pvector-shape-stats left)]
                [right-stats (adapter:pvector-shape-stats right)])
            (check-model left (range 5000))
            (check-equal? value 5000)
            (check-equal? (adapter:pvector-ref left 4999) 4999)
            (check-model right (range 5001 8192))
            (check-equal? (adapter:pvector-ref right 0) 5001)
            (check-no-chunk-shape-stats left-stats)
            (check-no-chunk-shape-stats right-stats)))))
    (let ([count 0])
      (define mapped
        (adapter:pvector-map made
                             (lambda (value)
                               (set! count (add1 count))
                               value)))
      (check-equal? count 130)
      (check-eq? (vector-ref (adapter:pvector->vector mapped) 64) elem)
      (check-eq? (list-ref (adapter:pvector->list mapped) 129) elem))
    (let ([count 0])
      (define mapped
        (adapter:pvector-map made
                             (lambda (value)
                               (set! count (add1 count))
                               (if (= count 66) 'other value))))
      (check-equal? count 130)
      (check-eq? (vector-ref (adapter:pvector->vector mapped) 64) elem)
      (check-equal? (vector-ref (adapter:pvector->vector mapped) 65) 'other)
      (check-eq? (list-ref (adapter:pvector->list mapped) 66) elem))
    (let-values ([(value rest) (adapter:pvector-pop-left made)])
      (check-eq? value elem)
      (check-eq? (vector-ref (adapter:pvector->vector rest) 0) elem)
      (check-eq? (list-ref (adapter:pvector->list rest) 128) elem))
    (let-values ([(value rest) (adapter:pvector-pop-right made)])
      (check-eq? value elem)
      (check-eq? (vector-ref (adapter:pvector->vector rest) 0) elem)
      (check-eq? (list-ref (adapter:pvector->list rest) 128) elem))
    (let-values ([(value rest) (adapter:pvector-pop-left made*)])
      (check-eq? value elem)
      (check-equal? (vector-ref (adapter:pvector->vector rest) 63) 'changed))
    (let-values ([(rest value) (adapter:pvector-delete made 65)])
      (check-eq? value elem)
      (check-eq? (vector-ref (adapter:pvector->vector rest) 64) elem)
      (check-eq? (vector-ref (adapter:pvector->vector rest) 65) elem)
      (check-eq? (list-ref (adapter:pvector->list rest) 128) elem))
    (let-values ([(rest value) (adapter:pvector-delete made* 64)])
      (check-equal? value 'changed)
      (check-eq? (vector-ref (adapter:pvector->vector rest) 64) elem))
    (let-values ([(left right) (adapter:pvector-split-at made 65)])
      (check-eq? (vector-ref (adapter:pvector->vector left) 64) elem)
      (check-eq? (vector-ref (adapter:pvector->vector right) 0) elem)
      (check-eq? (list-ref (adapter:pvector->list right) 64) elem))
    (let-values ([(left right) (adapter:pvector-split-at made* 65)])
      (check-equal? (vector-ref (adapter:pvector->vector left) 64) 'changed)
      (check-eq? (vector-ref (adapter:pvector->vector right) 0) elem)))
  (let ([seen null])
    (check-model (adapter:pvector-map pv
                                      (lambda (x)
                                        (set! seen (cons x seen))
                                        (add1 x)))
                 (map add1 xs))
    (check-equal? (reverse seen) xs))
  (check-true (adapter:pvector-empty?
               (adapter:pvector-map (adapter:pvector-empty) add1)))
  (check-model (adapter:pvector-map (adapter:pvector-drop pv 3) values)
               (drop xs 3))
  (check-true (eq? pv (adapter:pvector-map pv values)))
  (define mapped-void (adapter:pvector-map pv void))
  (check-equal? (adapter:pvector-length mapped-void) (length xs))
  (for ([v (adapter:in-pvector mapped-void)])
    (check-equal? v (void)))
  (let ([seen null])
    (check-equal? (adapter:pvector-for-each (adapter:pvector 'a 'b 'c)
                                            (lambda (v)
                                              (set! seen (append seen (list v)))))
                  (void))
    (check-equal? seen '(a b c))
    (set! seen null)
    (check-equal? (adapter:pvector-for-each (adapter:pvector 'a 'b 'c 'd)
                                            (lambda (v)
                                              (set! seen (append seen (list v)))))
                  (void))
    (check-equal? seen '(a b c d)))
  (check-equal? (adapter:pvector-for-each pv void) (void))
  (check-equal? (adapter:pvector-for-each pv values) (void))
  (check-exn exn:fail?
             (lambda ()
               (adapter:pvector-map (adapter:pvector 1)
                                    (lambda (x) (values x x)))))
  (check-exn exn:fail?
             (lambda ()
               (adapter:pvector-map (adapter:pvector 1 2)
                                    (lambda (x) (values x x)))))
  (check-exn exn:fail?
             (lambda ()
               (adapter:pvector-map (adapter:pvector 1 2 3)
                                    (lambda (x) (values x x)))))
  (check-exn exn:fail?
             (lambda ()
               (adapter:pvector-map (adapter:pvector 1 2 3 4)
                                    (lambda (x) (values x x)))))
  (check-equal? (adapter:pvector-view-left (adapter:pvector 'only)) 'only)
  (check-equal? (adapter:pvector-view-right (adapter:pvector 'only)) 'only)
  (check-equal? (adapter:pvector-view-left (adapter:pvector 'left 'right))
                'left)
  (check-equal? (adapter:pvector-view-right (adapter:pvector 'left 'right))
                'right)
  (check-equal? (adapter:pvector-view-left pv) 0)
  (check-equal? (adapter:pvector-view-right pv) 129)
  (check-exn exn:fail?
             (lambda ()
               (adapter:pvector-view-left (adapter:pvector-empty))))
  (check-exn exn:fail?
             (lambda ()
               (adapter:pvector-view-right (adapter:pvector-empty))))
  (check-model (adapter:pvector-set pv 64 'x)
               (append (take xs 64) '(x) (drop xs 65)))
  (when (core-backend?)
    (check-true (eq? pv (adapter:pvector-set pv 64 64)))
    (check-false (eq? pv (adapter:pvector-set pv 64 'x))))
  (define-values (middle-delete middle-deleted)
    (adapter:pvector-delete pv 32))
  (check-equal? middle-deleted 32)
  (check-model middle-delete (append (take xs 32) (drop xs 33)))
  (check-chunk-vector-lengths middle-delete
                '(63 64 2))
  (define-values (last-chunk-delete last-chunk-deleted)
    (adapter:pvector-delete pv 128))
  (check-equal? last-chunk-deleted 128)
  (check-model last-chunk-delete (append (take xs 128) (drop xs 129)))
  (check-chunk-vector-lengths last-chunk-delete
                '(64 64 1))
  (check-model (adapter:pvector-cons-left pv 'left)
               (cons 'left xs))
  (check-model (adapter:pvector-cons-right pv 'right)
               (append xs '(right)))
  (define packed-right
    (for/fold ([pv (adapter:pvector-empty)]) ([i (in-range 9)])
      (adapter:pvector-cons-right pv i)))
  (check-chunk-vector-lengths packed-right
                '(8 1))
  (define packed-left
    (for/fold ([pv (adapter:pvector-empty)]) ([i (in-range 9)])
      (adapter:pvector-cons-left pv i)))
  (check-chunk-vector-lengths packed-left
                '(1 8))
  (define single-chunk (adapter:pvector 0 1 2 3 4 5 6 7 8 9))
  (define single-set (adapter:pvector-set single-chunk 5 'x))
  (check-model single-set '(0 1 2 3 4 x 6 7 8 9))
  (check-chunk-vector-lengths single-set
                '(10))
  (define-values (single-left single-right)
    (adapter:pvector-split-at single-chunk 5))
  (check-model single-left '(0 1 2 3 4))
  (check-model single-right '(5 6 7 8 9))
  (check-chunk-vector-lengths single-left
                '(5))
  (check-chunk-vector-lengths single-right
                '(5))
  (define-values (split-left split-value split-right)
    (adapter:pvector-split single-chunk 5))
  (check-model split-left '(0 1 2 3 4))
  (check-equal? split-value 5)
  (check-model split-right '(6 7 8 9))
  (check-chunk-vector-lengths split-right
                '(4))
  (define-values (front-value-left front-value front-value-right)
    (adapter:pvector-split pv 3))
  (check-equal? front-value 3)
  (check-chunk-vector-lengths front-value-left
                '(3))
  (check-chunk-vector-lengths front-value-right
                '(60 64 2))
  (define-values (back-value-left back-value back-value-right)
    (adapter:pvector-split pv 129))
  (check-equal? back-value 129)
  (check-chunk-vector-lengths back-value-left
                '(64 64 1))
  (check-chunk-vector-lengths back-value-right
                '())
  (define single-insert (adapter:pvector-insert single-chunk 5 'x))
  (check-model single-insert '(0 1 2 3 4 x 5 6 7 8 9))
  (check-chunk-vector-lengths single-insert
                '(11))
  (define tail-insert-base (adapter:list->pvector (range 70)))
  (define tail-insert (adapter:pvector-insert tail-insert-base 64 'b))
  (check-model tail-insert (append (range 64) '(b) (range 64 70)))
  (check-chunk-vector-lengths tail-insert
                '(64 7))
  (define wide-insert-base (adapter:list->pvector (range 300)))
  (define-values (wide-middle-open wide-middle-deleted)
    (adapter:pvector-delete wide-insert-base 100))
  (check-equal? wide-middle-deleted 100)
  (check-chunk-vector-lengths wide-middle-open
                '(64 63 64 64 44))
  (define wide-middle-insert (adapter:pvector-insert wide-middle-open 100 'x))
  (check-model wide-middle-insert (append (range 100) '(x) (range 101 300)))
  (check-chunk-vector-lengths wide-middle-insert
                '(64 64 64 64 44))
  (define wide-full-insert (adapter:pvector-insert wide-insert-base 100 'y))
  (check-model wide-full-insert (append (range 100) '(y) (range 100 300)))
  (check-chunk-vector-lengths wide-full-insert
                '(64 36 1 28 64 64 44))
  (define-values (single-delete deleted)
    (adapter:pvector-delete single-chunk 5))
  (check-equal? deleted 5)
  (check-model single-delete '(0 1 2 3 4 6 7 8 9))
  (check-chunk-vector-lengths single-delete
                '(9))
  (define-values (single-pop-left-value single-pop-left-rest)
    (adapter:pvector-pop-left single-chunk))
  (check-equal? single-pop-left-value 0)
  (check-model single-pop-left-rest '(1 2 3 4 5 6 7 8 9))
  (check-chunk-vector-lengths single-pop-left-rest
                '(9))
  (define-values (single-pop-right-value single-pop-right-rest)
    (adapter:pvector-pop-right single-chunk))
  (check-equal? single-pop-right-value 9)
  (check-model single-pop-right-rest '(0 1 2 3 4 5 6 7 8))
  (check-chunk-vector-lengths single-pop-right-rest
                '(9))
  (define small-append
    (adapter:pvector-append (adapter:pvector 1 2 3)
                            (adapter:pvector 4 5 6)))
  (check-model small-append '(1 2 3 4 5 6))
  (check-chunk-vector-count small-append 1)
  (define merged-endpoints
    (adapter:pvector-append (adapter:pvector-take pv 3)
                            (adapter:pvector-drop pv 128)))
  (check-model merged-endpoints (append (take xs 3) (drop xs 128)))
  (check-chunk-vector-count merged-endpoints 1)
  (define deep-boundary-append
    (adapter:pvector-append (adapter:pvector-take pv 70)
                            (adapter:pvector-drop pv 100)))
  (check-model deep-boundary-append (append (take xs 70) (drop xs 100)))
  (check-chunk-vector-lengths deep-boundary-append
                '(64 6 28 2))
  (define-values (left rest-left) (adapter:pvector-pop-left pv))
  (check-equal? left 0)
  (check-model rest-left (range 1 130))
  (define-values (right rest-right) (adapter:pvector-pop-right pv))
  (check-equal? right 129)
  (check-model rest-right (range 129))
  (for ([pos (in-list '(0 1 63 64 65 100 129 130))])
    (define-values (l r) (adapter:pvector-split-at pv pos))
    (check-model l (take xs pos))
    (check-model r (drop xs pos))
    (check-model (adapter:pvector-take pv pos) (take xs pos))
    (check-model (adapter:pvector-drop pv pos) (drop xs pos)))
  (define-values (front-split-left front-split-right)
    (adapter:pvector-split-at pv 3))
  (check-chunk-vector-lengths front-split-left
                '(3))
  (check-chunk-vector-lengths front-split-right
                '(61 64 2))
  (define-values (back-split-left back-split-right)
    (adapter:pvector-split-at pv 129))
  (check-chunk-vector-lengths back-split-left
                '(64 64 1))
  (check-chunk-vector-lengths back-split-right
                '(1))
  (define cross-chunk-copy (adapter:pvector-copy pv 63 100))
  (check-model cross-chunk-copy (take (drop xs 63) 37))
  (check-chunk-vector-lengths cross-chunk-copy
                '(1 36))
  (define three-chunk-copy (adapter:pvector-copy pv 60 129))
  (check-model three-chunk-copy (take (drop xs 60) 69))
  (check-chunk-vector-lengths three-chunk-copy
                '(4 64 1))
  (define same-chunk-copy (adapter:pvector-copy pv 2 62))
  (check-model same-chunk-copy (take (drop xs 2) 60))
  (check-chunk-vector-lengths same-chunk-copy
                '(60))
  (define wide-xs (range 300))
  (define wide-pv (adapter:list->pvector wide-xs))
  (define wide-middle-copy (adapter:pvector-copy wide-pv 90 230))
  (check-model wide-middle-copy (take (drop wide-xs 90) 140))
  (check-chunk-vector-lengths wide-middle-copy
                '(38 64 38))
  (define wide-inserted (adapter:pvector-insert wide-pv 150 'x))
  (check-chunk-vector-lengths wide-inserted
                '(64 64 22 1 42 64 44))
  (define-values (wide-deleted wide-value)
    (adapter:pvector-delete wide-inserted 150))
  (check-equal? wide-value 'x)
  (check-model wide-deleted wide-xs)
  (check-chunk-vector-lengths wide-deleted
                '(64 64 22 42 64 44))
  (define large-xs (range 10000))
  (define large-pv (adapter:list->pvector large-xs))
  (check-model (adapter:pvector-copy large-pv 1250 8750)
               (take (drop large-xs 1250) 7500))
  (when (core-backend?)
    (let* ([pv (adapter:list->pvector (range 8192))]
           [set-pv (adapter:pvector-set pv 4096 'x)]
           [stats (adapter:pvector-shape-stats set-pv)])
      (check-model set-pv
                   (append (range 4096) '(x) (range 4097 8192)))
      (check-core-large-edge-stats stats 4 4 8184)
      (check-no-chunk-shape-stats stats))
    (let* ([pv (adapter:list->pvector (range 8192))]
           [set-prefix (adapter:pvector-set pv 0 'x)]
           [prefix-stats (adapter:pvector-shape-stats set-prefix)]
           [set-suffix (adapter:pvector-set pv 8191 'y)]
           [suffix-stats (adapter:pvector-shape-stats set-suffix)])
      (check-equal? (adapter:pvector-ref set-prefix 0) 'x)
      (check-equal? (adapter:pvector-ref set-prefix 1) 1)
      (check-equal? (adapter:pvector-ref set-suffix 8190) 8190)
      (check-equal? (adapter:pvector-ref set-suffix 8191) 'y)
      (check-core-large-edge-stats prefix-stats 4 4 8184)
      (check-core-large-edge-stats suffix-stats 4 4 8184)
      (check-no-chunk-shape-stats prefix-stats)
      (check-no-chunk-shape-stats suffix-stats))
    (let* ([pv (adapter:list->pvector (range 8192))]
           [set-pv (adapter:pvector-set pv 4096 'x)]
           [set-pv* (adapter:pvector-set set-pv 4097 'y)]
           [stats (adapter:pvector-shape-stats set-pv*)])
      (check-model set-pv*
                   (append (range 4096) '(x y) (range 4098 8192)))
      (check-equal? (adapter:pvector-ref set-pv* 4096) 'x)
      (check-equal? (adapter:pvector-ref set-pv* 4097) 'y)
      (check-no-chunk-shape-stats stats))
    (let* ([pv (adapter:list->pvector (range 130))]
           [set-pv (adapter:pvector-set pv 64 6400)]
           [set-pv* (adapter:pvector-set set-pv 65 6500)]
           [set-xs (append (range 64) '(6400) (range 65 130))]
           [set-xs* (append (range 64) '(6400 6500) (range 66 130))]
           [stats (adapter:pvector-shape-stats set-pv*)]
           [seen null])
      (check-model (adapter:pvector-map set-pv add1)
                   (map add1 set-xs))
      (adapter:pvector-for-each set-pv*
                                (lambda (x) (set! seen (cons x seen))))
      (check-equal? (reverse seen) set-xs*)
      (check-no-chunk-shape-stats stats))
    (let* ([pv (adapter:list->pvector (range 8192))]
           [consed (adapter:pvector-cons-left pv 'x)]
           [stats (adapter:pvector-shape-stats consed)])
      (check-model consed (cons 'x (range 8192)))
      (check-equal? (adapter:pvector-ref consed 0) 'x)
      (check-equal? (adapter:pvector-ref consed 1) 0)
      (check-equal? (adapter:pvector-ref consed 8192) 8191)
      (check-core-large-edge-stats stats 1 4 8188)
      (check-no-chunk-shape-stats stats))
    (let* ([pv (adapter:list->pvector (range 8192))]
           [consed (adapter:pvector-cons-right pv 'x)]
           [stats (adapter:pvector-shape-stats consed)])
      (check-model consed (append (range 8192) '(x)))
      (check-core-large-edge-stats stats 4 1 8188)
      (check-no-chunk-shape-stats stats))
    (let* ([pv (adapter:list->pvector (range 8192))]
           [consed (adapter:pvector-cons-right pv 'x)]
           [consed* (adapter:pvector-cons-right consed 'y)]
           [stats (adapter:pvector-shape-stats consed*)])
      (check-model consed* (append (range 8192) '(x y)))
      (check-core-large-edge-stats stats 4 2 8188)
      (check-no-chunk-shape-stats stats))
    (let* ([pv (adapter:list->pvector (range 8192))]
           [stats #f])
      (let-values ([(value rest) (adapter:pvector-pop-left pv)])
        (set! stats (adapter:pvector-shape-stats rest))
        (check-equal? value 0)
        (check-model rest (range 1 8192))
        (check-equal? (adapter:pvector-ref rest 0) 1)
        (check-equal? (adapter:pvector-ref rest 8190) 8191)
        (check-core-large-edge-stats stats 3 4 8184)
        (check-no-chunk-shape-stats stats)))
    (let* ([pv (adapter:list->pvector (range 8192))])
      (let-values ([(value rest) (adapter:pvector-pop-left pv)])
        (define consed (adapter:pvector-cons-left rest 'x))
        (define stats (adapter:pvector-shape-stats consed))
        (define appended (adapter:pvector-append (adapter:pvector 'x) rest))
        (define appended-stats (adapter:pvector-shape-stats appended))
        (check-equal? value 0)
        (check-model consed (cons 'x (range 1 8192)))
        (check-model appended (cons 'x (range 1 8192)))
        (check-core-large-edge-stats stats 4 4 8184)
        (check-core-large-edge-stats appended-stats 4 4 8184)
        (check-no-chunk-shape-stats stats)
        (check-no-chunk-shape-stats appended-stats)))
    (let* ([pv (adapter:list->pvector (range 8192))])
      (let-values ([(value rest) (adapter:pvector-pop-left pv)])
        (define inserted (adapter:pvector-insert rest 1 'x))
        (define inserted-stats (adapter:pvector-shape-stats inserted))
        (let-values ([(deleted-rest deleted) (adapter:pvector-delete inserted 1)])
          (define deleted-stats (adapter:pvector-shape-stats deleted-rest))
          (check-equal? value 0)
          (check-model inserted (append '(1 x) (range 2 8192)))
          (check-equal? deleted 'x)
          (check-model deleted-rest (range 1 8192))
          (check-core-large-edge-stats inserted-stats 4 4 8184)
          (check-core-large-edge-stats deleted-stats 3 4 8184)
          (check-no-chunk-shape-stats inserted-stats)
          (check-no-chunk-shape-stats deleted-stats))))
    (let* ([pv (adapter:list->pvector (range 8192))]
           [stats #f])
      (let-values ([(value rest) (adapter:pvector-pop-right pv)])
        (set! stats (adapter:pvector-shape-stats rest))
        (check-equal? value 8191)
        (check-model rest (range 8191))
        (check-core-large-edge-stats stats 4 3 8184)
        (check-no-chunk-shape-stats stats)))
    (let* ([pv (adapter:list->pvector (range 8192))])
      (let-values ([(value1 rest1) (adapter:pvector-pop-right pv)])
        (let-values ([(value2 rest2) (adapter:pvector-pop-right rest1)])
          (define stats (adapter:pvector-shape-stats rest2))
          (check-equal? value1 8191)
          (check-equal? value2 8190)
          (check-model rest2 (range 8190))
          (check-core-large-edge-stats stats 4 2 8184)
          (check-no-chunk-shape-stats stats))))
    (let* ([pv (adapter:list->pvector (range 8192))])
      (let-values ([(value rest) (adapter:pvector-pop-right pv)])
        (define consed (adapter:pvector-cons-right rest 'x))
        (define stats (adapter:pvector-shape-stats consed))
        (define appended (adapter:pvector-append rest (adapter:pvector 'x)))
        (define appended-stats (adapter:pvector-shape-stats appended))
        (check-equal? value 8191)
        (check-model consed (append (range 8191) '(x)))
        (check-model appended (append (range 8191) '(x)))
        (check-core-large-edge-stats stats 4 4 8184)
        (check-core-large-edge-stats appended-stats 4 4 8184)
        (check-no-chunk-shape-stats stats)
        (check-no-chunk-shape-stats appended-stats)))
    (let* ([pv (adapter:list->pvector (range 8192))])
      (let-values ([(value rest) (adapter:pvector-pop-right pv)])
        (define inserted (adapter:pvector-insert rest 8190 'x))
        (define inserted-stats (adapter:pvector-shape-stats inserted))
        (let-values ([(deleted-rest deleted) (adapter:pvector-delete inserted 8190)])
          (define deleted-stats (adapter:pvector-shape-stats deleted-rest))
          (check-equal? value 8191)
          (check-model inserted (append (range 8190) '(x 8190)))
          (check-equal? deleted 'x)
          (check-model deleted-rest (range 8191))
          (check-core-large-edge-stats inserted-stats 4 4 8184)
          (check-core-large-edge-stats deleted-stats 4 3 8184)
          (check-no-chunk-shape-stats inserted-stats)
          (check-no-chunk-shape-stats deleted-stats))))
    (let* ([pv (adapter:list->pvector (range 8192))]
           [stats #f])
      (let-values ([(rest value) (adapter:pvector-delete pv 0)])
        (set! stats (adapter:pvector-shape-stats rest))
        (check-equal? value 0)
        (check-model rest (range 1 8192))
        (check-core-large-edge-stats stats 3 4 8184)
        (check-no-chunk-shape-stats stats)))
    (let* ([pv (adapter:list->pvector (range 8192))]
           [stats #f])
      (let-values ([(rest value) (adapter:pvector-delete pv 8191)])
        (set! stats (adapter:pvector-shape-stats rest))
        (check-equal? value 8191)
        (check-model rest (range 8191))
        (check-core-large-edge-stats stats 4 3 8184)
        (check-no-chunk-shape-stats stats)))
    (let* ([pv (adapter:list->pvector (range 8192))]
           [inserted (adapter:pvector-insert pv 4097 'x)]
           [inserted-stats (adapter:pvector-shape-stats inserted)])
      (check-model inserted (append (range 4097) '(x) (range 4097 8192)))
      (check-model (adapter:pvector-copy inserted 4094 4101)
                   '(4094 4095 4096 x 4097 4098 4099))
      (let-values ([(left right) (adapter:pvector-split-at inserted 4097)])
        (check-model left (range 4097))
        (check-model (adapter:pvector-copy right 0 7)
                     '(x 4097 4098 4099 4100 4101 4102)))
      (check-core-large-edge-stats inserted-stats 4 4 8185)
      (check-no-chunk-shape-stats inserted-stats))
    (let* ([pv (adapter:list->pvector (range 8192))]
           [xs (range 8192)])
      (for ([pos (in-list '(4 5 7 4096 4097 5000 8185 8186))])
        (define value (list 'x pos))
        (define inserted (adapter:pvector-insert pv pos value))
        (define inserted-model (append (take xs pos)
                                       (list value)
                                       (drop xs pos)))
        (define inserted-stats (adapter:pvector-shape-stats inserted))
        (let-values ([(deleted-rest deleted)
                      (adapter:pvector-delete inserted pos)])
          (define deleted-stats
            (adapter:pvector-shape-stats deleted-rest))
          (check-model inserted inserted-model)
          (check-equal? deleted value)
          (check-model deleted-rest xs)
          (check-no-chunk-shape-stats inserted-stats)
          (check-no-chunk-shape-stats deleted-stats))))
    (let* ([pv (adapter:list->pvector (range 8192))])
      (let-values ([(deleted-rest deleted) (adapter:pvector-delete pv 4097)])
        (define deleted-stats (adapter:pvector-shape-stats deleted-rest))
        (check-equal? deleted 4097)
        (check-model deleted-rest (append (range 4097) (range 4098 8192)))
        (check-model (adapter:pvector-copy deleted-rest 4094 4101)
                     '(4094 4095 4096 4098 4099 4100 4101))
        (let-values ([(left right) (adapter:pvector-split-at deleted-rest 4097)])
          (check-model left (range 4097))
          (check-model (adapter:pvector-copy right 0 7)
                       '(4098 4099 4100 4101 4102 4103 4104)))
        (check-core-large-edge-stats deleted-stats 4 4 8183)
        (check-no-chunk-shape-stats deleted-stats)))
    (let* ([pv (adapter:list->pvector (range 8192))])
      (for ([pos (in-list '(4 5 7 4096 4097 5000 8185 8186))])
        (let-values ([(left value right) (adapter:pvector-split pv pos)])
          (define left-stats (adapter:pvector-shape-stats left))
          (define right-stats (adapter:pvector-shape-stats right))
          (check-model left (range pos))
          (check-equal? value pos)
          (check-model right (range (add1 pos) 8192))
          (check-no-chunk-shape-stats left-stats)
          (check-no-chunk-shape-stats right-stats))))
    (let* ([pv (adapter:list->pvector (range 16384))]
           [copied (adapter:pvector-copy pv 4096 12288)]
           [stats (adapter:pvector-shape-stats copied)])
      (check-model copied (range 4096 12288))
      (check-no-chunk-shape-stats stats))
    (let* ([pv (adapter:list->pvector (range 8192))]
           [copied (adapter:pvector-copy pv 0 6144)]
           [stats (adapter:pvector-shape-stats copied)])
      (check-model copied (range 0 6144))
      (check-no-chunk-shape-stats stats))
    (let* ([pv (adapter:list->pvector (range 8192))]
           [copied (adapter:pvector-copy pv 2048 8192)]
           [stats (adapter:pvector-shape-stats copied)])
      (check-model copied (range 2048 8192))
      (check-no-chunk-shape-stats stats))
    (let* ([pv (adapter:list->pvector (range 8192))]
           [copied (adapter:pvector-copy pv 1 8191)]
           [stats (adapter:pvector-shape-stats copied)])
      (check-model copied (range 1 8191))
      (check-core-large-edge-stats stats 3 3 8184)
      (check-no-chunk-shape-stats stats))
    (let* ([pv (adapter:list->pvector (range 8192))]
           [middle-only (adapter:pvector-copy pv 4 8188)]
           [middle-only-stats (adapter:pvector-shape-stats middle-only)]
           [aligned-middle (adapter:pvector-copy pv 7 8185)]
           [aligned-middle-stats (adapter:pvector-shape-stats aligned-middle)]
           [left-middle (adapter:pvector-take pv 8188)]
           [left-middle-stats (adapter:pvector-shape-stats left-middle)]
           [left-aligned-middle (adapter:pvector-take pv 8185)]
           [left-aligned-middle-stats
            (adapter:pvector-shape-stats left-aligned-middle)]
           [middle-right (adapter:pvector-drop pv 4)]
           [middle-right-stats (adapter:pvector-shape-stats middle-right)]
           [aligned-middle-right (adapter:pvector-drop pv 7)]
           [aligned-middle-right-stats
            (adapter:pvector-shape-stats aligned-middle-right)]
           [unaligned-middle (adapter:pvector-copy pv 5 8186)]
           [unaligned-middle-stats
            (adapter:pvector-shape-stats unaligned-middle)]
           [unaligned-deep-middle (adapter:pvector-copy pv 123 8123)]
           [unaligned-deep-middle-stats
            (adapter:pvector-shape-stats unaligned-deep-middle)]
           [left-unaligned-middle (adapter:pvector-take pv 8186)]
           [left-unaligned-middle-stats
            (adapter:pvector-shape-stats left-unaligned-middle)]
           [unaligned-middle-right (adapter:pvector-drop pv 5)]
           [unaligned-middle-right-stats
            (adapter:pvector-shape-stats unaligned-middle-right)])
      (check-model middle-only (range 4 8188))
      (check-model aligned-middle (range 7 8185))
      (check-model unaligned-middle (range 5 8186))
      (check-model unaligned-deep-middle (range 123 8123))
      (check-model left-middle (range 0 8188))
      (check-model left-aligned-middle (range 0 8185))
      (check-model left-unaligned-middle (range 0 8186))
      (check-model middle-right (range 4 8192))
      (check-model aligned-middle-right (range 7 8192))
      (check-model unaligned-middle-right (range 5 8192))
      (check-core-large-edge-stats middle-only-stats 1 1 8182)
      (check-core-large-edge-stats aligned-middle-stats 1 1 8176)
      (check-core-large-edge-stats unaligned-middle-stats 2 1 8178)
      (check-core-large-edge-stats
       unaligned-deep-middle-stats
       1
       1
       7998)
      (check-core-large-edge-stats left-middle-stats 4 1 8183)
      (check-core-large-edge-stats left-aligned-middle-stats 4 1 8180)
      (check-core-large-edge-stats left-unaligned-middle-stats 4 1 8181)
      (check-core-large-edge-stats middle-right-stats 1 4 8183)
      (check-core-large-edge-stats aligned-middle-right-stats 1 4 8180)
      (check-core-large-edge-stats unaligned-middle-right-stats 2 4 8181)
      (check-no-chunk-shape-stats middle-only-stats)
      (check-no-chunk-shape-stats aligned-middle-stats)
      (check-no-chunk-shape-stats unaligned-middle-stats)
      (check-no-chunk-shape-stats unaligned-deep-middle-stats)
      (check-no-chunk-shape-stats left-middle-stats)
      (check-no-chunk-shape-stats left-aligned-middle-stats)
      (check-no-chunk-shape-stats left-unaligned-middle-stats)
      (check-no-chunk-shape-stats middle-right-stats)
      (check-no-chunk-shape-stats aligned-middle-right-stats)
      (check-no-chunk-shape-stats unaligned-middle-right-stats))
    (let* ([pv (adapter:list->pvector (range 8192))])
      (let-values ([(small-left large-right) (adapter:pvector-split-at pv 4)])
        (define right-stats (adapter:pvector-shape-stats large-right))
        (check-model small-left (range 4))
        (check-model large-right (range 4 8192))
        (check-core-large-edge-stats right-stats 1 4 8183)
        (check-no-chunk-shape-stats right-stats))
      (let-values ([(large-left small-right) (adapter:pvector-split-at pv 8188)])
        (define left-stats (adapter:pvector-shape-stats large-left))
        (check-model large-left (range 8188))
        (check-model small-right (range 8188 8192))
        (check-core-large-edge-stats left-stats 4 1 8183)
        (check-no-chunk-shape-stats left-stats))
      (let-values ([(small-left large-right) (adapter:pvector-split-at pv 7)])
        (define right-stats (adapter:pvector-shape-stats large-right))
        (check-model small-left (range 7))
        (check-model large-right (range 7 8192))
        (check-core-large-edge-stats right-stats 1 4 8180)
        (check-no-chunk-shape-stats right-stats))
      (let-values ([(small-left large-right) (adapter:pvector-split-at pv 5)])
        (define right-stats (adapter:pvector-shape-stats large-right))
        (check-model small-left (range 5))
        (check-model large-right (range 5 8192))
        (check-core-large-edge-stats right-stats 2 4 8181)
        (check-no-chunk-shape-stats right-stats))
      (let-values ([(large-left small-right) (adapter:pvector-split-at pv 8185)])
        (define left-stats (adapter:pvector-shape-stats large-left))
        (check-model large-left (range 8185))
        (check-model small-right (range 8185 8192))
        (check-core-large-edge-stats left-stats 4 1 8180)
        (check-no-chunk-shape-stats left-stats))
      (let-values ([(large-left small-right) (adapter:pvector-split-at pv 8186)])
        (define left-stats (adapter:pvector-shape-stats large-left))
        (check-model large-left (range 8186))
        (check-model small-right (range 8186 8192))
        (check-core-large-edge-stats left-stats 4 1 8181)
        (check-no-chunk-shape-stats left-stats)))
    (let* ([pv (adapter:list->pvector (range 16384))]
           [copied (adapter:pvector-copy pv 4100 12292)]
           [stats (adapter:pvector-shape-stats copied)])
      (check-model copied (range 4100 12292))
      (check-no-chunk-shape-stats stats)))
  (check-equal? (for/list ([x (adapter:in-pvector pv)]) x)
                xs)
  (check-equal? (for/list ([x (adapter:in-pvector-reverse pv)]) x)
                (reverse xs))
  (check-equal? (for/list ([(x i) (adapter:in-pvector/index pv)])
                  (list x i))
                (for/list ([x (in-list xs)]
                           [i (in-naturals)])
                  (list x i)))
  (check-equal? (for/list ([(x i) (adapter:in-pvector-indexed pv)])
                  (list x i))
                (for/list ([x (in-list xs)]
                           [i (in-naturals)])
                  (list x i)))
  (define indexed-seq (adapter:in-pvector/index pv))
  (check-equal? (for/list ([(x i) indexed-seq]) (list x i))
                (for/list ([x (in-list xs)]
                           [i (in-naturals)])
                  (list x i)))
  (define indexed-alias-seq (adapter:in-pvector-indexed pv))
  (check-equal? (for/list ([(x i) indexed-alias-seq]) (list x i))
                (for/list ([x (in-list xs)]
                           [i (in-naturals)])
                  (list x i)))
  (check-equal? (chunk-vector->list (adapter:pvector->chunk-vector pv))
                xs)
  (check-equal? (chunk-vector->list
                 (adapter:pvector->chunk-vector (adapter:pvector-drop pv 3)))
                (drop xs 3))
  (define seq (adapter:in-pvector pv))
  (check-equal? (for/list ([x seq]) x) xs)
  (check-equal? (for/list ([x seq]) x) xs)
  (define rseq (adapter:in-pvector-reverse pv))
  (check-equal? (for/list ([x rseq]) x) (reverse xs))
  (check-equal? (for/list ([x rseq]) x) (reverse xs))
  (define shifted-pv (adapter:pvector-drop pv 3))
  (define shifted-xs (drop xs 3))
  (define shifted-seq (adapter:in-pvector shifted-pv))
  (check-equal? (for/list ([x shifted-seq]) x) shifted-xs)
  (check-equal? (for/list ([x shifted-seq]) x) shifted-xs)
  (define shifted-rseq (adapter:in-pvector-reverse shifted-pv))
  (check-equal? (for/list ([x shifted-rseq]) x) (reverse shifted-xs))
  (define shifted-indexed-seq (adapter:in-pvector/index shifted-pv))
  (check-equal? (for/list ([(x i) shifted-indexed-seq]) (list x i))
                (for/list ([x (in-list shifted-xs)]
                           [i (in-naturals)])
                  (list x i)))
  (check-model (adapter:for/pvector ([x (in-range 5)]) (* x x))
               '(0 1 4 9 16))
  (check-true (eq? (adapter:for/pvector ([x (adapter:in-pvector pv)]) x)
                   pv))
  (check-true (eq? (adapter:for/pvector ([x pv]) x)
                   pv))
  (check-true (eq? (adapter:for/pvector #:length (adapter:pvector-length pv)
                     ([x (adapter:in-pvector pv)])
                     x)
                   pv))
  (check-true (eq? (adapter:for/pvector #:length (adapter:pvector-length pv)
                     ([x pv])
                     x)
                   pv))
  (check-model (adapter:for/pvector ([x (adapter:in-pvector-reverse pv)]) x)
               (reverse xs))
  (check-model (adapter:for/pvector #:length 3
                 ([x (adapter:in-pvector pv)])
                 x)
               '(0 1 2))
  (check-model (adapter:for/pvector #:length 133
                 ([x (adapter:in-pvector pv)])
                 x)
               (append xs '(0 0 0)))
  (check-model (adapter:for/pvector #:length 133 ([x pv]) x)
               (append xs '(0 0 0)))
  (check-model (adapter:for/pvector ([x (adapter:in-pvector pv)]) (* x x))
               (map (lambda (x) (* x x)) xs))
  (check-model (adapter:for/pvector ([x (in-list xs)]) x)
               xs)
  (let ([value (box 'builder-uniform)]
        [count 0])
    (define pv
      (adapter:for/pvector ([x (in-range 130)])
        (set! count (add1 count))
        value))
    (check-equal? count 130)
    (check-model pv (make-list 130 value))
    (check-eq? (vector-ref (adapter:pvector->vector pv) 64) value)
    (check-eq? (list-ref (adapter:pvector->list pv) 129) value)
    (when (core-backend?)
      (check-shared-chunk-vector-view pv)))
  (let ([value (box 'builder-mixed)]
        [count 0])
    (define pv
      (adapter:for/pvector ([x (in-range 130)])
        (set! count (add1 count))
        (if (= x 64) 'other value)))
    (check-equal? count 130)
    (check-model pv
                 (append (make-list 64 value)
                         '(other)
                         (make-list 65 value)))
    (check-eq? (vector-ref (adapter:pvector->vector pv) 63) value)
    (check-equal? (vector-ref (adapter:pvector->vector pv) 64) 'other)
    (check-eq? (list-ref (adapter:pvector->list pv) 129) value)
    (when (core-backend?)
      (check-shared-chunk-vector-view pv)))
  (let* ([src (list->vector xs)]
         [pv (adapter:for/pvector ([x (in-vector src)]) x)])
    (vector-set! src 0 'changed)
    (check-model pv xs))
  (let* ([src (list->vector xs)]
         [pv (adapter:for/pvector #:length (vector-length src)
               ([x (in-vector src)])
               x)])
    (vector-set! src 0 'changed)
    (check-model pv xs))
  (let* ([src (list->vector xs)]
         [pv (adapter:for/pvector #:length (vector-length src)
               ([x src])
               x)])
    (vector-set! src 0 'changed)
    (check-model pv xs))
  (check-model (adapter:for/pvector #:length 3
                 ([x (in-vector (list->vector xs))])
                 x)
               '(0 1 2))
  (check-model (adapter:for/pvector #:length 133
                 ([x (in-vector (list->vector xs))])
                 x)
               (append xs '(0 0 0)))
  (let ([count 0])
    (define (get-list)
      (set! count (add1 count))
      xs)
    (check-model (adapter:for/pvector ([x (in-list (get-list))]) x)
                 xs)
    (check-equal? count 1))
  (check-model (adapter:for/pvector #:length 5 #:fill 'done
                 ([x (in-range 3)])
                 x)
               '(0 1 2 done done))
  (let ([value (box 'length-builder-uniform)]
        [count 0])
    (define pv
      (adapter:for/pvector #:length 130 ([x (in-range 130)])
        (set! count (add1 count))
        value))
    (check-equal? count 130)
    (check-model pv (make-list 130 value))
    (check-eq? (vector-ref (adapter:pvector->vector pv) 64) value)
    (check-eq? (list-ref (adapter:pvector->list pv) 129) value)
    (when (core-backend?)
      (check-shared-chunk-vector-view pv)))
  (let ([n 5])
    (check-model (adapter:for/pvector #:length n
                   ([x (in-range 0 n)])
                   x)
                 '(0 1 2 3 4)))
  (let ([n 5])
    (check-model (adapter:for/pvector #:length n
                   ([x (in-range 0 n 1)])
                   x)
                 '(0 1 2 3 4)))
  (let ([n 5])
    (check-model (adapter:for/pvector #:length n
                   ([x (in-range 0 n)])
                   (* x x))
                 '(0 1 4 9 16)))
  (let ([n 5])
    (check-model (adapter:for/pvector #:length n
                   ([x (in-range 0 n 1)])
                   (* x x))
                 '(0 1 4 9 16)))
  (check-model (adapter:for*/pvector ([x (in-range 2)] [y (in-range 2)])
                 (list x y))
               '((0 0) (0 1) (1 0) (1 1)))
  (check-true (eq? (adapter:for*/pvector ([x (adapter:in-pvector pv)]) x)
                   pv))
  (check-true (eq? (adapter:for*/pvector ([x pv]) x)
                   pv))
  (check-true (eq? (adapter:for*/pvector #:length (adapter:pvector-length pv)
                     ([x (adapter:in-pvector pv)])
                     x)
                   pv))
  (check-true (eq? (adapter:for*/pvector #:length (adapter:pvector-length pv)
                     ([x pv])
                     x)
                   pv))
  (check-model (adapter:for*/pvector ([x (adapter:in-pvector-reverse pv)]) x)
               (reverse xs))
  (check-model (adapter:for*/pvector #:length 3
                 ([x (adapter:in-pvector pv)])
                 x)
               '(0 1 2))
  (check-model (adapter:for*/pvector #:length 133
                 ([x (adapter:in-pvector pv)])
                 x)
               (append xs '(0 0 0)))
  (check-model (adapter:for*/pvector #:length 133 ([x pv]) x)
               (append xs '(0 0 0)))
  (check-model (adapter:for*/pvector ([x (adapter:in-pvector pv)]) (* x x))
               (map (lambda (x) (* x x)) xs))
  (check-model (adapter:for*/pvector ([x (in-list xs)]) x)
               xs)
  (let ([value (box 'builder-uniform)]
        [count 0])
    (define pv
      (adapter:for*/pvector ([x (in-range 13)] [y (in-range 10)])
        (set! count (add1 count))
        value))
    (check-equal? count 130)
    (check-model pv (make-list 130 value))
    (check-eq? (vector-ref (adapter:pvector->vector pv) 64) value)
    (check-eq? (list-ref (adapter:pvector->list pv) 129) value)
    (when (core-backend?)
      (check-shared-chunk-vector-view pv)))
  (let* ([src (list->vector xs)]
         [pv (adapter:for*/pvector ([x (in-vector src)]) x)])
    (vector-set! src 0 'changed)
    (check-model pv xs))
  (let* ([src (list->vector xs)]
         [pv (adapter:for*/pvector #:length (vector-length src)
               ([x (in-vector src)])
               x)])
    (vector-set! src 0 'changed)
    (check-model pv xs))
  (let* ([src (list->vector xs)]
         [pv (adapter:for*/pvector #:length (vector-length src)
               ([x src])
               x)])
    (vector-set! src 0 'changed)
    (check-model pv xs))
  (check-model (adapter:for*/pvector #:length 3
                 ([x (in-vector (list->vector xs))])
                 x)
               '(0 1 2))
  (check-model (adapter:for*/pvector #:length 133
                 ([x (in-vector (list->vector xs))])
                 x)
               (append xs '(0 0 0)))
  (let ([n 5])
    (check-model (adapter:for*/pvector #:length n
                   ([x (in-range 0 n)])
                   x)
                 '(0 1 2 3 4)))
  (let ([n 5])
    (check-model (adapter:for*/pvector #:length n
                   ([x (in-range 0 n 1)])
                   x)
                 '(0 1 2 3 4)))
  (let ([n 5])
    (check-model (adapter:for*/pvector #:length n
                   ([x (in-range 0 n)])
                   (* x x))
                 '(0 1 4 9 16)))
  (let ([n 5])
    (check-model (adapter:for*/pvector #:length n
                   ([x (in-range 0 n 1)])
                   (* x x))
                 '(0 1 4 9 16)))
  (check-model (adapter:for*/pvector #:length 4
                 ([x (in-range 2)] [y (in-range 2)])
                 (list x y))
               '((0 0) (0 1) (1 0) (1 1))))
