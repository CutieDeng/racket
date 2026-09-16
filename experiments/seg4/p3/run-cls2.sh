#!/bin/bash
SP=/private/tmp/claude-501/-Users-cutiedeng-Y2026-M07-D16-racket-feat-swisstable/d5d1ca89-29ba-48e9-9226-2d4a258a56cd/scratchpad
RK=/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/racket/bin/racket
export P33_SP=$SP
cd $SP/p3
RACKET_RETAIN_STATIC_RELOC=1 P33_LIBID=1 P33_STX=1 P33_XREPL=full P33_ROLE=A $RK -q -n -t p3.3-run.rkt > /tmp/d109-a.log 2>&1 \
&& cp p3.3a.log /tmp/d109-alog \
&& RACKET_RETAIN_STATIC_RELOC=1 P33_LIBID=1 P33_STX=1 P33_XREPL=full P33_ROLE=B $RK -q -n -t p3.3-run.rkt > /tmp/d109-b.log 2>&1
echo "AB:$?" > /tmp/d109-mark
