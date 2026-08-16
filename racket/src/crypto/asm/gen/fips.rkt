#lang racket/base

;; asm/gen/fips.rkt — bn_mul_mont_fips{K} 发射器
;; (Phase F: gen_fips.py 的 asmp 化替代——原直出裸 GNU 的"异类管线"就此
;;  汇入标准 .asm 管线, 吸收 ASM-ENHANCEMENT-PLAN A4)
;;
;; FIPS Montgomery multiply, 宽度 K: 每列的积交替进入两个并行列累加器
;; A(a0-a2)/B(b0-b2), 两条加法链在乱序核上重叠, 再合并进滚动 Comba 累加器
;; t(t0-t2)。ABI x0=rp, x1=ap, x2=bp, x3=np, x4=n0。
;;
;; 迁移形态 (对照 gen_fips.py, 体指令序逐条一致):
;;  - 全部寄存器经 .context fips_mont 钉在 Python 版的同一物理分配上
;;    (体字节不变纪律, 同 A2/A7); 语义名: t*=滚动累加, a*/b*=列累加器,
;;    m0/m1=乘数对, plo/phi=积低/高, q=蒙哥马利商, top=进位顶字, sel=选择位,
;;    rp2/n02=跨内核暂存。
;;  - 手写 stp/ldp callee-saved 序幕换 .save all (asmp 生成帧; 唯一与
;;    Python 产物的指令差异, 过 Gate B 差分+交织 A/B 门禁)。
;;  - 定长 sp scratch 帧 (FR 字节, q/Z/D 三段) 属 asmp M3 未实现范围,
;;    保持手写 sub/add sp (--allow-sp-writes 放行, 同 p256_hand)。
;;
;; 用法: [RKTASM=<rktasm 路径>] racket asm/gen/fips.rkt <K> <out.asm>

(require racket/list
         "gw.rkt")

(provide emit-fips)

