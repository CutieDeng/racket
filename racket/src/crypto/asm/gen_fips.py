#!/usr/bin/env python3
# FIPS Montgomery multiply width K with TWO parallel column accumulators: the
# products of each column alternate between accumulator A (x21-23) and B
# (x24-26) so the two add-chains are independent and overlap on the OoO core,
# then A+B are merged into the running Comba accumulator t (x5-7).
# ABI x0=rp,x1=ap,x2=bp,x3=np,x4=n0.
import sys
K=int(sys.argv[1]); out=sys.argv[2]
L=[]; e=lambda s="":L.append(s)
QO=0; ZO=K*8; DO=2*K*8; FR=(3*K*8+15)//16*16
def ld(dst,base,off):
    if base=='q': e("  ldr %s, [sp, #%d]"%(dst,QO+off*8))
    else: e("  ldr %s, [%s, #%d]"%(dst,{'a':'x1','b':'x2','m':'x3'}[base],off*8))
e("#if defined(__aarch64__) && defined(__APPLE__)")
e(".text"); e(".globl _bn_mul_mont_fips%d"%K); e(".p2align 4")
e("_bn_mul_mont_fips%d:"%K)
e("  stp x29, x30, [sp, #-16]!"); e("  mov x29, sp")
e("  stp x19, x20, [sp, #-16]!"); e("  stp x21, x22, [sp, #-16]!")
e("  stp x23, x24, [sp, #-16]!"); e("  stp x25, x26, [sp, #-16]!")
e("  sub sp, sp, #%d"%FR)
e("  mov x19, x0"); e("  mov x20, x4")
def emit_column(prods, add_to_t=True):
    # accumulate prods into A(x21,22,23) and B(x24,25,26), alternating; merge into t(x5,6,7)
    e("  mov x21, xzr"); e("  mov x22, xzr"); e("  mov x23, xzr")
    e("  mov x24, xzr"); e("  mov x25, xzr"); e("  mov x26, xzr")
    for k,(xb,xo,yb,yo) in enumerate(prods):
        A = (k%2==0)
        acc = ("x21","x22","x23") if A else ("x24","x25","x26")
        ld("x8",xb,xo); ld("x9",yb,yo)
        e("  mul x10, x8, x9"); e("  umulh x11, x8, x9")
        e("  adds %s, %s, x10"%(acc[0],acc[0])); e("  adcs %s, %s, x11"%(acc[1],acc[1])); e("  adc %s, %s, xzr"%(acc[2],acc[2]))
    # merge A into t, then B into t
    e("  adds x5, x5, x21"); e("  adcs x6, x6, x22"); e("  adc x7, x7, x23")
    e("  adds x5, x5, x24"); e("  adcs x6, x6, x25"); e("  adc x7, x7, x26")
e("  mov x5, xzr"); e("  mov x6, xzr"); e("  mov x7, xzr")
for i in range(K):
    e("  // col %d"%i)
    prods=[('a',j,'b',i-j) for j in range(0,i)]+[('m',j,'q',i-j) for j in range(1,i+1)]+[('a',i,'b',0)]
    emit_column(prods)
    e("  mul x12, x5, x20"); e("  str x12, [sp, #%d]"%(QO+i*8))
    e("  ldr x9, [x3, #0]"); e("  mul x10, x12, x9"); e("  umulh x11, x12, x9")
    e("  adds x5, x5, x10"); e("  adcs x6, x6, x11"); e("  adc x7, x7, xzr")
    e("  mov x5, x6"); e("  mov x6, x7"); e("  mov x7, xzr")
for i in range(K,2*K-1):
    e("  // col %d"%i)
    prods=[]
    for j in range(i-K+1,K): prods += [('a',j,'b',i-j),('m',j,'q',i-j)]
    emit_column(prods)
    e("  str x5, [sp, #%d]"%(ZO+(i-K)*8)); e("  mov x5, x6"); e("  mov x6, x7"); e("  mov x7, xzr")
e("  str x5, [sp, #%d]"%(ZO+(K-1)*8)); e("  mov x14, x6")
for j in range(K):
    e("  ldr x8, [x3, #%d]"%(j*8)); e("  ldr x9, [sp, #%d]"%(ZO+j*8))
    if j==0: e("  subs x10, x9, x8")
    else:    e("  sbcs x10, x9, x8")
    e("  str x10, [sp, #%d]"%(DO+j*8))
e("  cset x15, cs"); e("  orr x15, x15, x14"); e("  cmp x15, #0")
for j in range(K):
    e("  ldr x9, [sp, #%d]"%(ZO+j*8)); e("  ldr x10, [sp, #%d]"%(DO+j*8))
    e("  csel x9, x10, x9, ne"); e("  str x9, [x19, #%d]"%(j*8))
e("  add sp, sp, #%d"%FR)
e("  ldp x25, x26, [sp], #16"); e("  ldp x23, x24, [sp], #16"); e("  ldp x21, x22, [sp], #16")
e("  ldp x19, x20, [sp], #16"); e("  ldp x29, x30, [sp], #16"); e("  ret")
e("#endif")
open(out,"w").write("\n".join(L)+"\n"); print("wrote",out,"(%d lines)"%len(L))
