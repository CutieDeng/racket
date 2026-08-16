#lang racket

;; ============================================================
;; pipeline/pipeline.rkt - 代码变换流水线
;; ============================================================

(require "regalloc/types.rkt"
         "regalloc/liveness.rkt"
         "regalloc/interference.rkt"
         "regalloc/allocator.rkt"
         "regalloc/rewriter.rkt"
         "regalloc/abi.rkt"
         "regalloc/spill-config.rkt"
         "regalloc/save-load.rkt"
         "regalloc/loop-analysis.rkt"
         "regalloc/remat-split.rkt"
         "../semantic/control-flow.rkt"
         "../semantic/use-def.rkt"
         "../semantic/validate.rkt"
         "../parser/ast.rkt"
         racket/pvector
         racket/intmap)

(provide
  ;; 主流水线
  run-pipeline
  run-regalloc-pipeline
  run-pipeline-with-abi-info

  ;; 健全性关卡（post-inline 调用；param-syms 由 cfg 阶段捕获）
  check-no-undefined-gpr-virtuals
  declared-param-reg-symbols

  ;; 流水线配置
  (struct-out pipeline-config)
  default-pipeline-config
  make-pipeline-config

  ;; 流水线结果
  (struct-out pipeline-result)

  ;; 重导出语义验证
  (all-from-out "../semantic/validate.rkt")

  ;; 重导出寄存器分配相关
  (all-from-out "regalloc/types.rkt")
  (all-from-out "regalloc/liveness.rkt")
  (all-from-out "regalloc/interference.rkt")
  (all-from-out "regalloc/allocator.rkt")
  (all-from-out "regalloc/rewriter.rkt")
  (all-from-out "regalloc/abi.rkt")
  (all-from-out "regalloc/spill-config.rkt")
  (all-from-out "regalloc/save-load.rkt")
  (all-from-out "regalloc/loop-analysis.rkt"))

;; ============================================================
;; 配置
;; ============================================================

