#lang racket/base

(require
 racket/port
 racket/match
 syntax/module-reader
 syntax/readerr
 (only-in racket-tstring/private/source-transform
          transform-template-prefixes)
) ; end require

(provide
 (rename-out (tstring-read read)
             (tstring-read-syntax read-syntax)
             (tstring-get-info get-info)
 ) ; end rename-out
) ; end provide

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
                      (transform-with-read-errors source-body port)
       ) ; end string-append
      ) ; end open-input-string
    ) ; end define transformed-port
    (port-count-lines! transformed-port)
    (inject-tstring-requires
     (apply proc
            (append prefix
                    (list transformed-port)
                    suffix
            ) ; end append
     ) ; end apply
    ) ; end inject-tstring-requires
  ) ; end lambda
) ; end define wrap-reader

(define (inject-tstring-requires stx-or-datum)
  (cond
    ((syntax? stx-or-datum)
     (inject-tstring-requires/syntax stx-or-datum)
    ) ; end syntax
    (else
     (inject-tstring-requires/datum stx-or-datum)
    ) ; end datum
  ) ; end cond
) ; end define inject-tstring-requires

(define (inject-tstring-requires/syntax stx)
  (syntax-case stx ()
    ((module-form name lang (module-begin . more) . even-more)
     (with-syntax ((main-req (datum->syntax stx '(require tstring) stx))
                   (expand-req
                    (datum->syntax
                     stx
                     '(require (only-in racket-tstring/private/expand
                                        #%tstring-tpl
                                        #%tstring-fpl))
                     stx
                    ) ; end datum->syntax
                   ) ; end expand-req
              ) ; end with-syntax bindings
       #'(module-form name lang
           (module-begin main-req expand-req . more)
           . even-more)
     ) ; end with-syntax
    ) ; end module
    (_
     stx
    ) ; end non-module
  ) ; end syntax-case
) ; end define inject-tstring-requires/syntax

(define (inject-tstring-requires/datum datum)
  (match datum
    ((list* module-form name lang (list* module-begin more) even-more)
     (list* module-form
            name
            lang
            (list* module-begin
                   '(require tstring)
                   '(require (only-in racket-tstring/private/expand
                                      #%tstring-tpl
                                      #%tstring-fpl))
                   more
            ) ; end list* module body
            even-more
     ) ; end list*
    ) ; end module datum
    (_
     datum
    ) ; end non-module datum
  ) ; end match
) ; end define inject-tstring-requires/datum

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
