#!/bin/bash
# x86-conformance.sh — Phase E readiness: build librktcrypto for x86-64 (the
# pure-C paths, no AArch64 .S) and run the library-level conformance tests, to
# prove the x86 crypto is CORRECT before removing the bundled OpenSSL there.
#
# On Apple Silicon this cross-compiles for x86-64 and runs the test binaries
# under Rosetta; on a real x86-64 host it is a native build+run. Either way it
# answers "does the pure-C rktcrypto pass conformance on x86-64?" — the
# correctness gate that build-all.rkt's OpenSSL bundling was waiting on.
#
#   asm/tests/x86-conformance.sh
#
# (Performance parity vs OpenSSL — Phase E2 — is a separate, non-correctness
# question handled by crypto-benchmark.rkt.)

set -uo pipefail
cd "$(dirname "$0")/../.."               # crypto/ root
TARGET=${TARGET:-x86_64-apple-darwin}    # override for a Linux x86 CI toolchain
CC=${CC:-cc}
obj=$(mktemp -d); rc=0

echo "== building librktcrypto for $TARGET (pure-C; AArch64 .S self-disable) =="
nfail=0
for f in rktcrypto_*.c; do
  if ! "$CC" -target "$TARGET" -std=c11 -O2 -I. -c "$f" -o "$obj/${f%.c}.o" 2>"$obj/err"; then
    echo "  COMPILE-FAIL $f:"; sed 's/^/    /' "$obj/err" | grep -i error | head -3; nfail=$((nfail+1))
  fi
done
if [ $nfail -gt 0 ]; then echo "== $nfail file(s) failed to compile for $TARGET =="; rm -rf "$obj"; exit 1; fi
ar rc "$obj/librktcrypto.a" "$obj"/*.o 2>/dev/null
echo "  ok: $(ls "$obj"/*.o | wc -l | tr -d ' ') objects archived"

echo "== running library-level conformance on $TARGET =="
LIB_TESTS="test_brainpool_ecdsa test_rsa test_curves_extra test_pqc_extra test_kdf_aesmodes test_x509_cms test_ecdsa_edge test_rsa_edge"
for t in $LIB_TESTS; do
  bin="$obj/$t"
  if ! "$CC" -target "$TARGET" -O2 -I. -o "$bin" "asm/tests/$t.c" "$obj/librktcrypto.a" 2>"$obj/err"; then
    echo "  BUILD-FAIL $t"; sed 's/^/    /' "$obj/err" | grep -iE 'undefined|error' | head -3; rc=1; continue
  fi
  out=$("$bin" 2>&1 | tail -1)
  if echo "$out" | grep -qE "ALL PASS"; then printf "  PASS  %-24s (%s)\n" "$t" "$out"
  else printf "  FAIL  %-24s (%s)\n" "$t" "$out"; rc=1; fi
done

rm -rf "$obj"
echo "----"
[ $rc -eq 0 ] && echo "X86 CONFORMANCE OK — pure-C rktcrypto passes on $TARGET (OpenSSL removable, correctness-wise)" \
             || echo "X86 CONFORMANCE FAIL on $TARGET"
exit $rc
