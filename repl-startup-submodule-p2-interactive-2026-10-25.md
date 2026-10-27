# P2：交互层剩余账本（S6a/S6b/S6d）——前提复核（2026-10-25）

树 `racket-feat-native-pvector` / `feat/repl-startup-analysis`，HEAD `3b9b2fa279`（P1 两提交之后）。工具：`experiments/startup/tracehook.rkt`（以 `racket -i -t <hook>` 安装，`-i` 在前保住 `racket/init`；`-t` 在前会触发 `no-init!` 变成 racket/base REPL，ttp 会假降 30 ms）、`thgaps.py`、`loadtrace.rkt`。

## 0. 结论

1. **P2 前提不成立**。`setup-xrepl-environment` 没有 wall−cpu 缺口：`racket/init` 装载完成到提示符的整段 wall 50.9 ms = cpu 51 ms（真实顺序钩子，单次）。10-19 报告的"wall 12–14 / cpu 3–4"无法复现，推断当时量法把 GC 时间算出了 cpu。
2. **10-19 报告的 "xrepl `initialize-namespace` 触发 ~50 ms phase-1 visit" 在当前构建里不存在**：12 次 eval 合计 2.0 ms（每次 0.1–0.4 ms）。10-19 时间线 init.rkt 119 → expeditor 174 之间的 55 ms，现在是 6 ms（xrepl 装载 1.8 + 实例化 4.0）。消失原因未定位（推断与 D1 语法字面量惰性有关：visit 的主要分配是语法字面量反序列化 20–25 MB，D1 后不再在 visit 时发生）；缺口：没有同时段的 instantiate 计数对照。
3. 交互层现在的 51 ms 全部可归因，且除 GC 外没有 ≥ 4 ms 的单项：

| 段 | wall ms | 分配 | 性质 |
|---|---|---|---|
| xrepl 装载 4 模块 + 实例化 | 1.8 + 4.0 | 0.4 + 4.0 MB | `xrepl.rkt` 体 3.0 ms / 3.5 MB，.zo 186 KB（压缩）→ 代码物化（推断，分配量与 .zo 体积同序） |
| expeditor 装载 22 模块 + 实例化/open | 7.5 + 1.7 | 2.1 + 2.0 MB | 装载 4.6 ms 是 22 个模块的固定成本；实例化最大单项 `main.rkt` 0.31、`ee.rkt` 0.30 ms |
| lexer 链（P1 后） | 3.8 + 3.3 | 3.3 + 6.7 MB | `racket-lexer.rkt` 体 = 代码物化 |
| racket-indentation/navigation | 0.4 + ~0.5 | 2.4 MB | 含 contract-out 的 visit+eval |
| **GC 窗口关闭的 static 提升** | **26–28** | — | `PLT_STARTUP_GC_FINISH=static`（默认）；`none` 可省 26 ms 但把一次 23–29 ms major 推到提示符后首个大分配，用户已定 static |
| xrepl `initialize-namespace` 12 次 eval | 2.0 | 3 MB | 无 visit |
| 其余（expeditor-configure 收尾、prefs 读取等） | ~2.5 | — | 未细分 |

4. **全启动 CPU 账本（默认 REPL，Ctrl-D 退出报告）**：linklet 层 total 108 [+14 GC]：read 45（faslin-code 33 ms / 1676 个 / 9 MB、read-bundle 10 / 383、faslin-literals 2）、instantiate 32（1849 次）；expander 层 eval 94.5：instantiate 48.7（634）、resolver 25.7（6209 次）、module 14.4（383）、requires 5.6（4679）；read 12.9。

## 1. 对规划的修正

- P3（expeditor 12–14 ms）作废：expeditor 实例化 1.6 ms，装载 4.6 ms 是模块数固定成本（22 个），无局部项。
- S6a（phase-1 visit 50 ms）作废：当前构建里不存在。
- 交互层剩余唯一大项是 GC 关窗 26–28 ms，属 S7（fasl 产物出生 static，报告 §6 设计），不是局部改动。
- **最大的单项已验证是 faslin-code 33 ms / 9 MB（S2 读路径，正向报告的 C1：Racket faslin 3.5–4 µs/KB，裸 Chez fasl-read 的 8–10 倍，差距未定位）**。交互层每个模块体的"实例化"成本（xrepl 3.0、racket-lexer 3.8、syntax/id-table 2.9）实际都是它。建议下一步做 C1 而不是 P3/P4：定位 8–10× 差距（候选：rtd uid 查找、符号 intern、每对象 fasl 入口固定成本、代码对象重定位），任何比例的改善按 33 ms 计。
- P4（boot 段 16 ms）与 P5（模块体 top-10）保留，排在 C1 之后。

## 2. 量法记录

- `-i -t hook` 与默认 REPL ttp 一致（176.2/175.2 vs 176.0/177.0），钩子开销可忽略；`-e hook` 会把 phase-1 visit 提前到 `-e` 展开时，不能用于交互层时间线。
- `(dynamic-require m 0)`（main.sps 装 REPL init 文件的方式）= 实例化 + make available；`(void)` = visit；`#f` = 只实例化。
