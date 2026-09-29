# 第四段:正向设计（M2 产品化）— 绕开运行期 faslin 悬垂根

2026-09-17 · 原则=正向设计产品管线，不逆向修实验装置的低频崩

## 一、为什么转正向（逆向排查已定性到位）

实验装置（runtime faslin：B 进程 `fasl-read` 段镜像 + 重放 + 验收）复现一个低频崩（~13-17% 裸跑），已把机理定性锐化到：

- **已验证**：崩因=**真实悬垂堆指针**。某持有槽存一个指针，mark 期指向真对象（symbol/pair/vector/flonum，装载期可 `staddr-a2o` 铸回），到消费期其段已 `space_empty`（被释放）。持有槽在 live pure/impure 段、经**正常 GC sweep** 消费（非脏卡路径）。codes 线专属（zoreplay 对照全 0 触发）。
- **已排除**（全实测零）：code reloc 表完整性（coverage/movz per-span 差分/高带孤儿）、extvec/manifest 注入、运行期地址铸回、黑洞（=`unsafe-undefined` 合法哨兵）、弱结构、堆内第二持有者、状态图根可达持有者。
- **推断**：持有者被 GC 当 live 扫但状态图根不可达 → 挂 VM 全局根（namespace/registry/当前续延）。`object-backreferences` 命中两条持有链：① pair→rec:linklet→closure→rec:module ② vector→eq-hashtable→**continuation**（续延持有者=与"续延/栈根扫描漏 re-anchor"假说吻合）。
- **未知**：精确持有对象 + 装入 stale 指针的确切写点。

**判断**：这是**运行期把已实例化堆状态 fasl-in 回一个活进程**再手工重锚外部引用（code/keyword/rmp）这一路径的固有缺口——重放没把某条图边正确重锚，重放后该边指向的对象被回收。崩只出现在**codes-fast（RETAIN）线**；**green-none 线（zo 重放）崩免**（15/15，本轮 clean binary 复验 11/11+12/12）。逆向抓精确写点须重管线内核插桩，成本高，非当前主线；转正向=先把崩免的 green-none 线产品化。

## 二、架构与权衡（2026-09-17 纠正）

### 2.1 架构澄清（2026-09-17 纠正——原"native to-vfasl 免疫"前提有误）

读 `racket/src/cs/c/convert-to-boot.ss` + boot.c 定实：

- **racket.boot 不是堆镜像**：`(#%$make-boot-file dest machine '("petite" "scheme") src)`——boot 文件装的是**编译代码**，boot 期 `Sbuild_heap` **执行**它把 expander/io/thread 实例化出来。`-n -q` 已含 racket.boot 装载（实测 kernel-only ~30ms 已把 expander 实例化算进去）。故 expander 是"编译代码 boot 先例"，**不是活堆序列化先例**。
- **Chez 原生 save-heap 已移除**（[[repl-startup-preinstantiate-plan]] §方案 C 记）。**无 native to-vfasl 活堆免崩通道**——原 §二表格作废。
- **第四段 = startup 路径里 fasl-read 的活 ns 图**，不是 Chez boot 文件（boot 文件只吃编译代码，段是对象图）。装载点在 racket 启动早段（main.sps/启动序），boot 之后、REPL 之前。
- 实验装置的 `fasl-write`/`fasl-read` **就是**唯一可用的活堆序列化机制；跨进程外部引用重锚（code/keyword/rmp）是其固有难点，无更干净的原生替代。

### 2.2 真实权衡（两条线，非"免疫路径"）

低频崩发生在**运行期 B 进程的 codes-fast 线（RETAIN）**。两条产品候选线：

| 线 | 恢复机制 | 稳定性 | 恢复耗时 |
|---|---|---|---|
| **green-none（推荐产品基线）** | zo 重放供 code | **崩免**（15/15 净，本轮 clean binary 复验 11/11+12/12） | 慢：zo 重放是主成本 |
| codes-fast（RETAIN） | 内核 closure-fasl 单次读 code | **低频崩**（悬垂根，已定性未定精确写点） | 快：消 zo 重放 |

- green-none 崩免但恢复走 zo 重放（实验装置 mark→验收 ~158ms，含探针；`P33_PROBES=0` 文档投影 ~96ms，**产品端到端计时未独立复测**）。
- codes-fast 快但带崩。逆向抓精确写点非当前主线。
- **产品裁决建议**：先产品化 green-none 线（崩免、已验证），拿到真实 time-to-prompt；codes-fast 的崩当独立优化项，缓做。

## 三、最小正向步骤（M2，按澄清后架构）

已落地地基（committed）：M1 装置解绑（`P33_SP` 参数化）、`gen-seg4.sh`（build 期产段四件套，本轮 clean binary 复验 A/B 全绿）、`ci-seg4.sh` 分层看护、清场缓解 + 崩率哨兵。

