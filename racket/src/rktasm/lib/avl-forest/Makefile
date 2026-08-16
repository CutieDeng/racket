ROOT = /Users/cutiedeng/Documents/multiavl
AS = cd $(ROOT) && racket cli/as.rkt
CC = cc
CFLAGS = -O2 -Wall
HERE = lib/avl-forest

.PHONY: all test test-sve clean

all: test_avl.exe

avl-forest.s: avl-forest.d
	$(AS) --apple -o $(HERE)/$@ $(HERE)/$<

avl-forest.o: avl-forest.s
	$(CC) -c $< -o $@

test_avl.o: test_avl.c
	$(CC) $(CFLAGS) -c $< -o $@

test_avl.exe: test_avl.o avl-forest.o
	$(CC) $^ -o $@

test: test_avl.exe
	./test_avl.exe

# --- SVE targets (require Docker + QEMU) ---

# Combine scalar + SVE source for assembler (bl needs all labels in one file)
avl-forest-combined.d: avl-forest.d avl-forest-sve.d
	cat $^ > $@

avl-forest-gnu.s: avl-forest-combined.d
	$(AS) --gnu -o $(HERE)/$@ $(HERE)/$<

# Fix assembler output: for .D element size, GNU as expects X registers
# but our assembler always uses W registers. Also fix comment syntax.
avl-forest-gnu-fixed.s: avl-forest-gnu.s
	sed \
	  -e 's/^;/\/\//' \
	  -e 's/dup z\([0-9]*\)\.D, w\([0-9]*\)/dup z\1.D, x\2/g' \
	  -e 's/whilelt p\([0-9]*\)\.D, w\([0-9]*\), w\([0-9]*\)/whilelt p\1.D, x\2, x\3/g' \
	  -e 's/lastb w\([0-9]*\), p\([0-9]*\), z\([0-9]*\)\.D/lastb x\1, p\2, z\3.D/g' \
	  $< > $@

test-sve: avl-forest-gnu-fixed.s test_avl.c
	docker run --rm -v $(ROOT):/work -w /work/$(HERE) \
	  arm64v8/ubuntu:22.04 bash -c '\
	    apt-get update -qq && apt-get install -y -qq gcc qemu-user >/dev/null 2>&1 && \
	    gcc -O2 -Wall -DTEST_SVE -march=armv8-a+sve -c test_avl.c -o test_avl_sve.o && \
	    gcc -march=armv8-a+sve -c avl-forest-gnu-fixed.s -o avl-forest-sve.o && \
	    gcc test_avl_sve.o avl-forest-sve.o -o test_avl_sve.exe -static && \
	    qemu-aarch64 -cpu max ./test_avl_sve.exe \
	  '

clean:
	rm -f *.o *.s *.exe avl-forest-combined.d
