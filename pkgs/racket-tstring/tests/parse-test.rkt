#lang racket/base

(require
 rackunit
 "../main.rkt"
) ; end require

(define-syntax-rule (check-parse input expected-strings expected-expressions)
  (let-values (((strings expressions) (parse-template-string input)))
    (check-equal? strings expected-strings)
    (check-equal? expressions expected-expressions)
  ) ; end let-values
) ; end define-syntax-rule check-parse

(check-parse "hello" (list "hello") '())
(check-parse "hello {name}" (list "hello " "") (list "name"))
(check-parse "{name}" (list "" "") (list "name"))
(check-parse "{a} + {b}" (list "" " + " "") (list "a" "b"))
(check-parse "sum = {(+ a b)}" (list "sum = " "") (list "(+ a b)"))
(check-parse "brace = {(string-append \"}\" \"x\")}"
             (list "brace = " "")
             (list "(string-append \"}\" \"x\")")
) ; end check-parse
(check-parse "char = {(char->integer #\\})}"
             (list "char = " "")
             (list "(char->integer #\\})")
) ; end check-parse
(check-parse "symbol = {(symbol->string '|}|)}"
             (list "symbol = " "")
             (list "(symbol->string '|}|)")
) ; end check-parse
(check-parse "block = {#| } |# 7}"
             (list "block = " "")
             (list "#| } |# 7")
) ; end check-parse
(check-parse "line = {; }\n7}"
             (list "line = " "")
             (list "; }\n7")
) ; end check-parse
(check-parse "datum = {#;#\\} 7}"
             (list "datum = " "")
             (list "#;#\\} 7")
) ; end check-parse
(check-parse "outer {f\"inner {x}\"}"
             (list "outer " "")
             (list "f\"inner {x}\"")
) ; end check-parse
(check-parse "{{" (list "{") '())
(check-parse "}}" (list "}") '())
(check-parse "{{name}}" (list "{name}") '())
(check-parse "before {{ {name} }} after"
             (list "before { " " } after")
             (list "name")
) ; end check-parse

(check-exn
 exn:fail?
 (lambda ()
   (parse-template-string "hello {}")
 ) ; end lambda
) ; end check-exn empty interpolation

(check-exn
 exn:fail?
 (lambda ()
   (parse-template-string "hello {   }")
 ) ; end lambda
) ; end check-exn blank interpolation

(check-exn
 exn:fail?
 (lambda ()
   (parse-template-string "hello {")
 ) ; end lambda
) ; end check-exn unclosed interpolation

(check-exn
 exn:fail?
 (lambda ()
   (parse-template-string "hello }")
 ) ; end lambda
) ; end check-exn unmatched right brace

(check-exn
 exn:fail:contract?
 (lambda ()
   (parse-template-string 42)
 ) ; end lambda
) ; end check-exn non-string
