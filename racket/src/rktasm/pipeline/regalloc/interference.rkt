#lang racket

;; ============================================================
;; pipeline/regalloc/interference.rkt - 干涉图（按寄存器类分离）
;; ============================================================
;;
;; 分离为 3 张独立干涉图:
;;   - GPR (x/w)
;;   - FPR (v/z/d/s/h/b/q)
;;   - Predicate (p)

(require "../../semantic/control-flow.rkt"
         "../../semantic/use-def.rkt"
         "../../parser/ast.rkt"
         "liveness.rkt"
         "types.rkt"
         "abi.rkt"
         "abi-infer.rkt"
         racket/pvector
         racket/intmap
         racket/intbits
         racket/graph)

(provide
  ;; 数据结构
  (struct-out class-ig)
  (struct-out multi-class-ig)
  (struct-out move-edge)

  ;; 构建
  build-interference-graphs

  ;; 跨调用 clobber 并集 (clobber-aware 分配用)
  compute-clobber-union-map

  ;; 查询 (class-ig)
  ig-neighbors
  ig-neighbors/intbits  ; 新增：直接返回 intbits
  ig-degree
  ig-interferes?
  ig-is-precolored?
  ig-get-color
  ig-move-related?
  ig-get-move-edges
  ig-num-colors
  ig-get-groups
  ig-live-across-call?
  ig-get-live-across-call
  ig-class
  ig-reg-index
  ig-index-reg

  ;; 查询 (multi-class-ig)
  mig-get-class-ig
  mig-gpr
  mig-fpr
  mig-pred

  ;; 工具
  ast-reg->reg-id
  format-class-ig
  format-multi-class-ig)

;; ============================================================
;; 数据结构
;; ============================================================

