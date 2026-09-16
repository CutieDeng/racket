#!/bin/bash
# prefab desync quadrant: A-only self-read with prefab off/on
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
export P33_SP=$SP
cd $SP/p3
rm -f /tmp/quad-mark /tmp/quad-sum
for pf in 0 1; do
  echo "=== prefab=$pf ===" >> /tmp/quad-sum
  rm -f $SP/p3/p3.3a.log
  P33_PREHEAT=none P33_CODEFASL=1 P33_CF_SELFRD=1 P33_CF_PREFAB=$pf P33_XREPL=full P33_ROLE=A $RK -q -n -t p3.3-run.rkt > /tmp/quad-a-$pf.log 2>&1
  echo "A-exit: $?" >> /tmp/quad-sum
  grep -a "codes fasl" $SP/p3/p3.3a.log >> /tmp/quad-sum 2>/dev/null
done
echo DONE > /tmp/quad-mark
