#lang racket

;; ============================================================
;; test/abi-test.rkt - ABI 系统测试
;; ============================================================

(require rackunit
         rackunit/text-ui
         "../pipeline/regalloc/abi.rkt"
         "../pipeline/regalloc/abi-config.rkt"
         racket/intbits)

;; 初始化配置文件路径
;; 首先尝试当前目录，如果失败则尝试相对于测试文件的路径
(define (find-config-path)
  (define candidates
    (list
      (build-path (current-directory) "config/abi.rktd")
      (build-path (current-directory) ".." "config/abi.rktd")))
  (for/first ([p (in-list candidates)]
              #:when (file-exists? p))
    p))

(define config-path (find-config-path))
(when config-path
  (abi-config-path config-path)
  (void (reload-abi-config)))

;; ============================================================
;; 测试 reg-class-config 扩展
;; ============================================================

(define-test-suite reg-class-config-tests
  ;; 测试默认参数
  (test-case "make-reg-class-config with defaults"
    (define cfg (make-reg-class-config #:num-regs 16))
    (check-equal? (reg-class-config-num-regs cfg) 16)
    (check-equal? (reg-arg-regs cfg) '())
    (check-equal? (reg-return-regs cfg) '()))

  ;; 测试带 arg-regs 和 return-regs
  (test-case "make-reg-class-config with arg/return regs"
    (define cfg (make-reg-class-config
                  #:num-regs 32
                  #:arg-regs '(0 1 2 3 4 5 6 7)
                  #:return-regs '(0 1)))
    (check-equal? (reg-arg-regs cfg) '(0 1 2 3 4 5 6 7))
    (check-equal? (reg-return-regs cfg) '(0 1)))

  ;; 测试 is-arg-reg? 和 is-return-reg?
  (test-case "reg-is-arg-reg? and reg-is-return-reg?"
    (define cfg (make-reg-class-config
                  #:num-regs 16
                  #:arg-regs '(0 1 2)
                  #:return-regs '(0)))
    (check-true (reg-is-arg-reg? cfg 0))
    (check-true (reg-is-arg-reg? cfg 2))
    (check-false (reg-is-arg-reg? cfg 3))
    (check-true (reg-is-return-reg? cfg 0))
    (check-false (reg-is-return-reg? cfg 1))))

;; ============================================================
;; 测试 arm64-abi 预定义配置
;; ============================================================

(define-test-suite arm64-abi-tests
  ;; GPR 测试
  (test-case "arm64-abi GPR config"
    (check-equal? (abi-get-arg-regs arm64-abi 'gpr) '(0 1 2 3 4 5 6 7))
    (check-equal? (abi-get-return-regs arm64-abi 'gpr) '(0))
    (check-true (abi-is-arg-reg? arm64-abi 'gpr 0))
    (check-false (abi-is-arg-reg? arm64-abi 'gpr 8))
    (check-true (abi-is-return-reg? arm64-abi 'gpr 0))
    (check-false (abi-is-return-reg? arm64-abi 'gpr 1)))

  ;; FPR 测试
  (test-case "arm64-abi FPR config"
    (check-equal? (abi-get-arg-regs arm64-abi 'fpr) '(0 1 2 3 4 5 6 7))
    (check-equal? (abi-get-return-regs arm64-abi 'fpr) '(0 1))
    (check-true (abi-is-arg-reg? arm64-abi 'fpr 0))
    (check-true (abi-is-return-reg? arm64-abi 'fpr 1))
    (check-false (abi-is-return-reg? arm64-abi 'fpr 2)))

  ;; Predicate 测试
  (test-case "arm64-abi predicate config"
    (check-equal? (abi-get-arg-regs arm64-abi 'predicate) '(0 1 2 3))
    (check-equal? (abi-get-return-regs arm64-abi 'predicate) '(0 1 2 3))
    (check-true (abi-is-arg-reg? arm64-abi 'predicate 0))
    (check-true (abi-is-return-reg? arm64-abi 'predicate 3))
    (check-false (abi-is-arg-reg? arm64-abi 'predicate 4))))

;; ============================================================
;; 测试配置文件加载
;; ============================================================

(define-test-suite config-loading-tests
  ;; 测试 aapcs64 加载
  (test-case "load aapcs64 from config"
    (define aapcs64 (get-abi-by-name 'aapcs64))
    (check-not-false aapcs64)
    (when aapcs64
      (check-equal? (abi-get-arg-regs aapcs64 'gpr) '(0 1 2 3 4 5 6 7))
      (check-equal? (abi-get-return-regs aapcs64 'gpr) '(0))
      (check-equal? (abi-get-arg-regs aapcs64 'fpr) '(0 1 2 3 4 5 6 7))
      (check-equal? (abi-get-return-regs aapcs64 'fpr) '(0 1))))

  ;; 测试继承 (leaf extends aapcs64)
  (test-case "leaf inherits from aapcs64"
    (define leaf (get-abi-by-name 'leaf))
    (check-not-false leaf)
    (when leaf
      ;; arg-regs 应该继承自 aapcs64
      (check-equal? (abi-get-arg-regs leaf 'gpr) '(0 1 2 3 4 5 6 7))
      (check-equal? (abi-get-return-regs leaf 'gpr) '(0))))

  ;; 测试 naked
  (test-case "naked ABI"
    (define naked (get-abi-by-name 'naked))
    (check-not-false naked)
    (when naked
      (check-equal? (abi-get-arg-regs naked 'gpr) '(0 1 2 3 4 5 6 7))
      (check-equal? (abi-get-return-regs naked 'gpr) '(0))
      ;; naked 没有 preserved，但 x16/x17 仍保留给 rewrite-time scratch。
      (check-equal? (reg-num-allocatable (abi-config-gpr naked)) 29))))

;; ============================================================
;; 测试特殊寄存器
;; ============================================================

(define-test-suite special-regs-tests
  (test-case "abi-get-special-regs"
    (check-equal? (abi-get-special-reg arm64-abi 'sp) 31)
    (check-equal? (abi-get-special-reg arm64-abi 'fp) 29)
    (check-equal? (abi-get-special-reg arm64-abi 'lr) 30)
    (check-equal? (abi-get-special-reg arm64-abi 'platform) 18)
    (check-false (abi-get-special-reg arm64-abi 'nonexistent #f))))

;; ============================================================
;; 测试 ABI 不变量（数学约束）
;; ============================================================

(define-test-suite invariant-tests
  (test-case "arm64-abi 满足不变量"
    (check-true (abi-well-formed? arm64-abi))
    (check-equal? (abi-invariant-errors arm64-abi) '()))

  (test-case "banned 与 preserved 交叉时报错"
    (define bad
      (make-reg-class-config
       #:num-regs 8
       #:banned (intbits 1)
       #:preserved (intbits 1)))
    (define errs (reg-class-invariant-errors 'gpr bad))
    (check-true (pair? errs))
    (check-true
     (for/or ([e (in-list errs)])
       (regexp-match? #rx"交叉" e))))

  (test-case "参数寄存器不允许越界或 banned"
    (define bad
      (make-reg-class-config
       #:num-regs 8
       #:banned (intbits 3)
       #:arg-regs '(3 9)))
    (define errs (reg-class-invariant-errors 'gpr bad))
    (check-true (pair? errs))
    (check-true
     (for/or ([e (in-list errs)])
       (regexp-match? #rx"args" e)))))

;; ============================================================
;; ABI 偏序与格测试
;; ============================================================

(define-test-suite lattice-tests
  (test-case "命名 ABI 的偏序: aapcs64 ⊑ leaf ⊑ naked"
    (define aapcs64 (get-abi-by-name 'aapcs64))
    (define leaf (get-abi-by-name 'leaf))
    (define naked (get-abi-by-name 'naked))
    (check-not-false aapcs64)
    (check-not-false leaf)
    (check-not-false naked)
    (check-true (abi<=? aapcs64 leaf))
    (check-true (abi<=? leaf naked))
    (check-true (abi<=? aapcs64 naked))
    (check-false (abi<=? naked aapcs64)))

  (test-case "meet/join 满足格律（交换律、幂等律、吸收式）"
    (define a (abi->effect arm64-abi))
    (define b (abi->effect (abi-scratch-only arm64-abi)))
    (define meet-ab (abi-effect-meet a b))
    (define join-ab (abi-effect-join a b))
    ;; 交换律
    (check-equal? meet-ab (abi-effect-meet b a))
    (check-equal? join-ab (abi-effect-join b a))
    ;; 幂等律
    (check-equal? a (abi-effect-meet a a))
    (check-equal? a (abi-effect-join a a))
    ;; 吸收律: a ∧ (a ∨ b) = a, a ∨ (a ∧ b) = a
    (check-equal? a (abi-effect-meet a (abi-effect-join a b)))
    (check-equal? a (abi-effect-join a (abi-effect-meet a b))))

  (test-case "extends 违反格约束应报错"
    (define tmp (make-temporary-file "abi-bad-~a.rktd"))
    (call-with-output-file tmp
      (lambda (out)
        (displayln "(parent" out)
        (displayln "  (gpr (num-regs 8) (banned #x0) (preserved #x0))" out)
        (displayln "  (fpr (num-regs 8) (banned #x0) (preserved #x0))" out)
        (displayln "  (pred (num-regs 8) (banned #x0) (preserved #x0)))" out)
        (displayln "" out)
        (displayln "(child" out)
        (displayln "  (extends parent)" out)
        ;; child 缩小了 scratch（把 x0 变成 preserved），违反 parent ⊑ child
        (displayln "  (gpr (num-regs 8) (banned #x0) (preserved #x1))" out)
        (displayln "  (fpr (num-regs 8) (banned #x0) (preserved #x0))" out)
        (displayln "  (pred (num-regs 8) (banned #x0) (preserved #x0)))" out))
      #:exists 'truncate/replace)

    (parameterize ([abi-config-path tmp])
      (check-exn #rx"ABI 格约束"
                 (lambda ()
                   (reload-abi-config))))
    (delete-file tmp)))

;; ============================================================
;; 不变量边界情况测试
;; ============================================================

(define-test-suite invariant-edge-case-tests
  (test-case "num-regs 为负数时报错"
    (define bad (make-reg-class-config #:num-regs -1))
    (define errs (reg-class-invariant-errors 'gpr bad))
    (check-true (pair? errs))
    (check-true (for/or ([e (in-list errs)])
                  (regexp-match? #rx"num-regs" e))))

  (test-case "num-regs 超过 4096 时报错"
    (define bad (make-reg-class-config #:num-regs 5000))
    (define errs (reg-class-invariant-errors 'gpr bad))
    (check-true (pair? errs))
    (check-true (for/or ([e (in-list errs)])
                  (regexp-match? #rx"num-regs" e))))

  (test-case "arg-regs 包含越界值时报错"
    (define bad (make-reg-class-config
                  #:num-regs 8
                  #:arg-regs '(0 1 9)))  ; 9 >= num-regs
    (define errs (reg-class-invariant-errors 'gpr bad))
    (check-true (pair? errs))
    (check-true (for/or ([e (in-list errs)])
                  (regexp-match? #rx"args.*越界" e))))

  (test-case "return-regs 包含越界值时报错"
    (define bad (make-reg-class-config
                  #:num-regs 8
                  #:return-regs '(0 10)))  ; 10 >= num-regs
    (define errs (reg-class-invariant-errors 'gpr bad))
    (check-true (pair? errs))
    (check-true (for/or ([e (in-list errs)])
                  (regexp-match? #rx"return.*越界" e))))

  (test-case "空 arg-regs/return-regs 合法"
    (define cfg (make-reg-class-config
                  #:num-regs 16
                  #:arg-regs '()
                  #:return-regs '()))
    (define errs (reg-class-invariant-errors 'gpr cfg))
    (check-equal? errs '()))

  (test-case "arg-regs 包含重复时报错"
    (define bad (make-reg-class-config
                  #:num-regs 16
                  #:arg-regs '(0 1 0 2)))
    (define errs (reg-class-invariant-errors 'gpr bad))
    (check-true (pair? errs))
    (check-true (for/or ([e (in-list errs)])
                  (regexp-match? #rx"args.*重复" e))))

  (test-case "return-regs 包含 banned 寄存器时报错"
    (define bad (make-reg-class-config
                  #:num-regs 16
                  #:banned (intbits 3)
                  #:return-regs '(0 1 2 3)))
    (define errs (reg-class-invariant-errors 'gpr bad))
    (check-true (pair? errs))
    (check-true (for/or ([e (in-list errs)])
                  (regexp-match? #rx"return.*banned" e)))))

;; ============================================================
;; 格性质测试
;; ============================================================

(define-test-suite lattice-property-tests
  ;; 自反性: a <= a
  (test-case "abi-effect<=? 自反性"
    (define a (abi->effect arm64-abi))
    (check-true (abi-effect<=? a a)))

  ;; 反对称性: a <= b && b <= a => a = b
  (test-case "abi-effect<=? 反对称性"
    (define a (abi->effect arm64-abi))
    (define b (abi->effect arm64-abi))
    (check-true (and (abi-effect<=? a b)
                     (abi-effect<=? b a)
                     (equal? a b))))

  ;; 传递性: a <= b && b <= c => a <= c
  (test-case "abi-effect<=? 传递性"
    (define aapcs64 (get-abi-by-name 'aapcs64))
    (define leaf (get-abi-by-name 'leaf))
    (define naked (get-abi-by-name 'naked))
    (when (and aapcs64 leaf naked)
      (define a (abi->effect aapcs64))
      (define b (abi->effect leaf))
      (define c (abi->effect naked))
      (check-true (abi-effect<=? a b))
      (check-true (abi-effect<=? b c))
      (check-true (abi-effect<=? a c))))

  ;; 幂等性: a meet a = a, a join a = a
  (test-case "abi-effect-meet 幂等性"
    (define a (abi->effect arm64-abi))
    (check-equal? (abi-effect-meet a a) a))

  (test-case "abi-effect-join 幂等性"
    (define a (abi->effect arm64-abi))
    (check-equal? (abi-effect-join a a) a))

  ;; 交换律: a meet b = b meet a, a join b = b join a
  (test-case "meet/join 交换律"
    (define a (abi->effect arm64-abi))
    (define b (abi->effect (abi-scratch-only arm64-abi)))
    (check-equal? (abi-effect-meet a b) (abi-effect-meet b a))
    (check-equal? (abi-effect-join a b) (abi-effect-join b a)))

  ;; 结合律: (a meet b) meet c = a meet (b meet c)
  (test-case "meet/join 结合律"
    (define a (abi->effect arm64-abi))
    (define b (abi->effect (abi-scratch-only arm64-abi)))
    (define c (abi-effect
                (intbits 0 1 2)
                (intbits 0 1)
                intbits-empty))
    (check-equal? (abi-effect-meet (abi-effect-meet a b) c)
                  (abi-effect-meet a (abi-effect-meet b c)))
    (check-equal? (abi-effect-join (abi-effect-join a b) c)
                  (abi-effect-join a (abi-effect-join b c))))

  ;; 吸收律: a meet (a join b) = a, a join (a meet b) = a
  (test-case "吸收律"
    (define a (abi->effect arm64-abi))
    (define b (abi->effect (abi-scratch-only arm64-abi)))
    (check-equal? (abi-effect-meet a (abi-effect-join a b)) a)
    (check-equal? (abi-effect-join a (abi-effect-meet a b)) a)))

;; ============================================================
;; 颜色映射测试
;; ============================================================

(define-test-suite color-map-tests
  (test-case "abi-reg->color 正确性"
    ;; x0 (reg 0) 应该映射到某个颜色
    (define color (abi-reg->color arm64-abi 'gpr 0))
    (check-not-false color)
    ;; 验证反向映射
    (when color
      (check-equal? (abi-color->reg arm64-abi 'gpr color) 0)))

  (test-case "abi-color->reg 边界检查 - 越界颜色"
    ;; 使用一个大数值颜色，应该返回 #f
    (check-false (abi-color->reg arm64-abi 'gpr 1000))
    (check-false (abi-color->reg arm64-abi 'gpr -1)))

  (test-case "abi-reg->color banned 寄存器返回 #f"
    ;; x16/x17 是 rewrite-time scratch，x18 是平台保留寄存器。
    (check-false (abi-reg->color arm64-abi 'gpr 16))
    (check-false (abi-reg->color arm64-abi 'gpr 17))
    (check-false (abi-reg->color arm64-abi 'gpr 18)))

  (test-case "abi-reg->color 越界寄存器返回 #f"
    (check-false (abi-reg->color arm64-abi 'gpr 100)))

  (test-case "abi-color->reg 与 abi-reg->color 互逆"
    ;; 对于可分配寄存器，color->reg 和 reg->color 互为逆操作
    (define allocatable-regs '(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 19 20))
    (for ([reg (in-list allocatable-regs)])
      (define color (abi-reg->color arm64-abi 'gpr reg))
      (when color
        (check-equal? (abi-color->reg arm64-abi 'gpr color) reg))))

  (test-case "FPR 颜色映射正确"
    ;; v0-v31 都是可分配的
    (define color (abi-reg->color arm64-abi 'fpr 0))
    (check-not-false color)
    (when color
      (check-equal? (abi-color->reg arm64-abi 'fpr color) 0)))

  (test-case "Predicate 颜色映射正确"
    ;; p0-p15 都是可分配的
    (define color (abi-reg->color arm64-abi 'predicate 0))
    (check-not-false color)
    (when color
      (check-equal? (abi-color->reg arm64-abi 'predicate color) 0))))

;; ============================================================
;; 运行所有测试
;; ============================================================

(module+ test
  (run-tests reg-class-config-tests)
  (run-tests arm64-abi-tests)
  (run-tests config-loading-tests)
  (run-tests special-regs-tests)
  (run-tests invariant-tests)
  (run-tests lattice-tests)
  (run-tests invariant-edge-case-tests)
  (run-tests lattice-property-tests)
  (run-tests color-map-tests))
