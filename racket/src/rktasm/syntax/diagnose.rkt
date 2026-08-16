#lang racket

(require "../parser/ast.rkt"
         "class.rkt"
         "variant.rkt"
         "operand-type.rkt"
         "constraint.rkt")

(provide diagnose-instruction
         diagnose-instruction/layer2
         diagnose-instruction/layer3
         classify-instruction
         extract-ast-signature
         extract-ast-values
         validate-operand-constraints
         (struct-out diagnosis)
         (struct-out constraint-violation)
         diagnosis-ok?
         diagnosis-error?
         format-diagnosis)

;; ============================================================
;; 指令语法诊断模块
;; ============================================================
;;
;; 三层诊断:
;;   1. 大类别匹配 (cN, cNm, cNmK) - Layer 1
;;   2. 操作数类型签名匹配 - Layer 2
;;   3. 细粒度约束验证 (寄存器范围, 立即数范围) - Layer 3
;;
;; 使用新的 parser/ast.rkt 类型

;; ============================================================
;; 诊断结果
;; ============================================================

(struct diagnosis
  (success?          ; #t if OK
   mnemonic          ; symbol: 'add
   actual-class      ; symbol: 'c2
   allowed-classes   ; (setof symbol): (set 'c3 'c4)
   message           ; string or #f
   suggestions       ; (listof string)
   variants          ; (listof syntax-variant)
   actual-signature  ; (listof operand-type) - Layer 2
   matched-variants  ; (listof syntax-variant) - 类型匹配的变体
   constraint-violations) ; (listof constraint-violation) - Layer 3
  #:transparent)

;; Layer 3 约束违规记录
(struct constraint-violation
  (field-name       ; string: "Rd", "imm6"
   expected         ; constraint: (reg-range 0 31)
   actual           ; any: 32
   message)         ; string: "寄存器编号超出范围"
  #:transparent)

(define (diagnosis-ok? d)
  (and (diagnosis? d) (diagnosis-success? d)))

(define (diagnosis-error? d)
  (and (diagnosis? d) (not (diagnosis-success? d))))

;; ============================================================
;; 指令分类
;; ============================================================

(define (classify-instruction ins)
  (match ins
    [(ast-ins _ _ operands _)
     (define mem-idx
       (for/first ([i (in-naturals)]
                   [op (in-list operands)]
                   #:when (ast-mem? op))
         i))

     (define has-mem? (and mem-idx #t))
     (define pre-count (or mem-idx (length operands)))
     (define post-count
       (if has-mem?
           (- (length operands) mem-idx 1)
           0))

     (classify-operand-count pre-count has-mem? post-count)]))

;; 从 AST 指令提取操作数类型签名 (Layer 2)
(define (extract-ast-signature ins)
  (match ins
    [(ast-ins _ _ operands _)
     (map classify-ast-operand operands)]
    [_ '()]))

;; ============================================================
;; 诊断逻辑
;; ============================================================

;; Layer 1 诊断 (仅语法类别匹配)
(define (diagnose-instruction ins variant-db)
  (match ins
    [(ast-ins mnem _ _ _)
     (define actual-class (classify-instruction ins))
     (define actual-signature (extract-ast-signature ins))
     (define variants (lookup-variants-by-mnemonic variant-db mnem))

     (cond
       [(null? variants)
        (diagnosis #f mnem actual-class (set)
                   (format "未知指令: ~a" mnem)
                   '() '() actual-signature '() '())]
       [else
        (define allowed-classes
          (for/set ([v (in-list variants)])
            (syntax-variant-syntax-class v)))

        (cond
          [(set-member? allowed-classes actual-class)
           (define matching
             (filter (λ (v) (eq? (syntax-variant-syntax-class v) actual-class))
                     variants))
           (diagnosis #t mnem actual-class allowed-classes #f '() matching
                      actual-signature matching '())]
          [else
           (define suggestions
             (generate-suggestions actual-class allowed-classes))
           (diagnosis #f mnem actual-class allowed-classes
                      (format "~a 是 ~a，但 ~a 只支持 ~a"
                              (ast->string ins)
                              actual-class
                              mnem
                              (format-class-set allowed-classes))
                      suggestions
                      variants
                      actual-signature '() '())])])]))

;; Layer 2 诊断 (语法类别 + 操作数类型签名匹配)
;; signature-db: hash[template -> signature]
(define (diagnose-instruction/layer2 ins variant-db [signature-db #f])
  (match ins
    [(ast-ins mnem _ _ _)
     (define actual-class (classify-instruction ins))
     (define actual-signature (extract-ast-signature ins))
     (define variants (lookup-variants-by-mnemonic variant-db mnem))

     (cond
       [(null? variants)
        (diagnosis #f mnem actual-class (set)
                   (format "未知指令: ~a" mnem)
                   '() '() actual-signature '() '())]
       [else
        (define allowed-classes
          (for/set ([v (in-list variants)])
            (syntax-variant-syntax-class v)))

        (cond
          [(set-member? allowed-classes actual-class)
           ;; Layer 1 通过，进行 Layer 2 过滤
           (define class-matching
             (filter (λ (v) (eq? (syntax-variant-syntax-class v) actual-class))
                     variants))

           ;; Layer 2: 类型签名过滤
           (define type-matching
             (if signature-db
                 (filter-by-signature class-matching actual-signature signature-db)
                 class-matching))

           (cond
             ;; 有类型匹配的变体
             [(pair? type-matching)
              (diagnosis #t mnem actual-class allowed-classes #f '()
                         class-matching actual-signature type-matching '())]
             ;; 类别匹配但类型不匹配
             [else
              (define suggestions
                (generate-type-suggestions actual-signature class-matching signature-db))
              (diagnosis #f mnem actual-class allowed-classes
                         (format "~a 类别匹配 ~a，但操作数类型不匹配"
                                 (ast->string ins)
                                 actual-class)
                         suggestions
                         class-matching
                         actual-signature '() '())])]
          [else
           ;; Layer 1 不匹配
           (define suggestions
             (generate-suggestions actual-class allowed-classes))
           (diagnosis #f mnem actual-class allowed-classes
                      (format "~a 是 ~a，但 ~a 只支持 ~a"
                              (ast->string ins)
                              actual-class
                              mnem
                              (format-class-set allowed-classes))
                      suggestions
                      variants
                      actual-signature '() '())])])]))

;; 按类型签名过滤变体
(define (filter-by-signature variants actual-signature signature-db)
  (filter
   (λ (v)
     (define template (syntax-variant-template v))
     (define template-sig (hash-ref signature-db template #f))
     (and template-sig
          (signature-matches? actual-signature template-sig)))
   variants))

;; 生成类型匹配相关的建议
(define (generate-type-suggestions actual-signature variants signature-db)
  (define suggestions '())

  (when signature-db
    ;; 收集期望的类型签名
    (define expected-sigs
      (for/list ([v (in-list variants)]
                 #:when (hash-has-key? signature-db (syntax-variant-template v)))
        (hash-ref signature-db (syntax-variant-template v))))

    ;; 分析差异
    (when (pair? expected-sigs)
      (define first-expected (car expected-sigs))
      (when (= (length actual-signature) (length first-expected))
        ;; 找出不匹配的位置
        (for ([i (in-naturals)]
              [actual (in-list actual-signature)]
              [expected (in-list first-expected)]
              #:unless (operand-type-compatible? actual expected))
          (set! suggestions
                (cons (format "操作数 ~a: 期望 ~a，实际 ~a"
                              (add1 i)
                              expected
                              actual)
                      suggestions))))))

  (reverse suggestions))

;; ============================================================
;; Layer 3: 约束验证
;; ============================================================

;; 从 AST 指令提取操作数具体值 (用于 Layer 3 约束检查)
;; 返回: (listof (cons field-name value))
(define (extract-ast-values ins)
  (match ins
    [(ast-ins _ _ operands _)
     (append-map extract-operand-values operands)]
    [_ '()]))

;; 从单个操作数提取字段值
(define (extract-operand-values op)
  (match op
    ;; 寄存器 -> 提取寄存器编号
    [(ast-reg kind id _ _ _ _ _)
     (define field-name (reg-kind->field-name kind))
     (if (and field-name id)
         (list (cons field-name id))
         '())]
    ;; 立即数 -> 提取值
    [(ast-imm value _)
     (list (cons "imm" value))]
    ;; 内存操作数 -> 提取基址寄存器和偏移
    [(ast-mem base offset index _ _ _)
     (append
      (if (ast-reg? base)
          (extract-operand-values base)
          '())
      (if (ast-imm? offset)
          (list (cons "offset" (ast-imm-value offset)))
          '())
      (if (ast-reg? index)
          (extract-operand-values index)
          '()))]
    [_ '()]))

;; 寄存器类型到字段名的映射
(define (reg-kind->field-name kind)
  (case kind
    [(x w) "Rn"]
    [(b h s d q v) "Vn"]
    [(z) "Zn"]
    [(p) "Pn"]
    [else #f]))

;; 验证操作数约束
;; constraints: hash[field-name -> constraint]
;; values: (listof (cons field-name value))
;; 返回: (listof constraint-violation)
(define (validate-operand-constraints constraints values)
  (for*/list ([pair (in-list values)]
              [field-name (in-value (car pair))]
              [value (in-value (cdr pair))]
              [constraint (in-value (find-matching-constraint constraints field-name))]
              #:when constraint
              #:unless (validate-constraint constraint value))
    (make-violation field-name constraint value)))

;; 查找匹配的约束
(define (find-matching-constraint constraints field-name)
  ;; 尝试精确匹配
  (or (hash-ref constraints field-name #f)
      ;; 尝试模糊匹配 (如 Rn 可匹配 Rd, Rm 等)
      (for/first ([key (in-hash-keys constraints)]
                  #:when (field-name-compatible? field-name key))
        (hash-ref constraints key))))

;; 字段名兼容性检查
(define (field-name-compatible? actual expected)
  (define actual-prefix (substring actual 0 (min 1 (string-length actual))))
  (define expected-prefix (substring expected 0 (min 1 (string-length expected))))
  (string=? actual-prefix expected-prefix))

;; 创建违规记录
(define (make-violation field-name constraint value)
  (define message
    (match constraint
      [(reg-range min max)
       (format "寄存器编号 ~a 超出范围 [~a, ~a]" value min max)]
      [(imm-range min max step)
       (format "立即数 ~a 超出范围 [~a, ~a]" value min max)]
      [(imm-values vals)
       (format "立即数 ~a 不在允许值列表中" value)]
      [(element-size sizes)
       (format "元素大小 ~a 不在允许列表中" value)]
      [_ (format "约束验证失败: ~a = ~a" field-name value)]))
  (constraint-violation field-name constraint value message))

;; Layer 3 诊断 (完整三层验证)
;; constraint-db: hash[encoding-id -> (hash field-name -> constraint)]
(define (diagnose-instruction/layer3 ins variant-db [signature-db #f] [constraint-db #f])
  (match ins
    [(ast-ins mnem _ _ _)
     (define actual-class (classify-instruction ins))
     (define actual-signature (extract-ast-signature ins))
     (define actual-values (extract-ast-values ins))
     (define variants (lookup-variants-by-mnemonic variant-db mnem))

     (cond
       [(null? variants)
        (diagnosis #f mnem actual-class (set)
                   (format "未知指令: ~a" mnem)
                   '() '() actual-signature '() '())]
       [else
        (define allowed-classes
          (for/set ([v (in-list variants)])
            (syntax-variant-syntax-class v)))

        (cond
          [(set-member? allowed-classes actual-class)
           ;; Layer 1 通过，进行 Layer 2 过滤
           (define class-matching
             (filter (λ (v) (eq? (syntax-variant-syntax-class v) actual-class))
                     variants))

           ;; Layer 2: 类型签名过滤
           (define type-matching
             (if signature-db
                 (filter-by-signature class-matching actual-signature signature-db)
                 class-matching))

           (cond
             ;; 有类型匹配的变体
             [(pair? type-matching)
              ;; Layer 3: 约束验证
              (define violations
                (if constraint-db
                    (validate-variants-constraints type-matching actual-values constraint-db)
                    '()))

              (if (null? violations)
                  (diagnosis #t mnem actual-class allowed-classes #f '()
                             class-matching actual-signature type-matching '())
                  (diagnosis #f mnem actual-class allowed-classes
                             (format "~a 约束验证失败" (ast->string ins))
                             (map constraint-violation-message violations)
                             type-matching
                             actual-signature type-matching violations))]
             ;; 类别匹配但类型不匹配
             [else
              (define suggestions
                (generate-type-suggestions actual-signature class-matching signature-db))
              (diagnosis #f mnem actual-class allowed-classes
                         (format "~a 类别匹配 ~a，但操作数类型不匹配"
                                 (ast->string ins)
                                 actual-class)
                         suggestions
                         class-matching
                         actual-signature '() '())])]
          [else
           ;; Layer 1 不匹配
           (define suggestions
             (generate-suggestions actual-class allowed-classes))
           (diagnosis #f mnem actual-class allowed-classes
                      (format "~a 是 ~a，但 ~a 只支持 ~a"
                              (ast->string ins)
                              actual-class
                              mnem
                              (format-class-set allowed-classes))
                      suggestions
                      variants
                      actual-signature '() '())])])]))

;; 验证变体列表中的约束
(define (validate-variants-constraints variants values constraint-db)
  ;; 尝试找到至少一个满足约束的变体
  (define first-violation #f)
  (for/or ([v (in-list variants)])
    (define enc-id (syntax-variant-encoding-id v))
    (define constraints (hash-ref constraint-db enc-id (hash)))
    (define violations (validate-operand-constraints constraints values))
    (cond
      [(null? violations) #t]  ; 找到匹配的变体
      [else
       (unless first-violation
         (set! first-violation violations))
       #f]))
  ;; 如果没有找到匹配的变体，返回第一个违规
  (or first-violation '()))

;; ============================================================
;; 建议生成
;; ============================================================

(define (generate-suggestions actual-class allowed-classes)
  (define actual-pre (get-pre-count actual-class))
  (define actual-post (get-post-count actual-class))
  (define actual-mem? (has-memory? actual-class))
  (define actual-total (+ actual-pre actual-post (if actual-mem? 1 0)))

  (define suggestions '())

  ;; 操作数数量检查
  (define allowed-totals
    (for/list ([c (in-set allowed-classes)])
      (+ (get-pre-count c) (get-post-count c)
         (if (has-memory? c) 1 0))))

  (cond
    [(andmap (λ (t) (> t actual-total)) allowed-totals)
     (set! suggestions (cons "可能少写了操作数" suggestions))]
    [(andmap (λ (t) (< t actual-total)) allowed-totals)
     (set! suggestions (cons "可能多写了操作数" suggestions))])

  ;; 内存操作数检查
  (define any-requires-mem?
    (for/or ([c (in-set allowed-classes)])
      (has-memory? c)))
  (define none-allows-mem? (not any-requires-mem?))

  (cond
    [(and (not actual-mem?) any-requires-mem?)
     (set! suggestions (cons "可能需要内存操作数 (...)" suggestions))]
    [(and actual-mem? none-allows-mem?)
     (set! suggestions (cons "此指令不使用内存操作数" suggestions))])

  (reverse suggestions))

;; ============================================================
;; 格式化
;; ============================================================

(define (format-class-set classes)
  (string-join (sort (map symbol->string (set->list classes)) string<?) "/"))

(define (format-signature sig)
  (string-join (map symbol->string sig) ", "))

(define (format-diagnosis diag [variant-formatter #f])
  (define lines '())

  (define (add-line fmt . args)
    (set! lines (cons (apply format fmt args) lines)))

  (match diag
    [(diagnosis #t mnem actual-class _ _ _ _ actual-sig matched _)
     (add-line "OK: ~a 匹配 ~a" mnem actual-class)
     (when (pair? actual-sig)
       (add-line "  签名: (~a)" (format-signature actual-sig)))
     (when (pair? matched)
       (add-line "  匹配变体: ~a 个" (length matched)))]

    [(diagnosis #f mnem _ _ message suggestions variants actual-sig _ violations)
     (add-line "错误: ~a" message)

     (when (pair? actual-sig)
       (add-line "")
       (add-line "实际签名: (~a)" (format-signature actual-sig)))

     ;; Layer 3 约束违规
     (when (and violations (pair? violations))
       (add-line "")
       (add-line "约束违规:")
       (for ([v violations])
         (add-line "  - ~a" (constraint-violation-message v))))

     (unless (null? variants)
       (add-line "")
       (add-line "~a 支持的形式:" mnem)

       (define by-class (group-variants-by-class variants))
       (for ([(cls vs) (in-hash by-class)])
         (add-line "  ~a:" cls)
         (for ([v (take (reverse vs) (min 3 (length vs)))])
           (add-line "    ~a"
                     (if variant-formatter
                         (variant-formatter v)
                         (syntax-variant-encoding-id v))))
         (when (> (length vs) 3)
           (add-line "    ... 还有 ~a 个变体" (- (length vs) 3)))))

     (unless (null? suggestions)
       (add-line "")
       (add-line "建议:")
       (for ([s suggestions])
         (add-line "  - ~a" s)))])

  (string-join (reverse lines) "\n"))
