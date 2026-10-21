;; SHA-512 block compression on x86-64 (scalar, BMI2 rorx): the eight state words stay in
;; registers across all blocks, the 80 rounds are unrolled with the a..h rotation folded into
;; register names, the sixteen-word message schedule lives in a ring in the caller's scratch
;; area (hw[8..23]) because the DSL has no stack frames yet. Within a round Ch is added before
;; Sigma1 so the e chain is five cycles (Ch is ready two cycles after e, Sigma1 three).
;; This form is bound by its twelve rorx/shr per round on the shift pipes plus ~38 ALU ops
;; (7.7 cycles per round on Zen 5); sha512_avx512.asm moves the schedule to AVX-512VL ymm
;; (four words per step) and is dispatched first when AVX-512 is available. This kernel stays
;; as the BMI2-only fallback (an earlier two-lane xmm schedule attempt gained only 3%).
;;   void rktcrypto_sha512_blocks_x86(uint64_t hw[24], const unsigned char *data, intptr_t nblk)
;; hw[0..7] = state (updated). Oracle: sha512_transform_portable (rktcrypto_sha512.c) through the
;; core API with the BMI2/ADX bit cleared; gate: asm/tests/test_sha512_x86.c.

.rodata sha512_x86_k align=64
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

.function rktcrypto_sha512_blocks_x86 export (
  in: q.hw, q.data, q.n
)
  test q.n, q.n
  jz done
.for k, 0, 8
  mov q.s${k}, qword ptr [q.hw + ${8 * k}]
.endfor
blk:
.for i, 0, 80
  .for z, if i < 16 {0} else {1}, 1
  mov q.t1, qword ptr [q.data + ${8 * i}]
  bswap q.t1
  mov qword ptr [q.hw + ${64 + 8 * i}], q.t1
  .endfor
  .for z, if i < 16 {1} else {0}, 1
  mov q.t0, qword ptr [q.hw + ${64 + 8 * ((i - 2) % 16)}]
  rorx q.t1, q.t0, 19
  rorx q.t2, q.t0, 61
  xor q.t1, q.t2
  shr q.t0, 6
  xor q.t1, q.t0                               ; sigma1(W[i-2])
  mov q.t0, qword ptr [q.hw + ${64 + 8 * ((i - 15) % 16)}]
  rorx q.t2, q.t0, 1
  shr q.t0, 7
  xor q.t2, q.t0
  mov q.t0, qword ptr [q.hw + ${64 + 8 * ((i - 15) % 16)}]
  rorx q.t0, q.t0, 8
  xor q.t2, q.t0                               ; sigma0(W[i-15])
  add q.t1, q.t2
  add q.t1, qword ptr [q.hw + ${64 + 8 * ((i - 7) % 16)}]
  add q.t1, qword ptr [q.hw + ${64 + 8 * (i % 16)}]
  mov qword ptr [q.hw + ${64 + 8 * (i % 16)}], q.t1
  .endfor
  add q.s${(7 + 8 - i % 8) % 8}, q.t1                                ; h += W[i]   (off the e chain)
  add q.s${(7 + 8 - i % 8) % 8}, qword ptr [rip + sha512_x86_k + ${8 * i}]
  mov q.t0, q.s${(6 + 8 - i % 8) % 8}
  xor q.t0, q.s${(5 + 8 - i % 8) % 8}
  and q.t0, q.s${(4 + 8 - i % 8) % 8}
  xor q.t0, q.s${(6 + 8 - i % 8) % 8}                                ; Ch(e, f, g): ready two cycles after e
  add q.s${(7 + 8 - i % 8) % 8}, q.t0
  rorx q.t1, q.s${(4 + 8 - i % 8) % 8}, 14
  rorx q.t2, q.s${(4 + 8 - i % 8) % 8}, 18
  xor q.t1, q.t2
  rorx q.t2, q.s${(4 + 8 - i % 8) % 8}, 41
  xor q.t1, q.t2                               ; Sigma1(e): ready three cycles after e
  add q.s${(7 + 8 - i % 8) % 8}, q.t1                                ; h = T1 (e + 4)
  add q.s${(3 + 8 - i % 8) % 8}, q.s${(7 + 8 - i % 8) % 8}                                 ; e' = d + T1 (e + 5)
  rorx q.t0, q.s${(0 + 8 - i % 8) % 8}, 28
  rorx q.t1, q.s${(0 + 8 - i % 8) % 8}, 34
  xor q.t0, q.t1
  rorx q.t1, q.s${(0 + 8 - i % 8) % 8}, 39
  xor q.t0, q.t1
  add q.s${(7 + 8 - i % 8) % 8}, q.t0                                ; T1 + Sigma0(a)
  mov q.t0, q.s${(0 + 8 - i % 8) % 8}
  and q.t0, q.s${(1 + 8 - i % 8) % 8}
  mov q.t1, q.s${(0 + 8 - i % 8) % 8}
  or q.t1, q.s${(1 + 8 - i % 8) % 8}
  and q.t1, q.s${(2 + 8 - i % 8) % 8}
  or q.t1, q.t0                                ; Maj(a, b, c)
  add q.s${(7 + 8 - i % 8) % 8}, q.t1                                ; a' = T1 + T2
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
