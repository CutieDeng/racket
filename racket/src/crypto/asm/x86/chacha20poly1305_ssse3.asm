;; Fused ChaCha20 + Poly1305 unit loop on SSSE3 + MULX (x86-64 SysV), the tier below AVX2:
;; each iteration produces one 512-byte unit of ChaCha20 keystream XOR (two four-block groups,
;; the same code as chacha20_ssse3.asm) while the scalar Poly1305 absorbs the 32 blocks of the
;; PREVIOUS unit's ciphertext. The double round runs as a loop of five iterations of two rounds
;; (the loop counter in a frame slot: every general register is taken); six Poly1305 blocks ride
;; in each iteration, spread over its 32 half-quarter-round groups, the last two follow the loop.
;;   void rktcrypto_chacha20poly1305_units_ssse3(uint32_t state[16], const unsigned char *in,
;;                                               unsigned char *out, intptr_t units,
;;                                               const unsigned char *mac, uint64_t hr[6])
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

.rodata chacha20poly1305_ssse3_rol16 align=16
  .byte 2, 3, 0, 1, 6, 7, 4, 5, 10, 11, 8, 9, 14, 15, 12, 13
.end
.rodata chacha20poly1305_ssse3_rol8 align=16
  .byte 3, 0, 1, 2, 7, 4, 5, 6, 11, 8, 9, 10, 15, 12, 13, 14
.end
.rodata chacha20poly1305_ssse3_idx align=16
  .long 0, 1, 2, 3
.end
.rodata chacha20poly1305_ssse3_idx4 align=16
  .long 4, 5, 6, 7
.end

;; frame: group g's working rows at 192 g (a 0..63, c 64..127, d 128..191), the smashed state
;; at 384..639 (word i = 384 + 16 i), the finished words of the group being written out at
;; 640..895 (word i = 640 + 16 i)
.function rktcrypto_chacha20poly1305_units_ssse3 export (
  in: q.st, q.in, rdx, q.n, q.mac, q.hr
)
  .frame 912
  mov q.out, rdx
  test q.n, q.n
  jz done
  mov q.h0, qword ptr [q.hr]
  mov q.h1, qword ptr [q.hr + 8]
  mov q.h2, qword ptr [q.hr + 16]
  ;; smash every state word but the counter across the four lanes, once
.for i, 0, 16
  .for z, if i == 12 {1} else {0}, 1
  movd xmm.Ata, dword ptr [q.st + ${4 * i}]
  pshufd xmm.Ata, xmm.Ata, 0
  movdqu xmmword ptr [rsp + ${384 + 16 * i}], xmm.Ata
  .endfor
.endfor
unit:
  movdqu xmm.Ata, xmmword ptr [rsp + 384]
  movdqu xmmword ptr [rsp + 0], xmm.Ata
  movdqu xmm.Ata, xmmword ptr [rsp + 400]
  movdqu xmmword ptr [rsp + 16], xmm.Ata
  movdqu xmm.Ata, xmmword ptr [rsp + 416]
  movdqu xmmword ptr [rsp + 32], xmm.Ata
  movdqu xmm.Ata, xmmword ptr [rsp + 432]
  movdqu xmmword ptr [rsp + 48], xmm.Ata
  movdqu xmm.Ata, xmmword ptr [rsp + 512]
  movdqu xmmword ptr [rsp + 64], xmm.Ata
  movdqu xmm.Ata, xmmword ptr [rsp + 528]
  movdqu xmmword ptr [rsp + 80], xmm.Ata
  movdqu xmm.Ata, xmmword ptr [rsp + 544]
  movdqu xmmword ptr [rsp + 96], xmm.Ata
  movdqu xmm.Ata, xmmword ptr [rsp + 560]
  movdqu xmmword ptr [rsp + 112], xmm.Ata
  movdqu xmm.Ata, xmmword ptr [rsp + 592]
  movdqu xmmword ptr [rsp + 144], xmm.Ata
  movdqu xmm.Ata, xmmword ptr [rsp + 608]
  movdqu xmmword ptr [rsp + 160], xmm.Ata
  movdqu xmm.Ata, xmmword ptr [rsp + 624]
  movdqu xmmword ptr [rsp + 176], xmm.Ata
  movdqu xmm.Ab0, xmmword ptr [rsp + 448]
  movdqu xmm.Ab1, xmmword ptr [rsp + 464]
  movdqu xmm.Ab2, xmmword ptr [rsp + 480]
  movdqu xmm.Ab3, xmmword ptr [rsp + 496]
  movd xmm.Ata, dword ptr [q.st + 48]
  pshufd xmm.Ata, xmm.Ata, 0
  paddd xmm.Ata, xmmword ptr [rip + chacha20poly1305_ssse3_idx]
  movdqu xmmword ptr [rsp + 128], xmm.Ata
  movdqu xmm.Ata, xmmword ptr [rsp + 384]
  movdqu xmmword ptr [rsp + 192], xmm.Ata
  movdqu xmm.Ata, xmmword ptr [rsp + 400]
  movdqu xmmword ptr [rsp + 208], xmm.Ata
  movdqu xmm.Ata, xmmword ptr [rsp + 416]
  movdqu xmmword ptr [rsp + 224], xmm.Ata
  movdqu xmm.Ata, xmmword ptr [rsp + 432]
  movdqu xmmword ptr [rsp + 240], xmm.Ata
  movdqu xmm.Ata, xmmword ptr [rsp + 512]
  movdqu xmmword ptr [rsp + 256], xmm.Ata
  movdqu xmm.Ata, xmmword ptr [rsp + 528]
  movdqu xmmword ptr [rsp + 272], xmm.Ata
  movdqu xmm.Ata, xmmword ptr [rsp + 544]
  movdqu xmmword ptr [rsp + 288], xmm.Ata
  movdqu xmm.Ata, xmmword ptr [rsp + 560]
  movdqu xmmword ptr [rsp + 304], xmm.Ata
  movdqu xmm.Ata, xmmword ptr [rsp + 592]
  movdqu xmmword ptr [rsp + 336], xmm.Ata
  movdqu xmm.Ata, xmmword ptr [rsp + 608]
  movdqu xmmword ptr [rsp + 352], xmm.Ata
  movdqu xmm.Ata, xmmword ptr [rsp + 624]
  movdqu xmmword ptr [rsp + 368], xmm.Ata
  movdqu xmm.Bb0, xmmword ptr [rsp + 448]
  movdqu xmm.Bb1, xmmword ptr [rsp + 464]
  movdqu xmm.Bb2, xmmword ptr [rsp + 480]
  movdqu xmm.Bb3, xmmword ptr [rsp + 496]
  movd xmm.Ata, dword ptr [q.st + 48]
  pshufd xmm.Ata, xmm.Ata, 0
  paddd xmm.Ata, xmmword ptr [rip + chacha20poly1305_ssse3_idx4]
  movdqu xmmword ptr [rsp + 320], xmm.Ata
  ;; the double round as a runtime loop: the unrolled body (4000+ legacy-encoded instructions per
  ;; unit) overflows the op cache and the kernel decodes at four instructions a cycle; one double
  ;; round of both groups (~420 instructions) stays resident
  mov qword ptr [rsp + 896], 5
