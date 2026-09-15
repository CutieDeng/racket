# H：REPL 启动提速——性能分析技术与归因计划

2026-09-05 · 目标 time-to-prompt <50ms（对标 python3）· 原则=正向定位，只删可归因的不必要计算

## 一、分析技术清单（本阶段建立的工具箱）

| 技术 | 用途 | 状态 |
|---|---|---|
| `PLT_LINKLET_TIMES=1` | 进程级分解：boot/read(fasl)/instantiate/compile/GC | ☑ 现成，第一手段 |
| `PLT_LINKLET_SHOW=1` + grep `compile-linklet:` | 抓启动期**现场编译**的 linklet 名单（本应为零） | ☑ 现成 |
| `PLT_COMPILED_FILE_CHECK=exists` | 排除 mtime 假陈旧污染；亦是对照组（stat 检查成本） | ☑ 现成 |
| pty 真提示符计时（`ttp.py`，min-of-12） | 端到端 time-to-prompt，唯一能触发 expeditor/终端路径的量法 | ☑ 已建 |
| load-handler 打点树（`load-trace.rkt`） | 模块**装载**耗时树 | ☑ 已建；**盲区=实例化**（见下） |
| linklet 级 trace（`cs/linklet/trace.ss`） | 逐 linklet read/instantiate 打点带名字 | ◐ 树内有阀无表——**下一步接上调用点**（env 门控零常开成本） |
| macOS `sample`/Instruments | C/Chez 层（boot 装载 34ms 内部）采样 | ☐ 按需 |

**已知量法陷阱（实测）**：①worktree 分支切换刷新源 mtime → zo 假陈旧 → 静默转源装载+现场编译（最小启动 88→183ms，+95ms；**开发流程自伤**，量前必查或用 `=exists`）；②load-tracer 只见 load 不见 instantiate（init 层 110ms 仅 ~20ms 是装载）；③xrepl 重头非 pty 不触发，无 pty 的复演会漏掉整个 expeditor/终端初始化。

## 二、真基线（2026-09-05，无污染，min-of-12 全 wall）

| 配置 | ms | 层增量 |
|---|---|---|
| `racket -q -n -i`（裸 REPL） | **46.7** | 基底——**已低于 50ms 目标线** |
| `racket -q -i`（+racket/init 语言） | 123.7 | **+77.0** |
| `racket` 默认（+xrepl/expeditor） | **227.9** | **+104.2** |

（首轮 54.1/138.7/267.9 系 setup 未完成期测得；树净后整体再降 ~15%。最小 `-e` 树净值 90ms=read39[GC11]+boot33。）

最小 `-e '(exit)'` 进程分解（`=exists`，88ms [内含 GC 37ms]）：read(fasl) 43 [GC 36]、boot 34、instantiate 11。**GC 几乎全部由 fasl 物化引发**。

## 三、发现与线索

1. **两座大山结构未变**（与旧阶梯同构）：racket 语言层 +85、xrepl 层 +129；裸 REPL 54ms 已在目标门口 ⇒ 路线仍是 **prompt-first 延迟加载**（先出提示符，语言/交互层后台/首键补齐）。
2. init 层的 85ms 主体是**实例化而非装载**（装载树只占 ~20ms）⇒ 优化面在"哪些模块的 body 在跑什么"，需 linklet 级 trace 落地后归因。
3. read 43ms/9MB/356 bundle + 其引发的 36ms GC：候选=按需读 bundle、初始堆调参、bundle 瘦身；须逐模块归因后动手。
4. 开发流程守卫：mtime 假陈旧应有防线（量测脚本内置 `=exists` 对照；或 setup 后快照校验）。

## 四、下一步（顺序）

1. **linklet trace 落地**：给 `trace.ss` 接 read-bundle/instantiate/compile-linklet 调用点（带模块名，`PLT_LINKLET_TRACE_TIMES` 门控）——补齐实例化盲区，产出逐模块耗时树。
2. 用 1 归因两座大山内部 Top-N，圈定 prompt-first 的"必须先行"最小集。
3. pty 变体下归因 xrepl 层（expeditor/终端初始化/键表）。
4. 设计 prompt-first 方案（提示符前最小集 + 余量延迟/并行），性能红线=首键响应无感。

