;; ChaCha20 keystream XOR on AVX2 (x86-64 SysV), the tier for CPUs without AVX-512: eight
;; blocks per 512-byte unit in the state-in-lanes layout (register i holds word i of the
;; eight blocks). Sixteen ymm registers cannot hold the state and a scratch register, so
;; the d row lives in frame slots (unaligned moves: the frame is only 16-byte aligned): a quarter round pulls its d word into a scratch
;; register, uses it for both halves and writes it back once. Rotations by 16 and 8 are
;; byte shuffles with memory masks, 12 and 7 a shift pair. Two quarter rounds are
;; interleaved in program order (a, b, c rows + two d scratch + two shift scratch = 16),
;; the other two follow; the out-of-order window overlaps all four.
;;   void rktcrypto_chacha20_blocks_avx2(uint32_t state[16], const unsigned char *in,
;;                                       unsigned char *out, intptr_t units)
;; units = number of 512-byte units; state[12] advances by 8 per unit (mod 2^32).
;; Oracle: chacha20_core through rktcrypto_chacha20_xor with AVX2 and AVX-512 disabled;
;; gate: asm/tests/test_chacha20_avx512.c (which also clears AVX-512 to reach this tier).

.rodata chacha20_avx2_rol16 align=32
  .byte 2, 3, 0, 1, 6, 7, 4, 5, 10, 11, 8, 9, 14, 15, 12, 13
  .byte 2, 3, 0, 1, 6, 7, 4, 5, 10, 11, 8, 9, 14, 15, 12, 13
.end
.rodata chacha20_avx2_rol8 align=32
  .byte 3, 0, 1, 2, 7, 4, 5, 6, 11, 8, 9, 10, 15, 12, 13, 14
  .byte 3, 0, 1, 2, 7, 4, 5, 6, 11, 8, 9, 10, 15, 12, 13, 14
.end
.rodata chacha20_avx2_idx align=32
  .long 0, 1, 2, 3, 4, 5, 6, 7
.end

;; two interleaved quarter rounds; d words in frame slots \d0 / \d1 (addresses), pulled into
;; ymm.t0 / ymm.t1, shift scratch ymm.s0 / ymm.s1
.macro QR2 a0, b0, c0, d0, a1, b1, c1, d1
  vpaddd \a0, \a0, \b0
  vpaddd \a1, \a1, \b1
  vpxor ymm.t0, \a0, ymmword ptr [\d0]
  vpxor ymm.t1, \a1, ymmword ptr [\d1]
  vpshufb ymm.t0, ymm.t0, ymmword ptr [rip + chacha20_avx2_rol16]
  vpshufb ymm.t1, ymm.t1, ymmword ptr [rip + chacha20_avx2_rol16]
  vpaddd \c0, \c0, ymm.t0
  vpaddd \c1, \c1, ymm.t1
  vpxor \b0, \b0, \c0
  vpxor \b1, \b1, \c1
  vpslld ymm.s0, \b0, 12
  vpslld ymm.s1, \b1, 12
  vpsrld \b0, \b0, 20
  vpsrld \b1, \b1, 20
  vpor \b0, \b0, ymm.s0
  vpor \b1, \b1, ymm.s1
  vpaddd \a0, \a0, \b0
  vpaddd \a1, \a1, \b1
  vpxor ymm.t0, ymm.t0, \a0
  vpxor ymm.t1, ymm.t1, \a1
  vpshufb ymm.t0, ymm.t0, ymmword ptr [rip + chacha20_avx2_rol8]
  vpshufb ymm.t1, ymm.t1, ymmword ptr [rip + chacha20_avx2_rol8]
  vpaddd \c0, \c0, ymm.t0
  vpaddd \c1, \c1, ymm.t1
  vmovdqu ymmword ptr [\d0], ymm.t0
  vmovdqu ymmword ptr [\d1], ymm.t1
  vpxor \b0, \b0, \c0
  vpxor \b1, \b1, \c1
  vpslld ymm.s0, \b0, 7
  vpslld ymm.s1, \b1, 7
  vpsrld \b0, \b0, 25
  vpsrld \b1, \b1, 25
  vpor \b0, \b0, ymm.s0
  vpor \b1, \b1, ymm.s1
.endm

;; frame: d row at 0..127 (slot j = 32 j), the sixteen finished words at 128..639 (word i = 128 + 32 i)
.function rktcrypto_chacha20_blocks_avx2 export (
  in: q.st, q.in, q.out, q.n
)
  .simd avx2
  .frame 640
  test q.n, q.n
  jz done
