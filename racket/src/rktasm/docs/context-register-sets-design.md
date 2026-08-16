# 设计文档：asmp 上下文变量 / 上下文寄存器集

状态：草案（planning）
动机来源：rktcrypto 手写 P-256 点内核的寄存器 ABI 硬编码（`_p256_*` 契约）
关联：`config/abi.rktd`（omul/osqr 雏形）、`docs/openssl-parity-scheduling-plan.md`（第九节实测）

---

## 0. 一句话结论

asmp 已有的三件套（自定义 ABI + `.function` 签名 + 托管 `.call`）已经拼出了"值驻寄存器
跨 `bl` 传递"的**数据面**（clobber-aware 存活 + 偏置合并消 mov + reg-interfere 防 swap，
已 0/200000 KAT 验证）。缺的是**"上下文"这层抽象**——一个**命名、跨函数引用、一次声明、
asmp 一致分配并在汇编期校验**的共享寄存器集。本文提议把它做成一等公民 `.context`，从而
**消灭 `_p256_*` 那种"操作数固定 x4-x7、结果固定 x14-x17"的手写硬编码约定**，在**不改
指令调度**（故性能不变，见 §6）的前提下恢复虚拟寄存器的可维护性与编译期一致性检查。

## 1. 背景：现状与痛点

### 1.1 rktcrypto 的硬编码痛点（本特性的直接动机）

`rktcrypto_p256_hand.S` 的手工调度点内核 `jac_double_hw` / `mixed_add_hw` / `mont_sqrn_p256`
通过 `bl` 调用字段 helper（`_p256_mul` / `_p256_sqr` / `_p256_add` / `_p256_sub_from` …）。
为让值驻寄存器跨调用不 store/reload（这是它们追平并局部反超 OpenSSL ecp_nistz256 的关键），
这些 helper 用**固定物理寄存器的隐式 ABI**：操作数 x4-x7 / x8-x11、结果恒在 x14-x17、
结果指针 x0、src2 指针 x2。

这是**硬编码的跨函数约定**：调用方与被调方必须对"哪个寄存器持什么"逐字节达成一致，
一处改动（如 `_p256_mul` 换个结果寄存器）会让三个点内核**静默失效**——只有运行期差分
（`test_p256_extra.c` / `test_mixed_add.c` / `test_mont_sqrn.c`，各 0/200000）能抓到，
汇编期无任何检查。这是 rktcrypto 硬编码审查中评定的**最高结构性风险**。

### 1.2 asmp 现有机制已拼出"数据面"（但缺抽象）

调研（见 config/abi.rktd、semantic/inline.rkt、pipeline/regalloc/）确认现成能力：

- **自定义 ABI**（`abi.rktd`）：`(args …) (return …) (banned …) (preserved …)`，clobber = 派生
  的 caller-saved。
- **`.function (abi X)` + `in:/out:/inout:` 签名**：形参是**虚拟寄存器**，经**合成入口 move +
  livein 干涉约束 + 偏置着色合并** "粘"到 ABI 槽物理寄存器（`inline.rkt:284-535`,
  `allocator.rkt:667-686`）；`inout` 令输入槽==输出槽实现就地运算。
- **托管 `.call`**：parallel-copy 入/出参 move，`same-reg-location?` 直传免 mov
  （`inline.rkt:432-467`），register-residency 靠**偏置合并事后消除 `mov xN,xN`**。
- **clobber-aware 分配**：跨调用存活值据被调 ABI 的 clobber 并集放宽合法颜色，可留在
  被保留的 caller-saved 里免溢出（`interference.rkt:624-697`，实测跨调用值骑 x4/x5 零
  callee-saved）。
- **reg-interfere 合成 directive**：`.call` lowering 插入、只喂 regalloc 不输出汇编，
  防分配后重新形成隐藏 swap（`inline.rkt:469` → `interference.rkt:556-600`）。

### 1.3 omul/osqr：用错工具搭出的雏形

`abi.rktd:124-163` 的 `omul/omul2/osqr/oadd/osubp/oun`（+前身 `wideargs/fieldadd`）**正是
本特性的雏形**——它们把 OpenSSL ecp_nistz256 的 `$a0-$a3`(x4-x7)/`$acc0-$acc3`(x14-x17)
约定，编码进**每函数 ABI 的 args/return + 手调 banned/preserved 掩码**。但这是**借"逐函数
调用约定"机制来近似"跨函数共享上下文"**：共享性藏在位置化 args/return 与手工掩码里，
每个函数各自 re-declare，每个 callsite 重述 `formal=actual`，没有一等的命名上下文。

`openssl-parity-scheduling-plan.md` 第九节实测把这批 ABI 判为"废弃"：**前向取数在乱序
Apple 核 cyc 收益=0，帧驻留 marshalling 开销反超（229 开/关 > 内联 223 > clang 219），
asmp 托管路径达不到 OpenSSL 手工 174**，故生产 point-op 回退 clang C。

**关键再评估（2026-07 后续）**：那次失败的根因是 asmp **托管 `.call` 仍生成 marshalling
move（best-effort 消除）+ 帧驻留布局**带来的开销，而非"共享寄存器上下文"这个想法本身。
证据：本仓 rktcrypto 后来用**纯手写物理寄存器**的 register-ABI 内核（`mixed_add_hw` /
`mont_sqrn_p256`）在逐内核头对头中**达到并局部反超 OpenSSL ecp_nistz256**（field mul
1.01x、sqr 0.98x、point double 1.02x、mixed add 0.98x）。差别在：手写内核**零 marshalling、
指令调度全手工**。所以正确的特性设计应当**保留手工指令调度、只虚拟化寄存器名并保证
move-free**——恰好避开当年 omul/osqr 失败的那层开销（见 §5）。

