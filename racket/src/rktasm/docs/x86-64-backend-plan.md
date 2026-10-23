# rktasm x86-64 后端与 rktcrypto x86-64 内核：建设规划（2026-10-20，草案 v1）

状态：规划，待用户定稿。开发/验证机：**lan-11**（AMD Ryzen 9 9950X，Zen 5，Fedora 41，见 §6）。
关联：`crypto/ASM-ENHANCEMENT-PLAN.md` §3 原定"x86-64 非目标"的重议条件已触发（lan-11 成为开发/部署机），本文取代该条。
标注：**已验证**（实测/实读）、**推断**（有依据未实测）、**待核实**。

## 0. 决策与范围

- 目标：rktasm 增加 x86-64 后端，使 rktcrypto 的热点内核在 x86-64 上达到 OpenSSL 持平（与 Apple M 上同一标准：头对头实测、bit-exact 差分、C oracle 不可移除）。
- 范围内：SysV AMD64（Linux/ELF），Zen 5 调度模型，AVX2/AVX-512/VAES/VPCLMULQDQ/SHA-NI/ADX/BMI2/IFMA/GFNI 这组扩展，GNU `as` 装配的 `.S` 产物。
- 范围外（本轮）：Windows x64（MSVC 不吃 `.S`，继续 C 兜底；需要时另加 NASM 写出器）、32 位、APX/AMX（lan-11 无）、Intel 微架构调度模型（后续按微架构参数化加入）。
- 不变式沿用：C 实现 = 差分 oracle + 平台兜底，不可移除；每个内核保有独立 C 对照与差分 harness；性能门禁 ±2%；产物 `.S` 入树、rktasm 只在 regen 时运行。

## 1. "MRS 等价物"：数据从哪里来

ARM 侧的根基是 Arm 官方 **Machine Readable Architecture Specification**（AARCHMRS，BSD 许可，`data/aarchmrs/` 固定版本 + sha256）：`Instructions.json` 生成语法/校验表（`syntax/gen-instruction-spec.rkt`）、编码表（`encode/tool/mrs-converter.rkt`）、use/def 模式（`semantic/gen-use-def.rkt`，由操作数字段名 Rd/Rn/Rdn 推导），`Registers.json` 生成系统寄存器表。**已验证**（实读源码）。

x86-64 没有同等的厂商 JSON 规范；按"数据驱动、固定版本、离线可再生"的同一原则，各层的替代来源如下：

| ARM 侧（AARCHMRS 提供） | x86-64 来源 | 性质与状态 |
|---|---|---|
| 指令编码（PATTERN） | **Intel XED datafiles**（`github.com/intelxed/xed`，Apache-2.0；实读 External Release v2026.08.23：`datafiles/` 155 个条目、6.3MB，基表 `xed-isa.txt`（1228 个 ICLASS 块）+ 各扩展目录的 `*-isa.xed.txt`；每条指令是一个 `{ ... }` 块：`ICLASS/CPL/CATEGORY/EXTENSION/ISA_SET/EXCEPTIONS/REAL_OPCODE/ATTRIBUTES/FLAGS/PATTERN/OPERANDS/IFORM`，PATTERN/OPERANDS 成对可重复；格式说明在 `misc/engineering-notes.txt`；`golang.org/x/arch/x86/xeddata` 是可参考的第三方解析器） | 数据；格式**已验证**（本机 shallow clone 实读，scratchpad `xed-parse.rkt` 可解析全部块），版本固定方式与 sha256 待做 |
| CPUID 位 → ISA 集（dispatch 表的真源） | 同仓 `datafiles/cpuid.xed.txt` 与各扩展目录的 `cpuid.xed.txt`：`XED_ISA_SET_AES: aes.1.0.ecx.25`、`XED_ISA_SET_PCLMULQDQ: pclmulqdq.1.0.ecx.1` 这样的 leaf.subleaf.reg.bit 映射 | 数据，**已验证**；可直接生成 `rktcrypto_cpu.c` 的 x86 检测表（XGETBV 的 OS 状态位须另加） |
| 操作数定义（寄存器类、宽度、立即数） | 同上 `OPERANDS` 行，实例：`SHA1MSG1`：`REG0=XMM_R():rw:dq:i32 REG1=XMM_B():r:dq:i32`；`ADD`（内存目的形）：`MEM0:rw:v REG0=GPRv_R():r`——每个操作数带 **r/w/rw**、宽度码（`v`=操作数尺寸随模式、`d`/`q`/`dq`）、元素类型 | 数据，**已验证**；比 ARM 侧"按字段名猜 def/use"更准 |
| use/def 语义 | 同上 r/w 属性 + 隐式操作数 + `FLAGS:` 行，实例：`ADCX`：`FLAGS: MUST [ CF-TST CF-MOD ]`（只读写 CF）；`ADD`：`MUST [ of-mod sf-mod zf-mod af-mod pf-mod cf-mod ]` | 数据，**已验证**；x86 的两地址与部分标志更新正需要这层 |
| 扩展/特性归属（dispatch 分级） | `EXTENSION`/`ISA_SET`（如 `AVX512F_512`, `SHA`, `ADOX_ADCX`, `BMI2`, `VAES`） | 数据 |
| 延迟/端口模型（Apple M 手写 `data/latency.rktd`） | **AMD《Software Optimization Guide for the AMD Zen5 Microarchitecture》（文档号 58455）附带的指令延迟 Excel 表**——lan-11 的微架构；其次 **uops.info 的 `instructions.xml`**（多微架构实测，版本至 2026-03，附 `xmlToAssembler.py`） | 数据；58455 的 xlsx 存在**已验证**（检索），下载与使用条款**待核实**；uops.info 的许可与 Zen 5 覆盖**待核实**（页面未给许可声明） |
| 系统寄存器表 | 无对应物（x86 用 `cpuid`/`xgetbv`/`rdtsc`，数量少，手写） | 手写 |
| 编码正确性对照 | **GNU `as` 2.43.1**（lan-11 已装）装配 + `objdump -d` 回读；**`llvm-mc -show-encoding`** 逐指令差分 | 开发期 oracle，不入树（与 Docker gate-elf 同地位） |
| 调度模型对照 | **`llvm-mca`**（LLVM 对 znver5 用哪版调度模型**待核实**，可能仍是 znver4 近似）+ **`perf stat`**（lan-11 已装） | 开发期 oracle |
| 性能持平基线 | **OpenSSL 3.2.6**（lan-11 已装，`openssl speed -evp`） | 实测基线 |

来源的边界：XED datafiles、58455 的表、uops.info XML 是**数据**，与 AARCHMRS 压缩包同类——固定版本、记 sha256、提交到 `data/`（若许可允许再分发；uops.info 若不允许，则只提交我们转换后的 `.rktd` 并记录来源版本），不违反"不 vendor 外部代码"。llvm-mc/llvm-mca 只在开发期使用。

## 2. 组织方式：独立的 x86-64 处理模块（2026-10-20 用户定）

用户裁定：**x86-64 开新的处理逻辑模块，不要求复用 AArch64 那套逻辑**。因此：

- 新建 `rktasm/x86/`（或平级的 `rktasm-x86/`）：自有 parse → validate → regalloc → schedule → emit 管线，按 x86 的事实（两地址、EFLAGS、固定寄存器、内存操作数、16 GPR）从头设计，不把 AArch64 的 operand/regalloc/调度代码改成"通用"的。
- 只共享天然中立的东西：S-expr 读取器与 CLI 驱动的壳、`.function/in:/.save/.frame/.alloca/.for/${}/.context/.call` 这些**指令行之外的 directive 约定**（为了两套内核源码读起来一致）、`regen.sh` 的 check/gate/regen 三分工与 `asm/tests` 的 C-oracle 差分 harness、生成器（`asm/gen/*.rkt`）的组织方式。指令行与操作数语法由 x86 模块自定（Intel 语法、目的在前）。
- 直接收益：AArch64 内核的 `regen.sh check`（逐字节可复现）在整个 x86 建设期间**按构造不受影响**，原 §4 的"rewriter/分配器回归风险"消失；x86 模块可以用更贴合 x86 的中间表示（例如两地址形式直接进分配器，tied 约束作为一等概念）。
- 代价：两套管线各自维护；以后若出现第三架构，再抽公共层（届时有两个实例可对照，比现在抽象更可靠）。

x86-64 模块需要的部件（对应 ARM 侧的层，但独立实现）：

1. `operand/x86.rkt`：当前 `reg-class/c = 'x 'w 'z` 是 AArch64 专属（**已验证**，`operand/operand.rkt`）。x86 需要：同一 GPR 的 8/16/32/64 位视图（`al/ax/eax/rax`，高 8 位 `ah` 类只读不分配），xmm/ymm/zmm 同寄存器三视图，掩码 k0–k7，内存操作数 `[base + index*scale + disp]`（+ RIP 相对、`{1toN}` 广播、`{k}{z}` 掩码），立即数宽度（imm8/imm32 符号扩展规则）。
2. `syntax/x86`：由 XED 生成 instruction-spec/variant/alias 表（Intel 语法助记符与操作数顺序，目的在前，与现有 DSL 习惯一致）。
3. `semantic/x86`：use/def 由 XED 操作数 r/w + 隐式操作数 + FLAGS 生成；EFLAGS 作为伪寄存器进入依赖链（不参与着色）；部分更新表（`inc/dec` 不写 CF；`adcx` 只写 CF、`adox` 只写 OF——ADX 存在的理由，Montgomery 乘的两条进位链可并行）。
4. `config/abi.rktd` 加 `sysv-amd64`：args rdi rsi rdx rcx r8 r9；返回 rax(:rdx)；callee-saved rbx rbp r12–r15；xmm 全 caller-saved；`special-regs (sp rsp) (fp rbp)`；红区 128B（叶函数可用）；调用点 16B 栈对齐。`win64` 后置（args rcx rdx r8 r9，shadow space 32B，xmm6–15 callee-saved）。
5. 分配器约束（x86 后端的核心设计工作）：
   - **两地址**：`add rax, rbx` 目的即源。方案 A（推荐）：DSL 保持三操作数写法 `add r.d, r.a, r.b`，rewriter 在 `d≠a` 且 `a` 之后仍活时插入 `mov d, a`（LLVM TwoAddress 的做法）；VEX/EVEX 的 SIMD 本就三操作数，不受影响。方案 B：DSL 直接写两地址形式——失去与 AArch64 内核的形态一致，不推荐。
   - **固定寄存器**：`mul/imul(1-op)/div` 用 RDX:RAX，`mulx` 隐式 RDX 源，移位计数 `cl`，`rep` 串指令用 rsi/rdi/rcx——预着色 + 活跃区间分裂。
   - **内存操作数**：ALU 指令可带一个内存源/目的（load-op 微融合），分配器把它当 use/def，不占寄存器。
   - **寄存器少**：16 GPR（AArch64 31）→ 溢出与 remat 更频繁；P-256/Keccak 这类"压力感知调度"的收益更大，也更难。
