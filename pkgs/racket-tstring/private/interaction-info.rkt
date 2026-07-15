#lang racket/base

;; Interaction info for the tstring REPL reader, in the shape expected
;; by `current-interaction-info`: `((get-info data) key default)`.
;; Advertising this info lets xrepl keep the expeditor line editor even
;; though `current-read-interaction` is no longer the boot default, so
;; the REPL keeps the stock terminal behavior (colored errors without a
;; ";" prefix, silent eof exit, no-op empty entries). Every key other
;; than the submit predicate defers to the editor's defaults.

(require
 "read-syntax.rkt"
) ; end require

(provide
 get-info
) ; end provide

(define (get-info data)
  (lambda (key default)
    (case key
      ((drracket:submit-predicate)
       interaction-ready?/tstring
      ) ; end submit predicate
      (else
       default
      ) ; end other keys
    ) ; end case
  ) ; end lambda
) ; end define get-info
