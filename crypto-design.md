# Racket 密码学增强支持 — 设计方案 v2（全面 in-tree 路线）

状态：设计稿 v2（方向已定：全面 in-tree，摆脱 OpenSSL 密码学依赖）
分支：`anthropic/crypto`
日期：2026-07-14

## 0. 方向与澄清

v1 中"不发明密码学"的准确含义：**不自行设计算法/协议/工作模式**；
**重写实现是本方案的核心内容**。所有实现严格对标 FIPS/RFC/官方规范与公开
测试向量，来源优先采用形式化验证或经充分审计的 public-domain/宽松许可
C 代码，vendor 进树内并锁定上游版本。

目标（按用户决策更新）：

1. **摆脱 OpenSSL 密码学依赖**：Racket runtime 内建完整现代密码学原语，
   不再依赖 libcrypto 的存在与版本；规避 OpenSSL 漏洞供应链问题，
   获得独立演进能力。
2. **高性能**：允许对 runtime 做必要的"大手术"，目标是热路径性能达到
   与 OpenSSL 同量级（硬件加速路径 ≤1.2×，便携路径 ≤2–3×）。
3. **现代算法全覆盖**：含 SHA-3/BLAKE3、XChaCha20、AEAD、Argon2id、
   X25519/Ed25519、以及后量子（ML-KEM/ML-DSA）与混合密钥交换。
4. Rhombus 绑定降优先级，暂缓。

边界（诚实声明）：**TLS 协议栈暂不重写**。`openssl/mzssl.rkt` 的 TLS
功能继续依赖 libssl；本方案摆脱的是"应用密码学对 OpenSSL 的依赖"。
在内建原语齐备（M4 完成）后，"纯 Racket TLS 1.3"成为可行的独立后续
工程（TLS 1.3 状态机远比 1.2 简单，且届时全部原语已在树内），列为 M6
展望项，届时才是 OpenSSL 的完全退场。

## 1. 新原生子系统：`racket/src/crypto`（"rktcrypto"）

这是本方案的"大手术"核心。**不把密码学塞进 rktio**（rktio 定位是 I/O
抽象，现有 sha1/sha2 是历史遗留），而是新建一个与 rktio 平行的原生子系统：

```
racket/src/crypto/
├── rktcrypto.h              ; 公开 C API（RKTIO_EXTERN 同款宏体系）
├── parse.rkt                ; 复用 rktio/parse.rkt 机制，生成 rktcrypto.rktl
├── rktcrypto.rktl           ; 自动生成的 Racket 侧绑定定义
├── build.zuo                ; 独立静态库 librktcrypto.a
├── core/                    ; 子系统骨架
│   ├── cpu_features.c       ; cpuid / HWCAP / sysctl 运行时特性检测
│   ├── dispatch.c           ; 每算法多实现函数指针表，首次使用时选路
│   ├── selftest.c           ; KAT（Known-Answer Test）惰性自检框架
│   ├── ct_utils.c           ; 常量时间比较、防优化清零(memset_s/explicit_bzero)
│   └── entropy.c            ; getrandom/getentropy/urandom/BCryptGenRandom
└── vendor/                  ; 锁定版本的第三方实现（记录上游 commit + 许可）
    ├── hacl/                ; HACL* 生成的 C（形式化验证）
    ├── fiat/                ; fiat-crypto 域算术（形式化验证）
    ├── blake3/              ; 官方 BLAKE3 C 实现
    ├── argon2/              ; phc-winner-argon2 参考实现
    └── pqclean/             ; PQClean（ML-KEM / ML-DSA / SLH-DSA）
```

要点：

- **独立静态库**，CS 与 BC 两个后端都链接同一个库。这改变了本仓库
  以往"BC 靠 collects 纯 Racket fallback"的双后端模式 —— 对称加密和
  曲线运算的纯 Racket fallback 在性能和常量时间两方面都不成立，
  必须两后端共用 C 实现（这是大手术的一部分，但机制上与 rktio 被
  两后端共用完全同构）。