## 清单实验裁决（2026-09-05，工具=PLT_VFASL_STATS，已入树 `ef6bf14ea6`）

启动物化全景：116 个 vfasl 块 / 52.9MB（纯 Chez boot 走普通 fasl 零块——vfasl 仅存在于 racket 三件套）：

| vspace | MB | 占比 | 性质 |
|---|---|---|---|
| **code** | **24.94** | **47.2%** | 机器码——**可 dylib 化（AOT 进 .text，pbchunk 思路）** |
| data+impure+pure-typed+records | 21.2 | 40.1% | 真对象图——只能靠分层懒装砍 |
| reloc | 4.28 | 8.1% | 重定位表，主要服务 code，boot 模式装完即弃 |
| symbol | 2.16 | 4.1% | 每进程须 intern |

**裁决**：code+reloc ≈ 55% 的物化量可被"代码段进 .text 共享"路线消除 → boot 31ms 理论下探至 ~14-17ms，裸 REPL 全程 ~30ms 量级；叠加对余下 21MB 对象图的分层懒装可再进。两条路正式立项顺序：①code 段 dylib 化 spike（先在 pbchunk 现有机制上找 native 后端等价物）②对象图分层。远期档：save-startup-image（受限挂起点，见讨论记录）。

## 物化路径微观归因（2026-09-05，工具=PLT_VFASL_TIMES 相位计时，未提交）

vfasl 装载 21ms 相位表：**room+copy 13.7**（内拆：find_room 0.1 / memcpy 0.0 / **S_fasl_bytesin 流读 ≈9.4** + 段页首触杂项 ~4）、ptr-sweep 2.9、relink-code 2.8、intern-syms 1.2、其余 <0.5。两大预判（sweep 线性查表、relink 逐对象 icache）全被数据推翻——**真热点是把 53MB 从文件流搬进新 GC 段页**。

判定实验：热页缓存纯读 55.9MB 仅 **2.31ms** ⇒ 9.4ms 里 ~7ms 是"read 进新匿名页触发的 zero-fill 缺页+内核拷贝"复合，非读带宽。

**动刀清单（技术细节级，不动格式/原理）**：
1. **mmap→bv 路径切换**（首刀）：boot 打开处 mmap 整文件，用现成 `S_fasl_init_bv` 形态喂装载——消灭 ~700 次 read syscall 与内核→用户拷贝；预期 9.4→5-6ms。vfasl 的 bv 分支已存在，改动集中在 scheme.c 的 boot 打开与 seek 逻辑。
2. **ptr-sweep 局部性游标**（次刀）：`find_pointer_from_offset` 每指针从 s=0 线性爬 9 空间 → 记忆上次命中空间先试，预期 2.9→~1.5。
3. 深水备选（动格式，先不做）：to-vfasl 各 vspace 页对齐 + mach `vm_remap` COW 零拷贝零 fault（9.4→~1-2ms 级）。

## 第一刀落袋（2026-09-05，`feat/repl-startup-analysis` 分支三提交）

`ef6bf14ea6` STATS 插桩 / `75ce6ff1ff` TIMES 相位插桩 / mmap boot 装载。**裸 REPL 46.7→40.8ms、默认 227.9→200.9ms、room+copy 13.7→8.4ms**；回归 rktl×2 全过。行为差异按设计：截断文件仍走内存源边界的 eof 报错（非 SIGBUS）、WIN32/映射失败回退流式、装载毕 munmap。下一步：写触页统计实验 → 裁决第二/三层（vspace 页对齐 + MAP_FIXED|PRIVATE remap 的空间选择）；以及 sweep 局部性游标（现 3.8ms）。

## 写触页普查裁决（2026-09-05，工具=PLT_VFASL_WRITES，未提交）

装载后各空间写触页率：**data 0.0%（2788 页/11MB）、reloc 0.0%（1154 页/4.5MB）**、code **99.7%**、其余 95-100%。

**第二层形态定案（混合式）**：
1. **data 空间 remap**：to-vfasl 仅需对 data 空间页对齐（格式扩展最小化）+ 装载端 `MAP_FIXED|PRIVATE` 接页 → 省 11MB 拷贝+zero-fill（≈2ms）
2. **reloc 免物化**：sweep/relink 改为直接从 mmap 区读 reloc（boot 模式本就装完即弃）→ 省 4.5MB 搬运（≈1ms）
3. **code remap 死刑**：99.7% 写触（reloc 点铺满页）——vm_remap 深水估计对 code 无效；code 的 25MB 出路只在架构层（少装/AOT 进 .text）。微观优化地板由此可算：room+copy 8.4→~5.5、加 sweep 游标（3.8→~2）→ vfasl ~15ms、**裸 REPL ~37-38ms**。破 30 必须回架构层。

