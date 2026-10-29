# 启动包（startup pack）开发文档（2026-10-26 起）

状态：开发中。设计依据：repl-startup-pack-design-2026-10-26.md（§1 流程、§5 细粒度扫描）。本文件是施工台账：目标、约束、定案、步骤、验收、进度。

## 0. 目标与非目标
- 目标：默认 REPL（及任何命中成员的进程）跳过"按名字找文件"的开销：290 次 open、539 次 mtime、≈2,300 次 exists/stat、集合搜索、287 个文件的分散读；暖缓存推断 −15～−25 ms，冷缓存另 −30～−40 ms。
- 非目标（本期）：改变 .zo 内容或解码方式（L1/L3）、代码对象装载（L4）、预解析 requires（L2）。三个挂钩为后续各层保留，不重做。

## 1. 约束（硬）
1. **语义零变化**：模块名、`module-source`、`current-load-relative-directory`、子模块装载、模块缓存、错误文本与文件装载一致；成员不标 predefined。
2. **条件不满足即整体关闭**，不留半开：roots=`(same)`、modes=`(compiled)`、collection links/paths 与包 header 一致、`(current-load)` 为默认 handler、安全守卫为根守卫、无 stale 哨兵、`PLT_STARTUP_PACK` 非 `off`。
3. **不碰 Chez 内核、不碰 boot 文件、不碰 pb 种子**（只改 expander、main.sps、cm、setup）。
4. **无后台工作、无额外常驻**：每进程打开包一次，成员按需 `file-position`+`read-bytes`；不预读。
5. 工具可包装：H2/H3 在默认 handler 体内，cm/errortrace 的包装层照旧生效。
6. 度量纪律：同二进制 on/off 交错 A/B（ttp、守卫计数、`PLT_EXPANDER_TIMES` 区域），暖/冷缓存分开报；结论分已验证/推断。
7. 提交：Racket datum 格式，≤50 字符标题，不写 Co-Authored-By；expander 改动须 `make derived` 并一并提交派生产物。

## 2. 定案
### 2.1 挂钩
| 挂钩 | 文件 | 命中键 | 行为 |
|---|---|---|---|
| H1 | racket/src/expander/eval/collection.rkt `find-col-file` 入口 | `"col/sub/…/file"` 字符串 | 返回索引记录的完整路径（path），否则原逻辑 |
| H2 | racket/src/expander/boot/handler.rkt `default-load/use-compiled`，`choose-file-to-load` 之前 | 源 .rkt 完整路径（bytes） | `(values #f 'zo zo-path)`，其后 `register-zo-path`/`with-dir*`/`current-module-declare-source` 原样 |
| H3 | racket/src/expander/boot/load-handler.rkt `default-load-handler`，替换 `call-with-input-module-file` | .zo 完整路径（bytes） | 持包信号量、`file-position` 到成员起点，把**包端口本身**与成员偏移 `base` 交给原函数体就地读；`search-directory`/`file-position` 的文件内偏移加 `base`（独立文件 `base`=0）。零额外拷贝；读取跨度内无嵌套装载（proc 只读并返回 thunk，求值在跨度外） |

### 2.2 新文件 racket/src/expander/boot/startup-pack.rkt
- `startup-pack-init!`：由 main.sps 在 links/paths/roots 设定后、init 库 require 前调用；place 初始化时同样调用（place-local 状态：包端口、索引三张表、启用旗标）。
- 判定 `pack-enabled?`：见约束 2；`PLT_STARTUP_PACK` 支持 `off`、路径覆盖（默认位置 `(find-system-path 'collects-dir)/../share/startup.pack` 或 config `startup-pack` 键）。
- `pack-collection-path key` / `pack-zo-for-source src` / `call-with-pack-member zo proc` 三个查询；共享端口由 place-local 信号量保护，`call-with-pack-member` 在整个读取跨度内持有。
- 计时区域 `['eval 'pack]`（命中/未命中计数由 `PLT_EXPANDER_TIMES` 报告）。
- 依赖只用 `'#%kernel`/io 原语与 expander 内部模块（place-local、check、config）。

