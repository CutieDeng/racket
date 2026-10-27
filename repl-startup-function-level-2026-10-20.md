# REPL 启动：函数级定位与局部优化（第二轮，2026-10-20）

分支 `feat/repl-startup-analysis`，in-place 构建，macOS（Apple Silicon，APFS）。所有时间为本机实测；标注 **已验证**（实测）/ **推断**（间接证据）/ **未知**。

## 0. 结论

| 指标（normal 构建，pty） | 基线（N=15） | 本轮批 1（N=15） | 本轮批 2（N=20） | 差（基线 → 批 2） |
|---|---|---|---|---|
| 默认 REPL time-to-prompt 中位 / 最小 | 185.1 / 180.6 ms | 180.6 / 172.8 | 179.1 / 171.5 | −6.0 / −9.1 |
| `-q` time-to-prompt 中位 / 最小 | 107.4 / 103.2 | 106.6 / 103.9 | 105.5 / 102.6 | −1.9 / −0.6 |
| expander `resolver` 区域（6665 次调用） | 31.9 ms | 25.9 | 25.2 | −6.0…−6.7（已验证） |
| expander `module` 区域（383 次加载） | 18.3 ms | 16.1 | 15.6 | −2.2…−2.7（已验证） |

第二轮继续（I3，提交 rktio `rktio_ltps_poll`）：每次线程配额切换 15.6µs → ≈0µs（已验证，`quantum-bench.rkt`：同一 2 亿次紧循环开/关 engine 计时器 112.1 vs 112.6 ms；改前 141.5 vs 110.4）；默认 REPL 提示符前 135 次切换、`-q` 95 次 → 预计 −2.1 / −1.5 ms（推断）。I3 之后的 ttp 批次恰逢机器后台负载（load average 4.3，`suggestd`/`BTLEServer` 各 100% CPU），所有区域时间整体 +10～15%，该批次无效，待机器空闲后复测（§4 第三批）。

测试：`basic`/`module`/`file`/`path` 全过（I3 后再加 `portlib` 全过）；links 文件戳语义测试（同进程创建、同秒同大小改写、rename 替换、删除、重建）全过；`namespac` 的 `'names` 失败是预先存在（pvector 分支的 `core-unsafe-pvector-view-left` 的 `object-name` 为 `core-pvector-view-left`，`kernel.ss:231`），与本轮无关。

提交：两个独立提交（I1、I2），各自附带按其源码重生成的派生文件（`expander.scm`、`startup.inc`），并与全量构建产物逐字节比对。

本轮落地两处函数级局部修改，均在 expander 源码内，不改接口、不引入后台工作、不延迟任何已有动作：

| 编号 | 位置 | 改动 | 单次代价 | 启动期调用次数 | 预计节省 |
|---|---|---|---|---|---|
| I1 | `expander/eval/module-cache.rkt` `make-module-cache-key` | 用 `bytes-append`+`bytes->string/latin-1` 构造缓存键，替代 `(format "~s" (list hash dir))` | 2.71µs → 0.41µs（已验证，microbench） | 每次模块加载 2 次（load-handler 查、eval-module 存），383 加载 ≈ 766 次 | ≈ 1.8ms |
| I2 | `expander/eval/collection.rkt` `file->stamp` | links 文件戳的快路径改用 `file-or-directory-stat` 键（inode/size/mtime-ns/ctime-ns），不再每次查询轮询 filesystem-change-evt | 每个 links 文件 12.0µs → 2.3µs（已验证） | 每次集合查找 2 个 links 文件；init 步 ≈128 次查找，全启动 ≈300 次（推断） | ≈ 6ms |

## 1. 方法：为什么前一版函数级 profile 不可信

