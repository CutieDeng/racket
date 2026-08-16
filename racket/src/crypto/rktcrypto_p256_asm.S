/* rktcrypto_p256_asm.S — GENERATED; do not edit by hand.
   Source: asm/mont_mul.asm asm/mont_mul_p256.asm asm/mont_sqrn.asm
   rktasm 0d08901f47: cli/as.rkt --gnu-input --apple --elim --default-abi aapcs64 --keep-comments --allow-sp-writes
   Regenerate: asm/regen.sh regen p256   (gates: asm/tests/ diff + BASELINE.md ±2%)
   AArch64 dual-branch: __APPLE__ = Apple/Mach-O body (--gnu-input --apple --elim --default-abi aapcs64 --keep-comments --allow-sp-writes),
   else = ELF/GNU body (same instructions, ELF symbol syntax). */
#if defined(__aarch64__)
# if defined(__APPLE__)
.text
.globl _mont_mul_asm
.p2align 2
_mont_mul_asm:
Lmont_mul_asm$entry:
    stp x29, x30, [sp, #-80]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    ldr x25, [x1, #0]
    ldr x24, [x1, #8]
    ldr x23, [x1, #16]
    ldr x26, [x1, #24]
    ldr x1, [x2, #0]
    ldr x14, [x2, #8]
    ldr x13, [x2, #16]
    ldr x12, [x2, #24]
    ldr x11, [x3, #0]
    ldr x10, [x3, #8]
    ldr x9, [x3, #16]
    ldr x8, [x3, #24]
    ldr x6, [x3, #32]
    mul x22, x25, x1
    mul x21, x24, x1
    mul x20, x23, x1
    mul x19, x26, x1
    umulh x5, x25, x1
    umulh x4, x24, x1
    umulh x3, x23, x1
    umulh x2, x26, x1
    adds x21, x21, x5
    adcs x20, x20, x4
    adcs x19, x19, x3
    adc x15, xzr, x2
    mov x1, xzr
    mul x7, x22, x6
    mul x5, x7, x11
    mul x4, x7, x10
    mul x3, x7, x9
    mul x2, x7, x8
    adds x22, x22, x5
    adcs x21, x21, x4
    adcs x20, x20, x3
    adcs x19, x19, x2
    adcs x15, x15, xzr
    adc x1, x1, xzr
    umulh x5, x7, x11
    umulh x4, x7, x10
    umulh x3, x7, x9
    umulh x2, x7, x8
    adds x22, x21, x5
    adcs x21, x20, x4
    adcs x20, x19, x3
    adcs x19, x15, x2
    adc x15, x1, xzr
    mul x5, x25, x14
    mul x4, x24, x14
    mul x3, x23, x14
    mul x2, x26, x14
    adds x22, x22, x5
    adcs x21, x21, x4
    adcs x20, x20, x3
    adcs x19, x19, x2
    adc x15, x15, xzr
    umulh x5, x25, x14
    umulh x4, x24, x14
    umulh x3, x23, x14
    umulh x2, x26, x14
    adds x21, x21, x5
    adcs x20, x20, x4
    adcs x19, x19, x3
    adcs x15, x15, x2
    adc x1, xzr, xzr
    mul x7, x22, x6
    mul x5, x7, x11
    mul x4, x7, x10
    mul x3, x7, x9
    mul x2, x7, x8
    adds x22, x22, x5
    adcs x21, x21, x4
    adcs x20, x20, x3
    adcs x19, x19, x2
    adcs x15, x15, xzr
    adc x1, x1, xzr
    umulh x5, x7, x11
    umulh x4, x7, x10
    umulh x3, x7, x9
    umulh x2, x7, x8
    adds x22, x21, x5
    adcs x21, x20, x4
    adcs x20, x19, x3
    adcs x19, x15, x2
    adc x15, x1, xzr
    mul x5, x25, x13
    mul x4, x24, x13
    mul x3, x23, x13
    mul x2, x26, x13
    adds x22, x22, x5
    adcs x21, x21, x4
    adcs x20, x20, x3
    adcs x19, x19, x2
    adc x15, x15, xzr
    umulh x5, x25, x13
    umulh x4, x24, x13
    umulh x3, x23, x13
    umulh x2, x26, x13
    adds x21, x21, x5
    adcs x20, x20, x4
    adcs x19, x19, x3
    adcs x15, x15, x2
    adc x1, xzr, xzr
    mul x7, x22, x6
    mul x5, x7, x11
    mul x4, x7, x10
    mul x3, x7, x9
    mul x2, x7, x8
    adds x22, x22, x5
    adcs x21, x21, x4
    adcs x20, x20, x3
    adcs x19, x19, x2
    adcs x15, x15, xzr
    adc x1, x1, xzr
    umulh x5, x7, x11
    umulh x4, x7, x10
    umulh x3, x7, x9
    umulh x2, x7, x8
    adds x22, x21, x5
    adcs x21, x20, x4
    adcs x20, x19, x3
    adcs x19, x15, x2
    adc x15, x1, xzr
    mul x5, x25, x12
    mul x4, x24, x12
    mul x3, x23, x12
    mul x2, x26, x12
    adds x22, x22, x5
    adcs x21, x21, x4
    adcs x20, x20, x3
    adcs x19, x19, x2
    adc x15, x15, xzr
    umulh x5, x25, x12
    umulh x4, x24, x12
    umulh x3, x23, x12
    umulh x2, x26, x12
    adds x21, x21, x5
    adcs x20, x20, x4
    adcs x19, x19, x3
    adcs x15, x15, x2
    adc x1, xzr, xzr
    mul x7, x22, x6
    mul x5, x7, x11
    mul x4, x7, x10
    mul x3, x7, x9
    mul x2, x7, x8
    adds x22, x22, x5
    adcs x21, x21, x4
    adcs x20, x20, x3
    adcs x19, x19, x2
    adcs x15, x15, xzr
    adc x1, x1, xzr
    umulh x5, x7, x11
    umulh x4, x7, x10
    umulh x3, x7, x9
    umulh x2, x7, x8
    adds x22, x21, x5
    adcs x21, x20, x4
    adcs x20, x19, x3
    adcs x19, x15, x2
    adc x15, x1, xzr
    subs x5, x22, x11
    sbcs x4, x21, x10
    sbcs x3, x20, x9
    sbcs x2, x19, x8
    sbcs xzr, x15, xzr
    csel x5, x5, x22, CS
    csel x4, x4, x21, CS
    csel x3, x3, x20, CS
    csel x1, x2, x19, CS
    str x5, [x0, #0]
    str x4, [x0, #8]
    str x3, [x0, #16]
    str x1, [x0, #24]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #80
    ret

.globl _mont_mul_p256
.p2align 2
_mont_mul_p256:
Lmont_mul_p256$entry:
    mov x16, x0
    fmov d16, x16
    mov x0, x1
    mov x15, x2
    ldr x14, [x0, #0]
    ldr x13, [x0, #8]
    ldr x12, [x0, #16]
    ldr x11, [x0, #24]
    ldr x5, [x15]
    mul x10, x14, x5
    umulh x4, x14, x5
    mul x9, x13, x5
    umulh x3, x13, x5
    mul x8, x12, x5
    umulh x2, x12, x5
    mul x7, x11, x5
    umulh x1, x11, x5
    ldr x5, [x15, #8]
    adds x9, x9, x4
    ubfm x4, x10, #32, #31
    adcs x8, x8, x3
    ubfm x3, x10, #32, #63
    adcs x7, x7, x2
    adc x6, xzr, x1
    mov x0, xzr
    subs x2, x10, x4
    sbc x1, x10, x3
    adds x10, x9, x4
    mul x4, x14, x5
    adcs x9, x8, x3
    mul x3, x13, x5
    adcs x8, x7, x2
    mul x2, x12, x5
    adcs x7, x6, x1
    mul x1, x11, x5
    adc x6, x0, xzr
    adds x10, x10, x4
    umulh x4, x14, x5
    adcs x9, x9, x3
    umulh x3, x13, x5
    adcs x8, x8, x2
    umulh x2, x12, x5
    adcs x7, x7, x1
    umulh x1, x11, x5
    adc x6, x6, xzr
    ldr x5, [x15, #16]
    adds x9, x9, x4
    ubfm x4, x10, #32, #31
    adcs x8, x8, x3
    ubfm x3, x10, #32, #63
    adcs x7, x7, x2
    adcs x6, x6, x1
    adc x0, xzr, xzr
    subs x2, x10, x4
    sbc x1, x10, x3
    adds x10, x9, x4
    mul x4, x14, x5
    adcs x9, x8, x3
    mul x3, x13, x5
    adcs x8, x7, x2
    mul x2, x12, x5
    adcs x7, x6, x1
    mul x1, x11, x5
    adc x6, x0, xzr
    adds x10, x10, x4
    umulh x4, x14, x5
    adcs x9, x9, x3
    umulh x3, x13, x5
    adcs x8, x8, x2
    umulh x2, x12, x5
    adcs x7, x7, x1
    umulh x1, x11, x5
    adc x6, x6, xzr
    ldr x5, [x15, #24]
    adds x9, x9, x4
    ubfm x4, x10, #32, #31
    adcs x8, x8, x3
    ubfm x3, x10, #32, #63
    adcs x7, x7, x2
    adcs x6, x6, x1
    adc x0, xzr, xzr
    subs x2, x10, x4
    sbc x1, x10, x3
    adds x10, x9, x4
    mul x4, x14, x5
    adcs x9, x8, x3
    mul x3, x13, x5
    adcs x8, x7, x2
    mul x2, x12, x5
    adcs x7, x6, x1
    mul x1, x11, x5
    adc x6, x0, xzr
    adds x10, x10, x4
    umulh x4, x14, x5
    adcs x9, x9, x3
    umulh x3, x13, x5
    adcs x8, x8, x2
    umulh x2, x12, x5
    adcs x7, x7, x1
    umulh x1, x11, x5
    adc x6, x6, xzr
    adds x9, x9, x4
    ubfm x4, x10, #32, #31
    adcs x8, x8, x3
    ubfm x3, x10, #32, #63
    adcs x7, x7, x2
    adcs x6, x6, x1
    adc x0, xzr, xzr
    subs x2, x10, x4
    sbc x1, x10, x3
    adds x10, x9, x4
    adcs x9, x8, x3
    adcs x8, x7, x2
    adcs x7, x6, x1
    adc x6, x0, xzr
    movz x1, #65535
    movk x1, #65535, LSL #16
    movz x0, #1
    movk x0, #65535, LSL #32
    movk x0, #65535, LSL #48
    adds x4, x10, #1
    sbcs x3, x9, x1
    sbcs x2, x8, xzr
    sbcs x1, x7, x0
    sbcs xzr, x6, xzr
    csel x4, x10, x4, LO
    csel x3, x9, x3, LO
    csel x2, x8, x2, LO
    csel x0, x7, x1, LO
    fmov x16, d16
    str x4, [x16, #0]
    fmov x16, d16
    str x3, [x16, #8]
    fmov x16, d16
    str x2, [x16, #16]
    fmov x16, d16
    str x0, [x16, #24]
    ret



.globl _mont_sqrn_asm
.p2align 2
_mont_sqrn_asm:
Lmont_sqrn_asm$entry:
    stp x29, x30, [sp, #-64]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    ldr x6, [x1, #0]
    ldr x5, [x1, #8]
    ldr x4, [x1, #16]
    ldr x1, [x1, #24]
    ldr x19, [x3, #0]
    ldr x15, [x3, #8]
    ldr x14, [x3, #16]
    ldr x13, [x3, #24]
    ldr x11, [x3, #32]
Lmont_sqrn_asm$sqloop:
    mul x24, x6, x6
    mul x23, x5, x6
    mul x22, x4, x6
    mul x21, x1, x6
    umulh x10, x6, x6
    umulh x9, x5, x6
    umulh x8, x4, x6
    umulh x7, x1, x6
    adds x23, x23, x10
    adcs x22, x22, x9
    adcs x21, x21, x8
    adc x20, xzr, x7
    mov x3, xzr
    mul x12, x24, x11
    mul x10, x12, x19
    mul x9, x12, x15
    mul x8, x12, x14
    mul x7, x12, x13
    adds x24, x24, x10
    adcs x23, x23, x9
    adcs x22, x22, x8
    adcs x21, x21, x7
    adcs x20, x20, xzr
    adc x3, x3, xzr
    umulh x10, x12, x19
    umulh x9, x12, x15
    umulh x8, x12, x14
    umulh x7, x12, x13
    adds x24, x23, x10
    adcs x23, x22, x9
    adcs x22, x21, x8
    adcs x21, x20, x7
    adc x20, x3, xzr
    mul x10, x6, x5
    mul x9, x5, x5
    mul x8, x4, x5
    mul x7, x1, x5
    adds x24, x24, x10
    adcs x23, x23, x9
    adcs x22, x22, x8
    adcs x21, x21, x7
    adc x20, x20, xzr
    umulh x10, x6, x5
    umulh x9, x5, x5
    umulh x8, x4, x5
    umulh x7, x1, x5
    adds x23, x23, x10
    adcs x22, x22, x9
    adcs x21, x21, x8
    adcs x20, x20, x7
    adc x3, xzr, xzr
    mul x12, x24, x11
    mul x10, x12, x19
    mul x9, x12, x15
    mul x8, x12, x14
    mul x7, x12, x13
    adds x24, x24, x10
    adcs x23, x23, x9
    adcs x22, x22, x8
    adcs x21, x21, x7
    adcs x20, x20, xzr
    adc x3, x3, xzr
    umulh x10, x12, x19
    umulh x9, x12, x15
    umulh x8, x12, x14
    umulh x7, x12, x13
    adds x24, x23, x10
    adcs x23, x22, x9
    adcs x22, x21, x8
    adcs x21, x20, x7
    adc x20, x3, xzr
    mul x10, x6, x4
    mul x9, x5, x4
    mul x8, x4, x4
    mul x7, x1, x4
    adds x24, x24, x10
    adcs x23, x23, x9
    adcs x22, x22, x8
    adcs x21, x21, x7
    adc x20, x20, xzr
    umulh x10, x6, x4
    umulh x9, x5, x4
    umulh x8, x4, x4
    umulh x7, x1, x4
    adds x23, x23, x10
    adcs x22, x22, x9
    adcs x21, x21, x8
    adcs x20, x20, x7
    adc x3, xzr, xzr
    mul x12, x24, x11
    mul x10, x12, x19
    mul x9, x12, x15
    mul x8, x12, x14
    mul x7, x12, x13
    adds x24, x24, x10
    adcs x23, x23, x9
    adcs x22, x22, x8
    adcs x21, x21, x7
    adcs x20, x20, xzr
    adc x3, x3, xzr
    umulh x10, x12, x19
    umulh x9, x12, x15
    umulh x8, x12, x14
    umulh x7, x12, x13
    adds x24, x23, x10
    adcs x23, x22, x9
    adcs x22, x21, x8
    adcs x21, x20, x7
    adc x20, x3, xzr
    mul x10, x6, x1
    mul x9, x5, x1
    mul x8, x4, x1
    mul x7, x1, x1
    adds x24, x24, x10
    adcs x23, x23, x9
    adcs x22, x22, x8
    adcs x21, x21, x7
    adc x20, x20, xzr
    umulh x10, x6, x1
    umulh x9, x5, x1
    umulh x8, x4, x1
    umulh x7, x1, x1
    adds x23, x23, x10
    adcs x22, x22, x9
    adcs x21, x21, x8
    adcs x20, x20, x7
    adc x3, xzr, xzr
    mul x12, x24, x11
    mul x10, x12, x19
    mul x9, x12, x15
    mul x8, x12, x14
    mul x7, x12, x13
    adds x24, x24, x10
    adcs x23, x23, x9
    adcs x22, x22, x8
    adcs x21, x21, x7
    adcs x20, x20, xzr
    adc x3, x3, xzr
    umulh x10, x12, x19
    umulh x9, x12, x15
    umulh x8, x12, x14
    umulh x7, x12, x13
    adds x24, x23, x10
    adcs x23, x22, x9
    adcs x22, x21, x8
    adcs x21, x20, x7
    adc x20, x3, xzr
    subs x10, x24, x19
    sbcs x9, x23, x15
    sbcs x8, x22, x14
    sbcs x7, x21, x13
    sbcs xzr, x20, xzr
    csel x6, x10, x24, CS
    csel x5, x9, x23, CS
    csel x4, x8, x22, CS
    csel x1, x7, x21, CS
    subs x2, x2, #1
    b.ne Lmont_sqrn_asm$sqloop
    str x6, [x0, #0]
    str x5, [x0, #8]
    str x4, [x0, #16]
    str x1, [x0, #24]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret


.subsections_via_symbols
# else
// Generated by asmp
// Syntax: gnu

.text


.globl mont_mul_asm
.p2align 2
mont_mul_asm:
Lmont_mul_asm$entry:
    stp x29, x30, [sp, #-80]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    ldr x25, [x1, #0]
    ldr x24, [x1, #8]
    ldr x23, [x1, #16]
    ldr x26, [x1, #24]
    ldr x1, [x2, #0]
    ldr x14, [x2, #8]
    ldr x13, [x2, #16]
    ldr x12, [x2, #24]
    ldr x11, [x3, #0]
    ldr x10, [x3, #8]
    ldr x9, [x3, #16]
    ldr x8, [x3, #24]
    ldr x6, [x3, #32]
    mul x22, x25, x1
    mul x21, x24, x1
    mul x20, x23, x1
    mul x19, x26, x1
    umulh x5, x25, x1
    umulh x4, x24, x1
    umulh x3, x23, x1
    umulh x2, x26, x1
    adds x21, x21, x5
    adcs x20, x20, x4
    adcs x19, x19, x3
    adc x15, xzr, x2
    mov x1, xzr
    mul x7, x22, x6
    mul x5, x7, x11
    mul x4, x7, x10
    mul x3, x7, x9
    mul x2, x7, x8
    adds x22, x22, x5
    adcs x21, x21, x4
    adcs x20, x20, x3
    adcs x19, x19, x2
    adcs x15, x15, xzr
    adc x1, x1, xzr
    umulh x5, x7, x11
    umulh x4, x7, x10
    umulh x3, x7, x9
    umulh x2, x7, x8
    adds x22, x21, x5
    adcs x21, x20, x4
    adcs x20, x19, x3
    adcs x19, x15, x2
    adc x15, x1, xzr
    mul x5, x25, x14
    mul x4, x24, x14
    mul x3, x23, x14
    mul x2, x26, x14
    adds x22, x22, x5
    adcs x21, x21, x4
    adcs x20, x20, x3
    adcs x19, x19, x2
    adc x15, x15, xzr
    umulh x5, x25, x14
    umulh x4, x24, x14
    umulh x3, x23, x14
    umulh x2, x26, x14
    adds x21, x21, x5
    adcs x20, x20, x4
    adcs x19, x19, x3
    adcs x15, x15, x2
    adc x1, xzr, xzr
    mul x7, x22, x6
    mul x5, x7, x11
    mul x4, x7, x10
    mul x3, x7, x9
    mul x2, x7, x8
    adds x22, x22, x5
    adcs x21, x21, x4
    adcs x20, x20, x3
    adcs x19, x19, x2
    adcs x15, x15, xzr
    adc x1, x1, xzr
    umulh x5, x7, x11
    umulh x4, x7, x10
    umulh x3, x7, x9
    umulh x2, x7, x8
    adds x22, x21, x5
    adcs x21, x20, x4
    adcs x20, x19, x3
    adcs x19, x15, x2
    adc x15, x1, xzr
    mul x5, x25, x13
    mul x4, x24, x13
    mul x3, x23, x13
    mul x2, x26, x13
    adds x22, x22, x5
    adcs x21, x21, x4
    adcs x20, x20, x3
    adcs x19, x19, x2
    adc x15, x15, xzr
    umulh x5, x25, x13
    umulh x4, x24, x13
    umulh x3, x23, x13
    umulh x2, x26, x13
    adds x21, x21, x5
    adcs x20, x20, x4
    adcs x19, x19, x3
    adcs x15, x15, x2
    adc x1, xzr, xzr
    mul x7, x22, x6
    mul x5, x7, x11
    mul x4, x7, x10
    mul x3, x7, x9
    mul x2, x7, x8
    adds x22, x22, x5
    adcs x21, x21, x4
    adcs x20, x20, x3
    adcs x19, x19, x2
    adcs x15, x15, xzr
    adc x1, x1, xzr
    umulh x5, x7, x11
    umulh x4, x7, x10
    umulh x3, x7, x9
    umulh x2, x7, x8
    adds x22, x21, x5
    adcs x21, x20, x4
    adcs x20, x19, x3
    adcs x19, x15, x2
    adc x15, x1, xzr
    mul x5, x25, x12
    mul x4, x24, x12
    mul x3, x23, x12
    mul x2, x26, x12
    adds x22, x22, x5
    adcs x21, x21, x4
    adcs x20, x20, x3
    adcs x19, x19, x2
    adc x15, x15, xzr
    umulh x5, x25, x12
    umulh x4, x24, x12
    umulh x3, x23, x12
    umulh x2, x26, x12
    adds x21, x21, x5
    adcs x20, x20, x4
    adcs x19, x19, x3
    adcs x15, x15, x2
    adc x1, xzr, xzr
    mul x7, x22, x6
    mul x5, x7, x11
    mul x4, x7, x10
    mul x3, x7, x9
    mul x2, x7, x8
    adds x22, x22, x5
    adcs x21, x21, x4
    adcs x20, x20, x3
    adcs x19, x19, x2
    adcs x15, x15, xzr
    adc x1, x1, xzr
    umulh x5, x7, x11
    umulh x4, x7, x10
    umulh x3, x7, x9
    umulh x2, x7, x8
    adds x22, x21, x5
    adcs x21, x20, x4
    adcs x20, x19, x3
    adcs x19, x15, x2
    adc x15, x1, xzr
    subs x5, x22, x11
    sbcs x4, x21, x10
    sbcs x3, x20, x9
    sbcs x2, x19, x8
    sbcs xzr, x15, xzr
    csel x5, x5, x22, CS
    csel x4, x4, x21, CS
    csel x3, x3, x20, CS
    csel x1, x2, x19, CS
    str x5, [x0, #0]
    str x4, [x0, #8]
    str x3, [x0, #16]
    str x1, [x0, #24]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #80
    ret
// Generated by asmp
// Syntax: gnu

.text


.globl mont_mul_p256
.p2align 2
mont_mul_p256:
Lmont_mul_p256$entry:
    mov x16, x0
    fmov d16, x16
    mov x15, x2
    ldr x14, [x1, #0]
    ldr x13, [x1, #8]
    ldr x12, [x1, #16]
    ldr x11, [x1, #24]
    ldr x5, [x15]
    mul x10, x14, x5
    umulh x4, x14, x5
    mul x9, x13, x5
    umulh x3, x13, x5
    mul x8, x12, x5
    umulh x2, x12, x5
    mul x7, x11, x5
    umulh x1, x11, x5
    ldr x5, [x15, #8]
    adds x9, x9, x4
    ubfm x4, x10, #32, #31
    adcs x8, x8, x3
    ubfm x3, x10, #32, #63
    adcs x7, x7, x2
    adc x6, xzr, x1
    mov x0, xzr
    subs x2, x10, x4
    sbc x1, x10, x3
    adds x10, x9, x4
    mul x4, x14, x5
    adcs x9, x8, x3
    mul x3, x13, x5
    adcs x8, x7, x2
    mul x2, x12, x5
    adcs x7, x6, x1
    mul x1, x11, x5
    adc x6, x0, xzr
    adds x10, x10, x4
    umulh x4, x14, x5
    adcs x9, x9, x3
    umulh x3, x13, x5
    adcs x8, x8, x2
    umulh x2, x12, x5
    adcs x7, x7, x1
    umulh x1, x11, x5
    adc x6, x6, xzr
    ldr x5, [x15, #16]
    adds x9, x9, x4
    ubfm x4, x10, #32, #31
    adcs x8, x8, x3
    ubfm x3, x10, #32, #63
    adcs x7, x7, x2
    adcs x6, x6, x1
    adc x0, xzr, xzr
    subs x2, x10, x4
    sbc x1, x10, x3
    adds x10, x9, x4
    mul x4, x14, x5
    adcs x9, x8, x3
    mul x3, x13, x5
    adcs x8, x7, x2
    mul x2, x12, x5
    adcs x7, x6, x1
    mul x1, x11, x5
    adc x6, x0, xzr
    adds x10, x10, x4
    umulh x4, x14, x5
    adcs x9, x9, x3
    umulh x3, x13, x5
    adcs x8, x8, x2
    umulh x2, x12, x5
    adcs x7, x7, x1
    umulh x1, x11, x5
    adc x6, x6, xzr
    ldr x5, [x15, #24]
    adds x9, x9, x4
    ubfm x4, x10, #32, #31
    adcs x8, x8, x3
    ubfm x3, x10, #32, #63
    adcs x7, x7, x2
    adcs x6, x6, x1
    adc x0, xzr, xzr
    subs x2, x10, x4
    sbc x1, x10, x3
    adds x10, x9, x4
    mul x4, x14, x5
    adcs x9, x8, x3
    mul x3, x13, x5
    adcs x8, x7, x2
    mul x2, x12, x5
    adcs x7, x6, x1
    mul x1, x11, x5
    adc x6, x0, xzr
    adds x10, x10, x4
    umulh x4, x14, x5
    adcs x9, x9, x3
    umulh x3, x13, x5
    adcs x8, x8, x2
    umulh x2, x12, x5
    adcs x7, x7, x1
    umulh x1, x11, x5
    adc x6, x6, xzr
    adds x9, x9, x4
    ubfm x4, x10, #32, #31
    adcs x8, x8, x3
    ubfm x3, x10, #32, #63
    adcs x7, x7, x2
    adcs x6, x6, x1
    adc x0, xzr, xzr
    subs x2, x10, x4
    sbc x1, x10, x3
    adds x10, x9, x4
    adcs x9, x8, x3
    adcs x8, x7, x2
    adcs x7, x6, x1
    adc x6, x0, xzr
    movz x1, #65535
    movk x1, #65535, LSL #16
    movz x0, #1
    movk x0, #65535, LSL #32
    movk x0, #65535, LSL #48
    adds x4, x10, #1
    sbcs x3, x9, x1
    sbcs x2, x8, xzr
    sbcs x1, x7, x0
    sbcs xzr, x6, xzr
    csel x4, x10, x4, LO
    csel x3, x9, x3, LO
    csel x2, x8, x2, LO
    csel x0, x7, x1, LO
    fmov x16, d16
    str x4, [x16, #0]
    fmov x16, d16
    str x3, [x16, #8]
    fmov x16, d16
    str x2, [x16, #16]
    fmov x16, d16
    str x0, [x16, #24]
    ret
// Generated by asmp
// Syntax: gnu

.text


.globl mont_sqrn_asm
.p2align 2
mont_sqrn_asm:
Lmont_sqrn_asm$entry:
    stp x29, x30, [sp, #-64]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    ldr x6, [x1, #0]
    ldr x5, [x1, #8]
    ldr x4, [x1, #16]
    ldr x1, [x1, #24]
    ldr x19, [x3, #0]
    ldr x15, [x3, #8]
    ldr x14, [x3, #16]
    ldr x13, [x3, #24]
    ldr x11, [x3, #32]
Lmont_sqrn_asm$sqloop:
    mul x24, x6, x6
    mul x23, x5, x6
    mul x22, x4, x6
    mul x21, x1, x6
    umulh x10, x6, x6
    umulh x9, x5, x6
    umulh x8, x4, x6
    umulh x7, x1, x6
    adds x23, x23, x10
    adcs x22, x22, x9
    adcs x21, x21, x8
    adc x20, xzr, x7
    mov x3, xzr
    mul x12, x24, x11
    mul x10, x12, x19
    mul x9, x12, x15
    mul x8, x12, x14
    mul x7, x12, x13
    adds x24, x24, x10
    adcs x23, x23, x9
    adcs x22, x22, x8
    adcs x21, x21, x7
    adcs x20, x20, xzr
    adc x3, x3, xzr
    umulh x10, x12, x19
    umulh x9, x12, x15
    umulh x8, x12, x14
    umulh x7, x12, x13
    adds x24, x23, x10
    adcs x23, x22, x9
    adcs x22, x21, x8
    adcs x21, x20, x7
    adc x20, x3, xzr
    mul x10, x6, x5
    mul x9, x5, x5
    mul x8, x4, x5
    mul x7, x1, x5
    adds x24, x24, x10
    adcs x23, x23, x9
    adcs x22, x22, x8
    adcs x21, x21, x7
    adc x20, x20, xzr
    umulh x10, x6, x5
    umulh x9, x5, x5
    umulh x8, x4, x5
    umulh x7, x1, x5
    adds x23, x23, x10
    adcs x22, x22, x9
    adcs x21, x21, x8
    adcs x20, x20, x7
    adc x3, xzr, xzr
    mul x12, x24, x11
    mul x10, x12, x19
    mul x9, x12, x15
    mul x8, x12, x14
    mul x7, x12, x13
    adds x24, x24, x10
    adcs x23, x23, x9
    adcs x22, x22, x8
    adcs x21, x21, x7
    adcs x20, x20, xzr
    adc x3, x3, xzr
    umulh x10, x12, x19
    umulh x9, x12, x15
    umulh x8, x12, x14
    umulh x7, x12, x13
    adds x24, x23, x10
    adcs x23, x22, x9
    adcs x22, x21, x8
    adcs x21, x20, x7
    adc x20, x3, xzr
    mul x10, x6, x4
    mul x9, x5, x4
    mul x8, x4, x4
    mul x7, x1, x4
    adds x24, x24, x10
    adcs x23, x23, x9
    adcs x22, x22, x8
    adcs x21, x21, x7
    adc x20, x20, xzr
    umulh x10, x6, x4
    umulh x9, x5, x4
    umulh x8, x4, x4
    umulh x7, x1, x4
    adds x23, x23, x10
    adcs x22, x22, x9
    adcs x21, x21, x8
    adcs x20, x20, x7
    adc x3, xzr, xzr
    mul x12, x24, x11
    mul x10, x12, x19
    mul x9, x12, x15
    mul x8, x12, x14
    mul x7, x12, x13
    adds x24, x24, x10
    adcs x23, x23, x9
    adcs x22, x22, x8
    adcs x21, x21, x7
    adcs x20, x20, xzr
    adc x3, x3, xzr
    umulh x10, x12, x19
    umulh x9, x12, x15
    umulh x8, x12, x14
    umulh x7, x12, x13
    adds x24, x23, x10
    adcs x23, x22, x9
    adcs x22, x21, x8
    adcs x21, x20, x7
    adc x20, x3, xzr
    mul x10, x6, x1
    mul x9, x5, x1
    mul x8, x4, x1
    mul x7, x1, x1
    adds x24, x24, x10
    adcs x23, x23, x9
    adcs x22, x22, x8
    adcs x21, x21, x7
    adc x20, x20, xzr
    umulh x10, x6, x1
    umulh x9, x5, x1
    umulh x8, x4, x1
    umulh x7, x1, x1
    adds x23, x23, x10
    adcs x22, x22, x9
    adcs x21, x21, x8
    adcs x20, x20, x7
    adc x3, xzr, xzr
    mul x12, x24, x11
    mul x10, x12, x19
    mul x9, x12, x15
    mul x8, x12, x14
    mul x7, x12, x13
    adds x24, x24, x10
    adcs x23, x23, x9
    adcs x22, x22, x8
    adcs x21, x21, x7
    adcs x20, x20, xzr
    adc x3, x3, xzr
    umulh x10, x12, x19
    umulh x9, x12, x15
    umulh x8, x12, x14
    umulh x7, x12, x13
    adds x24, x23, x10
    adcs x23, x22, x9
    adcs x22, x21, x8
    adcs x21, x20, x7
    adc x20, x3, xzr
    subs x10, x24, x19
    sbcs x9, x23, x15
    sbcs x8, x22, x14
    sbcs x7, x21, x13
    sbcs xzr, x20, xzr
    csel x6, x10, x24, CS
    csel x5, x9, x23, CS
    csel x4, x8, x22, CS
    csel x1, x7, x21, CS
    subs x2, x2, #1
    b.ne Lmont_sqrn_asm$sqloop
    str x6, [x0, #0]
    str x5, [x0, #8]
    str x4, [x0, #16]
    str x1, [x0, #24]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret
# endif
#endif
