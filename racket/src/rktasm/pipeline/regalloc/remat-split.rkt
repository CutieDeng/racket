#lang racket

;; ============================================================
;; pipeline/regalloc/remat-split.rkt - 重物化·重载拆分 (预分配 pass)
;; ============================================================
;;
;; 把"在顶部一次性从不变地址装载、随后跨多个调用保持存活"的值
;; (这会强制它进 callee-saved 或溢出) 拆分成"每个使用点各自重载"：
;;   - 该值不再跨调用存活 => 不占 callee-saved、不溢出；
;;   - 基址指针因在各重载点被使用而自然保持存活 (分配器放进 callee-saved)。
;;
;; 这就是编译器的 rematerialization，匹配 clang 从输入结构体按需重读的
;; 策略。对 P-256 point-double：X,Y,Z 从 [in_ptr] 重读，取代跨 7 个域乘
;; 调用的寄存器驻留 (后者只会导致 spill store + reload)。
;;
;; 安全条件 (总是正确)：
;;   - 候选 v 恰好一个 def，且 def 是 `ldr v,[base,#imm]` (无回写)；
;;   - base 在整个函数中从不被定义 (函数输入指针，值不变)；
;;   - v 跨至少一个调用存活 (否则拆分只是徒增指令)。

(require "../../parser/ast.rkt"
         "../../semantic/control-flow.rkt"
         "../../semantic/use-def.rkt"
         "types.rkt"
         "liveness.rkt"
         racket/pvector
         racket/intmap
         racket/intbits)

(provide split-remat-loads)

