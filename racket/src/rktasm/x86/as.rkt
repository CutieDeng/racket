#lang racket/base
;; rktasm/x86 driver: parse -> validate against the XED-derived spec -> emit GAS Intel .S
;;   racket as.rkt [-o out.S] [--roundtrip] [--dump-usedef] in.asm
;; --roundtrip assembles the output for x86_64-linux with clang (no execution) and
;; checks that llvm-objdump reads back the same mnemonic sequence.
(require racket/cmdline racket/string racket/list racket/match racket/port racket/system racket/file racket/path
         "parse.rkt" "spec.rkt" "emit.rkt")

(define out-path (make-parameter #f))
(define roundtrip? (make-parameter #f))
(define dump-usedef? (make-parameter #f))
(define in-path
  (command-line
   #:once-each
   [("-o") file "output .S path" (out-path file)]
   [("--roundtrip") "assemble with clang --target=x86_64-unknown-linux-gnu and compare disassembly" (roundtrip? #t)]
   [("--dump-usedef") "print the use/def of every instruction" (dump-usedef? #t)]
   #:args (input) input))

(define items (parse-file in-path))

;; ---- validation: every instruction must match a form; record use/def
(define errors 0)
(define (err line fmt . args)
  (set! errors (add1 errors))
  (eprintf "~a:~a: ~a\n" in-path line (apply format fmt args)))
(define jumps '(jmp jo jno jb jc jnae jae jnb jnc je jz jne jnz jbe jna ja jnbe js jns jp jpe jnp jpo jl jnge jge jnl jle jng jg jnle jrcxz jecxz loop loope loopne call))
(for ([it items] #:when (fn? it))
  (define labels (for/list ([x (fn-body it)] #:when (label? x)) (label-name x)))
  (for ([x (fn-body it)] #:when (and (instr? x) (not (eq? (instr-mnemonic x) '.directive))))
    (define mn (instr-mnemonic x))
    (define ops (instr-ops x))
    (cond
      [(and (memq mn jumps) (= 1 (length ops)) (eq? (car (car ops)) 'label))
       (unless (memq (cadr (car ops)) labels) (err (instr-line x) "unknown label ~a" (cadr (car ops))))]
      [(null? (spec-forms mn)) (err (instr-line x) "unknown mnemonic ~a" mn)]
      [else
       (define f (match-form mn ops))
       (cond
         [(not f) (err (instr-line x) "no operand form of ~a matches ~a" mn (instr->text x))]
         [(dump-usedef?)
          (define-values (u d fr fw) (instr-use-def f ops))
          (printf "~a: ~a | isa ~a | uses ~a defs ~a flags-r ~a flags-w ~a\n" (instr-line x) (instr->text x) (form-isa-set f)
                  (map operand->text u) (map operand->text d) fr fw)])])))
(when (> errors 0) (eprintf "~a error(s)\n" errors) (exit 1))

;; ---- emit
(define text (with-output-to-string (lambda () (emit-module items (current-output-port) #:provenance (format "source ~a" (let-values ([(b n d) (split-path in-path)]) n))))))
(cond
  [(out-path) (call-with-output-file (out-path) #:exists 'truncate (lambda (o) (display text o)))]
  [else (display text)])

;; ---- round trip
(when (roundtrip?)
  (define tmp (make-temporary-file "rktasm-x86-~a.S"))
  (define obj (path-replace-extension tmp #".o"))
  (call-with-output-file tmp #:exists 'truncate (lambda (o) (display text o)))
  (define ok (system* (find-executable-path "clang") "--target=x86_64-unknown-linux-gnu" "-c" (path->string tmp) "-o" (path->string obj)))
  (unless ok (eprintf "roundtrip: clang rejected the output\n") (exit 2))
  (define objdump (or (find-executable-path "llvm-objdump")
                      (let ([p (with-output-to-string (lambda () (system* (find-executable-path "xcrun") "--find" "llvm-objdump")))]) (string-trim p))))
  (define dis (with-output-to-string (lambda () (system* objdump "-d" "--x86-asm-syntax=intel" "--no-show-raw-insn" (path->string obj)))))
  (define got (for/list ([l (string-split dis "\n")]
                         #:when (regexp-match #px"^\\s*[0-9a-f]+:\\s+\\S" l))
                (string->symbol (cadr (regexp-match #px"^\\s*[0-9a-f]+:\\s+(\\S+)" l)))))
  (define want (for*/list ([it items] #:when (fn? it) [x (fn-body it)]
                           #:when (and (instr? x) (not (eq? (instr-mnemonic x) '.directive))))
                 (instr-mnemonic x)))
  ;; the emitter adds push/pop/vzeroupper; drop those from `got` for the comparison
  (define got* (filter (lambda (m) (not (memq m '(push pop vzeroupper)))) got))
  (define (norm m) (string->symbol (regexp-replace #rx"^(j[a-z]+)$" (symbol->string m) "jcc")))
  (define a (map norm want)) (define b (map norm got*))
  (cond
    [(equal? a b) (eprintf "roundtrip: OK (~a instructions assembled and read back)\n" (length a))]
    [else
     (eprintf "roundtrip: MISMATCH emitted ~a vs read back ~a\n" (length a) (length b))
     (for ([x a] [y b] [i (in-naturals)] #:unless (eq? x y)) (eprintf "  first difference at #~a: ~a vs ~a\n" i x y) (exit 3))
     (exit 3)])
  (delete-file tmp) (delete-file obj))
