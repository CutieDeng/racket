#lang racket/base

;; benchmark/omap-dispatch-bench.rkt — comparator 动态分派税测量
;;
;; 目的: 为 cp0 "已知闭包递归克隆特化"(SpecConstr 类) 立项建立证据基础。
;; 按本项目"先测量后动手"纪律 (同 D1/D2): 在真实 CS/Chez 硬件上量化
;; 泛型比较器 (闭包过 struct 字段, 每节点未知调用) vs 宏单态化 omap
;; (比较器展开期内联) 的实际差距, 决定该编译器 pass 值不值得做。
;;
;; 三个变体, 同一 workload (N 次 set + M 次 ref, 同一 WBT 算法):
;;   dyn   — 比较器作 struct 字段的运行时闭包, 每节点未知调用 (SpecConstr
;;           将要优化掉的形态; 等价于原 vendor ordered-map 的分派模式)
;;   mono  — racket/omap 宏单态化 (比较器展开期内联; SpecConstr 的目标下界)
;;   intmap— core radix intmap (零比较器, 结构性上界参考)
;;
;; 用法: racket benchmark/omap-dispatch-bench.rkt [N] [trials]
;; 输出: 各变体 ops/sec + mono/dyn 加速比 = SpecConstr 可回收的税。

(require racket/fixnum
         racket/omap
         (file "../../../collects/racket/compare.rkt")
         racket/intmap)

;; ---- 变体 1: dyn — 运行时闭包比较器 (SpecConstr 靶子) ----
;; 与 mono 逐字对应的 WBT, 唯一区别: cmp 是运行时传入、存进节点闭包不可见的值。
;; 用 struct 承载 cmp 模拟"比较器藏在 map 对象字段里、cp0 看不见"的分派。