6. 调度模型 `data/latency-znver5.rktd`：由 58455 的 xlsx 转换；x86 特有规则：`cmp/test`+`jcc` 宏融合、load-op 微融合、循环头 32B 对齐（Zen 5 op-cache 行为按 SOG）、`vzeroupper`（AVX→SSE 过渡惩罚）、Zen 5 的 AVX-512 全宽无降频（**推断**，按公开微架构资料，实测确认）。
7. emit：Intel 语法（`.intel_syntax noprefix`）、ELF 符号与 `.type/.size`、`.p2align`、`.save all` → 按需 push/pop callee-saved、`.frame/.alloca` → `sub rsp`，CFI 可选。`.S` 用 `#if defined(__x86_64__)` 守卫（x86 汇编器不按 `-march` 拒指令，无需 ARM 侧的 `.arch_extension` 自声明）。
8. 运行时 dispatch（`crypto/rktcrypto_cpu.c` x86 分支，现仅查 leaf1/7 的 AES-NI/PCLMUL/SHA-NI/AVX2，**已验证**）：加 **XGETBV**（OS 启用 YMM/ZMM/opmask 状态，否则 AVX 指令 SIGILL）、leaf 7 的 ADX/BMI2/AVX512F/BW/VL/IFMA/VBMI/VAES/VPCLMULQDQ/GFNI、subleaf 1 的 AVX-VNNI/AVX-IFMA/SHA512；分级 x86-64-v2/v3/v4 + crypto 位。

## 3. 阶段

### X0 — lan-11 环境与基线（1–2 天）
- 本树在 lan-11 构建（`make base`，x86-64 Linux，gcc 14.3.1，**已验证**工具链存在）；跑现有 rktcrypto 测试（C 路径 + `rktcrypto_x86.h` intrinsics）。
- 基线表：`openssl speed -evp` vs rktcrypto bench，逐内核差距（AES-GCM/ChaCha-Poly/SHA-256/SHA-1/SHA-512/SHA-3/RSA/P-256/X25519/ML-KEM/ML-DSA）→ 决定 X4 顺序。
- 装 LLVM 到 `$HOME`（lan-11 无 sudo，**已验证**；用 LLVM 官方 Linux x86_64 二进制包或源码构建），得到 `llvm-mc`/`llvm-mca`。
- 取 XED（固定 commit）、58455 及其 xlsx、uops.info XML；核实三者条款；记 sha256。

#### X0 结果（2026-10-20，lan-11，已验证）
- 构建：`make CPUS=16 JOBS=16 base` 2m49s；`(9.3.10 chez-scheme Linux x86_64)`。前提是 pb 引导种子必须由本分支的 Chez 生成（racket/pb 的 v9.3 种子缺 `fasl_type_closure_freevars`/`fasl_type_padding`；本机 `make pb-build` 走 rktboot 因 `$code?` 失败；改用 Chez `bootquick --host-workarea` 交叉生成 pb/ta6le，且 `boot/pb` 须是带 origin/v9.3 的 git 仓以满足 `pb-manage`）。
- 验收：C 自检 `#t`，`integration.rkt` 77/77，无 libcrypto。
- rktcrypto 基准（1 MiB，单核）：sha256 2342 MB/s（SHA-NI intrinsics 生效）、sha1 1360、sha512 663、sha3-256 313、blake2b 1937、blake3 956、hmac-sha256 2169、siphash 4763、**chacha20-poly1305 783**、**aes-256-gcm 117**；x25519 21.5µs、ed25519 sign 17.3 / verify 42.9µs、p256 ecdsa sign 18.5 / verify 63.5µs、p256 ecdh 55.2µs；ml-kem-768 encaps 34.4µs、ml-dsa-65 sign 381µs。
- perf（`perf record -g`，paranoid=2 可用）：aes-256-gcm 87% 在 `aes_enc_blk`（`rktcrypto_aes_modes.c:267` 的逐字节查表 AES）——x86 上 CTR/GCM/CBC/CMAC/XTS 全部走这条便携路径，AES-NI 内核（`rktcrypto_aes256_block_aesni`）只被单块 API `rktcrypto_aes256_encrypt_block` 用到；chacha20-poly1305 50% `chacha20_core` + 13% `poly1305_blocks`（标量 C）。
- OpenSSL 3.2.6 对照：AES-128-CTR 15.5 GB/s（16KB 块），其余见 §6.1（基线表待填）。

#### X0.5 — 先用 C intrinsics 补最大的洞（不依赖 rktasm，1–3 天）
1. `rktcrypto_aes_modes.c` x86 分支：`rktcrypto_aes_enc_block`/`aes_enc_blk` 按 `Nr`（10/12/14）走 AES-NI；GCM/CTR 的批量路径改成 4–8 块流水的 AES-NI CTR（与 ARM 侧 NEON 8 路同构），GHASH 已是 PCLMUL。预计 aes-256-gcm 0.12 → 3–6 GB/s（推断，按 Zen 5 AES-NI 吞吐）。
2. 之后才轮到 rktasm x86 内核（VAES/VPCLMULQDQ 四路、AVX-512 ChaCha）去追 OpenSSL 的 10+ GB/s。
3. 顺带：x86 的 AES 密钥扩展也走 AES-NI（`aeskeygenassist`），CBC/CMAC 保持单块串行但用硬件指令。

**X0.5 落地记录（2026-10-21，lan-11，已验证）**
- 步骤 1（AES-NI 进 modes）：`rktcrypto_x86.c` 新增通用密钥扩展（`aeskeygenassist` 取 SubWord/RotWord，128/192/256 同一递推）、`aesimc` 逆调度、单块 enc/dec、8 块流水 CTR（`inc32` 可选）、CBC enc（串行）/dec（8 块）；`rktcrypto_aes_modes.c` 便携段通过 `expand_key/enc_blk/dec_blk` 分派，覆盖 expand/enc_block/CTR/CBC/CMAC/XTS，CCM 经 `rktcrypto_aes_enc_block` 自动受益；`rktcrypto_gcm.c` 的 `gctr` 走 8 块 CTR。差分 `asm/tests/test_aes_x86.c`（同进程切换 `rktcrypto_cpu_override_features`，4000 轮 × 全模式 × 三种密钥长，含 GCM/CCM seal/open/篡改）0/65121；integration 77/77；aes-256-gcm 117 → 1613 MB/s；perf 剩余 61% 在单块 `gcm_gfmul`。
- 步骤 2（SHA-1 SHA-NI）：`rktcrypto_sha1_blocks_shani`（sha1rnds4/nexte/msg1/msg2 标准序列），`rktcrypto_legacy.c` 分派；差分 `asm/tests/test_sha1_x86.c` 0/3001 + abc KAT；sha1 1360 → 2818 MB/s（OpenSSL 2722–2787，≈1.02×）。
- 步骤 3（GHASH 4 块聚合）：`gcm_gfmul` 拆为 `gcm_mul_raw`（256 位裸积）+ `gcm_reduce`（线性，可先累加后约简），`ghash_x86` 预计算 H²/H³/H⁴，每 64 字节一次约简；差分 0/65121；吞吐见下方记录。

### X1 — 规范表与文本后端（3–4 周）
- X1a `x86/xed-converter.rkt`：只解析 `ICLASS/EXTENSION/ISA_SET/FLAGS/ATTRIBUTES/OPERANDS`（行式 key: value 块，PATTERN/OPERANDS 按顺序配对成 form），生成 x86 模块自己的指令表与 use-def 表。**不**解析 `PATTERN` 的位域——装配交给 `as`，与 rktcrypto 现有流程一致。**原型已跑通**（scratchpad `xed-convert.rkt`，约 70 行）：111 个 ISA 文件 → 1932 个 ICLASS、10884 个 form、3.5MB `.rktd`；操作数动作词汇 `r/w/rw/rcw/cw/cr/crw`，`SUPP` 标记隐式操作数（如 `SHA256RNDS2` 的隐式 XMM0、`MULX` 的隐式 RDX），宽度码 `b/d/q/dq/qq/v/vv/z*`，标志词汇 `xx-mod/-tst/-u/-0/-1/-pop/-ah`（legacy 小写，APX 大写）；首批内核助记符（SHA-NI、SSE/AVX 搬运、MULX/ADCX/ADOX/RORX、VAES/VPCLMULQDQ、VPTERNLOGQ/VPMADD52、VPROLQ）全部存在，且每条按 ISA 集分形（例如 `VPADDD`：AVX/AVX2/AVX512F_128/256/512 共 10 form），dispatch 分级可直接由 form 的 ISA 集推出。
- X1b 后端：§2 的 1/4/5/7 项。验收样例：**SHA-256 块函数（SHA-NI，约 60 条指令）**——简单、x86 红利大、已有 C intrinsics 对照；门禁 = `asm/tests` 差分 0 mismatch + `as` 装配 + `objdump` 回读一致。
- X1c 门禁接入 `regen.sh`：`gate-x86`（lan-11 原生，等价 Phase E 的 `ELF_NATIVE`）。

