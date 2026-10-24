;; ChaCha20 keystream XOR on AVX2 (x86-64 SysV), the tier for CPUs without AVX-512: eight
;; blocks per 512-byte unit in the state-in-lanes layout (register i holds word i of the
;; eight blocks). Register plan: the a, b and d rows stay in registers (twelve), one pair of
;; the c row in two more, the other pair in frame slots; the pair a quarter-round pair needs
;; is invariant across the column/diagonal boundary, so the pairs are swapped once in the
;; middle of each round and the value reloaded is the one stored a round earlier (no
;; store-to-load forward on the critical path). Rotations by 16/8 are byte shuffles with
;; memory masks, 12/7 a shift pair into a scratch register; two quarter rounds interleaved.
;; The state words are smashed across lanes once into the frame (unaligned moves: the frame
;; is only 16-byte aligned); a unit reloads them with plain moves.
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

;; frame: c slots at 0..127 (c8 + 32 (i - 8)), the smashed state at 128..639 (word i = 128 + 32 i),
;; the sixteen finished words at 640..1151 (word i = 640 + 32 i)
.function rktcrypto_chacha20_blocks_avx2 export (
  in: q.st, q.in, q.out, q.n
)
  .simd avx2
  .frame 1152
  test q.n, q.n
  jz done
.for i, 0, 16
  .for z, if i == 12 {1} else {0}, 1
  vpbroadcastd ymm.t0, dword ptr [q.st + ${4 * i}]
  vmovdqu ymmword ptr [rsp + ${128 + 32 * i}], ymm.t0
  .endfor
.endfor
unit:
  vpbroadcastd ymm.x12, dword ptr [q.st + 48]
  vpaddd ymm.x12, ymm.x12, ymmword ptr [rip + chacha20_avx2_idx]
  vmovdqu ymmword ptr [rsp + 512], ymm.x12
.for i, 0, 8
  vmovdqu ymm.x${i}, ymmword ptr [rsp + ${128 + 32 * i}]
.endfor
.for i, 13, 16
  vmovdqu ymm.x${i}, ymmword ptr [rsp + ${128 + 32 * i}]
.endfor
  vmovdqu ymm.c0, ymmword ptr [rsp + 384]
  vmovdqu ymm.c1, ymmword ptr [rsp + 416]
  vmovdqu ymm.t0, ymmword ptr [rsp + 448]
  vmovdqu ymmword ptr [rsp + 64], ymm.t0
  vmovdqu ymm.t1, ymmword ptr [rsp + 480]
  vmovdqu ymmword ptr [rsp + 96], ymm.t1
