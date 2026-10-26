# REPL 启动：子模块实测与收益估算（2026-10-25，新树 M10/D25/racket-repl-startup）

HEAD `8bc0e49766`（分支 feat/repl-startup-analysis）。本树为 10-25 晚重建（主线树 M08/D24 被备份清理删除，拷贝在未挂载的 PSSD 上）；Chez 由同机 python3 树的 10.4 宿主经 `SCHEME_DIR` bootquick 引导；包：racket-lib/tstring/expeditor-lib(静态链接)/compiler-lib + 9.3 catalog 的 xrepl-lib、syntax-color-lib。工具全部在 `experiments/startup/`（本次新增 `boot-stamps.py`，配合临时 `PLT_BOOT_STAMPS` 打点：boot.c 5 处、七个 .sls 各 1 处、main.sps 8 处，未提交）。

## 0. 默认 REPL 提示符前的完整时间线（`PLT_BOOT_STAMPS`，CPU=user+sys ms，7 次中位；load 4–6）

| 阶段 | CPU ms | 其中 GC | 构成 |
|---|---|---|---|
| exec/dyld → racket_boot 入口 | 3 | | 动态链接、框架映射 |
| Sscheme_init + 注册 boot 文件 | 0 | | |
| Sbuild_heap：petite/scheme/racket boot 装载到 rumble 体开始 | **17** | | Chez 基础库 vfasl 装载 + 堆建立（10-19 曾测 wall 13.9） |
| rumble / thread / io / regexp / schemify / linklet 各库体 | 2 | | io 1、schemify 1，其余 <0.5 |
| expander 库体 + expander boot（原语表、根命名空间） | 3 | | |
| main.sps：参数解析、config.rktd、集合路径/links、place 初始化 | 3 | | flags 1–2，其余 <0.2 |
| `racket/init` 装载（init-library） | **60** | 9 | 见 §1 |
| REPL init 文件：racket/interactive → xrepl → expeditor → lexer/缩进 → xrepl 12 次 eval | **43** | 7 | 见 §2 |
| 启动 GC 窗口关闭（static 提升） | **23** | 23 | 政策项 S7 |
| 合计 | ≈ 154 | 39 | ttp 实测 166–174（含 pty/终端 ~5–10） |

`racket -n -v` 全程 28 ms CPU = 上表前六行，与 wall 27.4 一致。

## 1. racket/init 层 60 ms 的构成（本树区域报告 + 进程内基准）

| 桶 | ms | 依据 |
|---|---|---|
| faslin-code（代码物化，惰性，含在 body 内） | 23–27 | PLT_LINKLET_TIMES |
| 模块体执行 | ≈8 | linklet instantiate 区域 8/1089 |
| expander `module`（声明） | 9.5 | S3 后 |
| resolver 自身 | 6.4 | resolver-hook：symbol/load 376×5.8 µs=2.2、string 3569×0.6=2.0、其余 2.2 |
| read-bundle | 5–6 | bundle-bench：310 文件暖读 5.35 ms **/ 33.4 MB 分配**；元数据 27 K import 符号 + 15 K export 符号，其中 phase1/stx-data/phase2（启动不实例化）占 20% |
| requires 递归 | 3.5 | |
| instantiate 簿记（link/access/prep） | ≈4 | |
| faslin-literals | 2 | S3 后 |
| GC | 9 | 分配驱动 |

## 2. 交互层 43 ms 的构成（10-25 早间时间线 + 本树）

xrepl 装载+实例化 6、expeditor 22 模块装载 7.5 + open 1.7、lexer 链 7（其中 racket-lexer DFA 向量字面量物化 ≈5）、缩进/导航 1、xrepl 12 次顶层 `require` 的 Chez 编译+展开 3.4、12 次 eval 2、GC 7、杂 2。

## 3. 候选优化：机制、估算、代价（估算均为推断，依据列在后）

