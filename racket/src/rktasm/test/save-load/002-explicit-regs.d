;; ============================================================
;; 002-explicit-regs.d - save!/load! 显式寄存器测试
;; ============================================================
;;
;; 测试: 显式指定要保存的寄存器
;; 语法: (: save! x19 x20) 而不是 (: save! (x19 x20))

(: function test_explicit_regs (export) (abi aapcs64))
(: label entry)
  ;; 显式保存 x19, x20
  (: save! x19 x20)

  (mov x19 x0)
  (mov x20 x1)
  (add x0 x19 x20)

  ;; 显式恢复
  (: load! x19 x20)
  (ret)
(: end-function)
