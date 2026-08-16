#include "common.h"
#include "c_avl.h"
#include <unistd.h>

// Assembly functions
extern int32_t node_alloc(Pool *pool);
extern void    node_free(Pool *pool, int32_t idx);
extern int32_t avl_search_single(Pool *pool, int32_t root, int64_t key);
extern int32_t avl_insert_single(Pool *pool, int32_t root, int64_t key);

extern int64_t  sve_lane_count(void);
extern int32_t  avl_search_parallel(Pool *pool, int64_t key);
extern void     avl_insert_parallel(Pool *pool, int64_t key);

extern void     avl_batch_init(BatchCtx *ctx, Pool *pool, int32_t root);
extern void     avl_batch_put(BatchCtx *ctx, int64_t key);
extern void     avl_batch_flush(BatchCtx *ctx);
extern int32_t  avl_batch_root(BatchCtx *ctx);

// --- Benchmark configuration ---

#define WARMUP_ROUNDS 1
#define BENCH_ROUNDS  5

static int SIZES[] = { 1000, 10000, 100000, 500000 };
#define N_SIZES (int)(sizeof(SIZES) / sizeof(SIZES[0]))

// --- Result storage ---

// 3 benchmarks (insert / search / mixed) x N_SIZES x 4 impls
typedef struct {
    double c;
    double asm_s;       // asm-scalar
    double sve;         // asm-sve (multi-tree)
    double sve_batch;   // asm-sve-batch (single-tree)
} Quad;

typedef struct {
    int  n;
    Quad insert;
    Quad search;
    Quad mixed;
} SizeResult;

static SizeResult results[4]; // max N_SIZES = 4

// --- Benchmark helpers ---

static double bench_c_insert(int n, int64_t *keys, int rounds) {
    double times[BENCH_ROUNDS + WARMUP_ROUNDS];
    for (int r = 0; r < WARMUP_ROUNDS + rounds; r++) {
        Pool *pool = pool_create((uint32_t)(n + 100), 1);
        int32_t root = -1;
        uint64_t t0 = now_ns();
        for (int i = 0; i < n; i++)
            root = c_avl_insert(pool, root, keys[i]);
        uint64_t t1 = now_ns();
        times[r] = (double)(t1 - t0) / (double)n;
        (void)root;
        pool_destroy(pool);
    }
    return median_d(times + WARMUP_ROUNDS, rounds);
}

static double bench_c_search(int n, int64_t *keys, int64_t *search_keys, int rounds) {
    double times[BENCH_ROUNDS + WARMUP_ROUNDS];
    for (int r = 0; r < WARMUP_ROUNDS + rounds; r++) {
        Pool *pool = pool_create((uint32_t)(n + 100), 1);
        int32_t root = -1;
        for (int i = 0; i < n; i++)
            root = c_avl_insert(pool, root, keys[i]);
        uint64_t t0 = now_ns();
        for (int i = 0; i < n; i++)
            c_avl_search(pool, root, search_keys[i]);
        uint64_t t1 = now_ns();
        times[r] = (double)(t1 - t0) / (double)n;
        pool_destroy(pool);
    }
    return median_d(times + WARMUP_ROUNDS, rounds);
}

static double bench_asm_insert(int n, int64_t *keys, int rounds) {
    double times[BENCH_ROUNDS + WARMUP_ROUNDS];
    for (int r = 0; r < WARMUP_ROUNDS + rounds; r++) {
        Pool *pool = pool_create((uint32_t)(n + 100), 1);
        int32_t root = -1;
        uint64_t t0 = now_ns();
        for (int i = 0; i < n; i++)
            root = avl_insert_single(pool, root, keys[i]);
        uint64_t t1 = now_ns();
        times[r] = (double)(t1 - t0) / (double)n;
        (void)root;
        pool_destroy(pool);
    }
    return median_d(times + WARMUP_ROUNDS, rounds);
}

