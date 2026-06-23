#lang racket/base

(require
 racket/format
 (only-in racket-tstring/private/render
          format-fstring-value)
 (only-in racket-tstring/private/template
          template
          interpolation)
) ; end require

(provide
 rhombus_tstring_concat
 rhombus_tstring_format
 rhombus_tstring_template
 rhombus_tstring_interpolation
) ; end provide

(define (rhombus_tstring_concat . parts)
  (apply string-append
         (map ~a parts)
  ) ; end apply
) ; end define rhombus_tstring_concat

(define (rhombus_tstring_format value format-spec conversion)
  (format-fstring-value value
                        (and format-spec (~a format-spec))
                        (~a conversion)
  ) ; end format-fstring-value
) ; end define rhombus_tstring_format

(define (rhombus_tstring_template strings interpolations)
  (template strings interpolations)
) ; end define rhombus_tstring_template

(define (rhombus_tstring_interpolation value stx format-spec conversion expression-source)
  (interpolation value
                 stx
                 (and format-spec (~a format-spec))
                 (~a conversion)
                 (~a expression-source)
  ) ; end interpolation
) ; end define rhombus_tstring_interpolation
