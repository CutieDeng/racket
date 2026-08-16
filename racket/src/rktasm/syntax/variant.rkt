#lang racket

(provide
  ;; 语法变体结构
  (struct-out syntax-variant)

  ;; 数据库操作
  load-variant-db
  load-variant-db/default
  load-instruction-variants
  load-variant-classes

  ;; 查询
  lookup-variants-by-mnemonic
  lookup-variant-by-encoding
  lookup-class-by-template
  get-template-class

  ;; 分组工具
  group-variants-by-class
  group-variants-by-mnemonic

  ;; 路径
  default-data-dir)

;; ============================================================
;; 语法变体 (Syntax Variant)
;; ============================================================
;;
;; 两层结构:
;;   1. 具体指令编码 -> 语法变体模板
;;   2. 语法变体模板 -> 语法大类
;;
;; 例如:
;;   "ADD_64_addsub_shift" -> "XZR, XZR, XZR, LSL, UInteger" -> c5
;;   "LDR_64_ldst_immpost" -> "XZR, [XZR], SInteger" -> c1m1

;; 语法变体
;; encoding-id: 指令编码标识符 (如 "ADD_64_addsub_shift")
;; operand-names: 操作数名称列表 (如 '("Xd" "Xn" "Xm" "shift" "amount"))
;; syntax-class: 语法大类 (如 'c5)
;; template: 模板字符串 (如 "XZR, XZR, XZR, LSL, UInteger")
(struct syntax-variant
  (encoding-id
   operand-names
   syntax-class
   template)
  #:transparent)

;; ============================================================
;; 数据库加载
;; ============================================================

(require racket/runtime-path)

;; 默认数据目录 (相对于此文件)
(define-runtime-path default-data-dir "data")

;; 完整数据库结构:
;; - variants: hash[mnemonic -> (listof syntax-variant)]
;; - encoding-map: hash[encoding-id -> syntax-variant]
;; - template-class: hash[template -> syntax-class]

;; 从默认目录加载
(define (load-variant-db/default)
  (load-variant-db default-data-dir))

;; 从目录加载完整数据库
;; 需要: instruction-variants.rktd, variant-class.rktd
(define (load-variant-db dir)
  (define instruction-variants-path (build-path dir "instruction-variants.rktd"))
  (define variant-class-path (build-path dir "variant-class.rktd"))

  ;; 先加载 template -> class 映射
  (define template-class (load-variant-classes variant-class-path))

  ;; 加载 encoding -> template 映射
  (define encoding-template (load-instruction-variants instruction-variants-path))

  ;; 构建完整数据库
  (define by-mnemonic (make-hash))
  (define by-encoding (make-hash))

  (for ([(encoding-id template) (in-hash encoding-template)])
    (define mnemonic (extract-mnemonic-from-encoding encoding-id))
    (define cls (hash-ref template-class template 'unknown))
    (define variant (syntax-variant encoding-id '() cls template))

    (hash-set! by-encoding encoding-id variant)
    (hash-update! by-mnemonic mnemonic
                  (lambda (lst) (cons variant lst))
                  '()))

  ;; 反转列表保持顺序
  (for ([(k v) (in-hash by-mnemonic)])
    (hash-set! by-mnemonic k (reverse v)))

  (values by-mnemonic by-encoding template-class))

;; 加载 instruction-variants.rktd
;; 格式: ("encoding-id" "template")
(define (load-instruction-variants path)
  (define db (make-hash))
  (with-input-from-file path
    (lambda ()
      (let loop ()
        (define datum (read))
        (unless (eof-object? datum)
          (match datum
            [(list encoding-id template)
             (hash-set! db encoding-id template)]
            [_ (void)])
          (loop)))))
  db)

;; 加载 variant-class.rktd
;; 格式: ("template" syntax-class)
(define (load-variant-classes path)
  (define db (make-hash))
  (with-input-from-file path
    (lambda ()
      (let loop ()
        (define datum (read))
        (unless (eof-object? datum)
          (match datum
            [(list template cls)
             (hash-set! db template cls)]
            [_ (void)])
          (loop)))))
  db)

;; ============================================================
;; 查询函数
;; ============================================================

;; 根据助记符查询所有变体
(define (lookup-variants-by-mnemonic db mnemonic)
  (hash-ref db mnemonic '()))

;; 根据编码 ID 查询变体
(define (lookup-variant-by-encoding encoding-db encoding-id)
  (hash-ref encoding-db encoding-id #f))

;; 根据模板查询语法大类
(define (lookup-class-by-template template-db template)
  (hash-ref template-db template #f))

;; 获取模板对应的语法大类
(define (get-template-class template-db template)
  (hash-ref template-db template 'unknown))

;; ============================================================
;; 分组工具
;; ============================================================

;; 按语法大类分组
(define (group-variants-by-class variants)
  (define groups (make-hash))
  (for ([v (in-list variants)])
    (hash-update! groups (syntax-variant-syntax-class v)
                  (lambda (lst) (cons v lst))
                  '()))
  (for ([(k v) (in-hash groups)])
    (hash-set! groups k (reverse v)))
  groups)

;; 按助记符分组
(define (group-variants-by-mnemonic variants)
  (define groups (make-hash))
  (for ([v (in-list variants)])
    (define mnem (extract-mnemonic-from-encoding (syntax-variant-encoding-id v)))
    (hash-update! groups mnem
                  (lambda (lst) (cons v lst))
                  '()))
  (for ([(k v) (in-hash groups)])
    (hash-set! groups k (reverse v)))
  groups)

;; ============================================================
;; 辅助函数
;; ============================================================

;; 从编码 ID 提取助记符
;; "ADD_64_addsub_shift" -> 'add
(define (extract-mnemonic-from-encoding encoding-id)
  (define str (if (string? encoding-id) encoding-id (symbol->string encoding-id)))
  (define parts (string-split str "_"))
  (if (pair? parts)
      (string->symbol (string-downcase (car parts)))
      'unknown))
