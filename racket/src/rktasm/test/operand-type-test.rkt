#lang racket

(require rackunit
         rackunit/text-ui
         "../parser/ast.rkt"
         "../syntax/operand-type.rkt")

;; ============================================================
;; syntax/operand-type.rkt 单元测试
;; ============================================================

(define operand-type-tests
  (test-suite
   "Operand-Type 单元测试"

   ;; --------------------------------------------------------
   ;; operand-type?
   ;; --------------------------------------------------------
   (test-suite
    "operand-type?"

    (test-case "有效操作数类型"
      (for ([t '(gpr-64 gpr-32 simd-scalar simd-vector simd-element
                 sve-z sve-p sve-pn sme-za sme-zt
                 immediate negimm float-const
                 keyword barrier-option prefetch-op vector-length pre-index
                 memory reg-list system-reg label cond-code unknown)])
        (check-not-false (operand-type? t) (format "~a 应是有效类型" t))))

    (test-case "无效操作数类型"
      (check-false (operand-type? 'gpr))
      (check-false (operand-type? 'x0))
      (check-false (operand-type? 42))
      (check-false (operand-type? "gpr-64"))))

   ;; --------------------------------------------------------
   ;; parse-template-signature: GPR
   ;; --------------------------------------------------------
   (test-suite
    "parse-template-signature: GPR"

    (test-case "64-bit GPR"
      (check-equal? (parse-template-signature "XZR, XUInteger, XUInteger")
                    '(gpr-64 gpr-64 gpr-64)))

    (test-case "32-bit GPR"
      (check-equal? (parse-template-signature "WZR, WUInteger, WUInteger")
                    '(gpr-32 gpr-32 gpr-32)))

    (test-case "SP 是 gpr-64"
      (check-equal? (parse-template-signature "SP") '(gpr-64)))

    (test-case "WSP 是 gpr-32"
      (check-equal? (parse-template-signature "WSP") '(gpr-32))))

   ;; --------------------------------------------------------
   ;; parse-template-signature: SIMD
   ;; --------------------------------------------------------
   (test-suite
    "parse-template-signature: SIMD"

    (test-case "标量 SIMD"
      (check-equal? (parse-template-signature "DUInteger, DUInteger")
                    '(simd-scalar simd-scalar))
      (check-equal? (parse-template-signature "SUInteger")
                    '(simd-scalar))
      (check-equal? (parse-template-signature "HUInteger")
                    '(simd-scalar))
      (check-equal? (parse-template-signature "BUInteger")
                    '(simd-scalar))
      (check-equal? (parse-template-signature "QUInteger")
                    '(simd-scalar)))

    (test-case "向量 SIMD"
      (check-equal? (parse-template-signature "VUInteger.4S, VUInteger.4S")
                    '(simd-vector simd-vector)))

    (test-case "元素访问 SIMD"
      (check-equal? (parse-template-signature "VUInteger[UInteger]")
                    '(simd-element))))

   ;; --------------------------------------------------------
   ;; parse-template-signature: SVE
   ;; --------------------------------------------------------
   (test-suite
    "parse-template-signature: SVE"

    (test-case "Z 寄存器"
      (check-equal? (parse-template-signature "ZUInteger.B, ZUInteger.B")
                    '(sve-z sve-z)))

    (test-case "P 谓词寄存器"
      (check-equal? (parse-template-signature "PUInteger/M")
                    '(sve-p)))

    (test-case "PN 谓词寄存器"
      (check-equal? (parse-template-signature "PNUInteger")
                    '(sve-pn))))

   ;; --------------------------------------------------------
   ;; parse-template-signature: 立即数与关键字
   ;; --------------------------------------------------------
   (test-suite
    "parse-template-signature: 立即数与关键字"

    (test-case "立即数"
      (check-equal? (parse-template-signature "UInteger") '(immediate))
      (check-equal? (parse-template-signature "SInteger") '(immediate)))

    (test-case "浮点常量"
      (check-equal? (parse-template-signature "Real") '(float-const))
      (check-equal? (parse-template-signature "0.0") '(float-const)))

    (test-case "关键字 (shift/extend)"
      (check-equal? (parse-template-signature "LSL") '(keyword))
      (check-equal? (parse-template-signature "LSR") '(keyword))
      (check-equal? (parse-template-signature "SXTW") '(keyword)))

    (test-case "屏障选项"
      (check-equal? (parse-template-signature "SY") '(barrier-option))
      (check-equal? (parse-template-signature "ISH") '(barrier-option)))

    (test-case "预取操作"
      (check-equal? (parse-template-signature "PLDL1KEEP") '(prefetch-op)))

    (test-case "向量长度"
      (check-equal? (parse-template-signature "VLx2") '(vector-length)))

    (test-case "前索引修饰符"
      (check-equal? (parse-template-signature "!") '(pre-index)))

    (test-case "条件码"
      (check-equal? (parse-template-signature "EQ") '(cond-code))
      (check-equal? (parse-template-signature "NE") '(cond-code))))

   ;; --------------------------------------------------------
   ;; parse-template-signature: 复合模板
   ;; --------------------------------------------------------
   (test-suite
    "parse-template-signature: 复合"

    (test-case "ADD 指令模板"
      (check-equal?
       (parse-template-signature "XZR, XUInteger, XUInteger, LSL, UInteger")
       '(gpr-64 gpr-64 gpr-64 keyword immediate)))

    (test-case "空模板"
      (check-equal? (parse-template-signature "") '()))

    (test-case "内存模板"
      (define sig (parse-template-signature "[XUInteger, UInteger]"))
      (check-equal? sig '(memory))))

   ;; --------------------------------------------------------
   ;; operand-type-compatible?
   ;; --------------------------------------------------------
   (test-suite
    "operand-type-compatible?"

    (test-case "相同类型"
      (check-true (operand-type-compatible? 'gpr-64 'gpr-64))
      (check-true (operand-type-compatible? 'immediate 'immediate)))

    (test-case "unknown 匹配任何"
      (check-true (operand-type-compatible? 'unknown 'gpr-64))
      (check-true (operand-type-compatible? 'gpr-64 'unknown)))

    (test-case "label → immediate"
      (check-true (operand-type-compatible? 'label 'immediate)))

    (test-case "cond-code ↔ keyword"
      (check-true (operand-type-compatible? 'cond-code 'keyword))
      (check-true (operand-type-compatible? 'keyword 'cond-code)))

    (test-case "float-const ↔ immediate"
      (check-true (operand-type-compatible? 'immediate 'float-const))
      (check-true (operand-type-compatible? 'float-const 'immediate)))

    (test-case "simd-element ↔ simd-scalar"
      (check-true (operand-type-compatible? 'simd-scalar 'simd-element))
      (check-true (operand-type-compatible? 'simd-element 'simd-scalar)))

    (test-case "prefetch-op ↔ keyword"
      (check-true (operand-type-compatible? 'keyword 'prefetch-op))
      (check-true (operand-type-compatible? 'prefetch-op 'keyword)))

    (test-case "barrier-option ↔ keyword"
      (check-true (operand-type-compatible? 'keyword 'barrier-option))
      (check-true (operand-type-compatible? 'barrier-option 'keyword)))

    (test-case "不兼容类型"
      (check-false (operand-type-compatible? 'gpr-64 'gpr-32))
      (check-false (operand-type-compatible? 'gpr-64 'simd-scalar))
      (check-false (operand-type-compatible? 'immediate 'gpr-64))
      (check-false (operand-type-compatible? 'memory 'reg-list))))

   ;; --------------------------------------------------------
   ;; signature-matches?
   ;; --------------------------------------------------------
   (test-suite
    "signature-matches?"

    (test-case "完全匹配"
      (check-true (signature-matches?
                   '(gpr-64 gpr-64 gpr-64)
                   '(gpr-64 gpr-64 gpr-64))))

    (test-case "兼容匹配"
      (check-true (signature-matches?
                   '(gpr-64 gpr-64 label)
                   '(gpr-64 gpr-64 immediate))))

    (test-case "长度不同"
      (check-false (signature-matches?
                    '(gpr-64 gpr-64)
                    '(gpr-64 gpr-64 gpr-64))))

    (test-case "类型不匹配"
      (check-false (signature-matches?
                    '(gpr-64 gpr-32 gpr-64)
                    '(gpr-64 gpr-64 gpr-64))))

    (test-case "空签名"
      (check-true (signature-matches? '() '()))))

   ;; --------------------------------------------------------
   ;; classify-ast-operand
   ;; --------------------------------------------------------
   (test-suite
    "classify-ast-operand"

    (test-case "64-bit GPR"
      (check-equal? (classify-ast-operand (ast-reg 'x 0 #f #f #f #f no-srcloc))
                    'gpr-64))

    (test-case "32-bit GPR"
      (check-equal? (classify-ast-operand (ast-reg 'w 0 #f #f #f #f no-srcloc))
                    'gpr-32))

    (test-case "SIMD scalar (d register)"
      (check-equal? (classify-ast-operand (ast-reg 'd 0 #f #f #f #f no-srcloc))
                    'simd-scalar))

    (test-case "SIMD scalar (s register)"
      (check-equal? (classify-ast-operand (ast-reg 's 0 #f #f #f #f no-srcloc))
                    'simd-scalar))

    (test-case "SIMD vector (v with element)"
      (check-equal? (classify-ast-operand (ast-reg 'v 0 #f #f '4s #f no-srcloc))
                    'simd-vector))

    (test-case "SIMD scalar (v without element)"
      (check-equal? (classify-ast-operand (ast-reg 'v 0 #f #f #f #f no-srcloc))
                    'simd-scalar))

    (test-case "SVE Z"
      (check-equal? (classify-ast-operand (ast-reg 'z 0 #f #f 'B #f no-srcloc))
                    'sve-z))

    (test-case "SVE P"
      (check-equal? (classify-ast-operand (ast-reg 'p 0 #f #f #f #f no-srcloc))
                    'sve-p))

    (test-case "寄存器列表 (group-size)"
      (check-equal? (classify-ast-operand (ast-reg 'z 0 4 #f 'B #f no-srcloc))
                    'reg-list))

    (test-case "有 index 的组寄存器视为普通寄存器"
      (check-equal? (classify-ast-operand (ast-reg 'z 0 4 2 'D #f no-srcloc))
                    'sve-z))

    (test-case "正立即数"
      (check-equal? (classify-ast-operand (ast-imm 42 no-srcloc))
                    'immediate))

    (test-case "负立即数"
      (check-equal? (classify-ast-operand (ast-imm -1 no-srcloc))
                    'negimm))

    (test-case "零"
      (check-equal? (classify-ast-operand (ast-imm 0 no-srcloc))
                    'immediate))

    (test-case "标签"
      (check-equal? (classify-ast-operand (ast-label "loop" #f no-srcloc))
                    'label))

    (test-case "系统寄存器标签（具名）"
      (check-equal? (classify-ast-operand (ast-label 'DAIF #f no-srcloc))
                    'system-reg)
      (check-equal? (classify-ast-operand (ast-label 'CurrentEL #f no-srcloc))
                    'system-reg)
      (check-equal? (classify-ast-operand (ast-label 'TPIDR_EL0 #f no-srcloc))
                    'system-reg))

    (test-case "系统寄存器标签（编码式）"
      (check-equal? (classify-ast-operand (ast-label 'S3_3_C14_C0_2 #f no-srcloc))
                    'system-reg))

    (test-case "系统寄存器标签（名称模式）"
      (check-equal? (classify-ast-operand (ast-label 'DBGBVR<m>_EL1 #f no-srcloc))
                    'system-reg)
      (check-equal? (classify-ast-operand (ast-label 'TRCACATR<m> #f no-srcloc))
                    'system-reg)
      (check-equal? (classify-ast-operand (ast-label 'S3_<op1>_C<Cn>_C<Cm>_<op2> #f no-srcloc))
                    'system-reg))

    (test-case "移位 → keyword"
      (check-equal? (classify-ast-operand (ast-shift 'lsl 3 no-srcloc))
                    'keyword))

    (test-case "扩展 → keyword"
      (check-equal? (classify-ast-operand (ast-extend 'sxtw #f no-srcloc))
                    'keyword))

    (test-case "条件码"
      (check-equal? (classify-ast-operand (ast-cond 'eq no-srcloc))
                    'cond-code))

    (test-case "内存"
      (define mem (ast-mem (ast-reg 'x 0 #f #f #f #f no-srcloc)
                           (ast-imm 16 no-srcloc)
                           'offset #f #f no-srcloc))
      (check-equal? (classify-ast-operand mem) 'memory))

    (test-case "寄存器列表 (reglist)"
      (define rl (ast-reglist
                  (list (ast-reg 'x 0 #f #f #f #f no-srcloc)
                        (ast-reg 'x 1 #f #f #f #f no-srcloc))
                  no-srcloc))
      (check-equal? (classify-ast-operand rl) 'reg-list)))

   ;; --------------------------------------------------------
   ;; 谓词限定符
   ;; --------------------------------------------------------
   (test-suite
    "谓词限定符"

    (test-case "pred-qualifier?"
      (check-not-false (pred-qualifier? 'none))
      (check-not-false (pred-qualifier? 'm))
      (check-not-false (pred-qualifier? 'z))
      (check-false (pred-qualifier? 'x))
      (check-false (pred-qualifier? #f)))

    (test-case "pred-qualifier->string"
      (check-equal? (pred-qualifier->string 'none) "无限定符")
      (check-equal? (pred-qualifier->string 'm) "/M (合并)")
      (check-equal? (pred-qualifier->string 'z) "/Z (清零)"))

    (test-case "check-pred-qualifier-match 匹配"
      (check-true (check-pred-qualifier-match 'none 'none))
      (check-true (check-pred-qualifier-match 'm 'm))
      (check-true (check-pred-qualifier-match 'z 'z)))

    (test-case "check-pred-qualifier-match 不匹配"
      (check-true (string? (check-pred-qualifier-match 'none 'm)))
      (check-true (string? (check-pred-qualifier-match 'm 'none)))
      (check-true (string? (check-pred-qualifier-match 'm 'z))))

    (test-case "check-pred-qualifier-match #f 等同 none"
      (check-true (check-pred-qualifier-match 'none #f))))

   ;; --------------------------------------------------------
   ;; parse-template-signature/detailed
   ;; --------------------------------------------------------
   (test-suite
    "parse-template-signature/detailed"

    (test-case "普通操作数无限定符"
      (define result (parse-template-signature/detailed "XUInteger, XUInteger"))
      (check-equal? (length result) 2)
      (check-equal? (operand-info-type (car result)) 'gpr-64)
      (check-false (operand-info-pred-qualifier (car result))))

    (test-case "SVE P 带 /M"
      (define result (parse-template-signature/detailed "PUInteger/M"))
      (check-equal? (length result) 1)
      (check-equal? (operand-info-type (car result)) 'sve-p)
      (check-equal? (operand-info-pred-qualifier (car result)) 'm))

    (test-case "SVE P 带 /Z"
      (define result (parse-template-signature/detailed "PUInteger/Z"))
      (check-equal? (operand-info-pred-qualifier (car result)) 'z))

    (test-case "SVE P 无限定符"
      (define result (parse-template-signature/detailed "PUInteger"))
      (check-equal? (operand-info-pred-qualifier (car result)) 'none)))

   ;; --------------------------------------------------------
   ;; classify-ast-operand/detailed
   ;; --------------------------------------------------------
   (test-suite
    "classify-ast-operand/detailed"

    (test-case "GPR 无谓词信息"
      (define result (classify-ast-operand/detailed
                      (ast-reg 'x 0 #f #f #f #f no-srcloc)))
      (check-equal? (operand-info-type result) 'gpr-64)
      (check-false (operand-info-pred-qualifier result)))

    (test-case "P 寄存器带 /m"
      (define result (classify-ast-operand/detailed
                      (ast-reg 'p 0 #f #f #f 'm no-srcloc)))
      (check-equal? (operand-info-type result) 'sve-p)
      (check-equal? (operand-info-pred-qualifier result) 'm))

    (test-case "P 寄存器无限定符"
      (define result (classify-ast-operand/detailed
                      (ast-reg 'p 0 #f #f #f #f no-srcloc)))
      (check-equal? (operand-info-pred-qualifier result) 'none))

    (test-case "立即数保留类型"
      (define result (classify-ast-operand/detailed (ast-imm 42 no-srcloc)))
      (check-equal? (operand-info-type result) 'immediate)
      (check-false (operand-info-pred-qualifier result))))))

;; ============================================================
;; 执行
;; ============================================================

(module+ main
  (void (run-tests operand-type-tests)))

(module+ test
  (void (run-tests operand-type-tests)))
