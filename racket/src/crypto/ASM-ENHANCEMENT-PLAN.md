# rktcrypto 汇编层增强规划：可读性 · 维护性 · 性能

> 背景：rktcrypto 的 AArch64 内核（`asm/` + `rktcrypto_*_asm.S`/`rktcrypto_bn_*.S`）
> 在追平 OpenSSL 的冲刺中大量**转写/复刻 OpenSSL perlasm 的结构与调度**，
> 没有充分利用 asmp（现已入树更名 **rktasm**，`racket/src/rktasm`；原独立仓
> `/Users/cutiedeng/Y2026/M05/D29/asmp.git`，2026-08-06 并入）的语义化能力
> （命名虚拟寄存器只用了一半、`.function`/`.inline` 模板完全未用、调度器封存）。
> 本文按**可读性 / 维护性 / 使用性能**三维度规划增强，风格与
> [`OPENSSL-PARITY-PLAN.md`](./OPENSSL-PARITY-PLAN.md) 一致：现状基线前置、
> 分阶段、每项带**验收判据**。
>
> 性能红线（贯穿全文）：热点原语已实测**全面 ≥ OpenSSL 3.6.3**（2026-07-19 本机
> 头对头）。一切可读性/维护性重构必须过**双门禁**——bit-exact 差分 + cycle 持平
> （每内核 ±2%），绝不为语义化付性能税。
>
> **2026-08-05 增订**：新增「总纲：三层原则」；据此新增 Phase F（生成器 asmp 化，
> Python 退役）、扩充 Phase E（非 Apple aarch64）、明确 x86-64 为非目标（§3）。
>
> **2026-08-06 增订（Phase G，已完成）**：asmp **入树更名 rktasm**
> （`racket/src/rktasm`，与 rktio/crypto/random 平级；工作树快照导入，含
> M1/L1 与 gnu-writer 未提交改动，剔除 example*；`research/` 因被测试套件
> 引用而随迁）。接线：regen.sh `ASMP`→`RKTASM` 且默认树内相对定位、
> `gw.rkt` runtime-path 相对定位、语料测试路径树内化、provenance 头改标
> rktasm。验证：树内零配置全内核 check exit 0、gnu-writer 语料 13/13、
> 全量套件 0 失败。原独立仓 `/Users/cutiedeng/Y2026/M05/D29/asmp.git`
> 转为历史归档（入树前提交历史与旧 provenance 的 asmp commit 以其为准）。
> 决议（同日讨论）：**不**立"用 rktasm 重构 JIT/Chez 后端"项——CS 无传统
> JIT（Chez nanopass 按需 AOT 直出机器码），rktasm 与其生态位不同；
> 候选交汇点（arm64 编码器差分互证、手写汇编岛治理）留待未来评估。
>
> **2026-08-06 增订（Phase G 续：vendor/cutie-ftree 清零，已完成）**：
> rktasm 的 vendor 数据结构全部换 core 吸收版或就地吸收——
> ① pvector → `racket/pvector`（33 文件，API 10/10 覆盖）；
> ② bitset → `racket/intbits`（16 文件；两者表示同构=精确整数，纯名义映射；
> core 缺 `for/intbits` 推导式与变参构造器，暂由 `ds/intbits-compat.rkt`
> 薄壳补齐——**待办：core intbits 增补后壳退役**）；
> ③ ordered-map 分三路：整数键→`racket/intmap`；symbol/string 键经审计
> **有序性零价值**（遍历全落 for/set 或纯查找）→ 不可变 hasheq/hash；
> reg 结构体键（26 站点，序 load-bearing）→ **`ds/omap.rkt` 宏单态化模板**
> （`define-omap` 展开期把 key<? 注入递归体 → cp0 常规内联，无动态分派税；
> Adams WBT，迭代序=比较器序与实现无关；2 万随机差分 + `reg<?`≡
> `reg-id-compare` 对拍测试守护）；
> ④ graph+scc+算法 → 吸收为 `collects/racket/graph.rkt`（rktasm 经
> `ds/graph.rkt` 文件路径薄壳使用，brew 重打包后改集合 require）。
> comparator 模块随 ordered-map 退役。门禁：regen check **exit 0 且漂移
> 轮廓与迁移前逐行一致**（数据结构全换、`.S` 零字节变化）+ 全量套件。
> 长线候选（同日讨论沉淀）：cp0 "已知闭包实参的递归过程克隆特化"
> （SpecConstr 类）——宏单态化版可作其性能 oracle。
>
> **2026-08-07 增订（SpecConstr 证据基础，已测量）**：
> `rktasm/benchmark/omap-dispatch-bench.rkt` 在 CS/Chez 上量化分派税
> （三变体同 WBT：dyn=运行时闭包比较器过 struct 字段每节点未知调用、
> mono=racket/omap 宏单态化、intmap=radix 参考；比较器运行时选取防 cp0
> 内联污染，build/ref 分相计时）。**结论：分派税真实但温和**——纯查找
> （隔离分配）ref mono/dyn **1.18–1.22×**，混合 build+ref（现实函数式用法，
> 分配主导）**仅 1.05–1.06×**；ref intmap/mono 1.07–1.11×（整数键 radix
> 略优，已选 intmap）。**go/no-go 同 D1/D2 纪律：SpecConstr 是真但温和的
> 收益（上限 ~22% 且限于查找密集的泛型比较器 workload），非稳赚**；且
> rktasm 自身热路径（regalloc）已经是 mono/intmap 层，pass 惠及的是**其它**
> 泛型代码（sort 回调、泛型有序容器），不是 rktasm 热点。故仍列长线候选
> 非急项；此 benchmark 即"若立项则作性能 oracle"的那份对照。
>
> **2026-08-06 增订（comparator 协议规范与性能路线，讨论定稿）**：
> ① **协议规范**：新有序结构 API 一律以**三值比较器为根**（`'</'='/'>`，
> ds/omap.rkt `#:key-compare` 已示范），`<?` 谓词只作构造糖；存量
> `sort`/`<?` 面**永不改造**（排序类消费者结构上二路、三值零收益；
> fork 追 upstream 的合并税是决定性约束）。理据同 C++ `<=>`：加派生根、
> 保旧面、零破坏。比较链保持为**可融合表达式**（宏/描述符形态，叶子
> fx 三值），不过早物化为布尔。
> ② **性能路线（按一般优化技术，投入从小到大）**：kernel 叶子原语
> （`fx/string/symbol-compare` 单遍三值，rumble 吸收路线）→ 组合子
> 降数据描述符 + 全局 memo（每比较器一次特化，先例=regexp/contract
> 投影）→ 创建时偏应用特化（megamorphic→每实例单态间接调用）→
> cp0 已知闭包递归克隆（旗舰，泛型站点≡宏单态版）。
> ③ **ccmp/NZCV 融合已评估、搁置**：ARM64 三值天然映射 NZCV、字典序
> join 有原生 `ccmp`（k 字段=1 cmp+(k-1) ccmp 无分支无物化），且 `<?`
> 协议会在首字段破坏融合可能——协议设计已按此保留空间；但 **flags
> 不跨函数边界**（AAPCS64 不保序 NZCV），须先单态化才可达，且收益
> 尺度为每节点数周期、仅热循环可见 → 不单独立项，仅作 Chez arm64
> ISel 的备考记录（若未来立项，rktasm 的 NZCV 建模可写融合内核作
> oracle）。
>
> **2026-08-07 增订（Core 批次一，树侧已完成）**：
> ① `racket/intbits` 增补变参构造器 `(intbits pos ...)` 与
> `for/intbits`/`for*/intbits` 推导式（for/fold/derived 实现），
> `ds/intbits-compat.rkt` 本地定义退役、翻转为树内 collects 路径薄壳；
> ② `racket/omap` 进 core（`ds/omap.rkt` 平移，三值 `#:key-compare` 为根、
> `#:key<?` 作糖；`ds/omap.rkt` 翻转路径薄壳）；
> ③ 新建 **`racket/compare`** 协议模块：`comparison?` + 单遍三值叶子
> （fx/integer/real/char/string/symbol/bytes-compare，symbol 有 eq? 快路径）
> + 组合子（compare-on/reverse/lexico）+ 派生糖（compare->lt/->eq、
> lt->compare），叶子与派生器包 `begin-encourage-inline`（rumble/kernel
> 级吸收留作后续性能项）；
> ④ `racket/graph` 集合 require 在 in-place racket 验证可用。
> 测试：`racket-test-core/tests/racket/{compare,omap}.rktl` 新建、
> `intbits.rktl` 增补，全部 Passed，挂入 `all.rktl`。门禁：regen check
> exit 0、rktasm 套件 0 失败。**遗留**：三个 ds/ 路径薄壳
> （graph/omap/intbits-compat）待 brew racket 重打包后统一退役为集合
> require。

