# Racket 密码学增强支持 — 设计方案 v2（全面 in-tree 路线）

状态：设计稿 v2（方向已定：全面 in-tree，摆脱 OpenSSL 密码学依赖）
分支：`anthropic/crypto`
日期：2026-07-14

## 决策更新（2026-07-15）：不 vendor 任何外部代码

用户明确：**不引入任何外部库代码**（含 HACL*/fiat-crypto/PQClean 等验证
实现），避免把供应链风险搬进树内。因此本文 §1 vendor/ 目录与 §3 算法表
"来源 H/F/P" 全部作废 —— **所有算法内核从零手写**，对标 FIPS/RFC 官方
向量 + 独立参考做差分验收。M3 椭圆曲线、M4 后量子亦从零实现。常量时间
AES 用有限域算术 S-box（x^254 求逆）而非查表。优先级：M2b AES-GCM →
M3 公钥 → M4 后量子 → M5 去 OpenSSL。

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

### SipHash — 完成（2026-07-15）

`rktcrypto_siphash.c`：from-scratch 实现 SipHash-2-4 与 SipHash-1-3
（keyed PRF，16 字节密钥，8 字节 LE 输出）。公开 API 直接暴露（非
dispatch），io 层 `crypto-siphash-2-4`/`crypto-siphash-1-3` 原语，
collects `racket/crypto/mac` 的 `siphash-2-4`/`siphash-1-3`。

验收：官方 reference vectors（key=0..15、input byte i=i）len 0–7 全过，
`crypto-mac.rktl`（含 region 选择、1-3≠2-4、不同密钥不同、负向 key
长度校验）；C 层 KAT 加 SipHash-2-4 空输入；全量回归通过。用途：短
输入 MAC + 未来 M5 的 hash-table 抗 flooding 加固。

至此 M1/M1b 摘要+MAC 族完整：SHA-2 全族、SHA-3/SHAKE、BLAKE2b、
BLAKE3、HMAC、SipHash。

尚未完成（框架已就位，属机械增量）：

- **Poly1305**：已实现验证（作为 M2 AEAD 内部组件，未单独暴露 MAC API）。
- **KMAC**：基于 SHAKE，待补。
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

### M2b AES-256-GCM — 完成（2026-07-15）

`rktcrypto_aes.c` + `rktcrypto_gcm.c`：from-scratch AES-256-GCM。

- **AES-256 核心**（仅加密，CTR 只需加密）：常量时间——SubBytes 用有限域
  算术（GF(2^8) 经 x^254 费马求逆 + 仿射变换）**而非查表**，规避 cache
  时序侧信道（满足"不 vendor + 常量时间"双约束）。
- **GHASH**：常量时间逐位 GF(2^128) 乘法（NIST 位序，无查表），认证器
  无数据依赖时序。GCM = CTR（起始 J0+1）+ GHASH + tag（E(J0)⊕S）。
- 接入 AEAD dispatch（`'aes-256-gcm`，复用现有 aead 原语，无新原语、
  无版本 bump）。

验收：NIST 全零向量（隔离 AES/CTR/GHASH/tag）—— empty tag
530f8afb…、16 字节密文 cea7403d…/tag d0d1c8a7… 全过；AES 核心另过
FIPS-197 C.3 与 SP800-38A 向量；`crypto-aead.rktl` 增补 AES-GCM 用例
（NIST 向量 + 跨长度往返 + 篡改拒绝）；C 层 KAT 加全零 AES-GCM。
过程中排查发现是测试对照值抄错（TC15 密文/tag），实现自始正确——
用权威全零向量隔离确认。

性能：便携常量时间路径（有限域 S-box 无查表，慢但安全）；无硬件 AES
平台文档引导用 ChaCha20 系。ARMv8-CE/AES-NI 硬件加速 dispatch 待接入。

### M2b Argon2id — 完成（2026-07-15）

`rktcrypto_argon2.c`：from-scratch Argon2id（RFC 9106）内存硬密码哈希，
复用已有 BLAKE2b core。含变长哈希 H'、Argon2 P 置换（带
2·trunc(a)·trunc(b) 混合项，区别于 BLAKE2b round）、G 压缩、argon2id
混合寻址（首轮前半 data-independent 生成地址块、其余 data-dependent）、
多轮多 lane 驱动、内存清零；支持 secret(K)/AD(X)。接入
`racket/crypto/kdf` 的 `argon2id`（keyword API，默认 RFC 第二推荐
t=3/m=64MiB/p=4）。

验收：RFC 9106 官方向量（0d640df5…）离线通过；`crypto-kdf.rktl` 增补
（官方向量 + 确定性 + 不同 salt 不同 + 自定义长度 + 负向）；C 层 KAT。
排查中发现离线测试函数声明 ABI 与 intptr_t 签名不匹配致参数错位死循环
——实现本身正确。

### M2b DRBG — 完成（2026-07-15）

`rktcrypto_drbg.c`：per-OS-thread ChaCha20 用户态 CSPRNG（arc4random 风格
fast-key-erasure）。系统熵一次播种；每次请求用 block 0 keystream 重设
key（前向安全，状态被攻破无法反推历史输出）；getpid() 检测 fork 后
自动重播种（父子进程绝不共享状态）。Racket 绿色线程在同一 place 同一
OS 线程、atomic FFI 调用下进入,thread-local 状态无需额外锁。

