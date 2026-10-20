# rktasm/x86 — x86-64 后端（独立处理逻辑模块）

与 AArch64 管线并列、不共享实现（用户裁定 2026-10-20）；只沿用 directive 约定、
`regen.sh` 的 check/gate/regen 三分工与 C-oracle 差分 harness。规划与数据来源见
`../docs/x86-64-backend-plan.md`。

- `xed-convert.rkt <xed-checkout> <out.rktd>`：从 Intel XED datafiles 生成规范表
  （ICLASS/ISA_SET/EXTENSION/FLAGS/ATTRIBUTES/OPERANDS，PATTERN 原样保留供后置的编码器）。
- `spec.rkt`：加载 `data/xed-x86.rktd`（生成物，不入库；由 `xed-convert.rkt` 从 pin 住的 XED
  checkout 生成），按助记符 + 操作数形状匹配 XED 形式（legacy/VEX 优先于 EVEX/APX，除非操作数
  本身需要 zmm/k/xmm16+），给出 use/def（显式操作数 + `SUPP` 隐式寄存器，如 `sha256rnds2` 的
  xmm0、`mulx` 的 rdx）与 EFLAGS 读写集。
- `parse.rkt`：内核 DSL（Intel 操作数序、GAS Intel 语法）。`.function NAME [export] ( in:/out:/inout: )`
  … `.end`、`.save all|none`、`.rodata NAME [align=N]` … `.end`、`label:`、`.p2align`；虚拟寄存器
  `q./d./w./b.name`、`xmm./ymm./zmm.name`、`k.name`；内存 `[base + index*scale + disp + sym]` 带可选
  `size ptr` 与 `{…}` 修饰。先经共享的 `../parser/unroll.rkt`（`.for var, lo, hi` / `${expr}`）展开。
- `emit.rkt`：输出 `.S`（`#if defined(__x86_64__) && defined(__ELF__)` 整体守卫、`.intel_syntax noprefix`、
  被调用者保存寄存器自动 push/pop、用到 ymm/zmm 时 `ret` 前自动 `vzeroupper`、局部标号改名
  `.L<fn>_<label>`、`.note.GNU-stack`）。非 ELF 的 x86-64（macOS/Windows）保持 C/intrinsics 路径。
- `as.rkt`：驱动。`racket as.rkt [-o out.S] [--roundtrip] [--dump-usedef] in.asm`。
  `--roundtrip` 在 Mac 上用 `clang --target=x86_64-unknown-linux-gnu -c` 交叉汇编并以
  `llvm-objdump --x86-asm-syntax=intel` 读回，比对助记符序列（parse→emit→assemble→disassemble 闭环）。

内核源在 `racket/src/crypto/asm/x86/<kernel>.asm`，维护脚本 `racket/src/crypto/asm/x86/regen-x86.sh`
（`regen <kernel>` / `check [kernel]`（字节级再生稳定）/ `gate [kernel]`（仅 x86-64 Linux：
gcc 编 harness + 已提交 `.S`，对 C/intrinsics oracle 差分 + KAT + `BENCH` 行））。

现状（X1-1，2026-10-21）：物理寄存器模式；首个内核 `sha256`（SHA-NI，`rktcrypto_sha256_blocks_x86`）
已由 `rktcrypto_sha256.c` 在 x86-64 ELF 上分派。虚拟寄存器分配 / SysV 自动序幕 / 两地址改写 /
Zen 5 调度模型为 X1-2、X1-3。
