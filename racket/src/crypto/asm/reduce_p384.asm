;; P-384 Solinas reduction: r[6] <- reduce(prod[12]) mod p, bit-exact with the
;; C reduce_p384 in rktcrypto_ecc.c.  p = 2^384 - 2^128 - 2^96 + 2^32 - 1, so
;; 2^384 == c' (mod p) with c' = 2^128 + 2^96 - 2^32 + 1.  Because c' is a sum of
;; powers of two, folding hi*c' is MULTIPLY-FREE (shift/add/sub with adcs/sbcs
;; carry chains).  The C oracle always canonicalises into [0,p) (proven: after
;; the folds the residue is < 2^384 < 2p), so this kernel computes the same
;; canonical value.
;;
;; Layout (little-endian limbs): prod = lo(prod[0..5]) + hi(prod[6..11])*2^384.
;;   v  = lo + hi*c'                              (stage 1, 9 limbs, < 2^513)
;;   w  = v[0..5] + (v[6..8])*c'                  (stage 2, 7 limbs, < 2^385)
;;   fold top bit w[6] via c' + final subtract    (stage 3+4, one merged step)
;;       The residue is W + w6*2^384 (< 3p).  Adding w6*c' gives carry cy; then
;;       A = W' + c' where a carry cyA means W' >= p (value-p = value+c'-2^384).
;;       Picking A whenever cy|cyA does the second fold and the lone conditional
;;       subtract in one add (result is always canonical in [0,p)).
;;
;; hi*c' expands to  hi + (hi<<128) + (hi<<96) - (hi<<32).  With t = hi<<32
;; (7 limbs via extr), (hi<<96) = t at limb offset 1 and (hi<<32) = t at offset 0.
;;
;; ABI: void reduce_p384_asm(u64 r[6], const u64 prod[12]); x0=r, x1=prod.
.function reduce_p384_asm export (
  in: x.r, x.prod
)
entry:
  .save all
  ;; ---- load lo (prod[0..5]) and hi (prod[6..11]) ----
  ldr x.l0, [x.prod, #0]
  ldr x.l1, [x.prod, #8]
  ldr x.l2, [x.prod, #16]
  ldr x.l3, [x.prod, #24]
  ldr x.l4, [x.prod, #32]
  ldr x.l5, [x.prod, #40]
  ldr x.h0, [x.prod, #48]
  ldr x.h1, [x.prod, #56]
  ldr x.h2, [x.prod, #64]
  ldr x.h3, [x.prod, #72]
  ldr x.h4, [x.prod, #80]
  ldr x.h5, [x.prod, #88]

  ;; ---- t = hi << 32  (7 limbs t0..t6) ----
  ;; ubfm .,.,#32,#31 == lsl #32 ; ubfm .,.,#32,#63 == lsr #32
  ubfm x.t0, x.h0, #32, #31
  extr x.t1, x.h1, x.h0, #32
  extr x.t2, x.h2, x.h1, #32
  extr x.t3, x.h3, x.h2, #32
  extr x.t4, x.h4, x.h3, #32
  extr x.t5, x.h5, x.h4, #32
  ubfm x.t6, x.h5, #32, #63

  ;; ---- stage 1: v = lo + hi*c'  (v0..v8) ----
  ;; pass A: v[0..5] = lo + hi, carry -> v6
  adds x.v0, x.l0, x.h0
  adcs x.v1, x.l1, x.h1
  adcs x.v2, x.l2, x.h2
  adcs x.v3, x.l3, x.h3
  adcs x.v4, x.l4, x.h4
  adcs x.v5, x.l5, x.h5
  adc  x.v6, xzr, xzr
  ;; pass B: += hi<<128  (h0..h5 at limbs 2..7)
  adds x.v2, x.v2, x.h0
  adcs x.v3, x.v3, x.h1
  adcs x.v4, x.v4, x.h2
  adcs x.v5, x.v5, x.h3
  adcs x.v6, x.v6, x.h4
  adcs x.v7, xzr,  x.h5
  adc  x.v8, xzr,  xzr
  ;; pass C: += hi<<96  (t0..t6 at limbs 1..7)
  adds x.v1, x.v1, x.t0
  adcs x.v2, x.v2, x.t1
  adcs x.v3, x.v3, x.t2
  adcs x.v4, x.v4, x.t3
  adcs x.v5, x.v5, x.t4
  adcs x.v6, x.v6, x.t5
  adcs x.v7, x.v7, x.t6
  adc  x.v8, x.v8, xzr
  ;; pass D: -= hi<<32  (t0..t6 at limbs 0..6)
  subs x.v0, x.v0, x.t0
  sbcs x.v1, x.v1, x.t1
  sbcs x.v2, x.v2, x.t2
  sbcs x.v3, x.v3, x.t3
  sbcs x.v4, x.v4, x.t4
  sbcs x.v5, x.v5, x.t5
  sbcs x.v6, x.v6, x.t6
  sbcs x.v7, x.v7, xzr
  sbc  x.v8, x.v8, xzr

  ;; ---- stage 2: fold hi2 = (v6,v7,v8) via c' into v0..v5 -> w0..w6 ----
  ;; s = hi2 << 32  (4 limbs s0..s3)
  ubfm x.s0, x.v6, #32, #31
  extr x.s1, x.v7, x.v6, #32
  extr x.s2, x.v8, x.v7, #32
  ubfm x.s3, x.v8, #32, #63
  ;; pass A2: w = v[0..5] + hi2 (limbs 0..2)
  adds x.w0, x.v0, x.v6
  adcs x.w1, x.v1, x.v7
  adcs x.w2, x.v2, x.v8
  adcs x.w3, x.v3, xzr
  adcs x.w4, x.v4, xzr
  adcs x.w5, x.v5, xzr
  adc  x.w6, xzr,  xzr
  ;; pass B2: += hi2<<128  (v6,v7,v8 at limbs 2..4)
  adds x.w2, x.w2, x.v6
  adcs x.w3, x.w3, x.v7
  adcs x.w4, x.w4, x.v8
  adcs x.w5, x.w5, xzr
  adc  x.w6, x.w6, xzr
  ;; pass C2: += hi2<<96  (s0..s3 at limbs 1..4)
  adds x.w1, x.w1, x.s0
  adcs x.w2, x.w2, x.s1
  adcs x.w3, x.w3, x.s2
  adcs x.w4, x.w4, x.s3
  adcs x.w5, x.w5, xzr
  adc  x.w6, x.w6, xzr
  ;; pass D2: -= hi2<<32  (s0..s3 at limbs 0..3)
  subs x.w0, x.w0, x.s0
  sbcs x.w1, x.w1, x.s1
  sbcs x.w2, x.w2, x.s2
  sbcs x.w3, x.w3, x.s3
  sbcs x.w4, x.w4, xzr
  sbcs x.w5, x.w5, xzr
  sbc  x.w6, x.w6, xzr

  ;; ---- c' constants: C0=0xFFFFFFFF00000001 C1=0x00000000FFFFFFFF C2=1 ----
  movz x.c0, #1
  movk x.c0, #0xFFFF, lsl #32
  movk x.c0, #0xFFFF, lsl #48
  movz x.c1, #0xFFFF
  movk x.c1, #0xFFFF, lsl #16
  movz x.c2, #1

  ;; ---- stage 3+4: fold top bit w6 via c', then reduce into [0,p) ----
  ;; The remaining value is W + w6*2^384 with w6 in {0,1}, W < 2^384, total < 3p.
  ;; fold 1 adds w6*c' (== w6*2^384 mod p) into W, carry cy = new bit 384.
  ;; Then A = (post-fold1 low 6) + c'; a carry cyA out of limb 5 means that value
  ;; was >= p (recall value-p = value+c'-2^384).  Selecting A whenever (cy|cyA)
  ;; folds the second overflow AND does the single conditional subtract in one
  ;; add: if cy=1 the low limbs wrapped below c', so A < 2c' < p is the answer;
  ;; else A is value-p and is used iff value>=p (cyA).  (Verified by exhaustive
  ;; case analysis over w6 in {0,1}; the differential harness gates it.)
  neg  x.m, x.w6
  and  x.a0, x.c0, x.m
  and  x.a1, x.c1, x.m
  and  x.a2, x.c2, x.m
  adds x.w0, x.w0, x.a0
  adcs x.w1, x.w1, x.a1
  adcs x.w2, x.w2, x.a2
  adcs x.w3, x.w3, xzr
  adcs x.w4, x.w4, xzr
  adcs x.w5, x.w5, xzr
  adc  x.cy, xzr, xzr
  adds x.d0, x.w0, x.c0
  adcs x.d1, x.w1, x.c1
  adcs x.d2, x.w2, x.c2
  adcs x.d3, x.w3, xzr
  adcs x.d4, x.w4, xzr
  adcs x.d5, x.w5, xzr
  adc  x.cya, xzr, xzr
  orr  x.sel, x.cy, x.cya
  cmp  x.sel, #0                 ; sel!=0 (ne) => use A (value-p or 2nd fold)
  csel x.o0, x.d0, x.w0, ne
  csel x.o1, x.d1, x.w1, ne
  csel x.o2, x.d2, x.w2, ne
  csel x.o3, x.d3, x.w3, ne
  csel x.o4, x.d4, x.w4, ne
  csel x.o5, x.d5, x.w5, ne

  str x.o0, [x.r, #0]
  str x.o1, [x.r, #8]
  str x.o2, [x.r, #16]
  str x.o3, [x.r, #24]
  str x.o4, [x.r, #32]
  str x.o5, [x.r, #40]
  .restore all
  ret
.end