## 2. 问题陈述：四点缺口

现有机制离"上下文变量/上下文寄存器集"缺的正交原语：

1. **抽象缺失**：无"共享寄存器集"的**命名、跨函数引用、一次声明**对象。omul/oadd 是把
   同一约定复制进每个 ABI，正是要消灭的重复与硬编码。
2. **一致分配缺失**：需要**跨函数族的联合分配**（上下文变量在整族绑同一批物理寄存器），
   而非"逐调用 sound 放宽 + 每函数独立着色 + 期望偏置合并对上"。
3. **免 marshalling 语义保证缺失**：需要"值住在上下文槽 ⇒ 调用点默认不 re-move"的**显式
   语义**（当前先生成 move 再寄望消除，可静默退化）。
4. **验证/诊断缺失**：上下文寄存器分配失败（无法一致着色/被迫溢出）时须**报错而非静默
   退化**——否则重蹈"隐式 ABI 静默失效"。

## 3. 提议设计：`.context`

### 3.1 语法（GNU 前端）

```asm
; 声明一个上下文：一组命名上下文变量 + 寄存器类/数量。asmp 把每个字段一致分配到
; 整个函数族共享的固定物理寄存器,并自动派生"占用/保留"掩码。
.context p256_field {
  acc: x[6]        ; 6 limb 累加器 (Montgomery CIOS 中间态), 上下文驻留
  a:   x[4]        ; 操作数 a (前向载入, 跨 add/sub/mul 存活)
  bp:  x           ; 操作数 b 指针
}

; 函数 import 上下文;对 ctx 变量的引用解析到共享寄存器,本地临时仍由 asmp 自由分配
; (约束为与活跃上下文寄存器不冲突)。
.function p256_mul (context p256_field) inline-only
entry:
  ldr x.bi, [p256_field.bp]
  mul p256_field.acc0, p256_field.a0, x.bi     ; 上下文变量按名引用
  umulh x.t0, p256_field.a0, x.bi              ; x.t0 是本地临时, asmp 分配
  ...
  ret
.end

.function jac_double_hw (context p256_field, in: x0=x.r, x1=x.p) export
entry:
  ldp p256_field.a0, p256_field.a1, [x.p, #0]  ; 载入 in_x 到上下文
  ...
  .call p256_mul                               ; 上下文驻留: 零 marshalling
  ; p256_field.acc 现持结果, 直接可读 (无 store/reload, 无 mov)
  ...
  ret
.end
```

要点：
- `.context NAME { field: class[count]; … }` 声明命名上下文；`class` ∈ `x/w/v/z/p`，
  `[count]` 展开为 `field0…field{count-1}`（如 `acc:x[6]` → `acc0…acc5`）。
- `.function … (context NAME)`：函数 import 上下文；`NAME.fieldK` 引用上下文变量。可
  import 多个上下文。上下文变量**不在**该函数的 `in:/out:` 签名里（它们跨函数穿透，
  非调用参数）。
- `.call fn`（fn 与调用方共享上下文）：**对上下文变量零 marshalling**（已在正确寄存器），
  只 move 非上下文的 `in:/out:` 参数。

### 3.2 分配语义（核心）

1. **联合分配 pre-pass**：对每个 `.context`，asmp 收集所有 import 它的函数，做一次
   **跨函数联合分配**——为每个上下文字段选一个物理寄存器（或 w/x 视图对），使得：
   (a) 整族一致（同字段在所有函数同寄存器）；(b) 不与各函数的本地临时活跃区冲突
   （用各函数的干涉信息取并）；(c) 不与各函数签名的 ABI 槽冲突。
2. **上下文寄存器 = 每函数隐式 banned + 跨内部调用隐式 preserved**：asmp 自动派生
   omul/oadd 里手调的那批掩码——上下文寄存器对本地分配"占用"（banned），对族内 `.call`
   "保留"（preserved），使中间 helper 不破坏上下文。
3. **move-free by construction**：族内 `.call` 的 lowering **对上下文变量根本不生成 move**
   （§2 缺口 3），非"生成后消除"。这是与 omul/osqr 的关键区别（避开当年的 marshalling
   开销）。
4. **本地临时正常分配**：非上下文寄存器在各函数内仍由 asmp 图着色自由分配（排除活跃
   上下文寄存器）。

### 3.3 校验（消除静默失效）

- **联合分配失败即报错**：若上下文无法一致着色（族内某函数压力太大、上下文+本地临时
   超 31 GPR），asmp **汇编期报错**并指出是哪个函数、哪个字段、压力多少——而非静默溢出
   退化。这把"隐式 ABI 静默失效"变成"编译期一致性检查"（本特性最大的可维护性收益）。
- **上下文使用一致性检查**：所有 import 同一上下文的函数对字段名/类/数量声明一致；
   跨函数的读写不违反上下文寄存器的存活假设（复用 reg-interfere 约束原语，§4）。

### 3.4 上下文作用域层级（context scope levels）—— 正交维度

§3.1–3.3 解决"寄存器**如何**分配"（M1 手动 pin / M2 自适应联合分配）。**正交**于此的是
"上下文绑定在**多大范围**内被保证稳定"——即上下文寄存器的信息穿透**到哪个边界为止、
过边界时 asmp 该生成/强制什么保存·恢复·保留纪律**。这决定于上层应用的部署形态。

