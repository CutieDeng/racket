;; Poly1305 on AVX2 (x86-64 SysV), the tier for CPUs without AVX-512 IFMA: four blocks per
;; group in radix 2^26 (five 26-bit limbs in the 64-bit lanes of five ymm registers), lane k
;; accumulating every fourth block with r^4; the final group multiplies the lanes by their
;; own powers so that the lane sum is the hash. The lanes hold the blocks in the order the
;; qword unpacks give (block 0, 2, 1, 3), which the C side's table follows. Each 5x5 limb
;; product is a vpmuludq against a broadcast table row in memory (r^4 limbs and their 5x
;; variants, no register needed), then two carry passes.
;;   void rktcrypto_poly1305_blocks_avx2(uint64_t h[5], const uint64_t tab[72],
;;                                       const unsigned char *m, intptr_t groups)
;; h = the accumulator in radix 2^26 (in: lane 0; out: the lane sums, below 2^29);
;; tab rows 0..8 = r^4 limbs r0..r4 broadcast and 5*r1..5*r4 (32 bytes a row), rows 9..17
;; the same for the per-lane final powers (r^4, r^2, r^3, r); groups >= 1 groups of four full
;; blocks (the 2^128 bit is set on every block). Oracle: the radix-2^64 MULX kernel with AVX2
;; cleared; gate: asm/tests/test_poly1305_x86.c.

.rodata poly1305_avx2_consts align=32
  .quad 0x3ffffff, 0x3ffffff, 0x3ffffff, 0x3ffffff   ; +0   2^26-1
  .quad 0x1000000, 0x1000000, 0x1000000, 0x1000000   ; +32  2^24: the 2^128 bit in limb 4
.end

.function rktcrypto_poly1305_blocks_avx2 export (
  in: q.hp, q.tab, q.m, q.n4
)
  .simd avx2
  vmovq xmm.h0, qword ptr [q.hp]                   ; lane 0 = h, the other lanes zero
  vmovq xmm.h1, qword ptr [q.hp + 8]
  vmovq xmm.h2, qword ptr [q.hp + 16]
  vmovq xmm.h3, qword ptr [q.hp + 24]
  vmovq xmm.h4, qword ptr [q.hp + 32]
  mov q.rs, q.tab
  cmp q.n4, 1
  jne grp
  add q.rs, 288                                    ; a single group: the per-lane final powers
grp:
  ;; four blocks -> lo/hi qwords per lane (lane order 0, 2, 1, 3), then the five limbs added to h
  vmovdqu ymm.a, ymmword ptr [q.m]
  vmovdqu ymm.b, ymmword ptr [q.m + 32]
  vpunpcklqdq ymm.lo, ymm.a, ymm.b
  vpunpckhqdq ymm.hi, ymm.a, ymm.b
  vpand ymm.t, ymm.lo, ymmword ptr [rip + poly1305_avx2_consts]
  vpaddq ymm.h0, ymm.h0, ymm.t
  vpsrlq ymm.t, ymm.lo, 26
  vpand ymm.t, ymm.t, ymmword ptr [rip + poly1305_avx2_consts]
  vpaddq ymm.h1, ymm.h1, ymm.t
  vpsrlq ymm.t, ymm.lo, 52
  vpsllq ymm.u, ymm.hi, 12
  vpor ymm.t, ymm.t, ymm.u
  vpand ymm.t, ymm.t, ymmword ptr [rip + poly1305_avx2_consts]
  vpaddq ymm.h2, ymm.h2, ymm.t
  vpsrlq ymm.t, ymm.hi, 14
  vpand ymm.t, ymm.t, ymmword ptr [rip + poly1305_avx2_consts]
  vpaddq ymm.h3, ymm.h3, ymm.t
  vpsrlq ymm.t, ymm.hi, 40
  vpor ymm.t, ymm.t, ymmword ptr [rip + poly1305_avx2_consts + 32]
  vpaddq ymm.h4, ymm.h4, ymm.t
  ;; d_i = sum_{j<=i} h_j r_{i-j} + sum_{j>i} h_j 5r_{5+i-j}  (rows: r0..r4 at 0..4, 5r1..5r4 at 5..8)
.for i, 0, 5
  .for j, 0, 5
  vpmuludq ymm.t, ymm.h${j}, ymmword ptr [q.rs + ${32 * (if j <= i {i - j} else {9 + i - j})}]
  .for z, if j == 0 {0} else {1}, 1
  vmovdqa ymm.d${i}, ymm.t
  .endfor
  .for z, if j == 0 {1} else {0}, 1
  vpaddq ymm.d${i}, ymm.d${i}, ymm.t
  .endfor
  .endfor
.endfor
  ;; carries: 26 bits per limb, limb 4 wraps to limb 0 times 5
  vpsrlq ymm.t, ymm.d0, 26
  vpand ymm.h0, ymm.d0, ymmword ptr [rip + poly1305_avx2_consts]
  vpaddq ymm.d1, ymm.d1, ymm.t
  vpsrlq ymm.t, ymm.d1, 26
  vpand ymm.h1, ymm.d1, ymmword ptr [rip + poly1305_avx2_consts]
  vpaddq ymm.d2, ymm.d2, ymm.t
  vpsrlq ymm.t, ymm.d2, 26
  vpand ymm.h2, ymm.d2, ymmword ptr [rip + poly1305_avx2_consts]
  vpaddq ymm.d3, ymm.d3, ymm.t
  vpsrlq ymm.t, ymm.d3, 26
  vpand ymm.h3, ymm.d3, ymmword ptr [rip + poly1305_avx2_consts]
  vpaddq ymm.d4, ymm.d4, ymm.t
  vpsrlq ymm.t, ymm.d4, 26
  vpand ymm.h4, ymm.d4, ymmword ptr [rip + poly1305_avx2_consts]
  vpsllq ymm.u, ymm.t, 2
  vpaddq ymm.t, ymm.t, ymm.u                       ; carry * 5
  vpaddq ymm.h0, ymm.h0, ymm.t
  vpsrlq ymm.t, ymm.h0, 26
  vpand ymm.h0, ymm.h0, ymmword ptr [rip + poly1305_avx2_consts]
  vpaddq ymm.h1, ymm.h1, ymm.t
  add q.m, 64
  sub q.n4, 1
  jz done
  cmp q.n4, 1
  jne grp
  add q.rs, 288                                    ; the last group: per-lane final powers
  jmp grp
done:
  ;; lane sums
.for i, 0, 5
  vextracti128 xmm.t, ymm.h${i}, 1
  vpaddq xmm.h${i}, xmm.h${i}, xmm.t
  vpshufd xmm.t, xmm.h${i}, 0x4e
  vpaddq xmm.h${i}, xmm.h${i}, xmm.t
  vmovq qword ptr [q.hp + ${8 * i}], xmm.h${i}
.endfor
  ret
.end
