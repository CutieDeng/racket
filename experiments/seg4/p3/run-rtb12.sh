#!/bin/bash
# RETAIN-walk crash rate: 12 B-only runs against the same A products.
# Each run keeps its prog file (crash phase evidence).
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
export P33_SP=$SP
cd $SP/p3
rm -f /tmp/rtb12-sum /tmp/rtb12-mark
for j in 1 2 3 4 5 6 7 8 9 10 11 12; do
  rm -f $SP/p3/p3.3b.log $SP/p3/p3.3b.prog
  P33_PREHEAT=none P33_CODEFASL=1 RACKET_RETAIN_STATIC_RELOC=1 P33_XREPL=full P33_ROLE=B $RK -q -n -t p3.3-run.rkt > /tmp/rtb12-$j.log 2>&1
  ec=$?
  last=$(tail -1 $SP/p3/p3.3b.prog 2>/dev/null)
  echo "#$j exit=$ec last-phase=[$last]" >> /tmp/rtb12-sum
  cp $SP/p3/p3.3b.prog /tmp/rtb12-prog-$j 2>/dev/null
done
echo DONE > /tmp/rtb12-mark
