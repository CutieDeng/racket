#lang racket/base

(require
 racket/interaction-info
) ; end require

(provide
 install-tstring-reader!
) ; end provide

(define (install-tstring-reader!)
  ;; Loading the tstring reader and its bindings costs tens of
  ;; milliseconds, so the prompt appears first: this shim loads the
  ;; real reader on the first interaction and replaces itself.
  (define real-reader #f)
  (define (force-tstring-reader!)
    (unless real-reader
      (set! real-reader
            (dynamic-require 'racket-tstring/private/read-syntax
                             'read-interaction/tstring
            ) ; end dynamic-require
      ) ; end set!
      (namespace-require '(lib "tstring/main.rkt"))
      (namespace-require '(only (lib "racket-tstring/private/expand.rkt")
                                #%tstring-tpl
                                #%tstring-fpl
                          ) ; end only
      ) ; end namespace-require
    ) ; end unless
    real-reader
  ) ; end define force-tstring-reader!
  (define (lazy-read-interaction src in)
    ((force-tstring-reader!) src in)
  ) ; end define lazy-read-interaction
  (current-read-interaction lazy-read-interaction)
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
