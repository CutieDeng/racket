#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>

// Pool header layout (must match avl-forest.d)
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

// Assembly functions
extern int32_t node_alloc(Pool *pool);
extern void    node_free(Pool *pool, int32_t idx);
extern int32_t avl_search_single(Pool *pool, int32_t root, int64_t key);
extern int32_t avl_insert_single(Pool *pool, int32_t root, int64_t key);
extern int32_t avl_delete_single(Pool *pool, int32_t root, int64_t key);

#ifdef TEST_SVE
// SVE functions — x0=pool, x1=key (key in second arg slot)
extern int64_t  sve_lane_count(void);
extern int32_t  avl_search_parallel(Pool *pool, int64_t key);
extern void     avl_insert_parallel(Pool *pool, int64_t key);
#endif

Pool *pool_create(uint32_t capacity, uint32_t n_trees) {
    Pool *pool = calloc(1, sizeof(Pool));
    pool->capacity = capacity;
    pool->size = 0;
    pool->free_head = -1;
    pool->n_trees = n_trees;
    pool->key_base   = calloc(capacity, sizeof(int64_t));
    pool->left_base  = malloc(capacity * sizeof(int32_t));
    pool->right_base = malloc(capacity * sizeof(int32_t));
    pool->bf_base    = calloc(capacity, sizeof(int8_t));
    pool->roots_base = malloc(n_trees * sizeof(int32_t));

    // init left/right to -1
    memset(pool->left_base,  0xFF, capacity * sizeof(int32_t));
    memset(pool->right_base, 0xFF, capacity * sizeof(int32_t));

    // init roots to -1 (empty trees)
    for (uint32_t i = 0; i < n_trees; i++)
        pool->roots_base[i] = -1;

    pool->next_hint = 0;
    return pool;
}

void pool_destroy(Pool *pool) {
    free(pool->key_base);
    free(pool->left_base);
    free(pool->right_base);
    free(pool->bf_base);
    free(pool->roots_base);
    free(pool);
}

// Verify AVL property: |bf| <= 1 and bf matches actual height difference
int tree_height(Pool *pool, int32_t node) {
    if (node == -1) return 0;
    int lh = tree_height(pool, pool->left_base[node]);
    int rh = tree_height(pool, pool->right_base[node]);
    return 1 + (lh > rh ? lh : rh);
}

int verify_avl(Pool *pool, int32_t node) {
    if (node == -1) return 1;
    int lh = tree_height(pool, pool->left_base[node]);
    int rh = tree_height(pool, pool->right_base[node]);
    int bf = rh - lh;
    if (bf < -1 || bf > 1) {
        printf("FAIL: node %d bf=%d (lh=%d rh=%d)\n", node, bf, lh, rh);
        return 0;
    }
    if (pool->bf_base[node] != bf) {
        printf("FAIL: node %d stored bf=%d actual bf=%d\n",
               node, pool->bf_base[node], bf);
        return 0;
    }
    return verify_avl(pool, pool->left_base[node]) &&
           verify_avl(pool, pool->right_base[node]);
}

int verify_bst(Pool *pool, int32_t node, int64_t lo, int64_t hi) {
    if (node == -1) return 1;
    int64_t k = pool->key_base[node];
    if (k <= lo || k >= hi) {
        printf("FAIL: BST violation at node %d key=%lld (lo=%lld hi=%lld)\n",
               node, (long long)k, (long long)lo, (long long)hi);
        return 0;
    }
    return verify_bst(pool, pool->left_base[node], lo, k) &&
           verify_bst(pool, pool->right_base[node], k, hi);
}

int tree_size(Pool *pool, int32_t node) {
    if (node == -1) return 0;
    return 1 + tree_size(pool, pool->left_base[node])
             + tree_size(pool, pool->right_base[node]);
}

void test_node_alloc_free() {
    printf("=== test_node_alloc_free ===\n");
    Pool *pool = pool_create(10, 1);

    // Allocate all 10 nodes
    for (int i = 0; i < 10; i++) {
        int32_t idx = node_alloc(pool);
        assert(idx == i);
    }

    // Pool full
    assert(node_alloc(pool) == -1);

    // Free node 3, then alloc should return 3
    node_free(pool, 3);
    assert(node_alloc(pool) == 3);

    // Full again
    assert(node_alloc(pool) == -1);

    pool_destroy(pool);
    printf("PASS\n\n");
}

