#lang racket

(require rackunit
         rackunit/text-ui
         "../syntax/constraint.rkt")

;; ============================================================
;; syntax/constraint.rkt 单元测试
;; ============================================================

(define constraint-tests
  (test-suite
   "Constraint 单元测试"

   ;; --------------------------------------------------------
   ;; check-reg-range
   ;; --------------------------------------------------------
   (test-suite
    "check-reg-range"

    (test-case "范围内寄存器"
      (check-true (check-reg-range 0 0 31))
      (check-true (check-reg-range 15 0 31))
      (check-true (check-reg-range 31 0 31)))

    (test-case "边界值"
      (check-true (check-reg-range 0 0 0))
      (check-true (check-reg-range 7 0 7))
      (check-true (check-reg-range 0 0 7)))

    (test-case "超出范围"
      (check-false (check-reg-range 32 0 31))
      (check-false (check-reg-range -1 0 31))
      (check-false (check-reg-range 8 0 7)))

    (test-case "非数字输入"
      (check-false (check-reg-range 'x0 0 31))
      (check-false (check-reg-range "0" 0 31))))

   ;; --------------------------------------------------------
   ;; check-imm-range
   ;; --------------------------------------------------------
   (test-suite
    "check-imm-range"

    (test-case "基本范围 (step=1)"
      (check-true (check-imm-range 0 0 255))
      (check-true (check-imm-range 128 0 255))
      (check-true (check-imm-range 255 0 255)))

    (test-case "超出基本范围"
      (check-false (check-imm-range 256 0 255))
      (check-false (check-imm-range -1 0 255)))

    (test-case "步长对齐 (step=4)"
      (check-true (check-imm-range 0 0 252 4))
      (check-true (check-imm-range 4 0 252 4))
      (check-true (check-imm-range 252 0 252 4)))

    (test-case "步长不对齐"
      (check-false (check-imm-range 1 0 252 4))
      (check-false (check-imm-range 3 0 252 4))
      (check-false (check-imm-range 5 0 252 4)))

    (test-case "步长对齐 (step=8)"
      (check-true (check-imm-range 0 0 504 8))
      (check-true (check-imm-range 8 0 504 8))
      (check-false (check-imm-range 7 0 504 8)))

    (test-case "负数范围"
      (check-true (check-imm-range -128 -128 127))
      (check-true (check-imm-range 0 -128 127))
      (check-true (check-imm-range 127 -128 127))
      (check-false (check-imm-range -129 -128 127)))

    (test-case "非数字输入"
      (check-false (check-imm-range 'imm 0 255))
      (check-false (check-imm-range "42" 0 255))))

   ;; --------------------------------------------------------
   ;; check-imm-values
   ;; --------------------------------------------------------
   (test-suite
    "check-imm-values"

    (test-case "值在列表中"
      (check-not-false (check-imm-values 0 '(0 8 16 24)))
      (check-not-false (check-imm-values 24 '(0 8 16 24))))

    (test-case "值不在列表中"
      (check-false (check-imm-values 1 '(0 8 16 24)))
      (check-false (check-imm-values 7 '(0 8 16 24))))

    (test-case "空列表"
      (check-false (check-imm-values 0 '()))))

   ;; --------------------------------------------------------
   ;; validate-constraint (通用分发)
   ;; --------------------------------------------------------
   (test-suite
    "validate-constraint 分发"

    (test-case "分发到 reg-range"
      (check-true (validate-constraint (reg-range 0 31) 15))
      (check-false (validate-constraint (reg-range 0 7) 8)))

    (test-case "分发到 imm-range"
      (check-true (validate-constraint (imm-range 0 255 1) 100))
      (check-false (validate-constraint (imm-range 0 255 1) 256)))

    (test-case "分发到 imm-range 带步长"
      (check-true (validate-constraint (imm-range 0 252 4) 8))
      (check-false (validate-constraint (imm-range 0 252 4) 3)))

    (test-case "分发到 imm-values"
      (check-not-false (validate-constraint (imm-values '(0 1 2 4 8)) 4))
      (check-false (validate-constraint (imm-values '(0 1 2 4 8)) 3)))

    (test-case "分发到 arrangement"
      (check-not-false (validate-constraint (arrangement '(8B 16B)) '8B))
      (check-false (validate-constraint (arrangement '(8B 16B)) '4H)))

    (test-case "分发到 element-size"
      (check-not-false (validate-constraint (element-size '(B H S D)) 'S))
      (check-false (validate-constraint (element-size '(S D)) 'B)))

    (test-case "分发到 pred-mode-constraint"
      (check-not-false (validate-constraint (pred-mode-constraint '(z m)) 'z))
      (check-false (validate-constraint (pred-mode-constraint '(z)) 'm)))

    (test-case "未知约束类型默认通过"
      (check-true (validate-constraint "unknown-constraint" 42))))

   ;; --------------------------------------------------------
   ;; width-to-reg-range
   ;; --------------------------------------------------------
   (test-suite
    "width-to-reg-range"

    (test-case "3-bit 宽度 -> 0-7"
      (define r (width-to-reg-range 3))
      (check-equal? (reg-range-min r) 0)
      (check-equal? (reg-range-max r) 7))

    (test-case "4-bit 宽度 -> 0-15"
      (define r (width-to-reg-range 4))
      (check-equal? (reg-range-min r) 0)
      (check-equal? (reg-range-max r) 15))

    (test-case "5-bit 宽度 -> 0-31"
      (define r (width-to-reg-range 5))
      (check-equal? (reg-range-min r) 0)
      (check-equal? (reg-range-max r) 31)))

   ;; --------------------------------------------------------
   ;; extract-reg-constraint-from-width
   ;; --------------------------------------------------------
   (test-suite
    "extract-reg-constraint-from-width"

    (test-case "预定义宽度"
      (check-equal? (extract-reg-constraint-from-width 3) (reg-range 0 7))
      (check-equal? (extract-reg-constraint-from-width 4) (reg-range 0 15))
      (check-equal? (extract-reg-constraint-from-width 5) (reg-range 0 31)))

    (test-case "非预定义宽度回退到通用计算"
      (define r (extract-reg-constraint-from-width 2))
      (check-equal? (reg-range-min r) 0)
      (check-equal? (reg-range-max r) 3)))

   ;; --------------------------------------------------------
   ;; 结构透明性
   ;; --------------------------------------------------------
   (test-suite
    "结构构造与访问"

    (test-case "reg-range 透明"
      (define r (reg-range 0 31))
      (check-equal? (reg-range-min r) 0)
      (check-equal? (reg-range-max r) 31)
      (check-true (reg-range? r)))

    (test-case "imm-range 透明"
      (define r (imm-range -128 127 1))
      (check-equal? (imm-range-min r) -128)
      (check-equal? (imm-range-max r) 127)
      (check-equal? (imm-range-step r) 1))

    (test-case "imm-values 透明"
      (define r (imm-values '(0 8 16)))
      (check-equal? (imm-values-values r) '(0 8 16)))

    (test-case "arrangement 透明"
      (define r (arrangement '(8B 16B)))
      (check-equal? (arrangement-arrangements r) '(8B 16B)))

    (test-case "element-size 透明"
      (define r (element-size '(B H S D)))
      (check-equal? (element-size-sizes r) '(B H S D)))

    (test-case "pred-mode-constraint 透明"
      (define r (pred-mode-constraint '(z m)))
      (check-equal? (pred-mode-constraint-modes r) '(z m))))))

;; ============================================================
;; 执行
;; ============================================================

(module+ main
  (void (run-tests constraint-tests)))

(module+ test
  (void (run-tests constraint-tests)))
