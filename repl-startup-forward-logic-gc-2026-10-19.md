# 启动各阶段的逻辑性能与 GC 负载：正向分析（2026-10-19）

续 `repl-startup-phases-2026-10-19.md`。本篇只做两件事：①逐阶段看"实际做了什么工作、分配了多少、哪些是垃圾"，给出代码逻辑层面的改法；②GC 不靠关闭，靠减少分配与收集策略提示（hint）。不含任何"延迟到首次输入"类方案。
测量脚本：scratchpad `alloctrace.rkt`（分层分配/GC/存活）、`modprof.rkt`（逐模块 declare）、`modprof2.rkt`（真依赖序逐模块 phase-0 instantiate）、`readdecl.rkt`（读 .zo 与声明分离）、`bodyonly.rkt`（附着声明到新命名空间再实例化=剥离代码物化）、`gcpolicy.rkt`（vm-eval 改 Chez 收集策略）、`faslratio*.ss`/`zofasl2.ss`（裸 Chez fasl 物化成本）。原始输出在 `results/`。

## 0. 结论

**落地汇总（2026-10-19，六次提交，每项都是同一二进制 A/B，细节见 §5、§7–§12）**：

| 项 | 提交 | 已验证效果（默认 tty REPL 除非注明） | 备注 |
|---|---|---|---|
| G1 启动 GC 窗口（gen0-only + 关窗一次送 static） | fe249bf098 | ttp 229.7/236.3 → 214.0/220.5（static）/ 188.2/193.4（none）；footprint 150→130MB；提示符后不再有 major | 开关 PLT_STARTUP_GC_MODE/FINISH |
| D1 stx-data 惰性物化 | bb415179fd | `-q` ttp 132/140 → 121/126；声明区域 26.1ms/36.1MB → 16.0/24.1；footprint 143.7→136.3MB；默认 REPL 中位 224→214 | 代理单次 CAS 虚假失败致 ~1% 段错误，70c8880f86 修（300 次 0 失败） |
| D2 provides 表批量建表 | 495560107a | 声明分配 102→95MB，`-q` 声明区域 24.3→18.1MB，4698 项 2206→236KB；ttp 噪声内 | D3 不可行（nominal-module 每处不同） |
| R1 code 切片格式 | e56fe43c3e | linklet 层 CPU 65→61ms，racket 层分配 78.4→71.8MB，存活 +0.2MB；ttp 噪声内 | 未压缩代码实测更差，放弃；R3 上限 1.5ms 放弃 |
| C1 定位 | — | 物化成本 = fasl 解码 45% + LZ4 21% + intern 13% + icache 3%；"8–10× 差距"是对比对象不同 | §11 |
| C2 fasl 产物出生 gen 1 | e5c1f01046 | GC 23→18 次、56→52ms、CPU 212→206ms、footprint 135–143→131MB；ttp 噪声内 | 关窗 major（~38ms）仍在；出生 static 待做 |

收尾状态（全部提交后、全量重编为压缩 .zo、同机 load 16 下测，r1-measure-final/c2-cpu）：默认 REPL ttp 212.2/219.3（晨间基线 227/235，G1 单项 A/B 已记 230→214）、`-q` 119.8/124.4（基线 124）；提示符处收集 18 次 / GC 50ms（基线 23 / 66–70）、CPU 209ms；footprint 126.8–130.9MB（基线 150）；`-q` 的 racket 层分配 71.8MB（D1 前 91.4）、major 后存活 100.1MB（D1 前 104.3）。单项之和（ttp −20~−30ms、GC −20ms、footprint −20MB、分配 −20MB）与收尾状态一致；跨会话的绝对值受机器负载影响 ±5ms。

估计与实测的差距：D2/D3 原估 −18MB 实得 −7MB（D3 不可行）；R1/R3 原估 −24MB 实得 −6.6MB（读路径地板是 open 4.8ms，不是拷贝）；C2 原估存活拷贝 −12MB/关窗 24→10ms 实得 GC −4ms（min0 拷贝减少，但关窗 major 未动）。

**分配与 GC 账本（`racket -q` 等价路径，已验证）**：

| 阶段 | 分配 | 存活增量 | 收集次数 / GC ms |
|---|---|---|---|
| boot（三 vfasl 段） | 0.16MB 垃圾 | 堆 55.9MB（静态代） | 1 / 0 |
| racket/base | 20.3MB | +6.9MB | 2 / 1 |
| racket + racket/init（247+11 模块） | 97MB | +28.3MB | 12 / 19–25 |
| 首次展开（phase-1 visit） | 35MB | +14MB | 4（含 min2 13ms + major 13ms）/ 28–38 |
| tstring+xrepl（非 tty） | 5–6MB | +5MB | 0 |
| 合计到提示符（默认 tty，GC 日志） | 198.7MB | 存活 48.4MB | 23 / 66 |

垃圾占比 ≈ 70%；每 8MB 幼代里存活 1.5–2.7MB（19–34%）。

**racket/init 全量装载 117.6MB / 98ms 的构成（独立探针交叉验证，已验证）**：

| 工作 | 分配 | 时间 | 性质 |
|---|---|---|---|
| 读 .zo（bundle fasl→s-exp + 内层 bytevector） | 32.4MB（= .zo 字节 × 2.43，r²=0.99） | 14.6ms | 用后全垃圾 |
| 声明（decl/data/stx-data linklet 物化 + provides/requires 表 + 每模块簿记） | ~40MB | ~25ms | 多为存活 |
| 模块体 phase-0 代码与字面量物化（faslin-code / faslin-literals） | ~40MB | ~24ms | 存活但出生在 gen 0 |
| **模块体真正执行（246 个 body）** | **7.8MB** | **6–7ms** | 存活 |
| phase-1 visit 中的 body 执行 | 5.4MB | 5ms | 存活 |
| phase-1 visit 中的代码物化 + 语法对象反序列化 | ~30MB | ~42ms | 存活 |
| resolver 自含 | ~11MB（推断） | 11.6ms | 垃圾 |

