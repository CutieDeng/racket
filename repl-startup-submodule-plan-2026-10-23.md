# REPL 初始化流程：子模块级性能账本与局部优化规划（2026-10-23）

树：`racket-feat-native-pvector`，分支 `feat/repl-startup-analysis`，HEAD `f36a1b8dad`（I3）。
前序报告：`repl-startup-phases-2026-10-19.md`（阶段分解）、`repl-startup-forward-logic-gc-2026-10-19.md`（分配/GC 账本）、`repl-startup-function-level-2026-10-20.md`（函数级，I1–I3）。

## 0. 结论先行

- 现状（2026-10-20 normal 构建、pty、N=20）：默认 REPL time-to-prompt 中位 179 / 最小 171ms；`-q` 105 / 103。目标 <50ms 未达，剩余 ~130ms。
- 函数级一轮（resolver/load 路径）已收口，单项剩余均 <1ms。继续下压必须换粒度：**按子模块各自建账，在子模块内部做局部改动**，不碰跨层设计（不延迟、不后台、不改默认语言）。
- 尚未做过子模块级分解的三块（推断值，来自阶段报告）：交互层 lexer 链 29–34ms、expeditor+setup-xrepl-environment 24–28ms（其中 wall−cpu 缺口 ~10ms 未解释）、racket.boot 段 ~16ms（30.3−13.9）。这三块合计 ~70ms，是本轮主攻面。
- 10-20 会话的全部量测工具（prof-startup2.rkt 等 15 个）随 scratchpad 清空丢失。本轮工具一律放进树内 `experiments/startup/`（不提交或单独提交），不再放 scratchpad。

## 1. 子模块划分与当前账本

时间列为前序报告实测或推断，未在本轮复测；标注（已验证）/（推断）。

| 编号 | 子模块 | 当前成本 | 来源 | 状态 |
|---|---|---|---|---|
| S0 | Chez 底座 petite+scheme vfasl | 13.9ms wall（已验证） | 10-19 阶段报告 | 固定成本，不动，只作扣除基线 |
| S1 | racket.boot 段：rumble/thread/io/regexp/schemify/linklet/expander 实例化 + expander boot（primitive 模块声明、根命名空间、collection paths/links 初始化、config.rktd 读取） | ~16ms（推断：30.3−13.9） | 10-19 阶段报告 | **从未分解**。候选：primitive 模块声明的 provides 表构造（#%kernel 等 1600+ 原语）、`find-library-collection-paths` 的目录探测、config.rktd 解析 |
| S2 | .zo 读路径：open/头解析/目录检索/read-bundle/fasl-read | init 步：bundle fasl-read 2.85 + 代码 fasl-read 1.7 + open 1.9ms（已验证，init 步口径） | 10-20 函数级报告 §5 | R1/C2 已落地。剩余候选 R4：bundle 元数据惰性（60K 符号 intern 为 fasl-bundle 8ms 主体，推断） |
| S3 | 模块声明：provides/requires/stx-data/命名空间簿记 | init 步 provides 建表 1.0ms；全启动声明级 ~24ms（已验证，GC 关） | 10-19 正向报告 | D1/D2 已落地，D3 不可行。剩余 D4（簿记惰性）、D5（requires 紧凑编码）、attach-declaration proxy 29KB+35µs/模块 |
| S4 | 模块体执行（phase 0 instantiate） | racket/init 层 7.8MB/6–7ms（已验证）；交互层模块体未单独计 | 10-19 正向报告 | **未按模块排名**。候选：取 top-10 自身耗时/分配的模块体，逐个看是否在实例化期做了可编译期完成的工作（正则编译、表构造、struct 属性链） |
| S5 | resolver / collection / load 包装 | resolver 区域 25.2ms（6665 次，已验证） | 10-20 函数级报告 | I1–I3 已收口；剩余 7 项均 <1ms，**关闭** |
| S6a | 交互层：xrepl `initialize-namespace` 触发的 phase-1 visit | ~50ms（已验证）：+381 实例化/+73 模块/语法字面量反序列化 ~20–25MB | 10-19 阶段+正向报告 | 用户定向不做延迟方案 → 只做 visit 本身的局部加速：deserialize-syntax 解码循环、scope/binding 批量构造与 intern（V1–V3） |
| S6b | 交互层：expeditor 初始化 | 12–14ms wall（已验证） | 10-19 阶段报告 | **未分解**。候选：历史文件读取、termios/终端能力探测、keymap 构造 |
| S6c | 交互层：syntax-color lexer 链（module-lexer→racket-lexer→parser-tools/lex 运行时） | 29–34ms（已验证：instantiate +14、GC +9–21） | 10-19 阶段报告 | **未分解**。已知边：`module-lexer.rkt` require `racket/class`、`racket-lexer.rkt` require `parser-tools/lex`（DFA 表字面量 + racket/stxparam + syntax/stx + data/integer-set + racket/promise）。候选：表字面量物化成本、phase-1 visit 连带、多余依赖 |
| S6d | 交互层：`setup-xrepl-environment`/缩进/ns | wall 12–14 / cpu 3–4ms（已验证） | 10-19 阶段报告 | **wall−cpu 缺口 ~9ms 未解释**：疑终端查询往返、子进程或 sleep。先定位缺口来源 |
| S7 | GC | 提示符前 18 次 50ms（已验证，G1/C2 后） | 10-19 收尾 | 派生量：S2–S4、S6 减分配即减 GC。独立候选：fasl 产物出生 static（根表每条目记最年轻代） |
| S8 | tty/提示符 | ~3ms | 10-19 阶段报告 | 不动 |

