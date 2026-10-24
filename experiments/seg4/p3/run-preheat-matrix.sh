#!/bin/bash
# 7.2.1 stability matrix: workload x3 / none x3 / force x3 (full A+B pairs).
# Questions: does true force work now; is no-preheat green reproducible;
# does workload mode carry a 1/3 late-diagnostic crash.
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
export P33_SP=$SP
cd $SP/p3
rm -f /tmp/phm-sum /tmp/phm-mark
for mode in workload none force; do
  for j in 1 2 3; do
    echo "=== $mode #$j ===" >> /tmp/phm-sum
    rm -f $SP/p3/p3.3a.log $SP/p3/p3.3b.log
    RACKET_RETAIN_STATIC_RELOC=1 P33_LIBID=1 P33_XREPL=full P33_PREHEAT=$mode P33_ROLE=A $RK -q -n -t p3.3-run.rkt > /tmp/phm-a.log 2>&1 \
    && RACKET_RETAIN_STATIC_RELOC=1 P33_LIBID=1 P33_XREPL=full P33_PREHEAT=$mode P33_ROLE=B $RK -q -n -t p3.3-run.rkt > /tmp/phm-b.log 2>&1
    echo "pair-exit: $?" >> /tmp/phm-sum
    grep -a 'preheat' /tmp/phm-a.log >> /tmp/phm-sum 2>/dev/null
    ls -l $SP/p3/seg4z-state.fasl | awk '{print "state.fasl bytes: " $5}' >> /tmp/phm-sum
    tail -1 /tmp/phm-b.log | sed 's/^/B-last: /' >> /tmp/phm-sum
    grep -a 'FATAL' $SP/p3/p3.3a.log >> /tmp/phm-sum 2>/dev/null
    grep -a 'SUMMARY\|extended diag\|(zoclo\|FATAL' $SP/p3/p3.3b.log >> /tmp/phm-sum 2>/dev/null
  done
done
echo DONE > /tmp/phm-mark
