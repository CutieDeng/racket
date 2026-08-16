# GNU 输入前端简明说明

本文说明 `asmp` 的 GNU 风格输入前端。它不是完整替代 GNU as 的前端，而是一个面向 AArch64 函数体的传统汇编语法入口：GNU 文本会被解析成和 S-expression 前端相同的 AST，然后进入同一套指令验证、CFG、寄存器分配、标签验证和代码生成管线。

## 启动方式

```bash
# 显式使用 GNU 输入语法
racket cli/as.rkt --gnu-input -o out.s input.asm

# 根据扩展名自动识别 .s/.asm 为 GNU 输入
racket cli/as.rkt --input-syntax auto -o out.s input.asm

# GNU 输入，Apple/Mach-O 输出
racket cli/as.rkt --gnu-input --apple -o out.s input.asm
```

`--gnu` / `--apple` 控制输出语法；`--gnu-input` / `--input-syntax` 控制输入语法。两者是不同概念。

如果在 macOS 本机汇编时看到下面这类错误：

```text
error: unexpected token in '.section' directive
.section .rodata
                ^
```

通常说明把 GNU/ELF 输出喂给了 Apple/Mach-O assembler。修正方式是二选一：

```bash
# 目标是 macOS/Mach-O：生成 Apple 输出
racket cli/as.rkt --gnu-input --apple -o out.s input.asm
clang -target arm64-apple-macos11 -c out.s -o out.o

# 目标是 Linux/ELF：保留 GNU 输出，并使用 AArch64 Linux 工具链
racket cli/as.rkt --gnu-input --gnu -o out.s input.asm
clang -target aarch64-linux-gnu -c out.s -o out.o
```

## 函数与标签

支持传统函数标记：

```asm
.text
.globl add1
.type add1, %function
add1:
  add x0, x0, #1
  ret
.size add1, .-add1
```

也支持项目扩展的托管函数声明，适合使用虚拟寄存器和寄存器分配：

```asm
.asmp.function add1 abi=aapcs64 export
add1:
  mov x.tmp, x0
  add x0, x.tmp, #1
  ret
.asmp.end_function
```

新的推荐写法是 `.function ... .end`。它不需要 `abi=...`，`export` 可选；签名描述托管调用接口，`.end` 只结束结构，不自动生成 `ret`：

```asm
.function math.add-one export (
  inout: x.value
)
entry:
  add x.value, x.value, #1
  ret
.end
```

`export` 函数默认记录 public ABI profile `c-aapcs64`；如果边界不是默认 C/AAPCS64 形态，可以显式写：

```asm
.function crypto.deflate.raw-fixed export profile=apple-c-arm64 ()
entry:
  ret
.end
```

当前 MVP 会把 `profile=<name>` 归一化成 CFG metadata `public-abi-profile`，并把该函数标记为 public ABI root。已知 profile 包括 `c-aapcs64`、`apple-c-arm64`、`linux-syscall`、`kernel-aarch64`、`jit-private`、`project-abi`。`profile=...` 必须和 `export` 一起使用。CFG stage 已经会检查显式 C-like public profile 上明显错误的 private ABI，例如 `export profile=c-aapcs64 abi=fast20`。`c-aapcs64` / `apple-c-arm64` 的托管签名 lowering 会把 `in` / `inout` 映射到参数寄存器，把单路 `out` / `inout` 映射到返回寄存器。函数入口输入现在用 direct live-in move 加内部干涉约束表示，避免全量入口 snapshot；这些约束只给 regalloc 消费，不输出到最终汇编。非 C-like profile 的完整 checker 和 profile-specific lowering 仍是后续工作。

`export` 表示函数必须作为独立符号输出，并默认写 `.globl`。库边界还可以单独控制链接可见性和头文件暴露：

```asm
.function deflate_fixed_chain_aarch64_asm export profile=c-aapcs64 visibility=hidden no-header ()
entry:
  ret
.end
```

