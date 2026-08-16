#!/usr/bin/env racket
#lang racket

;; ============================================================
;; cli/parse2.rkt - 汇编文件解析 CLI (含 Use/Def 语义分析)
;; ============================================================
;;
;; 用法: racket cli/parse2.rkt [options] <input-file>
;;
;; 功能:
;;   - 解析汇编文件
;;   - 验证指令语法 (Layer1/2/3)
;;   - 显示 Use/Def 语义信息

(require "../parser/frontend.rkt"
         "../parser/ast.rkt"
         "../syntax/validator.rkt"
         "../syntax/spec.rkt"
         "../semantic/use-def.rkt"
         "../semantic/branch-info.rkt"
         "../semantic/control-flow.rkt"
         (only-in "../syntax/lookup.rkt" encoding-info? encoding-info-encoding-id encoding-info-template)
         racket/cmdline)

;; 将 validation-hint 列表转换为字符串列表
(define (hints->strings hints)
  (for/list ([h (in-list hints)])
    (format-hint h)))

;; ============================================================
;; 参数控制
;; ============================================================

(define show-ok-on-error (make-parameter #f))
(define show-use-def (make-parameter #t))
(define show-layer-info (make-parameter #t))
(define compact-mode (make-parameter #f))
(define show-cfg (make-parameter #f))
(define show-dot (make-parameter #f))

;; ============================================================
;; 诊断信息中间表示 (Diagnostic IR)
;; ============================================================

(struct diag-msg
  (key args)
  #:transparent)

(struct operand-info
  (index source actual-type)
  #:transparent)

(struct expected-sig
  (signature example)
  #:transparent)

(struct operand-diff
  (index expected actual)
  #:transparent)

(struct diagnostic
  (kind location source-code mnemonic operands expected diffs suggestions raw-message)
  #:transparent)

;; ============================================================
;; 诊断信息构建
;; ============================================================

(define (build-diagnostic item)
  (define ins (parse-result-instruction item))
  (define loc (parse-result-srcloc item))
  (define validation (parse-result-validation item))
  (define err (parse-result-parse-error item))
  (define loc-str (format-srcloc loc))

  (cond
    [(and err (eq? (parse-error-kind err) 'read))
     (diagnostic 'read-error loc-str #f #f #f #f #f '()
                 (parse-error-message err))]

    [(and ins validation)
     (define mnem (validation-result-mnemonic validation))
     (define actual-class (validation-result-actual-class validation))
     (define actual-sig (validation-result-actual-signature validation))
     (define error-layer (validation-result-error-layer validation))
     (define source-code (ast->string ins))
     (define operands-list (ast-ins-operands ins))

     (define op-infos
       (for/list ([type (in-list actual-sig)]
                  [op (in-list operands-list)]
                  [i (in-naturals 1)])
         (operand-info i (ast->string op) type)))

     (case error-layer
       [(mnemonic)
        (diagnostic 'unknown-mnemonic loc-str source-code mnem
                    op-infos #f #f
                    (hints->strings (validation-result-hints validation))
                    #f)]

       [(layer1)
        (define allowed-classes (lookup-layer1-classes mnem))
        (define all-sigs
          (apply append
                 (for/list ([cls (in-list allowed-classes)])
                   (lookup-layer2-sigs mnem cls))))
        (define expected-list
          (for/list ([sig (in-list (remove-duplicates all-sigs))])
            (expected-sig sig (generate-example mnem sig))))
        (diagnostic 'wrong-arity loc-str source-code mnem
                    op-infos expected-list #f
                    (hints->strings (validation-result-hints validation))
                    #f)]

       [(layer2)
        (define allowed-sigs (lookup-layer2-sigs mnem actual-class))
        (define same-len-sigs
          (filter (lambda (s) (= (length s) (length actual-sig))) allowed-sigs))
        (define diffs
          (if (pair? same-len-sigs)
              (let ([best-sig (car same-len-sigs)])
                (for/list ([exp (in-list best-sig)]
                           [act (in-list actual-sig)]
                           [i (in-naturals 1)]
                           #:unless (eq? exp act))
                  (operand-diff i exp act)))
              '()))
        (define expected-list
          (for/list ([sig (in-list same-len-sigs)])
            (expected-sig sig (generate-example mnem sig))))
        (diagnostic 'type-mismatch loc-str source-code mnem
                    op-infos expected-list diffs
                    '()
                    #f)]

       [(layer3)
        (define error-msg (validation-result-error-message validation))
        (define suggs (hints->strings (validation-result-hints validation)))
        (diagnostic 'constraint-error loc-str source-code mnem
                    op-infos #f #f suggs
                    error-msg)]

       [else
        (diagnostic 'unknown loc-str source-code mnem
                    op-infos #f #f '()
                    (validation-result-error-message validation))])]

    [else
     (diagnostic 'unknown loc-str #f #f #f #f #f '()
                 (and err (parse-error-message err)))]))

;; ============================================================
;; 类型名称映射
;; ============================================================

(define type-names
  #hash((gpr-64       . "64位通用寄存器 (x0-x30)")
        (gpr-32       . "32位通用寄存器 (w0-w30)")
        (gpr-64-sp    . "64位寄存器/SP")
        (gpr-32-sp    . "32位寄存器/WSP")
        (fpr-64       . "64位浮点寄存器 (d0-d31)")
        (fpr-32       . "32位浮点寄存器 (s0-s31)")
        (fpr-16       . "16位浮点寄存器 (h0-h31)")
        (fpr-128      . "128位向量寄存器 (q0-q31)")
        (fpr-8        . "8位寄存器 (b0-b31)")
        (sve-z        . "SVE Z寄存器 (z0-z31)")
        (sve-p        . "SVE 谓词寄存器 (p0-p15)")
        (sve-pn       . "SVE 谓词对寄存器 (pn0-pn15)")
        (imm          . "立即数")
        (immediate    . "立即数")
        (memory       . "内存地址")
        (label        . "标签/符号")
        (shift        . "移位操作 (lsl/lsr/asr/ror)")
        (extend       . "扩展操作 (uxtb/sxtw等)")
        (reglist      . "寄存器列表 { ... }")
        (reg-list     . "寄存器列表 { ... }")
        (simd-scalar  . "SIMD标量 (b/h/s/d)")
        (simd-vector  . "SIMD向量 (v0-v31)")
        (vector-length . "向量长度修饰符 (vl1-vl256)")
        (condition    . "条件码 (eq/ne/cs/cc等)")
        (cond         . "条件码 (eq/ne/cs/cc等)")
        (prefetch     . "预取类型")
        (barrier      . "屏障选项")
        (system-reg   . "系统寄存器")))

(define (type-name type)
  (hash-ref type-names type (symbol->string type)))

;; ============================================================
;; 示例生成
;; ============================================================

(define (generate-example mnem sig)
  (define operands
    (for/list ([type (in-list sig)]
               [i (in-naturals)])
      (case type
        [(gpr-64 gpr-64-sp) (format "x~a" i)]
        [(gpr-32 gpr-32-sp) (format "w~a" i)]
        [(fpr-64) (format "d~a" i)]
        [(fpr-32) (format "s~a" i)]
        [(fpr-16) (format "h~a" i)]
        [(fpr-128) (format "q~a" i)]
        [(fpr-8) (format "b~a" i)]
        [(sve-z) (format "z~a.d" i)]
        [(sve-p) (format "p~a" i)]
        [(sve-pn) (format "pn~a" i)]
        [(imm immediate) (format "~a" (expt 2 i))]
        [(memory) "(sp 0)"]
        [(label) "target"]
        [(shift) "lsl"]
        [(extend) "uxtx"]
        [(simd-scalar) (format "d~a" i)]
        [(simd-vector) (format "v~a.4s" i)]
        [(reglist reg-list) "{ v0.4s v1.4s }"]
        [(vector-length) "vl4"]
        [(condition cond) "eq"]
        [else "..."])))
  (if (null? operands)
      (format "(~a)" mnem)
      (format "(~a ~a)" mnem (string-join operands " "))))

;; ============================================================
;; 诊断格式化
;; ============================================================

(define (format-diagnostic diag index)
  (match-define (diagnostic kind loc source mnem ops expected diffs suggs raw) diag)

  (define lines '())
  (define (add! line) (set! lines (cons line lines)))

  (add! (format "错误 ~a: ~a" index loc))
  (add! "─────────────────────────────────────────")

  (case kind
    [(read-error)
     (add! "  [读取错误]")
     (add! (format "  ~a" raw))]

    [(unknown-mnemonic)
     (add! (format "  代码: ~a" source))
     (add! "")
     (add! "  [未知指令]")
     (add! (format "  助记符 '~a' 不存在于指令集中" mnem))
     (when (pair? suggs)
       (add! "")
       (for ([s (in-list suggs)])
         (add! (format "  ~a" s))))]

    [(wrong-arity)
     (add! (format "  代码: ~a" source))
     (add! "")
     (add! "  [操作数数量/结构错误]")
     (add! "")
     (add! "  您的写法:")
     (for ([op (in-list ops)])
       (add! (format "    [~a] ~a  →  ~a"
                     (operand-info-index op)
                     (operand-info-source op)
                     (type-name (operand-info-actual-type op)))))
     (add! "")
     (add! (format "  ~a 支持的操作数形式:" mnem))
     (when expected
       (for ([exp (in-list (take expected (min 5 (length expected))))])
         (add! (format "    ~a" (expected-sig-example exp)))
         (add! (format "      签名: ~a"
                       (string-join (map type-name (expected-sig-signature exp)) ", ")))))
     (when (pair? suggs)
       (add! "")
       (add! "  提示:")
       (for ([s (in-list suggs)])
         (add! (format "    - ~a" s))))]

    [(type-mismatch)
     (add! (format "  代码: ~a" source))
     (add! "")
     (add! "  [操作数类型错误]")
     (add! "")
     (add! "  您的写法:")
     (for ([op (in-list ops)])
       (add! (format "    [~a] ~a  →  ~a"
                     (operand-info-index op)
                     (operand-info-source op)
                     (type-name (operand-info-actual-type op)))))
     (when (pair? diffs)
       (add! "")
       (add! "  类型不匹配:")
       (for ([d (in-list diffs)])
         (add! (format "    操作数 ~a: 期望 ~a, 实际是 ~a"
                       (operand-diff-index d)
                       (type-name (operand-diff-expected d))
                       (type-name (operand-diff-actual d))))))
     (when (and expected (pair? expected))
       (add! "")
       (add! "  正确写法:")
       (for ([exp (in-list (take expected (min 3 (length expected))))])
         (add! (format "    ~a" (expected-sig-example exp)))))]

    [(constraint-error)
     (add! (format "  代码: ~a" source))
     (add! "")
     (add! "  [操作数值约束错误]")
     (add! "")
     (add! (format "  ~a" raw))
     (when (pair? suggs)
       (add! "")
       (add! "  原因:")
       (for ([s (in-list suggs)])
         (add! (format "    • ~a" s))))]

    [else
     (when source (add! (format "  代码: ~a" source)))
     (when raw (add! (format "  ~a" raw)))])

  (string-join (reverse lines) "\n"))

;; ============================================================
;; Layer3 格式化
;; ============================================================

(define (format-encoding-brief enc)
  (cond
    [(encoding-info? enc)
     (format "~a [~a]"
             (encoding-info-encoding-id enc)
             (encoding-info-template enc))]
    [(and (list? enc) (>= (length enc) 2))
     (format "~a [~a]" (first enc) (second enc))]
    [else (format "~a" enc)]))

(define (get-encoding-id enc)
  (cond
    [(encoding-info? enc) (encoding-info-encoding-id enc)]
    [(and (list? enc) (>= (length enc) 1)) (first enc)]
    [else enc]))

(define (format-layer3-info validation)
  (define encodings (validation-result-matched-encodings validation))
  (cond
    [(null? encodings) "无匹配编码"]
    [(= (length encodings) 1)
     (format-encoding-brief (car encodings))]
    [else
     (format "~a 个编码: ~a"
             (length encodings)
             (string-join (map (lambda (e) (format "~a" (get-encoding-id e)))
                              encodings)
                         ", "))]))

;; ============================================================
;; Use/Def 格式化
;; ============================================================

(define (format-use-def-brief result)
  (define defs (use-def-flat-defs result))
  (define uses (use-def-flat-uses result))
  (format "defs=[~a] uses=[~a]"
          (format-regs-compact defs)
          (format-regs-compact uses)))

(define (format-regs-compact regs)
  (if (null? regs)
      ""
      (string-join
       (for/list ([r (in-list regs)])
         (define pos (reg-ref-position r))
         (format "~a~a~a"
                 (reg-ref-kind r)
                 (reg-ref-id r)
                 (case pos
                   [(base) "/b"]
                   [(index) "/i"]
                   [else ""])))
       ",")))

(define (format-use-def-detail result)
  (define lines '())
  (define (add! line) (set! lines (cons line lines)))

  (for ([op-ref (in-list (use-def-result-operands result))])
    (define idx (operand-ref-index op-ref))
    (define role (operand-ref-role op-ref))
    (define regs (operand-ref-regs op-ref))
    (add! (format "    [~a] ~a: ~a"
                  idx
                  (case role
                    [(def) "def"]
                    [(use) "use"]
                    [(def+use) "def+use"])
                  (if (null? regs)
                      "(无寄存器)"
                      (format-regs-compact regs)))))

  (string-join (reverse lines) "\n"))

;; ============================================================
;; 输出
;; ============================================================

(define (print-instruction-result item)
  (define ins (parse-result-instruction item))
  (define loc (parse-result-srcloc item))
  (define validation (parse-result-validation item))

  (when (and ins validation (validation-ok? validation))
    (define use-def-result (extract-use-def ins))

    (if (compact-mode)
        ;; 紧凑模式
        (begin
          (printf "~a: ~a"
                  (format-srcloc loc)
                  (ast->string ins))
          (when (show-use-def)
            (printf "  | ~a" (format-use-def-brief use-def-result)))
          (newline))

        ;; 详细模式
        (begin
          (printf "~a: ~a\n"
                  (format-srcloc loc)
                  (ast->string ins))

          (when (show-layer-info)
            (printf "  Layer1: ~a\n" (validation-result-actual-class validation))
            (printf "  Layer2: ~a\n" (validation-result-actual-signature validation))
            (printf "  Layer3: ~a\n" (format-layer3-info validation)))

          (when (show-use-def)
            (printf "  Use/Def:\n")
            (displayln (format-use-def-detail use-def-result))
            (printf "    汇总: ~a\n" (format-use-def-brief use-def-result)))

          (newline)))))

(define (format-all-errors results)
  (define errors (parse-results-filter-errors results))
  (if (null? errors)
      ""
      (string-join
       (for/list ([item (in-list errors)]
                  [i (in-naturals 1)])
         (format-diagnostic (build-diagnostic item) i))
       "\n\n")))

;; ============================================================
;; 主程序
;; ============================================================

(define (run-parser input-file)
  (unless (file-exists? input-file)
    (eprintf "错误: 文件不存在: ~a\n" input-file)
    (exit 1))

  (define results (parse-file input-file #:validate? #t))
  (define has-errors (parse-results-has-errors? results))

  ;; CFG 模式 - 使用所有成功解析的项 (包括验证失败的)
  (cond
    [(show-cfg)
     (define items
       (for/list ([r (in-list (parse-results-items results))]
                  #:when (parse-result-instruction r))
         (parse-result-instruction r)))
     (define cfg (build-cfg items input-file))
     (if (show-dot)
         (displayln (format-cfg-dot cfg))
         (displayln (format-cfg cfg)))
     ;; 在 CFG 模式下只输出 CFG
     0]

    [else
     ;; 普通模式
     (run-parser-normal results has-errors)]))

(define (run-parser-normal results has-errors)
  ;; 预加载 use/def 数据库
  (when (show-use-def)
    (void (get-use-def-db)))

  ;; 输出成功结果
  (when (or (not has-errors) (show-ok-on-error))
    (unless (compact-mode)
      (displayln "=== 解析结果 (含 Use/Def 语义) ===\n"))
    (for ([item (parse-results-filter-ok results)])
      (print-instruction-result item)))

  ;; 摘要
  (unless (compact-mode)
    (displayln "=== 摘要 ===")
    (displayln (format-parse-results-summary results))
    (displayln ""))

  ;; 错误报告
  (when has-errors
    (unless (compact-mode)
      (displayln "=== 错误报告 ===\n"))
    (displayln (format-all-errors results)))

  (if has-errors 1 0))

;; ============================================================
;; 命令行入口
;; ============================================================

(module+ main
  (define input-file
    (command-line
     #:program "parse2"
     #:usage-help "解析汇编文件并输出 Use/Def 语义信息"
     #:once-each
     [("-a" "--show-all")
      "即使有错误也显示成功解析的结果"
      (show-ok-on-error #t)]
     [("-c" "--compact")
      "紧凑输出模式 (单行)"
      (compact-mode #t)]
     [("--no-use-def")
      "不显示 Use/Def 信息"
      (show-use-def #f)]
     [("--no-layer")
      "不显示 Layer 信息"
      (show-layer-info #f)]
     [("--cfg")
      "构建并输出控制流图 (CFG)"
      (show-cfg #t)]
     [("--dot")
      "以 DOT 格式输出 CFG (需配合 --cfg 使用)"
      (show-dot #t)]
     #:args (input-file)
     input-file))

  (exit (run-parser input-file)))
