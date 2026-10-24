#!/bin/bash
# zoclo hardening regression: 3 A/B pairs; expects per pair:
#   pairN: 0, (zoclo . ok) : 3, SUMMARY pass=11 fail=0, extended ok=12 fail=0, no FATAL
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
cd $SP/p3
rm -f /tmp/zoclo3-sum /tmp/zoclo3-mark
for j in 1 2 3; do
  RACKET_RETAIN_STATIC_RELOC=1 P33_LIBID=1 P33_XREPL=full P33_ROLE=A $RK -q -n -t p3.3-run.rkt > /tmp/zoclo3-a$j.log 2>&1 \
  && RACKET_RETAIN_STATIC_RELOC=1 P33_LIBID=1 P33_XREPL=full P33_ROLE=B $RK -q -n -t p3.3-run.rkt > /tmp/zoclo3-b$j.log 2>&1
  echo "pair$j: $?" >> /tmp/zoclo3-sum
  grep -a 'FATAL' $SP/p3/p3.3a.log >> /tmp/zoclo3-sum 2>/dev/null
  grep -a 'SUMMARY\|extended diag\|(zoclo\|FATAL' $SP/p3/p3.3b.log >> /tmp/zoclo3-sum 2>/dev/null
done
echo DONE > /tmp/zoclo3-mark
