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


;; Reduce limb i of the accumulator (m = acc[i], acc += m*p): acc[i+1] += m<<32, acc[i+2] += m>>32,
;; acc[i+3..i+4] += m*poly3, carry into acc[i+5]. Invoke inside a .for so ${} is evaluated.
.macro P256_REDUCE i
  mov rdx, q.acc${\i}
  mov q.t0, q.acc${\i}
  shl q.t0, 32
  mulx q.t2, q.t1, qword ptr [rip + p256_x86_consts]
  shr rdx, 32
  add q.acc${\i + 1}, q.t0
  adc q.acc${\i + 2}, rdx
  adc q.acc${\i + 3}, q.t1
  adc q.acc${\i + 4}, q.t2
  adc q.acc${\i + 5}, 0
.endm

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
.for i, 0, 1
  P256_REDUCE(i)
.endfor
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
  P256_REDUCE(i)
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

;; ---- field operations as macros over memory operands (base + offset text), for the point kernels
.macro P256_MULM r, a, b
  mov rdx, qword ptr [\a]
  mulx q.acc1, q.acc0, qword ptr [\b]
  mulx q.acc2, q.t0, qword ptr [\b + 8]
  mulx q.acc3, q.t1, qword ptr [\b + 16]
  mulx q.acc4, q.t2, qword ptr [\b + 24]
  add q.acc1, q.t0
  adc q.acc2, q.t1
  adc q.acc3, q.t2
  adc q.acc4, 0
  mov q.acc5, 0
  .for i, 0, 1
  P256_REDUCE(i)
  .endfor
  .for i, 1, 4
  mov rdx, qword ptr [\a + ${8 * i}]
  xor q.acc${i + 5}, q.acc${i + 5}
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
  adcx q.acc${i + 4}, qword ptr [rip + p256_x86_consts + 16]
  adox q.acc${i + 5}, qword ptr [rip + p256_x86_consts + 16]
  adcx q.acc${i + 5}, qword ptr [rip + p256_x86_consts + 16]
  P256_REDUCE(i)
  .endfor
  P256_FINAL(\r)
.endm
.macro P256_SQRM r, a
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
  mov q.acc8, 0
  .for i, 0, 4
  P256_REDUCE(i)
  .endfor
  P256_FINAL(\r)
.endm
;; acc4..acc7 (+ acc8) < 2p -> subtract p once if that does not borrow, store to \r
.macro P256_FINAL r
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
  mov qword ptr [\r], q.r0
  mov qword ptr [\r + 8], q.r1
  mov qword ptr [\r + 16], q.r2
  mov qword ptr [\r + 24], q.r3
.endm
;; r = a + b mod p, fully reduced (mont_add: subtract p when the sum carried or is >= p)
.macro P256_ADDM r, a, b
  mov q.acc4, qword ptr [\a]
  mov q.acc5, qword ptr [\a + 8]
  mov q.acc6, qword ptr [\a + 16]
  mov q.acc7, qword ptr [\a + 24]
  xor q.acc8, q.acc8
  add q.acc4, qword ptr [\b]
  adc q.acc5, qword ptr [\b + 8]
  adc q.acc6, qword ptr [\b + 16]
  adc q.acc7, qword ptr [\b + 24]
  adc q.acc8, 0
  P256_FINAL(\r)
.endm
;; r = a - b mod p (mont_sub: add p back when the difference borrowed)
.macro P256_SUBM r, a, b
  mov q.r0, qword ptr [\a]
  mov q.r1, qword ptr [\a + 8]
  mov q.r2, qword ptr [\a + 16]
  mov q.r3, qword ptr [\a + 24]
  sub q.r0, qword ptr [\b]
  sbb q.r1, qword ptr [\b + 8]
  sbb q.r2, qword ptr [\b + 16]
  sbb q.r3, qword ptr [\b + 24]
  sbb q.t0, q.t0                              ; all ones iff a < b
  mov q.t1, qword ptr [rip + p256_x86_consts + 8]
  and q.t1, q.t0
  mov q.t2, qword ptr [rip + p256_x86_consts]
  and q.t2, q.t0
  add q.r0, q.t0                              ; p0 = -1
  adc q.r1, q.t1
  adc q.r2, 0
  adc q.r3, q.t2
  mov qword ptr [\r], q.r0
  mov qword ptr [\r + 8], q.r1
  mov qword ptr [\r + 16], q.r2
  mov qword ptr [\r + 24], q.r3
