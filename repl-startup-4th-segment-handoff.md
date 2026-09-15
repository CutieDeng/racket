# 第四 boot 段（REPL 预实例化）——开发交接书

> 面向新 agent 的自足文档。2026-09-14 定稿。
> 详细流水账在 `repl-startup-kernel-enhancement-plan.md`（按日期追加，本文档是其收敛快照）。
> memory 索引：`racket-repl-startup-project.md`。

---

## 1. 需求本源

**目标**：racket REPL 的 time-to-prompt 从当前 ~256ms（racket/init + xrepl，real-tty 实测）降到 ~80-100ms。

**手段（用户 2026-09-07 定向"治本"）**：不在 runtime 启动时重新实例化语言层（产生大量对象、触发 GC），而是把 racket/init + xrepl 实例化后的**namespace 状态整体序列化为"第四个 boot 段"**，启动时直接反序列化恢复。前三段=petite/scheme/racket .boot；第四段=本工程产物。

**约束**：
- 只有全绿工作可合主线（用户多次重申）。
- 实验全部在 scratchpad 进行，主线当前仅两处 env 门控 C 改动（默认零行为差，见 §4.3）。
- 汇报用直白技术语言，结论分"已验证/推断/未知"三档。

---

## 2. 架构总图

### 2.1 A/B 双进程实验协议

```
A 进程 (P33_ROLE=A)                      B 进程 (P33_ROLE=B)
racket -q -n 启动                        racket -q -n 启动（byte-identical 至 mark 点）
  ↓ mark 点：kernel attach + 8 根        ↓ mark 点：同构
  ↓ [dw-walk 命名 / p2 快照 / n3 loc 扫描]  ↓ [同一套 walk（确定序）→ 本地命名表]
  ↓ current-load 拦截（zo 事件记录）      ↓ zo 事件重放（fasl decode，不实例化）
  ↓ namespace-require racket/init        ↓ manifest 读取 + externals 解析
  ↓ xrepl 步（P33_XREPL=none/require-only/full）
  ↓ 预热（完整验收工作负载 20 项）★       ↓ state.fasl 读取（externals 已填）
  ↓ GC×2                                 ↓ h1-h7 重建钩子 + patch 重放
  ↓ 段生成（fasl write + manifest）       ↓ 验收（8 核心 + x1-x3 xrepl 层 + 扩展诊断）
```

★ 预热必须在 write **之前**（历史第一大坑：曾在 write 后跑，导致惰性 syntax 在 B 端补反序列化、铸出第二套 scope 世界）。

### 2.2 产物四件套（scratchpad/p3/）

| 文件 | 内容 |
|---|---|
| `seg4z-state.fasl` | 主段：ns 图 + patch + tags + aux(eqvht) + rtdprops + codes-delta（root 向量 6 槽） |
| `seg4z-externals.manifest` | 外置对象命名表（per-tag：zo/loc/rmp/kw/rtd/prefab/bdw/cpb/iscope/dwseq/staddr/eqvht/zoloc/zomiss） |
| `seg4z-zolist.fasl` | zo 事件清单（路径+计数），B 重放用 |
| `seg4z-patch.rktd` | 文本摘要（真 patch 在 state.fasl 内） |

### 2.3 外置命名通道一览（A 规则链序=添加序）

