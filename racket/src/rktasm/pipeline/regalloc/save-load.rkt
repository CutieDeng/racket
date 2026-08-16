#lang racket

;; ============================================================
;; pipeline/regalloc/save-load.rkt - save!/load! 代码生成
;; ============================================================
;;
;; 设计原则:
;;
;; 1. 静态分配: 函数中所有需要保存的寄存器统一分配 stack slot
;;    slot-table: { reg-key → offset }
;;
;; 2. 独立展开: 每个 save!/load! 独立查表生成代码，无需配对
;;
;; 3. 栈管理:
;;    - 第一个 save! 负责分配栈空间 (sub sp)
;;    - 最后一个 load! 负责释放栈空间 (add sp 或 post-index)
;;
;; 4. 语法:
;;    (: save! reg1 reg2 ...)   - 保存指定寄存器
;;    (: load! reg1 reg2 ...)   - 恢复指定寄存器
;;    (: save! all)             - 保存所有使用的 callee-saved 寄存器
;;    (: load! all)             - 恢复所有使用的 callee-saved 寄存器

(require "../../semantic/control-flow.rkt"
         "../../semantic/use-def.rkt"
         "../../parser/ast.rkt"
         "../../parser/frontend.rkt"  ; for format-srcloc
         "types.rkt"
         "allocator.rkt"
         "abi.rkt"
         "abi-config.rkt"
         "abi-infer.rkt"
         "spill-config.rkt"
         racket/intbits
         racket/omap
         racket/pvector
         racket/intmap)

(provide
  ;; 数据结构
  (struct-out save-load-context)

  ;; 分析
  analyze-save-load

  ;; 代码生成
  expand-save-load

  ;; 配置
  (struct-out save-load-config)
  default-save-load-config
  sve-save-load-config)

;; ============================================================
;; 配置
;; ============================================================

