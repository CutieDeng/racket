;; ============================================================
;; avl-forest.d - SVE AVL 森林库
;; ============================================================
;;
;; M 个元素分散到 N 棵 AVL 树 (N = SVE vector width / 64bit)
;; 搜索: SVE 并行查 N 棵树, 深度 = log2(M/N)
;; 插入: SVE 并行下降找最浅树, 标量迭代插入
;;
;; Pool Header 布局 (64 bytes):
;;   +0   capacity   : u32
;;   +4   size       : u32
;;   +8   free_head  : i32   (-1 = empty)
;;   +12  n_trees    : u32
;;   +16  key_base   : ptr   keys[C] : i64
;;   +24  left_base  : ptr   left[C] : i32
;;   +32  right_base : ptr   right[C] : i32
;;   +40  bf_base    : ptr   bf[C] : i8
;;   +48  roots_base : ptr   roots[N] : i32
;;   +56  next_hint  : u32   round-robin 选树提示
;;
;; 约定: 节点索引 i32, -1 = null; key i64; bf i8 (-2..+2)
;; 空闲管理: free list 复用 left[] 字段

;; ============================================================
;; node_alloc: 分配一个节点
;; ============================================================
;; x0 = pool ptr
;; 返回: w0 = node index, -1 = full
(: function node_alloc (export) (abi aapcs64))
(: label entry)
  (ldr w.idx [x0 8])
  (cmn w.idx 1)
  (b.eq try_bump)

  ;; free list pop
  (ldr x.lb [x0 24])
  (ldr w.next [x.lb w.idx uxtw 2])
  (str w.next [x0 8])
  ;; init node: left=-1, right=-1, bf=0
  (mvn w.null wzr)
  (str w.null [x.lb w.idx uxtw 2])
  (ldr x.rb [x0 32])
  (str w.null [x.rb w.idx uxtw 2])
  (ldr x.bb [x0 40])
  (strb wzr [x.bb w.idx uxtw])
  (mov w0 w.idx)
  (ret)

(: label try_bump)
  (mov x.pool x0)
  (ldr w.size [x.pool 4])
  (ldr w.cap [x.pool 0])
  (cmp w.size w.cap)
  (b.hs bump_full)

  (mov w0 w.size)
  (add w.size w.size 1)
  (str w.size [x.pool 4])

  ;; init node: left=-1, right=-1, bf=0
  (ldr x.lb [x.pool 24])
  (ldr x.rb [x.pool 32])
  (ldr x.bb [x.pool 40])
  (mvn w.null wzr)
  (str w.null [x.lb w0 uxtw 2])
  (str w.null [x.rb w0 uxtw 2])
  (strb wzr [x.bb w0 uxtw])
  (ret)

(: label bump_full)
  (mvn w0 wzr)
  (ret)
(: end-function)

;; ============================================================
;; node_free: 释放节点
;; ============================================================
;; x0 = pool ptr, w1 = node index
(: function node_free (export) (abi aapcs64))
(: label entry)
  (ldr x.lb [x0 24])
  (ldr w.old [x0 8])
  (str w.old [x.lb w1 uxtw 2])
  (str w1 [x0 8])
  (ret)
(: end-function)

;; ============================================================
;; avl_search_single: 单树迭代搜索
;; ============================================================
;; x0 = pool ptr, w1 = root, x2 = key
;; 返回: w0 = node index, -1 = not found
(: function avl_search_single (export) (abi aapcs64))
(: label entry)
  (ldr x.kb [x0 16])
  (mov w.cur w1)

(: label loop)
  (cmn w.cur 1)
  (b.eq miss)
  (ldr x.nk [x.kb w.cur uxtw 3])
  (cmp x2 x.nk)
  (b.eq hit)
  (b.lt left)

  ;; right
  (ldr x.rb [x0 32])
  (ldr w.cur [x.rb w.cur uxtw 2])
  (b loop)
(: label left)
  (ldr x.lb [x0 24])
  (ldr w.cur [x.lb w.cur uxtw 2])
  (b loop)

