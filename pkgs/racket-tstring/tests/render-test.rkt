#lang racket/base

(require
 rackunit
 "../main.rkt"
 "../private/render.rkt"
) ; end require

(define name "Alice")

(define hello-interpolation
  (interpolation name #'name #f "")
) ; end define hello-interpolation

(define hello-template
  (template (list "hello " "")
            (list hello-interpolation)
  ) ; end template
) ; end define hello-template

(check-true (template? hello-template))
(check-equal? (template-parts hello-template) (list "hello " hello-interpolation ""))
(check-equal? (template-strings hello-template) (list "hello " ""))
(check-equal? (map interpolation-value (template-interpolations hello-template)) (list "Alice"))
(check-equal? (render-template hello-template) "hello Alice")
(check-equal? (render-fstring hello-template) "hello Alice")

(check-equal? (format-fstring-value 123 "010" "") "0000000123")
(check-equal? (format-fstring-value -123 "010" "") "-000000123")
(check-equal? (format-fstring-value -123 ">010" "") "000000-123")
(check-equal? (format-fstring-value -123 "<010" "") "-123000000")
(check-equal? (format-fstring-value -123 "x>010" "") "xxxxxx-123")
(check-equal? (format-fstring-value "abc" ">010" "") "0000000abc")
(check-equal? (format-fstring-value "abc" "0>10" "") "0000000abc")
(check-equal? (format-fstring-value 123 "#x" "") "0x7b")
(check-equal? (format-fstring-value 123 "#010x" "") "0x0000007b")
(check-equal? (format-fstring-value -123 "#010x" "") "-0x000007b")
(check-equal? (format-fstring-value 123 "#010X" "") "0X0000007B")
(check-equal? (format-fstring-value 123 "#b" "") "0b1111011")
(check-equal? (format-fstring-value 123 "#o" "") "0o173")

(check-exn
 exn:fail?
 (lambda ()
   (format-fstring-value "abc" "010" "")
 ) ; end lambda
) ; end check-exn string sign-aware zero padding

(check-exn
 exn:fail?
 (lambda ()
   (format-fstring-value "abc" "=010" "")
 ) ; end lambda
) ; end check-exn string sign-aware alignment

(check-exn
 exn:fail?
 (lambda ()
   (format-fstring-value 123 "s" "")
 ) ; end lambda
) ; end check-exn numeric string type

(check-exn
 exn:fail?
 (lambda ()
   (format-fstring-value 1.23 "s" "")
 ) ; end lambda
) ; end check-exn real string type

(check-exn
 exn:fail?
 (lambda ()
   (format-fstring-value "abc" "+10s" "")
 ) ; end lambda
) ; end check-exn string sign

(check-exn
 exn:fail?
 (lambda ()
   (format-fstring-value "abc" " 10s" "")
 ) ; end lambda
) ; end check-exn string space sign

(check-exn
 exn:fail?
 (lambda ()
   (format-fstring-value "abc" "#10s" "")
 ) ; end lambda
) ; end check-exn string alternate

(check-exn
 exn:fail?
 (lambda ()
   (format-fstring-value 123 ".2d" "")
 ) ; end lambda
) ; end check-exn integer precision

(check-exn
 exn:fail?
 (lambda ()
   (format-fstring-value 1.0 "#g" "")
 ) ; end lambda
) ; end check-exn unsupported real alternate

(define sum-template
  (template (list "sum = " "")
            (list (interpolation 3 #'(+ 1 2) #f ""))
  ) ; end template
) ; end define sum-template

(check-equal? (render-template sum-template) "sum = 3")
(check-equal? (render-template sum-template
                               #:value->string number->string
              ) ; end render-template
              "sum = 3"
) ; end check-equal?

(define id 42)
(define status "active")

(define sql-template
  (template (list "WHERE id = " " AND status = " "")
            (list (interpolation id #'id #f "")
                  (interpolation status #'status #f "")
            ) ; end list
  ) ; end template
) ; end define sql-template

(define-values (sql params)
  (template->sql sql-template)
) ; end define-values

(check-equal? sql "WHERE id = ? AND status = ?")
(check-equal? params (list 42 "active"))

(check-exn
 exn:fail?
 (lambda ()
   (template->sql sum-template)
 ) ; end lambda
) ; end check-exn

(define html-template
  (template (list "<p>" "</p>")
            (list (interpolation "<script>&\"" #'user-input #f ""))
  ) ; end template
) ; end define html-template

(check-equal? (html-render html-template)
              "<p>&lt;script&gt;&amp;&quot;</p>"
) ; end check-equal?

(check-exn
 exn:fail:contract?
  (lambda ()
    (render-template
     (template (list "too " "many " "strings")
               '()
     ) ; end template
    ) ; end render-template
  ) ; end lambda
) ; end check-exn
