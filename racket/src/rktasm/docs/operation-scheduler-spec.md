# asmp 操作级列表调度器 — 特性规格 / 验收规范 / 测试要求

状态：设计已定，待实现。
关联：`docs/openssl-parity-scheduling-plan.md` 第九节（实测背景），本文是其"操作级
mul 重叠调度"结论的落地规格。

---

## 1. 动机与背景

P-256 `point_double` 是一张**域运算 DAG**。域乘延迟 ~37cyc 但吞吐 ~17cyc（乱序核
可同时在飞 2-3 个）。DAG = 4 个域乘的关键链 `ZZ→M→X3→T`（≈148cyc，≈OpenSSL 下限）
+ 4 个**独立**域乘（YY,S,Y4,Z3）。最优时间 = 关键链，**当且仅当独立域乘落在关键链
的阴影里并发执行**——这要求它们在乱序窗口内共存，且**受寄存器压力约束**（~2 个在飞；
3 个全铺开会溢出 114 次→246cyc）。即：**受压力约束的 DAG 拓扑排序**。

**关键：为什么 clang 做不到而 asmp 能。** `mont_mul` 是 extern 符号，clang 必须把每个
调用当作不透明的内存屏障，**不能跨调用重排**，故按源序发射域乘（延迟约束，206-218cyc）。
asmp 的托管 `.call` 携带**声明的纯 in/out**，asmp 因此**知道两个域乘数据无关、可合法
重排**。这是 asmp 独有、clang 结构性缺失的自由度。

**实测验证（已完成）**：手工调度的 `jac_double`（~2 在飞、88 溢出）= **216cyc，低于
clang 218**，P-256 差分 KAT 0/200000。证明 asmp 能超越 clang。本特性把这一手工结果
**自动化**。

---

## 2. 特性范围

实现一个**操作级、压力感知的列表调度器**，作为 asmp 流水线的一个 pass，对每个基本块
内的指令/`.call` 重新排序，在保持语义的前提下最大化指令级并行（尤其是长延迟域乘的重叠），
同时把寄存器压力控制在不引发过量溢出的范围。

**非目标**：
- 不做跨基本块（全局）调度（首版限基本块内）。
- 不做软件流水（循环展开/模调度）。
- 不追求单独达到 OpenSSL 173cyc（那还需配套的溢出削减，见 §7 后续）；本特性目标是
  **自动复现并稳定超越 clang**，为后续溢出削减打底。

---

## 3. 设计

### 3.1 挂载点

**在 inline 展开（`.call` 降级为 bl+moves）之前**，对每个函数的每个基本块调度。此时
`.call` 仍是单个 directive，可作为**一个高延迟 DAG 节点**，in/out 干净。调度器需要一张
`callee-name → (in-params, out-params)` 映射（由已解析的各 `.function` 签名构建）以把
`.call` 的绑定 `formal=actual` 分类为 use（formal∈in）或 def（formal∈out）。

开关：全局参数 `*enable-scheduler*`（默认开）；环境变量 `ASMP_NO_SCHED` 关闭（用于
A/B 与回归对照）。

### 3.2 依赖 DAG

节点 = 基本块内的每条指令 / 每个 `.call`。边（i 在 j 之前，i→j）当且仅当以下之一：

- **RAW**：j 读 i 写的寄存器（含 `.call` 绑定的 in/out、NZCV）。
- **WAR**：j 写 i 读的寄存器。
- **WAW**：j 写 i 写的寄存器。
- **NZCV 伪寄存器**：把条件标志建模为一个隐式寄存器。置标志指令（adds/adcs/subs/sbcs/
  ands/cmp/cmn/tst/…）def NZCV；读标志指令（adc/sbc/adcs/sbcs/csel/cset/ccmp/b.cond/…）
  use NZCV。据此 RAW/WAR/WAW 自动**保持进位链 `adcs…adcs` 连续且有序**。
- **内存别名**：两条访存至少一个是 store 且可能别名 → 定序。别名判定：同基址+同常量偏移
  或无法证明不相交 → 保守别名；`[fp/sp,#imm]` 不同偏移 → 不别名。
