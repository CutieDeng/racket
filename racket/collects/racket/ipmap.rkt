#lang racket/base

;; racket/ipmap — 大端 Patricia trie 整数→值 映射, hash-consing, 节点即 ipmap (无 wrapper)
;;
;; racket/intset 的映射版 (键 exact-nonnegative-integer, 值任意)。与 racket/intmap
;; (BST) 共存: 提供 O(n+m) 结构化合并 + hash-consing 跨树去重。每节点缓存含值
;; equal-hash-code 的 Merkle hash, 经弱内插表构造, 结构相等 (键相等 ∧ 值 equal?)
;; 复用同一对象。canonical + 内插 ⟹ 相同 键→值 映射恒为同一节点对象 ⟹ Patricia
;; 节点自身即公开 ipmap: eq? ⟺ 相同映射 (零额外表), equal? = eq?, hasheq/hash 皆
;; O(1) 可作 memo 键。
;;
;; 编译器价值: 常量传播 / 类型推断 = 变量→格值 映射, 每 CFG 结点做格 join
;; (union-with ⊔) / meet (intersect-with ⊓) 迭代到不动点; 映射作 O(1) memo 键。
;; 选型边界同 racket/intset: 稀疏/大键空间 + 映射作 memo 键时用 ipmap; 稠密小键的
;; 逐元素更新用 racket/intmap(BST) 或数组更快 (实测: 稠密不动点 intbits 快 24~55x,
;; 但映射作 hasheq memo 键 hash-cons O(1) 快 equal-hash 22~38x)。
;;
;; eq? 子树短路正确性边界: difference / 左偏 union / 左偏 intersect 有效; 带值
;; union-with / intersect-with 不做子树短路 (f 未必幂等, 同 GHC)。
;; 内插值用 equal? 比较。单线程假设 (内插表全局可变态)。

(require "private/patricia-bits.rkt" racket/swisstable
) ; end require

(provide ipmap ipmap? ipmap-empty ipmap-empty?
         ipmap-ref ipmap-has-key?
         ipmap-set ipmap-set/absent ipmap-remove ipmap-update
         ipmap-count
         ipmap-union ipmap-union-with ipmap-union*
         ipmap-intersect ipmap-intersect-with
         ipmap-difference
         ipmap-map-values ipmap-filter
         ipmap-min-entry ipmap-max-entry
         ipmap-keys ipmap-values ipmap->list list->ipmap
         in-ipmap in-ipmap-keys in-ipmap-values
         for/ipmap for*/ipmap
         ipmap-foldr ipmap-intern-count
) ; end provide

;; ---- Merkle hash ----
(define HMASK #x3FFFFFFF
) ; end define
(define (mix h x
        ) ; end mix
        (bitwise-and (+ (* h 31
                        ) ; end *
                        x
                     ) ; end +
                     HMASK
        ) ; end bitwise-and
) ; end define
(define (tip-hash k v
        ) ; end tip-hash
        (mix (mix (mix 17 1
                  ) ; end mix
                  (bitwise-and k HMASK
                  ) ; end bitwise-and
             ) ; end mix
                            (bitwise-and (equal-hash-code v
                                         ) ; end equal-hash-code
                                         HMASK
                            ) ; end bitwise-and
        ) ; end mix
) ; end define
(define (bin-hash p m lh rh
        ) ; end bin-hash
  (mix (mix (mix (mix (mix 17 2
                      ) ; end mix
                      (bitwise-and p HMASK
                      ) ; end bitwise-and
                 ) ; end mix
                 (bitwise-and m HMASK
                 ) ; end bitwise-and
            ) ; end mix
            lh
       ) ; end mix
       rh
  ) ; end mix
) ; end define

;; ---- 节点 = 公开 ipmap 类型 ----
(define (node-write m port mode
        ) ; end node-write
        (fprintf port "#<ipmap:~a>" (ipmap->list m
                                    ) ; end ipmap->list
        ) ; end fprintf
) ; end define
(define (node-hash1 m _
        ) ; end node-hash1
        (node-hash m
        ) ; end node-hash
) ; end define

(struct mt-nil ()               #:property prop:custom-write node-write
) ; end struct
(struct mt-tip (key val hash
               ) ; end key
        #:property prop:equal+hash (list (lambda (a b _
                                                 ) ; end a
                                                 (eq? a b
                                                 ) ; end eq?
                                         ) ; end lambda
                                         node-hash1 node-hash1
                                   ) ; end list
                                #:property prop:custom-write node-write
) ; end struct
(struct mt-bin (prefix mask left right hash
               ) ; end prefix
                                #:property prop:equal+hash (list (lambda (a b _
                                                                         ) ; end a
                                                                         (eq? a b
                                                                         ) ; end eq?
                                                                 ) ; end lambda
                                                                 node-hash1 node-hash1
                                                           ) ; end list
                                #:property prop:custom-write node-write
) ; end struct