(: label hit)
  (mov w0 w.cur)
  (ret)
(: label miss)
  (mvn w0 wzr)
  (ret)
(: end-function)

;; ============================================================
;; avl_insert_single: 单树迭代插入 + rebalance
;; ============================================================
;; x0 = pool ptr, w1 = root (-1 = empty), x2 = key
;; 返回: w0 = new root
(: function avl_insert_single (export) (abi aapcs64))
(: save! all)
(: label entry)
  (mov x.pool x0)
  (mov w.root w1)
  (mov x.key x2)

  ;; 加载 base
  (ldr x.kb [x.pool 16])
  (ldr x.lb [x.pool 24])
  (ldr x.rb [x.pool 32])
  (ldr x.bb [x.pool 40])

  ;; 路径栈: path[48]*4=192, dir[48]*1=48, total=240→256
  (sub sp sp 256)
  (mov x.path sp)
  (add x.dir sp 192)

  ;; === 下降 ===
  (mov w.cur w.root)
  (mov w.depth 0)

(: label descend)
  (cmn w.cur 1)
  (b.eq ins_here)

  (str w.cur [x.path w.depth uxtw 2])
  (ldr x.nk [x.kb w.cur uxtw 3])
  (cmp x.key x.nk)
  (b.eq dup_key)
  (b.lt desc_left)

  ;; right: dir=1
  (mov w.d 1)
  (strb w.d [x.dir w.depth uxtw])
  (ldr w.cur [x.rb w.cur uxtw 2])
  (add w.depth w.depth 1)
  (b descend)

(: label desc_left)
  (strb wzr [x.dir w.depth uxtw])
  (ldr w.cur [x.lb w.cur uxtw 2])
  (add w.depth w.depth 1)
  (b descend)

(: label dup_key)
  (mov w0 w.root)
  (add sp sp 256)
  (: load! all)
  (ret)

;; === 分配新节点 ===
(: label ins_here)
  ;; 分配器会自动将跨调用活跃变量放到 callee-saved 寄存器
  (mov x0 x.pool)
  (bl node_alloc)
  (mov w.new w0)

  (cmn w.new 1)
  (b.eq alloc_fail)

  ;; set key
  (str x.key [x.kb w.new uxtw 3])

  ;; 挂到 parent
  (cbz w.depth new_tree)

  (sub w.pd w.depth 1)
  (ldr w.par [x.path w.pd uxtw 2])
  (ldrb w.d [x.dir w.pd uxtw])
  (cbnz w.d link_r)
  (str w.new [x.lb w.par uxtw 2])
  (b rebal_start)
(: label link_r)
  (str w.new [x.rb w.par uxtw 2])
  (b rebal_start)

;; === 回溯 rebalance ===
(: label rebal_start)
  (sub w.ri w.depth 1)

(: label rebal_loop)
  (tbnz w.ri 31 rebal_done)

  (ldr w.node [x.path w.ri uxtw 2])
  (ldrb w.d [x.dir w.ri uxtw])

  ;; bf += (dir==1) ? +1 : -1
  (ldrsb w.bf [x.bb w.node uxtw])
  (cbnz w.d bf_add)
  (sub w.bf w.bf 1)
  (b bf_set)
(: label bf_add)
  (add w.bf w.bf 1)
  (b bf_set)
(: label bf_set)
  (strb w.bf [x.bb w.node uxtw])

  ;; bf==0 → 高度没变
  (cbz w.bf rebal_done)

  ;; |bf|==1 → 继续回溯
  (cmp w.bf 1)
  (b.eq rebal_next)
  (cmn w.bf 1)
  (b.eq rebal_next)

  ;; |bf|==2 → 旋转
  (cmn w.bf 2)
  (b.eq rot_left_heavy)

  ;; bf==+2: 右重
  (ldr w.ch [x.rb w.node uxtw 2])
  (ldrsb w.cbf [x.bb w.ch uxtw])
  (tbnz w.cbf 31 rot_rl)

  ;; RR: 左旋
  (ldr w.cl [x.lb w.ch uxtw 2])
  (str w.cl [x.rb w.node uxtw 2])
  (str w.node [x.lb w.ch uxtw 2])
  (strb wzr [x.bb w.node uxtw])
  (strb wzr [x.bb w.ch uxtw])
  (mov w.nsub w.ch)
  (b fix_par)

