;; ============================================================
;; 009-save-pre-index.d - save! all pre-index 优化测试
;; ============================================================
;;
;; 目标:
;;   save! all 在可配对时，应优先生成:
;;     stp x29, x30, [sp, #-N]!
;;   而不是:
;;     sub sp, sp, #N
;;     stp x29, x30, [sp, #0]

(: function test_save_pre_index (export) (abi aapcs64))
(: label entry)
  (: save! all)
  (mov x29 sp)

  ;; 使用一个虚拟寄存器，确保触发寄存器分配路径
  (mov x.a x0)
  (add x0 x.a 1)

  (: load! all)
  (ret)
(: end-function)