`visibility=hidden` 在 GNU 输出中生成 `.hidden symbol`，在 Apple 输出中生成 `.private_extern _symbol`；`visibility=local` 保留函数体但不写 `.globl`。`header` / `no-header` 只影响 `--public-c-header`，不影响函数是否输出或能否被同一构建图里的 `.call` / `bl` 引用。为兼容旧代码，未显式写 `header` / `no-header` 的 C-like public root 仍会参与 header 生成；内部 raw 内核应显式写 `no-header`。

`weak` 或 `binding=weak` 可以把 exported 函数作为链接期默认实现输出。GNU 输出 `.weak symbol`；Apple/Mach-O 输出 `.weak_definition _symbol`、`.globl _symbol`，并在模块末尾输出 `.subsections_via_symbols`，这样单独链接时 C 对象能解析该符号，和强定义一起链接时强定义可以覆盖它。这个能力适合 deflate 这类库的 build-time default entry：实验版本可以提供 weak `asmp_deflate_raw_*`，最终构建或基准对比中再由强符号选择真正默认实现。

`c-aapcs64`、`apple-c-arm64`、`linux-syscall`、`kernel-aarch64` 目前只允许 ordinary entry ABI：未写 `abi`、`abi=aapcs64`、`abi=arm64`、`abi=leaf`、`abi=naked`。`jit-private` 和 `project-abi` 则必须显式写 `abi=<name>`，因为外部调用者要知道它承诺的是哪套项目私有约定：

```asm
.function engine.plugin.entry export profile=project-abi abi=engine-fast ()
entry:
  ret
.end
```

函数自身不需要为了使用虚拟寄存器而声明 ABI；未声明时会使用内建 AArch64 分配策略。内部优化 ABI 仍优先使用 `.call abi=<name>` 或 IPA call-convention clone 机制表达，不应该混同 public profile。

构建时可以额外导出 public ABI manifest：

```bash
racket cli/as.rkt --gnu-input --public-abi-manifest public-abi.rktd input.asm
```

manifest 是可读写的 Racket datum，记录所有 exported public root 的 concrete symbol、logical name、profile、link binding、显式 `abi` 和源码位置。后续 header/manifest 生成、dispatcher、debug/profile 归并都应优先消费这个边界清单，而不是扫描最终汇编文本。

对于简单 C-like public root，也可以直接生成 C header：

```bash
racket cli/as.rkt --gnu-input --public-c-header asmp_public.h input.asm
```

当前 header MVP 只为 `c-aapcs64` / `apple-c-arm64`、未写 `no-header`、且带非空托管 `.function` 签名的导出函数生成原型。`in` 参数成为 C value 参数，单个 `out` 或 `inout` 成为返回值；多输出、SVE/predicate、无托管签名的低层入口会被跳过并写入注释。显式 `no-header` 的入口会被完全省略，不在头文件注释里暴露内部符号名。符号名如果不是合法 C identifier，会生成 sanitised C 名并使用 `__asm__("real.symbol")` 绑定真实汇编符号。

外部调用可以单独声明 call ABI：

```asm
.asmp.extern puts abi=aapcs64
```

如果外部调用没有单独 ABI，未知调用会按内建 AAPCS64 scratch 集保守处理。`--default-abi <name>` 仍可作为兼容选项，影响未指定 ABI 的未知/动态调用以及旧式函数 ABI 选择。

## 内联模板

`.function` 定义一个带签名的代码块；调用点用 `.inline` 时展开函数体，用 `.call` 时生成 `bl target`。模板体应该优先使用虚拟寄存器表达输入、输出和状态；没有写进签名的虚拟寄存器会被当作 inline 实例内部临时量，每次展开时自动改名，不需要在调用点手动绑定。旧 `.inline-function` 仍可解析为兼容写法，但不再是推荐语法。

```asm
.function flush8 (inout: x.out, x.bits, w.count)
entry:
loop:
  cmp w.count, #8
  b.lt done
  strb w.bits, [x.out]
  add x.out, x.out, #1
  ubfm x.bits, x.bits, #8, #63
  sub w.count, w.count, #8
  b loop
done:
  .return
.end

.function caller export ()
entry:
  mov x.out, x0
  mov x.bits, #0
  mov w.count, #0
  .inline flush8 (x.out=x.out, x.bits=x.bits, w.count=w.count)
  ret
.end
```