两条改写直觉的事实：
1. **跑模块体几乎不花钱**（6–7ms / 7.8MB）。启动期 90% 以上的时间和分配是在把 .zo 变成堆里的代码、字面量、声明表，以及把它们在幼代里搬来搬去。
2. **声明期的分配按 .zo 字节线性膨胀**：decl/data/stx-data 这三个 linklet 的 fasl 数据在裸 Chez 里实测展开 5.8–10.3×（序列化的 provides/requires/语法向量），而非代码的 1.1–1.2×。`syntax-literals-data` 在声明时就急切物化（257 次，9.3ms），虽然语法对象本身是惰性反序列化。

**GC 策略提示（vm-eval 原型，不关 GC，已验证）**：启动窗口内只收集 gen 0、存活者进 gen 1 且不再回收 gen 1+（`(collect 0 1 1)`），语言层+visit 的 GC 从 47–61ms 降到 19–21ms，墙钟 −28~−33ms，代价 +5MB 未回收的 gen-1 垃圾（配 16MB 幼代则 +0）。Chez `collect` 不允许把 gen-0 存活者直接送到 ≥2 代（"invalid maximum target generation 2 for generation 0"），boot-mode 提示对普通 fasl 的 .zo 无效（实测 0 变化）。剩下的 ~20ms 是存活集（~35MB）被拷贝一次的成本，只能靠少分配/少存活压低。

## 1. 各阶段逻辑剖析

### 1.1 读 .zo（`read-linklet-bundle-hash`，linklet/read.ss）

逻辑：`read-bytes len` 把整段 bundle 读进 `bstr`（Racket 端口 → bytevector 一次拷贝）→ Chez `fasl-read` 把 bundle s-exp 读出来：列表 `(key val ...)`，每个 linklet 是向量，其中 code 和 literals 是**内层 bytevector（从 bstr 再拷一次）**→ `vector->linklet` 建记录 → `hash-set` 建 bundle hasheq → `decode-linklet-literals` 把 literals 包成惰性。
实测：315 文件 13.36MB → 32.4MB 分配 / 14.6ms；分配 = 9.3KB + 2.2×zoKB（r²=0.99）。分配成分（推断）：bstr 1.0× + 内层 code/literal bytevector ~0.9× + bundle 结构 ~0.5×。用后除 literals bytevector 外全是垃圾。
改法：
- R1 code/literals 以 (offset,len) 引用 bstr，物化时用定位过的 bytevector 端口 `fasl-read`（Chez 支持）：省内层拷贝 ~11MB、~1–2ms。
- R2 bundle 索引用定长 fixnum 向量代替嵌套 list/vector：省 ~5MB。
- R3 读路径不经 Racket 端口：直接以 Chez `open-fd-input-port`/mmap 得到的 bytevector 供 fasl-read，省一次拷贝（13MB）与端口层开销。
- R4 bstr 作为 lazy code 的后备存储（R1 后天然成立），避免"读完即弃"。

### 1.2 声明（`eval-module`，expander/eval/module.rkt）

逻辑：对每个模块实例化三个 linklet——`decl`（反序列化 requires / provides / phase-to-link / portal-stxes）、`data`（mpi 向量）、`stx-data`（语法字面量的序列化向量 + 惰性反序列化闭包）；然后 `declare-module!`：建 `module` 记录、每模块 `namespace`/`module-instance`、注册 registry、bulk-provide 登记。
实测（逐模块，GC 已剔除）：315 模块 40.2ms / 72.3MB（含读）。回归 `KB = 52.7 + 2.81·zoKB + 0.61·exports + 2.2·imports`（r²=0.96）：固定项 16.2MB、.zo 比例项 35.8MB（含 1.1 的读）、exports 项 13.0MB（21826 个导出）、imports 项 ~4MB。最重模块是**纯再导出模块**：init.rkt 3.4MB（4698 导出）、main.rkt 3.2MB（4695）、base.rkt 1.17MB（1805）、private/base.rkt 1.23MB（1805）、pre-base 1.17MB、kernel.rkt 0.94MB（37KB .zo 再导出 #%kernel 全部）。
裸 Chez 物化这三类 linklet：decl 5.8–7.2×、data 5–7×、stx-data 9.5–10.3× 膨胀，stx-data 4.6–15.6µs/KB。
微基准：4698 项 `hasheq` 经逐项 `hash-set` 构建 = 2.2MB（469B/项）/0.47ms；同内容 `make-hasheq`+`hash-set!` = 0.36MB/0.15ms；4698 个四字段 struct = 0.38MB。即 provides 表的 HAMT 路径拷贝是每项成本的主体。
`namespace-attach-module-declaration` 把同一组 340 个声明挂到新命名空间：12ms / 9.9MB = 每模块 29KB + 35µs 的命名空间侧簿记（proxy）。
改法：
- D1 **stx-data 惰性到 fasl 层**：声明时只保留 bytevector，`force-syntax-deserialize` 首次调用时才 fasl-read + 实例化。省 ~20–30MB（10× 膨胀的序列化语法数据）与 ~9ms；本会话未用到宏的模块零成本。
- D2 provides 表批量构造：从有序键向量一次建 HAMT（或声明期用可变 eq 表，首次共享时冻结）：469B→~100B/项，省 ~8MB、~1.5ms。
- D3 再导出共享：init/main/base/private-base/pre-base/kernel 六个模块的 ~14.7K 导出（67%）与来源模块的绑定逐项相同；`all-from-out` 以"引用来源表 + 差集"表示、查找时级联，省 ~10MB、~2ms。
- D4 每模块命名空间簿记惰性：`namespace`/`module-instance` 及其哈希表在首次实例化时再建；初始容量用 `small-hash`/向量。省 ~5–8MB、~3–5ms（推断，按 attach proxy 估）。
- D5 decl/data 的序列化编码更紧（requires 用 fixnum 向量索引 mpi 表而非符号/字符串列表；mpi 表跨模块共享前缀）：省 ~5MB（推断）。

