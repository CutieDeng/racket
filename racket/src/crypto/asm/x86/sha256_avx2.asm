;; SHA-256 block compression on x86-64 for CPUs without SHA-NI: scalar rounds on BMI2 rorx
;; (the a..h rotation folded into register names, Ch added before Sigma1, Sigma0 + Maj summed
;; before the a' add: five-cycle e and a chains) with the message schedule in xmm registers, four
;; words per step in a ring of four: sigma0 of W[t-15..t-12] and the W[t-16], W[t-7] terms as one
;; four-lane step (vpalignr windows, rotates as shift pairs), sigma1 (dependency distance two)
;; applied to lanes 2,3 of the newest group and then to the two words that produces, each half
;; placed with a byte shift that zero-fills. W + K goes to a 256-byte frame; group g+4 is computed
;; in four slices during the rounds of group g. The same layout as sha512_avx512.asm.
;;   void rktcrypto_sha256_blocks_avx2(uint32_t state[8], const unsigned char *data, intptr_t nblk)
;; Oracle: the portable transform with SHA-NI and AVX2 cleared; gate: asm/tests/test_sha256_x86.c.

.rodata sha256_avx2_k align=64
  .long 0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5
  .long 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5
  .long 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3
  .long 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174
  .long 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc
  .long 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da
  .long 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7
  .long 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967
  .long 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13
  .long 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85
  .long 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3
  .long 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070
  .long 0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5
  .long 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3
  .long 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208
  .long 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
.end
.rodata sha256_avx2_bswap align=16
  .byte 3, 2, 1, 0, 7, 6, 5, 4, 11, 10, 9, 8, 15, 14, 13, 12
.end

;; sigma0(x) = ROTR7 ^ ROTR18 ^ SHR3 ; sigma1(x) = ROTR17 ^ ROTR19 ^ SHR10 (AVX2 has no dword rotate)
.macro SIG0 d, x
  vpsrld \d, \x, 7
  vpslld xmm.c, \x, 25
  vpor \d, \d, xmm.c
  vpsrld xmm.c, \x, 18
  vpslld xmm.e, \x, 14
  vpor xmm.c, xmm.c, xmm.e
  vpxor \d, \d, xmm.c
  vpsrld xmm.c, \x, 3
  vpxor \d, \d, xmm.c
.endm
.macro SIG1 d, x
  vpsrld \d, \x, 17
  vpslld xmm.c, \x, 15
  vpor \d, \d, xmm.c
  vpsrld xmm.c, \x, 19
  vpslld xmm.e, \x, 13
  vpor xmm.c, xmm.c, xmm.e
  vpxor \d, \d, xmm.c
  vpsrld xmm.c, \x, 10
  vpxor \d, \d, xmm.c
.endm

.macro SCHED0 g
  vpalignr xmm.x, xmm.y${((\g) - 3) % 4}, xmm.y${((\g) - 4) % 4}, 4    ; W[t-15..t-12]
  SIG0(xmm.a, xmm.x)
.endm
.macro SCHED1 g
  vpalignr xmm.b, xmm.y${((\g) - 1) % 4}, xmm.y${((\g) - 2) % 4}, 4    ; W[t-7..t-4]
  vpaddd xmm.a, xmm.a, xmm.y${((\g) - 4) % 4}
  vpaddd xmm.a, xmm.a, xmm.b
  SIG1(xmm.b, xmm.y${((\g) - 1) % 4})
.endm
.macro SCHED2 g
  vpsrldq xmm.b, xmm.b, 8                            ; lanes 2,3 -> 0,1; 0 above
  vpaddd xmm.a, xmm.a, xmm.b                         ; lanes 0,1 = W[t], W[t+1]
  SIG1(xmm.b, xmm.a)
.endm
.macro SCHED3 g
  vpslldq xmm.b, xmm.b, 8                            ; lanes 0,1 -> 2,3; 0 below
  vpaddd xmm.y${(\g) % 4}, xmm.a, xmm.b              ; W[t..t+3] into the ring
  vpaddd xmm.b, xmm.y${(\g) % 4}, xmmword ptr [rip + sha256_avx2_k + ${16 * (\g)}]
  vmovdqu xmmword ptr [rsp + ${16 * (\g)}], xmm.b    ; W + K for rounds t..t+3
.endm

.macro ROUND i
  add d.s${(7 + 8 - (\i) % 8) % 8}, dword ptr [rsp + ${4 * (\i)}]              ; h += W[i] + K[i]
  mov d.t0, d.s${(5 + 8 - (\i) % 8) % 8}
  xor d.t0, d.s${(6 + 8 - (\i) % 8) % 8}
  and d.t0, d.s${(4 + 8 - (\i) % 8) % 8}
  xor d.t0, d.s${(6 + 8 - (\i) % 8) % 8}                                     ; Ch(e, f, g)
  add d.s${(7 + 8 - (\i) % 8) % 8}, d.t0
  rorx d.t1, d.s${(4 + 8 - (\i) % 8) % 8}, 6
  rorx d.t2, d.s${(4 + 8 - (\i) % 8) % 8}, 11
  xor d.t1, d.t2
  rorx d.t2, d.s${(4 + 8 - (\i) % 8) % 8}, 25
  xor d.t1, d.t2                                                             ; Sigma1(e)
  add d.s${(7 + 8 - (\i) % 8) % 8}, d.t1                                     ; T1
  add d.s${(3 + 8 - (\i) % 8) % 8}, d.s${(7 + 8 - (\i) % 8) % 8}             ; e' = d + T1
  rorx d.t0, d.s${(0 + 8 - (\i) % 8) % 8}, 2
  rorx d.t1, d.s${(0 + 8 - (\i) % 8) % 8}, 13
  xor d.t0, d.t1
  rorx d.t1, d.s${(0 + 8 - (\i) % 8) % 8}, 22
  xor d.t0, d.t1                                                             ; Sigma0(a)
  mov d.t1, d.s${(0 + 8 - (\i) % 8) % 8}
  and d.t1, d.s${(1 + 8 - (\i) % 8) % 8}                                     ; a & b
  mov d.t2, d.s${(0 + 8 - (\i) % 8) % 8}
  or d.t2, d.s${(1 + 8 - (\i) % 8) % 8}
  and d.t2, d.s${(2 + 8 - (\i) % 8) % 8}                                     ; c & (a | b)
  or d.t2, d.t1                                                              ; Maj(a, b, c)
  add d.t0, d.t2                                                             ; T2
  add d.s${(7 + 8 - (\i) % 8) % 8}, d.t0                                     ; a' = T1 + T2
.endm

.function rktcrypto_sha256_blocks_avx2 export (
  in: q.hw, q.data, q.n
)
  .simd avx2
  .frame 256
  test q.n, q.n
  jz done
  vmovdqa xmm.bswap, xmmword ptr [rip + sha256_avx2_bswap]
.for k, 0, 8
  mov d.s${k}, dword ptr [q.hw + ${4 * k}]
.endfor
blk:
.for g, 0, 4
  vmovdqu xmm.y${g}, xmmword ptr [q.data + ${16 * g}]
  vpshufb xmm.y${g}, xmm.y${g}, xmm.bswap
  vpaddd xmm.a, xmm.y${g}, xmmword ptr [rip + sha256_avx2_k + ${16 * g}]
  vmovdqu xmmword ptr [rsp + ${16 * g}], xmm.a
.endfor
.for i, 0, 64
  .for z, if i < 48 && i % 4 == 0 {0} else {1}, 1
  SCHED0(i / 4 + 4)
  .endfor
  .for z, if i < 48 && i % 4 == 1 {0} else {1}, 1
  SCHED1(i / 4 + 4)
  .endfor
  .for z, if i < 48 && i % 4 == 2 {0} else {1}, 1
  SCHED2(i / 4 + 4)
  .endfor
  .for z, if i < 48 && i % 4 == 3 {0} else {1}, 1
  SCHED3(i / 4 + 4)
  .endfor
  ROUND(i)
.endfor
.for k, 0, 8
  add d.s${k}, dword ptr [q.hw + ${4 * k}]
  mov dword ptr [q.hw + ${4 * k}], d.s${k}
.endfor
  add q.data, 64
  sub q.n, 1
  jnz blk
done:
  ret
.end