(struct pipeline-config
  (abi              ; abi-config - ABI 配置
   spill            ; spill-config - 溢出策略
   max-iters        ; integer - 最大迭代次数
   debug-level)     ; 0=none, 1=summary, 2=detail, 3=trace
  #:transparent)

(define (make-pipeline-config
          #:abi [abi arm64-abi]
          #:spill [spill default-spill-config]
          #:max-iters [max-iters 10]
          #:debug-level [debug-level 0])
  (pipeline-config abi spill max-iters debug-level))

(define default-pipeline-config
  (make-pipeline-config))

;; ============================================================
;; 结果
;; ============================================================

(struct pipeline-result
  (function          ; 变换后的 asm-function
   liveness          ; fn-liveness
   interference      ; multi-class-ig (3 张干涉图)
   allocation        ; alloc-result (合并后的分配结果)
   multi-allocation  ; multi-alloc-result (分类的分配结果)
   spill-slots       ; pvector[spill-slot]
   frame-size        ; 栈帧大小
   iterations        ; 溢出迭代次数
   errors)           ; (listof error) - 分配失败信息
  #:transparent)

;; ============================================================
;; 主流水线
;; ============================================================

(define (run-pipeline fn [config default-pipeline-config])
  (run-regalloc-pipeline fn config))

;; 带 ABI 信息的流水线（用于假溢出分析）
(define (run-pipeline-with-abi-info fn config abi-info-map)
  (run-regalloc-pipeline fn config #:abi-info-map abi-info-map))

(define (debug-ref-byte-size ref)
  (case (reg-ref-kind ref)
    [(w s) 4]
    [(x d) 8]
    [(b) 1]
    [(h) 2]
    [(q v z) 16]
    [else 8]))

(define (debug-ref-name ref)
  (format "~a.~a" (reg-ref-kind ref) (reg-ref-id ref)))

(define (collect-debug-reg-views fn)
  (define seen (make-hash))
  (define views '())
  (fn-for-each-block
   fn
   (lambda (block)
     (for ([ins (in-pvector (basic-block-instructions block))])
       (when (ast-ins? ins)
         (define use-def (extract-use-def ins))
         (for ([ref (in-list (append (use-def-flat-defs use-def)
                                     (use-def-flat-uses use-def)))])
           (define rid (reg-ref->reg-id ref))
           (when (reg-id-virtual? rid)
             (define name (debug-ref-name ref))
             (define key (list rid name))
             (unless (hash-ref seen key #f)
               (hash-set! seen key #t)
               (set! views
                     (cons (hash 'reg rid
                                 'name name
                                 'byte-size (debug-ref-byte-size ref))
                           views)))))))))
  (reverse views))

(define (attach-debug-reg-map fn alloc-result effective-abi iter)
  (define records (fn-get-info fn 'debug-reg-maps '()))
  (fn-set-info
   fn
   'debug-reg-maps
   (append records
           (list (hash 'iteration iter
                       'allocation alloc-result
                       'effective-abi effective-abi
                       'views (collect-debug-reg-views fn))))))

;; 健全性关卡：GPR 虚拟寄存器被“使用”却在整个函数体内“从未被定义”，且不是声明
;; 形参（in:/out:）——这样的寄存器没有任何值来源。它多半是忘了在 `.context` 里
;; pin 到物理寄存器、或忘了 `in:` 声明的入参（典型：某个入参指针）。旧行为是把它
;; 静默着色到任意物理寄存器、产出读错寄存器的代码（如从错误地址加载 → 运行时
;; 段错误）；这里改为汇编期 fail-fast，带清晰指引。
;;
;; 只查“通篇无定义”（而非 liveness 的 live-in）：liveness 是保守上近似，会把大量
;; 已定义、只是某路径上先用后定义的正常临时算作入口 live-in（deflate 库里有几十
;; 个这样的临时，差分已验证正确）——用“无定义”做信号才能零误报地区分真 bug。
;; 只查 GPR：整数/指针入参是危险类；向量的 SHA3 指令(eor3/rax1)use-def 建模不全，
;; 不纳入以免误报。声明形参（in:/out:）合法地“无定义”（值由 ABI 传入），须排除。
(define (declared-param-reg-symbols fn)
  (define params (fn-get-info fn 'function-params #f))
  (if params
      (for/fold ([s (set)]) ([param (in-list params)])
        (match param
          [(list _mode (? ast-reg? formal)) (set-add s (ast-reg-id formal))]
          [_ s]))
      (set)))

;; `param-syms`：该函数声明形参(in:/out:)的寄存器符号集，由调用方在 function-params
;; 尚存时(cfg 阶段捕获的函数)算好传入——因为到 post-inline 时 callconv 已消费它。
;; 调用点必须是 **post-inline**(cli/as.rkt run-regalloc-stage, expand-inline-cfg 之后)：
;; 那时 `.inline`/`.call` 已展开成真指令，被内联体提供的定义(如 deflate 的 best_len)
;; 全部可见，故对**所有**函数精确、无需按 `.context` 收窄作用域。
(define (check-no-undefined-gpr-virtuals fn param-syms)
  ;; 按“符号名”归一化，忽略 w/x 视图：AArch64 上 w 写清零 x 的高 32 位，故
  ;; `mov w.foo, …` 定义了完整的 x.foo；否则 w-定义/x-使用会被误判为无定义。
  (define defined (mutable-set))
  (define used (mutable-set))
  (fn-for-each-block fn
    (lambda (block)
      (for ([ins (in-pvector (basic-block-instructions block))]
            #:when (ast-ins? ins))
        (define ud (extract-use-def ins))
        (for ([d (in-list (use-def-flat-defs ud))])
          (define r (reg-ref->reg-id d))
          (when (and (reg-id-virtual? r) (eq? (reg-id-class r) 'gpr))
            (set-add! defined (reg-id-id r))))
        (for ([u (in-list (use-def-flat-uses ud))])
          (define r (reg-ref->reg-id u))
          (when (and (reg-id-virtual? r) (eq? (reg-id-class r) 'gpr))
            (set-add! used (reg-id-id r)))))))
  (define bad
    (for/list ([sym (in-set used)]
               #:unless (set-member? defined sym)
               #:unless (set-member? param-syms sym))
      sym))
  (unless (null? bad)
    (error 'check-undefined-virtuals
           (string-append
            "函数 '~a'：GPR 虚拟寄存器被使用却通篇无定义（无值来源）：~a\n"
            "  这些寄存器既未被写入、也不是声明形参。若它们是入参或上下文寄存器，\n"
            "  须在 `.context` 里 pin 到具体物理寄存器（如 AAPCS64 入参 x0-x7）或用\n"
            "  `in:` 声明，否则分配器会把它们静默放到任意寄存器、产出读错寄存器的代码。")
           (asm-function-name fn)
           (string-join
            (sort (map (lambda (sym) (format "x.~a" sym)) bad) string<?)
            ", "))))

(define (run-regalloc-pipeline fn [config default-pipeline-config]
                                #:abi-info-map [abi-info-map #f])
  ;; 0. 前端语义验证
  (validate-function fn)

  ;; 0.5 重物化·重载拆分 (预分配)：把跨调用存活的不变装载拆成使用点重载，
  ;; 消除溢出、让基址指针自然驻留 callee-saved。无候选时原样返回。
  (set! fn (split-remat-loads fn))

  (define abi (pipeline-config-abi config))
  (define spill-cfg (pipeline-config-spill config))
  (define max-iters (pipeline-config-max-iters config))
  (define debug-level (pipeline-config-debug-level config))
  (define debug? (> debug-level 0))

  (let loop ([current-fn fn] [iter 0])
    (when debug?
      (printf "=== 寄存器分配迭代 ~a ===\n" iter))

    (when (>= iter max-iters)
      (error 'run-regalloc-pipeline
             "溢出迭代次数超过限制 (~a)" max-iters))

    ;; 1. 活跃变量分析
    (define liveness (analyze-liveness current-fn))
    (when (>= debug-level 2)
      (printf "变量数: ~a\n" (fn-liveness-num-vars liveness)))

    ;; 2. 构建干涉图（3 张分离的图）
    (define mig (build-interference-graphs current-fn liveness #:abi abi))
    (when (>= debug-level 2)
      (printf "干涉图:\n")
      (when (mig-gpr mig)
        (printf "  GPR 顶点: ~a\n" (ugraph-vertex-count (class-ig-graph (mig-gpr mig)))))
      (when (mig-fpr mig)
        (printf "  FPR 顶点: ~a\n" (ugraph-vertex-count (class-ig-graph (mig-fpr mig)))))
      (when (mig-pred mig)
        (printf "  Predicate 顶点: ~a\n" (ugraph-vertex-count (class-ig-graph (mig-pred mig))))))

    ;; 3. 图着色分配（各类独立分配）
    ;; 使用 effective-abi（考虑 save! 声明）
    (define effective-abi (multi-class-ig-effective-abi mig))
    ;; 计算循环感知溢出代价
    (define cost-map (compute-spill-cost-map current-fn))
    ;; clobber-aware：跨调用值的实际 clobber 并集 (来自 abi-info-map)
    (define clobber-union-map
      (compute-clobber-union-map current-fn liveness effective-abi abi-info-map))
    (define multi-result
      (parameterize ([*spill-cost-map* cost-map]
                     [*clobber-union-map* clobber-union-map])
        (allocate-all-registers mig #:abi effective-abi)))
    (define alloc-result (merge-alloc-results multi-result))
    (define spilled (alloc-result-spilled alloc-result))
    (define current-fn/debug
      (attach-debug-reg-map current-fn alloc-result effective-abi iter))

    (when debug?
      (printf "溢出寄存器: ~a\n" (pvector-length spilled)))

    (cond
      ;; 有溢出
      [(> (pvector-length spilled) 0)
       (cond
         ;; 不允许溢出 - 返回错误
         [(not (spill-allowed? spill-cfg))
          (pipeline-result current-fn/debug liveness mig alloc-result multi-result
                           (pvector-empty) 0 iter
                           (list (format "分配失败：需要溢出 ~a 个寄存器，但溢出被禁止"
                                         (pvector-length spilled))))]
         ;; 允许溢出 - 重写并重新分配
         [else
          (define rewritten-fn (rewrite-function current-fn/debug alloc-result
                                                  #:abi effective-abi
                                                  #:abi-info-map abi-info-map))
          (loop rewritten-fn (add1 iter))])]

      ;; 无溢出 - 完成
      [else
       ;; 4. 重写虚拟寄存器为物理寄存器
       (define rewritten-fn (rewrite-function current-fn/debug alloc-result
                                               #:abi effective-abi
                                               #:abi-info-map abi-info-map))

       ;; 5. 处理 save!/load! 指令
       (define sl-context (analyze-save-load rewritten-fn alloc-result
                                              #:abi effective-abi))

       ;; 检查是否有 save!/load!
       (define has-save-load?
         (> (save-load-context-total-stack-size sl-context) 0))

       (define final-fn
         (if has-save-load?
             (expand-save-load rewritten-fn sl-context)
             rewritten-fn))

       (when (and debug? has-save-load?)
         (printf "save!/load! 栈空间: ~a 字节\n"
                 (save-load-context-total-stack-size sl-context))
         (when (> (save-load-context-sve-stack-slots sl-context) 0)
           (printf "save!/load! SVE 栈空间: ~a VL 单位\n"
                   (save-load-context-sve-stack-slots sl-context))))

       ;; 输出栈平衡警告 (到 stderr)
       (define sl-warnings (save-load-context-errors sl-context))
       (for ([w (in-list sl-warnings)])
         (eprintf "~a\n" w))

       (define spill-slots (compute-spill-slots spilled))
       (define save-load-size (save-load-context-total-stack-size sl-context))
       (define frame-size (+ (compute-frame-size spill-slots) save-load-size))

       ;; 收集错误
       (define all-errors (save-load-context-errors sl-context))

       (pipeline-result final-fn liveness mig alloc-result multi-result
                        spill-slots frame-size iter
                        all-errors)])))

;; ============================================================
;; 循环感知溢出代价计算
;; ============================================================

;; 计算每个寄存器变量的溢出代价
;; cost(v) = Σ (每个 use/def 点所在 block 的 10^loop_depth)
;; 返回 reg-om[reg-id -> number]
(define (compute-spill-cost-map fn)
  (define depths (compute-loop-depths fn))
  (define cost-map (make-hash))

  (for ([kv (in-intmap-pairs (asm-function-blocks fn))])
    (define bb-id-val (car kv))
    (define block (cdr kv))
    (define depth (get-loop-depth depths bb-id-val))
    (define weight (expt 10 depth))

    (for ([ins (in-pvector (basic-block-instructions block))])
      (when (ast-ins? ins)
        (define use-def (extract-use-def ins))
        ;; 为每个 def 和 use 的寄存器累加代价
        (for ([ref (in-list (append (use-def-flat-defs use-def)
                                    (use-def-flat-uses use-def)))])
          (define rid (reg-ref->reg-id ref))
          (when (reg-id-virtual? rid)
            (hash-set! cost-map rid
                       (+ (hash-ref cost-map rid 0) weight)))))))

  ;; 转换为 reg-om
  (for/fold ([m reg-om-empty])
            ([(rid cost) (in-hash cost-map)])
    (reg-om-set m rid cost)))

;; 从 ugraph 模块获取顶点数
(require racket/graph)
