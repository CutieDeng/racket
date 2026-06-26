#lang racket/base

(require "config.rkt"
         "special.rkt"
         "wrap.rkt"
         "error.rkt"
         "parameter.rkt"
         racket/private/primitive-table
) ; end require

(provide read-intmap
) ; end provide

(import-from-primitive-table
 #%kernel
 [core-intmap-literal->intmap core-intmap-literal->intmap]
) ; end import-from-primitive-table

(define (read-core-intmap-literal->intmap datum
        ) ; end read-core-intmap-literal->intmap
  (unless core-intmap-literal->intmap
    (error 'core-intmap-literal->intmap
           "native intmap literal input is not available"
    ) ; end error
  ) ; end unless
  (core-intmap-literal->intmap datum
  ) ; end core-intmap-literal->intmap
) ; end define

(define (discard-current-line in config
        ) ; end discard-current-line
  (let loop (
            ) ; end let args
    (define c (peek-char/special in config
              ) ; end peek-char/special
    ) ; end define
    (unless (or (eof-object? c
                ) ; end eof-object?
                (eqv? c #\newline
                ) ; end eqv?
            ) ; end or
      (read-char/special in config
      ) ; end read-char/special
      (loop
      ) ; end loop
    ) ; end unless
  ) ; end let
) ; end define

(define (read-expect-char expected accum-str in config
        ) ; end read-expect-char
  (define c (read-char/special in config
            ) ; end read-char/special
  ) ; end define
  (unless (eqv? c expected
          ) ; end eqv?
    (discard-current-line in config
    ) ; end discard-current-line
    (reader-error in config
                  #:due-to c
                  "expected `~a` to continue `#intmap` after `~a`"
                  expected
                  accum-str
    ) ; end reader-error
  ) ; end unless
  c
) ; end define

;; `#in` has been read.
(define (read-intmap read-one dispatch-c init-c second-c accum-str in config
        ) ; end read-intmap
  (unless (check-parameter read-accept-intmap config
          ) ; end check-parameter
    (discard-current-line in config
    ) ; end discard-current-line
    (reader-error in config "`#intmap` forms not enabled"
    ) ; end reader-error
  ) ; end unless
  (define chars (list #\t #\m #\a #\p
                ) ; end list
  ) ; end define
  (let loop ([chars chars] [accum-str accum-str
                           ] ; end accum-str
            ) ; end let args
    (cond
      [(null? chars)
       (define datum (read-one #f in (disable-wrapping config
                                     ) ; end disable-wrapping
                     ) ; end read-one
       ) ; end define
       (wrap (catch-and-reraise-as-reader
              in
              config
              (read-core-intmap-literal->intmap datum
              ) ; end read-core-intmap-literal->intmap
             ) ; end catch-and-reraise-as-reader
             in
             config
             init-c
       ) ; end wrap
      ] ; end clause
      [else
       (define c (read-expect-char (car chars
                                      ) ; end car
                                    accum-str
                                    in
                                    config
                 ) ; end read-expect-char
       ) ; end define
       (loop (cdr chars
             ) ; end cdr
             (string-append accum-str (string c
                                      ) ; end string
             ) ; end string-append
       ) ; end loop
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define
