;; SHA-512 block compression on x86-64 with a vectorised message schedule (BMI2 rorx rounds,
;; AVX-512VL ymm schedule). The eight state words stay in registers across all blocks and the
;; 80 rounds are unrolled with the a..h rotation folded into register names. The schedule is
;; computed four words at a time in a ring of four ymm registers (W[t-16..t-1]): sigma0 of
;; W[t-15..t-12] and the W[t-16], W[t-7] terms are one 4-lane step; sigma1 has a dependency
;; distance of two, so it is applied to W[t-2], W[t-1] (lanes 2,3 of the newest group) for
;; W[t], W[t+1] and then to those for W[t+2], W[t+3], each half placed with a zero-filling
;; valignq. W+K for the four rounds is stored to the frame, so a round reads one memory operand.
;; Group g+4 is computed while the rounds of group g run (16 rounds of slack before its first
;; use). Within a round Ch is added before Sigma1 (the e chain is five cycles: Ch two cycles
;; after e, Sigma1 three, two adds, then d + T1) and Sigma0 + Maj are summed into T2 before
;; the a' add (a chain also five). The scalar kernel (sha512_x86.asm) is bound by its twelve
;; rorx/shr per round on the two shift pipes and ~38 ALU ops per round (7.7 cycles per round
;; measured); this form leaves six shift-class and ~23 ALU ops per round.
;;   void rktcrypto_sha512_blocks_avx512_x86(uint64_t hw[24], const unsigned char *data, intptr_t nblk)
;; hw[0..7] = state (updated); hw[8..23] unused (same signature as the scalar kernel).
;; Oracle: the scalar kernel with the AVX-512 bit cleared, and the portable transform with
;; BMI2/ADX cleared; gate: asm/tests/test_sha512_x86.c.

.rodata sha512_avx512_k align=64
  .quad 0x428a2f98d728ae22, 0x7137449123ef65cd, 0xb5c0fbcfec4d3b2f, 0xe9b5dba58189dbbc
  .quad 0x3956c25bf348b538, 0x59f111f1b605d019, 0x923f82a4af194f9b, 0xab1c5ed5da6d8118
  .quad 0xd807aa98a3030242, 0x12835b0145706fbe, 0x243185be4ee4b28c, 0x550c7dc3d5ffb4e2
  .quad 0x72be5d74f27b896f, 0x80deb1fe3b1696b1, 0x9bdc06a725c71235, 0xc19bf174cf692694
  .quad 0xe49b69c19ef14ad2, 0xefbe4786384f25e3, 0x0fc19dc68b8cd5b5, 0x240ca1cc77ac9c65
  .quad 0x2de92c6f592b0275, 0x4a7484aa6ea6e483, 0x5cb0a9dcbd41fbd4, 0x76f988da831153b5
  .quad 0x983e5152ee66dfab, 0xa831c66d2db43210, 0xb00327c898fb213f, 0xbf597fc7beef0ee4
  .quad 0xc6e00bf33da88fc2, 0xd5a79147930aa725, 0x06ca6351e003826f, 0x142929670a0e6e70
  .quad 0x27b70a8546d22ffc, 0x2e1b21385c26c926, 0x4d2c6dfc5ac42aed, 0x53380d139d95b3df
  .quad 0x650a73548baf63de, 0x766a0abb3c77b2a8, 0x81c2c92e47edaee6, 0x92722c851482353b
  .quad 0xa2bfe8a14cf10364, 0xa81a664bbc423001, 0xc24b8b70d0f89791, 0xc76c51a30654be30
  .quad 0xd192e819d6ef5218, 0xd69906245565a910, 0xf40e35855771202a, 0x106aa07032bbd1b8
  .quad 0x19a4c116b8d2d0c8, 0x1e376c085141ab53, 0x2748774cdf8eeb99, 0x34b0bcb5e19b48a8
  .quad 0x391c0cb3c5c95a63, 0x4ed8aa4ae3418acb, 0x5b9cca4f7763e373, 0x682e6ff3d6b2b8a3
  .quad 0x748f82ee5defb2fc, 0x78a5636f43172f60, 0x84c87814a1f0ab72, 0x8cc702081a6439ec
  .quad 0x90befffa23631e28, 0xa4506cebde82bde9, 0xbef9a3f7b2c67915, 0xc67178f2e372532b
  .quad 0xca273eceea26619c, 0xd186b8c721c0c207, 0xeada7dd6cde0eb1e, 0xf57d4f7fee6ed178
  .quad 0x06f067aa72176fba, 0x0a637dc5a2c898a6, 0x113f9804bef90dae, 0x1b710b35131c471b
  .quad 0x28db77f523047d84, 0x32caab7b40c72493, 0x3c9ebe0a15c9bebc, 0x431d67c49c100d4c
  .quad 0x4cc5d4becb3e42b6, 0x597f299cfc657e2a, 0x5fcb6fab3ad6faec, 0x6c44198c4a475817
