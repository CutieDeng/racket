// Symmetric Montgomery squaring, 8-way operand-scanning. Computes off-diagonal
// products a[i]*a[j] (i<j) once into a 2k window, doubles them via a shift-and-
// add pass folding in diagonal squares a[i]^2, then Montgomery-reduces 512 bits
// per iteration. Squaring symmetry halves the multiply products; the 8-word
// register accumulator (acc0-7) gives ~2 adds/product. Kernel behind fast RSA
// verify (16 squarings). Reimplementation of the classic sqrx8x layout.
// ABI: void bn_sqr_mont_8w(uint64_t*rp, const uint64_t*ap, const uint64_t*np,
//                          const uint64_t*n0p, int num)   // num multiple of 8
// Regs: a0-7=x6-13 t0-3=x14-17 acc0-7=x19-26 cnt=x27 carry/na0=x28 topmost=x30
//       tp=x2 ap_end/np_end=x3 n0=x4 num(bytes)=x5 ap/np=x1 rp/window=x0
#if defined(__aarch64__) && defined(__APPLE__)
.text
.globl _bn_sqr_mont_8w
.p2align 5
_bn_sqr_mont_8w:
	mov	x5,x4			// num (words)
	mov	x4,x3			// n0p
	mov	x3,x2			// np
	stp	x29,x30,[sp,#-128]!
	add	x29,sp,#0
	stp	x19,x20,[sp,#16]
	stp	x21,x22,[sp,#32]
	stp	x23,x24,[sp,#48]
	stp	x25,x26,[sp,#64]
	stp	x27,x28,[sp,#80]
	stp	x0,x3,[sp,#96]		// offload rp, np
	ldp	x6,x7,[x1,#8*0]
	ldp	x8,x9,[x1,#8*2]
	ldp	x10,x11,[x1,#8*4]
	ldp	x12,x13,[x1,#8*6]
	sub	x2,sp,x5,lsl#4		// tp = sp - num*16
	lsl	x5,x5,#3		// num *= 8
	ldr	x4,[x4]			// *n0
	mov	sp,x2
	sub	x27,x5,#8*8
	b	Lzero_start
Lzero:
	sub	x27,x27,#8*8
	stp	xzr,xzr,[x2,#8*0]
	stp	xzr,xzr,[x2,#8*2]
	stp	xzr,xzr,[x2,#8*4]
	stp	xzr,xzr,[x2,#8*6]
Lzero_start:
	stp	xzr,xzr,[x2,#8*8]
	stp	xzr,xzr,[x2,#8*10]
	stp	xzr,xzr,[x2,#8*12]
	stp	xzr,xzr,[x2,#8*14]
	add	x2,x2,#8*16
	cbnz	x27,Lzero

	add	x3,x1,x5		// ap_end = &a[num]
	add	x1,x1,#8*8		// ap += 8
	mov	x19,xzr
	mov	x20,xzr
	mov	x21,xzr
	mov	x22,xzr
	mov	x23,xzr
	mov	x24,xzr
	mov	x25,xzr
	mov	x26,xzr
	mov	x2,sp			// tp
	str	x4,[x29,#112]		// offload n0

Louter_loop:
	mul	x14,x7,x6
	mul	x15,x8,x6
	mul	x16,x9,x6
	mul	x17,x10,x6
	adds	x20,x20,x14
	mul	x14,x11,x6
	adcs	x21,x21,x15
	mul	x15,x12,x6
	adcs	x22,x22,x16
	mul	x16,x13,x6
	adcs	x23,x23,x17
	umulh	x17,x7,x6
	adcs	x24,x24,x14
	umulh	x14,x8,x6
	adcs	x25,x25,x15
	umulh	x15,x9,x6
	adcs	x26,x26,x16
	umulh	x16,x10,x6
	stp	x19,x20,[x2],#8*2
	adc	x19,xzr,xzr
	adds	x21,x21,x17
	umulh	x17,x11,x6
	adcs	x22,x22,x14
	umulh	x14,x12,x6
	adcs	x23,x23,x15
	umulh	x15,x13,x6
	adcs	x24,x24,x16
	 mul	x16,x8,x7		// (ii)
	adcs	x25,x25,x17
	 mul	x17,x9,x7
	adcs	x26,x26,x14
	 mul	x14,x10,x7
	adc	x19,x19,x15

	mul	x15,x11,x7
	adds	x22,x22,x16
	mul	x16,x12,x7
	adcs	x23,x23,x17
	mul	x17,x13,x7
	adcs	x24,x24,x14
	umulh	x14,x8,x7
	adcs	x25,x25,x15
	umulh	x15,x9,x7
	adcs	x26,x26,x16
	umulh	x16,x10,x7
	adcs	x19,x19,x17
	umulh	x17,x11,x7
	stp	x21,x22,[x2],#8*2
	adc	x20,xzr,xzr
	adds	x23,x23,x14
	umulh	x14,x12,x7
	adcs	x24,x24,x15
	umulh	x15,x13,x7
	adcs	x25,x25,x16
	 mul	x16,x9,x8		// (iii)
	adcs	x26,x26,x17
	 mul	x17,x10,x8
	adcs	x19,x19,x14
	 mul	x14,x11,x8
	adc	x20,x20,x15

	mul	x15,x12,x8
	adds	x24,x24,x16
	mul	x16,x13,x8
	adcs	x25,x25,x17
	umulh	x17,x9,x8
	adcs	x26,x26,x14
	umulh	x14,x10,x8
	adcs	x19,x19,x15
	umulh	x15,x11,x8
	adcs	x20,x20,x16
	umulh	x16,x12,x8
	stp	x23,x24,[x2],#8*2
	adc	x21,xzr,xzr
	adds	x25,x25,x17
	umulh	x17,x13,x8
	adcs	x26,x26,x14
	 mul	x14,x10,x9		// (iv)
	adcs	x19,x19,x15
	 mul	x15,x11,x9
	adcs	x20,x20,x16
	 mul	x16,x12,x9
	adc	x21,x21,x17

	mul	x17,x13,x9
	adds	x26,x26,x14
	umulh	x14,x10,x9
	adcs	x19,x19,x15
	umulh	x15,x11,x9
	adcs	x20,x20,x16
	umulh	x16,x12,x9
	adcs	x21,x21,x17
	umulh	x17,x13,x9
	stp	x25,x26,[x2],#8*2
	adc	x22,xzr,xzr
	adds	x19,x19,x14
	 mul	x14,x11,x10		// (v)
	adcs	x20,x20,x15
	 mul	x15,x12,x10
	adcs	x21,x21,x16
	 mul	x16,x13,x10
	adc	x22,x22,x17

	umulh	x17,x11,x10
	adds	x20,x20,x14
	umulh	x14,x12,x10
	adcs	x21,x21,x15
	umulh	x15,x13,x10
	adcs	x22,x22,x16
	 mul	x16,x12,x11		// (vi)
	adc	x23,xzr,xzr
	adds	x21,x21,x17
	 mul	x17,x13,x11
	adcs	x22,x22,x14
	 umulh	x14,x12,x11
	adc	x23,x23,x15

	umulh	x15,x13,x11
	adds	x22,x22,x16
	 mul	x16,x13,x12		// (vii)
	adcs	x23,x23,x17
	 umulh	x17,x13,x12
	adc	x24,xzr,xzr
	adds	x23,x23,x14
	sub	x27,x3,x1		// done?
	adc	x24,x24,x15

	adds	x24,x24,x16
	sub	x14,x3,x5		// rewinded ap = &a[0]
	adc	x25,xzr,xzr
	add	x25,x25,x17

	cbz	x27,Louter_break

	mov	x4,x6			// n0 <- a[0]
	ldp	x6,x7,[x2,#8*0]
	ldp	x8,x9,[x2,#8*2]
	ldp	x10,x11,[x2,#8*4]
	ldp	x12,x13,[x2,#8*6]
	adds	x19,x19,x6
	adcs	x20,x20,x7
	ldp	x6,x7,[x1,#8*0]
	adcs	x21,x21,x8
	adcs	x22,x22,x9
	ldp	x8,x9,[x1,#8*2]
	adcs	x23,x23,x10
	adcs	x24,x24,x11
	ldp	x10,x11,[x1,#8*4]
	adcs	x25,x25,x12
	mov	x0,x1			// rp <- ap
	adcs	x26,xzr,x13
	ldp	x12,x13,[x1,#8*6]
	add	x1,x1,#8*8
	mov	x27,#-8*8

Lsqr_mul:
	mul	x14,x6,x4
	adc	x28,xzr,xzr
	mul	x15,x7,x4
	add	x27,x27,#8
	mul	x16,x8,x4
	mul	x17,x9,x4
	adds	x19,x19,x14
	mul	x14,x10,x4
	adcs	x20,x20,x15
	mul	x15,x11,x4
	adcs	x21,x21,x16
	mul	x16,x12,x4
	adcs	x22,x22,x17
	mul	x17,x13,x4
	adcs	x23,x23,x14
	umulh	x14,x6,x4
	adcs	x24,x24,x15
	umulh	x15,x7,x4
	adcs	x25,x25,x16
	umulh	x16,x8,x4
	adcs	x26,x26,x17
	umulh	x17,x9,x4
	adc	x28,x28,xzr
	str	x19,[x2],#8
	adds	x19,x20,x14
	umulh	x14,x10,x4
	adcs	x20,x21,x15
	umulh	x15,x11,x4
	adcs	x21,x22,x16
	umulh	x16,x12,x4
	adcs	x22,x23,x17
	umulh	x17,x13,x4
	ldr	x4,[x0,x27]
	adcs	x23,x24,x14
	adcs	x24,x25,x15
	adcs	x25,x26,x16
	adcs	x26,x28,x17
	cbnz	x27,Lsqr_mul

	cmp	x1,x3
	b.eq	Lsqr_break

	ldp	x6,x7,[x2,#8*0]
	ldp	x8,x9,[x2,#8*2]
	ldp	x10,x11,[x2,#8*4]
	ldp	x12,x13,[x2,#8*6]
	adds	x19,x19,x6
	ldur	x4,[x0,#-8*8]
	adcs	x20,x20,x7
	ldp	x6,x7,[x1,#8*0]
	adcs	x21,x21,x8
	adcs	x22,x22,x9
	ldp	x8,x9,[x1,#8*2]
	adcs	x23,x23,x10
	adcs	x24,x24,x11
	ldp	x10,x11,[x1,#8*4]
	adcs	x25,x25,x12
	mov	x27,#-8*8
	adcs	x26,x26,x13
	ldp	x12,x13,[x1,#8*6]
	add	x1,x1,#8*8
	b	Lsqr_mul

.align	4
Lsqr_break:
	ldp	x6,x7,[x0,#8*0]
	add	x1,x0,#8*8
	ldp	x8,x9,[x0,#8*2]
	sub	x14,x3,x1
	ldp	x10,x11,[x0,#8*4]
	sub	x15,x2,x14
	ldp	x12,x13,[x0,#8*6]
	cbz	x14,Louter_loop

	stp	x19,x20,[x2,#8*0]
	ldp	x19,x20,[x15,#8*0]
	stp	x21,x22,[x2,#8*2]
	ldp	x21,x22,[x15,#8*2]
	stp	x23,x24,[x2,#8*4]
	ldp	x23,x24,[x15,#8*4]
	stp	x25,x26,[x2,#8*6]
	mov	x2,x15
	ldp	x25,x26,[x15,#8*6]
	b	Louter_loop

.align	4
Louter_break:
	// double + add diagonal squares. x14 = &a[0].
	ldp	x7,x9,[x14,#8*0]	// a[0],a[1]
	ldp	x15,x16,[sp,#8*1]	// t[1],t[2]
	ldp	x11,x13,[x14,#8*2]	// a[2],a[3]
	add	x1,x14,#8*4
	ldp	x17,x14,[sp,#8*3]	// t[3],t[4]

	stp	x19,x20,[x2,#8*0]
	mul	x19,x7,x7		// a[0]^2
	stp	x21,x22,[x2,#8*2]
	umulh	x7,x7,x7
	stp	x23,x24,[x2,#8*4]
	mul	x8,x9,x9		// a[1]^2
	stp	x25,x26,[x2,#8*6]
	mov	x2,sp
	umulh	x9,x9,x9
	adds	x20,x7,x15,lsl#1
	extr	x15,x16,x15,#63
	sub	x27,x5,#8*4

Lshift_n_add:
	adcs	x21,x8,x15
	extr	x16,x17,x16,#63
	sub	x27,x27,#8*4
	adcs	x22,x9,x16
	ldp	x15,x16,[x2,#8*5]
	mul	x10,x11,x11		// a[2]^2
	ldp	x7,x9,[x1],#8*2
	umulh	x11,x11,x11
	mul	x12,x13,x13		// a[3]^2
	umulh	x13,x13,x13
	extr	x17,x14,x17,#63
	stp	x19,x20,[x2,#8*0]
	adcs	x23,x10,x17
	extr	x14,x15,x14,#63
	stp	x21,x22,[x2,#8*2]
	adcs	x24,x11,x14
	ldp	x17,x14,[x2,#8*7]
	extr	x15,x16,x15,#63
	adcs	x25,x12,x15
	extr	x16,x17,x16,#63
	adcs	x26,x13,x16
	ldp	x15,x16,[x2,#8*9]
	mul	x6,x7,x7		// a[4]^2
	ldp	x11,x13,[x1],#8*2
	umulh	x7,x7,x7
	mul	x8,x9,x9		// a[5]^2
	umulh	x9,x9,x9
	stp	x23,x24,[x2,#8*4]
	extr	x17,x14,x17,#63
	stp	x25,x26,[x2,#8*6]
	add	x2,x2,#8*8
	adcs	x19,x6,x17
	extr	x14,x15,x14,#63
	adcs	x20,x7,x14
	ldp	x17,x14,[x2,#8*3]
	extr	x15,x16,x15,#63
	cbnz	x27,Lshift_n_add

	ldp	x1,x4,[x29,#104]	// np, n0

	adcs	x21,x8,x15
	extr	x16,x17,x16,#63
	adcs	x22,x9,x16
	ldp	x15,x16,[x2,#8*5]
	mul	x10,x11,x11
	umulh	x11,x11,x11
	stp	x19,x20,[x2,#8*0]
	mul	x12,x13,x13
	umulh	x13,x13,x13
	stp	x21,x22,[x2,#8*2]
	extr	x17,x14,x17,#63
	adcs	x23,x10,x17
	extr	x14,x15,x14,#63
	 ldp	x19,x20,[sp,#8*0]
	adcs	x24,x11,x14
	extr	x15,x16,x15,#63
	 ldp	x6,x7,[x1,#8*0]		// n[0..]
	adcs	x25,x12,x15
	extr	x16,xzr,x16,#63
	 ldp	x8,x9,[x1,#8*2]
	adc	x26,x13,x16
	 ldp	x10,x11,[x1,#8*4]

	mul	x28,x4,x19		// na0 = t[0]*n0
	ldp	x12,x13,[x1,#8*6]
	add	x3,x1,x5		// np_end
	ldp	x21,x22,[sp,#8*2]
	stp	x23,x24,[x2,#8*4]
	ldp	x23,x24,[sp,#8*4]
	stp	x25,x26,[x2,#8*6]
	ldp	x25,x26,[sp,#8*6]
	add	x1,x1,#8*8		// np += 8
	mov	x30,xzr			// topmost
	mov	x2,sp
	mov	x27,#8

Lreduction:
	mul	x15,x7,x28
	sub	x27,x27,#1
	mul	x16,x8,x28
	str	x28,[x2],#8
	mul	x17,x9,x28
	subs	xzr,x19,#1
	mul	x14,x10,x28
	adcs	x19,x20,x15
	mul	x15,x11,x28
	adcs	x20,x21,x16
	mul	x16,x12,x28
	adcs	x21,x22,x17
	mul	x17,x13,x28
	adcs	x22,x23,x14
	umulh	x14,x6,x28
	adcs	x23,x24,x15
	umulh	x15,x7,x28
	adcs	x24,x25,x16
	umulh	x16,x8,x28
	adcs	x25,x26,x17
	umulh	x17,x9,x28
	adc	x26,xzr,xzr
	adds	x19,x19,x14
	umulh	x14,x10,x28
	adcs	x20,x20,x15
	umulh	x15,x11,x28
	adcs	x21,x21,x16
	umulh	x16,x12,x28
	adcs	x22,x22,x17
	umulh	x17,x13,x28
	mul	x28,x4,x19		// next na0
	adcs	x23,x23,x14
	adcs	x24,x24,x15
	adcs	x25,x25,x16
	adc	x26,x26,x17
	cbnz	x27,Lreduction

	ldp	x14,x15,[x2,#8*0]
	ldp	x16,x17,[x2,#8*2]
	mov	x0,x2			// window ptr
	sub	x27,x3,x1		// done?
	adds	x19,x19,x14
	adcs	x20,x20,x15
	ldp	x14,x15,[x2,#8*4]
	adcs	x21,x21,x16
	adcs	x22,x22,x17
	ldp	x16,x17,[x2,#8*6]
	adcs	x23,x23,x14
	adcs	x24,x24,x15
	adcs	x25,x25,x16
	adcs	x26,x26,x17
	cbz	x27,Lpost8

	ldur	x4,[x2,#-8*8]
	ldp	x6,x7,[x1,#8*0]
	ldp	x8,x9,[x1,#8*2]
	ldp	x10,x11,[x1,#8*4]
	mov	x27,#-8*8
	ldp	x12,x13,[x1,#8*6]
	add	x1,x1,#8*8

Lsqr8x_tail:
	mul	x14,x6,x4
	adc	x28,xzr,xzr
	mul	x15,x7,x4
	add	x27,x27,#8
	mul	x16,x8,x4
	mul	x17,x9,x4
	adds	x19,x19,x14
	mul	x14,x10,x4
	adcs	x20,x20,x15
	mul	x15,x11,x4
	adcs	x21,x21,x16
	mul	x16,x12,x4
	adcs	x22,x22,x17
	mul	x17,x13,x4
	adcs	x23,x23,x14
	umulh	x14,x6,x4
	adcs	x24,x24,x15
	umulh	x15,x7,x4
	adcs	x25,x25,x16
	umulh	x16,x8,x4
	adcs	x26,x26,x17
	umulh	x17,x9,x4
	adc	x28,x28,xzr
	str	x19,[x2],#8
	adds	x19,x20,x14
	umulh	x14,x10,x4
	adcs	x20,x21,x15
	umulh	x15,x11,x4
	adcs	x21,x22,x16
	umulh	x16,x12,x4
	adcs	x22,x23,x17
	umulh	x17,x13,x4
	ldr	x4,[x0,x27]
	adcs	x23,x24,x14
	adcs	x24,x25,x15
	adcs	x25,x26,x16
	adcs	x26,x28,x17
	cbnz	x27,Lsqr8x_tail

	ldp	x6,x7,[x2,#8*0]
	sub	x27,x3,x1		// done?
	sub	x16,x3,x5		// rewinded np
	ldp	x8,x9,[x2,#8*2]
	ldp	x10,x11,[x2,#8*4]
	ldp	x12,x13,[x2,#8*6]
	cbz	x27,Ltail_break

	ldur	x4,[x0,#-8*8]
	adds	x19,x19,x6
	adcs	x20,x20,x7
	ldp	x6,x7,[x1,#8*0]
	adcs	x21,x21,x8
	adcs	x22,x22,x9
	ldp	x8,x9,[x1,#8*2]
	adcs	x23,x23,x10
	adcs	x24,x24,x11
	ldp	x10,x11,[x1,#8*4]
	adcs	x25,x25,x12
	mov	x27,#-8*8
	adcs	x26,x26,x13
	ldp	x12,x13,[x1,#8*6]
	add	x1,x1,#8*8
	b	Lsqr8x_tail

.align	4
Ltail_break:
	ldr	x4,[x29,#112]		// n0
	add	x27,x2,#8*8

	subs	xzr,x30,#1		// move topmost carry to C
	adcs	x14,x19,x6
	adcs	x15,x20,x7
	ldp	x19,x20,[x0,#8*0]
	adcs	x21,x21,x8
	ldp	x6,x7,[x16,#8*0]	// x16 = &n[0]
	adcs	x22,x22,x9
	ldp	x8,x9,[x16,#8*2]
	adcs	x23,x23,x10
	adcs	x24,x24,x11
	ldp	x10,x11,[x16,#8*4]
	adcs	x25,x25,x12
	adcs	x26,x26,x13
	ldp	x12,x13,[x16,#8*6]
	add	x1,x16,#8*8
	adc	x30,xzr,xzr		// topmost
	mul	x28,x4,x19
	stp	x14,x15,[x2,#8*0]
	stp	x21,x22,[x2,#8*2]
	ldp	x21,x22,[x0,#8*2]
	stp	x23,x24,[x2,#8*4]
	ldp	x23,x24,[x0,#8*4]
	cmp	x27,x29			// hit bottom?
	stp	x25,x26,[x2,#8*6]
	mov	x2,x0			// slide window
	ldp	x25,x26,[x0,#8*6]
	mov	x27,#8
	b.ne	Lreduction

	// final: subtract modulus, conditional copy
	ldr	x0,[x29,#96]		// rp
	add	x2,x2,#8*8
	subs	x14,x19,x6
	sbcs	x15,x20,x7
	sub	x27,x5,#8*8
	mov	x3,x0			// rp copy (ap_end)

Lsqr8x_sub:
	sbcs	x16,x21,x8
	ldp	x6,x7,[x1,#8*0]
	sbcs	x17,x22,x9
	stp	x14,x15,[x0,#8*0]
	sbcs	x14,x23,x10
	ldp	x8,x9,[x1,#8*2]
	sbcs	x15,x24,x11
	stp	x16,x17,[x0,#8*2]
	sbcs	x16,x25,x12
	ldp	x10,x11,[x1,#8*4]
	sbcs	x17,x26,x13
	ldp	x12,x13,[x1,#8*6]
	add	x1,x1,#8*8
	ldp	x19,x20,[x2,#8*0]
	sub	x27,x27,#8*8
	ldp	x21,x22,[x2,#8*2]
	ldp	x23,x24,[x2,#8*4]
	ldp	x25,x26,[x2,#8*6]
	add	x2,x2,#8*8
	stp	x14,x15,[x0,#8*4]
	sbcs	x14,x19,x6
	stp	x16,x17,[x0,#8*6]
	add	x0,x0,#8*8
	sbcs	x15,x20,x7
	cbnz	x27,Lsqr8x_sub

	sbcs	x16,x21,x8
	mov	x2,sp
	add	x1,sp,x5
	ldp	x6,x7,[x3,#8*0]
	sbcs	x17,x22,x9
	stp	x14,x15,[x0,#8*0]
	sbcs	x14,x23,x10
	ldp	x8,x9,[x3,#8*2]
	sbcs	x15,x24,x11
	stp	x16,x17,[x0,#8*2]
	sbcs	x16,x25,x12
	ldp	x19,x20,[x1,#8*0]
	sbcs	x17,x26,x13
	ldp	x21,x22,[x1,#8*2]
	sbcs	xzr,x30,xzr		// borrow?
	ldr	x30,[x29,#8]
	stp	x14,x15,[x0,#8*4]
	stp	x16,x17,[x0,#8*6]

	sub	x27,x5,#8*4
Lcond_copy:
	sub	x27,x27,#8*4
	csel	x14,x19,x6,lo
	stp	xzr,xzr,[x2,#8*0]
	csel	x15,x20,x7,lo
	ldp	x6,x7,[x3,#8*4]
	ldp	x19,x20,[x1,#8*4]
	csel	x16,x21,x8,lo
	stp	xzr,xzr,[x2,#8*2]
	add	x2,x2,#8*4
	csel	x17,x22,x9,lo
	ldp	x8,x9,[x3,#8*6]
	ldp	x21,x22,[x1,#8*6]
	add	x1,x1,#8*4
	stp	x14,x15,[x3,#8*0]
	stp	x16,x17,[x3,#8*2]
	add	x3,x3,#8*4
	stp	xzr,xzr,[x1,#-8*4]
	stp	xzr,xzr,[x1,#-8*2]
	cbnz	x27,Lcond_copy

	csel	x14,x19,x6,lo
	stp	xzr,xzr,[x2,#8*0]
	csel	x15,x20,x7,lo
	stp	xzr,xzr,[x2,#8*2]
	csel	x16,x21,x8,lo
	csel	x17,x22,x9,lo
	stp	x14,x15,[x3,#8*0]
	stp	x16,x17,[x3,#8*2]
	b	Ldone

.align	4
Lpost8:
	adc	x28,xzr,xzr
	ldr	x30,[x29,#8]
	subs	x6,x19,x6
	ldr	x1,[x29,#96]		// rp
	sbcs	x7,x20,x7
	stp	xzr,xzr,[sp,#8*0]
	sbcs	x8,x21,x8
	stp	xzr,xzr,[sp,#8*2]
	sbcs	x9,x22,x9
	stp	xzr,xzr,[sp,#8*4]
	sbcs	x10,x23,x10
	stp	xzr,xzr,[sp,#8*6]
	sbcs	x11,x24,x11
	stp	xzr,xzr,[sp,#8*8]
	sbcs	x12,x25,x12
	stp	xzr,xzr,[sp,#8*10]
	sbcs	x13,x26,x13
	stp	xzr,xzr,[sp,#8*12]
	sbcs	x28,x28,xzr
	stp	xzr,xzr,[sp,#8*14]
	csel	x6,x19,x6,lo
	csel	x7,x20,x7,lo
	csel	x8,x21,x8,lo
	csel	x9,x22,x9,lo
	stp	x6,x7,[x1,#8*0]
	csel	x10,x23,x10,lo
	csel	x11,x24,x11,lo
	stp	x8,x9,[x1,#8*2]
	csel	x12,x25,x12,lo
	csel	x13,x26,x13,lo
	stp	x10,x11,[x1,#8*4]
	stp	x12,x13,[x1,#8*6]

Ldone:
	mov	sp,x29
	ldp	x19,x20,[x29,#16]
	ldp	x21,x22,[x29,#32]
	ldp	x23,x24,[x29,#48]
	ldp	x25,x26,[x29,#64]
	ldp	x27,x28,[x29,#80]
	ldp	x29,x30,[sp],#128
	ret
#endif