round:
  movdqu xmm.Ata, xmmword ptr [rsp + 0]
  paddd xmm.Ata, xmm.Ab0
  movdqu xmm.Atd, xmmword ptr [rsp + 128]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 0], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Atc, xmmword ptr [rsp + 64]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 128], xmm.Atd
  pxor xmm.Ab0, xmm.Atc
  movdqu xmmword ptr [rsp + 64], xmm.Atc
  movdqa xmm.Ats, xmm.Ab0
  pslld xmm.Ab0, 12
  psrld xmm.Ats, 20
  por xmm.Ab0, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 192]
  paddd xmm.Bta, xmm.Bb0
  movdqu xmm.Btd, xmmword ptr [rsp + 320]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 192], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Btc, xmmword ptr [rsp + 256]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 320], xmm.Btd
  pxor xmm.Bb0, xmm.Btc
  movdqu xmmword ptr [rsp + 256], xmm.Btc
  movdqa xmm.Bts, xmm.Bb0
  pslld xmm.Bb0, 12
  psrld xmm.Bts, 20
  por xmm.Bb0, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 16]
  paddd xmm.Ata, xmm.Ab1
  movdqu xmm.Atd, xmmword ptr [rsp + 144]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 16], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Atc, xmmword ptr [rsp + 80]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 144], xmm.Atd
  pxor xmm.Ab1, xmm.Atc
  movdqu xmmword ptr [rsp + 80], xmm.Atc
  movdqa xmm.Ats, xmm.Ab1
  pslld xmm.Ab1, 12
  psrld xmm.Ats, 20
  por xmm.Ab1, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 208]
  paddd xmm.Bta, xmm.Bb1
  movdqu xmm.Btd, xmmword ptr [rsp + 336]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 208], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Btc, xmmword ptr [rsp + 272]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 336], xmm.Btd
  pxor xmm.Bb1, xmm.Btc
  movdqu xmmword ptr [rsp + 272], xmm.Btc
  movdqa xmm.Bts, xmm.Bb1
  pslld xmm.Bb1, 12
  psrld xmm.Bts, 20
  por xmm.Bb1, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 32]
  paddd xmm.Ata, xmm.Ab2
  movdqu xmm.Atd, xmmword ptr [rsp + 160]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 32], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Atc, xmmword ptr [rsp + 96]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 160], xmm.Atd
  pxor xmm.Ab2, xmm.Atc
  movdqu xmmword ptr [rsp + 96], xmm.Atc
  movdqa xmm.Ats, xmm.Ab2
  pslld xmm.Ab2, 12
  psrld xmm.Ats, 20
  por xmm.Ab2, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 224]
  paddd xmm.Bta, xmm.Bb2
  movdqu xmm.Btd, xmmword ptr [rsp + 352]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 224], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Btc, xmmword ptr [rsp + 288]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 352], xmm.Btd
  pxor xmm.Bb2, xmm.Btc
  movdqu xmmword ptr [rsp + 288], xmm.Btc
  movdqa xmm.Bts, xmm.Bb2
  pslld xmm.Bb2, 12
  psrld xmm.Bts, 20
  por xmm.Bb2, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 48]
  paddd xmm.Ata, xmm.Ab3
  movdqu xmm.Atd, xmmword ptr [rsp + 176]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 48], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Atc, xmmword ptr [rsp + 112]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 176], xmm.Atd
  pxor xmm.Ab3, xmm.Atc
  movdqu xmmword ptr [rsp + 112], xmm.Atc
  movdqa xmm.Ats, xmm.Ab3
  pslld xmm.Ab3, 12
  psrld xmm.Ats, 20
  por xmm.Ab3, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 240]
  paddd xmm.Bta, xmm.Bb3
  movdqu xmm.Btd, xmmword ptr [rsp + 368]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 240], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Btc, xmmword ptr [rsp + 304]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 368], xmm.Btd
  pxor xmm.Bb3, xmm.Btc
  movdqu xmmword ptr [rsp + 304], xmm.Btc
  movdqa xmm.Bts, xmm.Bb3
  pslld xmm.Bb3, 12
  psrld xmm.Bts, 20
  por xmm.Bb3, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 0]
  paddd xmm.Ata, xmm.Ab0
  movdqu xmm.Atd, xmmword ptr [rsp + 128]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 0], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Atc, xmmword ptr [rsp + 64]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 128], xmm.Atd
  pxor xmm.Ab0, xmm.Atc
  movdqu xmmword ptr [rsp + 64], xmm.Atc
  movdqa xmm.Ats, xmm.Ab0
  pslld xmm.Ab0, 7
  psrld xmm.Ats, 25
  por xmm.Ab0, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 192]
  paddd xmm.Bta, xmm.Bb0
  movdqu xmm.Btd, xmmword ptr [rsp + 320]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 192], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Btc, xmmword ptr [rsp + 256]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 320], xmm.Btd
  pxor xmm.Bb0, xmm.Btc
  movdqu xmmword ptr [rsp + 256], xmm.Btc
  movdqa xmm.Bts, xmm.Bb0
  pslld xmm.Bb0, 7
  psrld xmm.Bts, 25
  por xmm.Bb0, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 16]
  paddd xmm.Ata, xmm.Ab1
  movdqu xmm.Atd, xmmword ptr [rsp + 144]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 16], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Atc, xmmword ptr [rsp + 80]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 144], xmm.Atd
  pxor xmm.Ab1, xmm.Atc
  movdqu xmmword ptr [rsp + 80], xmm.Atc
  movdqa xmm.Ats, xmm.Ab1
  pslld xmm.Ab1, 7
  psrld xmm.Ats, 25
  por xmm.Ab1, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 208]
  paddd xmm.Bta, xmm.Bb1
  movdqu xmm.Btd, xmmword ptr [rsp + 336]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 208], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Btc, xmmword ptr [rsp + 272]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 336], xmm.Btd
  pxor xmm.Bb1, xmm.Btc
  movdqu xmmword ptr [rsp + 272], xmm.Btc
  movdqa xmm.Bts, xmm.Bb1
  pslld xmm.Bb1, 7
  psrld xmm.Bts, 25
  por xmm.Bb1, xmm.Bts
  POLY1305_BLOCK(0)
  movdqu xmm.Ata, xmmword ptr [rsp + 32]
  paddd xmm.Ata, xmm.Ab2
  movdqu xmm.Atd, xmmword ptr [rsp + 160]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 32], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Atc, xmmword ptr [rsp + 96]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 160], xmm.Atd
  pxor xmm.Ab2, xmm.Atc
  movdqu xmmword ptr [rsp + 96], xmm.Atc
  movdqa xmm.Ats, xmm.Ab2
  pslld xmm.Ab2, 7
  psrld xmm.Ats, 25
  por xmm.Ab2, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 224]
  paddd xmm.Bta, xmm.Bb2
  movdqu xmm.Btd, xmmword ptr [rsp + 352]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 224], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Btc, xmmword ptr [rsp + 288]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 352], xmm.Btd
  pxor xmm.Bb2, xmm.Btc
  movdqu xmmword ptr [rsp + 288], xmm.Btc
  movdqa xmm.Bts, xmm.Bb2
  pslld xmm.Bb2, 7
  psrld xmm.Bts, 25
  por xmm.Bb2, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 48]
  paddd xmm.Ata, xmm.Ab3
  movdqu xmm.Atd, xmmword ptr [rsp + 176]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 48], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Atc, xmmword ptr [rsp + 112]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 176], xmm.Atd
  pxor xmm.Ab3, xmm.Atc
  movdqu xmmword ptr [rsp + 112], xmm.Atc
  movdqa xmm.Ats, xmm.Ab3
  pslld xmm.Ab3, 7
  psrld xmm.Ats, 25
  por xmm.Ab3, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 240]
  paddd xmm.Bta, xmm.Bb3
  movdqu xmm.Btd, xmmword ptr [rsp + 368]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 240], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Btc, xmmword ptr [rsp + 304]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 368], xmm.Btd
  pxor xmm.Bb3, xmm.Btc
  movdqu xmmword ptr [rsp + 304], xmm.Btc
  movdqa xmm.Bts, xmm.Bb3
  pslld xmm.Bb3, 7
  psrld xmm.Bts, 25
  por xmm.Bb3, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 0]
  paddd xmm.Ata, xmm.Ab1
  movdqu xmm.Atd, xmmword ptr [rsp + 176]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 0], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Atc, xmmword ptr [rsp + 96]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 176], xmm.Atd
  pxor xmm.Ab1, xmm.Atc
  movdqu xmmword ptr [rsp + 96], xmm.Atc
  movdqa xmm.Ats, xmm.Ab1
  pslld xmm.Ab1, 12
  psrld xmm.Ats, 20
  por xmm.Ab1, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 192]
  paddd xmm.Bta, xmm.Bb1
  movdqu xmm.Btd, xmmword ptr [rsp + 368]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 192], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Btc, xmmword ptr [rsp + 288]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 368], xmm.Btd
  pxor xmm.Bb1, xmm.Btc
  movdqu xmmword ptr [rsp + 288], xmm.Btc
  movdqa xmm.Bts, xmm.Bb1
  pslld xmm.Bb1, 12
  psrld xmm.Bts, 20
  por xmm.Bb1, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 16]
  paddd xmm.Ata, xmm.Ab2
  movdqu xmm.Atd, xmmword ptr [rsp + 128]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 16], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Atc, xmmword ptr [rsp + 112]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 128], xmm.Atd
  pxor xmm.Ab2, xmm.Atc
  movdqu xmmword ptr [rsp + 112], xmm.Atc
  movdqa xmm.Ats, xmm.Ab2
  pslld xmm.Ab2, 12
  psrld xmm.Ats, 20
  por xmm.Ab2, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 208]
  paddd xmm.Bta, xmm.Bb2
  movdqu xmm.Btd, xmmword ptr [rsp + 320]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 208], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Btc, xmmword ptr [rsp + 304]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 320], xmm.Btd
  pxor xmm.Bb2, xmm.Btc
  movdqu xmmword ptr [rsp + 304], xmm.Btc
  movdqa xmm.Bts, xmm.Bb2
  pslld xmm.Bb2, 12
  psrld xmm.Bts, 20
  por xmm.Bb2, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 32]
  paddd xmm.Ata, xmm.Ab3
  movdqu xmm.Atd, xmmword ptr [rsp + 144]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 32], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Atc, xmmword ptr [rsp + 64]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 144], xmm.Atd
  pxor xmm.Ab3, xmm.Atc
  movdqu xmmword ptr [rsp + 64], xmm.Atc
  movdqa xmm.Ats, xmm.Ab3
  pslld xmm.Ab3, 12
  psrld xmm.Ats, 20
  por xmm.Ab3, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 224]
  paddd xmm.Bta, xmm.Bb3
  movdqu xmm.Btd, xmmword ptr [rsp + 336]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 224], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Btc, xmmword ptr [rsp + 256]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 336], xmm.Btd
  pxor xmm.Bb3, xmm.Btc
  movdqu xmmword ptr [rsp + 256], xmm.Btc
  movdqa xmm.Bts, xmm.Bb3
  pslld xmm.Bb3, 12
  psrld xmm.Bts, 20
  por xmm.Bb3, xmm.Bts
  POLY1305_BLOCK(1)
  movdqu xmm.Ata, xmmword ptr [rsp + 48]
  paddd xmm.Ata, xmm.Ab0
  movdqu xmm.Atd, xmmword ptr [rsp + 160]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 48], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Atc, xmmword ptr [rsp + 80]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 160], xmm.Atd
  pxor xmm.Ab0, xmm.Atc
  movdqu xmmword ptr [rsp + 80], xmm.Atc
  movdqa xmm.Ats, xmm.Ab0
  pslld xmm.Ab0, 12
  psrld xmm.Ats, 20
  por xmm.Ab0, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 240]
  paddd xmm.Bta, xmm.Bb0
  movdqu xmm.Btd, xmmword ptr [rsp + 352]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 240], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Btc, xmmword ptr [rsp + 272]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 352], xmm.Btd
  pxor xmm.Bb0, xmm.Btc
  movdqu xmmword ptr [rsp + 272], xmm.Btc
  movdqa xmm.Bts, xmm.Bb0
  pslld xmm.Bb0, 12
  psrld xmm.Bts, 20
  por xmm.Bb0, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 0]
  paddd xmm.Ata, xmm.Ab1
  movdqu xmm.Atd, xmmword ptr [rsp + 176]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 0], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Atc, xmmword ptr [rsp + 96]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 176], xmm.Atd
  pxor xmm.Ab1, xmm.Atc
  movdqu xmmword ptr [rsp + 96], xmm.Atc
  movdqa xmm.Ats, xmm.Ab1
  pslld xmm.Ab1, 7
  psrld xmm.Ats, 25
  por xmm.Ab1, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 192]
  paddd xmm.Bta, xmm.Bb1
  movdqu xmm.Btd, xmmword ptr [rsp + 368]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 192], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Btc, xmmword ptr [rsp + 288]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 368], xmm.Btd
  pxor xmm.Bb1, xmm.Btc
  movdqu xmmword ptr [rsp + 288], xmm.Btc
  movdqa xmm.Bts, xmm.Bb1
  pslld xmm.Bb1, 7
  psrld xmm.Bts, 25
  por xmm.Bb1, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 16]
  paddd xmm.Ata, xmm.Ab2
  movdqu xmm.Atd, xmmword ptr [rsp + 128]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 16], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Atc, xmmword ptr [rsp + 112]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 128], xmm.Atd
  pxor xmm.Ab2, xmm.Atc
  movdqu xmmword ptr [rsp + 112], xmm.Atc
  movdqa xmm.Ats, xmm.Ab2
  pslld xmm.Ab2, 7
  psrld xmm.Ats, 25
  por xmm.Ab2, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 208]
  paddd xmm.Bta, xmm.Bb2
  movdqu xmm.Btd, xmmword ptr [rsp + 320]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 208], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Btc, xmmword ptr [rsp + 304]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 320], xmm.Btd
  pxor xmm.Bb2, xmm.Btc
  movdqu xmmword ptr [rsp + 304], xmm.Btc
  movdqa xmm.Bts, xmm.Bb2
  pslld xmm.Bb2, 7
  psrld xmm.Bts, 25
  por xmm.Bb2, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 32]
  paddd xmm.Ata, xmm.Ab3
  movdqu xmm.Atd, xmmword ptr [rsp + 144]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 32], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Atc, xmmword ptr [rsp + 64]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 144], xmm.Atd
  pxor xmm.Ab3, xmm.Atc
  movdqu xmmword ptr [rsp + 64], xmm.Atc
  movdqa xmm.Ats, xmm.Ab3
  pslld xmm.Ab3, 7
  psrld xmm.Ats, 25
  por xmm.Ab3, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 224]
  paddd xmm.Bta, xmm.Bb3
  movdqu xmm.Btd, xmmword ptr [rsp + 336]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 224], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Btc, xmmword ptr [rsp + 256]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 336], xmm.Btd
  pxor xmm.Bb3, xmm.Btc
  movdqu xmmword ptr [rsp + 256], xmm.Btc
  movdqa xmm.Bts, xmm.Bb3
  pslld xmm.Bb3, 7
  psrld xmm.Bts, 25
  por xmm.Bb3, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 48]
  paddd xmm.Ata, xmm.Ab0
  movdqu xmm.Atd, xmmword ptr [rsp + 160]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 48], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Atc, xmmword ptr [rsp + 80]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 160], xmm.Atd
  pxor xmm.Ab0, xmm.Atc
  movdqu xmmword ptr [rsp + 80], xmm.Atc
  movdqa xmm.Ats, xmm.Ab0
  pslld xmm.Ab0, 7
  psrld xmm.Ats, 25
  por xmm.Ab0, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 240]
  paddd xmm.Bta, xmm.Bb0
  movdqu xmm.Btd, xmmword ptr [rsp + 352]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 240], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Btc, xmmword ptr [rsp + 272]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 352], xmm.Btd
  pxor xmm.Bb0, xmm.Btc
  movdqu xmmword ptr [rsp + 272], xmm.Btc
  movdqa xmm.Bts, xmm.Bb0
  pslld xmm.Bb0, 7
  psrld xmm.Bts, 25
  por xmm.Bb0, xmm.Bts
  POLY1305_BLOCK(2)
  movdqu xmm.Ata, xmmword ptr [rsp + 0]
  paddd xmm.Ata, xmm.Ab0
  movdqu xmm.Atd, xmmword ptr [rsp + 128]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 0], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Atc, xmmword ptr [rsp + 64]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 128], xmm.Atd
  pxor xmm.Ab0, xmm.Atc
  movdqu xmmword ptr [rsp + 64], xmm.Atc
  movdqa xmm.Ats, xmm.Ab0
  pslld xmm.Ab0, 12
  psrld xmm.Ats, 20
  por xmm.Ab0, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 192]
  paddd xmm.Bta, xmm.Bb0
  movdqu xmm.Btd, xmmword ptr [rsp + 320]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 192], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Btc, xmmword ptr [rsp + 256]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 320], xmm.Btd
  pxor xmm.Bb0, xmm.Btc
  movdqu xmmword ptr [rsp + 256], xmm.Btc
  movdqa xmm.Bts, xmm.Bb0
  pslld xmm.Bb0, 12
  psrld xmm.Bts, 20
  por xmm.Bb0, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 16]
  paddd xmm.Ata, xmm.Ab1
  movdqu xmm.Atd, xmmword ptr [rsp + 144]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 16], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Atc, xmmword ptr [rsp + 80]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 144], xmm.Atd
  pxor xmm.Ab1, xmm.Atc
  movdqu xmmword ptr [rsp + 80], xmm.Atc
  movdqa xmm.Ats, xmm.Ab1
  pslld xmm.Ab1, 12
  psrld xmm.Ats, 20
  por xmm.Ab1, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 208]
  paddd xmm.Bta, xmm.Bb1
  movdqu xmm.Btd, xmmword ptr [rsp + 336]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 208], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Btc, xmmword ptr [rsp + 272]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 336], xmm.Btd
  pxor xmm.Bb1, xmm.Btc
  movdqu xmmword ptr [rsp + 272], xmm.Btc
  movdqa xmm.Bts, xmm.Bb1
  pslld xmm.Bb1, 12
  psrld xmm.Bts, 20
  por xmm.Bb1, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 32]
  paddd xmm.Ata, xmm.Ab2
  movdqu xmm.Atd, xmmword ptr [rsp + 160]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 32], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Atc, xmmword ptr [rsp + 96]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 160], xmm.Atd
  pxor xmm.Ab2, xmm.Atc
  movdqu xmmword ptr [rsp + 96], xmm.Atc
  movdqa xmm.Ats, xmm.Ab2
  pslld xmm.Ab2, 12
  psrld xmm.Ats, 20
  por xmm.Ab2, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 224]
  paddd xmm.Bta, xmm.Bb2
  movdqu xmm.Btd, xmmword ptr [rsp + 352]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 224], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Btc, xmmword ptr [rsp + 288]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 352], xmm.Btd
  pxor xmm.Bb2, xmm.Btc
  movdqu xmmword ptr [rsp + 288], xmm.Btc
  movdqa xmm.Bts, xmm.Bb2
  pslld xmm.Bb2, 12
  psrld xmm.Bts, 20
  por xmm.Bb2, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 48]
  paddd xmm.Ata, xmm.Ab3
  movdqu xmm.Atd, xmmword ptr [rsp + 176]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 48], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Atc, xmmword ptr [rsp + 112]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 176], xmm.Atd
  pxor xmm.Ab3, xmm.Atc
  movdqu xmmword ptr [rsp + 112], xmm.Atc
  movdqa xmm.Ats, xmm.Ab3
  pslld xmm.Ab3, 12
  psrld xmm.Ats, 20
  por xmm.Ab3, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 240]
  paddd xmm.Bta, xmm.Bb3
  movdqu xmm.Btd, xmmword ptr [rsp + 368]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 240], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Btc, xmmword ptr [rsp + 304]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 368], xmm.Btd
  pxor xmm.Bb3, xmm.Btc
  movdqu xmmword ptr [rsp + 304], xmm.Btc
  movdqa xmm.Bts, xmm.Bb3
  pslld xmm.Bb3, 12
  psrld xmm.Bts, 20
  por xmm.Bb3, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 0]
  paddd xmm.Ata, xmm.Ab0
  movdqu xmm.Atd, xmmword ptr [rsp + 128]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 0], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Atc, xmmword ptr [rsp + 64]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 128], xmm.Atd
  pxor xmm.Ab0, xmm.Atc
  movdqu xmmword ptr [rsp + 64], xmm.Atc
  movdqa xmm.Ats, xmm.Ab0
  pslld xmm.Ab0, 7
  psrld xmm.Ats, 25
  por xmm.Ab0, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 192]
  paddd xmm.Bta, xmm.Bb0
  movdqu xmm.Btd, xmmword ptr [rsp + 320]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 192], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Btc, xmmword ptr [rsp + 256]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 320], xmm.Btd
  pxor xmm.Bb0, xmm.Btc
  movdqu xmmword ptr [rsp + 256], xmm.Btc
  movdqa xmm.Bts, xmm.Bb0
  pslld xmm.Bb0, 7
  psrld xmm.Bts, 25
  por xmm.Bb0, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 16]
  paddd xmm.Ata, xmm.Ab1
  movdqu xmm.Atd, xmmword ptr [rsp + 144]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 16], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Atc, xmmword ptr [rsp + 80]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 144], xmm.Atd
  pxor xmm.Ab1, xmm.Atc
  movdqu xmmword ptr [rsp + 80], xmm.Atc
  movdqa xmm.Ats, xmm.Ab1
  pslld xmm.Ab1, 7
  psrld xmm.Ats, 25
  por xmm.Ab1, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 208]
  paddd xmm.Bta, xmm.Bb1
  movdqu xmm.Btd, xmmword ptr [rsp + 336]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 208], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Btc, xmmword ptr [rsp + 272]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 336], xmm.Btd
  pxor xmm.Bb1, xmm.Btc
  movdqu xmmword ptr [rsp + 272], xmm.Btc
  movdqa xmm.Bts, xmm.Bb1
  pslld xmm.Bb1, 7
  psrld xmm.Bts, 25
  por xmm.Bb1, xmm.Bts
  POLY1305_BLOCK(3)
  movdqu xmm.Ata, xmmword ptr [rsp + 32]
  paddd xmm.Ata, xmm.Ab2
  movdqu xmm.Atd, xmmword ptr [rsp + 160]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 32], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Atc, xmmword ptr [rsp + 96]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 160], xmm.Atd
  pxor xmm.Ab2, xmm.Atc
  movdqu xmmword ptr [rsp + 96], xmm.Atc
  movdqa xmm.Ats, xmm.Ab2
  pslld xmm.Ab2, 7
  psrld xmm.Ats, 25
  por xmm.Ab2, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 224]
  paddd xmm.Bta, xmm.Bb2
  movdqu xmm.Btd, xmmword ptr [rsp + 352]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 224], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Btc, xmmword ptr [rsp + 288]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 352], xmm.Btd
  pxor xmm.Bb2, xmm.Btc
  movdqu xmmword ptr [rsp + 288], xmm.Btc
  movdqa xmm.Bts, xmm.Bb2
  pslld xmm.Bb2, 7
  psrld xmm.Bts, 25
  por xmm.Bb2, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 48]
  paddd xmm.Ata, xmm.Ab3
  movdqu xmm.Atd, xmmword ptr [rsp + 176]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 48], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Atc, xmmword ptr [rsp + 112]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 176], xmm.Atd
  pxor xmm.Ab3, xmm.Atc
  movdqu xmmword ptr [rsp + 112], xmm.Atc
  movdqa xmm.Ats, xmm.Ab3
  pslld xmm.Ab3, 7
  psrld xmm.Ats, 25
  por xmm.Ab3, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 240]
  paddd xmm.Bta, xmm.Bb3
  movdqu xmm.Btd, xmmword ptr [rsp + 368]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 240], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Btc, xmmword ptr [rsp + 304]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 368], xmm.Btd
  pxor xmm.Bb3, xmm.Btc
  movdqu xmmword ptr [rsp + 304], xmm.Btc
  movdqa xmm.Bts, xmm.Bb3
  pslld xmm.Bb3, 7
  psrld xmm.Bts, 25
  por xmm.Bb3, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 0]
  paddd xmm.Ata, xmm.Ab1
  movdqu xmm.Atd, xmmword ptr [rsp + 176]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 0], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Atc, xmmword ptr [rsp + 96]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 176], xmm.Atd
  pxor xmm.Ab1, xmm.Atc
  movdqu xmmword ptr [rsp + 96], xmm.Atc
  movdqa xmm.Ats, xmm.Ab1
  pslld xmm.Ab1, 12
  psrld xmm.Ats, 20
  por xmm.Ab1, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 192]
  paddd xmm.Bta, xmm.Bb1
  movdqu xmm.Btd, xmmword ptr [rsp + 368]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 192], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Btc, xmmword ptr [rsp + 288]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 368], xmm.Btd
  pxor xmm.Bb1, xmm.Btc
  movdqu xmmword ptr [rsp + 288], xmm.Btc
  movdqa xmm.Bts, xmm.Bb1
  pslld xmm.Bb1, 12
  psrld xmm.Bts, 20
  por xmm.Bb1, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 16]
  paddd xmm.Ata, xmm.Ab2
  movdqu xmm.Atd, xmmword ptr [rsp + 128]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 16], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Atc, xmmword ptr [rsp + 112]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 128], xmm.Atd
  pxor xmm.Ab2, xmm.Atc
  movdqu xmmword ptr [rsp + 112], xmm.Atc
  movdqa xmm.Ats, xmm.Ab2
  pslld xmm.Ab2, 12
  psrld xmm.Ats, 20
  por xmm.Ab2, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 208]
  paddd xmm.Bta, xmm.Bb2
  movdqu xmm.Btd, xmmword ptr [rsp + 320]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 208], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Btc, xmmword ptr [rsp + 304]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 320], xmm.Btd
  pxor xmm.Bb2, xmm.Btc
  movdqu xmmword ptr [rsp + 304], xmm.Btc
  movdqa xmm.Bts, xmm.Bb2
  pslld xmm.Bb2, 12
  psrld xmm.Bts, 20
  por xmm.Bb2, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 32]
  paddd xmm.Ata, xmm.Ab3
  movdqu xmm.Atd, xmmword ptr [rsp + 144]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 32], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Atc, xmmword ptr [rsp + 64]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 144], xmm.Atd
  pxor xmm.Ab3, xmm.Atc
  movdqu xmmword ptr [rsp + 64], xmm.Atc
  movdqa xmm.Ats, xmm.Ab3
  pslld xmm.Ab3, 12
  psrld xmm.Ats, 20
  por xmm.Ab3, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 224]
  paddd xmm.Bta, xmm.Bb3
  movdqu xmm.Btd, xmmword ptr [rsp + 336]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 224], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Btc, xmmword ptr [rsp + 256]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 336], xmm.Btd
  pxor xmm.Bb3, xmm.Btc
  movdqu xmmword ptr [rsp + 256], xmm.Btc
  movdqa xmm.Bts, xmm.Bb3
  pslld xmm.Bb3, 12
  psrld xmm.Bts, 20
  por xmm.Bb3, xmm.Bts
  POLY1305_BLOCK(4)
  movdqu xmm.Ata, xmmword ptr [rsp + 48]
  paddd xmm.Ata, xmm.Ab0
  movdqu xmm.Atd, xmmword ptr [rsp + 160]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 48], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Atc, xmmword ptr [rsp + 80]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 160], xmm.Atd
  pxor xmm.Ab0, xmm.Atc
  movdqu xmmword ptr [rsp + 80], xmm.Atc
  movdqa xmm.Ats, xmm.Ab0
  pslld xmm.Ab0, 12
  psrld xmm.Ats, 20
  por xmm.Ab0, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 240]
  paddd xmm.Bta, xmm.Bb0
  movdqu xmm.Btd, xmmword ptr [rsp + 352]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 240], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol16]
  movdqu xmm.Btc, xmmword ptr [rsp + 272]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 352], xmm.Btd
  pxor xmm.Bb0, xmm.Btc
  movdqu xmmword ptr [rsp + 272], xmm.Btc
  movdqa xmm.Bts, xmm.Bb0
  pslld xmm.Bb0, 12
  psrld xmm.Bts, 20
  por xmm.Bb0, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 0]
  paddd xmm.Ata, xmm.Ab1
  movdqu xmm.Atd, xmmword ptr [rsp + 176]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 0], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Atc, xmmword ptr [rsp + 96]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 176], xmm.Atd
  pxor xmm.Ab1, xmm.Atc
  movdqu xmmword ptr [rsp + 96], xmm.Atc
  movdqa xmm.Ats, xmm.Ab1
  pslld xmm.Ab1, 7
  psrld xmm.Ats, 25
  por xmm.Ab1, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 192]
  paddd xmm.Bta, xmm.Bb1
  movdqu xmm.Btd, xmmword ptr [rsp + 368]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 192], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Btc, xmmword ptr [rsp + 288]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 368], xmm.Btd
  pxor xmm.Bb1, xmm.Btc
  movdqu xmmword ptr [rsp + 288], xmm.Btc
  movdqa xmm.Bts, xmm.Bb1
  pslld xmm.Bb1, 7
  psrld xmm.Bts, 25
  por xmm.Bb1, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 16]
  paddd xmm.Ata, xmm.Ab2
  movdqu xmm.Atd, xmmword ptr [rsp + 128]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 16], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Atc, xmmword ptr [rsp + 112]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 128], xmm.Atd
  pxor xmm.Ab2, xmm.Atc
  movdqu xmmword ptr [rsp + 112], xmm.Atc
  movdqa xmm.Ats, xmm.Ab2
  pslld xmm.Ab2, 7
  psrld xmm.Ats, 25
  por xmm.Ab2, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 208]
  paddd xmm.Bta, xmm.Bb2
  movdqu xmm.Btd, xmmword ptr [rsp + 320]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 208], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Btc, xmmword ptr [rsp + 304]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 320], xmm.Btd
  pxor xmm.Bb2, xmm.Btc
  movdqu xmmword ptr [rsp + 304], xmm.Btc
  movdqa xmm.Bts, xmm.Bb2
  pslld xmm.Bb2, 7
  psrld xmm.Bts, 25
  por xmm.Bb2, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 32]
  paddd xmm.Ata, xmm.Ab3
  movdqu xmm.Atd, xmmword ptr [rsp + 144]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 32], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Atc, xmmword ptr [rsp + 64]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 144], xmm.Atd
  pxor xmm.Ab3, xmm.Atc
  movdqu xmmword ptr [rsp + 64], xmm.Atc
  movdqa xmm.Ats, xmm.Ab3
  pslld xmm.Ab3, 7
  psrld xmm.Ats, 25
  por xmm.Ab3, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 224]
  paddd xmm.Bta, xmm.Bb3
  movdqu xmm.Btd, xmmword ptr [rsp + 336]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 224], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Btc, xmmword ptr [rsp + 256]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 336], xmm.Btd
  pxor xmm.Bb3, xmm.Btc
  movdqu xmmword ptr [rsp + 256], xmm.Btc
  movdqa xmm.Bts, xmm.Bb3
  pslld xmm.Bb3, 7
  psrld xmm.Bts, 25
  por xmm.Bb3, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 48]
  paddd xmm.Ata, xmm.Ab0
  movdqu xmm.Atd, xmmword ptr [rsp + 160]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 48], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Atc, xmmword ptr [rsp + 80]
  paddd xmm.Atc, xmm.Atd
  movdqu xmmword ptr [rsp + 160], xmm.Atd
  pxor xmm.Ab0, xmm.Atc
  movdqu xmmword ptr [rsp + 80], xmm.Atc
  movdqa xmm.Ats, xmm.Ab0
  pslld xmm.Ab0, 7
  psrld xmm.Ats, 25
  por xmm.Ab0, xmm.Ats
  movdqu xmm.Bta, xmmword ptr [rsp + 240]
  paddd xmm.Bta, xmm.Bb0
  movdqu xmm.Btd, xmmword ptr [rsp + 352]
  pxor xmm.Btd, xmm.Bta
  movdqu xmmword ptr [rsp + 240], xmm.Bta
  pshufb xmm.Btd, xmmword ptr [rip + chacha20poly1305_ssse3_rol8]
  movdqu xmm.Btc, xmmword ptr [rsp + 272]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 352], xmm.Btd
  pxor xmm.Bb0, xmm.Btc
  movdqu xmmword ptr [rsp + 272], xmm.Btc
  movdqa xmm.Bts, xmm.Bb0
  pslld xmm.Bb0, 7
  psrld xmm.Bts, 25
  por xmm.Bb0, xmm.Bts
  POLY1305_BLOCK(5)
  add q.mac, 96
  sub qword ptr [rsp + 896], 1
  jnz round
  POLY1305_BLOCK(0)
  POLY1305_BLOCK(1)
  add q.mac, 32
  ;; group 0: original state back, every word to the frame, transpose and write out
  movdqu xmm.w0, xmmword ptr [rsp + 0]
  paddd xmm.w0, xmmword ptr [rsp + 384]
  movdqu xmmword ptr [rsp + 640], xmm.w0
  movdqu xmm.w0, xmmword ptr [rsp + 16]
  paddd xmm.w0, xmmword ptr [rsp + 400]
  movdqu xmmword ptr [rsp + 656], xmm.w0
  movdqu xmm.w0, xmmword ptr [rsp + 32]
  paddd xmm.w0, xmmword ptr [rsp + 416]
  movdqu xmmword ptr [rsp + 672], xmm.w0
  movdqu xmm.w0, xmmword ptr [rsp + 48]
  paddd xmm.w0, xmmword ptr [rsp + 432]
  movdqu xmmword ptr [rsp + 688], xmm.w0
  movdqu xmm.w0, xmmword ptr [rsp + 64]
  paddd xmm.w0, xmmword ptr [rsp + 512]
  movdqu xmmword ptr [rsp + 768], xmm.w0
  movdqu xmm.w0, xmmword ptr [rsp + 80]
  paddd xmm.w0, xmmword ptr [rsp + 528]
  movdqu xmmword ptr [rsp + 784], xmm.w0
  movdqu xmm.w0, xmmword ptr [rsp + 96]
  paddd xmm.w0, xmmword ptr [rsp + 544]
  movdqu xmmword ptr [rsp + 800], xmm.w0
  movdqu xmm.w0, xmmword ptr [rsp + 112]
  paddd xmm.w0, xmmword ptr [rsp + 560]
  movdqu xmmword ptr [rsp + 816], xmm.w0
  movdqu xmm.w0, xmmword ptr [rsp + 144]
  paddd xmm.w0, xmmword ptr [rsp + 592]
  movdqu xmmword ptr [rsp + 848], xmm.w0
  movdqu xmm.w0, xmmword ptr [rsp + 160]
  paddd xmm.w0, xmmword ptr [rsp + 608]
  movdqu xmmword ptr [rsp + 864], xmm.w0
  movdqu xmm.w0, xmmword ptr [rsp + 176]
  paddd xmm.w0, xmmword ptr [rsp + 624]
  movdqu xmmword ptr [rsp + 880], xmm.w0
  movdqu xmm.w0, xmmword ptr [rsp + 128]
  movd xmm.w1, dword ptr [q.st + 48]
  pshufd xmm.w1, xmm.w1, 0
  paddd xmm.w0, xmm.w1
  paddd xmm.w0, xmmword ptr [rip + chacha20poly1305_ssse3_idx]
  movdqu xmmword ptr [rsp + 832], xmm.w0
  paddd xmm.Ab0, xmmword ptr [rsp + 448]
  movdqu xmmword ptr [rsp + 704], xmm.Ab0
  paddd xmm.Ab1, xmmword ptr [rsp + 464]
  movdqu xmmword ptr [rsp + 720], xmm.Ab1
  paddd xmm.Ab2, xmmword ptr [rsp + 480]
  movdqu xmmword ptr [rsp + 736], xmm.Ab2
  paddd xmm.Ab3, xmmword ptr [rsp + 496]
  movdqu xmmword ptr [rsp + 752], xmm.Ab3
