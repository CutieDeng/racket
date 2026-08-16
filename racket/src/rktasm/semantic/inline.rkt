#lang racket

;; ============================================================
;; semantic/inline.rkt - (: inline foo) 展开
;; ============================================================
;;
;; 语义:
;;   (: inline callee) 在当前函数体内展开 callee 的函数体
;;   - callee 的 ret 会被改写为跳转到内联出口标签
;;   - callee 的局部标签会重命名，避免冲突
;;   - callee 的虚拟寄存器会重命名，避免与 caller 冲突

(require "../parser/ast.rkt"
         "control-flow.rkt"
         "../pipeline/regalloc/abi.rkt"
         "../pipeline/regalloc/abi-config.rkt"
         racket/intmap
         racket/pvector
         racket/set
         racket/string)

(provide expand-inline-items
         expand-inline-cfg
         cfg->items
         collect-function-attrs)

;; 格式化 srcloc: file:line:col
(define (format-loc loc)
  (match loc
    [(srcloc src line col _ _)
     (define src-str
       (cond
         [(path? src) (path->string src)]
         [(symbol? src) (symbol->string src)]
         [src (~a src)]
         [else "<unknown>"]))
     (format "~a:~a:~a"
             src-str
             (or line 0)
             (or col 0))]
    [_ "<unknown>"]))

(define (raise-inline-error loc fmt . args)
  (error 'inline
         (format "~a: ~a"
                 (format-loc loc)
                 (apply format fmt args))))