### 2.3 包格式 v2
```
#"RKTPK2\n"  <u32 header-len> <header s-exp>  <u32 index-len> <index 二进制>  <members…>
header = (version vm library-subpath modes build-time members)
index  = <u32 count> 然后每成员：
         <u16 n><src 路径字节> <u16 n><zo 路径字节> <u8 k> k×(<u16 n><键字节>) <u32 offset> <u32 len> <20B sha1>
```
header 仍是 s-exp（≈300 B，`read` 0.4 ms）；索引改为定宽二进制并在 expander 侧手工解码，三张表的键/值都是字节串（不经 `string->path`/`path->string`）。v1 的 s-exp 索引 100 KB `read` 2.34 ms + 建表 ≈7 ms，使不走 REPL 的 `racket -l racket/base -e` 慢 3.8 ms（0/15），v2 为此而改。成员 = 原 .zo 字节，按首次装载顺序排列。键校验（§2.5 之前的"按键校验搜索顺序"）改为**惰性**：首次 `pack-collection-path` 命中某键时才走候选目录序，命中后缓存在表项里；不解析的键零成本。

### 2.4 生成与失效
- 生成：`racket/collects/setup/private/startup-pack.rkt`（S1 先以 experiments/startup/startup-pack-build.rkt 落地并验证，S5 迁入 setup 并挂到 `raco setup` 收尾）。成员 = 配置的根模块（默认 racket/init、racket/interactive、xrepl、expeditor、syntax-color/racket-lexer）经 `module->imports` 的静态闭包（全相位）。
- 失效：cm `write-compiled-code` 在包覆盖的根下写 .zo 时创建 `startup.pack.stale`；启动 stat 一次；`raco setup` 重建后删除。
- 已知限制：成员事后出现的 `.so` 不会被选中（构建时断言无 .so）；`.ss` 备选不进包。

## 3. 步骤与验收
| 步 | 内容 | 验收 |
|---|---|---|
| S1 | 构建脚本（闭包、索引、写包、`--verify`） | 305 成员字节逐一与原 .zo 相同；索引键覆盖全部 symbol/lib 命中 |
| S2 | expander：startup-pack.rkt + H1/H2/H3 + 区域；`make derived`；`make base` | 开/关两态核心测试全过；守卫计数 open/stat 降到个位数 |
| S3 | main.sps 两个调用点（启动、place） | place 内 require 成员命中 |
| S4 | 度量：四种进程 on/off 交错 ttp（n≥15）、冷缓存、区域、守卫计数；lan-11 复测 | 报告 §15 |
| S5 | cm 哨兵 + raco setup 生成 + 清理路径删包 | `raco make` 改成员 → 下次启动关闭；`raco setup` 后恢复 |
| S6 | 提交（BUILD/FEAT 分拆：构建工具、expander、main.sps、cm/setup） | 校验器通过 |

