;; Fused AES-GCM bulk pass on VAES + VPCLMULQDQ + AVX-512 (x86-64 SysV): per 256-byte
;; chunk, sixteen CTR blocks (inc32) are encrypted in four 512-bit registers and XORed
;; with the input; the ciphertext of the previous chunk is folded into the GHASH
;; accumulator in the same iteration, so the serial GHASH reduction chain overlaps the
;; AES rounds of the next chunk. One kernel serves both directions: the GHASH input is
;; the ciphertext, taken from the registers after the XOR (encrypt) or loaded before the
;; output store (decrypt, which also makes in-place decryption safe).
;;   intptr_t rktcrypto_gcm_crypt_vaes(const struct rktcrypto_gcm_vaes_ctx *c,
;;                                     const unsigned char *in, unsigned char *out, intptr_t len)
;; ctx: rk@0, htab@8 (H^16..H^1, byte-reversed), ctr@16 (big-endian, updated), acc@24
;; (byte-reversed, updated), nr@32, enc@40. Returns the bytes processed (a multiple of
;; 256); the C side finishes the remainder on the CTR and GHASH paths.
;; Oracle: the two-pass path (rktcrypto_aes_ctr_aesni + rktcrypto_ghash_x86);
;; gate: asm/tests/test_gcm_vaes.c.

.rodata gcm_vaes_bswap align=16
  .byte 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0
.end
.rodata gcm_vaes_inc align=64                   ; lane i of vector j holds 4j+i in dword 0
  .long 0,0,0,0, 1,0,0,0, 2,0,0,0, 3,0,0,0
  .long 4,0,0,0, 5,0,0,0, 6,0,0,0, 7,0,0,0
  .long 8,0,0,0, 9,0,0,0, 10,0,0,0, 11,0,0,0
  .long 12,0,0,0, 13,0,0,0, 14,0,0,0, 15,0,0,0
.end
.rodata gcm_vaes_sixteen align=64
  .long 16,0,0,0, 16,0,0,0, 16,0,0,0, 16,0,0,0
.end

.function rktcrypto_gcm_crypt_vaes export (
  in: q.ctx, q.in, q.out, q.len
  out: q.ret
)
  .simd avx512
  xor d.ret, d.ret
  cmp q.len, 256
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
  vmovdqu xmm.acc, xmmword ptr [q.p]
  xor d.pending, d.pending                       ; no ciphertext chunk waiting for GHASH yet
loop:
  ;; ---- GHASH of the previous chunk (d0..d3, byte-reversed ciphertext)
  test d.pending, d.pending
  jz skipghash
  vpxorq zmm.d0, zmm.d0, zmm.acc
  vpclmulqdq zmm.lo, zmm.d0, zmmword ptr [q.htab], 0x00
  vpclmulqdq zmm.hi, zmm.d0, zmmword ptr [q.htab], 0x11
  vpclmulqdq zmm.mid, zmm.d0, zmmword ptr [q.htab], 0x10
  vpclmulqdq zmm.t, zmm.d0, zmmword ptr [q.htab], 0x01
  vpxorq zmm.mid, zmm.mid, zmm.t
.for j, 1, 4
  vpclmulqdq zmm.t, zmm.d${j}, zmmword ptr [q.htab + ${64 * j}], 0x00
  vpxorq zmm.lo, zmm.lo, zmm.t
  vpclmulqdq zmm.t, zmm.d${j}, zmmword ptr [q.htab + ${64 * j}], 0x11
  vpxorq zmm.hi, zmm.hi, zmm.t
  vpclmulqdq zmm.t, zmm.d${j}, zmmword ptr [q.htab + ${64 * j}], 0x10
  vpxorq zmm.mid, zmm.mid, zmm.t
  vpclmulqdq zmm.t, zmm.d${j}, zmmword ptr [q.htab + ${64 * j}], 0x01
  vpxorq zmm.mid, zmm.mid, zmm.t
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
  vpor xmm.lo, xmm.lo, xmm.t7
  vpor xmm.hi, xmm.hi, xmm.t8
  vpor xmm.hi, xmm.hi, xmm.t9
  vpslld xmm.t7, xmm.lo, 31
  vpslld xmm.t8, xmm.lo, 30
  vpslld xmm.t9, xmm.lo, 25
  vpxor xmm.t7, xmm.t7, xmm.t8
  vpxor xmm.t7, xmm.t7, xmm.t9
  vpsrldq xmm.t8, xmm.t7, 4
  vpslldq xmm.t7, xmm.t7, 12
  vpxor xmm.lo, xmm.lo, xmm.t7
  vpsrld xmm.t2, xmm.lo, 1
  vpsrld xmm.t4, xmm.lo, 2
  vpsrld xmm.t5, xmm.lo, 7
  vpxor xmm.t2, xmm.t2, xmm.t4
  vpxor xmm.t2, xmm.t2, xmm.t5
  vpxor xmm.t2, xmm.t2, xmm.t8
  vpxor xmm.lo, xmm.lo, xmm.t2
  vpxor xmm.acc, xmm.hi, xmm.lo
skipghash:
  cmp q.len, 256
  jb fin
  ;; ---- AES-CTR for the current chunk: sixteen counters, inc32
.for j, 0, 4
  vpaddd zmm.s${j}, zmm.base, zmmword ptr [rip + gcm_vaes_inc + ${64 * j}]
.endfor
  vpaddd zmm.base, zmm.base, zmmword ptr [rip + gcm_vaes_sixteen]
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
  je last
.for r, 10, 12
  vbroadcasti32x4 zmm.k, xmmword ptr [q.rk + ${16 * r}]
  .for j, 0, 4
  vaesenc zmm.s${j}, zmm.s${j}, zmm.k
  .endfor
.endfor
  cmp d.nr, 12
  je last
.for r, 12, 14
  vbroadcasti32x4 zmm.k, xmmword ptr [q.rk + ${16 * r}]
  .for j, 0, 4
  vaesenc zmm.s${j}, zmm.s${j}, zmm.k
  .endfor
.endfor
last:
.for j, 0, 4
  vaesenclast zmm.s${j}, zmm.s${j}, zmm.klast
.endfor
  ;; decrypt: the ciphertext is the input, captured before the store (in-place safe)
  test d.enc, d.enc
  jnz xorstore
.for j, 0, 4
  vmovdqu64 zmm.d${j}, zmmword ptr [q.in + ${64 * j}]
.endfor
xorstore:
.for j, 0, 4
  vpxorq zmm.s${j}, zmm.s${j}, zmmword ptr [q.in + ${64 * j}]
  vmovdqu64 zmmword ptr [q.out + ${64 * j}], zmm.s${j}
.endfor
  test d.enc, d.enc
  jz reverse
.for j, 0, 4
  vmovdqa64 zmm.d${j}, zmm.s${j}                 ; encrypt: the ciphertext just produced
.endfor
reverse:
.for j, 0, 4
  vpshufb zmm.d${j}, zmm.d${j}, zmm.bswap
.endfor
  mov d.pending, 1
  add q.in, 256
  add q.out, 256
  add q.ret, 256
  sub q.len, 256
  jmp loop
fin:
  vmovdqu xmmword ptr [q.p], xmm.acc
  mov q.p, qword ptr [q.ctx + 16]
  vpshufb xmm.t, xmm.base, xmm.bswap
  vmovdqu xmmword ptr [q.p], xmm.t
done:
  ret
.end