.endm

;; Montgomery squaring for the field prime: the full 512-bit square (six off-diagonal
;; products doubled with an adc chain, four diagonal products), then the four reductions.
;;   void mont_sqr_p256_x86(uint64_t r[4], const uint64_t a[4])
.function mont_sqr_p256_x86 export (
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
  mulx q.acc5, q.t1, qword ptr [q.ap + 24]         ; a1*a3 first, so acc5 exists for the carries
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
  xor q.acc7, q.acc7                               ; doubling of the off-diagonal sum
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
  mulx q.t1, q.t0, rdx                             ; a1^2
  adc q.acc2, q.t0
  adc q.acc3, q.t1
  mov rdx, qword ptr [q.ap + 16]
  mulx q.t1, q.t0, rdx                             ; a2^2
  adc q.acc4, q.t0
  adc q.acc5, q.t1
  mov rdx, qword ptr [q.ap + 24]
  mulx q.t1, q.t0, rdx                             ; a3^2
  adc q.acc6, q.t0
  adc q.acc7, q.t1
  mov q.acc8, 0
.for i, 0, 4
  P256_REDUCE(i)
.endfor
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

;; Generic 256-bit Montgomery multiplication for the scalar order (ctx = {m[4], n0, rr[4]}):
;; the same mulx/adcx/adox rows, with m = acc[i] * n0 and acc += m * M per row, then one
;; constant-time conditional subtraction of M.
;;   void mont_mul_x86(uint64_t r[4], const uint64_t a[4], const uint64_t b[4], const mont_ctx *ctx)
.function mont_mul_x86 export (
  in: q.rp, q.ap, rdx, q.ctx
)
  mov q.bp, rdx
  ;; row 0
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
.for i, 0, 4
  ;; reduce limb i: m = acc[i] * n0, acc += m * M (acc[i] becomes 0 and is dropped)
  mov rdx, q.acc${i}
  imul rdx, qword ptr [q.ctx + 32]
  xor d.t0, d.t0                            ; clear CF/OF after imul
  mulx q.t1, q.t0, qword ptr [q.ctx]
  adcx q.acc${i}, q.t0
  adox q.acc${i + 1}, q.t1
  mulx q.t1, q.t0, qword ptr [q.ctx + 8]
  adcx q.acc${i + 1}, q.t0
  adox q.acc${i + 2}, q.t1
  mulx q.t1, q.t0, qword ptr [q.ctx + 16]
  adcx q.acc${i + 2}, q.t0
  adox q.acc${i + 3}, q.t1
  mulx q.t1, q.t0, qword ptr [q.ctx + 24]
  adcx q.acc${i + 3}, q.t0
  adox q.acc${i + 4}, q.t1
  adcx q.acc${i + 4}, qword ptr [rip + p256_x86_consts + 16]
  adox q.acc${i + 5}, qword ptr [rip + p256_x86_consts + 16]
  adcx q.acc${i + 5}, qword ptr [rip + p256_x86_consts + 16]
  .for z, if i < 3 {0} else {1}, 1
  ;; row i+1: a[i+1] * b into acc[i+1..i+5], carries into acc[i+6]
  mov rdx, qword ptr [q.ap + ${8 * (i + 1)}]
  xor q.acc${i + 6}, q.acc${i + 6}
  mulx q.t1, q.t0, qword ptr [q.bp]
  adcx q.acc${i + 1}, q.t0
  adox q.acc${i + 2}, q.t1
  mulx q.t1, q.t0, qword ptr [q.bp + 8]
  adcx q.acc${i + 2}, q.t0
  adox q.acc${i + 3}, q.t1
  mulx q.t1, q.t0, qword ptr [q.bp + 16]
  adcx q.acc${i + 3}, q.t0
  adox q.acc${i + 4}, q.t1
  mulx q.t1, q.t0, qword ptr [q.bp + 24]
  adcx q.acc${i + 4}, q.t0
  adox q.acc${i + 5}, q.t1
  adcx q.acc${i + 5}, qword ptr [rip + p256_x86_consts + 16]
  adox q.acc${i + 6}, qword ptr [rip + p256_x86_consts + 16]
  adcx q.acc${i + 6}, qword ptr [rip + p256_x86_consts + 16]
  .endfor
.endfor
  ;; acc4..acc7 (+ acc8) < 2M: subtract M once if that does not borrow
  mov q.r0, q.acc4
  mov q.r1, q.acc5
  mov q.r2, q.acc6
  mov q.r3, q.acc7
  sub q.r0, qword ptr [q.ctx]
  sbb q.r1, qword ptr [q.ctx + 8]
  sbb q.r2, qword ptr [q.ctx + 16]
  sbb q.r3, qword ptr [q.ctx + 24]
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

;; ---- point doubling (jac_double_portable, same operation order) ------------------------------
;; r and p may alias; results are formed in frame slots and copied out. p->Z != 0 is the caller's
;; precondition. Slots: YY@0 ZZ@32 S@64 M@96 X3@128 Y3@160 Z3@192 T@224 Y4@256 XM@288 XP@320 PROD@352
;;   void jac_double_x86(jac *r, const jac *p)       (X@0, Y@32, Z@64 in a jac)
.function jac_double_x86 export (
  in: q.r, q.p
)
  .frame 384
  P256_SQRM(rsp + 0, q.p + 32)                   ; YY = Y^2
  P256_SQRM(rsp + 32, q.p + 64)                  ; ZZ = Z^2
  P256_MULM(rsp + 192, q.p + 32, q.p + 64)       ; Z3 = Y*Z
  P256_SUBM(rsp + 288, q.p + 0, rsp + 32)        ; XM = X - ZZ
  P256_ADDM(rsp + 320, q.p + 0, rsp + 32)        ; XP = X + ZZ
  P256_MULM(rsp + 64, q.p + 0, rsp + 0)          ; S = X*YY
  P256_SQRM(rsp + 256, rsp + 0)                  ; Y4 = YY^2
  P256_MULM(rsp + 352, rsp + 288, rsp + 320)     ; PROD = XM*XP
  P256_ADDM(rsp + 64, rsp + 64, rsp + 64)        ; S = 2S
  P256_ADDM(rsp + 64, rsp + 64, rsp + 64)        ; S = 4*X*Y^2
  P256_ADDM(rsp + 96, rsp + 352, rsp + 352)      ; M = 2*PROD
  P256_ADDM(rsp + 96, rsp + 96, rsp + 352)       ; M = 3*PROD
  P256_ADDM(rsp + 256, rsp + 256, rsp + 256)
  P256_ADDM(rsp + 256, rsp + 256, rsp + 256)
  P256_ADDM(rsp + 256, rsp + 256, rsp + 256)     ; Y4 = 8*Y^4
  P256_SQRM(rsp + 128, rsp + 96)                 ; X3 = M^2
  P256_SUBM(rsp + 128, rsp + 128, rsp + 64)
  P256_SUBM(rsp + 128, rsp + 128, rsp + 64)      ; X3 = M^2 - 2S
  P256_SUBM(rsp + 224, rsp + 64, rsp + 128)      ; T = S - X3
  P256_MULM(rsp + 224, rsp + 96, rsp + 224)      ; T = M*(S - X3)
  P256_SUBM(rsp + 160, rsp + 224, rsp + 256)     ; Y3 = T - 8*Y^4
  P256_ADDM(rsp + 192, rsp + 192, rsp + 192)     ; Z3 = 2*Y*Z
.for k, 0, 12
  mov q.t0, qword ptr [rsp + ${128 + 8 * k}]
  mov qword ptr [q.r + ${8 * k}], q.t0
.endfor
  ret
.end

;; ---- mixed addition (mixed_add_portable, same operation order); q affine, p->Z != 0 ---------
;; Returns 0 when r was written, 1 when H = 0 and R = 0 (the caller doubles p), 2 when H = 0 and
;; R != 0 (the caller returns the identity). r may alias p or q.
;; Slots: Z1Z1@0 U2@32 S2@64 H@96 RR@128 HH@160 HHH@192 T@224 T2@256 TT@288 X3@320 Z3@352
;;   int mixed_add_x86(jac *r, const jac *p, const jac *q)
.function mixed_add_x86 export (
  in: q.r, q.p, rdx
  out: q.ret
)
  .frame 384
  mov q.rr, q.r                                  ; a copy the allocator may spill (r itself is rdi)
  mov q.q, rdx
  P256_SQRM(rsp + 0, q.p + 64)                   ; Z1Z1 = Z1^2
  P256_MULM(rsp + 64, q.q + 32, q.p + 64)        ; S2 = Y2*Z1
  P256_MULM(rsp + 32, q.q + 0, rsp + 0)          ; U2 = X2*Z1Z1
  P256_MULM(rsp + 64, rsp + 64, rsp + 0)         ; S2 = S2*Z1Z1
  P256_SUBM(rsp + 96, rsp + 32, q.p + 0)         ; H = U2 - X1
  P256_SUBM(rsp + 128, rsp + 64, q.p + 32)       ; R = S2 - Y1
  mov q.t0, qword ptr [rsp + 96]
  or q.t0, qword ptr [rsp + 104]
  or q.t0, qword ptr [rsp + 112]
  or q.t0, qword ptr [rsp + 120]
  jz hzero
  P256_SQRM(rsp + 160, rsp + 96)                 ; HH = H^2
  P256_SQRM(rsp + 320, rsp + 128)                ; X3 = R^2
  P256_MULM(rsp + 192, rsp + 160, rsp + 96)      ; HHH = HH*H
  P256_MULM(rsp + 224, q.p + 0, rsp + 160)       ; T = X1*HH
  P256_SUBM(rsp + 320, rsp + 320, rsp + 192)
  P256_SUBM(rsp + 320, rsp + 320, rsp + 224)
  P256_SUBM(rsp + 320, rsp + 320, rsp + 224)     ; X3 = R^2 - HHH - 2*X1*HH
  P256_MULM(rsp + 288, q.p + 32, rsp + 192)      ; TT = Y1*HHH
  P256_MULM(rsp + 352, q.p + 64, rsp + 96)       ; Z3 = Z1*H
  P256_SUBM(rsp + 256, rsp + 224, rsp + 320)     ; T2 = T - X3
  P256_MULM(rsp + 256, rsp + 128, rsp + 256)     ; T2 = R*(T - X3)
  P256_SUBM(rsp + 256, rsp + 256, rsp + 288)     ; Y3 = T2 - TT
.for k, 0, 4
  mov q.t0, qword ptr [rsp + ${320 + 8 * k}]
  mov qword ptr [q.rr + ${8 * k}], q.t0
  mov q.t0, qword ptr [rsp + ${256 + 8 * k}]
  mov qword ptr [q.rr + ${32 + 8 * k}], q.t0
  mov q.t0, qword ptr [rsp + ${352 + 8 * k}]
  mov qword ptr [q.rr + ${64 + 8 * k}], q.t0
.endfor
  xor d.ret, d.ret
  ret
hzero:
  mov q.t0, qword ptr [rsp + 128]
  or q.t0, qword ptr [rsp + 136]
  or q.t0, qword ptr [rsp + 144]
  or q.t0, qword ptr [rsp + 152]
  mov d.ret, 2
  mov d.t1, 1
  test q.t0, q.t0
  cmovz d.ret, d.t1                              ; H = 0 and R = 0: double
  ret
.end

;; ---- .call probe: r = (a*b)*c through two calls of mont_mul_p256_x86 (ABI path check) ------
;;   void p256_mul3_x86(uint64_t r[4], const uint64_t a[4], const uint64_t b[4], const uint64_t c[4])
.function p256_mul3_x86 export (
  in: q.r, q.a, rdx, q.c
)
  .frame 32
  mov q.b, rdx
  .call mont_mul_p256_x86(qword ptr [rsp], q.a, q.b)
  .call mont_mul_p256_x86(q.r, qword ptr [rsp], q.c)
  ret
.end
