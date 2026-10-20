;; Fused AES-GCM bulk pass on VAES + VPCLMULQDQ + AVX-512 (x86-64 SysV): per 512-byte
;; chunk, two groups of sixteen CTR blocks (inc32) are encrypted in four 512-bit
;; registers each and XORed with the input; the ciphertext of the previous chunk (eight
;; registers, 32 blocks) is folded into the GHASH accumulator with ONE reduction per
;; chunk, so the serial reduction chain costs half of what a 16-block chunk would and
;; overlaps the AES rounds of the next chunk. One kernel serves both directions: the
;; GHASH input is the ciphertext, taken from the registers after the XOR (encrypt) or
;; loaded before the output store (decrypt, which keeps in-place decryption correct).
;;   intptr_t rktcrypto_gcm_crypt_vaes(const struct rktcrypto_gcm_vaes_ctx *c,
;;                                     const unsigned char *in, unsigned char *out, intptr_t len)
;; ctx: rk@0, htab@8 (H^32..H^1 in eight 64-byte rows, byte-reversed), ctr@16 (big-endian,
;; updated), acc@24 (byte-reversed, updated), nr@32, enc@40. Returns the bytes processed
;; (a multiple of 512); the C side finishes the remainder on the CTR and GHASH paths.
;; Oracle: the two-pass path (rktcrypto_aes_ctr_aesni + rktcrypto_ghash_x86);
;; gate: asm/tests/test_gcm_vaes.c.
;;
;; rktcrypto_gcm_htab_vaes(htab, c) fills rows 0..6 of the table from row 7
;; ([H^4 H^3 H^2 H], written by the C side) and c = [H^4 | H^8 | H^16]: row 6 = row 7 * H^4,
;; rows 5,4 = rows 7,6 * H^8, rows 3..0 = rows 7..4 * H^16, each a lane-wise field
;; multiplication with the same shift-then-fold reduction as the intrinsics.

.rodata gcm_vaes_bswap align=16
  .byte 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0
.end
.rodata gcm_vaes_inc align=64                   ; lane i of vector j holds 4j+i in dword 0
  .long 0,0,0,0, 1,0,0,0, 2,0,0,0, 3,0,0,0
  .long 4,0,0,0, 5,0,0,0, 6,0,0,0, 7,0,0,0
  .long 8,0,0,0, 9,0,0,0, 10,0,0,0, 11,0,0,0
  .long 12,0,0,0, 13,0,0,0, 14,0,0,0, 15,0,0,0
  .long 16,0,0,0, 17,0,0,0, 18,0,0,0, 19,0,0,0
  .long 20,0,0,0, 21,0,0,0, 22,0,0,0, 23,0,0,0
  .long 24,0,0,0, 25,0,0,0, 26,0,0,0, 27,0,0,0
  .long 28,0,0,0, 29,0,0,0, 30,0,0,0, 31,0,0,0
.end
.rodata gcm_vaes_thirtytwo align=64
  .long 32,0,0,0, 32,0,0,0, 32,0,0,0, 32,0,0,0
.end

.function rktcrypto_gcm_crypt_vaes export (
  in: q.ctx, q.in, q.out, q.len
  out: q.ret
)
  .simd avx512
  xor d.ret, d.ret
  cmp q.len, 512
  jb done
  mov q.rk, qword ptr [q.ctx]
  mov q.htab, qword ptr [q.ctx + 8]
  mov q.p, qword ptr [q.ctx + 16]                ; counter block
  mov q.nr, qword ptr [q.ctx + 32]
  mov q.enc, qword ptr [q.ctx + 40]
  mov q.off, q.nr
  shl q.off, 4
  vbroadcasti32x4 zmm.bswap, xmmword ptr [rip + gcm_vaes_bswap]
  vbroadcasti32x4 zmm.k0, xmmword ptr [q.rk]
  vbroadcasti32x4 zmm.klast, xmmword ptr [q.rk + q.off]
  vbroadcasti32x4 zmm.base, xmmword ptr [q.p]
  vpshufb zmm.base, zmm.base, zmm.bswap          ; little-endian counters, all lanes equal
  mov q.p, qword ptr [q.ctx + 24]                ; accumulator
  vmovdqu64 xmm.acc, xmmword ptr [q.p]
  xor d.pending, d.pending                       ; no ciphertext chunk waiting for GHASH yet
loop:
  ;; ---- GHASH of the previous chunk (d0..d7, byte-reversed ciphertext) against H^32..H^1
  test d.pending, d.pending
  jz skipghash
  vpxorq zmm.d0, zmm.d0, zmm.acc
  vpclmulqdq zmm.lo, zmm.d0, zmmword ptr [q.htab], 0x00
  vpclmulqdq zmm.hi, zmm.d0, zmmword ptr [q.htab], 0x11
  vpclmulqdq zmm.mid, zmm.d0, zmmword ptr [q.htab], 0x10
  vpclmulqdq zmm.t, zmm.d0, zmmword ptr [q.htab], 0x01
  vpxorq zmm.mid, zmm.mid, zmm.t
