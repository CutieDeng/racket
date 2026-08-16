#!/bin/bash
# portable-check.sh — verify the non-ARMv8-crypto portable software paths of the
# AES modes / GMAC / CCM are bit-identical to the shipped NEON kernels. The
# default build on Apple Silicon always takes the hardware branch, so the
# portable #else code (which a cross-platform x86/generic build depends on) would
# otherwise never be exercised. Here we force the portable branch per-file and
# differential it against the archive's NEON implementation.
#
#   asm/tests/portable-check.sh
#
# Needs the in-tree librktcrypto.a (run `make in-place` first) for the NEON side.

set -uo pipefail
cd "$(dirname "$0")/../.."                       # crypto/ root
LIB=${LIB:-$(ls ../build/cs/c/rktcrypto/librktcrypto.a 2>/dev/null || true)}
if [ -z "$LIB" ] || [ ! -f "$LIB" ]; then echo "librktcrypto.a not found — run 'make in-place'"; exit 2; fi
tmp=$(mktemp -d); rc=0

# 1) AES-CBC/CTR/CMAC/XTS: portable object (renamed p_*, forced portable via
#    -march=armv8-a) diffed against the NEON archive inside one process.
cc -O2 -march=armv8-a -Drktcrypto_aes_ctr=p_ctr -Drktcrypto_aes_cbc_encrypt=p_cbce \
   -Drktcrypto_aes_cbc_decrypt=p_cbcd -Drktcrypto_aes_cmac=p_cmac -Drktcrypto_aes_xts=p_xts \
   -Drktcrypto_aes_expand_key=p_expand -Drktcrypto_aes_enc_block=p_encblk \
   -c rktcrypto_aes_modes.c -o "$tmp/aesmodes_port.o" 2>/dev/null
if cc -O2 -I. -o "$tmp/t_modes" asm/tests/test_aes_portable.c "$tmp/aesmodes_port.o" "$LIB" 2>/dev/null; then
  if "$tmp/t_modes"; then :; else rc=1; fi
else echo "AES-modes: BUILD-FAIL"; rc=1; fi

# 2) GMAC and 3) CCM: two-binary diff (NEON archive vs portable sources) — avoids
#    symbol clashes. Same random inputs both sides.
cat > "$tmp/gmac_vec.c" <<'EOF'
#include <stdio.h>
#include <stdint.h>
void rktcrypto_aes_gmac(const unsigned char*,intptr_t,const unsigned char[12],const unsigned char*,intptr_t,unsigned char[16]);
static uint64_t st=0xabcdef1234567ULL; static unsigned r(){st=st*6364136223846793005ULL+1;return(unsigned)(st>>33);}
int main(){int ks[3]={16,24,32};for(int t=0;t<3000;t++){int kl=ks[r()%3];unsigned char k[32],iv[12],m[300],tag[16];
 for(int i=0;i<kl;i++)k[i]=r();for(int i=0;i<12;i++)iv[i]=r();int len=r()%257;for(int i=0;i<len;i++)m[i]=r();
 rktcrypto_aes_gmac(k,kl,iv,m,len,tag);for(int i=0;i<16;i++)printf("%02x",tag[i]);printf("\n");}return 0;}
EOF
cat > "$tmp/ccm_vec.c" <<'EOF'
#include <stdio.h>
#include <stdint.h>
int rktcrypto_aes256ccm_seal(const unsigned char[32],const unsigned char[12],const unsigned char*,intptr_t,intptr_t,const unsigned char*,intptr_t,intptr_t,unsigned char*,intptr_t);
static uint64_t st=0x99887766ULL; static unsigned r(){st=st*6364136223846793005ULL+1;return(unsigned)(st>>33);}
int main(){for(int t=0;t<2000;t++){unsigned char k[32],n[12],aad[64],pt[128],out[160];
 for(int i=0;i<32;i++)k[i]=r();for(int i=0;i<12;i++)n[i]=r();int al=r()%40,pl=r()%80;
 for(int i=0;i<al;i++)aad[i]=r();for(int i=0;i<pl;i++)pt[i]=r();
 rktcrypto_aes256ccm_seal(k,n,aad,0,al,pt,0,pl,out,0);for(int i=0;i<pl+16;i++)printf("%02x",out[i]);printf("\n");}return 0;}
EOF
diff_two() { # name | neon-link | portable-compile-args
  local name="$1"; shift
  cc -O2 -o "$tmp/${name}_neon" "$tmp/${name}_vec.c" "$LIB" 2>/dev/null && "$tmp/${name}_neon" > "$tmp/${name}_n.txt" 2>&1
  if cc -O2 "$@" -o "$tmp/${name}_port" "$tmp/${name}_vec.c" 2>/dev/null; then "$tmp/${name}_port" > "$tmp/${name}_p.txt" 2>&1
    if diff -q "$tmp/${name}_n.txt" "$tmp/${name}_p.txt" >/dev/null; then echo "$name: PASS ($(wc -l <"$tmp/${name}_n.txt" | tr -d ' ') vectors)"; else echo "$name: FAIL"; rc=1; fi
  else echo "$name: portable BUILD-FAIL"; rc=1; fi
}
diff_two gmac -march=armv8-a rktcrypto_gcm.c rktcrypto_aes_modes.c rktcrypto_ct.c
diff_two ccm  -march=armv8-a -U__APPLE__ rktcrypto_ccm.c rktcrypto_aes_modes.c

rm -rf "$tmp"
echo "----"
[ $rc -eq 0 ] && echo "PORTABLE OK — software AES modes / GMAC / CCM match the NEON kernels" || echo "PORTABLE FAIL"
exit $rc
