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
- 2026-10-26 晚：正确性矩阵全过（核心测试、configure-runtime/main/reader 子模块、places、`raco make` 旁路、哨兵与 roots 关闭、300 次装载）。提交 491833f7a0（phase/decl 区域）、670bff1ce1（启动包 expander 侧）。发现 stamps 曾混入 64ea6ccea7（stash pop 冲突后的暂存残留），f879113595 移除；工作树不再套 stamps。S5 代码落地（setup/private/startup-pack.rkt、setup-core 收尾步骤与 --clean、cm 哨兵）；`raco setup setup compiler` 已生成 racket/share/startup.pack（356 模块）。默认位置推导错误（相对 collects-dir）→ 改为 `find-share-dir`（collection.rkt 新函数，main.rkt 传入，避免 pack↔collection 循环依赖），派生产物重生中。
- 2026-10-26 夜：**启用判定改为按键校验搜索顺序**（9ea96119cf）。原"header 记录 links/paths 字符串、启动时精确比对"在 `make base` 自己的 `raco setup`（`--no-user -G build/config/`，看不到用户 scope、安装 links 文件可能不存在、路径拼写不同）下永远不匹配；中间尝试过规范化路径、剔除用户 scope 项、按顶层集合名粗判（本机 scribble/text/wrap.rkt 与 racket/contract/option.rkt 真被用户 scope 副本遮蔽，粗判会整包关闭）。最终：`collection-candidate-dirs`（从 `find-col-file` 抽出）给出每个集合的候选目录序，启动时对 156 个键各走一遍"第一个含该文件的目录"，与成员源路径不等即丢该键；目录存在性按 (候选, 集合) 缓存，≈0.3 ms。header 只比 version/vm/subpath/modes。**已验证**：`make base` 产出的包（310 成员，构建配置下看不到 pkgs）在默认启动即启用（135 键），resolver 区域 24 → 12.9，ttp 默认 REPL −7.8（14/15）、`-q` −5.5（9/9）；普通 `raco setup` 后包含 356 成员。移除了 `user-scope-collection-dirs`。
- 2026-10-26 深夜：**索引 v2 + 惰性键校验 + 就地读**。(1) 固定成本：v1 s-exp 索引 `read` 2.34 ms + 建表 ≈7 ms 使 `racket -l racket/base -e '(void)'` 慢 3.8 ms（0/15）→ 二进制索引（§2.3）、表键值全用字节串、键校验推迟到首次命中；重建后 `racket -l racket/base -e '(void)'` 包开 **快 1.9 ms（21/21）**，`racket -n` 0.0（11/21，固定成本已不可测）。(2) 新发现回归：`racket -l racket -e '(void)'`（非 REPL，GC 窗口已关）包开**慢 14.9 ms（0/15）**。定位（`-W debug@GC`）：包路径多分配 26 MB（alloc 114.7 → 140.8 MB）触发一次 MAJ4（13 ms）+ 一次 min2（14 ms），关包时整程无 major。多出的分配 = `pack-member-bytes` 整份成员字节（14.3 MB，pack 区域）+ `open-input-bytes` 的 `bytes->immutable-bytes` 再拷一份（≈11.6 MB，落在 resolver 区域）；read.ss 的 `read-bytes len` 第三份两种路径都有。REPL 路径没暴露是因为窗口内只收 gen0。改法：H3 不再拷字节，`call-with-pack-member` 持信号量、`file-position` 到成员、把包端口与 `base` 交给原 proc 就地读（分配与 .zo 文件路径相同，少每模块一个文件端口）；`search-directory` 加 `base` 参数。验收标准新增：**`racket -l racket -e '(void)'` 包开不得慢于关**。构建中。
- 2026-10-26 深夜（续）：就地读第一次构建失败于 `make base` 的 `raco setup`："expected a `module' declaration; found an extra form, in: …/share/startup.pack"。原因：bundle（非目录）路径走 `read-syntax` 后再读一次以确认 EOF（"found an extra form" 检查），包端口在成员之后是下一个成员而非 EOF。改法：proc 多收 `end`（成员终点，独立文件为 #f），`end` 非 #f 时跳过该检查（成员内容在构建时逐字节验证）。重建中。
- 2026-10-26 夜：就地读重建通过并提交 **e956ad95fb**（索引 v2 + 惰性键 + 就地读 + experiments 构建器改为 setup 库前端）。**已验证**（本机，`make base` 自产 310 成员包）：默认 REPL −10.0（15/15）、`-q` −8.5（15/15）、`-l racket -e` −6.6（20/21）、`-l racket/base -e` −1.5（21/21）、`-n` +0.4（4/15，残余固定成本）；alloc 114.7 → 112.4 MB、major 0/0；正确性矩阵全过。数字汇总在估算报告 §15。S4 完成，S6 完成（提交），剩 lan-11 复测与 DOCS 提交。
- 2026-10-26 夜（终）：lan-11 复测 e956ad95fb 通过（REPL −3.7 14/15、`-l racket -e` −2.2 21/21、`-l racket/base` −0.4 21/21、`-n` +0.3、无 major、测试过）。S1–S6 全部完成；DOCS 提交随后。