## 4. 进度日志
- 2026-10-26：文档建立；S1 完成：experiments/startup/startup-pack-build.rkt，根 racket/init、racket/interactive、xrepl、expeditor、syntax-color/racket-lexer → 356 成员 / 14.7 MB / 156 个集合键，索引 100 KB；`--verify` 0 mismatch；覆盖默认 REPL 实际装载的 288 个 .zo 全部（68 个多余成员是静态闭包里运行时未触及的模块，无害）。两处修正：子模块引用只声明子模块，需先 `(module-declared? name #t)`；label 相位 import 不进闭包。S2 开始。
- 2026-10-26：S2/S3 代码落地：新文件 racket/src/expander/boot/startup-pack.rkt（place-local 状态、`startup-pack-init!`、三个查询、`['eval 'pack]` 区域、成员读取用信号量保护共享端口）；H1 collection.rkt `find-col-file` 拆成命中分支 + `find-col-file/search`；H2 handler.rkt 在 `choose-file-to-load` 前加包分支（条件含 `(eq? (current-load) default-load-handler)`）；H3 load-handler.rkt `call-with-input-module-file` 命中时 `(open-input-bytes bs path)`；main.rkt provide `startup-pack-init!` + `expander-place-init!` 调 `startup-pack-place-init!`；main.sps 在 roots 设定后与 place 启动参数继承后各调一次。构建中（make derived + make base）。
- 2026-10-26：S2/S3 构建通过并验证（三次返工：main.sps 顶层表达式须放进配置块内且在 roots 之后，否则 links/paths 比对在参数设定前执行；`debug` 名与 (expander) 库内既有定义冲突，改名 `pack-debug`）。**已验证**（本机 load ≈3，同二进制 `PLT_STARTUP_PACK=off` vs 包，tty 默认 REPL）：pack 区域 377 次命中 2.2 ms；resolver 区域 24.7 → 10.9；eval 区域 82 → 73；ttp 15 对交错 152.7 → 142.2，配对 **−11.4 ms，15/15**。守卫计数工具因自装安全守卫而使包关闭（设计如此），不能用它数系统调用；改用 lan-11 strace。暖缓存实测 −11 低于推断 −15～−25。冷缓存未测（需 sudo purge）。
- 2026-10-26 晚：正确性矩阵全过（核心测试、configure-runtime/main/reader 子模块、places、`raco make` 旁路、哨兵与 roots 关闭、300 次装载）。提交 3fd0524b47（phase/decl 区域）、c16f17a139（启动包 expander 侧）。发现 stamps 曾混入 0e557a8f3a（stash pop 冲突后的暂存残留），8841ae9060 移除；工作树不再套 stamps。S5 代码落地（setup/private/startup-pack.rkt、setup-core 收尾步骤与 --clean、cm 哨兵）；`raco setup setup compiler` 已生成 racket/share/startup.pack（356 模块）。默认位置推导错误（相对 collects-dir）→ 改为 `find-share-dir`（collection.rkt 新函数，main.rkt 传入，避免 pack↔collection 循环依赖），派生产物重生中。
- 2026-10-26 夜：**启用判定改为按键校验搜索顺序**（ae6ba02413）。原"header 记录 links/paths 字符串、启动时精确比对"在 `make base` 自己的 `raco setup`（`--no-user -G build/config/`，看不到用户 scope、安装 links 文件可能不存在、路径拼写不同）下永远不匹配；中间尝试过规范化路径、剔除用户 scope 项、按顶层集合名粗判（本机 scribble/text/wrap.rkt 与 racket/contract/option.rkt 真被用户 scope 副本遮蔽，粗判会整包关闭）。最终：`collection-candidate-dirs`（从 `find-col-file` 抽出）给出每个集合的候选目录序，启动时对 156 个键各走一遍"第一个含该文件的目录"，与成员源路径不等即丢该键；目录存在性按 (候选, 集合) 缓存，≈0.3 ms。header 只比 version/vm/subpath/modes。**已验证**：`make base` 产出的包（310 成员，构建配置下看不到 pkgs）在默认启动即启用（135 键），resolver 区域 24 → 12.9，ttp 默认 REPL −7.8（14/15）、`-q` −5.5（9/9）；普通 `raco setup` 后包含 356 成员。移除了 `user-scope-collection-dirs`。
- 2026-10-26 深夜：**索引 v2 + 惰性键校验 + 就地读**。(1) 固定成本：v1 s-exp 索引 `read` 2.34 ms + 建表 ≈7 ms 使 `racket -l racket/base -e '(void)'` 慢 3.8 ms（0/15）→ 二进制索引（§2.3）、表键值全用字节串、键校验推迟到首次命中；重建后 `racket -l racket/base -e '(void)'` 包开 **快 1.9 ms（21/21）**，`racket -n` 0.0（11/21，固定成本已不可测）。(2) 新发现回归：`racket -l racket -e '(void)'`（非 REPL，GC 窗口已关）包开**慢 14.9 ms（0/15）**。定位（`-W debug@GC`）：包路径多分配 26 MB（alloc 114.7 → 140.8 MB）触发一次 MAJ4（13 ms）+ 一次 min2（14 ms），关包时整程无 major。多出的分配 = `pack-member-bytes` 整份成员字节（14.3 MB，pack 区域）+ `open-input-bytes` 的 `bytes->immutable-bytes` 再拷一份（≈11.6 MB，落在 resolver 区域）；read.ss 的 `read-bytes len` 第三份两种路径都有。REPL 路径没暴露是因为窗口内只收 gen0。改法：H3 不再拷字节，`call-with-pack-member` 持信号量、`file-position` 到成员、把包端口与 `base` 交给原 proc 就地读（分配与 .zo 文件路径相同，少每模块一个文件端口）；`search-directory` 加 `base` 参数。验收标准新增：**`racket -l racket -e '(void)'` 包开不得慢于关**。构建中。
- 2026-10-26 深夜（续）：就地读第一次构建失败于 `make base` 的 `raco setup`："expected a `module' declaration; found an extra form, in: …/share/startup.pack"。原因：bundle（非目录）路径走 `read-syntax` 后再读一次以确认 EOF（"found an extra form" 检查），包端口在成员之后是下一个成员而非 EOF。改法：proc 多收 `end`（成员终点，独立文件为 #f），`end` 非 #f 时跳过该检查（成员内容在构建时逐字节验证）。重建中。
- 2026-10-26 夜：就地读重建通过并提交 **d6f8970429**（索引 v2 + 惰性键 + 就地读 + experiments 构建器改为 setup 库前端）。**已验证**（本机，`make base` 自产 310 成员包）：默认 REPL −10.0（15/15）、`-q` −8.5（15/15）、`-l racket -e` −6.6（20/21）、`-l racket/base -e` −1.5（21/21）、`-n` +0.4（4/15，残余固定成本）；alloc 114.7 → 112.4 MB、major 0/0；正确性矩阵全过。数字汇总在估算报告 §15。S4 完成，S6 完成（提交），剩 lan-11 复测与 DOCS 提交。
- 2026-10-26 夜（终）：lan-11 复测 d6f8970429 通过（REPL −3.7 14/15、`-l racket -e` −2.2 21/21、`-l racket/base` −0.4 21/21、`-n` +0.3、无 major、测试过）。S1–S6 全部完成；DOCS 提交随后。

