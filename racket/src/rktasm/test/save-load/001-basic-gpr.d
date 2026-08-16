;; ============================================================
;; 001-basic-gpr.d - save!/load! 基本 GPR 测试
;; ============================================================
;;
;; 测试: 使用 save! all / load! all 保存和恢复 GPR

(: function test_basic_gpr (export) (abi aapcs64))
(: label entry)
  (: save! all)
  (mov x29 sp)

  ;; 使用一些 callee-saved 寄存器
  (mov x.a x0)
  (mov x.b x1)
  (add x0 x.a x.b)

  (: load! all)
  (ret)
(: end-function)
