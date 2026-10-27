# S3：声明层序列化数据改字节流编码（2026-10-25，已提交）

树 `racket-feat-native-pvector` / `feat/repl-startup-analysis`，基于 `7926a572a5`。工具：`experiments/startup/faslin-census.py`（临时 `PLT_FASLIN_TRACE` 钩子，按 linklet 种类统计启动期 faslin 次数/字节/ms）、`zo-linklets.rkt`（单个 .zo 的逐 linklet 代码字节与 literals 载荷）、`linklet-times.py`。

## 0. 起点：启动期 faslin 普查（默认 REPL，5 次中位，改前）

| 种类 | n | KB | ms | µs/KB |
|---|---|---|---|---|
| module 体（phase 0 + 162 个 phase 1） | 545 | 7198 | 25.4 | 3.53 |
| decl | 383 | 1028 | 5.46 | 5.31 |
| stx-data（提示符前被强制的） | 96 / 311 | 456 | 3.22 | 7.06 |
| data | 383 | 273 | 1.27 | 4.64 |
| stx | 269 | 235 | 0.48 | 2.05 |

decl/stx-data 每 KB 比机器码贵 1.5–2×：C1 普查已证明它们由 expander 序列化器输出的"每元素一个对象"的向量组成（keyword 标签 → 外部 literal 的 graph 引用；整数、重复符号各一个 fasl 对象）。

## 1. 改法

`compile/serialize.rkt`：四条指令流（mutable shells / shared / fills / result）从"元素向量"改为**字节流**：
- 首字节分类：`#x00..` 操作码（42 个 `#:` 标签按表编号）、`#x40–#xB7` 小整数 0..119、`#xB8/#xB9/#xBA` = #f/#t/'()、`#xBB` zigzag LEB128 整数、`#xBC` LEB128 literal 索引、`#xBD–#xFF` literal 索引 0..66。
- 非整数非标签的值（符号、关键字值、字符串、字符、数、prefab key 等）进每次序列化一个的 literals 向量，按 eq/equal 去重（可变字符串不去重）。
- 编码在 `reap-stream!` 时一次完成；`ser-push! 'tag` 推入 `tag-elem` 包装（`scope.rkt` 推的 `#f` 标签 = "无需填充"标记，编为 #f 字节）。
- 操作码表在 phase 1 定义一次，`case-op`/`op-code` 宏在解码器里展开成数字 `case`；运行期表用逐个 keyword 字面量构造（flattener 不能从引号向量里 lift keyword）。
- 解码器 `decode`/`decode-shell`/`decode-fill!` 按字节分类读取；`deserialize` 多一个 `lits` 参数；旧向量格式解码器保留为 `deserialize/v` 等，`deserialize` 按 `(bytes? mutable-vec)` 分派，**已编译的旧 .zo 继续可用**（不 bump 版本）。
- `data` 向量从 4 元扩到 5 元（加 lits）；`as-data?` 形式 6 → 7 元。

`schemify/literal.rkt`：**可变字节串不再登记为 intern literal**。否则四条字节流被 lift 进 `racket/fasl` literals（`fasl->s-exp` + `datum-intern-literal` 读取、且不走 LZ4），实测 for.rkt 的 stx-data literal 载荷 152 → 225 KB、.zo 反而 +13%。规则依据：intern 面向 reader 字面量，而 reader 字面量是不可变的；引号里的可变字节串是程序构造的数据（本例即 expander 序列化流）。

## 2. 实测（collects 重编为新格式；路径上 ~60 个 pkg 模块仍旧格式）

| 种类 | 改前 KB / ms / µs/KB | 改后 KB / ms / µs/KB |
|---|---|---|
| decl | 1028 / 5.46 / 5.31 | 1020 / **3.65** / 3.58 |
| stx-data | 456 / 3.22 / 7.06 | 450 / **1.88** / 4.17 |
| data | 273 / 1.27 / 4.64 | 273 / 1.32 / 4.86（未改，mpis 另有编码） |
| faslin-code 合计 | 35.8–38.3 | 33.3 |

expander 区域（3 次）：`module`（声明）14.4 → 11.8–13.0 ms，分配 18.1 → 16.0 MB；`eval` 总分配 132.1 → 127.9 MB。.zo 体积：collects 719 个 29.9 → 29.6 MB（−1.2%）；for_rkt.zo 335 → 339 KB（stx-data 代码区 44.8 → 49.9 KB：字节流原始体积更小但 LZ4 压缩率低于旧的重复 graph 引用模式）。ttp 在 load 4–5 下不可判。

**推断**：剩余 decl/stx-data 成本已接近机器码速率（3.6–4.2 µs/KB），主体是 LZ4 解压 + 字节拷贝 + lits 向量里 strings/srcloc 的 `racket/fasl` 读取（for.rkt stx-data 2877 个 literal / 151 KB 不变）。再降需动 literals（srcloc/字符串）的编码，属另一项。

## 3. 量法与陷阱

- `make base` 只重编有改动的源；.dep 只记版本与 VM，序列化格式变了也不触发重编——测新格式必须删 `compiled/*.zo *.dep` 再 `make base`。
- `make base` 的 `raco setup` 会把 `info-cache.rktd` 写成只含 collects 的空表 → `raco make` 消失 → `make derived` 失败；每次 `make derived` 前先 `raco setup --no-docs --pkgs compiler-lib`。失败的 `make derived` 会删掉 startup.inc / expander.scm，用 `git checkout --` 恢复。
- `run.rkt -c <dir>` 独立跑源码 expander 在本树不可用（`linklet-bundle-machine-type` 的 host 原语缺失，预先存在）。
- flattener 限制：引号向量里的 keyword 不能 lift（"value that needs lifting is in an unrecognized context"）；用逐个 `(quote #:kw)` 构造表。

