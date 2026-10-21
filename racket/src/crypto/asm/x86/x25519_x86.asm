;; X25519 field arithmetic in radix 2^64 on MULX/ADX (x86-64 SysV): four 64-bit limbs,
;; loosely reduced (values below 2^256; only the byte encoding is made canonical, in C).
;; The 512-bit product is folded with 38 = 2 * 19 (2^256 = 38 mod p), then the small top
;; word is folded again and a last carry is absorbed with a masked 38.
;;   void fe64_mul_x86(uint64_t r[4], const uint64_t a[4], const uint64_t b[4])
;;   void fe64_sqr_x86(uint64_t r[4], const uint64_t a[4])
;;   void fe64_mul121665_x86(uint64_t r[4], const uint64_t a[4])
;; The b pointer of the multiply arrives in rdx, which mulx reads implicitly, so it is
;; moved out first. Oracle: the radix-2^51 ladder (rktcrypto_x25519.c) through the public
;; rktcrypto_x25519 with the BMI2/ADX bit cleared; gate: asm/tests/test_x25519_x86.c.

.rodata fe64_x86_consts align=16
  .quad 0                           ; zero (adox has no immediate form)
.end

;; acc0..acc3 += 38 * acc4..acc7, fold the top word, absorb the last carry; store to \rp
.macro FE64_REDUCE rp
  mov rdx, 38
  xor q.t2, q.t2
  mulx q.t1, q.t0, q.acc4
  adcx q.acc0, q.t0
  adox q.acc1, q.t1
  mulx q.t1, q.t0, q.acc5
  adcx q.acc1, q.t0
  adox q.acc2, q.t1
  mulx q.t1, q.t0, q.acc6
  adcx q.acc2, q.t0
  adox q.acc3, q.t1
  mulx q.t1, q.t0, q.acc7
  adcx q.acc3, q.t0
  adox q.t1, q.t2
  adcx q.t1, q.t2
  imul q.t1, q.t1, 38
  add q.acc0, q.t1
  adc q.acc1, 0
  adc q.acc2, 0
  adc q.acc3, 0
  sbb q.t0, q.t0
  and q.t0, 38
  add q.acc0, q.t0
  mov qword ptr [\rp], q.acc0
  mov qword ptr [\rp + 8], q.acc1
  mov qword ptr [\rp + 16], q.acc2
  mov qword ptr [\rp + 24], q.acc3
.endm

.function fe64_mul_x86 export (
  in: q.rp, q.ap, rdx
)
  mov q.bp, rdx
  mov rdx, qword ptr [q.ap]
  mulx q.acc1, q.acc0, qword ptr [q.bp]
  mulx q.acc2, q.t0, qword ptr [q.bp + 8]
  mulx q.acc3, q.t1, qword ptr [q.bp + 16]
  mulx q.acc4, q.t2, qword ptr [q.bp + 24]
  add q.acc1, q.t0
  adc q.acc2, q.t1
  adc q.acc3, q.t2
  adc q.acc4, 0
.for i, 1, 4
  mov rdx, qword ptr [q.ap + ${8 * i}]
  xor q.acc${i + 4}, q.acc${i + 4}
  mulx q.t1, q.t0, qword ptr [q.bp]
  adcx q.acc${i}, q.t0
  adox q.acc${i + 1}, q.t1
  mulx q.t1, q.t0, qword ptr [q.bp + 8]
  adcx q.acc${i + 1}, q.t0
  adox q.acc${i + 2}, q.t1
  mulx q.t1, q.t0, qword ptr [q.bp + 16]
  adcx q.acc${i + 2}, q.t0
  adox q.acc${i + 3}, q.t1
  mulx q.t1, q.t0, qword ptr [q.bp + 24]
  adcx q.acc${i + 3}, q.t0
  adox q.acc${i + 4}, q.t1
  adcx q.acc${i + 4}, qword ptr [rip + fe64_x86_consts]
.endfor
.for z, 0, 1
  FE64_REDUCE(q.rp)
.endfor
  ret
.end