`crypto-random-bytes`/`!` 从每次 syscall 切到 DRBG（M0 的
`rktcrypto_system_random` 仍是播种源与 fallback）。

验收：离线 C 测试全过 —— 区间填充、非全零、两次不同、分布 256/256、
**fork 安全（fork 后经 pipe 比对父子输出必不同,catastrophic 若相同）**；
C 层 KAT 加 DRBG 基本冒烟；Racket 层随机数测试（长度/非全零/65536
分布/两次不同）现走 DRBG 仍全过。性能：小请求从 ~1µs（syscall）降到
纳秒级内存操作。

**M2 对称+KDF+DRBG 至此完整**：对称(ChaCha20/AES-256)、AEAD 三件套、
KDF(HKDF/PBKDF2/Argon2id)、secretbox、DRBG。

### M2c 硬件加速（第一批：ARMv8-CE）— 完成（2026-07-15）

为已有算法接 ARMv8 Crypto Extensions 硬件加速（本机 Apple Silicon，
编译期 `__ARM_FEATURE_AES`/`__ARM_FEATURE_SHA2` 守卫，便携常量时间路径
保留于 `#else`）：

- **AES-256**（`rktcrypto_aes.c`）：vaeseq/vaesmcq 指令（硬件常量时间）。
  AES-256-GCM 从便携有限域 S-box 提到 125 MiB/s（GHASH 仍是便携逐位
  瓶颈，PMULL 待接）。
- **SHA-256**（`rktcrypto_sha256.c`）：vsha256hq/h2q/su0q/su1q 指令。
  **366 → 1434 MiB/s（3.9×，且超 rktio 内置 538 的 2.7×）**。

验收：硬件路径输出与便携完全一致 —— AES 过 FIPS-197 C.3 + SP800-38A、
NIST GCM 全零向量；SHA-256 过 NIST 向量 + python hashlib 差分（全块
边界）；crypto-digest/aead 测试与全量回归通过。纯 C 库内部改动
（transform 走硬件），不涉及原语/io/绑定，无需 bump 版本。

尚未完成（可选后补）：
- **PMULL GHASH**：GCM 的 GHASH 仍便携逐位（AES-GCM 的当前瓶颈）。
  已离线试写 PMULL 版但与便携逐位差分 1000/1000 不匹配（位反射域 +
  Karatsuba + 约减细节错，位反射是经典陷阱），按"不通过不集成"策略
  未放进仓库（AES-GCM 保持便携 GHASH 正确）。待专门调试后接入,接后
  AES-GCM 可达 GB/s 级。验收方法:与 rktcrypto_gcm.c 的 ref bit-by-bit
  ghash_mul 随机输入差分 + NIST 全零向量。
- **x86 加速**：AES-NI/SHA-NI/AVX2 需运行时 cpuid dispatch，待接。
- **ChaCha20/BLAKE NEON**、**scrypt**、**PBKDF2 C 内循环**：可选后补。

## 7.x M3 公钥（进行中）

vendor 政策更新（2026-07-15）：**最终实现模块零依赖从零手写**；但
**测试/验收阶段可引入 vendor 作差分 oracle + 性能基线**（增强验收）。

### M3-1 X25519 — 完成（2026-07-15）

`rktcrypto_x25519.c`：from-scratch X25519（RFC 7748）。Curve25519 域算术
GF(2^255-19) 用 5 个 51-bit limbs（add/sub/mul/sq、`__uint128_t` 中间积、
19 折叠约减、z^(p-2) 加法链求逆）；Montgomery ladder 用常量时间 cswap，
scalar 逐位驱动，对秘密标量常量时间；scalar clamp。生产代码零依赖
（连 rktcrypto.h 都不 include）。

接入 `racket/crypto/kex`：`x25519-generate-private-key`、
`x25519-public-key`、`x25519`（低阶点返回 #f）。

验收（三重）：① RFC 7748 §6.1 官方向量（单次 + **1000 次迭代**链式，
约 25 万 ladder 步）；② **vendor 差分:与 LibreSSL 2000 随机样本 0 不匹配**
（测试 harness 链接 -lcrypto,生产代码零依赖）；③ Racket 层 DH 一致性
（Alice/Bob 共享密钥相等)+ 低阶点拒绝 + 负向。`crypto-kex.rktl` 72 项、
C 层 KAT、全量回归通过。

排查中修一个 ladder step bug：变量复用把 `AA + a24·E` 误写成
`BB + a24·E`（AA 被覆盖丢失）——用命名临时变量按 donna 标准序列重写。
另遇构建陷阱：bump 版本后 raco make 命令一度失效，raco setup
compiler-lib 恢复。

### M3-2 Ed25519 — 完成（2026-07-15）

`rktcrypto_ed25519.c`：from-scratch Ed25519（RFC 8032）签名。复用 radix
2^51 域算术 + 加 neg/cmov/pow22523(sqrt)/isnegative/iszero；扩展坐标点
运算（unified twisted-Edwards 加法、常量时间 double-and-add 标量乘、点
压缩/解压含 sqrt 恢复 x）；**scalar mod L 运算 sc_reduce/sc_muladd**
（ref10 21-bit-limb 方法,Ed25519 最易错的部分）；SHA-512 复用已有 core
驱动 keygen/sign/verify。生产零依赖。接入 `racket/crypto/sign`。

