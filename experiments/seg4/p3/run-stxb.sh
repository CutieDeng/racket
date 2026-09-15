#!/bin/bash
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
cd $SP/p3
rm -f /tmp/stxb-mark $SP/p3/p3.3b.log
RACKET_RETAIN_STATIC_RELOC=1 P33_LIBID=1 P33_XREPL=full P33_STX=1 P33_ROLE=B $RK -q -n -t p3.3-run.rkt > /tmp/stxb.log 2>&1
echo "B-exit: $?" > /tmp/stxb-sum
echo DONE > /tmp/stxb-mark
