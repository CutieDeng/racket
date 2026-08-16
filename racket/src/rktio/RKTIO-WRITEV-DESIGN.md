# rktio 矢量写 (writev) 设计与进度

动机: `t"..."` / 大输出构建器手里已是一串 slice (字面段 + 插值), 现在只能
拼接成一个连续缓冲 (`string-append`, O(输出长度) 分配 + 拷贝) 或逐 slice 走
端口写 (每 slice 一次 Racket 端口层分派)。scatter/gather 写让 slice 列表
一次 `writev(2)` 出去——零拼接、一次分派、一次 syscall。收益集中在**大输出**
(小输出 string-append 仍最优, 见 pkgs/racket-tstring/PERF-NOTES.md)。

前提事实: rktio 此前**无**矢量写——`rktio_write`/`_in`/`_in_r` 全是单连续
缓冲, 无 iovec/writev。

## 已完成并 C 级验证 (①②)

- **rktio.h**: `rktio_iovec_t { const char *base; intptr_t len; }` +
  `rktio_writev(rktio, fd, iov, iovcnt)` 声明 (RKTIO_EXTERN_ERR)。
- **rktio_fd.c**: `do_writev` + `rktio_writev`。
  - POSIX 快路径: 非 socket / 非 pending 的 file/pipe fd → 单次 `writev(2)`;
    非阻塞 (临时 O_NONBLOCK)、EINTR 重试、EAGAIN→0、部分写返回字节数、
    终端跟踪 wrote_to_terminal, 语义逐条对齐 `do_write`。
  - 上限: 每次至多 RKTIO_WRITEV_MAX=64 slice (栈上 iovec[64]=1KB) + 总字节
    ≤ MAX_READ_WRITE_REQUEST_BYTES (同 do_write 的 LIMIT_REQUEST_SIZE);
    超出由调用方 resume。空 slice (len≤0) 跳过。
  - 回退: socket / pending-open / **全部 Windows** → `writev_sequential`
    (逐 slice 复用 do_write, 保留所有特例处理; 首个部分写/阻塞/错误即停,
    返回累计字节, 调用方 resume)。
- **测试** (scratchpad/test_writev.c, 链 build/cs/c/rktio 真实 config):
  3-slice 顺序拼接、空 slice 跳过、零/全空→0、100 单字节 slice 可恢复部分写
  (覆盖 >64 上限 + resume 协议)。**ALL PASS**。
  编译: `cc -I<rktio> -I<build/cs/c/rktio> test_writev.c rktio_fd.o
  librktio.a -framework CoreFoundation -liconv`。
- 纯增量: 既有 `rktio_write` 路径零改动; rktio_fd.c 对真实 config 编译干净。

## 剩余路径 (③④, build-heavy, 未做)

**③ Racket 侧绑定 + iovec marshalling (核心难点)**

