;; 010-middle-load-no-dealloc.d - 中间 load! 不应释放栈
;;
;; 规则:
;; - 第一个 save! 分配栈
;; - 仅函数结尾 load! 释放栈
;; - 中间 load! 只恢复寄存器，不调整 sp

(: function test_middle_load)
(: label entry)
  (: save! x19)
  (mov x19 1)
  (: load! x19)   ;; 中间 load!，不应 add sp
  (mov x0 x19)
  (: load! x19)   ;; 结尾 load!，应释放栈
  (ret)
(: end-function)
