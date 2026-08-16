;; Generic-width CIOS Montgomery multiply (AArch64), hand-scheduled in rktasm.
;; r = a*b*R^-1 mod m, R = 2^(64*nl), for an ARBITRARY odd modulus m (the
;; generic-prime path the NIST fast-reduction kernels don't cover). Used by the
;; brainpool curves (nl = 4/6/8) via rktcrypto_ecc.c's montmul. Bit-exact with
;; the portable montmul; gate: asm/tests/test_mont_cios.c.
;;
;; void mont_cios_asm(u64 *r, const u64 *a, const u64 *b, const u64 *m,
;;                    u64 n0, intptr_t nl, u64 *t);  t = caller scratch, nl+2 words.
.function mont_cios_asm export (
  in: x.r, x.a, x.b, x.m, x.n0, x.nl, x.t
)
entry:
  .save all
  ;; zero t[0..nl+1]
  add x.nl1, x.nl, #1               ; nl+1 (last t index)
  mov x.j, #0
zloop:
  str xzr, [x.t, x.j, lsl #3]
  add x.j, x.j, #1
  cmp x.j, x.nl1
  b.le zloop

  mov x.i, #0
outer:
  ldr x.bi, [x.b, x.i, lsl #3]      ; b[i]
  ;; ---- MAC: t += a * b[i] ----
  mov x.c, #0
  mov x.j, #0
mac:
  ldr x.aj, [x.a, x.j, lsl #3]
  ldr x.tj, [x.t, x.j, lsl #3]
  mul x.lo, x.aj, x.bi
  umulh x.hi, x.aj, x.bi
  adds x.lo, x.lo, x.tj
  adc x.hi, x.hi, xzr
  adds x.lo, x.lo, x.c
  adc x.c, x.hi, xzr
  str x.lo, [x.t, x.j, lsl #3]
  add x.j, x.j, #1
  cmp x.j, x.nl
  b.lt mac
  ;; t[nl] += c;  t[nl+1] = carry
  ldr x.tn, [x.t, x.nl, lsl #3]
  adds x.tn, x.tn, x.c
  str x.tn, [x.t, x.nl, lsl #3]
  cset x.cy, cs
  str x.cy, [x.t, x.nl1, lsl #3]
  ;; ---- Montgomery reduce one word ----
  ldr x.t0, [x.t]
  mul x.mm, x.t0, x.n0
  ldr x.m0, [x.m]
  mul x.lo, x.mm, x.m0
  umulh x.cc, x.mm, x.m0
  adds x.lo, x.lo, x.t0             ; low is 0 by construction; produces carry
  adc x.cc, x.cc, xzr
  mov x.j, #1
red:
  ldr x.mj, [x.m, x.j, lsl #3]
  ldr x.tj, [x.t, x.j, lsl #3]
  mul x.lo, x.mm, x.mj
  umulh x.hi, x.mm, x.mj
  adds x.lo, x.lo, x.tj
  adc x.hi, x.hi, xzr
  adds x.lo, x.lo, x.cc
  adc x.cc, x.hi, xzr
  sub x.jm1, x.j, #1
  str x.lo, [x.t, x.jm1, lsl #3]
  add x.j, x.j, #1
  cmp x.j, x.nl
  b.lt red
  ;; t[nl-1] = t[nl] + cc;  t[nl] = t[nl+1] + carry
  ldr x.tn, [x.t, x.nl, lsl #3]
  adds x.tn, x.tn, x.cc
  sub x.nlm1, x.nl, #1
  str x.tn, [x.t, x.nlm1, lsl #3]
  cset x.cy2, cs
  ldr x.tn1, [x.t, x.nl1, lsl #3]
  add x.tn1, x.tn1, x.cy2
  str x.tn1, [x.t, x.nl, lsl #3]

  add x.i, x.i, #1
  cmp x.i, x.nl
  b.lt outer

  ;; ---- final conditional subtract: r = (t >= m) ? t-m : t ----
  ;; tmp = t - m into r.  NOTE: the loop's `cmp x.j,x.nl` clobbers NZCV every
  ;; iteration, so we cannot carry the borrow in the flag (no sbcs chain) — the
  ;; borrow lives in x.bor.  Each limb borrows at most once across the two subs.
  mov x.j, #0
  mov x.bor, #0
sub1:
  ldr x.tj, [x.t, x.j, lsl #3]
  ldr x.mj, [x.m, x.j, lsl #3]
  subs x.d, x.tj, x.mj
  cset x.b1, cc                     ; cc = borrow out of t-m
  subs x.d, x.d, x.bor
  cset x.b2, cc                     ; cc = borrow out of -bor
  orr x.bor, x.b1, x.b2             ; new borrow (b1,b2 never both 1)
  str x.d, [x.r, x.j, lsl #3]
  add x.j, x.j, #1
  cmp x.j, x.nl
  b.lt sub1
  ;; if t[nl] != 0 (overflow limb set), t definitely >= m -> force keep tmp
  ldr x.tn, [x.t, x.nl, lsl #3]
  cmp x.tn, #0
  csel x.bor, xzr, x.bor, ne        ; t[nl]!=0 -> bor=0 (keep tmp); else keep bor
  ;; bor==0 (t>=m) keep r (=t-m); bor==1 (t<m) copy t back over r
  cbz x.bor, done
  mov x.j, #0
cpy:
  ldr x.tj, [x.t, x.j, lsl #3]
  str x.tj, [x.r, x.j, lsl #3]
  add x.j, x.j, #1
  cmp x.j, x.nl
  b.lt cpy
done:
  .restore all
  ret
.end
