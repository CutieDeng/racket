;; Poly1305 block loop in radix 2^64 on MULX (x86-64 SysV). The accumulator h is
;; three 64-bit limbs (h2 small), r is clamped 128-bit (r0, r1) with s1 = r1 + r1>>2
;; precomputed; each block adds the 16 message bytes plus the high bit, multiplies by r
;; with four mulx and two imul, and does the 2^130 = 5 partial reduction.
;;   void rktcrypto_poly1305_blocks_x86(uint64_t h[3], const uint64_t r[3] /* r0 r1 s1 */,
;;                                      const unsigned char *m, intptr_t nblk, uint64_t hibit)
;; The message pointer arrives in rdx, which mulx needs, so it is moved out first.
;; Oracle: poly1305_blocks (rktcrypto_poly1305.c, radix 2^26) through rktcrypto_poly1305_update
;; with the BMI2/ADX feature bit cleared; gate: asm/tests/test_poly1305_x86.c.

.function rktcrypto_poly1305_blocks_x86 export (
  in: q.hp, q.rp, rdx, q.n, q.hibit
)
  mov q.m, rdx
  test q.n, q.n
  jz done
  mov q.h0, qword ptr [q.hp]
  mov q.h1, qword ptr [q.hp + 8]
  mov q.h2, qword ptr [q.hp + 16]
  mov q.r0, qword ptr [q.rp]
  mov q.r1, qword ptr [q.rp + 8]
  mov q.s1, qword ptr [q.rp + 16]
blk:
  add q.h0, qword ptr [q.m]
  adc q.h1, qword ptr [q.m + 8]
  adc q.h2, q.hibit
  mov rdx, q.h0
  mulx q.d1, q.n0, q.r0                     ; d1:n0 = h0*r0
  mulx q.d3, q.d2, q.r1                     ; d3:d2 = h0*r1
  mov rdx, q.h1
  mulx q.t1, q.t0, q.r0                     ; t1:t0 = h1*r0
  add q.d2, q.t0
  adc q.d3, q.t1
  mulx q.t1, q.t0, q.s1                     ; t1:t0 = h1*s1
  add q.n0, q.t0
  adc q.d1, q.t1
  mov q.t0, q.h2
  imul q.t0, q.s1                           ; h2*s1
  add q.d2, q.t0
  adc q.d3, 0
  imul q.h2, q.r0                           ; h2*r0
  add q.d1, q.d2
  adc q.d3, q.h2
  mov q.h0, q.n0
  mov q.h1, q.d1
  mov q.t0, -4
  and q.t0, q.d3                            ; (d3 & ~3)
  mov q.h2, q.d3
  shr q.d3, 2
  and q.h2, 3
  add q.t0, q.d3                            ; (d3 & ~3) + (d3 >> 2) = 5 * (d3 >> 2)
  add q.h0, q.t0
  adc q.h1, 0
  adc q.h2, 0
  add q.m, 16
  sub q.n, 1
  jnz blk
  mov qword ptr [q.hp], q.h0
  mov qword ptr [q.hp + 8], q.h1
  mov qword ptr [q.hp + 16], q.h2
done:
  ret
.end
