#!/bin/bash
# weak-structure audit x6 in the open poison window (NOCLEAR so the
# clearing collection does not close it first)
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad
export P33_SP=$SP
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
cd $SP/p3
rm -f /tmp/wa-mark /tmp/wa-sum
for j in $(seq 1 1); do
  rm -f $SP/p3/p3.3b.log
  P33_PREHEAT=none P33_CODEFASL=1 P33_CF_WEAKAUDIT=1 P33_CF_NOCLEAR=1 RACKET_RETAIN_STATIC_RELOC=1 P33_XREPL=full P33_ROLE=B $RK -q -n -t p3.3-run.rkt > /tmp/wa-$j.log 2>&1
  echo "#$j exit=$?" >> /tmp/wa-sum
  grep -a "WEAK-AUDIT\|GARBAGE\|SUMMARY" $SP/p3/p3.3b.log | head -60 >> /tmp/wa-sum 2>/dev/null
done
echo DONE > /tmp/wa-mark
