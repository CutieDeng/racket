#!/bin/bash
# GC-stress amplification: 8 B-only runs codes vs 4 zoreplay control
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
export P33_SP=$SP
cd $SP/p3
rm -f /tmp/gcs2-sum /tmp/gcs2-mark
for mode in codes zoreplay; do
  if [ $mode = codes ]; then CF=1; N=24; else CF=0; N=0; fi
  for j in $(seq 1 $N); do
    rm -f $SP/p3/p3.3b.log $SP/p3/p3.3b.prog
    P33_PREHEAT=none P33_CODEFASL=$CF RACKET_RETAIN_STATIC_RELOC=1 P33_XREPL=full P33_ROLE=B $RK -q -n -t p3.3-run.rkt > /tmp/gcs2-$mode-$j.log 2>&1
    ec=$?
    last=$(grep -ac '\[ok\]' $SP/p3/p3.3b.log 2>/dev/null)
    echo "$mode #$j exit=$ec oks=$last" >> /tmp/gcs2-sum
    if [ $ec -ne 0 ]; then
      cp $SP/p3/p3.3b.log /tmp/gcs2-crash-$mode-$j.log 2>/dev/null
    fi
  done
done
echo DONE > /tmp/gcs2-mark
