#lang racket/base
(require "config.rkt"
         "special.rkt"
         "wrap.rkt"
         "error.rkt"
         "parameter.rkt"
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

;; The elements form is `((element ...) #f)`; it can express any
;; element list, so it doubles as the unambiguous escape for the two
;; shapes below.
(define (elements-pvector-literal-datum? datum)
  (and (pair? datum)
       (pair? (cdr datum))
       (null? (cddr datum))
       (eq? (cadr datum) #f)
       (list? (car datum))))

;; The raw (structural) form is `(root-id ((id form) ...))` or
;; `(root-id (#:allow-forward-refs ((id form) ...)))`; requiring the
;; definitions to be a nonempty list of two-element lists keeps almost
;; every plain element list out of this shape.
(define (raw-defs-shape? defs)
  (and (pair? defs)
       (list? defs)
       (andmap (lambda (def)
                 (and (pair? def)
                      (pair? (cdr def))
                      (null? (cddr def))))
               defs)))

(define (raw-pvector-literal-datum? datum)
  (and (pair? datum)
       (pair? (cdr datum))
       (null? (cddr datum))
       (let ([defs (cadr datum)])
         (or (raw-defs-shape? defs)
             ;; the canonical raw form of the empty pvector is
             ;; `(Empty ())` with no definitions; only the built-in
             ;; empty root is accepted with an empty definition list,
             ;; so plain element lists such as `(a ())` stay element
             ;; lists
             (and (null? defs) (eq? (car datum) 'Empty))
             (and (pair? defs)
                  (pair? (cdr defs))
                  (null? (cddr defs))
                  (eq? (car defs) '#:allow-forward-refs)
                  (raw-defs-shape? (cadr defs)))))))

;; `#pv` has been read.
(define (read-pvector read-one dispatch-c init-c second-c accum-str in config)
  (unless (check-parameter read-accept-pvector config)
    (discard-current-line in config)
    (reader-error in config "`#pvector` forms not enabled"))
  (define chars (list #\e #\c #\t #\o #\r))
  (let loop ([chars chars] [accum-str accum-str])
    (cond
      [(null? chars)
       (define datum (read-one #f in (disable-wrapping config)))
       (define normalized
         (cond
           [(elements-pvector-literal-datum? datum) datum]
           [(raw-pvector-literal-datum? datum)
            (unless (check-parameter read-accept-pvector-raw config)
              (reader-error in config "`#pvector` raw literals not enabled"))
            datum]
           [(list? datum)
            ;; plain elements form: `#pvector(element ...)`
            (list datum #f)]
           [else datum]))
       (wrap (catch-and-reraise-as-reader
              in
              config
              (core-pvector-literal->pvector normalized))
             in
             config
             init-c)]
      [else
       (define c (read-expect-char (car chars) accum-str in config))
       (loop (cdr chars) (string-append accum-str (string c)))])))
