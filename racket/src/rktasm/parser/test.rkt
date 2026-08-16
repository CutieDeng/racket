#lang racket

(require "ast.rkt"
         "parser.rkt")

;; ============================================================
;; Parser 测试
;; ============================================================

(define (test-parse desc sexp)
  (printf "~a\n" desc)
  (printf "  Input:  ~s\n" sexp)
  (with-handlers ([exn:fail? (lambda (e) (printf "  Error:  ~a\n\n" (exn-message e)))])
    (define result (parse-instruction sexp))
    (printf "  AST:    ~s\n" result)
    (printf "  String: ~a\n\n" (ast->string result))))

(define (test-reg desc sym)
  (printf "~a\n" desc)
  (printf "  Input:  ~s\n" sym)
  (with-handlers ([exn:fail? (lambda (e) (printf "  Error:  ~a\n\n" (exn-message e)))])
    (define result (try-parse-register sym))
    (if result
        (begin
          (printf "  AST:    ~s\n" result)
          (printf "  String: ~a\n\n" (ast->string result)))
        (printf "  Result: #f (not a register)\n\n"))))

(define (test-parse/stx desc stx-str)
  (printf "~a\n" desc)
  (printf "  Input:  ~a\n" stx-str)
  (with-handlers ([exn:fail? (lambda (e) (printf "  Error:  ~a\n\n" (exn-message e)))])
    (define stx (read-syntax 'test (open-input-string stx-str)))
    (define result (parse-instruction/stx stx))
    (printf "  AST:    ~s\n" result)
    (printf "  Loc:    ~s\n" (ast-srcloc result))
    (printf "  String: ~a\n\n" (ast->string result))))

(printf "========== 寄存器解析测试 ==========\n\n")

;; 基础物理寄存器
(test-reg "物理 X 寄存器" 'x0)
(test-reg "物理 W 寄存器" 'w31)
(test-reg "物理 Z 寄存器" 'z15)
(test-reg "物理 P 寄存器" 'p7)

;; 特殊寄存器
(test-reg "Stack pointer" 'sp)
(test-reg "Zero register" 'xzr)

;; 虚拟寄存器
(test-reg "虚拟 X 寄存器" 'x.foo)
(test-reg "虚拟 Z 寄存器" 'z.vec)

;; 带元素大小
(test-reg "Z 寄存器带元素" 'z0.B)
(test-reg "虚拟 Z 带元素" 'z.x.D)
(test-reg "V 寄存器带排列" 'v0.4s)

;; 谓词模式
(test-reg "P 寄存器带模式" 'p0/m)
(test-reg "虚拟 P 带模式" 'p.mask/z)

;; 寄存器组
(test-reg "物理寄存器组" 'z0*4)
(test-reg "虚拟寄存器组" 'z.vec*4)
(test-reg "组带索引" 'z0*4@2)
(test-reg "完整形式" 'z0*4@2.B)

;; 无效输入测试 (应该返回 #f)
(test-reg "标签 (非寄存器)" 'loop)
(test-reg "无效符号" 'foo)

(printf "========== 指令解析测试 ==========\n\n")

;; 基础指令
(test-parse "基础 ADD 指令" '(add x0 x1 x2))
(test-parse "W 寄存器 ADD" '(add w0 w1 w2))

;; 带移位
(test-parse "ADD 带 LSL" '(add x0 x1 x2 lsl 3))
(test-parse "SUB 带 ASR" '(sub x0 x1 x2 asr 5))

;; 带扩展
(test-parse "ADD 带 SXTW" '(add x0 x1 w2 sxtw))
(test-parse "ADD 带 UXTB 和 amount" '(add x0 x1 w2 uxtb 2))

;; 条件分支
(test-parse "条件分支 B.EQ" '(b.eq loop))

;; 内存访问
(test-parse "LDR 简单" '(ldr x0 (x1)))
(test-parse "LDR offset" '(ldr x0 (x1 16)))
(test-parse "LDR pre-index" '(ldr x0 (x1 16 !)))
(test-parse "LDR 寄存器 offset" '(ldr x0 (x1 x2)))
(test-parse "LDR 带 LSL" '(ldr x0 (x1 x2 lsl 3)))
(test-parse "LDR 带 SXTW" '(ldr x0 (x1 w2 sxtw)))

;; SVE 指令
(test-parse "SVE ADD" '(add z.d.D z.a.D z.b.D))
(test-parse "SVE 谓词" '(add z.d.S p.mask/m z.a.S z.b.S))

;; 寄存器组
(test-parse "LD4 寄存器组" '(ld4 (z0.B z1.B z2.B z3.B) p0 (x0)))
(test-parse "使用 *4 语法" '(ld4 z0*4.B p0 (x0)))

(printf "========== 带位置信息解析测试 ==========\n\n")

(test-parse/stx "带位置的 ADD" "(add x0 x1 x2)")
(test-parse/stx "带位置的 LDR" "(ldr x0 (x1 16))")
(test-parse/stx "带位置的条件分支" "(b.eq target)")

(printf "========== 错误处理测试 ==========\n\n")

;; 让 match 自然失败
(test-parse "无效内存语法" '(ldr x0 (1 2 3 4 5)))
(test-parse "空指令" '())

(printf "========== 测试完成 ==========\n")
