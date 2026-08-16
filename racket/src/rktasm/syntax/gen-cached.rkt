#!/usr/bin/env racket
#lang racket

;; ============================================================
;; gen-cached.rkt
;; 从 instruction-spec.rktd 重建所有缓存文件
;; ============================================================
;;
;; 生成: data/cached/*.rktd
;;   - index-mnemonic.rktd
;;   - index-layer1.rktd
;;   - index-layer2.rktd
;;   - integrated-table.rktd
;;   - index-alias-transform.rktd

(require "operand-type.rkt"
         "class.rkt")

(provide rebuild-all-caches
         load-instruction-spec
         build-mnemonic-index
         build-layer1-index
         build-layer2-index
         build-integrated-table
         load-alias-signatures
         load-alias-transforms
         merge-alias-layer1
         merge-alias-layer2
         build-alias-transform-index)

;; ============================================================
;; 加载指令规范
;; ============================================================

(define (load-instruction-spec path)
  (with-input-from-file path
    (lambda ()
      (let loop ([specs '()])
        (define datum (read))
        (if (eof-object? datum)
            (reverse specs)
            (loop (cons datum specs)))))))

;; ============================================================
;; Layer 计算函数
;; ============================================================

;; 从模板计算 Layer2 签名
(define (template->layer2 template)
  (parse-template-signature template))

;; 从 Layer2 签名计算 Layer1 类
(define (layer2->layer1 signature)
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
;; 构建索引
;; ============================================================

;; 按助记符索引: mnemonic -> (listof (encoding-id template constraints operand-fields))
(define (build-mnemonic-index specs)
  (define index (make-hash))
  (for ([spec (in-list specs)])
    (match spec
      ;; 新格式 (5 元素)
      [(list enc-id mnem template constraints operand-fields)
       (hash-update! index mnem
                     (λ (lst) (cons (list enc-id template constraints operand-fields) lst))
                     '())]
      ;; 旧格式 (4 元素)
      [(list enc-id mnem template constraints)
       (hash-update! index mnem
                     (λ (lst) (cons (list enc-id template constraints '()) lst))
                     '())]
      [_ (void)]))
  ;; Reverse to preserve order
  (for ([(k v) (in-hash index)])
    (hash-set! index k (reverse v)))
  index)

;; Layer1 索引: mnemonic -> (listof layer1-class)
(define (build-layer1-index specs)
  (define index (make-hash))
  (for ([spec (in-list specs)])
    (match spec
      ;; 支持新旧格式
      [(list enc-id mnem template constraints _ ...)
       (define sig (template->layer2 template))
       (define cls (layer2->layer1 sig))
       (hash-update! index mnem
                     (λ (s) (set-add s cls))
                     (set))]
      [_ (void)]))
  ;; Convert sets to sorted lists
  (for/hash ([(k v) (in-hash index)])
    (values k (sort (set->list v) symbol<?))))

;; Layer2 索引: (mnemonic layer1-class) -> (listof layer2-signature)
(define (build-layer2-index specs)
  (define index (make-hash))
  (for ([spec (in-list specs)])
    (match spec
      ;; 支持新旧格式
      [(list enc-id mnem template constraints _ ...)
       (define sig (template->layer2 template))
       (define cls (layer2->layer1 sig))
       (define key (list mnem cls))
       (hash-update! index key
                     (λ (s) (set-add s sig))
                     (set))]
      [_ (void)]))
  ;; Convert sets to lists
  (for/hash ([(k v) (in-hash index)])
    (values k (set->list v))))

;; 完整整合表: mnemonic -> layer1 -> layer2 -> (listof encoding-info)
(define (build-integrated-table specs)
  (define table (make-hash))

  (for ([spec (in-list specs)])
    (match spec
      ;; 新格式 (5 元素)
      [(list enc-id mnem template constraints operand-fields)
       (define sig (template->layer2 template))
       (define cls (layer2->layer1 sig))

       ;; 获取或创建 mnemonic 的 layer1 hash
       (unless (hash-has-key? table mnem)
         (hash-set! table mnem (make-hash)))
       (define l1-table (hash-ref table mnem))

       ;; 获取或创建 layer1-class 的 layer2 hash
       (unless (hash-has-key? l1-table cls)
         (hash-set! l1-table cls (make-hash)))
       (define l2-table (hash-ref l1-table cls))

       ;; 获取或创建 layer2-sig 的 encoding list
       (define sig-key (format "~s" sig))
       (hash-update! l2-table sig-key
                     (λ (lst) (cons (list enc-id template constraints operand-fields) lst))
                     '())]
      ;; 旧格式 (4 元素)
      [(list enc-id mnem template constraints)
       (define sig (template->layer2 template))
       (define cls (layer2->layer1 sig))

       (unless (hash-has-key? table mnem)
         (hash-set! table mnem (make-hash)))
       (define l1-table (hash-ref table mnem))

       (unless (hash-has-key? l1-table cls)
         (hash-set! l1-table cls (make-hash)))
       (define l2-table (hash-ref l1-table cls))

       (define sig-key (format "~s" sig))
       (hash-update! l2-table sig-key
                     (λ (lst) (cons (list enc-id template constraints '()) lst))
                     '())]
      [_ (void)]))

  table)

;; ============================================================
;; 别名处理
;; ============================================================

;; 加载别名签名规范
(define (load-alias-signatures path)
  (if (file-exists? path)
      (with-input-from-file path
        (lambda ()
          (let loop ([aliases '()])
            (define datum (read))
            (if (eof-object? datum)
                (reverse aliases)
                (loop (cons datum aliases))))))
      '()))

;; 加载别名转换规则
(define (load-alias-transforms path)
  (if (file-exists? path)
      (with-input-from-file path
        (lambda ()
          (let loop ([transforms '()])
            (define datum (read))
            (if (eof-object? datum)
                (reverse transforms)
                (loop (cons datum transforms))))))
      '()))

;; 加载自定义别名
;; 格式: (mnemonic (class signature) target-mnemonic transform)
;; 返回两个值: alias-sigs 和 alias-transforms 格式的列表
(define (load-custom-aliases path)
  (if (file-exists? path)
      (with-input-from-file path
        (lambda ()
          (define sigs-hash (make-hash))
          (define transforms-hash (make-hash))
          (let loop ()
            (define datum (read))
            (unless (eof-object? datum)
              (match datum
                [(list mnem (list cls sig) target-mnem transform)
                 ;; 添加到签名
                 (hash-update! sigs-hash mnem
                               (lambda (lst) (cons (list cls sig) lst))
                               '())
                 ;; 添加到转换
                 (hash-update! transforms-hash mnem
                               (lambda (lst) (cons (list (list cls sig) target-mnem transform) lst))
                               '())]
                [_ (void)])
              (loop)))
          ;; 转换为列表格式
          (values
           (for/list ([(mnem entries) (in-hash sigs-hash)])
             (list mnem entries))
           (for/list ([(mnem entries) (in-hash transforms-hash)])
             (cons mnem entries)))))
      (values '() '())))

;; 将别名签名合并到 Layer1 索引
;; alias-sigs: ((alias-mnem ((class sig) ...)) ...)
(define (merge-alias-layer1 l1-index alias-sigs)
  (define merged (hash-copy l1-index))
  (for ([alias-spec (in-list alias-sigs)])
    (match alias-spec
      [(list mnem entries)
       (define classes
         (remove-duplicates
          (for/list ([entry (in-list entries)])
            (car entry))))  ; (class sig) -> class
       (define existing (hash-ref merged mnem '()))
       (define new-classes
         (sort (remove-duplicates (append existing classes)) symbol<?))
       (hash-set! merged mnem new-classes)]
      [_ (void)]))
  merged)

;; 将别名签名合并到 Layer2 索引
(define (merge-alias-layer2 l2-index alias-sigs)
  (define merged (hash-copy l2-index))
  (for ([alias-spec (in-list alias-sigs)])
    (match alias-spec
      [(list mnem entries)
       (for ([entry (in-list entries)])
         (match entry
           [(list cls sig)
            (define key (list mnem cls))
            (define existing (hash-ref merged key '()))
            (unless (member sig existing)
              (hash-set! merged key (cons sig existing)))]
           [_ (void)]))]
      [_ (void)]))
  merged)

;; 构建别名转换索引
;; 格式: (alias-mnem class sig) -> (target-mnem . transform-rule)
(define (build-alias-transform-index alias-transforms)
  (define index (make-hash))
  (for ([transform-spec (in-list alias-transforms)])
    (match transform-spec
      [(list-rest mnem rules)
       (for ([rule (in-list rules)])
         (match rule
           [(list (list cls sig) target-mnem transform)
            (define key (list mnem cls sig))
            (define new-val (cons target-mnem transform))
            ;; 检查是否已存在更好的转换
            (define existing (hash-ref index key #f))
            (cond
              [(not existing)
               ;; 没有现有值，直接设置
               (hash-set! index key new-val)]
              [(transform-has-shift-keyword? transform)
               ;; 新转换有 shift 关键字，优先使用
               (hash-set! index key new-val)]
              [else
               ;; 保留现有的（可能有 shift 关键字）
               (void)])]
           [_ (void)]))]
      [_ (void)]))
  index)

;; 检查转换规则是否包含移位关键字 (const lsl/lsr/asr/ror)
(define (transform-has-shift-keyword? transform)
  (for/or ([elem (in-list transform)])
    (and (pair? elem)
         (eq? (car elem) 'const)
         (memq (cadr elem) '(lsl lsr asr ror)))))

;; 保存别名转换索引
(define (save-alias-transform-index index output-path)
  (call-with-output-file output-path
    (lambda (out)
      (fprintf out ";; 别名转换索引: (alias-mnem class sig) -> (target-mnem . transform)\n")
      (fprintf out ";; 生成命令: racket syntax/gen-cached.rkt\n\n")
      (for ([(key val) (in-hash index)])
        (fprintf out "(~s ~s)\n" key val)))
    #:exists 'replace)
  (printf "  已保存: ~a\n" output-path))

;; ============================================================
;; 保存缓存文件
;; ============================================================

(define (save-mnemonic-index index output-path)
  (call-with-output-file output-path
    (lambda (out)
      (fprintf out ";; 助记符索引: mnemonic -> ((encoding-id template constraints) ...)\n")
      (fprintf out ";; 生成命令: racket syntax/gen-cached.rkt\n\n")
      (for ([(mnem entries) (in-hash index)])
        (fprintf out "(~a\n" mnem)
        (for ([e (in-list entries)])
          (fprintf out "  ~s\n" e))
        (fprintf out ")\n\n")))
    #:exists 'replace)
  (printf "  已保存: ~a\n" output-path))

(define (save-layer1-index index output-path)
  (call-with-output-file output-path
    (lambda (out)
      (fprintf out ";; Layer1 索引: mnemonic -> (layer1-classes ...)\n")
      (fprintf out ";; 生成命令: racket syntax/gen-cached.rkt\n\n")
      (for ([(mnem classes) (in-hash index)])
        (fprintf out "(~a ~a)\n" mnem classes)))
    #:exists 'replace)
  (printf "  已保存: ~a\n" output-path))

(define (save-layer2-index index output-path)
  (call-with-output-file output-path
    (lambda (out)
      (fprintf out ";; Layer2 索引: (mnemonic layer1-class) -> (signatures ...)\n")
      (fprintf out ";; 生成命令: racket syntax/gen-cached.rkt\n\n")
      (for ([(key sigs) (in-hash index)])
        (fprintf out "(~s ~s)\n" key sigs)))
    #:exists 'replace)
  (printf "  已保存: ~a\n" output-path))

(define (save-integrated-table table output-path)
  (call-with-output-file output-path
    (lambda (out)
      (fprintf out ";; 整合表: mnemonic -> layer1 -> layer2 -> encodings\n")
      (fprintf out ";; 生成命令: racket syntax/gen-cached.rkt\n\n")
      (for ([(mnem l1-table) (in-hash table)])
        (fprintf out "(~a\n" mnem)
        (for ([(cls l2-table) (in-hash l1-table)])
          (fprintf out "  (~a\n" cls)
          (for ([(sig-key entries) (in-hash l2-table)])
            (fprintf out "    (~a\n" sig-key)
            (for ([e (in-list (reverse entries))])
              (fprintf out "      ~s\n" e))
            (fprintf out "    )\n"))
          (fprintf out "  )\n"))
        (fprintf out ")\n\n")))
    #:exists 'replace)
  (printf "  已保存: ~a\n" output-path))

;; ============================================================
;; 重建所有缓存
;; ============================================================

(define (rebuild-all-caches spec-path cache-dir
                            #:alias-sig-path [alias-sig-path #f]
                            #:alias-transform-path [alias-transform-path #f]
                            #:custom-alias-path [custom-alias-path #f])
  (printf "加载指令规范: ~a\n" spec-path)
  (define specs (load-instruction-spec spec-path))
  (printf "已加载 ~a 条记录\n\n" (length specs))

  ;; 加载别名规范
  (define alias-sigs-base
    (if alias-sig-path
        (begin
          (printf "加载别名签名: ~a\n" alias-sig-path)
          (load-alias-signatures alias-sig-path))
        '()))
  (define alias-transforms-base
    (if alias-transform-path
        (begin
          (printf "加载别名转换: ~a\n" alias-transform-path)
          (load-alias-transforms alias-transform-path))
        '()))

  ;; 加载自定义别名
  (define-values (custom-sigs custom-transforms)
    (if custom-alias-path
        (begin
          (printf "加载自定义别名: ~a\n" custom-alias-path)
          (load-custom-aliases custom-alias-path))
        (values '() '())))

  ;; 合并别名 (自定义优先)
  (define alias-sigs (append custom-sigs alias-sigs-base))
  (define alias-transforms (append custom-transforms alias-transforms-base))

  (when (pair? alias-sigs)
    (printf "已加载 ~a 个别名定义\n\n" (length alias-sigs)))

  (printf "构建缓存文件...\n")

  ;; 构建各索引
  (define mnem-index (build-mnemonic-index specs))
  (define l1-index-base (build-layer1-index specs))
  (define l2-index-base (build-layer2-index specs))
  (define integrated (build-integrated-table specs))

  ;; 合并别名到索引
  (define l1-index (merge-alias-layer1 l1-index-base alias-sigs))
  (define l2-index (merge-alias-layer2 l2-index-base alias-sigs))
  (define alias-transform-index (build-alias-transform-index alias-transforms))

  ;; 保存
  (make-directory* cache-dir)
  (save-mnemonic-index mnem-index (build-path cache-dir "index-mnemonic.rktd"))
  (save-layer1-index l1-index (build-path cache-dir "index-layer1.rktd"))
  (save-layer2-index l2-index (build-path cache-dir "index-layer2.rktd"))
  (save-integrated-table integrated (build-path cache-dir "integrated-table.rktd"))
  (when (hash? alias-transform-index)
    (save-alias-transform-index alias-transform-index
                                (build-path cache-dir "index-alias-transform.rktd")))

  (printf "\n完成!\n"))

;; ============================================================
;; 主程序
;; ============================================================

(module+ main
  (require racket/cmdline)

  (define spec-path
    (make-parameter "syntax/data/generated/instruction-spec.rktd"))
  (define cache-dir
    (make-parameter "syntax/data/cached"))
  (define alias-sig-path
    (make-parameter "syntax/data/alias-signatures.rktd"))
  (define alias-transform-path
    (make-parameter "syntax/data/alias-transforms.rktd"))
  (define custom-alias-path
    (make-parameter "syntax/data/custom-aliases.rktd"))

  (command-line
   #:program "gen-cached"
   #:once-each
   [("-s" "--spec") path "Path to instruction-spec.rktd" (spec-path path)]
   [("-c" "--cache") dir "Cache output directory" (cache-dir dir)]
   [("--alias-sig") path "Path to alias-signatures.rktd" (alias-sig-path path)]
   [("--alias-transform") path "Path to alias-transforms.rktd" (alias-transform-path path)]
   [("--custom-alias") path "Path to custom-aliases.rktd" (custom-alias-path path)]
   #:args ()

   (rebuild-all-caches (spec-path) (cache-dir)
                       #:alias-sig-path (alias-sig-path)
                       #:alias-transform-path (alias-transform-path)
                       #:custom-alias-path (custom-alias-path))))
