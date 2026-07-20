#!/usr/bin/env python3
# MD5 compress for asmp, TRANSCRIBED from OpenSSL's md5-aarch64.pl.
#
# MD5's serial a-chain is bounded by a hand-crafted instruction *schedule* that a
# list scheduler (clang's or asmp's) does not find on its own -- so, like SHA-1,
# we transcribe OpenSSL's exact instruction order and let asmp do only register
# allocation. The transcription is mechanical and preserves the constraint that no
# physical register id is hardcoded: every OpenSSL physical register wN/xN becomes
# an asmp VIRTUAL register w.rN/x.rN (asmp reallocates), and the ABI regs x0/x1/x2
# become named parameters. OpenSSL's manual callee-save prologue/epilogue is
# dropped -- asmp emits its own from `.save all`.
#
# Input : OpenSSL-generated md5-aarch64 assembly (physical-register .s)
# Output: asmp .asm kernel  void md5_blocks_asm(uint32_t st[4], const uint8_t*, long)
import sys, re

SRC = sys.argv[1]           # path to OpenSSL-generated md5_ossl.s
OUT = sys.argv[2] if len(sys.argv) > 2 else "asm/md5_blocks.asm"

# ABI: x0=state, x1=data, x2=block-count
ABI = {"0": "st", "1": "data", "2": "num"}

def rename(line):
    # strip the '// comment' but keep it as an asmp ';' comment for readability
    code, _, cmt = line.partition("//")
    code = code.rstrip()
    def sub(m):
        w, n = m.group(1), m.group(2)
        return f"{w}.{ABI[n]}" if n in ABI else f"{w}.r{n}"
    code = re.sub(r'\b([wx])([0-9]+)\b', sub, code)
    if cmt.strip():
        code = f"{code}    ; {cmt.strip().lstrip('.')}"
    return code

def gen():
    lines = open(SRC).read().splitlines()
    body = []
    in_body = False
    skip_eb = False
    for ln in lines:
        s = ln.strip()
        # drop big-endian-only byte-swap blocks (#ifdef __AARCH64EB__ ... #endif):
        # little-endian Apple loads MD5's message words in native order, no rev.
        if s.startswith("#ifdef __AARCH64EB__"):
            skip_eb = True; continue
        if skip_eb:
            if s.startswith("#endif"): skip_eb = False
            continue
        if s.startswith("ldp w10") or s.startswith("ldp\tw10"):   # first real insn = state load
            in_body = True
        if not in_body:
            continue
        # drop the callee-save save/restore (asmp manages via .save all) and the
        # final bare `ret` (we emit our own after .restore all)
        if re.search(r'\b(stp|ldp)\s+x(19|21|23|25|27)\b', s):    # x19/x21/... callee-save pairs
            continue
        if s == "ret":
            continue
        if s.startswith("ossl_md5_blocks_loop:"):
            body.append("loop:")
            continue
        if s.startswith(".align") or s == "" or s.startswith("AARCH64"):
            continue
        # b.ne to the loop label
        s2 = s.replace("ossl_md5_blocks_loop", "loop")
        body.append("  " + rename(s2))
    L =  [".function md5_blocks_asm export (", "  in: x.st, x.data, x.num", ")",
          "entry:", "  .save all"]
    L += body
    L += ["  .restore all", "  ret", ".end"]
    return L

open(OUT, "w").write("\n".join(gen()) + "\n")
print(f"wrote {OUT} ({len(gen())} lines) transcribed from {SRC}")