(: label rot_rl)
  ;; RL: 右旋 child, 左旋 node
  ;; 重新加载 ch 避免跨块活跃分析 bug
  (ldr w.rch [x.rb w.node uxtw 2])
  (ldr w.rgc [x.lb w.rch uxtw 2])
  ;; 保存 gc 原始 bf
  (ldrsb w.gbf [x.bb w.rgc uxtw])
  ;; 指针重排
  (ldr w.t [x.rb w.rgc uxtw 2])
  (str w.t [x.lb w.rch uxtw 2])
  (ldr w.t [x.lb w.rgc uxtw 2])
  (str w.t [x.rb w.node uxtw 2])
  (str w.rch [x.rb w.rgc uxtw 2])
  (str w.node [x.lb w.rgc uxtw 2])
  ;; 更新 bf: gc.bf=0 总是; node 和 ch 取决于 gc 原始 bf
  (strb wzr [x.bb w.rgc uxtw])
  ;; if gbf==+1: node.bf=-1, ch.bf=0
  ;; if gbf==-1: node.bf=0,  ch.bf=+1
  ;; if gbf==0:  node.bf=0,  ch.bf=0
  (strb wzr [x.bb w.node uxtw])
  (strb wzr [x.bb w.rch uxtw])
  (cmp w.gbf 1)
  (b.ne rl_not_pos)
  (mvn w.t wzr)
  (strb w.t [x.bb w.node uxtw])
  (b rl_bf_done)
(: label rl_not_pos)
  (cmn w.gbf 1)
  (b.ne rl_bf_done)
  (mov w.t 1)
  (strb w.t [x.bb w.rch uxtw])
  (b rl_bf_done)
(: label rl_bf_done)
  (mov w.nsub w.rgc)
  (b fix_par)

(: label rot_left_heavy)
  ;; bf==-2: 左重
  (ldr w.ch [x.lb w.node uxtw 2])
  (ldrsb w.cbf [x.bb w.ch uxtw])
  (cmp w.cbf 0)
  (b.gt rot_lr)

  ;; LL: 右旋
  (ldr w.cr [x.rb w.ch uxtw 2])
  (str w.cr [x.lb w.node uxtw 2])
  (str w.node [x.rb w.ch uxtw 2])
  (strb wzr [x.bb w.node uxtw])
  (strb wzr [x.bb w.ch uxtw])
  (mov w.nsub w.ch)
  (b fix_par)

(: label rot_lr)
  ;; LR: 左旋 child, 右旋 node
  ;; 重新加载 ch 避免跨块活跃分析 bug
  (ldr w.lch [x.lb w.node uxtw 2])
  (ldr w.lgc [x.rb w.lch uxtw 2])
  ;; 保存 gc 原始 bf
  (ldrsb w.gbf [x.bb w.lgc uxtw])
  ;; 指针重排
  (ldr w.t [x.lb w.lgc uxtw 2])
  (str w.t [x.rb w.lch uxtw 2])
  (ldr w.t [x.rb w.lgc uxtw 2])
  (str w.t [x.lb w.node uxtw 2])
  (str w.lch [x.lb w.lgc uxtw 2])
  (str w.node [x.rb w.lgc uxtw 2])
  ;; 更新 bf: gc.bf=0 总是; node 和 ch 取决于 gc 原始 bf
  (strb wzr [x.bb w.lgc uxtw])
  ;; if gbf==-1: node.bf=+1, ch.bf=0
  ;; if gbf==+1: node.bf=0,  ch.bf=-1
  ;; if gbf==0:  node.bf=0,  ch.bf=0
  (strb wzr [x.bb w.node uxtw])
  (strb wzr [x.bb w.lch uxtw])
  (cmn w.gbf 1)
  (b.ne lr_not_neg)
  (mov w.t 1)
  (strb w.t [x.bb w.node uxtw])
  (b lr_bf_done)
