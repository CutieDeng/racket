#lang racket

;; ============================================================
;; semantic/validate.rkt - 前端语义验证
;; ============================================================
;;
;; 在编译流水线早期执行的语义检查，包括：
;; - 跨寄存器类别同名虚拟变量检测
;; - 其他语义约束检查 (待扩展)

(require "control-flow.rkt"
         "use-def.rkt"
         "../parser/ast.rkt"
         "../pipeline/regalloc/types.rkt"
         "../pipeline/regalloc/abi-config.rkt"
         racket/pvector)

(provide
  validate-function
  validate-cfg
  ;; 配置参数
  *check-cross-class-naming*
  *check-memory-base-width*
  *check-virtual-name-format*
  *check-abi-declaration*
  ;; 错误收集（供外部使用）
  semantic-error
  semantic-error?
  semantic-error-category
  semantic-error-message
  semantic-error-location)

;; ============================================================
;; 配置参数
;; ============================================================

;; 是否检查跨寄存器类别的同名虚拟变量（默认开启）
;; 例如: z.result 和 p.result 会被禁止，因为它们共享名称 "result"
(define *check-cross-class-naming* (make-parameter #t))

;; 是否检查内存基址寄存器位宽（默认开启）
;; ARM64 要求内存基址必须是 64 位寄存器
(define *check-memory-base-width* (make-parameter #t))

;; 是否检查虚拟寄存器名称格式（默认开启）
;; 禁止以数字开头的变量名，如 z.0、p.123
(define *check-virtual-name-format* (make-parameter #t))

;; 是否检查 ABI 声明（默认关闭）
;; ABI 更适合作为 call 边界约束；函数自身不需要为了使用虚拟寄存器而声明 ABI。
(define *check-abi-declaration* (make-parameter #f))

;; ============================================================
;; 错误结构
;; ============================================================

;; 语义错误结构
;; category: 错误类别符号 (如 'cross-class-naming, 'memory-base-width)
;; message: 格式化的错误消息字符串
;; location: srcloc 或 #f
(struct semantic-error (category message location) #:transparent)

;; ============================================================
;; 主验证函数
;; ============================================================

;; 验证整个 CFG 中的所有函数
(define (validate-cfg cfg)
  (define all-errors '())
  (cfg-for-each-function cfg
    (lambda (fn)
      (define fn-errors (validate-function fn))
      (set! all-errors (append all-errors fn-errors))))
  (unless (null? all-errors)
    (report-all-errors all-errors)))

;; 验证单个函数，返回错误列表
(define (validate-function fn)
  (define errors '())
  (when (*check-virtual-name-format*)
    (set! errors (append errors (check-virtual-name-format fn))))
  (when (*check-cross-class-naming*)
    (set! errors (append errors (check-cross-class-naming fn))))
  (when (*check-memory-base-width*)
    (set! errors (append errors (check-memory-base-width fn))))
  (when (*check-abi-declaration*)
    (set! errors (append errors (check-abi-declaration fn))))
  ;; 如果有错误，汇总报告
  (unless (null? errors)
    (report-all-errors errors))
  errors)

;; 汇总报告所有错误
(define (report-all-errors errors)
  (define error-count (length errors))

  (define msg-lines
    (for/list ([err (in-list errors)]
               [i (in-naturals 1)])
      (format "  ~a. ~a" i (semantic-error-message err))))

  (error 'semantic
         (string-append
          (format "~a 个错误:\n" error-count)
          (string-join msg-lines "\n"))))

;; ============================================================
;; 跨寄存器类别同名检查
;; ============================================================

;; 收集函数中所有虚拟变量及其首次出现位置
(define (collect-virtual-vars-with-locs fn)
  (define vars (make-hash))  ;; reg-id -> srcloc (首次出现)
  (fn-for-each-block fn
    (lambda (block)
      (for ([ins (in-pvector (basic-block-instructions block))])
        (when (ast-ins? ins)
          (define loc (ast-ins-loc ins))
          (define use-def (extract-use-def ins))
          (for ([ref (in-list (use-def-flat-defs use-def))])
            (define rid (reg-ref->reg-id ref))
            (when (reg-id-virtual? rid)
              (unless (hash-has-key? vars rid)
                (hash-set! vars rid loc))))
          (for ([ref (in-list (use-def-flat-uses use-def))])
            (define rid (reg-ref->reg-id ref))
            (when (reg-id-virtual? rid)
              (unless (hash-has-key? vars rid)
                (hash-set! vars rid loc))))))))
  vars)

;; ============================================================
;; 虚拟寄存器名称格式检查
;; ============================================================

;; 检查虚拟寄存器名称是否以数字开头，返回错误列表
(define (check-virtual-name-format fn)
  (define var-locs (collect-virtual-vars-with-locs fn))
  (define errors '())

  (for ([(rid loc) (in-hash var-locs)])
    (define name (reg-id-id rid))
    (define name-str (if (symbol? name) (symbol->string name) (format "~a" name)))
    ;; 检查是否以数字开头
    (when (and (> (string-length name-str) 0)
               (char-numeric? (string-ref name-str 0)))
      (define class (reg-id-class rid))
      (define prefix
        (case class
          [(gpr) "x"]
          [(fpr) "z"]
          [(predicate) "p"]
          [else "?"]))
      (define source-file
        (if (and loc (srcloc? loc) (srcloc-source loc))
            (srcloc-source loc)
            "<unknown>"))
      (define line-num
        (if (and loc (srcloc? loc) (srcloc-line loc))
            (srcloc-line loc)
            0))
      (define col-num
        (if (and loc (srcloc? loc) (srcloc-column loc))
            (srcloc-column loc)
            1))
      (define message
        (format "~a:~a:~a: 变量名 '~a.~a' 不能以数字开头 (易与物理寄存器 ~a~a 混淆)"
                source-file line-num col-num prefix name-str prefix name-str))
      (set! errors (cons (semantic-error 'virtual-name-format message loc) errors))))

  errors)

;; ============================================================
;; 跨寄存器类别同名检查
;; ============================================================

;; 检查跨寄存器类别的同名虚拟变量，返回错误列表
(define (check-cross-class-naming fn)
  (define var-locs (collect-virtual-vars-with-locs fn))
  (define errors '())

  ;; 按名称分组
  (define name->entries (make-hash))  ;; name -> (listof (cons class reg-id))
  (for ([(rid loc) (in-hash var-locs)])
    (define name (reg-id-id rid))
    (define class (reg-id-class rid))
    (hash-update! name->entries name
                  (lambda (lst) (cons (cons class rid) lst))
                  '()))

  ;; 检查冲突
  (for ([(name entries) (in-hash name->entries)])
    (define unique-classes (remove-duplicates (map car entries)))
    (when (> (length unique-classes) 1)
      (define err (make-cross-class-error name entries var-locs (asm-function-name fn)))
      (set! errors (cons err errors))))

  errors)

;; 构建跨类别冲突错误
(define (make-cross-class-error name entries var-locs fn-name)
  (define (class->prefix cls)
    (case cls
      [(gpr) "x"]
      [(fpr) "z"]
      [(predicate) "p"]
      [else "?"]))

  ;; 按行号排序
  (define sorted-entries
    (sort entries
          (lambda (a b)
            (define loc-a (hash-ref var-locs (cdr a) #f))
            (define loc-b (hash-ref var-locs (cdr b) #f))
            (define line-a (if (and loc-a (srcloc? loc-a)) (or (srcloc-line loc-a) 0) 0))
            (define line-b (if (and loc-b (srcloc? loc-b)) (or (srcloc-line loc-b) 0) 0))
            (< line-a line-b))))

  ;; 获取第一个有效位置
  (define first-loc
    (for/or ([entry (in-list sorted-entries)])
      (hash-ref var-locs (cdr entry) #f)))

  (define source-file
    (if (and first-loc (srcloc? first-loc) (srcloc-source first-loc))
        (srcloc-source first-loc)
        "<unknown>"))

  ;; 构建位置列表
  (define loc-strs
    (for/list ([entry (in-list sorted-entries)])
      (define class (car entry))
      (define rid (cdr entry))
      (define loc (hash-ref var-locs rid #f))
      (define prefix (class->prefix class))
      (if (and loc (srcloc? loc) (srcloc-line loc))
          (format "~a.~a 在第 ~a 行" prefix name (srcloc-line loc))
          (format "~a.~a" prefix name))))

  (define message
    (format "~a: 变量名 '~a' 跨类别冲突 (~a)"
            source-file name (string-join loc-strs ", ")))

  (semantic-error 'cross-class-naming message first-loc))

;; ============================================================
;; 内存基址寄存器位宽检查
;; ============================================================

;; ARM64 要求内存寻址的基址寄存器必须是 64 位 (Xn 或 SP)
;; 32 位寄存器 (Wn 或 WSP) 不能作为基址
;; 返回错误列表
(define (check-memory-base-width fn)
  (define errors '())
  (fn-for-each-block fn
    (lambda (block)
      (for ([ins (in-pvector (basic-block-instructions block))])
        (when (ast-ins? ins)
          (for ([op (in-list (ast-ins-operands ins))])
            (define err (check-operand-memory-base op ins (asm-function-name fn)))
            (when err
              (set! errors (cons err errors))))))))
  (reverse errors))

;; 检查单个操作数中的内存基址，返回错误或 #f
(define (check-operand-memory-base op ins fn-name)
  (match op
    [(ast-mem base offset index-mode shift extend loc)
     (cond
       [(ast-reg? base)
        (define kind (ast-reg-kind base))
        (define id (ast-reg-id base))
        ;; W 寄存器不能作为基址 (包括 WSP)
        (if (eq? kind 'w)
            (let ([reg-name (if (eq? id 'sp)
                                "wsp"
                                (format "w~a" id))])
              (make-memory-base-error reg-name ins fn-name))
            #f)]
       [else #f])]
    [_ #f]))

;; 构建无效内存基址寄存器错误
(define (make-memory-base-error reg-name ins fn-name)
  (define loc (ast-ins-loc ins))
  (define source-file
    (if (and loc (srcloc? loc) (srcloc-source loc))
        (srcloc-source loc)
        "<unknown>"))
  (define line-num
    (if (and loc (srcloc? loc) (srcloc-line loc))
        (srcloc-line loc)
        0))
  (define col-num
    (if (and loc (srcloc? loc) (srcloc-column loc))
        (srcloc-column loc)
        1))
  (define ins-str (format-instruction ins))

  (define suggestion
    (if (string=? reg-name "wsp")
        "sp"
        (format "x~a" (substring reg-name 1))))

  (define message
    (format "~a:~a:~a: '~a' 不能作为内存基址 (需要 64 位寄存器，建议用 '~a')"
            source-file line-num col-num reg-name suggestion))

  (semantic-error 'memory-base-width message loc))

;; ============================================================
;; ABI 声明检查
;; ============================================================

;; 检查函数是否声明了 ABI
;; 规则:
;;   - 函数有 (abi <name>) 属性 → 通过
;;   - default-abi-name 参数已设置 → 通过
;;   - 函数不使用虚拟寄存器 → 通过 (无需寄存器分配)
;;   - 否则 → 错误
(define (check-abi-declaration fn)
  (define fn-name (asm-function-name fn))
  (define abi-name (fn-get-info fn 'abi #f))
  (cond
    ;; 显式声明了 ABI
    [abi-name '()]
    ;; 有默认 ABI 参数
    [(default-abi-name) '()]
    ;; 无 ABI - 检查是否使用虚拟寄存器
    [else
     (define vars (collect-virtual-vars-with-locs fn))
     (if (hash-empty? vars)
         '()
         (list (semantic-error
                'missing-abi
                (format "函数 '~a' 未声明 ABI (需要 (abi <name>) 属性，或使用 --default-abi 参数)"
                        fn-name)
                #f)))]))

;; ============================================================
;; 指令格式化 (AST -> 源码字符串)
;; ============================================================

;; 将 AST 指令格式化为 S-expr 字符串
(define (format-instruction ins)
  (match ins
    [(ast-ins mnem suffix operands _)
     (define mnem-str
       (if suffix
           (format "~a.~a" mnem suffix)
           (symbol->string mnem)))
     (define ops-str
       (string-join (map format-operand operands) " "))
     (if (string=? ops-str "")
         (format "(~a)" mnem-str)
         (format "(~a ~a)" mnem-str ops-str))]
    [_ "<unknown instruction>"]))

;; 格式化单个操作数
(define (format-operand op)
  (match op
    ;; 寄存器
    [(ast-reg kind id width element pred-mode virtual? _)
     (define base
       (cond
         [(and (eq? kind 'x) (eq? id 'zr)) "xzr"]
         [(and (eq? kind 'w) (eq? id 'zr)) "wzr"]
         [(and (eq? kind 'x) (eq? id 'sp)) "sp"]
         [(and (eq? kind 'w) (eq? id 'sp)) "wsp"]
         [(eq? kind 'x) (format "x~a" id)]
         [(eq? kind 'w) (format "w~a" id)]
         [(eq? kind 'z) (if virtual? (format "z.~a" id) (format "z~a" id))]
         [(eq? kind 'p) (if virtual? (format "p.~a" id) (format "p~a" id))]
         [(eq? kind 'v) (format "v~a" id)]
         [(eq? kind 'b) (format "b~a" id)]
         [(eq? kind 'h) (format "h~a" id)]
         [(eq? kind 's) (format "s~a" id)]
         [(eq? kind 'd) (format "d~a" id)]
         [(eq? kind 'q) (format "q~a" id)]
         [else (format "~a~a" kind id)]))
     (cond
       [element (format "~a[~a]" base element)]
       [width (format "~a.~a" base width)]
       [else base])]

    ;; 立即数
    [(ast-imm value _)
     (if (negative? value)
         (format "~a" value)
         (format "~a" value))]

    ;; 内存操作数
    [(ast-mem base offset index-mode shift extend _)
     (define base-str (format-operand base))
     (cond
       [(and (not offset) (not shift) (not extend))
        (format "(~a)" base-str)]
       [(and offset (not shift) (not extend))
        (if (ast-imm? offset)
            (format "(~a ~a)" base-str (ast-imm-value offset))
            (format "(~a ~a)" base-str (format-operand offset)))]
       [else
        ;; 复杂情况，简化处理
        (format "(~a ...)" base-str)])]

    ;; 标签
    [(ast-label name reloc _)
     (if reloc
         (format "~a@~a" name reloc)
         (symbol->string name))]

    ;; 移位
    [(ast-shift type amount _)
     (format "~a ~a" type amount)]

    ;; 扩展
    [(ast-extend type amount _)
     (if amount
         (format "~a ~a" type amount)
         (symbol->string type))]

    ;; 其他
    [_ "?"]))
