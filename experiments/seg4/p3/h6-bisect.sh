#!/bin/bash
# bisect the first bad h6 prop entry: install [1,mid]; crash => bad in [1,mid]
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M07-D16-racket-feat-swisstable/d5d1ca89-29ba-48e9-9226-2d4a258a56cd/scratchpad
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
cd $SP/p3
run_b () {  # $1 = range
  RACKET_RETAIN_STATIC_RELOC=1 P33_H6_RANGE="$1" P33_LPROBES=0 P33_XREPL=full P33_ROLE=B \
    $RK -q -n -t p3.3-run.rkt > /tmp/h6b.log 2>&1
  if grep -aq "invalid memory" $SP/p3/p3.3b.log /tmp/h6b.log 2>/dev/null; then echo BAD; else echo GOOD; fi
}
echo "== sanity: full range =="
r=$(run_b "0:999999"); echo "full: $r"
if [ "$r" != "BAD" ]; then echo "full range not bad; abort"; exit 1; fi
echo "== sanity: empty range =="
r=$(run_b "999998:2"); echo "empty: $r"
if [ "$r" != "GOOD" ]; then echo "empty range bad?!; abort"; exit 1; fi
lo=1; hi=8192
while [ $((hi-lo)) -gt 0 ]; do
  mid=$(( (lo+hi)/2 ))
  r=$(run_b "1:$mid")
  echo "range 1:$mid -> $r"
  if [ "$r" = "BAD" ]; then hi=$mid; else lo=$((mid+1)); fi
done
echo "FIRST BAD ENTRY INDEX: $lo"
# confirm single-entry culprit
r=$(run_b "$lo:$lo"); echo "solo $lo: $r"
