# pvector 对齐 list 一级运行时支持：规划与推进

分支 `feat/pvector-args`（基 `47f1e8eb46` = v9.3-dev 含 vector-apply/pvector-apply 与派生产物修复）。
本文档随实施逐步更新；状态标记：☐ 未开始 / ◐ 进行中 / ☑ 完成 / ✗ 放弃（附原因）。

## 背景与对照表（2026-08-28 实测）

| 能力 | list 的内核机制 | pvector 现状 |
|---|---|---|
| 实参序列（apply 末位） | `$apply` + `apply0..3` 手写入口 | ☑ 已有（`$apply-pvector` / `pvector-apply`，9.3.6） |
| rest 形参收集（被调方） | `dorest0..5` 手写入口 | ✗ 无对应 |
| 变参构造（n 值 → 容器） | 即 rest 机制，零额外代码 | ⚠ 112 条 arity 子句 ×2 份（adapter 296KB + pvector.rkt 289KB .zo，∝n²；>112 退化收 list） |
| 多值接收 `(call-with-values g pvector)` | 对偶天然 | ⚠ 走同一批子句 |
| 字面量/quote/.zo fasl | 天然 | ☑ `#pvector` 读写、literal-pool；quote 字面量进 .zo 与 `racket/fasl` 于 2026-10-14 补齐（此前所有编译产物写出路径均报 cannot marshal/cannot write，本行原 ☑ 失实；现 `s-exp->fasl` 结构化编码：tag 45=pvector 形状、tag 46=节点，节点经 fasl 图引用去重，解码经受检构造器直接建树（原语经 `#%pvector-structure` primitive table，无表的宿主写拒绝/读摊平）；MD .zo 走 Chez 原生 fasl，空 pvector 注册回单例；解码 65536 元素 1.3ms vs raw 读模式 74ms，MD/MI/syntax 字面量全部往返；两 subagent 评审后修 5 项，见 .commit） |
| match/for/sequence/stream/serialize/place 消息/equal+hash/打印 | — | ☑ |
| 语法一级公民（read-syntax 逐元素包装、datum->syntax/syntax->datum、syntax-case 模式/模板、quasisyntax、quasiquote、syntax/parse、strip-context） | 天然 | ☑ 2026-10-19 B 方案落地，见 pvector-language-face-design.md v2 |
| 内存表示 | pair 无头字（2 字/节点） | ✗ 记录节点带 rtd 头字（类型常数化可省 17~20%） |
| 库面组合子 | sort/reverse/filter/fold/member/… | ✗ 缺 sort/reverse/filter/andmap/ormap/foldl/foldr/member/index-of/count/partition；map 仅单序列 |
| keyword-apply 序列位 | list | ✗（独立接口路线下有意未覆盖） |

## 阶段总览

- **P1 ☑(待提交) `$pvector-args` 变参构造入口**：一个手写入口统一 (a) `(pvector v …)` 全 arity 原生（删两份 112 子句，−585KB .zo）、(b) `(call-with-values gen pvector)` 任意值数原生、(c) 为 rest-形参收 pvector 铺路。
- **P2 ☑ 库面组合子补全（P2a+P2b 已落，见下）**：sort/reverse/filter/foldl/foldr/andmap/ormap/member/index-of/count/partition、map 多序列。`pvector-reverse` 需设计（finger tree 有 O(1) 反转视图的可能，勿写成 O(n) 拷贝了事）。
- **P3 ✗ 节点类型常数化（放弃，2026-08-30 实测裁决）**：三项收益清算——(a) `pvector?` 提速实测仅 ~0.4ns（sealed-rtd 比较 3.39ns vs `vector?` 标签检查 2.97ns，均近基线 2.92ns），已可忽略；(b) 手写入口免传 rtd 已由 rtd 传参/finisher 单元解决；(c) 内存收益不需要类型常数（见 P3′）。跨自举全部代价换不来实质收益。
- **P3′ ☑ 节点字段打包（零跨自举的内存路线，用户已批，独立新分支）**：measure 与 level 合并为一个 packed 字段 `(measure<<6)|level`——**node2 5→4 字（−20%）、node3 6→5 字（−16.7%）**，保持两个 sealed 记录类型不合并（合并反而让 node2 变 5 字）。纯 rumble 改动 + `$apply-pvector` 入口字段偏移同步。代价：measure/level 读取各多一个移位（ref/split 下降热路径，O(log n)/次，须同树 A/B）；长度语义上限 2^54（物理不可达，128PB）。nongenerative UID 须 bump（防旧布局 fasl 误读）。
- **P4 ◐ rest 形参（P4a ☑ 适配器已落 / P4b ✗ 原生包装放弃，见下）**：`(lambda args …)` 的 pvector 变体；入口由 P1 提供，难点在表面语法与 schemify/linklet ABI，先做库级适配器（`procedure->pvector-rest`）探路。
- **P5 ☐ 视需求**：keyword-apply 序列位、跨 place 不可变共享。

## P1 设计（定稿）

**机制**：仿 Chez `vector`（`(define vector ($hand-coded 'vector-procedure))`——变参、把 n 个实参从寄存器+栈帧一次填进新 vector）。新入口 `$pvector-args-procedure`：
1. 复用 `vector-procedure` 的收集 IR：n = `%ac0`，alloc 向量，寄存器与帧槽线性填入；
2. 收集完**经 libspec 尾调**新库入口 `($pvector-from-fresh-vector v)`（单实参，1 个参数寄存器即可，i3 也安全，不需要 meta-cond）；
3. 该库入口调 `$pvector-finisher`（prims.ss 可变单元，默认抛"未初始化"）；rumble 启动时 `$set-pvector-finisher!` 安装真实现：新鲜向量按长度分派——0→空单例、1..4→专用构造、其余→`core-vector->pvector/no-copy`（取得所有权，零拷贝）。

**为什么必须绕 finisher 单元**：入口在 Chez 自举期生成，拿不到 rumble 运行期才创建的 rtd 与空单例（与 `$apply-pvector` 传 rtd 同源的问题）；且任何 Scheme 层变参包装都会先物化 rest list，自败。

**命名**：入口 `make-info` 名直接用 `"pvector"`（如 `vector` 之于 vector-procedure），错误消息与 `procedure-name` 面向用户正确；`#%kernel` 暴露为 `core-pvector-args`；collects 侧 `pvector` 绑定到它（无 core 后端时回落小 case-lambda + `list->pvector`）。