`.inline` 调用点只允许具名绑定：每个实参都必须写成 `formal=actual`，不支持位置参数，也不会因为名字相同而隐式传入。绑定的左侧必须是 callee 签名里声明过的虚拟寄存器形参，右侧是当前调用点中的寄存器；少传、多传、重复传都会报错。`in` / `out` / `inout` 目前用于声明接口和检查绑定集合，调用语法本身一致。

如果一个未 `export` 的 `.function` 只作为 `.inline` 目标使用，且展开后没有任何 `bl` 引用它，CLI 输出阶段会省掉它的 standalone 函数体。只要同一个函数被 `.call` 或原始 `bl` 引用，或者带有 `export`，它仍会作为普通函数输出。

GPR 绑定按同一个虚拟名贯通 `x.` / `w.` 视图，例如把 `x.bits=x.acc` 绑定后，模板中的 `w.bits` 会落到同一个物理寄存器的 32-bit 视图。`.clobber flags` 这类声明目前只作为语法预留入口（解析时**告警并忽略**），后续可以接入更严格的标志/寄存器副作用检查。

## 托管函数调用

`.call` 调用同一次 asmp 构建图里能找到的 `.function` 定义，不需要 `.extern-function` 签名声明。调用点只允许 named binding，左侧是 callee 签名里的形参，右侧是 caller 当前作用域里的寄存器：

```asm
.function lib.hash.fast-v1 (
  in: x.src, x.pos,
  out: w.hash
)
entry:
  add w.hash, w.src, w.pos
  ret
.end

.function app.main export (
  in: x.buf,
  out: w.result
)
entry:
  mov x.i, #7
  .call lib.hash.fast-v1 (
    x.src=x.buf,
    x.pos=x.i,
    w.hash=w.result
  )
  ret
.end
```

`.call` 会按固定托管调用约定降低为入参 move、`bl target`、出参 move。GPR、vector/FPR/SVE 和 predicate 参数分别按 ABI 的 `args` slot 计数：`x` / `w` 使用 GPR slot，`s` / `d` 使用 `fmov`，`v` / `q` 使用 128-bit 向量 `mov vN.16b, vM.16b`，`z` 使用 `orr zN.d, zM.d, zM.d` 做 bit-copy，`p` 使用 `mov pN.b, pM.b`。固定 FPR/NEON 和 SVE `z` 共享同一组 vector slot，predicate `p` 使用独立 slot。普通内部函数里，`out` / `inout` 在返回后传回同一个托管 slot；C-like public root 里，输出走 ABI `return` slot。入参和出参搬运按 parallel-copy 语义降低：无冲突时直接搬运，交叉覆盖或环才插入内部临时；同时 lowering 会给同一个 call bundle 的其它 ABI slot 加内部干涉约束，避免虚拟寄存器分配后重新形成隐藏 swap。找不到 `.function` 定义、少传、多传、重复绑定或 slot 数量超过 ABI 配置都会报错。当前 MVP 不做 stack fallback；寄存器组和 lane/index 形参仍是下一阶段能力。直接调用 C/libc/未知外部符号仍使用原始 `bl symbol` 和物理 ABI 寄存器。

命令行可以传入多个输入文件，asmp 会先合并构建图再解析 `.call` 目标：

```bash
racket cli/as.rkt --gnu-input -o out.s caller.asm callee.asm
```

托管函数名支持 dot namespace 和 `-` / `$`：

```asm
.function crypto.deflate.fast-v1 export ()
  ret
.end
```

函数名是可链接符号；普通 `entry:` / `loop:` / `done:` label 仍然只在当前函数内可见，后端会输出成函数作用域局部标签。不同函数可以重复使用 `entry:`，同一个函数内仍不应该重复定义同名 label。带 `-` 的函数符号会在输出汇编中按需 quote，以兼容 GNU/Apple assembler。

