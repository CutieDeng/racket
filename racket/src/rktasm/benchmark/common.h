// benchmark/common.h - 通用 benchmark 框架
#ifndef BENCHMARK_COMMON_H
#define BENCHMARK_COMMON_H

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <mach/mach_time.h>

// ============================================================
// 类型定义
// ============================================================

#define MAX_IMPLEMENTATIONS 8

typedef void (*hash_fn)(const uint8_t *data, size_t len, uint8_t digest[32]);

typedef struct {
    const char *name;
    hash_fn fn;
    int digest_len;
} implementation_t;

typedef struct {
    const char *name;
    int digest_len;
    implementation_t impls[MAX_IMPLEMENTATIONS];
    int impl_count;
} category_t;

typedef struct {
    const char *name;
    hash_fn fn;
    int digest_len;
    double throughput_mbps;
    double time_per_hash_ns;
    uint8_t digest[32];
} bench_result_t;

// ============================================================
// 分类操作
// ============================================================

static inline void category_init(category_t *cat, const char *name, int digest_len) {
    cat->name = name;
    cat->digest_len = digest_len;
    cat->impl_count = 0;
}

static inline void category_add(category_t *cat, const char *name, hash_fn fn) {
    if (cat->impl_count >= MAX_IMPLEMENTATIONS) return;
    cat->impls[cat->impl_count].name = name;
    cat->impls[cat->impl_count].fn = fn;
    cat->impls[cat->impl_count].digest_len = cat->digest_len;
    cat->impl_count++;
}

// ============================================================
// 计时
// ============================================================

static mach_timebase_info_data_t _timebase_info;
static int _timing_initialized = 0;

static inline void timing_init(void) {
    if (!_timing_initialized) {
        mach_timebase_info(&_timebase_info);
        _timing_initialized = 1;
    }
}

static inline uint64_t get_time_ns(void) {
    uint64_t t = mach_absolute_time();
    return (uint64_t)((double)t * _timebase_info.numer / _timebase_info.denom);
}

// ============================================================
// Benchmark 执行
// ============================================================

static inline void run_benchmark(bench_result_t *result, const uint8_t *data,
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

    result->throughput_mbps = (total_bytes / (1024.0 * 1024.0)) / (total_ns / 1e9);
    result->time_per_hash_ns = (double)total_ns / iterations;
    memcpy(result->digest, digest, result->digest_len);
}

// ============================================================
// 数据生成
// ============================================================

static inline uint8_t *generate_data(size_t len) {
    uint8_t *data = malloc(len);
    if (!data) return NULL;

    uint32_t seed = 0x12345678;
    for (size_t i = 0; i < len; i++) {
        seed = seed * 1103515245 + 12345;
        data[i] = (seed >> 16) & 0xFF;
    }
    return data;
}

// ============================================================
// 输出
// ============================================================

static inline void print_digest(const uint8_t *digest, int len) {
    for (int i = 0; i < len; i++) {
        printf("%02x", digest[i]);
    }
}

static inline int verify_digests(bench_result_t *results, int count, int digest_len) {
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

static inline void print_results_table(bench_result_t *results, int count,
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

static inline void print_results_json(bench_result_t *results, int count,
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
// 分类 Benchmark 运行
// ============================================================

static inline int run_category_benchmark(category_t *cat, int json_output) {
    size_t data_sizes[] = {64, 256, 1024, 4096, 16384, 65536, 262144, 1048576};
    int num_sizes = sizeof(data_sizes) / sizeof(data_sizes[0]);
    int iterations = 10000;
    int all_passed = 1;

    if (!json_output) {
        printf("\n[%s] Implementations: ", cat->name);
        for (int i = 0; i < cat->impl_count; i++) {
            printf("%s%s", cat->impls[i].name,
                   (i < cat->impl_count - 1) ? ", " : "\n");
        }
    }

    for (int s = 0; s < num_sizes; s++) {
        size_t data_len = data_sizes[s];
        uint8_t *data = generate_data(data_len);
        if (!data) {
            fprintf(stderr, "Failed to allocate %zu bytes\n", data_len);
            return 0;
        }

        int iters = iterations;
        if (data_len > 65536) iters = iterations / 10;
        if (data_len > 262144) iters = iterations / 100;

        bench_result_t results[MAX_IMPLEMENTATIONS];
        for (int i = 0; i < cat->impl_count; i++) {
            results[i].name = cat->impls[i].name;
            results[i].fn = cat->impls[i].fn;
            results[i].digest_len = cat->digest_len;
        }

        for (int i = 0; i < cat->impl_count; i++) {
            run_benchmark(&results[i], data, data_len, iters);
        }

        if (!verify_digests(results, cat->impl_count, cat->digest_len)) {
            all_passed = 0;
            free(data);
            continue;
        }

        if (json_output) {
            print_results_json(results, cat->impl_count, data_len, iters);
        } else {
            print_results_table(results, cat->impl_count, data_len, iters);
        }

        free(data);
    }

    return all_passed;
}

#endif // BENCHMARK_COMMON_H
