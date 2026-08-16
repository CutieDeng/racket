#lang racket

(require rackunit
         rackunit/text-ui
         "../parser/frontend.rkt"
         "../parser/ast.rkt"
         "../semantic/control-flow.rkt"
         "../pipeline/pipeline.rkt"
         "../pipeline/regalloc/abi.rkt"
         "../pipeline/regalloc/types.rkt"
         "../codegen/emit.rkt"
         racket/intmap
         racket/intbits
         racket/pvector)

(define (source->first-function source)
  (define results (parse-string source #:validate? #t))
  (when (parse-results-has-errors? results)
    (error 'source->first-function "parse errors:\n~a"
           (format-parse-errors-report results)))
  (define items
    (for/list ([r (in-list (parse-results-items results))]
               #:when (parse-result-ok? r))
      (parse-result-instruction r)))
  (cfg-get-function (build-cfg items) 0))

(define (allocated-phys-reg result abi reg)
  (define coalesced (alloc-result-coalesced result))
  (define assignment (alloc-result-assignment result))
  (define resolved (reg-om-ref coalesced reg reg))
  (cond
    [(reg-id-physical? resolved) (reg-id-id resolved)]
    [else
     (define color (reg-om-ref assignment resolved #f))
     (and color (abi-color->reg abi (reg-id-class resolved) color))]))

(define regalloc-color-tests
  (test-suite
   "register allocator color mapping"

   (test-case "GNU managed virtual registers compile when ABI is explicit"
     (define results
       (parse-string
        #<<ASM
.asmp.function gnu_vreg abi=aapcs64
gnu_vreg:
  mov x.tmp, x0
  add x0, x.tmp, #1
  ret
.asmp.end_function
ASM
        #:syntax 'gnu
        #:validate? #t))
     (check-equal? (parse-results-error-count results) 0)
     (define items
       (for/list ([r (in-list (parse-results-items results))]
                  #:when (parse-result-ok? r))
         (parse-result-instruction r)))
     (define fn (cfg-get-function (build-cfg items) 0))
     (define result (run-pipeline fn default-pipeline-config))
     (check-equal? (pipeline-result-errors result) '())
     (check-not-false
      (regexp-match? #rx"add x0, x[0-9]+, #1"
                     (emit-function/result result))))

   (test-case "precolored physical registers use ABI colors, not raw register numbers"
     (define fn
       (source->first-function
        #<<ASM
(: function precolor_conflict (abi aapcs64))
(: label entry)
(: save! all)
  (mov x.v x0)
  (add x.t0 x.v x0)
  (add x.t1 x.v x1)
  (add x.t2 x.v x2)
  (add x.t3 x.v x3)
  (add x.t4 x.v x4)
  (add x.t5 x.v x5)
  (add x.t6 x.v x6)
  (add x.t7 x.v x7)
  (add x.t8 x.v x8)
  (add x.t9 x.v x9)
  (add x.t10 x.v x10)
  (add x.t11 x.v x11)
  (add x.t12 x.v x12)
  (add x.t13 x.v x13)
  (add x.t14 x.v x14)
  (add x.t15 x.v x15)
  (add x.t16 x.v x16)
  (add x.t17 x.v x17)
  (add x.t19 x.v x19)
  (mov x0 x.v)
(: load! all)
  (ret)
(: end-function)
ASM
        ))
     (define result (run-pipeline fn (make-pipeline-config #:abi arm64-abi)))
     (check-equal? (pipeline-result-errors result) '())
     (define assignment (alloc-result-assignment (pipeline-result-allocation result)))
     (define color (reg-om-ref assignment (make-virtual-gpr 'v) #f))
     (check-not-false color)
     (define effective-abi
       (multi-class-ig-effective-abi (pipeline-result-interference result)))
     (check-not-equal? (abi-color->reg effective-abi 'gpr color) 19))

   (test-case "reserved rewrite scratch registers do not capture virtual coalesces"
     (define fn
       (source->first-function
        #<<ASM
(: function reserved_scratch_coalesce (abi aapcs64))
(: label entry)
  (mov x.v x16)
  (add x.use x.v x0)
  (mov x0 x.use)
  (ret)
(: end-function)
ASM
        ))
     (define result (run-pipeline fn (make-pipeline-config #:abi arm64-abi)))
     (check-equal? (pipeline-result-errors result) '())
     (define allocation (pipeline-result-allocation result))
     (define effective-abi
       (multi-class-ig-effective-abi (pipeline-result-interference result)))
     (define v-phys (allocated-phys-reg allocation effective-abi (make-virtual-gpr 'v)))
     (check-not-false v-phys)
     (check-not-equal? v-phys 16)
     (check-not-equal? v-phys 17))

   (test-case "coalescing with precolored aliases respects virtual interference"
     (define fn
       (source->first-function
        #<<ASM
(: function precolored_alias_conflict (abi aapcs64))
(: label entry)
  (mov x.a x4)
  (add x.b x5 x1)
  (add x.use x.a x.b)
  (mov x4 x.b)
  (mov x0 x.use)
  (ret)
(: end-function)
ASM
        ))
     (define result (run-pipeline fn (make-pipeline-config #:abi arm64-abi)))
     (check-equal? (pipeline-result-errors result) '())
     (define allocation (pipeline-result-allocation result))
     (define effective-abi
       (multi-class-ig-effective-abi (pipeline-result-interference result)))
     (define a-phys (allocated-phys-reg allocation effective-abi (make-virtual-gpr 'a)))
     (define b-phys (allocated-phys-reg allocation effective-abi (make-virtual-gpr 'b)))
     (check-not-false a-phys)
     (check-not-false b-phys)
     (check-not-equal? a-phys b-phys))

   (test-case "coalesced virtual alias keeps merged interference neighbors"
     (define fn
       (source->first-function
        #<<ASM
(: function coalesced_alias_neighbor (abi aapcs64))
(: label entry)
  (mov x.arg x0)
  (add x.base x1 x2)
  (mov x.scratch x3)
  (mov x.read x.arg)
  (add x.scratch x.scratch x.read)
  (mov x.cursor x.base)
  (add x0 x.cursor x.scratch)
  (ret)
(: end-function)
ASM
        ))
     (define result (run-pipeline fn (make-pipeline-config #:abi arm64-abi)))
     (check-equal? (pipeline-result-errors result) '())
     (define allocation (pipeline-result-allocation result))
     (define effective-abi
       (multi-class-ig-effective-abi (pipeline-result-interference result)))
     (define arg-phys (allocated-phys-reg allocation effective-abi (make-virtual-gpr 'arg)))
     (define base-phys (allocated-phys-reg allocation effective-abi (make-virtual-gpr 'base)))
     (check-not-false arg-phys)
     (check-not-false base-phys)
     (check-not-equal? arg-phys base-phys))

   (test-case "coalesced live-across-call aliases keep callee-saved colors"
     (define fn
       (source->first-function
        #<<ASM
(: function coalesced_live_across_call (abi aapcs64))
(: label entry)
(: save! all)
  (mov x29 sp)
  (mov x.src x0)
  (bl callee)
  (mov x.out x.src)
  (add x0 x.out 1)
(: load! all)
  (ret)
(: label callee)
  (ret)
(: end-function)
ASM
        ))
     (define result (run-pipeline fn (make-pipeline-config #:abi arm64-abi)))
     (check-equal? (pipeline-result-errors result) '())
     (define allocation (pipeline-result-allocation result))
     (define effective-abi
       (multi-class-ig-effective-abi (pipeline-result-interference result)))
     (define src-phys (allocated-phys-reg allocation effective-abi (make-virtual-gpr 'src)))
     (check-not-false src-phys)
     (check-true (intbits-ref (reg-callee-saved (abi-config-gpr effective-abi))
                                 src-phys)))

   (test-case "save all filters allocation colors by register class"
     (define fn
       (source->first-function
        #<<ASM
(: function save_all_class_filter (abi aapcs64))
(: label entry)
(: save! all)
  (mov x.v x0)
(: load! all)
  (ret)
(: end-function)
ASM
        ))
     (define gpr-x8-color (abi-reg->color arm64-abi 'gpr 8))
     (check-not-false gpr-x8-color)
     (define fake-allocation
       (alloc-result
        (reg-om-set reg-om-empty
                         (make-virtual-gpr 'v)
                         gpr-x8-color)
        (pvector-empty)
        reg-om-empty))
     (define context (analyze-save-load fn fake-allocation #:abi arm64-abi))
     (define all-expansion (save-load-context-all-expansion context))
     (check-false (hash-ref all-expansion (cons 'fpr 8) #f))
     (check-true (hash-ref all-expansion (cons 'gpr 29) #f))
     (check-true (hash-ref all-expansion (cons 'gpr 30) #f)))

   (test-case "frame pointer setup reserves x29 from virtual allocation"
     (define fn
       (source->first-function
        #<<ASM
(: function frame_pointer_reserves_x29 (abi aapcs64))
(: label entry)
(: save! all)
  (mov x29 sp)
  (mov x.a x0)
  (add x.b x.a x1)
  (add x.c x.b x2)
  (add x.d x.c x3)
  (mov x0 x.d)
(: load! all)
  (ret)
(: end-function)
ASM
        ))
     (define result (run-pipeline fn (make-pipeline-config #:abi arm64-abi)))
     (check-equal? (pipeline-result-errors result) '())
     (define effective-abi
       (multi-class-ig-effective-abi (pipeline-result-interference result)))
     (check-true (reg-banned? (abi-config-gpr effective-abi) 29))
     (define allocation (pipeline-result-allocation result))
     (for ([kv (in-reg-om (alloc-result-assignment allocation))])
       (define rid (car kv))
       (define color (cdr kv))
       (when (eq? (reg-id-class rid) 'gpr)
         (check-not-equal? (abi-color->reg effective-abi 'gpr color) 29))))

   (test-case "link register x30 is not used for live-across-call values"
     (define fn
       (source->first-function
        #<<ASM
(: function link_register_not_live_across_call (abi aapcs64))
(: label entry)
(: save! all)
  (mov x.live x0)
  (bl helper)
  (add x.result x.live x1)
  (mov x0 x.result)
(: load! all)
  (ret)
(: end-function)
ASM
        ))
     (define result (run-pipeline fn (make-pipeline-config #:abi arm64-abi)))
     (check-equal? (pipeline-result-errors result) '())
     (define effective-abi
       (multi-class-ig-effective-abi (pipeline-result-interference result)))
     (check-false (reg-preserved? (abi-config-gpr effective-abi) 30))
     (define allocation (pipeline-result-allocation result))
     (define live-color
       (reg-om-ref (alloc-result-assignment allocation)
                        (make-virtual-gpr 'live)
                        #f))
     (check-not-false live-color)
     (check-not-equal? (abi-color->reg effective-abi 'gpr live-color) 30))

   (test-case "explicit physical interference prevents precolored coalescing"
     (define fn0
       (source->first-function
        #<<ASM
(: function explicit_physical_interference (abi aapcs64))
(: label entry)
(: save! all)
  (mov x.v x0)
  (bl callee)
  (add x0 x.v x0)
(: load! all)
  (ret)
(: label callee)
  (ret)
(: end-function)
ASM
        ))
     (define entry (fn-entry-block fn0))
     (define constraint
       (ast-directive
        'reg-interfere
        #f
        (list (ast-reg 'x 'v #f #f #f #f no-srcloc)
              (ast-reg 'x 19 #f #f #f #f no-srcloc))
        no-srcloc))
     (define entry* (struct-copy basic-block entry
                                  [instructions
                                   (pvector-cons-left
                                    (basic-block-instructions entry)
                                    constraint)]))
     (define fn
       (struct-copy asm-function fn0
                    [blocks (intmap-set (asm-function-blocks fn0)
                                             (bb-id-val (basic-block-id entry))
                                             entry*)]))
     (define result (run-pipeline fn (make-pipeline-config #:abi arm64-abi)))
     (check-equal? (pipeline-result-errors result) '())
     (define allocation (pipeline-result-allocation result))
     (define effective-abi
       (multi-class-ig-effective-abi (pipeline-result-interference result)))
     (define v-phys (allocated-phys-reg allocation effective-abi (make-virtual-gpr 'v)))
     (check-not-false v-phys)
     (check-not-equal? v-phys 19))))

(module+ main
  (void (run-tests regalloc-color-tests)))

(module+ test
  (void (run-tests regalloc-color-tests)))