---

## 总纲（2026-08-05）：asmp 单一元编程基底 · 三层原则

由「整个 librktcrypto 使用 asmp 能力、移除所有 C 与 Python 元编程」的目标
讨论重述而来。原始诉求的字面形式与本库两条既有底线冲突——①验证方法论以
**可移植 C 为差分 oracle**（全 asm 化后只能拿同一工具链的产物互证，asmp
自身的共模故障不可检出）；②非 Apple/aarch64 平台的全部功能覆盖依赖 C。
故重述为：

**asmp 是唯一的元编程与汇编基底；C 收缩为两个明确角色——语义 oracle 与
可移植兜底。二者是验证与覆盖的基础设施，不可移除。**

- **第一层（生成器 asmp 化，做）**：全部 `gen_*.py` 替换为 `require` asmp 的
  Racket 发射模块，Python 退出仓库。发射器从「打印 .asm 文本」升级为「构造
  asmp 指令结构」——寄存器类别/操作数形状在发射点即检查，并可查询 asmp 的
  延迟/端口模型做参数搜索（交错因子、展开深度）。→ **Phase F**（吸收 A4）。
- **第二层（真源全覆盖，做）**：唯一无 asmp 源的 `bn_sqr.S` 待 asmp **M3
  （`.frame`：帧指针 + 变长 alloca）** 落地后收编（评估结论见 A5），达成
  「每个 .S 都有 asmp 真源」。→ A5 延续，前置在 asmp 仓。
- **第三层（热核扩圈，选择性做）**：按 profile 证据扩大 asmp 内核覆盖——
  候选：ML-KEM/ML-DSA **NTT**（现全标量）、ML-DSA 矩阵展开的 Keccak 批处理、
  poly1305/blake3/x25519 等纯 C 热点（并入 D3 评估）。**不变式：每新增一个
  asmp 内核，同步落一个独立 C oracle 差分 harness**（≥200k 随机+边界 + ABI
  guard），秘密路径加 dudect。
- **明确不做**：移除可移植 C；用汇编重写控制流重的解析/协议/胶水层
  （DER/X.509、RSA 填充、KDF、TLS key schedule 等维持 C——无性能收益，
  且失去边界审计与 sanitizer 工具链）。C 的定性从「待清理的历史层」改为
  「验证基础设施 + 平台覆盖」，原则内部不再有张力。
- **平台路线**：非 Apple aarch64（ELF）为近期目标（Phase E）；**x86-64 asmp
  后端暂非目标**——x86 由可移植 C + 既有 intrinsics 兜底（重议条件见 §3）。
  C intrinsics 热点（chacha20/gcm/aes/sha 系）依 Q2 结论继续不纳入 asmp 管辖。

---

## 0. 现状基线（动手前必读）

### 0.1 内核清单与真源状态

9 个 `.S` 全部 `#if defined(__aarch64__) && defined(__APPLE__)` guard，
`build.zuo:65-87` 直接编译；asmp 仅开发期依赖（`asm/README.md`）。

| .S | asmp 源 | 生成器 | 真源状态 |
|---|---|---|---|
| `bn_op.S` (op16 CIOS) | `mont_mul_op16.asm` | `gen_opscan.py` | ✅ 完整链 |
| `bn_fips.S` (fips16/32) | **无** | `gen_fips.py` **直出裸 GNU，绕过 asmp** | ⚠️ 异类管线 |
| `bn_sqr.S` (sqrx8x 布局) | **无** | **无（纯手写，OpenSSL 派生）** | ❌ 孤儿 |
| `ecc_asm.S` (mul_plain6/9) | `mul_plain6/9.asm` | `gen_mulplain.py` | ✅ 完整链 |
| `keccak_asm.S` (5 个 rate) | `keccak_absorb.asm` | `gen_keccak_absorb.py` | ✅ 完整链 |
| `keccak_f2_asm.S` | `keccak_f2.asm` | `gen_keccak_f2.py` | ✅ 完整链 |
| `md5_asm.S` | `md5_blocks.asm` | `gen_md5.py` **转写 OpenSSL md5-aarch64.pl 的产物 .s（未提交）** | ⚠️ 上游断链 |
| `p256_asm.S` (5 导出+6 helper) | `mont_mul*.asm`/`mont_sqrn*.asm` | 前二有生成器；`mont_sqrn*` 手工改编 | ⚠️ `jac_double_hw`+6 个 `_p256_*` helper **无 .asm**（ecp_nistz256 直接转写） |
| `sha1_asm.S` | **`.asm` 未提交** | `gen_sha1.py`（转写 sha1-armv8.pl 调度） | ❌ 产物无法溯源到已提交源 |

### 0.2 语义化现状：两个极端

- **原创内核**（`mont_mul_p256.asm` 等）：命名虚拟寄存器语义化良好
  （`x.a0/x.acc0/x.bi/x.t0`），但**零注释、无结构抽象**——P-256 Solinas 约简
  9 指令模式在 4 轮里平铺重复，读者须自行逆向出"这是同一个约简"。
- **转写内核**（`md5_blocks.asm`）：虚拟寄存器名**照抄 OpenSSL 物理寄存器编号**
  （`x.r10/w.r17`——语义化机制形同虚设），64 步全平铺，注释是转写噪音
  （"Begin aux function round 1…" 重复 64 次）而非不变量。
