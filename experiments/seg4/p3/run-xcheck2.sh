#!/bin/bash
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
cd $SP/p3
rm -f /tmp/xchk2-mark $SP/p3/p3.3b.log $SP/p3/p3.3b.prog
P33_PREHEAT=none P33_CODEFASL=1 P33_CF_XCHECK=2 RACKET_RETAIN_STATIC_RELOC=1 P33_XREPL=full P33_ROLE=B $RK -q -n -t p3.3-run.rkt > /tmp/xchk2-b.log 2>&1
echo "B-exit: $?" > /tmp/xchk2-sum
grep -a "XCHECK\|xdiff\|SUMMARY\|extended diag" $SP/p3/p3.3b.log >> /tmp/xchk2-sum 2>/dev/null
tail -2 /tmp/xchk2-b.log >> /tmp/xchk2-sum
echo DONE > /tmp/xchk2-mark