(struct dnode (k v l r sz) #:transparent)
(struct dmap (cmp root))

(define (dmap-empty cmp) (dmap cmp #f))
(define (dsize t) (if t (dnode-sz t) 0))
(define (dmk k v l r) (dnode k v l r (+ 1 (dsize l) (dsize r))))

(define (dbal k v l r)
  (define ls (dsize l)) (define rs (dsize r))
  (cond
    [(<= (+ ls rs) 1) (dmk k v l r)]
    [(> rs (* 3 ls))
     (define rl (dnode-l r)) (define rr (dnode-r r))
     (if (< (dsize rl) (* 2 (dsize rr)))
         (dmk (dnode-k r) (dnode-v r) (dmk k v l rl) rr)
         (dmk (dnode-k rl) (dnode-v rl)
              (dmk k v l (dnode-l rl))
              (dmk (dnode-k r) (dnode-v r) (dnode-r rl) rr)))]
    [(> ls (* 3 rs))
     (define ll (dnode-l l)) (define lr (dnode-r l))
     (if (< (dsize lr) (* 2 (dsize ll)))
         (dmk (dnode-k l) (dnode-v l) ll (dmk k v lr r))
         (dmk (dnode-k lr) (dnode-v lr)
              (dmk (dnode-k l) (dnode-v l) ll (dnode-l lr))
              (dmk k v (dnode-r lr) r)))]
    [else (dmk k v l r)]))

;; 关键: cmp 作为参数穿过递归 — cp0 不克隆递归过程故每层是未知调用
(define (dset* cmp t k v)
  (if (not t)
      (dmk k v #f #f)
      (case (cmp k (dnode-k t))
        [(<) (dbal (dnode-k t) (dnode-v t) (dset* cmp (dnode-l t) k v) (dnode-r t))]
        [(>) (dbal (dnode-k t) (dnode-v t) (dnode-l t) (dset* cmp (dnode-r t) k v))]
        [else (dmk k v (dnode-l t) (dnode-r t))])))

(define (dref* cmp t k)
  (let loop ([t t])
    (if (not t)
        #f
        (case (cmp k (dnode-k t))
          [(<) (loop (dnode-l t))]
          [(>) (loop (dnode-r t))]
          [else (dnode-v t)]))))

(define (dmap-set m k v) (dmap (dmap-cmp m) (dset* (dmap-cmp m) (dmap-root m) k v)))
(define (dmap-ref m k) (dref* (dmap-cmp m) (dmap-root m) k))

;; 比较器候选表 + 运行时选取: 保证 cp0 证明性看不见具体是哪个 (否则
;; 它可能把字面 lambda 内联进 dref*, 使 dyn≈mono 而测量失真)。
(define cmp-table
  (vector (lambda (a b) (cond [(fx< a b) '<] [(fx> a b) '>] [else '=]))
          (lambda (a b) (cond [(fx> a b) '<] [(fx< a b) '>] [else '=]))))  ; 反序(未用)
(define (opaque-cmp sel) (vector-ref cmp-table sel))

;; ---- 变体 2: mono — 宏单态化 ----
(define-omap mono #:key-compare fx-compare)

;; ---- workload ----
;; 确定性伪随机键序 (LCG), 三变体喂完全相同的序列。

(define (lcg x) (fxand (fx+ (fx* x 1103515245) 12345) #xFFFFFF))

(define (build-keys n)
  (define v (make-fxvector n))
  (let loop ([i 0] [s 7])
    (when (fx< i n)
      (define s2 (lcg s))
      (fxvector-set! v i (fxand s2 #xFFFF))
      (loop (fx+ i 1) s2)))
  v)

;; sel = 运行时选出的比较器索引 (来自命令行, cp0 不可知)。
;; build 阶段返回预建 map, ref 阶段在预建 map 上纯查找 (无分配, 隔离分派)。

(define (build-dyn keys n sel)
  (define m0 (dmap-empty (opaque-cmp sel)))
  (for/fold ([m m0]) ([i (in-range n)]) (dmap-set m (fxvector-ref keys i) i)))
(define (ref-dyn m keys n)
  (for/fold ([acc 0]) ([i (in-range n)])
    (if (dmap-ref m (fxvector-ref keys i)) (fx+ acc 1) acc)))

(define (build-mono keys n)
  (for/fold ([m mono-empty]) ([i (in-range n)]) (mono-set m (fxvector-ref keys i) i)))
(define (ref-mono m keys n)
  (for/fold ([acc 0]) ([i (in-range n)])
    (if (mono-ref m (fxvector-ref keys i) #f) (fx+ acc 1) acc)))

(define (build-intmap keys n)
  (for/fold ([m intmap-empty]) ([i (in-range n)]) (intmap-set m (fxvector-ref keys i) i)))
(define (ref-intmap m keys n)
  (for/fold ([acc 0]) ([i (in-range n)])
    (if (intmap-ref m (fxvector-ref keys i) #f) (fx+ acc 1) acc)))

;; ---- 计时 (取多轮最优, 抗噪声) ----

(define (best-ms thunk trials)
  (for/fold ([best +inf.0]) ([_ (in-range trials)])
    (define t0 (current-inexact-milliseconds))
    (thunk)
    (min best (- (current-inexact-milliseconds) t0))))

(module+ main
  (define argv (current-command-line-arguments))
  (define N (if (> (vector-length argv) 0) (string->number (vector-ref argv 0)) 20000))
  (define trials (if (> (vector-length argv) 1) (string->number (vector-ref argv 1)) 15))
  (define sel (modulo (string-length (or (getenv "PWD") "x")) 1)) ; =0, 但 cp0 证明性不可知
  (define reps 30)
  (define keys (build-keys N))

  (define md (build-dyn keys N sel))
  (define mm (build-mono keys N))
  (define mi (build-intmap keys N))
  (unless (= (ref-dyn md keys N) (ref-mono mm keys N) (ref-intmap mi keys N))
    (error 'bench "variants disagree"))

  (define (bench thunk) (best-ms (lambda () (for ([_ (in-range reps)]) (thunk))) trials))

  ;; build 相 (含分配) 与 ref 相 (纯查找, 隔离分派) 分开计时
  (define bd (bench (lambda () (build-dyn keys N sel))))
  (define bm (bench (lambda () (build-mono keys N))))
  (define bi (bench (lambda () (build-intmap keys N))))
  (define rd (bench (lambda () (ref-dyn md keys N))))
  (define rm (bench (lambda () (ref-mono mm keys N))))
  (define ri (bench (lambda () (ref-intmap mi keys N))))

  (printf "comparator dispatch tax (N=~a, ~a reps × ~a trials, CS/Chez)\n" N reps trials)
  (printf "比较器运行时选取 (cp0 证明性不可知), build 含分配 / ref 纯查找隔离分派\n")
  (printf "~a\n" (make-string 60 #\-))
  (printf "            build ms    ref ms    ref Mlookup/s\n")
  (printf "  dyn       ~a\t~a\t~a\n" (rnd bd) (rnd rd) (rnd (/ (* N reps 1e-3) rd)))
  (printf "  mono      ~a\t~a\t~a\n" (rnd bm) (rnd rm) (rnd (/ (* N reps 1e-3) rm)))
  (printf "  intmap    ~a\t~a\t~a\n" (rnd bi) (rnd ri) (rnd (/ (* N reps 1e-3) ri)))
  (printf "~a\n" (make-string 60 #\-))
  (printf "  ref  mono/dyn = ~ax   ← SpecConstr 可回收的分派税 (隔离后)\n" (rnd (/ rd rm)))
  (printf "  build mono/dyn = ~ax  ← 含分配时的税 (被分配摊薄)\n" (rnd (/ bd bm)))
  (printf "  ref  intmap/mono = ~ax ← radix vs 比较树 (SpecConstr 够不到)\n" (rnd (/ rm ri))))

(define (rnd x) (/ (round (* x 100)) 100.0))