踩坑记：写点插桩遇 `if` 无大括号体（rtd_parent 赋值变无条件→"incompatible record type"装载即坏）——**单语句 if 体前插桩必须补括号**。

## 测量方法论修正（2026-09-06，重要）

**wall 口径日间漂移 ±10%**（同一已提交态跨时段 40.8 vs 45.3/46.3）——跨时段 wall 比较作废；可靠口径=同时段 A/B 对照 + PLT_VFASL_TIMES 内部计时。据此修正：mmap 刀 wall 真实收益 ~1-1.5ms（内部口径 room+copy 13.7→8.4 仍可信）；`a77d3fe584` 提交信息中 46.7→40.8 的表述偏乐观。零拷贝实验（stash 恢复中，reloc-only 形态）：内部口径 −1.4ms 真实小赢、data 版近中性；此前"负 5ms"判定同为漂移假象。健全性交由三路 subagent 审计（GC 非段指针/vfasl 空间语义/运行时遍历器），审计+净值合议后定落地形态。

## 设计评审结论（2026-09-06，三路 subagent 审计合议）

**评审对象**：boot 装载零拷贝（data/reloc 空间指向常驻映射）。三路并行审计：A=GC 非段指针容忍性、B=vfasl 空间语义与生命周期、C=非 GC 运行时遍历器。

**裁决**：
- **reloc-only：通过，落地**。三审一致：语义与原实现等价（relink 后 CODERELOC 全部清零或指向 GC 管理的新拷贝，堆内零存活映射引用）、GC/运行时零涉及、条件耦合正确（to_static && !retain_static_relocation）。净值 −1.4ms（内部口径）。
- **data 空间：否决（现状），完备加固清单入档**。必崩点：sweep_stack 的 livemask **bignum** 走裸 SegInfo（mkgc.ss:1065——bignum 恰在 data 空间；实验未炸系当前 boot 无该形态的运气）、gc-par 记录 pm bignum（mkgc.ss:856）、S_dirty_set 的 use_marks 值查找（alloc.c:403，guardian rep 链）；另有打印器 `#<foreign>` 必现语义错误（print.ss:647 经 s_ptr_in_heap）、compute-size-increments/count-roots 裸 SegInfo、可变字面量 SIGSEGV 残余（vfasl.ss:637-653）。修复面 ~8 处 vs 净值近中性——性价比不成立。若未来 code AOT 化令页共享成为组合收益，此清单即施工图。
- **先例论据纠错**：singleton 不是段表外内存（受保护根管理的堆内对象）；正确先例=ephemeron 非可收集键（gc.c:2819 显式注释）+ foreign reference + MaybeSegInfo 守卫主干。vfasl.c 注释已随 reloc-only 提交改正。
- **红线**（写端不变量，任何 vfasl.ss 改动须重审）：映射区只能承载无指针纯数据；data 空间类型清单=flonum/inexactnum/string/flvector/fxvector/bytevector/bignum。

# 性能优化方法总目录（2026-09-06 汇总，随进展更新）

## 已实现（`feat/repl-startup-analysis` 四提交）

| 方法 | 提交 | 效果（内部口径） |
|---|---|---|
| mmap boot 装载 + madvise 预取（消 read syscall 与内核拷贝） | `a77d3fe584` | room+copy 13.7→8.4ms |
| reloc 空间零拷贝（留在映射区、装载后零存活引用，评审通过） | `5fd0bd54a5` | room+copy 8.4→6.2ms |
| 分析工具三件：PLT_VFASL_STATS / TIMES / WRITES | `ef6bf14ea6`/`75ce6ff1ff`/`5fd0bd54a5` | 归因基建（空间尺寸/相位耗时/写触页普查） |
| ptr-sweep/relink 空间查找局部性游标 | （本提交） | sweep 3.1→2.73、relink 3.1→2.63 |

