# TLS 栈重写规划：从零实现 rktcrypto TLS 后端，移除 libssl

> 本文档用于**开启新对话任务**。一个新会话读完本文即可直接动手，无需回溯历史。
> 目标读者是接手实现的工程/Agent。文末是**验收标准**，逐阶段可判定。

---

## 0. 一句话任务

Racket 摆脱 OpenSSL 的**最后一块**依赖是 TLS 栈：`openssl/mzssl` 是 `libssl`
状态机的薄封装。本任务从零实现一个 rktcrypto TLS 后端，**保持
`ssl-connect`/`ssl-listen`/`ports->ssl-ports` 等公开 API 不变**，把后端从
libssl 换成 in-tree 的 `racket/src/crypto` 原语，使 `ssl-available?` 在**不加载
任何 OpenSSL 二进制**的情况下重新为 `#t`，并让 `tls-acceptance.rkt` 通过。

工程纪律沿用本子系统既有做法（见 [`racket-crypto-project`] 记忆）：**从零手写、
零外部依赖、对真实 OpenSSL 对端逐条 bit-exact/互操作验证、每步进验收套**。

---

## 1. 现状与已有资产（动手前必读）

### 1.1 已完成——原语层已不依赖 OpenSSL
- `openssl/sha1`、`openssl/md5`、`crypto-random-bytes` 已走 `racket/crypto`。
- 全 `racket/crypto/*` 原语从零实现且性能 ≥ OpenSSL 持平（对称/摘要/AEAD/KDF/
  全 EC 曲线/RSA/DSA/DH/PQC）。实测本树 `libcrypto=#f`、非 TLS 路径不加载它。
- 功能验收：`racket/src/crypto/tests/integration.rkt`（71 检查全过）。

### 1.2 TLS 基础件（本重写的地基）
- **`rktcrypto_tls13.c`（248 行，RFC 8448 逐字节验证）** 已有：
  - `rktcrypto_tls13_transcript_hash` — 握手转录哈希
  - `rktcrypto_tls13_extract` / `rktcrypto_tls13_derive_secret` — HKDF 密钥调度
  - `rktcrypto_tls13_traffic_keys` — 派生 traffic key/iv
  - `rktcrypto_tls13_finished_key` / `rktcrypto_tls13_verify_data` — Finished MAC
  - `rktcrypto_tls13_record_nonce` / `_record_seal` / `_record_open` — 记录层 AEAD
  - `rktcrypto_tls13_selftest` — 自检
  - **缺**：握手**消息**解析/生成、扩展编解码、状态机。
- **`rktcrypto_x509.c`（236 行）** 已有：base64/PEM→DER、DER TLV 解析器
  (`der_tlv`/`der_into`/`der_skip`)、`rktcrypto_x509_verify_selfsigned`（单张自签
  验证）、`cert_rsa_pubkey`（取 RSA 公钥）、`rktcrypto_cms_verify`。
  - **缺**：证书**链**路径构建与验证、有效期/名称约束、主机名校验、信任库。
- **可直接调用的原语**：AES-128/256-GCM、ChaCha20-Poly1305（AEAD）；
  X25519 / P-256 ECDHE（`racket/crypto/kex`）；RSA / ECDSA(P-256) / Ed25519 签名
  验签；HKDF；SHA-256/384；X.509 DER 解析。ML-KEM-768 混合 KEM（可选 PQ 组）。

### 1.3 要保持不变的公开 API 契约（`openssl/mzssl` 导出面）
后端替换**不得改动**这些签名（`net/http-client`、`net/git-checkout`、
`net/url-connect`、用户代码都依赖它）：

```
ssl-connect  ssl-connect/enable-break  ssl-listen  ssl-accept  ssl-accept/enable-break
ssl-close  ssl-abandon-port  ports->ssl-ports  ssl-port?  ssl-listener?  ssl-addresses
ssl-make-client-context  ssl-make-server-context  ssl-secure-client-context
ssl-client-context?  ssl-server-context?  ssl-context?
ssl-load-certificate-chain!  ssl-load-private-key!
ssl-load-verify-root-certificates!  ssl-load-verify-source!  ssl-load-default-verify-sources!
ssl-set-verify!  ssl-try-verify!  ssl-set-verify-hostname!
ssl-set-ciphers!  ssl-set-server-name-identification-callback!  ssl-set-server-alpn!
ssl-get-alpn-selected  ssl-protocol-version
ssl-peer-verified?  ssl-peer-certificate-hostnames  ssl-peer-check-hostname
ssl-peer-subject-name  ssl-peer-issuer-name  ssl-channel-binding  ssl-set-keylogger!
ssl-available?  ssl-load-fail-reason  ssl-seal-context!
```