正向小步（每步可独立验证，不重启大战役）：

1. **green-none 产品端到端计时**：改造 B 装载器走 `P33_PROBES=0` 计时模式，在产品式最小 harness 里测 boot→段读→重放/hooks→首 prompt 的真实 time-to-prompt，对 256ms 基线核账（验证文档 ~96ms 投影是否成立）。这是"该不该继续投产"的判据数字。
2. **段装载点定位**：确定 racket 启动序里第四段 fasl-read 的挂点（main.sps / startup），先走"空段/缺段=退回现状"占位，验证条件装载不影响默认路径（minimal/`-q`/非 REPL 场景零累）。
> 注：本节 M2 小步在 §四（实测分解）+ §五（优化杠杆）出来后已被细化，**以 §五.2 规划为准**（§四.4 结论修正了原"语言层 +80/xrepl +121"的成本框定）。

关联档案：[[racket-repl-startup-project]]（逆向排查全账 + 工具入口）、[[repl-startup-preinstantiate-plan]]（方案 A/B/C 裁决）、repl-startup-zoclo-design.md（zoclo 通道，已落地）、repl-startup-kernel-enhancement-plan.md。

## 六、逆向装置的处置

- 实验装置调试插桩（内核 4 文件 guard + experiments 两文件 valhunt/backref/reloc-coverage/VALPROBE）**已回退**（2026-09-17），产品树干净可 build。
- 装置本身（experiments/seg4，HEAD 24f4c5587b 归档态）保留为逆向排查记录 + 定位工具库；清场缓解在其中默认开，codes 线 5/6 满分 + 崩率哨兵护线。
- 若日后仍需精确写点：路径=GC 内核把 sweep 当前对象基址+type 穿进 empty-seg guard（重管线），或 valhunt 扩真 VM 根集。非当前主线。

## 四、启动开销测量分解（2026-09-17，clean binary，正向重测）

### 4.1 墙钟阶梯（best of 3，`/usr/bin/time`）

| 配置 | 墙钟 | 相对上一级 |
|---|---|---|
| kernel `-n -q`（空） | 30ms | — |
| `racket/base`（`-I base -e void`） | 90ms | +60ms |
| 全 `racket/init`（`-e void`） | 160ms | +70ms |
| `+ xrepl + expeditor`（模块 require） | 176ms | +16ms |
| **默认 REPL to-prompt**（pty，静默检测） | **220ms** | **+44ms** |

### 4.2 GC/进程（`-e void`）

| 配置 | proc | gc |
|---|---|---|
| racket/base | 90ms | 14ms |
| racket/init | 158ms | **40ms** |
| + require xrepl | 162ms | 38ms |

### 4.3 内部分解（`PLT_LINKLET_TIMES`，权威）

| 阶段 | kernel `-n -q` | racket/base | racket/init | + xrepl+expeditor |
|---|---|---|---|---|
| boot | 27 | 27 | 27 | 27 |
| read（load .zo） | 23 | 25 | **44** | **47** |
| — faslin-code | — | 16（4MB） | **33（8MB）** | **33（9MB）** |
| — faslin-literals | — | 5 | 5 | 7 |
| instantiate | 6 | 3 | **18**（1947×） | 23（2063×） |
| linklet total | 56 | 55 | 89 | 99 |

### 4.4 三个颠覆原规划的实测结论

1. **实例化本身便宜（18-23ms）。模块层主成本是 `faslin-code`：反序列化 1679-1789 个编译 code 对象（8-9MB）=33ms**，加上其垃圾触发的 GC（racket/init gc 40ms vs base 14ms=+26ms）。原文档"实例化产生垃圾→GC"的框定不准——真相是**code 反序列化 + 其 GC**。
2. **xrepl 模块 require 几乎免费（含 expeditor 仅 +16ms）**。文档"xrepl +121ms"实为 **tty prompt 建立**（本轮实测 ~44ms，比文档小）：expeditor 行编辑器 init、terminfo、interaction-info、首 prompt 渲染——运行期 tty 工作，非模块装载。
3. **可优化面 = racket/init+xrepl 层的 ~86ms**（read+instantiate+GC 增量），**不是 220ms 全量**。kernel+base 地板（~90ms）是运行时本体，段无法消。tty 建立（~44ms）另算。

## 五、优化杠杆分析与规划（正向，按杠杆/风险排序）

> ⚠️ 下表与 §5.1/5.2 是初版乐观估计；**§5.3 可行性探针已修正**（GC 非独立杠杆、green-none 不省 faslin-code、boot-embed 收益未验证）。**以 §5.3 为准。**