void test_search_empty() {
    printf("=== test_search_empty ===\n");
    Pool *pool = pool_create(100, 1);
    assert(avl_search_single(pool, -1, 42) == -1);
    pool_destroy(pool);
    printf("PASS\n\n");
}

void test_insert_search() {
    printf("=== test_insert_search ===\n");
    Pool *pool = pool_create(1000, 1);
    int32_t root = -1;

    // Insert 1..100
    for (int i = 1; i <= 100; i++) {
        root = avl_insert_single(pool, root, (int64_t)i);
        assert(root != -1);
    }

    // Search all
    for (int i = 1; i <= 100; i++) {
        int32_t found = avl_search_single(pool, root, (int64_t)i);
        if (found == -1) {
            printf("FAIL: key %d not found\n", i);
            pool_destroy(pool);
            return;
        }
        assert(pool->key_base[found] == (int64_t)i);
    }

    // Search miss
    assert(avl_search_single(pool, root, 0) == -1);
    assert(avl_search_single(pool, root, 101) == -1);

    // Verify AVL property
    assert(verify_bst(pool, root, INT64_MIN, INT64_MAX));
    assert(verify_avl(pool, root));

    int h = tree_height(pool, root);
    printf("100 elements, height=%d (optimal ~7)\n", h);

    pool_destroy(pool);
    printf("PASS\n\n");
}

void test_insert_reverse() {
    printf("=== test_insert_reverse ===\n");
    Pool *pool = pool_create(1000, 1);
    int32_t root = -1;

    // Insert 100..1 (reverse order, worst case for BST)
    for (int i = 100; i >= 1; i--) {
        root = avl_insert_single(pool, root, (int64_t)i);
    }

    for (int i = 1; i <= 100; i++) {
        assert(avl_search_single(pool, root, (int64_t)i) != -1);
    }

    assert(verify_bst(pool, root, INT64_MIN, INT64_MAX));
    assert(verify_avl(pool, root));

    int h = tree_height(pool, root);
    printf("100 elements (reverse), height=%d\n", h);

    pool_destroy(pool);
    printf("PASS\n\n");
}

void test_insert_random() {
    printf("=== test_insert_random ===\n");
    Pool *pool = pool_create(10000, 1);
    int32_t root = -1;

    // Shuffle 1..1000
    int keys[1000];
    for (int i = 0; i < 1000; i++) keys[i] = i + 1;
    for (int i = 999; i > 0; i--) {
        int j = rand() % (i + 1);
        int tmp = keys[i]; keys[i] = keys[j]; keys[j] = tmp;
    }

    for (int i = 0; i < 1000; i++) {
        root = avl_insert_single(pool, root, (int64_t)keys[i]);
    }

    for (int i = 1; i <= 1000; i++) {
        assert(avl_search_single(pool, root, (int64_t)i) != -1);
    }

    assert(verify_bst(pool, root, INT64_MIN, INT64_MAX));
    assert(verify_avl(pool, root));

    int h = tree_height(pool, root);
    printf("1000 elements (random), height=%d (optimal ~10)\n", h);

    pool_destroy(pool);
    printf("PASS\n\n");
}

void test_duplicate_key() {
    printf("=== test_duplicate_key ===\n");
    Pool *pool = pool_create(100, 1);
    int32_t root = -1;

    root = avl_insert_single(pool, root, 42);
    int32_t root2 = avl_insert_single(pool, root, 42);  // duplicate
    assert(root2 == root);  // root unchanged
    assert(pool->size == 1);  // only 1 node allocated

    pool_destroy(pool);
    printf("PASS\n\n");
}

void test_delete_leaf() {
    printf("=== test_delete_leaf ===\n");
    Pool *pool = pool_create(100, 1);
    int32_t root = -1;

    // Insert 3 nodes: 2, 1, 3 → balanced tree with 2 as root
    root = avl_insert_single(pool, root, 2);
    root = avl_insert_single(pool, root, 1);
    root = avl_insert_single(pool, root, 3);

    // Delete leaf node 1
    root = avl_delete_single(pool, root, 1);
    assert(avl_search_single(pool, root, 1) == -1);
    assert(avl_search_single(pool, root, 2) != -1);
    assert(avl_search_single(pool, root, 3) != -1);
    assert(tree_size(pool, root) == 2);
    assert(verify_avl(pool, root));
    assert(verify_bst(pool, root, INT64_MIN, INT64_MAX));

    // Delete leaf node 3
    root = avl_delete_single(pool, root, 3);
    assert(avl_search_single(pool, root, 3) == -1);
    assert(tree_size(pool, root) == 1);
    assert(verify_avl(pool, root));

    pool_destroy(pool);
    printf("PASS\n\n");
}