(struct save-load-config
  (use-paired?        ; boolean - 使用 stp/ldp 配对指令
   stack-alignment    ; integer - 栈对齐 (通常 16)
   sve-enabled?)      ; boolean - 启用 SVE 支持
  #:transparent)

(define default-save-load-config
  (save-load-config
   #t    ; 使用 stp/ldp
   16    ; 16 字节对齐
   #f))  ; 默认不启用 SVE

(define sve-save-load-config
  (save-load-config
   #t    ; 使用 stp/ldp
   16    ; 16 字节对齐
   #t))  ; 启用 SVE

;; ============================================================
;; AST 构建辅助
;; ============================================================

;; SP 寄存器常量
(define sp-reg (ast-reg 'x 'sp #f #f #f #f no-srcloc))

;; FP (x29) 寄存器常量 —— .frame 建立的帧指针
(define fp-reg (ast-reg 'x 29 #f #f #f #f no-srcloc))

(define current-generated-loc (make-parameter no-srcloc))

;; 构建物理寄存器
(define (make-phys-reg kind num)
  (ast-reg kind num #f #f #f #f no-srcloc))

;; 构建立即数
(define (make-imm n)
  (ast-imm n no-srcloc))

;; 构建 [sp, #offset] 寻址
(define (make-sp-mem offset [mode 'offset])
  (ast-mem sp-reg (make-imm offset) mode #f #f no-srcloc))

;; 构建指令
(define (make-ins op operands)
  (ast-ins op #f operands (current-generated-loc)))

;; 按 class 过滤 reg-key 列表
(define (filter-by-class class keys)
  (filter (lambda (k) (eq? (reg-key-class k) class)) keys))

;; ============================================================
;; 数据结构
;; ============================================================

;; 寄存器键: (cons class reg-num)
;; class: 'gpr | 'fpr | 'sve-z | 'sve-p
(define (make-reg-key class reg-num)
  (cons class reg-num))

(define (reg-key-class key) (car key))
(define (reg-key-num key) (cdr key))

(define (reg-key-compare a b)
  (let ([sa (symbol->string (car a))] [sb (symbol->string (car b))])
    (cond
      [(string<? sa sb) '<]
      [(string<? sb sa) '>]
      [(< (cdr a) (cdr b)) '<]
      [(> (cdr a) (cdr b)) '>]
      [else '=])))

;; reg-key 严格小于谓词 — 与 reg-key-compare 的 '< 分支逐位一致
;; (class 按 symbol 名字符串序, 再槽号整数序)
(define (regkey<? a b)
  (let ([sa (symbol->string (car a))] [sb (symbol->string (car b))])
    (cond
      [(string<? sa sb) #t]
      [(string<? sb sa) #f]
      [else (< (cdr a) (cdr b))])))

;; reg-key 键宏单态化有序映射实例 (替代 vendor ordered-map)
(define-omap regkey-om #:key-compare reg-key-compare)

;; 槽信息
(struct slot-info
  (offset      ; integer - 相对于帧基址的偏移
   size        ; integer - 槽大小 (8/16/vl)
   class)      ; 'gpr | 'fpr | 'sve-z | 'sve-p
  #:transparent)

;; 分析上下文
(struct save-load-context
  (slot-table         ; regkey-om[reg-key → slot-info] - 全局槽分配
   total-stack-size   ; integer - 总栈空间 (不含 SVE)
   sve-stack-slots    ; integer - SVE 使用的 VL 单位数
   first-save-loc     ; (cons bb-id-val ins-idx) | #f - 第一个 save! 位置
   load-locs          ; hash[(cons bb-id-val ins-idx) → #t] - 需要释放栈的结尾 load! 位置
   all-expansion      ; hash[reg-key → #t] - 'all' 展开后的寄存器集合
   resolved-regs      ; hash[(cons bb-id-val ins-idx) → (listof reg-key)] - 已解析的寄存器
   frame?             ; boolean - 函数是否用 .frame 建立帧指针 (x29)
   alloca?            ; boolean - 函数是否用 .alloca 做变长栈分配
   errors)            ; (listof string)
  #:transparent)

;; ============================================================
;; 分析 save!/load!
;; ============================================================

;; 分析函数中的 save!/load! 指令，分配栈槽并收集元信息
;; fn            : asm-function
;; alloc-result  : alloc-result (含 assignment, coalesced)
;; config        : save-load-config
;; abi           : abi-config
;; → save-load-context
(define (analyze-save-load fn alloc-result [config default-save-load-config]
                            #:abi [abi arm64-abi])
  ;; assignment : reg-om[reg-id → color]
  (define assignment (alloc-result-assignment alloc-result))
  ;; coalesced : reg-om[reg-id → reg-id]
  (define coalesced (alloc-result-coalesced alloc-result))

  ;; 收集 'all' 模式需要的 callee-saved 寄存器
  ;; used-callee-saved-* : (listof integer) — 物理寄存器编号
  (define used-callee-saved-gpr (collect-used-callee-saved fn alloc-result abi 'gpr))
  (define used-callee-saved-fpr (collect-used-callee-saved fn alloc-result abi 'fpr))
  (define used-callee-saved-sve-z
    (if (save-load-config-sve-enabled? config)
        (collect-used-callee-saved fn alloc-result abi 'sve-z)
        '()))
  (define used-callee-saved-sve-p
    (if (save-load-config-sve-enabled? config)
        (collect-used-callee-saved fn alloc-result abi 'sve-p)
        '()))

  ;; 'all' 展开后的寄存器集合
  ;; all-expansion : hash[reg-key → #t]
  (define all-expansion
    (for/hash ([pair (in-list
                      (append
                       (map (lambda (r) (cons 'gpr r)) used-callee-saved-gpr)
                       (map (lambda (r) (cons 'fpr r)) used-callee-saved-fpr)
                       (map (lambda (r) (cons 'sve-z r)) used-callee-saved-sve-z)
                       (map (lambda (r) (cons 'sve-p r)) used-callee-saved-sve-p)))])
      (values (make-reg-key (car pair) (cdr pair)) #t)))

  ;; 1. 扫描函数收集 save!/load! 点及其寄存器 (纯函数式累积)
  ;; saves-rev    : (listof (list bb-val idx reg-keys)) — 逆序
  ;; loads-rev    : (listof (list bb-val idx reg-keys)) — 逆序
  ;; all-regs-map : regkey-om[reg-key → #t] — 所有需要栈槽的寄存器
  ;; resolved-map : hash[(cons bb-val idx) → (listof reg-key)] — 每个点的已解析寄存器
  (define-values (saves-rev loads-rev all-regs-map resolved-map)
    (for*/fold ([saves '()]
                [loads '()]
                [all-regs regkey-om-empty]
                [resolved (hash)])
               ([kv (in-intmap-pairs (asm-function-blocks fn))])
      (define bb-val (car kv))
      (define block (cdr kv))
      (for/fold ([saves saves]
                 [loads loads]
                 [all-regs all-regs]
                 [resolved resolved])
                ([ins (in-pvector (basic-block-instructions block))]
                 [i (in-naturals)])
        (if (not (ast-directive? ins))
            (values saves loads all-regs resolved)
            (match (ast-directive-kind ins)
              [(or 'save! 'load!)
               (define kind (ast-directive-kind ins))
               (define regs-raw (first (ast-directive-args ins)))
               ;; reg-keys : (listof reg-key) — 解析后的物理寄存器键
               (define reg-keys
                 (if (eq? regs-raw 'all)
                     (hash-keys all-expansion)
                     (resolve-to-reg-keys regs-raw assignment coalesced)))
               (define point-loc (cons bb-val i))
               (define new-resolved (hash-set resolved point-loc reg-keys))
               (match kind
                 ['save!
                  ;; 将 save! 中的寄存器加入全局槽分配集合
                  (define new-all-regs
                    (for/fold ([m all-regs])
                              ([key (in-list reg-keys)])
                      (regkey-om-set m key #t)))
                  (values (cons (list bb-val i reg-keys) saves)
                          loads new-all-regs new-resolved)]
                 ['load!
                  (values saves
                          (cons (list bb-val i reg-keys) loads)
                          all-regs new-resolved)])]
              [_ (values saves loads all-regs resolved)])))))

  (define save-points (reverse saves-rev))
  (define load-points (reverse loads-rev))

  ;; 提取需要槽分配的寄存器列表
  ;; all-reg-keys : (listof reg-key) — 按 reg-key-compare 排序
  (define all-reg-keys
    (for/list ([kv (in-regkey-om all-regs-map)])
      (car kv)))

  ;; 2. 分配 stack slots
  (define-values (slot-table cs-total-size sve-slots)
    (allocate-slots all-reg-keys config))

  ;; 2b. 扫描 .frame / .alloca 指令。
  ;;   .frame [N] : 建立帧指针; N 字节 FP-relative 本地槽保留在 callee-saved 区之上,
  ;;                故 total = cs-total + align16(N)。用户以 [x29, #cs-total + i] 寻址。
  ;;   .alloca    : 变长栈分配, epilogue 前须 `mov sp, x29` 复原。
  (define-values (frame? frame-local-bytes alloca?)
    (for*/fold ([fr? #f] [local 0] [al? #f])
               ([kv (in-intmap-pairs (asm-function-blocks fn))]
                [ins (in-pvector (basic-block-instructions (cdr kv)))]
                #:when (ast-directive? ins))
      (case (ast-directive-kind ins)
        [(frame)
         (values #t
                 (max local (let ([a (ast-directive-args ins)])
                              (if (pair? a) (first a) 0)))
                 al?)]
        [(alloca) (values fr? local #t)]
        [else (values fr? local al?)])))

  ;; 帧总大小 = callee-saved 区 + 对齐后的 FP-relative 本地保留区
  (define total-size
    (+ cs-total-size (align-up frame-local-bytes (save-load-config-stack-alignment config))))

  ;; 3. 确定第一个 save! 和需要释放栈的结尾 load!
  ;; 规则:
  ;; - 第一个 save! 负责分配栈
  ;; - 仅函数结尾路径上的 load! 负责释放栈
  ;; - 同一出口块存在多个 load! 时，仅最后一个负责释放
  (define first-save
    (and (pair? save-points)
         (let ([sp (car save-points)])
           (cons (first sp) (second sp)))))

  ;; 出口块集合
  ;; exit-bb-set : hash[bb-val → #t]
  (define exit-bb-set
    (for/hash ([blk (in-list (fn-exit-blocks fn))])
      (values (bb-id-val (basic-block-id blk)) #t)))

  ;; 每个出口块中最后一个 load! 点
  ;; last-load-per-exit : hash[bb-val → (list bb idx reg-keys)]
  (define last-load-per-exit
    (for/fold ([h (hash)])
              ([lp (in-list load-points)])
      (define bb-val (first lp))
      (define idx (second lp))
      (if (not (hash-ref exit-bb-set bb-val #f))
          h
          (let ([old (hash-ref h bb-val #f)])
            (if (or (not old) (> idx (second old)))
                (hash-set h bb-val lp)
                h)))))

  ;; 需要释放栈的 load! 点列表
  ;; dealloc-load-points : (listof (list bb idx reg-keys))
  (define dealloc-load-points
    (if (positive? (hash-count last-load-per-exit))
        (hash-values last-load-per-exit)
        ;; 回退：若 CFG 未识别到出口 load!，至少保证最后一个 load! 释放一次
        (if (pair? load-points)
            (list (last load-points))
            '())))

  ;; 需要释放栈的 load! 位置集合
  ;; dealloc-load-locs : hash[(cons bb-val idx) → #t]
  (define dealloc-load-locs
    (for/hash ([lp (in-list dealloc-load-points)])
      (values (cons (first lp) (second lp)) #t)))

  ;; 4. 栈平衡检查 (仅警告)
  (define balance-warnings
    (verify-stack-balance fn first-save dealloc-load-points))

  (save-load-context slot-table total-size sve-slots
                     first-save dealloc-load-locs
                     all-expansion
                     resolved-map
                     frame? alloca?
                     balance-warnings))

;; 解析寄存器列表到 reg-key 列表
(define (resolve-to-reg-keys regs assignment coalesced)
  (for/list ([reg (in-list regs)])
    (define kind (ast-reg-kind reg))
    (define id (ast-reg-id reg))
    (define class (kind->class kind))

    (define phys-id
      (match id
        [(? number?) id]
        [_
         (define the-reg-id (reg-id class 64 id #t))
         (define resolved (reg-om-ref coalesced the-reg-id the-reg-id))
         (define color (reg-om-ref assignment resolved #f))
         (match color
           [#f
            (if (reg-id-physical? resolved)
                (reg-id-id resolved)
                (error 'resolve-to-reg-keys "虚拟寄存器未分配: ~a" id))]
           [c (abi-color->reg arm64-abi class c)])]))

    (make-reg-key class phys-id)))

;; ============================================================
;; 栈平衡验证 (警告)
;; ============================================================
;;
;; 追踪 save! 到 load! 之间的 SP 变化:
;; - sub sp, sp, #N  → offset -= N
;; - add sp, sp, #N  → offset += N
;; - mov sp, fp      → sp-offset = fp-offset (if valid)
;; - mov fp, sp      → fp-offset = sp-offset
;; - 其他 FP 写入    → fp-offset = #f
;; - 其他 SP 修改    → sp-offset = 'unknown
;;
;; 栈状态:
;; sp-offset: integer | 'unknown
;; fp-offset: integer | #f

(define (verify-stack-balance fn first-save load-points)
  (match first-save
    [#f '()]
    [_
     (define first-save-bb (car first-save))
     (define first-save-idx (cdr first-save))

     ;; 构建 load! 位置集合
     (define load-locs
       (for/hash ([lp (in-list load-points)])
         (values (cons (first lp) (second lp)) #t)))

     ;; 只检查 save! 所在基本块内的栈平衡
     ;; 对于跨基本块的情况，不做分析（避免误报）
     (define result-warnings '())

     (fn-for-each-block fn
       (lambda (block)
         (define bb-val (bb-id-val (basic-block-id block)))

         ;; 只分析包含 save! 的基本块
         (when (= bb-val first-save-bb)
           (set! result-warnings
             (for/fold ([ws '()]
                        [sp 0]        ; 相对于 save! 后的 SP 偏移
                        [fp #f]       ; FP 保存的 SP 偏移值，#f 表示无效
                        [active? #f]  ; 是否在 save! 之后
                        [uc #f]       ; 导致 unknown 的原因
                        #:result ws)
                       ([ins (in-pvector (basic-block-instructions block))]
                        [i (in-naturals)])
               (define now-active? (or active? (= i first-save-idx)))
               (if (not now-active?)
                   (values ws sp fp #f uc)
                   (let ()
                     ;; 分析指令对栈状态的影响
                     (define-values (new-sp new-fp new-uc)
                       (match (analyze-stack-effect ins)
                         [(list 'sub-sp n)
                          (values (if (number? sp) (- sp n) sp) fp uc)]
                         [(list 'add-sp n)
                          (values (if (number? sp) (+ sp n) sp) fp uc)]
                         ['(mov-sp-fp)
                          (if fp
                              (values fp fp uc)
                              (values 'unknown #f
                                      (format "~a: mov sp, fp 但 FP 已失效"
                                              (format-ins-loc ins))))]
                         ['(mov-fp-sp)
                          (values sp (and (number? sp) sp) uc)]
                         ['(write-fp)
                          (values sp #f uc)]
                         ['(write-sp)
                          (values 'unknown fp
                                  (format "~a: ~a"
                                          (format-ins-loc ins)
                                          (format-ins-brief ins)))]
                         ['(none)
                          (values sp fp uc)]))

                     ;; 检查是否是 load! 位置 (只在同一基本块内)
                     (define at-load? (hash-ref load-locs (cons bb-val i) #f))
                     (define new-ws
                       (if (not at-load?)
                           ws
                           (let ()
                             (define loc-str
                               (if (and (ast-directive? ins) (ast-directive-loc ins))
                                   (format-srcloc (ast-directive-loc ins))
                                   "unknown"))
                             (define fn-name (asm-function-name fn))
                             (match new-sp
                               ['unknown
                                (cons (format "警告 [~a] ~a: load! 处栈状态未知\n  原因: ~a"
                                              fn-name loc-str (or new-uc "未知"))
                                      ws)]
                               [(? (negate zero?))
                                (cons (format "警告 [~a] ~a: load! 处栈不平衡，SP 偏移 = ~a 字节"
                                              fn-name loc-str new-sp)
                                      ws)]
                               [_ ws]))))

                     (values new-ws new-sp new-fp #t new-uc))))))))

     (reverse result-warnings)]))

;; 格式化指令的源位置
(define (format-ins-loc ins)
  (define loc
    (match ins
      [(? ast-ins?) (ast-ins-loc ins)]
      [(? ast-directive?) (ast-directive-loc ins)]
      [_ #f]))
  (if loc (format-srcloc loc) "unknown"))

;; 格式化指令的简短描述
(define (format-ins-brief ins)
  (match ins
    [(? ast-ins?)
     (define op-strs
       (for/list ([o (in-list (ast-ins-operands ins))])
         (format-operand-brief o)))
     (format "(~a ~a)" (ast-ins-mnemonic ins) (string-join op-strs " "))]
    [(? ast-directive?)
     (format "(: ~a ...)" (ast-directive-kind ins))]
    [_ "?"]))

;; 格式化操作数的简短描述
(define (format-operand-brief op)
  (match op
    [(? ast-reg?)
     (define kind (ast-reg-kind op))
     (match (ast-reg-id op)
       ['sp "sp"]
       ['fp "fp"]
       ['xzr "xzr"]
       ['wzr "wzr"]
       [(? symbol? id) (format "~a.~a" kind id)]
       [id (format "~a~a" kind id)])]
    [(? ast-imm?)
     (format "#~a" (ast-imm-value op))]
    [(? ast-mem?)
     (define base-str (format-operand-brief (ast-mem-base op)))
     (define offset (ast-mem-offset op))
     (define off-str (and offset (format-operand-brief offset)))
     (match (ast-mem-index-mode op)
       ['pre  (if off-str (format "(~a ~a !)" base-str off-str) (format "(~a !)" base-str))]
       ['post (if off-str (format "(~a) ~a" base-str off-str) (format "(~a)" base-str))]
       [_     (if off-str (format "(~a ~a)" base-str off-str) (format "(~a)" base-str))])]
    [_ "?"]))

;; 分析单条指令对栈状态的影响
;; 返回: '(effect-type . args)
;; effect-type: 'sub-sp | 'add-sp | 'mov-sp-fp | 'mov-fp-sp | 'write-fp | 'write-sp | 'none
(define (analyze-stack-effect ins)
  (match ins
    [(? ast-ins?)
     (define op (ast-ins-mnemonic ins))
     (define operands (ast-ins-operands ins))
     (match op
       ['sub
        (match operands
          [(list (? is-sp-reg?) (? is-sp-reg?) (? ast-imm? imm) _ ...)
           (list 'sub-sp (ast-imm-value imm))]
          [(list (? is-sp-reg?) _ ...) '(write-sp)]
          [_ '(none)])]

       ['add
        (match operands
          [(list (? is-sp-reg?) (? is-sp-reg?) (? ast-imm? imm) _ ...)
           (list 'add-sp (ast-imm-value imm))]
          [(list (? is-sp-reg?) _ ...) '(write-sp)]
          [_ '(none)])]

       ['mov
        (match operands
          [(list (? is-sp-reg?) (? is-fp-reg?) _ ...) '(mov-sp-fp)]
          [(list (? is-fp-reg?) (? is-sp-reg?) _ ...) '(mov-fp-sp)]
          [(list (? is-fp-reg?) _ ...) '(write-fp)]
          [(list (? is-sp-reg?) _ ...) '(write-sp)]
          [_ '(none)])]

       ;; str/stp with pre-index: (str reg (sp #N !)) → SP += N
       [(or 'str 'stp)
        (define mem (last operands))
        (match mem
          [(? ast-mem?)
           #:when (and (is-sp-reg? (ast-mem-base mem))
                       (eq? (ast-mem-index-mode mem) 'pre)
                       (ast-imm? (ast-mem-offset mem)))
           (define imm-value (ast-imm-value (ast-mem-offset mem)))
           (list 'add-sp imm-value)]
          [_ '(none)])]

       ;; ldr/ldp with post-index: (ldr reg (sp) #N) → SP += N
       [(or 'ldr 'ldp)
        (define mem (last operands))
        (match mem
          [(? ast-mem?)
           #:when (and (is-sp-reg? (ast-mem-base mem))
                       (eq? (ast-mem-index-mode mem) 'post)
                       (ast-imm? (ast-mem-offset mem)))
           (define imm-value (ast-imm-value (ast-mem-offset mem)))
           (list 'add-sp imm-value)]
          [_ '(none)])]

       [_
        (match operands
          [(list (? is-sp-reg?) _ ...) '(write-sp)]
          [(list (? is-fp-reg?) _ ...) '(write-fp)]
          [_ '(none)])])]
    [_ '(none)]))

;; 判断是否是 SP 寄存器
(define (is-sp-reg? op)
  (and (ast-reg? op)
       (match (ast-reg-id op)
         [(or 'sp 31) #t]
         [_ #f])))

;; 判断是否是 FP 寄存器 (x29)
(define (is-fp-reg? op)
  (and (ast-reg? op)
       (match (ast-reg-id op)
         ['fp #t]
         [29 (eq? (ast-reg-kind op) 'x)]
         [_ #f])))

;; 分配 stack slots
;; 返回: (values slot-table total-size sve-slots)
(define (allocate-slots reg-keys config)
  (define alignment (save-load-config-stack-alignment config))

  ;; 按类别分组
  (define gpr-regs (filter-by-class 'gpr reg-keys))
  (define fpr-regs (filter-by-class 'fpr reg-keys))
  (define sve-z-regs (filter-by-class 'sve-z reg-keys))
  (define sve-p-regs (filter-by-class 'sve-p reg-keys))

  ;; 排序: GPR 中 x29, x30 优先
  (define (gpr-sort-key k)
    (match (reg-key-num k)
      [29 0]
      [30 1]
      [n (+ 10 n)]))
  (define sorted-gpr (sort gpr-regs < #:key gpr-sort-key))
  (define sorted-fpr (sort fpr-regs < #:key reg-key-num))
  (define sorted-sve-z (sort sve-z-regs < #:key reg-key-num))
  (define sorted-sve-p (sort sve-p-regs < #:key reg-key-num))

  ;; 分配固定大小的槽 (GPR: 8, FPR: 16)
  ;; GPR slots
  (define-values (table-after-gpr offset-after-gpr)
    (for/fold ([tbl regkey-om-empty]
               [off 0])
              ([key (in-list sorted-gpr)])
      (values (regkey-om-set tbl key (slot-info off 8 'gpr))
              (+ off 8))))

  ;; 对齐到 16 字节 (为 FPR 准备)
  (define fpr-base-offset
    (if (and (pair? sorted-fpr) (not (= (modulo offset-after-gpr 16) 0)))
        (align-up offset-after-gpr 16)
        offset-after-gpr))

  ;; FPR slots
  (define-values (table-after-fpr offset-after-fpr)
    (for/fold ([tbl table-after-gpr]
               [off fpr-base-offset])
              ([key (in-list sorted-fpr)])
      (values (regkey-om-set tbl key (slot-info off 16 'fpr))
              (+ off 16))))

  ;; 对齐总大小
  (define total-size (align-up offset-after-fpr alignment))

  ;; SVE slots (VL-based, 单独计数)
  (define-values (table-after-sve sve-slot-count)
    (for/fold ([tbl table-after-fpr]
               [idx 0])
              ([key (in-list (append sorted-sve-z sorted-sve-p))])
      (define sve-class (reg-key-class key))
      (values (regkey-om-set tbl key (slot-info idx 'vl sve-class))
              (add1 idx))))

  (values table-after-sve total-size sve-slot-count))

;; 对齐
(define (align-up n alignment)
  (* (quotient (+ n (sub1 alignment)) alignment) alignment))

;; ============================================================
;; 收集使用的 callee-saved 寄存器
;; ============================================================

;; 收集函数中使用的 callee-saved 寄存器
;; fn           : asm-function
;; alloc-result : alloc-result (含 assignment reg-om)
;; abi          : abi-config
;; class        : 'gpr | 'fpr | 'sve-z | 'sve-p
;; → (listof integer) — 升序排列的物理寄存器编号
(define (collect-used-callee-saved fn alloc-result abi class)
  ;; assignment : reg-om[reg-id → color]
  (define assignment (alloc-result-assignment alloc-result))

  ;; abi-class : 'gpr | 'fpr | 'scalable | 'predicate
  (define abi-class
    (match class
      ['sve-z 'scalable]
      ['sve-p 'predicate]
      [c c]))

  (define (assignment-class-matches? rid)
    (case class
      [(gpr) (eq? (reg-id-class rid) 'gpr)]
      [(fpr) (eq? (reg-id-class rid) 'fpr)]
      [(sve-p) (eq? (reg-id-class rid) 'predicate)]
      ;; SVE z registers are not represented by a distinct allocator class in
      ;; the current MVP, so only direct physical z operands are collected below.
      [(sve-z) #f]
      [else #f]))

  (define cfg (abi-get-class-config abi abi-class))
  ;; callee-saved : intbits | #f — ABI 定义的 callee-saved 寄存器集合
  (define callee-saved (and cfg (reg-callee-saved cfg)))

  ;; 无 callee-saved 配置则返回空
  (if (not callee-saved)
      '()
      (let ()
        ;; 使用 intbits 收集已使用的 callee-saved 寄存器编号
        ;; 寄存器编号为小非负整数 (0-31)，适合 intbits 表示

        ;; 初始集合: GPR 始终包含 x29 (FP), x30 (LR)
        (define initial-regs
          (if (eq? class 'gpr)
              (intbits-set (intbits-set intbits-empty 29) 30)
              intbits-empty))

        ;; 从分配结果收集 callee-saved 寄存器
        (define regs-from-alloc
          (for/fold ([bs initial-regs])
                    ([kv (in-reg-om assignment)])
            (define rid (car kv))
            (define color (cdr kv))
            (define reg-num (abi-color->reg abi abi-class color))
            (if (and (assignment-class-matches? rid)
                     reg-num
                     (intbits-ref callee-saved reg-num))
                (intbits-set bs reg-num)
                bs)))

        ;; 扫描直接使用的物理寄存器
        ;; regs-final : intbits — 所有已使用的 callee-saved 寄存器编号
        (define regs-final
          (for*/fold ([bs regs-from-alloc])
                     ([kv (in-intmap-pairs (asm-function-blocks fn))]
                      [ins (in-pvector (basic-block-instructions (cdr kv)))]
                      #:when (ast-ins? ins)
                      [op (in-list (ast-ins-operands ins))])
            (define reg-num (extract-physical-callee-saved op class callee-saved))
            (if reg-num
                (intbits-set bs reg-num)
                bs)))

        ;; intbits 自然有序，直接转为升序列表
        (for/list ([i (in-intbits regs-final)])
          i))))

(define (extract-physical-callee-saved op class callee-saved)
  (match op
    [(? ast-reg?)
     (define kind (ast-reg-kind op))
     (define id (ast-reg-id op))
     (define op-class (kind->class kind))
     (and (eq? op-class class)
          (integer? id)
          (intbits-ref callee-saved id)
          id)]
    [(? ast-mem?)
     (define base-reg (extract-physical-callee-saved (ast-mem-base op) class callee-saved))
     (define offset-reg
       (and (ast-reg? (ast-mem-offset op))
            (extract-physical-callee-saved (ast-mem-offset op) class callee-saved)))
     (or base-reg offset-reg)]
    [_ #f]))

;; ============================================================
;; 代码生成 - 展开 save!/load!
;; ============================================================

(define (expand-save-load fn context [config default-save-load-config])
  (define slot-table (save-load-context-slot-table context))
  (define total-size (save-load-context-total-stack-size context))
  (define sve-slots (save-load-context-sve-stack-slots context))
  (define first-save (save-load-context-first-save-loc context))
  (define load-locs (save-load-context-load-locs context))
  (define all-expansion (save-load-context-all-expansion context))
  (define resolved-regs (save-load-context-resolved-regs context))
  (define frame? (save-load-context-frame? context))
  (define alloca? (save-load-context-alloca? context))

  ;; 重写每个基本块
  (define new-blocks
    (for/fold ([blocks (asm-function-blocks fn)])
              ([kv (in-intmap-pairs (asm-function-blocks fn))])
      (define bb-val (car kv))
      (define block (cdr kv))
      (define new-block
        (expand-block block bb-val slot-table total-size sve-slots
                      first-save load-locs all-expansion resolved-regs
                      frame? alloca? config))
      (intmap-set blocks bb-val new-block)))

  (struct-copy asm-function fn [blocks new-blocks]))

;; 从 kind 推断 class 的辅助函数
(define (kind->class kind)
  (match kind
    [(or 'x 'w) 'gpr]
    [(or 'v 'd 's 'h 'b 'q) 'fpr]
    ['z 'sve-z]
    ['p 'sve-p]
    [_ 'gpr]))

;; 从物理寄存器列表构建 reg-key 列表
(define (regs->reg-keys regs)
  (for/list ([reg (in-list regs)])
    (define kind (ast-reg-kind reg))
    (define id (ast-reg-id reg))
    (define class (kind->class kind))
    (make-reg-key class id)))

;; 展开单个基本块
(define (expand-block block bb-val slot-table total-size sve-slots
                      first-save load-locs all-expansion resolved-regs
                      frame? alloca? config)
  (define instructions (basic-block-instructions block))

  (define new-instructions
    (for/fold ([result (pvector-empty)])
              ([ins (in-pvector instructions)]
               [i (in-naturals)])
      (match ins
        ;; save! 指令
        [(? ast-directive?)
         #:when (eq? (ast-directive-kind ins) 'save!)
         (define point-loc (cons bb-val i))
         (define reg-keys (hash-ref resolved-regs point-loc '()))

         ;; 是否是第一个 save!
         (define is-first?
           (and first-save
                (= (car first-save) bb-val)
                (= (cdr first-save) i)))

         (parameterize ([current-generated-loc (ast-srcloc ins)])
           (generate-save-code result reg-keys slot-table
                               total-size sve-slots is-first? config))]

        ;; load! 指令
        [(? ast-directive?)
         #:when (eq? (ast-directive-kind ins) 'load!)
         (define point-loc (cons bb-val i))
         (define reg-keys (hash-ref resolved-regs point-loc '()))

         ;; 仅结尾 load! 负责释放栈空间
         (define should-dealloc?
           (hash-ref load-locs (cons bb-val i) #f))

         ;; 变长栈分配 (.alloca) 后 sp 是动态的; 在释放栈的 epilogue load! 前
         ;; 用 `mov sp, x29` 从帧指针复原 sp, 使后续 sp-relative 复原/后索引
         ;; 释放 (ldp x29,x30,[sp],#N) 恢复到进入时的 sp。
         (define result+
           (if (and should-dealloc? alloca?)
               (pvector-cons-right result (make-ins 'mov (list sp-reg fp-reg)))
               result))

         (parameterize ([current-generated-loc (ast-srcloc ins)])
           (generate-load-code result+ reg-keys slot-table
                               total-size sve-slots should-dealloc? config))]

        ;; .frame: 在前导保存 x29/x30 之后建立帧指针 —— `add x29, sp, #0`。
        ;; 源码里放在 .save 之后, 故此刻 sp 已 = 帧基址。
        [(? ast-directive?)
         #:when (eq? (ast-directive-kind ins) 'frame)
         (parameterize ([current-generated-loc (ast-srcloc ins)])
           (pvector-cons-right result
             (make-ins 'add (list fp-reg sp-reg (make-imm 0)))))]

        ;; .alloca xN [, k]: 变长栈分配 —— `sub sp, sp, xN, lsl #k`。
        [(? ast-directive?)
         #:when (eq? (ast-directive-kind ins) 'alloca)
         (define args (ast-directive-args ins))
         (define areg (first args))
         (define shift (second args))
         (parameterize ([current-generated-loc (ast-srcloc ins)])
           (pvector-cons-right result
             (make-ins 'sub
               (list sp-reg sp-reg areg
                     (ast-shift 'lsl shift no-srcloc)))))]

        ;; 普通指令
        [_ (pvector-cons-right result ins)])))

  (struct-copy basic-block block [instructions new-instructions]))

;; ============================================================
;; 生成 save 代码
;; ============================================================

(define (generate-save-code result reg-keys slot-table total-size sve-slots is-first? config)
  (define use-paired? (save-load-config-use-paired? config))

  ;; 按类别分组
  (define gpr-keys (filter-by-class 'gpr reg-keys))
  (define fpr-keys (filter-by-class 'fpr reg-keys))
  (define sve-z-keys (filter-by-class 'sve-z reg-keys))
  (define sve-p-keys (filter-by-class 'sve-p reg-keys))

  ;; 1. 先构建固定大小寄存器 (GPR/FPR) 的保存指令
  ;;    这样可以在 is-first? 时把栈分配折叠到首条 store 的 pre-index 中
  (define fixed-save-ops
    (let ()
      (define ops-after-gpr
        (generate-store-pairs (pvector-empty) gpr-keys slot-table 'x use-paired?))
      (generate-store-pairs ops-after-gpr fpr-keys slot-table 'q use-paired?)))

  ;; 2. 尝试把 "sub sp, sp, #N" 折叠成首条 "stp/str ..., [sp, #-N]!"
  (define-values (folded-save-ops folded?)
    (if (and is-first? (> total-size 0))
        (fold-stack-allocation-into-first-store fixed-save-ops total-size)
        (values fixed-save-ops #f)))

  ;; 3. 处理栈分配:
  ;;    - 若已折叠到 pre-index，不再单独生成 sub
  ;;    - SVE 分配 (addvl) 逻辑保持不变
  (define result-after-alloc
    (let ([res
           (if (and is-first? (> total-size 0) (not folded?))
               (pvector-cons-right result
                 (make-ins 'sub (list sp-reg sp-reg (make-imm total-size))))
               result)])
      (if (and is-first? (> sve-slots 0))
          (pvector-cons-right res
            (make-ins 'addvl (list sp-reg sp-reg (make-imm (- sve-slots)))))
          res)))

  ;; 4. 追加 GPR/FPR 保存指令
  (define result-after-fixed
    (for/fold ([res result-after-alloc])
              ([ins (in-pvector folded-save-ops)])
      (pvector-cons-right res ins)))

  ;; 5. 生成 SVE 存储
  (define result-after-sve-z
    (generate-sve-stores result-after-fixed sve-z-keys slot-table 'z))

  (define result-final
    (generate-sve-stores result-after-sve-z sve-p-keys slot-table 'p))

  result-final)

;; 判断内存操作数是否是 [sp, #0] (offset 模式)
(define (sp-zero-offset-mem? mem)
  (and (ast-mem? mem)
       (is-sp-reg? (ast-mem-base mem))
       (eq? (ast-mem-index-mode mem) 'offset)
       (ast-imm? (ast-mem-offset mem))
       (= (ast-imm-value (ast-mem-offset mem)) 0)))

;; stp pre-index 立即数可编码性检查
;; x 寄存器对:  imm ∈ [-512, 504], 步长 8
;; q 寄存器对:  imm ∈ [-1024, 1008], 步长 16
(define (stp-pre-index-imm-encodable? reg-kind imm)
  (match reg-kind
    ['x (and (<= -512 imm 504) (= (modulo imm 8) 0))]
    ['q (and (<= -1024 imm 1008) (= (modulo imm 16) 0))]
    [_ #f]))

;; 尝试把首条 [sp, #0] 的 stp/str 改写成 pre-index 形式:
;;   stp x29, x30, [sp, #0]  ->  stp x29, x30, [sp, #-N]!
;; 返回: (values new-ops folded?)
(define (fold-stack-allocation-into-first-store save-ops total-size)
  (let loop ([i 0] [n (pvector-length save-ops)])
    (cond
      [(>= i n) (values save-ops #f)]
      [else
       (define ins (pvector-ref save-ops i))
       (match ins
         [(ast-ins 'stp #f (list r1 r2 mem) _)
          (define imm (- total-size))
          (if (and (sp-zero-offset-mem? mem)
                   (ast-reg? r1)
                   (stp-pre-index-imm-encodable? (ast-reg-kind r1) imm))
              (values
               (pvector-set save-ops i
                            (make-ins 'stp (list r1 r2 (make-sp-mem imm 'pre))))
               #t)
              (loop (add1 i) n))]
         [_ (loop (add1 i) n)])])))

;; 生成成对存储指令
(define (generate-store-pairs result keys slot-table kind use-paired?)
  ;; 按偏移排序
  (define sorted-keys
    (sort keys <
          #:key (lambda (k)
                  (slot-info-offset (regkey-om-ref slot-table k #f)))))

  (let loop ([ks sorted-keys] [res result])
    (match ks
      ['() res]
      [(list k1 k2 rest ...)
       #:when use-paired?
       (define slot1 (regkey-om-ref slot-table k1 #f))
       (define slot2 (regkey-om-ref slot-table k2 #f))
       (define off1 (slot-info-offset slot1))
       (define off2 (slot-info-offset slot2))
       (define slot-size (slot-info-size slot1))
       (define reg1 (make-phys-reg kind (reg-key-num k1)))
       (define reg2 (make-phys-reg kind (reg-key-num k2)))
       (if (= off2 (+ off1 slot-size))
           ;; 连续，可以用 stp
           (loop rest
                 (pvector-cons-right res
                   (make-ins 'stp (list reg1 reg2 (make-sp-mem off1)))))
           ;; 不连续，单独存储 k1
           (loop (cons k2 rest)
                 (pvector-cons-right res
                   (make-ins 'str (list reg1 (make-sp-mem off1))))))]
      [(cons k rest)
       (define slot (regkey-om-ref slot-table k #f))
       (define off (slot-info-offset slot))
       (define reg (make-phys-reg kind (reg-key-num k)))
       (loop rest
             (pvector-cons-right res
               (make-ins 'str (list reg (make-sp-mem off)))))])))

;; 生成 SVE 存储
(define (generate-sve-stores result keys slot-table kind)
  (for/fold ([res result])
            ([k (in-list keys)])
    (define slot (regkey-om-ref slot-table k #f))
    (define vl-offset (slot-info-offset slot))
    (define reg (make-phys-reg kind (reg-key-num k)))
    (define mem (make-sp-mem vl-offset 'sve-vl))
    (pvector-cons-right res (make-ins 'str (list reg mem)))))

;; ============================================================
;; 生成 load 代码
;; ============================================================

(define (generate-load-code result reg-keys slot-table total-size sve-slots is-last? config)
  (define use-paired? (save-load-config-use-paired? config))

  ;; 按类别分组
  (define gpr-keys (filter-by-class 'gpr reg-keys))
  (define fpr-keys (filter-by-class 'fpr reg-keys))
  (define sve-z-keys (filter-by-class 'sve-z reg-keys))
  (define sve-p-keys (filter-by-class 'sve-p reg-keys))

  ;; 1. 生成 SVE 加载 (先加载 SVE，因为它们在栈顶)
  (define result-after-sve-p
    (generate-sve-loads result sve-p-keys slot-table 'p))

  (define result-after-sve-z
    (generate-sve-loads result-after-sve-p sve-z-keys slot-table 'z))

  ;; 2. 如果是最后一个 load! 且有 SVE，释放 SVE 栈空间
  (define result-after-sve-dealloc
    (if (and is-last? (> sve-slots 0))
        (pvector-cons-right result-after-sve-z
          (make-ins 'addvl (list sp-reg sp-reg (make-imm sve-slots))))
        result-after-sve-z))

  ;; 3. 生成 FPR 加载
  (define result-after-fpr
    (generate-load-pairs result-after-sve-dealloc fpr-keys slot-table 'q use-paired?
                         #f 0))  ; FPR 不使用 post-index

  ;; 4. 生成 GPR 加载
  ;; 检查是否可以使用 post-index：需要有偏移为 0 的 ldp
  (define can-use-post-index?
    (and is-last?
         use-paired?
         (> total-size 0)
         ;; 检查是否有连续的两个最低偏移寄存器
         (let ()
           (define sorted
             (sort gpr-keys <
                   #:key (lambda (k)
                           (slot-info-offset (regkey-om-ref slot-table k #f)))))
           (match sorted
             [(list k1 k2 _ ...)
              (define off1 (slot-info-offset (regkey-om-ref slot-table k1 #f)))
              (define off2 (slot-info-offset (regkey-om-ref slot-table k2 #f)))
              (and (= off1 0) (= off2 8))]
             [_ #f]))))  ; 连续且从 0 开始

  (define result-after-gpr
    (generate-load-pairs result-after-fpr gpr-keys slot-table 'x use-paired?
                         can-use-post-index? total-size))

  ;; 5. 如果需要释放但没用 post-index，手动释放
  (define result-final
    (if (and is-last? (> total-size 0) (not can-use-post-index?))
        (pvector-cons-right result-after-gpr
          (make-ins 'add (list sp-reg sp-reg (make-imm total-size))))
        result-after-gpr))

  result-final)

;; 生成成对加载指令
;; 如果 use-post-index? 为 #t，最后一对使用 post-index (必须是偏移 0 的 ldp)
(define (generate-load-pairs result keys slot-table kind use-paired?
                              use-post-index? post-index-amount)
  ;; 按偏移升序排列
  (define sorted-keys
    (sort keys <
          #:key (lambda (k)
                  (slot-info-offset (regkey-om-ref slot-table k #f)))))

  ;; 如果要用 post-index，先把偏移 0 和 slot-size 的两个寄存器提取出来
  (define-values (post-index-pair other-keys)
    (if (not (and use-post-index? (>= (length sorted-keys) 2)))
        (values #f sorted-keys)
        (match sorted-keys
          [(list k1 k2 rest ...)
           (define off1 (slot-info-offset (regkey-om-ref slot-table k1 #f)))
           (define off2 (slot-info-offset (regkey-om-ref slot-table k2 #f)))
           (define slot-size (slot-info-size (regkey-om-ref slot-table k1 #f)))
           (if (and (= off1 0) (= off2 slot-size))
               (values (list k1 k2) rest)
               (values #f sorted-keys))]
          [_ (values #f sorted-keys)])))

  ;; 对其他寄存器按偏移降序排列（先加载高地址）
  (define remaining-sorted
    (sort other-keys >
          #:key (lambda (k)
                  (slot-info-offset (regkey-om-ref slot-table k #f)))))

  ;; 构建其他寄存器的操作列表
  (define other-ops
    (let loop ([ks remaining-sorted] [ops '()])
      (match ks
        ['() (reverse ops)]
        [(list k1 k2 rest ...)
         #:when use-paired?
         (define slot1 (regkey-om-ref slot-table k1 #f))
         (define slot2 (regkey-om-ref slot-table k2 #f))
         (define off1 (slot-info-offset slot1))
         (define off2 (slot-info-offset slot2))
         (define slot-size (slot-info-size slot1))
         (if (= off1 (+ off2 slot-size))
             (loop rest (cons (list 'ldp k2 k1 off2) ops))
             (loop (cons k2 rest) (cons (list 'ldr k1 off1) ops)))]
        [(cons k rest)
         (define slot (regkey-om-ref slot-table k #f))
         (define off (slot-info-offset slot))
         (loop rest (cons (list 'ldr k off) ops))])))

  ;; 生成其他寄存器的加载指令
  (define result-after-others
    (for/fold ([res result])
              ([op (in-list other-ops)])
      (match op
        [(list 'ldp k1 k2 off)
         (define reg1 (make-phys-reg kind (reg-key-num k1)))
         (define reg2 (make-phys-reg kind (reg-key-num k2)))
         (pvector-cons-right res
           (make-ins 'ldp (list reg1 reg2 (make-sp-mem off))))]
        [(list 'ldr k off)
         (define reg (make-phys-reg kind (reg-key-num k)))
         (pvector-cons-right res
           (make-ins 'ldr (list reg (make-sp-mem off))))])))

  ;; 最后生成 post-index ldp（如果有）
  (match post-index-pair
    [(list k1 k2)
     (define reg1 (make-phys-reg kind (reg-key-num k1)))
     (define reg2 (make-phys-reg kind (reg-key-num k2)))
     (define mem (make-sp-mem post-index-amount 'post))
     (pvector-cons-right result-after-others
       (make-ins 'ldp (list reg1 reg2 mem)))]
    [_ result-after-others]))

;; 生成 SVE 加载
(define (generate-sve-loads result keys slot-table kind)
  ;; 按 VL 偏移降序
  (define sorted-keys
    (sort keys >
          #:key (lambda (k)
                  (slot-info-offset (regkey-om-ref slot-table k #f)))))

  (for/fold ([res result])
            ([k (in-list sorted-keys)])
    (define slot (regkey-om-ref slot-table k #f))
    (define vl-offset (slot-info-offset slot))
    (define reg (make-phys-reg kind (reg-key-num k)))
    (define mem (make-sp-mem vl-offset 'sve-vl))
    (pvector-cons-right res (make-ins 'ldr (list reg mem)))))
