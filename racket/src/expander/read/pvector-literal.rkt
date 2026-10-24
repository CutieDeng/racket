#lang racket/base
(require "config.rkt"
         "special.rkt"
         "wrap.rkt"
         "error.rkt"
         "parameter.rkt"
         "primitive-parameter.rkt"
         "sequence.rkt"
         (only-in '#%kernel
                  core-pvector-literal->pvector
                  core-list->pvector
                  core-pvector-map
                  make-pvector-placeholder))

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
       (read-pvector-body accum-str init-c in config read-one)]
      [else
       (define c (read-expect-char (car chars) accum-str in config))
       (loop (cdr chars) (string-append accum-str (string c)))])))

;; `#pvector` has been read; the body is a parenthesized sequence,
;; whose elements are read with the current configuration: in
;; `read-syntax` mode, each element is wrapped as a syntax object with
;; its own source location, as for a vector.  The two escape forms are
;; recognized on the unwrapped datum, and their elements are wrapped
;; afterward, all with the literal's location.
(define (read-pvector-body accum-str init-c in config read-one)
  (define c (read-char/special in config))
  (define closer
    (case c
      [(#\() #\)]
      [(#\[) (and (check-parameter read-square-bracket-as-paren config) #\])]
      [(#\{) (and (check-parameter read-curly-brace-as-paren config) #\})]
      [else #f]))
  (unless closer
    (discard-current-line in config)
    (reader-error in config
                  #:due-to c
                  "expected `(` after `~a`"
                  accum-str))
  (define for-syntax? (read-config-for-syntax? config))
  (define seq (read-unwrapped-sequence read-one c c closer in config
                                       #:whitespace-read-one read-one
                                       #:dot-mode #f))
  (define datum
    (if for-syntax?
        (let ([coerce (read-config-coerce config)])
          (map (lambda (e) (coerce #f e #f)) seq))
        seq))
  (define graph? (and (read-config-state-graph
                       (read-config-st config))
                      #t))
  (define (wrap-element e)
    (if for-syntax? (wrap e in config #f) e))
  (define pv
    (cond
      [(elements-pvector-literal-datum? datum)
       ;; `((element ...) #f)`
       (define elements (map wrap-element (car datum)))
       (if graph?
           ;; graph references (#N#) inside the elements are
           ;; placeholders at this point; defer construction to
           ;; make-reader-graph so they resolve
           (make-pvector-placeholder elements)
           (core-list->pvector elements))]
      [(raw-pvector-literal-datum? datum)
       (unless (check-parameter read-accept-pvector-raw config)
         (reader-error in config "`#pvector` raw literals not enabled"))
       (define raw-pv
         (catch-and-reraise-as-reader
          in
          config
          (core-pvector-literal->pvector datum)))
       (if for-syntax?
           (core-pvector-map raw-pv wrap-element)
           raw-pv)]
      [else
       ;; `#pvector(element ...)`
       (if graph?
           (make-pvector-placeholder seq)
           (core-list->pvector seq))]))
  (wrap pv in config init-c))
