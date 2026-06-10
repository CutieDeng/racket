#lang racket/base

(require
 rackunit
) ; end require

(dynamic-require 'racket/interactive/tstring #f)

(define read-interaction (current-read-interaction))

(define (read-datum in)
  (define v (read-interaction 'test in))
  (if (syntax? v)
      (syntax->datum v)
      v
  ) ; end if
) ; end define read-datum

(let ((in (open-input-string "1 2\n")))
  (check-equal? (read-datum in) 1)
  (check-equal? (read-datum in) 2)
  (check-equal? (read-datum in) eof)
) ; end let same line

(let ((in (open-input-string "\n1\n")))
  (check-equal? (read-datum in) 1)
  (check-equal? (read-datum in) eof)
) ; end let leading blank line

(let ((in (open-input-string "1 (2)\n")))
  (check-equal? (read-datum in) 1)
  (check-equal? (read-datum in) '(2))
  (check-equal? (read-datum in) eof)
) ; end let continued interaction

(let ((in (open-input-string "1 (\n")))
  (check-equal? (read-datum in) 1)
  (check-exn exn:fail:read:eof?
             (lambda ()
               (read-datum in)
             ) ; end lambda
  ) ; end check-exn
  (check-equal? (read-datum in) eof)
) ; end let eof after incomplete interaction

(let ((in (open-input-string "#\\a2\n")))
  (check-equal? (read-datum in) #\a)
  (check-equal? (read-datum in) 2)
) ; end let reader token boundary

(let ((in (open-input-string "#t2\n")))
  (check-exn exn:fail:read?
             (lambda ()
               (read-datum in)
             ) ; end lambda
  ) ; end check-exn
) ; end let reader token extension

(let ((in (open-input-string "f\"hi\" 2\n")))
  (check-equal? (read-datum in) '(#%tstring-fpl "hi"))
  (check-equal? (read-datum in) 2)
) ; end let template string

(let ((first-in (open-input-string "1 2\n"))
      (second-in (open-input-string "3\n"))
     ) ; end bindings
  (check-equal? (read-datum first-in) 1)
  (check-equal? (read-datum second-in) 3)
  (check-equal? (read-datum first-in) 2)
) ; end let per port
