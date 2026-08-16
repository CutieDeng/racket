;; RC2 (RFC 2268) block core (AArch64), hand-scheduled in rktasm. Operates on the
;; four 16-bit words R0..R3 held in the low halves of GPRs; the 64-word expanded
;; key K is read from memory (C does key expansion + the block loop). 16 MIX
;; rounds with a MASH after rounds 5 and 11. 16-bit rotate uses the duplicate
;; trick: ROL16(x,n) = low16( ror32(x|(x<<16), 16-n) ). MIX select term
;; (R[im2]&R[im1]) + (R[im3]&~R[im1]) is bit-disjoint, so it is an OR of and/bic.
;; Oracle: rc2 portable (bit-exact); gate: asm/tests/test_rc2.c.
;;
;; void rc2_enc_core_asm(const uint16_t *K, const unsigned char in[8],
;;                       unsigned char out[8]);
.function rc2_enc_core_asm export (
  in: x.K, x.in, x.out
)
entry:
  .save all
  ldrh w.r0, [x.in]
  ldrh w.r1, [x.in, #2]
  ldrh w.r2, [x.in, #4]
  ldrh w.r3, [x.in, #6]
  mov w.j, #0
  mov w.rc, #0
  mov w.mask, #0xffff
mixloop:
  ;; i=0: ri=r0 im1=r3 im2=r2 im3=r1 s=1
  ldrh w.k, [x.K, w.j, uxtw #1]
  add w.j, w.j, #1
  and w.t, w.r2, w.r3
  bic w.t2, w.r1, w.r3
  orr w.sel, w.t, w.t2
  add w.r0, w.r0, w.k
  add w.r0, w.r0, w.sel
  and w.r0, w.r0, w.mask
  orr w.tmp, w.r0, w.r0, lsl #16
  ror w.tmp, w.tmp, #15
  and w.r0, w.tmp, w.mask
  ;; i=1: ri=r1 im1=r0 im2=r3 im3=r2 s=2
  ldrh w.k, [x.K, w.j, uxtw #1]
  add w.j, w.j, #1
  and w.t, w.r3, w.r0
  bic w.t2, w.r2, w.r0
  orr w.sel, w.t, w.t2
  add w.r1, w.r1, w.k
  add w.r1, w.r1, w.sel
  and w.r1, w.r1, w.mask
  orr w.tmp, w.r1, w.r1, lsl #16
  ror w.tmp, w.tmp, #14
  and w.r1, w.tmp, w.mask
  ;; i=2: ri=r2 im1=r1 im2=r0 im3=r3 s=3
  ldrh w.k, [x.K, w.j, uxtw #1]
  add w.j, w.j, #1
  and w.t, w.r0, w.r1
  bic w.t2, w.r3, w.r1
  orr w.sel, w.t, w.t2
  add w.r2, w.r2, w.k
  add w.r2, w.r2, w.sel
  and w.r2, w.r2, w.mask
  orr w.tmp, w.r2, w.r2, lsl #16
  ror w.tmp, w.tmp, #13
  and w.r2, w.tmp, w.mask
  ;; i=3: ri=r3 im1=r2 im2=r1 im3=r0 s=5
  ldrh w.k, [x.K, w.j, uxtw #1]
  add w.j, w.j, #1
  and w.t, w.r1, w.r2
  bic w.t2, w.r0, w.r2
  orr w.sel, w.t, w.t2
  add w.r3, w.r3, w.k
  add w.r3, w.r3, w.sel
  and w.r3, w.r3, w.mask
  orr w.tmp, w.r3, w.r3, lsl #16
  ror w.tmp, w.tmp, #11
  and w.r3, w.tmp, w.mask

  add w.rc, w.rc, #1
  cmp w.rc, #5
  b.eq domash
  cmp w.rc, #11
  b.eq domash
aftermash:
  cmp w.rc, #16
  b.ne mixloop
  strh w.r0, [x.out]
  strh w.r1, [x.out, #2]
  strh w.r2, [x.out, #4]
  strh w.r3, [x.out, #6]
  .restore all
  ret

domash:
  ;; R[i] += K[R[(i+3)&3] & 63], sequential (uses updated R)
  and w.idx, w.r3, #63
  ldrh w.k, [x.K, w.idx, uxtw #1]
  add w.r0, w.r0, w.k
  and w.r0, w.r0, w.mask
  and w.idx, w.r0, #63
  ldrh w.k, [x.K, w.idx, uxtw #1]
  add w.r1, w.r1, w.k
  and w.r1, w.r1, w.mask
  and w.idx, w.r1, #63
  ldrh w.k, [x.K, w.idx, uxtw #1]
  add w.r2, w.r2, w.k
  and w.r2, w.r2, w.mask
  and w.idx, w.r2, #63
  ldrh w.k, [x.K, w.idx, uxtw #1]
  add w.r3, w.r3, w.k
  and w.r3, w.r3, w.mask
  b aftermash
.end

;; void rc2_dec_core_asm(const uint16_t *K, const unsigned char in[8],
;;                       unsigned char out[8]);   -- inverse of rc2_enc_core_asm
.function rc2_dec_core_asm export (
  in: x.K, x.in, x.out
)
entry:
  .save all
  ldrh w.r0, [x.in]
  ldrh w.r1, [x.in, #2]
  ldrh w.r2, [x.in, #4]
  ldrh w.r3, [x.in, #6]
  mov w.j, #63
  mov w.rc, #15
  mov w.mask, #0xffff
decloop:
  cmp w.rc, #10
  b.eq dmash
  cmp w.rc, #4
  b.eq dmash
afterdmash:
  ;; R-MIX i=3: s=5 im1=r2 im2=r1 im3=r0
  orr w.tmp, w.r3, w.r3, lsl #16
  ror w.tmp, w.tmp, #5
  and w.r3, w.tmp, w.mask
  and w.t, w.r1, w.r2
  bic w.t2, w.r0, w.r2
  orr w.sel, w.t, w.t2
  ldrh w.k, [x.K, w.j, uxtw #1]
  sub w.j, w.j, #1
  sub w.r3, w.r3, w.k
  sub w.r3, w.r3, w.sel
  and w.r3, w.r3, w.mask
  ;; R-MIX i=2: s=3 im1=r1 im2=r0 im3=r3
  orr w.tmp, w.r2, w.r2, lsl #16
  ror w.tmp, w.tmp, #3
  and w.r2, w.tmp, w.mask
  and w.t, w.r0, w.r1
  bic w.t2, w.r3, w.r1
  orr w.sel, w.t, w.t2
  ldrh w.k, [x.K, w.j, uxtw #1]
  sub w.j, w.j, #1
  sub w.r2, w.r2, w.k
  sub w.r2, w.r2, w.sel
  and w.r2, w.r2, w.mask
  ;; R-MIX i=1: s=2 im1=r0 im2=r3 im3=r2
  orr w.tmp, w.r1, w.r1, lsl #16
  ror w.tmp, w.tmp, #2
  and w.r1, w.tmp, w.mask
  and w.t, w.r3, w.r0
  bic w.t2, w.r2, w.r0
  orr w.sel, w.t, w.t2
  ldrh w.k, [x.K, w.j, uxtw #1]
  sub w.j, w.j, #1
  sub w.r1, w.r1, w.k
  sub w.r1, w.r1, w.sel
  and w.r1, w.r1, w.mask
  ;; R-MIX i=0: s=1 im1=r3 im2=r2 im3=r1
  orr w.tmp, w.r0, w.r0, lsl #16
  ror w.tmp, w.tmp, #1
  and w.r0, w.tmp, w.mask
  and w.t, w.r2, w.r3
  bic w.t2, w.r1, w.r3
  orr w.sel, w.t, w.t2
  ldrh w.k, [x.K, w.j, uxtw #1]
  sub w.j, w.j, #1
  sub w.r0, w.r0, w.k
  sub w.r0, w.r0, w.sel
  and w.r0, w.r0, w.mask

  subs w.rc, w.rc, #1
  b.ge decloop
  strh w.r0, [x.out]
  strh w.r1, [x.out, #2]
  strh w.r2, [x.out, #4]
  strh w.r3, [x.out, #6]
  .restore all
  ret

dmash:
  ;; R-MASH i=3,2,1,0: R[i] -= K[R[(i+3)&3] & 63]  (inverse order)
  and w.idx, w.r2, #63
  ldrh w.k, [x.K, w.idx, uxtw #1]
  sub w.r3, w.r3, w.k
  and w.r3, w.r3, w.mask
  and w.idx, w.r1, #63
  ldrh w.k, [x.K, w.idx, uxtw #1]
  sub w.r2, w.r2, w.k
  and w.r2, w.r2, w.mask
  and w.idx, w.r0, #63
  ldrh w.k, [x.K, w.idx, uxtw #1]
  sub w.r1, w.r1, w.k
  and w.r1, w.r1, w.mask
  and w.idx, w.r3, #63
  ldrh w.k, [x.K, w.idx, uxtw #1]
  sub w.r0, w.r0, w.k
  and w.r0, w.r0, w.mask
  b afterdmash
.end