- **产物 `.S`**：asmp 输出丢弃源注释——`md5_asm.S:26` 只剩 `movz x3, #42104`
  （0xd76aa478 的语义消失）；分配后全是无名物理寄存器。

### 0.3 asmp 已有但未被 rktcrypto 使用的能力（调研结论）

| 能力 | 出处 | rktcrypto 使用情况 |
|---|---|---|
| `.function` 带 `in:/out:/inout:` 签名 + `.inline fn (formal=actual)` 模板展开（局部临时自动重命名） | `docs/gnu-frontend-syntax.md:136-169` | **完全未用**——所有 .asm 是单函数平铺 |
| 托管 `.call`（自动入/出参 move、parallel-copy 破环） | 同上 `:172-200` | 未用（`jac_double_hw` 用裸 `bl` + 手工寄存器契约） |
| 周期感知列表调度器（延迟+**Apple-M 端口模型**，AES/PMULL 共端口、NZCV 依赖、内存消歧） | `pipeline/schedule.rkt` | **默认封存**（仅 `ASMP_SCHED*` 环境变量，无 CLI flag）；生产未启用 |
| `--perf-report`（溢出/load-use 链/ABI 建议）、`--debug-reg-map`、DWARF `-g` | `cli/as.rkt` | 仅调优时偶用，未进再生流程 |
| `variant-of/feature`（NEON/SVE 变体选择）、IPA callconv | docs | 未用 |
| asmp **没有**：宏、`.rept` 循环展开、编译期常量 | `docs/gnu-frontend-syntax.md:506-517` | → 循环展开必须留在外部生成器（本规划不试图改变） |

### 0.4 维护性/验证现状

- **拷贝同步**：`gen_*.py → .asm → .S` 三份（md5/sha1 四份，含未提交的
  OpenSSL 中间产物），改动手动传播，**无一致性校验**。
- **死代码**：`_bn_mul_mont_fips16` 生成并编译但 C 侧从未路由
  （`rktcrypto_bn.c` 只调 fips32）。
- **重复逻辑**：P-256 域乘两份并存——asmp 的 `mont_mul_p256`（C 调用）与
  转写的 `_p256_mul`（仅 `jac_double_hw` 内部用）。
- **provenance**：`md5/sha1/keccak*` 四个 .S 头部无源/生成器/再生命令
  （对比 `bn_op.S:1-7` 的完整头）；`p256_asm.S:1-2` 头注释已过时。
- **差分 harness 只覆盖 mont_mul 系**（`asm/mont_mul_test.c`、
  `mont_mul_p256_test.c`）；其余 8+ 内核依赖端到端 KAT 间接覆盖；
  RSA/bn Montgomery 内核不在 `rktcrypto_selftest.c` 核心 KAT 列表。
- **性能长尾**（相对 OpenSSL，实测）：P-384/521、Ed448/X448、SHA-1 等仍远低；
  `x25519/ed25519/ed448/blake3/poly1305` 纯 C 无 SIMD/asm。
- **历史教训**（必须尊重）：宽乱序 M1 上"取数前移"类调度收益实测≈0，
  P-256 point-op 生产路径最终回退 clang C（asmp
  `docs/openssl-parity-scheduling-plan.md:168-206`）。性能维度不重启该路线。

---

## 1. 分阶段规划

### Phase 0 — 护栏先行（一切重构的前置，独立可完成）

**P0.1 再生一致性检查 `regen-check`**
- 新增脚本/zuo 目标：对每个有完整链的内核，重跑 `gen_*.py` + asmp
  （固定 asmp commit），diff 产物与已提交 `.S`；不一致即失败。
- `.S` 头部 provenance 标准化模板：源文件、生成器、asmp commit、完整命令行、
  性能基线数字、guard 说明（以 `bn_op.S:1-7` 为蓝本，补齐 md5/sha1/keccak*）。
- **验收**：`regen-check` 对全部完整链内核绿；每个 .S 头部五要素齐全；
  CI/开发者一条命令可跑。

**P0.2 差分 harness 推广到全部内核**
- 以 `asm/mont_mul_test.c` 为模板（oracle=可移植 C、≥200k 随机+边界、
  ABI clobber sentinel x19-x28/v8-v15），补齐：op16、fips32、sqr_8w、
  mul_plain6/9、keccak_absorb×5、keccak_f2、md5、sha1、mont_sqrn×2、
  jac_double_hw。归入 `asm/tests/` 或 `tests/`。
- bn Montgomery 内核补进 `rktcrypto_selftest.c` KAT。
- **验收**：每个导出符号有独立差分 harness 且绿；selftest 覆盖 bn 内核。

**P0.3 cycle 基线登记**
- 每内核记录当前吞吐/延迟基准（`mm2_bench.c` 风格 + `crypto-benchmark.rkt`
  端到端），存 `asm/BASELINE.md`。此后一切重构以此为 ±2% 门禁。
- **验收**：基线表覆盖 9 个 .S 全部导出符号 + 端到端热点原语。

### Phase A — 孤儿收编与真源统一（维护性主战场）

原则：**每个 .S 必须能从已提交的源一键再生**；生成器（而非 .asm/.S）是
展开类内核的唯一真源。

- **A1 `sha1_blocks.asm` 入库** ✅（2026-07-26）：`gen_sha1.py` 本已自包含
  （直吐 asmp 源、不读 OpenSSL 文件），跑出 `asm/sha1_blocks.asm` 入库；
  regen.sh 纳入 sha1（`regen-check` PASS，产物体逐指令复现）；差分 0/200000 +
  "abc" 向量 + ABI guard，bench 20.3 ns/块（基线内）。附带删除 `fips16` 死代码
  （bn_fips.S 19969→15698 行），bn Montgomery KAT 进 selftest。
- **A2 `gen_md5.py` 自包含化** ✅（2026-07-27）：发现 regen.sh 的 md5 行生成器
  字段本已为空——committed `.asm` 即真源，OpenSSL 依赖只残留在死脚本里。故采
  **纯 SSA 重命名**（保指令顺序字节不变、只按每行语义注释把 `x.rN` 换成算法
  角色名 `a/b/c/d`、`m0..15`、`k<n>`、`f<n>`、`acc<n>`），消灭全部 626 处伪名；
  `gen_md5.py` 退役为历史说明（committed .asm 现为手工调度真源，同 mont_sqrn/Q1）。
  门禁：Gate A 规范化后 **0 结构差异**（649 指令逐条相同，仅寄存器分配号不同→
  性能由构造保证）；Gate B 差分 0/200000 + "abc" 向量 + ABI guard；regen-check PASS。
  副产验证：错误地给循环携带的状态回写命名会破坏 back-edge（多块 175163/200000
  失配，单块 "abc" 掩盖）——印证 harness 的多块覆盖价值。
