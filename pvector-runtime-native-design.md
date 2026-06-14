# Runtime-Native `pvector` 设计文档

本文档定义一个新的 `pvector` 目标：它不是 Racket 层的 finger-tree
原型，也不是依赖 chunked tree benchmark 取胜的库结构，而是一个面向
Racket runtime 原生实现的基础持久序列类型。

目标是让 `pvector` 获得接近 `list`/`cons` 的基础地位：在保持不可变、
持久、结构共享语义的同时，尽量降低内存占用，并在多维度 list-like
负载上超过普通 list。

## 1. 目标

### 1.1 核心目标

`pvector` 应成为 runtime 级基础数据结构：

- 原生 runtime 对象，不依赖 public wrapper 承担核心表示。
- 小对象表示要足够紧凑，避免当前 chunked-tree 原型在 size 1 到 8
  上的固定开销。
- 对象表示回到标准 size-measured finger-tree，不把 flat payload、
  chunked leaves、chunk-index vector、ref-cache 作为第一阶段设计基础。
- API 保持不可变、持久、结构共享。
- 在 list-like workloads 上，以时间、GC、内存、结构共享四个维度综合超过
  `list`。

### 1.2 明确非目标

第一阶段不做：

- 不改变 `pair?`、`list?`、`cons`、`car`、`cdr` 的语义。
- 不让 `pvector` 伪装成 pair/list。
- 不让 `apply` 或 reader/printer 全局接受 `pvector` 作为 list 替代。
  这些属于后续 runtime integration，需要独立 benchmark 和兼容性评估。
- 不暴露 generic finger-tree 或任意 monoid measure。
- 不为了中大型 benchmark 牺牲 size 1 到 8 的小对象成本。
- 不把 chunked tree 作为 release blocker 或默认性能方向；当前主线不保留
  chunked-tree backend 或 core chunk-view primitive；当前工作树也不保留
  可运行 chunked 后端模块，后续若复测必须从旧提交或独立实验分支恢复。

## 2. 总体设计

`pvector` 使用论文对标的 finger-tree 表示，而不是 chunked tree 或
flat-payload shortcut 表示。

```text
pvector
  empty-pvector
  single-pvector
  deep-finger-pvector
```

### 2.1 Empty 表示

空 `pvector` 是 runtime singleton。

要求：

- `(eq? pvector-empty pvector-empty)` 为真。
- 不分配额外 tree/cache。
- `pvector-length`、`pvector-empty?`、`pvector->list`、`in-pvector` 在空值上走
  极短路径。

### 2.2 Single 表示

size 1 使用 single 表示，对应 finger-tree 论文中的 `Single`。

当前基线：

```text
single-max = 1
```

候选形态：

```text
single-pvector: e0
```

要求：

- 不分配 finger-tree 节点。
- 不分配 chunk、chunk-index、flat payload 或 ref-cache。
- size 2 及以上进入 deep finger-tree，而不是小型 flat vector。

这一步刻意放弃 size 2 到 4 的 inline shortcut，目的是让当前 baseline
与论文结构对齐；若未来重新引入小对象特化，必须先由综合 benchmark 证明
收益，而不是只根据单个 size 或单个操作决定。

### 2.3 Deep Finger-Tree 表示

size 2 及以上使用标准 size-measured finger tree，不使用 chunked leaves，
也不使用 flat payload。

当前 shape：

```text
deep-finger-pvector:
  length
  prefix digit: 1..4 elements
  middle: empty or size-measured node2/node3 tree
  suffix digit: 1..4 elements
```

要求：

- 不分配 chunk、chunk-index vector 或 ref-cache。
- 不分配 flat payload vector。
- digit 长度保持 1 到 4。
- middle 为 `#f` 或 node2/node3 tree；size 2 到 8 可以没有 middle。
- size 9 通过调整 prefix/suffix 长度避免 middle 只有 1 个元素。

基本形态：

```text
deep-finger-pvector:
  length
  prefix digit: 1..4 elements
  middle tree: #f or measured node2/node3 tree
  suffix digit: 1..4 elements
```

节点形态：

```text
node2:
  measure
  a
  b

node3:
  measure
  a
  b
  c
```

要求：

- measure 固定为元素个数，不支持任意 monoid。
- digit 和 node 直接保存元素或子节点，不引入 chunk payload。
- `ref` 通过 size measure 下降查找。
- `append` 使用标准 finger-tree concatenation 路径。
- `split`、`take/drop`、`subvector` 使用 measure-guided split。
- 不维护 chunk-index vector。
- 不维护 ref-cache。
- 不让大对象操作产生的小结果继续保留大 tree。
- `take/drop/take-right/drop-right/pop-left/right/split/split-at` 在 runtime
  core 内部只做一次边界检查，然后通过 checked-once range helper 进入已验证区间的
  empty/self/shared-copy/fresh-copy 路径，避免 public 风格组合调用带来的重复
  length/check 和重复调度。
- `first/last` 或 raw `view-left/right` 的 core 路径应直接访问 single 字段或
  deep-finger 的 prefix/suffix digit，不应通过 general `ref` 路径做额外 index
  检查和 middle 分派。
- `list->pvector`、`make-pvector`、`cons-left/right`、`append`、`set` 的
  empty/single/deep-2 结果应使用直接 runtime constructor；不能为了回到标准
  表示先构造临时 vector，再通过 generic vector->pvector 分派。

暂停 chunked tree 的理由：

- 当前目标是 runtime-native 基础类型，第一优先级是最小对象数和稳定 hot path。
- chunked leaves 增加了阈值、cache、slice retention 和 materialization 的复杂度。
- benchmark 中看到的中大型收益可能来自 workload 偏置，不能证明它适合作为
  默认 runtime 表示。
- 标准 finger-tree 文献和常见 Haskell 实现没有把 chunked leaves 作为算法
  本体要求；在 Racket runtime 里加入这一层，需要比当前 benchmark 更强的证据。
- 标准 finger-tree 更接近算法本体，也更利于先做正确、紧凑、可审计的内核实现。

### 2.4 表示转换

所有构造和派生操作都必须根据结果规模选择表示。

例子：

```text
(pvector)              -> empty
(pvector a)            -> single
(pvector a b)          -> deep-finger, prefix 1, suffix 1, no middle
(pvector ... 8 elems)  -> deep-finger, no middle
(pvector ... 9 elems)  -> deep-finger, prefix 4, middle 2, suffix 3
(pvector ... N elems)  -> deep-finger
```

派生操作同理：

```text
cons-left single -> deep-finger
append deep deep -> deep-finger, sharing middle nodes where possible
take deep 1 -> single
drop deep to 0 -> empty singleton
```

关键原则：结果为 0 回到 empty，结果为 1 回到 single，结果大于 1 回到
标准 deep finger-tree；不引入 flat payload 作为中间捷径。

## 3. 模块设计

### 3.1 Runtime Core

位置：

```text
racket/src/cs/rumble/pvector.ss
```

职责：

