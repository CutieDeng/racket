#lang racket/base

(require
 racket/interaction-info
) ; end require

(provide
 install-tstring-reader!
) ; end provide

(define (install-tstring-reader!)
  (define read-interaction/tstring
    (dynamic-require 'racket-tstring/private/read-syntax
                     'read-interaction/tstring
    ) ; end dynamic-require
  ) ; end define read-interaction/tstring
  (namespace-require '(lib "tstring/main.rkt"))
  (namespace-require '(only (lib "racket-tstring/private/expand.rkt")
                            #%tstring-tpl
                            #%tstring-fpl
                      ) ; end only
  ) ; end namespace-require
  (current-read-interaction read-interaction/tstring)
  ;; Keep the expeditor-based REPL: xrepl only opens expeditor when the
  ;; read interaction is still the boot default or interaction info is
  ;; advertised, so a bare `current-read-interaction` swap would drop
  ;; the REPL to readline/plain mode (";"-prefixed uncolored errors,
  ;; echoed eof, extra newline on empty entries).
  (current-interaction-info '#(racket-tstring/private/interaction-info
                               get-info
                               #f
                             ) ; end info vector
  ) ; end current-interaction-info
) ; end define install-tstring-reader!

(install-tstring-reader!)
