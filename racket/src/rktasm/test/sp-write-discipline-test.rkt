#lang racket

(require rackunit
         rackunit/text-ui
         "../parser/frontend.rkt"
         "../semantic/control-flow.rkt"
         racket/pvector)

(define (source->fn source #:syntax [syntax 'sexp])
  (define parsed
    (parse-string source
                  #:source 'sp-write-test
                  #:syntax syntax
                  #:validate? #f))
  (when (parse-results-has-errors? parsed)
    (error 'source->fn "解析错误:\n~a"
           (format-parse-errors-report parsed)))
  (define items
    (for/list ([r (in-list (parse-results-items parsed))]
               #:when (parse-result-ok? r))
      (parse-result-instruction r)))
  (define cfg (build-cfg items 'sp-write-test))
  (cfg-get-function cfg 0))

(define (sp-write-errors source #:syntax [syntax 'sexp])
  (verify-sp-write-discipline (source->fn source #:syntax syntax)))

(define sp-write-discipline-tests
  (test-suite
   "SP 写入纪律测试"

   (test-case "add/sub/mov 这类直接定义 sp 的指令会被标记"
     (define errors
       (sp-write-errors
        "
(: function f)
(: label entry)
  (add sp sp 16)
  (ret)
(: end-function)
"))
     (check-equal? (pvector-length errors) 1)
     (check-equal? (sp-write-error-function-name (pvector-ref errors 0)) 'f))

   (test-case "pre-index 的 sp 寻址会被标记"
     (define errors
       (sp-write-errors
        "
(: function f)
(: label entry)
  (stp x29 x30 (sp -16 !))
  (ret)
(: end-function)
"))
     (check-equal? (pvector-length errors) 1)
     (check-true
      (regexp-match? #rx"pre/post-index"
                     (sp-write-error-reason (pvector-ref errors 0)))))

   (test-case "GNU post-index 的 sp 寻址会被标记"
     (define errors
       (sp-write-errors
        #<<ASM
f:
  ldp x29, x30, [sp], #16
  ret
.size f, .-f
ASM
        #:syntax 'gnu))
     (check-equal? (pvector-length errors) 1)
     (check-true
      (regexp-match? #rx"pre/post-index"
                     (sp-write-error-reason (pvector-ref errors 0)))))

   (test-case "读取 sp 和使用固定 sp 偏移访问栈槽允许通过"
     (define errors
       (sp-write-errors
        "
(: function f)
(: label entry)
  (mov x29 sp)
  (str sp (x0))
  (str x0 (sp 16))
  (ldr x1 (sp 16))
  (ret)
(: end-function)
"))
     (check-true (pvector-empty? errors)))

   (test-case ".save/.restore 是允许的栈管理指令"
     (define errors
       (sp-write-errors
        #<<ASM
.asmp.function f abi=aapcs64
f:
  .save fp, lr
  mov fp, sp
  str x0, [sp, #16]
  ldr x1, [sp, #16]
  .restore fp, lr
  ret
.asmp.end_function
ASM
        #:syntax 'gnu))
     (check-true (pvector-empty? errors)))))

(module+ main
  (void (run-tests sp-write-discipline-tests)))

(module+ test
  (void (run-tests sp-write-discipline-tests)))