**X1-1 已落地（2026-10-21，已验证）**——物理寄存器模式的端到端闭环：
- 模块文件 `rktasm/x86/{spec,parse,emit,as}.rkt`（见 `x86/README.md`）；`data/xed-x86.rktd` 为生成物不入库
  （`.gitignore`），从 pin 住的 XED checkout 用 `xed-convert.rkt` 再生。`.for var, lo, hi` / `${expr}`
  直接复用 `parser/unroll.rkt`（唯一与 AArch64 管线共享的代码）。
- 首个内核 `crypto/asm/x86/sha256.asm`（SHA-NI，从已验证的 intrinsics 逐条转写，状态驻寄存器跨块）→
  `rktcrypto_sha256_x86.S`，`rktcrypto_sha256.c` 在 x86-64 ELF 上分派；守卫 `__x86_64__ && __ELF__`，
  非 ELF x86-64 仍走 intrinsics。维护脚本 `crypto/asm/x86/regen-x86.sh {regen|check|gate|list}`。
- 门禁数据：Mac 闭环 173 条指令 parse→emit→clang 交叉汇编→llvm-objdump 回读一致，`check` 字节级再生稳定；
  lan-11 `gate` 0/3001 mismatch（3000 组随机多块 + FIPS 180-4 "abc" KAT）；harness 1 MiB
  asm 2665 MB/s vs intrinsics 2355 MB/s（+13%）；`make base` 后 self-test #t、integration 77/77；
  `crypto-benchmark` sha256 2243/2342（intrinsics，X0.5/X0）→ 2537/2669 MB/s（两次），
  OpenSSL 3.2.6 `speed -evp sha256` 16 KB = 2642 MB/s → 0.96–1.01×（持平）。
- 未做（X1-2/X1-3）：虚拟寄存器 + 图着色分配、SysV 自动序幕/`.frame`/`.alloca`、两地址改写、
  Zen 5 调度模型；编码器 X4 仍后置。

**X1-2a 已落地（2026-10-21，已验证）**——`rktasm/x86/regalloc.rkt`：指令级活跃性 + 含物理寄存器的干涉图 +
拷贝合并 + Chaitin-Briggs 着色，无溢出；SysV 入参预着色。`sha256.asm` 改为虚拟寄存器（xmm0 物理，
为 `sha256rnds2` 隐式操作数）；分配结果 10 个向量寄存器（t 复用 xmm0 的空闲区间）。lan-11 gate 0/3001，
harness asm 2666 MB/s（物理版 2665），integration 77/77，基准 sha256 2678 MB/s。主机端
`tests/alloc-tests.rkt` 7 组断言（预着色/视图、隐式 xmm0 干涉与复用、拷贝合并删除、压力点报错、
循环活跃性、视图宽度选形）。

**X3-1a 已落地（2026-10-21，已验证）**——`crypto/asm/x86/aes_ctr_vaes.asm`（VAES+AVX-512：4 个 zmm 装 16 个
计数器块，每轮一次 `vbroadcasti32x4` 供 4 条 `vaesenc`；计数器按字节反转的 128 位整数存放，inc32 用
`vpaddd` 32 位回绕，全宽模式 `vpaddq` + `vpcmpuq`/`kshiftlb` 掩码进位；64 字节余数循环；<64 字节与非 ELF
留 AES-NI）。C 侧：`rktcrypto_aes_ctr_x86` 变为分派器，AES-NI 实现改名 `rktcrypto_aes_ctr_aesni`（oracle）；
`rktcrypto_cpu.c` 加 AVX512(F+DQ+BW+VL)/VAES/VPCLMULQDQ 位与 xgetbv XCR0 检查。数据：gate 0/4000
（内核直接 + 经分派器，三种密钥长度，inc32/全宽，32/64/128 位回绕点）；harness 1 MiB AES-256-CTR
39734 MB/s vs AES-NI 11960（3.3×）；AES 对便携差分 0/65121；integration 77/77；基准 aes-256-gcm
3622→4830 MB/s（探针 3330→4160）。剩余瓶颈 = GHASH（xmm PCLMUL 4 块聚合）→ X3-1b。

**X3-1b 已落地（2026-10-21，已验证）**——`crypto/asm/x86/ghash_vpclmul.asm`（VPCLMULQDQ+AVX-512：4 个 zmm
装 16 个数据块对 H^16..H^1（C 侧每次调用预算 15 次乘法成 256 B 表，降序存放，作内存操作数），lo/hi/mid 原始积
跨 16 块累加后一次 `gcm_reduce`（逐条转写 intrinsics 的移位折叠序列，比特一致）；64 字节余数路径；
<256 B 区域留 PCLMUL intrinsics）。接入点 = `rktcrypto_ghash_x86` 的每个区域（aad、ct）前缀。
数据：gate 0/3000（oracle = 同函数关闭 VPCLMULQDQ 特征位）；harness 1 MiB GHASH 21202 vs 7677 MB/s
（2.8×）；integration 77/77；基准 aes-256-gcm 4830→8822 MB/s（探针 4160→6637）。
分析（推断）：CTR 39.6 + GHASH 21.2 GB/s 两趟理论合成 13.8，实测 8.8；GHASH 每 256 B 一条约 50–60 周期的
串行链（acc→clmul→折叠→约简），与 AES-256 16 块的 56 条 vaesenc 工作量相当 → X3-1c 单趟融合（AES 与
上一块 GHASH 重叠）预计接近 OpenSSL 的 22.8 GB/s；更便宜的约简（2 clmul 蒙哥马利式）与 32 块聚合为后备。

**X3-1c 已落地（2026-10-21，已验证）**——`crypto/asm/x86/gcm_vaes.asm`：单趟 AES-GCM 主体，每 256 B 块
16 个 CTR 块（4 zmm）加密并与输入异或，同一迭代把**上一块**密文折入 GHASH（`pending` 标志，首块跳过），
加密时密文取自寄存器、解密时在写出前从输入装载（原地解密安全）；上下文结构体 `rktcrypto_gcm_vaes_ctx`
（rk/htab/ctr/acc/nr/enc）绕过 6 个寄存器实参的限制，返回已处理字节数（256 的倍数）。C 侧
`gcm_x86_fused`（gcm.c，镜像 ARM `gcm_hw`）：aad GHASH → 融合主体 → <256 B 尾部走 CTR+GHASH 区域
（解密先 GHASH 后解密）→ 长度块 → tag；open 先解密后比对，失败清零输出。辅助 `rktcrypto_gcm_vaes_setup`
（H^16..H^1）、`rktcrypto_ghash_region_x86`。数据：gate 0/7500（seal/open/原地/篡改，128/256 位密钥，
长度含每个 256 倍数与随机尾部，oracle=关 VAES+VPCLMULQDQ 的两趟路径）；harness seal 16 KB
12927 vs 4292 MB/s、1 MiB 15643 vs 4409；integration 77/77；基准 aes-256-gcm 8822→10032 MB/s（探针 6875）。
分析（推断）：C 级 1 MiB 15.6 GB/s 而 Racket 基准 10.0 → 每 MiB 约 37 µs 的 Racket 侧开销（疑为输出
bytes 分配/清零），需单独定位；C 级 16 KB 12.9 vs OpenSSL 22.8（0.57×），每 256 B 块约 132 条向量
µop（56 vaesenc + 16 clmul + ~60 其他）接近端口吞吐界而非延迟链 → 调优清单：2-clmul 蒙哥马利式约简
（−25 op）、轮密钥常驻 15 个 zmm（.simd avx512 下可容）、s/d 寄存器乒乓省 4 次拷贝、vpternlogq 三路异或、
32 块一次约简（H^32 表）。

**X3-2a 已落地（2026-10-21，已验证）**——`crypto/asm/x86/chacha20_avx512.asm`：state-in-lanes 布局 16 块/单元
（寄存器 i = 全部 16 块的字 i），`vprold` 旋转，`.for` 四层嵌套（轮/列-对角/半步/列）由 `${}` 索引算术与
`${if}` 生成 960 条轮指令，嵌入广播 `dword ptr [st+4i]{1to16}` 加回原状态，16×16 dword 转置 =
unpack(dq)+unpack(qdq)+vshufi32x4×2（imm 0x44/0xee 再 0x88/0xdd），计数器 `add dword ptr [st+48], 16`
按规范 mod 2^32 回绕；`.simd avx512` 下分配到 xmm0–20。接入 `rktcrypto_chacha20_xor`（≥1024 B 的整单元）。
数据：gate 0/6000（oracle=关 AVX512 位的标量路径；长度含每个 1024 倍数与随机尾部、计数器 2^32 回绕、
原地、AEAD seal/open）；harness 1 MiB XOR 10695 vs 1000 MB/s（10.7×），AEAD seal 2844 vs 796；
integration 77/77；基准 chacha20-poly1305 743→2503 MB/s。瓶颈转为标量 radix-2^26 Poly1305 → X3-2b。

