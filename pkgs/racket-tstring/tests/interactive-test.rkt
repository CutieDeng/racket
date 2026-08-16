#lang racket/base

(require
 rackunit
 racket/interaction-info
 (only-in racket-tstring/private/read-syntax
          read/tstring
          read-syntax/tstring
          read-interaction/tstring
 ) ; end only-in
) ; end require

(dynamic-require 'racket/interactive/tstring #f)

(check-eq? (current-read-interaction) read-interaction/tstring)

;; The reader install must also advertise interaction info; otherwise
;; xrepl refuses to open expeditor (the read interaction is no longer
;; the boot default) and the REPL degrades to readline/plain mode.
(check-equal? (current-interaction-info)
              '#(racket-tstring/private/interaction-info
                 get-info
                 #f
               ) ; end info vector
) ; end check-equal? interaction info

(let ((info ((dynamic-require 'racket-tstring/private/interaction-info
                              'get-info
             ) ; end dynamic-require
             #f
            ) ; end get-info application
     )) ; end let bindings
  (define submit? (info 'drracket:submit-predicate #f))
  (check-true (procedure? submit?))
  (check-true (submit? (open-input-string "f\"done\"") #t))
  (check-false (submit? (open-input-string "f\"a") #t))
  (check-false (submit? (open-input-string "f\"a{(+ 1") #t))
  (check-true (submit? (open-input-string "f\"a\nb\"") #t))
  (check-false (submit? (open-input-string "") #t))
  (check-eq? (info 'color-lexer 'default) 'default)
) ; end let interaction info contents

(define read-interaction (current-read-interaction))

(define (read-datum in)
  (define v (read-interaction 'test in))
  (if (syntax? v)
      (syntax->datum v)
      v
  ) ; end if
) ; end define read-datum

(check-equal? (read/tstring (open-input-string "f\"hi\""))
              '(#%tstring-fpl "hi")
) ; end direct read/tstring

(let ((in (open-input-string "f\"hi\" 2\n")))
  (check-equal? (syntax->datum (read-syntax/tstring 'test in))
                '(#%tstring-fpl "hi")
  ) ; end check-equal?
  (check-equal? (syntax->datum (read-syntax/tstring 'test in)) 2)
) ; end let direct read-syntax/tstring

(let ((in (open-input-string "1 2\n")))
  (check-equal? (read-datum in) 1)
  (check-equal? (read-datum in) 2)
  (check-equal? (read-datum in) eof)
) ; end let same line

(let ((in (open-input-string "\n1\n")))
  (check-equal? (read-datum in) 1)
  (check-equal? (read-datum in) eof)
) ; end let leading blank line

(let ((in (open-input-string "; just a comment\n")))
  (check-equal? (read-datum in) eof)
) ; end let comment-only interaction

(let ((in (open-input-string "; just a comment\n1\n")))
  (check-equal? (read-datum in) 1)
  (check-equal? (read-datum in) eof)
) ; end let comment then interaction

(let ((in (open-input-string "1 (2)\n")))
  (check-equal? (read-datum in) 1)
  (check-equal? (read-datum in) '(2))
  (check-equal? (read-datum in) eof)
) ; end let continued interaction

(let ((in (open-input-string "1 (\n")))
  (check-equal? (read-datum in) 1)
  (check-exn exn:fail:read:eof?
             (lambda ()
               (read-datum in)
             ) ; end lambda
  ) ; end check-exn
  (check-equal? (read-datum in) eof)
) ; end let eof after incomplete interaction

(let ((in (open-input-string "(+ 1\n 2) 3\n")))
  (check-equal? (read-datum in) '(+ 1 2))
  (check-equal? (read-datum in) 3)
) ; end let multiline interaction

(let ((in (open-input-string "#\\a2\n")))
  (check-equal? (read-datum in) #\a)
  (check-equal? (read-datum in) 2)
) ; end let reader token boundary

(let ((in (open-input-string "#t2\n")))
  (check-exn exn:fail:read?
             (lambda ()
               (read-datum in)
             ) ; end lambda
  ) ; end check-exn
) ; end let reader token extension

(let ((in (open-input-string "#t2\n3\n")))
  (check-exn exn:fail:read?
             (lambda ()
               (read-datum in)
             ) ; end lambda
  ) ; end check-exn
  (check-equal? (read-datum in) 3)
) ; end let reader error consumes bad interaction

(let ((in (open-input-string "#reader racket/base 1\n")))
  (parameterize ((read-accept-reader #f)
                 (read-accept-lang #t)
                ) ; end parameterize bindings
    (check-equal? (read-datum in) 1)
    (check-equal? (read-datum in) eof)
  ) ; end parameterize
) ; end let read-accept-reader follows standard interaction

(let ((in (open-input-string "#lang racket/base\n")))
  (parameterize ((read-accept-lang #t))
    (check-exn (lambda (exn)
                 (and (exn:fail:read? exn)
                      (regexp-match? #rx"`#lang` not enabled"
                                     (exn-message exn)
                      ) ; end regexp-match?
                 ) ; end and
               ) ; end lambda
               (lambda ()
                 (read-datum in)
               ) ; end lambda
    ) ; end check-exn
    (check-equal? (read-datum in) 'racket/base)
  ) ; end parameterize
) ; end let read-accept-lang disabled for interaction

(let ((in (open-input-string "f\"hi\" 2\n")))
  (check-equal? (read-datum in) '(#%tstring-fpl "hi"))
  (check-equal? (read-datum in) 2)
) ; end let template string

(let ((in (open-input-string "#; f\"hi\" \"ok\"\n")))
  (check-equal? (read-datum in) "ok")
  (check-equal? (read-datum in) eof)
) ; end let datum-commented template string

(let ((in (open-input-string "#; 1 f\"hi\"\n")))
  (check-equal? (read-datum in) '(#%tstring-fpl "hi"))
  (check-equal? (read-datum in) eof)
) ; end let template string after datum comment

(let ((in (open-input-string (string-append "\u03BB f\"\u00E9\" 2\n"))))
  (check-equal? (read-datum in) (string->symbol "\u03BB"))
  (check-equal? (read-datum in) '(#%tstring-fpl "\u00E9"))
  (check-equal? (read-datum in) 2)
) ; end let unicode source position mapping

(let ((first-in (open-input-string "1 2\n"))
      (second-in (open-input-string "3\n"))
     ) ; end bindings
  (check-equal? (read-datum first-in) 1)
  (check-equal? (read-datum second-in) 3)
  (check-equal? (read-datum first-in) 2)
) ; end let per port
