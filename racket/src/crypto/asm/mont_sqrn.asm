// GENERATED (adapted from mont_mul.asm) -- do not edit by hand.
// Batched Montgomery squaring mod ctx: v <- v^2, repeated `rep` times, keeping
// the running value register-resident across iterations (one prologue for the
// whole run, no store/reload between squarings) -- OpenSSL ord_sqr_mont's batching
// trick. ABI: x0=r, x1=a, x2=rep(>=1), x3=ctx. `.save all` for callee-saved GPRs.
.function mont_sqrn_asm export (
  in: x.r, x.a, x.rep, x.ctx
)
entry:
  .save all
  ldr x.v0, [x.a, #0]
  ldr x.v1, [x.a, #8]
  ldr x.v2, [x.a, #16]
  ldr x.v3, [x.a, #24]
  ldr x.m0, [x.ctx, #0]
  ldr x.m1, [x.ctx, #8]
  ldr x.m2, [x.ctx, #16]
  ldr x.m3, [x.ctx, #24]
  ldr x.n0, [x.ctx, #32]
sqloop:
  // b[0]
  mul x.acc0, x.v0, x.v0
  mul x.acc1, x.v1, x.v0
  mul x.acc2, x.v2, x.v0
  mul x.acc3, x.v3, x.v0
  umulh x.p0, x.v0, x.v0
  umulh x.p1, x.v1, x.v0
  umulh x.p2, x.v2, x.v0
  umulh x.p3, x.v3, x.v0
  adds x.acc1, x.acc1, x.p0
  adcs x.acc2, x.acc2, x.p1
  adcs x.acc3, x.acc3, x.p2
  adc  x.acc4, xzr, x.p3
  mov  x.acc5, xzr
  mul x.mm, x.acc0, x.n0
  mul x.p0, x.mm, x.m0
  mul x.p1, x.mm, x.m1
  mul x.p2, x.mm, x.m2
  mul x.p3, x.mm, x.m3
  adds x.acc0, x.acc0, x.p0
  adcs x.acc1, x.acc1, x.p1
  adcs x.acc2, x.acc2, x.p2
  adcs x.acc3, x.acc3, x.p3
  adcs x.acc4, x.acc4, xzr
  adc  x.acc5, x.acc5, xzr
  umulh x.p0, x.mm, x.m0
  umulh x.p1, x.mm, x.m1
  umulh x.p2, x.mm, x.m2
  umulh x.p3, x.mm, x.m3
  adds x.acc0, x.acc1, x.p0
  adcs x.acc1, x.acc2, x.p1
  adcs x.acc2, x.acc3, x.p2
  adcs x.acc3, x.acc4, x.p3
  adc  x.acc4, x.acc5, xzr
  // b[1]
  mul x.p0, x.v0, x.v1
  mul x.p1, x.v1, x.v1
  mul x.p2, x.v2, x.v1
  mul x.p3, x.v3, x.v1
  adds x.acc0, x.acc0, x.p0
  adcs x.acc1, x.acc1, x.p1
  adcs x.acc2, x.acc2, x.p2
  adcs x.acc3, x.acc3, x.p3
  adc  x.acc4, x.acc4, xzr
  umulh x.p0, x.v0, x.v1
  umulh x.p1, x.v1, x.v1
  umulh x.p2, x.v2, x.v1
  umulh x.p3, x.v3, x.v1
  adds x.acc1, x.acc1, x.p0
  adcs x.acc2, x.acc2, x.p1
  adcs x.acc3, x.acc3, x.p2
  adcs x.acc4, x.acc4, x.p3
  adc  x.acc5, xzr, xzr
  mul x.mm, x.acc0, x.n0
  mul x.p0, x.mm, x.m0
  mul x.p1, x.mm, x.m1
  mul x.p2, x.mm, x.m2
  mul x.p3, x.mm, x.m3
  adds x.acc0, x.acc0, x.p0
  adcs x.acc1, x.acc1, x.p1
  adcs x.acc2, x.acc2, x.p2
  adcs x.acc3, x.acc3, x.p3
  adcs x.acc4, x.acc4, xzr
  adc  x.acc5, x.acc5, xzr
  umulh x.p0, x.mm, x.m0
  umulh x.p1, x.mm, x.m1
  umulh x.p2, x.mm, x.m2
  umulh x.p3, x.mm, x.m3
  adds x.acc0, x.acc1, x.p0
  adcs x.acc1, x.acc2, x.p1
  adcs x.acc2, x.acc3, x.p2
  adcs x.acc3, x.acc4, x.p3
  adc  x.acc4, x.acc5, xzr
  // b[2]
  mul x.p0, x.v0, x.v2
  mul x.p1, x.v1, x.v2
  mul x.p2, x.v2, x.v2
  mul x.p3, x.v3, x.v2
  adds x.acc0, x.acc0, x.p0
  adcs x.acc1, x.acc1, x.p1
  adcs x.acc2, x.acc2, x.p2
  adcs x.acc3, x.acc3, x.p3
  adc  x.acc4, x.acc4, xzr
  umulh x.p0, x.v0, x.v2
  umulh x.p1, x.v1, x.v2
  umulh x.p2, x.v2, x.v2
  umulh x.p3, x.v3, x.v2
  adds x.acc1, x.acc1, x.p0
  adcs x.acc2, x.acc2, x.p1
  adcs x.acc3, x.acc3, x.p2
  adcs x.acc4, x.acc4, x.p3
  adc  x.acc5, xzr, xzr
  mul x.mm, x.acc0, x.n0
  mul x.p0, x.mm, x.m0
  mul x.p1, x.mm, x.m1
  mul x.p2, x.mm, x.m2
  mul x.p3, x.mm, x.m3
  adds x.acc0, x.acc0, x.p0
  adcs x.acc1, x.acc1, x.p1
  adcs x.acc2, x.acc2, x.p2
  adcs x.acc3, x.acc3, x.p3
  adcs x.acc4, x.acc4, xzr
  adc  x.acc5, x.acc5, xzr
  umulh x.p0, x.mm, x.m0
  umulh x.p1, x.mm, x.m1
  umulh x.p2, x.mm, x.m2
  umulh x.p3, x.mm, x.m3
  adds x.acc0, x.acc1, x.p0
  adcs x.acc1, x.acc2, x.p1
  adcs x.acc2, x.acc3, x.p2
  adcs x.acc3, x.acc4, x.p3
  adc  x.acc4, x.acc5, xzr
  // b[3]
  mul x.p0, x.v0, x.v3
  mul x.p1, x.v1, x.v3
  mul x.p2, x.v2, x.v3
  mul x.p3, x.v3, x.v3
  adds x.acc0, x.acc0, x.p0
  adcs x.acc1, x.acc1, x.p1
  adcs x.acc2, x.acc2, x.p2
  adcs x.acc3, x.acc3, x.p3
  adc  x.acc4, x.acc4, xzr
  umulh x.p0, x.v0, x.v3
  umulh x.p1, x.v1, x.v3
  umulh x.p2, x.v2, x.v3
  umulh x.p3, x.v3, x.v3
  adds x.acc1, x.acc1, x.p0
  adcs x.acc2, x.acc2, x.p1
  adcs x.acc3, x.acc3, x.p2
  adcs x.acc4, x.acc4, x.p3
  adc  x.acc5, xzr, xzr
  mul x.mm, x.acc0, x.n0
  mul x.p0, x.mm, x.m0
  mul x.p1, x.mm, x.m1
  mul x.p2, x.mm, x.m2
  mul x.p3, x.mm, x.m3
  adds x.acc0, x.acc0, x.p0
  adcs x.acc1, x.acc1, x.p1
  adcs x.acc2, x.acc2, x.p2
  adcs x.acc3, x.acc3, x.p3
  adcs x.acc4, x.acc4, xzr
  adc  x.acc5, x.acc5, xzr
  umulh x.p0, x.mm, x.m0
  umulh x.p1, x.mm, x.m1
  umulh x.p2, x.mm, x.m2
  umulh x.p3, x.mm, x.m3
  adds x.acc0, x.acc1, x.p0
  adcs x.acc1, x.acc2, x.p1
  adcs x.acc2, x.acc3, x.p2
  adcs x.acc3, x.acc4, x.p3
  adc  x.acc4, x.acc5, xzr
  subs x.p0, x.acc0, x.m0
  sbcs x.p1, x.acc1, x.m1
  sbcs x.p2, x.acc2, x.m2
  sbcs x.p3, x.acc3, x.m3
  sbcs xzr,  x.acc4, xzr
  csel x.o0, x.p0, x.acc0, cs
  csel x.o1, x.p1, x.acc1, cs
  csel x.o2, x.p2, x.acc2, cs
  csel x.o3, x.p3, x.acc3, cs
  mov x.v0, x.o0
  mov x.v1, x.o1
  mov x.v2, x.o2
  mov x.v3, x.o3
  subs x.rep, x.rep, #1
  b.ne sqloop
  str x.v0, [x.r, #0]
  str x.v1, [x.r, #8]
  str x.v2, [x.r, #16]
  str x.v3, [x.r, #24]
  .restore all
  ret
.end
