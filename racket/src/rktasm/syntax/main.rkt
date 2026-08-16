#lang racket

;; ============================================================
;; Syntax Module - 语法描述主入口
;; ============================================================
;;
;; 提供:
;; 1. 指令规范 (spec.rkt) - 核心数据与缓存
;; 2. 验证器 (validator.rkt) - 三层验证
;; 3. 操作数类型 (operand-type.rkt) - Layer2 类型定义
;; 4. 约束 (constraint.rkt) - Layer3 约束定义
;; 5. 语法类 (class.rkt) - Layer1 类定义
;;
;; 使用示例:
;;   (require "syntax/main.rkt"
;;            "parser/parser.rkt")
;;
;;   (define ins (parse-instruction '(add x0 x1 x2)))
;;   (define result (validate-instruction ins))
;;   (displayln (format-validation-result result))

(require "spec.rkt"
         "validator.rkt"
         "operand-type.rkt"
         "constraint.rkt"
         "class.rkt")

;; Re-export spec.rkt (核心数据接口)
(provide
  ;; 数据库访问
  get-spec-db
  get-mnemonic-index
  get-layer1-index
  get-layer2-index
  get-integrated-table

  ;; 查询接口
  lookup-by-mnemonic
  lookup-layer1-classes
  lookup-layer2-sigs
  lookup-encodings

  ;; 计算接口 (带缓存)
  template->layer2/cached
  layer2->layer1/cached

  ;; 缓存控制
  clear-all-caches!
  preload-all!)

;; Re-export validator.rkt (三层验证器)
(provide
  validate-instruction
  (struct-out validation-result)
  validation-ok?
  validation-error?
  format-validation-result)

;; Re-export operand-type.rkt (Layer2)
(provide
  operand-type?
  operand-type->string
  parse-template-signature
  classify-ast-operand
  signature-matches?
  operand-type-compatible?)

;; Re-export constraint.rkt (Layer3)
(provide
  (struct-out reg-range)
  (struct-out imm-range)
  (struct-out imm-values)
  (struct-out arrangement)
  (struct-out element-size)
  (struct-out pred-mode-constraint)
  validate-constraint
  check-reg-range
  check-imm-range
  check-imm-values)

;; Re-export class.rkt (Layer1)
(provide
  syntax-class?
  classify-operand-count
  has-memory?
  has-post-index?
  get-pre-count
  get-post-count)
