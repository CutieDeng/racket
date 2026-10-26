(library (regexp)
  (export)
  (import (rename (chezpart)
                  [define chez:define])
          (rename (rumble)
                  ;; Remapped to place-local register operations:
                  [unsafe-make-place-local rumble:unsafe-make-place-local]
                  [unsafe-place-local-ref rumble:unsafe-place-local-ref]
                  [unsafe-place-local-set! rumble:unsafe-place-local-set!])
          (io))
  ;; TEMP-STAMPS
  (chez:define boot-stamp-regexp
    (and (#%getenv "PLT_BOOT_STAMPS")
         (let ([t (#%current-time 'time-monotonic)])
           (#%fprintf (#%current-error-port) "STAMP layer-regexp ~a ~a 0\n"
                      (+ (* 1000.0 (#%time-second t)) (/ (#%time-nanosecond t) 1000000.0))
                      (#%cpu-time))
           #t)))


  (include "place-register.ss")
  (define-place-register-define define regexp-register-start regexp-register-count)

  (include "include.ss")
  (include-generated "regexp.scm")

  (define (any-regexp? v)
    (or (1/regexp? v)
        (1/byte-regexp? v)))

  (set-intern-regexp?! any-regexp?)
  (set-printable-regexp?! any-regexp?))
