#!/bin/bash
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
export P33_SP=$SP
cd $SP/p3
rm -f /tmp/rtb24-sum /tmp/rtb24-mark
for mode in codes zoreplay; do
  if [ $mode = codes ]; then CF=1; else CF=0; fi
  for j in $(seq 1 12); do
    rm -f $SP/p3/p3.3b.log $SP/p3/p3.3b.prog
    P33_PREHEAT=none P33_CODEFASL=$CF RACKET_RETAIN_STATIC_RELOC=1 P33_XREPL=full P33_ROLE=B $RK -q -n -t p3.3-run.rkt > /tmp/rtb24-$mode-$j.log 2>&1
    ec=$?
    last=$(tail -1 $SP/p3/p3.3b.prog 2>/dev/null)
    echo "$mode #$j exit=$ec [$last]" >> /tmp/rtb24-sum
    if [ $ec -ne 0 ]; then
      cp $SP/p3/p3.3b.log /tmp/rtb24-crash-$mode-$j.log 2>/dev/null
      cp $SP/p3/p3.3b.prog /tmp/rtb24-crashprog-$mode-$j 2>/dev/null
    fi
  done
done
echo DONE > /tmp/rtb24-mark
