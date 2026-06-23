#lang tstring at-exp racket

(require rackunit)

(define name "Alice")

(check-equal? f"hello {name}" "hello Alice")
(check-equal? @string-append{hi} "hi")
