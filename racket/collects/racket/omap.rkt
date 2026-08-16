#lang racket/base

;; racket/omap — 宏单态化有序映射模板 (2026-08-07 由 rktasm ds/omap.rkt 吸收进 core)
;;
;; 协议: 三值比较器为根 (#:key-compare 主形式), #:key<? 谓词只作构造糖
;; (见 crypto/ASM-ENHANCEMENT-PLAN.md comparator 协议规范增订)。
;;
;; (define-omap name #:key<? lt-expr) 在展开点生成一整套单态操作:
;;   name-empty (常量)  name-empty?  name?  name-count
;;   name-set  name-ref  name-has-key?  name-delete  name-min
;;   name->pairs (升序 kv 对列表)  in-name (升序遍历序列)
;;
;; 性能原理: 比较器 lt-expr 在展开期进入每个递归体, 成为实例内的已知
;; 小函数 → cp0 常规内联 β 归约吃掉 → 生成码与手写单态版相同, 无
;; ordered-map 式"struct 字段存闭包 + 每节点未知调用"的动态分派税。
;; 递归不构成常量传播障碍: 每个实例是独立的递归克隆。
;;
;; 结构: 加权平衡树 (Adams 风格 WBT, delta=3/ratio=2, 单旋/双旋)。
;; 迭代序 = key<? 升序, 与内部结构无关 → 换实现不影响任何依赖遍历序
;; 的输出 (.S 字节稳定的前提)。
;; 键相等即 (and (not (lt a b)) (not (lt b a))); 不需要单独的 =? 参数。

(require (for-syntax racket/base racket/syntax))

(provide define-omap)

(define-syntax (define-omap stx)
  (syntax-case stx ()
    ;; #:key<? 便利形式: 由严格小于谓词派生三值比较器
    [(_ name #:key<? lt-expr)
     #'(define-omap name #:key-compare
         (let ([lt lt-expr])
           (lambda (a b) (cond [(lt a b) '<] [(lt b a) '>] [else '=]))))]
    ;; #:key-compare 主形式: 三值比较器 ('</'='/'>), 每节点单次调用——
    ;; 多字段字典序/字符串键下降路径比 <? 双询问省一半比较
    [(_ name #:key-compare cmp-expr)
     (let ([fmt (lambda (f) (format-id #'name f #'name))])
       (with-syntax
           ([nd        (fmt "~a-node")]
            [nd?       (fmt "~a-node?")]
            [nd-k      (fmt "~a-node-k")]
            [nd-v      (fmt "~a-node-v")]
            [nd-l      (fmt "~a-node-l")]
            [nd-r      (fmt "~a-node-r")]
            [nd-sz     (fmt "~a-node-sz")]
            [%empty    (fmt "~a-empty")]
            [%empty?   (fmt "~a-empty?")]
            [%?        (fmt "~a?")]
            [%count    (fmt "~a-count")]
            [%set      (fmt "~a-set")]
            [%ref      (fmt "~a-ref")]
            [%has-key? (fmt "~a-has-key?")]
            [%delete   (fmt "~a-delete")]
            [%min      (fmt "~a-min")]
            [%->pairs  (fmt "~a->pairs")]
            [in-%      (format-id #'name "in-~a" #'name)])
         #'(begin
             (struct nd (k v l r sz) #:transparent)
             (define %empty #f)
             (define (%empty? t) (not t))
             (define (%? t) (or (not t) (nd? t)))
             (define (%count t) (if t (nd-sz t) 0))
             (define cmp cmp-expr)

             (define (mk k v l r)
               (nd k v l r (+ 1 (%count l) (%count r))))

             ;; Adams WBT: size(heavy) > delta*size(light) 时旋转;
             ;; 内旋孙较重 (> ratio*兄弟) 时双旋
             (define (bal k v l r)
               (define ls (%count l))
               (define rs (%count r))
               (cond
                 [(<= (+ ls rs) 1) (mk k v l r)]
                 [(> rs (* 3 ls))
                  (define rl (nd-l r))
                  (define rr (nd-r r))
                  (if (< (%count rl) (* 2 (%count rr)))
                      (mk (nd-k r) (nd-v r) (mk k v l rl) rr)      ; 单左旋
                      (mk (nd-k rl) (nd-v rl)                       ; 双旋
                          (mk k v l (nd-l rl))
                          (mk (nd-k r) (nd-v r) (nd-r rl) rr)))]
                 [(> ls (* 3 rs))
                  (define ll (nd-l l))
                  (define lr (nd-r l))
                  (if (< (%count lr) (* 2 (%count ll)))
                      (mk (nd-k l) (nd-v l) ll (mk k v lr r))      ; 单右旋
                      (mk (nd-k lr) (nd-v lr)                       ; 双旋
                          (mk (nd-k l) (nd-v l) ll (nd-l lr))
                          (mk k v (nd-r lr) r)))]
                 [else (mk k v l r)]))

             (define (%set t k v)
               (if (not t)
                   (mk k v #f #f)
                   (case (cmp k (nd-k t))
                     [(<) (bal (nd-k t) (nd-v t) (%set (nd-l t) k v) (nd-r t))]
                     [(>) (bal (nd-k t) (nd-v t) (nd-l t) (%set (nd-r t) k v))]
                     [else (mk k v (nd-l t) (nd-r t))])))

             (define none (gensym 'none))
             (define (%ref t k [default #f])
               (let loop ([t t])
                 (if (not t)
                     (if (procedure? default) (default) default)
                     (case (cmp k (nd-k t))
                       [(<) (loop (nd-l t))]
                       [(>) (loop (nd-r t))]
                       [else (nd-v t)]))))

             (define (%has-key? t k)
               (let loop ([t t])
                 (if (not t)
                     #f
                     (case (cmp k (nd-k t))
                       [(<) (loop (nd-l t))]
                       [(>) (loop (nd-r t))]
                       [else #t]))))

             ;; 删除: 用右子树最小节点顶替
             (define (split-min t)   ; → (values k v rest)
               (if (not (nd-l t))
                   (values (nd-k t) (nd-v t) (nd-r t))
                   (let-values ([(k v rest) (split-min (nd-l t))])
                     (values k v (bal (nd-k t) (nd-v t) rest (nd-r t))))))

             (define (%delete t k)
               (cond
                 [(not t) #f]
                 [else
                  (case (cmp k (nd-k t))
                    [(<) (bal (nd-k t) (nd-v t) (%delete (nd-l t) k) (nd-r t))]
                    [(>) (bal (nd-k t) (nd-v t) (nd-l t) (%delete (nd-r t) k))]
                    [else
                     (cond
                       [(not (nd-l t)) (nd-r t)]
                       [(not (nd-r t)) (nd-l t)]
                       [else
                        (let-values ([(k2 v2 rest) (split-min (nd-r t))])
                          (bal k2 v2 (nd-l t) rest))])])]))

             (define (%min t)
               (cond
                 [(not t) #f]
                 [(not (nd-l t)) (cons (nd-k t) (nd-v t))]
                 [else (%min (nd-l t))]))

             (define (%->pairs t)
               (let loop ([t t] [acc '()])
                 (if (not t)
                     acc
                     (loop (nd-l t)
                           (cons (cons (nd-k t) (nd-v t))
                                 (loop (nd-r t) acc))))))

             (define (in-% t) (in-list (%->pairs t))))))]))
