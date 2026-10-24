# fasl2 + vfasl 镜像装载：boot-runtime 预实例化装载器规格

> 2026-09-18。用户定向：**专用、超高性能、引导式 boot-runtime 装载流程；装载期不分配任意可回收对象、完全不触发 GC。**
> 这是第四 boot 段（REPL 预实例化）的**生产装载器**规格，取代实验的 post-boot A/B walk 脚手架。
> 上游账：`repl-startup-4th-segment-handoff.md`、memory `racket-repl-startup-project.md`。

## 0. 结论先行（本次会话已验证/推断的地基）

- **崩溃根因已坐实（已验证）**：实验的 codes 崩溃 = post-boot 读 RETAIN 静态 reloc，第一次 post-boot GC 悬垂后 `s_get_reloc` 返回野指针。Scheme 层任何 GC 抑制都无效（walk/引擎装载/驱动入口三点全试）。⇒ 修复必须在 boot/C 层。
- **零分配只能靠 vfasl 镜像（已验证）**：任何 fasl-based 读逐对象反序列化进 gen-0，必分配整图（实测 5-12MB）→ 重招 ~34ms GC。唯一出路 = memcpy 整图到 **static 代**（`to_static`，仅 boot 期 `S_vfasl_boot_mode>0`）。
- **fasl2 域层已验证（已验证）**：MVP（scratchpad/mvp/fasl2.rkt）证明"外置 interned 类型（rmp）成 locator + 装载重建"跨进程正确（rmp-keyed 表 300/300，含计数器漂移）。底层 fasl 零改动。
- **eq-hash 进程不变性已解构（已验证）**：interned symbol = 内容哈希、跨进程稳定 → symbol-keyed 表镜像免 seeding；rmp/keyword/struct = 计数器哈希（首查询序）→ 需 seed。
- **externalref-vfasl 机件本会话原型过（已验证可行）**：vfasl reloc 引用"externals 向量[i]"，装载填表；code-reloc + data-external 全链路 round-trip 正确。为 linklet 字面量做时是死胡同，**为 fasl2 是正解**。

## 1. 架构：fasl2 域层架在 vfasl 镜像底座上

```
        build 期（可慢）                          runtime（boot 期，必须极快 + 零分配）
  ┌─────────────────────────┐            ┌──────────────────────────────────────┐
  │ 实例化 racket/init+xrepl  │            │ boot.c: 三段 boot + Scompact_heap      │
  │ fasl2-write:             │            │        + Sretain (若需)                │
  │  · 遍历 ns 状态图          │            │ ┌── 第四段装载（新 C 路径，pre-GC）──┐ │
  │  · interned/不透明类型     │  seg 四件套 │ │ 1. memcpy 镜像 → static（to_static）│ │
  │    外置成 externals 表     │ ─────────> │ │ 2. 解析 externals 表（结构/intern） │ │
  │  · 其余 vfasl 镜像化        │            │ │ 3. seed 计数器键的 eq-hash code     │ │
  │  · code 走 closure-fasl    │            │ │ 4. patch externalref → 解析对象     │ │
  │ 产出：image + externals    │            │ └────────────────────────────────────┘ │
  └─────────────────────────┘            │ main.sps: REPL 意图→跳过 require;非REPL 不装 │
                                          └──────────────────────────────────────┘
```

- **底座 = vfasl 镜像**：格式无关的整图 memcpy，装载到 static 代。不动 base fasl。
- **fasl2 = 域层**：独占 interned/不透明类型的外置与重建 + eq-hash seeding。所有域知识在此，boot/vfasl 内核只多一个 externalref reloc + externals 解析回调。

## 2. 格式扩展（两件，均本会话原型过或已解构）

### 2.1 externals 表（段内）
每条 = 一个 **locator**（kind + spec，spec 皆可 vfasl 化）：

| kind | spec | boot 期解析 | seed? |
|---|---|---|---|
| `rmp` | name（symbol/path/submod list） | `make-resolved-module-path` 重 intern | 需（计数器键） |
| `kw` | string | `string->keyword` | 需 |
| `sym` | name | `string->symbol`（或 vfasl-reloc-symbol 直接） | 免（内容哈希） |
| `prefab-rtd` | (key . count) | `prefab-key->struct-type` | 视键类型 |
| `loc` | (root-idx . edge-chain) | 从 8 根走结构边路径（n3-resolve，C 层，pre-GC 安全） | 免/视 |
| `bdw` | code 的 reloc 路径 | 读 code reloc（**pre-GC pristine → 安全**） | 免（code 无 eq 身份） |

关键：**发现→解析**。实验 discovery-walk（读所有 code reloc 找名，post-boot 崩）换成 build 期**声明** locator、装载器**解析**声明的路径（pre-GC）。