static double bench_asm_search(int n, int64_t *keys, int64_t *search_keys, int rounds) {
    double times[BENCH_ROUNDS + WARMUP_ROUNDS];
    for (int r = 0; r < WARMUP_ROUNDS + rounds; r++) {
        Pool *pool = pool_create((uint32_t)(n + 100), 1);
        int32_t root = -1;
        for (int i = 0; i < n; i++)
            root = avl_insert_single(pool, root, keys[i]);
        uint64_t t0 = now_ns();
        for (int i = 0; i < n; i++)
            avl_search_single(pool, root, search_keys[i]);
        uint64_t t1 = now_ns();
        times[r] = (double)(t1 - t0) / (double)n;
        pool_destroy(pool);
    }
    return median_d(times + WARMUP_ROUNDS, rounds);
}

static double bench_sve_insert(int n, int64_t *keys, int n_trees, int rounds) {
    double times[BENCH_ROUNDS + WARMUP_ROUNDS];
    for (int r = 0; r < WARMUP_ROUNDS + rounds; r++) {
        Pool *pool = pool_create((uint32_t)(n + 100), (uint32_t)n_trees);
        uint64_t t0 = now_ns();
        for (int i = 0; i < n; i++)
            avl_insert_parallel(pool, keys[i]);
        uint64_t t1 = now_ns();
        times[r] = (double)(t1 - t0) / (double)n;
        pool_destroy(pool);
    }
    return median_d(times + WARMUP_ROUNDS, rounds);
}

static double bench_sve_search(int n, int64_t *keys, int64_t *search_keys,
                                int n_trees, int rounds) {
    double times[BENCH_ROUNDS + WARMUP_ROUNDS];
    for (int r = 0; r < WARMUP_ROUNDS + rounds; r++) {
        Pool *pool = pool_create((uint32_t)(n + 100), (uint32_t)n_trees);
        for (int i = 0; i < n; i++)
            avl_insert_parallel(pool, keys[i]);
        uint64_t t0 = now_ns();
        for (int i = 0; i < n; i++)
            avl_search_parallel(pool, search_keys[i]);
        uint64_t t1 = now_ns();
        times[r] = (double)(t1 - t0) / (double)n;
        pool_destroy(pool);
    }
    return median_d(times + WARMUP_ROUNDS, rounds);
}

static double bench_c_mixed(int n, int64_t *keys, int rounds) {
    double times[BENCH_ROUNDS + WARMUP_ROUNDS];
    for (int r = 0; r < WARMUP_ROUNDS + rounds; r++) {
        Pool *pool = pool_create((uint32_t)(n + 100), 1);
        int32_t root = -1;
        int half = n / 2;
        for (int i = 0; i < half; i++)
            root = c_avl_insert(pool, root, keys[i]);
        uint64_t t0 = now_ns();
        for (int i = half; i < n; i++) {
            root = c_avl_insert(pool, root, keys[i]);
            c_avl_search(pool, root, keys[i - half]);
        }
        uint64_t t1 = now_ns();
        int ops = (n - half) * 2;
        times[r] = (double)(t1 - t0) / (double)ops;
        pool_destroy(pool);
    }
    return median_d(times + WARMUP_ROUNDS, rounds);
}

static double bench_asm_mixed(int n, int64_t *keys, int rounds) {
    double times[BENCH_ROUNDS + WARMUP_ROUNDS];
    for (int r = 0; r < WARMUP_ROUNDS + rounds; r++) {
        Pool *pool = pool_create((uint32_t)(n + 100), 1);
        int32_t root = -1;
        int half = n / 2;
        for (int i = 0; i < half; i++)
            root = avl_insert_single(pool, root, keys[i]);
        uint64_t t0 = now_ns();
        for (int i = half; i < n; i++) {
            root = avl_insert_single(pool, root, keys[i]);
            avl_search_single(pool, root, keys[i - half]);
        }
        uint64_t t1 = now_ns();
        int ops = (n - half) * 2;
        times[r] = (double)(t1 - t0) / (double)ops;
        pool_destroy(pool);
    }
    return median_d(times + WARMUP_ROUNDS, rounds);
}

