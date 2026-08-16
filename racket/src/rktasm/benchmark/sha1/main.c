// benchmark/sha1/main.c - SHA1 benchmark
#include "../common.h"
#include "sha1_ref.h"

#ifdef __APPLE__
#include <CommonCrypto/CommonDigest.h>
#endif

// ============================================================
// SHA1 实现
// ============================================================

// ASM implementation 000 (from our DSL)
extern void sha1_init(uint32_t state[5]);
extern void sha1_consume(uint32_t state[5], const uint8_t block[64]);
extern void sha1_digest(uint32_t state[5], const uint8_t *data,
                        uint64_t total_bits, uint8_t digest[20]);

// ASM implementation 001 (optimized, symbol-prefixed)
extern void opt_sha1_init(uint32_t state[5]);
extern void opt_sha1_consume(uint32_t state[5], const uint8_t block[64]);
extern void opt_sha1_digest(uint32_t state[5], const uint8_t *data,
                            uint64_t total_bits, uint8_t digest[20]);

// ASM implementation 002 (sha1h + 2-block consume, symbol-prefixed)
extern void opt2_sha1_init(uint32_t state[5]);
extern void opt2_sha1_consume(uint32_t state[5], const uint8_t block[64]);
extern void opt2_sha1_consume_blocks(uint32_t state[5], const uint8_t *data,
                                     uint64_t blocks);
extern void opt2_sha1_digest(uint32_t state[5], const uint8_t *data,
                             uint64_t total_bits, uint8_t digest[20]);

static void sha1_c_ref(const uint8_t *data, size_t len, uint8_t digest[32]) {
    sha1_ref(data, len, digest);
}

static void sha1_asm_neon_000(const uint8_t *data, size_t len, uint8_t digest[32]) {
    uint32_t state[5];
    sha1_init(state);
    size_t blocks = len / 64;
    for (size_t i = 0; i < blocks; i++) {
        sha1_consume(state, data + i * 64);
    }
    sha1_digest(state, data + blocks * 64, len * 8, digest);
}

static void sha1_asm_neon_001(const uint8_t *data, size_t len, uint8_t digest[32]) {
    uint32_t state[5];
    opt_sha1_init(state);
    size_t blocks = len / 64;
    for (size_t i = 0; i < blocks; i++) {
        opt_sha1_consume(state, data + i * 64);
    }
    opt_sha1_digest(state, data + blocks * 64, len * 8, digest);
}

static void sha1_asm_neon_002(const uint8_t *data, size_t len, uint8_t digest[32]) {
    uint32_t state[5];
    opt2_sha1_init(state);
    size_t blocks = len / 64;
    if (blocks != 0) {
        opt2_sha1_consume_blocks(state, data, (uint64_t)blocks);
    }
    opt2_sha1_digest(state, data + blocks * 64, len * 8, digest);
}

#ifdef __APPLE__
static void sha1_commoncrypto(const uint8_t *data, size_t len, uint8_t digest[32]) {
    CC_SHA1(data, (CC_LONG)len, digest);
}
#endif

// ============================================================
// 正确性测试
// ============================================================

static void print_digest_fp(FILE *fp, const uint8_t *digest, int len) {
    for (int i = 0; i < len; i++) {
        fprintf(fp, "%02x", digest[i]);
    }
}

