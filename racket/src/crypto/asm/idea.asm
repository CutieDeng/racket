;; IDEA block core (AArch64), hand-scheduled in rktasm. 8 rounds + output
;; transform over the four 16-bit words X1..X4. The multiply is mod (2^16+1)
;; with 0 representing 2^16, implemented BRANCHLESS: compute the normal
;; (lo-hi, +0x10001 if <=0) and the zero-case (1-x-y) and csel on p==0.
;; One kernel serves both directions (the C driver passes the encryption
;; subkeys Z for encrypt, the inverse-derived subkeys for decrypt). Key
;; schedule and big-endian byte packing stay in C... except the load/store
;; here does the big-endian word packing. Constants pinned: mask=0xffff,
;; big=0x10001, one=1.
;; Oracle: idea_crypt portable (bit-exact); gate: asm/tests/test_idea.c.
;;
;; void idea_core_asm(const uint16_t *Z, const unsigned char in[8],
;;                    unsigned char out[8]);
.function idea_core_asm export (
  in: x.Z, x.in, x.out
)
entry:
  .save all
  mov w.mask, #0xffff
  mov w.one, #1
  mov w.big, #1
  movk w.big, #1, lsl #16          ; 0x00010001 = 65537
  ;; load X1..X4 big-endian
  ldrb w.hb, [x.in]
  ldrb w.lb, [x.in, #1]
  orr w.X1, w.lb, w.hb, lsl #8
  ldrb w.hb, [x.in, #2]
  ldrb w.lb, [x.in, #3]
  orr w.X2, w.lb, w.hb, lsl #8
  ldrb w.hb, [x.in, #4]
  ldrb w.lb, [x.in, #5]
  orr w.X3, w.lb, w.hb, lsl #8
  ldrb w.hb, [x.in, #6]
  ldrb w.lb, [x.in, #7]
  orr w.X4, w.lb, w.hb, lsl #8
  mov x.cnt, #8
round:
  ;; X1 = mul(X1, z0)
  ldrh w.zk, [x.Z], #2
  mul w.p, w.X1, w.zk
  ror w.hi, w.p, #16
  and w.hi, w.hi, w.mask
  and w.lo, w.p, w.mask
  subs w.r, w.lo, w.hi, lsl #0
  add w.r2, w.r, w.big
  csel w.rn, w.r2, w.r, le
  and w.rn, w.rn, w.mask
  sub w.zc, w.one, w.X1
  sub w.zc, w.zc, w.zk
  and w.zc, w.zc, w.mask
  cmp w.p, #0
  csel w.X1, w.zc, w.rn, eq
  ;; X2 = add(X2, z1)
  ldrh w.zk, [x.Z], #2
  add w.X2, w.X2, w.zk
  and w.X2, w.X2, w.mask
  ;; X3 = add(X3, z2)
  ldrh w.zk, [x.Z], #2
  add w.X3, w.X3, w.zk
  and w.X3, w.X3, w.mask
  ;; X4 = mul(X4, z3)
  ldrh w.zk, [x.Z], #2
  mul w.p, w.X4, w.zk
  ror w.hi, w.p, #16
  and w.hi, w.hi, w.mask
  and w.lo, w.p, w.mask
  subs w.r, w.lo, w.hi, lsl #0
  add w.r2, w.r, w.big
  csel w.rn, w.r2, w.r, le
  and w.rn, w.rn, w.mask
  sub w.zc, w.one, w.X4
  sub w.zc, w.zc, w.zk
  and w.zc, w.zc, w.mask
  cmp w.p, #0
  csel w.X4, w.zc, w.rn, eq
  ;; t0 = mul(X1^X3, z4)
  eor w.ta, w.X1, w.X3
  ldrh w.zk, [x.Z], #2
  mul w.p, w.ta, w.zk
  ror w.hi, w.p, #16
  and w.hi, w.hi, w.mask
  and w.lo, w.p, w.mask
  subs w.r, w.lo, w.hi, lsl #0
  add w.r2, w.r, w.big
  csel w.rn, w.r2, w.r, le
  and w.rn, w.rn, w.mask
  sub w.zc, w.one, w.ta
  sub w.zc, w.zc, w.zk
  and w.zc, w.zc, w.mask
  cmp w.p, #0
  csel w.t0, w.zc, w.rn, eq
  ;; t1 = mul((X2^X4)+t0, z5)
  eor w.tb, w.X2, w.X4
  add w.tb, w.tb, w.t0
  and w.tb, w.tb, w.mask
  ldrh w.zk, [x.Z], #2
  mul w.p, w.tb, w.zk
  ror w.hi, w.p, #16
  and w.hi, w.hi, w.mask
  and w.lo, w.p, w.mask
  subs w.r, w.lo, w.hi, lsl #0
  add w.r2, w.r, w.big
  csel w.rn, w.r2, w.r, le
  and w.rn, w.rn, w.mask
  sub w.zc, w.one, w.tb
  sub w.zc, w.zc, w.zk
  and w.zc, w.zc, w.mask
  cmp w.p, #0
  csel w.t1, w.zc, w.rn, eq
  ;; t0 = add(t0, t1)
  add w.t0, w.t0, w.t1
  and w.t0, w.t0, w.mask
  ;; X1 ^= t1; X4 ^= t0
  eor w.X1, w.X1, w.t1
  eor w.X4, w.X4, w.t0
  ;; x = X2^t0; X2 = X3^t1; X3 = x
  eor w.tmp, w.X2, w.t0
  eor w.X2, w.X3, w.t1
  mov w.X3, w.tmp
  subs x.cnt, x.cnt, #1
  b.ne round
  ;; output transform: Y1=mul(X1,z0) Y2=add(X3,z1) Y3=add(X2,z2) Y4=mul(X4,z3)
  ldrh w.zk, [x.Z], #2
  mul w.p, w.X1, w.zk
  ror w.hi, w.p, #16
  and w.hi, w.hi, w.mask
  and w.lo, w.p, w.mask
  subs w.r, w.lo, w.hi, lsl #0
  add w.r2, w.r, w.big
  csel w.rn, w.r2, w.r, le
  and w.rn, w.rn, w.mask
  sub w.zc, w.one, w.X1
  sub w.zc, w.zc, w.zk
  and w.zc, w.zc, w.mask
  cmp w.p, #0
  csel w.Y1, w.zc, w.rn, eq
  ldrh w.zk, [x.Z], #2
  add w.Y2, w.X3, w.zk
  and w.Y2, w.Y2, w.mask
  ldrh w.zk, [x.Z], #2
  add w.Y3, w.X2, w.zk
  and w.Y3, w.Y3, w.mask
  ldrh w.zk, [x.Z]
  mul w.p, w.X4, w.zk
  ror w.hi, w.p, #16
  and w.hi, w.hi, w.mask
  and w.lo, w.p, w.mask
  subs w.r, w.lo, w.hi, lsl #0
  add w.r2, w.r, w.big
  csel w.rn, w.r2, w.r, le
  and w.rn, w.rn, w.mask
  sub w.zc, w.one, w.X4
  sub w.zc, w.zc, w.zk
  and w.zc, w.zc, w.mask
  cmp w.p, #0
  csel w.Y4, w.zc, w.rn, eq
  ;; store big-endian
  ror w.hb, w.Y1, #8
  strb w.hb, [x.out]
  strb w.Y1, [x.out, #1]
  ror w.hb, w.Y2, #8
  strb w.hb, [x.out, #2]
  strb w.Y2, [x.out, #3]
  ror w.hb, w.Y3, #8
  strb w.hb, [x.out, #4]
  strb w.Y3, [x.out, #5]
  ror w.hb, w.Y4, #8
  strb w.hb, [x.out, #6]
  strb w.Y4, [x.out, #7]
  .restore all
  ret
.end