| # | 杠杆 | 消什么 | 风险 | 预估 to-prompt |
|---|---|---|---|---|
| 1 | **heap-state 第四段（green-none）** | racket/init+xrepl 的 faslin+instantiate+GC（~86ms）→ 段恢复 ~40ms | 低（已验证崩免 11/11+12/12） | ~114ms（-48%） |
| 2 | **编译代码进 boot 镜像**（新，比 codes-fast 低危） | faslin-code（33ms）+其 GC；code 入 static gen | 低（native `$make-boot-file`，无堆重锚=无悬垂根） | 与 #1 互补 |
| 3 | codes-fast 段（native code fasl 单读） | 段恢复的 code 反序列化（→~15ms） | **低频崩**（悬垂根，已停追） | ~89ms |
| 4 | tty prompt 建立（~44ms） | expeditor init/terminfo/首渲染 | 中（需剖析 tty 工作可预计算部分） | <80ms 的必要补充 |
| 5 | 段裁剪（5.078MB） | RSS/分发，**非延迟**（fasl-read 15ms） | 低 | 不影响 to-prompt |

### 5.1 关键洞察：两个可分离的成本，两条可分离的杠杆

- **faslin-code（33ms，反序列化编译代码）** ← 杠杆 #2（代码进 boot 镜像，像 expander 那样，crash-free）。
- **instantiate + 活 ns 状态（18ms + 垃圾/GC）** ← 杠杆 #1（heap-state 段）或就留着（instantiate 只 18ms）。

原工程把两者揉进一个"第四段"，逼出了 codes-fast 的堆重锚崩。**分离后**：#2 用 native 编译代码 boot（无崩）消 faslin-code 大头；#1 heap-state 段消 GC；两者都不必碰 codes-fast 的崩线。

### 5.2 规划（正向、小步、低危优先）

1. **验证杠杆 #2 可行性**：能否把 racket/init+xrepl 的 .zo 编译 code 打进第四 boot 文件（`$make-boot-file`，CS backend 的 .zo 本是 Chez 编译 code）。若可行=crash-free 消 33ms faslin+其 GC。**这是最高性价比的下一步探针**（低危、native、避开崩线）。
2. **green-none 段产品端到端计时**（原 M2-步1）：核实 ~114ms 投影，拿真实判据数字。
3. **tty prompt 剖析**：`PLT_LINKLET_TIMES` 已排除模块层；用相同法测 expeditor init 的 tty 工作，定 ~44ms 里多少可预计算/惰性化。
4. 组合评估：#2（-33ms）+#1（-GC）+#4（-tty 部分）叠加能否触 <80ms；决定是否值得碰 codes-fast 崩线。

**判据**：<80ms 若靠 #1+#2+#4（全 crash-free）可达，则 codes-fast 崩线永久搁置——这是本轮分析给出的最优路线假设（**推断，待 #2 可行性 + 端到端计时验证**）。

### 5.3 杠杆 #2 可行性探针结论（2026-09-17，实测+读源）

**探了什么**：racket/init+xrepl 的编译 code 能否 boot 驻留、避开 faslin-code（33ms）。

**实测发现**：
1. **GC 非独立杠杆**：`PLTDISABLEGC=1` 下 gc=0 但 proc 仍 ~160ms（默认 proc 164-186、gc 41）——GC 时间与生产性工作重叠，禁掉只省 ~10-20ms，非 40ms。原表格"消 GC ~26ms"高估。
2. **faslin-code=硬核**：`eval-from-bytevector`→`code-from-bytevector`→`load-compiled-from-port`（Chez 编译码装载），8MB 分 1679 code 对象 @~0.24GB/s=33ms。boot 装载 ~5x 快/字节（36MB@27ms=1.33GB/s，单流+static-gen 批放），但**该优势是否迁移到 boot-embed racket/base 未验证**（需改 cs 构建把更多编进 racket.so 或第四 boot 文件，实测）。
3. **`embedded-load`/`as-predefined?` 机制已存在**（`-Y` flag，`raco exe` 用）——但只免文件系统 .zo 解析，**仍 faslin code**，不免 33ms。
4. **green-none 不省 code 成本**：其 code 供给走 zo-replay/bdw-naming（实验 restore mark→验收 ~186ms，主项=externals 解析 93ms + hooks 39ms=命名装置，文档称产品期归 ~96ms **未净测**）。heap-state 段真正 crash-free 省的只有 instantiate（18ms）+特定 GC，**不含 faslin-code 大头**。

