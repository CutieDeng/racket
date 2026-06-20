#lang racket/base

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
) ; end define install-tstring-reader!

(install-tstring-reader!)
