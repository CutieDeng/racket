#lang racket

;; ============================================================
;; semantic/use-def.rkt - 指令 Use/Def 语义分析
;; ============================================================
;;
;; 分析指令的寄存器使用模式：
;;   - def: 指令定义（写入）的寄存器
;;   - use: 指令使用（读取）的寄存器
;;
;; 输出为 Tree 结构，保留操作数层级关系
;;
;; 数据来源: semantic/data/use-def-patterns.rktd
;; 通过 tool/extract/use-def-extractor.rkt 从 MRS 约束数据生成

(require "../parser/ast.rkt"
         racket/runtime-path)

;; 模块位置: semantic/use-def.rkt

(provide
  ;; 数据结构
  (struct-out use-def-result)
  (struct-out operand-ref)
  (struct-out reg-ref)

  ;; 主分析函数
  extract-use-def

  ;; 辅助查询
  use-def-flat-defs
  use-def-flat-uses
  use-def-has-memory?
  use-def-groups       ; 获取寄存器组

  ;; 格式化
  format-use-def

  ;; 数据库访问
  get-use-def-db)

;; ============================================================
;; 数据结构
;; ============================================================

;; 寄存器引用
(struct reg-ref
  (kind       ; 'x | 'w | 'sp | 'zr - 寄存器类型
   id         ; number | symbol - 编号或虚拟名
   position)  ; 'direct | 'base | 'index | 'offset - 在操作数中的位置
  #:transparent)

;; 操作数引用 (Tree 节点)
(struct operand-ref
  (index      ; number - 操作数位置 (从 0 开始)
   role       ; 'def | 'use | 'def+use
   regs       ; (listof reg-ref) - 该操作数涉及的寄存器
   group?)    ; boolean - 这些寄存器是否形成一个组（必须连续分配）
  #:transparent)

;; 辅助构造：根据操作数类型自动设置 group?
(define (make-operand-ref index role regs op)
  (operand-ref index role regs (ast-reglist? op)))

;; Use/Def 分析结果
(struct use-def-result
  (mnemonic   ; symbol - 助记符
   operands)  ; (listof operand-ref) - 按操作数组织的引用
  #:transparent)

;; ============================================================
;; Use/Def 模式数据库 (从 .rktd 文件加载)
;; ============================================================

(define-runtime-path patterns-path "data/use-def-patterns.rktd")

;; 内存缓存
(define *use-def-db* (box #f))

;; 加载 S-表达式文件
(define (load-sexp-file path)
  (if (file-exists? path)
      (with-input-from-file path
        (lambda ()
          (let loop ([items '()])
            (define datum (read))
            (if (eof-object? datum)
                (reverse items)
                (loop (cons datum items))))))
      '()))

;; 获取 use/def 数据库 (懒加载)
;; 格式: hash[mnemonic -> (list defs uses def+uses)]
(define (get-use-def-db)
  (unless (unbox *use-def-db*)
    (define h (make-hash))
    (for ([item (load-sexp-file patterns-path)])
      (match item
        [(list mnem defs uses def+uses)
         (hash-set! h mnem (list defs uses def+uses))]
        [_ (void)]))
    (set-box! *use-def-db* h))
  (unbox *use-def-db*))

;; 查询助记符的 use/def 模式
;; 返回: (list defs uses def+uses) 或 #f
(define (lookup-use-def-pattern mnem)
  (hash-ref (get-use-def-db) mnem #f))

;; ============================================================
;; 字段名到寄存器类型映射
;; ============================================================

;; 从字段名推断寄存器类型
(define (field-name->reg-kind field)
  (cond
    [(regexp-match? #rx"^[XRWS]" field) 'x]  ; X, R, W, S 开头
    [(regexp-match? #rx"^Z" field) 'z]       ; SVE 寄存器
    [(regexp-match? #rx"^V" field) 'v]       ; SIMD 寄存器
    [(regexp-match? #rx"^P" field) 'p]       ; 谓词寄存器
    [else 'x]))  ; 默认

;; ============================================================
;; 主分析函数
;; ============================================================

(define (extract-use-def ins)
  (match ins
    [(ast-ins mnem suffix operands _)
     (define db-pattern (lookup-use-def-pattern mnem))
     (define op-refs
       (if db-pattern
           (analyze-operands-from-db mnem db-pattern operands)
           (analyze-operands-fallback mnem operands)))
     (use-def-result mnem op-refs)]
    [_ (use-def-result 'unknown '())]))

;; 基于数据库模式分析操作数
;; db-pattern: (list defs uses def+uses) 其中每个是字段名列表
(define (analyze-operands-from-db mnem db-pattern operands)
  (match-define (list def-fields use-fields def+use-fields) db-pattern)

  ;; 计算每种角色的数量
  (define n-defs (length def-fields))
  (define n-uses (length use-fields))
  (define n-def+uses (length def+use-fields))

  ;; 判断是否为 load/store 类指令 (有内存操作数)
  (define has-memory?
    (for/or ([op (in-list operands)])
      (ast-mem? op)))

  ;; 根据数据库模式推断操作数角色
  ;; 策略：
  ;;   - 如果有 def 字段，前 n-defs 个非内存操作数是 def
  ;;   - 如果有 def+use 字段，对应位置是 def+use
  ;;   - 其余是 use
  ;;   - 内存操作数需要特殊处理 (检查 pre/post-index)

  (for/list ([op (in-list operands)]
             [i (in-naturals)])
    (cond
      ;; 内存操作数
      [(ast-mem? op)
       (define mode (ast-mem-index-mode op))
       (define base-role (if (memq mode '(pre post)) 'def+use 'use))
       (operand-ref i (if (memq mode '(pre post)) 'def+use 'use)
                    (extract-regs-from-memory op base-role) #f)]

      ;; 根据数据库模式判断
      [else
       (define role (infer-operand-role i n-defs n-uses n-def+uses has-memory?))
       (make-operand-ref i role (extract-regs-from-operand op role) op)])))

;; 根据位置和模式推断操作数角色
(define (infer-operand-role index n-defs n-uses n-def+uses has-memory?)
  (cond
    ;; 有 def+use (如累加器指令)
    [(> n-def+uses 0)
     (cond
       [(< index n-defs) 'def]
       [(< index (+ n-defs n-def+uses)) 'def+use]
       [else 'use])]

    ;; 没有 def (比较指令等)
    [(= n-defs 0) 'use]

    ;; 有 def，第一个（或前几个）是 def
    [(< index n-defs) 'def]

    ;; 其余是 use
    [else 'use]))

;; 后备分析 (当数据库中没有该助记符时)
(define (analyze-operands-fallback mnem operands)
  ;; 默认：第一个是 def，其余是 use
  ;; 但需要处理特殊情况
  (define mnem-str (symbol->string mnem))

  (cond
    ;; 比较指令：全是 use
    [(regexp-match? #rx"^(cmp|cmn|tst|ccmp|ccmn|fcmp)" mnem-str)
     (for/list ([op (in-list operands)]
                [i (in-naturals)])
       (make-operand-ref i 'use (extract-regs-from-operand op 'use) op))]

    ;; 分支指令：全是 use
    [(regexp-match? #rx"^(b|br|blr|ret|cb|tb)" mnem-str)
     (for/list ([op (in-list operands)]
                [i (in-naturals)])
       (make-operand-ref i 'use (extract-regs-from-operand op 'use) op))]

    ;; Store 指令：全是 use
    [(regexp-match? #rx"^(st|stur)" mnem-str)
     (for/list ([op (in-list operands)]
                [i (in-naturals)])
       (cond
         [(ast-mem? op)
          (define mode (ast-mem-index-mode op))
          (operand-ref i (if (memq mode '(pre post)) 'def+use 'use)
                       (extract-regs-from-memory op 'use) #f)]
         [else
          (make-operand-ref i 'use (extract-regs-from-operand op 'use) op)]))]

    ;; Load 指令：第一个是 def
    [(regexp-match? #rx"^(ld|ldr|lda|ldur)" mnem-str)
     (analyze-load-operands operands)]

    ;; SHA1 加密指令：sha1c/sha1p/sha1m/sha1su0/sha1su1 第一个操作数是 def+use
    ;; 这些指令读取并更新目标寄存器
    [(regexp-match? #rx"^sha1(c|p|m|su0|su1)$" mnem-str)
     (for/list ([op (in-list operands)]
                [i (in-naturals)])
       (make-operand-ref i (if (= i 0) 'def+use 'use)
                    (extract-regs-from-operand op (if (= i 0) 'def+use 'use)) op))]

    ;; 默认：第一个是 def，其余是 use
    [else
     (for/list ([op (in-list operands)]
                [i (in-naturals)])
       (make-operand-ref i (if (= i 0) 'def 'use)
                    (extract-regs-from-operand op (if (= i 0) 'def 'use)) op))]))

;; 分析 Load 指令操作数 (处理 pre/post-index)
(define (analyze-load-operands operands)
  (for/list ([op (in-list operands)]
             [i (in-naturals)])
    (cond
      ;; 第一个操作数是目标寄存器 (def)
      [(= i 0)
       (make-operand-ref i 'def (extract-regs-from-operand op 'def) op)]
      ;; 第二个位置如果也是寄存器 (ldp)，也是 def
      [(and (= i 1) (ast-reg? op))
       (make-operand-ref i 'def (extract-regs-from-operand op 'def) op)]
      ;; 内存操作数
      [(ast-mem? op)
       (define mode (ast-mem-index-mode op))
       (define base-role (if (memq mode '(pre post)) 'def+use 'use))
       (operand-ref i (if (memq mode '(pre post)) 'def+use 'use)
                    (extract-regs-from-memory op base-role) #f)]
      ;; 其他操作数是 use
      [else
       (make-operand-ref i 'use (extract-regs-from-operand op 'use) op)])))

;; ============================================================
;; 寄存器提取
;; ============================================================

;; 从操作数提取寄存器引用
(define (extract-regs-from-operand op role)
  (match op
    ;; GPR 寄存器
    [(ast-reg kind id _ _ _ _ _)
     #:when (memq kind '(x w))
     (list (reg-ref kind id 'direct))]

    ;; FPR 寄存器 (SIMD/FP)
    [(ast-reg kind id _ _ _ _ _)
     #:when (memq kind '(v d s h b q z))
     (list (reg-ref kind id 'direct))]

    ;; 谓词寄存器 (SVE predicate)
    [(ast-reg kind id _ _ _ _ _)
     #:when (eq? kind 'p)
     (list (reg-ref kind id 'direct))]

    ;; 内存操作数
    [(? ast-mem?)
     (extract-regs-from-memory op 'use)]

    ;; 寄存器列表
    [(ast-reglist regs _)
     (append-map (λ (r) (extract-regs-from-operand r role)) regs)]

    ;; 其他 (立即数、标签等) - 无寄存器
    [_ '()]))

;; 从内存操作数提取寄存器
(define (extract-regs-from-memory mem base-role)
  (match mem
    [(ast-mem base offset index-mode shift extend _)
     (define result '())

     ;; 基址寄存器
     (when (ast-reg? base)
       (match base
         [(ast-reg kind id _ _ _ _ _)
          #:when (memq kind '(x w))
          (set! result (cons (reg-ref kind id 'base) result))]
         [_ (void)]))

     ;; 偏移量 (如果是寄存器)
     (when (ast-reg? offset)
       (match offset
         [(ast-reg kind id _ _ _ _ _)
          #:when (memq kind '(x w))
          (set! result (cons (reg-ref kind id 'index) result))]
         [_ (void)]))

     (reverse result)]
    [_ '()]))

;; ============================================================
;; 辅助查询函数
;; ============================================================

;; 获取扁平化的 def 列表
(define (use-def-flat-defs result)
  (append-map
   (λ (op-ref)
     (if (memq (operand-ref-role op-ref) '(def def+use))
         (operand-ref-regs op-ref)
         '()))
   (use-def-result-operands result)))

;; 获取扁平化的 use 列表
(define (use-def-flat-uses result)
  (append-map
   (λ (op-ref)
     (if (memq (operand-ref-role op-ref) '(use def+use))
         (operand-ref-regs op-ref)
         '()))
   (use-def-result-operands result)))

;; 检查是否有内存操作数
(define (use-def-has-memory? result)
  (for/or ([op-ref (in-list (use-def-result-operands result))])
    (for/or ([reg (in-list (operand-ref-regs op-ref))])
      (memq (reg-ref-position reg) '(base index)))))

;; 获取寄存器组信息
;; 返回 (listof (list role (listof reg-ref)))
;; 其中 role 是 'def | 'use | 'def+use
(define (use-def-groups result)
  (filter-map
   (λ (op-ref)
     (and (operand-ref-group? op-ref)
          (> (length (operand-ref-regs op-ref)) 1)
          (list (operand-ref-role op-ref)
                (operand-ref-regs op-ref))))
   (use-def-result-operands result)))

;; ============================================================
;; 格式化输出
;; ============================================================

(define (format-use-def result)
  (match result
    [(use-def-result mnem operands)
     (define lines
       (list (format "指令: ~a" mnem)
             (format "操作数:")
             (string-join
              (for/list ([op (in-list operands)])
                (format "  [~a] ~a: ~a"
                        (operand-ref-index op)
                        (operand-ref-role op)
                        (format-reg-list (operand-ref-regs op))))
              "\n")
             ""
             (format "Defs: ~a" (format-reg-list (use-def-flat-defs result)))
             (format "Uses: ~a" (format-reg-list (use-def-flat-uses result)))))
     (string-join lines "\n")]))

(define (format-reg-list regs)
  (if (null? regs)
      "(none)"
      (string-join
       (for/list ([r (in-list regs)])
         (format "~a~a~a"
                 (reg-ref-kind r)
                 (reg-ref-id r)
                 (case (reg-ref-position r)
                   [(base) "/base"]
                   [(index) "/idx"]
                   [(offset) "/off"]
                   [else ""])))
       ", ")))

;; ============================================================
;; 测试
;; ============================================================

(module+ test
  (require "../parser/parser.rkt")

  ;; 显示数据库统计
  (displayln "=== Use/Def 数据库 ===")
  (define db (get-use-def-db))
  (printf "已加载 ~a 条助记符模式\n\n" (hash-count db))

  ;; 显示部分模式
  (displayln "示例模式:")
  (for ([mnem (in-list '(add sub ldr str ldp stp cmp mov))])
    (define pattern (hash-ref db mnem #f))
    (when pattern
      (match-define (list defs uses def+uses) pattern)
      (printf "  ~a: defs=~a uses=~a def+uses=~a\n"
              mnem defs uses def+uses)))
  (newline)

  (define (test-ins sexp)
    (define ins (parse-instruction sexp))
    (define result (extract-use-def ins))
    (displayln (format-use-def result))
    (newline))

  (displayln "=== ALU 指令 ===")
  (test-ins '(add x0 x1 x2))
  (test-ins '(sub w0 w1 w2))

  (displayln "=== 比较指令 ===")
  (test-ins '(cmp x0 x1))

  (displayln "=== Load 指令 ===")
  (test-ins '(ldr x0 (x1)))
  (test-ins '(ldr x0 (x1 x2)))
  (test-ins '(ldr x0 (x1 16 !)))  ; pre-index

  (displayln "=== Store 指令 ===")
  (test-ins '(str x0 (x1 16)))

  (displayln "=== Load Pair 指令 ===")
  (test-ins '(ldp x0 x1 (x2 16))))