(struct move-edge (src dst) #:transparent)

;; 单类干涉图
(struct class-ig
  (class           ; 'gpr | 'fpr | 'predicate
   graph           ; ugraph (pvector[intbits])
   reg-index       ; reg-om[reg-id -> integer] (类内索引)
   index-reg       ; pvector[reg-id] (类内)
   precolored      ; intbits - 物理寄存器
   colors          ; intmap[class-idx -> integer]
   move-edges      ; pvector[move-edge]
   groups          ; pvector[reg-group]
   live-across-call ; intbits - 跨调用活跃
   num-colors)     ; integer - 可用颜色数
  #:transparent)

;; 多类干涉图容器
(struct multi-class-ig
  (gpr             ; class-ig | #f
   fpr             ; class-ig | #f
   pred            ; class-ig | #f
   effective-abi)  ; abi-config - 实际使用的 ABI (可能是 scratch-only)
  #:transparent)

;; ============================================================
;; 构建干涉图
;; ============================================================

;; 检查函数是否有 save! 声明
(define (fn-has-save-directive? fn)
  (define found #f)
  (fn-for-each-block fn
    (lambda (block)
      (unless found
        (for ([ins (in-pvector (basic-block-instructions block))])
          (when (and (ast-directive? ins)
                     (eq? (ast-directive-kind ins) 'save!))
            (set! found #t))))))
  found)

(define (entry-sp-reg? op)
  (and (ast-reg? op)
       (equal? (ast-reg-id op) 'sp)))

(define (entry-fp-reg? op)
  (and (ast-reg? op)
       (or (and (eq? (ast-reg-kind op) 'x)
                (equal? (ast-reg-id op) 29))
           (equal? (ast-reg-id op) 'fp))))

(define (entry-lr-reg? op)
  (and (ast-reg? op)
       (or (and (eq? (ast-reg-kind op) 'x)
                (equal? (ast-reg-id op) 30))
           (equal? (ast-reg-id op) 'lr))))

(define (entry-save-directive? ins)
  (and (ast-directive? ins)
       (eq? (ast-directive-kind ins) 'save!)))

(define (entry-frame-save-ins? ins)
  (and (ast-ins? ins)
       (eq? (ast-ins-mnemonic ins) 'stp)
       (let ([ops (ast-ins-operands ins)])
         (and (>= (length ops) 3)
              (entry-fp-reg? (car ops))
              (entry-lr-reg? (cadr ops))
              (ast-mem? (caddr ops))
              (let ([mem (caddr ops)])
                (and (eq? (ast-mem-index-mode mem) 'pre)
                     (entry-sp-reg? (ast-mem-base mem))))))))

(define (entry-frame-pointer-ins? ins)
  (and (ast-ins? ins)
       (eq? (ast-ins-mnemonic ins) 'mov)
       (let ([ops (ast-ins-operands ins)])
         (and (= (length ops) 2)
              (entry-fp-reg? (car ops))
              (entry-sp-reg? (cadr ops))))))

(define (fn-establishes-frame-pointer? fn)
  (define entry-bb (fn-entry-block fn))
  (and entry-bb
       (let ([instructions (basic-block-instructions entry-bb)])
         (define prefix-len (min 8 (pvector-length instructions)))
         (define has-frame-save?
           (for/or ([i (in-range prefix-len)])
             (define ins (pvector-ref instructions i))
             (or (entry-save-directive? ins)
                 (entry-frame-save-ins? ins))))
         (and has-frame-save?
              (for/or ([i (in-range (min 16 (pvector-length instructions)))])
                (entry-frame-pointer-ins? (pvector-ref instructions i)))))))

(define (reg-class-ban-reg cfg reg-num)
  (make-reg-class-config
   #:num-regs (reg-class-config-num-regs cfg)
   #:banned (intbits-set (reg-class-config-banned cfg) reg-num)
   #:preserved (intbits-clear (reg-class-config-preserved cfg) reg-num)
   #:arg-regs (reg-class-config-arg-regs cfg)
   #:return-regs (reg-class-config-return-regs cfg)))

(define (reg-class-unpreserve-reg cfg reg-num)
  (make-reg-class-config
   #:num-regs (reg-class-config-num-regs cfg)
   #:banned (reg-class-config-banned cfg)
   #:preserved (intbits-clear (reg-class-config-preserved cfg) reg-num)
   #:arg-regs (reg-class-config-arg-regs cfg)
   #:return-regs (reg-class-config-return-regs cfg)))

(define (abi-ban-gpr-reg abi reg-num)
  (abi-config (reg-class-ban-reg (abi-config-gpr abi) reg-num)
              (abi-config-fpr abi)
              (abi-config-pred abi)))

(define (abi-unpreserve-gpr-reg abi reg-num)
  (abi-config (reg-class-unpreserve-reg (abi-config-gpr abi) reg-num)
              (abi-config-fpr abi)
              (abi-config-pred abi)))

(define (build-interference-graphs fn liveness #:abi [abi arm64-abi])
  ;; 按 class 分组所有寄存器
  (define reg-index (fn-liveness-reg-index liveness))
  (define index-reg (fn-liveness-index-reg liveness))
  (define num-vars (fn-liveness-num-vars liveness))

  ;; 收集显式干涉约束（全局，稍后按类过滤）。约束里可能只出现
  ;; 物理寄存器；这些寄存器也必须成为图顶点，否则 virtual-vs-physical
  ;; 约束不会排除对应颜色。
  (define all-interference-constraints (collect-interference-constraints fn))

  ;; 分类寄存器
  (define-values (gpr-regs fpr-regs pred-regs)
    (for/fold ([gprs '()] [fprs '()] [preds '()])
              ([i (in-range num-vars)])
      (define reg (pvector-ref index-reg i))
      (case (reg-id-class reg)
        [(gpr) (values (cons (cons i reg) gprs) fprs preds)]
        [(fpr) (values gprs (cons (cons i reg) fprs) preds)]
        [(predicate) (values gprs fprs (cons (cons i reg) preds))]
        [else (values gprs fprs preds)])))

  (define live-reg-map
    (for/fold ([m reg-om-empty])
              ([i (in-range num-vars)])
      (reg-om-set m (pvector-ref index-reg i) #t)))

  (define constraint-reg-map
    (for*/fold ([m live-reg-map])
               ([constraint (in-list all-interference-constraints)]
                [reg (in-list (list (car constraint) (cdr constraint)))])
      (if (reg-om-ref m reg #f)
          m
          (reg-om-set m reg 'constraint-only))))

  (define-values (gpr-regs* fpr-regs* pred-regs*)
    (for/fold ([gprs gpr-regs]
               [fprs fpr-regs]
               [preds pred-regs]
               [next-idx num-vars]
               #:result (values gprs fprs preds))
              ([kv (in-reg-om constraint-reg-map)])
      (define reg (car kv))
      (define origin (cdr kv))
      (cond
        [(not (eq? origin 'constraint-only))
         (values gprs fprs preds next-idx)]
        [else
         (define pair (cons next-idx reg))
         (case (reg-id-class reg)
           [(gpr) (values (cons pair gprs) fprs preds (add1 next-idx))]
           [(fpr) (values gprs (cons pair fprs) preds (add1 next-idx))]
           [(predicate) (values gprs fprs (cons pair preds) (add1 next-idx))]
           [else (values gprs fprs preds next-idx)])])))

  ;; 收集 move 边（全局，稍后按类过滤）
  (define all-move-edges (collect-move-edges fn reg-index))

  ;; 收集寄存器组（全局）
  (define all-groups (collect-reg-groups fn reg-index))

  ;; 收集跨调用活跃信息
  (define live-across-call (collect-live-across-call fn liveness index-reg))

  ;; 检查是否有 save! 声明，决定可用寄存器范围
  ;; 没有 save! 时只能使用 scratch-reg，不能使用 callee-saved
  (define has-save? (fn-has-save-directive? fn))
  (define effective-abi/base (if has-save? abi (abi-scratch-only abi)))
  ;; x30 is the architectural link register. If a function saves LR, x30 may be
  ;; used as a short-lived caller-saved temporary, but it must not be treated as
  ;; callee-saved: `bl` overwrites LR before the callee runs. If LR is not saved
  ;; at all, ban x30 entirely so a virtual register cannot clobber the return
  ;; address.
  (define effective-abi/no-lr
    (if has-save?
        (abi-unpreserve-gpr-reg effective-abi/base 30)
        (abi-ban-gpr-reg effective-abi/base 30)))
  (define effective-abi
    (if (fn-establishes-frame-pointer? fn)
        (abi-ban-gpr-reg effective-abi/no-lr 29)
        effective-abi/no-lr))

  (define gpr-num-colors (reg-num-allocatable (abi-config-gpr effective-abi)))
  (define fpr-num-colors (reg-num-allocatable (abi-config-fpr effective-abi)))
  (define pred-num-colors (reg-num-allocatable (abi-config-pred effective-abi)))

  ;; 构建各类干涉图
  (define gpr-ig
    (if (null? gpr-regs*) #f
        (build-class-ig 'gpr (reverse gpr-regs*) fn liveness
                        all-move-edges all-interference-constraints
                        all-groups live-across-call
                        gpr-num-colors effective-abi)))

  (define fpr-ig
    (if (null? fpr-regs*) #f
        (build-class-ig 'fpr (reverse fpr-regs*) fn liveness
                        all-move-edges all-interference-constraints
                        all-groups live-across-call
                        fpr-num-colors effective-abi)))

  (define pred-ig
    (if (null? pred-regs*) #f
        (build-class-ig 'predicate (reverse pred-regs*) fn liveness
                        all-move-edges all-interference-constraints
                        all-groups live-across-call
                        pred-num-colors effective-abi)))

  (multi-class-ig gpr-ig fpr-ig pred-ig effective-abi))

;; 构建单类干涉图
(define (build-class-ig class reg-pairs fn liveness
                         all-move-edges all-interference-constraints
                         all-groups live-across-call
                         num-colors abi)
  ;; 创建类内索引
  (define-values (class-reg-index class-index-reg)
    (for/fold ([r->i reg-om-empty]
               [i->r (pvector-empty)])
              ([pair (in-list reg-pairs)]
               [idx (in-naturals)])
      (values (reg-om-set r->i (cdr pair) idx)
              (pvector-cons-right i->r (cdr pair)))))

  ;; 全局索引到类内索引的映射 (使用 pvector，因为 global-idx 是连续整数)
  ;; 构建一个足够大的 pvector，用 global-idx 直接索引
  (define max-global-idx
    (if (null? reg-pairs) 0 (add1 (apply max (map car reg-pairs)))))
  (define global->class
    (for/fold ([v (make-vector max-global-idx #f)])
              ([pair (in-list reg-pairs)]
               [idx (in-naturals)])
      (vector-set! v (car pair) idx)
      v))

  ;; 创建空图 (n 个顶点)
  (define n (length reg-pairs))
  (define g (make-ugraph n))

  ;; 预着色
  (define-values (precolored colors)
    (for/fold ([pre intbits-empty]
               [col intmap-empty])
              ([pair (in-list reg-pairs)]
               [idx (in-naturals)])
      (define reg (cdr pair))
      (if (reg-id-physical? reg)
          (let ([color (abi-reg->color abi (reg-id-class reg) (reg-id-id reg))])
            (values (intbits-set pre idx)
                    (if color
                        (intmap-set col idx color)
                        col)))
          (values pre col))))

  ;; 过滤本类的 move 边
  (define class-move-edges
    (for/fold ([edges (pvector-empty)])
              ([edge (in-pvector all-move-edges)])
      (if (and (eq? (reg-id-class (move-edge-src edge)) class)
               (eq? (reg-id-class (move-edge-dst edge)) class))
          (pvector-cons-right edges edge)
          edges)))

  ;; 过滤本类的寄存器组
  (define class-groups
    (for/fold ([groups (pvector-empty)])
              ([group (in-pvector all-groups)])
      (if (eq? (reg-group-class group) class)
          (pvector-cons-right groups group)
          groups)))

  ;; 类内跨调用活跃 intbits
  (define class-live-across-call
    (for/fold ([bs intbits-empty])
              ([pair (in-list reg-pairs)]
               [idx (in-naturals)])
      (define global-idx (car pair))
      (if (intbits-ref live-across-call global-idx)
          (intbits-set bs idx)
          bs)))

  ;; 添加干涉边
  (define g-with-edges
    (add-class-interference-edges g fn liveness class-reg-index
                                  global->class class))

  ;; 添加组内干涉边
  (define g-with-group-edges
    (add-group-interference-edges g-with-edges class-groups class-reg-index))

  ;; 添加显式干涉约束边
  (define g-with-constraint-edges
    (add-explicit-interference-edges g-with-group-edges
                                     all-interference-constraints
                                     class-reg-index
                                     class))

  (class-ig class g-with-constraint-edges
            class-reg-index class-index-reg
            precolored colors class-move-edges class-groups
            class-live-across-call num-colors))

;; 添加类内干涉边
(define (add-class-interference-edges g fn liveness class-reg-index
                                       global->class class)
  (define index-reg (fn-liveness-index-reg liveness))

  (for/fold ([current-g g])
            ([kv (in-intmap-pairs (asm-function-blocks fn))])
    (define block (cdr kv))
    (define bb-id (basic-block-id block))
    (define instructions (basic-block-instructions block))
    (define n-instructions (pvector-length instructions))
    (define live (get-live-out liveness bb-id))

    (define-values (block-g _)
      (for/fold ([g current-g] [live live])
                ([i (in-range (sub1 n-instructions) -1 -1)])
        (define ins (pvector-ref instructions i))
        (if (ast-ins? ins)
            (let* ([use-def (extract-use-def ins)]
                   [defs (use-def-flat-defs use-def)]
                   [uses (use-def-flat-uses use-def)])

              ;; 添加 def 和 live 变量之间的干涉（仅限本类）
              (define g-with-def-interference
                (for/fold ([g g])
                          ([def-ref (in-list defs)])
                  (define def-id (reg-ref->reg-id def-ref))
                  (when (not (eq? (reg-id-class def-id) class))
                    (set! g g))  ; 跳过非本类
                  (if (not (eq? (reg-id-class def-id) class))
                      g
                      (let ([def-idx (reg-om-ref class-reg-index def-id #f)])
                        (if (not def-idx)
                            g
                            (for/fold ([g g])
                                      ([live-idx (in-intbits live)])
                              (define live-reg (pvector-ref index-reg live-idx))
                              (if (not (eq? (reg-id-class live-reg) class))
                                  g
                                  (let ([live-class-idx (and (< live-idx (vector-length global->class))
                                                            (vector-ref global->class live-idx))])
                                    (if (or (not live-class-idx)
                                            (= def-idx live-class-idx))
                                        g
                                        (add-undirected-edge g def-idx live-class-idx))))))))))

              ;; 更新活跃集
              (define live-after-def
                (for/fold ([l live])
                          ([def-ref (in-list defs)])
                  (define def-id (reg-ref->reg-id def-ref))
                  (define idx (reg-om-ref (fn-liveness-reg-index liveness) def-id #f))
                  (if idx (intbits-clear l idx) l)))

              (define live-after-use
                (for/fold ([l live-after-def])
                          ([use-ref (in-list uses)])
                  (define use-id (reg-ref->reg-id use-ref))
                  (define idx (reg-om-ref (fn-liveness-reg-index liveness) use-id #f))
                  (if idx (intbits-set l idx) l)))

              (values g-with-def-interference live-after-use))
            (values g live))))

    block-g))

;; ============================================================
;; 辅助函数
;; ============================================================

;; 收集跨调用活跃信息（返回全局 intbits）
(define (collect-live-across-call fn liveness index-reg)
  (define result (box intbits-empty))

  (fn-for-each-block fn
    (lambda (block)
      (define bb-id (basic-block-id block))
      (define instructions (basic-block-instructions block))
      (define n-instructions (pvector-length instructions))
      (define live (get-live-out liveness bb-id))

      (for/fold ([live live])
                ([i (in-range (sub1 n-instructions) -1 -1)])
        (define ins (pvector-ref instructions i))
        (if (ast-ins? ins)
            (let* ([mnem (ast-ins-mnemonic ins)]
                   [use-def (extract-use-def ins)]
                   [defs (use-def-flat-defs use-def)]
                   [uses (use-def-flat-uses use-def)]
                   [is-call? (is-call-instruction? mnem)])

              (when is-call?
                (for ([live-idx (in-intbits live)])
                  (define live-reg (pvector-ref index-reg live-idx))
                  (when (reg-id-virtual? live-reg)
                    (set-box! result (intbits-set (unbox result) live-idx)))))

              (define live-after-def
                (for/fold ([l live])
                          ([def-ref (in-list defs)])
                  (define def-id (reg-ref->reg-id def-ref))
                  (define idx (reg-om-ref (fn-liveness-reg-index liveness) def-id #f))
                  (if idx (intbits-clear l idx) l)))

              (for/fold ([l live-after-def])
                        ([use-ref (in-list uses)])
                (define use-id (reg-ref->reg-id use-ref))
                (define idx (reg-om-ref (fn-liveness-reg-index liveness) use-id #f))
                (if idx (intbits-set l idx) l)))
            live))))

  (unbox result))

;; 收集寄存器组
(define (collect-reg-groups fn reg-index)
  (define groups (pvector-empty))
  (fn-for-each-block fn
    (lambda (block)
      (for ([ins (in-pvector (basic-block-instructions block))])
        (when (ast-ins? ins)
          (define use-def (extract-use-def ins))
          (define ud-groups (use-def-groups use-def))
          (for ([grp (in-list ud-groups)])
            (define refs (cadr grp))
            (when (> (length refs) 1)
              (define members
                (for/list ([ref (in-list refs)])
                  (reg-ref->reg-id ref)))
              (when (for/or ([m (in-list members)]) (reg-id-virtual? m))
                (define group (make-reg-group members))
                (set! groups (pvector-cons-right groups group)))))))))
  groups)

;; 收集 move 边
(define (collect-move-edges fn reg-index)
  (define edges (pvector-empty))
  (fn-for-each-block fn
    (lambda (block)
      (for ([ins (in-pvector (basic-block-instructions block))])
        (cond
          [(ast-ins? ins)
           (define mnem (ast-ins-mnemonic ins))
           (when (memq mnem '(mov fmov))
             (define use-def (extract-use-def ins))
             (define defs (use-def-flat-defs use-def))
             (define uses (use-def-flat-uses use-def))
             (when (and (= (length defs) 1)
                        (= (length uses) 1)
                        (eq? (reg-ref-position (car defs)) 'direct)
                        (eq? (reg-ref-position (car uses)) 'direct))
               (define src-id (reg-ref->reg-id (car uses)))
               (define dst-id (reg-ref->reg-id (car defs)))
               (when (coalescable-move-edge? src-id dst-id)
                 (set! edges (pvector-cons-right edges (move-edge src-id dst-id))))))]
          [(and (ast-directive? ins)
                (eq? (ast-directive-kind ins) 'weak-mov))
           (define args (ast-directive-args ins))
           (define dst-reg (first args))
           (define src-reg (second args))
           (define dst-id (ast-reg->reg-id dst-reg))
           (define src-id (ast-reg->reg-id src-reg))
              (when (coalescable-move-edge? src-id dst-id)
                (set! edges (pvector-cons-right edges (move-edge src-id dst-id))))]))))
  edges)

(define (collect-interference-constraints fn)
  (define constraints '())
  (fn-for-each-block fn
    (lambda (block)
      (for ([ins (in-pvector (basic-block-instructions block))])
        (when (and (ast-directive? ins)
                   (eq? (ast-directive-kind ins) 'reg-interfere))
          (match (ast-directive-args ins)
            [(list (? ast-reg? left) (? ast-reg? right))
             (set! constraints
                   (cons (cons (ast-reg->reg-id left)
                               (ast-reg->reg-id right))
                         constraints))]
            [_ (void)])))))
  (reverse constraints))

;; 为组内寄存器添加干涉边
(define (add-group-interference-edges g groups class-reg-index)
  (for/fold ([current-g g])
            ([group (in-pvector groups)])
    (define members (reg-group-members group))
    (for*/fold ([g current-g])
               ([i (in-range (length members))]
                [j (in-range (add1 i) (length members))])
      (define reg-i (list-ref members i))
      (define reg-j (list-ref members j))
      (define idx-i (reg-om-ref class-reg-index reg-i #f))
      (define idx-j (reg-om-ref class-reg-index reg-j #f))
      (if (and idx-i idx-j)
          (add-undirected-edge g idx-i idx-j)
          g))))

(define (add-explicit-interference-edges g constraints class-reg-index class)
  (for/fold ([current-g g])
            ([constraint (in-list constraints)])
    (define left (car constraint))
    (define right (cdr constraint))
    (if (and (eq? (reg-id-class left) class)
             (eq? (reg-id-class right) class))
        (let ([left-idx (reg-om-ref class-reg-index left #f)]
              [right-idx (reg-om-ref class-reg-index right #f)])
          (if (and left-idx right-idx (not (= left-idx right-idx)))
              (add-undirected-edge current-g left-idx right-idx)
              current-g))
        current-g)))

;; 从 ast-reg 转换为 reg-id
(define (ast-reg->reg-id reg)
  (define kind (ast-reg-kind reg))
  (define id (ast-reg-id reg))
  (define class
    (case kind
      [(x w) 'gpr]
      [(z v d s h b q) 'fpr]
      [(p) 'predicate]
      [else 'gpr]))
  (define virtual? (symbol? id))
  (define actual-id
    (cond
      [(eq? id 'sp) 31]
      [(eq? id 'zr) 31]
      [else id]))
  (reg-id class (canonical-width class) actual-id virtual?))

(define (is-call-instruction? mnem)
  (memq mnem '(bl blr)))

;; ============================================================
;; 跨调用 clobber 并集 (clobber-aware 分配)
;; ============================================================
;;
;; 对每个跨调用存活的虚拟 GPR，计算它跨越的所有调用的"实际 GPR clobber
;; 集"的并集 (来自 abi-info-map 的 inferred gpr-def，已跨过程传递闭包)。
;; 分配器据此只把这些寄存器排除在"被实际 clobber 的物理寄存器"之外，而非
;; 保守地排除全部 caller-saved —— 从而跨越轻量被调方 (保留大部分寄存器) 的
;; 值可留在 caller-saved 寄存器里，不必进 callee-saved 或溢出。
;;
;; 返回 reg-om[reg-id -> phys-gpr-intbits]。

(define (abi-caller-saved-gpr-intbits abi)
  (define cfg (abi-get-class-config abi 'gpr))
  (if cfg
      (intbits-subtract (reg-allocatable cfg) (reg-callee-saved cfg))
      intbits-empty))

;; 某个调用指令 clobber 的 GPR 集（对调用方可用寄存器而言的 sound 上界）：
;;   直接 bl 到有声明 ABI 的目标 -> 该 ABI 的 caller-saved (allocatable−preserved)。
;;     依据 ABI 契约：被调方只会 clobber 自身 caller-saved，preserved 的会保存恢复；
;;     被调方 banned 的寄存器 (如 x16/x17 spill 临时) 在调用方也 banned，故遗漏无害。
;;   无声明 ABI / blr / 未知目标 -> 保守全部 caller-saved (default-clob)。
;; lr(x30)：bl/blr 一定会写 lr (返回地址)，故 lr 恒在 clobber 集里，
;; 否则跨调用值可能被分配到 x30 而被调用指令本身破坏。
(define lr-clobber (intbits-set intbits-empty 30))

(define (call-target-clobber-gpr ins abi-info-map default-clob)
  (match ins
    [(ast-ins 'bl _ (list (ast-label name _ _)) _)
     (define info (and abi-info-map (get-function-abi-info abi-info-map name)))
     (define callee-abi (and info (function-abi-info-declared-abi info)))
     (intbits-union lr-clobber
                   (if callee-abi
                       (let ([cfg (abi-config-gpr callee-abi)])
                         (intbits-subtract (reg-allocatable cfg) (reg-callee-saved cfg)))
                       default-clob))]
    [_ (intbits-union lr-clobber default-clob)]))

(define (compute-clobber-union-map fn liveness abi abi-info-map)
  (define index-reg (fn-liveness-index-reg liveness))
  (define reg-index (fn-liveness-reg-index liveness))
  (define default-clob (abi-caller-saved-gpr-intbits abi))
  (define result (box reg-om-empty))
  (fn-for-each-block fn
    (lambda (block)
      (define instrs (basic-block-instructions block))
      (define n (pvector-length instrs))
      (define live0 (get-live-out liveness (basic-block-id block)))
      (for/fold ([live live0])
                ([i (in-range (sub1 n) -1 -1)])
        (define ins (pvector-ref instrs i))
        (cond
          [(ast-ins? ins)
           (define mnem (ast-ins-mnemonic ins))
           (define ud (extract-use-def ins))
           (when (is-call-instruction? mnem)
             (define clob (call-target-clobber-gpr ins abi-info-map default-clob))
             (for ([idx (in-intbits live)])
               (define r (pvector-ref index-reg idx))
               (when (and (reg-id-virtual? r) (eq? (reg-id-class r) 'gpr))
                 (set-box! result
                           (reg-om-set (unbox result) r
                                            (intbits-union
                                             (reg-om-ref (unbox result) r intbits-empty)
                                             clob))))))
           (define live1
             (for/fold ([l live]) ([d (in-list (use-def-flat-defs ud))])
               (define idx (reg-om-ref reg-index (reg-ref->reg-id d) #f))
               (if idx (intbits-clear l idx) l)))
           (for/fold ([l live1]) ([u (in-list (use-def-flat-uses ud))])
             (define idx (reg-om-ref reg-index (reg-ref->reg-id u) #f))
             (if idx (intbits-set l idx) l))]
          [else live]))))
  (unbox result))

(define (internal-snapshot-reg-id? rid)
  (and (reg-id-virtual? rid)
       (symbol? (reg-id-id rid))
       (regexp-match? #rx"^__asmp_.*\\$" (symbol->string (reg-id-id rid)))))

(define (coalescable-move-edge? src-id dst-id)
  (and (eq? (reg-id-class src-id) (reg-id-class dst-id))
       (not (internal-snapshot-reg-id? src-id))
       (not (internal-snapshot-reg-id? dst-id))))

(define (add-undirected-edge g v1 v2)
  (if (ugraph-has-edge? g v1 v2)
      g
      (ugraph-add-edge g v1 v2)))

;; ============================================================
;; 查询函数 (class-ig)
;; ============================================================

(define (ig-class ig)
  (class-ig-class ig))

(define (ig-reg-index ig)
  (class-ig-reg-index ig))

(define (ig-index-reg ig)
  (class-ig-index-reg ig))

;; 返回邻居列表 (兼容旧 API)
(define (ig-neighbors ig reg)
  (define idx (reg-om-ref (class-ig-reg-index ig) reg #f))
  (if idx
      (for/list ([neighbor-idx (in-ugraph-neighbors (class-ig-graph ig) idx)])
        (pvector-ref (class-ig-index-reg ig) neighbor-idx))
      '()))

;; 新增：直接返回邻居 intbits (高效)
(define (ig-neighbors/intbits ig reg)
  (define idx (reg-om-ref (class-ig-reg-index ig) reg #f))
  (if idx
      (ugraph-neighbors (class-ig-graph ig) idx)
      intbits-empty))

(define (ig-degree ig reg)
  (define idx (reg-om-ref (class-ig-reg-index ig) reg #f))
  (if idx (ugraph-degree (class-ig-graph ig) idx) 0))

(define (ig-interferes? ig reg1 reg2)
  (define idx1 (reg-om-ref (class-ig-reg-index ig) reg1 #f))
  (define idx2 (reg-om-ref (class-ig-reg-index ig) reg2 #f))
  (and idx1 idx2 (ugraph-has-edge? (class-ig-graph ig) idx1 idx2)))

(define (ig-is-precolored? ig reg)
  (reg-id-physical? reg))

(define (ig-get-color ig reg)
  (define idx (reg-om-ref (class-ig-reg-index ig) reg #f))
  (and idx (intmap-ref (class-ig-colors ig) idx #f)))

(define (ig-move-related? ig reg)
  (for/or ([edge (in-pvector (class-ig-move-edges ig))])
    (or (equal? (move-edge-src edge) reg)
        (equal? (move-edge-dst edge) reg))))

(define (ig-get-move-edges ig reg)
  (for/list ([edge (in-pvector (class-ig-move-edges ig))]
             #:when (or (equal? (move-edge-src edge) reg)
                        (equal? (move-edge-dst edge) reg)))
    edge))

(define (ig-num-colors ig)
  (class-ig-num-colors ig))

(define (ig-get-groups ig)
  (class-ig-groups ig))

(define (ig-live-across-call? ig reg-idx)
  (intbits-ref (class-ig-live-across-call ig) reg-idx))

(define (ig-get-live-across-call ig)
  (class-ig-live-across-call ig))

;; ============================================================
;; 查询函数 (multi-class-ig)
;; ============================================================

(define (mig-gpr mig) (multi-class-ig-gpr mig))
(define (mig-fpr mig) (multi-class-ig-fpr mig))
(define (mig-pred mig) (multi-class-ig-pred mig))

(define (mig-get-class-ig mig class)
  (case class
    [(gpr) (multi-class-ig-gpr mig)]
    [(fpr) (multi-class-ig-fpr mig)]
    [(predicate) (multi-class-ig-pred mig)]
    [else #f]))

;; ============================================================
;; 格式化
;; ============================================================

(define (format-class-ig ig)
  (define lines '())
  (define (add-line! s) (set! lines (cons s lines)))

  (add-line! (format "=== ~a 干涉图 ===" (class-ig-class ig)))
  (add-line! (format "顶点数: ~a" (ugraph-vertex-count (class-ig-graph ig))))
  (add-line! (format "边数: ~a" (ugraph-edge-count (class-ig-graph ig))))
  (add-line! (format "Move 边数: ~a" (pvector-length (class-ig-move-edges ig))))
  (add-line! (format "寄存器组数: ~a" (pvector-length (class-ig-groups ig))))
  (add-line! (format "可用颜色: ~a" (class-ig-num-colors ig)))
  (add-line! "")
  (add-line! "顶点:")

  (for ([kv (in-reg-om (class-ig-reg-index ig))])
    (define reg (car kv))
    (define neighbors (ig-neighbors ig reg))
    (define precolored? (reg-id-physical? reg))
    (define color (ig-get-color ig reg))
    (add-line! (format "  ~a~a: [度数=~a]~a -> { ~a }"
                       (format-reg-id-short reg)
                       (if precolored? "*" "")
                       (ig-degree ig reg)
                       (if color (format " 颜色=~a" color) "")
                       (string-join (map format-reg-id-short neighbors) ", "))))

  (when (> (pvector-length (class-ig-move-edges ig)) 0)
    (add-line! "")
    (add-line! "Move 边:")
    (for ([edge (in-pvector (class-ig-move-edges ig))])
      (add-line! (format "  ~a <- ~a"
                         (format-reg-id-short (move-edge-dst edge))
                         (format-reg-id-short (move-edge-src edge))))))

  (string-join (reverse lines) "\n"))

(define (format-multi-class-ig mig)
  (string-join
   (filter values
           (list (and (mig-gpr mig) (format-class-ig (mig-gpr mig)))
                 (and (mig-fpr mig) (format-class-ig (mig-fpr mig)))
                 (and (mig-pred mig) (format-class-ig (mig-pred mig)))))
   "\n\n"))

(define (format-reg-id-short r)
  (define prefix
    (case (reg-id-class r)
      [(gpr) (if (= (reg-id-width r) 32) "w" "x")]
      [(fpr) (case (reg-id-width r) [(32) "s"] [(64) "d"] [else "v"])]
      [(predicate) "p"]
      [else "?"]))
  (if (reg-id-virtual? r)
      (format "~a.~a" prefix (reg-id-id r))
      (format "~a~a" prefix (reg-id-id r))))
