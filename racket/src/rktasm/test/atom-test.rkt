#lang racket

(require rackunit
         rackunit/text-ui
         racket/match
         "../parser/ast.rkt"
         "../parser/parser.rkt"
         "../codegen/emit.rkt")

;; ============================================================
;; AST 和 Emit 测试
;; ============================================================
;;
;; 测试 AST 构造和输出
;; 使用实际的 parser/ast.rkt 和 codegen/emit.rkt API

;; 辅助构造函数 (适配新 API)
;; ast-reg: kind id group-size index element pred-mode loc
(define (R kind id [elem #f] [index #f] [arr #f] [pred #f])
  (ast-reg kind id #f index (or arr elem) pred no-srcloc))
(define (I v) (ast-imm v no-srcloc))
(define (S kind [amt #f]) (ast-shift kind amt no-srcloc))
(define (E kind [amt #f]) (ast-extend kind amt no-srcloc))
(define (C code) (ast-cond code no-srcloc))
(define (L name) (ast-label name #f no-srcloc))

;; 内存构造: ast-mem base offset index-mode shift extend loc
(define (M base [offset #f] [mode 'offset] [shift #f] [extend #f])
  (ast-mem base offset mode shift extend no-srcloc))

;; 指令构造
(define (ins mnem suffix operands)
  (ast-ins mnem suffix operands no-srcloc))

;; ============================================================
;; 测试套件
;; ============================================================

(define atom-tests
  (test-suite
   "AST 和 Emit 测试"

   ;; ----------------------------------------------------------
   ;; 1. 寄存器输出测试
   ;; ----------------------------------------------------------
   (test-suite
    "寄存器输出"

    (test-case "基础 GPR x0"
      (check-equal? (emit-reg (R 'x 0)) "x0"))

    (test-case "SP 寄存器"
      (check-equal? (emit-reg (R 'x 'sp)) "sp"))

    (test-case "XZR 寄存器"
      (check-equal? (emit-reg (R 'x 'zr)) "xzr"))

    (test-case "基础 GPR w0"
      (check-equal? (emit-reg (R 'w 0)) "w0"))

    (test-case "WZR 寄存器"
      (check-equal? (emit-reg (R 'w 'zr)) "wzr"))

    (test-case "SIMD 向量 v0.4s"
      (check-equal? (emit-reg (R 'v 0 '4s)) "v0.4s"))

    (test-case "SIMD 标量带索引 v0.s[1]"
      (check-equal? (emit-reg (R 'v 0 's 1)) "v0.s[1]"))

    (test-case "SVE z0"
      (check-equal? (emit-reg (R 'z 0)) "z0"))

    (test-case "谓词 p0"
      (check-equal? (emit-reg (R 'p 0)) "p0"))

    (test-case "谓词 p0/m"
      (check-equal? (emit-reg (R 'p 0 #f #f #f 'm)) "p0/m"))

    (test-case "谓词 p0/z"
      (check-equal? (emit-reg (R 'p 0 #f #f #f 'z)) "p0/z")))

   ;; ----------------------------------------------------------
   ;; 2. 操作数输出测试
   ;; ----------------------------------------------------------
   (test-suite
    "操作数输出"

    (test-case "正立即数"
      (check-equal? (emit-operand (I 42)) "#42"))

    (test-case "负立即数"
      (check-equal? (emit-operand (I -16)) "#-16"))

    (test-case "LSL 移位带数量"
      (check-equal? (emit-operand (S 'lsl 3)) "LSL #3"))

    (test-case "ASR 移位带数量"
      (check-equal? (emit-operand (S 'asr 2)) "ASR #2"))

    (test-case "LSL 移位无数量"
      (check-equal? (emit-operand (S 'lsl)) "LSL"))

    (test-case "SXTW 扩展"
      (check-equal? (emit-operand (E 'sxtw)) "SXTW"))

    (test-case "UXTX 扩展带数量"
      (check-equal? (emit-operand (E 'uxtx 2)) "UXTX #2"))

    (test-case "条件码 EQ"
      (check-equal? (emit-operand (C 'eq)) "EQ"))

    (test-case "条件码 NE"
      (check-equal? (emit-operand (C 'ne)) "NE")))

   ;; ----------------------------------------------------------
   ;; 3. 内存操作数测试
   ;; ----------------------------------------------------------
   (test-suite
    "内存操作数"

    (test-case "简单内存 [base]"
      (check-equal? (emit-operand (M (R 'x 0))) "[x0]"))

    (test-case "offset 模式 [base, #imm]"
      (check-equal? (emit-operand (M (R 'x 0) (I 16))) "[x0, #16]"))

    (test-case "寄存器偏移 [base, reg]"
      (check-equal? (emit-operand (M (R 'x 0) (R 'x 1))) "[x0, x1]"))

    (test-case "寄存器偏移 + 移位"
      (check-equal? (emit-operand (M (R 'x 0) (R 'x 1) 'offset (S 'lsl 3))) "[x0, x1, LSL #3]"))

    (test-case "pre-index [base, #imm]!"
      (check-equal? (emit-operand (M (R 'x 'sp) (I -16) 'pre)) "[sp, #-16]!"))

    (test-case "post-index [base], #imm"
      (check-equal? (emit-operand (M (R 'x 'sp) (I 16) 'post)) "[sp], #16")))

   ;; ----------------------------------------------------------
   ;; 4. 指令输出测试
   ;; ----------------------------------------------------------
   (test-suite
    "指令输出"

    (test-case "三寄存器 add"
      (check-equal?
       (emit-instruction (ins 'add #f (list (R 'x 0) (R 'x 1) (R 'x 2))))
       "    add x0, x1, x2"))

    (test-case "带移位 add"
      (check-equal?
       (emit-instruction (ins 'add #f (list (R 'x 0) (R 'x 1) (R 'x 2) (S 'lsl) (I 3))))
       "    add x0, x1, x2, LSL #3"))

    (test-case "带立即数 add"
      (check-equal?
       (emit-instruction (ins 'add #f (list (R 'x 0) (R 'x 1) (I 42))))
       "    add x0, x1, #42"))

    (test-case "内存加载 ldr"
      (check-equal?
       (emit-instruction (ins 'ldr #f (list (R 'x 0) (M (R 'x 1) (I 16)))))
       "    ldr x0, [x1, #16]"))

    (test-case "内存加载带索引 ldr"
      (check-equal?
       (emit-instruction (ins 'ldr #f (list (R 'x 0) (M (R 'x 1) (R 'x 2) 'offset (S 'lsl 3)))))
       "    ldr x0, [x1, x2, LSL #3]"))

    (test-case "存储对 pre-index stp"
      (check-equal?
       (emit-instruction (ins 'stp #f (list (R 'x 29) (R 'x 30) (M (R 'x 'sp) (I -16) 'pre))))
       "    stp x29, x30, [sp, #-16]!"))

    (test-case "加载对 post-index ldp"
      (check-equal?
       (emit-instruction (ins 'ldp #f (list (R 'x 29) (R 'x 30) (M (R 'x 'sp) (I 16) 'post))))
       "    ldp x29, x30, [sp], #16"))

    (test-case "条件选择 csel"
      (check-equal?
       (emit-instruction (ins 'csel #f (list (R 'x 0) (R 'x 1) (R 'x 2) (C 'eq))))
       "    csel x0, x1, x2, EQ"))

    (test-case "条件分支 b.eq"
      (check-equal?
       (emit-instruction (ins 'b 'eq (list (L 'label))))
       "    b.eq label"))

    (test-case "SIMD fadd"
      (check-equal?
       (emit-instruction (ins 'fadd #f (list (R 'v 0 '4s) (R 'v 1 '4s) (R 'v 2 '4s))))
       "    fadd v0.4s, v1.4s, v2.4s"))

    (test-case "nop"
      (check-equal?
       (emit-instruction (ins 'nop #f '()))
       "    nop"))

    (test-case "ret"
      (check-equal?
       (emit-instruction (ins 'ret #f '()))
       "    ret")))))

;; ============================================================
;; 执行
;; ============================================================

(module+ main
  (void (run-tests atom-tests)))

(module+ test
  (void (run-tests atom-tests)))
