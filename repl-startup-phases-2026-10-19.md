# Racket REPL 启动各阶段实测与优化方案（2026-10-19）

树：`racket-feat-native-pvector`（feat/repl-startup-analysis，v9.3.10，boot 文件 10-19 10:30 构建，含未提交的 pvector-fasl 改动）。机器：Apple M5 Max，macOS 25.4，热页缓存。测量期间系统 load average 2.4–10.4（其它会话在跑构建），全部取 min-of-N 或 median-of-N，A/B 交错。
工具与原始数据：scratchpad `startup-measure.py` / `startup-measure2.py` / `loadtrace.rkt` / `loadtrace2.rkt` / `ttp2.py`，结果 `results/*.json`，日志 `startup-measure*.log`、`tty-timeline.log`、`firsteval.log`。

## 0. 结论

**已验证**（本次实测）：

| 配置 | time-to-prompt（min/median, ms） | 首次求值延迟 | 备注 |
|---|---|---|---|
| python3 REPL（参照） | 17.9 / 19.4 | 0.2 | |
| `racket -q -I racket/base -i` | 46.3 / 46.8 | 7.0 | |
| `racket -q`（racket/init，无 xrepl） | 124.4 / 126.6 | 51.1 | 首次求值 = phase-1 visit |
| **默认 `racket`**（tstring→xrepl→expeditor） | **226.8 / 235.5** | 2.3 | phase-1 visit 已在提示符前支付 |
| Homebrew racket 9.3.5 默认 | 132.6 / 134.7 | 54.5 | 无 tstring/xrepl 配置 |

默认 tty REPL 的 227ms 分成四段（按 pty 时间线，已验证）：

| 段 | 墙钟 | 内容 |
|---|---|---|
| boot → banner | 25–29 | exec + 3 个 vfasl boot 文件装载 + 运行时初始化 |
| racket/init 语言层 | ~92 | 328 bundle / 1338 linklet / 6MB code 的读入、声明、实例化 |
| 交互层（tstring+xrepl+expeditor） | ~100 | phase-1 visit ~50 + syntax-color 词法器链 ~29 + expeditor 模块 ~12 + setup/缩进/命名空间/xrepl 本体 ~10 |
| 终端初始化 + 提示符 | ~3 | expeditor init-screen 0.13ms，其余为首个提示符渲染 |

CPU 口径（默认 tty REPL，`PLT_LINKLET_TIMES` / `PLT_EXPANDER_TIMES`，中位数）：linklet 层 total 127–135ms [+GC 59–61]：boot 25 / read 54 [+22]（faslin-code 38–40，1905 个 code 对象 10MB；read-bundle 11，383 bundle；literals 8）/ instantiate 42–46 [+29–35]，2229 次 / compile 2（18 个顶层 linklet）/ on-demand 2（137 次）。expander 层：resolver 36–37.5（6667 次）/ module（声明）32–33 / instantiate 46–48（734 次）/ requires 7–8 / read 15 / compile 4.5 / expand 1.0（73 个顶层形式，31 次宏）。

三个改写此前认识的结论：

