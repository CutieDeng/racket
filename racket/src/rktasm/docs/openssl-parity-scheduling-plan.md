# 让 asmp 编排出与 OpenSSL point-op 同级的汇编：设计方案

## 目标问题

P-256 的 `ecp_nistz256_point_double`（OpenSSL 手排汇编）在 Apple M 核上 ≈165 cyc。
clang -O3 编译的等价 C 版 ≈207 cyc；asmp 托管汇编（寄存器传参 `jac_double_asm`）≈223 cyc。
问题：**给 asmp 加什么特性，能让它从"托管的高层源"自动编排出 ≈165 cyc 的代码，而不是靠人手写裸汇编？**

结论先行：**能，且缺的是两个通用编译优化——跨调用前向取数调度 + 只读输入重物化。**
二者都是标准优化（非 OpenSSL 专用 hack），满足"基于通用优化考量"的门槛。

---

## 一、OpenSSL 165 cyc 的三根支柱（来自实读其汇编源）

读 `ecp_nistz256-armv8.pl` 的 `ecp_nistz256_point_double` 与其子例程，165 cyc 来自三点，**没有一点是"更聪明的调度顺序"本身**：

### P1. 内部固定寄存器 ABI
所有域子例程（`__ecp_nistz256_mul_mont` / `_sqr_mont` / `_add` / `_sub_from` / `_sub_morf` / `_div_by_2`）共享一套**硬编码寄存器约定**：
- 入参 `a[0..3]` 恒在 `$a0-$a3`(x4-x7)，`b[0]` 在 `$bi`，或 `b` 指针在 `$bp`；
- 累加器 `$acc0-$acc5`，临时 `$t0-$t3`；
- **结果恒从 `$acc0-$acc3` 返回**。

调用方与被调方无需为传参做 spill/reload——寄存器里直接交接。

### P2. 显式 4 槽栈帧
`point_double` 开 `sub sp,sp,#32*4`，命名 4 个 256-bit 槽 `S,M,Zsqr,tmp0`。
工作集活在**栈帧**里，不是"活跃寄存器跨调用"。每个域运算：从帧槽 `ldp` 进 `$a0-$a3` → 算 → 结果 `stp` 回某个帧槽（或留在 `$acc` 里直接喂下一个）。

### P3. 前向取数（forward-loading）—— 真正的手工绝活
第 N+1 个运算的操作数 load，被写在第 N 个运算的 `bl` **之前**，且与第 N 个结果的搬运 `mov` **交错**：

```asm
    mov  $t0,$acc0
    mov  $t1,$acc1
    ldp  $a0,$a1,[sp,#$S]     // 为【下一个】sqr_mont 前向取数
    mov  $t2,$acc2
    mov  $t3,$acc3
    ldp  $a2,$a3,[sp,#$S+16]
    add  $rp,$rp_real,#64
    bl   __ecp_nistz256_add   // 当前这次调用
```

前向取数带来两重收益，**在乱序核上依然有效**：
1. load 延迟藏在当前 `add`/调用序幕之下，返回时数据已就绪；
2. **更关键——绕开访存定序停顿**：load 在程序序上排到被调方的 store 之前，硬件无需对 load 与后续 store 做别名消歧，不会被 store 队列卡住。这正是 OOO 核上"把 load 静态提前"仍有收益的原因（不是简单的填发射槽）。

---

## 二、asmp 现状对照

| 支柱 | asmp 现状 | 差距 |
|---|---|---|
| P1 固定寄存器 ABI | ✅ 已有：自定义 ABI（`wideargs`）+ 托管 `.call` 带寄存器绑定 | 无 |
| P2 命名栈帧槽 | ⚠️ 部分：有 spill 槽，但由分配器自行决定，未暴露"把这 4 个向量钉在帧里"的模型 | 需要"托管命名帧临时" |
| P3 前向取数 | ❌ 缺失：无调度器；分配器把 reload 放在**使用点前**（调用返回之后），延迟不藏、且撞被调方 store 定序 | 需要"跨调用前向取数调度" |

