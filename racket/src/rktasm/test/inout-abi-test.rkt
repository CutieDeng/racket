#lang racket

;; ============================================================
;; test/inout-abi-test.rkt - in-place (inout) 参数 ABI 测试
;; ============================================================
;;
;; 验证 `inout:` 参数模式：一个参数同时作输入与输出，复用同一个 ABI 槽
;; (同一物理寄存器)。用于就地域运算 (a = a + b, 结果写回 a 的寄存器)，
;; 无需为输出单独分配返回槽。P-256 域加/减/除2 的 asmp 内核依赖此特性。

(require rackunit
         rackunit/text-ui
         "../parser/frontend.rkt"
         "../parser/ast.rkt"
         "../semantic/control-flow.rkt"
         "../semantic/inline.rkt"
         "../semantic/ipa-callconv.rkt"
         "../pipeline/pipeline.rkt"
         "../pipeline/regalloc/abi-config.rkt"
         "../codegen/emit.rkt")

(define here (path-only (syntax-source #'here)))
(define repo-dir (simplify-path (build-path here "..")))
(define project-abi-config (simplify-path (build-path repo-dir "config" "abi.rktd")))

;; 编译 GNU 语法源码为汇编字符串 (加载项目 ABI 配置)
(define (compile-gnu source)
  (parameterize ([abi-config-path project-abi-config])
    (reload-abi-config project-abi-config #:force? #t)
    (define results (parse-string source #:source "inout-test" #:syntax 'gnu))
    (when (parse-results-has-errors? results)
      (error 'compile-gnu "解析错误:\n~a" (format-parse-errors-report results)))
    (define items
      (for/list ([r (parse-results-items results)] #:when (parse-result-ok? r))
        (parse-result-instruction r)))
    (define cfg (expand-inline-cfg (build-cfg items)))
    (define asm-parts
      (for/list ([i (in-range (cfg-function-count cfg))])
        (define fn (cfg-get-function cfg i))
        (define result (run-pipeline fn default-pipeline-config))
        (unless (null? (pipeline-result-errors result))
          (error 'compile-gnu "编译错误:\n~a" (pipeline-result-errors result)))
        (emit-function (pipeline-result-function result))))
    (string-join asm-parts "\n")))

(define (contains? s sub) (and (regexp-match? (regexp (regexp-quote sub)) s) #t))

(define-test-suite inout-tests
  ;; oadd ABI: a=x14-x17 (inout 槽), b=x8-x11。就地加 → 结果落 a 的寄存器 x14-x17。
  (test-case "inout 参数复用输入槽 (就地写回同一寄存器)"
    (define asm
      (compile-gnu "
.function inplace_add abi=oadd (
  inout: x.a0, x.a1, x.a2, x.a3,
  in: x.b0, x.b1, x.b2, x.b3
)
entry:
  adds x.a0, x.a0, x.b0
  adcs x.a1, x.a1, x.b1
  adcs x.a2, x.a2, x.b2
  adcs x.a3, x.a3, x.b3
  ret
.end
"))
    ;; inout 的本质: 输入寄存器 == 输出寄存器 (就地)。a0 映射到 oadd arg 槽 0 = x14,
    ;; 且 `adds x14, x14, x8` 同时读写 x14 —— 输入与输出复用同一物理寄存器。
    (check-true (contains? asm "adds x14, x14, x8")
                "inout a0 应就地读写 x14 (输入槽 == 输出槽)"))

  ;; 对比: 非 inout (in + 独立 out) 会因输出槽索引超出 args 而报错。
  ;; 这里只验证 inout 不需要额外返回槽即可编译通过。
  (test-case "inout 无需额外返回槽即可编译"
    (check-not-exn
     (lambda ()
       (compile-gnu "
.function inplace_dbl abi=oun (
  inout: x.a0, x.a1, x.a2, x.a3
)
entry:
  adds x.a0, x.a0, x.a0
  adcs x.a1, x.a1, x.a1
  adcs x.a2, x.a2, x.a2
  adcs x.a3, x.a3, x.a3
  ret
.end
")))))

(module+ main
  (run-tests inout-tests))
(module+ test
  (run-tests inout-tests))