验收：**与 OpenSSL@3 差分 200 样本 —— pubkey/signature/verify 全 0 不匹配**
（这是关键:排除了我手抄 RFC seed 出错的干扰,直接确认从零实现与成熟库
逐位一致;测试链接 -lcrypto,生产零依赖）；`crypto-sign.rktl`（KAT +
sign/verify 往返 + 篡改/错消息/错密钥拒绝 + 负向）；C 层 KAT；全量回归。

实现教训:首版仓促(verify 有垃圾代码、sc 运算缺失)——删掉重写,ref10
scalar 运算仔细转写一次通过。sign→verify 自洽不足以证明与标准一致
(错 seed 也会自洽),vendor 差分是决定性验收。

### M3-3 P-256 — 完成（2026-07-15）

`rktcrypto_p256.c`：from-scratch NIST P-256（secp256r1）ECDH + ECDSA。
泛化 Montgomery 域算术（4×64-bit limbs,参数化模数——同一套代码服务
域 mod p 与群阶 mod n,n0/R² 运行时算避免手抄错）；Jacobian 坐标点
运算（double/add/常量时间 scalarmult,a=-3 优化 double 公式）；ECDH
（scalar×point→x）；ECDSA-with-SHA-256 sign（随机 nonce rejection
sampling 从 DRBG）+ verify。复用 SHA-256。生产零依赖。接入
`racket/crypto/kex`（p256-ecdh）+ `racket/crypto/sign`（p256-ecdsa）。

验收（与 OpenSSL 3 差分,极充分）：① pubkey 100 样本逐字节一致（证明
整个点运算栈正确）；② ECDH DH 一致性；③ ECDSA 自洽 sign→verify;
④ **跨库互操作:我签的 OpenSSL 能验、OpenSSL 签的我能验（各 100 样本
0 失败）**——确认 ECDSA 语义/编码/哈希与标准一致。`crypto-kex.rktl`/
`crypto-sign.rktl` 增补、C 层 KAT、全量回归。

实现教训:jac_double 首版仓促(重复语句、mont_sub 缺参数、错误公式)——
仔细重写标准 a=-3 double 公式。

**M3 经典公钥完整:X25519、Ed25519、P-256(ECDH+ECDSA)全部从零手写。**

### M4-1 ML-KEM-768 — 完成（2026-07-15）

`rktcrypto_mlkem.c`：from-scratch ML-KEM-768（Kyber，FIPS 203），**首个
后量子格密码**。多项式环 Z_q[X]/(X²⁵⁶+1),q=3329;NTT 乘法（zetas 表、
Montgomery/Barrett 约减、7 层蝶形 ntt/invntt、basemul）;矩阵/噪声采样
用 SHAKE128 拒绝采样 + CBD(η=2);K-PKE IND-CPA + FO 变换（隐式拒绝）
得 IND-CCA2。G/H=SHA3-512/256、PRF=SHAKE256,全部复用 M1 的 Keccak
核。尺寸:ek=1184、dk=2400、ct=1088、ss=32。生产随机版走内建 DRBG;
另留 `_derand` 变体供 KAT。接入 `racket/crypto/kem`（mlkem768-generate-key
/encaps/decaps，隐式拒绝语义在契约中说明）。生产零依赖。

验收（极充分）：① 自洽 keygen→encaps→decaps 50 样本 0 失败;② **与
OpenSSL 3.6 互操作:用我的 ek 让 OpenSSL 封装、我解封,50 样本 shared
secret 全等**——逐位证明 keygen 输出格式、decaps 语义、G/H/ss 派生、
压缩编码全部与 FIPS 203 标准一致（互操作是随机化 KEM 的正确 oracle,
不能比对封装输出）;③ C 层 KAT 钉死确定性输出 + 隐式拒绝(改 1 bit →
ss 变);④ `crypto-kem.rktl` 122 测试(20 轮往返、随机性、隐式拒绝、
负例);⑤ 全 8 套 crypto 回归通过。

性能（M1 Air/aarch64,经完整 Racket 栈含 FFI+参数检查）:keygen/encaps/
decaps 均 ~30k ops/s(~32 µs/op)。OpenSSL 基线 45k/68k/44k——同数量
级,便携 C 无 SIMD NTT 下 0.5–0.7×;encaps 差距最大(OpenSSL 有
AVX2/NEON NTT)。NEON NTT 向量化列为后续优化。

实现教训(极隐蔽的决定性 bug):keygen 把 `skpv=ntt(s)` 序列化进 dk
前未做 `polyvec_reduce`——`poly_ntt` 输出不约减,而 `poly_tobytes` 只
处理单次负数回绕、无法容纳大正系数,12-bit 截断损坏 dk。自洽与互操作
同时失败,逐层隔离(NTT 往返→basemul→编码/压缩→CBD 范围→矩阵主项
抵消→序列化)才定位到存储截断。加一行 `polyvec_reduce(&skpv)` 即 0 失败。
教训:NTT 输出必须先约减再序列化;差分单测每层都要有,否则复合失败无从
下手。

### M4-2 ML-DSA-65 — 完成（2026-07-15）

