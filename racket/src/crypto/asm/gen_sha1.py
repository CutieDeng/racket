#!/usr/bin/env python3
# Multi-block ARMv8 SHA-1 compress written for asmp (virtual registers; asmp does
# register allocation). Transcribes OpenSSL sha1-armv8.pl's hardware schedule
# (sha1c/p/m + sha1h + sha1su0/su1) exactly -- the instruction *placement* is what
# clang schedules ~7% worse than the hand asm on Apple M. State (ABCD,E) stays in
# registers across all blocks (no per-block ctx round-trip).
# ABI: void sha1_blocks_asm(uint32_t st[5], const uint8_t *p, long nblk)
import sys
def gen():
    L=[".function sha1_blocks_asm export (", "  in: x.st, x.p, x.num", ")","entry:"]
    # K constants (round groups 0-19,20-39,40-59,60-79)
    for i,(lo,hi) in enumerate([(0x7999,0x5A82),(0xEBA1,0x6ED9),(0xBCDC,0x8F1B),(0xC1D6,0xCA62)]):
        L.append("  movz w.t, #0x%04X" % lo)
        L.append("  movk w.t, #0x%04X, lsl #16" % hi)
        L.append("  dup v.k%d.4s, w.t" % i)
    L.append("  ld1 { v.abcd.4s }, [x.st]")
    L.append("  ldr s.e, [x.st, #16]")          # E into lane 0
    L.append("loop:")
    L.append("  ld1 { v.m0.4s, v.m1.4s, v.m2.4s, v.m3.4s }, [x.p], #64")
    L.append("  subs x.num, x.num, #1")
    L.append("  rev32 v.m0.16b, v.m0.16b")
    L.append("  rev32 v.m1.16b, v.m1.16b")
    L.append("  add v.w0.4s, v.k0.4s, v.m0.4s")
    L.append("  rev32 v.m2.16b, v.m2.16b")
    L.append("  mov v.abcd0.16b, v.abcd.16b")
    L.append("  add v.w1.4s, v.k0.4s, v.m1.4s")
    L.append("  rev32 v.m3.16b, v.m3.16b")
    L.append("  sha1h s.e1, s.abcd")
    L.append("  sha1c q.abcd, s.e, v.w0.4s")
    kxx=["v.k0","v.k1","v.k2","v.k3"]
    j=0
    L.append("  add v.w0.4s, %s.4s, v.m2.4s" % kxx[j])
    L.append("  sha1su0 v.m0.4s, v.m1.4s, v.m2.4s")
    msg=["v.m0","v.m1","v.m2","v.m3"]
    w0,w1="v.w0","v.w1"; e0,e1="e0","e1"
    for i in range(1,17):
        f=("c","p","m","p")[i//5]
        L.append("  sha1h s.%s, s.abcd" % e0)
        L.append("  sha1%s q.abcd, s.%s, %s.4s" % (f,e1,w1))
        L.append("  add %s.4s, %s.4s, %s.4s" % (w1,kxx[j],msg[3]))
        L.append("  sha1su1 %s.4s, %s.4s" % (msg[0],msg[3]))
        if i<16:
            L.append("  sha1su0 %s.4s, %s.4s, %s.4s" % (msg[1],msg[2],msg[3]))
        e0,e1=e1,e0; w0,w1=w1,w0; msg=msg[1:]+msg[:1]
        if (i+3)%5==0: j+=1
    # final 3 rounds (rounds 60..79 tail)
    L.append("  sha1h s.%s, s.abcd" % e0)
    L.append("  sha1p q.abcd, s.%s, %s.4s" % (e1,w1))
    L.append("  add %s.4s, %s.4s, %s.4s" % (w1,kxx[j],msg[3]))
    L.append("  sha1h s.%s, s.abcd" % e1)
    L.append("  sha1p q.abcd, s.%s, %s.4s" % (e0,w0))
    L.append("  sha1h s.%s, s.abcd" % e0)
    L.append("  sha1p q.abcd, s.%s, %s.4s" % (e1,w1))
    L.append("  add v.e.4s, v.e.4s, v.%s.4s" % e0)   # feed-forward E += E0
    L.append("  add v.abcd.4s, v.abcd.4s, v.abcd0.4s")
    L.append("  b.ne loop")
    L.append("  st1 { v.abcd.4s }, [x.st]")
    L.append("  str s.e, [x.st, #16]")
    L.append("  ret")
    L.append(".end")
    return L
open(sys.argv[1] if len(sys.argv)>1 else "asm/sha1_blocks.asm","w").write("\n".join(gen())+"\n")
print("wrote sha1_blocks.asm")
