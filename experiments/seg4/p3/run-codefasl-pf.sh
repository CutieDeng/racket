#!/bin/bash
# P33_CODEFASL experiment: green-none pair with native codes fasl supply.
# A also writes seg4z-codes.fasl; B reads it instead of replaying 330 .zo.
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
export P33_SP=$SP
cd $SP/p3
rm -f /tmp/cf-sum /tmp/cf-mark /tmp/cf-b.prog /tmp/cf-a.log /tmp/cf-b.log $SP/p3/p3.3a.prog $SP/p3/p3.3b.prog $SP/p3/p3.3a.log $SP/p3/p3.3b.log $SP/p3/seg4z-codes.fasl $SP/p3/seg4z-codes.manifest
P33_PREHEAT=none P33_CODEFASL=1 P33_CF_PREFAB=1 P33_XREPL=full P33_ROLE=A $RK -q -n -t p3.3-run.rkt > /tmp/cf-a.log 2>&1 \
&& P33_PREHEAT=none P33_CODEFASL=1 P33_CF_PREFAB=1 P33_XREPL=full P33_ROLE=B $RK -q -n -t p3.3-run.rkt > /tmp/cf-b.log 2>&1
echo "pair-exit: $?" > /tmp/cf-sum
grep -a 'codes fasl written' $SP/p3/p3.3a.log >> /tmp/cf-sum 2>/dev/null
ls -l $SP/p3/seg4z-codes.fasl 2>/dev/null | awk '{print "codes.fasl bytes: " $5}' >> /tmp/cf-sum
grep -a 'native codes fasl\|SUMMARY\|extended diag\|FATAL\|MISMATCH' $SP/p3/p3.3b.log >> /tmp/cf-sum 2>/dev/null
rm -f /tmp/cf-b.prog; cp $SP/p3/p3.3b.prog /tmp/cf-b.prog 2>/dev/null
tail -1 /tmp/cf-b.log | sed 's/^/B-last: /' >> /tmp/cf-sum
echo DONE > /tmp/cf-mark
