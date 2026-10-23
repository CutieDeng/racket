;; Poly1305 on SSE2 (x86-64 SysV), the tier for CPUs without AVX2 or BMI2: two blocks per
;; group in radix 2^26 (five 26-bit limbs in the two 64-bit lanes of five xmm registers),
;; lane k accumulating every second block with r^2; the final group multiplies lane 0 by r^2
;; and lane 1 by r so that the lane sum is the hash. Each 5x5 limb product is a pmuludq
;; against an aligned table row in memory (r^2 limbs and their 5x variants); two carry passes.
;; Legacy two-operand encodings, masks from aligned rodata, data through movdqu.
;;   void rktcrypto_poly1305_blocks_sse2(uint64_t h[5], const uint64_t tab[36],
;;                                       const unsigned char *m, intptr_t groups)
;; h = the accumulator in radix 2^26 (in: lane 0; out: the lane sums, below 2^28);
;; tab rows 0..8 = r^2 limbs r0..r4 broadcast to both lanes and 5*r1..5*r4 (16 bytes a row),
;; rows 9..17 the same for the per-lane final powers (r^2, r); tab 16-byte aligned;
;; groups >= 1 groups of two full blocks (the 2^128 bit is set on every block).
;; Oracle: the radix-2^26 C code with the kernel's tier cleared; gate: asm/tests/test_poly1305_x86.c.

.rodata poly1305_sse2_consts align=16
  .quad 0x3ffffff, 0x3ffffff                      ; +0   2^26-1
  .quad 0x1000000, 0x1000000                      ; +16  2^24: the 2^128 bit in limb 4
.end

.function rktcrypto_poly1305_blocks_sse2 export (
  in: q.hp, q.tab, q.m, q.n2
)
  movq xmm.h0, qword ptr [q.hp]                    ; lane 0 = h, lane 1 zero
  movq xmm.h1, qword ptr [q.hp + 8]
  movq xmm.h2, qword ptr [q.hp + 16]
  movq xmm.h3, qword ptr [q.hp + 24]
  movq xmm.h4, qword ptr [q.hp + 32]
  mov q.rs, q.tab
  cmp q.n2, 1
  jne grp
  add q.rs, 144                                    ; a single group: the per-lane final powers
grp:
  movdqu xmm.lo, xmmword ptr [q.m]                 ; block 0 = (lo, hi)
  movdqu xmm.hi, xmmword ptr [q.m + 16]            ; block 1
  movdqa xmm.t, xmm.lo
  punpcklqdq xmm.lo, xmm.hi                        ; (b0.lo, b1.lo)
  punpckhqdq xmm.t, xmm.hi                         ; (b0.hi, b1.hi)
  movdqa xmm.hi, xmm.t
  movdqa xmm.t, xmm.lo
  pand xmm.t, xmmword ptr [rip + poly1305_sse2_consts]
  paddq xmm.h0, xmm.t
  movdqa xmm.t, xmm.lo
  psrlq xmm.t, 26
  pand xmm.t, xmmword ptr [rip + poly1305_sse2_consts]
  paddq xmm.h1, xmm.t
  movdqa xmm.t, xmm.lo
  psrlq xmm.t, 52
  movdqa xmm.u, xmm.hi
  psllq xmm.u, 12
  por xmm.t, xmm.u
  pand xmm.t, xmmword ptr [rip + poly1305_sse2_consts]
  paddq xmm.h2, xmm.t
  movdqa xmm.t, xmm.hi
  psrlq xmm.t, 14
  pand xmm.t, xmmword ptr [rip + poly1305_sse2_consts]
  paddq xmm.h3, xmm.t
  movdqa xmm.t, xmm.hi
  psrlq xmm.t, 40
  por xmm.t, xmmword ptr [rip + poly1305_sse2_consts + 16]
  paddq xmm.h4, xmm.t
  ;; d_i = sum_{j<=i} h_j r_{i-j} + sum_{j>i} h_j 5r_{5+i-j}  (rows: r0..r4 at 0..4, 5r1..5r4 at 5..8)
.for i, 0, 5
  .for j, 0, 5
  .for z, if j == 0 {0} else {1}, 1
  movdqa xmm.d${i}, xmm.h${j}
  pmuludq xmm.d${i}, xmmword ptr [q.rs + ${16 * (if j <= i {i - j} else {9 + i - j})}]
  .endfor
  .for z, if j == 0 {1} else {0}, 1
  movdqa xmm.t, xmm.h${j}
  pmuludq xmm.t, xmmword ptr [q.rs + ${16 * (if j <= i {i - j} else {9 + i - j})}]
  paddq xmm.d${i}, xmm.t
  .endfor
  .endfor
.endfor
  ;; carries: 26 bits per limb, limb 4 wraps to limb 0 times 5
  movdqa xmm.t, xmm.d0
  psrlq xmm.t, 26
  pand xmm.d0, xmmword ptr [rip + poly1305_sse2_consts]
  paddq xmm.d1, xmm.t
  movdqa xmm.t, xmm.d1
  psrlq xmm.t, 26
  pand xmm.d1, xmmword ptr [rip + poly1305_sse2_consts]
  paddq xmm.d2, xmm.t
  movdqa xmm.t, xmm.d2
  psrlq xmm.t, 26
  pand xmm.d2, xmmword ptr [rip + poly1305_sse2_consts]
  paddq xmm.d3, xmm.t
  movdqa xmm.t, xmm.d3
  psrlq xmm.t, 26
  pand xmm.d3, xmmword ptr [rip + poly1305_sse2_consts]
  paddq xmm.d4, xmm.t
  movdqa xmm.t, xmm.d4
  psrlq xmm.t, 26
  pand xmm.d4, xmmword ptr [rip + poly1305_sse2_consts]
  movdqa xmm.u, xmm.t
  psllq xmm.u, 2
  paddq xmm.t, xmm.u                               ; carry * 5
  paddq xmm.d0, xmm.t
  movdqa xmm.t, xmm.d0
  psrlq xmm.t, 26
  pand xmm.d0, xmmword ptr [rip + poly1305_sse2_consts]
  paddq xmm.d1, xmm.t
  movdqa xmm.h0, xmm.d0
  movdqa xmm.h1, xmm.d1
  movdqa xmm.h2, xmm.d2
  movdqa xmm.h3, xmm.d3
  movdqa xmm.h4, xmm.d4
  add q.m, 32
  sub q.n2, 1
  jz done
  cmp q.n2, 1
  jne grp
  add q.rs, 144                                    ; the last group: per-lane final powers
  jmp grp
done:
.for i, 0, 5
  pshufd xmm.t, xmm.h${i}, 0x4e
  paddq xmm.h${i}, xmm.t
  movq qword ptr [q.hp + ${8 * i}], xmm.h${i}
.endfor
  ret
.end
