#lang racket

;; ============================================================
;; pipeline/schedule.rkt - 操作级压力感知列表调度器
;; ============================================================
;;
;; 规格见 docs/operation-scheduler-spec.md。
;;
;; 在 inline 展开(.call 降级)之前，对每个基本块的可调度区段做依赖保持的
;; 列表调度，把长延迟域乘 (.call 节点) 重排以最大化乱序核上的重叠 (ILP)，
;; 同时用压力感知选择把寄存器压力约束住 (避免过量溢出)。
;;
;; .call 被当作单个高延迟节点：其 uses = 输入绑定的 actual，defs = 输出绑定
;; 的 actual (据 callee 签名的 in/out mode)。域运算 .call 对调用方内存无副作用
;; (寄存器传参、纯函数)，故不引内存定序边 —— 由差分 KAT 兜底验证。

(require "../parser/ast.rkt"
         "../semantic/control-flow.rkt"
         "../semantic/use-def.rkt"
         "regalloc/types.rkt"
         "sched-model.rkt"
         racket/pvector
         racket/intmap)

(provide schedule-function
         compute-pure-callees
         compute-criticality-map
         *enable-scheduler*
         ;; 供测试
         build-region-dag
         (struct-out sched-node)
         split-regions
         list-schedule-region
         stmt-latency
         stmt-port
         port-capacity)

