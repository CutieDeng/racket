#lang racket

(provide
  ;; 约束类型
  (struct-out reg-range)
  (struct-out imm-range)
  (struct-out imm-values)
  (struct-out arrangement)
  (struct-out element-size)
  (struct-out pred-mode-constraint)

  ;; 约束验证
  validate-constraint
  check-reg-range
  check-imm-range
  check-imm-values

  ;; 约束提取
  width-to-reg-range
  extract-reg-constraint-from-width)

;; ============================================================
;; 约束定义 (Layer 3)
;; ============================================================
;;
;; 细粒度约束验证:
;;   reg-range      ; 寄存器编号范围 min-max
;;   imm-range      ; 立即数范围 min-max
;;   imm-values     ; 特定立即数值列表
;;   arrangement    ; 向量排列 8B/16B/4H/...
;;   element-size   ; 元素大小 B/H/S/D
;;   pred-mode      ; 谓词模式 /Z /M

;; 寄存器编号范围约束
;; min: 最小寄存器编号
;; max: 最大寄存器编号
(struct reg-range (min max) #:transparent)

;; 立即数范围约束
;; min: 最小值 (包含)
;; max: 最大值 (包含)
;; step: 步长 (默认 1)
(struct imm-range (min max step) #:transparent)

;; 特定立即数值约束
;; values: 允许的值列表
(struct imm-values (values) #:transparent)

;; 向量排列约束
;; arrangements: 允许的排列列表 (如 '(8B 16B 4H 8H 2S 4S 2D))
(struct arrangement (arrangements) #:transparent)

;; 元素大小约束
;; sizes: 允许的元素大小列表 (如 '(B H S D))
(struct element-size (sizes) #:transparent)

;; 谓词模式约束
;; modes: 允许的模式列表 (如 '(z m) 或 '(z))
(struct pred-mode-constraint (modes) #:transparent)

;; ============================================================
;; 约束验证
;; ============================================================

;; 通用约束验证
(define (validate-constraint constraint value)
  (match constraint
    [(reg-range min max)
     (check-reg-range value min max)]
    [(imm-range min max step)
     (check-imm-range value min max step)]
    [(imm-values vals)
     (check-imm-values value vals)]
    [(arrangement arrs)
     (check-arrangement value arrs)]
    [(element-size sizes)
     (check-element-size value sizes)]
    [(pred-mode-constraint modes)
     (check-pred-mode value modes)]
    [_ #t]))  ; 未知约束类型，默认通过

;; 检查寄存器编号范围
(define (check-reg-range reg-id min-id max-id)
  (and (number? reg-id)
       (>= reg-id min-id)
       (<= reg-id max-id)))

;; 检查立即数范围
(define (check-imm-range value min-val max-val [step 1])
  (and (number? value)
       (>= value min-val)
       (<= value max-val)
       (or (= step 1)
           (zero? (remainder (- value min-val) step)))))

;; 检查特定立即数值
(define (check-imm-values value allowed-values)
  (member value allowed-values))

;; 检查向量排列
(define (check-arrangement arr allowed-arrangements)
  (member arr allowed-arrangements))

;; 检查元素大小
(define (check-element-size size allowed-sizes)
  (member size allowed-sizes))

;; 检查谓词模式
(define (check-pred-mode mode allowed-modes)
  (member mode allowed-modes))

;; ============================================================
;; 约束提取
;; ============================================================

;; 从位宽计算寄存器范围
;; 这是从 MRS 编码字段提取约束的主要方式
(define (width-to-reg-range width)
  (define max-val (sub1 (expt 2 width)))
  (reg-range 0 max-val))

;; 常见的寄存器约束
;; 3 bit width -> 0-7 (低位寄存器，用于某些指令)
;; 4 bit width -> 0-15
;; 5 bit width -> 0-31 (完整 GPR/SIMD 范围)
(define (extract-reg-constraint-from-width width)
  (match width
    [3 (reg-range 0 7)]
    [4 (reg-range 0 15)]
    [5 (reg-range 0 31)]
    [_ (width-to-reg-range width)]))

;; ============================================================
;; 常用约束实例
;; ============================================================

;; GPR 完整范围 (0-31)
(define gpr-full-range (reg-range 0 31))

;; 低位 GPR (0-7)
(define gpr-low-range (reg-range 0 7))

;; 低位 GPR (0-15)
(define gpr-mid-range (reg-range 0 15))

;; SIMD/FP 完整范围 (0-31)
(define simd-full-range (reg-range 0 31))

;; SVE Z 寄存器范围 (0-31)
(define sve-z-full-range (reg-range 0 31))

;; SVE P 寄存器范围 (0-15 或 0-7)
(define sve-p-full-range (reg-range 0 15))
(define sve-p-low-range (reg-range 0 7))

;; 常见向量排列
(define simd-8b-16b (arrangement '(8B 16B)))
(define simd-4h-8h (arrangement '(4H 8H)))
(define simd-2s-4s (arrangement '(2S 4S)))
(define simd-2d (arrangement '(2D)))

;; SVE 元素大小
(define sve-bhsd (element-size '(B H S D)))
(define sve-hsd (element-size '(H S D)))
(define sve-sd (element-size '(S D)))

;; 谓词模式
(define pred-zeroing (pred-mode-constraint '(z)))
(define pred-merging (pred-mode-constraint '(m)))
(define pred-either (pred-mode-constraint '(z m)))
