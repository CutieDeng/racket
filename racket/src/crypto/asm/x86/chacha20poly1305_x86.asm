;; Fused ChaCha20 + Poly1305 unit loop on AVX-512 + MULX (x86-64 SysV): each iteration
;; produces one 1024-byte unit of ChaCha20 keystream XOR (sixteen blocks, the same code
;; as chacha20_avx512.asm) while the scalar Poly1305 absorbs the 64 blocks of the PREVIOUS
;; unit's ciphertext; the 64 Poly1305 blocks are spread over the 40 ChaCha half-rounds so
;; both chains stay inside the out-of-order window (vector pipes and the integer
;; multiplier run concurrently).
;;   void rktcrypto_chacha20poly1305_units_x86(uint32_t state[16], const unsigned char *in,
;;                                             unsigned char *out, intptr_t units,
;;                                             const unsigned char *mac, uint64_t hr[6])
;; mac points at the ciphertext of the unit preceding `in` (out - 1024 when encrypting,
;; in - 1024 when decrypting); hr = {h0, h1, h2, r0, r1, s1} in radix 2^64 (h updated).
;; The caller runs unit 0 on the plain ChaCha20 kernel and absorbs the last unit afterwards.
;; The output pointer arrives in rdx, which mulx needs, so it is moved out first.
;; Oracle: the two-pass path; gate: asm/tests/test_chacha20poly1305_x86.c.

.rodata chacha20poly1305_x86_idx align=64
  .long 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
.end

.function rktcrypto_chacha20poly1305_units_x86 export (
  in: q.st, q.in, rdx, q.n, q.mac, q.hr
)
  .simd avx512
  mov q.out, rdx
  test q.n, q.n
  jz done
  mov q.h0, qword ptr [q.hr]
  mov q.h1, qword ptr [q.hr + 8]
  mov q.h2, qword ptr [q.hr + 16]
  vmovdqa64 zmm.idx, zmmword ptr [rip + chacha20poly1305_x86_idx]
unit:
.for i, 0, 16
  vpbroadcastd zmm.x${i}, dword ptr [q.st + ${4 * i}]
.endfor
  vpaddd zmm.x12, zmm.x12, zmm.idx
.for r, 0, 10
 .for ph, 0, 2
  .for h, 0, 2
   .for c, 0, 4
  vpaddd zmm.x${c}, zmm.x${c}, zmm.x${4 + (c + ph) % 4}
   .endfor
   .for c, 0, 4
  vpxord zmm.x${12 + (c + 3 * ph) % 4}, zmm.x${12 + (c + 3 * ph) % 4}, zmm.x${c}
   .endfor
   .for c, 0, 4
  vprold zmm.x${12 + (c + 3 * ph) % 4}, zmm.x${12 + (c + 3 * ph) % 4}, ${if h == 0 {16} else {8}}
   .endfor
   .for c, 0, 4
  vpaddd zmm.x${8 + (c + 2 * ph) % 4}, zmm.x${8 + (c + 2 * ph) % 4}, zmm.x${12 + (c + 3 * ph) % 4}
   .endfor
   .for c, 0, 4
  vpxord zmm.x${4 + (c + ph) % 4}, zmm.x${4 + (c + ph) % 4}, zmm.x${8 + (c + 2 * ph) % 4}
   .endfor
   .for c, 0, 4
  vprold zmm.x${4 + (c + ph) % 4}, zmm.x${4 + (c + ph) % 4}, ${if h == 0 {12} else {7}}
   .endfor
   ;; Poly1305 blocks of the previous unit, 64 spread over the 40 half-rounds
   .for k, (r * 4 + ph * 2 + h) * 64 / 40, (r * 4 + ph * 2 + h + 1) * 64 / 40
  add q.h0, qword ptr [q.mac + ${16 * k}]
  adc q.h1, qword ptr [q.mac + ${16 * k + 8}]
  adc q.h2, 1
  mov rdx, q.h0
  mulx q.d1, q.n0, qword ptr [q.hr + 24]           ; d1:n0 = h0*r0
  mulx q.d3, q.d2, qword ptr [q.hr + 32]           ; d3:d2 = h0*r1
  mov rdx, q.h1
  mulx q.p1, q.p0, qword ptr [q.hr + 24]           ; t1:t0 = h1*r0
  add q.d2, q.p0
  adc q.d3, q.p1
  mulx q.p1, q.p0, qword ptr [q.hr + 40]           ; t1:t0 = h1*s1
  add q.n0, q.p0
  adc q.d1, q.p1
  mov q.p0, q.h2
  imul q.p0, qword ptr [q.hr + 40]                 ; h2*s1
  add q.d2, q.p0
  adc q.d3, 0
  imul q.h2, qword ptr [q.hr + 24]                 ; h2*r0
  add q.d1, q.d2
  adc q.d3, q.h2
  mov q.h0, q.n0
  mov q.h1, q.d1
  mov q.p0, -4
  and q.p0, q.d3
  mov q.h2, q.d3
  shr q.d3, 2
  and q.h2, 3
  add q.p0, q.d3
  add q.h0, q.p0
  adc q.h1, 0
  adc q.h2, 0
   .endfor
  .endfor
 .endfor
