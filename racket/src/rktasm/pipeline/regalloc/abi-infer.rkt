#lang racket

;; ============================================================
;; pipeline/regalloc/abi-infer.rkt - ABI 推断与验证
;; ============================================================
;;
;; 功能：
;; 1. 推断函数的实际 def 集合（哪些寄存器被修改）
;; 2. 验证声明的 ABI 是否被遵守
;; 3. 为假溢出分析提供 ABI 信息
;;
;; 算法：
;; - 构建函数调用图
;; - 识别强连通分量 (SCC)
;; - 按拓扑序对每个 SCC 进行不动点迭代

(require "abi.rkt"
         "abi-config.rkt"
         "types.rkt"
         "../../semantic/control-flow.rkt"
         "../../semantic/use-def.rkt"
         "../../parser/ast.rkt"
         racket/intbits
         racket/pvector
         racket/intmap)

(provide
  ;; 推断结果
  (struct-out inferred-abi)
  (struct-out function-abi-info)
  inferred-abi-empty
  inferred-abi-union

  ;; 主函数
  infer-all-abis
  clear-abi-infer-cache!

  ;; 验证
  verify-declared-abi

  ;; 查询
  get-function-abi-info
  function-is-leaf?)

;; ============================================================
;; 数据结构
;; ============================================================

