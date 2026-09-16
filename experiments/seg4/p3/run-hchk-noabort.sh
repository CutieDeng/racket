#!/bin/bash
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
cd $SP/p3
rm -f /tmp/hna-mark /tmp/hna-sum
export CHEZ_CHECK_HEAP_NO_ABORT=1
for j in $(seq 1 6); do
  rm -f $SP/p3/p3.3b.log
  P33_PREHEAT=none P33_CODEFASL=1 P33_CF_GCSTRESS=1 RACKET_RETAIN_STATIC_RELOC=1 P33_XREPL=full P33_ROLE=B $RK -q -n -t p3.3-run.rkt > /tmp/hna-$j.log 2>&1
  ec=$?
  nd=$(grep -c "dangling" /tmp/hna-$j.log)
  echo "#$j exit=$ec dangling-reports=$nd" >> /tmp/hna-sum
done
echo DONE > /tmp/hna-mark