Racket 侧逻辑已用 ffi/unsafe 对独立 proto dylib **端到端验证** (2026-08-07,
scratchpad/{proto_writev.c,proto-driver.rkt})——**PASS**:
- iovec 双数组构建 (bases[] uintptr + lens[] intptr, malloc 'atomic);
- foreign-procedure 签名 `(_int _pointer _pointer _intptr -> _intptr)`;
- **字节粒度部分写 resume 正确** (300 slice × 1KB = 300KB 穿 ~64KB 管道,
  多轮部分写 + 跨 slice 推进, 读回 300KB 字节精确一致)。
- resume 算法 (已验证): 已写 n 字节 → 跳过累计 len ≤ n 的整 slice, 对跨越
  n 的 slice 推进 `base += n', len -= n'`。C 原语返回字节数, resume 在此层。

CS 后端集成的**唯一剩余风险 = zero-copy byte-string pinning** (验证时用
immobile malloc 拷贝作安全替身):
- `rktio.rktl` 由 `rktio/parse.rkt` 生成; iovec 数组参数最好**绕过**该宏,
  在 io.sls 手写 foreign-procedure (同 io.sls:146 的 `foreign-procedure`
  直用), 因类型系统难表达 array-of-struct。
- CS byte-string 可移动 (GC 会挪)。**已定位精确原语** (rumble/foreign.ss):
  `make-ftype-scheme-object-pointer bstr` 得指向 bytevector 数据的 ftype
  指针 (Chez 处理头偏移), `lock-object`/`unlock-object` (foreign.ss:1319-23)
  钉住底层对象。配方: 原子区内逐 slice `lock-object` + 取
  `ftype-pointer-address (make-ftype-scheme-object-pointer bstr)` + start
  偏移 → 写进 foreign-alloc 的 iovec 数组 → 调 rktio_writev (非 collect-safe
  → 调用期不 GC) → `unlock-object` 全部 → foreign-free。
- 注: 单缓冲 `(*ref char)` 之所以安全, 是 Chez foreign-procedure 对
  bytevector 实参在非 collect-safe 调用期自动钉住 (io.sls let-unwrappers
  对 `(*ref char)` 不做转换, 直接交 foreign-procedure); iovec 数组够不到
  该自动机制, 故须手动 lock-object。

**③ 落地状态 (2026-08-07)**: 已写入树、随 `make cs` 编译验证:
- `rktio.rktl`/`.inc`/`.def` 由 parse.rkt 重生成 (parse.rkt **自动**处理
  `rktio_iovec_t` struct + `(*ref rktio_iovec_t)` → convert-type 映射 u8*)。
- `racket/src/cs/io.sls`: 加 Chez 原语 import (lock-object/unlock-object/
  make-ftype-scheme-object-pointer/ftype-pointer-address/
  bytevector-u64-native-set!) + **`rktio_writev_pinned` helper** (原子区
  逐 slice lock-object → 取 `ftype-pointer-address(make-ftype-scheme-object-
  pointer bstr)+start` → 写 iovec bytevector {addr,len} → 调 rktio_writev
  (非 collect-safe, 调用期不 GC) → unlock 全部) + 注册进 |#%rktio-instance|。
- `racket/src/io/host/rktio.rkt`: 加 `(define-function () #f
  rktio_writev_pinned)` 供 io 层调用。
- **BC 后端待补** (bootstrap-rktio.rkt 需并行 ffi/unsafe 实现; BC 维护模式)。

**④ 端口原语 + 公开 API (2026-08-07 落地, 随第二次 make cs 验证)**
- `fd-port.rkt`: fd-output-port 加 `write-bytes-list-fully` 方法 (锁已持有,
  同 flush-buffer-fully 协议: slow-mode! → flush-buffer-fully 保序 →
  rktio_writev_pinned 各 slice + **字节粒度 resume** (`advance-slices`) +
  would-block 时 port-unlock→sync evt→port-lock 重试; error 时自 port-unlock
  再 raise 因 with-lock 用 begin0 非 dynamic-wind escape 不 unlock)。
  公开 `fd-output-port-write-bytes-list!` 用 `with-lock` 包裹。
- `bytes-output.rkt`: 公开 `write-bytes*` (fd-output-port → 矢量零拷贝路径,
  其它端口 → 逐 slice do-write-bytes 回退); 经 port/main.rkt 导出。
- 关键构建认识 (踩坑记录):
  1. io 层 (racket/src/io) 与低层 io.sls (rktio FFI 实例) 是**两个不同编译
     产物**: io.sls→io.so; io 层→expander 展开→`io/compiled/io.rktl`→schemify
     →`cs/schemified/io.scm`→编译进 racket.so。
  2. **`make cs` (zuo in-place) 不重生成 io.rktl** (io.rktl 的 zuo 依赖是
     expander/rktio.rktl/rktcrypto.rktl, **不含 io 源**)——改 io 源后 io.rktl
     陈旧、改动 inert。**必须 `zuo . derived`** (main.zuo:846 调
     `build-one cs/main.zuo schemified`; 或 `make derived`) 才重展开 io 源
     →io.rktl→io.scm。删掉 io.rktl 强制其重建。
  3. 新增公开名 (write-bytes*) 需三处 provide + **一处硬编码原语声明**:
     - io/port/bytes-output.rkt 加 provide → port/main.rkt → io/main.rkt
       (使其进 io.scm 导出);
     - **`racket/src/cs/primitive/kernel.ss` 加
       `[write-bytes* (known-procedure/single-valued 6)]`** (6=arity 1-2 参数,
       同 write-byte)——这是 CS 后端 **#%kernel 原语的硬编码 allow-list**,
       io.scm 只提供实现, 此表声明"哪些名字暴露为 kernel 原语 + 优化元数据"。
       **漏这一步则 io.scm 导出了 write-bytes* 但用户级仍 unbound** (实测:
       write-bytes-avail* 在此表→可用, write-bytes* 不在→unbound, 三轮
       derived 重建都不解决, 直到加入此表)。
     - racket/base 经 pre-base `(all-from-except '#%kernel ...)` 全量 re-export
       #%kernel, 故加入 kernel.ss 后自动 surface。BC 后端另有
       `bc/src/portfun.c` 一套 (legacy, 未改)。
     - kernel.ss 改动经 `derived` 重生成 known.scm + 重建 racket.so 生效。
- **已知精修项 (offset 记账)**: 方法直接 rktio_writev_pinned 绕过正常
  write-some-bytes 路径, 故端口 offset/position 计数器未随矢量写更新
  (`file-position` 会少算矢量写字节)。文件**内容正确** (字节到 fd, 与
  offset 无关), 仅位置计数缺失。修法: 写完 total 后 `increment-offset!`
  (slow-mode! 后 direct-bstr=#f 会生效; count.rkt); 开 port-count-lines!
  时逐 slice `port-count!` 做行列计数。本轮先验证内容正确性 (证 pinning),
  offset 记账下轮补 (避免在未验证细节上改动浪费构建)。
- **tstring 接入待做**: `(display t"...")` / 融合输出渲染 slice 为 bytes
  后交 write-bytes*。收益窗口窄 (仅多-中 slice, 见 PERF-NOTES), 作专用路径。

## 实测性能画像 (2026-08-07, 建成后 racket/base write-bytes* 实测)

写 /dev/null fd-port, 各 15 轮取最优, 三路对比 (writev* / N 次 write-bytes /
一次 bytes-append 拼接后 write-bytes):

| 数据形态 | writev* | N-write | concat | 最快 |
|---------|--------:|--------:|-------:|:----:|
| 多小 300×1KB (**t-string 型**) | 226ms | 132ms | **39ms** | concat |
| 少大 8×256KB | **1.81ms** | 16.9ms | 498ms | **writev*** |
| 极少极大 4×2MB | **0.39ms** | 2.0ms | 519ms | **writev*** |

**结论: writev* 的甜点是"少量大 slice"**——8×256KB 比 concat 快 **275×**、
4×2MB 快 **1330×** (concat 要分配+拷贝一个巨缓冲, writev 完全避开)。**多小
slice 惨败** (300 次 lock-object pin 开销主导, concat 快 5.8×)。**小数据**
(60B-500B) writev* 也慢 10× (foreign 调用+pin 固定开销)。

即: write-bytes* 是**"输出几个大 byte-string 而不想拼接"** 的正确原语
(序列化多个大 buffer、大分块响应、sendfile 式); 对**多小 slice 一律用
concat/N-write**。**对 t-string (许多小段+小插值) writev 是错误工具**——
见 pkgs/racket-tstring/PERF-NOTES.md, f"" 的 string-append 在那里最优。

## write-bytes* = 自适应 dispatch (2026-08-07 定稿)

鉴于三路各有领地 (concat 赢小/中总量, writev 赢少量大 slice, N-write 居中),
`write-bytes*` 不做"纯矢量", 而是**自适应最优多写**——只读 `#slices` 与
`total` (皆 O(#slices) 且 total 本就要算返回值), 便宜地选策略:
- **少 slice (≤16) 且 total ≥ 64KB → 矢量 (rktio_writev)**: 甜点区, 躲开大分配;
- **total ≤ 256KB → concat**: 一次分配一次写胜 N 次分派;
- **否则 (多 slice + 大 total) → 逐 slice 直写**: 既躲大分配又躲 per-slice pin。
非 fd 端口一律顺序 do-write-bytes。阈值保守 (只在 writev 明确甜点才选它),
误判代价低 (边界外 concat/N-write 本就接近)。

阈值调优认识 (实测校正): **非 writev 分支里 concat 几乎总赢**——多 slice 时
单次分配胜多次分派、小总量时分配便宜; N-write 只在"多 slice + *巨*总量"
(单次大分配比 N 次直写更亏) 才可能赢。故 concat-max-total 设**高** (16MB
安全阀), 不作常规阈值 (初版误设 256KB 令 300KB 多小落 N-write, 比 concat
慢 3.5×, 实测校正)。三分支等价于: writev 甜点 → 否则 concat → 仅巨型 N-write。

**设计原则: 自适应投机分支只在"运行时形态真会变"时划算**。通用
write-bytes* 调用者形态未知 → 自适应值得 (令其"永不比替代慢, 甜点区快
275-1330×")。**t-string 形态编译期已知 (恒为许多小段) → 静态 f""
(string-append) 即可, 不需分支**——为不变的形态加运行时分支是白付成本。

## 收益边界 (诚实标注)

- 缓冲端口已合并 syscall (N 次 write 攒进端口缓冲一次 flush); writev 的净赢
  是**省掉 N 次 Racket 端口层分派 + 大输出时省整串分配**, 不是省 syscall。
- 小而频繁的写 (日志行): string-append / 缓冲端口已近最优, writev 若每次强制
  一次 gather-syscall 反而更差。**大的一次性写 (报告/HTML/SQL 落文件)** 才是
  writev 的甜点。
- 故: 值得作为**大输出构建器的专用路径**提供, 不改变小输出的默认 (string-append)。