1. **默认 REPL 在提示符前做了本应延迟到首次输入的工作（~50ms）**：xrepl 的 `initialize-namespace`（xrepl.rkt:1555–1570）用 `eval` 求值 12 个顶层形式（`set-saved-values-param!` + 11 个 `(require (only-in xrepl/saved-values ...))`）。expander 的第一次顶层展开调用 `namespace-visit-available-modules!`（expander/eval/main.rkt:320–324），把 racket/init 图上全部可用模块的 phase-1 实例化掉：+381 次 linklet 实例化、+300 个 code 对象（3MB）faslin、+73 个新模块。证据：`-q` REPL 首次求值 51ms vs 默认 2.3ms；instantiate 计数 244→596/734；`compile/top 18`。
2. **GC 时间（提示符处 67–74ms）不是可独立回收的量**：`PLTDISABLEGC=1` 只把 racket/init 层墙钟从 128 降到 120（−8ms），repl-default −7.7ms，而 RSS +69–74MB。推断：关掉 GC 后分配侧的缺页/缓存成本顶替了回收成本。因此"GC 旁路/推迟到提示符后"的上界约 8–20ms，不是此前预期的 34–70ms；真正的杠杆是**不分配**（镜像/少反序列化），不是改收集时机。
3. **语言层 92ms 里，声明（declare）占大头，模块体实例化只有 ~14ms**：GC 关闭的 per-linklet 自含时间 38.3ms = decl 10.3 + syntax-literals-data 9.3 + data 3.5 + syntax-literals 0.9（声明级 24ms）+ 模块体 14.3；expander `module`（声明）区 25–28ms；resolver 真实自含 11.6ms；每文件读入+声明固定成本 0.089ms（回归 `self = 0.089 + 0.00136·KB`，r²=0.20，固定项占 61%，309 文件）。所以"预声明镜像"的收益面大于"预实例化"，而且不含运行期闭包（见 §5 Q3）。

内存（`vmmap --summary` 提示符处）：physical footprint base 68MB / init 108MB / 默认 150.5MB / python3 5.2MB；其中 Chez 堆（VM_ALLOCATE 脏页）66 / 106 / 148MB，boot 文件映射 51.4MB 干净页常驻。指令数：boot 264M、base 465M、init 1282M、默认（非 tty）1889M、python3 155M。

## 1. 测量方法

- 墙钟阶梯：Python `subprocess` + `os.wait4` 取 wall/user/sys/maxrss，N=9 交错，取 min 与 median。
- time-to-prompt：pty 计时器（`ttp2.py` 逻辑内嵌于 harness）：fork 到 `> ` 出现；然后等 150ms 再送输入（30ms 时 expeditor 尚未就绪会挂）；用 `Ctrl-D` 退出以拿到退出时报告而不触发展开。首次求值延迟 = 送入 `1` 到下一个提示符。
- 内部分解：`PLT_LINKLET_TIMES`（linklet 层，CPU）、`PLT_EXPANDER_TIMES`（expander 区，嵌套自含）、`PLT_VFASL_TIMES`（boot vfasl 相位，C 层）。
- 逐 linklet：`PLT_LINKLET_TRACE_TIMES`（实例化起止，栈法算自含）；逐文件：`loadtrace.rkt`（`#%kernel` 语言包 `current-load/use-compiled`，含 .zo 字节）；resolver：`loadtrace2.rkt`（resolver 与 load 共享嵌套栈）。
- 陷阱（已验证）：
  - 本树 `-e` 会先 `dynamic-require racket/interactive/tstring-reader`（main.sps `install-command-line-interaction-reader!`），即使 `-n` 也加载 racket/base：`-n -q -e ''` 80ms vs `-n -q -v` 27–30ms。`-e` 不能当 REPL 代理；`-e '(void)'` 还包含 phase-1 visit。
  - 非 tty 的默认 REPL（`racket </dev/null` 193ms）走 readline 分支，与 tty 路径不同，不能代表交互场景。
  - 逐模块 trace 里 GC 落在谁身上谁就"变贵"（name.rkt 12ms、rand.rkt 12ms 都是 GC 假象）；逐模块归因用 `PLTDISABLEGC=1` + 多次取 min。但 GC 关闭会让 tty 层整体慢 100ms（lex.rkt 1.2→47ms），tty 层只用 GC 开的时间线。
  - trace 输出本身让 ttp 增加 5–10%。
- 未测：冷页缓存（需 `sudo purge`）。历史值（2026-09-27）：719 个散落 .zo 冷读 ~46ms。

## 2. 阶梯（墙钟，ms）

