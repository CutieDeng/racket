#!/bin/bash
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/6ac99b69-12b6-486e-afc0-65901fa5c0ab/scratchpad/seg4
export P33_SP=$SP
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
cd $SP/p3
rm -f /tmp/port-mark $SP/p3/p3.3a.log $SP/p3/p3.3b.log
P33_PREHEAT=none P33_XREPL=full P33_ROLE=A $RK -q -n -t p3.3-run.rkt > /tmp/port-a.log 2>&1 \
&& P33_PREHEAT=none P33_XREPL=full P33_ROLE=B $RK -q -n -t p3.3-run.rkt > /tmp/port-b.log 2>&1
echo "pair-exit: $?" > /tmp/port-sum
grep -a 'SUMMARY\|extended diag' $SP/p3/p3.3b.log >> /tmp/port-sum 2>/dev/null
echo DONE > /tmp/port-mark