| # | 子模块 / 改法 | 估算收益 | 依据 | 代价 / 风险 | 局部性 |
|---|---|---|---|---|---|
| A | **S7 关窗**：fasl 产物在窗口内直接出生在 static（10-19 报告 §6 设计：faslin 12 个分配点带目标代、31 处存储标脏卡、年轻引用根表已有） | −10～−15 ms | 关窗 = 拷贝 ~48 MB 存活（23 ms）；若读入产物已在 static，待拷贝量降到 ~18 MB（10-19 推算） | C（fasl.c/gc.c），GC 正确性风险高；需 `$enable-check-heap` 以外的自检 | 核心 |
| B | **C3 vfasl .zo**（`PLT_LINKLET_VFASL` 已落地、默认关） | −8～−10 ms | 10-19 实测 faslin-code 22.5→16.5、端到端 −9～−10；本树 faslin 23–27 | .zo 体积 2.2×（collects 30→~66 MB）；bundle 级合并未做（每镜像 ~10 µs 固定成本吃掉一半） | linklet 层，格式；政策决定 |
| C | **读路径分配**：bundle-bench 每轮 33 MB（文件字节 12 MB + ?）→ 定位多出的 ~20 MB（疑 code 切片/bundle 结构拷贝） | −2～−3 ms（少 2 次幼代 GC） | init-library 9 次 GC ≈9 ms，每 8 MB 一次 | 先量后改；linklet.sls 局部 | 核心 |
| D | **R4 元数据惰性**（未实例化 linklet 的 importss/exports 延迟 intern） | −1 ms | 只占符号量 20% | 格式局部 | 收益小，**不建议单做** |
| E | **集合目录缓存**（resolver symbol/load） | −2 ms | 376×5.8 µs=2.2 ms；本机空载时曾测 15.8 µs/次→上限 −6 | `root` 目录失效语义（10-20 已指出）；需绑定目录 stamp | expander/eval/collection.rkt |
| F | **racket-lexer 转移表平铺**（parser-tools `lexer` 宏改发 fxvector/bytes） | −4 ms（仅 xrepl 用户） | 5.4 ms/6.7 MB 物化，表为 `#(#(lo hi next)…)` 嵌套向量 | parser-tools-lib 外部包（改到谁内置谁） | 包内 |
| G | **xrepl initialize-namespace 改 `namespace-require`** | −3 ms（仅 xrepl 用户） | compile 2.4 + expand 0.9 区域 | xrepl-lib 外部包；语义等价（无展开、无 visit；visit 现仅 2 ms） | 包内 |
| H | **Chez 基础 boot 17 ms**：零拷贝映射（`PLT_VFASL_CODE_ZC`，P3 实测 −1.8）、缩小 scheme.boot、装载期符号 intern | −2～−3 ms | 51 MB 干净页映射 + 重定位 + intern，10-19 P3 已判"近最优" | 深 C；上限低 | Chez 核心 |
| I | expander boot + 各层体 5 ms | ≤ −1.5 | 原语模块 provides 表可批量建（D2 同法） | 派生产物格式 | 核心 |
| J | 模块体逻辑 | ≈0 | 全 racket/init 体 8 ms 分散 | | 不做 |

**合计上限（全部做完，推断）**：A+B+C+E ≈ −22～−30 ms（核心层，默认 REPL 与 `-q` 都受益）；F+G ≈ −7（仅 xrepl）；H+I ≈ −4。当前 ttp ~170 → ~135–140。<50 ms 仍不可达，与 10-19 结论一致：需要快路径（预声明镜像 Q3 / 第四 boot 段）这一级的设计。

## 4. 建议顺序

1. **C → B**：先做读路径分配定位（一次测量，半天），再按政策决定 vfasl .zo 是否默认开（体积换 −9 ms）。
2. **A（S7）**：收益最大、风险最高，独立一轮，须先恢复 10-19 报告 §6 设计（在 PSSD 上）。
3. **E**：小而稳。
4. **F/G**：内置 parser-tools-lib / xrepl-lib 后做。
5. **H/I**：最后。

## 5. 量法记录

- `PLT_BOOT_STAMPS` 的 C 侧 `CLOCK_MONOTONIC` 与 Chez `time-monotonic` 基准相差恰好 uptime（67 h），跨边界 wall 差无效，只用 CPU 列（1 ms 分辨率）。
- `-t` 在 `-i` 前会清掉 init 库；`(dynamic-require m (void))` 是 visit；bundle 读在 `read` 时已把 literals 强制。
- 本树 ttp 比旧树低（~170 vs ~180）：包集更小（无 racket-index/docs 等），不能与旧树绝对值比，只在本树内比。

## 6. C 定位结果（已验证）

`read-alloc.rkt` 逐文件回归 + 三种读法对照（310 文件 / 12.4 MB）：

| 读法 | 分配 | 倍数 |
|---|---|---|
| 文件端口 `read`（装载器真实路径） | 23.5 MB | 1.90× |
| 仅 `read-bytes` 整文件 | 14.1 MB | 1.14× |
| 读入字节串再经字节端口 `read`（bundle-bench 的量法） | 48.3 MB | 3.91× |

