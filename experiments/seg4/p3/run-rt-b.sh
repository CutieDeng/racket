#!/bin/bash
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
cd $SP/p3
rm -f /tmp/rtb-mark $SP/p3/p3.3b.log $SP/p3/p3.3b.prog
P33_PREHEAT=none P33_CODEFASL=1 RACKET_RETAIN_STATIC_RELOC=1 P33_XREPL=full P33_ROLE=B $RK -q -n -t p3.3-run.rkt > /tmp/rtb.log 2>&1
echo "B-exit: $?" > /tmp/rtb-sum
tail -3 /tmp/rtb.log >> /tmp/rtb-sum
echo "--PROG--" >> /tmp/rtb-sum
cat $SP/p3/p3.3b.prog >> /tmp/rtb-sum 2>/dev/null
grep -a 'SUMMARY\|extended diag\|FATAL' $SP/p3/p3.3b.log >> /tmp/rtb-sum 2>/dev/null
echo DONE > /tmp/rtb-mark