IR 中会同时保留 logical function identity 和 concrete version identity。源代码里的 `.function crypto.deflate.main` 会得到 canonical version；后续内部 calling convention 或 caller-specialization clone 会使用新的 private linkage symbol，例如 `crypto.deflate.main$asmp.cc1`，但 metadata 仍指向 logical function `crypto.deflate.main`，并记录 version id、clone reason、specialization key 和 debug origin。clone 默认清除 `export` / `public-abi-profile` 等 public boundary metadata，因此不会把内部优化版本误暴露成外部接口。诊断、debug 和 profile 归并应默认回到 logical function，必要时再显示具体 clone version。

手写优化实现也可以挂到同一个 logical function family 下，而不是伪装成优化器自动生成的代码。例如 NEON/SVE 版本可以写成独立函数体，并用 `variant-of` 指向标量逻辑函数：

```asm
.function asmp.deflate.fixed.neon-extend variant-of=asmp.deflate.fixed version=neon-extend feature=neon (
  in:  x.dst, x.src,
  out: w.status
)
entry:
  ret
.end
```

这里 emitted linkage symbol 仍然是 `asmp.deflate.fixed.neon-extend`，但 IR 里的 logical name 是 `asmp.deflate.fixed`，version id 是 `neon-extend`，version kind 是 `source-variant`，clone reason 是 `handwritten`。因此后续 dispatcher、IPA 选择、debug/profile 聚合可以把它和标量实现视为同一族。`feature=neon` 只是当前的元数据，不会让编译器自动生成 NEON 指令；NEON 函数体仍由用户手写。

当前已经有 CFG 级 clone MVP：`semantic/function-clone.rkt` 可以为一个 `.function` 插入新的 versioned linkage symbol，并把指定 caller 里的直接 `bl target` 或尚未 lower 的 `.call target (...)` 改指向 clone。clone group 记录在 CFG metadata 中，函数自身的 `function-version` 是权威身份来源。clone 即使来自 `export` public root，也会保持 private：canonical public entry 继续保留 `export` / `public-abi-profile`，clone 会清除 public boundary metadata，并额外记录 `public-abi-origin-profile`、`public-abi-origin-header?` 和 `public-abi-origin-visibility` 以便后续 debug/profile/dispatch 归并。这个能力目前是 IPA/ABI 自动选择前的机制层；完整策略选择、clone 数量限制和 debug/profile 归并仍是后续工作。

在此基础上，`semantic/ipa-callconv.rkt` 提供了 IPA call-convention clone selector。策略层可以显式给出 `(caller, callee, abi)` selection；也可以调用 `plan-callconv-selections`，让 planner 在候选 ABI 中按 managed `.call` 的 caller-side move 数估算收益，自动产出 selection。selector 会验证目标确实对应一个尚未 lower 的 managed `.call` 边，clone callee，给 clone 写入新的 `abi` metadata，并只重写被选中的 caller。这个 pass 必须运行在 `build-cfg` 之后、`expand-inline-cfg` 之前，因为 `.call` lowering 会读取目标函数的 `abi` 来决定参数 slot。自动 planner 会把 header-visible public root 当作 ABI barrier，不自动为它选择内部 calling convention；显式 `.call abi=...` hint 仍然可以为某个调用点实例化 clone。`visibility=hidden no-header` 的 exported raw/internal root 不算 header-visible barrier，因此可以被自动 planner 当作内部实现候选。当前 planner 不处理原始 `bl` 的 ABI 语义，不看寄存器压力、spill、profile 或递归/SCC 上的 clone 策略；这些留给后续 policy 层。

CLI 中可以显式给出候选 ABI 来启用 planner：

```bash
racket cli/as.rkt --gnu-input --ipa-callconv-candidates fast20,fast21 input.asm
```

`--ipa-callconv-min-savings N` 可以调整最小 move 节省阈值；`--ipa-callconv-report` 会输出 planner 选中的 caller/callee/ABI 和 move-cost 对比。

用户也可以直接在 `.call` 上引导某个调用边使用指定 ABI 实例化 callee：

```asm
.call math.inc abi=fast20 (
  x.value=x20
)
```

