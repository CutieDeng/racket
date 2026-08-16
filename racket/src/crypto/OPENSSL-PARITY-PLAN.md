# OpenSSL 接口对齐与功能完全替代规划

> 承接 [`TLS-REWRITE-PLAN.md`](./TLS-REWRITE-PLAN.md)（已完成：TLS 1.3/1.2 从零后端、
> libssl 删除、aarch64 零 OpenSSL）。本文规划**从"够用"走到"功能完全替代 OpenSSL"**
> 的后续工作：TLS 特性对齐、对外接口对齐、算法/格式覆盖、合规与非 aarch64 收尾。
> 每阶段可独立成会话；文末每项带**验收判据**。

---

## 0. 现状基线（动手前必读）

- **已零 OpenSSL（aarch64）**：RNG、摘要、`racket/crypto/*` 全原语、TLS 1.3+1.2
  客户端/服务端、X.509 链验证、主机名、SNI/ALPN、通道绑定(tls-exporter)、
  keylog。`ssl-available? = #t`，`net/http-client` HTTPS 可用，libssl/libcrypto/
  legacy FFI 已删。
- **Racket 对外暴露的 OpenSSL 面本就很窄**：只有 `openssl/*`（TLS + sha1/md5，已迁）
  和 `racket/crypto/*`（本就 rktcrypto）。因此"接口对齐"主要是 **TLS 行为对齐**
  与 **可选的 libcrypto 兼容层**（供生态第三方 `crypto` 包等），而非核心分发缺口。
- **已知功能差距**（相对 libssl / 相对完整 OpenSSL），下面按价值排序成阶段。

---

## 1. 分阶段规划

### Phase A — TLS 特性对齐到 libssl 功能对等（最高价值）
让 rktcrypto TLS 后端在**行为**上与旧 mzssl 无差别，`net/*` 与用户代码不感知差异。

- **A1 端口层完整语义**（当前为阻塞式，最影响生产可用性）
  - 非阻塞 I/O：`make-input-port`/`make-output-port` 返回可 `sync` 的 evt，读写不
    阻塞其他 Racket 线程/事件；半关闭（写方向 close_notify 后仍可读）；
    `ssl-abandon-port`（放弃 TLS 关闭、只还原始端口）；`shutdown-on-close?`；
    `enable-break` 变体；`ssl-addresses` 全信息。
  - 复用 mzssl 的"内存缓冲泵"骨架：状态机消费/产出字节缓冲，端口泵接非阻塞 TCP。
  - **验收**：并发多连接（≥100）不互相阻塞；`ssl-abandon-port` 后原端口可继续明文
    收发；对慢速对端不死锁；`raco test` 端口语义用例通过。

- **A2 会话恢复**（性能：省一次 RTT + 公钥运算）
  - TLS 1.3：`NewSessionTicket` 生成/解析、PSK 绑定（`pre_shared_key` +
    `psk_key_exchange_modes`）、0-RTT 视需要（默认关，防重放）。
  - TLS 1.2：session-id 缓存 + `SessionTicket`（RFC 5077）。
  - 服务端 ticket 密钥轮换；客户端会话缓存（进程内 + 可插拔）。
  - **验收**：我方 client↔server ticket 复用成功（握手无证书/无 CertVerify）；
    与 openssl `s_server`/`s_client` 的 `-sess_out`/`-sess_in` 互操作恢复成功。

- **A3 证书吊销检查**（安全正确性：当前会接受"已吊销但未过期"证书）
  - CRL：分发点(CDP)拉取 + 签名验证 + 撤销列表匹配；缓存。
  - OCSP：请求构造/响应验证；**OCSP stapling**（`status_request` 扩展，服务端
    附带、客户端校验）。
  - 策略开关：`ssl-set-verify!` 语义扩展（soft-fail/hard-fail）。
  - **验收**：对 badssl `revoked.badssl.com` 正确拒绝；stapling 响应校验通过；
    无 stapling 时按策略回退。

- **A4 双向 TLS（客户端证书）**
  - 服务端：`CertificateRequest`（1.3/1.2）、校验客户端证书链 + CertificateVerify。
  - 客户端：按服务端 CA 提示选证、发送 Certificate + CertificateVerify。
  - API：`ssl-load-certificate-chain!`/`ssl-load-private-key!` 客户端侧、
    要求/可选客户端证书的服务端开关。
  - **验收**：我方双向 ↔ openssl（`-Verify`/`-cert`）双向；无证书按 required/optional
    策略正确处理。

- **A5 协议健壮性与安全**
  - 降级 sentinel 强校验（1.3→1.2/1.2→更低）；RFC 的 MUST-reject（非法参数、重复
    扩展、坏长度、非法 group/sig_alg）；record 大小/计数上限；1.3 `KeyUpdate`；
    1.2 安全重协商策略（默认禁）；告警码精确化（现多为泛化 fatal）。
  - `ssl-set-ciphers!` 从 no-op 变为真实策略（套件启用/排序）；`ssl-protocol-version`
    与版本区间（`'tls12`/`'tls13`/`'secure`）精确。
  - **验收**：负例互操作套（篡改握手/记录、降级、坏扩展）全部正确拒绝且可诊断；
    与 openssl 的 `-no_tls1_3`/`-cipher` 组合协商结果一致。

