#lang racket

;; ============================================================
;; pipeline/analysis/dep-chain.rkt - 指令依赖链分析
;; ============================================================
;;
;; 在寄存器分配完成后（物理寄存器已确定），分析 load-use 依赖链。
;; 报告可能导致流水线停顿的模式：
;;   - load 指令的目标寄存器在紧接的下一条指令中被使用
;;     （ARM64 L1 cache hit ≈ 4 cycles latency）

(require "../../semantic/control-flow.rkt"
         "../../semantic/use-def.rkt"
         "../../parser/ast.rkt"
         "../regalloc/types.rkt"
         racket/pvector
         racket/intmap)

(provide
  (struct-out load-use-warning)
  analyze-load-use-deps)

;; ============================================================
;; 数据结构
;; ============================================================

;; load-use 停顿警告
(struct load-use-warning
  (fn-name          ; symbol — 函数名
   load-ins         ; ast-ins — load 指令
   use-ins          ; ast-ins — 使用指令
   load-loc         ; srcloc
   use-loc          ; srcloc
   gap              ; integer — 间隔指令数（0 = 紧邻）
   load-mnem        ; symbol — load 助记符
   use-mnem)        ; symbol — use 助记符
  #:transparent)

;; ============================================================
;; ARM64 load 指令判断
;; ============================================================

(define load-mnemonics
  '(ldr ldp ldrb ldrh ldrsb ldrsh ldrsw ldrex ldxr ldaxr
    ldur ldurb ldurh ldursb ldursh ldursw
    ld1 ld2 ld3 ld4 ld1r ld2r ld3r ld4r))

(define (load-instruction? ins)
  (and (ast-ins? ins)
       (memq (ast-ins-mnemonic ins) load-mnemonics)))

;; ============================================================
;; 分析
;; ============================================================

;; 分析函数中的 load-use 依赖
;; fn : asm-function （寄存器分配完成后的函数）
;; → (listof load-use-warning)
(define (analyze-load-use-deps fn)
  (define fn-name (asm-function-name fn))
  (define warnings '())

  (for ([kv (in-intmap-pairs (asm-function-blocks fn))])
    (define block (cdr kv))
    (define insns (basic-block-instructions block))
    (define len (pvector-length insns))

    ;; 遍历每对相邻指令
    (for ([i (in-range (sub1 len))])
      (define ins1 (pvector-ref insns i))
      (define ins2 (pvector-ref insns (add1 i)))

      (when (and (load-instruction? ins1) (ast-ins? ins2))
        ;; 获取 load 的 def 寄存器
        (define load-ud (extract-use-def ins1))
        (define load-defs (use-def-flat-defs load-ud))

        ;; 获取下一条指令的 use 寄存器
        (define use-ud (extract-use-def ins2))
        (define use-uses (use-def-flat-uses use-ud))

        ;; 检查是否有 def-use 重叠
        (define load-def-ids
          (for/set ([ref (in-list load-defs)])
            (reg-ref->reg-id ref)))
        (define has-dep?
          (for/or ([ref (in-list use-uses)])
            (set-member? load-def-ids (reg-ref->reg-id ref))))

        (when has-dep?
          (set! warnings
                (cons (load-use-warning
                       fn-name
                       ins1 ins2
                       (ast-srcloc ins1) (ast-srcloc ins2)
                       0
                       (ast-ins-mnemonic ins1)
                       (ast-ins-mnemonic ins2))
                      warnings))))))

  (reverse warnings))
