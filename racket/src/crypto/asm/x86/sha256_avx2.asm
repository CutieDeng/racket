;; SHA-256 block compression on x86-64 for CPUs without SHA-NI: scalar rounds on BMI2 rorx
;; (the a..h rotation folded into register names, Ch added before Sigma1, Sigma0 + Maj summed
;; before the a' add: five-cycle e and a chains; Maj as ((a ^ b) & (b ^ c)) ^ b with a ^ b carried
;; into the next round as its b ^ c in alternating registers: 25 instructions a round) with the message schedule of TWO consecutive blocks in the
;; two 128-bit lanes of ymm registers (every schedule op is lane-local), four words per step in a
;; ring of four: sigma0 of W[t-15..t-12] and the W[t-16], W[t-7] terms as one four-lane step
;; (vpalignr windows, rotates as shift pairs), sigma1 (dependency distance two) applied to lanes
;; 2,3 of the newest group and then to the two words that produces, each half placed with a byte
;; shift that zero-fills. W + K of both blocks goes to a 512-byte frame (group g at 32 g: the
;; first block's four words, then the second's); group g+4 is computed in four slices during the
;; rounds of the first block's group g, the second block's rounds then read the frame with no
;; schedule work: half the vector work per block. An odd last block duplicates itself in the
;; second lane and skips the second block's rounds.
;;   void rktcrypto_sha256_blocks_avx2(uint32_t state[8], const unsigned char *data, intptr_t nblk)
;; Oracle: the portable transform with SHA-NI and AVX2 cleared; gate: asm/tests/test_sha256_x86.c.

.rodata sha256_avx2_k2 align=64
  .long 0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5
  .long 0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5
  .long 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5
  .long 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5
  .long 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3
  .long 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3
  .long 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174
  .long 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174
  .long 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc
  .long 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc
  .long 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da
  .long 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da
  .long 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7
  .long 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7
  .long 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967
  .long 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967
  .long 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13
  .long 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13
  .long 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85
  .long 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85
  .long 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3
  .long 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3
  .long 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070
  .long 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070
  .long 0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5
  .long 0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5
  .long 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3
  .long 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3
  .long 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208
  .long 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208
  .long 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
  .long 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
.end
.rodata sha256_avx2_bswap align=16
  .byte 3, 2, 1, 0, 7, 6, 5, 4, 11, 10, 9, 8, 15, 14, 13, 12
.end

;; sigma0(x) = ROTR7 ^ ROTR18 ^ SHR3 ; sigma1(x) = ROTR17 ^ ROTR19 ^ SHR10 (AVX2 has no dword rotate)
.macro SIG0 d, x
  vpsrld \d, \x, 7
  vpslld ymm.c, \x, 25
  vpor \d, \d, ymm.c
  vpsrld ymm.c, \x, 18
  vpslld ymm.e, \x, 14
  vpor ymm.c, ymm.c, ymm.e
  vpxor \d, \d, ymm.c
  vpsrld ymm.c, \x, 3
  vpxor \d, \d, ymm.c
.endm
.macro SIG1 d, x
  vpsrld \d, \x, 17
  vpslld ymm.c, \x, 15
  vpor \d, \d, ymm.c
  vpsrld ymm.c, \x, 19
  vpslld ymm.e, \x, 13
  vpor ymm.c, ymm.c, ymm.e
  vpxor \d, \d, ymm.c
  vpsrld ymm.c, \x, 10
  vpxor \d, \d, ymm.c
.endm

.macro SCHED0 g
  vpalignr ymm.x, ymm.y${((\g) - 3) % 4}, ymm.y${((\g) - 4) % 4}, 4    ; W[t-15..t-12]
  SIG0(ymm.a, ymm.x)
.endm
.macro SCHED1 g
  vpalignr ymm.b, ymm.y${((\g) - 1) % 4}, ymm.y${((\g) - 2) % 4}, 4    ; W[t-7..t-4]
  vpaddd ymm.a, ymm.a, ymm.y${((\g) - 4) % 4}
  vpaddd ymm.a, ymm.a, ymm.b
  SIG1(ymm.b, ymm.y${((\g) - 1) % 4})
.endm
.macro SCHED2 g
  vpsrldq ymm.b, ymm.b, 8                            ; lanes 2,3 -> 0,1; 0 above
  vpaddd ymm.a, ymm.a, ymm.b                         ; lanes 0,1 = W[t], W[t+1]
  SIG1(ymm.b, ymm.a)
.endm
.macro SCHED3 g
  vpslldq ymm.b, ymm.b, 8                            ; lanes 0,1 -> 2,3; 0 below
  vpaddd ymm.y${(\g) % 4}, ymm.a, ymm.b              ; W[t..t+3] into the ring
  vpaddd ymm.b, ymm.y${(\g) % 4}, ymmword ptr [rip + sha256_avx2_k2 + ${32 * (\g)}]
  vmovdqu ymmword ptr [rsp + ${32 * (\g)}], ymm.b    ; W + K for rounds t..t+3 of both blocks