- **A3 p256 孤儿岛收编** ✅（2026-07-27，改为**拆分**而非反向移植调度）：
  经代码研判，`_jac_double_hw` 是 OpenSSL ecp_nistz256 point-double 的手工调度
  转写（forward-load 与 `bl` 交织，160cyc==OpenSSL，代码注释明示为 sanctioned
  hand exception），6 个 helper 用 OpenSSL 内部寄存器 ABI（操作数 x3-x7）紧耦合
  于该调度——强行过 asmp 分配器/调度器会威胁 parity 关键热路径。真正的缺陷是
  **手写岛混入头部谎称 "GENERATED from mont_mul.asm" 的文件**。故**纯拆分**（移动
  committed 字节，零指令改动→零性能风险，同 bn_sqr/OpenSSL 对手写 asm 的处理）：
  - `rktcrypto_p256_asm.S`：4 个 asmp 内核（mont_mul/mont_mul_p256/mont_sqrn×2），
    regen.sh 纳入（known-drift：`_mont_mul_p256` 分配器演进漂移，其余 3 个精确复现）。
  - `rktcrypto_p256_hand.S`：6 helper + jac_double_hw，诚实标注为手写真源
    （**后由 A7 用 `.context` 收编为可再生源**）。
  **双份域乘不合并**（已判定）：`_p256_mul`（寄存器 ABI，仅此处用）与
  `mont_mul_p256`（AAPCS64 指针 ABI，C 面）ABI 不同，合并需重写调度、危及 parity——
  故刻意保留双份并在头注释说明。门禁：test_p256_extra 差分 0/210000（含 aliasing+
  真曲线点链）、ABI guard、bench 优于基线（jac_double 51.7 vs 56.5）；regen-check
  exit 0；build.zuo 加 p256_hand.S。
- **A4 `gen_fips.py` 汇入 asmp 管线** →（2026-08-05）**并入 Phase F/F1**：
  不再单独做「Python 改产 .asm 文本」的中间形态，直接以 Racket 发射器重写
  （`fips16` 死代码已随 A1 删除）。
- **A5 `bn_sqr.S` 收编——判定为诚实手写孤儿，暂缓待 M3** ⏸（2026-07-28，评估后
  决定不强转）：勘察确认 `rktcrypto_bn_sqr.S`（sqrx8x 对称平方，696 行）与 A7 的
  p256_hand **本质不同**，不是干净的 `.context` M1/L1 候选：①它用 **`x29` 作真帧
  指针**（全程 `[x29,#96/104/112/16..80]` 存溢出指针与 callee-saved 槽），而 asmp
  的 `.save all` 只存 x29/x30、**不执行 `add x29,sp,#0`**（A7 已证）→ body 的帧指
  针相对寻址会全错；②**变长栈 alloca** `sub sp,sp,x5,lsl#4`（x5=运行时 num）远超
  p256_hand 的定长 scratch，属 M3+（`.frame` 未实现）；③把 acc0-7 声明为 `x19-x28`
  上下文字段后，**手写 `stp x19,…` 保存被 M1 冲突检查拒**（实测"手写物理寄存器 x19
  与上下文字段占用同一物理寄存器"），而 asmp 无"已手工保存、仅记录覆盖"模式（`.save`
  与 codegen 绑定）。强转任一路径都会违反"调度字节不变/零回归"（需把帧指针相对改
  sp 相对寻址）或需新 asmp 逃生舱。结论：bn_sqr 的 ABI 已在头注释完整文档化、且被
  `test_bn` sqr8w 差分门禁守护，与 OpenSSL 自家手写 perlasm 内核同属**诚实手写真源**；
  regen.sh 保持 `UNSUPPORTED="bn_sqr"` 诚实 SKIP。干净收编需先落 asmp **M3（`.frame`
  支持帧指针+变长 alloca）** 或"手工管理帧"逃生舱（.context 字段标'手工保存'，豁免
  M1 raw 冲突+满足 L1 且不生成 codegen）——均属独立 asmp 工作，非本轮快赢。
- **A6 文档对齐** ✅（2026-07-28）：`asm/README.md` 内核表以 regen.sh TABLE 为权威
  重建——从 4 行（仅 P-256/Montgomery、且 p256_hand 误标"hand-written no source"）补全
  为 12 内核全表，标注 source kind（gen/hand-.asm/.context/hand-.S）+ 生成器 + 路由 +
  known-drift/orphan 状态；修正过时引用（不存在的 `gen_montmul*.py`、已删的
  `mont_sqrn_p256.asm`、"sanctioned hand exception"旧框架、跳过清单里已收编的 sha1/p256）；
  新增 `.context` 章节（用法 + "勿反射式扩散"判据，指向 asmp 设计文档 §7.1）。
  `p256_asm.S` 头注释已在 A3 拆分时修正。
- **A7 `p256_hand` 用 `.context` 收编为可再生源** ✅（2026-07-28）：A3 曾把
  `rktcrypto_p256_hand.S`（9 内核、812 行）诚实标注为手写孤儿，因 6 helper 与
  jac/mixed_add 紧耦合于 OpenSSL 内部**寄存器 ABI**（操作数 x4-x7/x8-x11、结果
  x14-x17、结果指针 x0），且两个点内核**手写 `stp x19-x22` + 硬编码栈偏移**——
  即硬编码审计的风险④（固定寄存器 ABI 契约散落各内核）与风险⑤（手写 callee-saved
  帧）。asmp 的 `.context (scope library)` 能力就绪后收编：**一条 `.context
  p256_field (scope library)` 声明整个寄存器-ABI 一次**（`a0-a3=x4-x7 b0-b3=x8-x11
  acc0-acc3=x14-x17 rp=x0 bp=x2 bz=x3` + 帧 `fr=x21 fp=x22 fq=x19`），9 内核全部
  `(context p256_field)` 导入，物理寄存器机械换成 `x.<field>`——**风险④消除**；两个
  点内核改用 `.save all` 让 asmp 自动生成 callee-saved 帧序/复原（L1 校验：漏 `.save`
  会在装配期报"字段落在 callee-saved 却未保存"）——**风险⑤消除**。128/352B scratch
  **内存**帧属 M3（`.frame` 未实现）保持手写，装配加 `--allow-sp-writes` 放行。
  **指令调度逐条不变**（M1 替换是 pre-regalloc 纯文本 pass，全物理体字节级穿过）。
  真源 `asm/p256_hand.asm`（20.7KB），regen.sh 纳入 p256_hand 行（`--allow-sp-writes`
  入全局 flags，对不写 sp 的其它内核 no-op，实证全 check 不变）。门禁全绿：**差分
  0/200000 ×3**（test_p256_extra 含 jac chain 0/210000、test_mixed_add、test_mont_sqrn）、
  **regen-check PASS**（指令体字节级复现）、**头对头不回归**（交织 NEW-vs-OLD：jac
  52.7 vs 52.2 ns ~1.01×、mixed_add 死平；vs OpenSSL point_double 1.005–1.026、
  point_add_affine 0.936–0.949 反超）、L1 活体校验。812→747 行。
- **验收**（Phase A 实质完成 2026-07-28）：`regen-check` 覆盖除 `bn_sqr` 外全部内核
  （bn_sqr 为诚实手写孤儿，见 A5，需 M3 才能干净收编）；`git grep 'x\.r[0-9]' asm/`
  为空（无伪语义名）；差分与基线双门禁全绿；死代码清零。**A7 消除了硬编码审计的最高
  风险④/⑤**（`_p256_*` 隐式寄存器-ABI 契约 + 手写 callee-saved 帧）；剩余 A4（gen_fips
  汇入 asmp）低优先，不阻塞。

