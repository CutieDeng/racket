;; Poly1305 on AVX-512 IFMA (x86-64 SysV): eight blocks per vector in radix 2^44 (limbs of
;; 44/44/42 bits), lane k accumulating every eighth block with r^8; the final group multiplies
;; lane k by r^(8-k) so that the lane sum is the hash. Each 3x3 limb product is a pair of
;; vpmadd52luq/vpmadd52huq (the high halves shift left by 8 into the next limb, position 3
;; wraps with 20 = 4 * 5), then one carry pass. The table holds the broadcast r^8 limbs and
;; 20 * limb variants (rows 0..4) and the per-lane final powers (rows 5..9), 64 bytes a row.
;;   void rktcrypto_poly1305_blocks_ifma(uint64_t h44[3], const uint64_t tab[80],
;;                                       const unsigned char *m, intptr_t groups)
;; h44 = the accumulator in radix 2^44 (in: lane 0, out: the lane sum, limbs below 2^48);
;; groups >= 1 groups of eight full blocks (the 2^128 bit is set on every block).
;; Oracle: the radix-2^64 MULX kernel with the IFMA feature bit cleared; gate: test_poly1305_x86.c.

.rodata poly1305_ifma_consts align=64
  .quad 0, 2, 4, 6, 8, 10, 12, 14                  ; +0   low halves of the eight blocks
  .quad 1, 3, 5, 7, 9, 11, 13, 15                  ; +64  high halves
  .quad 0xfffffffffff, 0xfffffffffff, 0xfffffffffff, 0xfffffffffff, 0xfffffffffff, 0xfffffffffff, 0xfffffffffff, 0xfffffffffff   ; +128 2^44-1
  .quad 0x3ffffffffff, 0x3ffffffffff, 0x3ffffffffff, 0x3ffffffffff, 0x3ffffffffff, 0x3ffffffffff, 0x3ffffffffff, 0x3ffffffffff   ; +192 2^42-1
  .quad 0xffffff, 0xffffff, 0xffffff, 0xffffff, 0xffffff, 0xffffff, 0xffffff, 0xffffff                                           ; +256 2^24-1
  .quad 0x10000000000, 0x10000000000, 0x10000000000, 0x10000000000, 0x10000000000, 0x10000000000, 0x10000000000, 0x10000000000   ; +320 2^40: the 2^128 bit in limb 2
.end

.function rktcrypto_poly1305_blocks_ifma export (
  in: q.hp, q.tab, q.m, q.n8
)
  .simd avx512
  vmovq xmm.h0, qword ptr [q.hp]                   ; lane 0 = h, the other lanes zero
  vmovq xmm.h1, qword ptr [q.hp + 8]
  vmovq xmm.h2, qword ptr [q.hp + 16]
  vmovdqa64 zmm.ie, zmmword ptr [rip + poly1305_ifma_consts]
  vmovdqa64 zmm.io, zmmword ptr [rip + poly1305_ifma_consts + 64]
  vmovdqa64 zmm.m44, zmmword ptr [rip + poly1305_ifma_consts + 128]
  vmovdqa64 zmm.m42, zmmword ptr [rip + poly1305_ifma_consts + 192]
  vmovdqa64 zmm.m24, zmmword ptr [rip + poly1305_ifma_consts + 256]
  vmovdqa64 zmm.b40, zmmword ptr [rip + poly1305_ifma_consts + 320]
  mov q.rs, q.tab
  cmp q.n8, 1
  jne grp
  add q.rs, 320                                    ; a single group: the per-lane final powers
