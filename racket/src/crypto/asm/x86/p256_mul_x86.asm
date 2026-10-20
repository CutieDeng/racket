;; P-256 Montgomery multiplication on MULX/ADX (x86-64 SysV), 4 x 64-bit limbs, R = 2^256,
;; n0 = 1 for p = 2^256 - 2^224 + 2^192 + 2^96 - 1: each row a[i]*b is accumulated with the
;; adcx/adox carry chains and the lowest limb is reduced at once (m = acc[i];
;; acc += m*p is acc[i+1] += m<<32, acc[i+2] += m>>32, acc[i+3..i+4] += m*poly3), then one
;; constant-time conditional subtraction of p.
;;   void mont_mul_p256_x86(uint64_t r[4], const uint64_t a[4], const uint64_t b[4])
;; The b pointer arrives in rdx, which mulx reads implicitly, so it is moved out first.
;; Oracle: mont_mul_portable (rktcrypto_p256.c) via the harness's own u128 CIOS reference
;; and the public ECDH/ECDSA API with the BMI2/ADX bit cleared; gate: asm/tests/test_p256_x86.c.

.rodata p256_x86_consts align=16
  .quad 0xffffffff00000001          ; poly3 = p[3]
  .quad 0x00000000ffffffff          ; poly1 = p[1]
  .quad 0                           ; zero (adox has no immediate form)
.end

.function mont_mul_p256_x86 export (
  in: q.rp, q.ap, rdx
)
  mov q.bp, rdx
  ;; row 0: a0 * b
  mov rdx, qword ptr [q.ap]
  mulx q.acc1, q.acc0, qword ptr [q.bp]
  mulx q.acc2, q.t0, qword ptr [q.bp + 8]
  mulx q.acc3, q.t1, qword ptr [q.bp + 16]
  mulx q.acc4, q.t2, qword ptr [q.bp + 24]
  add q.acc1, q.t0
  adc q.acc2, q.t1
  adc q.acc3, q.t2
  adc q.acc4, 0
  mov q.acc5, 0
  ;; reduce limb 0
  mov rdx, q.acc0
  mov q.t0, q.acc0
  shl q.t0, 32
  mulx q.t2, q.t1, qword ptr [rip + p256_x86_consts]
  shr rdx, 32
  add q.acc1, q.t0
  adc q.acc2, rdx
  adc q.acc3, q.t1
  adc q.acc4, q.t2
  adc q.acc5, 0
.for i, 1, 4
  ;; row i: a[i] * b into acc[i..i+4], carries into acc[i+5]
  mov rdx, qword ptr [q.ap + ${8 * i}]
  xor q.acc${i + 5}, q.acc${i + 5}
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
  adcx q.acc${i + 4}, qword ptr [rip + p256_x86_consts + 16]
  adox q.acc${i + 5}, qword ptr [rip + p256_x86_consts + 16]
  adcx q.acc${i + 5}, qword ptr [rip + p256_x86_consts + 16]
  ;; reduce limb i
  mov rdx, q.acc${i}
  mov q.t0, q.acc${i}
  shl q.t0, 32
  mulx q.t2, q.t1, qword ptr [rip + p256_x86_consts]
  shr rdx, 32
  add q.acc${i + 1}, q.t0
  adc q.acc${i + 2}, rdx
  adc q.acc${i + 3}, q.t1
  adc q.acc${i + 4}, q.t2
  adc q.acc${i + 5}, 0
.endfor
  ;; acc4..acc7 (+ acc8) < 2p: subtract p once if that does not borrow
  mov q.r0, q.acc4
  mov q.r1, q.acc5
  mov q.r2, q.acc6
  mov q.r3, q.acc7
  sub q.r0, -1
  sbb q.r1, qword ptr [rip + p256_x86_consts + 8]
  sbb q.r2, 0
  sbb q.r3, qword ptr [rip + p256_x86_consts]
  sbb q.acc8, 0
  cmovc q.r0, q.acc4
  cmovc q.r1, q.acc5
  cmovc q.r2, q.acc6
  cmovc q.r3, q.acc7
  mov qword ptr [q.rp], q.r0
  mov qword ptr [q.rp + 8], q.r1
  mov qword ptr [q.rp + 16], q.r2
  mov qword ptr [q.rp + 24], q.r3
  ret
.end
