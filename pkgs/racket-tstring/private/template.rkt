#lang racket/base

(provide
 template
 template?
 template-parts
 template-strings
 template-interpolations
 interpolation
 interpolation?
 interpolation-value
 interpolation-syntax
 interpolation-expression
 interpolation-format-spec
 interpolation-conversion
 template-write-hook
) ; end provide

;; 流式渲染钩子: render.rkt 载入时装填 write-template (破 template↔render 环)。
;; 未装填时 (只 require template.rkt) 退化为结构式打印。
(define template-write-hook (box #f))

(define (template-custom-write tpl port mode)
  (define hook (unbox template-write-hook))
  (cond
    ;; display 模式 (mode=#f) + 已装填流式写入器 → 直接流写渲染内容
    [(and (not mode) hook) (hook tpl port)]
    ;; write/print 模式或未装填 → 结构式, 便于调试/可读回
    [else
     (write-string "#<template " port)
     (write (template-data-strings tpl) port)
     (write-string " " port)
     (write (template-data-interpolations tpl) port)
     (write-string ">" port)]))

(struct template-data (strings interpolations)
  #:transparent
  #:reflection-name 'template
  #:property prop:custom-write template-custom-write)
(struct interpolation-data (value syntax format-spec conversion expression)
  #:transparent
  #:reflection-name 'interpolation)

(define (template strings interpolations)
  (template-data strings interpolations)
) ; end define template

(define template? template-data?)
(define template-strings template-data-strings)
(define template-interpolations template-data-interpolations)

(define (interpolation value syntax format-spec conversion (expression #f))
  (interpolation-data value syntax format-spec conversion expression)
) ; end define interpolation

(define interpolation? interpolation-data?)
(define interpolation-value interpolation-data-value)
(define interpolation-syntax interpolation-data-syntax)
(define interpolation-format-spec interpolation-data-format-spec)
(define interpolation-conversion interpolation-data-conversion)
(define interpolation-expression interpolation-data-expression)

(define (template-parts tpl)
  (let loop ((strings (template-strings tpl))
             (interpolations (template-interpolations tpl))
        ) ; end loop bindings
    (cond
      ((null? interpolations)
       strings
      ) ; end no more interpolations
      (else
       (cons (car strings)
             (cons (car interpolations)
                   (loop (cdr strings)
                         (cdr interpolations)
                   ) ; end loop
             ) ; end cons interpolation
       ) ; end cons string
      ) ; end more interpolations
    ) ; end cond
  ) ; end let loop
) ; end define template-parts