- 定义 runtime-native 表示。
- 提供核心 primitive 候选：
  - `core-pvector?`
  - `core-pvector-empty`
  - `core-pvector-empty?`
  - `core-pvector-length`
  - `core-pvector-ref`
  - `core-pvector-set`
  - `core-pvector-cons-left`
  - `core-pvector-cons-right`
  - `core-pvector-pop-left`
  - `core-pvector-pop-right`
  - `core-pvector-append`
  - `core-pvector-take`
  - `core-pvector-drop`
  - `core-pvector-subvector`
  - `core-pvector-split`
  - `core-pvector-split-at`
  - `core-pvector-map`
  - `core-pvector-for-each`
  - `core-list->pvector`
  - `core-vector->pvector`
  - `core-immutable-vector->pvector`
  - `core-fresh-vector->pvector`
  - `core-pvector->list`
  - `core-pvector->vector`
- 提供 shape/stat introspection，仅用于测试和 benchmark。

runtime core 不负责 public contract error wording。它只负责快速、正确、
安全的核心行为。

### 3.2 Public Module

位置：

```text
racket/collects/racket/pvector.rkt
```

职责：

- 提供稳定 public API。
- 做 contract/checking/error-message。
- 提供 sequence、stream、custom-write、equal+hash、serialization、match
  expanders。
- 提供 `unsafe` submodule。

原则：

- public module 不应持有额外 wrapper 作为长期表示。
- 如果为了兼容已有 Racket struct/property 机制暂时需要 wrapper，必须有明确
  migration plan，并在 benchmark 中单独测 public vs adapter/runtime 差距。
- public hot path 应尽量薄，不能把 runtime-native 的收益吃掉。

### 3.3 Runtime Adapter

位置：

```text
racket/collects/racket/private/pvector-runtime-adapter.rkt
```

职责：

- 在 core primitive 可用时调用 core。
- 在 core primitive 不可用时 fallback 到 Racket 实现。
- 为测试提供稳定边界。

原则：

- adapter 只是迁移桥，不是最终性能目标。
- benchmark 必须分别报告 public `pvector` 和 adapter/runtime 路径，避免 wrapper
  开销被隐藏。

### 3.4 Fallback / Prototype

位置：

```text
racket/collects/racket/private/pvector*.rkt
```

职责：

- 保留 Racket 层 fallback。
- 作为 differential testing oracle。
- 不再作为最终性能目标。

### 3.5 Tests and Benchmarks

位置：

```text
pkgs/racket-test/tests/racket/
pkgs/racket-test/tests/generic/
pkgs/racket-benchmarks/tests/racket/benchmarks/pvector/
```

必须保留三类 benchmark：

- 专用小对象 live workload：
  `list-workload.rkt`
- 幂级大小综合 workload：
  `list-spectrum.rkt`
- 综合评分 workload：
  `list-score.rkt`

幂级大小分布默认：

```text
0, 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, ...
```

原因：它能同时覆盖 empty、single、deep-finger 以及不同数量级的 list-like
操作。任何新表示或特殊优化都必须先通过 `list-score.rkt` 观察全局收益，
不能只根据单个 size 或单个 operation 决策。

`list-score.rkt` 使用 academic-clean scoring profile：

- `detail` 行报告具体 size/op/impl 的 `real-ns/op`、
  `generated-result-cost-units` 和 `result-cost-units/op`。
- `power-score` 行按每个幂级 size 聚合该 size 下所有操作；每个幂级单独
  计算 speed score、cost score 和 total score。
- `total-score` 行对所有幂级 size 等权聚合，避免某个大 size 或某个小 size
  因样本数量支配结论。
- speed score 使用 baseline 的 `real-ns/op` 除以目标实现的 `real-ns/op`；
  cost score 使用 deterministic `academic-result-cost-units/op` 单位，不使用
  GC 堆差值作为主评分，避免 arena/free-space 噪声。
  `generated-result-cost-units` 是 `iterations * result-cost-units/op`，
  用于解释该 detail 行的累计对象结果成本；进入评分的是 per-operation
  成本。
- cost score 使用 zero-aware shifted ratio：`(baseline-cost + 1) /
  (target-cost + 1)`。这样当 list/pvector 的空结果成本为 0、目标实现仍然
  产生一个空 vector 或其他结果对象时，额外对象会进入评分，而不会被除零保护
  抹平。
- total score 默认使用 speed 0.7、cost 0.3 的加权几何平均；所有 score
  都是越大越好，`1.0` 表示等于 baseline。
- 每个实现只通过该数据结构的具体接口执行操作，不允许在 benchmark 层为
  某个实现额外添加 list/vector 中转、缓存或 wrapper 快捷路径。输出中的
  `interface-model` 固定为 `direct-concrete-interface`，表示 benchmark
  假设被测实现已经提供了该操作的干净工程实现。
- TSV 输出必须显式带上 `score-profile`、`size-weight-model`、
  `operation-weight-model`、`interface-model`、`score-method`、`speed-metric`、
  `cost-metric` 字段，让后续报告不用反读脚本才能理解评分口径。
- academic-clean 是标准学术版 benchmark：它评价的是一个干净工程实现的
  公开/具体接口，而不是 benchmark harness 里的额外适配层。构造、访问、
  append、take/drop、map、to-list 都应调用各实现的直接接口；只有被测
  operation 本身是转换时，才允许产生目标转换结果。该 profile 的含义是：
  具体接口实现本身应已经没有多余调用、没有额外中转分配，并按对象运算的
  必要成本执行；如果实现仍有多余 wrapper/copy，分数会通过 speed 和
  result-cost 两个维度体现出来。

## 4. 编码原则规范

### 4.1 表示优先原则

当前 baseline 对标 finger-tree 论文结构，不使用 small-flat shortcut。

必须做到：

- size 0 使用 empty singleton。
- size 1 使用 single，不分配 tree。
- size 2 及以上使用 deep finger-tree。
- 所有结果必须按 0、1、2+ 回到对应表示。
- deep 表示第一阶段不创建 ref-cache；查找性能依靠 measure-guided descent。

### 4.2 热路径原则

热路径包括：

- length
- ref
- first/last
- cons-left/cons-right
- append
- take/drop/subvector
- map/for-each
- sequence/stream iteration

热路径要求：

- 使用 fixnum fast path。
- 避免 `match`。
- 避免通过 list 中转。
- 避免 higher-order measure/assoc procedure。
- 避免在循环中分配闭包。
- 对 single 使用直接字段访问。
- 对 deep-finger 使用直接 digit/node 分派和 measure-guided descent。

### 4.3 内存原则

每个表示都要有明确对象预算。

初始预算目标：

```text
empty: 0 per-instance allocation
size 1 single: 1 runtime object
size 2..8 deep: pvector object + 2 digit vectors, no middle tree
size 9+ deep: pvector object + 2 digit vectors + node2/node3 middle tree
```

如果未来要重新引入 inline-small 或 flat payload，必须先由 `list-score.rkt`
证明全局收益，并在文档中记录对 correctness、memory retention 和 public wrapper
的影响。

### 4.4 No-Chunk / No-Cache 基线原则