- **绑定生成复用 rktio 的 parse.rkt 机制**：`rktcrypto.h` → `parse.rkt`
  → `rktcrypto.rktl`，io 层新增 `racket/src/io/crypto/` 挂接，
  `racket/src/cs/primitive/kernel.ss` 声明原语。改动足迹与既有 FEAT
  惯例一致，且全程不触及 expander/read，无需 re-bootstrap。
- **vendor 纪律**（供应链对策）：来源只取 4 类 —— HACL*（F* 形式化
  验证生成的 C）、fiat-crypto（Coq 验证的域算术）、PQClean（PQC 参考
  实现整理项目）、官方参考实现（BLAKE3、argon2、SipHash）。每个
  vendor 目录附 `PROVENANCE.md`：上游仓库、commit hash、抽取方式、
  许可（Apache-2.0/MIT/CC0，均与 Racket 的 Apache/MIT 双许可兼容）、
  本地补丁清单。构建期零网络获取。
- **KAT 惰性自检**：每个算法首次使用时跑一组内嵌测试向量（微秒级），
  防错误编译/错误链接/平台特性误判，失败即 raise，绝不静默降级到
  错误结果。

## 2. Runtime 性能设计（需重点讨论的部分）

### 2.1 多实现 dispatch 与硬件加速

每个算法维护一张实现表，`cpu_features` 初始化后一次性选路（函数指针，
无每次调用分支）：

| 平台特性 | 受益算法 |
|---|---|
| x86 AES-NI + PCLMULQDQ | AES-GCM（加密 + GHASH） |
| x86 SHA-NI | SHA-256 |
| x86 AVX2 / AVX-512 | ChaCha20、Poly1305、BLAKE2/3、SHA-2、ML-KEM |
| ARMv8 Crypto Extensions (AESE/PMULL/SHA2) | AES-GCM、SHA-256 |
| ARM NEON | ChaCha20、BLAKE3 |
| 无特性 | 全算法便携 C 路径（HACL* portable / bitsliced AES） |

AES 特殊处理：无硬件 AES 时，查表实现有 cache-timing 侧信道，
**不提供查表路径**；便携路径采用位切片（bitsliced）常量时间实现
（慢但安全），并在文档标注"无硬件加速平台优先选 ChaCha20-Poly1305"。

### 2.2 FFI 开销与调用粒度

- Racket CS 对 C 的原语调用开销在数十 ns 量级；对 ≥4KB 的数据块完全
  可忽略。**不需要为消除 FFI 开销做手术**，需要做的是避免逐小块调用：
  增量 API 在 Racket 层聚合小写入（类似端口缓冲），聚满一个 chunk 才
  跨 FFI。
- **零拷贝**：原语调用是 atomic 的（调用期间 GC 不运行），可直接传
  bytevector 裸指针 + start/end，无需 pin/copy。
- **零分配变体**：所有 one-shot 原语配 `!` 版本（写入调用者提供的
  输出缓冲），供热路径使用。

### 2.3 调度器协作（绿色线程延迟）

atomic FFI 调用期间 Racket 调度器停摆。对 1GB 输入做一次 one-shot
哈希会阻塞所有绿色线程与 GC。对策：

- C 层一律提供 init/update/final 增量接口；
- Racket 层 one-shot 对大输入**自动分块**（默认 256KB/次 atomic 调用，
  参数可调），块间回到调度器。256KB 下单次调用耗时在几十 µs 量级
  （SHA-256 硬件路径 ~2GB/s），绿色线程延迟无感；
- 分块循环在 `racket/src/io` 层实现一次，所有算法共用。

### 2.4 futures 并行

- 摘要/AEAD 的 update/final 原语不分配、不触碰 Racket 堆结构，
  标记为 **future-safe**，使哈希/加密可在 futures 上真并行；
- BLAKE3 的树形模式天然可并行：提供 `blake3-bytes/parallel`，在
  Racket 层用 futures 按子树切分（官方 C 实现单线程，多线程编排放
  Racket 层，避免在 C 里引入线程池）；