(: label lr_not_neg)
  (cmp w.gbf 1)
  (b.ne lr_bf_done)
  (mvn w.t wzr)
  (strb w.t [x.bb w.lch uxtw])
  (b lr_bf_done)
(: label lr_bf_done)
  (mov w.nsub w.lgc)
  (b fix_par)

(: label fix_par)
  ;; 新子树根挂到 grandparent
  (cbz w.ri new_root)
  (sub w.gpd w.ri 1)
  (ldr w.gp [x.path w.gpd uxtw 2])
  (ldrb w.gd [x.dir w.gpd uxtw])
  (cbnz w.gd fix_par_r)
  (str w.nsub [x.lb w.gp uxtw 2])
  (b rebal_done)
(: label fix_par_r)
  (str w.nsub [x.rb w.gp uxtw 2])
  (b rebal_done)

(: label new_root)
  (mov w.root w.nsub)
  (b rebal_done)

(: label rebal_next)
  (sub w.ri w.ri 1)
  (b rebal_loop)

(: label rebal_done)
  (mov w0 w.root)
  (add sp sp 256)
  (: load! all)
  (ret)

(: label new_tree)
  ;; 空树插入
  (mov w0 w.new)
  (add sp sp 256)
  (: load! all)
  (ret)

(: label alloc_fail)
  (mvn w0 wzr)
  (add sp sp 256)
  (: load! all)
  (ret)
(: end-function)

;; ============================================================
;; avl_delete_single: 单树迭代删除 + rebalance
;; ============================================================
;; x0 = pool ptr, w1 = root (-1 = empty), x2 = key
;; 返回: w0 = new root (-1 if tree becomes empty)
(: function avl_delete_single (export) (abi aapcs64))
(: save! all)
(: label entry)
  (mov x.pool x0)
  (mov w.root w1)
  (mov x.key x2)

  ;; 加载 base
  (ldr x.kb [x.pool 16])
  (ldr x.lb [x.pool 24])
  (ldr x.rb [x.pool 32])
  (ldr x.bb [x.pool 40])

  ;; 路径栈: path[48]*4=192, dir[48]*1=48, total=240→256
  (sub sp sp 256)
  (mov x.path sp)
  (add x.dir sp 192)

  ;; === Phase 1: 下降搜索 ===
  (mov w.cur w.root)
  (mov w.depth 0)
  (b d_descend)

(: label d_descend)
  (cmn w.cur 1)
  (b.eq d_not_found)

  ;; 保存 cur 到临时槽 (d_found 跨块时需要)
  (str w.cur [x.path 240])

  (ldr x.nk [x.kb w.cur uxtw 3])
  (cmp x.key x.nk)
  (b.eq d_found)
  (b.lt d_desc_left)

  ;; right: dir=1
  (str w.cur [x.path w.depth uxtw 2])
  (mov w.d 1)
  (strb w.d [x.dir w.depth uxtw])
  (ldr w.cur [x.rb w.cur uxtw 2])
  (add w.depth w.depth 1)
  (b d_descend)

(: label d_desc_left)
  (str w.cur [x.path w.depth uxtw 2])
  (strb wzr [x.dir w.depth uxtw])
  (ldr w.cur [x.lb w.cur uxtw 2])
  (add w.depth w.depth 1)
  (b d_descend)

(: label d_not_found)
  ;; Key 不存在, 返回 root 不变
  (mov w0 w.root)
  (add sp sp 256)
  (: load! all)
  (ret)

;; === Phase 2: 删除节点 ===
;; 使用 x.path+240 和 x.path+244 作为临时槽,
;; 避免跨块活跃分析 bug 导致变量丢失

(: label d_found)
  ;; 保存 cur 到临时槽
  (str w.cur [x.path 240])
  ;; 先检查左子
  (ldr w.lc [x.lb w.cur uxtw 2])
  (cmn w.lc 1)
  (b.ne d_has_left)
  ;; left==-1: child = right[cur] (可能也是 -1 → 叶节点)
  ;; 重新加载 cur (跨块 workaround)
  (ldr w.fc [x.path 240])
  (ldr w.child [x.rb w.fc uxtw 2])
  (mov w.del w.fc)
  (b d_unlink)

