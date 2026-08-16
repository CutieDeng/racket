#lang racket

;; ============================================================
;; syntax/alias.rkt - 指令别名处理
;; ============================================================
;;
;; 处理 ARM64 汇编器别名 (如 mov, cmp, tst 等)
;;
;; 别名是汇编器语法糖，映射到真实指令编码：
;;   mov Xd, Xm    → orr Xd, xzr, Xm
;;   mov Xd, #imm  → movz/movn Xd, #imm
;;   cmp Xn, Xm    → subs xzr, Xn, Xm
;;   tst Xn, Xm    → ands xzr, Xn, Xm

(require racket/runtime-path)

(provide
  ;; 数据库
  get-alias-map

  ;; 查询
  alias?
  get-alias-targets

  ;; 别名展开
  expand-alias
  try-alias-validation)

;; ============================================================
;; 别名数据库
;; ============================================================

(define-runtime-path alias-map-path "data/alias-map.rktd")

;; 内存缓存
(define *alias-map* (box #f))

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

;; 获取别名映射 (懒加载)
;; 格式: hash[alias-mnem -> (listof target-mnem)]
(define (get-alias-map)
  (unless (unbox *alias-map*)
    (define h (make-hash))
    (for ([item (load-sexp-file alias-map-path)])
      (match item
        [(list alias-mnem targets)
         (hash-set! h alias-mnem targets)]
        [_ (void)]))
    ;; 添加手工补充的常用别名
    (add-common-aliases! h)
    (set-box! *alias-map* h))
  (unbox *alias-map*))

;; 手工补充常用别名 (MRS 数据可能不完整)
(define (add-common-aliases! h)
  ;; 确保核心别名存在
  (hash-update! h 'mov (λ (lst) (remove-duplicates (append lst '(orr movz movn add)))) '())
  (hash-update! h 'cmp (λ (lst) (remove-duplicates (append lst '(subs)))) '())
  (hash-update! h 'cmn (λ (lst) (remove-duplicates (append lst '(adds)))) '())
  (hash-update! h 'tst (λ (lst) (remove-duplicates (append lst '(ands)))) '())
  (hash-update! h 'mvn (λ (lst) (remove-duplicates (append lst '(orn)))) '())
  (hash-update! h 'neg (λ (lst) (remove-duplicates (append lst '(sub)))) '())
  (hash-update! h 'negs (λ (lst) (remove-duplicates (append lst '(subs)))) '())
  (hash-update! h 'ngc (λ (lst) (remove-duplicates (append lst '(sbc)))) '())
  (hash-update! h 'ngcs (λ (lst) (remove-duplicates (append lst '(sbcs)))) '())
  ;; 移位别名
  (hash-update! h 'lsl (λ (lst) (remove-duplicates (append lst '(ubfm lslv)))) '())
  (hash-update! h 'lsr (λ (lst) (remove-duplicates (append lst '(ubfm lsrv)))) '())
  (hash-update! h 'asr (λ (lst) (remove-duplicates (append lst '(sbfm asrv)))) '())
  (hash-update! h 'ror (λ (lst) (remove-duplicates (append lst '(extr rorv)))) '())
  ;; 符号扩展别名
  (hash-update! h 'sxtb (λ (lst) (remove-duplicates (append lst '(sbfm)))) '())
  (hash-update! h 'sxth (λ (lst) (remove-duplicates (append lst '(sbfm)))) '())
  (hash-update! h 'sxtw (λ (lst) (remove-duplicates (append lst '(sbfm)))) '())
  (hash-update! h 'uxtb (λ (lst) (remove-duplicates (append lst '(ubfm)))) '())
  (hash-update! h 'uxth (λ (lst) (remove-duplicates (append lst '(ubfm)))) '())
  ;; 乘法别名
  (hash-update! h 'mul (λ (lst) (remove-duplicates (append lst '(madd)))) '())
  (hash-update! h 'mneg (λ (lst) (remove-duplicates (append lst '(msub)))) '())
  (hash-update! h 'smull (λ (lst) (remove-duplicates (append lst '(smaddl)))) '())
  (hash-update! h 'umull (λ (lst) (remove-duplicates (append lst '(umaddl)))) '())
  ;; 条件选择别名
  (hash-update! h 'cinc (λ (lst) (remove-duplicates (append lst '(csinc)))) '())
  (hash-update! h 'cinv (λ (lst) (remove-duplicates (append lst '(csinv)))) '())
  (hash-update! h 'cneg (λ (lst) (remove-duplicates (append lst '(csneg)))) '())
  (hash-update! h 'cset (λ (lst) (remove-duplicates (append lst '(csinc)))) '())
  (hash-update! h 'csetm (λ (lst) (remove-duplicates (append lst '(csinv)))) '()))

;; ============================================================
;; 查询接口
;; ============================================================

