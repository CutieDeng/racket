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

- `regalloc.rkt`：虚拟寄存器 → 物理寄存器。指令级活跃性（标号/跳转构成的控制流）、含显式与隐式物理
  寄存器的干涉图（vreg 不会落在正承载 `sha256rnds2` 隐式操作数的 xmm0 上，但 xmm0 空闲时可复用）、
  拷贝合并（Briggs/George，合并后的自拷贝删除）、Chaitin-Briggs simplify-select；不溢出（寄存器不够时
  报错并指出压力点）。`in:`/`inout:` 按 SysV 位置预着色 rdi rsi rdx rcx r8 r9，`out:` 首个 rax；
  一个 vreg 全函数一个物理寄存器（不切分活跃区间）；节点顺序=首次出现顺序，再生字节稳定。
  池：GPR 15 个（无 rsp）、向量 xmm0–15、掩码 k1–k7。`as.rkt --dump-alloc` 打印映射。
  主机端检查 `tests/alloc-tests.rkt`（不需 x86 硬件）。

- EVEX 修饰（X3-1a 起）：`zmm.x{k.m}{z}`、`[mem]{1to16}` 由解析器保存为结构化数据；规范表把 XED 的
  写掩码（MASK1）与广播伪操作数剔出语法操作数列表，掩码寄存器计为 use、合并掩码（无 `{z}`）计为目标的
  use；分配器给 k1–k7 着色并改写修饰；回读比对归一化 llvm-objdump 打印的 `vpcmp{eq,lt,…}` 别名。
  VAES/VPCLMULQDQ 没有嵌入广播（`{1toN}` 对 `vaesenc` 非法，用 `vbroadcasti32x4` 到寄存器）。

- `.simd sse|avx2|avx512`（函数内）：向量池 16 或 32 个寄存器；分配后驱动检查落在 xmm16–31 的指令
  必须有 EVEX 形式（否则报错提示换 AVX-512 助记符）。

现状（X3-1b，2026-10-21）：内核 `sha256`（SHA-NI）、`aes_ctr_vaes`（VAES+AVX-512 CTR，16 块/迭代）、
`ghash_vpclmul`（VPCLMULQDQ GHASH，16 块一次约简）已落地并由 C 分派；lan-11 gate 全部 0 mismatch。
待做：AES+GHASH 单趟融合内核、`.frame/.alloca`、`.call` 破坏集、两地址改写、Zen 5 调度模型（X1-3）。