(: label d_has_left)
  ;; left != -1, 检查右子
  ;; 重新加载 cur
  (ldr w.fc [x.path 240])
  (ldr w.rc [x.rb w.fc uxtw 2])
  (cmn w.rc 1)
  (b.ne d_two_children)
  ;; right==-1, left != -1
  (ldr w.fc2 [x.path 240])
  (ldr w.child [x.lb w.fc2 uxtw 2])
  (mov w.del w.fc2)
  (b d_unlink)

(: label d_two_children)
  ;; cur 已在 x.path+240
  ;; 重新加载 cur
  (ldr w.fc [x.path 240])
  ;; path[depth] = cur, dir[depth] = 1 (向右)
  (str w.fc [x.path w.depth uxtw 2])
  (mov w.d 1)
  (strb w.d [x.dir w.depth uxtw])
  (add w.depth w.depth 1)
  ;; succ = right[cur]
  (ldr w.succ [x.rb w.fc uxtw 2])
  (b d_succ_loop)

(: label d_succ_loop)
  ;; 先保存 succ 到临时槽, 再加载左子
  (str w.succ [x.path 244])
  (ldr w.sl [x.lb w.succ uxtw 2])
  (cmn w.sl 1)
  (b.eq d_succ_found)
  ;; 左子存在, 记录 succ 到 path
  ;; 重新加载 succ (跨块 workaround)
  (ldr w.suc2 [x.path 244])
  (str w.suc2 [x.path w.depth uxtw 2])
  (strb wzr [x.dir w.depth uxtw])
  (add w.depth w.depth 1)
  (mov w.succ w.sl)
  (b d_succ_loop)

(: label d_succ_found)
  ;; 从临时槽重新加载 cur 和 succ
  (ldr w.origcur [x.path 240])
  (ldr w.fsucc [x.path 244])
  ;; 复制 key: keys[cur] = keys[succ]
  (ldr x.sk [x.kb w.fsucc uxtw 3])
  (str x.sk [x.kb w.origcur uxtw 3])
  ;; 实际删除 succ: child = right[succ]
  (ldr w.child [x.rb w.fsucc uxtw 2])
  (mov w.del w.fsucc)
  (b d_unlink)

;; === 断开 w.del, 用 w.child 替换 ===
(: label d_unlink)
  (cbz w.depth d_del_root)

  (sub w.pd w.depth 1)
  (ldr w.par [x.path w.pd uxtw 2])
  (ldrb w.d [x.dir w.pd uxtw])
  (cbnz w.d d_link_right)
  (str w.child [x.lb w.par uxtw 2])
  (b d_do_free)

(: label d_link_right)
  (str w.child [x.rb w.par uxtw 2])
  (b d_do_free)

(: label d_del_root)
  ;; 删的就是 root
  (mov w.root w.child)
  (b d_do_free)

(: label d_do_free)
  ;; 释放被删节点
  (mov x0 x.pool)
  (mov w1 w.del)
  (bl node_free)

  ;; 调用后重新加载 base (汇编器 workaround)
  (ldr x.kb2 [x.pool 16])
  (ldr x.lb2 [x.pool 24])
  (ldr x.rb2 [x.pool 32])
  (ldr x.bb2 [x.pool 40])

  ;; === Phase 3: Rebalance ===
  (sub w.ri w.depth 1)
  (b d_rebal_loop)

(: label d_rebal_loop)
  (tbnz w.ri 31 d_rebal_done)

  (ldr w.node [x.path w.ri uxtw 2])
  (ldrb w.d [x.dir w.ri uxtw])

  ;; bf 更新 (与 insert 相反)
  ;; 从左删 (dir=0) → bf += 1
  ;; 从右删 (dir=1) → bf -= 1
  (ldrsb w.bf [x.bb2 w.node uxtw])
  (cbnz w.d d_bf_sub)
  (add w.bf w.bf 1)
  (b d_bf_store)