.for j, 1, 8
  vpclmulqdq zmm.t, zmm.d${j}, zmmword ptr [q.htab + ${64 * j}], 0x00
  vpxorq zmm.lo, zmm.lo, zmm.t
  vpclmulqdq zmm.t, zmm.d${j}, zmmword ptr [q.htab + ${64 * j}], 0x11
  vpxorq zmm.hi, zmm.hi, zmm.t
  vpclmulqdq zmm.t, zmm.d${j}, zmmword ptr [q.htab + ${64 * j}], 0x10
  vpclmulqdq zmm.t2, zmm.d${j}, zmmword ptr [q.htab + ${64 * j}], 0x01
  vpternlogq zmm.mid, zmm.t, zmm.t2, 0x96
.endfor
  vpslldq zmm.t, zmm.mid, 8
  vpsrldq zmm.mid, zmm.mid, 8
  vpxorq zmm.lo, zmm.lo, zmm.t
  vpxorq zmm.hi, zmm.hi, zmm.mid
  vextracti64x4 ymm.t, zmm.lo, 1
  vpxorq ymm.lo, ymm.lo, ymm.t
  vextracti32x4 xmm.t, ymm.lo, 1
  vpxorq xmm.lo, xmm.lo, xmm.t
  vextracti64x4 ymm.t, zmm.hi, 1
  vpxorq ymm.hi, ymm.hi, ymm.t
  vextracti32x4 xmm.t, ymm.hi, 1
  vpxorq xmm.hi, xmm.hi, xmm.t
  vpsrld xmm.t7, xmm.lo, 31
  vpsrld xmm.t8, xmm.hi, 31
  vpslld xmm.lo, xmm.lo, 1
  vpslld xmm.hi, xmm.hi, 1
  vpsrldq xmm.t9, xmm.t7, 12
  vpslldq xmm.t8, xmm.t8, 4
  vpslldq xmm.t7, xmm.t7, 4
  vporq xmm.lo, xmm.lo, xmm.t7
  vporq xmm.hi, xmm.hi, xmm.t8
  vporq xmm.hi, xmm.hi, xmm.t9
  vpslld xmm.t7, xmm.lo, 31
  vpslld xmm.t8, xmm.lo, 30
  vpslld xmm.t9, xmm.lo, 25
  vpxorq xmm.t7, xmm.t7, xmm.t8
  vpxorq xmm.t7, xmm.t7, xmm.t9
  vpsrldq xmm.t8, xmm.t7, 4
  vpslldq xmm.t7, xmm.t7, 12
  vpxorq xmm.lo, xmm.lo, xmm.t7
  vpsrld xmm.t2, xmm.lo, 1
  vpsrld xmm.t4, xmm.lo, 2
  vpsrld xmm.t5, xmm.lo, 7
  vpxorq xmm.t2, xmm.t2, xmm.t4
  vpxorq xmm.t2, xmm.t2, xmm.t5
  vpxorq xmm.t2, xmm.t2, xmm.t8
  vpxorq xmm.lo, xmm.lo, xmm.t2
  vpxorq xmm.acc, xmm.hi, xmm.lo
skipghash:
  cmp q.len, 512
  jb fin
  ;; ---- AES-CTR for the current chunk: two groups of sixteen counters (inc32)
.for g, 0, 2
  .for j, 0, 4
  vpaddd zmm.s${j}, zmm.base, zmmword ptr [rip + gcm_vaes_inc + ${64 * (4 * g + j)}]
  .endfor
  .for j, 0, 4
  vpshufb zmm.s${j}, zmm.s${j}, zmm.bswap
  vpxorq zmm.s${j}, zmm.s${j}, zmm.k0
  .endfor
  .for r, 1, 10
  vbroadcasti32x4 zmm.k, xmmword ptr [q.rk + ${16 * r}]
    .for j, 0, 4
  vaesenc zmm.s${j}, zmm.s${j}, zmm.k
    .endfor
  .endfor
  cmp d.nr, 10
  je last${g}
  .for r, 10, 12
  vbroadcasti32x4 zmm.k, xmmword ptr [q.rk + ${16 * r}]
    .for j, 0, 4
  vaesenc zmm.s${j}, zmm.s${j}, zmm.k
    .endfor
  .endfor
  cmp d.nr, 12
  je last${g}
  .for r, 12, 14
  vbroadcasti32x4 zmm.k, xmmword ptr [q.rk + ${16 * r}]
    .for j, 0, 4
  vaesenc zmm.s${j}, zmm.s${j}, zmm.k
    .endfor
  .endfor
last${g}:
  .for j, 0, 4
  vaesenclast zmm.s${j}, zmm.s${j}, zmm.klast
  .endfor
  ;; decrypt: the ciphertext is the input, captured before the store (in-place safe)
  test d.enc, d.enc
  jnz xorstore${g}
  .for j, 0, 4
  vmovdqu64 zmm.d${4 * g + j}, zmmword ptr [q.in + ${64 * (4 * g + j)}]
  .endfor
