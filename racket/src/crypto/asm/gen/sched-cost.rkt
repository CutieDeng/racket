#lang racket/base

;; asm/gen/sched-cost.rkt — 内核静态成本估算 (F3: 发射器查询调度模型)
;;
;; 消费发射器产出的指令流, 查询 rktasm 的 apple-m 调度模型 (与装配用的
;; 同一份), 算出三个每内核标量:
;;   - issue-bound   = ceil(有效指令数 / issue-width)      吞吐下界(前端)
;;   - port-bound    = max_p ceil(count_p / capacity_p)    吞吐下界(执行端口)
;;   - chain-latency = 同名寄存器数据链的最长延迟和         关键路径(建议值)
;; 前二是**周期下界**(纯模型, 与硬件无关、零测量噪声); 后一是 pre-regalloc
;; 的同名链估计, 仅作建议 (重命名/内存别名不建模)。
;;
;; **用途 = CI 诊断/回归监视, 不是增益猎取**。D1 已实测宽乱序 M 核上静态
;; 重调度无可靠增益 (docs/openssl-parity-scheduling-plan.md), 故本工具的
;; 价值在于**发现发射器改动引入的端口压力/指令数回归** (例如某次重构把
;; port-int 压力翻倍), 而非据模型分数去调参求快。真·性能裁决仍是
;; regen.sh 的交织 A/B。
;;
;; 用法:
;;   racket asm/gen/sched-cost.rkt              # 全内核估算表
;;   racket asm/gen/sched-cost.rkt <kernel>     # 单内核明细 (端口分布)
;;   racket asm/gen/sched-cost.rkt --check      # 对比已提交快照, 漂移即非零退出
;;   racket asm/gen/sched-cost.rkt --snapshot   # 重写快照 (发射器有意改动后)
;; 内核名同 regen.sh: bn_op bn_fips ecc keccak keccak_f2 sha1
;; 快照 = asm/gen/sched-cost.snapshot (四元组/内核, 纯模型确定值)

(require racket/list
         racket/match
         racket/runtime-path
         "gw.rkt"
         "opscan.rkt"
         "fips.rkt"
         "mulplain.rkt"
         "keccak.rkt"
         "sha1.rkt")

