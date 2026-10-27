# 启动包（statically indexed module pack）：现有装载流程分析与快路径设计（2026-10-26）

## 1. 现在一个模块是怎么被装进来的（默认 REPL，287 个 .zo / 12 MB）

以 `racket/init` 里的一个 `(require racket/private/x)` 为例，每个模块走一遍下面六步；括号里是本机实测的总量（tty REPL，load 3–4）。

| 步 | 代码位置 | 做什么 | 总量 |
|---|---|---|---|
| ① 解析名字 | expander/boot/handler.rkt:158 `standard-module-name-resolver` | symbol/`lib`：`find-col-file`（eval/collection.rkt:374）查集合：2 个 links 文件各 exists+stat、用户 collects 目录探测、主 collects 目录探测、文件 exists；string：相对路径拼接。命中 path-cache 时 0.1–0.3 µs，未命中 11 µs（329 次） | resolver 区域 22–24 ms / 6,132 次（含 ②③ 的自身时间） |
| ② 选文件 | handler.rkt:29 `default-load/use-compiled` → `choose-file-to-load` | .rkt 与 compiled/x_rkt.zo 各一次 `file-or-directory-modify-seconds`（`use-compiled-file-check` 默认 'modify-seconds），决定用 .zo | 539 次 mtime ≈0.7 ms |
| ③ 打开读取 | boot/load-handler.rkt:21 `default-load-handler` | `open-input-file`（Racket 端口 + rktio fd，≈14 µs/次）、识别 `#~`、子模块目录时按 `expected-mod` 搜目录表再定位 | 290 次 open ≈4 ms；字节读入 6–13 ms |
| ④ 解码 bundle | cs/linklet/read.ss:8 `read-linklet-bundle-hash` | 4 字节长度 + 元数据 fasl（符号、键、每个 linklet 的向量）+ 代码区（整块读入，按 R1 切片惰性）；每个 bundle 自带一份符号表，跨文件重复 intern | read-bundle 5–7 ms；`read` 区域 10.5 |
| ⑤ 声明 | eval/module.rkt:39 `eval-module` → namespace/module.rkt:226 `declare-module!` | 实例化 data linklet（mpi 向量等，2.8 ms）、decl linklet（requires/provides 表，7.1 ms）、建 `module` 记录、注册；syntax literals 惰性（D1） | module 11.5 + requires 5 |
| ⑥ 实例化 | namespace/module.rkt:423/514 → linklet.sls:907 | phase-0 体（faslin-code 按需装载代码对象 27–30 + 体执行 24）、phase≥1 体 11 | instantiate 39–43 |

关键性质：
- ①②③ 完全是"按名字找文件"的开销，与模块内容无关：暖缓存 ≈ 13–20 ms I/O + 路径/缓存计算；冷缓存另加数十 ms（287 个散落文件的随机读）。
- ④ 的符号 intern 和 ⑤ 的 data/decl 是"把元数据从字节变成表"，每个 bundle 独立做，跨模块重复（60 K 符号 intern、每模块一份 mpi 向量）。
- ⑥ 与读法无关。
- 现成的多模块单段装载路径已存在：eval/load.rkt:44 `embedded-load`（`raco exe` 的 `-k` 段）：一段字节里顺序 `read` 出多个编译后模块，逐个 `(current-eval)`，用 `current-module-declare-as-predefined` 标记；模块以各自真实名字声明，身份不变。但它是顺序扫描、无索引、无按需，且 ① 的 resolver 仍会对每个名字走一遍。

## 2. 快路径设计：按层递进

原则：只在装载流程上加一条分支，命中时跳过 ①–④ 的全部或部分；未命中（不在包里、包过期、集合搜索顺序被改）走原路径；声明与实例化（⑤⑥）不变，所以语义、模块身份、错误行为与今天一致。