| 配置 | min | median | user | sys | RSS MB | bundle/linklet/code MB |
|---|---|---|---|---|---|---|
| `/usr/bin/true` | 2.5 | 2.7 | 0.6 | 0.8 | 1 | |
| python3 `-c pass` | 17.5 | 18.4 | 9.4 | 5.5 | 8 | |
| Chez `scheme -q`（自带 LZ4 fasl boot） | 30.0 | 31.1 | 20.6 | 8.1 | 55 | |
| Chez `-b petite.boot -b scheme.boot`（racket 的 vfasl 版） | 13.9 | 14.3 | 6.8 | 5.1 | 32 | |
| `racket -n -q -v`（boot 地板） | 30.3 | 31.0 | 18.1 | 9.1 | 120 | |
| `-n -q -l racket/kernel` | 34.7 | 35.5 | 20.9 | 10.3 | 120 | 1/3/0 |
| `-n -q -l racket/base` | 46.6 | 48.4 | 30.8 | 12.7 | 124 | 70/297/1 |
| `-n -q -l racket` | 124.0 | 125.5 | 93.3 | 23.4 | 164 | 317/1289/6 |
| `-n -q -l racket/init` | 128.0 | 130.5 | 97.5 | 24.7 | 164 | 328/1338/6 |
| `racket -q </dev/null` | 127.5 | 130.0 | 96.8 | 23.9 | 164 | 328/1338/6 |
| `racket </dev/null`（readline 分支） | 193.0 | 194.6 | 152.4 | 31.8 | 206 | 342/1698/9 |
| `-q -I racket/base -e '(void)'` | 95.5 | 97.4 | | | 153 | 171/873/5 |
| `-q -I racket -e '(void)'` | 179.4 | 182.8 | | | 209 | 327/1626/9 |
| `-q -e '(void)'` | 182.9 | 185.6 | | | 205 | |
| Homebrew 9.3.5 `</dev/null` | 134.8 | 135.6 | | | 114 | |

增量：boot→kernel +4.4（main.sps 集合路径建立、命令行、resolver 36 次 2.0ms、exit）；kernel→base +12（70 bundle）；base→racket +77（247 bundle，0.31ms/模块）；racket→init +4；init→默认 tty 提示符 +100。退出成本（首输出→退出）：boot 2.5、racket 5.0。

## 3. 各阶段细目

### 3.1 boot（25–29ms 墙钟，25ms CPU）

- vfasl 相位合计 ≈ 11.4ms（3 个 boot 文件 53MB，已验证）：room+copy 5.5–5.9（53MB memcpy，带宽界）、ptr-sweep 2.6–2.8、intern-syms 1.2–1.5、relink-code 1.0–1.3、symrefs 0.3、rtds 0.14、closures 0.1。
- petite+scheme 两段在 Chez 二进制下的全程墙钟 13.9ms（含 exec/退出）；推断 racket.boot（35MB，占 65% 字节）的 vfasl 份额约 7.5ms。
- 推断：boot CPU 25 − vfasl 11.4 − C 初始化/exec ~3 ≈ **~9–10ms 是 boot 顶层形式执行**（rumble/thread/io/expander 的 `namespace-init!` 等）。**未分解**，需要在 racket.boot 顶层加相位计时（下一测量项）。
- Chez 自带的 LZ4 fasl boot 比 vfasl 慢 16ms（30.0 vs 13.9）：vfasl 路线本身是对的。

### 3.2 racket/base 层（+12ms）

70 bundle / 297 linklet / 1MB code。linklet：read 6（faslin-code 4）、instantiate 2；expander：resolver 5.7（188 次）、module 5.7、instantiate 2.0、read 2.7。逐 linklet 自含（GC 关）：decl 2.2、syntax-literals-data 1.5、data 0.6、模块体 ~1.6。

### 3.3 racket 语言层（+77ms，247 bundle）