**风险与对策**：
- n≤4 新路径（vector 分配+间接调+分派）可能比现有专用子句慢——实测；若回退 >20%，备选：入口对 n≤4 直接以寄存器传参尾调 4-ary 小 finisher。
- 库入口 libspec 注册方式需考古（找 `apply0` / `$check-continuation` 的注册位置照抄）。
- `(apply pvector lst)` 路径连带变化：`$apply` 摊开 n 实参 → 本入口收集，任意 n 原生（现状 >112 退化）。

**验收**：
- 正确性：pvector.rktl / racket-test 的 pvector.rkt(rackunit 2537 行) / apply-new-test 376 断言全过；`(procedure-arity pvector)` = 0 起；`(call-with-values … pvector)` n∈{0,1,5,113,10⁴} 与 list 版一致；`(apply pvector lst)` 大 n 一致。
- 性能：构造 n=1..8/40/113/1000 头对头（同树 A/B）；n≤4 回退 ≤20%，n≥5 应显著快于现状（现状≥113 收 list）。
- 体积：两份 .zo 合计约 −585KB。
- 构建：`make base` + 全量 `raco setup -D` 零错误（吸取 info-cache 教训，不再单跑 make base 收尾）。

### P1 步骤
1. ☑ 考古：库入口 libspec 注册机制（apply0 怎么注册）
2. ☑ Chez 侧：cpnanopass 入口 + library.ss 库入口 + prims.ss 单元/绑定 + primdata 登记
3. ☑ 纯 Chez 冒烟：装假 finisher，验证收集与尾调（不动 rumble 即可测）
4. ☑ rumble finisher + kernel 登记 + collects 两处改绑定并删 112 子句
5. ☑ 全量验证（rktl ×2 + rackunit + 376 + setup -D）
6. ☑ 基准与 .zo 体积对比（同树 A/B）
7. ◐ .commit（含 keyword-apply 未覆盖等既有事实不变的说明）

## 决策日志
- 2026-08-28 用户批准整体规划与"按步推进+更新文档"的工作方式。
- P1 采用"收集进新鲜向量 + finisher 单元"而非"入口内直接构造 finger tree"：后者需在 IR 里分配记录并再度传 rtd，复杂度高收益小；向量中转正是现有 `small-immutable-vector->pvector` 快径的形状。


## P1 结果（2026-08-29）

**实现落点**：`cmacros.ss` 库入口表尾 `($pvector-from-fresh-vector #f 1 #f #t)`；`library.ss` 入口转发 `$pvector-finisher`；`prims.ss` finisher 单元（默认抛未初始化）+ `$pvector-args`；`cpnanopass.ss` 入口=vector-procedure 收集 IR + `(goto <libspec-label>)` 尾调（live 集用 `reg-cons*`，`reg-list` 是只收标识符的宏）；rumble finisher = `core-vector->pvector/no-copy` 本尊（只读元素、0..4 小情形已内置）；adapter/pvector.rkt 换绑定、删两处生成器（公开 `pvector` 宏的调用点内联展开保留，`pvector/proc` 仅值位置）。

**血的教训**：`declare-library-entries` 按位置枚举索引，**插表中部会推移后续全部索引**、破坏自举期宿主↔新码契约（首例症状：`fxpopcount32` 的报错库入口被错位命中，收到 nanopass 语法结构）。**只能追加表尾。**

**验证**：pvector.rktl（含新增值位置构造节）/vector.rktl 全过；376 断言过；rackunit `pvector-runtime-adapter.rkt` 过；rackunit `pvector.rkt` 唯一失败在旧构建同样复现=**预先存在**（1399 行打印期望：`bc-native-public-pvector?` 辅助与 CS 实际打印分支不匹配，raw 字面量 `#pvector(…)` vs 期望 `#<pvector:3>`/wrapper 形），记入待办。

**同树 A/B（min-of-15）**：apply-n1 0.72×、n3 0.79×、n5 0.69×、n8 0.75×、n40 0.96×、n113 0.71×、n1000 0.76×；cwv-n3 0.71×、n6 0.67×——**全线快 21~33%，无一回退**。**.zo**：adapter 296,410→106,571（−189.8KB）、pvector.rkt 289,326→252,549（−36.8KB），合计 **−226.6KB**。

**待办（新发现）**：racket-test `pvector.rkt:1399` 打印期望预先存在失败；`make base` 清 info-cache 陷阱再次确认（每次全量安装后跑 base 必触发）。

## P2a 结果（2026-08-29，`feat/pvector-combinators` 分支）

**落地 12 个组合子**（adapter 单份实现 + 公开 wrapper 后端薄壳 + `exported- = (if bc-native-public? raw: 包装)` 既有模式）：
`pvector-fold-left` / `pvector-fold-right`（**签名 `(pv init proc)`，回调序循 R6RS**：left=`(proc acc elem)`（与内核原语 `core-pvector-fold-left` 一致）、right=`(proc elem acc)`）、`pvector-reverse`、`pvector-sort`（`#:key` `#:cache-keys?`，vector-sort! 中转 + `fresh-vector->pvector` 零拷贝回收）、`pvector-filter`（core 后端用 `with-core-pvector-builder`）、`pvector-partition`（两遍 filter）、`pvector-count`、`pvector-andmap`/`pvector-ormap`（`let/ec` 早退，语义同 list 版含末值/首真值）、`pvector-member`/`memq`/`memv`（**循 vector-member 惯例返回索引**，member 默认 `equal?` 可传自定义）。

**决策记录**：
- `pvector-reverse` 取 O(n)（fold-left 逆序填新鲜向量 + no-copy 建树）。O(1) 反转视图被否：需 wrapper 类型或核心方向标志，前者破坏 `pvector?` 单一性、后者让所有访问器多付分支——为罕见操作向全体收税，不划算；若 P3 动节点布局时可重估。用户预警的"勿 O(n) 拷贝了事"以此设计分析回应。
- member 族返回**索引**而非后缀 pvector：pvector 是 vector 族亲缘（racket/vector 的 vector-member 同型）；后缀语义可由 `pvector-drop` + 索引一步得到。故弃 index-of（冗余）。
- adapter 层报错 who 为 `core-*`：与模块全部既有导出一致（实测 map/length/ref/append 皆然），不在本批单独改，列为整体打磨项。

**验证**：pvector.rktl 新增组合子节（含 n=1000 中间树覆盖与错误路径）全过；rackunit adapter 套件 0 失败；rackunit pvector.rkt 仍仅 1399 那个预先存在失败；376 断言过；**完整 `make cs` 零错误**（12 个新 defproc 渲染通过）。

**P2 余项**：`pvector-map` 多序列并行版；1399 打印期望修复；（观察项）导出层报错 who 统一。

## P2b 结果（2026-08-29，同分支 `feat/pvector-map-multi`，两提交待 merge）