- Argon2id 的多 lane 并行同理可在后续版本用 futures 编排。

### 2.5 随机数架构

- **M0**：`rktcrypto_system_random`（getrandom → getentropy →
  缓存 fd 的 /dev/urandom → BCryptGenRandom），替换现走文件 I/O 的
  `/dev/urandom` 读取；
- **M2**：用户态 DRBG —— 每个 place 一个 ChaCha20 基 CSPRNG
  （arc4random 风格：fast-key-erasure），系统熵播种，定期/按量自动
  重播种，`fork` 后失效重播（rktio fork hook）。目的：把
  `crypto-random-bytes` 从"每次一个 syscall"变成纳秒级内存操作，
  同时保持前向安全。per-place 状态避免锁竞争。

### 2.6 常量时间纪律

- 秘密数据禁止参与分支与内存索引 —— vendor 来源（HACL*/fiat）已在
  验证层面保证，自写胶水代码 code review 时执行同一纪律；
- CI 加 dudect 风格统计冒烟（`crypto-bytes=?`、Poly1305 verify、
  Ed25519 verify 的首异 vs 末异分布对比），作回归护栏而非证明；
- 密钥材料缓冲用 `call-with-secret-bytes` 管理，退出即防优化清零
  （文档如实标注 GC 拷贝/换页不在承诺内）。

### 2.7 附带的 runtime 安全加固（可选，顺手收益）

内建 SipHash 后，可评估把 Racket 哈希表的 `equal-hash` 字符串/字节串
路径换成随机 key 的 SipHash-1-3，防 hash-flooding DoS —— 属于 runtime
本体的安全增强，与本子系统协同，列为 M5 可选项单独评审（有兼容性
影响：哈希值不再跨进程稳定）。

## 3. 算法实现表

图例：来源 H=HACL*，F=fiat-crypto，P=PQClean，O=官方参考实现，
R=Racket 层编排（无新 C）。"加速"列为 dispatch 可选路径，便携 C 始终存在。

### 摘要

| 算法 | 标准 | 来源 | 加速 | 里程碑 |
|---|---|---|---|---|
| SHA-224/256 | FIPS 180-4 | H（替换现 rktio 实现） | SHA-NI、ARMv8、AVX2 | M1 |
| SHA-384/512、SHA-512/256 | FIPS 180-4 | H | AVX2 | M1 |
| SHA3-224/256/384/512 | FIPS 202 | H | AVX2 | M1 |
| SHAKE128/256 (XOF) | FIPS 202 | H | AVX2 | M1 |
| BLAKE2b/BLAKE2s（含 keyed 模式） | RFC 7693 | H | AVX2 | M1 |
| BLAKE3（哈希/keyed/derive-key，XOF） | 官方规范 | O | SSE4.1/AVX2/AVX-512/NEON | M1 |
| SHA-1、MD5 | 遗留 | 保留现状 | — | 仅兼容，文档标注非密码学用途 |

### MAC

| 算法 | 标准 | 来源 | 加速 | 里程碑 |
|---|---|---|---|---|
| HMAC（任意已注册摘要） | FIPS 198-1 / RFC 2104 | R + H one-shot | 随摘要 | M1 |
| Poly1305 | RFC 8439 | H | AVX2 | M1 |
| SipHash-2-4 / 1-3 | 官方规范 | O | 便携 | M1 |
| KMAC128/256 | SP 800-185 | R（基于 SHAKE） | 随 SHA-3 | M1+（可选） |

### 对称 / AEAD