- **调用副作用**：`.call` 保守地对内存"可能读写"，与其前后的访存定序（除非能证明
  `.call` 只写其 out 指向的内存——首版保守：`.call` 与所有 store 定序）。

**硬屏障**（其两侧指令一律不跨越重排）：标签、分支（b/b./cbz/cbnz/tbz/ret/br）、
写 sp/fp/lr 的指令、`.save`/`.restore`/其它 directive（`.call` 除外）。屏障把基本块
切成若干**可调度区段**，仅区段内重排。

### 3.3 延迟模型（cyc，用于关键路径优先级）

| 指令 | 延迟 |
|---|---|
| `.call` 域乘/域运算 | 12（模 ~37cyc / 3-wide 发射） |
| `mul` / `umulh` / `madd` | 3 |
| `ldr` / `ldp` | 4 |
| `str` / `stp` | 1 |
| 其它 ALU（add/sub/adc/csel/mov/and/orr/movz/movk/extr…） | 1 |

模型已外置为数据文件 `data/latency.rktd`（`pipeline/sched-model.rkt` 加载；`--sched-model <名字或路径>` / `ASMP_SCHED_MODEL` 选择，默认 apple-m 与内置表逐值一致），默认值须使域乘节点在关键路径计算中占主导。

### 3.4 列表调度算法（压力感知）

标准前向列表调度 + Goodman-Hsu 压力控制：

```
region = 屏障切分出的可调度指令序列
DAG = build-dag(region)
compute critical-path height cp[n] = latency[n] + max(cp[succ])   # 反拓扑
ready = { 无前驱的节点 }
live = 区段入口活跃 vreg 集合（用于压力估计）
scheduled = []
while ready 非空:
    # 压力感知选择
    if 估计 live 数 > 压力阈值 T:
        pick = ready 中 "净释放寄存器最多"（defs 被后续消费、且 uses 使某些 vreg 死亡）
    else:
        pick = ready 中 cp 最大者（暴露 ILP）；平手取原始序最靠前（稳定）
    scheduled.append(pick)
    更新 live（pick 的 uses 使无后续用途者死亡；defs 加入）
    把新就绪的后继加入 ready
emit scheduled
```

- **压力阈值 T**：默认 = 该类可分配寄存器数的一个安全比例（GPR 首版取 24）。可调。
- **稳定性**：平手一律取原始程序序最靠前者，保证确定性输出（同输入同输出，便于测试）。
- **列表调度是保序安全的**：只在 DAG 允许的拓扑序内重排，绝不违反任何依赖边。

### 3.5 正确性不变式（实现必须满足，测试必须覆盖）

1. **依赖保持**：输出是 DAG 的一个合法拓扑序 → 所有 RAW/WAR/WAW/NZCV/内存/屏障依赖
   在输出中的相对顺序与依赖方向一致。
2. **进位链完整**：任何 `adcs…adcs…adc` / `sbcs…` 链在输出中保持连续且原序（NZCV 依赖
   的直接推论）。
3. **屏障不跨越**：屏障两侧的指令集合在输出中不交叉。
4. **无新增/丢失指令**：输出是输入的一个排列（多重集相等）。
5. **语义等价**：对任意输入，调度前后函数计算结果逐位相同（由差分 KAT 保证）。

---

## 4. 验收规范

### 4.1 功能验收（正确性，硬性，全部必须通过）

- **F1 排列不变**：对每个被调度的基本块，输出指令多重集 == 输入多重集。
- **F2 拓扑合法**：输出顺序不违反 §3.2 构建的任一依赖边（单元测试用小样例断言）。
- **F3 P-256 差分 KAT**：`jac_double`（经调度器）对 C 参考 `jac_double` **0/200000**
  逐位一致（affine 比较）。这是硬门槛。
- **F4 asmp 回归**：`test/*.rkt`（非 native）全绿，**零回归**。已知 native deflate
  测试环境性失败不计。