- **`d75b359ad6` (TEST)**：修 rackunit `pvector.rkt:1399` 预先存在的打印期望——分支判别改为"公开构造器是否给出 raw 值"（原辅助按 vm='racket 判，CS+core 取错分支且两分支期望皆为旧打印器）；`write` 断言改为回读等价 + `#pvector(` 前缀（不锁内部表示），`display`/`print` 对紧凑形。**rackunit 套件自此零失败。**
- **`9abe9f9d4e` (FEAT)**：`pvector-map` 变参化 `(pv ...+ proc)`——首 pvector 走 fold 原语驱动、其余经新鲜向量 O(1) 定位、builder 收集；单序列旧径与 `values` 恒等捷径原样保留；长度不等报 `pvector-map: pvectors have different lengths`。文档 defproc 更新为变参形。完整 `make cs` 零错误。

**P2 完结。** 余下观察项（不阻塞）：导出层报错 who 统一为公开名（模块全体现状为 core-*）。

## P4 结果（2026-08-30）

**P4a ☑（`feat/pvector-rest` 分支 `eb32354194`）**：`procedure->pvector-rest`——返回变参过程，把全部实参装成一个 pvector 调给单参 proc（rest-lambda 的 pvector 对应物）。参考实现经 rest list；checks（procedure? + arity-includes 1）、rktl 测试（0/3/200 实参、apply 转发、arity、两类错误）、scrbl 文档齐。

**P4b ✗ 原生包装闭包（放弃，记录如下）**：目标是仿 `$wrapper-apply` 家族做 `pvector-rest-wrapper` 手写库入口（闭包布局 [code, proc, arity-mask]，收集实参进向量后经 `$pvector-rest-invoke` 调 finisher 再调 proc）+ `$make-pvector-rest-procedure` maker。**失败模式**：入口一经安装（`define-hand-coded-library-entry`），新构建的 racket 在 setup 阶段即 "invalid memory reference"，且纯 Chez 里 maker 造出的闭包 `$closure-code` 都取不出（code 槽为垃圾）、`procedure-arity-mask` 读出乱数——**与入口体内容无关（最小尾返回体同样崩）**。二分定界：表行 + `$pvector-rest-invoke` Scheme 库入口 = 无害（P4B5:0）；加上 {表行 + 安装 + cpnanopass case} 即致损。控制组 `$make-wrapper-procedure` 全程正常。vfasl 无 wrapper 白名单（生成式 reloc）。**未定位到机制层根因**；候选：带 fv* 的手写库入口在文件中段安装 vs wrapper-apply 三兄弟在 library.ss:131 早段安装的某种顺序/分块约束（`installs-library-entry?` 的 vfasl 组合排除机制在 s/vfasl.ss:179 有注释）。**止损理由**：省的只是 rest-list 的 ~0.8ns/元素，排查已入 boot 格式取证深水区。Chez 侧已全部回退，P4a 提交为 P4 终态。若将来重启：先在纯 Chez 树上最小复现（一个 fv* 手写库入口装在文件尾段），并对比 library.ss:131 位置安装是否即好——那将直接定位约束。

**途中发现（有价值）**：库入口的**安装顺序约束**——入口代码对象内嵌的库引用（`lookup-libspec`）在安装时链接，被引用入口必须已装（首次症状 "$lookup-library-entry: entry 636 uninitialized"）。

## P3′ 结果（2026-08-30，`feat/pvector-node-pack` 分支，待 merge）

**位布局（用户已评审）**：`packed = (measure<<6)|level`，fixnum 60 位内恰好装下（measure≤2^54−1 时 packed ≤ 2^60−1，压线不溢出）；level∈[1,54]（2 分支下界推得 ≤log2 measure），`logand 63` 判 leaf 无歧义。长度上限 2^60→2^54（128PB，物理不可达），**守卫放增长入口**：`core-pvector-append/known-length`（唯一不经向量中转的倍增通道）与 `core-make-pvector`，O(1)/操作。

**实现形状**：记录构造器改内部名 + 同签名打包包装函数 ⇒ **19 个裸构造点零改动**；measure/level 读取经两个漏斗函数改读 packed ⇒ 调用方零改动；UID bump（`cutie-pvector-packed-node-1/2`）；`$apply-pvector` 入口同步（leaf 判定改 `(logand fld0 (fix 63))==(fix 1)`，children fld2..4→fld1..3）。

**踩坑（已修）**：入口 walk 循环里 `%td` 是 emit 的目的指针贯穿全程，误用作 packed 刮擦寄存器 → 野写 "invalid memory reference"（rktl 6 项失败 + 中间树 apply 崩）。改借 `%ts`（rtd 缓存），分支两侧从 tc 槽 `(ref-reg %ac1)` 回载后再做描述符比较。**手写入口的寄存器生命期必须全程列表核对，emit 类辅助宏隐式占有的寄存器最易漏。**

**验证**：pvector.rktl/vector.rktl 全过、rackunit 两件 0 失败、深树/中间树 apply/越界守卫定向测试过。
**性能（同树 A/B，min-of-15）**：单次深树 ref +4.5~4.9%（每层 1 个 fxsrl，1k 深度 19.1→20.0ns）；sweep/fold/apply/append/take ≤+3.3%，construct −2.2%——批量路径基本无感。
**内存（shape-stats 精确计数）**：from-list 树 **−16.7%**、append 构建 −17.1%、cons 构建（node2 为主）**−20.0%**（节点字数；含脊柱同量级）。
## P5-2 规划（2026-08-31，`feat/pvector-place-message` 分支）

**目标**：pvector 过 place 通道，对齐 list 的零拷贝直传级（direct）。v1 范围 = 仅 direct：全体元素满足 `place-message-allowed-direct?` 的 pvector 指针直传；含可变元素 → 维持 contract error（今日行为）。拷贝级与经 pvector 的引用环留待后续（涉及 make-reader-graph 认知 pvector，另一层工程）。

**实测依据（100k 元素，min-of-30，主线构建）**：list 直传 263ns/元素（`allowed?` 对每个 pair 做不可变 hasheq 环检测记录）；list 拷贝路径 483；pvector 纯遍历检查 1.5。pvector 构造上无环 ⇒ 脊椎免图记录，direct 检查预期 ~3-5ns/元素、零分配——**比 list 直传快约两个数量级**。

**prop:place-message 路线判死（架构）**：该 prop 由 thread 层创建，rumble 先于 thread 加载，record 定义时 prop 不存在；hash/string 等 rumble 级类型全部硬编码于 `allowed?` cond，pvector 同类同待遇。

