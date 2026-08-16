#lang racket

(require rackunit
         rackunit/text-ui
         "../parser/frontend.rkt"
         "../parser/ast.rkt"
         "../semantic/control-flow.rkt"
         "../semantic/inline.rkt"
         "../semantic/function-clone.rkt"
         "../semantic/ipa-callconv.rkt"
         "../pipeline/regalloc/abi-config.rkt"
         racket/pvector
         racket/intmap
         (prefix-in cli: "../cli/as.rkt"))

(define (ok-items results)
  (for/list ([r (in-list (parse-results-items results))]
             #:when (parse-result-ok? r))
    (parse-result-instruction r)))

(define (cfg-from-gnu source)
  (define results (parse-string source #:syntax 'gnu #:validate? #t))
  (check-equal? (parse-results-error-count results) 0)
  (build-cfg (ok-items results) 'ipa-callconv-test))

(define callconv-source
  #<<ASM
.function math.inc (
  inout: x.value
)
entry:
  add x.value, x.value, #1
  ret
.end

.function app.a export ()
entry:
  mov x20, #41
  .call math.inc (
    x.value=x20
  )
  ret
.end

.function app.b export ()
entry:
  mov x21, #7
  .call math.inc (
    x.value=x21
  )
  ret
.end
ASM
  )

(define (write-test-abi-config path)
  (call-with-output-file path
    (lambda (out)
      (displayln "(fast9" out)
      (displayln "  (gpr (num-regs 31) (banned #x0) (preserved #x0) (args 9 10) (return 9))" out)
      (displayln "  (fpr (num-regs 32) (banned #x0) (preserved #x0) (args 8 9) (return 8))" out)
      (displayln "  (pred (num-regs 16) (banned #x0) (preserved #x0) (args 4 5) (return 4)))" out)
      (displayln "" out)
      (displayln "(fast10" out)
      (displayln "  (gpr (num-regs 31) (banned #x0) (preserved #x0) (args 10 11) (return 10))" out)
      (displayln "  (fpr (num-regs 32) (banned #x0) (preserved #x0) (args 10 11) (return 10))" out)
      (displayln "  (pred (num-regs 16) (banned #x0) (preserved #x0) (args 6 7) (return 6)))" out)
      (displayln "" out)
      (displayln "(fast20" out)
      (displayln "  (gpr (num-regs 31) (banned #x0) (preserved #x0) (args 20 22) (return 20))" out)
      (displayln "  (fpr (num-regs 32) (banned #x0) (preserved #x0) (args 20 21) (return 20))" out)
      (displayln "  (pred (num-regs 16) (banned #x0) (preserved #x0) (args 8 9) (return 8)))" out)
      (displayln "" out)
      (displayln "(fast21" out)
      (displayln "  (gpr (num-regs 31) (banned #x0) (preserved #x0) (args 21 23) (return 21))" out)
      (displayln "  (fpr (num-regs 32) (banned #x0) (preserved #x0) (args 22 23) (return 22))" out)
      (displayln "  (pred (num-regs 16) (banned #x0) (preserved #x0) (args 10 11) (return 10)))" out))
    #:exists 'truncate/replace))

(define (call-with-test-abis thunk)
  (define tmp (make-temporary-file "asmp-ipa-abi-~a.rktd"))
  (write-test-abi-config tmp)
  (dynamic-wind
    void
    (lambda ()
      (parameterize ([abi-config-path tmp])
        (reload-abi-config #:force? #t)
        (thunk)))
    (lambda ()
      (when (file-exists? tmp)
        (delete-file tmp)))))

(define (function-call-targets fn)
  (apply append
         (for/list ([kv (in-intmap-pairs (asm-function-blocks fn))])
           (define block (cdr kv))
           (for/list ([ins (in-pvector (basic-block-instructions block))]
                      #:when
                      (match ins
                        [(ast-directive 'call _ _ _) #t]
                        [(ast-ins 'bl _ (list (ast-label _ #f _)) _) #t]
                        [_ #f]))
             (match ins
               [(ast-directive 'call target _ _) target]
               [(ast-ins 'bl _ (list (ast-label target #f _)) _) target])))))

(define (function-instructions fn)
  (apply append
         (for/list ([kv (in-intmap-pairs (asm-function-blocks fn))])
           (define block (cdr kv))
           (for/list ([ins (in-pvector (basic-block-instructions block))]
                      #:when (ast-ins? ins))
             ins))))

(define (has-mov? fn dst-kind dst-id src-kind src-id)
  (for/or ([ins (in-list (function-instructions fn))])
    (match ins
      [(ast-ins 'mov _
                (list (ast-reg (? (lambda (k) (eq? k dst-kind))) dst-id* _ _ _ _ _)
                      (ast-reg (? (lambda (k) (eq? k src-kind))) src-id* _ _ _ _ _))
                _)
       (and (equal? dst-id* dst-id)
            (equal? src-id* src-id))]
      [_ #f])))

(define ipa-callconv-tests
  (test-suite
   "IPA callconv clone selector"

   (test-case "collect-managed-call-edges finds .call edges before lowering"
     (define cfg (cfg-from-gnu callconv-source))
     (check-equal?
      (map (lambda (edge)
             (list (managed-call-edge-caller edge)
                   (managed-call-edge-callee edge)))
           (collect-managed-call-edges cfg))
      '((app.a math.inc) (app.b math.inc))))

   (test-case "source .call abi hint becomes an explicit selection"
     (define cfg
       (cfg-from-gnu
        #<<ASM
.function math.inc (
  inout: x.value
)
entry:
  add x.value, x.value, #1
  ret
.end

.function app.main export ()
entry:
  mov x20, #41
  .call math.inc abi=fast20 (
    x.value=x20
  )
  ret
.end
ASM
        ))
     (define selections (collect-callconv-hint-selections cfg))
     (check-equal? (length selections) 1)
     (define selection (car selections))
     (check-equal? (callconv-selection-caller selection) 'app.main)
     (check-equal? (callconv-selection-callee selection) 'math.inc)
     (check-equal? (callconv-selection-abi-name selection) 'fast20)
     (check-equal? (callconv-selection-clone-reason selection)
                   'user-callconv-hint)
     (check-true (srcloc? (callconv-selection-site-loc selection))))

   (test-case "source .call abi hints are applied per callsite"
     (call-with-test-abis
      (lambda ()
        (define cfg
          (cfg-from-gnu
           #<<ASM
.function math.inc (
  inout: x.value
)
entry:
  add x.value, x.value, #1
  ret
.end

.function app.main export ()
entry:
  mov x20, #41
  .call math.inc abi=fast20 (
    x.value=x20
  )
  mov x21, #7
  .call math.inc abi=fast21 (
    x.value=x21
  )
  ret
.end
ASM
           ))
        (define selections (collect-callconv-hint-selections cfg))
        (check-equal? (map callconv-selection-abi-name selections)
                      '(fast20 fast21))
        (define-values (cfg* summaries)
          (apply-callconv-selections cfg selections))
        (check-equal? (map (lambda (summary)
                             (asm-function-name
                              (callconv-clone-summary-clone summary)))
                           summaries)
                      '(math.inc$asmp.cc.fast20
                        math.inc$asmp.cc.fast21))
        (define expanded (expand-inline-cfg cfg*))
        (define app-main (cfg-get-function-by-name expanded 'app.main))
        (check-equal? (function-call-targets app-main)
                      '(math.inc$asmp.cc.fast20
                        math.inc$asmp.cc.fast21))
        (check-false (has-mov? app-main 'x 20 'x 20))
        (check-false (has-mov? app-main 'x 21 'x 21)))))

   (test-case "apply-callconv-selections clones callee and rewrites selected callers"
     (call-with-test-abis
      (lambda ()
        (define cfg (cfg-from-gnu callconv-source))
        (define-values (cfg* summaries)
          (apply-callconv-selections
           cfg
           (list
            (make-callconv-selection #:caller 'app.a
                                     #:callee 'math.inc
                                     #:abi 'fast9)
            (make-callconv-selection #:caller 'app.b
                                     #:callee 'math.inc
                                     #:abi 'fast9))))
        (check-equal? (length summaries) 1)
        (define summary (car summaries))
        (define clone (callconv-clone-summary-clone summary))
        (check-equal? (callconv-clone-summary-callee summary) 'math.inc)
        (check-equal? (callconv-clone-summary-abi-name summary) 'fast9)
        (check-equal? (callconv-clone-summary-callers summary)
                      '(app.a app.b))
        (check-equal? (asm-function-name clone) 'math.inc$asmp.cc.fast9)
        (check-equal? (fn-get-info clone 'abi #f) 'fast9)
        (check-true (fn-get-info clone 'ipa-callconv-clone? #f))
        (check-equal? (function-version-version-kind (fn-function-version clone))
                      'callconv)
        (check-equal? (function-version-specialization-key
                       (fn-function-version clone))
                      '(abi fast9 callers (app.a app.b)))
        (check-equal? (function-call-targets (cfg-get-function-by-name cfg* 'app.a))
                      '(math.inc$asmp.cc.fast9))
        (check-equal? (function-call-targets (cfg-get-function-by-name cfg* 'app.b))
                      '(math.inc$asmp.cc.fast9))
        (check-equal? (cfg-clone-group cfg* 'math.inc)
                      '(math.inc math.inc$asmp.cc.fast9)))))

   (test-case "public ABI roots stay stable when IPA creates private clones"
     (call-with-test-abis
      (lambda ()
        (define cfg
          (cfg-from-gnu
           #<<ASM
.function api.inc export profile=c-aapcs64 (
  inout: x.value
)
entry:
  add x.value, x.value, #1
  ret
.end

.function app.worker ()
entry:
  mov x20, #41
  .call api.inc (
    x.value=x20
  )
  ret
.end
ASM
           ))
        (define-values (cfg* summaries)
          (apply-callconv-selections
           cfg
           (list
            (make-callconv-selection #:caller 'app.worker
                                     #:callee 'api.inc
                                     #:abi 'fast20))))
        (check-equal? (length summaries) 1)
        (define original (cfg-get-function-by-name cfg* 'api.inc))
        (define clone
          (cfg-get-function-by-name cfg* 'api.inc$asmp.cc.fast20))
        (define worker (cfg-get-function-by-name cfg* 'app.worker))
        (check-not-false original)
        (check-not-false clone)
        (check-true (fn-get-info original 'export #f))
        (check-true (fn-public-abi-root? original))
        (check-equal? (fn-public-abi-profile original) 'c-aapcs64)
        (check-false (fn-get-info original 'abi #f))
        (check-false (fn-get-info clone 'export #f))
        (check-false (fn-public-abi-root? clone))
        (check-false (fn-public-abi-profile clone))
        (check-equal? (fn-get-info clone 'abi #f) 'fast20)
        (check-true (fn-get-info clone 'ipa-callconv-clone? #f))
        (check-equal? (fn-get-info clone 'ipa-callconv-origin #f) 'api.inc)
        (check-equal? (fn-get-info clone 'ipa-callconv-callers #f)
                      '(app.worker))
        (check-true (fn-get-info clone 'public-abi-origin? #f))
        (check-equal? (fn-get-info clone 'public-abi-origin-profile #f)
                      'c-aapcs64)
        (check-equal? (function-call-targets worker)
                      '(api.inc$asmp.cc.fast20)))))

   (test-case "planner treats header-visible public roots as ABI barriers"
     (call-with-test-abis
      (lambda ()
        (define cfg
          (cfg-from-gnu
           #<<ASM
.function api.inc export profile=c-aapcs64 (
  inout: x.value
)
entry:
  add x.value, x.value, #1
  ret
.end

.function app.worker ()
entry:
  mov x20, #41
  .call api.inc (
    x.value=x20
  )
  ret
.end
ASM
           ))
        (define api (cfg-get-function-by-name cfg 'api.inc))
        (check-true (fn-public-abi-barrier? api))
        (define-values (selections reports)
          (plan-callconv-selections cfg
                                    #:candidate-abis '(fast20)))
        (check-equal? selections '())
        (check-equal? reports '()))))

   (test-case "planner can optimize hidden no-header public roots"
     (call-with-test-abis
      (lambda ()
        (define cfg
          (cfg-from-gnu
           #<<ASM
.function raw.inc export profile=c-aapcs64 visibility=hidden no-header (
  inout: x.value
)
entry:
  add x.value, x.value, #1
  ret
.end

.function app.worker ()
entry:
  mov x20, #41
  .call raw.inc (
    x.value=x20
  )
  ret
.end
ASM
           ))
        (define raw (cfg-get-function-by-name cfg 'raw.inc))
        (check-true (fn-public-abi-root? raw))
        (check-false (fn-public-header? raw))
        (check-false (fn-public-abi-barrier? raw))
        (define-values (selections reports)
          (plan-callconv-selections cfg
                                    #:candidate-abis '(fast20)))
        (check-equal? (map callconv-selection-abi-name selections)
                      '(fast20))
        (check-equal? (map callconv-selection-report-selected-abi reports)
                      '(fast20))
        (define-values (cfg* summaries)
          (apply-callconv-selections cfg selections))
        (check-equal? (length summaries) 1)
        (define clone
          (cfg-get-function-by-name cfg* 'raw.inc$asmp.cc.fast20))
        (define worker (cfg-get-function-by-name cfg* 'app.worker))
        (check-not-false clone)
        (check-false (fn-get-info clone 'export #f))
        (check-false (fn-public-abi-root? clone))
        (check-true (fn-get-info clone 'public-abi-origin? #f))
        (check-equal? (fn-get-info clone 'public-abi-origin-profile #f)
                      'c-aapcs64)
        (check-false (fn-get-info clone 'public-abi-origin-header? #t))
        (check-equal? (fn-get-info clone 'public-abi-origin-visibility #f)
                      'hidden)
        (check-equal? (function-call-targets worker)
                      '(raw.inc$asmp.cc.fast20)))))

   (test-case "selected clone ABI is used by later .call lowering"
     (call-with-test-abis
      (lambda ()
        (define cfg (cfg-from-gnu callconv-source))
        (define-values (cfg* _summaries)
          (apply-callconv-selections
           cfg
           (list
            (make-callconv-selection #:caller 'app.a
                                     #:callee 'math.inc
                                     #:abi 'fast9))))
        (define expanded (expand-inline-cfg cfg*))
        (define app-a (cfg-get-function-by-name expanded 'app.a))
        (define app-b (cfg-get-function-by-name expanded 'app.b))
        (check-equal? (function-call-targets app-a)
                      '(math.inc$asmp.cc.fast9))
        (check-equal? (function-call-targets app-b)
                      '(math.inc))
        (check-true (has-mov? app-a 'x 9 'x 20))
        (check-true (has-mov? app-a 'x 20 'x 9))
        (check-false (has-mov? app-b 'x 9 'x 21)))))

   (test-case "planner selects lower move-cost ABI candidates"
     (call-with-test-abis
      (lambda ()
        (define cfg (cfg-from-gnu callconv-source))
        (define-values (selections reports)
          (plan-callconv-selections cfg
                                    #:candidate-abis '(fast9 fast20 fast21)))
        (check-equal? (map callconv-selection-abi-name selections)
                      '(fast20 fast21))
        (check-equal? (map callconv-selection-report-selected-abi reports)
                      '(fast20 fast21))
        (check-equal? (map callconv-selection-report-baseline-cost reports)
                      '(2 2))
        (check-equal? (map callconv-selection-report-selected-cost reports)
                      '(0 0))
        (check-equal? (map callconv-selection-report-savings reports)
                      '(2 2))
        (define-values (cfg* summaries)
          (apply-callconv-selections cfg selections))
        (check-equal? (map (lambda (summary)
                             (asm-function-name
                              (callconv-clone-summary-clone summary)))
                           summaries)
                      '(math.inc$asmp.cc.fast20
                        math.inc$asmp.cc.fast21))
        (define expanded (expand-inline-cfg cfg*))
        (define app-a (cfg-get-function-by-name expanded 'app.a))
        (define app-b (cfg-get-function-by-name expanded 'app.b))
        (check-equal? (function-call-targets app-a)
                      '(math.inc$asmp.cc.fast20))
        (check-equal? (function-call-targets app-b)
                      '(math.inc$asmp.cc.fast21))
        (check-false (has-mov? app-a 'x 20 'x 20))
        (check-false (has-mov? app-b 'x 21 'x 21)))))

   (test-case "CLI regalloc stage can run IPA callconv planner before lowering"
     (call-with-test-abis
      (lambda ()
        (define path (make-temporary-file "asmp-ipa-cli-~a.asm"))
        (call-with-output-file path
          (lambda (out)
            (display #<<ASM
.function math.inc (
  inout: x.value
)
entry:
  add x.value, x.value, #1
  ret
.end

.function app.main export ()
entry:
  mov x20, #41
  .call math.inc (
    x.value=x20
  )
  ret
.end
ASM
                     out))
          #:exists 'truncate/replace)
        (parameterize ([cli:input-syntax 'gnu]
                       [cli:ipa-callconv-candidate-abis '(fast20)]
                       [cli:ipa-callconv-min-savings 1]
                       [cli:ipa-callconv-report #f]
                       [default-abi-name #f])
          (define parse-result (cli:run-parse-stage path))
          (check-equal? (pvector-length (cli:parse-stage-result-errors parse-result)) 0)
          (define cfg-result
            (cli:run-cfg-stage (cli:parse-stage-result-items parse-result) path))
          (check-equal? (pvector-length (cli:cfg-stage-result-errors cfg-result)) 0)
          (define regalloc-result
            (cli:run-regalloc-stage (cli:cfg-stage-result-cfg cfg-result)
                                    (cli:cfg-stage-result-functions cfg-result)))
          (check-equal? (pvector-length (cli:regalloc-stage-result-errors regalloc-result)) 0)
          (define app-fn
            (for/first ([fn (in-list (cli:regalloc-stage-result-functions regalloc-result))]
                        #:when (eq? (asm-function-name fn) 'app.main))
              fn))
          (check-not-false app-fn)
          (check-equal? (function-call-targets app-fn)
                        '(math.inc$asmp.cc.fast20))
          (check-not-false
           (for/first ([fn (in-list (cli:regalloc-stage-result-functions regalloc-result))]
                       #:when (eq? (asm-function-name fn) 'math.inc$asmp.cc.fast20))
             fn)))
        (delete-file path))))

   (test-case "CLI applies source .call abi hint without candidate list"
     (call-with-test-abis
      (lambda ()
        (define path (make-temporary-file "asmp-ipa-source-hint-~a.asm"))
        (call-with-output-file path
          (lambda (out)
            (display #<<ASM
.function math.inc (
  inout: x.value
)
entry:
  add x.value, x.value, #1
  ret
.end

.function app.main export ()
entry:
  mov x20, #41
  .call math.inc abi=fast20 (
    x.value=x20
  )
  ret
.end
ASM
                     out))
          #:exists 'truncate/replace)
        (parameterize ([cli:input-syntax 'gnu]
                       [cli:ipa-callconv-candidate-abis '()]
                       [cli:ipa-callconv-report #f]
                       [default-abi-name #f])
          (define parse-result (cli:run-parse-stage path))
          (check-equal? (pvector-length (cli:parse-stage-result-errors parse-result)) 0)
          (define cfg-result
            (cli:run-cfg-stage (cli:parse-stage-result-items parse-result) path))
          (check-equal? (pvector-length (cli:cfg-stage-result-errors cfg-result)) 0)
          (define regalloc-result
            (cli:run-regalloc-stage (cli:cfg-stage-result-cfg cfg-result)
                                    (cli:cfg-stage-result-functions cfg-result)))
          (check-equal? (pvector-length (cli:regalloc-stage-result-errors regalloc-result)) 0)
          (define app-fn
            (for/first ([fn (in-list (cli:regalloc-stage-result-functions regalloc-result))]
                        #:when (eq? (asm-function-name fn) 'app.main))
              fn))
          (check-not-false app-fn)
          (check-equal? (function-call-targets app-fn)
                        '(math.inc$asmp.cc.fast20)))
        (delete-file path))))

   (test-case "conflicting selections for one edge are rejected"
     (call-with-test-abis
      (lambda ()
        (define cfg (cfg-from-gnu callconv-source))
        (check-exn
         #rx"conflicting callconv selections"
         (lambda ()
           (apply-callconv-selections
            cfg
            (list
             (make-callconv-selection #:caller 'app.a
                                      #:callee 'math.inc
                                      #:abi 'fast9)
             (make-callconv-selection #:caller 'app.a
                                      #:callee 'math.inc
                                      #:abi 'fast10))))))))

   (test-case "selection must target an existing managed .call edge"
     (call-with-test-abis
      (lambda ()
        (define cfg (cfg-from-gnu callconv-source))
        (check-exn
         #rx"no managed \\.call edge"
         (lambda ()
           (apply-callconv-selections
            cfg
            (list
             (make-callconv-selection #:caller 'app.a
                                      #:callee 'app.b
                                      #:abi 'fast9))))))))))

(module+ main
  (void (run-tests ipa-callconv-tests)))

(module+ test
  (void (run-tests ipa-callconv-tests)))
