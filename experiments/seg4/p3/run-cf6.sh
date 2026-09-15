#!/bin/bash
# codes.fasl line stability: 6 full pairs at the full-marks config
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
cd $SP/p3
rm -f /tmp/cf6-sum /tmp/cf6-mark
for j in 1 2 3 4 5 6; do
  echo "=== cf #$j ===" >> /tmp/cf6-sum
  rm -f $SP/p3/p3.3a.log $SP/p3/p3.3b.log
  P33_PREHEAT=none P33_CODEFASL=1 P33_XREPL=full P33_ROLE=A $RK -q -n -t p3.3-run.rkt > /tmp/cf6-a-$j.log 2>&1 \
  && P33_PREHEAT=none P33_CODEFASL=1 P33_XREPL=full P33_ROLE=B $RK -q -n -t p3.3-run.rkt > /tmp/cf6-b-$j.log 2>&1
  echo "pair-exit: $?" >> /tmp/cf6-sum
  cp $SP/p3/p3.3b.log /tmp/cf6-bdrv-$j.log 2>/dev/null
  tail -1 /tmp/cf6-b-$j.log | sed 's/^/B-last: /' >> /tmp/cf6-sum
  grep -a 'SUMMARY\|extended diag\|FATAL' $SP/p3/p3.3b.log >> /tmp/cf6-sum 2>/dev/null
done
echo DONE > /tmp/cf6-mark
