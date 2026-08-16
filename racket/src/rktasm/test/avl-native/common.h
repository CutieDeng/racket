#ifndef COMMON_H
#define COMMON_H

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>

// Pool header layout (must match avl-forest.d exactly)
//   offset 0:  capacity   (u32)
//   offset 4:  size       (u32)
//   offset 8:  free_head  (i32)
//   offset 12: n_trees    (u32)
//   offset 16: key_base   (ptr)
//   offset 24: left_base  (ptr)
//   offset 32: right_base (ptr)
//   offset 40: bf_base    (ptr)
//   offset 48: roots_base (ptr)
//   offset 56: next_hint  (u32)
typedef struct {
    uint32_t capacity;
    uint32_t size;
    int32_t  free_head;
    uint32_t n_trees;
    int64_t  *key_base;
    int32_t  *left_base;
    int32_t  *right_base;
    int8_t   *bf_base;
    int32_t  *roots_base;
    uint32_t next_hint;
} Pool;

// BatchCtx layout (must match avl-batch.d exactly)
//   offset  0: pool_ptr   (ptr)
//   offset  8: root       (i32)
//   offset 12: count      (u32)
//   offset 16: capacity   (u32)
//   offset 20: _pad       (4B)
//   offset 24: _pad2      (8B)
//   offset 32: buf[32]    (i64x32, 256B)
// total 288 bytes, 16-byte aligned
typedef struct {
    Pool    *pool_ptr;
    int32_t  root;
    uint32_t count;
    uint32_t capacity;
    uint32_t _pad;
    uint64_t _pad2;
    int64_t  buf[32];
} BatchCtx __attribute__((aligned(16)));

// --- High-precision timing (Linux) ---

static inline uint64_t now_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
}

// --- Pool lifecycle ---

static Pool *pool_create(uint32_t capacity, uint32_t n_trees) {
    Pool *pool = (Pool *)calloc(1, sizeof(Pool));
    pool->capacity   = capacity;
    pool->size       = 0;
    pool->free_head  = -1;
    pool->n_trees    = n_trees;
    pool->key_base   = (int64_t *)calloc(capacity, sizeof(int64_t));
    pool->left_base  = (int32_t *)malloc(capacity * sizeof(int32_t));
    pool->right_base = (int32_t *)malloc(capacity * sizeof(int32_t));
    pool->bf_base    = (int8_t  *)calloc(capacity, sizeof(int8_t));
    pool->roots_base = (int32_t *)malloc(n_trees * sizeof(int32_t));
    memset(pool->left_base,  0xFF, capacity * sizeof(int32_t));
    memset(pool->right_base, 0xFF, capacity * sizeof(int32_t));
    for (uint32_t i = 0; i < n_trees; i++)
        pool->roots_base[i] = -1;
    pool->next_hint = 0;
    return pool;
}

static void pool_destroy(Pool *pool) {
    free(pool->key_base);
    free(pool->left_base);
    free(pool->right_base);
    free(pool->bf_base);
    free(pool->roots_base);
    free(pool);
}

static void pool_reset(Pool *pool) {
    pool->size = 0;
    pool->free_head = -1;
    memset(pool->key_base,   0,    pool->capacity * sizeof(int64_t));
    memset(pool->left_base,  0xFF, pool->capacity * sizeof(int32_t));
    memset(pool->right_base, 0xFF, pool->capacity * sizeof(int32_t));
    memset(pool->bf_base,    0,    pool->capacity * sizeof(int8_t));
    for (uint32_t i = 0; i < pool->n_trees; i++)
        pool->roots_base[i] = -1;
    pool->next_hint = 0;
}

// --- Tree verification ---

static int tree_height(Pool *pool, int32_t node) {
    if (node == -1) return 0;
    int lh = tree_height(pool, pool->left_base[node]);
    int rh = tree_height(pool, pool->right_base[node]);
    return 1 + (lh > rh ? lh : rh);
}

