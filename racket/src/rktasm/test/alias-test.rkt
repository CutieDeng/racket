#lang racket

(require rackunit
         rackunit/text-ui
         "../syntax/alias.rkt")

;; ============================================================
;; syntax/alias.rkt 单元测试
;; ============================================================

(define alias-tests
  (test-suite
   "Alias 单元测试"

   ;; --------------------------------------------------------
   ;; alias? 查询
   ;; --------------------------------------------------------
   (test-suite
    "alias?"

    (test-case "核心别名"
      (check-true (alias? 'mov))
      (check-true (alias? 'cmp))
      (check-true (alias? 'cmn))
      (check-true (alias? 'tst))
      (check-true (alias? 'mvn))
      (check-true (alias? 'neg))
      (check-true (alias? 'negs)))

    (test-case "移位别名"
      (check-true (alias? 'lsl))
      (check-true (alias? 'lsr))
      (check-true (alias? 'asr))
      (check-true (alias? 'ror)))

    (test-case "符号扩展别名"
      (check-true (alias? 'sxtb))
      (check-true (alias? 'sxth))
      (check-true (alias? 'sxtw))
      (check-true (alias? 'uxtb))
      (check-true (alias? 'uxth)))

    (test-case "乘法别名"
      (check-true (alias? 'mul))
      (check-true (alias? 'mneg))
      (check-true (alias? 'smull))
      (check-true (alias? 'umull)))

    (test-case "条件选择别名"
      (check-true (alias? 'cinc))
      (check-true (alias? 'cinv))
      (check-true (alias? 'cneg))
      (check-true (alias? 'cset))
      (check-true (alias? 'csetm)))

    (test-case "非别名指令"
      (check-false (alias? 'add))
      (check-false (alias? 'sub))
      (check-false (alias? 'orr))
      (check-false (alias? 'nop))
      (check-false (alias? 'ret))
      (check-false (alias? 'foobar))))

   ;; --------------------------------------------------------
   ;; get-alias-targets
   ;; --------------------------------------------------------
   (test-suite
    "get-alias-targets"

    (test-case "mov 目标包含 orr/movz/movn"
      (define targets (get-alias-targets 'mov))
      (check-not-false (member 'orr targets) "mov 应包含 orr")
      (check-not-false (member 'movz targets) "mov 应包含 movz")
      (check-not-false (member 'movn targets) "mov 应包含 movn"))

    (test-case "cmp 目标包含 subs"
      (define targets (get-alias-targets 'cmp))
      (check-not-false (member 'subs targets) "cmp 应包含 subs"))

    (test-case "cmn 目标包含 adds"
      (define targets (get-alias-targets 'cmn))
      (check-not-false (member 'adds targets) "cmn 应包含 adds"))

    (test-case "tst 目标包含 ands"
      (define targets (get-alias-targets 'tst))
      (check-not-false (member 'ands targets) "tst 应包含 ands"))

    (test-case "mvn 目标包含 orn"
      (define targets (get-alias-targets 'mvn))
      (check-not-false (member 'orn targets) "mvn 应包含 orn"))

    (test-case "neg 目标包含 sub"
      (define targets (get-alias-targets 'neg))
      (check-not-false (member 'sub targets) "neg 应包含 sub"))

    (test-case "mul 目标包含 madd"
      (define targets (get-alias-targets 'mul))
      (check-not-false (member 'madd targets) "mul 应包含 madd"))

    (test-case "不存在的别名返回空"
      (check-equal? (get-alias-targets 'nonexistent) '())))

   ;; --------------------------------------------------------
   ;; expand-alias: MOV
   ;; --------------------------------------------------------
   (test-suite
    "expand-alias: MOV"

    (test-case "mov Xd, Xm → orr Xd, xzr, Xm, lsl, 0"
      (define result (expand-alias 'mov '(x0 x1)))
      (check-not-false result)
      (check-equal? (length result) 1)
      (define expanded (car result))
      (check-equal? (car expanded) 'orr)
      (check-equal? (second expanded) 'x0)
      (check-equal? (third expanded) 'xzr)
      (check-equal? (fourth expanded) 'x1))

    (test-case "mov Wd, Wm → orr Wd, wzr, Wm, lsl, 0"
      (define result (expand-alias 'mov '(w0 w1)))
      (check-not-false result)
      (define expanded (car result))
      (check-equal? (third expanded) 'wzr "32-bit 应用 wzr"))

    (test-case "mov Xd, #imm → movz 和 movn"
      (define result (expand-alias 'mov '(x0 42)))
      (check-not-false result)
      (check-equal? (length result) 2)
      (check-equal? (car (first result)) 'movz)
      (check-equal? (car (second result)) 'movn))

    (test-case "mov 非法组合返回 #f"
      (check-false (expand-alias 'mov '(x0)))))

   ;; --------------------------------------------------------
   ;; expand-alias: CMP
   ;; --------------------------------------------------------
   (test-suite
    "expand-alias: CMP"

    (test-case "cmp Xn, Xm → subs xzr, Xn, Xm, lsl, 0"
      (define result (expand-alias 'cmp '(x0 x1)))
      (check-not-false result)
      (check-equal? (length result) 1)
      (define expanded (car result))
      (check-equal? (car expanded) 'subs)
      (check-equal? (second expanded) 'xzr)
      (check-equal? (third expanded) 'x0)
      (check-equal? (fourth expanded) 'x1))

    (test-case "cmp Wn, Wm → subs wzr, Wn, Wm"
      (define result (expand-alias 'cmp '(w0 w1)))
      (check-not-false result)
      (define expanded (car result))
      (check-equal? (second expanded) 'wzr))

    (test-case "cmp Xn, #imm → subs xzr, Xn, #imm"
      (define result (expand-alias 'cmp '(x0 42)))
      (check-not-false result)
      (define expanded (car result))
      (check-equal? (car expanded) 'subs)
      (check-equal? (second expanded) 'xzr)))

   ;; --------------------------------------------------------
   ;; expand-alias: CMN
   ;; --------------------------------------------------------
   (test-suite
    "expand-alias: CMN"

    (test-case "cmn Xn, Xm → adds xzr, Xn, Xm"
      (define result (expand-alias 'cmn '(x0 x1)))
      (check-not-false result)
      (define expanded (car result))
      (check-equal? (car expanded) 'adds)
      (check-equal? (second expanded) 'xzr))

    (test-case "cmn Xn, #imm → adds xzr, Xn, #imm"
      (define result (expand-alias 'cmn '(x5 100)))
      (check-not-false result)
      (define expanded (car result))
      (check-equal? (car expanded) 'adds)))

   ;; --------------------------------------------------------
   ;; expand-alias: TST
   ;; --------------------------------------------------------
   (test-suite
    "expand-alias: TST"

    (test-case "tst Xn, Xm → ands xzr, Xn, Xm"
      (define result (expand-alias 'tst '(x0 x1)))
      (check-not-false result)
      (define expanded (car result))
      (check-equal? (car expanded) 'ands)
      (check-equal? (second expanded) 'xzr))

    (test-case "tst Xn, #imm → ands xzr, Xn, #imm"
      (define result (expand-alias 'tst '(x0 255)))
      (check-not-false result)
      (define expanded (car result))
      (check-equal? (car expanded) 'ands)))

   ;; --------------------------------------------------------
   ;; expand-alias: MVN, NEG, NEGS, NGC, NGCS
   ;; --------------------------------------------------------
   (test-suite
    "expand-alias: 其他别名"

    (test-case "mvn Xd, Xm → orn Xd, xzr, Xm"
      (define result (expand-alias 'mvn '(x0 x1)))
      (check-not-false result)
      (define expanded (car result))
      (check-equal? (car expanded) 'orn)
      (check-equal? (third expanded) 'xzr))

    (test-case "neg Xd, Xm → sub Xd, xzr, Xm"
      (define result (expand-alias 'neg '(x0 x1)))
      (check-not-false result)
      (define expanded (car result))
      (check-equal? (car expanded) 'sub)
      (check-equal? (third expanded) 'xzr))

    (test-case "negs Xd, Xm → subs Xd, xzr, Xm"
      (define result (expand-alias 'negs '(x0 x1)))
      (check-not-false result)
      (define expanded (car result))
      (check-equal? (car expanded) 'subs)
      (check-equal? (third expanded) 'xzr))

    (test-case "ngc Xd, Xm → sbc Xd, xzr, Xm"
      (define result (expand-alias 'ngc '(x0 x1)))
      (check-not-false result)
      (define expanded (car result))
      (check-equal? (car expanded) 'sbc)
      (check-equal? (third expanded) 'xzr))

    (test-case "ngcs Xd, Xm → sbcs Xd, xzr, Xm"
      (define result (expand-alias 'ngcs '(x0 x1)))
      (check-not-false result)
      (define expanded (car result))
      (check-equal? (car expanded) 'sbcs)
      (check-equal? (third expanded) 'xzr))

    (test-case "未知别名返回 #f"
      (check-false (expand-alias 'add '(x0 x1 x2)))
      (check-false (expand-alias 'unknowninstr '(x0 x1)))))

   ;; --------------------------------------------------------
   ;; expand-alias: 带 shift 的变体
   ;; --------------------------------------------------------
   (test-suite
    "expand-alias: 带 shift"

    (test-case "cmp Xn, Xm, shift → subs xzr, Xn, Xm, shift"
      (define result (expand-alias 'cmp '(x0 x1 lsl 3)))
      (check-not-false result)
      (define expanded (car result))
      (check-equal? (car expanded) 'subs)
      (check-equal? (second expanded) 'xzr)
      ;; 后续操作数保留
      (check-true (> (length expanded) 3)))

    (test-case "tst Xn, Xm, shift → ands xzr, Xn, Xm, shift"
      (define result (expand-alias 'tst '(x0 x1 lsl 3)))
      (check-not-false result)
      (define expanded (car result))
      (check-equal? (car expanded) 'ands)))

   ;; --------------------------------------------------------
   ;; get-alias-map
   ;; --------------------------------------------------------
   (test-suite
    "get-alias-map"

    (test-case "返回 hash"
      (define m (get-alias-map))
      (check-true (hash? m)))

    (test-case "包含核心别名"
      (define m (get-alias-map))
      (check-true (hash-has-key? m 'mov))
      (check-true (hash-has-key? m 'cmp))
      (check-true (hash-has-key? m 'tst))))))

;; ============================================================
;; 执行
;; ============================================================

(module+ main
  (void (run-tests alias-tests)))

(module+ test
  (void (run-tests alias-tests)))