### 1.3 代码物化（`eval-from-bytevector` → `load-compiled-from-port`）

逻辑：每个 linklet 在首次实例化时（'lazy）把 code bytevector 交给 Chez fasl 读取器：分配 code 对象（`S_code`，**gen 0 的 code 空间**）、重定位表、闭包、名字/arity 信息，并解析外部引用（literals 向量）与库入口。
实测：裸 Chez 对未压缩 fasl（Racket .zo 默认未压缩，linklet.sls:176/config.ss:14）：分配 1.1–1.2× fasl 字节、全部存活、垃圾 ≈0；速度 0.36–0.44µs/KB + 每次调用 0.85–1.8µs；压缩 fasl 则 26× 分配（Racket 不用）。Racket 层 `faslin-code` 区实测 21–40ms / 6–10MB = **3.5–4µs/KB，是裸 Chez 的 8–10 倍**。裸 Chez 直接读 .zo 里的模块体 code 报 "unregistered record type"（body 引用 Racket 记录类型，按 uid 解析），说明 Racket 代码的物化还含每个记录类型引用的 rtd 查找与符号 intern。
改法：
- C1 定位 Racket 层 8–10× 差距（rtd uid 查找、符号 intern、每 linklet `with-interrupts-disabled`/端口/`S_ENABLE_CODE_WRITE` 切换、icache 刷新）：先用 `PLT_VFASL_TIMES` 同款相位计时拆 `load-compiled-from-port` 内部（需插桩）。目标 24ms→~10ms（推断）。
- C2 **代码出生在老代**：`S_code` 固定 `find_room(tc, space_code, 0, ...)`（alloc.c:1099）；启动期给 fasl 物化一个目标代参数（C 层小改），代码对象不再被幼代收集拷贝：省 ~12MB 拷贝、GC −5~8ms。
- C3 vfasl 形态的 .zo（`PLT_LINKLET_VFASL`，已落地 −9ms）+ rtd-ref 覆盖修复：再 −5–8ms（推断）。

### 1.4 模块体执行（phase 0）

实测：246 个模块体 6–7ms / 7.8MB（把声明附着到新命名空间后重新实例化，代码已物化）。逐模块 top（含该模块代码物化）：contract/region 1.9MB、arrow-val-first 1.8MB、dict 1.5MB、port 1.1MB、class-internal 1.1MB、contract misc/guts 0.95MB、set-types 0.9、pvector 0.9、format 0.84；中位数 64KB / 0.05ms。xrepl.rkt 4.4MB（`make-base-namespace` 2MB + `initialize-namespace` 的 12 个顶层求值；按本轮范围不展开）。
结论：模块体本身没有值得单独优化的大头；`define-struct`/contract 构造等每模块几十 KB，分散。

### 1.5 phase-1 visit（首次展开触发）

实测：35MB / 47ms（GC 29）；其中 body 5.4MB/5ms（ns2 复测），代码物化 +300 code 对象 3MB（≈8MB/8ms），余 ~20–25MB/~30ms 是**语法字面量反序列化**（`deserialize`：scope 集合、binding 表、syntax 结构，走 `hash-set` 逐项构造）。
改法：
- V1 scope 集合/binding 表批量构造与跨字面量 intern（同一 scope 集合在一模块内大量重复）；
- V2 binding 表以向量形式惰性建索引（只在写入时升级为哈希）；
- V3 D1 的惰性使未被引用的模块不反序列化。
（本节数字中 30ms/20MB 的拆分是推断，直接测量需在 `force-syntax-deserialize` 加计时。）

### 1.6 resolver 与 requires 簿记

resolver（expander/boot/handler.rkt）：已缓存的符号模块路径 0.2µs/258B；未缓存的 `collection-file-path` 11.5µs/11KB（每个候选目录 `build-path` + `file-exists?` 探测、`ss->rkt` 字符串换算）。自含 11.6ms/2938 次，前 50 次占一半。
改法：R5 进程内"集合名→目录"缓存（现有 `path-cache` 只缓存整条模块路径）；R6 构建期生成 collects 索引（模块路径→文件），启动零探测。省 ~6–8ms、~8MB。
requires（`run-module-instance!`）：每次递归 `(hash-set seen mi #t)`（HAMT 路径拷贝）+ `seen-list` cons + shifted-requires 构造；expander 区 10.7MB/5355 次。改法 R7：`seen` 改可变 eq 表或 module-instance 上的访问标记；shifted mpi 向量化。省 ~5MB、~2ms（推断）。

### 1.7 tty 层各模块（不含延迟方案）

expeditor 13 模块 476KB .zo：10–12ms cpu、4–5ms GC（同样是物化为主）；syntax-color/racket-lexer 链 24 模块 27–31ms cpu，其中 instantiate +14ms、GC +9–21ms、on-demand 物化 50 次——词法器表以运行期构造（推断），值得单独剖析其 body；racket-indentation 2ms。改法 T1：lexer 的 DFA 表改为编译期常量（量化前先测 `parser-tools/lex` body 的分配）；T2：expeditor 的 color/wstring 表惰性构造。

