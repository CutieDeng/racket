#!/bin/bash
# green-none timing pair (P33_PROBES=0): B-side section timings
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
export P33_SP=$SP
cd $SP/p3
rm -f /tmp/gnt-mark /tmp/gnt-sum $SP/p3/p3.3a.log $SP/p3/p3.3b.log
P33_PREHEAT=none P33_XREPL=full P33_PROBES=0 P33_ROLE=A $RK -q -n -t p3.3-run.rkt > /tmp/gnt-a.log 2>&1 \
&& P33_PREHEAT=none P33_XREPL=full P33_PROBES=0 P33_ROLE=B $RK -q -n -t p3.3-run.rkt > /tmp/gnt-b.log 2>&1
echo "pair-exit: $?" > /tmp/gnt-sum
grep -a 'ms\|cpu=\|fasl-read' $SP/p3/p3.3b.log | tail -30 >> /tmp/gnt-sum 2>/dev/null
grep -a 'driver body done\|mark point ready' /tmp/gnt-b.log >> /tmp/gnt-sum 2>/dev/null
echo DONE > /tmp/gnt-mark
