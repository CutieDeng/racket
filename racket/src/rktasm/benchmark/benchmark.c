// benchmark.c - 多算法 benchmark 框架
// 支持多种算法分类，每个分类可以有多个实现

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>
#include <mach/mach_time.h>  // macOS high-resolution timer

// ============================================================
// 算法分类框架
// ============================================================

#define MAX_IMPLEMENTATIONS 8
#define MAX_CATEGORIES 16

typedef void (*hash_fn)(const uint8_t *data, size_t len, uint8_t digest[32]);

typedef struct {
    const char *name;
    hash_fn fn;
    int digest_len;  // 摘要长度 (bytes)
} implementation_t;

typedef struct {
    const char *name;           // 分类名称 (如 "SHA1", "SHA256")
    int digest_len;             // 该分类的摘要长度
    implementation_t impls[MAX_IMPLEMENTATIONS];
    int impl_count;
} category_t;

// 全局分类注册表
static category_t categories[MAX_CATEGORIES];
static int category_count = 0;

// 注册新分类
static category_t *register_category(const char *name, int digest_len) {
    if (category_count >= MAX_CATEGORIES) return NULL;
    category_t *cat = &categories[category_count++];
    cat->name = name;
    cat->digest_len = digest_len;
    cat->impl_count = 0;
    return cat;
}

// 向分类添加实现
static void add_implementation(category_t *cat, const char *name, hash_fn fn) {
    if (!cat || cat->impl_count >= MAX_IMPLEMENTATIONS) return;
    cat->impls[cat->impl_count].name = name;
    cat->impls[cat->impl_count].fn = fn;
    cat->impls[cat->impl_count].digest_len = cat->digest_len;
    cat->impl_count++;
}

// ============================================================
// SHA1 实现
// ============================================================

#include "sha1_ref.h"

// ASM implementation (from our DSL)
extern void sha1_init(uint32_t state[5]);
extern void sha1_consume(uint32_t state[5], const uint8_t block[64]);
extern void sha1_digest(uint32_t state[5], const uint8_t *data,
                        uint64_t total_bits, uint8_t digest[20]);

static void sha1_c_ref(const uint8_t *data, size_t len, uint8_t digest[32]) {
    sha1_ref(data, len, digest);
}

static void sha1_asm_neon(const uint8_t *data, size_t len, uint8_t digest[32]) {
    uint32_t state[5];
    sha1_init(state);
    size_t blocks = len / 64;
    for (size_t i = 0; i < blocks; i++) {
        sha1_consume(state, data + i * 64);
    }
    sha1_digest(state, data + blocks * 64, len * 8, digest);
}

// OpenSSL (optional, compile with -DUSE_OPENSSL -lcrypto)
#ifdef USE_OPENSSL
#include <openssl/sha.h>

static void sha1_openssl(const uint8_t *data, size_t len, uint8_t digest[32]) {
    SHA1(data, len, digest);
}
#endif

// CommonCrypto (macOS built-in)
#ifdef __APPLE__
#include <CommonCrypto/CommonDigest.h>

static void sha1_commoncrypto(const uint8_t *data, size_t len, uint8_t digest[32]) {
    CC_SHA1(data, (CC_LONG)len, digest);
}
#endif

static void register_sha1(void) {
    category_t *cat = register_category("SHA1", 20);
    add_implementation(cat, "C-reference", sha1_c_ref);
    add_implementation(cat, "ASM-NEON", sha1_asm_neon);
#ifdef __APPLE__
    add_implementation(cat, "CommonCrypto", sha1_commoncrypto);
#endif
#ifdef USE_OPENSSL
    add_implementation(cat, "OpenSSL", sha1_openssl);
#endif
}

// ============================================================
// Timing utilities
// ============================================================

static mach_timebase_info_data_t timebase_info;

static void init_timing(void) {
    mach_timebase_info(&timebase_info);
}

static uint64_t get_time_ns(void) {
    uint64_t t = mach_absolute_time();
    return (uint64_t)((double)t * timebase_info.numer / timebase_info.denom);
}

// ============================================================
// Benchmark
// ============================================================

typedef struct {
    const char *name;
    hash_fn fn;
    int digest_len;
    double throughput_mbps;
    double time_per_hash_ns;
    uint8_t digest[32];
} bench_result_t;

static void run_benchmark(bench_result_t *result, const uint8_t *data,
                          size_t data_len, int iterations) {
    uint8_t digest[32];

    // Warmup
    for (int i = 0; i < 10; i++) {
        result->fn(data, data_len, digest);
    }

    // Benchmark
    uint64_t start = get_time_ns();
    for (int i = 0; i < iterations; i++) {
        result->fn(data, data_len, digest);
    }
    uint64_t end = get_time_ns();

    uint64_t total_ns = end - start;
    double total_bytes = (double)data_len * iterations;

    result->throughput_mbps = (total_bytes / (1024.0 * 1024.0)) /
                              (total_ns / 1e9);
    result->time_per_hash_ns = (double)total_ns / iterations;
    memcpy(result->digest, digest, result->digest_len);
}

static void print_digest(const uint8_t *digest, int len) {
    for (int i = 0; i < len; i++) {
        printf("%02x", digest[i]);
    }
}