## 2. GC：减少负载而不是关闭

### 2.1 现状机制（rumble/memory.ss）

幼代阈值 `collect-trip-bytes` = 8MB；代基数 4（每 4 次 minor 收一次 gen 1，每 16 次 gen 2）；major 由"分配量翻倍"触发（trigger 32MB 起、每次 major 后按 post-allocated 重设）。默认 tty 到提示符：14 次 min0（≈17ms）+ 6 次 min1（≈25ms）+ 1 次 min2（13ms）+ 1 次 MAJ4（13ms）= 66ms。拷贝式收集的成本 ∝ 存活者，垃圾本身免费：min1/min2/MAJ 的 51ms 是在反复搬同一批启动期存活数据。

### 2.2 策略提示实测（语言层 97MB + visit 35MB，三批次各 3 次，批次间系统负载不同，只做批内比较）

| 策略 | lang GC / 次数 | visit GC / 次数 | use 增量 | 备注 |
|---|---|---|---|---|
| 默认 | 19–30 / 11–12 | 21–38 / 4 | 35MB | |
| trip 32MB | 8–9 / 2 | 25–28 / 2 | 53MB | 幼代大→缺页多，wall 仅 −8 |
| trip 64MB | 12 / 1 | 12–14 / 1 | 52MB | |
| **gen0only** `(collect 0 1 1)` | **12–14 / 11** | **6–9 / 4** | 31–37MB | wall −28~−33 |
| trip16 + gen0only | 14–17 / 6 | 9 / 2 | 30MB | 内存最优 |
| trip32 + gen0only | 18–19 / 3 | 8–9 / 1 | 30MB | |
| trip4 + gen0only | 15–16 / 23 | 8 / 7 | 33MB | |
| nomajor `(collect 1 1 2)` | 23–25 / 11 | 12–14 / 4 | 35MB | |
| boot-mode（fasl 代码进静态代） | 无变化 | 无变化 | 无变化 | 普通 fasl 不受影响 |

读法：gen0only 下每个存活对象只被拷贝一次（gen0→gen1），GC 总量 ≈ 存活集一次拷贝（~35MB，≈13–15ms）+ 每次收集固定开销；幼代大小只改变次数，不改变拷贝总量（trip4 23 次 15ms vs trip32 3 次 18ms）。
`PLTDISABLEGC=1` 只省 8ms 的原因：幼代不复用 → 158MB 全部走新页缺页与缓存失效，把省下的收集时间吃掉。所以"零 GC"必须以"少分配"为前提，否则不如小幼代 + 单次提升。

### 2.3 建议的 GC 方案（按实施顺序）

- G1 **启动模式收集策略**（memory.ss，几十行）：从 boot 到提示符，`collect/report` 固定走 `(collect 0 1 1)` 并屏蔽 major 触发；提示符出现后恢复默认（随后第一次 gen-1 收集由用户分配触发，把启动期存活一次性提升）。已验证 −28~−40ms GC。可选 trip 16MB 同窗口，内存回到基线。
- G2 **少分配**（§1 各项）：读路径 R1–R4 −25–30MB、stx-data 惰性 D1 −20–30MB、provides D2/D3 −18MB、resolver R5/R6 −8MB、簿记 D4 −5–8MB、requires R7 −5MB。合计可把 158MB 压到 ~60–70MB（推断），收集次数 20→7–8 次，存活集 48→~30MB。
- G3 **代码与字面量出生在老代**（C2）：存活拷贝再 −12–15MB。
- G4 **零 GC 的边界**：gen0only + trip 16MB 下，GC = 存活一次拷贝 + 每次 ~0.5ms；要到字面意义的零次收集，需启动期分配 < 幼代，即只剩快路径（声明与代码预物化进静态镜像）。正向改法把 GC 从 66ms 压到 ~10–15ms 是可达范围（推断：G1 −40，G2/G3 再 −10~−15）。

## 3. 验证判据与下一步

1. G1 实现后：`PLTSTDERR=debug@GC` 日志应只有 min0，到提示符 GC ≤ 25ms；`racket -q` wall 124→~95；`current-memory-use` 提示符后首次 gen-1 收集的时点与成本记录下来。
2. D1（stx-data 惰性）：`PLT_LINKLET_TRACE_TIMES` 中提示符前 `syntax-literals-data` 实例化 257→0；alloctrace racket 层分配 97→~70MB。
3. R1/R3（读路径）：readdecl 的 read 分配 2.43×→≤1.2× .zo 字节。
4. D2/D3（provides）：readdecl 回归的 exports 项 0.61KB→≤0.2KB/项。
5. C1（物化差距）：插桩 `load-compiled-from-port` 相位，目标 ≤1µs/KB。
实施顺序建议：G1 → D1 → R1/R3 → D2/D3 → C1/C2 → R5/R6/R7 → D4/D5。

## 4. 方法与陷阱

