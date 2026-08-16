;; asmp .context source for the hand-scheduled P-256 point kernels (was the
;; source-less rktcrypto_p256_hand.S). One `.context p256_field (scope library)`
;; declares the OpenSSL-derived register-ABI contract ONCE — operand a in x4-x7,
;; operand b in x8-x11, b[0] limb in x3, result acc in x14-x17, result ptr x0,
;; src2 ptr x2, callee-saved frame regs x19/x21/x22 — replacing the former
;; per-kernel hardcoded fixed-register ABI (review risk 4). The two frame kernels
;; use `.save all` so asmp auto-generates the callee-saved prologue/epilogue,
;; replacing the hand stp x19-x22 + hardcoded stack offsets (review risk 5). The
;; hand instruction schedule is preserved bit-for-bit; only physical register
;; names became `x.<field>`. The 128/352-byte scratch memory frames stay hand
;; written (M3 `.frame` unimplemented) -> assemble with --allow-sp-writes.
;; Assemble: cli/as.rkt --gnu-input --apple --elim --default-abi aapcs64
;;   --keep-comments --allow-sp-writes p256_hand.asm
;; Gates: asm/tests/{test_p256_extra,test_mixed_add,test_mont_sqrn}.c each 0/200000.

;; t0/t1/t2 (x1/x12/x13) ARE part of the cross-function register-ABI, not local
;; scratch: jac_double_hw/mixed_add_hw call the helpers via 38 `bl`s with NO
;; `.clobber` declarations, so the whole family shares one implicit contract —
;; a helper touches only x4-x17 + x1/x12/x13 and preserves everything else, and
;; the callers keep live values in the preserved registers across those calls.
;; Pinning them in `.context` encodes that contract (§7.1: cross-function shared
;; register-ABI → .context). Leaving them undeclared virtuals SEGFAULTS: asmp's
;; allocator can't infer a bare `bl`'s clobber set, so it reassigns registers in
;; ways that break the implicit caller/helper agreement (verified 2026-07-29).
;; This whole kernel is deliberately hand-allocated (OpenSSL-parity schedule,
;; asmp scheduler off for crypto per D1); asmp names/checks/regenerates it, and
;; still block-reorders it (e.g. mixed_add's epilogue), but does not allocate it.
.context p256_field (scope library) a0=x4 a1=x5 a2=x6 a3=x7 b0=x8 b1=x9 b2=x10 b3=x11 acc0=x14 acc1=x15 acc2=x16 acc3=x17 rp=x0 bp=x2 bz=x3 fr=x21 fp=x22 fq=x19 fspare=x20 t0=x1 t1=x12 t2=x13


.function p256_mul (context p256_field)
entry:
    ldr x.t1, [x.bp, #8]
    ldr x.b3, [x.bp, #16]
    ldr x.acc3, [x.bp, #24]
    mul x.acc0, x.a0, x.bz
    umulh x.b2, x.a0, x.bz
    mul x.acc1, x.a1, x.bz
    umulh x.b1, x.a1, x.bz
    mul x.acc2, x.a2, x.bz
    umulh x.b0, x.a2, x.bz
    mul x.t2, x.a3, x.bz
    umulh x.bp, x.a3, x.bz
    adds x.acc1, x.acc1, x.b2
    ubfm x.b2, x.acc0, #32, #31
    adcs x.acc2, x.acc2, x.b1
    ubfm x.b1, x.acc0, #32, #63
    adcs x.t2, x.t2, x.b0
    adc x.bz, xzr, x.bp
    mov x.t0, xzr
    subs x.b0, x.acc0, x.b2
    sbc x.bp, x.acc0, x.b1
    adds x.acc0, x.acc1, x.b2
    mul x.b2, x.a0, x.t1
    adcs x.acc1, x.acc2, x.b1
    mul x.b1, x.a1, x.t1
    adcs x.acc2, x.t2, x.b0
    mul x.b0, x.a2, x.t1
    adcs x.t2, x.bz, x.bp
    mul x.bp, x.a3, x.t1
    adc x.bz, x.t0, xzr
    adds x.acc0, x.acc0, x.b2
    umulh x.b2, x.a0, x.t1
    adcs x.acc1, x.acc1, x.b1
    umulh x.b1, x.a1, x.t1
    adcs x.acc2, x.acc2, x.b0
    umulh x.b0, x.a2, x.t1
    adcs x.t2, x.t2, x.bp
    umulh x.bp, x.a3, x.t1
    adc x.bz, x.bz, xzr
    adds x.acc1, x.acc1, x.b2
    ubfm x.b2, x.acc0, #32, #31
    adcs x.acc2, x.acc2, x.b1
    ubfm x.b1, x.acc0, #32, #63
    adcs x.t2, x.t2, x.b0
    adcs x.bz, x.bz, x.bp
    adc x.t0, xzr, xzr
    subs x.b0, x.acc0, x.b2
    sbc x.bp, x.acc0, x.b1
    adds x.acc0, x.acc1, x.b2
    mul x.b2, x.a0, x.b3
    adcs x.acc1, x.acc2, x.b1
    mul x.b1, x.a1, x.b3
    adcs x.acc2, x.t2, x.b0
    mul x.b0, x.a2, x.b3
    adcs x.t2, x.bz, x.bp
    mul x.bp, x.a3, x.b3
    adc x.bz, x.t0, xzr
    adds x.acc0, x.acc0, x.b2
    umulh x.b2, x.a0, x.b3
    adcs x.acc1, x.acc1, x.b1
    umulh x.b1, x.a1, x.b3
    adcs x.acc2, x.acc2, x.b0
    umulh x.b0, x.a2, x.b3
    adcs x.t2, x.t2, x.bp
    umulh x.bp, x.a3, x.b3
    adc x.bz, x.bz, xzr
    adds x.acc1, x.acc1, x.b2
    ubfm x.b2, x.acc0, #32, #31
    adcs x.acc2, x.acc2, x.b1
    ubfm x.b1, x.acc0, #32, #63
    adcs x.t2, x.t2, x.b0
    adcs x.bz, x.bz, x.bp
    adc x.t0, xzr, xzr
    subs x.b0, x.acc0, x.b2
    sbc x.bp, x.acc0, x.b1
    adds x.acc0, x.acc1, x.b2
    mul x.b2, x.a0, x.acc3
    adcs x.acc1, x.acc2, x.b1
    mul x.b1, x.a1, x.acc3
    adcs x.acc2, x.t2, x.b0
    mul x.b0, x.a2, x.acc3
    adcs x.t2, x.bz, x.bp
    mul x.bp, x.a3, x.acc3
    adc x.bz, x.t0, xzr
    adds x.acc0, x.acc0, x.b2
    umulh x.b2, x.a0, x.acc3
    adcs x.acc1, x.acc1, x.b1
    umulh x.b1, x.a1, x.acc3
    adcs x.acc2, x.acc2, x.b0
    umulh x.b0, x.a2, x.acc3
    adcs x.t2, x.t2, x.bp
    umulh x.bp, x.a3, x.acc3
    adc x.bz, x.bz, xzr
    adds x.acc1, x.acc1, x.b2
    ubfm x.b2, x.acc0, #32, #31
    adcs x.acc2, x.acc2, x.b1
    ubfm x.b1, x.acc0, #32, #63
    adcs x.t2, x.t2, x.b0
    adcs x.bz, x.bz, x.bp
    adc x.t0, xzr, xzr
    subs x.b0, x.acc0, x.b2
    sbc x.bp, x.acc0, x.b1
    adds x.acc0, x.acc1, x.b2
    adcs x.acc1, x.acc2, x.b1
    adcs x.acc2, x.t2, x.b0
    adcs x.t2, x.bz, x.bp
    adc x.bz, x.t0, xzr
    movz x.bp, #65535
    movk x.bp, #65535, LSL #16
    movz x.t0, #1
    movk x.t0, #65535, LSL #32
    movk x.t0, #65535, LSL #48
    adds x.b2, x.acc0, #1
    sbcs x.b1, x.acc1, x.bp
    sbcs x.b0, x.acc2, xzr
    sbcs x.bp, x.t2, x.t0
    sbcs xzr, x.bz, xzr
    csel x.acc0, x.acc0, x.b2, LO
    csel x.acc1, x.acc1, x.b1, LO
    csel x.acc2, x.acc2, x.b0, LO
    csel x.acc3, x.t2, x.bp, LO
    stp x.acc0,x.acc1,[x.rp]
    stp x.acc2,x.acc3,[x.rp,#16]
    ret
.end

.function p256_sqr (context p256_field)
entry:
    mul x.acc1, x.a1, x.a0
    umulh x.b3, x.a1, x.a0
    mul x.acc2, x.a2, x.a0
    umulh x.b2, x.a2, x.a0
    mul x.acc3, x.a3, x.a0
    umulh x.bp, x.a3, x.a0
    adds x.acc2, x.acc2, x.b3
    mul x.t1, x.a2, x.a1
    umulh x.b3, x.a2, x.a1
    adcs x.acc3, x.acc3, x.b2
    mul x.b2, x.a3, x.a1
    umulh x.b1, x.a3, x.a1
    adc x.bp, x.bp, xzr
    mul x.t0, x.a3, x.a2
    umulh x.b0, x.a3, x.a2
    adds x.b3, x.b3, x.b2
    mul x.acc0, x.a0, x.a0
    adc x.b2, x.b1, xzr
    adds x.acc3, x.acc3, x.t1
    umulh x.a0, x.a0, x.a0
    adcs x.bp, x.bp, x.b3
    mul x.b3, x.a1, x.a1
    adcs x.t0, x.t0, x.b2
    umulh x.a1, x.a1, x.a1
    adc x.b0, x.b0, xzr
    adds x.acc1, x.acc1, x.acc1
    mul x.b2, x.a2, x.a2
    adcs x.acc2, x.acc2, x.acc2
    umulh x.a2, x.a2, x.a2
    adcs x.acc3, x.acc3, x.acc3
    mul x.b1, x.a3, x.a3
    adcs x.bp, x.bp, x.bp
    umulh x.a3, x.a3, x.a3
    adcs x.t0, x.t0, x.t0
    adcs x.b0, x.b0, x.b0
    adc x.bz, xzr, xzr
    adds x.acc1, x.acc1, x.a0
    adcs x.acc2, x.acc2, x.b3
    adcs x.acc3, x.acc3, x.a1
    adcs x.bp, x.bp, x.b2
    adcs x.t0, x.t0, x.a2
    ubfm x.t1, x.acc0, #32, #31
    adcs x.b0, x.b0, x.b1
    ubfm x.b3, x.acc0, #32, #63
    adc x.bz, x.bz, x.a3
    subs x.b2, x.acc0, x.t1
    sbc x.b1, x.acc0, x.b3
    adds x.acc0, x.acc1, x.t1
    adcs x.acc1, x.acc2, x.b3
    ubfm x.t1, x.acc0, #32, #31
    adcs x.acc2, x.acc3, x.b2
    ubfm x.b3, x.acc0, #32, #63
    adc x.acc3, x.b1, xzr
    subs x.b2, x.acc0, x.t1
    sbc x.b1, x.acc0, x.b3
    adds x.acc0, x.acc1, x.t1
    adcs x.acc1, x.acc2, x.b3
    ubfm x.t1, x.acc0, #32, #31
    adcs x.acc2, x.acc3, x.b2
    ubfm x.b3, x.acc0, #32, #63
    adc x.acc3, x.b1, xzr
    subs x.b2, x.acc0, x.t1
    sbc x.b1, x.acc0, x.b3
    adds x.acc0, x.acc1, x.t1
    adcs x.acc1, x.acc2, x.b3
    ubfm x.t1, x.acc0, #32, #31
    adcs x.acc2, x.acc3, x.b2
    ubfm x.b3, x.acc0, #32, #63
    adc x.acc3, x.b1, xzr
    subs x.b2, x.acc0, x.t1
    sbc x.b1, x.acc0, x.b3
    adds x.acc0, x.acc1, x.t1
    adcs x.acc1, x.acc2, x.b3
    adcs x.acc2, x.acc3, x.b2
    adc x.acc3, x.b1, xzr
    adds x.acc0, x.acc0, x.bp
    adcs x.acc1, x.acc1, x.t0
    adcs x.acc2, x.acc2, x.b0
    adcs x.acc3, x.acc3, x.bz
    adc x.bp, xzr, xzr
    movz x.bz, #65535
    movk x.bz, #65535, LSL #16
    movz x.t0, #1
    movk x.t0, #65535, LSL #32
    movk x.t0, #65535, LSL #48
    adds x.t1, x.acc0, #1
    sbcs x.b3, x.acc1, x.bz
    sbcs x.b2, x.acc2, xzr
    sbcs x.b1, x.acc3, x.t0
    sbcs xzr, x.bp, xzr
    csel x.acc0, x.acc0, x.t1, LO
    csel x.acc1, x.acc1, x.b3, LO
    csel x.acc2, x.acc2, x.b2, LO
    csel x.acc3, x.acc3, x.b1, LO
    stp x.acc0,x.acc1,[x.rp]
    stp x.acc2,x.acc3,[x.rp,#16]
    ret
.end

.function p256_add (context p256_field)
entry:
    adds x.acc0, x.acc0, x.b0
    adcs x.acc1, x.acc1, x.b1
    adcs x.acc2, x.acc2, x.b2
    adcs x.acc3, x.acc3, x.b3
    adc x.b2, xzr, xzr
    movn x.b0, #0
    movz x.bp, #65535
    movk x.bp, #65535, LSL #16
    movz x.t0, #1
    movk x.t0, #65535, LSL #32
    movk x.t0, #65535, LSL #48
    subs x.b1, x.acc0, x.b0
    sbcs x.b0, x.acc1, x.bp
    sbcs x.bp, x.acc2, xzr
    sbcs x.t0, x.acc3, x.t0
    sbcs xzr, x.b2, xzr
    csel x.acc0, x.b1, x.acc0, CS
    csel x.acc1, x.b0, x.acc1, CS
    csel x.acc2, x.bp, x.acc2, CS
    csel x.acc3, x.t0, x.acc3, CS
    str x.acc0, [x.rp, #0]
    str x.acc1, [x.rp, #8]
    str x.acc2, [x.rp, #16]
    str x.acc3, [x.rp, #24]
    ret
.end

.function p256_sub_from (context p256_field)
entry:
    ldr x.b2, [x.bp, #0]
    ldr x.b1, [x.bp, #8]
    ldr x.b0, [x.bp, #16]
    ldr x.t0, [x.bp, #24]
    subs x.acc0, x.acc0, x.b2
    sbcs x.acc1, x.acc1, x.b1
    sbcs x.acc2, x.acc2, x.b0
    sbcs x.acc3, x.acc3, x.t0
    sbc x.b1, xzr, xzr
    movn x.b0, #0
    movz x.bp, #65535
    movk x.bp, #65535, LSL #16
    movz x.t0, #1
    movk x.t0, #65535, LSL #32
    movk x.t0, #65535, LSL #48
    and x.b0, x.b0, x.b1
    and x.bp, x.bp, x.b1
    and x.t0, x.t0, x.b1
    adds x.acc0, x.acc0, x.b0
    adcs x.acc1, x.acc1, x.bp
    adcs x.acc2, x.acc2, xzr
    adc x.acc3, x.acc3, x.t0
    str x.acc0, [x.rp, #0]
    str x.acc1, [x.rp, #8]
    str x.acc2, [x.rp, #16]
    str x.acc3, [x.rp, #24]
    ret
.end

.function p256_sub_morf (context p256_field)
entry:
    ldr x.b2, [x.bp, #0]
    ldr x.b1, [x.bp, #8]
    ldr x.b0, [x.bp, #16]
    ldr x.t0, [x.bp, #24]
    subs x.acc0, x.b2, x.acc0
    sbcs x.acc1, x.b1, x.acc1
    sbcs x.acc2, x.b0, x.acc2
    sbcs x.acc3, x.t0, x.acc3
    sbc x.b1, xzr, xzr
    movn x.b0, #0
    movz x.bp, #65535
    movk x.bp, #65535, LSL #16
    movz x.t0, #1
    movk x.t0, #65535, LSL #32
    movk x.t0, #65535, LSL #48
    and x.b0, x.b0, x.b1
    and x.bp, x.bp, x.b1
    and x.t0, x.t0, x.b1
    adds x.acc0, x.acc0, x.b0
    adcs x.acc1, x.acc1, x.bp
    adcs x.acc2, x.acc2, xzr
    adc x.acc3, x.acc3, x.t0
    str x.acc0, [x.rp, #0]
    str x.acc1, [x.rp, #8]
    str x.acc2, [x.rp, #16]
    str x.acc3, [x.rp, #24]
    ret
.end

.function p256_div2 (context p256_field)
entry:
    and x.b1, x.acc0, #1
    neg x.b1, x.b1
    movn x.b0, #0
    movz x.bp, #65535
    movk x.bp, #65535, LSL #16
    movz x.t0, #1
    movk x.t0, #65535, LSL #32
    movk x.t0, #65535, LSL #48
    and x.b0, x.b0, x.b1
    and x.bp, x.bp, x.b1
    and x.t0, x.t0, x.b1
    adds x.acc0, x.acc0, x.b0
    adcs x.acc1, x.acc1, x.bp
    adcs x.acc2, x.acc2, xzr
    adcs x.acc3, x.acc3, x.t0
    adc x.t0, xzr, xzr
    extr x.acc0, x.acc1, x.acc0, #1
    extr x.acc1, x.acc2, x.acc1, #1
    extr x.acc2, x.acc3, x.acc2, #1
    extr x.acc3, x.t0, x.acc3, #1
    str x.acc0, [x.rp, #0]
    str x.acc1, [x.rp, #8]
    str x.acc2, [x.rp, #16]
    str x.acc3, [x.rp, #24]
    ret
.end

.function jac_double_hw (context p256_field) export
entry:
    .save all
    sub sp, sp, #128


	ldp	x.acc0,x.acc1,[x.t0,#32]
	mov	x.fr,x.rp
	ldp	x.acc2,x.acc3,[x.t0,#48]
	mov	x.fp,x.t0
	mov	x.b0,x.acc0
	mov	x.b1,x.acc1
	ldp	x.a0,x.a1,[x.fp,#64]	// forward load for p256_sqr_mont
	mov	x.b2,x.acc2
	mov	x.b3,x.acc3
	ldp	x.a2,x.a3,[x.fp,#80]
	add	x.rp,sp,#0
	bl p256_add	// p256_mul_by_2(S, in_y);

	add	x.rp,sp,#64
	bl p256_sqr	// p256_sqr_mont(Zsqr, in_z);

	ldp	x.b0,x.b1,[x.fp]
	ldp	x.b2,x.b3,[x.fp,#16]
	mov	x.a0,x.acc0		// put Zsqr aside for p256_sub
	mov	x.a1,x.acc1
	mov	x.a2,x.acc2
	mov	x.a3,x.acc3
	add	x.rp,sp,#32
	bl p256_add	// p256_add(M, Zsqr, in_x);

	add	x.bp,x.fp,#0
	mov	x.acc0,x.a0		// restore Zsqr
	mov	x.acc1,x.a1
	ldp	x.a0,x.a1,[sp,#0]	// forward load for p256_sqr_mont
	mov	x.acc2,x.a2
	mov	x.acc3,x.a3
	ldp	x.a2,x.a3,[sp,#16]
	add	x.rp,sp,#64
	bl p256_sub_morf	// p256_sub(Zsqr, in_x, Zsqr);

	add	x.rp,sp,#0
	bl p256_sqr	// p256_sqr_mont(S, S);

	ldr	x.bz,[x.fp,#32]
	ldp	x.a0,x.a1,[x.fp,#64]
	ldp	x.a2,x.a3,[x.fp,#80]
	add	x.bp,x.fp,#32
	add	x.rp,sp,#96
	bl p256_mul	// p256_mul_mont(tmp0, in_z, in_y);

	mov	x.b0,x.acc0
	mov	x.b1,x.acc1
	ldp	x.a0,x.a1,[sp,#0]	// forward load for p256_sqr_mont
	mov	x.b2,x.acc2
	mov	x.b3,x.acc3
	ldp	x.a2,x.a3,[sp,#16]
	add	x.rp,x.fr,#64
	bl p256_add	// p256_mul_by_2(res_z, tmp0);

	add	x.rp,sp,#96
	bl p256_sqr	// p256_sqr_mont(tmp0, S);

	ldr	x.bz,[sp,#64]		// forward load for p256_mul_mont
	ldp	x.a0,x.a1,[sp,#32]
	ldp	x.a2,x.a3,[sp,#48]
	add	x.rp,x.fr,#32
	bl p256_div2	// p256_div_by_2(res_y, tmp0);

	add	x.bp,sp,#64
	add	x.rp,sp,#32
	bl p256_mul	// p256_mul_mont(M, M, Zsqr);

	mov	x.b0,x.acc0		// duplicate M
	mov	x.b1,x.acc1
	mov	x.b2,x.acc2
	mov	x.b3,x.acc3
	mov	x.a0,x.acc0		// put M aside
	mov	x.a1,x.acc1
	mov	x.a2,x.acc2
	mov	x.a3,x.acc3
	add	x.rp,sp,#32
	bl p256_add
	mov	x.b0,x.a0			// restore M
	mov	x.b1,x.a1
	ldr	x.bz,[x.fp]		// forward load for p256_mul_mont
	mov	x.b2,x.a2
	ldp	x.a0,x.a1,[sp,#0]
	mov	x.b3,x.a3
	ldp	x.a2,x.a3,[sp,#16]
	bl p256_add	// p256_mul_by_3(M, M);

	add	x.bp,x.fp,#0
	add	x.rp,sp,#0
	bl p256_mul	// p256_mul_mont(S, S, in_x);

	mov	x.b0,x.acc0
	mov	x.b1,x.acc1
	ldp	x.a0,x.a1,[sp,#32]	// forward load for p256_sqr_mont
	mov	x.b2,x.acc2
	mov	x.b3,x.acc3
	ldp	x.a2,x.a3,[sp,#48]
	add	x.rp,sp,#96
	bl p256_add	// p256_mul_by_2(tmp0, S);

	add	x.rp,x.fr,#0
	bl p256_sqr	// p256_sqr_mont(res_x, M);

	add	x.bp,sp,#96
	bl p256_sub_from	// p256_sub(res_x, res_x, tmp0);

	add	x.bp,sp,#0
	add	x.rp,sp,#0
	bl p256_sub_morf	// p256_sub(S, S, res_x);

	ldr	x.bz,[sp,#32]
	mov	x.a0,x.acc0		// copy S
	mov	x.a1,x.acc1
	mov	x.a2,x.acc2
	mov	x.a3,x.acc3
	add	x.bp,sp,#32
	bl p256_mul	// p256_mul_mont(S, S, M);

	add	x.bp,x.fr,#32
	add	x.rp,x.fr,#32
	bl p256_sub_from	// p256_sub(res_y, S, res_y);

    add sp, sp, #128
    .restore all
    ret
.end

.function mixed_add_hw (context p256_field) export
entry:
    .save all
    sub sp, sp, #352
    mov x.fr,x.rp                 // r
    mov x.fp,x.t0                 // p
    mov x.fq,x.bp                 // q

    // branch (a): p->Z == 0 -> *r = *q
    ldp x.b0,x.b1,[x.fp,#64]
    ldp x.b2,x.b3,[x.fp,#80]
    orr x.b0,x.b0,x.b1
    orr x.b2,x.b2,x.b3
    orr x.b0,x.b0,x.b2
    cbnz x.b0, Lma_main
    ldp x.b0,x.b1,[x.fq,#0]
    stp x.b0,x.b1,[x.fr,#0]
    ldp x.b0,x.b1,[x.fq,#16]
    stp x.b0,x.b1,[x.fr,#16]
    ldp x.b0,x.b1,[x.fq,#32]
    stp x.b0,x.b1,[x.fr,#32]
    ldp x.b0,x.b1,[x.fq,#48]
    stp x.b0,x.b1,[x.fr,#48]
    ldp x.b0,x.b1,[x.fq,#64]
    stp x.b0,x.b1,[x.fr,#64]
    ldp x.b0,x.b1,[x.fq,#80]
    stp x.b0,x.b1,[x.fr,#80]
    b Lma_epi

Lma_main:
    // op1: Z1Z1 = sqr(p->Z)
    ldp x.a0,x.a1,[x.fp,#64]
    ldp x.a2,x.a3,[x.fp,#80]
    add x.rp,sp,#0
    bl p256_sqr
    // op2: S2 = mul(q->Y, p->Z)
    ldp x.a0,x.a1,[x.fq,#32]
    ldp x.a2,x.a3,[x.fq,#48]
    ldr x.bz,[x.fp,#64]
    add x.bp,x.fp,#64
    add x.rp,sp,#32
    bl p256_mul
    // op3: U2 = mul(q->X, Z1Z1)
    ldp x.a0,x.a1,[x.fq,#0]
    ldp x.a2,x.a3,[x.fq,#16]
    ldr x.bz,[sp,#0]
    add x.bp,sp,#0
    add x.rp,sp,#64
    bl p256_mul
    // forward-load op5 operands (sub_from below preserves x.bz-x.a3)
    ldp x.a0,x.a1,[sp,#32]
    ldp x.a2,x.a3,[sp,#48]
    ldr x.bz,[sp,#0]
    // op4: H = U2 - p->X
    add x.bp,x.fp,#0
    add x.rp,sp,#96
    bl p256_sub_from
    // op5: S2 = mul(S2, Z1Z1)
    add x.bp,sp,#0
    add x.rp,sp,#32
    bl p256_mul
    // forward-load op7 operand a = H
    ldp x.a0,x.a1,[sp,#96]
    ldp x.a2,x.a3,[sp,#112]
    // op6: R = S2' - p->Y
    add x.bp,x.fp,#32
    add x.rp,sp,#128
    bl p256_sub_from

    // branch (b)/(c): H==0 ? (R==0 -> double ; R!=0 -> infinity)
    orr x.b0,x.acc0,x.acc1
    orr x.b1,x.acc2,x.acc3
    orr x.b0,x.b0,x.b1               // R != 0 ?
    ldp x.b2,x.b3,[sp,#96]
    ldp x.t1,x.t2,[sp,#112]
    orr x.b2,x.b2,x.b3
    orr x.t1,x.t1,x.t2
    orr x.b2,x.b2,x.t1            // H != 0 ?
    cbnz x.b2, Lma_cont
    cbnz x.b0, Lma_inf
    mov x.rp,x.fr
    mov x.t0,x.fp
    bl jac_double_hw
    b Lma_epi
Lma_inf:
    mov x.b0,#1
    stp x.b0,xzr,[x.fr,#0]
    stp xzr,xzr,[x.fr,#16]
    stp x.b0,xzr,[x.fr,#32]
    stp xzr,xzr,[x.fr,#48]
    stp xzr,xzr,[x.fr,#64]
    stp xzr,xzr,[x.fr,#80]
    b Lma_epi

Lma_cont:
    // op7: HH = sqr(H)
    add x.rp,sp,#160
    bl p256_sqr
    // op9: HHH = mul(HH, H)   (a = HH straight from x.acc0-17)
    mov x.a0,x.acc0
    mov x.a1,x.acc1
    mov x.a2,x.acc2
    mov x.a3,x.acc3
    ldr x.bz,[sp,#96]
    add x.bp,sp,#96
    add x.rp,sp,#192
    bl p256_mul
    // op10: t = mul(p->X, HH)
    ldp x.a0,x.a1,[x.fp,#0]
    ldp x.a2,x.a3,[x.fp,#16]
    ldr x.bz,[sp,#160]
    add x.bp,sp,#160
    add x.rp,sp,#224
    bl p256_mul
    // op8: X3 = sqr(R)
    ldp x.a0,x.a1,[sp,#128]
    ldp x.a2,x.a3,[sp,#144]
    add x.rp,sp,#256
    bl p256_sqr
    // forward-load op14 operands
    ldp x.a0,x.a1,[x.fp,#32]
    ldp x.a2,x.a3,[x.fp,#48]
    ldr x.bz,[sp,#192]
    // op11: X3 = R^2 - HHH
    add x.bp,sp,#192
    add x.rp,sp,#256
    bl p256_sub_from
    // op12: X3 = X3 - t
    add x.bp,sp,#224
    add x.rp,sp,#256
    bl p256_sub_from
    // op13: X3 = X3 - t
    add x.bp,sp,#224
    add x.rp,sp,#256
    bl p256_sub_from
    // op14: tt = mul(p->Y, HHH)
    add x.bp,sp,#192
    add x.rp,sp,#288
    bl p256_mul
    // op15: Z3 = mul(p->Z, H) -> r->Z
    ldp x.a0,x.a1,[x.fp,#64]
    ldp x.a2,x.a3,[x.fp,#80]
    ldr x.bz,[sp,#96]
    add x.bp,sp,#96
    add x.rp,x.fr,#64
    bl p256_mul
    // op16: t2 = t - X3
    ldp x.acc0,x.acc1,[sp,#224]
    ldp x.acc2,x.acc3,[sp,#240]
    add x.bp,sp,#256
    add x.rp,sp,#320
    bl p256_sub_from
    // op17: t2 = mul(R, t2)
    ldp x.a0,x.a1,[sp,#128]
    ldp x.a2,x.a3,[sp,#144]
    ldr x.bz,[sp,#320]
    add x.bp,sp,#320
    add x.rp,sp,#320
    bl p256_mul
    // op18: Y3 = t2' - tt -> r->Y
    add x.bp,sp,#288
    add x.rp,x.fr,#32
    bl p256_sub_from
    // op19: store X3 -> r->X
    ldp x.b0,x.b1,[sp,#256]
    ldp x.b2,x.b3,[sp,#272]
    stp x.b0,x.b1,[x.fr,#0]
    stp x.b2,x.b3,[x.fr,#16]

Lma_epi:
    add sp, sp, #352
    .restore all
    ret
.end

.function mont_sqrn_p256 (context p256_field) export
entry:
    ldr x.a0, [x.t0, #0]
    ldr x.a1, [x.t0, #8]
    ldr x.a2, [x.t0, #16]
    ldr x.a3, [x.t0, #24]
    mov x.t2, x.bp
sqloop:
    // dedicated symmetric squaring of (x.a0,x.a1,x.a2,x.a3): upper-triangular products
    mul   x.acc1, x.a1, x.a0
    umulh x.b3, x.a1, x.a0
    mul   x.acc2, x.a2, x.a0
    umulh x.b2, x.a2, x.a0
    mul   x.acc3, x.a3, x.a0
    umulh x.bp,  x.a3, x.a0
    adds  x.acc2, x.acc2, x.b3
    mul   x.t1, x.a2, x.a1
    umulh x.b3, x.a2, x.a1
    adcs  x.acc3, x.acc3, x.b2
    mul   x.b2, x.a3, x.a1
    umulh x.b1,  x.a3, x.a1
    adc   x.bp,  x.bp,  xzr
    mul   x.t0,  x.a3, x.a2
    umulh x.b0,  x.a3, x.a2
    adds  x.b3, x.b3, x.b2
    mul   x.acc0, x.a0, x.a0
    adc   x.b2, x.b1,  xzr
    adds  x.acc3, x.acc3, x.t1
    umulh x.a0,  x.a0, x.a0
    adcs  x.bp,  x.bp,  x.b3
    mul   x.b3, x.a1, x.a1
    adcs  x.t0,  x.t0,  x.b2
    umulh x.a1,  x.a1, x.a1
    adc   x.b0,  x.b0,  xzr
    // double the cross-product sum
    adds  x.acc1, x.acc1, x.acc1
    mul   x.b2, x.a2, x.a2
    adcs  x.acc2, x.acc2, x.acc2
    umulh x.a2,  x.a2, x.a2
    adcs  x.acc3, x.acc3, x.acc3
    mul   x.b1,  x.a3, x.a3
    adcs  x.bp,  x.bp,  x.bp
    umulh x.a3,  x.a3, x.a3
    adcs  x.t0,  x.t0,  x.t0
    adcs  x.b0,  x.b0,  x.b0
    adc   x.bz,  xzr, xzr
    // add diagonal squares -> full 512-bit product in x.acc0..x.bz
    adds  x.acc1, x.acc1, x.a0
    adcs  x.acc2, x.acc2, x.b3
    adcs  x.acc3, x.acc3, x.a1
    adcs  x.bp,  x.bp,  x.b2
    adcs  x.t0,  x.t0,  x.a2
    ubfm  x.t1, x.acc0, #32, #31
    adcs  x.b0,  x.b0,  x.b1
    ubfm  x.b3, x.acc0, #32, #63
    adc   x.bz,  x.bz,  x.a3
    // P-256 Solinas Montgomery reduction (4 rounds)
    subs  x.b2, x.acc0, x.t1
    sbc   x.b1,  x.acc0, x.b3
    adds  x.acc0, x.acc1, x.t1
    adcs  x.acc1, x.acc2, x.b3
    ubfm  x.t1, x.acc0, #32, #31
    adcs  x.acc2, x.acc3, x.b2
    ubfm  x.b3, x.acc0, #32, #63
    adc   x.acc3, x.b1,  xzr
    subs  x.b2, x.acc0, x.t1
    sbc   x.b1,  x.acc0, x.b3
    adds  x.acc0, x.acc1, x.t1
    adcs  x.acc1, x.acc2, x.b3
    ubfm  x.t1, x.acc0, #32, #31
    adcs  x.acc2, x.acc3, x.b2
    ubfm  x.b3, x.acc0, #32, #63
    adc   x.acc3, x.b1,  xzr
    subs  x.b2, x.acc0, x.t1
    sbc   x.b1,  x.acc0, x.b3
    adds  x.acc0, x.acc1, x.t1
    adcs  x.acc1, x.acc2, x.b3
    ubfm  x.t1, x.acc0, #32, #31
    adcs  x.acc2, x.acc3, x.b2
    ubfm  x.b3, x.acc0, #32, #63
    adc   x.acc3, x.b1,  xzr
    subs  x.b2, x.acc0, x.t1
    sbc   x.b1,  x.acc0, x.b3
    adds  x.acc0, x.acc1, x.t1
    adcs  x.acc1, x.acc2, x.b3
    adcs  x.acc2, x.acc3, x.b2
    adc   x.acc3, x.b1,  xzr
    // fold in the high half of the product
    adds  x.acc0, x.acc0, x.bp
    adcs  x.acc1, x.acc1, x.t0
    adcs  x.acc2, x.acc2, x.b0
    adcs  x.acc3, x.acc3, x.bz
    adc   x.bp,  xzr, xzr
    // conditional subtract of p -> [0,p)
    movz  x.bz, #65535
    movk  x.bz, #65535, LSL #16
    movz  x.t0, #1
    movk  x.t0, #65535, LSL #32
    movk  x.t0, #65535, LSL #48
    adds  x.t1, x.acc0, #1
    sbcs  x.b3, x.acc1, x.bz
    sbcs  x.b2, x.acc2, xzr
    sbcs  x.b1,  x.acc3, x.t0
    sbcs  xzr, x.bp,  xzr
    csel  x.a0, x.acc0, x.t1, LO
    csel  x.a1, x.acc1, x.b3, LO
    csel  x.a2, x.acc2, x.b2, LO
    csel  x.a3, x.acc3, x.b1,  LO
    subs  x.t2, x.t2, #1
    b.ne  sqloop
    stp   x.a0, x.a1, [x.rp]
    stp   x.a2, x.a3, [x.rp, #16]
    ret
.end