### Phase B — 语义化重构（可读性主战场，逐内核推进）

- **B1 命名规范**：制定并文档化寄存器命名约定（`asm/NAMING.md`）——
  算法状态用角色名（`x.ha/x.hb/x.hc/x.hd`、`v.st0`）、数据流用
  `x.a0-3/x.bi/x.acc0-5/x.t0-3`、进位链临时 `x.c0/c1`；禁止 `x.rN`。
  转写内核 md5 已随 A2 完成语义命名；sha1 生成器本就产语义名（`v.abcd/v.m0/x.k`），无需重命名。
- **B2 `.inline` 模板收拢重复模式**：用 asmp GNU 前端已有的
  `.function (inline-only)` + `.inline fn (formal=actual)`（临时自动重命名）
  抽象：
  - P-256 Solinas 约简（9 指令 × 4 轮 → 1 模板）；
  - CIOS 列累加（`accumulate`/`reduce` 从生成器字符串拼接上移为 asmp 模板，
    生成器——Phase F 后为 Racket 发射器——只负责循环展开与参数化）;
  - MD5/SHA1 步函数（64/80 步 → 4 个轮模板）；
  - Keccak θ/ρπ/χ 阶段（生成器表驱动保留，阶段体模板化）。
  注意 asmp 无宏/循环展开（`docs/gnu-frontend-syntax.md:506`），**展开循环
  仍由生成器负责**——分工是"生成器管迭代结构，asmp 模板管迭代体"。
- **B3 注释纪律**：生成器在展开点自动发**不变量注释**（列宽、进位深度、
  当前处理的 b[i]/轮次），替代转写噪音；魔法常量一律带语义注释
  （`movz/movk` 对标注 `; K[3]=0xc1bdceee` 与 P-256 素数字面量标注）。
- **验收**：逐内核过双门禁（bit-exact + cycle ±2%）；抽查评审：新读者
  凭 .asm + NAMING.md 能在 15 分钟内说出任一段的算法角色（以 code review
  形式验收）；`.inline` 模板消除的重复行数 ≥40%（md5/p256 类）。

### Phase C — 产物与工具链可读性（含 asmp 侧配套，跨仓协作）

rktcrypto 侧：
- **C1 产物注释保全** — 见 C3（asmp `--keep-comments`）与源描述透传，已覆盖此意图。
- **C2 再生脚本化** ✅（2026-07-27）：`asm/regen.sh {check|regen|list}` 一条命令
  完成 生成器→asmp→guard→provenance 头（含 --keep-comments 与源描述），
  消除 README 三步手工流程。
- **C6 committed .S 携带内核描述** ✅（2026-07-27）：内核级人读描述放进**生成器
  或 .asm 源**的前导 `;;` 块（bn_op←gen_opscan、ecc←gen_mulplain、sha1←gen_sha1、
  keccak_f2←gen_keccak_f2、md5←md5_blocks.asm 手写源），regen.sh 的
  `source_description()` 把它抬进 .S 头——描述随源版本化、regen 无损（堵住"regen
  静默降级富头"的脚枪）。全部 committed .S 现带算法/性能描述。门禁：body 逐条不变
  （0 diff，注释被汇编器剥离→二进制 bit-identical）+ 6 harness ALL PASS + regen-check。

asmp 侧（另仓提交，rktcrypto 受益）：
- **C3 注释透传** ✅：emit 层按 loc 侧表保留源 `;`/`//` 尾注释到输出
  （`--keep-comments`）——0xd76aa478 类语义在产物中消失的根因已解。已用于
  md5（631 条行内注释）等。局限：只透传**指令行尾注释**，独立注释行（bn_op/ecc
  的 `// b[i] base=` 段标记）不透传——改由生成器描述块覆盖内核级说明。
- **C4 延迟/端口模型外置** ✅：`data/latency.rktd` + `pipeline/sched-model.rkt`，
  `--sched-model` 选择，默认 apple-m 与内置逐值一致。
- **C5 语法预留项清理** ✅：`.clobber`/`(noinline)` 解析时 stderr 告警。
- **验收**：C2/C6 后再生零手工步骤且富头无损；C3 后 `.S` 常量/关键段注释可见；
  C4 后调度器换核不改源码。**全部达成。**

### Phase D — 使用性能：定点解锁与长尾（以测量裁决）

基调：热点已持平/反超，本阶段**不追求普涨**，只做三类有明确依据的定点工作。

- **D1 调度器白名单实测** ✅（2026-07-27，结论：**不采纳，保持关闭**）：
  对 5 个内核用 `--sched-only <fn>` 再生，全差分门禁实测：
  | 内核 | 正确性 | bench(sched vs committed) |
  |---|---|---|
  | md5 | **错 200k/200k**（循环携带 a/b/c/d 态被误重排跨 back-edge） | — |
  | bn_op | 0/200000 | 103 vs 102 ns（无增益） |
  | mul_plain6 | 0/200000 | 12.2 vs 11.3（略差） |
  | mul_plain9 | 0/200000 | 20.8 vs 19.9（略差） |
  | keccak_f2 | 0/200000 | 119.8 vs 123（噪声内） |
  定论：宽 OoO M 核硬件已乱序执行，asmp 静态调度**无可靠增益**（差异全在
  测量噪声内，无一明确超过 committed），且对**循环携带依赖内核有正确性 bug**
  （md5 全错——asmp 调度器已知缺陷的具体可复现反例，比 deflate 5/31 更清晰）。
  差分 harness 当场抓到 md5 错误——**印证 Phase 0 门禁哲学：盲开调度器会静默
  破坏 md5**。故不采纳、保持 opt-in/off；asmp 侧修复循环携带态建模前不得默认开。
  **不重启** point-op 前移调度路线（历史已否决，此实验再次证否）。
