;; Blowfish 16-round Feistel core (AArch64), hand-scheduled in rktasm. Operates on
;; the two 32-bit halves L,R (uint32, big-endian conversion is the C caller's job).
;; F(x) = ((S0[x>>24] + S1[(x>>16)&255]) ^ S2[(x>>8)&255]) + S3[x&255]; the byte
;; lanes are ror + `ldr [Sn, w, uxtb #2]` (uxtb extract avoids the unsupported
;; immediate AND). One kernel serves both directions via a P-array start pointer
;; and a +4/-4 stride: encrypt = (&P[0], +4), decrypt = (&P[17], -4); after the
;; 16 rounds P points at P[16]/P[1] and the two output-whitening subkeys are
;; *P and *(P+stride). Key schedule + block loop stay in C.
;; Oracle: bf_enc/bf_dec portable (bit-exact); gate: asm/tests/test_bf.c.
;;
;; void bf_core_asm(const uint32_t *P, const uint32_t *S, uint32_t io[2],
;;                  intptr_t stride);   // io[0]=L io[1]=R in/out; stride = +/-4
.function bf_core_asm export (
  in: x.P, x.S, x.io, x.stride
)
entry:
  .save all
  add x.S1, x.S, #1024
  add x.S2, x.S, #2048
  add x.S3, x.S, #3072
  ldr w.L, [x.io]
  ldr w.R, [x.io, #4]
  mov x.cnt, #16
  mov w.mask, #0xff
loop:
  ldr w.p, [x.P]
  add x.P, x.P, x.stride
  eor w.L, w.L, w.p
  ;; F(L): byte lanes via ror + mask (uxtb load-extend is not encodable)
  ror w.t, w.L, #24
  and w.idx, w.t, w.mask
  ldr w.a, [x.S, w.idx, uxtw #2]
  ror w.t, w.L, #16
  and w.idx, w.t, w.mask
  ldr w.b, [x.S1, w.idx, uxtw #2]
  ror w.t, w.L, #8
  and w.idx, w.t, w.mask
  ldr w.c, [x.S2, w.idx, uxtw #2]
  and w.idx, w.L, w.mask
  ldr w.d, [x.S3, w.idx, uxtw #2]
  add w.f, w.a, w.b
  eor w.f, w.f, w.c
  add w.f, w.f, w.d
  eor w.R, w.R, w.f
  ;; swap L,R
  mov w.t, w.L
  mov w.L, w.R
  mov w.R, w.t
  subs x.cnt, x.cnt, #1
  b.ne loop
  ;; undo the final swap, then output whitening
  mov w.t, w.L
  mov w.L, w.R
  mov w.R, w.t
  ldr w.p, [x.P]
  eor w.R, w.R, w.p
  ldr w.p, [x.P, x.stride]
  eor w.L, w.L, w.p
  str w.L, [x.io]
  str w.R, [x.io, #4]
  .restore all
  ret
.end