.end

.rodata sha512_avx512_bswap align=32
  .quad 0x0001020304050607, 0x08090a0b0c0d0e0f, 0x0001020304050607, 0x08090a0b0c0d0e0f
.end

;; Schedule group g (W[4g..4g+3]) from the ring y0..y3, in four slices so the vector work is
;; spread over the four rounds of group g-4. Ring slot (g-4)%4 holds W[4g-16..4g-13] and is
;; overwritten with the new group (its last read is in slice 1).
.macro SCHED0 g
  valignq ymm.x, ymm.y${((\g) - 3) % 4}, ymm.y${((\g) - 4) % 4}, 1   ; W[t-15..t-12]
  vprorq ymm.a, ymm.x, 1
  vprorq ymm.b, ymm.x, 8
  vpsrlq ymm.x, ymm.x, 7
  vpxorq ymm.a, ymm.a, ymm.b
  vpxorq ymm.a, ymm.a, ymm.x                                  ; sigma0(W[t-15..t-12])
  valignq ymm.b, ymm.y${((\g) - 1) % 4}, ymm.y${((\g) - 2) % 4}, 1   ; W[t-7..t-4]
.endm
.macro SCHED1 g
  vpaddq ymm.a, ymm.a, ymm.y${((\g) - 4) % 4}                   ; + W[t-16..t-13]
  vpaddq ymm.a, ymm.a, ymm.b                                  ; + W[t-7..t-4]
  vprorq ymm.b, ymm.y${((\g) - 1) % 4}, 19
  vprorq ymm.x, ymm.y${((\g) - 1) % 4}, 61
  vpsrlq ymm.c, ymm.y${((\g) - 1) % 4}, 6
  vpxorq ymm.b, ymm.b, ymm.x
.endm
.macro SCHED2 g
  vpxorq ymm.b, ymm.b, ymm.c                                  ; sigma1(W[t-4..t-1])
  valignq ymm.b, ymm.zero, ymm.b, 2                           ; lanes 2,3 -> 0,1; 0 above
  vpaddq ymm.a, ymm.a, ymm.b                                  ; lanes 0,1 = W[t], W[t+1]
  vprorq ymm.b, ymm.a, 19
  vprorq ymm.x, ymm.a, 61
  vpsrlq ymm.c, ymm.a, 6
.endm
.macro SCHED3 g
  vpxorq ymm.b, ymm.b, ymm.x
  vpxorq ymm.b, ymm.b, ymm.c                                  ; sigma1(W[t], W[t+1]) in lanes 0,1
  valignq ymm.b, ymm.b, ymm.zero, 2                           ; lanes 0,1 -> 2,3; 0 below
  vpaddq ymm.y${(\g) % 4}, ymm.a, ymm.b                         ; W[t..t+3] into the ring
  vpaddq ymm.b, ymm.y${(\g) % 4}, ymmword ptr [rip + sha512_avx512_k + ${32 * (\g)}]
  vmovdqu64 ymmword ptr [rsp + ${32 * (\g)}], ymm.b             ; W + K for rounds t..t+3
.endm

