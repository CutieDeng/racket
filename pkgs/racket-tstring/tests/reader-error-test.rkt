#lang racket/base

(require
 rackunit
 racket/runtime-path
 racket/sandbox
 "../lang/reader.rkt"
) ; end require

(define-runtime-path reader-rkt "../lang/reader.rkt")

(define (read-tstring-source source)
  (read-syntax 'reader-error-test (open-input-string source))
) ; end define read-tstring-source

(define (evaluate-tstring-module-source source)
  (parameterize ((sandbox-output 'string)
                 (sandbox-error-output 'string)
            ) ; end parameterize bindings
    (define in
      (open-input-string
       (format "#lang reader (file ~s)\n~a"
               (path->string reader-rkt)
               source
       ) ; end format
      ) ; end open-input-string
    ) ; end define in
    (port-count-lines! in)
    (make-module-evaluator in)
  ) ; end parameterize
) ; end define evaluate-tstring-module-source

(define (syntax-error-from thunk)
  (with-handlers ((exn:fail:syntax?
                   (lambda (exn) exn)
                  ) ; end exn:fail:syntax?
                 ) ; end handlers
    (thunk)
    #f
  ) ; end with-handlers
) ; end define syntax-error-from

(check-exn
 exn:fail:read?
 (lambda ()
   (read-tstring-source "f\"hello")
 ) ; end lambda
) ; end check-exn unclosed template string

(check-exn
 exn:fail:read?
 (lambda ()
   (read-tstring-source "f\"hello {name")
 ) ; end lambda
) ; end check-exn unclosed reader interpolation

(define bad-interpolation-exn
  (syntax-error-from
   (lambda ()
     (evaluate-tstring-module-source "f\"{+ 1}\"\n")
   ) ; end lambda
  ) ; end syntax-error-from
) ; end define bad-interpolation-exn

(check-true (exn:fail:syntax? bad-interpolation-exn))
(check-true
 (regexp-match? #rx"fpl: interpolation must contain exactly one expression"
                (exn-message bad-interpolation-exn)
 ) ; end regexp-match?
) ; end check-true
(check-false (regexp-match? #rx"fpl: fpl:" (exn-message bad-interpolation-exn)))
(check-equal? (syntax-line (car (exn:fail:syntax-exprs bad-interpolation-exn))) 2)
(check-equal? (syntax-column (car (exn:fail:syntax-exprs bad-interpolation-exn))) 0)
