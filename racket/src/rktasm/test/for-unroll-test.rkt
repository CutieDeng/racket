#lang racket

;; ============================================================
;; test/for-unroll-test.rkt — compile-time `.for` loop unrolling
;; ============================================================
;;
;; Covers parser/unroll.rkt: the pre-parser line-level expander that turns
;;   .for <var>, <lo>, <hi> ... .endfor
;; into repeated bodies with `${expr}` compile-time integer substitution.
;; `${...}` (rather than a `\`-sigil) so it coexists with AArch64 SIMD
;; register-list syntax `{ v0.4s, ... }`. Loops nest; a `.for`-free source is
;; returned unchanged (true no-op). End-to-end byte-identical assembled output
;; (hand-unrolled vs `.for`) is additionally verified via cli/as.rkt in
;; asm/regen.sh territory; here we pin the expander semantics directly.

(require rackunit
         rackunit/text-ui
         "../parser/unroll.rkt")

;; expand a list of source line strings -> list of expanded line strings
;; (a "line" is (list text line-number prov); car is the text)
(define (exp strs)
  (map car (expand-for-lines
            (for/list ([s (in-list strs)] [i (in-naturals 1)]) (list s i #f))
            'test)))

(define unroll-tests
  (test-suite
   "in-.asm .for unroll"

   (test-case "basic index concat + arithmetic offset"
     (check-equal?
      (exp '(".for i, 0, 4" "  ldr x.a${i}, [x.ap, #${8*i}]" ".endfor"))
      '("  ldr x.a0, [x.ap, #0]"
        "  ldr x.a1, [x.ap, #8]"
        "  ldr x.a2, [x.ap, #16]"
        "  ldr x.a3, [x.ap, #24]")))

   (test-case "coexists with AArch64 SIMD register lists"
     ;; bare { } stays a register list; ${i} expands inside it
     (check-equal?
      (exp '(".for i, 0, 3" "  ld1r { v.ln${i}.2d }, [x.st], #8" ".endfor"))
      '("  ld1r { v.ln0.2d }, [x.st], #8"
        "  ld1r { v.ln1.2d }, [x.st], #8"
        "  ld1r { v.ln2.2d }, [x.st], #8")))

   (test-case "lone $ (not followed by {) passes through literally"
     (check-equal?
      (exp '(".for i, 0, 2" "L$tag${i}:" ".endfor"))
      '("L$tag0:" "L$tag1:")))

   (test-case "no-op identity for .for-free source (string + braces untouched)"
     (check-equal?
      (exp '("  mov x0, x1" "  ld1 { v0.4s }, [x0]" "  .asciz \"a\\nb\"" "  ret"))
      '("  mov x0, x1" "  ld1 { v0.4s }, [x0]" "  .asciz \"a\\nb\"" "  ret")))

   (test-case "expr: additive/shift precedence + hex literal"
     ;; 0x10 + k << 2  ==  (16 + k) << 2   (C: shift below additive)
     (check-equal?
      (exp '(".for k, 0, 2" "  mov x0, #${0x10 + k << 2}" ".endfor"))
      '("  mov x0, #64" "  mov x0, #68")))

   (test-case "expr: multiplicative / % / integer div precedence"
     (check-equal?
      (exp '(".for i, 1, 3" "x #${1 + i * 3}" "y #${7 % i}" "z #${8 / i}" ".endfor"))
      ;; i=1: 4,0,8   i=2: 7,1,4
      '("x #4" "y #0" "z #8" "x #7" "y #1" "z #4")))

   (test-case "expr: unary minus + parens"
     (check-equal?
      (exp '(".for i, 0, 2" "v #${-(i+1)*2}" ".endfor"))
      '("v #-2" "v #-4")))

   ;; ---- conditionals (Rust-style if/else) + comparisons + logicals ----
   (test-case "if/else: special-case the last iteration"
     (check-equal?
      (exp '(".for i, 0, 8" "o #${if i == 7 { 0 } else { 8*i }}" ".endfor"))
      '("o #0" "o #8" "o #16" "o #24" "o #32" "o #40" "o #48" "o #0")))

   (test-case "else if chain (first / mid / last)"
     (check-equal?
      (exp '(".for i, 0, 3" "c #${if i==0 { 1 } else if i==2 { 4 } else { 2 }}" ".endfor"))
      '("c #1" "c #2" "c #4")))

   (test-case "logical || / && in condition"
     (check-equal?
      (exp '(".for i, 0, 4" "m #${if i==0 || i==3 { 16 } else { 8 }}" ".endfor"))
      '("m #16" "m #8" "m #8" "m #16")))

   (test-case "comparisons yield 1/0; unary !"
     (check-equal?
      (exp '(".for i, 0, 3" "p ${i<=1} ${i!=1} ${!(i==0)}" ".endfor"))
      '("p 1 1 0" "p 1 0 1" "p 0 1 1")))

   (test-case "short-circuit: dead branch (8/i at i=0) never evaluated -> no div0"
     (check-equal?
      (exp '(".for i, 0, 3" "s #${if i==0 { 0 } else { 8/i }}" ".endfor"))
      '("s #0" "s #8" "s #4")))

   (test-case "short-circuit &&: 8/i skipped when i==0"
     (check-equal?
      (exp '(".for i, 0, 3" "a #${i!=0 && 8/i>2}" ".endfor"))
      '("a #0" "a #1" "a #1")))

   (test-case "if nests inside arithmetic"
     (check-equal?
      (exp '(".for i, 0, 3" "n #${1 + if i==1 { 10 } else { 20 }}" ".endfor"))
      '("n #21" "n #11" "n #21")))

   (test-case "labels + cross-iteration branch"
     (check-equal?
      (exp '(".for i, 0, 3" "L${i}:" "  b L${i+1}" ".endfor"))
      '("L0:" "  b L1" "L1:" "  b L2" "L2:" "  b L3")))

   (test-case "nested loops: inner body sees enclosing var"
     (check-equal?
      (exp '(".for i, 0, 2" ".for j, 0, 2" "m #${i*2+j}" ".endfor" ".endfor"))
      '("m #0" "m #1" "m #2" "m #3")))

   (test-case "loop bound uses enclosing var (triangular)"
     (check-equal?
      (exp '(".for i, 0, 3" ".for j, 0, i" "p #${j}" ".endfor" ".endfor"))
      ;; i=0: none  i=1: j=0  i=2: j=0,1
      '("p #0" "p #0" "p #1")))

   (test-case "zero-iteration range emits nothing, surrounding lines intact"
     (check-equal?
      (exp '("a" ".for i, 3, 3" "GONE" ".endfor" "b"))
      '("a" "b")))

   ;; ---- error handling: clear errors, never silent wrong expansion ----
   (test-case "unmatched .endfor errors"
     (check-exn exn:fail? (lambda () (exp '(".endfor")))))
   (test-case "missing .endfor errors"
     (check-exn exn:fail? (lambda () (exp '(".for i, 0, 2" "x")))))
   (test-case "unknown loop var errors"
     (check-exn exn:fail? (lambda () (exp '(".for i, 0, 2" "y #${k}" ".endfor")))))
   (test-case "wrong .for arity errors"
     (check-exn exn:fail? (lambda () (exp '(".for i, 0" "x" ".endfor")))))
   (test-case "unbalanced ${ errors"
     (check-exn exn:fail? (lambda () (exp '(".for i, 0, 2" "x #${8*i" ".endfor")))))
   (test-case "malformed expr errors"
     (check-exn exn:fail? (lambda () (exp '(".for i, 0, 2" "x #${2 *}" ".endfor")))))
   (test-case "if without else: lazy — fine when the else-less path is never hit"
     (check-equal? (exp '(".for i, 0, 1" "x #${if i==0 { 1 }}" ".endfor")) '("x #1")))
   (test-case "if without else: errors only when evaluated with cond false"
     (check-exn exn:fail? (lambda () (exp '(".for i, 0, 2" "x #${if i==0 { 1 }}" ".endfor")))))))

(run-tests unroll-tests)