这个 hint 会生成一个使用 `fast20` 的 `math.inc` clone，并只把这一条 managed `.call` 改到 clone。同一个 caller 可以多次 `.call` 同一个 callee，并在不同调用点写不同的 `abi=` hint；源码 hint 的粒度是调用点。自动 planner 目前仍按 caller/callee 边估算和选择，如果某条边上出现源码 hint，CLI 会让源码 hint 优先，不再用自动 planner 覆盖这条边。

调用侧也可以按 source variant 选择手写优化实现，而不用直接写具体实现符号：

```asm
.function asmp.deflate.fixed.neon-extend variant-of=asmp.deflate.fixed version=neon-extend feature=neon (
  inout: x.state
)
entry:
  ret
.end

.function app.worker ()
entry:
  .call asmp.deflate.fixed variant=neon-extend (
    x.state=x20
  )
  .call asmp.deflate.fixed feature=neon (
    x.state=x20
  )
  ret
.end
```

`variant=` / `version=` 匹配被调用函数的 source-variant version id，`feature=` 匹配 `feature=<name>` metadata。匹配到唯一 variant 时，`.call` 会被降低到该具体实现符号；没有匹配或匹配到多个候选都会报错。这个选择机制不生成 NEON/SVE 代码，它只在手写 variant 已存在时选择它。

较大的 GNU `.asm` 阅读例子可以看 `example/013-deflate-fixed-fast.asm` 和 `example/019-deflate-fixed-chain.asm`：前者展示 fixed-Huffman bit writer 和 `.inline` helper 组织方式，后者在同一框架里加入有界 hash-chain match finder。

建议按下面的顺序阅读示例，逐步建立托管调用模型：

| 文件 | 重点 |
|------|------|
| `example/014-managed-call-basic.asm` | 最小 `.function/.call`，只展示 named binding 和局部 label |
| `example/015-managed-call-hello.asm` | 托管调用如何包住一个真实 C ABI `puts` 调用 |
| `example/016-managed-call-fpr-neon.asm` | `d` 标量和 `v` 向量参数如何占用 vector/FPR slot |
| `example/017-managed-call-sve-registers.asm` | SVE `z` 和 predicate `p` 的寄存器传参 MVP |
| `example/018-managed-call-abi-hint.asm` | 同一个 caller 里按调用点选择不同 ABI clone |

这几份示例也刻意暴露当前边界：`.call` 只查找同一次构建图里的 `.function`，所有绑定必须具名，FPR/NEON/SVE/predicate 目前只做寄存器 slot 传递，没有 stack fallback，也还不支持寄存器组、lane/index 形参。

## 寄存器

物理寄存器保持传统含义，不会被重新分配：

```asm
add x0, x1, x2
ldr w10, [x3, #16]
```

虚拟寄存器使用项目原有命名风格，会进入寄存器分配：

```asm
mov x.tmp, x0
add x.acc, x.tmp, #1
mov x0, x.acc
```

常用形式：

```asm
x.name      // 64-bit GPR virtual
w.name      // 32-bit GPR virtual
z.name.B    // SVE/vector virtual
p.mask/m    // predicate virtual
```

语义边界很重要：传统 GNU 输入里的 `x0`、`x19` 等是物理寄存器；只有 `x.name` / `w.name` / `z.name` 这种形式才是托管虚拟寄存器。

`fp` 和 `lr` 是 GNU 前端里的物理寄存器别名，分别等价于 `x29` 和 `x30`。

## 显式保存/恢复

不推荐在源代码里手写函数序言/尾声的具体 `stp` / `ldp` 序列。GNU 前端支持意图式 directive：

```asm
.asmp.function main abi=aapcs64 export
main:
  .save fp, lr
  mov fp, sp
  bl puts
  .restore fp, lr
  ret
.asmp.end_function
```

`.save` / `.restore` 会进入同一套 `save!` / `load!` 管线：源码显式声明保存哪些寄存器，后端自动分配栈槽，并选择 `stp` / `ldp`、pre-index / post-index、栈对齐和释放位置。`.load` 是 `.restore` 的别名；旧 `.asmp.save` / `.asmp.restore` / `.asmp.load` 仍可作为兼容写法解析。

## 栈指针写入纪律

源码中直接写 `sp` 默认会发出警告，推荐只通过 `.save` / `.restore` 等栈管理 directive 改变栈边界：

