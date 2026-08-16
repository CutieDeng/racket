#lang racket

;; ============================================================
;; test/abi-infer-test.rkt - ABI 推断与有效 ABI 语义测试
;; ============================================================

(require rackunit
         rackunit/text-ui
         "../parser/frontend.rkt"
         "../parser/ast.rkt"
         "../semantic/control-flow.rkt"
         "../pipeline/regalloc/abi.rkt"
         "../pipeline/regalloc/abi-config.rkt"
         "../pipeline/regalloc/abi-infer.rkt"
         "../pipeline/regalloc/liveness.rkt"
         "../pipeline/regalloc/interference.rkt"
         racket/intbits)

;; 初始化配置文件路径
(define (find-config-path)
  (define candidates
    (list
     (build-path (current-directory) "config/abi.rktd")
     (build-path (current-directory) ".." "config/abi.rktd")))
  (for/first ([p (in-list candidates)]
              #:when (file-exists? p))
    p))

(define config-path (find-config-path))
(when config-path
  (abi-config-path config-path)
  (void (reload-abi-config)))
(default-abi-name 'aapcs64)

(define (source->cfg source)
  (define results (parse-string source))
  (when (parse-results-has-errors? results)
    (error 'source->cfg "解析错误:\n~a"
           (format-parse-errors-report results)))
  (define items
    (for/list ([r (parse-results-items results)]
               #:when (parse-result-ok? r))
      (parse-result-instruction r)))
  (build-cfg items))

(define-test-suite abi-infer-tests
  (test-case "调用链推断应传递 def 集"
    (define cfg
      (source->cfg "
(: function f)
(: label entry)
  (mov x0 1)
  (ret)
(: end-function)

(: function g)
(: label entry)
  (bl f)
  (ret)
(: end-function)

(: function h)
(: label entry)
  (bl g)
  (ret)
(: end-function)
"))
    (define abi-map (infer-all-abis cfg))
    (define h-info (hash-ref abi-map 'h #f))
    (check-not-false h-info)
    (define h-def (inferred-abi-gpr-def (function-abi-info-inferred-abi h-info)))
    (check-true (intbits-ref h-def 0)))

  (test-case "声明 ABI 时，修改 preserved 寄存器应报错"
    (define cfg
      (source->cfg "
(: function bad (abi aapcs64))
(: label entry)
  (mov x19 1)
  (ret)
(: end-function)
"))
    (define abi-map (infer-all-abis cfg))
    (define bad-info (hash-ref abi-map 'bad #f))
    (check-not-false bad-info)
    (define errs (function-abi-info-errors bad-info))
    (check-true (pair? errs))
    (check-true (for/or ([e (in-list errs)])
                  (regexp-match? #rx"x19" e))))

  (test-case "动态调用 blr 应按默认 ABI 保守推断"
    (define cfg
      (source->cfg "
(: function dyn_call)
(: label entry)
  (blr x16)
  (ret)
(: end-function)
"))
    (define abi-map (infer-all-abis cfg))
    (define info (hash-ref abi-map 'dyn_call #f))
    (check-not-false info)
    (define defs (inferred-abi-gpr-def (function-abi-info-inferred-abi info)))
    ;; caller-saved x0 应视为可能被 clobber
    (check-true (intbits-ref defs 0))
    ;; callee-saved x19 不应被默认 scratch 假设覆盖
    (check-false (intbits-ref defs 19)))

  (test-case "没有 default-abi 时，未知调用按内建 AAPCS64 保守推断"
    (parameterize ([default-abi-name #f])
      (define cfg
        (source->cfg "
(: extern ext)
(: function caller)
(: label entry)
  (bl ext)
  (ret)
(: end-function)
"))
      (define abi-map (infer-all-abis cfg))
      (define info (hash-ref abi-map 'caller #f))
      (check-not-false info)
      (define defs (inferred-abi-gpr-def (function-abi-info-inferred-abi info)))
      (check-true (intbits-ref defs 0))
      (check-false (intbits-ref defs 19))))

  (test-case "extern ABI 声明控制外部调用 clobber 集"
    (define cfg
      (source->cfg "
(: extern ext (abi naked))
(: function caller)
(: label entry)
  (bl ext)
  (ret)
(: end-function)
"))
    (define abi-map (infer-all-abis cfg))
    (define info (hash-ref abi-map 'caller #f))
    (check-not-false info)
    (define defs (inferred-abi-gpr-def (function-abi-info-inferred-abi info)))
    ;; naked 没有 preserved，x19 也应按可能被 clobber 处理。
    (check-true (intbits-ref defs 19)))

  (test-case "同一 CFG 重复推断时，切换 default-abi 仍应生效（缓存不应污染语义）"
    (define cfg
      (source->cfg "
(: function dyn_call_switch)
(: label entry)
  (blr x16)
  (ret)
(: end-function)
"))
    ;; 先用 aapcs64：x30 为 callee-saved，不应出现在 scratch 推断
    (default-abi-name 'aapcs64)
    (define abi-map-a (infer-all-abis cfg))
    (define info-a (hash-ref abi-map-a 'dyn_call_switch #f))
    (check-not-false info-a)
    (define defs-a (inferred-abi-gpr-def (function-abi-info-inferred-abi info-a)))
    (check-false (intbits-ref defs-a 30))

    ;; 再切换 leaf：x30 不再 preserved，应进入 scratch 推断
    (default-abi-name 'leaf)
    (define abi-map-b (infer-all-abis cfg))
    (define info-b (hash-ref abi-map-b 'dyn_call_switch #f))
    (check-not-false info-b)
    (define defs-b (inferred-abi-gpr-def (function-abi-info-inferred-abi info-b)))
    (check-true (intbits-ref defs-b 30))

    ;; 恢复默认值，避免影响后续测试
    (default-abi-name 'aapcs64))

  (test-case "跨 CFG 复用缓存时，函数体变化应触发新摘要（不应命中旧结果）"
    (define cfg-a
      (source->cfg "
(: function same_name)
(: label entry)
  (mov x0 1)
  (ret)
(: end-function)
"))
    (define map-a (infer-all-abis cfg-a))
    (define info-a (hash-ref map-a 'same_name #f))
    (check-not-false info-a)
    (define defs-a (inferred-abi-gpr-def (function-abi-info-inferred-abi info-a)))
    (check-true (intbits-ref defs-a 0))

    (define cfg-b
      (source->cfg "
(: function same_name)
(: label entry)
  (mov x19 1)
  (ret)
(: end-function)
"))
    (define map-b (infer-all-abis cfg-b))
    (define info-b (hash-ref map-b 'same_name #f))
    (check-not-false info-b)
    (define defs-b (inferred-abi-gpr-def (function-abi-info-inferred-abi info-b)))
    (check-true (intbits-ref defs-b 19))
    (check-false (intbits-ref defs-b 0)))

  (test-case "无 save! 时 effective-abi 应退化为 scratch-only"
    (define cfg
      (source->cfg "
(: function no_save)
(: label entry)
  (mov x.a 1)
  (add x0 x.a 1)
  (ret)
(: end-function)
"))
    (define fn (cfg-get-function cfg 0))
    (define lv (analyze-liveness fn))
    (define mig (build-interference-graphs fn lv #:abi arm64-abi))
    (check-equal? (multi-class-ig-effective-abi mig)
                  (abi-scratch-only arm64-abi)))

  (test-case "有 save! 时 effective-abi 保留声明 ABI 但 LR 不是 preserved"
    (define cfg
      (source->cfg "
(: function with_save)
(: label entry)
  (: save! all)
  (mov x.a 1)
  (: load! all)
  (ret)
(: end-function)
"))
    (define fn (cfg-get-function cfg 0))
    (define lv (analyze-liveness fn))
    (define mig (build-interference-graphs fn lv #:abi arm64-abi))
    (define effective (multi-class-ig-effective-abi mig))
    (check-true (reg-allocatable? (abi-config-gpr effective) 30))
    (check-false (reg-preserved? (abi-config-gpr effective) 30))
    (check-equal? (abi-config-fpr effective) (abi-config-fpr arm64-abi))
    (check-equal? (abi-config-pred effective) (abi-config-pred arm64-abi))))

;; ============================================================
;; 缓存机制测试
;; ============================================================

(define-test-suite infer-cache-tests
  (test-case "clear-abi-infer-cache! 清除所有缓存"
    ;; 先创建一些缓存
    (define cfg
      (source->cfg "
(: function test_fn)
(: label entry)
  (mov x0 1)
  (ret)
(: end-function)
"))
    (void (infer-all-abis cfg))
    ;; 清除缓存
    (clear-abi-infer-cache!)
    ;; 验证缓存被清除 - 重新推断应成功
    (define cfg2
      (source->cfg "
(: function test_fn2)
(: label entry)
  (mov x1 1)
  (ret)
(: end-function)
"))
    (define abi-map (infer-all-abis cfg2))
    (check-true (hash-has-key? abi-map 'test_fn2)))

  (test-case "相同 CFG 重复推断使用缓存"
    (clear-abi-infer-cache!)
    (define cfg
      (source->cfg "
(: function cached_fn)
(: label entry)
  (mov x0 1)
  (ret)
(: end-function)
"))
    ;; 第一次推断
    (define abi-map1 (infer-all-abis cfg))
    ;; 第二次推断应使用缓存
    (define abi-map2 (infer-all-abis cfg))
    ;; 结果应该相同
    (check-equal? (hash-keys abi-map1) (hash-keys abi-map2))
    (check-equal? (hash-ref abi-map1 'cached_fn #f)
                  (hash-ref abi-map2 'cached_fn #f)))

  (test-case "不同 CFG 不共享结果缓存"
    (clear-abi-infer-cache!)
    (define cfg-a
      (source->cfg "
(: function unique_fn)
(: label entry)
  (mov x0 1)
  (ret)
(: end-function)
"))
    (define cfg-b
      (source->cfg "
(: function unique_fn)
(: label entry)
  (mov x5 1)
  (ret)
(: end-function)
"))
    (define map-a (infer-all-abis cfg-a))
    (define map-b (infer-all-abis cfg-b))

    ;; 两个结果应该不同（不同的 def 集）
    (define def-a (inferred-abi-gpr-def
                    (function-abi-info-inferred-abi
                      (hash-ref map-a 'unique_fn))))
    (define def-b (inferred-abi-gpr-def
                    (function-abi-info-inferred-abi
                      (hash-ref map-b 'unique_fn))))
    (check-true (intbits-ref def-a 0))
    (check-false (intbits-ref def-a 5))
    (check-true (intbits-ref def-b 5))
    (check-false (intbits-ref def-b 0))))

;; ============================================================
;; SCC 不动点测试
;; ============================================================

(define-test-suite scc-fixpoint-tests
  (test-case "无内部边的 SCC 零迭代"
    ;; 单函数无递归调用
    (define cfg
      (source->cfg "
(: function simple)
(: label entry)
  (mov x0 1)
  (ret)
(: end-function)
"))
    (clear-abi-infer-cache!)
    (define abi-map (infer-all-abis cfg))
    (check-true (hash-has-key? abi-map 'simple))
    (define info (hash-ref abi-map 'simple))
    ;; 简单函数只有局部 def
    (check-true (intbits-ref
                  (inferred-abi-gpr-def (function-abi-info-inferred-abi info))
                  0)))

  (test-case "直接递归函数"
    ;; 函数调用自身
    (define cfg
      (source->cfg "
(: function recursive)
(: label entry)
  (cbz x0 .exit)
  (sub x0 x0 1)
  (bl recursive)
(: label exit)
  (ret)
(: end-function)
"))
    (clear-abi-infer-cache!)
    (define abi-map (infer-all-abis cfg))
    (check-true (hash-has-key? abi-map 'recursive))
    ;; 递归函数应正确推断
    (define info (hash-ref abi-map 'recursive))
    (check-not-false info))

  (test-case "相互递归函数"
    ;; A 调用 B，B 调用 A
    (define cfg
      (source->cfg "
(: function ping)
(: label entry)
  (cbz x0 .done)
  (sub x0 x0 1)
  (bl pong)
(: label done)
  (ret)
(: end-function)

(: function pong)
(: label entry)
  (cbz x0 .done)
  (sub x0 x0 1)
  (bl ping)
(: label done)
  (ret)
(: end-function)
"))
    (clear-abi-infer-cache!)
    (define abi-map (infer-all-abis cfg))
    (check-true (hash-has-key? abi-map 'ping))
    (check-true (hash-has-key? abi-map 'pong))
    ;; 两个函数的 def 集应包含 x0
    (define ping-def (inferred-abi-gpr-def
                       (function-abi-info-inferred-abi
                         (hash-ref abi-map 'ping))))
    (define pong-def (inferred-abi-gpr-def
                       (function-abi-info-inferred-abi
                         (hash-ref abi-map 'pong))))
    (check-true (intbits-ref ping-def 0))
    (check-true (intbits-ref pong-def 0)))

  (test-case "SCC 拓扑序正确 - 被调用者先于调用者"
    ;; a -> b -> c (a 调用 b，b 调用 c)
    ;; 推断顺序应该是 c 先于 b，b 先于 a
    (define cfg
      (source->cfg "
(: function c)
(: label entry)
  (mov x0 1)
  (ret)
(: end-function)

(: function b)
(: label entry)
  (bl c)
  (ret)
(: end-function)

(: function a)
(: label entry)
  (bl b)
  (ret)
(: end-function)
"))
    (clear-abi-infer-cache!)
    (define abi-map (infer-all-abis cfg))
    ;; 所有函数的推断结果应正确传递
    (define a-def (inferred-abi-gpr-def
                    (function-abi-info-inferred-abi
                      (hash-ref abi-map 'a))))
    (check-true (intbits-ref a-def 0)))

  (test-case "多个独立 SCC 正确处理"
    ;; 两组独立函数
    (define cfg
      (source->cfg "
(: function a1)
(: label entry)
  (mov x0 1)
  (ret)
(: end-function)

(: function a2)
(: label entry)
  (bl a1)
  (ret)
(: end-function)

(: function b1)
(: label entry)
  (mov x1 1)
  (ret)
(: end-function)

(: function b2)
(: label entry)
  (bl b1)
  (ret)
(: end-function)
"))
    (clear-abi-infer-cache!)
    (define abi-map (infer-all-abis cfg))
    ;; a2 应包含 x0 的 def
    (define a2-def (inferred-abi-gpr-def
                     (function-abi-info-inferred-abi
                       (hash-ref abi-map 'a2))))
    ;; b2 应包含 x1 的 def
    (define b2-def (inferred-abi-gpr-def
                     (function-abi-info-inferred-abi
                       (hash-ref abi-map 'b2))))
    (check-true (intbits-ref a2-def 0))
    (check-true (intbits-ref b2-def 1))))

(module+ test
  (run-tests abi-infer-tests)
  (run-tests infer-cache-tests)
  (run-tests scc-fixpoint-tests))