- **F5 端到端 KAT**：接入生产 P-256 后，`rktcrypto` selftest / OpenSSL 差分互操作全过
  （若集成到生产路径）。

### 4.2 性能验收

- **P1（主目标，硬性）**：调度器**自动**产出的 `jac_double`（寄存器传参、`.call` 域乘）
  在同址 A/B 中 **≤ clang C 的 cyc**（即自动复现手工 jdbal 的"低于 clang"结果，
  216 vs 218 量级）。允许 ±3cyc 热噪声裕度，但须在多轮交错测量中**稳定不劣于 clang**。
- **P2（对照，非硬性）**：`ASMP_NO_SCHED=1`（关调度）的同一源应回到 ~223cyc（未调度基线），
  证明增益来自调度器本身。
- **P3（方向性，非硬性）**：报告到 OpenSSL 173 的剩余差距，并明确其归因（溢出，见 §7）。

### 4.3 稳健性

- **R1 确定性**：同输入 → 同输出（平手取原序）。
- **R2 无候选即恒等**：不含可重排机会的基本块（纯直线依赖链）输出 == 输入。
- **R3 保守回退**：任何无法分析的构造（未知 `.call` 目标、复杂内存、含屏障）→ 保守定序，
  绝不产生错误重排。

---

## 5. 测试要求

### 5.1 单元测试（`test/schedule-test.rkt`，新增）

- **U1 DAG 依赖**：构造含 RAW/WAR/WAW 的小基本块，断言 DAG 边集正确。
- **U2 NZCV 链**：`adds/adcs/adcs/adc` + 中间无关指令，断言链保持连续有序。
- **U3 屏障**：含 `bl`/分支/sp 写的块，断言屏障两侧不交叉。
- **U4 排列不变**：随机小块，断言输出多重集 == 输入。
- **U5 压力控制**：高压力块，断言 live 峰值不超阈值太多（或至少不比未调度更差）。
- **U6 确定性**：同输入调两次，输出相同。
- **U7 恒等**：纯依赖链输入，输出 == 输入。

### 5.2 差分 KAT（复用 scratchpad 既有 harness）

- **K1** `jac_double` 经调度器 vs C `jac_double`：**0/200000**。
- **K2** 域乘 `mont_mul_p256_rr` 经调度器 vs oracle：**0/1000000**（若域乘也过调度器）。

### 5.3 回归

- **G1** `raco test test/*.rkt`（非 native）零失败。
- **G2** A/B：`ASMP_NO_SCHED=1` vs 默认，对既有 asmp 内核（含 mont_mul、deflate 样例）
  输出正确性一致（性能可不同）。

### 5.4 性能测量

- **M1** 同址交错 A/B（4 轮）：`jac_double`(调度) / `jac_double`(不调度) / clang C /
  OpenSSL，报告 cyc，验证 P1。
- **M2** 端到端 ECDSA verify ops/s（若集成生产），报告对 OpenSSL 比值变化。

---

## 6. 风险与缓解

| 风险 | 缓解 |
|---|---|
| 进位链被错误拆散 → 静默算错 | NZCV 伪寄存器依赖 + U2 单测 + K1 差分 KAT（0/200000 硬门槛）|
| 内存重排违反别名 | 保守别名（不能证明不相交即定序）+ `.call` 与 store 全定序 |
| 压力增大导致溢出反变慢 | 压力感知选择 + P2 对照 + 阈值可调；若某块调度后更慢，回退该块原序 |
| 破坏既有内核 | G1 回归 + 开关 `ASMP_NO_SCHED` 兜底 |
| `.call` in/out 分类错误 | 从 callee 签名精确分类；未知目标保守（全 def+use） |

---

## 7. 实施阶段（增量，每阶段 KAT 门控）

1. **阶段 A**：DAG 构建（数据依赖 + NZCV + 内存 + 屏障）+ 排列不变的恒等调度（先不重排，
   验证 F1/F2/U1-U4/U7）。
2. **阶段 B**：加关键路径优先列表调度（无压力控制），过 K1 差分 KAT。测 cyc（可能因压力
   变差——预期，进阶段 C）。
