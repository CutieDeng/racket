#!/bin/bash
# 灾后校准烟测：配方线 A/B 一对，A/B 退出码分别打标（纪律 §8.2）
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
cd $SP/p3
rm -f /tmp/pair1-sum /tmp/pair1-mark
RACKET_RETAIN_STATIC_RELOC=1 P33_LIBID=1 P33_XREPL=full P33_ROLE=A $RK -q -n -t p3.3-run.rkt > /tmp/pair1-a.log 2>&1
echo "A-exit: $?" >> /tmp/pair1-sum
RACKET_RETAIN_STATIC_RELOC=1 P33_LIBID=1 P33_XREPL=full P33_ROLE=B $RK -q -n -t p3.3-run.rkt > /tmp/pair1-b.log 2>&1
echo "B-exit: $?" >> /tmp/pair1-sum
grep -a 'SUMMARY\|VERDICT\|extended' $SP/p3/p3.3b.log >> /tmp/pair1-sum 2>/dev/null
echo DONE > /tmp/pair1-mark
