#!/usr/bin/env racket
#lang racket

;; ============================================================
;; gen-use-def.rkt - 从指令规范提取 use/def 模式
;; ============================================================
;;
;; 生成: data/use-def-patterns.rktd
;;
;; 从约束字段名推导 use/def 语义：
;;   Rd, Xd, Wd, Zd, Vd, Pd = def (destination)
;;   Rn, Rm, Ra, Xn, Xm, Zn, Zm = use (source)
;;   Rdn, Zdn = def+use (destination that's also source)
;;   Rt, Rt2 = depends on instruction class (load→def, store→use, mrs→def, msr→use)
;;
;; 已知缺口(勿盲目覆盖已提交的 use-def-patterns.rktd):
;;   - crypto 累加器(sha1c/sha1m/sha1p/sha1su0/sha1su1 等)的 Rd/Qd 实为
;;     def+use(读且写),但字段名 "Rd" 在此被归为纯 def。已提交的 .rktd 里这些
;;     条目是手工修正过的 def+use;直接 regen 会把它们退回纯 def,须重新应用修正。
;;   - msr 的 Rt 未进 spec 约束,故其 Xt 源未被跟踪(次要)。

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
         ;; MRS/MSR 的 Rt 方向不靠前缀:mrs 从 sysreg 写入 Xt(def),
         ;; msr 从 Xt 读出到 sysreg(use)。
         [(eq? mnem 'mrs)
          (set! defs (cons field-name defs))]
         [(eq? mnem 'msr)
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
      ;; 当前 spec 为 5 元组 (enc-id mnem template constraints operand-fields);
      ;; list-rest 取前 4 项、忽略其余,兼容未来再加尾字段。
      [(list-rest enc-id mnem template constraints _)
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
      (fprintf out ";;   Rt = load→def, store→use, mrs→def, msr→use\n")
      (fprintf out ";;\n")
      (fprintf out ";; 生成命令: racket semantic/gen-use-def.rkt\n")
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
   #:program "gen-use-def"
   #:once-each
   [("-s" "--spec") path
    "Path to instruction-spec.rktd"
    (spec-path path)]
   [("-o" "--output") path
    "Output path"
    (output-path path)]
   #:args ()

   ;; 确保输出目录存在
   (define dir (path-only (output-path)))
   (when dir (make-directory* dir))

   (printf "从 ~a 提取 use/def 模式...\n" (spec-path))
   (define db (extract-use-def-db (spec-path)))
   (save-use-def-db db (output-path))

   ;; 维护引导:crypto 累加器 Rd 被归为纯 def,但实为 def+use(见文件头"已知缺口")
   (eprintf "警告: crypto 累加器(sha1c/sha1m/sha1p/sha1su0/sha1su1)的 Rd 被归为纯 def,\n")
   (eprintf "      实为 def+use;已提交 use-def-patterns.rktd 含手工修正,regen 后须重新应用。\n")

   ;; 显示示例
   (printf "\n示例:\n")
   (for ([mnem (in-list '(add sub ldr str cmp mov ldp stp))]
         #:when (hash-has-key? db mnem))
     (match-define (list defs uses def-uses) (hash-ref db mnem))
     (printf "  ~a: defs=~a uses=~a def+uses=~a\n"
             mnem defs uses def-uses))))