语法（作用域是 `.context` 的属性，与 pin/自适应正交）：

```asm
.context NAME (scope library)      { acc: x[4]; a: x[4]; rp: x }   ; 默认
.context NAME (scope process reserve=x28)  { self: x }             ; 进程级保留寄存器
.context NAME (scope signal)       { sp_ctx: x }                   ; 异常安全
```

三个层级 = 三种"稳定性保证 + 边界纪律"，由弱到强：

#### L1 · 库层级（library，默认）—— 边界自动保存/恢复

**语义**：上下文寄存器是**库内部约定**，对库外的标准 AAPCS64 世界不可见。穿透范围 =
import 同一上下文的**函数族内部**；边界 = 族的**公开入口**（`export` 且被库外调用）
与**族内调用出库**（`bl` 到非族的 AAPCS64 函数）。

**asmp 在边界自动生成**（这是"库接口边缘自动生成处理、读取、恢复上下文寄存器"）：
- **公开入口/出口**：上下文寄存器若落在 AAPCS64 **callee-saved**（x19-x28）→ 入口 `.save`
  出口 `.restore`（AAPCS64 要求，asmp 已有机制，扩展为"凡上下文占用的 callee-saved 都
  保存"）；若落在 **caller-saved**（x0-x18）→ 库外不会保留它，故入口须**初始化**上下文
  （载入初值）、出口视其为可弃（AAPCS64 语义）。
- **族内调用出库**：对每条 `bl` 到**非族 AAPCS64 函数**，其间活跃的 caller-saved 上下文
  寄存器会被被调方 clobber → asmp **自动在该调用点插保存/恢复**（或诊断"上下文活跃期
  跨越了外部调用"）。族内 `.call` 不受影响（§3.2 move-free、preserved）。

**净效果**：上下文成为**库私有寄存器 bank**——在公开入口建立、公开出口拆除，族内自由
共享，库外完全无感。复用现有 `.save/.restore` + clobber-aware（§4）。**风险最低、最先做**。

#### L2 · 进程层级（process）—— 全程序 `-ffixed-rXX` 保留

**语义**：上下文寄存器**进程级预留**——整个应用（含 C 编译单元）以 `-ffixed-x28` 编译，
**任何模块都不分配/修改**这些寄存器。穿透范围 = **全进程任意调用边界**（包括调入 C、
调入其它模块），因为无人会 clobber 它。

**asmp 的职责**：
- **假设上下文寄存器跨任意调用稳定** → 连出库的 AAPCS64 调用也**不需保存/恢复**（L1 的
  边界纪律在此可省——这是 L2 相对 L1 的性能收益）。
- **产出构建契约**：生成 manifest / 头注释 / build-system 钩子，声明"本库依赖 x28 被全程
  `-ffixed` 保留"，让上层强制 `-ffixed-x28`（对应用户说的"应用层强制 -ffixed-rxx"）。
- **校验库自身不违反自己的保留**（不把保留寄存器挪作它用）。
- **保留失效的防护**（关键风险）：若某模块没遵守 `-ffixed` → 静默腐败。缓解：可选生成
  **启动期自检**（写标记值→跨一次可疑调用→验证未变）或**链接期断言**，把"全程序未
  一致保留"从运行期腐败变成可诊断失败。

**用例**：解释器/VM 的**线程本地上下文指针**（当前 frame / heap / TLS 基址）——需在**所有**
调用间稳定，正是 `-ffixed` 全局寄存器的经典用法。**最强保证、但要全程序协作**。

#### L3 · 异常安全层级（signal）—— 信号处理专用/敏感寄存器 ⏸ **暂缓（价值边际）**

> **决定（2026-07-28）：暂不实现 L3。** 理由：L3 主要为"用专用寄存器做信号标志"这类
> 模型服务（信号 handler 置位 → 同步流轮询 → 进异常流程）。但该模型的置位必须写 ucontext
> 保存槽（`regs[N]`/`__ss.__x[N]`，见下）——**置位侧就是一次内存写，和 `volatile
> sig_atomic_t pending=1` 没区别**。寄存器方案唯一（且很小）的优势在**高频轮询侧**：`cbz xN`
> 免一次 L1 load，而内存标志的 load 恒在 L1、分支恒命中、宽 OoO 核基本藏掉——只有极紧
> 循环（memcpy 级）+ load 单元吞吐成瓶颈时才显现（GC safepoint 那种窄场景）。**收益边际 +
> 代价重（全程序 -ffixed + 平台特定 ucontext 槽契约 + 异步窗口分析）+ 对当前驱动用例
> （rktcrypto 纯库内计算、无信号语义）完全无关** → 暂缓。绝大多数场景用内存标志即可。
> 以下分析保留，供未来极端热轮询场景参考。

**语义**：针对**异步信号**——信号在任意指令边界打断执行。此层管两类寄存器：
(a) **信号处理器专用**寄存器（handler 自身要用、需与库上下文不撞）；(b) 库上下文里
**信号可观测/须原子更新**的字段（safepoint/GC 读的上下文指针）。穿透范围 = **含异步
再入的当前模块内部**。

**平台事实（aarch64/Darwin，设计须据此）**：内核在投递信号前把**全寄存器**存入 ucontext、
`sigreturn` 时恢复——故上下文寄存器的值**默认能扛过一次信号 handler**（handler 里 C 代码
的 clobber 在返回时被内核撤销），**除非** handler 走 `siglongjmp`/`setcontext`/改 ucontext。

