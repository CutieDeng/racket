#!/usr/bin/env racket
#lang racket

;; ============================================================
;; cli/as.rkt - 完整汇编器 CLI
;; ============================================================
;;
;; 用法: racket cli/as.rkt [options] <input-file>
;;
;; 功能阶段:
;;   1. 解析 (parse)      - Lisp S-expr / GNU as → AST
;;   2. 验证 (validate)   - Layer1/2/3 语法检查
;;   3. CFG  (cfg)        - 控制流图构建
;;   4. 分配 (regalloc)   - 寄存器分配
;;   5. 生成 (emit)       - ARM64 汇编输出
;;
;; 示例:
;;   racket cli/as.rkt input.lisp                    # 完整编译
;;   racket cli/as.rkt -o output.s input.lisp        # 指定输出文件
;;   racket cli/as.rkt --stop-after=cfg input.lisp   # 只到 CFG 阶段
;;   racket cli/as.rkt --apple input.lisp            # Apple 汇编语法
;;   racket cli/as.rkt --dump=liveness input.lisp    # 调试: 输出活跃信息

(require "../parser/frontend.rkt"
         "../parser/ast.rkt"
         "../parser/comments.rkt"
         "../pipeline/sched-model.rkt"
         "../syntax/validator.rkt"
         "../syntax/spec.rkt"
         "../semantic/use-def.rkt"
         "../semantic/branch-info.rkt"
         "../semantic/control-flow.rkt"
         "../semantic/inline.rkt"
         "../semantic/apply-contexts.rkt"
         "../semantic/ipa-callconv.rkt"
         "../semantic/public-abi.rkt"
         "../semantic/save-verify.rkt"
         "../pipeline/pipeline.rkt"
         "../pipeline/schedule.rkt"
         "../pipeline/regalloc/abi-config.rkt"
         "../pipeline/regalloc/abi-infer.rkt"
         "../pipeline/analysis/perf-report.rkt"
         "../codegen/emit.rkt"
         racket/pvector
         racket/intmap
         racket/graph
         (only-in "../syntax/lookup.rkt"
                  encoding-info? encoding-info-encoding-id encoding-info-template)
         racket/cmdline
         racket/format
         racket/set)

;; ============================================================
;; 配置参数
;; ============================================================