.for r, 0, 10
  vpaddd ymm.x0, ymm.x0, ymm.x4
  vpaddd ymm.x1, ymm.x1, ymm.x5
  vpxor ymm.x12, ymm.x12, ymm.x0
  vpxor ymm.x13, ymm.x13, ymm.x1
  vpshufb ymm.x12, ymm.x12, ymmword ptr [rip + chacha20_avx2_rol16]
  vpshufb ymm.x13, ymm.x13, ymmword ptr [rip + chacha20_avx2_rol16]
  vpaddd ymm.c0, ymm.c0, ymm.x12
  vpaddd ymm.c1, ymm.c1, ymm.x13
  vpxor ymm.x4, ymm.x4, ymm.c0
  vpxor ymm.x5, ymm.x5, ymm.c1
  vpslld ymm.t0, ymm.x4, 12
  vpslld ymm.t1, ymm.x5, 12
  vpsrld ymm.x4, ymm.x4, 20
  vpsrld ymm.x5, ymm.x5, 20
  vpor ymm.x4, ymm.x4, ymm.t0
  vpor ymm.x5, ymm.x5, ymm.t1
  vpaddd ymm.x0, ymm.x0, ymm.x4
  vpaddd ymm.x1, ymm.x1, ymm.x5
  vpxor ymm.x12, ymm.x12, ymm.x0
  vpxor ymm.x13, ymm.x13, ymm.x1
  vpshufb ymm.x12, ymm.x12, ymmword ptr [rip + chacha20_avx2_rol8]
  vpshufb ymm.x13, ymm.x13, ymmword ptr [rip + chacha20_avx2_rol8]
  vpaddd ymm.c0, ymm.c0, ymm.x12
  vpaddd ymm.c1, ymm.c1, ymm.x13
  vpxor ymm.x4, ymm.x4, ymm.c0
  vpxor ymm.x5, ymm.x5, ymm.c1
  vpslld ymm.t0, ymm.x4, 7
  vpslld ymm.t1, ymm.x5, 7
  vpsrld ymm.x4, ymm.x4, 25
  vpsrld ymm.x5, ymm.x5, 25
  vpor ymm.x4, ymm.x4, ymm.t0
  vpor ymm.x5, ymm.x5, ymm.t1
  vmovdqu ymmword ptr [rsp + 0], ymm.c0
  vmovdqu ymmword ptr [rsp + 32], ymm.c1
  vmovdqu ymm.c0, ymmword ptr [rsp + 64]
  vmovdqu ymm.c1, ymmword ptr [rsp + 96]
  vpaddd ymm.x2, ymm.x2, ymm.x6
  vpaddd ymm.x3, ymm.x3, ymm.x7
  vpxor ymm.x14, ymm.x14, ymm.x2
  vpxor ymm.x15, ymm.x15, ymm.x3
  vpshufb ymm.x14, ymm.x14, ymmword ptr [rip + chacha20_avx2_rol16]
  vpshufb ymm.x15, ymm.x15, ymmword ptr [rip + chacha20_avx2_rol16]
  vpaddd ymm.c0, ymm.c0, ymm.x14
  vpaddd ymm.c1, ymm.c1, ymm.x15
  vpxor ymm.x6, ymm.x6, ymm.c0
  vpxor ymm.x7, ymm.x7, ymm.c1
  vpslld ymm.t0, ymm.x6, 12
  vpslld ymm.t1, ymm.x7, 12
  vpsrld ymm.x6, ymm.x6, 20
  vpsrld ymm.x7, ymm.x7, 20
  vpor ymm.x6, ymm.x6, ymm.t0
  vpor ymm.x7, ymm.x7, ymm.t1
  vpaddd ymm.x2, ymm.x2, ymm.x6
  vpaddd ymm.x3, ymm.x3, ymm.x7
  vpxor ymm.x14, ymm.x14, ymm.x2
  vpxor ymm.x15, ymm.x15, ymm.x3
  vpshufb ymm.x14, ymm.x14, ymmword ptr [rip + chacha20_avx2_rol8]
  vpshufb ymm.x15, ymm.x15, ymmword ptr [rip + chacha20_avx2_rol8]
  vpaddd ymm.c0, ymm.c0, ymm.x14
  vpaddd ymm.c1, ymm.c1, ymm.x15
  vpxor ymm.x6, ymm.x6, ymm.c0
  vpxor ymm.x7, ymm.x7, ymm.c1
  vpslld ymm.t0, ymm.x6, 7
  vpslld ymm.t1, ymm.x7, 7
  vpsrld ymm.x6, ymm.x6, 25
  vpsrld ymm.x7, ymm.x7, 25
  vpor ymm.x6, ymm.x6, ymm.t0
  vpor ymm.x7, ymm.x7, ymm.t1
  vpaddd ymm.x0, ymm.x0, ymm.x5
  vpaddd ymm.x1, ymm.x1, ymm.x6
  vpxor ymm.x15, ymm.x15, ymm.x0
  vpxor ymm.x12, ymm.x12, ymm.x1
  vpshufb ymm.x15, ymm.x15, ymmword ptr [rip + chacha20_avx2_rol16]
  vpshufb ymm.x12, ymm.x12, ymmword ptr [rip + chacha20_avx2_rol16]
  vpaddd ymm.c0, ymm.c0, ymm.x15
  vpaddd ymm.c1, ymm.c1, ymm.x12
  vpxor ymm.x5, ymm.x5, ymm.c0
  vpxor ymm.x6, ymm.x6, ymm.c1
  vpslld ymm.t0, ymm.x5, 12
  vpslld ymm.t1, ymm.x6, 12
  vpsrld ymm.x5, ymm.x5, 20
  vpsrld ymm.x6, ymm.x6, 20
  vpor ymm.x5, ymm.x5, ymm.t0
  vpor ymm.x6, ymm.x6, ymm.t1
  vpaddd ymm.x0, ymm.x0, ymm.x5
  vpaddd ymm.x1, ymm.x1, ymm.x6
  vpxor ymm.x15, ymm.x15, ymm.x0
  vpxor ymm.x12, ymm.x12, ymm.x1
  vpshufb ymm.x15, ymm.x15, ymmword ptr [rip + chacha20_avx2_rol8]
  vpshufb ymm.x12, ymm.x12, ymmword ptr [rip + chacha20_avx2_rol8]
  vpaddd ymm.c0, ymm.c0, ymm.x15
  vpaddd ymm.c1, ymm.c1, ymm.x12
  vpxor ymm.x5, ymm.x5, ymm.c0
  vpxor ymm.x6, ymm.x6, ymm.c1
  vpslld ymm.t0, ymm.x5, 7
  vpslld ymm.t1, ymm.x6, 7
  vpsrld ymm.x5, ymm.x5, 25
  vpsrld ymm.x6, ymm.x6, 25
  vpor ymm.x5, ymm.x5, ymm.t0
  vpor ymm.x6, ymm.x6, ymm.t1
  vmovdqu ymmword ptr [rsp + 64], ymm.c0
  vmovdqu ymmword ptr [rsp + 96], ymm.c1
  vmovdqu ymm.c0, ymmword ptr [rsp + 0]
  vmovdqu ymm.c1, ymmword ptr [rsp + 32]
  vpaddd ymm.x2, ymm.x2, ymm.x7
  vpaddd ymm.x3, ymm.x3, ymm.x4
  vpxor ymm.x13, ymm.x13, ymm.x2
  vpxor ymm.x14, ymm.x14, ymm.x3
  vpshufb ymm.x13, ymm.x13, ymmword ptr [rip + chacha20_avx2_rol16]
  vpshufb ymm.x14, ymm.x14, ymmword ptr [rip + chacha20_avx2_rol16]
  vpaddd ymm.c0, ymm.c0, ymm.x13
  vpaddd ymm.c1, ymm.c1, ymm.x14
  vpxor ymm.x7, ymm.x7, ymm.c0
  vpxor ymm.x4, ymm.x4, ymm.c1
  vpslld ymm.t0, ymm.x7, 12
  vpslld ymm.t1, ymm.x4, 12
  vpsrld ymm.x7, ymm.x7, 20
  vpsrld ymm.x4, ymm.x4, 20
  vpor ymm.x7, ymm.x7, ymm.t0
  vpor ymm.x4, ymm.x4, ymm.t1
  vpaddd ymm.x2, ymm.x2, ymm.x7
  vpaddd ymm.x3, ymm.x3, ymm.x4
  vpxor ymm.x13, ymm.x13, ymm.x2
  vpxor ymm.x14, ymm.x14, ymm.x3
  vpshufb ymm.x13, ymm.x13, ymmword ptr [rip + chacha20_avx2_rol8]
  vpshufb ymm.x14, ymm.x14, ymmword ptr [rip + chacha20_avx2_rol8]
  vpaddd ymm.c0, ymm.c0, ymm.x13
  vpaddd ymm.c1, ymm.c1, ymm.x14
  vpxor ymm.x7, ymm.x7, ymm.c0
  vpxor ymm.x4, ymm.x4, ymm.c1
  vpslld ymm.t0, ymm.x7, 7
  vpslld ymm.t1, ymm.x4, 7
  vpsrld ymm.x7, ymm.x7, 25
  vpsrld ymm.x4, ymm.x4, 25
  vpor ymm.x7, ymm.x7, ymm.t0
  vpor ymm.x4, ymm.x4, ymm.t1
