;; ============================================================
;; 005-nested-call.d - 嵌套调用 save!/load! 测试
;; ============================================================
;;
;; 测试: 包含函数调用的 save!/load!

(: function helper (abi aapcs64))
(: label entry)
  (add x0 x0 1)
  (ret)
(: end-function)

(: function test_nested_call (export) (abi aapcs64))
(: label entry)
  (: save! all)
  (mov x29 sp)

  ;; 保存参数
  (mov x.saved x0)

  ;; 调用 helper
  (bl helper)

  ;; 使用返回值和保存的值
  (add x0 x0 x.saved)

  (: load! all)
  (ret)
(: end-function)