### L0 索引包（跳过 ①②③，④ 部分）
- 文件布局：`[header: 版本/机器类型/构建戳] [index: 模块名 → (resolved path, offset, len, zo-sha1)] [members: 每个成员的原始 .zo 字节]`。成员就是今天的 .zo 内容，不改格式。
- 装载：main.sps 在 `namespace-require+ init-library` 之前打开包（mmap 或一次 `read-bytes`），校验 header 戳，建 name→entry 的 hasheq（place-local）。
- 挂钩点 A（① resolver，handler.rkt:158）：symbol / `lib` / string 三个分支在算路径之前先查包索引（string 分支用 (relto 的 resolved name . 串) 查）。命中：直接 `make-resolved-module-path` 成包里记录的路径，不做任何文件系统操作；若 `load?` 且未声明，调 `pack-declare!`。
- 挂钩点 B（③ 装载）：`pack-declare!` = 对成员字节 `(parameterize ([read-accept-compiled #t] [read-on-demand-source #t]) (read port))` 然后 `((current-eval) v)`，并设 `current-module-declare-name`，与 `embedded-load` 相同，只是按索引定位、按需触发。子模块：成员 .zo 自带目录表，仍由 ④ 的目录搜索处理，或在索引里直接给出子模块偏移。
- 跳过的量：290 次 open、539 次 mtime、2,300 次 exists/stat、集合搜索 329 次未命中、12 MB 的 287 次分散读 → 一次顺序读/映射。
- 推断收益：暖缓存 −15～−25 ms（I/O 13–20 + resolver/load handler 路径计算的一部分）；冷缓存另 −30～−40。

### L1 包级共享表（④ 的重复 intern）
- 成员不再各自带符号表：包里一张符号/路径/mpi 表，成员 bundle 的元数据 fasl 引用表项（需要 bundle 元数据格式加一个"外部表"引用类型，写端在 `raco setup` 的打包步骤做，读端在 read.ss）。
- 推断收益：read-bundle 5–7 → 1–2，data 2.8 → ~1。

### L2 预解析的 requires（① 的剩余）
- 索引里每个成员记录它的 requires 对应的成员编号（构建时解析一次）。声明时 `requires` 列表直接构造成 resolved 名，expander 不再为包内 require 调 resolver。
- 影响 6,132 次调用里包内的那部分（绝大多数）。推断收益：resolver 区域 22 → 3–5。
- 需要 expander 一个入口：`declare-module!` 接受"已解析的 requires"（现在由 decl linklet 产出 mpi，再在 ⑤⑥ 中 `module-path-index-resolve`）。

### L3 声明结果数据化（⑤ 的 decl/data）
- decl/data linklet 是"生成表的代码"；对包成员，构建时跑一次，把 requires/provides/mpi 表用 compile/serialize 的字节流格式存进成员，装载时直接反序列化成 `module` 记录需要的值（provides 表经 D2 的 intmap-build）。
- 推断收益：decl 7.1 + data 2.8 → 3–4。风险：provides 表含绑定/作用域对象，序列化走 S3 已有的路径，但需要确认与 syntax-literals 的共享（`#:srcloc/source` 等）不被打破。

### L4 代码区（⑥ 的 faslin-code）
- 与"按定义惰性装载"合并：包内代码区按定义建切片索引。独立于 L0–L3，另立项。

## 3. 一致性与失效
- 包由 `raco setup` 的收尾步骤生成（与 info-cache/links 同级），记录每个成员的 .zo sha1 与 `.dep` 里的源 sha1；任何写 collects 下 .zo 的 `raco make/setup` 结束时重建或删除包。
- 启动时只校验 header：Racket 版本、机器类型、`(current-library-collection-links/paths)` 的规范化摘要（与构建时一致才启用，防止 PLTCOLLECTS/用户 scope 覆盖同名集合被跳过）、`use-compiled-file-check` 为 'modify-seconds 时额外 stat 包文件与 collects 的戳文件各一次。不逐成员 stat。
- 不命中/不一致 → 全程走原路径；`PLT_STARTUP_PACK=off` 可关，便于 A/B。
- 覆盖面：默认包含 racket/init + racket/interactive + xrepl + expeditor 闭包（305 模块）；非 REPL 进程也命中其子集（`racket -l racket/base` 同样受益），无额外常驻（包字节只在命中成员时被触碰；用 mmap 则未触碰页不占 RSS）。

