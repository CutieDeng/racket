# Racket 启动调用链与优化台账（2026-10-26，fasl2/pb 线回退后，HEAD 121e54ba79）

## 一、回退后失效/移除的优化

| 原提交 | 内容 | 曾测收益 | 现状 |
|---|---|---|---|
| 9e2619e657 | Chez fasl 闭包序列化（fasl 类型 47） | 无（能力项） | 移除；`(fasl-write 闭包)` 回到上游报错 |
| 9646b2b820 | 运行期 fasl 写活代码对象（`s_fasl_code_info`） | 无 | 移除 |
| 0e9cb2fefd | `RACKET_RETAIN_STATIC_RELOC` 开关 | 无 | 移除 |
| a9bc338a81 | fasl2 externals 表、seg4 装载钩子（`PLT_SEG4_BOOT`/`PLT_SEG4`、main.zuo seg4）、rumble `set-eq-hash-code!` | seg4 实验 11/11 但未进默认路径 | 移除 |
| 7999c9267b / 973bb16029 | externals 的 rtd 支持、边界检查 | 无 | 移除 |
| 5cca280f07 | vfasl 镜像 eq-hashtable（2 个 singleton） | 无 | 移除 |
| e30820c986（B） | `PLT_LINKLET_VFASL` .zo 走 vfasl 镜像 | 10-19 测 faslin-code 22.5→16.5、端到端 −9～−10（默认关） | 移除；10-25 已发现门控缺陷（转换器输出依赖进程状态） |
| cc04c8678e 等 | experiments/seg4 生成器与脚本（65 文件） | — | 移除 |
| 本地 pb 种子 | 09-08 孤儿提交 + 10-20 未提交重生成 + lan-11 私有 pb.git | — | boot/pb 复位上游 v9.3（d8c788e）；备份在 scratchpad/pb-custom-seed |

随之作废的方案：Q1 第四段全态镜像、Q3 预声明镜像（依赖 B + eq-hashtable 镜像 + externals）、"启动镜像零 GC"路线。设计文档保留：repl-startup-fasl2-spec.md、repl-startup-forward-design.md、repl-startup-4th-segment-handoff.md、repl-startup-preinstantiate-plan.md。

## 二、仍在树上、已验证的优化（正向分析时视为已完成）

| 层 | 提交 | 内容 | 实测 |
|---|---|---|---|
| boot 装载 | a77d3fe584 / 5fd0bd54a5 / 9830507ee4 | boot 文件 mmap 装载、reloc 留在映射、sweep 局部性游标 | vfasl 21→16 ms |
| boot 装载 | 3f71a16b71…8b8138a24e | arm64 字面量池→GOT vspace、死 quad 截断、零拷贝 opt-in（`PLT_VFASL_CODE_ZC`） | relink 2.5→0.9、boot 文件 −2.35 MB、端到端打平 |
| boot 装载 | 6777c6c944（H1） | 符号表按镜像预扩容 + `S_intern4` 先比哈希 | intern-syms 1.5→1.0，ttp 不可见 |
| exec | 9b740f14e7（H2） | rktio CoreFoundation 延迟 dlopen，去 `-framework` | 空程序链接 CF 多 1.6 ms；`racket -n` 29.3→27.6（load 12） |
| GC | 75a49a38eb（G1） | 启动 GC 窗口：窗口内只收 gen0，关窗一次提升 | ttp 230→214 |
| GC/fasl | 5c4aa3c56d（C2）→ f419b6512a（A） | fasl 产物出生在目标代（1→static），年轻引用根表 | 关窗 20.6→13.3，ttp −6.1 |
| .zo 读 | 0434cdb553 / eae5477bf7（C1） | varint 单字节快路径、解码时算符号哈希 | 读取器暖缓存 −24%；lan-11 C1+S3 −6.7 |
| 序列化 | a995188afa / b34727f220（S3） | expander 字节流编码、srcloc 源共享 | decl 5.5→3.6、stx-data 3.2→1.8、literals 667→191 KB |
| 声明 | D1 / D2（a67868d658） / R1 | stx-data 惰性、provides 批量建表、code 切片格式 | R1 −4 ms/−6.6 MB |
| resolver | 8f36997acf / 2718d90141（I1/I2） | module-cache 键改 bytes、links 戳改 stat 键 | resolver 31.9→25.2 |
| 交互层 | c12f2976d0（P1）+ df1fbd8d92 | expeditor 取 `racket-lexer/status` 变量导出，免 phase-1 visit；expeditor-lib 内置 | ttp −14.5 |
| 交互层 | a0968452a5（G）+ 146fdb0a4b | xrepl saved-value 名字 `namespace-require` 不 eval；xrepl-lib/parser-tools-lib 内置 | ttp −2.2 |
| 量具 | 75ce6ff1ff / ef6bf14ea6 / 498d7789ad | `PLT_VFASL_TIMES`、`PLT_VFASL_STATS`、expander instantiate 细分区域 | — |
| 量具（分支） | a187463a0c（feat/repl-startup-stamps，未并入） | `PLT_BOOT_STAMPS` 阶段打点 | — |