`jac_double_asm` 之所以 223 > clang 207：它试图把 X,Y,Z 全留寄存器跨调用（15 值 > 10 个 callee-saved）→ 被迫 spill（存+载），比 clang"从只读输入重读"更贵。**寄存器传参本身是错的方向**；正解是复现 OpenSSL 的"帧驻留 + 前向取数 + 从输入重物化"。

---

## 三、设计：两个新 asmp 特性

### 特性 1（核心）：跨调用前向取数调度 `cross-call load hoisting`

一个**分配后**的受限调度 pass，只做一件事：把 load 提前到前一个调用之前。

- 对每个 load L（无论是 spill reload 还是 `.call` 的实参 load），若它喂的值在一个中间隔着 `.call`/`bl` 的点被用，尝试把 L 提前到该调用之前，塞进前序指令的阴影里。
- **安全性靠访存效应分析**：L 读地址 (base,off)。把 L 提前越过 `.call C` 合法当且仅当 C 可证不写 [base,off]：
  - 托管 `.call` 到已知域运算：其写集 = 输出区 `[out_ptr, 32)`。asmp 已有实参绑定，`out_ptr` 已知。
  - 帧槽 (fp/sp+常量 off) 与被调方输出区（另一个帧槽或结果结构体）：**已知的不同偏移 ⇒ 可证不别名 ⇒ 提前合法**。
  - 保守回退：地址不可判 ⇒ 不提前。
- 这直接复现 P3，且可证安全。它**不是通用乱序调度器**（我已论证那对 OOO 无益），而是精准的"跨调用 load 提升 + 访存消歧"，收益来源明确。

### 特性 2：只读输入重物化 `rematerialization`

当一个 vreg 是"内存里某稳定地址已有的值的副本"（一个从不被覆写的函数入参、或帧临时），分配器不做 spill（存+载），而是标记它"可从 [ptr,off] 重物化"，在每个本要 reload 的使用点直接从**原地址** load——无 spill store、无帧槽。

- 对 point-double：X,Y,Z 来自 `[in_ptr]`，`in_ptr` 全程只读 ⇒ X,Y,Z 可重物化 ⇒ **零 spill store**；每次用时从 `[in_ptr,#off]` 重读。配合特性 1，这些重读又被前向取到调用之前。
- asmp 需要：给 vreg 标注重物化来源。两种口子——
  - 推断：vreg 仅由"对可证不变地址的一次 load"定义 ⇒ 自动可重物化；
  - 源标注：`x.X = remat [x.pp,#0]`。

### 特性 3（可选，锦上添花）：托管命名帧临时

暴露 `.frame S, M, Zsqr, tmp0`（各 32 字节），让高层源能像 OpenSSL 那样把工作集显式钉在帧里，运算读写帧槽。等价于"分配器把这几个向量强制驻留内存并给稳定地址"，使特性 1 的别名判定平凡成立。可用现有 spill-slot 机制加一层命名封装实现。

---

## 四、可行性判决

**能做到功能对等（≈0.9-0.97× OpenSSL）。** 一个用托管源写、调用共享域乘的 asmp point-double，配齐特性 1+2 后，会被编排成与 OpenSSL 同构的"帧驻留 + 前向取数"代码。

诚实的保留：达到**逐指令 165 cyc** 取决于 asmp 调度器是否做出与人手相同的前向取数选择；现实目标 ≈170-185 cyc（verify ≈0.85-0.95× OpenSSL）。完全 bit-for-bit 排布对等不保证，但 ~10% 内的功能对等可达。

## 五、工作量与风险

- 特性 1（调度 + 访存效应分析）：较大，~数日，**正确性关键**（改分配后指令序，撞碼即错）。
- 特性 2（重物化）：中等，触及分配器/rewriter。
- 特性 3：小，封装 spill-slot。
- 三者都是高爆炸半径改动，必须开关门控 + 回归：asmp 自带测试 + P-256 差分 KAT（对 OpenSSL + 参考 C 逐位一致）兜底。

## 六、实施顺序

