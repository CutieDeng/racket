#lang racket

;; ============================================================
;; optional-extractor.rkt
;; 从 MRS Instructions.json 提取 optional_shift / optional_extend 信息
;; 自动生成别名签名和转换规则
;; ============================================================

(require json
         "../../syntax/operand-type.rkt"
         "../../syntax/class.rkt")

(provide extract-optional-aliases)

;; ============================================================
;; MRS 数据加载
;; ============================================================

(define (load-mrs-json path)
  (with-input-from-file path read-json))

;; ============================================================
;; 从 MRS 提取含 optional_shift 的编码名
;; ============================================================

;; 递归查找所有 Instruction.Instruction 节点
(define (find-instruction-nodes node)
  (cond
    [(hash? node)
     (define t (hash-ref node '_type ""))
     (define children
       (apply append
              (for/list ([v (in-hash-values node)])
                (find-instruction-nodes v))))
     (if (equal? t "Instruction.Instruction")
         (cons node children)
         children)]
    [(list? node)
     (apply append (map find-instruction-nodes node))]
    [else '()]))

;; 从指令节点提取: (name, optional-rule-id) 或 #f
(define (extract-optional-info node)
  (define name (hash-ref node 'name #f))
  (define asm (hash-ref node 'assembly #f))
  (when (and name asm (hash? asm))
    (define symbols (hash-ref asm 'symbols '()))
    (for/first ([sym (in-list symbols)]
                #:when (and (hash? sym)
                            (let ([rid (hash-ref sym 'rule_id "")])
                              (string-prefix? rid "optional_"))))
      (cons name (hash-ref sym 'rule_id)))))

;; ============================================================
;; 从 instruction-spec.rktd 获取签名信息
;; ============================================================

(define (load-spec path)
  (with-input-from-file path
    (lambda ()
      (let loop ([specs '()])
        (define datum (read))
        (if (eof-object? datum)
            (reverse specs)
            (loop (cons datum specs)))))))

;; ============================================================
;; 生成别名数据
;; ============================================================

;; 判断签名末尾是否是 shift 部分: (... keyword immediate)
(define (has-shift-suffix? sig)
  (and (>= (length sig) 2)
       (let ([last2 (take-right sig 2)])
         (and (eq? (car last2) 'keyword)
              (eq? (cadr last2) 'immediate)))))

;; 去掉签名末尾的 shift 部分
(define (strip-shift-suffix sig)
  (if (has-shift-suffix? sig)
      (drop-right sig 2)
      sig))

;; 从 spec 中找到编码的签名
(define (spec->sig-map specs)
  (define h (make-hash))
  (for ([spec (in-list specs)])
    (match spec
      [(list enc-id mnem template constraints)
       (define sig (parse-template-signature template))
       (hash-set! h enc-id (list mnem sig))]
      [_ (void)]))
  h)

;; ============================================================
;; 主提取函数
;; ============================================================

(define (extract-optional-aliases mrs-path spec-path)
  ;; 1. 从 MRS 提取含 optional_shift 的编码名
  (define mrs-data (load-mrs-json mrs-path))
  (define all-instructions (find-instruction-nodes mrs-data))
  (printf "MRS 指令节点数: ~a\n" (length all-instructions))

  (define optional-entries
    (filter-map extract-optional-info all-instructions))
  (printf "含 optional_ 的编码数: ~a\n" (length optional-entries))

  ;; 按 optional 类型分组
  (define shift-encodings
    (filter (lambda (p) (string-prefix? (cdr p) "optional_shift")) optional-entries))
  (define extend-encodings
    (filter (lambda (p) (string-prefix? (cdr p) "optional_extend")) optional-entries))
  (printf "  optional_shift: ~a\n" (length shift-encodings))
  (printf "  optional_extend: ~a\n" (length extend-encodings))

  ;; 2. 从 spec 获取签名
  (define specs (load-spec spec-path))
  (define sig-map (spec->sig-map specs))
  (printf "\nspec 记录数: ~a\n" (hash-count sig-map))

  ;; 3. 对每个含 optional_shift 的编码，检查签名是否有 shift 后缀
  (define alias-entries (make-hash))  ; mnem -> ((class short-sig) ...)

  (for ([entry (in-list shift-encodings)])
    (define enc-name (car entry))
    (define info (hash-ref sig-map enc-name #f))
    (when info
      (define mnem (car info))
      (define full-sig (cadr info))
      (when (has-shift-suffix? full-sig)
        (define short-sig (strip-shift-suffix full-sig))
        (define short-class (classify-operand-count
                              (length (takef short-sig (lambda (t) (not (eq? t 'memory)))))
                              (memq 'memory short-sig)
                              0))
        ;; 只添加 short-sig 不同于 full-sig 的情况
        (define key (list mnem short-class short-sig))
        (unless (hash-has-key? alias-entries key)
          (hash-set! alias-entries key
                     (list enc-name mnem full-sig short-sig short-class))))))

  ;; 4. 汇总
  ;; 按 mnem 分组
  (define by-mnem (make-hash))
  (for ([(key val) (in-hash alias-entries)])
    (match key
      [(list mnem cls sig)
       (hash-update! by-mnem mnem
                     (lambda (lst) (cons (list cls sig) lst))
                     '())]
      [_ (void)]))

  ;; 构建转换规则
  (define transforms (make-hash))
  (for ([(key val) (in-hash alias-entries)])
    (match key
      [(list mnem cls short-sig)
       (define n (length short-sig))
       ;; 转换: 原操作数 + (const lsl) + (const 0)
       (define rule
         (append (for/list ([i (in-range n)]) i)
                 '((const lsl) (const 0))))
       (hash-update! transforms mnem
                     (lambda (lst)
                       (cons (list cls short-sig mnem rule) lst))
                     '())]
      [_ (void)]))

  (values by-mnem transforms))

;; ============================================================
;; 输出
;; ============================================================

(define (write-alias-signatures by-mnem output-path)
  (call-with-output-file output-path
    (lambda (out)
      (fprintf out ";; ============================================================\n")
      (fprintf out ";; alias-signatures.rktd - 自动生成的别名签名\n")
      (fprintf out ";; 来源: MRS optional_shift / optional_extend\n")
      (fprintf out ";; 生成命令: racket tool/extract/optional-extractor.rkt\n")
      (fprintf out ";; ============================================================\n\n")
      (for ([(mnem entries) (in-hash by-mnem)])
        (fprintf out "(~a\n" mnem)
        (fprintf out "  (")
        (for ([entry (in-list entries)]
              [i (in-naturals)])
          (match entry
            [(list cls sig)
             (when (> i 0) (fprintf out "\n   "))
             (fprintf out "(~a ~s)" cls sig)]))
        (fprintf out "))\n\n")))
    #:exists 'replace)
  (printf "\n已保存签名: ~a (~a 个助记符)\n"
          output-path (hash-count by-mnem)))

(define (write-alias-transforms transforms output-path)
  (call-with-output-file output-path
    (lambda (out)
      (fprintf out ";; ============================================================\n")
      (fprintf out ";; alias-transforms.rktd - 自动生成的别名转换规则\n")
      (fprintf out ";; 来源: MRS optional_shift / optional_extend\n")
      (fprintf out ";; 生成命令: racket tool/extract/optional-extractor.rkt\n")
      (fprintf out ";; ============================================================\n\n")
      (for ([(mnem entries) (in-hash transforms)])
        (fprintf out "(~a\n" mnem)
        (for ([entry (in-list entries)])
          (match entry
            [(list cls sig target-mnem rule)
             (fprintf out "  ((~a ~s)  ~a  ~s)\n"
                      cls sig target-mnem rule)]))
        (fprintf out ")\n\n")))
    #:exists 'replace)
  (printf "已保存转换: ~a (~a 个助记符)\n"
          output-path (hash-count transforms)))

;; ============================================================
;; 主程序
;; ============================================================

(module+ main
  (require racket/cmdline)

  (define mrs-path
    (make-parameter "AARCHMRS_OPENSOURCE_A_profile_FAT-2025-12/Instructions.json"))
  (define spec-path
    (make-parameter "syntax/data/generated/instruction-spec.rktd"))
  (define sig-output
    (make-parameter "syntax/data/alias-signatures.rktd"))
  (define transform-output
    (make-parameter "syntax/data/alias-transforms.rktd"))

  (command-line
   #:program "optional-extractor"
   #:once-each
   [("-m" "--mrs") path "MRS Instructions.json path" (mrs-path path)]
   [("-s" "--spec") path "instruction-spec.rktd path" (spec-path path)]
   [("--sig-out") path "Output alias-signatures.rktd" (sig-output path)]
   [("--transform-out") path "Output alias-transforms.rktd" (transform-output path)]
   #:args ()

   (define-values (by-mnem transforms)
     (extract-optional-aliases (mrs-path) (spec-path)))

   (write-alias-signatures by-mnem (sig-output))
   (write-alias-transforms transforms (transform-output))))
