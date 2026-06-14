# BC Runtime-Native `pvector` 设计文档

本文档规划一个基于 Racket BC runtime 的原生 `pvector` type。目标不是在
Racket 层继续压低 `struct`/`vector` 组合实现的常数，而是让 `pvector` 像
`pair`、`vector` 一样拥有 runtime tag、固定内存布局、GC 原生遍历和 JIT
inline 能力。

本文档只覆盖 BC。CS 可以保留当前 `racket/src/cs/rumble/pvector.ss` 作为语义
参考或并行实现，但 BC 的实现不应复用 CS record 形态作为 runtime 表示。

## 1. 目标

核心目标：

- 新增 BC runtime 原生类型 `scheme_pvector_type` 及相关内部 node 类型。
- 采用固定 size measure 的标准 finger-tree 表示：`empty`、`single`、`deep`、
  `node2`、`node3`。
- 不引入 chunked leaves、chunk-index vector、ref cache 或 small-flat payload。
- 让 `pvector?`、`pvector-length`、`pvector-ref`、`pvector-cons-left/right`、
  `pvector-pop-left/right`、`pvector-append`、`pvector-split-at` 等核心操作走
  C runtime fast path。
- 为 `pvector?`、`pvector-length`、`pvector-ref`、小 arity 构造和边界检查后
  unsafe ref 建立 JIT inline。
- 以性能、内存、GC、正确性和兼容性作为验收维度，而不是用单一 benchmark 决策。

明确非目标：

- 不改变 `pair?`、`list?`、`cons`、`car`、`cdr` 的语义。
- 不让 `pvector` 伪装成 list，也不让 `apply` 默认接受 `pvector`。
- 不暴露 generic finger-tree 或任意 monoid measure。
- 第一阶段不做 mutable pvector。
- 第一阶段不做 reader 语法扩展；printer 只提供可读但不改变 reader 全局语义的
  `#<pvector>` 或 `#(pvector ...)` 风格输出，最终格式需单独确认。

## 2. 当前 BC 对标点

BC 的现有基础类型有明确模式可仿照：

- `scheme_vector_type` 在 `racket/src/bc/src/stypes.h` 中占一个 runtime type tag；
  `Scheme_Vector` 在 `racket/src/bc/include/scheme.h` 中定义为 header、size 和
  flexible element array。
- `type.c` 为类型设置名字并注册 GC traversal，例如 `<vector>` 和 `vector_obj`。
- `list.c` 注册 `cons`、`list`、`pair?`、`list?` 等 primitive，并通过 primitive
  flags 通知 JIT 可 inline。
- `jitinline.c` 对 `vector?`、`vector-ref`、`vector-set!` 和小 arity vector
  allocation 已有 inline 路径。

`pvector` 应按这个层次进入 BC，而不是只在 `collects` 中做 adapter。

## 3. Runtime Type 与对象布局

新增 public-facing runtime type：

```c
scheme_pvector_type
```

新增 internal node type：

```c
scheme_pvector_node_type
```

推荐只暴露一个 public type，内部通过 shape tag 区分 empty/single/deep/node2/node3。
这样 `pvector?` 只需要一个 type test；内部 node 不应被用户层谓词接受。

### 3.1 对象头

所有对象以普通 `Scheme_Object`/`Scheme_Inclhash_Object` 开头，保留 GC/hash/equal
所需字段。`pvector` 本身不可变，构造完成后字段不再修改；构造期写入字段必须满足
precise GC 与 write barrier 规则。

### 3.2 顶层 pvector

```c
typedef struct Scheme_PVector {
  Scheme_Inclhash_Object iso;
  intptr_t length;
  unsigned char shape;
  unsigned char prefix_len;
  unsigned char suffix_len;
  unsigned char reserved;
  Scheme_Object *a;
  Scheme_Object *b;
  Scheme_Object *c;
  Scheme_Object *d;
} Scheme_PVector;
```

字段含义：

- `length`: fixnum-range length fast path；超过 `intptr_t` 可先拒绝，除非后续设计支持
  bignum length。
- `shape`: `PV_EMPTY`、`PV_SINGLE`、`PV_DEEP`。
- `prefix_len`/`suffix_len`: deep digit 长度，范围 1..4。
- `a..d`: shape-dependent payload。

建议布局：