- **D2 长尾测量与定点**（2026-07-27 测量完成）：C 级微基准量化长尾点算术：
  | 操作 | P-384 | P-521 | P-256(参考) |
  |---|---|---|---|
  | pubkey(定基 comb) | 39.4us | 36.6us | ~10us |
  | ECDH(变基 width-4 窗口) | **143.5us** | 118.1us | 26.8us |
  发现：① 长尾曲线**不在 racket/crypto 公共 API**，仅 TLS 内部特定套件用→次要热度；
  ② 标量乘算法**已优化**（变基 width-4 窗口+批量仿射、定基 comb 零在线倍点），
  无廉价算法收益；③ 反直觉的 P-384 ECDH 比更大的 P-521 还慢——P-521 有专用
  `p521rr.c`（Mersenne 快约简）+ 快点算术，P-384 走 ecc.c 通用路径；
  ④ **精确瓶颈定位**：P-384 字段乘 23.9ns = mul_plain6 **7.2ns** + reduce_p384(C)
  **15.1ns**——约简是乘法的 2 倍、字段乘的 63%（P-256 的等价 Solinas 约简是内联
  ~9 条 asm 指令）。→ asm 化 reduce_p384。
  **D2 已交付 asm reduce_p384**（2026-07-27，multiply-free shift/add Solinas，
  asm/reduce_p384.asm，进 rktcrypto_ecc_asm.S，fp_reduce 的 384 路 aarch64+apple
  路由，C 版留作 oracle+回退）。correctness：差分 **0/200000 + 0/9M 额外种子 +
  结构化边界** bit-exact（→ 由传递性所有 P-384 操作结果不变）。性能诚实修正：
  孤立 reduce asm 是 C 的 **2x**（6.9 vs 15ns），但 asm 是 `bl` 调用（`.save all`
  存 6 个 callee-saved），而 C reduce 被 clang 内联进 fp_mul——故 **field-mul 层
  实测仅 +16%**（交织采样载入免疫 C 18.4→asm 15.5ns），端到端 P-384 约 +10-16%。
  教训：孤立微基准不含调用开销，会高估内联替换的真实收益；`bl` kernel 替换内联 C
  须以 in-context 交织测量裁决。**本会话机器被外部 VM 持续占用（load 24-34，全局
  ~2.3x），绝对端到端数需空闲机器复测；比值类测量(交织/受控 harness)已可信**。
  Ed448/X448 罕用、3DES/Camellia/XTS 遗留——均低优先，暂缓。
  **OpenSSL 3.6.3 公平 raw 头对头验证**（2026-07-27，交织采样载入免疫，比值=
  rktcrypto/openssl 时间）：P-256 ECDSA sign 0.99x / verify 1.01x（**持平**，复现
  历史判断）、P-256 ECDH 1.17x（唯一缺口，纯变基 vs OpenSSL 最极致的 ecp_nistz256）、
  P-384 ECDH 1.03x / P-521 ECDH 1.05x（**~持平**，rktcrypto 侧还多做序列化故纯
  scalarmul 更近）。结论：**EC 面全线达到/接近 OpenSSL 持平**，D2 的 asm reduce_p384
  经此验证确认贡献于 P-384 持平；此前记忆"长尾远低"已过时（大 EC 优化早已完成，
  本次仅公平复测确认）。P-256 变基 ECDH 1.17x 是唯一残差，属 diminishing-returns
  区（OpenSSL ecp_nistz256 变基是黄金标准），sign/verify 已持平故非急，记录待未来深挖。
- **D-deep P-256 变基 ECDH 专用内核**（2026-07-27，按"定制专用内核非默认能力"指点）：
  组件 profile（变基标量乘 25.4µs）——260 次 jac_double(asm hw) 59%、52 次 mixed_add
  16%、预计算/求逆 11%、常量时间表选择 ~0（排除疑点）；field mul/sqr(asm) 6ns 近吞吐
  极限。倍点已到极限，**唯一非专用内核=mixed_add(C，逐乘 AAPCS64 bl)**。→ 手写
  register-resident `_mixed_add_hw`（p256_hand.S，链 _p256_* 寄存器 ABI helper、内联
  交织配对独立乘、复现全部 3 分支），fp 层路由 mixed_add→hw（C 留 mixed_add_portable
  oracle+回退）。门禁：差分 0/200000 bit-exact、ABI guard、交织比值 0.90（C 86→asm
  78ns）、self-test #t、pubkey KAT + ECDH 交换律 PASS。**头对头 vs OpenSSL：P-256
  ECDH 1.17→1.14x**（~3% 端到端，与预测一致——mixed_add 占 16% 提速 ~10%）。诚实：
  P-256 已 diminishing-returns（倍点/field-mul 已到极限、sign/verify 本持平），此为小
  margin 定点收窄，非大跃。committed harness test_mixed_add.c。
- **D-deep2 P-256 微调续（2026-07-28）**：ILP 测量——field mul 延迟 8.55/吞吐 5.63ns（headroom
  1.52x），但完全内联双乘需 2×寄存器>31 会溢出（OpenSSL 单体点内核 holistically 调度，
  高风险）。查得 `_p256_sqr`（倍点/混合加用的 helper）已是专用对称平方器，**唯一 mul-based
  是 `mont_sqrn_p256`（fp_inv 重复平方路径，16 积 CIOS）**。→ 专用对称平方器（10 积=6 上三角
  翻倍+4 对角，复用 _p256_sqr body 的 register-resident rep 循环，结果回喂 x4-x7 零 feedback mov），
  移入 p256_hand.S（从 p256_asm.S 手术移除旧版；regen p256 源去 mont_sqrn_p256.asm）。门禁：
  差分 0/200000（多 rep+边界，vs C oracle）、ABI guard、rep=255 摊销 0.876x、self-test #t、
  7 harness 全绿。**头对头 P-256 ECDH 1.14→1.11x**（fp_inv 2139→1933ns）。
  **累积微调：1.17→1.14（mixed_add_hw）→1.11x（专用平方），缺口 17%→11%**，两步皆 gated 实测。
- **D-deep2 决定性收官（2026-07-28）**：发现 OpenSSL libcrypto **导出了 ecp_nistz256 内部内核**
  （`ecp_nistz256_mul_mont/sqr_mont/point_double/point_add_affine`），可**逐层直接头对头**。
  结果（交织、载入免疫）：**rktcrypto 全部 P-256 内核已达/超 OpenSSL 持平**——field mul 1.01x、
  **sqr 0.98x（反超）**、point double 1.02x、**mixed add 0.98x（反超）**（微调的 mixed_add_hw +
  专用平方器让 add/sqr 反超 OpenSSL 实际内核）。故 ECDH "1.11x" 非内核缺口：~4%=
  rktcrypto_ecdh 含最终仿射 fp_inv+序列化而 OpenSSL EC_POINT_mul 只输出投影点（口径不对等，
  纯标量乘头对头 1.07x 证实）；~7%（纯标量乘残差）=弥散 C-glue/预计算（batch_affine、窗口
  循环粘合、倍点计数 261 vs ~256），表选择仅 2%、内核全持平。**结论：无剩余内核缺口可攻，
  P-256 已在内核级达 OpenSSL 持平/反超；residual 是 API 序列化(公平成本)+弥散粘合，非专用
  内核机会**。这也是"头对头实测参考实现"纪律的胜利——直接对比 OpenSSL 真实内核而非孤立
  microbench，定位到"缺口"实为测量伪差+弥散开销。
- **D3 纯 C 热点评估（总纲第三层）**：`x25519/ed25519/ed448/blake3/poly1305`
  目前纯 C；2026-08-05 增补 PQC 候选——ML-KEM/ML-DSA **NTT 全标量**
  （int16/int32 Montgomery，无 NEON），且 ML-DSA 矩阵展开未用 2-way Keccak
  批处理（ML-KEM 已用，`mlkem_impl.h` poly_parse_2x）。
  逐个先测 profile 占比再决定是否落 asmp 内核；x25519/ed25519 若动，
  须重跑 dudect 恒时验证。**先测量后动手，负收益即止**；新内核必配
  独立 C oracle 差分 harness（总纲不变式）。
