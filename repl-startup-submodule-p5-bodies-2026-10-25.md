# P5：模块体 top-10 → 结论改写为"实例化开销账本"（2026-10-25）

工具：`experiments/startup/loadtrace.rkt`（`LT_SKIP_C=1`，`-I racket/base` 起步，按依赖后序逐模块 `dynamic-require` 增量）、`faslbench.rkt`（`FB_DUMP` 逐 linklet 暖 fasl-read）、`expander-times.py`、`resolver-hook.rkt`（按调用形态统计 resolver 自身耗时，扣除装载器时间）。提交 `expander: finer instantiate performance regions`（instantiate 区域拆 prep/link/access/body）。

## 0. 结论

1. **模块体逻辑不是目标**：linklet 层 `instantiate`（真正跑模块体）对整个 racket/init 闭包合计 8 ms / 1089 个 linklet（`-I racket/base -l racket/init` 退出报告）。逐模块增量排名里的"大项"都是别的东西：
   - `racket/interactive.rkt` 26.6 ms = 其中一次 21 ms major GC + 动态加载 xrepl；
   - `syntax-color/racket-lexer` 5.4 ms / 6.7 MB = 4 个 DFA 词法器的转移表（`#(#(lo hi next) …)` 嵌套向量字面量）的物化，暖 fasl-read 2.07 ms + 冷态/分配；
   - `racket/private/set-types` 1.7、`racket/private/unit/runtime` 1.4、`racket/dict` 0.7：含被它们首次拉起的未计入依赖（unit/runtime 单独拉起 142 个 bundle）与 generics/struct 表构造；真体量 ≤ 1 ms 级。
   - 其余 140 个模块各 0.17–0.4 ms 的长尾 = 每模块固定成本（expander 簿记 + 代码物化），不是模块逻辑。
2. **expander 自身的每模块开销很小**（新子区域，默认 REPL，3 次）：instantiate 50.6 ms / 634 次 = body 44.7（= 惰性 faslin-code ~29 + literals ~4 + 模块体 ~8）+ link 1.9 + access 1.7 + prep 1.3。
3. **resolver 自身**（整启动，扣除装载器时间，含包装开销）12.4 ms / 5763 次：`symbol/load`（集合路径查找）426 次 × 15.8 µs = 6.7 ms 是唯一的块；`string`（相对路径）3854 次 × 0.6 µs = 2.5；其余 < 1.5 ms。
4. 正则字面量：134 个，全部重编译 0.39 ms，不是目标。

## 1. 当前默认 REPL 的 CPU 账本（提示符前，~100 ms，本机 load 4–5 时的区域值）

| 桶 | ms | 状态 |
|---|---|---|
| boot（S1） | 25–30 | 从未分解（P4） |
| faslin-code（代码物化） | 29 | 读取器已 −24%；再降靠代码体积或 vfasl .zo（C3，曾测 −9 ms / 体积 2.2×） |
| read（.zo 读 + read-bundle） | 14（read-bundle 5–11） | R4：bundle 元数据（60 K 符号 intern）惰性，未做 |
| module（声明） | 13.7 | S3 后；剩余 = provides/requires 表构造 |
| resolver 自身 | 8–12 | symbol/load 6.7 可做集合目录缓存（10-20 报告已指出 `root` 目录语义问题） |
| 模块体 | 8 | 不动 |
| requires 递归 | 5.3 | |
| instantiate 簿记 | 5 | |
| compile + expand（xrepl 的 16 个顶层 require 经 Chez 编译） | 3.4 | xrepl 改 `namespace-require` 可省（xrepl-lib 外部包） |
| GC（窗口内 + 关窗 static 提升） | 16 + 26–28 | S7 |

## 2. 可做项（按收益/局部性）

1. **R4 bundle 元数据惰性**（read-bundle 5–11 ms）：linklet.sls，格式局部。
2. **P4 boot 段分解**（25–30 ms，未知构成）。
3. 集合目录缓存（resolver symbol/load 6.7 → ~1 ms，推断）：expander/eval/collection.rkt，需定 `root` 目录失效策略。
4. racket-lexer 转移表改平铺 fxvector/bytes（−3～4 ms，仅 xrepl 用户；parser-tools-lib 外部包）。
5. xrepl `initialize-namespace` 改 `namespace-require`（−3 ms；xrepl-lib 外部包）。