### 1.4 要移除的 FFI 面
- `openssl/private/ffi.rkt`（408 行）：BIO 内存 I/O、X509 解析/验证、SSL_CTX/SSL
  连接握手/IO/ALPN/SNI/会话/keylog/exporter（50+ 函数）。
- `openssl/libssl.rkt` / `libcrypto.rkt`：运行时 `ffi-lib` dlopen（连同
  `native-libs/build.rkt` 打包的 OpenSSL 二进制——**正是要消除的供应链面**）。
- `openssl/mzssl.rkt`（1793 行）：**保留 API 与端口泵/事件集成骨架，替换其
  libssl 调用为 rktcrypto TLS 后端调用**。理想切分：新增
  `openssl/private/rktcrypto-backend.rkt`，mzssl 在 `ssl-available?` 分支里优先选它。

### 1.5 验收 oracle（已就位，勿重造）
- `racket/src/crypto/tests/tls-acceptance.rkt`：回环 client↔server 握手+双向回显，
  走公开 API；无后端时 SKIP，有后端时判定。**每阶段扩展它**。
- 互操作对端：本机 OpenSSL 3.6.3（`/opt/homebrew/opt/openssl@3`，`s_server`/
  `s_client` 或 EVP）+ 真实 HTTPS 站点。
- 性能：`racket/src/crypto/benchmarks/crypto-benchmark.rkt --check`（握手 ops/s 可
  新增一节）。

---

## 2. 目标架构

```
  用户 / net/*  ──> openssl/mzssl.rkt  (API + Racket 端口泵/事件, 不变)
                         │
                         ├─(旧) openssl/private/ffi.rkt ──> libssl.dylib   ← 删
                         └─(新) openssl/private/rktcrypto-backend.rkt
                                     │  纯 Racket 握手状态机 + 记录层驱动
                                     └──> librktcrypto (C 原语, FFI 已有)
```

- **握手状态机与消息编解码放在 Racket 侧**（`rktcrypto-backend.rkt`），调用 C 侧
  `rktcrypto_tls13_*` 做密码学重活；证书链验证放 C 侧 `rktcrypto_x509.c`（大数/
  签名在 C）+ Racket 侧路径逻辑。理由：状态机是 I/O/控制流密集、非密码学热点，
  Racket 表达力更合适且便于与现有端口泵集成；密码学与大数留在 C。
- **记录层分帧**用现成 `_record_seal`/`_record_open`；**握手加密**同一套 AEAD。
- 内存 BIO 语义（mzssl 现用 libssl 内存 BIO 泵接非阻塞端口/事件）改为：状态机
  消费/产出字节缓冲，mzssl 的端口泵把缓冲接到 Racket 端口——**泵骨架可复用**。

---

## 3. 分阶段计划

> 每阶段：实现 → 对真实 OpenSSL 对端互操作 → 扩 `tls-acceptance.rkt` → 通过才进下一阶段。
> 阶段间可独立提交（沿用 `FEAT "..."` 提交风格）。

### Phase 1 — TLS 1.3 客户端握手状态机
**范围**：能与现代 HTTPS 服务器完成 TLS 1.3 握手并收发应用数据（先不做证书验证，
`ssl-set-verify! #f` 路径），解锁 `net/http-client` HTTPS。
- ClientHello 生成 + ServerHello 解析；扩展编解码：`supported_versions`、
  `key_share`（X25519 + P-256）、`supported_groups`、`signature_algorithms`、
  `server_name`(SNI)、`application_layer_protocol_negotiation`(ALPN)。
- EncryptedExtensions / Certificate / CertificateVerify / Finished 解析；
  客户端 Finished 生成；密钥调度用 `rktcrypto_tls13_*`（已验证）。
- HelloRetryRequest 处理；record 层 1.3 分帧（含 `change_cipher_spec` 兼容）。
- 密码套件：`TLS_AES_128_GCM_SHA256`、`TLS_AES_256_GCM_SHA384`、
  `TLS_CHACHA20_POLY1305_SHA256`。
- **新增文件**：`rktcrypto-backend.rkt`（握手驱动 + 消息编解码）；C 侧按需补
  `rktcrypto_tls13.c`（如 HKDF-Expand-Label 的 label 拼接、Certificate 结构 helper）。
- **互操作**：对 `openssl s_server -tls1_3`、对公网 HTTPS（如 example.com:443）握手成功、
  GET 到内容。

