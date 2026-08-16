#lang racket

;; ============================================================
;; pipeline/regalloc/spill-config.rkt - 溢出策略配置
;; ============================================================

(provide
  ;; 数量约束
  (struct-out at-most)
  count-spec?
  count-spec-max
  count-spec-exact?

  ;; 指令选择
  (struct-out insn-selection)
  default-insn-selection
  conservative-insn-selection
  strict-insn-selection

  ;; 溢出区域
  (struct-out spill-region)

  ;; 溢出配置
  (struct-out spill-config)
  default-spill-config
  no-spill-config

  ;; save!/load! 验证级别
  save-load-verify-level

  ;; 查询
  spill-allowed?
  spill-region-allows?)

;; ============================================================
;; 数量约束
;; ============================================================

;; 'any      - 任意条 (*)
;; n         - 恰好 n 条，不足补 nop
;; (at-most n) - 最多 n 条

(struct at-most (n) #:transparent)

(define (count-spec? v)
  (or (eq? v 'any)
      (and (integer? v) (>= v 0))
      (at-most? v)))

;; 获取最大允许数量
(define (count-spec-max spec)
  (cond
    [(eq? spec 'any) +inf.0]
    [(integer? spec) spec]
    [(at-most? spec) (at-most-n spec)]))

;; 是否要求精确数量
(define (count-spec-exact? spec)
  (integer? spec))

;; ============================================================
;; 指令选择
;; ============================================================

(struct insn-selection
  (allow-paired?           ; 中间代码允许 stp/ldp
   allow-paired-prologue?  ; 函数序言允许成对（x29, x30, callee-saved）
   allow-paired-epilogue?) ; 函数尾声允许成对
  #:transparent)

;; 默认：全部允许成对
(define default-insn-selection
  (insn-selection #t #t #t))

;; 保守：中间代码不用成对，序言尾声可以
(define conservative-insn-selection
  (insn-selection #f #t #t))

;; 严格：全部只用单条
(define strict-insn-selection
  (insn-selection #f #f #f))

;; ============================================================
;; 溢出区域配置
;; ============================================================

(struct spill-region
  (save-spec        ; count-spec - save 指令数量约束
   load-spec        ; count-spec - load 指令数量约束
   selection)       ; insn-selection
  #:transparent)

;; ============================================================
;; 溢出配置
;; ============================================================

(struct spill-config
  (enabled?         ; 是否允许溢出
   call-region      ; spill-region | #f - 函数调用点
   general-region   ; spill-region | #f - 一般溢出点
   prologue         ; insn-selection - 函数序言
   epilogue         ; insn-selection - 函数尾声
   cost-fn)         ; (reg-id context -> number) | #f - 溢出代价
  #:transparent)

;; 默认配置：允许溢出，无限制
(define default-spill-config
  (spill-config
    #t                                                    ; enabled
    (spill-region 'any 'any default-insn-selection)       ; call
    (spill-region 'any 'any default-insn-selection)       ; general
    default-insn-selection                                ; prologue
    default-insn-selection                                ; epilogue
    #f))                                                  ; cost-fn

;; 禁止溢出
(define no-spill-config
  (spill-config #f #f #f strict-insn-selection strict-insn-selection #f))

;; ============================================================
;; 查询函数
;; ============================================================

(define (spill-allowed? config)
  (and config (spill-config-enabled? config)))

;; 检查溢出区域是否允许指定数量的指令
(define (spill-region-allows? region count)
  (and region
       (<= count (count-spec-max (spill-region-save-spec region)))))

;; ============================================================
;; save!/load! 验证参数
;; ============================================================
;;
;; 控制 (: save! all) / (: load! all) 配对验证：
;;   'suppress  - 不检查，不输出信息
;;   'expected  - 不检查，但输出调试信息
;;   'warning   - 检查，未配对时输出警告（默认）
;;   'error     - 检查，未配对时报错

(define save-load-verify-level (make-parameter 'warning))
