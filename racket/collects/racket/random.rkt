#lang racket/base

(require "private/crypto-core.rkt"
         (only-in "random/generator.rkt" rgen? rgen-integer)
         racket/contract/base racket/sequence racket/set)
(provide (contract-out [crypto-random-bytes (-> exact-nonnegative-integer? bytes?)]
                       [random-ref (->* (sequence?) ((or/c pseudo-random-generator? rgen?)) any/c)]
                       [random-sample (->* (sequence? exact-nonnegative-integer?)
                                           ((or/c pseudo-random-generator? rgen?)
                                            #:replacement? any/c)
                                           (listof any/c))]))

;; (: crypto-random-bytes (-> Positive-Integer Bytes))
;; Returns n random bytes from the OS, via the built-in rktcrypto
;; subsystem when available (see racket/private/crypto-core).

(define (random-ref seq [prng (current-pseudo-random-generator)])
  (define samples
    (random-sample/replacement seq 1 prng))
  (unless samples
    (raise-argument-error 'random-ref "non-empty sequence" seq))
  (vector-ref samples 0))

(define not-there (gensym))

(define (random-sample seq n [prng (current-pseudo-random-generator)]
                       #:replacement? [replacement? #t])
  ;; doing reservoir sampling, to do a single pass over the sequence
  ;; (some sequences may not like multiple passes, e.g., ports)
  (cond
   [(zero? n) '()]
   [(not replacement?)
    (define samples
      (random-sample/out-replacement seq n prng))
    ;; did we get enough?
    (unless (for/and ([s (in-vector samples)])
              (not (eq? s not-there)))
      (raise-argument-error 'random-sample
                            "integer less than or equal to sequence length"
                            1 seq n prng))
    (vector->list samples)]
   [else
    (define samples
      (random-sample/replacement seq n prng))
    (unless samples
      (raise-argument-error 'random-sample
                            "non-empty sequence for n>0"
                            0 seq n prng))
    (vector->list samples)]))

;; `prng` throughout is either a classic pseudo-random generator or
;; an rktrandom generator from `racket/random/generator`.
(define (rand-int n prng)
  (if (rgen? prng) (rgen-integer prng n) (random n prng)))

(define (random-sample/out-replacement seq n prng)
  ;; Based on: https://rosettacode.org/wiki/Knuth%27s_algorithm_S#Racket
  (define samples (make-vector n not-there))
  (for ([elt seq]
        [i   (in-naturals)])
    (cond [(< i n) ; we're not full, sample for sure
           (vector-set! samples i elt)]
          [(< (rand-int (add1 i) prng) n) ; we've already seen n items; replace one?
           (vector-set! samples (rand-int n prng) elt)]))
  samples)

(define (random-sample/replacement seq n prng)
  ;; similar to above, except each sample is independent
  (define samples #f)
  (for ([elt seq]
        [i   (in-naturals)])
    (cond [(= i 0) ; initialize samples
           (set! samples (make-vector n elt))]
          [else ; independently, maybe replace
           (for ([j (in-range n)])
             (when (zero? (rand-int (add1 i) prng))
               (vector-set! samples j elt)))]))
  samples)