| 算法 | 标准 | 来源 | 加速 | 里程碑 |
|---|---|---|---|---|
| ChaCha20 | RFC 8439 | H | AVX2/AVX-512/NEON | M2 |
| ChaCha20-Poly1305 | RFC 8439 | H | 同上 | M2 |
| XChaCha20-Poly1305（大 nonce，随机 nonce 安全） | draft-irtf-cfrg-xchacha | H + 少量胶水 | 同上 | M2 |
| AES-128/256 core + CTR | FIPS 197 / SP 800-38A | H（AES-NI/ARMv8）+ bitsliced 便携 | AES-NI、ARMv8 CE | M2 |
| AES-128/256-GCM | SP 800-38D | H/EverCrypt | AES-NI+PCLMUL、PMULL | M2 |
| AES-256-GCM-SIV（misuse-resistant） | RFC 8452 | H + 胶水 | 同 GCM | M2+（可选） |

### KDF / 密码哈希

| 算法 | 标准 | 来源 | 加速 | 里程碑 |
|---|---|---|---|---|
| HKDF（extract/expand） | RFC 5869 | R | 随 HMAC | M2 |
| PBKDF2-HMAC-SHA2 | RFC 8018 | 自写 C 内循环（薄，直调 H 压缩函数） | 随摘要 | M2 |
| Argon2id | RFC 9106 | O (phc-winner-argon2) | SSE2/AVX2 | M2 |
| scrypt | RFC 7914 | O | — | M2+（可选） |

### 随机

| 能力 | 参照 | 来源 | 里程碑 |
|---|---|---|---|
| 系统熵（getrandom/getentropy/BCryptGenRandom） | — | 自写（entropy.c） | M0 |
| 用户态 DRBG（ChaCha20，fast-key-erasure，per-place，fork 安全） | arc4random 设计 | 自写（基于 H 的 ChaCha20） | M2 |
| 无模偏整数、随机采样加固 | — | R | M0/M2 |

### 经典公钥

| 算法 | 标准 | 来源 | 里程碑 |
|---|---|---|---|
| X25519 | RFC 7748 | H/F（51/64-bit 优化域算术） | M3 |
| Ed25519（含 Ed25519ph） | RFC 8032 | H | M3 |
| P-256 ECDH / ECDSA（互操作需要） | FIPS 186-5 | H + F 域算术 | M3 |
| X448 / Ed448 | RFC 7748/8032 | H | M3+（可选） |
| RSA | — | 不进基线（需要常量时间大数栈，性价比低；互操作场景后议） | non-goal |

### 后量子

| 算法 | 标准 | 来源 | 加速 | 里程碑 |
|---|---|---|---|---|
| ML-KEM-768/1024（Kyber） | FIPS 203 | P（或 libcrux 验证实现） | AVX2 | M4 |
| ML-DSA-65/87（Dilithium） | FIPS 204 | P | AVX2 | M4 |
| 混合密钥交换 X25519MLKEM768 | draft-ietf-tls-ecdhe-mlkem | R（X25519 + ML-KEM 组合） | — | M4 |
| SLH-DSA-SHA2-128s（SPHINCS+，保守备份签名） | FIPS 205 | P | — | M4+（可选） |

### 工具

| 能力 | 里程碑 |
|---|---|
| 常量时间比较 `crypto-bytes=?`、防优化清零 `crypto-bytes-clear!` | M0 |
| hex（复用 file/sha1）、base64url（补 net/base64） | M1 |
| `call-with-secret-bytes`、密钥封装辅助 | M1 |

## 4. 公共 API 布局（沿 v1，微调）

```
racket/crypto/random     ; 系统熵 + DRBG
racket/crypto/digest     ; 统一摘要（one-shot/增量/port/XOF）
racket/crypto/mac        ; HMAC / Poly1305 / SipHash（v1 的 hmac 模块并入）
racket/crypto/kdf        ; HKDF / PBKDF2 / Argon2id
racket/crypto/aead       ; 低层 AEAD（显式 nonce）
racket/crypto/secretbox  ; 高层对称（自动 nonce，XChaCha20 基，版本前缀）
racket/crypto/sign       ; Ed25519 / ML-DSA / P-256 ECDSA
racket/crypto/kex        ; X25519 / ML-KEM / 混合 KEM
racket/crypto/util       ; ct 比较、清零、编码
racket/crypto            ; re-export 常用子集
```

