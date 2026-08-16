;; asmp .context source for the hand-scheduled Montgomery symmetric-squaring
;; kernel bn_sqr_mont_8w (sqrx8x 8-way operand-scanning; was the source-less
;; rktcrypto_bn_sqr.S). One `.context bn_sqr_ctx (scope library)` declares the
;; OpenSSL-derived register ABI ONCE: acc0-7 in x19-x26, cnt=x27, carry/na0=x28,
;; topmost=x30, a0-7 in x6-x13, temps t0-3 in x14-x17, tp=x2, ap/np=x1,
;; ap_end/np_end/rp-copy=x3, n0=x4, num(words->bytes)=x5, rp/window=x0. The M3
;; frame is generated, not hand-written: `.save all` emits the callee-saved
;; prologue/epilogue (x29/x30 + x19-x28, fixed 128B frame), `.frame 32` reserves
;; the FP-relative locals at [x29,#96/104/112] (rp/np/n0 offload) and emits the
;; x29 frame pointer, `.alloca x.num,4` emits the variable-length `sub sp,sp,
;; num,lsl#4` (tp = sp - num*16). Body is the hand schedule verbatim, only
;; physical registers renamed to x.<field> -> instruction schedule unchanged;
;; the hot loops (Louter_loop/Lsqr_mul/Lreduction/Lshift_n_add/Lsqr8x_tail/
;; Lsqr8x_sub/Lcond_copy) are byte-for-byte the OpenSSL-parity schedule.
;; ABI: void bn_sqr_mont_8w(uint64_t*rp, const uint64_t*ap, const uint64_t*np,
;;                          const uint64_t*n0p, int num)   // num multiple of 8
;; Assemble: cli/as.rkt --gnu-input --apple --elim --default-abi aapcs64
;;   --keep-comments --allow-sp-writes asm/bn_sqr.asm
;; Gate: asm/tests/test_bn.c diff_sqr num=8/16/32 = 0 mismatches + ABI guard.

.context bn_sqr_ctx (scope library) rp=x0 ap=x1 tp=x2 apend=x3 n0=x4 num=x5 a0=x6 a1=x7 a2=x8 a3=x9 a4=x10 a5=x11 a6=x12 a7=x13 t0=x14 t1=x15 t2=x16 t3=x17 acc0=x19 acc1=x20 acc2=x21 acc3=x22 acc4=x23 acc5=x24 acc6=x25 acc7=x26 cnt=x27 carry=x28 top=x30


.function bn_sqr_mont_8w (context bn_sqr_ctx) export
entry:
  mov	x.num,x.n0	// num (words)
  mov	x.n0,x.apend	// n0p
  mov	x.apend,x.tp	// np
  .save all
  .frame 32
  stp	x.rp,x.apend,[sp,#96]	// offload rp, np
  ldp	x.a0,x.a1,[x.ap,#0]
  ldp	x.a2,x.a3,[x.ap,#16]
  ldp	x.a4,x.a5,[x.ap,#32]
  ldp	x.a6,x.a7,[x.ap,#48]
  .alloca x5, 4             // sub sp,sp,x5,lsl#4  (x5=num words; sp = tp = sp - num*16)
  mov x.tp, sp              // tp = post-alloca sp
  ubfm x.num, x.num, #61, #60   // lsl x5,x5,#3  (num words -> bytes)
  ldr	x.n0,[x.n0]	// *n0
  sub	x.cnt,x.num,#64
  b	Lzero_start
Lzero:
  sub	x.cnt,x.cnt,#64
  stp	xzr,xzr,[x.tp,#0]
  stp	xzr,xzr,[x.tp,#16]
  stp	xzr,xzr,[x.tp,#32]
  stp	xzr,xzr,[x.tp,#48]
Lzero_start:
  stp	xzr,xzr,[x.tp,#64]
  stp	xzr,xzr,[x.tp,#80]
  stp	xzr,xzr,[x.tp,#96]
  stp	xzr,xzr,[x.tp,#112]
  add	x.tp,x.tp,#128
  cbnz	x.cnt,Lzero
  add	x.apend,x.ap,x.num	// ap_end = &a[num]
  add	x.ap,x.ap,#64	// ap += 8
  mov	x.acc0,xzr
  mov	x.acc1,xzr
  mov	x.acc2,xzr
  mov	x.acc3,xzr
  mov	x.acc4,xzr
  mov	x.acc5,xzr
  mov	x.acc6,xzr
  mov	x.acc7,xzr
  mov	x.tp,sp	// tp
  str	x.n0,[x29,#112]	// offload n0
Louter_loop:
  mul	x.t0,x.a1,x.a0
  mul	x.t1,x.a2,x.a0
  mul	x.t2,x.a3,x.a0
  mul	x.t3,x.a4,x.a0
  adds	x.acc1,x.acc1,x.t0
  mul	x.t0,x.a5,x.a0
  adcs	x.acc2,x.acc2,x.t1
  mul	x.t1,x.a6,x.a0
  adcs	x.acc3,x.acc3,x.t2
  mul	x.t2,x.a7,x.a0
  adcs	x.acc4,x.acc4,x.t3
  umulh	x.t3,x.a1,x.a0
  adcs	x.acc5,x.acc5,x.t0
  umulh	x.t0,x.a2,x.a0
  adcs	x.acc6,x.acc6,x.t1
  umulh	x.t1,x.a3,x.a0
  adcs	x.acc7,x.acc7,x.t2
  umulh	x.t2,x.a4,x.a0
  stp	x.acc0,x.acc1,[x.tp],#16
  adc	x.acc0,xzr,xzr
  adds	x.acc2,x.acc2,x.t3
  umulh	x.t3,x.a5,x.a0
  adcs	x.acc3,x.acc3,x.t0
  umulh	x.t0,x.a6,x.a0
  adcs	x.acc4,x.acc4,x.t1
  umulh	x.t1,x.a7,x.a0
  adcs	x.acc5,x.acc5,x.t2
  mul	x.t2,x.a2,x.a1	// (ii)
  adcs	x.acc6,x.acc6,x.t3
  mul	x.t3,x.a3,x.a1
  adcs	x.acc7,x.acc7,x.t0
  mul	x.t0,x.a4,x.a1
  adc	x.acc0,x.acc0,x.t1
  mul	x.t1,x.a5,x.a1
  adds	x.acc3,x.acc3,x.t2
  mul	x.t2,x.a6,x.a1
  adcs	x.acc4,x.acc4,x.t3
  mul	x.t3,x.a7,x.a1
  adcs	x.acc5,x.acc5,x.t0
  umulh	x.t0,x.a2,x.a1
  adcs	x.acc6,x.acc6,x.t1
  umulh	x.t1,x.a3,x.a1
  adcs	x.acc7,x.acc7,x.t2
  umulh	x.t2,x.a4,x.a1
  adcs	x.acc0,x.acc0,x.t3
  umulh	x.t3,x.a5,x.a1
  stp	x.acc2,x.acc3,[x.tp],#16
  adc	x.acc1,xzr,xzr
  adds	x.acc4,x.acc4,x.t0
  umulh	x.t0,x.a6,x.a1
  adcs	x.acc5,x.acc5,x.t1
  umulh	x.t1,x.a7,x.a1
  adcs	x.acc6,x.acc6,x.t2
  mul	x.t2,x.a3,x.a2	// (iii)
  adcs	x.acc7,x.acc7,x.t3
  mul	x.t3,x.a4,x.a2
  adcs	x.acc0,x.acc0,x.t0
  mul	x.t0,x.a5,x.a2
  adc	x.acc1,x.acc1,x.t1
  mul	x.t1,x.a6,x.a2
  adds	x.acc5,x.acc5,x.t2
  mul	x.t2,x.a7,x.a2
  adcs	x.acc6,x.acc6,x.t3
  umulh	x.t3,x.a3,x.a2
  adcs	x.acc7,x.acc7,x.t0
  umulh	x.t0,x.a4,x.a2
  adcs	x.acc0,x.acc0,x.t1
  umulh	x.t1,x.a5,x.a2
  adcs	x.acc1,x.acc1,x.t2
  umulh	x.t2,x.a6,x.a2
  stp	x.acc4,x.acc5,[x.tp],#16
  adc	x.acc2,xzr,xzr
  adds	x.acc6,x.acc6,x.t3
  umulh	x.t3,x.a7,x.a2
  adcs	x.acc7,x.acc7,x.t0
  mul	x.t0,x.a4,x.a3	// (iv)
  adcs	x.acc0,x.acc0,x.t1
  mul	x.t1,x.a5,x.a3
  adcs	x.acc1,x.acc1,x.t2
  mul	x.t2,x.a6,x.a3
  adc	x.acc2,x.acc2,x.t3
  mul	x.t3,x.a7,x.a3
  adds	x.acc7,x.acc7,x.t0
  umulh	x.t0,x.a4,x.a3
  adcs	x.acc0,x.acc0,x.t1
  umulh	x.t1,x.a5,x.a3
  adcs	x.acc1,x.acc1,x.t2
  umulh	x.t2,x.a6,x.a3
  adcs	x.acc2,x.acc2,x.t3
  umulh	x.t3,x.a7,x.a3
  stp	x.acc6,x.acc7,[x.tp],#16
  adc	x.acc3,xzr,xzr
  adds	x.acc0,x.acc0,x.t0
  mul	x.t0,x.a5,x.a4	// (v)
  adcs	x.acc1,x.acc1,x.t1
  mul	x.t1,x.a6,x.a4
  adcs	x.acc2,x.acc2,x.t2
  mul	x.t2,x.a7,x.a4
  adc	x.acc3,x.acc3,x.t3
  umulh	x.t3,x.a5,x.a4
  adds	x.acc1,x.acc1,x.t0
  umulh	x.t0,x.a6,x.a4
  adcs	x.acc2,x.acc2,x.t1
  umulh	x.t1,x.a7,x.a4
  adcs	x.acc3,x.acc3,x.t2
  mul	x.t2,x.a6,x.a5	// (vi)
  adc	x.acc4,xzr,xzr
  adds	x.acc2,x.acc2,x.t3
  mul	x.t3,x.a7,x.a5
  adcs	x.acc3,x.acc3,x.t0
  umulh	x.t0,x.a6,x.a5
  adc	x.acc4,x.acc4,x.t1
  umulh	x.t1,x.a7,x.a5
  adds	x.acc3,x.acc3,x.t2
  mul	x.t2,x.a7,x.a6	// (vii)
  adcs	x.acc4,x.acc4,x.t3
  umulh	x.t3,x.a7,x.a6
  adc	x.acc5,xzr,xzr
  adds	x.acc4,x.acc4,x.t0
  sub	x.cnt,x.apend,x.ap	// done?
  adc	x.acc5,x.acc5,x.t1
  adds	x.acc5,x.acc5,x.t2
  sub	x.t0,x.apend,x.num	// rewinded ap = &a[0]
  adc	x.acc6,xzr,xzr
  add	x.acc6,x.acc6,x.t3
  cbz	x.cnt,Louter_break
  mov	x.n0,x.a0	// n0 <- a[0]
  ldp	x.a0,x.a1,[x.tp,#0]
  ldp	x.a2,x.a3,[x.tp,#16]
  ldp	x.a4,x.a5,[x.tp,#32]
  ldp	x.a6,x.a7,[x.tp,#48]
  adds	x.acc0,x.acc0,x.a0
  adcs	x.acc1,x.acc1,x.a1
  ldp	x.a0,x.a1,[x.ap,#0]
  adcs	x.acc2,x.acc2,x.a2
  adcs	x.acc3,x.acc3,x.a3
  ldp	x.a2,x.a3,[x.ap,#16]
  adcs	x.acc4,x.acc4,x.a4
  adcs	x.acc5,x.acc5,x.a5
  ldp	x.a4,x.a5,[x.ap,#32]
  adcs	x.acc6,x.acc6,x.a6
  mov	x.rp,x.ap	// rp <- ap
  adcs	x.acc7,xzr,x.a7
  ldp	x.a6,x.a7,[x.ap,#48]
  add	x.ap,x.ap,#64
  movn x.cnt, #63
Lsqr_mul:
  mul	x.t0,x.a0,x.n0
  adc	x.carry,xzr,xzr
  mul	x.t1,x.a1,x.n0
  add	x.cnt,x.cnt,#8
  mul	x.t2,x.a2,x.n0
  mul	x.t3,x.a3,x.n0
  adds	x.acc0,x.acc0,x.t0
  mul	x.t0,x.a4,x.n0
  adcs	x.acc1,x.acc1,x.t1
  mul	x.t1,x.a5,x.n0
  adcs	x.acc2,x.acc2,x.t2
  mul	x.t2,x.a6,x.n0
  adcs	x.acc3,x.acc3,x.t3
  mul	x.t3,x.a7,x.n0
  adcs	x.acc4,x.acc4,x.t0
  umulh	x.t0,x.a0,x.n0
  adcs	x.acc5,x.acc5,x.t1
  umulh	x.t1,x.a1,x.n0
  adcs	x.acc6,x.acc6,x.t2
  umulh	x.t2,x.a2,x.n0
  adcs	x.acc7,x.acc7,x.t3
  umulh	x.t3,x.a3,x.n0
  adc	x.carry,x.carry,xzr
  str	x.acc0,[x.tp],#8
  adds	x.acc0,x.acc1,x.t0
  umulh	x.t0,x.a4,x.n0
  adcs	x.acc1,x.acc2,x.t1
  umulh	x.t1,x.a5,x.n0
  adcs	x.acc2,x.acc3,x.t2
  umulh	x.t2,x.a6,x.n0
  adcs	x.acc3,x.acc4,x.t3
  umulh	x.t3,x.a7,x.n0
  ldr	x.n0,[x.rp,x.cnt]
  adcs	x.acc4,x.acc5,x.t0
  adcs	x.acc5,x.acc6,x.t1
  adcs	x.acc6,x.acc7,x.t2
  adcs	x.acc7,x.carry,x.t3
  cbnz	x.cnt,Lsqr_mul
  cmp	x.ap,x.apend
  b.eq	Lsqr_break
  ldp	x.a0,x.a1,[x.tp,#0]
  ldp	x.a2,x.a3,[x.tp,#16]
  ldp	x.a4,x.a5,[x.tp,#32]
  ldp	x.a6,x.a7,[x.tp,#48]
  adds	x.acc0,x.acc0,x.a0
  ldur	x.n0,[x.rp,#-64]
  adcs	x.acc1,x.acc1,x.a1
  ldp	x.a0,x.a1,[x.ap,#0]
  adcs	x.acc2,x.acc2,x.a2
  adcs	x.acc3,x.acc3,x.a3
  ldp	x.a2,x.a3,[x.ap,#16]
  adcs	x.acc4,x.acc4,x.a4
  adcs	x.acc5,x.acc5,x.a5
  ldp	x.a4,x.a5,[x.ap,#32]
  adcs	x.acc6,x.acc6,x.a6
  movn x.cnt, #63
  adcs	x.acc7,x.acc7,x.a7
  ldp	x.a6,x.a7,[x.ap,#48]
  add	x.ap,x.ap,#64
  b	Lsqr_mul
  .align	4
Lsqr_break:
  ldp	x.a0,x.a1,[x.rp,#0]
  add	x.ap,x.rp,#64
  ldp	x.a2,x.a3,[x.rp,#16]
  sub	x.t0,x.apend,x.ap
  ldp	x.a4,x.a5,[x.rp,#32]
  sub	x.t1,x.tp,x.t0
  ldp	x.a6,x.a7,[x.rp,#48]
  cbz	x.t0,Louter_loop
  stp	x.acc0,x.acc1,[x.tp,#0]
  ldp	x.acc0,x.acc1,[x.t1,#0]
  stp	x.acc2,x.acc3,[x.tp,#16]
  ldp	x.acc2,x.acc3,[x.t1,#16]
  stp	x.acc4,x.acc5,[x.tp,#32]
  ldp	x.acc4,x.acc5,[x.t1,#32]
  stp	x.acc6,x.acc7,[x.tp,#48]
  mov	x.tp,x.t1
  ldp	x.acc6,x.acc7,[x.t1,#48]
  b	Louter_loop
  .align	4
Louter_break:
  ldp	x.a1,x.a3,[x.t0,#0]	// a[0],a[1]
  ldp	x.t1,x.t2,[sp,#8]	// t[1],t[2]
  ldp	x.a5,x.a7,[x.t0,#16]	// a[2],a[3]
  add	x.ap,x.t0,#32
  ldp	x.t3,x.t0,[sp,#24]	// t[3],t[4]
  stp	x.acc0,x.acc1,[x.tp,#0]
  mul	x.acc0,x.a1,x.a1	// a[0]^2
  stp	x.acc2,x.acc3,[x.tp,#16]
  umulh	x.a1,x.a1,x.a1
  stp	x.acc4,x.acc5,[x.tp,#32]
  mul	x.a2,x.a3,x.a3	// a[1]^2
  stp	x.acc6,x.acc7,[x.tp,#48]
  mov	x.tp,sp
  umulh	x.a3,x.a3,x.a3
  adds	x.acc1,x.a1,x.t1,lsl #1
  extr	x.t1,x.t2,x.t1,#63
  sub	x.cnt,x.num,#32
Lshift_n_add:
  adcs	x.acc2,x.a2,x.t1
  extr	x.t2,x.t3,x.t2,#63
  sub	x.cnt,x.cnt,#32
  adcs	x.acc3,x.a3,x.t2
  ldp	x.t1,x.t2,[x.tp,#40]
  mul	x.a4,x.a5,x.a5	// a[2]^2
  ldp	x.a1,x.a3,[x.ap],#16
  umulh	x.a5,x.a5,x.a5
  mul	x.a6,x.a7,x.a7	// a[3]^2
  umulh	x.a7,x.a7,x.a7
  extr	x.t3,x.t0,x.t3,#63
  stp	x.acc0,x.acc1,[x.tp,#0]
  adcs	x.acc4,x.a4,x.t3
  extr	x.t0,x.t1,x.t0,#63
  stp	x.acc2,x.acc3,[x.tp,#16]
  adcs	x.acc5,x.a5,x.t0
  ldp	x.t3,x.t0,[x.tp,#56]
  extr	x.t1,x.t2,x.t1,#63
  adcs	x.acc6,x.a6,x.t1
  extr	x.t2,x.t3,x.t2,#63
  adcs	x.acc7,x.a7,x.t2
  ldp	x.t1,x.t2,[x.tp,#72]
  mul	x.a0,x.a1,x.a1	// a[4]^2
  ldp	x.a5,x.a7,[x.ap],#16
  umulh	x.a1,x.a1,x.a1
  mul	x.a2,x.a3,x.a3	// a[5]^2
  umulh	x.a3,x.a3,x.a3
  stp	x.acc4,x.acc5,[x.tp,#32]
  extr	x.t3,x.t0,x.t3,#63
  stp	x.acc6,x.acc7,[x.tp,#48]
  add	x.tp,x.tp,#64
  adcs	x.acc0,x.a0,x.t3
  extr	x.t0,x.t1,x.t0,#63
  adcs	x.acc1,x.a1,x.t0
  ldp	x.t3,x.t0,[x.tp,#24]
  extr	x.t1,x.t2,x.t1,#63
  cbnz	x.cnt,Lshift_n_add
  ldp	x.ap,x.n0,[x29,#104]	// np, n0
  adcs	x.acc2,x.a2,x.t1
  extr	x.t2,x.t3,x.t2,#63
  adcs	x.acc3,x.a3,x.t2
  ldp	x.t1,x.t2,[x.tp,#40]
  mul	x.a4,x.a5,x.a5
  umulh	x.a5,x.a5,x.a5
  stp	x.acc0,x.acc1,[x.tp,#0]
  mul	x.a6,x.a7,x.a7
  umulh	x.a7,x.a7,x.a7
  stp	x.acc2,x.acc3,[x.tp,#16]
  extr	x.t3,x.t0,x.t3,#63
  adcs	x.acc4,x.a4,x.t3
  extr	x.t0,x.t1,x.t0,#63
  ldp	x.acc0,x.acc1,[sp,#0]
  adcs	x.acc5,x.a5,x.t0
  extr	x.t1,x.t2,x.t1,#63
  ldp	x.a0,x.a1,[x.ap,#0]	// n[0..]
  adcs	x.acc6,x.a6,x.t1
  extr	x.t2,xzr,x.t2,#63
  ldp	x.a2,x.a3,[x.ap,#16]
  adc	x.acc7,x.a7,x.t2
  ldp	x.a4,x.a5,[x.ap,#32]
  mul	x.carry,x.n0,x.acc0	// na0 = t[0]*n0
  ldp	x.a6,x.a7,[x.ap,#48]
  add	x.apend,x.ap,x.num	// np_end
  ldp	x.acc2,x.acc3,[sp,#16]
  stp	x.acc4,x.acc5,[x.tp,#32]
  ldp	x.acc4,x.acc5,[sp,#32]
  stp	x.acc6,x.acc7,[x.tp,#48]
  ldp	x.acc6,x.acc7,[sp,#48]
  add	x.ap,x.ap,#64	// np += 8
  mov	x.top,xzr	// topmost
  mov	x.tp,sp
  mov	x.cnt,#8
Lreduction:
  mul	x.t1,x.a1,x.carry
  sub	x.cnt,x.cnt,#1
  mul	x.t2,x.a2,x.carry
  str	x.carry,[x.tp],#8
  mul	x.t3,x.a3,x.carry
  subs	xzr,x.acc0,#1
  mul	x.t0,x.a4,x.carry
  adcs	x.acc0,x.acc1,x.t1
  mul	x.t1,x.a5,x.carry
  adcs	x.acc1,x.acc2,x.t2
  mul	x.t2,x.a6,x.carry
  adcs	x.acc2,x.acc3,x.t3
  mul	x.t3,x.a7,x.carry
  adcs	x.acc3,x.acc4,x.t0
  umulh	x.t0,x.a0,x.carry
  adcs	x.acc4,x.acc5,x.t1
  umulh	x.t1,x.a1,x.carry
  adcs	x.acc5,x.acc6,x.t2
  umulh	x.t2,x.a2,x.carry
  adcs	x.acc6,x.acc7,x.t3
  umulh	x.t3,x.a3,x.carry
  adc	x.acc7,xzr,xzr
  adds	x.acc0,x.acc0,x.t0
  umulh	x.t0,x.a4,x.carry
  adcs	x.acc1,x.acc1,x.t1
  umulh	x.t1,x.a5,x.carry
  adcs	x.acc2,x.acc2,x.t2
  umulh	x.t2,x.a6,x.carry
  adcs	x.acc3,x.acc3,x.t3
  umulh	x.t3,x.a7,x.carry
  mul	x.carry,x.n0,x.acc0	// next na0
  adcs	x.acc4,x.acc4,x.t0
  adcs	x.acc5,x.acc5,x.t1
  adcs	x.acc6,x.acc6,x.t2
  adc	x.acc7,x.acc7,x.t3
  cbnz	x.cnt,Lreduction
  ldp	x.t0,x.t1,[x.tp,#0]
  ldp	x.t2,x.t3,[x.tp,#16]
  mov	x.rp,x.tp	// window ptr
  sub	x.cnt,x.apend,x.ap	// done?
  adds	x.acc0,x.acc0,x.t0
  adcs	x.acc1,x.acc1,x.t1
  ldp	x.t0,x.t1,[x.tp,#32]
  adcs	x.acc2,x.acc2,x.t2
  adcs	x.acc3,x.acc3,x.t3
  ldp	x.t2,x.t3,[x.tp,#48]
  adcs	x.acc4,x.acc4,x.t0
  adcs	x.acc5,x.acc5,x.t1
  adcs	x.acc6,x.acc6,x.t2
  adcs	x.acc7,x.acc7,x.t3
  cbz	x.cnt,Lpost8
  ldur	x.n0,[x.tp,#-64]
  ldp	x.a0,x.a1,[x.ap,#0]
  ldp	x.a2,x.a3,[x.ap,#16]
  ldp	x.a4,x.a5,[x.ap,#32]
  movn x.cnt, #63
  ldp	x.a6,x.a7,[x.ap,#48]
  add	x.ap,x.ap,#64
Lsqr8x_tail:
  mul	x.t0,x.a0,x.n0
  adc	x.carry,xzr,xzr
  mul	x.t1,x.a1,x.n0
  add	x.cnt,x.cnt,#8
  mul	x.t2,x.a2,x.n0
  mul	x.t3,x.a3,x.n0
  adds	x.acc0,x.acc0,x.t0
  mul	x.t0,x.a4,x.n0
  adcs	x.acc1,x.acc1,x.t1
  mul	x.t1,x.a5,x.n0
  adcs	x.acc2,x.acc2,x.t2
  mul	x.t2,x.a6,x.n0
  adcs	x.acc3,x.acc3,x.t3
  mul	x.t3,x.a7,x.n0
  adcs	x.acc4,x.acc4,x.t0
  umulh	x.t0,x.a0,x.n0
  adcs	x.acc5,x.acc5,x.t1
  umulh	x.t1,x.a1,x.n0
  adcs	x.acc6,x.acc6,x.t2
  umulh	x.t2,x.a2,x.n0
  adcs	x.acc7,x.acc7,x.t3
  umulh	x.t3,x.a3,x.n0
  adc	x.carry,x.carry,xzr
  str	x.acc0,[x.tp],#8
  adds	x.acc0,x.acc1,x.t0
  umulh	x.t0,x.a4,x.n0
  adcs	x.acc1,x.acc2,x.t1
  umulh	x.t1,x.a5,x.n0
  adcs	x.acc2,x.acc3,x.t2
  umulh	x.t2,x.a6,x.n0
  adcs	x.acc3,x.acc4,x.t3
  umulh	x.t3,x.a7,x.n0
  ldr	x.n0,[x.rp,x.cnt]
  adcs	x.acc4,x.acc5,x.t0
  adcs	x.acc5,x.acc6,x.t1
  adcs	x.acc6,x.acc7,x.t2
  adcs	x.acc7,x.carry,x.t3
  cbnz	x.cnt,Lsqr8x_tail
  ldp	x.a0,x.a1,[x.tp,#0]
  sub	x.cnt,x.apend,x.ap	// done?
  sub	x.t2,x.apend,x.num	// rewinded np
  ldp	x.a2,x.a3,[x.tp,#16]
  ldp	x.a4,x.a5,[x.tp,#32]
  ldp	x.a6,x.a7,[x.tp,#48]
  cbz	x.cnt,Ltail_break
  ldur	x.n0,[x.rp,#-64]
  adds	x.acc0,x.acc0,x.a0
  adcs	x.acc1,x.acc1,x.a1
  ldp	x.a0,x.a1,[x.ap,#0]
  adcs	x.acc2,x.acc2,x.a2
  adcs	x.acc3,x.acc3,x.a3
  ldp	x.a2,x.a3,[x.ap,#16]
  adcs	x.acc4,x.acc4,x.a4
  adcs	x.acc5,x.acc5,x.a5
  ldp	x.a4,x.a5,[x.ap,#32]
  adcs	x.acc6,x.acc6,x.a6
  movn x.cnt, #63
  adcs	x.acc7,x.acc7,x.a7
  ldp	x.a6,x.a7,[x.ap,#48]
  add	x.ap,x.ap,#64
  b	Lsqr8x_tail
  .align	4
Ltail_break:
  ldr	x.n0,[x29,#112]	// n0
  add	x.cnt,x.tp,#64
  subs	xzr,x.top,#1	// move topmost carry to C
  adcs	x.t0,x.acc0,x.a0
  adcs	x.t1,x.acc1,x.a1
  ldp	x.acc0,x.acc1,[x.rp,#0]
  adcs	x.acc2,x.acc2,x.a2
  ldp	x.a0,x.a1,[x.t2,#0]	// x16 = &n[0]
  adcs	x.acc3,x.acc3,x.a3
  ldp	x.a2,x.a3,[x.t2,#16]
  adcs	x.acc4,x.acc4,x.a4
  adcs	x.acc5,x.acc5,x.a5
  ldp	x.a4,x.a5,[x.t2,#32]
  adcs	x.acc6,x.acc6,x.a6
  adcs	x.acc7,x.acc7,x.a7
  ldp	x.a6,x.a7,[x.t2,#48]
  add	x.ap,x.t2,#64
  adc	x.top,xzr,xzr	// topmost
  mul	x.carry,x.n0,x.acc0
  stp	x.t0,x.t1,[x.tp,#0]
  stp	x.acc2,x.acc3,[x.tp,#16]
  ldp	x.acc2,x.acc3,[x.rp,#16]
  stp	x.acc4,x.acc5,[x.tp,#32]
  ldp	x.acc4,x.acc5,[x.rp,#32]
  cmp	x.cnt,x29	// hit bottom?
  stp	x.acc6,x.acc7,[x.tp,#48]
  mov	x.tp,x.rp	// slide window
  ldp	x.acc6,x.acc7,[x.rp,#48]
  mov	x.cnt,#8
  b.ne	Lreduction
  ldr	x.rp,[x29,#96]	// rp
  add	x.tp,x.tp,#64
  subs	x.t0,x.acc0,x.a0
  sbcs	x.t1,x.acc1,x.a1
  sub	x.cnt,x.num,#64
  mov	x.apend,x.rp	// rp copy (ap_end)
Lsqr8x_sub:
  sbcs	x.t2,x.acc2,x.a2
  ldp	x.a0,x.a1,[x.ap,#0]
  sbcs	x.t3,x.acc3,x.a3
  stp	x.t0,x.t1,[x.rp,#0]
  sbcs	x.t0,x.acc4,x.a4
  ldp	x.a2,x.a3,[x.ap,#16]
  sbcs	x.t1,x.acc5,x.a5
  stp	x.t2,x.t3,[x.rp,#16]
  sbcs	x.t2,x.acc6,x.a6
  ldp	x.a4,x.a5,[x.ap,#32]
  sbcs	x.t3,x.acc7,x.a7
  ldp	x.a6,x.a7,[x.ap,#48]
  add	x.ap,x.ap,#64
  ldp	x.acc0,x.acc1,[x.tp,#0]
  sub	x.cnt,x.cnt,#64
  ldp	x.acc2,x.acc3,[x.tp,#16]
  ldp	x.acc4,x.acc5,[x.tp,#32]
  ldp	x.acc6,x.acc7,[x.tp,#48]
  add	x.tp,x.tp,#64
  stp	x.t0,x.t1,[x.rp,#32]
  sbcs	x.t0,x.acc0,x.a0
  stp	x.t2,x.t3,[x.rp,#48]
  add	x.rp,x.rp,#64
  sbcs	x.t1,x.acc1,x.a1
  cbnz	x.cnt,Lsqr8x_sub
  sbcs	x.t2,x.acc2,x.a2
  mov	x.tp,sp
  add	x.ap,sp,x.num
  ldp	x.a0,x.a1,[x.apend,#0]
  sbcs	x.t3,x.acc3,x.a3
  stp	x.t0,x.t1,[x.rp,#0]
  sbcs	x.t0,x.acc4,x.a4
  ldp	x.a2,x.a3,[x.apend,#16]
  sbcs	x.t1,x.acc5,x.a5
  stp	x.t2,x.t3,[x.rp,#16]
  sbcs	x.t2,x.acc6,x.a6
  ldp	x.acc0,x.acc1,[x.ap,#0]
  sbcs	x.t3,x.acc7,x.a7
  ldp	x.acc2,x.acc3,[x.ap,#16]
  sbcs	xzr,x.top,xzr	// borrow?
  ldr	x.top,[x29,#8]
  stp	x.t0,x.t1,[x.rp,#32]
  stp	x.t2,x.t3,[x.rp,#48]
  sub	x.cnt,x.num,#32
Lcond_copy:
  sub	x.cnt,x.cnt,#32
  csel	x.t0,x.acc0,x.a0,lo
  stp	xzr,xzr,[x.tp,#0]
  csel	x.t1,x.acc1,x.a1,lo
  ldp	x.a0,x.a1,[x.apend,#32]
  ldp	x.acc0,x.acc1,[x.ap,#32]
  csel	x.t2,x.acc2,x.a2,lo
  stp	xzr,xzr,[x.tp,#16]
  add	x.tp,x.tp,#32
  csel	x.t3,x.acc3,x.a3,lo
  ldp	x.a2,x.a3,[x.apend,#48]
  ldp	x.acc2,x.acc3,[x.ap,#48]
  add	x.ap,x.ap,#32
  stp	x.t0,x.t1,[x.apend,#0]
  stp	x.t2,x.t3,[x.apend,#16]
  add	x.apend,x.apend,#32
  stp	xzr,xzr,[x.ap,#-32]
  stp	xzr,xzr,[x.ap,#-16]
  cbnz	x.cnt,Lcond_copy
  csel	x.t0,x.acc0,x.a0,lo
  stp	xzr,xzr,[x.tp,#0]
  csel	x.t1,x.acc1,x.a1,lo
  stp	xzr,xzr,[x.tp,#16]
  csel	x.t2,x.acc2,x.a2,lo
  csel	x.t3,x.acc3,x.a3,lo
  stp	x.t0,x.t1,[x.apend,#0]
  stp	x.t2,x.t3,[x.apend,#16]
  b	Ldone
  .align	4
Lpost8:
  adc	x.carry,xzr,xzr
  ldr	x.top,[x29,#8]
  subs	x.a0,x.acc0,x.a0
  ldr	x.ap,[x29,#96]	// rp
  sbcs	x.a1,x.acc1,x.a1
  stp	xzr,xzr,[sp,#0]
  sbcs	x.a2,x.acc2,x.a2
  stp	xzr,xzr,[sp,#16]
  sbcs	x.a3,x.acc3,x.a3
  stp	xzr,xzr,[sp,#32]
  sbcs	x.a4,x.acc4,x.a4
  stp	xzr,xzr,[sp,#48]
  sbcs	x.a5,x.acc5,x.a5
  stp	xzr,xzr,[sp,#64]
  sbcs	x.a6,x.acc6,x.a6
  stp	xzr,xzr,[sp,#80]
  sbcs	x.a7,x.acc7,x.a7
  stp	xzr,xzr,[sp,#96]
  sbcs	x.carry,x.carry,xzr
  stp	xzr,xzr,[sp,#112]
  csel	x.a0,x.acc0,x.a0,lo
  csel	x.a1,x.acc1,x.a1,lo
  csel	x.a2,x.acc2,x.a2,lo
  csel	x.a3,x.acc3,x.a3,lo
  stp	x.a0,x.a1,[x.ap,#0]
  csel	x.a4,x.acc4,x.a4,lo
  csel	x.a5,x.acc5,x.a5,lo
  stp	x.a2,x.a3,[x.ap,#16]
  csel	x.a6,x.acc6,x.a6,lo
  csel	x.a7,x.acc7,x.a7,lo
  stp	x.a4,x.a5,[x.ap,#32]
  stp	x.a6,x.a7,[x.ap,#48]
Ldone:
  .restore all
  ret
