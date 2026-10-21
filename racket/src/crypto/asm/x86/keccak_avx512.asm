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
.rodata keccak_x86_pi align=64                  ; vpermi2q indices: 0-7 first table, 8-15 second
  .quad 0, 9, 0, 0, 0, 0, 0, 0          ; +0 pi0: planes 0,1
  .quad 0, 0, 2, 11, 0, 0, 0, 0          ; +64 pi0: planes 2,3
  .quad 0, 1, 2, 3, 12, 0, 0, 0          ; +128 pi0: plane 4 onto the merged four
  .quad 3, 12, 0, 0, 0, 0, 0, 0          ; +192 pi1: planes 0,1
  .quad 0, 0, 0, 9, 0, 0, 0, 0          ; +256 pi1: planes 2,3
  .quad 0, 1, 2, 3, 10, 0, 0, 0          ; +320 pi1: plane 4 onto the merged four
  .quad 1, 10, 0, 0, 0, 0, 0, 0          ; +384 pi2: planes 0,1
  .quad 0, 0, 3, 12, 0, 0, 0, 0          ; +448 pi2: planes 2,3
  .quad 0, 1, 2, 3, 8, 0, 0, 0          ; +512 pi2: plane 4 onto the merged four
  .quad 4, 8, 0, 0, 0, 0, 0, 0          ; +576 pi3: planes 0,1
  .quad 0, 0, 1, 10, 0, 0, 0, 0          ; +640 pi3: planes 2,3
  .quad 0, 1, 2, 3, 11, 0, 0, 0          ; +704 pi3: plane 4 onto the merged four
  .quad 2, 11, 0, 0, 0, 0, 0, 0          ; +768 pi4: planes 0,1
  .quad 0, 0, 4, 8, 0, 0, 0, 0          ; +832 pi4: planes 2,3
  .quad 0, 1, 2, 3, 9, 0, 0, 0          ; +896 pi4: plane 4 onto the merged four
  .quad 0, 1, 10, 11, 0, 0, 0, 0           ; +960 merge of the two pairs
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
  mov d.t, 1
  kmovw k.m0, d.t
  vmovdqa64 zmm.pi2, zmmword ptr [rip + keccak_x86_idx + 128]
  vmovdqa64 zmm.pi3, zmmword ptr [rip + keccak_x86_idx + 192]
  vmovdqa64 zmm.pi4, zmmword ptr [rip + keccak_x86_idx + 256]
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
  ;; pi into the other register set: output plane yo, lane y <- input plane y, lane 3(yo-3y) mod 5,
  ;; as a merge tree of two-table permutes (planes 0,1 | planes 2,3 | both | plane 4)
  .for yo, 0, 5
  vmovdqa64 zmm.ta, zmmword ptr [rip + keccak_x86_pi + ${192 * yo}]
  vpermi2q zmm.ta, zmm.s${5 * h}, zmm.s${5 * h + 1}
  vmovdqa64 zmm.tb, zmmword ptr [rip + keccak_x86_pi + ${192 * yo + 64}]
  vpermi2q zmm.tb, zmm.s${5 * h + 2}, zmm.s${5 * h + 3}
  vmovdqa64 zmm.tm, zmmword ptr [rip + keccak_x86_pi + 960]
  vpermi2q zmm.tm, zmm.ta, zmm.tb
  vmovdqa64 zmm.s${5 * (1 - h) + yo}, zmmword ptr [rip + keccak_x86_pi + ${192 * yo + 128}]
  vpermi2q zmm.s${5 * (1 - h) + yo}, zmm.tm, zmm.s${5 * h + 4}
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

;; ---- two independent states, interleaved (ML-KEM / ML-DSA samplers run XOF pairs) --------
;; The single-state round twice over, state A in s0..s9 and state B in s10..s19 (each with its
;; two register sets), the index vectors shared; the two dependency chains overlap in the
;; out-of-order window. 31 vector registers: .simd avx512.
;;   void keccak_f1600_x2_x86(uint64_t sA[25], uint64_t sB[25])
.function keccak_f1600_x2_x86 export (
  in: q.sa, q.sb
)
  .simd avx512
  mov d.t, 0x1f
  kmovw k.m5, d.t
  mov d.t, 1
  kmovw k.m0, d.t
  vmovdqa64 zmm.pi2, zmmword ptr [rip + keccak_x86_idx + 128]
  vmovdqa64 zmm.pi3, zmmword ptr [rip + keccak_x86_idx + 192]
  vmovdqa64 zmm.pi4, zmmword ptr [rip + keccak_x86_idx + 256]