(define the-nil (mt-nil
                ) ; end mt-nil
) ; end define
(define ipmap-empty the-nil
) ; end define
(define (ipmap? x
        ) ; end ipmap?
        (or (mt-nil? x
            ) ; end mt-nil?
            (mt-tip? x
            ) ; end mt-tip?
            (mt-bin? x
            ) ; end mt-bin?
        ) ; end or
) ; end define
(define (node-hash t
        ) ; end node-hash
  (cond [(mt-bin? t
         ) ; end mt-bin?
          (mt-bin-hash t
          ) ; end mt-bin-hash
        ] ; end
        [(mt-tip? t
         ) ; end mt-tip?
          (mt-tip-hash t
          ) ; end mt-tip-hash
        ] ; end
        [else 0
        ] ; end else
  ) ; end cond
) ; end define

;; ---- 弱内插表 ----
;; core swisstable 可用则用它 (eqv fixnum 键), 否则退回内建 hasheqv (同 pvector 哲学)
(define-values (intern-table intern-ref intern-set! intern-for-each
               ) ; end intern-table
  (if (swisstable-runtime-adapter-core-available?
      ) ; end swisstable-runtime-adapter-core-available?
      (values (make-swisstable-eqv
              ) ; end make-swisstable-eqv
              swisstable-ref swisstable-set! swisstable-for-each
      ) ; end values
      (values (make-hasheqv
              ) ; end make-hasheqv
              hash-ref hash-set! hash-for-each
      ) ; end values
  ) ; end if
) ; end define-values
(define (prune bs
        ) ; end prune
        (filter weak-box-value bs
        ) ; end filter
) ; end define
(define (intern h match? make
        ) ; end intern
  (define bucket (intern-ref intern-table h '()
                 ) ; end intern-ref
  ) ; end define
  (let loop ([bs bucket
             ] ; end bs
            ) ; end
    (if (null? bs
        ) ; end null?
        (let ([node (make
                    ) ; end make
              ] ; end node
             ) ; end
          (intern-set! intern-table h (cons (make-weak-box node
                                            ) ; end make-weak-box
                                            (prune bucket
                                            ) ; end prune
                                      ) ; end cons
          ) ; end intern-set!
          node
        ) ; end let
        (let ([n (weak-box-value (car bs
                                 ) ; end car
                 ) ; end weak-box-value
              ] ; end n
             ) ; end
          (if (and n (match? n
                     ) ; end match?
              ) ; end and
              n (loop (cdr bs
                      ) ; end cdr
                ) ; end loop
          ) ; end if
        ) ; end let
    ) ; end if
  ) ; end let
) ; end define

(define (mk-tip k v
        ) ; end mk-tip
  (define h (tip-hash k v
            ) ; end tip-hash
  ) ; end define
  (intern h
          (lambda (n
                  ) ; end n
                  (and (mt-tip? n
                       ) ; end mt-tip?
                       (= (mt-tip-key n
                          ) ; end mt-tip-key
                          k
                       ) ; end =
                       (equal? (mt-tip-val n
                               ) ; end mt-tip-val
                               v
                       ) ; end equal?
                  ) ; end and
          ) ; end lambda
          (lambda () (mt-tip k v h
                     ) ; end mt-tip
          ) ; end lambda
  ) ; end intern
) ; end define

(define (mk-bin p m l r
        ) ; end mk-bin
  (define h (bin-hash p m (node-hash l
                          ) ; end node-hash
                      (node-hash r
                      ) ; end node-hash
            ) ; end bin-hash
  ) ; end define
  (intern h
          (lambda (n
                  ) ; end n
                  (and (mt-bin? n
                       ) ; end mt-bin?
                       (= (mt-bin-prefix n
                          ) ; end mt-bin-prefix
                          p
                       ) ; end =
                       (= (mt-bin-mask n
                          ) ; end mt-bin-mask
                          m
                       ) ; end =
                           (eq? (mt-bin-left n
                                ) ; end mt-bin-left
                                l
                           ) ; end eq?
                       (eq? (mt-bin-right n
                            ) ; end mt-bin-right
                            r
                       ) ; end eq?
                  ) ; end and
          ) ; end lambda
          (lambda () (mt-bin p m l r h
                     ) ; end mt-bin
          ) ; end lambda
  ) ; end intern
) ; end define

(define (ipmap-intern-count
        ) ; end ipmap-intern-count
  (define n 0
  ) ; end define
  (intern-for-each intern-table (lambda (h bs
                                        ) ; end h
                                        (set! n (+ n (length (prune bs
                                                             ) ; end prune
                                                     ) ; end length
                                                ) ; end +
                                        ) ; end set!
                                ) ; end lambda
  ) ; end intern-for-each
  n
) ; end define

;; ---- 树级 = ipmap 级 ----
(define none (gensym 'none
             ) ; end gensym
) ; end define

(define (join p1 t1 p2 t2
        ) ; end join
  (define m (branch-mask p1 p2
            ) ; end branch-mask
  ) ; end define
  (if (zero-bit? p1 m
      ) ; end zero-bit?
      (mk-bin (mask-of p1 m
              ) ; end mask-of
              m t1 t2
      ) ; end mk-bin
      (mk-bin (mask-of p1 m
              ) ; end mask-of
              m t2 t1
      ) ; end mk-bin
  ) ; end if
) ; end define