**asmp 的职责**（在默认内核保存之上加纪律）：
- **标注异步不安全窗口**：上下文寄存器处于**瞬态/不一致**（如多寄存器上下文更新到一半）
  的区间，若被信号 handler 读取会出错 → asmp 标注/校验这些窗口，或要求上下文更新对
  信号可见方**原子**（单寄存器写、或 handler 只读稳定字段）。
- **专用信号寄存器的保留与隔离**：把 (a) 类寄存器从常规上下文/本地分配里**保留**，
  确保 handler 与库不撞（类似 L2 但只对信号路径）。
- **与 `siglongjmp` 交互的诊断**：若上下文寄存器语义要求跨 `siglongjmp` 存活，须落在
  被 setjmp/longjmp 保存的集合里（callee-saved）——asmp 可校验此约束。

**保存槽是内核级、Linux/Darwin 同构（回应"谁提供保存槽"）**：handler 里"给专用寄存器
置位"不能写**活寄存器**（`sigreturn` 会撤销），须写**内核信号帧里的保存槽**（内核建帧、
`sigreturn` 恢复改过的值）。保存槽是 **OS 内核**提供的（Linux：`setup_rt_frame`/`rt_sigreturn`；
Darwin：XNU 信号投递/`sigreturn`）；**libc 只提供 ucontext 类型定义 + sigreturn 蹦床**，不
拥有该槽。故 L3 的 ucontext 槽契约**须按平台配置化**（同 asmp 的 per-platform ABI 表）：

| 平台 | 专用寄存器 xN 的保存槽字段 |
|---|---|
| Linux/aarch64 | `uc->uc_mcontext.regs[N]`（`struct sigcontext`，GPR 在 regs[0..30]） |
| Darwin/arm64 | `uc->uc_mcontext->__ss.__x[N]`（GPR 在 __x[0..28]） |

底层机制两平台一致（Go 异步抢占即用之），差异仅结构体布局。handler 侧 C 代码按 asmp
声明的槽契约写；asmp 声明寄存器 + 校验窗口，但不生成 handler（那是 C+平台）。

**最严、最专用**，仅信号敏感的上下文需要（如 VM safepoint）——但见本节顶部：暂缓。

#### 层级与 M1/M2、寄存器类的组合

- **正交于 pin/自适应**：L1/L2/L3 都可搭配手动 pin（M1）或自适应联合分配（M2）。手动
  标识上下文↔寄存器 id 绑定（用户所述）= M1 的 `field=reg`，在 L2/L3 尤其常用（进程保留
  与信号专用寄存器往往需人为指定确切 id，如 `reserve=x28`）。
- **默认 L1**：不写 `scope` 即库层级，覆盖 rktcrypto `_p256_*` 这类**纯库内**用例（它们
  根本不跨出库、也无信号语义，L1 足够且零额外纪律——就是当前 M1 已验证的形态）。
- **递进落地**：L1 复用现成 `.save`/clobber-aware，**最先做**（几乎已随 M1/M2 具备）；
  L2 需 manifest + 可选自检，中等；L3 需信号窗口分析，最后、最专用。

## 4. 映射到现有基建（大量复用，非从零）

| 需要的能力 | 复用的现成机制 | 出处 |
|---|---|---|
| 上下文变量互斥/共存约束 | **reg-interfere 合成 directive**（现内部专用，本特性暴露给联合分配） | inline.rkt:469, interference.rkt:556-600 |
| 上下文值跨 `bl` 存活合法着色 | **clobber-aware 分配**（据派生 preserved 放宽） | interference.rkt:624-697 |
| 上下文字段"粘"到固定寄存器 | **偏置着色**（现用于 ABI 槽，扩展到上下文字段） | allocator.rkt:667-686 |
| 上下文的命名身份/元数据 | **function-identity / clone metadata** | function-identity.rkt, function-clone.rkt |
| 上下文的内存驻留对偶 | **`.frame S,M`（命名帧临时，待实现）** | openssl-parity-scheduling-plan.md:84-86 |
| 掩码派生（banned/preserved） | 从 `.context` 声明自动生成，替代 omul/oadd 手调 | abi.rkt:88-114 |

新增的核心组件仅两块：**(a) 联合分配 pre-pass**（跨函数一致分配上下文字段）；
**(b) move-free 的 `.call` lowering 分支**（上下文变量不生成 move）。其余是复用 + 校验。

## 5. 与已废弃 omul/osqr 的关系——为何这次不同

omul/osqr **是雏形，但用错了工具**：借"逐函数调用约定"表达"跨函数共享上下文"，把共享
性藏进位置化 args/return + 手调掩码，且**托管 `.call` 仍生成 marshalling move**（best-effort
消除）+ 帧驻留布局——正是 `openssl-parity-scheduling-plan.md` 第九节实测判其收益为 0（229>
219）的直接开销来源。

`.context` 的三点关键改进直击当年失败根因：
1. **共享性上提为一等命名对象**（消灭 omul/oadd 的重复掩码硬编码）；
2. **联合分配保证一致**（不靠"每函数独立着色 + 期望偏置合并对上"）；
3. **move-free by construction**（对上下文变量根本不生成 marshalling move）——这是避开
   229 vs 219 那层开销的关键。