- `current-memory-use 'cumulative` = `bytes-allocated + bytes-deallocated`，与 GC 日志 "alloc" 一致（116 vs 118MB）。
- 逐模块 `dynamic-require` 剖面必须按 phase-0 import 的真依赖后序做（`module->imports` 的相对路径要相对模块目录自己解析；用根模块先做会把全部依赖算到根上）；phase-1 专用模块不能用 `dynamic-require #f` 测（会在 phase 0 实例化，启动时不发生）。
- `(read in)` 后 `(eval c)` 的声明路径不带 `read-on-demand-source`，会急切物化全部 body 代码（+28MB/+14ms），不是启动真实路径；用 `module-declared? p #t` 走 load handler 才是。
- 分配确定 → GC 每次落在同一模块上，min-of-N 消不掉，须用 GC 列减去。
- Chez `collect` 的目标代约束：g < 最大代时 max-target 必须是 g+1；`(collect 0 2 2)`、`(collect 0 4 4)`、`(collect 0 'static 'static)` 全部非法。
- 压缩 fasl 物化分配 26×；Racket .zo 默认不压缩。

## 5. Step 1 落地：启动 GC 窗口（2026-10-19，已提交）

实现（`rumble/memory.ss`、`rumble.sls`、`main.sps`）：窗口从 init library 装载前开到 `read-eval-print-loop` 前；窗口内 `collect/report` 把所有自动收集请求强制为 gen 0→gen 1、冻结代计数器、跳过"内存翻倍"major 触发；关窗时一次 major 以 `'static` 为最小/最大目标代把全部存活对象直接送进 static（两条 major 分支都改：Racket 实际走的是 custodian accounting 分支）。只对文本 REPL 启用；`PLT_STARTUP_GC_MODE=off|repl|all`，`PLT_STARTUP_GC_FINISH=none|major|static`（默认 static）。

同一二进制 A/B（默认 tty REPL，pty，交错 N=7，已验证）：

| | off | none | static（默认） |
|---|---|---|---|
| time-to-prompt min/med | 229.7 / 236.3 | 188.2 / 193.4 | 214.0 / 220.5 |
| 提示符前收集 | 16 min0 + 5 min1 + min2 = 61ms | 23 min0 = 34ms | 22 min0 29ms + 关窗 major 30ms |
| 提示符后首个 ≥8MB 分配 | MAJ4 23ms | MAJ4 29ms | 无（min0/min1 4ms） |
| footprint（提示符处） | 150.3MB | 138.6MB | 130.2MB |
| 启动对象所在代 | 3–4 | 3 | 7（static） |

默认取 static：符合"对象一次到位获得最终 gc 属性"，之后的 major 对启动态零成本、无提示符后的 29ms 追补、内存最低；代价是关窗那一次 ~30ms 拷贝（48MB 存活），这正是第二步要消的量。`none` 是"提示符最快"的选项，留作开关。
Chez 约束（已验证）：`(collect g min max)` 在 g < 最大代时 max 只能是 g+1，所以 gen-0 存活者不能直接落到 ≥2 代；`in-place-minimum-generation` 只作用于目标代本身，关窗提升无法原地标记，必拷贝一次。
正确性：basic/hash/struct/vector/string/list 在 static 关窗后的 REPL 内 load 全过；`-f basic.rktl`（非 REPL，窗口不开）过；`PLT_STARTUP_GC_MODE=all` 下 basic/hash/struct/string 过。
陷阱：main.sps 的 `call-in-main-thread` lambda 体内不能插 `define`（"invalid context for definition"），用顶层 define + `set!`；关窗调用必须以"窗口开启过"为条件，否则 off 模式也会被提升（第一版漏洞，已修）。

## 6. Step 2 设计：fasl 产物直接出生在最终代（待实施）

目标：`load-compiled-from-port` / `fasl-read` 在窗口内产出的对象（code、重定位表、闭包、字面量向量/字符串/bytevector、decl/data/stx-data 的数据）直接分配在 static（或窗口目标代），不经过 gen 0→1→static 的两次拷贝；关窗拷贝只剩 Scheme 分配的状态（~18MB，推断 30ms→~10ms），窗口内 minor 的存活拷贝也随之减少。

改动面（读源已定位）：
- fasl.c `faslin`：分配点 12 处走带目标代的变体（`S_code` 固定 `find_room(tc, space_code, 0, ...)` alloc.c:1099；`S_record`/`S_closure`/`S_string`/`S_relocation_table`/`S_stencil_vector` 用 `newspace_find_room`；`Scons`/`Sbox`/`S_vector`；`S_bytevector2` 已有 space 参但 gen 固定 0；`S_cons_in`/`S_vector_in`/`S_ephemeron_cons_in` 已带 gen）。空间按 vfasl 的 vspace 映射：code→space_code、闭包/rtd→space_pure、含指针记录→space_impure_record、可变向量→space_impure、无指针→space_data、符号不动。
- 存储点 31 处（`faslin(tc, &SLOT, ...)` 递归把子值写进父对象槽）：目标代 >0 时须经 `S_dirty_set`（alloc.c:396，按槽所在段代与值的代比较后标脏卡），否则 static 父对象引用新建的 gen-0 符号/externals/运行期 rtd 会被 minor 漏扫（vfasl 的 `*ref = vfasl_external_ref(...)`（vfasl.c:720）正是这类无脏卡存储，只在非 boot 模式安全）。顶层 `fasl_entry` 的 `x` 是 C 栈变量，须用 `MaybeSegInfo` 判堆内再标脏。
- code 的重定位目标（`S_set_code_obj`，fasl.c:1506）只做裸写；老代 code 引用年轻对象的扫描依赖 code 段脏卡（gc.c:1693 `for_code`），需确认 `S_record_code_mod`/脏卡路径对 static code 成立，否则 code→externals 引用须另行登记。
- 入口：`bv_fasl_entry`（fasl.c:546）已按 `S_vfasl_boot_mode` 选 code 写入代；新增线程级目标代（tc 字段或 `S_G` 变量），由 Chez 参数（如 `$fasl-target-generation`）控制；linklet.sls 在窗口内 `parameterize` 包住 `code-from-bytevector` 与字面量 `fasl-read`。
- 验证：裸 Chez `faslratio` 复测（产物代号 = 目标代）；窗口内把 `collect-trip-bytes` 压到 256KB 做 minor 风暴 + `S_check_heap`（gcwrapper.c:696，调试构建）；六个测试集 REPL 内 load；`PLT_STARTUP_GC_MODE=all` 跑 basic/hash/struct。
风险：遗漏一个脏卡站点 = 低概率悬垂（seg4 历史的根因类型），因此以白名单式"每个存储点经同一宏"实现，不允许裸写。