`rktcrypto_mldsa.c`：from-scratch ML-DSA-65（Dilithium，FIPS 204），
**首个后量子签名**,子系统最大单文件。环 Z_q[X]/(X²⁵⁶+1),q=8380417
(23-bit);NTT(自研生成 zetas 表,root=1753,离线校验 root²⁵⁶≡-1、
zetas[1]=25847 对齐参考;Montgomery/Barrett 约减);Fiat-Shamir-with-
aborts 拒绝采样签名循环;power2round/decompose/makehint/usehint 舍入;
SampleInBall 挑战、SHAKE128 矩阵展开、SHAKE256 噪声/掩码采样、CBD 风格
η=4。参数(k,l)=(6,5)、τ=49、γ1=2¹⁹、γ2=(q-1)/32、ω=55。签名"纯"变体
+空上下文(默认互操作口径),hedged(随机 rnd)。尺寸:vk=1952、sk=4032、
sig=3309。生产零依赖。接入 `racket/crypto/sign`(mldsa65-generate-key
/sign/verify)。

验收(极充分,决定性)：① 自洽 keygen→sign→verify 30/30、篡改消息全拒;
② **与 OpenSSL 3.6 双向互操作各 25/25:我签的 OpenSSL 能验(证明 sign+
vk 格式+消息表示 μ 全对)、OpenSSL 签的我能验(证明 verify+挑战重算全
对)**——逐位确认 FIPS 204 语义/编码/域分隔一致;③ C 层 KAT + 三类负例
(篡改 sig、错消息、跨密钥);④ `crypto-sign.rktl` 增补(10 轮往返、hedged
随机性、空消息、负例);⑤ 全 8 套 crypto 回归通过。

性能（M1 Air,经完整 Racket 栈）:keygen 6.9k、**sign 3.4k(反超 OpenSSL
2.6k!)**、verify 8.1k ops/s。OpenSSL 基线 12.4k/2.6k/13.8k——便携 C 无
SIMD 下 keygen/verify ~0.6×,sign 因拒绝采样循环实现紧凑反而更快。NEON
NTT 向量化列为后续。

实现关键:zetas 表用离线程序生成而非手抄(吸取经验),NTT 自洽 + 参考常量
双校验;先自洽 30/30 再双向互操作,一次通过——严格对齐 pq-crystals 参考
的打包/采样/符号约定是零返工的原因。

### M4-3 X25519MLKEM768 混合 KEM — 完成（2026-07-15）

`racket/crypto/kem` 纯 collects 层实现(复用已验证的 ML-KEM-768 +
X25519,无新 C):draft-ietf-tls-ecdhe-mlkem 的混合 KEM——只要经典或后量子
一侧不破,共享密钥即安全(抗"先收割后解密")。构造为纯拼接,线序**先经
offline C харness 打到 OpenSSL X25519MLKEM768 探明再固化**:ek=ml-kem-ek‖
x25519-pub(1216)、ct=ml-kem-ct‖x25519-ephem(1120)、ss=ml-kem-ss‖x25519-ss
(64,无额外 KDF,交由 TLS 密钥调度)。**互操作:OpenSSL encaps 我 ek → 我
decaps 逐半恢复,64 字节 ss 完全一致**(C 探针确认布局,Racket 层忠实转
写)。API x25519mlkem768-generate-key/encaps/decaps。

验收：自洽 20 轮往返、随机性、跨密钥失配、ss 前 32 字节等于独立 ML-KEM
解封(证明拼接顺序)、负例;`crypto-kem.rktl` 增补。性能 encaps 8.6k ops/s。

**M4 后量子完整:ML-KEM-768(KEM) + ML-DSA-65(签名) + X25519MLKEM768
(混合 KEM)全部从零/纯拼接,与 OpenSSL 逐位互操作。经典+后量子密码栈齐备。**

### M5-1 SHA-1/MD5 内建、openssl/* 去 libcrypto — 完成（2026-07-15）

`rktcrypto_legacy.c`：from-scratch SHA-1(FIPS 180-4)+MD5(RFC 1321),
纳入统一 digest 框架(alg id 14/15、F_SHA1/F_MD5 家族)。**二者密码学已破,
仅为兼容旧场景(Git 对象 id、旧校验和)保留**,注释明标。`openssl/sha1`
与 `openssl/md5` 从 libcrypto FFI(带纯 Racket 回退)改为直接走内建
digest——**这两个模块不再依赖任何外部库**,是"摆脱 OpenSSL"的直接兑现;
接口不变。`racket/crypto/digest` 增 sha1/md5 符号。

验收：官方向量(空/"abc"/quick-brown-fox)+ 流式分块一致 + **与纯 Racket
file/sha1、file/md5 交叉对拍 200 组随机长度 0 不一致**(覆盖块边界);C 层
KAT;crypto-digest.rktl 增正例、原把 md5 当"未知算法"的负例改用 sha999。

性能教训:首版标量块函数 SHA-1 385/MD5 351 MB/s——**反比纯 Racket 回退
(900+)还慢**(digest 框架每次 update memcpy ~2KB 上下文联合体,加标量块
带每轮分支)。按经典做法重写:SHA-1 滚动 16 字窗口 + 80 轮全展开去分支
→996;MD5 RFC 1321 全展开 64 步去分支→856 MB/s(各 ~2.5×),追平/反超
纯 Racket。教训:落入统一框架的 digest 必须跑吞吐基准对比回退实现,否则
"内建"可能是性能倒退。

### M5-2 benchmark 套件 + dudect 常量时间护栏 — 完成（2026-07-15）

`racket/src/crypto/benchmarks/crypto-benchmark.rkt`：全栈吞吐/延迟基准
(可直接 racket 运行),digest/MAC/AEAD 报 MB/s,公钥/PQ 报 ops/s。作为
性能验收仪器与回归绊线。实测(M1 Air):
- digest:SHA-256 2413、BLAKE3 1075、BLAKE2b 1108、SHA-1 995、MD5 807、
  SHA3-256 211 MB/s(SHA-256 因 ARMv8 SHA 扩展领先)。