bundle-bench 的 33 MB 是字节端口量法的假象（字节端口 `read-bytes` 又拷一遍）。真实路径 23.5 = 文件字节 12.4 + 惰性 linklet 代码拷出 3.8（R1 设计：stx-data/phase≥1 拷出免整段留存）+ fasl 结构字节 ≈2 + 元数据（42 K 符号 × 29 B + 625 bundle × 4.3 KB）≈4 + 端口缓冲 ≈1.7。可省的只有 3.8 MB 二次拷贝（code 区按惰性/非惰性分段读），≈ 0.5 次 GC + 0.3 ms memcpy → **C 估算改为 ≈ −1 ms，不单独做**。

## 7. B 实测结果：vfasl .zo 门控当前不可用（已验证，2026-10-25 晚）

`PLT_LINKLET_VFASL=1` 全量重编（collects + pkgs + 用户作用域 rackunit 等）：.zo 总量 35.0 → 57.1 MB（1.63×；小 linklet 固定开销大：rackunit base.rkt 的 decl 3.2 KB → 25.8 KB），`raco setup` 以 SIGABRT 结束，默认 REPL 到不了提示符：`vfasl: external index out of range`，出自 `rackunit/private/base.rkt` 的 decl linklet。

定位（每步各自进程，均已验证）：
- 该 decl 的**明文 fasl 流**在不同进程里逐字节相同（进程内 compile+write 与 fresh 进程 managed compile 一致），声明 1 个 external（`#hasheq()` 字面量），literals 向量长度 1，明文可正常读。
- 同一明文在当前进程或 fresh 进程里转换得到的 vfasl 镜像**可正常装载**（任意端口偏移 0/100/4000/8192/12345 都行）。
- 安装的镜像（由 `raco setup` 进程转换）与 fresh 转换**只差 1 字节**（偏移 9337：`0xF0` vs `0x30`，所在 8 字节字 `0xF000` vs `0x3000`，即 fixnum 7680 vs 1536），位于 **code 空间**（数据区偏移 9188 ∈ [4864, 9392)），前后字相同。装载时报 external 越界。
- 结论：vfasl 转换器的输出依赖转换进程的状态（长寿命的 `raco setup` 进程里已存在的符号/gensym 等），不是 R1 切片、不是 C2 出生代（`PLT_STARTUP_FASL_GEN=0`/`PLT_STARTUP_GC_MODE=off`/`FASL_MASK=0` 都不变）、不是端口位置。可疑点：`vfasl.ss:717` gensym 复制经 `(gensym pname uname)` 取转换进程里已有的对象、`:999` `target-symbol-hash`、符号引用位置编码。10-19 的门控验证只覆盖 racket/init 闭包 + basic.rktl，未含 rackunit 这类模块；是否由今日提交引入未验证。

**B 的决定**：收益（faslin-code −8～10 ms）与代价（体积 1.63～2.2×）都成立，但门控在当前树上有正确性缺陷，须先修转换器再谈默认开启。树已重编回非 vfasl .zo。

## 8. A 实测结果：fasl 产物出生在 static（已验证，2026-10-26 凌晨，提交 826e37d386）

**结论**：默认 REPL 关窗 20.6 → 13.3 ms，窗口内 GC 12 → 14 ms，ttp 配对中位 −6.1 ms（13/15 快）。估算 −10～−15 偏高：关窗少拷的不是 §3 推算的 30 MB，静态化后关窗仍有 13 ms（存活的非 fasl 产物：声明期物化的语法对象/模块实例/命名空间表）。

### 8.1 根因（第一次 GEN=7 失败：`expeditor-read` arity 错误）

- 根表里的 static code 对象在关窗 major 之后引用陈旧。不是 W^X（A1 把开写上限提到根表最高代后仍失败）。
- 真因：`sweep_code_object` 在 `from_g == static_generation && !retain_static_relocation` 时**扫完一遍就把 reloc 表丢掉**（mkgc.ss:1152，Chez 假设 static 代码不再被扫）。出生在 static 的代码对象每次收到其引用对象的 GC 都要重扫；第二次扫时 `CODERELOC(p)==0`，一个条目都不更新 → 引用陈旧。`FINISH=none` 之前"能用"只是因为短测试还没触发第二次到达 gen 1 的收集。
- 修法（gc.c 根表循环）：扫 static code 时临时置 `retain_static_relocation=1`；扫完按 reloc 表精确算 youngest（含 CODENAME/INFO/PINFOS/ARITYMASK）；youngest ≥ 自身代时才丢 reloc 表并退表。非 code 条目 youngest 取 MIN_TG（保守）。
- 顺带消掉的代价：旧根表每次窗口 GC 全量重扫（+10 ms）；现在条目只在收集到达其 youngest 时才扫。

### 8.2 数字（同一二进制，`PLT_STARTUP_FASL_GEN=1` vs `7` 交错；本机 load 3–4）