.for g, 0, 4
  movdqu xmm.w0, xmmword ptr [rsp + ${640 + 16 * (4 * g)}]
  movdqu xmm.w1, xmmword ptr [rsp + ${640 + 16 * (4 * g + 1)}]
  movdqu xmm.w2, xmmword ptr [rsp + ${640 + 16 * (4 * g + 2)}]
  movdqu xmm.w3, xmmword ptr [rsp + ${640 + 16 * (4 * g + 3)}]
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
  movdqu xmm.w${b}, xmmword ptr [q.in + ${0 + 64 * b + 16 * g}]
  pxor xmm.o${b}, xmm.w${b}
  movdqu xmmword ptr [q.out + ${0 + 64 * b + 16 * g}], xmm.o${b}
  .endfor
.endfor
  ;; group 1
  movdqu xmm.w0, xmmword ptr [rsp + 192]
  paddd xmm.w0, xmmword ptr [rsp + 384]
  movdqu xmmword ptr [rsp + 640], xmm.w0
  movdqu xmm.w0, xmmword ptr [rsp + 208]
  paddd xmm.w0, xmmword ptr [rsp + 400]
  movdqu xmmword ptr [rsp + 656], xmm.w0
  movdqu xmm.w0, xmmword ptr [rsp + 224]
  paddd xmm.w0, xmmword ptr [rsp + 416]
  movdqu xmmword ptr [rsp + 672], xmm.w0
  movdqu xmm.w0, xmmword ptr [rsp + 240]
  paddd xmm.w0, xmmword ptr [rsp + 432]
  movdqu xmmword ptr [rsp + 688], xmm.w0
  movdqu xmm.w0, xmmword ptr [rsp + 256]
  paddd xmm.w0, xmmword ptr [rsp + 512]
  movdqu xmmword ptr [rsp + 768], xmm.w0
  movdqu xmm.w0, xmmword ptr [rsp + 272]
  paddd xmm.w0, xmmword ptr [rsp + 528]
  movdqu xmmword ptr [rsp + 784], xmm.w0
  movdqu xmm.w0, xmmword ptr [rsp + 288]
  paddd xmm.w0, xmmword ptr [rsp + 544]
  movdqu xmmword ptr [rsp + 800], xmm.w0
  movdqu xmm.w0, xmmword ptr [rsp + 304]
  paddd xmm.w0, xmmword ptr [rsp + 560]
  movdqu xmmword ptr [rsp + 816], xmm.w0
  movdqu xmm.w0, xmmword ptr [rsp + 336]
  paddd xmm.w0, xmmword ptr [rsp + 592]
  movdqu xmmword ptr [rsp + 848], xmm.w0
  movdqu xmm.w0, xmmword ptr [rsp + 352]
  paddd xmm.w0, xmmword ptr [rsp + 608]
  movdqu xmmword ptr [rsp + 864], xmm.w0
  movdqu xmm.w0, xmmword ptr [rsp + 368]
  paddd xmm.w0, xmmword ptr [rsp + 624]
  movdqu xmmword ptr [rsp + 880], xmm.w0
  movdqu xmm.w0, xmmword ptr [rsp + 320]
  movd xmm.w1, dword ptr [q.st + 48]
  pshufd xmm.w1, xmm.w1, 0
  paddd xmm.w0, xmm.w1
  paddd xmm.w0, xmmword ptr [rip + chacha20poly1305_ssse3_idx4]
  movdqu xmmword ptr [rsp + 832], xmm.w0
  paddd xmm.Bb0, xmmword ptr [rsp + 448]
  movdqu xmmword ptr [rsp + 704], xmm.Bb0
  paddd xmm.Bb1, xmmword ptr [rsp + 464]
  movdqu xmmword ptr [rsp + 720], xmm.Bb1
  paddd xmm.Bb2, xmmword ptr [rsp + 480]
  movdqu xmmword ptr [rsp + 736], xmm.Bb2
  paddd xmm.Bb3, xmmword ptr [rsp + 496]
  movdqu xmmword ptr [rsp + 752], xmm.Bb3
.for g, 0, 4
  movdqu xmm.w0, xmmword ptr [rsp + ${640 + 16 * (4 * g)}]
  movdqu xmm.w1, xmmword ptr [rsp + ${640 + 16 * (4 * g + 1)}]
  movdqu xmm.w2, xmmword ptr [rsp + ${640 + 16 * (4 * g + 2)}]
  movdqu xmm.w3, xmmword ptr [rsp + ${640 + 16 * (4 * g + 3)}]
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
  movdqu xmm.w${b}, xmmword ptr [q.in + ${256 + 64 * b + 16 * g}]
  pxor xmm.o${b}, xmm.w${b}
  movdqu xmmword ptr [q.out + ${256 + 64 * b + 16 * g}], xmm.o${b}
  .endfor
.endfor
  add dword ptr [q.st + 48], 8
  add q.in, 512
  add q.out, 512
  sub q.n, 1
  jnz unit
  mov qword ptr [q.hr], q.h0
  mov qword ptr [q.hr + 8], q.h1
  mov qword ptr [q.hr + 16], q.h2
done:
  ret
.end