- linklet：read 40 [+11]（faslin-code 24，1289 code 对象 6MB；read-bundle ~7；literals 5）、instantiate 9 [+1]。
- expander：resolver 24.1（2662 次；真实自含约 10）、module（声明）25.7 [+4]、instantiate 15.7 [+3]（233 实例）、requires 3.9、read 10.6 [+7]。
- 逐 linklet 自含（GC 关，min of 3）：35.4ms = syntax-literals-data 8.9 + decl 8.7 + data 3.4 + syntax-literals 0.8 + 模块体 13.6（collects/racket 4.5、racket/private 4.3、racket/contract 3.8）。模块体最大单笔 ≤0.6ms（dict/port/set-types/arrow-val-first/class-internal）。
- 逐文件读入+声明自含（GC 关，min of 3）：init 层 309 文件合计 44.9ms，13.11MB .zo；最大单文件 init.rkt 2.08、main.rkt 1.60、kernel.rkt 1.01，其余 ≤0.63。按组：racket/private 14.6（116 文件 4.5MB）、racket 13.6（62/2.8MB）、contract 8.5（57/3.4MB）、syntax/parse 2.8（21/1.2MB）。
- resolver（loadtrace2，init+交互层）：2938 次，自含 11.6ms；p50 ≤1µs、p90 4µs、p99 46µs、max 2.75ms；最重 50 次占 5.7ms（集合路径探测）；按模块路径形态：符号 6.6、`lib` 2.8、相对字符串 2.0。`PLT_COMPILED_FILE_CHECK=exists` 对墙钟无可测影响。

### 3.4 racket/init（+4ms）

11 个 bundle（enter/help/interaction-info 等），instantiate +3。

### 3.5 交互层（+100ms，默认 tty）

在 `-q` REPL 里逐项作为连续输入实测（prompt-to-prompt 墙钟 / `(time)` cpu·real·gc），3 次：

| 项 | 墙钟 | cpu/real/gc | 说明 |
|---|---|---|---|
| 首次求值 `1`（= phase-1 visit） | 49.2–51.9 | | +381 phase-1 实例化（31ms 自含含 GC）+73 新模块（2.5）+300 code 对象 3MB faslin |
| `make-base-namespace`（xrepl.rkt:55） | 3.4 | 2/2/1 | |
| `dynamic-require xrepl/xrepl` | 3.6–3.9 | 2/2/0 | 依赖已被 racket/init 装载 |
| expeditor 模块（13 个，.zo 476KB） | 11.8–13.6 | 10–12/10–12/4–5 | |
| `syntax-color/racket-lexer` 链（含 parser-tools/lex、lexer-contract、option-contract） | 29.4–33.6 | 27–31/28–32/3–9 | 24 模块；主要是 instantiate（+14ms）+ GC（+9–21）+ on-demand 50 次，不是读入 |
| `syntax-color/racket-indentation`（+navigation） | 3.0–3.3 | 2/2/0 | |
| `setup-xrepl-environment`（expeditor open+configure+initialize-namespace，模块已预载） | 11.6–14.5 | 3–4/3–6/0 | real 高于 cpu 的部分是终端握手/首个 expeditor 提示符 |

合计 ≈ 103ms，与 pty 实测 227 − 124 = 103 吻合。tty 时间线（GC 开，ttp 221 的一次）：banner 25.2 → init.rkt 结束 118.9 → expeditor/main 实例化结束 174.0 → racket-lexer 212.6 → racket-indentation 215.3 → xrepl/main 结束 216.2 → 最后一次实例化 218.3 → 提示符 221.3。`expeditor-open` 的 `init-screen`（setupterm 等）仅 0.13ms；`get-preference` 首次 0.43ms。

### 3.6 首次求值（phase-1 visit）

`-q` REPL 首次输入 51ms；racket/base REPL 7ms。默认 REPL 因 xrepl 在提示符前展开了 12 个顶层形式而提前支付（2.3ms 首次求值）。两者之和（time-to-first-result）：默认 229、`-q` 175、base 53、python3 18。

### 3.7 GC 与内存