static double bench_sve_mixed(int n, int64_t *keys, int n_trees, int rounds) {
    double times[BENCH_ROUNDS + WARMUP_ROUNDS];
    for (int r = 0; r < WARMUP_ROUNDS + rounds; r++) {
        Pool *pool = pool_create((uint32_t)(n + 100), (uint32_t)n_trees);
        int half = n / 2;
        for (int i = 0; i < half; i++)
            avl_insert_parallel(pool, keys[i]);
        uint64_t t0 = now_ns();
        for (int i = half; i < n; i++) {
            avl_insert_parallel(pool, keys[i]);
            avl_search_parallel(pool, keys[i - half]);
        }
        uint64_t t1 = now_ns();
        int ops = (n - half) * 2;
        times[r] = (double)(t1 - t0) / (double)ops;
        pool_destroy(pool);
    }
    return median_d(times + WARMUP_ROUNDS, rounds);
}

// --- SVE-Batch benchmarks ---

static double bench_batch_insert(int n, int64_t *keys, int rounds) {
    double times[BENCH_ROUNDS + WARMUP_ROUNDS];
    for (int r = 0; r < WARMUP_ROUNDS + rounds; r++) {
        Pool *pool = pool_create((uint32_t)(n + 100), 1);
        BatchCtx ctx;
        avl_batch_init(&ctx, pool, -1);
        uint64_t t0 = now_ns();
        for (int i = 0; i < n; i++)
            avl_batch_put(&ctx, keys[i]);
        avl_batch_flush(&ctx);
        uint64_t t1 = now_ns();
        times[r] = (double)(t1 - t0) / (double)n;
        pool_destroy(pool);
    }
    return median_d(times + WARMUP_ROUNDS, rounds);
}

static double bench_batch_search(int n, int64_t *keys, int64_t *search_keys, int rounds) {
    // Batch insert, then scalar search (batch is insert-only optimization)
    double times[BENCH_ROUNDS + WARMUP_ROUNDS];
    for (int r = 0; r < WARMUP_ROUNDS + rounds; r++) {
        Pool *pool = pool_create((uint32_t)(n + 100), 1);
        BatchCtx ctx;
        avl_batch_init(&ctx, pool, -1);
        for (int i = 0; i < n; i++)
            avl_batch_put(&ctx, keys[i]);
        avl_batch_flush(&ctx);
        int32_t root = avl_batch_root(&ctx);
        uint64_t t0 = now_ns();
        for (int i = 0; i < n; i++)
            avl_search_single(pool, root, search_keys[i]);
        uint64_t t1 = now_ns();
        times[r] = (double)(t1 - t0) / (double)n;
        pool_destroy(pool);
    }
    return median_d(times + WARMUP_ROUNDS, rounds);
}

static double bench_batch_mixed(int n, int64_t *keys, int rounds) {
    double times[BENCH_ROUNDS + WARMUP_ROUNDS];
    for (int r = 0; r < WARMUP_ROUNDS + rounds; r++) {
        Pool *pool = pool_create((uint32_t)(n + 100), 1);
        BatchCtx ctx;
        avl_batch_init(&ctx, pool, -1);
        int half = n / 2;
        for (int i = 0; i < half; i++)
            avl_batch_put(&ctx, keys[i]);
        avl_batch_flush(&ctx);
        uint64_t t0 = now_ns();
        for (int i = half; i < n; i++) {
            avl_batch_put(&ctx, keys[i]);
            avl_batch_flush(&ctx);
            avl_search_single(pool, avl_batch_root(&ctx), keys[i - half]);
        }
        uint64_t t1 = now_ns();
        int ops = (n - half) * 2;
        times[r] = (double)(t1 - t0) / (double)ops;
        pool_destroy(pool);
    }
    return median_d(times + WARMUP_ROUNDS, rounds);
}

// ============================================================
//  Output: Racket datum format
// ============================================================