;; 内核名 → 发射程序 (与 regen.sh TABLE 的可发射内核对应)
(define (kernel-program name)
  (case name
    [("bn_op")     (emit-opscan 16)]
    [("bn_fips")   (emit-fips 32)]
    [("ecc")       (append (emit-mul-plain 6) (emit-mul-plain 9))]
    [("keccak")    (emit-absorb)]
    [("keccak_f2") (emit-f2)]
    [("sha1")      (emit-sha1)]
    [else (error 'sched-cost "unknown kernel: ~a" name)]))

(define KERNELS '("bn_op" "bn_fips" "ecc" "keccak" "keccak_f2" "sha1"))

;; 程序 (可嵌套列表) → 扁平 ast-ins 序列 (指示/注释/空行不计成本)
(define (program->instrs prog)
  (let loop ([x prog] [acc '()])
    (cond
      [(list? x) (for/fold ([acc acc]) ([e (in-list x)]) (loop e acc))]
      [(ast-ins? x) (cons x acc)]
      [else acc])))

;; ---- 寄存器读写抽取 ----
;; 目的地 = 首个寄存器操作数 (str/st1 例外: 无目的寄存器, 全读)。
;; NZCV 进位链 (adcs/sbcs/adc/sbc) 单独连成一条链。

(define store-mnemonics '(str str stp stur strb strh st1 st2 st3 st4 stnp))
(define (store? m) (and (memq m store-mnemonics) #t))

(define carry-consumers '(adc adcs sbc sbcs adcs. sbcs.))
(define carry-producers '(adds adcs subs sbcs cmp cmn adc sbc adc. sbc.))

;; 从一个操作数收集涉及的寄存器名 (符号: 虚拟名 x.foo → 'x.foo; 物理 x5 → 'x5;
;; 内存基址寄存器也算读)。返回 symbol 列表。
(define (operand-regs op)
  (cond
    [(ast-reg? op)
     (list (reg-key op))]
    [(ast-mem? op)
     (let ([b (ast-mem-base op)] [o (ast-mem-offset op)])
       (append (if (ast-reg? b) (list (reg-key b)) '())
               (if (ast-reg? o) (list (reg-key o)) '())))]
    [(ast-reglist? op)
     (append-map operand-regs (ast-reglist-regs op))]
    [else '()]))

(define (reg-key r)
  (define id (ast-reg-id r))
  (if (memq id '(zr sp))
      #f  ; 零寄存器/栈指针不建模为数据依赖
      (string->symbol (format "~a.~a" (ast-reg-kind r) id))))

;; → (values dsts srcs) 两个 symbol 列表 (已去 #f)
(define (ins-def-use i)
  (define m (ast-ins-mnemonic i))
  (define ops (ast-ins-operands i))
  (define reg-ops (filter (lambda (o) (or (ast-reg? o) (ast-mem? o) (ast-reglist? o))) ops))
  (cond
    [(store? m)
     ;; 存储: 无寄存器目的, 全部操作数是读 (含基址)
     (values '() (filter values (append-map operand-regs reg-ops)))]
    [(null? reg-ops)
     (values '() '())]
    [else
     ;; 首个寄存器操作数是写, 其余是读
     (define dst (filter values (operand-regs (car reg-ops))))
     (define src (filter values (append-map operand-regs (cdr reg-ops))))
     (values dst src)]))

;; ---- 成本计算 ----

(define (compute-cost instrs)
  (define model (current-sched-model))
  (define iw (sched-model-issue-width model))
  (define n (length instrs))

  ;; 端口分布
  (define port-counts (make-hash))
  (for ([i (in-list instrs)])
    (define p (model-port model (ast-ins-mnemonic i)))
    (hash-update! port-counts p add1 0))
  (define port-bound
    (for/fold ([mx 0]) ([(p c) (in-hash port-counts)])
      (max mx (ceiling (/ c (model-port-capacity model p))))))

  (define issue-bound (ceiling (/ n iw)))

  ;; 同名寄存器数据链关键路径 + NZCV 进位链 (建议值)
  ;; ready[reg] = 该寄存器最近一次写的完成周期; carry-ready 同理
  (define ready (make-hash))
  (define carry-ready 0)
  (define crit 0)
  (for ([i (in-list instrs)])
    (define m (ast-ins-mnemonic i))
    (define lat (model-latency model m))
    (define-values (dsts srcs) (ins-def-use i))
    (define src-ready
      (for/fold ([t 0]) ([s (in-list srcs)])
        (max t (hash-ref ready s 0))))
    (define carry-in (if (memq m carry-consumers) carry-ready 0))
    (define start (max src-ready carry-in))
    (define finish (+ start lat))
    (for ([d (in-list dsts)]) (hash-set! ready d finish))
    (when (memq m carry-producers) (set! carry-ready finish))
    (set! crit (max crit finish)))

  (values n issue-bound port-bound crit port-counts))

;; ---- 报告 ----

(define (report-one name)
  (define instrs (program->instrs (kernel-program name)))
  (define-values (n ib pb crit ports) (compute-cost instrs))
  (printf "~a: ~a instrs | issue-bound ~a | port-bound ~a | chain-latency ~a\n"
          name n ib pb crit)
  (printf "  port distribution:\n")
  (for ([p (sort (hash-keys ports) symbol<?)])
    (define c (hash-ref ports p))
    (define cap (model-port-capacity (current-sched-model) p))
    (printf "    ~a: ~a  (cap ~a → ~a cyc)\n" p c cap (ceiling (/ c cap)))))

(define (report-table)
  (printf "static sched-cost (apple-m model; lower bounds, not a bench)\n")
  (printf "~a\n" (make-string 64 #\-))
  (printf "~a  ~a  ~a  ~a  ~a\n"
          (~w "kernel" 12) (~w "instrs" 8) (~w "issue" 7) (~w "port" 6) (~w "chain" 6))
  (for ([name (in-list KERNELS)])
    (define instrs (program->instrs (kernel-program name)))
    (define-values (n ib pb crit _p) (compute-cost instrs))
    (printf "~a  ~a  ~a  ~a  ~a\n"
            (~w name 12) (~w n 8) (~w ib 7) (~w pb 6) (~w crit 6))))

(define (~w v width)
  (define s (format "~a" v))
  (string-append s (make-string (max 0 (- width (string-length s))) #\space)))

;; ---- 快照 (回归门禁) ----
;; 每内核 (n issue-bound port-bound chain-latency); 纯模型确定值, 无测量噪声。

(define-runtime-path snapshot-path "sched-cost.snapshot")

(define (current-snapshot)
  (for/list ([name (in-list KERNELS)])
    (define instrs (program->instrs (kernel-program name)))
    (define-values (n ib pb crit _p) (compute-cost instrs))
    (list (string->symbol name) n ib pb crit)))

(define (write-snapshot)
  (call-with-output-file snapshot-path
    (lambda (out)
      (writeln '(kernel instrs issue-bound port-bound chain-latency) out)
      (for ([row (in-list (current-snapshot))]) (writeln row out)))
    #:exists 'truncate/replace)
  (printf "wrote ~a\n" snapshot-path))

(define (check-snapshot)
  (unless (file-exists? snapshot-path)
    (error 'sched-cost "no snapshot; run --snapshot first"))
  (define want
    (call-with-input-file snapshot-path
      (lambda (in)
        (read in) ; 跳过表头行
        (let loop ([acc '()])
          (define r (read in))
          (if (eof-object? r) (reverse acc) (loop (cons r acc)))))))
  (define got (current-snapshot))
  (define drift
    (for/list ([w (in-list want)] [g (in-list got)] #:unless (equal? w g))
      (cons w g)))
  (cond
    [(null? drift) (printf "sched-cost: 6 内核与快照一致\n") 0]
    [else
     (for ([d (in-list drift)])
       (printf "DRIFT ~a:\n  snapshot: ~s\n  current:  ~s\n"
               (car (car d)) (car d) (cdr d)))
     (printf "sched-cost: ~a 内核漂移 (发射器有意改动请 --snapshot 重写)\n"
             (length drift))
     1]))

(module+ main
  (define argv (current-command-line-arguments))
  (cond
    [(= (vector-length argv) 0) (report-table)]
    [(equal? (vector-ref argv 0) "--check") (exit (check-snapshot))]
    [(equal? (vector-ref argv 0) "--snapshot") (write-snapshot)]
    [(= (vector-length argv) 1) (report-one (vector-ref argv 0))]
    [else (error 'sched-cost "usage: racket asm/gen/sched-cost.rkt [kernel|--check|--snapshot]")]))
