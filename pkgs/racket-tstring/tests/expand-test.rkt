#lang racket/base

(require
 rackunit
 racket/string
 "../main.rkt"
 "../private/expand.rkt"
) ; end require

(define name "Alice")

(define simple-template
  (tpl "hello {name}")
) ; end define simple-template

(check-true (template? simple-template))
(check-equal? (length (template-parts simple-template)) 3)
(check-equal? (template-strings simple-template) (list "hello " ""))
(check-equal? (syntax-e (interpolation-syntax (car (template-interpolations simple-template)))) 'name)
(check-equal? (map interpolation-value (template-interpolations simple-template))
              (list "Alice")
) ; end check-equal?
(check-equal? (map interpolation-format-spec (template-interpolations simple-template)) (list #f))
(check-equal? (map interpolation-conversion (template-interpolations simple-template)) (list ""))
(check-equal? (render-template simple-template) "hello Alice")
(check-equal? (fpl "hello {name}") "hello Alice")
(check-equal? (fpl "static") "static")
(check-exn
 exn:fail?
 (lambda ()
   (eval '(let ()
            (require "../private/expand.rkt")
            (tpl "{missing-name}")
          ) ; end let
   ) ; end eval
 ) ; end lambda
) ; end check-exn unbound t-string interpolation
(define t "T")
(define bang! "bang")
(define name= "name-equals")
(check-true (template? (tpl "{t}")))
(check-equal? (interpolation-value (car (template-interpolations (tpl "{t}")))) "T")
(check-equal? (interpolation-format-spec (car (template-interpolations (tpl "{t}")))) #f)
(check-equal? (interpolation-conversion (car (template-interpolations (tpl "{t}")))) "")
(check-equal? (fpl "{bang!}") "bang")
(check-equal? (fpl "{name=}") "name-equals")

(define formatted-template
  (tpl "{1!r:.2f}")
) ; end define formatted-template

(check-equal? (interpolation-value (car (template-interpolations formatted-template))) 1)
(check-equal? (syntax-e (interpolation-syntax (car (template-interpolations formatted-template)))) 1)
(check-equal? (interpolation-conversion (car (template-interpolations formatted-template))) "r")
(check-equal? (interpolation-format-spec (car (template-interpolations formatted-template))) ".2f")

(check-equal? (fpl "{(string-upcase name)}") "ALICE")
(check-equal? (fpl "{(+ 1)}") "1")
(check-equal? (fpl "{2:03d}") "002")
(check-equal? (fpl "{123:010}") "0000000123")
(check-equal? (fpl "{-123:010}") "-000000123")
(check-equal? (fpl "{-123:>010}") "000000-123")
(check-equal? (fpl "{-123:<010}") "-123000000")
(check-equal? (fpl "{123:#010x}") "0x0000007b")
(check-equal? (fpl "{-123:#010x}") "-0x000007b")
(check-equal? (fpl "{#;ignored 123:04d}") "0123")
(check-equal? (fpl "{#;(ignored :not-a-suffix) 7:03d}") "007")
(check-equal? (fpl "{10:>2d}") "10")
(check-equal? (fpl "{7:>3d}") "  7")
(check-equal? (fpl "{7:<3d}") "7  ")
(check-equal? (fpl "{1.234:.2f}") "1.23")
(check-equal? (fpl "{2:.2f}") "2.00")
(check-equal? (fpl "{\"hi\"!r}") "\"hi\"")
(check-exn
 exn:fail?
 (lambda ()
   (fpl "{\"hi\"!r:.2f}")
 ) ; end lambda
) ; end check-exn string conversion numeric format

(check-exn
 exn:fail:syntax?
 (lambda ()
   (eval '(let ()
            (require "../private/expand.rkt")
            (fpl "{+ 1}")
          ) ; end let
   ) ; end eval
 ) ; end lambda
) ; end check-exn extra text after expression

(check-exn
 exn:fail:syntax?
 (lambda ()
   (eval '(let ()
            (require "../private/expand.rkt")
            (fpl "{2 03d}")
          ) ; end let
   ) ; end eval
 ) ; end lambda
) ; end check-exn old format suffix

(check-exn
 exn:fail:syntax?
 (lambda ()
   (eval '(let ()
            (require "../private/expand.rkt")
            (fpl "{value r}")
          ) ; end let
   ) ; end eval
 ) ; end lambda
) ; end check-exn old conversion suffix

(check-exn
 exn:fail:syntax?
 (lambda ()
   (eval '(let ()
            (require "../private/expand.rkt")
            (fpl "{x!rr}")
          ) ; end let
   ) ; end eval
 ) ; end lambda
) ; end check-exn extra conversion text

(check-exn
 exn:fail:syntax?
 (lambda ()
   (eval '(let ()
            (require "../private/expand.rkt")
            (fpl "{x:}")
          ) ; end let
   ) ; end eval
 ) ; end lambda
) ; end check-exn empty format suffix

(check-exn
 exn:fail:syntax?
 (lambda ()
   (eval '(let ()
            (require "../private/expand.rkt")
            (fpl "{123#010x}")
          ) ; end let
   ) ; end eval
 ) ; end lambda
) ; end check-exn missing format delimiter before alternate flag

(define evaluation-order '())

(check-equal?
 (fpl "{(begin (set! evaluation-order (append evaluation-order '(a))) \"A\")}{(begin (set! evaluation-order (append evaluation-order '(b))) \"B\")}")
 "AB"
) ; end check-equal?
(check-equal? evaluation-order '(a b))

(define a 1)
(define b 2)

(define multi-template
  (tpl "{a} + {b} = {(+ a b)}")
) ; end define multi-template

(check-equal? (render-template multi-template) "1 + 2 = 3")
(check-equal? (map interpolation-value (template-interpolations multi-template))
              (list 1 2 3)
) ; end check-equal?

(check-exn
 exn:fail?
 (lambda ()
   (template->sql (tpl "WHERE id = {(+ 1 2)}"))
 ) ; end lambda
) ; end check-exn

(check-equal? (fpl "{{name}}") "{name}")
(check-equal? (fpl "outer {f\"inner {name}\"}") "outer inner Alice")

(define nested-template
  (tpl "outer {t\"inner {name}\"}")
) ; end define nested-template

(check-true (template? (interpolation-value (car (template-interpolations nested-template)))))

(check-exn
 exn:fail:syntax?
 (lambda ()
   (eval '(let ()
            (require "../private/expand.rkt")
            (tpl 1)
          ) ; end let
   ) ; end eval
 ) ; end lambda
) ; end check-exn

(check-exn
 exn:fail:syntax?
 (lambda ()
   (eval '(let ()
            (require "../private/expand.rkt")
            (tpl "hello {}")
          ) ; end let
   ) ; end eval
 ) ; end lambda
) ; end check-exn empty template interpolation

(check-exn
 exn:fail:syntax?
 (lambda ()
   (eval '(let ()
            (require "../private/expand.rkt")
            (tpl "hello {")
          ) ; end let
   ) ; end eval
 ) ; end lambda
) ; end check-exn unclosed template interpolation

(check-exn
 exn:fail:syntax?
 (lambda ()
   (eval '(let ()
            (require "../private/expand.rkt")
            (tpl "hello }")
          ) ; end let
   ) ; end eval
 ) ; end lambda
) ; end check-exn unmatched right brace

(check-exn
 exn:fail:syntax?
 (lambda ()
   (eval '(let ()
            (require "../private/expand.rkt")
            (tpl "hello {(+ 1 2}")
          ) ; end let
   ) ; end eval
 ) ; end lambda
) ; end check-exn malformed expression
