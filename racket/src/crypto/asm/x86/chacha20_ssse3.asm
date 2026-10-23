;; ChaCha20 keystream XOR on SSSE3 (x86-64 SysV), the tier below AVX2: eight blocks per
;; 512-byte unit as TWO independent four-block groups in the state-in-lanes layout. On this
;; core every integer vector op costs two cycles on a dependency chain, so a quarter round is
;; a 32-cycle chain and one four-block group (its four quarter rounds in flight) is latency
;; bound at 160 cycles per block whatever the register plan -- OpenSSL's 4x sits on the same
;; bound. Two groups double the chains in flight; to fit sixteen registers only the b row of
;; each group stays in registers (eight), the a, c and d rows live in frame slots and ride
;; through four temporaries inside a quarter round (one load and one store per row per
;; quarter round; the reloads are of values stored half a round earlier, off the chain).
;; Each quarter round is emitted as two halves and the eight first halves of a half round precede
;; the eight second halves (a, c, d return to their slots between them), so all eight chains are
;; resident in the FP scheduler at once instead of four. The double round is a runtime loop so
;; that the body stays in the op cache.
;; Rotations by 16/8 are byte shuffles with memory masks, 12/7 a shift pair. The state words
;; are smashed across lanes once into the frame; a unit copies them into the working slots.
;; Legacy encodings: two-operand forms, unaligned data through movdqu, masks from aligned rodata.
;;   void rktcrypto_chacha20_blocks_ssse3(uint32_t state[16], const unsigned char *in,
;;                                        unsigned char *out, intptr_t units)
;; units = number of 512-byte units; state[12] advances by 8 per unit (mod 2^32).
;; Oracle: chacha20_core through rktcrypto_chacha20_xor with SSSE3, AVX2 and AVX-512 disabled;
;; gate: asm/tests/test_chacha20_avx512.c.

.rodata chacha20_ssse3_rol16 align=16
  .byte 2, 3, 0, 1, 6, 7, 4, 5, 10, 11, 8, 9, 14, 15, 12, 13
.end
.rodata chacha20_ssse3_rol8 align=16
  .byte 3, 0, 1, 2, 7, 4, 5, 6, 11, 8, 9, 10, 15, 12, 13, 14
.end
.rodata chacha20_ssse3_idx align=16
  .long 0, 1, 2, 3
.end
.rodata chacha20_ssse3_idx4 align=16
  .long 4, 5, 6, 7
.end

;; frame: group g's working rows at 192 g (a 0..63, c 64..127, d 128..191), the smashed state
;; at 384..639 (word i = 384 + 16 i), the finished words of the group being written out at
;; 640..895 (word i = 640 + 16 i)
.function rktcrypto_chacha20_blocks_ssse3 export (
  in: q.st, q.in, q.out, q.n
)
  .frame 896
  test q.n, q.n
  jz done
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
  paddd xmm.Ata, xmmword ptr [rip + chacha20_ssse3_idx]
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
  paddd xmm.Ata, xmmword ptr [rip + chacha20_ssse3_idx4]
  movdqu xmmword ptr [rsp + 320], xmm.Ata
  ;; the double round as a runtime loop: the unrolled body (4000+ legacy-encoded instructions per
  ;; unit) overflows the op cache and the kernel decodes at four instructions a cycle; one double
  ;; round of both groups (~420 instructions) stays resident
  mov q.r, 10
