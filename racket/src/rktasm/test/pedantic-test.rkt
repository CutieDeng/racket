#lang racket

(require rackunit
         rackunit/text-ui
         "../semantic/control-flow.rkt"
         "../parser/ast.rkt"
         "../parser/parser.rkt"
         racket/pvector)

;; ============================================================
;; 辅助函数
;; ============================================================

(define (parse-items items)
  (for/list ([item (in-list items)])
    (match item
      [(list ': 'function name)
       (ast-directive 'function name '() no-srcloc)]
      [(list ': 'end-function)
       (ast-directive 'end-function #f '() no-srcloc)]
      [(list ': 'label name)
       (ast-directive 'label name '() no-srcloc)]
      [_ (parse-instruction item)])))

(define (build-test-function items)
  (define cfg (build-cfg (parse-items items) 'test))
  (cfg-get-function cfg 0))

;; ============================================================
;; 测试套件
;; ============================================================

(define pedantic-tests
  (test-suite
   "Pedantic 检查测试"

   (test-case "单基本块有 ret 无警告"
     (define fn (build-test-function
                 '((: function good)
                   (mov x0 1)
                   (ret)
                   (: end-function))))
     (define result (check-linear-fallthrough fn))
     (check-false result))

   (test-case "单基本块无终止指令触发警告"
     (define fn (build-test-function
                 '((: function no_ret)
                   (mov x0 1)
                   (add x0 x0 1)
                   (: end-function))))
     (define result (check-linear-fallthrough fn))
     (check-true (linear-fallthrough-warning? result))
     (check-equal? (linear-fallthrough-warning-function-name result) 'no_ret)
     (check-equal? (linear-fallthrough-warning-instruction-count result) 2))

   (test-case "有无条件跳转无警告"
     (define fn (build-test-function
                 '((: function has_jump)
                   (mov x0 1)
                   (b somewhere)
                   (: end-function))))
     (define result (check-linear-fallthrough fn))
     (check-false result))

   (test-case "多基本块跳过检查"
     (define fn (build-test-function
                 '((: function multi_block)
                   (cbz x0 skip)
                   (mov x0 1)
                   (: label skip)
                   (mov x1 2)
                   (: end-function))))
     (define result (check-linear-fallthrough fn))
     (check-false result))

   (test-case "空函数跳过检查"
     (define fn (build-test-function
                 '((: function empty)
                   (: end-function))))
     (define result (check-linear-fallthrough fn))
     (check-false result))

   (test-case "只有 br 指令无警告"
     (define fn (build-test-function
                 '((: function indirect_jump)
                   (mov x0 1)
                   (br x30)
                   (: end-function))))
     (define result (check-linear-fallthrough fn))
     (check-false result))

   (test-case "条件分支算终止指令"
     (define fn (build-test-function
                 '((: function cond_branch)
                   (mov x0 1)
                   (b.eq target)
                   (: end-function))))
     (define result (check-linear-fallthrough fn))
     (check-false result))))

;; ============================================================
;; 执行
;; ============================================================

(module+ main
  (void (run-tests pedantic-tests)))

(module+ test
  (void (run-tests pedantic-tests)))
