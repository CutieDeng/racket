#lang racket

(require rackunit
         rackunit/text-ui
         "../parser/frontend.rkt"
         "../semantic/control-flow.rkt"
         "../pipeline/pipeline.rkt"
         "../pipeline/regalloc/abi-config.rkt")

(define (source->fn source)
  (define parsed (parse-string source #:validate? #f))
  (when (parse-results-has-errors? parsed)
    (error 'source->fn "解析错误:\n~a"
           (format-parse-errors-report parsed)))
  (define items
    (for/list ([r (in-list (parse-results-items parsed))]
               #:when (parse-result-ok? r))
      (parse-result-instruction r)))
  (define cfg (build-cfg items 'abi-optional-test))
  (cfg-get-function cfg 0))

(define abi-optional-tests
  (test-suite
   "函数 ABI 可选测试"

   (test-case "使用虚拟寄存器的函数无需声明 ABI"
     (parameterize ([default-abi-name #f])
       (define fn
         (source->fn "
(: function f)
(: label entry)
  (mov x.tmp x0)
  (add x0 x.tmp 1)
  (ret)
(: end-function)
"))
       (define result (run-pipeline fn default-pipeline-config))
       (check-equal? (pipeline-result-errors result) '())))))

(module+ main
  (void (run-tests abi-optional-tests)))

(module+ test
  (void (run-tests abi-optional-tests)))
