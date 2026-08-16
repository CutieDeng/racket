#lang racket

(require "loader.rkt"
         "syntax-variant.rkt"
         "../../syntax/operand-type.rkt"
         "../../syntax/constraint.rkt")

(provide build-integrated-db
         save-integrated-db
         integrated-entry
         integrated-entry?)

;; ============================================================
;; Integrated Table Generator
;; ============================================================
;;
;; 生成整合的三层映射表:
;;
;; 结构:
;;   mnemonic -> (listof layer1-group)
;;   layer1-group = (layer1-class (listof layer2-group))
;;   layer2-group = (layer2-signature (listof layer3-entry))
;;   layer3-entry = (encoding-id constraints template)
;;
;; 用途:
;;   1. 解析时快速验证助记符合法性
;;   2. Layer1 匹配后缩小候选范围
;;   3. Layer2 匹配后进一步缩小
;;   4. Layer3 反查所有符合约束的编码

;; 完整条目结构
(struct integrated-entry
  (encoding-id      ; string: "ADD_64_addsub_shift"
   mnemonic         ; symbol: 'add
   layer1-class     ; symbol: 'c3
   layer2-signature ; (listof symbol): '(gpr-64 gpr-64 gpr-64 keyword immediate)
   layer3-constraints ; hash[field -> constraint]
   template)        ; string: "XZR, XZR, XZR, LSL, UInteger"
  #:transparent)

;; ============================================================
;; 构建整合数据库
;; ============================================================

(define (build-integrated-db json-path)
  (define json-data (read-instructions-json json-path))
  (define rules (get-assembly-rules json-data))
  (define a64 (get-a64-instruction-set json-data))

  ;; 收集所有条目
  (define entries '())

  (define (walk node)
    (match (hash-ref node '_type #f)
      ["Instruction.InstructionSet"
       (for-each walk (hash-ref node 'children '()))]
      ["Instruction.InstructionGroup"
       (for-each walk (hash-ref node 'children '()))]
      ["Instruction.Instruction"
       (define entry (process-instruction rules node))
       (when entry
         (set! entries (cons entry entries)))]
      [_ (void)]))

  (walk a64)

  ;; 按助记符分组
  (define by-mnemonic (make-hash))
  (for ([e (in-list entries)])
    (hash-update! by-mnemonic
                  (integrated-entry-mnemonic e)
                  (λ (lst) (cons e lst))
                  '()))

  ;; 构建层级结构
  (define integrated-db (make-hash))
  (for ([(mnem entries) (in-hash by-mnemonic)])
    (hash-set! integrated-db mnem (build-hierarchy entries)))

  integrated-db)

;; 处理单条指令
(define (process-instruction rules node)
  (define encoding-id (hash-ref node 'name #f))
  (define assembly (hash-ref node 'assembly #f))
  (define encoding (hash-ref node 'encoding (hash)))

  (when (and encoding-id assembly (hash? assembly))
    (define mnemonic (extract-mnemonic* rules assembly))
    (when mnemonic
      ;; Layer 1: 语法结构
      (define-values (operand-names layer1-class template)
        (analyze-assembly* rules assembly))

      ;; Layer 2: 操作数类型签名
      (define layer2-sig (parse-template-signature template))

      ;; Layer 3: 编码约束
      (define layer3-constraints (extract-constraints encoding))

      (integrated-entry encoding-id mnemonic layer1-class
                        layer2-sig layer3-constraints template))))

;; 提取约束
(define (extract-constraints encoding)
  (define constraints (make-hash))
  (define values (hash-ref encoding 'values '()))

  (for ([field (in-list values)])
    (define name (hash-ref field 'name #f))
    (define range (hash-ref field 'range (hash)))
    (define width (hash-ref range 'width #f))
    (define value-node (hash-ref field 'value (hash)))
    (define value-str (hash-ref value-node 'value ""))

    (when (and name width (variable-field?* value-str))
      (define constraint (field-to-constraint* name width))
      (when constraint
        (hash-set! constraints name constraint))))

  constraints)

;; 辅助函数
(define (variable-field?* value-str)
  (and (string? value-str)
       (regexp-match? #rx"x" value-str)))

(define gpr-fields* '("Rd" "Rn" "Rm" "Rt" "Rt2" "Rs" "Ra" "Rdn"))
(define simd-fields* '("Vd" "Vn" "Vm" "Vt" "Vt2" "Va"))
(define sve-z-fields* '("Zd" "Zn" "Zm" "Zt" "Za" "Zda" "Zdn"))
(define sve-p-fields* '("Pd" "Pn" "Pm" "Pg" "Pt"))

(define (field-to-constraint* name width)
  (cond
    [(member name gpr-fields*) (reg-range 0 (sub1 (expt 2 width)))]
    [(member name simd-fields*) (reg-range 0 (sub1 (expt 2 width)))]
    [(member name sve-z-fields*) (reg-range 0 (sub1 (expt 2 width)))]
    [(member name sve-p-fields*) (reg-range 0 (sub1 (expt 2 width)))]
    [(regexp-match? #rx"^imm" name) (imm-range 0 (sub1 (expt 2 width)) 1)]
    [(regexp-match? #rx"^off" name) (imm-range 0 (sub1 (expt 2 width)) 1)]
    [(string=? name "size") (element-size '(B H S D))]
    [else #f]))

;; 从 syntax-variant.rkt 复制的辅助函数
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
  ;; 简化版本 - 直接调用 syntax-variant 中的函数
  (define db (build-syntax-variant-db rules (hash '_type "Instruction.InstructionSet"
                                                  'children (list (hash '_type "Instruction.Instruction"
                                                                       'name "temp"
                                                                       'assembly assembly)))))
  (define variants (hash-ref db (extract-mnemonic* rules assembly) '()))
  (if (pair? variants)
      (let ([v (car variants)])
        (values (extract-syntax-variant-operand-names v)
                (extract-syntax-variant-syntax-class v)
                (extract-syntax-variant-template v)))
      (values '() 'c0 "")))

;; ============================================================
;; 构建层级结构
;; ============================================================

;; 将条目列表构建为层级结构
;; 返回: (listof (layer1-class . (listof (layer2-sig . (listof entry)))))
(define (build-hierarchy entries)
  ;; 按 Layer1 分组
  (define by-layer1 (make-hash))
  (for ([e (in-list entries)])
    (hash-update! by-layer1
                  (integrated-entry-layer1-class e)
                  (λ (lst) (cons e lst))
                  '()))

  ;; 每个 Layer1 组内按 Layer2 分组
  (for/list ([(l1-class l1-entries) (in-hash by-layer1)])
    (define by-layer2 (make-hash))
    (for ([e (in-list l1-entries)])
      (define sig-key (format "~a" (integrated-entry-layer2-signature e)))
      (hash-update! by-layer2 sig-key
                    (λ (lst) (cons e lst))
                    '()))

    (cons l1-class
          (for/list ([(sig-key l2-entries) (in-hash by-layer2)])
            (cons (integrated-entry-layer2-signature (car l2-entries))
                  l2-entries)))))

;; ============================================================
;; 保存整合表
;; ============================================================

(define (save-integrated-db db output-dir)
  ;; 保存完整整合表
  (call-with-output-file (build-path output-dir "integrated-table.rktd")
    (lambda (out)
      (fprintf out ";; ============================================================\n")
      (fprintf out ";; 三层整合映射表\n")
      (fprintf out ";; ============================================================\n")
      (fprintf out ";;\n")
      (fprintf out ";; 结构: (mnemonic (layer1-hierarchy))\n")
      (fprintf out ";; layer1-hierarchy = (layer1-class ((layer2-sig (entries...)) ...))\n")
      (fprintf out ";; entry = (encoding-id template (constraint...))\n")
      (fprintf out ";;\n\n")

      (for ([(mnem hierarchy) (in-hash db)])
        (fprintf out "(~a\n" mnem)
        (for ([l1-group (in-list hierarchy)])
          (define l1-class (car l1-group))
          (define l2-groups (cdr l1-group))
          (fprintf out "  (~a\n" l1-class)
          (for ([l2-group (in-list l2-groups)])
            (define l2-sig (car l2-group))
            (define entries (cdr l2-group))
            (fprintf out "    (~s\n" l2-sig)
            (for ([e (in-list entries)])
              (fprintf out "      (~s ~s ~s)\n"
                       (integrated-entry-encoding-id e)
                       (integrated-entry-template e)
                       (hash->list (integrated-entry-layer3-constraints e))))
            (fprintf out "    )\n"))
          (fprintf out "  )\n"))
        (fprintf out ")\n\n")))
    #:exists 'replace)

  ;; 保存快速查找索引
  (save-lookup-indices db output-dir)

  (printf "已保存整合表: ~a/integrated-table.rktd (~a 个助记符)\n"
          output-dir (hash-count db)))

;; 保存各层级的快速查找索引
(define (save-lookup-indices db output-dir)
  ;; Layer 1 索引: mnemonic -> (setof layer1-class)
  (call-with-output-file (build-path output-dir "index-layer1.rktd")
    (lambda (out)
      (fprintf out ";; Layer 1 索引: mnemonic -> (layer1-classes...)\n\n")
      (for ([(mnem hierarchy) (in-hash db)])
        (define classes (map car hierarchy))
        (fprintf out "(~a ~a)\n" mnem classes)))
    #:exists 'replace)

  ;; Layer 2 索引: (mnemonic layer1-class) -> (listof layer2-sig)
  (call-with-output-file (build-path output-dir "index-layer2.rktd")
    (lambda (out)
      (fprintf out ";; Layer 2 索引: (mnemonic layer1-class) -> (signatures...)\n\n")
      (for ([(mnem hierarchy) (in-hash db)])
        (for ([l1-group (in-list hierarchy)])
          (define l1-class (car l1-group))
          (define sigs (map car (cdr l1-group)))
          (fprintf out "((~a ~a) ~s)\n" mnem l1-class sigs))))
    #:exists 'replace)

  ;; Layer 3 索引: (mnemonic layer1-class layer2-sig-hash) -> (listof encoding-id)
  (call-with-output-file (build-path output-dir "index-layer3.rktd")
    (lambda (out)
      (fprintf out ";; Layer 3 索引: encoding-id -> constraints\n\n")
      (for* ([(mnem hierarchy) (in-hash db)]
             [l1-group (in-list hierarchy)]
             [l2-group (in-list (cdr l1-group))]
             [e (in-list (cdr l2-group))])
        (define constraints (integrated-entry-layer3-constraints e))
        (when (positive? (hash-count constraints))
          (fprintf out "(~s ~s)\n"
                   (integrated-entry-encoding-id e)
                   (for/list ([(k v) (in-hash constraints)])
                     (list k (constraint->sexp* v)))))))
    #:exists 'replace)

  (printf "已保存索引文件: index-layer1.rktd, index-layer2.rktd, index-layer3.rktd\n"))

(define (constraint->sexp* c)
  (match c
    [(reg-range min max) `(reg-range ,min ,max)]
    [(imm-range min max step) `(imm-range ,min ,max ,step)]
    [(imm-values vals) `(imm-values ,@vals)]
    [(element-size sizes) `(element-size ,@sizes)]
    [_ c]))

;; ============================================================
;; 主程序
;; ============================================================

(module+ main
  (require racket/cmdline)

  (define json-path
    (make-parameter "AARCHMRS_OPENSOURCE_A_profile_FAT-2025-12/Instructions.json"))
  (define output-dir
    (make-parameter "syntax/data"))

  (command-line
   #:program "integrated-table"
   #:once-each
   [("-j" "--json") path "Path to Instructions.json" (json-path path)]
   [("-o" "--output") dir "Output directory" (output-dir dir)]
   #:args ()

   (printf "构建整合表...\n")
   (define db (build-integrated-db (json-path)))
   (save-integrated-db db (output-dir))

   ;; 显示统计
   (printf "\n=== 统计 ===\n")
   (define total-entries 0)
   (define total-l1-groups 0)
   (define total-l2-groups 0)

   (for ([(mnem hierarchy) (in-hash db)])
     (for ([l1-group (in-list hierarchy)])
       (set! total-l1-groups (add1 total-l1-groups))
       (for ([l2-group (in-list (cdr l1-group))])
         (set! total-l2-groups (add1 total-l2-groups))
         (set! total-entries (+ total-entries (length (cdr l2-group)))))))

   (printf "助记符数量: ~a\n" (hash-count db))
   (printf "Layer1 分组: ~a\n" total-l1-groups)
   (printf "Layer2 分组: ~a\n" total-l2-groups)
   (printf "总条目数: ~a\n" total-entries)))
