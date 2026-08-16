ROOT := ../..
AS   := cd $(ROOT) && racket cli/as.rkt
CC   := gcc
CFLAGS := -O2 -Wall -march=armv8-a+sve
HERE := test/avl-native

.PHONY: all test bench clean

all: test bench

# --- Assemble AVL forest (combined scalar + SVE) ---

avl-combined.d: $(ROOT)/lib/avl-forest/avl-forest.d $(ROOT)/lib/avl-forest/avl-forest-sve.d $(ROOT)/lib/avl-batch/avl-batch.d
	cat $^ > $@

avl-gnu.s: avl-combined.d
	$(AS) --gnu -o $(HERE)/$@ $(HERE)/$<

# Fix: .D element size requires X registers in GNU as; also fix comment syntax
avl.s: avl-gnu.s
	sed \
	  -e 's/^;/\/\//' \
	  -e 's/dup z\([0-9]*\)\.D, w\([0-9]*\)/dup z\1.D, x\2/g' \
	  -e 's/whilelt p\([0-9]*\)\.D, w\([0-9]*\), w\([0-9]*\)/whilelt p\1.D, x\2, x\3/g' \
	  -e 's/lastb w\([0-9]*\), p\([0-9]*\), z\([0-9]*\)\.D/lastb x\1, p\2, z\3.D/g' \
	  $< > $@ && echo >> $@

avl.o: avl.s
	$(CC) -march=armv8-a+sve -c $< -o $@

# --- Correctness tests ---

test_correctness.o: test_correctness.c common.h c_avl.h
	$(CC) $(CFLAGS) -DTEST_SVE -c $< -o $@

test_correctness.exe: test_correctness.o avl.o
	$(CC) $^ -o $@

test: test_correctness.exe
	./test_correctness.exe

# --- Benchmark ---

bench_avl.o: bench_avl.c common.h c_avl.h
	$(CC) $(CFLAGS) -c $< -o $@

bench_avl.exe: bench_avl.o avl.o
	$(CC) $^ -o $@

bench: bench_avl.exe
	./bench_avl.exe

# --- Docker/QEMU (for testing on non-SVE hosts) ---

docker-test: avl.s test_correctness.c bench_avl.c common.h c_avl.h
	docker run --rm -v $(CURDIR):/work -w /work \
	  arm64v8/ubuntu:22.04 bash -c '\
	    apt-get update -qq && apt-get install -y -qq gcc qemu-user >/dev/null 2>&1 && \
	    gcc -O2 -Wall -DTEST_SVE -march=armv8-a+sve -c test_correctness.c -o test_correctness.o && \
	    gcc -march=armv8-a+sve -c avl.s -o avl.o && \
	    gcc test_correctness.o avl.o -o test_correctness.exe -static && \
	    qemu-aarch64 -cpu max ./test_correctness.exe && \
	    gcc -O2 -Wall -march=armv8-a+sve -c bench_avl.c -o bench_avl.o && \
	    gcc bench_avl.o avl.o -o bench_avl.exe -static && \
	    qemu-aarch64 -cpu max ./bench_avl.exe \
	  '

clean:
	rm -f *.o avl.s avl-gnu.s avl-combined.d test_correctness.exe bench_avl.exe