3. **阶段 C**：加压力感知选择，调阈值 T，达 P1（≤clang）。过 F3/F4/P1/P2。
4. **阶段 D**：接入生产 P-256（若 P1 达成），过 F5/M2。
5. **后续（本特性之外）**：溢出削减——保留更多寄存器的域乘 ABI / 活跃区间拆分 / 重物化，
   配合调度器逼近 OpenSSL 173。

---

## 8. 交付物

- `pipeline/schedule.rkt`（调度器实现）。
- `test/schedule-test.rkt`（单元测试 U1-U7）。
- 流水线挂载 + `*enable-scheduler*` / `ASMP_NO_SCHED` 开关 + `ASMP_SCHED_PLIMIT`。
- 本文档更新"实测结果"节（阶段 C 后回填 cyc 与验收结论）。

## 9. 实测结果（2026-07-17，阶段 C 达成）

**核心实现要点（踩坑）**：
1. **周期感知**是关键。首版把后继在前驱"已调度"时即置就绪 → 域乘发射后立刻排
   其依赖后继，不填延迟阴影 → 无重叠增益（245→234，几乎无效）。改为**周期基**
   列表调度（节点仅当前驱延迟已流逝 finish≤cycle 才 data-ready，发射域乘后其后继
   等 latency 周期，期间发射独立域乘填满阴影）后，独立域乘在输出中相邻 → 乱序核
   重叠 → 见效。
2. **`.call` 不能建模 NZCV-def**。若把域乘 `.call` 也算 clobber 标志，会把所有域乘
   串进进位链的 NZCV 总序 → 完全无法重排。域乘是纯函数、调用方不跨调用依赖标志
   （ABI 标准），故 `.call` 不上 NZCV 链。移除后域乘方可自由重排。
3. **inline add/sub 须用唯一临时**。共享 `x.s0`/`x.u0` 等临时会在所有 add/sub 间
   造 WAW/WAR 假依赖，串死调度。全 `.call`（临时藏于 callee）或 SSA 唯一临时才有
   调度自由度。

**实测（同址 4 轮交错 A/B，`jac_double_rr2` 全 `.call` 寄存器传参点倍加）**：

| | cyc |
|---|---|
| clang C | 219-220 |
| **调度 OFF**（`ASMP_NO_SCHED=1`） | **244-245** |
| **调度 ON**（自动） | **215（稳定）** |
| OpenSSL | 175-176 |

**验收**：
- **F3 差分 KAT**：`jac_double_rr2`（经调度器，含被调度的 `mont_mul_p256_rr`）
  vs C 参考 **0/200000** 逐位一致。✅
- **P1（主目标）**：调度 ON **215 < clang 219-220，稳定不劣于 clang**。✅
  且相对未调度基线 **245→215（−30cyc / −12%）**。
- **P2**：`ASMP_NO_SCHED=1` 回到 245，证明增益来自调度器。✅
- **U1-U7 单测**全过（`test/schedule-test.rkt` 8/8）。✅

**结论**：**推翻"clang 是自动编译上限"的判断**——asmp 操作级调度器自动产出
**低于 clang** 的 P-256 点倍加（215 vs 220），因为它能重排 clang 不能重排的 extern
域乘 `.call`。到 OpenSSL 175 的剩余 ~40cyc 是溢出（63 次）——后续溢出削减方向
（§7 阶段 5）。

**已知局限**：压力启发式对 inline-SSA 变体会过度聚簇（峰值活跃 18 > 阈值，
仍产 125 溢出反而更慢）；全 `.call` 结构（临时藏 callee、数据流干净）是当前
最佳适用形态。压力模型的进一步标定留作后续。

## 10. 已知正确性问题与 opt-in 安全门（重要）

**默认关闭。** 调度器在含复杂控制流/循环/内联的代码（deflate 示例）上存在
**未根除的依赖建模盲点**：全非-native 回归中 `dynamic-huffman-reference-test`
的 5/31 用例功能失配（compressed got≠expected）。已补内存定序边（store 依赖
此前全部内存 op、load 依赖最近 store、纯 `.call` 免内存边）后由 8 降到 5，但
仍有残余——观测到的重排看似都作用于独立寄存器，根因待查（疑似某指令
`extract-use-def` 不完整、或某跨区隐式依赖）。