第一阶段的 release baseline 不引入 chunked leaves、chunk-index vector 或
ref-cache。

要求：

- single 不允许 chunk/cache。
- deep-finger 不允许 chunk-index/ref-cache。
- append/slice/take/drop 不能因为共享大 tree 而让 empty/single 结果保留大对象。
- 如果未来重新评估 chunked tree，必须作为独立实验分支，有单独 benchmark、
  memory-retention 报告和回滚路径；不能静默进入默认表示。

### 4.5 安全原则

runtime 代码必须避免 unsafe accessor 类型误用。

要求：

- 每个 internal representation 都有独立 predicate。
- unsafe accessor 前必须由同一分支 predicate 保证。
- shape-stats、materialization、for-each 这类辅助路径也要覆盖所有表示。
- 新增表示必须添加 regression test，避免遗漏导致 crash 或 illegal instruction。

### 4.6 Public API 原则

public API 负责用户体验，不负责核心性能结构。

要求：

- 错误信息与 Racket 风格一致。
- unsafe submodule 跳过 public checks，但不能跳过 runtime memory safety。
- `pvector` 和 `pvector*` match expanders 与文档一致。
- sequence/stream 协议不能把小对象强制 promote 成 large。
- serialization/equal/hash 对所有表示一致。

### 4.7 Benchmark 先行原则

任何优化都必须先有对应 benchmark。

要求：

- 修改表示层前，先运行 `list-score.rkt`，并说明综合分变化。
- `list-score.rkt` 必须按 size/op/impl 输出明细行，并用 `real-ns/op`
  作为 speed score 的输入；总 `real-ms` 只用于判断本行测量是否足够长。
- `list-score.rkt` 必须输出 `power-score` 和 `total-score`。`power-score`
  按幂级 size 分别计算，`total-score` 对幂级分布等权汇总。
- cost score 使用 `academic-result-cost-units/op`：它是 deterministic
  result object cost model，用来评价干净工程实现的必要对象/槽位开销；
  `generated-result-cost-units` 记录该 detail 行按重复次数累计的结果成本；
  `live-bytes` 仍作为观测字段保留，但不进入主综合分。
- `list-score.rkt` 的标准 profile 是 `academic-clean`：
  - size 权重为 `equal-per-power-size`；
  - 同一 size 内 operation 权重为 `equal-per-operation-within-size`；
  - speed metric 为 `real-ns/op`；
  - cost metric 为 `academic-result-cost-units/op`；
  - speed ratio 为 `baseline/target`；
  - cost ratio 为 `zero-aware-add1-baseline/target`；
  - interface model 为 `direct-concrete-interface`；
  - score method 为 `weighted-geomean(speed=0.7,cost=0.3)`，除非命令行
    明确覆盖权重。
- 对极短极小容器，benchmark 必须支持自动放大重复次数，避免把 0ms 或
  单个 size/op 的偶然结果作为优化依据。
- 每次优化报告必须包含：
  - commit 或工作区说明；
  - 命令；
  - raw TSV；
  - `real-ms`；
  - `real-ns/op`；
  - `result-cost-units/op`；
  - `generated-result-cost-units`；
  - `power-score`；
  - `total-score`；
  - `cpu-ms`；
  - `gc-ms`；
  - live memory 附表；
  - 对失败项的解释。
- 报告主线先讲性能，再讲内存。内存是约束，不是替代性能报告。

## 5. 验收标准

验收分为 correctness、安全、性能、内存、集成五类。

### 5.1 Correctness Gate

必须通过：

```sh
make -j4 also-cs
./racket/bin/racket -y pkgs/racket-test/tests/racket/pvector-runtime-adapter.rkt
./racket/bin/racket -y pkgs/racket-test/tests/racket/pvector.rkt
./racket/bin/racket -y pkgs/racket-test/tests/racket/pvector-tree.rkt
./racket/bin/racket -y pkgs/racket-test/tests/generic/stream.rkt
./racket/bin/racket -y pkgs/racket-benchmarks/tests/racket/benchmarks/pvector/gate.rkt --quiet
```

必须新增/保留：

- empty、single、deep-finger 的构造、ref、set、append、take/drop、map、for-each 测试。
- 0、1、2、8、9、幂级大小的 shape boundary 测试。
- randomized differential tests against list/vector model。
- match pattern tests for `pvector` and `pvector*`。

### 5.2 Safety Gate

必须满足：

- 所有表示的 shape-stats 能运行。
- 所有表示的 `pvector->list`、`pvector->vector` 能运行。
- 所有非空表示的 `first/last` raw endpoint access 必须直接访问 endpoint，
  不能借 general `ref` 完成。
- `pvector->list` 的 core 路径不能先 materialize vector snapshot；它应直接
  遍历 finger-tree 并只分配结果 list。
- `take/drop/pop/split/split-at` 的 core 路径不能通过重复 checked public-style
  组合实现；外层检查一次后必须复用已验证区间 helper。
- empty/single/deep-2 的 core 构造和更新路径不能先 materialize 临时 vector；
  它们必须直接构造 empty singleton、single 或 prefix/suffix 为 1 的 deep
  finger-tree。
- 所有表示的 `pvector-map`、`pvector-for-each` 能运行。
- large-finger 路径不依赖 chunk-index/ref-cache 才能正确运行。
- 不允许 crash、illegal instruction、GC corruption。
- `git diff --check` 通过。

### 5.3 Performance Gate

性能报告必须以 `real-ms(gc-ms)` 为主，不能只报告内存。

本节使用上文定义的 `academic-clean` 综合评分协议：幂级 size 等权、
同一 size 内 operation 等权，先输出 `detail`，再输出每个幂级的
`power-score`，最后输出全分布 `total-score`。该 profile 是标准学术版
benchmark：被测实现必须通过具体接口完成操作，不能靠 benchmark harness 的
额外中转、缓存或包装路径获得分数。

必须运行：

```sh
./racket/bin/racket -y pkgs/racket-benchmarks/tests/racket/benchmarks/pvector/gate.rkt --performance

./racket/bin/racket pkgs/racket-benchmarks/tests/racket/benchmarks/pvector/gate.rkt --score-smoke --quiet

./racket/bin/racket -t pkgs/racket-benchmarks/tests/racket/benchmarks/pvector/list-score.rkt -- --max-size 1024

./racket/bin/racket -t pkgs/racket-benchmarks/tests/racket/benchmarks/pvector/list-workload.rkt -- --count 200000 --sizes 1,2,4,8,16,64 --ops build-live,sum-live,ref-live,cons-left-live,cons-right-live,drop-left-live,append-self-live

./racket/bin/racket -t pkgs/racket-benchmarks/tests/racket/benchmarks/pvector/list-spectrum.rkt -- --m 100000 --sizes 1,2,4,8,16,64,256 --ops build,sum,ref-middle,append-self,map-add1
```

本地快速回归可先运行：

```sh
./racket/bin/racket -y pkgs/racket-benchmarks/tests/racket/benchmarks/pvector/gate.rkt --performance-smoke
```

