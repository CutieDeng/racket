#lang racket/base

;; asm/gen/sha1.rkt — sha1_blocks_asm 发射器
;; (Phase F: gen_sha1.py 的 asmp 化替代; 结构与其逐条对应)
;;
;; 多块 ARMv8 SHA-1 压缩 (sha1c/p/m + sha1h + sha1su0/su1), 转写 OpenSSL
;; sha1-armv8.pl 的硬件调度——指令**摆放**正是 clang 在 Apple M 上调度差
;; ~7% 的部分。状态 (ABCD,E) 跨全部块驻留向量寄存器, 无逐块 ctx 往返。
;; ABI: void sha1_blocks_asm(uint32_t st[5], const uint8_t *p, long nblk)
;;
;; 用法: [RKTASM=<rktasm 路径>] racket asm/gen/sha1.rkt <out.asm>

(require racket/list
         "gw.rkt")

(provide emit-sha1)

;; K 常量 (轮组 0-19/20-39/40-59/60-79) 的 movz/movk 半字对
(define K-HALVES '((#x7999 #x5A82) (#xEBA1 #x6ED9) (#xBCDC #x8F1B) (#xC1D6 #xCA62)))

(define (v4s name) (rv name "4s"))
(define (v16b name) (rv name "16b"))

(define (emit-sha1)
  (define kxx (vector 'k0 'k1 'k2 'k3))
  (append
   (list (doc "Multi-block ARMv8 SHA-1 compress (sha1c/p/m + sha1h + sha1su0/su1)."
              "State (ABCD,E) stays in vector registers across all blocks -- no per-block"
              "ctx round-trip. The instruction schedule mirrors OpenSSL's hardware path,"
              "which clang schedules ~7% worse on Apple M. ~20 ns/block."))
   (list (fn-begin 'sha1_blocks_asm #:export? #t
                   #:in (list (rx 'st) (rx 'p) (rx 'num)))
         (lbl 'entry))
   (append*
    (for/list ([halves (in-list K-HALVES)] [i (in-naturals)])
      (list (ins 'movz (rw 't) (im (first halves)))
            (ins 'movk (rw 't) (im (second halves)) (sh 'lsl 16))
            (ins 'dup (v4s (vector-ref kxx i)) (rw 't)))))
   (list (ins 'ld1 (regs (v4s 'abcd)) (mem (rx 'st)))
         (ins 'ldr (rs-reg 'e) (mem (rx 'st) 16))
         (lbl 'loop)
         (ins 'ld1 (regs (v4s 'm0) (v4s 'm1) (v4s 'm2) (v4s 'm3))
              (mem-post (rx 'p) 64))
         (ins 'subs (rx 'num) (rx 'num) (im 1))
         (ins 'rev32 (v16b 'm0) (v16b 'm0))
         (ins 'rev32 (v16b 'm1) (v16b 'm1))
         (ins 'add (v4s 'w0) (v4s 'k0) (v4s 'm0))
         (ins 'rev32 (v16b 'm2) (v16b 'm2))
         (ins 'mov (v16b 'abcd0) (v16b 'abcd))
         (ins 'add (v4s 'w1) (v4s 'k0) (v4s 'm1))
         (ins 'rev32 (v16b 'm3) (v16b 'm3))
         (ins 'sha1h (rs-reg 'e1) (rs-reg 'abcd))
         (ins 'sha1c (rq 'abcd) (rs-reg 'e) (v4s 'w0))
         (ins 'add (v4s 'w0) (v4s 'k0) (v4s 'm2))
         (ins 'sha1su0 (v4s 'm0) (v4s 'm1) (v4s 'm2)))
   ;; 主展开: e0/e1、w0/w1 乒乓, msg 环转, 每 5 轮换 K 组
   (let loop ([i 1] [j 0]
              [msg '(m0 m1 m2 m3)] [w0 'w0] [w1 'w1] [e0 'e0] [e1 'e1]
              [acc '()])
     (cond
       [(> i 16) (reverse acc)]
       [else
        (define f (list-ref '(sha1c sha1p sha1m sha1p) (quotient i 5)))
        (define lines
          (append
           (list (ins 'sha1h (rs-reg e0) (rs-reg 'abcd))
                 (ins f (rq 'abcd) (rs-reg e1) (v4s w1))
                 (ins 'add (v4s w1) (v4s (vector-ref kxx j)) (v4s (fourth msg)))
                 (ins 'sha1su1 (v4s (first msg)) (v4s (fourth msg))))
           (if (< i 16)
               (list (ins 'sha1su0 (v4s (second msg)) (v4s (third msg)) (v4s (fourth msg))))
               '())))
        (loop (+ i 1)
              (if (zero? (modulo (+ i 3) 5)) (+ j 1) j)
              (append (rest msg) (list (first msg)))
              w1 w0 e1 e0
              (append (reverse lines) acc))]))
   ;; 收尾 3 轮 (60..79 尾部) + 前馈
   ;; 主循环出口: i=17 时 e0/e1 与 w0/w1 已乒乓 16 次 → e0='e0 e1='e1 w1='w1
   (list (ins 'sha1h (rs-reg 'e0) (rs-reg 'abcd))
         (ins 'sha1p (rq 'abcd) (rs-reg 'e1) (v4s 'w1))
         (ins 'add (v4s 'w1) (v4s 'k3) (v4s 'm3))
         (ins 'sha1h (rs-reg 'e1) (rs-reg 'abcd))
         (ins 'sha1p (rq 'abcd) (rs-reg 'e0) (v4s 'w0))
         (ins 'sha1h (rs-reg 'e0) (rs-reg 'abcd))
         (ins 'sha1p (rq 'abcd) (rs-reg 'e1) (v4s 'w1))
         (ins 'add (v4s 'e) (v4s 'e) (v4s 'e0))
         (ins 'add (v4s 'abcd) (v4s 'abcd) (v4s 'abcd0))
         (ins 'b #:suffix 'ne (lab 'loop))
         (ins 'st1 (regs (v4s 'abcd)) (mem (rx 'st)))
         (ins 'str (rs-reg 'e) (mem (rx 'st) 16))
         (ins 'ret)
         (fn-end))))

(module+ main
  (define argv (current-command-line-arguments))
  (unless (= (vector-length argv) 1)
    (error 'sha1 "usage: racket asm/gen/sha1.rkt <out.asm>"))
  (write-gnu-program (vector-ref argv 0) (emit-sha1)))