## 4. 收尾（全量 .zo 重编后，提交）

全部 5880 个 pkg .zo + 719 个 collects .zo 重编为新格式后（默认 REPL，5 次中位）：

| 种类 | 改前 ms / µs/KB | 改后 ms / µs/KB |
|---|---|---|
| decl | 5.46 / 5.31 | **3.59 / 3.51** |
| stx-data（96 个被强制） | 3.22 / 7.06 | **1.79 / 3.94** |
| data | 1.27 / 4.64 | 1.42 / 5.21（未改） |
| faslin-code 合计 | 35.8–38.3 | 33.6 |

expander `module` 区域 14.4 → 12–13 ms、分配 18.1 → 16.0 MB；ttp 7 次 min 165.6 / 中位 168.2（load 5，同条件早些时候 176–185，差值不可判，推断 −5～−10）。

**连带修复**：`compiler/private/deserialize.rkt`（demodularizer 与 `raco decompile` 用的反序列化器副本，9 参数）对新 10 参数形式报 arity mismatch，使 compiler-test 的 demod sandbox 测试编译失败；加 `stream->elements` 把字节流翻成它原本消费的元素列表（操作码表与 expander 同序，需同步维护）。demodularizer 自己的输出（`bundle.rkt`）仍生成向量形式 → expander 里的向量解码器须永久保留，这也是不 bump 版本的依据。

测试：basic/module/syntax/stx/macro/read/number/string/fasl 过；namespac 只剩预先存在的 `names`；demod 99 过；xrepl 只剩预先存在的 #23。派生文件二次再生零 diff。提交 `(FEAT "expander: byte-stream encoding for serialized data")`。

**剩余**：literals 向量里的 srcloc/字符串仍走 `racket/fasl`（for.rkt stx-data 2877 个 / 151 KB，faslin-literals 区域 4–10 ms）；`data` linklet 的 mpis 编码未改；两者是下一候选。

## 5. 第二项：srcloc 共享源路径（提交 `expander: share srcloc sources in serialization`）

literals 普查（`lit-census.rkt`，启动模块集 2372 个有 literals 的 linklet，改前）：racket/fasl 载荷 667 KB，其中 stx-data 495 KB = **37,987 个 srcloc**（每个一个 struct + `datum-intern-literal`）；data 86 KB = 5532 个模块路径字符串；phase0 42 KB（keyword 656、string 380、srcloc 547、regexp 95）；decl 6 KB（1092 个 hash）。

改法：源为路径的 srcloc 不再整体作 literal，改为流内 `#:srcloc/source` 操作码 + 4 个整数 + 一个共享"源持有者"literal（`(srcloc path #f #f #f #f)`，每个源路径一个）。持有者本身是 srcloc，所以 `racket/fasl` 的相对化/截断规则逐字节不变。compiler-lib 副本的操作码表同步追加。

| 指标 | 改前 | 改后 |
|---|---|---|
| racket/fasl literal 载荷（启动模块集） | 667 KB | 191 KB |
| stx-data 部分 / srcloc literal 数 | 495 KB / 37,987 | 19 KB / 393 |
| 全部 literals 暖解码（进程内单遍） | 6.55 ms | 3.10 ms |
| collects .zo 总量 | 29.6 MB（原 29.9） | 29.0 MB |
| ttp 7 次（load 5.6–7.7） | — | min 161.5 / 中位 174.0（不可判） |

测试：核心套件同前（namespac `names`、xrepl #23 预先存在），demod 99 过，派生文件二次再生零 diff。

剩余 literals：data 的 5532 个模块路径字符串（86 KB，需字符串语义）、phase0/phase1 体的 keyword/regexp/prefab（~80 KB）。

## 6. lan-11 整启动 A/B（Zen 5，空载 load 0–1.4，已验证）

两树独立构建（`make CPUS=16 JOBS=16 base`，无 xrepl/expeditor 包，故不含 P1）：A = `0ce4367080`（今日之前），B = `8bfa166008`（C1 两项 + S3 两项 + 一项 Linux 修复）。pty time-to-prompt 交错：

| 场景 | A 中位 / 最小 | B 中位 / 最小 | 逐对差中位 | 正向对数 |
|---|---|---|---|---|
| `racket -i`（racket/init，普通 REPL） | 117.6 / 112.2 | 111.1 / 109.9 | **−6.7 ms** | 25/25 |
| `racket -I racket/base -i` | 46.6 / 45.4 | 45.2 / 44.6 | −1.3 ms | 15/15 |

linklet 层退出报告 total 63–70 → 58–60 ms（3 次，噪声大）。macOS 同类改动下 racket/init 层本地估算 −5 ~ −8，与 lan-11 的 −6.7 一致。

**连带发现并修复**：C1 第二项把 `SYM_HASH_INIT/MIX` 放进了 types.h 的 `#ifdef PTHREADS` 段，lan-11 的内核编译不取该段 → fasl.c 隐式声明错误，macOS 构建未暴露。提交 `8bfa166008` 把宏移到无条件区（FIXRANGE 旁），两机构建通过。

lan-11 流程：bundle（6 提交仅 86 KB）→ rsync → bare 仓 fetch → 两个 clone 各复制 `boot/pb` 种子（须先 `mkdir boot`）→ nohup make → 远端阻塞等 rc 文件；`~/startup/{ttp.py,ab-two.py,linklet-times.py}`。
