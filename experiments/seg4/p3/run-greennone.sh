#!/bin/bash
# green-none line: P33_PREHEAT=none WITHOUT RACKET_RETAIN_STATIC_RELOC / P33_LIBID.
# Tests whether post-zoclo the staddr/dwseq/retain machinery is still needed
# for extended 12/12, and whether dropping it removes the stale-slot variance.
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
export P33_SP=$SP
cd $SP/p3
rm -f /tmp/gn-sum /tmp/gn-mark
for j in 1 2 3; do
  echo "=== green-none #$j ===" >> /tmp/gn-sum
  rm -f $SP/p3/p3.3a.log $SP/p3/p3.3b.log
  P33_PREHEAT=none P33_XREPL=full P33_ROLE=A $RK -q -n -t p3.3-run.rkt > /tmp/gn-a-$j.log 2>&1 \
  && P33_PREHEAT=none P33_XREPL=full P33_ROLE=B $RK -q -n -t p3.3-run.rkt > /tmp/gn-b-$j.log 2>&1
  echo "pair-exit: $?" >> /tmp/gn-sum
  cp $SP/p3/p3.3b.log /tmp/gn-bdrv-$j.log 2>/dev/null
  ls -l $SP/p3/seg4z-state.fasl | awk '{print "state.fasl bytes: " $5}' >> /tmp/gn-sum
  tail -1 /tmp/gn-b-$j.log | sed 's/^/B-last: /' >> /tmp/gn-sum
  grep -a 'SUMMARY\|extended diag\|(zoclo\|FATAL' $SP/p3/p3.3b.log >> /tmp/gn-sum 2>/dev/null
done
echo DONE > /tmp/gn-mark