## 7. D1 落地：stx-data 惰性物化（2026-10-19，已提交 bb415179fd）

实现（`expander/eval/module.rkt`）：声明时不再实例化 `stx-data` linklet，而是装一个同接口的代理 instance（`deserialized-syntax-vector` 的 box + `deserialize-syntax` 过程）；首次 `deserialize-syntax` 调用时才 `eval-linklet`+`instantiate-linklet` 真 linklet，把反序列化向量发布进代理的 box，然后像真 linklet 一样把过程置 #f。`PLT_EAGER_STX_DATA=1` 恢复原行为（A/B 开关，保留）。flattener 两条约束：模块级不能读环境变量（改成函数）、定义不能自引用（代理通过 box 引用自身）。

同一二进制 A/B（已验证，step2-d1.log）：

| | eager | lazy（默认） |
|---|---|---|
| 提示符前 `syntax-literals-data` 实例化次数（`racket -q`） | 251 | 1 |
| expander `module` 区域 | 26.1ms / 36.1MB | 16.0ms / 24.1MB |
| linklet 层 total | 63[+6]ms | 56[+7]ms |
| racket 层分配（alloctrace） | 91.4MB | 81.5MB |
| 首次展开分配 | 35.1MB | 39.2MB（运行到的宏在此时物化） |
| major 后存活 | 104.3MB | 99.9MB |
| ttp `racket -q` min/med（N=7） | 132.2 / 139.7 | 120.6 / 125.5 |
| ttp 默认 REPL min/med | 199.7 / 223.7 | 208.1 / 214.1 |
| footprint（提示符处） | 143.7MB | 136.3MB |

默认 REPL 的收益小于 `-q`：init 阶段本来就运行宏，大部分工作只是被搬到首次展开。macro/syntax/stx/stxparam/module/basic/syntaxlibs 在 REPL 内 load 与 `-f` 全过（`-f macro.rktl` 末尾的 "local-expand: not currently expanding" 为预先存在的预期输出，eager 模式同样打印）。

## 8. D2 落地：provides 表批量建表（2026-10-19，待提交）

实现：rumble `intmap-build`（hamt-stencil.ss）——按 hash 数位逐层稳定计数排序（一条 2n 的索引 fxvector 两半交替做源/目标），重复键折叠为最后一个值，每个 trie 节点只分配一次：先递归建好子节点存入该层暂存向量，算出 mask/count/槽数后 `$make-system-stencil-vector` 直接分配、`$stencil-vector-fill-set!` 逐槽填入（分配到填完之间 `disable-interrupts`，收集请求被推迟到 `enable-interrupts`；节点是最年轻对象，填充不需写屏障）；hash 位耗尽的桶生成与 `intmap-set` 相同的 cnode。结果与按序 `intmap-set` 构造的树结构相同（迭代顺序、`equal?` 一致，0–20000 项含重复键/碰撞的 eq/eqv 结构测试 + GC 压力测试过）。少于 8 项的表仍走 `intmap-set`（排序暂存比路径拷贝贵）。导出为 `#%unsafe` 的 `unsafe-hasheq-from-vectors` / `unsafe-hasheqv-from-vectors`（BC 用 hash tree 实现同名原语以保 startup.inc 可链接）；expander `serialize.rkt` 的 `#:hasheq`/`#:hasheqv`/`#:hasheqv/phase+space` 解码成两个向量后一次建表，`#:hash`（equal）不变。

第一版（元素经列表 + `#%apply`）实测：4698 项 644KB（`#%apply` 到变参原语会再拷一份 rest 列表，33 元素 816B/次）；小表固定开销（每表 ~4.5KB 的分层暂存）使首次展开层反增 +4.9MB。第二版（上述直接填充 + 懒分配各层暂存 + 8 项阈值）：4698 项 236KB（增量 2206KB，−89%）。第二版曾漏填 `#f` 值的槽（`(and (fx= count 1) (vector-ref vals ...))` 把 #f 当成"无值"）→ 未初始化槽被 GC 扫到 → 间歇崩溃；已修并把 #f 值加进测试。

同一二进制 A/B（第二版，PLT_INCREMENTAL_HASH_DECODE 开关仅用于测量，已移除；d2-validate-c.log / d2-recheck.log）：

| | 增量 | 批量（默认） |
|---|---|---|
| expander `module` 区域分配（`racket -q`） | 24.3MB | 18.1MB |
| eval 总分配 | 77.7MB | 71.6MB |
| racket 层分配（alloctrace） | 81.7MB | 78.8MB |
| racket/base 层 / init 层 | 18.1 / 5.7MB | 16.3 / 4.1MB |
| 332 模块顺序声明分配（readdecl） | 102.0MB | 95.0MB（init.rkt 3.34→2.05MB） |
| 同上声明耗时（3 次交替，去掉 GC 命中离群的一次） | 66.0–67.6ms | 64.6–66.9ms |
| ttp 默认 REPL min/med（N=9） | 204.6 / 219.7 | 209.9 / 215.5 |
| ttp `-q` min/med | 119.3 / 122.4 | 115.8 / 120.1 |
| footprint（3 次） | 144.1/133.6/132.0MB | 134.4/136.2/134.0MB |

