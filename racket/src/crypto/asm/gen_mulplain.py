#!/usr/bin/env python3
# Plain schoolbook multiply r[0..2K-1] = a[0..K-1]*b[0..K-1], operand-scanning
# with a register-resident rotating accumulator and two carry chains per column
# (lo-product adcs sweep + hi-product adcs sweep). Same structure as the RSA
# operand-scanning Montgomery kernel but WITHOUT the reduction pass: each column
# just finalizes the low accumulator word as r[i]. ABI x0=r, x1=a, x2=b.
import sys
K=int(sys.argv[1]); out=sys.argv[2]; M=K+2
L=[]; e=lambda s="":L.append(s)
def A(base,j): return "x.acc%d"%((base+j)%M)
def lo_pass(base):
    for j in range(K):
        e("  ldr x.t, [x.a, #%d]"%(j*8)); e("  mul x.p, x.t, x.bi")
        if j==0: e("  adds %s, %s, x.p"%(A(base,0),A(base,0)))
        else:    e("  adcs %s, %s, x.p"%(A(base,j),A(base,j)))
    e("  adcs %s, %s, xzr"%(A(base,K),A(base,K)))
    e("  adc  %s, %s, xzr"%(A(base,K+1),A(base,K+1)))
def hi_pass(base):
    for j in range(K):
        e("  ldr x.t, [x.a, #%d]"%(j*8)); e("  umulh x.p, x.t, x.bi")
        if j==0: e("  adds %s, %s, x.p"%(A(base,1),A(base,1)))
        else:    e("  adcs %s, %s, x.p"%(A(base,j+1),A(base,j+1)))
    e("  adc  %s, %s, xzr"%(A(base,K+1),A(base,K+1)))
e(".function mul_plain%d export ("%K); e("  in: x.r, x.a, x.b"); e(")")
e("entry:"); e("  .save all")
for j in range(M): e("  mov x.acc%d, xzr"%j)
base=0
for i in range(K):
    e("  // b[%d] base=%d"%(i,base))
    e("  ldr x.bi, [x.b, #%d]"%(i*8))
    lo_pass(base); hi_pass(base)
    e("  str %s, [x.r, #%d]"%(A(base,0), i*8))   # r[i] = low accumulator word
    e("  mov %s, xzr"%A(base,0))                  # free the slot for the rotate
    base=(base+1)%M
for j in range(K):                               # high half: r[K..2K-1]
    e("  str %s, [x.r, #%d]"%(A(base,j), (K+j)*8))
e("  .restore all"); e("  ret"); e(".end")
open(out,"w").write("\n".join(L)+"\n"); print("wrote mul_plain K=%d (%d lines)"%(K,len(L)))
