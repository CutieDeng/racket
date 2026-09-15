#!/bin/bash
# 7.2.1 targeted-preheat experiment: control (workload) / force / both.
# Per config: full A+B pair, record verdicts + state.fasl size + preheat lines.
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
cd $SP/p3
rm -f /tmp/ph-sum /tmp/ph-mark
for mode in workload force both; do
  echo "=== mode=$mode ===" >> /tmp/ph-sum
  rm -f $SP/p3/p3.3a.log $SP/p3/p3.3b.log
  RACKET_RETAIN_STATIC_RELOC=1 P33_LIBID=1 P33_XREPL=full P33_PREHEAT=$mode P33_ROLE=A $RK -q -n -t p3.3-run.rkt > /tmp/ph-a-$mode.log 2>&1 \
  && RACKET_RETAIN_STATIC_RELOC=1 P33_LIBID=1 P33_XREPL=full P33_PREHEAT=$mode P33_ROLE=B $RK -q -n -t p3.3-run.rkt > /tmp/ph-b-$mode.log 2>&1
  echo "pair-exit: $?" >> /tmp/ph-sum
  grep -a 'preheat' /tmp/ph-a-$mode.log >> /tmp/ph-sum 2>/dev/null
  ls -l $SP/p3/seg4z-state.fasl | awk '{print "state.fasl bytes: " $5}' >> /tmp/ph-sum
  grep -a 'FATAL' $SP/p3/p3.3a.log >> /tmp/ph-sum 2>/dev/null
  grep -a 'SUMMARY\|extended diag\|(zoclo\|FATAL' $SP/p3/p3.3b.log >> /tmp/ph-sum 2>/dev/null
done
echo DONE > /tmp/ph-mark