;; 输出控制
(define output-file (make-parameter #f))
(define output-stdout (make-parameter #f))
(define public-abi-manifest-file (make-parameter #f))
(define public-c-header-file (make-parameter #f))

;; 阶段控制
(define stop-after (make-parameter 'emit))  ; 'parse | 'validate | 'cfg | 'regalloc | 'emit

;; 调试输出
(define dump-flags (make-parameter '()))  ; '(ast cfg liveness interference allocation)
(define verbose-level (make-parameter 0))  ; 0=quiet, 1=summary, 2=detail, 3=trace
(define emit-debug-lines (make-parameter #f)) ; 输出 .file/.loc 行号调试信息
(define emit-debug-reg-map (make-parameter #f)) ; 输出虚拟寄存器映射注释
(define scheduler-all? (make-parameter #f))     ; --sched：调度全部函数
(define scheduler-only (make-parameter (set)))  ; --sched-only：仅调度指定函数

;; 汇编语法
(define input-syntax (make-parameter 'sexp)) ; 'sexp | 'gnu | 'auto
(define asm-syntax (make-parameter 'gnu))  ; 'gnu | 'apple
(define emit-cfi (make-parameter #f))
(define skip-redundant-mov (make-parameter #f))  ; 默认保留所有指令
(define merge-colocated-labels (make-parameter #f))  ; 合并同位置标签

;; 寄存器分配
(define allow-spill (make-parameter #t))
(define max-regalloc-iters (make-parameter 10))
(define regalloc-debug (make-parameter 0))

;; IPA / ABI clone planning
(define ipa-callconv-candidate-abis (make-parameter '()))
(define ipa-callconv-min-savings (make-parameter 1))
(define ipa-callconv-report (make-parameter #f))

;; 格式化
(define format-mode (make-parameter 'text))  ; 'text | 'json | 'dot | 'sexp

;; 错误处理
(define continue-on-error (make-parameter #f))
(define show-hints (make-parameter #t))

;; 性能报告
(define perf-report (make-parameter #f))

;; 功能开关
(define skip-validation (make-parameter #f))
(define verify-save-load-flag (make-parameter #t))
(define check-outside-function (make-parameter #t))  ; 检查函数外指令
(define verify-label-refs-flag (make-parameter #t))  ; 检查标签引用
(define verify-symbol-names-flag (make-parameter #t)) ; 检查符号名合法性
(define pedantic-flag (make-parameter #f))           ; 严格检查（默认关闭）
(define sp-write-policy (make-parameter 'warn))      ; 'allow | 'warn | 'error

;; ============================================================
;; 阶段定义
;; ============================================================

(define stages '(parse validate cfg regalloc emit))

(define (stage->index stage)
  (define idx (index-of stages stage))
  (or idx (error 'stage->index "未知阶段: ~a" stage)))

(define (should-run-stage? stage)
  (<= (stage->index stage) (stage->index (stop-after))))

(define (should-dump? what)
  (member what (dump-flags)))

(define (parse-comma-symbols text)
  (filter values
          (for/list ([part (in-list (string-split text ","))])
            (define trimmed (string-trim part))
            (and (not (string=? trimmed ""))
                 (string->symbol trimmed)))))

;; ============================================================
;; 诊断格式化
;; ============================================================

(define type-names
  #hash((gpr-64       . "x寄存器")
        (gpr-32       . "w寄存器")
        (gpr-64-sp    . "x寄存器/SP")
        (gpr-32-sp    . "w寄存器/WSP")
        (fpr-64       . "d寄存器")
        (fpr-32       . "s寄存器")
        (fpr-16       . "h寄存器")
        (fpr-128      . "q寄存器")
        (fpr-8        . "b寄存器")
        (sve-z        . "z寄存器")
        (sve-p        . "p谓词")
        (imm          . "立即数")
        (immediate    . "立即数")
        (memory       . "内存")
        (label        . "标签")
        (shift        . "移位")
        (extend       . "扩展")
        (reglist      . "寄存器列表")
        (condition    . "条件码")))

(define (type-name type)
  (hash-ref type-names type (symbol->string type)))

(define (format-validation-error item)
  (define ins (parse-result-instruction item))
  (define loc (parse-result-srcloc item))
  (define validation (parse-result-validation item))
  (define err (parse-result-parse-error item))

  (cond
    [(and err (eq? (parse-error-kind err) 'read))
     (format "~a: 读取错误: ~a"
             (format-srcloc loc)
             (parse-error-message err))]

    ;; 语法错误 (解析时抛出异常)
    [(and err (eq? (parse-error-kind err) 'syntax))
     (format "~a: 语法错误: ~a"
             (format-srcloc loc)
             (parse-error-message err))]

    [(and ins validation)
     (define mnem (validation-result-mnemonic validation))
     (define layer (validation-result-error-layer validation))
     (define msg (validation-result-error-message validation))
     (define hints (validation-result-hints validation))

     (define base-msg
       (format "~a: ~a: ~a"
               (format-srcloc loc)
               (ast->string ins)
               (or msg (format "~a 层验证失败" layer))))

     (if (and (show-hints) (pair? hints))
         (string-append base-msg "\n"
                        (string-join
                         (for/list ([h (in-list hints)])
                           (format "  提示: ~a" (format-hint h)))
                         "\n"))
         base-msg)]

    [else
     (format "~a: 未知错误" (format-srcloc loc))]))

;; 格式化标签引用错误
(define (format-label-ref-error err)
  (define label (label-ref-error-label err))
  (define ins (label-ref-error-instruction err))
  (define loc (label-ref-error-srcloc err))
  (define fn-name (label-ref-error-function-name err))
  (define defined (label-ref-error-defined-labels err))

  (define base-msg
    (format "~a: ~a: 未定义的标签 '~a'"
            (format-srcloc loc)
            (ast->string ins)
            label))

  (if (and (show-hints) (pair? defined))
      (string-append base-msg "\n"
                     (format "  提示: 函数 ~a 中已定义的标签: ~a"
                             fn-name
                             (string-join (map symbol->string defined) ", ")))
      base-msg))

;; 格式化符号名错误
(define (format-symbol-name-error err)
  (define sym (symbol-name-error-symbol err))
  (define kind (symbol-name-error-kind err))
  (define fn-name (symbol-name-error-function-name err))
  (define reason (symbol-name-error-reason err))

  (define kind-str (case kind [(function) "函数"] [(label) "标签"]))
  (define sanitized (sanitize-symbol sym))

  (define base-msg
    (format "~a '~a': 符号名不合法" kind-str sym))

  (if (show-hints)
      (string-append base-msg "\n"
                     (format "  提示: ~a" reason) "\n"
                     (format "  建议: 改为 '~a'" sanitized))
      base-msg))

;; 格式化线性 fallthrough 警告
(define (format-linear-fallthrough-warning w)
  (define fn-name (linear-fallthrough-warning-function-name w))
  (define count (linear-fallthrough-warning-instruction-count w))
  (define last-ins (linear-fallthrough-warning-last-instruction w))
  (define loc (linear-fallthrough-warning-srcloc w))

  (define loc-str (if loc (format-srcloc loc) "<unknown>"))
  (define ins-str (if last-ins (ast->string last-ins) "<none>"))

  (format "~a: ~a: [pedantic] 函数 '~a' 可能 fall-through (~a 条指令，末尾无终止指令)"
          loc-str ins-str fn-name count))

;; 格式化源码层 SP 写入诊断
(define (format-sp-write-error err)
  (define fn-name (sp-write-error-function-name err))
  (define ins (sp-write-error-instruction err))
  (define loc (sp-write-error-srcloc err))
  (define reason (sp-write-error-reason err))

  (define loc-str (if loc (format-srcloc loc) "<unknown>"))
  (format "~a: ~a: 函数 '~a' 直接写入 sp (~a)。请使用 .asmp.save/.asmp.restore 等栈管理指令"
          loc-str
          (ast->string ins)
          fn-name
          reason))

;; ============================================================
;; 阶段 1: 解析
;; ============================================================

(struct parse-stage-result
  (items          ; (listof ast-node) - 成功解析的指令/directive
   errors         ; pvector of string - 错误消息
   raw-results)   ; parse-results - 原始结果
  #:transparent)

(define (run-parse-stage input-file)
  (define syntax-mode (resolve-input-syntax input-file))
  (when (>= (verbose-level) 1)
    (eprintf "阶段 1: 解析 ~a (~a 输入)\n" input-file syntax-mode))

  (unless (file-exists? input-file)
    (error 'as "文件不存在: ~a" input-file))

  (define results
    (parse-file input-file
                #:validate? (not (skip-validation))
                #:syntax syntax-mode))

  (define items
    (for/list ([r (in-list (parse-results-items results))]
               #:when (parse-result-instruction r))
      (parse-result-instruction r)))

  (define validation-errors
    (for/fold ([errs (pvector-empty)])
              ([r (in-list (parse-results-items results))]
               #:when (not (parse-result-ok? r)))
      (pvector-cons-right errs (format-validation-error r))))

  ;; 检查函数外指令
  (define outside-function-errors
    (if (check-outside-function)
        (check-instructions-outside-function items input-file)
        (pvector-empty)))

  (define errors (pvector-append validation-errors outside-function-errors))

  (when (should-dump? 'ast)
    (dump-ast items))

  (when (>= (verbose-level) 1)
    (eprintf "  解析: ~a 条指令, ~a 个错误\n"
             (length items) (pvector-length errors)))

  (parse-stage-result items errors results))

(define (run-parse-stage/files input-files)
  (cond
    [(null? input-files)
     (parse-stage-result '()
                         (pvector-cons-right (pvector-empty) "未提供输入文件")
                         '())]
    [(null? (cdr input-files))
     (run-parse-stage (car input-files))]
    [else
     (define results
       (for/list ([input-file (in-list input-files)])
         (run-parse-stage input-file)))
     (parse-stage-result
      (apply append (map parse-stage-result-items results))
      (for/fold ([errs (pvector-empty)])
                ([r (in-list results)])
        (pvector-append errs (parse-stage-result-errors r)))
      results)]))

;; 检查函数外的指令
;; 返回 pvector of 错误消息
(define (check-instructions-outside-function items source)
  (define errors (box (pvector-empty)))
  (define in-function? #f)

  (for ([item (in-list items)])
    (cond
      ;; 函数开始
      [(and (ast-directive? item)
            (eq? (ast-directive-kind item) 'function))
       (set! in-function? #t)]
      ;; 函数结束
      [(and (ast-directive? item)
            (eq? (ast-directive-kind item) 'end-function))
       (set! in-function? #f)]
      ;; 非函数内的指令
      [(and (ast-ins? item) (not in-function?))
       (define loc (ast-srcloc item))
       (define loc-str (format-srcloc loc))
       (set-box! errors
                 (pvector-cons-right
                  (unbox errors)
                  (format "~a: ~a: 指令在函数定义外"
                          loc-str (ast->string item))))]))

  (unbox errors))

(define (dump-ast items)
  (displayln ";; === AST Dump ===")
  (for ([item (in-list items)]
        [i (in-naturals)])
    (printf ";; [~a] ~a\n" i (ast->string item))
    (when (>= (verbose-level) 2)
      (printf ";;     ~a\n" item)))
  (displayln ";; === End AST ===\n"))

;; ============================================================
;; 阶段 2: CFG 构建
;; ============================================================

(struct cfg-stage-result
  (cfg            ; control-flow-graph
   functions      ; (listof asm-function)
   errors)        ; pvector of string
  #:transparent)

(define (run-cfg-stage items input-file)
  (when (>= (verbose-level) 1)
    (eprintf "阶段 2: 构建 CFG\n"))

  (define cfg (build-cfg items input-file))
  (define fn-count (cfg-function-count cfg))

  (define functions
    (for/list ([i (in-range fn-count)])
      (cfg-get-function cfg i)))

  (when (should-dump? 'cfg)
    (dump-cfg-info cfg))

  ;; 可选: 验证 save!/load!
  (define sv-errors
    (if (verify-save-load-flag)
        (for/fold ([errs (pvector-empty)])
                  ([fn (in-list functions)])
          (define info (verify-save-load fn))
          (for/fold ([e errs])
                    ([err (in-list (save-load-errors info))])
            (pvector-cons-right e err)))
        (pvector-empty)))

  ;; 可选: 验证标签引用
  (define lr-errors
    (if (verify-label-refs-flag)
        (for/fold ([errs (pvector-empty)])
                  ([fn (in-list functions)])
          (pvector-append errs (verify-label-references fn cfg)))
        (pvector-empty)))

  ;; 可选: 验证符号名合法性
  (define sn-errors
    (if (verify-symbol-names-flag)
        (for/fold ([errs (pvector-empty)])
                  ([fn (in-list functions)])
          (pvector-append errs (verify-symbol-names fn)))
        (pvector-empty)))

  ;; 默认警告源码层直接写 sp；严格模式下作为 CFG 错误。
  (define sp-write-findings
    (case (sp-write-policy)
      [(allow) (pvector-empty)]
      [else
       (for/fold ([errs (pvector-empty)])
                 ([fn (in-list functions)])
         (pvector-append errs (verify-sp-write-discipline fn)))]))

  ;; 格式化标签引用错误
  (define label-ref-error-msgs
    (for/fold ([msgs (pvector-empty)])
              ([err (in-pvector lr-errors)])
      (pvector-cons-right msgs (format-label-ref-error err))))

  ;; 格式化符号名错误
  (define symbol-name-error-msgs
    (for/fold ([msgs (pvector-empty)])
              ([err (in-pvector sn-errors)])
      (pvector-cons-right msgs (format-symbol-name-error err))))

  ;; 格式化 SP 写入诊断
  (define sp-write-msgs
    (for/fold ([msgs (pvector-empty)])
              ([err (in-pvector sp-write-findings)])
      (pvector-cons-right msgs (format-sp-write-error err))))

  ;; Public ABI profile checks
  (define public-abi-msgs
    (for/fold ([msgs (pvector-empty)])
              ([err (in-list (check-public-abi-profiles cfg))])
      (pvector-cons-right msgs (format-public-abi-error err))))

  (when (eq? (sp-write-policy) 'warn)
    (for ([msg (in-pvector sp-write-msgs)])
      (eprintf "警告: ~a\n" msg)))

  ;; Pedantic: 检查线性 fallthrough
  (define pedantic-warnings
    (if (pedantic-flag)
        (for/fold ([warns (pvector-empty)])
                  ([fn (in-list functions)])
          (define w (check-linear-fallthrough fn))
          (if w
              (pvector-cons-right warns (format-linear-fallthrough-warning w))
              warns))
        (pvector-empty)))

  (define errors (pvector-append sv-errors
                                 (pvector-append label-ref-error-msgs
                                                 (pvector-append symbol-name-error-msgs
                                                                 (pvector-append (if (eq? (sp-write-policy) 'error)
                                                                                     sp-write-msgs
                                                                                     (pvector-empty))
                                                                                 (pvector-append public-abi-msgs
                                                                                                 pedantic-warnings))))))

  (when (>= (verbose-level) 1)
    (eprintf "  CFG: ~a 个函数\n" fn-count))

  (cfg-stage-result cfg functions errors))

(define (dump-cfg-info cfg)
  (case (format-mode)
    [(dot)
     (displayln (format-cfg-dot cfg))]
    [else
     (displayln ";; === CFG Dump ===")
     (displayln (format-cfg cfg))
     (displayln ";; === End CFG ===\n")]))

;; ============================================================
;; 阶段 3: 寄存器分配
;; ============================================================

(struct regalloc-stage-result
  (results        ; (listof pipeline-result)
   errors         ; pvector of string
   functions      ; (listof asm-function) — inline 展开后的函数
   abi-info-map   ; hash[fn-name -> function-abi-info]
   module-items)  ; (listof ast-directive) - 函数外模块级指令/数据
  #:transparent)

;; 解析函数的 ABI 名称 → abi-config
;; 优先使用函数属性 (abi <name>)，其次 --default-abi 参数
;; 当 --default-abi 为 auto 时，根据 abi-info-map 自动推断：
;;   无调用 → leaf，有调用 → aapcs64
(define (resolve-function-abi fn [abi-info-map #f])
  (define fn-name (asm-function-name fn))
  (define explicit-abi (fn-get-info fn 'abi #f))
  (define abi-name
    (cond
      ;; 函数显式声明了 ABI → 直接使用
      [explicit-abi explicit-abi]
      ;; --default-abi auto → 自动推断
      [(eq? (default-abi-name) 'auto)
       (if (function-is-leaf? fn)
           'leaf      ; 无 bl/blr → leaf ABI
           'aapcs64)] ; 有调用 → aapcs64
      ;; 其他 --default-abi 值
      [else (default-abi-name)]))
  (cond
    [(not abi-name) #f]
    [else
     (load-abi-config)
     (define abi (get-abi-by-name abi-name))
     (unless abi
       (error 'regalloc
              "函数 '~a' 的 ABI '~a' 未在配置文件中定义" fn-name abi-name))
     abi]))

(define (inline-only-function? fn)
  (fn-get-info fn 'inline-only #f))

(define (function-inline-targets fn)
  (for*/fold ([targets (set)])
             ([kv (in-intmap-pairs (asm-function-blocks fn))]
              [ins (in-pvector (basic-block-instructions (cdr kv)))])
    (match ins
      [(ast-directive 'inline target _ _)
       (if (symbol? target) (set-add targets target) targets)]
      [_ targets])))

(define (cfg-inline-targets cfg)
  (for/fold ([targets (set)])
            ([i (in-range (cfg-function-count cfg))])
    (define fn (cfg-get-function cfg i))
    (if fn
        (set-union targets (function-inline-targets fn))
        targets)))

(define (function-bl-targets fn)
  (for*/fold ([targets (set)])
             ([kv (in-intmap-pairs (asm-function-blocks fn))]
              [ins (in-pvector (basic-block-instructions (cdr kv)))])
    (match ins
      [(ast-ins 'bl #f (list (ast-label target #f _)) _)
       (if (symbol? target) (set-add targets target) targets)]
      [_ targets])))

(define (cfg-bl-targets cfg)
  (for/fold ([targets (set)])
            ([i (in-range (cfg-function-count cfg))])
    (define fn (cfg-get-function cfg i))
    (if fn
        (set-union targets (function-bl-targets fn))
        targets)))

(define (omit-inline-selected-function? fn inline-targets bl-targets)
  (define name (asm-function-name fn))
  (and (set-member? inline-targets name)
       (not (fn-get-info fn 'export #f))
       (not (set-member? bl-targets name))))

(define (format-ipa-callconv-report-line report)
  (format "~a -> ~a: ~a cost ~a -> ~a cost ~a (save ~a move~a)"
          (callconv-selection-report-caller report)
          (callconv-selection-report-callee report)
          (callconv-selection-report-baseline-abi report)
          (callconv-selection-report-baseline-cost report)
          (callconv-selection-report-selected-abi report)
          (callconv-selection-report-selected-cost report)
          (callconv-selection-report-savings report)
          (if (= (callconv-selection-report-savings report) 1) "" "s")))

(define (run-ipa-callconv-planner cfg)
  (define candidates (ipa-callconv-candidate-abis))
  (define hinted-selections (collect-callconv-hint-selections cfg))
  (define hinted-edges
    (for/set ([selection (in-list hinted-selections)])
      (cons (callconv-selection-caller selection)
            (callconv-selection-callee selection))))
  (define-values (planned-selections reports)
    (if (null? candidates)
        (values '() '())
        (plan-callconv-selections
         cfg
         #:candidate-abis candidates
         #:min-move-savings (ipa-callconv-min-savings))))
  (define planned-selections*
    (filter (lambda (selection)
              (not (set-member?
                    hinted-edges
                    (cons (callconv-selection-caller selection)
                          (callconv-selection-callee selection)))))
            planned-selections))
  (define reports*
    (filter (lambda (report)
              (not (set-member?
                    hinted-edges
                    (cons (callconv-selection-report-caller report)
                          (callconv-selection-report-callee report)))))
            reports))
  (define selections (append hinted-selections planned-selections*))
  (if (null? selections)
      (values cfg '() '())
      (let ()
        (define-values (cfg* summaries)
          (apply-callconv-selections cfg selections))
        (when (or (ipa-callconv-report) (>= (verbose-level) 1))
          (when (pair? hinted-selections)
            (eprintf "  IPA callconv: ~a source hint~a\n"
                     (length hinted-selections)
                     (if (= (length hinted-selections) 1) "" "s")))
          (cond
            [(and (null? hinted-selections)
                  (null? reports*)
                  (null? planned-selections*))
             (eprintf "  IPA callconv: no profitable managed .call clones\n")]
            [else
             (when (pair? reports*)
               (eprintf "  IPA callconv: ~a planned clone selection~a\n"
                        (length reports*)
                        (if (= (length reports*) 1) "" "s")))
             (for ([report (in-list reports*)])
               (eprintf "    ~a\n" (format-ipa-callconv-report-line report)))]))
        (values cfg* selections summaries))))

;; 操作级列表调度：在 .call 降级前，对 cfg 中被"允许"的函数做压力感知列表调度。
;; **默认关闭**（调度器对含复杂控制流/内存的代码仍有依赖建模盲点，见
;; docs/operation-scheduler-spec.md §10 已知问题）。opt-in：
;;   --sched         / ASMP_SCHED=1            → 调度所有函数
;;   --sched-only=…  / ASMP_SCHED_ONLY=fn1,fn2 → 只调度指定函数
;;                                               （推荐：仅经 KAT 验证的内核）
(define (schedule-cfg cfg)
  (define all? (or (scheduler-all?) (and (getenv "ASMP_SCHED") #t)))
  (define only
    (set-union
     (scheduler-only)
     (let ([e (getenv "ASMP_SCHED_ONLY")])
       (if e (list->set (map string->symbol (string-split e ","))) (set)))))
  (define (scheduled? name) (or all? (set-member? only name)))
  (if (or (not (*enable-scheduler*)) (not (or all? (positive? (set-count only)))))
      (values cfg (hash))
      (let* ([items (cfg->items cfg)]
             [attrs (collect-function-attrs items)]
             [callee-params
              (for/hash ([(name a) (in-hash attrs)]
                         #:when (and (hash? a) (hash-ref a 'function-params #f)))
                (values name (hash-ref a 'function-params)))]
             [pure-callees (compute-pure-callees (control-flow-graph-functions cfg))]
             [crit-by-name (make-hash)]
             [new-functions
              (for/fold ([m (control-flow-graph-functions cfg)])
                        ([kv (in-intmap-pairs (control-flow-graph-functions cfg))])
                (define fn (cdr kv))
                (define name (asm-function-name fn))
                (cond
                  [(scheduled? name)
                   (define sfn (schedule-function fn callee-params
                                                  #:pure-callees pure-callees))
                   ;; 关键路径临界度 (供 critical-path-aware 溢出)
                   (hash-set! crit-by-name name
                              (compute-criticality-map sfn callee-params pure-callees))
                   (intmap-set m (car kv) sfn)]
                  [else (intmap-set m (car kv) fn)]))])
        (values (struct-copy control-flow-graph cfg [functions new-functions])
                crit-by-name))))

(define (run-regalloc-stage cfg functions)
  (when (>= (verbose-level) 1)
    (eprintf "阶段 3: 寄存器分配\n"))

  ;; 在 CFG 构建后展开 inline 指令，确保 CFG 阶段可见原始 inline
  (define-values (cfg/ipa _ipa-selections _ipa-summaries)
    (run-ipa-callconv-planner cfg))
  ;; 操作级列表调度 (在 .call 降级前，把域乘等 .call 作节点重排以最大化 ILP)
  ;; 并算出各函数的关键路径临界度 (供 critical-path-aware 溢出)
  (define-values (cfg/sched crit-by-name) (schedule-cfg cfg/ipa))
  (define inline-targets (cfg-inline-targets cfg/sched))
  (define cfg* (expand-inline-cfg cfg/sched))
  (define bl-targets (cfg-bl-targets cfg*))
  (define functions*
    (for/list ([i (in-range (cfg-function-count cfg*))])
      (cfg-get-function cfg* i)))
  (define output-functions*
    (filter (lambda (fn)
              (and (not (inline-only-function? fn))
                   (not (omit-inline-selected-function? fn inline-targets bl-targets))))
            functions*))

  ;; 健全性关卡（通用）：拒绝“被用却通篇无定义、又非声明形参”的 GPR 虚拟寄存器
  ;; （无值来源 → 分配器静默错分配 → 运行时段错误）。在此点执行的两个理由：
  ;; ① post-inline —— `.inline`/`.call` 已展开成真指令，被内联体提供的定义此刻全部
  ;;    可见（如 deflate 的 best_len），故对所有函数精确、无需按 .context 收窄作用域；
  ;; ② 声明形参 —— 用 cfg 阶段捕获的 `functions`（function-params 未被 callconv 消费）
  ;;    建 {函数名→形参符号} 侧表，post-inline 函数按名查表排除(如 c-public out: 形参)。
  (define param-syms-by-name
    (for/hash ([fn (in-list functions)])
      (values (asm-function-name fn) (declared-param-reg-symbols fn))))
  (for ([fn (in-list output-functions*)])
    (check-no-undefined-gpr-virtuals
     fn (hash-ref param-syms-by-name (asm-function-name fn) (set))))

  ;; 预加载 ABI 配置
  (load-abi-config)

  ;; 推断所有函数的 ABI（用于假溢出分析和 ABI 验证）
  (define abi-info-map (infer-all-abis cfg*))

  ;; 检查 ABI 推断/验证错误
  (define abi-errors
    (for/fold ([errs '()])
              ([(fn-name info) (in-hash abi-info-map)])
      (append errs (function-abi-info-errors info))))

  (when (and (pair? abi-errors) (>= (verbose-level) 1))
    (for ([err (in-list abi-errors)])
      (eprintf "警告: ~a\n" err)))

  (define results
    (for/list ([fn (in-list output-functions*)])
      (define abi (or (resolve-function-abi fn abi-info-map) arm64-abi))
      (define config
        (make-pipeline-config
         #:abi abi
         #:spill (if (allow-spill)
                     default-spill-config
                     (spill-config #f 0 'none))
         #:max-iters (max-regalloc-iters)
         #:debug-level (regalloc-debug)))
      ;; 运行 pipeline 并传入 abi-info-map 用于假溢出分析；
      ;; critical-path-aware 溢出用本函数的临界度 (调度阶段算出)
      (parameterize ([*criticality-map* (hash-ref crit-by-name (asm-function-name fn) #f)])
        (run-pipeline-with-abi-info fn config abi-info-map))))

  (define errors
    (for/fold ([errs (pvector-empty)])
              ([r (in-list results)])
      (for/fold ([e errs])
                ([err (in-list (pipeline-result-errors r))])
        (pvector-cons-right e err))))

  (when (should-dump? 'liveness)
    (dump-liveness-info results))

  (when (should-dump? 'interference)
    (dump-interference-info results))

  (when (should-dump? 'allocation)
    (dump-allocation-info results))

  (when (>= (verbose-level) 1)
    (for ([r (in-list results)]
          [i (in-naturals)])
      (define fn (pipeline-result-function r))
      (eprintf "  函数 ~a: ~a 次迭代, 栈帧 ~a 字节\n"
               (asm-function-name fn)
               (pipeline-result-iterations r)
               (pipeline-result-frame-size r))))

  (regalloc-stage-result results errors output-functions* abi-info-map
                         (cfg-get-info cfg* 'module-items '())))

(define (dump-liveness-info results)
  (displayln ";; === Liveness Dump ===")
  (for ([r (in-list results)])
    (define liveness (pipeline-result-liveness r))
    (define fn (pipeline-result-function r))
    (printf ";; Function: ~a\n" (asm-function-name fn))
    (printf ";;   变量数: ~a\n" (fn-liveness-num-vars liveness)))
  (displayln ";; === End Liveness ===\n"))

(define (dump-interference-info results)
  (displayln ";; === Interference Graph Dump ===")
  (for ([r (in-list results)])
    (define mig (pipeline-result-interference r))
    (define fn (pipeline-result-function r))
    (printf ";; Function: ~a\n" (asm-function-name fn))
    (when (mig-gpr mig)
      (printf ";;   GPR 顶点: ~a\n"
              (graph-vertex-count (class-ig-graph (mig-gpr mig)))))
    (when (mig-fpr mig)
      (printf ";;   FPR 顶点: ~a\n"
              (graph-vertex-count (class-ig-graph (mig-fpr mig)))))
    (when (mig-pred mig)
      (printf ";;   Predicate 顶点: ~a\n"
              (graph-vertex-count (class-ig-graph (mig-pred mig))))))
  (displayln ";; === End Interference ===\n"))

(define (dump-allocation-info results)
  (displayln ";; === Allocation Dump ===")
  (for ([r (in-list results)])
    (define alloc (pipeline-result-allocation r))
    (define fn (pipeline-result-function r))
    (printf ";; Function: ~a\n" (asm-function-name fn))
    (printf ";;   分配数: ~a\n"
            (reg-om-count (alloc-result-assignment alloc)))
    (printf ";;   合并数: ~a\n"
            (reg-om-count (alloc-result-coalesced alloc)))
    (printf ";;   溢出数: ~a\n"
            (pvector-length (alloc-result-spilled alloc)))
    ;; 详细分配
    (when (>= (verbose-level) 2)
      (printf ";;   分配详情:\n")
      (for ([kv (in-reg-om (alloc-result-assignment alloc))])
        (printf ";;     ~a → ~a\n" (car kv) (cdr kv)))))
  (displayln ";; === End Allocation ===\n"))

(define (debug-reg-id->string r)
  (define prefix
    (case (reg-id-class r)
      [(gpr) (if (<= (reg-id-width r) 32) "w" "x")]
      [(fpr) (case (reg-id-width r)
               [(8) "b"]
               [(16) "h"]
               [(32) "s"]
               [(64) "d"]
               [else "q"])]
      [(predicate) "p"]
      [else "?"]))
  (if (reg-id-virtual? r)
      (format "~a.~a" prefix (reg-id-id r))
      (format "~a~a" prefix (reg-id-id r))))

(define (debug-internal-reg-id? r)
  (and (reg-id-virtual? r)
       (symbol? (reg-id-id r))
       (regexp-match? #rx"^__asmp_" (symbol->string (reg-id-id r)))))

(define (debug-phys-reg->string reg id)
  (case (reg-id-class reg)
    [(gpr) (format "~a~a" (if (<= (reg-id-width reg) 32) "w" "x") id)]
    [(fpr) (format "~a~a"
                   (case (reg-id-width reg)
                     [(8) "b"]
                     [(16) "h"]
                     [(32) "s"]
                     [(64) "d"]
                     [else "q"])
                   id)]
    [(predicate) (format "p~a" id)]
    [else (format "?~a" id)]))

(define (debug-allocation-target->string abi reg color)
  (define class (reg-id-class reg))
  (define phys (abi-color->reg abi class color))
  (cond
    [phys (debug-phys-reg->string reg phys)]
    [(exact-nonnegative-integer? color) (format "color#~a" color)]
    [else (~a color)]))

(define (debug-view-names record reg)
  (for/list ([view (in-list (hash-ref record 'views '()))]
             #:when (equal? (hash-ref view 'reg #f) reg))
    (hash-ref view 'name)))

(define (debug-display-names record reg)
  (if (debug-internal-reg-id? reg)
      '()
      (let ([names (debug-view-names record reg)])
        (if (null? names)
            (list (debug-reg-id->string reg))
            names))))

(define (debug-virtual-assignment-lines record alloc abi)
  (append*
   (for/list ([kv (in-reg-om (alloc-result-assignment alloc))]
              #:when (and (reg-id-virtual? (car kv))
                          (not (debug-internal-reg-id? (car kv)))))
     (define reg (car kv))
     (define color (cdr kv))
     (for/list ([name (in-list (debug-display-names record reg))])
       (format "~a -> ~a"
               name
               (debug-allocation-target->string abi reg color))))))

(define (debug-coalesced-lines record alloc)
  (append*
   (for/list ([kv (in-reg-om (alloc-result-coalesced alloc))]
              #:when (and (reg-id-virtual? (car kv))
                          (not (debug-internal-reg-id? (car kv)))
                          (not (debug-internal-reg-id? (cdr kv)))))
     (for/list ([name (in-list (debug-display-names record (car kv)))])
       (format "~a -> ~a"
               name
               (debug-reg-id->string (cdr kv)))))))

(define (debug-spilled-lines record alloc)
  (append*
   (for/list ([reg (in-pvector (alloc-result-spilled alloc))]
              #:when (and (reg-id-virtual? reg)
                          (not (debug-internal-reg-id? reg))))
     (debug-display-names record reg))))

(define (debug-allocation-record-empty? record)
  (define alloc (hash-ref record 'allocation #f))
  (or (not alloc)
      (and (reg-om-empty? (alloc-result-assignment alloc))
           (reg-om-empty? (alloc-result-coalesced alloc))
           (= (pvector-length (alloc-result-spilled alloc)) 0))))

(define (debug-reg-map-records result)
  (define fn (pipeline-result-function result))
  (define stored-records (fn-get-info fn 'debug-reg-maps #f))
  (define records
    (if (and stored-records (pair? stored-records))
        stored-records
        (list (hash 'iteration (pipeline-result-iterations result)
                    'allocation (pipeline-result-allocation result)
                    'effective-abi (multi-class-ig-effective-abi
                                    (pipeline-result-interference result))))))
  (define non-empty-records
    (filter (lambda (record) (not (debug-allocation-record-empty? record)))
            records))
  (if (null? non-empty-records) records non-empty-records))

(define (comment-block comment-prefix title lines)
  (define prefix (format "~a " comment-prefix))
  (string-join
   (cons (format "~a~a" prefix title)
         (if (null? lines)
             (list (format "~a  (none)" prefix))
             (for/list ([line (in-list lines)])
               (format "~a  ~a" prefix line))))
   "\n"))

(define (format-debug-reg-map/result result comment-prefix)
  (define fn (pipeline-result-function result))
  (define records (debug-reg-map-records result))
  (define (format-record record)
    (define alloc (hash-ref record 'allocation))
    (define abi (hash-ref record 'effective-abi))
    (define iter (hash-ref record 'iteration #f))
    (define allocated (debug-virtual-assignment-lines record alloc abi))
    (define coalesced (debug-coalesced-lines record alloc))
    (define spilled (debug-spilled-lines record alloc))
    (string-join
     (append
      (if iter
          (list (format "~a iteration ~a:" comment-prefix iter))
          '())
      (list
       (comment-block comment-prefix "allocated:" allocated)
       (comment-block comment-prefix "coalesced:" coalesced)
       (comment-block comment-prefix "spilled:" spilled)))
     "\n"))
  (string-join
   (append
    (list (format "~a asmp debug reg map: ~a"
                  comment-prefix
                  (asm-function-name fn)))
    (for/list ([record (in-list records)])
      (format-record record))
    (list (format "~a end asmp debug reg map" comment-prefix)))
   "\n"))

;; ============================================================
;; 阶段 4: 代码生成
;; ============================================================

(struct emit-stage-result
  (assembly       ; string - 汇编输出
   errors)        ; (listof string)
  #:transparent)

(define (run-emit-stage results [module-items '()])
  (when (>= (verbose-level) 1)
    (eprintf "阶段 4: 代码生成\n"))

  (define base-config
    (case (asm-syntax)
      [(apple) apple-emit-config]
      [else default-emit-config]))

  (define config
    (struct-copy emit-config base-config
                 [emit-debug-info? (emit-debug-lines)]
                 [emit-cfi? (emit-cfi)]
                 [skip-redundant-mov? (skip-redundant-mov)]
                 [merge-colocated-labels? (merge-colocated-labels)]))
  (define comment-prefix
    (case (asm-syntax)
      [(gnu) "//"]
      [else (string (emit-config-comment-char config))]))

  (define assembly
    (parameterize ([current-emit-config config])
      (call-with-fresh-debug-file-state
       (lambda ()
      (define function-sections
        (for/list ([r (in-list results)])
          (define function-asm (emit-function/result r))
          (if (emit-debug-reg-map)
              (string-append (format-debug-reg-map/result r comment-prefix)
                             "\n"
                             function-asm)
              function-asm)))
      (define module-section
        (format-module-items module-items))
      ;; string-join 只在元素之间放分隔符, 末元素 (.subsections_via_symbols 等)
      ;; 无尾随换行 -> 拼进 C 的 #if/#endif 时会粘成 ".subsections_via_symbols#endif"
      ;; 令汇编器/编译器报 "unterminated conditional directive"。补一个尾随换行,
      ;; 使输出始终以 \n 结束 (POSIX 文本文件惯例)。
      (string-append
       (string-join
        (filter (lambda (section) (not (string=? section "")))
                (append
                 (list (format "~a Generated by asmp\n~a Syntax: ~a\n\n.text\n"
                               comment-prefix
                               comment-prefix
                               (asm-syntax))
                       (emit-debug-text-begin))
                 function-sections
                 (list (emit-debug-text-end)
                       module-section
                       (emit-debug-dwarf-footer)
                       (if (eq? (asm-syntax) 'apple)
                           ".subsections_via_symbols"
                           ""))))
        "\n\n")
       "\n")))))

  (when (>= (verbose-level) 1)
    (eprintf "  生成: ~a 字节汇编\n" (string-length assembly)))

  (emit-stage-result assembly '()))

(define (format-module-items module-items)
  (string-join
   (filter (lambda (s) (not (string=? s "")))
           (for/list ([item (in-list module-items)])
             (emit-directive item)))
   "\n"))

;; ============================================================
;; 输出
;; ============================================================

(define (write-output content)
  (cond
    [(output-stdout)
     (display content)]
    [(output-file)
     (call-with-output-file (output-file)
       (lambda (out) (display content out))
       #:exists 'truncate/replace)
     (when (>= (verbose-level) 1)
       (eprintf "输出写入: ~a\n" (output-file)))]
    [else
     (display content)]))

(define (format-errors errors stage)
  (if (pvector-empty? errors)
      ""
      (string-append
       (format "\n=== ~a 阶段错误 ===\n" stage)
       (string-join (pvector->list errors) "\n")
       "\n")))

;; ============================================================
;; 主流程
;; ============================================================

(define (run-compiler/files input-files)
  (define all-errors (pvector-empty))

  ;; 阶段 1: 解析
  (define parse-result (run-parse-stage/files input-files))
  (set! all-errors (pvector-append all-errors (parse-stage-result-errors parse-result)))

  (when (and (not (pvector-empty? (parse-stage-result-errors parse-result)))
             (not (continue-on-error)))
    (display (format-errors (parse-stage-result-errors parse-result) "解析"))
    (exit 1))

  ;; 阶段 1.5: 应用 .context —— 命名上下文虚拟寄存器 → 物理寄存器替换。
  ;; 在 CFG/regalloc 之前, 剥离 .context 声明并对 import 上下文的函数完成替换。
  (define-values (context-items context-error-list)
    (apply-contexts (parse-stage-result-items parse-result)))
  (define context-errors
    (for/fold ([pv (pvector-empty)]) ([e (in-list context-error-list)])
      (pvector-cons-right pv e)))
  (set! all-errors (pvector-append all-errors context-errors))
  (when (and (not (pvector-empty? context-errors))
             (not (continue-on-error)))
    (display (format-errors context-errors "上下文"))
    (exit 1))

  (unless (should-run-stage? 'cfg)
    (case (format-mode)
      [(sexp)
       (for ([item (in-list context-items)])
         (writeln item))]
      [else
       (for ([item (in-list context-items)])
         (displayln (ast->string item)))])
    (exit 0))

  ;; 阶段 2: CFG
  (define cfg-source
    (if (and (pair? input-files) (null? (cdr input-files)))
        (car input-files)
        'multi-module))
  (define cfg-result
    (run-cfg-stage context-items cfg-source))
  (set! all-errors (pvector-append all-errors (cfg-stage-result-errors cfg-result)))

  (when (and (not (pvector-empty? (cfg-stage-result-errors cfg-result)))
             (not (continue-on-error)))
    (display (format-errors (cfg-stage-result-errors cfg-result) "CFG"))
    (exit 1))

  (when (public-abi-manifest-file)
    (write-public-abi-manifest
     (public-abi-manifest (cfg-stage-result-cfg cfg-result))
     (public-abi-manifest-file))
    (when (>= (verbose-level) 1)
      (eprintf "Public ABI manifest 写入: ~a\n"
               (public-abi-manifest-file))))

  (when (public-c-header-file)
    (write-public-c-header
     (public-abi-manifest (cfg-stage-result-cfg cfg-result))
     (public-c-header-file))
    (when (>= (verbose-level) 1)
      (eprintf "Public C header 写入: ~a\n"
               (public-c-header-file))))

  (unless (should-run-stage? 'regalloc)
    (case (format-mode)
      [(dot)
       (displayln (format-cfg-dot (cfg-stage-result-cfg cfg-result)))]
      [else
       (displayln (format-cfg (cfg-stage-result-cfg cfg-result)))])
    (exit 0))

  ;; 阶段 3: 寄存器分配
  (define regalloc-result
    (run-regalloc-stage (cfg-stage-result-cfg cfg-result)
                        (cfg-stage-result-functions cfg-result)))
  (set! all-errors (pvector-append all-errors (regalloc-stage-result-errors regalloc-result)))

  (when (and (not (pvector-empty? (regalloc-stage-result-errors regalloc-result)))
             (not (continue-on-error)))
    (display (format-errors (regalloc-stage-result-errors regalloc-result) "寄存器分配"))
    (exit 1))

  (unless (should-run-stage? 'emit)
    ;; 输出分配后的函数 (调试用)
    (for ([r (in-list (regalloc-stage-result-results regalloc-result))])
      (define fn (pipeline-result-function r))
      (printf ";; Function: ~a (frame: ~a bytes)\n"
              (asm-function-name fn)
              (pipeline-result-frame-size r)))
    (exit 0))

  ;; 性能报告（在代码生成之前输出）
  (when (perf-report)
    (define report
      (generate-perf-report
       (regalloc-stage-result-results regalloc-result)
       (regalloc-stage-result-functions regalloc-result)
       (regalloc-stage-result-abi-info-map regalloc-result)))
    (displayln report)
    (displayln ""))

  ;; 阶段 4: 代码生成
  (define emit-result
    (run-emit-stage (regalloc-stage-result-results regalloc-result)
                    (regalloc-stage-result-module-items regalloc-result)))

  ;; 输出
  (unless (perf-report)
    (write-output (emit-stage-result-assembly emit-result)))

  ;; 返回状态
  (if (pvector-empty? all-errors) 0 1))

(define (run-compiler input-file)
  (run-compiler/files (list input-file)))

;; ============================================================
;; 命令行解析
;; ============================================================

(define (parse-stop-after str)
  (define sym (string->symbol str))
  (unless (member sym stages)
    (error 'as "无效的阶段: ~a (可选: ~a)" str stages))
  sym)

(define (parse-input-syntax str)
  (case (string->symbol (string-downcase str))
    [(sexp s-expression lisp) 'sexp]
    [(gnu gas) 'gnu]
    [(auto) 'auto]
    [else
     (error 'as "无效的输入语法: ~a (可选: sexp, gnu, auto)" str)]))

(define (resolve-input-syntax input-file)
  (case (input-syntax)
    [(auto)
     (define path-str (string-downcase (format "~a" input-file)))
     (if (or (string-suffix? path-str ".s")
             (string-suffix? path-str ".asm"))
         'gnu
         'sexp)]
    [else (input-syntax)]))

(define (parse-dump-flags str)
  (map string->symbol (string-split str ",")))

(module+ main
  ;; 环境变量选择调度模型（--sched-model 旗标在其后解析，优先生效）
  (let ([e (getenv "ASMP_SCHED_MODEL")])
    (when e (resolve-sched-model! e)))
  (define input-files
    (command-line
     #:program "as"
     #:usage-help
     "asmp 汇编器 - 从 Lisp S-expr / GNU as 编译到 ARM64 汇编\n\n阶段: parse → validate → cfg → regalloc → emit"

     ;; 输出选项
     #:once-each
     [("-o" "--output") file
      "输出文件 (默认: stdout)"
      (output-file file)]

     [("--stdout")
      "强制输出到 stdout"
      (output-stdout #t)]

     [("--public-abi-manifest") file
      "写出 public ABI manifest (rktd)"
      (public-abi-manifest-file file)]

     [("--public-c-header") file
      "写出 public C header"
      (public-c-header-file file)]

     ;; 阶段控制
     [("-S" "--stop-after") stage
      "在指定阶段后停止 (parse|validate|cfg|regalloc|emit)"
      (stop-after (parse-stop-after stage))]

     ;; 调试
     [("-d" "--dump") flags
      "输出调试信息 (ast,cfg,liveness,interference,allocation)"
      (dump-flags (parse-dump-flags flags))]

     [("--regalloc-debug") level
      "寄存器分配调试级别 (0-3)"
      (regalloc-debug (string->number level))]

     [("-g" "--debug-lines")
      "生成 .file/.loc 行号调试信息，供 GDB/LLDB 源码级单步使用"
      (emit-debug-lines #t)]

     [("--debug-reg-map")
      "在输出汇编中以注释形式生成虚拟寄存器到物理寄存器的映射"
      (emit-debug-reg-map #t)]
     [("--keep-comments")
      "把源文件的尾注释透传到输出指令上 (GNU 前端)"
      (current-source-comments (make-hash))]
     [("--sched")
      "启用操作级列表调度器，调度全部函数 (等价 ASMP_SCHED=1)"
      (scheduler-all? #t)]
     [("--sched-only")
      fns
      "只调度指定函数，逗号分隔 (等价 ASMP_SCHED_ONLY=fn1,fn2)"
      (scheduler-only (set-union (scheduler-only)
                                 (list->set (map string->symbol
                                                 (string-split fns ",")))))]
     [("--sched-model")
      model
      "调度器微架构模型：data/<name>.rktd 的名字或文件路径 (默认 apple-m)"
      (resolve-sched-model! model)]

     #:multi
     [("-v" "--verbose")
      "增加详细程度 (可多次使用: -v -v)"
      (verbose-level (add1 (verbose-level)))]

     #:once-each

     ;; 汇编语法
     [("--input-syntax") syntax
      "输入语法 (sexp|gnu|auto，默认: sexp)"
      (input-syntax (parse-input-syntax syntax))]

     [("--gnu-input")
      "GNU as / 传统汇编输入语法"
      (input-syntax 'gnu)]

     [("--sexp-input")
      "S-expression 输入语法"
      (input-syntax 'sexp)]

     [("--gnu")
      "GNU as 语法 (默认)"
      (asm-syntax 'gnu)]

     [("--apple")
      "Apple as 语法 (添加 _ 前缀)"
      (asm-syntax 'apple)]

     [("--cfi")
      "生成 CFI 指令"
      (emit-cfi #t)]

     [("--elim")
      "消除冗余 mov 指令 (如 mov x0, x0)"
      (skip-redundant-mov #t)]

     [("--merge-labels")
      "合并同位置标签 (入口块标签合并到函数名)"
      (merge-colocated-labels #t)]

     ;; 寄存器分配
     [("--no-spill")
      "禁止寄存器溢出 (分配失败则报错)"
      (allow-spill #f)]

     [("--max-iters") n
      "最大寄存器分配迭代次数"
      (max-regalloc-iters (string->number n))]

     [("--ipa-callconv-candidates") names
      "启用 IPA callconv clone planner，逗号分隔候选 ABI"
      (ipa-callconv-candidate-abis (parse-comma-symbols names))]

     [("--ipa-callconv-min-savings") n
      "IPA callconv planner 的最小 move 节省"
      (ipa-callconv-min-savings (string->number n))]

     [("--ipa-callconv-report")
      "输出 IPA callconv clone planner 报告"
      (ipa-callconv-report #t)]

     ;; 格式
     [("-f" "--format") fmt
      "输出格式 (text|json|dot|sexp)"
      (format-mode (string->symbol fmt))]

     ;; 错误处理
     [("--continue-on-error")
      "遇到错误继续处理"
      (continue-on-error #t)]

     [("--no-hints")
      "不显示错误提示"
      (show-hints #f)]

     ;; 功能开关
     [("--skip-validation")
      "跳过语法验证 (Layer1/2/3)"
      (skip-validation #t)]

     [("--no-verify-save-load")
      "不验证 save!/load! 配对"
      (verify-save-load-flag #f)]

     [("--allow-outside-function")
      "允许函数定义外的指令"
      (check-outside-function #f)]

     [("--no-verify-label-refs")
      "不验证标签引用"
      (verify-label-refs-flag #f)]

     [("--no-verify-symbol-names")
      "不验证符号名合法性"
      (verify-symbol-names-flag #f)]

     [("--allow-sp-writes")
      "允许源码中直接写 sp (兼容旧式手写栈代码)"
      (sp-write-policy 'allow)]

     [("--warn-sp-writes")
      "源码中直接写 sp 时发出警告 (默认)"
      (sp-write-policy 'warn)]

     [("--forbid-sp-writes")
      "禁止源码中直接写 sp (作为 CFG 错误)"
      (sp-write-policy 'error)]

     [("--pedantic")
      "启用严格检查 (警告可疑的代码模式)"
      (pedantic-flag #t)]

     [("--perf-report")
      "输出性能分析报告 (溢出、load-use 依赖链、ABI 建议)"
      (perf-report #t)]

     ;; ABI 配置
     [("--default-abi") name
      "默认 ABI (如 aapcs64, leaf, naked)"
      (default-abi-name (string->symbol name))]

     [("--abi-config") path
      "ABI 配置文件路径"
      (abi-config-path path)]

     #:args input-files
     input-files))

  ;; 捕获所有未处理的异常，提供友好的错误消息
  (with-handlers
    ([exn:fail?
      (lambda (e)
        (define msg (exn-message e))
        ;; 清理错误消息
        (define clean-msg
          (cond
            ;; 合约违规
            [(regexp-match #rx"^([^:]+): contract violation" msg)
             => (lambda (m)
                  (format "内部错误: ~a 参数无效\n建议: 检查输入文件是否完整 (如缺少 end-function)" (cadr m)))]
            ;; 其他错误
            [else msg]))
        (eprintf "\n=== 编译器错误 ===\n~a\n" clean-msg)
        (when (>= (verbose-level) 2)
          (eprintf "\n=== 详细堆栈 ===\n")
          (for ([ctx (in-list (continuation-mark-set->context
                               (exn-continuation-marks e)))])
            (when (car ctx)
              (eprintf "  ~a\n" (car ctx)))))
        (exit 1))])
    (exit (run-compiler/files input-files))))

;; ============================================================
;; In-process 汇编入口 (供构建工具/测试直接 require 调用, 免 racket 子进程)
;; ============================================================

;; assemble : (or/c path-string (listof path-string)) 关键字… -> exit-code(0=成功)
;; run-compiler/files 内部多处 (exit …);用 exit-handler 拦成返回码, 不终止调用进程。
(define (assemble input
                  #:output          [output #f]
                  #:input-syntax    [in-syn 'sexp]
                  #:asm-syntax      [asm-syn 'gnu]
                  #:elim?           [elim? #f]
                  #:cfi?            [cfi? #f]
                  #:public-c-header [pch #f]
                  #:abi-config      [abi-cfg #f]
                  #:default-abi     [def-abi #f])
  (define files (if (list? input) input (list input)))
  (let/ec return
    (parameterize ([exit-handler         (lambda (code) (return code))]
                   [output-file          output]
                   [input-syntax         in-syn]
                   [asm-syntax           asm-syn]
                   [skip-redundant-mov   elim?]
                   [emit-cfi             cfi?]
                   [public-c-header-file pch]
                   [abi-config-path      (if abi-cfg abi-cfg (abi-config-path))]
                   [default-abi-name     (if def-abi def-abi (default-abi-name))])
      (run-compiler/files files))))

;; ============================================================
;; 库接口 (供其他模块使用)
;; ============================================================

(provide
 ;; in-process 汇编入口
 assemble

 ;; 主函数
 run-compiler
 run-compiler/files

 ;; 分阶段结果
 (struct-out parse-stage-result)
 (struct-out cfg-stage-result)
 (struct-out regalloc-stage-result)
 (struct-out emit-stage-result)

 ;; 分阶段执行
 run-parse-stage
 run-parse-stage/files
 run-cfg-stage
 run-regalloc-stage
 run-emit-stage

 ;; 参数
 output-file
 output-stdout
 public-abi-manifest-file
 public-c-header-file
 stop-after
 dump-flags
 verbose-level
 emit-debug-lines
 emit-debug-reg-map
 input-syntax
 asm-syntax
 emit-cfi
 allow-spill
 max-regalloc-iters
 ipa-callconv-candidate-abis
 ipa-callconv-min-savings
 ipa-callconv-report
 format-mode
 continue-on-error
 show-hints
 skip-validation
 verify-save-load-flag
 sp-write-policy
 check-outside-function)
