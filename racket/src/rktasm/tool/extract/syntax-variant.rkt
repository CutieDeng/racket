#lang racket

(require "loader.rkt"
         "rule-resolver.rkt")

(provide extract-syntax-variant
         extract-syntax-variant?
         extract-syntax-variant-encoding-id
         extract-syntax-variant-operand-names
         extract-syntax-variant-syntax-class
         extract-syntax-variant-template

         build-syntax-variant-db
         build-syntax-variant-db-from-json
         save-syntax-variant-db

         ;; 按大类聚合
         group-by-syntax-class)

;; ============================================================
;; Syntax Variant - 细粒度指令语法 (提取时使用)
;; ============================================================
;;
;; 两层结构:
;;   1. 具体指令变体 -> 细粒度语法 (operand names/types)
;;   2. 细粒度语法 -> 大类别 (cN, cNm, cNmK)
;;
;; 例如:
;;   ADD_64_addsub_shift -> (Xd Xn Xm optional_shift) -> c4
;;   LDR_64_ldst_immpost -> (Xt [Xn] simm) -> c2m1

(struct extract-syntax-variant
  (encoding-id      ; string: "ADD_64_addsub_shift"
   operand-names    ; list: '("XdOrXZR" "XnOrXZR" "XmOrXZR" "optional_shift")
   syntax-class     ; symbol: 'c4
   template)        ; string: "Xd, Xn, Xm, shift"
  #:transparent)

;; ============================================================
;; Extract from JSON
;; ============================================================

(define (build-syntax-variant-db-from-json json-path)
  (define json-data (read-instructions-json json-path))
  (define rules (get-assembly-rules json-data))
  (define a64 (get-a64-instruction-set json-data))
  (build-syntax-variant-db rules a64))

(define (build-syntax-variant-db rules instruction-set)
  (define db (make-hash))

  (define (walk node)
    (match (hash-ref node '_type #f)
      ["Instruction.InstructionSet"
       (for-each walk (hash-ref node 'children '()))]
      ["Instruction.InstructionGroup"
       (for-each walk (hash-ref node 'children '()))]
      ["Instruction.Instruction"
       (process-instruction node)]
      [_ (void)]))

  (define (process-instruction node)
    (define encoding-id (hash-ref node 'name #f))
    (define assembly (hash-ref node 'assembly #f))
    (when (and encoding-id assembly (hash? assembly))
      (define mnemonic (extract-mnemonic rules assembly))
      (when mnemonic
        (define-values (operand-names syntax-class template)
          (analyze-assembly rules assembly))
        (define variant (extract-syntax-variant encoding-id operand-names syntax-class template))
        (hash-update! db mnemonic
                      (lambda (lst) (cons variant lst))
                      '()))))

  (walk instruction-set)

  ;; Reverse to preserve order
  (for ([(k v) (in-hash db)])
    (hash-set! db k (reverse v)))

  db)

;; ============================================================
;; Assembly Analysis
;; ============================================================

;; Returns: (values operand-names syntax-class template)
(define (analyze-assembly rules assembly)
  (define symbols (get-symbol-list assembly))

  ;; Parse symbols to extract operands
  (define-values (operand-names pre-count post-count has-brace-memory? has-real-memory? template-parts)
    (parse-assembly-symbols rules symbols))

  ;; 分类逻辑：
  ;; - cN: N个操作数，无内存
  ;; - cNm: N个操作数 + 1个真实内存
  ;; - cNmK: N个操作数 + 1个真实内存 + K个后操作数
  ;; - cmNm: 1个抽象内存 + N个操作数 + 1个真实内存 (新增)
  ;;
  ;; 注意：当有花括号内存时，花括号后的 COMMA 不计入操作数分隔符
  (define actual-pre-count
    (if has-brace-memory?
        (sub1 pre-count)  ; 花括号后的 COMMA 不算
        pre-count))

  (define syntax-class
    (cond
      ;; 双内存情况: {ZA...[...]} + Pg + [XnSP...]
      [(and has-brace-memory? has-real-memory?)
       (string->symbol (format "cm~am" actual-pre-count))]
      ;; 只有真实内存
      [has-real-memory?
       (if (= post-count 0)
           (string->symbol (format "c~am" pre-count))
           (string->symbol (format "c~am~a" pre-count post-count)))]
      ;; 无内存
      [else
       (string->symbol (format "c~a" pre-count))]))

  (define template (string-join (filter string? template-parts) ", "))

  (values operand-names syntax-class template))

;; Parse assembly symbols
;; Returns: (values operand-names pre-count post-count brace-memory? real-memory? template-parts)
(define (parse-assembly-symbols rules symbols)
  ;; 首先展开所有符号（递归展开 RuleReference）
  (define flat-symbols (flatten-symbols rules symbols))

  ;; 'mnemonic: 助记符阶段（SPACE 之前）
  ;; 'before: 内存操作数之前
  ;; 'in-bracket: 在 [...] 内
  ;; 'in-brace: 在 {...} 内
  ;; 'in-brace-index: 在花括号内的 [...] 内
  ;; 'in-index: 在元素索引 [...] 内
  ;; 'after: 内存操作数之后
  (define state 'mnemonic)
  (define operand-names '())
  (define template-parts '())
  (define comma-before 0)
  (define comma-after 0)
  (define has-memory? #f)       ; 真实内存 [XnSP ...]
  (define has-brace-memory? #f) ; 花括号内的抽象内存 {ZA0H.B[Ws, offs]}
  (define has-space? #f)
  (define current-group-parts '())  ; For [...] or {...}
  (define brace-index-parts '())    ; For [...] inside {...}
  (define current-operand-parts '()) ; 当前操作数的组成部分（用于合并连续的规则引用）

  (define prev-was-comma? #f)  ; Track if previous token was COMMA

  ;; 辅助函数：结束当前操作数，合并到 template
  (define (finish-current-operand)
    (when (pair? current-operand-parts)
      (define merged (string-join (reverse current-operand-parts) ""))
      (set! template-parts (append template-parts (list merged)))
      (set! current-operand-parts '())))

  (for ([sym (in-list flat-symbols)])
    (match sym
      [(list 'literal val)
       (cond
         ;; 助记符阶段，忽略字面量
         [(eq? state 'mnemonic)
          (void)]
         ;; 处理以 [ 结尾的字面量（如 ".B["）在花括号内
         [(and (string-suffix? val "[") (eq? state 'in-brace))
          (define prefix (substring val 0 (sub1 (string-length val))))
          (set! current-group-parts (cons prefix current-group-parts))
          (set! state 'in-brace-index)
          (set! has-brace-memory? #t)
          (set! brace-index-parts '())]
         ;; Memory operand [...] - only if preceded by COMMA
         [(and (string=? val "[") prev-was-comma?)
          (finish-current-operand)
          (set! state 'in-bracket)
          (set! has-memory? #t)
          (set! current-group-parts '())]
         ;; Element index [...] - not preceded by COMMA, append to current operand
         [(and (string=? val "[") (not prev-was-comma?) (eq? state 'before))
          (set! state 'in-index)
          (set! current-group-parts '())]
         [(string=? val "]")
          (cond
            [(eq? state 'in-bracket)
             ;; Memory operand
             (define mem-str (string-join (filter identity (reverse current-group-parts)) " "))
             (set! template-parts (append template-parts (list (format "[~a]" mem-str))))
             (set! state 'after)]
            [(eq? state 'in-index)
             ;; Element index - append to current operand parts
             (define idx-str (string-join (filter identity (reverse current-group-parts)) " "))
             (set! current-operand-parts (cons (format "[~a]" idx-str) current-operand-parts))
             (set! state 'before)]
            [(eq? state 'in-brace-index)
             ;; 花括号内的索引结束，将 [Ws offs] 添加到 group-parts
             (define idx-str (string-join (filter identity (reverse brace-index-parts)) " "))
             (set! current-group-parts (cons (format "[~a]" idx-str) current-group-parts))
             (set! state 'in-brace)])]
         ;; Register group {...}
         [(string=? val "{")
          (finish-current-operand)
          (set! state 'in-brace)
          (set! current-group-parts '())]
         [(string=? val "}")
          (define grp-str (string-join (filter identity (reverse current-group-parts)) " "))
          (set! template-parts (append template-parts (list (format "{~a}" grp-str))))
          (set! state 'before)]
         ;; Other literals
         [(eq? state 'in-brace-index)
          (unless (string=? val ",")
            (set! brace-index-parts (cons val brace-index-parts)))]
         [(member state '(in-bracket in-brace in-index))
          (unless (string=? val ",")
            (set! current-group-parts (cons val current-group-parts)))]
         ;; Shift/extend 关键字作为独立操作数
         [(and (member state '(before after))
               (member val '("LSL" "LSR" "ASR" "ROR" "MSL"
                             "UXTB" "UXTH" "UXTW" "UXTX"
                             "SXTB" "SXTH" "SXTW" "SXTX")))
          ;; 先结束当前操作数（如果有的话）
          (finish-current-operand)
          ;; 把 shift/extend 作为独立操作数
          (set! template-parts (append template-parts (list val)))
          ;; 增加一次计数，为后面的 amount 准备（作为隐式分隔）
          (when (eq? state 'before)
            (set! comma-before (add1 comma-before)))
          (when (eq? state 'after)
            (set! comma-after (add1 comma-after)))]
         ;; 普通字面量（如 "."）加入当前操作数
         [(eq? state 'before)
          (set! current-operand-parts (cons val current-operand-parts))]
         [(eq? state 'after)
          (set! current-operand-parts (cons val current-operand-parts))])
       (set! prev-was-comma? #f)]

      [(list 'rule rule-id)
       (cond
         [(equal? rule-id "SPACE")
          (set! has-space? #t)
          ;; SPACE 标志着助记符结束，开始操作数
          (when (eq? state 'mnemonic)
            (set! state 'before))]
         [(equal? rule-id "COMMA")
          (set! prev-was-comma? #t)
          ;; 遇到 COMMA，结束当前操作数
          (finish-current-operand)
          (case state
            [(before) (set! comma-before (add1 comma-before))]
            [(after) (set! comma-after (add1 comma-after))])]
         ;; hash 本身不作为分隔符，跳过
         [(equal? rule-id "hash")
          (void)]
         ;; 助记符阶段，忽略规则引用
         [(eq? state 'mnemonic)
          (void)]
         [(and rule-id (not (member rule-id '("SPACE" "COMMA" "hash" "OPT_SPACE"))))
          (set! prev-was-comma? #f)
          ;; This is an operand part
          (define name (simplify-operand-name rule-id))
          (when name
            (set! operand-names (cons name operand-names))
            (case state
              [(before after)
               ;; 加入当前操作数的组成部分
               (set! current-operand-parts (cons name current-operand-parts))]
              [(in-bracket in-brace in-index)
               (set! current-group-parts (cons name current-group-parts))]
              [(in-brace-index)
               (set! brace-index-parts (cons name brace-index-parts))]))])]
      [_ (void)]))

  ;; 结束最后一个操作数
  (finish-current-operand)

  ;; 计算内存前的操作数数量
  ;; 如果有内存: pre_count = comma_before (最后一个COMMA连接内存)
  ;; 如果无内存: operand_count = comma + 1
  (define pre-count
    (cond
      [(not has-space?) 0]
      [has-memory? comma-before]
      [else (add1 comma-before)]))

  (values (filter identity (reverse operand-names))
          pre-count
          comma-after
          has-brace-memory?
          has-memory?
          template-parts))

;; ============================================================
;; Symbol Flattening - 递归展开规则引用
;; ============================================================

;; 将符号列表展开为扁平的 (type value) 列表
;; 返回: (listof (list 'literal string) | (list 'rule string))
(define (flatten-symbols rules symbols)
  (append-map (lambda (sym) (flatten-symbol rules sym '())) symbols))

;; 展开单个符号
;; visited: 已访问的规则 ID，防止无限递归
(define (flatten-symbol rules sym visited)
  (match (hash-ref sym '_type #f)
    ["Instruction.Symbols.Literal"
     (list (list 'literal (hash-ref sym 'value "")))]

    ["Instruction.Symbols.RuleReference"
     (define rule-id (hash-ref sym 'rule_id #f))
     (cond
       ;; 基础规则，不展开
       [(member rule-id '("SPACE" "COMMA" "OPT_SPACE" "hash"))
        (list (list 'rule rule-id))]
       ;; 防止无限递归
       [(member rule-id visited)
        (list (list 'rule rule-id))]
       ;; 需要展开的规则
       [rule-id
        (expand-rule rules rule-id (cons rule-id visited))]
       [else '()])]

    ["Instruction.Symbols.Optional"
     ;; 可选符号，展开其内部
     (define inner-symbols (get-symbol-list-from-optional sym))
     (append-map (lambda (s) (flatten-symbol rules s visited)) inner-symbols)]

    ["Instruction.Symbols.Whitespace"
     '()]

    [_ '()]))

;; 展开一个规则
(define (expand-rule rules rule-id visited)
  (define key (if (string? rule-id) (string->symbol rule-id) rule-id))
  (define rule (hash-ref rules key #f))

  (cond
    [(not rule)
     ;; 规则不存在，作为终结符返回
     (list (list 'rule (if (symbol? rule-id) (symbol->string rule-id) rule-id)))]

    [else
     (match (hash-ref rule '_type #f)
       ;; Token: 终结符
       ["Instruction.Rules.Token"
        (list (list 'rule (if (symbol? rule-id) (symbol->string rule-id) rule-id)))]

       ;; Rule: 序列规则，展开其 symbols
       ["Instruction.Rules.Rule"
        (define symbols (get-rule-symbols rule))
        (append-map (lambda (s) (flatten-symbol rules s visited)) symbols)]

       ;; Choice: 选择规则，取第一个非空分支展开
       ["Instruction.Rules.Choice"
        (define choices (hash-ref rule 'choices '()))
        (if (pair? choices)
            ;; 展开第一个 choice
            (let ([first-choice (car choices)])
              (define symbols (get-symbol-list first-choice))
              (append-map (lambda (s) (flatten-symbol rules s visited)) symbols))
            (list (list 'rule (if (symbol? rule-id) (symbol->string rule-id) rule-id))))]

       [_
        (list (list 'rule (if (symbol? rule-id) (symbol->string rule-id) rule-id)))])]))

;; 从 Rule 节点获取 symbols
(define (get-rule-symbols rule)
  (define symbols (hash-ref rule 'symbols #f))
  (cond
    [(list? symbols) symbols]
    [(and (hash? symbols) (hash-ref symbols 'symbols #f)) => identity]
    [else '()]))

;; 从 Optional 节点获取内部 symbols
(define (get-symbol-list-from-optional opt)
  (define symbols (hash-ref opt 'symbols #f))
  (cond
    [(list? symbols) symbols]
    [(and (hash? symbols) (hash-ref symbols 'symbols #f)) => identity]
    [else '()]))

;; Simplify operand name for display
(define (simplify-operand-name name)
  ;; Remove noise
  (define step1 (regexp-replace* #rx"__[0-9]+$" name ""))
  (define step2 (regexp-replace* #rx"OrXZR|OrWZR|OrXSP|OrWSP|_option" step1 ""))
  (define step3 (regexp-replace* #rx"^optional_" step2 "["))
  (define step4 (if (string-prefix? step3 "[")
                    (string-append step3 "]")
                    step3))
  ;; Filter out noise tokens
  (if (member step4 '("OPT_SPACE" "T" "COMMA" "hash" "" "R" "fpfar"))
      #f
      step4))

;; ============================================================
;; Helpers
;; ============================================================

(define (get-symbol-list assembly)
  (define symbols (hash-ref assembly 'symbols #f))
  (cond
    [(list? symbols) symbols]
    [(and (hash? symbols) (hash-ref symbols 'symbols #f)) => identity]
    [else '()]))

(define (extract-mnemonic rules assembly)
  (define symbols (get-symbol-list assembly))
  (and (pair? symbols)
       (let ([first-sym (car symbols)])
         (match (hash-ref first-sym '_type #f)
           ["Instruction.Symbols.Literal"
            (string->symbol (string-downcase (hash-ref first-sym 'value "")))]
           ["Instruction.Symbols.RuleReference"
            (define rule-id (hash-ref first-sym 'rule_id #f))
            (and rule-id
                 (let ([resolved (resolve-rule rules rule-id)])
                   (and (resolved-token? resolved)
                        (string->symbol
                         (string-downcase (resolved-token-pattern resolved))))))]
           [_ #f]))))

;; ============================================================
;; Grouping & Output
;; ============================================================

;; Group variants by syntax class
(define (group-by-syntax-class variants)
  (define groups (make-hash))
  (for ([v (in-list variants)])
    (hash-update! groups (extract-syntax-variant-syntax-class v)
                  (lambda (lst) (cons v lst))
                  '()))
  (for ([(k v) (in-hash groups)])
    (hash-set! groups k (reverse v)))
  groups)

;; Save two-layer mapping:
;;   1. instruction-variants.rktd: (encoding-id syntax-variant-id)
;;   2. variant-class.rktd: (syntax-variant-id syntax-class)
(define (save-syntax-variant-db db dir)
  ;; Collect all variants and assign IDs based on operand pattern
  (define variant-to-class (make-hash))  ; variant-id -> class
  (define instruction-to-variant '())     ; (encoding-id . variant-id)

  (for* ([variants (in-hash-values db)]
         [v (in-list variants)])
    (define variant-id (extract-syntax-variant-template v))
    (define encoding-id (extract-syntax-variant-encoding-id v))
    (define cls (extract-syntax-variant-syntax-class v))

    ;; Record instruction -> variant
    (set! instruction-to-variant
          (cons (list encoding-id variant-id)
                instruction-to-variant))

    ;; Record variant -> class (may have duplicates, that's ok)
    (hash-set! variant-to-class variant-id cls))

  ;; Layer 1: 具体指令 -> 语法变体
  (call-with-output-file (build-path dir "instruction-variants.rktd")
    (lambda (out)
      (fprintf out ";; 具体指令 -> 语法变体\n")
      (fprintf out ";; (encoding-id syntax-variant)\n\n")
      (for ([pair (sort instruction-to-variant string<? #:key car)])
        (fprintf out "~s\n" pair)))
    #:exists 'replace)

  ;; Layer 2: 语法变体 -> 大类
  (call-with-output-file (build-path dir "variant-class.rktd")
    (lambda (out)
      (fprintf out ";; 语法变体 -> 大类\n")
      (fprintf out ";; (syntax-variant syntax-class)\n\n")
      (for ([(variant-id cls) (in-hash variant-to-class)])
        (fprintf out "~s\n" (list variant-id cls))))
    #:exists 'replace)

  (printf "已保存:\n")
  (printf "  ~a/instruction-variants.rktd (~a 条指令)\n"
          dir (length instruction-to-variant))
  (printf "  ~a/variant-class.rktd (~a 种变体)\n"
          dir (hash-count variant-to-class)))
