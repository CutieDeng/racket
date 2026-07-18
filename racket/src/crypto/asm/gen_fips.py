#!/usr/bin/env python3
# Raw GNU AArch64 FIPS (finely-integrated product-scanning) Montgomery multiply,
# width K. One fused pass: each column accumulates multiply products a[j]*b[i-j]
# AND reduction products m[j]*q[i-j] into a 3-word register accumulator, with
# q[i] computed on the fly -- no separate serial reduction. ABI x0=rp,x1=ap,
# x2=bp,x3=np,x4=n0. q[] and z[] on a self-managed stack frame.
import sys
K=int(sys.argv[1]); out=sys.argv[2]
L=[]; e=lambda s="":L.append(s)
NW=2*K+K   # z[K] + diff[K] ... we use q[K], z[K] on stack
QO=0; ZO=K*8; DO=2*K*8
FR=(3*K*8+15)//16*16
e("#if defined(__aarch64__) && defined(__APPLE__)")
e(".text"); e(".globl _bn_mul_mont_fips%d"%K); e(".p2align 4")
e("_bn_mul_mont_fips%d:"%K)
e("  stp x29, x30, [sp, #-16]!"); e("  mov x29, sp")
e("  stp x19, x20, [sp, #-16]!")
e("  sub sp, sp, #%d"%FR)
e("  mov x19, x0")  # rp
e("  mov x20, x4")  # n0
# t0,t1,t2 = x5,x6,x7 ; xi,yi=x8,x9 ; lo,hi=x10,x11 ; qi=x12
def MAC(xr,yr):
    e("  mul x10, %s, %s"%(xr,yr)); e("  umulh x11, %s, %s"%(xr,yr))
    e("  adds x5, x5, x10"); e("  adcs x6, x6, x11"); e("  adc x7, x7, xzr")
e("  mov x5, xzr"); e("  mov x6, xzr"); e("  mov x7, xzr")
for i in range(K):
    e("  // col %d"%i)
    for j in range(0,i):
        e("  ldr x8, [x1, #%d]"%(j*8)); e("  ldr x9, [x2, #%d]"%((i-j)*8)); MAC("x8","x9")
    for j in range(1,i+1):
        e("  ldr x8, [x3, #%d]"%(j*8)); e("  ldr x9, [sp, #%d]"%(QO+(i-j)*8)); MAC("x8","x9")
    e("  ldr x8, [x1, #%d]"%(i*8)); e("  ldr x9, [x2, #0]"); MAC("x8","x9")
    e("  mul x12, x5, x20"); e("  str x12, [sp, #%d]"%(QO+i*8))   # q[i]
    e("  ldr x9, [x3, #0]"); MAC("x12","x9")                       # += q[i]*m[0] -> t0=0
    e("  mov x5, x6"); e("  mov x6, x7"); e("  mov x7, xzr")
for i in range(K,2*K-1):
    e("  // col %d"%i)
    for j in range(i-K+1,K):
        e("  ldr x8, [x1, #%d]"%(j*8)); e("  ldr x9, [x2, #%d]"%((i-j)*8)); MAC("x8","x9")
        e("  ldr x8, [x3, #%d]"%(j*8)); e("  ldr x9, [sp, #%d]"%(QO+(i-j)*8)); MAC("x8","x9")
    e("  str x5, [sp, #%d]"%(ZO+(i-K)*8)); e("  mov x5, x6"); e("  mov x6, x7"); e("  mov x7, xzr")
e("  str x5, [sp, #%d]"%(ZO+(K-1)*8))   # z[K-1]=t0
e("  mov x14, x6")                       # top carry = t1
# conditional subtract m from z[]
for j in range(K):
    e("  ldr x8, [x3, #%d]"%(j*8)); e("  ldr x9, [sp, #%d]"%(ZO+j*8))
    if j==0: e("  subs x10, x9, x8")
    else:    e("  sbcs x10, x9, x8")
    e("  str x10, [sp, #%d]"%(DO+j*8))
e("  cset x15, cs"); e("  orr x15, x15, x14"); e("  cmp x15, #0")
for j in range(K):
    e("  ldr x9, [sp, #%d]"%(ZO+j*8)); e("  ldr x10, [sp, #%d]"%(DO+j*8))
    e("  csel x9, x10, x9, ne"); e("  str x9, [x19, #%d]"%(j*8))
e("  add sp, sp, #%d"%FR); e("  ldp x19, x20, [sp], #16"); e("  ldp x29, x30, [sp], #16"); e("  ret")
e("#endif")
open(out,"w").write("\n".join(L)+"\n"); print("wrote",out,"(%d lines)"%len(L))