风格约束不变：`*-bytes` one-shot 命名、不透明增量 context +
`update!`/`final!`、`#:start`/`#:end` 区间、公共 API 全 contract、
密钥只收 `bytes?`、认证失败统一 `#f`。`file/sha1`、`racket/random`、
`openssl/sha1`、`openssl/md5` 全部改为内建实现的薄包装（openssl 模块
去掉 libcrypto FFI 路径，保 API 兼容）。

## 5. 路线图

| 里程碑 | 内容 | 验收标准 |
|---|---|---|
| **M0 基建** | `racket/src/crypto` 子系统骨架：build.zuo/parse 绑定链、cpu_features、dispatch、KAT 框架、ct_utils、entropy；`crypto-random-bytes` 切换 + `!` 变体；`crypto-bytes=?`/`crypto-bytes-clear!` | 双后端构建通过；随机数在 chroot/无 fd 场景可用；KAT 框架跑通首个算法（SHA-256） |
| **M1 摘要+MAC** | SHA-2 全族（含替换 rktio 旧实现）、SHA-3/SHAKE、BLAKE2、BLAKE3、HMAC、Poly1305、SipHash；统一 digest/mac API；分块调度循环；future-safe 标记 | 全部 NIST/RFC/官方向量通过；增量==one-shot 性质测试；SHA-256 硬件路径 ≥ OpenSSL 的 80%；1GB 输入哈希期间绿色线程延迟 < 1ms |
| **M2 对称+KDF+DRBG** | ChaCha20/XChaCha20-Poly1305、AES-CTR/GCM（含 bitsliced 便携）、HKDF、PBKDF2、Argon2id、secretbox、per-place DRBG | RFC 8439/CAVP/RFC 9106 向量 + Wycheproof AEAD 子集通过；DRBG 后 `crypto-random-bytes` 32B 调用 < 100ns；AES-GCM 硬件路径 ≥ OpenSSL 的 80% |
| **M3 经典公钥** | X25519、Ed25519、P-256 ECDH/ECDSA | RFC 7748/8032 + Wycheproof 曲线子集；Ed25519 verify ≥ 主流实现同量级 |
| **M4 后量子** | ML-KEM-768/1024、ML-DSA-65/87、X25519MLKEM768 混合 | FIPS 203/204 官方 KAT；与 liboqs/BoringSSL 互操作抽查 |
| **M5 收尾+去 OpenSSL** | `openssl/sha1`/`md5` 切内建；benchmark 套件（racket-benchmarks）；dudect CI 护栏；（可选评审）equal-hash SipHash 加固 | 除 mzssl(TLS) 外无任何模块加载 libcrypto；基准报告入库 |
| **M6 展望（独立工程）** | 纯 Racket TLS 1.3（客户端先行），基于 M1–M4 全部原语 | 另立设计文档 |

依赖关系：M0 → M1 → M2 → {M3, M4 可并行} → M5。每个里程碑独立可
交付可回退；M0+M1 完成即可让 `file/sha1` 一族与随机数脱离历史实现。

## 6. 风险与对策

| 风险 | 对策 |
|---|---|
| vendor 代码量大、跟上游脱节 | 只 vendor 生成物/参考实现的最小子集；PROVENANCE.md 记录同步方式；HACL*/PQClean 上游本就为嵌入设计 |
| 自建实现出漏洞 = 自己成为供应链 | 只用验证/审计过的来源 + 全量 KAT + Wycheproof + dudect 护栏；胶水层最小化；不写任何算法内核 |
| BC 后端链接 C 库带来的构建复杂度 | librktcrypto 无外部依赖、纯 C99，与 rktio 同构；BC 若维护成本过高可降级为"BC 仅保留摘要+随机，不承诺 AEAD/公钥" |
| 无硬件 AES 平台性能差 | bitsliced 保正确与常量时间；文档引导用 ChaCha20 系 |
| PQC 标准仍在演进（如 SLH-DSA 参数） | 基线只收已定稿 FIPS 203/204；API 带算法名 symbol，可平滑增补参数集 |

