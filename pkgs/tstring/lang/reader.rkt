#lang racket/base

(require
 racket/port
 racket/match
 racket/string
 syntax/module-reader
 syntax/readerr
 (only-in tstring/private/rhombus-source-transform
          rhombus-runtime-import-source
          transform-rhombus-template-prefixes)
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
    (define source (port->string port))
    (define maybe-raw-module
      (try-read-target proc prefix suffix source)
    ) ; end define maybe-raw-module
    (cond
      ((and maybe-raw-module
            (rhombus-module? maybe-raw-module)
       ) ; end and
       (define transformed-rhombus-port
         (open-input-string
          (string-append rhombus-runtime-import-source
                         (transform-rhombus-template-prefixes source port)
          ) ; end string-append
         ) ; end open-input-string
       ) ; end define transformed-rhombus-port
       (port-count-lines! transformed-rhombus-port)
       (apply proc
              (append prefix
                      (list transformed-rhombus-port)
                      suffix
              ) ; end append
       ) ; end apply
      ) ; end rhombus
      (else
       (define transformed-port
         (open-input-string
          (transform-with-read-errors source port)
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
      ) ; end other target language
    ) ; end cond
  ) ; end lambda
) ; end define wrap-reader

(define (try-read-target proc prefix suffix source)
  (with-handlers ((exn:fail?
                   (lambda (_exn)
                     #f
                   ) ; end lambda
                  ) ; end exn:fail?
                 ) ; end handlers
    (define raw-port (open-input-string source))
    (port-count-lines! raw-port)
    (apply proc
           (append prefix
                   (list raw-port)
                   suffix
           ) ; end append
    ) ; end apply
  ) ; end with-handlers
) ; end define try-read-target

(define (rhombus-module? stx-or-datum)
  (define datum
    (if (syntax? stx-or-datum)
        (syntax->datum stx-or-datum)
        stx-or-datum
    ) ; end if
  ) ; end define datum
  (match datum
    ((list* 'module _name lang _body)
     (rhombus-language-datum? lang)
    ) ; end module
    (_ #f)
  ) ; end match
) ; end define rhombus-module?

(define (rhombus-language-datum? lang)
  (cond
    ((symbol? lang)
     (rhombus-language-name? (symbol->string lang))
    ) ; end symbol
    ((and (pair? lang)
          (eq? (car lang) 'quote)
          (pair? (cdr lang))
          (symbol? (cadr lang))
     ) ; end and
     (rhombus-language-name? (symbol->string (cadr lang)))
    ) ; end quoted symbol
    ((and (pair? lang)
          (eq? (car lang) 'lib)
          (pair? (cdr lang))
          (string? (cadr lang))
     ) ; end and
     (rhombus-library-path? (cadr lang))
    ) ; end lib path
    (else
     #f
    ) ; end unsupported module path
  ) ; end cond
) ; end define rhombus-language-datum?

(define (rhombus-language-name? name)
  (or (equal? name "rhombus")
      (string-prefix? name "rhombus/")
  ) ; end or
) ; end define rhombus-language-name?

(define (rhombus-library-path? path)
  (or (equal? path "rhombus/main.rhm")
      (string-prefix? path "rhombus/")
  ) ; end or
) ; end define rhombus-library-path?

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
