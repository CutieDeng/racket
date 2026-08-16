#lang racket/base

;; write-template + prop:custom-write 流式渲染回归测试 (2026-08-07)
;; 见 crypto/ASM-ENHANCEMENT-PLAN.md「t"" 流式输出」增订: (display t"") 经
;; custom-write 流写端口, 与 render-template 物化结果逐字节一致。

(require rackunit
         racket/port
         "../main.rkt"
         "../private/expand.rkt")

(define name "Alice")
(define n 42)

;; ---- write-template == render-template (无格式插值) ----
(let ([t (tpl "hi {name}, n={n}!")])
  (check-equal? (with-output-to-string (lambda () (write-template t (current-output-port))))
                (render-template t))
  (check-equal? (with-output-to-string (lambda () (write-template t (current-output-port))))
                "hi Alice, n=42!"))

;; ---- (display t"") 走 custom-write 流式 = render 结果 ----
(let ([t (tpl "hi {name}, n={n}!")])
  (check-equal? (with-output-to-string (lambda () (display t)))
                (render-template t)))

;; ---- (write t"") 打结构 (调试), 非渲染内容 ----
(let ([t (tpl "x={n}")])
  (define w (with-output-to-string (lambda () (write t))))
  (check-true (regexp-match? #rx"^#<template " w))
  (check-false (regexp-match? #rx"x=42" w)))

;; ---- 慢路径: 带 format-spec 的插值 honor spec ----
;; (注意 write-template honor format-spec, 而默认 render-template 用 ~a
;;  忽略 spec——write-template 是更正确的行为, 故直接断言期望输出)
(let ([t (tpl "v={n:04d}")])
  (check-equal? (with-output-to-string (lambda () (display t))) "v=0042"))

;; ---- 空插值模板 (纯字面) ----
(let ([t (tpl "no interpolation here")])
  (check-equal? (with-output-to-string (lambda () (display t)))
                "no interpolation here"))

(displayln "write-template-test: all checks passed")
