#!/bin/bash
# asm-profile.sh — deterministic STATIC structural profile of each committed
# AArch64 kernel .S (Apple branch), for noise-free comparison of the kernels'
# assembly shape. Unlike wall-clock ns/op (load-sensitive on this cycle-counter-
# less M-series box), these counts are exact and reproducible.
#
# Per kernel it counts, over the real instruction body (comments/labels/
# directives stripped, Apple branch only):
#   instrs   total instructions
#   mul      64x64 multiplies (mul/umulh/smulh/madd)  — the throughput bottleneck
#   crypto   NEON crypto/SHA3 ops (aes*/sha*/pmull/eor3/rax1/xar/bcax)
#   vec      other NEON/SIMD instructions (v-regs / .16b/.4s/.2d lanes)
#   ld st    memory loads / stores
#   addsub   add/adc/sub/sbc (carry-chain arithmetic)
#   logic    and/orr/eor/bic/... ; shift  lsl/lsr/asr/ror/bfx/extr
#   branch   b/b.cc/cbz/cbnz/tbz/ret/bl
#   xregs    distinct x0-x30 touched (register-pressure proxy)
#
#   asm/asm-profile.sh              # table over all kernels
#   asm/asm-profile.sh <file.S>     # one kernel, with the per-mnemonic histogram

set -uo pipefail
cd "$(dirname "$0")/.."   # crypto/ root

KERNELS="rktcrypto_bn_op.S rktcrypto_bn_fips.S rktcrypto_bn_sqr.S \
rktcrypto_ecc_asm.S rktcrypto_mont_cios_asm.S rktcrypto_p256_asm.S rktcrypto_p256_hand.S \
rktcrypto_keccak_asm.S rktcrypto_keccak_f2_asm.S rktcrypto_sha1_asm.S rktcrypto_md5_asm.S \
rktcrypto_ccm_asm.S rktcrypto_des_asm.S rktcrypto_rc2_asm.S rktcrypto_bf_asm.S \
rktcrypto_idea_asm.S rktcrypto_cast5_asm.S rktcrypto_seed_asm.S"

# Emit the Apple-branch instruction body of a .S (strip cpp/ELF branch, comments,
# labels, directives). Mirrors regen.sh's select_apple: keep lines until '# else'
# inside the '# if defined(__APPLE__)' block.
apple_body() {
  awk '
    # enter apple body on any #if whose condition mentions __APPLE__ — handles both
    # "#if defined(__aarch64__) && defined(__APPLE__)" (legacy, single guard) and
    # "# if defined(__APPLE__)" (dual-branch inner). The bare outer
    # "#if defined(__aarch64__)" has no __APPLE__ so it does not trigger.
    /^[ \t]*#[ \t]*if.*defined\(__APPLE__\)/ { inapple=1; next }
    /^[ \t]*#[ \t]*else/   { inapple=0; next }
    /^[ \t]*#[ \t]*endif/  { inapple=0; next }
    /^[ \t]*#/ { next }
    inapple {
      line=$0
      sub(/;.*$/,"",line); sub(/\/\/.*$/,"",line)   # strip ; and // comments
      gsub(/^[ \t]+|[ \t]+$/,"",line)
      if(line=="") next
      if(line ~ /^\./) next                          # .text/.globl/.p2align/...
      if(line ~ /:[ \t]*$/) next                     # label
      if(line ~ /^L[A-Za-z0-9_$]+:/) next            # label with trailing code (rare)
      print line
    }' "$1"
}

profile() { # $1=.S  -> prints "name instrs mul crypto vec ld st addsub logic shift branch xregs"
  local f="$1" name; name=$(basename "$f" .S | sed 's/^rktcrypto_//;s/_asm$//')
  apple_body "$f" | awk -v NAME="$name" '
    { mnem=$1; instrs++
      if(mnem ~ /^(mul|umulh|smulh|madd|mneg|umull|smull)$/) mul++
      else if(mnem ~ /^(aese|aesd|aesmc|aesimc|sha1|sha256|sha512|pmull|pmull2|eor3|rax1|xar|bcax)/) crypto++
      else if($0 ~ /\bv[0-9]/ || $0 ~ /\.(16b|8b|4s|2s|2d|1d|8h|4h)\b/) vec++
      else if(mnem ~ /^(ldr|ldp|ld1|ld2|ld3|ld4|ldur|ldrb|ldrh)$/) ld++
      else if(mnem ~ /^(str|stp|st1|st2|st3|st4|stur|strb|strh)$/) st++
      else if(mnem ~ /^(add|adds|adc|adcs|sub|subs|sbc|sbcs|neg|cmp|cmn)$/) addsub++
      else if(mnem ~ /^(and|ands|orr|orn|eor|eon|bic|mvn|bfi|bfm|ubfx|sbfx|ubfm|sbfm)$/) logic++
      else if(mnem ~ /^(lsl|lsr|asr|ror|extr|rev|rev32|rev16|clz|rbit)$/) shift++
      else if(mnem ~ /^(b|bl|br|ret|cbz|cbnz|tbz|tbnz)$/ || mnem ~ /^b\./) branch++
      # distinct x-registers
      s=$0; while(match(s,/x[12]?[0-9]/)){ r=substr(s,RSTART,RLENGTH); xr[r]=1; s=substr(s,RSTART+RLENGTH) }
    }
    END{ nx=0; for(r in xr) nx++
      printf "%-12s %6d %5d %6d %5d %4d %4d %6d %5d %5d %6d %5d\n",
        NAME, instrs+0, mul+0, crypto+0, vec+0, ld+0, st+0, addsub+0, logic+0, shift+0, branch+0, nx }'
}

SNAP=asm/asm-profile.snapshot

all_rows() { for f in $KERNELS; do [ -f "$f" ] && profile "$f"; done; }
header() { printf "%-12s %6s %5s %6s %5s %4s %4s %6s %5s %5s %6s %5s\n" name instrs mul crypto vec ld st addsub logic shift branch xregs; }

case "${1:-}" in
  --snapshot)
    { header; all_rows; } > "$SNAP"
    echo "wrote $SNAP"; cat "$SNAP" ;;
  --check)
    if [ ! -f "$SNAP" ]; then echo "no snapshot ($SNAP) — run: asm/asm-profile.sh --snapshot"; exit 2; fi
    cur=$(mktemp); { header; all_rows; } > "$cur"
    if diff -u "$SNAP" "$cur" >/tmp/apdiff.$$ 2>&1; then
      echo "asm-profile: all $(grep -c . <<<"$(all_rows)") kernels match snapshot (static structure unchanged)"; rm -f "$cur" /tmp/apdiff.$$; exit 0
    else
      echo "asm-profile: STRUCTURE DRIFT vs snapshot —"; sed 's/^/  /' /tmp/apdiff.$$; rm -f "$cur" /tmp/apdiff.$$; exit 1
    fi ;;
  "" )
    header; printf '%.0s-' {1..96}; echo; all_rows ;;
  * )
    f="$1"; [ -f "$f" ] || f="rktcrypto_${1#rktcrypto_}"
    echo "== $f — per-mnemonic histogram (Apple body) =="
    apple_body "$f" | awk '{c[$1]++} END{for(m in c) printf "%6d  %s\n",c[m],m}' | sort -rn
    echo "== profile =="; header; profile "$f" ;;
esac
