#!/bin/bash
# P33_PREHEAT=none stability: 6 full A+B pairs (project stability bar).
# Per-pair driver logs preserved as /tmp/none6-{a,b}drv-$j.log for forensics.
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
cd $SP/p3
rm -f /tmp/none6-sum /tmp/none6-mark
for j in 1 2 3 4 5 6; do
  echo "=== none #$j ===" >> /tmp/none6-sum
  rm -f $SP/p3/p3.3a.log $SP/p3/p3.3b.log
  RACKET_RETAIN_STATIC_RELOC=1 P33_LIBID=1 P33_XREPL=full P33_PREHEAT=none P33_ROLE=A $RK -q -n -t p3.3-run.rkt > /tmp/none6-a-$j.log 2>&1 \
  && RACKET_RETAIN_STATIC_RELOC=1 P33_LIBID=1 P33_XREPL=full P33_PREHEAT=none P33_ROLE=B $RK -q -n -t p3.3-run.rkt > /tmp/none6-b-$j.log 2>&1
  echo "pair-exit: $?" >> /tmp/none6-sum
  cp $SP/p3/p3.3a.log /tmp/none6-adrv-$j.log 2>/dev/null
  cp $SP/p3/p3.3b.log /tmp/none6-bdrv-$j.log 2>/dev/null
  ls -l $SP/p3/seg4z-state.fasl | awk '{print "state.fasl bytes: " $5}' >> /tmp/none6-sum
  tail -1 /tmp/none6-b-$j.log | sed 's/^/B-last: /' >> /tmp/none6-sum
  grep -a 'FATAL' $SP/p3/p3.3a.log >> /tmp/none6-sum 2>/dev/null
  grep -a 'SUMMARY\|extended diag\|(zoclo\|FATAL' $SP/p3/p3.3b.log >> /tmp/none6-sum 2>/dev/null
done
echo DONE > /tmp/none6-mark