(: label d_bf_sub)
  (sub w.bf w.bf 1)
  (b d_bf_store)

(: label d_bf_store)
  (strb w.bf [x.bb2 w.node uxtw])

  ;; bf==0: 高度降了, 继续回溯
  (cbz w.bf d_rebal_next)

  ;; |bf|==1: 高度没变, 停止
  (cmp w.bf 1)
  (b.eq d_rebal_done)
  (cmn w.bf 1)
  (b.eq d_rebal_done)

  ;; |bf|==2: 需要旋转
  (cmn w.bf 2)
  (b.eq d_rot_left_heavy)

  ;; bf==+2: 右重
  (b d_rot_right_heavy)

;; --- 右重 (bf==+2) ---
(: label d_rot_right_heavy)
  (ldr w.ch [x.rb2 w.node uxtw 2])
  (ldrsb w.cbf [x.bb2 w.ch uxtw])
  (tbnz w.cbf 31 d_rot_rl)

  ;; RR: 单左旋 (ch.bf >= 0)
  (ldr w.cl [x.lb2 w.ch uxtw 2])
  (str w.cl [x.rb2 w.node uxtw 2])
  (str w.node [x.lb2 w.ch uxtw 2])
  (mov w.nsub w.ch)

  ;; bf 更新取决于 ch.bf
  (cbz w.cbf d_rr_ch_zero)
  ;; ch.bf==+1: 两者归零, 高度降 → continue
  (strb wzr [x.bb2 w.node uxtw])
  (strb wzr [x.bb2 w.ch uxtw])
  (b d_fix_par_cont)

(: label d_rr_ch_zero)
  ;; ch.bf==0: node.bf=+1, ch.bf=-1, 高度不变 → break
  (mov w.t 1)
  (strb w.t [x.bb2 w.node uxtw])
  (mvn w.t wzr)
  (strb w.t [x.bb2 w.ch uxtw])
  (b d_fix_par_done)

(: label d_rot_rl)
  ;; RL: 双旋转
  ;; 重新加载避免跨块活跃分析 bug
  (ldr w.rch [x.rb2 w.node uxtw 2])
  (ldr w.rgc [x.lb2 w.rch uxtw 2])
  (ldrsb w.gbf [x.bb2 w.rgc uxtw])

  ;; 指针重排
  (ldr w.t [x.rb2 w.rgc uxtw 2])
  (str w.t [x.lb2 w.rch uxtw 2])
  (ldr w.t [x.lb2 w.rgc uxtw 2])
  (str w.t [x.rb2 w.node uxtw 2])
  (str w.rch [x.rb2 w.rgc uxtw 2])
  (str w.node [x.lb2 w.rgc uxtw 2])

  ;; bf 更新
  (strb wzr [x.bb2 w.rgc uxtw])
  (strb wzr [x.bb2 w.node uxtw])
  (strb wzr [x.bb2 w.rch uxtw])
  (cmp w.gbf 1)
  (b.ne d_rl_not_pos)
  (mvn w.t wzr)
  (strb w.t [x.bb2 w.node uxtw])
  (b d_rl_bf_done)
(: label d_rl_not_pos)
  (cmn w.gbf 1)
  (b.ne d_rl_bf_done)
  (mov w.t 1)
  (strb w.t [x.bb2 w.rch uxtw])
  (b d_rl_bf_done)
(: label d_rl_bf_done)
  (mov w.nsub w.rgc)
  ;; 双旋转: 高度降 → continue
  (b d_fix_par_cont)