.for y, 0, 5
  vmovdqu64 zmm.s${y}{k.m5}{z}, zmmword ptr [q.sa + ${40 * y}]
  vmovdqu64 zmm.s${10 + y}{k.m5}{z}, zmmword ptr [q.sb + ${40 * y}]
.endfor
  lea q.rc, [rip + keccak_x86_rc]
  mov d.n, 12
round2x:
.for h, 0, 2
  ;; theta, both states
  .for st, 0, 2
  vmovdqa64 zmm.c${st}, zmm.s${10 * st + 5 * h}
  vpternlogq zmm.c${st}, zmm.s${10 * st + 5 * h + 1}, zmm.s${10 * st + 5 * h + 2}, 0x96
  vpternlogq zmm.c${st}, zmm.s${10 * st + 5 * h + 3}, zmm.s${10 * st + 5 * h + 4}, 0x96
  vpermq zmm.d${st}, zmm.pi3, zmm.c${st}
  vpermq zmm.t${st}, zmm.pi2, zmm.c${st}
  vprolq zmm.t${st}, zmm.t${st}, 1
  vpxorq zmm.d${st}, zmm.d${st}, zmm.t${st}
  .endfor
  .for y, 0, 5
    .for st, 0, 2
  vpxorq zmm.s${10 * st + 5 * h + y}, zmm.s${10 * st + 5 * h + y}, zmm.d${st}
    .endfor
  .endfor
  ;; rho
  .for y, 0, 5
    .for st, 0, 2
  vprolvq zmm.s${10 * st + 5 * h + y}, zmm.s${10 * st + 5 * h + y}, zmmword ptr [rip + keccak_x86_rho + ${64 * y}]
    .endfor
  .endfor
  ;; pi (merge tree) into the other register set of each state
  .for yo, 0, 5
    .for st, 0, 2
  vmovdqa64 zmm.ta${st}, zmmword ptr [rip + keccak_x86_pi + ${192 * yo}]
  vpermi2q zmm.ta${st}, zmm.s${10 * st + 5 * h}, zmm.s${10 * st + 5 * h + 1}
  vmovdqa64 zmm.tb${st}, zmmword ptr [rip + keccak_x86_pi + ${192 * yo + 64}]
  vpermi2q zmm.tb${st}, zmm.s${10 * st + 5 * h + 2}, zmm.s${10 * st + 5 * h + 3}
  vmovdqa64 zmm.tm${st}, zmmword ptr [rip + keccak_x86_pi + 960]
  vpermi2q zmm.tm${st}, zmm.ta${st}, zmm.tb${st}
  vmovdqa64 zmm.s${10 * st + 5 * (1 - h) + yo}, zmmword ptr [rip + keccak_x86_pi + ${192 * yo + 128}]
  vpermi2q zmm.s${10 * st + 5 * (1 - h) + yo}, zmm.tm${st}, zmm.s${10 * st + 5 * h + 4}
    .endfor
  .endfor
  ;; chi
  .for yo, 0, 5
    .for st, 0, 2
  vpermq zmm.ta${st}, zmm.pi2, zmm.s${10 * st + 5 * (1 - h) + yo}
  vpermq zmm.tb${st}, zmm.pi4, zmm.s${10 * st + 5 * (1 - h) + yo}
  vpternlogq zmm.s${10 * st + 5 * (1 - h) + yo}, zmm.ta${st}, zmm.tb${st}, 0xd2
    .endfor
  .endfor
  ;; iota
  .for st, 0, 2
  vpxorq zmm.s${10 * st + 5 * (1 - h)}{k.m0}, zmm.s${10 * st + 5 * (1 - h)}, qword ptr [q.rc + ${8 * h}]{1to8}
  .endfor
.endfor
  add q.rc, 16
  sub d.n, 1
  jnz round2x
.for y, 0, 5
  vmovdqu64 zmmword ptr [q.sa + ${40 * y}]{k.m5}, zmm.s${y}
  vmovdqu64 zmmword ptr [q.sb + ${40 * y}]{k.m5}, zmm.s${10 + y}
.endfor
  ret
.end