累计：vfasl 装载 21→~16ms；裸 REPL 稳态 ~45ms（wall 口径 ±10% 日漂移，跨时段勿比）。

## 待实现——微观层（不动架构）

1. ~~ptr-sweep 局部性游标~~ **已实现**（见下表新行）：sweep 3.1→2.73、relink 3.1→2.63（游标同时覆盖两条热径）；命中率低于预期（目标空间交错度高），收益 −0.9ms 真实稳定。
2. relink-code 内部再归因与批量化：3.1ms 未细拆（逐 code object 逐 reloc entry；候选=entry 解码内联、跨对象批处理）。
3. bitmap sweep 零字快跳（64-bit 字读 + ctz）：data/reloc 位图尾零已被写出端裁剪，剩余区位密集，观察级收益。
4. intern-syms（1.2ms，符号表哈希/锁）：观察级。

## 待实现——架构层（按收益排序）

5. **code AOT 进可执行 .text 段**（25MB/47% 物化量；写触 99.7% 判死 remap 后的唯一出路；`bootpbchunk` 为 pb 后端先例，需 native 等价物）——boot 31ms 理论砍半的主通道。
6. **racket.boot 对象图分层懒装**（data+impure ~21MB：expander 全量/schemify known 库等按"提示符前最小集"拆分）。
7. **collects 层 prompt-first 延迟加载**：racket 语言层 +77ms（主体=实例化非装载）、xrepl/expeditor 层 +104ms——默认体验逼近裸 REPL 的主战场；需 linklet 级 trace（trace.ss 有阀无表）补实例化归因。
8. save-startup-image 受限挂起点（远期档，见讨论记录）。

## 已否决（评审在案，勿重启除非前提变化）

- **data 空间零拷贝**：GC 必崩点（livemask bignum 等裸 SegInfo ~8 处）vs 近零净值；加固清单在"设计评审结论"节，若 code AOT 使页共享成组合收益可凭清单重启。
- **vm_remap code 页**：写触 99.7%，COW 必负。
- **嵌入式 boot（boot.o）**：与外部文件同速，IO 非瓶颈。
- zygote/常驻预热：违背"无后台"红线。

## 两座大山的模块级账单（2026-09-06，工具=linklet instantiate trace，未提交）

**racket/init 层**（1791 次实例化，自含合计 90.7ms）top：`define-struct.rkt` **14.0**、**语法字面量支撑 linklet 合计 ~29.5**（syntax-literals-data 12.2 + decl 11.3 + data 4.8 + syntax-literals 1.3——.zo 内部段，语法对象反序列化的隐形大头）、`system.rkt` 6.5、`dict.rkt` 5.2、contract 家族 ~6、`kw.rkt` 2.1、自家 `pvector-runtime-adapter` 1.3。

**xrepl 层增量**（无 tty 口径，自含 ~74ms）top：**`tstring.rkt` 28.7 + `tstring-reader.rkt` 3.4 ≈ 32ms（自家工程，头号单项）**、`struct-dc.rkt` 20.8（contract 结构合约——牵连方待查）、`main.rkt` 8.7、`class-internal.rkt` 5.4、`xrepl.rkt` 本体仅 2.6。

**prompt-first 可执行清单（由账单裁定，按收益排序）**：
1. **tstring 交互挂载延迟化**（~32ms）：交互信息/reader 延迟到首个 t-string 触发——纯自家改动，最大单笔。
2. struct-dc/contract 链归因（20.8ms）：查引入方（疑 tstring/xrepl 依赖），能斩依赖则连带消失。
3. 语法字面量 29.5ms：架构级（.zo 语法对象反序列化惰性化——上游已有 lazy syntax 机制？待查 racket 的 deserialize-syntax 延迟开关）。
4. define-struct.rkt 14ms：body 在跑什么（struct property/guard 初始化）待细看。

工具注记：instantiate trace（linklet.sls，PLT_LINKLET_TRACE_TIMES 门控）已实现未提交；无 tty 口径缺 expeditor 部分，pty 版待补。


## prompt-first 首刀 + 归因假象纠错（2026-09-06，baa2cdd2c3 trace 工具 / <本提交> tstring 惰性化）

