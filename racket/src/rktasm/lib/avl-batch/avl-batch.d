;; ============================================================
;; avl-batch.d - SVE 单树批量并行插入库
;; ============================================================
;;
;; 需要与 avl-forest.d 链接 (avl_batch_flush 调用 avl_insert_single)
;;
;; BatchCtx 结构体 (288 bytes, 16-byte aligned):
;;   offset  0: pool_ptr   (ptr)    — 指向 Pool
;;   offset  8: root       (i32)    — 当前树根
;;   offset 12: count      (u32)    — 已缓冲 key 数
;;   offset 16: capacity   (u32)    — SVE 64-bit lane 数 (cntd)
;;   offset 20: _pad       (4B)
;;   offset 24: _pad2      (8B)
;;   offset 32: buf[32]    (i64x32) — key 缓冲区, 256B
;; 总计 288 字节
;;
;; 函数:
;;   avl_batch_init   (x0=ctx, x1=pool, w2=root) → void
;;   avl_batch_put    (x0=ctx, x1=key) → void
;;   avl_batch_flush  (x0=ctx) → void
;;   avl_batch_root   (x0=ctx) → w0=root

;; ============================================================
;; avl_batch_init: 初始化 BatchCtx
;; ============================================================
;; x0 = ctx, x1 = pool, w2 = root
(: function avl_batch_init (export) (abi aapcs64))
(: label entry)
  (str x1 [x0 0])              ; ctx->pool_ptr = pool
  (str w2 [x0 8])              ; ctx->root = root
  (str wzr [x0 12])            ; ctx->count = 0
  (cntd x3)                    ; SVE 64-bit lane count
  (str w3 [x0 16])             ; ctx->capacity = cntd
  (ret)
(: end-function)

;; ============================================================
;; avl_batch_root: 读取当前根
;; ============================================================
;; x0 = ctx → w0 = root
(: function avl_batch_root (export) (abi aapcs64))
(: label entry)
  (ldr w0 [x0 8])              ; return ctx->root
  (ret)
(: end-function)

;; ============================================================
;; avl_batch_put: 缓冲 1 个 key, 满则自动 flush
;; ============================================================
;; x0 = ctx, x1 = key
(: function avl_batch_put (export) (abi aapcs64))
(: save! all)
(: label entry)
  (mov x.ctx x0)
  (mov x.key x1)

  ;; buf[count] = key
  (ldr w.cnt [x.ctx 12])       ; count
  (add x.buf x.ctx 32)         ; &buf[0]
  (str x.key [x.buf w.cnt uxtw 3])  ; buf[count] = key
  (add w.cnt w.cnt 1)
  (str w.cnt [x.ctx 12])       ; count++

  ;; if count >= capacity → flush
  (ldr w.cap [x.ctx 16])       ; capacity
  (cmp w.cnt w.cap)
  (b.lo bp_done)

  ;; flush
  (mov x0 x.ctx)
  (bl avl_batch_flush)

(: label bp_done)
  (: load! all)
  (ret)
(: end-function)

;; ============================================================
;; avl_batch_flush: 并行下降 + 逐条标量插入
;; ============================================================
;; x0 = ctx → void
;;
;; Phase 1: SVE 并行下降 (cache 预热 + 去重标记)
;;   z1 = keys from buf
;;   z0 = cur nodes (start from root)
;;   z5 = -1 sentinel
;;   z6 = dup_mask (0=新key, -1=已存在)
;;   p0 = valid lanes (< count)
;;   p1 = active lanes (cur != -1)
;;   p2 = hit (key == node_key)
;;   p3 = direction (key > node_key → right)
;;
;; Phase 2: 逐条标量插入 (跳过已存在的 key)
;;
;; SVE 物理寄存器, 不经过 regalloc
(: function avl_batch_flush (export) (abi aapcs64))
(: save! all)
(: label entry)
  (mov x.ctx x0)

  ;; 检查 count == 0
  (ldr w.cnt [x.ctx 12])
  (cbz w.cnt bf_ret)

  ;; 加载 pool 指针和字段
  (ldr x.pool [x.ctx 0])       ; pool_ptr
  (ldr x.kb [x.pool 16])       ; key_base
  (ldr x.lb [x.pool 24])       ; left_base
  (ldr x.rb [x.pool 32])       ; right_base

  ;; 加载 root, sign-extend to 64-bit
  (ldrsw x.root [x.ctx 8])

  ;; --- Phase 1: SVE 并行下降 ---

  ;; p0 = valid lanes (< count)
  (mov w.zero 0)
  (whilelt p0.D w.zero w.cnt)

  ;; z1 = 加载 buf 中的 N 个 key
  (add x.buf x.ctx 32)
  (ld1d {z1.D} p0/z [x.buf])

  ;; z0 = dup(root) — 所有 lane 从同一 root 开始
  (dup z0.D w.root)

  ;; z5 = -1 sentinel (via .S fill)
  (mvn w.neg wzr)
  (dup z5.S w.neg)

  ;; z6 = 0 (dup_mask: 0=新key)
  (dup z6.D w.zero)

  ;; p1 = active lanes (cur != -1)
  (cmpne p1.D p0/z z0.D z5.D)
  (b bf_loop)