## 7. 实施记录

### M0 基建 — 完成（2026-07-14）

落地内容（与规划一致，两处按实际情况调整）：

- **`racket/src/crypto` 子系统**：`rktcrypto.h`（RKTCRYPTO_EXTERN 宏体系）、
  `rktcrypto_entropy.c`（getentropy/getrandom-syscall/urandom-fd-cache/
  BCryptGenRandom）、`rktcrypto_ct.c`（常量时间比较 + memset_s/
  explicit_bzero/SecureZeroMemory 清零）、`rktcrypto_selftest.c`（KAT
  自检框架，每算法必须注册）。纯 C99 零依赖，**无 configure 步骤**
  （调整 1：平台选择全走预定义宏，`setup-rktcrypto` 直接
  dynamic-require build.zuo，比 rktio 的 configure 流程简单一档）。
- **绑定链**：扩展 `rktio/parse.rkt` 词法器识别 RKTCRYPTO 词汇（3 行）；
  生成 `rktcrypto.rktl/.inc/.def`（checked in）；`cs/c/boot.c` 经
  `rktcrypto.inc` 注册 Sforeign_symbol；`cs/io.sls` 增加
  `#%rktcrypto` 实例表；`io/host/rktcrypto.rkt` + `io/crypto/main.rkt`
  暴露带参数检查的原语；`cs/primitive/kernel.ss` 注册 4 个原语。
- **原语**（`#%kernel`，racket/base 可见）：`crypto-random-bytes!`、
  `crypto-bytes=?`、`crypto-bytes-clear!`、`crypto-subsystem-self-test?`。
- **collects**：`racket/crypto{,/random,/util}`（contract-out 全覆盖，
  含 `call-with-secret-bytes`）；`racket/private/crypto-core.rkt` 做
  原语 feature-test，BC/无原语宿主回退旧 urandom 路径与尽力而为
  Racket 实现（调整 2：BC 共链 C 库推迟到确有需要时，M0 先走
  fallback，文档如实标注）。
- **版本**：9.2.2 → 9.2.3（原语集变更强制 zo 重编；这是踩坑教训——
  不 bump 版本时 racket/base 的 .zo 缓存按旧 `#%kernel` 导出表编译，
  新原语名不可见）。

踩坑记录（后续里程碑复用）：

1. `make base` **不会**再生成 `schemified/*.scm`；改 io/expander 层
   后必须先 `make derived`（需要 PATH 上有可用 racket + 树内安装
   parser-tools-lib）再 `make base`。
2. `boot.c` 里 `rktcrypto.inc` 之前必须 include `rktcrypto.h`，
   否则 Sforeign_symbol 取址处未声明。
3. 全量核心回归（`all.rktl`）需要 `raco pkg install --link
   pkgs/racket-test-core`。

验收结果：

- 正负测试：`tests/racket/crypto.rktl` 65 项全过（37 值 + 28 异常），
  已注册进 `all.rktl`。
- 性能：32B `crypto-random-bytes` ≈1.0µs/次（旧 /dev/urandom 文件
  路径 ≈23µs，**23×**）；1MB 填充 ≈4.4ms（getentropy 256B 分块的
  syscall 上限，M2 DRBG 后此路径不再是热路径）；`crypto-bytes=?`
  1KB ≈31ns。
- 时序护栏：`crypto-bytes=?` equal/首字节异/末字节异 三种输入
  200k×1KB 均 6.2–6.5ms，无早退可辨特征。
- C 自检（KAT）在 CS 启动后首次调用可用，`(crypto-subsystem-self-test?)`
  → `#t`。

### M1 摘要+MAC — 第一批完成（2026-07-14）

本批交付统一 digest 框架 + SHA-2 全族 + SHA-3/SHAKE + BLAKE2b + HMAC。

已完成并验收：

