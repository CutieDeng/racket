;; ============================================================
;; 003-fpr.d - save!/load! FPR 测试
;; ============================================================
;;
;; 测试: 浮点寄存器的保存和恢复
;; 注意: 需要使用 callee-saved FPR (d8-d15)

(: function test_fpr (export) (abi aapcs64))
(: label entry)
  ;; 显式保存 callee-saved FPR
  (: save! q8 q9)
  (mov x29 sp)

  ;; 使用 callee-saved FPR
  (fmov d8 d0)
  (fmov d9 d1)
  (fadd d0 d8 d9)

  (: load! q8 q9)
  (ret)
(: end-function)
