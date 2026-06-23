#lang racket/base

(require
 rackunit
 "../main.rkt"
 (prefix-in base: "wrapper-racket-base.rkt")
 (prefix-in full: "wrapper-racket.rkt")
) ; end require

(check-equal? base:rendered "hello Alice")
(check-true (template? base:template-value))
(check-equal? (interpolation-value (car (template-interpolations base:template-value))) "Alice")
(check-equal? (interpolation-format-spec (car (template-interpolations base:template-value))) #f)
(check-equal? (interpolation-conversion (car (template-interpolations base:template-value))) "")
(check-equal? base:nested-rendered "outer inner Alice")

(check-equal? full:rendered "hello Alice")
(check-true (template? full:template-value))
(check-equal? (interpolation-value (car (template-interpolations full:template-value))) "Alice")
