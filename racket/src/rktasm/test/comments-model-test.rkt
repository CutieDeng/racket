#lang racket

(require rackunit
         rackunit/text-ui
         "../parser/frontend.rkt"
         "../parser/ast.rkt"
         "../parser/comments.rkt"
         "../pipeline/sched-model.rkt"
         "../codegen/emit.rkt")

;; ============================================================
;; 注释透传 (parser/comments.rkt + emit) 与调度模型外置
;; (pipeline/sched-model.rkt) 单元测试
;; ============================================================

(define gnu-source
  (string-join
   '(".function f (in: x.a)"
     "entry:"
     "  movz x.k, #42104    ; Load lower half of constant 0xd76aa478"
     "  add x.a, x.a, x.k   // gnu style comment"
     "  mov x0, x.a"
     "  ret"
     ".end")
   "\n"))

(define (parse-gnu-with-table)
  (define tbl (make-hash))
  (parameterize ([current-source-comments tbl])
    (parse-string gnu-source #:source 'cmt-test #:syntax 'gnu #:validate? #f))
  tbl)

(define comments-tests
  (test-suite
   "注释透传"

   (test-case "GNU 前端把尾注释记入侧表 (两种注释引导符)"
     (define tbl (parse-gnu-with-table))
     (check-equal? (hash-ref tbl (cons 'cmt-test 3) #f)
                   "Load lower half of constant 0xd76aa478")
     (check-equal? (hash-ref tbl (cons 'cmt-test 4) #f)
                   "gnu style comment")
     ;; 无注释行不入表
     (check-false (hash-ref tbl (cons 'cmt-test 5) #f)))

   (test-case "参数为 #f (默认) 时不记录"
     (parameterize ([current-source-comments #f])
       (parse-string gnu-source #:source 'cmt-off #:syntax 'gnu #:validate? #f)
       (check-false (source-comment-ref 'cmt-off 3))))

   (test-case "emit-instruction 按 loc 反查并追加注释"
     (define ins (ast-ins 'movz #f
                          (list (ast-reg 'x 3 #f #f #f #f no-srcloc)
                                (ast-imm 42104 no-srcloc))
                          (srcloc 'cmt-test 3 0 #f #f)))
     (parameterize ([current-source-comments (parse-gnu-with-table)])
       (check-regexp-match #rx"Load lower half of constant 0xd76aa478"
                           (emit-instruction ins)))
     ;; 侧表关闭时输出不含注释
     (parameterize ([current-source-comments #f])
       (check-false (regexp-match? #rx"constant" (emit-instruction ins)))))))

(define model-tests
  (test-suite
   "调度模型外置"

   (test-case "内置 apple-m 关键值 (与历史硬编码表一致)"
     (define m (current-sched-model))
     (check-equal? (sched-model-name m) 'apple-m)
     (check-equal? (sched-model-issue-width m) 3)
     (check-equal? (sched-model-call-latency m) 12)
     (check-equal? (model-latency m 'mul) 3)
     (check-equal? (model-latency m 'ldr) 4)
     (check-equal? (model-latency m 'aese) 2)
     (check-equal? (model-latency m 'pmull) 3)
     (check-equal? (model-latency m 'some-unknown-mnemonic) 1)
     (check-equal? (model-port m 'aese) 'crypto)
     (check-equal? (model-port m 'pmull2) 'crypto)
     (check-equal? (model-port m 'ldr) 'ld)
     (check-equal? (model-port m 'some-unknown-mnemonic) 'int)
     (check-equal? (model-port-capacity m 'crypto) 1)
     (check-equal? (model-port-capacity m 'int) 6)
     (check-equal? (model-port-capacity m 'some-unknown-port) 4))

   (test-case "data/latency.rktd 与内置模型逐值一致"
     (parameterize ([current-sched-model (current-sched-model)])
       (define builtin (current-sched-model))
       (resolve-sched-model! "latency")
       (define loaded (current-sched-model))
       (for ([mnem '(mul umulh ldr ldp str aese aesd aesmc pmull pmull2
                     ld1 st1 add sub eor3 bcax and orr mov fmov
                     some-unknown-mnemonic)])
         (check-equal? (model-latency loaded mnem) (model-latency builtin mnem)
                       (format "latency mismatch: ~a" mnem))
         (check-equal? (model-port loaded mnem) (model-port builtin mnem)
                       (format "port mismatch: ~a" mnem)))
       (for ([p '(crypto ld st mul simd int some-unknown-port)])
         (check-equal? (model-port-capacity loaded p)
                       (model-port-capacity builtin p)
                       (format "capacity mismatch: ~a" p)))
       (check-equal? (sched-model-issue-width loaded)
                     (sched-model-issue-width builtin))
       (check-equal? (sched-model-call-latency loaded)
                     (sched-model-call-latency builtin))))))

(define all-tests
  (test-suite
   "comments + sched-model"
   comments-tests
   model-tests))

;; ============================================================
;; 执行
;; ============================================================

(module+ main
  (void (run-tests all-tests)))

(module+ test
  (void (run-tests all-tests)))
