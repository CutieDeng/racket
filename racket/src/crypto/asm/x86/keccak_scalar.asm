;; Keccak-f[1600] scalar (x86-64 SysV): lanes stay in memory (the caller's state and a frame
;; buffer, alternated each round), theta's column parities are accumulated in the frame while
;; chi writes the output row, D[x] = C[x-1] ^ rol(C[x+1], 1) is formed in five registers at the
;; start of a round, each output row gathers its five lanes (load, xor D, rol by the rho offset)
;; and chi is andn + xor per lane. Two rounds per loop iteration; the 512-bit AVX-512 version
;; is bound by shuffle throughput (32 per round), this one by plain ALU work with high ILP.
;;   void keccak_f1600_scalar_x86(uint64_t s[25])
;; Oracle: keccak_f_portable; gate: asm/tests/test_keccak_x86.c (same harness as the AVX-512 kernel).

.rodata keccak_scalar_rc align=64
  .quad 0x0000000000000001, 0x0000000000008082, 0x800000000000808a, 0x8000000080008000
  .quad 0x000000000000808b, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009
  .quad 0x000000000000008a, 0x0000000000000088, 0x0000000080008009, 0x000000008000000a
  .quad 0x000000008000808b, 0x800000000000008b, 0x8000000000008089, 0x8000000000008003
  .quad 0x8000000000008002, 0x8000000000000080, 0x000000000000800a, 0x800000008000000a
  .quad 0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008
.end