**修正后的判据**：
- 原"#1+#2+#4 全 crash-free 触 <80ms"是**乐观误判**。真相：faslin-code（33ms）是 crash-free 难消的硬核；green-none 省得少（~instantiate 18ms+），codes-fast 省得多但崩，boot-embed 省不省未验证。
- **决定性的便宜下一步 = green-none 产品端到端净测（P33_PROBES=0，最小 harness）**：它直接回答"green-none 到底省多少 / 是否 re-pay code 成本"，是判"该不该投产 heap-state 段"的关键数字。**在拿到这个数前，不宜投入 boot-embed 构建实验（重、且收益未验证）。**
- boot-embed（杠杆 #2）降级为"green-none 净测后、若仍差距大才做"的构建实验，非当前主线。

**一句话**：本轮探针把杠杆 #2 从"低危高性价比"重估为"收益未验证、需构建实验"；真正便宜且决定性的是先净测 green-none 的产品级 time-to-prompt。

## 七、fasl 处理本身的优化：vfasl（2026-09-17，实测）

用户方向：不折腾 code 放哪个容器，优化 fasl 处理本身。分析结论=**vfasl 是最大头且 crash-free 的杠杆**。

### 7.1 机制：为什么 boot 快 5×——不是容器，是格式

- `.zo` code 走 **per-object fasl**（`compile-to-port*` 写 `fasl_type_fasl`，装载 `load-compiled-from-port`→`faslin` 逐对象反序列化+分配）。
- boot 文件走 **vfasl**（build.zuo:655-657 `vfasl-convert-file` 把 petite/scheme/racket.boot 转 vfasl）：**预算好的内存镜像，装载=memcpy+重定位**（vfasl.ss 头注："creates an image of the memory that fasl_in would create"）。
- **装载器 `bv_fasl_entry` 已按流内类型字节分派 fasl vs vfasl**（fasl.c:526）——装 vfasl 无需改装载器。

### 7.2 实测（Chez scheme 直测 + boot）

| 量 | fasl | vfasl | 比 |
|---|---|---|---|
| 装载率 | 42-47ms / 6.2-9MB ≈ **0.15-0.19 GB/s** | boot 36MB@~27ms 相 ≈ **>1 GB/s** | ~**5-7×** |
| **体积** | vf.so 9.07MB / vf2.so 6.16MB | vf.vfasl **4.07MB** / vf2.vfasl **2.06MB** | **0.33-0.45×（更小！）** |

**关键纠正**：vfasl **更小**（33-45%），不是更大。原"size tradeoff"顾虑作废——vfasl 速度+体积双赢（体积小部分因 `vfasl-convert-file` 带 `fasl-strip-options` 剥调试信息）。

### 7.3 潜在收益 + 可行性门

- **收益**：faslin-code 33ms（racket/init 8MB）@ vfasl 率 → ~5-7ms，**crash-free 省 ~26ms**，且 .zo 更小（RSS/分发受益）。这是本工程找到的**最大 crash-free 杠杆**，且正是"优化 fasl 处理本身"。
- **可行性门（未验证，决定性）**：
  1. `.zo` 写侧改出 vfasl code——`$fasl-to-vfasl`（=`to-vfasl`，vfasl.ss:1104）已存在，对 code 对象产 vfasl bv。
  2. **装载侧：`load-compiled-from-port` 能否吃 vfasl code bv**——bare `load` 一个 vfasl 文件失败（"unexpected #<code>"，7.ss run-outer 顶层形式处理不认；但那是文件 `load` 路径，非 .zo 的 **bytevector** 路径）；**Racket .zo 走 bytevector 路径（`code-from-bytevector`），底层同一 `S_bv_fasl_read`→`bv_fasl_entry` 已分派 vfasl，大概率直接可读**——须直测。
  3. **外部引用解析**：单模块 vfasl code 的外部引用=library-entry/C-entry/symbol（vfasl reloc tag 支持，racket.boot 就引用它们）+ 自身字面量；跨模块引用走 linklet import 向量（instantiate 期传入，不烘进 code）——故单 linklet code 外部引用面在 vfasl 支持范围内。**不支持的边缘情形须回退 fasl**。
- **为什么 Racket 没做**（推断）：vfasl 机器+版本强绑（但 .zo 已机器绑）、跨模块引用边缘情形需回退、vfasl 组合约束（`installs-library-entry?`）、历史上 vfasl 为 boot 而加、无人推 .zo 化。

### 7.4 次要 fasl 杠杆

- **惰性/JIT-on-demand**：Racket CS 已有 `linklet-interpret-jitified`（部分 code 解释+按需 jit）；扩大按需面可减启动 faslin，但改行为面大。
- **并行 faslin**：337 bundle 可并行反序列化，但 CS 装载单线程，改动大。
- 均次于 vfasl。

### 7.4b 可行性直测结论（2026-09-17，已验证）

Chez 层直测（make-boot-file 同码两格式，真 boot 上下文装载）：6000 个过程（fasl 11.4MB / vfasl 3.85MB）。

