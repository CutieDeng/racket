#!/bin/bash
# run B under lldb repeatedly until it crashes; capture the C backtrace
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M08-D24-racket-feat-native-pvector/a95ca407-0dbc-4d46-a16a-c1769ee54cd5/scratchpad
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
export P33_SP=$SP
cd $SP/p3
rm -f /tmp/rtlldb-mark /tmp/rtlldb-bt
export P33_PREHEAT=none P33_CODEFASL=1 RACKET_RETAIN_STATIC_RELOC=1 P33_XREPL=full P33_ROLE=B
for j in $(seq 1 20); do
  lldb --batch -o "settings set target.disable-aslr false" -o run -o bt -o quit -- $RK -q -n -t p3.3-run.rkt > /tmp/rtlldb-$j.log 2>&1
  if grep -q "stop reason = EXC_BAD_ACCESS\|invalid memory" /tmp/rtlldb-$j.log; then
    echo "CRASH at iteration $j" > /tmp/rtlldb-bt
    grep -A 30 "stop reason" /tmp/rtlldb-$j.log | head -40 >> /tmp/rtlldb-bt
    break
  fi
done
echo DONE > /tmp/rtlldb-mark