```text
PV_EMPTY:
  singleton object; length=0; no payload

PV_SINGLE:
  length=1; a = element

PV_DEEP:
  length = total length
  a = prefix digit object
  b = middle tree or scheme_false
  c = suffix digit object
```

为什么 digit 不直接塞进顶层四个字段：

- deep 同时需要 prefix/suffix，各 1..4 个元素；塞进顶层会让结构膨胀。
- 用独立 digit 对象可以让 GC traversal 和 path-copy 更统一。
- 这是第一阶段的论文对标实现；不做 small-flat 特化。

### 3.3 Digit

digit 是内部对象，保存 1..4 个元素：

```c
typedef struct Scheme_PVector_Digit {
  Scheme_Object so;
  unsigned char count;
  unsigned char reserved[sizeof(intptr_t) - 1];
  Scheme_Object *els[4];
} Scheme_PVector_Digit;
```

也可以把 digit 作为 `scheme_pvector_node_type` 的一种 shape，减少 type tag 数量。
关键要求是固定 4 槽，不分配额外 vector。

### 3.4 Node2/Node3

```c
typedef struct Scheme_PVector_Node {
  Scheme_Object so;
  intptr_t measure;
  unsigned char arity;  /* 2 or 3 */
  unsigned char level;
  unsigned char reserved[sizeof(intptr_t) - 2];
  Scheme_Object *a;
  Scheme_Object *b;
  Scheme_Object *c;     /* unused for node2 */
} Scheme_PVector_Node;
```

要求：

- `measure` 固定为元素数量。
- `level=0` 表示节点直接包含元素；`level>0` 表示包含子 node。
- `node2` 和 `node3` 共用布局，减少 GC traversal 类型和 JIT 判断复杂度。
- 不保存 generic measure procedure。

## 4. 内存与 GC

需要修改：

- `racket/src/bc/src/stypes.h`: 增加 type tag。
- `racket/src/bc/include/scheme.h`: 增加 C struct、predicate/accessor macro。
- `racket/src/bc/src/type.c`: 设置类型名，如 `<pvector>`、`<pvector-node>`，并注册
  GC traversal。
- precise GC 生成源：为 pvector/digit/node 增加 mark、fixup、size 描述。

GC traversal 原则：

- `Scheme_PVector`: mark `a/b/c/d` 中按 shape 有效的字段。
- `Digit`: mark `els[0..count-1]`。
- `Node`: mark `a`、`b`，若 `arity=3` mark `c`。
- 空 pvector 为 singleton，注册为全局常量/root，不能被移动后丢失引用。

内存验收：

- `pvector-empty` 不随调用分配。
- 单元素 `pvector` 只分配一个顶层对象，不分配 digit/node。
- size 2..8 的 deep 只分配顶层 deep + 两个 digit，不分配 middle tree。
- 构造 N 元素 pvector 的对象数必须可由 shape invariant 解释，不能出现 adapter、
  wrapper、临时 vector 残留。

## 5. Primitive 与模块边界

新增 BC C 文件建议：

```text
racket/src/bc/src/pvector.c
```

负责：

- 对象构造、shape invariant 检查。
- primitive 注册。
- public API 的 runtime backend。
- unsafe/internal helper。

对外 primitive 分两层：

```text
pvector?
pvector-empty
pvector-empty?
pvector-length
pvector
make-pvector
list->pvector
vector->pvector
pvector->list
pvector->vector
pvector-ref
pvector-set
pvector-cons-left
pvector-cons-right
pvector-pop-left
pvector-pop-right
pvector-append
pvector-split-at
pvector-take
pvector-drop
```

unsafe/internal primitive：

```text
unsafe-pvector-ref
unsafe-pvector-length
unsafe-pvector-first
unsafe-pvector-last
unsafe-pvector-view-left
unsafe-pvector-view-right
```

`racket/collects/racket/pvector.rkt` 只做 public contract、sequence/match 文档入口和
fallback 兼容，不承担核心表示。

## 6. 核心算法路径

### 6.1 Ref

`pvector-ref`：

1. type check。
2. exact nonnegative integer / fixnum index check。
3. bounds check。
4. 调 `pvector_ref_unsafe(pv, index)`。

`pvector_ref_unsafe`：