| 配置 | 默认 min | PLTDISABLEGC min | Δ | RSS |
|---|---|---|---|---|
| `-n -q -l racket/init` | 127.8 | 119.8 | −8.1 | 164→233MB |
| `racket </dev/null` | 192.8 | 185.1 | −7.7 | 206→280 |
| `racket </dev/null` + eval `1` | 194.2 | 189.1 | −5.1 | 206→283 |
| `-I racket -e '(void)'` | 179.1 | 159.9 | −19.2 | 208→268 |

提示符处 `current-gc-milliseconds`：默认 67–74，`-q` 52–56；但可回收墙钟只有 8–19ms。

### 3.8 `-e` 路径（非 REPL，顺带）

`racket -n -q -e ''` 80ms：tstring-reader 把 racket/base 拉进来（171 bundle），比 `-n -q -v` 多 50ms。对 `racket -e` 脚本/命令行场景是独立的回归点。

## 4. 正向优化（逐项：靶、预期、代价、验证判据）

排序按（预期收益 ÷ 改动面）。所有预期值都是推断，判据栏给出验证方法。

### F1 交互层（当前 ~100ms，可压到 ~20ms）

- **F1a xrepl `initialize-namespace` 不走展开**（xrepl.rkt:1555–1570）：把 `eval-sexpr-for-user` 的 12 个形式换成直接 API——`set-saved-values-param!` 直接调用（实例已经 `namespace-attach-module` 共享），11 个 `^/$n` 绑定用 `namespace-require`（`(only (lib "xrepl/saved-values") (saved-value-ref ^))` 形态，不经 `expand`）或 `namespace-set-variable-value!`。预期 time-to-prompt −50ms（提示符前不再触发 `namespace-visit-available-modules!`），首次求值回到 51ms（与 `-q` 一致）。代价：xrepl-lib 安装副本（用户此前决定 vendor xrepl）；需确认 `^` 等绑定仍是语法级可见。判据：pty ttp ≈ 175，`compile/top` 计数 18→0，首次求值 ≈ 51。
- **F1b 词法器链延迟**（29ms）：expeditor-configure 里的 `color-lexer`/`drracket:indentation` 只在首次击键着色/缩进时才需要。方案：把 `current-expeditor-lexer` 设为首次调用时 `dynamic-require` 的 thunk（同 tstring-reader 的做法）。预期 −29ms（首次击键 +29ms 延迟，一次性）。符合"负载由用户触发"约束（同步、由击键触发）。判据：ttp −29，首字符回显延迟实测。更深：parser-tools/lex 实例化 +14ms 与 GC +9 的成因未知（候选：DFA 表字面量、stxparam 运行期、on-demand 50 次 code 物化），值得单独剖析。
- **F1c expeditor 模块 12ms**：13 个模块 476KB；可合并（demod）或裁依赖（`ffi/unsafe/vm`、color/wstring 表的惰性构造）。预期 −5ms。
- **F1d 小项**：`make-base-namespace` 2ms（改用 `make-base-empty-namespace` + 惰性 require）、indentation 2ms（并入 F1b）、prefs 0.4ms。
- F1a+F1b 落地后默认 REPL 预期 ≈ 145–150ms（推断：227 − 50 − 29）。

### F2 语言层 racket/init（~92ms）