### Phase 2 — X.509 证书链路径验证 + 信任库 + 主机名校验
**范围**：`ssl-set-verify! #t` 与 `ssl-secure-client-context` 可用（默认安全）。
- 链构建（server 证书 → 中间 CA → 根）；每链接：签名验证（RSA-PKCS1v1.5 / RSA-PSS /
  ECDSA-P256/384 / Ed25519）、有效期、basicConstraints/CA、keyUsage/EKU、
  名称约束（RFC 5280）。
- 主机名校验（RFC 6125：SAN dNSName 优先、通配符规则）→ `ssl-set-verify-hostname!`、
  `ssl-peer-check-hostname`。
- 信任锚来源：PEM bundle（`ssl-load-verify-root-certificates!`）；系统信任库
  （macOS：Security framework / keychain 导出；Linux：/etc/ssl PEM；Windows：cert store）
  → `ssl-load-default-verify-sources!`。
- **主要在 C**（`rktcrypto_x509.c` 扩链验证，签名/大数在 C）；Racket 侧编排链构建/
  信任源加载/主机名。
- **互操作**：对公网 HTTPS 全验证通过；对故意过期/错主机名/自签证书正确**拒绝**。

### Phase 3 — TLS 1.2
**范围**：兼容无 1.3 的对端（`'secure` 允许 1.2+）。
- 1.2 握手流（ServerKeyExchange、证书请求/客户端证书可选）、PRF（SHA-256）、
  记录层（显式 nonce GCM / ChaCha20-Poly1305）、`extended_master_secret`、
  `renegotiation_info`。
- 密码套件：ECDHE-RSA/ECDSA-AES128/256-GCM、ECDHE-*-CHACHA20-POLY1305。
- **互操作**：对 `openssl s_server -tls1_2`、对仅 1.2 的公网站点。

### Phase 4 — 服务器端 + ALPN/SNI 选择 + 会话恢复 + 端口层收尾
**范围**：达到 mzssl 现有 surface 的功能对等。
- 服务器握手（1.3 + 1.2）；`ssl-listen`/`ssl-accept`；证书/私钥装载
  （`ssl-load-certificate-chain!`/`ssl-load-private-key!` 已有 API）。
- SNI 回调（`ssl-set-server-name-identification-callback!`）、ALPN 选择
  （`ssl-set-server-alpn!`/`ssl-get-alpn-selected`）。
- 会话恢复（1.3 PSK/ticket；1.2 session id/ticket 可选）。
- 端口集成收尾：`ports->ssl-ports` 双向、非阻塞、`ssl-abandon-port`、
  半关闭、`ssl-channel-binding`（tls-exporter / tls-unique）、`ssl-set-keylogger!`
  （SSLKEYLOGFILE 格式）、`ssl-protocol-version`、`ssl-peer-*`。
- 移除 `ffi.rkt`/`libssl.rkt`/`libcrypto.rkt` 的 libssl dlopen 及 `native-libs`
  打包；`ssl-available?` 改为 rktcrypto 后端存在性。

---

## 4. 验证方法（贯穿全程）

1. **互操作优先于自证**：每个消息/结构先与真实 OpenSSL 对端跑通（`s_client`/
   `s_server`、EVP、公网站点），再谈自洽。握手转录、密钥调度已有 RFC 8448 逐字节基准。
2. **bit-exact 差分**：密钥调度/记录层/证书签名验证对 OpenSSL 输出逐字节对拍。
3. **回归套**：每阶段扩 `tls-acceptance.rkt`（加对应协议版本/验证模式/服务器角色的
   回环用例）；`integration.rkt` 保持全过（原语不得回归）。
4. **负例**：过期证书、错主机名、篡改握手/记录、降级攻击、错 ALPN——必须正确拒绝。
5. **性能**：握手 ops/s 与吞吐进 `crypto-benchmark.rkt`，`--check` 防回归。
6. **构建纪律**：`make derived RACKET=$PWD/racket/bin/racket` 后 `make cs`；C 源
   `-Wall -Wextra` 零警告；`crypto-subsystem-self-test?` 为 `#t`。
   （注意：`raco test` 命令在精简构建缺装，直接 `racket <file>` 跑；三套均带
   `test` 子模块，正常发行版 raco test 可发现。）

---

## 5. 风险与需决策项

- **规模**：≈ 重写 libssl，是本工程最大单块，**多会话**。建议一会话一 Phase 甚至一
  Phase 拆多会话（Phase 2 链验证、Phase 4 端口层各自可独立）。
- **信任库跨平台**：macOS/Windows 系统信任源接入是平台专项工作量，Phase 2 可先
  PEM bundle 落地、系统源逐平台补。
- **常量时间 / 安全**：证书验证、PSK、record 解密的错误处理需防时序侧信道（沿用
  子系统既有 CT 纪律与 dudect）。