static int hex_nibble(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

static int hex_to_bytes(const char *hex, uint8_t *out, size_t out_len) {
    size_t hex_len = strlen(hex);
    if (hex_len != out_len * 2) return 0;
    for (size_t i = 0; i < out_len; i++) {
        int hi = hex_nibble(hex[i * 2]);
        int lo = hex_nibble(hex[i * 2 + 1]);
        if (hi < 0 || lo < 0) return 0;
        out[i] = (uint8_t)((hi << 4) | lo);
    }
    return 1;
}

static int run_known_answer_tests(category_t *cat, int json_output) {
    static const uint8_t msg_empty[] = "";
    static const uint8_t msg_abc[] = "abc";
    static const uint8_t msg_long[] =
        "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq";

    typedef struct {
        const char *name;
        const uint8_t *msg;
        size_t len;
        const char *expected_hex;
    } kat_t;

    const kat_t tests[] = {
        {"empty", msg_empty, 0, "da39a3ee5e6b4b0d3255bfef95601890afd80709"},
        {"abc", msg_abc, 3, "a9993e364706816aba3e25717850c26c9cd0d89d"},
        {"abcdbc..nopq", msg_long, sizeof(msg_long) - 1, "84983e441c3bd26ebaae4aa1f95129e5e54670f1"},
    };

    if (!json_output) {
        printf("\n[Correctness] Known-answer tests\n");
    }

    for (size_t t = 0; t < sizeof(tests) / sizeof(tests[0]); t++) {
        uint8_t expected[20];
        if (!hex_to_bytes(tests[t].expected_hex, expected, sizeof(expected))) {
            fprintf(stderr, "Invalid KAT hex string: %s\n", tests[t].name);
            return 0;
        }

        for (int i = 0; i < cat->impl_count; i++) {
            uint8_t digest[32] = {0};
            cat->impls[i].fn(tests[t].msg, tests[t].len, digest);
            if (memcmp(digest, expected, cat->digest_len) != 0) {
                fprintf(stderr, "KAT failed [%s] impl=%s\n", tests[t].name, cat->impls[i].name);
                fprintf(stderr, "  expected: ");
                print_digest_fp(stderr, expected, cat->digest_len);
                fprintf(stderr, "\n  actual:   ");
                print_digest_fp(stderr, digest, cat->digest_len);
                fprintf(stderr, "\n");
                return 0;
            }
        }
    }

    if (!json_output) {
        printf("  KAT: PASSED (%zu vectors)\n", sizeof(tests) / sizeof(tests[0]));
    }
    return 1;
}

static int run_padding_boundary_tests(category_t *cat, int json_output) {
    const size_t lens[] = {
        0, 1, 2, 3, 7, 8, 15, 31,
        55, 56, 57, 63, 64, 65,
        95, 127, 128, 129, 255, 256, 257, 511, 512, 513, 1024
    };

    if (!json_output) {
        printf("[Correctness] Padding-boundary tests\n");
    }

    for (size_t li = 0; li < sizeof(lens) / sizeof(lens[0]); li++) {
        size_t len = lens[li];
        uint8_t dummy = 0;
        uint8_t *data = NULL;
        const uint8_t *input = NULL;

        if (len == 0) {
            input = &dummy;
        } else {
            data = generate_data(len);
            if (!data) {
                fprintf(stderr, "Failed to allocate boundary test buffer: %zu\n", len);
                return 0;
            }
            input = data;
        }

        uint8_t ref_digest[32] = {0};
        sha1_c_ref(input, len, ref_digest);

        for (int i = 1; i < cat->impl_count; i++) {
            uint8_t digest[32] = {0};
            cat->impls[i].fn(input, len, digest);
            if (memcmp(digest, ref_digest, cat->digest_len) != 0) {
                fprintf(stderr, "Boundary test failed len=%zu impl=%s\n", len, cat->impls[i].name);
                fprintf(stderr, "  reference: ");
                print_digest_fp(stderr, ref_digest, cat->digest_len);
                fprintf(stderr, "\n  actual:    ");
                print_digest_fp(stderr, digest, cat->digest_len);
                fprintf(stderr, "\n");
                free(data);
                return 0;
            }
        }

        free(data);
    }

    if (!json_output) {
        printf("  Boundary: PASSED (%zu lengths)\n", sizeof(lens) / sizeof(lens[0]));
    }
    return 1;
}

// ============================================================
// 汇编版本性能对比
// ============================================================

static void run_asm_head_to_head(int json_output) {
    if (json_output) return;

    const size_t sizes[] = {64, 256, 1024, 4096, 16384, 65536, 262144, 1048576};
    const int base_iterations = 10000;

    printf("\n[ASM Optimization] 000 vs 001 vs 002\n");
    printf("%-10s %14s %14s %14s %10s %10s\n",
           "Bytes", "ASM-000 MB/s", "ASM-001 MB/s", "ASM-002 MB/s", "001/000", "002/000");
    printf("%-10s %14s %14s %14s %10s %10s\n",
           "----------", "--------------", "--------------", "--------------", "----------", "----------");

    for (size_t i = 0; i < sizeof(sizes) / sizeof(sizes[0]); i++) {
        size_t len = sizes[i];
        uint8_t *data = generate_data(len);
        if (!data) {
            fprintf(stderr, "Failed to allocate %zu bytes for ASM compare\n", len);
            return;
        }

        int iters = base_iterations;
        if (len > 65536) iters = base_iterations / 10;
        if (len > 262144) iters = base_iterations / 100;

        bench_result_t r0 = {.name = "ASM-000", .fn = sha1_asm_neon_000, .digest_len = 20};
        bench_result_t r1 = {.name = "ASM-001", .fn = sha1_asm_neon_001, .digest_len = 20};
        bench_result_t r2 = {.name = "ASM-002", .fn = sha1_asm_neon_002, .digest_len = 20};
        run_benchmark(&r0, data, len, iters);
        run_benchmark(&r1, data, len, iters);
        run_benchmark(&r2, data, len, iters);

        if (memcmp(r0.digest, r1.digest, 20) != 0 || memcmp(r0.digest, r2.digest, 20) != 0) {
            fprintf(stderr, "Digest mismatch in ASM head-to-head len=%zu\n", len);
            free(data);
            return;
        }

        double speedup_001 = r1.throughput_mbps / r0.throughput_mbps;
        double speedup_002 = r2.throughput_mbps / r0.throughput_mbps;
        printf("%-10zu %14.2f %14.2f %14.2f %9.2fx %9.2fx\n",
               len, r0.throughput_mbps, r1.throughput_mbps, r2.throughput_mbps,
               speedup_001, speedup_002);
        free(data);
    }
}

// ============================================================
// Main
// ============================================================

int main(int argc, char *argv[]) {
    timing_init();

    int json_output = 0;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--json") == 0) {
            json_output = 1;
        }
    }

    if (!json_output) {
        printf("SHA1 Benchmark\n");
        printf("==============\n");
    }

    category_t sha1;
    category_init(&sha1, "SHA1", 20);
    category_add(&sha1, "C-reference", sha1_c_ref);
    category_add(&sha1, "ASM-000", sha1_asm_neon_000);
    category_add(&sha1, "ASM-001", sha1_asm_neon_001);
    category_add(&sha1, "ASM-002", sha1_asm_neon_002);
#ifdef __APPLE__
    category_add(&sha1, "CommonCrypto", sha1_commoncrypto);
#endif

    int kat_passed = run_known_answer_tests(&sha1, json_output);
    int boundary_passed = run_padding_boundary_tests(&sha1, json_output);
    int perf_passed = run_category_benchmark(&sha1, json_output);
    run_asm_head_to_head(json_output);
    int passed = kat_passed && boundary_passed && perf_passed;

    if (!json_output) {
        printf("\nCorrectness (KAT): %s\n", kat_passed ? "PASSED" : "FAILED");
        printf("Correctness (Boundary): %s\n", boundary_passed ? "PASSED" : "FAILED");
        printf("Digest verification: %s\n", perf_passed ? "PASSED" : "FAILED");
        printf("Overall: %s\n", passed ? "PASSED" : "FAILED");
    }

    return passed ? 0 : 1;
}
