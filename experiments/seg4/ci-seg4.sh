#!/bin/bash
# ===== Fourth-boot-segment integration guard =====
# Layered watch for the segment work; run after the matching change class.
#
#   L1  kernel fasl layer   (after make base): p73 battery + fasl/vector/pvector suites
#   L2  apparatus layer     (after seg4 edits): gen-seg4.sh end-to-end, full marks required
#   L3  stability layer     (milestones/nightly): N green-none pairs + N codes B-only runs,
#                           crash-rate report against the recorded baselines
#   L4  timing layer        (milestones): PROBES=0 phase extraction
#
# Usage: ci-seg4.sh <racket-executable> <workdir> [L1|L2|L3|L4|all] [N]
# Baselines (2026-09-16): green-none crash 0/15; codes line crash ~1/6 (fail-stop,
# apparatus-local, see the log D157-D162); B restore chain ~193ms gross.
set -u
SRC="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$SRC/../.." && pwd)"
RK="${1:?usage: ci-seg4.sh <racket> <workdir> [layer] [N]}"
WD="${2:?usage: ci-seg4.sh <racket> <workdir> [layer] [N]}"
LAYER="${3:-all}"
N="${4:-6}"
mkdir -p "$WD"
FAIL=0
note() { echo "== $*"; }
verdict() { # verdict <name> <ok?> <detail>
  if [ "$2" = ok ]; then echo "PASS  $1  $3"; else echo "FAIL  $1  $3"; FAIL=1; fi
}

run_L1() {
  note "L1 kernel fasl layer"
  out=$("$RK" -q -n -t "$SRC/p73-code-roundtrip.rkt" 2>&1)
  echo "$out" | grep -q "FAIL" && verdict p73 bad "$out" || verdict p73 ok "10 checks"
  for s in fasl vector pvector; do
    (cd "$REPO/pkgs/racket-test-core/tests/racket" \
      && "$RK" -q -f $s.rktl > "$WD/ci-$s.log" 2>&1)
    if [ $? -eq 0 ]; then verdict "suite-$s" ok "exit 0"; else verdict "suite-$s" bad "see $WD/ci-$s.log"; fi
  done
}

run_L2() {
  note "L2 apparatus layer (gen-seg4 end-to-end)"
  rm -rf "$WD/l2"
  out=$(bash "$SRC/gen-seg4.sh" "$RK" "$WD/l2" 2>&1)
  if echo "$out" | grep -q "pass=11 fail=0" && echo "$out" | grep -q "ok=12 fail=0"; then
    verdict gen-seg4 ok "11/11 + 12/12"
  else
    verdict gen-seg4 bad "$(echo "$out" | tail -3 | tr '\n' ' ')"
  fi
}

run_L3() {
  note "L3 stability layer (N=$N per line)"
  rm -rf "$WD/l3"; bash "$SRC/gen-seg4.sh" "$RK" "$WD/l3" > /dev/null 2>&1
  export P33_SP="$WD/l3"
  cd "$WD/l3/p3"
  gn_bad=0
  for j in $(seq 1 "$N"); do
    P33_PREHEAT=none P33_XREPL=full P33_ROLE=A "$RK" -q -n -t p3.3-run.rkt > /dev/null 2>&1 \
      && P33_PREHEAT=none P33_XREPL=full P33_ROLE=B "$RK" -q -n -t p3.3-run.rkt > /dev/null 2>&1 \
      || gn_bad=$((gn_bad+1))
  done
  [ "$gn_bad" -eq 0 ] && verdict green-none-x$N ok "0 crashes (baseline 0/15)" \
                      || verdict green-none-x$N bad "$gn_bad/$N crashed (baseline 0/15)"
  # codes line: crash rate is WATCHED, not gated (known apparatus-local draw)
  P33_PREHEAT=none P33_CODEFASL=1 RACKET_RETAIN_STATIC_RELOC=1 P33_XREPL=full P33_ROLE=A \
    "$RK" -q -n -t p3.3-run.rkt > /dev/null 2>&1
  cf_bad=0
  for j in $(seq 1 "$N"); do
    P33_PREHEAT=none P33_CODEFASL=1 RACKET_RETAIN_STATIC_RELOC=1 P33_XREPL=full P33_ROLE=B \
      "$RK" -q -n -t p3.3-run.rkt > /dev/null 2>&1 || cf_bad=$((cf_bad+1))
  done
  echo "WATCH codes-line-x$N  $cf_bad/$N crashed (known draw baseline ~1/6..1/3; investigate only on a JUMP)"
}

run_L4() {
  note "L4 timing layer"
  rm -rf "$WD/l4"; bash "$SRC/gen-seg4.sh" "$RK" "$WD/l4" > /dev/null 2>&1
  export P33_SP="$WD/l4"
  cd "$WD/l4/p3"
  rm -f p3.3b.prog
  P33_PREHEAT=none P33_XREPL=full P33_PROBES=0 P33_ROLE=A "$RK" -q -n -t p3.3-run.rkt > /dev/null 2>&1
  P33_PREHEAT=none P33_XREPL=full P33_PROBES=0 P33_ROLE=B "$RK" -q -n -t p3.3-run.rkt > /dev/null 2>&1
  echo "-- B phase timeline (baseline: restore chain ~193ms gross):"
  cat p3.3b.prog 2>/dev/null | sed 's/^/   /'
}

case "$LAYER" in
  L1) run_L1 ;;
  L2) run_L2 ;;
  L3) run_L3 ;;
  L4) run_L4 ;;
  all) run_L1; run_L2; run_L3; run_L4 ;;
  *) echo "unknown layer: $LAYER"; exit 2 ;;
esac
exit $FAIL