| | 装载耗时（min of 6，减 petite+scheme 基线 20ms） | 体积 | 正确性 |
|---|---|---|---|
| fasl code | **60ms** | 11.4MB | g100 3 4=219 ✓ |
| vfasl code | **20ms** | 3.85MB | g100 3 4=219 ✓ |
| — | **3.0× 快** | **0.34×** | **vfasl 装载即运行、外部引用解析 OK** |

**已验证**：vfasl 编译码**装载正确且能跑**（外部引用=fx ops/library-entry/define 机器在 boot 上下文解析成功），**3× 快 + 66% 更小**。核心可行性（vfasl code 往返+运行）从"推断"升"已验证"。
- 保守取 **3×**（本码型；racket.boot 规模级 ~5×，真 .zo 估 3-5×）。
- **收益重估**：racket/init faslin-code 33ms @3× → ~11ms，**crash-free 省 ~22ms**（racket/init 160→~138ms；全 REPL 220→~198ms），且 .zo 更小。
- **仍待确认（Racket 集成面，非 Chez 面）**：①Racket .zo 走 `load-compiled-from-port`（bytevector 路径，非 boot 装载）能否吃 vfasl——底层同一 C 分派 `bv_fasl_entry`，大概率可，须直接喂 vfasl bv 验证；②linklet 的 import/export 结构在 vfasl 下保持（本测是 boot 顶层 define，非 linklet）；③不支持的边缘情形回退 fasl。

### 7.4c load-compiled-from-port 直测=vfasl 全链已验证（2026-09-17）

用 Racket .zo 装载**同一个原语** `load-compiled-from-port` 直测（Chez 层），6000 过程：

| 格式（经 `vfasl-convert-file ... '("petite" "scheme")`） | load-compiled-from-port 耗时（min of 6） | 体积 | 正确性 |
|---|---|---|---|
| fasl | **54ms** | 7.87MB | (k100 3 4)=207 ✓ |
| vfasl | **10ms** | 2.98MB | (k100 3 4)=207 ✓ |
| — | **5.4× 快** | **0.38×** | ✓ |

**关键**：**`.zo` 装载所用的确切原语 `load-compiled-from-port` 直接吃 vfasl 并正确运行**。之前 deps='() 失败=library entry 被当对象**含入**打断顶层序列；**deps='("petite" "scheme") 后 library entry 变引用，全链通过**（(hh)/(k100) 均正确）。**核心可行性全链已验证**（写 vfasl → load-compiled-from-port 读 → 运行），5.4× 快 + 38% 体积。

**收益再firm**：racket/init faslin-code 33ms @5.4× → ~6ms，**crash-free 省 ~27ms**，.zo 体积约 0.4×。

**剩余（有界工程，非可行性风险）**：
1. **linklet import/export 结构**：真 .zo 是 linklet（带导入导出编译结构），非顶层 define；须确认 vfasl 保 linklet 结构（但**贵的是 code faslin，正是 vfasl 加速的**；linklet 元数据小）。
2. **构建集成**：让 `compile*-to-bytevector`/.zo 写侧出 vfasl code——需 code bytevector 版的 `$fasl-to-vfasl`（`vfasl-convert-file` 现是文件→文件），或 .zo 后处理。
3. **deps 集**：vfasl 须知哪些 library entry 外置=运行时的 petite+scheme+**racket**（本测只用 petite/scheme entry，真 racket/base 还用 racket.boot entry，deps 加 "racket"）。
4. 跨模块引用边缘→回退 fasl。

### 7.4d linklet 结构与 literals（2026-09-17，验证）

读 linklet.sls + 直测：

**linklet 记录**（linklet.sls:522）字段 = `code`（procedure 或 code bytevector）、`literals`（单独的字面量向量，racket/fasl 序列化）、format、importss/exports 等元数据。**code 只经 `wrapped-code-content`(bytevector) → `code-from-bytevector` → `load-compiled-from-port` 装载**，别处不碰其格式。→ **code 的 fasl/vfasl 格式对 linklet 层透明**；linklet wrapper（导入导出/元数据）格式无关。

**literals 直测**：含嵌入字面量（字符串/list assv-memv 表/符号）的 code 经 vfasl 往返正确：`(describe 2)="two" (describe 20)="round" (describe 99)="other"`。→ **literals 可嵌入 vfasl 镜像**（linklet 的 `literals` 单列向量可改为嵌入 vfasl，或验证 `load-compiled-from-port bv literals` 的 vfasl+外部 literals 路径）。

