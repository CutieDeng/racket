#lang racket

(require rackunit
         rackunit/text-ui
         "../codegen/emit.rkt"
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

(define (compile-to-asm items #:merge-labels? [merge? #f])
  (define cfg (build-cfg (parse-items items) 'test))
  (define fn (cfg-get-function cfg 0))
  (define config
    (struct-copy emit-config apple-emit-config
                 [merge-colocated-labels? merge?]))
  (parameterize ([current-emit-config config])
    (emit-function fn)))

;; ============================================================
;; 测试套件
;; ============================================================

(define emit-tests
  (test-suite
   "Emit 测试"

   ;; ----------------------------------------------------------
   ;; 局部标签转换测试
   ;; ----------------------------------------------------------
   (test-suite
    "局部标签转换"

    (test-case "连字符转下划线"
      (define asm (compile-to-asm
                   '((: function test)
                     (: label my-loop)
                     (mov x0 1)
                     (b.ne my-loop)
                     (ret)
                     (: end-function))))
      (check-true (regexp-match? #rx"Ltest\\$my_loop:" asm))
      (check-true (regexp-match? #rx"b\\.ne Ltest\\$my_loop" asm)))

    (test-case "重名冲突加后缀"
      (define asm (compile-to-asm
                   '((: function test)
                     (: label my-loop)
                     (mov x0 1)
                     (b.ne my-loop)
                     (: label my_loop)
                     (mov x0 2)
                     (b.ne my_loop)
                     (ret)
                     (: end-function))))
      (check-true (regexp-match? #rx"Ltest\\$my_loop:" asm))
      (check-true (regexp-match? #rx"Ltest\\$my_loop_1:" asm)))

    (test-case "合法标签名不变"
      (define asm (compile-to-asm
                   '((: function test)
                     (: label valid_name)
                     (mov x0 1)
                     (b.ne valid_name)
                     (ret)
                     (: end-function))))
      (check-true (regexp-match? #rx"Ltest\\$valid_name:" asm))))

   ;; ----------------------------------------------------------
   ;; 标签合并测试
   ;; ----------------------------------------------------------
   (test-suite
    "标签合并"

    (test-case "默认不合并"
      (define asm (compile-to-asm
                   '((: function test)
                     (: label loop)
                     (mov x0 1)
                     (b.ne loop)
                     (ret)
                     (: end-function))
                   #:merge-labels? #f))
      (check-true (regexp-match? #rx"Ltest\\$loop:" asm))
      (check-true (regexp-match? #rx"b\\.ne Ltest\\$loop" asm)))

    (test-case "启用合并"
      (define asm (compile-to-asm
                   '((: function test)
                     (: label loop)
                     (mov x0 1)
                     (b.ne loop)
                     (ret)
                     (: end-function))
                   #:merge-labels? #t))
      (check-false (regexp-match? #rx"Ltest\\$loop:" asm))
      (check-true (regexp-match? #rx"b\\.ne _test" asm)))

    (test-case "非入口块标签不受影响"
      (define asm (compile-to-asm
                   '((: function test)
                     (mov x0 1)
                     (: label middle)
                     (add x0 x0 1)
                     (b.ne middle)
                     (ret)
                     (: end-function))
                   #:merge-labels? #t))
      (check-true (regexp-match? #rx"Ltest\\$middle:" asm))))))

;; ============================================================
;; 执行
;; ============================================================

(module+ main
  (void (run-tests emit-tests)))

(module+ test
  (void (run-tests emit-tests)))