(define (sanitize-symbol-name s)
  (regexp-replace* #rx"[^A-Za-z0-9_]" (symbol->string s) "_"))

;; 收集每个函数体（不含 function/end-function 自身）
(define (collect-function-bodies items)
  (define bodies (make-hash))
  (define in-fn? #f)
  (define fn-name #f)
  (define body-rev '())

  (for ([item (in-list items)])
    (match item
      [(ast-directive 'function name _ loc)
       (when in-fn?
         (raise-inline-error loc "发现嵌套 function 指令: ~a" name))
       (set! in-fn? #t)
       (set! fn-name name)
       (set! body-rev '())]
      [(ast-directive 'end-function _ _ loc)
       (unless in-fn?
         (raise-inline-error loc "发现多余的 end-function"))
       (hash-set! bodies fn-name (reverse body-rev))
       (set! in-fn? #f)
       (set! fn-name #f)
       (set! body-rev '())]
      [_
       (when in-fn?
         (set! body-rev (cons item body-rev)))]))

  (when in-fn?
    (raise-inline-error no-srcloc "函数 ~a 缺少 end-function" fn-name))

  bodies)

(define (collect-function-attrs items)
  (for/hash ([item (in-list items)]
             #:when (and (ast-directive? item)
                         (eq? (ast-directive-kind item) 'function)))
    (values (ast-directive-name item)
            (let ([args (ast-directive-args item)])
              (if (hash? args) args (hash))))))

(define (collect-local-label-map body rename-symbol)
  (for/hash ([item (in-list body)]
             #:when (and (ast-directive? item)
                         (eq? (ast-directive-kind item) 'label)
                         (symbol? (ast-directive-name item))))
    (define old (ast-directive-name item))
    (values old (rename-symbol old))))

(define (gpr-kind? k)
  (memq k '(x w)))

(define (scalar-fpr-kind? k)
  (memq k '(s d)))

(define (vector-fpr-kind? k)
  (memq k '(v q)))

(define (sve-fpr-kind? k)
  (eq? k 'z))

(define (predicate-kind? k)
  (eq? k 'p))

(define (fixed-fpr-kind? k)
  (or (scalar-fpr-kind? k)
      (vector-fpr-kind? k)))

(define (adapt-bound-reg template actual)
  (define template-kind (ast-reg-kind template))
  (define actual-kind (ast-reg-kind actual))
  (define kind
    (if (and (gpr-kind? template-kind) (gpr-kind? actual-kind))
        template-kind
        actual-kind))
  (struct-copy ast-reg template
               [kind kind]
               [id (ast-reg-id actual)]))

(define (inline-binding-map bindings)
  (for/hash ([binding (in-list bindings)])
    (match binding
      [(list (? ast-reg? formal) (? ast-reg? actual))
       (values (ast-reg-id formal) actual)]
      [_ (values #f #f)])))

(define (formal-key reg)
  (cons (ast-reg-kind reg) (ast-reg-id reg)))

(define (validate-inline-bindings target params bindings loc)
  (validate-named-bindings 'inline target params bindings loc))

(define (validate-named-bindings form target params bindings loc)
  (define param-keys
    (for/list ([param (in-list params)])
      (match param
        [(list _ (? ast-reg? reg)) (formal-key reg)]
        [_ (raise-inline-error loc "~a ~a 的参数签名非法: ~a" form target param)])))
  (define param-set (list->set param-keys))
  (define seen (mutable-set))
  (for ([binding (in-list bindings)])
    (match binding
      [(list (? ast-reg? formal) (? ast-reg? actual))
       (define key (formal-key formal))
       (unless (set-member? param-set key)
         (raise-inline-error loc "~a ~a 绑定了未声明参数: ~a"
                             form
                             target
                             (ast->string formal)))
       (when (set-member? seen key)
         (raise-inline-error loc "~a ~a 重复绑定参数: ~a"
                             form
                             target
                             (ast->string formal)))
       (set-add! seen key)]
      [_ (raise-inline-error loc "~a ~a 绑定格式非法: ~a" form target binding)]))
  (for ([param (in-list params)]
        [key (in-list param-keys)])
    (unless (set-member? seen key)
      (match param
        [(list _ (? ast-reg? reg))
         (raise-inline-error loc "~a ~a 缺少参数绑定: ~a"
                             form
                             target
                             (ast->string reg))]))))

(define (lookup-binding bindings formal)
  (for/first ([binding (in-list bindings)]
              #:when (match binding
                       [(list (? ast-reg? f) _) (equal? (formal-key f) (formal-key formal))]
                       [_ #f]))
    (second binding)))

(define (resolve-managed-call-abi attrs loc)
  (define abi-name0
    (or (and (hash? attrs) (hash-ref attrs 'abi #f))
        (default-abi-name)))
  (define abi-name
    (cond
      [(eq? abi-name0 'auto) 'aapcs64]
      [else abi-name0]))
  (cond
    [abi-name
     (define abi
       (or (get-abi-by-name abi-name)
           (and (eq? abi-name 'aapcs64) arm64-abi)))
     (unless abi
       (raise-inline-error loc "managed call ABI is not defined: ~a" abi-name))
     abi]
    [else arm64-abi]))

(define (param-reg-class formal loc)
  (define kind (ast-reg-kind formal))
  (when (ast-reg-group-size formal)
    (raise-inline-error loc ".call parameter register groups are not supported yet: ~a"
                        (ast->string formal)))
  (when (ast-reg-index formal)
    (raise-inline-error loc ".call parameter lane/index views are not supported yet: ~a"
                        (ast->string formal)))
  (when (ast-reg-pred-mode formal)
    (raise-inline-error loc ".call parameter predicate modes are not supported yet: ~a"
                        (ast->string formal)))
  (cond
    [(gpr-kind? kind) 'gpr]
    [(or (fixed-fpr-kind? kind) (sve-fpr-kind? kind)) 'fpr]
    [(predicate-kind? kind) 'predicate]
    [else
     (raise-inline-error loc ".call parameter register class is not supported yet: ~a"
                         (ast->string formal))]))

(define (slot-regs-for-class abi class)
  (case class
    [(gpr) (abi-get-arg-regs abi 'gpr)]
    [(fpr) (abi-get-arg-regs abi 'fpr)]
    [(predicate) (abi-get-arg-regs abi 'predicate)]
    [else '()]))

(define (return-regs-for-class abi class)
  (case class
    [(gpr) (abi-get-return-regs abi 'gpr)]
    [(fpr) (abi-get-return-regs abi 'fpr)]
    [(predicate) (abi-get-return-regs abi 'predicate)]
    [else '()]))

(define (next-slot-index! counters class)
  (define current (hash-ref counters class 0))
  (hash-set! counters class (add1 current))
  current)

(define (slot-reg-for formal class phys-reg)
  (define kind (ast-reg-kind formal))
  (ast-reg kind
           phys-reg
           #f
           #f
           (ast-reg-element formal)
           #f
           (ast-reg-loc formal)))

(define (param-slot mode formal input-slot output-slot)
  (list mode formal input-slot output-slot))

(define (param-slot-mode slot) (first slot))
(define (param-slot-formal slot) (second slot))
(define (param-slot-input slot) (third slot))
(define (param-slot-output slot) (fourth slot))

(define (mode-needs-input? mode)
  (memq mode '(in inout)))

(define (mode-needs-output? mode)
  (memq mode '(out inout)))

(define (c-like-public-profile? attrs)
  (define export? (hash-ref attrs 'export #f))
  (define profile
    (or (hash-ref attrs 'public-abi-profile #f)
        (hash-ref attrs 'profile #f)
        (hash-ref attrs 'export-profile #f)
        (and export? 'c-aapcs64)))
  (and export?
       (if (memq profile '(c-aapcs64 apple-c-arm64)) #t #f)))

(define (allocate-param-reg formal class regs counters loc slot-kind)
  (define slot-index (next-slot-index! counters class))
  (when (>= slot-index (length regs))
    (raise-inline-error loc
                        ".call ABI has no ~a ~a for parameter ~a (needed index ~a)"
                        class
                        slot-kind
                        (ast->string formal)
                        slot-index))
  (slot-reg-for formal class (list-ref regs slot-index)))

(define (function-param-slots/internal params loc abi)
  (define counters (make-hash))
  (for/list ([param (in-list params)])
    (match param
      [(list mode (? ast-reg? formal))
       (define class (param-reg-class formal loc))
       (define slot
         (allocate-param-reg formal
                             class
                             (slot-regs-for-class abi class)
                             counters
                             loc
                             "slot"))
       (param-slot mode
                   formal
                   (and (mode-needs-input? mode) slot)
                   (and (mode-needs-output? mode) slot))]
      [_ (raise-inline-error loc "函数参数签名非法: ~a" param)])))

(define (function-param-slots/c-public params loc abi)
  (define input-counters (make-hash))
  (define output-counters (make-hash))
  (for/list ([param (in-list params)])
    (match param
      [(list mode (? ast-reg? formal))
       (define class (param-reg-class formal loc))
       (define input-slot
         (and (mode-needs-input? mode)
              (allocate-param-reg formal
                                  class
                                  (slot-regs-for-class abi class)
                                  input-counters
                                  loc
                                  "argument slot")))
       (define output-slot
         (and (mode-needs-output? mode)
              (allocate-param-reg formal
                                  class
                                  (return-regs-for-class abi class)
                                  output-counters
                                  loc
                                  "return slot")))
       (param-slot mode formal input-slot output-slot)]
      [_ (raise-inline-error loc "函数参数签名非法: ~a" param)])))

(define (function-param-slots params loc attrs)
  (define abi (resolve-managed-call-abi attrs loc))
  (if (c-like-public-profile? attrs)
      (function-param-slots/c-public params loc abi)
      (function-param-slots/internal params loc abi)))

(define (vector-copy-view reg)
  (ast-reg 'v
           (ast-reg-id reg)
           #f
           #f
           '16b
           #f
           (ast-reg-loc reg)))

(define (sve-copy-view reg)
  (ast-reg 'z
           (ast-reg-id reg)
           #f
           #f
           'd
           #f
           (ast-reg-loc reg)))

(define (predicate-copy-view reg)
  (ast-reg 'p
           (ast-reg-id reg)
           #f
           #f
           'b
           #f
           (ast-reg-loc reg)))

(define (mov-ins dst src loc)
  (define dst-kind (and (ast-reg? dst) (ast-reg-kind dst)))
  (define src-kind (and (ast-reg? src) (ast-reg-kind src)))
  (cond
    [(and (scalar-fpr-kind? dst-kind)
          (scalar-fpr-kind? src-kind))
     (ast-ins 'fmov #f (list dst src) loc)]
    [(and (vector-fpr-kind? dst-kind)
          (vector-fpr-kind? src-kind))
     (ast-ins 'mov #f
              (list (vector-copy-view dst)
                    (vector-copy-view src))
              loc)]
    [(and (sve-fpr-kind? dst-kind)
          (sve-fpr-kind? src-kind))
     (ast-ins 'orr #f
              (list (sve-copy-view dst)
                    (sve-copy-view src)
                    (sve-copy-view src))
              loc)]
    [(and (predicate-kind? dst-kind)
          (predicate-kind? src-kind))
     (ast-ins 'mov #f
              (list (predicate-copy-view dst)
                    (predicate-copy-view src))
              loc)]
    [else
     (ast-ins 'mov #f (list dst src) loc)]))

(define (same-reg-location? a b)
  (and (ast-reg? a)
       (ast-reg? b)
       (eq? (ast-reg-kind a) (ast-reg-kind b))
       (equal? (ast-reg-id a) (ast-reg-id b))))

(define (maybe-mov-ins dst src loc)
  (and (not (same-reg-location? dst src))
       (mov-ins dst src loc)))

(define (label-ins target loc)
  (ast-label target #f loc))

(define (copy-location-class reg)
  (define kind (ast-reg-kind reg))
  (cond
    [(gpr-kind? kind) 'gpr]
    [(or (fixed-fpr-kind? kind) (sve-fpr-kind? kind)) 'fpr]
    [(predicate-kind? kind) 'predicate]
    [else kind]))

(define (copy-location-key reg)
  (and (ast-reg? reg)
       (list (copy-location-class reg)
             (ast-reg-id reg)
             (ast-reg-index reg))))

(define (copy-location=? a b)
  (equal? (copy-location-key a)
          (copy-location-key b)))

(define (copy-temp-like reg prefix index loc)
  (struct-copy ast-reg reg
               [id (string->symbol (format "~a~a" prefix index))]
               [loc loc]))

(define (adapt-temp-view temp source)
  (struct-copy ast-reg source
               [id (ast-reg-id temp)]
               [loc (ast-reg-loc temp)]))

(define (parallel-copy-moves copies temp-prefix loc)
  (define pending0
    (filter (lambda (copy)
              (not (same-reg-location? (first copy) (second copy))))
            copies))
  (let loop ([pending pending0] [temp-index 0])
    (cond
      [(null? pending) '()]
      [else
       (define source-keys
         (for/list ([copy (in-list pending)])
           (copy-location-key (second copy))))
       (define movable
         (for/first ([copy (in-list pending)]
                     #:unless (member (copy-location-key (first copy))
                                      source-keys))
           copy))
       (cond
         [movable
          (cons (mov-ins (first movable) (second movable) loc)
                (loop (remove movable pending) temp-index))]
         [else
          (define cycle-copy (first pending))
          (define cycle-src (second cycle-copy))
          (define temp (copy-temp-like cycle-src temp-prefix temp-index loc))
          (define cycle-src-key (copy-location-key cycle-src))
          (cons
           (mov-ins temp cycle-src loc)
           (loop
            (for/list ([copy (in-list pending)])
              (define dst (first copy))
              (define src (second copy))
              (if (equal? (copy-location-key src) cycle-src-key)
                  (list dst (adapt-temp-view temp src))
                  copy))
            (add1 temp-index)))])])))

(define (explicit-interference-constraint left right loc)
  (ast-directive 'reg-interfere #f (list left right) loc))

(define (slot-bundle-constraints value/slot-pairs loc)
  (apply append
         (for/list ([pair (in-list value/slot-pairs)])
           (define value (first pair))
           (define own-slot (second pair))
           (for/list ([other-pair (in-list value/slot-pairs)]
                      #:unless (or (same-reg-location? own-slot
                                                       (second other-pair))
                                    (same-reg-location? value
                                                       (second other-pair))))
             (explicit-interference-constraint value (second other-pair) loc)))))

(define (call-slot-inputs slots bindings loc)
  (define copies
    (for/list ([slot (in-list slots)]
               #:when (mode-needs-input? (param-slot-mode slot)))
      (define formal (param-slot-formal slot))
      (define actual (lookup-binding bindings formal))
      (define actual* (adapt-bound-reg formal actual))
      (list (param-slot-input slot) actual*)))
  (define constraints
    (slot-bundle-constraints
     (for/list ([copy (in-list copies)])
       (list (second copy) (first copy)))
     loc))
  (append constraints
          (parallel-copy-moves copies "__asmp_call_in$" loc)))

(define (call-slot-outputs slots bindings loc)
  (define copies
    (for/list ([slot (in-list slots)]
               #:when (mode-needs-output? (param-slot-mode slot)))
      (define formal (param-slot-formal slot))
      (define actual (lookup-binding bindings formal))
      (define actual* (adapt-bound-reg formal actual))
      (list actual* (param-slot-output slot))))
  (define constraints
    (slot-bundle-constraints copies loc))
  (append constraints
          (parallel-copy-moves copies "__asmp_call_out$" loc)))

(define (function-entry-livein-constraints slots loc)
  (define input-slots
    (for/list ([slot (in-list slots)]
               #:when (mode-needs-input? (param-slot-mode slot)))
      slot))
  (apply append
         (for/list ([slot (in-list input-slots)]
                    [index (in-naturals)])
             (define formal (param-slot-formal slot))
             (for/list ([other-slot (in-list (drop input-slots (add1 index)))])
             (explicit-interference-constraint formal
                                               (param-slot-input other-slot)
                                               loc)))))

(define (function-entry-moves-from-slots slots loc)
  (append
   (function-entry-livein-constraints slots loc)
   (filter values
           (for/list ([slot (in-list slots)]
                      #:when (mode-needs-input? (param-slot-mode slot)))
             (maybe-mov-ins (param-slot-formal slot)
                            (param-slot-input slot)
                            loc)))))

(define (function-return-moves-from-slots slots loc)
  (define copies
    (for/list ([slot (in-list slots)]
               #:when (mode-needs-output? (param-slot-mode slot)))
      (list (param-slot-output slot)
            (param-slot-formal slot))))
  (define constraints
    (slot-bundle-constraints
     (for/list ([copy (in-list copies)])
       (list (second copy) (first copy)))
     loc))
  (append constraints
          (parallel-copy-moves copies "__asmp_return$" loc)))

(define (function-entry-moves params attrs loc)
  (function-entry-moves-from-slots
   (function-param-slots params loc attrs)
   loc))

(define (function-return-moves params attrs loc)
  (function-return-moves-from-slots
   (function-param-slots params loc attrs)
   loc))

(define (insert-after-leading-labels body inserted)
  (let loop ([rest body] [labels '()])
    (match rest
      [(cons (ast-directive 'label _ _ _) tail)
       (loop tail (cons (car rest) labels))]
      [_ (append (reverse labels) inserted rest)])))

(define (entry-sp-reg? reg)
  (and (ast-reg? reg)
       (eq? (ast-reg-id reg) 'sp)))

(define (entry-fp-reg? reg)
  (and (ast-reg? reg)
       (or (and (eq? (ast-reg-kind reg) 'x)
                (equal? (ast-reg-id reg) 29))
           (eq? (ast-reg-id reg) 'fp))))

(define (entry-lr-reg? reg)
  (and (ast-reg? reg)
       (or (and (eq? (ast-reg-kind reg) 'x)
                (equal? (ast-reg-id reg) 30))
           (eq? (ast-reg-id reg) 'lr))))

(define (entry-frame-save-ins? item)
  (match item
    [(ast-ins 'stp _ (list left right (? ast-mem? mem)) _)
     (and (entry-fp-reg? left)
          (entry-lr-reg? right)
          (entry-sp-reg? (ast-mem-base mem))
          (eq? (ast-mem-index-mode mem) 'pre))]
    [_ #f]))

(define (entry-frame-pointer-ins? item)
  (match item
    [(ast-ins 'mov _ (list dst src) _)
     (and (entry-fp-reg? dst)
          (entry-sp-reg? src))]
    [_ #f]))

(define (entry-prefix-directive? item)
  (or (and (ast-directive? item)
           (memq (ast-directive-kind item) '(label save!)))
      (entry-frame-save-ins? item)
      (entry-frame-pointer-ins? item)))

(define (insert-after-entry-prefix body inserted)
  (let loop ([rest body] [prefix '()])
    (match rest
      [(cons item tail)
       #:when (entry-prefix-directive? item)
       (loop tail (cons item prefix))]
      [_ (append (reverse prefix) inserted rest)])))

(define (load-directive? item)
  (and (ast-directive? item)
       (eq? (ast-directive-kind item) 'load!)))

(define (insert-return-moves body slots)
  (let loop ([rest body])
    (match rest
      ['() '()]
      [(cons item tail)
       (cond
         [(load-directive? item)
          (define-values (loads after-loads)
            (let collect ([xs rest] [loads-rev '()])
              (match xs
                [(cons load-item more)
                 #:when (load-directive? load-item)
                 (collect more (cons load-item loads-rev))]
                [_ (values (reverse loads-rev) xs)])))
          (match after-loads
            [(cons (ast-ins 'ret suffix operands ret-loc) more)
             (append (function-return-moves-from-slots slots ret-loc)
                     loads
                     (list (ast-ins 'ret suffix operands ret-loc))
                     (loop more))]
            [_ (cons item (loop tail))])]
         [else
          (match item
            [(ast-ins 'ret suffix operands ret-loc)
             (append (function-return-moves-from-slots slots ret-loc)
                     (list (ast-ins 'ret suffix operands ret-loc))
                     (loop tail))]
            [_ (cons item (loop tail))])])])))

(define (apply-function-boundary body attrs loc)
  (define params (hash-ref attrs 'function-params #f))
  (if (not params)
      body
      (let* ([slots (function-param-slots params loc attrs)]
             [entry-moves (function-entry-moves-from-slots slots loc)]
             [body-with-return-moves (insert-return-moves body slots)])
        (insert-after-entry-prefix body-with-return-moves entry-moves))))

(define (lower-call target attrs bindings loc)
  (when (hash-ref attrs 'inline-only #f)
    (raise-inline-error loc ".call target is inline-only; use .inline: ~a" target))
  (define params (hash-ref attrs 'function-params #f))
  (unless params
    (raise-inline-error loc ".call target has no .function signature: ~a" target))
  (validate-named-bindings 'call target params bindings loc)
  (define slots (function-param-slots params loc attrs))
  (append
   (call-slot-inputs slots bindings loc)
   (list (ast-ins 'bl #f (list (label-ins target loc)) loc))
   (call-slot-outputs slots bindings loc)))

(define (call-directive-bindings args)
  (if (hash? args)
      (hash-ref args 'bindings '())
      args))

(define (call-directive-option args key [default #f])
  (if (hash? args)
      (hash-ref args key default)
      default))

(define (build-source-variant-index function-attrs)
  (for/fold ([index (hash)])
            ([(name attrs) (in-hash function-attrs)]
             #:when (hash-ref attrs 'variant-of #f))
    (define logical-name (hash-ref attrs 'variant-of))
    (hash-set index
              logical-name
              (cons name (hash-ref index logical-name '())))))

(define (source-variant-matches? attrs variant-id target-feature)
  (and (or (not variant-id)
           (equal? (hash-ref attrs 'version-id #f) variant-id))
       (or (not target-feature)
           (equal? (hash-ref attrs 'target-feature #f) target-feature))))

(define (source-variant-request-text variant-id target-feature)
  (string-join
   (filter values
           (list (and variant-id (format "variant=~a" variant-id))
                 (and target-feature (format "feature=~a" target-feature))))
   " "))

(define (resolve-call-target-variant target args function-attrs variant-index loc)
  (define variant-id (call-directive-option args 'variant-id #f))
  (define target-feature (call-directive-option args 'target-feature #f))
  (if (or variant-id target-feature)
      (let* ([candidates (hash-ref variant-index target '())]
             [matches
              (filter
               (lambda (candidate)
                 (source-variant-matches?
                  (hash-ref function-attrs candidate (hash))
                  variant-id
                  target-feature))
               candidates)])
        (match matches
          ['()
           (raise-inline-error
            loc
            ".call ~a has no source variant matching ~a"
            target
            (source-variant-request-text variant-id target-feature))]
          [(list selected) selected]
          [_
           (raise-inline-error
            loc
            ".call ~a source variant selection is ambiguous for ~a: ~a"
            target
            (source-variant-request-text variant-id target-feature)
            (string-join (map symbol->string matches) ", "))]))
      target))

(define (inline-target-params attrs)
  (or (hash-ref attrs 'inline-params #f)
      (hash-ref attrs 'function-params #f)))

(define (rewrite-reg reg rename-symbol [bindings (hash)])
  (define rid (ast-reg-id reg))
  (cond
    [(not (symbol? rid)) reg]
    [(hash-ref bindings rid #f)
     => (lambda (actual) (adapt-bound-reg reg actual))]
    [else
     (struct-copy ast-reg reg [id (rename-symbol rid)])]))

(define (rewrite-operand op label-map rename-symbol [bindings (hash)])
  (match op
    [(? ast-reg? r)
     (rewrite-reg r rename-symbol bindings)]
    [(ast-label name reloc loc)
     (ast-label (hash-ref label-map name name) reloc loc)]
    [(ast-mem base offset index-mode shift extend loc)
     (ast-mem (rewrite-operand base label-map rename-symbol bindings)
              (and offset (rewrite-operand offset label-map rename-symbol bindings))
              index-mode
              shift
              extend
              loc)]
    [(ast-reglist regs loc)
     (ast-reglist
      (map (lambda (r) (rewrite-operand r label-map rename-symbol bindings)) regs)
      loc)]
    [_ op]))

(define (rewrite-save-load-directive d rename-symbol [bindings (hash)])
  (define kind (ast-directive-kind d))
  (define name (ast-directive-name d))
  (define args (ast-directive-args d))
  (define loc (ast-directive-loc d))

  (match args
    [(list regs size-spec)
     (define regs*
       (if (eq? regs 'all)
           'all
           (for/list ([r (in-list regs)])
             (if (ast-reg? r)
                 (rewrite-reg r rename-symbol bindings)
                 r))))
     (ast-directive kind name (list regs* size-spec) loc)]
    [_ d]))

(define (with-inline-entry-loc items inline-loc)
  (let loop ([rest items] [prefix '()])
    (match rest
      ['() (reverse prefix)]
      [(cons (? ast-ins? ins) tail)
       (append (reverse prefix)
               (cons (struct-copy ast-ins ins [loc inline-loc]) tail))]
      [(cons item tail)
       (loop tail (cons item prefix))])))

;; 将一次 inline 实例化并重命名
(define (instantiate-inline caller target body inline-loc fresh-id [bindings '()])
  (define prefix
    (format "inl_~a_~a_~a"
            (sanitize-symbol-name caller)
            (sanitize-symbol-name target)
            fresh-id))
  (define (rename-symbol sym)
    (string->symbol (format "~a__~a" prefix (symbol->string sym))))
  (define exit-label (string->symbol (format "~a__exit" prefix)))

  (define label-map (collect-local-label-map body rename-symbol))
  (define bindings-map (inline-binding-map bindings))

  (define rewritten
    (for/fold ([out '()]) ([item (in-list body)])
      (define transformed
        (match item
          [(ast-ins 'ret _ _ loc)
           (list (ast-ins 'b #f (list (ast-label exit-label #f loc)) loc))]
          [(ast-ins 'eret _ _ loc)
           (raise-inline-error loc "eret 不能用于 (: inline ~a) 的函数体" target)]
          [(ast-ins mnem suffix operands loc)
           (list (ast-ins mnem
                          suffix
                          (map (lambda (op) (rewrite-operand op label-map rename-symbol bindings-map))
                               operands)
                          loc))]
          [(ast-directive 'label name args loc)
           (list (ast-directive 'label (hash-ref label-map name name) args loc))]
          [(ast-directive (or 'save! 'load!) _ _ _)
           (list (rewrite-save-load-directive item rename-symbol bindings-map))]
          [(ast-directive 'weak-mov name args loc)
           (match args
             [(list dst src)
              (list (ast-directive 'weak-mov name
                                   (list (rewrite-reg dst rename-symbol bindings-map)
                                         (rewrite-reg src rename-symbol bindings-map))
                                   loc))]
             [_ (list item)])]
          [(ast-directive 'inline _ _ loc)
           (raise-inline-error loc "inline 展开阶段不应保留 inline 指令")]
          [_ (list item)]))
      (append out transformed)))

  ;; 统一追加出口标签，供被改写的 ret 跳转。是否省略落到下一块的
  ;; 末端跳转由 emit 阶段根据最终 CFG 块顺序决定，避免 inline 展开时
  ;; 过早删除分支后又被块重排改变语义。
  (with-inline-entry-loc
   (append rewritten
           (list (ast-directive 'label exit-label '() inline-loc)))
   inline-loc))

;; 展开所有 (: inline target)
(define (expand-inline-items items)
  (define function-bodies (collect-function-bodies items))
  (define function-attrs (collect-function-attrs items))
  (define source-variant-index (build-source-variant-index function-attrs))
  (define inline-counter 0)

  (define (next-inline-id)
    (set! inline-counter (add1 inline-counter))
    inline-counter)

  (define (expand-body caller body stack)
    (for/fold ([out '()]) ([item (in-list body)])
      (define expanded
        (match item
          [(ast-directive 'inline target bindings loc)
           (unless (symbol? target)
             (raise-inline-error loc "inline 目标必须是函数名符号"))
           (when (member target stack)
             (raise-inline-error
              loc
              "检测到递归 inline: ~a -> ~a"
              (string-join (map symbol->string (reverse stack)) " -> ")
              target))
           (define target-body (hash-ref function-bodies target #f))
           (unless target-body
             (raise-inline-error loc "inline 目标函数不存在: ~a" target))
           (define target-attrs (hash-ref function-attrs target (hash)))
           (define target-params (inline-target-params target-attrs))
           (when target-params
             (validate-inline-bindings target target-params bindings loc))
           (define expanded-target
             (expand-body target target-body (cons target stack)))
           (instantiate-inline caller target expanded-target loc (next-inline-id) bindings)]
          [(ast-directive 'call target args loc)
           (unless (symbol? target)
             (raise-inline-error loc ".call 目标必须是函数名符号"))
           (define selected-target
             (resolve-call-target-variant
              target
              args
              function-attrs
              source-variant-index
              loc))
           (define target-attrs (hash-ref function-attrs selected-target #f))
           (unless target-attrs
             (raise-inline-error loc ".call 目标函数不存在: ~a" selected-target))
           (lower-call selected-target target-attrs (call-directive-bindings args) loc)]
          [_ (list item)]))
      (append out expanded)))

  ;; 第二遍：按原顺序重建程序，并对函数体做 inline 展开
  (define out-rev '())
  (define in-fn? #f)
  (define fn-name #f)
  (define fn-loc no-srcloc)
  (define body-rev '())

  (for ([item (in-list items)])
    (cond
      [(not in-fn?)
       (match item
         [(ast-directive 'function name attrs loc)
          (set! in-fn? #t)
          (set! fn-name name)
          (set! fn-loc loc)
          (set! body-rev '())
          (define item*
            (if (and (hash? attrs) (hash-has-key? attrs 'function-params))
                (struct-copy ast-directive item
                             [args (hash-remove attrs 'function-params)])
                item))
          (set! out-rev (cons item* out-rev))]
         [_
          (set! out-rev (cons item out-rev))])]
      [else
       (match item
         [(ast-directive 'end-function _ _ loc)
          (define expanded (expand-body fn-name (reverse body-rev) (list fn-name)))
          (define fn-attrs (hash-ref function-attrs fn-name (hash)))
          (define expanded/boundary
            (if (hash-ref fn-attrs 'inline-only #f)
                expanded
                (apply-function-boundary expanded fn-attrs fn-loc)))
          ;; reversed 视图中顺序应为: end, reverse(expanded), function, ...
          (set! out-rev (cons item (append (reverse expanded/boundary) out-rev)))
          (set! in-fn? #f)
          (set! fn-name #f)
          (set! fn-loc no-srcloc)
          (set! body-rev '())]
         [_
          (set! body-rev (cons item body-rev))])]))

  (when in-fn?
    (raise-inline-error no-srcloc "函数 ~a 缺少 end-function" fn-name))

  (reverse out-rev))

;; ============================================================
;; CFG 级展开
;; ============================================================

(define (cfg-has-inline? cfg)
  (for/or ([i (in-range (cfg-function-count cfg))])
    (define fn (cfg-get-function cfg i))
    (or (fn-get-info fn 'function-params #f)
        (for/or ([kv (in-intmap-pairs (asm-function-blocks fn))])
          (define block (cdr kv))
          (for/or ([ins (in-pvector (basic-block-instructions block))])
            (and (ast-directive? ins)
                 (memq (ast-directive-kind ins) '(inline call))))))))

(define internal-fn-info-keys '(max-internal-align function-loc))

(define (fn-info->attr-hash fn)
  (for/fold ([h (hash)])
            ([kv (in-hash-pairs (asm-function-info fn))])
    (define k (car kv))
    (define v (cdr kv))
    (if (memq k internal-fn-info-keys)
        h
        (hash-set h k v))))

(define (function->items fn)
  (define fn-loc (fn-get-info fn 'function-loc no-srcloc))
  (define header
    (ast-directive 'function
                   (asm-function-name fn)
                   (fn-info->attr-hash fn)
                   fn-loc))
  (define (labels-for-block block)
    (define bbid (basic-block-id block))
    (sort
     (for/list ([kv (in-hash-pairs (asm-function-label->id fn))]
                #:when (equal? (cdr kv) bbid))
       (car kv))
     (lambda (a b)
       (string<? (symbol->string a) (symbol->string b)))))
  (define body
    (apply append
           (for/list ([kv (in-intmap-pairs (asm-function-blocks fn))])
             (define block (cdr kv))
             (append
              (for/list ([label (in-list (labels-for-block block))])
                (ast-directive 'label label '() no-srcloc))
              (for/list ([ins (in-pvector (basic-block-instructions block))])
                ins)))))
  (define footer (ast-directive 'end-function #f '() no-srcloc))
  (append (list header) body (list footer)))

(define (extern-items-from-cfg cfg)
  (define extern-syms (cfg-get-info cfg 'extern-symbols #f))
  (define extern-vars (cfg-get-info cfg 'extern-vars #f))
  (if (not extern-syms)
      '()
      (for/list ([sym (in-set extern-syms)])
        (if (and extern-vars (set-member? extern-vars sym))
            (ast-directive 'extern sym '(var) no-srcloc)
            (ast-directive 'extern sym '(func) no-srcloc)))))

(define (cfg->items cfg)
  (append
   (extern-items-from-cfg cfg)
   (apply append
          (for/list ([i (in-range (cfg-function-count cfg))])
            (function->items (cfg-get-function cfg i))))))

(define (expand-inline-cfg cfg)
  (if (not (cfg-has-inline? cfg))
      cfg
      (let* ([items (cfg->items cfg)]
             [expanded-items (expand-inline-items items)]
             [new-cfg (build-cfg expanded-items (control-flow-graph-source cfg))])
        ;; 保留原 CFG 的调试/扩展信息
        (struct-copy control-flow-graph new-cfg
                     [debug (control-flow-graph-debug cfg)]
                     [info (control-flow-graph-info cfg)]))))
