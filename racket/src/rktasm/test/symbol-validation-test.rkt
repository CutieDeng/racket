#lang racket

(require rackunit
         rackunit/text-ui
         "../semantic/control-flow.rkt"
         "../parser/ast.rkt"
         racket/pvector
         racket/intmap
         racket/graph)

;; ============================================================
;; 辅助函数
;; ============================================================

(define (make-test-function name)
  (asm-function
   0                                          ; id
   name                                       ; name
   #f                                         ; entry
   graph-empty                                ; graph
   intmap-empty                               ; blocks
   intmap-empty                               ; id->label
   (hasheq)                                   ; label->id
   intmap-empty                               ; vid->bbid
   intmap-empty                               ; bbid->vid
   fn-debug-empty                             ; debug
   (hasheq)))                                 ; info

;; ============================================================
;; 测试套件
;; ============================================================

(define symbol-validation-tests
  (test-suite
   "符号名验证测试"

   (test-suite
    "valid-asm-symbol?"

    (test-case "合法符号"
      (check-true (valid-asm-symbol? 'main))
      (check-true (valid-asm-symbol? '_start))
      (check-true (valid-asm-symbol? 'foo123))
      (check-true (valid-asm-symbol? '__bar))
      (check-true (valid-asm-symbol? 'foo.bar))
      (check-true (valid-asm-symbol? 'hello-world))
      (check-true (valid-asm-symbol? 'a.b$c-d))
      (check-true (valid-asm-symbol? 'A))
      (check-true (valid-asm-symbol? '_)))

    (test-case "不合法符号"
      (check-false (valid-asm-symbol? "123abc"))
      (check-false (valid-asm-symbol? 'a+b))
      (check-false (valid-asm-symbol? 'a@b))
      (check-false (valid-asm-symbol? 'a::b))
      (check-false (valid-asm-symbol? 'a..b))
      (check-false (valid-asm-symbol? 'a.-b))
      (check-false (valid-asm-symbol? "1"))))

   (test-suite
    "sanitize-symbol"

    (test-case "转换连字符"
      (check-equal? (sanitize-symbol 'drop-1) "drop_1")
      (check-equal? (sanitize-symbol 'foo-bar-baz) "foo_bar_baz")
      (check-equal? (sanitize-symbol 'my-loop) "my_loop"))

    (test-case "首字符数字"
      (check-equal? (sanitize-symbol "123abc") "_23abc")
      (check-equal? (sanitize-symbol "1") "_"))

    (test-case "特殊字符"
      (check-equal? (sanitize-symbol 'a+b) "a_b")
      (check-equal? (sanitize-symbol 'foo.bar) "foo_bar"))

    (test-case "已合法符号不变"
      (check-equal? (sanitize-symbol 'main) "main")
      (check-equal? (sanitize-symbol '_start) "_start")
      (check-equal? (sanitize-symbol 'foo123) "foo123")))

   (test-suite
    "verify-symbol-names"

    (test-case "合法函数名"
      (for ([name (in-list '(valid_name crypto.deflate.fast-v1 a.b$c-d))])
        (define fn (make-test-function name))
        (define errors (verify-symbol-names fn))
        (check-true (pvector-empty? errors))))

    (test-case "不合法函数名"
      (define fn (make-test-function 'a@b))
      (define errors (verify-symbol-names fn))
      (check-equal? (pvector-length errors) 1)
      (define err (pvector-ref errors 0))
      (check-equal? (symbol-name-error-symbol err) 'a@b)
      (check-equal? (symbol-name-error-kind err) 'function)))))

;; ============================================================
;; 执行
;; ============================================================

(module+ main
  (void (run-tests symbol-validation-tests)))

(module+ test
  (void (run-tests symbol-validation-tests)))