初始性能目标：

- size 1 到 4：
  - `build-live` 不得超过 list 的 2.0x。
  - `cons-left-live` 不得超过 list 的 2.0x，若失败必须说明是否因为 semantic
    difference 不可避免。
  - `ref-live` 应接近 vector/list，不得超过 treelist。
- size 8 到 16：
  - `build-live` 应接近或优于 list。
  - `sum-live`、`ref-live` 必须优于 list 或接近 vector。
  - `map-add1` 应优于 vector 和 treelist。
- size 64 及以上：
  - `append-self` 必须优于 list 和 vector。
  - `build` 必须优于 list 和 treelist，接近 vector。
  - `map-add1` 必须优于 vector 和 treelist，并接近 list。
  - `sum` 必须优于 list 或接近 vector。

最终 release 目标：

- 在幂级大小分布综合 workload 上，`pvector` 的几何平均 real time 必须优于
  list。
- 在 list-workload small live workload 上，size 1 到 16 不得出现数量级慢于
  list 的项目。
- 任何比 list 慢超过 2x 的项目都必须列为 release blocker 或有明确非目标说明。

### 5.4 Memory Gate

内存是硬约束，但报告顺序排在性能之后。

必须运行：

```sh
./racket/bin/racket -t pkgs/racket-benchmarks/tests/racket/benchmarks/pvector/list-workload.rkt -- --count 200000 --sizes 1,2,4,8,16,64 --ops build-live,cons-left-live,append-self-live
```

初始内存目标：

- size 1：
  - `build-live` live bytes 不得超过 list 的 2.0x。
  - 目标是接近 list，明显优于 treelist。
- size 2 到 4：
  - 不得超过 list 的 1.5x。
  - 不得超过 vector 的 2.0x。
- size 8 到 16：
  - 应接近或优于 list。
- size 64：
  - 必须优于 list。
  - 应接近 treelist。

当前 chunked-tree 原型不满足该 gate；这正是 small representation 和
no-chunk baseline 的动机。

### 5.5 Integration Gate

必须满足：

- public `racket/pvector` 和 adapter/runtime 路径都能通过测试。
- public wrapper overhead 必须单独报告。
- reference 文档更新。
- match 文档更新。
- unsafe submodule 文档更新。
- serialization/equal/hash/stream/sequence 行为稳定。
- 如果增加 kernel primitive，必须更新 runtime boundary manifest 和 gate。

## 6. 开发里程碑

### M1: Baseline 固化

- 从当前工作树移除 chunked-tree 实现和专用测试；相关实验只能通过旧提交或
  独立实验分支恢复，不作为新 baseline，也不进入当前 runtime boundary。
- 保留当前性能/内存报告。
- 明确当前失败项：
  - size 1 到 8 构造慢；
  - small live memory 偏大；
  - public wrapper overhead 可见。
  - chunk/cache 机制引入额外表示复杂度。

### M2: Paper-Shape Runtime Prototype

- 实现 empty + single + deep-finger。
- 更新 ref/length/first/last/for-each/map。
- 更新 constructors 和 conversion。
- 跑 correctness + list-score smoke。

### M3: Deep Finger-Tree Baseline

- 移除默认 large chunked tree 路径。
- 实现或恢复标准 size-measured finger-tree 路径。
- 确认 deep 表示不污染 empty/single 表示。
- append/slice/take/drop 对 empty/single result demote。
- chunked tree 从当前 runtime boundary 和当前工作树移除；后续复测只能作为
  独立实验，不进入 release gate。

### M4: Public API Thinning

- 减少 public wrapper 对 runtime-native path 的影响。
- public 与 adapter 性能差距必须收敛。
- 更新文档和 unsafe submodule。

### M5: Release Gate

- correctness 全绿。
- safety 全绿。
- performance gate 达标。
- memory gate 达标。
- 文档完整。

### 当前实现状态

截至当前工作树：

- runtime core candidate 已移除 small-flat payload 表示。
- 当前 shape 对标 finger-tree 论文：empty、single、deep-finger。
- size 1 使用 single；size 2 到 8 使用无 middle tree 的 deep-finger；
  size 9 及以上使用 prefix/suffix digit 加 size-measured node2/node3
  middle tree。
- M4 的 chunked tree 路径及其可运行模块已从当前工作树移除。
- `pvector-shape-stats` 对 core deep 值必须报告 `payload-vectors = 0`、
  `digit-vectors = 2`；prefix/suffix digit 长度必须保持在 1..4；有
  middle tree 时 `finger-nodes > 0`。
- deep 的 range fill/copy 已按 digit/node measure 递归拷贝，不再对每个元素
  单独执行一次 tree `ref`。
- edge `take/drop/pop` 以及 digit 尚有空间时的 `cons-left/right` 可以共享
  middle tree，并通过 `prefix-length`、`suffix-length`、`middle-measure`
  测试覆盖。
- digit 尚有空间时的 `cons-left/right` 复用固定尺寸 immutable digit
  构造路径，不再通过通用 loop 复制小 vector。
- digit 已满时的 `cons-left/right` 已改为把原满 prefix/suffix 建成
  measured bridge node 并接入 middle tree；新元素成为单元素 prefix/suffix，
  不再整段 materialize/rebuild。
- deep `set` 已对 prefix/suffix 执行 digit copy，对 middle 执行
  measure-guided node path edit，不再整段 materialize。
- deep `set` 落在 prefix/suffix digit 时只涉及长度 1..4 的 digit
  vector；runtime core 直接构造更新后的 immutable digit，不再走通用
  copy + set + freeze 路径。
- edge-cropped deep 与 single 的 append 在 digit 容量足够时直接补
  prefix/suffix，并共享 middle tree。
- deep 与 single 的混合 append 在 digit 容量不足时，会把
  边界 digit 和 single value 组成 measured bridge nodes，并共享原 middle
  tree；因此不再整段 materialize/rebuild。
- runtime core 的固定长度 digit vector 构造已改为使用 CS runtime 的
  inline immutable-vector constructor，不再先 `make-vector`、逐项 `set!`、
  再 `vector->immutable-vector`。
- runtime core 的 mutable vector range copy 在长度 1..4 时直接使用
  mutable `vector` constructor；短 copy 不再先 `make-vector` 再 loop set。
- runtime core 的 digit/slice immutable copy 在长度 0..4 时直接构造
  immutable vector；prefix/suffix slice 不再为了短 digit 先分配 mutable copy
  再 freeze。
- runtime core 的 pvector range immutable materialization 在长度 0..4 时也
  直接通过 unchecked ref 构造 immutable vector；跨 prefix/middle/suffix 的短
  slice 不再先 `make-vector`、`fill-range!`、再 freeze。
- runtime core 的 pvector range immutable materialization 已新增 known-length
  internal helper；large-finger edge slice 在 fallback 到短 range 构造时，
  复用外层 checked-once 的 pvector length，不再让每个元素 ref 重新读取长度。