**但必须诚实**：omul/osqr 的实测也揭示"asmp 托管路径达不到 OpenSSL 手工 174"的部分原因
是**手工逐指令寄存器复用的调度**，而非仅寄存器约定。因此 `.context` 的定位**不是让 asmp
自动调度出 OpenSSL 级内核**，而是：**让程序员用虚拟上下文变量写手工调度的内核**（指令
顺序仍手写），asmp 只负责寄存器名的跨函数一致分配 + move-free + 校验。见 §6 的性能论证。

## 6. 性能论证：为何不改指令调度 ⇒ 性能不变（关键可行性）

本特性的性能安全性建立在一个已验证的先例上：**A2（md5 语义化）证明"纯 SSA 重命名、
保持指令顺序字节不变"→ asmp 分配后指令流规范化后 0 结构差异 → 性能由构造保证**
（见 `rktcrypto` 的 ASM-ENHANCEMENT-PLAN.md A2）。

`.context` 本质是**把 A2 的单函数寄存器重命名扩展到跨函数**：
- 程序员把 `jac_double_hw` / `_p256_*` 的**手工指令调度原样保留**，只把物理寄存器名
  （x4-x7 / x14-x17）换成上下文变量名（`p256_field.a0` / `.acc0`）。
- asmp 联合分配把这些上下文变量**分回一组一致的物理寄存器**（很可能就是 x4-x7/x14-x17
  或等价集），move-free 保证族内调用不插 move。
- 产物指令流**与手写内核规范化后逐条相同**（仅寄存器编号可能不同，如 A2）→ 性能不变。

**验收门禁**（与本仓一贯纪律一致）：`.context` 版内核 vs 手写版，(a) 规范化寄存器编号后
指令流 0 结构差异（Gate A，如 A2）；(b) 差分 0/200000 bit-exact；(c) 逐内核头对头 vs
OpenSSL ecp_nistz256 持平/反超不回归。三者全绿才采纳。

## 7. 风险与非目标

### 7.1 适用判据：何时用 / 何时不用 `.context`（防止无差别扩散）

`.context` 有真实成本——一层专用 DSL（scope / `.save all` 语义）+ 让内核依赖 asmp
在场才能再生。它**只在一个特定结构上回本**：**跨函数共享的寄存器-ABI 契约**——一族
相互调用的手写内核约定"操作数在 xA-xB、结果在 xC-xD"，且该契约否则是**隐式、无强制**
的（静默 AAPCS64/调用约定违反的温床）。判据：

| 结构特征 | 手法 | 理由 |
|---|---|---|
| 跨函数共享寄存器-ABI 的手写族（互相 `bl`/内联、共用固定寄存器约定）| **用 `.context`** | 契约声明一次、多内核强制一致、L1 装配期抓越界；批次 = 耦合边界 |
| 单函数内的伪语义名（如寄存器照抄参考实现物理编号）| **纯 SSA 重命名**，不用 `.context` | 不跨函数、无共享契约 → 局部改名即可，上 `.context` 是过度工程 |
| asmp 生成器/分配器产出的内核 | **普通命名虚拟寄存器** | 本就走 asmp 分配，无手写寄存器-ABI 契约可声明 |
| 帧指针函数 / 变长 alloca / 手工管理帧的内核 | **暂不适用**（待 M3 `.frame` 或"手工管理帧"逃生舱）| `.save all` 不设 x29 帧指针、M1 拒手写 callee-saved raw 寄存器 → 强上违反零回归 |

**批次大小由耦合边界决定，不是越多越好**：应用到共享 ABI 族的**部分**成员会制造新缺陷
（同一契约两种写法）。反之，把 `.context` 铺到不共享契约的内核上是纯成本、零收益。

**"边界"含入参绑定与 clobber 集，不止传参/返回（易错点）**：`.context` 里 pin 的
寄存器常身兼多职——如 p256_hand 的 `t0=x1`：在 `mont_sqrn_p256` 里 x1 是 **C 入参
`a` 指针**（AAPCS64 第二参数、边界），在 helper 里 x1 是 scratch；且手写族靠**裸 `bl`
（无 `.clobber`）**互调，"哪些寄存器被 helper 破坏"是**隐式跨函数契约**，那些 scratch
也是共享 ABI 的一部分。反例（2026-07-29 实测）：把 3 个 scratch（x1/x12/x13）从 `.context`
移除改未声明虚拟 → mont_sqrn 的 `ldr x.a0,[x.t0]` 里 x.t0(本应=x1=入参 a)被分配器
放到 x12 → **从错误地址加载 → 段错误**（寄存器集不变仅置换、无帧变化，却崩）。故判定
寄存器是否"边界"要看它**是否是入参/是否参与跨函数 clobber 约定**，不只看传参/返回。

**已修：汇编期 `.context` 完整性关卡（2026-07-29）**。上述反例暴露了真正的 asmp 集成
缺口：一个 `x.t0` 被**使用却通篇无定义、又非声明形参**，asmp 旧行为是**静默着色到任意
寄存器、产出读错寄存器的代码**（运行时才段错误）。现加 fail-fast 关卡（`pipeline.rkt`
`check-no-undefined-gpr-virtuals`）：凡"被用而通篇无定义、且非声明形参"的 GPR 虚拟 →
汇编期报错并指引"须 pin 或 `in:` 声明"。

**通用 · 高精度（不按作用域收窄）**。关键是**放到定义完全可见的点**——`cli/as.rkt`
`run-regalloc-stage` 里 `expand-inline-cfg` **之后**（post-inline，寄存器仍虚拟、尚未
分配）。那时 `.inline`/`.call` 已展开成真指令，被内联体提供的定义（如 deflate 的
`best_len`，源于 `.inline df_search_chain` 的 `out:` 绑定）全部可见，故对**所有**函数
精确、零误报。声明形参由 cfg 阶段捕获的 `functions`（`function-params` 尚未被 callconv
消费）建 `{函数名→形参符号}` 侧表、post-inline 按名查表排除。