## 4. 实施与度量顺序
1. **L0 spike（半天–1 天）**：手写打包脚本（按 /tmp/zo-list.rktd 的 287 个文件）+ main.sps 装包 + resolver/load 两处挂钩（先只做 symbol 与 string 分支）。度量：ttp 交错 A/B（`PLT_STARTUP_PACK=off/on`）、暖/冷缓存各一组（冷缓存用 `purge` 或重启后首跑）、`PLT_EXPANDER_TIMES` 的 resolver/read 区域、守卫计数（open/stat 应降到个位数）。
2. L2（1 天）：resolver 调用数应从 6,132 降到百位。
3. L1/L3 视 L0/L2 后的剩余量决定。

## 5. 细粒度扫描：装载流程里每个参与者与启动包的处理（2026-10-26 复核，覆盖 §1 六步的全部分支）

复核结论先行：§2 的"挂钩 A 在 resolver、挂钩 B 走 embedded-load"不够准确。resolver 之后还有 `default-load/use-compiled`（选文件、登记、设目录）和 `default-load-handler`（打开、识别 `#~`、子模块目录搜索、模块缓存）两层，子模块的二次装载、`load/use-compiled` 的路径调用、模块缓存都挂在这两层。**挂钩改为按路径键在这三层各放一个，走原有函数体，不另起 embedded-load 路径**，否则子模块、缓存、工具包装都要回头补。

### 5.1 挂钩点（最终）

| 挂钩 | 位置 | 触发条件 | 做什么 | 跳过的原工作 |
|---|---|---|---|---|
| H1 集合查找 | eval/collection.rkt:374 `find-col-file` 入口 | 包启用 且 (collection, col-path, file-name) 命中索引 | 返回索引里记录的完整路径（已是 .rkt 名） | 2 个 links 文件各 exists+stat、用户 collects 目录探测、主目录探测、文件 exists（≈7 次系统调用/次未命中） |
| H2 选文件 | boot/handler.rkt:29 `default-load/use-compiled`，在 `choose-file-to-load` 之前 | 包启用 且 `path`（源 .rkt 路径）命中索引 且 `(current-load)` 是默认 handler | 直接 `(values #f 'zo <成员的原 .zo 路径>)`，其余原样：`register-zo-path`、`current-module-declare-source` #f、`with-dir*` 设 `current-load-relative-directory` 为源目录、调 `(current-load)` | .rkt/.zo/.so 的 mtime 比较（539 次） |
| H3 打开读取 | boot/load-handler.rkt:21 `default-load-handler`，替换 `call-with-input-module-file` | `path`（.zo 路径）命中索引 | 持包信号量、`file-position` 到成员起点，把包端口与成员偏移 `base` 交给原函数体就地读（`object-name` = 包路径，只影响错误信息；`cached-bundle` 的键来自 bundle 内容哈希，不用端口名）；文件内偏移（子模块目录）加 `base`。**不得**先读成字节串再 `open-input-bytes`：那是两份额外拷贝（`open-input-bytes` 会 `bytes->immutable-bytes`），非 REPL 进程里多出的分配触发额外 major GC（实测 `-l racket -e` +15 ms）。其余原函数体不变：`with-module-reading-parameterization+delay-source`、`linklet-directory-start`/`search-directory` 子模块定位、`cached-bundle` 模块缓存、错误信息 | `open-input-file #:for-module?`（290 次端口创建）、分散读 |

三处都是"命中则换数据来源，否则原路"，函数签名、参数、登记表、错误路径全部复用。

### 5.2 每个参与者的处理