- **F2a 减少模块数（demod/flatten）**：固定成本面 = 每文件 0.089ms × 309 ≈ 27ms（读入+声明固定项）+ resolver 11.6 + expander `module` 区里与模块数成比例的部分（~14ms）。把 racket/init 闭包 flatten 成少数 bundle 的上界约 −40ms；历史实验（2026-08，另一树）`raco demod -s -r` 后 `#lang racket` 仍 91ms（含 boot 37）。代价：丢失子模块/phase 分离、.zo 体积、与 F2c 的交互。判据：read-bundle 计数 328→个位数，resolver 调用数骤降。
- **F2b faslin-code（24–38ms）**：per-linklet vfasl（`PLT_LINKLET_VFASL`，已落地，−9ms，.zo 2.2×）+ 修 rtd-ref 覆盖缺口（54% code 字节不能 vfasl，根因 code-info/source 记录，转换端物化即可）→ 推断再 −5–8ms。bundle 级合并已实测无收益（G1 关闭）。
- **F2c 语法字面量惰性化**：syntax-literals-data 9.3 + faslin-literals 8 + syntax-literals 0.9 ≈ 18ms 在提示符前对每个模块急切反序列化语法对象；只有展开用到该模块的宏时才需要。expander 级改动（`syntax-literals` 实例按首次 `syntax-literal` 访问惰性）。推断 −10–15ms。判据：syntax-literals-data 实例化计数 250→0（提示符前）。
- **F2d 声明开销**（expander `module` 区 25–33ms，decl 10.9 + data 3.9）：`decl` linklet 急切构建各 phase 的 provide/binding 表。惰性化 provides 表或缩小声明元数据，推断 −5–10ms。与 Q3（预声明镜像）重叠，若走 Q3 则此项由镜像覆盖。
- **F2e resolver 11.6ms**：一半在 50 次集合路径探测（多个 collection 目录 + links 表 + `file-exists?` 探测）。进程内缓存集合→目录映射（现有缓存粒度不够）或构建期生成 collects 索引表。推断 −6–8ms。判据：loadtrace2 的 top-50 自含时间。
- **F2f 模块体实例化 ~14ms**：分散（最大 0.6ms），只有快路径（Q1/Q3）能消。
- **F2g GC**：按 §3.7，推迟/旁路上界 8–20ms；此前搁置的 GC 旁路 v1（−14ms）量级一致，不再追 full-fix 的 −70 预期。减少分配（F2b/F2c、镜像）才是对 GC 的正解。

### F3 boot（25–29ms）

- **F3a** room+copy 5.5ms 是 53MB memcpy 的带宽界；只剩零拷贝映射（PIC 线已完成，`PLT_VFASL_CODE_ZC` Linux opt-in；macOS MAP_JIT 限制）或缩小 boot 镜像（53MB 含 Chez 编译器+schemify+expander，REPL 需要编译器，不可裁）。
- **F3b** ptr-sweep/relink/intern-syms ≈ 5ms：微观项，游标优化已做，剩余观察级。
- **F3c** 顶层初始化 ~9–10ms（推断）：未分解；先插桩再决定（候选：expander `namespace-init!`、io/thread 子系统的急切表、place/future 初始化）。
- **F3d** main.sps 到 kernel 的 4.4ms：集合路径建立（config.rktd/links.rktd 读取与解析）+ 单模块 resolver 36 次 2.0ms。预计算集合路径或延迟 links 解析，推断 −2–3ms。
- F3e 退出 2.5–5ms：不在提示符路径上，对 `-e` 脚本有意义。

### F4 `-e` 路径（非 REPL）

`install-command-line-interaction-reader!` 改为惰性（仅当 `-e` 字符串含 t-string 语法或首次交互时装载）：`racket -n -e` 从 80 回到 ~32ms；`racket -e` 场景省 tstring-reader 自身开销（未单测）。

### 正向优化叠加后的落点（推断）

227 → F1a/F1b −79 → ~148 → F2b/F2c/F2e/F3d −25–35 → ~115–125 → F2a demod −30–40 → ~80–90。到 50ms 以内只靠正向优化达不到（boot 29 + base 层 12 + 最小交互层已 ≥ 45，且 racket 语言层不可能压到 10ms），必须加快路径。

## 5. 快路径优化（跳过工作：镜像/缓存/延迟）

约束（用户 2026-08-23 定）：无后台 CPU、无与子进程并发的延迟工作、无不相称常驻内存；非 REPL 进程零影响。