xorstore${g}:
  .for j, 0, 4
  vpxorq zmm.s${j}, zmm.s${j}, zmmword ptr [q.in + ${64 * (4 * g + j)}]
  vmovdqu64 zmmword ptr [q.out + ${64 * (4 * g + j)}], zmm.s${j}
  .endfor
  test d.enc, d.enc
  jz reverse${g}
  .for j, 0, 4
  vmovdqa64 zmm.d${4 * g + j}, zmm.s${j}         ; encrypt: the ciphertext just produced
  .endfor
reverse${g}:
  .for j, 0, 4
  vpshufb zmm.d${4 * g + j}, zmm.d${4 * g + j}, zmm.bswap
  .endfor
.endfor
  vpaddd zmm.base, zmm.base, zmmword ptr [rip + gcm_vaes_thirtytwo]
  mov d.pending, 1
  add q.in, 512
  add q.out, 512
  add q.ret, 512
  sub q.len, 512
  jmp loop
fin:
  vmovdqu64 xmmword ptr [q.p], xmm.acc
  mov q.p, qword ptr [q.ctx + 16]
  vpshufb xmm.t, xmm.base, xmm.bswap
  vmovdqu64 xmmword ptr [q.p], xmm.t
done:
  ret
.end

.function rktcrypto_gcm_htab_vaes export (
  in: q.htab, q.c
)
  .simd avx512
  vmovdqu64 zmm.v7, zmmword ptr [q.htab + 448]
  vbroadcasti32x4 zmm.c4, xmmword ptr [q.c]
  vbroadcasti32x4 zmm.c8, xmmword ptr [q.c + 16]
  vbroadcasti32x4 zmm.c16, xmmword ptr [q.c + 32]
  ;; k: 0 v6=v7*c4 | 1 v5=v7*c8 | 2 v4=v6*c8 | 3 v3=v7*c16 | 4 v2=v6*c16 | 5 v1=v5*c16 | 6 v0=v4*c16
.for k, 0, 7
  vpclmulqdq zmm.lo, zmm.v${if k == 0 {7} else if k == 1 {7} else if k == 2 {6} else if k == 3 {7} else if k == 4 {6} else if k == 5 {5} else {4}}, zmm.c${if k == 0 {4} else if k < 3 {8} else {16}}, 0x00
  vpclmulqdq zmm.hi, zmm.v${if k == 0 {7} else if k == 1 {7} else if k == 2 {6} else if k == 3 {7} else if k == 4 {6} else if k == 5 {5} else {4}}, zmm.c${if k == 0 {4} else if k < 3 {8} else {16}}, 0x11
  vpclmulqdq zmm.mid, zmm.v${if k == 0 {7} else if k == 1 {7} else if k == 2 {6} else if k == 3 {7} else if k == 4 {6} else if k == 5 {5} else {4}}, zmm.c${if k == 0 {4} else if k < 3 {8} else {16}}, 0x10
  vpclmulqdq zmm.t, zmm.v${if k == 0 {7} else if k == 1 {7} else if k == 2 {6} else if k == 3 {7} else if k == 4 {6} else if k == 5 {5} else {4}}, zmm.c${if k == 0 {4} else if k < 3 {8} else {16}}, 0x01
  vpxorq zmm.mid, zmm.mid, zmm.t
  vpslldq zmm.t, zmm.mid, 8
  vpsrldq zmm.mid, zmm.mid, 8
  vpxorq zmm.lo, zmm.lo, zmm.t
  vpxorq zmm.hi, zmm.hi, zmm.mid
  vpsrld zmm.t7, zmm.lo, 31
  vpsrld zmm.t8, zmm.hi, 31
  vpslld zmm.lo, zmm.lo, 1
  vpslld zmm.hi, zmm.hi, 1
  vpsrldq zmm.t9, zmm.t7, 12
  vpslldq zmm.t8, zmm.t8, 4
  vpslldq zmm.t7, zmm.t7, 4
  vporq zmm.lo, zmm.lo, zmm.t7
  vporq zmm.hi, zmm.hi, zmm.t8
  vporq zmm.hi, zmm.hi, zmm.t9
  vpslld zmm.t7, zmm.lo, 31
  vpslld zmm.t8, zmm.lo, 30
  vpslld zmm.t9, zmm.lo, 25
  vpxorq zmm.t7, zmm.t7, zmm.t8
  vpxorq zmm.t7, zmm.t7, zmm.t9
  vpsrldq zmm.t8, zmm.t7, 4
  vpslldq zmm.t7, zmm.t7, 12
  vpxorq zmm.lo, zmm.lo, zmm.t7
  vpsrld zmm.t2, zmm.lo, 1
  vpsrld zmm.t4, zmm.lo, 2
  vpsrld zmm.t5, zmm.lo, 7
  vpxorq zmm.t2, zmm.t2, zmm.t4
  vpxorq zmm.t2, zmm.t2, zmm.t5
  vpxorq zmm.t2, zmm.t2, zmm.t8
  vpxorq zmm.lo, zmm.lo, zmm.t2
  vpxorq zmm.v${6 - k}, zmm.hi, zmm.lo
.endfor
.for k, 0, 7
  vmovdqu64 zmmword ptr [q.htab + ${64 * k}], zmm.v${k}
.endfor
  ret
.end
