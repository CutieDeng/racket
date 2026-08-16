;; SEED (RFC 4269) 16-round Feistel core (AArch64), hand-scheduled in rktasm.
;; G(x) = SS0[x&255] ^ SS1[(x>>8)&255] ^ SS2[(x>>16)&255] ^ SS3[(x>>24)&255]
;; (byte lanes via ror+mask, `ldr [SSn, byte, uxtw #2]`, SSn = SS + n*1024).
;; F(R0,R1,K0,K1): T0=R0^K0; T1=R1^K1; T1^=T0; T1=G(T1); T0+=T1; T0=G(T0);
;; T1+=T0; T1=G(T1); T0+=T1. Round: newL=R; newR=L^F. The C driver orders the
;; 32 round-key words for the direction (enc rounds 0..15, dec 15..0) so the
;; kernel iterates forward. Oracle: seed_crypt portable; gate: test_seed.c.
;;
;; void seed_core_asm(const uint32_t *rk, const uint32_t *SS, uint32_t io[4]);
;;   io[0..3] = L0,L1,R0,R1 in/out (big-endian words done by the C caller).
.function seed_core_asm export (
  in: x.rk, x.SS, x.io
)
entry:
  .save all
  add x.S1, x.SS, #1024
  add x.S2, x.SS, #2048
  add x.S3, x.SS, #3072
  ldr w.L0, [x.io]
  ldr w.L1, [x.io, #4]
  ldr w.R0, [x.io, #8]
  ldr w.R1, [x.io, #12]
  mov w.mask, #0xff
  mov x.cnt, #16
loop:
  ldr w.K0, [x.rk], #4
  ldr w.K1, [x.rk], #4
  eor w.T0, w.R0, w.K0
  eor w.T1, w.R1, w.K1
  eor w.T1, w.T1, w.T0
  ;; T1 = G(T1)
  and w.i, w.T1, w.mask
  ldr w.g, [x.SS, w.i, uxtw #2]
  ror w.t, w.T1, #8
  and w.i, w.t, w.mask
  ldr w.tt, [x.S1, w.i, uxtw #2]
  eor w.g, w.g, w.tt
  ror w.t, w.T1, #16
  and w.i, w.t, w.mask
  ldr w.tt, [x.S2, w.i, uxtw #2]
  eor w.g, w.g, w.tt
  ror w.t, w.T1, #24
  and w.i, w.t, w.mask
  ldr w.tt, [x.S3, w.i, uxtw #2]
  eor w.T1, w.g, w.tt
  ;; T0 += T1; T0 = G(T0)
  add w.T0, w.T0, w.T1
  and w.i, w.T0, w.mask
  ldr w.g, [x.SS, w.i, uxtw #2]
  ror w.t, w.T0, #8
  and w.i, w.t, w.mask
  ldr w.tt, [x.S1, w.i, uxtw #2]
  eor w.g, w.g, w.tt
  ror w.t, w.T0, #16
  and w.i, w.t, w.mask
  ldr w.tt, [x.S2, w.i, uxtw #2]
  eor w.g, w.g, w.tt
  ror w.t, w.T0, #24
  and w.i, w.t, w.mask
  ldr w.tt, [x.S3, w.i, uxtw #2]
  eor w.T0, w.g, w.tt
  ;; T1 += T0; T1 = G(T1)
  add w.T1, w.T1, w.T0
  and w.i, w.T1, w.mask
  ldr w.g, [x.SS, w.i, uxtw #2]
  ror w.t, w.T1, #8
  and w.i, w.t, w.mask
  ldr w.tt, [x.S1, w.i, uxtw #2]
  eor w.g, w.g, w.tt
  ror w.t, w.T1, #16
  and w.i, w.t, w.mask
  ldr w.tt, [x.S2, w.i, uxtw #2]
  eor w.g, w.g, w.tt
  ror w.t, w.T1, #24
  and w.i, w.t, w.mask
  ldr w.tt, [x.S3, w.i, uxtw #2]
  eor w.T1, w.g, w.tt
  ;; T0 += T1
  add w.T0, w.T0, w.T1
  ;; newL = R; newR = L ^ (T0,T1)
  eor w.n0, w.L0, w.T0
  eor w.n1, w.L1, w.T1
  mov w.L0, w.R0
  mov w.L1, w.R1
  mov w.R0, w.n0
  mov w.R1, w.n1
  subs x.cnt, x.cnt, #1
  b.ne loop
  ;; output = (R, L)
  str w.R0, [x.io]
  str w.R1, [x.io, #4]
  str w.L0, [x.io, #8]
  str w.L1, [x.io, #12]
  .restore all
  ret
.end
