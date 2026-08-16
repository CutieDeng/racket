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

(define (build-test-cfg source-items)
  (build-cfg source-items 'test))

(define (parse-items items)
  (for/list ([item (in-list items)])
    (match item
      [(list ': 'function name)
       (ast-directive 'function name '() no-srcloc)]
      [(list ': 'end-function)
       (ast-directive 'end-function #f '() no-srcloc)]
      [(list ': 'label name)
       (ast-directive 'label name '() no-srcloc)]
      [(list ': 'extern name)
       (ast-directive 'extern name '(func) no-srcloc)]
      [(list ': 'extern name '(var))
       (ast-directive 'extern name '(var) no-srcloc)]
      [_ (parse-instruction item)])))

;; ============================================================
;; 测试套件
;; ============================================================

(define label-ref-tests
  (test-suite
   "标签引用验证测试"

   (test-case "正确的局部标签引用"
     (define items (parse-items
                    '((: function test)
                      (: label loop)
                      (mov x0 1)
                      (b.ne loop)
                      (ret)
                      (: end-function))))
     (define cfg (build-test-cfg items))
     (define fn (cfg-get-function cfg 0))
     (define errors (verify-label-references fn cfg))
     (check-true (pvector-empty? errors)))

   (test-case "未定义标签"
     (define items (parse-items
                    '((: function test)
                      (: label loop)
                      (mov x0 1)
                      (b.ne undefined_label)
                      (ret)
                      (: end-function))))
     (define cfg (build-test-cfg items))
     (define fn (cfg-get-function cfg 0))
     (define errors (verify-label-references fn cfg))
     (check-equal? (pvector-length errors) 1)
     (define err (pvector-ref errors 0))
     (check-equal? (label-ref-error-label err) 'undefined_label))

   (test-case "跨函数引用合法"
     (define items (parse-items
                    '((: function foo)
                      (ret)
                      (: end-function)
                      (: function bar)
                      (bl foo)
                      (ret)
                      (: end-function))))
     (define cfg (build-test-cfg items))
     (define fn (cfg-get-function cfg 1))
     (define errors (verify-label-references fn cfg))
     (check-true (pvector-empty? errors)))

   (test-case "多个未定义标签"
     (define items (parse-items
                    '((: function test)
                      (b.eq label1)
                      (b.ne label2)
                      (ret)
                      (: end-function))))
     (define cfg (build-test-cfg items))
     (define fn (cfg-get-function cfg 0))
     (define errors (verify-label-references fn cfg))
     (check-equal? (pvector-length errors) 2))

   (test-case "错误信息包含已定义标签"
     (define items (parse-items
                    '((: function test)
                      (: label valid)
                      (b.ne typo)
                      (ret)
                      (: end-function))))
     (define cfg (build-test-cfg items))
     (define fn (cfg-get-function cfg 0))
     (define errors (verify-label-references fn cfg))
     (check-equal? (pvector-length errors) 1)
     (define err (pvector-ref errors 0))
     (check-not-false (member 'valid (label-ref-error-defined-labels err))))

   (test-case "extern 符号引用合法"
     (define items (parse-items
                    '((: extern printf)
                      (: function test)
                      (bl printf)
                      (ret)
                      (: end-function))))
     (define cfg (build-test-cfg items))
     (define fn (cfg-get-function cfg 0))
     (define errors (verify-label-references fn cfg))
     (check-true (pvector-empty? errors)))

   (test-case "多个 extern 符号"
     (define items (parse-items
                    '((: extern malloc)
                      (: extern free)
                      (: function test)
                      (bl malloc)
                      (bl free)
                      (ret)
                      (: end-function))))
     (define cfg (build-test-cfg items))
     (define fn (cfg-get-function cfg 0))
     (define errors (verify-label-references fn cfg))
     (check-true (pvector-empty? errors)))

   (test-case "未声明的外部符号报错"
     (define items (parse-items
                    '((: extern malloc)
                      (: function test)
                      (bl malloc)
                      (bl free)
                      (ret)
                      (: end-function))))
     (define cfg (build-test-cfg items))
     (define fn (cfg-get-function cfg 0))
     (define errors (verify-label-references fn cfg))
     (check-equal? (pvector-length errors) 1)
     (define err (pvector-ref errors 0))
     (check-equal? (label-ref-error-label err) 'free))

   (test-case "extern 变量声明"
     (define items (parse-items
                    '((: extern errno (var))
                      (: function test)
                      (adrp x0 errno)
                      (ret)
                      (: end-function))))
     (define cfg (build-test-cfg items))
     (define fn (cfg-get-function cfg 0))
     (define errors (verify-label-references fn cfg))
     (check-true (pvector-empty? errors)))

   (test-case "mrs 的系统寄存器操作数不应被当成标签引用"
     (define items (parse-items
                    '((: function test)
                      (mrs x0 CurrentEL)
                      (mrs x1 DAIF)
                      (ret)
                      (: end-function))))
     (define cfg (build-test-cfg items))
     (define fn (cfg-get-function cfg 0))
     (define errors (verify-label-references fn cfg))
     (check-true (pvector-empty? errors)))

   (test-case "mrs 的系统寄存器名称模式不应被当成标签引用"
     (define items (parse-items
                    '((: function test)
                      (mrs x0 DBGBVR<m>_EL1)
                      (mrs x1 TRCACATR<m>)
                      (mrs x2 S3_<op1>_C<Cn>_C<Cm>_<op2>)
                      (ret)
                      (: end-function))))
     (define cfg (build-test-cfg items))
     (define fn (cfg-get-function cfg 0))
     (define errors (verify-label-references fn cfg))
     (check-true (pvector-empty? errors)))))

;; ============================================================
;; 执行
;; ============================================================

(module+ main
  (void (run-tests label-ref-tests)))

(module+ test
  (void (run-tests label-ref-tests)))