- MAC:HMAC-SHA256 2112、SipHash-2-4 2869 MB/s。
- AEAD:ChaCha20-Poly1305 684、**AES-256-GCM 仅 149**(常量时间逐位
  GHASH 的代价;PMULL 硬件 GHASH 因位反射 bug 暂缓)——**建议默认用
  ChaCha20-Poly1305**。
- 公钥:X25519 46k、Ed25519 sign 12k/verify 11k、P-256 ecdh 4.8k ops/s。
- PQ:ML-KEM keygen/encaps/decaps ~29k、ML-DSA sign 3k/verify 7.9k、
  混合 KEM encaps 13k ops/s。

`benchmarks/dudect_ct.c` + `run-dudect.sh`：dudect 风格常量时间检查,对两
类输入(密钥相关差异)做 Welch t 检验,|t|<4.5 视为未检出时序泄漏。实测:
`ct_bytes_equal` |t|=0.29、X25519 ladder |t|=1.30(均 OK);**故意早退的
leaky memcmp 正控制 |t|=85(正确报 LEAK?)**——证明该 harness 真能检出
泄漏,而非恒过。确认常量时间比较与 Montgomery ladder 无数据依赖分支。

**M5 收尾:SHA-1/MD5 内建化去 libcrypto、全栈性能基准、常量时间护栏。**

### M5-opt-1 AES-GCM PMULL 硬件 GHASH — 完成（2026-07-15）

针对基准暴露的唯一软肋 AES-256-GCM 149 MB/s 优化。定位:AES-CTR 早已走
硬件 <code>vaeseq</code>,瓶颈纯粹是逐位软件 GHASH。实现 ARMv8 PMULL
(<code>vmull_p64</code>) 硬件 GHASH：
- GHASH 位序（块字节 0 的 bit7 = x⁰）与 PMULL 多项式序相反，用单条
  <code>vrbitq_u8</code> 做整 128 位翻转转成正常序，Karatsuba 128×128→256
  无缝相乘，再用 0x87 折叠常量归约。H 每消息只翻转一次、累加器全程保持
  正常序、末尾只翻回一次。
- **吸取位反射 footgun 教训**：先离线对拍便携 <code>ghash_mul</code>
  <strong>20 万随机 0 错</strong>再集成；集成后对 OpenSSL AES-256-GCM
  <strong>500 组随机 (pt,aad) 长度 0 不一致</strong>。首版翻转 bug 也是
  200000/200000 全错，改用显式位索引提取定位、再回落到正确的
  <code>vrbitq_u8</code>。
- 便携逐位路径 <code>#else</code> 完整保留（无硬件时）。PMULL/vrbitq/折叠
  归约无数据依赖分支或访存，常量时间性质不变。

结果:**AES-256-GCM 149 → 1152 MB/s（7.7×）**，从最慢 AEAD 反超
ChaCha20-Poly1305（711）成最快。OpenSSL 全流水线汇编基线 ~8 GB/s——完全
对齐需多块流水（Gueron-Kounavis:4–8 路 CTR 流水 + H 幂聚合 GHASH 单次
归约），属更大专项，本次先消除数量级软肋。

### M5-opt-2 剩余性能缺口评估（OpenSSL M1 精确基线）

正确性前提:全算法差分/互操作 **0 不一致**（PQ interop、hashlib 72 例、
X25519/Ed25519/P-256 差分全部复跑确认）——无实现需修。性能对比:

| 算法 | rktcrypto | OpenSSL | 比值 | 追平所需 |
|---|---|---|---|---|
| AES-256-GCM | 1152 | ~8000 | 0.14× | 单遍融合 + H 幂聚合 GHASH（汇编级） |
| SHA-256 | 2413 | 3281 | 0.74× | 多块调度（硬件已用） |
| SHA-512（旧） | 545 | 1853 | 0.29× | ARMv8.2 SHA-512 硬件 |
| SHA-512（新） | **1725** | 1853 | **0.93×** | 已上硬件,核心 2790 反超 |
| SHA3-256 | 211 | 1118 | 0.19× | Keccak NEON/SHA3 扩展 |
| P-256 ecdh | 4845 | 43197 | 0.11× | NIST 专用域约减 + wNAF + 基点表 |
| P-256 ecdsa sign | 4328 | 97705 | 0.04× | 同上（OpenSSL 有逐微架构汇编） |
| ML-DSA-65 sign | 3066 | 2554 | **1.20×** | 已反超 |

**诚实结论**:用零依赖 from-scratch C（+intrinsics）全面追平 OpenSSL
逐微架构手写汇编不现实——差距源于 OpenSSL 的专用汇编与预算表，而非算法
缺陷;本子系统各算法与 OpenSSL 同数量级、个别（ML-DSA sign）反超。已消
除唯一的数量级软肋(AES-GCM 7.7×)。剩余可行硬件 intrinsic 专项(SHA-512
FEAT_SHA512、SHA-3 FEAT_SHA3——M1 均可用)与专用域算术(P-256)列为后续。
### M5-opt-3 硬件 SHA-512（ARMv8.2 FEAT_SHA512）— 完成（2026-07-15）