- **验收**：D1 每内核出对比数字（启用调度 vs 现状），正收益者更新基线并
  固化进再生流程（`regen.sh` 记录 `ASMP_SCHED_ONLY` 配置）；D2 逐项给出
  与 OpenSSL 头对头比值，目标 ≥0.9×；D3 每候选有 profile 数据与 go/no-go
  结论存档。

### Phase E — 平台扩展：非 Apple aarch64（可用性收尾，2026-08-05 扩充）

前置已基本解除：Phase A 实质完成（2026-07-28）。`bn_sqr` 虽无 asmp 源，
但 hand-.S 本身可直接评估 guard 放宽，不阻塞本阶段。

- **E1 ELF/aarch64-linux 产物**：asmp `--gnu` 输出 + 放宽 guard 为
  `defined(__aarch64__)`（Apple/ELF 双分支）。需核对 Mach-O→ELF 差异是否
  全部由 asmp 输出层吸收：符号前导下划线、`.type`/`.size` 指示、section
  命名；`bn_sqr.S`/`p256_hand.S` 等含手写帧/手写段落的内核逐个人工核对。
- **E2 特性面收窄盘点**：Apple-M 基线假定 AES/PMULL/SHA2/SHA512/SHA3 全有；
  通用 aarch64（Neoverse、树莓派等）可能缺 SHA512/SHA3 扩展。盘点每个 .S
  与 intrinsics 路径实际用到的扩展指令，决定 guard 细化为按
  `__ARM_FEATURE_*` 分支，还是接 `rktcrypto_cpu` 运行时 dispatch
  （getauxval 检测面已备，`rktcrypto_cpu.c:29-71`）；C 标量兜底保证任何
  特性组合下功能完整（总纲：C=覆盖基础设施）。
- **E3 调度/延迟模型**：调度器默认关闭（D1 判定），ELF 变体无需新 sched
  模型即可发布；若未来为特定核开白名单，先落对应 `--sched-model` 数据
  （C4 已外置）。非 Apple 硬件上按 Q4 纪律重建 BASELINE（机型/频率/日期）。
- **E4 构建/测试接线**：`build.zuo` 预期无需改（guard 在 .S 内部）；差分
  harness、selftest、`tests/integration.rkt` 在 aarch64-linux 实机/CI 跑通。
- **验收**：aarch64-linux 构建产物过全部差分 harness + selftest +
  integration.rkt；`.S` 双平台由 `regen.sh` 同源产出（bn_sqr 除外，guard
  放宽后直接复用）；E2 盘点结论成文（哪些内核要求哪些特性、各自兜底路径）。

### Phase F — 生成器 asmp 化：Python 退役（总纲第一层）

原则：发射器与汇编器同语言同库。生成器从「打印 .asm 文本的 Python 脚本」
升级为「构造 asmp 指令结构的 Racket 模块」；构造后仍序列化为 `.asm` 文本
提交（Q5），check/gate/regen 门禁机制与口径完全不变。

- **F0 asmp 侧发射 API** ✅（2026-08-06，asmp 仓 `parser/gnu-writer.rkt` +
  `test/gnu-writer-test.rkt`，未提交）：gnu-parser 的逆——发射器直接构造
  `parser/ast.rkt` 结构，`gnu-program->string`/`write-gnu-program` 确定性
  序列化为 GNU 前端文本，**默认序列化后立即回读比对**（gnu-parser 解析、
  剥 srcloc 逐条 equal?，失配在发射点即报错）。构造器面：寄存器/立即数/
  三种寻址/寄存器列表/shift 尾随立即数拆分（与 parser 表示一致）/条件码/
  后缀指令 + `.function`（三行导出头/单行 context 头）/`.save`/`.restore`/
  `.context`/`.end`/标签/注释。门禁：8/8 测试绿；**语料往返 12/12 已提交
  .asm 全部闭合**（parse→serialize→reparse→AST 相同）；**双进程确定性**
  SHA-256 相同。无 hash 遍历序依赖（attrs 固定键序、context 按声明序）。
- **F1 逐内核迁移（每个独立过闸）**：
  1. **mulplain 试点** ✅（2026-08-06）：`asm/gen/mulplain.rkt`（`emit-mul-plain
     K`，6/9 limb 两份 Python 变体合并为一个参数化函数）+ 公共入口
     `asm/gen/gw.rkt`（ASMP env 定位 asmp 仓）+ 对拍仪器
     `asm/gen/asm-equiv.rkt`（两个 .asm 的 AST 级比较，后续每个内核迁移
     复用）。验收（全绿）：**AST 对拍** 新旧 .asm 逐条相同（272/566 项）；
     **.S 装配字节相同**（Gate A，性能构造性不变）；`.asm` 以发射器输出
     一次性重写（字节 diff 仅 Python 手工对齐空格 ×24 处）；regen.sh TABLE
     ecc 行换 Racket 命令；`gen_mulplain.py` 删除；`regen.sh check ecc`
     PASS + `gate ecc` 差分全绿 + perf 构造性跳过；**故障注入自证**（发射器
     植错 → check 报 DRIFT → 恢复复绿）。
  2. **gen_fips** ✅（2026-08-06，吸收 A4）：`asm/gen/fips.rkt`（`emit-fips
     K`，K=32；1.57 万行直出裸 GNU → 参数化模式函数）。形态：**.context
     fips_mont 把全部寄存器钉在 Python 版的同一物理分配**（体指令序逐条
     一致，机械获得语义名 t*/a*/b*/m*/plo/phi/q/top/sel）；手写 stp/ldp
     序幕换 `.save all`（唯一指令差异：帧布局 + p2align 4→2 + 条件码大小
     写）；768B 定长 sp scratch 帧手写保留（M3 范围，--allow-sp-writes）。
     异类管线消灭：TABLE 行从 `__DIRECT__` 直出改为标准 `.asm` 源，`.S`
     首次获得 provenance 头 + regen 包裹 guard。**Gate B 全绿**：差分
     test_bn 9 项 PASS；交织 A/B `bn_mul_mont_fips32` **451.3→449.8ns
     (-0.3%)**，同批对照内核全 ±0.2% 内；`regen bn_fips` 写入后自动门禁
     复绿；`check bn_fips` PASS（全链可复现）；`gen_fips.py` 删除。
  3. **keccak_absorb + keccak_f2** ✅（2026-08-06）：合并为单一
     `asm/gen/keccak.rkt`（`absorb`/`f2` 两模式）——两个 Python 脚本复制
     粘贴的 24 轮置换体收敛为一份 `emit-round`。AST 对拍逐条相同
     （absorb 876 项 / f2 141 项）；`.S` 产物不变（keccak 维持 KNOWN_DRIFT
     白名单保留旧 `.S`，本迁移只换 `.asm` 真源；keccak_f2 `check` 精确
     复现）；差分门禁全绿。**副产：故障注入暴露并修复一个门禁漏洞**——
     KNOWN_DRIFT 白名单原本连「生成器输出 ≠ 已提交 .asm」（do_check 步骤
     1）也一并豁免，坏发射器会静默过 check；已改为步骤 1 失配返回专用码
     2 一律硬失败，白名单只豁免步骤 2 的 `.S` 分配器漂移（注入实测
     exit 1，恢复后全内核 check exit 0）。
  4. **opscan + sha1** ✅（2026-08-06）：`asm/gen/opscan.rkt`
     （`emit-opscan K`）、`asm/gen/sha1.rkt`（乒乓状态机逐条复刻）。AST
     对拍逐条相同（op16 3305 项 / sha1 123 项，均一次通过）；`check`
     精确复现（.S 不变，性能构造性不变）；差分门禁全绿。
  每步门禁：优先追求**指令体逐条复现**（同 A2 纪律，零性能风险）；发射
  路径导致分配变化时走 gate 交织 A/B ±2%，警惕 keccak 式非良性漂移在
  别的内核复现。