.endfor
  ;; original state back (c8, c9 in registers; c10, c11 in their slots), every word to the frame
.for i, 0, 8
  vpaddd ymm.x${i}, ymm.x${i}, ymmword ptr [rsp + ${128 + 32 * i}]
  vmovdqu ymmword ptr [rsp + ${640 + 32 * i}], ymm.x${i}
.endfor
.for i, 12, 16
  vpaddd ymm.x${i}, ymm.x${i}, ymmword ptr [rsp + ${128 + 32 * i}]
  vmovdqu ymmword ptr [rsp + ${640 + 32 * i}], ymm.x${i}
.endfor
  vpaddd ymm.c0, ymm.c0, ymmword ptr [rsp + 384]
  vmovdqu ymmword ptr [rsp + 896], ymm.c0
  vpaddd ymm.c1, ymm.c1, ymmword ptr [rsp + 416]
  vmovdqu ymmword ptr [rsp + 928], ymm.c1
  vmovdqu ymm.t0, ymmword ptr [rsp + 64]
  vpaddd ymm.t0, ymm.t0, ymmword ptr [rsp + 448]
  vmovdqu ymmword ptr [rsp + 960], ymm.t0
  vmovdqu ymm.t1, ymmword ptr [rsp + 96]
  vpaddd ymm.t1, ymm.t1, ymmword ptr [rsp + 480]
  vmovdqu ymmword ptr [rsp + 992], ymm.t1
  ;; transpose, two word groups at a time (register budget): group g of four words ->
  ;; u_j with lane L = words 4g..4g+3 of block 4L+j; the pair of groups (0,1) gives each
  ;; block's first 32 bytes, (2,3) the second; output block 4L+j = lane L of u_j of both
.for half, 0, 2
  .for g, 2 * half, 2 * half + 2
  vmovdqu ymm.w0, ymmword ptr [rsp + ${640 + 32 * (4 * g)}]
  vmovdqu ymm.w1, ymmword ptr [rsp + ${640 + 32 * (4 * g + 1)}]
  vmovdqu ymm.w2, ymmword ptr [rsp + ${640 + 32 * (4 * g + 2)}]
  vmovdqu ymm.w3, ymmword ptr [rsp + ${640 + 32 * (4 * g + 3)}]
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