**体积阈值（重要 tradeoff）**：vfasl 有固定开销（头/reloc 表/连续布局）——大 code 7.87MB→2.98MB(0.38×)，但**小 code 1847B→4188B(2.3× 更大)**。→ 小 linklet vfasl 会**变大**；需**体积阈值**（只 vfasl 大 linklet）或**合并**（多 linklet 组一个 vfasl，摊薄固定开销——vfasl 本就支持组合）。startup 关键路径的大模块（racket/init 8MB code）正是 vfasl 受益区。

**linklet 结构可行性小结**：code 格式对 linklet 透明✓、literals 可嵌 vfasl✓、大 code 速度+体积双赢✓、小 code 需阈值/合并。核心机制全验证，剩写侧集成。

### 7.4e 精确转换配方 + 集成边界（2026-09-17）

**mimic 直测（compile-to-port 走 linklet 形状 lambda）**：
- compile-to-port 原始输出 **vfasl 拒绝**（"unsupported code-info"——含调试/源信息）。
- 加 **strip-fasl-file**（`inspector-source source-annotations profile-source compile-time-information`）后 vfasl 通过，(proc 10 4)=33 两格式一致 ✓。

**精确转换配方**（linklet.sls 集成用）：
```
compile-to-port → strip-fasl-file(去 code-info) → vfasl-convert-file(deps petite+scheme+racket) → load-compiled-from-port ✓
```
- 转换原语 `vfasl-convert-file`/`strip-fasl-file` 在 linklet.sls 可用（imports (chezpart)=全 chezscheme）；但**文件版**，in-memory 需 port 版内部（`read-and-strip-from-port` 等，未干净暴露）。

**集成边界（为何停在此，不盲目重建 racket.boot）**：
1. **写侧改 compile*-to-bytevector（linklet.sls:394）+ 重建 racket.boot**：改核心运行时，~15min 构建，有破坏风险；需处理 (a)strip 去调试信息(丢 raco decompile)、(b)外部 literals(linklet 单列 literals 向量 vs vfasl，未验证外部-literals+vfasl，安全做法=有 literals 回退 fasl)、(c)build-vs-runtime 门控(运行期 eval 编译不该 vfasl)、(d)temp-file vs in-memory(并行 raco make temp 冲突)。
2. **.zo 后处理（exposed linklet API）**：`linklet-fasled-code+arguments` 暴露 code，但 `set-linklet-code` 内部、code 字段回写不干净暴露。

**两条都是核心运行时工程，非快探针。可行性已锤实，产品化是有计划的下一工程。**

### 7.4f 外部 literals 验证（2026-09-17，关键约束）

用户要求的低风险 Chez 层验证。直测三种情况：

| 情况 | 结果 |
|---|---|
| fasl + 外部 literals（`compile-to-port` 带 external?-pred，`load-compiled-from-port bv literals`） | ✓ `(99 "alpha" "beta")` 正确 |
| **vfasl + 外部 literals** | ✗ **`vfasl-convert-file` 拒绝**："incompatible external vector in bytevector"——**vfasl 与外部-literals 机制不兼容**（连 strip 也拒："incompatible external vector"） |
| **vfasl + 嵌入 literals**（`compile-to-port` **无** external?-pred，debug 关） | ✓ `(9 "alpha" "beta" (1 2 3))` 正确，**且无需 strip** |

**关键发现（修正 §7.4e 的 strip 结论）**：
1. **vfasl 不支持外部 literals**（external vector）。linklet 的 `literals` 单列向量若非空，**不能 vfasl**。
2. **嵌入 literals + vfasl 可行**，且 **debug 关（`generate-inspector-information #f`/`generate-procedure-source-information #f`）后无需 strip**（code-info 根本不产生）——比 §7.4e 的配方更干净。

**干净配方（修正版）**：
```
compile-to-port(debug 关, 无 external?-pred=嵌入 literals) → vfasl-convert-file(deps petite+scheme+racket) → load-compiled-from-port ✓
```

**真实约束（vfasl 覆盖面）**：
- 外部 literals = **paths**（必须外置=可移植/重定位）+ srclocs（debug，生产关）。
- → **只有无外部 literals（无 path 字面量）的 linklet 能 vfasl**；带 path 字面量的 **回退 fasl**（安全）。
- **覆盖率待测**：真 racket/base .zo 里多少 linklet 无外部 literals=vfasl 可覆盖面。这是决定 vfasl 收益覆盖度的关键数字。

**集成裁决**：env-gated，`literals` 空时 vfasl（debug 关）、非空回退 fasl——安全、无需 strip、无兼容风险。收益覆盖 = 无外部 literals 的 linklet 占比（待测）。

### 7.4g 扩展 vfasl 支持 externalref：可行性 + 覆盖率裁决（2026-09-17）

**用户问：有没有考量扩展 vfasl 支持外部 literals。答：可行，且覆盖率分析表明"扩展是必要的、非可选"。**

