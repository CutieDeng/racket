;; Fused ChaCha20 + Poly1305 unit loop on SSSE3 + MULX (x86-64 SysV), the tier below AVX2:
;; each iteration produces one 256-byte unit of ChaCha20 keystream XOR (four blocks, the same
;; code as chacha20_ssse3.asm) while the scalar Poly1305 absorbs the 16 blocks of the PREVIOUS
;; unit's ciphertext, spread over the 40 quarter-round pairs.
;;   void rktcrypto_chacha20poly1305_units_ssse3(uint32_t state[16], const unsigned char *in,
;;                                               unsigned char *out, intptr_t units,
;;                                               const unsigned char *mac, uint64_t hr[6])
;; mac points at the ciphertext of the unit preceding `in` (out - 256 when encrypting, in - 256
;; when decrypting); hr = {h0, h1, h2, r0, r1, s1} in radix 2^64 (h updated). The caller runs
;; unit 0 on the plain kernel and absorbs the last unit afterwards. The output pointer arrives
;; in rdx, which mulx needs, so it is moved out first.
;; Oracle: the two-pass path (BMI2/ADX cleared); gate: asm/tests/test_chacha20poly1305_x86.c.

.rodata chacha20poly1305_ssse3_rol16 align=16
  .byte 2, 3, 0, 1, 6, 7, 4, 5, 10, 11, 8, 9, 14, 15, 12, 13
.end
.rodata chacha20poly1305_ssse3_rol8 align=16
  .byte 3, 0, 1, 2, 7, 4, 5, 6, 11, 8, 9, 10, 15, 12, 13, 14
.end
.rodata chacha20poly1305_ssse3_idx align=16
  .long 0, 1, 2, 3
.end

.macro QR2 a0, b0, c0, d0, a1, b1, c1, d1
  paddd \a0, \b0
  paddd \a1, \b1
  movdqu xmm.t0, xmmword ptr [\d0]
  movdqu xmm.t1, xmmword ptr [\d1]
  pxor xmm.t0, \a0
  pxor xmm.t1, \a1
  pshufb xmm.t0, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  pshufb xmm.t1, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  paddd \c0, xmm.t0
  paddd \c1, xmm.t1
  pxor \b0, \c0
  pxor \b1, \c1
  movdqa xmm.s0, \b0
  movdqa xmm.s1, \b1
  pslld xmm.s0, 12
  pslld xmm.s1, 12
  psrld \b0, 20
  psrld \b1, 20
  por \b0, xmm.s0
  por \b1, xmm.s1
  paddd \a0, \b0
  paddd \a1, \b1
  pxor xmm.t0, \a0
  pxor xmm.t1, \a1
  pshufb xmm.t0, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  pshufb xmm.t1, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  paddd \c0, xmm.t0
  paddd \c1, xmm.t1
  movdqu xmmword ptr [\d0], xmm.t0
  movdqu xmmword ptr [\d1], xmm.t1
  pxor \b0, \c0
  pxor \b1, \c1
  movdqa xmm.s0, \b0
  movdqa xmm.s1, \b1
  pslld xmm.s0, 7
  pslld xmm.s1, 7
  psrld \b0, 25
  psrld \b1, 25
  por \b0, xmm.s0
  por \b1, xmm.s1
.endm

;; frame: d row at 0..63 (slot j = 16 j), the sixteen finished words at 64..319 (word i = 64 + 16 i)
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

.function rktcrypto_chacha20poly1305_units_ssse3 export (
  in: q.st, q.in, rdx, q.n, q.mac, q.hr
)
  .frame 320
  mov q.out, rdx
  test q.n, q.n
  jz done
  mov q.h0, qword ptr [q.hr]
  mov q.h1, qword ptr [q.hr + 8]
  mov q.h2, qword ptr [q.hr + 16]
unit:
.for i, 0, 12
  movd xmm.x${i}, dword ptr [q.st + ${4 * i}]
  pshufd xmm.x${i}, xmm.x${i}, 0
.endfor
  movd xmm.t0, dword ptr [q.st + 48]
  pshufd xmm.t0, xmm.t0, 0
  paddd xmm.t0, xmmword ptr [rip + chacha20poly1305_ssse3_idx]
  movdqu xmmword ptr [rsp + 0], xmm.t0
.for j, 1, 4
  movd xmm.t0, dword ptr [q.st + ${48 + 4 * j}]
  pshufd xmm.t0, xmm.t0, 0
  movdqu xmmword ptr [rsp + ${16 * j}], xmm.t0