**实现（4 处源改动 + 1 处派生产物）**：
1. `cs/thread.sls`：仿 `#%engine` 注册 `'#%pvector` 原语表——`pvector?`(=core-pvector?)、`pvector-cursor-start/value/next`、`impersonator?` 复用现有。
2. `thread/place-message.rkt`：`import-from-primitive-table` 取表（缺表回退 `pvector?`=恒假 ⇒ BC/旧宿主行为不变）；`allowed?` 的 loop 增一个 direct? 参数（原为闭包常量，pvector 分支需对元素强制 direct 语义以保 `place-message-allowed?` 与 put 行为一致）；新增 pvector 分支：非 impersonator + 游标遍历元素全过 direct 检查 → 允许；`message-ize` 同判定，过则原值直传（如 place-shared bytes 之例），否则 fail。`un-message-ize` 零改动（直传值不是 message-ized）。
3. `thread/bootstrap.rkt`：host 端假表（`pvector?`=恒假，分支死代码），demo/host 编译不受宿主版本影响。
4. `make derived` 再生 `schemified/thread.scm` 并随源同提交（派生产物纪律）。

**无版本 bump**：新表仅 thread.scm 内部消费，不触 expander/collects 绑定面。

**验证**：pvector.rktl 加节（同 place 内 put/get `eq?` 断言证零拷贝、可变元素 contract error、`place-message-allowed?` 一致性、深树/append 中间树形状）；真跨 place 收发测试；bench 复测 pvector vs list 直传；make base + 全量 rktl×2 + rackunit×2。

## P5-2 结果（2026-08-31，`feat/pvector-place-message` 分支 `34dcd4ebb5`，待 merge）

**落地形态与规划一致**：`'#%pvector` 可选原语表（thread.sls 注册 4 个 rumble 谓词/游标原语；缺表=旧行为，BC/旧宿主零影响）；`allowed?` loop 的 direct? 由闭包常量改循环参数，pvector 分支对元素强制 direct 语义（保 `place-message-allowed?` 与 put 一致）；`message-ize` 直传分支；`un-message-ize` 零改动。bootstrap.rkt 无需改（缺表回退已覆盖 host 编译）。thread.scm 已随源再生同提交。

**验证**：pvector.rktl（新 place 节：6 个 eq? 直传断言含 append 中间树/嵌套/空/拷贝消息内共享、谓词一致性、拒收路径）+ vector.rktl 全过；rackunit pvector.rkt 0 失败（"place message boundary" 用例从旧边界断言更新为新行为）；adapter 套件 0 失败；place-pvector.rkt 真跨 place 往返 eq? + 子侧构造回传全过。

**性能（100k 元素，min-of-30）**：pvector 直传 put+get **6.26ns/元素、零分配**；同数据 list 直传 292.8ns（环检测 hasheq 记录）——**47×**。纯遍历下界 1.41ns，差值=表间接的游标调用+通道常数。

**观察项（不阻塞）**：检查循环若下沉为 rumble 单原语（融合"元素是否全直传候选"粗筛）可望向 2ns 靠近，等有真实负载再说；place-shared fx/flvector 与 cpointer 作为元素在 v1 被拒（它们属"仅非 direct 允许"类），如有需求可放宽。

**遗留陷阱确认 ×2**：make base 清 info-cache（本轮两次撞上 raco 子命令消失，均按既有对策处理：raco setup -D / 直接 racket 跑测试文件）。

## P4b 重启（2026-08-31，`feat/pvector-rest-native` 分支）——根因已定位

**根因 = `cpprim.ss:3512` 的 `hand-coded-closure?` 白名单。** `$hand-coded` 对名单内的名字（nuate/nonprocedure-code/error-invoke/invoke/三 wrapper/popcount-slow/cpu-features）返回裸 code 对象（`label-ref`），名单外一律生成闭包字面量（`'closure` info-literal）。库表里绝大多数手写入口的安装值本来就是闭包（dorest0 等，经闭包协议调用）——**trio 才是特例**。未进名单的 `pvector-rest-wrapper` 被包成带垃圾槽的闭包装进表，而 `make-wrapper-closure-alloc` 的 `'library`+`code-data-disp` 字面量按裸 code 解析入口值 → code 槽野指针 → "invalid memory reference"。修复 = 名单加名字，一行。

**证伪记录**：早段安装假说 ✗（library.ss:134 安装同样崩）；表索引/equates 偏移假说 ✗（新鲜表与 pb equates 逐项一致：popcount-slow 630/cpu-features 632/size 638）；vfasl 分块假说 ✗。当年 P4b 五轮排查全部烧在错误假设空间。

**定位路径（有复用价值）**：纯 Chez 复现 → `$lookup-library-entry` 逐槽分类（trio=code、我的=procedure，fv-count 2 证明 codegen 本体正确）→ `(compile '(lambda () ($hand-coded 'x)))` 直接求值对比 → grep 特例产生点。**手写库入口若要被 `make-wrapper-closure-alloc` 引用，必须同时上 `hand-coded-closure?` 白名单**——这就是当年缺的那句话。

**连带发现（待处理）**：pb 检出（racket/pb 本地 HEAD）的 boot 文件是 P4b 时代含幻影行（$pvector-rest-invoke）的 319 行表产物（size 638），而主线源码现为 318 行（636）——主线构建自洽（宏新鲜加载 + equates 现场再生），但 pb 检出与主线源存在一行漂移，若 P4b 真落地（表回到 319/638 且行位吻合）恰好归位；若不落地，宜择机用主线源重跑 pb-build 归零。

## P4b 落地（2026-08-31，`feat/pvector-rest-native` 分支 `480bf0b5d1`，待 merge）

**实现**：`pvector-rest-wrapper` 手写入口（收集实参→新鲜向量，$pvector-args 同款 IR）+ `$pvector-rest-invoke` Scheme 库入口（vector→finisher→调 proc）+ `$make-pvector-rest-procedure` maker（wrapper 闭包 [code, proc, arity-mask]，cpprim inline + prims 检查层）+ rumble `core-procedure->pvector-rest`（#%procedure? 且 $apply-entries-available? 才给原生，否则 #f）+ #%kernel 原语 + adapter/collects 接线（applicable struct/BC 保留 rest-list 回退，wrap 时选定）。版本 9.3.7。

**性能（min-of-30）**：vs rest-list 参考实现 n=3 −12%、n=10 −27%、apply n=200 −38%、n=1000 −36%（≈3ns/元素，瞬时分配减半）——超前估（0.8ns）约 3×。