void test_delete_one_child() {
    printf("=== test_delete_one_child ===\n");
    Pool *pool = pool_create(100, 1);
    int32_t root = -1;

    // Insert 2, 1, 3, 4 → node 3 has one child (4)
    root = avl_insert_single(pool, root, 2);
    root = avl_insert_single(pool, root, 1);
    root = avl_insert_single(pool, root, 3);
    root = avl_insert_single(pool, root, 4);

    // Delete node 3 (has right child 4)
    root = avl_delete_single(pool, root, 3);
    assert(avl_search_single(pool, root, 3) == -1);
    assert(avl_search_single(pool, root, 4) != -1);
    assert(tree_size(pool, root) == 3);
    assert(verify_avl(pool, root));
    assert(verify_bst(pool, root, INT64_MIN, INT64_MAX));

    pool_destroy(pool);
    printf("PASS\n\n");
}

void test_delete_two_children() {
    printf("=== test_delete_two_children ===\n");
    Pool *pool = pool_create(100, 1);
    int32_t root = -1;

    // Insert 1..7 → balanced tree
    for (int i = 1; i <= 7; i++)
        root = avl_insert_single(pool, root, (int64_t)i);

    // Delete node with two children (e.g. 2, which has children 1 and 3)
    root = avl_delete_single(pool, root, 2);
    assert(avl_search_single(pool, root, 2) == -1);
    assert(tree_size(pool, root) == 6);
    assert(verify_avl(pool, root));
    assert(verify_bst(pool, root, INT64_MIN, INT64_MAX));

    // All other keys still present
    for (int i = 1; i <= 7; i++) {
        if (i == 2) continue;
        assert(avl_search_single(pool, root, (int64_t)i) != -1);
    }

    pool_destroy(pool);
    printf("PASS\n\n");
}

void test_delete_root() {
    printf("=== test_delete_root ===\n");
    Pool *pool = pool_create(100, 1);
    int32_t root = -1;

    // Single node
    root = avl_insert_single(pool, root, 42);
    root = avl_delete_single(pool, root, 42);
    assert(root == -1);

    // Build a tree and delete root
    root = -1;
    for (int i = 1; i <= 5; i++)
        root = avl_insert_single(pool, root, (int64_t)i);

    int64_t root_key = pool->key_base[root];
    root = avl_delete_single(pool, root, root_key);
    assert(avl_search_single(pool, root, root_key) == -1);
    assert(tree_size(pool, root) == 4);
    assert(verify_avl(pool, root));
    assert(verify_bst(pool, root, INT64_MIN, INT64_MAX));

    pool_destroy(pool);
    printf("PASS\n\n");
}

void test_delete_not_found() {
    printf("=== test_delete_not_found ===\n");
    Pool *pool = pool_create(100, 1);
    int32_t root = -1;

    // Delete from empty tree
    root = avl_delete_single(pool, root, 42);
    assert(root == -1);

    // Build tree, delete non-existent key
    for (int i = 1; i <= 5; i++)
        root = avl_insert_single(pool, root, (int64_t)i);

    int32_t old_root = root;
    root = avl_delete_single(pool, root, 99);
    assert(root == old_root);
    assert(tree_size(pool, root) == 5);

    pool_destroy(pool);
    printf("PASS\n\n");
}

