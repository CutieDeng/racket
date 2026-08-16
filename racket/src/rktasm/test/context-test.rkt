#lang racket

;; ============================================================
;; test/context-test.rkt - .context (命名上下文寄存器集) M1 测试
;; ============================================================
;;
;; 覆盖:
;;   - 解析 .context 声明 (产出 'context directive)
;;   - 替换 pass: 字段引用 -> 物理寄存器, w/x 视图保持, directive 被剥离
;;   - 未声明字段不替换 (保持本地虚拟)
;;   - 结构等价: .context 版指令流 == 手写物理寄存器版 (字节等价的结构证明)
;;   - 校验: 字段跨上下文冲突 / 字段别名 / 未声明上下文 / 手写物理寄存器冲突
;;
;; 见 docs/context-register-sets-design.md (里程碑 M1)。

(require rackunit
         rackunit/text-ui
         "../parser/frontend.rkt"
         "../parser/ast.rkt"
         "../semantic/apply-contexts.rkt"
         (only-in "../semantic/control-flow.rkt" build-cfg cfg-get-function)
         (only-in "../pipeline/pipeline.rkt"
                  check-no-undefined-gpr-virtuals declared-param-reg-symbols))

;; 解析 GNU 源到扁平 item 列表
(define (parse-items src)
  (define results (parse-string src #:source "context-test" #:syntax 'gnu))
  (when (parse-results-has-errors? results)
    (error 'parse-items "解析错误:\n~a" (format-parse-errors-report results)))
  (for/list ([r (in-list (parse-results-items results))]
             #:when (parse-result-ok? r))
    (parse-result-instruction r)))

(define (apply-src src)
  (apply-contexts (parse-items src)))

;; 应用 .context 替换后构建 CFG, 取首个函数 (供完整性关卡测试)
(define (ctx-fn-from src)
  (define-values (out _errs) (apply-src src))
  (cfg-get-function (build-cfg out 'ctx-check-test) 0))

;; 施用完整性关卡(param-syms 由声明形参算得; 这些简单函数无 .inline 故 post-inline==此形态)
(define (check-fn fn)
  (check-no-undefined-gpr-virtuals fn (declared-param-reg-symbols fn)))

(define (all-ins items) (filter ast-ins? items))

(define (find-ins items mnem)
  (for/first ([it (in-list items)]
              #:when (and (ast-ins? it) (eq? (ast-ins-mnemonic it) mnem)))
    it))

(define (context-directive? it)
  (and (ast-directive? it) (eq? (ast-directive-kind it) 'context)))

;; 把一条指令归一成 (mnemonic suffix (operand-desc ...))，
;; 寄存器归一成 (reg kind id)，用于结构等价比较 (忽略 srcloc)。
(define (operand-desc op)
  (match op
    [(ast-reg kind id gs idx el pm _) (list 'reg kind id gs idx el pm)]
    [(ast-imm v _) (list 'imm v)]
    [(ast-cond c _) (list 'cond c)]
    [(ast-label n r _) (list 'label n r)]
    [(ast-mem base off im sh ex _)
     (list 'mem (operand-desc base)
           (and off (operand-desc off)) im
           (and sh (list 'shift)) (and ex (list 'extend)))]
    [(ast-reglist regs _) (list 'reglist (map operand-desc regs))]
    [_ (list 'other)]))

(define (ins-signature ins)
  (list (ast-ins-mnemonic ins)
        (ast-ins-suffix ins)
        (map operand-desc (ast-ins-operands ins))))

(define (ins-stream items) (map ins-signature (all-ins items)))

;; ------------------------------------------------------------

(define-test-suite context-tests

  (test-case "解析 .context 产出 'context directive"
    (define items (parse-items ".context p256 a0=x4 acc0=x14\n"))
    (define ctx (findf context-directive? items))
    (check-true (and ctx #t) "应出现一个 'context directive")
    (check-equal? (ast-directive-name ctx) 'p256)
    ;; args = (list scope field-map-assoc); scope 默认 library
    (check-equal? (first (ast-directive-args ctx)) 'library "默认 scope 为 library")
    (define fields (second (ast-directive-args ctx)))
    (check-equal? (length fields) 2)
    (define a0 (assq 'a0 fields))
    (check-equal? (ast-reg-kind (cdr a0)) 'x)
    (check-equal? (ast-reg-id (cdr a0)) 4))

  (test-case "替换正确 + directive 剥离 + 未声明字段保持虚拟"
    (define-values (out errs)
      (apply-src (string-append
                  ".context c a0=x4 a1=x5 acc0=x14\n"
                  ".function f (context c) export\n"
                  "entry:\n"
                  "  mul x.acc0, x.a0, x.bi\n"
                  "  ret\n"
                  ".end\n")))
    (check-equal? errs '() "无校验错误")
    (check-false (findf context-directive? out) "'context directive 应被剥离")
    (define mul (find-ins out 'mul))
    (match-define (list d s1 s2) (ast-ins-operands mul))
    ;; x.acc0 -> x14, x.a0 -> x4
    (check-equal? (list (ast-reg-kind d) (ast-reg-id d)) '(x 14))
    (check-equal? (list (ast-reg-kind s1) (ast-reg-id s1)) '(x 4))
    ;; x.bi 未声明 -> 保持虚拟 (id 为符号)
    (check-equal? (ast-reg-id s2) 'bi "未声明字段不替换"))

  (test-case "w/x 视图保持 (w.acc0 且 acc0=x14 -> w14)"
    (define-values (out errs)
      (apply-src (string-append
                  ".context c a0=x4 acc0=x14\n"
                  ".function g (context c) export\n"
                  "entry:\n"
                  "  mov w.acc0, w.a0\n"
                  "  ret\n"
                  ".end\n")))
    (check-equal? errs '())
    (define mov (find-ins out 'mov))
    (match-define (list d s) (ast-ins-operands mov))
    (check-equal? (list (ast-reg-kind d) (ast-reg-id d)) '(w 14) "w 视图 + 物理编号 14")
    (check-equal? (list (ast-reg-kind s) (ast-reg-id s)) '(w 4)))

  (test-case "结构等价: .context 版指令流 == 手写物理寄存器版"
    (define hand
      (parse-items (string-append
                    ".function k export ()\n"
                    "entry:\n"
                    "  adds x14, x4, x5\n"
                    "  adcs x15, x5, x6\n"
                    "  subs x4, x14, x8\n"
                    "  csel x14, x14, x4, cc\n"
                    "  ret\n"
                    ".end\n")))
    (define-values (ctx-out _errs)
      (apply-src (string-append
                  ".context c a0=x4 a1=x5 a2=x6 b0=x8 acc0=x14 acc1=x15\n"
                  ".function k (context c) export\n"
                  "entry:\n"
                  "  adds x.acc0, x.a0, x.a1\n"
                  "  adcs x.acc1, x.a1, x.a2\n"
                  "  subs x.a0, x.acc0, x.b0\n"
                  "  csel x.acc0, x.acc0, x.a0, cc\n"
                  "  ret\n"
                  ".end\n")))
    (check-equal? (ins-stream ctx-out) (ins-stream hand)
                  "替换后指令流应与手写物理寄存器版逐条相同"))

  (test-case "字段跨上下文冲突 -> 报错"
    (define-values (_out errs)
      (apply-src (string-append
                  ".context c1 shared=x4\n"
                  ".context c2 shared=x5\n"
                  ".function h (context c1 c2) export\n"
                  "entry:\n"
                  "  mov x.shared, x.shared\n"
                  "  ret\n"
                  ".end\n")))
    (check-true (pair? errs) "同字段映射不同寄存器应报错")
    (check-true (regexp-match? #rx"冲突" (car errs))))

  (test-case "字段别名 (同一上下文两字段同寄存器) -> 报错"
    (define-values (_out errs)
      (apply-src ".context bad a0=x4 b0=x4\n"))
    (check-true (pair? errs))
    (check-true (regexp-match? #rx"同一物理寄存器" (car errs))))

  (test-case "import 未声明上下文 -> 报错"
    (define-values (_out errs)
      (apply-src (string-append
                  ".function m (context nope) export\n"
                  "entry:\n"
                  "  ret\n"
                  ".end\n")))
    (check-true (pair? errs))
    (check-true (regexp-match? #rx"未声明的上下文" (car errs))))

  (test-case "手写物理寄存器与上下文字段占用冲突 -> 报错"
    (define-values (_out errs)
      (apply-src (string-append
                  ".context c a0=x4 acc0=x14\n"
                  ".function n (context c) export\n"
                  "entry:\n"
                  "  mov x4, x.acc0\n"     ; x4 手写, 与 a0=x4 冲突
                  "  ret\n"
                  ".end\n")))
    (check-true (pair? errs))
    (check-true (regexp-match? #rx"手写物理寄存器" (car errs))))

  (test-case "无上下文的函数不受影响"
    (define-values (out errs)
      (apply-src (string-append
                  ".function p export ()\n"
                  "entry:\n"
                  "  mov x.foo, x.bar\n"    ; 普通虚拟寄存器, 不替换
                  "  ret\n"
                  ".end\n")))
    (check-equal? errs '())
    (define mov (find-ins out 'mov))
    (match-define (list d s) (ast-ins-operands mov))
    (check-equal? (ast-reg-id d) 'foo)
    (check-equal? (ast-reg-id s) 'bar))

  ;; ---- L1 (库层级) 作用域 ----
  (test-case "解析 (scope library) 显式声明"
    (define ctx (findf context-directive?
                       (parse-items ".context c (scope library) s0=x19\n")))
    (check-equal? (first (ast-directive-args ctx)) 'library))

  (test-case "L1: callee-saved 上下文字段 + .save all → 无错"
    (define-values (out errs)
      (apply-src (string-append
                  ".context c (scope library) s0=x19 acc0=x14\n"
                  ".function f (context c) export\n"
                  "entry:\n"
                  "  .save all\n"
                  "  mov x.s0, x0\n"
                  "  add x.acc0, x.s0, x1\n"
                  "  .restore all\n"
                  "  ret\n"
                  ".end\n")))
    (check-equal? errs '() "有 .save all 覆盖, 不应报错"))

  (test-case "L1: callee-saved 上下文字段无 .save all → 报错(核心安全属性)"
    (define-values (out errs)
      (apply-src (string-append
                  ".context c (scope library) s0=x19 acc0=x14\n"
                  ".function f (context c) export\n"
                  "entry:\n"
                  "  mov x.s0, x0\n"           ; 用 x19 却不保存
                  "  add x.acc0, x.s0, x1\n"
                  "  ret\n"
                  ".end\n")))
    (check-equal? (length errs) 1 "应报一个未保存错误")
    (check-true (regexp-match? #rx"callee-saved" (car errs)))
    (check-true (regexp-match? #rx"s0" (car errs)))
    (check-true (regexp-match? #rx"x19" (car errs))))

  (test-case "L1: 显式 .save x19 也算覆盖 → 无错"
    (define-values (out errs)
      (apply-src (string-append
                  ".context c (scope library) s0=x19 acc0=x14\n"
                  ".function f (context c) export\n"
                  "entry:\n"
                  "  .save x19\n"
                  "  mov x.s0, x0\n"
                  "  add x.acc0, x.s0, x1\n"
                  "  .load x19\n"
                  "  ret\n"
                  ".end\n")))
    (check-equal? errs '() "显式 .save x19 覆盖, 不应报错"))

  (test-case "L1: 纯 caller-saved 上下文字段 (x14) 不触发保存校验"
    (define-values (out errs)
      (apply-src (string-append
                  ".context c (scope library) acc0=x14 acc1=x15\n"
                  ".function f (context c) export\n"
                  "entry:\n"
                  "  add x.acc0, x.acc1, x0\n"  ; x14/x15 是 caller-saved, 无需保存
                  "  ret\n"
                  ".end\n")))
    (check-equal? errs '() "caller-saved 字段不应触发 L1 校验"))

  ;; ---- .context 完整性关卡: 用而通篇无定义的 GPR 虚拟寄存器 ----
  (test-case "完整性: .context 函数用未声明且未定义的 GPR 虚拟 → 报错"
    ;; x.ptr 既非 context 字段、也从未被写入 → 无值来源(易漏 pin 的入参指针)。
    (define fn
      (ctx-fn-from (string-append
                    ".context c a0=x4 acc0=x14\n"
                    ".function f (context c) export\n"
                    "entry:\n"
                    "  ldr x.acc0, [x.ptr]\n"
                    "  ret\n"
                    ".end\n")))
    (check-exn #rx"通篇无定义" (lambda () (check-fn fn))))

  (test-case "完整性: 被写入的虚拟寄存器 → 不报错"
    (define fn
      (ctx-fn-from (string-append
                    ".context c a0=x4 acc0=x14\n"
                    ".function f (context c) export\n"
                    "entry:\n"
                    "  mov x.tmp, x.a0\n"
                    "  add x.acc0, x.tmp, x.a0\n"
                    "  ret\n"
                    ".end\n")))
    (check-not-exn (lambda () (check-fn fn))))

  (test-case "完整性: w-定义 / x-使用 同名视图 → 不误报"
    ;; AArch64 w 写清零 x 高 32 位 → w.tmp 定义了完整 x.tmp。
    (define fn
      (ctx-fn-from (string-append
                    ".context c a0=x4 acc0=x14\n"
                    ".function f (context c) export\n"
                    "entry:\n"
                    "  mov w.tmp, w.a0\n"
                    "  add x.acc0, x.tmp, x.a0\n"
                    "  ret\n"
                    ".end\n")))
    (check-not-exn (lambda () (check-fn fn))))

  (test-case "完整性(通用): 非 .context 函数同样受检 → 报错"
    ;; 关卡是通用的(post-inline 施于所有函数), 不再按 .context 收窄作用域。
    (define fn
      (ctx-fn-from (string-append
                    ".function f export\n"
                    "entry:\n"
                    "  ldr x0, [x.ptr]\n"
                    "  ret\n"
                    ".end\n")))
    (check-exn #rx"通篇无定义" (lambda () (check-fn fn))))

  (test-case "完整性: 声明形参(in:/out:)合法无定义 → 不报错"
    ;; in: x.arg 由 ABI 传入(无 body 定义), 须排除。
    (define fn
      (ctx-fn-from (string-append
                    ".function f export (in: x.arg)\n"
                    "entry:\n"
                    "  ldr x0, [x.arg]\n"
                    "  ret\n"
                    ".end\n")))
    (check-not-exn (lambda () (check-fn fn)))))

(module+ main
  (exit (run-tests context-tests)))

(module+ test
  (require rackunit/text-ui)
  (run-tests context-tests))