**验证**：pvector.rktl（含新增原生覆盖节：applicable struct 回退、chaperone 插入保持、千元素 fold）+ vector.rktl 全过；rackunit 两件 0 失败；arity mask −1、0/3/10/200 实参、apply 大参数全对。

**P4 状态：☑ 完结**（P4a 参考路径保留为回退；P4b 原生路径为主线）。落地要点=hand-coded-closure? 白名单（根因节已记）。

**自举链审计（2026-08-31 实证封印）**：从**已提交** pb boot（racket/pb 本地 HEAD d8c788e，检出零改动）+ 清空的 Chez 构建区全量重建 P4b 分支 → 构建零错误、setup 通过、原生包装命中、pvector.rktl 全过。结论：**P4b 不构成自举链变动，pb 仓库无需更新**；库表加行/新原语/新手写入口均经"宏从源新鲜加载"在单次常规构建内传播。真正需要动 pb boot 的只有 fasl/重定位格式、pb 字节码集、老 reader 不识的语法这类"老编译器无法从源码现场重导"的变更。既有漂移（pb boot=P4b 幻影行 319 行表产物）属卫生问题非正确性问题，是否重跑 pb-build 对齐由用户定。

**漂移归因修正（2026-09-01）**：pb 种子提交 d8c788e "new build" 作者=Matthew Flatt（2026-05-13），`HEAD == origin/v9.3`——**种子从来都是官方 racket/pb v9.3 原样**，"P4b 幻影行时代本地产物"之说不成立。【此段归因有误,见下方终版修正】结论不变：旧种子构建新源正常（宏新鲜加载）；今日以合并后主线（320 行）重跑 pb-build 换为自产自洽种子，`make pb-stage` 惯例（amend 单提交 "new build"）落盘，**不 push**（origin=官方仓库）。

**漂移归因再修正（终版，2026-09-01）**：昨日"已提交 pb equates=638"系**脏检出读数**——当时检出里躺着 p4b3 链再生的文件（复原发生在当日 17:29 之后）。真实已提交种子 equates=**0x27A=634=317 行=与上游 master 表完全一致**；"上游多 2 行""幻影行"两说均为脏数据产物，作废。最终事实：官方种子=纯上游 317 行表,fork 主线=320 行,旧种子构建新源正常（已实证）。另:今日 pb-build 实走 **rktboot 纯源自举**路径（无系统 scheme 时的分支）,且因 boot mtime 新于源被判 Up-to-date 跳过——强制重建需先删/触碰产物。

## 收尾（2026-09-01）：P4b 合入主线 + pb 种子归零

- **merge `631d2fb25d`**（P4b→v9.3-dev，无冲突，合并树与已验证分支树逐字节一致）。
- **pb 种子重生**：rktboot 纯源自举路径、合并后主线 320 行表（equates 0x280=640），按 pb-stage 惯例 amend 为单提交 `8a3bf18 "new build"`（作者本人）；**不 push**（origin=官方 racket/pb）。注意 `make pb-stage` 目标本身只适用于换分支名场景（`git branch` 撞已有分支报错），同分支刷新须手动 `git add . && git commit --amend --reset-author -m "new build"`。
- **新种子终验**：清空 Chez 构建区 → make base 零错误；native rest 包装命中、place 零拷贝 eq? 通过、派生 equates 与种子同为 0x280、pvector.rktl 全过。
- 下一个 src.tgz 发包将自动携带自产自洽种子（打包管线零改动）。

## 崩溃级缺陷修复（2026-09-02，`fix/pvector-host-procedures` 分支 `403b6c385a`，待 merge）

**发现**：探测 P5-1 边界时挖出——rumble 层直调用户过程的入口把 Racket 级 `procedure?`（含 applicable struct）放行的值直接交给手写入口/Chez 调用 → 关键字过程与 applicable struct 一律 "invalid memory reference"。崩溃面=`pvector-apply`/`vector-apply` 全分支 + `pvector-map`/`for-each`/`fold-left`（含 unsafe 变体）；adapter 层组合子（filter/sort/member/andmap/count/multi-map）因走 Racket 代码的 `|#%app|` 抽取而无恙。该缺陷自 vector-apply 特性起即存在、已随主线发布线。

**修复（更优方案）**：rumble 新增 `extract-host-procedure`（`slow-extract-procedure` 旁）——host 过程原样透传，其余走 `|#%app|` 同款抽取得到等价 host 过程（procedure 值 prop:procedure 插 self、chaperone/impersonator/continuation 全处理、arity 预检报原过程名）。每次调用抽取一次、逐元素零开销；host 过程只多一个指针测试。**附带收益**：applicable struct 的 `procedure->pvector-rest` 也升级为原生包装路径；continuation 可过 `pvector-apply`。关键字过程按普通位置调用语义：可选关键字取默认值、缺必选关键字报标准 contract error。

**验证**：16 项崩溃/行为探针全绿（含 500 元素大树、arity 错配、必选关键字缺失、chaperoned vector 插入保持）；pvector.rktl/vector.rktl（各新增专项节）全过；rackunit×2 零失败。

## E1 报错 who 统一（2026-09-03，`fix/pvector-error-who` 分支，待 merge）

**实测泄漏面**：45 探针扫全部公开入口坏参 → 38 处漏内部名。两类：①内核直连 op 的 rumble who 带 `core-` 前缀（length/ref/set/first/last/cons/pop/append/map/for-each/fold-left/take/drop/split/insert/delete/copy 家族）；②adapter 派生 op（fold-right/reverse/sort/filter/partition/count/andmap/ormap/member/memq/memv/->list/->vector）无入口检查，错误从首个触碰坏参的底层原语漏出。

**修复**：rumble 全部 who 改公开名（view-left/right → pvector-first/last 特映射）；`->list`/`->vector` 用自名检查替代借用 length 的检查；adapter 派生 op 加 `check-pvector` 入口检查（含 index-where* 漏斗，member/memq/memv 一并覆盖）。复扫零泄漏；rktl 新增 16 条消息正则锁定断言。既有测试只钉谓词未钉文本，零改动；rackunit 的 core- 引用是函数名映射断言，不受影响。

**观察项（新记）**：`pvector-empty?` 对非 pvector 静默返回 #f（hash-empty?/stream-empty? 惯例是报错）——契约设计问题，另行裁决。

## empty? 契约收严 + E2 快路径（2026-09-04，`feat/pvector-call-polish` 分支，待 merge）

**`797c87e207` (FIX)**：`pvector-empty?` 从 any/c 宽容谓词改为要求 pvector（对齐 hash-empty?/stream-empty? 惯例，用户裁决）。只动导出绑定；模块内部（含 `(pvector)` match 模式——对任意匹配值必须失败而非报错）经宏卫生引用内部宽容谓词，零波及，match 行为有测试钉住。文档契约 any/c→pvector?、示例更换；rackunit 一处宽容断言转 check-exn。