- `PV_SINGLE`: 返回 `a`。
- `PV_DEEP`: 先查 prefix，再查 suffix，最后按 measure 下降 middle tree。
- node 下降只读 `measure/arity/level/a/b/c`，不得调用 public primitive。

### 6.2 Cons Left/Right

优先直接处理：

- empty -> single。
- single -> deep(prefix 1, suffix 1)。
- deep prefix/suffix 未满 -> 复制对应 digit，构造新 deep。
- digit 满 -> 将溢出的 2/3 元素打包为 node，递归插入 middle。

要求：

- 每步只复制当前 path。
- 不通过 `pvector->list` 或临时 vector 重建。
- digit copy 固定最多 4 个元素，必须手写直接路径。

### 6.3 Append

第一阶段采用标准 finger-tree append：

- empty identity。
- single 插入另一边。
- deep/deep 通过连接 suffix + middle + prefix 建立新 middle。

验收重点不是所有 append 都比 list 快，而是：

- 大对象 append 不线性复制全部元素。
- 小对象 append 不出现 chunk/cache/wrapper 固定成本。
- append 后 `ref`、`split` 不依赖临时 materialization。

### 6.4 Split/Take/Drop

`split-at` 使用 measure-guided descent：

- 对 prefix/suffix 的边界直接切 digit。
- middle 命中时下降到 node，再把左右碎片 rebuild 为标准 shape。
- 结果长度 0 回 empty，1 回 single，>1 回 deep。

不得先 materialize 成 vector/list 再 split。

## 7. JIT Inline 规划

JIT 第一阶段只内联低风险 hot path：

- `pvector?`: type test，仿 `vector?`。
- `pvector-length`: type check + load length。
- `unsafe-pvector-length`: load length。
- `unsafe-pvector-ref`: inline single 和 deep prefix/suffix 快路径；middle 下降可先 call
  C helper。
- 小 arity `(pvector)`、`(pvector x)`、`(pvector x y)`: inline empty/single/simple deep
  allocation。

第二阶段再考虑：

- checked `pvector-ref` 的 index/bounds inline。
- `pvector-first`/`pvector-last`。
- `pvector-cons-left/right` 的 empty/single/digit-not-full inline。

需要修改：

- primitive flags：注册时设置 `SCHEME_PRIM_IS_UNARY_INLINED`、
  `SCHEME_PRIM_IS_BINARY_INLINED`、`SCHEME_PRIM_IS_NARY_INLINED` 中合适的位。
- `jitinline.c`: 增加 named primitive 分支。
- `jitalloc.c`: 如需要，增加 pvector-specific inline allocation helper。

原则：

- JIT inline 只覆盖能用固定偏移和小分支完成的路径。
- 复杂 tree rebalance、append、split 走 C helper。
- 每个 inline 分支必须有非 JIT 等价测试。

## 8. Equal、Hash、Printer、Sequence

`equal?`：

- pvector 与 pvector 按长度和元素逐一比较。
- 第一阶段不让 pvector 与 list/vector 自动 equal；除非明确设计跨类型序列 equal。

hash：

- 使用元素 hash 的顺序组合，和 `equal?` 语义一致。
- 可缓存 hash，但第一阶段不缓存，避免对象字段和 invalidation 复杂化。

printer：

- 初始输出可采用 `#<pvector:...>` 保守格式。
- 若采用可读格式，需要 reader 支持或打印为 `(pvector ...)` 风格，必须与
  `print-as-expression` 规则一致。

sequence/stream：

- public 层提供 `prop:sequence` 等价能力或 `in-pvector`。
- runtime 提供直接 iterator state：pvector + index + length。
- `for` 遍历不应每步重新做 public bounds/type check。

serialization/place：

- 第一阶段至少保证不可序列化时错误清楚。
- 完整支持需要加入 marshal/unmarshal、place message copy、compiled constant 处理。

## 9. 编码原则

- 所有 public primitive 只做一次参数检查，然后进入 checked-once helper。
- helper 名称区分 checked/unsafe/internal，例如 `scheme_pvector_ref` 与
  `scheme_pvector_ref_unsafe`。