| 通道 | 语义名 | 覆盖 | B 解析 |
|---|---|---|---|
| code（隐式最优先） | — | 所有 code | 经 zo/bdw/cpb/zoloc |
| kw | keyword 字符串 | keyword rec | string->keyword |
| rmp | 路径/符号 spec | resolved-module-path | make-resolved-module-path（intern） |
| rtd | nongenerative uid | **boot 世界** rtd（mark ∨ static-gen；init 新 rtd 必须 in-graph！） | uid gensym 重 intern + `$sgetprop '*rtd*` |
| prefab-rtd | (key . count) | prefab | prefab-key->struct-type |
| staddr（P33_LIBID 门控） | (delta . tag) | static-gen 非 code/rtd/ht | `((anchor+delta)<<3)\|tag` → `$address->object` |
| dwseq（P33_LIBID 门控） | walk 序号 | dw 域非 mark 对象 | dw-seq-obj 表 |
| iscope | (rtd名 . id/(phase.msid)) | 顶层 scope 三件套等 18 个 boot 单例 | mark 期登记表 |
| pre-boot-marked → loc | n3 边路径 | 其余 mark 域对象 | n3-resolve 从 8 根走边 |
| eqvht（aux） | — | eq-hashtable（fasl 不可写） | kvvec 重建（天然 rehash） |
| zoclo（2026-09-15） | code 的 (evt . seq) | 0-fv 闭包（非 mark 域、code 有 zo 名、A 上==reloc 自字面量） | zo-b-lookup → reloc 0-fv 自字面量（规范闭包） |

### 2.4 B 端重建钩子

- h1 registry lock-box 复位；h2 module-cache-clear!（env P33_SKIP_H2 可跳）；h3 links-cache 不动；h4 thread-cell 播种；h5 custodian 类跳过；h6 rtd uid plist 恢复（putprop）；**h7 eq-hash-code 登记同步**（普适级发现，见 §5.3）。

---

## 3. 当前状态矩阵（2026-09-15 晚更新）

| 线 | 配置 | 验收 | 稳定性 | 段体积 |
|---|---|---|---|---|
| **green-none（推荐线）** | env 全不设 + `P33_PREHEAT=none` | 核心 11/11 VERDICT(A) + **扩展 12/12 fail=0** | **15/15 全净**（2026-09-15） | **5.078MB** |
| 配方线（降级为诊断线） | `RACKET_RETAIN_STATIC_RELOC=1` + `P33_LIBID=1` | 核心 11/11 + 扩展 12/12 fail=0 | 验收全绿但 **~21% 对在诊断走查段 B invalid memory**（错位槽,流水账 D128-D131） | 9.26MB（workload 预热） |
| 绿基线（历史） | 默认（全部 env 不设,workload 预热） | 核心 11/11 + 扩展 10/12（zoclo 前） | 4/4 | — |

- **D131 裁决**：zoclo 根除 class 族后 staddr/dwseq/retain 对验收面不再必要；A 预热（workload/定向 force）均可弃——零预热 15/15 满分且段 -45%。定向 force 机制（`P33_PREHEAT=force`,353 模块 0 err）实测使段**增大**到 9.44MB,方向证伪,保留为诊断装备。配方线的 ~21% 崩溃=段内解析错位槽（验收路径未踩,census 走查触发）,归因 retain/staddr 线（15 连净 P≈0.03 的统计证据;根因未最终定位）。

- 验收 11 项=8 核心（算术/map/sort/require 热+冷/sha1/contract 错误路径）+ x1-x3 xrepl 层（prompt-read 活/toplevel-prefix 可达/interaction-info 可达）。
- **2026-09-15 起配方线零功能残余**：class 族（原 §7.1）经 'zoclo 通道根除，扩展 12/12 首次满分。
- **计时**（P33_PROBES=0）：段恢复净 ~227ms，其中 zo 重放 164ms 是实验期命名装置（产品化用内核 closure-fasl 直带 code 后归零）；state.fasl 9.2MB 读取仅 ~9ms。**产品外推 boot 37 + 段读 ~10 + hooks/replay ~35 ≈ 80-100ms**，达标。
- A/B walk 指纹已验证 4/4 逐行 SAME（跨进程命名稳定性完全建立）。

---

## 4. 代码地图

### 4.1 scratchpad（实验主体，不进 git）

根：`/private/tmp/claude-501/-Users-cutiedeng-Y2026-M07-D16-racket-feat-swisstable/d5d1ca89-29ba-48e9-9226-2d4a258a56cd/scratchpad/`
（注意：scratchpad 是 session 绑定的；新 agent 若 scratchpad 已失效，需从本文档+流水账重建，核心文件建议先拷贝入库或新 scratchpad。）