设计要点（迭代收敛的踩坑，每步被新 FP 类别推翻）：①**判据=“通篇无定义”而非
liveness live-in**（liveness 保守上近似，把大量已定义、仅某路径先用后定义的正常临时算
live-in→41 FP）；②**按符号名归一化，忽略 w/x 视图**（AArch64 w 写清零 x 高 32 位，
`mov w.foo` 定义了整个 x.foo，否则 w-定义/x-使用误判无定义）；③**只查 GPR**（向量 SHA3
指令 eor3/rax1 的 use-def 建模不全）；④**排除声明形参**（in:/out: 合法无 body 定义，值由
ABI 传入；须用 cfg 阶段侧表，因 regalloc 时 function-params 已被 profile 消费）；⑤**放到
post-inline**（此前限定 `.context` 函数只是规避“.inline 定义尚未展开不可见”的权宜；正解是
移到内联后，让检查通用而精确）。门禁：asmp **676 项测试全过**（含 5 项完整性测试：报错/
已写入/w-x 视图/**非 .context 函数同样受检**/声明形参豁免）、crypto 全 regen-check 绿、
虚拟化反例被拦、pinned 正确版通过、**全库零 FP**。**结论：全 pin 仍是这类内核的正确解，
而现在漏 pin（任何函数）会在汇编期即被精确诊断，不再退化成静默段错误**。

**rktcrypto 实证（2026-07-28）**：全仓 12 个 `.asm` 源里 `.context` 只用于 **1 个**
（`p256_hand.asm`，1 条声明 / 9 内核 = 一个 P-256 点运算族的共享寄存器-ABI，风险④）；
md5 用 SSA 重命名（A2）、bn_sqr 因帧指针+变长 alloca 被**拒绝**收编（A5）、其余 10 个
用普通命名虚拟。即：该结构在整个代码库恰好出现一次，特性也就用在这一处——无"更多可批量"
的对象。新增手写内核前，先过上表判据再决定是否值得引入 `.context`。

**风险**
- **寄存器压力**：上下文集 + 本地临时超 31 GPR → 联合分配失败。缓解：这正是要**报错**
  的场景（§3.3），而非静默溢出；且当前手写内核已在此约束内工作（存在可行分配），
  `.context` 只需复现它。
- **调度器交互**：上下文寄存器预着色，调度器（若启用）须尊重；但 crypto 内核调度器默认
  关（见 rktcrypto D1 实测：宽 OoO 核调度无收益且 md5 有正确性 bug），故低风险。
- **联合分配复杂度**：跨函数一致着色是新分配阶段；先做**保守版**（上下文字段直接钉到
  声明可选的物理寄存器提示，asmp 只校验一致 + 派生掩码 + move-free），再迭代到全自动
  联合选择。

**非目标**
- 不追求 asmp 自动调度出 OpenSSL 级内核（§5：调度仍手写）。
- 不重启 point-op 托管路径追平 OpenSSL 174 的目标（已实测否决；且本仓手写内核已达持平）。
- 不改 `.function`/`.call`/自定义 ABI 的现有语义（纯增量新原语）。

## 8. 验收 / 示例

**里程碑 M1（保守版，最小可用）** ✅ **已实现（2026-07-28）**：`.context NAME
field=reg …` 声明 + `.function (context NAME)` import + 替换 pass（把命名虚拟寄存器
`x.<field>` 替换为映射的物理寄存器，保 w/x 视图）+ 一致性/冲突校验。改动：
`parser/ast.rkt`（'context directive kind）、`parser/gnu-parser.rkt`（解析 .context 与
签名里的 context import）、`semantic/apply-contexts.rkt`（新，替换 pass + 校验）、
`cli/as.rkt`（挂为 parse→CFG 之间的 stage 1.5）、`test/context-test.rkt`（9 用例）。
**门禁全绿**：(1) asmp 全套 666 tests 通过（新增 9 context 用例，零回归——apply-contexts
对无 context 代码是恒等）；(2) **字节等价**：p256 field-add 手写物理 vs `.context` 版
产物**逐字节相同**（同 SHA），且**真实 rktcrypto `_p256_add`（含 b 操作数消费后寄存器
复用为临时的手法）同样字节相同**（SHA 579360e5）；(3) **冲突检查实测触发**：字面 x8
写在 `x.b0=x8` 的 context 字段处 → 汇编期报错（带 file:line：`手写物理寄存器 x8 与
上下文字段占用同一物理寄存器`），把风险 ④ 的静默失效变成编译期错误。
M1 局限（诚实）：替换 + 冲突检查仅 GPR(x/w)；未做签名 ABI 槽仲裁（M2）；寄存器复用
（b 消费后复用为临时）须按 context 名书写（否则冲突报错）——M2 的联合分配才能让临时
自由虚拟化。
后续：用 `.context` 重写整个 `_p256_*` + `jac_double_hw` 族（机械转写，字节等价 gated）
使 p256_hand.S 从"无源手写物理"变为"asmp `.context` 源、可再生"。

**里程碑 M2（联合分配）**：去掉显式寄存器提示，asmp 自动跨族一致选择上下文寄存器 +
失败报错诊断。

**里程碑 M3（`.frame` 对偶）**：命名帧临时（内存驻留上下文），给点内核的 scratch 布局
（现 p256_hand.S 硬编码 `@0/@32/@64…`）一个命名抽象。