## 5. L2（预解析 requires）扫描结论（2026-10-27，已验证，未开工）

工具：scratchpad/res-classify.rkt（`'#%kernel` 模块在装任何库前包裹 `current-module-name-resolver`，分类 3269 次四参调用）、load-excl.rkt / load-excl-mem.rkt（resolver → load/use-compiled → load → eval 四层**独占**时间/分配）、/tmp/res-stage.rkt、/tmp/res-miss.rkt、/tmp/load-steps.rkt（单步微基准）。覆盖 racket/init + racket/interactive + racket-lexer + xrepl（不含 expeditor/xrepl 初始化，REPL 实际 5834 次）。

1. 之前"已声明模块每次解析 2.5 µs"是测量伪影：基准列表里 `(lib "racket/base/lang/reader.rkt")` 在该进程里未声明，每次触发装载尝试 11.9 µs，拉高平均。真实值：symbol/lib 命中路径缓存 0.14–0.19 µs，mpi join+resolve 0.21 µs，`module-declared?` 0.04 µs。
2. 调用构成：56% 是相对字符串、noload、relto、已声明（1824 次，合计 0.85 ms，单次 0.46 µs）；真正触发装载 375 次；`(submod "." x)` 带装载 17 次 2.7 ms 是真实子模块装载（lazy-require 等），非负探测。
3. 四层独占时间（3 次运行）：load 16–23 ms（含 bundle fasl 读 ≈10）、eval 11–17（decl/data）、resolver 6.3–6.6、load/use-compiled 2.8。`PLT_EXPANDER_TIMES` 的 resolver 区域 10.5 ms = 解析自身 + load/use-compiled + load handler 非 read 部分（三者都没有自己的区域）。
4. 单次装载固定步骤实测：21 参数 `with-module-reading-parameterization` 0.87 µs、`maybe-count-lines!` 的 `regexp-match?` 1.1 µs、头部两次扫描（directory-start + hash-code）≈1.3 µs、`read` 分派再解析一次头部 ≈1 µs、path-cache HAMT 插入 ≈1 µs、split-path/string->symbol/make-resolved ≈0.8 µs。可去除的 ≈7–9 µs × 375 ≈ **2.5–3.2 ms**。
5. 分配：load 层独占 28.7 MB（bundle 字节 12.7 + fasl 产物）、eval 15 MB、resolver 6 MB（1.9 KB/次）。plain REPL 全程 GC 32 ms = 9 次 minor（各 1–2 ms，存活率 >50%）+ 关窗 major。

**结论**：预解析 requires 上界 ≤1 ms，不做。按装载的固定开销可做"包成员融合装载路径"（索引预存 directory 表与 hash、跳过 regexp/21 参数 parameterize/双重头解析/`read` 分派，守卫 `current-load`/`current-eval` 为默认）≈ −3 ms（推断）。更大的只剩 L4（fasl 9.4 + body0 的一部分 + GC 存活量）与 L3（decl/data 10）。

## 6. 融合装载路径（2026-10-27 定案）

