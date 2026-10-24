#lang racket/base
;; GAS Intel-syntax ELF writer for the x86-64 module. Produces a self-guarded .S:
;; the whole body sits under #if defined(__x86_64__) && defined(__ELF__) (SysV ABI,
;; ELF directives) so the file is inert on other targets, the same convention as
;; the AArch64 kernels' platform guards; non-ELF x86-64 keeps the C/intrinsics path.
(require racket/string racket/list racket/match "parse.rkt" "spec.rkt")
(provide emit-module operand->text instr->text)

;; function whose body is being emitted: local labels print as .L<fn>_<label>
(define current-fn (make-parameter #f))
;; byte offset of the allocator's spill slots from rsp (above the .frame area)
(define current-spill-base (make-parameter 0))
(define (label->text n) (if (current-fn) (format ".L~a_~a" (current-fn) n) (symbol->string n)))

(define callee-saved '(rbx rbp r12 r13 r14 r15))

(define (decor->text d)
  (match d
    [(list 'z) "{z}"]
    [(list 'bcst n) (format "{1to~a}" n)]
    [(list 'mask r) (format "{~a}" (reg->text r))]
    [(list 'raw s) s]))
(define (decors->text ds) (apply string-append (map decor->text ds)))
(define (reg->text r)
  (match r
    [(list 'reg n) (symbol->string n)]
    [(list 'reg n decor) (string-append (symbol->string n) (decors->text decor))]
    [(list 'vreg cls name view) (error 'x86-emit "unallocated virtual register ~a.~a" view name)]
    [(list 'vreg cls name view decor) (error 'x86-emit "unallocated virtual register ~a.~a" view name)]
    [_ (error 'x86-emit "bad register ~s" r)]))

(define (operand->text u)
  (match u
    [(list 'imm n) (if (< n 0) (format "-0x~a" (number->string (- n) 16)) (format "0x~a" (number->string n 16)))]
    [(list 'label n) (label->text n)]
    [(list 'mem base index scale disp0 sym0 size decor)
     ;; spill slots: [rsp + __spill + off] -> [rsp + (base + off)]
     (define-values (disp sym) (if (eq? sym0 '__spill) (values (+ disp0 (current-spill-base)) #f) (values disp0 sym0)))
     (define parts
       (append (if base (list (reg->text base)) '())
               (if index (list (if (= scale 1) (reg->text index) (format "~a*~a" (reg->text index) scale))) '())
               (if sym (list (symbol->string sym)) '())
               (if (zero? disp) '() (list (if (< disp 0) (format "-~a" (- disp)) (number->string disp))))))
     (define inner (string-join parts " + "))
     (string-append (if size (format "~a ptr " size) "")
                    "[" (regexp-replace* #rx"\\+ -" inner "- ") "]"
                    (decors->text decor))]
    [(cons 'reg _) (reg->text u)]
    [(cons 'vreg _) (reg->text u)]
    [_ (error 'x86-emit "bad operand ~s" u)]))

(define (instr->text i)
  (define mn (symbol->string (instr-mnemonic i)))
  (if (null? (instr-ops i))
      mn
      (string-append mn " " (string-join (map operand->text (instr-ops i)) ", "))))

(define (fn-used-regs f)
  (define s (make-hasheq))
  (for ([x (fn-body f)] #:when (instr? x))
    (let walk ([ops (instr-ops x)])
      (for ([u ops])
        (match u
          [(list 'reg n) (hash-set! s n #t)]
          [(list 'reg n _) (hash-set! s n #t)]
          [(list 'mem base index _ _ _ _ _) (walk (filter values (list base index)))]
          [_ (void)]))))
  s)

(define (gpr-base n)
  ;; map any view name to its 64-bit register name
  (define i (reg-name-info n))
  (and i (eq? (car i) 'gpr) (list-ref gpr64-names (caddr i))))

(define (emit-function f out)
  (define name (symbol->string (fn-name f)))
  (define used (fn-used-regs f))
  (define saves
    (if (eq? (fn-save f) 'none) '()
        (filter (lambda (r) (for/or ([(n _) used]) (eq? (gpr-base n) r))) callee-saved)))
  (define uses-wide? (for/or ([(n _) used]) (memq (reg-name->class n) '(ymm zmm))))
  (fprintf out "\n")
  (when (fn-export? f)
    (fprintf out "        .globl  ~a\n" name)
    (fprintf out "        .type   ~a, @function\n" name))
  (fprintf out "        .p2align 5\n~a:\n" name)
  ;; prologue: callee-saved pushes, then the .frame scratch; the frame size is rounded so that
  ;; rsp is 16-byte aligned in the body (return address + pushes + frame)
  (for ([r saves]) (fprintf out "        push    ~a\n" r))
  (define user-frame (let ([v (fn-frame f)]) (if (number? v) v 0)))   ; the struct's #:auto fields share one auto-value
  (define spill-bytes (let ([v (fn-spill f)]) (if (number? v) v 0)))
  (define spill-base (if (> spill-bytes 0) (* 64 (quotient (+ user-frame 63) 64)) 0))
  (define has-call? (for/or ([x (fn-body f)]) (and (instr? x) (eq? (instr-mnemonic x) 'call))))
  (define frame
    (let ([n (+ (if (> spill-bytes 0) spill-base user-frame) spill-bytes)])
      (if (and (zero? n) (not has-call?)) 0
          (let* ([n16 (* 16 (quotient (+ n 15) 16))]
                 [odd? (odd? (add1 (length saves)))])   ; return address + pushes = odd number of qwords?
            (+ n16 (if odd? 8 0))))))
  (when (> frame 0) (fprintf out "        sub     rsp, ~a\n" frame))
  (parameterize ([current-fn name] [current-spill-base spill-base])
  (for ([x (fn-body f)])
    (cond
      [(label? x) (fprintf out "~a:\n" (label->text (label-name x)))]
      [(eq? (instr-mnemonic x) '.directive) (fprintf out "        ~a\n" (instr-text x))]
      [(and (eq? (instr-mnemonic x) 'call) (pair? (instr-ops x)) (eq? (car (car (instr-ops x))) 'label))
       (fprintf out "        call    ~a@PLT\n" (cadr (car (instr-ops x))))]
      [(eq? (instr-mnemonic x) 'ret)
       (when uses-wide? (fprintf out "        vzeroupper\n"))
       (when (> frame 0) (fprintf out "        add     rsp, ~a\n" frame))
       (for ([r (reverse saves)]) (fprintf out "        pop     ~a\n" r))
       (fprintf out "        ret\n")]
      [else (fprintf out "        ~a\n" (instr->text x))])))
  (fprintf out "        .size   ~a, .-~a\n" name name))

(define (emit-rodata r out)
  (fprintf out "\n        .section .rodata\n        .p2align ~a\n~a:\n" (integer-length (sub1 (rodata-align r))) (rodata-name r))
  (for ([l (rodata-lines r)]) (fprintf out "        ~a\n" l))
  (fprintf out "        .text\n"))

(define (emit-module items out #:provenance [prov ""] #:guard [guard "defined(__x86_64__) && defined(__ELF__)"])
  (fprintf out "/* Generated by rktasm/x86 from the kernel DSL; do not edit. ~a */\n" prov)
  (fprintf out "#if ~a\n        .intel_syntax noprefix\n        .text\n" guard)
  (for ([x items])
    (cond [(fn? x) (emit-function x out)]
          [(rodata? x) (emit-rodata x out)]))
  (fprintf out "\n        .section .note.GNU-stack,\"\",@progbits\n#endif /* ~a */\n" guard))
