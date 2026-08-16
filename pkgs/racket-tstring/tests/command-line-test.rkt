#lang racket/base

(require
 rackunit
 racket/port
) ; end require

(define (run-racket input . args)
  (define-values (proc out in err)
    (apply subprocess #f #f #f (find-system-path 'exec-file) args)
  ) ; end define-values
  (when input
    (display input in)
  ) ; end when input
  (close-output-port in)
  (subprocess-wait proc)
  (values (subprocess-status proc)
          (port->string out)
          (port->string err)
  ) ; end values
) ; end define run-racket

(define-check (check-racket-output input args expected-output)
  (define-values (status stdout stderr)
    (apply run-racket input args)
  ) ; end define-values
  (with-check-info (('stderr stderr))
    (check-equal? status 0)
  ) ; end with-check-info
  (check-equal? stdout expected-output)
) ; end define-check check-racket-output

(check-racket-output #f
                     '("-e" "(define x 1) f\"{x}\"")
                     "\"1\"\n"
) ; end single -e

(check-racket-output #f
                     '("-e" "(define x 1)"
                       "-e" "f\"{x}\"")
                     "\"1\"\n"
) ; end multiple -e

(check-racket-output "(define x 1)\nf\"{x}\"\n"
                     '("-f" "-")
                     "\"1\"\n"
) ; end -f stdin
