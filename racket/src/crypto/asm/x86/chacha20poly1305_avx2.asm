;; Fused ChaCha20 + Poly1305 unit loop on AVX2 + MULX (x86-64 SysV), the tier for CPUs without
;; AVX-512: each iteration produces one 512-byte unit of ChaCha20 keystream XOR (eight blocks,
;; the same code as chacha20_avx2.asm) while the scalar Poly1305 absorbs the 32 blocks of the
;; PREVIOUS unit's ciphertext, spread over the 40 quarter-round pairs so that the vector pipes
;; and the integer multiplier run concurrently.
;;   void rktcrypto_chacha20poly1305_units_avx2(uint32_t state[16], const unsigned char *in,
;;                                              unsigned char *out, intptr_t units,
;;                                              const unsigned char *mac, uint64_t hr[6])
;; mac points at the ciphertext of the unit preceding `in` (out - 512 when encrypting, in - 512
;; when decrypting); hr = {h0, h1, h2, r0, r1, s1} in radix 2^64 (h updated). The caller runs
;; unit 0 on the plain kernel and absorbs the last unit afterwards. The output pointer arrives
;; in rdx, which mulx needs, so it is moved out first.
;; Oracle: the two-pass path (BMI2/ADX cleared); gate: asm/tests/test_chacha20poly1305_x86.c.

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

;; two interleaved quarter rounds; d words in frame slots \d0 / \d1 (addresses), pulled into
;; ymm.t0 / ymm.t1, shift scratch ymm.s0 / ymm.s1
.macro QR2 a0, b0, c0, d0, a1, b1, c1, d1
  vpaddd \a0, \a0, \b0
  vpaddd \a1, \a1, \b1
  vpxor ymm.t0, \a0, ymmword ptr [\d0]
  vpxor ymm.t1, \a1, ymmword ptr [\d1]
  vpshufb ymm.t0, ymm.t0, ymmword ptr [rip + chacha20poly1305_avx2_rol16]
  vpshufb ymm.t1, ymm.t1, ymmword ptr [rip + chacha20poly1305_avx2_rol16]
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
  vpshufb ymm.t0, ymm.t0, ymmword ptr [rip + chacha20poly1305_avx2_rol8]
  vpshufb ymm.t1, ymm.t1, ymmword ptr [rip + chacha20poly1305_avx2_rol8]
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

.function rktcrypto_chacha20poly1305_units_avx2 export (
  in: q.st, q.in, rdx, q.n, q.mac, q.hr
)
  .simd avx2
  .frame 640
  mov q.out, rdx
  test q.n, q.n
  jz done
  mov q.h0, qword ptr [q.hr]
  mov q.h1, qword ptr [q.hr + 8]
  mov q.h2, qword ptr [q.hr + 16]
unit:
.for i, 0, 12
  vpbroadcastd ymm.x${i}, dword ptr [q.st + ${4 * i}]
.endfor
  vpbroadcastd ymm.t0, dword ptr [q.st + 48]
  vpaddd ymm.t0, ymm.t0, ymmword ptr [rip + chacha20poly1305_avx2_idx]
  vmovdqu ymmword ptr [rsp + 0], ymm.t0
.for j, 1, 4
  vpbroadcastd ymm.t0, dword ptr [q.st + ${48 + 4 * j}]
  vmovdqu ymmword ptr [rsp + ${32 * j}], ymm.t0
.endfor
.for r, 0, 10
  QR2(ymm.x0, ymm.x4, ymm.x8, rsp + 0, ymm.x1, ymm.x5, ymm.x9, rsp + 32)
  .for k, (r * 4 + 0) * 32 / 40, (r * 4 + 1) * 32 / 40
  POLY1305_BLOCK(k)
  .endfor
  QR2(ymm.x2, ymm.x6, ymm.x10, rsp + 64, ymm.x3, ymm.x7, ymm.x11, rsp + 96)
  .for k, (r * 4 + 1) * 32 / 40, (r * 4 + 2) * 32 / 40
  POLY1305_BLOCK(k)
  .endfor
  QR2(ymm.x0, ymm.x5, ymm.x10, rsp + 96, ymm.x1, ymm.x6, ymm.x11, rsp + 0)
  .for k, (r * 4 + 2) * 32 / 40, (r * 4 + 3) * 32 / 40
  POLY1305_BLOCK(k)
  .endfor
  QR2(ymm.x2, ymm.x7, ymm.x8, rsp + 32, ymm.x3, ymm.x4, ymm.x9, rsp + 64)
  .for k, (r * 4 + 3) * 32 / 40, (r * 4 + 4) * 32 / 40
  POLY1305_BLOCK(k)
  .endfor
.endfor
  ;; original state back, every word to the frame
.for i, 0, 12
  vpbroadcastd ymm.t0, dword ptr [q.st + ${4 * i}]
  vpaddd ymm.x${i}, ymm.x${i}, ymm.t0
  vmovdqu ymmword ptr [rsp + ${128 + 32 * i}], ymm.x${i}
.endfor
  vpbroadcastd ymm.t0, dword ptr [q.st + 48]
  vpaddd ymm.t0, ymm.t0, ymmword ptr [rip + chacha20poly1305_avx2_idx]
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
  add q.mac, 512
  sub q.n, 1
  jnz unit
  mov qword ptr [q.hr], q.h0
  mov qword ptr [q.hr + 8], q.h1
  mov qword ptr [q.hr + 16], q.h2
done:
  ret
.end
