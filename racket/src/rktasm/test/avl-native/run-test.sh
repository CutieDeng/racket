#!/bin/bash
# AVL Forest native test + benchmark runner
# Usage: ./run-test.sh [test|bench|all]
#
# Requires: racket, gcc with SVE support, aarch64 host
set -e
cd "$(dirname "$0")"
ROOT=../..
MODE="${1:-all}"

echo "============================================================"
echo "  AVL Forest — Native Test Suite"
echo "============================================================"
echo ""

# --- Step 1: Assemble ---
echo ">>> Assembling (racket → GNU asm)..."
cat "$ROOT/lib/avl-forest/avl-forest.d" \
    "$ROOT/lib/avl-forest/avl-forest-sve.d" > avl-combined.d

(cd "$ROOT" && racket cli/as.rkt --gnu -o test/avl-native/avl-gnu.s test/avl-native/avl-combined.d)

# Fix .D element size: GNU as requires X registers
sed \
  -e 's/^;/\/\//' \
  -e 's/dup z\([0-9]*\)\.D, w\([0-9]*\)/dup z\1.D, x\2/g' \
  -e 's/whilelt p\([0-9]*\)\.D, w\([0-9]*\), w\([0-9]*\)/whilelt p\1.D, x\2, x\3/g' \
  -e 's/lastb w\([0-9]*\), p\([0-9]*\), z\([0-9]*\)\.D/lastb x\1, p\2, z\3.D/g' \
  avl-gnu.s > avl.s
echo >> avl.s

echo "    OK"

# --- Step 2: Compile ---
echo ">>> Compiling..."
gcc -march=armv8-a+sve -c avl.s -o avl.o

if [ "$MODE" = "test" ] || [ "$MODE" = "all" ]; then
    gcc -O2 -Wall -march=armv8-a+sve -DTEST_SVE -c test_correctness.c -o test_correctness.o
    gcc test_correctness.o avl.o -o test_correctness.exe
fi

if [ "$MODE" = "bench" ] || [ "$MODE" = "all" ]; then
    gcc -O2 -Wall -march=armv8-a+sve -c bench_avl.c -o bench_avl.o
    gcc bench_avl.o avl.o -o bench_avl.exe
fi

echo "    OK"

# --- Step 3: Run ---
if [ "$MODE" = "test" ] || [ "$MODE" = "all" ]; then
    echo ""
    echo ">>> Running Correctness Tests..."
    echo ""
    ./test_correctness.exe
fi

if [ "$MODE" = "bench" ] || [ "$MODE" = "all" ]; then
    echo ""
    echo ">>> Running Benchmark..."
    echo ""
    ./bench_avl.exe
fi