| 文件 | 职责 |
|---|---|
| `p3/p3.3-run.rkt` | runner（'#%kernel 模块，A/B byte-identical）：boot 引擎装载、mark 点、racket 桥（safe-eval/ns-census/probe-layers/sdi/hash-keys 等）、**A 预热块**、驱动调用 |
| `p3/p3.3a.chez.ss` | A 驱动：mark 扫描、外置规则链、fasl write 循环、manifest 构建、控制探针 |
| `p3/p3.3b.chez.ss` | B 驱动：walk/命名表、manifest 解析、fasl read、h1-h7、patch 重放、验收、诊断探针群 |
| `p3/p3.naming.ss` | 命名引擎共享层：dw-walk!（+kernel-prims 扩根/rtd-plist 增量/reloc 穿透闸门）、n3 loc 命名、staddr/dwseq/iscope 机制、指纹 dump、codes 表定位 |
| `p3/p3.2-boot.chez.ss` `p3.2-head.chez.ss` | 干净 Chez 环境引导 + 基元捕获 |
| `p1.engine.ss` `p2.writeset.ss` | fasl 外置机制（规则链/attempt-write）+ 快照/diff/patch |
| `p3/p3-mandiff.rkt/.chez.ss` | 清单结构对比器（bit 差→条目差翻译） |
| `p3/run6.sh` `run-cls2.sh` `run-3way.sh` | 批跑脚本（tmux 长命令必须走脚本文件，见 §8） |

### 4.2 主线树已改（未提交，默认零行为差）

worktree：`/Users/cutiedeng/Y2026/M08/D24/racket-feat-native-pvector/`（分支 feat/native-pvector 之上）

1. `racket/src/cs/c/boot.c`：`racket_boot` 中 `Sscheme_init` 后，`RACKET_RETAIN_STATIC_RELOC=1` 时调 `Sretain_static_relocation()`。
2. `racket/src/ChezScheme/c/prim5.c`：`s_get_reloc` 对 static-gen code 的无条件拒绝松绑为"仅未 retain 时拒"。

需 `make base`（2-3 分钟）重建生效。提交时机随产品化批次，由用户裁决。

### 4.3 env 开关速查

| 变量 | 作用 |
|---|---|
| `P33_ROLE=A/B` | 角色 |
| `P33_XREPL=none/require-only/full` | xrepl 层级 |
| `P33_PREHEAT=workload/force/both/none` | A 预热策略（默认 workload=20 项工作负载；none=零预热=**推荐线**；force=定向 force 全 registry，诊断用，段更大） |
| `RACKET_RETAIN_STATIC_RELOC=1` | C 层保留 static reloc（配方线） |
| `P33_LIBID=1` | 开 staddr/dwseq 通道（配方线） |
| `P33_PROBES=0` | 计时模式（关验收/探针） |
| `P33_LPROBES=0` | 关层探针（ns-census/identifier-binding/sdi） |
| `P33_DWFP=1` | dump walk 指纹（/tmp/dwfp-{A,B}.txt + kp 名单） |
| `P33_STX=1` | stxparam 微实验 |
| `P33_CLS2=1` | minst hunter |
| `P33_SDI/SDI2/TL/REBIND/DUPTRACE/H6_RANGE/DH_TRACE` | 各诊断探针（见流水账） |

### 4.4 验证命令模板

```sh
SP=<scratchpad>; RK=<worktree>/racket/bin/racket
cd $SP/p3
# 推荐线（green-none）一对：
P33_PREHEAT=none P33_XREPL=full P33_ROLE=A $RK -q -n -t p3.3-run.rkt
P33_PREHEAT=none P33_XREPL=full P33_ROLE=B $RK -q -n -t p3.3-run.rkt
grep -a 'SUMMARY\|VERDICT\|extended' $SP/p3/p3.3b.log
# 多对稳定性：bash run-greennone12.sh；诊断线（旧配方线）：run6.sh / run-preheat-matrix.sh
# （勿在 tmux 打长单行；runner 任何改动只能整对验证——B-only 冒烟对 runner 改动无效）
```

