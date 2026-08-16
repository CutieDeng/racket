#lang racket

;; ============================================================
;; pipeline/analysis/perf-report.rkt - 性能分析报告
;; ============================================================
;;
;; 编译后输出分析报告：
;;   1. 溢出报告：哪些变量被溢出，在哪个循环深度
;;   2. load-use 依赖链：可能的流水线停顿
;;   3. ABI 建议：可以使用更宽松的 ABI

(require "dep-chain.rkt"
         "../regalloc/loop-analysis.rkt"
         "../regalloc/allocator.rkt"
         "../regalloc/abi-infer.rkt"
         "../regalloc/types.rkt"
         "../../semantic/control-flow.rkt"
         "../../semantic/use-def.rkt"
         "../../parser/ast.rkt"
         racket/pvector
         racket/intmap)

(provide
  generate-perf-report)

;; ============================================================
;; 主函数
;; ============================================================

;; 生成性能分析报告
;; pipeline-results : (listof pipeline-result)  — 来自 run-regalloc-stage
;; functions : (listof asm-function) — inline 展开后的函数列表
;; abi-info-map : hash[fn-name -> function-abi-info]
;; → string
(define (generate-perf-report pipeline-results functions abi-info-map)
  (define lines '())
  (define (emit! s) (set! lines (cons s lines)))

  (emit! "=== 性能分析 ===")

  (for ([r (in-list pipeline-results)]
        [fn (in-list functions)])
    (define fn-name (asm-function-name fn))
    (define fn-lines '())
    (define (fn-emit! s) (set! fn-lines (cons s fn-lines)))

    ;; 1. 溢出报告
    (define alloc (pipeline-result-allocation r))
    (define spilled (alloc-result-spilled alloc))
    (define depths (compute-loop-depths fn))

    (when (> (pvector-length spilled) 0)
      (for ([reg (in-pvector spilled)])
        ;; 找到变量被使用的最深循环深度
        (define max-depth
          (for*/fold ([md 0])
                     ([kv (in-intmap-pairs (asm-function-blocks fn))]
                      [ins (in-pvector (basic-block-instructions (cdr kv)))]
                      #:when (ast-ins? ins))
            (define ud (extract-use-def ins))
            (define refs (append (use-def-flat-defs ud) (use-def-flat-uses ud)))
            (define mentions-reg?
              (for/or ([ref (in-list refs)])
                (equal? (reg-ref->reg-id ref) reg)))
            (if mentions-reg?
                (max md (get-loop-depth depths (car kv)))
                md)))

        ;; 估计额外内存指令（每个 use/def 点 2 条：一次 load + 一次 store）
        (define use-count
          (for*/sum ([kv (in-intmap-pairs (asm-function-blocks fn))]
                     [ins (in-pvector (basic-block-instructions (cdr kv)))]
                     #:when (ast-ins? ins))
            (define ud (extract-use-def ins))
            (define refs (append (use-def-flat-defs ud) (use-def-flat-uses ud)))
            (if (for/or ([ref (in-list refs)])
                  (equal? (reg-ref->reg-id ref) reg))
                1 0)))

        (define extra-mem-insns (* use-count 2))

        (define reg-name (format-reg-id* reg))
        (if (> max-depth 0)
            (fn-emit! (format "  \u26A0 变量 ~a 在循环 (深度 ~a) 中被溢出，估计额外 ~a 条内存指令"
                              reg-name max-depth extra-mem-insns))
            (fn-emit! (format "  \u26A0 变量 ~a 被溢出，估计额外 ~a 条内存指令"
                              reg-name extra-mem-insns)))))

    ;; 2. load-use 依赖链分析（对分配后的函数）
    (define final-fn (pipeline-result-function r))
    (define load-use-warnings (analyze-load-use-deps final-fn))

    (for ([w (in-list load-use-warnings)])
      (define load-loc (load-use-warning-load-loc w))
      (define load-line (and load-loc (srcloc-line load-loc)))
      (define use-loc (load-use-warning-use-loc w))
      (define use-line (and use-loc (srcloc-line use-loc)))
      (define line-str
        (cond
          [(and load-line use-line)
           (format "第 ~a-~a 行" load-line use-line)]
          [load-line (format "第 ~a 行" load-line)]
          [else "未知位置"]))

      (fn-emit! (format "  \u26A0 ~a: load-use 依赖链 (~a → ~a)，间隔 ~a 条指令，建议插入无关指令"
                        line-str
                        (load-use-warning-load-mnem w)
                        (load-use-warning-use-mnem w)
                        (load-use-warning-gap w))))

    ;; 3. ABI 建议
    (define info (and abi-info-map (get-function-abi-info abi-info-map fn-name)))
    (when info
      (define explicit-abi (fn-get-info fn 'abi #f))
      (define callees (function-abi-info-callees info))
      ;; 如果声明了 aapcs64 但实际无调用 → 建议 leaf
      (when (and explicit-abi
                 (eq? explicit-abi 'aapcs64)
                 (null? callees)
                 (function-is-leaf? fn))
        (fn-emit! (format "  \u2139 此函数可使用 (abi leaf) 释放 x29/x30 作为 scratch"))))

    ;; 输出函数报告
    (emit! (format "~a:" fn-name))
    (if (null? fn-lines)
        (emit! "  \u2713 无溢出，无明显 IPC 瓶颈")
        (for ([l (in-list (reverse fn-lines))])
          (emit! l))))

  (string-join (reverse lines) "\n"))

;; ============================================================
;; 辅助
;; ============================================================

;; 需要从 pipeline-result 获取信息
(require "../pipeline.rkt")

(define (format-reg-id* r)
  (define prefix (case (reg-id-class r) [(gpr) "x"] [(fpr) "v"] [(predicate) "p"] [else "?"]))
  (if (reg-id-virtual? r)
      (format "~a.~a" prefix (reg-id-id r))
      (format "~a~a" prefix (reg-id-id r))))
