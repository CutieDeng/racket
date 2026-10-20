;; ChaCha20 keystream XOR on AVX-512 (x86-64 SysV): sixteen blocks per unit in the
;; state-in-lanes layout (register i holds word i of all sixteen blocks, lane b = block
;; b), rotations on vprold, the original state re-added from memory through embedded
;; broadcasts, then a 16x16 dword transpose (unpack, unpack, two vshufi32x4 stages) to
;; block order before the XOR with the input.
;;   void rktcrypto_chacha20_blocks_avx512(uint32_t state[16], const unsigned char *in,
;;                                         unsigned char *out, intptr_t units)
;; units = number of 1024-byte units; state[12] (the block counter) advances by 16 per
;; unit, wrapping mod 2^32 like the scalar code. Oracle: chacha20_core (rktcrypto_chacha20.c)
;; through rktcrypto_chacha20_xor with AVX-512 disabled; gate: asm/tests/test_chacha20_avx512.c.

.rodata chacha20_avx512_idx align=64
  .long 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
.end

.function rktcrypto_chacha20_blocks_avx512 export (
  in: q.st, q.in, q.out, q.n
)
  .simd avx512
  test q.n, q.n
  jz done
  vmovdqa64 zmm.idx, zmmword ptr [rip + chacha20_avx512_idx]
unit:
.for i, 0, 16
  vpbroadcastd zmm.x${i}, dword ptr [q.st + ${4 * i}]
.endfor
  vpaddd zmm.x12, zmm.x12, zmm.idx
  ;; 10 double rounds; ph 0 = columns, ph 1 = diagonals; h 0 = rotations 16/12, h 1 = 8/7
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
  .endfor
 .endfor
.endfor
  ;; add the original state (the counter word gets its per-lane index back)
.for i, 0, 12
  vpaddd zmm.x${i}, zmm.x${i}, dword ptr [q.st + ${4 * i}]{1to16}
.endfor
  vpbroadcastd zmm.t0, dword ptr [q.st + 48]
  vpaddd zmm.t0, zmm.t0, zmm.idx
  vpaddd zmm.x12, zmm.x12, zmm.t0
.for i, 13, 16
  vpaddd zmm.x${i}, zmm.x${i}, dword ptr [q.st + ${4 * i}]{1to16}
.endfor
  ;; transpose: after the two unpack stages, x[4g+m] lane L = words 4g..4g+3 of block 4L+m
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
  ;; lane stages: block 4L+m = (x[m].L, x[4+m].L, x[8+m].L, x[12+m].L) -> x[4L+m]
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
  sub q.n, 1
  jnz unit
done:
  ret
.end
