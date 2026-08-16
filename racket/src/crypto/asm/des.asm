;; Single-DES 16-round Feistel core (AArch64), hand-scheduled in rktasm.
;; Mirrors the C des_feistel/des1_core in rktcrypto_legacy_ciphers.c: each round's
;; F = 8 SP-table lookups XORed, where SP[box][ (6-bit window of R) ^ subkey_b ]
;; already folds the S-box with the P permutation. Every 6-bit E-expansion group
;; is a rotate: window_b = ror(R, shift_b) & 0x3f (the two wrapping groups fall
;; out for free at shift 27/31). Subkeys are the pre-split 6-bit groups
;; ks->g[r][0..7]; the C driver passes the start pointer and a +8/-8 byte stride
;; so one forward loop serves both encrypt and decrypt. IP/FP, key schedule and
;; the block loop stay in C; this kernel is one block's 16-round core.
;; Oracle: des1_core (bit-exact); gate: asm/tests/test_des.c.
;;
;; uint64_t des1_core_asm(const uint32_t *sp,        // &DES_SP[0][0], 8*64 u32
;;                        const unsigned char *sk,   // &g[0] enc / &g[15] dec
;;                        intptr_t stride,           // +8 enc / -8 dec (bytes)
;;                        uint64_t state);           // (L<<32)|R after IP
;;   returns (R<<32)|L after 16 rounds + the pre-output swap.
.function des1_core_asm export (
  in: x.spt, x.sk, x.stride, x.state
)
entry:
  .save all
  ror x.sw, x.state, #32         ; swap halves: low 32 of sw = high 32 of state = L
  mov w.L, w.sw
  mov w.R, w.state               ; R = low 32
  mov x.cnt, #16
loop:
  ror w.w, w.R, #27
  and w.i, w.w, #0x3f
  ldrb w.k, [x.sk]
  eor w.i, w.i, w.k
  ldr w.f, [x.spt, w.i, uxtw #2]           ; box 0

  ror w.w, w.R, #23
  and w.i, w.w, #0x3f
  ldrb w.k, [x.sk, #1]
  eor w.i, w.i, w.k
  add w.i, w.i, #64
  ldr w.bx, [x.spt, w.i, uxtw #2]
  eor w.f, w.f, w.bx                       ; box 1

  ror w.w, w.R, #19
  and w.i, w.w, #0x3f
  ldrb w.k, [x.sk, #2]
  eor w.i, w.i, w.k
  add w.i, w.i, #128
  ldr w.bx, [x.spt, w.i, uxtw #2]
  eor w.f, w.f, w.bx                       ; box 2

  ror w.w, w.R, #15
  and w.i, w.w, #0x3f
  ldrb w.k, [x.sk, #3]
  eor w.i, w.i, w.k
  add w.i, w.i, #192
  ldr w.bx, [x.spt, w.i, uxtw #2]
  eor w.f, w.f, w.bx                       ; box 3

  ror w.w, w.R, #11
  and w.i, w.w, #0x3f
  ldrb w.k, [x.sk, #4]
  eor w.i, w.i, w.k
  add w.i, w.i, #256
  ldr w.bx, [x.spt, w.i, uxtw #2]
  eor w.f, w.f, w.bx                       ; box 4

  ror w.w, w.R, #7
  and w.i, w.w, #0x3f
  ldrb w.k, [x.sk, #5]
  eor w.i, w.i, w.k
  add w.i, w.i, #320
  ldr w.bx, [x.spt, w.i, uxtw #2]
  eor w.f, w.f, w.bx                       ; box 5

  ror w.w, w.R, #3
  and w.i, w.w, #0x3f
  ldrb w.k, [x.sk, #6]
  eor w.i, w.i, w.k
  add w.i, w.i, #384
  ldr w.bx, [x.spt, w.i, uxtw #2]
  eor w.f, w.f, w.bx                       ; box 6

  ror w.w, w.R, #31
  and w.i, w.w, #0x3f
  ldrb w.k, [x.sk, #7]
  eor w.i, w.i, w.k
  add w.i, w.i, #448
  ldr w.bx, [x.spt, w.i, uxtw #2]
  eor w.f, w.f, w.bx                       ; box 7

  ;; Feistel step: nR = L ^ F; L = R; R = nR
  eor w.nR, w.L, w.f
  mov w.L, w.R
  mov w.R, w.nR

  add x.sk, x.sk, x.stride
  subs x.cnt, x.cnt, #1
  b.ne loop

  orr x0, x.L, x.R, lsl #32      ; (R<<32)|L  (pre-output swap)
  .restore all
  ret
.end
