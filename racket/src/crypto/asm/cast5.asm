;; CAST-128 (RFC 2144) 16-round Feistel core (AArch64), hand-scheduled in rktasm.
;; The 3 CAST round-function types (i%3) differ in how I is formed (Km+D, Km^D,
;; Km-D) and how the four S-box lookups combine; the C driver precomputes, for
;; the requested direction, the per-round masking key Km[r], rotation Kr[r] and a
;; type byte typ[r] (enc: i=0..15, dec: i=15..0), so this kernel just iterates
;; forward and branches on the type. ROL by Kr = ror by -Kr. Lookups: Sn = S +
;; n*1024, `ldr [Sn, byte, uxtw #2]`. Oracle: cast_crypt portable; gate: test_cast5.c
;;
;; void cast_core_asm(const uint32_t *Km, const uint32_t *Kr,
;;                    const unsigned char *typ, const uint32_t *S, uint32_t io[2]);
.function cast_core_asm export (
  in: x.Km, x.Kr, x.typ, x.S, x.io
)
entry:
  .save all
  add x.S2, x.S, #1024
  add x.S3, x.S, #2048
  add x.S4, x.S, #3072
  ldr w.L, [x.io]
  ldr w.R, [x.io, #4]
  mov w.mask, #0xff
  mov x.cnt, #16
loop:
  ldr w.km, [x.Km], #4
  ldr w.kr, [x.Kr], #4
  ldrb w.ty, [x.typ], #1
  ;; I = ROL(op(Km,R), Kr)  -- op by type
  cmp w.ty, #0
  b.eq iadd
  cmp w.ty, #1
  b.eq ixor
  sub w.md, w.km, w.R
  b idone
iadd:
  add w.md, w.km, w.R
  b idone
ixor:
  eor w.md, w.km, w.R
idone:
  neg w.rr, w.kr
  ror w.I, w.md, w.rr
  ;; four S-box lookups
  ror w.t, w.I, #24
  and w.idx, w.t, w.mask
  ldr w.a, [x.S, w.idx, uxtw #2]
  ror w.t, w.I, #16
  and w.idx, w.t, w.mask
  ldr w.b, [x.S2, w.idx, uxtw #2]
  ror w.t, w.I, #8
  and w.idx, w.t, w.mask
  ldr w.c, [x.S3, w.idx, uxtw #2]
  and w.idx, w.I, w.mask
  ldr w.d, [x.S4, w.idx, uxtw #2]
  ;; combine by type
  cmp w.ty, #0
  b.eq cadd
  cmp w.ty, #1
  b.eq cxor
  ;; type2: ((a+b)^c)-d
  add w.f, w.a, w.b
  eor w.f, w.f, w.c
  sub w.f, w.f, w.d
  b cdone
cadd:
  ;; type0: ((a^b)-c)+d
  eor w.f, w.a, w.b
  sub w.f, w.f, w.c
  add w.f, w.f, w.d
  b cdone
cxor:
  ;; type1: ((a-b)+c)^d
  sub w.f, w.a, w.b
  add w.f, w.f, w.c
  eor w.f, w.f, w.d
cdone:
  ;; Feistel: newR = L ^ F; L = R; R = newR
  eor w.nr, w.L, w.f
  mov w.L, w.R
  mov w.R, w.nr
  subs x.cnt, x.cnt, #1
  b.ne loop
  ;; output = (R, L)
  str w.R, [x.io]
  str w.L, [x.io, #4]
  .restore all
  ret
.end
