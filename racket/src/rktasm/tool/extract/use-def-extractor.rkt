#lang racket

;; ============================================================
;; use-def-extractor.rkt - 从 MRS 数据提取 use/def 模式
;; ============================================================
;;
;; 从约束字段名推导 use/def 语义：
;;   Rd, Xd, Wd, Zd, Vd, Pd = def (destination)
;;   Rn, Rm, Ra, Xn, Xm, Zn, Zm = use (source)
;;   Rdn, Zdn = def+use (destination that's also source)
;;   Rt, Rt2 = depends on instruction class

(require "loader.rkt")

(provide extract-use-def-db
         save-use-def-db)

;; ============================================================
;; 字段名到角色的映射
;; ============================================================

;; Destination 字段 (def)
(define def-fields
  '("Rd" "Wd" "Xd" "Zd" "Vd" "Pd" "Dd" "Sd" "Hd" "Bd" "Qd"))

;; Source 字段 (use)
(define use-fields
  '("Rn" "Rm" "Ra" "Rs"
    "Wn" "Wm" "Wa"
    "Xn" "Xm" "Xa"
    "Zn" "Zm" "Za" "Zk"
    "Vn" "Vm" "Va"
    "Dn" "Dm" "Sn" "Sm" "Hn" "Hm" "Bn" "Bm" "Qn" "Qm"
    "Pn" "Pm" "Pg"))

;; Destination + Source 字段 (def+use)
(define def-use-fields
  '("Rdn" "Zdn" "Zda" "Vdn"))

;; Transfer 字段 (需要根据指令类别判断)
(define transfer-fields
  '("Rt" "Rt2" "Zt" "Vt"))

;; Load 指令助记符前缀
(define load-prefixes
  '("ld" "ldr" "ldp" "ldur" "ldar" "ldax" "ldx" "ldnp" "ldtr" "ldrs"))

;; Store 指令助记符前缀
(define store-prefixes
  '("st" "str" "stp" "stur" "stlr" "stx" "stnp" "sttr"))

;; ============================================================
;; 提取 use/def 模式
;; ============================================================

;; 判断是否为 load 指令
(define (load-instruction? mnem)
  (define mnem-str (string-downcase (symbol->string mnem)))
  (for/or ([prefix (in-list load-prefixes)])
    (string-prefix? mnem-str prefix)))

;; 判断是否为 store 指令
(define (store-instruction? mnem)
  (define mnem-str (string-downcase (symbol->string mnem)))
  (for/or ([prefix (in-list store-prefixes)])
    (string-prefix? mnem-str prefix)))

;; 判断是否为比较指令 (无 def)
(define (compare-instruction? mnem)
  (memq mnem '(cmp cmn tst ccmp ccmn fcmp fcmpe)))

;; 从约束提取 use/def 模式
;; 返回: (use-def-pattern defs uses def-uses)
(define (extract-pattern-from-constraints mnem constraints)
  (define defs '())
  (define uses '())
  (define def-uses '())

  (for ([c (in-list constraints)])
    (define field-name (car c))
    (cond
      ;; Destination 字段
      [(member field-name def-fields)
       (set! defs (cons field-name defs))]
      ;; Source 字段
      [(member field-name use-fields)
       (set! uses (cons field-name uses))]
      ;; Destination + Source 字段
      [(member field-name def-use-fields)
       (set! def-uses (cons field-name def-uses))]
      ;; Transfer 字段 - 根据指令类别判断
      [(member field-name transfer-fields)
       (cond
         [(load-instruction? mnem)
          (set! defs (cons field-name defs))]
         [(store-instruction? mnem)
          (set! uses (cons field-name uses))]
         [else
          ;; 默认作为 use
          (set! uses (cons field-name uses))])]))

  ;; 比较指令没有 def
  (when (compare-instruction? mnem)
    (set! uses (append defs uses))
    (set! defs '()))

  (list (reverse defs) (reverse uses) (reverse def-uses)))

;; ============================================================
;; 数据库构建
;; ============================================================

;; 从指令规范提取 use/def 数据库
;; 返回: hash[mnemonic -> (listof (list encoding-id pattern))]
(define (extract-use-def-db spec-path)
  (define db (make-hash))

  (for ([spec (load-sexp-file spec-path)])
    (match spec
      [(list enc-id mnem template constraints)
       (define pattern (extract-pattern-from-constraints mnem constraints))
       (hash-update! db mnem
                     (λ (lst) (cons (list enc-id pattern) lst))
                     '())]
      [_ (void)]))

  ;; 合并相同助记符的模式
  (define merged-db (make-hash))
  (for ([(mnem patterns) (in-hash db)])
    ;; 取最常见的模式作为该助记符的代表
    (define pattern-counts (make-hash))
    (for ([p (in-list patterns)])
      (define pat (cadr p))
      (hash-update! pattern-counts pat add1 0))
    (define most-common
      (car (argmax cdr (hash->list pattern-counts))))
    (hash-set! merged-db mnem most-common))

  merged-db)

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

;; ============================================================
;; 输出
;; ============================================================

(define (save-use-def-db db output-path)
  (call-with-output-file output-path
    (lambda (out)
      (fprintf out ";; ============================================================\n")
      (fprintf out ";; use-def-patterns.rktd - 指令 Use/Def 模式\n")
      (fprintf out ";; ============================================================\n")
      (fprintf out ";;\n")
      (fprintf out ";; 格式: (mnemonic (defs ...) (uses ...) (def+uses ...))\n")
      (fprintf out ";;\n")
      (fprintf out ";; 从约束字段名推导:\n")
      (fprintf out ";;   Rd, Xd, Wd, Zd = def (destination)\n")
      (fprintf out ";;   Rn, Rm, Xn, Xm, Zn, Zm = use (source)\n")
      (fprintf out ";;   Rdn, Zdn = def+use\n")
      (fprintf out ";;   Rt = load→def, store→use\n")
      (fprintf out ";;\n\n")

      (for ([(mnem pattern) (in-hash db)])
        (match-define (list defs uses def-uses) pattern)
        (fprintf out "~s\n" (list mnem defs uses def-uses))))
    #:exists 'replace)

  (printf "已保存 use/def 模式: ~a (~a 条记录)\n"
          output-path (hash-count db)))

;; ============================================================
;; 主程序
;; ============================================================

(module+ main
  (require racket/cmdline)

  (define spec-path
    (make-parameter "syntax/data/generated/instruction-spec.rktd"))
  (define output-path
    (make-parameter "semantic/data/use-def-patterns.rktd"))

  (command-line
   #:program "use-def-extractor"
   #:once-each
   [("-s" "--spec") path
    "Path to instruction-spec.rktd"
    (spec-path path)]
   [("-o" "--output") path
    "Output path"
    (output-path path)]
   #:args ()

   (printf "从 ~a 提取 use/def 模式...\n" (spec-path))
   (define db (extract-use-def-db (spec-path)))
   (save-use-def-db db (output-path))

   ;; 显示示例
   (printf "\n示例:\n")
   (for ([mnem (in-list '(add sub ldr str cmp mov ldp stp))]
         #:when (hash-has-key? db mnem))
     (match-define (list defs uses def-uses) (hash-ref db mnem))
     (printf "  ~a: defs=~a uses=~a def+uses=~a\n"
             mnem defs uses def-uses))))
