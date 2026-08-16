#!/usr/bin/env racket
#lang racket

;; ============================================================
;; gen-alias-signatures.rkt
;; 生成: data/alias-signatures.rktd
;;       data/alias-transforms.rktd
;;       data/alias-map.rktd
;; ============================================================
;;
;; 从 MRS Instructions.json 自动提取别名定义
;;
;; 数据来源:
;; 1. MRS InstructionAlias 节点: 别名定义及其目标指令
;; 2. instruction-spec.rktd: 指令签名信息

(require racket/cmdline
         racket/match
         racket/string
         json)

;; ============================================================
;; 配置
;; ============================================================

(define mrs-json-path
  (make-parameter "AARCHMRS_OPENSOURCE_A_profile_FAT-2025-12/Instructions.json"))
(define spec-path
  (make-parameter "syntax/data/generated/instruction-spec.rktd"))
(define sig-output (make-parameter "syntax/data/alias-signatures.rktd"))
(define transform-output (make-parameter "syntax/data/alias-transforms.rktd"))
(define map-output (make-parameter "syntax/data/alias-map.rktd"))

;; ============================================================
;; 从 MRS JSON 提取别名
;; ============================================================

;; 递归遍历 JSON 查找所有 InstructionAlias 节点
(define (extract-aliases-from-json json-data)
  (define result '())

  (define (walk node parent-instruction)
    (cond
      [(hash? node)
       (define node-type (hash-ref node '_type #f))

       ;; 更新父指令
       (define new-parent
         (if (equal? node-type "Instruction.Instruction")
             (hash-ref node 'name #f)
             parent-instruction))

       ;; 如果是别名节点，收集信息
       (when (equal? node-type "Instruction.InstructionAlias")
         (define alias-info
           (hash 'name (hash-ref node 'name #f)
                 'parent new-parent
                 'operation_id (hash-ref node 'operation_id #f)
                 'assembly (hash-ref node 'assembly #f)
                 'preferred (hash-ref node 'preferred #f)
                 '_meta (hash-ref node '_meta #f)))
         (set! result (cons alias-info result)))

       ;; 递归遍历子节点
       (for ([v (in-hash-values node)])
         (walk v new-parent))]

      [(list? node)
       (for ([v (in-list node)])
         (walk v parent-instruction))]

      [else (void)]))

  (walk json-data #f)
  result)

;; 从 assembly.symbols 提取助记符
(define (extract-mnemonic-from-assembly assembly)
  (define symbols (hash-ref assembly 'symbols '()))
  (for/or ([sym (in-list symbols)])
    (and (hash? sym)
         (equal? (hash-ref sym '_type #f) "Instruction.Symbols.Literal")
         (let ([v (hash-ref sym 'value #f)])
           (and v (regexp-match? #rx"^[A-Za-z]" v)
                (string-downcase v))))))

;; 从 assembly.symbols 提取签名模板
(define (extract-template-from-assembly assembly)
  (define symbols (hash-ref assembly 'symbols '()))
  (define parts '())

  (for ([sym (in-list symbols)])
    (when (hash? sym)
      (define sym-type (hash-ref sym '_type #f))
      (cond
        [(equal? sym-type "Instruction.Symbols.RuleReference")
         (define rule-id (hash-ref sym 'rule_id #f))
         (when (and rule-id
                    (not (member rule-id '("SPACE" "OPT_SPACE" "COMMA"))))
           (set! parts (cons rule-id parts)))]
        [(equal? sym-type "Instruction.Symbols.Literal")
         (define v (hash-ref sym 'value #f))
         ;; 收集元素大小后缀 (.B, .H, .S, .D, .Q)
         (when (and v (regexp-match? #rx"^\\.[BHSDQ]$" v))
           (set! parts (cons v parts)))])))

  (reverse parts))

;; 从别名 assembly 解析操作数签名
(define (parse-alias-assembly-signature assembly)
  (define symbols (hash-ref assembly 'symbols '()))
  (define operands '())

  (for ([sym (in-list symbols)])
    (when (hash? sym)
      (define sym-type (hash-ref sym '_type #f))
      (when (equal? sym-type "Instruction.Symbols.RuleReference")
        (define rule-id (hash-ref sym 'rule_id #f))
        (when (and rule-id
                   ;; 忽略 optional_ 开头的规则（可选移位/扩展不计入签名）
                   (not (regexp-match? #rx"^optional_" rule-id)))
          (cond
            ;; GPR
            [(regexp-match? #rx"^[WX]" rule-id)
             (define size (if (regexp-match? #rx"^W" rule-id) 'gpr-32 'gpr-64))
             (set! operands (cons size operands))]
            [(regexp-match? #rx"^R" rule-id)
             (set! operands (cons 'gpr-64 operands))]
            ;; SVE Z register
            [(regexp-match? #rx"^Z" rule-id)
             (set! operands (cons 'sve-z operands))]
            ;; SVE P register
            [(regexp-match? #rx"^P" rule-id)
             (set! operands (cons 'sve-p operands))]
            ;; SIMD V register
            [(regexp-match? #rx"^V" rule-id)
             (set! operands (cons 'simd-v operands))]
            ;; Immediate (不包括 hash，因为它只是 # 前缀)
            [(or (regexp-match? #rx"^imm" rule-id)
                 (regexp-match? #rx"^const" rule-id)
                 (regexp-match? #rx"^offs" rule-id))
             (set! operands (cons 'immediate operands))]
            ;; Shift/extend (非可选的)
            [(regexp-match? #rx"shift" rule-id)
             (set! operands (cons 'keyword operands))]
            ;; Condition code
            [(regexp-match? #rx"^cond" rule-id)
             (set! operands (cons 'cond-code operands))])))))

  (reverse operands))

;; ============================================================
;; 从模板提取操作数名称列表
;; ============================================================

;; 从模板字符串提取操作数名称
;; 例如: "Xd, Xn, Xm" -> ("Xd" "Xn" "Xm")
;; 例如: "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" -> ("P" "P" "P" "P")
(define (extract-operand-names-from-template template)
  (define parts (string-split template ", "))
  (for/list ([p (in-list parts)])
    (define p-trimmed (string-trim p))
    (cond
      ;; GPR: Xd, Wn, etc.
      [(regexp-match #rx"^([WX][a-z]+)" p-trimmed) => (λ (m) (cadr m))]
      ;; Predicate with /M or /Z: PUInteger/M -> Pg
      [(regexp-match #rx"^P[A-Z][a-z]*/([MZ])" p-trimmed) => (λ (m) "Pg")]
      ;; Predicate: PUInteger.B -> P
      [(regexp-match? #rx"^P" p-trimmed) "P"]
      ;; SVE Z register: ZUInteger.B -> Z
      [(regexp-match? #rx"^Z" p-trimmed) "Z"]
      ;; SIMD V register
      [(regexp-match? #rx"^V" p-trimmed) "V"]
      ;; Immediate
      [(regexp-match? #rx"^#|^UInteger|Integer" p-trimmed) "imm"]
      [else p-trimmed])))

;; ============================================================
;; 从 _meta.encoded_in 构建转换映射
;; ============================================================

;; 从 _meta.encoded_in 提取别名操作数到编码字段的映射
;; encoded_in: hash like { <Pd>: [{_type: AST.Identifier, value: "Pd"}], ... }
;; 返回: hash like { "Rd" -> "Xd", ... } (编码字段名 -> 别名操作数名)
(define (extract-encoded-in-mapping meta)
  (define result (make-hash))
  (when (hash? meta)
    (define encoded-in (hash-ref meta 'encoded_in #f))
    (when (hash? encoded-in)
      (for ([(field-key exprs) (in-hash encoded-in)])
        ;; field-key 是像 '<Xd>' 这样的符号
        (define alias-operand-name
          (let ([s (symbol->string field-key)])
            (if (and (string-prefix? s "<") (string-suffix? s ">"))
                (substring s 1 (- (string-length s) 1))
                s)))
        ;; exprs 是一个表达式列表，通常只有一个 Identifier (编码字段名)
        (when (list? exprs)
          (for ([expr exprs])
            (when (and (hash? expr)
                       (equal? (hash-ref expr '_type #f) "AST.Identifier"))
              (define encoding-field (hash-ref expr 'value #f))
              (when encoding-field
                ;; 映射: 编码字段名 -> 别名操作数名
                (hash-set! result encoding-field alias-operand-name))))))))
  result)

;; 从别名 assembly 提取别名操作数名称
;; 例如: MOV Pd.B, Pn.B -> ("Pd" "Pn")
;; 规则ID如 "XdOrXZR__6" 应该提取为 "Xd"
(define (extract-alias-operand-names assembly)
  (define symbols (hash-ref assembly 'symbols '()))
  (define names '())
  (for ([sym (in-list symbols)])
    (when (hash? sym)
      (define sym-type (hash-ref sym '_type #f))
      (when (equal? sym-type "Instruction.Symbols.RuleReference")
        (define rule-id (hash-ref sym 'rule_id #f))
        (when (and rule-id
                   (not (member rule-id '("SPACE" "OPT_SPACE" "COMMA")))
                   ;; 忽略 optional_ 开头的规则（可选移位/扩展）
                   (not (regexp-match? #rx"^optional_" rule-id)))
          ;; 提取核心寄存器名称
          ;; "XdOrXZR__6" -> "Xd"
          ;; "Pn__3" -> "Pn"
          ;; "ZUInteger" -> "Z"
          (define base-name
            (cond
              ;; 处理 XdOrXZR, WdOrWZR 等形式 -> Xd, Wd
              [(regexp-match #rx"^([XW][a-z]+)Or" rule-id)
               => (λ (m) (cadr m))]
              ;; 处理 Pd, Pn__3 等形式 -> Pd, Pn
              [(regexp-match #rx"^(P[a-z]+)" rule-id)
               => (λ (m) (cadr m))]
              ;; 处理 Zd, Zn 等形式
              [(regexp-match #rx"^(Z[a-z]+)" rule-id)
               => (λ (m) (cadr m))]
              ;; 处理 Xd, Xn, Wm 等基本形式
              [(regexp-match #rx"^([XW][a-z]+)" rule-id)
               => (λ (m) (cadr m))]
              ;; 默认：取第一个大写字母后跟可选小写字母的部分
              [(regexp-match #rx"^([A-Z][a-z]*)" rule-id)
               => (λ (m) (cadr m))]
              [else rule-id]))
          (set! names (cons base-name names))))))
  (reverse names))

;; 从约束列表中提取编码字段名顺序
;; constraints: (("Rd" ...) ("Rn" ...) ...)
;; 返回: ("Rd" "Rn" ...)
(define (extract-constraint-field-order constraints)
  (for/list ([c (in-list constraints)])
    (if (pair? c) (car c) c)))

;; 从约束列表中查找字段名
(define (find-field-in-constraints constraints field-name)
  (for/or ([c (in-list constraints)])
    (and (pair? c)
         (string=? (car c) field-name))))

;; 根据目标模板和 _meta.encoded_in 计算转换规则
;; 返回: 转换规则列表，例如 (0 (zr 64) 1 (const lsl) (const 0))
(define (compute-transform alias-operand-names target-template encoded-in-mapping spec-db parent-enc-id)
  (define target-info (hash-ref spec-db parent-enc-id #f))
  (unless target-info
    (return (for/list ([i (in-range (length alias-operand-names))]) i)))

  (define template (hash-ref target-info 'template ""))
  (define target-parts (string-split template ", "))
  (define constraints (hash-ref target-info 'constraints '()))

  ;; 构建别名操作数名到索引的映射
  (define alias-name->index (make-hash))
  (for ([name (in-list alias-operand-names)]
        [i (in-naturals)])
    ;; 存储多种可能的名称形式
    (hash-set! alias-name->index name i)
    (hash-set! alias-name->index (string-upcase name) i)
    ;; 也存储去掉首字母的形式 (Xd -> d, Pd -> d)
    (when (> (string-length name) 1)
      (hash-set! alias-name->index (substring name 1) i)))

  ;; ARM64 标准操作数位置命名约定:
  ;; - 位置 0: Rd/Pd/Zd (目标)
  ;; - 位置 1: Rn/Pn/Zn (第一个源) 或 Pg (谓词)
  ;; - 位置 2: Rm/Pm/Zm (第二个源)
  ;; - 位置 3+: 移位/扩展/立即数

  ;; 检测寄存器宽度 (32 或 64)
  (define reg-width
    (cond
      [(for/or ([name alias-operand-names])
         (regexp-match? #rx"^[XZ]" name)) 64]
      [else 32]))

  ;; 为每个目标操作数位置找到对应的别名操作数索引或常量
  (for/list ([i (in-naturals)]
             [target-part (in-list target-parts)])
    (define target-part-trimmed (string-trim target-part))

    ;; 根据位置推断可能的字段名
    (define inferred-field-names
      (cond
        ;; GPR/预测指令的标准位置
        [(= i 0) '("Rd" "Pd" "Zd" "Zdn" "Xd" "Wd")]
        [(= i 1) '("Rn" "Pn" "Zn" "Pg" "Xn" "Wn")]
        [(= i 2) '("Rm" "Pm" "Zm" "Xm" "Wm")]
        [(= i 3) '("Ra" "Pk" "shift" "Pa")]
        [else '()]))

    ;; 在 encoded_in 映射中查找这些字段是否有对应的别名操作数
    (define alias-op-name
      (for/or ([field-name (in-list inferred-field-names)])
        (hash-ref encoded-in-mapping field-name #f)))

    (cond
      ;; 找到了别名操作数映射
      [alias-op-name
       (define idx (hash-ref alias-name->index alias-op-name #f))
       (cond
         ;; 成功找到别名操作数索引
         [idx idx]
         ;; 映射存在但不在别名操作数中 - 检查目标部分类型或映射值本身
         ;; 移位类型 (LSL, LSR, ASR, ROR) - 检查 target-part 或 alias-op-name
         [(or (member target-part-trimmed '("LSL" "LSR" "ASR" "ROR"))
              (member alias-op-name '("LSL" "LSR" "ASR" "ROR")))
          (list 'const (string->symbol (string-downcase
            (if (member target-part-trimmed '("LSL" "LSR" "ASR" "ROR"))
                target-part-trimmed
                alias-op-name))))]
         ;; 立即数 (UInteger 等通常是 0)
         [(or (regexp-match? #rx"^UInteger|^Integer|^#" target-part-trimmed)
              (regexp-match? #rx"^[0-9]+$" alias-op-name))
          (list 'const 0)]
         ;; 回退默认值
         [else 0])]

      ;; 零寄存器 (XZR, WZR) - 只有当 encoded_in 没有映射时才使用
      [(regexp-match? #rx"^XZR|^WZR" target-part-trimmed)
       (list 'zr reg-width)]

      ;; 移位类型 (LSL, LSR, ASR, ROR)
      [(member target-part-trimmed '("LSL" "LSR" "ASR" "ROR"))
       (list 'const (string->symbol (string-downcase target-part-trimmed)))]

      ;; 立即数 (UInteger 等通常是 0)
      [(regexp-match? #rx"^UInteger|^Integer|^#" target-part-trimmed)
       (list 'const 0)]

      ;; P 寄存器 (谓词) - 检查是否在 encoded_in 中
      [(regexp-match? #rx"^P" target-part-trimmed)
       (define possible-fields
         (list (format "P~a" (case i [(0) "d"] [(1) "g"] [(2) "n"] [(3) "m"] [else "a"]))
               (format "P~a" i)))
       (define op-name
         (for/or ([f possible-fields])
           (hash-ref encoded-in-mapping f #f)))
       (if op-name
           (or (hash-ref alias-name->index op-name #f) 0)
           ;; 没找到映射，可能是固定的谓词源 - 使用最后一个别名操作数
           (max 0 (sub1 (length alias-operand-names))))]

      ;; Z 寄存器 (SVE)
      [(regexp-match? #rx"^Z" target-part-trimmed)
       (define possible-fields
         (list (format "Z~a" (case i [(0) "d"] [(1) "n"] [(2) "m"] [(3) "a"] [else "t"]))
               (format "Zd~a" (if (= i 0) "n" ""))
               (format "Z~a" i)))
       (define op-name
         (for/or ([f possible-fields])
           (hash-ref encoded-in-mapping f #f)))
       (if op-name
           (or (hash-ref alias-name->index op-name #f) 0)
           ;; 没找到，使用位置匹配
           (min i (max 0 (sub1 (length alias-operand-names)))))]

      ;; 默认: 根据类型匹配
      [else
       (define best-match
         (for/first ([j (in-naturals)]
                     [name (in-list alias-operand-names)]
                     #:when (or (and (regexp-match? #rx"^[XW]" target-part-trimmed)
                                     (regexp-match? #rx"^[XW]" name))
                                (and (regexp-match? #rx"^P" target-part-trimmed)
                                     (regexp-match? #rx"^P" name))
                                (and (regexp-match? #rx"^Z" target-part-trimmed)
                                     (regexp-match? #rx"^Z" name))))
           j))
       (cond
         ;; 找到了类型匹配的别名操作数
         [best-match best-match]
         ;; 没有匹配，且目标是移位类型 -> 使用默认 LSL
         [(member target-part-trimmed '("LSL" "LSR" "ASR" "ROR" "lsl" "lsr" "asr" "ror"))
          (list 'const 'lsl)]
         ;; 没有匹配，且目标是立即数 -> 使用默认 0
         [(regexp-match? #rx"^UInteger|^Integer|^#|imm" target-part-trimmed)
          (list 'const 0)]
         ;; 其他情况：避免越界，使用常量 0
         [(>= i (length alias-operand-names))
          (list 'const 0)]
         ;; 回退到位置匹配
         [else i])])))

;; ============================================================
;; 加载指令规范
;; ============================================================

(define (load-instruction-spec path)
  (define result (make-hash))
  (when (file-exists? path)
    (with-input-from-file path
      (lambda ()
        (let loop ()
          (define datum (read))
          (unless (eof-object? datum)
            (match datum
              ;; 5 元素格式: (enc-id mnem template constraints operand-fields)
              [(list enc-id mnem template constraints operand-fields)
               (hash-set! result enc-id
                          (hash 'mnem mnem
                                'template template
                                'constraints constraints
                                'operand-fields operand-fields))]
              ;; 4 元素格式 (旧格式兼容)
              [(list enc-id mnem template constraints)
               (hash-set! result enc-id
                          (hash 'mnem mnem
                                'template template
                                'constraints constraints))]
              [_ (void)])
            (loop))))))
  result)

;; ============================================================
;; 解析模板为签名类型
;; ============================================================

;; 模板元素到操作数类型的映射
(define (template-element->operand-type elem)
  (cond
    ;; GPR
    [(regexp-match? #rx"^[WX]d" elem) 'gpr]
    [(regexp-match? #rx"^[WX]n" elem) 'gpr]
    [(regexp-match? #rx"^[WX]m" elem) 'gpr]
    [(regexp-match? #rx"^[WX]t" elem) 'gpr]
    [(regexp-match? #rx"^[WX]a" elem) 'gpr]
    [(regexp-match? #rx"^R" elem) 'gpr]
    ;; SVE Z 寄存器
    [(regexp-match? #rx"^Z" elem) 'sve-z]
    ;; SVE P 寄存器
    [(regexp-match? #rx"^P" elem) 'sve-p]
    ;; SIMD V 寄存器
    [(regexp-match? #rx"^V" elem) 'simd-v]
    ;; 立即数
    [(regexp-match? #rx"^imm" elem) 'immediate]
    [(regexp-match? #rx"^#" elem) 'immediate]
    [(regexp-match? #rx"^hash" elem) 'immediate]
    [(regexp-match? #rx"^const" elem) 'immediate]
    ;; 移位/扩展
    [(regexp-match? #rx"shift" elem) 'shift]
    [(regexp-match? #rx"extend" elem) 'extend]
    ;; 条件码
    [(regexp-match? #rx"^cond" elem) 'cond-code]
    ;; 元素大小后缀
    [(regexp-match? #rx"^\\.([BHSDQ])$" elem) 'element-suffix]
    ;; 其他
    [else #f]))

;; 解析模板字符串为签名
(define (parse-template-to-signature template-str)
  (define parts (string-split template-str ", "))
  (define types
    (for/list ([p (in-list parts)])
      (define p-trimmed (string-trim p))
      (cond
        ;; GPR with size
        [(regexp-match? #rx"^[WX]" p-trimmed)
         (if (regexp-match? #rx"^W" p-trimmed) 'gpr-32 'gpr-64)]
        ;; SVE Z register
        [(regexp-match? #rx"^Z" p-trimmed) 'sve-z]
        ;; SVE P register
        [(regexp-match? #rx"^P" p-trimmed) 'sve-p]
        ;; SIMD V register
        [(regexp-match? #rx"^V" p-trimmed) 'simd-v]
        ;; Immediate
        [(or (regexp-match? #rx"^#" p-trimmed)
             (regexp-match? #rx"^UInteger" p-trimmed)
             (regexp-match? #rx"Integer" p-trimmed))
         'immediate]
        ;; Shift/extend keyword
        [(regexp-match? #rx"(lsl|lsr|asr|ror|sxt|uxt)" (string-downcase p-trimmed))
         'keyword]
        ;; Condition code
        [(regexp-match? #rx"^(EQ|NE|CS|HS|CC|LO|MI|PL|VS|VC|HI|LS|GE|LT|GT|LE|AL|NV)" p-trimmed)
         'cond-code]
        [else 'unknown])))
  (filter (lambda (t) (not (eq? t 'unknown))) types))

;; ============================================================
;; 构建别名数据库
;; ============================================================

(define (build-alias-database)
  (define aliases (make-hash))

  ;; 加载 MRS JSON
  (unless (file-exists? (mrs-json-path))
    (printf "警告: MRS JSON 文件不存在: ~a\n" (mrs-json-path))
    (return aliases))

  (printf "  加载 MRS JSON...\n")
  (define json-data
    (with-input-from-file (mrs-json-path)
      (lambda () (read-json))))

  ;; 提取所有别名
  (printf "  提取别名定义...\n")
  (define alias-nodes (extract-aliases-from-json json-data))
  (printf "  找到 ~a 个别名\n" (length alias-nodes))

  ;; 加载指令规范
  (printf "  加载指令规范...\n")
  (define spec-db (load-instruction-spec (spec-path)))
  (printf "  指令规范条目: ~a\n" (hash-count spec-db))

  ;; 处理每个别名
  (for ([alias-info (in-list alias-nodes)])
    (define alias-name (hash-ref alias-info 'name #f))
    (define parent-enc-id (hash-ref alias-info 'parent #f))
    (define assembly (hash-ref alias-info 'assembly #f))

    (when (and alias-name parent-enc-id assembly)
      ;; 从 assembly 提取别名助记符
      (define alias-mnem (extract-mnemonic-from-assembly assembly))

      ;; 从 spec-db 获取目标指令信息
      (define target-info (hash-ref spec-db parent-enc-id #f))

      (when (and alias-mnem target-info)
        (define target-mnem (hash-ref target-info 'mnem #f))

        ;; 从别名的 assembly 解析签名（而非目标指令的模板）
        (define alias-sig (parse-alias-assembly-signature assembly))

        ;; 如果解析失败，回退到目标指令的签名
        (define final-sig
          (if (null? alias-sig)
              (parse-template-to-signature (hash-ref target-info 'template ""))
              alias-sig))

        ;; 计算操作数类别
        (define class-name
          (string->symbol (format "c~a" (length final-sig))))

        ;; 从 _meta.encoded_in 计算正确的转换规则
        (define meta (hash-ref alias-info '_meta #f))
        (define encoded-in-mapping (extract-encoded-in-mapping meta))
        (define alias-operand-names (extract-alias-operand-names assembly))

        ;; 计算转换规则
        (define transform
          (if (and (hash? meta) (hash-count encoded-in-mapping) (pair? alias-operand-names))
              (compute-transform alias-operand-names
                                 (hash-ref target-info 'template "")
                                 encoded-in-mapping
                                 spec-db
                                 parent-enc-id)
              ;; 回退: 简单的 0, 1, 2... 映射
              (for/list ([i (in-range (length final-sig))])
                i)))

        ;; 添加到数据库
        (hash-update! aliases (string->symbol alias-mnem)
                      (lambda (lst)
                        (cons (list class-name final-sig target-mnem transform)
                              lst))
                      '()))))

  aliases)

;; ============================================================
;; 输出签名文件
;; ============================================================

(define (write-signatures aliases path)
  (call-with-output-file path
    (lambda (out)
      (displayln ";; ============================================================" out)
      (displayln ";; alias-signatures.rktd - 别名签名定义" out)
      (displayln ";; ============================================================" out)
      (displayln ";;" out)
      (displayln ";; 生成: racket syntax/gen-alias-signatures.rkt" out)
      (displayln ";; 数据来源: MRS Instructions.json" out)
      (displayln ";;\n" out)

      (for ([(mnem entries) (in-hash aliases)])
        (define sigs
          (remove-duplicates
           (for/list ([e (in-list entries)])
             (list (first e) (second e)))))
        (fprintf out "~s\n\n" (list mnem sigs))))
    #:exists 'replace)

  (printf "已保存: ~a (~a 个助记符)\n" path (hash-count aliases)))

;; ============================================================
;; 输出转换文件
;; ============================================================

(define (write-transforms aliases path)
  (call-with-output-file path
    (lambda (out)
      (displayln ";; ============================================================" out)
      (displayln ";; alias-transforms.rktd - 别名转换规则" out)
      (displayln ";; ============================================================" out)
      (displayln ";;" out)
      (displayln ";; 生成: racket syntax/gen-alias-signatures.rkt" out)
      (displayln ";; 数据来源: MRS Instructions.json" out)
      (displayln ";;\n" out)

      (for ([(mnem entries) (in-hash aliases)])
        (define transforms
          (remove-duplicates
           (for/list ([e (in-list entries)])
             (list (list (first e) (second e))  ; (class sig)
                   (third e)                     ; target-mnem
                   (fourth e)))))                ; transform
        (fprintf out "~s\n\n" (cons mnem transforms))))
    #:exists 'replace)

  (printf "已保存: ~a\n" path))

;; ============================================================
;; 输出别名映射文件 (alias-map.rktd)
;; ============================================================

(define (write-alias-map aliases path)
  (call-with-output-file path
    (lambda (out)
      (displayln ";; ============================================================" out)
      (displayln ";; alias-map.rktd - 简化别名映射" out)
      (displayln ";; ============================================================" out)
      (displayln ";;" out)
      (displayln ";; 格式: (alias-mnemonic (target-mnemonic ...))" out)
      (displayln ";; 生成: racket syntax/gen-alias-signatures.rkt" out)
      (displayln ";; 数据来源: MRS Instructions.json" out)
      (displayln ";;\n" out)

      (for ([(mnem entries) (in-hash aliases)])
        (define targets
          (remove-duplicates
           (for/list ([e (in-list entries)])
             (third e))))
        (fprintf out "~s\n" (list mnem targets))))
    #:exists 'replace)

  (printf "已保存: ~a (~a 个助记符)\n" path (hash-count aliases)))

;; ============================================================
;; 主程序
;; ============================================================

(define (return v) v)

(module+ main
  (command-line
   #:program "gen-alias-signatures"
   #:once-each
   [("-j" "--json") path
    "MRS JSON 路径"
    (mrs-json-path path)]
   [("-s" "--spec") path
    "指令规范路径"
    (spec-path path)]
   [("-o" "--output-sig") path
    "签名输出路径"
    (sig-output path)]
   [("-t" "--output-transform") path
    "转换输出路径"
    (transform-output path)]
   [("-m" "--output-map") path
    "映射输出路径"
    (map-output path)]
   #:args ()

   (printf "生成别名签名、转换和映射 (从 MRS)...\n")

   (define aliases (build-alias-database))
   (printf "  别名助记符数: ~a\n" (hash-count aliases))

   (write-signatures aliases (sig-output))
   (write-transforms aliases (transform-output))
   (write-alias-map aliases (map-output))

   (printf "完成!\n")))

;; 导出供其他模块使用
(provide build-alias-database)
