#!/bin/bash
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
export P33_SP=$SP
cd $SP/p3
rm -f /tmp/k4-mark $SP/p3/p3.3a.log
P33_PREHEAT=none P33_CODEFASL=1 P33_CF_K4=1 RACKET_RETAIN_STATIC_RELOC=1 P33_XREPL=full P33_ROLE=A $RK -q -n -t p3.3-run.rkt > /tmp/k4-a.log 2>&1
echo "A-exit: $?" > /tmp/k4-sum
grep -a "kind-4\|k4-big\|codes fasl" $SP/p3/p3.3a.log >> /tmp/k4-sum 2>/dev/null
echo DONE > /tmp/k4-mark