;; ast-reg -> 虚拟 reg-id；非虚拟/非寄存器/sp/zr 返回 #f
(define (areg->reg-id r)
  (and (ast-reg? r)
       (let* ([kind (ast-reg-kind r)]
              [id (ast-reg-id r)]
              [class (case kind
                       [(x w) 'gpr]
                       [(z v d s h b q) 'fpr]
                       [(p) 'predicate]
                       [else 'gpr])])
         (and (symbol? id) (not (memq id '(sp zr)))
              (reg-id class (canonical-width class) id #t)))))

;; 跨调用存活的虚拟寄存器集合 (reg-om[reg-id -> #t])
(define (regs-live-across-call fn liveness)
  (define index-reg (fn-liveness-index-reg liveness))
  (define reg-index (fn-liveness-reg-index liveness))
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
           (define ud (extract-use-def ins))
           (when (memq (ast-ins-mnemonic ins) '(bl blr))
             (for ([idx (in-intbits live)])
               (define r (pvector-ref index-reg idx))
               (when (reg-id-virtual? r)
                 (set-box! result (reg-om-set (unbox result) r #t)))))
           (define live1
             (for/fold ([l live]) ([d (in-list (use-def-flat-defs ud))])
               (define idx (reg-om-ref reg-index (reg-ref->reg-id d) #f))
               (if idx (intbits-clear l idx) l)))
           (for/fold ([l live1]) ([u (in-list (use-def-flat-uses ud))])
             (define idx (reg-om-ref reg-index (reg-ref->reg-id u) #f))
             (if idx (intbits-set l idx) l))]
          [else live]))))
  (unbox result))

;; 主入口
(define (split-remat-loads fn)
  (if (getenv "ASMP_NO_REMAT") fn (split-remat-loads* fn)))

(define (split-remat-loads* fn)
  (define liveness (analyze-liveness fn))
  (define across (regs-live-across-call fn liveness))
  ;; def 统计
  (define def-count (make-hash))    ; reg-id -> 定义次数
  (define def-ins-of (make-hash))   ; reg-id -> 定义指令
  (define defined-set (make-hash))  ; reg-id -> #t (曾被定义)
  (fn-for-each-block fn
    (lambda (block)
      (for ([ins (in-pvector (basic-block-instructions block))])
        (when (ast-ins? ins)
          (for ([d (in-list (use-def-flat-defs (extract-use-def ins)))])
            (define r (reg-ref->reg-id d))
            (hash-set! defined-set r #t)
            (hash-update! def-count r add1 0)
            (hash-set! def-ins-of r ins))))))
  ;; 不变装载配方：返回 (cons dst-kind mem) 或 #f
  (define (invariant-load-recipe v)
    (define di (hash-ref def-ins-of v #f))
    (and di (= 1 (hash-ref def-count v 0))
         (match di
           [(ast-ins 'ldr _ (list dst (and mem (ast-mem base offset idx-mode _ _ _))) _)
            (and (ast-reg? dst)
                 (equal? (areg->reg-id dst) v)
                 (eq? idx-mode 'offset)
                 (ast-reg? base)
                 (let ([bid (areg->reg-id base)])
                   ;; base 值不变：至多一个 def (0=函数输入寄存器；
                   ;; 1=参数装载 mov base,argreg，位于入口、支配所有重载点)。
                   ;; def-count<=1 保证全函数无重定义。
                   (and bid (<= (hash-ref def-count bid 0) 1)))
                 (or (not offset) (ast-imm? offset))
                 (cons (ast-reg-kind dst) mem))]
           [_ #f])))
  ;; 候选来源：跨调用存活的虚拟 gpr
  (define recipe (make-hash))       ; v -> (cons kind mem)
  (define remove-def (make-hasheq)) ; def 指令 -> #t
  (for ([kv (in-reg-om across)])
    (define v (car kv))
    (when (and (reg-id-virtual? v) (eq? (reg-id-class v) 'gpr))
      (define r (invariant-load-recipe v))
      (when r
        (hash-set! recipe v r)
        (hash-set! remove-def (hash-ref def-ins-of v) #t))))
  (if (zero? (hash-count recipe))
      fn
      (transform-fn fn recipe remove-def)))

(define (transform-fn fn recipe remove-def)
  (define counter (box 0))
  (define (fresh-sym v)
    (define k (unbox counter))
    (set-box! counter (add1 k))
    (string->symbol (format "~a$rs~a" (reg-id-id v) k)))
  (define new-blocks
    (for/fold ([blocks (asm-function-blocks fn)])
              ([kv (in-intmap-pairs (asm-function-blocks fn))])
      (define bb-key (car kv))
      (define block (cdr kv))
      (intmap-set blocks bb-key
                       (transform-block block recipe remove-def fresh-sym))))
  (struct-copy asm-function fn [blocks new-blocks]))

(define (transform-block block recipe remove-def fresh-sym)
  (define new-instrs
    (for/fold ([acc (pvector-empty)])
              ([ins (in-pvector (basic-block-instructions block))])
      (cond
        [(hash-ref remove-def ins #f) acc]   ; 删除原始一次性装载
        [(ast-ins? ins)
         (define ud (extract-use-def ins))
         (define used-cands
           (remove-duplicates
            (for/list ([u (in-list (use-def-flat-uses ud))]
                       #:when (hash-ref recipe (reg-ref->reg-id u) #f))
              (reg-ref->reg-id u))))
         (cond
           [(null? used-cands) (pvector-cons-right acc ins)]
           [else
            (define sym-map (make-hash))  ; 旧符号 -> 新符号
            (define acc1
              (for/fold ([a acc]) ([v (in-list used-cands)])
                (define kind+mem (hash-ref recipe v))
                (define kind (car kind+mem))
                (define mem (cdr kind+mem))
                (define nsym (fresh-sym v))
                (hash-set! sym-map (reg-id-id v) nsym)
                (pvector-cons-right a
                  (ast-ins 'ldr #f
                           (list (ast-reg kind nsym #f #f #f #f (ast-srcloc ins))
                                 mem)
                           (ast-srcloc ins)))))
            (pvector-cons-right acc1 (subst-ins-ids ins sym-map))])]
        [else (pvector-cons-right acc ins)])))
  (struct-copy basic-block block [instructions new-instrs]))

;; 把指令中 id 属于 sym-map 的 ast-reg 替换为新符号 (仅使用位置；
;; 候选的唯一 def 已删除，故其余出现都是使用)
(define (subst-ins-ids ins sym-map)
  (match ins
    [(ast-ins mnem suffix operands loc)
     (ast-ins mnem suffix (map (lambda (op) (subst-op-ids op sym-map)) operands) loc)]
    [_ ins]))

(define (subst-op-ids op sym-map)
  (match op
    [(ast-reg kind id gs idx el pm loc)
     (define n (and (symbol? id) (hash-ref sym-map id #f)))
     (if n (ast-reg kind n gs idx el pm loc) op)]
    [(ast-mem base offset im sh ex loc)
     (ast-mem (subst-op-ids base sym-map)
              (and offset (subst-op-ids offset sym-map))
              im sh ex loc)]
    [(ast-reglist regs loc)
     (ast-reglist (map (lambda (r) (subst-op-ids r sym-map)) regs) loc)]
    [_ op]))