static void emit_datum(FILE *f, int64_t lanes, const char *hostname,
                       const char *timestamp) {
    fprintf(f, ";; AVL Forest Benchmark — auto-generated\n");
    fprintf(f, ";; %s @ %s\n\n", hostname, timestamp);

    // meta
    fprintf(f, "((meta\n");
    fprintf(f, "  (hostname . \"%s\")\n", hostname);
    fprintf(f, "  (timestamp . \"%s\")\n", timestamp);
    fprintf(f, "  (sve-lanes . %lld)\n", (long long)lanes);
    fprintf(f, "  (sve-bits  . %lld)\n", (long long)(lanes * 64));
    fprintf(f, "  (warmup-rounds . %d)\n", WARMUP_ROUNDS);
    fprintf(f, "  (bench-rounds  . %d)\n", BENCH_ROUNDS);
    fprintf(f, "  (unit . \"ns/op\"))\n\n");

    // per-benchmark section
    const char *bench_names[] = { "sequential-insert", "random-search", "mixed-insert-search" };
    for (int b = 0; b < 3; b++) {
        fprintf(f, " (%s\n", bench_names[b]);
        for (int si = 0; si < N_SIZES; si++) {
            Quad *t;
            if      (b == 0) t = &results[si].insert;
            else if (b == 1) t = &results[si].search;
            else             t = &results[si].mixed;
            fprintf(f, "  ((n . %d) (c-scalar . %.2f) (asm-scalar . %.2f) (asm-sve . %.2f) (sve-batch . %.2f))\n",
                    results[si].n, t->c, t->asm_s, t->sve, t->sve_batch);
        }
        fprintf(f, " )\n\n");
    }

    // summary (at largest N)
    SizeResult *last = &results[N_SIZES - 1];
    fprintf(f, " (summary\n");
    fprintf(f, "  (asm-scalar-vs-c-scalar\n");
    fprintf(f, "   (insert-speedup . %.3f)\n",  last->insert.c / last->insert.asm_s);
    fprintf(f, "   (search-speedup . %.3f))\n",  last->search.c / last->search.asm_s);
    fprintf(f, "  (asm-sve-vs-asm-scalar\n");
    fprintf(f, "   (insert-speedup . %.3f)\n",  last->insert.asm_s / last->insert.sve);
    fprintf(f, "   (search-speedup . %.3f))\n",  last->search.asm_s / last->search.sve);
    fprintf(f, "  (asm-sve-vs-c-scalar\n");
    fprintf(f, "   (insert-speedup . %.3f)\n",  last->insert.c / last->insert.sve);
    fprintf(f, "   (search-speedup . %.3f))\n",  last->search.c / last->search.sve);
    fprintf(f, "  (sve-batch-vs-asm-scalar\n");
    fprintf(f, "   (insert-speedup . %.3f)\n",  last->insert.asm_s / last->insert.sve_batch);
    fprintf(f, "   (search-speedup . %.3f))\n",  last->search.asm_s / last->search.sve_batch);

    // peak throughput
    double best_tp = 0;
    for (int si = 0; si < N_SIZES; si++) {
        double tp = 1e9 / results[si].search.sve;
        if (tp > best_tp) best_tp = tp;
    }
    fprintf(f, "  (peak-search-throughput-mops . %.2f))\n", best_tp / 1e6);

    fprintf(f, ")\n");
}

// ============================================================
//  Output: human-readable text report
// ============================================================

static void emit_text_table(FILE *f, const char *title, int bench_idx) {
    fprintf(f, "\n--- %s ---\n", title);
    fprintf(f, "    %-6s|  %-12s|  %-12s|  %-12s|  %-12s| %-s\n",
            "N", "C-scalar", "ASM-scalar", "ASM-SVE", "SVE-Batch", "Batch speedup");
    fprintf(f, "----------+--------------+--------------+--------------+--------------+----------\n");
    for (int si = 0; si < N_SIZES; si++) {
        Quad *t;
        if      (bench_idx == 0) t = &results[si].insert;
        else if (bench_idx == 1) t = &results[si].search;
        else                     t = &results[si].mixed;
        fprintf(f, " %8d | %9.1f ns | %9.1f ns | %9.1f ns | %9.1f ns |   %5.2fx\n",
                results[si].n, t->c, t->asm_s, t->sve, t->sve_batch,
                t->asm_s / t->sve_batch);
    }
}

