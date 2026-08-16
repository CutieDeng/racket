#lang racket

(require rackunit
         rackunit/text-ui
         "../parser/frontend.rkt"
         "../parser/ast.rkt"
         "../semantic/control-flow.rkt"
         "../semantic/function-clone.rkt"
         "../semantic/inline.rkt")

(define (ok-items results)
  (for/list ([r (in-list (parse-results-items results))]
             #:when (parse-result-ok? r))
    (parse-result-instruction r)))

(define (cfg-from-sexp source)
  (define results (parse-string source #:syntax 'sexp #:validate? #t))
  (check-equal? (parse-results-error-count results) 0)
  (build-cfg (ok-items results)))

(define (cfg-from-gnu source)
  (define results (parse-string source #:syntax 'gnu #:validate? #t))
  (check-equal? (parse-results-error-count results) 0)
  (build-cfg (ok-items results)))

(define function-identity-tests
  (test-suite
   "function identity metadata"

   (test-case "source functions receive canonical version identity"
     (define cfg
       (cfg-from-sexp
        #<<SRC
(: function foo)
(: label entry)
  (ret)
(: end-function)
SRC
        ))
     (define fn (cfg-get-function-by-name cfg 'foo))
     (check-not-false fn)
     (define v (fn-function-version fn))
     (check-true (function-version-canonical? v))
     (check-equal? (function-version-logical-name v) 'foo)
     (check-equal? (function-version-version-id v) 'canonical)
     (check-equal? (function-version-linkage-symbol v) 'foo)
     (check-equal? (fn-logical-name fn) 'foo)
     (check-equal? (fn-linkage-symbol fn) 'foo)
     (check-equal? (fn-debug-display-name fn) "foo"))

   (test-case "clone version keeps logical identity and changes linkage symbol"
     (define cfg
       (cfg-from-sexp
        #<<SRC
(: function crypto.deflate.main)
(: label entry)
  (ret)
(: end-function)
SRC
        ))
     (define fn (cfg-get-function-by-name cfg 'crypto.deflate.main))
     (define clone
       (fn-clone-version fn
                         #:version-id 'cc1
                         #:version-kind 'callconv
                         #:clone-reason 'managed-callconv
                         #:specialization-key '(caller app.main)))
     (define v (fn-function-version clone))
     (check-false (function-version-canonical? v))
     (check-true (function-version-clone? v))
     (check-equal? (asm-function-name clone) 'crypto.deflate.main$asmp.cc1)
     (check-equal? (function-version-linkage-symbol v) 'crypto.deflate.main$asmp.cc1)
     (check-equal? (function-version-logical-name v) 'crypto.deflate.main)
     (check-equal? (function-version-origin-version-id v) 'canonical)
     (check-equal? (function-version-version-kind v) 'callconv)
     (check-equal? (function-version-clone-reason v) 'managed-callconv)
     (check-equal? (function-version-specialization-key v) '(caller app.main))
     (check-equal? (fn-debug-display-name clone)
                   "crypto.deflate.main [clone cc1, reason=managed-callconv]"))

   (test-case "function identity survives inline CFG roundtrip"
     (define cfg
       (expand-inline-cfg
        (cfg-from-gnu
         #<<ASM
.function helper (inout: x.value)
entry:
  add x.value, x.value, #1
  ret
.end

.function app.main export ()
entry:
  mov x10, #41
  .inline helper (x.value=x10)
  ret
.end
ASM
         )))
     (define helper (cfg-get-function-by-name cfg 'helper))
     (define main-fn (cfg-get-function-by-name cfg 'app.main))
     (check-not-false helper)
     (check-not-false main-fn)
     (check-equal? (fn-logical-name helper) 'helper)
     (check-equal? (function-version-version-id (fn-function-version helper))
                   'canonical)
     (check-equal? (fn-logical-name main-fn) 'app.main)
     (check-true (fn-get-info main-fn 'export #f)))

   (test-case "source variant keeps handwritten body under logical function"
     (define cfg
       (cfg-from-gnu
        #<<ASM
.function asmp.deflate.fixed ()
entry:
  ret
.end

.function asmp.deflate.fixed.neon-extend variant-of=asmp.deflate.fixed version=neon-extend feature=neon ()
entry:
  ret
.end
ASM
        ))
     (define scalar (cfg-get-function-by-name cfg 'asmp.deflate.fixed))
     (define neon (cfg-get-function-by-name cfg 'asmp.deflate.fixed.neon-extend))
     (check-not-false scalar)
     (check-not-false neon)
     (check-equal? (fn-logical-name scalar) 'asmp.deflate.fixed)
     (check-equal? (fn-logical-name neon) 'asmp.deflate.fixed)
     (define version (fn-function-version neon))
     (check-false (function-version-canonical? version))
     (check-true (function-version-clone? version))
     (check-equal? (function-version-version-id version) 'neon-extend)
     (check-equal? (function-version-version-kind version) 'source-variant)
     (check-equal? (function-version-clone-reason version) 'handwritten)
     (check-equal? (function-version-specialization-key version)
                   '(target-feature neon))
     (check-equal? (function-version-linkage-symbol version)
                   'asmp.deflate.fixed.neon-extend)
     (check-equal? (cfg-clone-group cfg 'asmp.deflate.fixed)
                   '(asmp.deflate.fixed asmp.deflate.fixed.neon-extend)))))

(module+ main
  (void (run-tests function-identity-tests)))

(module+ test
  (void (run-tests function-identity-tests)))
