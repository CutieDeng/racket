# C1：faslin-code（S2 读路径）建账与第一项局部优化（2026-10-25）

树 `racket-feat-native-pvector` / `feat/repl-startup-analysis`，HEAD `0434cdb553`。工具：`experiments/startup/faslbench.rkt`（进程内对默认 REPL 模块集的全部 code linklet 做 `fasl-read`，不运行代码；`FB_PAUSE` 配合 `sample`）、`linklet-times.py`（pty 默认 REPL 的 `PLT_LINKLET_TIMES` 退出报告）、`ab-swap.py`（换 `Racket.framework/.../Racket` 二进制做交错 A/B）。符号在 `racket/lib/Racket.framework/Versions/9.3.10_CS/Racket`（2560 个），`racket/bin/racket` 52 KB 只是启动器。

## 0. 结论

| 指标 | 改前 | 改后 | 性质 |
|---|---|---|---|
| 进程内 `fasl-read` 全部 3137 个 code linklet（11.8 MB）每轮 | 31.8–33.7 ms | 25.5–25.7 ms（3 次运行，极差 0.3） | **已验证** −7 ms（−21%） |
| 默认 REPL `faslin-code` 区域（8 次交替，中位） | 37 ms | 33 ms | 推断方向一致；机器 load 5–6，单次散布 29–45 |
| 默认 REPL ttp 交错 A/B 25 对 | 209.9 | 195.6 | **未确证**：13/25 为正，单次噪声 ±30 ms，待空闲机器复测 |
| 预期整启动收益 | | ≈ −5 ms（9 MB / 11.8 MB × 7） | 推断 |

测试：basic / number / string / fasl / module 全过。提交 `0434cdb553`（只改 `racket/src/ChezScheme/c/fasl.c`，无派生文件）。

**修正 P2 报告的说法**：10-19 正向报告 §11 已更正"Racket faslin 是裸 Chez 8–10 倍"——那是拿简单数据测的裸 Chez 速率，不可比；对同样内容裸 Chez `fasl-read` 就是这个速度（decl+data+stx+body0 = 14.8 ms 与 Racket 区域吻合）。C1 不是"找 Racket 包装层差距"，而是**让 Chez fasl 读取器本身更快**。

## 1. 自采样剖面（`sample` 5 s，150 轮循环，自身样本数）

| 函数 | 改前 | 改后 | 说明 |
|---|---|---|---|
| faslin（对象解码主循环） | 736（32%） | （首行被截，≈同量级） | 格式固有 |
| S_fasl_uptrin + iptrin | 446 + 146（25%） | 109 + 175（12%） | **本次目标**：每个长度/计数/重定位偏移/fixnum/字符串字符各一次调用 |
| LZ4_decompress_safe | 351（15%） | 494（21%） | 压缩 .zo 固有；未压缩 .zo 10-19 实测整体更差 |
| stringin | （并入 uptrin） | 301（13%） | 符号/字符串逐字符解码 |
| S_intern_sc + S_intern3 + mutex | 167+77+~83（14%） | 204+108+~20（14%） | 每个符号一次 oblist 查找，含 tc_mutex 加解锁 |
| sys_icache_invalidate | 109（5%） | 170（7%） | 每次 `fasl-read` 后对本次写入的 code 范围刷 icache，每 linklet 一次 |
| Sinteger / memmove / S_vector | ~124（5%） | ~138 | |

## 2. 改动（fasl.c）

`uptrin`（宏）、`iptrin`、`sizein` 加内联单字节快路径：缓冲区里已有字节且延续位为 0 时直接取；否则回落到原 `S_fasl_uptrin` / 原循环（改名 `iptrin_slow`）。`S_fasl_uptrin` 对外行为不变（`bytes_consumed` 调用方不受影响）。平台无关 C，pb 同样编译。

## 3. 下一项候选（按剖面）

1. 符号路径（stringin + intern ≈ 26%）：解码时顺带算 hash、免二次扫描；或把 `S_intern_sc` 的 tc_mutex 改为整次 `fasl-read` 持有一次（每符号省一对加解锁，约 3%；需确认 faslin 内不会触发需要让出锁的 GC）。预期 −2～3 ms（推断）。
2. icache 刷新 7%：每 linklet 一次 `S_flush_instruction_cache`；代码读完即执行，难以跨 linklet 合并；可查刷新范围是否只覆盖本次 code 对象。
3. LZ4 21%：不动（10-19 已测未压缩整体更差）。
4. faslin 主循环 32%：需逐 case 计数后再定。