| 量 | GEN=1 | GEN=7 | 差 |
|---|---|---|---|
| gc-window-closed（boot stamps，7 次中位 CPU） | 20.6 | 13.3 | −7.3 |
| init-library-done / repl-init-file-done | 50.6 / 36.3 | 50.9 / 36.7 | 0（重扫代价已消） |
| `PLT_EXPANDER_TIMES` eval 行 GC 列（×3） | 12, 12, 13 | 14, 14, 14 | +1.5 |
| ttp `-i`，15 对交错 | med 159.8 | med 151.5 | 配对中位 −6.1，13/15 |

### 8.3 正确性（本机）

- pty 驱动真实 tty REPL 12 步（含 300k 向量分配、两次 major、一次 minor、`require racket/list racket/string racket/match`、2M 次循环），六种配置（GEN=1；GEN=7 默认/none/static/MODE=all/MASK=512）全部输出正确、正常退出。
- 核心测试 basic/module/syntax/stx/macro/read/number/string/fasl/hash/struct 在 `GEN=7 MODE=all` 下通过（module.rktl 末尾的集合路径错误在 GEN=1、窗口关闭时同样出现，预先存在）。300 次装载 0 失败。
- lan-11（Linux x86-64）构建通过；pty/配对 ttp 结果见 §8.4。

### 8.4 lan-11 结果（Linux x86-64 Zen 5，空载，同一二进制 826e37d386）

- 构建通过（gc.c 为跨平台 C 改动）。
- 真实 tty REPL 12 步脚本（Linux 无 expeditor，走普通 REPL 路径）：GEN=1、GEN=7 默认/major/none/MODE=all/MASK=512 六配置全部正确、正常退出。100 次装载（`MODE=all`，该树未装 xrepl 故不含 `-l xrepl`）0 失败。
- ttp `-i`（无 xrepl 的普通 REPL）15 对交错：GEN=1 med 110.5 → GEN=7 med 106.1，配对中位 −4.2 ms，14/15 快。

## 9. E 实测结果：集合目录缓存不做（已验证，2026-10-26）

安全守卫计数（`experiments/startup/guard-count.rkt`，`-l racket/init -l racket/interactive`，两工具一致）：

| who | 次数 | 单次（microbench，暖缓存） | 合计 |
|---|---|---|---|
| `current-load-relative-directory` 参数设置 | 3807 | 0.19 µs（parameterize 整体） | 0.7 ms；来源=语法字面量反序列化/`define-runtime-path`，非 resolver |
| `directory-exists?` | 599 | 0.8–1.05 | ≈0.6 ms |
| `file-exists?` | 545 | 0.85–1.1 | ≈0.5 ms；其中 357 次是两个 links.rktd 的 `file->stamp` 前置存在性检查 |
| `file-or-directory-stat` | 356 | 2.3（I2） | ≈0.8 ms（links 戳） |
| `file-or-directory-modify-seconds` | 539 | ≈1 | ≈0.5 ms（compiled-load 的 .zo/.rkt 时间比较） |
| `open-input-file` | 290 | — | 真实装载 |

典型一次 `racket/x` 符号查找 = 用户 collects 目录探测（`~/Library/Racket/9.3.10/collects` 不存在，128 次全 miss）+ 主 collects 目录 hit + 子目录 + 文件 + 2 个 links 文件 ×（file-exists? + stat）≈ 7–8 次系统调用 ≈ 8 µs，与 resolver-hook 的 symbol/load 329 次自身 2.5 ms（7.7 µs/次）一致。

**结论**：全部 fs 探针合计 ≈ 2.5–3 ms，没有单一主项；语义不变能做的只有 links 戳合并 file-exists?+stat 为一次 stat（−0.35 ms）、过滤不存在的用户 collects 目录（−0.15 ms，且改变"会话中新建目录即可见"的语义）。E 上限 ≈ −1 ms，不立项。resolver 的另一半是 `string` 形态 3612 次 ×0.9 µs = 3.2 ms（相对路径拼接 + resolved-module-path 驻留，非 fs），归入 I。

## 10. F/G 实测结果（2026-10-26 上午）

前置：xrepl-lib、parser-tools-lib 已内置（f4f922b18b，与 expeditor-lib 同法；安装侧改为 static-link，`raco setup parser-tools syntax-color xrepl expeditor racket`）。

### G：xrepl `initialize-namespace` 改 `namespace-require`（已提交 ca5ba84bfa）

