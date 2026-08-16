#lang racket
;; ============================================================
;; sysreg.rkt — 具名 AArch64 系统寄存器表(运行时消费端)
;;
;; 加载 data/generated/sysreg-table.rktd(由 gen-sysreg-table.rkt 生成),
;; 提供:
;;   (sysreg-name? s)        — s 是否为已知具名系统寄存器
;;   (sysreg->structural s)  — "CNTVCTSS_EL0" -> "S3_3_C14_C0_6"(#f 表示未知)
;;
;; 文本发射路径下,rktasm 只需把具名 sysreg 翻成结构式 Sx_x_Cx_Cx_x,
;; 下游任何汇编器(clang/as)都认——天然后向兼容,且不依赖 clang 是否
;; 认识新名字(如 CNTVCTSS_EL0)。
;;
;; 软断言:表缺失/为空/格式异常/锚点丢失都响亮失败,指引维护者重跑生成器。
;; ============================================================
(require racket/runtime-path)
(provide sysreg-name? sysreg->structural)

(define WHO 'sysreg)
(define-runtime-path table-path "data/generated/sysreg-table.rktd")

;; name(string) -> (list op0 op1 CRn CRm op2)
(define *table*
  (let ([h (make-hash)])
    (unless (file-exists? table-path)
      (error WHO "缺少 ~a——请运行 syntax/gen-sysreg-table.rkt 生成" table-path))
    (with-input-from-file table-path
      (lambda ()
        (let loop ()
          (define d (read))
          (unless (eof-object? d)
            (when (pair? d)                       ; 跳过潜在注释外的非表项
              (unless (and (symbol? (car d)) (= 5 (length (cdr d)))
                           (andmap exact-nonnegative-integer? (cdr d)))
                (error WHO "sysreg-table.rktd 条目格式异常: ~s(应为 (NAME op0 op1 CRn CRm op2))" d))
              (hash-set! h (symbol->string (car d)) (cdr d)))
            (loop)))))
    (when (zero? (hash-count h))
      (error WHO "sysreg-table.rktd 为空——生成器可能失败"))
    ;; 锚点:表若陈旧/损坏,此处即拦
    (unless (equal? (hash-ref h "CNTVCTSS_EL0" #f) '(3 3 14 0 6))
      (error WHO "锚点 CNTVCTSS_EL0 缺失或编码不符——sysreg-table.rktd 可能已陈旧,请重跑生成器"))
    h))

(define (norm s) (if (symbol? s) (symbol->string s) s))

(define (sysreg-name? s)
  (hash-has-key? *table* (norm s)))

;; 具名 -> 结构式;未知返回 #f(结构式/普通标签由调用方原样处理)
(define (sysreg->structural s)
  (define e (hash-ref *table* (norm s) #f))
  (and e (match-let ([(list op0 op1 crn crm op2) e])
           (format "S~a_~a_C~a_C~a_~a" op0 op1 crn crm op2))))
