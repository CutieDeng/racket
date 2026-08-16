#lang racket

;; ============================================================
;; semantic/branch-info.rkt - 分支指令语义信息
;; ============================================================
;;
;; 提供分支指令的语义查询功能:
;;   - 判断是否为分支指令
;;   - 判断分支类型 (条件/无条件)
;;   - 判断目标类型 (直接/间接)
;;   - 判断是否为调用/返回
;;   - 提取分支目标
;;
;; 数据来源: semantic/data/branch-patterns.rktd

(require "../parser/ast.rkt"
         racket/runtime-path)

(provide
  ;; 数据结构
  (struct-out branch-info)
  (struct-out target-info)

  ;; 查询函数
  get-branch-info
  branch-instruction?
  unconditional-branch?
  conditional-branch?
  direct-branch?
  indirect-branch?
  call-instruction?
  return-instruction?

  ;; 目标提取
  extract-branch-target

  ;; 数据库访问
  get-branch-db)

;; ============================================================
;; 数据结构
;; ============================================================

;; 分支指令信息
(struct branch-info
  (mnemonic        ; symbol - 助记符 (不含 suffix)
   branch-type     ; 'unconditional | 'conditional
   target-type     ; 'direct | 'indirect
   is-call?        ; boolean - 是否保存返回地址
   is-return?      ; boolean - 是否为返回指令
   condition-src)  ; #f | 'suffix | 'register | 'bit
  #:transparent)

;; 分支目标信息
(struct target-info
  (kind            ; 'label | 'register
   value)          ; symbol | ast-reg
  #:transparent)

;; ============================================================
;; 分支模式数据库 (从 .rktd 文件加载)
;; ============================================================

(define-runtime-path patterns-path "data/branch-patterns.rktd")

;; 内存缓存
(define *branch-db* (box #f))

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

;; 获取分支数据库 (懒加载)
;; 格式: hash[mnemonic -> branch-info]
(define (get-branch-db)
  (unless (unbox *branch-db*)
    (define h (make-hash))
    (for ([item (load-sexp-file patterns-path)])
      (match item
        [(list mnem branch-type target-type is-call is-return cond-src)
         (hash-set! h mnem
                    (branch-info mnem branch-type target-type
                                 is-call is-return cond-src))]
        [_ (void)]))
    (set-box! *branch-db* h))
  (unbox *branch-db*))

;; ============================================================
;; 查询函数
;; ============================================================

;; 获取助记符的分支信息
;; 对于 B.cond 形式，需要先合成完整助记符
(define (get-branch-info mnem [suffix #f])
  (define db (get-branch-db))
  (cond
    ;; 尝试合成 mnem.suffix 形式 (如 b.eq)
    [(and suffix (eq? mnem 'b))
     (define full-mnem (string->symbol (format "~a.~a" mnem suffix)))
     (hash-ref db full-mnem #f)]
    ;; 直接查找
    [else
     (hash-ref db mnem #f)]))

;; 判断是否为分支指令
(define (branch-instruction? ins)
  (match ins
    [(ast-ins mnem suffix _ _)
     (get-branch-info mnem suffix)]
    [_ #f]))

;; 判断是否为无条件分支
(define (unconditional-branch? ins)
  (define info (match ins
                 [(ast-ins mnem suffix _ _)
                  (get-branch-info mnem suffix)]
                 [_ #f]))
  (and info (eq? (branch-info-branch-type info) 'unconditional)))

;; 判断是否为条件分支
(define (conditional-branch? ins)
  (define info (match ins
                 [(ast-ins mnem suffix _ _)
                  (get-branch-info mnem suffix)]
                 [_ #f]))
  (and info (eq? (branch-info-branch-type info) 'conditional)))

;; 判断是否为直接跳转
(define (direct-branch? ins)
  (define info (match ins
                 [(ast-ins mnem suffix _ _)
                  (get-branch-info mnem suffix)]
                 [_ #f]))
  (and info (eq? (branch-info-target-type info) 'direct)))

;; 判断是否为间接跳转
(define (indirect-branch? ins)
  (define info (match ins
                 [(ast-ins mnem suffix _ _)
                  (get-branch-info mnem suffix)]
                 [_ #f]))
  (and info (eq? (branch-info-target-type info) 'indirect)))

;; 判断是否为调用指令 (保存返回地址)
(define (call-instruction? ins)
  (define info (match ins
                 [(ast-ins mnem suffix _ _)
                  (get-branch-info mnem suffix)]
                 [_ #f]))
  (and info (branch-info-is-call? info)))

;; 判断是否为返回指令
(define (return-instruction? ins)
  (define info (match ins
                 [(ast-ins mnem suffix _ _)
                  (get-branch-info mnem suffix)]
                 [_ #f]))
  (and info (branch-info-is-return? info)))

;; ============================================================
;; 目标提取
;; ============================================================

;; 从分支指令提取目标
;; 返回 target-info | #f
(define (extract-branch-target ins)
  (define info (match ins
                 [(ast-ins mnem suffix _ _)
                  (get-branch-info mnem suffix)]
                 [_ #f]))
  (unless info (return #f))

  (match ins
    [(ast-ins mnem suffix operands _)
     (cond
       ;; ret 默认使用 x30，但可以指定
       [(branch-info-is-return? info)
        (if (null? operands)
            (target-info 'register (ast-reg 'x 30 #f #f #f #f no-srcloc))
            (match (car operands)
              [(? ast-reg? r) (target-info 'register r)]
              [_ #f]))]

       ;; 间接跳转 - 目标是寄存器
       [(eq? (branch-info-target-type info) 'indirect)
        (match operands
          [(list (? ast-reg? r) _ ...) (target-info 'register r)]
          [_ #f])]

       ;; 直接跳转 - 目标是标签
       [(eq? (branch-info-target-type info) 'direct)
        (define label-operand
          (match (branch-info-condition-src info)
            ;; B.cond label - 第一个操作数是标签
            ['suffix (and (pair? operands) (car operands))]
            ;; CBZ Rt, label - 第二个操作数是标签
            ['register (and (>= (length operands) 2) (second operands))]
            ;; TBZ Rt, #bit, label - 第三个操作数是标签
            ['bit (and (>= (length operands) 3) (third operands))]
            ;; B/BL label - 第一个操作数是标签
            [#f (and (pair? operands) (car operands))]))
        (match label-operand
          [(ast-label name _ _) (target-info 'label name)]
          [_ #f])]

       [else #f])]
    [_ #f]))

;; ============================================================
;; 返回语法支持
;; ============================================================

(define-syntax-rule (return v)
  (begin v))

;; ============================================================
;; 测试
;; ============================================================

(module+ test
  (require "../parser/parser.rkt")

  ;; 显示数据库统计
  (displayln "=== 分支指令数据库 ===")
  (define db (get-branch-db))
  (printf "已加载 ~a 条分支模式\n\n" (hash-count db))

  ;; 显示所有模式
  (displayln "分支模式列表:")
  (for ([(mnem info) (in-hash db)])
    (printf "  ~a: type=~a target=~a call?=~a ret?=~a cond=~a\n"
            mnem
            (branch-info-branch-type info)
            (branch-info-target-type info)
            (branch-info-is-call? info)
            (branch-info-is-return? info)
            (branch-info-condition-src info)))
  (newline)

  ;; 测试查询
  (displayln "=== 查询测试 ===")
  (define (test-ins sexp)
    (define ins (parse-instruction sexp))
    (printf "指令: ~a\n" (ast->string ins))
    (printf "  分支? ~a\n" (if (branch-instruction? ins) "是" "否"))
    (when (branch-instruction? ins)
      (printf "  无条件? ~a\n" (unconditional-branch? ins))
      (printf "  条件? ~a\n" (conditional-branch? ins))
      (printf "  直接? ~a\n" (direct-branch? ins))
      (printf "  间接? ~a\n" (indirect-branch? ins))
      (printf "  调用? ~a\n" (call-instruction? ins))
      (printf "  返回? ~a\n" (return-instruction? ins))
      (define target (extract-branch-target ins))
      (printf "  目标: ~a\n" target))
    (newline))

  (test-ins '(b loop))
  (test-ins '(bl printf))
  (test-ins '(b.eq done))
  (test-ins '(cbz x0 exit))
  (test-ins '(tbz x0 5 error))
  (test-ins '(br x16))
  (test-ins '(blr x16))
  (test-ins '(ret))
  (test-ins '(ret x30))

  ;; 非分支指令测试
  (displayln "=== 非分支指令 ===")
  (test-ins '(add x0 x1 x2))
  (test-ins '(mov x0 1)))
