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
     (with-syntax (((injected-req ...)
                    (map (lambda (datum)
                           (datum->syntax stx datum stx)
                         ) ; end lambda
                         (injected-require-datums (syntax->datum #'lang))
                    ) ; end map
                   ) ; end injected-req
                  ) ; end with-syntax bindings
       #'(module-form name lang
           (module-begin injected-req ... . more)
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
     (define injected-requires (injected-require-datums lang))
     (list* module-form
            name
            lang
            (cons module-begin
                  (append injected-requires more)
            ) ; end cons module body
            even-more
     ) ; end list*
    ) ; end module datum
    (_
     datum
    ) ; end non-module datum
  ) ; end match
) ; end define inject-tstring-requires/datum

(define (injected-require-datums lang)
  (if (typed-target-language? lang)
      typed-require-datums
      untyped-require-datums
  ) ; end if
) ; end define injected-require-datums

(define (typed-target-language? lang)
  (define symbol (language-symbol lang))
  (and symbol
       (memq symbol '(typed/racket typed/racket/base))
  ) ; end and
) ; end define typed-target-language?

(define (language-symbol lang)
  (cond
    ((symbol? lang)
     lang
    ) ; end symbol
    ((and (pair? lang)
          (eq? (car lang) 'quote)
          (pair? (cdr lang))
          (symbol? (cadr lang))
     ) ; end and
     (cadr lang)
    ) ; end quoted symbol
    (else
     #f
    ) ; end unsupported module path
  ) ; end cond
) ; end define language-symbol

(define untyped-require-datums
  '((require tstring)
    (require (only-in racket-tstring/private/expand
                      #%tstring-tpl
                      #%tstring-fpl))
   ) ; end quote
) ; end define untyped-require-datums

(define typed-require-datums
  '((require/typed racket-tstring
      [#:opaque Template template?]
      [#:opaque Interpolation interpolation?]
      [template (-> (Listof String) (Listof Interpolation) Template)]
      [template-parts (-> Template (Listof (U String Interpolation)))]
      [template-strings (-> Template (Listof String))]
      [template-interpolations (-> Template (Listof Interpolation))]
      [interpolation (->* (Any Syntax (U False String) String)
                          ((U False String))
                          Interpolation)]
      [interpolation-value (-> Interpolation Any)]
      [interpolation-expression (-> Interpolation (U False String))]
      [interpolation-format-spec (-> Interpolation (U False String))]
      [interpolation-conversion (-> Interpolation String)]
      [render-template (->* (Template)
                            (#:interpolation->string (-> Interpolation Any)
                             #:value->string (-> Any String))
                            String)]
      [render-fstring (-> Template String)]
      [template->sql (-> Template (Values String (Listof Any)))]
      [html-render (->* (Template)
                        (#:interpolation->string (-> Interpolation Any))
                        String)]
      [parse-template-string (-> String (Values (Listof String) (Listof String)))])
    (require/typed (only-in racket-tstring/private/render
                            [format-fstring-value #%tstring-format-fstring-value])
      [#%tstring-format-fstring-value (-> Any (U False String) String String)])
    (require/typed (only-in racket-tstring/private/template
                            [template #%tstring-template]
                            [interpolation #%tstring-interpolation]
                            [interpolation-syntax #%tstring-raw-interpolation-syntax])
      [#%tstring-template (-> (Listof String) (Listof Interpolation) Template)]
      [#%tstring-interpolation (->* (Any Syntax (U False String) String)
                                    ((U False String))
                                    Interpolation)]
      [#%tstring-raw-interpolation-syntax (-> Interpolation Any)])
    (: interpolation-syntax (-> Interpolation (Syntaxof Any)))
    (define (interpolation-syntax interpolation-value)
      (assert (#%tstring-raw-interpolation-syntax interpolation-value) syntax?)
    ) ; end define interpolation-syntax
    (require (only-in racket-tstring/private/expand
                      [typed-tpl #%tstring-tpl]
                      [typed-fpl #%tstring-fpl]))
   ) ; end quote
) ; end define typed-require-datums

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
