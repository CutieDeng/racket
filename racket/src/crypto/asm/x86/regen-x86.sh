#!/bin/sh
# rktasm/x86 kernel maintenance (x86-64 ELF kernels under asm/x86/*.asm).
#   regen-x86.sh regen <kernel>    regenerate rktcrypto_<kernel>_x86.S from asm/x86/<kernel>.asm (Mac or Linux)
#   regen-x86.sh check [kernel]    regenerate to a temp file and require a byte-identical committed .S
#   regen-x86.sh gate  [kernel]    x86-64 Linux only: build the C harness against the committed .S,
#                                  run the differential/KAT, print the BENCH lines (fails on any mismatch)
#   regen-x86.sh gensrc [--write] emitted .asm sources (GENSRC table): regenerate from their Racket
#                                  emitter and require a byte-identical committed .asm (--write: rewrite it)
#   regen-x86.sh list
# The generator runs on any host (clang cross round trip is optional: RT=1); the gate needs the
# target ISA (SHA-NI/AES-NI/...) on the running CPU, i.e. lan-11-class hardware.
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)        # racket/src/crypto
RKTASM="$ROOT/../rktasm/x86/as.rkt"
RACKET=${RACKET:-racket}
CC=${CC:-cc}
# kernel | .S output | harness | extra harness sources (every kernel .S of the table is linked into every gate,
# because the dispatchers in rktcrypto_x86.c reference all of them)
TABLE='
sha256|rktcrypto_sha256_x86.S|asm/tests/test_sha256_x86.c|rktcrypto_x86.c rktcrypto_cpu.c
sha256_avx2|rktcrypto_sha256_avx2.S|asm/tests/test_sha256_x86.c|rktcrypto_x86.c rktcrypto_cpu.c
aes_ctr_vaes|rktcrypto_aes_ctr_vaes.S|asm/tests/test_aes_ctr_vaes.c|rktcrypto_x86.c rktcrypto_cpu.c
ghash_vpclmul|rktcrypto_ghash_vpclmul.S|asm/tests/test_ghash_vpclmul.c|rktcrypto_x86.c rktcrypto_cpu.c
gcm_vaes|rktcrypto_gcm_vaes.S|asm/tests/test_gcm_vaes.c|rktcrypto_x86.c rktcrypto_cpu.c rktcrypto_gcm.c rktcrypto_aes_modes.c rktcrypto_ccm.c rktcrypto_ct.c
gcm_aesni|rktcrypto_gcm_aesni.S|asm/tests/test_gcm_vaes.c|rktcrypto_x86.c rktcrypto_cpu.c rktcrypto_gcm.c rktcrypto_aes_modes.c rktcrypto_ccm.c rktcrypto_ct.c
gcm_aesni_sse|rktcrypto_gcm_aesni_sse.S|asm/tests/test_gcm_vaes.c|rktcrypto_x86.c rktcrypto_cpu.c rktcrypto_gcm.c rktcrypto_aes_modes.c rktcrypto_ccm.c rktcrypto_ct.c
chacha20_avx2|rktcrypto_chacha20_avx2.S|asm/tests/test_chacha20_avx512.c|rktcrypto_chacha20.c rktcrypto_poly1305.c rktcrypto_aead.c rktcrypto_cpu.c rktcrypto_x86.c rktcrypto_gcm.c rktcrypto_aes_modes.c rktcrypto_ccm.c rktcrypto_ct.c
chacha20_ssse3|rktcrypto_chacha20_ssse3.S|asm/tests/test_chacha20_avx512.c|rktcrypto_chacha20.c rktcrypto_poly1305.c rktcrypto_aead.c rktcrypto_cpu.c rktcrypto_x86.c rktcrypto_gcm.c rktcrypto_aes_modes.c rktcrypto_ccm.c rktcrypto_ct.c
chacha20_avx512|rktcrypto_chacha20_avx512.S|asm/tests/test_chacha20_avx512.c|rktcrypto_chacha20.c rktcrypto_cpu.c rktcrypto_x86.c rktcrypto_aead.c rktcrypto_poly1305.c rktcrypto_gcm.c rktcrypto_aes_modes.c rktcrypto_ccm.c rktcrypto_ct.c
poly1305_x86|rktcrypto_poly1305_x86.S|asm/tests/test_poly1305_x86.c|rktcrypto_poly1305.c rktcrypto_chacha20.c rktcrypto_cpu.c rktcrypto_x86.c rktcrypto_aead.c rktcrypto_gcm.c rktcrypto_aes_modes.c rktcrypto_ccm.c rktcrypto_ct.c
chacha20poly1305_x86|rktcrypto_chacha20poly1305_x86.S|asm/tests/test_chacha20poly1305_x86.c|rktcrypto_poly1305.c rktcrypto_chacha20.c rktcrypto_cpu.c rktcrypto_x86.c rktcrypto_aead.c rktcrypto_gcm.c rktcrypto_aes_modes.c rktcrypto_ccm.c rktcrypto_ct.c
p256_mul_x86|rktcrypto_p256_mul_x86.S|asm/tests/test_p256_x86.c|rktcrypto_*.c
keccak_avx512|rktcrypto_keccak_avx512.S|asm/tests/test_keccak_x86.c|rktcrypto_cpu.c rktcrypto_x86.c
keccak_scalar|rktcrypto_keccak_scalar.S|asm/tests/test_keccak_x86.c|rktcrypto_cpu.c rktcrypto_x86.c
sha512_x86|rktcrypto_sha512_x86.S|asm/tests/test_sha512_x86.c|rktcrypto_sha512.c rktcrypto_cpu.c rktcrypto_x86.c
sha512_avx512|rktcrypto_sha512_avx512.S|asm/tests/test_sha512_x86.c|rktcrypto_sha512.c rktcrypto_cpu.c rktcrypto_x86.c
ed25519_x86|rktcrypto_x25519_x86.S|asm/tests/test_ed25519_x86.c|rktcrypto_ed25519.c rktcrypto_sha512.c rktcrypto_cpu.c rktcrypto_x86.c|asm/x86/x25519_x86.asm
x25519_x86|rktcrypto_x25519_x86.S|asm/tests/test_x25519_x86.c|rktcrypto_x25519.c rktcrypto_cpu.c rktcrypto_x86.c
poly1305_sse2|rktcrypto_poly1305_sse2.S|asm/tests/test_poly1305_x86.c|rktcrypto_poly1305.c rktcrypto_chacha20.c rktcrypto_cpu.c rktcrypto_x86.c rktcrypto_aead.c rktcrypto_gcm.c rktcrypto_aes_modes.c rktcrypto_ccm.c rktcrypto_ct.c
poly1305_avx2|rktcrypto_poly1305_avx2.S|asm/tests/test_poly1305_x86.c|rktcrypto_poly1305.c rktcrypto_chacha20.c rktcrypto_cpu.c rktcrypto_x86.c rktcrypto_aead.c rktcrypto_gcm.c rktcrypto_aes_modes.c rktcrypto_ccm.c rktcrypto_ct.c
poly1305_ifma|rktcrypto_poly1305_ifma.S|asm/tests/test_poly1305_x86.c|rktcrypto_poly1305.c rktcrypto_chacha20.c rktcrypto_cpu.c rktcrypto_x86.c rktcrypto_aead.c rktcrypto_gcm.c rktcrypto_aes_modes.c rktcrypto_ccm.c rktcrypto_ct.c
'
rows() { echo "$TABLE" | grep -v '^$' | { if [ -n "${1:-}" ]; then grep "^$1|"; else cat; fi; }; }
NL='
'
gen() { # $1=kernel $2=out  (a row's fifth column names the .asm when it is not asm/x86/<kernel>.asm)
  src=$(rows "$1" | cut -d'|' -f5); [ -n "$src" ] || src="asm/x86/$1.asm"
  ( cd "$ROOT" && "$RACKET" "$RKTASM" ${RT:+--roundtrip} -o "$2" "$src" )
}
cmd=${1:-}; k=${2:-}
# emitted .asm sources: kernel | emitter (run from racket/src/crypto, output path as its argument)
GENSRC="gcm_vaes|asm/gen/gcm-vaes-x86.rkt
gcm_aesni|asm/gen/gcm-aesni-x86.rkt
gcm_aesni_sse|asm/gen/gcm-aesni-x86.rkt --sse"