扫描依据：§5 + choose-file-to-load.rkt 的 `linklet-directory-start`/`linklet-bundle-hash-code`（纯 peek，相对当前位置）、compile/read-linklet.rkt 的 `read-linklet-bundle-or-directory`（`#~` 已消费；`start-pos = file-position − 2`，目录内偏移相对 start-pos，故对包成员自动正确；initial? #t 时剥 pre/post）、load-handler.rkt `default-load-handler` 的全部分支、eval/module.rkt 的 cache-key（用 `current-load-relative-directory`）、cs/linklet/read.ss 的 `read-on-demand-source`（决定 linklet 'faslable 还是 'faslable-strict，**必须保留**）。包里 310 成员 = 62 bundle + 248 directory。

现状每次成员装载：`maybe-count-lines!` regexp 1.1 µs → 21 参数 parameterize 0.87 → `linklet-directory-start` 7 次 peek → `search-directory` 二叉查找（每步 `file-position` 0.6 µs + 读名）→ `file-position` 到 bundle → `cached-bundle` 再 7 次 peek + 20 字节 → `(read i)`（建 read-config、字符分派、再解析一次版本/vm 头）→ thunk。可去除 ≈ 7–10 µs/次。

定案：
1. 索引 v3（magic `RKTPK3`）每成员追加 bundle 表：`<u8 kind B|D> <u16 count> count×(<u16 n><编码名字节> <u32 成员内偏移> <u32 长度> <20B sha1>)`。名字 = .zo 目录里存的 `encode-symbols` 形式（根模块 = `#""`）；B 成员表 = 单项 `#""`，偏移 0；sha1 全零表示无 hash（与 `linklet-bundle-hash-code` 一致）。生成时解析每个成员与目录里每个 bundle 的头部取 sha1。
2. expander 侧 by-zo 表值 = `(vector offset length table-bytes parsed)`，bundle 表首次装载时解析并缓存（lazy）。`call-with-pack-member` 把 `(port base table)` 交给包专用过程。
3. load-handler.rkt 新增 `load-pack-member`：按 `expected-mod` 查表（symbol → `#""`；`(#f . subs)`/`(sym . subs)` → 编码 subs）；查不到：D 成员且 pair → `void`，symbol → "could not find main module"；B 成员且 `(sym . subs)` → 装根（与原 B 分支一致），`(#f . subs)` → `void`。命中：用表里 sha1 建 cache key 查 `module-cache-ref`（命中 → 返回 declare thunk）；否则 `file-position` 到 `base+off+2`（跳过 `#~`），`(load-on-demand-enabled)` 时 parameterize `read-on-demand-source`，直接调 `read-linklet-bundle-or-directory`，检查 `compiled-module-expression?`，返回 `(lambda () ((current-eval) v))`。文件路径（非包）的 `proc` 恢复上游原形（去掉 `base`/`end` 参数）。
4. 不变：resolver、`default-load/use-compiled`（H2、`register-zo-path`、`current-module-declare-source`/`current-load-relative-directory`）、`(current-eval)`、module cache 键语义、错误类型。
5. 验收：§3 的三类进程 A/B + `debug@GC`；正确性矩阵；`racket -l racket -e` 的 resolver 区域应降 ≈ 2–3 ms（推断 −3 ms 总体）。
- 2026-10-27：§6 融合装载路径落地并提交 **1894b40572**（索引 v3 bundle 表、`load-pack-member`、文件分支恢复上游原形）。构建一次通过；正确性矩阵全过（核心测试、子模块程序、place、`dynamic-require` 子模块、`(submod … configure-runtime)` 探测、pty REPL、300 次装载 0 失败、`--verify` 0）。**区域（已验证）**：`-l racket -e` 包开 eval+read 61.3 → 58.3 ms（关 67.5）；默认 REPL eval+read 74.5 → 71.6；fasl 读现在计入 pack 区域（直接调 bundle 读取器，绕过 `read` 区域）。到退出 A/B 本轮机器负载高（关侧中位数漂移 119→105、REPL off min 126.9），pack 开/关差值 −8.6(19/21)/−1.7/−0.3(`-n`)、REPL −8.9(13/15)、`-q` −6.4(13/15)，与上一版同量级、无法从中分离本步贡献 → 另起 worktree 构建 d6f8970429 做同机头对头（ab-two.py / ab-two-ttp.py）。
- 2026-10-27：lan-11 复测 1894b40572（已验证，pack 开/关）：`-l racket -e` −3.5（21/21，上一版 −2.2）、`-l racket/base` −0.4（20/21）、`-n` +0.4（0/15，上一版 +0.3：索引多了 bundle 表 ≈28 KB，解码成本略升）、REPL ttp −6.1（14/15，上一版 −3.7）；alloc 114.3 → 109.9 MB，major 0/0；测试过。
- 2026-10-27：**同机头对头（已验证）**，A = d6f8970429 参考构建（worktree racket-ref-v3，仅核心，无 pkgs）、B = 1894b40572，交错 41 对，load 5.5–6.3：`-l racket -e` **−1.4 ms（35/41）**、`-l racket -l racket/contract` −1.6（37/41）、`-l racket/base` −0.2（17/41，略差）、`-n` ±0.2。ttp 不可比（参考构建没装 xrepl/expeditor）。§6 的 −3 推断偏高，实际 ≈ −1.5；racket/base 级进程持平略负的原因 = 索引多了 bundle 表、解码时逐表按条目读。跟进：索引 v4 给每张表加 `u16 table-len` 前缀，解码一次 `read-bytes`（magic RKTPK4），重建中。
- 2026-10-27：索引 v4（表长前缀）重建通过并提交；正确性全过；头对头 vs d6f8970429：`-l racket -e` −1.4（34/41）复现，`-n` −0.3（8/41）、`-l racket/base` −0.3（17/41）——小进程差异在 ±0.3 ms 内且两套安装不止包代码不同（主树装了 pkgs），无法再分辨；包开/关的 `-n` 固定成本两版都 ≈0.3 ms，由打开包 + 读 header/索引主导。融合装载路径收尾：**本机 `-l racket -e` −1.4 ms（已验证）、lan-11 REPL 开/关 −3.7 → −6.1**。

