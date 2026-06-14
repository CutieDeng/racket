#lang racket/base

(require racket/private/generic
         racket/generic
         racket/contract/base
         racket/contract/combinator
         racket/function
         racket/generator
         racket/match
         (only-in '#%kernel vector-copy)
         '#%flfxnum
         racket/unsafe/ops
         (rename-in "private/for.rkt"
                    [stream-ref stream-get-generics])
         "private/sequence.rkt"
         (only-in "private/stream-cons.rkt"
                  stream-cons
                  stream-lazy
                  stream-force
                  unpack-multivalue
                  thunk->multivalue)
         "private/generic-methods.rkt"
         (for-syntax racket/base))

(provide empty-stream
         stream-cons
         stream?
         gen:stream
         ;; we don't need the generics versions of these because
         ;; the original sequence functions will work fine
         ;; for the dispatch. (the method table layout is
         ;; identical)
         stream-empty?
         stream-first
         stream-rest
         prop:stream
         in-stream
         stream-lazy
         stream-force

         stream
         stream*
         stream->list
         stream-length
         stream-ref
         stream-tail
         stream-take
         stream-append
         stream-map
         stream-andmap
         stream-ormap
         stream-for-each
         stream-fold
         stream-filter
         stream-add-between
         stream-count

         stream/c

         for/stream
         for*/stream)

(define-syntax gen:stream
  (make-generic-info (quote-syntax gen:stream)
                     (quote-syntax prop:stream)
                     (quote-syntax stream-via-prop?)
                     (quote-syntax stream-get-generics)
                     (list (quote-syntax stream-empty?)
                           (quote-syntax stream-first)
                           (quote-syntax stream-rest))
                     (list (quote-syntax stream-empty?)
                           (quote-syntax stream-first)
                           (quote-syntax stream-rest))
                     (list #t #t #t)))

(define-match-expander stream
  (syntax-rules (values)
    [(_) (? stream-empty?)]
    [(_ (values hd ...) tl ...)
     (? stream-cons?
        (app stream-first hd ...)
        (app stream-rest (stream tl ...)))]
    [(_ hd tl ...)
     (? stream-cons?
        (app stream-first hd)
        (app stream-rest (stream tl ...)))])
  (syntax-rules ()
    ((_)
     empty-stream)
    ((_ tl)
     ;; shortcut:
     (stream-cons tl #:eager empty-stream))
    ((_ hd tl ...)
     (stream-cons hd (stream tl ...)))))

(define-match-expander stream*
  (syntax-rules (values)
    [(_ tl) (? stream? tl)]
    [(_ (values hd ...) tl ...)
     (? stream-cons?
        (app stream-first hd ...)
        (app stream-rest (stream* tl ...)))]
    [(_ hd tl ...)
     (? stream-cons?
        (app stream-first hd)
        (app stream-rest (stream* tl ...)))])
  (syntax-rules ()
    [(_ tl)
     (stream-lazy #:who 'stream* tl)]
    [(_ hd tl ...)
     (stream-cons hd (stream* tl ...))]))

(define (stream-cons? st)
  (and (stream? st) (not (stream-empty? st))))

(define pvector-stream-procs #f)

(define (load-pvector-stream-procs)
  (unless pvector-stream-procs
    (set! pvector-stream-procs
          (with-handlers ([exn:fail? (lambda (_) 'unavailable)])
            (vector (dynamic-require 'racket/pvector 'pvector?)
                    (dynamic-require 'racket/pvector 'pvector->list)
                    (dynamic-require 'racket/pvector 'pvector-length)
                    (dynamic-require 'racket/pvector 'pvector-ref)
                    (dynamic-require 'racket/pvector 'pvector-drop)
                    (dynamic-require 'racket/pvector 'pvector-take)
                    (dynamic-require 'racket/pvector 'pvector-empty)
                    (dynamic-require 'racket/pvector 'pvector-append)
                    (dynamic-require 'racket/pvector 'pvector->vector)
                    (dynamic-require 'racket/pvector 'vector->pvector)
                    (dynamic-require 'racket/pvector 'pvector-for-each)
                    (dynamic-require 'racket/pvector 'pvector-map)
                    (dynamic-require '(submod racket/pvector unsafe)
                                     'unsafe-pvector->chunk-vector)
                    (dynamic-require 'racket/pvector 'make-pvector)
                    (dynamic-require '(submod racket/pvector unsafe)
                                     'unsafe-pvector-length)
                    (dynamic-require '(submod racket/pvector unsafe)
                                     'unsafe-pvector-ref)
                    (dynamic-require '(submod racket/pvector unsafe)
                                     'unsafe-pvector-drop)
                    (dynamic-require '(submod racket/pvector unsafe)
                                     'unsafe-pvector-take)))))
  (and (vector? pvector-stream-procs)
       pvector-stream-procs))

(define (pvector-stream-procs-for s)
  (and (sequence-via-prop? s)
       (let ([procs (load-pvector-stream-procs)])
         (and procs
              ((vector-ref procs 0) s)
              procs))))

(define (stream->list s)
  (cond
    [(pvector-map-stream? s)
     (pvector-map-stream->list s)]
    [(pvector-filter-stream? s)
     (pvector-filter-stream->list s)]
    [(pvector-filter-take-stream? s)
     (pvector-filter-take-stream->list s)]
    [(pvector-append-stream? s)
     (pvector-append-stream->list s)]
    [else
     (let ([procs (pvector-stream-procs-for s)])
       (if procs
           ((vector-ref procs 1) s)
           (for/list ([v (in-stream s)]) v)))]))

(define (stream-length/slow s)
  (let loop ([s s] [len 0])
    (if (stream-empty? s)
        len
        (loop (stream-rest s) (add1 len)))))

(define (stream-length s)
  (unless (stream? s) (raise-argument-error 'stream-length "stream?" s))
  (cond
    [(pvector-map-stream? s)
     (pvector-map-stream-length s)]
    [(pvector-filter-stream? s)
     (pvector-filter-stream-length s)]
    [(pvector-append-stream? s)
     (pvector-append-stream-length s)]
    [else
     (let ([procs (pvector-stream-procs-for s)])
       (if procs
           ((vector-ref procs 14) s)
           (stream-length/slow s)))]))

(define (stream-ref/slow st i)
  (let loop ([n i] [s st])
    (cond
     [(stream-empty? s)
      (raise-stream-ended-before-index 'stream-ref i)]
     [(zero? n)
      (stream-first s)]
     [else
      (loop (sub1 n) (stream-rest s))])))

(define (raise-stream-ended-before-index who i)
  (raise-arguments-error who
                         "stream ended before index"
                         "index" i
                         ;; Why `"stream" st` is omitted:
                         ;; including `st` in the error message
                         ;; means that it has to be kept live;
                         ;; that's not so great for a stream, where
                         ;; lazy construction could otherwise allow
                         ;; a element to be reached without consuming
                         ;; proportional memory
                         #;"stream" #;st))

(define (stream-ref st i)
  (unless (stream? st) (raise-argument-error 'stream-ref "stream?" st))
  (unless (exact-nonnegative-integer? i)
    (raise-argument-error 'stream-ref "exact-nonnegative-integer?" i))
  (cond
    [(pvector-map-stream? st)
     (pvector-map-stream-ref st i)]
    [(pvector-filter-stream? st)
     (pvector-filter-stream-ref st i)]
    [(pvector-append-stream? st)
     (pvector-append-stream-ref st i)]
    [else
     (define procs (pvector-stream-procs-for st))
     (if procs
         (let ([len ((vector-ref procs 14) st)])
           (if (< i len)
               ((vector-ref procs 15) st i)
               (raise-stream-ended-before-index 'stream-ref i)))
         (stream-ref/slow st i))]))

(define (stream-tail/slow st i)
  (let loop ([n i] [s st])
    (cond
      [(zero? n) s]
      [(stream-empty? s)
       (raise-stream-ended-before-index 'stream-tail i)]
      [else
       (loop (sub1 n) (stream-rest s))])))

(define (stream-tail st i)
  (unless (stream? st) (raise-argument-error 'stream-tail "stream?" st))
  (unless (exact-nonnegative-integer? i)
    (raise-argument-error 'stream-tail "exact-nonnegative-integer?" i))
  (cond
    [(zero? i) st]
    [(pvector-map-stream? st)
     (pvector-map-stream-tail st i)]
    [(pvector-filter-stream? st)
     (pvector-filter-stream-tail-at st i)]
    [(pvector-append-stream? st)
     (pvector-append-stream-tail-at st i)]
    [else
     (define procs (pvector-stream-procs-for st))
     (if procs
         (let ([len ((vector-ref procs 14) st)])
           (if (<= i len)
               ((vector-ref procs 16) st i)
               (raise-stream-ended-before-index 'stream-tail i)))
         (stream-tail/slow st i))]))

(define (stream-take/slow st i)
  (stream-lazy
   (let loop ([n i] [s st])
     (cond
       [(zero? n) empty-stream]
       [(stream-empty? s)
        (raise-stream-ended-before-index 'stream-take i)]
       [else
        (stream-cons (stream-first s)
                     (loop (sub1 n) (stream-rest s)))]))))

(define (stream-take st i)
  (unless (stream? st) (raise-argument-error 'stream-take "stream?" st))
  (unless (exact-nonnegative-integer? i)
    (raise-argument-error 'stream-take "exact-nonnegative-integer?" i))
  (cond
    [(pvector-map-stream? st)
     (pvector-map-stream-take st i)]
    [(pvector-append-stream? st)
     (pvector-append-stream-take st i)]
    [(pvector-filter-stream? st)
     (pvector-filter-stream-take st i)]
    [else
     (define procs (pvector-stream-procs-for st))
     (if procs
         (let ([len ((vector-ref procs 14) st)])
           (if (<= i len)
               ((vector-ref procs 17) st i)
               (raise-stream-ended-before-index 'stream-take i)))
         (stream-take/slow st i))]))

(define (reverse-onto acc tail)
  (let loop ([acc acc] [tail tail])
    (if (null? acc)
        tail
        (loop (cdr acc) (cons (car acc) tail)))))

(define (all-pvectors? l pvector?)
  (let loop ([l l])
    (cond
      [(null? l) #t]
      [(pvector? (car l)) (loop (cdr l))]
      [else #f])))

(define (pvector-stream-append l)
  (let ([procs (load-pvector-stream-procs)])
    (and procs
         (all-pvectors? l (vector-ref procs 0))
         (let ([pvector-empty (vector-ref procs 6)]
               [pvector-append (vector-ref procs 7)])
           (let loop ([l l] [result (pvector-empty)])
             (if (null? l)
                 result
                 (loop (cdr l) (pvector-append result (car l)))))))))

(struct pvector-append-stream (s pos len tail procs)
  #:property prop:stream
  (vector
   (lambda (st)
     (and (unsafe-fx>= (pvector-append-stream-pos st)
                       (pvector-append-stream-len st))
          (stream-empty? (pvector-append-stream-tail st))))
   (lambda (st)
     (if (unsafe-fx< (pvector-append-stream-pos st)
                     (pvector-append-stream-len st))
         ((vector-ref (pvector-append-stream-procs st) 15)
          (pvector-append-stream-s st)
          (pvector-append-stream-pos st))
         (stream-first (pvector-append-stream-tail st))))
   (lambda (st)
     (cond
       [(unsafe-fx< (pvector-append-stream-pos st)
                    (unsafe-fx- (pvector-append-stream-len st) 1))
        (pvector-append-stream (pvector-append-stream-s st)
                               (unsafe-fx+ (pvector-append-stream-pos st) 1)
                               (pvector-append-stream-len st)
                               (pvector-append-stream-tail st)
                               (pvector-append-stream-procs st))]
       [(unsafe-fx< (pvector-append-stream-pos st)
                    (pvector-append-stream-len st))
        (pvector-append-stream (pvector-append-stream-s st)
                               (pvector-append-stream-len st)
                               (pvector-append-stream-len st)
                               (pvector-append-stream-tail st)
                               (pvector-append-stream-procs st))]
       [else (stream-rest (pvector-append-stream-tail st))]))))

(define (pvector-stream-append-prefix l)
  (let ([procs (load-pvector-stream-procs)])
    (and procs
         (pair? l)
         ((vector-ref procs 0) (car l))
         (let* ([s (car l)]
                [len ((vector-ref procs 14) s)]
                [tail (apply stream-append (cdr l))])
           (if (unsafe-fx= len 0)
               tail
               (pvector-append-stream s 0 len tail procs))))))

(define (pvector-append-stream-prefix-length st)
  (unsafe-fx- (pvector-append-stream-len st)
              (pvector-append-stream-pos st)))

(define (pvector-append-stream-length st)
  (+ (pvector-append-stream-prefix-length st)
     (stream-length (pvector-append-stream-tail st))))

(define (pvector-append-stream-ref st i)
  (let ([prefix-len (pvector-append-stream-prefix-length st)])
    (cond
      [(< i prefix-len)
       ((vector-ref (pvector-append-stream-procs st) 15)
        (pvector-append-stream-s st)
        (unsafe-fx+ (pvector-append-stream-pos st) i))]
      [else
       (stream-ref (pvector-append-stream-tail st)
                   (- i prefix-len))])))

(define (pvector-append-stream-tail-at st i)
  (let ([prefix-len (pvector-append-stream-prefix-length st)])
    (cond
      [(< i prefix-len)
       (pvector-append-stream
        (pvector-append-stream-s st)
        (unsafe-fx+ (pvector-append-stream-pos st) i)
        (pvector-append-stream-len st)
        (pvector-append-stream-tail st)
        (pvector-append-stream-procs st))]
      [(= i prefix-len)
       (pvector-append-stream-tail st)]
      [else
       (stream-tail (pvector-append-stream-tail st)
                    (- i prefix-len))])))

(define (pvector-append-stream-take st i)
  (let ([prefix-len (pvector-append-stream-prefix-length st)])
    (if (<= i prefix-len)
        (pvector-append-stream
         (pvector-append-stream-s st)
         (pvector-append-stream-pos st)
         (+ (pvector-append-stream-pos st) i)
         empty-stream
         (pvector-append-stream-procs st))
        (stream-take/slow st i))))

(define (pvector-append-stream->list st)
  (let ([s (pvector-append-stream-s st)]
        [len (pvector-append-stream-len st)]
        [chunks ((vector-ref (pvector-append-stream-procs st) 12)
                 (pvector-append-stream-s st))])
    (let chunk-loop ([chunk-pos 0] [offset 0] [acc null])
      (if (or (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
              (unsafe-fx>= offset len))
          (reverse-onto acc (stream->list (pvector-append-stream-tail st)))
          (let* ([chunk (unsafe-vector-ref chunks chunk-pos)]
                 [chunk-len (unsafe-vector-length chunk)]
                 [next-offset (unsafe-fx+ offset chunk-len)]
                 [end-pos (if (unsafe-fx< len next-offset)
                              (unsafe-fx- len offset)
                              chunk-len)])
            (cond
              [(unsafe-fx<= next-offset (pvector-append-stream-pos st))
               (chunk-loop (unsafe-fx+ chunk-pos 1) next-offset acc)]
              [else
               (let elem-loop ([elem-pos
                                 (if (unsafe-fx<= (pvector-append-stream-pos st)
                                                  offset)
                                     0
                                     (unsafe-fx- (pvector-append-stream-pos st)
                                                offset))]
                                [acc acc])
                 (if (unsafe-fx= elem-pos end-pos)
                     (chunk-loop (unsafe-fx+ chunk-pos 1) next-offset acc)
                     (elem-loop (unsafe-fx+ elem-pos 1)
                                (cons (unsafe-vector-ref chunk elem-pos)
                                      acc))))]))))))

(define (pvector-append-stream-count f st)
  (let ([chunks ((vector-ref (pvector-append-stream-procs st) 12)
                 (pvector-append-stream-s st))]
        [len (pvector-append-stream-len st)])
    (+ (let chunk-loop ([chunk-pos 0] [offset 0] [count 0])
         (if (or (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
                 (unsafe-fx>= offset len))
             count
             (let* ([chunk (unsafe-vector-ref chunks chunk-pos)]
                    [chunk-len (unsafe-vector-length chunk)]
                    [next-offset (unsafe-fx+ offset chunk-len)]
                    [end-pos (if (unsafe-fx< len next-offset)
                                 (unsafe-fx- len offset)
                                 chunk-len)])
               (cond
                 [(unsafe-fx<= next-offset (pvector-append-stream-pos st))
                  (chunk-loop (unsafe-fx+ chunk-pos 1) next-offset count)]
                 [else
                  (let elem-loop ([elem-pos
                                    (if (unsafe-fx<=
                                         (pvector-append-stream-pos st)
                                         offset)
                                        0
                                        (unsafe-fx-
                                         (pvector-append-stream-pos st)
                                         offset))]
                                   [count count])
                    (if (unsafe-fx= elem-pos end-pos)
                        (chunk-loop (unsafe-fx+ chunk-pos 1)
                                    next-offset
                                    count)
                        (elem-loop (unsafe-fx+ elem-pos 1)
                                   (if (f (unsafe-vector-ref chunk elem-pos))
                                       (unsafe-fx+ count 1)
                                       count))))]))))
       (stream-count f (pvector-append-stream-tail st)))))

(define (pvector-append-stream-for-each f st)
  (let ([chunks ((vector-ref (pvector-append-stream-procs st) 12)
                 (pvector-append-stream-s st))]
        [len (pvector-append-stream-len st)])
    (let chunk-loop ([chunk-pos 0] [offset 0])
      (cond
        [(or (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
             (unsafe-fx>= offset len))
         (stream-for-each f (pvector-append-stream-tail st))]
        [else
         (let* ([chunk (unsafe-vector-ref chunks chunk-pos)]
                [chunk-len (unsafe-vector-length chunk)]
                [next-offset (unsafe-fx+ offset chunk-len)]
                [end-pos (if (unsafe-fx< len next-offset)
                             (unsafe-fx- len offset)
                             chunk-len)])
           (cond
             [(unsafe-fx<= next-offset (pvector-append-stream-pos st))
              (chunk-loop (unsafe-fx+ chunk-pos 1) next-offset)]
             [else
              (let elem-loop ([elem-pos
                                (if (unsafe-fx<=
                                     (pvector-append-stream-pos st)
                                     offset)
                                    0
                                    (unsafe-fx-
                                     (pvector-append-stream-pos st)
                                     offset))])
                (cond
                  [(unsafe-fx= elem-pos end-pos)
                   (chunk-loop (unsafe-fx+ chunk-pos 1) next-offset)]
                  [else
                   (f (unsafe-vector-ref chunk elem-pos))
                   (elem-loop (unsafe-fx+ elem-pos 1))]))]))]))))

(define (pvector-append-stream-fold f init st)
  (let ([chunks ((vector-ref (pvector-append-stream-procs st) 12)
                 (pvector-append-stream-s st))]
        [len (pvector-append-stream-len st)])
    (let chunk-loop ([chunk-pos 0] [offset 0] [acc init])
      (if (or (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
              (unsafe-fx>= offset len))
          (stream-fold f acc (pvector-append-stream-tail st))
          (let* ([chunk (unsafe-vector-ref chunks chunk-pos)]
                 [chunk-len (unsafe-vector-length chunk)]
                 [next-offset (unsafe-fx+ offset chunk-len)]
                 [end-pos (if (unsafe-fx< len next-offset)
                              (unsafe-fx- len offset)
                              chunk-len)])
            (cond
              [(unsafe-fx<= next-offset (pvector-append-stream-pos st))
               (chunk-loop (unsafe-fx+ chunk-pos 1) next-offset acc)]
              [else
               (let elem-loop ([elem-pos
                                 (if (unsafe-fx<=
                                      (pvector-append-stream-pos st)
                                      offset)
                                     0
                                     (unsafe-fx-
                                      (pvector-append-stream-pos st)
                                      offset))]
                                [acc acc])
                 (if (unsafe-fx= elem-pos end-pos)
                     (chunk-loop (unsafe-fx+ chunk-pos 1) next-offset acc)
                     (elem-loop (unsafe-fx+ elem-pos 1)
                                (f acc
                                   (unsafe-vector-ref chunk
                                                      elem-pos)))))]))))))

(define (stream-append . l)
  (for ([s (in-list l)])
    (unless (stream? s) (raise-argument-error 'stream-append "stream?" s)))
  (or (and (pair? l)
           (pvector-stream-append l))
      (and (pair? l)
           (pvector-stream-append-prefix l))
      (stream-lazy (streams-append l))))

(define (streams-append l)
  (cond
   [(null? l) empty-stream]
   [(null? (cdr l)) (car l)]
   [(stream-empty? (car l)) (streams-append (cdr l))]
   [else
    (stream-cons (stream-first (car l))
                 (streams-append (cons (stream-rest (car l)) (cdr l))))]))

(define (pvector-stream-map f s procs)
  (cond
    [(eq? f values) s]
    [else
     (let ([len ((vector-ref procs 14) s)])
       (if (unsafe-fx= len 0)
           ((vector-ref procs 6))
           ((vector-ref procs 13) len (void))))]))

(struct pvector-map-stream (f s pos len procs)
  #:property prop:stream
  (vector
   (lambda (st)
     (unsafe-fx>= (pvector-map-stream-pos st)
                  (pvector-map-stream-len st)))
   (lambda (st)
     ((pvector-map-stream-f st)
      ((vector-ref (pvector-map-stream-procs st) 15)
       (pvector-map-stream-s st)
       (pvector-map-stream-pos st))))
   (lambda (st)
     (let ([pos (unsafe-fx+ (pvector-map-stream-pos st) 1)]
           [len (pvector-map-stream-len st)])
       (if (unsafe-fx>= pos len)
           empty-stream
           (pvector-map-stream (pvector-map-stream-f st)
                               (pvector-map-stream-s st)
                               pos
                               len
                               (pvector-map-stream-procs st)))))))

(define (pvector-stream-map/lazy f s procs)
  (let ([len ((vector-ref procs 14) s)])
    (if (unsafe-fx= len 0)
        empty-stream
        (pvector-map-stream f s 0 len procs))))

(define (pvector-map-stream-length st)
  (unsafe-fx- (pvector-map-stream-len st)
              (pvector-map-stream-pos st)))

(define (pvector-map-stream-ref st i)
  (let ([len (pvector-map-stream-length st)])
    (if (< i len)
        ((pvector-map-stream-f st)
         ((vector-ref (pvector-map-stream-procs st) 15)
          (pvector-map-stream-s st)
          (unsafe-fx+ (pvector-map-stream-pos st) i)))
        (raise-stream-ended-before-index 'stream-ref i))))

(define (pvector-map-stream-tail st i)
  (let ([len (pvector-map-stream-length st)])
    (cond
      [(< i len)
       (pvector-map-stream
        (pvector-map-stream-f st)
        (pvector-map-stream-s st)
        (unsafe-fx+ (pvector-map-stream-pos st) i)
        (pvector-map-stream-len st)
        (pvector-map-stream-procs st))]
      [(= i len) empty-stream]
      [else (raise-stream-ended-before-index 'stream-tail i)])))

(define (pvector-map-stream-take st i)
  (let ([len (pvector-map-stream-length st)])
    (if (<= i len)
        (pvector-map-stream
         (pvector-map-stream-f st)
         (pvector-map-stream-s st)
         (pvector-map-stream-pos st)
         (+ (pvector-map-stream-pos st) i)
         (pvector-map-stream-procs st))
        (stream-take/slow st i))))

(define (pvector-map-stream->list st)
  (let ([f (pvector-map-stream-f st)]
        [s (pvector-map-stream-s st)]
        [len (pvector-map-stream-len st)]
        [chunks ((vector-ref (pvector-map-stream-procs st) 12)
                 (pvector-map-stream-s st))])
    (let chunk-loop ([chunk-pos 0] [offset 0] [acc null])
      (if (or (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
              (unsafe-fx>= offset len))
          (reverse acc)
          (let* ([chunk (unsafe-vector-ref chunks chunk-pos)]
                 [chunk-len (unsafe-vector-length chunk)]
                 [next-offset (unsafe-fx+ offset chunk-len)]
                 [end-pos (if (unsafe-fx< len next-offset)
                              (unsafe-fx- len offset)
                              chunk-len)])
            (cond
              [(unsafe-fx<= next-offset (pvector-map-stream-pos st))
               (chunk-loop (unsafe-fx+ chunk-pos 1) next-offset acc)]
              [else
               (let elem-loop ([elem-pos
                                 (if (unsafe-fx<= (pvector-map-stream-pos st)
                                                  offset)
                                     0
                                     (unsafe-fx- (pvector-map-stream-pos st)
                                                offset))]
                                [acc acc])
                 (if (unsafe-fx= elem-pos end-pos)
                     (chunk-loop (unsafe-fx+ chunk-pos 1) next-offset acc)
                     (elem-loop (unsafe-fx+ elem-pos 1)
                                (cons (f (unsafe-vector-ref chunk elem-pos))
                                      acc))))]))))))

(define (pvector-map-stream-count f st)
  (let ([map-f (pvector-map-stream-f st)]
        [len (pvector-map-stream-len st)]
        [chunks ((vector-ref (pvector-map-stream-procs st) 12)
                 (pvector-map-stream-s st))])
    (let chunk-loop ([chunk-pos 0] [offset 0] [count 0])
      (if (or (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
              (unsafe-fx>= offset len))
          count
          (let* ([chunk (unsafe-vector-ref chunks chunk-pos)]
                 [chunk-len (unsafe-vector-length chunk)]
                 [next-offset (unsafe-fx+ offset chunk-len)]
                 [end-pos (if (unsafe-fx< len next-offset)
                              (unsafe-fx- len offset)
                              chunk-len)])
            (cond
              [(unsafe-fx<= next-offset (pvector-map-stream-pos st))
               (chunk-loop (unsafe-fx+ chunk-pos 1) next-offset count)]
              [else
               (let elem-loop ([elem-pos
                                 (if (unsafe-fx<= (pvector-map-stream-pos st)
                                                  offset)
                                     0
                                     (unsafe-fx- (pvector-map-stream-pos st)
                                                offset))]
                                [count count])
                 (if (unsafe-fx= elem-pos end-pos)
                     (chunk-loop (unsafe-fx+ chunk-pos 1) next-offset count)
                     (elem-loop
                      (unsafe-fx+ elem-pos 1)
                      (if (call-with-values
                              (lambda ()
                                (map-f (unsafe-vector-ref chunk elem-pos)))
                            f)
                          (unsafe-fx+ count 1)
                          count))))]))))))

(define (pvector-map-stream-for-each f st)
  (let ([map-f (pvector-map-stream-f st)]
        [len (pvector-map-stream-len st)]
        [chunks ((vector-ref (pvector-map-stream-procs st) 12)
                 (pvector-map-stream-s st))])
    (let chunk-loop ([chunk-pos 0] [offset 0])
      (unless (or (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
                  (unsafe-fx>= offset len))
        (let* ([chunk (unsafe-vector-ref chunks chunk-pos)]
               [chunk-len (unsafe-vector-length chunk)]
               [next-offset (unsafe-fx+ offset chunk-len)]
               [end-pos (if (unsafe-fx< len next-offset)
                            (unsafe-fx- len offset)
                            chunk-len)])
          (cond
            [(unsafe-fx<= next-offset (pvector-map-stream-pos st))
             (chunk-loop (unsafe-fx+ chunk-pos 1) next-offset)]
            [else
             (let elem-loop ([elem-pos
                               (if (unsafe-fx<= (pvector-map-stream-pos st)
                                                offset)
                                   0
                                   (unsafe-fx- (pvector-map-stream-pos st)
                                              offset))])
               (unless (unsafe-fx= elem-pos end-pos)
                 (call-with-values
                  (lambda ()
                    (map-f (unsafe-vector-ref chunk elem-pos)))
                  (case-lambda
                    [(v) (f v)]
                    [vs (apply f vs)]))
                 (elem-loop (unsafe-fx+ elem-pos 1))))
             (chunk-loop (unsafe-fx+ chunk-pos 1) next-offset)]))))))

(define (pvector-map-stream-fold f init st)
  (let ([map-f (pvector-map-stream-f st)]
        [len (pvector-map-stream-len st)]
        [chunks ((vector-ref (pvector-map-stream-procs st) 12)
                 (pvector-map-stream-s st))])
    (let chunk-loop ([chunk-pos 0] [offset 0] [acc init])
      (if (or (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
              (unsafe-fx>= offset len))
          acc
          (let* ([chunk (unsafe-vector-ref chunks chunk-pos)]
                 [chunk-len (unsafe-vector-length chunk)]
                 [next-offset (unsafe-fx+ offset chunk-len)]
                 [end-pos (if (unsafe-fx< len next-offset)
                              (unsafe-fx- len offset)
                              chunk-len)])
            (cond
              [(unsafe-fx<= next-offset (pvector-map-stream-pos st))
               (chunk-loop (unsafe-fx+ chunk-pos 1) next-offset acc)]
              [else
               (let elem-loop ([elem-pos
                                 (if (unsafe-fx<= (pvector-map-stream-pos st)
                                                  offset)
                                     0
                                     (unsafe-fx- (pvector-map-stream-pos st)
                                                offset))]
                                [acc acc])
                 (if (unsafe-fx= elem-pos end-pos)
                     (chunk-loop (unsafe-fx+ chunk-pos 1) next-offset acc)
                     (elem-loop
                      (unsafe-fx+ elem-pos 1)
                      (call-with-values
                       (lambda ()
                         (map-f (unsafe-vector-ref chunk elem-pos)))
                       (case-lambda
                         [(v) (f acc v)]
                         [vs (apply f acc vs)])))))]))))))

(struct pvector-filter-stream (f s pos len procs state)
  #:property prop:stream
  (vector
   (lambda (st)
     (not (pvector-filter-stream-force! st)))
   (lambda (st)
     (let ([pos (pvector-filter-stream-force! st)])
       ((vector-ref (pvector-filter-stream-procs st) 15)
        (pvector-filter-stream-s st)
        pos)))
   (lambda (st)
     (let ([pos (pvector-filter-stream-force! st)])
       (if pos
           (let ([next-pos (unsafe-fx+ pos 1)]
                 [len (pvector-filter-stream-len st)])
             (if (unsafe-fx>= next-pos len)
                 empty-stream
                 (pvector-filter-stream
                  (pvector-filter-stream-f st)
                  (pvector-filter-stream-s st)
                  next-pos
                  len
                  (pvector-filter-stream-procs st)
                  (vector 0 #f))))
           empty-stream)))))

(define (pvector-filter-stream-force! st)
  (let ([state (pvector-filter-stream-state st)])
    (cond
      [(unsafe-fx= (unsafe-vector-ref state 0) 1)
       (unsafe-vector-ref state 1)]
      [(unsafe-fx= (unsafe-vector-ref state 0) 2)
       #f]
      [else
       (let ([f (pvector-filter-stream-f st)]
             [s (pvector-filter-stream-s st)]
             [len (pvector-filter-stream-len st)]
             [ref (vector-ref (pvector-filter-stream-procs st) 15)])
         (let loop ([pos (pvector-filter-stream-pos st)])
           (cond
             [(unsafe-fx>= pos len)
              (unsafe-vector-set! state 0 2)
              #f]
             [(f (ref s pos))
              (unsafe-vector-set! state 0 1)
              (unsafe-vector-set! state 1 pos)
              pos]
             [else
              (loop (unsafe-fx+ pos 1))])))])))

(define (pvector-stream-filter/lazy f s procs)
  (let ([len ((vector-ref procs 14) s)])
    (if (unsafe-fx= len 0)
        empty-stream
        (pvector-filter-stream f s 0 len procs (vector 0 #f)))))

(define (pvector-filter-stream-rest-after st pos)
  (let ([next-pos (unsafe-fx+ pos 1)]
        [len (pvector-filter-stream-len st)])
    (if (unsafe-fx>= next-pos len)
        empty-stream
        (pvector-filter-stream
         (pvector-filter-stream-f st)
         (pvector-filter-stream-s st)
         next-pos
         len
         (pvector-filter-stream-procs st)
         (vector 0 #f)))))

(define (pvector-filter-stream-length st)
  (let ([pos (pvector-filter-stream-force! st)])
    (if pos
        (let ([f (pvector-filter-stream-f st)]
              [s (pvector-filter-stream-s st)]
              [procs (pvector-filter-stream-procs st)])
          (let ([chunks ((vector-ref procs 12) s)]
                [start (unsafe-fx+ pos 1)])
            (let chunk-loop ([chunk-pos 0] [offset 0] [count 1])
              (if (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
                  count
                  (let* ([chunk (unsafe-vector-ref chunks chunk-pos)]
                         [chunk-len (unsafe-vector-length chunk)]
                         [next-offset (unsafe-fx+ offset chunk-len)])
                    (cond
                      [(unsafe-fx<= next-offset start)
                       (chunk-loop (unsafe-fx+ chunk-pos 1)
                                   next-offset
                                   count)]
                      [else
                       (let elem-loop ([elem-pos
                                         (if (unsafe-fx<= start offset)
                                             0
                                             (unsafe-fx- start offset))]
                                        [count count])
                         (if (unsafe-fx= elem-pos chunk-len)
                             (chunk-loop (unsafe-fx+ chunk-pos 1)
                                         next-offset
                                         count)
                             (elem-loop (unsafe-fx+ elem-pos 1)
                                        (if (f (unsafe-vector-ref chunk elem-pos))
                                            (unsafe-fx+ count 1)
                                            count))))]))))))
        0)))

(define (pvector-filter-stream-ref st i)
  (let ((pos (pvector-filter-stream-force! st)))
    (cond
      ((not pos)
       (raise-stream-ended-before-index 'stream-ref i))
      ((zero? i)
       ((vector-ref (pvector-filter-stream-procs st) 15)
        (pvector-filter-stream-s st)
        pos))
      (else
       (let* ((f (pvector-filter-stream-f st))
              (s (pvector-filter-stream-s st))
              (procs (pvector-filter-stream-procs st))
              (start (unsafe-fx+ pos 1))
              (chunks ((vector-ref procs 12) s)))
         (let ((remaining i))
           (let/ec return
             (let chunk-loop ((chunk-pos 0) (offset 0))
               (unless (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
                 (let* ((chunk (unsafe-vector-ref chunks chunk-pos))
                        (chunk-len (unsafe-vector-length chunk))
                        (next-offset (unsafe-fx+ offset chunk-len)))
                   (unless (unsafe-fx<= next-offset start)
                     (let elem-loop ((elem-pos
                                      (if (unsafe-fx<= start offset)
                                          0
                                          (unsafe-fx- start offset))))
                       (unless (unsafe-fx= elem-pos chunk-len)
                         (let ((v (unsafe-vector-ref chunk elem-pos)))
                           (when (f v)
                             (if (= remaining 1)
                                 (return v)
                                 (set! remaining (sub1 remaining)))))
                         (elem-loop (unsafe-fx+ elem-pos 1)))))
                   (chunk-loop (unsafe-fx+ chunk-pos 1)
                               next-offset))))
             (raise-stream-ended-before-index 'stream-ref i))))))))

(define (pvector-filter-stream-tail-at st i)
  (let ((pos (pvector-filter-stream-force! st)))
    (cond
      ((not pos)
       (raise-stream-ended-before-index 'stream-tail i))
      ((= i 1)
       (pvector-filter-stream-rest-after st pos))
      (else
       (let* ((f (pvector-filter-stream-f st))
              (s (pvector-filter-stream-s st))
              (procs (pvector-filter-stream-procs st))
              (start (unsafe-fx+ pos 1))
              (chunks ((vector-ref procs 12) s)))
         (let ((remaining (sub1 i)))
           (let/ec return
             (let chunk-loop ((chunk-pos 0) (offset 0))
               (unless (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
                 (let* ((chunk (unsafe-vector-ref chunks chunk-pos))
                        (chunk-len (unsafe-vector-length chunk))
                        (next-offset (unsafe-fx+ offset chunk-len)))
                   (unless (unsafe-fx<= next-offset start)
                     (let elem-loop ((elem-pos
                                      (if (unsafe-fx<= start offset)
                                          0
                                          (unsafe-fx- start offset))))
                       (unless (unsafe-fx= elem-pos chunk-len)
                         (let ((v (unsafe-vector-ref chunk elem-pos)))
                           (when (f v)
                             (if (= remaining 1)
                                 (return
                                  (pvector-filter-stream-rest-after
                                   st
                                   (unsafe-fx+ offset elem-pos)))
                                 (set! remaining (sub1 remaining)))))
                         (elem-loop (unsafe-fx+ elem-pos 1)))))
                   (chunk-loop (unsafe-fx+ chunk-pos 1)
                               next-offset))))
             (raise-stream-ended-before-index 'stream-tail i))))))))

(define (pvector-filter-stream-take st i)
  (cond
    [(zero? i) empty-stream]
    [(fixnum? i) (pvector-filter-take-stream st i i)]
    [else (stream-take/slow st i)]))

(struct pvector-filter-take-stream (s remaining index)
  #:property prop:stream
  (vector
   (lambda (st)
     (cond
       [(unsafe-fx= (pvector-filter-take-stream-remaining st) 0) #t]
       [(stream-empty? (pvector-filter-take-stream-s st))
        (raise-stream-ended-before-index
         'stream-take
         (pvector-filter-take-stream-index st))]
       [else #f]))
   (lambda (st)
     (stream-first (pvector-filter-take-stream-s st)))
   (lambda (st)
     (let ([remaining (unsafe-fx- (pvector-filter-take-stream-remaining st) 1)])
       (if (unsafe-fx= remaining 0)
           empty-stream
           (pvector-filter-take-stream
            (stream-rest (pvector-filter-take-stream-s st))
            remaining
            (pvector-filter-take-stream-index st)))))))

(define (pvector-filter-take-stream->list st)
  (let ([s (pvector-filter-take-stream-s st)]
        [remaining (pvector-filter-take-stream-remaining st)])
    (cond
      [(unsafe-fx= remaining 0) null]
      [(pvector-filter-stream? s)
       (let ([pos (pvector-filter-stream-force! s)])
         (if pos
             (let ([f (pvector-filter-stream-f s)]
                   [source (pvector-filter-stream-s s)]
                   [procs (pvector-filter-stream-procs s)])
               (let ([first ((vector-ref procs 15) source pos)])
                 (if (unsafe-fx= remaining 1)
                     (list first)
                     (let ([chunks ((vector-ref procs 12) source)]
                           [start (unsafe-fx+ pos 1)])
                       (let/ec return
                         (let chunk-loop ([chunk-pos 0]
                                          [offset 0]
                                          [remaining (unsafe-fx- remaining 1)]
                                          [acc (list first)])
                           (if (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
                               (raise-stream-ended-before-index
                                'stream-take
                                (pvector-filter-take-stream-index st))
                               (let* ([chunk (unsafe-vector-ref chunks chunk-pos)]
                                      [chunk-len (unsafe-vector-length chunk)]
                                      [next-offset (unsafe-fx+ offset chunk-len)])
                                 (cond
                                   [(unsafe-fx<= next-offset start)
                                    (chunk-loop (unsafe-fx+ chunk-pos 1)
                                                next-offset
                                                remaining
                                                acc)]
                                   [else
                                    (let elem-loop ([elem-pos
                                                      (if (unsafe-fx<= start
                                                                       offset)
                                                          0
                                                          (unsafe-fx- start
                                                                     offset))]
                                                     [remaining remaining]
                                                     [acc acc])
                                      (cond
                                        [(unsafe-fx= elem-pos chunk-len)
                                         (chunk-loop (unsafe-fx+ chunk-pos 1)
                                                     next-offset
                                                     remaining
                                                     acc)]
                                        [else
                                         (let ([v (unsafe-vector-ref chunk
                                                                     elem-pos)])
                                           (cond
                                             [(f v)
                                              (if (unsafe-fx= remaining 1)
                                                  (return
                                                   (reverse (cons v acc)))
                                                  (elem-loop
                                                   (unsafe-fx+ elem-pos 1)
                                                   (unsafe-fx- remaining 1)
                                                   (cons v acc)))]
                                             [else
                                              (elem-loop
                                               (unsafe-fx+ elem-pos 1)
                                               remaining
                                               acc)]))]))])))))))))
             (raise-stream-ended-before-index
              'stream-take
              (pvector-filter-take-stream-index st))))]
      [else
       (let loop ([s s] [remaining remaining] [acc null])
         (cond
           [(unsafe-fx= remaining 0)
            (reverse acc)]
           [(stream-empty? s)
            (raise-stream-ended-before-index
             'stream-take
             (pvector-filter-take-stream-index st))]
           [else
            (let ([v (stream-first s)])
              (loop (stream-rest s)
                    (unsafe-fx- remaining 1)
                    (cons v acc)))]))])))

(define (pvector-filter-stream-count f st)
  (let ([pos (pvector-filter-stream-force! st)])
    (if pos
        (let ([filter-f (pvector-filter-stream-f st)]
              [s (pvector-filter-stream-s st)]
              [procs (pvector-filter-stream-procs st)])
          (let* ([first ((vector-ref procs 15) s pos)]
                 [count (if (f first) 1 0)]
                 [chunks ((vector-ref procs 12) s)]
                 [start (unsafe-fx+ pos 1)])
            (let chunk-loop ([chunk-pos 0] [offset 0] [count count])
              (if (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
                  count
                  (let* ([chunk (unsafe-vector-ref chunks chunk-pos)]
                         [chunk-len (unsafe-vector-length chunk)]
                         [next-offset (unsafe-fx+ offset chunk-len)])
                    (cond
                      [(unsafe-fx<= next-offset start)
                       (chunk-loop (unsafe-fx+ chunk-pos 1)
                                   next-offset
                                   count)]
                      [else
                       (let elem-loop ([elem-pos
                                         (if (unsafe-fx<= start offset)
                                             0
                                             (unsafe-fx- start offset))]
                                        [count count])
                         (if (unsafe-fx= elem-pos chunk-len)
                             (chunk-loop (unsafe-fx+ chunk-pos 1)
                                         next-offset
                                         count)
                             (let ([v (unsafe-vector-ref chunk elem-pos)])
                               (elem-loop
                                (unsafe-fx+ elem-pos 1)
                                (if (and (filter-f v) (f v))
                                    (unsafe-fx+ count 1)
                                    count)))))]))))))
        0)))

(define (pvector-filter-stream-for-each f st)
  (let ([pos (pvector-filter-stream-force! st)])
    (when pos
      (let ([filter-f (pvector-filter-stream-f st)]
            [s (pvector-filter-stream-s st)]
            [procs (pvector-filter-stream-procs st)])
        (f ((vector-ref procs 15) s pos))
        (let ([chunks ((vector-ref procs 12) s)]
              [start (unsafe-fx+ pos 1)])
          (let chunk-loop ([chunk-pos 0] [offset 0])
            (unless (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
              (let* ([chunk (unsafe-vector-ref chunks chunk-pos)]
                     [chunk-len (unsafe-vector-length chunk)]
                     [next-offset (unsafe-fx+ offset chunk-len)])
                (cond
                  [(unsafe-fx<= next-offset start)
                   (chunk-loop (unsafe-fx+ chunk-pos 1)
                               next-offset)]
                  [else
                   (let elem-loop ([elem-pos
                                     (if (unsafe-fx<= start offset)
                                         0
                                         (unsafe-fx- start offset))])
                     (unless (unsafe-fx= elem-pos chunk-len)
                       (let ([v (unsafe-vector-ref chunk elem-pos)])
                         (when (filter-f v) (f v)))
                       (elem-loop (unsafe-fx+ elem-pos 1))))
                   (chunk-loop (unsafe-fx+ chunk-pos 1)
                               next-offset)])))))))))

(define (pvector-filter-stream-fold f init st)
  (let ([pos (pvector-filter-stream-force! st)])
    (if pos
        (let ([filter-f (pvector-filter-stream-f st)]
              [s (pvector-filter-stream-s st)]
              [procs (pvector-filter-stream-procs st)])
          (let* ([first ((vector-ref procs 15) s pos)]
                 [acc (f init first)]
                 [chunks ((vector-ref procs 12) s)]
                 [start (unsafe-fx+ pos 1)])
            (let chunk-loop ([chunk-pos 0] [offset 0] [acc acc])
              (if (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
                  acc
                  (let* ([chunk (unsafe-vector-ref chunks chunk-pos)]
                         [chunk-len (unsafe-vector-length chunk)]
                         [next-offset (unsafe-fx+ offset chunk-len)])
                    (cond
                      [(unsafe-fx<= next-offset start)
                       (chunk-loop (unsafe-fx+ chunk-pos 1)
                                   next-offset
                                   acc)]
                      [else
                       (let elem-loop ([elem-pos
                                         (if (unsafe-fx<= start offset)
                                             0
                                             (unsafe-fx- start offset))]
                                        [acc acc])
                         (if (unsafe-fx= elem-pos chunk-len)
                             (chunk-loop (unsafe-fx+ chunk-pos 1)
                                         next-offset
                                         acc)
                             (let ([v (unsafe-vector-ref chunk elem-pos)])
                               (elem-loop
                                (unsafe-fx+ elem-pos 1)
                                (if (filter-f v) (f acc v) acc)))))]))))))
        init)))

(define (pvector-filter-take-stream-count f st)
  (let ([s (pvector-filter-take-stream-s st)]
        [remaining (pvector-filter-take-stream-remaining st)])
    (cond
      [(unsafe-fx= remaining 0) 0]
      [(pvector-filter-stream? s)
       (let ([pos (pvector-filter-stream-force! s)])
         (if pos
             (let ([filter-f (pvector-filter-stream-f s)]
                   [source (pvector-filter-stream-s s)]
                   [procs (pvector-filter-stream-procs s)])
               (let* ([first ((vector-ref procs 15) source pos)]
                      [count (if (f first) 1 0)])
                 (if (unsafe-fx= remaining 1)
                     count
                     (let ([chunks ((vector-ref procs 12) source)]
                           [start (unsafe-fx+ pos 1)])
                       (let/ec return
                         (let chunk-loop ([chunk-pos 0]
                                          [offset 0]
                                          [remaining (unsafe-fx- remaining 1)]
                                          [count count])
                           (if (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
                               (raise-stream-ended-before-index
                                'stream-take
                                (pvector-filter-take-stream-index st))
                               (let* ([chunk (unsafe-vector-ref chunks chunk-pos)]
                                      [chunk-len (unsafe-vector-length chunk)]
                                      [next-offset (unsafe-fx+ offset chunk-len)])
                                 (cond
                                   [(unsafe-fx<= next-offset start)
                                    (chunk-loop (unsafe-fx+ chunk-pos 1)
                                                next-offset
                                                remaining
                                                count)]
                                   [else
                                    (let elem-loop ([elem-pos
                                                      (if (unsafe-fx<= start
                                                                       offset)
                                                          0
                                                          (unsafe-fx- start
                                                                     offset))]
                                                     [remaining remaining]
                                                     [count count])
                                      (cond
                                        [(unsafe-fx= elem-pos chunk-len)
                                         (chunk-loop (unsafe-fx+ chunk-pos 1)
                                                     next-offset
                                                     remaining
                                                     count)]
                                        [else
                                         (let ([v (unsafe-vector-ref chunk
                                                                     elem-pos)])
                                           (cond
                                             [(filter-f v)
                                              (let ([count (if (f v)
                                                               (unsafe-fx+
                                                                count
                                                                1)
                                                               count)])
                                                (if (unsafe-fx= remaining 1)
                                                    (return count)
                                                    (elem-loop
                                                     (unsafe-fx+ elem-pos 1)
                                                     (unsafe-fx- remaining 1)
                                                     count)))]
                                             [else
                                              (elem-loop
                                               (unsafe-fx+ elem-pos 1)
                                               remaining
                                               count)]))]))])))))))))
             (raise-stream-ended-before-index
              'stream-take
              (pvector-filter-take-stream-index st))))]
      [else
       (let loop ([s s] [remaining remaining] [count 0])
         (cond
           [(unsafe-fx= remaining 0) count]
           [(stream-empty? s)
            (raise-stream-ended-before-index
             'stream-take
             (pvector-filter-take-stream-index st))]
           [else
            (loop (stream-rest s)
                  (unsafe-fx- remaining 1)
                  (if (call-with-values (lambda () (stream-first s)) f)
                      (unsafe-fx+ count 1)
                      count))]))])))

(define (pvector-filter-take-stream-for-each f st)
  (let ([s (pvector-filter-take-stream-s st)]
        [remaining (pvector-filter-take-stream-remaining st)])
    (cond
      [(unsafe-fx= remaining 0) (void)]
      [(pvector-filter-stream? s)
       (let ([pos (pvector-filter-stream-force! s)])
         (if pos
             (let ([filter-f (pvector-filter-stream-f s)]
                   [source (pvector-filter-stream-s s)]
                   [procs (pvector-filter-stream-procs s)])
               (f ((vector-ref procs 15) source pos))
               (unless (unsafe-fx= remaining 1)
                 (let ([chunks ((vector-ref procs 12) source)]
                       [start (unsafe-fx+ pos 1)])
                   (let/ec return
                     (let chunk-loop ([chunk-pos 0]
                                      [offset 0]
                                      [remaining (unsafe-fx- remaining 1)])
                       (if (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
                           (raise-stream-ended-before-index
                            'stream-take
                            (pvector-filter-take-stream-index st))
                           (let* ([chunk (unsafe-vector-ref chunks chunk-pos)]
                                  [chunk-len (unsafe-vector-length chunk)]
                                  [next-offset (unsafe-fx+ offset chunk-len)])
                             (cond
                               [(unsafe-fx<= next-offset start)
                                (chunk-loop (unsafe-fx+ chunk-pos 1)
                                            next-offset
                                            remaining)]
                               [else
                                (let elem-loop ([elem-pos
                                                  (if (unsafe-fx<= start
                                                                   offset)
                                                      0
                                                      (unsafe-fx- start
                                                                 offset))]
                                                 [remaining remaining])
                                  (cond
                                    [(unsafe-fx= elem-pos chunk-len)
                                     (chunk-loop (unsafe-fx+ chunk-pos 1)
                                                 next-offset
                                                 remaining)]
                                    [else
                                     (let ([v (unsafe-vector-ref chunk
                                                                 elem-pos)])
                                       (cond
                                         [(filter-f v)
                                          (f v)
                                          (if (unsafe-fx= remaining 1)
                                              (return (void))
                                              (elem-loop
                                               (unsafe-fx+ elem-pos 1)
                                               (unsafe-fx- remaining 1)))]
                                         [else
                                          (elem-loop
                                           (unsafe-fx+ elem-pos 1)
                                           remaining)]))]))]))))))))
             (raise-stream-ended-before-index
              'stream-take
              (pvector-filter-take-stream-index st))))]
      [else
       (let loop ([s s] [remaining remaining])
         (cond
           [(unsafe-fx= remaining 0) (void)]
           [(stream-empty? s)
            (raise-stream-ended-before-index
             'stream-take
             (pvector-filter-take-stream-index st))]
           [else
            (f (stream-first s))
            (loop (stream-rest s)
                  (unsafe-fx- remaining 1))]))])))

(define (pvector-filter-take-stream-fold f init st)
  (let ([s (pvector-filter-take-stream-s st)]
        [remaining (pvector-filter-take-stream-remaining st)])
    (cond
      [(unsafe-fx= remaining 0) init]
      [(pvector-filter-stream? s)
       (let ([pos (pvector-filter-stream-force! s)])
         (if pos
             (let ([filter-f (pvector-filter-stream-f s)]
                   [source (pvector-filter-stream-s s)]
                   [procs (pvector-filter-stream-procs s)])
               (let* ([first ((vector-ref procs 15) source pos)]
                      [acc (f init first)])
                 (if (unsafe-fx= remaining 1)
                     acc
                     (let ([chunks ((vector-ref procs 12) source)]
                           [start (unsafe-fx+ pos 1)])
                       (let/ec return
                         (let chunk-loop ([chunk-pos 0]
                                          [offset 0]
                                          [remaining (unsafe-fx- remaining 1)]
                                          [acc acc])
                           (if (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
                               (raise-stream-ended-before-index
                                'stream-take
                                (pvector-filter-take-stream-index st))
                               (let* ([chunk (unsafe-vector-ref chunks chunk-pos)]
                                      [chunk-len (unsafe-vector-length chunk)]
                                      [next-offset (unsafe-fx+ offset chunk-len)])
                                 (cond
                                   [(unsafe-fx<= next-offset start)
                                    (chunk-loop (unsafe-fx+ chunk-pos 1)
                                                next-offset
                                                remaining
                                                acc)]
                                   [else
                                    (let elem-loop ([elem-pos
                                                      (if (unsafe-fx<= start
                                                                       offset)
                                                          0
                                                          (unsafe-fx- start
                                                                     offset))]
                                                     [remaining remaining]
                                                     [acc acc])
                                      (cond
                                        [(unsafe-fx= elem-pos chunk-len)
                                         (chunk-loop (unsafe-fx+ chunk-pos 1)
                                                     next-offset
                                                     remaining
                                                     acc)]
                                        [else
                                         (let ([v (unsafe-vector-ref chunk
                                                                     elem-pos)])
                                           (cond
                                             [(filter-f v)
                                              (let ([acc (f acc v)])
                                                (if (unsafe-fx= remaining 1)
                                                    (return acc)
                                                    (elem-loop
                                                     (unsafe-fx+ elem-pos 1)
                                                     (unsafe-fx- remaining 1)
                                                     acc)))]
                                             [else
                                              (elem-loop
                                               (unsafe-fx+ elem-pos 1)
                                               remaining
                                               acc)]))]))])))))))))
             (raise-stream-ended-before-index
              'stream-take
              (pvector-filter-take-stream-index st))))]
      [else
       (let loop ([s s] [remaining remaining] [acc init])
         (cond
           [(unsafe-fx= remaining 0) acc]
           [(stream-empty? s)
            (raise-stream-ended-before-index
             'stream-take
             (pvector-filter-take-stream-index st))]
           [else
            (loop (stream-rest s)
                  (unsafe-fx- remaining 1)
                  (call-with-values
                   (lambda () (stream-first s))
                   (case-lambda
                     [(v) (f acc v)]
                     [vs (apply f acc vs)])))]))])))

(define (pvector-filter-stream->list st)
  (let ([pos (pvector-filter-stream-force! st)])
    (if pos
        (let ([f (pvector-filter-stream-f st)]
              [s (pvector-filter-stream-s st)]
              [len (pvector-filter-stream-len st)]
              [procs (pvector-filter-stream-procs st)])
          (let ([chunks ((vector-ref procs 12) s)]
                [ref (vector-ref procs 15)]
                [start (unsafe-fx+ pos 1)])
            (let chunk-loop ([chunk-pos 0]
                             [offset 0]
                             [acc (list (ref s pos))])
              (if (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
                  (reverse acc)
                  (let* ([chunk (unsafe-vector-ref chunks chunk-pos)]
                         [chunk-len (unsafe-vector-length chunk)]
                         [next-offset (unsafe-fx+ offset chunk-len)])
                    (cond
                      [(unsafe-fx<= next-offset start)
                       (chunk-loop (unsafe-fx+ chunk-pos 1)
                                   next-offset
                                   acc)]
                      [else
                       (let elem-loop ([elem-pos
                                         (if (unsafe-fx<= start offset)
                                             0
                                             (unsafe-fx- start offset))]
                                        [acc acc])
                         (if (unsafe-fx= elem-pos chunk-len)
                             (chunk-loop (unsafe-fx+ chunk-pos 1)
                                         next-offset
                                         acc)
                             (let ([v (unsafe-vector-ref chunk elem-pos)])
                               (elem-loop (unsafe-fx+ elem-pos 1)
                                          (if (f v)
                                              (cons v acc)
                                              acc)))))]))))))
        null)))

(define (stream-map f s)
  (unless (procedure? f) (raise-argument-error 'stream-map "procedure?" f))
  (unless (stream? s) (raise-argument-error 'stream-map "stream?" s))
  (let ([procs (pvector-stream-procs-for s)])
    (if (and procs
             (or (eq? f values)
                 (eq? f void)))
        (pvector-stream-map f s procs)
        (if procs
            (pvector-stream-map/lazy f s procs)
            (stream-lazy
             (let loop ([s s])
               (cond
                 [(stream-empty? s) empty-stream]
                 [else (stream-cons (call-with-values (λ () (stream-first s)) f)
                                    (loop (stream-rest s)))])))))))

(define (pvector-stream-andmap f s procs)
  (let ([chunks ((vector-ref procs 12) s)])
    (let/ec return
      (let chunk-loop ([chunk-pos 0] [last #t])
        (if (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
            last
            (let ([chunk (unsafe-vector-ref chunks chunk-pos)])
              (let elem-loop ([elem-pos 0] [last last])
                (if (unsafe-fx= elem-pos (unsafe-vector-length chunk))
                    (chunk-loop (unsafe-fx+ chunk-pos 1) last)
                    (let ([v (f (unsafe-vector-ref chunk elem-pos))])
                      (if v
                          (elem-loop (unsafe-fx+ elem-pos 1) v)
                          (return #f)))))))))))

(define (pvector-stream-ormap f s procs)
  (let ([chunks ((vector-ref procs 12) s)])
    (let/ec return
      (let chunk-loop ([chunk-pos 0])
        (unless (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
          (let ([chunk (unsafe-vector-ref chunks chunk-pos)])
            (let elem-loop ([elem-pos 0])
              (cond
                [(unsafe-fx= elem-pos (unsafe-vector-length chunk))
                 (chunk-loop (unsafe-fx+ chunk-pos 1))]
                [else
                 (let ([v (f (unsafe-vector-ref chunk elem-pos))])
                   (if v
                       (return v)
                       (elem-loop (unsafe-fx+ elem-pos 1))))])))))
      #f)))

(define (pvector-stream-andmap-values s procs)
  (let ([chunks ((vector-ref procs 12) s)])
    (let/ec return
      (let chunk-loop ([chunk-pos 0] [last #t])
        (if (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
            last
            (let ([chunk (unsafe-vector-ref chunks chunk-pos)])
              (let elem-loop ([elem-pos 0] [last last])
                (if (unsafe-fx= elem-pos (unsafe-vector-length chunk))
                    (chunk-loop (unsafe-fx+ chunk-pos 1) last)
                    (let ([v (unsafe-vector-ref chunk elem-pos)])
                      (if v
                          (elem-loop (unsafe-fx+ elem-pos 1) v)
                          (return #f)))))))))))

(define (pvector-stream-ormap-values s procs)
  (let ([chunks ((vector-ref procs 12) s)])
    (let/ec return
      (let chunk-loop ([chunk-pos 0])
        (unless (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
          (let ([chunk (unsafe-vector-ref chunks chunk-pos)])
            (let elem-loop ([elem-pos 0])
              (cond
                [(unsafe-fx= elem-pos (unsafe-vector-length chunk))
                 (chunk-loop (unsafe-fx+ chunk-pos 1))]
                [else
                 (let ([v (unsafe-vector-ref chunk elem-pos)])
                   (if v
                       (return v)
                       (elem-loop (unsafe-fx+ elem-pos 1))))])))))
      #f)))

(define (pvector-stream-for-each/chunks f s procs)
  (let ([chunks ((vector-ref procs 12) s)])
    (let chunk-loop ([chunk-pos 0])
      (unless (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
        (let ([chunk (unsafe-vector-ref chunks chunk-pos)])
          (let elem-loop ([elem-pos 0])
            (unless (unsafe-fx= elem-pos (unsafe-vector-length chunk))
              (f (unsafe-vector-ref chunk elem-pos))
              (elem-loop (unsafe-fx+ elem-pos 1)))))
        (chunk-loop (unsafe-fx+ chunk-pos 1))))))

(define (pvector-stream-for-each f s procs)
  (let ([len ((vector-ref procs 14) s)])
    (cond
      [(zero? len) (void)]
      [(or (eq? f void)
           (eq? f values))
       (void)]
      [(procedure-arity-includes? f 1)
       ((vector-ref procs 10) s f)]
      [else
       (pvector-stream-for-each/chunks f s procs)])))

(define (pvector-stream-fold f init s procs)
  (let ([chunks ((vector-ref procs 12) s)])
    (let chunk-loop ([chunk-pos 0] [acc init])
      (if (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
          acc
          (let ([chunk (unsafe-vector-ref chunks chunk-pos)])
            (let elem-loop ([elem-pos 0] [acc acc])
              (if (unsafe-fx= elem-pos (unsafe-vector-length chunk))
                  (chunk-loop (unsafe-fx+ chunk-pos 1) acc)
                  (elem-loop (unsafe-fx+ elem-pos 1)
                             (f acc (unsafe-vector-ref chunk elem-pos))))))))))

(define (pvector-stream-count f s procs)
  (let ([chunks ((vector-ref procs 12) s)])
    (let chunk-loop ([chunk-pos 0] [count 0])
      (if (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
          count
          (let ([chunk (unsafe-vector-ref chunks chunk-pos)])
            (let elem-loop ([elem-pos 0] [count count])
              (cond
                [(unsafe-fx= elem-pos (unsafe-vector-length chunk))
                 (chunk-loop (unsafe-fx+ chunk-pos 1) count)]
                [(f (unsafe-vector-ref chunk elem-pos))
                 (elem-loop (unsafe-fx+ elem-pos 1) (unsafe-fx+ count 1))]
                [else
                 (elem-loop (unsafe-fx+ elem-pos 1) count)])))))))

(define (pvector-stream-count-values s procs)
  (let ([chunks ((vector-ref procs 12) s)])
    (let chunk-loop ([chunk-pos 0] [count 0])
      (if (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
          count
          (let ([chunk (unsafe-vector-ref chunks chunk-pos)])
            (let elem-loop ([elem-pos 0] [count count])
              (cond
                [(unsafe-fx= elem-pos (unsafe-vector-length chunk))
                 (chunk-loop (unsafe-fx+ chunk-pos 1) count)]
                [(unsafe-vector-ref chunk elem-pos)
                 (elem-loop (unsafe-fx+ elem-pos 1) (unsafe-fx+ count 1))]
                [else
                 (elem-loop (unsafe-fx+ elem-pos 1) count)])))))))

(define (pvector-backed-stream-andmap for-each f s)
  (let/ec return
    (let ([last #t])
      (for-each
       (case-lambda
         [(v)
          (let ([result (f v)])
            (if result
                (set! last result)
                (return #f)))]
         [vs
          (let ([result (apply f vs)])
            (if result
                (set! last result)
                (return #f)))])
       s)
      last)))

(define (pvector-backed-stream-ormap for-each f s)
  (let/ec return
    (for-each
     (case-lambda
       [(v)
        (let ([result (f v)])
          (when result (return result)))]
       [vs
        (let ([result (apply f vs)])
          (when result (return result)))])
     s)
    #f))

(define (stream-andmap f s)
  (unless (procedure? f) (raise-argument-error 'stream-andmap "procedure?" f))
  (unless (stream? s) (raise-argument-error 'stream-andmap "stream?" s))
  (cond
    [(pvector-map-stream? s)
     (pvector-backed-stream-andmap pvector-map-stream-for-each f s)]
    [(pvector-filter-stream? s)
     (pvector-backed-stream-andmap pvector-filter-stream-for-each f s)]
    [(pvector-filter-take-stream? s)
     (pvector-backed-stream-andmap pvector-filter-take-stream-for-each f s)]
    [(pvector-append-stream? s)
     (pvector-backed-stream-andmap pvector-append-stream-for-each f s)]
    [else
     (let ([procs (pvector-stream-procs-for s)])
       (cond
         [(and procs (eq? f void))
          (if (zero? ((vector-ref procs 14) s)) #t (void))]
         [(and procs (eq? f values))
          (pvector-stream-andmap-values s procs)]
         [procs
          (pvector-stream-andmap f s procs)]
         [else
          (sequence-andmap f s)]))]))

(define (stream-ormap f s)
  (unless (procedure? f) (raise-argument-error 'stream-ormap "procedure?" f))
  (unless (stream? s) (raise-argument-error 'stream-ormap "stream?" s))
  (cond
    [(pvector-map-stream? s)
     (pvector-backed-stream-ormap pvector-map-stream-for-each f s)]
    [(pvector-filter-stream? s)
     (pvector-backed-stream-ormap pvector-filter-stream-for-each f s)]
    [(pvector-filter-take-stream? s)
     (pvector-backed-stream-ormap pvector-filter-take-stream-for-each f s)]
    [(pvector-append-stream? s)
     (pvector-backed-stream-ormap pvector-append-stream-for-each f s)]
    [else
     (let ([procs (pvector-stream-procs-for s)])
       (cond
         [(and procs (eq? f void))
          (if (zero? ((vector-ref procs 14) s)) #f (void))]
         [(and procs (eq? f values))
          (pvector-stream-ormap-values s procs)]
         [procs
          (pvector-stream-ormap f s procs)]
         [else
          (sequence-ormap f s)]))]))

(define (stream-for-each f s)
  (unless (procedure? f) (raise-argument-error 'stream-for-each "procedure?" f))
  (unless (stream? s) (raise-argument-error 'stream-for-each "stream?" s))
  (cond
    [(pvector-map-stream? s)
     (pvector-map-stream-for-each f s)]
    [(pvector-filter-stream? s)
     (pvector-filter-stream-for-each f s)]
    [(pvector-filter-take-stream? s)
     (pvector-filter-take-stream-for-each f s)]
    [(pvector-append-stream? s)
     (pvector-append-stream-for-each f s)]
    [else
     (let ([procs (pvector-stream-procs-for s)])
       (if procs
           (pvector-stream-for-each f s procs)
           (sequence-for-each f s)))]))

(define (stream-fold f i s)
  (unless (procedure? f) (raise-argument-error 'stream-fold "procedure?" f))
  (unless (stream? s) (raise-argument-error 'stream-fold "stream?" s))
  (cond
    [(pvector-map-stream? s)
     (pvector-map-stream-fold f i s)]
    [(pvector-filter-stream? s)
     (pvector-filter-stream-fold f i s)]
    [(pvector-filter-take-stream? s)
     (pvector-filter-take-stream-fold f i s)]
    [(pvector-append-stream? s)
     (pvector-append-stream-fold f i s)]
    [else
     (let ([procs (pvector-stream-procs-for s)])
       (cond
         [(and procs (eq? f void))
          (if (zero? ((vector-ref procs 14) s)) i (void))]
         [procs
          (pvector-stream-fold f i s procs)]
         [else
          (sequence-fold f i s)]))]))

(define (stream-count f s)
  (unless (procedure? f) (raise-argument-error 'stream-count "procedure?" f))
  (unless (stream? s) (raise-argument-error 'stream-count "stream?" s))
  (cond
    [(pvector-map-stream? s)
     (pvector-map-stream-count f s)]
    [(pvector-filter-stream? s)
     (pvector-filter-stream-count f s)]
    [(pvector-filter-take-stream? s)
     (pvector-filter-take-stream-count f s)]
    [(pvector-append-stream? s)
     (pvector-append-stream-count f s)]
    [else
     (let ([procs (pvector-stream-procs-for s)])
       (cond
         [(and procs (eq? f void))
          ((vector-ref procs 14) s)]
         [(and procs (eq? f values))
          (pvector-stream-count-values s procs)]
         [procs
          (pvector-stream-count f s procs)]
         [else
          (sequence-count f s)]))]))

(define (stream-filter f s)
  (unless (procedure? f) (raise-argument-error 'stream-filter "procedure?" f))
  (unless (stream? s) (raise-argument-error 'stream-filter "stream?" s))
  (let ([procs (pvector-stream-procs-for s)])
    (cond
      [(and procs (eq? f void)) s]
      [(and procs (eq? f values))
       (pvector-stream-filter-values s procs)]
      [procs
       (pvector-stream-filter/lazy f s procs)]
      [else
       (stream-lazy
        (let loop ([s s])
          (cond
            [(stream-empty? s) empty-stream]
            [(call-with-values (λ () (stream-first s)) f)
             (define v (thunk->multivalue (λ () (stream-first s))))
             (stream-cons (unpack-multivalue v)
                          (loop (stream-rest s)))]
            [else (loop (stream-rest s))])))])))

(define (pvector-stream-filter-values s procs)
  (let ([len ((vector-ref procs 2) s)]
        [chunks ((vector-ref procs 12) s)])
    (define (copy-prefix! out stop-count)
      (let copy-chunks ([chunk-pos 0] [out-pos 0])
        (unless (unsafe-fx= out-pos stop-count)
          (define chunk (unsafe-vector-ref chunks chunk-pos))
          (let copy-elems ([elem-pos 0] [out-pos out-pos])
            (unless (unsafe-fx= out-pos stop-count)
              (unsafe-vector-set! out
                                  out-pos
                                  (unsafe-vector-ref chunk elem-pos))
              (define next-out-pos (unsafe-fx+ out-pos 1))
              (if (unsafe-fx= elem-pos
                              (unsafe-fx- (unsafe-vector-length chunk) 1))
                  (copy-chunks (unsafe-fx+ chunk-pos 1) next-out-pos)
                  (copy-elems (unsafe-fx+ elem-pos 1) next-out-pos)))))))
    (let scan-chunks ([chunk-pos 0]
                      [count 0]
                      [seen-false? #f]
                      [out #f])
      (if (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
          (cond
            [(not seen-false?) s]
            [(unsafe-fx= count 0) ((vector-ref procs 6))]
            [out ((vector-ref procs 9) (vector-copy out 0 count))]
            [else
             (define out (make-vector count))
             (copy-prefix! out count)
             ((vector-ref procs 9) out)])
          (let ([chunk (unsafe-vector-ref chunks chunk-pos)])
            (let scan-elems ([elem-pos 0]
                             [count count]
                             [seen-false? seen-false?]
                             [out out])
              (cond
                [(unsafe-fx= elem-pos (unsafe-vector-length chunk))
                 (scan-chunks (unsafe-fx+ chunk-pos 1)
                              count
                              seen-false?
                              out)]
                [else
                 (define v (unsafe-vector-ref chunk elem-pos))
                 (cond
                   [v
                    (cond
                      [out
                       (unsafe-vector-set! out count v)
                       (scan-elems (unsafe-fx+ elem-pos 1)
                                   (unsafe-fx+ count 1)
                                   seen-false?
                                   out)]
                      [seen-false?
                       (define out (make-vector len))
                       (copy-prefix! out count)
                       (unsafe-vector-set! out count v)
                       (scan-elems (unsafe-fx+ elem-pos 1)
                                   (unsafe-fx+ count 1)
                                   seen-false?
                                   out)]
                      [else
                       (scan-elems (unsafe-fx+ elem-pos 1)
                                   (unsafe-fx+ count 1)
                                   seen-false?
                                   out)])]
                   [else
                    (scan-elems (unsafe-fx+ elem-pos 1)
                                count
                                #t
                                out)])])))))))

(define (pvector-stream-add-between s e procs)
  (let* ([len ((vector-ref procs 2) s)]
         [pvector-empty (vector-ref procs 6)])
    (cond
      [(unsafe-fx= len 0) (pvector-empty)]
      [(unsafe-fx= len 1) s]
      [else
       (let* ([chunks ((vector-ref procs 12) s)]
              [out-len (unsafe-fx- (unsafe-fx* len 2) 1)]
              [out (make-vector out-len e)])
         (let chunk-loop ([chunk-pos 0] [out-pos 0])
           (unless (unsafe-fx= chunk-pos (unsafe-vector-length chunks))
             (define chunk (unsafe-vector-ref chunks chunk-pos))
             (let elem-loop ([elem-pos 0] [out-pos out-pos])
               (if (unsafe-fx= elem-pos (unsafe-vector-length chunk))
                   (chunk-loop (unsafe-fx+ chunk-pos 1) out-pos)
                   (begin
                     (unsafe-vector-set! out
                                         out-pos
                                         (unsafe-vector-ref chunk elem-pos))
                     (elem-loop (unsafe-fx+ elem-pos 1)
                                (unsafe-fx+ out-pos 2)))))))
        ((vector-ref procs 9) (vector->immutable-vector out)))])))

(define (stream-add-between s e)
  (unless (stream? s)
    (raise-argument-error 'stream-add-between "stream?" s))
  (let ([procs (pvector-stream-procs-for s)])
    (if procs
        (pvector-stream-add-between s e procs)
        (stream-lazy
         (cond
           [(stream-empty? s) empty-stream]
           [else
            (stream-cons
             (stream-first s)
             (let loop ([s (stream-rest s)])
               (cond
                 [(stream-empty? s) empty-stream]
                 [else
                  (stream-cons e
                               (stream-cons (stream-first s)
                                            (loop (stream-rest s))))])))])))))

;; Impersonators and Chaperones ----------------------------------------------------------------------
;; (these are private because they would fail on lists, which satisfy `stream?`)

(define (impersonate-stream s first-proc rest-proc . props)
  (impersonate-generics
   gen:stream
   s
   [stream-first
    (λ (stream-first)
      (impersonate-procedure stream-first
                             (λ (s) (values (λ (v) (first-proc v)) s))))]
   [stream-rest
    (λ (stream-rest)
      (impersonate-procedure stream-rest
                             (λ (s) (values (λ (v) (rest-proc v)) s))))]
   #:properties props))

(define (chaperone-stream s first-proc rest-proc . props)
  (chaperone-generics
   gen:stream
   s
   [stream-first
    (λ (stream-first)
      (chaperone-procedure stream-first
                           (λ (s) (values (λ (v) (first-proc v)) s))))]
   [stream-rest
    (λ (stream-rest)
      (chaperone-procedure stream-rest
                           (λ (s) (values (λ (v) (rest-proc v)) s))))]
   #:properties props))

;; Stream contracts ----------------------------------------------------------------------------------

(define (stream/c-name ctc)
  (define elem-name (contract-name (base-stream/c-content ctc)))
  (apply build-compound-type-name
         'stream/c
         elem-name
         '()))

(define (add-stream-context blame)
  (blame-add-context blame "a value generated by"))

(define (stream/c-stronger? a b)
  (contract-stronger? (base-stream/c-content a) (base-stream/c-content b)))

(define ((late-neg-projection impersonate/chaperone-stream) ctc)
  (define elem-ctc (base-stream/c-content ctc))
  (define listof-elem-ctc (listof elem-ctc))
  (define elem-ctc-late-neg (get/build-late-neg-projection elem-ctc))
  (define listof-elem-ctc-late-neg (get/build-late-neg-projection listof-elem-ctc))
  (λ (blame)
    (define stream-blame (add-stream-context blame))
    (define elem-ctc-late-neg-acceptor (elem-ctc-late-neg stream-blame))
    (define listof-elem-ctc-neg-acceptor (listof-elem-ctc-late-neg stream-blame))
    (define (stream/c-late-neg-proj-val-acceptor val neg-party)
      (unless (stream? val)
        (raise-blame-error blame #:missing-party neg-party
                           val '(expected "a stream" given: "~e") val))
      (define blame+neg-party (cons blame neg-party))
      (if (list? val)
          (listof-elem-ctc-neg-acceptor val neg-party)
          (impersonate/chaperone-stream
           val
           (λ (v) (with-contract-continuation-mark
                   blame+neg-party
                   (elem-ctc-late-neg-acceptor v neg-party)))
           (λ (v)
             (with-contract-continuation-mark
              blame+neg-party
              (if (list? v)
                  (listof-elem-ctc-neg-acceptor v neg-party)
                  (stream/c-late-neg-proj-val-acceptor v neg-party))))
           impersonator-prop:contracted ctc
           impersonator-prop:blame stream-blame)))
    stream/c-late-neg-proj-val-acceptor))

(struct base-stream/c (content))

(struct chaperone-stream/c base-stream/c ()
  #:property prop:custom-write custom-write-property-proc
  #:property prop:chaperone-contract
  (parameterize ([skip-projection-wrapper? #t])
    (build-chaperone-contract-property
     #:name stream/c-name
     #:first-order stream?
     #:stronger stream/c-stronger?
     #:late-neg-projection (late-neg-projection chaperone-stream))))

(struct impersonator-stream/c base-stream/c ()
  #:property prop:custom-write custom-write-property-proc
  #:property prop:contract
  (build-contract-property
   #:name stream/c-name
   #:first-order stream?
   #:stronger stream/c-stronger?
   #:late-neg-projection (late-neg-projection impersonate-stream)))

(define (stream/c elem)
  (define ctc (coerce-contract 'stream/c elem))
  (if (chaperone-contract? ctc)
      (chaperone-stream/c ctc)
      (impersonator-stream/c ctc)))

;; Stream comprehensions -----------------------------------------------------------------------------

(define-syntaxes (for/stream for*/stream)
  (let ()
    (define ((make-for/stream derived-stx) stx)
      (syntax-case stx ()
        [(_ clauses . body)
         (with-syntax ([((pre-body ...) (post-body ...)) (split-for-body stx #'body)])
           (quasisyntax/loc stx
             (stream-lazy
               (#,derived-stx #,stx
                              ([get-rest empty-stream]
                               #:delay-with thunk)
                 clauses
                 pre-body ...
                 (stream-cons (let () post-body ...) (get-rest))))))]))
    (values (make-for/stream #'for/foldr/derived)
            (make-for/stream #'for*/foldr/derived))))
