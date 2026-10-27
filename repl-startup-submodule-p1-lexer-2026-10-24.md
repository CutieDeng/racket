# P1：交互层 lexer 链（S6c）建账与局部优化（2026-10-24）

树：`racket-feat-native-pvector` / `feat/repl-startup-analysis`，HEAD `f36a1b8dad`。规划：`repl-startup-submodule-plan-2026-10-23.md`。
工具（树内 `experiments/startup/`）：`loadtrace.rkt`（declare / phase-0 instantiate / visit 两段分解，按依赖后序）、`tracehook.rkt`+`thgaps.py`（真实默认 REPL 内的装载/求值时间线）、`ttp.py`（pty time-to-prompt）、`ab-swap.py`（同二进制交错 A/B，换单个 .zo 文件）。

## 0. 结论

| 指标 | 改前 | 改后 | 差 |
|---|---|---|---|
| 默认 REPL time-to-prompt 中位（交错 A/B，15 对，load 3.7–4.1） | 197.4 ms | 184.1 ms | **−14.5 ms（逐对差中位，15/15 为正）** |
| 同上 最小 | 190.0 | 178.9 | −11.1 |
| lexer 链在真实 REPL 时间线中的段（装载 23 模块 + 实例化） | 3.8 + 14.4 ms / 3.3 + 22.4 MB | 3.8 + 3.6 ms / 3.3 + 6.4 MB | −10.8 ms / −16 MB（已验证） |

改动：expeditor `expeditor-configure` 不再 `(dynamic-require 'syntax-color/racket-lexer 'racket-lexer)`，改为取 `racket-lexer/status`（文档化的普通变量导出）并丢弃第 6 个返回值。功能验证：默认 REPL 求值、着色正常；xrepl 测试集结果与改前一致（interaction #23 的错误信息文本不匹配为预先存在，改前改后同）。

**交付（2026-10-25）**：`expeditor-lib` 原为外部 catalog 包（github.com/racket/expeditor @65e20a41），用户决定内置。提交 `2f9a17c215`（BUILD：上游原文拷入 `pkgs/expeditor-lib`，Makefile `PKGS`/`REQUIRED_PKGS` 加入；`main.zuo` 的本地 `pkgs/` catalog 优先于官方 catalog，与 tstring 同机制）、`eda1da9529`（FEAT：lexer 改取变量导出）。安装已切为 static-link（`raco pkg update --static-link pkgs/expeditor-lib`，8.6 s）。内置后复测交错 A/B 15 对：中位 192.6 → 179.5 ms，逐对差中位 −13.4 ms，15/15 为正。补丁文件 `experiments/startup/patches/expeditor-lexer-no-visit.patch` 保留作上游 PR 底稿。

## 1. 机制（已验证，expander 源码 + A/B）

`racket-lexer` 经 `contract-out` 导出 → 是**语法**导出（`module->exports` 列在 syntax 一侧）。expander `eval/dynamic-require.rkt` 对语法导出的处理：