(define (emit-fips K)
  (define QO 0)               ; q[i] 商字区
  (define ZO (* K 8))         ; Z 结果区
  (define DO (* 2 K 8))       ; D = Z - N 差值区
  (define FR (* (quotient (+ (* 3 K 8) 15) 16) 16))

  ;; 语义名 → Python 版物理寄存器 (体字节不变的钉桩表)
  (define ctx
    (ctx-decl 'fips_mont
              (list (cons 'rp (rx 0))  (cons 'ap (rx 1))  (cons 'bp (rx 2))
                    (cons 'np (rx 3))  (cons 'n0 (rx 4))
                    (cons 't0 (rx 5))  (cons 't1 (rx 6))  (cons 't2 (rx 7))
                    (cons 'm0 (rx 8))  (cons 'm1 (rx 9))
                    (cons 'plo (rx 10)) (cons 'phi (rx 11))
                    (cons 'q (rx 12))  (cons 'top (rx 14)) (cons 'sel (rx 15))
                    (cons 'rp2 (rx 19)) (cons 'n02 (rx 20))
                    (cons 'a0 (rx 21)) (cons 'a1 (rx 22)) (cons 'a2 (rx 23))
                    (cons 'b0 (rx 24)) (cons 'b1 (rx 25)) (cons 'b2 (rx 26)))
              #:scope 'library))

  ;; 取操作数: 'q → sp 帧的商字区; 'a/'b/'m → 对应指针
  (define (ld dst base off)
    (case base
      [(q) (ins 'ldr (rx dst) (mem rsp (+ QO (* off 8))))]
      [(a) (ins 'ldr (rx dst) (mem (rx 'ap) (* off 8)))]
      [(b) (ins 'ldr (rx dst) (mem (rx 'bp) (* off 8)))]
      [(m) (ins 'ldr (rx dst) (mem (rx 'np) (* off 8)))]))

  ;; 一列: 积交替进 A/B 双累加器 (独立进位链), 再先 A 后 B 合并进 t
  (define (emit-column prods)
    (append
     (for/list ([r '(a0 a1 a2 b0 b1 b2)]) (ins 'mov (rx r) xzr))
     (append*
      (for/list ([p (in-list prods)] [k (in-naturals)])
        (define-values (acc0 acc1 acc2)
          (if (even? k) (values 'a0 'a1 'a2) (values 'b0 'b1 'b2)))
        (list (ld 'm0 (first p) (second p))
              (ld 'm1 (third p) (fourth p))
              (ins 'mul (rx 'plo) (rx 'm0) (rx 'm1))
              (ins 'umulh (rx 'phi) (rx 'm0) (rx 'm1))
              (ins 'adds (rx acc0) (rx acc0) (rx 'plo))
              (ins 'adcs (rx acc1) (rx acc1) (rx 'phi))
              (ins 'adc (rx acc2) (rx acc2) xzr))))
     (list (ins 'adds (rx 't0) (rx 't0) (rx 'a0))
           (ins 'adcs (rx 't1) (rx 't1) (rx 'a1))
           (ins 'adc (rx 't2) (rx 't2) (rx 'a2))
           (ins 'adds (rx 't0) (rx 't0) (rx 'b0))
           (ins 'adcs (rx 't1) (rx 't1) (rx 'b1))
           (ins 'adc (rx 't2) (rx 't2) (rx 'b2)))))

  ;; t 右滚一字
  (define (shift-t)
    (list (ins 'mov (rx 't0) (rx 't1))
          (ins 'mov (rx 't1) (rx 't2))
          (ins 'mov (rx 't2) xzr)))

  (append
   (list (doc (format "FIPS Montgomery multiply width K=~a with TWO parallel column accumulators:" K)
              "products of each column alternate between accumulator A and B so the two"
              "add-chains are independent and overlap on the OoO core, then A+B merge into"
              "the running Comba accumulator t. ABI x0=rp x1=ap x2=bp x3=np x4=n0."))
   (list ctx
         (fn-begin (string->symbol (format "bn_mul_mont_fips~a" K))
                   #:export? #t
                   #:contexts '(fips_mont))
         (lbl 'entry)
         (save-all)
         ;; 定长 scratch 帧 (q|Z|D 三段) — M3 未实现, 手写 sp (--allow-sp-writes)
         (ins 'sub rsp rsp (im FR))
         (ins 'mov (rx 'rp2) (rx 'rp))
         (ins 'mov (rx 'n02) (rx 'n0))
         (ins 'mov (rx 't0) xzr)
         (ins 'mov (rx 't1) xzr)
         (ins 'mov (rx 't2) xzr))
   ;; 低半列 0..K-1: 列积 + 蒙哥马利商消去
   (append*
    (for/list ([i (in-range K)])
      (append
       (list (rem (format "col ~a" i)))
       (emit-column
        (append (for/list ([j (in-range 0 i)]) (list 'a j 'b (- i j)))
                (for/list ([j (in-range 1 (+ i 1))]) (list 'm j 'q (- i j)))
                (list (list 'a i 'b 0))))
       (list (ins 'mul (rx 'q) (rx 't0) (rx 'n02))
             (ins 'str (rx 'q) (mem rsp (+ QO (* i 8))))
             (ins 'ldr (rx 'm1) (mem (rx 'np) 0))
             (ins 'mul (rx 'plo) (rx 'q) (rx 'm1))
             (ins 'umulh (rx 'phi) (rx 'q) (rx 'm1))
             (ins 'adds (rx 't0) (rx 't0) (rx 'plo))
             (ins 'adcs (rx 't1) (rx 't1) (rx 'phi))
             (ins 'adc (rx 't2) (rx 't2) xzr))
       (shift-t))))
   ;; 高半列 K..2K-2
   (append*
    (for/list ([i (in-range K (- (* 2 K) 1))])
      (append
       (list (rem (format "col ~a" i)))
       (emit-column
        (append*
         (for/list ([j (in-range (+ (- i K) 1) K)])
           (list (list 'a j 'b (- i j)) (list 'm j 'q (- i j))))))
       (list (ins 'str (rx 't0) (mem rsp (+ ZO (* (- i K) 8)))))
       (shift-t))))
   (list (ins 'str (rx 't0) (mem rsp (+ ZO (* (- K 1) 8))))
         (ins 'mov (rx 'top) (rx 't1)))
   ;; 条件减 N: D = Z - N (借位链), 顶字/借位判选
   (for/fold ([acc '()] #:result (reverse acc))
             ([j (in-range K)])
     (define lines
       (list (ins 'ldr (rx 'm0) (mem (rx 'np) (* j 8)))
             (ins 'ldr (rx 'm1) (mem rsp (+ ZO (* j 8))))
             (ins (if (zero? j) 'subs 'sbcs) (rx 'plo) (rx 'm1) (rx 'm0))
             (ins 'str (rx 'plo) (mem rsp (+ DO (* j 8))))))
     (append (reverse lines) acc))
   (list (ins 'cset (rx 'sel) (cnd 'cs))
         (ins 'orr (rx 'sel) (rx 'sel) (rx 'top))
         (ins 'cmp (rx 'sel) (im 0)))
   (append*
    (for/list ([j (in-range K)])
      (list (ins 'ldr (rx 'm1) (mem rsp (+ ZO (* j 8))))
            (ins 'ldr (rx 'plo) (mem rsp (+ DO (* j 8))))
            (ins 'csel (rx 'm1) (rx 'plo) (rx 'm1) (cnd 'ne))
            (ins 'str (rx 'm1) (mem (rx 'rp2) (* j 8))))))
   (list (ins 'add rsp rsp (im FR))
         (restore-all)
         (ins 'ret)
         (fn-end))))

(module+ main
  (define argv (current-command-line-arguments))
  (unless (= (vector-length argv) 2)
    (error 'fips "usage: racket asm/gen/fips.rkt <K> <out.asm>"))
  (define K (string->number (vector-ref argv 0)))
  (unless (and (exact-positive-integer? K) (>= K 2))
    (error 'fips "K must be an integer >= 2, got: ~a" (vector-ref argv 0)))
  (define out (vector-ref argv 1))
  (write-gnu-program out (emit-fips K))
  (printf "wrote bn_mul_mont_fips K=~a\n" K))