| 参与者 | 现状 | 包下处理 |
|---|---|---|
| resolver `quote` / `submod` 于 symbol 名 / planet | handler.rkt:234-262 | 不经过集合查找，不受影响；planet 路径不进包 |
| resolver `symbol` 分支 | path-cache（按 registry）→ `find-col-file` | H1 命中后结果照旧进 path-cache；首次解析 11 µs → ≈1 µs |
| resolver `lib` 分支（含旧式 `(lib "x.ss" "y")`、`main.rkt` 默认、`.ss`→`.rkt`） | 同上，先 split-relative-string 再 `find-col-file` | 索引键用 `find-col-file` 的入参 (col col-path f-file)，旧式写法在进入 H1 前已规范化，无需额外处理 |
| resolver `string` 分支 | `(cons s dir)` path-cache → build-path | 不碰文件系统，不改；其产物进入 H2 时按路径命中 |
| resolver `path` / `file` 分支 | `simplify-path`（文件系统敏感） | 不改；结果路径若命中索引则 H2/H3 生效 |
| `subm-path`（`(submod "." x)` / `(submod ".." x)`） | 解析出 root-modname + subm-path；装载时 `expected-mod` = `(cons sym subm)` 或 `(cons #f subm)`（根已声明时只允许 .zo） | H3 的字节端口上 `linklet-directory-start`+`search-directory` 原样工作；`(cons #f subm)` 经 `use-path/src`（`register-zo-path` 登记的 .zo 路径）再次进入 H3，仍命中包 |
| `-module-hash-table-table` / `registry-table-ref`（每 registry 的 declared 表与 name→(zo src base) 表） | handler.rkt:54-70，`boot` 时重置 | 不改；H2 照常 `register-zo-path`，使子模块二次装载与"沿用上次决定"逻辑一致 |
| `current-module-declare-name` / `-source` | resolver 设 name；`choose-file-to-load` 用主路径时 source 为 #f | H2 同样给 #f（`.ss` 备选路径不进包：构建时只收 `.rkt` 主路径命中的成员） |
| `current-load-relative-directory` | `with-dir*` 设为源文件目录 | H2 保留 |
| `choose-file-to-load`（collects/racket/private/choose-file-to-load.rkt） | 按 `use-compiled-file-check`（'modify-seconds / 'exists）比较 .rkt 与各 roots×modes 下的 .zo/.so 日期，`.so` 优先 | H2 绕过；等价于 'exists 语义 + 信任包；**限制**：成员若事后出现更新的 `.so` 扩展不会被选中（collects 内无 `.so`，构建时断言） |
| `current-compiled-file-roots` / `use-compiled-file-paths` / `PLTCOMPILEDROOTS` / `-R` / `-d` | main.sps:832-863 设置 | 启用条件：roots = `(same)` 且 modes = `(compiled)`；否则包关闭（errortrace 把 `compiled/errortrace` 放进 modes、cm 用 roots → 自动关闭） |
| `current-library-collection-links/paths`、`PLTCOLLECTS`、`-S`/`-X`、用户 scope 同名集合覆盖 | main.sps:848-855 | 包 header 记录构建时两个列表的规范化字符串；启动比对不等 → 关闭 |
| `current-load/use-compiled` 被工具替换（cm 的 `make-compilation-manager-load/use-compiled-handler`、`raco make -v`、`raco setup`） | cm-minimal.rkt:110 用 parameterize 包一层 | H2/H3 位于默认函数体内：工具包装层先于默认层运行，其自己的新旧判断不受影响；若工具最终委托默认 handler，仍受益；若工具自己打开文件（cm 的 `default-handler` 路径走 `(current-load)`），H3 照常命中 |
| `current-load` 被替换（errortrace 装自己的 load handler） | — | H2 条件要求 `(eq? (current-load) default-load-handler)`，否则按原路径给出真实文件，让工具自己读 |
| 模块缓存 `cached-bundle`（按 bundle hash-code，place-local，ephemeron） | load-handler.rkt:94 | 字节端口上同样可读 hash-code，复用 |
| `read-on-demand-source` / `load-on-demand-enabled` | 作为旗标决定 linklet preparation 'faslable（惰性）vs 'faslable-strict | 原函数体保留 `with-module-reading-parameterization+delay-source path`，惰性不变（R1 切片、D1 字面量从内存字节惰性解码，不回读文件） |
| `current-code-inspector` 非原始 | read.ss:76 → 'faslable-unsafe，eval 时报错 | 读路径不变，行为一致 |
| `read-accept-compiled` 等读参数 | `with-module-reading-parameterization` | 不变 |
| 安全守卫 `current-security-guard` | 每次 `open-input-file` 受检 | 包文件打开受检一次；成员读取不再逐文件受检 → 若守卫不是根守卫则关闭包（保守） |
| `module-predefined?` / `current-module-declare-as-predefined` | 仅 `raco exe` 的 `-k` 段用；expander 内无其他消费者 | 包成员**不**标 predefined，与文件装载完全一致 |
| `-k`/`-Y` 嵌入段、`embedded-load-in-places` | main.sps:465-487、place 创建时重放 | 不改；两机制互不影响 |
| places（`expander-place-init!` 重置 module-cache/path-caches） | main.sps:930-945 | 包句柄与索引做 place-local：每个 place 首次用时自行打开包、读索引（索引 ≈ 数百 KB） |
| 代码检查器/`raco decompile`/`module->path`/`variable-reference->module-source` | 依赖声明名与 declare-source | 名与 source 与文件装载相同 |
| 错误：找不到集合、子模块缺失、非编译模块 | resolver/`default-load-handler` 原文本 | 未命中走原路，文本不变 |