(: label bf_loop)
  ;; 无 active lanes → 下降结束
  (ptest p0 p1.B)
  (b.eq bf_phase2)

  ;; Gather node keys: z2 = keys[cur]
  (ld1d {z2.D} p1/z [x.kb z0.D lsl 3])

  ;; 命中检查: p2 = (key == node_key)
  (cmpeq p2.D p1/z z1.D z2.D)

  ;; 标记命中 lane 为重复: dup_mask[lane] = -1
  ;; sel z6 = p2 ? z5 : z6  (mov z6.D p2/m z5.D 的等价)
  (sel z6.D p2 z5.D z6.D)

  ;; 方向: p3 = (key > node_key) → go right
  (cmpgt p3.D p1/z z1.D z2.D)

  ;; Gather children (signed 32→64 extend)
  (ld1sw {z3.D} p1/z [x.lb z0.D lsl 2])
  (ld1sw {z4.D} p1/z [x.rb z0.D lsl 2])

  ;; 选择下一层
  (sel z0.D p3 z4.D z3.D)        ; right or left
  (sel z0.D p2 z5.D z0.D)        ; 命中 lane 置 -1 (停止)
  (sel z0.D p1 z0.D z5.D)        ; 非活跃 lane 保持 -1

  ;; 更新 active
  (cmpne p1.D p0/z z0.D z5.D)
  (b bf_loop)

(: label bf_phase2)
  ;; --- Phase 2: 逐条标量插入 ---

  ;; 溢出 dup_mask (z6) 到栈
  (sub sp sp 256)
  (mov x.stk sp)
  (st1d {z6.D} p0 [x.stk])

  ;; Phase 2 循环: for (i = 0; i < count; i++)
  (mov w.i 0)
  (b bf_p2_top)

(: label bf_p2_top)
  ;; 循环条件
  (ldr w.cnt2 [x.ctx 12])        ; reload count
  (cmp w.i w.cnt2)
  (b.hs bf_p2_done)              ; i >= count → 退出循环

  ;; 检查 dup_mask[i]
  (ldr x.dm [x.stk w.i uxtw 3])
  (cbnz x.dm bf_p2_skip)         ; 已存在，跳过

  ;; 加载 key: buf[i]
  ;; 每次循环需重新加载 ctx 字段（caller-saved 被 bl 破坏）
  (ldr x.pool [x.ctx 0])
  (add x.buf x.ctx 32)
  (ldr x2 [x.buf w.i uxtw 3])   ; key = buf[i]

  ;; 调用 avl_insert_single(pool, root, key)
  (mov x0 x.pool)
  (ldr w1 [x.ctx 8])             ; root
  (bl avl_insert_single)

  ;; 保存新 root 回 ctx
  (str w0 [x.ctx 8])

(: label bf_p2_skip)
  (add w.i w.i 1)
  (b bf_p2_top)

(: label bf_p2_done)
  ;; 清空缓冲
  (str wzr [x.ctx 12])           ; count = 0
  ;; 恢复栈
  (add sp sp 256)

(: label bf_ret)
  (: load! all)
  (ret)
(: end-function)