```bash
racket cli/as.rkt --gnu-input input.asm                 # 默认: 警告
racket cli/as.rkt --gnu-input --forbid-sp-writes input.asm
racket cli/as.rkt --gnu-input --allow-sp-writes input.asm
```

会被诊断的形式包括 `add/sub/mov sp, ...`，以及会更新基址的 `[sp, #imm]!` / `[sp], #imm` pre/post-index 寻址。读取 `sp` 是允许的，例如 `mov fp, sp`；固定偏移访问栈槽也是允许的，例如 `str x0, [sp, #16]`。

## 调试与展开信息

`-g` / `--debug-lines` 会在输出汇编中生成 `.file` / `.loc`，并追加一个最小 DWARF v4 compile unit。这样 GNU as 或 clang integrated assembler 会生成可被 GDB/LLDB 使用的 line table，调试器可以把机器码地址映射回 asmp `.asm` 源码行。为了让 LLDB/GDB 暴露寄存器变量，asmp 当前把这个 compile unit 标成 C11 调试语言；源码和 line table 仍然指向 `.asm` 文件。

```bash
racket cli/as.rkt -g --gnu-input -o out.s input.asm
clang -target aarch64-linux-gnu -g -c out.s -o out.o
```

macOS/LLDB 下建议保留对象文件再链接，便于 `dsymutil` 生成 dSYM：

```bash
racket cli/as.rkt --gnu-input --apple -g --cfi -o out.s input.asm
clang -target arm64-apple-macos11 -g -c out.s -o out.o
clang -target arm64-apple-macos11 out.o -o app
dsymutil app
```

inline 模板展开后的指令默认保留模板体自身的源码行号；每次展开块的第一条实际指令会映射到 `.inline ...` 调用行，所以可以在调用行设置断点并停到该次展开的入口。单步进入后，后续指令会回到模板体源码行。当前还不会生成 DWARF inline-call metadata，inline 调试表现为“调用行可断、模板体可单步”。

`-g` 还会为已分配到物理寄存器的 asmp 虚拟寄存器生成 `DW_TAG_variable`，所以可以在断点处用调试器查看变量：

```lldb
(lldb) breakpoint set --file input.asm --line 42
(lldb) run
(lldb) frame variable
(unsigned long) x.answer = 42
(unsigned int) w.answer32 = 7
```

这些变量会尽量保留源码里出现过的寄存器视图：`w.name` 会显示为 32-bit 的 `asmp_u32`，`x.name` 会显示为 64-bit 的 `asmp_u64`。如果同一个虚拟寄存器在源码中同时以 `w.name` 和 `x.name` 使用，当前会把两个视图都列出来，而不是生成按 PC 范围切换的精确 location list。这些变量仍使用全函数范围的 `DW_OP_regN` 位置，适合把 asmp 虚拟名和当前物理寄存器值对上；发生 spill 的虚拟寄存器目前只会出现在 `--debug-reg-map` 注释里，不会生成可读取的 DWARF 变量。

`--debug-reg-map` 会在输出汇编里追加注释，列出 asmp 虚拟寄存器在分配轮次中的去向：

```bash
racket cli/as.rkt --gnu-input -g --cfi --debug-reg-map -o out.s input.asm
```

输出形如：

```asm
// asmp debug reg map: fn
// iteration 0:
// allocated:
//   x.out -> x4
// coalesced:
//   (none)
// spilled:
//   x.tmp
// end asmp debug reg map
```

这个映射是给人读的完整分配摘要，会同时列出 allocated、coalesced 和 spilled；DWARF 变量目前只覆盖能解析到物理寄存器的位置。映射注释同样保留源码寄存器视图，所以 `w.name` 不会被显示成 `x.name`；如果源码确实使用了同一个虚拟寄存器的多个视图，会列出多个对应点。

`--cfi` 会生成 `.cfi_startproc` / `.cfi_endproc`，并跟踪常见 AArch64 栈帧操作：`sub/add sp`、`stp/str` 保存 GPR、`ldp/ldr` 恢复 GPR、`mov fp, sp`。配合 `.save` / `.restore` 生成的栈帧，可以让调试器和 profiler 更可靠地做 backtrace：