### 5.3 包格式（L0）
- header：magic、版本串、`(system-type 'vm)`、`(system-library-subpath)`、构建时间、collection-links 列表字符串、collection-paths 列表字符串、`use-compiled-file-paths` 字符串。
- 索引：成员数 N；每成员：源 .rkt 完整路径、.zo 完整路径、集合键 (col col-path f-file)（可多个：`racket/base` 与 `(lib "racket/base.rkt")` 同一成员）、offset、len、.zo sha1、.dep 里记录的源 sha1。全部用 racket/fasl 写成一个字节块，启动时 `fasl->s-exp` 一次。
- 成员：原 .zo 字节原样拼接，按依赖序（首次装载顺序）排列，4K 对齐可选（便于 mmap，不是必须）。
- 访问：每进程 `open-input-file` 一次；成员读取 `file-position`+`read-bytes len`（页缓存命中时等价今天的读，省的是 open 与查找；不预读 12 MB，非 REPL 进程只触碰用到的成员）。

### 5.4 失效与生成
- 生成：`raco setup` 收尾步骤（与 info-cache、links 同级），成员列表来自配置：默认 = racket/init + racket/interactive + xrepl + expeditor 的闭包（由 `module->imports` 从 .zo 元数据静态求出，不靠运行时追踪）；也可按安装定制。
- 失效：cm 的 `write-compiled-code`（compile-zo* 尾部，本树已改过该函数）在写入 collects 根下的 .zo 时写一个哨兵文件 `startup-pack.stale`；启动时 stat 哨兵一次，存在即关闭包；`raco setup` 重建包并删哨兵。这样启动只付 1 次 stat，手工 `raco make` 修改成员也安全。
- 开关：`PLT_STARTUP_PACK=off`；`PLT_EXPANDER_TIMES` 增加 `pack` 区域（命中次数、读取字节、未命中次数）。

### 5.5 测试矩阵
basic/module/syntax/stx/macro/read/number/string/fasl/hash/struct；`racket file.rkt`（`configure-runtime` 子模块经 `(submod ".." …)`）；`(dynamic-require '(submod racket/base reader) …)` 类子模块；`raco make -v` 与 `raco setup` 下包自动关闭且结果一致；`-l errortrace`（modes 改变 → 关闭）；`PLTCOLLECTS`/`PLTCOMPILEDROOTS` 设置 → 关闭；places 里 require 包成员；哨兵存在 → 关闭；`-n`、`-q`、默认 REPL、`racket -l racket/base -e` 四种进程的 ttp 交错 A/B（on/off）、冷缓存各一组、守卫计数（open/stat 应降到个位数）。

### 5.6 工作分解（L0）
1. `racket/collects/setup/private/startup-pack.rkt`：建包（闭包计算、索引、写出）、读包（header 校验、索引解码、成员读取）、启用判定（roots/modes/links/paths/哨兵/守卫/handler 身份）。
2. expander：collection.rkt H1、handler.rkt H2、load-handler.rkt H3 三处分支 + pack 区域；expander 不能依赖 collects 模块 → 包的读取与判定要放在 expander 内部（boot/ 下新文件），setup 侧只负责生成。`make derived` 重生 expander.scm/startup.inc。
3. main.sps：启动早期（设置 links/paths/roots 之后、`namespace-require+ init-library` 之前）调用 `startup-pack-init!`；place 初始化处同样。
4. cm-minimal.rkt：写 .zo 时落哨兵。
5. raco setup 收尾：生成包；`raco pkg`/`setup` 的清理路径删包。
6. 工具：`experiments/startup/pack-stats.rkt`（命中/未命中列表）、A/B 脚本复用 ab-gen 的 env 切换。

L2（预解析 requires）与 L3（声明数据化）需要 expander `declare-module!`/decl linklet 侧新接口，在 L0 的实测之后再定；它们不改变 5.1 的三个挂钩。
