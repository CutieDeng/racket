#lang racket/base

;; racket/compare — 三值比较协议 (2026-08-07, 依 comparator 协议规范立项;
;; 见 racket/src/crypto/ASM-ENHANCEMENT-PLAN.md 增订)
;;
;; 结果域 '< '= '>。规范要点:
;;  - 新有序结构 API 以三值比较器为根 (racket/omap #:key-compare 已示范),
;;    <? 谓词只作派生糖; 存量 sort/<? 面不改造。
;;  - 叶子比较器**单遍**出三值: 对代价在数据遍历里的键 (string/bytes/
;;    多字段字典序), 比 <? 双探针省一半比较。
;;  - 比较链保持可融合表达式形态, 不过早物化为布尔 (为未来后端
;;    cmp+ccmp 融合保留空间; 该 ISel 项已评估搁置, 见规范③)。
;;  - 叶子与派生器包在 begin-encourage-inline 中, 配合已知站点的
;;    cross-linklet 内联降低接口成本。

(require racket/fixnum
         racket/performance-hint)

(provide comparison?
         fx-compare integer-compare real-compare
         char-compare string-compare symbol-compare bytes-compare
         compare-on compare-reverse compare-lexico
         compare->lt compare->eq lt->compare)

(define (comparison? v)
  (and (memq v '(< = >)) #t))

(begin-encourage-inline

  (define (fx-compare a b)
    (cond [(fx< a b) '<] [(fx> a b) '>] [else '=]))

  (define (integer-compare a b)
    (cond [(< a b) '<] [(> a b) '>] [else '=]))

  (define (real-compare a b)
    (cond [(< a b) '<] [(> a b) '>] [else '=]))

  (define (char-compare a b)
    (cond [(char<? a b) '<] [(char>? a b) '>] [else '=]))

  ;; 单遍字典序: 首个不等字符定方向, 前缀关系由长度定
  (define (string-compare a b)
    (define la (string-length a))
    (define lb (string-length b))
    (define n (fxmin la lb))
    (let loop ([i 0])
      (if (fx= i n)
          (cond [(fx< la lb) '<] [(fx> la lb) '>] [else '=])
          (let ([ca (string-ref a i)] [cb (string-ref b i)])
            (cond [(char<? ca cb) '<]
                  [(char>? ca cb) '>]
                  [else (loop (fx+ i 1))])))))

  ;; interned symbol 快路径: eq? 即 '=
  (define (symbol-compare a b)
    (if (eq? a b)
        '=
        (string-compare (symbol->string a) (symbol->string b))))

  (define (bytes-compare a b)
    (define la (bytes-length a))
    (define lb (bytes-length b))
    (define n (fxmin la lb))
    (let loop ([i 0])
      (if (fx= i n)
          (cond [(fx< la lb) '<] [(fx> la lb) '>] [else '=])
          (let ([ba (bytes-ref a i)] [bb (bytes-ref b i)])
            (cond [(fx< ba bb) '<]
                  [(fx> ba bb) '>]
                  [else (loop (fx+ i 1))])))))

  ;; 派生糖
  (define ((compare->lt cmp) a b) (eq? '< (cmp a b)))
  (define ((compare->eq cmp) a b) (eq? '= (cmp a b)))
  (define ((lt->compare lt) a b)
    (cond [(lt a b) '<] [(lt b a) '>] [else '=]))

  ;; 组合子
  (define ((compare-on key cmp) a b)
    (cmp (key a) (key b)))

  (define ((compare-reverse cmp) a b)
    (case (cmp a b) [(<) '>] [(>) '<] [else '=]))

  ;; 字典序链: 逐比较器求值, 首个非 '= 定方向
  (define (compare-lexico . cmps)
    (lambda (a b)
      (let loop ([cs cmps])
        (if (null? cs)
            '=
            (let ([r ((car cs) a b)])
              (if (eq? r '=) (loop (cdr cs)) r)))))))
