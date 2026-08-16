# Makefile for SHA1 benchmark
# 依赖: 系统 cc, 可选 OpenSSL

CC = cc
CFLAGS = -O3 -Wall -Wextra
LDFLAGS =

# OpenSSL support (optional)
# Uncomment to enable:
# CFLAGS += -DUSE_OPENSSL
# LDFLAGS += -lcrypto

# Paths
MULTIAVL_ROOT = ..
ASM_SRC = sha1_asm.s

.PHONY: all clean run run-json

all: benchmark

# Generate ASM from DSL
$(ASM_SRC): $(MULTIAVL_ROOT)/example/000-neon-sha1.d gen-asm.rkt
	racket gen-asm.rkt --apple > $(ASM_SRC)

sha1_asm.o: $(ASM_SRC)
	$(CC) -c $(ASM_SRC) -o sha1_asm.o

sha1_ref.o: sha1_ref.c sha1_ref.h
	$(CC) $(CFLAGS) -c sha1_ref.c -o sha1_ref.o

benchmark.o: benchmark.c sha1_ref.h
	$(CC) $(CFLAGS) -c benchmark.c -o benchmark.o

benchmark: benchmark.o sha1_ref.o sha1_asm.o
	$(CC) $(LDFLAGS) benchmark.o sha1_ref.o sha1_asm.o -o benchmark

# Run benchmark
run: benchmark
	./benchmark

run-json: benchmark
	./benchmark --json > results.json
	@echo "Results saved to results.json"

# Visualize results
visualize: results.json
	racket visualize.rkt results.json

clean:
	rm -f *.o benchmark $(ASM_SRC) results.json