round:
  movdqu xmm.Ata, xmmword ptr [rsp + 0]
  paddd xmm.Ata, xmm.Ab0
  movdqu xmm.Atd, xmmword ptr [rsp + 128]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 0], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20_ssse3_rol16]
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
  pshufb xmm.Btd, xmmword ptr [rip + chacha20_ssse3_rol16]
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
  pshufb xmm.Atd, xmmword ptr [rip + chacha20_ssse3_rol16]
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
  pshufb xmm.Btd, xmmword ptr [rip + chacha20_ssse3_rol16]
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
  pshufb xmm.Atd, xmmword ptr [rip + chacha20_ssse3_rol16]
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
  pshufb xmm.Btd, xmmword ptr [rip + chacha20_ssse3_rol16]
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
  pshufb xmm.Atd, xmmword ptr [rip + chacha20_ssse3_rol16]
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
  pshufb xmm.Btd, xmmword ptr [rip + chacha20_ssse3_rol16]
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
  pshufb xmm.Atd, xmmword ptr [rip + chacha20_ssse3_rol8]
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
  pshufb xmm.Btd, xmmword ptr [rip + chacha20_ssse3_rol8]
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
  pshufb xmm.Atd, xmmword ptr [rip + chacha20_ssse3_rol8]
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
  pshufb xmm.Btd, xmmword ptr [rip + chacha20_ssse3_rol8]
  movdqu xmm.Btc, xmmword ptr [rsp + 272]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 336], xmm.Btd
  pxor xmm.Bb1, xmm.Btc
  movdqu xmmword ptr [rsp + 272], xmm.Btc
  movdqa xmm.Bts, xmm.Bb1
  pslld xmm.Bb1, 7
  psrld xmm.Bts, 25
  por xmm.Bb1, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 32]
  paddd xmm.Ata, xmm.Ab2
  movdqu xmm.Atd, xmmword ptr [rsp + 160]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 32], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20_ssse3_rol8]
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
  pshufb xmm.Btd, xmmword ptr [rip + chacha20_ssse3_rol8]
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
  pshufb xmm.Atd, xmmword ptr [rip + chacha20_ssse3_rol8]
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
  pshufb xmm.Btd, xmmword ptr [rip + chacha20_ssse3_rol8]
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
  pshufb xmm.Atd, xmmword ptr [rip + chacha20_ssse3_rol16]
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
  pshufb xmm.Btd, xmmword ptr [rip + chacha20_ssse3_rol16]
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
  pshufb xmm.Atd, xmmword ptr [rip + chacha20_ssse3_rol16]
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
  pshufb xmm.Btd, xmmword ptr [rip + chacha20_ssse3_rol16]
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
  pshufb xmm.Atd, xmmword ptr [rip + chacha20_ssse3_rol16]
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
  pshufb xmm.Btd, xmmword ptr [rip + chacha20_ssse3_rol16]
  movdqu xmm.Btc, xmmword ptr [rsp + 256]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 336], xmm.Btd
  pxor xmm.Bb3, xmm.Btc
  movdqu xmmword ptr [rsp + 256], xmm.Btc
  movdqa xmm.Bts, xmm.Bb3
  pslld xmm.Bb3, 12
  psrld xmm.Bts, 20
  por xmm.Bb3, xmm.Bts
  movdqu xmm.Ata, xmmword ptr [rsp + 48]
  paddd xmm.Ata, xmm.Ab0
  movdqu xmm.Atd, xmmword ptr [rsp + 160]
  pxor xmm.Atd, xmm.Ata
  movdqu xmmword ptr [rsp + 48], xmm.Ata
  pshufb xmm.Atd, xmmword ptr [rip + chacha20_ssse3_rol16]
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
  pshufb xmm.Btd, xmmword ptr [rip + chacha20_ssse3_rol16]
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
  pshufb xmm.Atd, xmmword ptr [rip + chacha20_ssse3_rol8]
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
  pshufb xmm.Btd, xmmword ptr [rip + chacha20_ssse3_rol8]
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
  pshufb xmm.Atd, xmmword ptr [rip + chacha20_ssse3_rol8]
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
  pshufb xmm.Btd, xmmword ptr [rip + chacha20_ssse3_rol8]
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
  pshufb xmm.Atd, xmmword ptr [rip + chacha20_ssse3_rol8]
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
  pshufb xmm.Btd, xmmword ptr [rip + chacha20_ssse3_rol8]
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
  pshufb xmm.Atd, xmmword ptr [rip + chacha20_ssse3_rol8]
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
  pshufb xmm.Btd, xmmword ptr [rip + chacha20_ssse3_rol8]
  movdqu xmm.Btc, xmmword ptr [rsp + 272]
  paddd xmm.Btc, xmm.Btd
  movdqu xmmword ptr [rsp + 352], xmm.Btd
  pxor xmm.Bb0, xmm.Btc
  movdqu xmmword ptr [rsp + 272], xmm.Btc
  movdqa xmm.Bts, xmm.Bb0
  pslld xmm.Bb0, 7
  psrld xmm.Bts, 25
  por xmm.Bb0, xmm.Bts
  sub q.r, 1
  jnz round
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
  paddd xmm.w0, xmmword ptr [rip + chacha20_ssse3_idx]
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
  paddd xmm.w0, xmmword ptr [rip + chacha20_ssse3_idx4]
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
done:
  ret
.end