```bash
racket cli/as.rkt -g --cfi --gnu-input -o out.s input.asm
```

`--dump=ast,cfg,liveness,interference,allocation` 是 asmp 内部诊断输出，用来调 parser、CFG 和寄存器分配；它不是 GDB/LLDB 使用的调试信息。

## 操作数

立即数：

```asm
mov x0, #42
add x0, x0, #1
```

移位和扩展：

```asm
add x0, x1, x2, lsl #3
add x0, x1, w2, sxtw #2
```

内存寻址：

```asm
ldr x0, [x1]
ldr x0, [x1, #16]
stp x29, x30, [sp, #-16]!
ldr w10, [x3, w9, uxtw #2]
```

寄存器列表：

```asm
ld1 { z0.B - z3.B }, p0/z, [x0]
```

## 符号与 relocation

GNU 输入中的 relocation 会落到统一的 `ast-label` relocation 字段，再按输出语法生成 GNU 或 Apple 写法。

```asm
adrp x0, :pg_hi21:symbol
add  x0, x0, #:lo12:symbol

adrp x0, :got:symbol
ldr  x0, [x0, :got_lo12:symbol]
```

映射关系：

| GNU 输入 | AST relocation | GNU 输出 | Apple 输出 |
|---|---|---|---|
| `:pg_hi21:sym` | `PAGE` | `sym` in `adrp` | `_sym@PAGE` |
| `:lo12:sym` / `#:lo12:sym` | `PAGEOFF` | `:lo12:sym` | `_sym@PAGEOFF` |
| `:got:sym` | `GOTPAGE` | `:got:sym` | `_sym@GOTPAGE` |
| `:got_lo12:sym` | `GOTPAGEOFF` | `:got_lo12:sym` | `_sym@GOTPAGEOFF` |

外部符号可以声明：

```asm
.extern puts, hello_msg
```

## 当前边界

当前 GNU 前端重点覆盖函数体和常用静态数据，不完整支持完整 GAS 指令伪操作。已支持的基础数据 directive：

```asm
.section .rodata
.align 3
label:
  .ascii "bytes without trailing zero"
  .asciz "zero terminated string"
  .byte 1, 2, 0xff
  .byte2 0x1234
  .byte4 0x12345678, label
  .byte8 0x1122334455667788, label
  .byte16 0x112233445566778899aabbccddeeff00
  .byte32 1
```

形式约定：

| Directive | 支持形式 |
|---|---|
| `.ascii` | 一个或多个字符串字面量，例如 `.ascii "a", "b"` |
| `.asciz` | 一个或多个字符串字面量，由目标汇编器追加 NUL |
| `.byte` | 整数、符号或 relocation 表达式列表；整数范围为 `-128..255` |
| `.byte2` | 整数、符号或 relocation 表达式列表；整数范围为 `-32768..65535` |
| `.byte4` | 整数、符号或 relocation 表达式列表；整数范围为 `-2147483648..4294967295` |
| `.byte8` | 整数、符号或 relocation 表达式列表；整数范围为 `-9223372036854775808..18446744073709551615` |
| `.byte16` | 整数列表 |
| `.byte32` | 整数列表 |

`.byteN` 中的 `N` 是编码宽度。`.byte4 1` 表示把整数 `1` 编码成一个 4 字节整数槽位；在常见 AArch64 little-endian 目标上，对应字节是 `01 00 00 00`。`.byte4 0x12345678` 对应 `78 56 34 12`。负数按该宽度的二补码编码。它不是字符串，也不是把后面的参数拆成 4 个 `.byte`。

`.word` 仅作为 GNU 兼容输入别名接受，并会规范化为 `.byte4`；新代码请使用显式宽度。`.byte*` 不接收字符串字面量，字符串数据请使用 `.ascii` / `.asciz`。暂不做完整 GNU 表达式求值，复杂表达式会尽量保留为符号/relocation 或报错。下面这些目前不是稳定接口：

