#!/bin/bash
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad
export P33_SP=$SP
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
cd $SP/p3
rm -f /tmp/gcevo-mark $SP/p3/p3.3b.log
P33_PREHEAT=none P33_CODEFASL=1 P33_CF_GCEVO=1 RACKET_RETAIN_STATIC_RELOC=1 P33_XREPL=full P33_ROLE=B $RK -q -n -t p3.3-run.rkt > /tmp/gcevo-b.log 2>&1
echo "B-exit: $?" > /tmp/gcevo-sum
grep -a "GCEVO\|drift\|SUMMARY\|extended diag" $SP/p3/p3.3b.log >> /tmp/gcevo-sum 2>/dev/null
tail -2 /tmp/gcevo-b.log >> /tmp/gcevo-sum
echo DONE > /tmp/gcevo-mark
