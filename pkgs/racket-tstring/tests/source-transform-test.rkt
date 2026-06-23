#lang racket/base

(require
 rackunit
 "../private/source-transform.rkt"
) ; end require

(check-equal? (transform-template-prefixes "f\"x\"") "(#%tstring-fpl \"x\")")
(check-equal? (transform-template-prefixes "t\"x\"") "(#%tstring-tpl \"x\")")
(check-equal? (transform-template-prefixes "ft\"x\"") "ft\"x\"")
(check-equal? (transform-template-prefixes "tf\"x\"") "tf\"x\"")
(check-equal? (transform-template-prefixes "#; f\"x\" \"y\"")
              "#; (#%tstring-fpl \"x\") \"y\""
) ; end check-equal?
(check-equal? (transform-template-prefixes "#; 1 f\"x\"")
              "#; 1 (#%tstring-fpl \"x\")"
) ; end check-equal?
(check-equal? (transform-template-prefixes "#; 'f\"x\" \"y\"")
              "#; '(#%tstring-fpl \"x\") \"y\""
) ; end check-equal?

(check-exn exn:fail? (lambda () (transform-template-prefixes "F\"x\"")))
(check-exn exn:fail? (lambda () (transform-template-prefixes "T\"x\"")))
(check-exn exn:fail? (lambda () (transform-template-prefixes "f'x'")))
(check-exn exn:fail? (lambda () (transform-template-prefixes "f\"\"\"x\"\"\"")))
(check-exn exn:fail? (lambda () (transform-template-prefixes "fr\"x\\ny\"")))
(check-exn exn:fail? (lambda () (transform-template-prefixes "rf\"x\\ny\"")))

(define-values (content end-index)
  (find-template-literal-content "f\"hello {name}\" rest" 0)
) ; end define-values

(check-equal? content "hello {name}")
(check-equal? end-index 15)