void test_delete_all() {
    printf("=== test_delete_all ===\n");
    Pool *pool = pool_create(1000, 1);
    int32_t root = -1;

    int N = 100;
    int keys[100];
    for (int i = 0; i < N; i++) keys[i] = i + 1;

    // Shuffle for insertion
    for (int i = N - 1; i > 0; i--) {
        int j = rand() % (i + 1);
        int tmp = keys[i]; keys[i] = keys[j]; keys[j] = tmp;
    }

    for (int i = 0; i < N; i++)
        root = avl_insert_single(pool, root, (int64_t)keys[i]);

    // Shuffle again for deletion order
    for (int i = N - 1; i > 0; i--) {
        int j = rand() % (i + 1);
        int tmp = keys[i]; keys[i] = keys[j]; keys[j] = tmp;
    }

    // Delete all, verify AVL after each
    for (int i = 0; i < N; i++) {
        root = avl_delete_single(pool, root, (int64_t)keys[i]);
        assert(verify_avl(pool, root));
        assert(verify_bst(pool, root, INT64_MIN, INT64_MAX));
        assert(tree_size(pool, root) == N - i - 1);
    }

    assert(root == -1);
    printf("PASS\n\n");
}

void test_insert_delete_mixed() {
    printf("=== test_insert_delete_mixed ===\n");
    Pool *pool = pool_create(10000, 1);
    int32_t root = -1;

    // Track which keys are present
    int present[2001];
    memset(present, 0, sizeof(present));
    int count = 0;

    srand(12345);
    for (int round = 0; round < 5000; round++) {
        int key = (rand() % 2000) + 1;
        if (present[key]) {
            // Delete
            root = avl_delete_single(pool, root, (int64_t)key);
            present[key] = 0;
            count--;
        } else {
            // Insert
            root = avl_insert_single(pool, root, (int64_t)key);
            present[key] = 1;
            count++;
        }
    }

    // Verify final state
    assert(verify_avl(pool, root));
    assert(verify_bst(pool, root, INT64_MIN, INT64_MAX));
    assert(tree_size(pool, root) == count);

    // Verify every key
    for (int k = 1; k <= 2000; k++) {
        int32_t found = avl_search_single(pool, root, (int64_t)k);
        if (present[k]) {
            assert(found != -1);
        } else {
            assert(found == -1);
        }
    }

    int h = tree_height(pool, root);
    printf("%d elements after mixed ops, height=%d\n", count, h);

    pool_destroy(pool);
    printf("PASS\n\n");
}

#ifdef TEST_SVE
void test_sve_lane_count() {
    printf("=== test_sve_lane_count ===\n");
    int64_t lanes = sve_lane_count();
    printf("SVE 64-bit lanes: %lld\n", (long long)lanes);
    assert(lanes > 0);
    assert(lanes <= 32);  // max SVE width is 2048 bits = 32 D-lanes
    printf("PASS\n\n");
}

void test_search_parallel_basic() {
    printf("=== test_search_parallel_basic ===\n");
    int64_t n = sve_lane_count();
    printf("Using %lld trees\n", (long long)n);
    Pool *pool = pool_create(1000, (uint32_t)n);

    // Insert distinct keys into each tree using avl_insert_single
    for (int i = 0; i < (int)n; i++) {
        int64_t key = (i + 1) * 100;  // keys: 100, 200, 300, ...
        pool->roots_base[i] = avl_insert_single(pool, pool->roots_base[i], key);
        // Add a few more keys per tree
        pool->roots_base[i] = avl_insert_single(pool, pool->roots_base[i], key + 1);
        pool->roots_base[i] = avl_insert_single(pool, pool->roots_base[i], key + 2);
    }

    // Parallel search should find all keys
    for (int i = 0; i < (int)n; i++) {
        int64_t key = (i + 1) * 100;
        int32_t found = avl_search_parallel(pool, key);
        if (found == -1) {
            printf("FAIL: key %lld not found\n", (long long)key);
            assert(0);
        }
        assert(pool->key_base[found] == key);

        // Also find key+1, key+2
        found = avl_search_parallel(pool, key + 1);
        assert(found != -1);
        assert(pool->key_base[found] == key + 1);

        found = avl_search_parallel(pool, key + 2);
        assert(found != -1);
        assert(pool->key_base[found] == key + 2);
    }

    pool_destroy(pool);
    printf("PASS\n\n");
}

void test_search_parallel_miss() {
    printf("=== test_search_parallel_miss ===\n");
    int64_t n = sve_lane_count();
    Pool *pool = pool_create(1000, (uint32_t)n);

    // Insert some keys
    for (int i = 0; i < (int)n; i++) {
        pool->roots_base[i] = avl_insert_single(pool, pool->roots_base[i], (i + 1) * 10);
    }

    // Search for non-existent keys
    assert(avl_search_parallel(pool, 999) == -1);
    assert(avl_search_parallel(pool, 0) == -1);
    assert(avl_search_parallel(pool, -1) == -1);

    // Search in empty pool
    Pool *empty = pool_create(100, (uint32_t)n);
    assert(avl_search_parallel(empty, 42) == -1);
    pool_destroy(empty);

    pool_destroy(pool);
    printf("PASS\n\n");
}

