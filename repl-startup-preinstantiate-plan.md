# REPL 启动总解:预实例化语言层进镜像 — 规划/分析/设计

2026-09-07 · 目标 default REPL ~200ms → ~60-80ms 级 · 原则=让实例化垃圾从不产生(治本，非 GC 调度治标)

## 一、问题(已实测确认)

| 事实 | 证据 |
|---|---|
| 默认 REPL time-to-prompt ~200ms | pty min-of-N |
| 其中 ~70ms 是 GC(关键路径) | prompt 处 current-gc-milliseconds=70,裸 REPL=0 |
| GC 收的是 racket/init+xrepl **模块实例化**垃圾(~6MB) | .zo 已用(非编译);裸 291 实例化 vs +语言层 **1792**(+1500) |
| racket.boot 是"已实例化运行时堆镜像" | expander/io/thread/schemify build 期实例化、装载即活 |

**根因**:每次启动重跑 ~1500 个确定性模块实例化,产生确定性垃圾,触发确定性 GC。这些工作每次启动完全一样 → 本应 build 期做一次、镜像化。

## 二、设计目标与红线

- **目标**:racket/init(语言层)+ xrepl 预实例化进启动堆镜像;runtime 反序列化即得活状态,零实例化、零垃圾、零 GC 触发。
- **红线**:(1) minimal 安装/`-q`/非 REPL 场景不受累(不为 REPL 优化让批处理变胖);(2) 语义不变(namespace/module-registry 与现状等价);(3) 镜像与二进制世代耦合(沿用 pb 种子纪律,自产自洽);(4) place 语义正确(namespace 若 place-local 须每 place 重建或共享不可变部分)。

## 三、方案候选(裁决待 subagent a957...)

| 方案 | 机制 | 消除对象 | 障碍 |
|---|---|---|---|
| **A 扩 racket.boot 第四段** | boot.c 三段(petite/scheme/racket)→加预实例化的 racket/init+xrepl 段;to-vfasl 序列化其堆状态 | 实例化**本身**(装载即活) | namespace/module-registry 能否进 static 代序列化;expander 已这么做=先例 |
| **B demod 降实例化** | compiler/demod.rkt 合并模块图,减 1500→少数 linklet | 实例化**成本**(仍实例化,但少) | 只降不消;垃圾仍产生;收益部分 |
| **C 堆快照(4th boot segment)** | 类 save-startup-image:build 期起 racket、快照堆、写镜像段 | 实例化本身 | Chez saved-heap 已移除;需新造 vfasl-writer-for-live-heap |

**判据**:方案 A/C 消垃圾(治本,拿满 ~70ms+实例化时间),B 只降成本(治标偏)。倾向 A(复用现有三段 boot + to-vfasl,expander 是同款先例)。

## 四、前置 spike(定案后第一步)

1. 确认 racket.boot 边界为何止于 expander/不含 racket/base(技术约束 vs 构建选择)——subagent 调研中。
2. 若 A 可行:最小 spike=把 racket/base 一层预实例化进镜像,量 291→? 实例化数下降 + GC 下降,验证机制。
3. namespace/module-registry 序列化的 place 语义验证(能安全跨进程复用否)。

## 五、fallback

若 A/C 架构性不可行:退回 demod(B,部分)+ GC 旁路 v1(+14ms,治标)组合,记为次优。

## 方案定案:A(2026-09-07,用户确认)
扩 racket.boot 第四段/预实例化 racket/init+xrepl 进堆镜像。B/C 排除。可行性 subagent 收窄为产出 A 的实现蓝图(4th boot segment 生成流程 + to-vfasl 序列化 namespace/registry 的改动面 + boot.c 装载第四段 + place 语义处理 + 前置最小 spike 步骤)。下会话按蓝图开 racket/base 预实例化 spike。