- **F2 工具链收尾** ✅（2026-08-06）：TABLE 六个生成器行全部换
  `asm/gen/*.rkt` 命令；`git ls-files 'asm/*.py'` **为空**——含清除三个
  非 TABLE 残留（`gen_md5.py` 历史说明移植进 `md5_blocks.asm` 头注释后
  删除；`gen_montmul{,_p256}.py` 为 A3 拆分后死残留径删）；
  `asm/README.md` 内核表/流程章节改写；regen.sh 过时头注修正。
- **F3 发射器纪律 + 静态成本诊断** ✅（2026-08-07，参数搜索重定位为回归诊断）：
  发射代码可读性与 B1/B3 同级；发射器本身不在差分门禁保护下，正确性由
  内核差分兜底，故发射逻辑保持直白展开、禁自作聪明的间接层。
  **发射器查询调度模型的能力已落地为 `asm/gen/sched-cost.rkt`**——但按
  D1 结论（宽乱序 M 核静态重调度无可靠增益）**重定位为诊断而非增益搜索**：
  查 apple-m 模型算每内核 issue-bound / port-bound / chain-latency 三个
  周期下界（纯模型确定值、零测量噪声），快照 `sched-cost.snapshot` 挂进
  `regen.sh check`，发射器改动改变任一内核成本画像即非零退出（故障注入
  实证：多一条 nop → check exit 1 精确报 bn_op 漂移）。`gw.rkt` 扩展为
  统一入口 re-export ast 访问器 + 模型查询。成本表进 `asm/BASELINE.md`，
  读法印证内核设计（bn_fips 端口受限 chain 仅 49、bn_op CIOS 延迟受限
  chain 358）。**参数搜索求增益不做**——真·性能裁决仍是交织 A/B。
- **验收**：`git ls-files 'asm/*.py'` 为空；regen-check 全绿；全内核
  双门禁（差分 + ±2%）绿；KNOWN_DRIFT 清单不因迁移扩大（keccak 维持
  现状即可，不倒退）。

---

## 2. 依赖与推进顺序

```
P0 (护栏) ──► A (真源统一) ──► B (语义化) ──► C (产物可读性)
                    │                              │
                    ├────────► F (生成器 asmp 化)   └─► D1 (调度白名单)
                    │               │
                    └────────► E (ELF/aarch64) ◄────┘ (建议 F 先行)
                                                       D2/D3 (长尾/纯C/PQC NTT) ◄─ B 降低编写成本
```

- P0 独立先行，本身即有回归防护价值；
- A 是 B/E/F 的硬前置（已实质完成，2026-07-28）；
- **F 与 E 建议 F 先行**：先归一发射器再产 ELF 变体，避免 Python 生成器
  双平台各改一遍；但 E 不硬依赖 F（现有链也能产 ELF）；
- F0（asmp 侧发射 API）是 F1 的前置，属 asmp 仓工作（已完成 2026-08-06）；
- C3/C4（asmp 侧）与 B 并行不冲突；
- D 全程可穿插，但 D1 依赖 P0.2 的逐内核差分（调度器正确性以差分兜底）。

## 3. 非目标

- **不**把宏/循环展开塞进 asmp——生成器保留为展开类内核的真源，asmp 模板
  只承担"迭代体"抽象（与 asmp 设计边界一致）。
- **不**为语义化接受性能回退（±2% 门禁硬性）。
- **不**重启已被实测否决的路线：point-op 手工调度 ABI 群（asmp
  `config/abi.rktd:75-163` 的实验遗留）、宽乱序核上的取数前移。
- **不**做 asmp x86-64 后端与 x86-64 汇编内核（2026-08-05 重申并展开）：
  x86-64 暂非性能目标场景，该平台由**可移植 C 兜底** + 既有
  `rktcrypto_x86.c` intrinsics（AES-NI/PCLMUL/SHA-NI，运行时 dispatch）维持。
  asmp x64 后端 = 新 ISA 编码器 + 新寄存器/分配约束 + 新调度模型 + 全内核
  第二套实现与基线，投入同量级于重写一个编译器后端，且不改变任何 C oracle
  不变式。**重议条件**：x86-64 成为实际部署热点、且 profile 证明具体内核
  存在 ≥1.5× 的 C 路径缺口时逐内核个案评估——届时优先扩 intrinsics 路线，
  asmp 后端仅在 intrinsics 也不够时作为 asmp 仓的独立立项。
- **不**移除可移植 C（总纲）：C 是差分 oracle 与平台覆盖的基础设施；
  每个 asmp 内核必须保有独立 C 对照实现 + 差分 harness，此为硬不变式。
- **不**用汇编重写解析/协议/胶水层（DER/X.509、RSA 填充、KDF、TLS
  key schedule 等）——无性能收益、失去 sanitizer 与边界审计工具链。

## 4. 开放问题

- Q1：`mont_sqrn*.asm` 头注释自称 GENERATED 实为手工改编——按 A 原则补生成器，
  还是承认"手写 .asm 即真源"并修正注释？（倾向后者：平方内核结构特殊，
  强行生成器化收益低。）
- Q2：C 侧 intrinsics 热点（chacha20/gcm/aes/sha2/sha3 共约 500 行 NEON/crypto
  intrinsics）是否纳入 asmp 管辖？倾向**不纳入**：clang 对 intrinsics 的调度
  已被实测验证（AES/PMULL 共端口界），迁移只有维护性收益无性能收益，
  且失去编译器跨平台性。仅当 D3 发现 clang 调度劣化时个案重议。
- Q3：调度器正确性盲点（asmp deflate 用例 5/31 失配）是否阻塞 D1？
  不阻塞——D1 限定直线型内核 + 逐内核差分兜底，但 asmp 侧修复前
  **不得**将调度默认打开。
- Q4：`asm/BASELINE.md` 的基线数字是否随硬件换代失效？是——基线表须记录
  机型/频率/日期，换机重测（沿用 OpenSSL 对标的既有纪律）。
- Q5（Phase F）：Racket 发射器是否保留 `.asm` 文本中间产物？**已定：保留**
  （mulplain 试点即此形态）——人可审计、check 门禁口径不变、手写内核
  （p256_hand/md5 等）与生成内核维持同一表示；发射器构造指令结构后经
  确定性序列化产 `.asm`，asmp 照常装配；`write-gnu-program` 默认回读自校验。
  「同进程直出 .S」仅作开发期快捷路径，不进 regen 正式流程。