1. 特性 3（命名帧）——最小、解锁清晰源模型。
2. 特性 2（重物化）——先削掉 spill store，把 223 拉向 clang 的 207 以下。
3. 特性 1（前向取数）——藏 load 延迟、绕 store 定序，把 207 推向 ~175。
4. 每步用 `jac_double_asm` 重测 cyc，用差分 KAT 验正确性；达标后集成 point_add，闭合 verify 缺口。

## 七、实测修正（2026-07 实现后回填）

已实现两个通用寄存器分配特性并用 P-256 差分 KAT (对 C 参考逐位一致,
0/200000 fails) 验证：

- **立即数重物化**（`rewriter.rkt` 的 `analyze-remat`）：把被溢出、且由无
  寄存器输入的 `movz/movn/movk` 链定义的值改为使用点重建。正确、通用、零回归。
  但对 `jac_double_asm` **不触发**——常量 (pf0/pf1/pf3) 寄存器压力下仍拿到了
  寄存器 (分配器正确行为)，未被溢出。
- **重载拆分重物化**（`remat-split.rkt`,预分配 pass）：把"跨调用存活的不变
  装载" (X,Y,Z 来自 `[in_ptr]`) 拆成使用点重载,基址指针自然驻留 callee-saved。
  命中 12 个候选,`jac_double_asm` 指令 450→419、spill-reload 84→62。
  同址 A/B 实测 **~2.4% (noremat 368 → remat 359 cyc)**,逐位一致。

**关键修正**：`jac_double_asm` 跨调用溢出的主体不是 X,Y,Z 装载,而是**中间域
运算结果** (M,S,prod,Y4,T——由域乘/域加算出,def-count 2-3)。这些**无法重物化**
(不是从不变地址装载,而是昂贵算出),且数量超过寄存器容量,溢出不可避免。

因此**重物化 (特性 2) 对 point-double 的收益有限 (~2.4%)**。OpenSSL 同样把这些
中间量溢出到其命名帧槽 (S,M,Zsqr,tmp0),差距**纯粹来自前向取数调度 (特性 1)**——
且其前向取数值活在"被中间被调方保留"的寄存器里 (手工协调的调用约定)。

**结论修订**：point-double 追平 OpenSSL 的唯一杠杆是**特性 1 (前向取数调度)**,
而且它需要**跨过程寄存器协调**——调用方与所有域子例程约定哪些寄存器承载跨调用的
前向取数据并保证不被 clobber。这不是事后 pass,而是接近"每调用点定制调用约定 +
保留寄存器保证 + 调度"的整体寄存器分配。工作量大、风险高;是 asmp 追平 OpenSSL
point-op 的真正门槛。

## 八、Clobber-aware 跨调用分配 (已实现，2026-07-17)

"跨过程寄存器协调"的核心已落地——**clobber-aware 跨调用分配**
(`allocator.rkt` + `interference.rkt` `compute-clobber-union-map`)：

- 旧行为：任何跨调用存活的值一律只能进 callee-saved 或溢出 (保守假设调用
  clobber 全部 caller-saved)。
- 新行为：对每个跨调用值，计算它跨越的各调用的**实际 clobber 集并集**
  = 被调方声明 ABI 的 caller-saved (allocatable−preserved) **∪ lr(x30)**
  (bl 必写 lr)。合法颜色 = allocatable − 该并集。于是跨越**轻量被调方**
  (声明 ABI 保留大部分寄存器) 的值可留在被保留的 caller-saved 里，不必进
  callee-saved 或溢出。
- **sound 依据**：ABI 契约——被调方只 clobber 自身 caller-saved，preserved
  的会存/恢复 (已实测：tinyclob 被调方在压力下用 x4-x7 会自动 stp/ldp)；
  被调方 banned 的 (x16/x17 spill 临时) 在调用方也 banned，遗漏无害。lr 单独
  强制加入 (bl 写返回地址)——**这是关键坑：漏掉 lr 会把数据分配到 x30 被 bl
  破坏**。fp 未被 clobber 但作为帧基址全程存活，由干涉图自然排除。
- 验证：P-256 差分 KAT 0/200000；tinyclob 样例中跨调用值落 x4/x5 (被调方保留
  的 caller-saved)、零 callee-saved 保存；asmp 非 native 测试全绿零回归。