## A 的关键修正:非 REPL 零影响是硬约束(2026-09-07,用户追问)
**风险**:racket.boot 是所有进程(-e/脚本/raco/CI)无条件装载。若预实例化状态塞进 racket.boot 本体→非 REPL 进程也背 xrepl+expeditor+语言层(+6-10MB 堆),违红线1。
**修正形态**:A 必须做成**独立第四 boot 段 + 条件装载**,非"扩 racket.boot 本体"。boot.c 已分段(petite/scheme/racket 各 Sregister_boot_file_*),加第四段同款;装载与否由 main.sps 启动早期的 REPL 意图(repl?/text-repl?/命令行,此时已知)决定——交互 REPL 装、-e/脚本/raco/批处理不装(与今天完全一致零影响)。
**验收前置(硬约束)**:(1) 非 REPL 模式实例化数/内存/启动时间与改前逐项一致(A/B 对照);(2) 第四段跨段引用一致性(引用前三段 expander/kernel 对象,vfasl library-entry/singleton 重定位能否跨段解析,=P4b/reloc 同款机制);(3) namespace/registry place-local→per-place 副本(共享不可变编译码+per-place 可变注册表)。
**裁决**:非 REPL 零影响不达成则 A 不落地。已交 subagent 蓝图任务含此。

## 决定性更正:A 字面形态架构阻断(2026-09-07,subagent a957 施工调研)
**错误前提纠正**:racket.boot 不是"已实例化堆快照",是**代码+顶层 form,靠 Sbuild_heap 执行重建状态**。expander 状态每 place 由 namespace-init! 重跑算出,非序列化。**"反序列化已实例化堆"这个能力对闭包不存在**。
**硬阻断证据**:fasl.ss:678-723 wrf 无 procedure 分支→闭包→$oops"invalid fasl object";已实例化模块 instance 变量槽通篇闭包;vfasl 只重定位不快照;module-registry 带信号量+线程锁,place-local 不可序列化。
**⇒ A 字面形态(序列化实例化态进第四段、装载即活零实例化)走不通**。整个"总解"设想建立在不存在的能力上。
**修正方案空间**:
- A 字面:架构阻断,弃。
- **A-demod(可行,不动内核)**:flatten racket/init+xrepl 成单 linklet+predefine 预载(embedded-load as-predefined,main.sps:858)。实例化数几百→个位模块边界,GC 降不归零(instance 仍每 place 重建,eval/module.rkt:34-36)。**=早先当"治标B"排除的路,当时判断错误,它是唯一非内核可落地路**。
- 内核序列化改造(乙):给 fasl wrf 加闭包/代码分支+回避端口/线程/锁(语义不可跨进程)。Chez 核心大改+高风险。
**下步=先 spike 定案(勿急实现)**:Spike-0(半天,REPL fasl-write instance 实证闭包不可序列化,钉死字面 A)/Spike-1(base→init→xrepl 实例化数+GC 基线)/Spike-2(racket/base demod+predefine,量 GC 能压多少→决定 A-demod 值不值+零GC是否非付内核代价)。
**现三段 boot 生成/嵌入/装载链已查清(build.zuo:719-726/848-852/489-521, convert-to-boot.ss:27, to-vfasl.ss:23, embed-boot.rkt:24-149, boot.c:187-225)**,扩段机械改动不难,但字面 A 卡在序列化不在扩段。

## 关键纠正:闭包序列化与 GC 的耦合被高估(2026-09-07,用户追问)
**事实**:实例化那 6MB 大部分是**活状态**(expeditor 6176KB 分配/6132KB 保留/垃圾≈0),非废垃圾。70ms GC 贵在**把这坨活状态从 gen-0 提升到老代**(拷贝式 GC 成本∝存活集),不是清垃圾。
**⇒ 攻击 startup GC 三路,闭包序列化只是路(a)的必要条件**:
- (a) 活状态预置进 static 代(镜像化)→从不进gen-0→从不提升→真零 startup GC。**要闭包序列化**(状态即闭包)。
- (b) 提升推迟到 prompt 后(GC 旁路 v1 修对恢复点)。**不要序列化**。GC 仍发生只是不挡首屏。
- (c) demod 减活状态集。**不要序列化**。部分。
**框架纠错**:①"垃圾不该产生"命题不适用——那 6MB 是语言层**必需的活状态**,必须产生;自由度只有"在哪产生+提升GC何时跑"。②time-to-prompt 只需 GC 别挡 prompt=(b),不需序列化。我之前把 time-to-prompt 收益也拽进内核序列化深水区=过度耦合。③v1"治标"的贬低有偏——活状态非浪费,推迟其提升是正当。
**务实路线翻回**:先修 v1 恢复点(移 prompt 后,不需序列化,预期 -14→接近-70ms);闭包序列化/镜像化(a)留远期档(追求绝对零GC+免内存重复才值内核改造)。demod(c)可叠。
**v1 full-fix 卡点(仍在)**:恢复点需 prompt 后,end-startup-collect! 是 rumble 内部,repl.rkt 看不见;方案=经 #%kernel 原语暴露到 Racket 层,repl.rkt read-eval-print-loop 首次 current-prompt-read 后调(prompt 已 flush)。需 bump 版本。

