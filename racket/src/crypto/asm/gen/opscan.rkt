#lang racket/base

;; asm/gen/opscan.rkt — bn_mul_mont_op{K} 发射器
;; (Phase F: gen_opscan.py 的 asmp 化替代; 结构与其逐条对应)
;;
;; Operand-scanning CIOS Montgomery multiply: 寄存器驻留旋转累加器 (M=K+2),
;; 每行两条进位链 (lo 积 + hi 积各一条 adcs 链 → 每积 ~2 加, 对比 Comba/FIPS
;; 三字累加的 3)。旋转 base 使 CIOS 的一字右移隐式化。
;; ABI x0=r, x1=a, x2=b, x3=m, x4=n0。RSA-CRT (mod p/q) 热路径在 k=16。
;;
;; 用法: [RKTASM=<rktasm 路径>] racket asm/gen/opscan.rkt <K> <out.asm>

(require racket/list
         "gw.rkt")

(provide emit-opscan)

(define (emit-opscan K)
  (define M (+ K 2))
  (define (acc base j)
    (rx (string->symbol (format "acc~a" (modulo (+ base j) M)))))
  (define (sreg j) (rx (string->symbol (format "s~a" j))))
  (define (oreg j) (rx (string->symbol (format "o~a" j))))

  ;; acc[base+0..K-1] += lo(src[j]*factor); 进位收进 acc[base+K], acc[base+K+1]
  (define (lo-pass base factor srcptr)
    (append
     (append*
      (for/list ([j (in-range K)])
        (list (ins 'ldr (rx 't) (mem srcptr (* j 8)))
              (ins 'mul (rx 'p) (rx 't) factor)
              (if (zero? j)
                  (ins 'adds (acc base 0) (acc base 0) (rx 'p))
                  (ins 'adcs (acc base j) (acc base j) (rx 'p))))))
     (list (ins 'adcs (acc base K) (acc base K) xzr)
           (ins 'adc (acc base (+ K 1)) (acc base (+ K 1)) xzr))))

  ;; acc[base+1..K] += hi(src[j]*factor); 进位收进 acc[base+K+1]
  (define (hi-pass base factor srcptr)
    (append
     (append*
      (for/list ([j (in-range K)])
        (list (ins 'ldr (rx 't) (mem srcptr (* j 8)))
              (ins 'umulh (rx 'p) (rx 't) factor)
              (if (zero? j)
                  (ins 'adds (acc base 1) (acc base 1) (rx 'p))
                  (ins 'adcs (acc base (+ j 1)) (acc base (+ j 1)) (rx 'p))))))
     (list (ins 'adc (acc base (+ K 1)) (acc base (+ K 1)) xzr))))

  (define-values (rows-rev final-base)
    (for/fold ([rows '()] [base 0])
              ([i (in-range K)])
      (define row
        (append
         (list (rem (format "b[~a] base=~a" i base))
               (ins 'ldr (rx 'bi) (mem (rx 'b) (* i 8))))
         (lo-pass base (rx 'bi) (rx 'a))
         (hi-pass base (rx 'bi) (rx 'a))
         (list (ins 'mul (rx 'mi) (acc base 0) (rx 'n0)))
         (lo-pass base (rx 'mi) (rx 'm))
         (hi-pass base (rx 'mi) (rx 'm))
         ;; acc[base+0] 已消零, 旋转后成为新的 acc[K+1]
         (list (ins 'mov (acc base 0) xzr))))
      (values (cons row rows) (modulo (+ base 1) M))))

  (append
   (list (doc (format "Operand-scanning CIOS Montgomery multiply, k=~a (~a-bit): register-resident"
                      K (* K 64))
              "accumulator (rotating base), two carry chains per row (lo-product + hi-product"
              "pass = ~2 adds/product vs Comba/FIPS 3). The rotating base makes the CIOS"
              "one-word shift implicit. RSA-CRT (mod p/q) hot path at k=16."))
   (list (fn-begin (string->symbol (format "bn_mul_mont_op~a" K))
                   #:export? #t
                   #:in (list (rx 'r) (rx 'a) (rx 'b) (rx 'm) (rx 'n0)))
         (lbl 'entry)
         (save-all))
   (for/list ([j (in-range M)])
     (ins 'mov (rx (string->symbol (format "acc~a" j))) xzr))
   (append* (reverse rows-rev))
   ;; 条件减 m: 借位链 + 顶字借位判定 + csel 选择
   (append*
    (for/list ([j (in-range K)])
      (list (ins 'ldr (rx 't) (mem (rx 'm) (* j 8)))
            (ins (if (zero? j) 'subs 'sbcs) (sreg j) (acc final-base j) (rx 't)))))
   (list (ins 'sbcs xzr (acc final-base K) xzr))
   (for/list ([j (in-range K)])
     (ins 'csel (oreg j) (sreg j) (acc final-base j) (cnd 'cs)))
   (for/list ([j (in-range K)])
     (ins 'str (oreg j) (mem (rx 'r) (* j 8))))
   (list (restore-all)
         (ins 'ret)
         (fn-end))))

(module+ main
  (define argv (current-command-line-arguments))
  (unless (= (vector-length argv) 2)
    (error 'opscan "usage: racket asm/gen/opscan.rkt <K> <out.asm>"))
  (define K (string->number (vector-ref argv 0)))
  (unless (and (exact-positive-integer? K) (>= K 2))
    (error 'opscan "K must be an integer >= 2, got: ~a" (vector-ref argv 0)))
  (write-gnu-program (vector-ref argv 1) (emit-opscan K))
  (printf "wrote bn_mul_mont_op K=~a\n" K))
