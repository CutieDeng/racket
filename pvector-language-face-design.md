# B：pvector 语言面设计（草案 v1，待裁决）

2026-09-04 · 依据 `pvector-vs-list-benchmarks.md` 裁决：**胜域零摩擦，不动 list 默认表示**。

## 现状盘点（已实证）

| 语言面 | 状态 |
|---|---|
| 调用面（apply/keyword-apply/rest/place） | ☑ 全齐（本工程 P1-P5） |
| 推导式/序列（for/pvector、in-pvector、stream） | ☑ 已有 |
| 模块内 quote pvector 值（编译期字面量嵌入） | ☑ 已通（literal-emit 机制） |
| reader 字面量 | ◐ 只认结构转储格式 `#pvector(2 ((0 (Digit/val …)) …))`；人类形态 `#pvector(1 2 3)` 被拒 |
| rest 参数 pvector 承载 | ◐ 需显式 `procedure->pvector-rest` 包装，无声明语法 |

## B1：rest 参数的 pvector 承载（主菜）

目标：`(lambda args body)` 形态中让 `args` 以 pvector 到达，零 list。callee 侧声明，caller 无感知。

**方案甲（纯库宏，建议先行）**：`pvector-lambda` / `define/pvector-rest` 语法糖，降糖为 `(procedure->pvector-rest (lambda (args-pv) body))`——骑 P4b 原生包装，零编译器改动，当日可落地；成本=每 λ 一次 make 调用（非每调用），性能即已实测的 rest-list −27~38%。
**方案乙（schemify 识别）**：编译期直接发射 wrapper 闭包分配（静态 arity mask、免运行时 make）；中等改动，收益为常数级。
**方案丙（#%kernel λ 级新形态）**：调用协议核心支持 rest-kind 参数化，dorest 级直达 pvector 物化、零包装跳。真"P4 终态"，深改 expander/schemify/Chez；建议留作 profiling 触发的 D-spike。

**语法争点（需裁）**：形式名（`pvector-lambda`？`lambda/pv`？）；要不要 `define` 形态；formals 是否允许前置固定参数 `(pvector-lambda (x y . pv) body)`（甲方案可支持：内层 λ 收 (x y pv)）。

## B2：字面量表面语法

- **读入**：让 reader 兼容人类形态 `#pvector(elem ...)`（保留结构格式）；元素为 datum，读时 `list->pvector` 重建 O(n)。
- **输出（需裁）**：`write` 现输出结构转储（保形 round-trip、但对人不可读）。选项：a) 一律人类形态（round-trip 后形状不保证逐节点同构——但 equal? 保证）；b) 阈值切换（小值人类形态、大值结构格式）；c) 维持现状仅加读入兼容。倾向 **a**：形状是表示细节，equal?/元素序才是契约；结构格式保留为 `#:mode 'raw`（现有 pvector->literal-datum 已有 raw/expanded 之分，语义对齐）。
- quote/编译期地位已通，无需动。

## B3：非目标（明确排除）

改 list 默认表示；list↔pvector 隐式转换；reader 缺省行为变化（`(1 2 3)` 永远是 list）。

## 排期建议

B1 甲 + B2 读入兼容 = 一个分支一周期可齐；B2 输出策略随裁决走；乙/丙按需后置。

## v2：pvector 升为语法一级公民（2026-10-19）

**动机**：v1 把 `#pvector` 字面量在语法对象中当作不透明数据（reader 禁包装、`datum-map` 不下探、序列化器整体 quote），导致两类静默/晚报错：模板 `#'#pvector(x 1)` 不替换模式变量、`(datum->syntax ctx (pvector #'a))` 直到写 .zo 才报 "cannot marshal"。v2 把 pvector 与 vector 对齐为语法容器。

**语义**：
- reader（`read/pvector-literal.rkt`）：`#pvector(` / `#pvector[` / `#pvector{` 后用 `read-unwrapped-sequence` 读元素，`read-syntax` 模式下逐元素包装并带各自 srcloc；两种转义体（`((e ...) #f)` 与 raw 定义表）在去包装 datum 上识别，元素事后以整个字面量位置包装。
- `datum-map`：pvector 进入慢路径，`core-pvector-map` 保形重建；`datum-has-elements?` 对非空 pvector 为真。由此 `datum->syntax`/`syntax->datum`/scope 惰性传播（`non-syntax-map`）/taint 自动覆盖。
- `compile/serialize.rkt`：`#:pvector` 标签（含 all-quoted 快路径），解码经 `core-fresh-vector->pvector`；共享检测遍历元素。
- `cross-phase.rkt` 允许 pvector 作 cross-datum；`preserved.rkt` 允许 pvector 作保留属性值。
- `syntax-case`：`sc.rkt` 模式编译器新增 `'pvector`/`'pveclist`（定长逐元素 / 含省略号按列表），`stxcase.rkt` 解释器同步；`stx.rkt` 加 `stx-pvector?`/`stx-pvector-ref`。模板（`template.rkt`）新增 `t-pvector` guide，映射到 `core-list->pvector`。
- `quasisyntax`（`qqstx.rkt`）与 `quasiquote`（`core-syntax.rkt`）按 vector 同款：转列表递归、`core-list->pvector` 重建，`unsyntax-splicing`/`unquote-splicing` 可用。
- `syntax/parse`：`pat:pvector` 贯穿 rep/rep-patterns/parse-classic/parse-interp/residual(-interp)/opt(-interp)，进度帧 `ps-add-unpvector`。
- `syntax/strip-context` 下探 pvector。

**可观察变化**：`(syntax-e #'#pvector(a))` 由裸符号的 pvector 变为语法对象的 pvector；`quote` 中含语法对象元素的 pvector 与 vector 一样被 `syntax->datum` 剥离。BC 侧只用既有 `#%kernel` 原语（`core-pvector?`/`-map`/`->list`/`-length`/`-ref`、`core-list->pvector`、`core-fresh-vector->pvector`），无新原语。
