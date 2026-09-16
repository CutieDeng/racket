#!/bin/bash
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
export P33_SP=$SP
cd $SP/p3
rm -f /tmp/hlldb-mark /tmp/hlldb-hit
export P33_PREHEAT=none P33_CODEFASL=1 P33_CF_GCSTRESS=1 RACKET_RETAIN_STATIC_RELOC=1 P33_XREPL=full P33_ROLE=B
for j in $(seq 1 6); do
  lldb --batch \
    -o "settings set target.disable-aslr false" \
    -o "breakpoint set -f gcwrapper.c -l 590" \
    -o run \
    -o "bt 12" \
    -o "frame variable pp p seg base s aftergc" \
    -o "memory read -f x -s 8 -c 8 \`((unsigned long)pp) & ~63\`" \
    -o quit -- $RK -q -n -t p3.3-run.rkt > /tmp/hlldb-$j.log 2>&1
  if grep -q "stop reason = breakpoint" /tmp/hlldb-$j.log; then
    echo "HIT at $j" > /tmp/hlldb-hit
    grep -B2 -A 40 "stop reason = breakpoint" /tmp/hlldb-$j.log | head -60 >> /tmp/hlldb-hit
    break
  fi
done
echo DONE > /tmp/hlldb-mark