## 7. 收口（2026-10-27）

L4（按定义惰性代码）经评估不开工：`PLT_LINKLET_TIMES` 实测 faslin-code 27 ms（+GC 6）/ 1579 linklet / 9 MB，上界 ≈25 ms，但按定义切片会断掉 linklet 内直呼/内联（R10 ≤5% 预算大概率守不住）、断 fasl 图共享、占位过程语义面广、改全部 .zo 格式；用户决定收口。L3、关窗 major、body+ 延后均不做。

本轮累计（默认 tty REPL，本机，pack 开 vs 关，已验证）：启动包 −10 ms、融合装载路径再 −1.4（头对头）；lan-11 REPL −6.0。代码链 c16f17a139 … 07ae4f2904 全部在 feat/repl-startup-analysis。

## 8. 格式 v5：成员路径相对化（2026-10-29）

起因：`release-9.3.13` 的 rpm 构建在 fedora/el9 的 postinstall 变体全败，`/usr/lib/rpm/check-buildroot` 在 `/usr/share/racket/startup.pack` 里找到 BUILDROOT 绝对路径。v4 索引逐成员记录构建时的绝对 src/zo 路径（本机 in-place 包 310 成员 ×2 条），任何重定位（rpm/deb/Windows portable、换前缀的 bottle）之后键校验都对不上，包静默失效。

v5（magic `RKTPK5`）：
- 索引每成员前加 `<u8 root>`：0 = 主 collects 目录，1 = 安装级 pkgs 目录（`find-pkgs-dir`：config `pkgs-dir` 否则 `share/pkgs`），255 = 绝对路径（两个根之外的兜底，in-place 构建里 `pkgs/*-lib` 走这档）。
- 写端（setup/private/startup-pack.rkt）按根编码；header 加 `roots "(collects pkgs)" absolute N`，`raco setup` 日志可见绝对成员数。
- 读端（expander boot/startup-pack.rkt）`startup-pack-init!` 多收一个 roots 向量（`(vector (find-main-collects) (find-pkgs-dir config))`，expander/eval/collection.rkt 新增 `find-pkgs-dir` 与 setup/dirs 同义），解析索引时 `bytes-append` 目录形式的根 + 相对字节，得到与解析器一致的绝对字节；键校验、by-src、by-zo 逻辑不变。未知根的成员跳过。
- 本机（已验证）：工具生成 333 成员、11 绝对（全是 `pkgs/` 内 parser-tools 等）、`--verify` 0 mismatch、`strings` 无构建树前缀（绝对兜底除外）；安装布局下 pkgs 在 pkgs-dir 之下，预期 0 绝对。
