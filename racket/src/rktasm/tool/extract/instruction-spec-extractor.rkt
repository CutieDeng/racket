#lang racket

;; ============================================================
;; instruction-spec-extractor.rkt
;; 从 MRS JSON 提取指令规范 - 唯一的核心数据生成器
;; ============================================================

(require "loader.rkt"
         "syntax-variant.rkt"
         "../../syntax/constraint.rkt")

(provide extract-instruction-spec
         save-instruction-spec)

;; ============================================================
;; 提取指令规范
;; ============================================================

;; 指令规范条目: (encoding-id mnemonic template constraints)
(define (extract-instruction-spec json-path)
  (define json-data (read-instructions-json json-path))
  (define rules (get-assembly-rules json-data))
  (define a64 (get-a64-instruction-set json-data))

  (define specs '())

  (define (walk node)
    (match (hash-ref node '_type #f)
      ["Instruction.InstructionSet"
       (for-each walk (hash-ref node 'children '()))]
      ["Instruction.InstructionGroup"
       (for-each walk (hash-ref node 'children '()))]
      ["Instruction.Instruction"
       (define spec (process-instruction rules node))
       (when spec
         (set! specs (cons spec specs)))]
      [_ (void)]))

  (walk a64)
  (reverse specs))

;; 处理单条指令
(define (process-instruction rules node)
  (define encoding-id (hash-ref node 'name #f))
  (define assembly (hash-ref node 'assembly #f))
  (define encoding (hash-ref node 'encoding (hash)))

  (and encoding-id assembly (hash? assembly)
       (let ([mnemonic (extract-mnemonic* rules assembly)])
         (and mnemonic
              (let-values ([(operand-names syntax-class template)
                            (analyze-assembly* rules assembly)])
                (let ([constraints (extract-constraints* encoding)])
                  (list encoding-id mnemonic template constraints)))))))

;; 提取约束
(define (extract-constraints* encoding)
  (define values (hash-ref encoding 'values '()))
  (for*/list ([field (in-list values)]
              [name (in-value (hash-ref field 'name #f))]
              #:when name
              [range (in-value (hash-ref field 'range (hash)))]
              [width (in-value (hash-ref range 'width #f))]
              #:when width
              [value-node (in-value (hash-ref field 'value (hash)))]
              [value-str (in-value (hash-ref value-node 'value ""))]
              #:when (variable-field? value-str)
              [constraint (in-value (field->constraint name width))]
              #:when constraint)
    (list name constraint)))

(define (variable-field? value-str)
  (and (string? value-str) (regexp-match? #rx"x" value-str)))

;; 字段到约束的映射
(define gpr-fields '("Rd" "Rn" "Rm" "Rt" "Rt2" "Rs" "Ra" "Rdn"))
(define simd-fields '("Vd" "Vn" "Vm" "Vt" "Vt2" "Va"))
(define sve-z-fields '("Zd" "Zn" "Zm" "Zt" "Za" "Zda" "Zdn" "Zdn1" "Zdn2" "Zt1" "Zt2"))
(define sve-p-fields '("Pd" "Pn" "Pm" "Pg" "Pt" "Pdm"))
(define sve-pn-fields '("PNg" "PNn" "PNd"))

(define (field->constraint name width)
  (define max-val (sub1 (expt 2 width)))
  (cond
    [(member name gpr-fields) `(reg-range 0 ,max-val)]
    [(member name simd-fields) `(reg-range 0 ,max-val)]
    [(member name sve-z-fields) `(reg-range 0 ,max-val)]
    [(member name sve-p-fields) `(reg-range 0 ,max-val)]
    [(member name sve-pn-fields) `(reg-range 0 ,max-val)]
    [(regexp-match? #rx"^imm" name) `(imm-range 0 ,max-val 1)]
    [(regexp-match? #rx"^off" name) `(imm-range 0 ,max-val 1)]
    [(string=? name "size") `(element-size B H S D)]
    [(string=? name "shift") `(imm-range 0 ,max-val 1)]
    [else #f]))

;; 从 syntax-variant.rkt 借用的辅助函数
(define (extract-mnemonic* rules assembly)
  (define symbols (get-symbol-list* assembly))
  (and (pair? symbols)
       (let ([first-sym (car symbols)])
         (match (hash-ref first-sym '_type #f)
           ["Instruction.Symbols.Literal"
            (string->symbol (string-downcase (hash-ref first-sym 'value "")))]
           [_ #f]))))

(define (get-symbol-list* assembly)
  (define symbols (hash-ref assembly 'symbols #f))
  (cond
    [(list? symbols) symbols]
    [(and (hash? symbols) (hash-ref symbols 'symbols #f)) => identity]
    [else '()]))

(define (analyze-assembly* rules assembly)
  (define db (build-syntax-variant-db rules
               (hash '_type "Instruction.InstructionSet"
                     'children (list (hash '_type "Instruction.Instruction"
                                          'name "temp"
                                          'assembly assembly)))))
  (define mnem (extract-mnemonic* rules assembly))
  (define variants (hash-ref db mnem '()))
  (if (pair? variants)
      (let ([v (car variants)])
        (values (extract-syntax-variant-operand-names v)
                (extract-syntax-variant-syntax-class v)
                (extract-syntax-variant-template v)))
      (values '() 'c0 "")))

;; ============================================================
;; 保存指令规范
;; ============================================================

(define (save-instruction-spec specs output-path)
  (call-with-output-file output-path
    (lambda (out)
      (fprintf out ";; ============================================================\n")
      (fprintf out ";; instruction-spec.rktd - 指令规范 (核心数据)\n")
      (fprintf out ";; ============================================================\n")
      (fprintf out ";;\n")
      (fprintf out ";; 格式: (encoding-id mnemonic template ((field constraint) ...))\n")
      (fprintf out ";;\n")
      (fprintf out ";; 这是唯一的核心数据文件，其他数据可从此计算:\n")
      (fprintf out ";;   - Layer2 签名: 从 template 通过 parse-template-signature 计算\n")
      (fprintf out ";;   - Layer1 类别: 从 Layer2 签名通过 layer2->layer1 计算\n")
      (fprintf out ";;\n")
      (fprintf out ";; 生成命令:\n")
      (fprintf out ";;   racket tool/extract/instruction-spec-extractor.rkt\n")
      (fprintf out ";;\n")
      (fprintf out ";; 总条目数: ~a\n" (length specs))
      (fprintf out ";; ============================================================\n\n")

      (for ([spec (in-list specs)])
        (fprintf out "~s\n" spec)))
    #:exists 'replace)

  (printf "已保存: ~a (~a 条记录)\n" output-path (length specs)))

;; ============================================================
;; 主程序
;; ============================================================

(module+ main
  (require racket/cmdline)

  (define json-path
    (make-parameter "AARCHMRS_OPENSOURCE_A_profile_FAT-2025-12/Instructions.json"))
  (define output-path
    (make-parameter "syntax/data/generated/instruction-spec.rktd"))

  (command-line
   #:program "instruction-spec-extractor"
   #:once-each
   [("-j" "--json") path "Path to Instructions.json" (json-path path)]
   [("-o" "--output") path "Output file path" (output-path path)]
   #:args ()

   ;; 确保输出目录存在
   (define dir (path-only (output-path)))
   (when dir (make-directory* dir))

   (printf "从 ~a 提取指令规范...\n" (json-path))
   (define specs (extract-instruction-spec (json-path)))
   (save-instruction-spec specs (output-path))

   ;; 统计
   (printf "\n=== 统计 ===\n")
   (define mnemonics (remove-duplicates (map cadr specs)))
   (printf "总编码数: ~a\n" (length specs))
   (printf "助记符数: ~a\n" (length mnemonics))))
