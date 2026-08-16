#lang racket/base

(require
 rackunit
 racket/file
 racket/port
 racket/system
) ; end require

(define (typed-racket-available?)
  (with-handlers ((exn:fail?
                   (lambda (_exn)
                     #f
                   ) ; end lambda
                  ) ; end exn:fail?
                 ) ; end handlers
    (collection-file-path "reader.rkt" "typed" "racket")
    #t
  ) ; end with-handlers
) ; end define typed-racket-available?

(define (check-typed-module source)
  (define path (make-temporary-file "tstring-typed-~a.rkt"))
  (call-with-output-file path
    (lambda (out)
      (display source out)
    ) ; end lambda
    #:exists 'truncate
  ) ; end call-with-output-file
  (define racket-exe (find-system-path 'exec-file))
  (define stdout (open-output-string))
  (define stderr (open-output-string))
  (define ok?
    (parameterize ((current-output-port stdout)
                   (current-error-port stderr)
                  ) ; end parameterize bindings
      (system* racket-exe "-y" (path->string path))
    ) ; end parameterize
  ) ; end define ok?
  (delete-file path)
  (unless ok?
    (fail-check
     (string-append "typed tstring module failed\nstdout:\n"
                    (get-output-string stdout)
                    "\nstderr:\n"
                    (get-output-string stderr)
     ) ; end string-append
    ) ; end fail-check
  ) ; end unless
) ; end define check-typed-module

(cond
  ((typed-racket-available?)
   (check-typed-module
    #<<SOURCE
#lang tstring typed/racket

(: name String)
(define name "Alice")

(: rendered String)
(define rendered f"hello {name}")

(: value Real)
(define value 3.14159)

(: precision Integer)
(define precision 2)

(: formatted-rendered String)
(define formatted-rendered f"pi={value:.{precision}f}")

(: template-value Template)
(define template-value t"hello {name}")

(: rendered-from-template String)
(define rendered-from-template (render-fstring template-value))

(: rendered-with-keyword String)
(define rendered-with-keyword
  (render-template template-value
                   #:value->string (lambda ([value : Any])
                                     "slot"
                                   ) ; end lambda
  ) ; end render-template
)

(: interpolation-values (Listof Any))
(define interpolation-values
  (map interpolation-value (template-interpolations template-value))
)

(: interpolation-expressions (Listof (U False String)))
(define interpolation-expressions
  (map interpolation-expression (template-interpolations template-value))
)

(: interpolation-syntaxes (Listof (Syntaxof Any)))
(define interpolation-syntaxes
  (map interpolation-syntax (template-interpolations template-value))
)

(unless (equal? rendered "hello Alice")
  (error 'typed-tstring "bad f-string result"))
(unless (equal? formatted-rendered "pi=3.14")
  (error 'typed-tstring "bad nested format result"))
(unless (equal? rendered-from-template "hello Alice")
  (error 'typed-tstring "bad template render result"))
(unless (equal? rendered-with-keyword "hello slot")
  (error 'typed-tstring "bad keyword render result"))
(unless (equal? interpolation-values (list "Alice"))
  (error 'typed-tstring "bad interpolation values"))
(unless (equal? interpolation-expressions (list "name"))
  (error 'typed-tstring "bad interpolation expressions"))
(unless (and (= (length interpolation-syntaxes) 1)
             (identifier? (car interpolation-syntaxes)))
  (error 'typed-tstring "bad interpolation syntax"))
SOURCE
   ) ; end check typed/racket
   (check-typed-module
    #<<SOURCE
#lang tstring typed/racket/base

(: name String)
(define name "Alice")

(: rendered String)
(define rendered f"hello {name}")

(: template-value Template)
(define template-value t"hello {name}")

(: rendered-from-template String)
(define rendered-from-template (render-template template-value))

(unless (equal? rendered "hello Alice")
  (error 'typed-tstring-base "bad f-string result"))
(unless (equal? rendered-from-template "hello Alice")
  (error 'typed-tstring-base "bad template render result"))
SOURCE
   ) ; end check typed/racket/base
  ) ; end typed-racket available
  (else
   (displayln "typed/racket not available; skipping tstring typed wrapper tests")
  ) ; end skip
) ; end cond
