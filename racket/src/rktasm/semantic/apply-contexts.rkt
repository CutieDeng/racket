#lang racket

;; ============================================================
;; semantic/apply-contexts.rkt - .context 替换 pass (M1 保守版)
;; ============================================================
;;
;; 消费解析阶段产出的扁平 item 列表, 完成三件事:
;;
;;   1. 收集所有 `.context NAME field=reg ...` 声明成 registry
;;      (NAME -> {field -> phys-reg})。
;;   2. 对每个 import 了上下文的 `.function`(attrs 'contexts 非空), 把函数体
;;      指令里 id 为已声明字段的**虚拟寄存器** (kind=x/w) 替换成对应物理寄存器,
;;      保持 w/x 视图 (w.acc0 且 acc0=x14 -> w14)。未声明字段保持虚拟。
;;   3. 一致性/冲突校验 (消除"隐式 ABI 静默失效"):
;;      (a) 同一字段名在多个 import 的上下文里映射到不同物理寄存器 -> 报错;
;;      (b) 两个不同字段映射到同一物理寄存器 (字段别名) -> 报错;
;;          函数体里**手写的物理寄存器**与某上下文字段占用同一物理寄存器 -> 报错;
;;      (c) import 了未声明的上下文名 -> 报错。
;;
;; 该 pass 在 parse 之后、CFG/regalloc 之前运行 (cli/as.rkt)。它把 'context
;; directive 从 item 流剥离, 使 CFG/emit 永不见到。
;;
;; 设计动机与语义见 docs/context-register-sets-design.md (里程碑 M1)。

(require "../parser/ast.rkt"
         racket/match)

(provide apply-contexts)

;; ------------------------------------------------------------
;; 工具
;; ------------------------------------------------------------

;; 物理寄存器所属的分配类 (x/w 共享整型寄存器堆)。
(define (reg-kind->class kind)
  (cond
    [(memq kind '(x w)) 'gpr]
    [(memq kind '(v q d s h b)) 'vec]
    [(eq? kind 'z) 'sve-z]
    [(eq? kind 'p) 'sve-p]
    [else 'other]))

(define (loc->string loc)
  (match loc
    [(srcloc src line _ _ _)
     (define src-str
       (cond
         [(not src) "<unknown>"]
         [(path? src) (path->string src)]
         [(symbol? src) (symbol->string src)]
         [else (format "~a" src)]))
     (if line (format "~a:~a" src-str line) src-str)]
    [_ "<unknown>"]))

;; ------------------------------------------------------------
;; registry: 收集 .context 声明
;; ------------------------------------------------------------

;; 返回 (values registry scope-registry errors)
;;   registry       : hash[NAME -> hash[field -> phys-ast-reg]]
;;   scope-registry : hash[NAME -> scope-symbol]  (library|process|signal)
(define (collect-contexts items)
  (for/fold ([registry (hash)]
             [scope-registry (hash)]
             [errors '()]
             #:result (values registry scope-registry (reverse errors)))
            ([item (in-list items)]
             #:when (and (ast-directive? item)
                         (eq? (ast-directive-kind item) 'context)))
    (define name (ast-directive-name item))
    ;; args = (list scope field-map-assoc); scope ∈ {library,process,signal}
    (define parts (ast-directive-args item))
    (define scope (if (pair? parts) (first parts) 'library))
    (define fields (if (and (pair? parts) (pair? (cdr parts))) (second parts) '()))
    (define loc-str (loc->string (ast-directive-loc item)))
    (cond
      [(hash-has-key? registry name)
       (values registry scope-registry
               (cons (format "~a: 上下文 '~a' 重复声明" loc-str name) errors))]
      [else
       ;; 字段表 + 字段级校验 (字段重名 / 两字段共享同一物理寄存器)
       (define-values (field-map local-errs)
         (for/fold ([fm (hash)] [errs '()])
                   ([kv (in-list fields)])
           (define field (car kv))
           (define reg (cdr kv))
           (cond
             [(hash-has-key? fm field)
              (values fm (cons (format "~a: 上下文 '~a' 字段 '~a' 重复声明"
                                       loc-str name field) errs))]
             [else
              ;; 别名检测: 该物理寄存器是否已被本上下文另一字段占用
              (define key (cons (reg-kind->class (ast-reg-kind reg))
                                (ast-reg-id reg)))
              (define clash
                (for/first ([(f r) (in-hash fm)]
                            #:when (equal? key
                                           (cons (reg-kind->class (ast-reg-kind r))
                                                 (ast-reg-id r))))
                  f))
              (if clash
                  (values fm
                          (cons (format "~a: 上下文 '~a' 字段 '~a' 与 '~a' 映射到同一物理寄存器"
                                        loc-str name field clash) errs))
                  (values (hash-set fm field reg) errs))])))
       (values (hash-set registry name field-map)
               (hash-set scope-registry name scope)
               (append (reverse local-errs) errors))])))

;; ------------------------------------------------------------
;; 为一个函数构造有效字段表 (union 其 import 的上下文)
;; ------------------------------------------------------------

;; 返回 (values field-map errors)
;;   field-map : hash[field -> phys-ast-reg]
(define (build-function-field-map context-names registry fn-name loc-str)
  (for/fold ([field-map (hash)]
             [errors '()]
             #:result (values field-map (reverse errors)))
            ([ctx-name (in-list context-names)])
    (cond
      [(not (hash-has-key? registry ctx-name))
       (values field-map
               (cons (format "~a: 函数 '~a' import 了未声明的上下文 '~a'"
                             loc-str fn-name ctx-name) errors))]
      [else
       (define ctx (hash-ref registry ctx-name))
       (for/fold ([fm field-map] [errs errors] #:result (values fm errs))
                 ([(field reg) (in-hash ctx)])
         (cond
           [(and (hash-has-key? fm field)
                 (not (same-phys-reg? (hash-ref fm field) reg)))
            (values fm
                    (cons (format "~a: 函数 '~a' 的字段 '~a' 在多个上下文里映射冲突"
                                  loc-str fn-name field) errs))]
           [else (values (hash-set fm field reg) errs)]))])))

(define (same-phys-reg? a b)
  (and (equal? (reg-kind->class (ast-reg-kind a)) (reg-kind->class (ast-reg-kind b)))
       (equal? (ast-reg-id a) (ast-reg-id b))))

;; ------------------------------------------------------------
;; 操作数替换
;; ------------------------------------------------------------

;; 若 r 是 id 为已声明字段的虚拟寄存器 (kind=x/w) -> 换成物理寄存器,
;; 保持引用视图 (kind) 与其它修饰 (element/index 等), 只替换 id 数字。
(define (subst-reg r field-map)
  (match r
    [(ast-reg kind id _ _ _ _ _)
     (if (and (symbol? id)
              (memq kind '(x w))
              (hash-has-key? field-map id))
         (struct-copy ast-reg r [id (ast-reg-id (hash-ref field-map id))])
         r)]
    [_ r]))

(define (subst-operand op field-map)
  (match op
    [(? ast-reg?) (subst-reg op field-map)]
    [(ast-mem base offset index-mode shift extend loc)
     (ast-mem (subst-reg base field-map)
              (if (ast-reg? offset) (subst-reg offset field-map) offset)
              index-mode shift extend loc)]
    [(ast-reglist regs loc)
     (ast-reglist (for/list ([g (in-list regs)]) (subst-operand g field-map)) loc)]
    [_ op]))

;; 遍历指令操作数, 收集**手写物理寄存器** (id 为数字) 的 (class . id) 集合。
;; 用于检测手写物理寄存器与上下文字段的占用冲突。
(define (collect-phys-regs-in-operand op acc)
  (match op
    [(ast-reg kind id _ _ _ _ _)
     (if (number? id)
         (set-add acc (cons (reg-kind->class kind) id))
         acc)]
    [(ast-mem base offset _ _ _ _)
     (define a1 (collect-phys-regs-in-operand base acc))
     (if (ast-reg? offset) (collect-phys-regs-in-operand offset a1) a1)]
    [(ast-reglist regs _)
     (for/fold ([a acc]) ([g (in-list regs)]) (collect-phys-regs-in-operand g a))]
    [_ acc]))

;; 上下文字段占用的 (class . id) 集合
(define (field-map->phys-set field-map)
  (for/set ([(field reg) (in-hash field-map)])
    (cons (reg-kind->class (ast-reg-kind reg)) (ast-reg-id reg))))

;; ------------------------------------------------------------
;; L1 (库层级): callee-saved 上下文字段的边界保存校验
;; ------------------------------------------------------------

;; 落在 AAPCS64 callee-saved GPR (x19-x28)、且来自 scope=library 上下文的字段。
;; 返回 hash[(class . id) -> field-name]。这些字段被 export 函数使用时必须保存
;; (.save all 或显式 .save), 否则静默违反 AAPCS64 —— L1 要在汇编期报错。
(define (callee-saved-lib-regmap ctx-names registry scope-registry)
  (for*/hash ([ctx-name (in-list ctx-names)]
              #:when (and (hash-has-key? registry ctx-name)
                          (eq? (hash-ref scope-registry ctx-name 'library) 'library))
              [(field reg) (in-hash (hash-ref registry ctx-name))]
              #:when (and (eq? (reg-kind->class (ast-reg-kind reg)) 'gpr)
                          (number? (ast-reg-id reg))
                          (<= 19 (ast-reg-id reg) 28)))
    (values (cons 'gpr (ast-reg-id reg)) field)))

;; 从 .save/.load directive (kind 'save!/'load!) 提取覆盖集:
;;   'all             -> 覆盖所有用到的 callee-saved
;;   (setof (class.id)) -> 覆盖列出的物理寄存器
(define (save-directive-coverage item)
  (define args (ast-directive-args item))
  (define spec (and (pair? args) (car args)))
  (cond
    [(eq? spec 'all) 'all]
    [(list? spec)
     (for/set ([r (in-list spec)] #:when (ast-reg? r))
       (cons (reg-kind->class (ast-reg-kind r)) (ast-reg-id r)))]
    [else (set)]))

;; 合并两个覆盖 ('all 吸收一切)
(define (merge-coverage a b)
  (cond [(or (eq? a 'all) (eq? b 'all)) 'all]
        [else (set-union a b)]))

;; ------------------------------------------------------------
;; 主入口
;; ------------------------------------------------------------

;; apply-contexts : (listof ast) -> (values (listof ast) (listof string))
;;   返回 (values 变换后的 items, 错误消息列表)。
;;   items 中的 'context directive 被剥离; import 上下文的函数体指令完成替换。
(define (apply-contexts items)
  (define-values (registry scope-registry reg-errors) (collect-contexts items))

  ;; 逐 item 走一遍, 跟踪当前函数的字段表; 替换函数体指令 + L1 校验。
  ;; active state (在 import 上下文的函数里):
  ;;   (list field-map phys-set fn-name loc-str cs-lib is-export used-box saved-box)
  ;;   cs-lib   : hash[(class.id) -> field]  callee-saved library 字段
  ;;   used-box : box[setof (class.id)]      实际用到的 cs-lib 寄存器
  ;;   saved-box: box['all | setof (class.id)]  .save 覆盖
  (define errors-box (box (reverse reg-errors)))
  (define (add-error! msg) (set-box! errors-box (cons msg (unbox errors-box))))

  ;; L1 校验: export 函数用了 callee-saved library 上下文字段却没保存 -> 报错
  (define (l1-check! active)
    (match-define (list _fm _ps fn-name loc-str cs-lib is-export used-box saved-box) active)
    (when is-export
      (define saved (unbox saved-box))
      (for ([u (in-set (unbox used-box))]
            #:unless (or (eq? saved 'all) (set-member? saved u)))
        (add-error!
         (format "~a: 上下文字段 '~a' 落在 callee-saved 寄存器 ~a, 但 export 函数 '~a' 未保存它 (需 .save all 或 .save ~a)"
                 loc-str (hash-ref cs-lib u) (phys->string u) fn-name (phys->string u))))))

  (define out
    (let loop ([items items]
               [active #f]
               [acc '()])
      (match items
        ['() (reverse acc)]
        [(cons item rest)
         (cond
           ;; 剥离 .context 声明
           [(and (ast-directive? item) (eq? (ast-directive-kind item) 'context))
            (loop rest active acc)]

           ;; 函数开始: 若 import 上下文, 建立字段表 + L1 状态
           [(and (ast-directive? item) (eq? (ast-directive-kind item) 'function))
            (define attrs (ast-directive-args item))
            (define ctx-names (and (hash? attrs) (hash-ref attrs 'contexts '())))
            (define is-export (and (hash? attrs) (hash-ref attrs 'export #f) #t))
            (define fn-name (ast-directive-name item))
            (define loc-str (loc->string (ast-directive-loc item)))
            (define next-active
              (cond
                [(or (not ctx-names) (null? ctx-names)) #f]
                [else
                 (define-values (field-map errs)
                   (build-function-field-map ctx-names registry fn-name loc-str))
                 (for ([e (in-list errs)]) (add-error! e))
                 (list field-map (field-map->phys-set field-map) fn-name loc-str
                       (callee-saved-lib-regmap ctx-names registry scope-registry)
                       is-export (box (set)) (box (set)))]))
            (loop rest next-active (cons item acc))]

           ;; 函数结束: L1 校验后清空 active
           [(and (ast-directive? item) (eq? (ast-directive-kind item) 'end-function))
            (when active (l1-check! active))
            (loop rest #f (cons item acc))]

           ;; 函数体的 .save/.load directive: 累积覆盖集
           [(and active (ast-directive? item)
                 (memq (ast-directive-kind item) '(save! load!)))
            (match-define (list _fm _ps _fn _loc _cs _ex _used saved-box) active)
            (set-box! saved-box (merge-coverage (unbox saved-box)
                                                (save-directive-coverage item)))
            (loop rest active (cons item acc))]

           ;; 函数体指令: 替换 + 冲突检测 + L1 used 追踪
           [(and active (ast-ins? item))
            (match-define (list field-map phys-set fn-name loc-str cs-lib _ex used-box _sv) active)
            ;; (b) 手写物理寄存器与上下文字段占用冲突
            (define hand-phys (collect-phys-regs-in-operand-list
                               (ast-ins-operands item)))
            (for ([p (in-set hand-phys)] #:when (set-member? phys-set p))
              (add-error!
               (format "~a: 函数 '~a' 手写物理寄存器 ~a 与上下文字段占用同一物理寄存器"
                       (loc->string (ast-ins-loc item)) fn-name
                       (phys->string p))))
            (define new-ins
              (struct-copy ast-ins item
                           [operands (for/list ([op (in-list (ast-ins-operands item))])
                                       (subst-operand op field-map))]))
            ;; L1: 记录该指令用到的 callee-saved library 上下文寄存器
            (for ([p (in-set (collect-phys-regs-in-operand-list
                              (ast-ins-operands new-ins)))]
                  #:when (hash-has-key? cs-lib p))
              (set-box! used-box (set-add (unbox used-box) p)))
            (loop rest active (cons new-ins acc))]

           [else (loop rest active (cons item acc))])])))

  (values out (reverse (unbox errors-box))))

(define (collect-phys-regs-in-operand-list ops)
  (for/fold ([acc (set)]) ([op (in-list ops)])
    (collect-phys-regs-in-operand op acc)))

(define (phys->string p)
  (match-define (cons class id) p)
  (case class
    [(gpr) (format "x~a" id)]
    [(vec) (format "v~a" id)]
    [(sve-z) (format "z~a" id)]
    [(sve-p) (format "p~a" id)]
    [else (format "~a~a" class id)]))
