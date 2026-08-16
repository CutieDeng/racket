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