**`23996ffb81` (REFACTOR)**：place direct 检查快路径下沉 rumble——新原语 `core-pvector-place-atomics?`（经 '#%pvector 表暴露）：树递归 for-each + call/1cc 一次性逃逸，只认无条件可直传的原子值（数/符号/字符/布尔/keyword/void/null/不可变字符串与字节串）；否决时回落完整游标 walk（pair/嵌套 pvector 仍走全规则）。**6.26→1.70ns/元素**（put+get 全程，vs list 直传约 178×）。第一版用游标只到 5.14——**游标帧栈每元素 ~3ns，批量遍历应走树递归**（教训）。

**验证**：rktl×2 全过（含 match 卫生守卫、strict empty? 三断言）、rackunit×2 零失败、跨 place place-pvector 过、混合尾拒收/嵌套放行/直传 eq? 三正确性例过。

**分支现挂三提交**（E1 who 统一 + empty? + E2），一并待 merge。观察项清零。

## P5-1 落地（2026-09-04，`feat/pvector-call-polish` 分支 `bfeec56e17`）

**`pvector-keyword-apply`**：keyword-apply 的 pvector 序列位对应物（v1=纯函数形态，调用点直传关键字不合并）。同源校验（sorted/distinct kws、长度匹配、序列位按本操作名检查 pvector）后复用 kw.rkt 抽取机制——抽取出的过程以两个关键字表为前置位置参数，整个调用骑 `pvector-apply` 原生入口，零中间 list。kw.rkt 新导出 `keyword-procedure-extract/method`（唯一内核层改动）。关键字过程/空 kws 普通过程/applicable struct/self 插入 prop:procedure 方法全走同一路径；普通过程给关键字经抽取的延迟包装报标准错误。

**验证**：冒烟 6 例全过（含 self-method 关键字 45=3×(10+5)）；rktl 12 组新用例（基本/前置位/必选关键字缺失/乱序拒收/长度不匹配/非 pvector 序列位/千元素/who 断言）全过；rackunit×2 零失败。

**批次总账**：feat/pvector-call-polish 四提交（E1 who / empty? 契约 / E2 快路径 / P5-1），调用面宣告完整，观察项清零，一并待 merge。

## F 基准面板完成（2026-09-04）

全量数据与裁决见 `pvector-vs-list-benchmarks.md`。要点：pvector 胜域=结构操作（length 42274×/ref 1713×/append 28219×/尾插 56801× @100k）+调用面（apply 1.6×/place 178×）；list 胜域=线性一遍过（map/迭代/头操作 2-5× 常数优势）；内存 pvector +50%/元素。**裁决：全面替代不成立，互补双雄；B 的方向=胜域零摩擦而非改 list 默认表示。** 面板暴露两个 pvector 常数优化点（map 路径、reverse 树反转），记为观察项。

## 穿刺规划：map / reverse 常数优化（结构保形路线，2026-09-04）

**S0 归因（已完成，零改动实测 @100k）**：map 全程 5.53 = 树读+proc+写 vec ~2.8 + `vector->pvector` 重建 **4.24**；reverse 5.26 = 读出 1.21 + 同款重建。fold 基线 1.50。两点同根因：**经 vector 中转触发的再分块重建税 ~4.2ns/元素**。共同手法 = 结果树直接从源树构造，消灭中转。

**S1 map 保形穿刺**（先行，收益面大）
- 实现：rumble `core-pvector-map` 的 else 分支（len>4）改结构保形递归——large-finger 逐 digit（p0-p3/s0-s3 内联字段）、node2/node3 以**同 packed 字**（measure/level 在 map 下不变，经内部构造器 `%make-core-pvector-node2-packed` 原样拷）+ 映射后子节点重建；`(logand packed 63)=1` 判叶层，叶子层子即元素、施 proc。
- 语义红线：**proc 调用序保持左→右**（现实现如此、效应可观察）——prefix→middle（node 子从左）→suffix。
- 不动面：len≤4 捷径、values/void 恒等捷径、multi-map（adapter builder 路径）。
- 验收：bench ≤3ns/元素 @1k/100k（下界估计=读 1.5+proc/分配 ~1.3）；rktl 加"effectful proc 记录顺序"断言；`shape-stats` 前后一致（保形自检）；全套件零回归。

**S2 reverse 镜像穿刺**
- 实现：新 rumble 原语 `core-pvector-reverse`——镜像法：前/后缀 digit 组互换且各自内部反序（digit 1-4 元素的 pN 排列须先读源确认布局语义）、middle 递归且 node 子反序、packed 原样拷（测度对称）；inline 直接反序重建。adapter `pvector-reverse` 改路由（BC fallback 保留现 vector 路线）。
- 影响面：**#%kernel 新原语 → 版本 bump 9.3.7→9.3.8**（既定规则）。
- 验收：`(pvector->list (pvector-reverse pv))` ≡ `(reverse (pvector->list pv))` 于多形状（inline/深树/append 中间树/pop 碎形/单双元素）；bench ≤2.5ns/元素（无 proc 调用）；shape-stats 节点计数一致（镜像保数）；idempotence `(reverse (reverse pv))` 逐元素等。
- 顺带收益：E1 时代 `pvector-reverse` 的 adapter 入口检查保留，错误面不变。

**排序与预算**：同分支 `feat/pvector-structural-map` 两提交（S1→S2），各 1-2 构建周期；风险=保形递归代码量（镜 for-each 结构）与 digit 布局细节，均有既有 walker 作模板。若 S1 实测达标即证明手法，S2 照搬。

## 穿刺结果：S1/S2 双达标（2026-09-04，`feat/pvector-structural-map` 分支两提交，待 merge）

**S1 保形 map（`3fd43b6977`，REFACTOR）**：else 分支改结构保形递归（packed 字原样拷+子映射、digit 按 slot 映射、let* 显式串左→右调用序——Chez 实参求值序不定是必须绕开的雷）。**5.53→1.94ns/元素**（验收 ≤3；vs list 1.32，比值 0.22×→0.68×）。保形自检=shape-stats 逐形状全等；调用序断言；捷径全保留。

