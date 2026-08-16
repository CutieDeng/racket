#lang racket

;; ============================================================
;; semantic/ipa-callconv.rkt - IPA call-convention clones
;; ============================================================
;;
;; A policy layer may give explicit (caller, callee, abi) selections, or ask
;; the local planner to choose among ABI candidates by managed .call move cost.
;; The pass validates those managed .call edges, clones the callee with an ABI
;; override, and rewrites only the selected callers to the clone.

(require "../parser/ast.rkt"
         "control-flow.rkt"
         "function-clone.rkt"
         "../pipeline/regalloc/abi.rkt"
         "../pipeline/regalloc/abi-config.rkt"
         racket/pvector
         racket/intmap
         racket/set)

(provide
 (struct-out managed-call-edge)
 (struct-out callconv-selection-report)
 (struct-out callconv-selection)
 (struct-out callconv-clone-summary)
 make-callconv-selection
 collect-managed-call-edges
 collect-callconv-hint-selections
 plan-callconv-selections
 infer-callconv-selections
 apply-callconv-selections)

(struct managed-call-edge
  (caller callee loc)
  #:transparent)

(struct managed-callsite
  (caller callee bindings abi-name loc)
  #:transparent)

(struct callconv-selection-report
  (caller callee baseline-abi baseline-cost selected-abi selected-cost savings)
  #:transparent)

(struct callconv-selection
  (caller callee abi-name version-id clone-reason specialization-key linkage-symbol site-loc)
  #:transparent)

(struct callconv-clone-summary
  (callee abi-name clone callers)
  #:transparent)

(define (make-callconv-selection #:caller caller
                                 #:callee callee
                                 #:abi abi-name
                                 #:version-id [version-id #f]
                                 #:clone-reason [clone-reason 'managed-callconv]
                                 #:specialization-key [specialization-key #f]
                                 #:linkage-symbol [linkage-symbol #f]
                                 #:site-loc [site-loc #f])
  (callconv-selection caller
                      callee
                      abi-name
                      version-id
                      clone-reason
                      specialization-key
                      linkage-symbol
                      site-loc))

(define (callconv-selection-version-id* selection)
  (or (callconv-selection-version-id selection)
      (string->symbol
       (format "cc.~a" (callconv-selection-abi-name selection)))))

(define (selection-group-key selection)
  (list (callconv-selection-callee selection)
        (callconv-selection-abi-name selection)
        (callconv-selection-version-id* selection)
        (callconv-selection-linkage-symbol selection)))

(define (resolve-known-abi abi-name)
  (load-abi-config)
  (or (get-abi-by-name abi-name)
      (and (eq? abi-name 'aapcs64) arm64-abi)))

(define (effective-managed-abi-name fn)
  (define abi-name0
    (or (fn-get-info fn 'abi #f)
        (default-abi-name)))
  (cond
    [(eq? abi-name0 'auto) 'aapcs64]
    [abi-name0 abi-name0]
    [else 'aapcs64]))

(define (validate-abi-name! abi-name)
  (unless (symbol? abi-name)
    (error 'apply-callconv-selections "ABI name must be a symbol: ~v" abi-name))
  (unless (resolve-known-abi abi-name)
    (error 'apply-callconv-selections "managed call ABI is not defined: ~a" abi-name)))

(define (collect-managed-call-edges cfg)
  (for/list ([site (in-list (collect-managed-callsites cfg))])
    (managed-call-edge (managed-callsite-caller site)
                       (managed-callsite-callee site)
                       (managed-callsite-loc site))))

(define (call-directive-bindings args)
  (if (hash? args)
      (hash-ref args 'bindings '())
      args))

(define (call-directive-abi-name args)
  (and (hash? args)
       (hash-ref args 'abi #f)))

(define (collect-managed-callsites cfg)
  (apply append
         (for/list ([kv (in-intmap-pairs (control-flow-graph-functions cfg))])
           (define fn (cdr kv))
           (define caller (asm-function-name fn))
           (apply append
                  (for/list ([bkv (in-intmap-pairs (asm-function-blocks fn))])
                    (define block (cdr bkv))
                    (for/list ([ins (in-pvector (basic-block-instructions block))]
                               #:when
                               (match ins
                                 [(ast-directive 'call (? symbol? _) _ _) #t]
                                 [_ #f]))
                      (match ins
                        [(ast-directive 'call callee args loc)
                         (managed-callsite caller
                                           callee
                                           (call-directive-bindings args)
                                           (call-directive-abi-name args)
                                           loc)])))))))

(define (collect-callconv-hint-selections cfg)
  (for/list ([site (in-list (collect-managed-callsites cfg))]
             #:when (managed-callsite-abi-name site))
    (make-callconv-selection
     #:caller (managed-callsite-caller site)
     #:callee (managed-callsite-callee site)
     #:abi (managed-callsite-abi-name site)
     #:clone-reason 'user-callconv-hint
     #:specialization-key
     (list 'source-callconv-hint
           (managed-callsite-caller site)
           (managed-callsite-callee site)
           (managed-callsite-abi-name site))
     #:site-loc (managed-callsite-loc site))))

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

(define (formal-key reg)
  (cons (ast-reg-kind reg) (ast-reg-id reg)))

(define (param-reg-class formal loc)
  (define kind (ast-reg-kind formal))
  (cond
    [(or (ast-reg-group-size formal)
         (ast-reg-index formal)
         (ast-reg-pred-mode formal))
     (error 'plan-callconv-selections
            "unsupported managed .call parameter view at ~a: ~a"
            loc
            (ast->string formal))]
    [(gpr-kind? kind) 'gpr]
    [(or (fixed-fpr-kind? kind) (sve-fpr-kind? kind)) 'fpr]
    [(predicate-kind? kind) 'predicate]
    [else
     (error 'plan-callconv-selections
            "unsupported managed .call parameter class at ~a: ~a"
            loc
            (ast->string formal))]))

(define (slot-regs-for-class abi class)
  (case class
    [(gpr) (abi-get-arg-regs abi 'gpr)]
    [(fpr) (abi-get-arg-regs abi 'fpr)]
    [(predicate) (abi-get-arg-regs abi 'predicate)]
    [else '()]))

(define (slot-reg-for formal phys-reg)
  (ast-reg (ast-reg-kind formal)
           phys-reg
           #f
           #f
           (ast-reg-element formal)
           #f
           (ast-reg-loc formal)))

(define (function-param-slots/abi params abi loc)
  (define counters (make-hash))
  (for/list ([param (in-list params)])
    (match param
      [(list mode (? ast-reg? formal))
       (define class (param-reg-class formal loc))
       (define slot-regs (slot-regs-for-class abi class))
       (define slot-index (hash-ref counters class 0))
       (hash-set! counters class (add1 slot-index))
       (and (< slot-index (length slot-regs))
            (list mode formal (slot-reg-for formal (list-ref slot-regs slot-index))))]
      [_ (error 'plan-callconv-selections
                "invalid managed .function parameter signature: ~v"
                param)])))

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

(define (lookup-binding bindings formal)
  (for/first ([binding (in-list bindings)]
              #:when (match binding
                       [(list (? ast-reg? f) _) (equal? (formal-key f) (formal-key formal))]
                       [_ #f]))
    (second binding)))

(define (validate-managed-bindings! caller callee params bindings loc)
  (define param-keys
    (for/list ([param (in-list params)])
      (match param
        [(list _ (? ast-reg? reg)) (formal-key reg)]
        [_ (error 'plan-callconv-selections
                  "invalid managed .function parameter signature: ~v"
                  param)])))
  (define param-set (list->set param-keys))
  (define seen (mutable-set))
  (for ([binding (in-list bindings)])
    (match binding
      [(list (? ast-reg? formal) (? ast-reg? _actual))
       (define key (formal-key formal))
       (unless (set-member? param-set key)
         (error 'plan-callconv-selections
                "~a -> ~a binds undeclared parameter at ~a: ~a"
                caller
                callee
                loc
                (ast->string formal)))
       (when (set-member? seen key)
         (error 'plan-callconv-selections
                "~a -> ~a duplicates parameter binding at ~a: ~a"
                caller
                callee
                loc
                (ast->string formal)))
       (set-add! seen key)]
      [_ (error 'plan-callconv-selections
                "invalid managed .call binding at ~a: ~v"
                loc
                binding)]))
  (for ([param (in-list params)]
        [key (in-list param-keys)])
    (unless (set-member? seen key)
      (match param
        [(list _ (? ast-reg? reg))
         (error 'plan-callconv-selections
                "~a -> ~a misses parameter binding at ~a: ~a"
                caller
                callee
                loc
                (ast->string reg))]))))

(define (same-reg-location? a b)
  (and (ast-reg? a)
       (ast-reg? b)
       (eq? (ast-reg-kind a) (ast-reg-kind b))
       (equal? (ast-reg-id a) (ast-reg-id b))))

(define (move-needed-cost dst src)
  (if (same-reg-location? dst src) 0 1))

(define (callsite-move-cost site params abi)
  (define slots (function-param-slots/abi params abi (managed-callsite-loc site)))
  (and (andmap values slots)
       (for/sum ([slot (in-list slots)])
         (define mode (first slot))
         (define formal (second slot))
         (define actual (lookup-binding (managed-callsite-bindings site) formal))
         (define actual* (adapt-bound-reg formal actual))
         (+ (if (memq mode '(in inout))
                (move-needed-cost (third slot) actual*)
                0)
            (if (memq mode '(out inout))
                (move-needed-cost actual* (third slot))
                0)))))

(define (callsite-group-key site)
  (cons (managed-callsite-caller site)
        (managed-callsite-callee site)))

(define (group-callsites sites)
  (define groups (make-hash))
  (define order '())
  (for ([site (in-list sites)])
    (define key (callsite-group-key site))
    (unless (hash-has-key? groups key)
      (hash-set! groups key '())
      (set! order (append order (list key))))
    (hash-set! groups key (append (hash-ref groups key) (list site))))
  (for/list ([key (in-list order)])
    (hash-ref groups key)))

(define (candidate-cost sites params abi)
  (for/fold ([total 0])
            ([site (in-list sites)]
             #:break (not total))
    (define cost (callsite-move-cost site params abi))
    (and cost (+ total cost))))

(define (best-candidate sites params candidate-abis baseline-cost)
  (for/fold ([best #f])
            ([candidate (in-list candidate-abis)])
    (define abi (resolve-known-abi candidate))
    (cond
      [(not abi) best]
      [else
       (define cost (candidate-cost sites params abi))
       (cond
         [(not cost) best]
         [(or (not best) (< cost (cdr best)))
          (cons candidate cost)]
         [else best])])))

(define (plan-callconv-group cfg sites candidate-abis min-move-savings)
  (define first-site (car sites))
  (define caller (managed-callsite-caller first-site))
  (define callee (managed-callsite-callee first-site))
  (define callee-fn (cfg-get-function-by-name cfg callee))
  (cond
    [(not callee-fn) (values #f #f)]
    [(fn-public-abi-barrier? callee-fn) (values #f #f)]
    [else
     (define params (fn-get-info callee-fn 'function-params #f))
     (cond
       [(not params) (values #f #f)]
       [else
        (for ([site (in-list sites)])
          (validate-managed-bindings! (managed-callsite-caller site)
                                      callee
                                      params
                                      (managed-callsite-bindings site)
                                      (managed-callsite-loc site)))
        (define baseline-abi-name (effective-managed-abi-name callee-fn))
        (define baseline-abi (resolve-known-abi baseline-abi-name))
        (unless baseline-abi
          (error 'plan-callconv-selections
                 "managed call ABI is not defined: ~a"
                 baseline-abi-name))
        (define baseline-cost (candidate-cost sites params baseline-abi))
        (unless baseline-cost
          (error 'plan-callconv-selections
                 "baseline ABI ~a has too few slots for ~a"
                 baseline-abi-name
                 callee))
        (define best (best-candidate sites params candidate-abis baseline-cost))
        (if (and best
                 (>= (- baseline-cost (cdr best)) min-move-savings))
            (let* ([selected-abi (car best)]
                   [selected-cost (cdr best)]
                   [savings (- baseline-cost selected-cost)]
                   [selection
                    (make-callconv-selection
                     #:caller caller
                     #:callee callee
                     #:abi selected-abi
                     #:clone-reason 'move-cost
                     #:specialization-key
                     (list 'abi selected-abi
                           'baseline baseline-abi-name
                           'baseline-cost baseline-cost
                           'selected-cost selected-cost))]
                   [report
                    (callconv-selection-report caller
                                               callee
                                               baseline-abi-name
                                               baseline-cost
                                               selected-abi
                                               selected-cost
                                               savings)])
              (values selection report))
            (values #f #f))])]))

(define (plan-callconv-selections cfg
                                  #:candidate-abis candidate-abis
                                  #:min-move-savings [min-move-savings 1])
  (for ([abi-name (in-list candidate-abis)])
    (validate-abi-name! abi-name))
  (for/fold ([selections '()]
             [reports '()]
             #:result (values (reverse selections) (reverse reports)))
            ([sites (in-list (group-callsites (collect-managed-callsites cfg)))])
    (define-values (selection report)
      (plan-callconv-group cfg sites candidate-abis min-move-savings))
    (values (if selection (cons selection selections) selections)
            (if report (cons report reports) reports))))

(define (infer-callconv-selections cfg
                                   #:candidate-abis candidate-abis
                                   #:min-move-savings [min-move-savings 1])
  (define-values (selections _reports)
    (plan-callconv-selections cfg
                              #:candidate-abis candidate-abis
                              #:min-move-savings min-move-savings))
  selections)

(define (managed-call-edge-set cfg)
  (for/set ([edge (in-list (collect-managed-call-edges cfg))])
    (cons (managed-call-edge-caller edge)
          (managed-call-edge-callee edge))))

(define (selection-site-targeted? selection)
  (and (callconv-selection-site-loc selection) #t))

(define (selection-edge-key selection)
  (cons (callconv-selection-caller selection)
        (callconv-selection-callee selection)))

(define (managed-callsite-matches-selection? site selection)
  (define site-abi (managed-callsite-abi-name site))
  (and (eq? (managed-callsite-caller site)
            (callconv-selection-caller selection))
       (eq? (managed-callsite-callee site)
            (callconv-selection-callee selection))
       (equal? (managed-callsite-loc site)
               (callconv-selection-site-loc selection))
       (or (not site-abi)
           (eq? site-abi (callconv-selection-abi-name selection)))))

(define (validate-selection-shape! selection)
  (unless (callconv-selection? selection)
    (error 'apply-callconv-selections
           "expected callconv-selection, got: ~v"
           selection))
  (unless (symbol? (callconv-selection-caller selection))
    (error 'apply-callconv-selections
           "caller must be a symbol: ~v"
           (callconv-selection-caller selection)))
  (unless (symbol? (callconv-selection-callee selection))
    (error 'apply-callconv-selections
           "callee must be a symbol: ~v"
           (callconv-selection-callee selection)))
  (validate-abi-name! (callconv-selection-abi-name selection))
  (define version-id (callconv-selection-version-id* selection))
  (unless (symbol? version-id)
    (error 'apply-callconv-selections
           "version-id must be a symbol: ~v"
           version-id))
  (define site-loc (callconv-selection-site-loc selection))
  (when (and site-loc (not (srcloc? site-loc)))
    (error 'apply-callconv-selections
           "site-loc must be an srcloc or #f: ~v"
           site-loc)))

(define (validate-selection-edge! cfg edge-set callsites selection)
  (define caller (callconv-selection-caller selection))
  (define callee (callconv-selection-callee selection))
  (unless (cfg-get-function-by-name cfg caller)
    (error 'apply-callconv-selections "caller function not found: ~a" caller))
  (define callee-fn (cfg-get-function-by-name cfg callee))
  (unless callee-fn
    (error 'apply-callconv-selections "callee function not found: ~a" callee))
  (unless (fn-get-info callee-fn 'function-params #f)
    (error 'apply-callconv-selections
           "callee has no managed .function signature: ~a"
           callee))
  (cond
    [(selection-site-targeted? selection)
     (unless (for/or ([site (in-list callsites)])
               (managed-callsite-matches-selection? site selection))
       (error 'apply-callconv-selections
              "no managed .call site from ~a to ~a at ~a"
              caller
              callee
              (callconv-selection-site-loc selection)))]
    [else
     (unless (set-member? edge-set (cons caller callee))
       (error 'apply-callconv-selections
              "no managed .call edge from ~a to ~a"
              caller
              callee))]))

(define (validate-unique-edge-selections! selections)
  (define edge-kinds (make-hash))
  (define edge-seen (make-hash))
  (define site-seen (make-hash))
  (for ([selection (in-list selections)])
    (define edge-key (selection-edge-key selection))
    (define kind (if (selection-site-targeted? selection) 'site 'edge))
    (define prior-kind (hash-ref edge-kinds edge-key #f))
    (when (and prior-kind (not (eq? prior-kind kind)))
      (error 'apply-callconv-selections
             "conflicting callconv selections for ~a -> ~a"
             (car edge-key)
             (cdr edge-key)))
    (hash-set! edge-kinds edge-key kind)
    (cond
      [(selection-site-targeted? selection)
       (define site-key
         (list (callconv-selection-caller selection)
               (callconv-selection-callee selection)
               (callconv-selection-site-loc selection)))
       (define prior (hash-ref site-seen site-key #f))
       (when (and prior
                  (not (equal? (selection-group-key prior)
                               (selection-group-key selection))))
         (error 'apply-callconv-selections
                "conflicting callconv selections for ~a -> ~a"
                (car edge-key)
                (cdr edge-key)))
       (hash-set! site-seen site-key selection)]
      [else
       (define prior (hash-ref edge-seen edge-key #f))
       (when (and prior
                  (not (equal? (selection-group-key prior)
                               (selection-group-key selection))))
         (error 'apply-callconv-selections
                "conflicting callconv selections for ~a -> ~a"
                (car edge-key)
                (cdr edge-key)))
       (hash-set! edge-seen edge-key selection)])))

(define (validate-selections! cfg selections)
  (for ([selection (in-list selections)])
    (validate-selection-shape! selection))
  (validate-unique-edge-selections! selections)
  (define callsites (collect-managed-callsites cfg))
  (define edge-set (managed-call-edge-set cfg))
  (for ([selection (in-list selections)])
    (validate-selection-edge! cfg edge-set callsites selection)))

(define (group-selections selections)
  (define groups (make-hash))
  (define order '())
  (for ([selection (in-list selections)])
    (define key (selection-group-key selection))
    (unless (hash-has-key? groups key)
      (hash-set! groups key '())
      (set! order (append order (list key))))
    (hash-set! groups key (append (hash-ref groups key) (list selection))))
  (for/list ([key (in-list order)])
    (hash-ref groups key)))

(define (summary-specialization-key group callers)
  (define first-selection (car group))
  (cond
    [(ormap selection-site-targeted? group)
     (list 'abi
           (callconv-selection-abi-name first-selection)
           'source-callconv-hints
           (for/list ([selection (in-list group)])
             (list (callconv-selection-caller selection)
                   (callconv-selection-callee selection)
                   (callconv-selection-site-loc selection))))]
    [else
     (or (callconv-selection-specialization-key first-selection)
         (list 'abi
               (callconv-selection-abi-name first-selection)
               'callers
               callers))]))

(define (cfg-replace-function cfg fn)
  (struct-copy control-flow-graph cfg
               [functions
                (intmap-set (control-flow-graph-functions cfg)
                                 (asm-function-id fn)
                                 fn)]
               [fn-names
                (hash-set (control-flow-graph-fn-names cfg)
                                 (asm-function-name fn)
                                 (asm-function-id fn))]))

(define (call-directive-abi-compatible? args selection)
  (define abi-name (call-directive-abi-name args))
  (or (not abi-name)
      (eq? abi-name (callconv-selection-abi-name selection))))

(define (rewrite-callsite-target-ins ins selection new-target)
  (match ins
    [(ast-directive 'call target args loc)
     (if (and (eq? target (callconv-selection-callee selection))
              (equal? loc (callconv-selection-site-loc selection))
              (call-directive-abi-compatible? args selection))
         (ast-directive 'call new-target args loc)
         ins)]
    [_ ins]))

(define (rewrite-callsite-target-block block selection new-target)
  (define instructions
    (for/fold ([out (pvector-empty)])
              ([ins (in-pvector (basic-block-instructions block))])
      (pvector-cons-right out
                          (rewrite-callsite-target-ins ins selection new-target))))
  (struct-copy basic-block block [instructions instructions]))

(define (rewrite-callsite-target-in-function fn selection new-target)
  (define blocks
    (for/fold ([out (asm-function-blocks fn)])
              ([kv (in-intmap-pairs (asm-function-blocks fn))])
      (define block-id (car kv))
      (define block (cdr kv))
      (intmap-set out
                  block-id
                  (rewrite-callsite-target-block block selection new-target))))
  (struct-copy asm-function fn [blocks blocks]))

(define (cfg-rewrite-callsite-target cfg selection new-target)
  (define caller (callconv-selection-caller selection))
  (define caller-fn (cfg-get-function-by-name cfg caller))
  (cfg-replace-function
   cfg
   (rewrite-callsite-target-in-function caller-fn selection new-target)))

(define (clone-with-abi-info clone abi-name original callers)
  (define clone*
    (for/fold ([fn clone])
              ([kv (in-list
                    (list (cons 'abi abi-name)
                          (cons 'ipa-callconv-clone? #t)
                          (cons 'ipa-callconv-origin
                                (asm-function-name original))
                          (cons 'ipa-callconv-callers callers)))])
      (fn-set-info fn (car kv) (cdr kv))))
  (if (fn-public-abi-root? original)
      (for/fold ([fn clone*])
                ([kv (in-list
                      (list (cons 'public-abi-origin? #t)
                            (cons 'public-abi-origin-profile
                                  (fn-public-abi-profile original))
                            (cons 'public-abi-origin-header?
                                  (fn-public-header? original))
                            (cons 'public-abi-origin-visibility
                                  (fn-get-info original 'visibility 'public))))])
        (fn-set-info fn (car kv) (cdr kv)))
      clone*))

(define (apply-selection-group cfg group)
  (define first-selection (car group))
  (define callee (callconv-selection-callee first-selection))
  (define original
    (or (cfg-get-function-by-name cfg callee)
        (error 'apply-callconv-selections "callee function not found: ~a" callee)))
  (define abi-name (callconv-selection-abi-name first-selection))
  (define callers
    (remove-duplicates
     (for/list ([selection (in-list group)])
       (callconv-selection-caller selection))))
  (define specialization-key
    (summary-specialization-key group callers))
  (define-values (cfg+ clone0)
    (cfg-add-function-clone cfg
                            callee
                            #:version-id (callconv-selection-version-id* first-selection)
                            #:version-kind 'callconv
                            #:clone-reason (callconv-selection-clone-reason first-selection)
                            #:specialization-key specialization-key
                            #:linkage-symbol
                            (callconv-selection-linkage-symbol first-selection)))
  (define clone (clone-with-abi-info clone0 abi-name original callers))
  (define cfg++ (cfg-replace-function cfg+ clone))
  (define site-selections
    (filter selection-site-targeted? group))
  (define edge-selections
    (filter (lambda (selection)
              (not (selection-site-targeted? selection)))
            group))
  (define edge-callers
    (remove-duplicates
     (for/list ([selection (in-list edge-selections)])
       (callconv-selection-caller selection))))
  (define cfg+++
    (if (null? edge-callers)
        cfg++
        (cfg-rewrite-call-targets cfg++
                                  callee
                                  (asm-function-name clone)
                                  #:callers edge-callers)))
  (define cfg++++
    (for/fold ([cfg* cfg+++])
              ([selection (in-list site-selections)])
      (cfg-rewrite-callsite-target cfg*
                                   selection
                                   (asm-function-name clone))))
  (values cfg++++
          (callconv-clone-summary callee abi-name clone callers)))

(define (apply-callconv-selections cfg selections)
  (validate-selections! cfg selections)
  (for/fold ([cfg* cfg]
             [summaries '()]
             #:result (values cfg* (reverse summaries)))
            ([group (in-list (group-selections selections))])
    (define-values (cfg** summary)
      (apply-selection-group cfg* group))
    (values cfg** (cons summary summaries))))