- 11 个 `(require (only-in xrepl/saved-values [saved-value-ref name]))` 的 `eval` 改为原始 require spec `(namespace-require '(rename xrepl/saved-values name saved-value-ref))`；第一个 `eval`（`set-saved-values-param!` 宏，写用户命名空间的 phase-1 变量）保留。
- microbench：12 次 eval 2.4 ms → 12 次 namespace-require 0.03 ms。
- 默认 REPL（同二进制，只换 xrepl_rkt.zo 交错）：`PLT_EXPANDER_TIMES` compile 2.1–2.3 → 1.2–1.3 ms、expand 0.8 → 0.4；ttp 配对中位 −2.2 ms，10/15（load 3–4）。`^ ^^ ^^^ $1 ,help` 行为不变。
- 量法陷阱：第一次 A/B 的 A 组 compile 56 ms/expand 53 ms 是 .zo 比源旧被装载器从源编译（mtime 陷阱再次出现），touch 后消失。

### F：parser-tools `lexer` 转移表平铺——不做（已验证后放弃）

§3 的"5.4 ms/6.7 MB 物化"是把 P1 报告里整条 lexer 链的 declare+visit 数字误记到了表上。实测 racket-lexer 模块 phase-0 体（deps 先实例化）：

| | 嵌套向量（上游） | 每状态一个 fxvector |
|---|---|---|
| 体实例化（含首次代码物化） | 2.7–3.1 ms / 7.0 MB | 2.1–2.4 ms / 3.9 MB |
| 体执行（300 次重复实例化，attach 依赖，采样器） | 1.63 ms | 1.56 ms |
| racket-lexer_rkt.zo | 172 KB（表作为代码对象常量，`#(lo hi next)` 条目经 transition-cache 去重后共享） | 1075 KB（fxvector 无法共享，经 racket/fasl 字面量 1085 个/1.0 MB） |
| 词法输出 | 3 个文件 token 流 sha1 相同 | |

体执行 1.6 ms 的构成（采样）：≈50% 在 linklet 实例化内部无 Racket 帧（代码/常量物化）、≈20–25% `lexer-contract.rkt:76 run-tester`（option-contract 的 tester 在合同施加时用随机字符串跑一遍词法器：`char-at-random`/`build-string`）、≈7% `racket-tabify.rkt`、≈10% contract 构造（arr-i `build-??-args`、`and/c`）。表编码只影响首次物化的 ≈0.5 ms，换 .zo +0.9 MB，放弃；lex.rkt 已回退，parser-tools-lib 仍内置（无害）。可做但未做：syntax-color-lib 的 option-contract tester（≈0.4 ms，需内置 syntax-color-lib）。

### 估算 vs 实测汇总（A–G）

| 项 | §3 估算 | 实测 ttp | 状态 |
|---|---|---|---|
| A fasl 产物出生 static | −10～−15 | −6.1（本机）/ −4.2（lan-11） | 提交 826e37d386 |
| B vfasl .zo | −8～−10 | 门控有缺陷 | 未做 |
| C 读路径分配 | −2～−3 | 上限 −1 | 不做 |
| E 集合目录缓存 | −2 | 上限 −1 | 不做 |
| F lexer 表平铺 | −4 | ≤ −0.5，.zo +0.9 MB | 不做 |
| G xrepl 不 eval | −3 | −2.2 | 提交 ca5ba84bfa |

## 11. H 实测结果（2026-10-26 上午）

`racket -n` 的 boot 段（c-boot-registered → rumble 体）≈21 ms CPU，其中 vfasl 相位（`PLT_VFASL_TIMES`，空载本机）≈12 ms：room+copy 5.9、ptr-sweep 2.8、intern-syms 1.5、relink 1.3、其余 <1；余下 ≈3.5 ms 是 petite/scheme 顶层初始化与 racket.so 的 rumble 前顶层。exec→C 入口 5 ms CPU 里 CoreFoundation 的动态链接占 ≈1.5。

### H1 符号表预扩容 + 先比哈希（已提交 27db46e51d）

- 根因：oblist 初始 4096 桶，只在 GC 后扩容；boot 镜像 ≈45k 符号全部驻入 4096 桶（链长 ≈11），每个符号比名串。`S_intern4` 原先无条件解引用名串再逐桶比名。
- 改法：vfasl 驻留前按镜像符号空间预扩容（`S_resize_oblist_for`）；`S_intern4` 先比 `SYMHASH` 再碰名串。
- 实测 intern-syms：本机 1.52 → 1.29 → 1.02 ms（三个运行时交错 12 次中位）；lan-11 2.0 → 1.5。vfasl 总 12.3 → 11.9。
- ttp：lan-11 15 对交错 +0.2 ms（8/15），**不可见**。本机 load 9–16（Spotlight 索引）当日不可测。

### H2 CoreFoundation 延迟装载（已提交 cfb7955caf）

