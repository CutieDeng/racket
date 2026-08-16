#lang racket

;; ============================================================
;; test/inline-test.rkt - Inline 展开功能测试
;; ============================================================
;;
;; 本测试文件验证 inline 展开功能，包括：
;; 1. 基本inline展开
;; 2. 变量重命名（虚拟寄存器冲突避免）
;; 3. 标签重命名（标签冲突避免）
;; 4. ret指令变换（跳转到出口标签）
;; 5. 嵌套inline
;; 6. 错误检测（递归、不存在目标）
;; 7. save!/load! 指令重写
;; 8. 内存操作数重写

(require rackunit
         rackunit/text-ui
         "../parser/frontend.rkt"
         "../parser/ast.rkt"
         "../semantic/control-flow.rkt"
         "../semantic/inline.rkt"
         racket/pvector
         "../pipeline/pipeline.rkt"
         "../codegen/emit.rkt")

;; ============================================================
;; 辅助函数
;; ============================================================

;; 完整编译：源码 → 汇编字符串
(define (compile-to-asm source #:config [config default-pipeline-config]
                                #:emit-config [emit-cfg default-emit-config])
  (define results (parse-string source))

  ;; 检查解析错误
  (when (parse-results-has-errors? results)
    (error 'compile-to-asm "解析错误:\n~a"
           (format-parse-errors-report results)))

  ;; 提取 AST
  (define items
    (for/list ([r (parse-results-items results)]
               #:when (parse-result-ok? r))
      (parse-result-instruction r)))

  ;; 构建 CFG（保留 inline 指令）
  (define cfg (build-cfg items))
  ;; 在 CFG 构建后展开 inline
  (define expanded-cfg (expand-inline-cfg cfg))

  ;; 对每个函数运行流水线
  (define compiled-fns
    (for/list ([i (in-range (cfg-function-count expanded-cfg))])
      (define fn (cfg-get-function expanded-cfg i))
      (run-pipeline fn config)))

  ;; 检查编译错误
  (for ([result (in-list compiled-fns)])
    (unless (null? (pipeline-result-errors result))
      (error 'compile-to-asm "编译错误:\n~a"
             (string-join (pipeline-result-errors result) "\n"))))

  ;; 生成汇编
  (parameterize ([current-emit-config emit-cfg])
    (string-join
     (for/list ([result (in-list compiled-fns)])
       (emit-function/result result))
     "\n\n")))

(define (asm-contains? asm pattern)
  (regexp-match? (regexp pattern) asm))

(define (asm-not-contains? asm pattern)
  (not (asm-contains? asm pattern)))

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
;; 测试套件
;; ============================================================

(define-test-suite cfg-phase-inline-tests
  (test-case "CFG 阶段保留 inline 指令"
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
    (define caller (cfg-get-function cfg 1))
    (define block (fn-entry-block caller))
    (check-true
     (for/or ([ins (in-pvector (basic-block-instructions block))])
       (and (ast-directive? ins)
            (eq? (ast-directive-kind ins) 'inline)))
     "build-cfg 结果中应保留 (: inline ...)")))

(define-test-suite basic-inline-tests
  (test-case "基本 inline 展开"
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
    (define asm (compile-to-asm source))
    ;; inline 不应生成 bl 指令
    (check-pred (lambda (s) (asm-not-contains? s "bl callee")) asm
                "inline 不应生成 bl 指令")
    ;; 应该有内联后的代码
    (check-pred (lambda (s) (asm-contains? s "add x0, x0, #1")) asm
                "应包含内联后的 add 指令"))

  (test-case "inline 展开后的标签命名"
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
    (define asm (compile-to-asm source))
    ;; 应该生成内联后的局部标签（格式是 inl_caller_callee）
    (check-pred (lambda (s) (asm-contains? s "Lcaller\\$inl_caller_callee")) asm
                "应生成带有前缀的内联标签"))

  (test-case "末尾 ret 的 inline 出口跳转可省略"
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
    (define asm (compile-to-asm source))
    ;; callee 末尾 ret 的出口标签紧随其后时，可以直接 fall through。
    (check-pred (lambda (s) (asm-not-contains? s "b Lcaller\\$inl_caller_callee_1__exit")) asm
                "末尾 ret 不应生成跳到下一标签的空跳转")
    (check-pred (lambda (s) (asm-contains? s "Lcaller\\$inl_caller_callee_1__exit:")) asm
                "inline 出口标签仍应保留"))

  (test-case "branch to label colocated with inline call"
    (define source "
(: function callee)
(: label entry)
  (add x0 x0 1)
  (ret)
(: end-function)

(: function caller)
(: label entry)
  (b target)
(: label target)
  (: inline callee)
  (ret)
(: end-function)
")
    (define asm (compile-to-asm source))
    ;; The caller label is colocated with the inlined callee entry label.
    ;; It must remain branchable as a local label, not leak as an external name.
    (check-pred (lambda (s) (asm-not-contains? s "b target")) asm
                "同位置 inline 标签不应丢失 caller 标签"))

  (test-case "inline keeps cold branch to template join label"
    (define source "
(: function callee)
(: label entry)
  (cmp x0 32)
  (b.hs two)
  (mov x1 1)
  (b done)
(: label two)
  (cmp x0 4096)
  (b.hs three)
  (mov x1 2)
  (b done)
(: label three)
  (mov x1 3)
  (b done)
(: label done)
  (add x2 x2 1)
  (ret)
(: end-function)

(: function caller)
(: label entry)
  (: inline callee)
(: label after)
  (mov x3 3)
  (ret)
(: end-function)
")
    (define asm (compile-to-asm source))
    (check-pred
     (lambda (s)
       (regexp-match?
        #rx"Lcaller\\$inl_caller_callee_[0-9]+__three:\n    mov x[0-9]+, #3\n    b Lcaller\\$inl_caller_callee_[0-9]+__done"
        s))
     asm
     "冷分支不能因 inline 块重排而落入 caller 后续块"))

  (test-case "inline materializes reordered implicit fallthrough to template join label"
    (define source "
(: function callee)
(: label entry)
  (cmp x0 0)
  (b.eq good)
  (b done)
(: label good)
  (mov x1 1)
(: label done)
  (ret)
(: end-function)

(: function caller)
(: label entry)
  (: inline callee)
(: label after)
  (mov x3 3)
  (ret)
(: end-function)
")
    (define asm (compile-to-asm source))
    (check-pred
     (lambda (s)
       (regexp-match?
        #rx"Lcaller\\$inl_caller_callee_[0-9]+__good:\n    mov x1, #1\n    b Lcaller\\$inl_caller_callee_[0-9]+__done"
        s))
     asm
     "隐式 fallthrough 若被块布局打散，必须补成显式跳转")))

(define-test-suite variable-renaming-tests
  (test-case "虚拟寄存器重命名避免冲突"
    (define source "
(: function callee)
(: label entry)
  (add %result %x 1)
  (mov x0 %result)
  (ret)
(: end-function)

(: function caller)
(: label entry)
  (mov %x 41)
  (: inline callee)
  (mov x1 %result)
  (ret)
(: end-function)
")
    (define asm (compile-to-asm source))
    ;; 编译应该成功，说明重命名正确
    (check-pred string? asm))

  (test-case "多个 inline 调用的寄存器隔离"
    (define source "
(: function add1)
(: label entry)
  (add %tmp %input 1)
  (mov x0 %tmp)
  (ret)
(: end-function)

(: function caller)
(: label entry)
  (mov %input 10)
  (: inline add1)
  (mov %input 20)
  (: inline add1)
  (ret)
(: end-function)
")
    (define asm (compile-to-asm source))
    ;; 两次 inline 应该使用不同的寄存器前缀
    (check-pred string? asm)))

(define-test-suite label-renaming-tests
  (test-case "局部标签重命名"
    (define source "
(: function callee)
(: label entry)
  (cbz x0 .skip_add)
  (add x0 x0 1)
(: label skip_add)
  (ret)
(: end-function)

(: function caller)
(: label entry)
  (mov x0 5)
  (: inline callee)
  (ret)
(: end-function)
")
    (define asm (compile-to-asm source))
    ;; 局部标签应该被重命名
    (check-pred (lambda (s) (asm-contains? s "inl_caller_callee")) asm
                "局部标签应被重命名以包含前缀"))

  (test-case "caller 和 callee 都有同名局部标签"
    (define source "
(: function callee)
(: label loop)
  (subs x0 x0 1)
  (b.ne .loop)
  (ret)
(: end-function)

(: function caller)
(: label loop)
  (mov x0 5)
  (: inline callee)
  (subs x1 x1 1)
  (b.ne .loop)
  (ret)
(: end-function)
")
    (define asm (compile-to-asm source))
    ;; 两个 loop 标签应该不冲突
    (check-pred string? asm)))

(define-test-suite nested-inline-tests
  (test-case "嵌套 inline（A inline B，B inline C）"
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
    (define asm (compile-to-asm source))
    ;; 不应有任何 bl 指令（除了可能的系统调用）
    (check-pred (lambda (s) (asm-not-contains? s "bl middle")) asm
                "middle 不应通过 bl 调用")
    (check-pred (lambda (s) (asm-not-contains? s "bl innermost")) asm
                "innermost 不应通过 bl 调用")))

(define-test-suite error-detection-tests
  (test-case "inline 目标不存在时报错"
    (define source "
(: function caller)
(: label entry)
  (: inline nonexistent)
  (ret)
(: end-function)
")
    (check-exn #rx"inline 目标函数不存在"
               (lambda () (compile-to-asm source))))

  (test-case "递归 inline 检测（直接递归）"
    (define source "
(: function recursive)
(: label entry)
  (: inline recursive)
  (ret)
(: end-function)
")
    (check-exn #rx"检测到递归 inline"
               (lambda () (compile-to-asm source))))

  (test-case "递归 inline 检测（间接递归）"
    (define source "
(: function f)
(: label entry)
  (: inline g)
  (ret)
(: end-function)

(: function g)
(: label entry)
  (: inline f)
  (ret)
(: end-function)
")
    (check-exn #rx"检测到递归 inline"
               (lambda () (compile-to-asm source))))

  (test-case "eret 不能用于 inline 函数"
    (define source "
(: function callee)
(: label entry)
  (eret)
(: end-function)

(: function caller)
(: label entry)
  (: inline callee)
  (ret)
(: end-function)
")
    (check-exn #rx"eret 不能用于"
               (lambda () (compile-to-asm source)))))

(define-test-suite memory-operand-tests
  (test-case "内存操作数中的虚拟寄存器重写"
    (define source "
(: function callee)
(: label entry)
  (ldr %tmp [x0])
  (add %tmp %tmp 1)
  (str %tmp [x0])
  (ret)
(: end-function)

(: function caller)
(: label entry)
  (mov x0 100)
  (: inline callee)
  (ret)
(: end-function)
")
    (define asm (compile-to-asm source))
    (check-pred string? asm))

  (test-case "带偏移的内存操作数"
    (define source "
(: function callee)
(: label entry)
  (ldr %val [x0 %offset])
  (add %val %val 1)
  (str %val [x0 %offset])
  (ret)
(: end-function)

(: function caller)
(: label entry)
  (mov x0 100)
  (mov %offset 8)
  (: inline callee)
  (ret)
(: end-function)
")
    (define asm (compile-to-asm source))
    (check-pred string? asm)))

;; ============================================================
;; 运行所有测试
;; ============================================================

;; ============================================================
;; CFG 级 inline 展开测试
;; ============================================================

(define-test-suite cfg-level-inline-tests
  (test-case "expand-inline-cfg 无 inline 时返回原 CFG"
    (define source "
(: function simple)
(: label entry)
  (mov x0 1)
  (ret)
(: end-function)
")
    (define cfg (source->cfg source))
    (define expanded (expand-inline-cfg cfg))
    ;; 无 inline 时应返回原对象
    (check-true (eq? cfg expanded)))

  (test-case "expand-inline-cfg 有 inline 时返回新 CFG"
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
    (define expanded (expand-inline-cfg cfg))
    ;; 有 inline 时应返回新对象
    (check-false (eq? cfg expanded))
    ;; 展开后函数数量应相同
    (check-equal? (cfg-function-count cfg) (cfg-function-count expanded)))

  (test-case "expand-inline-cfg 保留 CFG 调试信息"
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
    ;; 使用 cfg-set-info 设置调试信息
    (define cfg-with-info (cfg-set-info cfg 'test-key 'test-value))
    (define expanded (expand-inline-cfg cfg-with-info))
    ;; 调试信息应保留
    (check-equal? (cfg-get-info expanded 'test-key #f) 'test-value))

  (test-case "expand-inline-cfg 检测并处理 inline 指令"
    ;; 通过展开结果验证 inline 被正确检测
    (define source-with-inline "
(: function callee)
(: label entry)
  (add x0 x0 1)
  (ret)
(: end-function)

(: function caller)
(: label entry)
  (: inline callee)
  (ret)
(: end-function)
")
    (define source-without-inline "
(: function simple)
(: label entry)
  (mov x0 1)
  (ret)
(: end-function)
")
    (define cfg-with (source->cfg source-with-inline))
    (define cfg-without (source->cfg source-without-inline))

    ;; 有 inline 的 CFG 展开后应该返回不同的对象
    (define expanded-with (expand-inline-cfg cfg-with))
    (check-false (eq? cfg-with expanded-with))

    ;; 无 inline 的 CFG 展开后应该返回相同的对象
    (define expanded-without (expand-inline-cfg cfg-without))
    (check-true (eq? cfg-without expanded-without)))

  (test-case "expand-inline-cfg 处理多个 inline"
    (define source "
(: function add1)
(: label entry)
  (add x0 x0 1)
  (ret)
(: end-function)

(: function caller)
(: label entry)
  (mov x0 10)
  (: inline add1)
  (: inline add1)
  (: inline add1)
  (ret)
(: end-function)
")
    (define cfg (source->cfg source))
    (define expanded (expand-inline-cfg cfg))
    ;; 应成功展开多个 inline
    (check-not-false expanded)
    (check-equal? (cfg-function-count expanded) 2)))

(module+ test
  (run-tests cfg-phase-inline-tests)
  (run-tests basic-inline-tests)
  (run-tests variable-renaming-tests)
  (run-tests label-renaming-tests)
  (run-tests nested-inline-tests)
  (run-tests error-detection-tests)
  (run-tests memory-operand-tests)
  (run-tests cfg-level-inline-tests))