void test_insert_parallel() {
    printf("=== test_insert_parallel ===\n");
    int64_t n = sve_lane_count();
    printf("Using %lld trees\n", (long long)n);
    Pool *pool = pool_create(10000, (uint32_t)n);

    int N = 500;
    // Insert keys via parallel insert
    for (int i = 1; i <= N; i++) {
        avl_insert_parallel(pool, (int64_t)i);
    }

    // All keys should be findable via parallel search
    for (int i = 1; i <= N; i++) {
        int32_t found = avl_search_parallel(pool, (int64_t)i);
        if (found == -1) {
            printf("FAIL: key %d not found after parallel insert\n", i);
            assert(0);
        }
        assert(pool->key_base[found] == (int64_t)i);
    }

    // Check total node count
    int total = 0;
    for (int i = 0; i < (int)n; i++) {
        int sz = tree_size(pool, pool->roots_base[i]);
        total += sz;
        // Verify each tree is a valid AVL
        assert(verify_avl(pool, pool->roots_base[i]));
        assert(verify_bst(pool, pool->roots_base[i], INT64_MIN, INT64_MAX));
    }
    assert(total == N);
    printf("Inserted %d keys across %lld trees, total=%d\n", N, (long long)n, total);

    // Print tree sizes
    printf("Tree sizes:");
    for (int i = 0; i < (int)n; i++)
        printf(" %d", tree_size(pool, pool->roots_base[i]));
    printf("\n");

    // Duplicate insert should not add nodes
    avl_insert_parallel(pool, 1);
    total = 0;
    for (int i = 0; i < (int)n; i++)
        total += tree_size(pool, pool->roots_base[i]);
    assert(total == N);

    pool_destroy(pool);
    printf("PASS\n\n");
}

void test_mixed_parallel() {
    printf("=== test_mixed_parallel ===\n");
    int64_t n = sve_lane_count();
    Pool *pool = pool_create(50000, (uint32_t)n);

    int N = 5000;
    // Insert many keys
    for (int i = 1; i <= N; i++) {
        avl_insert_parallel(pool, (int64_t)i);
    }

    // Verify all present
    for (int i = 1; i <= N; i++) {
        int32_t found = avl_search_parallel(pool, (int64_t)i);
        if (found == -1) {
            printf("FAIL: key %d not found\n", i);
            assert(0);
        }
    }

    // Verify miss
    for (int i = N + 1; i <= N + 100; i++) {
        assert(avl_search_parallel(pool, (int64_t)i) == -1);
    }

    // Verify all trees are valid AVL
    int total = 0;
    for (int i = 0; i < (int)n; i++) {
        assert(verify_avl(pool, pool->roots_base[i]));
        assert(verify_bst(pool, pool->roots_base[i], INT64_MIN, INT64_MAX));
        total += tree_size(pool, pool->roots_base[i]);
    }
    assert(total == N);

    int max_h = 0;
    for (int i = 0; i < (int)n; i++) {
        int h = tree_height(pool, pool->roots_base[i]);
        if (h > max_h) max_h = h;
    }
    printf("%d keys in %lld trees, max height=%d (single-tree optimal ~%d)\n",
           N, (long long)n, max_h, (int)(1.44 * 12.3));  // log2(5000) ≈ 12.3

    pool_destroy(pool);
    printf("PASS\n\n");
}
#endif

int main() {
    test_node_alloc_free();
    test_search_empty();
    test_insert_search();
    test_insert_reverse();
    test_insert_random();
    test_duplicate_key();
    test_delete_leaf();
    test_delete_one_child();
    test_delete_two_children();
    test_delete_root();
    test_delete_not_found();
    test_delete_all();
    test_insert_delete_mixed();

#ifdef TEST_SVE
    test_sve_lane_count();
    test_search_parallel_basic();
    test_search_parallel_miss();
    test_insert_parallel();
    test_mixed_parallel();
#endif

    printf("All tests passed!\n");
    return 0;
}