- rktio 只在 `system-language+country`/locale 大小写/locale 排序三处用 CF，均不在启动路径；但 `-framework CoreFoundation` 让每个进程在 `main` 前多做动态链接：空 C 程序 2.5 ms（iconv+ncurses）vs 4.1 ms（+CF），40 次中位。
- 改法：11 个 CF 函数 `dlopen`/`dlsym` 首次使用时解析；可执行文件、Racket.framework、rktio 三处链接标志去掉（configure.ac + 生成的 configure 同步改）。`otool -L` 不再列 CF；`DYLD_PRINT_LIBRARIES` 显示 CF 在启动路径上为 delayed，首次 `string-locale-upcase` 时真正装载。
- 实测 `racket -n`（两运行时交错 20 次，load 12）：wall 29.3 → 27.6、CPU 25.7 → 24.5；ttp 15 对 +30 ms/14 of 15 是负载伪影（两组 min 相同 152.3/152.5），推断真实收益 ≈ −1.5 ms，待空载复测。locale 三函数输出不变；string.rktl/basic.rktl 通过。
- Linux 无此项。

### H 未做

- `PLT_VFASL_CODE_ZC`：P3 已判 macOS 不可行、Linux 净慢 2 ms，维持 opt-in。
- 缩小 scheme.boot（Chez 编译器 7 MB）：Racket CS 运行期 `compile` 依赖，且 vfasl relink 需库条目先注册，延迟装载是架构改动，不属 H。
- room+copy 5.9 ms = 50 MB 拷入 MAP_JIT/匿名页（≈3200 次缺页 + memcpy），已近硬件界。

## 12. I 实测结果：resolver `string` 形态无杠杆（2026-10-26 午前）

- D2（provides 批量建表）早已提交（495560107a），I 只剩 resolver。
- 真实单次成本（空载 microbench，`(current-module-name-resolver)` 直接调用，load?=#f）：string 缓存命中 0.16–0.30 µs，未命中 1.0–2.0 µs；symbol 命中 0.12，未命中（集合查找）11 µs。
- 启动后抽查 `"private/base.rkt"`/`"pre-base.rkt"`/`"stx.rkt"` 等高频键均为命中（0.17–0.30 µs）。resolver-hook 报的 string 形态 0.89 µs/次自身时间主要是钩子本身（两次取时+hash+形态判断 ≈0.5 µs）与冷缓存，不是 resolver 的工作。
- 量法陷阱：用钩子复刻缓存键去判"命中/未命中"时，钩子装在 `-I racket/base` 之后，核心模块的装载早于钩子，复刻表把它们全判成未命中（2696/3612），结论错误；直接测调用成本才是判据。
- 曾试两代缓存 + 已声明模块非装载也缓存（handler.rkt），因启动期只有 298 个键远低于 1024 的冲刷阈值、且高频键已命中，无收益，已回退未提交。
- 结论：string 3612 次真实成本 ≈1 ms，不做。

### A–I 总表（ttp，本机默认 REPL）

| 项 | 估算 | 实测 | 提交 |
|---|---|---|---|
| A fasl 产物出生 static | −10～−15 | −6.1（lan-11 −4.2） | 826e37d386 |
| B vfasl .zo | −8～−10 | 门控缺陷 | 未做 |
| C 读路径分配 | −2～−3 | ≤ −1 | 不做 |
| E 集合目录缓存 | −2 | ≤ −1 | 不做 |
| F lexer 表平铺 | −4 | ≤ −0.5，.zo +0.9 MB | 不做（回退） |
| G xrepl 不 eval | −3 | −2.2 | ca5ba84bfa |
| H1 符号表预扩容 | — | vfasl −0.5，ttp 0 | 27db46e51d |
| H2 CF 延迟装载 | −2～−3（H 合计） | boot −1.5（推断，待空载） | cfb7955caf |
| I resolver | ≤ −1.5 | ≈0 | 不做 |

本轮合计 ≈ −10 ms（A+G+H2），默认 ttp 空载 ≈ 150 ms。估算系统性偏高 2–5×，原因：把链路级数字（declare/visit）记到了单组件上（F）、把钩子开销记到了被测项上（I）、把"数量×单价"里的单价取了含负载的值（E）。

## 13. S4（racket/init 装载）正向分析：第一轮测量（2026-10-26 下午，已验证）

默认 REPL 模块集 = racket/base + racket/interactive + xrepl + syntax-color/racket-lexer 链（非 tty 装载，与 tty 路径差 expeditor 初始化与提示符前工作）。