(define (bin* p m l r
        ) ; end bin*
  (cond [(mt-nil? l
         ) ; end mt-nil?
          r
        ] ; end r
        [(mt-nil? r
         ) ; end mt-nil?
          l
        ] ; end l
        [else (mk-bin p m l r
              ) ; end mk-bin
        ] ; end else
  ) ; end cond
) ; end define

(define (tree-ref t k default
        ) ; end tree-ref
  (let loop ([t t
             ] ; end t
            ) ; end
    (cond
      [(mt-bin? t
       ) ; end mt-bin?
       (if (match-prefix? k (mt-bin-prefix t
                            ) ; end mt-bin-prefix
                          (mt-bin-mask t
                          ) ; end mt-bin-mask
           ) ; end match-prefix?
           (loop (if (zero-bit? k (mt-bin-mask t
                                  ) ; end mt-bin-mask
                     ) ; end zero-bit?
                     (mt-bin-left t
                     ) ; end mt-bin-left
                     (mt-bin-right t
                     ) ; end mt-bin-right
                 ) ; end if
           ) ; end loop
           default
       ) ; end if
      ] ; end
      [(mt-tip? t
       ) ; end mt-tip?
        (if (= (mt-tip-key t
               ) ; end mt-tip-key
               k
            ) ; end =
            (mt-tip-val t
            ) ; end mt-tip-val
            default
        ) ; end if
      ] ; end
      [else default
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (tree-insert-with combine t k v
        ) ; end tree-insert-with
  (let ins ([t t
            ] ; end t
           ) ; end
    (cond
      [(mt-bin? t
       ) ; end mt-bin?
       (define p (mt-bin-prefix t
                 ) ; end mt-bin-prefix
       ) ; end define
        (define m (mt-bin-mask t
                  ) ; end mt-bin-mask
        ) ; end define
       (cond
         [(not (match-prefix? k p m
               ) ; end match-prefix?
          ) ; end not
           (join k (mk-tip k v
                   ) ; end mk-tip
                 p t
           ) ; end join
         ] ; end
         [(zero-bit? k m
          ) ; end zero-bit?
          (define l (mt-bin-left t
                    ) ; end mt-bin-left
          ) ; end define
           (define l* (ins l
                      ) ; end ins
           ) ; end define
          (if (eq? l l*
              ) ; end eq?
              t (mk-bin p m l* (mt-bin-right t
                               ) ; end mt-bin-right
                ) ; end mk-bin
          ) ; end if
         ] ; end
         [else
          (define r (mt-bin-right t
                    ) ; end mt-bin-right
          ) ; end define
          (define r* (ins r
                     ) ; end ins
          ) ; end define
          (if (eq? r r*
              ) ; end eq?
              t (mk-bin p m (mt-bin-left t
                            ) ; end mt-bin-left
                        r*
                ) ; end mk-bin
          ) ; end if
         ] ; end else
       ) ; end cond
      ] ; end
      [(mt-tip? t
       ) ; end mt-tip?
       (define tk (mt-tip-key t
                  ) ; end mt-tip-key
       ) ; end define
       (cond
         [(not (= tk k
               ) ; end =
          ) ; end not
           (join k (mk-tip k v
                   ) ; end mk-tip
                 tk t
           ) ; end join
         ] ; end
         [combine
          (define nv (combine v (mt-tip-val t
                                ) ; end mt-tip-val
                     ) ; end combine
          ) ; end define
          (if (equal? nv (mt-tip-val t
                         ) ; end mt-tip-val
              ) ; end equal?
              t (mk-tip k nv
                ) ; end mk-tip
          ) ; end if
         ] ; end combine
         [else (mk-tip k v
               ) ; end mk-tip
         ] ; end else
       ) ; end cond
      ] ; end
      [else (mk-tip k v
            ) ; end mk-tip
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (tree-remove t k
        ) ; end tree-remove
  (let del ([t t
            ] ; end t
           ) ; end
    (cond
      [(mt-bin? t
       ) ; end mt-bin?
       (define p (mt-bin-prefix t
                 ) ; end mt-bin-prefix
       ) ; end define
        (define m (mt-bin-mask t
                  ) ; end mt-bin-mask
        ) ; end define
       (cond
         [(not (match-prefix? k p m
               ) ; end match-prefix?
          ) ; end not
           t
         ] ; end t
         [(zero-bit? k m
          ) ; end zero-bit?
          (define l (mt-bin-left t
                    ) ; end mt-bin-left
          ) ; end define
           (define l* (del l
                      ) ; end del
           ) ; end define
          (if (eq? l l*
              ) ; end eq?
              t (bin* p m l* (mt-bin-right t
                             ) ; end mt-bin-right
                ) ; end bin*
          ) ; end if
         ] ; end
         [else
          (define r (mt-bin-right t
                    ) ; end mt-bin-right
          ) ; end define
          (define r* (del r
                     ) ; end del
          ) ; end define
          (if (eq? r r*
              ) ; end eq?
              t (bin* p m (mt-bin-left t
                          ) ; end mt-bin-left
                      r*
                ) ; end bin*
          ) ; end if
         ] ; end else
       ) ; end cond
      ] ; end
      [(mt-tip? t
       ) ; end mt-tip?
        (if (= (mt-tip-key t
               ) ; end mt-tip-key
               k
            ) ; end =
            the-nil t
        ) ; end if
      ] ; end
      [else t
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (tree-union s t
        ) ; end tree-union
  (cond
    [(eq? s t
     ) ; end eq?
      s
    ] ; end s
    [(mt-nil? s
     ) ; end mt-nil?
      t
    ] ; end t
    [(mt-nil? t
     ) ; end mt-nil?
      s
    ] ; end s
    [(mt-tip? s
     ) ; end mt-tip?
      (tree-insert-with (lambda (nv ov
                                ) ; end nv
                                nv
                        ) ; end lambda
                        t (mt-tip-key s
                          ) ; end mt-tip-key
                        (mt-tip-val s
                        ) ; end mt-tip-val
      ) ; end tree-insert-with
    ] ; end
    [(mt-tip? t
     ) ; end mt-tip?
      (tree-insert-with (lambda (nv ov
                                ) ; end nv
                                ov
                        ) ; end lambda
                        s (mt-tip-key t
                          ) ; end mt-tip-key
                        (mt-tip-val t
                        ) ; end mt-tip-val
      ) ; end tree-insert-with
    ] ; end
    [else (bin-merge tree-union s t
          ) ; end bin-merge
    ] ; end else
  ) ; end cond
) ; end define

(define (tree-union-with f s t
        ) ; end tree-union-with
  (cond
    [(mt-nil? s
     ) ; end mt-nil?
      t
    ] ; end t
    [(mt-nil? t
     ) ; end mt-nil?
      s
    ] ; end s
    [(mt-tip? s
     ) ; end mt-tip?
      (tree-insert-with (lambda (nv ov
                                ) ; end nv
                                (f nv ov
                                ) ; end f
                        ) ; end lambda
                        t (mt-tip-key s
                          ) ; end mt-tip-key
                        (mt-tip-val s
                        ) ; end mt-tip-val
      ) ; end tree-insert-with
    ] ; end
    [(mt-tip? t
     ) ; end mt-tip?
      (tree-insert-with (lambda (nv ov
                                ) ; end nv
                                (f ov nv
                                ) ; end f
                        ) ; end lambda
                        s (mt-tip-key t
                          ) ; end mt-tip-key
                        (mt-tip-val t
                        ) ; end mt-tip-val
      ) ; end tree-insert-with
    ] ; end
    [else (bin-merge (lambda (a b
                             ) ; end a
                             (tree-union-with f a b
                             ) ; end tree-union-with
                     ) ; end lambda
                     s t
          ) ; end bin-merge
    ] ; end else
  ) ; end cond
) ; end define

(define (bin-merge rec s t
        ) ; end bin-merge
  (define p1 (mt-bin-prefix s
             ) ; end mt-bin-prefix
  ) ; end define
        (define m1 (mt-bin-mask s
                   ) ; end mt-bin-mask
        ) ; end define
  (define l1 (mt-bin-left s
             ) ; end mt-bin-left
  ) ; end define
        (define r1 (mt-bin-right s
                   ) ; end mt-bin-right
        ) ; end define
  (define p2 (mt-bin-prefix t
             ) ; end mt-bin-prefix
  ) ; end define
        (define m2 (mt-bin-mask t
                   ) ; end mt-bin-mask
        ) ; end define
  (define l2 (mt-bin-left t
             ) ; end mt-bin-left
  ) ; end define
        (define r2 (mt-bin-right t
                   ) ; end mt-bin-right
        ) ; end define
  (cond
    [(and (= m1 m2
          ) ; end =
          (= p1 p2
          ) ; end =
     ) ; end and
      (mk-bin p1 m1 (rec l1 l2
                    ) ; end rec
              (rec r1 r2
              ) ; end rec
      ) ; end mk-bin
    ] ; end
    [(and (shorter? m1 m2
          ) ; end shorter?
          (match-prefix? p2 p1 m1
          ) ; end match-prefix?
     ) ; end and
     (if (zero-bit? p2 m1
         ) ; end zero-bit?
         (mk-bin p1 m1 (rec l1 t
                       ) ; end rec
                 r1
         ) ; end mk-bin
         (mk-bin p1 m1 l1 (rec r1 t
                          ) ; end rec
         ) ; end mk-bin
     ) ; end if
    ] ; end
    [(and (shorter? m2 m1
          ) ; end shorter?
          (match-prefix? p1 p2 m2
          ) ; end match-prefix?
     ) ; end and
     (if (zero-bit? p1 m2
         ) ; end zero-bit?
         (mk-bin p2 m2 (rec s l2
                       ) ; end rec
                 r2
         ) ; end mk-bin
         (mk-bin p2 m2 l2 (rec s r2
                          ) ; end rec
         ) ; end mk-bin
     ) ; end if
    ] ; end
    [else (join p1 s p2 t
          ) ; end join
    ] ; end else
  ) ; end cond
) ; end define

(define (tree-intersect-with f s t
        ) ; end tree-intersect-with
  (cond
    [(or (mt-nil? s
         ) ; end mt-nil?
         (mt-nil? t
         ) ; end mt-nil?
     ) ; end or
      the-nil
    ] ; end the-nil
    [(mt-tip? s
     ) ; end mt-tip?
     (define v (tree-ref t (mt-tip-key s
                           ) ; end mt-tip-key
                         none
               ) ; end tree-ref
     ) ; end define
     (if (eq? v none
         ) ; end eq?
         the-nil (mk-tip (mt-tip-key s
                         ) ; end mt-tip-key
                         (f (mt-tip-val s
                            ) ; end mt-tip-val
                            v
                         ) ; end f
                 ) ; end mk-tip
     ) ; end if
    ] ; end
    [(mt-tip? t
     ) ; end mt-tip?
     (define v (tree-ref s (mt-tip-key t
                           ) ; end mt-tip-key
                         none
               ) ; end tree-ref
     ) ; end define
     (if (eq? v none
         ) ; end eq?
         the-nil (mk-tip (mt-tip-key t
                         ) ; end mt-tip-key
                         (f v (mt-tip-val t
                              ) ; end mt-tip-val
                         ) ; end f
                 ) ; end mk-tip
     ) ; end if
    ] ; end
    [else
     (define p1 (mt-bin-prefix s
                ) ; end mt-bin-prefix
     ) ; end define
     (define m1 (mt-bin-mask s
                ) ; end mt-bin-mask
     ) ; end define
     (define l1 (mt-bin-left s
                ) ; end mt-bin-left
     ) ; end define
     (define r1 (mt-bin-right s
                ) ; end mt-bin-right
     ) ; end define
     (define p2 (mt-bin-prefix t
                ) ; end mt-bin-prefix
     ) ; end define
     (define m2 (mt-bin-mask t
                ) ; end mt-bin-mask
     ) ; end define
     (define l2 (mt-bin-left t
                ) ; end mt-bin-left
     ) ; end define
     (define r2 (mt-bin-right t
                ) ; end mt-bin-right
     ) ; end define
     (cond
       [(and (= m1 m2
             ) ; end =
             (= p1 p2
             ) ; end =
        ) ; end and
         (bin* p1 m1 (tree-intersect-with f l1 l2
                     ) ; end tree-intersect-with
               (tree-intersect-with f r1 r2
               ) ; end tree-intersect-with
         ) ; end bin*
       ] ; end
       [(and (shorter? m1 m2
             ) ; end shorter?
             (match-prefix? p2 p1 m1
             ) ; end match-prefix?
        ) ; end and
         (tree-intersect-with f (if (zero-bit? p2 m1
                                    ) ; end zero-bit?
                                    l1 r1
                                ) ; end if
                              t
         ) ; end tree-intersect-with
       ] ; end
       [(and (shorter? m2 m1
             ) ; end shorter?
             (match-prefix? p1 p2 m2
             ) ; end match-prefix?
        ) ; end and
         (tree-intersect-with f s (if (zero-bit? p1 m2
                                      ) ; end zero-bit?
                                      l2 r2
                                  ) ; end if
         ) ; end tree-intersect-with
       ] ; end
       [else the-nil
       ] ; end else
     ) ; end cond
    ] ; end else
  ) ; end cond
) ; end define

(define (tree-intersect s t
        ) ; end tree-intersect
  (cond
    [(eq? s t
     ) ; end eq?
      s
    ] ; end s
    [(or (mt-nil? s
         ) ; end mt-nil?
         (mt-nil? t
         ) ; end mt-nil?
     ) ; end or
      the-nil
    ] ; end the-nil
    [else (tree-intersect-with (lambda (a b
                                       ) ; end a
                                       a
                               ) ; end lambda
                               s t
          ) ; end tree-intersect-with
    ] ; end else
  ) ; end cond
) ; end define

(define (tree-difference s t
        ) ; end tree-difference
  (cond
    [(eq? s t
     ) ; end eq?
      the-nil
    ] ; end the-nil
    [(mt-nil? s
     ) ; end mt-nil?
      the-nil
    ] ; end the-nil
    [(mt-nil? t
     ) ; end mt-nil?
      s
    ] ; end s
    [(mt-tip? s
     ) ; end mt-tip?
      (if (eq? (tree-ref t (mt-tip-key s
                           ) ; end mt-tip-key
                         none
               ) ; end tree-ref
               none
          ) ; end eq?
          s the-nil
      ) ; end if
    ] ; end
    [(mt-tip? t
     ) ; end mt-tip?
      (tree-remove s (mt-tip-key t
                     ) ; end mt-tip-key
      ) ; end tree-remove
    ] ; end
    [else
     (define p1 (mt-bin-prefix s
                ) ; end mt-bin-prefix
     ) ; end define
     (define m1 (mt-bin-mask s
                ) ; end mt-bin-mask
     ) ; end define
     (define l1 (mt-bin-left s
                ) ; end mt-bin-left
     ) ; end define
     (define r1 (mt-bin-right s
                ) ; end mt-bin-right
     ) ; end define
     (define p2 (mt-bin-prefix t
                ) ; end mt-bin-prefix
     ) ; end define
     (define m2 (mt-bin-mask t
                ) ; end mt-bin-mask
     ) ; end define
     (define l2 (mt-bin-left t
                ) ; end mt-bin-left
     ) ; end define
     (define r2 (mt-bin-right t
                ) ; end mt-bin-right
     ) ; end define
     (cond
       [(and (= m1 m2
             ) ; end =
             (= p1 p2
             ) ; end =
        ) ; end and
         (bin* p1 m1 (tree-difference l1 l2
                     ) ; end tree-difference
               (tree-difference r1 r2
               ) ; end tree-difference
         ) ; end bin*
       ] ; end
       [(and (shorter? m1 m2
             ) ; end shorter?
             (match-prefix? p2 p1 m1
             ) ; end match-prefix?
        ) ; end and
        (if (zero-bit? p2 m1
            ) ; end zero-bit?
            (bin* p1 m1 (tree-difference l1 t
                        ) ; end tree-difference
                  r1
            ) ; end bin*
            (bin* p1 m1 l1 (tree-difference r1 t
                           ) ; end tree-difference
            ) ; end bin*
        ) ; end if
       ] ; end
       [(and (shorter? m2 m1
             ) ; end shorter?
             (match-prefix? p1 p2 m2
             ) ; end match-prefix?
        ) ; end and
         (tree-difference s (if (zero-bit? p1 m2
                                ) ; end zero-bit?
                                l2 r2
                            ) ; end if
         ) ; end tree-difference
       ] ; end
       [else s
       ] ; end else
     ) ; end cond
    ] ; end else
  ) ; end cond
) ; end define

(define (tree-map-values f t
        ) ; end tree-map-values
  (let loop ([t t
             ] ; end t
            ) ; end
    (cond
      [(mt-bin? t
       ) ; end mt-bin?
        (mk-bin (mt-bin-prefix t
                ) ; end mt-bin-prefix
                (mt-bin-mask t
                ) ; end mt-bin-mask
                (loop (mt-bin-left t
                      ) ; end mt-bin-left
                ) ; end loop
                (loop (mt-bin-right t
                      ) ; end mt-bin-right
                ) ; end loop
        ) ; end mk-bin
      ] ; end
      [(mt-tip? t
       ) ; end mt-tip?
        (mk-tip (mt-tip-key t
                ) ; end mt-tip-key
                (f (mt-tip-key t
                   ) ; end mt-tip-key
                   (mt-tip-val t
                   ) ; end mt-tip-val
                ) ; end f
        ) ; end mk-tip
      ] ; end
      [else t
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (tree-filter pred t
        ) ; end tree-filter
  (let loop ([t t
             ] ; end t
            ) ; end
    (cond
      [(mt-bin? t
       ) ; end mt-bin?
        (bin* (mt-bin-prefix t
              ) ; end mt-bin-prefix
              (mt-bin-mask t
              ) ; end mt-bin-mask
              (loop (mt-bin-left t
                    ) ; end mt-bin-left
              ) ; end loop
              (loop (mt-bin-right t
                    ) ; end mt-bin-right
              ) ; end loop
        ) ; end bin*
      ] ; end
      [(mt-tip? t
       ) ; end mt-tip?
        (if (pred (mt-tip-key t
                  ) ; end mt-tip-key
                  (mt-tip-val t
                  ) ; end mt-tip-val
            ) ; end pred
            t the-nil
        ) ; end if
      ] ; end
      [else t
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (ipmap-count s
        ) ; end ipmap-count
  (let loop ([t s
             ] ; end t
              [acc 0
              ] ; end acc
            ) ; end
    (cond [(mt-bin? t
           ) ; end mt-bin?
            (loop (mt-bin-left t
                  ) ; end mt-bin-left
                  (loop (mt-bin-right t
                        ) ; end mt-bin-right
                        acc
                  ) ; end loop
            ) ; end loop
          ] ; end
          [(mt-tip? t
           ) ; end mt-tip?
            (add1 acc
            ) ; end add1
          ] ; end
          [else acc
          ] ; end else
    ) ; end cond
  ) ; end let
) ; end define
(define (ipmap-foldr s f init
        ) ; end ipmap-foldr
  (let loop ([t s
             ] ; end t
              [acc init
              ] ; end acc
            ) ; end
    (cond [(mt-bin? t
           ) ; end mt-bin?
            (loop (mt-bin-left t
                  ) ; end mt-bin-left
                  (loop (mt-bin-right t
                        ) ; end mt-bin-right
                        acc
                  ) ; end loop
            ) ; end loop
          ] ; end
          [(mt-tip? t
           ) ; end mt-tip?
            (f (mt-tip-key t
               ) ; end mt-tip-key
               (mt-tip-val t
               ) ; end mt-tip-val
               acc
            ) ; end f
          ] ; end
          [else acc
          ] ; end else
    ) ; end cond
  ) ; end let
) ; end define
(define (ipmap-min-entry s
        ) ; end ipmap-min-entry
  (let loop ([t s
             ] ; end t
            ) ; end
       (cond [(mt-bin? t
              ) ; end mt-bin?
               (loop (mt-bin-left t
                     ) ; end mt-bin-left
               ) ; end loop
             ] ; end
                          [(mt-tip? t
                           ) ; end mt-tip?
                            (cons (mt-tip-key t
                                  ) ; end mt-tip-key
                                  (mt-tip-val t
                                  ) ; end mt-tip-val
                            ) ; end cons
                          ] ; end
             [else #f
             ] ; end else
       ) ; end cond
  ) ; end let
) ; end define
(define (ipmap-max-entry s
        ) ; end ipmap-max-entry
  (let loop ([t s
             ] ; end t
            ) ; end
       (cond [(mt-bin? t
              ) ; end mt-bin?
               (loop (mt-bin-right t
                     ) ; end mt-bin-right
               ) ; end loop
             ] ; end
                          [(mt-tip? t
                           ) ; end mt-tip?
                            (cons (mt-tip-key t
                                  ) ; end mt-tip-key
                                  (mt-tip-val t
                                  ) ; end mt-tip-val
                            ) ; end cons
                          ] ; end
             [else #f
             ] ; end else
       ) ; end cond
  ) ; end let
) ; end define

;; ---- 公开 API (节点即 ipmap) ----
(define (check-key who k
        ) ; end check-key
  (unless (exact-nonnegative-integer? k
          ) ; end exact-nonnegative-integer?
          (raise-argument-error who "exact-nonnegative-integer?" k
          ) ; end raise-argument-error
  ) ; end unless
) ; end define

(define (ipmap-empty? m
        ) ; end ipmap-empty?
        (mt-nil? m
        ) ; end mt-nil?
) ; end define
(define (ipmap-ref m k [default (lambda () (error 'ipmap-ref "key not found: ~a" k
                                           ) ; end error
                                ) ; end lambda
                       ] ; end default
        ) ; end ipmap-ref
  (check-key 'ipmap-ref k
  ) ; end check-key
  (define v (tree-ref m k none
            ) ; end tree-ref
  ) ; end define
  (if (eq? v none
      ) ; end eq?
      (if (procedure? default
          ) ; end procedure?
          (default
          ) ; end default
          default
      ) ; end if
      v
  ) ; end if
) ; end define
(define (ipmap-has-key? m k
        ) ; end ipmap-has-key?
        (check-key 'ipmap-has-key? k
        ) ; end check-key
        (not (eq? (tree-ref m k none
                  ) ; end tree-ref
                  none
             ) ; end eq?
        ) ; end not
) ; end define
(define (ipmap-set m k v
        ) ; end ipmap-set
        (check-key 'ipmap-set k
        ) ; end check-key
        (tree-insert-with #f m k v
        ) ; end tree-insert-with
) ; end define
(define (ipmap-set/absent m k v
        ) ; end ipmap-set/absent
  (check-key 'ipmap-set/absent k
  ) ; end check-key
  (if (eq? (tree-ref m k none
           ) ; end tree-ref
           none
      ) ; end eq?
      (tree-insert-with #f m k v
      ) ; end tree-insert-with
      m
  ) ; end if
) ; end define
(define (ipmap-remove m k
        ) ; end ipmap-remove
        (check-key 'ipmap-remove k
        ) ; end check-key
        (tree-remove m k
        ) ; end tree-remove
) ; end define
(define (ipmap-update m k f [default (lambda () (error 'ipmap-update "key not found: ~a" k
                                                ) ; end error
                                     ) ; end lambda
                            ] ; end default
        ) ; end ipmap-update
  (check-key 'ipmap-update k
  ) ; end check-key
  (define cur (tree-ref m k none
              ) ; end tree-ref
  ) ; end define
  (define base (if (eq? cur none
                   ) ; end eq?
                   (if (procedure? default
                       ) ; end procedure?
                       (default
                       ) ; end default
                       default
                   ) ; end if
                   cur
               ) ; end if
  ) ; end define
  (tree-insert-with #f m k (f base
                           ) ; end f
  ) ; end tree-insert-with
) ; end define
(define (ipmap-union a b
        ) ; end ipmap-union
        (tree-union a b
        ) ; end tree-union
) ; end define
(define (ipmap-union-with f a b
        ) ; end ipmap-union-with
        (tree-union-with f a b
        ) ; end tree-union-with
) ; end define
(define (ipmap-intersect a b
        ) ; end ipmap-intersect
        (tree-intersect a b
        ) ; end tree-intersect
) ; end define
(define (ipmap-intersect-with f a b
        ) ; end ipmap-intersect-with
        (tree-intersect-with f a b
        ) ; end tree-intersect-with
) ; end define
(define (ipmap-difference a b
        ) ; end ipmap-difference
        (tree-difference a b
        ) ; end tree-difference
) ; end define
(define (ipmap-map-values f m
        ) ; end ipmap-map-values
        (tree-map-values f m
        ) ; end tree-map-values
) ; end define
(define (ipmap-filter pred m
        ) ; end ipmap-filter
        (tree-filter pred m
        ) ; end tree-filter
) ; end define
(define (ipmap-keys m
        ) ; end ipmap-keys
        (ipmap-foldr m (lambda (k v acc
                               ) ; end k
                               (cons k acc
                               ) ; end cons
                       ) ; end lambda
                     '()
        ) ; end ipmap-foldr
) ; end define
(define (ipmap-values m
        ) ; end ipmap-values
        (ipmap-foldr m (lambda (k v acc
                               ) ; end k
                               (cons v acc
                               ) ; end cons
                       ) ; end lambda
                     '()
        ) ; end ipmap-foldr
) ; end define
(define (ipmap->list m
        ) ; end ipmap->list
        (ipmap-foldr m (lambda (k v acc
                               ) ; end k
                               (cons (cons k v
                                     ) ; end cons
                                     acc
                               ) ; end cons
                       ) ; end lambda
                     '()
        ) ; end ipmap-foldr
) ; end define
(define (in-ipmap m
        ) ; end in-ipmap
  (make-do-sequence (lambda () (values (lambda (p
                                               ) ; end p
                                               (values (caar p
                                                       ) ; end caar
                                                       (cdar p
                                                       ) ; end cdar
                                               ) ; end values
                                       ) ; end lambda
                                       cdr (ipmap->list m
                                           ) ; end ipmap->list
                                       pair? #f #f
                               ) ; end values
                    ) ; end lambda
  ) ; end make-do-sequence
) ; end define
(define (in-ipmap-keys m
        ) ; end in-ipmap-keys
        (make-do-sequence (lambda () (values car cdr (ipmap-keys m
                                                     ) ; end ipmap-keys
                                             pair? #f #f
                                     ) ; end values
                          ) ; end lambda
        ) ; end make-do-sequence
) ; end define
(define (in-ipmap-values m
        ) ; end in-ipmap-values
        (make-do-sequence (lambda () (values car cdr (ipmap-values m
                                                     ) ; end ipmap-values
                                             pair? #f #f
                                     ) ; end values
                          ) ; end lambda
        ) ; end make-do-sequence
) ; end define

;; ---- 构造糖 / 推导式 ----
;; (ipmap k0 v0 k1 v1 ...) — 交替键值 (同内置 hash 惯例)
(define (ipmap . kvs
        ) ; end ipmap
  (let loop ([kvs kvs
             ] ; end kvs
              [m ipmap-empty
              ] ; end m
            ) ; end
    (cond
      [(null? kvs
       ) ; end null?
        m
      ] ; end m
      [(null? (cdr kvs
              ) ; end cdr
       ) ; end null?
        (error 'ipmap "expected an even number of key/value args"
        ) ; end error
      ] ; end
      [else (loop (cddr kvs
                  ) ; end cddr
                  (ipmap-set m (car kvs
                               ) ; end car
                             (cadr kvs
                             ) ; end cadr
                  ) ; end ipmap-set
            ) ; end loop
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define
;; (list->ipmap '((k . v) ...))
(define (list->ipmap pairs
        ) ; end list->ipmap
  (for/fold ([m ipmap-empty
             ] ; end m
            ) ; end
            ([p (in-list pairs
                ) ; end in-list
             ] ; end p
            ) ; end
            (ipmap-set m (car p
                         ) ; end car
                       (cdr p
                       ) ; end cdr
            ) ; end ipmap-set
  ) ; end for/fold
) ; end define
;; 左偏 union 折叠 (冲突取先出现者)
(define (ipmap-union* . ms
        ) ; end ipmap-union*
        (foldr ipmap-union ipmap-empty ms
        ) ; end foldr
) ; end define

;; for/ipmap 的 body 返回 (values key val)
(define-syntax-rule (for/ipmap (clause ...
                               ) ; end clause
                               body ...
                    ) ; end for/ipmap
  (for/fold ([m ipmap-empty
             ] ; end m
            ) ; end
            (clause ...
            ) ; end clause
    (define-values (k v
                   ) ; end k
                   (let () body ...
                   ) ; end let
    ) ; end define-values
    (ipmap-set m k v
    ) ; end ipmap-set
  ) ; end for/fold
) ; end define-syntax-rule
(define-syntax-rule (for*/ipmap (clause ...
                                ) ; end clause
                                body ...
                    ) ; end for*/ipmap
  (for*/fold ([m ipmap-empty
              ] ; end m
             ) ; end
             (clause ...
             ) ; end clause
    (define-values (k v
                   ) ; end k
                   (let () body ...
                   ) ; end let
    ) ; end define-values
    (ipmap-set m k v
    ) ; end ipmap-set
  ) ; end for*/fold
) ; end define-syntax-rule

