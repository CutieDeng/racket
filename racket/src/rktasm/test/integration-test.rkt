#lang racket

;; ============================================================
;; test/integration-test.rkt - 高级集成测试
;; ============================================================
;;
;; 测试多个组件协作:
;; 1. inline + ABI 推断协作
;; 2. 多函数调用链 + 缓存复用
;; 3. ABI 配置热重载

(require rackunit
         rackunit/text-ui
         "../parser/frontend.rkt"
         "../parser/ast.rkt"
         "../semantic/control-flow.rkt"
         "../semantic/inline.rkt"
         "../pipeline/regalloc/abi.rkt"
         "../pipeline/regalloc/abi-config.rkt"
         "../pipeline/regalloc/abi-infer.rkt"
         "../pipeline/pipeline.rkt"
         "../codegen/emit.rkt"
         racket/intbits
         racket/file)

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

;; ============================================================
;; inline + ABI 推断协作测试
;; ============================================================

(define-test-suite inline-abi-integration-tests
  (test-case "inline 展开后 ABI 推断正确"
    (clear-abi-infer-cache!)
    (define source "
(: function callee)
(: label entry)
  (add x0 x0 1)
  (ret)
(: end-function)

(: function caller)
(: label entry)
  (mov x0 41)
  (: inline callee)
  (ret)
(: end-function)
")
    (define cfg (source->cfg source))
    ;; 展开 inline
    (define expanded-cfg (expand-inline-cfg cfg))
    ;; 对展开后的 CFG 进行 ABI 推断
    (define abi-map (infer-all-abis expanded-cfg))

    ;; caller 应该存在
    (check-true (hash-has-key? abi-map 'caller))
    (define caller-info (hash-ref abi-map 'caller))
    (check-not-false caller-info)

    ;; caller 应该有正确的 def 集（包含 x0）
    (define caller-def (inferred-abi-gpr-def
                         (function-abi-info-inferred-abi caller-info)))
    (check-true (intbits-ref caller-def 0)))

  (test-case "嵌套 inline 后 ABI 推断正确"
    (clear-abi-infer-cache!)
    (define source "
(: function innermost)
(: label entry)
  (add x0 x0 100)
  (ret)
(: end-function)

(: function middle)
(: label entry)
  (add x0 x0 10)
  (: inline innermost)
  (ret)
(: end-function)

(: function outer)
(: label entry)
  (mov x0 1)
  (: inline middle)
  (ret)
(: end-function)
")
    (define cfg (source->cfg source))
    (define expanded-cfg (expand-inline-cfg cfg))
    (define abi-map (infer-all-abis expanded-cfg))

    ;; outer 应该有正确的 def 集
    (define outer-info (hash-ref abi-map 'outer #f))
    (check-not-false outer-info)
    (define outer-def (inferred-abi-gpr-def
                        (function-abi-info-inferred-abi outer-info)))
    (check-true (intbits-ref outer-def 0))))

;; ============================================================
;; 多函数调用链 + 缓存复用测试
;; ============================================================

(define-test-suite call-chain-cache-tests
  (test-case "复杂调用链的 ABI 推断"
    (clear-abi-infer-cache!)
    (define source "
(: function leaf_a)
(: label entry)
  (mov x0 1)
  (ret)
(: end-function)

(: function leaf_b)
(: label entry)
  (mov x1 2)
  (ret)
(: end-function)

(: function middle)
(: label entry)
  (bl leaf_a)
  (bl leaf_b)
  (ret)
(: end-function)

(: function root)
(: label entry)
  (bl middle)
  (ret)
(: end-function)
")
    (define cfg (source->cfg source))
    (define abi-map (infer-all-abis cfg))

    ;; root 应该包含 leaf_a 和 leaf_b 的 def
    (define root-info (hash-ref abi-map 'root #f))
    (check-not-false root-info)
    (define root-def (inferred-abi-gpr-def
                       (function-abi-info-inferred-abi root-info)))
    (check-true (intbits-ref root-def 0))
    (check-true (intbits-ref root-def 1)))

  (test-case "缓存复用不污染跨 CFG 结果"
    (clear-abi-infer-cache!)

    ;; 第一个 CFG
    (define cfg1 (source->cfg "
(: function fn1)
(: label entry)
  (mov x0 1)
  (ret)
(: end-function)
"))
    (define map1 (infer-all-abis cfg1))

    ;; 第二个 CFG（不同函数体）
    (define cfg2 (source->cfg "
(: function fn1)
(: label entry)
  (mov x5 1)
  (ret)
(: end-function)
"))
    (define map2 (infer-all-abis cfg2))

    ;; 两个结果应该不同
    (define def1 (inferred-abi-gpr-def
                   (function-abi-info-inferred-abi
                     (hash-ref map1 'fn1))))
    (define def2 (inferred-abi-gpr-def
                   (function-abi-info-inferred-abi
                     (hash-ref map2 'fn1))))

    (check-true (intbits-ref def1 0))
    (check-false (intbits-ref def1 5))
    (check-true (intbits-ref def2 5))
    (check-false (intbits-ref def2 0))))

;; ============================================================
;; ABI 配置热重载测试
;; ============================================================

(define-test-suite abi-config-reload-tests
  (test-case "配置文件修改后重新加载"
    (define tmp (make-temporary-file "abi-hot-reload-~a.rktd"))
    (call-with-output-file tmp
      (lambda (out)
        (displayln "(testabi1" out)
        (displayln "  (gpr (num-regs 16) (banned #x0) (preserved #x0))" out)
        (displayln "  (fpr (num-regs 16) (banned #x0) (preserved #x0))" out)
        (displayln "  (pred (num-regs 16) (banned #x0) (preserved #x0)))" out))
      #:exists 'truncate/replace)

    (parameterize ([abi-config-path tmp])
      ;; 加载配置
      (define configs1 (reload-abi-config #:force? #t))
      (check-true (hash-has-key? configs1 'testabi1))

      ;; 修改配置
      (sleep 1.5)
      (call-with-output-file tmp
        (lambda (out)
          (displayln "(testabi1" out)
          (displayln "  (gpr (num-regs 32) (banned #x0) (preserved #x0))" out)
          (displayln "  (fpr (num-regs 32) (banned #x0) (preserved #x0))" out)
          (displayln "  (pred (num-regs 16) (banned #x0) (preserved #x0)))" out)
          (displayln "" out)
          (displayln "(testabi2" out)
          (displayln "  (gpr (num-regs 16) (banned #x0) (preserved #x0))" out)
          (displayln "  (fpr (num-regs 16) (banned #x0) (preserved #x0))" out)
          (displayln "  (pred (num-regs 16) (banned #x0) (preserved #x0)))" out))
        #:exists 'truncate/replace)

      ;; 重新加载
      (define configs2 (reload-abi-config #:force? #t))
      (check-true (hash-has-key? configs2 'testabi1))
      (check-true (hash-has-key? configs2 'testabi2))

      ;; 验证 testabi1 已更新
      (define abi1 (hash-ref configs2 'testabi1))
      (check-equal? (reg-class-config-num-regs (abi-config-gpr abi1)) 32))

    (delete-file tmp))

  (test-case "default-abi-name 切换影响推断"
    (clear-abi-infer-cache!)
    (define cfg (source->cfg "
(: function dyn)
(: label entry)
  (blr x16)
  (ret)
(: end-function)
"))

    ;; 使用 aapcs64
    (default-abi-name 'aapcs64)
    (define map1 (infer-all-abis cfg))
    (define def1 (inferred-abi-gpr-def
                   (function-abi-info-inferred-abi
                     (hash-ref map1 'dyn))))

    ;; 使用 leaf (x30 不再 preserved)
    (default-abi-name 'leaf)
    (define map2 (infer-all-abis cfg))
    (define def2 (inferred-abi-gpr-def
                   (function-abi-info-inferred-abi
                     (hash-ref map2 'dyn))))

    ;; aapcs64: x30 是 callee-saved，不在 scratch 中
    (check-false (intbits-ref def1 30))
    ;; leaf: x30 不是 preserved，在 scratch 中
    (check-true (intbits-ref def2 30))

    ;; 恢复默认
    (default-abi-name 'aapcs64)))

;; ============================================================
;; 端到端编译测试
;; ============================================================

(define-test-suite end-to-end-tests
  (test-case "完整编译流程：解析 -> inline -> ABI 推断 -> 代码生成"
    (define source "
(: function add1)
(: label entry)
  (add x0 x0 1)
  (ret)
(: end-function)

(: function add10)
(: label entry)
  (: inline add1)
  (: inline add1)
  (: inline add1)
  (: inline add1)
  (: inline add1)
  (: inline add1)
  (: inline add1)
  (: inline add1)
  (: inline add1)
  (: inline add1)
  (ret)
(: end-function)
")
    (define cfg (source->cfg source))

    ;; 展开 inline
    (define expanded-cfg (expand-inline-cfg cfg))
    (check-not-false expanded-cfg)

    ;; ABI 推断
    (define abi-map (infer-all-abis expanded-cfg))
    (check-true (hash-has-key? abi-map 'add10))

    ;; 对每个函数运行流水线
    (for ([i (in-range (cfg-function-count expanded-cfg))])
      (define fn (cfg-get-function expanded-cfg i))
      (define result (run-pipeline fn default-pipeline-config))
      (check-true (null? (pipeline-result-errors result))))))

;; ============================================================
;; 运行所有测试
;; ============================================================

(module+ test
  (run-tests inline-abi-integration-tests)
  (run-tests call-chain-cache-tests)
  (run-tests abi-config-reload-tests)
  (run-tests end-to-end-tests))
