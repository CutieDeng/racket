;; ============================================================
;; 007-post-index.d - Post-index 优化测试
;; ============================================================
;;
;; 测试: ldp x29, x30, [sp], #N 的 post-index 优化
;; 当有 x29, x30 需要恢复时，最后的 ldp 应该使用 post-index

(: function test_post_index (export) (abi aapcs64))
(: label entry)
  (: save! all)
  (mov x29 sp)

  ;; 使用多个 callee-saved 寄存器触发 stp/ldp 配对
  (mov x.a x0)
  (mov x.b x1)
  (mov x.c x2)
  (add x0 x.a x.b)
  (add x0 x0 x.c)

  (: load! all)
  (ret)
(: end-function)