- **降级与协议健壮性**：need 覆盖 RFC 的 MUST 拒绝项（降级 sentinel、非法参数），
  安全 > 互操作宽容。
- **首个可用里程碑**：Phase 1+2 完成即可让 HTTPS 客户端（http-client/git-checkout）
  在无 OpenSSL 下工作——这是最高价值的中间交付。

---

## 6. 验收标准（逐阶段可判定，直接据此收尾）

> 记 `R = $PWD/racket/bin/racket`，`ACC = racket/src/crypto/tests/tls-acceptance.rkt`，
> `INT = racket/src/crypto/tests/integration.rkt`。所有阶段**共同前置**：
> `$R $INT` 71/71 全过（原语零回归）、相关 C 源 `-Wall -Wextra` 零警告、
> `crypto-subsystem-self-test?` 为 `#t`、`make cs` 重链成功。

**Phase 1 验收**
- [ ] `$R $ACC` 在 rktcrypto 后端下不再 SKIP，TLS 1.3 回环握手+双向回显通过。
- [ ] 对 `openssl s_server -tls1_3`（AES-128-GCM / AES-256-GCM / ChaCha20-Poly1305
      三套各一次）握手成功并互发数据、Finished 校验通过。
- [ ] 对至少 3 个公网 HTTPS 站点（覆盖 X25519 与 P-256 key_share、含一次
      HelloRetryRequest）完成握手并 GET 到响应体。
- [ ] SNI、ALPN(h2/http1.1) 扩展正确协商（`ssl-get-alpn-selected` 返回值正确）。

**Phase 2 验收**
- [ ] `ssl-secure-client-context` 对合法公网证书链**全验证通过**（签名+有效期+
      主机名+链到系统/PEM 根）。
- [ ] 对过期证书、错主机名、自签未信任、名称约束违规**各构造一例并正确拒绝**
      （返回可诊断错误，不是崩溃）。
- [ ] RSA-PKCS1v1.5 / RSA-PSS / ECDSA-P256 / Ed25519 四类叶证书签名各验证一例。
- [ ] `ssl-peer-subject-name`/`ssl-peer-certificate-hostnames`/`ssl-peer-verified?`
      返回与 OpenSSL 对同证书一致。
- [ ] `ACC` 扩展的"全验证客户端"用例通过。

**Phase 3 验收**
- [ ] 对 `openssl s_server -tls1_2`（ECDHE-RSA 与 ECDHE-ECDSA、GCM 与
      ChaCha20-Poly1305）握手+数据+验证通过。
- [ ] 对仅支持 1.2 的公网站点握手成功。
- [ ] 版本协商正确：对同时支持 1.3/1.2 的对端优先 1.3；`ssl-protocol-version`
      报告准确。降级 sentinel 检测生效。

**Phase 4 验收（= 总验收）**
- [ ] `ssl-listen`/`ssl-accept` 服务器端：rktcrypto 客户端 ↔ rktcrypto 服务器
      回环（1.3 与 1.2 各一次）握手+双向大数据（≥1 MiB，分块）无误。
- [ ] 与 OpenSSL 双向：`我方 client ↔ openssl s_server` 且
      `openssl s_client ↔ 我方 server` 均通过（1.3 + 1.2）。
- [ ] 服务器 SNI 回调选证、ALPN 选择正确；会话恢复（1.3 ticket）复用成功。
- [ ] `ports->ssl-ports` 全语义：非阻塞、半关闭、`ssl-abandon-port`、
      `ssl-channel-binding`、`ssl-set-keylogger!`(SSLKEYLOGFILE 可被 Wireshark 解密)。
- [ ] **移除完成**：删除 libssl/libcrypto 的 `ffi-lib` dlopen 与 `native-libs`
      OpenSSL 打包后，`ssl-available?` 仍为 `#t`；全树 grep 无对 libssl/libcrypto
      的运行时依赖；`net/http-client` HTTPS、`net/git-checkout` https 在**不存在
      任何 OpenSSL 二进制**的环境下正常工作。
- [ ] `$R $ACC` 全部用例（1.2/1.3 × client/server × verify on/off）通过；
      `$R $INT` 71/71；`crypto-benchmark.rkt --check` 无回归。
- [ ] 更新记忆 [`openssl-migration-assessment`]：TLS 迁移完成，OpenSSL 依赖清零。

**最终判据一句话**：在一台**未安装任何 OpenSSL**的 aarch64 机器上，
`ssl-available?` 为 `#t`，`tls-acceptance.rkt` 与 `integration.rkt` 全过，
`net/http-client` 能 HTTPS GET 到公网站点——即 OpenSSL 依赖已从 Racket 移除。