.endm

.macro ROUND i, off
  add d.s${(7 + 8 - (\i) % 8) % 8}, dword ptr [rsp + ${32 * ((\i) / 4) + 4 * ((\i) % 4) + (\off)}]   ; h += W[i] + K[i]
  mov d.t0, d.s${(5 + 8 - (\i) % 8) % 8}
  xor d.t0, d.s${(6 + 8 - (\i) % 8) % 8}
  and d.t0, d.s${(4 + 8 - (\i) % 8) % 8}
  xor d.t0, d.s${(6 + 8 - (\i) % 8) % 8}                                     ; Ch(e, f, g)
  add d.s${(7 + 8 - (\i) % 8) % 8}, d.t0
  rorx d.t2, d.s${(4 + 8 - (\i) % 8) % 8}, 6
  rorx d.t0, d.s${(4 + 8 - (\i) % 8) % 8}, 11
  xor d.t2, d.t0
  rorx d.t0, d.s${(4 + 8 - (\i) % 8) % 8}, 25
  xor d.t2, d.t0                                                             ; Sigma1(e)
  add d.s${(7 + 8 - (\i) % 8) % 8}, d.t2                                                              ; T1
  add d.s${(3 + 8 - (\i) % 8) % 8}, d.s${(7 + 8 - (\i) % 8) % 8}                                                               ; e' = d + T1
  rorx d.t0, d.s${(0 + 8 - (\i) % 8) % 8}, 2
  rorx d.t2, d.s${(0 + 8 - (\i) % 8) % 8}, 13
  xor d.t0, d.t2
  rorx d.t2, d.s${(0 + 8 - (\i) % 8) % 8}, 22
  xor d.t0, d.t2                                                             ; Sigma0(a)
  mov d.t${if (\i) % 2 == 0 {1} else {3}}, d.s${(0 + 8 - (\i) % 8) % 8}
  xor d.t${if (\i) % 2 == 0 {1} else {3}}, d.s${(1 + 8 - (\i) % 8) % 8}                                                             ; a ^ b (next round's b ^ c)
  and d.t${if (\i) % 2 == 0 {3} else {1}}, d.t${if (\i) % 2 == 0 {1} else {3}}                                                           ; (b ^ c) & (a ^ b)
  xor d.t${if (\i) % 2 == 0 {3} else {1}}, d.s${(1 + 8 - (\i) % 8) % 8}                                                             ; Maj(a, b, c)
  add d.t0, d.t${if (\i) % 2 == 0 {3} else {1}}                                                            ; T2
  add d.s${(7 + 8 - (\i) % 8) % 8}, d.t0                                                              ; a' = T1 + T2
.endm

.function rktcrypto_sha256_blocks_avx2 export (
  in: q.hw, q.data, q.n
)
  .simd avx2
  .frame 512
  test q.n, q.n
  jz done
  vbroadcasti128 ymm.bswap, xmmword ptr [rip + sha256_avx2_bswap]
.for k, 0, 8
  mov d.s${k}, dword ptr [q.hw + ${4 * k}]
.endfor
pair:
  ;; the second lane's block: the next one, or this one again when it is the last
  mov q.t0, q.data
  cmp q.n, 1
  je one
  add q.t0, 64
one:
.for g, 0, 4
  vmovdqu xmm.y${g}, xmmword ptr [q.data + ${16 * g}]
  vinserti128 ymm.y${g}, ymm.y${g}, xmmword ptr [q.t0 + ${16 * g}], 1
  vpshufb ymm.y${g}, ymm.y${g}, ymm.bswap
  vpaddd ymm.a, ymm.y${g}, ymmword ptr [rip + sha256_avx2_k2 + ${32 * g}]
  vmovdqu ymmword ptr [rsp + ${32 * g}], ymm.a
.endfor
  mov d.t3, d.s1
  xor d.t3, d.s2                                                             ; b ^ c for round 0's Maj
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
  ROUND(i, 0)
.endfor
.for k, 0, 8
  add d.s${k}, dword ptr [q.hw + ${4 * k}]
  mov dword ptr [q.hw + ${4 * k}], d.s${k}
.endfor
  sub q.n, 1
  jz done
  ;; the second block: its W + K already sit in the frame's upper lanes
  mov d.t3, d.s1
  xor d.t3, d.s2
.for i, 0, 64
  ROUND(i, 16)
.endfor
.for k, 0, 8
  add d.s${k}, dword ptr [q.hw + ${4 * k}]
  mov dword ptr [q.hw + ${4 * k}], d.s${k}
.endfor
  add q.data, 128
  sub q.n, 1
  jnz pair
done:
  ret
.end