1. `namespace-module-visit!`：把 `syntax-color/racket-lexer` 在 phase 1 实例化。visit 递归规则（`namespace/module.rkt` `run-module-instance!`）：phase-0 require 的模块跑其 phase-1 体；for-syntax require 的模块在 phase-1 实例里跑其 phase-0 体，再沿其 phase-0 边递归。于是 parser-tools/lex 的编译期依赖（deriv/re/front/stx/util/unicode-chars、syntax/id-table、syntax/boundmap、data/integer-set、syntax/parse/experimental/*、syntax/contract）全部在 phase 1 实例化。
2. `new-namespace` + `namespace-require` + `eval sym`：在新命名空间里展开该标识符宏（contract-out 的导出宏）并编译运行。

变量导出走 `namespace-get-variable`，无 visit、无 eval；且 `#:otherwise-available? #f`，phase-1 依赖不会被标为 available，没有延后到首次输入的隐藏成本。

A/B（`-I racket/init -e`，4 次）：`'racket-lexer` 37.9 ms / 27.8 MB / GC 22 ms；`'racket-lexer/status` 24.5 ms / 11.8 MB / GC 16 ms → visit+eval = **13.4 ms / 16 MB**。

门面（facade）方案无效：把 contract-out 放到只 require 核心模块的薄模块里，visit 门面仍递归 visit 其 phase-0 require（核心模块）→ 38.6 ms / 28 MB，与直接取 `racket-lexer` 相同。要避开 visit 只能是变量导出，或消费者改取变量导出。

## 2. lexer 链账本（`loadtrace.rkt`，`-I racket/init -e` 环境，两次运行一致 ±5%）

| 段 | 模块数 | ms | MB | 说明 |
|---|---|---|---|---|
| A declare（读 .zo + 声明，全相位） | 23 | 6.7–6.9（其中装载器自身 3.9，余为工具的 `module->imports` 遍历） | 7.0 | 真实时间线里 3.8 ms / 3.3 MB |
| B phase-0 实例化 | 7 | 4.7–5.0 | 7.8 | `racket-lexer.rkt` 体 3.8–4.1 ms / 6.6 MB；lexer-contract 0.28/0.39；option.rkt 0.16/0.31 |
| C(a) phase-0 体在 phase 1 实例化（visit 引起） | 15 | 5.5 | 8.6 | `syntax/id-table` 2.9 / 4.3 MB；`syntax/parse/experimental/contract` 0.6 / 1.0；`data/integer-set` 0.4–0.5 / 0.8；`syntax/boundmap` 0.3 / 0.9 |
| C(b) phase-1 体（visit 引起） | 7 | 2.2–2.3 | 5.5 | `parser-tools/lex` phase-1 体 1.4–1.5 / 4.4 MB；`racket-lexer` 0.43 / 0.73 |

**推断**：B/C 的大头是各 linklet 首次实例化时的代码物化（faslin），与模块体逻辑无关——`racket-lexer_rkt.zo` 185 KB（压缩）含 4 个生成的 DFA 词法器；`syntax/id-table`、`lex.rkt` phase-1 体同理。证据：分配量与 .zo 体积同序、与模块体内容不成比例；缺口：未逐 linklet 量 faslin 时间。

C(a)+C(b) ≈ 7.7 ms / 14 MB，加上新命名空间+宏展开+编译 ≈ 5 ms，与 A/B 差 13.4 ms / 16 MB 一致。

## 3. 真实 REPL 时间线（`tracehook.rkt`，`racket -e <hook> -i`，hook 安装点 = racket/init 已装载且已被 `-e` 触发 phase-1 visit）

改前（ms 自 hook 起 / 累计 CPU）：xrepl 装载 0.8–1.6 → xrepl 实例化缺口 2.75 ms/3.9 MB → expeditor 装载 4.3–7.7 → expeditor 实例化+open 3.25 ms/2.1 MB → tstring interaction-info 10.9 → **lexer 链装载 11.2–15.0，实例化+visit 缺口 14.4 ms / 14 CPU / 3 GC / 22.4 MB** → racket-indentation/navigation 29.4–29.8 → 缺口 30.9 ms（其中 GC 28 = 启动 GC 窗口关闭时的 static 提升，非本链）→ xrepl `initialize-namespace` 12 次 eval 60.7–62.7（2 ms CPU；visit 已被 `-e` 提前支付）。

改后：lexer 链实例化缺口 3.59 ms / 6.4 MB；其余段不变。

## 4. 未做 / 待决

1. **交付**：已内置（见 §0）。原则（用户 2026-10-25 定）：启动关键路径上要改的外部包，改到谁就内置谁，不预先全收；xrepl-lib、syntax-color-lib 到 P2/P1-b 时再按此处理。
2. **P1-b（syntax-color 局部，推断 −1.5–2 ms / −3 MB）**：`racket-lexer.rkt` phase-0 体 3.8–4.1 ms / 6.6 MB 中含 nobar 变体（scribble 用）与 bar 变体各自的 DFA；拆 nobar 到独立模块可少物化一半代码。未量，属 syntax-color 包内改动。
3. **racket-indentation**：`racket-amount-to-indent` 同为 contract-out 语法导出，dynamic-require 2.1–2.3 ms / 2.4 MB（含声明 4 模块 1 ms）；无变量导出可替代，若要省需 syntax-color 加变量导出。
4. **通用现象**：任何对 contract-out 导出名的 `dynamic-require` 都付 visit + 新命名空间 eval；库内 `lazy-require`/`dynamic-require` 取 contract-out 名字的地方可按同法排查（未扫）。
5. 工具教训：`(dynamic-require m (void))` 是 visit 不是"只声明"；只声明用 `(module-declared? <module-path> #t)`，且必须是 module path 不能是 resolved path；`module->imports` 的相对 mpi 要重接到模块自身名上才能 resolve；A/B 换 .zo 时 .zo mtime 必须比源新，否则装载器静默改为从源编译（+95 ms 假差）。
