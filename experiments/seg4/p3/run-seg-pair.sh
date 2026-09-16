#!/bin/bash
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad
export P33_SP=$SP
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
cd $SP/p3
rm -f /tmp/segp-mark $SP/p3/p3.3a.log $SP/p3/p3.3b.log $SP/p3/seg4z-codes-*.fasl $SP/p3/seg4z-codes-*.manifest
P33_PREHEAT=none P33_CODEFASL=1 P33_CF_SEGMENTED=1 RACKET_RETAIN_STATIC_RELOC=1 P33_XREPL=full P33_ROLE=A $RK -q -n -t p3.3-run.rkt > /tmp/segp-a.log 2>&1 \
&& P33_PREHEAT=none P33_CODEFASL=1 P33_CF_SEGMENTED=1 RACKET_RETAIN_STATIC_RELOC=1 P33_XREPL=full P33_ROLE=B $RK -q -n -t p3.3-run.rkt > /tmp/segp-b.log 2>&1
echo "pair-exit: $?" > /tmp/segp-sum
grep -a "segmented codes supply\|SUMMARY\|extended diag\|FATAL" $SP/p3/p3.3b.log >> /tmp/segp-sum 2>/dev/null
ls $SP/p3/seg4z-codes-*.fasl 2>/dev/null | wc -l >> /tmp/segp-sum
tail -1 /tmp/segp-b.log >> /tmp/segp-sum
echo DONE > /tmp/segp-mark