## 三、默认 REPL 启动调用链（实现位置 → 当前成本，本机 load 4）

ttp 默认 152 / `-q -i` 98 / `-n -q -i` 38。CPU 列来自 `PLT_BOOT_STAMPS` 7 次中位；区域时间来自 `PLT_LINKLET_TIMES` / `PLT_EXPANDER_TIMES`。

### S0 exec → C 入口（2 ms）
- dyld 装载 bin/racket（52 KB 启动器）+ Racket.framework（2.3 MB）+ libSystem/iconv/ncurses。CF 已不再链接。
- 入口：`racket/src/cs/c/boot.c:155 racket_boot`。

### S1 Chez 内核与三段 boot（16 ms CPU；vfasl 相位 ≈12）
- `boot.c:169 Sscheme_init` → `Sregister_boot_file_*`（petite 6.9 MB / scheme 4.9 MB / racket 35 MB，`boot.c:203-235`）→ `Sbuild_heap`（`ChezScheme/c/scheme.c`，mmap 装载：`scheme.c:947-951` 设 `S_vfasl_mapping_*`）。
- 每段：`vfasl.c:365 S_vfasl`：room+copy 5.9（50 MB 拷入 MAP_JIT/匿名页）| ptr-sweep 2.8 | intern-syms 1.0（≈45k 符号）| relink-code 1.3 | rtds/closures/symrefs <1。
- 非 vfasl 部分 ≈3.5：petite/scheme 顶层初始化 + racket.so 的 rumble 前顶层。
- 接口：三段 boot 的内容由 build（to-vfasl.ss / strip.ss）决定；装载器只重定位。**改动约束：镜像格式/常量须对上游 pb 种子守卫。**

### S2 Racket CS 库层体（≈1 ms）
- racket.so 顶层按序：rumble → thread → io → regexp → schemify → linklet → expander（`racket/src/cs/*.sls`）。io 0.2、regexp 0.6，其余 ≤0.1。
- expander 层末尾 `(boot)`（`main.sps:838`，expander/boot/handler.rkt `boot`：装 resolver/load handler/reader guard）与 `expander-place-init!`（`main.sps:936`）。

### S3 main.sps（3 ms）
- 参数解析（flags 1–2 ms，`main.sps:500-600` 区）、`config.rktd`、集合路径/links（`main.sps:848-855` → `find-library-collection-links`/`-paths`，expander/eval/collection.rkt）、place 初始化。
- 开启 GC 窗口：`main.sps:1014 set-startup-gc-mode!`（rumble/memory.ss；默认仅文本 REPL，`PLT_STARTUP_GC_MODE`）。

### S4 init library：`racket/init`（61 ms CPU，含 GC 9）
- `main.sps:517 (namespace-require+ init-library)`（`main.sps:285`）。
- 每个模块的路径：
  1. **resolver**（expander/boot/handler.rkt:158 `standard-module-name-resolver`；集合查找 eval/collection.rkt:374 `find-col-file`）—— 区域 24 ms / 6132 次；symbol 命中 0.12 µs、未命中 11 µs（2 个 links 文件各 stat+exists + 目录探测）；string 命中 0.2–0.3 µs。
  2. **load handler**（handler.rkt:29 `default-load/use-compiled` → boot/load-handler.rkt:21 `default-load-handler`）：.zo 时间戳比较（`file-or-directory-modify-seconds` 539 次）、打开读取（290 文件）。
  3. **read**（区域 10.5；linklet 层 read 37–42，其中 read-bundle 5–7）：`linklet.sls:425 eval-from-bytevector` → Chez `fasl-read`（`ChezScheme/c/fasl.c`，C1 的读取器）；expander 侧 `compile/serialize.rkt` 字节流解码（S3）。
  4. **declare**（区域 module 11 / 379 次；requires 5）：eval/module.rkt:39 `eval-module` → namespace/module.rkt:226 `declare-module!`；decl/data/stx-data linklet（D1 惰性、D2 批表）。faslin-code 27–30 = 代码对象物化（R1 切片，按需）。
  5. **instantiate**（区域 41，body 36 / 630 次）：namespace/module.rkt:423 `namespace-module-instantiate!` → :514 `run-module-instance!` → `linklet.sls:907 eval-linklet` / instantiate。模块体本身 14.3 ms（169 模块，最大 0.79 class-internal）；phase-1 visit 20（C(a) 9.7 + C(b) 10.6）。
