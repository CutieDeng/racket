#lang racket

(require rackunit
         rackunit/text-ui
         "../parser/frontend.rkt"
         "../semantic/control-flow.rkt"
         "../semantic/save-verify.rkt")

;; 将源码字符串编译为首个函数并执行 save!/load! 验证
(define (verify-source source)
  (define parsed (parse-string source))
  (define items
    (for/list ([r (in-list (parse-results-items parsed))]
               #:when (parse-result-ok? r))
      (parse-result-instruction r)))
  (define cfg (build-cfg items 'test))
  (define fn (cfg-get-function cfg 0))
  (verify-save-load fn))

(define save-verify-tests
  (test-suite
   "save-verify 边界语义测试"

   (test-case "首 save! + 末 load! 通过（中间不强制配对）"
     (define info
       (verify-source
        "
(: function f)
(: label entry)
  (: save! x19)
  (mov x0 1)
  (: load! x19)
  (: load! x19)
  (ret)
(: end-function)
"))
     (check-equal? (length (save-load-errors info)) 0))

   (test-case "仅有 save! 报错"
     (define info
       (verify-source
        "
(: function f)
(: label entry)
  (: save! x19)
  (ret)
(: end-function)
"))
     (check-true (pair? (save-load-errors info)))
     (check-true
      (regexp-match?
       #rx"缺少结尾 load!"
       (car (save-load-errors info)))))

   (test-case "仅有 load! 报错"
     (define info
       (verify-source
        "
(: function f)
(: label entry)
  (: load! x19)
  (ret)
(: end-function)
"))
     (check-true (pair? (save-load-errors info)))
     (check-true
      (regexp-match?
       #rx"缺少开头 save!"
       (car (save-load-errors info)))))

   (test-case "首个是 load! 报错"
     (define info
       (verify-source
        "
(: function f)
(: label entry)
  (: load! x19)
  (: save! x19)
  (ret)
(: end-function)
"))
     (check-true (pair? (save-load-errors info)))
     (check-true
      (regexp-match?
       #rx"首个 save!/load! 指令应为 save!"
       (car (save-load-errors info)))))

   (test-case "末个是 save! 报错"
     (define info
       (verify-source
        "
(: function f)
(: label entry)
  (: save! x19)
  (: load! x19)
  (: save! x20)
  (ret)
(: end-function)
"))
     (check-true (pair? (save-load-errors info)))
     (check-true
      (ormap (lambda (msg)
               (regexp-match? #rx"末个 save!/load! 指令应为 load!" msg))
             (save-load-errors info))))))

(module+ main
  (void (run-tests save-verify-tests)))

(module+ test
  (void (run-tests save-verify-tests)))