;; 推断出的 ABI：记录函数会 def 哪些寄存器
(struct inferred-abi
  (gpr-def    ; intbits — 被 def 的 GPR (x0-x30)
   fpr-def    ; intbits — 被 def 的 FPR (v0-v31)
   pred-def)  ; intbits — 被 def 的 Predicate (p0-p15)
  #:transparent)

(define inferred-abi-empty
  (inferred-abi intbits-empty intbits-empty intbits-empty))

;; 内部保留标记：动态调用（如 blr）未知目标
(define unknown-call-target '__unknown_call__)

;; 合并两个 inferred-abi（并集）
(define (inferred-abi-union a b)
  (inferred-abi
    (intbits-union (inferred-abi-gpr-def a) (inferred-abi-gpr-def b))
    (intbits-union (inferred-abi-fpr-def a) (inferred-abi-fpr-def b))
    (intbits-union (inferred-abi-pred-def a) (inferred-abi-pred-def b))))

;; 函数 ABI 信息（推断 + 验证结果）
(struct function-abi-info
  (fn-name         ; symbol
   declared-abi    ; abi-config | #f
   inferred-abi    ; inferred-abi
   callees         ; (listof symbol) — 调用的函数名
  errors)         ; (listof string)
  #:transparent)

;; 函数局部摘要（与 ABI 配置无关，可跨 CFG 复用）
(struct fn-local-summary
  (id              ; exact-nonnegative-integer - 全局唯一摘要 ID
   local-def       ; inferred-abi
   callees)        ; (listof symbol)
  #:transparent)

;; CFG 预处理缓存（增量复用）：
;; - 缓存与 ABI 配置无关的部分（局部 def、调用关系、调用图、SCC）
;; - 每次 infer-all-abis 时仍动态读取 ABI 配置，保证配置变化语义正确
(struct infer-prepared
  (n                     ; exact-nonnegative-integer
   names-vec             ; vector[index -> symbol]
   local-defs-vec        ; vector[index -> inferred-abi]
   raw-callees-vec       ; vector[index -> (listof symbol)]
   callee-refs-vec       ; vector[index -> (listof (or/c exact-nonnegative-integer? symbol?))]
   declared-abi-names-vec ; vector[index -> symbol|#f]
   sccs)                 ; (listof (listof index))
  #:transparent)

(define *infer-prepared-cache* (make-weak-hasheq))
;; key: 函数规范化指令序列（listof string），value: fn-local-summary
(define *fn-local-summary-cache* (make-hash))
;; key: 程序结构签名，value: infer-prepared
(define *infer-prepared-structure-cache* (make-hash))
;; key: infer-prepared(eq?)，value: hash[result-signature -> abi-info-map]
(define *infer-result-cache* (make-weak-hasheq))
(define *next-fn-summary-id* (box 0))

(define (clear-abi-infer-cache!)
  (hash-clear! *infer-prepared-cache*)
  (hash-clear! *fn-local-summary-cache*)
  (hash-clear! *infer-prepared-structure-cache*)
  (hash-clear! *infer-result-cache*)
  (set-box! *next-fn-summary-id* 0))

(define (abi-config-signature)
  (define p (abi-config-path))
  (define path (if (path? p) p (string->path p)))
  (define path* (path->string (simplify-path (path->complete-path path))))
  (if (file-exists? path*)
      (list path*
            (file-or-directory-modify-seconds path*)
            (file-size path*))
      (list path* 'missing)))

(define (infer-result-signature)
  (list (default-abi-name) (abi-config-signature)))

(define (extern-abi-key cfg)
  (sort
   (for/list ([(name abi-name) (in-hash (cfg-get-info cfg 'extern-abi-names (hash)))])
     (list name abi-name))
   string<?
   #:key (lambda (entry) (symbol->string (car entry)))))

;; 生成函数体摘要 key。
;; 直接使用函数 blocks 持久化结构作为 equal?-key，避免构造额外摘要对象。
;; 该 key 包含 srcloc / block-id 等信息，因此对“同源码重复构建 CFG”复用友好；
;; 对位置变化会保守 miss，但不影响正确性。
(define (function-summary-key fn)
  (asm-function-blocks fn))

(define (intern-fn-local-summary summary-key fn)
  (define cached (hash-ref *fn-local-summary-cache* summary-key #f))
  (if cached
      cached
      (let-values ([(local-def callees) (collect-local-defs fn)])
        (define sid (unbox *next-fn-summary-id*))
        (set-box! *next-fn-summary-id* (add1 sid))
        (define summary (fn-local-summary sid local-def callees))
        (hash-set! *fn-local-summary-cache* summary-key summary)
        summary)))

(define (prepare-infer-context cfg)
  (define cached (hash-ref *infer-prepared-cache* cfg #f))
  (if cached
      cached
      (let ()
        ;; 1) 收集函数名、声明 ABI 名、局部摘要（可跨 CFG 复用）
        (define n (cfg-function-count cfg))
        (define names-vec (make-vector n #f))
        (define declared-abi-names-vec (make-vector n #f))
        (define summaries-vec (make-vector n #f))
        (define summary-ids-vec (make-vector n -1))
        (for ([i (in-range n)])
          (define fn (cfg-get-function cfg i))
          (define fn-name (asm-function-name fn))
          (vector-set! names-vec i fn-name)
          (vector-set! declared-abi-names-vec i (fn-get-info fn 'abi #f))
          (define summary-key (function-summary-key fn))
          (define summary (intern-fn-local-summary summary-key fn))
          (vector-set! summaries-vec i summary)
          (vector-set! summary-ids-vec i (fn-local-summary-id summary)))

        ;; 2) 尝试按“程序结构签名”复用已准备结果
        (define extern-key (extern-abi-key cfg))
        (define structure-key
          (list
           extern-key
           (for/list ([i (in-range n)])
             (list (vector-ref names-vec i)
                   (vector-ref declared-abi-names-vec i)
                   (vector-ref summary-ids-vec i)))))
        (define structure-cached
          (hash-ref *infer-prepared-structure-cache* structure-key #f))
        (if structure-cached
            (begin
              (hash-set! *infer-prepared-cache* cfg structure-cached)
              structure-cached)
            (let ()
              ;; 3) 结构缓存 miss：构建完整预处理结果
              (define fn->idx (make-hash))
              (for ([i (in-range n)])
                (hash-set! fn->idx (vector-ref names-vec i) i))

              (define local-defs-vec
                (for/vector ([i (in-range n)])
                  (fn-local-summary-local-def (vector-ref summaries-vec i))))
              (define raw-callees-vec
                (for/vector ([i (in-range n)])
                  (fn-local-summary-callees (vector-ref summaries-vec i))))

              ;; 调用目标预解析（内部函数 -> index，外部函数/unknown 保留 symbol）
              (define callee-refs-vec
                (for/vector ([i (in-range n)])
                  (for/list ([callee (in-list (vector-ref raw-callees-vec i))])
                    (define maybe-idx (hash-ref fn->idx callee #f))
                    (if maybe-idx maybe-idx callee))))

              ;; 构建调用图并求 SCC（仅依赖代码结构）
              (define call-graph (build-call-graph callee-refs-vec))
              (define sccs (find-sccs call-graph))

              (define prepared
                (infer-prepared n
                                names-vec
                                local-defs-vec
                                raw-callees-vec
                                callee-refs-vec
                                declared-abi-names-vec
                                sccs))
              (hash-set! *infer-prepared-structure-cache* structure-key prepared)
              (hash-set! *infer-prepared-cache* cfg prepared)
              prepared)))))

;; ============================================================
;; 第一遍：收集函数局部 def 和调用关系
;; ============================================================

;; 收集函数自身指令的 def（不包括调用传递的 def）
;; fn : asm-function
;; → (values inferred-abi (listof symbol))
;;   第一个返回值: 函数局部 def 的寄存器集合
;;   第二个返回值: 调用目标函数名列表 (去重)
(define (collect-local-defs fn)
  ;; gd : intbits — 被 def 的 GPR 编号
  ;; fd : intbits — 被 def 的 FPR 编号
  ;; pd : intbits — 被 def 的 Predicate 编号
  ;; cs : (listof symbol) — 调用目标 (逆序，已去重)
  (define seen-callees (make-hash))
  (define-values (gd fd pd cs)
    (for*/fold ([gd intbits-empty]
                [fd intbits-empty]
                [pd intbits-empty]
                [cs '()])
               ([kv (in-intmap-pairs (asm-function-blocks fn))]
                [ins (in-pvector (basic-block-instructions (cdr kv)))]
                #:when (ast-ins? ins))
      (define mnem (ast-ins-mnemonic ins))
      (cond
        ;; bl/blr 调用：收集被调用函数名
        [(memq mnem '(bl blr))
         (define target (get-call-target ins))
         (define callee
           (if (and target (symbol? target))
               target
               ;; 动态调用无法静态解析目标，按未知调用处理
               unknown-call-target))
         (if (hash-ref seen-callees callee #f)
             (values gd fd pd cs)
             (begin
               (hash-set! seen-callees callee #t)
               (values gd fd pd (cons callee cs))))]
        ;; 其他指令：收集 def 的物理寄存器
        [else
         (define use-def (extract-use-def ins))
         (define-values (gd2 fd2 pd2)
           (for/fold ([g gd] [f fd] [p pd])
                     ([ref (in-list (use-def-flat-defs use-def))])
             (define-values (class reg-num) (physical-reg-info ref))
             (if reg-num
                 (case class
                   [(gpr) (values (intbits-set g reg-num) f p)]
                   [(fpr) (values g (intbits-set f reg-num) p)]
                   [(predicate) (values g f (intbits-set p reg-num))]
                   [else (values g f p)])
                 (values g f p))))
         (values gd2 fd2 pd2 cs)])))

  (values (inferred-abi gd fd pd) cs))

;; 获取调用目标（bl 的标签名）
(define (get-call-target ins)
  (define ops (ast-ins-operands ins))
  (and (pair? ops)
       (ast-label? (car ops))
       (ast-label-name (car ops))))

;; 从 reg-ref 获取物理寄存器信息
;; 返回 (values class reg-num) 或 (values #f #f)
(define (physical-reg-info ref)
  (cond
    [(reg-ref? ref)
     (define rid (reg-ref->reg-id ref))
     (cond
       ;; 虚拟寄存器：跳过（只关心物理寄存器）
       [(reg-id-virtual? rid) (values #f #f)]
       ;; 物理寄存器
       [else
        (define class (reg-id-class rid))
        (define id (reg-id-id rid))
        (if (integer? id)
            (values class id)
            (values #f #f))])]
    [else (values #f #f)]))

;; ============================================================
;; 调用图与 SCC
;; ============================================================

;; 构建调用图
;; callee-refs-vec : vector[index -> (listof (or/c exact-nonnegative-integer? symbol?))]
;; → vector[index -> (listof index)]（仅程序内函数边）
(define (build-call-graph callee-refs-vec)
  (define n (vector-length callee-refs-vec))
  (define graph (make-vector n '()))
  (for ([i (in-range n)])
    ;; 调用目标在 infer-all-abis 中已预解析为内部索引或外部符号
    (define known-rev
      (for/fold ([acc '()])
                ([callee-ref (in-list (vector-ref callee-refs-vec i))])
        (if (integer? callee-ref)
            (cons callee-ref acc)
            acc)))
    (vector-set! graph i known-rev))
  graph)

;; Tarjan 算法找 SCC
;; graph : vector[index -> (listof index)]
;; → (listof (listof index))
(define (find-sccs graph)
  (define n (vector-length graph))
  (define index 0)
  (define indices (make-vector n -1))
  (define lowlinks (make-vector n -1))
  (define on-stack (make-vector n #f))
  (define stack '())
  (define sccs '())

  (define (strongconnect v)
    (vector-set! indices v index)
    (vector-set! lowlinks v index)
    (set! index (add1 index))
    (set! stack (cons v stack))
    (vector-set! on-stack v #t)

    (for ([w (in-list (vector-ref graph v))])
      (cond
        [(= -1 (vector-ref indices w))
         (strongconnect w)
         (vector-set! lowlinks v
                      (min (vector-ref lowlinks v)
                           (vector-ref lowlinks w)))]
        [(vector-ref on-stack w)
         (vector-set! lowlinks v
                      (min (vector-ref lowlinks v)
                           (vector-ref indices w)))]))

    (when (= (vector-ref lowlinks v) (vector-ref indices v))
      (define scc '())
      (let loop ()
        (define w (car stack))
        (set! stack (cdr stack))
        (vector-set! on-stack w #f)
        (set! scc (cons w scc))
        (unless (eq? w v)
          (loop)))
      (set! sccs (cons scc sccs))))

  (for ([v (in-range n)])
    (when (= -1 (vector-ref indices v))
      (strongconnect v)))

  (reverse sccs))

;; ============================================================
;; 不动点迭代
;; ============================================================

;; 对一个 SCC 进行不动点计算
(define (compute-scc-fixpoint scc local-defs-vec callee-refs-vec result-vec
                              declared-scratch-defs
                              default-scratch-def)
  ;; 使用局部索引化向量表示 SCC 内部状态，降低迭代期开销
  (define scc-indices-vec (list->vector scc))
  (define scc-size (vector-length scc-indices-vec))
  (define global->local
    (for/hash ([global-idx (in-list scc)]
               [local-idx (in-naturals)])
      (values global-idx local-idx)))
  ;; base-vec[idx] : local-def ∪ 外部调用贡献（常量）
  (define base-vec (make-vector scc-size inferred-abi-empty))
  ;; internal-vec[idx] : SCC 内调用目标索引向量
  (define internal-vec (make-vector scc-size #()))
  ;; values-vec[idx] : 当前不动点值
  (define values-vec (make-vector scc-size inferred-abi-empty))

  ;; 预计算 base/internal，并初始化当前值
  (for ([local-idx (in-range scc-size)])
    (define global-idx (vector-ref scc-indices-vec local-idx))
    (define local-def (vector-ref local-defs-vec global-idx))
    (define callees (vector-ref callee-refs-vec global-idx))

    (define-values (internal-idx-rev base-def)
      (for/fold ([internal-idx-rev '()]
                 [acc local-def])
                ([callee-ref (in-list callees)])
        (cond
          [(integer? callee-ref)
           (define callee-local-idx (hash-ref global->local callee-ref #f))
           (if callee-local-idx
               ;; SCC 内调用：留给迭代阶段
               (values (cons callee-local-idx internal-idx-rev) acc)
               ;; SCC 外（但在程序内）调用：其推断值已固定
               (values internal-idx-rev
                       (inferred-abi-union
                        acc
                        (vector-ref result-vec callee-ref))))]
          [else
           ;; 外部/未知调用：按声明 ABI 或默认 ABI 保守建模
           (values internal-idx-rev
                   (inferred-abi-union
                    acc
                    (get-callee-abi callee-ref result-vec
                                    declared-scratch-defs
                                    default-scratch-def)))])))

    (define internal-indices (list->vector (reverse internal-idx-rev)))
    (vector-set! base-vec local-idx base-def)
    (vector-set! internal-vec local-idx internal-indices)
    (vector-set! values-vec local-idx base-def))

  ;; 仅保留可能变化的节点（有 SCC 内依赖）
  (define active-nodes
    (for/list ([local-idx (in-range scc-size)]
               #:when (> (vector-length (vector-ref internal-vec local-idx)) 0))
      local-idx))

  ;; 若无内部边（例如单节点无自环），base-def 已是最终结果，零迭代返回
  (define has-internal-edges? (pair? active-nodes))

  (when has-internal-edges?
    ;; 自适应策略：
    ;; - 稀疏 SCC：worklist 只传播受影响节点（通常更快）
    ;; - 稠密 SCC：sweep 扫描全体活跃节点（减少维护 worklist 成本）
    (define internal-edge-count
      (for/sum ([local-idx (in-list active-nodes)])
        (vector-length (vector-ref internal-vec local-idx))))
    (define use-sweep?
      (or
       (<= scc-size 4)
       ;; 平均出度 >= 8，视为较稠密
       (>= internal-edge-count (* 8 scc-size))
       ;; 较大 SCC 且边密度 >= 1/3
       (and (>= scc-size 16)
            (>= (* 3 internal-edge-count) (* scc-size scc-size)))))

    (if use-sweep?
        (let loop ([iter 0])
          (when (< iter 100)
            (define changed? #f)
            (for ([local-idx (in-list active-nodes)])
              (define base-def (vector-ref base-vec local-idx))
              (define internal-indices (vector-ref internal-vec local-idx))
              (define merged-def
                (for/fold ([acc base-def])
                          ([callee-local-idx (in-vector internal-indices)])
                  (inferred-abi-union acc
                                      (vector-ref values-vec callee-local-idx))))
              (unless (equal? (vector-ref values-vec local-idx) merged-def)
                (vector-set! values-vec local-idx merged-def)
                (set! changed? #t)))
            (when changed?
              (loop (add1 iter)))))
        (let ()
          ;; 增量 worklist：仅重算“依赖于发生变化节点”的用户节点
          (define users-vec (make-vector scc-size '()))
          ;; 构建反向依赖：callee -> users
          (for ([local-idx (in-range scc-size)])
            (for ([callee-local-idx (in-vector (vector-ref internal-vec local-idx))])
              (vector-set! users-vec callee-local-idx
                           (cons local-idx (vector-ref users-vec callee-local-idx)))))

          (define pending '())
          (define in-worklist (make-vector scc-size #f))

          (define (enqueue! idx)
            (unless (vector-ref in-worklist idx)
              (set! pending (cons idx pending))
              (vector-set! in-worklist idx #t)))

          (for ([local-idx (in-list active-nodes)])
            (enqueue! local-idx))

          (let loop ()
            (unless (null? pending)
              (define local-idx (car pending))
              (set! pending (cdr pending))
              (vector-set! in-worklist local-idx #f)

              (define base-def (vector-ref base-vec local-idx))
              (define internal-indices (vector-ref internal-vec local-idx))
              (define merged-def
                (for/fold ([acc base-def])
                          ([callee-local-idx (in-vector internal-indices)])
                  (inferred-abi-union acc
                                      (vector-ref values-vec callee-local-idx))))

              (define old-def (vector-ref values-vec local-idx))
              (unless (equal? old-def merged-def)
                (vector-set! values-vec local-idx merged-def)
                (for ([user-local-idx (in-list (vector-ref users-vec local-idx))])
                  (enqueue! user-local-idx)))

              (loop))))))

  ;; 回写 SCC 结果
  (for ([local-idx (in-range scc-size)])
    (define global-idx (vector-ref scc-indices-vec local-idx))
    (vector-set! result-vec global-idx (vector-ref values-vec local-idx))))

;; 获取被调用函数的 ABI（用于计算 def 集合）
;; 如果有声明 ABI，返回其 scratch-reg 作为 def
;; 否则返回推断的 def
(define (get-callee-abi callee-ref result-vec declared-scratch-defs default-scratch-def)
  (cond
    ;; 程序内已知函数
    [(integer? callee-ref)
     (vector-ref result-vec callee-ref)]
    ;; 动态调用（如 blr）按默认 ABI 的 scratch 集保守建模
    [(eq? callee-ref unknown-call-target)
     default-scratch-def]
    ;; 有声明 ABI 的函数：scratch-reg 视为 def
    [(hash-ref declared-scratch-defs callee-ref #f)]
    ;; 未知函数：保守假设所有 scratch-reg 被 def
    ;; 使用默认 ABI
    [else default-scratch-def]))

;; 将 abi-config 转换为 scratch-reg 的 def 集合
;; scratch-reg = 全集 - banned - preserved
(define (abi-to-scratch-def abi)
  (define (class-scratch-def cfg)
    (define num-regs (reg-class-config-num-regs cfg))
    (define banned (reg-class-config-banned cfg))
    (define preserved (reg-class-config-preserved cfg))
    (define all-regs (for/intbits ([i (in-range num-regs)]) i))
    (intbits-subtract (intbits-subtract all-regs banned) preserved))

  (inferred-abi
    (class-scratch-def (abi-config-gpr abi))
    (class-scratch-def (abi-config-fpr abi))
    (class-scratch-def (abi-config-pred abi))))

;; ============================================================
;; ABI 验证
;; ============================================================

;; 验证函数是否遵守声明的 ABI
;; fn-name      : symbol
;; declared-abi : abi-config
;; inferred     : inferred-abi
;; → (listof string) — 错误信息列表
(define (verify-declared-abi fn-name declared-abi inferred)
  (define (check-class class-name cfg inferred-def)
    ;; preserved : intbits — ABI 要求保护的寄存器
    (define preserved (reg-class-config-preserved cfg))
    ;; violations : intbits — 被修改的保护寄存器
    (define violations (intbits-intersect preserved inferred-def))
    (if (intbits-empty? violations)
        '()
        (let ()
          (define reg-names
            (for/list ([r (in-intbits violations)])
              (format-reg-name class-name r)))
          (list (format "函数 '~a' 声明的 ABI 要求保护 ~a，但函数修改了它们"
                        fn-name (string-join reg-names ", "))))))

  (append
   (check-class 'gpr (abi-config-gpr declared-abi) (inferred-abi-gpr-def inferred))
   (check-class 'fpr (abi-config-fpr declared-abi) (inferred-abi-fpr-def inferred))
   (check-class 'pred (abi-config-pred declared-abi) (inferred-abi-pred-def inferred))))

;; 格式化寄存器名
(define (format-reg-name class reg-num)
  (case class
    [(gpr) (format "x~a" reg-num)]
    [(fpr) (format "v~a" reg-num)]
    [(pred) (format "p~a" reg-num)]
    [else (format "r~a" reg-num)]))

;; ============================================================
;; 主函数
;; ============================================================

;; 对 CFG 中的所有函数进行 ABI 推断和验证
;; cfg : cfg (程序 CFG)
;; → hash[fn-name → function-abi-info]
(define (infer-all-abis cfg)
  ;; 1. 复用与 ABI 配置无关的预处理结果（可跨多次推断增量复用）
  (define prepared (prepare-infer-context cfg))
  ;; 结果级缓存：同一 prepared + 同一 ABI 配置签名，直接复用最终 abi-map
  (define result-sig (infer-result-signature))
  (define prepared-result-bucket (hash-ref *infer-result-cache* prepared #f))
  (define cached-result
    (and prepared-result-bucket
         (hash-ref prepared-result-bucket result-sig #f)))
  (if cached-result
      cached-result
      (let ()
  (define n (infer-prepared-n prepared))
  (define names-vec (infer-prepared-names-vec prepared))
  (define local-defs-vec (infer-prepared-local-defs-vec prepared))
  (define raw-callees-vec (infer-prepared-raw-callees-vec prepared))
  (define callee-refs-vec (infer-prepared-callee-refs-vec prepared))
  (define sccs (infer-prepared-sccs prepared))
  (define declared-abi-names-vec (infer-prepared-declared-abi-names-vec prepared))

  ;; 2. 绑定当前 ABI 配置（每次动态读取，确保配置变化后语义正确）
  (define declared-vec (make-vector n #f))
  (define declared-scratch-defs (make-hash))
  ;; 同一 abi-name 常被重复使用，做一次局部缓存减少查询/转换开销
  (define abi-name->cfg (make-hash))
  (define abi-name->scratch (make-hash))

  (define (resolve-abi abi-name)
    (cond
      [(hash-has-key? abi-name->cfg abi-name)
       (hash-ref abi-name->cfg abi-name)]
      [else
       (define abi (get-abi-by-name abi-name))
       (hash-set! abi-name->cfg abi-name abi)
       (when abi
         (hash-set! abi-name->scratch abi-name (abi-to-scratch-def abi)))
       abi]))

  (for ([i (in-range n)])
    (define abi-name (vector-ref declared-abi-names-vec i))
    (when abi-name
      (define abi (resolve-abi abi-name))
      (when abi
        (define fn-name (vector-ref names-vec i))
        (vector-set! declared-vec i abi)
        (hash-set! declared-scratch-defs fn-name
                   (hash-ref abi-name->scratch abi-name inferred-abi-empty)))))

  ;; 外部函数可单独声明 ABI；调用这些符号时按声明 ABI 的 scratch 集处理。
  (for ([(fn-name abi-name) (in-hash (cfg-get-info cfg 'extern-abi-names (hash)))])
    (define abi (resolve-abi abi-name))
    (unless abi
      (error 'infer-all-abis "extern 函数 '~a' 指定的 ABI '~a' 未定义" fn-name abi-name))
    (hash-set! declared-scratch-defs fn-name
               (hash-ref abi-name->scratch abi-name inferred-abi-empty)))

  ;; 预计算默认 ABI 的 scratch-def（未知/动态调用回退）
  (define default-scratch-def
    (let* ([name0 (default-abi-name)]
           [name (if (eq? name0 'auto) 'aapcs64 name0)])
      (cond
        [name
         (define abi (get-abi-by-name name))
         (unless abi
           (error 'infer-all-abis "默认 ABI '~a' 未定义" name))
         (abi-to-scratch-def abi)]
        [else
         (abi-to-scratch-def arm64-abi)])))

  ;; 3. 按拓扑序（逆序 SCC）计算不动点
  ;; result-vec : vector[index → inferred-abi]
  (define result-vec (make-vector n inferred-abi-empty))
  (for ([scc (in-list sccs)])
    (compute-scc-fixpoint scc local-defs-vec callee-refs-vec result-vec
                          declared-scratch-defs
                          default-scratch-def))

  ;; 4. 验证声明的 ABI 并构建最终结果
  ;; final-result : hash[fn-name → function-abi-info]
  (define final-result
    (for/hash ([i (in-range n)])
      (define fn-name (vector-ref names-vec i))
      (define inferred (vector-ref result-vec i))
      (define declared (vector-ref declared-vec i))
      (define raw-callees (vector-ref raw-callees-vec i))
      ;; 对外展示时隐藏内部保留标记
      (define callees
        (for/list ([c (in-list raw-callees)]
                   #:unless (eq? c unknown-call-target))
          c))

      (define errors
        (if declared
            (verify-declared-abi fn-name declared inferred)
            '()))

      (values fn-name
              (function-abi-info fn-name declared inferred callees errors))))

  (unless prepared-result-bucket
    (set! prepared-result-bucket (make-hash))
    (hash-set! *infer-result-cache* prepared prepared-result-bucket))
  (hash-set! prepared-result-bucket result-sig final-result)
  final-result)))

;; 查询函数的 ABI 信息
(define (get-function-abi-info abi-info-map fn-name)
  (hash-ref abi-info-map fn-name #f))

;; 判断函数是否为叶子函数（无任何 bl/blr 调用）
;; 通过检查函数体是否包含 bl/blr 指令来判断
(define (function-is-leaf? fn)
  (for*/and ([kv (in-intmap-pairs (asm-function-blocks fn))]
             [ins (in-pvector (basic-block-instructions (cdr kv)))]
             #:when (ast-ins? ins))
    (not (memq (ast-ins-mnemonic ins) '(bl blr)))))

;; ============================================================
;; 测试
;; ============================================================

(module+ test
  (displayln "=== ABI 推断测试 ===\n")
  (displayln "（需要完整 CFG 进行测试）"))