用户点明:自写 intrinsic/汇编属 from-scratch(非 vendor),且有便携实现作
oracle 可逐位验证——遂落地硬件 SHA-512。`rktcrypto_sha512.c` 加
`__ARM_FEATURE_SHA512` 守卫路径:SHA512SU0/SU1 消息调度 + SHA512H/H2
压缩,4 个 128 位状态向量 {a,b}{c,d}{e,f}{g,h},每步 2 轮。
- **oracle 验证法**:先离线对拍便携 transform **5 万随机块 0 错**。首版
  轮函数一次通过;全硬件调度首版全错,ACLE 语义定位到 SHA512SU1 的
  σ1 源参(Vn)与直加项(Vm)写反,交换即 0 错——"位序 footgun"被 oracle
  即时捕获,从未有发布错误代码的风险。
- 附带发现 digest 框架 `core_update` 逐字节经 ctx->buf 缓冲(倍增内存
  流量),硬件 transform 提速后成瓶颈;加"空缓冲整块直转"快路径。

结果:**SHA-512 545 → 1725 MB/s(3.2×),0.93× OpenSSL 近平**;裸核心
2790 MB/s **反超 OpenSSL 1853(1.5×)**,残差为 Racket 栈公共开销。KAT +
NIST 向量 + hashlib 差分(12 尺寸跨块边界)0 错。**"不劣于"对 SHA-512 达成
（核心反超）。** 教训修正:oracle 在手时,intrinsic footgun 不应成为回避
硬件的理由——写、验、只在逐位相等时集成。

**可行后续**:同法可上 SHA-1 硬件、FEAT_SHA3 加速 Keccak、单遍融合
GCM、P-256 专用域约减。运行时 CPU 特征分派(见下)是把这些安全铺开的
架构前提。

### M5-opt-x86 x86-64 硬件路径 + 运行时分派 — 完成（2026-07-15）

用户点明:运行时"预分派"是把硬件加速跨平台安全铺开的架构前提。落地
运行时 CPU 特征分派 + x86-64 硬件路径(对齐 OpenSSL,初步实现)。**关键
方法**:虽在 Apple Silicon 开发,但可 cross-compile x86_64 + Rosetta 2
运行(Rosetta 支持 AES-NI/PCLMUL,不支持 SHA-NI)——故高价值的 AES-GCM
路径可 Rosetta 逐位验证,非仅编译检查。

- `rktcrypto_cpu.c/.h`:运行时特征探测,一次性缓存(热路径读缓存字后
  分派,零 per-call 开销——OpenSSL 模式)。x86 用 CPUID leaf 1/7;ARM
  macOS 用 sysctlbyname(FEAT_AES/PMULL/SHA256/SHA512),ARM Linux 用
  getauxval(AT_HWCAP)。**双平台实测**:M1 原生探到全 ARM 特征、Rosetta
  探到 AESNI+PCLMUL。
- `rktcrypto_x86.c`(`__attribute__((target(...)))` 使无全局 -march 也可
  编译,标准多版本分派手法):
  - **AES-256 块(AES-NI)**:Rosetta 验证——FIPS-197 C.3 KAT + 对拍便携
    10 万 0 错。
  - **GHASH(PCLMULQDQ,Gueron 序列)**:Rosetta 验证——对拍便携 20 万 0
    错;字节反转吸收 GCM 位序,无需 bit-reverse。
  - **SHA-256(SHA-NI)**:标准 Intel intrinsic 序,编译干净,但 Rosetta
    无 SHA 扩展→correct-by-construction+编译检查,待真机验;分派回退到
    已验证便携 SHA-256。
- 分派接线:aes.c 块 / gcm.c GHASH / sha256.c transform 加
  `#elif __x86_64__` 运行时分支,不碰 ARM 编译期路径(M1 侧 x86 全编译
  掉,零回归——重建后 selftest 通过、AES-GCM 1142/SHA-512 1701 不变)。
- **集成验证(Rosetta)**:同一 x86 AES-GCM,hw 分派(features=0x3)vs
  强制便携(0x0),**300 组随机 (pt,aad) 长度输出逐位相同**;便携已对
  OpenSSL 500 组验证→x86 hw 传递性正确。

架构注:分派在 C 库层(非 Racket 解释器;Racket CS 经 Chez 编译原生,
crypto 在 librktcrypto)。当前 Apple 目标编译期守卫已正确;运行时分派为
可分发多架构二进制的正解(x86 的 AES-NI/SHA-NI 因 CPU 而异尤需)。

**密码学子系统开发完成。** P-256 专用汇编、单遍 GCM、x86 SHA-NI 真机验、
x86 AVX2 SHA-512/Keccak 与纯 Racket TLS（M6）仍属后续。

### M5-opt-4 结构性算法优化（曲线 comb/window + ChaCha 8-way）— 完成（2026-07-16）

用户授权"任何手段（汇编/JIT/…）只要正确且最大化性能"。本轮全部为**可验证
的可移植 C 结构性优化**（非微架构汇编），四项，各自离线 bit-exact 对拍 +
标准向量/OpenSSL 差分：

- **P-256 变基宽 4 窗口**（`jac_scalarmult_win`）：ECDH 与 verify 的 u2·Q
  项从逐位 double-and-add（256 double + 256 add）改为宽 4 窗口（256 double
  + 64 add），表 T[1..15] 一次 Montgomery-trick 批量求逆归一到仿射，供
  `mixed_add`。秘密标量常量时间（cmov 扫表 + 零位掩码），点为公开值故建表
  可分支。对拍参考 double-and-add 20000/0；OpenSSL 差分 50/0（ECDH 双向、
  互验签名、篡改拒绝）。ECDH ~6160→8585、verify 4733→5992 ops/s。
