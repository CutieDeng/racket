#!/bin/bash
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M07-D16-racket-feat-swisstable/d5d1ca89-29ba-48e9-9226-2d4a258a56cd/scratchpad
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
cd $SP/p3
rm -f /tmp/d106-sum
for j in 1 2 3 4 5 6; do
  RACKET_RETAIN_STATIC_RELOC=1 P33_LIBID=1 P33_XREPL=full P33_ROLE=A $RK -q -n -t p3.3-run.rkt > /tmp/d106-a$j.log 2>&1 \
  && RACKET_RETAIN_STATIC_RELOC=1 P33_LIBID=1 P33_XREPL=full P33_ROLE=B $RK -q -n -t p3.3-run.rkt > /tmp/d106-b$j.log 2>&1
  echo "pair$j: $?" >> /tmp/d106-sum
  grep -a 'SUMMARY\|extended diag' $SP/p3/p3.3b.log >> /tmp/d106-sum 2>/dev/null
done
echo DONE > /tmp/d106-mark
