#lang racket

(require rackunit
         rackunit/text-ui
         racket/runtime-path
         "../parser/frontend.rkt"
         "../parser/ast.rkt"
         "../semantic/control-flow.rkt"
         "../semantic/inline.rkt"
         "../pipeline/pipeline.rkt"
         "../pipeline/regalloc/abi-config.rkt"
         "../codegen/emit.rkt"
         racket/pvector
         (prefix-in cli: "../cli/as.rkt"))

;; ============================================================
;; GNU frontend tests
;; ============================================================

(define-runtime-path gnu-basic-fixture "fixtures/gnu-basic.asm")
(define-runtime-path standalone-hello-source "../example/011-gnu-standalone-hello.asm")
(define-runtime-path macos-hello-source "../example/012-macos-standalone-hello.asm")
(define-runtime-path deflate-asm-source "../example/013-deflate-fixed-fast.asm")
(define-runtime-path deflate-chain-asm-source "../example/019-deflate-fixed-chain.asm")
(define-runtime-path abi-config-source "../config/abi.rktd")

(define (parse-gnu source #:validate? [validate? #t])
  (parse-string source
                #:source 'gnu-test
                #:syntax 'gnu
                #:validate? validate?))

(define (ok-items results)
  (for/list ([r (in-list (parse-results-items results))]
             #:when (parse-result-ok? r))
    (parse-result-instruction r)))

(define (instructions results)
  (filter ast-ins? (ok-items results)))

(define (compile-functions items config)
  (default-abi-name 'aapcs64)
  (define cfg (expand-inline-cfg (build-cfg items)))
  (parameterize ([current-emit-config config])
    (string-join
     (for/list ([i (in-range (cfg-function-count cfg))])
       (define fn (cfg-get-function cfg i))
       (emit-function/result (run-pipeline fn default-pipeline-config)))
     "\n\n")))

(define gnu-frontend-tests
  (test-suite
   "GNU frontend -> shared AST"

   (test-case "GNU function lowers to function/label/instruction directives"
     (define results
       (parse-gnu #<<ASM
.text
.globl add1
.type add1, %function
add1:
  add x0, x0, #1
  ret
.size add1, .-add1
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (define items (ok-items results))
     (check-equal? (map ast-ins-mnemonic (instructions results)) '(add ret))
     (define fn
       (for/first ([item (in-list items)]
                   #:when (and (ast-directive? item)
                               (eq? (ast-directive-kind item) 'function)))
         item))
     (check-not-false fn)
     (check-equal? (ast-directive-kind fn) 'function)
     (check-equal? (ast-directive-name fn) 'add1)
     (check-true (hash-ref (ast-directive-args fn) 'export #f))
     (check-equal? (ast-directive-kind (last items)) 'end-function)
     (define cfg (build-cfg items))
     (check-equal? (cfg-get-info cfg 'module-items '()) '()))

   (test-case "parse-file accepts GNU source explicitly"
     (define results (parse-file gnu-basic-fixture #:syntax 'gnu #:validate? #t))
     (check-equal? (parse-results-error-count results) 0)
     (check-equal? (map ast-ins-mnemonic (instructions results)) '(add ret)))

   (test-case "standalone GNU hello uses _start, syscall, and local rodata"
     (define results (parse-file standalone-hello-source #:syntax 'gnu #:validate? #t))
     (check-equal? (parse-results-error-count results) 0)
     (check-equal? (map ast-ins-mnemonic (instructions results))
                   '(mov adrp add mov mov svc mov mov svc))
     (define cfg (build-cfg (ok-items results)))
     (check-not-false (cfg-get-function-by-name cfg '_start))
     (check-equal? (map ast-directive-kind (cfg-get-info cfg 'module-items '()))
                   '(section label ascii))
     (define rendered
       (parameterize ([current-emit-config default-emit-config])
         (emit-module cfg)))
     (check-not-false (regexp-match? #rx"\\.globl _start" rendered))
     (check-not-false (regexp-match? #rx"svc #0" rendered))
     (check-not-false (regexp-match? #rx"\\.ascii \"hello world from asmp\\\\n\"" rendered)))

   (test-case "macOS GNU hello preserves LR across puts"
     (define results (parse-file macos-hello-source #:syntax 'gnu #:validate? #t))
     (check-equal? (parse-results-error-count results) 0)
     (define items (ok-items results))
     (check-equal? (for/list ([item (in-list items)]
                              #:when (and (ast-directive? item)
                                          (memq (ast-directive-kind item) '(save! load!))))
                     (ast-directive-kind item))
                   '(save! load!))
     (define rendered (compile-functions items apple-emit-config))
     (check-not-false (regexp-match? #rx"\\.globl _main" rendered))
     (check-not-false (regexp-match? #rx"stp x29, x30, \\[sp, #-[0-9]+\\]!" rendered))
     (check-not-false (regexp-match? #rx"bl _puts" rendered))
     (check-not-false (regexp-match? #rx"ldp x29, x30, \\[sp\\], #[0-9]+" rendered)))

   (test-case "-g emits assembler line debug directives"
     (define results
       (parse-string #<<ASM
.asmp.function debug_lines abi=aapcs64 export
entry:
  mov x.tmp, x0
  add x0, x.tmp, #1
  ret
.asmp.end_function
ASM
                     #:source "debug-input.asm"
                     #:syntax 'gnu
                     #:validate? #t))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg (expand-inline-cfg (build-cfg (ok-items results))))
     (define fn (cfg-get-function-by-name cfg 'debug_lines))
     (define rendered
       (parameterize ([current-emit-config
                       (struct-copy emit-config default-emit-config
                                    [emit-debug-info? #t])])
         (emit-function/result (run-pipeline fn default-pipeline-config))))
     (check-not-false (regexp-match? #rx"\\.file 1 \"debug-input\\.asm\"" rendered))
     (check-not-false (regexp-match? #rx"\\.loc 1 3 0\n    mov" rendered))
     (check-not-false (regexp-match? #rx"\\.loc 1 4 0\n    add" rendered))
     (check-not-false (regexp-match? #rx"\\.loc 1 5 0\n    ret" rendered)))

   (test-case "-g emits a minimal DWARF compile unit for line lookup"
     (define results
       (parse-string #<<ASM
.asmp.function debug_cu abi=aapcs64 export
entry:
  mov x.tmp, x0
  add x0, x.tmp, #1
  mov w.tmp32, #7
  add w0, w.tmp32, #1
  ret
.asmp.end_function
ASM
                     #:source "debug-cu.asm"
                     #:syntax 'gnu
                     #:validate? #t))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg (expand-inline-cfg (build-cfg (ok-items results))))
     (define fn (cfg-get-function-by-name cfg 'debug_cu))
     (define result (run-pipeline fn default-pipeline-config))
     (define rendered
       (parameterize ([cli:asm-syntax 'gnu]
                      [cli:emit-debug-lines #t]
                      [cli:emit-debug-reg-map #f]
                      [cli:emit-cfi #f])
         (cli:emit-stage-result-assembly
          (cli:run-emit-stage (list result)))))
     (check-not-false (regexp-match? #rx"\\.Lasmp_debug_text_begin:" rendered))
     (check-not-false (regexp-match? #rx"\\.section \\.debug_abbrev" rendered))
     (check-not-false (regexp-match? #rx"\\.section \\.debug_info" rendered))
     (check-not-false (regexp-match? #rx"\\.short 29" rendered))
     (check-not-false (regexp-match? #rx"\\.asciz \"debug-cu\\.asm\"" rendered))
     (check-not-false (regexp-match? #rx"\\.asciz \"debug_cu\"" rendered))
     (check-not-false (regexp-match? #rx"\\.asciz \"x\\.tmp\"" rendered))
     (check-not-false (regexp-match? #rx"\\.asciz \"w\\.tmp32\"" rendered))
     (check-false (regexp-match? #rx"\\.asciz \"x\\.tmp32\"" rendered)))

   (test-case "-g maps inline call line to expanded entry"
     (define results
       (parse-string #<<ASM
.function bump2 (inout: x.value)
entry:
  add x.value, x.value, #1
  add x.value, x.value, #2
  .return
.end

.asmp.function inline_break abi=aapcs64 export
entry:
  mov x.value, x0
  .inline bump2 (x.value=x.value)
  mov x0, x.value
  ret
.asmp.end_function
ASM
                     #:source "debug-inline.asm"
                     #:syntax 'gnu
                     #:validate? #t))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg (expand-inline-cfg (build-cfg (ok-items results))))
     (define fn (cfg-get-function-by-name cfg 'inline_break))
     (define rendered
       (parameterize ([current-emit-config
                       (struct-copy emit-config default-emit-config
                                    [emit-debug-info? #t])])
         (emit-function/result (run-pipeline fn default-pipeline-config))))
     (check-not-false (regexp-match? #rx"\\.loc 1 10 0\n    mov" rendered))
     (check-not-false (regexp-match? #rx"\\.loc 1 11 0\n    add" rendered))
     (check-not-false (regexp-match? #rx"\\.loc 1 4 0\n    add" rendered))
     (check-not-false (regexp-match? #rx"\\.loc 1 12 0\n    mov" rendered)))

   (test-case "--cfi tracks managed save/restore frames"
     (define results (parse-file macos-hello-source #:syntax 'gnu #:validate? #t))
     (check-equal? (parse-results-error-count results) 0)
     (define rendered
       (compile-functions
        (ok-items results)
        (struct-copy emit-config default-emit-config
                     [emit-cfi? #t])))
     (check-not-false (regexp-match? #rx"\\.cfi_startproc" rendered))
     (check-not-false (regexp-match? #rx"\\.cfi_def_cfa sp, 0" rendered))
     (check-not-false (regexp-match? #rx"\\.cfi_def_cfa_offset 32" rendered))
     (check-not-false (regexp-match? #rx"\\.cfi_offset w29, -32" rendered))
     (check-not-false (regexp-match? #rx"\\.cfi_offset w30, -24" rendered))
     (check-not-false (regexp-match? #rx"\\.cfi_def_cfa w29, 32" rendered))
     (check-not-false (regexp-match? #rx"\\.cfi_restore w29" rendered))
     (check-not-false (regexp-match? #rx"\\.cfi_restore w30" rendered))
     (check-not-false (regexp-match? #rx"\\.cfi_endproc" rendered)))

   (test-case "GNU deflate example compiles through .function helpers selected by .inline"
     (define results (parse-file deflate-asm-source #:syntax 'gnu #:validate? #t))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg (expand-inline-cfg (build-cfg (ok-items results))))
     (define fn (cfg-get-function-by-name cfg 'deflate_fixed_fast_aarch64_asm))
     (check-not-false fn)
     (define rendered
       (parameterize ([current-emit-config default-emit-config])
         (emit-function/result (run-pipeline fn default-pipeline-config))))
     (check-not-false (regexp-match? #rx"\\.globl deflate_fixed_fast_aarch64_asm" rendered))
     (check-false (regexp-match? #rx"^df_flush8:" rendered))
     (check-not-false (regexp-match? #rx"ubfm w[0-9]+, w[0-9]+, #0, #14" rendered)))

   (test-case "GNU deflate hash-chain example compiles with managed frame directives"
     (parameterize ([abi-config-path abi-config-source])
       (reload-abi-config abi-config-source #:force? #t)
       (define results (parse-file deflate-chain-asm-source #:syntax 'gnu #:validate? #t))
       (check-equal? (parse-results-error-count results) 0)
       (define cfg (expand-inline-cfg (build-cfg (ok-items results))))
       (define fn (cfg-get-function-by-name cfg 'deflate_fixed_chain_aarch64_asm))
       (check-not-false fn)
       (define rendered
         (parameterize ([current-emit-config default-emit-config])
           (emit-function/result (run-pipeline fn default-pipeline-config))))
       (check-not-false (regexp-match? #rx"\\.globl deflate_fixed_chain_aarch64_asm" rendered))
       (check-false (regexp-match? #rx"^df_flush8:" rendered))
       (check-false (regexp-match? #rx"^df_insert_hash_pos:" rendered))
       (check-false (regexp-match? #rx"^df_search_chain:" rendered))
       (check-not-false (regexp-match? #rx"stp x29, x30" rendered))
       (check-not-false (regexp-match? #rx"emit_current_match" rendered))
       (check-not-false (regexp-match? #rx"reinsert_skipped_loop" rendered))
       (check-not-false (regexp-match? #rx"ubfm w[0-9]+, w[0-9]+, #0, #14" rendered))))

   (test-case "deflate public wrapper calls hidden raw kernel through managed .call"
     (define results (parse-file deflate-chain-asm-source #:syntax 'gnu #:validate? #t))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg (expand-inline-cfg (build-cfg (ok-items results))))
     (define wrapper (cfg-get-function-by-name cfg 'asmp_deflate_raw_fixed))
     (check-not-false wrapper)
     (define insns '())
     (fn-for-each-block
      wrapper
      (lambda (block)
        (set! insns
              (append insns
                      (for/list ([ins (in-pvector (basic-block-instructions block))])
                        ins)))))
     (define bl-index
       (for/first ([ins (in-list insns)]
                   [i (in-naturals)]
                   #:when (and (ast-ins? ins)
                               (eq? (ast-ins-mnemonic ins) 'bl)
                               (match (ast-ins-operands ins)
                                 [(list (? ast-label? label))
                                  (eq? (ast-label-name label)
                                       'deflate_fixed_chain_aarch64_asm)]
                                 [_ #f])))
         i))
     (check-not-false bl-index)
     (define writeback (list-ref insns (add1 bl-index)))
     (check-equal? (ast-ins-mnemonic writeback) 'mov)
     (match (ast-ins-operands writeback)
       [(list (? ast-reg? dst) (? ast-reg? src))
        (check-equal? (ast-reg-id dst) 'written)
        (check-equal? (ast-reg-id src) 0)]
       [_ (fail-check "expected .call output writeback move")]))

   (test-case "--debug-reg-map keeps pre-rewrite allocation records"
     (define results (parse-file deflate-asm-source #:syntax 'gnu #:validate? #t))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg (expand-inline-cfg (build-cfg (ok-items results))))
     (define fn (cfg-get-function-by-name cfg 'deflate_fixed_fast_aarch64_asm))
     (define result (run-pipeline fn default-pipeline-config))
     (define rendered
       (parameterize ([cli:asm-syntax 'gnu]
                      [cli:emit-debug-reg-map #t]
                      [cli:emit-debug-lines #f]
                      [cli:emit-cfi #f])
         (cli:emit-stage-result-assembly
          (cli:run-emit-stage (list result)))))
     (check-not-false (regexp-match? #rx"// asmp debug reg map: deflate_fixed_fast_aarch64_asm" rendered))
     (check-not-false (regexp-match? #rx"// iteration 0:" rendered))
     (check-not-false (regexp-match? #rx"x\\.out -> x[0-9]+" rendered))
     (check-not-false (regexp-match? #rx"x\\.dst_base" rendered)))

   (test-case ".function inline calls are named-only"
     (define good
       (parse-gnu #<<ASM
.function copy (in: x.src, out: x.dst)
entry:
  mov x.dst, x.src
  .return
.end

.asmp.function caller abi=aapcs64 export
entry:
  .inline copy (x.src=x0, x.dst=x1)
  ret
.asmp.end_function
ASM
                  ))
     (check-equal? (parse-results-error-count good) 0)
     (check-not-false (expand-inline-cfg (build-cfg (ok-items good))))
     (check-equal? (parse-results-error-count (parse-gnu ".inline copy x.src=x0\n")) 1)
     (check-equal? (parse-results-error-count (parse-gnu ".inline copy (x.src)\n")) 1))

   (test-case ".function inline binding set is checked"
     (define (check-inline-error call rx)
       (define results
         (parse-gnu
          (format #<<ASM
.function copy (in: x.src, out: x.dst)
entry:
  mov x.dst, x.src
  .return
.end

.asmp.function caller abi=aapcs64 export
entry:
  ~a
  ret
.asmp.end_function
ASM
                  call)))
       (check-equal? (parse-results-error-count results) 0)
       (check-exn (lambda (e) (regexp-match? rx (exn-message e)))
                  (lambda () (expand-inline-cfg (build-cfg (ok-items results))))))
     (check-inline-error ".inline copy (x.src=x0)"
                         #rx"缺少参数绑定")
     (check-inline-error ".inline copy (x.src=x0, x.dst=x1, x.tmp=x2)"
                         #rx"未声明参数")
     (check-inline-error ".inline copy (x.src=x0, x.src=x1, x.dst=x2)"
                         #rx"重复绑定参数"))

   (test-case ".function public C entry lowers ABI live-ins directly"
     (define results
       (parse-gnu #<<ASM
.function api.entry export profile=c-aapcs64 (
  in: x.dst,
  in: x.dst_cap,
  in: x.dst_len,
  in: x.src,
  in: x.src_len,
  in: x.scratch,
  in: x.scratch_len,
  out: w.status
)
entry:
  cmp x.dst_cap, x.src_len
  b.lo small
  mov w.status, #0
  ret
small:
  mov w.status, #1
  ret
.end
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg (expand-inline-cfg (build-cfg (ok-items results))))
     (define fn (cfg-get-function-by-name cfg 'api.entry))
     (check-not-false fn)
     (define entry-block (fn-entry-block fn))
     (check-not-false entry-block)
     (define entry-insns (basic-block-instructions entry-block))
     (define entry-prefix
       (for/list ([ins (in-pvector entry-insns)]
                  [i (in-range 28)])
         ins))
     (check-equal? (length entry-prefix) 28)
     (define constraints (take entry-prefix 21))
     (define first-moves (drop entry-prefix 21))
     (check-equal? (length constraints) 21)
     (for ([constraint (in-list constraints)])
       (check-true (ast-directive? constraint))
       (check-equal? (ast-directive-kind constraint) 'reg-interfere)
       (match (ast-directive-args constraint)
         [(list (? ast-reg? formal) (? ast-reg? livein))
          (check-true (symbol? (ast-reg-id formal)))
          (check-true (integer? (ast-reg-id livein)))]
         [_ (fail-check "expected reg-interfere formal/livein args")]))
     (check-equal? (map (lambda (constraint)
                          (ast-reg-id (second (ast-directive-args constraint))))
                        (take constraints 6))
                   '(1 2 3 4 5 6))
     (for ([index (in-range 7)])
       (define formal-move (list-ref first-moves index))
       (check-equal? (ast-ins-mnemonic formal-move) 'mov)
       (define formal-dst (first (ast-ins-operands formal-move)))
       (define formal-src (second (ast-ins-operands formal-move)))
       (check-true (symbol? (ast-reg-id formal-dst)))
       (check-equal? (ast-reg-id formal-src) index))
     (for ([block (in-list (fn-exit-blocks fn))])
       (define insns (for/list ([ins (in-pvector (basic-block-instructions block))]) ins))
       (check-true (>= (length insns) 2))
       (define return-move (list-ref insns (- (length insns) 2)))
       (define ret-ins (last insns))
       (check-equal? (ast-ins-mnemonic return-move) 'mov)
       (check-equal? (ast-ins-mnemonic ret-ins) 'ret)
       (define return-dst (first (ast-ins-operands return-move)))
       (check-equal? (ast-reg-kind return-dst) 'w)
       (check-equal? (ast-reg-id return-dst) 0))
     (define pipeline-result (run-pipeline fn default-pipeline-config))
     (define rendered
       (parameterize ([current-emit-config default-emit-config])
         (emit-function/result pipeline-result)))
     (check-false (regexp-match? #px"mov x1, x3(.|\n)*cmp x1," rendered))
     (define dwarf-rendered
       (parameterize ([current-emit-config
                       (struct-copy emit-config default-emit-config
                                    [emit-debug-info? #t])])
         (emit-function/result pipeline-result)))
     (check-false (regexp-match? #rx"__asmp_entry_arg" dwarf-rendered))
     (define reg-map-rendered
       (parameterize ([cli:asm-syntax 'gnu]
                      [cli:emit-debug-reg-map #t]
                      [cli:emit-debug-lines #f]
                      [cli:emit-cfi #f])
         (cli:emit-stage-result-assembly
          (cli:run-emit-stage (list pipeline-result)))))
     (check-false (regexp-match? #rx"__asmp_entry_arg" reg-map-rendered)))

   (test-case ".function entry ABI moves are inserted after leading save"
     (define results
       (parse-gnu #<<ASM
.function api.save_entry export profile=c-aapcs64 (
  in: x.dst_len,
  out: w.status
)
entry:
  .save all
  cbz x.dst_len, bad
  str xzr, [x.dst_len]
  mov w.status, #0
  .restore all
  ret
bad:
  mov w.status, #3
  .restore all
  ret
.end
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg (expand-inline-cfg (build-cfg (ok-items results))))
     (define fn (cfg-get-function-by-name cfg 'api.save_entry))
     (check-not-false fn)
     (define rendered
       (parameterize ([current-emit-config default-emit-config])
         (emit-function/result (run-pipeline fn default-pipeline-config))))
     (define save-pos (car (regexp-match-positions #rx"stp x29, x30" rendered)))
     (define entry-move-pos (car (regexp-match-positions #rx"mov x[0-9]+, x0" rendered)))
     (check-true (< (car save-pos) (car entry-move-pos))))

   (test-case ".function entry ABI moves are inserted after explicit frame setup"
     (define results
       (parse-gnu #<<ASM
.function api.frame_entry export profile=c-aapcs64 (
  in: x.dst_len,
  out: w.status
)
entry:
  .save all
  mov x29, sp
  cbz x.dst_len, bad
  str xzr, [x.dst_len]
  mov w.status, #0
  .restore all
  ret
bad:
  mov w.status, #3
  .restore all
  ret
.end
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg (expand-inline-cfg (build-cfg (ok-items results))))
     (define fn (cfg-get-function-by-name cfg 'api.frame_entry))
     (check-not-false fn)
     (define rendered
       (parameterize ([current-emit-config default-emit-config])
         (emit-function/result (run-pipeline fn default-pipeline-config))))
     (define frame-pos (car (regexp-match-positions #rx"mov x29, sp" rendered)))
     (define entry-move-pos (car (regexp-match-positions #rx"mov x[0-9]+, x0" rendered)))
     (check-true (< (car frame-pos) (car entry-move-pos))))

   (test-case ".function return moves are inserted before trailing restore"
     (define results
       (parse-gnu #<<ASM
.function api.status export profile=c-aapcs64 (
  out: w.status
)
entry:
  .save all
  mov w.status, #7
  .restore all
  ret
.end
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg (expand-inline-cfg (build-cfg (ok-items results))))
     (define fn (cfg-get-function-by-name cfg 'api.status))
     (check-not-false fn)
     (define entry-block (fn-entry-block fn))
     (check-not-false entry-block)
     (define insns (for/list ([ins (in-pvector (basic-block-instructions entry-block))]) ins))
     (define return-move-index
       (for/first ([ins (in-list insns)]
                   [i (in-naturals)]
                   #:when (and (ast-ins? ins)
                               (eq? (ast-ins-mnemonic ins) 'mov)
                               (ast-reg? (first (ast-ins-operands ins)))
                               (eq? (ast-reg-kind (first (ast-ins-operands ins))) 'w)
                               (equal? (ast-reg-id (first (ast-ins-operands ins))) 0)))
         i))
     (define restore-index
       (for/first ([ins (in-list insns)]
                   [i (in-naturals)]
                   #:when (and (ast-directive? ins)
                               (eq? (ast-directive-kind ins) 'load!)))
         i))
     (check-not-false return-move-index)
     (check-not-false restore-index)
     (check-true (< return-move-index restore-index)))

   (test-case ".function return slot constraints prevent allocated hidden swaps"
     (define results
       (parse-gnu #<<ASM
.function api.pair abi=aapcs64 (
  out: x.left,
  out: x.right
)
entry:
  mov x.left, x1
  mov x.right, x0
  ret
.end
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg (expand-inline-cfg (build-cfg (ok-items results))))
     (define fn (cfg-get-function-by-name cfg 'api.pair))
     (check-not-false fn)
     (define insns
       (for/list ([ins (in-pvector (basic-block-instructions (fn-entry-block fn)))])
         ins))
     (define (reg-id? value kind id)
       (and (ast-reg? value)
            (eq? (ast-reg-kind value) kind)
            (equal? (ast-reg-id value) id)))
     (define (has-interference? formal-id slot-id)
       (for/or ([ins (in-list insns)])
         (and (ast-directive? ins)
              (eq? (ast-directive-kind ins) 'reg-interfere)
              (match (ast-directive-args ins)
                [(list left right)
                 (and (reg-id? left 'x formal-id)
                      (reg-id? right 'x slot-id))]
                [_ #f]))))
     (check-true (has-interference? 'left 1))
     (check-true (has-interference? 'right 0))
     (define rendered
       (parameterize ([current-emit-config default-emit-config])
         (emit-function/result (run-pipeline fn default-pipeline-config))))
     (check-false
      (regexp-match? #rx"mov x0, x1\n    mov x1, x0\n    ret"
                     rendered)))

   (test-case ".inline-function remains a compatibility alias"
     (define results
       (parse-gnu #<<ASM
.inline-function copy (in: x.src, out: x.dst)
entry:
  mov x.dst, x.src
  .return
.end

.function caller export ()
entry:
  .inline copy (x.src=x0, x.dst=x1)
  ret
.end
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (check-not-false (expand-inline-cfg (build-cfg (ok-items results)))))

   (test-case "CLI omits inline-selected local .function with no branch references"
     (define path (make-temporary-file "asmp-inline-selected-~a.asm"))
     (call-with-output-file path
       (lambda (out)
         (display #<<ASM
.function helper (inout: x.value)
entry:
  add x.value, x.value, #1
  ret
.end

.function app.main export ()
entry:
  mov x10, #41
  .inline helper (x.value=x10)
  mov x0, x10
  ret
.end
ASM
                  out))
       #:exists 'truncate)
     (parameterize ([cli:input-syntax 'gnu]
                    [abi-config-path abi-config-source]
                    [default-abi-name 'aapcs64])
       (reload-abi-config abi-config-source #:force? #t)
       (define parse-result (cli:run-parse-stage path))
       (check-equal? (pvector-length (cli:parse-stage-result-errors parse-result)) 0)
       (define cfg-result
         (cli:run-cfg-stage (cli:parse-stage-result-items parse-result) path))
       (check-equal? (pvector-length (cli:cfg-stage-result-errors cfg-result)) 0)
       (define regalloc-result
         (cli:run-regalloc-stage (cli:cfg-stage-result-cfg cfg-result)
                                 (cli:cfg-stage-result-functions cfg-result)))
       (check-equal? (pvector-length (cli:regalloc-stage-result-errors regalloc-result)) 0)
       (check-equal? (map asm-function-name
                          (cli:regalloc-stage-result-functions regalloc-result))
                     '(app.main))))

   (test-case ".function can be selected by .inline or .call at the call site"
     (define results
       (parse-gnu #<<ASM
.function math.add-one (
  inout: x.value
)
entry:
  add x.value, x.value, #1
  ret
.end

.function app.main export ()
entry:
  mov x10, #41
  .inline math.add-one (x.value=x10)
  .call math.add-one (
    x.value=x10
  )
  mov x0, x10
  ret
.end
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg (expand-inline-cfg (build-cfg (ok-items results))))
     (define main-fn (cfg-get-function-by-name cfg 'app.main))
     (check-not-false main-fn)
     (define rendered
       (parameterize ([current-emit-config default-emit-config])
         (emit-function/result (run-pipeline main-fn default-pipeline-config))))
     (check-not-false (regexp-match? #rx"add x[0-9]+, x[0-9]+, #1" rendered))
     (check-not-false (regexp-match? #rx"bl \"?math\\.add-one\"?" rendered)))

   (test-case ".function and .call use named managed signatures"
     (define results
       (parse-gnu #<<ASM
.function my-lib.hash-v1 (
  in: x.src, x.pos,
  out: w.hash
)
entry:
  add w.hash, w.src, w.pos
  ret
.end

.function crypto.deflate.main export (
  in: x.buf,
  out: w.result
)
entry:
  mov x.i, #7
  .call my-lib.hash-v1 (
    x.src=x.buf,
    x.pos=x.i,
    w.hash=w.result
  )
  ret
.end
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg (expand-inline-cfg (build-cfg (ok-items results))))
     (define helper (cfg-get-function-by-name cfg 'my-lib.hash-v1))
     (define main-fn (cfg-get-function-by-name cfg 'crypto.deflate.main))
     (check-not-false helper)
     (check-not-false main-fn)
     (check-false (fn-get-info helper 'export #f))
     (check-true (fn-get-info main-fn 'export #f))
     (check-true (fn-get-info main-fn 'public-abi-root? #f))
     (check-equal? (fn-get-info main-fn 'public-abi-profile #f) 'c-aapcs64)
     (define rendered
       (parameterize ([current-emit-config default-emit-config])
         (string-join
          (for/list ([fn (in-list (list helper main-fn))])
            (emit-function/result (run-pipeline fn default-pipeline-config)))
          "\n\n")))
     (check-not-false (regexp-match? #rx"\"my-lib\\.hash-v1\":" rendered))
     (check-not-false (regexp-match? #rx"\\.globl crypto\\.deflate\\.main" rendered))
     (check-not-false (regexp-match? #rx"bl \"my-lib\\.hash-v1\"" rendered))
     (check-not-false (regexp-match? #rx"Lmy_lib_hash_v1\\$entry:" rendered))
     (check-not-false (regexp-match? #rx"Lcrypto_deflate_main\\$entry:" rendered))
     (check-false (regexp-match? #rx"(^|\n)entry:" rendered)))

   (test-case ".call can select a handwritten source variant"
     (define results
       (parse-gnu #<<ASM
.function lib.match.scalar (
  inout: x.value
)
entry:
  add x.value, x.value, #1
  ret
.end

.function lib.match.neon variant-of=lib.match.scalar version=neon-extend feature=neon (
  inout: x.value
)
entry:
  add x.value, x.value, #16
  ret
.end

.function app.main export ()
entry:
  mov x10, #0
  .call lib.match.scalar variant=neon-extend (
    x.value=x10
  )
  .call lib.match.scalar feature=neon (
    x.value=x10
  )
  ret
.end
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg (expand-inline-cfg (build-cfg (ok-items results))))
     (define main-fn (cfg-get-function-by-name cfg 'app.main))
     (check-not-false main-fn)
     (define rendered
       (parameterize ([current-emit-config default-emit-config])
         (emit-function/result (run-pipeline main-fn default-pipeline-config))))
     (check-equal? (length (regexp-match* #rx"bl \"?lib\\.match\\.neon\"?" rendered)) 2)
     (check-false (regexp-match? #rx"bl \"?lib\\.match\\.scalar\"?" rendered)))

   (test-case ".function export profile records public ABI metadata"
     (define results
       (parse-gnu #<<ASM
.function asmp.deflate.raw-fixed export profile=apple-c-arm64 ()
entry:
  ret
.end
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg (build-cfg (ok-items results)))
     (define fn (cfg-get-function-by-name cfg 'asmp.deflate.raw-fixed))
     (check-not-false fn)
     (check-true (fn-get-info fn 'export #f))
     (check-true (fn-get-info fn 'public-abi-root? #f))
     (check-equal? (fn-get-info fn 'public-abi-profile #f) 'apple-c-arm64)
     (check-false (fn-get-info fn 'profile #f)))

   (test-case ".function profile requires export"
     (define results
       (parse-gnu #<<ASM
.function internal.helper profile=c-aapcs64 ()
entry:
  ret
.end
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (check-exn #rx"profile=.*without export"
                (lambda () (build-cfg (ok-items results)))))

   (test-case ".call supports fixed FPR and NEON vector slots"
     (define results
       (parse-gnu #<<ASM
.function lib.scale (
  in: d.value,
  out: d.result
)
entry:
  fadd d.result, d.value, d.value
  ret
.end

.function lib.vxor (
  in: v.left.16b,
  in: v.right.16b,
  out: v.result.16b
)
entry:
  eor v.result.16b, v.left.16b, v.right.16b
  ret
.end

.function app.main export ()
entry:
  .call lib.scale (
    d.value=d2,
    d.result=d3
  )
  .call lib.vxor (
    v.left=v10,
    v.right=v11,
    v.result=v12
  )
  ret
.end
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg (expand-inline-cfg (build-cfg (ok-items results))))
     (define main-fn (cfg-get-function-by-name cfg 'app.main))
     (check-not-false main-fn)
     (define rendered
       (parameterize ([current-emit-config default-emit-config])
         (emit-function/result (run-pipeline main-fn default-pipeline-config))))
     (check-not-false (regexp-match? #rx"fmov d0, d2" rendered))
     (check-not-false (regexp-match? #rx"bl lib\\.scale" rendered))
     (check-not-false (regexp-match? #rx"fmov d3, d[0-9]+" rendered))
     (check-not-false (regexp-match? #rx"mov v0\\.16b, v10\\.16b" rendered))
     (check-not-false (regexp-match? #rx"mov v1\\.16b, v11\\.16b" rendered))
     (check-not-false (regexp-match? #rx"bl lib\\.vxor" rendered))
     (check-not-false (regexp-match? #rx"mov v12\\.16b, v[0-9]+\\.16b" rendered)))

   (test-case ".call counts GPR and FPR slots independently"
     (define results
       (parse-gnu #<<ASM
.function lib.mix (
  in: x.ga,
  in: d.fa,
  in: x.gb,
  in: d.fb,
  out: x.go,
  out: d.fo
)
entry:
  add x.go, x.ga, x.gb
  fadd d.fo, d.fa, d.fb
  ret
.end

.function app.main export ()
entry:
  .call lib.mix (
    x.ga=x10,
    d.fa=d10,
    x.gb=x11,
    d.fb=d11,
    x.go=x12,
    d.fo=d12
  )
  ret
.end
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg (expand-inline-cfg (build-cfg (ok-items results))))
     (define main-fn (cfg-get-function-by-name cfg 'app.main))
     (check-not-false main-fn)
     (define rendered
       (parameterize ([current-emit-config default-emit-config])
         (emit-function/result (run-pipeline main-fn default-pipeline-config))))
     (check-not-false (regexp-match? #rx"mov x0, x10" rendered))
     (check-not-false (regexp-match? #rx"fmov d0, d10" rendered))
     (check-not-false (regexp-match? #rx"mov x1, x11" rendered))
     (check-not-false (regexp-match? #rx"fmov d1, d11" rendered))
     (check-not-false (regexp-match? #rx"mov x12, x[0-9]+" rendered))
     (check-not-false (regexp-match? #rx"fmov d12, d[0-9]+" rendered)))

   (test-case ".call supports register-only SVE vector and predicate slots"
     (define results
       (parse-gnu #<<ASM
.function lib.sve (
  in: z.input.B,
  in: p.mask,
  out: z.output.B,
  out: p.out
)
entry:
  orr z.output.d, z.input.d, z.input.d
  mov p.out.b, p.mask.b
  ret
.end

.function app.main export ()
entry:
  .call lib.sve (
    z.input=z10,
    p.mask=p5,
    z.output=z11,
    p.out=p6
  )
  ret
.end
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg (expand-inline-cfg (build-cfg (ok-items results))))
     (define callee-fn (cfg-get-function-by-name cfg 'lib.sve))
     (check-not-false callee-fn)
     (define rendered-callee
       (parameterize ([current-emit-config default-emit-config])
         (emit-function/result (run-pipeline callee-fn default-pipeline-config))))
     (check-not-false (regexp-match? #rx"lib\\.sve:\nLlib_sve\\$entry:\n    " rendered-callee))
     (check-false (regexp-match? #rx"lib\\.sve:\n    [^\n]+\nLlib_sve\\$entry:" rendered-callee))
     (define main-fn (cfg-get-function-by-name cfg 'app.main))
     (check-not-false main-fn)
     (define rendered
       (parameterize ([current-emit-config default-emit-config])
         (emit-function/result (run-pipeline main-fn default-pipeline-config))))
     (check-not-false (regexp-match? #rx"orr z0\\.d, z10\\.d, z10\\.d" rendered))
     (check-not-false (regexp-match? #rx"mov p0\\.b, p5\\.b" rendered))
     (check-not-false (regexp-match? #rx"bl lib\\.sve" rendered))
     (check-not-false (regexp-match? #rx"orr z11\\.d, z[0-9]+\\.d, z[0-9]+\\.d" rendered))
     (check-not-false (regexp-match? #rx"mov p6\\.b, p[0-9]+\\.b" rendered)))

   (test-case ".call to public C-like root reads outputs from return slots"
     (define results
       (parse-gnu #<<ASM
.function api.add export profile=c-aapcs64 (
  in: x.left,
  in: x.right,
  out: x.result
)
entry:
  add x.result, x.left, x.right
  ret
.end

.function app.main export ()
entry:
  .call api.add (
    x.left=x10,
    x.right=x11,
    x.result=x12
  )
  ret
.end
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg (expand-inline-cfg (build-cfg (ok-items results))))
     (define main-fn (cfg-get-function-by-name cfg 'app.main))
     (check-not-false main-fn)
     (define rendered
       (parameterize ([current-emit-config default-emit-config])
         (emit-function/result (run-pipeline main-fn default-pipeline-config))))
     (check-not-false (regexp-match? #rx"mov x0, x10" rendered))
     (check-not-false (regexp-match? #rx"mov x1, x11" rendered))
     (check-not-false (regexp-match? #rx"bl api\\.add" rendered))
     (check-not-false (regexp-match? #rx"mov x12, x0" rendered))
     (check-false (regexp-match? #rx"mov x12, x2" rendered)))

   (test-case ".call uses one temp for cyclic input slot moves"
     (define results
       (parse-gnu #<<ASM
.function lib.mix (
  in: x.left,
  in: x.right
)
entry:
  ret
.end

.function app.main export ()
entry:
  .call lib.mix (
    x.left=x1,
    x.right=x0
  )
  ret
.end
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg (expand-inline-cfg (build-cfg (ok-items results))))
     (define main-fn (cfg-get-function-by-name cfg 'app.main))
     (check-not-false main-fn)
     (define entry-block (fn-entry-block main-fn))
     (define insns
       (for/list ([ins (in-pvector (basic-block-instructions entry-block))]
                  [i (in-range 3)])
         ins))
     (check-equal? (map ast-ins-mnemonic insns) '(mov mov mov))
     (define temp (first (ast-ins-operands (first insns))))
     (check-equal? (ast-reg-id temp) (string->symbol "__asmp_call_in$0"))
     (check-equal? (ast-reg-id (second (ast-ins-operands (first insns)))) 1)
     (check-equal? (ast-reg-id (first (ast-ins-operands (second insns)))) 1)
     (check-equal? (ast-reg-id (second (ast-ins-operands (second insns)))) 0)
     (check-equal? (ast-reg-id (first (ast-ins-operands (third insns)))) 0)
     (check-equal? (ast-reg-id (second (ast-ins-operands (third insns))))
                   (ast-reg-id temp)))

   (test-case ".call uses one temp for cyclic output writeback"
     (define results
       (parse-gnu #<<ASM
.function lib.pair (
  out: x.left,
  out: x.right
)
entry:
  mov x.left, #1
  mov x.right, #2
  ret
.end

.function app.main export ()
entry:
  .call lib.pair (
    x.left=x1,
    x.right=x0
  )
  ret
.end
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg (expand-inline-cfg (build-cfg (ok-items results))))
     (define main-fn (cfg-get-function-by-name cfg 'app.main))
     (check-not-false main-fn)
     (define insns '())
     (fn-for-each-block
      main-fn
      (lambda (block)
        (set! insns
              (append insns
                      (for/list ([ins (in-pvector (basic-block-instructions block))])
                        ins)))))
     (define bl-index
       (for/first ([ins (in-list insns)]
                   [i (in-naturals)]
                   #:when (and (ast-ins? ins)
                               (eq? (ast-ins-mnemonic ins) 'bl)))
         i))
     (check-not-false bl-index)
     (define output-moves (take (drop insns (add1 bl-index)) 3))
     (check-equal? (map ast-ins-mnemonic output-moves) '(mov mov mov))
     (define temp (first (ast-ins-operands (first output-moves))))
     (check-equal? (ast-reg-id temp) (string->symbol "__asmp_call_out$0"))
     (check-equal? (ast-reg-id (second (ast-ins-operands (first output-moves)))) 0)
     (check-equal? (ast-reg-id (first (ast-ins-operands (second output-moves)))) 0)
     (check-equal? (ast-reg-id (second (ast-ins-operands (second output-moves)))) 1)
     (check-equal? (ast-reg-id (first (ast-ins-operands (third output-moves)))) 1)
     (check-equal? (ast-reg-id (second (ast-ins-operands (third output-moves))))
                   (ast-reg-id temp)))

   (test-case ".call input slot constraints prevent allocated hidden swaps"
     (define results
       (parse-gnu #<<ASM
.function lib.mix (
  in: x.left,
  in: x.right
)
entry:
  ret
.end

.function app.main export ()
entry:
  mov x.a, x1
  mov x.b, x0
  .call lib.mix (
    x.left=x.a,
    x.right=x.b
  )
  ret
.end
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg (expand-inline-cfg (build-cfg (ok-items results))))
     (define main-fn (cfg-get-function-by-name cfg 'app.main))
     (define rendered
       (parameterize ([current-emit-config default-emit-config])
         (emit-function/result (run-pipeline main-fn default-pipeline-config))))
     (check-false
      (regexp-match? #rx"mov x0, x1\n    mov x1, x0\n    bl lib\\.mix"
                     rendered))
     (check-not-false
      (regexp-match? #px"mov x[0-9]+, x1\n    mov x1, x0\n    mov x0, x[0-9]+"
                     rendered)))

   (test-case ".call output slot constraints prevent allocated hidden swaps"
     (define results
       (parse-gnu #<<ASM
.function lib.pair (
  out: x.left,
  out: x.right
)
entry:
  mov x.left, #1
  mov x.right, #2
  ret
.end

.function app.main export ()
entry:
  .call lib.pair (
    x.left=x.a,
    x.right=x.b
  )
  mov x1, x.a
  mov x0, x.b
  ret
.end
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg (expand-inline-cfg (build-cfg (ok-items results))))
     (define main-fn (cfg-get-function-by-name cfg 'app.main))
     (define rendered
       (parameterize ([current-emit-config default-emit-config])
         (emit-function/result (run-pipeline main-fn default-pipeline-config))))
     (check-false
      (regexp-match? #rx"bl lib\\.pair\n    mov x1, x0\n    mov x0, x1"
                     rendered))
     (check-not-false
      (regexp-match? #px"mov x[0-9]+, x1\n    mov x1, x0\n    mov x0, x[0-9]+"
                     rendered)))

   (test-case ".call SVE MVP rejects predicate slot overflow with source locations"
     (define results
       (parse-string #<<ASM
.function lib.too-many-preds (
  in: p.a,
  in: p.b,
  in: p.c,
  in: p.d,
  in: p.e
)
entry:
  ret
.end
ASM
                     #:source "pred-overflow.asm"
                     #:syntax 'gnu
                     #:validate? #t))
     (check-equal? (parse-results-error-count results) 0)
     (check-exn
      (lambda (e)
        (and (regexp-match? #rx"pred-overflow\\.asm:1:0" (exn-message e))
             (regexp-match? #rx"no predicate slot"
                            (exn-message e))))
      (lambda ()
        (expand-inline-cfg (build-cfg (ok-items results))))))

   (test-case "multi-input parse lets .call find another module definition"
     (define caller-path (make-temporary-file "asmp-caller-~a.asm"))
     (define callee-path (make-temporary-file "asmp-callee-~a.asm"))
     (call-with-output-file caller-path
       (lambda (out)
         (display #<<ASM
.function app.main export (
  out: x.result
)
entry:
  .call lib.math.inc (x.value=x.result)
  ret
.end
ASM
                  out))
       #:exists 'truncate/replace)
     (call-with-output-file callee-path
       (lambda (out)
         (display #<<ASM
.function lib.math.inc (
  out: x.value
)
entry:
  mov x.value, #1
  ret
.end
ASM
                  out))
       #:exists 'truncate/replace)
     (define parse-result
       (parameterize ([cli:input-syntax 'gnu])
         (cli:run-parse-stage/files
          (list (path->string caller-path)
                (path->string callee-path)))))
     (check-true (pvector-empty? (cli:parse-stage-result-errors parse-result)))
     (define cfg
       (expand-inline-cfg
        (build-cfg (cli:parse-stage-result-items parse-result) 'multi-test)))
     (define main-fn (cfg-get-function-by-name cfg 'app.main))
     (check-not-false main-fn)
     (define rendered
       (parameterize ([current-emit-config default-emit-config])
         (emit-function/result (run-pipeline main-fn default-pipeline-config))))
     (check-not-false (regexp-match? #rx"bl lib\\.math\\.inc" rendered)))

   (test-case ".asmp.function accepts whitespace-separated ABI attributes"
     (define results
       (parse-gnu #<<ASM
.asmp.function gnu_vreg abi=aapcs64 export
gnu_vreg:
  mov x.tmp, x0
  add x0, x.tmp, #1
  ret
.asmp.end_function
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (define fn (car (ok-items results)))
     (check-equal? (ast-directive-kind fn) 'function)
     (check-equal? (hash-ref (ast-directive-args fn) 'abi #f) 'aapcs64)
     (check-true (hash-ref (ast-directive-args fn) 'export #f)))

   (test-case ".asmp.extern accepts per-symbol call ABI"
     (define results
       (parse-gnu #<<ASM
.asmp.extern ext_call abi=naked
caller:
  bl ext_call
  ret
.size caller, .-caller
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg (build-cfg (ok-items results)))
     (check-equal? (hash-ref (cfg-get-info cfg 'extern-abi-names (hash)) 'ext_call #f)
                   'naked))

   (test-case "GNU shifted register operand uses the existing flat AST shape"
     (define results
       (parse-gnu #<<ASM
shifted:
  add x0, x1, x2, lsl #3
  ret
.size shifted, .-shifted
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (define add-ins (car (instructions results)))
     (define ops (ast-ins-operands add-ins))
     (check-equal? (length ops) 5)
     (check-true (ast-shift? (list-ref ops 3)))
     (check-equal? (ast-shift-kind (list-ref ops 3)) 'lsl)
     (check-true (ast-imm? (list-ref ops 4)))
     (check-equal? (ast-imm-value (list-ref ops 4)) 3))

   (test-case "GNU extended register memory operand lowers to ast-mem"
     (define results
       (parse-gnu #<<ASM
load_indexed:
  ldr w10, [x3, w9, uxtw #2]
  ret
.size load_indexed, .-load_indexed
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (define ldr-ins (car (instructions results)))
     (define mem (cadr (ast-ins-operands ldr-ins)))
     (check-true (ast-mem? mem))
     (check-equal? (ast-reg-kind (ast-mem-base mem)) 'x)
     (check-equal? (ast-reg-id (ast-mem-base mem)) 3)
     (check-equal? (ast-reg-kind (ast-mem-offset mem)) 'w)
     (check-equal? (ast-reg-id (ast-mem-offset mem)) 9)
     (check-true (ast-extend? (ast-mem-extend mem)))
     (check-equal? (ast-extend-kind (ast-mem-extend mem)) 'uxtw)
     (check-equal? (ast-extend-amount (ast-mem-extend mem)) 2))

   (test-case "GNU relocation expressions lower to existing label reloc AST"
     (define results
       (parse-gnu #<<ASM
.extern extvar
reloc_user:
  adrp x0, :got:extvar
  ldr x0, [x0, :got_lo12:extvar]
  adrp x1, :pg_hi21:local_data
  add x1, x1, #:lo12:local_data
  ret
local_data:
  ret
.size reloc_user, .-reloc_user
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (define insns (instructions results))
     (define adrp-got (cadr (ast-ins-operands (list-ref insns 0))))
     (define ldr-mem (cadr (ast-ins-operands (list-ref insns 1))))
     (define adrp-page (cadr (ast-ins-operands (list-ref insns 2))))
     (define add-lo12 (list-ref (ast-ins-operands (list-ref insns 3)) 2))
     (check-equal? (ast-label-reloc adrp-got) 'GOTPAGE)
     (check-equal? (ast-label-reloc (ast-mem-offset ldr-mem)) 'GOTPAGEOFF)
     (check-equal? (ast-label-reloc adrp-page) 'PAGE)
     (check-equal? (ast-label-reloc add-lo12) 'PAGEOFF))

   (test-case "GNU data directives are preserved as module items"
     (define results
       (parse-gnu #<<ASM
.section .rodata
.globl data_msg
data_msg:
  .asciz "hello, data"
  .ascii "raw"
  .byte 1, 2, 0xff
  .byte2 0x1234
  .byte4 0x12345678, data_msg
  .byte8 0x1122334455667788, data_msg
  .byte16 1
  .byte32 1
  .word 7
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (define items (ok-items results))
     (define cfg (build-cfg items))
     (define module-items (cfg-get-info cfg 'module-items '()))
     (check-equal? (map ast-directive-kind module-items)
                   '(section global label asciz ascii byte byte2 byte4 byte8 byte16 byte32 byte4))
     (define rendered
       (parameterize ([current-emit-config default-emit-config])
         (emit-module cfg)))
     (check-not-false (regexp-match? #rx"\\.section \\.rodata" rendered))
     (check-not-false (regexp-match? #rx"data_msg:" rendered))
     (check-not-false (regexp-match? #rx"\\.asciz \"hello, data\"" rendered))
     (check-not-false (regexp-match? #rx"\\.ascii \"raw\"" rendered))
     (check-not-false (regexp-match? #rx"\\.byte 1, 2, 255" rendered))
     (check-not-false (regexp-match? #rx"\\.2byte 4660" rendered))
     (check-not-false (regexp-match? #rx"\\.4byte 305419896, data_msg" rendered))
     (check-not-false (regexp-match? #rx"\\.8byte 1234605616436508552, data_msg" rendered))
     (check-not-false (regexp-match? #rx"\\.octa 1" rendered))
     (check-not-false (regexp-match? #rx"\\.octa 1, 0" rendered))
     (check-not-false (regexp-match? #rx"\\.4byte 7" rendered)))

   (test-case "GNU .data section maps to Apple data section"
     (define results
       (parse-gnu #<<ASM
.data
.align 3
.globl runtime_flag
runtime_flag:
  .byte8 1
ASM
                  ))
     (check-equal? (parse-results-error-count results) 0)
     (define cfg (build-cfg (ok-items results)))
     (define rendered
       (parameterize ([current-emit-config apple-emit-config])
         (emit-module cfg)))
     (check-not-false (regexp-match? #rx"\\.section __DATA,__data" rendered))
     (check-not-false (regexp-match? #rx"\\.p2align 3" rendered))
     (check-not-false (regexp-match? #rx"_runtime_flag:" rendered))
     (check-not-false (regexp-match? #rx"\\.8byte 1" rendered)))

   (test-case "GNU data directives reject ambiguous scalar payloads"
     (check-equal? (parse-results-error-count (parse-gnu ".asciz\n")) 1)
     (check-equal? (parse-results-error-count (parse-gnu ".byte \"x\"\n")) 1)
     (check-equal? (parse-results-error-count (parse-gnu ".byte 256\n")) 1)
     (check-equal? (parse-results-error-count (parse-gnu ".byte4 0x100000000\n")) 1)
     (check-equal? (parse-results-error-count (parse-gnu ".word 0x100000000\n")) 1)
     (check-equal? (parse-results-error-count (parse-gnu ".byte16 data_msg\n")) 1)
     (check-equal? (parse-results-error-count (parse-gnu ".byte32 data_msg\n")) 1))

   (test-case "relocated labels emit in GNU and Apple spellings from one AST"
     (define add-ins
       (ast-ins 'add #f
                (list (ast-reg 'x 0 #f #f #f #f no-srcloc)
                      (ast-reg 'x 0 #f #f #f #f no-srcloc)
                      (ast-label 'extvar 'PAGEOFF no-srcloc))
                no-srcloc))
     (check-equal? (parameterize ([current-emit-config default-emit-config])
                     (emit-instruction add-ins))
                   "    add x0, x0, :lo12:extvar")
     (check-equal? (parameterize ([current-emit-config apple-emit-config])
                     (emit-instruction add-ins))
                   "    add x0, x0, _extvar@PAGEOFF"))

   (test-case "PAGE relocation emits as bare GNU ADRP operand"
     (define adrp-ins
       (ast-ins 'adrp #f
                (list (ast-reg 'x 0 #f #f #f #f no-srcloc)
                      (ast-label 'extvar 'PAGE no-srcloc))
                no-srcloc))
     (check-equal? (parameterize ([current-emit-config default-emit-config])
                     (emit-instruction adrp-ins))
                   "    adrp x0, extvar")
     (check-equal? (parameterize ([current-emit-config apple-emit-config])
                     (emit-instruction adrp-ins))
                   "    adrp x0, _extvar@PAGE"))

   (test-case "GNU frontend reports shared validation errors"
     (define results
       (parse-gnu #<<ASM
bad_add:
  add x0, x1
  ret
.size bad_add, .-bad_add
ASM
                  ))
     (define errors (parse-results-filter-errors results))
     (check-equal? (length errors) 1)
     (check-equal? (parse-error-kind (parse-result-parse-error (car errors)))
                   'validation))))

(module+ main
  (void (run-tests gnu-frontend-tests)))

(module+ test
  (void (run-tests gnu-frontend-tests)))
