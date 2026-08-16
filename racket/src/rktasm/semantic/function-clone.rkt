#lang racket

;; ============================================================
;; semantic/function-clone.rkt - CFG-level function clone support
;; ============================================================
;;
;; A clone is a new concrete function body/linkage symbol that still belongs
;; to the same source-level logical function. This module keeps the API small:
;; create a clone, optionally rewrite selected callsites to it, and preserve a
;; CFG-level clone group index for later IPA/debug passes.

(require "../parser/ast.rkt"
         "control-flow.rkt"
         racket/pvector
         racket/intmap
         racket/set)

(provide
 cfg-add-function-clone
 cfg-rewrite-call-targets
 cfg-clone-and-rewrite-callers
 cfg-clone-group
 rewrite-call-target-in-function)

(define clone-group-info-key 'function-clone-groups)

(define (target->symbol target who)
  (cond
    [(symbol? target) target]
    [(asm-function? target) (asm-function-name target)]
    [else
     (error who "expected a function symbol or asm-function, got: ~v" target)]))

(define (resolve-function cfg target who)
  (cond
    [(asm-function? target) target]
    [(symbol? target)
     (or (cfg-get-function-by-name cfg target)
         (error who "function not found: ~a" target))]
    [else
     (error who "expected a function symbol or asm-function, got: ~v" target)]))

(define (normalize-callers callers who)
  (cond
    [(not callers) #f]
    [(or (symbol? callers) (asm-function? callers))
     (set (target->symbol callers who))]
    [(set? callers)
     (for/set ([caller (in-set callers)])
       (target->symbol caller who))]
    [(list? callers)
     (for/set ([caller (in-list callers)])
       (target->symbol caller who))]
    [else
     (error who "expected callers to be #f, a symbol, a function, a list, or a set; got: ~v"
            callers)]))

(define (caller-selected? fn caller-set)
  (or (not caller-set)
      (set-member? caller-set (asm-function-name fn))))

(define (append-unique xs x)
  (if (member x xs)
      xs
      (append xs (list x))))

(define (cfg-record-function-clone cfg original clone)
  (define logical-name (fn-logical-name original))
  (define groups (cfg-get-info cfg clone-group-info-key (hash)))
  (define existing (hash-ref groups logical-name '()))
  (define updated
    (append-unique
     (append-unique existing (asm-function-name original))
     (asm-function-name clone)))
  (cfg-set-info cfg clone-group-info-key
                (hash-set groups logical-name updated)))

(define (cfg-clone-group cfg logical-name)
  (hash-ref (cfg-get-info cfg clone-group-info-key (hash))
            logical-name
            '()))

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

(define (rewrite-call-target-ins ins old-target new-target)
  (match ins
    [(ast-ins 'bl suffix (list (ast-label target #f label-loc)) ins-loc)
     (if (eq? target old-target)
         (ast-ins 'bl suffix (list (ast-label new-target #f label-loc)) ins-loc)
         ins)]
    [(ast-directive 'call target bindings loc)
     (if (eq? target old-target)
         (ast-directive 'call new-target bindings loc)
         ins)]
    [_ ins]))

(define (rewrite-call-target-block block old-target new-target)
  (define instructions
    (for/fold ([out (pvector-empty)])
              ([ins (in-pvector (basic-block-instructions block))])
      (pvector-cons-right out
                          (rewrite-call-target-ins ins old-target new-target))))
  (struct-copy basic-block block [instructions instructions]))

(define (rewrite-call-target-in-function fn old-target new-target)
  (define old-symbol (target->symbol old-target 'rewrite-call-target-in-function))
  (define new-symbol (target->symbol new-target 'rewrite-call-target-in-function))
  (define blocks
    (for/fold ([out (asm-function-blocks fn)])
              ([kv (in-intmap-pairs (asm-function-blocks fn))])
      (define block-id (car kv))
      (define block (cdr kv))
      (intmap-set out
                  block-id
                  (rewrite-call-target-block block old-symbol new-symbol))))
  (struct-copy asm-function fn [blocks blocks]))

(define (cfg-rewrite-call-targets cfg old-target new-target
                                  #:callers [callers #f])
  (define old-symbol (target->symbol old-target 'cfg-rewrite-call-targets))
  (define new-symbol (target->symbol new-target 'cfg-rewrite-call-targets))
  (define caller-set (normalize-callers callers 'cfg-rewrite-call-targets))
  (for/fold ([cfg* cfg])
            ([kv (in-intmap-pairs (control-flow-graph-functions cfg))])
    (define fn (cdr kv))
    (if (caller-selected? fn caller-set)
        (cfg-replace-function
         cfg*
         (rewrite-call-target-in-function fn old-symbol new-symbol))
        cfg*)))

(define (cfg-add-function-clone cfg source
                                #:version-id version-id
                                #:version-kind [version-kind 'clone]
                                #:clone-reason [clone-reason 'unspecified]
                                #:specialization-key [specialization-key #f]
                                #:linkage-symbol [linkage-symbol #f])
  (define original (resolve-function cfg source 'cfg-add-function-clone))
  (define clone-with-version
    (if linkage-symbol
        (fn-clone-version original
                          #:version-id version-id
                          #:version-kind version-kind
                          #:clone-reason clone-reason
                          #:specialization-key specialization-key
                          #:linkage-symbol linkage-symbol)
        (fn-clone-version original
                          #:version-id version-id
                          #:version-kind version-kind
                          #:clone-reason clone-reason
                          #:specialization-key specialization-key)))
  (define clone-name (asm-function-name clone-with-version))
  (when (cfg-get-function-by-name cfg clone-name)
    (error 'cfg-add-function-clone "clone linkage symbol already exists: ~a" clone-name))
  (define clone-id (control-flow-graph-next-fn-id cfg))
  (define clone
    (struct-copy asm-function clone-with-version [id clone-id]))
  (define cfg+
    (struct-copy control-flow-graph cfg
                 [functions
                  (intmap-set (control-flow-graph-functions cfg)
                                   clone-id
                                   clone)]
                 [fn-names
                  (hash-set (control-flow-graph-fn-names cfg)
                                   clone-name
                                   clone-id)]
                 [next-fn-id (add1 clone-id)]))
  (values (cfg-record-function-clone cfg+ original clone)
          clone))

(define (all-existing-function-names cfg)
  (for/set ([kv (in-intmap-pairs (control-flow-graph-functions cfg))])
    (asm-function-name (cdr kv))))

(define (cfg-clone-and-rewrite-callers cfg source
                                       #:version-id version-id
                                       #:version-kind [version-kind 'clone]
                                       #:clone-reason [clone-reason 'unspecified]
                                       #:specialization-key [specialization-key #f]
                                       #:linkage-symbol [linkage-symbol #f]
                                       #:callers [callers #f])
  (define original (resolve-function cfg source 'cfg-clone-and-rewrite-callers))
  (define rewrite-callers
    (or (normalize-callers callers 'cfg-clone-and-rewrite-callers)
        (all-existing-function-names cfg)))
  (define-values (cfg+ clone)
    (cfg-add-function-clone cfg
                            original
                            #:version-id version-id
                            #:version-kind version-kind
                            #:clone-reason clone-reason
                            #:specialization-key specialization-key
                            #:linkage-symbol linkage-symbol))
  (values (cfg-rewrite-call-targets cfg+
                                    (asm-function-name original)
                                    (asm-function-name clone)
                                    #:callers rewrite-callers)
          clone))