- **ChaCha20 8-way NEON**（`chacha20_8block_xor`）：两组独立 4-block（A:
  ctr..+3, B: ctr+4..+7）交错，倍增在途依赖链喂饱宽 NEON 单元；组转置/XOR/
  存储抽为 `cc_store4` 共用。逐长度 0..1500 × 5 计数器（含回绕）对拍标量核
  0 错；RFC 8439 §2.8.2 AEAD KAT 通过。**2109→3148 MB/s（0.94× OpenSSL
  3335）**；ChaCha20-Poly1305 1171→1455（0.49→0.61×，两遍理想 1565 的 93%）。
- **Ed25519 定基 comb**（`ge_scalarmult_base`，宽 4）：ed_comb[I]=Σ2^(64i)·B。
  签名做**两次**定基乘（公钥 A + 承诺 R）故收益最大。扭曲 Edwards(a=-1) 加法
  律完备→无例外分支，cmov 扫表常量时间、I=0 选单位元。对拍 20000/0；RFC 8032
  测例 1/3 确定性签名**逐字节**复现。**sign 13229→40088（0.19→0.58×）、
  verify 12182→17242**。
- **Ed25519 变基宽 4 窗口**（`ge_scalarmult_win`）：verify 的 h·A 项。加法律
  完备→投影表无需仿射归一；verify 全公开数据故直接索引（免扫表）。对拍
  20000/0。**verify 17242→20291（本轮累计 0.44→0.73×）**。
- **P-256 域求逆加法链**（`fp_inv`，cb492a8d67）：通用 Fermat mont_inv（256
  平方 + ~128 乘逐位过 p-2）→p-2 加法链（~277 平方 + 13 乘）。p-2=[32 ones]
  [31 z][1][96 z][94 ones][0][1]，94-ones 段拆 32+32+30 **复用 x32**（避免
  建专用 x94 白费 ~60 平方）。所有域求逆（jac_to_affine/affine_normalize/
  batch_affine）。对拍 mont_inv 20000/0，微基准 1.30×。
- **P-256 标量域窗口求逆**（`scn_inv`，7951b41b19）：k^-1/s^-1（mod n）。n 无
  短加法链结构→宽 4 窗口幂（定指数 n-2，15 预算 + 64 窗乘，~128→79 乘）。窗位
  来自公开 n-2 非秘密 base→常量时间。对拍 20000/0，微基准 1.26×。ecdh 不变。

六项均 `-Wall` 干净、内建 KAT 自检 `#t`。参考实现（`jac_scalarmult` /
`ge_scalarmult` / `mont_inv`）降级为 selftest oracle，`P256_SELFTEST` /
`ED25519_SELFTEST` 守卫，生产不编译。P-256 本轮累计 ecdh~6160→9000(1.46×)、
verify 4733→6274(1.32×)。**可移植 C 算法侧至此触顶**（预算表/窗口、SIMD 加宽、
加法链/窗口求逆全落地）。

### M5-opt-5 汇编级内核（asmp 工具链 + P-256 mont_mul）— 进行中（2026-07-16）

用户决定启动汇编级开发，并指出已有增强型汇编器项目 asmp
（`/Users/cutiedeng/Y2026/M05/D29/asmp.git`，Racket 写的 ARM64 汇编器：虚拟
寄存器 `x.name` + 图着色分配 + `--dump=interference/allocation` 冲突/分配日志
+ ABI 感知 prologue/epilogue + Apple/GNU 双语法）。架构约束：**源与汇编输出
两份都入库**，构建只依赖committed `.S`（asmp 仅开发期依赖）——perlasm 模式。

**首个内核：P-256 Montgomery 乘**（c114460dcf）。mont_mul 是 P-256 每个域/
标量乘的主导开销。asmp 生成的 CIOS 全寄存器驻留（0 栈溢出；高压时溢出到
caller-saved FP 寄存器 d16-d20 而非栈，fmov 比 stack 便宜），**2.2× 便携 C
（62 vs 28 Mmul/s）**，带动整条曲线 ~1.7×。

- 工作流（已在 `asm/README.md` 固化）：`asm/mont_mul.asm`（asmp 源，脚本
  `gen_montmul.py` 生成）→ `--gnu-input --apple --elim --default-abi aapcs64`
  → 包 `#if defined(__aarch64__)&&defined(__APPLE__)` 守卫存为 committed
  `rktcrypto_p256_asm.S`。`build.zuo` 直接编该 `.S`（预处理汇编），无 asmp/
  Racket 构建期依赖；非 Apple-AArch64 时 `.S` 空、mont_mul 回退
  `mont_mul_portable`（原 C，改名保留为 oracle）。drop-in 同 ABI 读 ctx→
  同时服务 p 和 n 两模数。
- **验证纪律**（`asm/mont_mul_test.c`，oracle=mont_mul_portable）：bit-exact
  0/200000（p 和 n 两模数含边界）；**ABI callee-saved 护栏**（x19-x28、
  v8-v15 哨兵存活）通过；端到端 KAT 自检 #t、consistency 0/2500、OpenSSL
  差分 0/40。
- 关键工具经验：leaf ABI 默认只给 caller-saved→高压溢出；`--default-abi
  aapcs64` 解锁 callee-saved（自动 save/restore）。惰性加载 a[i] 削减长活
  跨迭代压力消除栈溢出。allocator 会把 GP 值 fmov 进 FP 寄存器当廉价溢出槽
  （只用 caller-saved v16-v31，ABI 安全，护栏已证）。

