#lang racket

(require racket/generic
         racket/stream
         (only-in racket/private/for prop:gen-sequence))

(define-struct list-stream (v)
  #:methods gen:stream
  [(define (stream-empty? generic-stream)
     (empty? (list-stream-v generic-stream)))
   (define (stream-first generic-stream)
     (first (list-stream-v generic-stream)))
   (define (stream-rest generic-stream)
     (rest (list-stream-v generic-stream)))])

(struct vector-stream (i v)
        #:methods gen:stream
        [(define (stream-first x) (vector-ref (vector-stream-v x)
                                              (vector-stream-i x)))
         (define (stream-rest x) (vector-stream (add1 (vector-stream-i x))
                                                (vector-stream-v x)))
         (define (stream-empty? x) (>= (vector-stream-i x)
                                       (vector-length
                                        (vector-stream-v x))))])

(struct sequence+stream (stream-values sequence-values)
  #:property prop:gen-sequence
  (lambda (x) (in-list (sequence+stream-sequence-values x)))
  #:methods gen:stream
  [(define (stream-empty? x)
     (empty? (sequence+stream-stream-values x)))
   (define (stream-first x)
     (first (sequence+stream-stream-values x)))
   (define (stream-rest x)
     (sequence+stream (rest (sequence+stream-stream-values x))
                      (sequence+stream-sequence-values x)))])



(module+ test
  (require rackunit
           racket/pvector)

  (define l1 (list-stream '(1 2)))

  (check-true (stream? l1))
  (check-false (stream-empty? l1))
  (check-equal? (stream-first l1) 1)

  (define l2 (stream-rest l1))
  (check-true (stream? l2))
  (check-false (stream-empty? l2))
  (check-equal? (stream-first l2) 2)

  (define l3 (stream-rest l2))
  (check-true (stream? l3))
  (check-true (stream-empty? l3))


  (define s2 (vector-stream 0 '#(1 2 3)))
  (check-equal? (sequence-fold + 0 s2) 6)
  (define s3 (sequence+stream '(stream values)
                              '(sequence values)))
  (check-equal? (stream->list s3)
                '(stream values))
  (check-equal? (stream-length s3) 2)
  (check-equal? (stream-ref s3 1) 'values)
  (check-equal? (stream->list (stream-tail s3 1)) '(values))
  (check-equal? (stream->list (stream-take s3 1)) '(stream))
  (let* ([sep (box 'sep)]
         [between (stream-add-between (pvector 'a 'b 'c) sep)])
    (check-true (pvector? between))
    (check-equal? (stream->list between) (list 'a sep 'b sep 'c))
    (check-true (eq? (pvector-ref between 1) sep))
    (check-true (eq? (pvector-ref between 3) sep)))
  )