**X3-2b 已落地（2026-10-21，已验证）**——`crypto/asm/x86/poly1305_x86.asm`：radix-2^64 Poly1305 块循环
（h 三肢、r=(r0,r1)、s1=r1+r1>>2；每块 4 条 `mulx` + 2 条 `imul` + 2^130≡5 部分约简，OpenSSL base-2^64 同构）；
`m` 实参在 rdx（mulx 隐式源）须先移出，分配器把 h0 合并进 rdx（合法：h0 在 rdx 重定义前已死）。C 侧
`poly1305_blocks` 在 ≥64 B 时把 radix-2^26 累加器/r 转成 2^64（先归一化进位，`unsigned __int128`），
调内核后转回（h4 可达 2^27，radix-2^26 乘法可吸收）；cpu.c 加 BMI2+ADX 位。数据：gate 0/4200
（oracle=关 BMI2ADX 位的 radix-2^26 路径；随机分片 update、r 钳位极值、全 0xff 块、AEAD seal/open）；
harness 1 MiB MAC 6402 vs 3907 MB/s，AEAD seal 3995 vs 2850；integration 77/77；基准 chacha20-poly1305
2503→3257 MB/s。两趟合成 1/(1/10.7+1/6.4)=4.0 GB/s（OpenSSL ≈6.5）→ X3-2c 融合（ChaCha 向量 +
Poly 标量同循环）+ Poly 双路（h、h′ 配 r²）。
**Racket 侧开销（lan-11 已验证）**：`(make-bytes 1048592)` 每次 49 µs（清零 + 新页），超过 1 MiB
AES-GCM 的 C 时间（67 µs）——`aead-encrypt` 的输出缓冲分配是 Racket 基准 10.0 vs C 15.6 GB/s 的主因；
候选：不清零分配原语（C 调用覆盖全部字节）或复用缓冲 API。

**X3-1d 已落地（2026-10-21，已验证）**——GCM 调优：llvm-mca（x86_64 llvm 19，`-mcpu=znver5`）把瓶颈报为
FP 管线 0/1 饱和（vaesenc/vpclmulqdq zmm 按双泵建模），但独立 CTR 内核 39.8 GB/s（56 条 vaesenc/256 B 约 33
周期）证明本机 vaesenc zmm 并非双泵，融合循环实为每块 GHASH 串行链（~50–60 周期/约简）所限 → 结构改为
**512 B 块、8 个 zmm（32 块）对 H^32..H^1 一次约简**（链成本/字节减半，AES 吞吐成为上限）；H^32 表由
`rktcrypto_gcm_htab_vaes` 向量化生成（C 算 H²/H³/H⁴/H⁸/H¹⁶ 五次串行乘，内核以 3 层相关度做 7 次 lane-wise
乘：行 6 = 行 7·H⁴，行 5,4 = 行 7,6·H⁸，行 3..0 = 行 7..4·H¹⁶），避免每次调用 31 次串行乘。常驻轮密钥试验
仅 +1.4%（且挤占 d0–7 的寄存器预算）已撤回；`vpternlogq` 三路异或保留。驱动回读比对忽略函数间对齐 nop。
数据：gate 0/7500（篡改清零期望随块大小改为 ≥512 B）；harness seal 16 KB 17.8–18.8 GB/s、1 MiB
21.2–22.5 GB/s（OpenSSL `speed -evp` 16 KB 22.8 → 1 MiB 已持平，16 KB 0.78–0.82×，差额=每次调用的
H 表（~5 次串行乘 + 内核）与 J0/aad/尾部固定开销）；integration 77/77；基准 aes-256-gcm 10161→11551 MB/s
（含 49 µs/MiB 的 make-bytes）。

**X3-2c 已落地（2026-10-21，已验证）**——`crypto/asm/x86/chacha20poly1305_x86.asm`：ChaCha20 单元循环（同
chacha20_avx512）与标量 Poly1305（同 poly1305_x86，r 作内存操作数）融合，64 个 Poly 块按 `.for k, b*64/40,
(b+1)*64/40`（`.for` 边界为编译期表达式）摊到 40 个半轮之间，向量管线与整数乘法器并行；C 侧
`rktcrypto_chacha20poly1305_fused`（x86 ELF 定义，aead.c 的 ARM 融合分支守卫扩到 x86 ELF）：加密=单元 0 走
普通内核、融合内核吸收**上一单元**密文、末单元事后 update；解密=融合内核吸收**本单元**密文（Poly 读在
存储之前，原地解密安全）。Poly 状态 radix 2^26↔2^64 转换提为 `rktcrypto_poly1305_export64/import64`。
**修正既有缺陷**：aead.c open 的尾部原先先解密再 update（原地时 MAC 吸到明文，ARM 路径同样），改为先认证
后解密。数据：gate 0/3000（seal/open/原地/篡改清零，长度含每个 1024 倍数与随机尾部）；harness seal
16 KB 5650、1 MiB 6033 MB/s（标量 ~750；两趟内核 4.0 GB/s；OpenSSL ≈6.5）；integration 77/77；基准
chacha20-poly1305 3257→5018 MB/s。再往上=Poly 双路（h,h′ 配 r²，链减半）。

**X3-3a 已落地（2026-10-21，已验证）**——`crypto/asm/x86/p256_mul_x86.asm`：P-256 蒙哥马利乘（MULX + adcx/adox
双进位链，n0=1 的 Solinas 约简：acc[i+1]+=m<<32、acc[i+2]+=m>>32、acc[i+3..4]+=m·poly3，常数 poly3/poly1/zero
入 rodata 作内存操作数以省 GPR（15 个池全用），最后一次常数时间条件减 p（cmovc）；b 指针在 rdx 先移出）。
C 侧 `rktcrypto_p256.c` x86 ELF 分支：`fp_mul/fp_sqr/mont_mul(ctx==&FP)` 运行时按 BMI2+ADX 分派（不缓存
特征字，保持测试钩子有效；首版缓存导致 harness 的"portable"对照实为内核，已改）。DSL 加条件码别名
（cmovc→CMOVB 等 jcc/cmovcc/setcc，回读比对同样归一）。数据：gate 0/200200（200k 随机/边界输入 vs
harness 内 u128 CIOS 参考实现，+ pubkey/ECDH/ECDSA 交叉验证与篡改签名拒绝）；harness 乘法 161 Mops/s
vs 参考 27；pubkey 134.4 vs 30.2 kops/s（4.45×）；integration 77/77；基准 p256 ecdh 55.2→30.3 µs/op、
ecdsa sign 18.5→12.3、verify 63.5→37.9（vs OpenSSL 41.3k/95.8k/31.2k ops/s → 0.80/0.85/0.85×）。
待做 X3-3b：标量阶 `mont_mul_x86(ctx)`、sqrn 专用、点运算内核（ARM 侧 jac_double_hw/mixed_add_hw 经验 ~12%）。

**X3-4a 已落地（2026-10-21，已验证）**——`crypto/asm/x86/keccak_avx512.asm`：Keccak-f[1600]，5 个 zmm 各装一个平面
（lane x = s[x+5y]，lane 5–7 闲置，掩码装载/存储），theta=2 条 vpternlogq(0x96)+2 条 vpermq+vprolq，rho=5 条
vprolvq（偏移表入 rodata），pi=5×5 掩码 vpermq（输出平面 Y' 的索引向量 = 按 3Y' mod 5 的 lane 旋转，掩码 k0–k4
选 lane），chi=2 条 vpermq+vpternlogq(0xd2)，iota=掩码广播 xor；两轮一迭代交替两组寄存器免拷贝。接入
`keccak_f()`（AVX512 位）。数据：gate 0/20001（20k 随机/全 0·全 1 状态 vs 便携置换 + FIPS 202
SHA3-256("abc")）；harness 532 vs 272 MB/s（1.96×，按 136 B/置换折算）；integration 77/77；基准 sha3-256
313→498 MB/s、sha3-512 263（OpenSSL sha3-256 ≈760 → 0.65×）。分析（推断）：单流置换为延迟界——pi 的 5 次
掩码 vpermq 串行（~15 周期）+theta/chi 链 → 每轮 ~35 周期、每置换 ~1300 周期；可改 vpermt2q 两两合并树
（深度 3，约 −11%）；ML-KEM/ML-DSA 的 `keccak_f1600_x2` 双态交错可得近 2× 吞吐（下一步）。

**X3-3b 已落地（2026-10-21，已验证）**——`mont_mul_x86(r,a,b,ctx)`：标量阶的通用蒙哥马利乘（同文件；m=acc[i]·n0 用
imul，acc+=m·M 走 mulx+adcx/adox；imul 破坏标志后用 `xor d.t0` 清零；零常量走内存以保持 15 个 GPR 内），
`mont_mul_dispatch` 对 ctx≠&FP 分派到它。数据：gate 0/300200（+100k 通用参考差分，模 n 与模 p 两种 ctx）；
基准 ecdsa sign 12.3→11.2 µs/op（89.5k ops/s，OpenSSL 95.8k → 0.93×）、verify 37.4、ecdh 31.0。

**X3-4b 已落地（2026-10-21，已验证）**——`crypto/asm/x86/sha512_x86.asm`：标量 SHA-512（BMI2 `rorx` 做 Σ/σ，
8 个状态字常驻寄存器跨块，80 轮展开并把 a..h 轮转折入寄存器名 `s${(k+8-i%8)%8}`，16 字消息环放在调用方
的 `hw[24]`（状态 8 + 环 16，DSL 尚无栈帧），每轮 ~22 条 + 调度 ~17 条）。接入 `sha512_transform`
（单块）与 `core_update` 的整块批路径（状态跨块驻留）。数据：gate 0/3001（随机分片 update、SHA-384 IV
混测 + FIPS 180-4 "abc"）；harness 1164 vs 697 MB/s（1.67×）；integration 77/77；基准 sha512 635→1023 MB/s
（OpenSSL 1519 → 0.67×；C 级 0.77×）。下一步 X3-4c：AVX2 向量化消息调度（4 字 σ0/σ1，交错进标量轮），
预计 ≈1.4–1.5 GB/s（OpenSSL 的做法）。

**X3-4c/4d 调优（2026-10-21，已验证）**——SHA-512：轮内先加 Ch 再加 Σ1（e 链 5 周期），1164→1179 MB/s（噪声内）；
试验：ymm 向量化调度（σ0/σ1 四字一组、交错进轮）+3%、再把 K 折进调度 +0%（perf stat IPC 4.2：
端口混合/链共同限制，非指令数），均不采用，保留标量版；基准 sha512 1054（OpenSSL 0.69×）。Keccak：pi 改
vpermi2q 合并树（平面 0,1 | 2,3 | 合 | 4，深度 3），532→564 MB/s（+6%），基准 sha3-256 497→525（0.67×）。
DSL 加 `.frame N`（push 之后分配、`ret` 前释放，按返回地址+push 数补齐 16 字节对齐；主机测试 +1 组）。

