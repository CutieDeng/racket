#lang racket/base

(require
 rackunit
 racket/file
 racket/port
 racket/system
) ; end require

(define (rhombus-available?)
  (with-handlers ((exn:fail?
                   (lambda (_exn)
                     #f
                   ) ; end lambda
                  ) ; end exn:fail?
                 ) ; end handlers
    (collection-file-path "main.rhm" "rhombus")
    #t
  ) ; end with-handlers
) ; end define rhombus-available?

(define (run-rhombus-tstring source)
  (define path (make-temporary-file "tstring-rhombus-~a.rhm"))
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
  (values ok?
          (get-output-string stdout)
          (get-output-string stderr)
  ) ; end values
) ; end define run-rhombus-tstring

(define (check-rhombus-tstring source expected-stdout)
  (define-values (ok? stdout stderr)
    (run-rhombus-tstring source)
  ) ; end define-values
  (unless ok?
    (fail-check
     (string-append "rhombus tstring module failed\nstdout:\n"
                    stdout
                    "\nstderr:\n"
                    stderr
     ) ; end string-append
    ) ; end fail-check
  ) ; end unless
  (check-equal? stdout expected-stdout)
) ; end define check-rhombus-tstring

(when (rhombus-available?)
  (check-rhombus-tstring
   #<<SOURCE
#lang tstring rhombus
let name = "Ada"
let value = 7
let width = 4
println(f"hello {name}")
println(f"padded={value:04d}")
println(f"nested={value:0{width}d}")
println(t"hello {name!r}")
SOURCE
   (string-append
    "hello Ada\n"
    "padded=0007\n"
    "nested=0007\n"
    "template([\"hello \", \"\"], [interpolation(\"Ada\", #'name, #false, \"r\", \"name\")])\n"
   ) ; end string-append
  ) ; end check-rhombus-tstring
) ; end when