| 问题 | 量法 | 结果 |
|---|---|---|
| 物化了多少代码 | Chez `object-counts`（boot 静态代码不计） | 17,440 个代码对象 / 15.5 MB（racket/base 单独 2,520 / 2.2 MB） |
| 其中提示符前被执行多少 | `racket -M` 机器无关 .zo（独立 `PLTCOMPILEDROOTS`）+ `PLT_CS_JIT=1 PLT_LINKLET_SHOW_JIT_DEMAND=1`，数按需编译的 lambda | **1,161 个被进入 ≈ 6.7%**；≈93% 的过程提示符前从未执行 |
| phase≥1 体在提示符前占多少 | expander 区域按 phase 拆分（body0/body+，临时插桩） | 真实 tty REPL：body0 23–24 ms / 441 次，**body+ 10.7–10.9 ms / 189 次**；非 tty 模块集 body+ 7.2–7.8 / 132 |
| 顶层 `namespace-require` 是否急切 visit | 读 expander（namespace/api.rkt:115） | 否（`#:visit? #f`）；189 次 phase≥1 实例化来自模块体内的 `dynamic-require`/`for-syntax` 依赖与 xrepl 的求值，不是顶层 require 语义 |

推论（推断，待各自实现后实测）：
- 定义粒度惰性代码物化：faslin-code 27–30 ms 中按对象数 93% 未执行；若字节比例相近，上限 ≈ −25 ms，且常驻代码 15.5 MB → ≈1–2 MB。这是 S4 最大的单项。
- phase≥1 体推迟到首次展开：−11 ms（tty），首次求值相应 +11。
- 10-19 用 loadtrace 强制 visit 得到的 20+6+7=33 ms 是"全部 visit"的上限，不是提示符前的实际值（11）。

顺带修复：`racket -M` 机器无关编译在本树失效（recompile cache 对 MI 输出求 target-machine 摘要），64ea6ccea7。

补充（同日，tty REPL，临时 'decl/'data 区域）：`module` 区 11.5 ms = **decl linklet 实例化 7.1–7.2**（379 个，provides/requires 表，分配 9.9 MB）+ data linklet 2.8（mpi 向量等）+ 其余 ≈1.5。惰性 provides 表的上限 ≈ −7 ms。

## 14. S4 第二轮：用现成的惰性机制做杠杆实验（2026-10-26 傍晚，已验证）

目标：验证"定义粒度惰性代码物化"能否吃掉 faslin-code 27–30 ms。Racket CS 已有两种按 lambda 惰性的编译模式，直接拿来当实验载体（REPL 闭包 305 个模块编进独立 `PLTCOMPILEDROOTS`，运行时以安装 root 作回退）：

| 模式 | 机制 | faslin-code | 物化代码对象 | tty REPL eval 区域 | 判决 |
|---|---|---|---|---|---|
| 安装 .zo（基线） | 整 linklet 机器码，R1 切片 | 29–30 | 17,435 / 15.5 MB | 77（instantiate 39 = body0 24 + body+ 11；module 11；resolver 22） | — |
| `PLT_CS_JIT`（编译期+运行期） | 外层解释，每个 lambda 存源码，首次调用时编译 | 11–19 | — | on-demand 373 + compile-pass 336 + schemify 62 ⇒ 总 ≈1 s | 真 JIT，不是杠杆 |
| `PLT_CS_COMPILE_LIMIT=1`（'mach 超限路径） | 外层解释（interpretable），每个 lambda 预编译成机器码字节串，首次调用时 fasl-read | 11–18 | **4,870 / 4.4 MB（−72%）** | **105**（instantiate 63 = body0 44 + body+ 14；分配 52→121 MB，GC 3→17） | 物化省了，但外层解释 + 变量间接把它吃回去还倒贴 ≈28 |

补充事实：
- 超限路径下 expeditor 装载失败：`hash-ref: no value found for key 'terminal-init`（expeditor-lib/private/terminal.rkt:46 直接引用 `#%expeditor` 原语表项，解释模式的原语解析查不到）；实验里 expeditor 从安装 root 回退装载。
- 进入过的 lambda 1,161 vs 超限模式物化 4,870：差额是 jitify 的包装过程/外层壳对象与每 linklet 的固定对象，不是执行差异。

**结论**：
1. 杠杆本身成立：按需物化把代码对象从 17.4k 降到 4.9k，faslin-code 29 → 11–18。
2. 现成载体不可用：两种模式都以"外层体解释"为前提；要兑现收益必须新造机制——外层体照常编译，只把每个顶层 `define` 的 lambda 变成"首次调用时从 .zo 切片 fasl-read 真代码并替换自身"的包装过程（jitify 的 `$make-wrapper-procedure` + `force-wrapped-code` 已有，差的是 schemify 侧只对顶层定义做转换、不解释外层）。
3. 代价未测：顶层定义之间失去 cp0/schemify 跨定义内联与 known-call 直呼（库热路径如 `map`/`sort` 可能变慢），须按 R10 预算（≤5%）用基准集验收；首次调用多一次 fasl-read（~µs 级）。
4. 预期（推断）：faslin-code −15～−20、常驻代码 −10 MB；body0 不变；实现量=schemify 一个 pass + linklet.sls 装载侧 + .zo 格式（每定义切片索引），中等。