**S2 镜像 reverse（`6ae4f67b57`，FEAT，bump 9.3.8）**：新原语 `core-pvector-reverse`——节点自带测度使镜像平凡健全（packed 原样、子序反转、前后缀 digit 组互换+各自反序、middle 可空守卫）。**5.26→1.13ns/元素**（验收 ≤2.5；vs list 0.96 近持平，比值 0.17×→0.85×）。验证=10 形状等价/双反幂等/镜像保数（shape-stats 相等至前后缀转置——断言本身修正过一轮：镜像本就该转置该两键）/复合操作。adapter 保 vector 回退（BC）。

**面板修订**：map 与 reverse 从"list 稳定胜 4-5×"移入"近持平带"（0.68×/0.85×）——pvector 败域进一步收窄至 迭代/头插/弹头/逐元素构造（cons 极简固有）与内存 +50%。裁决不变（互补双雄），但胜负带明显东移。

## B 语言面 v1 落地（2026-09-05，`feat/pvector-language-face` 分支 `a60e2e67b5`，待 merge）

**B1 `pvector-lambda`/`define/pvector-rest`**：方案甲（纯库宏，骑 P4b 原生包装）。普通形零包装直达（object-name=pvector-rest-wrapper）；固定参形 `(x ... . pv)` 经 pvector-ref/drop 绑定 + `procedure-reduce-arity-mask`（显名 'pvector-lambda——匿名 reduce 结果 object-name=#f 会炸 arity-test 的报错正则，教训）。

**B2 可读字面量**：`#pvector(1 2 3)` 读写双向——reader 三形分发（元素形 `((elems) #f)` 兜底逃生门、raw 形收紧为"非空二元组定义表"并覆盖 `#:allow-forward-refs` 变体、其余列表=人类形归一化为元素形后走原内核入口，**零内核改动**）；write 从 raw 转储改为人类形（`write-pvector-literal` 保留结构输出，display/print 紧凑形不变）。expander 变更 → expander.scm + BC startup.inc 双产物再生同提交。

**语义边界移动（有意）**：三条钉"畸形 raw 必报错"的旧 reader 测试改为按人类形读出（`#pvector(1 #f)` 等）；歧义逃生门=元素形可表达一切元素表。

**验证**：B-VERIFY 24 断言全过（宏全形态/arity/原生命中/三形读入/歧义角/往返含千元素/display 不变）；pvector.rktl 全过（含新 12 组）；rackunit 零失败。

**B 状态**：v1（甲+读写）完结;乙（schemify 识别）/丙（λ 级 rest-kind）留档按需;设计文档 `pvector-language-face-design.md`。

**B v1 补丁（amend → `6e88548539`）**：`define/pvector-rest` 定义的过程经 `procedure-rename` 携带自名（此前 object-name 报通用的 pvector-rest-wrapper，错误消息同病；+0.5ns/调用，仅 define 形态付费）。全套件复验绿。

## 收台（2026-09-05）：穿刺与语言面均入主线

merge `9130ecf7b7`（structural-map）+ `b765e9e013`（language-face，pvector.rktl 尾部双追加节手工解冲突：补回被 git 共同后缀吸走的 `) ; end let`）。组合树独立构建全验：rktl×2 全过、rackunit×2 零失败、跨特性冒烟（字面量→保形 map→镜像 reverse→宏→write 往返，9.3.8）通过。主线自 origin 累计 13 个 first-parent 提交。工程全景：P1-P5 ☑ 修复清扫 ☑ 穿刺 ☑ 语言面 v1 ☑。

# code-review 欠账修复工作包（2026-09-08，high 级评审 15 条 CONFIRMED，merge 前清账）

评审方法：10 finder 角度 → 35 原始候选 → 24 去重 → 逐条验证投票 → 补漏扫描。以下按修复顺序 S1（硬伤）→ S3（套件卫生）→ S2（语义偏差）。每条修复独立验证，S1/S3 必修，S2 逐条裁量后全修。

## S1 硬伤（数据损坏 / 构建失败）

- [x] **S1-1 fixnum 位宽守卫缺失**（统一公式 (fixnum-width)-7；pb/32 真机复验在册） `racket/src/cs/rumble/pvector.ss:48`：packed `(measure<<6)|level` 节点字与 `(- (fxsll 1 54) 1)` cap 假设 61 位 fixnum；32 位 CS（pb32/arm32/i3，fixnum 30 位）下 unsafe 编译静默变垃圾、safe 编译 boot 失败。同族 swisstable.ss:172 / patricia.ss:236 均有 `(fixnum-width)` 守卫，pvector 漏。**修法**：按同族写法加位宽分派（32 位用缩小的 cap/位段或禁用 packed 优化路径）。
- [x] **S1-2 prims.ss meta-cond 分组错误**（collector 通用遍历 arg-registers 实证后挪出） `racket/src/ChezScheme/s/prims.ss:57`：`asm-arg-reg-cnt < 3` 的 else 分支漏定义 `$pvector-args`/`$pvector-finisher`/`$set-pvector-finisher!`，而 rumble（pvector.ss:4321、rumble.sls:1090）无条件引用 → 32 位 x86 boot 失败。`$pvector-args` 根本不需要 3 个 staging 寄存器——**分组本身就错**，应挪到无条件区。
- [x] **S1-3 write 无 expanded 逃逸**（与 S2-4/S1-6 同笔修复） `racket/collects/racket/pvector.rkt:2723`：write 模式无条件产 `#pvector(elem ...)`，元素序列撞 expanded/raw 读形时读回**静默变值**（`(pvector '(1 2) #f)` 读回成 `(pvector 1 2)`）或报错。文档（pvectors.scrbl:707-710）明言 `((elem ...) #f)` 形是逃逸——打印器从未使用。**修法**：打印前判元素序列是否与 expanded/raw 形碰撞，碰撞则改用 expanded 逃逸形输出。
- [x] **S1-4 raw-defs-shape? 拒空表回归**（e72a355fc2） `racket/src/expander/read/pvector-literal.rkt:45`：写端 raw 模式对空 pvector 仍产 `#pvector(Empty ())`，新谓词要求非空 defs → 该形读回成含 `'Empty` `'()` 的二元素 pvector（静默损坏）；`literal-datum->pvector` 与 reader 对同一 datum 判定不一致。**修法**：raw-defs-shape? 允许空 defs 列表（恢复 `(root ())` 形）。
- [x] **S1-5 cons/insert 不查 cap**（direct+known-length 双层守；第一版只守 known-length 被边界实测抓漏） `racket/src/cs/rumble/pvector.ss:3535/3555/3871`：cap 只在 make 与 append 查；共享翻倍 53 次逼近 2^54-1 后 cons-right 数次即溢出 packed 字（unsafe 下静默损坏）。**修法**：三处增长入口补 cap 检查，报既有的 exceeds-maximum 错。