;; --- 左重 (bf==-2) ---
(: label d_rot_left_heavy)
  (ldr w.ch [x.lb2 w.node uxtw 2])
  (ldrsb w.cbf [x.bb2 w.ch uxtw])
  (cmp w.cbf 0)
  (b.gt d_rot_lr)

  ;; LL: 单右旋 (ch.bf <= 0)
  (ldr w.cr [x.rb2 w.ch uxtw 2])
  (str w.cr [x.lb2 w.node uxtw 2])
  (str w.node [x.rb2 w.ch uxtw 2])
  (mov w.nsub w.ch)

  ;; bf 更新取决于 ch.bf
  (cbz w.cbf d_ll_ch_zero)
  ;; ch.bf==-1: 两者归零, 高度降 → continue
  (strb wzr [x.bb2 w.node uxtw])
  (strb wzr [x.bb2 w.ch uxtw])
  (b d_fix_par_cont)

(: label d_ll_ch_zero)
  ;; ch.bf==0: node.bf=-1, ch.bf=+1, 高度不变 → break
  (mvn w.t wzr)
  (strb w.t [x.bb2 w.node uxtw])
  (mov w.t 1)
  (strb w.t [x.bb2 w.ch uxtw])
  (b d_fix_par_done)

(: label d_rot_lr)
  ;; LR: 双旋转
  ;; 重新加载避免跨块活跃分析 bug
  (ldr w.lch [x.lb2 w.node uxtw 2])
  (ldr w.lgc [x.rb2 w.lch uxtw 2])
  (ldrsb w.gbf [x.bb2 w.lgc uxtw])

  ;; 指针重排
  (ldr w.t [x.lb2 w.lgc uxtw 2])
  (str w.t [x.rb2 w.lch uxtw 2])
  (ldr w.t [x.rb2 w.lgc uxtw 2])
  (str w.t [x.lb2 w.node uxtw 2])
  (str w.lch [x.lb2 w.lgc uxtw 2])
  (str w.node [x.rb2 w.lgc uxtw 2])

  ;; bf 更新
  (strb wzr [x.bb2 w.lgc uxtw])
  (strb wzr [x.bb2 w.node uxtw])
  (strb wzr [x.bb2 w.lch uxtw])
  (cmn w.gbf 1)
  (b.ne d_lr_not_neg)
  (mov w.t 1)
  (strb w.t [x.bb2 w.node uxtw])
  (b d_lr_bf_done)
(: label d_lr_not_neg)
  (cmp w.gbf 1)
  (b.ne d_lr_bf_done)
  (mvn w.t wzr)
  (strb w.t [x.bb2 w.lch uxtw])
  (b d_lr_bf_done)
(: label d_lr_bf_done)
  (mov w.nsub w.lgc)
  ;; 双旋转: 高度降 → continue
  (b d_fix_par_cont)

;; --- fix_par + continue ---
(: label d_fix_par_cont)
  (cbz w.ri d_new_root_cont)
  (sub w.gpd w.ri 1)
  (ldr w.gp [x.path w.gpd uxtw 2])
  (ldrb w.gd [x.dir w.gpd uxtw])
  (cbnz w.gd d_fpc_right)
  (str w.nsub [x.lb2 w.gp uxtw 2])
  (b d_rebal_next)
(: label d_fpc_right)
  (str w.nsub [x.rb2 w.gp uxtw 2])
  (b d_rebal_next)
(: label d_new_root_cont)
  (mov w.root w.nsub)
  (b d_rebal_next)

;; --- fix_par + done ---
(: label d_fix_par_done)
  (cbz w.ri d_new_root_done)
  (sub w.gpd w.ri 1)
  (ldr w.gp [x.path w.gpd uxtw 2])
  (ldrb w.gd [x.dir w.gpd uxtw])
  (cbnz w.gd d_fpd_right)
  (str w.nsub [x.lb2 w.gp uxtw 2])
  (b d_rebal_done)
(: label d_fpd_right)
  (str w.nsub [x.rb2 w.gp uxtw 2])
  (b d_rebal_done)
(: label d_new_root_done)
  (mov w.root w.nsub)
  (b d_rebal_done)

(: label d_rebal_next)
  (sub w.ri w.ri 1)
  (b d_rebal_loop)

(: label d_rebal_done)
  (mov w0 w.root)
  (add sp sp 256)
  (: load! all)
  (ret)
(: end-function)

;; SVE 并行操作函数在 avl-forest-sve.d 中