- **A6 通道绑定与 keylog 补全**
  - `tls-unique`（1.2，= 首个 Finished 的 verify_data）；`tls-server-end-point`
    用证书自身签名摘要算法（现固定 SHA-256）；1.2 的 keylog（`CLIENT_RANDOM`
    `master_secret` 行）。
  - **验收**：三种 channel-binding 与 openssl 对同连接一致；1.2 SSLKEYLOGFILE 可被
    Wireshark 解密。

### Phase B — 对外接口/兼容层对齐（生态替代）
让"通过 Racket 用到 OpenSSL"的路径都能落到 rktcrypto。

- **B1 `openssl/legacy` 语义替代**：旧模块只做 `OSSL_PROVIDER_load` 激活 legacy EVP。
  评估是否需要保留一个**空壳兼容 shim**（no-op，返回成功）以防外部代码 `require`；
  或在文档中标注废弃。**验收**：`(require openssl/legacy)` 不报错且不加载 OpenSSL。
- **B2 libcrypto 兼容 FFI 面（可选，重）**：若要支持第三方 `crypto` 包（Culpepper）
  等直接调 libcrypto 的生态，提供 rktcrypto-backed 的 `crypto` factory 或 libcrypto
  ABI shim。**判据**：`crypto` 包的 `libcrypto-factory` 测试在 rktcrypto 后端通过。
  （范围大、非核心分发，按需启动。）
- **B3 X.509 / 格式工具面**：对外提供证书解析/构造、CSR、PKCS#8/#12、PEM/DER 转换的
  Racket API（现有解析在 backend 内部）。**判据**：能读写 openssl 生成的
  key/cert/p12 并 round-trip 一致。

### Phase C — 算法与格式覆盖补全
- **C1 遗留/冷门分组密码**：RC4、单-DES、Blowfish、CAST5、IDEA、RC2、SEED（按需，
  多数已在 `rktcrypto_legacy_ciphers.c`；补齐缺口并接 `racket/crypto` 或 legacy 面）。
- **C2 容器/PKI 格式**：完整 CMS/PKCS#7（签名+加密+多签名者）、PKCS#12、PKCS#8
  加密私钥、OpenSSH 私钥、SPKI。现仅 `rktcrypto_cms_verify`（单签名者 RSA）。
- **C3 KDF/MAC 长尾**：按 OpenSSL EVP_KDF/EVP_MAC 清单核对缺项。
- **验收**：对每类用 openssl 生成向量做差分/round-trip。

### Phase D — 合规、安全审计、测试深度
- **D1 常量时间审计**：新 TLS 路径（证书验证错误处理、record 解密失败、PSK 比较、
  padding）过 dudect；沿用子系统 CT 纪律。
- **D2 测试向量**：接入 Wycheproof（ECDSA/RSA/AEAD/HKDF/X25519）+ TLS 的 RFC 8448/
  7905 逐字节；BoringSSL/OpenSSL 互操作矩阵自动化。
- **D3 内存与错误**：密钥/中间量 `secure_clear`；错误不泄露区分信息（时序侧信道）。
- **验收**：Wycheproof 全过；CT 报告无显著泄漏；互操作矩阵 CI 化。

### Phase E — 非 aarch64 收尾（扩展"移除"到全平台）
- **E1 性能实测**：x86-64（及其他）头对头 rktcrypto pure-C vs OpenSSL（沿用
  `crypto-benchmark.rkt --check` + 装 libcrypto 对拍纪律）。
- **E2 补 asmp 内核**：对性能不达标的热点（AES/GHASH/SHA/bignum/EC）补 x86-64
  (AES-NI/PCLMUL/AVX2) 汇编，或接受可量化的差距。
- **E3 扩展移除**：达标后，把 `native-libs/build-all.rkt` 的 openssl 去除从 aarch64
  推广到该平台；重复 aarch64 的验收。
- **验收**：目标平台 `ssl-available? #t` 无 OpenSSL、acceptance+integration 全过、
  基准无回归（或差距在既定容差内并记录）。

---

## 2. 优先级建议

1. **A1 端口层** + **A3 吊销** + **A5 健壮性**：生产可用与安全的必需项，先做。
2. **A2 会话恢复** + **A4 双向 TLS**：功能对等的主要缺口。
3. **A6 / B1 / B3**：中等价值的接口补全。
4. **E 非 aarch64**：把"移除"推广到全平台（独立可并行）。
5. **B2 / C / D**：生态/长尾/合规，按实际需求启动。

> **最小"完全替代 libssl"里程碑** = A1+A2+A3+A4+A5+A6 全过，`tls-acceptance.rkt`
> 扩到覆盖恢复/吊销/双向/负例，且与 openssl 双向互操作矩阵全绿。

---

## 3. 风险与决策项

- **端口层非阻塞**是最易出并发 bug 的一块（旧 mzssl 有大量 warning 注释），需仔细复用
  其泵/事件模型并加压力测试。
- **吊销检查引入网络 I/O**（CRL/OCSP 拉取）→ 超时/缓存/软失败策略要产品化决策。
- **B2 libcrypto ABI shim** 工程量可比一次 TLS 重写，仅在有明确生态需求时启动。
- **E 非 aarch64**：是否值得补 x86 汇编取决于目标平台重要性；也可接受"非 aarch64 继续
  bundle OpenSSL 但 TLS 仍走 rktcrypto"的过渡态。
- **安全 > 互操作宽容**：吊销/降级/双向证书的 MUST-reject 不因兼容性让步。
