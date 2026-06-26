#lang racket/base
(require "config.rkt"
         "special.rkt"
         "wrap.rkt"
         "error.rkt"
         (only-in '#%kernel core-pvector-literal->pvector))

(provide read-pvector)

(define (discard-current-line in config)
  (let loop ()
    (define c (peek-char/special in config))
    (unless (or (eof-object? c)
                (eqv? c #\newline))
      (read-char/special in config)
      (loop))))

(define (read-expect-char expected accum-str in config)
  (define c (read-char/special in config))
  (unless (eqv? c expected)
    (discard-current-line in config)
    (reader-error in config
                  #:due-to c
                  "expected `~a` to continue `#pvector` after `~a`"
                  expected
                  accum-str))
  c)

;; `#pv` has been read.
(define (read-pvector read-one dispatch-c init-c second-c accum-str in config)
  (define chars (list #\e #\c #\t #\o #\r))
  (let loop ([chars chars] [accum-str accum-str])
    (cond
      [(null? chars)
       (define datum (read-one #f in (disable-wrapping config)))
       (wrap (catch-and-reraise-as-reader
              in
              config
              (core-pvector-literal->pvector datum))
             in
             config
             init-c)]
      [else
       (define c (read-expect-char (car chars) accum-str in config))
       (loop (cdr chars) (string-append accum-str (string c)))])))
