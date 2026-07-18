#!/usr/bin/env python3
# Operand-scanning CIOS Montgomery multiply, k=K, register-resident accumulator
# with two carry chains per row (a lo-product pass and a hi-product pass, each a
# single adcs chain -> ~2 adds/product vs the Comba 3-word accumulator's 3).
# Rotating base makes the CIOS one-word shift implicit. ABI x0=r,x1=a,x2=b,x3=m,x4=n0.
import sys
K=int(sys.argv[1]); out=sys.argv[2]; M=K+2
L=[]; e=lambda s="":L.append(s)
def A(base,j): return "x.acc%d"%((base+j)%M)
def lo_pass(base, factor, srcptr):   # acc[0..K-1] += lo(src[j]*factor); carry -> acc[K],acc[K+1]
    for j in range(K):
        e("  ldr x.t, [%s, #%d]"%(srcptr, j*8)); e("  mul x.p, x.t, %s"%factor)
        if j==0: e("  adds %s, %s, x.p"%(A(base,0),A(base,0)))
        else:    e("  adcs %s, %s, x.p"%(A(base,j),A(base,j)))
    e("  adcs %s, %s, xzr"%(A(base,K),A(base,K)))
    e("  adc  %s, %s, xzr"%(A(base,K+1),A(base,K+1)))
def hi_pass(base, factor, srcptr):   # acc[1..K] += hi(src[j]*factor); carry -> acc[K+1]
    for j in range(K):
        e("  ldr x.t, [%s, #%d]"%(srcptr, j*8)); e("  umulh x.p, x.t, %s"%factor)
        if j==0: e("  adds %s, %s, x.p"%(A(base,1),A(base,1)))
        else:    e("  adcs %s, %s, x.p"%(A(base,j+1),A(base,j+1)))
    e("  adc  %s, %s, xzr"%(A(base,K+1),A(base,K+1)))
e(".function bn_mul_mont_op%d export ("%K); e("  in: x.r, x.a, x.b, x.m, x.n0"); e(")")
e("entry:"); e("  .save all")
for j in range(M): e("  mov x.acc%d, xzr"%j)
base=0
for i in range(K):
    e("  // b[%d] base=%d"%(i,base))
    e("  ldr x.bi, [x.b, #%d]"%(i*8))
    lo_pass(base, "x.bi", "x.a"); hi_pass(base, "x.bi", "x.a")
    e("  mul x.mi, %s, x.n0"%A(base,0))
    lo_pass(base, "x.mi", "x.m"); hi_pass(base, "x.mi", "x.m")
    e("  mov %s, xzr"%A(base,0))   # acc[0] became 0; becomes new acc[K+1]
    base=(base+1)%M
# conditional subtract
for j in range(K):
    e("  ldr x.t, [x.m, #%d]"%(j*8))
    if j==0: e("  subs x.s%d, %s, x.t"%(j,A(base,j)))
    else:    e("  sbcs x.s%d, %s, x.t"%(j,A(base,j)))
e("  sbcs xzr, %s, xzr"%A(base,K))
for j in range(K): e("  csel x.o%d, x.s%d, %s, cs"%(j,j,A(base,j)))
for j in range(K): e("  str x.o%d, [x.r, #%d]"%(j,j*8))
e("  .restore all"); e("  ret"); e(".end")
open(out,"w").write("\n".join(L)+"\n"); print("wrote op K=%d (%d lines)"%(K,len(L)))
