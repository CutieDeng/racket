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
