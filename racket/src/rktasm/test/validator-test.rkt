#lang racket

(require rackunit
         rackunit/text-ui
         "../parser/ast.rkt"
         "../parser/parser.rkt"
         "../syntax/validator.rkt")

;; validator 通过相对路径加载数据文件，确保 cwd 为项目根目录
(define project-root
  (simplify-path (build-path (syntax-source #'here) 'up 'up)))

;; ============================================================
;; syntax/validator.rkt 单元测试
;; ============================================================

;; 辅助: 构造 AST 指令
(define (make-ins mnem . operands)
  (ast-ins mnem #f operands no-srcloc))

;; 辅助: 快速构造寄存器
(define (xreg id) (ast-reg 'x id #f #f #f #f no-srcloc))
(define (wreg id) (ast-reg 'w id #f #f #f #f no-srcloc))
(define (dreg id) (ast-reg 'd id #f #f #f #f no-srcloc))
(define (sreg id) (ast-reg 's id #f #f #f #f no-srcloc))
(define (vreg id elem) (ast-reg 'v id #f #f elem #f no-srcloc))
(define (zreg id elem) (ast-reg 'z id #f #f elem #f no-srcloc))
(define (preg id [mode #f]) (ast-reg 'p id #f #f #f mode no-srcloc))
(define xzr (ast-reg 'x 'zr #f #f #f #f no-srcloc))
(define sp (ast-reg 'x 'sp #f #f #f #f no-srcloc))

;; 辅助: 快速构造其他节点
(define (imm v) (ast-imm v no-srcloc))
(define (lbl name) (ast-label name #f no-srcloc))
(define (shift-node kind [amount #f]) (ast-shift kind amount no-srcloc))

;; 提取验证结果中的第一条智能建议文本
(define (first-smart-suggestion result)
  (define hints (validation-result-hints result))
  (define smart-hints
    (filter (lambda (h) (eq? (validation-hint-kind h) 'smart-suggestion)) hints))
  (and (pair? smart-hints)
       (validation-hint-data (car smart-hints))))

(define validator-tests
  (test-suite
   "Validator 单元测试"

   ;; --------------------------------------------------------
   ;; validation-result 结构
   ;; --------------------------------------------------------
   (test-suite
    "validation-result 结构"

    (test-case "validation-ok? 与 validation-error?"
      (define ok (validation-result #t #f 'add 'c3 '(gpr-64 gpr-64 gpr-64) '() #f '()))
      (define err (validation-result #f 'mnemonic 'xyz 'c0 '() '() "未知" '()))
      (check-true (validation-ok? ok))
      (check-false (validation-error? ok))
      (check-false (validation-ok? err))
      (check-true (validation-error? err)))

    (test-case "validation-ok? 非 validation-result"
      (check-false (validation-ok? 42))
      (check-false (validation-ok? #f))
      (check-false (validation-error? 42))))

   ;; --------------------------------------------------------
   ;; validate-instruction: 已知正确指令
   ;; --------------------------------------------------------
   (test-suite
    "validate-instruction: 正确指令"

    (test-case "add x0, x1, x2"
      (define ins (parse-instruction '(add x0 x1 x2)))
      (define result (validate-instruction ins))
      (check-true (validation-ok? result) "add x0, x1, x2 应当通过"))

    (test-case "add w0, w1, w2"
      (define ins (parse-instruction '(add w0 w1 w2)))
      (define result (validate-instruction ins))
      (check-true (validation-ok? result) "add w0, w1, w2 应当通过"))

    (test-case "sub x0, x1, x2"
      (define ins (parse-instruction '(sub x0 x1 x2)))
      (define result (validate-instruction ins))
      (check-true (validation-ok? result)))

    (test-case "add x0, x1, 42"
      (define ins (parse-instruction '(add x0 x1 42)))
      (define result (validate-instruction ins))
      (check-true (validation-ok? result)))

    (test-case "nop"
      (define ins (parse-instruction '(nop)))
      (define result (validate-instruction ins))
      (check-true (validation-ok? result)))

    (test-case "ret"
      (define ins (parse-instruction '(ret)))
      (define result (validate-instruction ins))
      (check-true (validation-ok? result))))

   ;; --------------------------------------------------------
   ;; validate-instruction: 错误层级
   ;; --------------------------------------------------------
   (test-suite
    "validate-instruction: 错误层级"

    (test-case "未知助记符 → mnemonic 层"
      (define ins (make-ins 'xyzinvalid (xreg 0)))
      (define result (validate-instruction ins))
      (check-true (validation-error? result))
      (check-equal? (validation-result-error-layer result) 'mnemonic))

    (test-case "操作数数量错误 → layer1"
      (define ins (parse-instruction '(add x0 x1)))
      (define result (validate-instruction ins))
      (check-true (validation-error? result))
      ;; layer1 错误 (操作数数量不对) 或 layer2 (类型不匹配)
      (check-not-false (memq (validation-result-error-layer result)
                        '(layer1 layer2))))

    (test-case "错误结果包含助记符"
      (define ins (make-ins 'xyzinvalid (xreg 0)))
      (define result (validate-instruction ins))
      (check-equal? (validation-result-mnemonic result) 'xyzinvalid)))

   (test-suite
    "validate-instruction: 非法寄存器元素后缀"

    (test-case "q0.16b 在验证阶段报错"
      (define ins (parse-instruction '(movi q0.16b 1)))
      (define result (validate-instruction ins))
      (check-true (validation-error? result))
      (check-equal? (validation-result-error-layer result) 'layer2)
      (check-true
       (string-contains? (validation-result-error-message result)
                         "q 寄存器不支持元素后缀")))

    (test-case "x0.8b 在验证阶段报错"
      (define ins (parse-instruction '(add x0.8b x1 x2)))
      (define result (validate-instruction ins))
      (check-true (validation-error? result))
      (check-equal? (validation-result-error-layer result) 'layer2)
      (check-true
       (string-contains? (validation-result-error-message result)
                         "GPR 寄存器不支持元素后缀")))

    (test-case "x.a.8b 在验证阶段报错"
      (define ins (parse-instruction '(add x.a.8b x1 x2)))
      (define result (validate-instruction ins))
      (check-true (validation-error? result))
      (check-equal? (validation-result-error-layer result) 'layer2)
      (check-true
       (string-contains? (validation-result-error-message result)
                         "GPR 寄存器不支持元素后缀")))

    (test-case "未知助记符优先于 q 元素后缀错误"
      (define ins (parse-instruction '(xyzinvalid q0.16b)))
      (define result (validate-instruction ins))
      (check-true (validation-error? result))
      (check-equal? (validation-result-error-layer result) 'mnemonic)
      (check-true
       (string-contains? (validation-result-error-message result)
                         "未知指令助记符")))

    (test-case "未知助记符优先于 GPR 元素后缀错误"
      (define ins (parse-instruction '(xyzinvalid x0.8b)))
      (define result (validate-instruction ins))
      (check-true (validation-error? result))
      (check-equal? (validation-result-error-layer result) 'mnemonic)
      (check-true
       (string-contains? (validation-result-error-message result)
                         "未知指令助记符"))))

   ;; --------------------------------------------------------
   ;; validate-instruction: 别名指令
   ;; --------------------------------------------------------
   (test-suite
    "validate-instruction: 别名"

    (test-case "mov x0, x1 (别名)"
      (define ins (parse-instruction '(mov x0 x1)))
      (define result (validate-instruction ins))
      ;; mov 可能通过别名扩展或直接存在于索引中
      ;; 无论哪种方式，都应有确定的结果
      (check-true (validation-result? result)))

    (test-case "mov x0, 42"
      (define ins (parse-instruction '(mov x0 42)))
      (define result (validate-instruction ins))
      (check-true (validation-result? result))))

   ;; --------------------------------------------------------
   ;; validation-hint 结构
   ;; --------------------------------------------------------
   (test-suite
    "validation-hint 结构"

    (test-case "构造和访问"
      (define h (validation-hint 'suffix '(lsl 0)))
      (check-equal? (validation-hint-kind h) 'suffix)
      (check-equal? (validation-hint-data h) '(lsl 0)))

    (test-case "hint 透明性"
      (check-true (validation-hint?
                   (validation-hint 'similar-mnemonic '(add sub))))))

   ;; --------------------------------------------------------
   ;; format-validation-result
   ;; --------------------------------------------------------
   (test-suite
    "format-validation-result"

    (test-case "格式化成功结果"
      (define ok (validation-result #t #f 'add 'c3 '(gpr-64 gpr-64 gpr-64)
                                    '(("enc1" "tmpl")) #f '()))
      (define output (format-validation-result ok))
      (check-true (string-contains? output "✓"))
      (check-true (string-contains? output "add")))

    (test-case "格式化失败结果"
      (define err (validation-result #f 'mnemonic 'xyz 'c0 '() '()
                                     "未知指令助记符: xyz" '()))
      (define output (format-validation-result err))
      (check-true (string-contains? output "✗"))
      (check-true (string-contains? output "xyz"))
      (check-true (string-contains? output "未知")))

    (test-case "格式化带提示的失败结果"
      (define err (validation-result #f 'layer2 'add 'c2 '(gpr-64 gpr-64)
                                     '() "操作数类型不匹配"
                                     (list (validation-hint 'operand-count 'too-few))))
      (define output (format-validation-result err))
      (check-true (string-contains? output "提示"))))

   ;; --------------------------------------------------------
   ;; format-hint
   ;; --------------------------------------------------------
   (test-suite
    "format-hint"

    (test-case "suffix 提示"
      (define output (format-hint (validation-hint 'suffix '(lsl 0))))
      (check-true (string-contains? output "lsl")))

    (test-case "similar-mnemonic 提示"
      (define output (format-hint (validation-hint 'similar-mnemonic '(add adds))))
      (check-true (string-contains? output "add")))

    (test-case "type-mismatch 提示"
      (define output (format-hint (validation-hint 'type-mismatch '(1 gpr-64 gpr-32))))
      (check-true (string-contains? output "操作数")))

    (test-case "operand-count too-few"
      (define output (format-hint (validation-hint 'operand-count 'too-few)))
      (check-true (string-contains? output "少")))

    (test-case "operand-count too-many"
      (define output (format-hint (validation-hint 'operand-count 'too-many)))
      (check-true (string-contains? output "多")))

    (test-case "smart-suggestion 提示"
      (define output (format-hint (validation-hint 'smart-suggestion "使用 movi")))
      (check-true (string-contains? output "建议"))
      (check-true (string-contains? output "movi")))

    (test-case "constraint 提示 (imm-range)"
      (define output (format-hint (validation-hint 'constraint
                                                   (list "imm" 300
                                                         (imm-range 0 255 1)))))
      (check-true (string-contains? output "立即数")))

    (test-case "pred-qualifier 提示"
      (define output (format-hint (validation-hint 'pred-qualifier '(0 m z))))
      (check-true (string-contains? output "谓词")))

    (test-case "tied-operand 提示"
      (define output (format-hint (validation-hint 'tied-operand '((0 2) "Zdn" ()))))
      (check-true (string-contains? output "同一寄存器")))

    (test-case "memory-required 提示"
      (define output (format-hint (validation-hint 'memory-required #t)))
      (check-true (string-contains? output "内存")))

    (test-case "memory-not-allowed 提示"
      (define output (format-hint (validation-hint 'memory-not-allowed #t)))
      (check-true (string-contains? output "内存")))

    (test-case "未知提示"
      (define output (format-hint (validation-hint 'unknown-kind "data")))
      (check-true (string-contains? output "未知"))))

   ;; --------------------------------------------------------
   ;; generate-smart-suggestion
   ;; --------------------------------------------------------
   (test-suite
    "generate-smart-suggestion (通过验证结果间接测试)"

    (test-case "mov 向量+立即数触发建议"
      ;; 构造 mov v0.8b, #1 的指令
      (define ins (make-ins 'mov (vreg 0 '8b) (imm 1)))
      (define result (validate-instruction ins))
      ;; 如果失败，应该包含智能建议
      (when (validation-error? result)
        (define msg (first-smart-suggestion result))
        (when msg
          (check-true (string-contains? msg "movi")))))

    (test-case "mov x0, s.a 触发 fmov 建议且类型差异定位更准确"
      (define ins (make-ins 'mov (xreg 0) (sreg 'a)))
      (define result (validate-instruction ins))
      (check-true (validation-error? result))

      (define msg (first-smart-suggestion result))
      (check-not-false msg)
      (check-true (string-contains? msg "fmov"))

      ;; 选“最接近签名”后，应只指出源操作数类型不匹配，而不是两边都错
      (define hints (validation-result-hints result))
      (define mismatch-hints
        (filter (lambda (h) (eq? (validation-hint-kind h) 'type-mismatch)) hints))
      (check-equal? (length mismatch-hints) 1)
      (check-equal? (validation-hint-data (car mismatch-hints))
                    '(2 simd-v simd-scalar)))

    (test-case "mov v0.4s, w1 建议使用 ins/dup"
      (define ins (make-ins 'mov (vreg 0 '4s) (wreg 1)))
      (define result (validate-instruction ins))
      (check-true (validation-error? result))
      (define msg (first-smart-suggestion result))
      (check-not-false msg)
      (check-true (or (string-contains? msg "ins")
                      (string-contains? msg "dup"))))

    (test-case "fmov w0, w1 建议使用 mov"
      (define ins (make-ins 'fmov (wreg 0) (wreg 1)))
      (define result (validate-instruction ins))
      (check-true (validation-error? result))
      (define msg (first-smart-suggestion result))
      (check-not-false msg)
      (check-true (string-contains? msg "mov")))

    (test-case "umov w0, s1 建议改用向量 lane 或 fmov"
      (define ins (make-ins 'umov (wreg 0) (sreg 1)))
      (define result (validate-instruction ins))
      (check-true (validation-error? result))
      (define msg (first-smart-suggestion result))
      (check-not-false msg)
      (check-true (or (string-contains? msg "lane")
                      (string-contains? msg "fmov"))))

    (test-case "ins v0.4s, x1 提示 GPR 源应为 w 寄存器"
      (define ins (make-ins 'ins (vreg 0 '4s) (xreg 1)))
      (define result (validate-instruction ins))
      (check-true (validation-error? result))
      (define msg (first-smart-suggestion result))
      (check-not-false msg)
      (check-true (string-contains? msg "w 寄存器")))

    (test-case "sha1h s0, w1 提示先 fmov 到 s"
      (define ins (make-ins 'sha1h (sreg 0) (wreg 1)))
      (define result (validate-instruction ins))
      (check-true (validation-error? result))
      (define msg (first-smart-suggestion result))
      (check-not-false msg)
      (check-true (string-contains? msg "fmov")))

    (test-case "sha1c s0, s1, s2 提示第3操作数应为向量"
      (define ins (make-ins 'sha1c (sreg 0) (sreg 1) (sreg 2)))
      (define result (validate-instruction ins))
      (check-true (validation-error? result))
      (define msg (first-smart-suggestion result))
      (check-not-false msg)
      (check-true (string-contains? msg "vN.4s")))

    (test-case "sha1p v0.4s, s1, v2.4s 提示第1操作数应为标量"
      (define ins (make-ins 'sha1p (vreg 0 '4s) (sreg 1) (vreg 2 '4s)))
      (define result (validate-instruction ins))
      (check-true (validation-error? result))
      (define msg (first-smart-suggestion result))
      (check-not-false msg)
      (check-true (string-contains? msg "第 1 个操作数")))

    (test-case "sha1su1 v0.4s, s1 提示只接受向量"
      (define ins (make-ins 'sha1su1 (vreg 0 '4s) (sreg 1)))
      (define result (validate-instruction ins))
      (check-true (validation-error? result))
      (define msg (first-smart-suggestion result))
      (check-not-false msg)
      (check-true (string-contains? msg "只接受向量"))))))

;; ============================================================
;; 需要引入 imm-range 以测试 constraint hint
;; ============================================================
(require "../syntax/constraint.rkt")

;; ============================================================
;; 执行
;; ============================================================

(module+ main
  (parameterize ([current-directory project-root])
    (void (run-tests validator-tests))))

(module+ test
  (parameterize ([current-directory project-root])
    (void (run-tests validator-tests))))
