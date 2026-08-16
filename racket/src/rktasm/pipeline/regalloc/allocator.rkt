#lang racket

;; ============================================================
;; pipeline/regalloc/allocator.rkt - 图着色寄存器分配
;; ============================================================
;;
;; Chaitin-Briggs 算法（适配 class-ig 单类干涉图）

(require "../../semantic/control-flow.rkt"
         "../../parser/ast.rkt"
         "liveness.rkt"
         "interference.rkt"
         "types.rkt"
         "abi.rkt"
         racket/pvector
         racket/intbits)

(provide
  (struct-out alloc-result)
  (struct-out spill-slot)
  (struct-out multi-alloc-result)
  allocate-registers         ; 单类分配
  allocate-all-registers     ; 多类分配
  merge-alloc-results
  format-alloc-result
  format-multi-alloc-result
  *trace-allocator*          ; 性能追踪开关
  *spill-cost-map*           ; 溢出代价映射参数
  *clobber-union-map*        ; 跨调用 clobber 并集 (clobber-aware 分配)
  *criticality-map*)         ; 关键路径临界度 (critical-path-aware 溢出)

;; ============================================================
;; 数据结构
;; ============================================================

(struct alloc-result (assignment spilled coalesced) #:transparent)
(struct spill-slot (offset size reg) #:transparent)

;; 多类分配结果
(struct multi-alloc-result
  (gpr             ; alloc-result | #f
   fpr             ; alloc-result | #f
   pred)           ; alloc-result | #f
  #:transparent)

(struct allocator-state
  (ig precolored simplify-worklist freeze-worklist spill-worklist
   spilled-nodes coalesced-nodes colored-nodes select-stack
   select-stack-set  ;; 新增：intbits 快速查找栈中元素
   coalesce-map color-map degree move-list worklist-moves
   active-moves coalesced-moves frozen-moves constrained-moves
   index-reg reg-index k
   abi)  ;; 新增：ABI 配置
  #:transparent)

;; ============================================================
;; 主函数
;; ============================================================

;; 性能追踪参数
(define *trace-allocator* (make-parameter #f))

;; 溢出代价映射：reg-om[reg-id -> number]
;; 值越大表示溢出代价越高（应优先保留在寄存器中）
;; 如果为 #f，使用纯度数策略（原始行为）
(define *spill-cost-map* (make-parameter #f))

;; 跨调用 clobber 并集：reg-om[reg-id -> phys-gpr-intbits]
;; 对跨调用存活的虚拟寄存器，只排除被实际 clobber 的物理寄存器 (而非全部
;; caller-saved)。#f 时退回保守行为 (跨调用值只用 callee-saved)。
(define *clobber-union-map* (make-parameter #f))

;; 关键路径临界度：hash[reg-id -> number]。select-spill 用它优先溢出低临界度
;; (远离关键路径) 的值 —— 溢出关键路径值会给关键路径加 reload 延迟。#f 时忽略。
(define *criticality-map* (make-parameter #f))

;; 分配单类干涉图
(define (allocate-registers ig #:abi [abi arm64-abi])
  (define trace? (*trace-allocator*))
  (define t0 (if trace? (current-inexact-milliseconds) 0))

  (define state (initialize-allocator ig abi))

  (define t1 (if trace? (current-inexact-milliseconds) 0))

  (define simplify-count 0)
  (define coalesce-count 0)
  (define freeze-count 0)
  (define spill-count 0)

  (define final-state
    (let loop ([state state])
      (cond
        [(not (intbits-empty? (allocator-state-simplify-worklist state)))
         (set! simplify-count (add1 simplify-count))
         (loop (simplify state))]
        [(not (null? (allocator-state-worklist-moves state)))
         (set! coalesce-count (add1 coalesce-count))
         (loop (coalesce state))]
        [(not (intbits-empty? (allocator-state-freeze-worklist state)))
         (set! freeze-count (add1 freeze-count))
         (loop (freeze state))]
        [(not (intbits-empty? (allocator-state-spill-worklist state)))
         (set! spill-count (add1 spill-count))
         (loop (select-spill state))]
        [else state])))

  (define t2 (if trace? (current-inexact-milliseconds) 0))

  (define colored-state (assign-colors final-state abi))

  (define t3 (if trace? (current-inexact-milliseconds) 0))

  (when trace?
    (printf "    [allocator] 初始化: ~a ms\n" (- t1 t0))
    (printf "    [allocator] 主循环: ~a ms (simplify=~a, coalesce=~a, freeze=~a, spill=~a)\n"
            (- t2 t1) simplify-count coalesce-count freeze-count spill-count)
    (printf "    [allocator] 着色:   ~a ms\n" (- t3 t2)))

  (build-alloc-result colored-state))

;; 分配多类干涉图（并行友好）
(define (allocate-all-registers mig #:abi [abi arm64-abi])
  (define gpr-result
    (and (mig-gpr mig)
         (allocate-registers (mig-gpr mig) #:abi abi)))
  (define fpr-result
    (and (mig-fpr mig)
         (allocate-registers (mig-fpr mig) #:abi abi)))
  (define pred-result
    (and (mig-pred mig)
         (allocate-registers (mig-pred mig) #:abi abi)))
  (multi-alloc-result gpr-result fpr-result pred-result))

;; 合并多类结果为单个 alloc-result
(define (merge-alloc-results mar)
  (define assignment
    (for*/fold ([m reg-om-empty])
               ([result (in-list (filter values
                                          (list (multi-alloc-result-gpr mar)
                                                (multi-alloc-result-fpr mar)
                                                (multi-alloc-result-pred mar))))]
                [kv (in-reg-om (alloc-result-assignment result))])
      (reg-om-set m (car kv) (cdr kv))))

  (define spilled
    (for*/fold ([pv (pvector-empty)])
               ([result (in-list (filter values
                                          (list (multi-alloc-result-gpr mar)
                                                (multi-alloc-result-fpr mar)
                                                (multi-alloc-result-pred mar))))]
                [reg (in-pvector (alloc-result-spilled result))])
      (pvector-cons-right pv reg)))

  (define coalesced
    (for*/fold ([m reg-om-empty])
               ([result (in-list (filter values
                                          (list (multi-alloc-result-gpr mar)
                                                (multi-alloc-result-fpr mar)
                                                (multi-alloc-result-pred mar))))]
                [kv (in-reg-om (alloc-result-coalesced result))])
      (reg-om-set m (car kv) (cdr kv))))

  (alloc-result assignment spilled coalesced))

;; ============================================================
;; 初始化
;; ============================================================

(define (initialize-allocator ig abi)
  (define k (class-ig-num-colors ig))
  (define class (class-ig-class ig))

  ;; 使用 class-ig-index-reg (pvector) 和 class-ig-reg-index (reg-om)
  (define index-reg (class-ig-index-reg ig))  ;; pvector: idx -> reg
  (define reg-index (class-ig-reg-index ig))  ;; reg-om: reg -> idx
  (define n (pvector-length index-reg))

  (define-values (degree pre simp freeze spill)
    (for/fold ([deg reg-om-empty]
               [pre intbits-empty]
               [simp intbits-empty]
               [freeze intbits-empty]
               [spill intbits-empty])
              ([i (in-range n)])
      (define reg (pvector-ref index-reg i))
      (define d (ig-degree ig reg))
      (define new-deg (reg-om-set deg reg d))
      (cond
        [(reg-id-physical? reg)
         (values new-deg (intbits-set pre i) simp freeze spill)]
        [(>= d k)
         (values new-deg pre simp freeze (intbits-set spill i))]
        [(ig-move-related? ig reg)
         (values new-deg pre simp (intbits-set freeze i) spill)]
        [else
         (values new-deg pre (intbits-set simp i) freeze spill)])))

  (define initial-colors
    (for/fold ([m reg-om-empty])
              ([i (in-range n)])
      (define reg (pvector-ref index-reg i))
      (if (reg-id-physical? reg)
          (let ([color (abi-reg->color abi (reg-id-class reg) (reg-id-id reg))])
            (if color
                (reg-om-set m reg color)
                m))
          m)))

  (define-values (move-list worklist-moves)
    (let ([ml reg-om-empty] [wl '()])
      (for ([edge (in-pvector (class-ig-move-edges ig))])
        (define src (move-edge-src edge))
        (define dst (move-edge-dst edge))
        (set! ml (reg-om-set ml src (cons edge (reg-om-ref ml src '()))))
        (set! ml (reg-om-set ml dst (cons edge (reg-om-ref ml dst '()))))
        (set! wl (cons edge wl)))
      (values ml wl)))

  (allocator-state ig pre simp freeze spill
                   intbits-empty intbits-empty intbits-empty '()
                   intbits-empty  ;; select-stack-set (空)
                   reg-om-empty initial-colors
                   degree move-list worklist-moves
                   '() '() '() '()
                   index-reg reg-index k
                   abi))

;; ============================================================
;; Simplify
;; ============================================================

(define (simplify state)
  (define worklist (allocator-state-simplify-worklist state))
  (define i (intbits-first worklist))
  (define reg (pvector-ref (allocator-state-index-reg state) i))
  (define new-simplify (intbits-clear worklist i))
  (define new-stack (cons reg (allocator-state-select-stack state)))
  (define new-stack-set (intbits-set (allocator-state-select-stack-set state) i))
  (decrement-degree state reg i new-simplify new-stack new-stack-set))

(define (decrement-degree state removed-reg removed-idx new-simplify new-stack new-stack-set)
  (define ig (allocator-state-ig state))
  (define reg-index (allocator-state-reg-index state))
  (define k (allocator-state-k state))
  ;; 使用 intbits 直接获取邻居索引
  (define neighbor-set (ig-neighbors/intbits ig removed-reg))

  (for/fold ([st (struct-copy allocator-state state
                              [simplify-worklist new-simplify]
                              [select-stack new-stack]
                              [select-stack-set new-stack-set])])
            ([ni (in-intbits neighbor-set)])
    ;; 使用 intbits 快速检查
    (if (or (intbits-ref (allocator-state-precolored st) ni)
            (intbits-ref (allocator-state-coalesced-nodes st) ni)
            (intbits-ref (allocator-state-select-stack-set st) ni))
        st
        (let* ([neighbor (pvector-ref (allocator-state-index-reg st) ni)]
               [old-degree (reg-om-ref (allocator-state-degree st) neighbor 0)]
               [new-degree (max 0 (sub1 old-degree))]
               [st1 (struct-copy allocator-state st
                                 [degree (reg-om-set (allocator-state-degree st) neighbor new-degree)])])
          (if (and (= old-degree k) (< new-degree k))
              (let ([st2 (struct-copy allocator-state st1
                                      [spill-worklist (intbits-clear (allocator-state-spill-worklist st1) ni)])])
                (if (ig-move-related? ig neighbor)
                    (struct-copy allocator-state st2
                                 [freeze-worklist (intbits-set (allocator-state-freeze-worklist st2) ni)])
                    (struct-copy allocator-state st2
                                 [simplify-worklist (intbits-set (allocator-state-simplify-worklist st2) ni)])))
              st1)))))

;; ============================================================
;; Coalesce
;; ============================================================

(define (coalesce state)
  (define moves (allocator-state-worklist-moves state))
  (define move (car moves))
  (define rest-moves (cdr moves))

  (define src (get-alias state (move-edge-src move)))
  (define dst (get-alias state (move-edge-dst move)))

  (define-values (u v)
    (let ([src-idx (reg-om-ref (allocator-state-reg-index state) src #f)]
          [dst-idx (reg-om-ref (allocator-state-reg-index state) dst #f)])
      (if (and src-idx (intbits-ref (allocator-state-precolored state) src-idx))
          (values src dst)
          (values dst src))))

  (define st1 (struct-copy allocator-state state [worklist-moves rest-moves]))

  (cond
    [(equal? u v)
     (add-worklist (struct-copy allocator-state st1
                                [coalesced-moves (cons move (allocator-state-coalesced-moves st1))]) u)]
    [(or (let ([vi (reg-om-ref (allocator-state-reg-index st1) v #f)])
           (and vi (intbits-ref (allocator-state-precolored st1) vi)))
         (effective-interferes? st1 u v))
     (let ([st2 (struct-copy allocator-state st1
                             [constrained-moves (cons move (allocator-state-constrained-moves st1))])])
       (add-worklist (add-worklist st2 u) v))]
    [(can-coalesce? st1 u v)
     (combine st1 u v move)]
    [else
     (struct-copy allocator-state st1
                  [active-moves (cons move (allocator-state-active-moves st1))])]))

(define (get-alias state reg)
  (define idx (reg-om-ref (allocator-state-reg-index state) reg #f))
  (if (and idx (intbits-ref (allocator-state-coalesced-nodes state) idx))
      (get-alias state (reg-om-ref (allocator-state-coalesce-map state) reg reg))
      reg))

(define (alias-class-members state reg)
  (define rep (get-alias state reg))
  (define index-reg (allocator-state-index-reg state))
  (for/list ([i (in-range (pvector-length index-reg))]
             #:when (equal? (get-alias state (pvector-ref index-reg i)) rep))
    (pvector-ref index-reg i)))

(define (effective-neighbors state reg)
  (define ig (allocator-state-ig state))
  (define rep (get-alias state reg))
  (remove-duplicates
   (filter
    (lambda (neighbor)
      (not (equal? (get-alias state neighbor) rep)))
    (apply append
           (for/list ([member (in-list (alias-class-members state reg))])
             (ig-neighbors ig member))))))

(define (effective-interferes? state a b)
  (define b-rep (get-alias state b))
  (for/or ([neighbor (in-list (effective-neighbors state a))])
    (equal? (get-alias state neighbor) b-rep)))

(define (effective-live-across-call? state reg)
  (define ig (allocator-state-ig state))
  (define reg-index (allocator-state-reg-index state))
  (for/or ([member (in-list (alias-class-members state reg))])
    (define idx (reg-om-ref reg-index member #f))
    (and idx (ig-live-across-call? ig idx))))

;; 跨调用 clobber 并集（合并别名类各成员）。
;; 返回 phys-gpr-intbits；无映射/非 gpr/空集 时返回 #f (退回保守 callee-saved)。
(define (effective-clobber-union state reg)
  (define m (and (not (getenv "ASMP_NO_CLOB")) (*clobber-union-map*)))
  (and m
       (eq? (reg-id-class reg) 'gpr)
       (let ([cu (for/fold ([acc intbits-empty])
                           ([member (in-list (alias-class-members state reg))])
                   (define c (reg-om-ref m member #f))
                   (if c (intbits-union acc c) acc))])
         (and (not (intbits-empty? cu)) cu))))

;; 跨调用值的合法颜色 = allocatable − clobber-phys (clobber 已含 lr，见
;; call-target-clobber-gpr)。故跨调用值绝不会落在被 clobber 的 caller-saved
;; 或 lr 上；fp 未被 clobber 但作为帧基址全程存活，由干涉图排除。
(define (compute-colors-excluding-phys abi class clobber-phys)
  (define cfg (abi-get-class-config abi class))
  (if cfg
      (for/intbits ([color (in-naturals)]
                   [phys (in-intbits (reg-allocatable cfg))]
                   #:unless (intbits-ref clobber-phys phys))
        color)
      #f))

(define (can-coalesce? state u v)
  (define ig (allocator-state-ig state))
  (define reg-index (allocator-state-reg-index state))
  (define k (allocator-state-k state))
  (define ui (reg-om-ref reg-index u #f))
  (define vi (reg-om-ref reg-index v #f))
  (define abi (allocator-state-abi state))

  ;; 检查 live-across-call 与 caller-saved 的冲突
  ;; 如果 v 是 live-across-call 的虚拟寄存器，u 是 caller-saved 物理寄存器，禁止合并
  (define (violates-live-across-call? phys-reg virt-reg virt-idx)
    (and virt-idx
         (effective-live-across-call? state virt-reg)
         (reg-id-physical? phys-reg)
         ;; clobber-aware：禁止合并进被 clobber 的物理寄存器 (含 lr)；
         ;; 被调方保留的 caller-saved / callee-saved 允许承载跨调用值。
         (let ([cu (effective-clobber-union state virt-reg)])
           (if cu
               (intbits-ref cu (reg-id-id phys-reg))
               (not (is-callee-saved-physical? phys-reg abi))))))

  (define (precolored-reg? reg)
    (define idx (reg-om-ref reg-index reg #f))
    (and idx (intbits-ref (allocator-state-precolored state) idx)))

  (define (uncolored-physical? reg)
    (and (reg-id-physical? reg)
         (not (abi-reg->color abi (reg-id-class reg) (reg-id-id reg)))))

  (define (precolored-neighbor-ok? neighbor precolored-reg)
    (define alias (get-alias state neighbor))
    (define degree (reg-om-ref (allocator-state-degree state) neighbor 0))
    (and (not (equal? alias precolored-reg))
         (or (effective-interferes? state alias precolored-reg)
             (precolored-reg? alias)
             (< degree k))))

  (cond
    ;; 如果合并会导致 live-across-call 的虚拟寄存器被分配到 caller-saved，禁止
    [(and ui (intbits-ref (allocator-state-precolored state) ui))
     (cond
       ;; Reserved physical registers (for example x16/x17 rewrite temps) do
       ;; not have allocator colors, so a virtual value must not coalesce into
       ;; them and become live across later rewrite-time scratch use.
       [(and vi
             (not (intbits-ref (allocator-state-precolored state) vi))
             (uncolored-physical? u))
        #f]
       ;; u 是预着色（物理），v 是虚拟
       [(and vi (not (intbits-ref (allocator-state-precolored state) vi))
             (violates-live-across-call? u v vi))
        #f]
       [else
        (for/and ([t (in-list (effective-neighbors state v))])
          (precolored-neighbor-ok? t u))])]
    ;; v 是预着色（物理），u 是虚拟
    [(and vi (intbits-ref (allocator-state-precolored state) vi))
     (cond
       [(and ui
             (not (intbits-ref (allocator-state-precolored state) ui))
             (uncolored-physical? v))
        #f]
       [(and ui (not (intbits-ref (allocator-state-precolored state) ui))
             (violates-live-across-call? v u ui))
        #f]
       [else
        (for/and ([t (in-list (effective-neighbors state u))])
          (precolored-neighbor-ok? t v))])]
    [else
     (define combined
       (remove-duplicates
        (append (effective-neighbors state u)
                (effective-neighbors state v))))
     (define high-deg (for/sum ([n (in-list combined)])
                       (if (>= (reg-om-ref (allocator-state-degree state) n 0) k) 1 0)))
     (< high-deg k)]))

;; 检查物理寄存器是否是 callee-saved (根据 ABI 配置)
(define (is-callee-saved-physical? reg abi)
  (and (reg-id-physical? reg)
       (let* ([class (reg-id-class reg)]
              [cfg (abi-get-class-config abi class)]
              [callee-saved (and cfg (reg-callee-saved cfg))])
         (and callee-saved
              (intbits-ref callee-saved (reg-id-id reg))))))

(define (combine state u v move)
  (define reg-index (allocator-state-reg-index state))
  (define vi (reg-om-ref reg-index v #f))

  (define st1
    (struct-copy allocator-state state
                 [freeze-worklist (if vi (intbits-clear (allocator-state-freeze-worklist state) vi)
                                      (allocator-state-freeze-worklist state))]
                 [spill-worklist (if vi (intbits-clear (allocator-state-spill-worklist state) vi)
                                     (allocator-state-spill-worklist state))]))

  (define st2
    (struct-copy allocator-state st1
                 [coalesced-nodes (if vi (intbits-set (allocator-state-coalesced-nodes st1) vi)
                                      (allocator-state-coalesced-nodes st1))]
                 [coalesce-map (reg-om-set (allocator-state-coalesce-map st1) v u)]
                 [coalesced-moves (cons move (allocator-state-coalesced-moves st1))]))

  (define v-moves (reg-om-ref (allocator-state-move-list st2) v '()))
  (define u-moves (reg-om-ref (allocator-state-move-list st2) u '()))
  (define st3
    (struct-copy allocator-state st2
                 [move-list (reg-om-set (allocator-state-move-list st2) u (append u-moves v-moves))]))

  (add-worklist st3 u))

(define (add-worklist state reg)
  (define reg-index (allocator-state-reg-index state))
  (define idx (reg-om-ref reg-index reg #f))
  (define k (allocator-state-k state))

  (if (and idx
           (not (intbits-ref (allocator-state-precolored state) idx))
           (not (ig-move-related? (allocator-state-ig state) reg))
           (< (reg-om-ref (allocator-state-degree state) reg 0) k))
      (struct-copy allocator-state state
                   [freeze-worklist (intbits-clear (allocator-state-freeze-worklist state) idx)]
                   [simplify-worklist (intbits-set (allocator-state-simplify-worklist state) idx)])
      state))

;; ============================================================
;; Freeze
;; ============================================================

(define (freeze state)
  (define worklist (allocator-state-freeze-worklist state))
  (define i (intbits-first worklist))
  (define reg (pvector-ref (allocator-state-index-reg state) i))

  (struct-copy allocator-state state
               [freeze-worklist (intbits-clear worklist i)]
               [simplify-worklist (intbits-set (allocator-state-simplify-worklist state) i)]
               [frozen-moves (append (reg-om-ref (allocator-state-move-list state) reg '())
                                     (allocator-state-frozen-moves state))]))

;; ============================================================
;; Select Spill
;; ============================================================

(define (select-spill state)
  (define worklist (allocator-state-spill-worklist state))
  (define cost-map (*spill-cost-map*))
  (define crit-map (*criticality-map*))
  (define best-idx -1)
  (define best-priority -inf.0)

  ;; 选择 spill priority 最高的变量溢出
  ;; priority = degree / (cost × (1 + criticality))
  ;; 度数高、使用代价低、且远离关键路径 = 最佳溢出候选。
  ;; 关键路径感知：临界度高的值 (溢出会给关键路径加 reload 延迟) priority 被压低,
  ;; 从而优先溢出远离关键路径的值，让关键链留在寄存器里 —— 利用依赖图动态分析
  ;; 做人手工凭直觉做的溢出取舍。
  (define crit-w
    (let ([e (getenv "ASMP_CRIT_WEIGHT")]) (if e (string->number e) 1.0)))
  (for ([i (in-intbits worklist)])
    (define reg (pvector-ref (allocator-state-index-reg state) i))
    (define degree (reg-om-ref (allocator-state-degree state) reg 0))
    (define cost (if cost-map (reg-om-ref cost-map reg 1) 1))
    (define crit (if crit-map (hash-ref crit-map reg 0) 0))
    (define priority
      (/ (exact->inexact degree) (* (max 1 cost) (+ 1.0 (* crit-w crit)))))
    (when (> priority best-priority)
      (set! best-idx i)
      (set! best-priority priority)))

  (define best-reg (pvector-ref (allocator-state-index-reg state) best-idx))
  (define st1 (struct-copy allocator-state state
                           [spill-worklist (intbits-clear worklist best-idx)]))

  (define new-stack (cons best-reg (allocator-state-select-stack st1)))
  (define new-stack-set (intbits-set (allocator-state-select-stack-set st1) best-idx))

  (decrement-degree st1 best-reg best-idx
                    (allocator-state-simplify-worklist st1)
                    new-stack new-stack-set))

;; ============================================================
;; Assign Colors
;; ============================================================

(define (assign-colors state abi)
  (define state-after-groups (assign-group-colors state abi))
  (assign-individual-colors state-after-groups abi))

(define (assign-group-colors state abi)
  (define ig (allocator-state-ig state))
  (define groups (ig-get-groups ig))
  (define k (allocator-state-k state))

  (define reg->group
    (for*/fold ([m reg-om-empty])
               ([group (in-pvector groups)]
                [mem (in-list (reg-group-members group))])
      (reg-om-set m mem group)))

  (for/fold ([st state])
            ([group (in-pvector groups)])
    (define members (reg-group-members group))
    (define group-size (length members))
    (define alignment (reg-group-alignment group))

    (define used-colors
      (for/fold ([used intbits-empty])
                ([m (in-list members)])
        (for/fold ([u used])
                  ([neighbor (in-list (effective-neighbors st m))])
          (if (member neighbor members)
              u
              (let* ([alias (get-alias st neighbor)]
                     [neighbor-group (reg-om-ref reg->group alias #f)]
                     [neighbor-color (reg-om-ref (allocator-state-color-map st) alias #f)])
                (cond
                  [(and neighbor-group neighbor-color)
                   (define ng-size (length (reg-group-members neighbor-group)))
                   (define ng-first-member (car (reg-group-members neighbor-group)))
                   (define ng-start (reg-om-ref (allocator-state-color-map st) ng-first-member #f))
                   (if ng-start
                       (for/fold ([u* u]) ([c (in-range ng-start (+ ng-start ng-size))])
                         (intbits-set u* c))
                       u)]
                  [neighbor-color (intbits-set u neighbor-color)]
                  [else u]))))))

    (define start-color (find-consecutive-colors k group-size alignment used-colors))

    (if start-color
        (for/fold ([s st])
                  ([m (in-list members)]
                   [offset (in-naturals)])
          (define color (+ start-color offset))
          (define idx (reg-om-ref (allocator-state-reg-index s) m #f))
          (struct-copy allocator-state s
                       [color-map (reg-om-set (allocator-state-color-map s) m color)]
                       [colored-nodes (if idx
                                          (intbits-set (allocator-state-colored-nodes s) idx)
                                          (allocator-state-colored-nodes s))]))
        (for/fold ([s st])
                  ([m (in-list members)])
          (define idx (reg-om-ref (allocator-state-reg-index s) m #f))
          (if (and idx (reg-id-virtual? m))
              (struct-copy allocator-state s
                           [spilled-nodes (intbits-set (allocator-state-spilled-nodes s) idx)])
              s)))))

(define (find-consecutive-colors k n alignment used-colors)
  (for/first ([start (in-range 0 (- k (sub1 n)))]
              #:when (and (= 0 (remainder start alignment))
                         (consecutive-colors-available? start n used-colors)))
    start))

(define (consecutive-colors-available? start n used-colors)
  (for/and ([c (in-range start (+ start n))])
    (not (intbits-ref used-colors c))))

(define (assign-individual-colors state abi)
  (define stack (allocator-state-select-stack state))
  (define ig (allocator-state-ig state))
  (define k (allocator-state-k state))
  (define class (class-ig-class ig))

  ;; 计算 callee-saved 颜色
  (define callee-saved-colors (compute-callee-saved-colors abi class))

  (for/fold ([st state])
            ([reg (in-list stack)])
    (define already-colored? (reg-om-ref (allocator-state-color-map st) reg #f))
    (define already-spilled?
      (let ([idx (reg-om-ref (allocator-state-reg-index st) reg #f)])
        (and idx (intbits-ref (allocator-state-spilled-nodes st) idx))))

    (if (or already-colored? already-spilled?)
        st
        (let* ([idx (reg-om-ref (allocator-state-reg-index st) reg #f)]
               [is-live-across-call? (and idx (effective-live-across-call? st reg))]
               ;; clobber-aware：跨调用值只排除被实际 clobber 的物理寄存器；
               ;; 无 clobber 信息时退回保守的 callee-saved-only。
               [allowed-colors
                (if is-live-across-call?
                    (let ([cu (effective-clobber-union st reg)])
                      (or (and cu (compute-colors-excluding-phys abi class cu))
                          callee-saved-colors))
                    #f)]
               [used-colors
                (for/fold ([used intbits-empty])
                          ([neighbor (in-list (effective-neighbors st reg))])
                  (define alias (get-alias st neighbor))
                  (define color (reg-om-ref (allocator-state-color-map st) alias #f))
                  (if color (intbits-set used color) used))]
               ;; 偏置着色 (biased coloring / call-argument coalescing):
               ;; 优先取一个 move 伙伴 (含预着色的调用参数/返回寄存器) 的颜色,
               ;; 使 `mov dst,src` 两端同色 → 退化为 mov xN,xN 被消除。
               ;; 这正是把域运算结果流入下一个 .call 参数寄存器的机制。
               [color-legal?
                (lambda (c)
                  (and (not (intbits-ref used-colors c))
                       (if allowed-colors (intbits-ref allowed-colors c) (< c k))))]
               [preferred-color
                (and (not (getenv "ASMP_NO_BIAS"))
                     (let ([rep (get-alias st reg)])
                       (for/first ([edge (in-list (reg-om-ref
                                                   (allocator-state-move-list st) reg '()))]
                                   #:do [(define s (get-alias st (move-edge-src edge)))
                                         (define d (get-alias st (move-edge-dst edge)))
                                         (define partner (if (equal? s rep) d s))
                                         (define pc (reg-om-ref
                                                     (allocator-state-color-map st) partner #f))]
                                   #:when (and pc (color-legal? pc)))
                         pc)))]
               [available-color
                (or preferred-color
                    (if allowed-colors
                        (for/first ([c (in-intbits allowed-colors)]
                                    #:when (not (intbits-ref used-colors c)))
                          c)
                        (for/first ([c (in-range k)]
                                    #:when (not (intbits-ref used-colors c)))
                          c)))])

          (if available-color
              (struct-copy allocator-state st
                           [color-map (reg-om-set (allocator-state-color-map st) reg available-color)]
                           [colored-nodes (if idx (intbits-set (allocator-state-colored-nodes st) idx)
                                              (allocator-state-colored-nodes st))])
              (struct-copy allocator-state st
                           [spilled-nodes (if idx (intbits-set (allocator-state-spilled-nodes st) idx)
                                              (allocator-state-spilled-nodes st))]))))))

(define (compute-callee-saved-colors abi class)
  (define cfg (abi-get-class-config abi class))
  (if cfg
      (let* ([callee-saved-regs (reg-callee-saved cfg)]
             [allocatable-regs (reg-allocatable cfg)])
        (for/intbits ([color (in-naturals)]
                     [phys-reg (in-intbits allocatable-regs)]
                     #:when (intbits-ref callee-saved-regs phys-reg))
          color))
      intbits-empty))

;; 计算 caller-saved 颜色 (优先分配这些)
(define (compute-caller-saved-colors abi class)
  (define cfg (abi-get-class-config abi class))
  (if cfg
      (let* ([caller-saved-regs (reg-caller-saved cfg)]
             [allocatable-regs (reg-allocatable cfg)])
        (for/intbits ([color (in-naturals)]
                     [phys-reg (in-intbits allocatable-regs)]
                     #:when (intbits-ref caller-saved-regs phys-reg))
          color))
      intbits-empty))

;; ============================================================
;; 构建结果
;; ============================================================

(define (build-alloc-result state)
  (define assignment
    (for/fold ([m reg-om-empty])
              ([kv (in-reg-om (allocator-state-color-map state))])
      (define reg (car kv))
      (define color (cdr kv))
      (if (reg-id-physical? reg) m (reg-om-set m reg color))))

  (define spilled
    (for/fold ([pv (pvector-empty)])
              ([i (in-intbits (allocator-state-spilled-nodes state))])
      (pvector-cons-right pv (pvector-ref (allocator-state-index-reg state) i))))

  (define coalesced
    (for/fold ([m reg-om-empty])
              ([kv (in-reg-om (allocator-state-coalesce-map state))])
      (reg-om-set m (car kv) (get-alias state (cdr kv)))))

  (alloc-result assignment spilled coalesced))

;; ============================================================
;; 格式化
;; ============================================================

(define (format-alloc-result result)
  (define lines '())
  (define (add-line! s) (set! lines (cons s lines)))

  (add-line! "=== 寄存器分配结果 ===")
  (add-line! "")
  (add-line! "分配:")
  (if (reg-om-empty? (alloc-result-assignment result))
      (add-line! "  (无虚拟寄存器)")
      (for ([kv (in-reg-om (alloc-result-assignment result))])
        (define reg (car kv))
        (define color (cdr kv))
        (define phys (abi-color->reg arm64-abi (reg-id-class reg) color))
        (add-line! (format "  ~a -> ~a"
                           (format-reg-id reg)
                           (if phys (format-phys-reg (reg-id-class reg) phys) "?")))))

  (add-line! "")
  (add-line! (format "溢出: ~a" (pvector-length (alloc-result-spilled result))))
  (when (> (pvector-length (alloc-result-spilled result)) 0)
    (for ([reg (in-pvector (alloc-result-spilled result))])
      (add-line! (format "  ~a" (format-reg-id reg)))))

  (when (not (reg-om-empty? (alloc-result-coalesced result)))
    (add-line! "")
    (add-line! "合并:")
    (for ([kv (in-reg-om (alloc-result-coalesced result))])
      (add-line! (format "  ~a -> ~a" (format-reg-id (car kv)) (format-reg-id (cdr kv))))))

  (string-join (reverse lines) "\n"))

(define (format-multi-alloc-result mar)
  (string-join
   (filter (lambda (s) (not (string=? s "")))
           (list (if (multi-alloc-result-gpr mar)
                     (string-append "=== GPR ===\n" (format-alloc-result (multi-alloc-result-gpr mar)))
                     "")
                 (if (multi-alloc-result-fpr mar)
                     (string-append "=== FPR ===\n" (format-alloc-result (multi-alloc-result-fpr mar)))
                     "")
                 (if (multi-alloc-result-pred mar)
                     (string-append "=== Predicate ===\n" (format-alloc-result (multi-alloc-result-pred mar)))
                     "")))
   "\n\n"))

(define (format-reg-id r)
  (define prefix (case (reg-id-class r) [(gpr) "x"] [(fpr) "v"] [(predicate) "p"] [else "?"]))
  (if (reg-id-virtual? r)
      (format "~a.~a" prefix (reg-id-id r))
      (format "~a~a" prefix (reg-id-id r))))

(define (format-phys-reg class id)
  (case class
    [(gpr) (format "x~a" id)]
    [(fpr) (format "v~a" id)]
    [(predicate) (format "p~a" id)]
    [else (format "?~a" id)]))
