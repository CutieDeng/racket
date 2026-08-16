#ifndef C_AVL_H
#define C_AVL_H

#include "common.h"

// Pure C AVL implementation using the same Pool memory layout.
// This provides a fair baseline for benchmarking against the ASM implementations.

static int32_t c_node_alloc(Pool *pool) {
    if (pool->free_head != -1) {
        int32_t idx = pool->free_head;
        pool->free_head = pool->left_base[idx];
        pool->left_base[idx]  = -1;
        pool->right_base[idx] = -1;
        pool->bf_base[idx]    = 0;
        pool->key_base[idx]   = 0;
        return idx;
    }
    if (pool->size >= pool->capacity) return -1;
    int32_t idx = (int32_t)pool->size++;
    pool->left_base[idx]  = -1;
    pool->right_base[idx] = -1;
    pool->bf_base[idx]    = 0;
    return idx;
}

static int32_t c_avl_search(Pool *pool, int32_t root, int64_t key) {
    int32_t cur = root;
    while (cur != -1) {
        int64_t k = pool->key_base[cur];
        if (key == k) return cur;
        if (key < k)
            cur = pool->left_base[cur];
        else
            cur = pool->right_base[cur];
    }
    return -1;
}

// --- Rotations ---

static int32_t c_rotate_left(Pool *pool, int32_t x) {
    int32_t y = pool->right_base[x];
    int32_t t = pool->left_base[y];
    pool->left_base[y]  = x;
    pool->right_base[x] = t;
    // Update balance factors
    // After left rotation of x with right child y:
    //   old: bf(x), bf(y)
    //   new: bf(x) = bf(x) - 1 - max(bf(y), 0)
    //        bf(y) = bf(y) - 1 + min(bf(x_new), 0)
    // But simpler: just recompute from children heights conceptually.
    // We use the algebraic update:
    int8_t bx = pool->bf_base[x];
    int8_t by = pool->bf_base[y];
    int8_t new_bx = bx - 1 - (by > 0 ? by : 0);
    int8_t new_by = by - 1 + (new_bx < 0 ? new_bx : 0);
    pool->bf_base[x] = new_bx;
    pool->bf_base[y] = new_by;
    return y;
}

static int32_t c_rotate_right(Pool *pool, int32_t y) {
    int32_t x = pool->left_base[y];
    int32_t t = pool->right_base[x];
    pool->right_base[x] = y;
    pool->left_base[y]  = t;
    int8_t by = pool->bf_base[y];
    int8_t bx = pool->bf_base[x];
    int8_t new_by = by + 1 - (bx < 0 ? bx : 0);
    int8_t new_bx = bx + 1 + (new_by > 0 ? new_by : 0);
    pool->bf_base[y] = new_by;
    pool->bf_base[x] = new_bx;
    return x;
}

// --- Recursive insert with AVL rebalance ---

static int32_t c_avl_insert_rec(Pool *pool, int32_t node, int64_t key, int *height_changed) {
    if (node == -1) {
        int32_t n = c_node_alloc(pool);
        if (n == -1) return -1;
        pool->key_base[n] = key;
        *height_changed = 1;
        return n;
    }

    int64_t k = pool->key_base[node];
    if (key == k) {
        *height_changed = 0;
        return node; // duplicate
    }

    if (key < k) {
        int hc = 0;
        int32_t new_left = c_avl_insert_rec(pool, pool->left_base[node], key, &hc);
        pool->left_base[node] = new_left;
        if (hc) {
            pool->bf_base[node]--;
            if (pool->bf_base[node] == 0) {
                *height_changed = 0;
            } else if (pool->bf_base[node] == -1) {
                *height_changed = 1;
            } else {
                // bf == -2, rebalance
                if (pool->bf_base[new_left] <= 0) {
                    // LL case
                    node = c_rotate_right(pool, node);
                } else {
                    // LR case
                    pool->left_base[node] = c_rotate_left(pool, new_left);
                    node = c_rotate_right(pool, node);
                }
                *height_changed = 0;
            }
        } else {
            *height_changed = 0;
        }
    } else {
        int hc = 0;
        int32_t new_right = c_avl_insert_rec(pool, pool->right_base[node], key, &hc);
        pool->right_base[node] = new_right;
        if (hc) {
            pool->bf_base[node]++;
            if (pool->bf_base[node] == 0) {
                *height_changed = 0;
            } else if (pool->bf_base[node] == 1) {
                *height_changed = 1;
            } else {
                // bf == 2, rebalance
                if (pool->bf_base[new_right] >= 0) {
                    // RR case
                    node = c_rotate_left(pool, node);
                } else {
                    // RL case
                    pool->right_base[node] = c_rotate_right(pool, new_right);
                    node = c_rotate_left(pool, node);
                }
                *height_changed = 0;
            }
        } else {
            *height_changed = 0;
        }
    }

    return node;
}

static int32_t c_avl_insert(Pool *pool, int32_t root, int64_t key) {
    int hc = 0;
    return c_avl_insert_rec(pool, root, key, &hc);
}

#endif // C_AVL_H