static void emit_text(FILE *f, int64_t lanes, const char *hostname,
                      const char *timestamp) {
    fprintf(f, "\n");
    fprintf(f, "============================================================\n");
    fprintf(f, "  AVL Forest Benchmark Report\n");
    fprintf(f, "============================================================\n");
    fprintf(f, "  Host      : %s\n", hostname);
    fprintf(f, "  Timestamp : %s\n", timestamp);
    fprintf(f, "  SVE lanes : %lld (%lld-bit)\n",
            (long long)lanes, (long long)(lanes * 64));
    fprintf(f, "  Impls     : C-scalar, ASM-scalar, ASM-SVE(%lld trees), SVE-Batch(1 tree)\n",
            (long long)lanes);
    fprintf(f, "  Method    : %d warmup + %d measured rounds, median ns/op\n",
            WARMUP_ROUNDS, BENCH_ROUNDS);

    emit_text_table(f, "Sequential Insert (keys 1..N)", 0);
    emit_text_table(f, "Random Search (after inserting N keys)", 1);
    emit_text_table(f, "Mixed Insert+Search (50/50)", 2);

    SizeResult *last = &results[N_SIZES - 1];
    fprintf(f, "\n--- Summary (at N=%d) ---\n", last->n);
    fprintf(f, "ASM-scalar vs C-scalar  : %5.2fx faster (insert), %5.2fx faster (search)\n",
            last->insert.c / last->insert.asm_s,
            last->search.c / last->search.asm_s);
    fprintf(f, "ASM-SVE    vs ASM-scalar: %5.2fx faster (insert), %5.2fx faster (search)\n",
            last->insert.asm_s / last->insert.sve,
            last->search.asm_s / last->search.sve);
    fprintf(f, "ASM-SVE    vs C-scalar  : %5.2fx faster (insert), %5.2fx faster (search)\n",
            last->insert.c / last->insert.sve,
            last->search.c / last->search.sve);
    fprintf(f, "SVE-Batch  vs ASM-scalar: %5.2fx faster (insert), %5.2fx faster (search)\n",
            last->insert.asm_s / last->insert.sve_batch,
            last->search.asm_s / last->search.sve_batch);

    double best_tp = 0;
    for (int si = 0; si < N_SIZES; si++) {
        double tp = 1e9 / results[si].search.sve;
        if (tp > best_tp) best_tp = tp;
    }
    fprintf(f, "Peak search throughput  : %.1f M ops/sec (SVE)\n", best_tp / 1e6);
    fprintf(f, "\n");
}

// ============================================================
//  Main
// ============================================================