;; 检查是否为别名
(define (alias? mnem)
  (hash-has-key? (get-alias-map) mnem))

;; 获取别名的目标指令列表
(define (get-alias-targets mnem)
  (hash-ref (get-alias-map) mnem '()))

;; ============================================================
;; 别名展开
;; ============================================================

;; 尝试将别名指令展开为真实指令
;; 返回: (listof expanded-instruction) 或 #f
;;
;; 别名展开规则 (ARM64 形式):
;;   mov Xd, Xm        → (orr Xd xzr Xm lsl 0)
;;   mov Xd, #imm      → (movz Xd #imm lsl 0)
;;   cmp Xn, Xm        → (subs xzr Xn Xm lsl 0)
;;   cmp Xn, #imm      → (subs xzr Xn #imm)
;;   cmn Xn, Xm        → (adds xzr Xn Xm lsl 0)
;;   tst Xn, Xm        → (ands xzr Xn Xm lsl 0)
;;   mvn Xd, Xm        → (orn Xd xzr Xm lsl 0)
;;   neg Xd, Xm        → (sub Xd xzr Xm lsl 0)
;;   negs Xd, Xm       → (subs Xd xzr Xm lsl 0)
(define (expand-alias mnem operands)
  (case mnem
    ;; MOV 展开
    [(mov)
     (cond
       ;; mov Xd, Xm → orr Xd, xzr, Xm, lsl, 0
       [(and (= (length operands) 2)
             (register-operand? (car operands))
             (register-operand? (cadr operands)))
        (define reg-size (get-register-size (car operands)))
        (define zr (if (eq? reg-size 'x) 'xzr 'wzr))
        (list (list 'orr (car operands) zr (cadr operands) 'lsl 0))]
       ;; mov Xd, #imm → movz Xd, #imm (不需要 lsl)
       [(and (= (length operands) 2)
             (register-operand? (car operands))
             (immediate-operand? (cadr operands)))
        (list (list 'movz (car operands) (cadr operands))
              (list 'movn (car operands) (cadr operands)))]
       [else #f])]

    ;; CMP 展开
    [(cmp)
     (cond
       ;; cmp Xn, Xm → subs xzr, Xn, Xm, lsl 0
       [(and (>= (length operands) 2)
             (register-operand? (car operands))
             (register-operand? (cadr operands)))
        (define reg-size (get-register-size (car operands)))
        (define zr (if (eq? reg-size 'x) 'xzr 'wzr))
        (if (= (length operands) 2)
            (list (list 'subs zr (car operands) (cadr operands) 'lsl 0))
            ;; 已有 shift 操作数
            (list (cons 'subs (cons zr operands))))]
       ;; cmp Xn, #imm → subs xzr, Xn, #imm
       [(and (= (length operands) 2)
             (register-operand? (car operands))
             (immediate-operand? (cadr operands)))
        (define reg-size (get-register-size (car operands)))
        (define zr (if (eq? reg-size 'x) 'xzr 'wzr))
        (list (list 'subs zr (car operands) (cadr operands)))]
       [else #f])]

    ;; CMN 展开
    [(cmn)
     (cond
       [(and (>= (length operands) 2)
             (register-operand? (car operands))
             (register-operand? (cadr operands)))
        (define reg-size (get-register-size (car operands)))
        (define zr (if (eq? reg-size 'x) 'xzr 'wzr))
        (if (= (length operands) 2)
            (list (list 'adds zr (car operands) (cadr operands) 'lsl 0))
            (list (cons 'adds (cons zr operands))))]
       [(and (= (length operands) 2)
             (register-operand? (car operands))
             (immediate-operand? (cadr operands)))
        (define reg-size (get-register-size (car operands)))
        (define zr (if (eq? reg-size 'x) 'xzr 'wzr))
        (list (list 'adds zr (car operands) (cadr operands)))]
       [else #f])]

    ;; TST 展开
    [(tst)
     (cond
       ;; tst Xn, Xm → ands xzr, Xn, Xm, lsl 0
       [(and (>= (length operands) 2)
             (register-operand? (car operands))
             (register-operand? (cadr operands)))
        (define reg-size (get-register-size (car operands)))
        (define zr (if (eq? reg-size 'x) 'xzr 'wzr))
        (if (= (length operands) 2)
            (list (list 'ands zr (car operands) (cadr operands) 'lsl 0))
            (list (cons 'ands (cons zr operands))))]
       ;; tst Xn, #imm → ands xzr, Xn, #imm
       [(and (= (length operands) 2)
             (register-operand? (car operands))
             (immediate-operand? (cadr operands)))
        (define reg-size (get-register-size (car operands)))
        (define zr (if (eq? reg-size 'x) 'xzr 'wzr))
        (list (list 'ands zr (car operands) (cadr operands)))]
       [else #f])]

    ;; MVN 展开
    [(mvn)
     (cond
       ;; mvn Xd, Xm → orn Xd, xzr, Xm, lsl 0
       [(and (= (length operands) 2)
             (register-operand? (car operands))
             (register-operand? (cadr operands)))
        (define reg-size (get-register-size (car operands)))
        (define zr (if (eq? reg-size 'x) 'xzr 'wzr))
        (list (list 'orn (car operands) zr (cadr operands) 'lsl 0))]
       [else #f])]

    ;; NEG 展开
    [(neg)
     (cond
       ;; neg Xd, Xm → sub Xd, xzr, Xm, lsl 0
       [(and (= (length operands) 2)
             (register-operand? (car operands))
             (register-operand? (cadr operands)))
        (define reg-size (get-register-size (car operands)))
        (define zr (if (eq? reg-size 'x) 'xzr 'wzr))
        (list (list 'sub (car operands) zr (cadr operands) 'lsl 0))]
       [else #f])]

    ;; NEGS 展开
    [(negs)
     (cond
       [(and (= (length operands) 2)
             (register-operand? (car operands))
             (register-operand? (cadr operands)))
        (define reg-size (get-register-size (car operands)))
        (define zr (if (eq? reg-size 'x) 'xzr 'wzr))
        (list (list 'subs (car operands) zr (cadr operands) 'lsl 0))]
       [else #f])]

    ;; NGC 展开
    [(ngc)
     (cond
       [(and (= (length operands) 2)
             (register-operand? (car operands))
             (register-operand? (cadr operands)))
        (define reg-size (get-register-size (car operands)))
        (define zr (if (eq? reg-size 'x) 'xzr 'wzr))
        (list (list 'sbc (car operands) zr (cadr operands)))]
       [else #f])]

    ;; NGCS 展开
    [(ngcs)
     (cond
       [(and (= (length operands) 2)
             (register-operand? (car operands))
             (register-operand? (cadr operands)))
        (define reg-size (get-register-size (car operands)))
        (define zr (if (eq? reg-size 'x) 'xzr 'wzr))
        (list (list 'sbcs (car operands) zr (cadr operands)))]
       [else #f])]

    ;; 其他别名 - 返回 #f 让 validator 尝试目标助记符
    [else #f]))

;; ============================================================
;; 辅助函数
;; ============================================================

;; 判断操作数是否为寄存器 (简化版本，基于 S-expr)
(define (register-operand? op)
  (and (symbol? op)
       (regexp-match? #rx"^[xwXW]([0-9]+|zr|sp)$" (symbol->string op))))

;; 判断操作数是否为立即数
(define (immediate-operand? op)
  (or (number? op)
      (and (symbol? op)
           (regexp-match? #rx"^#" (symbol->string op)))))

;; 获取寄存器大小
(define (get-register-size op)
  (if (symbol? op)
      (let ([s (symbol->string op)])
        (cond
          [(regexp-match? #rx"^[xX]" s) 'x]
          [(regexp-match? #rx"^[wW]" s) 'w]
          [else 'x]))
      'x))

;; ============================================================
;; 验证集成
;; ============================================================

;; 尝试使用别名验证
;; 返回: validation-result 或 #f
;;
;; validate-fn: (-> mnemonic operands validation-result)
(define (try-alias-validation mnem operands validate-fn)
  (define targets (get-alias-targets mnem))
  (cond
    [(null? targets) #f]
    [else
     ;; 首先尝试展开
     (define expansions (expand-alias mnem operands))
     (cond
       [expansions
        ;; 尝试每个展开
        (for/or ([exp (in-list expansions)])
          (define exp-mnem (car exp))
          (define exp-operands (cdr exp))
          (define result (validate-fn exp-mnem exp-operands))
          (and result
               (validation-ok? result)
               result))]
       ;; 如果没有展开规则，尝试直接用目标助记符
       [else
        (for/or ([target (in-list targets)])
          (define result (validate-fn target operands))
          (and result
               (validation-ok? result)
               result))])]))

;; 导入 validation-ok? (需要外部提供或延迟绑定)
(define validation-ok?
  (make-parameter (λ (r) #t)))

;; ============================================================
;; 测试
;; ============================================================

(module+ test
  (displayln "=== 别名数据库测试 ===")
  (define m (get-alias-map))
  (printf "已加载 ~a 个别名\n\n" (hash-count m))

  (displayln "核心别名:")
  (for ([mnem '(mov cmp cmn tst mvn neg negs mul)])
    (printf "  ~a → ~a\n" mnem (get-alias-targets mnem)))

  (newline)
  (displayln "别名检查:")
  (for ([mnem '(mov add sub ldr str cmp)])
    (printf "  ~a: ~a\n" mnem (if (alias? mnem) "是别名" "不是别名"))))
