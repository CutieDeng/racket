;; ============================================================
;; 004-multi-block.d - 多基本块 save!/load! 测试
;; ============================================================
;;
;; 测试: 多个基本块中的 save!/load!
;; 关键点: 不同执行路径都需要正确释放栈空间

(: function test_multi_block (export) (abi aapcs64))
(: label entry)
  (: save! all)
  (mov x29 sp)

  (mov x.val x0)
  (cmp x.val 0)
  (b.eq zero_path)

(: label nonzero_path)
  (mov x0 1)
  (: load! all)
  (ret)

(: label zero_path)
  (mov x0 0)
  (: load! all)
  (ret)
(: end-function)