int main(int argc, char **argv) {
    (void)argc; (void)argv;

    int64_t lanes = sve_lane_count();

    // --- Collect hostname + timestamp ---
    char hostname[256] = "unknown";
    gethostname(hostname, sizeof(hostname));

    time_t now = time(NULL);
    struct tm *tm = localtime(&now);
    char timestamp[64];
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%dT%H:%M:%S", tm);

    // --- Progress banner ---
    fprintf(stderr, "AVL Forest Benchmark  |  SVE %lld lanes  |  host=%s\n",
            (long long)lanes, hostname);
    fprintf(stderr, "Sizes:");
    for (int i = 0; i < N_SIZES; i++) fprintf(stderr, " %d", SIZES[i]);
    fprintf(stderr, "  |  %d warmup + %d rounds\n\n", WARMUP_ROUNDS, BENCH_ROUNDS);

    // --- Run benchmarks ---
    for (int si = 0; si < N_SIZES; si++) {
        int n = SIZES[si];
        results[si].n = n;

        int64_t *keys   = (int64_t *)malloc((size_t)n * sizeof(int64_t));
        int64_t *search = (int64_t *)malloc((size_t)n * sizeof(int64_t));
        for (int i = 0; i < n; i++) keys[i] = (int64_t)(i + 1);
        for (int i = 0; i < n; i++) search[i] = (int64_t)(i + 1);
        xorshift_seed(42 + (uint64_t)n);
        shuffle_i64(search, n);

        // Insert
        fprintf(stderr, "  [%d/%d] N=%-8d insert... ", si + 1, N_SIZES, n);
        fflush(stderr);
        results[si].insert.c         = bench_c_insert(n, keys, BENCH_ROUNDS);
        results[si].insert.asm_s     = bench_asm_insert(n, keys, BENCH_ROUNDS);
        results[si].insert.sve       = bench_sve_insert(n, keys, (int)lanes, BENCH_ROUNDS);
        results[si].insert.sve_batch = bench_batch_insert(n, keys, BENCH_ROUNDS);
        fprintf(stderr, "search... ");
        fflush(stderr);

        // Search
        results[si].search.c         = bench_c_search(n, keys, search, BENCH_ROUNDS);
        results[si].search.asm_s     = bench_asm_search(n, keys, search, BENCH_ROUNDS);
        results[si].search.sve       = bench_sve_search(n, keys, search, (int)lanes, BENCH_ROUNDS);
        results[si].search.sve_batch = bench_batch_search(n, keys, search, BENCH_ROUNDS);
        fprintf(stderr, "mixed... ");
        fflush(stderr);

        // Mixed (shuffle keys for mixed workload)
        xorshift_seed(99 + (uint64_t)n);
        shuffle_i64(keys, n);
        results[si].mixed.c         = bench_c_mixed(n, keys, BENCH_ROUNDS);
        results[si].mixed.asm_s     = bench_asm_mixed(n, keys, BENCH_ROUNDS);
        results[si].mixed.sve       = bench_sve_mixed(n, keys, (int)lanes, BENCH_ROUNDS);
        results[si].mixed.sve_batch = bench_batch_mixed(n, keys, BENCH_ROUNDS);
        fprintf(stderr, "done\n");

        free(keys);
        free(search);
    }

    // --- Build output filenames ---
    // hostname 中的 '.' 替换为 '-'
    char safe_host[256];
    strncpy(safe_host, hostname, sizeof(safe_host) - 1);
    safe_host[sizeof(safe_host) - 1] = '\0';
    for (char *p = safe_host; *p; p++)
        if (*p == '.' || *p == '/') *p = '-';

    char date_tag[32];
    strftime(date_tag, sizeof(date_tag), "%Y%m%d-%H%M%S", tm);

    char datum_path[512], text_path[512];
    snprintf(datum_path, sizeof(datum_path), "bench-%s-%s.datum", safe_host, date_tag);
    snprintf(text_path,  sizeof(text_path),  "bench-%s-%s.txt",  safe_host, date_tag);

    // --- Write datum file ---
    FILE *fd = fopen(datum_path, "w");
    if (!fd) { perror(datum_path); return 1; }
    emit_datum(fd, lanes, hostname, timestamp);
    fclose(fd);

    // --- Write text file ---
    FILE *ft = fopen(text_path, "w");
    if (!ft) { perror(text_path); return 1; }
    emit_text(ft, lanes, hostname, timestamp);
    fclose(ft);

    // --- Print both to stdout ---
    fprintf(stderr, "\n");

    printf("┌─────────────────────────────────────────────────────────────┐\n");
    printf("│  Report files written:                                     │\n");
    printf("│    datum : %-48s│\n", datum_path);
    printf("│    text  : %-48s│\n", text_path);
    printf("└─────────────────────────────────────────────────────────────┘\n");

    // Display text report
    emit_text(stdout, lanes, hostname, timestamp);

    // Display datum report
    printf("\n");
    printf("============================================================\n");
    printf("  Racket Datum\n");
    printf("============================================================\n");
    fd = fopen(datum_path, "r");
    if (fd) {
        char buf[1024];
        while (fgets(buf, sizeof(buf), fd))
            fputs(buf, stdout);
        fclose(fd);
    }
    printf("\n");

    return 0;
}
