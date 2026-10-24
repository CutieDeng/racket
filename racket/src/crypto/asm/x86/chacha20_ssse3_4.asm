;; ChaCha20 keystream XOR on SSSE3 (x86-64 SysV): the single-group four-block kernel kept for
;; the 256-byte remainder of the two-group kernel (chacha20_ssse3.asm) and of the tiers above;
;; four blocks per 256-byte unit in the state-in-lanes layout (register i holds word i of the four blocks).
;; The same register plan as the AVX2 kernel: the d row lives in frame slots, a quarter round
;; pulls its d word into a scratch register and writes it back once, rotations by 16/8 are
;; byte shuffles with memory masks, 12/7 a shift pair, two quarter rounds interleaved.
;; Legacy encodings: two-operand forms, unaligned data through movdqu, masks from aligned rodata.
;;   void rktcrypto_chacha20_blocks_ssse3_4(uint32_t state[16], const unsigned char *in,
;;                                        unsigned char *out, intptr_t units)
;; units = number of 256-byte units; state[12] advances by 4 per unit (mod 2^32).
;; Oracle: chacha20_core through rktcrypto_chacha20_xor with SSSE3, AVX2 and AVX-512 disabled;
;; gate: asm/tests/test_chacha20_avx512.c.

.rodata chacha20_ssse3_4_rol16 align=16
  .byte 2, 3, 0, 1, 6, 7, 4, 5, 10, 11, 8, 9, 14, 15, 12, 13
.end
.rodata chacha20_ssse3_4_rol8 align=16
  .byte 3, 0, 1, 2, 7, 4, 5, 6, 11, 8, 9, 10, 15, 12, 13, 14
.end
.rodata chacha20_ssse3_4_idx align=16
  .long 0, 1, 2, 3
.end

.macro QR2 a0, b0, c0, d0, a1, b1, c1, d1
  paddd \a0, \b0
  paddd \a1, \b1
  movdqu xmm.t0, xmmword ptr [\d0]
  movdqu xmm.t1, xmmword ptr [\d1]
  pxor xmm.t0, \a0
  pxor xmm.t1, \a1
  pshufb xmm.t0, xmmword ptr [rip + chacha20_ssse3_4_rol16]
  pshufb xmm.t1, xmmword ptr [rip + chacha20_ssse3_4_rol16]
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
  pshufb xmm.t0, xmmword ptr [rip + chacha20_ssse3_4_rol8]
  pshufb xmm.t1, xmmword ptr [rip + chacha20_ssse3_4_rol8]
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
.function rktcrypto_chacha20_blocks_ssse3_4 export (
  in: q.st, q.in, q.out, q.n
)
  .frame 320
  test q.n, q.n
  jz done
unit:
.for i, 0, 12
  movd xmm.x${i}, dword ptr [q.st + ${4 * i}]
  pshufd xmm.x${i}, xmm.x${i}, 0
.endfor
  movd xmm.t0, dword ptr [q.st + 48]
  pshufd xmm.t0, xmm.t0, 0
  paddd xmm.t0, xmmword ptr [rip + chacha20_ssse3_4_idx]
  movdqu xmmword ptr [rsp + 0], xmm.t0
.for j, 1, 4
  movd xmm.t0, dword ptr [q.st + ${48 + 4 * j}]
  pshufd xmm.t0, xmm.t0, 0
  movdqu xmmword ptr [rsp + ${16 * j}], xmm.t0
.endfor
.for r, 0, 10
  QR2(xmm.x0, xmm.x4, xmm.x8, rsp + 0, xmm.x1, xmm.x5, xmm.x9, rsp + 16)
  QR2(xmm.x2, xmm.x6, xmm.x10, rsp + 32, xmm.x3, xmm.x7, xmm.x11, rsp + 48)
  QR2(xmm.x0, xmm.x5, xmm.x10, rsp + 48, xmm.x1, xmm.x6, xmm.x11, rsp + 0)
  QR2(xmm.x2, xmm.x7, xmm.x8, rsp + 16, xmm.x3, xmm.x4, xmm.x9, rsp + 32)
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
  paddd xmm.t0, xmmword ptr [rip + chacha20_ssse3_4_idx]
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
  sub q.n, 1
  jnz unit
done:
  ret
.end