.function fe64_sqr_x86 export (
  in: q.rp, q.ap
)
  mov rdx, qword ptr [q.ap]
  mulx q.acc2, q.acc1, qword ptr [q.ap + 8]        ; a0*a1
  mulx q.acc3, q.t0, qword ptr [q.ap + 16]         ; a0*a2
  mulx q.acc4, q.t1, qword ptr [q.ap + 24]         ; a0*a3
  add q.acc2, q.t0
  adc q.acc3, q.t1
  adc q.acc4, 0
  mov rdx, qword ptr [q.ap + 8]
  mulx q.acc5, q.t1, qword ptr [q.ap + 24]         ; a1*a3
  add q.acc4, q.t1
  adc q.acc5, 0
  mulx q.t1, q.t0, qword ptr [q.ap + 16]           ; a1*a2
  add q.acc3, q.t0
  adc q.acc4, q.t1
  adc q.acc5, 0
  mov rdx, qword ptr [q.ap + 16]
  mulx q.acc6, q.t0, qword ptr [q.ap + 24]         ; a2*a3
  add q.acc5, q.t0
  adc q.acc6, 0
  xor q.acc7, q.acc7
  add q.acc1, q.acc1
  adc q.acc2, q.acc2
  adc q.acc3, q.acc3
  adc q.acc4, q.acc4
  adc q.acc5, q.acc5
  adc q.acc6, q.acc6
  adc q.acc7, 0
  mov rdx, qword ptr [q.ap]
  mulx q.t1, q.acc0, rdx                           ; a0^2
  add q.acc1, q.t1
  mov rdx, qword ptr [q.ap + 8]
  mulx q.t1, q.t0, rdx
  adc q.acc2, q.t0
  adc q.acc3, q.t1
  mov rdx, qword ptr [q.ap + 16]
  mulx q.t1, q.t0, rdx
  adc q.acc4, q.t0
  adc q.acc5, q.t1
  mov rdx, qword ptr [q.ap + 24]
  mulx q.t1, q.t0, rdx
  adc q.acc6, q.t0
  adc q.acc7, q.t1
.for z, 0, 1
  FE64_REDUCE(q.rp)
.endfor
  ret
.end

.function fe64_mul121665_x86 export (
  in: q.rp, q.ap
)
  mov rdx, 121665
  mulx q.t1, q.acc0, qword ptr [q.ap]
  mulx q.t2, q.acc1, qword ptr [q.ap + 8]
  add q.acc1, q.t1
  mulx q.t1, q.acc2, qword ptr [q.ap + 16]
  adc q.acc2, q.t2
  mulx q.t2, q.acc3, qword ptr [q.ap + 24]
  adc q.acc3, q.t1
  adc q.t2, 0
  imul q.t2, q.t2, 38
  add q.acc0, q.t2
  adc q.acc1, 0
  adc q.acc2, 0
  adc q.acc3, 0
  sbb q.t0, q.t0
  and q.t0, 38
  add q.acc0, q.t0
  mov qword ptr [q.rp], q.acc0
  mov qword ptr [q.rp + 8], q.acc1
  mov qword ptr [q.rp + 16], q.acc2
  mov qword ptr [q.rp + 24], q.acc3
  ret
.end