合计可触及面（推断）：S1 16 + S6b 13 + S6c 31 + S6d 13 + S6a 50 ≈ 123ms 中，局部改动预期可取 30–50ms；加 S2/S3/S4 的 10–15ms。到 50ms 仍需格式/声明层设计项，本轮不覆盖。

## 2. 量测工具（第一步重建，放 `experiments/startup/`）

| 工具 | 作用 | 方法要点（见前序报告附录） |
|---|---|---|
| `ttp.py` | pty time-to-prompt，默认/`-q`/`-I racket/base` 三档，N 可配，输出 min/median | 送输入前等 ≥100ms；Ctrl-D 退出；先 `uptime`，load >2 改用同二进制交错 A/B（`ab-emul.py` 法） |
| `loadtrace.rkt` | 逐模块 read/declare/instantiate 自身耗时 + 分配（`current-memory-use`/`vector-set-performance-stats!`），按真依赖后序，输出 .rktd | 相对 import 自解析；phase-1 专用模块不 `dynamic-require #f`；GC 假象用 PLTDISABLEGC + min-of-N 消，tty 层只用 GC 开 |
| `boot-stamps` | S1 分解：在 `main.sps`/expander boot 各步打时间戳（`PLT_BOOT_STAMPS` 环境变量门控，临时补丁，不提交或门控提交） | 读 `current-inexact-milliseconds` 与 `(bytes-allocated)`，输出到 stderr |
| `tty-timeline.rkt` | S6 分解：banner/init.rkt/expeditor/lexer/indent/xrepl-main/prompt 时间线，加 cpu 时间列以暴露 wall−cpu 缺口 | 同 10-19 方法，新增 `current-process-milliseconds` 列 |
| `prof-sigalrm.rkt` | 子模块内函数级定位（SIGALRM 时间采样，DEBUG 构建） | 投递滞后 ≤1000 tick；热点必须计数×microbench 复核 |
| `ab-emul.py` | 同二进制交错 A/B | 30 对交错，报逐对差中位与正向对数 |

工时：重建全部 ~2–3h（方法已在报告记录，无需重新推导）。

## 3. 执行顺序（每项 = 建账 → 定候选 → 同二进制 A/B → 子模块独立提交）

| 序 | 子模块 | 第一步 | 预期（推断） | 工时 |
|---|---|---|---|---|
| P1 | S6c lexer 链 | `loadtrace` 单跑 `(dynamic-require 'syntax-color/module-lexer #f)` 在已 visit 的 xrepl 命名空间中，分 instantiate/visit/GC 三列；看 racket-lexer DFA 表字面量物化与 parser-tools 运行时依赖各占多少 | −10–20ms | 0.5–1 天 |
| P2 | S6d setup-xrepl-environment | tty-timeline 加 cpu 列，`strace`/`dtruss` 等价（macOS 用 `fs_usage`/`ktrace`）看 9ms 缺口是 ioctl/read/subprocess 哪个 | −5–9ms | 0.5 天 |
| P3 | S6b expeditor | 同上时间线细分到 expeditor 内部（历史文件、termios、keymap） | −3–6ms | 0.5 天 |
| P4 | S1 boot 段 | boot-stamps 分解 16ms 到 rumble/io/expander-boot/collection-init 四段；expander boot 的 primitive 表构造按模块计 | −3–6ms | 1 天 |
| P5 | S4 模块体 top-10 | loadtrace 按 instantiate 自身耗时与分配排名（racket/init 层 + 交互层），逐个读源码定位实例化期可编译期化的工作 | −3–5ms | 1 天 |
| P6 | S6a phase-1 visit 局部加速 | prof-sigalrm 采 visit 窗口，分 deserialize-syntax / scope 构造 / binding intern / code 物化 | −10–15ms | 1–2 天 |
| P7 | S2 R4 bundle 元数据惰性 | 量 fasl-bundle 内符号 intern 占比，设计惰性符号表（linklet.sls 内，格式局部） | −5–8ms | 1–2 天 |

P1–P3 全在交互层库内（syntax-color/xrepl/expeditor 包），改动面与核心无关，先做。

## 4. 红线与验收

- 不引入后台工作、不把启动期动作推迟到首次输入（首次求值延迟默认 2.3ms 不得增长）。
- 每个子模块单独提交，提交信息含该子模块自身指标的前后值（如 lexer 链 instantiate ms、S1 分段 ms），不只报 ttp。
- ttp 只在 load <2 时报绝对值；否则用交错 A/B 报逐对差。
- 改 expander/rumble/io 源须重生成派生文件并与全量构建逐字节比对；改 .zo 格式须全量重编后才量。
- 触及包的测试：syntax-color-test、xrepl-test、expeditor 相关、`basic`/`module`/`file`/`path`。

## 5. 待决事项

1. S6c 若发现主因是 parser-tools/lex 的运行时依赖（stxparam/syntax/stx 等只为宏服务），处理方式是改 racket-lexer 不依赖 parser-tools（重写词法器）还是把 parser-tools 运行时瘦身——前者属包级重写，需用户定。
2. S1 若主因是 primitive 模块声明的 provides 表（约 20 个 primitive 模块），改法是把表预构造进 expander 派生产物（启动期只装载），属派生产物格式局部改动，需用户确认范围。