- [x] **S1-6（新发现，review 15 条之外）raw 解析端 same-level 校验拒绝合法 append 树**：运行时 link2/link3 本以 max(child levels)+1 合成异 level 子节点（append 依赖），解析端却要求子节点同 level 且用首子推导父 level → write-pvector-literal **默认 raw 模式**对几乎所有 append 过的 pvector 产不可读输出（double×5/len=64 即触发）。修复=解析端改用运行时 link 构造器重建（保留 arity/size 校验）。发现路径：S2-4 回退验证时读回炸出。

## S3 套件卫生

- [x] **S3-1 place 测试无守卫** `pkgs/racket-test-core/tests/racket/pvector.rktl:1322`：place-channel 测试块随 all.rktl 在所有 VM 跑；BC 无 pvector place 支持、places-disabled 直接 raise。仓库惯例=place 测试住 place.rktl（带 place-enabled?/vm 守卫）。**修法**：块加 `(system-type 'vm)`='chez-scheme 且 place-enabled? 守卫（或迁 place.rktl）。`pkgs/racket-test/tests/racket/place-pvector.rkt` 同罪同修。
- [x] **S3-2 BC 打印断言错** `pkgs/racket-test/tests/racket/pvector.rkt:1397`：分支谓词从 bc-native-public-pvector? 改成了裸 raw:pvector? 别名 → BC-native 配置误入 CS 断言（期望 `#pvector(...)`，BC 实产 `#<pvector:3>`）；~2117 行 place check-true 同病。**修法**：恢复按 VM 区分的谓词与期望。
- [x] **S3-3 测试块在 report-errs 后** `pkgs/racket-test-core/tests/racket/vector.rktl:640`：新 vector-apply 非宿主过程测试块在 `(report-errs)` 之后，失败不计入汇总。**修法**：块移到 638 行 report-errs 前。

**S3 备注（已结）**：那个"既有失败"实为 **S1-5 引入的回归**（growth check 在校验前取未验参数的 length，who 被 pvector-length 抢报）——当时 A/B 只 stash 测试文件、二进制仍带 S1-5，误判为历史欠账。已修（check 移到 core-check-end-index 后），rackunit 归零。**教训：基线 A/B 必须连构建产物一起回退，只回退测试=测同一个被测物。**

## S2 语义偏差

- [x] **S2-1 pvector-map 单参洞** `racket/collects/racket/private/pvector-runtime-adapter.rkt:963` + `racket/collects/racket/pvector.rkt:1076`（两份同病）：`[(pv1 . rest)]` 变参 clause 吞掉单参调用 → 内部 cdr 错 + arity 假报含 1。**修法**：变参 clause 头改 `[(pv1 pv2 . rest)]` 级（保证 ≥2 才入）。
- [x] **S2-2 pvector-member 参数序** `adapter:667`：等价谓词调用序 `(is-equal? element target)` 反于 vector-member/member 的 `(cmp target element)`。**修法**：翻转为 `(is-equal? target element)`，与文档"vector-member 类比"一致。
- [x] **S2-3 partition 谓词双跑** `adapter:631`：两次 filter 实现使谓词每元素跑两遍，有状态谓词下元素可两边都在/都不在。**修法**：单遍 builder 双路输出。
- [x] **S2-4 write Θ(length) 挂死**（65536 阈值回退 raw；2^51 案 1.0ms 往返） `racket/collects/racket/pvector.rkt:2725`：平铺逐元素打印使共享结构（自 append 50 次=2^51 长）写不完；旧池化结构写器 Θ(structure)。**修法**：write human 形保留但对超长/高共享结构回退 raw 池化形（与 S1-3 逃逸判定合并设计）。
- [x] **S2-5 reader-graph 占位符**（kernel 原语三件套+三段链；环/共享全解析） `racket/src/expander/read/pvector-literal.rkt:86`：`#N#` 引用在 pvector 字面量内烙进占位符对象（make-reader-graph 不遍历 pvector）。**修法**：仿 #hash 的 make-hash-placeholder 路径加 pvector 占位符感知（或 read 期检测占位符转 delay 构造）。
- [x] **S2-6 BC fallback 无契约** `adapter:590`：pvector-fold-left/apply 的 BC fallback 臂不校验参数 → 错误 who/契约文本。**修法**：fallback 臂补 pvector?/procedure? 前置检查。
- [x] **S2-7 builder 续延重入** `adapter:308`：with-core-pvector-builder 的可变状态被用户回调中捕获的续延重入后产垃圾第二结果（内存安全，数据错误）。**修法**：完成时置 builder 失效标志，重入即报错（对齐 hash 迭代器惯例）。

## 验收纪律
每条：修复 → 针对性新测试（红→绿）→ 全套件回归 → 独立提交（格式照旧）。S1-1/S1-2 完成后 32 位验证按 pb/32 四层法（强制窄 fixnum + pb 构建）。

## 工作包收官（2026-09-08）：16/16 全清
六笔提交：e72a355fc2(S1-4) / 172c8057b6(S1-3+S2-4+S1-6) / c851e634a3(S1-1/2/5) / 14b040ffb7(S3×3) / 2a9304233d(S2×5+S1-5回归自纠) / 本笔(S2-5)。版本 9.3.9。
**沉淀的程序性知识**：①新增 #%kernel 原语三件套=rumble 导出+primitive/kernel.ss 表+bump Z，**且 expander 引用新原语时构建链必须 base→(setup -D)→derived→base**（expander 禁 dynamic-require，flatten 自足检查；宿主先拿到原语才能编 expander）②基线 A/B 必须连构建产物回退③每段 make base 后 derived 前须 -l- setup -D（info-cache 第 6/7 次）。

## pb/32 复验裁决(A):32位真机验证通过(2026-09-08,队友会话,tpb32l)
真 tpb32l 内核(i386容器qemu+mac bootquick)加载 HEAD 真 rumble pvector 核心实测:cap=8388607(2^23-1)、packed peak 恰=greatest-fixnum(紧致无溢出)、**旧公式静默垃圾实证**((- (fxsll 1 54) 1)=4194303,32位机器字移位mod 32回绕)、行为全过(cons/自倍/cap三入口/near-cap深引用)、level饱和修复32位同样生效、反向对照有判别力(旧公式连加载都炸)。**S1-1 pb/32复验正式闭环**。
**附带独立缺口(记账)**:①rktcrypto 六C文件(ecc/p256/p521/x448/bn.h/legacy_ciphers)无条件用__int128,i686不支持无32位回退→完整32位racket无法组装(rktcrypto 32位可移植欠账);②vfasl.c计时代码缺stdint.h(uint64_t间接可得于本机,已补一行提交)。