## Chez 内核闭包序列化改造:风险保障框架(2026-09-07,用户认可走此路后定)
**风险分层**:R1 正确性(free-var捕获/code-ptr重定位偏移=静默错,最危险)/R2 不可迁移对象(闭图夹带端口/线程/信号量/foreign/registry锁,跨进程非法)/R3 性能回归(wrf/vfasl热路径加分支拖慢全体含非REPL)/R4 GC交互(进static代与收集器假设冲突,=data零拷贝同类雷)。
**保障方法**:
- R1=往返bit-exact(code-ptr/free-var/arity/name逐字段)+行为差分(序列化前后同输入equal?,=rktcrypto差分互操作法)+从racket/init图枚举全闭包类型覆盖。
- R2=**build期静态可达性审计**:遍历free-var闭图遇不可迁移类型立即报错停机(不留运行期赌);参照place-message allowed?谓词+三路评审subagentC遍历器清单。**改造前先跑只报告版看racket/init夹带什么**。
- R3=编译期常量/类型分派末位门控保现有fasl/vfasl路指令数不变(meta-cond手法)+**A/B必覆盖非REPL**(raco make/-e/纯base脚本,任一回归即否决)+fasl装载吞吐before/after。
- R4=复用上周三路评审产物(GC非段指针容忍/运行时遍历器旁路审计,裸SegInfo必崩点清单照单核对)。
**执行顺序(否决点前置)**:Spike-0(fasl-write实证)→**R2审计先行(1-2天最省,racket/init闭图可迁移性,只报告)→夹带不可迁移对象则架构判死止损★最强前置否决**→通过才最小内核spike(wrf加纯λ分支,往返bit-exact单闭包)→R1差分+R3热路径+R4评审→扩全图。
**方法论=先量再改/否决点前置/每步bit-exact差分/改动面隔离**。下会话第一步=R2审计(非写序列化器);若racket/init闭图夹带I/O/custodian/lock(大概率)则内核路判死,务实退GC旁路v1修恢复点(-70ms不需序列化)。

## R2 审计裁决:档(B)内核路有条件可行(2026-09-07,subagent a68c,运行时实证)
**否决门未触发**。从加载 racket/init 后 namespace 全图遍历 81827 对象(未截断,897 instance/1062 module-inst/6404 闭包)。**无任何本质捕获的不可迁移对象**;夹带者全部可外置:①对象自身方法闭包(端口=代码+状态一体,匿名#f捕获,per-place整体重建)②低层thread/place调度器闭包(rumble/thread运行时,镜像里以代码存在)③参数/thread-cell间接(printf等free-var捕获参数对象非端口值,端口值在parameterization,per-place重建)。
**关键结构**:通往thread/place/ports子图只有两座桥——module-registry lock-box(残留未清cons(evt,weak-box thread))+ namespace root-expand-context(f2)。切断即净。阴性有利:0续延/0subprocess-tcp-udp-future/0裸cpointer。
**外置清单(反序列化后重绑)**:①快照前 registry lock-box 重置#f(一步斩thread→place→全place-local端口/custodian子图,最高优先)②namespace root-expand-ctx(f2)复位未强制delay③参数默认thread-cell值per-place重播种(security-guard/env-vars/prng/place-local)④place-local寄存器表/初始parameterization不序列化per-place重建⑤**weak-pair1953/ephemeron334/weak-box1061=Chez fasl格式不支持,须丢弃重建或转强引用=内核路最大机械工作量,非架构死点**⑥inspector1065/namespace1064=快照载荷本身。
**工作重心重定位**:端口/线程可外置(易);**内核路主体=fasl弱引用/ephemeron序列化**(先做可行性小样:剥离缓存+重建不破intern语义)。
**下步**:①R2b补审计(racket/init+xrepl,重点xrepl的readline/终端端口具名捕获)②弱引用fasl小样③抽查语言函数常量折叠边界有无把线程/端口焊进常量池。三者通过才启动wrf闭包序列化内核spike(走R1-R4保障框架)。遍历器脚本在scratchpad traverse.head/driver.ss+report.log(方法论坑:record-type-field-names不含继承字段须沿parent累加;Chez哈希表也是$record须先拦)。