.endfor
.for i, 0, 12
  vpaddd zmm.x${i}, zmm.x${i}, dword ptr [q.st + ${4 * i}]{1to16}
.endfor
  vpbroadcastd zmm.t0, dword ptr [q.st + 48]
  vpaddd zmm.t0, zmm.t0, zmm.idx
  vpaddd zmm.x12, zmm.x12, zmm.t0
.for i, 13, 16
  vpaddd zmm.x${i}, zmm.x${i}, dword ptr [q.st + ${4 * i}]{1to16}
.endfor
.for g, 0, 4
  vpunpckldq zmm.t0, zmm.x${4 * g}, zmm.x${4 * g + 1}
  vpunpckhdq zmm.t1, zmm.x${4 * g}, zmm.x${4 * g + 1}
  vpunpckldq zmm.t2, zmm.x${4 * g + 2}, zmm.x${4 * g + 3}
  vpunpckhdq zmm.t3, zmm.x${4 * g + 2}, zmm.x${4 * g + 3}
  vpunpcklqdq zmm.x${4 * g}, zmm.t0, zmm.t2
  vpunpckhqdq zmm.x${4 * g + 1}, zmm.t0, zmm.t2
  vpunpcklqdq zmm.x${4 * g + 2}, zmm.t1, zmm.t3
  vpunpckhqdq zmm.x${4 * g + 3}, zmm.t1, zmm.t3
.endfor
.for m, 0, 4
  vshufi32x4 zmm.t0, zmm.x${m}, zmm.x${4 + m}, 0x44
  vshufi32x4 zmm.t1, zmm.x${m}, zmm.x${4 + m}, 0xee
  vshufi32x4 zmm.t2, zmm.x${8 + m}, zmm.x${12 + m}, 0x44
  vshufi32x4 zmm.t3, zmm.x${8 + m}, zmm.x${12 + m}, 0xee
  vshufi32x4 zmm.x${m}, zmm.t0, zmm.t2, 0x88
  vshufi32x4 zmm.x${4 + m}, zmm.t0, zmm.t2, 0xdd
  vshufi32x4 zmm.x${8 + m}, zmm.t1, zmm.t3, 0x88
  vshufi32x4 zmm.x${12 + m}, zmm.t1, zmm.t3, 0xdd
.endfor
.for b, 0, 16
  vpxord zmm.x${b}, zmm.x${b}, zmmword ptr [q.in + ${64 * b}]
  vmovdqu64 zmmword ptr [q.out + ${64 * b}], zmm.x${b}
.endfor
  add dword ptr [q.st + 48], 16
  add q.in, 1024
  add q.out, 1024
  add q.mac, 1024
  sub q.n, 1
  jnz unit
  mov qword ptr [q.hr], q.h0
  mov qword ptr [q.hr + 8], q.h1
  mov qword ptr [q.hr + 16], q.h2
done:
  ret
.end
