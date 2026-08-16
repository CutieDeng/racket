#!/usr/bin/env racket
#lang racket

;; ============================================================
;; cli/parse.rkt - 汇编文件解析 CLI
;; ============================================================
;;
;; 用法: racket cli/parse.rkt [options] <input-file>

(require "../parser/frontend.rkt"
         "../parser/ast.rkt"
         "../syntax/validator.rkt"
         "../syntax/spec.rkt"
         (only-in "../syntax/lookup.rkt" encoding-info? encoding-info-encoding-id encoding-info-template)
         racket/cmdline)

;; ============================================================
;; 辅助函数: 将结构化提示转为字符串列表
;; ============================================================

(define (hints->strings hints)
  (for/list ([h (in-list hints)])
    (match h
      [(validation-hint 'suffix ops)
       (format "可添加后缀: ~a" ops)]
      [(validation-hint 'similar-mnemonic mnems)
       (format "您是否想要: ~a" (string-join (map symbol->string mnems) ", "))]
      [(validation-hint 'type-mismatch (list idx exp act))
       (format "操作数 ~a: 期望 ~a, 实际 ~a" idx exp act)]
      [(validation-hint 'operand-count 'too-few)
       "可能少写了操作数"]
      [(validation-hint 'operand-count 'too-many)
       "可能多写了操作数"]
      [(validation-hint 'memory-required #t)
       "可能需要内存操作数 [...]"]
      [(validation-hint 'memory-not-allowed #t)
       "此指令不使用内存操作数"]
      [(validation-hint 'constraint data)
       (format "约束: ~a" data)]
      [(? string? s) s]  ; 兼容旧的字符串格式
      [_ (format "~a" h)])))

;; ============================================================
;; 参数控制
;; ============================================================

(define show-ok-on-error (make-parameter #f))

;; ============================================================
;; 诊断信息中间表示 (Diagnostic IR)
;; ============================================================
;; 便于 locale 国际化，将诊断信息与格式化分离

;; 诊断消息类型
(struct diag-msg
  (key           ; symbol - 消息键 (用于 locale 查找)
   args)         ; list - 参数列表
  #:transparent)

;; 操作数信息
(struct operand-info
  (index         ; number - 操作数位置 (从 1 开始)
   source        ; string - 源码文本
   actual-type)  ; symbol - 实际类型
  #:transparent)

;; 期望的签名信息
(struct expected-sig
  (signature     ; (listof symbol) - 签名
   example)      ; string - 示例代码
  #:transparent)

;; 操作数差异
(struct operand-diff
  (index         ; number
   expected      ; symbol
   actual)       ; symbol
  #:transparent)

;; 诊断信息
(struct diagnostic
  (kind          ; symbol - 'read-error | 'unknown-mnemonic | 'wrong-arity | 'type-mismatch | 'no-encoding
   location      ; string - 位置字符串
   source-code   ; string | #f - 源码
   mnemonic      ; symbol | #f
   operands      ; (listof operand-info) | #f
   expected      ; (listof expected-sig) | #f
   diffs         ; (listof operand-diff) | #f - 对于 type-mismatch
   suggestions   ; (listof string)
   raw-message)  ; string | #f - 原始消息 (fallback)
  #:transparent)

;; ============================================================
;; 诊断信息构建
;; ============================================================

;; 从 parse-result 构建诊断信息
(define (build-diagnostic item)
  (define ins (parse-result-instruction item))
  (define loc (parse-result-srcloc item))
  (define validation (parse-result-validation item))
  (define err (parse-result-parse-error item))
  (define loc-str (format-srcloc loc))

  (cond
    ;; 读取错误
    [(and err (eq? (parse-error-kind err) 'read))
     (diagnostic 'read-error loc-str #f #f #f #f #f '()
                 (parse-error-message err))]

    ;; 验证错误
    [(and ins validation)
     (define mnem (validation-result-mnemonic validation))
     (define actual-class (validation-result-actual-class validation))
     (define actual-sig (validation-result-actual-signature validation))
     (define error-layer (validation-result-error-layer validation))
     (define source-code (ast->string ins))
     (define operands-list (ast-ins-operands ins))

     ;; 构建操作数信息
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
        ;; 获取所有支持的 Layer1 类别下的具体签名
        (define allowed-classes (lookup-layer1-classes mnem))
        (define all-sigs
          (apply append
                 (for/list ([cls (in-list allowed-classes)])
                   (lookup-layer2-sigs mnem cls))))
        ;; 构建期望签名列表
        (define expected-list
          (for/list ([sig (in-list (remove-duplicates all-sigs))])
            (expected-sig sig (generate-example mnem sig))))
        (diagnostic 'wrong-arity loc-str source-code mnem
                    op-infos expected-list #f
                    (hints->strings (validation-result-hints validation))
                    #f)]

       [(layer2)
        (define allowed-sigs (lookup-layer2-sigs mnem actual-class))
        ;; 找出最接近的匹配（操作数数量相同）
        (define same-len-sigs
          (filter (lambda (s) (= (length s) (length actual-sig))) allowed-sigs))
        ;; 构建差异信息
        (define diffs
          (if (pair? same-len-sigs)
              (let ([best-sig (car same-len-sigs)])
                (for/list ([exp (in-list best-sig)]
                           [act (in-list actual-sig)]
                           [i (in-naturals 1)]
                           #:unless (eq? exp act))
                  (operand-diff i exp act)))
              '()))
        ;; 期望签名
        (define expected-list
          (for/list ([sig (in-list same-len-sigs)])
            (expected-sig sig (generate-example mnem sig))))
        ;; 使用结构化提示
        (define hint-strings (hints->strings (validation-result-hints validation)))
        (diagnostic 'type-mismatch loc-str source-code mnem
                    op-infos expected-list diffs
                    hint-strings
                    #f)]

       [(layer3)
        ;; Layer3 错误 - 约束验证失败
        ;; 获取错误消息和建议
        (define error-msg (validation-result-error-message validation))
        (define suggs (hints->strings (validation-result-hints validation)))
        (diagnostic 'constraint-error loc-str source-code mnem
                    op-infos #f #f suggs
                    error-msg)]

       [else
        (diagnostic 'unknown loc-str source-code mnem
                    op-infos #f #f '()
                    (validation-result-error-message validation))])]

    ;; 其他错误
    [else
     (diagnostic 'unknown loc-str #f #f #f #f #f '()
                 (and err (parse-error-message err)))]))

;; ============================================================
;; 类型名称映射 (可用于 locale)
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
;; 诊断格式化 (从中间表示生成输出)
;; ============================================================

(define (format-diagnostic diag index)
  (match-define (diagnostic kind loc source mnem ops expected diffs suggs raw) diag)

  (define lines '())
  (define (add! line) (set! lines (cons line lines)))

  ;; 标题
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
     ;; 您的写法
     (add! "  您的写法:")
     (for ([op (in-list ops)])
       (add! (format "    [~a] ~a  →  ~a"
                     (operand-info-index op)
                     (operand-info-source op)
                     (type-name (operand-info-actual-type op)))))
     (add! "")
     ;; 期望的形式
     (add! (format "  ~a 支持的操作数形式:" mnem))
     (when expected
       (for ([exp (in-list (take expected (min 5 (length expected))))])
         (add! (format "    ~a" (expected-sig-example exp)))
         ;; 显示签名类型
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
     ;; 您的写法
     (add! "  您的写法:")
     (for ([op (in-list ops)])
       (add! (format "    [~a] ~a  →  ~a"
                     (operand-info-index op)
                     (operand-info-source op)
                     (type-name (operand-info-actual-type op)))))
     ;; 差异
     (when (pair? diffs)
       (add! "")
       (add! "  类型不匹配:")
       (for ([d (in-list diffs)])
         (add! (format "    操作数 ~a: 期望 ~a, 实际是 ~a"
                       (operand-diff-index d)
                       (type-name (operand-diff-expected d))
                       (type-name (operand-diff-actual d))))))
     ;; 正确示例
     (when (and expected (pair? expected))
       (add! "")
       (add! "  正确写法:")
       (for ([exp (in-list (take expected (min 3 (length expected))))])
         (add! (format "    ~a" (expected-sig-example exp)))))
     ;; 提示（如 lsl 0 补全）
     (when (pair? suggs)
       (add! "")
       (add! "  提示:")
       (for ([s (in-list suggs)])
         (add! (format "    - ~a" s))))]

    [(no-encoding)
     (add! (format "  代码: ~a" source))
     (add! "")
     (add! "  [无匹配编码]")
     (add! (format "  ~a" raw))]

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
;; 输出
;; ============================================================

(define (print-instruction-result item)
  (define ins (parse-result-instruction item))
  (define loc (parse-result-srcloc item))
  (define validation (parse-result-validation item))

  (when (and ins validation (validation-ok? validation))
    (printf "~a: ~a\n"
            (format-srcloc loc)
            (ast->string ins))
    (printf "  签名: ~a\n" (validation-result-actual-signature validation))
    (printf "  编码: ~a\n\n" (format-layer3-info validation))))

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

  ;; 输出成功结果 (根据参数)
  (when (or (not has-errors) (show-ok-on-error))
    (displayln "=== 解析结果 ===\n")
    (for ([item (parse-results-filter-ok results)])
      (print-instruction-result item)))

  ;; 摘要
  (displayln "=== 摘要 ===")
  (displayln (format-parse-results-summary results))
  (displayln "")

  ;; 错误报告
  (when has-errors
    (displayln "=== 错误报告 ===\n")
    (displayln (format-all-errors results)))

  (if has-errors 1 0))

;; ============================================================
;; 命令行入口
;; ============================================================

(module+ main
  (define input-file
    (command-line
     #:program "parse"
     #:usage-help "解析汇编文件并输出 Layer3 编码信息"
     #:once-each
     [("-a" "--show-all")
      "即使有错误也显示成功解析的结果"
      (show-ok-on-error #t)]
     #:args (input-file)
     input-file))

  (exit (run-parser input-file)))
