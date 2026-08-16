#lang racket/base

;; ============================================================
;; private/patricia-bits.rkt — 大端 Patricia trie 的位原语
;; ============================================================
;;
;; 共享给 racket/intset 与 racket/ipmap。键为非负整数; 分支位 (mask) 为单个
;; 2 的幂, 前缀 (prefix) 为其上的公共高位。参考 Okasaki & Gill
;; "Fast Mergeable Integer Maps"。
;;
;;   highest-bit-mask w : ≤ w 的最高位 (2 的幂)
;;   branch-mask p1 p2  : p1、p2 最高相异位 (它们的分支位)
;;   zero-bit? i m      : i 在位 m 处是否为 0 (决定走左/右子树)
;;   mask-of i m        : i 在分支位 m 之上的前缀 (m 位及以下清零)
;;   match-prefix? i p m: i 的前缀 (在 m 层) 是否等于 p
;;   shorter? m1 m2     : m1 是否比 m2 更靠近根 (分支位更高 = 前缀更短)

(provide zero-bit? mask-of match-prefix? branch-mask shorter?
) ; end provide

;; ≤ w 的最高位。w>0 时 = 2^(integer-length(w)-1)。
(define (highest-bit-mask w
        ) ; end highest-bit-mask
  (arithmetic-shift 1 (sub1 (integer-length w
                            ) ; end integer-length
                      ) ; end sub1
  ) ; end arithmetic-shift
) ; end define

;; p1、p2 的分支位 (仅在 p1≠p2 时调用, 故 xor>0)
(define (branch-mask p1 p2
        ) ; end branch-mask
  (highest-bit-mask (bitwise-xor p1 p2
                    ) ; end bitwise-xor
  ) ; end highest-bit-mask
) ; end define

(define (zero-bit? i m
        ) ; end zero-bit?
  (zero? (bitwise-and i m
         ) ; end bitwise-and
  ) ; end zero?
) ; end define

;; i 在分支位 m 之上的前缀: 清掉 m 位及其以下所有位。
;; (sub1 (arithmetic-shift m 1)) = 2m-1 = m 位及以下全 1; 取反后与 i。
(define (mask-of i m
        ) ; end mask-of
  (bitwise-and i (bitwise-not (sub1 (arithmetic-shift m 1
                                    ) ; end arithmetic-shift
                              ) ; end sub1
                 ) ; end bitwise-not
  ) ; end bitwise-and
) ; end define

(define (match-prefix? i p m
        ) ; end match-prefix?
  (= (mask-of i m
     ) ; end mask-of
     p
  ) ; end =
) ; end define

;; 分支位更大 = 前缀更短 = 更靠近根
(define (shorter? m1 m2
        ) ; end shorter?
  (> m1 m2
  ) ; end >
) ; end define