ttp 交错 15 对（expeditor 从安装 root）：安装 .zo med 169.2 vs 超限模式 212.8，配对 +44 ms，15/15 更慢（load 3）。

## 15. 启动包实测结果（2026-10-26 夜，已验证）

实现见 repl-startup-pack-dev-2026-10-26.md（定案）与 repl-startup-pack-design-2026-10-26.md（扫描）。提交链 670bff1ce1 → 1555447f3e → 9ea96119cf → e956ad95fb。以下全部为同一二进制、`PLT_STARTUP_PACK=off` 对默认位置包、交错配对；包为 `make base` 自己的 `raco setup` 写出的 310 成员版（构建配置看不到 pkgs，xrepl/expeditor/lexer 根缺席）。本机 load 3–4。

| 进程 | 关 (med ms) | 开 (med ms) | 配对差 | 开更快 |
|---|---|---|---|---|
| 默认 tty REPL ttp | 153.5 | 143.8 | **−10.0** | 15/15 |
| `-q -i` ttp | 97.2 | 89.2 | **−8.5** | 15/15 |
| `-l racket -e '(void)'` 到退出 | 119.5 | 113.0 | **−6.6** | 20/21 |
| `-l racket/base -e '(void)'` 到退出 | 42.2 | 41.1 | **−1.5** | 21/21 |
| `-n -e '(void)'` 到退出 | 27.6 | 27.8 | +0.4 | 4/15 |

区域（`-l racket -e`，关 → 开）：resolver 18.5 → 9.4 ms；pack 区域 3.2 ms/317 命中；eval 59.9 → 53.2；read 区域 20.7 MB 不变。GC（`-W debug@GC` atexit）：alloc 114.7 → 112.4 MB，minor 13 → 13，major 0 → 0。

残余固定成本：`racket -n` +0.4 ms = 打开包 + 读 300 B header + 解码 310 项二进制索引 + 建三张表；若要归零需索引惰性解码（未做，收益上界 0.4 ms）。

过程中的两次回归（均已修，见 dev 文档进度日志）：v1 s-exp 索引使 `-l racket/base -e` 慢 3.8 ms（0/15）；成员经字节串 + `open-input-bytes` 双拷贝使 `-l racket -e` 多 26 MB 分配、在 GC 窗口外触发 major，慢 14.9 ms（0/15）。两者在 REPL ttp 里都不可见（分别被更大的收益掩盖 / 被窗口内只收 gen0 掩盖），所以**验收矩阵必须包含非 REPL 到退出的进程**。

正确性矩阵（包开）：核心测试 basic/syntax/stx/macro/read/number/string/fasl/hash/struct 全过（module.rktl 尾部 #f 为预先存在）；子模块程序（configure-runtime/main/reader）、place 内 require 成员、`dynamic-require` 子模块、`raco make` 旁路、pty REPL、300 次装载 0 失败、哨兵往返（`raco make` 改成员 → 关闭；`raco setup` 重建 → 恢复）、`--verify` 0 mismatch。

lan-11（Linux x86-64 Zen 5，最小安装，无 xrepl/expeditor，plain REPL；同一提交 e956ad95fb，`make base` 自产 310 成员包，已验证）：

| 进程 | 关 (med ms) | 开 (med ms) | 配对差 | 开更快 |
|---|---|---|---|---|
| 默认 REPL ttp | 106.3 | 102.8 | **−3.7** | 14/15 |
| `-l racket -e '(void)'` 到退出 | 113.2 | 111.0 | **−2.2** | 21/21 |
| `-l racket/base -e '(void)'` 到退出 | 42.0 | 41.7 | −0.4 | 21/21 |
| `-n -e '(void)'` 到退出 | 30.5 | 30.9 | +0.3 | 2/15 |

alloc 114.3 → 111.5 MB，major 0/0；核心测试 basic/syntax/macro/read/fasl/struct 过（module.rktl 尾部 #f 预先存在）、`--verify` 0 mismatch、子模块 `dynamic-require` 正常。Linux 收益比 macOS 小（文件系统 stat/open 更便宜，且该安装的 REPL 闭包更小）。

未测：冷缓存（需 `sudo purge`）。