- runtime core 的 `pvector->vector` 在长度 1..4 时直接用 CS runtime 的
  mutable `vector` constructor 返回结果；不再先 `make-vector` 再逐项
  `vector-set!`。长度 0 仍走空 mutable vector，长度 5+ 仍走通用填充路径。
- runtime core 的 `cons-left/right` 和 `append` 已按 empty、single、
  deep-finger 三种合法形态分派；移除旧 small-flat/flat payload 时代遗留的
  通用 vector materialization fallback。当前 baseline 下 single+single
  append 直接产生 deep-finger，single+deep/deep+single/deep+deep 直接进入
  finger-tree 路径。
- runtime core 的 `cons-left/right` 已新增 known-length internal helper；
  `insert` 的端点路径与 deep middle fallback 里的 `cons-right` 组合路径复用
  外层 checked-once 的 length，不再让 large-finger edge cons 重新读取长度。
- deep 与 deep 的 append 已可直接拼接两侧 middle 子树，并把左 suffix
  与右 prefix 的边界 digit 组成 measured bridge nodes；主路径不再整段
  materialize/rebuild。
- deep 与 deep append 的边界 bridge node 现在按 bridge 长度 2..8 直接构造
  node2/node3 树，不再先分配临时 bridge vector 再调用通用 node-tree builder。
- deep 与 deep append 的 bridge digit 组合已按左右 digit 长度 1..4 展开；
  构造 node2/node3 bridge 时不再为每个槽调用 bridge-ref helper 做左右来源
  分支判断。
- runtime core 在 full-edge `cons-left/right`、single/deep append 与
  deep/deep append 中接入 bridge node 和已有 middle tree 时，已按 1/2/3
  个 measured nodes 直接返回原 node 或构造 node2/node3，不再为这些固定小
  规模连接分配临时 list/vector 后调用通用 node-tree builder。
- runtime core 在满 prefix/suffix digit 推入 middle tree 时，长度固定为 4
  的 edge digit 直接构造 node2(level 2) + 两个 node2(level 1)；full-edge
  `cons-left/right` 和 single/deep append 不再为了这个固定形态调用通用
  node-tree builder 并分配临时 vector。
- runtime core 的 deep/deep append 在 left suffix 与 right prefix 都是满
  digit（4+4）时，直接构造 node3(level 2) + node3/node3/node2(level 1)
  的 bridge tree；该常见路径不再通过通用 bridge-ref helper 逐项分支取值。
- runtime core 的 leaf node2/node3 构造已使用固定 measure 的直接 record
  constructor；level=1 的 node 不再通过通用 `core-entry-measure` 分支计算
  measure。满 digit bridge 与 deep/deep append bridge 的 level=2 根节点也
  直接写入固定 bridge measure，不再为固定形态重复读取 child measure。
- runtime core 构建下一层 node tree 时，已按实际输出 node 数量一次性分配
  结果 vector，不再先按输入 entry 数量分配过大的临时 vector 后切片复制。
- runtime core 的 aligned middle slice 在只产生 1/2/3 个 pieces 时，直接
  返回原 piece 或构造 node2/node3；只有更长 pieces 才进入通用 vector-backed
  node-tree builder。
- runtime core 的 aligned middle slice 已把 piece 相交判断、递归 slice 和
  finish 判定拆成顶层 helper；不再为每次 slice 定义局部 `add-piece!`
  helper，也不再用 `set!` 维护 `pieces` / `failed?` 状态。
- runtime core 的 aligned middle slice 在非叶子层已拆出 child-node 专用
  piece helper，直接读取 child node measure 并递归；leaf 层已改为固定
  `start/end` case 分派，长度 1 的 slice 仍按原语义返回失败，长度 2/3
  直接返回 leaf node，不再分配 piece list 或调用 entry-measure helper。
- single 与 single append 直接产生 deep-finger，不经过 flat payload。
- deep 在 prefix/suffix digit 有容量或可收缩时，`insert/delete` 直接复制
  digit 并共享 middle tree，不再整段 materialize。
- deep 在 prefix/suffix digit 上的 `insert/delete` 只涉及长度 1..4 的
  digit vector；runtime core 对这些小尺寸直接构造 immutable digit，
  不再通过通用两段 loop 复制后插入或删除。
- deep 在 middle 内部执行 `insert/delete` 时，已改为通过
  measure-guided `copy`/`append` 组合左右片段和单元素片段，不再整段
  materialize 到 vector 后重建。该组合路径由外层完成一次 index/length
  检查后调用 unchecked copy，避免 private runtime 内再次走 checked
  public-style copy 入口。该路径保留 no-chunk deep-finger 形态；后续只有在
  benchmark 证明必要时，才进一步替换为单次下降的局部 node edit。
- deep 的 middle `insert` 组合路径已去掉临时 singleton pvector 和第一层
  append；现在由左片段直接 `cons-right` 新元素，再与右片段 append。该改动
  保持原有 copy/append 组合策略，不引入新的 node edit 或表示变体。
- deep 的 `copy/take/drop/split-at` 在裁剪点正好落在 prefix/middle 或
  middle/suffix 边界、且能保持 prefix/suffix digit 非空时，可直接重组
  digit，并共享原 middle tree；如果直接共享会产生空 digit，则退回
  fresh-result materialization 重新构造标准 deep-finger。
- deep 的 `copy/take/drop/split-at` 构造新边界 digit 时，如果该边界段完全
  来自原 prefix/suffix digit，则直接复用完整 digit 或从已有 digit vector
  切片；只有边界段混入 middle 元素以满足 aligned middle slice 时才走通用
  range materialization。
- deep 的 `copy/take/drop/split-at` 边界 digit 复用/切片判断已提升为
  runtime core 顶层 helper，不再为每次 large-finger copy 定义捕获
  prefix/suffix/middle 边界的局部 helper。
- deep 的 `copy/take/drop/split-at` 在 middle 内部裁剪点对齐到已有 node
  子树边界时，会按 measure 切出 middle slice，完整覆盖的子树保持共享，
  只重建连接节点。
- deep 的 `copy/take/drop/split-at` 在 middle 内部裁剪点未对齐时，会把
  切口附近少量元素吸收到 prefix/suffix digit，再按 measure 切出对齐的
  middle slice；代表性 unaligned middle cases 已由形态测试覆盖。
- adapter 默认 builder、整数 range、等差 range 构造路径已改为 vector-backed
  core construction；runtime candidate、kernel export 与 primitive metadata
  已移除 chunked 构造 primitive。
- runtime core 已新增 `core-fresh-vector->pvector`，用于接收 adapter/public
  层刚创建且不再外部可变引用的临时 vector。它只消除构造路径中
  `vector->immutable-vector` 的额外冻结复制，不改变 empty/single/deep-finger
  表示，也不引入 flat payload 或 chunked leaves。
- runtime core 内部的 `list->pvector`、`make-pvector`、`map`、`copy` 等
  fresh-result materialization 路径也直接使用该 no-retain 构造方式，避免
  先冻结复制再构建。