static int verify_digests(bench_result_t *results, int count, int digest_len) {
    for (int i = 1; i < count; i++) {
        if (memcmp(results[0].digest, results[i].digest, digest_len) != 0) {
            printf("ERROR: digest mismatch between %s and %s\n",
                   results[0].name, results[i].name);
            printf("  %s: ", results[0].name);
            print_digest(results[0].digest, digest_len);
            printf("\n");
            printf("  %s: ", results[i].name);
            print_digest(results[i].digest, digest_len);
            printf("\n");
            return 0;
        }
    }
    return 1;
}

// ============================================================
// Data generation
// ============================================================

static uint8_t *generate_data(size_t len) {
    uint8_t *data = malloc(len);
    if (!data) return NULL;

    // Simple PRNG for reproducible data
    uint32_t seed = 0x12345678;
    for (size_t i = 0; i < len; i++) {
        seed = seed * 1103515245 + 12345;
        data[i] = (seed >> 16) & 0xFF;
    }
    return data;
}

// ============================================================
// Output formats
// ============================================================

static void print_results_table(bench_result_t *results, int count,
                                size_t data_len, int iterations) {
    printf("\n");
    printf("Data size: %zu bytes, Iterations: %d\n", data_len, iterations);
    printf("%-20s %12s %12s %10s\n",
           "Implementation", "MB/s", "ns/hash", "Relative");
    printf("%-20s %12s %12s %10s\n",
           "--------------------", "------------", "------------", "----------");

    double baseline = results[0].throughput_mbps;
    for (int i = 0; i < count; i++) {
        double relative = results[i].throughput_mbps / baseline;
        printf("%-20s %12.2f %12.0f %9.2fx\n",
               results[i].name,
               results[i].throughput_mbps,
               results[i].time_per_hash_ns,
               relative);
    }
}

// JSON output for Racket visualization
static void print_results_json(bench_result_t *results, int count,
                               size_t data_len, int iterations) {
    printf("{\"data_size\": %zu, \"iterations\": %d, \"results\": [\n",
           data_len, iterations);
    for (int i = 0; i < count; i++) {
        printf("  {\"name\": \"%s\", \"mbps\": %.2f, \"ns_per_hash\": %.0f}%s\n",
               results[i].name,
               results[i].throughput_mbps,
               results[i].time_per_hash_ns,
               (i < count - 1) ? "," : "");
    }
    printf("]}\n");
}

// ============================================================
// Main
// ============================================================

static void register_all_categories(void) {
    register_sha1();
    // 未来可以添加更多算法:
    // register_sha256();
    // register_md5();
}

int main(int argc, char *argv[]) {
    init_timing();
    register_all_categories();

    // Parse arguments
    size_t data_sizes[] = {64, 256, 1024, 4096, 16384, 65536, 262144, 1048576};
    int num_sizes = sizeof(data_sizes) / sizeof(data_sizes[0]);
    int iterations = 10000;
    int json_output = 0;
    const char *filter_category = NULL;  // NULL = 运行所有分类

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--json") == 0) {
            json_output = 1;
        } else if (strcmp(argv[i], "--iterations") == 0 && i + 1 < argc) {
            iterations = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--category") == 0 && i + 1 < argc) {
            filter_category = argv[++i];
        }
    }

    if (!json_output) {
        printf("Hash Benchmark\n");
        printf("==============\n");
    }

    int all_passed = 1;

    // 遍历每个分类
    for (int c = 0; c < category_count; c++) {
        category_t *cat = &categories[c];

        // 分类过滤
        if (filter_category && strcmp(cat->name, filter_category) != 0) {
            continue;
        }

        if (!json_output) {
            printf("\n[%s] Implementations: ", cat->name);
            for (int i = 0; i < cat->impl_count; i++) {
                printf("%s%s", cat->impls[i].name,
                       (i < cat->impl_count - 1) ? ", " : "\n");
            }
        }

        // 每个数据大小
        for (int s = 0; s < num_sizes; s++) {
            size_t data_len = data_sizes[s];
            uint8_t *data = generate_data(data_len);
            if (!data) {
                fprintf(stderr, "Failed to allocate %zu bytes\n", data_len);
                return 1;
            }

            // 调整迭代次数
            int iters = iterations;
            if (data_len > 65536) iters = iterations / 10;
            if (data_len > 262144) iters = iterations / 100;

            // 准备结果
            bench_result_t results[MAX_IMPLEMENTATIONS];
            for (int i = 0; i < cat->impl_count; i++) {
                results[i].name = cat->impls[i].name;
                results[i].fn = cat->impls[i].fn;
                results[i].digest_len = cat->digest_len;
            }

            // 运行 benchmark
            for (int i = 0; i < cat->impl_count; i++) {
                run_benchmark(&results[i], data, data_len, iters);
            }

            // 验证摘要一致性
            if (!verify_digests(results, cat->impl_count, cat->digest_len)) {
                all_passed = 0;
                free(data);
                continue;
            }

            // 输出
            if (json_output) {
                print_results_json(results, cat->impl_count, data_len, iters);
            } else {
                print_results_table(results, cat->impl_count, data_len, iters);
            }

            free(data);
        }
    }

    if (!json_output) {
        printf("\nDigest verification: %s\n", all_passed ? "PASSED" : "FAILED");
    }

    return all_passed ? 0 : 1;
}