**基准口径修正（2026-10-21，用户指出）**：`crypto-benchmark.rkt` 的 AEAD 行原先调用一次性 `aead-encrypt`，每次
迭代 `make-bytes` 1 MiB 输出（分配+填充+新页+GC，实测 46 µs/次，其中 GC 15.6），把 API 分配算进了"吞吐"；
且 MB/s 用 1048576 做除数（实为 MiB/s，比 OpenSSL 的十进制单位低 4.9%）。已改为：AEAD 行对预分配缓冲调用
`crypto-aead-seal!`（nonce 预分配），一次性 API 单独一行标明"allocates"，单位改十进制 MB/s，方法学写入
脚本头部（每次调用仍含密钥调度/H 表，openssl speed 复用上下文）。基线文件为机器本地，不入库。

**x86 内核总表（2026-10-21，lan-11 Zen 5，两次运行区间；Racket 基准=修正后同口径 / C 级 harness / OpenSSL 3.2.6
`speed -evp` 16 KB；均十进制 MB/s）**

| 原语 | X0 基线（MiB/s） | 现 Racket 基准 | 现 C 级 | OpenSSL | 比值（Racket / C） |
|---|---|---|---|---|---|
| sha256 | 2342 | 2662–2805 | 2665–2813 | 2642 | 1.0–1.06 |
| sha1 | 1360 | 2803–2957 | — | 2788 | 1.0–1.06 |
| aes-256-gcm | 117 | 29.6 GB/s（一次性 API 含分配 16.3） | 16 KB 24.1–25.3 / 1 MiB 28.6–31.2 GB/s | 23.4–25.0 GB/s（16 KB） | 1.18–1.26 / 0.96–1.01（16 KB） |
| chacha20-poly1305 | 744 | 7.49 GB/s | 16 KB 7.69–7.71 / 1 MiB 8.17–8.37 GB/s | 6.56–6.95 GB/s | 1.08–1.14 / 1.1–1.28 |
| sha512 | 663 | 1493 | 1578 | 1519 | 0.98 / 1.04 |
| sha3-256 | 313 | 807 | 826 | 779 | 1.04 / 1.06 |
| p256 ecdh | 55.2 µs | 24.3 µs | — | 24.2 µs | 1.00 |
| p256 ecdsa sign | 18.5 µs | 10.1 µs | — | 10.4 µs | 1.04 |
| p256 ecdsa verify | 63.5 µs | 30.7 µs | — | 32.0 µs | 1.04 |
| x25519 shared | 21.5 µs（X0 基线 22.5） | 17.0 µs | — | 18.3 µs | 1.08 |
| ed25519 sign | 17.3 µs | 9.1 µs | 8.64–9.07 µs | 16.0 µs | 1.76 / 1.76–1.85 |
| ed25519 verify | 42.9 µs | 24.8 µs | 23.5–24.8 µs | 47.7 µs | 1.92 / 1.92–2.03 |

同口径下 Racket 基准与 C 级一致（原语调用开销 ≤2%）；"Racket 比 C 慢"的早先结论撤销。与 OpenSSL 的剩余差距
按来源分：AES-GCM 16 KB 为每次调用的密钥调度+H 表（API 一次性 vs 上下文复用，约 0.12 µs/次 C 级）；
SHA-512/SHA-3 为内核本身（轮链/置换延迟界）；P-256 为点运算仍在 C。

**X3-3c 已落地（2026-10-21，已验证）**——`mont_sqr_p256_x86`：专用平方（6 个非对角积一次 adc 链翻倍 + 4 个对角积，
再 4 次约简；约简步提为 `.macro P256_REDUCE i`，mul/通用乘改用宏后 `.S` 逐字节不变）；`fp_sqr` 分派到它。
首版在 a1·a2/a1·a3 两行之间丢了一个进位（29% 输入失败，差分门禁抓到），改为先算 a1·a3 让 acc5 先存在。
数据：gate 0/400200；sqr 185 vs mul 153 Mops/s（1.21×）；integration 77/77；基准 p256 ecdh 30.8→28.3 µs
（0.86×）、ecdsa sign 11.0→10.4 µs（96.5k ops/s vs OpenSSL 95.8k，**持平**）、verify 36.8→34.9 µs（0.92×）。

**X3-5a 已落地（2026-10-21，已验证）**——`crypto/asm/x86/x25519_x86.asm`：GF(2^255−19) radix-2^64 内核 `fe64_mul/sqr/
mul121665`（mulx/adcx/adox 行 + 38 折叠 + 顶字再折 + 掩码 38 吸收末进位，宏 `FE64_REDUCE`），C 侧 fe64 阶梯
（add/sub/cswap/frombytes/tobytes/invert 用 `unsigned __int128`，tobytes 两步规范化），BMI2+ADX 时分派。
数据：gate 0/3001（随机 + 0/1/p−1/p/p+1/2^256−1/基点 等边界点 + RFC 7748 向量，oracle=关位的 radix-2^51 阶梯）；
harness 41.3 vs 40.4 kops/s——**无增益**：gcc 对 radix-2^51 `__int128` 代码内联良好，而每次内核调用付 6 对
push/pop + 内存往返，抵消了 mulx 的收益；基准 x25519 shared 23.9 µs（OpenSSL 18.3 → 0.77×）。
→ X3-5b：用 `.macro` 把整步阶梯（5 mul + 4 sqr + mul121665 + add/sub）合成一个内核（操作数在 `.frame` 槽），
去掉 11 次调用开销。

**X3-5b 已落地（2026-10-21，已验证）**——`x25519_step_x86`：整步阶梯一个内核：mul/sqr/mul121665 体改成内存操作数
宏（`FE64_MULM r,a,b` 等，参数是"基址 + 偏移"文本），add/sub 也是宏（进位/借位两次折叠），9 个临时量在
`.frame 320` 槽，去掉每步 11 次调用的 push/pop 与实参搬运；C 侧每比特 cswap 后调一次。
数据：gate 0/3001；harness 56.1 vs 38.4 kops/s（1.46×）；integration 77/77；基准 x25519 shared 23.9→17.0 µs
（58.9k ops/s vs OpenSSL 54.6k → **1.08×，反超**），keygen 17.2 µs。方法论结论：在 x86 上 15 个 GPR 装不下
寄存器驻留的点/阶梯运算，但"宏合成 + 帧槽"消掉调用开销就足够超过编译器内联的 `__int128` 代码。

**X3-3d 已落地（2026-10-21，已验证）**——P-256 点运算内核 `jac_double_x86`/`mixed_add_x86`：域乘/平方体改成内存
操作数宏 `P256_MULM/SQRM`（与函数版逐字节同源），`P256_ADDM/SUBM` 与 `mont_add/mont_sub` 语义一致（完全约简），
`P256_FINAL` 条件减 p；按便携实现的运算顺序合成，临时量在 `.frame 384/392` 槽；mixed_add 把 r 指针存帧槽以
腾出寄存器，H=0 的退化情形以返回值交回 C（1=倍点、2=无穷远）。DSL 顺带修：`xor d.ret, d.ret` 被当作读取使 out
寄存器全程活跃（清零惯用法改为纯定义）、`${}` 任意行求值、压力错误列出活跃集。数据：gate 0/401500（300 轮
pubkey/ECDH/ECDSA 交叉验证 + 域级差分）；harness pubkey 138→153 kops/s；integration 77/77；基准 p256 ecdh
28.3→24.3 µs（41.1k ops/s vs OpenSSL 41.3k → **1.00×**）、ecdsa sign 10.4→10.1（99.5k vs 95.8k → **1.04×**）、
verify 34.9→30.7（32.6k vs 31.2k → **1.04×**）。

**X1-2b/2c 已落地（2026-10-21）——分配器的溢出与 ABI 能力**（用户指出：要的是带寄存器约束/ABI 语义的算子，
而非文本宏绕开）：
- 溢出：Chaitin-Briggs 着色失败时不再报错，选压力点上活跃最久/提及最少的值进帧槽（用前装入临时量、定义后存回，
  纯 `mov`/`vmovdqu64`/`kmovq` 不碰标志位），循环重分配；溢出区在 `.frame` 之上，发射器扩帧。
- `.call NAME(a,…)`：实参经临时量进 SysV 寄存器（`[mem]` 走 lea），调用定义全部 caller-saved GPR + 全部向量/掩码
  寄存器，跨调用值自动进 callee-saved 或溢出；`call NAME@PLT`；调用点 rsp 16 对齐。
- 预着色兜底：入参/出参跨其 ABI 寄存器重定义（典型：跨 `.call`）时自动入口拷出/`ret` 前拷入，不再报
  "argument conflicts with its register"；配合调用实参临时量解决入参被前一个实参搬运覆盖的问题。
- 真机验证：mixed_add_x86 改为让分配器自动溢出 r 指针（替代手工帧槽），加 `.call` 探针 `p256_mul3_x86`
  （两次 `.call mont_mul_p256_x86`），走 P-256 门禁。主机测试 +3 组（溢出 GPR/向量、.call）。

**X3-4e 已落地（2026-10-21，已验证）**——`keccak_f1600_x2_x86`：两个独立状态交错（A 在 s0–9、B 在 s10–19，共享
索引向量，31 个向量寄存器），接入 `rktcrypto_keccak_f1600_x2`（ML-KEM 矩阵展开的 XOF 对）。数据：gate 0/30001
（含 10k 对随机/取反状态）；harness 850 MB/s（两态合计，单态 567 → 每态 1.5×）；integration 77/77；基准
ml-kem-768 keygen 26.8→24.4 µs、encaps 26.4→23.9、decaps 30.7→28.2（ML-DSA 不用 x2，不变）。