;; ---- one Montgomery-ladder step as a single kernel ----------------------------------------
;; st = {x2, z2, x3, z3} (four 32-byte elements, in and out), x1 the base u-coordinate. The ten
;; field multiplications/squarings are the kernel bodies above as macros over memory operands
;; (so no call/push/pop or argument shuffling between them), add/sub are macros too, and the
;; nine temporaries live in .frame slots.
;;   void x25519_step_x86(uint64_t st[16], const uint64_t x1[4])
.macro FE64_MULM r, a, b
  mov rdx, qword ptr [\a]
  mulx q.acc1, q.acc0, qword ptr [\b]
  mulx q.acc2, q.t0, qword ptr [\b + 8]
  mulx q.acc3, q.t1, qword ptr [\b + 16]
  mulx q.acc4, q.t2, qword ptr [\b + 24]
  add q.acc1, q.t0
  adc q.acc2, q.t1
  adc q.acc3, q.t2
  adc q.acc4, 0
  .for i, 1, 4
  mov rdx, qword ptr [\a + ${8 * i}]
  xor q.acc${i + 4}, q.acc${i + 4}
  mulx q.t1, q.t0, qword ptr [\b]
  adcx q.acc${i}, q.t0
  adox q.acc${i + 1}, q.t1
  mulx q.t1, q.t0, qword ptr [\b + 8]
  adcx q.acc${i + 1}, q.t0
  adox q.acc${i + 2}, q.t1
  mulx q.t1, q.t0, qword ptr [\b + 16]
  adcx q.acc${i + 2}, q.t0
  adox q.acc${i + 3}, q.t1
  mulx q.t1, q.t0, qword ptr [\b + 24]
  adcx q.acc${i + 3}, q.t0
  adox q.acc${i + 4}, q.t1
  adcx q.acc${i + 4}, qword ptr [rip + fe64_x86_consts]
  .endfor
  .for z, 0, 1
  FE64_REDUCE(\r)
  .endfor
.endm
.macro FE64_SQRM r, a
  mov rdx, qword ptr [\a]
  mulx q.acc2, q.acc1, qword ptr [\a + 8]
  mulx q.acc3, q.t0, qword ptr [\a + 16]
  mulx q.acc4, q.t1, qword ptr [\a + 24]
  add q.acc2, q.t0
  adc q.acc3, q.t1
  adc q.acc4, 0
  mov rdx, qword ptr [\a + 8]
  mulx q.acc5, q.t1, qword ptr [\a + 24]
  add q.acc4, q.t1
  adc q.acc5, 0
  mulx q.t1, q.t0, qword ptr [\a + 16]
  add q.acc3, q.t0
  adc q.acc4, q.t1
  adc q.acc5, 0
  mov rdx, qword ptr [\a + 16]
  mulx q.acc6, q.t0, qword ptr [\a + 24]
  add q.acc5, q.t0
  adc q.acc6, 0
  xor q.acc7, q.acc7
  add q.acc1, q.acc1
  adc q.acc2, q.acc2
  adc q.acc3, q.acc3
  adc q.acc4, q.acc4
  adc q.acc5, q.acc5
  adc q.acc6, q.acc6
  adc q.acc7, 0
  mov rdx, qword ptr [\a]
  mulx q.t1, q.acc0, rdx
  add q.acc1, q.t1
  mov rdx, qword ptr [\a + 8]
  mulx q.t1, q.t0, rdx
  adc q.acc2, q.t0
  adc q.acc3, q.t1
  mov rdx, qword ptr [\a + 16]
  mulx q.t1, q.t0, rdx
  adc q.acc4, q.t0
  adc q.acc5, q.t1
  mov rdx, qword ptr [\a + 24]
  mulx q.t1, q.t0, rdx
  adc q.acc6, q.t0
  adc q.acc7, q.t1
  .for z, 0, 1
  FE64_REDUCE(\r)
  .endfor
.endm
.macro FE64_MUL121665M r, a
  mov rdx, 121665
  mulx q.t1, q.acc0, qword ptr [\a]
  mulx q.t2, q.acc1, qword ptr [\a + 8]
  add q.acc1, q.t1
  mulx q.t1, q.acc2, qword ptr [\a + 16]
  adc q.acc2, q.t2
  mulx q.t2, q.acc3, qword ptr [\a + 24]
  adc q.acc3, q.t1
  adc q.t2, 0
  imul q.t2, q.t2, 38
  add q.acc0, q.t2
  adc q.acc1, 0
  adc q.acc2, 0
  adc q.acc3, 0
  sbb q.t0, q.t0
  and q.t0, 38
  add q.acc0, q.t0
  mov qword ptr [\r], q.acc0
  mov qword ptr [\r + 8], q.acc1
  mov qword ptr [\r + 16], q.acc2
  mov qword ptr [\r + 24], q.acc3