grp:
  vmovdqu64 zmm.v0, zmmword ptr [q.m]
  vmovdqu64 zmm.v1, zmmword ptr [q.m + 64]
  vmovdqa64 zmm.lo, zmm.ie
  vpermi2q zmm.lo, zmm.v0, zmm.v1                  ; low 64 bits of blocks 0..7
  vmovdqa64 zmm.hi, zmm.io
  vpermi2q zmm.hi, zmm.v0, zmm.v1                  ; high 64 bits
  vpandq zmm.t0, zmm.lo, zmm.m44
  vpsrlq zmm.t1, zmm.lo, 44
  vpandq zmm.t, zmm.hi, zmm.m24
  vpsllq zmm.t, zmm.t, 20
  vporq zmm.t1, zmm.t1, zmm.t
  vpsrlq zmm.t2, zmm.hi, 24
  vporq zmm.t2, zmm.t2, zmm.b40
  vpaddq zmm.h0, zmm.h0, zmm.t0
  vpaddq zmm.h1, zmm.h1, zmm.t1
  vpaddq zmm.h2, zmm.h2, zmm.t2
  vpxorq zmm.d0, zmm.d0, zmm.d0
  vpxorq zmm.d1, zmm.d1, zmm.d1
  vpxorq zmm.d2, zmm.d2, zmm.d2
  vpxorq zmm.e0, zmm.e0, zmm.e0
  vpxorq zmm.e1, zmm.e1, zmm.e1
  vpxorq zmm.e2, zmm.e2, zmm.e2
  vpmadd52luq zmm.d0, zmm.h0, zmmword ptr [q.rs]          ; h0*r0
  vpmadd52huq zmm.e0, zmm.h0, zmmword ptr [q.rs]
  vpmadd52luq zmm.d0, zmm.h1, zmmword ptr [q.rs + 256]    ; h1*s2
  vpmadd52huq zmm.e0, zmm.h1, zmmword ptr [q.rs + 256]
  vpmadd52luq zmm.d0, zmm.h2, zmmword ptr [q.rs + 192]    ; h2*s1
  vpmadd52huq zmm.e0, zmm.h2, zmmword ptr [q.rs + 192]
  vpmadd52luq zmm.d1, zmm.h0, zmmword ptr [q.rs + 64]     ; h0*r1
  vpmadd52huq zmm.e1, zmm.h0, zmmword ptr [q.rs + 64]
  vpmadd52luq zmm.d1, zmm.h1, zmmword ptr [q.rs]          ; h1*r0
  vpmadd52huq zmm.e1, zmm.h1, zmmword ptr [q.rs]
  vpmadd52luq zmm.d1, zmm.h2, zmmword ptr [q.rs + 256]    ; h2*s2
  vpmadd52huq zmm.e1, zmm.h2, zmmword ptr [q.rs + 256]
  vpmadd52luq zmm.d2, zmm.h0, zmmword ptr [q.rs + 128]    ; h0*r2
  vpmadd52huq zmm.e2, zmm.h0, zmmword ptr [q.rs + 128]
  vpmadd52luq zmm.d2, zmm.h1, zmmword ptr [q.rs + 64]     ; h1*r1
  vpmadd52huq zmm.e2, zmm.h1, zmmword ptr [q.rs + 64]
  vpmadd52luq zmm.d2, zmm.h2, zmmword ptr [q.rs]          ; h2*r0
  vpmadd52huq zmm.e2, zmm.h2, zmmword ptr [q.rs]
  vpsllq zmm.e0, zmm.e0, 8                         ; high halves: 2^52 = 2^44 * 2^8
  vpaddq zmm.d1, zmm.d1, zmm.e0
  vpsllq zmm.e1, zmm.e1, 8
  vpaddq zmm.d2, zmm.d2, zmm.e1
  vpsllq zmm.t, zmm.e2, 12                         ; position 3: 2^140 = 2^130 * 2^10, times 5 = (<<10) + (<<12)
  vpaddq zmm.d0, zmm.d0, zmm.t
  vpsllq zmm.t, zmm.e2, 10
  vpaddq zmm.d0, zmm.d0, zmm.t
  vpsrlq zmm.t, zmm.d0, 44
  vpandq zmm.h0, zmm.d0, zmm.m44
  vpaddq zmm.d1, zmm.d1, zmm.t
  vpsrlq zmm.t, zmm.d1, 44
  vpandq zmm.h1, zmm.d1, zmm.m44
  vpaddq zmm.d2, zmm.d2, zmm.t
  vpsrlq zmm.t, zmm.d2, 42
  vpandq zmm.h2, zmm.d2, zmm.m42
  vpaddq zmm.h0, zmm.h0, zmm.t                     ; carry out of limb 2: 2^130 = 5
  vpsllq zmm.t, zmm.t, 2
  vpaddq zmm.h0, zmm.h0, zmm.t
  add q.m, 128
  sub q.n8, 1
  jz done
  cmp q.n8, 1
  jne grp
  add q.rs, 320                                    ; last group: per-lane powers r^(8-k)
  jmp grp
done:
.for i, 0, 3
  vextracti64x4 ymm.t, zmm.h${i}, 1
  vpaddq ymm.h${i}, ymm.h${i}, ymm.t
  vextracti32x4 xmm.t, ymm.h${i}, 1
  vpaddq xmm.h${i}, xmm.h${i}, xmm.t
  vpsrldq xmm.t, xmm.h${i}, 8
  vpaddq xmm.h${i}, xmm.h${i}, xmm.t
  vmovq qword ptr [q.hp + ${8 * i}], xmm.h${i}
.endfor
  ret
.end