**X3-2d 已落地（2026-10-21，已验证）——模块 1 ChaCha20-Poly1305 收口**：`poly1305_ifma.asm`：AVX-512 IFMA 八路
Poly1305（radix 2^44，lane k 以 r^8 吸收每第 8 块，末组按 lane 乘 r^(8−k) 后求和；3×3 肢积 = vpmadd52luq/huq
对，高半部左移 8 进下一肢，位置 3 以 20 回绕，一次进位）；C 侧用 radix-2^64 的 `poly_mul130`（与 MULX 内核同式）
算 r^1..r^8 并转 2^44 建 10 行表，≥256 B 的整组走 IFMA，余数走 MULX。差分抓到两处胶水错误：lane 和转回
radix 2^64 时 l1 被重复计入；lane 和可超 2^130 几位而 MULX 内核要求 h2 很小（imul h2·s1 溢出），加一次
2^130≡5 折叠。数据：gate 0/7200；MAC 17.67 GB/s（MULX 6.07、radix-26 3.66）。AEAD 主体改为两趟
（ChaCha 单元 → IFMA Poly；解密先 MAC 后解密以保原地安全）：C 级 seal 1 MiB 6.42 GB/s（标量融合 6.03）、
16 KB 6.05；基准 chacha20-poly1305 5.90→6.35 GB/s（OpenSSL 6.56 → **0.97×**）。后续可选：把 IFMA 组插进
ChaCha 轮（估 ~8.5 GB/s），需 8-lane 状态跨单元传递。

**X3-4f 已落地（2026-10-21，已验证）——模块 2 SHA-3 收口**：`keccak_scalar.asm`：标量 Keccak-f[1600]，lane 驻内存
（调用方状态与 `.frame` 缓冲逐轮交替），theta 列奇偶在 chi 写出时顺手累加进帧区，每轮开头 15 条算 D，每行
5 lane 各 load+xor D+rol、chi 用 `andn`+xor，两轮一迭代（宏 `KECCAK_ROUND src,dst,rcoff`，25 个 lane 序列由
脚本一次生成后以可读 .asm 入库）；15 个 GPR 正好用满，无溢出。单流分派改到它（AVX-512 版受 512 位 shuffle 吞吐
限制：每轮 32 次），双态仍用向量 x2。数据：gate 0/50001；harness 826 MB/s（AVX-512 568、便携 229；x2 双态合计 852
≈ 两次标量）；integration 77/77；基准 sha3-256 554→807 MB/s（OpenSSL 779 → **1.04×**）、sha3-512 295→429。

**X3-4g 已落地（2026-10-21，已验证）——模块 3 SHA-512 收口**：`sha512_avx512.asm`：标量轮不变（rorx Σ、Ch 先于 Σ1、
Σ0+Maj 先合成 T2 再加，e/a 链各 5 周期），消息调度搬到 AVX-512VL ymm：四字一组、四个 ymm 作 W[t-16..t-1] 环，
σ0 与 W[t-16]/W[t-7] 项一步四 lane（`valignq` 取错位窗口），σ1 依赖距离为 2 故分两半（先对最新组的 lane 2,3
得 W[t],W[t+1]，再对其得 W[t+2],W[t+3]，各用一次补零 `valignq` 放位），W+K 存入 `.frame 640`，每轮只读一个内存
操作数；组 g+4 在组 g 的四轮中分四片插入（16 轮余量）。诊断依据：标量版 perf 探针 617 周期/块=7.7 周期/轮、
41 条/轮其中 12 条 rorx/shr（移位管线 2 条）；新版 460.7 周期/块=5.76 周期/轮、31.4 条/轮（移位类 6）、IPC 5.46，
距 5 周期链界 15%。之前 2 lane xmm 调度只得 +3% 的原因是 lane 数不够、移位类指令仍留标量侧。数据：gate 0/6001
（AVX-512 版 vs 标量版 vs 便携三方一致）；harness 1488–1578 MB/s（标量 1109–1169、便携 662–700；区间=全量验收中与单独运行）；make base、self-test #t、
integration 77/77；基准 sha512 1121→**1493 MB/s**（OpenSSL 1519 → **0.98×**）。BMI2-only 机器仍走标量版。

**X3-4h 已落地（2026-10-21，已验证）——模块 4 AES-GCM 融合内核重排**：尺寸扫描（n=0..1 MiB 拟合 a+b·n）先定位：固定开销
126 ns（OpenSSL 复用上下文下约 110）不是主因，主因是体吞吐 22.4 GB/s（OpenSSL 8K→16K 差分推算约 30）。消融变体
（去 GHASH 2.48 / 去 AES 2.43 周期/块，合体 4.10）说明两半各自接近管线界却几乎不重叠：原内核把前一块的 62 条 GHASH
+42 条折叠/归约整段放在循环顶部，32 条 vpclmulqdq 排队占满 FP 调度器，AES 进不来。微基准建立 Zen 5 端口模型：
vpclmulqdq 任何宽度均 4 个 FP µop、每 2 周期 1 条（单元独占）；vaesenc/vpshufb/vpslldq/vextracti 共用两条管线
（2/周期）；vpxorq 4/周期；FP 合计约 4 µop/周期为总闸。新内核由 Racket 发射器 `asm/gen/gcm-vaes-x86.rkt` 生成：
八条 AES 链同时推进（8 zmm，4 周期延迟被两管线填满），每块 17 个槽（计数器/轮 0/轮 1..13/末轮/异或存储），前一块
密文的乘积（Karatsuba：3 乘 + 字交换 + 异或，第二张表存 lo^hi）按约 2 条乘/槽摊到槽 0..12，依赖累加器的 e0 块放
最后 4 槽；再前一块的原始和在槽 0..5 折叠+归约（头 5 条固定在槽 0 开头，先于新乘积写 lo/hi/mid），归约链领先消费者
整整一块；表行预乘 x^-1 使归约少掉 256 位左移 10 条；加密方向密文直接异或进 GHASH 寄存器（省 8 次拷贝）；两流各用
独立暂存（t/t2 对 r1..r3），因为一流的写/读对可能被槽边界拆开。每种密钥长度各一条直线路径（块 0 仅 AES、块 1 AES+
乘积、循环块 AES+折叠+乘积），尾声折叠剩余和并做最后一块的 GHASH。被否决的候选：轮密钥改 m512 操作数（FP µop −15
但更慢）。A/B（同机交替 5 次取最小）：加密 4.107→2.771 周期/块（22.0→32.6 GB/s）、解密 3.828→2.719；FP µop
382→≈350/块组；gate 0/7500；harness 16 KB 17.7→23.1–24.8 GB/s、1 MiB 21.5→28.6–31.2；AES 对便携差分 0/65121；
make base、self-test #t、integration 77/77；基准 aes-256-gcm（1 MiB，预分配 seal!）19920→**29600 MB/s**（OpenSSL 16 KB
23.4–25.0 → 体吞吐反超；16 KB 口径 C 级 0.93–0.99×，余下差距=每次调用的密钥调度/H 表 126 ns 对上下文复用）。

**X3-4i 已落地（2026-10-21，已验证）——模块 5 ChaCha20 双组内核**：定位：`openssl speed` chacha20 单独 10.4 GB/s、我们的
16 块内核 10.1（551 周期/单位，IPC 2.0）；裸双轮微基准（perf 周期）单组 16 块 51.5 周期/双轮（24 条链，每条 op 实测
约 2 周期延迟）、IPC 1.9，两组 32 寄存器交错 61.3 周期/32 块（IPC 3.2）；ymm 延迟相同故无益。原内核的 2 倍差距只靠乱序
窗口跨单位重叠。新内核 `rktcrypto_chacha20_blocks2_avx512`：2048 字节单位，两组各 16 块、全部 32 个 zmm 作状态，
轮内按 4 条一段交错；轮阶段零暂存（索引向量/原状态全用内存操作数与嵌入广播）；收尾先把 B 组存入 `.frame 1024`，
A 组用 4 个暂存完成状态回加/转置/异或存储，再装回 B 组同样收尾。分配器陷阱：B 组收尾若复用 A 组的暂存名 t0..t3，
分配器把该名的活跃区拉过整个循环体，多溢出 4 个状态寄存器——改用独立名 u0..u3 即零溢出（待查 regalloc 的
再定义暂存处理）。C 侧 `chacha20_units_avx512` 把 1024 单位数拆成双单位对 + 尾部单单位，普通 XOR 与 IFMA 两趟
融合路径同用。数据：内核 34.3→23.6 周期/块（IPC 2.0→2.94；FP 4 µop/周期界 17.3）；gate 0/6000、0/3000；
harness chacha20 10.1→15.0 GB/s（OpenSSL 10.4 → **1.45×**）、chacha20-poly1305 seal 16 KB 6.07→7.69、1 MiB 6.46→8.17–8.30
（OpenSSL 6.56–6.95 → **1.1–1.26×**；两趟和 1/(1/15+1/18.6)=8.3 即上限）；全量验收 14 gate 全过、AES 差分 0/65121、
integration 77/77；基准 chacha20-poly1305 6328→**7494 MB/s**（Racket 层比 C 级 1 MiB 8290 低 10%，此前两者相差 1%，
待查 Racket 侧 seal! 路径的固定/比例开销）。后续候选：IFMA Poly 塞进单组 ChaCha 的
空闲 FP 槽（单组 IPC 1.9 留有余量，估 ~10 GB/s）。

