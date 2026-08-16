#lang racket

;; ============================================================
;; pipeline/regalloc/rewriter.rkt - 指令重写
;; ============================================================

(require "../../semantic/control-flow.rkt"
         "../../semantic/use-def.rkt"
         "../../parser/ast.rkt"
         "types.rkt"
         "allocator.rkt"
         "abi.rkt"
         "abi-infer.rkt"
         racket/pvector
         racket/intmap
         racket/intbits)

(provide
  rewrite-function
  compute-frame-size
  compute-spill-slots
  format-spill-slots
  detect-frame-pointer)

;; ============================================================
;; 栈帧布局
;; ============================================================

;; 检测函数是否建立了 frame pointer
;; 方式 1: (: save! ...) + (mov x29 sp) / (mov fp sp)
;; 方式 2: (stp x29 x30 (sp -16 !)) + (mov x29 sp) / (mov fp sp)
;; 返回 'fp-established 如果检测到
;; 返回 #f 否则 - 此时禁用基于栈的 spilling
(define (detect-frame-pointer fn)
  (define entry-bb (fn-entry-block fn))
  (and entry-bb
       (let ([instructions (basic-block-instructions entry-bb)])
         ;; 检查是否有 (: save ...) 指令
         (define has-save!?
           (for/or ([i (in-range (min 5 (pvector-length instructions)))])
             (define ins (pvector-ref instructions i))
             (and (ast-directive? ins)
                  (eq? (ast-directive-kind ins) 'save!))))

         ;; 检查是否有手动的 stp x29 x30 [sp, #-16]! 序言
         (define has-manual-prologue?
           (for/or ([i (in-range (min 5 (pvector-length instructions)))])
             (define ins (pvector-ref instructions i))
             (and (ast-ins? ins)
                  (eq? (ast-ins-mnemonic ins) 'stp)
                  (let ([ops (ast-ins-operands ins)])
                    (and (>= (length ops) 3)
                         (ast-reg? (car ops))
                         (ast-reg? (cadr ops))
                         (ast-mem? (caddr ops))
                         (let ([r1 (car ops)]
                               [r2 (cadr ops)]
                               [mem (caddr ops)])
                           ;; 检查是 x29 x30 或 fp lr
                           (and (or (and (eq? (ast-reg-kind r1) 'x)
                                         (or (eq? (ast-reg-id r1) 29)
                                             (eq? (ast-reg-id r1) 'fp)))
                                    (eq? (ast-reg-id r1) 'fp))
                                (or (and (eq? (ast-reg-kind r2) 'x)
                                         (or (eq? (ast-reg-id r2) 30)
                                             (eq? (ast-reg-id r2) 'lr)))
                                    (eq? (ast-reg-id r2) 'lr))
                                ;; 检查内存操作数是 pre-index 到 sp
                                (eq? (ast-mem-index-mode mem) 'pre)
                                (ast-reg? (ast-mem-base mem))
                                (eq? (ast-reg-id (ast-mem-base mem)) 'sp))))))))

         ;; 只有在有 save! 或手动序言的情况下才检查 mov fp sp
         (and (or has-save!? has-manual-prologue?)
              (for/or ([i (in-range (min 10 (pvector-length instructions)))])
                (define ins (pvector-ref instructions i))
                (and (ast-ins? ins)
                     (eq? (ast-ins-mnemonic ins) 'mov)
                     (let ([ops (ast-ins-operands ins)])
                       (and (= (length ops) 2)
                            (ast-reg? (car ops))
                            (ast-reg? (cadr ops))
                            (let ([dst (car ops)]
                                  [src (cadr ops)])
                              (and (or (and (eq? (ast-reg-kind dst) 'x)
                                            (eq? (ast-reg-id dst) 29))
                                       (eq? (ast-reg-id dst) 'fp))
                                   (eq? (ast-reg-id src) 'sp)
                                   'fp-established))))))))))

(define (compute-spill-slots spilled-regs)
  (define current-offset 0)
  (for/fold ([slots (pvector-empty)])
            ([reg (in-pvector spilled-regs)])
    (define size (case (reg-id-width reg)
                   [(8) 1] [(16) 2] [(32) 4] [(64) 8] [(128) 16] [else 8]))
    (define aligned-offset (* (quotient (+ current-offset (sub1 size)) size) size))
    (set! current-offset (+ aligned-offset size))
    (pvector-cons-right slots (spill-slot aligned-offset size reg))))

(define (compute-frame-size spill-slots #:extra-size [extra 0])
  (define spill-size
    (if (pvector-empty? spill-slots) 0
        (let ([last-slot (pvector-ref spill-slots (sub1 (pvector-length spill-slots)))])
          (+ (spill-slot-offset last-slot) (spill-slot-size last-slot)))))
  (* (quotient (+ spill-size extra 15) 16) 16))

(define (sp-reg)
  (ast-reg 'x 'sp #f #f #f #f no-srcloc))

(define (make-sp-adjust-instruction mnemonic amount [loc no-srcloc])
  (ast-ins mnemonic #f
           (list (sp-reg)
                 (sp-reg)
                 (ast-imm amount no-srcloc))
           loc))

;; ============================================================
;; 重物化 (rematerialization)
;; ============================================================
;;
;; 一个被溢出的虚拟寄存器，若其值可由"无寄存器输入的立即数指令链"
;; (movz/movn 起头 + 可选 movk) 重建，则不必分配栈槽 spill/reload，
;; 而是在每个使用点重新执行该指令链 (重物化)。这消除了 spill store、
;; 栈槽，并把每次 4-cyc 的 reload 换成 1-3 条无访存的 mov。
;;
;; 安全条件 (总是正确)：
;;   - 该虚拟寄存器被溢出且属 gpr；
;;   - 其所有 def 都是 movz/movn/movk 且除目的寄存器外无寄存器操作数；
;;   - 其所有 def 位置 < 其所有 use 位置 (整条链先构建后使用，
;;     故重建完整链在任意使用点都等于原值)。

;; 判断指令是否是"仅立即数输入"的 mov (movz/movn/movk)
(define (immediate-mov-ins? ins)
  (match ins
    [(ast-ins mnem _ operands _)
     (and (memq mnem '(movz movn movk))
          ;; 恰好一个寄存器操作数 (目的寄存器)
          (= 1 (for/sum ([op (in-list operands)]) (if (ast-reg? op) 1 0))))]
    [_ #f]))

;; 分析函数，返回 (values remat-map remat-def-set)
;;   remat-map    : reg-om[reg-id -> (listof ast-ins)]  重建配方 (按序)
;;   remat-def-set: hasheq[ast-ins -> #t]  构成配方的 def 指令 (重写时删除)
(define (analyze-remat fn spilled)
  (define spilled-set
    (for/fold ([m reg-om-empty])
              ([r (in-pvector spilled)])
      (reg-om-set m r #t)))
  (define def-info (make-hash))      ; reg-id -> (listof (cons pos ins))
  (define use-min (make-hash))       ; reg-id -> 最早 use 位置
  (define all-immediate (make-hash)) ; reg-id -> 是否所有 def 都是 immediate-mov
  (define pos (box 0))
  (fn-for-each-block fn
    (lambda (block)
      (for ([ins (in-pvector (basic-block-instructions block))])
        (when (ast-ins? ins)
          (define p (unbox pos))
          (define ud (extract-use-def ins))
          (define imm? (immediate-mov-ins? ins))
          (define def-ids
            (for/list ([dref (in-list (use-def-flat-defs ud))])
              (reg-ref->reg-id dref)))
          (for ([rid (in-list def-ids)])
            (when (reg-id-virtual? rid)
              (hash-update! def-info rid (lambda (l) (cons (cons p ins) l)) '())
              (hash-update! all-immediate rid (lambda (b) (and b imm?)) #t)))
          (for ([uref (in-list (use-def-flat-uses ud))])
            (define rid (reg-ref->reg-id uref))
            (when (reg-id-virtual? rid)
              ;; movk 会读取自身目的寄存器，属链内自用，不计为 use
              (unless (and imm? (member rid def-ids))
                (hash-update! use-min rid (lambda (mn) (min mn p)) p)))))
        (set-box! pos (add1 (unbox pos))))))
  (define remat-def-set (make-hasheq))
  (define remat-map
    (for/fold ([m reg-om-empty])
              ([(rid defs) (in-hash def-info)])
      (cond
        [(and (reg-om-ref spilled-set rid #f)
              (hash-ref all-immediate rid #f)
              (eq? (reg-id-class rid) 'gpr))
         (define sorted (sort defs < #:key car))
         (define max-def-pos (car (last sorted)))
         (define min-use (hash-ref use-min rid #f))
         (cond
           [(and min-use (< max-def-pos min-use))
            (for ([pi (in-list sorted)]) (hash-set! remat-def-set (cdr pi) #t))
            (reg-om-set m rid (map cdr sorted))]
           [else m])]
        [else m])))
  (values remat-map remat-def-set))

;; 把配方按序重建到物理临时寄存器 temp-num (把配方里目的虚拟寄存器替换为 temp)
(define (rewrite-remat-recipe recipe orig-reg temp-num loc)
  (define vid (reg-id-id orig-reg))
  (for/list ([rins (in-list recipe)])
    (match rins
      [(ast-ins mnem suffix operands _)
       (ast-ins mnem suffix
                (map (lambda (op)
                       (match op
                         [(ast-reg kind id gs idx el pm l)
                          (if (equal? id vid)
                              (ast-reg kind temp-num gs idx el pm l)
                              op)]
                         [_ op]))
                     operands)
                loc)]
      [_ rins])))

;; ============================================================
;; 指令重写
;; ============================================================

(define (rewrite-function fn alloc-result #:abi [abi arm64-abi] #:abi-info-map [abi-info-map #f])
  (define assignment (alloc-result-assignment alloc-result))
  (define spilled-all (alloc-result-spilled alloc-result))
  (define coalesced (alloc-result-coalesced alloc-result))
  ;; 重物化分析：把可由立即数链重建的溢出寄存器从"栈槽 spill"中剔除，
  ;; 改为使用点重建 (见 analyze-remat)。
  (define-values (remat-map remat-def-set) (analyze-remat fn spilled-all))
  (define spilled
    (for/fold ([acc (pvector-empty)])
              ([r (in-pvector spilled-all)])
      (if (reg-om-ref remat-map r #f) acc (pvector-cons-right acc r))))
  (define spill-slots (compute-spill-slots spilled))
  (define spill-stack-size (compute-frame-size spill-slots))

  ;; 检测是否建立了 frame pointer
  (define use-fp? (detect-frame-pointer fn))

  ;; 检测函数中的 SP 修改量（用于调整 FP-based spill 偏移）
  (define sp-adjustment (detect-sp-adjustment fn))

  ;; 收集函数中使用的 NEON 寄存器（本函数直接使用的）
  (define used-neon-regs (collect-used-neon-regs fn))

  ;; 收集所有被调函数 clobber 的 FPR 寄存器（invoke-abi 视图）
  (define call-clobbered-fpr (collect-call-clobbered-fpr fn abi-info-map))

  ;; NEON scratch 寄存器 (v16-v31)
  ;; 排除：本函数使用的 + 被调函数会 clobber 的
  (define unavailable-neon
    (intbits-union used-neon-regs call-clobbered-fpr))

  (define available-neon-spill-regs
    (for/list ([i (in-range 16 32)]  ; v16-v31
               #:unless (intbits-ref unavailable-neon i))
      i))

  ;; 统计 GPR spills
  (define num-gpr-spills (count-gpr-spills spilled))

  ;; 决定 spill 策略
  ;; 1. 优先使用 FP-based 栈 spilling（当 FP 建立且有 SP 调整信息时）
  ;; 2. 其次使用安全的 NEON 寄存器（不被调用 clobber 的）
  (define spill-strategy
    (cond
      ;; 有 FP 建立，优先使用 FP-based 栈 spilling
      [use-fp?
       'fp-stack]
      ;; 有足够的安全 NEON 寄存器可用
      [(<= num-gpr-spills (length available-neon-spill-regs))
       'neon-regs]
      ;; 无法 spill - 输出详细调试信息
      [else
       (define callee-info
         (if abi-info-map
             (format "\n调用的函数 clobber 的 FPR: ~a" (intbits->list call-clobbered-fpr))
             "\n(无 ABI 信息，假设所有 caller-saved FPR 被 clobber)"))
       (error 'rewrite-function
              "函数 ~a 需要 spill ~a 个 GPR 寄存器:\n  - 没有建立栈帧 (需要 stp x29 x30 + mov x29 sp)\n  - 本函数使用的 FPR: ~a\n  - 可用 NEON scratch 寄存器: ~a~a\n建议: 添加 (stp x29 x30 [sp, #-16]!) 和 (mov x29 sp) 建立栈帧。"
              (asm-function-name fn) num-gpr-spills
              (intbits->list used-neon-regs)
              (length available-neon-spill-regs)
              callee-info)]))

  (define spill-map
    (for/fold ([m reg-om-empty])
              ([slot (in-pvector spill-slots)])
      (reg-om-set m (spill-slot-reg slot) slot)))

  ;; 为 NEON spill 分配寄存器
  (define neon-spill-map
    (if (eq? spill-strategy 'neon-regs)
        (assign-neon-spill-regs spilled available-neon-spill-regs)
        reg-om-empty))

  (define new-blocks
    (for/fold ([blocks (asm-function-blocks fn)])
              ([kv (in-intmap-pairs (asm-function-blocks fn))])
      (define bb-key (car kv))
      (define block (cdr kv))
      (define entry-block (fn-entry-block fn))
      (define insert-fp-spill-prologue?
        (and (eq? spill-strategy 'fp-stack)
             (> spill-stack-size 0)
             entry-block
             (equal? bb-key (bb-id-val (basic-block-id entry-block)))))
      (define new-block (rewrite-block block assignment coalesced spill-map abi
                                        spill-strategy neon-spill-map sp-adjustment
                                        remat-map remat-def-set
                                        #:insert-fp-spill-prologue? insert-fp-spill-prologue?
                                        #:fp-spill-stack-size spill-stack-size))
      (intmap-set blocks bb-key new-block)))

  (struct-copy asm-function fn [blocks new-blocks]))

;; 收集所有被调函数 clobber 的 FPR 寄存器
(define (collect-call-clobbered-fpr fn abi-info-map)
  (define clobbered intbits-empty)
  (fn-for-each-block fn
    (lambda (block)
      (for ([ins (in-pvector (basic-block-instructions block))])
        (when (ast-ins? ins)
          (define mnem (ast-ins-mnemonic ins))
          (when (memq mnem '(bl blr))
            (define target (get-call-target-name ins))
            (define callee-abi (get-callee-fpr-def target abi-info-map))
            (set! clobbered (intbits-union clobbered callee-abi)))))))
  clobbered)

;; 获取调用目标函数名
(define (get-call-target-name ins)
  (define ops (ast-ins-operands ins))
  (and (pair? ops)
       (ast-label? (car ops))
       (ast-label-name (car ops))))

;; 获取被调函数的 FPR def 集合
(define (get-callee-fpr-def target abi-info-map)
  (cond
    ;; 有 ABI 信息，使用实际推断的 fpr-def
    [(and target abi-info-map (hash-ref abi-info-map target #f))
     => (lambda (info)
          (inferred-abi-fpr-def (function-abi-info-inferred-abi info)))]
    ;; 无 ABI 信息，保守假设所有 caller-saved FPR 被 clobber (v0-v31)
    ;; 但 v8-v15 是 callee-saved 的低 64 位，不会被 clobber
    ;; 保守起见，假设 v0-v7 和 v16-v31 被 clobber
    [else
     (intbits-union
       (for/intbits ([i (in-range 0 8)]) i)    ; v0-v7
       (for/intbits ([i (in-range 16 32)]) i))])) ; v16-v31

;; intbits 转 list（用于调试输出）
(define (intbits->list bs)
  (for/list ([i (in-intbits bs)]) i))

;; 检测函数中的 SP 调整量
;; 返回最大的 sub sp sp N 值
(define (detect-sp-adjustment fn)
  (define max-adj 0)
  (fn-for-each-block fn
    (lambda (block)
      (for ([ins (in-pvector (basic-block-instructions block))])
        (when (ast-ins? ins)
          (define mnem (ast-ins-mnemonic ins))
          (define ops (ast-ins-operands ins))
          ;; 检测 sub sp sp N
          (when (and (eq? mnem 'sub)
                     (= (length ops) 3)
                     (ast-reg? (car ops))
                     (ast-reg? (cadr ops))
                     (ast-imm? (caddr ops))
                     (eq? (ast-reg-id (car ops)) 'sp)
                     (eq? (ast-reg-id (cadr ops)) 'sp))
            (define adj (ast-imm-value (caddr ops)))
            (when (> adj max-adj)
              (set! max-adj adj)))))))
  max-adj)

;; 收集函数中使用的 NEON 寄存器
(define (collect-used-neon-regs fn)
  (define used intbits-empty)
  (fn-for-each-block fn
    (lambda (block)
      (for ([ins (in-pvector (basic-block-instructions block))])
        (when (ast-ins? ins)
          (for ([op (in-list (ast-ins-operands ins))])
            (when (ast-reg? op)
              (define kind (ast-reg-kind op))
              (define id (ast-reg-id op))
              (when (and (memq kind '(v q d s h b))
                         (number? id))
                (set! used (intbits-set used id)))))))))
  used)

;; 统计 GPR spills
(define (count-gpr-spills spilled)
  (for/sum ([reg (in-pvector spilled)])
    (if (eq? (reg-id-class reg) 'gpr) 1 0)))

;; 为 GPR spills 分配 NEON 寄存器
(define (assign-neon-spill-regs spilled available-neon-regs)
  (define neon-idx 0)
  (for/fold ([m reg-om-empty])
            ([reg (in-pvector spilled)]
             #:when (eq? (reg-id-class reg) 'gpr))
    (when (>= neon-idx (length available-neon-regs))
      (error 'assign-neon-spill-regs "NEON 寄存器不足"))
    (define neon-reg (list-ref available-neon-regs neon-idx))
    (set! neon-idx (add1 neon-idx))
    (reg-om-set m reg neon-reg)))

(define (frame-pointer-setup-ins? ins)
  (and (ast-ins? ins)
       (eq? (ast-ins-mnemonic ins) 'mov)
       (let ([ops (ast-ins-operands ins)])
         (and (= (length ops) 2)
              (ast-reg? (car ops))
              (ast-reg? (cadr ops))
              (or (and (eq? (ast-reg-kind (car ops)) 'x)
                       (equal? (ast-reg-id (car ops)) 29))
                  (equal? (ast-reg-id (car ops)) 'fp))
              (equal? (ast-reg-id (cadr ops)) 'sp)))))

(define (load-directive? ins)
  (and (ast-directive? ins)
       (eq? (ast-directive-kind ins) 'load!)))

;; `mov sp, fp` —— 手动栈帧拆除 (用户函数自己恢复 sp)。存在时 rewriter 不应再插
;; `add sp,#spillsize` 反预留 (会把 sp 抬过头)。
(define (restore-sp-from-fp-ins? ins)
  (and (ast-ins? ins)
       (eq? (ast-ins-mnemonic ins) 'mov)
       (let ([ops (ast-ins-operands ins)])
         (and (= (length ops) 2)
              (ast-reg? (car ops)) (ast-reg? (cadr ops))
              (equal? (ast-reg-id (car ops)) 'sp)
              (or (equal? (ast-reg-id (cadr ops)) 29)
                  (equal? (ast-reg-id (cadr ops)) 'fp))))))

(define (rewrite-block block assignment coalesced spill-map abi
                        spill-strategy neon-spill-map sp-adjustment
                        remat-map remat-def-set
                        #:insert-fp-spill-prologue? [insert-fp-spill-prologue? #f]
                        #:fp-spill-stack-size [fp-spill-stack-size 0])
  (define instructions (basic-block-instructions block))
  ;; 用户函数若自行 `mov sp, fp` 拆帧, 跳过 rewriter 的反预留 add。
  (define manual-sp-teardown?
    (for/or ([ins (in-pvector instructions)]) (restore-sp-from-fp-ins? ins)))
  (define-values (rewritten-instructions _)
    (for/fold ([result (pvector-empty)]
               [inserted-prologue? #f])
              ([ins (in-pvector instructions)])
      (cond
        ;; 重物化：删除构成配方的立即数 def 指令 (值将在使用点重建)
        [(hash-ref remat-def-set ins #f)
         (values result inserted-prologue?)]
        [(ast-ins? ins)
         (define result*
           (rewrite-instruction ins result assignment coalesced spill-map abi
                                spill-strategy neon-spill-map sp-adjustment
                                remat-map))
         (if (and insert-fp-spill-prologue?
                  (not inserted-prologue?)
                  (> fp-spill-stack-size 0)
                  (frame-pointer-setup-ins? ins))
             (values (pvector-cons-right
                      result*
                      (make-sp-adjust-instruction 'sub fp-spill-stack-size
                                                  (ast-srcloc ins)))
                     #t)
             (values result* inserted-prologue?))]
        [(and (load-directive? ins)
              (eq? spill-strategy 'fp-stack)
              (> fp-spill-stack-size 0)
              (not manual-sp-teardown?))
         (values (pvector-cons-right
                  (pvector-cons-right
                   result
                   (make-sp-adjust-instruction 'add fp-spill-stack-size
                                               (ast-srcloc ins)))
                  ins)
                 inserted-prologue?)]
        [else
         (values (pvector-cons-right result ins)
                 inserted-prologue?)])))
  (struct-copy basic-block block [instructions rewritten-instructions]))

(define (rewrite-instruction ins result assignment coalesced spill-map abi
                             spill-strategy neon-spill-map sp-adjustment
                             remat-map)
  (define use-def (extract-use-def ins))
  (define uses (use-def-flat-uses use-def))
  (define defs (use-def-flat-defs use-def))

  (define loads-needed
    (for/list ([ref (in-list uses)]
               #:when (reg-om-ref spill-map (reg-ref->reg-id ref) #f))
      (reg-ref->reg-id ref)))

  ;; 重物化的使用：不从栈槽 reload，而在此处重建
  (define remat-loads
    (for/list ([ref (in-list uses)]
               #:when (reg-om-ref remat-map (reg-ref->reg-id ref) #f))
      (reg-ref->reg-id ref)))

  (define stores-needed
    (for/list ([ref (in-list defs)]
               #:when (reg-om-ref spill-map (reg-ref->reg-id ref) #f))
      (reg-ref->reg-id ref)))

  (cond
    [(or (not (null? loads-needed)) (not (null? stores-needed)) (not (null? remat-loads)))
     (rewrite-with-spill ins result assignment coalesced spill-map loads-needed stores-needed abi
                         spill-strategy neon-spill-map sp-adjustment
                         remat-loads remat-map)]
    [else
     (define new-ins (substitute-registers ins assignment coalesced abi))
     (pvector-cons-right result new-ins)]))

(define (rewrite-with-spill ins result assignment coalesced spill-map loads-needed stores-needed abi
                            spill-strategy neon-spill-map sp-adjustment
                            remat-loads remat-map)
  (define source-loc (ast-srcloc ins))
  ;; 临时寄存器池
  ;; GPR: x16, x17 (IP registers)
  ;; FPR: v16-v23 (caller-saved, not argument registers)
  (define gpr-temps '(16 17))
  (define fpr-temps '(16 17 18 19 20 21 22 23))
  (define gpr-idx 0)
  (define fpr-idx 0)

  (define (allocate-temp class)
    (if (eq? class 'gpr)
        (let ([temp (list-ref gpr-temps gpr-idx)])
          (set! gpr-idx (modulo (add1 gpr-idx) (length gpr-temps)))
          temp)
        (let ([temp (list-ref fpr-temps fpr-idx)])
          (set! fpr-idx (modulo (add1 fpr-idx) (length fpr-temps)))
          temp)))

  (define load-temps
    (for/fold ([m reg-om-empty])
              ([reg (in-list loads-needed)])
      (reg-om-set m reg (allocate-temp (reg-id-class reg)))))

  ;; 重物化的使用也需要一个临时寄存器 (承载重建结果)
  (define remat-temps
    (for/fold ([m reg-om-empty])
              ([reg (in-list remat-loads)])
      (reg-om-set m reg (allocate-temp (reg-id-class reg)))))

  (define store-temps
    (for/fold ([m reg-om-empty])
              ([reg (in-list stores-needed)])
      (define existing (reg-om-ref load-temps reg #f))
      (if existing
          (reg-om-set m reg existing)
          (reg-om-set m reg (allocate-temp (reg-id-class reg))))))

  (define temp-map
    (let* ([m1 (for/fold ([m load-temps])
                         ([kv (in-reg-om remat-temps)])
                 (reg-om-set m (car kv) (cdr kv)))])
      (for/fold ([m m1])
                ([kv (in-reg-om store-temps)])
        (reg-om-set m (car kv) (cdr kv)))))

  ;; 先发射重物化配方 (把值重建进临时寄存器)
  (define result-with-remat
    (for/fold ([r result])
              ([reg (in-list remat-loads)])
      (define recipe (reg-om-ref remat-map reg))
      (define temp (reg-om-ref temp-map reg))
      (for/fold ([r2 r])
                ([rins (in-list (rewrite-remat-recipe recipe reg temp source-loc))])
        (pvector-cons-right r2 rins))))

  (define result-with-loads
    (for/fold ([r result-with-remat])
              ([reg (in-list loads-needed)])
      (define slot (reg-om-ref spill-map reg))
      (define temp (reg-om-ref temp-map reg))
      (define load-ins-list
        (case spill-strategy
          [(neon-regs)
           (define neon-reg (reg-om-ref neon-spill-map reg))
           (list (make-neon-load-instruction temp neon-reg reg source-loc))]
          [(fp-stack)
           (make-load-instruction temp slot reg #t sp-adjustment source-loc)]
          [else
           (make-load-instruction temp slot reg #f 0 source-loc)]))
      (for/fold ([r r]) ([i (in-list load-ins-list)]) (pvector-cons-right r i))))

  (define extended-assignment
    (for/fold ([m assignment])
              ([kv (in-reg-om temp-map)])
      (define reg (car kv))
      (define temp-reg-num (cdr kv))
      (reg-om-set m
                       reg
                       (reg-id (reg-id-class reg)
                               (canonical-width (reg-id-class reg))
                               temp-reg-num
                               #f))))

  (define new-ins (substitute-registers ins extended-assignment coalesced abi))
  (define result-with-ins (pvector-cons-right result-with-loads new-ins))

  (for/fold ([r result-with-ins])
            ([reg (in-list stores-needed)])
    (define slot (reg-om-ref spill-map reg))
    (define temp (reg-om-ref temp-map reg))
    (define store-ins-list
      (case spill-strategy
        [(neon-regs)
         (define neon-reg (reg-om-ref neon-spill-map reg))
         (list (make-neon-store-instruction temp neon-reg reg source-loc))]
        [(fp-stack)
         (make-store-instruction temp slot reg #t sp-adjustment source-loc)]
        [else
         (make-store-instruction temp slot reg #f 0 source-loc)]))
    (for/fold ([r r]) ([i (in-list store-ins-list)]) (pvector-cons-right r i))))

;; ldr/str 立即数偏移可编码范围: scaled (0..32760, 正) 或 unscaled ldur/stur (-256..255)。
;; 大用户栈帧 + FP 相对负偏移 spill 会超出 -256 → 需先把地址算进临时寄存器。
(define (spill-off-in-range? off) (and (>= off -256) (<= off 32760)))

;; 计算 spill slot 相对 base 的偏移量 (FP 负 / SP 正)。
;; FP 相对: spill 区由插入的 `sub sp,#spillsize` (在 `mov fp,sp` 之后, 用户 `sub sp`
;; 之前) 预留, 位于 [fp-spillsize, fp] —— 在用户栈帧之上。故偏移 = -(slot+size),
;; 不含 sp-adjustment (用户帧大小); 否则会与用户帧区间重叠 (SIGBUS)。
;; 无用户帧时 sp-adjustment=0, 与旧式一致 (行为不变)。
(define (spill-slot-offset* slot use-fp? sp-adjustment)
  (if use-fp?
      (- (+ (spill-slot-offset slot) (spill-slot-size slot)))
      (spill-slot-offset slot)))

(define (spill-reg-kind orig-reg)
  (define width (reg-id-width orig-reg))
  (case (reg-id-class orig-reg)
    [(gpr) (if (= width 32) 'w 'x)]
    [(fpr) (case width [(32) 's] [(64) 'd] [else 'q])]
    [else 'x]))

;; 为超范围偏移在 addr-tmp (GPR 编号) 内构造有效地址 base±|off|。
;; off 为编译期常量; |off|<=4095 用单条 sub/add 立即数; 否则 movz(+movk)+寄存器加减。
(define (make-addr-materialize addr-tmp base-reg off loc)
  (define mag (abs off))
  (define op (if (negative? off) 'sub 'add))
  (define addr (ast-reg 'x addr-tmp #f #f #f #f no-srcloc))
  (define base (ast-reg 'x base-reg #f #f #f #f no-srcloc))
  (if (<= mag 4095)
      (list (ast-ins op #f (list addr base (ast-imm mag no-srcloc)) loc))
      (let ([lo (bitwise-and mag #xffff)] [hi (arithmetic-shift mag -16)])
        (append
         (list (ast-ins 'movz #f (list addr (ast-imm lo no-srcloc)) loc))
         (if (> hi 0)
             (list (ast-ins 'movk #f (list addr (ast-imm hi no-srcloc)
                                           (ast-shift 'lsl 16 no-srcloc)) loc))
             '())
         (list (ast-ins op #f (list addr base addr) loc))))))

;; 返回指令列表 (通常 1 条; 超范围时先物化地址)。
(define (make-load-instruction temp-reg-num slot orig-reg use-fp? sp-adjustment [loc no-srcloc])
  (define reg-kind (spill-reg-kind orig-reg))
  (define base-reg (if use-fp? 29 'sp))
  (define offset (spill-slot-offset* slot use-fp? sp-adjustment))
  (define val (ast-reg reg-kind temp-reg-num #f #f #f #f no-srcloc))
  (cond
    [(spill-off-in-range? offset)
     (list (ast-ins 'ldr #f
             (list val (ast-mem (ast-reg 'x base-reg #f #f #f #f no-srcloc)
                                (ast-imm offset no-srcloc) 'offset #f #f no-srcloc))
             loc))]
    [(eq? (reg-id-class orig-reg) 'gpr)
     ;; 地址物化进 temp 本身 (先地址后值, 同一 GPR)
     (append (make-addr-materialize temp-reg-num base-reg offset loc)
             (list (ast-ins 'ldr #f
                     (list val (ast-mem (ast-reg 'x temp-reg-num #f #f #f #f no-srcloc)
                                        (ast-imm 0 no-srcloc) 'offset #f #f no-srcloc))
                     loc)))]
    [else (error 'make-load-instruction "spill offset ~a out of range for non-GPR" offset)]))

(define (make-store-instruction temp-reg-num slot orig-reg use-fp? sp-adjustment [loc no-srcloc])
  (define reg-kind (spill-reg-kind orig-reg))
  (define base-reg (if use-fp? 29 'sp))
  (define offset (spill-slot-offset* slot use-fp? sp-adjustment))
  (define val (ast-reg reg-kind temp-reg-num #f #f #f #f no-srcloc))
  (cond
    [(spill-off-in-range? offset)
     (list (ast-ins 'str #f
             (list val (ast-mem (ast-reg 'x base-reg #f #f #f #f no-srcloc)
                                (ast-imm offset no-srcloc) 'offset #f #f no-srcloc))
             loc))]
    [(eq? (reg-id-class orig-reg) 'gpr)
     ;; 值在 temp 中; 地址物化进另一个 IP 寄存器 (x16/x17)
     (define addr-tmp (if (= temp-reg-num 16) 17 16))
     (append (make-addr-materialize addr-tmp base-reg offset loc)
             (list (ast-ins 'str #f
                     (list val (ast-mem (ast-reg 'x addr-tmp #f #f #f #f no-srcloc)
                                        (ast-imm 0 no-srcloc) 'offset #f #f no-srcloc))
                     loc)))]
    [else (error 'make-store-instruction "spill offset ~a out of range for non-GPR" offset)]))

;; NEON spill: GPR -> NEON (fmov d, x)
(define (make-neon-store-instruction temp-reg-num neon-reg-num orig-reg [loc no-srcloc])
  (define width (reg-id-width orig-reg))
  (define src-kind (if (= width 32) 'w 'x))
  (define dst-kind (if (= width 32) 's 'd))
  (ast-ins 'fmov #f
           (list (ast-reg dst-kind neon-reg-num #f #f #f #f no-srcloc)
                 (ast-reg src-kind temp-reg-num #f #f #f #f no-srcloc))
           loc))

;; NEON restore: NEON -> GPR (fmov x, d)
(define (make-neon-load-instruction temp-reg-num neon-reg-num orig-reg [loc no-srcloc])
  (define width (reg-id-width orig-reg))
  (define dst-kind (if (= width 32) 'w 'x))
  (define src-kind (if (= width 32) 's 'd))
  (ast-ins 'fmov #f
           (list (ast-reg dst-kind temp-reg-num #f #f #f #f no-srcloc)
                 (ast-reg src-kind neon-reg-num #f #f #f #f no-srcloc))
           loc))

;; ============================================================
;; 寄存器替换
;; ============================================================

(define (substitute-registers ins assignment coalesced abi)
  (match ins
    [(ast-ins mnem suffix operands loc)
     (ast-ins mnem suffix
              (map (lambda (op) (substitute-operand op assignment coalesced abi)) operands)
              loc)]
    [_ ins]))

(define (substitute-operand op assignment coalesced abi)
  (match op
    [(ast-reg kind id group-size index element pred-mode loc)
     (define width (case kind [(x) 64] [(w) 32] [(z v q) 128] [(d) 64] [(s) 32] [(h) 16] [(b) 8] [else 64]))
     (define class (case kind [(x w) 'gpr] [(z v d s h b q) 'fpr] [(p) 'predicate] [else 'gpr]))
     (define virtual? (symbol? id))

     (if virtual?
         (let* ([rid (reg-id class (canonical-width class) id #t)]
                [direct-color-or-phys (reg-om-ref assignment rid #f)]
                [resolved-rid (reg-om-ref coalesced rid rid)]
                [color-or-phys (or direct-color-or-phys
                                   (reg-om-ref assignment resolved-rid #f))])
           (cond
             ;; Found a mapping - either an allocator color, or an explicit
             ;; physical reg-id used by rewrite-time spill temporaries.
             [color-or-phys
              (cond
                [(reg-id? color-or-phys)
                 (ast-reg kind (reg-id-id color-or-phys) group-size index element pred-mode loc)]
                [else
                 (let ([phys-num (abi-color->reg abi class color-or-phys)])
                   (if phys-num
                       (ast-reg kind phys-num group-size index element pred-mode loc)
                       op))])]
             ;; Check if resolved to a physical reg-id
             [(and (reg-id? resolved-rid) (reg-id-physical? resolved-rid))
              (ast-reg kind (reg-id-id resolved-rid) group-size index element pred-mode loc)]
             ;; No mapping found - keep original
             [else op]))
         op)]

    [(ast-mem base offset index-mode shift extend loc)
     (ast-mem (substitute-operand base assignment coalesced abi)
              (if offset (substitute-operand offset assignment coalesced abi) #f)
              index-mode shift extend loc)]

    [(ast-reglist regs loc)
     (ast-reglist (map (lambda (r) (substitute-operand r assignment coalesced abi)) regs) loc)]

    [_ op]))

;; ============================================================
;; 格式化
;; ============================================================

(define (format-spill-slots slots)
  (define lines '())
  (define (add-line! s) (set! lines (cons s lines)))

  (add-line! "=== 溢出槽 ===")
  (add-line! (format "数量: ~a" (pvector-length slots)))

  (when (> (pvector-length slots) 0)
    (add-line! "")
    (for ([slot (in-pvector slots)] [i (in-naturals)])
      (add-line! (format "  [~a] offset=~a size=~a reg=~a"
                         i (spill-slot-offset slot) (spill-slot-size slot)
                         (format-reg-id (spill-slot-reg slot))))))

  (add-line! "")
  (add-line! (format "栈帧大小: ~a 字节" (compute-frame-size slots)))
  (string-join (reverse lines) "\n"))

(define (format-reg-id r)
  (define prefix (case (reg-id-class r) [(gpr) "x"] [(fpr) "v"] [else "?"]))
  (if (reg-id-virtual? r)
      (format "~a.~a" prefix (reg-id-id r))
      (format "~a~a" prefix (reg-id-id r))))
