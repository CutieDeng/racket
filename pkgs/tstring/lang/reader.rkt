#lang racket/base

(require
 racket/port
 racket/runtime-path
 syntax/module-reader
 syntax/readerr
 (file "../../racket-tstring/private/source-transform.rkt")
) ; end require

(provide
 (rename-out (tstring-read read)
             (tstring-read-syntax read-syntax)
             (tstring-get-info get-info)
 ) ; end rename-out
) ; end provide

(define-runtime-path main-rkt "../main.rkt")
(define-runtime-path expand-rkt "../../racket-tstring/private/expand.rkt")

(define (wrap-reader proc)
  (lambda args
    (define-values (prefix port suffix)
      (split-reader-args args)
    ) ; end define-values
    (define-values (language-prefix source-body)
      (split-language-prefix (port->string port))
    ) ; end define-values
    (define transformed-port
      (open-input-string
       (string-append language-prefix
                      (format "(require (file ~s))\n" (path->string main-rkt))
                      (format "(require (only-in (file ~s) #%tstring-tpl #%tstring-fpl))\n"
                              (path->string expand-rkt)
                      ) ; end format
                      (transform-with-read-errors source-body port)
       ) ; end string-append
      ) ; end open-input-string
    ) ; end define transformed-port
    (port-count-lines! transformed-port)
    (apply proc
           (append prefix
                   (list transformed-port)
                   suffix
           ) ; end append
    ) ; end apply
  ) ; end lambda
) ; end define wrap-reader

(define (split-reader-args args)
  (let loop ((prefix '())
             (rest args)
        ) ; end loop bindings
    (cond
      ((null? rest)
       (error 'tstring-reader "reader arguments do not include an input port")
      ) ; end no port
      ((input-port? (car rest))
       (values (reverse prefix)
               (car rest)
               (cdr rest)
       ) ; end values
      ) ; end found port
      (else
       (loop (cons (car rest) prefix)
             (cdr rest)
       ) ; end loop
      ) ; end keep searching
    ) ; end cond
  ) ; end let loop
) ; end define split-reader-args

(define (split-language-prefix source)
  (define match
    (regexp-match-positions #px"^[ \t]+[A-Za-z0-9_+./-][^\r\n]*(?:\r\n|\r|\n)?"
                            source
    ) ; end regexp-match-positions
  ) ; end define match
  (cond
    (match
     (define end (cdar match))
     (values (if (or (zero? end)
                     (member (string-ref source (sub1 end)) '(#\newline #\return))
                 ) ; end or
                 (substring source 0 end)
                 (string-append (substring source 0 end) "\n")
             ) ; end if
             (substring source end)
     ) ; end values
    ) ; end match
    (else
     (values "" source)
    ) ; end else
  ) ; end cond
) ; end define split-language-prefix

(define (transform-with-read-errors source port)
  (with-handlers ((exn:fail?
                   (lambda (exn)
                     (raise-read-error (exn-message exn)
                                       (object-name port)
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
) ; end define transform-with-read-errors

(define-values (tstring-read tstring-read-syntax tstring-get-info)
  (make-meta-reader 'tstring
                    "language path"
                    lang-reader-module-paths
                    wrap-reader
                    wrap-reader
                    (lambda (proc)
                      (lambda (key default)
                        (if proc
                            (proc key default)
                            default
                        ) ; end if
                      ) ; end lambda
                    ) ; end get-info wrapper
  ) ; end make-meta-reader
) ; end define-values
