;; Poly1305 on SSE2 (x86-64 SysV), the tier for CPUs without AVX2 or BMI2: four blocks per
;; group as two accumulator sets of two lanes each in radix 2^26 (set A takes blocks 4g, 4g+1,
;; set B blocks 4g+2, 4g+3), every lane accumulating with r^4; the final group multiplies the
;; lanes by their own powers (A: r^4, r^3; B: r^2, r) so that the sum of the four lanes is the
;; hash. Each 5x5 limb product is a pmuludq against an aligned table row in memory; set B's
;; products follow set A's carries (sixteen registers: two sets, five sums, two scratch).
;; Legacy two-operand encodings, masks from aligned rodata, data through movdqu.
;;   void rktcrypto_poly1305_blocks_sse2(uint64_t h[5], const uint64_t tab[54],
;;                                       const unsigned char *m, intptr_t groups)
;; h = the accumulator in radix 2^26 (in: lane 0 of set A; out: the lane sums, below 2^29);
;; tab: rows 0..8 = r^4 limbs in both lanes and 5*r1..5*r4 (16 bytes a row), rows 9..17 the
;; final powers of set A (r^4, r^3), rows 18..26 of set B (r^2, r); tab 16-byte aligned;
;; groups >= 1 groups of four full blocks (the 2^128 bit is set on every block).
;; Oracle: the radix-2^26 C code with the SSE2 bit cleared; gate: asm/tests/test_poly1305_x86.c.

.rodata poly1305_sse2_consts align=16
  .quad 0x3ffffff, 0x3ffffff                      ; +0   2^26-1
  .quad 0x1000000, 0x1000000                      ; +16  2^24: the 2^128 bit in limb 4
.end

.function rktcrypto_poly1305_blocks_sse2 export (
  in: q.hp, q.tab, q.m, q.n4
)
  movq xmm.a0, qword ptr [q.hp]                    ; lane 0 of set A = h, every other lane zero
  movq xmm.a1, qword ptr [q.hp + 8]
  movq xmm.a2, qword ptr [q.hp + 16]
  movq xmm.a3, qword ptr [q.hp + 24]
  movq xmm.a4, qword ptr [q.hp + 32]
  pxor xmm.b0, xmm.b0
  pxor xmm.b1, xmm.b1
  pxor xmm.b2, xmm.b2
  pxor xmm.b3, xmm.b3
  pxor xmm.b4, xmm.b4
  mov q.rs, q.tab
  xor q.fin, q.fin                                 ; 0: steady rows for both sets; 144: final rows (A at +144, B at +288)
  cmp q.n4, 1
  jne grp
  mov q.fin, 144
