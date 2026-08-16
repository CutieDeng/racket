#!/bin/bash
# run-suite.sh — one command to run the library-level conformance tests that
# link the whole librktcrypto archive (KAT / interop / roundtrip / tamper), and
# then the kernel differential+perf gates via regen.sh. These library-level
# tests were previously "compile and run by hand" only; this makes them a single
# gate so a broken RSA/curve/PQC/KDF/X.509 path is caught automatically.
#
#   asm/tests/run-suite.sh              # build librktcrypto if needed, run all
#   asm/tests/run-suite.sh lib          # library-level tests only
#   asm/tests/run-suite.sh kernels      # regen.sh gate (asm differential) only
#
# The archive is taken from the in-tree build; if absent, run `make in-place`
# (or set LIB=/path/to/librktcrypto.a).

set -uo pipefail
cd "$(dirname "$0")/../.."               # crypto/ root
BUILD=../build/cs/c/rktcrypto
LIB=${LIB:-$(ls "$BUILD"/librktcrypto.a 2>/dev/null || true)}

# library-level tests: each links ONLY the archive (no stubs), includes
# rktcrypto.h, prints a final "ALL PASS"/"FAILURES" line and exits nonzero on
# failure.
LIB_TESTS="test_brainpool_ecdsa test_rsa test_curves_extra test_pqc_extra test_kdf_aesmodes test_x509_cms test_ecdsa_edge test_rsa_edge"

run_lib() {
  if [ -z "$LIB" ] || [ ! -f "$LIB" ]; then
    echo "librktcrypto.a not found under $BUILD — run 'make in-place' first (or set LIB=...)."; return 2
  fi
  local fail=0 t src bin
  for t in $LIB_TESTS; do
    src="asm/tests/$t.c"
    if [ ! -f "$src" ]; then printf '  %-24s SKIP (no source yet)\n' "$t"; continue; fi
    bin=$(mktemp)
    if ! cc -O2 -I. -o "$bin" "$src" "$LIB" 2>/tmp/rs_cc.$$; then
      printf '  %-24s BUILD-FAIL\n' "$t"; sed 's/^/      /' /tmp/rs_cc.$$ | head -6; rm -f "$bin" /tmp/rs_cc.$$; fail=1; continue
    fi
    rm -f /tmp/rs_cc.$$
    if "$bin" >/tmp/rs_out.$$ 2>&1; then
      printf '  %-24s PASS\n' "$t"
    else
      printf '  %-24s FAIL\n' "$t"; sed 's/^/      /' /tmp/rs_out.$$ | tail -8; fail=1
    fi
    rm -f "$bin" /tmp/rs_out.$$
  done
  return $fail
}

cmd=${1:-all}
rc=0
case "$cmd" in
  lib)     echo "== library-level conformance =="; run_lib || rc=$? ;;
  kernels) echo "== kernel differential+perf gate =="; bash asm/regen.sh gate || rc=$? ;;
  all)
    echo "== library-level conformance (archive-linked) =="
    run_lib || rc=$?
    echo "== kernel differential+perf gate (regen.sh) =="
    bash asm/regen.sh gate || rc=$?
    ;;
  *) echo "usage: run-suite.sh {all|lib|kernels}"; exit 2 ;;
esac
echo "----"
[ $rc -eq 0 ] && echo "SUITE OK" || echo "SUITE FAIL (rc=$rc)"
exit $rc
