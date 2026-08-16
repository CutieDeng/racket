#lang racket

(require "loader.rkt"
         "syntax-variant.rkt"
         "../../syntax/operand-type.rkt"
         "../../syntax/constraint.rkt")

(provide build-constraint-db-from-json
         save-constraint-db
         extract-encoding-constraints)

;; ============================================================
;; Constraint Extractor Tool (Layer 3)
;; ============================================================
;;
;; 从 Instructions.json 提取编码约束数据
;; 生成 instruction-constraints.rktd 文件

;; ============================================================
;; 编码字段类型映射
;; ============================================================

;; GPR 寄存器字段
(define gpr-fields '("Rd" "Rn" "Rm" "Rt" "Rt2" "Rs" "Ra" "Rdn"))

;; SIMD/FP 标量寄存器字段
(define simd-fields '("Vd" "Vn" "Vm" "Vt" "Vt2" "Va"))

;; SVE Z 寄存器字段
(define sve-z-fields '("Zd" "Zn" "Zm" "Zt" "Za" "Zda" "Zdn" "Zdn1" "Zdn2" "Zdn3" "Zdn4"
                       "Zt1" "Zt2" "Zt3" "Zt4" "Zm1" "Zm2" "Zm3" "Zm4"))

;; SVE P 谓词寄存器字段
(define sve-p-fields '("Pd" "Pn" "Pm" "Pg" "Pt" "Pdm"))

;; SVE PN 谓词计数器字段
(define sve-pn-fields '("PNg" "PNn" "PNd"))

;; 立即数字段模式
(define (immediate-field? name)
  (or (regexp-match? #rx"^imm[0-9]+" name)
      (regexp-match? #rx"^off[0-9]+" name)
      (member name '("amount" "shift" "scale"))))

;; ============================================================
;; 先验知识: 立即数字段的编码转换语义
;; ============================================================
;; ARM MRS JSON 不提供编码转换公式，需要手动定义
;;
;; 格式: field-name -> (min max step signed?)
;; - min/max 是汇编层面的值范围
;; - step 是对齐要求
;; - signed? 表示是否是有符号数
;;
;; 转换公式 (汇编 -> 编码):
;;   encode = (asm-value - min) / step
;;
;; 例如 imm19 (分支偏移):
;;   - 汇编范围: [-1MB, +1MB-4] 字节偏移, 4字节对齐
;;   - 编码范围: [0, 2^19-1] (19位无符号)
;;   - 公式: encode = (offset >> 2) & 0x7FFFF (有符号截断)

(define immediate-semantics
  (hash
   ;; 分支偏移字段 (PC-relative, 4字节对齐)
   ;; imm19: 条件分支 B.cond, CBZ, CBNZ, LDR literal
   ;; 汇编: offset = SignExtend(imm19) << 2
   ;; 范围: [-1MB, +1MB-4]
   "imm19" (list (- (expt 2 20)) (- (expt 2 20) 4) 4 #t)

   ;; imm26: 无条件分支 B, BL
   ;; 汇编: offset = SignExtend(imm26) << 2
   ;; 范围: [-128MB, +128MB-4]
   "imm26" (list (- (expt 2 27)) (- (expt 2 27) 4) 4 #t)

   ;; imm14: TBZ, TBNZ 测试分支
   ;; 汇编: offset = SignExtend(imm14) << 2
   ;; 范围: [-32KB, +32KB-4]
   "imm14" (list (- (expt 2 15)) (- (expt 2 15) 4) 4 #t)

   ;; 加载/存储偏移字段
   ;; imm12: LDR/STR unsigned offset (按元素大小缩放)
   ;; 这里先用无缩放版本，实际使用时根据元素大小调整
   "imm12" (list 0 (sub1 (expt 2 12)) 1 #f)

   ;; imm9: LDR/STR pre/post-index, LDUR/STUR
   ;; 有符号 9 位立即数
   "imm9" (list -256 255 1 #t)

   ;; imm7: LDP/STP 偏移 (按元素大小缩放)
   ;; 有符号 7 位
   "imm7" (list (- (expt 2 6)) (- (expt 2 6) 1) 1 #t)))

;; 获取立即数字段的语义信息
(define (get-immediate-semantics name)
  (hash-ref immediate-semantics name #f))

;; 判断字段值是否为变量（包含 'x'）
(define (variable-field? value-str)
  (and (string? value-str)
       (regexp-match? #rx"x" value-str)))

;; ============================================================
;; 约束提取
;; ============================================================

;; 从单条指令提取约束
;; 返回: (hash field-name -> constraint)
(define (extract-encoding-constraints instruction)
  (define constraints (make-hash))
  (define encoding (hash-ref instruction 'encoding (hash)))
  (define values (hash-ref encoding 'values '()))

  (for ([field (in-list values)])
    (define name (hash-ref field 'name #f))
    (define range (hash-ref field 'range (hash)))
    (define width (hash-ref range 'width #f))
    (define value-node (hash-ref field 'value (hash)))
    (define value-str (hash-ref value-node 'value ""))

    (when (and name width (variable-field? value-str))
      (define constraint (field-to-constraint name width))
      (when constraint
        (hash-set! constraints name constraint))))

  constraints)

;; 从字段名和宽度生成约束
(define (field-to-constraint name width)
  (cond
    ;; GPR 寄存器
    [(member name gpr-fields)
     (reg-range 0 (sub1 (expt 2 width)))]

    ;; SIMD 寄存器
    [(member name simd-fields)
     (reg-range 0 (sub1 (expt 2 width)))]

    ;; SVE Z 寄存器
    [(member name sve-z-fields)
     (reg-range 0 (sub1 (expt 2 width)))]

    ;; SVE P 谓词寄存器
    [(member name sve-p-fields)
     (reg-range 0 (sub1 (expt 2 width)))]

    ;; SVE PN 谓词计数器
    [(member name sve-pn-fields)
     (reg-range 0 (sub1 (expt 2 width)))]

    ;; 立即数 - 优先使用语义信息
    [(immediate-field? name)
     (define semantics (get-immediate-semantics name))
     (if semantics
         ;; 有语义信息，使用实际的汇编层范围
         (match-let ([(list min max step signed?) semantics])
           (imm-range min max step))
         ;; 无语义信息，使用默认的编码范围
         (imm-range 0 (sub1 (expt 2 width)) 1))]

    ;; size 字段 -> 元素大小约束
    [(string=? name "size")
     (element-size (width-to-sizes width))]

    ;; shift 字段 -> 移位类型约束
    [(string=? name "shift")
     (imm-values (build-list (expt 2 width) identity))]

    [else #f]))

;; 从宽度计算可能的元素大小
(define (width-to-sizes width)
  (case width
    [(2) '(B H S D)]  ; 00=B, 01=H, 10=S, 11=D
    [(1) '(S D)]       ; 0=S, 1=D
    [else '(B H S D)]))

;; ============================================================
;; 数据库构建
;; ============================================================

;; 从 JSON 构建约束数据库
;; 返回: hash[encoding-id -> (hash field-name -> constraint)]
(define (build-constraint-db-from-json json-path)
  (define json-data (read-instructions-json json-path))
  (define a64 (get-a64-instruction-set json-data))

  (define db (make-hash))

  (define (walk node)
    (match (hash-ref node '_type #f)
      ["Instruction.InstructionSet"
       (for-each walk (hash-ref node 'children '()))]
      ["Instruction.InstructionGroup"
       (for-each walk (hash-ref node 'children '()))]
      ["Instruction.Instruction"
       (define encoding-id (hash-ref node 'name #f))
       (when encoding-id
         (define constraints (extract-encoding-constraints node))
         (when (positive? (hash-count constraints))
           (hash-set! db encoding-id constraints)))]
      [_ (void)]))

  (walk a64)
  db)

;; ============================================================
;; 输出格式化
;; ============================================================

;; 将约束转换为 S-expr 格式
(define (constraint->sexp c)
  (match c
    [(reg-range min max)
     `(reg-range ,min ,max)]
    [(imm-range min max step)
     `(imm-range ,min ,max ,step)]
    [(imm-values vals)
     `(imm-values ,@vals)]
    [(arrangement arrs)
     `(arrangement ,@arrs)]
    [(element-size sizes)
     `(element-size ,@sizes)]
    [(pred-mode-constraint modes)
     `(pred-mode ,@modes)]
    [_ c]))

;; 保存约束数据库
(define (save-constraint-db db output-dir)
  ;; 保存完整约束映射
  (call-with-output-file (build-path output-dir "instruction-constraints.rktd")
    (lambda (out)
      (fprintf out ";; ============================================================\n")
      (fprintf out ";; Layer 3: 指令编码约束映射\n")
      (fprintf out ";; ============================================================\n")
      (fprintf out ";;\n")
      (fprintf out ";; 格式: (encoding-id ((field constraint) ...))\n")
      (fprintf out ";;\n")
      (fprintf out ";; 约束类型:\n")
      (fprintf out ";;   (reg-range min max)      - 寄存器编号范围\n")
      (fprintf out ";;   (imm-range min max step) - 立即数范围\n")
      (fprintf out ";;   (imm-values v1 v2 ...)   - 特定立即数值\n")
      (fprintf out ";;   (element-size B H S D)   - 元素大小\n")
      (fprintf out ";;\n\n")

      (for ([(encoding-id constraints) (in-hash db)]
            #:when (positive? (hash-count constraints)))
        (define fields-list
          (for/list ([(field c) (in-hash constraints)])
            (list field (constraint->sexp c))))
        (fprintf out "~s\n" (list encoding-id fields-list))))
    #:exists 'replace)

  (printf "已保存约束数据库: ~a/instruction-constraints.rktd (~a 条记录)\n"
          output-dir (hash-count db))

  ;; 生成约束统计摘要
  (save-constraint-summary db output-dir))

;; 保存约束统计摘要
(define (save-constraint-summary db output-dir)
  ;; 统计各类约束
  (define reg-constraints (make-hash))  ; (min . max) -> count
  (define imm-constraints (make-hash))  ; (min . max) -> count
  (define field-stats (make-hash))      ; field-name -> count

  (for* ([(enc-id constraints) (in-hash db)]
         [(field c) (in-hash constraints)])
    (hash-update! field-stats field add1 0)
    (match c
      [(reg-range min max)
       (hash-update! reg-constraints (cons min max) add1 0)]
      [(imm-range min max _)
       (hash-update! imm-constraints (cons min max) add1 0)]
      [_ (void)]))

  (call-with-output-file (build-path output-dir "layer3-summary.rktd")
    (lambda (out)
      (fprintf out ";; ============================================================\n")
      (fprintf out ";; Layer 3 约束统计摘要\n")
      (fprintf out ";; ============================================================\n\n")

      (fprintf out ";; --- 寄存器范围约束 ---\n")
      (for ([(range count) (in-hash reg-constraints)]
            #:when (> count 5))
        (fprintf out ";; (reg-range ~a ~a): ~a 次\n" (car range) (cdr range) count))

      (fprintf out "\n;; --- 立即数范围约束 ---\n")
      (for ([(range count) (in-hash imm-constraints)]
            #:when (> count 5))
        (fprintf out ";; (imm-range 0 ~a): ~a 次\n" (cdr range) count))

      (fprintf out "\n;; --- 字段使用统计 (top 30) ---\n")
      (define sorted-fields
        (take (sort (hash->list field-stats) > #:key cdr)
              (min 30 (hash-count field-stats))))
      (for ([pair (in-list sorted-fields)])
        (fprintf out ";; ~a: ~a 次\n" (car pair) (cdr pair)))

      (fprintf out "\n;; === 常用约束模板 ===\n\n")

      ;; 生成常用约束常量
      (fprintf out "(common-constraints\n")
      (fprintf out "  ;; GPR 范围\n")
      (fprintf out "  (gpr-full (reg-range 0 31))     ; 5-bit 寄存器\n")
      (fprintf out "  (gpr-low  (reg-range 0 7))      ; 3-bit 寄存器\n")
      (fprintf out "  (gpr-mid  (reg-range 0 15))     ; 4-bit 寄存器\n")
      (fprintf out "\n")
      (fprintf out "  ;; SVE Z 范围\n")
      (fprintf out "  (sve-z-full (reg-range 0 31))   ; 5-bit\n")
      (fprintf out "  (sve-z-low  (reg-range 0 7))    ; 3-bit (某些指令)\n")
      (fprintf out "  (sve-z-mid  (reg-range 0 15))   ; 4-bit (某些指令)\n")
      (fprintf out "\n")
      (fprintf out "  ;; SVE P 谓词范围\n")
      (fprintf out "  (sve-p-full (reg-range 0 15))   ; 4-bit\n")
      (fprintf out "  (sve-p-low  (reg-range 0 7))    ; 3-bit (控制谓词)\n")
      (fprintf out "\n")
      (fprintf out "  ;; 常见立即数范围\n")
      (fprintf out "  (imm3 (imm-range 0 7 1))        ; 3-bit\n")
      (fprintf out "  (imm4 (imm-range 0 15 1))       ; 4-bit\n")
      (fprintf out "  (imm5 (imm-range 0 31 1))       ; 5-bit\n")
      (fprintf out "  (imm6 (imm-range 0 63 1))       ; 6-bit\n")
      (fprintf out "  (imm8 (imm-range 0 255 1))      ; 8-bit\n")
      (fprintf out ")\n"))
    #:exists 'replace)

  (printf "已保存约束摘要: ~a/layer3-summary.rktd\n" output-dir))

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
   #:program "constraint-extractor"
   #:once-each
   [("-j" "--json") path
    "Path to Instructions.json"
    (json-path path)]
   [("-o" "--output") dir
    "Output directory for constraint database"
    (output-dir dir)]
   #:args ()

   (printf "Loading JSON from ~a...\n" (json-path))
   (define db (build-constraint-db-from-json (json-path)))

   (save-constraint-db db (output-dir))

   ;; 显示示例
   (printf "\n示例约束:\n")
   (define examples
     (take (hash->list db) (min 5 (hash-count db))))
   (for ([example (in-list examples)])
     (match-define (cons enc-id constraints) example)
     (printf "  ~a:\n" enc-id)
     (for ([(field c) (in-hash constraints)])
       (printf "    ~a: ~s\n" field (constraint->sexp c))))))