```
  p256 ecdh    ~9000 -> 14943 ops/s (0.19x -> 0.34x OpenSSL)
  p256 sign   ~16640 -> 28914 ops/s (0.16x -> 0.29x OpenSSL)
  p256 verify  ~6200 -> 10402 ops/s (0.18x -> 0.31x OpenSSL)
```

**专用域乘/平方（4c764e3200 + d8274fc375）**——用户要求 P-256 对齐并尝试超越：
- **mont_mul_p256**（专用 mod-p）：n0=-p^-1 mod 2^64 = **1**，p 的 Solinas limbs
  使每个约简字 u*p 用 lsl/lsr/subs 实现（无乘），乘法端口让给 schoolbook。SOS。
  **2.73×C、1.28× 通用 CIOS（78 vs 61 vs 28 Mmul/s）**。对拍 mod p 0/1000000
  （含 (p-1)^2）。
- **mont_sqr_p256**：对称积省半偏积乘，共用移位约简。1.14× mont_mul(a,a)。对拍 0/1000000。
- C `mont_mul` 按 ctx 派发：&FP→mont_mul_p256、&FN→通用；ctx 恒编译期常量→分支折叠。
  工具经验：asmp 标量移位立即数用 `ubfm Xd,Xn,#immr,#imms`（lsl#s=#(64-s),#(63-s)）。

```
  p256 ecdh    14943 -> 17359 ops/s (0.34x -> 0.39x OpenSSL)
  p256 sign    28914 -> 32593 ops/s (0.29x -> 0.32x OpenSSL)
  p256 verify  10402 -> 11989 ops/s (0.31x -> 0.36x OpenSSL)
```

**分析 OpenSSL + 交叉 CIOS/点运算级 ILP（bab..→560..）**——用户令拉取 OpenSSL
vendor 分析。拉取 ecp_nistz256-armv8.pl 精读，关键发现：
- OpenSSL 域乘是**交错 CIOS**（每乘一个 b 字立即约简，累加器仅 6 字，~95 指令），
  非我的 SOS（全 8 字积后大约简，~235 指令）。约简每字 9 指令
  （lsl/lsr+subs/sbc+5 adds，n0=1 无约简乘）。
- OpenSSL **point_double 用子程序 bl、无延迟约简**——整个优势就在紧凑域乘。
  ⇒ 之前判断"需点运算级 asm/延迟约简"是错的；只需把域乘做成交错 CIOS。
- **重定 mont_mul_p256 为交错 CIOS**：147 指令。关键测量：宽 OoO M1 上域乘链式
  是**延迟约束**(~57cyc)、独立乘是**吞吐约束**(~19cyc)；点运算跑独立乘，故看
  **吞吐**——交错 CIOS 170 vs SOS 97 Mmul/s。平方走 mont_mul_p256(a,a)=150>SOS
  squarer 97，删专用 squarer。通用 mod-n 亦改交错 CIOS(1.32×)。对拍 0/1000000。
- **点运算级 ILP 重排（纯 C，零风险）**：profile 显示 jac_double=8×域乘延迟(464cyc,
  零重叠)；实测两个独立域乘 back-to-back 会重叠(38 vs 67cyc)，但编译器对 extern
  asm 调用保持源序，故须**源码上把独立乘写相邻**。重排 jac_double/mixed_add/
  jac_add 成"pair"结构→OoO 重叠→**ecdh/sign/verify +15-23%**。教训:cmov 扫表前移
  到 doubling 前反而回退(sel 活跃期跨 doubling 增压)，已撤。绝对 ops/s 随核温漂移,
  须同期基线对比。

```
  p256 ecdh    14943 -> 21242 ops/s (0.34x -> 0.50x OpenSSL)
  p256 sign    28914 -> 40668 ops/s (0.29x -> 0.41x OpenSSL)
  p256 verify  10402 -> 15042 ops/s (0.31x -> 0.46x OpenSSL)
```

**本 session P-256 累计 vs OpenSSL：ecdh 0.19→0.50×、sign 0.16→0.41×、
verify 0.18→0.46×（各 ~2.6×）**。到 1.0× 的剩余差距：点运算仍跑在域乘延迟
(~57cyc)而非吞吐(~19cyc)，ILP 重排已推近但未满；深挖需更激进 ILP（2-路点运算/
手写交错双乘）+ 更快求逆（Bernstein-Yang），progressively 难。

**其余缺口（plan #5 续）**：P-256（现 ~0.5×，进一步需更深 ILP/快速求逆）、
AES-GCM
（0.47×，AES/PMULL 端口调度）、ChaCha-Poly（0.61×，需软流水融合让 NEON 密文
与标量 MAC 真正重叠）、SHA-256/3（0.76-0.78×，硬件已用，多缓冲调度）。结构性
算法侧已基本触顶；进一步需专用汇编，风险/收益需单独立项。

## 8. 明确不做（non-goals）


- 不自行设计算法/协议/模式；不提供 ECB、无认证 CBC 等易误用原语。
- RSA 不进基线。
- TLS 重写不在本方案范围（M6 另立项）。
- 不承诺进程级密钥防护（内存加密、防 swap）。
- Rhombus 绑定暂缓（原 v1 Phase 5 移除，待核心稳定后另排）。