函数外的 `.align` / `.p2align` 在 `.text` 中仍作为下一个函数的 pending
alignment 使用；在 `.data`、`.rodata` 或其它非 text section 中会作为普通
module directive 输出。Apple 输出会写成 `.p2align N`，因此 8 字节函数指针槽
应使用 `.align 3`。

- 输入中的手写 `.cfi_*` 透传；
- 宏、条件汇编、复杂表达式求值；
- 更复杂的 section flag/type 组合。

输入中的手写 `.cfi_*` 仍然不做完整 GAS 兼容解析；新代码请优先使用 `--cfi` 让 asmp 根据托管栈帧生成展开信息。

## Hello World

当前最稳的 hello world 写法是：汇编实现一个 `hello_main` 函数，调用外部 `puts`，字符串 `hello_msg` 由同一个 GNU 输入文件提供。

GNU 输入文件：

```asm
.extern puts

.asmp.function hello_main abi=aapcs64 export
hello_main:
  .save fp, lr
  mov fp, sp
  adrp x0, :got:hello_msg
  ldr x0, [x0, :got_lo12:hello_msg]
  bl puts
  mov w0, #0
  .restore fp, lr
  ret
.asmp.end_function

.section .rodata
.globl hello_msg
hello_msg:
  .asciz "hello world from asmp"
```

C driver：

```c
extern int hello_main(void);

int main(void) {
    return hello_main();
}
```

生成 GNU 汇编：

```bash
racket cli/as.rkt --gnu-input -o /tmp/hello.s example/010-gnu-hello.asm
```

在 AArch64 Linux 环境中，可以继续编译并链接：

```bash
clang -c /tmp/hello.s -o /tmp/hello.o
clang example/010-gnu-hello-driver.c /tmp/hello.o -o /tmp/hello
/tmp/hello
```

在 macOS arm64 上，可以从同一个 GNU 输入生成 Apple 汇编：

```bash
racket cli/as.rkt --gnu-input --apple -o /tmp/hello-apple.s example/010-gnu-hello.asm
clang -target arm64-apple-macos11 -c /tmp/hello-apple.s -o /tmp/hello-apple.o
```

## 独立 Hello World

如果目标是 Linux AArch64，也可以不写 C driver、不依赖 libc，直接提供 `_start` 并使用 syscall：

```asm
.asmp.function _start export
  mov x0, #1
  adrp x1, :pg_hi21:hello_msg
  add x1, x1, #:lo12:hello_msg
  mov x2, #22
  mov x8, #64
  svc #0

  mov x0, #0
  mov x8, #93
  svc #0
.asmp.end_function

.section .rodata
hello_msg:
  .ascii "hello world from asmp\n"
```

生成并组装：

```bash
racket cli/as.rkt --gnu-input -o /tmp/standalone-hello.s example/011-gnu-standalone-hello.asm
clang -target aarch64-linux-gnu -c /tmp/standalone-hello.s -o /tmp/standalone-hello.o
```

在带 AArch64 Linux linker 的环境中可以继续无 libc 链接：

```bash
clang -nostdlib /tmp/standalone-hello.o -o /tmp/standalone-hello
```

这个独立版本是 Linux/ELF 程序，不是 macOS/Mach-O 程序。不要在 macOS 上用 `gcc -nostdlib a.s` 直接链接它：Darwin 链接器默认寻找 `_main`，动态可执行文件还要求链接 `libSystem.dylib`，并且 Linux 的 syscall 号也不能直接用于 macOS。

如果目标是 macOS，最普通的做法是导出 `main`，使用 `--apple` 输出，并正常链接 libSystem：

```asm
.extern puts

.asmp.function main abi=aapcs64 export
main:
  .save fp, lr
  mov fp, sp
  adrp x0, :pg_hi21:hello_msg
  add x0, x0, #:lo12:hello_msg
  bl puts
  mov w0, #0
  .restore fp, lr
  ret
.asmp.end_function

.section .rodata
hello_msg:
  .asciz "hello world from asmp"
```

```bash
racket cli/as.rkt --gnu-input --apple -o /tmp/macos-hello.s input.asm
clang /tmp/macos-hello.s -o /tmp/macos-hello
```
