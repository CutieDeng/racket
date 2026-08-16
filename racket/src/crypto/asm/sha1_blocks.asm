;; Multi-block ARMv8 SHA-1 compress (sha1c/p/m + sha1h + sha1su0/su1).
;; State (ABCD,E) stays in vector registers across all blocks -- no per-block
;; ctx round-trip. The instruction schedule mirrors OpenSSL's hardware path,
;; which clang schedules ~7% worse on Apple M. ~20 ns/block.
.function sha1_blocks_asm export (
  in: x.st, x.p, x.num
)
entry:
  movz w.t, #31129
  movk w.t, #23170, lsl #16
  dup v.k0.4s, w.t
  movz w.t, #60321
  movk w.t, #28377, lsl #16
  dup v.k1.4s, w.t
  movz w.t, #48348
  movk w.t, #36635, lsl #16
  dup v.k2.4s, w.t
  movz w.t, #49622
  movk w.t, #51810, lsl #16
  dup v.k3.4s, w.t
  ld1 { v.abcd.4s }, [x.st]
  ldr s.e, [x.st, #16]
loop:
  ld1 { v.m0.4s, v.m1.4s, v.m2.4s, v.m3.4s }, [x.p], #64
  subs x.num, x.num, #1
  rev32 v.m0.16b, v.m0.16b
  rev32 v.m1.16b, v.m1.16b
  add v.w0.4s, v.k0.4s, v.m0.4s
  rev32 v.m2.16b, v.m2.16b
  mov v.abcd0.16b, v.abcd.16b
  add v.w1.4s, v.k0.4s, v.m1.4s
  rev32 v.m3.16b, v.m3.16b
  sha1h s.e1, s.abcd
  sha1c q.abcd, s.e, v.w0.4s
  add v.w0.4s, v.k0.4s, v.m2.4s
  sha1su0 v.m0.4s, v.m1.4s, v.m2.4s
  sha1h s.e0, s.abcd
  sha1c q.abcd, s.e1, v.w1.4s
  add v.w1.4s, v.k0.4s, v.m3.4s
  sha1su1 v.m0.4s, v.m3.4s
  sha1su0 v.m1.4s, v.m2.4s, v.m3.4s
  sha1h s.e1, s.abcd
  sha1c q.abcd, s.e0, v.w0.4s
  add v.w0.4s, v.k0.4s, v.m0.4s
  sha1su1 v.m1.4s, v.m0.4s
  sha1su0 v.m2.4s, v.m3.4s, v.m0.4s
  sha1h s.e0, s.abcd
  sha1c q.abcd, s.e1, v.w1.4s
  add v.w1.4s, v.k1.4s, v.m1.4s
  sha1su1 v.m2.4s, v.m1.4s
  sha1su0 v.m3.4s, v.m0.4s, v.m1.4s
  sha1h s.e1, s.abcd
  sha1c q.abcd, s.e0, v.w0.4s
  add v.w0.4s, v.k1.4s, v.m2.4s
  sha1su1 v.m3.4s, v.m2.4s
  sha1su0 v.m0.4s, v.m1.4s, v.m2.4s
  sha1h s.e0, s.abcd
  sha1p q.abcd, s.e1, v.w1.4s
  add v.w1.4s, v.k1.4s, v.m3.4s
  sha1su1 v.m0.4s, v.m3.4s
  sha1su0 v.m1.4s, v.m2.4s, v.m3.4s
  sha1h s.e1, s.abcd
  sha1p q.abcd, s.e0, v.w0.4s
  add v.w0.4s, v.k1.4s, v.m0.4s
  sha1su1 v.m1.4s, v.m0.4s
  sha1su0 v.m2.4s, v.m3.4s, v.m0.4s
  sha1h s.e0, s.abcd
  sha1p q.abcd, s.e1, v.w1.4s
  add v.w1.4s, v.k1.4s, v.m1.4s
  sha1su1 v.m2.4s, v.m1.4s
  sha1su0 v.m3.4s, v.m0.4s, v.m1.4s
  sha1h s.e1, s.abcd
  sha1p q.abcd, s.e0, v.w0.4s
  add v.w0.4s, v.k2.4s, v.m2.4s
  sha1su1 v.m3.4s, v.m2.4s
  sha1su0 v.m0.4s, v.m1.4s, v.m2.4s
  sha1h s.e0, s.abcd
  sha1p q.abcd, s.e1, v.w1.4s
  add v.w1.4s, v.k2.4s, v.m3.4s
  sha1su1 v.m0.4s, v.m3.4s
  sha1su0 v.m1.4s, v.m2.4s, v.m3.4s
  sha1h s.e1, s.abcd
  sha1m q.abcd, s.e0, v.w0.4s
  add v.w0.4s, v.k2.4s, v.m0.4s
  sha1su1 v.m1.4s, v.m0.4s
  sha1su0 v.m2.4s, v.m3.4s, v.m0.4s
  sha1h s.e0, s.abcd
  sha1m q.abcd, s.e1, v.w1.4s
  add v.w1.4s, v.k2.4s, v.m1.4s
  sha1su1 v.m2.4s, v.m1.4s
  sha1su0 v.m3.4s, v.m0.4s, v.m1.4s
  sha1h s.e1, s.abcd
  sha1m q.abcd, s.e0, v.w0.4s
  add v.w0.4s, v.k2.4s, v.m2.4s
  sha1su1 v.m3.4s, v.m2.4s
  sha1su0 v.m0.4s, v.m1.4s, v.m2.4s
  sha1h s.e0, s.abcd
  sha1m q.abcd, s.e1, v.w1.4s
  add v.w1.4s, v.k3.4s, v.m3.4s
  sha1su1 v.m0.4s, v.m3.4s
  sha1su0 v.m1.4s, v.m2.4s, v.m3.4s
  sha1h s.e1, s.abcd
  sha1m q.abcd, s.e0, v.w0.4s
  add v.w0.4s, v.k3.4s, v.m0.4s
  sha1su1 v.m1.4s, v.m0.4s
  sha1su0 v.m2.4s, v.m3.4s, v.m0.4s
  sha1h s.e0, s.abcd
  sha1p q.abcd, s.e1, v.w1.4s
  add v.w1.4s, v.k3.4s, v.m1.4s
  sha1su1 v.m2.4s, v.m1.4s
  sha1su0 v.m3.4s, v.m0.4s, v.m1.4s
  sha1h s.e1, s.abcd
  sha1p q.abcd, s.e0, v.w0.4s
  add v.w0.4s, v.k3.4s, v.m2.4s
  sha1su1 v.m3.4s, v.m2.4s
  sha1h s.e0, s.abcd
  sha1p q.abcd, s.e1, v.w1.4s
  add v.w1.4s, v.k3.4s, v.m3.4s
  sha1h s.e1, s.abcd
  sha1p q.abcd, s.e0, v.w0.4s
  sha1h s.e0, s.abcd
  sha1p q.abcd, s.e1, v.w1.4s
  add v.e.4s, v.e.4s, v.e0.4s
  add v.abcd.4s, v.abcd.4s, v.abcd0.4s
  b.ne loop
  st1 { v.abcd.4s }, [x.st]
  str s.e, [x.st, #16]
  ret
.end