**分配器 def-use web 拆分（2026-10-21，已验证）**：起因=ChaCha 双组内核里 B 组收尾复用 A 组的暂存名 t0..t3 时多溢出
4 个状态寄存器：分配器按"名"建节点，t0 同时与 A 阶段（x0..15）和 B 阶段（y0..15）的活跃集干涉，而 x、y 在轮阶段又
两两干涉占满 32 色，t0 需第 33 色。现在 `regalloc.rkt` 在溢出轮之前先做到达定义（按名的定义位 bitset 前向数据流）
+ 并查集把每个名拆成 def-use web（共享一次使用的定义归一 web；读改写指令把自身定义并入其读到的 web；参数的入口
web、结果到达 ret 的 web 保留原名，其余命名 `name~wK`），各 web 独立分配。连带修正：XED 的条件写 `cw`（cmovcc）
此前当纯定义，web 拆分后 `sub r0..; cmovc r0, acc` 的两个定义分成两 web 而被分到不同寄存器（generic mont_mul 10%
mismatch）——现按读改写处理；掩码修饰符 `{k.m}` 内的 k 寄存器读也参与重命名（aes_ctr 全计数器路径此前错 mask）；
向量溢出按函数宽度选 movdqu xmm / vmovdqu ymm / vmovdqu64 zmm（非 AVX-512 函数不再被塞进 zmm 指令）。
`tests/alloc-tests.rkt` 修复了 10 处陈旧断言（ret 计入函数体、溢出取代报错、发射格式单空格、调用对齐）并在失败时
以非零退出；新增 web 测试。全部 14 个内核重新分配（x25519 少一个 push/pop 对、p256 少 8 个），lan-11 14 gate 全过、
AES 差分 0/65121。

**X3-4j 已落地（2026-10-21，已验证）——模块 6 Ed25519 fe64 路径**：基准 ed25519 sign 18.0 µs（OpenSSL 16.0 → 0.89×，
全表最低）、verify 44.6（OpenSSL 47.7）。分析：sign 做两次定基标量乘（API 只有 32 字节种子，公钥每次重算；OpenSSL 的
密钥对象带公钥只算一次——API 扩展为 64 字节 seed||pk 可再省一半，留待用户决定）；每次标量乘 64 次 comb 查表各
16 项×15 字的 cmov（约 675 条/次）+ 64 次 fe51 __int128 混合加；两次 tobytes 各一次求逆。落地：`x25519_x86.asm` 增
Ed25519 点运算内核——`ed25519_madd_x86`（7 乘，缓存仿射）、`ed25519_add_x86`（统一加 9 乘，2d 由指针传入）、
`ed25519_dbl_x86`（4 平方 4 乘，帧内零元做取负）均由 FE64_MULM/SQRM/ADDM/SUBM 宏在 `.frame` 槽上合成（结果可与
首输入别名：输入先全部消费进帧）；`ed25519_lookup_x86`：AVX-512 常数时间查表（16 项各 128 字节全部装载，
vpcmpeqd 掩码 + vpblendmd 混入，无数据相关寻址）。C 侧（`rktcrypto_ed25519.c` x86 ELF 段）：fe64 加减/编码/求逆/
pow22523、ge64 运算、comb 表由 fe51 表一次性转换（128 KB，条目 128 字节对齐）、sign 两个编码共用一次求逆
（Montgomery 技巧）；运行时 BMI2/ADX+AVX-512 分派，fe51 代码保留为便携路径与 oracle。门禁表加 5 列（共享 .asm
的行），gate 链接列表去重。数据：gate 0/7503（公钥/签名逐字节一致、双向验签、篡改拒绝、RFC 8032 向量）；
harness sign 25.7→**8.64–9.07 µs**（OpenSSL 16.0 → **1.76×**）、verify 51.8→**23.5–24.8 µs**（OpenSSL 47.7 → **1.93×**）；
全量验收 15 gate 全过、AES 差分 0/65121、make base、self-test #t、integration 77/77（含 RFC 8032 向量）；基准
ed25519 sign 18.0→**9.1 µs**、verify 44.6→**24.8 µs**。

**X3-4k 已落地（2026-10-21，已验证）——模块 7 AES-GCM 每次调用固定开销**：探针分解（融合路径 n=512 共 1197 周期）：
H 表 75.6 ns 占固定开销六成（C 侧 5 次串行 gfmul 内建 + 内核 7 次向量乘 + 32 项标量 x^-1 缩放与 Karatsuba 行
+ memcpy）。新 `rktcrypto_gcm_htab_vaes(htab, H)` 一趟完成整张 1280 字节表：H 先乘 x^-1，之后全部幂在 x^-1 缩放域
里相乘（a'·b' 的反射乘积经"仅折叠"短归约直接得 (a·b)'，每次乘少 10 条、链更短，且无需事后缩放）；xmm 上 H^2、
H^3/H^4、H^8、H^16（深度 4），拼出第 7 行 [H^4 H^3 H^2 H]，H^4/H^8/H^16 经 vshufi32x4 广播到各 lane（寄存器源
无广播指令），7 次向量乘得其余行（深度 3）；Karatsuba 行 vpshufd+xor 直接生成；区域助手要的明文 H^16..H^1 由
第 4..7 行反缩放（右移一位，底位折回 x^128 = 0xE1..00）得到。C 侧 setup 退化为一次内核调用（便携分支保留 C 构造）。
A/B（perf 周期，交替，三次取最小）：表 75.6→49.5 ns；融合 seal n=512 1197→1009 周期/次、16 KB 3794→3652
（671→646 ns，**25.3 GB/s，OpenSSL 25.0 → 1.01×**）；gate 0/7500；全量验收 15 gate 全过、AES 差分 0/65121、
make base、self-test #t、integration 77/77；基准 aes-256-gcm 29.6→31.3 GB/s（1 MiB）。余下固定开销：密钥调度 ~27 ns、H 与 E(J0)
各 ~10 ns（可配对流水，−10 ns，未做）、首块内核 ~40 ns、长度块 GHASH 与胶水；上下文复用 API 仍是最大杠杆（用户决定）。

**X3-5 已落地（2026-10-22）——API 扩展与回退层**（用户 2026-10-21 定调"API 可以多做；性能不足和回退的情形增强"）：
- **展开密钥 API**：C `rktcrypto_aead_expanded_key_size/expand_key`（记录 = 头 16 + AES 密钥调度 240 + H 16 + x86 ELF 上
  融合内核 1280 字节表；CCM 只用前 272；ChaCha 族无可预计算，返回 0→Racket 层返回密钥副本），`rktcrypto_aead_seal/open`
  按 key_len == 展开长度识别（校验 magic/alg）；GCM/CCM 核心重构为"已备好密钥调度"版本，融合路径接受预置表。
  Racket：新内核原语 `crypto-aead-expand-key`（kernel.ss 登记，版本 9.3.10→9.3.11，base 包 info 同步 9.3.11），
  `crypto-aead-seal!/open!` 接受两种长度；`racket/crypto/aead` 导出 `aead-expand-key`；参考文档与 core 测试已加。
- **Ed25519 展开私钥**：`rktcrypto_ed25519_expand`（seed||pk）与 `rktcrypto_ed25519_sign_expanded`（免重算公钥）；
  `crypto-ed25519-sign/public-key` 接受 32/64 字节；`ed25519-expand-private-key`（Racket 侧拼接）。
- **FFI 表**：`rktcrypto.rktl` 由手工维护改回可全量再生——io.sls 补 `uint32_t/uint64_t` ftype（此前再生会因 pbkdf2/scrypt
  的 uint32_t 参数炸 io.so 编译）。`make derived` 需 parser-tools-lib + compiler-lib（lan-11 树里离线从本机包目录
  `raco pkg install -u --copy --deps force` 装入，parser-tools 的 `module+ test` 子模块因无 rackunit 用脚本剥除）；
  本机 Homebrew Racket 9.3.5 无 `unsafe-hasheq-from-vectors` 不能当 derived 的宿主，只能用树内 racket。
  **`make derived` 失败会删 racket/src/bc/src/startup.inc，须 `git checkout -- <该文件>` 精确恢复**（已发生一次）。
- **回退层（无 AVX-512 的 x86：Intel 客户端 / Zen 2–3）**：`chacha20_avx2.asm`（8 块/512 字节单位，16 ymm 装不下 16 字
  状态+暂存→d 行驻帧槽，每个 QR 取一次写一次，旋转 16/8 用内存掩码 vpshufb、12/7 用移位对，两 QR 交错；帧只 16 字节
  对齐故全用 vmovdqu）：1.0→4.5 GB/s；`gcm_aesni.asm`（发射器 `asm/gen/gcm-aesni-x86.rkt`：8 条 AES-NI 链 128 字节
  块，轮密钥/掩码/表行全内存操作数，GHASH 从内存取（加密取上一块输出、解密取当前块输入且装载全在覆写槽之前），
  Karatsuba + x^-1 表、折叠在块尾）：4.4→7.3–7.7 GB/s；Ed25519 的 AVX2 查表内核 `ed25519_lookup_avx2_x86`
  （vpcmpeqd 掩码 + vpblendvb 内存操作数）让 fe64 路径在 BMI2 无 AVX-512 时也可用：sign 9.49 µs（AVX-512 查表 9.08）。
  门禁：gcm_aesni 0/12000、chacha20_avx2 0/8500、ed25519 avx2 层 0/9003（harness 以特征位清除切换层级，oracle 为更低层）。
- **验收（lan-11，9.3.11）**：make base、self-test #t、core 测试 crypto-aead/crypto-sign 全过、integration 77/77；基准
  aes-256-gcm 16 KB 23.45→**27.8 GB/s（展开密钥；OpenSSL 25.0 → 1.11×）**、1 MiB 31.0；ed25519 sign 9.1→**6.0 µs（展开私钥；
  OpenSSL 16.0 → 2.7×）**。rktcrypto.inc/.def 也须随头文件再生（`parse.rkt -c/-d`），否则新入口在 boot 的外部符号表里缺失
  （"unavailable: librktcrypto is not part of this Racket build"）；版本号变更会换用户作用域目录（9.3.10→9.3.11），
  构建辅助包须重装。

