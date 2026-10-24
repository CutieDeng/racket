;; GHASH accumulation on VPCLMULQDQ + AVX-512 (x86-64 SysV): 16 blocks per iteration,
;; four 512-bit registers of data against the powers H^16..H^1, one reduction per 16 blocks.
;;   void rktcrypto_ghash_vpclmul(const unsigned char htab[256], unsigned char acc[16],
;;                                const unsigned char *data, intptr_t len)
;; htab[16k..16k+15] = H^(16-k) (k = 0..15), acc and htab in the byte-reversed representation
;; used by rktcrypto_ghash_x86 (rktcrypto_x86.c), len a multiple of 64; acc updated in place.
;; The 256-bit products are accumulated raw (gcm_mul_raw) and reduced once with the same
;; shift-then-fold sequence as the intrinsics (gcm_reduce), so the result is bit-identical.
;; Oracle: rktcrypto_ghash_x86 with VPCLMULQDQ disabled; gate: asm/tests/test_ghash_vpclmul.c.

.rodata ghash_vpclmul_bswap align=16
  .byte 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0
.end

.function rktcrypto_ghash_vpclmul export (
  in: q.htab, q.accp, q.data, q.len
)
  vbroadcasti32x4 zmm.bswap, xmmword ptr [rip + ghash_vpclmul_bswap]
  vmovdqu xmm.acc, xmmword ptr [q.accp]
  cmp q.len, 256
  jb tail64
loop256:
.for j, 0, 4
  vmovdqu64 zmm.d${j}, zmmword ptr [q.data + ${64 * j}]
  vpshufb zmm.d${j}, zmm.d${j}, zmm.bswap
.endfor
  vpxorq zmm.d0, zmm.d0, zmm.acc                   ; acc into block 0 (upper lanes of acc are zero)
  ;; raw products: lo = a0*b0, hi = a1*b1, mid = a0*b1 ^ a1*b0, summed over the 16 blocks
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
  add q.data, 256
  sub q.len, 256
  jmp fold
tail64:
  test q.len, q.len
  jz done
  vmovdqu64 zmm.d0, zmmword ptr [q.data]
  vpshufb zmm.d0, zmm.d0, zmm.bswap
  vpxorq zmm.d0, zmm.d0, zmm.acc
  vpclmulqdq zmm.lo, zmm.d0, zmmword ptr [q.htab + 192], 0x00   ; H^4 H^3 H^2 H^1
  vpclmulqdq zmm.hi, zmm.d0, zmmword ptr [q.htab + 192], 0x11
  vpclmulqdq zmm.mid, zmm.d0, zmmword ptr [q.htab + 192], 0x10
  vpclmulqdq zmm.t, zmm.d0, zmmword ptr [q.htab + 192], 0x01
  vpxorq zmm.mid, zmm.mid, zmm.t
  add q.data, 64
  sub q.len, 64
fold:
  ;; mid folds into lo/hi (gcm_mul_raw), then the four lanes fold into one 128-bit pair
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
  ;; gcm_reduce(lo, hi): shift the 256-bit product left by one, then fold modulo the polynomial
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
  cmp q.len, 256
  jae loop256
  jmp tail64
done:
  vmovdqu xmmword ptr [q.accp], xmm.acc
  ret
.end
