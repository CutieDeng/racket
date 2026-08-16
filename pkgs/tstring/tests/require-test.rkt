#lang racket/base

(require
 rackunit
 "../main.rkt"
) ; end require

(define tpl-value
  (template (list "hello " "")
            (list (interpolation "Alice" #'name #f ""))
  ) ; end template
) ; end define tpl-value

(check-true (template? tpl-value))
(check-equal? (render-template tpl-value) "hello Alice")

(check-exn
 exn:fail?
 (lambda ()
   (eval '(let ()
            (require "../main.rkt")
            fpl
          ) ; end let
   ) ; end eval
 ) ; end lambda
) ; end check-exn private fpl

(check-exn
 exn:fail?
 (lambda ()
   (eval '(let ()
            (require "../main.rkt")
            tpl
          ) ; end let
   ) ; end eval
 ) ; end lambda
) ; end check-exn private tpl
