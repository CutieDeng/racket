#lang racket/base

;; ============================================================
;; pipeline/sched-model.rkt - 调度器微架构模型（延迟/端口表外置）
;; ============================================================
;;
;; 兑现 docs/operation-scheduler-spec.md 的承诺：延迟与端口模型不再硬编码
;; 在 schedule.rkt，而是可从 data/<name>.rktd 加载。内置 apple-m 模型与
;; 旧硬编码表逐值一致（默认行为 bit 等价）。
;;
;; 模型文件格式（datum，见 data/latency.rktd）：
;;   ((name . apple-m)
;;    (issue-width . 3)
;;    (call-latency . 12)
;;    (default-latency . 1)
;;    (default-port . int)
;;    (default-port-capacity . 4)
;;    (latencies  ((mul umulh ...) . 3) ...)
;;    (ports      ((aese ...) . crypto) ...)
;;    (port-capacities (crypto . 1) (ld . 3) ...))
;;
;; 选择顺序：--sched-model 旗标 > ASMP_SCHED_MODEL 环境变量 > 内置 apple-m。
;; 名字解析为 data/<name>.rktd；含路径分隔符或 .rktd 后缀则按路径读取。

(require racket/runtime-path
         racket/string)

(provide current-sched-model
         resolve-sched-model!
         sched-model-name
         sched-model-issue-width
         sched-model-call-latency
         model-latency
         model-port
         model-port-capacity)

(struct sched-model
  (name issue-width call-latency
   default-latency default-port default-port-capacity
   lat-table port-table cap-table)
  #:transparent)

(define-runtime-path data-dir "../data")

(define (groups->table groups what)
  (define tbl (make-hasheq))
  (for ([entry (in-list groups)])
    (define keys (car entry))
    (define val (cdr entry))
    (for ([k (in-list (if (list? keys) keys (list keys)))])
      (when (hash-has-key? tbl k)
        (error 'sched-model "duplicate ~a entry for mnemonic: ~a" what k))
      (hash-set! tbl k val)))
  tbl)

(define (alist-ref alist key default)
  (cond [(assq key alist) => cdr] [else default]))

(define (datum->sched-model d source)
  (unless (and (list? d) (andmap pair? d))
    (error 'sched-model "malformed model datum in ~a" source))
  (sched-model
   (alist-ref d 'name (string->symbol (format "~a" source)))
   (alist-ref d 'issue-width 3)
   (alist-ref d 'call-latency 12)
   (alist-ref d 'default-latency 1)
   (alist-ref d 'default-port 'int)
   (alist-ref d 'default-port-capacity 4)
   (groups->table (alist-ref d 'latencies '()) 'latency)
   (groups->table (alist-ref d 'ports '()) 'port)
   (groups->table (alist-ref d 'port-capacities '()) 'port-capacity)))

(define (load-sched-model spec)
  (define path
    (cond
      [(or (string-contains? spec "/") (string-suffix? spec ".rktd"))
       (string->path spec)]
      [else (build-path data-dir (string-append spec ".rktd"))]))
  (unless (file-exists? path)
    (error 'sched-model "model file not found: ~a" path))
  (datum->sched-model (with-input-from-file path read) path))

;; 内置 apple-m：与外置 data/latency.rktd 及旧硬编码表逐值一致，
;; 保证无 data/ 目录（嵌入使用）时行为不变。
(define builtin-apple-m
  (datum->sched-model
   '((name . apple-m)
     (issue-width . 3)
     (call-latency . 12)
     (default-latency . 1)
     (default-port . int)
     (default-port-capacity . 4)
     (latencies
      ((mul umulh madd msub mneg smull umull) . 3)
      ((ldr ldp ldur ldrb ldrh ldrsw) . 4)
      ((str stp stur strb strh) . 1)
      ((aese aesd aesmc aesimc) . 2)
      ((pmull pmull2) . 3)
      ((ld1 ld2 ld3 ld4 ldnp) . 4)
      ((st1 st2 st3 st4 stnp) . 1)
      ((add sub mla mls shl sshr ushr sli sri ext tbl tbx zip1 zip2 uzp1 uzp2
        trn1 trn2 dup ins rev16 rev32 rev64 rbit cnt) . 2)
      ((and orr eor bic orn eor3 bcax not mov movi mvni fmov) . 1))
     (ports
      ((aese aesd aesmc aesimc pmull pmull2) . crypto)
      ((ldr ldp ldur ldrb ldrh ldrsw ld1 ld2 ld3 ld4 ldnp) . ld)
      ((str stp stur strb strh st1 st2 st3 st4 stnp) . st)
      ((mul umulh madd msub mneg smull umull) . mul)
      ((add sub mla mls shl sshr ushr sli sri ext tbl tbx zip1 zip2 uzp1 uzp2
        trn1 trn2 dup ins rev16 rev32 rev64 rbit cnt
        and orr eor bic orn eor3 bcax not mov movi mvni fmov) . simd))
     (port-capacities
      (crypto . 1) (ld . 3) (st . 2) (mul . 2) (simd . 4) (int . 6)))
   'builtin))

(define current-sched-model (make-parameter builtin-apple-m))

;; CLI/env 入口：spec 为名字或路径
(define (resolve-sched-model! spec)
  (current-sched-model (load-sched-model spec)))

(define (model-latency m mnem)
  (hash-ref (sched-model-lat-table m) mnem (sched-model-default-latency m)))

(define (model-port m mnem)
  (hash-ref (sched-model-port-table m) mnem (sched-model-default-port m)))

(define (model-port-capacity m port)
  (hash-ref (sched-model-cap-table m) port (sched-model-default-port-capacity m)))