- **算法内核**（全部 from-scratch 重写，对标标准）：
  - `rktcrypto_sha256.c`：SHA-224/256（FIPS 180-4）
  - `rktcrypto_sha512.c`：SHA-384/512/512-256（FIPS 180-4）
  - `rktcrypto_sha3.c`：SHA3-224/256/384/512 + SHAKE128/256（FIPS 202，
    单份 Keccak-f[1600] 服务定长与 XOF）
  - `rktcrypto_blake2b.c`：BLAKE2b（RFC 7693，核心含 keyed 模式）
- **dispatch**（`rktcrypto_digest.c`）：算法用 int id（经 rktcrypto.h 常量
  暴露到 Racket 侧），统一 init/update/final/oneshot + ctx-size/size/
  block-size/xof? 元数据。context 存在 Racket 字节串里，dispatch 每次
  调用 memcpy 进出本地对齐 union —— 兼顾 GC 可移动性与对齐，对大块
  update 开销可忽略（一次 ~208B memcpy）。
- **io 层**（`io/crypto/main.rkt`）：8 个接受 symbol 的类型安全低层原语，
  kernel.ss 注册；**collects**（`racket/crypto/digest`）：digest 对象
  （finalized 标记防重用）、one-shot/增量/port/file 四形态、`#:start/#:end`
  区间、XOF `#:length`，全 contract。
- **HMAC**（`racket/crypto/mac`，纯 Racket 编排，FIPS 198-1）：one-shot +
  增量，密钥块用完 `crypto-bytes-clear!` 清零；瓶颈仍在 C 内核。
- **C 层 KAT**：selftest 每族一个 known-answer 测试。

验收结果：

- 正确性：`tests/racket/crypto-digest.rktl` 55 项全过（NIST FIPS 180-4/202、
  RFC 7693、RFC 4231 官方向量 + 增量==one-shot + port + 负向）；额外与
  **python hashlib 差分测试 78 例**（覆盖 0/55/56/63/64/65/127/128/129/1000/
  100000 等全部块边界）零不匹配。测试过程实抓 2 个笔误（测试期望值）+ 
  暴露 dispatch 设计的正确性（增量切分不变）。
- 性能（16 MiB one-shot，Apple M-series 便携路径）：BLAKE2b 1150 MiB/s、
  SHA-512 576、SHA-256 366、SHA3-256 233 MiB/s。

### M1b BLAKE3 — 完成（2026-07-15）

`rktcrypto_blake3.c`：from-scratch 实现 BLAKE3（官方规范），含树形结构
（1024 字节 chunk 分块、CV 栈按完成 chunk 数的低位进位合并、root 输出）
与 XOF 可变长输出。接入 digest dispatch（`'blake3`，兼具 32 字节默认
与 XOF 能力）。

验收：官方测试向量（输入 i%251）离线全过 —— len 0/1/2/3/64/1023/1024/
1025/2048/3072，覆盖单 chunk、chunk 边界、多 chunk 树合并、多 block XOF；
`crypto-digest.rktl` 增补 BLAKE3 用例（含 XOF 前缀一致性、2KiB 多 chunk
增量==one-shot）；C 层 KAT 加 BLAKE3("abc")；全量回归通过。吞吐
1150+ MiB/s（便携路径，最快的内建摘要）。

实现中定位并修复一个真实 bug：满 chunk 的末 block 必须**延迟**到 output
阶段带 CHUNK_END 压缩，不能在 update 中当普通 block 处理 —— 单 chunk
测试无法暴露，多 chunk（1025+）差分才发现。

尚未完成（框架已就位，属机械增量）：

- **Poly1305、SipHash、KMAC**：Poly1305 已离线实现验证（并入 M2 AEAD）；
  SipHash 归入 M5（equal-hash 抗 flooding 加固）；KMAC 基于 SHAKE 待补。
- **SHA-256 便携实现调优**：当前 366 MiB/s 约为 rktio 内置的 0.68×
  （两者皆纯 C 参考实现；可用消息调度滚动 + 循环展开提升）。
