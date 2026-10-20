;; Keccak-f[1600] on AVX-512 (x86-64 SysV): the five planes of the state live in five
;; 512-bit registers (lane x of plane y = s[x + 5y], lanes 5..7 unused), so theta is two
;; three-input XORs plus two lane rotations, rho one vprolvq per plane, pi gathers each
;; output plane from the five input planes with masked vpermq (the index vector of output
;; plane Y' is the lane rotation by 3Y' mod 5), chi two lane rotations and a vpternlogq
;; (0xd2 = a ^ (~b & c)) per plane, iota a masked broadcast XOR. Two rounds per loop
;; iteration alternate the two register sets, so pi never needs plane copies.
;;   void keccak_f1600_x86(uint64_t s[25])
;; Oracle: keccak_f_portable (rktcrypto_sha3.c); gate: asm/tests/test_keccak_x86.c.

.rodata keccak_x86_rc align=64
  .quad 0x0000000000000001, 0x0000000000008082, 0x800000000000808a, 0x8000000080008000
  .quad 0x000000000000808b, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009
  .quad 0x000000000000008a, 0x0000000000000088, 0x0000000080008009, 0x000000008000000a
  .quad 0x000000008000808b, 0x800000000000008b, 0x8000000000008089, 0x8000000000008003
  .quad 0x8000000000008002, 0x8000000000000080, 0x000000000000800a, 0x800000008000000a
  .quad 0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008
.end
.rodata keccak_x86_idx align=64                 ; lane rotations: vector k = [3k mod 5 ...]
  .quad 0, 1, 2, 3, 4, 0, 0, 0                  ; pi0: identity
  .quad 3, 4, 0, 1, 2, 0, 0, 0                  ; pi1: lane x <- x+3
  .quad 1, 2, 3, 4, 0, 0, 0, 0                  ; pi2: lane x <- x+1 (theta C[x+1], chi b)
  .quad 4, 0, 1, 2, 3, 0, 0, 0                  ; pi3: lane x <- x-1 (theta C[x-1])
  .quad 2, 3, 4, 0, 1, 0, 0, 0                  ; pi4: lane x <- x+2 (chi c)
.end
.rodata keccak_x86_rho align=64                 ; rotation offsets, plane y lane x
  .quad 0, 1, 62, 28, 27, 0, 0, 0
  .quad 36, 44, 6, 55, 20, 0, 0, 0
  .quad 3, 10, 43, 25, 39, 0, 0, 0
  .quad 41, 45, 15, 21, 8, 0, 0, 0
  .quad 18, 2, 61, 56, 14, 0, 0, 0
.end

.function keccak_f1600_x86 export (
  in: q.s
)
  .simd avx512
  mov d.t, 0x1f
  kmovw k.m5, d.t
.for y, 0, 5
  mov d.t, ${1 << y}
  kmovw k.m${y}, d.t
.endfor
.for i, 0, 5
  vmovdqa64 zmm.pi${i}, zmmword ptr [rip + keccak_x86_idx + ${64 * i}]
.endfor
.for y, 0, 5
  vmovdqu64 zmm.s${y}{k.m5}{z}, zmmword ptr [q.s + ${40 * y}]
.endfor
  lea q.rc, [rip + keccak_x86_rc]
  mov d.n, 12
round2:
.for h, 0, 2
  ;; theta: C = XOR of the five planes; D[x] = C[x-1] ^ rol(C[x+1], 1); planes ^= D
  vmovdqa64 zmm.c, zmm.s${5 * h}
  vpternlogq zmm.c, zmm.s${5 * h + 1}, zmm.s${5 * h + 2}, 0x96
  vpternlogq zmm.c, zmm.s${5 * h + 3}, zmm.s${5 * h + 4}, 0x96
  vpermq zmm.d, zmm.pi3, zmm.c
  vpermq zmm.t1, zmm.pi2, zmm.c
  vprolq zmm.t1, zmm.t1, 1
  vpxorq zmm.d, zmm.d, zmm.t1
  .for y, 0, 5
  vpxorq zmm.s${5 * h + y}, zmm.s${5 * h + y}, zmm.d
  .endfor
  ;; rho
  .for y, 0, 5
  vprolvq zmm.s${5 * h + y}, zmm.s${5 * h + y}, zmmword ptr [rip + keccak_x86_rho + ${64 * y}]
  .endfor
  ;; pi into the other register set: output plane yo, lane y <- input plane y, lane 3(yo-3y) mod 5
  .for yo, 0, 5
    .for y, 0, 5
  vpermq zmm.s${5 * (1 - h) + yo}{k.m${y}}, zmm.pi${yo}, zmm.s${5 * h + y}
    .endfor
  .endfor
  ;; chi: a ^= ~b & c with b = lane x+1, c = lane x+2
  .for yo, 0, 5
  vpermq zmm.t1, zmm.pi2, zmm.s${5 * (1 - h) + yo}
  vpermq zmm.t2, zmm.pi4, zmm.s${5 * (1 - h) + yo}
  vpternlogq zmm.s${5 * (1 - h) + yo}, zmm.t1, zmm.t2, 0xd2
  .endfor
  ;; iota
  vpxorq zmm.s${5 * (1 - h)}{k.m0}, zmm.s${5 * (1 - h)}, qword ptr [q.rc + ${8 * h}]{1to8}
.endfor
  add q.rc, 16
  sub d.n, 1
  jnz round2
.for y, 0, 5
  vmovdqu64 zmmword ptr [q.s + ${40 * y}]{k.m5}, zmm.s${y}
.endfor
  ret
.end