结论：分配 −6~7MB（已验证，确定性指标）；时间 −2~−4ms 中位数（推断，在 ±3ms 噪声内）；footprint 无可分辨差异。与正向报告估计的 −18MB 差距来自 D3（再导出引用共享）不可行：nominal-module 在每个再导出处不同，装载侧无法共享 binding 对象。

## 9. 读路径再测与 R1 设计（2026-10-19）

实测（332 个启动 .zo，15.37MB，3 次平均）：Racket 端口整文件 `read-bytes` 7.7ms / 17.1MB（其中 open+file-size 4.8ms / 1.8MB，即打开本身是地板）；先读 4 字节再读剩余不增加分配（17.15MB），此前记的"+15MB"不成立；Chez `open-file-input-port`+`get-bytevector-n` 9.7ms / 33.9MB（双拷贝，更差）；Chez 无缓冲端口 + `get-bytevector-n!` 6.1ms / 15.9MB。→ R3（绕过 Racket 端口）上限 ≈ 1.5ms / 1.2MB，不值得单独做。
主模块 bundle 外层 `fasl-read`（332 个，12.7MB）：6.0ms / 15.6MB，其中 code bytevector 10.3MB、字面量 0.1MB，元数据 60350 个符号出现、82135 对、40339 其他对象（importss 22568 符号、exports 15312、importss-abi 61377 项）。
`read-bundle` 子区域（临时插桩，`racket -q`，328 个 bundle）：read-len 0、read-bytes 2[+4 gc]、fasl-bundle 8[+1]、adjust-bundle 3、read-bundle 自身 1；外层 `read` 22[+1]ms，即 Racket 侧（打开文件、`#~` 头解析、目录检索）≈ 9ms。
R1 设计（已写成补丁脚本 r1-apply.py，待应用）：bundle 格式改为 `[len|0x80000000][fasl][codelen][code area]`，fasl 内每个 linklet 的 code 槽换成 `(offset . len)`；读侧一次 `read-bytes` 取 code area，linklet 的 code 字段为 `code-slice` 记录（bv/start/len），`eval-from-bytevector` 用定位到 offset 的 bytevector 端口零拷贝 `fasl-read`（已验证每个 code bytevector 恰含 1 个 fasl 对象：1743 个 procedure、8 个 interpret 向量）；`stx-data` 与 phase≥1 的 code 读时拷出（它们可能永不求值，不能把整个 code area 留住）；高位标志使旧格式文件照旧可读；zo-lib 的 zo-parse/zo-marshal 改为整段透传。顺带把 adjust 的 4 次记录拷贝合为 1 次 `make-linklet`。预期（推断）：分配 −10~12MB、时间 −1~2ms；需全量重编译 .zo 才能测到。

## 10. 已定位并修复：模块装载中的间歇性 "invalid memory reference"（D1 引入）

现象：`racket -l racket/base -l racket/private/pvector-runtime-adapter -e '(void)'` 约 1–1.5% 的运行以 "invalid memory reference. Some debugging context lost" 失败（上下文随运行变：pvector-runtime-adapter / contract opters 模块体），`make derived` 两次因此中断。
定位（已验证）：同一二进制 `PLT_EAGER_STX_DATA=1` 0/300、惰性 4/300；pre-D2(HEAD) 4/300、pre-D1(HEAD~1) 0/300；D2 第一版/第二版二进制 1/200、3/200；GC 风暴（collect-trip-bytes 64KB 装载整个 `racket`）0/12 → 与 GC 无关，是 D1 的惰性代理。lldb（须 `settings set target.disable-aslr false`，默认关 ASLR 时 150 次不复现）捕获：`ldr x0, [x23, x30]`，x23 = 0x6（#f）、x30 = 9（typed-object 数据位移 + 下标 0），即 unsafe 编译的 expander 在 `force-syntax-object` 里对 #f 做 `(vector*-ref #f 0)`。
根因：代理用单次 `(box-cas! vec-box #f vec)` 发布反序列化向量；AArch64 的 CAS（LL/SC）可能虚假失败，box 留空，`force-syntax-object` 的 `(or (unbox box) (begin (deserialize-syntax ..) (unbox box)))` 得到 #f 后直接 `vector*-ref`。真 linklet（header.rkt）对同一 CAS 有重试循环，`force-syntax-object` 对 `vector-cas!` 也有；代理漏了。
修复：代理改为与真 linklet 相同的循环（CAS 成功或 box 已非空才退出）；修后 300 次 0 失败（见 d1fix-rate.log）。教训：Racket CS 里凡 `box-cas!`/`vector-cas!` 都必须按"可能虚假失败"写重试；unsafe 编译的 expander 把类型错误直接变成段错误，间歇性崩溃先用同二进制 A/B 开关二分，再用保留 ASLR 的 lldb 抓寄存器。

## 11. C1 定位：代码物化的每 KB 成本构成（2026-10-19，已验证）

进程内对 332 个主 bundle 的全部 1751 个 code bytevector 做 `fasl-read`（带各自的 externals，codefasl2/3.rkt；GC 后静机）：

| 类别 | 数量 | KB | fasl-read | µs/KB | µs/个 |
|---|---|---|---|---|---|
| 全部 | 1751 | 10083 | 25.5–29.3ms | 2.5–2.9 | 14.6–16.8 |
| phase-0 body | 332 | 4811 | 9.6–10.0 | 2.0–2.1 | 29–30 |
| decl | 332 | 937 | 3.9 | 4.1 | 11.7 |
| data | 332 | 239 | 0.65 | 2.7 | 1.9 |
| stx-data | 251 | 1113 | 5.8 | 5.2 | 23.1 |
| stx | 251 | 219 | 0.28 | 1.3 | 1.1 |
| interpret 格式 | 8 | 1249 | 0.83 | 0.67 | 104 |