**归因假象**:instantiate 迹线聚合器把"父 body 内 dynamic-require 的子"算进父的 elapsed——"tstring 32ms"实为 tstring 自身 1.5ms + 它 dynamic-require 的 xrepl 子树(xrepl 本体 16.5 + struct-dc 20.8)。**自含时间(elapsed − 子时间)才是归因量**,已写入 trace 工具提交与本记录。

**tstring reader 惰性化**:交互 reader 装载(reader + tstring bindings 命名空间导入)推迟到首次交互;xrepl 加载是 REPL 必需、不可延迟(账单已证)。同时段 A/B:默认 REPL 192-196 vs 对照 205,**−10ms 真实**(超噪声)。功能:首行即 t-string 正确(pty 验)、交互三例回归过。

**修正后的 prompt-first 认识**:xrepl 本体(~17ms self)+ struct-dc(20.8)是 REPL 必需核心,不可延迟;可延迟的只是"非首屏必需的挂载"(tstring reader 属之)。清单第 2 项 struct-dc 归因随之降级——它是 xrepl 依赖,除非改 xrepl 本身否则搬不走。真正剩余大头回到架构层(语法字面量 29.5 惰性化、code AOT)。

## xrepl/expeditor 加载优化（2026-09-06，进行中）

**归因(subagent)**:xrepl 净增量 ~72ms 中,自身惰性化已极致(命令全 defautoload、不用 contract),**65% (~27-34ms) 是 expeditor 行编辑器**(expeditor/main.rkt 顶层构建按键分派表)。contract/class 非靶点(与 racket/init 共享,已加载)。

**已实现·terminal-port? 门(非 TTY 无损跳过)**:xrepl.rkt make-xrepl-reader 的 expeditor `dynamic-require` 前加 `(terminal-port? input)`+`(terminal-port? output)`(对齐 expeditor init-screen 的判断)。管道/脚本/CI 下不再加载 expeditor,省 ~27ms。实测:管道 exp-loaded #f、pty eval 正常。**局限:仅惠及非 TTY 场景;交互 TTY 首屏 expeditor 必需,不受影响**。**落点问题:改的是 racket/share/pkgs 安装副本(git 未追踪,xrepl-lib 是 catalog 外部包)——需 vendor xrepl-lib 进 fork 或提上游 PR 才能持久化**。用户已定:未来将 xrepl-lib 引入语言中维护。

**交互首屏靶点·expeditor 27.2ms cold load**:确定成本,TTY 场景也付。可优化性(keymap 惰性构建/预序列化 vs 首屏必需)深挖中(subagent aef...)。若可惰性/预计算→交互 205ms 可降;若首屏刚需→只剩 boot 内置(移 build 期)或 D 形态(plain-first 升级,有割裂风险)。

## 启动期 GC:交互 REPL 剩余最大杠杆(2026-09-07)

**发现(纠 expeditor 假象后的真靶点)**:默认 REPL 102ms 里 **~47ms 是 GC**;GC 阶梯——裸 REPL +0、+racket语言层 +30、+xrepl +47。裸 REPL 分配不够零 GC;racket/init 加载分配 ~6MB 跨过 `collect_trip_bytes`(alloc.c:209,gen-0 自上次 GC 分配量阈值)触发 major 收集,落在 time-to-prompt 关键路径。**这次 GC 收的是 boot 垃圾(reader/expander/-e 编译残渣),非用户垃圾**;推迟它不改语义,只把 ~30-47ms 移出首屏。

**机制**:`S_G.collect_trip_bytes`(alloc.c:48 初始化=default_collect_trip_bytes,:209 触发判断)。

**待验证实验(下步)**:启动期临时抬高 collect_trip_bytes(或推迟首次 major GC)使 prompt 先出,GC 移到 prompt 后/首次 idle。红线=仅 startup 作用域(全局抬阈=常驻内存代价),prompt 后恢复默认;语义不变(GC 仍会发生,只是不阻塞首屏)。预期:默认 REPL -30~40ms → ~165ms,交互 time-to-prompt 大跨。风险=作用域界定(在哪个点抬、哪个点恢复)+ 与 Racket CS rumble 层 collect 调度的交互(需查 rumble 是否也驱动 collect)。**这是纯调度优化,符合"机器负载须用户显式触发"原则——boot 垃圾的回收推迟到 prompt 后即用户交互态**。