.endfor
.for r, 0, 10
  QR2(xmm.x0, xmm.x4, xmm.x8, rsp + 0, xmm.x1, xmm.x5, xmm.x9, rsp + 16)
  .for k, (r * 4 + 0) * 16 / 40, (r * 4 + 1) * 16 / 40
  POLY1305_BLOCK(k)
  .endfor
  QR2(xmm.x2, xmm.x6, xmm.x10, rsp + 32, xmm.x3, xmm.x7, xmm.x11, rsp + 48)
  .for k, (r * 4 + 1) * 16 / 40, (r * 4 + 2) * 16 / 40
  POLY1305_BLOCK(k)
  .endfor
  QR2(xmm.x0, xmm.x5, xmm.x10, rsp + 48, xmm.x1, xmm.x6, xmm.x11, rsp + 0)
  .for k, (r * 4 + 2) * 16 / 40, (r * 4 + 3) * 16 / 40
  POLY1305_BLOCK(k)
  .endfor
  QR2(xmm.x2, xmm.x7, xmm.x8, rsp + 16, xmm.x3, xmm.x4, xmm.x9, rsp + 32)
  .for k, (r * 4 + 3) * 16 / 40, (r * 4 + 4) * 16 / 40
  POLY1305_BLOCK(k)
  .endfor
.endfor
  ;; original state back, every word to the frame
.for i, 0, 12
  movd xmm.t0, dword ptr [q.st + ${4 * i}]
  pshufd xmm.t0, xmm.t0, 0
  paddd xmm.x${i}, xmm.t0
  movdqu xmmword ptr [rsp + ${64 + 16 * i}], xmm.x${i}
.endfor
  movd xmm.t0, dword ptr [q.st + 48]
  pshufd xmm.t0, xmm.t0, 0
  paddd xmm.t0, xmmword ptr [rip + chacha20poly1305_ssse3_idx]
  movdqu xmm.t1, xmmword ptr [rsp + 0]
  paddd xmm.t0, xmm.t1
  movdqu xmmword ptr [rsp + ${64 + 16 * 12}], xmm.t0
.for j, 1, 4
  movd xmm.t0, dword ptr [q.st + ${48 + 4 * j}]
  pshufd xmm.t0, xmm.t0, 0
  movdqu xmm.t1, xmmword ptr [rsp + ${16 * j}]
  paddd xmm.t0, xmm.t1
  movdqu xmmword ptr [rsp + ${64 + 16 * (12 + j)}], xmm.t0
.endfor
  ;; transpose each group of four words: block j's words 4g..4g+3 land in one register, stored
  ;; straight to output block j at offset 16 g after the XOR with the input
.for g, 0, 4
  movdqu xmm.w0, xmmword ptr [rsp + ${64 + 16 * (4 * g)}]
  movdqu xmm.w1, xmmword ptr [rsp + ${64 + 16 * (4 * g + 1)}]
  movdqu xmm.w2, xmmword ptr [rsp + ${64 + 16 * (4 * g + 2)}]
  movdqu xmm.w3, xmmword ptr [rsp + ${64 + 16 * (4 * g + 3)}]
  movdqa xmm.p0, xmm.w0
  punpckldq xmm.p0, xmm.w1
  movdqa xmm.p1, xmm.w0
  punpckhdq xmm.p1, xmm.w1
  movdqa xmm.p2, xmm.w2
  punpckldq xmm.p2, xmm.w3
  movdqa xmm.p3, xmm.w2
  punpckhdq xmm.p3, xmm.w3
  movdqa xmm.o0, xmm.p0
  punpcklqdq xmm.o0, xmm.p2                      ; block 0
  movdqa xmm.o1, xmm.p0
  punpckhqdq xmm.o1, xmm.p2                      ; block 1
  movdqa xmm.o2, xmm.p1
  punpcklqdq xmm.o2, xmm.p3                      ; block 2
  movdqa xmm.o3, xmm.p1
  punpckhqdq xmm.o3, xmm.p3                      ; block 3
  .for b, 0, 4
  movdqu xmm.w${b}, xmmword ptr [q.in + ${64 * b + 16 * g}]
  pxor xmm.o${b}, xmm.w${b}
  movdqu xmmword ptr [q.out + ${64 * b + 16 * g}], xmm.o${b}
  .endfor
.endfor
  add dword ptr [q.st + 48], 4
  add q.in, 256
  add q.out, 256
  add q.mac, 256
  sub q.n, 1
  jnz unit
  mov qword ptr [q.hr], q.h0
  mov qword ptr [q.hr + 8], q.h1
  mov qword ptr [q.hr + 16], q.h2
done:
  ret
.end