case "$cmd" in
  list) rows | cut -d'|' -f1 ;;
  gensrc)
    rc=0
    IFS=$NL; for row in $GENSRC; do IFS=' 	$NL'
      kk=$(echo "$row" | cut -d'|' -f1); emitter=$(echo "$row" | cut -d'|' -f2); src="asm/x86/$kk.asm"
      if [ "$k" = "--write" ]; then ( cd "$ROOT" && "$RACKET" $emitter "$src" ) && echo "gensrc($kk): wrote $src"; continue; fi
      tmp=$(mktemp "${TMPDIR:-/tmp}/rktasm-x86-gensrc.XXXXXX")
      if ( cd "$ROOT" && "$RACKET" $emitter "$tmp" ) && cmp -s "$tmp" "$ROOT/$src"; then echo "gensrc($kk): byte-identical $src"
      else echo "gensrc($kk): DIFFERS from committed $src (emitter $emitter)"; rc=1; fi
      rm -f "$tmp"
    done; exit $rc ;;
  regen)
    [ -n "$k" ] || { echo "regen needs a kernel"; exit 2; }
    row=$(rows "$k"); [ -n "$row" ] || { echo "unknown kernel $k"; exit 2; }
    out=$(echo "$row" | cut -d'|' -f2)
    gen "$k" "$ROOT/$out" && echo "regen($k): wrote $out" ;;
  check)
    rc=0
    IFS=$NL; for row in $(rows "$k"); do IFS=' 	$NL'
      kk=$(echo "$row" | cut -d'|' -f1); out=$(echo "$row" | cut -d'|' -f2)
      tmp=$(mktemp "${TMPDIR:-/tmp}/rktasm-x86-check.XXXXXX")
      if gen "$kk" "$tmp" && cmp -s "$tmp" "$ROOT/$out"; then echo "check($kk): byte-identical $out"
      else echo "check($kk): DIFFERS from committed $out"; rc=1; fi
      rm -f "$tmp"
    done; exit $rc ;;
  gate)
    case "$(uname -s)-$(uname -m)" in Linux-x86_64) ;; *) echo "gate: needs x86-64 Linux (got $(uname -s)-$(uname -m))"; exit 2 ;; esac
    rc=0
    IFS=$NL; for row in $(rows "$k"); do IFS=' 	$NL'
      kk=$(echo "$row" | cut -d'|' -f1); out=$(echo "$row" | cut -d'|' -f2)
      h=$(echo "$row" | cut -d'|' -f3); deps=$(echo "$row" | cut -d'|' -f4)
      bin=$(mktemp "${TMPDIR:-/tmp}/rktasm-x86-gate.XXXXXX")
      alls=$(rows | cut -d'|' -f2 | sort -u | tr '\n' ' ')   # two rows may share one .S
      if ( cd "$ROOT" && $CC -O2 -I. -o "$bin" "$h" $alls $deps ) && "$bin" > "$bin.txt" 2>&1; then
        echo "gate($kk): PASS  $(grep -c '^BENCH' "$bin.txt") BENCH line(s)"; grep '^BENCH\|mismatches' "$bin.txt" | sed 's/^/  /'
      else echo "gate($kk): FAIL"; sed 's/^/  /' "$bin.txt" 2>/dev/null | tail -8; rc=1; fi
      rm -f "$bin" "$bin.txt"
    done; exit $rc ;;
  *) echo "usage: regen-x86.sh {regen <kernel> | check [kernel] | gate [kernel] | gensrc [--write] | list}"; exit 2 ;;
esac