## 4. 量法记录

- 机器 load ≥ 4 时 ttp 单次噪声 ±30 ms，25 对交错仍不能判 5 ms 级差异；此类改动以进程内基准为准，整启动 A/B 留到空闲时段。
- `make base` 重编 fasl.c 并重链 framework 约 3.5 分钟（tmux 会话 `repl-c1`，日志 `/tmp/c1-make.log`）。
- A/B 换 framework 二进制用 `cp -p` 即可（启动器通过 `@executable_path/../lib/Racket.framework` 动态链接）。

## 5. 第二项：符号解码时顺带求 hash + fixnum 内联（提交 `eae5477bf7`）

| 指标 | 第一项后 | 第二项后 |
|---|---|---|
| 进程内每轮（3137 linklet / 11.8 MB，3 次运行） | 25.4–25.7 ms | **24.3–24.7 ms**（基线 31.8–33.7，累计 −24%，已验证） |

改动：`symbolin` 用 `SYM_HASH_INIT`/`SYM_HASH_MIX`（移到 types.h 与 intern.c 共用）边解码边算 hash；`S_intern_sc_hc`/`S_intern3_hc` 接收预算好的 hash，原入口成为包装；`fasl_type_small_integer` 的 fixnum 范围直接 `FIX`。测试 basic/number/string/fasl/module 过。整启动 ttp A/B 仍未做（load 4.6，脚本在 load <3 时才跑）。

改后各类 linklet 的读取速率（每轮，暖缓存）：

| 类别 | n | KB | ms | µs/KB | µs/个 |
|---|---|---|---|---|---|
| phase0 体 | 743 | 5582 | 10.74 | 1.92 | 14.5 |
| stx-data | 311 | 1302 | 5.32 | **4.08** | 17.1 |
| phase1 体 | 263 | 2767 | 4.17 | 1.51 | 15.8 |
| decl | 743 | 1387 | 3.66 | **2.64** | 4.9 |
| data | 743 | 478 | 0.94 | 1.96 | 1.3 |
| stx | 311 | 272 | 0.28 | 1.03 | 0.9 |

## 6. fasl 对象普查（临时计数器，已从源码移除）

每轮 2.97 M 个 fasl 对象 ≈ 8.4 ns/个：读取器每对象已很快，成本在对象数量。

| 类型 | 占比 | 其中在向量内 |
|---|---|---|
| small_integer | 31% | 86% |
| graph_ref | 30% | 78% |
| immediate | 12% | — |
| library_code（重定位项） | 6% | — |
| symbol + gensym | 5% | — |

重定位项（每轮 40 万）本身便宜：46% `library_code`、28% `graph_ref`。code 对象的 name/arity/code-info/pinfos 子读只占对象总数 ~14%。

按 linklet 归因（抽样 1568 个）：small_integer 的 63% 来自 **stx-data**（`racket/private/for` 13.4 K / 43 KB，`syntax/id-table` 7.0 K，`syntax/parse/private/rep` 5.1 K，pvector 4.8 K……），其次 phase0 体 16%、phase1 9%、**decl** 9%（`syntax/contract` decl 5.6 K / 32 KB）。抽样到的向量形如 `#(1 2 3 0 4 5 6 7 8 9)`、`#(2 5 6 7 8 9 10 12 13 14 16 20)`——expander 序列化（scope/binding/shift 表、provides/requires 编码）的整数索引表，不是机器码或 code-info。

**结论**：读取器侧的微优化已拿到 −24%（暖缓存）；剩余剖面 LZ4 ~21%、faslin 主循环、icache 7% 均难再压。对象密度问题属声明层（S3）：stx-data 与 decl 的序列化用 fxvector/bytevector 整数流替代"fixnum 向量"，可把这两类的对象数降一个量级（推断），并同时减少分配与 GC。启动时实际被读的 stx-data 数量未量（推断 ≤180/311：1676 次 faslin-code − decl/data/stx 各 383 − phase0 ~350）。

## 7. 量法记录（续）

- zsh 里 `cmd | tee log; echo $?` 记的是 tee 的状态，必须用 `${pipestatus[1]}`；第一次重建因此误报成功。
- 临时 C 计数器要放在首次使用之前或加前向声明，否则 `make base` 内核编译失败但顶层仍可能继续。
- 进程内 `fasl-read` 基准是暖缓存；真实启动同样字节慢约 1.6×（冷页/首次触碰），比例收益可按区域时间折算。
