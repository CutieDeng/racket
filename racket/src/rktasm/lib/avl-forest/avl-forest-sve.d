;; ============================================================
;; avl-forest-sve.d - SVE 并行操作 (Phase 3)
;; ============================================================
;;
;; 需要与 avl-forest.d 链接 (avl_insert_parallel 调用 avl_insert_single)
;;
;; 函数:
;;   sve_lane_count      → x0 = 64-bit lane count
;;   avl_search_parallel → 并行 N 树搜索
;;   avl_insert_parallel → round-robin 选树 + 标量插入

;; ============================================================
;; sve_lane_count: 返回 64-bit SVE lane 数
;; ============================================================
;; 返回: x0 = VL/64 (number of 64-bit lanes)
(: function sve_lane_count (export))
(: label entry)
  (cntd x0)
  (ret)
(: end-function)

;; ============================================================
;; avl_search_parallel: SVE 并行多树搜索
;; ============================================================
;; x0 = pool ptr, x1 = key
;; 返回: w0 = node index (-1 = not found)
;;
;; SVE 向量/谓词 (物理, regalloc 不管):
;;   z0=cur, z1=key, z2=nk, z3=left, z4=right, z5=neg1
;;   p0=valid, p1=active, p2=hit, p3=direction
(: function avl_search_parallel (export) (abi aapcs64))
(: label entry)
  ;; 保存参数到虚拟寄存器
  (mov x.pool x0)
  (mov x.key x1)

  ;; 加载 pool 字段
  (ldr w.nt [x.pool 12])       ; n_trees
  (ldr x.roots [x.pool 48])    ; roots_base
  (ldr x.kb [x.pool 16])       ; key_base
  (ldr x.lb [x.pool 24])       ; left_base
  (ldr x.rb [x.pool 32])       ; right_base

  ;; valid lanes: p0 = lane < n_trees
  (mov w.zero 0)
  (whilelt p0.D w.zero w.nt)

  ;; 加载 N 个 roots → z0 (signed 32→64 extend)
  (ld1sw {z0.D} p0/z [x.roots])

  ;; 广播 key → z1
  ;; NOTE: assembler 写 w.key 但 .D 编码使 CPU 读取完整 64-bit x.key
  (dup z1.D w.key)

  ;; z5 = -1 (sentinel): 用 S 元素填充 0xFFFFFFFF → 每个 D 元素 = -1
  (mvn w.neg wzr)
  (dup z5.S w.neg)

  ;; p1 = active lanes (cur != -1)
  (cmpne p1.D p0/z z0.D z5.D)
  (b sp_loop)

(: label sp_loop)
  (ptest p0 p1.B)
  (b.eq sp_miss)

  ;; Gather keys: z2 = keys[cur]
  (ld1d {z2.D} p1/z [x.kb z0.D lsl 3])

  ;; 命中检查: p2 = (nk == key)
  (cmpeq p2.D p1/z z2.D z1.D)
  (ptest p0 p2.B)
  (b.ne sp_hit)

  ;; 方向: p3 = (key > nk) → go right
  (cmpgt p3.D p1/z z1.D z2.D)

  ;; Gather children
  (ld1sw {z3.D} p1/z [x.lb z0.D lsl 2])
  (ld1sw {z4.D} p1/z [x.rb z0.D lsl 2])

  ;; 选择下一层 cur + 非活跃 lane 置 -1
  (sel z0.D p3 z4.D z3.D)
  (sel z0.D p1 z0.D z5.D)

  ;; 更新 active
  (cmpne p1.D p0/z z0.D z5.D)
  (b sp_loop)

(: label sp_hit)
  (lastb w0 p2 z0.D)
  (ret)

(: label sp_miss)
  (mvn w0 wzr)
  (ret)
(: end-function)

;; ============================================================
;; avl_insert_parallel: SVE 并行查重 + round-robin 选树 + 标量插入
;; ============================================================
;; x0 = pool ptr, x1 = key
;; 无返回值 (修改 pool.roots in-place)
;;
;; 算法:
;;   1. SVE 并行下降 N 棵树, 仅检查 duplicate
;;   2. 选树: 纯 round-robin (pool->next_hint, offset +56)
;;   3. bl avl_insert_single 执行标量插入
;;   4. 更新 next_hint = (tree_idx + 1) % n_trees
;;
;; SVE 向量/谓词 (物理):
;;   z0=cur, z1=key, z2=nk, z3=left, z4=right, z5=neg1
;;   p0=valid, p1=active, p2=hit, p3=direction
(: function avl_insert_parallel (export) (abi aapcs64))
(: save! all)
(: label entry)
  ;; 保存参数到虚拟寄存器 (跨 bl 存活, allocator 自动分配 callee-saved)
  (mov x.pool x0)
  (mov x.key x1)

  ;; 加载 pool 字段
  (ldr w.nt [x.pool 12])       ; n_trees
  (ldr x.roots [x.pool 48])    ; roots_base
  (ldr x.kb [x.pool 16])       ; key_base
  (ldr x.lb [x.pool 24])       ; left_base
  (ldr x.rb [x.pool 32])       ; right_base

  ;; valid lanes: p0 = lane < n_trees
  (mov w.zero 0)
  (whilelt p0.D w.zero w.nt)

  ;; 加载 roots → z0
  (ld1sw {z0.D} p0/z [x.roots])

  ;; 广播 key → z1
  (dup z1.D w.key)

  ;; z5 = -1 sentinel
  (mvn w.neg wzr)
  (dup z5.S w.neg)

  ;; p1 = active lanes (cur != -1)
  (cmpne p1.D p0/z z0.D z5.D)
  (b ip_loop)

(: label ip_loop)
  ;; 无 active lanes → 查重结束
  (ptest p0 p1.B)
  (b.eq ip_do_insert)

  ;; Gather node keys
  (ld1d {z2.D} p1/z [x.kb z0.D lsl 3])

  ;; Duplicate check
  (cmpeq p2.D p1/z z2.D z1.D)
  (ptest p0 p2.B)
  (b.ne ip_duplicate)

  ;; Direction: p3 = key > nk → right
  (cmpgt p3.D p1/z z1.D z2.D)

  ;; Gather children
  (ld1sw {z3.D} p1/z [x.lb z0.D lsl 2])
  (ld1sw {z4.D} p1/z [x.rb z0.D lsl 2])

  ;; 选择 + 非活跃 lane 置 -1
  (sel z0.D p3 z4.D z3.D)
  (sel z0.D p1 z0.D z5.D)

  ;; 更新 active
  (cmpne p1.D p0/z z0.D z5.D)
  (b ip_loop)

(: label ip_do_insert)
  ;; Round-robin 选树
  (ldr w.tidx [x.pool 56])              ; pool->next_hint

  ;; 调用 avl_insert_single(pool, roots[tidx], key)
  (ldr w1 [x.roots w.tidx uxtw 2])      ; roots[tidx]
  (mov x0 x.pool)
  (mov x2 x.key)
  (bl avl_insert_single)

  ;; 存储新 root
  (str w0 [x.roots w.tidx uxtw 2])

  ;; 更新 next_hint = (tidx + 1) % n_trees
  (add w.next w.tidx 1)
  (ldr w.nt2 [x.pool 12])
  (cmp w.next w.nt2)
  (b.lo ip_done)
  (mov w.next 0)
(: label ip_done)
  (str w.next [x.pool 56])
  (: load! all)
  (ret)

(: label ip_duplicate)
  (: load! all)
  (ret)
(: end-function)
