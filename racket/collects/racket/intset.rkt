#lang racket/base

;; racket/intset — 大端 Patricia trie 整数集合, hash-consing, 节点即 intset (无 wrapper)
;;
;; 每节点缓存 Merkle 结构 hash; 所有节点经弱内插表构造 (mk-tip/mk-bin), 结构相等
;; 的节点复用同一对象。Patricia canonical (同集合同树形) + 内插 (同树形同对象) ⟹
;; **同一集合恒为同一节点对象** ⟹ Patricia 节点自身就是公开的 intset (无外层
;; wrapper): eq? ⟺ 相同集合 (零额外表), equal? = eq?, hasheq 亦 O(1) 可作 memo 键。
;; 任何子树都是合法 intset (它确实表示一个集合)。
;;
;; 选型边界 (2026-08-08 实测, bit-exact 对拍): intset 适合 *稀疏 / 大* id 空间 +
;; *以集合为 memo 键*。稠密小 id (寄存器/vreg) 用 racket/intbits (位集), 别用 intset:
;;   - 稠密 liveness 不动点: intbits 快 intset 24~55x (位运算 vs trie+内插);
;;   - 稀疏大 id 不动点: intset 快 intbits ~7x (intbits 退化为巨 bignum);
;;   - 集合作 hasheq memo 键 (GVN/状态去重/分析缓存): intset 快 intbits 22~38x
;;     (hash-cons ⟹ eq? O(1) vs equal-hash O(bits))——此为 intset 的杀手锏场景。
;;
;; 单线程假设: 内插表是全局可变态 (CS 协作调度纯计算不被抢占)。

(require "private/patricia-bits.rkt" racket/swisstable
) ; end require

(provide intset intset? intset-empty intset-empty?
         intset-member? intset-add intset-remove
         intset-union intset-intersect intset-difference intset-union*
         intset-subset? intset-count intset-min intset-max
         intset->list list->intset in-intset intset-foldr intset-foldl
         for/intset for*/intset
         intset-intern-count
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
(define (tip-hash k
        ) ; end tip-hash
        (mix (mix 17 1
             ) ; end mix
             (bitwise-and k HMASK
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

;; ---- 节点 = 公开 intset 类型 (property 挂节点本身) ----
;; canonical + 内插 ⟹ eq? ⟺ 相同集合; equal-hash 读缓存 Merkle hash。
(define (node-write s port mode
        ) ; end node-write
        (fprintf port "#<intset:~a>" (intset->list s
                                     ) ; end intset->list
        ) ; end fprintf
) ; end define
(define (node-hash1 s _
        ) ; end node-hash1
        (node-hash s
        ) ; end node-hash
) ; end define

(struct pt-nil ()               #:property prop:custom-write node-write
) ; end struct
(struct pt-tip (key hash
               ) ; end key
        #:property prop:equal+hash (list (lambda (a b _
                                                 ) ; end a
                                                 (eq? a b
                                                 ) ; end eq?
                                         ) ; end lambda
                                         node-hash1 node-hash1
                                   ) ; end list
                                #:property prop:custom-write node-write
                                #:property prop:sequence (lambda (s
                                                                 ) ; end s
                                                                 (in-intset s
                                                                 ) ; end in-intset
                                                         ) ; end lambda
) ; end struct
(struct pt-bin (prefix mask left right hash
               ) ; end prefix
                                #:property prop:equal+hash (list (lambda (a b _
                                                                         ) ; end a
                                                                         (eq? a b
                                                                         ) ; end eq?
                                                                 ) ; end lambda
                                                                 node-hash1 node-hash1
                                                           ) ; end list
                                #:property prop:custom-write node-write
                                #:property prop:sequence (lambda (s
                                                                 ) ; end s
                                                                 (in-intset s
                                                                 ) ; end in-intset
                                                         ) ; end lambda
) ; end struct