;; one round: \src -> \dst (base expressions), round constant at [q.rc + \rcoff]
.macro KECCAK_ROUND src, dst, rcoff
  ;; theta: D[x] = C[x-1] ^ rol(C[x+1], 1), C in the frame at 200
  mov q.d0, qword ptr [rsp + 208]
  rol q.d0, 1
  xor q.d0, qword ptr [rsp + 232]
  mov q.d1, qword ptr [rsp + 216]
  rol q.d1, 1
  xor q.d1, qword ptr [rsp + 200]
  mov q.d2, qword ptr [rsp + 224]
  rol q.d2, 1
  xor q.d2, qword ptr [rsp + 208]
  mov q.d3, qword ptr [rsp + 232]
  rol q.d3, 1
  xor q.d3, qword ptr [rsp + 216]
  mov q.d4, qword ptr [rsp + 200]
  rol q.d4, 1
  xor q.d4, qword ptr [rsp + 224]
  ;; output row 0
  mov q.b0, qword ptr [\src + 0]
  xor q.b0, q.d0
  mov q.b1, qword ptr [\src + 48]
  xor q.b1, q.d1
  rol q.b1, 44
  mov q.b2, qword ptr [\src + 96]
  xor q.b2, q.d2
  rol q.b2, 43
  mov q.b3, qword ptr [\src + 144]
  xor q.b3, q.d3
  rol q.b3, 21
  mov q.b4, qword ptr [\src + 192]
  xor q.b4, q.d4
  rol q.b4, 14
  andn q.t, q.b1, q.b2
  xor q.t, q.b0
  xor q.t, qword ptr [q.rc + \rcoff]
  mov qword ptr [\dst + 0], q.t
  mov qword ptr [rsp + 200], q.t
  andn q.t, q.b2, q.b3
  xor q.t, q.b1
  mov qword ptr [\dst + 8], q.t
  mov qword ptr [rsp + 208], q.t
  andn q.t, q.b3, q.b4
  xor q.t, q.b2
  mov qword ptr [\dst + 16], q.t
  mov qword ptr [rsp + 216], q.t
  andn q.t, q.b4, q.b0
  xor q.t, q.b3
  mov qword ptr [\dst + 24], q.t
  mov qword ptr [rsp + 224], q.t
  andn q.t, q.b0, q.b1
  xor q.t, q.b4
  mov qword ptr [\dst + 32], q.t
  mov qword ptr [rsp + 232], q.t
  ;; output row 1
  mov q.b0, qword ptr [\src + 24]
  xor q.b0, q.d3
  rol q.b0, 28
  mov q.b1, qword ptr [\src + 72]
  xor q.b1, q.d4
  rol q.b1, 20
  mov q.b2, qword ptr [\src + 80]
  xor q.b2, q.d0
  rol q.b2, 3
  mov q.b3, qword ptr [\src + 128]
  xor q.b3, q.d1
  rol q.b3, 45
  mov q.b4, qword ptr [\src + 176]
  xor q.b4, q.d2
  rol q.b4, 61
  andn q.t, q.b1, q.b2
  xor q.t, q.b0
  mov qword ptr [\dst + 40], q.t
  xor qword ptr [rsp + 200], q.t
  andn q.t, q.b2, q.b3
  xor q.t, q.b1
  mov qword ptr [\dst + 48], q.t
  xor qword ptr [rsp + 208], q.t
  andn q.t, q.b3, q.b4
  xor q.t, q.b2
  mov qword ptr [\dst + 56], q.t
  xor qword ptr [rsp + 216], q.t
  andn q.t, q.b4, q.b0
  xor q.t, q.b3
  mov qword ptr [\dst + 64], q.t
  xor qword ptr [rsp + 224], q.t
  andn q.t, q.b0, q.b1
  xor q.t, q.b4
  mov qword ptr [\dst + 72], q.t
  xor qword ptr [rsp + 232], q.t
  ;; output row 2
  mov q.b0, qword ptr [\src + 8]
  xor q.b0, q.d1
  rol q.b0, 1
  mov q.b1, qword ptr [\src + 56]
  xor q.b1, q.d2
  rol q.b1, 6
  mov q.b2, qword ptr [\src + 104]
  xor q.b2, q.d3
  rol q.b2, 25
  mov q.b3, qword ptr [\src + 152]
  xor q.b3, q.d4
  rol q.b3, 8
  mov q.b4, qword ptr [\src + 160]
  xor q.b4, q.d0
  rol q.b4, 18
  andn q.t, q.b1, q.b2
  xor q.t, q.b0
  mov qword ptr [\dst + 80], q.t
  xor qword ptr [rsp + 200], q.t
  andn q.t, q.b2, q.b3
  xor q.t, q.b1
  mov qword ptr [\dst + 88], q.t
  xor qword ptr [rsp + 208], q.t
  andn q.t, q.b3, q.b4
  xor q.t, q.b2
  mov qword ptr [\dst + 96], q.t
  xor qword ptr [rsp + 216], q.t
  andn q.t, q.b4, q.b0
  xor q.t, q.b3
  mov qword ptr [\dst + 104], q.t
  xor qword ptr [rsp + 224], q.t
  andn q.t, q.b0, q.b1
  xor q.t, q.b4
  mov qword ptr [\dst + 112], q.t
  xor qword ptr [rsp + 232], q.t
  ;; output row 3
  mov q.b0, qword ptr [\src + 32]
  xor q.b0, q.d4
  rol q.b0, 27
  mov q.b1, qword ptr [\src + 40]
  xor q.b1, q.d0
  rol q.b1, 36
  mov q.b2, qword ptr [\src + 88]
  xor q.b2, q.d1
  rol q.b2, 10
  mov q.b3, qword ptr [\src + 136]
  xor q.b3, q.d2
  rol q.b3, 15
  mov q.b4, qword ptr [\src + 184]
  xor q.b4, q.d3
  rol q.b4, 56
  andn q.t, q.b1, q.b2
  xor q.t, q.b0
  mov qword ptr [\dst + 120], q.t
  xor qword ptr [rsp + 200], q.t
  andn q.t, q.b2, q.b3
  xor q.t, q.b1
  mov qword ptr [\dst + 128], q.t
  xor qword ptr [rsp + 208], q.t
  andn q.t, q.b3, q.b4
  xor q.t, q.b2
  mov qword ptr [\dst + 136], q.t
  xor qword ptr [rsp + 216], q.t
  andn q.t, q.b4, q.b0
  xor q.t, q.b3
  mov qword ptr [\dst + 144], q.t
  xor qword ptr [rsp + 224], q.t
  andn q.t, q.b0, q.b1
  xor q.t, q.b4
  mov qword ptr [\dst + 152], q.t
  xor qword ptr [rsp + 232], q.t
  ;; output row 4
  mov q.b0, qword ptr [\src + 16]
  xor q.b0, q.d2
  rol q.b0, 62
  mov q.b1, qword ptr [\src + 64]
  xor q.b1, q.d3
  rol q.b1, 55
  mov q.b2, qword ptr [\src + 112]
  xor q.b2, q.d4
  rol q.b2, 39
  mov q.b3, qword ptr [\src + 120]
  xor q.b3, q.d0
  rol q.b3, 41
  mov q.b4, qword ptr [\src + 168]
  xor q.b4, q.d1
  rol q.b4, 2
  andn q.t, q.b1, q.b2
  xor q.t, q.b0
  mov qword ptr [\dst + 160], q.t
  xor qword ptr [rsp + 200], q.t
  andn q.t, q.b2, q.b3
  xor q.t, q.b1
  mov qword ptr [\dst + 168], q.t
  xor qword ptr [rsp + 208], q.t
  andn q.t, q.b3, q.b4
  xor q.t, q.b2
  mov qword ptr [\dst + 176], q.t
  xor qword ptr [rsp + 216], q.t
  andn q.t, q.b4, q.b0
  xor q.t, q.b3
  mov qword ptr [\dst + 184], q.t
  xor qword ptr [rsp + 224], q.t
  andn q.t, q.b0, q.b1
  xor q.t, q.b4
  mov qword ptr [\dst + 192], q.t
  xor qword ptr [rsp + 232], q.t