**A. 扩展可行性（照 vfasl 现有模式复制）**：
vfasl 装载器（vfasl.c）已用"偏移表"解析 **4 种外部引用**（C-entry/library-entry/symbol/singleton）：`singletonref[i]`/`symref[i]` 指向镜像槽存索引，装载时 patch 成解析结果（`*ref = lookup_singleton(...)` / interned symbol）。**外部 literals = 第 5 种，源是 per-linklet 的 externals 向量**。关键：`bv_fasl_entry` 已拿到 externals（fasl 路径在用），只是 **vfasl 路径 `S_vfasl(bv,f,offset,len)` 丢弃**（签名不带 externals）。改动 5 处：①cmacros.ss 加 `vfasl-reloc-external-tag`（3-bit tag 用 6 剩 2）+ header externalref-count；②strip.ss:287 `fasl-type-graph` 处放行外部引用（现拒绝）；③vfasl.ss 编码器发 externalref 表项；④vfasl.c 给 S_vfasl 加 externals 参数 + externalrefs 表（照抄 singletonref 循环，`*ref = Svector_ref(externals, i)`）；⑤fasl.c/externs.h 改签名穿 externals。**构建=改 Chez 核心 + 重建 petite/scheme.boot**（比 racket.boot 更底层）。

**B. 覆盖率裁决（源码级，比计数更权威）**：
`register-literal-serialization`（schemify/literal.rkt）定 code 外置哪些 quoted：
- **嵌入（不外置）**：数/字符/布尔/null/eof/void/interned-symbol。
- **总是外置**：**gensym**（"须暴露给整个 linklet directory"=跨 linklet 身份共享）、**hash**、srcloc、prefab-key、**`[else]` 兜底**（path/regexp/keyword/byte-regexp/extflonum/任意结构常量）。
- **datum-intern? 时外置**：**string/bytes**（默认多为开）。
- pair/vector/box：含外置元素则外置。

→ **外部 literals 是常态**：任何 linklet 有 hash / interned string / keyword / regexp / gensym / path 常量就有外部 literals=多数非平凡 linklet。**回退方案覆盖率低**（多数回退 fasl，vfasl 收益微）。**嵌入方案不安全**：gensym 嵌入破坏跨 linklet 身份、path 嵌入破坏可移植性。

**C. 裁决**：**扩展 vfasl externalref 是让这条杠杆广覆盖且正确的必要手段**，不是可选优化。回退/嵌入都有硬限制（覆盖率低 / 破坏 gensym 身份+path 可移植）。**测覆盖率的计数被 exposed API 挡住（linklet-fasled-code+arguments 未surface 到 Racket），但源码级结论更强=外部 literals 常态。**

### 7.4h vfasl externalref 扩展的影响面 + 自举兼容性（2026-09-17）

**一次性重建影响面**：
1. 改 cmacros.ss（加 reloc tag + header externalref-count）→ cmacros 到处 include → **全 Chez 重建 + 所有 vfasl boot 重生成**（常规后果）。
2. **fasl 格式零改动**（只碰 vfasl 编码器/装载器/strip graph 处理/S_vfasl 签名）→ 中间 fasl boot、所有 .zo（fasl）照旧装载。
3. vfasl 格式变（header 布局）→ petite/scheme/racket.boot（都 vfasl）重生成；native clean rebuild 里新编码器（build.zuo:61 用**新建 scheme**）↔ 新 loader 自洽。
4. **版本防护**：`scheme-version=#x0a050001`（cmacros.ss:360），boot header 带版本、装载查兼容。**bump 它** → 旧格式 vfasl boot 被新 binary 装载时版本不匹配**响亮失败**（"cannot find compatible boot file"），而非静默错读 header 偏移。
5. 风险：增量复用旧 vfasl boot（clean 重生成解）/预置 racket.boot（随版本重生成）/cross 编译（host+target 都改；native 无此问题）。

**自举兼容性（战略结论：不需要定制自举/定制最小运行时，与上游兼容）**：
- 项目**本就从 vendored 源码建 Chez**（racket/src/ChezScheme）；我的改动=这份 vendored Chez 的一个本地 patch，与既有 Chez patch（prim5.c 等）同性质。
- Chez 自举**自宿主多阶段**（BUILDING）：`make` 建新 boot→用新 boot 建更新一套→比对；**最终 boot 由完全-新系统产出**，格式变化天然吸收。
- Chez 有 **`re.boot` / `reboot.ss`** 机制，明确为"**C 侧与 Scheme 侧不同步**"（正是改 vfasl.c+vfasl.ss）和"从**实质不兼容版本**自举"设计——上游标准工具、非定制。
- **最小运行时 pb boots 上游兼容、零改动**：pb=machine-independent 输入编译器，**vfasl=机器相关内存镜像、pb 不用 vfasl**（互斥）；改的是 native vfasl **输出**，不碰 pb 输入。
- schemified/expander=格式无关可读源，被新 Chez 编译进 racket.boot（新格式），源不受影响。

