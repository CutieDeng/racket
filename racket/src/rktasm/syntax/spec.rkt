#lang racket

;; ============================================================
;; syntax/spec.rkt - 指令规范加载与缓存
;; ============================================================
;;
;; 多级缓存策略:
;;   Level 0: instruction-spec.rktd (磁盘)
;;   Level 1: cached/*.rktd (磁盘缓存，可重建)
;;   Level 2: 内存缓存 (运行时)
;;   Level 3: 计算缓存 (Layer2/Layer1 计算结果)

(require "operand-type.rkt"
         "class.rkt"
         "constraint.rkt"
         racket/runtime-path)

(provide
  ;; 数据库加载
  get-spec-db           ; 获取规范数据库 (懒加载)
  get-mnemonic-index    ; 获取助记符索引
  get-layer1-index      ; 获取 Layer1 索引
  get-layer2-index      ; 获取 Layer2 索引
  get-integrated-table  ; 获取整合表
  get-constraint-db     ; 获取约束数据库

  ;; 查询接口
  lookup-by-mnemonic    ; 按助记符查找
  lookup-layer1-classes ; 查找 Layer1 类
  lookup-layer2-sigs    ; 查找 Layer2 签名
  lookup-encodings      ; 查找具体编码
  get-encoding-operand-fields  ; 获取编码的操作数字段

  ;; 计算接口 (带缓存)
  template->layer2/cached
  layer2->layer1/cached

  ;; 缓存控制
  clear-all-caches!
  preload-all!)

;; ============================================================
;; 路径配置
;; ============================================================

(define-runtime-path data-root "data")
(define generated-dir (build-path data-root "generated"))
(define cached-dir (build-path data-root "cached"))

(define spec-path (build-path generated-dir "instruction-spec.rktd"))
(define mnemonic-index-path (build-path cached-dir "index-mnemonic.rktd"))
(define layer1-index-path (build-path cached-dir "index-layer1.rktd"))
(define layer2-index-path (build-path cached-dir "index-layer2.rktd"))
(define integrated-path (build-path cached-dir "integrated-table.rktd"))

;; ============================================================
;; Level 2: 内存缓存
;; ============================================================

;; 缓存容器 (使用 box 实现懒加载)
(define *spec-db* (box #f))
(define *mnemonic-index* (box #f))
(define *layer1-index* (box #f))
(define *layer2-index* (box #f))
(define *integrated-table* (box #f))
(define *constraint-db* (box #f))

;; Level 3: 计算缓存
(define *template->layer2-cache* (make-hash))
(define *layer2->layer1-cache* (make-hash))

;; ============================================================
;; 懒加载实现
;; ============================================================

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

(define (load-as-hash path key-fn)
  (define h (make-hash))
  (for ([item (load-sexp-file path)])
    (when (pair? item)
      (hash-set! h (key-fn item) item)))
  h)

;; 获取规范数据库 (懒加载)
(define (get-spec-db)
  (unless (unbox *spec-db*)
    (set-box! *spec-db* (load-sexp-file spec-path)))
  (unbox *spec-db*))

;; 获取助记符索引 (懒加载，优先使用缓存文件)
(define (get-mnemonic-index)
  (unless (unbox *mnemonic-index*)
    (set-box! *mnemonic-index*
              (if (file-exists? mnemonic-index-path)
                  (load-as-hash mnemonic-index-path car)
                  (build-mnemonic-index-from-spec))))
  (unbox *mnemonic-index*))

;; 获取 Layer1 索引
(define (get-layer1-index)
  (unless (unbox *layer1-index*)
    (set-box! *layer1-index*
              (if (file-exists? layer1-index-path)
                  (load-layer1-index-file)
                  (build-layer1-index-from-spec))))
  (unbox *layer1-index*))

;; 获取 Layer2 索引
(define (get-layer2-index)
  (unless (unbox *layer2-index*)
    (set-box! *layer2-index*
              (if (file-exists? layer2-index-path)
                  (load-layer2-index-file)
                  (build-layer2-index-from-spec))))
  (unbox *layer2-index*))

;; 获取整合表
(define (get-integrated-table)
  (unless (unbox *integrated-table*)
    (set-box! *integrated-table*
              (if (file-exists? integrated-path)
                  (load-as-hash integrated-path car)
                  (build-integrated-from-spec))))
  (unbox *integrated-table*))

;; 获取约束数据库 (从 instruction-spec.rktd 提取)
;; 格式: hash[encoding-id -> hash[field-name -> constraint]]
(define (get-constraint-db)
  (unless (unbox *constraint-db*)
    (set-box! *constraint-db* (build-constraint-db-from-spec)))
  (unbox *constraint-db*))

;; 从 instruction-spec.rktd 构建约束数据库
(define (build-constraint-db-from-spec)
  (define h (make-hash))
  (for ([spec (get-spec-db)])
    (match spec
      ;; 新格式 (5 元素): enc-id mnem template constraints operand-fields
      [(list enc-id mnem template constraints operand-fields)
       (define field-hash (make-hash))
       (for ([c (in-list constraints)])
         (match c
           [(list field-name constraint-sexp)
            (define constraint (sexp->constraint constraint-sexp))
            (when constraint
              (hash-set! field-hash field-name constraint))]
           [_ (void)]))
       (hash-set! h enc-id field-hash)]
      ;; 旧格式 (4 元素): enc-id mnem template constraints
      [(list enc-id mnem template constraints)
       (define field-hash (make-hash))
       (for ([c (in-list constraints)])
         (match c
           [(list field-name constraint-sexp)
            (define constraint (sexp->constraint constraint-sexp))
            (when constraint
              (hash-set! field-hash field-name constraint))]
           [_ (void)]))
       (hash-set! h enc-id field-hash)]
      [_ (void)]))
  h)

;; 将 S-表达式转换为约束结构
(define (sexp->constraint sexp)
  (match sexp
    [(list 'reg-range min max)
     (reg-range min max)]
    [(list 'imm-range min max step)
     (imm-range min max step)]
    [(list 'imm-values vals ...)
     (imm-values vals)]
    [(list 'element-size sizes ...)
     (element-size sizes)]
    [_ #f]))

;; ============================================================
;; 从磁盘缓存加载
;; ============================================================

(define (load-layer1-index-file)
  (define h (make-hash))
  (for ([item (load-sexp-file layer1-index-path)])
    (match item
      [(list mnem classes)
       (hash-set! h mnem classes)]
      [_ (void)]))
  h)

(define (load-layer2-index-file)
  (define h (make-hash))
  (for ([item (load-sexp-file layer2-index-path)])
    (match item
      [(list (list mnem cls) sigs)
       (hash-set! h (cons mnem cls) sigs)]
      [_ (void)]))
  h)

;; ============================================================
;; 从规范构建索引 (当缓存不存在时)
;; ============================================================

(define (build-mnemonic-index-from-spec)
  (define h (make-hash))
  (for ([spec (get-spec-db)])
    (match spec
      ;; 新格式 (5 元素)
      [(list enc-id mnem template constraints operand-fields)
       (hash-update! h mnem
                     (λ (lst) (cons (list enc-id template constraints operand-fields) lst))
                     '())]
      ;; 旧格式 (4 元素)
      [(list enc-id mnem template constraints)
       (hash-update! h mnem
                     (λ (lst) (cons (list enc-id template constraints '()) lst))
                     '())]
      [_ (void)]))
  (for ([(k v) (in-hash h)])
    (hash-set! h k (reverse v)))
  h)

(define (build-layer1-index-from-spec)
  (define h (make-hash))
  (for ([spec (get-spec-db)])
    (match spec
      ;; 新格式或旧格式都能匹配
      [(list enc-id mnem template constraints _ ...)
       (define l2 (template->layer2/cached template))
       (define l1 (layer2->layer1/cached l2))
       (hash-update! h mnem (λ (s) (set-add s l1)) (set))]
      [_ (void)]))
  (for/hash ([(k v) (in-hash h)])
    (values k (sort (set->list v) symbol<?))))

(define (build-layer2-index-from-spec)
  (define h (make-hash))
  (for ([spec (get-spec-db)])
    (match spec
      ;; 新格式或旧格式都能匹配
      [(list enc-id mnem template constraints _ ...)
       (define l2 (template->layer2/cached template))
       (define l1 (layer2->layer1/cached l2))
       (hash-update! h (cons mnem l1) (λ (s) (set-add s l2)) (set))]
      [_ (void)]))
  (for/hash ([(k v) (in-hash h)])
    (values k (set->list v))))

(define (build-integrated-from-spec)
  (define h (make-hash))
  (for ([spec (get-spec-db)])
    (match spec
      ;; 新格式 (5 元素)
      [(list enc-id mnem template constraints operand-fields)
       (define l2 (template->layer2/cached template))
       (define l1 (layer2->layer1/cached l2))
       ;; 创建层级结构
       (unless (hash-has-key? h mnem)
         (hash-set! h mnem (make-hash)))
       (define l1-h (hash-ref h mnem))
       (unless (hash-has-key? l1-h l1)
         (hash-set! l1-h l1 (make-hash)))
       (define l2-h (hash-ref l1-h l1))
       (define l2-key (format "~s" l2))
       (hash-update! l2-h l2-key
                     (λ (lst) (cons (list enc-id template constraints operand-fields) lst))
                     '())]
      ;; 旧格式 (4 元素)
      [(list enc-id mnem template constraints)
       (define l2 (template->layer2/cached template))
       (define l1 (layer2->layer1/cached l2))
       (unless (hash-has-key? h mnem)
         (hash-set! h mnem (make-hash)))
       (define l1-h (hash-ref h mnem))
       (unless (hash-has-key? l1-h l1)
         (hash-set! l1-h l1 (make-hash)))
       (define l2-h (hash-ref l1-h l1))
       (define l2-key (format "~s" l2))
       (hash-update! l2-h l2-key
                     (λ (lst) (cons (list enc-id template constraints '()) lst))
                     '())]
      [_ (void)]))
  h)

;; ============================================================
;; Level 3: 计算缓存
;; ============================================================

;; 带缓存的 template -> Layer2
(define (template->layer2/cached template)
  (hash-ref! *template->layer2-cache* template
             (λ () (parse-template-signature template))))

;; 带缓存的 Layer2 -> Layer1
(define (layer2->layer1/cached signature)
  (define key (format "~s" signature))
  (hash-ref! *layer2->layer1-cache* key
             (λ () (compute-layer1 signature))))

(define (compute-layer1 signature)
  (define mem-idx
    (for/first ([i (in-naturals)]
                [t (in-list signature)]
                #:when (eq? t 'memory))
      i))
  (define has-mem? (and mem-idx #t))
  (define pre (or mem-idx (length signature)))
  (define post (if has-mem? (- (length signature) mem-idx 1) 0))
  (classify-operand-count pre has-mem? post))

;; ============================================================
;; 查询接口
;; ============================================================

;; 按助记符查找所有编码
(define (lookup-by-mnemonic mnem)
  (define index (get-mnemonic-index))
  (hash-ref index mnem '()))

;; 查找助记符支持的 Layer1 类
(define (lookup-layer1-classes mnem)
  (define index (get-layer1-index))
  (hash-ref index mnem '()))

;; 查找 (助记符, Layer1) 支持的 Layer2 签名
(define (lookup-layer2-sigs mnem layer1-class)
  (define index (get-layer2-index))
  (hash-ref index (cons mnem layer1-class) '()))

;; 查找匹配的具体编码
;; 整合表格式: (mnemonic (layer1 ((layer2-sig) encoding ...) ...) ...)
(define (lookup-encodings mnem layer1-class layer2-sig)
  (define table (get-integrated-table))
  (define mnem-entry (hash-ref table mnem #f))
  (cond
    [(not mnem-entry) '()]
    [(pair? mnem-entry)
     ;; mnem-entry 格式: (mnemonic (l1 (sig enc ...) ...) ...)
     ;; 跳过第一个元素 (mnemonic)，找 layer1 条目
     (define l1-entries (cdr mnem-entry))
     (define l1-entry
       (for/first ([e (in-list l1-entries)]
                   #:when (and (pair? e) (eq? (car e) layer1-class)))
         e))
     (cond
       [(not l1-entry) '()]
       [else
        ;; l1-entry 格式: (layer1 ((sig) enc ...) ...)
        (define sig-entries (cdr l1-entry))
        (define l2-key-str (format "~s" layer2-sig))
        ;; 找匹配的 layer2 签名
        (define sig-entry
          (for/first ([e (in-list sig-entries)]
                      #:when (and (pair? e)
                                  (list? (car e))  ; 签名可以是空列表
                                  (equal? (format "~s" (car e)) l2-key-str)))
            e))
        (if sig-entry
            (cdr sig-entry)  ; 返回编码列表
            '())])]
    [else '()]))

;; 从编码条目获取操作数字段列表
;; encoding: (enc-id template constraints operand-fields) 或 (enc-id template constraints)
;; 返回: (listof string) 或 '()
(define (get-encoding-operand-fields encoding)
  (cond
    [(and (list? encoding) (>= (length encoding) 4))
     (list-ref encoding 3)]
    [else '()]))

;; ============================================================
;; 缓存控制
;; ============================================================

(define (clear-all-caches!)
  (set-box! *spec-db* #f)
  (set-box! *mnemonic-index* #f)
  (set-box! *layer1-index* #f)
  (set-box! *layer2-index* #f)
  (set-box! *integrated-table* #f)
  (set-box! *constraint-db* #f)
  (hash-clear! *template->layer2-cache*)
  (hash-clear! *layer2->layer1-cache*))

(define (preload-all!)
  (get-spec-db)
  (get-mnemonic-index)
  (get-layer1-index)
  (get-layer2-index)
  (get-integrated-table))