.endm

.function keccak_f1600_scalar_x86 export (
  in: q.s
)
  .frame 240
  ;; initial column parities
  mov q.t, qword ptr [q.s + 0]
  xor q.t, qword ptr [q.s + 40]
  xor q.t, qword ptr [q.s + 80]
  xor q.t, qword ptr [q.s + 120]
  xor q.t, qword ptr [q.s + 160]
  mov qword ptr [rsp + 200], q.t
  mov q.t, qword ptr [q.s + 8]
  xor q.t, qword ptr [q.s + 48]
  xor q.t, qword ptr [q.s + 88]
  xor q.t, qword ptr [q.s + 128]
  xor q.t, qword ptr [q.s + 168]
  mov qword ptr [rsp + 208], q.t
  mov q.t, qword ptr [q.s + 16]
  xor q.t, qword ptr [q.s + 56]
  xor q.t, qword ptr [q.s + 96]
  xor q.t, qword ptr [q.s + 136]
  xor q.t, qword ptr [q.s + 176]
  mov qword ptr [rsp + 216], q.t
  mov q.t, qword ptr [q.s + 24]
  xor q.t, qword ptr [q.s + 64]
  xor q.t, qword ptr [q.s + 104]
  xor q.t, qword ptr [q.s + 144]
  xor q.t, qword ptr [q.s + 184]
  mov qword ptr [rsp + 224], q.t
  mov q.t, qword ptr [q.s + 32]
  xor q.t, qword ptr [q.s + 72]
  xor q.t, qword ptr [q.s + 112]
  xor q.t, qword ptr [q.s + 152]
  xor q.t, qword ptr [q.s + 192]
  mov qword ptr [rsp + 232], q.t
  lea q.rc, [rip + keccak_scalar_rc]
  mov d.n, 12
round2:
  KECCAK_ROUND(q.s, rsp, 0)
  KECCAK_ROUND(rsp, q.s, 8)
  add q.rc, 16
  sub d.n, 1
  jnz round2
  ret
.end