- runtime core 的 large-finger 与 single pvector append 在 digit 可容纳时
  复用固定尺寸 immutable digit 构造路径；digit 已满需要把 single 作为
  新边界 digit 时，直接构造 single immutable digit vector，不再经由
  通用 pvector range materialization。
- runtime core 的 large-finger 与 single pvector append 已接收
  `append/known-length` 传入的左右长度；large+single 和 single+large 两条
  路径不再为了构造结果长度重新读取 large-finger length。
- runtime core 的顶层 `insert/delete` 已按 endpoint 与 deep-finger 中间路径
  直接分派；当前 baseline 不再保留旧表示时代的整段 vector materialization
  fallback。deep 中间路径继续通过 unchecked `copy`/`append` 组合左右片段与
  单元素片段，避免重复边界检查。
- runtime core 的 large-finger `insert` 在 prefix digit 可直接容纳插入时，
  先完成 prefix 命中判断，不再为了可能不会走到的 suffix/middle 路径预先读取
  suffix、计算 suffix-start 或读取 middle。suffix/middle 字段只在对应重建
  路径实际需要时读取。
- runtime core 的 large-finger `delete` 及其返回 deleted value 的 edge helper
  也按 prefix 命中先行判断；prefix digit 可直接收缩时，不再提前读取 suffix
  或计算 suffix-start。suffix 与 middle 字段只在 suffix 重建、prefix 重建或
  fallback copy/append 真正需要时读取。
- runtime core 的 deep 中间 `insert/delete` 与 large-finger `set` 已接收
  外层 checked-once 得到的 pvector length；这些 helper 不再为了计算
  suffix 起点或结果长度重新读取 large-finger length。
- runtime core 的 deep 中间 `insert/delete` 组合路径已把左右片段长度传给
  内部 known-length append helper；该路径不再让 append 重新读取左右
  pvector length，也不重新进入旧表示 fallback 判断。
- runtime core 的 `set` 对长度 1/2 直接比较端点并构造 single/deep2；
  长度 2 不再为了修改 prefix/suffix 的一侧而进入 general large-finger digit copy。
- runtime core 的 `pop-left/right` 返回值已改为通过 endpoint view 直接读取
  prefix/suffix 端点；剩余序列仍由 checked-once 的 unchecked copy 路径构造。
- runtime core 的 `delete` 在长度大于 2 且删除首/尾元素时，已直接对剩余范围
  调用一次 unchecked copy；不再落入 large-finger delete fallback 后产生
  empty copy + append 组合。
- runtime core 的 `pop-left/right` 与 `delete` 对长度 1/2 的结果直接返回
  empty/single，不再通过 copy 或 fallback vector materialization 构造短结果。
- runtime core 的 `vector->pvector/no-copy`、`list->pvector`、`make-pvector` 与
  `copy/unchecked` 对长度 1..4 的结果直接构造 single/deep2/deep3/deep4，
  不再为了这些短结果分配临时 vector 再进入 general vector materialization。
- runtime core 的 large-finger `copy/unchecked` 对长度 2..4 的结果先读取一次
  prefix digit；若短区间完全落在 prefix，则直接由该 digit 构造结果。否则再
  读取 suffix/suffix-start，若短区间完全落在 suffix，也直接由该 digit 构造；
  只有跨 digit 或 middle 时才读取 middle 并通过 known-pieces ref 构造短结果。
  该路径避免为短 copy 的每个元素重复执行 generic known-length ref 调度。
- runtime core 的 `copy/unchecked` 对 large finger 的 left/right edge trim
  直接复用 edge digit shrink helper；当裁掉 1..3 个端点元素且不会删空
  prefix/suffix digit 时，`copy/drop/take/take-right/drop-right` 不再进入
  通用 large-finger copy 探测和 node slice。
- runtime core 的通用 large-finger `copy` 也接收外层 checked-once 得到的
  pvector length；`copy/unchecked` 进入 aligned middle slice 探测时不再
  重新读取 large-finger length。
- runtime core 的 `copy/unchecked` fallback materialization 已把外层
  checked-once 的 length 传给 range fill；large-finger copy 未能共享切片时，
  fallback 填充临时 result vector 也不再重新读取 large-finger length。
- runtime core 的 `take/drop/take-right/drop-right` 在端点位置直接返回
  `empty-core-pvector` 或原 pvector，不再通过 `copy/unchecked` 的 empty/self
  分支。
- runtime core 的 `pop-left/right`、`split` 端点分解和 `delete` 端点删除在
  large finger 边 digit 长度大于 1 时，直接缩短 prefix/suffix digit 并共享
  middle 与另一侧 digit，不再为了剩余 pvector 进入 range copy helper。
- runtime core 的 large-finger 端点 `pop` / `split` / `delete` 已把 selected
  value 与 rest 构造合并到同一个 edge helper；prefix/suffix digit 只读取一次，
  不再先经 endpoint view 取值、再由 rest helper 重新读取同一 edge digit。
- runtime core 的 large-finger 非端点 `delete` 在索引仍落在可收缩的
  prefix/suffix digit 时，也把 deleted value 与 rest 构造融合；该路径不再
  先执行一次 indexed ref，再重新读取同一 edge digit 做 digit shrink。
- runtime core 的端点 `pop-left/right`、edge-trim `copy`、端点 `split`
  和端点 `delete` 已把外层 checked-once 得到的 length 传给 edge digit
  shrink helper；这些路径不再为了构造剩余 large-finger 重新读取 pvector
  length。
- runtime core 的 checked `ref` 与短 `copy` 在源索引落在左右端点时直接使用
  endpoint view，不再让端点访问进入 indexed descent；该路径只消除调用和
  树下降开销，不改变 empty/single/deep-finger 表示。
- runtime core 的短 range materialization 对长度 2..4 的连续区间只在首元素
  检查左端点、末元素检查右端点；中间元素直接使用 known-length indexed ref，
  不再为每个元素重复执行双端点分支。large-finger 短 `copy` 已进一步改为
  direct digit 或 known-pieces 路径，不再通过 generic known-length indexed ref。
- runtime core 的 large-finger 短 immutable range materialization 也已改为
  direct digit 或 known-pieces 路径；长度 2..4 的 edge digit 构造不再为每个
  元素重复走 generic indexed ref 下降。
- runtime core 的非端点 indexed ref 在外层已经 checked-once 得到 pvector
  length 时，也通过 known-length internal ref 进入 large-finger descent；
  短 `copy`、`set` 同值比较、`split/delete` selected value 和短
  `map/for-each/list/vector` 分支不再为同一次访问重新读取 large-finger
  length。
- runtime core 的 large-finger known-length ref 在索引命中 prefix 时先直接
  返回 prefix 元素；suffix 字段、suffix length 与 suffix-start 只在 prefix
  miss 后读取和计算。prefix hit 不再额外读取另一端 digit。
- runtime core 的 large-finger `set` 已把同值比较融合进 shape-specific
  set helper：prefix/suffix 路径用已读取的 digit 直接比较，middle 路径用
  已计算的 middle index 比较后再决定是否重建；外层不再为了同值检查先做
  一次独立 indexed ref。
