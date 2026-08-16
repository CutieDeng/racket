#lang racket/base

;; asm/gen/gw.rkt — 发射器公共入口: 定位 rktasm 并 re-export gnu-writer。
;;
;; rktasm (原 asmp) 是开发期依赖 (见 asm/README.md), 在树内与 crypto 平级
;; (racket/src/rktasm), 不进构建图; 默认相对定位, 可用 RKTASM 环境变量覆盖
;; (与 regen.sh 同款约定), dynamic-require 取绑定。
;; 所有 asm/gen/*.rkt 发射器统一 (require "gw.rkt"), 不各自散落路径逻辑。

(require (for-syntax racket/base)
         racket/runtime-path)

;; gw.rkt 位于 crypto/asm/gen/ → 上三级到 racket/src/, 再进 rktasm
(define-runtime-path default-rktasm-dir "../../../rktasm")

(define rktasm-dir
  (or (getenv "RKTASM") default-rktasm-dir))

(define gnu-writer-path
  (build-path rktasm-dir "parser" "gnu-writer.rkt"))
(define ast-path
  (build-path rktasm-dir "parser" "ast.rkt"))
(define sched-model-path
  (build-path rktasm-dir "pipeline" "sched-model.rkt"))

(unless (file-exists? gnu-writer-path)
  (error 'asm/gen "rktasm 未找到 (设 RKTASM 环境变量): ~a" gnu-writer-path))

(define-syntax-rule (reexport-from path name ...)
  (begin
    (begin (define name (dynamic-require path 'name)) ...)
    (provide name ...)))

(reexport-from gnu-writer-path
 ;; 操作数构造器
 rx rw rv rq rd rs-reg xzr wzr rsp
 im lab sh ext cnd mem mem-pre mem-post regs
 ;; 行构造器
 ins lbl doc rem blank
 fn-begin fn-end save-all restore-all save-regs restore-regs ctx-decl
 ;; 序列化/解析
 gnu-program->string write-gnu-program parse-gnu-file->items ast-strip-loc)

;; AST 访问器 (sched-cost 等分析工具读发射器产出的指令流)
(reexport-from ast-path
 ast-ins? ast-ins-mnemonic ast-ins-operands
 ast-reg? ast-reg-kind ast-reg-id
 ast-mem? ast-mem-base ast-mem-offset
 ast-reglist? ast-reglist-regs)

;; 调度模型查询 (静态成本估算, 与 asmp 装配用同一 apple-m 模型)
(reexport-from sched-model-path
 current-sched-model model-latency model-port model-port-capacity
 sched-model-issue-width)
