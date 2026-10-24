;; AES-CTR keystream on VAES + AVX-512 (x86-64 SysV): four 512-bit registers hold
;; 16 counter blocks; one round-key broadcast feeds four vaesenc per round.
;;   void rktcrypto_aes_ctr_vaes(const unsigned char *rk, int nr_inc32, unsigned char ctr[16],
;;                               const unsigned char *in, unsigned char *out, intptr_t len)
;; len is a multiple of 64 (the C dispatcher keeps the tail on the AES-NI path);
;; nr_inc32 = Nr | (inc32 << 8). ctr is updated in place (big-endian, like the oracle).
;; Counters live byte-reversed (128-bit little-endian integers per lane): inc32 adds to
;; dword 0 with 32-bit wrap; full mode adds to qword 0 and carries into qword 1 with a
;; compare mask. Oracle: rktcrypto_aes_ctr_aesni (rktcrypto_x86.c); gate: asm/tests/test_aes_ctr_vaes.c.

.rodata aes_ctr_vaes_bswap align=16
  .byte 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0
.end
.rodata aes_ctr_vaes_inc align=64              ; lane i of vector j holds 4j+i in dword 0
  .long 0,0,0,0, 1,0,0,0, 2,0,0,0, 3,0,0,0
  .long 4,0,0,0, 5,0,0,0, 6,0,0,0, 7,0,0,0
  .long 8,0,0,0, 9,0,0,0, 10,0,0,0, 11,0,0,0
  .long 12,0,0,0, 13,0,0,0, 14,0,0,0, 15,0,0,0
.end
.rodata aes_ctr_vaes_four align=64             ; +4 per lane
  .long 4,0,0,0, 4,0,0,0, 4,0,0,0, 4,0,0,0
.end
.rodata aes_ctr_vaes_sixteen align=64          ; +16 per lane
  .long 16,0,0,0, 16,0,0,0, 16,0,0,0, 16,0,0,0
.end
.rodata aes_ctr_vaes_onehi align=64            ; qword 1 of every lane = 1 (the carry)
  .quad 0, 1, 0, 1, 0, 1, 0, 1
.end

.function rktcrypto_aes_ctr_vaes export (
  in: q.rk, q.nrflags, q.ctr, q.in, q.out, q.len
)
  mov d.nr, d.nrflags
  and d.nr, 0xff
  shr d.nrflags, 8                               ; inc32 flag
  mov q.off, q.nr
  shl q.off, 4
  vbroadcasti32x4 zmm.bswap, xmmword ptr [rip + aes_ctr_vaes_bswap]
  vbroadcasti32x4 zmm.k0, xmmword ptr [q.rk]
  vbroadcasti32x4 zmm.klast, xmmword ptr [q.rk + q.off]
  vbroadcasti32x4 zmm.base, xmmword ptr [q.ctr]  ; all four lanes = the counter
  vpshufb zmm.base, zmm.base, zmm.bswap          ; little-endian integers
  cmp q.len, 256
  jb tail64
loop256:
  test d.nrflags, d.nrflags
  jz full256
.for j, 0, 4
  vpaddd zmm.c${j}, zmm.base, zmmword ptr [rip + aes_ctr_vaes_inc + ${64 * j}]
.endfor
  vpaddd zmm.base, zmm.base, zmmword ptr [rip + aes_ctr_vaes_sixteen]
  jmp enc256
full256:
.for j, 0, 4
  vpaddq zmm.c${j}, zmm.base, zmmword ptr [rip + aes_ctr_vaes_inc + ${64 * j}]
  vpcmpuq k.c, zmm.c${j}, zmm.base, 1            ; qword 0 wrapped?
  kshiftlb k.c, k.c, 1                           ; -> qword 1 of the same lane
  vpaddq zmm.c${j}{k.c}, zmm.c${j}, zmmword ptr [rip + aes_ctr_vaes_onehi]
.endfor
  vpaddq zmm.t, zmm.base, zmmword ptr [rip + aes_ctr_vaes_sixteen]
  vpcmpuq k.c, zmm.t, zmm.base, 1
  kshiftlb k.c, k.c, 1
  vpaddq zmm.t{k.c}, zmm.t, zmmword ptr [rip + aes_ctr_vaes_onehi]
  vmovdqa64 zmm.base, zmm.t
