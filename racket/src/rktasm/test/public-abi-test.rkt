#lang racket

(require rackunit
         rackunit/text-ui
         racket/runtime-path
         "../parser/frontend.rkt"
         "../semantic/control-flow.rkt"
         "../semantic/public-abi.rkt"
         "../codegen/emit.rkt"
         racket/pvector
         (prefix-in cli: "../cli/as.rkt"))

(define-runtime-path deflate-chain-source "../example/019-deflate-fixed-chain.asm")

(define (ok-items results)
  (for/list ([r (in-list (parse-results-items results))]
             #:when (parse-result-ok? r))
    (parse-result-instruction r)))

(define (cfg-from-gnu source)
  (define results (parse-string source #:syntax 'gnu #:validate? #t))
  (check-equal? (parse-results-error-count results) 0)
  (build-cfg (ok-items results) 'public-abi-test))

(define public-abi-tests
  (test-suite
   "public ABI profile checks"

   (test-case "explicit C public profile rejects private function ABI"
     (define cfg
       (cfg-from-gnu
        #<<ASM
.asmp.function api_bad export profile=c-aapcs64 abi=fast20
entry:
  ret
.asmp.end_function
ASM
        ))
     (define errors (check-public-abi-profiles cfg))
     (check-equal? (length errors) 1)
     (check-equal? (public-abi-error-function-name (car errors)) 'api_bad)
     (check-equal? (public-abi-error-profile (car errors)) 'c-aapcs64)
     (check-equal? (public-abi-error-abi-name (car errors)) 'fast20)
     (check-not-false
      (regexp-match? #rx"profile=c-aapcs64 conflicts with function abi=fast20"
                     (format-public-abi-error (car errors)))))

   (test-case "explicit C public profile allows C-compatible entry ABI names"
     (define cfg
       (cfg-from-gnu
        #<<ASM
.asmp.function api_leaf export profile=c-aapcs64 abi=leaf
entry:
  ret
.asmp.end_function
ASM
        ))
     (check-equal? (check-public-abi-profiles cfg) '()))

   (test-case "project public profile requires an explicit ABI contract"
     (define cfg
       (cfg-from-gnu
        #<<ASM
.function engine.plugin.entry export profile=project-abi ()
entry:
  ret
.end
ASM
        ))
     (define errors (check-public-abi-profiles cfg))
     (check-equal? (length errors) 1)
     (check-equal? (public-abi-error-profile (car errors)) 'project-abi)
     (check-false (public-abi-error-abi-name (car errors)))
     (check-not-false
      (regexp-match? #rx"requires an explicit function abi=<name>"
                     (format-public-abi-error (car errors)))))

   (test-case "new .function supports explicit project ABI profiles"
     (define cfg
       (cfg-from-gnu
        #<<ASM
.function engine.plugin.entry export profile=project-abi abi=fast20 ()
entry:
  ret
.end
ASM
        ))
     (define fn (cfg-get-function-by-name cfg 'engine.plugin.entry))
     (check-not-false fn)
     (check-equal? (fn-public-abi-profile fn) 'project-abi)
     (check-true (fn-public-abi-profile-explicit? fn))
     (check-equal? (fn-get-info fn 'abi #f) 'fast20)
     (check-equal? (check-public-abi-profiles cfg) '()))

   (test-case "linux syscall profile rejects private managed ABI on the public entry"
     (define cfg
       (cfg-from-gnu
        #<<ASM
.function sys.entry export profile=linux-syscall abi=fast20 ()
entry:
  ret
.end
ASM
        ))
     (define errors (check-public-abi-profiles cfg))
     (check-equal? (length errors) 1)
     (check-equal? (public-abi-error-profile (car errors)) 'linux-syscall)
     (check-equal? (public-abi-error-abi-name (car errors)) 'fast20))

   (test-case "jit-private profile accepts explicit custom ABI"
     (define cfg
       (cfg-from-gnu
        #<<ASM
.function jit.entry export profile=jit-private abi=fast20 ()
entry:
  ret
.end
ASM
        ))
     (define fn (cfg-get-function-by-name cfg 'jit.entry))
     (check-not-false fn)
     (check-equal? (fn-public-abi-profile fn) 'jit-private)
     (check-equal? (fn-get-info fn 'abi #f) 'fast20)
     (check-equal? (check-public-abi-profiles cfg) '()))

   (test-case "public ABI manifest records exported roots only"
     (define cfg
       (cfg-from-gnu
        #<<ASM
.function api.entry export profile=project-abi abi=fast20 ()
entry:
  ret
.end

.function internal.helper ()
entry:
  ret
.end
ASM
        ))
     (define manifest (public-abi-manifest cfg))
     (check-equal? (hash-ref manifest 'format) 'asmp-public-abi)
     (check-equal? (hash-ref manifest 'version) 1)
     (define exports (hash-ref manifest 'exports))
     (check-equal? (length exports) 1)
     (define entry (car exports))
     (check-equal? (hash-ref entry 'name) 'api.entry)
     (check-equal? (hash-ref entry 'logical-name) 'api.entry)
     (check-equal? (hash-ref entry 'linkage-symbol) 'api.entry)
     (check-equal? (hash-ref entry 'visibility) 'public)
     (check-true (hash-ref entry 'header?))
     (check-equal? (hash-ref entry 'profile) 'project-abi)
     (check-equal? (hash-ref entry 'abi) 'fast20)
     (check-equal? (hash-ref entry 'params) '())
     (check-true (hash-ref entry 'profile-explicit?)))

   (test-case "hidden no-header export stays in manifest but not C header"
     (define cfg
       (cfg-from-gnu
        #<<ASM
.function raw.impl export profile=c-aapcs64 visibility=hidden no-header ()
entry:
  ret
.end

.function api.entry export profile=c-aapcs64 (
  out: x.value
)
entry:
  ret
.end
ASM
        ))
     (define manifest (public-abi-manifest cfg))
     (define exports (hash-ref manifest 'exports))
     (check-equal? (length exports) 2)
     (define raw-entry
       (for/first ([entry (in-list exports)]
                   #:when (eq? (hash-ref entry 'name) 'raw.impl))
         entry))
     (check-not-false raw-entry)
     (check-equal? (hash-ref raw-entry 'visibility) 'hidden)
     (check-false (hash-ref raw-entry 'header?))
     (define header (public-c-header manifest))
     (check-false (regexp-match? #rx"raw\\.impl|raw_impl|skipped raw" header))
     (check-not-false (regexp-match? #rx"extern uint64_t api_entry" header))
     (define gnu-rendered
       (parameterize ([current-emit-config default-emit-config])
         (emit-module cfg)))
     (check-not-false (regexp-match? #rx"\\.globl raw\\.impl" gnu-rendered))
     (check-not-false (regexp-match? #rx"\\.hidden raw\\.impl" gnu-rendered))
     (define apple-rendered
       (parameterize ([current-emit-config apple-emit-config])
         (emit-module cfg)))
     (check-not-false (regexp-match? #rx"\\.globl _raw\\.impl" apple-rendered))
     (check-not-false (regexp-match? #rx"\\.private_extern _raw\\.impl" apple-rendered)))

   (test-case "weak public default emits platform weak binding"
     (define cfg
       (cfg-from-gnu
        #<<ASM
.function api.default export weak profile=c-aapcs64 (
  out: x.value
)
entry:
  ret
.end
ASM
        ))
     (define fn (cfg-get-function-by-name cfg 'api.default))
     (check-not-false fn)
     (check-equal? (fn-get-info fn 'binding #f) 'weak)
     (define entry (car (hash-ref (public-abi-manifest cfg) 'exports)))
     (check-equal? (hash-ref entry 'binding) 'weak)
     (define gnu-rendered
       (parameterize ([current-emit-config default-emit-config])
         (emit-module cfg)))
     (check-not-false (regexp-match? #rx"\\.weak api\\.default" gnu-rendered))
     (check-false (regexp-match? #rx"\\.globl api\\.default" gnu-rendered))
     (define apple-rendered
       (parameterize ([current-emit-config apple-emit-config])
         (emit-module cfg)))
     (check-not-false
      (regexp-match? #rx"\\.weak_definition _api\\.default" apple-rendered))
     (check-not-false (regexp-match? #rx"\\.globl _api\\.default" apple-rendered))
     (check-not-false (regexp-match? #rx"\\.subsections_via_symbols" apple-rendered)))

   (test-case "public ABI manifest records managed signature parameters"
     (define cfg
       (cfg-from-gnu
        #<<ASM
.function api.add export profile=c-aapcs64 (
  in: x.left, w.right,
  out: x.result
)
entry:
  ret
.end
ASM
        ))
     (define entry (car (hash-ref (public-abi-manifest cfg) 'exports)))
     (check-equal?
      (map (lambda (param)
             (list (hash-ref param 'mode)
                   (hash-ref param 'kind)
                   (hash-ref param 'name)))
           (hash-ref entry 'params))
      '((in x left) (in w right) (out x result))))

   (test-case "public C header is generated from simple managed signatures"
     (define cfg
       (cfg-from-gnu
        #<<ASM
.function api.add export profile=c-aapcs64 (
  in: x.left, w.right,
  out: x.result
)
entry:
  ret
.end

.function api.bump export profile=apple-c-arm64 (
  inout: x.value
)
entry:
  ret
.end
ASM
        ))
     (define header (public-c-header (public-abi-manifest cfg)))
     (check-not-false
      (regexp-match? #rx"extern uint64_t api_add\\(uint64_t left, uint32_t right\\) ASMP_PUBLIC_SYM\\(\"api\\.add\"\\);"
                     header))
     (check-not-false
      (regexp-match? #rx"extern uint64_t api_bump\\(uint64_t value\\) ASMP_PUBLIC_SYM\\(\"api\\.bump\"\\);"
                     header)))

   (test-case "public C header skips entries without managed signatures"
     (define cfg
       (cfg-from-gnu
        #<<ASM
.function raw.entry export profile=c-aapcs64 ()
entry:
  ret
.end
ASM
        ))
     (define header (public-c-header (public-abi-manifest cfg)))
     (check-not-false
      (regexp-match? #rx"/\\* skipped raw\\.entry: missing non-empty managed signature \\*/"
                     header))
     (check-false
      (regexp-match? #rx"extern .*raw_entry" header)))

   (test-case "public C header maps common deflate API names to C pointer types"
     (define cfg
       (cfg-from-gnu
        #<<ASM
.function asmp_deflate_raw_fixed export profile=c-aapcs64 (
  in: x.dst, x.dst_cap, x.dst_len, x.src, x.src_len, x.scratch, x.scratch_len,
  out: w.status
)
entry:
  ret
.end

.function asmp_deflate_raw_auto export profile=c-aapcs64 (
  in: x.dst, x.dst_cap, x.dst_len, x.src, x.src_len, x.scratch, x.scratch_len,
  out: w.status
)
entry:
  ret
.end

.function asmp_deflate_raw_stored export profile=c-aapcs64 (
  in: x.dst, x.dst_cap, x.dst_len, x.src, x.src_len,
  out: w.status
)
entry:
  ret
.end
ASM
        ))
     (define header (public-c-header (public-abi-manifest cfg)))
     (check-not-false
      (regexp-match? #rx"extern int asmp_deflate_raw_fixed\\(uint8_t \\* dst, uint64_t dst_cap, uint64_t \\* dst_len, const uint8_t \\* src, uint64_t src_len, void \\* scratch, uint64_t scratch_len\\);"
                     header))
     (check-not-false
      (regexp-match? #rx"extern int asmp_deflate_raw_auto\\(uint8_t \\* dst, uint64_t dst_cap, uint64_t \\* dst_len, const uint8_t \\* src, uint64_t src_len, void \\* scratch, uint64_t scratch_len\\);"
                     header))
     (check-not-false
      (regexp-match? #rx"extern int asmp_deflate_raw_stored\\(uint8_t \\* dst, uint64_t dst_cap, uint64_t \\* dst_len, const uint8_t \\* src, uint64_t src_len\\);"
                     header)))

   (test-case "deflate chain header exposes wrapper API only"
     (define results (parse-file deflate-chain-source #:syntax 'gnu #:validate? #t))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg (build-cfg (ok-items results) 'deflate-chain))
     (define manifest (public-abi-manifest cfg))
     (define exports (hash-ref manifest 'exports))
     (define raw-entry
       (for/first ([entry (in-list exports)]
                   #:when (eq? (hash-ref entry 'name)
                               'deflate_fixed_chain_aarch64_asm))
         entry))
     (check-not-false raw-entry)
     (check-equal? (hash-ref raw-entry 'visibility) 'hidden)
     (check-false (hash-ref raw-entry 'header?))
     (define header (public-c-header manifest))
     (check-false (regexp-match? #rx"deflate_fixed_chain_aarch64_asm" header))
     (for ([name (in-list '("asmp_deflate_raw_bound"
                            "asmp_deflate_raw_scratch_size"
                            "asmp_deflate_raw_scratch_align"
                            "asmp_deflate_raw_fixed"
                            "asmp_deflate_raw_stored"
                            "asmp_deflate_raw_auto"))])
       (check-not-false (regexp-match? (regexp (regexp-quote name)) header))))

   (test-case "public C header knows the physical deflate wrapper prototype"
     (define cfg
       (cfg-from-gnu
        #<<ASM
.function asmp_deflate_raw_bound export profile=c-aapcs64 ()
entry:
  ret
.end

.function asmp_deflate_raw_scratch_size export profile=c-aapcs64 ()
entry:
  ret
.end

.function asmp_deflate_raw_scratch_align export profile=c-aapcs64 ()
entry:
  ret
.end

.function asmp_deflate_raw_fixed export profile=c-aapcs64 ()
entry:
  ret
.end
ASM
        ))
     (define header (public-c-header (public-abi-manifest cfg)))
     (check-not-false
      (regexp-match? #rx"extern uint64_t asmp_deflate_raw_bound\\(uint64_t src_len\\);"
                     header))
     (check-not-false
      (regexp-match? #rx"extern uint64_t asmp_deflate_raw_scratch_size\\(void\\);"
                     header))
     (check-not-false
      (regexp-match? #rx"extern uint64_t asmp_deflate_raw_scratch_align\\(void\\);"
                     header))
     (check-not-false
      (regexp-match? #rx"extern int asmp_deflate_raw_fixed\\(uint8_t \\* dst, uint64_t dst_cap, uint64_t \\* dst_len, const uint8_t \\* src, uint64_t src_len, void \\* scratch, uint64_t scratch_len\\);"
                     header))
     (check-false
      (regexp-match? #rx"skipped asmp_deflate_raw_" header)))

   (test-case "public ABI manifest can be written as rktd"
     (define cfg
       (cfg-from-gnu
        #<<ASM
.function api.entry export profile=c-aapcs64 ()
entry:
  ret
.end
ASM
        ))
     (define path (make-temporary-file "asmp-public-abi-~a.rktd"))
     (dynamic-wind
       void
       (lambda ()
         (write-public-abi-manifest (public-abi-manifest cfg) path)
         (define manifest (call-with-input-file path read))
         (define entry (car (hash-ref manifest 'exports)))
         (check-equal? (hash-ref manifest 'format) 'asmp-public-abi)
         (check-equal? (hash-ref entry 'name) 'api.entry)
         (check-equal? (hash-ref entry 'profile) 'c-aapcs64))
       (lambda ()
         (when (file-exists? path)
           (delete-file path)))))

   (test-case "CLI writes public ABI manifest after CFG checks"
     (define source-path (make-temporary-file "asmp-public-abi-cli-~a.asm"))
     (define asm-path (make-temporary-file "asmp-public-abi-cli-~a.s"))
     (define manifest-path (make-temporary-file "asmp-public-abi-cli-~a.rktd"))
     (dynamic-wind
       (lambda ()
         (call-with-output-file source-path
           (lambda (out)
             (display #<<ASM
.function api.entry export profile=c-aapcs64 ()
entry:
  ret
.end
ASM
                      out))
           #:exists 'truncate/replace))
       (lambda ()
         (parameterize ([cli:input-syntax 'gnu]
                        [cli:output-file asm-path]
                        [cli:output-stdout #f]
                        [cli:public-abi-manifest-file manifest-path]
                        [cli:stop-after 'emit])
           (check-equal? (cli:run-compiler/files (list source-path)) 0))
         (define manifest (call-with-input-file manifest-path read))
         (define entry (car (hash-ref manifest 'exports)))
         (check-equal? (hash-ref entry 'name) 'api.entry)
         (check-equal? (hash-ref entry 'profile) 'c-aapcs64))
       (lambda ()
         (for ([path (in-list (list source-path asm-path manifest-path))])
           (when (file-exists? path)
             (delete-file path))))))

   (test-case "CLI writes public C header"
     (define source-path (make-temporary-file "asmp-public-c-header-cli-~a.asm"))
     (define asm-path (make-temporary-file "asmp-public-c-header-cli-~a.s"))
     (define header-path (make-temporary-file "asmp-public-c-header-cli-~a.h"))
     (dynamic-wind
       (lambda ()
         (call-with-output-file source-path
           (lambda (out)
             (display #<<ASM
.function api.add export profile=c-aapcs64 (
  in: x.left, x.right,
  out: x.result
)
entry:
  ret
.end
ASM
                      out))
           #:exists 'truncate/replace))
       (lambda ()
         (parameterize ([cli:input-syntax 'gnu]
                        [cli:output-file asm-path]
                        [cli:output-stdout #f]
                        [cli:public-c-header-file header-path]
                        [cli:stop-after 'emit])
           (check-equal? (cli:run-compiler/files (list source-path)) 0))
         (define header (file->string header-path))
         (check-not-false
          (regexp-match? #rx"extern uint64_t api_add\\(uint64_t left, uint64_t right\\)"
                         header)))
       (lambda ()
         (for ([path (in-list (list source-path asm-path header-path))])
           (when (file-exists? path)
             (delete-file path))))))

   (test-case "legacy export without explicit profile is not rejected"
     (define cfg
       (cfg-from-gnu
        #<<ASM
.asmp.function old_fast_export export abi=fast20
entry:
  ret
.asmp.end_function
ASM
        ))
     (define fn (cfg-get-function-by-name cfg 'old_fast_export))
     (check-not-false fn)
     (check-true (fn-public-abi-root? fn))
     (check-false (fn-public-abi-profile-explicit? fn))
     (check-equal? (check-public-abi-profiles cfg) '()))

   (test-case "CLI CFG stage includes public ABI profile errors"
     (define results
       (parse-string
        #<<ASM
.asmp.function api_bad export profile=c-aapcs64 abi=fast20
entry:
  ret
.asmp.end_function
ASM
        #:syntax 'gnu
        #:validate? #t))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg-result
       (cli:run-cfg-stage (ok-items results) 'public-abi-test))
     (check-equal? (pvector-length (cli:cfg-stage-result-errors cfg-result)) 1)
     (check-not-false
      (regexp-match? #rx"profile=c-aapcs64 conflicts with function abi=fast20"
                     (pvector-ref (cli:cfg-stage-result-errors cfg-result) 0))))))

(module+ main
  (void (run-tests public-abi-tests)))

(module+ test
  (void (run-tests public-abi-tests)))
