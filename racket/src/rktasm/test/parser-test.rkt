#lang racket

(require rackunit
         rackunit/text-ui
         "../parser/ast.rkt"
         "../parser/parser.rkt"
         "../codegen/emit.rkt")

;; ============================================================
;; Parser Tests
;; ============================================================

(define parser-tests
  (test-suite
   "Lisp-Style Assembly Parser Tests"

   ;; 物理寄存器
   (test-suite
    "Physical Registers"

    (test-case "Parse x0-x30 registers"
      (define result (parse-instruction '(add x0 x1 x2)))
      (check-equal? (ast-ins-mnemonic result) 'add)
      (check-false (ast-ins-suffix result))
      (check-equal? (length (ast-ins-operands result)) 3)
      (define first-op (car (ast-ins-operands result)))
      (check-true (ast-reg? first-op))
      (check-equal? (ast-reg-kind first-op) 'x)
      (check-equal? (ast-reg-id first-op) 0))

    (test-case "Parse w0-w31 registers"
      (define result (parse-instruction '(add w0 w1 w2)))
      (define first-op (car (ast-ins-operands result)))
      (check-true (ast-reg? first-op))
      (check-equal? (ast-reg-kind first-op) 'w)
      (check-equal? (ast-reg-id first-op) 0))

    (test-case "Parse sp register"
      (define result (parse-instruction '(mov sp x0)))
      (define first-op (car (ast-ins-operands result)))
      (check-true (ast-reg? first-op))
      (check-equal? (ast-reg-id first-op) 'sp))

    (test-case "Parse xzr register"
      (define result (parse-instruction '(mov x0 xzr)))
      (define second-op (cadr (ast-ins-operands result)))
      (check-true (ast-reg? second-op))
      (check-equal? (ast-reg-id second-op) 'zr))

    (test-case "Parse vector register with arrangement"
      (define result (parse-instruction '(add v0.4s v1.4s v2.4s)))
      (define first-op (car (ast-ins-operands result)))
      (check-true (ast-reg? first-op))
      (check-equal? (ast-reg-kind first-op) 'v)
      (check-equal? (ast-reg-id first-op) 0)
      (check-equal? (ast-reg-element first-op) '4s))

    (test-case "Parse q register with arrangement suffix (deferred validation)"
      (define result (parse-instruction '(movi q0.16b 1)))
      (define first-op (car (ast-ins-operands result)))
      (check-true (ast-reg? first-op))
      (check-equal? (ast-reg-kind first-op) 'q)
      (check-equal? (ast-reg-id first-op) 0)
      (check-equal? (ast-reg-element first-op) '16b))

    (test-case "Parse x register with arrangement suffix (deferred validation)"
      (define result (parse-instruction '(add x0.8b x1 x2)))
      (define first-op (car (ast-ins-operands result)))
      (check-true (ast-reg? first-op))
      (check-equal? (ast-reg-kind first-op) 'x)
      (check-equal? (ast-reg-id first-op) 0)
      (check-equal? (ast-reg-element first-op) '8b)))

   ;; 虚拟寄存器
   (test-suite
    "Virtual Registers"

    (test-case "Parse x.name virtual register"
      (define result (parse-instruction '(add x.a x.b x.c)))
      (define first-op (car (ast-ins-operands result)))
      (check-true (ast-reg? first-op))
      (check-equal? (ast-reg-kind first-op) 'x)
      (check-equal? (ast-reg-id first-op) 'a))

    (test-case "Parse w.name virtual register"
      (define result (parse-instruction '(add w.foo w.bar w.baz)))
      (define first-op (car (ast-ins-operands result)))
      (check-true (ast-reg? first-op))
      (check-equal? (ast-reg-kind first-op) 'w)
      (check-equal? (ast-reg-id first-op) 'foo))

    (test-case "Mix physical and virtual registers"
      (define result (parse-instruction '(add sp x.a x.b)))
      (define first-op (car (ast-ins-operands result)))
      (check-true (ast-reg? first-op))
      (check-equal? (ast-reg-id first-op) 'sp)
      (define second-op (cadr (ast-ins-operands result)))
      (check-true (ast-reg? second-op))
      (check-equal? (ast-reg-id second-op) 'a))

    (test-case "Parse virtual q register with arrangement suffix (deferred validation)"
      (define result (parse-instruction '(movi q.a.16b 1)))
      (define first-op (car (ast-ins-operands result)))
      (check-true (ast-reg? first-op))
      (check-equal? (ast-reg-kind first-op) 'q)
      (check-equal? (ast-reg-id first-op) 'a)
      (check-equal? (ast-reg-element first-op) '16b))

    (test-case "Parse virtual x register with arrangement suffix (deferred validation)"
      (define result (parse-instruction '(add x.a.8b x1 x2)))
      (define first-op (car (ast-ins-operands result)))
      (check-true (ast-reg? first-op))
      (check-equal? (ast-reg-kind first-op) 'x)
      (check-equal? (ast-reg-id first-op) 'a)
      (check-equal? (ast-reg-element first-op) '8b)))

   ;; SVE 寄存器
   (test-suite
    "SVE Registers"

    (test-case "Parse z register with element size"
      (define result (parse-instruction '(add z0.B z1.B z2.B)))
      (define first-op (car (ast-ins-operands result)))
      (check-true (ast-reg? first-op))
      (check-equal? (ast-reg-kind first-op) 'z)
      (check-equal? (ast-reg-id first-op) 0)
      (check-equal? (ast-reg-element first-op) 'B))

    (test-case "Parse virtual z register with element size"
      (define result (parse-instruction '(add z.x.B z.y.B z.z.B)))
      (define first-op (car (ast-ins-operands result)))
      (check-true (ast-reg? first-op))
      (check-equal? (ast-reg-kind first-op) 'z)
      (check-equal? (ast-reg-id first-op) 'x)
      (check-equal? (ast-reg-element first-op) 'B)))

   ;; 谓词寄存器
   (test-suite
    "Predicate Registers"

    (test-case "Parse p register with merging mode"
      (define result (parse-instruction '(add z0.S p0/m z1.S z2.S)))
      (define p-op (cadr (ast-ins-operands result)))
      (check-true (ast-reg? p-op))
      (check-equal? (ast-reg-kind p-op) 'p)
      (check-equal? (ast-reg-id p-op) 0)
      (check-equal? (ast-reg-pred-mode p-op) 'm))

    (test-case "Parse p register with zeroing mode"
      (define result (parse-instruction '(mov z0.D p0/z z1.D)))
      (define p-op (cadr (ast-ins-operands result)))
      (check-true (ast-reg? p-op))
      (check-equal? (ast-reg-kind p-op) 'p)
      (check-equal? (ast-reg-pred-mode p-op) 'z))

    (test-case "Parse virtual p register with mode"
      (define result (parse-instruction '(add z.a.S p.check/m z.b.S z.c.S)))
      (define p-op (cadr (ast-ins-operands result)))
      (check-true (ast-reg? p-op))
      (check-equal? (ast-reg-kind p-op) 'p)
      (check-equal? (ast-reg-id p-op) 'check)
      (check-equal? (ast-reg-pred-mode p-op) 'm)))

   ;; 寄存器组
   (test-suite
    "Register Lists"

    (test-case "Parse physical register list"
      (define result (parse-instruction '(ld1 (z0.B z1.B z2.B) p0/z (x0))))
      (define reglist (car (ast-ins-operands result)))
      (check-true (ast-reglist? reglist))
      (check-equal? (length (ast-reglist-regs reglist)) 3))

    (test-case "Parse virtual register list"
      (define result (parse-instruction '(ld1 (z.x.B z.y.B z.z.B) p.g/z (x.base))))
      (define reglist (car (ast-ins-operands result)))
      (check-true (ast-reglist? reglist))
      (define regs (ast-reglist-regs reglist))
      (check-equal? (ast-reg-id (car regs)) 'x)
      (check-equal? (ast-reg-id (cadr regs)) 'y)
      (check-equal? (ast-reg-id (caddr regs)) 'z)))

   ;; 平铺移位
   (test-suite
    "Flat Shift Syntax"

    (test-case "Parse LSL shift (flat)"
      (define result (parse-instruction '(add x0 x1 x2 lsl 3)))
      (check-equal? (length (ast-ins-operands result)) 5)
      (define shift-op (list-ref (ast-ins-operands result) 3))
      (check-true (ast-shift? shift-op))
      (check-equal? (ast-shift-kind shift-op) 'lsl))

    (test-case "Parse ASR shift (flat)"
      (define result (parse-instruction '(mov x0 x1 asr 2)))
      (define shift-op (list-ref (ast-ins-operands result) 2))
      (check-true (ast-shift? shift-op))
      (check-equal? (ast-shift-kind shift-op) 'asr)))

   ;; 平铺扩展
   (test-suite
    "Flat Extend Syntax"

    (test-case "Parse SXTW extend without amount"
      (define result (parse-instruction '(add x0 x1 w.a sxtw)))
      (define extend-op (last (ast-ins-operands result)))
      (check-true (ast-extend? extend-op))
      (check-equal? (ast-extend-kind extend-op) 'sxtw)
      (check-false (ast-extend-amount extend-op)))

    (test-case "Parse UXTB extend with amount"
      (define result (parse-instruction '(add x0 x1 w.a uxtb 2)))
      (define extend-op (list-ref (ast-ins-operands result) 3))
      (check-true (ast-extend? extend-op))
      (check-equal? (ast-extend-kind extend-op) 'uxtb)))

   ;; 内存寻址
   (test-suite
    "Memory Addressing"

    (test-case "Parse simple memory: (base)"
      (define result (parse-instruction '(ldr x0 (x1))))
      (define mem-op (cadr (ast-ins-operands result)))
      (check-true (ast-mem? mem-op))
      (check-equal? (ast-mem-index-mode mem-op) 'offset))

    (test-case "Parse memory with immediate: (base imm)"
      (define result (parse-instruction '(ldr x0 (x1 16))))
      (define mem-op (cadr (ast-ins-operands result)))
      (check-true (ast-mem? mem-op))
      (check-true (ast-imm? (ast-mem-offset mem-op)))
      (check-equal? (ast-imm-value (ast-mem-offset mem-op)) 16))

    (test-case "Parse pre-index: (base offset !)"
      (define result (parse-instruction '(stp x29 x30 (sp -16 !))))
      (define mem-op (caddr (ast-ins-operands result)))
      (check-true (ast-mem? mem-op))
      (check-equal? (ast-mem-index-mode mem-op) 'pre)))

   ;; 条件分支
   (test-suite
    "Conditional Branches"

    (test-case "Parse b.eq with label"
      (define result (parse-instruction '(b.eq loop)))
      (check-equal? (ast-ins-mnemonic result) 'b)
      (check-equal? (ast-ins-suffix result) 'eq))

    (test-case "Virtual register with dot is not condition"
      (define result (parse-instruction '(mov x.foo x.bar)))
      (check-equal? (ast-ins-mnemonic result) 'mov)
      (check-false (ast-ins-suffix result))))

   ;; Round-trip: parse -> emit
   (test-suite
    "Round-Trip (Parse -> Emit)"

    (test-case "Simple ADD"
      (define result (parse-instruction '(add x0 x1 x2)))
      (check-equal? (emit-instruction result) "    add x0, x1, x2"))

    (test-case "ADD with shift"
      (define result (parse-instruction '(add x0 x1 x2 lsl 3)))
      (check-equal? (emit-instruction result) "    add x0, x1, x2, LSL #3"))

    (test-case "STP with pre-index"
      (define result (parse-instruction '(stp x29 x30 (sp -16 !))))
      (check-equal? (emit-instruction result) "    stp x29, x30, [sp, #-16]!"))

    (test-case "Predicate register with mode"
      (define result (parse-instruction '(mov z0.D p0/m z1.D)))
      (check-equal? (emit-instruction result) "    mov z0.D, p0/m, z1.D")))))

;; Run tests
(module+ main
  (void (run-tests parser-tests)))

(module+ test
  (void (run-tests parser-tests)))