- 模块账本：169 模块，declare 26（GC 关 40）、体 14.3、visit 20。前几名 declare：racket/private/local.rkt 3.3、init.rkt 1.4、main.rkt 1.0、unit-core 0.7；体：class-internal 0.79、set-types 0.70、dict 0.70、contract/region 0.68、port 0.65。

### S5 REPL init 文件：`racket/interactive`（44 ms CPU，含 GC 9）
- `main.sps:1041 (when repl-init? …)` → `racket/collects/racket/interactive.rkt`：`(dynamic-require 'xrepl #f)`、`toplevel-prefix`、用户 init-file。
- **xrepl**（pkgs/xrepl-lib/xrepl/main.rkt → xrepl.rkt）：67 模块 declare 10.8、体 12.9（main.rkt 体 7.4 = 16 个顶层 require）、visit 5.8；`xrepl.rkt:1875 setup-xrepl-environment` 装 eval/prompt-read/display handler；首个提示符前 `initialize-namespace`（11 个 `namespace-require` + 1 个 eval，G 后 ≈1.5 ms）。
- **expeditor**（pkgs/expeditor-lib/main.rkt）：78 模块 declare 12、体 4.6、visit 6.6；`main.rkt:1494 default-racket-lexer` 取 `racket-lexer/status`（syntax-color/racket-lexer，体 2.7–3.1，其中 ≈25% 是 lexer-contract 的 option-contract tester）；parser-tools/lex 链、racket-tabify。
- 其后 `install-command-line-interaction-reader!`（`main.sps:296`）。

### S6 关窗（15 ms，全 GC）
- 进入 REPL 前 rumble/memory.ss 关闭启动窗口：一次 `(collect … 'static)` 把启动期存活对象全部提升到 static（`PLT_STARTUP_GC_FINISH`，默认 static）。A 之后 fasl 产物已在 static，剩余 13–15 ms 是声明期物化的语法对象/模块实例/命名空间表。

### S7 提示符与循环
- `read-eval-print-loop`（expander eval 层）→ `current-prompt-read`（xrepl `make-xrepl-reader` :1626 → expeditor `expeditor-read`）→ 首次输入：展开（phase-1 visit 已在 S4/S5 做完）、Chez `compile`、eval。tty 建立 ≈3 ms。

### 分配/GC 画像
- 窗口内 GC：init 9 + 交互 9 = 18（gen0 only）；关窗 15。`PLT_EXPANDER_TIMES` eval 行 GC 列 ≈16–17。
- RSS：`racket -n` 127 MB（boot 堆 50 + 映射 54 + 其它）。

## 四、量具
- `experiments/startup/`：boot-stamps.py（需 stamps 分支或工作树副本）、linklet-times.py、expander-times.py、ttp.py / ab-swap.py / ab-gen.py（配对交错）、loadtrace.rkt（模块账本，GC 关：`PLTDISABLEGC=1`）、resolver-hook.rkt、guard-count.rkt、zo-linklets.rkt、tracehook.rkt + thgaps.py。
- scratchpad：pty-repl.py（真实 tty REPL 回归）、lexer-prof.rkt（任意模块体采样）、lexer-cost.rkt（declare/deps/body 分解）、resolver-bench*.rkt、gen7-tests.sh。
- 陷阱：`-e` 模式默认不开 GC 窗口；钩子装在 `-I` 之后看不到 racket/base 的装载；loadtrace GC 开时把停顿记到单模块；Apple Silicon 短进程相位双峰，只信交错中位；本机 Spotlight 索引时 ttp 作废。
