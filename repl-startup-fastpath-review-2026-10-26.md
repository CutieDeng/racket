# REPL 启动快路径重审（2026-10-26，闭包序列化线回退之后）

## 0. 前提变化

- 121e54ba79 回退 fasl2/闭包序列化线（9e2619e657…5cca280f07、B e30820c986、experiments/seg4）。P2.x GOT/零拷贝线保留。
- boot/pb 复位上游 racket/pb v9.3（d8c788e）。本机（tarm64osx）与 lan-11（ta6le）均从上游种子全量 pb bootstrap 通过：petite.boot fixpoint、核心测试 basic/syntax/stx/macro/read/number/string/fasl/hash/struct 通过（module.rktl 尾部集合路径错误预先存在）、300 次装载 0 失败、`(fasl-write 闭包)` 回到上游报错。
- **铁律**：任何改动不得制造对非上游 pb 种子的依赖（判据：全部 c/*.c 对上游种子头文件 `cc -fsyntax-only` 零新增报错；boot 镜像格式改动须守卫）。

## 1. 当前账本（本机，load 4，默认 REPL = racket/init + racket/interactive → xrepl → expeditor）

ttp：默认 152.4（n=15）、`-q -i` 98.5、`-n -q -i` 38.3。

CPU 时间线（`PLT_BOOT_STAMPS`，7 次中位）：exec→C 2 | boot 装载到 rumble 体 16 | 各库层 ≈1 | main.sps 3 | racket/init 61（GC 9）| 交互层 44（GC 9）| 关窗 static 提升 15。

linklet 层（`PLT_LINKLET_TIMES`）：faslin-code 27–30 | read 37–42（read-bundle 5–7）| instantiate 22–29 | 合计 86–92。
expander 区域：instantiate 41（body 36）| resolver 24（6132 次）| module 11（379）| requires 5 | read 10.5。

模块账本（loadtrace，GC 关闭以免把停顿记到单个模块上）：

| 链 | 模块数 | declare | 体实例化（最大单模块） | phase-1 visit |
|---|---|---|---|---|
| racket/init | 169 | 26（GC 开）/ 40（GC 关） | 14.3（0.79，class-internal） | 9.7 + 10.6 |
| xrepl | 67 | 10.8 | 12.9（main.rkt 7.4 = 16 个顶层 require） | 2.6 + 3.2 |
| expeditor（含 lexer 链） | 78 | 12.0 | 4.6 | 3.7 + 2.9 |

结论与 10-19 一致：**声明（读 .zo、代码物化、provides/binding 表、resolver）占语言层 70–80%，模块体只 ≈14 ms 且分散**。GC 开时 loadtrace 把一次 major 停顿记到 pvector-runtime-adapter（14.9）上，是量法伪影。

## 2. 各快路径在新约束下的判决

| 方案 | 依赖 | 判决 |
|---|---|---|
| Q1 第四段全态镜像（seg4） | 闭包序列化 | **死**：能力已回退，且本就被判"闭包不可序列化"。 |
| Q3 预声明镜像 | B 的 .zo vfasl（代码随镜像）、eq-hashtable 镜像、externals（rtd/boot 引用） | **死**：三项都在回退范围；且 expander 的 `module` 记录本身带 `prepare-instance`/`instantiate-phase`/`force-bulk-binding` 三个过程字段，"只声明"图同样含闭包。 |
| A-demod（racket/init+xrepl flatten 成单 linklet 预载） | 无内核改动 | **不可用于 REPL**：flatten 后各模块不再单独声明，用户之后 `(require racket/list)` 会从 .zo 再声明一份实例，struct 类型身份分裂。 |
| **启动包（startup pack）** | 无内核改动；`embedded-load` + `current-module-declare-as-predefined` 已在 main.sps/expander 存在（`raco exe` 的 `-k` 段用法） | **可行，收益最大**：把 racket/init + xrepl + expeditor 闭包的已编译模块按依赖序拼成一个文件，启动时一次 `embedded-load` 按真实名字逐个声明（身份不变），省掉 resolver 24 + 290 次文件打开/读 + 每文件 read-bundle + 部分 module 区；推断 −30～−40。代价：构建步骤、与已安装 .zo 的一致性校验（stamp/sha，过期回退到常规装载）、包文件 ≈10–20 MB 只在 REPL 模式映射。 |
| Q4 延迟到用户触发（同步） | 无 | **可行**：lexer 链（声明+实例化 ≈10）推迟到首次需要着色；xrepl main.rkt 16 个命令模块（7.4）推迟到首次 `,`；phase-1 visit（init 20 + xrepl 6 + expeditor 7）推迟到首次输入展开。推断 −25～−30，首次求值相应变慢同量。 |
| 关窗 GC 移到提示符之后 | 政策 | **可做但不是消除**：15 ms 从 ttp 挪到首次输入前，同步、有界；是否算违反"负载须用户触发"由你定。 |
| 代码物化 faslin-code 29 | 代码体积 | 只有缩体积（demod 剪枝不可用于 REPL）或 .zo vfasl（已回退）能动；**不动**。 |
| Q7 冷启动 | 启动包顺带解决（单文件） | 随启动包。 |

落点推断：152 → 启动包 ≈115 → Q4 ≈90 → 关窗后移 ≈75。`-q` 98 与裸 38 之差（60 = racket/init 的声明+实例化）是语言层的固定成本，<50 只有改默认语言层才可达，与 10-19 结论相同。

## 3. 建议

1. **启动包 spike（半天）**：用 `raco exe` 的拼接格式把 racket/init 闭包（169 模块）拼成一个段，`-k` 风格 `embedded-load … as-predefined`，量 declare/resolver/read 三项的实际降幅与一致性校验成本。通过则扩到 xrepl/expeditor。
2. Q4 三项延迟（都在树内：xrepl-lib、expeditor-lib 已内置）。
3. 关窗 GC 政策，你定。