- **Q1 第四段预实例化镜像（fasl2/seg4，进行中的主线）**：靶 = 语言层 92 + 交互层模块 ~50 + phase-1 visit 50。理论落点 boot 30 + 段装载（5MB 实测 +20ms/真启动；0.14ms/208KB 微观）+ externals 解析（targeted 0.02ms，dw-walk 51ms 不可用）+ 哈希表重建（947 表；2080 条 0.05ms）+ tty 3 ≈ 40–60ms（推断）。现状：构建侧 38MB 全态镜像可转换（route-2 已提交）；消费侧卡在 boot code 跨进程身份（内容命名不确定、位置命名覆盖 10%）。风险高、多会话；镜像 38MB 对 RSS 的净影响未知（它替代的是今天 148MB 堆的一部分）。
- **Q2 .zo 预链接镜像**：per-linklet vfasl 已落地（−9ms）；rtd-ref 修复是剩余杠杆（推断 −5–8ms）；bundle 合并无收益（已验证）。
- **Q3 预声明镜像（新提议，Q1 的子集）**：§0 结论 3 指出声明占语言层 70–80ms（read-bundle + 声明级 linklet + expander module + resolver + requires），模块体实例化只 ~14ms。只把 racket/init 闭包的**声明结果**（module 记录、binding/provide 表、syntax literals、linklet code 对象）做进镜像，启动时只做 phase-0 模块体实例化。关键优势：声明图不含运行期闭包，对 boot 代码的引用只有 rtd（uid，已解）、符号、interned scope（key，已解）、rmp/mpi（re-intern，已解）、eq-hashtable（route-2，已解）；linklet code 对象随镜像自带（.zo-vfasl 线），不需要跨进程 code 命名——seg4 消费侧的主要阻断正是实例态持有的 boot 闭包。推断落点：boot 30 + 镜像装载 ~5–10 + 实例化 14 + instantiate 区剩余 + 交互层（F1 后 ~20）≈ 80–100ms；叠加 Q1 的实例态再降。下一步可测：对 338 个声明的"只声明"图做 externals 普查（此前全态普查 1280 externals 中 closure 47 / code 30，只声明子集应更少）。
- **Q4 延迟到用户触发**：F1a/F1b 本质是快路径（把 phase-1 visit、词法器推迟到首次输入/击键），同步、用户触发，符合约束。
- **Q5 默认体验降级**：`-q`（无 xrepl）124ms、racket/base 46ms；作为策略选项列出，不是技术方案。
- **Q6 已否决**：daemon/zygote/后台预热/prompt-first 后台线程（违反三条红线）。
- **Q7 冷启动**：未测；719 个散落 .zo 的冷读历史值 ~46ms；把 collects .zo 打包成单文件（索引 + mmap）同时消 resolver 探测与磁盘 seek（推断）。

## 6. 建议顺序

1. F1a（xrepl 不展开，−50ms，几十行，xrepl-lib 副本）→ 验证 ttp ≈ 175、首次求值 51。
2. F1b（词法器惰性，−29ms）→ ttp ≈ 146。
3. F2e + F3d（resolver/集合路径缓存，−8–10ms）。
4. F2c（语法字面量惰性，−10–15ms，expander 改动）。
5. Q3 普查（只声明图 externals 计数）决定是否以预声明镜像替代全态 seg4 作为快路径主线。
6. F2a demod 与 Q3 二选一（两者都消模块数固定成本，Q3 覆盖面更大）。

## 7. 待决与未知

- boot 顶层初始化 ~9–10ms 未分解（需 racket.boot 顶层插桩）。
- parser-tools/lex 实例化 14ms + GC 9ms 的成因未知。
- `PLTDISABLEGC` 只省 8ms 的机理是推断（分配侧成本转移），未用 page-fault 计数直接验证。
- 冷页缓存未测。
- 测量期间系统负载 2.4–10.4，个别段（filecheck）受影响，已用交错 min 处理；跨会话比较仍以同时段 A/B 为准。