grp:
  ;; set A: blocks 0, 1 -> lo/hi qwords per lane, limbs added
  movdqu xmm.d1, xmmword ptr [q.m]
  movdqu xmm.d2, xmmword ptr [q.m + 16]
  movdqa xmm.d3, xmm.d1
  punpcklqdq xmm.d1, xmm.d2                        ; (b0.lo, b1.lo)
  punpckhqdq xmm.d3, xmm.d2                        ; (b0.hi, b1.hi)
  movdqa xmm.t, xmm.d1
  pand xmm.t, xmmword ptr [rip + poly1305_sse2_consts]
  paddq xmm.a0, xmm.t
  movdqa xmm.t, xmm.d1
  psrlq xmm.t, 26
  pand xmm.t, xmmword ptr [rip + poly1305_sse2_consts]
  paddq xmm.a1, xmm.t
  movdqa xmm.t, xmm.d1
  psrlq xmm.t, 52
  movdqa xmm.d0, xmm.d3
  psllq xmm.d0, 12
  por xmm.t, xmm.d0
  pand xmm.t, xmmword ptr [rip + poly1305_sse2_consts]
  paddq xmm.a2, xmm.t
  movdqa xmm.t, xmm.d3
  psrlq xmm.t, 14
  pand xmm.t, xmmword ptr [rip + poly1305_sse2_consts]
  paddq xmm.a3, xmm.t
  movdqa xmm.t, xmm.d3
  psrlq xmm.t, 40
  por xmm.t, xmmword ptr [rip + poly1305_sse2_consts + 16]
  paddq xmm.a4, xmm.t
  lea q.rs, [q.tab + q.fin]
  movdqa xmm.d0, xmm.a0
  pmuludq xmm.d0, xmmword ptr [q.rs + 0]
  movdqa xmm.t, xmm.a1
  pmuludq xmm.t, xmmword ptr [q.rs + 128]
  paddq xmm.d0, xmm.t
  movdqa xmm.t, xmm.a2
  pmuludq xmm.t, xmmword ptr [q.rs + 112]
  paddq xmm.d0, xmm.t
  movdqa xmm.t, xmm.a3
  pmuludq xmm.t, xmmword ptr [q.rs + 96]
  paddq xmm.d0, xmm.t
  movdqa xmm.t, xmm.a4
  pmuludq xmm.t, xmmword ptr [q.rs + 80]
  paddq xmm.d0, xmm.t
  movdqa xmm.d1, xmm.a0
  pmuludq xmm.d1, xmmword ptr [q.rs + 16]
  movdqa xmm.t, xmm.a1
  pmuludq xmm.t, xmmword ptr [q.rs + 0]
  paddq xmm.d1, xmm.t
  movdqa xmm.t, xmm.a2
  pmuludq xmm.t, xmmword ptr [q.rs + 128]
  paddq xmm.d1, xmm.t
  movdqa xmm.t, xmm.a3
  pmuludq xmm.t, xmmword ptr [q.rs + 112]
  paddq xmm.d1, xmm.t
  movdqa xmm.t, xmm.a4
  pmuludq xmm.t, xmmword ptr [q.rs + 96]
  paddq xmm.d1, xmm.t
  movdqa xmm.d2, xmm.a0
  pmuludq xmm.d2, xmmword ptr [q.rs + 32]
  movdqa xmm.t, xmm.a1
  pmuludq xmm.t, xmmword ptr [q.rs + 16]
  paddq xmm.d2, xmm.t
  movdqa xmm.t, xmm.a2
  pmuludq xmm.t, xmmword ptr [q.rs + 0]
  paddq xmm.d2, xmm.t
  movdqa xmm.t, xmm.a3
  pmuludq xmm.t, xmmword ptr [q.rs + 128]
  paddq xmm.d2, xmm.t
  movdqa xmm.t, xmm.a4
  pmuludq xmm.t, xmmword ptr [q.rs + 112]
  paddq xmm.d2, xmm.t
  movdqa xmm.d3, xmm.a0
  pmuludq xmm.d3, xmmword ptr [q.rs + 48]
  movdqa xmm.t, xmm.a1
  pmuludq xmm.t, xmmword ptr [q.rs + 32]
  paddq xmm.d3, xmm.t
  movdqa xmm.t, xmm.a2
  pmuludq xmm.t, xmmword ptr [q.rs + 16]
  paddq xmm.d3, xmm.t
  movdqa xmm.t, xmm.a3
  pmuludq xmm.t, xmmword ptr [q.rs + 0]
  paddq xmm.d3, xmm.t
  movdqa xmm.t, xmm.a4
  pmuludq xmm.t, xmmword ptr [q.rs + 128]
  paddq xmm.d3, xmm.t
  movdqa xmm.d4, xmm.a0
  pmuludq xmm.d4, xmmword ptr [q.rs + 64]
  movdqa xmm.t, xmm.a1
  pmuludq xmm.t, xmmword ptr [q.rs + 48]
  paddq xmm.d4, xmm.t
  movdqa xmm.t, xmm.a2
  pmuludq xmm.t, xmmword ptr [q.rs + 32]
  paddq xmm.d4, xmm.t
  movdqa xmm.t, xmm.a3
  pmuludq xmm.t, xmmword ptr [q.rs + 16]
  paddq xmm.d4, xmm.t
  movdqa xmm.t, xmm.a4
  pmuludq xmm.t, xmmword ptr [q.rs + 0]
  paddq xmm.d4, xmm.t
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
  paddq xmm.t, xmm.u
  paddq xmm.d0, xmm.t
  movdqa xmm.t, xmm.d0
  psrlq xmm.t, 26
  pand xmm.d0, xmmword ptr [rip + poly1305_sse2_consts]
  paddq xmm.d1, xmm.t
  movdqa xmm.a0, xmm.d0
  movdqa xmm.a1, xmm.d1
  movdqa xmm.a2, xmm.d2
  movdqa xmm.a3, xmm.d3
  movdqa xmm.a4, xmm.d4
  ;; set B: blocks 2, 3
  movdqu xmm.d1, xmmword ptr [q.m + 32]
  movdqu xmm.d2, xmmword ptr [q.m + 48]
  movdqa xmm.d3, xmm.d1
  punpcklqdq xmm.d1, xmm.d2
  punpckhqdq xmm.d3, xmm.d2
  movdqa xmm.t, xmm.d1
  pand xmm.t, xmmword ptr [rip + poly1305_sse2_consts]
  paddq xmm.b0, xmm.t
  movdqa xmm.t, xmm.d1
  psrlq xmm.t, 26
  pand xmm.t, xmmword ptr [rip + poly1305_sse2_consts]
  paddq xmm.b1, xmm.t
  movdqa xmm.t, xmm.d1
  psrlq xmm.t, 52
  movdqa xmm.d0, xmm.d3
  psllq xmm.d0, 12
  por xmm.t, xmm.d0
  pand xmm.t, xmmword ptr [rip + poly1305_sse2_consts]
  paddq xmm.b2, xmm.t
  movdqa xmm.t, xmm.d3
  psrlq xmm.t, 14
  pand xmm.t, xmmword ptr [rip + poly1305_sse2_consts]
  paddq xmm.b3, xmm.t
  movdqa xmm.t, xmm.d3
  psrlq xmm.t, 40
  por xmm.t, xmmword ptr [rip + poly1305_sse2_consts + 16]
  paddq xmm.b4, xmm.t
  lea q.rs, [q.tab + q.fin]
  add q.rs, q.fin                                  ; set B's final rows sit another 144 further
  movdqa xmm.d0, xmm.b0
  pmuludq xmm.d0, xmmword ptr [q.rs + 0]
  movdqa xmm.t, xmm.b1
  pmuludq xmm.t, xmmword ptr [q.rs + 128]
  paddq xmm.d0, xmm.t
  movdqa xmm.t, xmm.b2
  pmuludq xmm.t, xmmword ptr [q.rs + 112]
  paddq xmm.d0, xmm.t
  movdqa xmm.t, xmm.b3
  pmuludq xmm.t, xmmword ptr [q.rs + 96]
  paddq xmm.d0, xmm.t
  movdqa xmm.t, xmm.b4
  pmuludq xmm.t, xmmword ptr [q.rs + 80]
  paddq xmm.d0, xmm.t
  movdqa xmm.d1, xmm.b0
  pmuludq xmm.d1, xmmword ptr [q.rs + 16]
  movdqa xmm.t, xmm.b1
  pmuludq xmm.t, xmmword ptr [q.rs + 0]
  paddq xmm.d1, xmm.t
  movdqa xmm.t, xmm.b2
  pmuludq xmm.t, xmmword ptr [q.rs + 128]
  paddq xmm.d1, xmm.t
  movdqa xmm.t, xmm.b3
  pmuludq xmm.t, xmmword ptr [q.rs + 112]
  paddq xmm.d1, xmm.t
  movdqa xmm.t, xmm.b4
  pmuludq xmm.t, xmmword ptr [q.rs + 96]
  paddq xmm.d1, xmm.t
  movdqa xmm.d2, xmm.b0
  pmuludq xmm.d2, xmmword ptr [q.rs + 32]
  movdqa xmm.t, xmm.b1
  pmuludq xmm.t, xmmword ptr [q.rs + 16]
  paddq xmm.d2, xmm.t
  movdqa xmm.t, xmm.b2
  pmuludq xmm.t, xmmword ptr [q.rs + 0]
  paddq xmm.d2, xmm.t
  movdqa xmm.t, xmm.b3
  pmuludq xmm.t, xmmword ptr [q.rs + 128]
  paddq xmm.d2, xmm.t
  movdqa xmm.t, xmm.b4
  pmuludq xmm.t, xmmword ptr [q.rs + 112]
  paddq xmm.d2, xmm.t
  movdqa xmm.d3, xmm.b0
  pmuludq xmm.d3, xmmword ptr [q.rs + 48]
  movdqa xmm.t, xmm.b1
  pmuludq xmm.t, xmmword ptr [q.rs + 32]
  paddq xmm.d3, xmm.t
  movdqa xmm.t, xmm.b2
  pmuludq xmm.t, xmmword ptr [q.rs + 16]
  paddq xmm.d3, xmm.t
  movdqa xmm.t, xmm.b3
  pmuludq xmm.t, xmmword ptr [q.rs + 0]
  paddq xmm.d3, xmm.t
  movdqa xmm.t, xmm.b4
  pmuludq xmm.t, xmmword ptr [q.rs + 128]
  paddq xmm.d3, xmm.t
  movdqa xmm.d4, xmm.b0
  pmuludq xmm.d4, xmmword ptr [q.rs + 64]
  movdqa xmm.t, xmm.b1
  pmuludq xmm.t, xmmword ptr [q.rs + 48]
  paddq xmm.d4, xmm.t
  movdqa xmm.t, xmm.b2
  pmuludq xmm.t, xmmword ptr [q.rs + 32]
  paddq xmm.d4, xmm.t
  movdqa xmm.t, xmm.b3
  pmuludq xmm.t, xmmword ptr [q.rs + 16]
  paddq xmm.d4, xmm.t
  movdqa xmm.t, xmm.b4
  pmuludq xmm.t, xmmword ptr [q.rs + 0]
  paddq xmm.d4, xmm.t
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
  paddq xmm.t, xmm.u
  paddq xmm.d0, xmm.t
  movdqa xmm.t, xmm.d0
  psrlq xmm.t, 26
  pand xmm.d0, xmmword ptr [rip + poly1305_sse2_consts]
  paddq xmm.d1, xmm.t
  movdqa xmm.b0, xmm.d0
  movdqa xmm.b1, xmm.d1
  movdqa xmm.b2, xmm.d2
  movdqa xmm.b3, xmm.d3
  movdqa xmm.b4, xmm.d4
  add q.m, 64
  sub q.n4, 1
  jz done
  cmp q.n4, 1
  jne grp
  mov q.fin, 144                                   ; the last group: per-lane final powers
  jmp grp
done:
  ;; lane sums of both sets
.for i, 0, 5
  paddq xmm.a${i}, xmm.b${i}
  pshufd xmm.t, xmm.a${i}, 0x4e
  paddq xmm.a${i}, xmm.t
  movq qword ptr [q.hp + ${8 * i}], xmm.a${i}
.endfor
  ret
.end