## GC 靶点坐实 + 旁路点(2026-09-07 补)
- **坐实非 exit 陷阱**:prompt 处(退出前)current-gc-milliseconds=**70ms**(裸 REPL~0)——GC 确在 time-to-prompt 关键路径。此前 echo(exit)|PLT_LINKLET_TIMES 的 [+47] 混入了退出处理器 GC(main.sps:729 gcs-on-exit?,在 prompt 后);退出前查询排除了它。
- **旋钮**:collect-trip-bytes(Chez 参数,不暴露用户层,rumble/memory.ss:42 已在按 place 数动态设,collect-trip-for-allocating-places!)。collect-request box(memory.ss:2)是 Racket 层 GC 调度钩子。
- **旁路实现点**:rumble/memory.ss——启动期把 collect-trip-bytes 抬到 boot 分配量之上(不触发首次 major GC),prompt 出现后恢复默认(推迟的 GC 移到交互态)。红线=仅 startup 作用域、语义不变、符合"负载须用户触发"。预期默认 REPL -40~60ms → time-to-prompt 大跨。**下步实施:界定"prompt 出现"的恢复点 + 与 collect-request 调度交互,是设计改动需谨慎作用域。**

## GC 旁路实现 v1(2026-09-07,工作树未提交)
**实现**:rumble/memory.ss 加 defer-startup-collect!/end-startup-collect!(抬 collect-trip-bytes 到 256MB 上界/恢复 base);rumble.sls 导出;main.sps 在 namespace-require+ init-library 前 defer、REPL 循环前 end。
**实测**:prompt 处 GC 70→**56ms(-14)**,正确性无损(pvector.rktl 全过+交互求值正常)。
**诊断(部分收益之因)**:defer 成功推迟 init-library 的 GC,但 end-startup-collect! 恢复点在 REPL 循环**前**——恢复即触发的 56ms GC 仍落在 repl-setup(prompt 前)。**full-fix=恢复点移到 prompt 显示之后**。
**分层障碍**:end-startup-collect! 是 rumble 内部(collects 层 repl.rkt 的 read-eval-print-loop 不可见);main.sps 里 prompt 之后无钩子(prompt 在 current-prompt-read 内显示)。
**下步方案(三选一,下会话)**:(a) 把 defer/end 经 #%kernel 原语暴露到 Racket 层,在 repl.rkt read-eval-print-loop 首次 current-prompt-read 后调 end(prompt 已 flush);(b) 在 boot text-repl 的 prompt flush 点直接调;(c) main.sps 用 will/timer 在 prompt 后异步 end。倾向 (a),但需 bump 版本(新 kernel 原语)。预期拿满 -70ms → 默认 REPL ~135ms。
**红线守住**:仅 startup 作用域(end 后 collect-trip 恢复 base,无常驻内存膨胀)、语义不变、GC 推到交互态=负载用户触发。

## 方向纠正(2026-09-07,用户洞察):治标→治本
**用户点破**:GC 旁路是治标。~6MB 启动垃圾来源=racket/init+xrepl 的**模块实例化**(确定性、每次启动重复的工作;非编译,.zo 已用)。既然 racket.boot 是"已实例化运行时堆镜像"(expander/io/thread build 期实例化好、装载即活),racket/init+xrepl **本应同样预实例化进镜像**→装载即活、零实例化垃圾、零 GC 触发。**让垃圾从不产生**,而非调度清理。
**nuance**:实例化工作移到 build 期(一次),非消失;但 runtime 每次启动零垃圾/零 GC,正确。
**重定位**:
- GC 旁路 v1(memory.ss/rumble.sls/main.sps 未提交,+14ms)=**治标,搁置**,不追 full-fix。可撤销。
- 真解=**预实例化 racket/init+xrepl 进 boot 镜像**(=之前架构层 save-startup-image/boot-inclusion)。一石多鸟:消 70ms GC(垃圾不产生)+消语言层/xrepl 实例化时间+消两座大山主体。
**下步 spike(必做,确认可行性)**:racket/init、xrepl 是 collects 层 Racket 模块(linklet 层之上),能否像 expander 那样 build 期实例化进 vfasl 镜像?查 raco demod/embedding、自定义 boot 镜像、Racket CS 的"预加载 namespace 进 image"机制。走得通则这是 REPL 启动的总解(默认 REPL ~200→可能 ~60-80ms 级)。
