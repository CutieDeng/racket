;; SHA-256 block compression on SHA-NI (x86-64, SysV). First kernel of the x86
;; module: physical registers, transcribed one-to-one from the verified
;; intrinsics in rktcrypto_x86.c (rktcrypto_sha256_block_shani), state kept in
;; registers across all nblk blocks.
;;   void rktcrypto_sha256_blocks_x86(uint32_t state[8], const unsigned char *data, intptr_t nblk)
;; Register plan: xmm0 = wk (implicit operand of sha256rnds2), xmm1 = STATE0 (abef),
;; xmm2 = STATE1 (cdgh), xmm3-xmm6 = MSG0-MSG3, xmm7 = TMP, xmm8/xmm9 = saved state,
;; xmm10 = byte-swap mask.
;; Oracle: rktcrypto_sha256_block_shani; gate: asm/tests/test_sha256_x86.c.

.rodata sha256_x86_k align=64
  .long 0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5
  .long 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174
  .long 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da
  .long 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967
  .long 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85
  .long 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070
  .long 0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3
  .long 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
.end

.rodata sha256_x86_shuf align=16
  .byte 3, 2, 1, 0, 7, 6, 5, 4, 11, 10, 9, 8, 15, 14, 13, 12
.end

.function rktcrypto_sha256_blocks_x86 export (
  in: rdi, rsi, rdx
)
entry:
  test rdx, rdx
  jz done
  movdqa xmm10, xmmword ptr [rip + sha256_x86_shuf]
  movdqu xmm7, xmmword ptr [rdi]            ; a b c d
  movdqu xmm2, xmmword ptr [rdi + 16]       ; e f g h
  pshufd xmm7, xmm7, 0xb1                   ; c d a b
  pshufd xmm2, xmm2, 0x1b                   ; h g f e
  movdqa xmm1, xmm7
  palignr xmm1, xmm2, 8                     ; STATE0 = a b e f
  pblendw xmm2, xmm7, 0xf0                  ; STATE1 = c d g h
blk:
  movdqa xmm8, xmm1
  movdqa xmm9, xmm2
  movdqu xmm3, xmmword ptr [rsi]
  pshufb xmm3, xmm10
  movdqu xmm4, xmmword ptr [rsi + 16]
  pshufb xmm4, xmm10
  movdqu xmm5, xmmword ptr [rsi + 32]
  pshufb xmm5, xmm10
  movdqu xmm6, xmmword ptr [rsi + 48]
  pshufb xmm6, xmm10
  ;; rounds 0-15: wk = MSGi + K[4i..4i+3]
.for i, 0, 4
  movdqa xmm0, xmm${3 + i}
  paddd xmm0, xmmword ptr [rip + sha256_x86_k + ${16 * i}]
  sha256rnds2 xmm2, xmm1
  pshufd xmm0, xmm0, 0x0e
  sha256rnds2 xmm1, xmm2
.endfor
  ;; rounds 16-63: schedule MSGa = msg2(msg1(MSGa, MSGb) + alignr(MSGd, MSGc, 4), MSGd), then 4 rounds
.for r, 4, 16
  sha256msg1 xmm${3 + (r % 4)}, xmm${3 + ((r + 1) % 4)}
  movdqa xmm7, xmm${3 + ((r + 3) % 4)}
  palignr xmm7, xmm${3 + ((r + 2) % 4)}, 4
  paddd xmm${3 + (r % 4)}, xmm7
  sha256msg2 xmm${3 + (r % 4)}, xmm${3 + ((r + 3) % 4)}
  movdqa xmm0, xmm${3 + (r % 4)}
  paddd xmm0, xmmword ptr [rip + sha256_x86_k + ${16 * r}]
  sha256rnds2 xmm2, xmm1
  pshufd xmm0, xmm0, 0x0e
  sha256rnds2 xmm1, xmm2
.endfor
  paddd xmm1, xmm8
  paddd xmm2, xmm9
  add rsi, 64
  sub rdx, 1
  jnz blk
  pshufd xmm7, xmm1, 0x1b                   ; f e b a
  pshufd xmm2, xmm2, 0xb1                   ; d c h g
  movdqa xmm1, xmm7
  pblendw xmm1, xmm2, 0xf0                  ; a b c d
  palignr xmm2, xmm7, 8                     ; e f g h
  movdqu xmmword ptr [rdi], xmm1
  movdqu xmmword ptr [rdi + 16], xmm2
done:
  ret
.end