(define the-nil (pt-nil
                ) ; end pt-nil
) ; end define
(define intset-empty the-nil
) ; end define
(define (intset? x
        ) ; end intset?
        (or (pt-nil? x
            ) ; end pt-nil?
            (pt-tip? x
            ) ; end pt-tip?
            (pt-bin? x
            ) ; end pt-bin?
        ) ; end or
) ; end define
(define (node-hash t
        ) ; end node-hash
  (cond [(pt-bin? t
         ) ; end pt-bin?
          (pt-bin-hash t
          ) ; end pt-bin-hash
        ] ; end
        [(pt-tip? t
         ) ; end pt-tip?
          (pt-tip-hash t
          ) ; end pt-tip-hash
        ] ; end
        [else 0
        ] ; end else
  ) ; end cond
) ; end define

;; ---- 弱内插表 (core/fallback 双后端, 同 pvector 哲学) ----
;; fixnum 结构hash -> (listof weak-box[node])。core swisstable 可用则用它
;; (eqv fixnum 键实测端到端 ~1.16x), 否则退回内建 hasheqv (不退化)。
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

(define (mk-tip k
        ) ; end mk-tip
  (define h (tip-hash k
            ) ; end tip-hash
  ) ; end define
  (intern h (lambda (n
                    ) ; end n
                    (and (pt-tip? n
                         ) ; end pt-tip?
                         (= (pt-tip-key n
                            ) ; end pt-tip-key
                            k
                         ) ; end =
                    ) ; end and
            ) ; end lambda
          (lambda () (pt-tip k h
                     ) ; end pt-tip
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
                  (and (pt-bin? n
                       ) ; end pt-bin?
                       (= (pt-bin-prefix n
                          ) ; end pt-bin-prefix
                          p
                       ) ; end =
                       (= (pt-bin-mask n
                          ) ; end pt-bin-mask
                          m
                       ) ; end =
                           (eq? (pt-bin-left n
                                ) ; end pt-bin-left
                                l
                           ) ; end eq?
                       (eq? (pt-bin-right n
                            ) ; end pt-bin-right
                            r
                       ) ; end eq?
                  ) ; end and
          ) ; end lambda
          (lambda () (pt-bin p m l r h
                     ) ; end pt-bin
          ) ; end lambda
  ) ; end intern
) ; end define

(define (intset-intern-count
        ) ; end intset-intern-count
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

;; ---- 树级 = intset 级 (构造走 mk-*) ----
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
  (cond [(pt-nil? l
         ) ; end pt-nil?
          r
        ] ; end r
        [(pt-nil? r
         ) ; end pt-nil?
          l
        ] ; end l
        [else (mk-bin p m l r
              ) ; end mk-bin
        ] ; end else
  ) ; end cond
) ; end define