- runtime core 的 large-finger `set` 也把另一端 digit 与 middle 字段读取
  推迟到同值比较之后；当 prefix/suffix/middle 命中且值未改变时，直接返回
  原 pvector，不再为了最终不会发生的重建读取无关字段或计算 suffix-start。
- runtime core 的 `split-at`、`split-at-right` 在端点位置直接返回
  `empty-core-pvector` 和原 pvector，不再通过 `copy/unchecked` 的
  empty/self 分支；`split` 的端点 selected value 也直接使用 endpoint view，
  中间 selected value 在端点排除后直接走 unchecked indexed ref。
- runtime core 的非端点 `split` 在 selected index 落在 prefix/suffix digit
  且可直接保持另一侧 edge digit 非空时，融合 selected value 读取与一侧
  pvector 构造；短半边也直接从同一个 edge digit 生成 single/deep2/deep3，
  不再先执行 indexed ref，再对同一 edge 做一次 range copy 或短 copy 探测。
- runtime core 的非端点 `split` edge helper 与 `split-at` interior edge
  helper 已按 prefix 命中先行判断；prefix 分支不再为了可能不会使用的
  suffix 分支预先读取 suffix、计算 suffix-start 或读取 middle。suffix/middle
  字段只在实际构造对应结果时读取。
- runtime core 的 `split-at`、`split-at-right` 在切分点距离左端或右端为 1
  时，复用 large-finger edge `view+rest` helper；该路径只读取一次边 digit，
  直接构造 singleton 与 rest，不再分别执行 singleton copy 和 rest copy。
- runtime core 的 `split-at`、`split-at-right` 在切分点落在 prefix/suffix
  digit 内部且两侧都能保持非空 edge digit 时，会一次读取 edge pieces 并
  构造左右结果；短半边直接生成标准 single/deep2/deep3/deep4，长半边共享
  middle 与另一端 digit。该路径不再分别对左右两边执行 `copy/unchecked`
  的 large-finger 探测。
- runtime core 的 size 2..4 `->vector`、`map`、`for-each` 和 `->list`
  短线性路径已直接读取 prefix/suffix digit；size 4 若来自两个 deep2
  append 形成 node2 middle，则直接读取该 leaf node2 字段。该路径不再
  通过 `known-pieces` helper 反复计算 suffix-start 或分派到通用 node ref。
- runtime core 的 large-finger full-range `fill`、`map`、`for-each` 与
  `to-list` 直接顺序处理 prefix、middle 全覆盖 traversal 与 suffix；size
  5..8 等 no-middle 形态只处理 prefix/suffix 且不读取 middle。full-range
  路径不再经过 segment traversal 的 max/min 裁剪。
- runtime core 的 large-finger partial range traversal 在区间完全落在
  prefix digit 或 suffix digit 时，也直接进入对应 vector range helper；
  prefix-only 区间不读取 suffix/middle，suffix-only 区间不读取 middle，且不再
  经过 segment traversal 的 max/min 裁剪。
- runtime core 的 large-finger partial range traversal 在区间完全落在 middle
  tree 时直接进入 node range helper；该路径不再先执行 prefix segment no-op，
  也不再执行 suffix segment no-op。
- runtime core 的 checked `copy` 入口只读取一次 pvector length，并用该
  known length 分别校验 `start` 与 `end`；同一次 range copy 不再为两个
  端点校验重复读取对象长度。
- runtime core 的 middle node `ref` / `set` 在非叶层已直接递归到子 node；
  外层已排除 `level=1`，因此不再经过带 `level` 再分派的 entry helper，
  也不再为每次 node 操作定义捕获 `level` 的局部 descend/set helper。
- runtime core 的 middle node 非叶 `ref` / `set` 也直接读取 child node 的
  cached measure；这些路径不再通过 `core-entry-measure` 做 `level=1`
  分支，node3 的 `a+b` 合计也只计算一次。
- runtime core 的 middle leaf node（level 1）`ref` / `set` 已直接按
  node2/node3 字段访问或重建；leaf 层不再经过通用 measure 计算和 entry
  helper 分派。
- runtime core 的 node `fill` / `map` / `for-each` / `to-list` traversal
  也已把 entry range 相交判断和 `level=1` 分派提升成顶层 helper，不再为
  每次 node traversal 定义捕获 `level`、`start/end` 或目标 vector 的局部
  helper。
- runtime core 的 node 非叶 traversal entry helper 已收窄为 child-node
  helper：直接读取 child node measure 并递归，不再携带 `level` 参数，也不再
  在 helper 内保留 `level=1` 分支。
- runtime core 的 middle leaf node（level 1）`fill` / `map` / `for-each` /
  `to-list` 已进一步直接按 node2/node3 字段和固定 start/end 条件遍历；
  leaf traversal 不再为每个 entry 计算 measure 或 range intersection。
- runtime core 的 middle node `fill` / `map` / `for-each` / `to-list` 在
  `start=0,end=node-measure` 的完整覆盖场景直接按 node2/node3 递归遍历；
  `pvector->vector`、`pvector->list`、整段 `map` / `for-each` 的 middle tree
  主路径不再为每个 child node 计算 range intersection。partial range
  仍走原 range-aware helper。
- runtime core 的 `set` 同值比较、`split` selected value、`delete`
  deleted value 在索引落到左右端点时也复用 endpoint view，避免这些
  checked-once 操作为了返回端点对象再进入 indexed descent。
- runtime core 的非端点 `delete` 在 fused edge helper 已经判定不能直接
  缩短 prefix/suffix digit 后，middle fallback 直接进入 copy/append
  组合 helper；该路径不再重新进入 `large-finger-delete` 做第二次
  prefix/suffix edge 探测。
- runtime core 的 `pvector->list` / `pvector->vector` 对长度 0..4 的结果
  不再进入通用 range traversal；其中长度 2..4 的 deep-finger 值读取一次
  prefix/middle/suffix pieces 后，通过 piece-aware ref 直接访问元素，避免
  endpoint view、重复字段读取或 short indexed ref helper，同时仍支持短值中
  存在 middle node 的形态。短 deep 分支也在外层计算一次 suffix-start 后传给
  piece-aware ref，避免每个元素访问重复执行相同的 fixnum 差值计算。
  短 `pvector->vector` 的长度 1..4 分支直接构造 mutable vector，
  不再执行 `make-vector` + 多次 `vector-set!`；
  public/unsafe wrapper 对长度 1..4 也利用 wrapper 内缓存的 length 直接
  materialize。
- public/adapter 层固定 arity 的 `(pvector x)`、`(pvector x y)`、
  `(pvector x y z)` 与 `(pvector x y z w)` 已改为调用 runtime
  single/deep2/deep3/deep4 constructor，不再先分配暂存 vector。
- public/adapter 层的短 `list->pvector` / `vector->pvector` 在长度 1..4 时
  直接读元素并调用 runtime single/deep2/deep3/deep4 constructor；mutable vector
  输入不再为这些长度先复制/冻结输入 vector，因为结果不会保留该 vector。