### 2.2 externalref reloc（vfasl 内核）
- cmacros 加 `vfasl-reloc-external-tag`（3-bit 枚举第 7，本会话加过）。
- vfasl.c `relink_code` + singletonref 循环：`tag==external → *ref = Svector_ref(externals, pos)`（本会话实现过 code-reloc + data-external 两路，round-trip 过）。
- `S_vfasl` 加 `externals` 参数；`fasl.c`/`externs.h` 穿参（本会话改过）。
- 铁律（本会话血泪）：FFI 目标地址必须符号化（当进程地址在别进程是毒指针）；code 永不走地址身份。

## 3. boot 期装载流程（零分配、零 GC 的关键序）

在 boot.c `Sscheme_init`（三段 boot + `Scompact_heap` + `boot_mode=0`）**之后**、任何 Scheme 分配之前：

1. **置 `S_vfasl_boot_mode=1`**（或等价，使第四段 `to_static`）。
2. **memcpy 第四段镜像 → static 代**（vfasl 常规路径，不进 gen-0）。
3. **解析 externals 表**（fasl2 回调，pre-GC）：
   - rmp/kw/sym → intern；loc → 从根走结构路径；bdw → 读 code reloc（此刻 pristine）。
   - 全部在 static 上就地产出"已解析向量"。
4. **seed 计数器键的 eq-hash code**：把 build 端记录的 code 值写进 rumble `codes` 表（对应本进程重建出的 rmp/kw 对象）。有界（state 段 rmp 814+kw 404≈1200 条）。
5. **patch externalref**：镜像里的 externalref 槽 `*ref = 已解析向量[i]`。
6. **恢复 `boot_mode=0`**，把控制权交给 Scheme。

全程无 gen-0 分配（镜像入 static、seed 写既有 codes 表、patch 就地）、无 GC 触发（第一次 post-boot GC 尚未发生，故 reloc/结构路径全 pristine）。**崩溃前提（悬垂 reloc）根本不存在**。

## 4. 两大障碍的解（均本会话验证/解构）

- **障碍一（引用任意 boot 世界对象，loc 1242 + bdw 159）**：externals 表的 `loc`（结构路径）+`bdw`（code reloc 路径）在 boot 期 pre-GC 解析。结构路径不读 reloc、地址无关（n3 已验证安全）；bdw 读 reloc 但 pre-GC pristine → 安全。
- **障碍二（eq-hash 进程不变性）**：symbol 键免费（内容哈希，MVP 200/200）；计数器键（rmp/kw）boot 期 seed（有界，步骤 4）。**不改 rumble eq-hash、不改 base fasl**（用户定向：底层别动，域逻辑进 fasl2）。

## 5. 非 REPL 零影响（硬约束）

第四段是**独立段 + 条件装载**：main.sps 启动早期判 REPL 意图，交互 REPL 才装第四段，-e/脚本/raco/批处理不装（与今日字节一致）。绝不合进 racket.boot 本体（那是无条件全进程装载）。

## 6. 实现步骤（C 工程，按依赖序）

1. **重建 externalref-vfasl 内核**（本会话做过并 round-trip 验证，已回退）：cmacros/vfasl.ss/vfasl.c/fasl.c/externs.h/strip.ss 六文件。`#ifdef vfasl_reloc_external_tag` 守 pb 自举；data-external 用硬编码 `#define VFASL_EXTERNAL_BASE`。
2. **fasl2-write 域层**（Chez 层）：遍历状态图，interned/不透明类型外置成 externals 表（locator），其余 `$fasl-to-vfasl` 镜像化，code 走已在主线的 closure-fasl（`fasl-type-closure-freevars=47`）。
3. **boot 期 externals 解析器**（新 C + Scheme 回调）：步骤 3-5 的 boot 流程。loc 结构路径解析器（C 走 record 字段 `$record-ref`）。
4. **eq-hash seed 原语**（rumble）：暴露 `set-eq-hash-code!`（写 codes 表），boot 期 fasl2 调用。
5. **boot.c 第四段装载钩子** + build.zuo 四段构建 + main.sps 条件装载。
6. **端到端**：真实 4 段 boot 的 time-to-prompt 实测（验证 ~80-100ms 外推）。

## 7. 状态

- 已验证：崩溃根因（boot 层）、零分配须 vfasl 镜像、fasl2 域层正确、eq-hash 解构、externalref-vfasl 机件。
- 待实现：步骤 1-6（C 工程主体）。**先做步骤 1**（重建 externalref 内核）——是一切的机件地基，本会话验证过可行。
- 红线：非 REPL 零影响；base fasl/rumble eq-hash 不改（域逻辑全在 fasl2）；bit-exact + 每步验证。
