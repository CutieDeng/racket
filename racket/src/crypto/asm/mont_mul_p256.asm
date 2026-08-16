.function mont_mul_p256 export (
  in: x.r, x.a, x.b
)
entry:
  ldr x.a0, [x.a, #0]
  ldr x.a1, [x.a, #8]
  ldr x.a2, [x.a, #16]
  ldr x.a3, [x.a, #24]
  ldr x.bi, [x.b]
  mul   x.acc0, x.a0, x.bi
  umulh x.t0,   x.a0, x.bi
  mul   x.acc1, x.a1, x.bi
  umulh x.t1,   x.a1, x.bi
  mul   x.acc2, x.a2, x.bi
  umulh x.t2,   x.a2, x.bi
  mul   x.acc3, x.a3, x.bi
  umulh x.t3,   x.a3, x.bi
  ldr   x.bi, [x.b, #8]
  adds  x.acc1, x.acc1, x.t0
  ubfm  x.t0, x.acc0, #32, #31
  adcs  x.acc2, x.acc2, x.t1
  ubfm  x.t1, x.acc0, #32, #63
  adcs  x.acc3, x.acc3, x.t2
  adc   x.acc4, xzr, x.t3
  mov   x.acc5, xzr
  subs  x.t2, x.acc0, x.t0
  sbc   x.t3, x.acc0, x.t1
  adds  x.acc0, x.acc1, x.t0
  mul   x.t0, x.a0, x.bi
  adcs  x.acc1, x.acc2, x.t1
  mul   x.t1, x.a1, x.bi
  adcs  x.acc2, x.acc3, x.t2
  mul   x.t2, x.a2, x.bi
  adcs  x.acc3, x.acc4, x.t3
  mul   x.t3, x.a3, x.bi
  adc   x.acc4, x.acc5, xzr
  adds  x.acc0, x.acc0, x.t0
  umulh x.t0, x.a0, x.bi
  adcs  x.acc1, x.acc1, x.t1
  umulh x.t1, x.a1, x.bi
  adcs  x.acc2, x.acc2, x.t2
  umulh x.t2, x.a2, x.bi
  adcs  x.acc3, x.acc3, x.t3
  umulh x.t3, x.a3, x.bi
  adc   x.acc4, x.acc4, xzr
  ldr   x.bi, [x.b, #16]
  adds  x.acc1, x.acc1, x.t0
  ubfm  x.t0, x.acc0, #32, #31
  adcs  x.acc2, x.acc2, x.t1
  ubfm  x.t1, x.acc0, #32, #63
  adcs  x.acc3, x.acc3, x.t2
  adcs  x.acc4, x.acc4, x.t3
  adc   x.acc5, xzr, xzr
  subs  x.t2, x.acc0, x.t0
  sbc   x.t3, x.acc0, x.t1
  adds  x.acc0, x.acc1, x.t0
  mul   x.t0, x.a0, x.bi
  adcs  x.acc1, x.acc2, x.t1
  mul   x.t1, x.a1, x.bi
  adcs  x.acc2, x.acc3, x.t2
  mul   x.t2, x.a2, x.bi
  adcs  x.acc3, x.acc4, x.t3
  mul   x.t3, x.a3, x.bi
  adc   x.acc4, x.acc5, xzr
  adds  x.acc0, x.acc0, x.t0
  umulh x.t0, x.a0, x.bi
  adcs  x.acc1, x.acc1, x.t1
  umulh x.t1, x.a1, x.bi
  adcs  x.acc2, x.acc2, x.t2
  umulh x.t2, x.a2, x.bi
  adcs  x.acc3, x.acc3, x.t3
  umulh x.t3, x.a3, x.bi
  adc   x.acc4, x.acc4, xzr
  ldr   x.bi, [x.b, #24]
  adds  x.acc1, x.acc1, x.t0
  ubfm  x.t0, x.acc0, #32, #31
  adcs  x.acc2, x.acc2, x.t1
  ubfm  x.t1, x.acc0, #32, #63
  adcs  x.acc3, x.acc3, x.t2
  adcs  x.acc4, x.acc4, x.t3
  adc   x.acc5, xzr, xzr
  subs  x.t2, x.acc0, x.t0
  sbc   x.t3, x.acc0, x.t1
  adds  x.acc0, x.acc1, x.t0
  mul   x.t0, x.a0, x.bi
  adcs  x.acc1, x.acc2, x.t1
  mul   x.t1, x.a1, x.bi
  adcs  x.acc2, x.acc3, x.t2
  mul   x.t2, x.a2, x.bi
  adcs  x.acc3, x.acc4, x.t3
  mul   x.t3, x.a3, x.bi
  adc   x.acc4, x.acc5, xzr
  adds  x.acc0, x.acc0, x.t0
  umulh x.t0, x.a0, x.bi
  adcs  x.acc1, x.acc1, x.t1
  umulh x.t1, x.a1, x.bi
  adcs  x.acc2, x.acc2, x.t2
  umulh x.t2, x.a2, x.bi
  adcs  x.acc3, x.acc3, x.t3
  umulh x.t3, x.a3, x.bi
  adc   x.acc4, x.acc4, xzr
  adds  x.acc1, x.acc1, x.t0
  ubfm  x.t0, x.acc0, #32, #31
  adcs  x.acc2, x.acc2, x.t1
  ubfm  x.t1, x.acc0, #32, #63
  adcs  x.acc3, x.acc3, x.t2
  adcs  x.acc4, x.acc4, x.t3
  adc   x.acc5, xzr, xzr
  subs  x.t2, x.acc0, x.t0
  sbc   x.t3, x.acc0, x.t1
  adds  x.acc0, x.acc1, x.t0
  adcs  x.acc1, x.acc2, x.t1
  adcs  x.acc2, x.acc3, x.t2
  adcs  x.acc3, x.acc4, x.t3
  adc   x.acc4, x.acc5, xzr
  movz  x.pp1, #0xffff
  movk  x.pp1, #0xffff, lsl #16
  movz  x.pp3, #0x0001
  movk  x.pp3, #0xffff, lsl #32
  movk  x.pp3, #0xffff, lsl #48
  adds  x.t0, x.acc0, #1
  sbcs  x.t1, x.acc1, x.pp1
  sbcs  x.t2, x.acc2, xzr
  sbcs  x.t3, x.acc3, x.pp3
  sbcs  xzr,  x.acc4, xzr
  csel  x.o0, x.acc0, x.t0, lo
  csel  x.o1, x.acc1, x.t1, lo
  csel  x.o2, x.acc2, x.t2, lo
  csel  x.o3, x.acc3, x.t3, lo
  str x.o0, [x.r, #0]
  str x.o1, [x.r, #8]
  str x.o2, [x.r, #16]
  str x.o3, [x.r, #24]
  ret
.end