.endm
;; r = a + b mod 2^256-38 (the carry folded twice)
.macro FE64_ADDM r, a, b
  mov q.acc0, qword ptr [\a]
  mov q.acc1, qword ptr [\a + 8]
  mov q.acc2, qword ptr [\a + 16]
  mov q.acc3, qword ptr [\a + 24]
  add q.acc0, qword ptr [\b]
  adc q.acc1, qword ptr [\b + 8]
  adc q.acc2, qword ptr [\b + 16]
  adc q.acc3, qword ptr [\b + 24]
  sbb q.t0, q.t0
  and q.t0, 38
  add q.acc0, q.t0
  adc q.acc1, 0
  adc q.acc2, 0
  adc q.acc3, 0
  sbb q.t0, q.t0
  and q.t0, 38
  add q.acc0, q.t0
  mov qword ptr [\r], q.acc0
  mov qword ptr [\r + 8], q.acc1
  mov qword ptr [\r + 16], q.acc2
  mov qword ptr [\r + 24], q.acc3
.endm
;; r = a - b mod 2^256-38 (the borrow folded twice)
.macro FE64_SUBM r, a, b
  mov q.acc0, qword ptr [\a]
  mov q.acc1, qword ptr [\a + 8]
  mov q.acc2, qword ptr [\a + 16]
  mov q.acc3, qword ptr [\a + 24]
  sub q.acc0, qword ptr [\b]
  sbb q.acc1, qword ptr [\b + 8]
  sbb q.acc2, qword ptr [\b + 16]
  sbb q.acc3, qword ptr [\b + 24]
  sbb q.t0, q.t0
  and q.t0, 38
  sub q.acc0, q.t0
  sbb q.acc1, 0
  sbb q.acc2, 0
  sbb q.acc3, 0
  sbb q.t0, q.t0
  and q.t0, 38
  sub q.acc0, q.t0
  mov qword ptr [\r], q.acc0
  mov qword ptr [\r + 8], q.acc1
  mov qword ptr [\r + 16], q.acc2
  mov qword ptr [\r + 24], q.acc3
.endm

;; frame slots (32 bytes each): A@0 B@32 C@64 D@96 DA@128 CB@160 AA@192 BB@224 E@256 T@288
;; st: x2@0 z2@32 x3@64 z3@96
.function x25519_step_x86 export (
  in: q.st, q.x1
)
  .frame 320
  FE64_ADDM(rsp + 0, q.st + 0, q.st + 32)           ; A = x2 + z2
  FE64_SUBM(rsp + 32, q.st + 0, q.st + 32)          ; B = x2 - z2
  FE64_ADDM(rsp + 64, q.st + 64, q.st + 96)         ; C = x3 + z3
  FE64_SUBM(rsp + 96, q.st + 64, q.st + 96)         ; D = x3 - z3
  FE64_MULM(rsp + 128, rsp + 96, rsp + 0)           ; DA = D * A
  FE64_MULM(rsp + 160, rsp + 64, rsp + 32)          ; CB = C * B
  FE64_ADDM(rsp + 288, rsp + 128, rsp + 160)        ; T = DA + CB
  FE64_SQRM(q.st + 64, rsp + 288)                   ; x3 = T^2
  FE64_SUBM(rsp + 288, rsp + 128, rsp + 160)        ; T = DA - CB
  FE64_SQRM(rsp + 288, rsp + 288)                   ; T = T^2
  FE64_MULM(q.st + 96, q.x1, rsp + 288)             ; z3 = x1 * T
  FE64_SQRM(rsp + 192, rsp + 0)                     ; AA = A^2
  FE64_SQRM(rsp + 224, rsp + 32)                    ; BB = B^2
  FE64_MULM(q.st + 0, rsp + 192, rsp + 224)         ; x2 = AA * BB
  FE64_SUBM(rsp + 256, rsp + 192, rsp + 224)        ; E = AA - BB
  FE64_MUL121665M(rsp + 288, rsp + 256)             ; T = 121665 * E
  FE64_ADDM(rsp + 288, rsp + 288, rsp + 192)        ; T = T + AA
  FE64_MULM(q.st + 32, rsp + 256, rsp + 288)        ; z2 = E * T
  ret
.end