(define *enable-scheduler* (make-parameter #t))

;; NZCV 伪寄存器 (条件标志)，作依赖建模用的唯一标记
(define NZCV (reg-id 'nzcv 0 'nzcv #f))

;; 置标志 (def NZCV) 的助记符
(define FLAG-SETTERS
  '(adds adcs subs sbcs ands bics cmp cmn tst negs ngcs cmp.w))
;; 读标志 (use NZCV) 的助记符 (adcs/sbcs 既读又写)
(define FLAG-READERS
  '(adc sbc adcs sbcs csel cset csetm cinc cinv cneg csinc csinv csneg ccmp ccmn))

;; 分支/返回 (硬屏障)
(define BRANCH-MNEMONICS '(b br blr ret cbz cbnz tbz tbnz))

;; ============================================================
;; 节点：一条指令 / 一个 .call 的调度单元
;; ============================================================
(struct sched-node
  (index      ; 原始序号 (稳定性/平手)
   stmt       ; ast-ins | ast-directive('call)
   uses       ; (listof reg-id)  含 NZCV
   defs       ; (listof reg-id)  含 NZCV
   latency    ; 延迟 (cyc)
   mem)       ; 'none | 'load | 'store | 'both  (内存副作用类别)
  #:transparent)

(define LOAD-MNEMONICS
  '(ldr ldp ldur ldrb ldrh ldrsw ldrsb ldrsh ldar ldxr ldaxr ldnp ld1 ld2 ld3 ld4))
(define STORE-MNEMONICS
  '(str stp stur strb strh stlr stxr stlxr stnp st1 st2 st3 st4))

;; 语句的内存类别。纯 .call (被调方无访存) → 'none；否则 (impure/未知) → 'both。
(define (stmt-mem-class stmt pure-callees)
  (cond
    [(call-directive? stmt)
     (if (hash-ref pure-callees (ast-directive-name stmt) #f) 'none 'both)]
    [(ast-ins? stmt)
     (define m (ast-ins-mnemonic stmt))
     (cond [(memq m LOAD-MNEMONICS) 'load]
           [(memq m STORE-MNEMONICS) 'store]
           [else 'none])]
    [else 'none]))

(define (mem-reads? c) (memq c '(load both)))
(define (mem-writes? c) (memq c '(store both)))

;; 内存地址 (base . offset)，用于别名消歧。offset=#f 表示未知（保守）。
;; 仅识别 [base, #imm] 直接寻址（无回写/无变址寄存器）；否则返回 #f (未知)。
(define (stmt-mem-addr stmt)
  (and (ast-ins? stmt)
       (let loop ([ops (ast-ins-operands stmt)])
         (cond
           [(null? ops) #f]
           [(ast-mem? (car ops))
            (define mem (car ops))
            (define base (ast-mem-base mem))
            (define off (ast-mem-offset mem))
            (if (and (ast-reg? base)
                     (eq? (ast-mem-index-mode mem) 'offset)
                     (not (ast-mem-index-mode-writeback? mem)))
                (cons (ast-reg-id base)
                      (and (ast-imm? off) (ast-imm-value off)))
                #f)]                        ; 变址/回写 → 未知
           [else (loop (cdr ops))]))))

(define (ast-mem-index-mode-writeback? mem)
  (memq (ast-mem-index-mode mem) '(pre post)))

;; 两个内存地址可能别名？未知/异基址/近偏移 → 保守别名；同基址且偏移相距≥16 → 不别名。
(define (mem-may-alias? a1 a2)
  (or (getenv "ASMP_SCHED_NOMEMDIS")           ; 关消歧 → 全部保守别名 (调试)
      (not a1) (not a2)
      (not (cdr a1)) (not (cdr a2))          ; 未知偏移
      (not (equal? (car a1) (car a2)))       ; 异基址 → 保守别名
      (< (abs (- (cdr a1) (cdr a2))) 16)))    ; 同基址近偏移 → 别名

;; ------------------------------------------------------------
;; 助记符 → 延迟 / 执行端口。表由微架构模型提供（pipeline/sched-model.rkt，
;; 数据文件 data/<name>.rktd，--sched-model / ASMP_SCHED_MODEL 选择；
;; 默认 apple-m，与历史硬编码表逐值一致）。
(define (stmt-latency stmt)
  (define m (current-sched-model))
  (cond
    [(call-directive? stmt) (sched-model-call-latency m)]
    [(ast-ins? stmt) (model-latency m (ast-ins-mnemonic stmt))]
    [else 1]))

;; 宽乱序核对每类端口每周期有独立的发射上限；不同类可并行，同类竞争。
;; Apple M 上 AES 与 PMULL 共享 crypto 管线 (实测二者几乎不重叠)，模型将其
;; 归入同一 'crypto 端口，调度器据此不会徒劳地试图让它们并行。
(define (stmt-port stmt)
  (define m (current-sched-model))
  (cond
    [(call-directive? stmt) 'int]
    [(ast-ins? stmt) (model-port m (ast-ins-mnemonic stmt))]
    [else 'int]))

;; 可用 ASMP_SCHED_PORTS=0 关闭端口模型 (退回纯 issue-width)。
(define (port-capacity port)
  (model-port-capacity (current-sched-model) port))

(define (call-directive? s)
  (and (ast-directive? s) (eq? (ast-directive-kind s) 'call)))

;; ------------------------------------------------------------
;; 硬屏障判定：其两侧不跨越重排
(define (barrier? stmt)
  (cond
    [(call-directive? stmt) #f]           ; .call 可调度
    [(ast-directive? stmt) #t]            ; 其它 directive (.save/.restore/label...) 屏障
    [(ast-label? stmt) #t]
    [(ast-ins? stmt)
     (define m (ast-ins-mnemonic stmt))
     (or (memq m BRANCH-MNEMONICS)
         (memq m '(bl))                   ; 裸 bl (未知目标) 保守作屏障
         (writes-special-reg? stmt))]
    [else #t]))

;; 写 sp/fp/lr → 屏障 (栈/帧/返回地址)
(define (writes-special-reg? ins)
  (define ud (extract-use-def ins))
  (for/or ([ref (in-list (use-def-flat-defs ud))])
    (define rid (reg-ref->reg-id ref))
    (and (not (reg-id-virtual? rid))
         (memv (reg-id-id rid) '(sp 29 30 31 fp lr)))))

;; ------------------------------------------------------------
;; 计算一条语句的 (uses . defs)，reg-id 列表 (含 NZCV)
(define (stmt-use-def stmt callee-params)
  (cond
    [(call-directive? stmt)
     (call-use-def stmt callee-params)]
    [(ast-ins? stmt)
     (define ud (extract-use-def stmt))
     (define m (ast-ins-mnemonic stmt))
     (define base-uses (map reg-ref->reg-id (use-def-flat-uses ud)))
     (define base-defs (map reg-ref->reg-id (use-def-flat-defs ud)))
     (define uses (if (memq m FLAG-READERS) (cons NZCV base-uses) base-uses))
     (define defs (if (or (memq m FLAG-SETTERS)) (cons NZCV base-defs) base-defs))
     (cons uses defs)]
    [else (cons '() '())]))

;; .call: 输入绑定 actual = use；输出绑定 actual = def。
;; 不建模 NZCV：托管 .call 到纯域子例程，调用方不跨调用依赖标志 (ABI 标准——
;; 调用会 clobber 标志，故良构代码从不跨调用读旧标志)。若把 .call 也算 NZCV-def，
;; 会把所有域乘串进进位链的总序 → 完全无法重排。正确性由差分 KAT 兜底。
(define (call-use-def stmt callee-params)
  (define target (ast-directive-name stmt))
  (define bindings (call-directive-bindings* (ast-directive-args stmt)))
  (define params (hash-ref callee-params target #f))
  (define mode-of                ; formal-key -> mode
    (if params
        (for/hash ([p (in-list params)])
          (values (formal-key* (second p)) (first p)))
        (hash)))
  (define uses '())
  (define defs '())
  (for ([b (in-list bindings)])
    (define formal (first b))
    (define actual (second b))
    (define rid (areg->reg-id actual))
    (when rid
      (define mode (hash-ref mode-of (formal-key* formal) 'inout)) ; 未知 → 保守 inout
      (when (memq mode '(in inout)) (set! uses (cons rid uses)))
      (when (memq mode '(out inout)) (set! defs (cons rid defs)))))
  (cons uses defs))

;; ast-reg -> 虚拟 reg-id (与 areg 一致处理)
(define (areg->reg-id r)
  (and (ast-reg? r)
       (let* ([kind (ast-reg-kind r)] [id (ast-reg-id r)]
              [class (case kind [(x w) 'gpr] [(z v d s h b q) 'fpr] [(p) 'predicate] [else 'gpr])])
         (cond
           [(and (symbol? id) (not (memq id '(sp zr xzr wzr))))
            (reg-id class (canonical-width class) id #t)]
           [(number? id) (reg-id class (canonical-width class) id #f)]
           [else #f]))))

;; 绑定/formal 辅助 (与 inline.rkt 同义，独立实现避免耦合)
(define (call-directive-bindings* args)
  (cond [(hash? args) (hash-ref args 'bindings '())]
        [(list? args) args]
        [else '()]))
(define (formal-key* f)
  (and (ast-reg? f) (ast-reg-id f)))

;; ============================================================
;; DAG 构建 (一个区段 = 无屏障的指令向量)
;; ============================================================
;; 返回 (values succs preds) : vector[idx -> (listof idx)]
;; nzcv-live-out?：本区段末尾 NZCV 是否活跃 (后随条件分支读标志)。若是，原序中
;; 最后一个 NZCV 写者/clobber 必须仍是调度中最后一个 NZCV 写 (否则条件分支读到错误标志)。
(define (build-region-dag nodes #:nzcv-live-out? [nzcv-live-out? #f])
  (define n (vector-length nodes))
  (define succs (make-vector n '()))
  (define preds (make-vector n '()))
  (define nzcv-write-idxs '())     ; 所有 NZCV 写者/clobber 的 idx
  (define (add-edge! i j)          ; i 在 j 前
    (unless (= i j)
      (vector-set! succs i (cons j (vector-ref succs i)))
      (vector-set! preds j (cons i (vector-ref preds j)))))
  ;; 记录每个 reg 最近的 def 位置、以及自上个 def 以来的 use 位置
  (define last-def (make-hash))    ; reg-id -> idx
  (define uses-since-def (make-hash)) ; reg-id -> (listof idx)
  (define edge-seen (make-hash))   ; (cons i j) -> #t 去重
  (define (add-edge/dedup! i j)
    (define k (cons i j))
    (unless (or (= i j) (hash-ref edge-seen k #f))
      (hash-set! edge-seen k #t)
      (add-edge! i j)))
  ;; 内存定序（带别名消歧）：
  ;;   load-like 依赖最近的"可能别名"store-like；
  ;;   store-like 依赖此前所有"可能别名"的内存 op。
  ;; 同基址不同偏移 (如不同栈帧槽) 互不别名 → 可自由重排；异基址/未知 → 保守别名。
  (define mem-history '())        ; (list idx addr is-store?) 逆序 (最近在前)
  ;; NZCV 单独处理 (含 clobber 语义)：last-writer=(cons idx clobber?) 或 #f
  (define nzcv-writer #f)
  (define nzcv-readers '())       ; 自上个 writer 以来的读者 idx
  (for ([j (in-range n)])
    (define nd (vector-ref nodes j))
    ;; 一般寄存器 RAW/WAR/WAW (排除 NZCV，NZCV 单独处理)
    (for ([u (in-list (sched-node-uses nd))] #:unless (equal? u NZCV))
      (define d (hash-ref last-def u #f))
      (when d (add-edge/dedup! d j))
      (hash-update! uses-since-def u (lambda (l) (cons j l)) '()))
    (for ([w (in-list (sched-node-defs nd))] #:unless (equal? w NZCV))
      (for ([u (in-list (hash-ref uses-since-def w '()))])
        (add-edge/dedup! u j))
      (define d (hash-ref last-def w #f))
      (when d (add-edge/dedup! d j))
      (hash-set! last-def w j)
      (hash-set! uses-since-def w '()))
    ;; NZCV：读=RAW(依赖 last-writer)；真写=WAR+WAW(跳过 clobber 前驱)；
    ;; .call=clobber(dead write)=WAR(不能进位链内插) 但不给/受 WAW → 域乘可重叠。
    (define nzcv-read? (and (member NZCV (sched-node-uses nd)) #t))
    (define nzcv-write? (and (member NZCV (sched-node-defs nd)) #t))
    (define nzcv-clobber? (call-directive? (sched-node-stmt nd)))
    (when (and nzcv-read? nzcv-writer) (add-edge/dedup! (car nzcv-writer) j)) ; RAW
    (when (or nzcv-write? nzcv-clobber?)
      (for ([r (in-list nzcv-readers)]) (add-edge/dedup! r j))               ; WAR
      (when (and nzcv-write? nzcv-writer (not (cdr nzcv-writer)))
        (add-edge/dedup! (car nzcv-writer) j))                                ; WAW (非 clobber)
      (set! nzcv-writer (cons j nzcv-clobber?))
      (set! nzcv-readers '())
      (set! nzcv-write-idxs (cons j nzcv-write-idxs)))
    (when (and nzcv-read? (not nzcv-write?) (not nzcv-clobber?))
      (set! nzcv-readers (cons j nzcv-readers)))
    ;; 内存边 (别名消歧)
    (define c (sched-node-mem nd))
    (when (or (mem-reads? c) (mem-writes? c))
      (define addr (stmt-mem-addr (sched-node-stmt nd)))
      ;; load-like 依赖最近的可能别名 store
      (when (mem-reads? c)
        (let find ([h mem-history])
          (cond
            [(null? h) (void)]
            [(and (caddr (car h)) (mem-may-alias? addr (cadr (car h))))
             (add-edge/dedup! (car (car h)) j)]   ; 最近别名 store，止
            [else (find (cdr h))])))
      ;; store-like 依赖此前所有可能别名的内存 op
      (when (mem-writes? c)
        (for ([e (in-list mem-history)])
          (when (mem-may-alias? addr (cadr e))
            (add-edge/dedup! (car e) j))))
      (set! mem-history (cons (list j addr (mem-writes? c)) mem-history))))
  ;; NZCV live-out：原序最后一个 NZCV 写者 (max idx) 须仍是最后一个 → 其余写者/clobber
  ;; 都排在它之前 (否则会 clobber 掉传给后随条件分支的标志)。
  (when (and nzcv-live-out? (pair? nzcv-write-idxs))
    (define last-w (apply max nzcv-write-idxs))
    (for ([w (in-list nzcv-write-idxs)] #:unless (= w last-w))
      (add-edge/dedup! w last-w)))
  (values succs preds))

;; ============================================================
;; 关键路径高度 cp[n] = latency + max(cp[succ])
;; ============================================================
(define (critical-path-heights nodes succs)
  (define n (vector-length nodes))
  (define cp (make-vector n #f))
  (define (height i)
    (or (vector-ref cp i)
        (let ([h (+ (sched-node-latency (vector-ref nodes i))
                    (for/fold ([m 0]) ([s (in-list (vector-ref succs i))])
                      (max m (height s))))])
          (vector-set! cp i h)
          h)))
  (for ([i (in-range n)]) (height i))
  cp)

;; ============================================================
;; 列表调度 (压力感知)
;; ============================================================
;; live-in: 区段入口活跃 vreg 集合 (hash reg-id->#t)；#f 表示不估压力
(define (env-plimit)
  (define e (getenv "ASMP_SCHED_PLIMIT"))
  (if e (string->number e) 24))

(define (list-schedule-region nodes #:live-in [live-in #f]
                              #:pressure-limit [plimit (env-plimit)]
                              #:nzcv-live-out? [nzcv-live-out? #f]
                              #:identity? [identity? #f])
  (define n (vector-length nodes))
  (cond
    [(<= n 1) (for/list ([i (in-range n)]) i)]
    [(or identity? (getenv "ASMP_SCHED_IDENTITY")) (for/list ([i (in-range n)]) i)]
    [else
     (define-values (succs preds) (build-region-dag nodes #:nzcv-live-out? nzcv-live-out?))
     (define cp (critical-path-heights nodes succs))
     (define pred-count (make-vector n 0))
     (for ([i (in-range n)]) (vector-set! pred-count i (length (vector-ref preds i))))
     (define scheduled (make-vector n #f))
     ;; live 计数估计 (仅 gpr 虚拟寄存器)
     (define live (make-hash))
     (when live-in (for ([(k v) (in-hash live-in)]) (hash-set! live k #t)))
     ;; 剩余 use 计数：每个 vreg 还有多少未调度的使用 (用于判断 def 后何时死)
     (define remaining-uses (make-hash))
     (for ([i (in-range n)])
       (for ([u (in-list (sched-node-uses (vector-ref nodes i)))])
         (when (countable? u) (hash-update! remaining-uses u add1 0))))
     (define (live-count) (hash-count live))
     ;; 某节点调度后的净 live 变化估计
     (define (delta-live nd)
       (define d 0)
       ;; 新 def 加入 (若之后还有 use)
       (for ([w (in-list (sched-node-defs nd))])
         (when (and (countable? w) (not (hash-ref live w #f))
                    (> (hash-ref remaining-uses w 0) 0))
           (set! d (add1 d))))
       ;; use 若是该 vreg 最后一次使用 → 该 vreg 死
       (for ([u (in-list (sched-node-uses nd))])
         (when (and (countable? u) (= (hash-ref remaining-uses u 0) 1)
                    (hash-ref live u #f))
           (set! d (sub1 d))))
       d)
     ;; 周期感知列表调度：节点只有当其所有前驱的延迟都已流逝 (finish<=cycle)
     ;; 时才 data-ready。发射一个长延迟域乘后，其依赖后继要等 latency 个周期，
     ;; 期间独立域乘被发射 → 填满延迟阴影 → 独立乘在输出中相邻 → 乱序核重叠。
     (define finish (make-vector n 0))       ; 各节点完成周期
     (define issue-width                      ; 每周期最多发射数 (宽乱序核)
       (let ([e (getenv "ASMP_SCHED_ISSUE")])
         (if e
             (string->number e)
             (sched-model-issue-width (current-sched-model)))))
     ;; 端口感知：本周期各执行端口已发射数，推进周期时清零。
     (define ports-off? (equal? (getenv "ASMP_SCHED_PORTS") "0"))
     (define port-used (make-hash))
     (define (node-port i) (stmt-port (sched-node-stmt (vector-ref nodes i))))
     (define (port-avail? i)
       (or ports-off?
           (let ([p (node-port i)]) (< (hash-ref port-used p 0) (port-capacity p)))))
     (define result '())
     (define (schedule-node! pick cycle)
       (set! result (cons pick result))
       (vector-set! scheduled pick #t)
       (vector-set! finish pick (+ cycle (sched-node-latency (vector-ref nodes pick))))
       (define nd (vector-ref nodes pick))
       (for ([u (in-list (sched-node-uses nd))])
         (when (countable? u)
           (hash-update! remaining-uses u sub1 0)
           (when (= (hash-ref remaining-uses u 0) 0) (hash-remove! live u))))
       (for ([w (in-list (sched-node-defs nd))])
         (when (and (countable? w) (> (hash-ref remaining-uses w 0) 0))
           (hash-set! live w #t)))
       (for ([s (in-list (vector-ref succs pick))])
         (vector-set! pred-count s (sub1 (vector-ref pred-count s)))))
     (define (all-preds-scheduled? i)
       (= (vector-ref pred-count i) 0))
     (define (data-ready-cycle i)             ; 最早可发射周期 = max 前驱 finish
       (for/fold ([c 0]) ([p (in-list (vector-ref preds i))])
         (max c (vector-ref finish p))))
     (let loop ([cycle 0] [issued-this-cycle 0])
       (define pending
         (for/list ([i (in-range n)]
                    #:when (and (not (vector-ref scheduled i)) (all-preds-scheduled? i)))
           i))
       (cond
         [(null? pending) (void)]             ; 全部调度完
         [else
          (define maxdist
            (let ([e (getenv "ASMP_SCHED_MAXDIST")]) (and e (string->number e))))
          (define outpos (length result))
          (define data-ready
            (for/list ([i (in-list pending)] #:when (<= (data-ready-cycle i) cycle)) i))
          (define ready-now
            (cond
              [(not maxdist) data-ready]
              [else
               (define f (filter (lambda (i) (<= (- (sched-node-index (vector-ref nodes i)) outpos)
                                                 maxdist))
                                 data-ready))
               ;; 若限距把候选清空但仍有 data-ready，放行原序最小者 (防死锁)
               (if (null? f)
                   (if (null? data-ready) '()
                       (list (argmin (lambda (i) (sched-node-index (vector-ref nodes i))) data-ready)))
                   f)]))
          ;; 端口过滤：本周期该端口未满的候选。若数据就绪但全被端口挡住，则
          ;; 推进周期 (下个周期端口清零) —— 不会死锁。
          (define ready-port (filter port-avail? ready-now))
          (cond
            [(or (null? ready-port) (>= issued-this-cycle issue-width))
             ;; 本周期无可发射 (或已满/端口满) → 推进周期
             (define next
               (for/fold ([m #f]) ([i (in-list pending)])
                 (define d (max cycle (data-ready-cycle i)))
                 (if (or (not m) (< d m)) d m)))
             (hash-clear! port-used)
             (loop (max (add1 cycle) (or next (add1 cycle))) 0)]
            [else
             ;; 优先级模式:
             ;;  cp    (默认历史): 纯关键路径 (- cp); 仅 live>plimit 时退化到压力
             ;;  pmin  : 压力优先 (delta-live, -cp) —— 最小化跨调用活跃度
             ;;  blend : 关键路径, 但 live 逼近寄存器上限时按压力挑
             (define prio-mode (or (getenv "ASMP_SCHED_PRIO") "cp"))
             (define hi-pressure? (> (live-count) plimit))
             (define pick
               (cond
                 [(equal? prio-mode "pmin")
                  (argmin-node ready-port nodes
                               (lambda (i) (list (delta-live (vector-ref nodes i))
                                                 (- (vector-ref cp i)) i)))]
                 [(equal? prio-mode "blend")
                  ;; live 在寄存器预算内 → 关键路径; 超预算 → 压力优先
                  (if hi-pressure?
                      (argmin-node ready-port nodes
                                   (lambda (i) (list (delta-live (vector-ref nodes i))
                                                     (- (vector-ref cp i)) i)))
                      (argmin-node ready-port nodes
                                   (lambda (i) (list (- (vector-ref cp i)) i))))]
                 [hi-pressure?
                  (argmin-node ready-port nodes
                               (lambda (i) (list (delta-live (vector-ref nodes i))
                                                 (- (vector-ref cp i)) i)))]
                 [else
                  (argmin-node ready-port nodes
                               (lambda (i) (list (- (vector-ref cp i)) i)))]))
             (when (getenv "ASMP_SCHED_DEBUG")
               (when (> (live-count) (unbox *max-live*)) (set-box! *max-live* (live-count))))
             (unless ports-off? (hash-update! port-used (node-port pick) add1 0))
             (schedule-node! pick cycle)
             (loop cycle (add1 issued-this-cycle))])]))
     (when (and (getenv "ASMP_SCHED_DEBUG") (> n 20))
       (eprintf "[sched] region n=~a max-live=~a plimit=~a\n" n (unbox *max-live*) plimit))
     (define final (reverse result))
     (when (and (getenv "ASMP_SCHED_PRESSURE") (> n 6))
       (report-cross-call-pressure nodes final))
     final]))

;; 分析最终调度序: 每个 .call 处跨调用存活的 vreg 数 (= 竞争 callee-saved/溢出的值)。
;; 这是溢出的真实约束 (满 clobber 域乘处), 不同于总 live-count。
(define (report-cross-call-pressure nodes schedule)
  (define pos (make-hash))                 ; node-index -> 调度位置
  (for ([nd (in-list schedule)] [p (in-naturals)]) (hash-set! pos nd p))
  (define def-pos (make-hash))             ; vreg -> 最早 def 位置
  (define use-pos (make-hash))             ; vreg -> 最晚 use 位置
  (for ([ni (in-list schedule)] [p (in-naturals)])
    (define nd (vector-ref nodes ni))
    (for ([w (in-list (sched-node-defs nd))] #:when (countable? w))
      (hash-update! def-pos w (lambda (o) (min o p)) p))
    (for ([u (in-list (sched-node-uses nd))] #:when (countable? u))
      (hash-update! use-pos u (lambda (o) (max o p)) p)))
  (define call-positions
    (for/list ([ni (in-list schedule)] [p (in-naturals)]
               #:when (call-directive? (sched-node-stmt (vector-ref nodes ni)))) p))
  (define per-call
    (for/list ([cp (in-list call-positions)])
      (for/sum ([(v dp) (in-hash def-pos)])
        (define up (hash-ref use-pos v -1))
        (if (and (< dp cp) (> up cp)) 1 0))))
  (eprintf "[pressure] ~a calls, cross-call live per call: ~a  (max=~a)\n"
           (length call-positions) per-call
           (if (null? per-call) 0 (apply max per-call))))
(define *max-live* (box 0))

(define (countable? rid)
  (and (reg-id-virtual? rid) (eq? (reg-id-class rid) 'gpr)))

;; 取 key-list 字典序最小的节点
(define (argmin-node ready nodes key-fn)
  (for/fold ([best #f] [best-key #f] #:result best)
            ([i (in-list ready)])
    (define k (key-fn i))
    (if (or (not best) (list<? k best-key))
        (values i k)
        (values best best-key))))
(define (list<? a b)
  (cond [(null? a) #f] [(null? b) #f]
        [(< (car a) (car b)) #t] [(> (car a) (car b)) #f]
        [else (list<? (cdr a) (cdr b))]))

;; ============================================================
;; 区段切分 (基本块 → 屏障分隔的可调度区段)
;; ============================================================
;; 返回 (listof (cons 'sched (vectorof stmt)) | (cons 'barrier stmt))，保持原序
(define (split-regions instrs)
  (define regions '())
  (define cur '())
  (define (flush!)
    (unless (null? cur)
      (set! regions (cons (cons 'sched (list->vector (reverse cur))) regions))
      (set! cur '())))
  (for ([s (in-pvector instrs)])
    (if (barrier? s)
        (begin (flush!) (set! regions (cons (cons 'barrier s) regions)))
        (set! cur (cons s cur))))
  (flush!)
  (reverse regions))

;; ============================================================
;; 主入口
;; ============================================================
;; 计算各函数是否"内存纯"(无 load/store、无裸 bl/blr、所调用者全纯)。
;; 纯函数的 .call 不引内存定序边 → 域乘可自由重排。
(define (compute-pure-callees functions-omap)
  (define pure (make-hash))
  ;; 初值：本体无访存 & 无裸调用
  (define callees-of (make-hash))
  (for ([kv (in-intmap-pairs functions-omap)])
    (define fn (cdr kv))
    (define name (asm-function-name fn))
    (define calls '())
    (define local-pure #t)
    (fn-for-each-block fn
      (lambda (block)
        (for ([s (in-pvector (basic-block-instructions block))])
          (cond
            [(call-directive? s) (set! calls (cons (ast-directive-name s) calls))]
            [(ast-ins? s)
             (define m (ast-ins-mnemonic s))
             (when (or (memq m LOAD-MNEMONICS) (memq m STORE-MNEMONICS)
                       (memq m '(bl blr)))
               (set! local-pure #f))]
            [else (void)]))))
    (hash-set! pure name local-pure)
    (hash-set! callees-of name calls))
  ;; 不动点：若调用了不纯者 → 不纯
  (let loop ()
    (define changed #f)
    (for ([(name calls) (in-hash callees-of)])
      (when (hash-ref pure name #f)
        (for ([c (in-list calls)])
          (unless (hash-ref pure c #f)     ; 未知目标视为不纯
            (when (hash-ref pure name #f)
              (hash-set! pure name #f) (set! changed #t))))))
    (when changed (loop)))
  pure)

;; 关键路径感知溢出：对每个虚拟 gpr 算"临界度"= 使用它的节点的最大关键路径高度
;; (下游延迟加权链长)。临界度高 = 溢出它会给关键路径加 reload 延迟 → 应尽量不溢出。
;; 利用 asmp 的动态依赖分析 (人手工凭直觉做的事)。返回 hash[reg-id -> number]。
(define (compute-criticality-map fn callee-params [pure-callees (hash)])
  (define crit (make-hash))
  (fn-for-each-block fn
    (lambda (block)
      (for ([r (in-list (split-regions (basic-block-instructions block)))]
            #:when (eq? (car r) 'sched))
        (define stmts (cdr r))
        (when (> (vector-length stmts) 1)
          (define nodes
            (for/vector ([s (in-vector stmts)] [i (in-naturals)])
              (define ud (stmt-use-def s callee-params))
              (sched-node i s (car ud) (cdr ud) (stmt-latency s)
                          (stmt-mem-class s pure-callees))))
          (define-values (succs preds) (build-region-dag nodes))
          (define cp (critical-path-heights nodes succs))
          (for ([i (in-range (vector-length nodes))])
            (for ([u (in-list (sched-node-uses (vector-ref nodes i)))])
              (when (and (reg-id-virtual? u) (eq? (reg-id-class u) 'gpr))
                (hash-update! crit u (lambda (m) (max m (vector-ref cp i))) 0))))))))
  crit)

(define (schedule-function fn callee-params
                           #:pure-callees [pure-callees (hash)]
                           #:identity? [identity? #f])
  (if (not (*enable-scheduler*))
      fn
      (let ([new-blocks
             (for/fold ([blocks (asm-function-blocks fn)])
                       ([kv (in-intmap-pairs (asm-function-blocks fn))])
               (define bb-key (car kv))
               (define block (cdr kv))
               (intmap-set blocks bb-key
                           (schedule-block block callee-params pure-callees identity?)))])
        (struct-copy asm-function fn [blocks new-blocks]))))

;; 后随屏障是否读 NZCV (条件分支 b.<cond>) → 本区段 NZCV 活跃出口
(define (barrier-reads-flags? s)
  (and (ast-ins? s)
       (eq? (ast-ins-mnemonic s) 'b)
       (ast-ins-suffix s)))

(define (schedule-block block callee-params pure-callees identity?)
  (define instrs (basic-block-instructions block))
  (define regions (list->vector (split-regions instrs)))
  (define nr (vector-length regions))
  (define new-instrs
    (for/fold ([acc (pvector-empty)]) ([ri (in-range nr)])
      (define r (vector-ref regions ri))
      (case (car r)
        [(barrier) (pvector-cons-right acc (cdr r))]
        [(sched)
         (define stmts (cdr r))
         ;; 下一个元素是屏障；若其读标志 → NZCV 活跃出口，末位 NZCV 写须保持
         (define nzcv-lo?
           (and (< (add1 ri) nr)
                (eq? (car (vector-ref regions (add1 ri))) 'barrier)
                (barrier-reads-flags? (cdr (vector-ref regions (add1 ri))))))
         (define nodes
           (for/vector ([s (in-vector stmts)] [i (in-naturals)])
             (define ud (stmt-use-def s callee-params))
             (sched-node i s (car ud) (cdr ud) (stmt-latency s)
                         (stmt-mem-class s pure-callees))))
         (define order (list-schedule-region nodes #:identity? identity?
                                             #:nzcv-live-out? nzcv-lo?))
         (for/fold ([a acc]) ([idx (in-list order)])
           (pvector-cons-right a (sched-node-stmt (vector-ref nodes idx))))])))
  (struct-copy basic-block block [instructions new-instrs]))
