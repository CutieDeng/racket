#!/bin/bash
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
cd $SP/p3
rm -f /tmp/hlldb2-mark /tmp/hlldb2-hit
export P33_PREHEAT=none P33_CODEFASL=1 P33_CF_GCSTRESS=1 RACKET_RETAIN_STATIC_RELOC=1 P33_XREPL=full P33_ROLE=B
for j in $(seq 1 8); do
  lldb --batch \
    -o "settings set target.disable-aslr false" \
    -o "breakpoint set -f gcwrapper.c -l 590" \
    -o run \
    -o "frame variable pp p" \
    -o "memory read -f x -s 8 -c 32 \`((unsigned long)pp) - 128\`" \
    -o "memory read -f c -s 1 -c 96 \`((unsigned long)pp) - 96\`" \
    -o "memory read -f x -s 8 -c 4 \`((unsigned long)p) & ~7\`" \
    -o quit -- $RK -q -n -t p3.3-run.rkt > /tmp/hlldb2-$j.log 2>&1
  if grep -q "stop reason = breakpoint" /tmp/hlldb2-$j.log; then
    echo "HIT at $j" > /tmp/hlldb2-hit
    grep -A 70 "frame variable" /tmp/hlldb2-$j.log | head -75 >> /tmp/hlldb2-hit
    break
  fi
done
echo DONE > /tmp/hlldb2-mark