**因此调度器默认关闭**，仅对**逐一经差分 KAT 验证**的内核 opt-in 开启：
- `ASMP_SCHED_ONLY=fn1,fn2`（推荐）：只调度指定函数。
- `ASMP_SCHED=1`：调度全部（仅在确信安全时）。

**验收状态**：
- F1/F2/U1-U7 单测、F3 KAT(0/200000)、P1(≤clang)、P2 —— 在**开启的 crypto
  内核**（`jac_double_rr2` + `mont_mul_p256_rr`）上**全部通过**（216 vs clang
  219，KAT 0/200000）。
- F4 零回归 —— **默认关闭时全绿**；调度器全局开启（`ASMP_SCHED=1`）时
  deflate 用例失配（见上）。
- 故本特性以 **opt-in 形态交付**：核心算法（周期感知列表调度 + 压力控制 +
  纯 `.call` 重排）已验证有效且在 crypto 内核上正确；通用正确性（复杂控制流的
  完整依赖建模）为后续工作，完成前不默认开启。

### §10.1 已修的内联正确性 bug + 仍开放项 (2026-07-17)

**已修 (正确性改进，crypto KAT 仍 0/200000)**：
1. **域乘 .call 会物理 clobber NZCV**（其内部 adcs），但为让域乘重叠曾把 NZCV 完全
   从 .call 移除 → 调度器把域乘塞进进位链的 setter 与 csel 之间 → csel 读到错误标志。
   **修**：把 .call 建模为 NZCV **clobber**（dead write）：加 WAR 边（不能进位链内插）
   但不参与 WAW（两域乘无 WAW → 仍可重叠）。NZCV 从一般寄存器环拆出单独处理
   （RAW/WAR + clobber 语义）。jdssa 调度 KAT 174767→112337（改善）。
2. **NZCV 活跃出口**：区段后随条件分支 (b.<cond>) 时 NZCV 活跃，原序最后一个 NZCV
   写者须保持最后（否则分支读错标志）。`build-region-dag #:nzcv-live-out?` 处理。

**仍开放 (先于本轮 NZCV 工作就存在的调度器 bug)**：deflate 部分示例
(dynamic-huffman-reference-test 5/31) 功能失配。诊断：identity（不重排，过完整调度
管线）正确；任意 DAG-合法重排失配；可见重排在 vreg 层看似都作用于独立寄存器
(如 `sub w.bit_count` 上移、常量 mov 重排)，use-def fallback 对 cmp/mov 亦正确。
疑似复杂内联代码某隐式依赖或与下游分配的交互未建模，根因待查。**因此调度器保持
opt-in，仅对 KAT 验证内核开启**；此开放项不影响已交付的 crypto 用例。
开关：`ASMP_SCHED_IDENTITY`/`ASMP_SCHED_MAXDIST`/`ASMP_SCHED_NOMEMDIS` 为调试用。

**新增更清晰的可复现反例 (2026-07-27, rktcrypto 实测)**：`--sched-only md5_blocks_asm`
使 MD5 压缩内核功能全错（差分 200000/200000 失配、MD5("abc") 错），而 identity 正确。
md5 是**单基本块循环体**，状态字 a/b/c/d 在 `b.ne loop` back-edge 上循环携带（入口
load 命名、块末回写同名）——调度器重排跨越了这条循环携带链，比 deflate 例更小更易
定位。同批实测：直线型内核 (bn_mul_mont_op16 / mul_plain6/9 / keccak_f2_asm) 调度后
差分 0/200000 **正确但无性能增益**（宽 OoO M 核硬件已乱序，静态调度差异全在噪声内）。
结论强化：调度器对宽 OoO 目标既无收益又不安全于循环携带态；根因建议从"区段调度未
建模循环携带 (loop-carried across back-edge) 依赖"入手（md5 是最小复现）。