- public 层 literal `(pvector ...)` expression transformer 和 identity `in-range`
  literal 优化在长度 1..4 时直接展开为 single/deep2/deep3/deep4 constructor；
  这些路径不再为了进入 `small-immutable-vector->pvector` 先生成短
  `vector-immutable`。
- adapter 层 `sequence->pvector` 的整数 range 与 arithmetic range 在长度
  1..4 时直接构造 single/deep2/deep3/deep4，不再先填充临时 mutable vector。
- runtime 的 immutable/fresh vector 构造入口在长度 1..4 时也直接构造
  single/deep2/deep3/deep4，避免短 vector 再进入 general large-finger builder。
- runtime core 的 `list->pvector` 在长度 1..4 时直接构造
  single/deep2/deep3/deep4；这些长度不再为输入 list 创建临时 vector。
- runtime core 的 `make-pvector` 对长度 2..4 直接构造 deep2/deep3/deep4；
  `pvector-map` 对长度 1 使用 single 字段，对长度 2..4 读取一次
  prefix/middle/suffix pieces 后调用过程并构造 single/deep2/deep3/deep4，
  不再分配临时 vector、进入 general traversal、重复读取字段或通过 short
  indexed ref helper；这些短 deep 分支同样复用已知 suffix-start。
- runtime core 的大对象 `pvector-map` 已改为通过专用 range-map helper 沿
  digit/node 直接填充结果 vector，不再通过 `for-each-range` 加捕获索引的
  lambda 间接写入。
- runtime core 的 large-finger `fill`、`map`、`for-each`、`to-list`
  traversal 已共享顶层 vector-segment helper；主路径不再为 prefix/suffix
  段定义局部 helper，也不再用 `set!` 串接 fill/map offset。
- runtime core 的 large-finger `fill`、`map`、`for-each`、`to-list`
  traversal 已新增 known-length internal helper；`pvector->vector`、
  `pvector-map`、`pvector-for-each` 和 `pvector->list` 在外层读过 length
  后，不再让 large-finger traversal helper 重新读取 length。
- runtime core 的 `pvector-for-each` 对长度 1 使用 single 字段，对长度 2..4
  读取一次 prefix/middle/suffix pieces 后调用过程；短 pvector 不再进入
  general range traversal、重复读取字段、重复计算 suffix-start 或 short indexed
  ref helper。
- public `pvector-map` 的长度 1 路径现在直接委托 runtime core map；
  不再先构造单元素 `vector-immutable` 再走小 vector 转换。
- public/adapter `make-pvector` 的长度 5 及以上路径现在直接委托 runtime
  core `make-pvector`；长度 0..4 保持 direct constructor，长度 5..64
  不再由 public/adapter 先展开重复参数并构造临时 `vector-immutable`。
- adapter 的 fresh `for/vector`/`for*/vector` 结果现在走 `fresh-vector->pvector`；
  用户传入的普通 vector 仍走安全复制路径，保持不可变语义。
- 该 fresh-vector runtime 入口属于调用路径薄化；当前文档保留上一轮
  academic-clean score 记录，不因这次局部 runtime 改动重新标定验收分数。
- `pvector->chunk-vector` / `pvector->chunk-vector/shared` 仅是 adapter 层兼容
  视图，不是内部表示、缓存或 core primitive。
- core `map/for-each/list` 已改为按 large-finger 的 digit/node 顺序线性遍历，
  不再通过每个位置反复 `ref` 下降。
- public/private `in-pvector`、反向遍历和 indexed 遍历的热路径已改为一次
  `pvector->vector` snapshot 后顺序读取，不再通过 chunk-vector 兼容视图。
- public `equal?` 与 hash 路径已移除对 `pvector->chunk-vector/shared` 兼容
  视图的依赖。hash full path 使用 runtime traversal；equal path 使用一个
  tree 的 direct traversal 加另一个 tree 的 indexed ref，避免分配 chunk-vector
  兼容视图。
- match expander 的 tail-list 构造也不再通过 `pvector-lookup-chunk` 兼容
  lookup，而是直接按 index 从 runtime tree 读取并构造结果 list。
- 曾短暂验证 core mutable-vector cursor 方案，但该方案在 Racket sequence
  协议下让 size=256 `sum` 退化到约 30-31ms；当前归档实现不保留 cursor
  primitive，也不把 no-allocation cursor 作为已验收优化。
- 已新增 `list-score.rkt`，输出所有 size/op/impl 明细、自动校准后的
  `iterations`、总 `real-ms`、归一化 `real-ns/op`、
  `generated-result-cost-units`、`result-cost-units/op`、每个幂级的
  `power-score`，以及幂级等权汇总的 `total-score`；
  后续优化必须以该综合分为入口。
- 移除 small-flat 后，旧 flat-tuned smoke 数据失效；重建 runtime 后已经
  运行 correctness/gate smoke，并用 `list-score.rkt` 跑通一个覆盖
  size 1、2、4、8、16、64、256 与 build/sum/append-self/map-add1 的
  综合样本。按 list baseline、speed 0.7、cost 0.3 的当前 scoring，
  2026-06-15 的 smoke 代表性结果为 `pvector total-score` 约 0.98 到 1.00，
  `adapter-pvector total-score` 约 1.16 到 1.18。该样本只是当前直接路径
  实现的 smoke 基线；是否引入 small/flat/cursor 一类表示优化，仍必须由
  同一 scoring 口径下的综合收益证明。

尚未完成：

- 性能和内存 gate 需要在 paper-shape baseline 重建后重新建立基线。
- `gate.rkt --performance` / `--performance-smoke` 已能自动运行
  `list-workload.rkt` 与 `list-spectrum.rkt` 并按本节阈值报告 blocker。
- `gate.rkt --performance` 当前阈值曾按 flat baseline 调整，paper-shape
  baseline 重测后需要重新校准。
- 如果后续考虑 inline-small、flat payload、cursor 或其他优化，必须先提交
  `list-score.rkt` 的综合分变化，再决定是否进入主线。
- middle `insert/delete` 后续可继续优化为更局部的 node edit，但这不再是
  移除整段 materialization 的 release blocker。

## 7. 设计判断

当前原型显示 chunked tree 在部分中大型 benchmark 上可能有收益，但这个信号
不足以让它进入 runtime-native `pvector` 的默认设计。它可能来自 workload
偏置、阈值选择、cache/materialization 行为，或者测试没有充分覆盖真实
list-like 小对象场景。当前归档实现因此把 chunked tree 视为暂停的实验分支：
core 不提供 chunked 构造 primitive，也不提供 chunk-vector view primitive；
性能报告不再包含专门的 chunk-vector benchmark 项。

因此新的 runtime-native `pvector` 设计必须从表示层解决问题：

- 小对象必须像 `cons` 一样轻。
- 中型对象必须像 `vector` 一样直接。
- 大型对象先使用标准 size-measured finger tree 保留 persistent sharing，
  暂时不使用 chunked leaves。

只有这三层同时成立，`pvector` 才有资格作为 runtime 级基础序列继续推进。
