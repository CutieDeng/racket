#!/bin/bash
# ===== Fourth-boot-segment build-time generator (M1 prototype) =====
# Runs the A role of the segment protocol against a built racket and
# leaves the segment artifacts in the output directory, then smoke-tests
# them with a B-role load.  Configuration is the recommended green-none
# line (no RETAIN, no LIBID, no preheat).
#
# Usage: gen-seg4.sh <racket-executable> <output-dir>
#
# Artifacts (under <output-dir>/p3/):
#   seg4z-state.fasl          the namespace-state segment
#   seg4z-externals.manifest  external-object naming table
#   seg4z-zolist.fasl         zo event list (B code supply via replay)
#   seg4z-patch.rktd          textual patch digest
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
RK="${1:?usage: gen-seg4.sh <racket-executable> <output-dir>}"
OUT="${2:?usage: gen-seg4.sh <racket-executable> <output-dir>}"

mkdir -p "$OUT/p3"
cp "$SRC/p1.engine.ss" "$SRC/p1.engine-suppl.ss" "$SRC/p1.head.ss" \
   "$SRC/p2.writeset.ss" "$OUT/"
cp "$SRC/p3/"*.ss "$SRC/p3/"*.rkt "$OUT/p3/"

export P33_SP="$OUT"
cd "$OUT/p3"

P33_PREHEAT=none P33_XREPL=full P33_ROLE=A "$RK" -q -n -t p3.3-run.rkt \
  > "$OUT/gen-a.log" 2>&1
echo "A exit: $?"
ls -l "$OUT"/p3/seg4z-* | awk '{print "  " $5 " " $9}'

P33_PREHEAT=none P33_XREPL=full P33_ROLE=B "$RK" -q -n -t p3.3-run.rkt \
  > "$OUT/gen-b.log" 2>&1
echo "B exit: $?"
grep -a 'SUMMARY\|extended diag' "$OUT/p3/p3.3b.log"