;; Round i on the rotated state (a..h = s(0-i)..s(7-i) mod 8).
.macro ROUND i
  add q.s${(7 + 8 - (\i) % 8) % 8}, qword ptr [rsp + ${8 * (\i)}]              ; h += W[i] + K[i]
  mov q.t0, q.s${(5 + 8 - (\i) % 8) % 8}
  xor q.t0, q.s${(6 + 8 - (\i) % 8) % 8}
  and q.t0, q.s${(4 + 8 - (\i) % 8) % 8}
  xor q.t0, q.s${(6 + 8 - (\i) % 8) % 8}                                     ; Ch(e, f, g) = ((f ^ g) & e) ^ g
  add q.s${(7 + 8 - (\i) % 8) % 8}, q.t0
  rorx q.t1, q.s${(4 + 8 - (\i) % 8) % 8}, 14
  rorx q.t2, q.s${(4 + 8 - (\i) % 8) % 8}, 18
  xor q.t1, q.t2
  rorx q.t2, q.s${(4 + 8 - (\i) % 8) % 8}, 41
  xor q.t1, q.t2                                                           ; Sigma1(e)
  add q.s${(7 + 8 - (\i) % 8) % 8}, q.t1                                     ; T1
  add q.s${(3 + 8 - (\i) % 8) % 8}, q.s${(7 + 8 - (\i) % 8) % 8}               ; e' = d + T1
  rorx q.t0, q.s${(0 + 8 - (\i) % 8) % 8}, 28
  rorx q.t1, q.s${(0 + 8 - (\i) % 8) % 8}, 34
  xor q.t0, q.t1
  rorx q.t1, q.s${(0 + 8 - (\i) % 8) % 8}, 39
  xor q.t0, q.t1                                                           ; Sigma0(a)
  mov q.t1, q.s${(0 + 8 - (\i) % 8) % 8}
  and q.t1, q.s${(1 + 8 - (\i) % 8) % 8}                                     ; a & b
  mov q.t2, q.s${(0 + 8 - (\i) % 8) % 8}
  or q.t2, q.s${(1 + 8 - (\i) % 8) % 8}
  and q.t2, q.s${(2 + 8 - (\i) % 8) % 8}                                     ; c & (a | b)
  or q.t2, q.t1                                                            ; Maj(a, b, c)
  add q.t0, q.t2                                                           ; T2 = Sigma0 + Maj
  add q.s${(7 + 8 - (\i) % 8) % 8}, q.t0                                     ; a' = T1 + T2
.endm

.function rktcrypto_sha512_blocks_avx512_x86 export (
  in: q.hw, q.data, q.n
)
  .simd avx512
  .frame 640
  test q.n, q.n
  jz done
  vmovdqa64 ymm.bswap, ymmword ptr [rip + sha512_avx512_bswap]
  vpxorq ymm.zero, ymm.zero, ymm.zero
.for k, 0, 8
  mov q.s${k}, qword ptr [q.hw + ${8 * k}]
.endfor
blk:
.for g, 0, 4
  vmovdqu64 ymm.y${g}, ymmword ptr [q.data + ${32 * g}]
  vpshufb ymm.y${g}, ymm.y${g}, ymm.bswap                     ; W[4g..4g+3] big-endian words
  vpaddq ymm.a, ymm.y${g}, ymmword ptr [rip + sha512_avx512_k + ${32 * g}]
  vmovdqu64 ymmword ptr [rsp + ${32 * g}], ymm.a
.endfor
.for i, 0, 80
  .for z, if i < 64 && i % 4 == 0 {0} else {1}, 1
  SCHED0(i / 4 + 4)
  .endfor
  .for z, if i < 64 && i % 4 == 1 {0} else {1}, 1
  SCHED1(i / 4 + 4)
  .endfor
  .for z, if i < 64 && i % 4 == 2 {0} else {1}, 1
  SCHED2(i / 4 + 4)
  .endfor
  .for z, if i < 64 && i % 4 == 3 {0} else {1}, 1
  SCHED3(i / 4 + 4)
  .endfor
  ROUND(i)
.endfor
.for k, 0, 8
  add q.s${k}, qword ptr [q.hw + ${8 * k}]
  mov qword ptr [q.hw + ${8 * k}], q.s${k}
.endfor
  add q.data, 128
  sub q.n, 1
  jnz blk
done:
  ret
.end