decl+data+stx+body0 = 14.8ms，与 `racket -q` 的 linklet 层 `faslin-code` 15–22ms 吻合：Racket 包装层没有显著额外成本，差距在 Chez `fasl-read` 对这类内容本身的工作量；此前"裸 Chez 0.4µs/KB"是对简单数据测的，不可比。
`sample` 采样（重复 60 轮的 fasl-read 循环，自采样占比）：faslin 24%、**LZ4_decompress_safe 21%**、S_fasl_uptrin 18%、S_intern_sc+S_intern3 13%、iptrin 3%、sys_icache_invalidate 3%、GC ~3%、memmove 2%。
即：fasl 对象解码 ~45%（格式固有，vfasl 路线才能消）、**LZ4 解压 21%（configure 默认 enable_compress，PLT_CS_MAKE_COMPRESSED → 代码条目 LZ4 压缩；运行期 `PLT_LINKLET_NO_COMPRESS=1` 下重编译即可得未压缩 .zo）**、符号 intern 13%、每个 code 对象一次 icache 失效 3%。物化分配 6.7× 压缩字节（10MB→70MB，含解压缓冲）。
推断：未压缩代码 + R1 切片 = 解压 −4~5ms、分配 −25MB（解压缓冲）−10MB（拷贝），代价 .zo 体积 +15MB、读取 +~1.5ms；须全量重编后实测。

## 12. C2 落地：fasl 产物出生在 gen 1（2026-10-19，已提交）

实现（ChezScheme/c：fasl.c、alloc.c、gc.c、globals.h、types.h、thread.c、prim5.c、externs.h；cs：rumble/memory.ss、linklet.sls）：每线程 `fasl_gen`（+按种类掩码 `fasl_gen_mask`，`(cs)s_set_fasl_gen`）；`faslin` 的 pair/box/vector/stencil/record/closure/number/string/code 分配走 `find_room(tc, space, g, ...)`（impure/impure_record/closure/data/code 空间），按 mkgc 规则把对齐补位字写 FIX(0)；scratch string、graph 表、weak pair、ephemeron、tlc 留 gen 0。出生即老代的对象可能引用更年轻对象（读中 intern 的符号、externals、已有 rtd）：脏卡机制不覆盖 record 不可变域与闭包 code 指针，code 段无脏卡 → 改为"年轻引用根表"（S_G.young_ref）：读完整批登记，GC 在 setup_sweep_dirty 前对条目整对象 `sweep`/`sweep_code_object`，条目所在代 ≤ MAX_TG 后丢弃；所在段正被收集的条目交给常规扫描（判据只能用 `old_space`：收集器已把被收集段的 generation 改写成目标代）。linklet 层在启动窗口内对 `eval-from-bytevector` 置 gen 1（`PLT_STARTUP_FASL_GEN`，0 关闭）。

三次返工（已验证根因）：(1) 补位字未初始化 → impure 按字扫描把垃圾当指针 copy 崩；(2) 对象基址算错（带标签指针 = base−8+tag）；(3) 脏卡语义（上述）→ record 域悬垂（"expected vector, given port"）、闭包 code 指针悬垂；(4) 关窗 major 对已改写代号的段误当根扫描 → 对已转发对象 sweep 崩。`$enable-check-heap` 在本分支连未改动二进制也崩，不可用；验证改用种类掩码二分 + 全模式冒烟 + 测试集 + 300 次装载。

同一二进制 A/B（`PLT_STARTUP_FASL_GEN=0` 对照，默认 REPL，pty，交错；c2-validate.log/c2-cpu.py）：

| | off | gen1（默认） |
|---|---|---|
| 提示符处收集次数 / GC 毫秒（N=9 中位） | 23 / 56（min 54） | 18 / 52（min 49） |
| 提示符处 CPU 毫秒（中位 / min） | 212 / 204 | 206 / 203 |
| footprint（3 次） | 140.8/135.0/143.2MB | 131.6/131.4/131.3MB |
| ttp 默认 REPL min/med（N=15） | 209.9 / 215.0 | 210.0 / 214.0 |
| ttp `-q` min/med | 118.1 / 123.4 | 115.5 / 123.6 |
| linklet 层 CPU（`-q`，N=7 中位） | read 28 faslin 16 total 63 | read 30 faslin 18 total 65 |

结论：收集次数 −5、GC −4~−5ms、CPU −6ms、footprint −5MB（已验证）；ttp 差异在噪声内（推断：分配经 `find_room` 与登记多付 ~2ms，关窗 major 仍要把 gen 1 拷到 static ≈38ms）。高负载下（load 8）GC 日志曾显示 min0 41→30ms、关窗 major 41→38ms，静机复测为上表。测试：REPL 内 basic/hash/struct/macro/syntax/stx/module 过；`PLT_STARTUP_GC_MODE=all` 下 `-f` basic/hash/struct/syntax 过；`mode=all` 300 次装载 0 失败。
下一步（未做，推断）：出生在 static 才能消掉关窗拷贝（~38ms 中的代码部分 ≈ −25ms）；根表须改成"每条目记最年轻引用代"（像脏字节那样只在收集到该代时重扫），否则 static 条目会在窗口内每次 min0 被重扫（~6ms/次）；code 的最年轻代需遍历重定位表计算。