(define (intset-member? s k
        ) ; end intset-member?
  (check-key 'intset-member? k
  ) ; end check-key
  (let loop ([t s
             ] ; end t
            ) ; end
    (cond
      [(pt-bin? t
       ) ; end pt-bin?
       (and (match-prefix? k (pt-bin-prefix t
                             ) ; end pt-bin-prefix
                           (pt-bin-mask t
                           ) ; end pt-bin-mask
            ) ; end match-prefix?
            (loop (if (zero-bit? k (pt-bin-mask t
                                   ) ; end pt-bin-mask
                      ) ; end zero-bit?
                      (pt-bin-left t
                      ) ; end pt-bin-left
                      (pt-bin-right t
                      ) ; end pt-bin-right
                  ) ; end if
            ) ; end loop
       ) ; end and
      ] ; end
      [(pt-tip? t
       ) ; end pt-tip?
        (= (pt-tip-key t
           ) ; end pt-tip-key
           k
        ) ; end =
      ] ; end
      [else #f
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (intset-add s k
        ) ; end intset-add
  (check-key 'intset-add k
  ) ; end check-key
  (let ins ([t s
            ] ; end t
           ) ; end
    (cond
      [(pt-bin? t
       ) ; end pt-bin?
       (define p (pt-bin-prefix t
                 ) ; end pt-bin-prefix
       ) ; end define
        (define m (pt-bin-mask t
                  ) ; end pt-bin-mask
        ) ; end define
       (cond
         [(not (match-prefix? k p m
               ) ; end match-prefix?
          ) ; end not
           (join k (mk-tip k
                   ) ; end mk-tip
                 p t
           ) ; end join
         ] ; end
         [(zero-bit? k m
          ) ; end zero-bit?
          (define l (pt-bin-left t
                    ) ; end pt-bin-left
          ) ; end define
           (define l* (ins l
                      ) ; end ins
           ) ; end define
          (if (eq? l l*
              ) ; end eq?
              t (mk-bin p m l* (pt-bin-right t
                               ) ; end pt-bin-right
                ) ; end mk-bin
          ) ; end if
         ] ; end
         [else
          (define r (pt-bin-right t
                    ) ; end pt-bin-right
          ) ; end define
          (define r* (ins r
                     ) ; end ins
          ) ; end define
          (if (eq? r r*
              ) ; end eq?
              t (mk-bin p m (pt-bin-left t
                            ) ; end pt-bin-left
                        r*
                ) ; end mk-bin
          ) ; end if
         ] ; end else
       ) ; end cond
      ] ; end
      [(pt-tip? t
       ) ; end pt-tip?
        (define tk (pt-tip-key t
                   ) ; end pt-tip-key
        ) ; end define
        (if (= tk k
            ) ; end =
            t (join k (mk-tip k
                      ) ; end mk-tip
                    tk t
              ) ; end join
        ) ; end if
      ] ; end
      [else (mk-tip k
            ) ; end mk-tip
      ] ; end else
    ) ; end cond
  ) ; end let
) ; end define

(define (intset-remove s k
        ) ; end intset-remove
  (check-key 'intset-remove k
  ) ; end check-key
  (let del ([t s
            ] ; end t
           ) ; end
    (cond
      [(pt-bin? t
       ) ; end pt-bin?
       (define p (pt-bin-prefix t
                 ) ; end pt-bin-prefix
       ) ; end define
        (define m (pt-bin-mask t
                  ) ; end pt-bin-mask
        ) ; end define
       (cond
         [(not (match-prefix? k p m
               ) ; end match-prefix?
          ) ; end not
           t
         ] ; end t
         [(zero-bit? k m
          ) ; end zero-bit?
          (define l (pt-bin-left t
                    ) ; end pt-bin-left
          ) ; end define
           (define l* (del l
                      ) ; end del
           ) ; end define
          (if (eq? l l*
              ) ; end eq?
              t (bin* p m l* (pt-bin-right t
                             ) ; end pt-bin-right
                ) ; end bin*
          ) ; end if
         ] ; end
         [else
          (define r (pt-bin-right t
                    ) ; end pt-bin-right
          ) ; end define
          (define r* (del r
                     ) ; end del
          ) ; end define
          (if (eq? r r*
              ) ; end eq?
              t (bin* p m (pt-bin-left t
                          ) ; end pt-bin-left
                      r*
                ) ; end bin*
          ) ; end if
         ] ; end else
       ) ; end cond
      ] ; end
      [(pt-tip? t
       ) ; end pt-tip?
        (if (= (pt-tip-key t
               ) ; end pt-tip-key
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

(define (intset-union s t
        ) ; end intset-union
  (cond
    [(eq? s t
     ) ; end eq?
      s
    ] ; end s
    [(pt-nil? s
     ) ; end pt-nil?
      t
    ] ; end t
    [(pt-nil? t
     ) ; end pt-nil?
      s
    ] ; end s
    [(pt-tip? s
     ) ; end pt-tip?
      (intset-add t (pt-tip-key s
                    ) ; end pt-tip-key
      ) ; end intset-add
    ] ; end
    [(pt-tip? t
     ) ; end pt-tip?
      (intset-add s (pt-tip-key t
                    ) ; end pt-tip-key
      ) ; end intset-add
    ] ; end
    [else
     (define p1 (pt-bin-prefix s
                ) ; end pt-bin-prefix
     ) ; end define
     (define m1 (pt-bin-mask s
                ) ; end pt-bin-mask
     ) ; end define
     (define l1 (pt-bin-left s
                ) ; end pt-bin-left
     ) ; end define
     (define r1 (pt-bin-right s
                ) ; end pt-bin-right
     ) ; end define
     (define p2 (pt-bin-prefix t
                ) ; end pt-bin-prefix
     ) ; end define
     (define m2 (pt-bin-mask t
                ) ; end pt-bin-mask
     ) ; end define
     (define l2 (pt-bin-left t
                ) ; end pt-bin-left
     ) ; end define
     (define r2 (pt-bin-right t
                ) ; end pt-bin-right
     ) ; end define
     (cond
       [(and (= m1 m2
             ) ; end =
             (= p1 p2
             ) ; end =
        ) ; end and
         (mk-bin p1 m1 (intset-union l1 l2
                       ) ; end intset-union
                 (intset-union r1 r2
                 ) ; end intset-union
         ) ; end mk-bin
       ] ; end
       [(and (shorter? m1 m2
             ) ; end shorter?
             (match-prefix? p2 p1 m1
             ) ; end match-prefix?
        ) ; end and
        (if (zero-bit? p2 m1
            ) ; end zero-bit?
            (mk-bin p1 m1 (intset-union l1 t
                          ) ; end intset-union
                    r1
            ) ; end mk-bin
            (mk-bin p1 m1 l1 (intset-union r1 t
                             ) ; end intset-union
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
            (mk-bin p2 m2 (intset-union s l2
                          ) ; end intset-union
                    r2
            ) ; end mk-bin
            (mk-bin p2 m2 l2 (intset-union s r2
                             ) ; end intset-union
            ) ; end mk-bin
        ) ; end if
       ] ; end
       [else (join p1 s p2 t
             ) ; end join
       ] ; end else
     ) ; end cond
    ] ; end else
  ) ; end cond
) ; end define

(define (intset-intersect s t
        ) ; end intset-intersect
  (cond
    [(eq? s t
     ) ; end eq?
      s
    ] ; end s
    [(or (pt-nil? s
         ) ; end pt-nil?
         (pt-nil? t
         ) ; end pt-nil?
     ) ; end or
      the-nil
    ] ; end the-nil
    [(pt-tip? s
     ) ; end pt-tip?
      (if (intset-member? t (pt-tip-key s
                            ) ; end pt-tip-key
          ) ; end intset-member?
          s the-nil
      ) ; end if
    ] ; end
    [(pt-tip? t
     ) ; end pt-tip?
      (if (intset-member? s (pt-tip-key t
                            ) ; end pt-tip-key
          ) ; end intset-member?
          t the-nil
      ) ; end if
    ] ; end
    [else
     (define p1 (pt-bin-prefix s
                ) ; end pt-bin-prefix
     ) ; end define
     (define m1 (pt-bin-mask s
                ) ; end pt-bin-mask
     ) ; end define
     (define l1 (pt-bin-left s
                ) ; end pt-bin-left
     ) ; end define
     (define r1 (pt-bin-right s
                ) ; end pt-bin-right
     ) ; end define
     (define p2 (pt-bin-prefix t
                ) ; end pt-bin-prefix
     ) ; end define
     (define m2 (pt-bin-mask t
                ) ; end pt-bin-mask
     ) ; end define
     (define l2 (pt-bin-left t
                ) ; end pt-bin-left
     ) ; end define
     (define r2 (pt-bin-right t
                ) ; end pt-bin-right
     ) ; end define
     (cond
       [(and (= m1 m2
             ) ; end =
             (= p1 p2
             ) ; end =
        ) ; end and
         (bin* p1 m1 (intset-intersect l1 l2
                     ) ; end intset-intersect
               (intset-intersect r1 r2
               ) ; end intset-intersect
         ) ; end bin*
       ] ; end
       [(and (shorter? m1 m2
             ) ; end shorter?
             (match-prefix? p2 p1 m1
             ) ; end match-prefix?
        ) ; end and
         (intset-intersect (if (zero-bit? p2 m1
                               ) ; end zero-bit?
                               l1 r1
                           ) ; end if
                           t
         ) ; end intset-intersect
       ] ; end
       [(and (shorter? m2 m1
             ) ; end shorter?
             (match-prefix? p1 p2 m2
             ) ; end match-prefix?
        ) ; end and
         (intset-intersect s (if (zero-bit? p1 m2
                                 ) ; end zero-bit?
                                 l2 r2
                             ) ; end if
         ) ; end intset-intersect
       ] ; end
       [else the-nil
       ] ; end else
     ) ; end cond
    ] ; end else
  ) ; end cond
) ; end define

(define (intset-difference s t
        ) ; end intset-difference
  (cond
    [(eq? s t
     ) ; end eq?
      the-nil
    ] ; end the-nil
    [(pt-nil? s
     ) ; end pt-nil?
      the-nil
    ] ; end the-nil
    [(pt-nil? t
     ) ; end pt-nil?
      s
    ] ; end s
    [(pt-tip? s
     ) ; end pt-tip?
      (if (intset-member? t (pt-tip-key s
                            ) ; end pt-tip-key
          ) ; end intset-member?
          the-nil s
      ) ; end if
    ] ; end
    [(pt-tip? t
     ) ; end pt-tip?
      (intset-remove s (pt-tip-key t
                       ) ; end pt-tip-key
      ) ; end intset-remove
    ] ; end
    [else
     (define p1 (pt-bin-prefix s
                ) ; end pt-bin-prefix
     ) ; end define
     (define m1 (pt-bin-mask s
                ) ; end pt-bin-mask
     ) ; end define
     (define l1 (pt-bin-left s
                ) ; end pt-bin-left
     ) ; end define
     (define r1 (pt-bin-right s
                ) ; end pt-bin-right
     ) ; end define
     (define p2 (pt-bin-prefix t
                ) ; end pt-bin-prefix
     ) ; end define
     (define m2 (pt-bin-mask t
                ) ; end pt-bin-mask
     ) ; end define
     (define l2 (pt-bin-left t
                ) ; end pt-bin-left
     ) ; end define
     (define r2 (pt-bin-right t
                ) ; end pt-bin-right
     ) ; end define
     (cond
       [(and (= m1 m2
             ) ; end =
             (= p1 p2
             ) ; end =
        ) ; end and
         (bin* p1 m1 (intset-difference l1 l2
                     ) ; end intset-difference
               (intset-difference r1 r2
               ) ; end intset-difference
         ) ; end bin*
       ] ; end
       [(and (shorter? m1 m2
             ) ; end shorter?
             (match-prefix? p2 p1 m1
             ) ; end match-prefix?
        ) ; end and
        (if (zero-bit? p2 m1
            ) ; end zero-bit?
            (bin* p1 m1 (intset-difference l1 t
                        ) ; end intset-difference
                  r1
            ) ; end bin*
            (bin* p1 m1 l1 (intset-difference r1 t
                           ) ; end intset-difference
            ) ; end bin*
        ) ; end if
       ] ; end
       [(and (shorter? m2 m1
             ) ; end shorter?
             (match-prefix? p1 p2 m2
             ) ; end match-prefix?
        ) ; end and
         (intset-difference s (if (zero-bit? p1 m2
                                  ) ; end zero-bit?
                                  l2 r2
                              ) ; end if
         ) ; end intset-difference
       ] ; end
       [else s
       ] ; end else
     ) ; end cond
    ] ; end else
  ) ; end cond
) ; end define

(define (intset-subset? s t
        ) ; end intset-subset?
  (cond
    [(eq? s t
     ) ; end eq?
      #t
    ] ; end #t
    [(pt-nil? s
     ) ; end pt-nil?
      #t
    ] ; end #t
    [(pt-nil? t
     ) ; end pt-nil?
      #f
    ] ; end #f
    [(pt-tip? s
     ) ; end pt-tip?
      (intset-member? t (pt-tip-key s
                        ) ; end pt-tip-key
      ) ; end intset-member?
    ] ; end
    [(pt-tip? t
     ) ; end pt-tip?
      #f
    ] ; end #f
    [else
     (define p1 (pt-bin-prefix s
                ) ; end pt-bin-prefix
     ) ; end define
     (define m1 (pt-bin-mask s
                ) ; end pt-bin-mask
     ) ; end define
     (define l1 (pt-bin-left s
                ) ; end pt-bin-left
     ) ; end define
     (define r1 (pt-bin-right s
                ) ; end pt-bin-right
     ) ; end define
     (define p2 (pt-bin-prefix t
                ) ; end pt-bin-prefix
     ) ; end define
     (define m2 (pt-bin-mask t
                ) ; end pt-bin-mask
     ) ; end define
     (define l2 (pt-bin-left t
                ) ; end pt-bin-left
     ) ; end define
     (define r2 (pt-bin-right t
                ) ; end pt-bin-right
     ) ; end define
     (cond
       [(and (= m1 m2
             ) ; end =
             (= p1 p2
             ) ; end =
        ) ; end and
         (and (intset-subset? l1 l2
              ) ; end intset-subset?
              (intset-subset? r1 r2
              ) ; end intset-subset?
         ) ; end and
       ] ; end
       [(and (shorter? m2 m1
             ) ; end shorter?
             (match-prefix? p1 p2 m2
             ) ; end match-prefix?
        ) ; end and
        (if (zero-bit? p1 m2
            ) ; end zero-bit?
            (intset-subset? s l2
            ) ; end intset-subset?
            (intset-subset? s r2
            ) ; end intset-subset?
        ) ; end if
       ] ; end
       [else #f
       ] ; end else
     ) ; end cond
    ] ; end else
  ) ; end cond
) ; end define

(define (intset-empty? s
        ) ; end intset-empty?
        (pt-nil? s
        ) ; end pt-nil?
) ; end define
(define (intset-count s
        ) ; end intset-count
  (let loop ([t s
             ] ; end t
              [acc 0
              ] ; end acc
            ) ; end
    (cond [(pt-bin? t
           ) ; end pt-bin?
            (loop (pt-bin-left t
                  ) ; end pt-bin-left
                  (loop (pt-bin-right t
                        ) ; end pt-bin-right
                        acc
                  ) ; end loop
            ) ; end loop
          ] ; end
          [(pt-tip? t
           ) ; end pt-tip?
            (add1 acc
            ) ; end add1
          ] ; end
          [else acc
          ] ; end else
    ) ; end cond
  ) ; end let
) ; end define
(define (intset-foldr s f init
        ) ; end intset-foldr
  (let loop ([t s
             ] ; end t
              [acc init
              ] ; end acc
            ) ; end
    (cond [(pt-bin? t
           ) ; end pt-bin?
            (loop (pt-bin-left t
                  ) ; end pt-bin-left
                  (loop (pt-bin-right t
                        ) ; end pt-bin-right
                        acc
                  ) ; end loop
            ) ; end loop
          ] ; end
          [(pt-tip? t
           ) ; end pt-tip?
            (f (pt-tip-key t
               ) ; end pt-tip-key
               acc
            ) ; end f
          ] ; end
          [else acc
          ] ; end else
    ) ; end cond
  ) ; end let
) ; end define
(define (intset-foldl s f init
        ) ; end intset-foldl
  (let loop ([t s
             ] ; end t
              [acc init
              ] ; end acc
            ) ; end
    (cond [(pt-bin? t
           ) ; end pt-bin?
            (loop (pt-bin-right t
                  ) ; end pt-bin-right
                  (loop (pt-bin-left t
                        ) ; end pt-bin-left
                        acc
                  ) ; end loop
            ) ; end loop
          ] ; end
          [(pt-tip? t
           ) ; end pt-tip?
            (f (pt-tip-key t
               ) ; end pt-tip-key
               acc
            ) ; end f
          ] ; end
          [else acc
          ] ; end else
    ) ; end cond
  ) ; end let
) ; end define
(define (intset-min s
        ) ; end intset-min
  (let loop ([t s
             ] ; end t
            ) ; end
       (cond [(pt-bin? t
              ) ; end pt-bin?
               (loop (pt-bin-left t
                     ) ; end pt-bin-left
               ) ; end loop
             ] ; end
             [(pt-tip? t
              ) ; end pt-tip?
               (pt-tip-key t
               ) ; end pt-tip-key
             ] ; end
             [else #f
             ] ; end else
       ) ; end cond
  ) ; end let
) ; end define
(define (intset-max s
        ) ; end intset-max
  (let loop ([t s
             ] ; end t
            ) ; end
       (cond [(pt-bin? t
              ) ; end pt-bin?
               (loop (pt-bin-right t
                     ) ; end pt-bin-right
               ) ; end loop
             ] ; end
             [(pt-tip? t
              ) ; end pt-tip?
               (pt-tip-key t
               ) ; end pt-tip-key
             ] ; end
             [else #f
             ] ; end else
       ) ; end cond
  ) ; end let
) ; end define
(define (intset->list s
        ) ; end intset->list
        (intset-foldr s cons '()
        ) ; end intset-foldr
) ; end define
(define (in-intset s
        ) ; end in-intset
        (make-do-sequence (lambda () (values car cdr (intset->list s
                                                     ) ; end intset->list
                                             pair? #f #f
                                     ) ; end values
                          ) ; end lambda
        ) ; end make-do-sequence
) ; end define

(define (check-key who k
        ) ; end check-key
  (unless (exact-nonnegative-integer? k
          ) ; end exact-nonnegative-integer?
          (raise-argument-error who "exact-nonnegative-integer?" k
          ) ; end raise-argument-error
  ) ; end unless
) ; end define

;; ---- 构造糖 / 推导式 ----
(define (list->intset ks
        ) ; end list->intset
        (for/fold ([s intset-empty
                   ] ; end s
                  ) ; end
                  ([k (in-list ks
                      ) ; end in-list
                   ] ; end k
                  ) ; end
                  (intset-add s k
                  ) ; end intset-add
        ) ; end for/fold
) ; end define
(define (intset . ks
        ) ; end intset
        (list->intset ks
        ) ; end list->intset
) ; end define
(define (intset-union* . sets
        ) ; end intset-union*
        (foldl intset-union intset-empty sets
        ) ; end foldl
) ; end define

(define-syntax-rule (for/intset (clause ...
                                ) ; end clause
                                body ...
                    ) ; end for/intset
  (for/fold ([s intset-empty
             ] ; end s
            ) ; end
            (clause ...
            ) ; end clause
            (intset-add s (let () body ...
                          ) ; end let
            ) ; end intset-add
  ) ; end for/fold
) ; end define-syntax-rule
(define-syntax-rule (for*/intset (clause ...
                                 ) ; end clause
                                 body ...
                    ) ; end for*/intset
  (for*/fold ([s intset-empty
              ] ; end s
             ) ; end
             (clause ...
             ) ; end clause
             (intset-add s (let () body ...
                           ) ; end let
             ) ; end intset-add
  ) ; end for*/fold
) ; end define-syntax-rule

