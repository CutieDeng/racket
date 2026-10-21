#lang racket/base
;; Host-side checks for the x86 module (no x86 hardware needed):
;;   racket tests/alloc-tests.rkt
;; Parser + spec matching + register allocation on small kernels, asserting the
;; properties the SHA-256 bring-up relies on.
(require racket/list racket/match racket/string rackunit "../parse.rkt" "../spec.rkt" "../regalloc.rkt" "../emit.rkt")

(define (alloc src)
  (define items (parse-string src 'test))
  (define f (findf fn? items))
  (allocate-fn f))
(define (mapping-ref r name) (cdr (assq name (alloc-result-mapping r))))
(define (emitted r)
  (define o (open-output-string))
  (emit-module (list (alloc-result-fn r)) o)
  (get-output-string o))

;; 1. arguments are precolored by SysV position; q./d. views share one register
(let ([r (alloc "
.function f export (
  in: q.a, q.b
  out: q.r
)
  mov q.r, q.a
  add d.r, d.b
  ret
.end")])
  (check-equal? (mapping-ref r 'a) 'rdi)
  (check-equal? (mapping-ref r 'b) 'rsi)
  (check-equal? (mapping-ref r 'r) 'rax)
  (check-true (regexp-match? #rx"add eax, esi" (emitted r))))

;; 2. a vreg live across a redefinition of xmm0 (sha256rnds2's implicit operand) never lands on xmm0;
;;    a vreg whose value xmm0 merely carries may share it (the copy is then removed)
(let ([r (alloc "
.function g export (
  in: q.p
)
  movdqu xmm.keep, xmmword ptr [q.p]
  movdqa xmm.s1, xmmword ptr [q.p + 16]
  movdqa xmm.s0, xmmword ptr [q.p + 32]
  movdqa xmm0, xmm.s1
  sha256rnds2 xmm.s1, xmm.s0
  movdqa xmm0, xmm.s0
  sha256rnds2 xmm.s0, xmm.s1
  paddd xmm.s1, xmm.keep
  movdqu xmmword ptr [q.p], xmm.s1
  ret
.end")])
  (check-not-equal? (mapping-ref r 'keep) 'xmm0)
  (check-not-equal? (mapping-ref r 's0) 'xmm0)
  (check-not-equal? (mapping-ref r 's1) 'xmm0))

;; 3. a dead-by-then vreg may reuse xmm0 (liveness is instruction-level, not whole-function)
(let ([r (alloc "
.function h export (
  in: q.p
)
  movdqu xmm.t, xmmword ptr [q.p]
  paddd xmm.t, xmm.t
  movdqu xmmword ptr [q.p + 16], xmm.t
  movdqa xmm0, xmmword ptr [q.p]
  movdqa xmm.s1, xmmword ptr [q.p + 16]
  movdqa xmm.s0, xmmword ptr [q.p + 32]
  sha256rnds2 xmm.s1, xmm.s0
  movdqu xmmword ptr [q.p], xmm.s1
  ret
.end")])
  (check-equal? (mapping-ref r 't) 'xmm0))

;; 4. copies coalesce when the source dies at the copy
(let ([r (alloc "
.function c export (
  in: q.p
)
  mov q.x, qword ptr [q.p]
  mov q.y, q.x
  add q.y, 1
  mov qword ptr [q.p], q.y
  ret
.end")])
  (check-equal? (mapping-ref r 'x) (mapping-ref r 'y))
  ;; the coalesced copy is gone: only one mov from memory, one add, one store remain
  (check-equal? (length (filter instr? (fn-body (alloc-result-fn r)))) 4))

;; 5. out of registers is an error that names the pressure point
(check-exn #rx"out of vec registers.*17 vec registers live"
  (lambda ()
    (alloc (string-append "
.function big export (
  in: q.p
)
"
      (string-join (for/list ([i 17]) (format "  movdqu xmm.v~a, xmmword ptr [q.p + ~a]" i (* 16 i))) "\n")
      "\n"
      (string-join (for/list ([i 17]) (format "  movdqu xmmword ptr [q.p + ~a], xmm.v~a" (* 16 i) i)) "\n")
      "\n  ret\n.end"))))

;; 6. loop liveness: a value defined before a loop and used after it stays allocated across the body
(let ([r (alloc "
.function l export (
  in: q.p, q.n
)
  movdqa xmm.acc, xmmword ptr [q.p]
  pxor xmm.zero, xmm.zero
top:
  movdqu xmm.x, xmmword ptr [q.p]
  paddd xmm.acc, xmm.x
  add q.p, 16
  sub q.n, 1
  jnz top
  paddd xmm.acc, xmm.zero
  movdqu xmmword ptr [q.p], xmm.acc
  ret
.end")])
  (check-not-equal? (mapping-ref r 'zero) (mapping-ref r 'x))
  (check-not-equal? (mapping-ref r 'acc) (mapping-ref r 'x)))

;; 7. width views select the form: a 32-bit vreg view must not match a 64-bit-only operand
(check-false (match-form 'movq (list '(vreg gpr a d) '(vreg xmm b xmm))))
(check-true (and (match-form 'movq (list '(vreg gpr a q) '(vreg xmm b xmm))) #t))

(displayln "alloc-tests: all checks passed")

;; 8. .simd avx512 widens the vector pool to 32; without it the same kernel is out of registers
(define (wide-kernel simd)
  (string-append "
.function w export (
  in: q.p
)
" (if simd "  .simd avx512\n" "")
    (string-join (for/list ([i 24]) (format "  vmovdqu64 zmm.v~a, zmmword ptr [q.p + ~a]" i (* 64 i))) "\n") "\n"
    (string-join (for/list ([i 24]) (format "  vmovdqu64 zmmword ptr [q.p + ~a], zmm.v~a" (* 64 i) i)) "\n")
    "\n  ret\n.end"))
(check-exn #rx"out of vec registers" (lambda () (alloc (wide-kernel #f))))
(let ([r (alloc (wide-kernel #t))])
  (check-true (and (for/or ([m (alloc-result-mapping r)]) (memq (cdr m) '(xmm16 xmm17 xmm18 xmm19 xmm20 xmm21 xmm22 xmm23))) #t)))
(check-true (operands-need-evex? '((reg zmm16) (reg zmm1))))
(check-false (operands-need-evex? '((reg zmm15) (reg zmm1))))

(displayln "alloc-tests: simd checks passed")

;; 9. .frame N allocates stack scratch after the pushes and frees it before every ret; rsp stays
;;    16-byte aligned in the body (return address + pushes + frame)
(let* ([r (alloc "
.function fr export (
  in: q.p
)
  .frame 24
  mov q.x, qword ptr [q.p]
  mov qword ptr [rsp + 8], q.x
  mov q.y, qword ptr [rsp + 8]
  add q.y, qword ptr [rsp]
  mov qword ptr [q.p], q.y
  ret
.end")]
       [text (emitted r)])
  ;; no callee-saved pushes here: return address (8) + frame must be a multiple of 16 -> 24 rounds to 32, +8 = 40
  (check-true (regexp-match? #rx"sub     rsp, 40\n" text))
  (check-true (regexp-match? #rx"add     rsp, 40\n        ret" text)))
(displayln "alloc-tests: frame checks passed")

;; 10. .macro: parameter substitution, per-expansion labels (\@), nesting, and .for inside a body
(let* ([r (alloc "
.macro ADD3 d, a, b
  mov \\d, \\a
  add \\d, \\b
.endm
.macro CLAMP x
  test \\x, \\x
  jns ok\\@
  neg \\x
ok\\@:
.endm
.macro TWICE d, a, b
  ADD3(\\d, \\a, \\b)
  .for k, 0, 2
  CLAMP(\\d)
  .endfor
.endm
.function m export (
  in: q.a, q.b
  out: q.r
)
  TWICE(q.r, q.a, qword ptr [q.b + 8])
  ret
.end")]
       [body (filter instr? (fn-body (alloc-result-fn r)))])
  ;; mov, add, then two CLAMP expansions of three instructions each
  (check-equal? (length body) 8)
  (check-equal? (map instr-mnemonic body) '(mov add test jns neg test jns neg))
  (check-equal? (length (filter label? (fn-body (alloc-result-fn r)))) 2))
(check-exn #rx"expects 2 argument" (lambda () (alloc "
.macro P a, b
  mov \\a, \\b
.endm
.function e export (
  in: q.a
)
  P(q.a)
  ret
.end")))
(displayln "alloc-tests: macro checks passed")

;; 11. ${expr} is evaluated outside .for as well (macros with arithmetic on their arguments)
(let* ([r (alloc "
.macro LOADK d, i
  mov \\d, qword ptr [q.p + ${8 * (\\i + 1)}]
.endm
.function tl export (
  in: q.p
  out: q.r
)
  LOADK(q.r, 2)
  add q.r, ${1 << 4}
  ret
.end")]
       [text (emitted r)])
  (check-true (regexp-match? #rx"\\[rdi \\+ 24\\]" text))
  (check-true (regexp-match? #rx"add     rax, 0x10|add rax, 0x10" text)))
(displayln "alloc-tests: top-level expression checks passed")

;; 12. xor r, r is a definition, not a use: an out register zeroed at one exit is not live from entry
(let ([r (alloc "
.function zr export (
  in: q.p
  out: q.ret
)
  mov q.a, qword ptr [q.p]
  test q.a, q.a
  jz other
  xor d.ret, d.ret
  ret
other:
  mov d.ret, 2
  ret
.end")])
  (check-not-equal? (mapping-ref r 'a) 'rax))
(displayln "alloc-tests: zeroing idiom checks passed")
