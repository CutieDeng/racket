/* rktcrypto_p256_hand.S — GENERATED; do not edit by hand.
   asmp .context source for the hand-scheduled P-256 point kernels (was the
   source-less rktcrypto_p256_hand.S). One `.context p256_field (scope library)`
   declares the OpenSSL-derived register-ABI contract ONCE — operand a in x4-x7,
   operand b in x8-x11, b[0] limb in x3, result acc in x14-x17, result ptr x0,
   src2 ptr x2, callee-saved frame regs x19/x21/x22 — replacing the former
   per-kernel hardcoded fixed-register ABI (review risk 4). The two frame kernels
   use `.save all` so asmp auto-generates the callee-saved prologue/epilogue,
   replacing the hand stp x19-x22 + hardcoded stack offsets (review risk 5). The
   hand instruction schedule is preserved bit-for-bit; only physical register
   names became `x.<field>`. The 128/352-byte scratch memory frames stay hand
   written (M3 `.frame` unimplemented) -> assemble with --allow-sp-writes.
   Assemble: cli/as.rkt --gnu-input --apple --elim --default-abi aapcs64
     --keep-comments --allow-sp-writes p256_hand.asm
   Gates: asm/tests/{test_p256_extra,test_mixed_add,test_mont_sqrn}.c each 0/200000.
   t0/t1/t2 (x1/x12/x13) ARE part of the cross-function register-ABI, not local
   scratch: jac_double_hw/mixed_add_hw call the helpers via 38 `bl`s with NO
   `.clobber` declarations, so the whole family shares one implicit contract —
   a helper touches only x4-x17 + x1/x12/x13 and preserves everything else, and
   the callers keep live values in the preserved registers across those calls.
   Pinning them in `.context` encodes that contract (§7.1: cross-function shared
   register-ABI → .context). Leaving them undeclared virtuals SEGFAULTS: asmp's
   allocator can't infer a bare `bl`'s clobber set, so it reassigns registers in
   ways that break the implicit caller/helper agreement (verified 2026-07-29).
   This whole kernel is deliberately hand-allocated (OpenSSL-parity schedule,
   asmp scheduler off for crypto per D1); asmp names/checks/regenerates it, and
   still block-reorders it (e.g. mixed_add's epilogue), but does not allocate it.
   Source: asm/p256_hand.asm
   rktasm 0d08901f47: cli/as.rkt --gnu-input --apple --elim --default-abi aapcs64 --keep-comments --allow-sp-writes
   Regenerate: asm/regen.sh regen p256_hand   (gates: asm/tests/ diff + BASELINE.md ±2%)
   AArch64 dual-branch: __APPLE__ = Apple/Mach-O body (--gnu-input --apple --elim --default-abi aapcs64 --keep-comments --allow-sp-writes),
   else = ELF/GNU body (same instructions, ELF symbol syntax). */
#if defined(__aarch64__)
# if defined(__APPLE__)
.text


