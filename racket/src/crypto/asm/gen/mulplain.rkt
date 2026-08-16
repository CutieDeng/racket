#lang racket/base

;; asm/gen/mulplain.rkt — mul_plain{6,9} 发射器
;; (Phase F: gen_mulplain.py 的 asmp 化替代; 结构与其逐条对应)
;;
;; Plain schoolbook multiply r[0..2K-1] = a[0..K-1] * b[0..K-1]:
;; operand-scanning, 寄存器驻留旋转累加器 (M = K+2 槽), 每列两条进位链
;; (lo 积 adcs 扫 + hi 积 adcs 扫), 无约简步。ABI x0=r, x1=a, x2=b。
;;
;; 用法: [RKTASM=<rktasm 路径>] racket asm/gen/mulplain.rkt <K> <out.asm>
;; 验收 (迁移时已过): asm/gen/asm-equiv.rkt 证明新旧 .asm AST 相同;
;; regen.sh check/gate ecc 全绿 (.S 指令体复现 + 差分门禁)。

(require racket/list
         "gw.rkt")

(provide emit-mul-plain)

(define (emit-mul-plain K)
  (define M (+ K 2))
  (define (acc base j)
    (rx (string->symbol (format "acc~a" (modulo (+ base j) M)))))

  ;; lo 积进位链: acc[base+j] += lo(a[j]*bi), 尾部吸收进位到 acc[base+K+1]
  (define (lo-pass base)
    (append
     (append*
      (for/list ([j (in-range K)])
        (list (ins 'ldr (rx 't) (mem (rx 'a) (* j 8)))
              (ins 'mul (rx 'p) (rx 't) (rx 'bi))
              (if (zero? j)
                  (ins 'adds (acc base 0) (acc base 0) (rx 'p))
                  (ins 'adcs (acc base j) (acc base j) (rx 'p))))))
     (list (ins 'adcs (acc base K) (acc base K) xzr)
           (ins 'adc (acc base (+ K 1)) (acc base (+ K 1)) xzr))))

  ;; hi 积进位链: acc[base+j+1] += hi(a[j]*bi)
  (define (hi-pass base)
    (append
     (append*
      (for/list ([j (in-range K)])
        (list (ins 'ldr (rx 't) (mem (rx 'a) (* j 8)))
              (ins 'umulh (rx 'p) (rx 't) (rx 'bi))
              (if (zero? j)
                  (ins 'adds (acc base 1) (acc base 1) (rx 'p))
                  (ins 'adcs (acc base (+ j 1)) (acc base (+ j 1)) (rx 'p))))))
     (list (ins 'adc (acc base (+ K 1)) (acc base (+ K 1)) xzr))))

  ;; 一列: 载 b[i], lo/hi 双扫, 收 r[i], 腾出旋转槽
  (define (column i base)
    (append
     (list (rem (format "b[~a] base=~a" i base))
           (ins 'ldr (rx 'bi) (mem (rx 'b) (* i 8))))
     (lo-pass base)
     (hi-pass base)
     (list (ins 'str (acc base 0) (mem (rx 'r) (* i 8)))
           (ins 'mov (acc base 0) xzr))))

  (define-values (columns-rev final-base)
    (for/fold ([cols '()] [base 0])
              ([i (in-range K)])
      (values (cons (column i base) cols) (modulo (+ base 1) M))))

  (append
   (list (doc (format "Plain schoolbook multiply r=a*b for ~a-limb field elements (~a): operand-scanning,"
                      K
                      (case K
                        [(6) "P-384"]
                        [(9) "P-521"]
                        [else (format "~a-bit" (* K 64))]))
              "register-resident rotating accumulator, two carry chains per column (lo+hi"
              "sweeps), no reduction pass. Beats the C Comba (~2x). Routed from rktcrypto_ecc.c."))
   (list (fn-begin (string->symbol (format "mul_plain~a" K))
                   #:export? #t
                   #:in (list (rx 'r) (rx 'a) (rx 'b)))
         (lbl 'entry)
         (save-all))
   (for/list ([j (in-range M)])
     (ins 'mov (rx (string->symbol (format "acc~a" j))) xzr))
   (append* (reverse columns-rev))
   ;; 高半部 r[K..2K-1] = 旋转累加器剩余槽
   (for/list ([j (in-range K)])
     (ins 'str (acc final-base j) (mem (rx 'r) (* (+ K j) 8))))
   (list (restore-all)
         (ins 'ret)
         (fn-end))))

(module+ main
  (define argv (current-command-line-arguments))
  (unless (= (vector-length argv) 2)
    (error 'mulplain "usage: racket asm/gen/mulplain.rkt <K> <out.asm>"))
  (define K (string->number (vector-ref argv 0)))
  (unless (memv K '(6 9))
    (error 'mulplain "K must be 6 or 9, got: ~a" (vector-ref argv 0)))
  (define out (vector-ref argv 1))
  (write-gnu-program out (emit-mul-plain K))
  (printf "wrote mul_plain K=~a\n" K))