---

## 5. 三大根因与修复（全链已实证，新 agent 勿重走）

### 5.1 A 预热（惰性 syntax 世界统一）
旧流程控制探针在 fasl write **之后**跑 → 段带未 force 的 `deserialized-syntax-vector` box(#f) → B 验收首次 force → B 铸 scope → 混合 scope 世界（dup scope 557-641，#%app unbound 全家桶）。修复=runner A 角色在 write 前跑 20 项工作负载。dup→0。

### 5.2 D1 移除 + 顶层绑定落地
patch op（rep-scope 11/2 的 f2 槽写）曾被"深合并"分支拦截（按 Chez 表假设合并 racket 不可变哈希=无效）。改普通覆盖后 racket/init 的 1404 条顶层绑定落进 B。单世系下覆盖语义正确。

### 5.3 h7 eq-hash-code 登记同步（普适级）
CS `eq-hash-code` = rumble `codes` 弱表按首问序分配的**进程本地序号**（counter 起 12345）；racket hasheq HAMT 按此序号组织 → fasl 迁移后 **枚举可见、hash 走位全盲**（census 2903↔1499、sdi 列出绑定但 match #f、解析失败落顶层变量回退——全部矛盾的统一解）。修复=codes 表经 collect-request-handler 闭包 BFS 定位（库内变量），A mark 快照 → write 时 delta（~6223 对）入 root 槽 5 → B install-if-absent（0 冲突）。counter 不同步（hash 碰撞可容忍）。
**任何跨进程 fasl racket hasheq 的场景都需要这个机制。**

### 5.4 配方线三支柱（retain 线）
1. **reloc 闸门**：retain 下 GC 不更新 static reloc 表（gc.c 无消费点）→ attach 后走图读悬垂条目即崩。`dw-reloc-ok` 全局闸，仅 mark 相（dw-walk/cpb 前）开。
2. **rtd boot 世界约束**：'rtd 通道曾扩过头，init 新 rtd（B 无 uid 注册）被外置 → fasl rtd 位空洞 → 抽签崩。约束=(mark ∨ static-gen)。
3. **mutable-hash 桶跳过**：racket 可变 hash 的内部桶链按**插入序（进程本地）**组织；dw-kids 的 record 字段遍历曾把它暴露进命名 → walk 序抽签。特判 eq-mutable-hash/mutable-hash/weak-mutable-hash 只下潜 Chez ht 字段。修后指纹 4/4 SAME。

### 5.5 行为契约（不可违反）
- **pre-eval scope census 是配方线必要预热**：gate 掉它 → 确定性 map 死循环（走图 force 副作用被依赖，与 SDI 探针"治疗性副作用"同族）。保留。
- attach 窗口（fasl-read→replay→验收前）禁全堆 walk（GC 扰动实测）。
- 诊断一律 try 化，不许杀进程（forensics 教训）。

---

## 6. 已证死路（勿再试）

| 假说/路线 | 证伪方式 |
|---|---|
| core scope=interned-scope 按 key intern | B 堆 walk：mark 域 interned-scope 计数 0 |
| 负 id scope 双份=失败根因 | dup=0 后失败依旧；跨模块 id 碰撞 eq 匹配下无害 |
| D1 深合并（Chez 表假设） | syms 实为 racket 不可变哈希，no-op |
| rtdprops 全域宽判据 | 4500 值上车带死库 cell → invalid memory |
| 白名单救援（逐 rtd） | 打地鼠（date 修好、match/contract 新坏） |
| dwseq 覆盖 POST-mark prop 值自由变量 | walk 域不含 → 仅命中 2 |
| tie-drop 进 n3-kids | 丢 4 个 thread-cell loc 名 → 参数化断裂 0/8 |
| reloc 穿透常开 | 晚期悬垂崩（d72-d85 全体） |
| kernel-prims 名单/序漂移 | kp dump 两侧 1410 项逐行同 |

---

## 7. 未解问题栈（按优先序，新 agent 从这里接）

### 7.1 ✅ stxparam mark-key 断裂——已根除（2026-09-15，'zoclo 通道）
- **根因（普适级）**：**0-fv 闭包身份分裂**。zo 装载进程上，模块 cell 里的 0-fv 闭包与其 code reloc 自字面量是同一对象；段旅行后 B 上分裂为两个（zo 重放新造字面量 vs 段图带来的 A cell 闭包）。cpe 函数体内 mark key 编译为 reloc 字面量引用，racket 层变量引用全走 cell 版 → eq 失配 → mark 永远读不到 → super-new "not in a class"。
- **修复='zoclo 通道**：A 端 0-fv ∧ 非 mark 域 ∧ code 有 zo 名 ∧ A 上闭包==自身 reloc 字面量 → 外置 (evt . seq)；B 端 zo-b-lookup → `p33-zoclo-literal`（reloc 0-fv 自字面量）为规范闭包。命中 3 条全 ok；消融证明单此一项即愈（'#%unsafe 扩根尝试无效已撤）。
- **判定探针链留档**：peek-env 差分/probe2 自洽/probe3-5 层清白/probe7-8 交叉读写/probe10 reloc 转储/probe11 eq+行为终审（b 驱动 P33_STX=1 gated，永久装备）。详见流水账 2026-09-15。
- **产品化警示**：任何跨进程 fasl 场景，凡以闭包对象本体为 eq key 的机制都受此制约；zoclo 判据（A 侧 cell==literal 才外置）是语义保真的关键。

### 7.2 段裁剪（9.2MB → 数百 KB~2MB）
1. ✅ **预热裁除（2026-09-15，D128-D131，实测反转原设想）**：原计划"定向 force 替代工作负载预热"已实现（`P33_PREHEAT=force`，`p33-syntax-force-plan` 索引式枚举 registry+module f12 force-bulk-binding，353 模块 0 err）但**证伪**——全量 force 使段涨到 9.44MB。真解=**零预热**（`P33_PREHEAT=none`）：5.078MB（-45%），15/15 全净满分（见 §3 green-none 线）。"A 预热必要"（§5.1）已不复现，机制**未理解**（候选=D1 覆盖+h7+现通道集使 B 端惰性 force 自洽），列为待研。
2. ❌ fasl 图裁枝（rtdprops/zo 清单按需化）——**2026-09-15 边际剖析证伪**（D132）：五槽独占合计仅 ~417KB，**~4.66MB（92%）是多槽共享核心图**（ns/expander 世界），容器按需化省不动。剖析装备=A 驱动 `P33_SEGPROF=1`（solo 写测"可达量"无效，须边际法：逐槽剔除重写取差）。
3. 核心段/扩展分层（=动核心图，唯一真字节杠杆）。**降级缓做**：段字节不在 time-to-prompt 关键路径（fasl-read 14ms@5.08MB），只关 RSS/分发；green-none 计时外推 boot 37+read/install ~34+replay/hooks ~25 ≈ 96ms，目标已在线上成立，优先做 §7.3（首项 code 通道原生化，消 97ms zo 重放实验伪影）。

### 7.3 产品化清单
- build.zuo 四段构建、embed-boot.rkt、boot.c（retain-reloc 钩子转正）、main.sps 条件装载。
- zo 重放→内核 closure-fasl 原生 code（fasl-type-closure-freevars=47 已在主线），164ms 归零的关键。
- zomiss 10（#f|128 匿名 code）→0。
- 两处 C 改动提交（用户裁决时机）。
- xrepl-lib 惰性化三改动（readline 双惰性化）已在安装拷贝 `racket/share/pkgs/xrepl-lib/xrepl/xrepl.rkt`，待 vendoring。

---

## 8. 纪律红线（血泪集，全部实测过）

1. **编辑与运行必须物理分离或全链 &&**：python assert 失败后 tmux 命令照跑旧文件=假实验（犯 4 次）。
2. **陈日志假象**：驱动崩在 p32-load 期时 log 文件不被 replace，读到上一轮内容。A/B 退出码必须分别打标。
3. tmux 多命令一律脚本文件（长单行折行/粘连失效）；macOS 无 timeout 命令；C-c 前确认目标进程。
4. '#%kernel 模块无 `let`/`and`/`for`/`foldl`；Chez let 体 define 不得被表达式打断；engine `try` 的 fallback 按值急求值（只放纯值）。
5. scope 族对象禁整体 display（循环结构，曾产 30GB log）；打印一律 trunc。
6. p32-env 无 `#%$fxaddress` 等，用 `($primitive $fxaddress)` 显式形式；racket reader 拒 `#3%`。
7. Chez 纯空间记录禁原位写（sweep_dirty 崩），需 `#%$record` 造新记录写入可变槽。
8. 深嵌套区改动用整块重写，不用手术补丁（括号平衡自检：strip 字符串/注释后计数）。
9. 恢复/回滚精确到文件（全局 git checkout 禁）。

---

## 9. ⚠️ scratchpad 灾难与恢复（2026-09-14）

原 scratchpad（/private/tmp 下，session 绑定）被系统清理，6 个基础层文件失踪。已完成抢救：

- **库内权威拷贝：`experiments/seg4/`**（本 worktree）——新 agent 以此为准。
- 恢复来源：13 个主文件为幸存拷贝（含全部三大修复）；p1.engine.ss/p2.writeset.ss/p3.2-boot/p1.head.ss/p3.2-gen.py/enum/table 从 session transcript 的 Write 记录提取；p3.2-head.chez.ss 用 p3.2-gen.py 派生逻辑从 p1.head.ss 重建；engine 缺失增量（trunc/fmt-val/children-labeled/find-leak-paths）以 `p1.engine-suppl.ss` 补齐（runner 载入链已插入 suppl）；mark-ht 定义补进 writeset。
- **✅ 校准完成（2026-09-14 深夜）**：缺口根因=抢救只取各文件**最早 Write 全文**、丢后续 Edit 链。链式重放 21 条增量 + 3 处手工修复（p3.2-boot quote / engine-suppl 尾残片 / table cpb 三件套）后，配方线 **6/6 全绿（核心 11/11 + 扩展 11/12）**，与灾前状态完全一致；唯一残余仍=class 族（§7.1）。详见流水账 2026-09-14 条目。`experiments/seg4/` 现为**已验证**权威拷贝。
- 使用方式：把 `experiments/seg4/{p1.*,p2.*}` 与 `experiments/seg4/p3/*` 拷入任意目录并把 runner 中 SP 常量指向其父目录（或按原路径重建 scratchpad）。
- transcript 抢救方法论（可复用）：`.claude/projects/<dir>/<session>.jsonl` 与 `<session>/subagents/*.jsonl` 中 Write tool_use 含全文；sed/cat 的 tool_result 可拼段；生成器脚本（如 p3.2-gen.py）优先找。

## 10. 关键常量/事实速查

- rootvec 8 根：ns/thread/custodian/logger/plumber/inspector/code-inspector/security-guard。
- namespace 字段：f2=root-expand-ctx(box)、f7=module-registry、f9=bulk-binding-registry、f16=module-instances（0-phase→rmp→instance / union）。
- scope=(id kind binding-table)；表在 f2；顶层绑定挂 rep-scope 11/2；`empty-binding-table=#hasheq()`；twbb=(syms syms/serialize bulk-bindings) 全 immutable。
- 顶层 require 绑定走 **bulk-bindings**（不进 syms）。
- static generation 判定：`($primitive $generation)` → 7。
- eq-hash-code：symbol/number/char 结构化，其余 codes 表序号（12345 起）。
- A 段"语义确定、字节不定"（eq-ht 迭代序/弱表 GC 时点/class-contract 弱缓存 ±7 code 摇摆集=已知良性）。
