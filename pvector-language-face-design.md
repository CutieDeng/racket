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