**唯一长期代价**：vendored Chez 多一个本地 patch（随上游 Racket 更新 rebase，项目已在做）+ 建议 bump scheme-version。**自举流程、最小运行时拉取、configure 路径全照旧。**

| 维度 | 需定制? |
|---|---|
| 自举流程 / configure | 否 |
| 最小运行时（pb boots） | 否（上游兼容、非 vfasl） |
| boot 重生成 | 自动（多阶段 + re.boot） |
| schemified/expander | 否 |
| vendored Chez 维护 | 是（既有，多一 patch rebase） |
| 版本 bump | 建议 |

### 7.5 下一步（正向、决定性、便宜）

**可行性已全链验证**（§7.4b/c/d）。剩下的是**构建集成**（有界工程）：
1. **写侧出 vfasl code**：`compile*-to-bytevector`（linklet.sls:394）现产 fasl code bytevector；需产 vfasl——用 code bytevector 版的 `$fasl-to-vfasl`（系统原语存在，需在 linklet.sls 内调用）或后处理。deps 集含 petite+scheme+**racket**。
2. **literals 策略**：嵌入 vfasl（已验证可行）或验证 `load-compiled-from-port bv literals` 的 vfasl 外部-literals 路径。
3. **体积阈值/合并**：只 vfasl 大 linklet，或合并小 linklet 摊薄固定开销。
4. **端到端量**：改 racket/base 或 racket/init 的 .zo code 出 vfasl，量 startup faslin-code 降幅（预期 33ms→~6ms）。
5. 跨模块引用边缘→回退 fasl。

**修正后的下一步（§7.4g 覆盖率裁决后）**：外部 literals 是常态→回退/嵌入覆盖率低或不安全→**vfasl externalref 扩展是必要前置**。故真正的 M2 顺序：
1. **扩展 vfasl externalref**（Chez 核心 5 处改 + 重建 petite/scheme.boot），照 singletonref 模式；env-gated，先 gate-on 时 vfasl+externalref、off 时现状。
2. 验证 externalref 往返（externals 向量装载时正确 patch）——Chez 层直测，重建后。
3. linklet.sls 写侧 compile*-to-bytevector 出 vfasl（externalref 版），量单 collection startup faslin-code 降幅。
4. 全 racket/base+init .zo vfasl 化，端到端量 to-prompt。
5. 边缘/失败回退 fasl（护栏）。


### 7.5b M2-步3 实测(2026-09-29,per-linklet vfasl 已落地,env-gated)

管线已落地(`PLT_LINKLET_VFASL` 门控,默认关):writer GOT-gate(`$fasl-to-vfasl` 第二参,boot 转换开、.zo 关=P2.2a in-object 语义,绕开 gen0 abort)、strip.ss 新原语 `$vfasl-convert-bytevector`(in-memory,复用 read-and-strip-from-port)、linklet.sls `compile*-to-bytevector` 出口转换+guard 回退 fasl。读侧零改动(`load-compiled-from-port` C 层自动分派,externals=linklet literals 经 fasl2 externalref 解析)。

**实测(racket/init 闭包 259 模块重编,fallback-root 交替 A/B)**:
- 全链正确:vfasl root 启动+运行、跨进程加载、外部 literals(hash/string)解析、basic.rktl 全过。
- faslin-code:median 22.5→16.5ms(**1.36×,非文档预期 5.4×**)。
- **端到端启动:169→160ms(−9~10ms,min/mean 一致)**——超相位差,vfasl 免中间垃圾的 GC 增益。
- 体积:.zo 14→31MB(2.2×)。

**§7.5 预期修正(关键)**:5.4× 只在**单个大镜像**成立;真实 .zo 粒度=1294 个多为小 code 对象,每 vfasl 镜像固定成本 ~10µs 吃掉大半(1294×10µs≈13ms)。字节分布平(top10 zo 仅占 20%)→ **阈值路覆盖率低;逼近 5× 的正路=合并**(bundle/模块级多 linklet 共一个 vfasl 镜像,摊薄固定开销+消体积膨胀),属 linklet 序列化层工程。当前 per-linklet 形态可作为 env-gated 小收益(−9ms)保留。

**风险/成本**：改 Chez 核心运行时（vfasl.c/vfasl.ss/cmacros/strip.ss/fasl.c）+ 重建 petite/scheme.boot，是本工程最深的一层改动；但收益=faslin-code 5.4× 广覆盖、crash-free、.zo 更小。可行性/模式已锤实，是有计划的核心工程。