1. **`profile/sampler`（engine 采样）在启动场景下是准确定性的。** 采样线程要在主线程 engine 配额（`TICKS`=100000 tick）耗尽时才能被调度，于是采样点落在从每次线程切换起第 k×100000 tick 的位置；同一段确定性的启动代码，每次运行采到的是同一组点。两次 24/60 进程的聚合给出完全不同的"热点"（一次是 `locale-encoding-is-utf-8?`/`rest`，一次是 `write-bytes/max`/`fail-hash-ref`），且 `error-value->string-handler` 计数证明启动期根本没有异常格式化。结论：该采样器对启动分析无效（已验证）。
2. **改用时间采样器**（scratchpad `prof-startup2.rkt`）：`setitimer(ITIMER_REAL, 250µs)` → SIGALRM → Chez `register-signal-handler`，处理函数在被中断的续延上做 `continuation-mark-set->context`，输出沿用 `profile/analyzer` 的节点/边格式（`prof-agg.py` 聚合，`prof-query.py` 查调用链，`PROF_DUMP` 导出 JSON）。需要 DEBUG 构建（inspector 信息）才能把 io/expander/rumble 的帧映射到源码行；collects 下的 .zo 代码没有 inspector 信息，其自身时间会记到最近的有信息的外层帧（例如 `instantiate-linklet:969` = 模块体执行）。
3. **采样器的投递延迟上限是 `default-timer-ticks`=1000 tick**（`s/cmacros.ss:2124`；`$event` 由 trap 计数触发，信号到达只置 `something-pending`，不重置 trap 计数；`enable-interrupts` 把计数设为 1 让下一次 trap 检查投递）。后果：样本落在信号到达后 ≤1000 tick 内的**下一个 trap 检查点**，而 trap 检查在循环头与过程入口；时间按 **tick 密度** 而不是时间分布——紧循环（`clean-double-slashes` 的逐字节循环、UTF-8 编解码、`build-bnode` 填充）吸收其前面 C 调用/系统调用的时间。实证（已验证，`sampler-bias.rkt`）：`file-exists?` 循环 0.93µs/次，其中 66% 的样本落在 `clean-double-slashes` 循环，而该循环单独只占 0.1µs；`open-input-file` 循环 95% 样本落在 `do-custodian-register` 的 `lock-release`（open 系统调用之后的第一个 `enable-interrupts`）。
4. 工具（scratchpad `.../scratchpad/`）：`prof-startup2.rkt`（时间采样器，`init|all|raw|chains` 模式）、`prof-agg.py`（多进程聚合，`PROF_SCRIPT`/`PROF_DUMP`）、`prof-query.py`（按函数名查 3 级调用者/被调者）、`prof-loop.rkt`（对单个操作循环采样）、`sampler-bias.rkt`（投递滞后实证）、`guard-count.rkt`/`guard-count2.rkt`（security guard 计数 `->host`）、`resolver-stats.rkt`（resolver/load 包装计时）、`micro1-7.rkt`（microbench）、`kevent-bench.c`（裸系统调用成本）、`links-stamp-test.rkt`（I2 语义测试）、`ab-ttp.py`（ttp A/B）、`apply-round1.py`（补丁）。
5. 因此所有热点都用**直接计数 × microbench** 复核：security guard 钩子统计 `->host` 调用（按 `who` 分类），`current-module-name-resolver` 包装统计各形态模块路径的自身耗时（扣除嵌套 resolver/load 时间），`current-load/use-compiled` 包装统计加载次数。GC 时间通过 `(- wall gc-ms)` 做时间戳扣除。

## 2. init 步（`racket/init` 加载，DEBUG 构建 33ms 壁钟，GC 7ms，归因 24.8ms/run，30 进程 ×130 样本）

按修正后的归因（采样 + 计数复核）：