unit:
.for i, 0, 12
  vpbroadcastd ymm.x${i}, dword ptr [q.st + ${4 * i}]
.endfor
  vpbroadcastd ymm.t0, dword ptr [q.st + 48]
  vpaddd ymm.t0, ymm.t0, ymmword ptr [rip + chacha20_avx2_idx]
  vmovdqu ymmword ptr [rsp + 0], ymm.t0
.for j, 1, 4
  vpbroadcastd ymm.t0, dword ptr [q.st + ${48 + 4 * j}]
  vmovdqu ymmword ptr [rsp + ${32 * j}], ymm.t0
.endfor
.for r, 0, 10
  QR2(ymm.x0, ymm.x4, ymm.x8, rsp + 0, ymm.x1, ymm.x5, ymm.x9, rsp + 32)
  QR2(ymm.x2, ymm.x6, ymm.x10, rsp + 64, ymm.x3, ymm.x7, ymm.x11, rsp + 96)
  QR2(ymm.x0, ymm.x5, ymm.x10, rsp + 96, ymm.x1, ymm.x6, ymm.x11, rsp + 0)
  QR2(ymm.x2, ymm.x7, ymm.x8, rsp + 32, ymm.x3, ymm.x4, ymm.x9, rsp + 64)
.endfor
  ;; original state back, every word to the frame
.for i, 0, 12
  vpbroadcastd ymm.t0, dword ptr [q.st + ${4 * i}]
  vpaddd ymm.x${i}, ymm.x${i}, ymm.t0
  vmovdqu ymmword ptr [rsp + ${128 + 32 * i}], ymm.x${i}
.endfor
  vpbroadcastd ymm.t0, dword ptr [q.st + 48]
  vpaddd ymm.t0, ymm.t0, ymmword ptr [rip + chacha20_avx2_idx]
  vpaddd ymm.t0, ymm.t0, ymmword ptr [rsp + 0]
  vmovdqu ymmword ptr [rsp + ${128 + 32 * 12}], ymm.t0
.for j, 1, 4
  vpbroadcastd ymm.t0, dword ptr [q.st + ${48 + 4 * j}]
  vpaddd ymm.t0, ymm.t0, ymmword ptr [rsp + ${32 * j}]
  vmovdqu ymmword ptr [rsp + ${128 + 32 * (12 + j)}], ymm.t0
.endfor
  ;; transpose, two word groups at a time (register budget): group g of four words ->
  ;; u_j with lane L = words 4g..4g+3 of block 4L+j; the pair of groups (0,1) gives each
  ;; block's first 32 bytes, (2,3) the second; output block 4L+j = lane L of u_j of both
.for half, 0, 2
  .for g, 2 * half, 2 * half + 2
  vmovdqu ymm.w0, ymmword ptr [rsp + ${128 + 32 * (4 * g)}]
  vmovdqu ymm.w1, ymmword ptr [rsp + ${128 + 32 * (4 * g + 1)}]
  vmovdqu ymm.w2, ymmword ptr [rsp + ${128 + 32 * (4 * g + 2)}]
  vmovdqu ymm.w3, ymmword ptr [rsp + ${128 + 32 * (4 * g + 3)}]
  vpunpckldq ymm.p0, ymm.w0, ymm.w1
  vpunpckhdq ymm.p1, ymm.w0, ymm.w1
  vpunpckldq ymm.p2, ymm.w2, ymm.w3
  vpunpckhdq ymm.p3, ymm.w2, ymm.w3
  vpunpcklqdq ymm.g${g % 2}_0, ymm.p0, ymm.p2
  vpunpckhqdq ymm.g${g % 2}_1, ymm.p0, ymm.p2
  vpunpcklqdq ymm.g${g % 2}_2, ymm.p1, ymm.p3
  vpunpckhqdq ymm.g${g % 2}_3, ymm.p1, ymm.p3
  .endfor
  .for j, 0, 4
   .for L, 0, 2
  vperm2i128 ymm.o0, ymm.g0_${j}, ymm.g1_${j}, ${if L == 0 {0x20} else {0x31}}
  vpxor ymm.o0, ymm.o0, ymmword ptr [q.in + ${64 * (4 * L + j) + 32 * half}]
  vmovdqu ymmword ptr [q.out + ${64 * (4 * L + j) + 32 * half}], ymm.o0
   .endfor
  .endfor
.endfor
  add dword ptr [q.st + 48], 8
  add q.in, 512
  add q.out, 512
  sub q.n, 1
  jnz unit
done:
  ret
.end