**作用域层级里程碑（§3.4，正交于 M1–M3）**：
- **L1 库层级** ✅ 随 M1/M2 具备（默认作用域；复用 `.save`/clobber-aware 的边界处理；
  rktcrypto `_p256_*` 纯库内用例只需 L1）。剩：把"公开入口/出库调用自动保存·恢复上下文
  寄存器"从隐式（现靠 `.save`）显式化为 `scope library` 属性驱动。
- **L2 进程层级**：`scope process reserve=xNN` + 产出 `-ffixed-xNN` 构建 manifest + 库内
  保留校验 + 可选启动自检。门禁：跨模块（调入 C）上下文寄存器稳定性实测。
- **L3 异常安全层级** ⏸ **暂缓**（§3.4 L3：收益边际——寄存器信号标志的置位侧就是内存写、
  与 `volatile sig_atomic_t` 无异，仅高频轮询侧省一个 L1 load 且多被 OoO 藏掉；代价重
  且对当前驱动用例无关）。分析保留供未来极端热轮询场景。

达标标准：rktcrypto 的 `_p256_*` 寄存器 ABI 硬编码（审查风险 ④）被 `.context` 声明取代，
汇编期一致性检查生效，且性能逐内核不回归；作用域按用例递进（库内 L1 已足够）。

## 9. 开放问题

- Q1：上下文字段的 w/x 视图（32/64 位）如何声明与引用？（P-256 全 x，但 md5/sha1 用 w/v。）
- Q2：一个函数 import 多个上下文时，联合分配如何仲裁跨上下文的寄存器冲突？
- Q3：`.context` 是否需要"作用域"（某些字段只在族内部分函数活跃）以省寄存器？还是整族
  全程占用（简单但压力大）？倾向先做整族占用（简单、匹配当前手写内核）。
- Q4：M1 的"显式物理寄存器提示"是否直接复用 `abi.rktd` 的 args/return 语法，还是 `.context`
  内联提示？倾向内联（`acc: x[6] @x14`），让上下文声明自包含。
- Q5：这值不值得做？rktcrypto 侧收益 = 消除最高风险硬编码 + 可维护性；成本 = asmp 新
  分配阶段 + 前端语法。建议先做 M1 保守版验证"指令流等价 + 消除硬编码"，再决定 M2/M3。
- Q6（作用域）：L2 的 `-ffixed` 保留失效如何**可靠**检测？启动自检只能抽样、链接期断言
  难跨语言——是否退而"文档化构建契约 + 关键路径断言"即可？
- Q7（作用域）：L3 的"异步不安全窗口"如何界定粒度？是每条多寄存器上下文更新都算窗口
  （保守、开销大），还是只标注声明为 signal-visible 的字段的非原子更新？
- Q8（作用域）：三层级是否需要**混合**（一个上下文里部分字段 L1、部分 L2）？倾向作用域
  是**整个上下文**的属性（简单），跨层级需求拆成多个 `.context`。

---

## 10. L1 / L2 实现方案（落到 asmp 现有机制）

M1（`.context` 声明 + 替换 + 冲突校验）已实现。L1/L2 是叠在其上的**作用域**维度，均**大量
复用现成机制**、改动面小。L3 暂缓（§3.4）。

### 10.1 L1 · 库层级（默认）—— 实现方案 ✅ **已实现（2026-07-28）**

> **已实现**：解析 `(scope library|process|signal)`（默认 library）+ L1 校验（callee-saved
> 上下文字段被 export 函数用却未 `.save` → 汇编期报错）。改动：`parser/gnu-parser.rkt`
> （`parse-context-directive` 解析 `(scope …)`，args 改为 `(list scope field-map)`）、
> `semantic/apply-contexts.rkt`（collect-contexts 带 scope-registry、`callee-saved-lib-regmap`、
> 主循环追踪 used/saved + `l1-check!`）、`test/context-test.rkt`（+5 L1 用例）。
> **门禁全绿**：asmp 全套 **671 tests**；正向（`scope library`+`.save all`→自动 `stp x19`）；
> **负向**（用 x19 漏 `.save all`→报错"上下文字段 's0' 落在 callee-saved 寄存器 x19，但
> export 函数 'foo' 未保存它"）；rktcrypto 帧模式 A(手写 stp/ldp+硬编码 `[sp,#16]` 偏移)
> vs B(`scope library`+`.save all`,源零硬编码)**结构等价**——证明可消除 `jac_double_hw` 的
> 手写 save + 硬编码栈偏移（审查风险 ⑤）。auto-save 复用 `.save all`（已免费），L1 新增
> 的是**边界保存的汇编期校验**（把静默 AAPCS64 违反变编译期错误）。剩：步骤 3（出库调用
> caller-saved 字段自动 save）与步骤 2b（无 `.save all` 时自动注入）后做。

**目标**：上下文寄存器是库私有，asmp 自动处理 AAPCS64 边界（公开入口/出口、出库调用）。

**关键复用**：`.save all` **已自动收集"函数实际用到的 callee-saved 寄存器"并生成
prologue/epilogue + 栈槽**（`pipeline/regalloc/save-load.rkt:159`）。M1 替换后，若某上下文
字段落在 callee-saved（x19-x28 / v8-v15）且被 `export` 函数使用，**该函数只要写 `.save all`，
边界保存已自动完成**——L1 的 callee-saved 边界处理**基本免费**。

