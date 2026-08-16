#lang racket/base

(require racket/cmdline
         racket/list
         racket/match
         racket/string)

(define selected-kind "total-score")
(define speed-only? #f)
(define input-paths null)

(command-line
 #:program "pvector-score-summary"
 #:once-each
 [("--kind") k "Score row kind to summarize, normally total-score or power-score"
             (set! selected-kind k)]
 [("--speed-only") "Summarize speed score plus absolute real-ns/op geomean only"
                   (set! speed-only? #t)]
 #:args paths
 (set! input-paths paths))

(define (string->number/false s)
  (and (not (string=? s ""))
       (string->number s)))

(define (median xs)
  (define sorted (sort xs <))
  (define n (length sorted))
  (cond
    [(zero? n) #f]
    [(odd? n) (list-ref sorted (quotient n 2))]
    [else
     (/ (+ (list-ref sorted (sub1 (quotient n 2)))
           (list-ref sorted (quotient n 2)))
        2.0)]))

(define (mean xs)
  (/ (for/sum ([x (in-list xs)]) x)
     (length xs)))

(define (sample-stddev xs)
  (cond
    [(< (length xs) 2) 0.0]
    [else
     (define avg (mean xs))
     (sqrt (/ (for/sum ([x (in-list xs)])
                (define delta (- x avg))
                (* delta delta))
              (sub1 (length xs))))]))

(define (geomean xs)
  (define positives
    (for/list ([x (in-list xs)]
               #:when (and x (positive? x)))
      x))
  (and (pair? positives)
       (exp (/ (for/sum ([x (in-list positives)]) (log x))
               (length positives)))))

(define (format-cell v)
  (cond
    [(not v) ""]
    [(integer? v) (number->string v)]
    [(number? v) (real->decimal-string v 6)]
    [else (format "~a" v)]))

(define speed-only-score-method
  "speed-only-geomean(speed-ratio=baseline/target)")

(define (absolute-speed-method size-weight-model operation-weight-model)
  (format "absolute-geomean(real-ns/op;size-weight=~a;operation-weight=~a)"
          size-weight-model
          operation-weight-model))

(define (split-row line)
  (string-split line "\t" #:trim? #f))

(define (header-index header name)
  (define pos
    (for/first ([field (in-list header)]
                [i (in-naturals)]
                #:when (string=? field name))
      i))
  (unless pos
    (raise-user-error 'pvector-score-summary
                      "missing TSV column: ~a"
                      name))
  pos)

(struct bucket (values metadata) #:transparent)

(define buckets (make-hash))

(define (cell fields index)
  (if (< index (length fields))
      (list-ref fields index)
      ""))

(define (add-sample! key metadata value)
  (when value
    (hash-update! buckets
                  key
                  (lambda (b)
                    (bucket (cons value (bucket-values b))
                            (bucket-metadata b)))
                  (lambda () (bucket null metadata)))))

(define (add-detail-speed-samples! detail-by-size)
  (define values-by-impl (make-hash))
  (for ([(key values) (in-hash detail-by-size)])
    (match-define (list impl _size baseline score-profile size-weight-model
                        operation-weight-model score-method)
      key)
    (define size-geomean (geomean values))
    (when size-geomean
      (hash-update! values-by-impl
                    (list impl baseline score-profile size-weight-model
                          operation-weight-model score-method)
                    (lambda (xs) (cons size-geomean xs))
                    null)))
  (for ([(key values) (in-hash values-by-impl)])
    (match-define (list impl baseline score-profile size-weight-model
                        operation-weight-model score-method)
      key)
    (define value (geomean values))
    (add-sample! (list "detail-speed"
                       impl
                       "absolute-real-ns/op-geomean"
                       baseline)
                 (list baseline
                       score-profile
                       size-weight-model
                       operation-weight-model
                       score-method)
                 value)))

(define (consume-port in)
  (define header-line (read-line in 'any))
  (unless (eof-object? header-line)
    (define header (split-row header-line))
    (define kind-i (header-index header "kind"))
    (define size-i (header-index header "size"))
    (define impl-i (header-index header "impl"))
    (define real-ns/op-i (header-index header "real-ns/op"))
    (define baseline-i (header-index header "baseline"))
    (define score-profile-i (header-index header "score-profile"))
    (define size-weight-model-i (header-index header "size-weight-model"))
    (define operation-weight-model-i (header-index header "operation-weight-model"))
    (define score-method-i (header-index header "score-method"))
    (define metric-indices
      (if speed-only?
          (list (cons "speed-score" (header-index header "speed-score")))
          (list (cons "speed-score" (header-index header "speed-score"))
                (cons "cost-score" (header-index header "cost-score"))
                (cons "total-score" (header-index header "total-score")))))
    (define detail-by-size (make-hash))
    (for ([line (in-lines in 'any)])
      (define fields (split-row line))
      (define kind (cell fields kind-i))
      (when (string=? kind "detail")
        (define value (string->number/false (cell fields real-ns/op-i)))
        (when value
          (define impl (cell fields impl-i))
          (define size (cell fields size-i))
          (define baseline (cell fields baseline-i))
          (define size-weight-model (cell fields size-weight-model-i))
          (define operation-weight-model (cell fields operation-weight-model-i))
          (hash-update! detail-by-size
                        (list impl
                              size
                              baseline
                              (cell fields score-profile-i)
                              size-weight-model
                              operation-weight-model
                              (absolute-speed-method size-weight-model
                                                     operation-weight-model))
                        (lambda (xs) (cons value xs))
                        null)))
      (when (string=? kind selected-kind)
        (define impl (cell fields impl-i))
        (define baseline (cell fields baseline-i))
        (define metadata
          (list baseline
                (cell fields score-profile-i)
                (cell fields size-weight-model-i)
                (cell fields operation-weight-model-i)
                (if speed-only?
                    speed-only-score-method
                    (cell fields score-method-i))))
        (for ([metric (in-list metric-indices)])
          (define metric-name (car metric))
          (define value (string->number/false (cell fields (cdr metric))))
          (add-sample! (list selected-kind impl metric-name baseline)
                       metadata
                       value))))
    (add-detail-speed-samples! detail-by-size)))

(cond
  [(null? input-paths)
   (consume-port (current-input-port))]
  [else
   (for ([path (in-list input-paths)])
     (call-with-input-file path consume-port))])

(define (emit-row cells)
  (displayln (string-join (map format-cell cells) "\t")))

(emit-row
 '("kind" "impl" "metric" "n" "median" "mean" "stddev" "cv"
   "cv-percent" "min" "max" "baseline" "score-profile"
   "size-weight-model" "operation-weight-model" "score-method"))

(for ([key (in-list (sort (hash-keys buckets) string<?
                          #:key (lambda (k) (format "~s" k))))])
  (define b (hash-ref buckets key))
  (define xs (reverse (bucket-values b)))
  (define n (length xs))
  (define avg (mean xs))
  (define sd (sample-stddev xs))
  (define cv (and (not (zero? avg)) (/ sd avg)))
  (match-define (list baseline score-profile size-weight-model
                      operation-weight-model score-method)
    (bucket-metadata b))
  (emit-row
   (append (list (list-ref key 0)
                 (list-ref key 1)
                 (list-ref key 2)
                 n
                 (median xs)
                 avg
                 sd
                 cv
                 (and cv (* 100 cv))
                 (apply min xs)
                 (apply max xs))
           (list baseline
                 score-profile
                 size-weight-model
                 operation-weight-model
                 score-method))))