enc256:
.for j, 0, 4
  vpshufb zmm.c${j}, zmm.c${j}, zmm.bswap
  vpxorq zmm.c${j}, zmm.c${j}, zmm.k0
.endfor
.for r, 1, 10
  vbroadcasti32x4 zmm.k, xmmword ptr [q.rk + ${16 * r}]
  .for j, 0, 4
  vaesenc zmm.c${j}, zmm.c${j}, zmm.k
  .endfor
.endfor
  cmp d.nr, 10
  je last256
.for r, 10, 12
  vbroadcasti32x4 zmm.k, xmmword ptr [q.rk + ${16 * r}]
  .for j, 0, 4
  vaesenc zmm.c${j}, zmm.c${j}, zmm.k
  .endfor
.endfor
  cmp d.nr, 12
  je last256
.for r, 12, 14
  vbroadcasti32x4 zmm.k, xmmword ptr [q.rk + ${16 * r}]
  .for j, 0, 4
  vaesenc zmm.c${j}, zmm.c${j}, zmm.k
  .endfor
.endfor
last256:
.for j, 0, 4
  vaesenclast zmm.c${j}, zmm.c${j}, zmm.klast
  vpxorq zmm.c${j}, zmm.c${j}, zmmword ptr [q.in + ${64 * j}]
  vmovdqu64 zmmword ptr [q.out + ${64 * j}], zmm.c${j}
.endfor
  add q.in, 256
  add q.out, 256
  sub q.len, 256
  cmp q.len, 256
  jae loop256
tail64:
  test q.len, q.len
  jz done
  test d.nrflags, d.nrflags
  jz full64
  vpaddd zmm.c0, zmm.base, zmmword ptr [rip + aes_ctr_vaes_inc]
  vpaddd zmm.base, zmm.base, zmmword ptr [rip + aes_ctr_vaes_four]
  jmp enc64
full64:
  vpaddq zmm.c0, zmm.base, zmmword ptr [rip + aes_ctr_vaes_inc]
  vpcmpuq k.c, zmm.c0, zmm.base, 1
  kshiftlb k.c, k.c, 1
  vpaddq zmm.c0{k.c}, zmm.c0, zmmword ptr [rip + aes_ctr_vaes_onehi]
  vpaddq zmm.t, zmm.base, zmmword ptr [rip + aes_ctr_vaes_four]
  vpcmpuq k.c, zmm.t, zmm.base, 1
  kshiftlb k.c, k.c, 1
  vpaddq zmm.t{k.c}, zmm.t, zmmword ptr [rip + aes_ctr_vaes_onehi]
  vmovdqa64 zmm.base, zmm.t
enc64:
  vpshufb zmm.c0, zmm.c0, zmm.bswap
  vpxorq zmm.c0, zmm.c0, zmm.k0
.for r, 1, 10
  vbroadcasti32x4 zmm.k, xmmword ptr [q.rk + ${16 * r}]
  vaesenc zmm.c0, zmm.c0, zmm.k
.endfor
  cmp d.nr, 10
  je last64
.for r, 10, 12
  vbroadcasti32x4 zmm.k, xmmword ptr [q.rk + ${16 * r}]
  vaesenc zmm.c0, zmm.c0, zmm.k
.endfor
  cmp d.nr, 12
  je last64
.for r, 12, 14
  vbroadcasti32x4 zmm.k, xmmword ptr [q.rk + ${16 * r}]
  vaesenc zmm.c0, zmm.c0, zmm.k
.endfor
last64:
  vaesenclast zmm.c0, zmm.c0, zmm.klast
  vpxorq zmm.c0, zmm.c0, zmmword ptr [q.in]
  vmovdqu64 zmmword ptr [q.out], zmm.c0
  add q.in, 64
  add q.out, 64
  sub q.len, 64
  jmp tail64
done:
  vpshufb xmm.t, xmm.base, xmm.bswap             ; lane 0 back to big-endian
  vmovdqu xmmword ptr [q.ctr], xmm.t
  ret
.end