| 项 | profile 自身时间 | 直接计数 | 修正后结论 |
|---|---|---|---|
| 模块体执行（`instantiate-linklet:969/962`） | 4.4ms | — | 真实；collects 代码无 inspector 信息，不能再分（未知细分） |
| bundle fasl-read（`read-linklet-bundle-hash`） | 2.85ms | 259 次加载 | C 时间，真实 |
| `lock-release ← do-custodian-register ← open-input-file` | 1.9ms | 258 次 open | 实为 `open()` 系统调用：C 层 open+fstat+close 6.4µs，Racket 层 9.6µs（已验证）；归因位置是 open 之后的第一个 enable-interrupts |
| `clean-double-slashes` 循环 | 2.0ms | 1162 次 `->host`（file-exists? 127、directory-exists? 299、modify-seconds 478、open 258）+ split-path | 循环本身 ≈0.1µs/次 ≈ 0.2ms；其余是吸收的 stat 系统调用（0.5–0.9µs/次 ≈ 0.9ms）与 `find-col-file` 的 kevent 轮询 |
| `find-col-file`（集合查找） | 自身 0.3 + 分散 | resolver 包装：symbol 形态加载 113 次，自身 43µs/次 = 4.9ms；noload miss 15 次 ×38µs | **每次查找 2 次 `filesystem-change-evt-ready?`，每次 12.0µs（已验证：裸 `kevent()` 零超时轮询在本机就是 12µs）**，占查找成本的 2/3 |
| `make-module-cache-key`（`format "~s"` → printer → UTF-8 解码） | 1.65ms | 2 次/加载 | 已验证 2.71µs/次 |
| `code-from-bytevector`（R1 惰性代码 fasl-read） | 1.7ms | 1716 段 | C 时间 |
| `build-bnode`（D2 provides 表） | 1.0ms | — | 真实（disable-interrupts 区，样本记在 `enable-interrupts` 行） |
| `global-lock ← fasl->s-exp`（`datum-intern-literal`/prefab） | 0.9ms | — | 字面量 intern，0.06µs/次 → 约 1.5 万次（推断） |
| UTF-8 编解码（`string->bytes/utf-8` in build-path、`bytes->string/utf-8`） | 0.8ms | — | Racket 层循环 0.12µs/70B，Chez 原语 0.07/0.04；上限 0.5ms |
| `path-cache` 字符串键（`(cons s dir)` equal-hash） | — | 1526 次 noload string，0.54µs/次 | 0.8ms |
| `current-load-relative-directory` 读（derived parameter 的 guard 在读时跑 security check） | — | 2788 次 ×0.13µs | 0.36ms |
| 调度器 `swap-in-thread` | 0.45ms | — | engine 配额切换，非局部 |

interactive 步（xrepl）：`directory-exists?` 871 次（xrepl 680、readline 166）——`find-col-file` 对位于 pkgs 根目录的集合逐个探测 `root` 条目（links.rktd 有 216 个 `root`），`collection-path "xrepl"` 173µs/次（已验证）；resolver 包装显示 7 次 symbol 加载自身 1.46ms。

## 3. 本轮修改

### I1 `make-module-cache-key`
键 = `[长度字节][hash-code 20B][目录 bytes]` 经 Latin-1 解码后 `string->symbol`。Latin-1 逐字节映射保证 (hash, dir)→symbol 单射；原来的 `(format "~s" ...)` 走 printer（`write-via-handler` 1.30ms + `bytes->string/utf-8` 0.31ms + 输出端口）。

### I2 `file->stamp`
原实现：`old-stamp = (content . fs-change-evt)`，每次查找对每个 links 文件调用 `filesystem-change-evt-ready?`（kqueue 分支 = `rktio_ltps_poll` = `kevent()`，本机 12µs，与注册的 vnode 数无关）。
新实现：`old-stamp = (content . key)`，`key = #(inode size mtime-ns ctime-ns)`（`file-or-directory-stat`，1.4µs；缺文件先 `file-exists?` 0.9µs，避免异常开销）。键相同即复用缓存表；键变化则读内容比较，流程与原来相同。覆盖：原地改写（mtime-ns/size）、`touch`（ctime）、rename 替换（inode）、删除/新建（#f ↔ vector）。
**语义差异（需用户确认）**：原机制依赖内核事件，理论上能发现同一时间戳刻度内的两次改写；新机制在 mtime 纳秒级文件系统（APFS/ext4/NTFS）上等价，在 1s 粒度文件系统（HFS+/FAT）上若同一秒内改写且大小不变则漏检。同文件内的 `default-load/use-compiled` 本来就用秒级 mtime 判断 .zo/.rkt 新旧，因此这不是新的信任假设类型。Linux 上 inotify 轮询只需一次非阻塞 `read`（≈0.5µs），此问题是 macOS kevent 的固定开销所致。

