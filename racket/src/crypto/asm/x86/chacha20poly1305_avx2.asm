;; Fused ChaCha20 + Poly1305 unit loop on AVX2 + MULX (x86-64 SysV), the tier for CPUs without
;; AVX-512: each iteration produces one 512-byte unit of ChaCha20 keystream XOR (eight blocks,
;; the same code as chacha20_avx2.asm: a/b/d rows in registers, one c pair in registers and the
;; other in frame slots) while the scalar Poly1305 absorbs the 32 blocks of the PREVIOUS unit's
;; ciphertext, spread over the 40 quarter-round pairs so that the vector pipes and the integer
;; multiplier run concurrently.
;;   void rktcrypto_chacha20poly1305_units_avx2(uint32_t state[16], const unsigned char *in,
;;                                              unsigned char *out, intptr_t units,
;;                                              const unsigned char *mac, uint64_t hr[6])
;; mac points at the ciphertext of the unit preceding `in` (out - 512 when encrypting, in - 512
;; when decrypting); hr = {h0, h1, h2, r0, r1, s1} in radix 2^64 (h updated). The caller runs
;; unit 0 on the plain kernel and absorbs the last unit afterwards. The output pointer arrives
;; in rdx, which mulx needs, so it is moved out first.
;; Oracle: the two-pass path (BMI2/ADX cleared); gate: asm/tests/test_chacha20poly1305_x86.c.

;; one Poly1305 block of the ciphertext at mac + 16 k (radix 2^64, MULX; the same sequence as
;; chacha20poly1305_x86.asm): h = (h + m + 2^128) * r mod 2^130-5, partially reduced
.macro POLY1305_BLOCK k
  add q.h0, qword ptr [q.mac + ${16 * \k}]
  adc q.h1, qword ptr [q.mac + ${16 * \k + 8}]
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
.endm

.rodata chacha20poly1305_avx2_rol16 align=32
  .byte 2, 3, 0, 1, 6, 7, 4, 5, 10, 11, 8, 9, 14, 15, 12, 13
  .byte 2, 3, 0, 1, 6, 7, 4, 5, 10, 11, 8, 9, 14, 15, 12, 13
.end
.rodata chacha20poly1305_avx2_rol8 align=32
  .byte 3, 0, 1, 2, 7, 4, 5, 6, 11, 8, 9, 10, 15, 12, 13, 14
  .byte 3, 0, 1, 2, 7, 4, 5, 6, 11, 8, 9, 10, 15, 12, 13, 14
.end
.rodata chacha20poly1305_avx2_idx align=32
  .long 0, 1, 2, 3, 4, 5, 6, 7
.end

;; frame: c slots at 0..127 (c8 + 32 (i - 8)), the smashed state at 128..639 (word i = 128 + 32 i),
;; the sixteen finished words at 640..1151 (word i = 640 + 32 i)
.function rktcrypto_chacha20poly1305_units_avx2 export (
  in: q.st, q.in, rdx, q.n, q.mac, q.hr
)
  .simd avx2
  .frame 1152
  mov q.out, rdx
  test q.n, q.n
  jz done
  mov q.h0, qword ptr [q.hr]
  mov q.h1, qword ptr [q.hr + 8]
  mov q.h2, qword ptr [q.hr + 16]
.for i, 0, 16
  .for z, if i == 12 {1} else {0}, 1
  vpbroadcastd ymm.t0, dword ptr [q.st + ${4 * i}]
  vmovdqu ymmword ptr [rsp + ${128 + 32 * i}], ymm.t0
  .endfor
.endfor
unit:
  vpbroadcastd ymm.x12, dword ptr [q.st + 48]
  vpaddd ymm.x12, ymm.x12, ymmword ptr [rip + chacha20poly1305_avx2_idx]
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
  vpshufb ymm.x12, ymm.x12, ymmword ptr [rip + chacha20poly1305_avx2_rol16]
  vpshufb ymm.x13, ymm.x13, ymmword ptr [rip + chacha20poly1305_avx2_rol16]
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
  vpshufb ymm.x12, ymm.x12, ymmword ptr [rip + chacha20poly1305_avx2_rol8]
  vpshufb ymm.x13, ymm.x13, ymmword ptr [rip + chacha20poly1305_avx2_rol8]
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
  .for k, (r * 4 + 0) * 32 / 40, (r * 4 + 1) * 32 / 40
  POLY1305_BLOCK(k)
  .endfor
  vpaddd ymm.x2, ymm.x2, ymm.x6
  vpaddd ymm.x3, ymm.x3, ymm.x7
  vpxor ymm.x14, ymm.x14, ymm.x2
  vpxor ymm.x15, ymm.x15, ymm.x3
  vpshufb ymm.x14, ymm.x14, ymmword ptr [rip + chacha20poly1305_avx2_rol16]
  vpshufb ymm.x15, ymm.x15, ymmword ptr [rip + chacha20poly1305_avx2_rol16]
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
  vpshufb ymm.x14, ymm.x14, ymmword ptr [rip + chacha20poly1305_avx2_rol8]
  vpshufb ymm.x15, ymm.x15, ymmword ptr [rip + chacha20poly1305_avx2_rol8]
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
  .for k, (r * 4 + 1) * 32 / 40, (r * 4 + 2) * 32 / 40
  POLY1305_BLOCK(k)
  .endfor
  vpaddd ymm.x0, ymm.x0, ymm.x5
  vpaddd ymm.x1, ymm.x1, ymm.x6
  vpxor ymm.x15, ymm.x15, ymm.x0
  vpxor ymm.x12, ymm.x12, ymm.x1
  vpshufb ymm.x15, ymm.x15, ymmword ptr [rip + chacha20poly1305_avx2_rol16]
  vpshufb ymm.x12, ymm.x12, ymmword ptr [rip + chacha20poly1305_avx2_rol16]
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
  vpshufb ymm.x15, ymm.x15, ymmword ptr [rip + chacha20poly1305_avx2_rol8]
  vpshufb ymm.x12, ymm.x12, ymmword ptr [rip + chacha20poly1305_avx2_rol8]
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
  .for k, (r * 4 + 2) * 32 / 40, (r * 4 + 3) * 32 / 40
  POLY1305_BLOCK(k)
  .endfor
  vpaddd ymm.x2, ymm.x2, ymm.x7
  vpaddd ymm.x3, ymm.x3, ymm.x4
  vpxor ymm.x13, ymm.x13, ymm.x2
  vpxor ymm.x14, ymm.x14, ymm.x3
  vpshufb ymm.x13, ymm.x13, ymmword ptr [rip + chacha20poly1305_avx2_rol16]
  vpshufb ymm.x14, ymm.x14, ymmword ptr [rip + chacha20poly1305_avx2_rol16]
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
  vpshufb ymm.x13, ymm.x13, ymmword ptr [rip + chacha20poly1305_avx2_rol8]
  vpshufb ymm.x14, ymm.x14, ymmword ptr [rip + chacha20poly1305_avx2_rol8]
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
  .for k, (r * 4 + 3) * 32 / 40, (r * 4 + 4) * 32 / 40
  POLY1305_BLOCK(k)
  .endfor
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
  add q.mac, 512
  sub q.n, 1
  jnz unit
  mov qword ptr [q.hr], q.h0
  mov qword ptr [q.hr + 8], q.h1
  mov qword ptr [q.hr + 16], q.h2
done:
  ret
.end