- 所有长度和索引 hot path 使用 `intptr_t`/fixnum；非 fixnum 先走 slow path。
- 不在 C hot path 调用 Racket-level closure、generic sequence 或 adapter。
- 不通过 list/vector 中转实现核心操作。
- 构造函数必须集中维护 shape invariant，禁止散落手写半成品对象。
- 每个新对象布局都要有 `SCHEME_PVECTOR_*` macro，避免重复 cast/offset。
- 所有 GC-visible 字段必须在可能 GC 前初始化。
- JIT inline 只能复刻已经有 C helper 覆盖的行为。

## 10. 测试计划

正确性：

- empty/single/deep/node2/node3 shape invariant。
- ref、set、cons、pop、append、split、take/drop 的随机模型测试，对照 list/vector。
- 边界：0、1、2、3、4、5、8、9、16、31、32、33、64、255、256、257、1024。
- improper argument、negative index、too-large index、non-pvector 输入。

Runtime：

- GC stress：构造后强制 collection，验证元素仍可达。
- place/serialization 行为按当前阶段要求测试。
- printer/equal/hash 与文档一致。

JIT：

- JIT on/off 结果一致。
- inline hit path 通过 `pvector?`、`pvector-length`、`unsafe-pvector-ref` 小测试覆盖。
- fallback C helper 与 inline path 行为一致。

性能：

- 专用 list-like suite：build、sum、map、fold、append、cons/pop、ref-middle。
- 综合幂级分布 suite：size 0,1,2,4,8,...,2^k，每个幂级先分别计算
  speed-score、cost-score 和 total-score，再把所有幂级等权几何平均成综合分。
- `academic-clean` profile 作为标准学术版验收口径：调用具体接口，不通过
  adapter/list/vector 中转；成本按必要结果对象形态计算，用于约束没有多余调用、
  没有多余结果外分配、对象操作接近接口最优。
- 指标包括 real time、CPU time、GC time、allocated bytes 或可获得的近似分配指标、
  live memory、object count 和结果形态 cost units。
- 必须与 `list`、`vector`、`treelist`、当前 CS/Racket pvector adapter 比较。

## 11. 分阶段验收

P0: 原生对象可用

- 新 type、layout、GC traversal、empty singleton 完成。
- `pvector?`、`pvector-empty`、`pvector-length`、`pvector-ref`、基本构造通过测试。

P1: 完整核心 API

- cons/pop/append/split/take/drop/set 完成。
- 无 list/vector 中转的核心 hot path。
- public `racket/pvector` 接到 BC backend。

P2: Runtime 协议

- equal/hash/printer/sequence 行为确定并测试。
- unsafe API 与 public API 分层完成。
- 文档更新到 reference。

P3: JIT inline

- `pvector?`、`pvector-length`、unsafe ref、小 arity 构造 inline。
- JIT on/off 测试和 benchmark 报告齐全。

P4: 性能验收

- 小对象 size 0..8 固定成本显著低于 Racket-layer 实现。
- 在幂级综合 benchmark 中，`pvector` 至少在 append/split/ref/update 维度超过 list，
  且 build/sum/map 不出现不可解释退化。
- 所有性能结论附带命令、机器信息、结果文件和统计口径。

## 12. 风险与决策点

- Type tag 增加影响 ABI/扩展接口，需要确认 BC 类型编号稳定性和导出边界。
- GC traversal 错误风险高，必须先小步合入并用 stress 测试。
- JIT inline 容易复制语义错误，只能在 C helper 稳定后加入。
- printer/reader 的可读表示会影响语言表面，不能在 runtime patch 中顺手决定。
- 是否让 `equal?` 跨 list/vector/pvector 比较，需要单独兼容性决策。
- 是否让 `apply`、`map`、`for/list` 等接受 pvector，必须等核心性能稳定后另开设计。

## 13. 推荐实施顺序

1. 增加 type tag、C struct、macro、empty singleton 和 GC traversal。
2. 实现 `pvector?`、`pvector-empty?`、`pvector-length`、`pvector-ref`。
3. 实现构造和转换，先保证无 wrapper、无 chunk、无 flat payload。
4. 实现 cons/pop/set/split/append，并建立随机模型测试。
5. 接入 public `racket/pvector` 和 unsafe 子模块。
6. 增加 equal/hash/print/sequence。
7. 加 JIT inline：先 predicate/length，再 ref，再小 arity allocation。
8. 跑完整 correctness + GC + JIT + benchmark gate，形成验收报告。
