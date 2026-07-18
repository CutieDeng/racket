#!/usr/bin/env python3
# Raw GNU AArch64 Comba Montgomery multiply width K. ABI x0=rp,x1=ap,x2=bp,x3=np,x4=n0.
import sys
K=int(sys.argv[1]); out=sys.argv[2]
L=[]; e=lambda s="":L.append(s)
# z[] and diff[] on stack: z[0..2K] (2K+1 words) then diff[0..K-1] (K words)
NW=(2*K+1)+K
FR=(NW*8+15)//16*16
e("#if defined(__aarch64__) && defined(__APPLE__)")
e(".text"); e(".globl _bn_mul_mont_comba%d"%K); e(".p2align 4")
e("_bn_mul_mont_comba%d:"%K)
e("  stp x29, x30, [sp, #-16]!"); e("  mov x29, sp")
e("  stp x19, x20, [sp, #-16]!")
e("  sub sp, sp, #%d"%FR)
e("  mov x19, x0")   # rp
e("  mov x20, x4")   # n0
D=(2*K+1)*8          # diff[] byte offset in frame
# Comba multiply
e("  mov x5, xzr"); e("  mov x6, xzr"); e("  mov x7, xzr")
for col in range(2*K-1):
    lo=max(0,col-(K-1)); hi=min(col,K-1)
    for i in range(lo,hi+1):
        j=col-i
        e("  ldr x8, [x1, #%d]"%(i*8)); e("  ldr x9, [x2, #%d]"%(j*8))
        e("  mul x10, x8, x9"); e("  umulh x11, x8, x9")
        e("  adds x5, x5, x10"); e("  adcs x6, x6, x11"); e("  adc x7, x7, xzr")
    e("  str x5, [sp, #%d]"%(col*8)); e("  mov x5, x6"); e("  mov x6, x7"); e("  mov x7, xzr")
e("  str x5, [sp, #%d]"%((2*K-1)*8)); e("  str xzr, [sp, #%d]"%((2*K)*8))
# CIOS reduction
for i in range(K):
    e("  ldr x12, [sp, #%d]"%(i*8)); e("  mul x12, x12, x20"); e("  mov x13, xzr")
    for j in range(K):
        e("  ldr x8, [x3, #%d]"%(j*8)); e("  ldr x9, [sp, #%d]"%((i+j)*8))
        e("  mul x10, x12, x8"); e("  umulh x11, x12, x8")
        e("  adds x9, x9, x10"); e("  adc x11, x11, xzr")
        e("  adds x9, x9, x13"); e("  adc x13, x11, xzr")
        e("  str x9, [sp, #%d]"%((i+j)*8))
    # add carry to z[i+K], propagate to z[i+K+1..2K]
    e("  ldr x9, [sp, #%d]"%((i+K)*8)); e("  adds x9, x9, x13"); e("  str x9, [sp, #%d]"%((i+K)*8))
    for p in range(i+K+1, 2*K+1):
        e("  ldr x9, [sp, #%d]"%(p*8)); e("  adcs x9, x9, xzr"); e("  str x9, [sp, #%d]"%(p*8))
# conditional subtract: diff[j] = z[K+j]-m[j]-borrow ; store to diff[]
for j in range(K):
    e("  ldr x8, [x3, #%d]"%(j*8)); e("  ldr x9, [sp, #%d]"%((K+j)*8))
    if j==0: e("  subs x10, x9, x8")
    else:    e("  sbcs x10, x9, x8")
    e("  str x10, [sp, #%d]"%(D+j*8))
# ge = z[2K]!=0 OR no-borrow(CS). After the sbcs chain, C=1 means no borrow (>=).
e("  cset x14, cs")                        # x14 = 1 if z_hi >= m (no borrow)
e("  ldr x15, [sp, #%d]"%((2*K)*8))        # overflow word
e("  orr x14, x14, x15")                   # ge if overflow set too
e("  cmp x14, #0")                         # ge != 0 ?
for j in range(K):
    e("  ldr x9, [sp, #%d]"%((K+j)*8))     # original
    e("  ldr x10, [sp, #%d]"%(D+j*8))      # diff
    e("  csel x9, x10, x9, ne")            # ge(ne) -> diff else original
    e("  str x9, [x19, #%d]"%(j*8))
e("  add sp, sp, #%d"%FR)
e("  ldp x19, x20, [sp], #16]".replace("]","") if False else "  ldp x19, x20, [sp], #16")
e("  ldp x29, x30, [sp], #16")
e("  ret")
e("#endif")
open(out,"w").write("\n".join(L)+"\n")
print("wrote",out,"(%d lines)"%len(L))
