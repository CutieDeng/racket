#lang racket

(provide
  ;; 语法大类
  syntax-class?
  syntax-class->string
  parse-syntax-class

  ;; 语法大类数据库
  syntax-class-db?
  load-syntax-class-db
  lookup-syntax-classes
  all-mnemonics

  ;; 分类工具
  classify-operand-count
  has-memory?
  has-post-index?
  get-pre-count
  get-post-count)

;; ============================================================
;; 语法大类 (Syntax Class)
;; ============================================================
;;
;; 编码规则:
;;   cN     = N 个操作数，无内存         (add x.d x.a x.b -> c3)
;;   cNm    = N 个操作数 + 内存           (ldr x.d [x.base] -> c1m)
;;   cNmK   = N 个操作数 + 内存 + K 后操作数  (ldr x.d [x.base] imm -> c1m1)
;;   cmNm   = 花括号内存 + N 操作数 + 真实内存  (SME 指令)
;;
;; 示例:
;;   c0   = 0 操作数              (nop)
;;   c1   = 1 操作数              (br x.target)
;;   c3   = 3 操作数              (add x.d x.a x.b)
;;   c5   = 5 操作数              (add x.d x.a x.b lsl 3)
;;   c1m  = 1 操作数 + 内存       (ldr x.d [x.base offset])
;;   c1m1 = 1 操作数 + 内存 + 1 后  (ldr x.d [x.base] imm)
;;   c2m1 = 2 操作数 + 内存 + 1 后  (stp x.a x.b [x.base] imm)

;; ============================================================
;; 语法大类类型
;; ============================================================

;; 语法大类是一个 symbol: 'c0, 'c1, 'c2, 'c3, 'c1m, 'c1m1, ...
(define (syntax-class? x)
  (and (symbol? x)
       (regexp-match? #rx"^c[m]?[0-9]+[m]?[0-9]*$" (symbol->string x))))

(define (syntax-class->string cls)
  (symbol->string cls))

(define (parse-syntax-class str)
  (define sym (if (symbol? str) str (string->symbol str)))
  (and (syntax-class? sym) sym))

;; ============================================================
;; 语法大类解析工具
;; ============================================================

;; 从语法大类提取信息
;; c3 -> (values 3 #f 0)
;; c1m -> (values 1 #t 0)
;; c2m1 -> (values 2 #t 1)
;; cm1m -> (values 1 #t 0) with brace-memory
(define (parse-class-components cls)
  (define str (symbol->string cls))
  (match (regexp-match #rx"^c(m)?([0-9]+)(m)?([0-9]*)$" str)
    [(list _ brace-m pre-str mem-m post-str)
     (values (string->number pre-str)
             (or brace-m mem-m)
             (if (string=? post-str "") 0 (string->number post-str)))]
    [_ (values 0 #f 0)]))

;; 是否有内存操作数
(define (has-memory? cls)
  (define-values (_ mem? __) (parse-class-components cls))
  (and mem? #t))

;; 是否有后索引操作数
(define (has-post-index? cls)
  (define-values (_ __ post) (parse-class-components cls))
  (> post 0))

;; 获取内存前操作数数量
(define (get-pre-count cls)
  (define-values (pre _ __) (parse-class-components cls))
  pre)

;; 获取内存后操作数数量
(define (get-post-count cls)
  (define-values (_ __ post) (parse-class-components cls))
  post)

;; 根据指令结构分类
;; operand-count: 操作数数量
;; has-mem?: 是否有内存
;; post-count: 后索引操作数数量
(define (classify-operand-count operand-count has-mem? [post-count 0])
  (cond
    [(not has-mem?)
     (string->symbol (format "c~a" operand-count))]
    [(= post-count 0)
     (string->symbol (format "c~am" operand-count))]
    [else
     (string->symbol (format "c~am~a" operand-count post-count))]))

;; ============================================================
;; 语法大类数据库
;; ============================================================

;; 数据库结构: hash[symbol -> (listof symbol)]
;; mnemonic -> (list of syntax-classes)
(define (syntax-class-db? x)
  (and (hash? x)
       (for/and ([(k v) (in-hash x)])
         (and (symbol? k)
              (list? v)
              (andmap syntax-class? v)))))

;; 从 .rktd 文件加载数据库
;; 文件格式: 每行一个 (mnemonic (class1 class2 ...))
(define (load-syntax-class-db path)
  (define db (make-hash))
  (with-input-from-file path
    (lambda ()
      (let loop ()
        (define datum (read))
        (unless (eof-object? datum)
          (match datum
            [(list mnem classes)
             (hash-set! db mnem classes)]
            [_ (void)])
          (loop)))))
  db)

;; 查询助记符支持的语法大类
(define (lookup-syntax-classes db mnemonic)
  (hash-ref db mnemonic '()))

;; 获取所有助记符
(define (all-mnemonics db)
  (hash-keys db))