static int tree_size(Pool *pool, int32_t node) {
    if (node == -1) return 0;
    return 1 + tree_size(pool, pool->left_base[node])
             + tree_size(pool, pool->right_base[node]);
}

static int verify_avl(Pool *pool, int32_t node) {
    if (node == -1) return 1;
    int lh = tree_height(pool, pool->left_base[node]);
    int rh = tree_height(pool, pool->right_base[node]);
    int bf = rh - lh;
    if (bf < -1 || bf > 1) {
        printf("  AVL violation: node %d bf=%d (lh=%d rh=%d)\n", node, bf, lh, rh);
        return 0;
    }
    if (pool->bf_base[node] != bf) {
        printf("  BF mismatch: node %d stored=%d actual=%d\n",
               node, pool->bf_base[node], bf);
        return 0;
    }
    return verify_avl(pool, pool->left_base[node]) &&
           verify_avl(pool, pool->right_base[node]);
}

static int verify_bst(Pool *pool, int32_t node, int64_t lo, int64_t hi) {
    if (node == -1) return 1;
    int64_t k = pool->key_base[node];
    if (k <= lo || k >= hi) {
        printf("  BST violation: node %d key=%lld (lo=%lld hi=%lld)\n",
               node, (long long)k, (long long)lo, (long long)hi);
        return 0;
    }
    return verify_bst(pool, pool->left_base[node], lo, k) &&
           verify_bst(pool, pool->right_base[node], k, hi);
}

// --- Report formatting ---

static void print_header(const char *title) {
    printf("\n");
    printf("============================================================\n");
    printf("  %s\n", title);
    printf("============================================================\n");
}

static void print_separator(void) {
    printf("----------+--------------+--------------+--------------+----------\n");
}

static void print_bench_header(void) {
    printf("    %-6s|  %-12s|  %-12s|  %-12s| %-s\n",
           "N", "C-scalar", "ASM-scalar", "ASM-SVE", "SVE speedup");
    print_separator();
}

static void print_result_row(const char *impl_c, const char *impl_asm,
                              const char *impl_sve,
                              int N, double c_ns, double asm_ns, double sve_ns) {
    printf(" %8d | %9.1f ns | %9.1f ns | %9.1f ns |   %5.2fx\n",
           N, c_ns, asm_ns, sve_ns, asm_ns / sve_ns);
    (void)impl_c; (void)impl_asm; (void)impl_sve;
}

static void print_speedup(const char *base, const char *fast,
                           double base_insert, double fast_insert,
                           double base_search, double fast_search) {
    printf("%-22s vs %-12s: %.2fx faster (insert), %.2fx faster (search)\n",
           fast, base, base_insert / fast_insert, base_search / fast_search);
}

// --- Simple PRNG (xorshift64) for reproducible benchmarks ---

static uint64_t xorshift_state = 88172645463325252ULL;

static void xorshift_seed(uint64_t s) {
    xorshift_state = s ? s : 88172645463325252ULL;
}

static uint64_t xorshift64(void) {
    uint64_t x = xorshift_state;
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    xorshift_state = x;
    return x;
}

// Fisher-Yates shuffle
static void shuffle_i64(int64_t *arr, int n) {
    for (int i = n - 1; i > 0; i--) {
        int j = (int)(xorshift64() % (uint64_t)(i + 1));
        int64_t tmp = arr[i]; arr[i] = arr[j]; arr[j] = tmp;
    }
}

// Comparison for qsort of doubles
static int cmp_double(const void *a, const void *b) {
    double da = *(const double *)a, db = *(const double *)b;
    return (da > db) - (da < db);
}

// Return median of array (sorts in place)
static double median_d(double *arr, int n) {
    qsort(arr, (size_t)n, sizeof(double), cmp_double);
    if (n % 2 == 1) return arr[n / 2];
    return (arr[n / 2 - 1] + arr[n / 2]) / 2.0;
}

#endif // COMMON_H
