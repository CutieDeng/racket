#lang racket

(require "class.rkt"
         "variant.rkt"
         "operand-type.rkt"
         "constraint.rkt")

(provide
  ;; 数据库加载
  load-integrated-db
  load-integrated-db/default

  ;; 层级查找
  lookup-layer1-classes      ; mnemonic -> (listof layer1-class)
  lookup-layer2-signatures   ; mnemonic layer1-class -> (listof layer2-sig)
  lookup-layer3-encodings    ; mnemonic layer1-class layer2-sig -> (listof encoding-info)

  ;; 反向查找
  find-matching-encodings    ; mnemonic actual-class actual-sig values -> (listof encoding-info)

  ;; 诊断辅助
  diagnose-mnemonic-error    ; mnemonic -> error-info
  diagnose-layer1-error      ; mnemonic actual-class -> error-info
  diagnose-layer2-error      ; mnemonic actual-class actual-sig -> error-info

  ;; 编码信息结构
  (struct-out encoding-info))

;; ============================================================
;; 数据结构
;; ============================================================

;; 编码信息
(struct encoding-info
  (encoding-id      ; string
   template         ; string
   layer2-signature ; (listof symbol)
   constraints)     ; (listof (field . constraint))
  #:transparent)

;; 整合数据库结构
;; hash[mnemonic -> (listof layer1-group)]
;; layer1-group = (layer1-class . (listof layer2-group))
;; layer2-group = (layer2-sig . (listof encoding-info))

;; ============================================================
;; 加载数据库
;; ============================================================

(define (load-integrated-db data-dir)
  (define db (make-hash))

  ;; 加载 Layer1 索引
  (define layer1-index (make-hash))
  (with-input-from-file (build-path data-dir "index-layer1.rktd")
    (lambda ()
      (let loop ()
        (define datum (read))
        (unless (eof-object? datum)
          (match datum
            [(list mnem classes)
             (hash-set! layer1-index mnem classes)]
            [_ (void)])
          (loop)))))

  ;; 加载完整表
  (with-input-from-file (build-path data-dir "integrated-table.rktd")
    (lambda ()
      (let loop ()
        (define datum (read))
        (unless (eof-object? datum)
          (when (pair? datum)
            (define mnem (car datum))
            (define hierarchy (parse-hierarchy (cdr datum)))
            (hash-set! db mnem hierarchy))
          (loop)))))

  (values db layer1-index))

(define (load-integrated-db/default)
  (load-integrated-db "syntax/data"))

;; 解析层级结构
(define (parse-hierarchy raw-hierarchy)
  (for/list ([l1-group (in-list raw-hierarchy)])
    (when (pair? l1-group)
      (define l1-class (car l1-group))
      (define l2-groups
        (for/list ([l2-group (in-list (cdr l1-group))]
                   #:when (pair? l2-group))
          (define l2-sig (car l2-group))
          (define entries
            (for/list ([entry (in-list (cdr l2-group))]
                       #:when (and (list? entry) (>= (length entry) 2)))
              (match entry
                [(list enc-id template constraints-raw)
                 (encoding-info enc-id template l2-sig
                               (parse-constraints constraints-raw))]
                [(list enc-id template)
                 (encoding-info enc-id template l2-sig '())]
                [_ #f])))
          (cons l2-sig (filter identity entries))))
      (cons l1-class (filter pair? l2-groups)))))

;; 解析约束
(define (parse-constraints raw)
  (for/list ([c (in-list raw)]
             #:when (pair? c))
    (match c
      [(list field (list 'reg-range min max))
       (cons field (reg-range min max))]
      [(list field (list 'imm-range min max step))
       (cons field (imm-range min max step))]
      [(list field (list 'element-size sizes ...))
       (cons field (element-size sizes))]
      [_ c])))

;; ============================================================
;; 层级查找
;; ============================================================

;; Layer 1: 查找助记符支持的语法类别
(define (lookup-layer1-classes db mnem)
  (define hierarchy (hash-ref db mnem #f))
  (if hierarchy
      (filter symbol? (map car hierarchy))
      '()))

;; Layer 2: 查找特定类别下的签名列表
(define (lookup-layer2-signatures db mnem layer1-class)
  (define hierarchy (hash-ref db mnem '()))
  (define l1-group
    (for/first ([g (in-list hierarchy)]
                #:when (and (pair? g) (eq? (car g) layer1-class)))
      g))
  (if l1-group
      (map car (cdr l1-group))
      '()))

;; Layer 3: 查找特定签名下的编码列表
(define (lookup-layer3-encodings db mnem layer1-class layer2-sig)
  (define hierarchy (hash-ref db mnem '()))
  (define l1-group
    (for/first ([g (in-list hierarchy)]
                #:when (and (pair? g) (eq? (car g) layer1-class)))
      g))
  (if l1-group
      (let ([l2-group
             (for/first ([g (in-list (cdr l1-group))]
                         #:when (and (pair? g) (equal? (car g) layer2-sig)))
               g)])
        (if l2-group (cdr l2-group) '()))
      '()))

;; ============================================================
;; 反向查找 - 找到所有匹配的编码
;; ============================================================

;; 根据实际值查找匹配的编码
;; values: (listof (field . value))
(define (find-matching-encodings db mnem actual-class actual-sig [values '()])
  (define encodings (lookup-layer3-encodings db mnem actual-class actual-sig))

  (if (null? values)
      encodings
      ;; 根据 Layer3 约束过滤
      (filter
       (λ (enc)
         (constraints-satisfied? (encoding-info-constraints enc) values))
       encodings)))

;; 检查约束是否满足
(define (constraints-satisfied? constraints values)
  (for/and ([c (in-list constraints)])
    (define field (car c))
    (define constraint (cdr c))
    (define value (assoc-ref values field))
    (or (not value)  ; 如果没有对应值，跳过检查
        (validate-constraint constraint value))))

(define (assoc-ref alist key)
  (define pair (assoc key alist))
  (and pair (cdr pair)))

;; ============================================================
;; 诊断辅助 - 生成错误信息
;; ============================================================

;; 助记符不存在时的错误信息
(define (diagnose-mnemonic-error db mnem)
  (define all-mnems (hash-keys db))

  ;; 尝试找相似的助记符
  (define similar
    (for/list ([m (in-list all-mnems)]
               #:when (similar-mnemonic? mnem m))
      m))

  (list 'unknown-mnemonic
        mnem
        (format "未知指令助记符: ~a" mnem)
        (if (pair? similar)
            (format "您是否想要: ~a" (string-join (map symbol->string similar) ", "))
            "没有找到相似的助记符")))

;; Layer 1 不匹配时的错误信息
(define (diagnose-layer1-error db mnem actual-class)
  (define allowed (lookup-layer1-classes db mnem))

  (list 'layer1-mismatch
        mnem
        actual-class
        allowed
        (format "~a 的语法结构是 ~a，但 ~a 只支持: ~a"
                mnem actual-class mnem
                (string-join (map symbol->string allowed) ", "))
        (generate-layer1-suggestions actual-class allowed)))

;; Layer 2 不匹配时的错误信息
(define (diagnose-layer2-error db mnem actual-class actual-sig)
  (define allowed-sigs (lookup-layer2-signatures db mnem actual-class))

  (list 'layer2-mismatch
        mnem
        actual-class
        actual-sig
        allowed-sigs
        (format "~a 的操作数类型 ~a 不匹配" mnem actual-sig)
        (generate-layer2-suggestions actual-sig allowed-sigs)))

;; ============================================================
;; 辅助函数
;; ============================================================

;; 相似助记符检测 (简单的编辑距离)
(define (similar-mnemonic? a b)
  (define sa (symbol->string a))
  (define sb (symbol->string b))
  (and (< (abs (- (string-length sa) (string-length sb))) 3)
       (or (string-prefix? sa sb)
           (string-prefix? sb sa)
           (string-suffix? sa sb)
           (string-suffix? sb sa))))

;; Layer 1 建议
(define (generate-layer1-suggestions actual allowed)
  (define suggestions '())

  (define actual-pre (get-pre-count actual))
  (define actual-mem? (has-memory? actual))

  (for ([c (in-list allowed)])
    (define c-pre (get-pre-count c))
    (define c-mem? (has-memory? c))

    (cond
      [(and (not actual-mem?) c-mem?)
       (set! suggestions (cons "需要添加内存操作数 [...]" suggestions))]
      [(and actual-mem? (not c-mem?))
       (set! suggestions (cons "不应包含内存操作数" suggestions))]
      [(> c-pre actual-pre)
       (set! suggestions (cons (format "可能少写了 ~a 个操作数" (- c-pre actual-pre)) suggestions))]
      [(< c-pre actual-pre)
       (set! suggestions (cons (format "可能多写了 ~a 个操作数" (- actual-pre c-pre)) suggestions))]))

  (remove-duplicates suggestions))

;; Layer 2 建议
(define (generate-layer2-suggestions actual-sig allowed-sigs)
  (define suggestions '())

  (for ([expected (in-list allowed-sigs)]
        #:when (= (length expected) (length actual-sig)))
    (for ([i (in-naturals)]
          [act (in-list actual-sig)]
          [exp (in-list expected)]
          #:unless (operand-type-compatible? act exp))
      (set! suggestions
            (cons (format "操作数 ~a: 期望 ~a, 实际 ~a" (add1 i) exp act)
                  suggestions))))

  (remove-duplicates suggestions))