- **硬件加速路径**（SHA-NI/AVX2/ARMv8-CE）：dispatch 的多实现函数指针
  表尚未接入，全部走便携 C。设计文档 M1"≥OpenSSL 80%"针对硬件路径，
  待此项完成后验收。
- **可变长/keyed BLAKE2b 的公开 API**：核心已支持，dispatch 暂固定
  BLAKE2b-512、无 keyed 出口（keyed 场景先用 HMAC）。

### M2 对称+AEAD+KDF — 第一批完成（2026-07-15）

本批交付 ChaCha20 系对称加密、AEAD、secretbox 高层封装、HKDF/PBKDF2。

已完成并验收：

- **算法内核**（from-scratch 重写，对标标准）：
  - `rktcrypto_chacha20.c`：ChaCha20（RFC 8439）+ HChaCha20（XChaCha20 用）
  - `rktcrypto_poly1305.c`：Poly1305（RFC 8439，32-bit limbs radix 2^26，
    常量时间约减）
  - `rktcrypto_aead.c`：ChaCha20-Poly1305 + XChaCha20-Poly1305 AEAD，
    认证失败经 `rktcrypto_ct_bytes_equal` 常量时间比较
- **dispatch**（rktcrypto.h AEAD API）：int alg id + seal/open/key-size/
  nonce-size/tag-size，key/nonce 尺寸校验内建。
- **io 层**：5 个 symbol-keyed 原语（kernel.ss 注册）。
- **collects 两层**：
  - `racket/crypto/aead`（低层，显式 nonce，专家用，文档明确警示 nonce
    复用灾难性）
  - `racket/crypto/secretbox`（高层默认入口，misuse-resistant）：只需
    密钥，每次消息随机 24 字节 nonce（XChaCha20 保证随机 nonce 安全）、
    版本字节前缀、认证失败统一 `#f`；`call-with-secret-bytes` 清密钥。
  - `racket/crypto/kdf`：HKDF（RFC 5869）、PBKDF2（RFC 8018），纯 Racket
    编排 HMAC。
- **C 层 KAT**：selftest 加 ChaCha20-Poly1305 AEAD（seal+open+tamper-reject）。

验收结果：

- 正确性：RFC 8439 §2.4/2.5/2.8（ChaCha20/Poly1305/AEAD）、
  draft-irtf-cfrg-xchacha（HChaCha20 + XChaCha20-Poly1305 A.3.1）、
  RFC 5869（HKDF TC1/TC3）、PBKDF2-HMAC-SHA256 官方向量全过；HChaCha20
  额外与 Python 独立参考交叉验证。`crypto-aead.rktl`（43 项，含
  Wycheproof 风格负向：截断 tag、翻转密文/tag、坏 AAD/key/nonce、坏
  版本字节）+ `crypto-kdf.rktl`（19 项）全过；全量回归通过。
- misuse-resistance 验证：secretbox 同消息两次密文不同（随机 nonce）、
  篡改/坏版本/错密钥/错 AAD 均返回 `#f`。

尚未完成（M2 后续）：

- **AES-256-GCM**：软件需 bitsliced 常量时间实现 + PCLMUL/PMULL GHASH
  加速，体量较大，待接入（无硬件 AES 平台建议用 ChaCha20 系，文档已述）。
- **Argon2id、scrypt**：密码哈希，PBKDF2 已覆盖基本需求，Argon2id 待补。
- **per-place DRBG**：`crypto-random-bytes` 已走系统熵（M0），用户态
  ChaCha20 DRBG（arc4random 风格、fork 安全）作为性能优化待做。
- **PBKDF2 C 内循环**：当前纯 Racket，高迭代次数 CPU-bound，C 化待优化。

## 8. 明确不做（non-goals）


- 不自行设计算法/协议/模式；不提供 ECB、无认证 CBC 等易误用原语。
- RSA 不进基线。
- TLS 重写不在本方案范围（M6 另立项）。
- 不承诺进程级密钥防护（内存加密、防 swap）。
- Rhombus 绑定暂缓（原 v1 Phase 5 移除，待核心稳定后另排）。
