# benchmark/sha1/Makefile - SHA1 benchmark

CC = cc
CFLAGS = -O3 -Wall -Wextra
LDFLAGS =

# Paths
MULTIAVL_ROOT = ../..
DSL_SRC_000 = $(MULTIAVL_ROOT)/example/000-neon-sha1.d
DSL_SRC_001 = $(MULTIAVL_ROOT)/example/001-sha1.d
DSL_SRC_002 = $(MULTIAVL_ROOT)/example/002-sha1.d

.PHONY: all clean run run-json compare-asm

all: benchmark

# Generate ASM from DSL (000/001/002)
sha1_asm_000.s: $(DSL_SRC_000) gen-asm.rkt
	racket gen-asm.rkt --apple --source $(DSL_SRC_000) > sha1_asm_000.s

sha1_asm_001.s: $(DSL_SRC_001) gen-asm.rkt
	racket gen-asm.rkt --apple --source $(DSL_SRC_001) --prefix opt_ > sha1_asm_001.s

sha1_asm_002.s: $(DSL_SRC_002) gen-asm.rkt
	racket gen-asm.rkt --apple --source $(DSL_SRC_002) --prefix opt2_ > sha1_asm_002.s

sha1_asm_000.o: sha1_asm_000.s
	$(CC) -c sha1_asm_000.s -o sha1_asm_000.o

sha1_asm_001.o: sha1_asm_001.s
	$(CC) -c sha1_asm_001.s -o sha1_asm_001.o

sha1_asm_002.o: sha1_asm_002.s
	$(CC) -c sha1_asm_002.s -o sha1_asm_002.o

sha1_ref.o: sha1_ref.c sha1_ref.h
	$(CC) $(CFLAGS) -c sha1_ref.c -o sha1_ref.o

main.o: main.c sha1_ref.h ../common.h
	$(CC) $(CFLAGS) -c main.c -o main.o

benchmark: main.o sha1_ref.o sha1_asm_000.o sha1_asm_001.o sha1_asm_002.o
	$(CC) $(LDFLAGS) main.o sha1_ref.o sha1_asm_000.o sha1_asm_001.o sha1_asm_002.o -o benchmark

# Run benchmark
run: benchmark
	./benchmark

run-json: benchmark
	./benchmark --json > results.json
	@echo "Results saved to results.json"

compare-asm: sha1_asm_000.s sha1_asm_001.s sha1_asm_002.s
	./compare-asm.sh sha1_asm_000.s sha1_asm_001.s sha1_asm_002.s

clean:
	rm -f *.o benchmark sha1_asm_000.s sha1_asm_001.s sha1_asm_002.s results.json
