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
- `.frame N`（函数内）：N 字节栈暂存，正文用 `[rsp + off]` 访问；发射器在 push 之后 `sub rsp`、每个 `ret`
  前 `add rsp`，并按返回地址 + push 数把大小补到 16 字节对齐。
- `.macro NAME p1, p2 … .endm` / `NAME(a, b)`：参数化文本宏（`x86/macro.rkt`，体内 `\p1`、`\@` 为每次展开
  的计数器），在 `.for` 展开之前展开，可嵌套、可含 `.for`。
- `${expr}` 在任何一行都求值（解析器把整个源包进一个隐式单次 `.for`），宏参数可直接参与算术。
- 分配器把清零惯用法（`xor r, r`、`sub r, r`、`pxor/vpxorq x, x`）视为纯定义而非读取（否则一个在出口处
  `xor d.ret, d.ret` 的 out 寄存器会从入口一直活到出口）；寄存器不足时错误信息列出压力点的活跃值。
- 溢出：着色失败时分配器选压力点上"活跃最久、提及最少"的值放进帧槽（每次读取前装入短命临时量、每次定义后
  存回；GPR 8 B、向量 64 B 槽，用 `mov`/`vmovdqu64`/`kmovq`，不动标志位，adc/adox 链安全），重做分配直到成功；
  溢出区放在 `.frame` 区之上，发射器自动扩帧。`as.rkt --dump-alloc` 打印 `spilled name@off`。
- `.call NAME(a, b, …)`：SysV 调用（≤6 个寄存器实参；实参先进临时量再进 rdi rsi rdx rcx r8 r9，`[mem]`
  用 lea 取址），调用指令定义全部 caller-saved GPR、全部向量与掩码寄存器（跨调用活跃的值自动落到
  callee-saved 寄存器或溢出），结果在 rax；发射 `call NAME@PLT`，并保证调用点 rsp 16 字节对齐。
- ABI 预着色的兜底：入参/出参若跨越其 ABI 寄存器的重定义（如跨 `.call` 存活），分配器自动在入口拷出
  （或在每个 `ret` 前拷入 rax），不再报 "argument conflicts with its register"。
- 内核合成配方（X25519 阶梯、P-256 点运算）：把域运算体写成内存操作数宏（参数为"基址 + 偏移"文本，
  如 `rsp + 32`、`q.p + 64`），临时量放 `.frame` 槽，一次调用完成整步，消掉调用/push/pop 开销。

现状（X3-2a，2026-10-21）：内核 `sha256`（SHA-NI）、`aes_ctr_vaes`（VAES+AVX-512 CTR）、`ghash_vpclmul`
（VPCLMULQDQ GHASH）、`gcm_vaes`（AES-GCM 单趟融合，上下文结构体传参）、`chacha20_avx512`（16 块/单元，
`.simd avx512`）、`poly1305_x86`（MULX radix-2^64）、`chacha20poly1305_x86`（向量 ChaCha + 标量 Poly 融合）、`p256_mul_x86`（MULX/ADX 蒙哥马利乘）、`keccak_avx512`（Keccak-f[1600] 平面布局 + x2 双态）、分配器已按 def-use web 拆分重名值（到达定义 + 并查集；cmovcc 条件写按读改写；掩码修饰符读参与重命名；向量溢出按函数宽度）；`chacha20_avx512` 加双组 32 块内核（2048 字节单位，32 zmm 全作状态，15 GB/s）、`gcm_vaes` 已重排为 AES 轮与前一块 GHASH 在程序序中交错（发射器 `asm/gen/gcm-vaes-x86.rkt`，Karatsuba + x^-1 预乘表，内核 4.1→2.8 周期/块）、`sha512_x86`（标量 rorx）+ `sha512_avx512`（AVX-512VL 四字向量调度，标量轮）、`poly1305_ifma`（AVX-512 IFMA 八路）、`keccak_scalar`（单流标量 Keccak）、P-256 点运算、X25519 整步阶梯、Ed25519 点运算（madd/add/dbl 宏合成 + AVX-512 常数时间 comb 查表，fe64 路径 sign 9.1 / verify 24.8 µs）已落地并由 C 分派；lan-11 gate 全部 0 mismatch。GCM 的 H 表改为单趟内核（缩放域内相乘，16 KB 每次调用 −25 ns，与 OpenSSL 持平）。展开密钥 API（`aead-expand-key`，GCM 表预置）与 Ed25519 展开私钥已加；回退层（与同机屏蔽位的 OpenSSL 对照 0.90–1.02×）：`chacha20_avx2`/`chacha20_ssse3`、`poly1305_avx2`、`gcm_aesni`（VEX）/`gcm_aesni_sse`（同一发射器 `--sse`）、Ed25519 AVX2 查表、`poly1305_sse2`（无 BMI2 层）、`sha256_avx2`（无 SHA-NI：0.98× OpenSSL AVX2 路径）。待做：E(J0) 与 H 配对
（2-clmul 约简、轮密钥常驻）、`.frame/.alloca`、`.call` 破坏集、两地址改写、Zen 5 调度模型（X1-3）。
