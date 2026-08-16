#lang racket

;; ============================================================
;; test/reg-compare-parity-test.rkt — reg<? / reg-id-compare 对拍
;; ============================================================
;;
;; reg<? (racket/omap reg-om 实例的严格小于谓词) 必须与三态比较器
;; reg-id-compare 的 '< 分支逐位一致:
;;   (eq? (reg-id-compare a b) '<)  ⟺  (reg<? a b)
;; 同时校验 '=' ⟺ (and (not (reg<? a b)) (not (reg<? b a)))。
;; 1e5 随机对 + 定向边界对 (数值 id vs 符号 id、物理 vs 虚拟、各 class)。

(require "../pipeline/regalloc/types.rkt")

(define classes '(gpr fpr predicate other))

(define (random-id)
  (if (zero? (random 2))
      (random 64)
      (string->symbol (format "v~a" (random 40)))))

(define (random-reg)
  (define class (list-ref classes (random (length classes))))
  (reg-id class (canonical-width class) (random-id) (zero? (random 2))))

(define (check-pair a b)
  (define cmp (reg-id-compare a b))
  (define lt (reg<? a b))
  (define gt (reg<? b a))
  (unless (eq? (eq? cmp '<) lt)
    (error 'reg-compare-parity
           "reg<? 与 reg-id-compare '< 分支不一致: ~v ~v cmp=~a reg<?=~a"
           a b cmp lt))
  (unless (eq? (eq? cmp '=) (and (not lt) (not gt)))
    (error 'reg-compare-parity
           "相等语义不一致: ~v ~v cmp=~a lt=~a gt=~a" a b cmp lt gt))
  (unless (eq? (eq? cmp '>) gt)
    (error 'reg-compare-parity
           "reg<? 反向与 reg-id-compare '> 分支不一致: ~v ~v" a b)))

;; 定向边界对
(define directed
  (list (make-gpr 0) (make-gpr 31) (make-fpr 0) (make-fpr 31)
        (make-virtual-gpr 'a) (make-virtual-gpr 'b) (make-virtual-gpr 'a)
        (make-virtual-fpr 'a)
        (reg-id 'predicate 16 0 #f) (reg-id 'predicate 16 'p #t)
        (reg-id 'other 64 3 #f)
        ;; 数值 id vs 符号 id 混合 (同 class 同 virtual?)
        (reg-id 'gpr 64 5 #t) (reg-id 'gpr 64 'v5 #t)))
(for* ([a (in-list directed)] [b (in-list directed)])
  (check-pair a b))

;; 1e5 随机对拍
(random-seed 20260806)
(for ([_ (in-range 100000)])
  (check-pair (random-reg) (random-reg)))

;; 自反: a 与自身
(for ([_ (in-range 1000)])
  (define a (random-reg))
  (check-pair a a))

(displayln "reg-compare-parity-test: all checks passed")