- 开关 `ASMP_NO_CLOB`。新增测试 ABI `tinyclob` (config/abi.rktd, 只 clobber
  x0-x3) 用于验证机制。

**对 P-256 的适用**：clobber-aware 帮到"只跨越轻量调用"的值。point-double 里
中间量 (M,S,Y4…) 仍跨越**重量级域乘** (clobber 全部)，故仍溢出到帧——OpenSSL
亦如此。要把 point-double 推到 OpenSSL，还需：把域 add/sub 写成**保留型轻量
.function**，把 point-double 写成 **OpenSSL 帧驻留布局 + 源码级前向取数**
(域乘输入在前一个轻量调用之前载入被保留的 caller-saved)，clobber-aware 使这些
前向载入值自动跨轻量调用存活。此即特性 1 的"人写调度 + asmp 协调分配"实现路径,
无需独立调度器。剩余工作 = 协调 ABI 的域子例程 + OpenSSL 布局 point-double 转写。

## 九、全链路实测：前向取数在乱序核上无效 (2026-07-17，决定性)

把上述全部实现并实测，得到**推翻本文核心假设**的结论：

**已建**：`fieldadd` ABI (保留 x4-x7)；`fadd_p256`/`fsub_p256`/`fdiv2_p256`
轻量域子例程 (紧凑 in-place，12 寄存器、零溢出、不碰 x4-x7)；`jac_double_ossl`
—— 完整 OpenSSL 帧驻留布局 point-double (18 域运算、frame slot 驻留、源码级前向
取数：每个域乘的 b 操作数在前一个轻量调用前载入 x4-x7)。

**验证**：clobber-aware 确实把前向载入的域乘 b 操作数放进 **x4-x7** 并跨轻量
add/sub/div2 调用存活 (机制完全按 OpenSSL 寄存器纪律工作)；P-256 差分 KAT
**0/200000** 逐位一致。

**实测 cyc (同址 A/B)**：
| | cyc |
|---|---|
| C jac_double (clang) | 219 |
| asm 内联寄存器传参 (旧 jac_double_asm) | 223 |
| **asm jac_double_ossl (帧驻留+前向取数)** | **229** |
| OpenSSL point_double | 174 |

**关键发现**：
1. **前向取数在这颗大窗口乱序 Apple 核上 cyc 收益 = 0** (jd_ossl 开/关前向取数都
   是 229)。硬件已把 L1 帧载入延迟隐藏，静态把 load 提前无效。**这推翻了本文
   第七节"前向取数是唯一杠杆"的判断**——前向取数是 OpenSSL 手写的技法，但在乱序
   核上它不是 174 的来源。
2. OpenSSL 帧驻留布局在 asmp 里反而**更慢** (229 > 内联 223 > clang 219)：19 个
   .call 的实参 marshalling (每个域运算 8 ldr + 4 str 走 frame) 的开销超过它省下的
   溢出。asmp 托管 .call 无法达到 OpenSSL 手工"结果留寄存器喂下一步"的协调。
3. **asmp (clobber-aware + remat + 全部特性) 在 P-256 point-double 上触顶 ≈clang
   (219-229cyc)，到不了 OpenSSL 的 174**。174 的来源不是前向取数，而是 OpenSSL
   逐指令手调的指令选择 + 寄存器复用 (结果在寄存器间流动、极少 frame 往返)，这是
   asmp 托管分配模型 (无论帧驻留还是寄存器传参) 都达不到的手工协调层。

**最终结论**：clobber-aware 是正确且通用的 asmp 特性 (跨轻量调用的值免溢出，已
验证)，但 **P-256 point-double 追平 OpenSSL 无法通过 asmp 托管路径达成**——真正
差距在手工逐指令协调，非任何可自动化的通用特性。生产 point-op 继续用 clang C
(与 asmp 托管方案同档 ~220cyc)。三个 asmp 寄存器分配特性 (立即数重物化、
reload-split、clobber-aware) 作为通用改进保留，均 0/200000 KAT + 零回归。
