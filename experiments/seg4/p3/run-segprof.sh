#!/bin/bash
# A-only green-none run with per-slot segment size profile (P33_SEGPROF=1)
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
cd $SP/p3
rm -f /tmp/segprof-mark $SP/p3/p3.3a.log
P33_PREHEAT=none P33_XREPL=full P33_SEGPROF=1 P33_ROLE=A $RK -q -n -t p3.3-run.rkt > /tmp/segprof-a.log 2>&1
echo "A-exit: $?" > /tmp/segprof-sum
grep -a 'segprof\|write iter' $SP/p3/p3.3a.log >> /tmp/segprof-sum 2>/dev/null
echo DONE > /tmp/segprof-mark
