#lang tstring racket

(provide
 rendered
 template-value
) ; end provide

(define name "Alice")
(define rendered f"hello {name}")
(define template-value t"hello {name}")