.p2align 2
_p256_mul:
Lp256_mul$entry:
    ldr x12, [x2, #8]
    ldr x11, [x2, #16]
    ldr x17, [x2, #24]
    mul x14, x4, x3
    umulh x10, x4, x3
    mul x15, x5, x3
    umulh x9, x5, x3
    mul x16, x6, x3
    umulh x8, x6, x3
    mul x13, x7, x3
    umulh x2, x7, x3
    adds x15, x15, x10
    ubfm x10, x14, #32, #31
    adcs x16, x16, x9
    ubfm x9, x14, #32, #63
    adcs x13, x13, x8
    adc x3, xzr, x2
    mov x1, xzr
    subs x8, x14, x10
    sbc x2, x14, x9
    adds x14, x15, x10
    mul x10, x4, x12
    adcs x15, x16, x9
    mul x9, x5, x12
    adcs x16, x13, x8
    mul x8, x6, x12
    adcs x13, x3, x2
    mul x2, x7, x12
    adc x3, x1, xzr
    adds x14, x14, x10
    umulh x10, x4, x12
    adcs x15, x15, x9
    umulh x9, x5, x12
    adcs x16, x16, x8
    umulh x8, x6, x12
    adcs x13, x13, x2
    umulh x2, x7, x12
    adc x3, x3, xzr
    adds x15, x15, x10
    ubfm x10, x14, #32, #31
    adcs x16, x16, x9
    ubfm x9, x14, #32, #63
    adcs x13, x13, x8
    adcs x3, x3, x2
    adc x1, xzr, xzr
    subs x8, x14, x10
    sbc x2, x14, x9
    adds x14, x15, x10
    mul x10, x4, x11
    adcs x15, x16, x9
    mul x9, x5, x11
    adcs x16, x13, x8
    mul x8, x6, x11
    adcs x13, x3, x2
    mul x2, x7, x11
    adc x3, x1, xzr
    adds x14, x14, x10
    umulh x10, x4, x11
    adcs x15, x15, x9
    umulh x9, x5, x11
    adcs x16, x16, x8
    umulh x8, x6, x11
    adcs x13, x13, x2
    umulh x2, x7, x11
    adc x3, x3, xzr
    adds x15, x15, x10
    ubfm x10, x14, #32, #31
    adcs x16, x16, x9
    ubfm x9, x14, #32, #63
    adcs x13, x13, x8
    adcs x3, x3, x2
    adc x1, xzr, xzr
    subs x8, x14, x10
    sbc x2, x14, x9
    adds x14, x15, x10
    mul x10, x4, x17
    adcs x15, x16, x9
    mul x9, x5, x17
    adcs x16, x13, x8
    mul x8, x6, x17
    adcs x13, x3, x2
    mul x2, x7, x17
    adc x3, x1, xzr
    adds x14, x14, x10
    umulh x10, x4, x17
    adcs x15, x15, x9
    umulh x9, x5, x17
    adcs x16, x16, x8
    umulh x8, x6, x17
    adcs x13, x13, x2
    umulh x2, x7, x17
    adc x3, x3, xzr
    adds x15, x15, x10
    ubfm x10, x14, #32, #31
    adcs x16, x16, x9
    ubfm x9, x14, #32, #63
    adcs x13, x13, x8
    adcs x3, x3, x2
    adc x1, xzr, xzr
    subs x8, x14, x10
    sbc x2, x14, x9
    adds x14, x15, x10
    adcs x15, x16, x9
    adcs x16, x13, x8
    adcs x13, x3, x2
    adc x3, x1, xzr
    movz x2, #65535
    movk x2, #65535, LSL #16
    movz x1, #1
    movk x1, #65535, LSL #32
    movk x1, #65535, LSL #48
    adds x10, x14, #1
    sbcs x9, x15, x2
    sbcs x8, x16, xzr
    sbcs x2, x13, x1
    sbcs xzr, x3, xzr
    csel x14, x14, x10, LO
    csel x15, x15, x9, LO
    csel x16, x16, x8, LO
    csel x17, x13, x2, LO
    stp x14, x15, [x0]
    stp x16, x17, [x0, #16]
    ret

.p2align 2
_p256_sqr:
Lp256_sqr$entry:
    mul x15, x5, x4
    umulh x11, x5, x4
    mul x16, x6, x4
    umulh x10, x6, x4
    mul x17, x7, x4
    umulh x2, x7, x4
    adds x16, x16, x11
    mul x12, x6, x5
    umulh x11, x6, x5
    adcs x17, x17, x10
    mul x10, x7, x5
    umulh x9, x7, x5
    adc x2, x2, xzr
    mul x1, x7, x6
    umulh x8, x7, x6
    adds x11, x11, x10
    mul x14, x4, x4
    adc x10, x9, xzr
    adds x17, x17, x12
    umulh x4, x4, x4
    adcs x2, x2, x11
    mul x11, x5, x5
    adcs x1, x1, x10
    umulh x5, x5, x5
    adc x8, x8, xzr
    adds x15, x15, x15
    mul x10, x6, x6
    adcs x16, x16, x16
    umulh x6, x6, x6
    adcs x17, x17, x17
    mul x9, x7, x7
    adcs x2, x2, x2
    umulh x7, x7, x7
    adcs x1, x1, x1
    adcs x8, x8, x8
    adc x3, xzr, xzr
    adds x15, x15, x4
    adcs x16, x16, x11
    adcs x17, x17, x5
    adcs x2, x2, x10
    adcs x1, x1, x6
    ubfm x12, x14, #32, #31
    adcs x8, x8, x9
    ubfm x11, x14, #32, #63
    adc x3, x3, x7
    subs x10, x14, x12
    sbc x9, x14, x11
    adds x14, x15, x12
    adcs x15, x16, x11
    ubfm x12, x14, #32, #31
    adcs x16, x17, x10
    ubfm x11, x14, #32, #63
    adc x17, x9, xzr
    subs x10, x14, x12
    sbc x9, x14, x11
    adds x14, x15, x12
    adcs x15, x16, x11
    ubfm x12, x14, #32, #31
    adcs x16, x17, x10
    ubfm x11, x14, #32, #63
    adc x17, x9, xzr
    subs x10, x14, x12
    sbc x9, x14, x11
    adds x14, x15, x12
    adcs x15, x16, x11
    ubfm x12, x14, #32, #31
    adcs x16, x17, x10
    ubfm x11, x14, #32, #63
    adc x17, x9, xzr
    subs x10, x14, x12
    sbc x9, x14, x11
    adds x14, x15, x12
    adcs x15, x16, x11
    adcs x16, x17, x10
    adc x17, x9, xzr
    adds x14, x14, x2
    adcs x15, x15, x1
    adcs x16, x16, x8
    adcs x17, x17, x3
    adc x2, xzr, xzr
    movz x3, #65535
    movk x3, #65535, LSL #16
    movz x1, #1
    movk x1, #65535, LSL #32
    movk x1, #65535, LSL #48
    adds x12, x14, #1
    sbcs x11, x15, x3
    sbcs x10, x16, xzr
    sbcs x9, x17, x1
    sbcs xzr, x2, xzr
    csel x14, x14, x12, LO
    csel x15, x15, x11, LO
    csel x16, x16, x10, LO
    csel x17, x17, x9, LO
    stp x14, x15, [x0]
    stp x16, x17, [x0, #16]
    ret

.p2align 2
_p256_add:
Lp256_add$entry:
    adds x14, x14, x8
    adcs x15, x15, x9
    adcs x16, x16, x10
    adcs x17, x17, x11
    adc x10, xzr, xzr
    movn x8, #0
    movz x2, #65535
    movk x2, #65535, LSL #16
    movz x1, #1
    movk x1, #65535, LSL #32
    movk x1, #65535, LSL #48
    subs x9, x14, x8
    sbcs x8, x15, x2
    sbcs x2, x16, xzr
    sbcs x1, x17, x1
    sbcs xzr, x10, xzr
    csel x14, x9, x14, CS
    csel x15, x8, x15, CS
    csel x16, x2, x16, CS
    csel x17, x1, x17, CS
    str x14, [x0, #0]
    str x15, [x0, #8]
    str x16, [x0, #16]
    str x17, [x0, #24]
    ret

.p2align 2
_p256_sub_from:
Lp256_sub_from$entry:
    ldr x10, [x2, #0]
    ldr x9, [x2, #8]
    ldr x8, [x2, #16]
    ldr x1, [x2, #24]
    subs x14, x14, x10
    sbcs x15, x15, x9
    sbcs x16, x16, x8
    sbcs x17, x17, x1
    sbc x9, xzr, xzr
    movn x8, #0
    movz x2, #65535
    movk x2, #65535, LSL #16
    movz x1, #1
    movk x1, #65535, LSL #32
    movk x1, #65535, LSL #48
    and x8, x8, x9
    and x2, x2, x9
    and x1, x1, x9
    adds x14, x14, x8
    adcs x15, x15, x2
    adcs x16, x16, xzr
    adc x17, x17, x1
    str x14, [x0, #0]
    str x15, [x0, #8]
    str x16, [x0, #16]
    str x17, [x0, #24]
    ret

.p2align 2
_p256_sub_morf:
Lp256_sub_morf$entry:
    ldr x10, [x2, #0]
    ldr x9, [x2, #8]
    ldr x8, [x2, #16]
    ldr x1, [x2, #24]
    subs x14, x10, x14
    sbcs x15, x9, x15
    sbcs x16, x8, x16
    sbcs x17, x1, x17
    sbc x9, xzr, xzr
    movn x8, #0
    movz x2, #65535
    movk x2, #65535, LSL #16
    movz x1, #1
    movk x1, #65535, LSL #32
    movk x1, #65535, LSL #48
    and x8, x8, x9
    and x2, x2, x9
    and x1, x1, x9
    adds x14, x14, x8
    adcs x15, x15, x2
    adcs x16, x16, xzr
    adc x17, x17, x1
    str x14, [x0, #0]
    str x15, [x0, #8]
    str x16, [x0, #16]
    str x17, [x0, #24]
    ret

.p2align 2
_p256_div2:
Lp256_div2$entry:
    and x9, x14, #1
    neg x9, x9
    movn x8, #0
    movz x2, #65535
    movk x2, #65535, LSL #16
    movz x1, #1
    movk x1, #65535, LSL #32
    movk x1, #65535, LSL #48
    and x8, x8, x9
    and x2, x2, x9
    and x1, x1, x9
    adds x14, x14, x8
    adcs x15, x15, x2
    adcs x16, x16, xzr
    adcs x17, x17, x1
    adc x1, xzr, xzr
    extr x14, x15, x14, #1
    extr x15, x16, x15, #1
    extr x16, x17, x16, #1
    extr x17, x1, x17, #1
    str x14, [x0, #0]
    str x15, [x0, #8]
    str x16, [x0, #16]
    str x17, [x0, #24]
    ret

.globl _jac_double_hw
.p2align 2
_jac_double_hw:
Ljac_double_hw$entry:
    stp x29, x30, [sp, #-32]!
    stp x21, x22, [sp, #16]
    sub sp, sp, #128
    ldp x14, x15, [x1, #32]
    mov x21, x0
    ldp x16, x17, [x1, #48]
    mov x22, x1
    mov x8, x14
    mov x9, x15
    ldp x4, x5, [x22, #64]    ; forward load for p256_sqr_mont
    mov x10, x16
    mov x11, x17
    ldp x6, x7, [x22, #80]
    add x0, sp, #0
    bl _p256_add    ; p256_mul_by_2(S, in_y);
    add x0, sp, #64
    bl _p256_sqr    ; p256_sqr_mont(Zsqr, in_z);
    ldp x8, x9, [x22]
    ldp x10, x11, [x22, #16]
    mov x4, x14    ; put Zsqr aside for p256_sub
    mov x5, x15
    mov x6, x16
    mov x7, x17
    add x0, sp, #32
    bl _p256_add    ; p256_add(M, Zsqr, in_x);
    add x2, x22, #0
    mov x14, x4    ; restore Zsqr
    mov x15, x5
    ldp x4, x5, [sp, #0]    ; forward load for p256_sqr_mont
    mov x16, x6
    mov x17, x7
    ldp x6, x7, [sp, #16]
    add x0, sp, #64
    bl _p256_sub_morf    ; p256_sub(Zsqr, in_x, Zsqr);
    add x0, sp, #0
    bl _p256_sqr    ; p256_sqr_mont(S, S);
    ldr x3, [x22, #32]
    ldp x4, x5, [x22, #64]
    ldp x6, x7, [x22, #80]
    add x2, x22, #32
    add x0, sp, #96
    bl _p256_mul    ; p256_mul_mont(tmp0, in_z, in_y);
    mov x8, x14
    mov x9, x15
    ldp x4, x5, [sp, #0]    ; forward load for p256_sqr_mont
    mov x10, x16
    mov x11, x17
    ldp x6, x7, [sp, #16]
    add x0, x21, #64
    bl _p256_add    ; p256_mul_by_2(res_z, tmp0);
    add x0, sp, #96
    bl _p256_sqr    ; p256_sqr_mont(tmp0, S);
    ldr x3, [sp, #64]    ; forward load for p256_mul_mont
    ldp x4, x5, [sp, #32]
    ldp x6, x7, [sp, #48]
    add x0, x21, #32
    bl _p256_div2    ; p256_div_by_2(res_y, tmp0);
    add x2, sp, #64
    add x0, sp, #32
    bl _p256_mul    ; p256_mul_mont(M, M, Zsqr);
    mov x8, x14    ; duplicate M
    mov x9, x15
    mov x10, x16
    mov x11, x17
    mov x4, x14    ; put M aside
    mov x5, x15
    mov x6, x16
    mov x7, x17
    add x0, sp, #32
    bl _p256_add
    mov x8, x4    ; restore M
    mov x9, x5
    ldr x3, [x22]    ; forward load for p256_mul_mont
    mov x10, x6
    ldp x4, x5, [sp, #0]
    mov x11, x7
    ldp x6, x7, [sp, #16]
    bl _p256_add    ; p256_mul_by_3(M, M);
    add x2, x22, #0
    add x0, sp, #0
    bl _p256_mul    ; p256_mul_mont(S, S, in_x);
    mov x8, x14
    mov x9, x15
    ldp x4, x5, [sp, #32]    ; forward load for p256_sqr_mont
    mov x10, x16
    mov x11, x17
    ldp x6, x7, [sp, #48]
    add x0, sp, #96
    bl _p256_add    ; p256_mul_by_2(tmp0, S);
    add x0, x21, #0
    bl _p256_sqr    ; p256_sqr_mont(res_x, M);
    add x2, sp, #96
    bl _p256_sub_from    ; p256_sub(res_x, res_x, tmp0);
    add x2, sp, #0
    add x0, sp, #0
    bl _p256_sub_morf    ; p256_sub(S, S, res_x);
    ldr x3, [sp, #32]
    mov x4, x14    ; copy S
    mov x5, x15
    mov x6, x16
    mov x7, x17
    add x2, sp, #32
    bl _p256_mul    ; p256_mul_mont(S, S, M);
    add x2, x21, #32
    add x0, x21, #32
    bl _p256_sub_from    ; p256_sub(res_y, S, res_y);
    add sp, sp, #128
    ldp x21, x22, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

.globl _mixed_add_hw
.p2align 2
_mixed_add_hw:
Lmixed_add_hw$entry:
    stp x29, x30, [sp, #-48]!
    stp x19, x21, [sp, #16]
    str x22, [sp, #32]
    sub sp, sp, #352
    mov x21, x0    ; r
    mov x22, x1    ; p
    mov x19, x2    ; q
    ldp x8, x9, [x22, #64]
    ldp x10, x11, [x22, #80]
    orr x8, x8, x9
    orr x10, x10, x11
    orr x8, x8, x10
    cbnz x8, Lmixed_add_hw$Lma_main
    ldp x8, x9, [x19, #0]
    stp x8, x9, [x21, #0]
    ldp x8, x9, [x19, #16]
    stp x8, x9, [x21, #16]
    ldp x8, x9, [x19, #32]
    stp x8, x9, [x21, #32]
    ldp x8, x9, [x19, #48]
    stp x8, x9, [x21, #48]
    ldp x8, x9, [x19, #64]
    stp x8, x9, [x21, #64]
    ldp x8, x9, [x19, #80]
    stp x8, x9, [x21, #80]
Lmixed_add_hw$Lma_epi:
    add sp, sp, #352
    ldp x21, x22, [sp, #24]
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #48
    ret
Lmixed_add_hw$Lma_main:
    ldp x4, x5, [x22, #64]
    ldp x6, x7, [x22, #80]
    add x0, sp, #0
    bl _p256_sqr
    ldp x4, x5, [x19, #32]
    ldp x6, x7, [x19, #48]
    ldr x3, [x22, #64]
    add x2, x22, #64
    add x0, sp, #32
    bl _p256_mul
    ldp x4, x5, [x19, #0]
    ldp x6, x7, [x19, #16]
    ldr x3, [sp, #0]
    add x2, sp, #0
    add x0, sp, #64
    bl _p256_mul
    ldp x4, x5, [sp, #32]
    ldp x6, x7, [sp, #48]
    ldr x3, [sp, #0]
    add x2, x22, #0
    add x0, sp, #96
    bl _p256_sub_from
    add x2, sp, #0
    add x0, sp, #32
    bl _p256_mul
    ldp x4, x5, [sp, #96]
    ldp x6, x7, [sp, #112]
    add x2, x22, #32
    add x0, sp, #128
    bl _p256_sub_from
    orr x8, x14, x15
    orr x9, x16, x17
    orr x8, x8, x9    ; R != 0 ?
    ldp x10, x11, [sp, #96]
    ldp x12, x13, [sp, #112]
    orr x10, x10, x11
    orr x12, x12, x13
    orr x10, x10, x12    ; H != 0 ?
    cbnz x10, Lmixed_add_hw$Lma_cont
    cbnz x8, Lmixed_add_hw$Lma_inf
    mov x0, x21
    mov x1, x22
    bl _jac_double_hw
    b Lmixed_add_hw$Lma_epi
Lmixed_add_hw$Lma_inf:
    mov x8, #1
    stp x8, xzr, [x21, #0]
    stp xzr, xzr, [x21, #16]
    stp x8, xzr, [x21, #32]
    stp xzr, xzr, [x21, #48]
    stp xzr, xzr, [x21, #64]
    stp xzr, xzr, [x21, #80]
    b Lmixed_add_hw$Lma_epi
Lmixed_add_hw$Lma_cont:
    add x0, sp, #160
    bl _p256_sqr
    mov x4, x14
    mov x5, x15
    mov x6, x16
    mov x7, x17
    ldr x3, [sp, #96]
    add x2, sp, #96
    add x0, sp, #192
    bl _p256_mul
    ldp x4, x5, [x22, #0]
    ldp x6, x7, [x22, #16]
    ldr x3, [sp, #160]
    add x2, sp, #160
    add x0, sp, #224
    bl _p256_mul
    ldp x4, x5, [sp, #128]
    ldp x6, x7, [sp, #144]
    add x0, sp, #256
    bl _p256_sqr
    ldp x4, x5, [x22, #32]
    ldp x6, x7, [x22, #48]
    ldr x3, [sp, #192]
    add x2, sp, #192
    add x0, sp, #256
    bl _p256_sub_from
    add x2, sp, #224
    add x0, sp, #256
    bl _p256_sub_from
    add x2, sp, #224
    add x0, sp, #256
    bl _p256_sub_from
    add x2, sp, #192
    add x0, sp, #288
    bl _p256_mul
    ldp x4, x5, [x22, #64]
    ldp x6, x7, [x22, #80]
    ldr x3, [sp, #96]
    add x2, sp, #96
    add x0, x21, #64
    bl _p256_mul
    ldp x14, x15, [sp, #224]
    ldp x16, x17, [sp, #240]
    add x2, sp, #256
    add x0, sp, #320
    bl _p256_sub_from
    ldp x4, x5, [sp, #128]
    ldp x6, x7, [sp, #144]
    ldr x3, [sp, #320]
    add x2, sp, #320
    add x0, sp, #320
    bl _p256_mul
    add x2, sp, #288
    add x0, x21, #32
    bl _p256_sub_from
    ldp x8, x9, [sp, #256]
    ldp x10, x11, [sp, #272]
    stp x8, x9, [x21, #0]
    stp x10, x11, [x21, #16]
    b Lmixed_add_hw$Lma_epi

.globl _mont_sqrn_p256
.p2align 2
_mont_sqrn_p256:
Lmont_sqrn_p256$entry:
    ldr x4, [x1, #0]
    ldr x5, [x1, #8]
    ldr x6, [x1, #16]
    ldr x7, [x1, #24]
    mov x13, x2
Lmont_sqrn_p256$sqloop:
    mul x15, x5, x4
    umulh x11, x5, x4
    mul x16, x6, x4
    umulh x10, x6, x4
    mul x17, x7, x4
    umulh x2, x7, x4
    adds x16, x16, x11
    mul x12, x6, x5
    umulh x11, x6, x5
    adcs x17, x17, x10
    mul x10, x7, x5
    umulh x9, x7, x5
    adc x2, x2, xzr
    mul x1, x7, x6
    umulh x8, x7, x6
    adds x11, x11, x10
    mul x14, x4, x4
    adc x10, x9, xzr
    adds x17, x17, x12
    umulh x4, x4, x4
    adcs x2, x2, x11
    mul x11, x5, x5
    adcs x1, x1, x10
    umulh x5, x5, x5
    adc x8, x8, xzr
    adds x15, x15, x15
    mul x10, x6, x6
    adcs x16, x16, x16
    umulh x6, x6, x6
    adcs x17, x17, x17
    mul x9, x7, x7
    adcs x2, x2, x2
    umulh x7, x7, x7
    adcs x1, x1, x1
    adcs x8, x8, x8
    adc x3, xzr, xzr
    adds x15, x15, x4
    adcs x16, x16, x11
    adcs x17, x17, x5
    adcs x2, x2, x10
    adcs x1, x1, x6
    ubfm x12, x14, #32, #31
    adcs x8, x8, x9
    ubfm x11, x14, #32, #63
    adc x3, x3, x7
    subs x10, x14, x12
    sbc x9, x14, x11
    adds x14, x15, x12
    adcs x15, x16, x11
    ubfm x12, x14, #32, #31
    adcs x16, x17, x10
    ubfm x11, x14, #32, #63
    adc x17, x9, xzr
    subs x10, x14, x12
    sbc x9, x14, x11
    adds x14, x15, x12
    adcs x15, x16, x11
    ubfm x12, x14, #32, #31
    adcs x16, x17, x10
    ubfm x11, x14, #32, #63
    adc x17, x9, xzr
    subs x10, x14, x12
    sbc x9, x14, x11
    adds x14, x15, x12
    adcs x15, x16, x11
    ubfm x12, x14, #32, #31
    adcs x16, x17, x10
    ubfm x11, x14, #32, #63
    adc x17, x9, xzr
    subs x10, x14, x12
    sbc x9, x14, x11
    adds x14, x15, x12
    adcs x15, x16, x11
    adcs x16, x17, x10
    adc x17, x9, xzr
    adds x14, x14, x2
    adcs x15, x15, x1
    adcs x16, x16, x8
    adcs x17, x17, x3
    adc x2, xzr, xzr
    movz x3, #65535
    movk x3, #65535, LSL #16
    movz x1, #1
    movk x1, #65535, LSL #32
    movk x1, #65535, LSL #48
    adds x12, x14, #1
    sbcs x11, x15, x3
    sbcs x10, x16, xzr
    sbcs x9, x17, x1
    sbcs xzr, x2, xzr
    csel x4, x14, x12, LO
    csel x5, x15, x11, LO
    csel x6, x16, x10, LO
    csel x7, x17, x9, LO
    subs x13, x13, #1
    b.ne Lmont_sqrn_p256$sqloop
    stp x4, x5, [x0]
    stp x6, x7, [x0, #16]
    ret

.subsections_via_symbols
# else
// Generated by asmp
// Syntax: gnu

.text


.p2align 2
p256_mul:
Lp256_mul$entry:
    ldr x12, [x2, #8]
    ldr x11, [x2, #16]
    ldr x17, [x2, #24]
    mul x14, x4, x3
    umulh x10, x4, x3
    mul x15, x5, x3
    umulh x9, x5, x3
    mul x16, x6, x3
    umulh x8, x6, x3
    mul x13, x7, x3
    umulh x2, x7, x3
    adds x15, x15, x10
    ubfm x10, x14, #32, #31
    adcs x16, x16, x9
    ubfm x9, x14, #32, #63
    adcs x13, x13, x8
    adc x3, xzr, x2
    mov x1, xzr
    subs x8, x14, x10
    sbc x2, x14, x9
    adds x14, x15, x10
    mul x10, x4, x12
    adcs x15, x16, x9
    mul x9, x5, x12
    adcs x16, x13, x8
    mul x8, x6, x12
    adcs x13, x3, x2
    mul x2, x7, x12
    adc x3, x1, xzr
    adds x14, x14, x10
    umulh x10, x4, x12
    adcs x15, x15, x9
    umulh x9, x5, x12
    adcs x16, x16, x8
    umulh x8, x6, x12
    adcs x13, x13, x2
    umulh x2, x7, x12
    adc x3, x3, xzr
    adds x15, x15, x10
    ubfm x10, x14, #32, #31
    adcs x16, x16, x9
    ubfm x9, x14, #32, #63
    adcs x13, x13, x8
    adcs x3, x3, x2
    adc x1, xzr, xzr
    subs x8, x14, x10
    sbc x2, x14, x9
    adds x14, x15, x10
    mul x10, x4, x11
    adcs x15, x16, x9
    mul x9, x5, x11
    adcs x16, x13, x8
    mul x8, x6, x11
    adcs x13, x3, x2
    mul x2, x7, x11
    adc x3, x1, xzr
    adds x14, x14, x10
    umulh x10, x4, x11
    adcs x15, x15, x9
    umulh x9, x5, x11
    adcs x16, x16, x8
    umulh x8, x6, x11
    adcs x13, x13, x2
    umulh x2, x7, x11
    adc x3, x3, xzr
    adds x15, x15, x10
    ubfm x10, x14, #32, #31
    adcs x16, x16, x9
    ubfm x9, x14, #32, #63
    adcs x13, x13, x8
    adcs x3, x3, x2
    adc x1, xzr, xzr
    subs x8, x14, x10
    sbc x2, x14, x9
    adds x14, x15, x10
    mul x10, x4, x17
    adcs x15, x16, x9
    mul x9, x5, x17
    adcs x16, x13, x8
    mul x8, x6, x17
    adcs x13, x3, x2
    mul x2, x7, x17
    adc x3, x1, xzr
    adds x14, x14, x10
    umulh x10, x4, x17
    adcs x15, x15, x9
    umulh x9, x5, x17
    adcs x16, x16, x8
    umulh x8, x6, x17
    adcs x13, x13, x2
    umulh x2, x7, x17
    adc x3, x3, xzr
    adds x15, x15, x10
    ubfm x10, x14, #32, #31
    adcs x16, x16, x9
    ubfm x9, x14, #32, #63
    adcs x13, x13, x8
    adcs x3, x3, x2
    adc x1, xzr, xzr
    subs x8, x14, x10
    sbc x2, x14, x9
    adds x14, x15, x10
    adcs x15, x16, x9
    adcs x16, x13, x8
    adcs x13, x3, x2
    adc x3, x1, xzr
    movz x2, #65535
    movk x2, #65535, LSL #16
    movz x1, #1
    movk x1, #65535, LSL #32
    movk x1, #65535, LSL #48
    adds x10, x14, #1
    sbcs x9, x15, x2
    sbcs x8, x16, xzr
    sbcs x2, x13, x1
    sbcs xzr, x3, xzr
    csel x14, x14, x10, LO
    csel x15, x15, x9, LO
    csel x16, x16, x8, LO
    csel x17, x13, x2, LO
    stp x14, x15, [x0]
    stp x16, x17, [x0, #16]
    ret

.p2align 2
p256_sqr:
Lp256_sqr$entry:
    mul x15, x5, x4
    umulh x11, x5, x4
    mul x16, x6, x4
    umulh x10, x6, x4
    mul x17, x7, x4
    umulh x2, x7, x4
    adds x16, x16, x11
    mul x12, x6, x5
    umulh x11, x6, x5
    adcs x17, x17, x10
    mul x10, x7, x5
    umulh x9, x7, x5
    adc x2, x2, xzr
    mul x1, x7, x6
    umulh x8, x7, x6
    adds x11, x11, x10
    mul x14, x4, x4
    adc x10, x9, xzr
    adds x17, x17, x12
    umulh x4, x4, x4
    adcs x2, x2, x11
    mul x11, x5, x5
    adcs x1, x1, x10
    umulh x5, x5, x5
    adc x8, x8, xzr
    adds x15, x15, x15
    mul x10, x6, x6
    adcs x16, x16, x16
    umulh x6, x6, x6
    adcs x17, x17, x17
    mul x9, x7, x7
    adcs x2, x2, x2
    umulh x7, x7, x7
    adcs x1, x1, x1
    adcs x8, x8, x8
    adc x3, xzr, xzr
    adds x15, x15, x4
    adcs x16, x16, x11
    adcs x17, x17, x5
    adcs x2, x2, x10
    adcs x1, x1, x6
    ubfm x12, x14, #32, #31
    adcs x8, x8, x9
    ubfm x11, x14, #32, #63
    adc x3, x3, x7
    subs x10, x14, x12
    sbc x9, x14, x11
    adds x14, x15, x12
    adcs x15, x16, x11
    ubfm x12, x14, #32, #31
    adcs x16, x17, x10
    ubfm x11, x14, #32, #63
    adc x17, x9, xzr
    subs x10, x14, x12
    sbc x9, x14, x11
    adds x14, x15, x12
    adcs x15, x16, x11
    ubfm x12, x14, #32, #31
    adcs x16, x17, x10
    ubfm x11, x14, #32, #63
    adc x17, x9, xzr
    subs x10, x14, x12
    sbc x9, x14, x11
    adds x14, x15, x12
    adcs x15, x16, x11
    ubfm x12, x14, #32, #31
    adcs x16, x17, x10
    ubfm x11, x14, #32, #63
    adc x17, x9, xzr
    subs x10, x14, x12
    sbc x9, x14, x11
    adds x14, x15, x12
    adcs x15, x16, x11
    adcs x16, x17, x10
    adc x17, x9, xzr
    adds x14, x14, x2
    adcs x15, x15, x1
    adcs x16, x16, x8
    adcs x17, x17, x3
    adc x2, xzr, xzr
    movz x3, #65535
    movk x3, #65535, LSL #16
    movz x1, #1
    movk x1, #65535, LSL #32
    movk x1, #65535, LSL #48
    adds x12, x14, #1
    sbcs x11, x15, x3
    sbcs x10, x16, xzr
    sbcs x9, x17, x1
    sbcs xzr, x2, xzr
    csel x14, x14, x12, LO
    csel x15, x15, x11, LO
    csel x16, x16, x10, LO
    csel x17, x17, x9, LO
    stp x14, x15, [x0]
    stp x16, x17, [x0, #16]
    ret

.p2align 2
p256_add:
Lp256_add$entry:
    adds x14, x14, x8
    adcs x15, x15, x9
    adcs x16, x16, x10
    adcs x17, x17, x11
    adc x10, xzr, xzr
    movn x8, #0
    movz x2, #65535
    movk x2, #65535, LSL #16
    movz x1, #1
    movk x1, #65535, LSL #32
    movk x1, #65535, LSL #48
    subs x9, x14, x8
    sbcs x8, x15, x2
    sbcs x2, x16, xzr
    sbcs x1, x17, x1
    sbcs xzr, x10, xzr
    csel x14, x9, x14, CS
    csel x15, x8, x15, CS
    csel x16, x2, x16, CS
    csel x17, x1, x17, CS
    str x14, [x0, #0]
    str x15, [x0, #8]
    str x16, [x0, #16]
    str x17, [x0, #24]
    ret

.p2align 2
p256_sub_from:
Lp256_sub_from$entry:
    ldr x10, [x2, #0]
    ldr x9, [x2, #8]
    ldr x8, [x2, #16]
    ldr x1, [x2, #24]
    subs x14, x14, x10
    sbcs x15, x15, x9
    sbcs x16, x16, x8
    sbcs x17, x17, x1
    sbc x9, xzr, xzr
    movn x8, #0
    movz x2, #65535
    movk x2, #65535, LSL #16
    movz x1, #1
    movk x1, #65535, LSL #32
    movk x1, #65535, LSL #48
    and x8, x8, x9
    and x2, x2, x9
    and x1, x1, x9
    adds x14, x14, x8
    adcs x15, x15, x2
    adcs x16, x16, xzr
    adc x17, x17, x1
    str x14, [x0, #0]
    str x15, [x0, #8]
    str x16, [x0, #16]
    str x17, [x0, #24]
    ret

.p2align 2
p256_sub_morf:
Lp256_sub_morf$entry:
    ldr x10, [x2, #0]
    ldr x9, [x2, #8]
    ldr x8, [x2, #16]
    ldr x1, [x2, #24]
    subs x14, x10, x14
    sbcs x15, x9, x15
    sbcs x16, x8, x16
    sbcs x17, x1, x17
    sbc x9, xzr, xzr
    movn x8, #0
    movz x2, #65535
    movk x2, #65535, LSL #16
    movz x1, #1
    movk x1, #65535, LSL #32
    movk x1, #65535, LSL #48
    and x8, x8, x9
    and x2, x2, x9
    and x1, x1, x9
    adds x14, x14, x8
    adcs x15, x15, x2
    adcs x16, x16, xzr
    adc x17, x17, x1
    str x14, [x0, #0]
    str x15, [x0, #8]
    str x16, [x0, #16]
    str x17, [x0, #24]
    ret

.p2align 2
p256_div2:
Lp256_div2$entry:
    and x9, x14, #1
    neg x9, x9
    movn x8, #0
    movz x2, #65535
    movk x2, #65535, LSL #16
    movz x1, #1
    movk x1, #65535, LSL #32
    movk x1, #65535, LSL #48
    and x8, x8, x9
    and x2, x2, x9
    and x1, x1, x9
    adds x14, x14, x8
    adcs x15, x15, x2
    adcs x16, x16, xzr
    adcs x17, x17, x1
    adc x1, xzr, xzr
    extr x14, x15, x14, #1
    extr x15, x16, x15, #1
    extr x16, x17, x16, #1
    extr x17, x1, x17, #1
    str x14, [x0, #0]
    str x15, [x0, #8]
    str x16, [x0, #16]
    str x17, [x0, #24]
    ret

.globl jac_double_hw
.p2align 2
jac_double_hw:
Ljac_double_hw$entry:
    stp x29, x30, [sp, #-32]!
    stp x21, x22, [sp, #16]
    sub sp, sp, #128
    ldp x14, x15, [x1, #32]
    mov x21, x0
    ldp x16, x17, [x1, #48]
    mov x22, x1
    mov x8, x14
    mov x9, x15
    ldp x4, x5, [x22, #64]    // forward load for p256_sqr_mont
    mov x10, x16
    mov x11, x17
    ldp x6, x7, [x22, #80]
    add x0, sp, #0
    bl p256_add    // p256_mul_by_2(S, in_y);
    add x0, sp, #64
    bl p256_sqr    // p256_sqr_mont(Zsqr, in_z);
    ldp x8, x9, [x22]
    ldp x10, x11, [x22, #16]
    mov x4, x14    // put Zsqr aside for p256_sub
    mov x5, x15
    mov x6, x16
    mov x7, x17
    add x0, sp, #32
    bl p256_add    // p256_add(M, Zsqr, in_x);
    add x2, x22, #0
    mov x14, x4    // restore Zsqr
    mov x15, x5
    ldp x4, x5, [sp, #0]    // forward load for p256_sqr_mont
    mov x16, x6
    mov x17, x7
    ldp x6, x7, [sp, #16]
    add x0, sp, #64
    bl p256_sub_morf    // p256_sub(Zsqr, in_x, Zsqr);
    add x0, sp, #0
    bl p256_sqr    // p256_sqr_mont(S, S);
    ldr x3, [x22, #32]
    ldp x4, x5, [x22, #64]
    ldp x6, x7, [x22, #80]
    add x2, x22, #32
    add x0, sp, #96
    bl p256_mul    // p256_mul_mont(tmp0, in_z, in_y);
    mov x8, x14
    mov x9, x15
    ldp x4, x5, [sp, #0]    // forward load for p256_sqr_mont
    mov x10, x16
    mov x11, x17
    ldp x6, x7, [sp, #16]
    add x0, x21, #64
    bl p256_add    // p256_mul_by_2(res_z, tmp0);
    add x0, sp, #96
    bl p256_sqr    // p256_sqr_mont(tmp0, S);
    ldr x3, [sp, #64]    // forward load for p256_mul_mont
    ldp x4, x5, [sp, #32]
    ldp x6, x7, [sp, #48]
    add x0, x21, #32
    bl p256_div2    // p256_div_by_2(res_y, tmp0);
    add x2, sp, #64
    add x0, sp, #32
    bl p256_mul    // p256_mul_mont(M, M, Zsqr);
    mov x8, x14    // duplicate M
    mov x9, x15
    mov x10, x16
    mov x11, x17
    mov x4, x14    // put M aside
    mov x5, x15
    mov x6, x16
    mov x7, x17
    add x0, sp, #32
    bl p256_add
    mov x8, x4    // restore M
    mov x9, x5
    ldr x3, [x22]    // forward load for p256_mul_mont
    mov x10, x6
    ldp x4, x5, [sp, #0]
    mov x11, x7
    ldp x6, x7, [sp, #16]
    bl p256_add    // p256_mul_by_3(M, M);
    add x2, x22, #0
    add x0, sp, #0
    bl p256_mul    // p256_mul_mont(S, S, in_x);
    mov x8, x14
    mov x9, x15
    ldp x4, x5, [sp, #32]    // forward load for p256_sqr_mont
    mov x10, x16
    mov x11, x17
    ldp x6, x7, [sp, #48]
    add x0, sp, #96
    bl p256_add    // p256_mul_by_2(tmp0, S);
    add x0, x21, #0
    bl p256_sqr    // p256_sqr_mont(res_x, M);
    add x2, sp, #96
    bl p256_sub_from    // p256_sub(res_x, res_x, tmp0);
    add x2, sp, #0
    add x0, sp, #0
    bl p256_sub_morf    // p256_sub(S, S, res_x);
    ldr x3, [sp, #32]
    mov x4, x14    // copy S
    mov x5, x15
    mov x6, x16
    mov x7, x17
    add x2, sp, #32
    bl p256_mul    // p256_mul_mont(S, S, M);
    add x2, x21, #32
    add x0, x21, #32
    bl p256_sub_from    // p256_sub(res_y, S, res_y);
    add sp, sp, #128
    ldp x21, x22, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

.globl mixed_add_hw
.p2align 2
mixed_add_hw:
Lmixed_add_hw$entry:
    stp x29, x30, [sp, #-48]!
    stp x19, x21, [sp, #16]
    str x22, [sp, #32]
    sub sp, sp, #352
    mov x21, x0    // r
    mov x22, x1    // p
    mov x19, x2    // q
    ldp x8, x9, [x22, #64]
    ldp x10, x11, [x22, #80]
    orr x8, x8, x9
    orr x10, x10, x11
    orr x8, x8, x10
    cbnz x8, Lmixed_add_hw$Lma_main
    ldp x8, x9, [x19, #0]
    stp x8, x9, [x21, #0]
    ldp x8, x9, [x19, #16]
    stp x8, x9, [x21, #16]
    ldp x8, x9, [x19, #32]
    stp x8, x9, [x21, #32]
    ldp x8, x9, [x19, #48]
    stp x8, x9, [x21, #48]
    ldp x8, x9, [x19, #64]
    stp x8, x9, [x21, #64]
    ldp x8, x9, [x19, #80]
    stp x8, x9, [x21, #80]
Lmixed_add_hw$Lma_epi:
    add sp, sp, #352
    ldp x21, x22, [sp, #24]
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #48
    ret
Lmixed_add_hw$Lma_main:
    ldp x4, x5, [x22, #64]
    ldp x6, x7, [x22, #80]
    add x0, sp, #0
    bl p256_sqr
    ldp x4, x5, [x19, #32]
    ldp x6, x7, [x19, #48]
    ldr x3, [x22, #64]
    add x2, x22, #64
    add x0, sp, #32
    bl p256_mul
    ldp x4, x5, [x19, #0]
    ldp x6, x7, [x19, #16]
    ldr x3, [sp, #0]
    add x2, sp, #0
    add x0, sp, #64
    bl p256_mul
    ldp x4, x5, [sp, #32]
    ldp x6, x7, [sp, #48]
    ldr x3, [sp, #0]
    add x2, x22, #0
    add x0, sp, #96
    bl p256_sub_from
    add x2, sp, #0
    add x0, sp, #32
    bl p256_mul
    ldp x4, x5, [sp, #96]
    ldp x6, x7, [sp, #112]
    add x2, x22, #32
    add x0, sp, #128
    bl p256_sub_from
    orr x8, x14, x15
    orr x9, x16, x17
    orr x8, x8, x9    // R != 0 ?
    ldp x10, x11, [sp, #96]
    ldp x12, x13, [sp, #112]
    orr x10, x10, x11
    orr x12, x12, x13
    orr x10, x10, x12    // H != 0 ?
    cbnz x10, Lmixed_add_hw$Lma_cont
    cbnz x8, Lmixed_add_hw$Lma_inf
    mov x0, x21
    mov x1, x22
    bl jac_double_hw
    b Lmixed_add_hw$Lma_epi
Lmixed_add_hw$Lma_inf:
    mov x8, #1
    stp x8, xzr, [x21, #0]
    stp xzr, xzr, [x21, #16]
    stp x8, xzr, [x21, #32]
    stp xzr, xzr, [x21, #48]
    stp xzr, xzr, [x21, #64]
    stp xzr, xzr, [x21, #80]
    b Lmixed_add_hw$Lma_epi
Lmixed_add_hw$Lma_cont:
    add x0, sp, #160
    bl p256_sqr
    mov x4, x14
    mov x5, x15
    mov x6, x16
    mov x7, x17
    ldr x3, [sp, #96]
    add x2, sp, #96
    add x0, sp, #192
    bl p256_mul
    ldp x4, x5, [x22, #0]
    ldp x6, x7, [x22, #16]
    ldr x3, [sp, #160]
    add x2, sp, #160
    add x0, sp, #224
    bl p256_mul
    ldp x4, x5, [sp, #128]
    ldp x6, x7, [sp, #144]
    add x0, sp, #256
    bl p256_sqr
    ldp x4, x5, [x22, #32]
    ldp x6, x7, [x22, #48]
    ldr x3, [sp, #192]
    add x2, sp, #192
    add x0, sp, #256
    bl p256_sub_from
    add x2, sp, #224
    add x0, sp, #256
    bl p256_sub_from
    add x2, sp, #224
    add x0, sp, #256
    bl p256_sub_from
    add x2, sp, #192
    add x0, sp, #288
    bl p256_mul
    ldp x4, x5, [x22, #64]
    ldp x6, x7, [x22, #80]
    ldr x3, [sp, #96]
    add x2, sp, #96
    add x0, x21, #64
    bl p256_mul
    ldp x14, x15, [sp, #224]
    ldp x16, x17, [sp, #240]
    add x2, sp, #256
    add x0, sp, #320
    bl p256_sub_from
    ldp x4, x5, [sp, #128]
    ldp x6, x7, [sp, #144]
    ldr x3, [sp, #320]
    add x2, sp, #320
    add x0, sp, #320
    bl p256_mul
    add x2, sp, #288
    add x0, x21, #32
    bl p256_sub_from
    ldp x8, x9, [sp, #256]
    ldp x10, x11, [sp, #272]
    stp x8, x9, [x21, #0]
    stp x10, x11, [x21, #16]
    b Lmixed_add_hw$Lma_epi

.globl mont_sqrn_p256
.p2align 2
mont_sqrn_p256:
Lmont_sqrn_p256$entry:
    ldr x4, [x1, #0]
    ldr x5, [x1, #8]
    ldr x6, [x1, #16]
    ldr x7, [x1, #24]
    mov x13, x2
Lmont_sqrn_p256$sqloop:
    mul x15, x5, x4
    umulh x11, x5, x4
    mul x16, x6, x4
    umulh x10, x6, x4
    mul x17, x7, x4
    umulh x2, x7, x4
    adds x16, x16, x11
    mul x12, x6, x5
    umulh x11, x6, x5
    adcs x17, x17, x10
    mul x10, x7, x5
    umulh x9, x7, x5
    adc x2, x2, xzr
    mul x1, x7, x6
    umulh x8, x7, x6
    adds x11, x11, x10
    mul x14, x4, x4
    adc x10, x9, xzr
    adds x17, x17, x12
    umulh x4, x4, x4
    adcs x2, x2, x11
    mul x11, x5, x5
    adcs x1, x1, x10
    umulh x5, x5, x5
    adc x8, x8, xzr
    adds x15, x15, x15
    mul x10, x6, x6
    adcs x16, x16, x16
    umulh x6, x6, x6
    adcs x17, x17, x17
    mul x9, x7, x7
    adcs x2, x2, x2
    umulh x7, x7, x7
    adcs x1, x1, x1
    adcs x8, x8, x8
    adc x3, xzr, xzr
    adds x15, x15, x4
    adcs x16, x16, x11
    adcs x17, x17, x5
    adcs x2, x2, x10
    adcs x1, x1, x6
    ubfm x12, x14, #32, #31
    adcs x8, x8, x9
    ubfm x11, x14, #32, #63
    adc x3, x3, x7
    subs x10, x14, x12
    sbc x9, x14, x11
    adds x14, x15, x12
    adcs x15, x16, x11
    ubfm x12, x14, #32, #31
    adcs x16, x17, x10
    ubfm x11, x14, #32, #63
    adc x17, x9, xzr
    subs x10, x14, x12
    sbc x9, x14, x11
    adds x14, x15, x12
    adcs x15, x16, x11
    ubfm x12, x14, #32, #31
    adcs x16, x17, x10
    ubfm x11, x14, #32, #63
    adc x17, x9, xzr
    subs x10, x14, x12
    sbc x9, x14, x11
    adds x14, x15, x12
    adcs x15, x16, x11
    ubfm x12, x14, #32, #31
    adcs x16, x17, x10
    ubfm x11, x14, #32, #63
    adc x17, x9, xzr
    subs x10, x14, x12
    sbc x9, x14, x11
    adds x14, x15, x12
    adcs x15, x16, x11
    adcs x16, x17, x10
    adc x17, x9, xzr
    adds x14, x14, x2
    adcs x15, x15, x1
    adcs x16, x16, x8
    adcs x17, x17, x3
    adc x2, xzr, xzr
    movz x3, #65535
    movk x3, #65535, LSL #16
    movz x1, #1
    movk x1, #65535, LSL #32
    movk x1, #65535, LSL #48
    adds x12, x14, #1
    sbcs x11, x15, x3
    sbcs x10, x16, xzr
    sbcs x9, x17, x1
    sbcs xzr, x2, xzr
    csel x4, x14, x12, LO
    csel x5, x15, x11, LO
    csel x6, x16, x10, LO
    csel x7, x17, x9, LO
    subs x13, x13, #1
    b.ne Lmont_sqrn_p256$sqloop
    stp x4, x5, [x0]
    stp x6, x7, [x0, #16]
    ret
# endif
#endif
