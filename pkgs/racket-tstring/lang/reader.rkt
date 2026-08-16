#lang racket/base

(require
 racket/port
 racket/runtime-path
 syntax/strip-context
 syntax/readerr
 "../private/source-transform.rkt"
) ; end require

(provide
 read
 read-syntax
 get-info
) ; end provide

(define-runtime-path main-rkt "../main.rkt")
(define-runtime-path expand-rkt "../private/expand.rkt")

(define base-read-syntax
  (dynamic-require 'racket/base 'read-syntax)
) ; end define base-read-syntax

(define (read in)
  (syntax->datum (read-syntax #f in))
) ; end define read

(define (read-syntax path in)
  (port-count-lines! in)
  (define-values (start-line start-column start-position)
    (port-next-location in)
  ) ; end define-values
  (define source (port->string in))
  (define transformed-body
    (with-handlers ((exn:fail?
                     (lambda (exn)
                       (raise-read-error (exn-message exn)
                                         path
                                         #f
                                         #f
                                         #f
                                         #f
                       ) ; end raise-read-error
                     ) ; end lambda
                    ) ; end exn:fail?
                   ) ; end handlers
      (transform-template-prefixes source)
    ) ; end with-handlers
  ) ; end define transformed-body
  (define transformed-in (open-input-string transformed-body))
  (port-count-lines! transformed-in)
  (when start-line
    (set-port-next-location! transformed-in
                             start-line
                             start-column
                             start-position
    ) ; end set-port-next-location!
  ) ; end when line
  (define body-forms (map strip-context (read-all-syntax path transformed-in)))
  (define module-name-stx
    (datum->syntax #f (module-name-from-path path))
  ) ; end define module-name-stx
  (strip-context
   #`(module #,module-name-stx racket/base
       (require (file #,(path->string main-rkt)))
       (require (only-in (file #,(path->string expand-rkt))
                         #%tstring-tpl
                         #%tstring-fpl
                ) ; end only-in
       ) ; end require
       #,@body-forms
     ) ; end module
  ) ; end strip-context
) ; end define read-syntax

(define (read-all-syntax path in)
  (let loop ((forms '()))
    (define form (base-read-syntax path in))
    (cond
      ((eof-object? form)
       (reverse forms)
      ) ; end eof
      (else
       (loop (cons form forms))
      ) ; end form
    ) ; end cond
  ) ; end let loop
) ; end define read-all-syntax

(define (module-name-from-path path)
  (cond
    ((path? path)
     (define-values (_base name _dir?) (split-path path))
     (string->symbol
      (path->string (path-replace-extension name #""))
     ) ; end string->symbol
    ) ; end path
    ((symbol? path)
     path
    ) ; end symbol
    (else
     'anonymous-module
    ) ; end fallback
  ) ; end cond
) ; end define module-name-from-path

(define (get-info key default default-filter)
  (default-filter key default)
) ; end define get-info
