;; ============================================================
;; 006-single-reg.d - 单寄存器 save!/load! 测试
;; ============================================================
;;
;; 测试: 只保存单个寄存器的边界情况
;; 语法: (: save! x19) - 单个寄存器

(: function test_single_reg (export) (abi aapcs64))
(: label entry)
  ;; 只保存 x19
  (: save! x19)

  (mov x19 x0)
  (add x0 x19 1)

  (: load! x19)
  (ret)
(: end-function)
