#!/bin/bash
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
cd $SP/p3
rm -f /tmp/b12-mark /tmp/b12-sum
for j in $(seq 1 12); do
  rm -f $SP/p3/p3.3b.log
  P33_PREHEAT=none P33_CODEFASL=1 RACKET_RETAIN_STATIC_RELOC=1 P33_XREPL=full P33_ROLE=B $RK -q -n -t p3.3-run.rkt > /tmp/b12-$j.log 2>&1
  echo "#$j exit=$?" >> /tmp/b12-sum
done
echo DONE > /tmp/b12-mark