### I3 `rktio_ltps_poll`（第二轮继续，调度器每配额开销）

定位（已验证）：`quantum-bench.rkt` 用 `(set-timer 0)` 关掉 engine 计时器对比同一 2 亿次紧循环：开计时器 141.5ms/2000 次切换，关 110.4ms → **每次线程配额切换 15.6µs**；紧循环里一个配额（100000 tick）只有 70µs，调度开销占 22%。默认 REPL 提示符前切换 135 次（`-q` 95 次，`vector-set-performance-stats!` 槽 4）。
机制：`poll-and-select-thread!` 在 tick 用尽时调 `check-external-events` → io sandman 的 poll → `fd-semaphore-poll-ready?` → `rktio_ltps_poll`（共享 ltps）。kqueue 分支无条件 `kevent()`（零超时 12.7µs；`poll(NULL,0,0)` 7.3µs、`select(0)` 0.16µs——本机实测），而 poll()/select() 变体早已有"表空即返回"。
修改：kqueue/epoll 分支加同样的 `rktio_hash_is_empty(lt->fd_handles)` 早返回。阻塞在 fd 上的线程在被唤醒前一直持有 ltps 条目，所以只要有可能就绪的 fd 仍会轮询；`ltps-wake-test.rkt`（主线程持续占 CPU、另一线程阻塞在 TCP 读）验证唤醒仍在一个配额内。
A/B：见 §4 第三批。

## 4. A/B（同机、同会话、normal 构建、pty 量 time-to-prompt，N=15）

基线与本轮是先后两次构建（同一提交基线 `make base` → 打补丁 → `raco setup -D` + `make derived` + `make base`），不是交错测量；区域时间来自 `PLT_EXPANDER_TIMES`/`PLT_LINKLET_TIMES` 各 3 次取中位。

```
base-normal  default  n=15 min 180.6 med 185.1 mean 187.3
base-normal  -q       n=15 min 103.2 med 107.4 mean 109.6
   expander: instantiate=50.3ms/734, module=18.3ms/383, read=12.4ms/520, requires=7.0ms/5355, resolver=31.9ms/6665
round1       default  n=15 min 172.8 med 180.6 mean 180.4
round1       -q       n=15 min 103.9 med 106.6 mean 107.0
   expander: instantiate=48.4ms/734, module=16.1ms/383, read=13.6ms/538, requires=7.1ms/5355, resolver=25.9ms/6662
```

第二批（N=20，提交后同一二进制）：

```
round1b      default  n=20 med 179.1 min 171.5
round1b      -q       n=20 med 105.5 min 102.6
   expander: instantiate=47.6ms/734, module=15.6ms/383, read=12.5ms/529, requires=6.9ms/5355, resolver=25.2ms/6662
```

第三批（I3 之后，N=20，机器负载 load 3.4、`BTLEServer` 100% CPU，**无效**，仅记录）：default med 195.4 / min 179.6，`-q` 111.1 / 107.9；所有区域（instantiate 58.3、linklet read 59）整体高于第二批 10～20%，是竞争而非代码差异。I3 的有效对比改用同二进制交错法，见 §4.1。

### 4.1 I3 的同二进制交错 A/B（已验证，`ab-emul.py`，30 对，负载 load 4–5 下）