**实现步骤（增量，由易到难）**：
1. **解析 `scope library`（默认）**：`.context NAME (scope library) {…}`。无 `scope` 即此，
   = 当前 M1 行为，仅打标记。
2. **callee-saved 上下文字段自动进 `.save` 集**：`scope library` 上下文被 `export` 函数
   import 时，把该上下文映射到 callee-saved 的字段并入函数的 save 集。两选一：
   - (a) **约定**：文档化"`scope library` + `.save all` = 边界已处理"，零新代码（`.save all`
     已覆盖）。**先做这个**。
   - (b) **自动注入**：函数未写 `.save all` 时，apply-contexts 为 callee-saved 上下文字段
     注入 `.save`/`.load`（复用 save-load.rkt）。便利性增强，后做。
3. **出库调用的 caller-saved 上下文字段处理**：族内 `bl` 到**非族**（不 import 同上下文）
   的 AAPCS64 目标、且此时有 caller-saved 上下文字段活跃 →
   - **M1-保守**：**诊断**（"上下文 caller-saved 寄存器 x14 跨越外部调用 @file:line"），
     交程序员。**先做这个**（rktcrypto `_p256_*` 只有族内 `bl`，此情形不出现）。
   - **L1-完整**：自动在调用点插保存/恢复（复用 clobber-aware / spill 机制）。后做。
4. **校验**：`export` 函数 import `scope library` 上下文却未保存它用到的 callee-saved 字段
   → 报错（复用 `semantic/save-verify.rkt`）。

**rktcrypto 具体收益**：`jac_double_hw` 等现手写 `stp x19,x20,[sp,#16]` 保存 x19-x22
（callee-saved，充当 r/p/q 指针 + 循环态）。把它们声明为 `scope library` 上下文字段 +
内核用 `.save all` → asmp 自动生成 prologue/epilogue，**消除手写 stp/ldp 与硬编码栈偏移
（审查风险 ⑤）**。这是 L1 对 rktcrypto 的实打实收益。

**改动清单（小）**：`gnu-parser.rkt`（解析 `scope`）；`apply-contexts.rkt`（步骤 2b 可选注入、
步骤 3 诊断、步骤 4 校验挂接）；复用 save-load/save-verify。

### 10.2 L2 · 进程层级 —— 实现方案

**目标**：上下文寄存器经 `-ffixed` 进程级保留 → 跨任意调用稳定（连出库也免保存）+ 产出
构建契约。

**关键复用**：`semantic/public-abi.rkt` 已有 `public-abi-manifest` / `write-public-abi-manifest`
/ `public-c-header` / `write-public-c-header`——manifest/头生成基础设施现成。

**实现步骤**：
1. **解析 `scope process reserve=xNN [xMM…]`**：显式列出进程保留寄存器（L2 天然要手动
   pin，因为要与 `-ffixed` 精确对齐——即用户所述"手动标识上下文↔寄存器 id 绑定"）。
2. **保留字段不进 `.save`**：进程稳定，跨任意调用（含外部 AAPCS64）都不保存/恢复——
   这是 L2 相对 L1 的性能收益（省边界纪律）。
3. **clobber-aware 视保留寄存器为全程 preserved**：在 `interference.rkt` 的 clobber 计算里，
   把 L2 保留寄存器从**任何**调用的 clobber 集里剔除（`-ffixed` 保证无人动它），使保留
   寄存器里的值跨任意 `bl` 存活、免溢出。
4. **产出构建 manifest**：扩展 `public-abi.rkt` 的 manifest 条目，加
   `(reserved-registers x28 …)`；`--public-c-header` / 构建钩子据此声明"所有 C 编译单元
   须 `-ffixed-x28`"。让上层构建强制该 flag。
5. **库自洽校验**：库内除声明的上下文外**不得**另用保留寄存器 → 报错（扩展 M1 冲突检查
   为"保留寄存器出现在其上下文之外即错"）。
6. **可选启动自检**：生成 `_ctx_verify_reservation`——写哨兵到保留寄存器 → 调一次外部
   dummy → 验证未变，把"某模块没遵守 `-ffixed`"从静默腐败变可诊断失败（对应 Q6）。

**用例**：**非 rktcrypto**（纯库内，L1 已足够）。真实用例 = 解释器/VM 的**线程本地上下文
指针**（Racket CS / python3-native 解释器状态基址）进程级保留供廉价访问。故 L2 是更广
Racket 生态的特性，当前**推测性**，但 manifest 复用干净、设计就绪。

**改动清单**：`gnu-parser.rkt`（解析 `scope process reserve=`）；`apply-contexts.rkt`（校验 5、
不注入 save）；`interference.rkt`（步骤 3 clobber 剔除）；`public-abi.rkt`（步骤 4 manifest
扩展）；步骤 6 可选 codegen。

### 10.3 落地建议与门禁

- **L1 先做**（有 rktcrypto 实打实收益：消除手写 save + 硬编码栈偏移；主要复用 `.save all`；
  低风险）。门禁：asmp 测试保绿 + rktcrypto 内核用 `scope library` 重写后差分 0/200000 +
  字节/结构等价（callee-saved 自动 save 后产物应与手写 prologue 等价）。
- **L2 待用例**（解释器出现时再做；manifest 复用现成）。门禁：跨模块（调入 C）保留寄存器
  稳定性实测 + `-ffixed` manifest 正确产出 + 自检捕获违规。
- **正交性**：L1/L2 都在 M1 替换之上加"边界纪律"，不改 M1 已验证的替换/字节等价核心。