**X3-5b 已落地（2026-10-23）——回退层补齐到同口径对标**（用户指出回退层应与同机、同特征集的 OpenSSL 对照，
用 `OPENSSL_ia32cap` 屏蔽 CPUID 位；注意该变量为空串 = 全部清零，不可用作"默认"）。新增：`poly1305_avx2.asm`
（4 路 radix 2^26，表行作内存操作数，lane 顺序随 qword unpack 为 0,2,1,3，末组按 lane 幂 r^4,r^2,r^3,r；首版把
×5 项的表行索引错了 4 行，门禁 72% mismatch 定位后修正）；`gcm_aesni_sse.asm`（同一发射器 `--sse` 模式：两操作数
遗留编码，`op3`/`shift` 抽象在 d≠a 时补 movdqa；SSE 内存操作数须 16 字节对齐→C 侧把密钥调度与表拷到对齐缓冲，
输入异或经寄存器）；`chacha20_ssse3.asm`（4 块/256 字节单位，结构同 AVX2 版）；`RKTCRYPTO_CPU_X86_SSSE3` 位；
GCM 融合分派三层（3=VAES、2=VEX AES-NI、1=SSE）。gensrc 表的发射器列允许带参数。
同口径对照（lan-11，16 KB，MB/s；OpenSSL 3.2.6 同屏蔽位）：
| 特征集 | 原语 | 我们 | OpenSSL | 比值 |
|---|---|---|---|---|
| 无 AVX-512/VAES/IFMA（AVX2 层） | chacha20 | 4186–4332 | 4358 | 0.96–0.99 |
| | poly1305 | 7877–8314 | （反推 ≈8400） | ≈0.95 |
| | chacha20-poly1305 | 2684–2913 | 2977 | 0.90–0.98 |
| | aes-256-gcm | 6878（1 MiB 7303） | 6771 | 1.02 |
| 再去 AVX2（SSE/AES-NI 层） | chacha20 | 2122 | 2231 | 0.95 |
| | chacha20-poly1305 | 1562 | 1709 | 0.91 |
| | aes-256-gcm | 6869 | 7206 | 0.95 |
此前 SSE 层为 0.45 / 0.60。门禁：poly1305_avx2 0/10200、gcm_aesni_sse 0/15000、chacha20_ssse3 0/11000，全部 20 行
全过，AES 差分 0/65121，make base、integration 77/77。

**DSL `.simd avx512`（2026-10-21）**：函数级指令把向量池扩到 xmm0–31（16–31 仅在压力下使用）；分配后
驱动做可编码检查——落在 16–31 的寄存器要求指令有 AVX-512(EVEX) 形式，否则报错提示换 EVEX 助记符
（`vpxor`→`vpxorq`）。主机测试 +3 组。

### X2 — 调度模型（1 周）
- xlsx/XML → `data/latency-znver5.rktd` 转换器；调度器加 §2.6 规则；对照 `llvm-mca` 与 `perf stat` 周期数（±5% 内视为模型可用）。

### X3 — 内核（每内核 3–7 天，与 Apple M 经验一致）
顺序按 X0 差距与硬件红利：SHA-256（SHA-NI）→ AES-GCM（VAES+VPCLMULQDQ 四路，AES-NI 回退）→ ChaCha20-Poly1305（AVX2/AVX-512）→ Montgomery/RSA（MULX+ADCX+ADOX；AVX-512 IFMA 52 位作备选路线）→ P-256 → Keccak（AVX-512 或 BMI2 `rorx`）→ SHA-1/SHA-512 → 长尾。每个内核：C oracle 差分、OpenSSL 3.2.6 头对头、dudect（秘密路径）。

### X4 — 编码器（后置，2–3 周，可选）
- 解析 XED `PATTERN` 生成 `encode/config-x86/`，供 in-process `assemble`（deflate 研究线）与长度/对齐感知调度；`llvm-mc -show-encoding` 逐指令差分门禁。rktcrypto 不依赖它。

## 4. 风险与未决

1. uops.info 数据许可（**待核实**）；若不可再分发，只提交转换产物并记录来源版本。
2. XED `PATTERN` 语言复杂（前缀状态机、VEX/EVEX 字段）——故 X4 后置，X1 不碰。
3. （已消除）两地址等约束曾被设想为改造共享的 rewriter/分配器；按 §2 的独立模块方案，AArch64 管线不被触碰，`regen.sh check` 自然不变。
4. x86 内核不是 AArch64 `.asm` 的移植：指令集、寄存器压力、调度完全不同，是第二套实现；`.asm` 内核数量将翻倍，维护面随之增加（这正是原计划列为非目标的理由，现由 lan-11 的需求抵消）。
5. LLVM 对 znver5 调度模型的支持程度**待核实**；若仅 znver4 近似，以 58455 表与实测为准。
6. 分支归属：rktasm 树目前只在 `feat/native-pvector` 世系与本分支（`feat/repl-startup-analysis`）上，不在 `master`、不在 `feat/crypto` 工作树（**已验证** `git branch --contains`）；本文件与后续代码落在哪条线由用户定。

## 5. 立即步骤（本周）

1. 用户定分支归属与 lan-11 的使用边界（可否长期占用、是否可装 LLVM 到 `$HOME`）。
2. X0：lan-11 构建 + 基线表 + 三份数据的许可核实。
3. X1a 原型：XED `OPERANDS/FLAGS` 解析器，先覆盖 SHA-256 内核用到的助记符。
4. 两地址/EFLAGS 的设计 spike：以 SHA-256 内核为样例走通 DSL→分配→发射→`as`→差分。

## 5.1 开发环路的分工（已验证，2026-10-20）

- 本机（Apple Silicon，Apple clang 21）可以**交叉装配** x86-64 ELF：`clang --target=x86_64-unknown-linux-gnu -c foo.S`，Intel 语法 `.intel_syntax noprefix`，`mulx/adcx/adox/rorx`、`sha256rnds2`、`vaesenc ymm`、`vpclmulqdq/vpternlogq/vpmadd52luq/vprolq/vgf2p8affineqb zmm` 全部接受；Xcode 自带 `llvm-objdump`（`--x86-asm-syntax=intel`）可回读编码。因此 x86 模块的解析/分配/发射与"装配 + 回读逐字节比对"门禁都能在本机迭代；只有**执行**（C-oracle 差分、perf、openssl 持平）需要 lan-11。
- lan-11 的外网与经 ProxyJump 的链路实测只有 20–40KB/s（GitHub 拉取与 Fedora 镜像下载都慢），因此同步采用"root 属 `~/Documents/racket`（v9.0 全史）本地种子 + GitHub 只拉 v9.0..master 增量 + 19MB 私有提交 bundle（`merge-base..HEAD`，1920 提交）rsync 续传"的办法；LLVM 走 `dnf download` + `rpm2cpio` 装到 `~/opt/llvm19`（无 sudo）。

## 6.1 lan-11 头对头基线（2026-10-20，已验证；rktcrypto 1 MiB 单核 vs OpenSSL 3.2.6 `speed -evp` 16 KB 单核）

| 项 | rktcrypto（C + 现有 intrinsics） | OpenSSL 3.2.6 | 比值 | 差距来源（推断） |
|---|---|---|---|---|
| sha256 | 2342 MB/s | 2580 MB/s | 0.91× | 两边都是 SHA-NI；差在块循环/调度 |
| sha1 | 1360 MB/s | 2722 MB/s | 0.50× | OpenSSL 用 SHA-NI 的 SHA-1 指令，rktcrypto 无 x86 SHA-1 路径 |
| sha512 | 663 MB/s | 1484 MB/s | 0.45× | OpenSSL AVX2 asm |
| sha3-256 | 313 MB/s | 761 MB/s | 0.41× | OpenSSL AVX-512/AVX2 Keccak |
| sm3 | 655 MB/s | 641 MB/s | 1.02× | 两边标量 |
| chacha20-poly1305 | 783 MB/s | 6402 MB/s | 0.12× | OpenSSL AVX-512 ChaCha + AVX2 Poly |
| aes-256-gcm | 117 MB/s | 22804 MB/s | 0.01× | rktcrypto x86 modes 走便携查表 AES（见 X0 perf）；OpenSSL VAES/VPCLMULQDQ |

公钥（ops/s，单核）：

| 项 | rktcrypto | OpenSSL 3.2.6 | 比值 | 差距来源（推断） |
|---|---|---|---|---|
| p256 ecdsa sign | 54153 | 95831 | 0.57× | OpenSSL ecp_nistz256（ADX/BMI2 asm） |
| p256 ecdsa verify | 15742 | 31232 | 0.50× | 同上 |
| p256 ecdh | 18103 | 41316 | 0.44× | 同上 |
| x25519 shared | 46451 | 54613 | 0.85× | OpenSSL ADX 路径 |
| ed25519 sign | 57679 | 58485 | 0.99× | 持平 |
| ed25519 verify | 23334 | 19997 | 1.17× | 反超 |

RSA 不在 rktcrypto 基准清单里（OpenSSL：rsa2048 sign 5921 / verify 100549 ops/s），待补。

## 6. lan-11 实测（2026-10-20，ssh 直连，已验证）

- `Linux fedora 6.12.9-200.fc41.x86_64`，Fedora 41 Workstation；AMD Ryzen 9 9950X（Zen 5，16C/32T，L2 16×1MB，L3 2×32MB，最高 5.75GHz）；内存 60GB；`/home` 余 1.2TB。
- ISA 标志：`avx512f/bw/cd/dq/vl, avx512_bf16/bitalg/ifma/vbmi/vbmi2/vnni/vp2intersect/vpopcntdq, avx_vnni, vaes, vpclmulqdq, sha_ni, gfni, adx, bmi1/2, aes, pclmulqdq, rdrand/rdseed, movbe`；无 `sha512`、`apx`、`amx`。
- 工具链：gcc 14.3.1，GNU as 2.43.1，perf 可用，python3 13.1，OpenSSL 3.2.6；**缺** clang/llvm-mc/llvm-mca/nasm；无 sudo（需密码）；系统 Racket 8.15（本树需自建）。