两臂都是 I3 之后的同一个二进制、同一条命令形态 `racket -l racket/base -e <E> -i`：A 臂 `E=(void)`；B 臂 `E` 额外起一个线程阻塞读一个无写端的 FIFO（`open-input-file` 以 O_NONBLOCK 打开，`read-char` 得 EAGAIN → `fd-semaphore-update!` 在共享 ltps 登记该 fd），于是 B 臂的每个配额切换都回到改前的行为（ltps 非空 → `kevent`）。交错执行，逐对相减：

```
A (no fd registered, I3 active)   n=30 min 163.2 med 167.4 mean 168.0
B (fd registered = kevent/quantum) n=30 min 166.8 med 172.0 mean 172.3
paired B-A: median +3.8 ms, mean +4.2 ms, pairs 30, positive 28/30
```

即 I3 让默认 REPL 启动少 ≈3.8ms（B 臂多一个休眠线程带来的调度簿记会使该值略偏大，上限估 0.3ms）。与"135 次切换 × 12.7µs ≈ 1.7ms"的估算相比偏大：切换后的 `kevent` 返回还会把 `check-external-events` 的 `did?` 路径与 cache 污染一起算进去（推断）。

resolver −6.0ms 与 I2 的估算（≈300 次查找 × 2 × (12.0−2.3)µs ≈ 5.8ms）一致；module −2.2ms 与 I1 的估算（766 × 2.3µs ≈ 1.8ms）一致。`-q` 的 ttp 差在噪声内（N=15 的中位数噪声约 ±3ms），但区域计时对两种启动同样适用。

## 5. 函数级剩余候选与上限

提交：23b46dfd89（I1）、b9da9e567c（I2）、0ce4367080（I3）。

init 步（24.8ms 归因）剩余按函数拆分后，单项都在 1ms 以下：

1. `find-col-file` 的 pkgs `root` 逐目录探测（xrepl/readline 类集合 173µs/次；interactive 步 ≈0.9ms）：可在 `get-linked-collections` 建表时把 `root` 目录的子目录列表并入（与 `static-root` 相同），但 `root` 语义是"动态内容"，缓存失效需绑定目录 mtime——属设计变更，待用户定。
2. `open-input-file` Racket 层 3.2µs/次 ×383（端口对象 + custodian 注册 + 4KB 缓冲）：≈1.2ms，分散，无单点。
3. `path-cache` 字符串键：`(cons s dir)` 的 equal-hash 0.54µs ×1526 ≈ 0.8ms；可改两级表（dir → string 表）。
4. UTF-8 编解码走 Chez 原语的纯 ASCII/合法序列快路径：≤0.5ms。
5. `clean-double-slashes` 紧循环改 unsafe/fixnum：≈0.2ms。
6. `datum-intern-literal`：intern 语义本身，不动。
7. `default-load/use-compiled` 的存在性/日期探测（每次加载 ≈5 次 stat ≈ 5µs）：已是最少（源与 .zo 各一次日期），不动。

函数级能触及的部分到此为止；更大的桶（模块体执行 3.8ms、bundle fasl-read 2.85ms、代码 fasl-read 1.7ms、provides 建表 1.0ms、字面量 intern 0.9ms、open 系统调用 1.9ms——均为 init 步数值）需要格式/声明层的设计变更（R4 bundle 元数据惰性、声明期数据的进一步惰性化、代码物化成本），不属本轮。

## 6. 量法陷阱（新增）

- `profile/sampler` 在确定性工作负载上采样点固定，不能用于启动分析。
- 信号采样器投递延迟 ≤1000 tick，紧循环吸收其前面 C/系统调用时间；必须用计数 × microbench 复核。
- macOS 上 `kevent()` 零超时轮询固定 ≈12µs（空 kqueue 亦然）；`filesystem-change-evt-ready?`/`sync/timeout 0` 同价。
- `stat` 0.5µs、`fstat` 0.2µs、深路径 `open`+close 6.2µs（C）。
- `collection-path` 的 microbench 必须放在循环外（29µs/次），否则污染被测项。
- `(current-module-name-resolver)` 以 `load?=#f` 调用不会填 path-cache，microbench 必须用 `load?=#t`。
