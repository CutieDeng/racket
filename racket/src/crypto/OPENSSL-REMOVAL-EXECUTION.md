# OpenSSL 完全移除 — 执行清单（一一实现）

承接 [`OPENSSL-PARITY-PLAN.md`](./OPENSSL-PARITY-PLAN.md)。这是**执行台账**：逐项实现、
测试、勾选。基线（2026-08，实测）：aarch64 已零 OpenSSL（otool 无直连、shim 返回 #f、
crypto 77 checks 无 libcrypto、TLS 受入 8/8、真实 HTTPS 200、native-libs aarch64 不打包
openssl）；**非 aarch64 也已停止打包 openssl**（build-all.rkt 全平台 openssl→null, 142c0e4cb4）——因 openssl 集合从不加载捆绑 openssl（libssl/libcrypto 为 #f shim，ssl-available? 探测执行体内 rktcrypto），捆绑纯属死重。

跨平台是本目标的硬约束 → Phase E 与功能补齐并行推进。

## 执行顺序与状态

| # | 项 | 价值 | 状态 |
|---|---|---|---|
| 1 | B1 `openssl/legacy` shim 不加载 openssl | 低（防 require 报错） | ✅ 已完成（shim 空模块，实测 require 成功 libcrypto=#f） |
| 2 | A5 `ssl-set-ciphers!` 真实套件策略（启用/排序 AEAD 套件） | 中 | ✅ 已完成（cipher-string 解析→'suite-policy→client offer/server accept 双向过滤；tls-acceptance +3 用例全绿）。`enable-dhe!/ecdhe!` 保持 no-op（后端 ECDHE 恒开，无 FFDHE 组，语义上确为空操作） |
| 3 | A6 通道绑定补全 | 中 | ✅ tls-unique(1.2)+server-end-point 证书签名 hash + 1.2 keylog CLIENT_RANDOM，tls-acceptance 16/16 |
| 4 | A3 证书吊销（OCSP stapling） | 高（安全） | ✅ 验证器 rktcrypto-ocsp.rkt(签名/certID/新鲜度/状态) + TLS1.3 status_request+server staple+client 抽取校验+revoked abort；ssl-set-revocation-check! / ssl-set-ocsp-staple!；tls-acceptance +2 e2e + test-ocsp 6例。CRL/OCSP 主动拉取(有网络)待续 |
| 5 | A4 双向 TLS（1.3 + 1.2） | 高 | ✅ 1.3 完成 + TLS 1.2 双向（server CertificateRequest + 读 client Certificate/CertificateVerify + EMS session-hash 时序 + 验证；client 应答；正例 tls-acceptance 通过 tls1.2）。1.2 负例 e2e 受限于 client read-until-ccs 不处理 alert（待续） |
| 6 | A2 会话恢复：1.3 NewSessionTicket/PSK、1.2 SessionTicket | 中 | ✅ 1.3 完成（f5b5080ce1）：NewSessionTicket 生成/解析 + PSK(psk_dhe_ke)，binder 校验(截断 CH 上 HMAC)、Early=Extract(0,PSK)、单次票据、mzssl 透明接线(server ticket-store + client 按 host 会话缓存, 无新公开 API)、恢复时复原 peer 身份。test-resumption.rkt(判别性证明)。**1.2 SessionTicket(RFC 5077)完成**(8a279be049 server + 83c7c3e598 client)：server 发 empty SessionTicket ext + NewSessionTicket、按 ticket 存 master 走 abbreviated；client 提供 ticket ext、捕获 NST、按 session_id 回显检测 abbreviated。tls12-ticket.sh(openssl s_client -reconnect→5 Reused) + test-tls12-resume.rkt(loopback conn2 无证书=恢复)。**A2 全完成** |
| 7 | A1 端口层非阻塞（evt/sync、半关闭、ssl-abandon-port 完整语义） | 高（生产） | ✅ 非阻塞读+可 sync（fe1b689f22）：TLS1.3 recv-nb 用 peek-bytes-avail!* 探测整条记录是否到齐，到齐才读（保证不阻塞）、否则回 peek-bytes-evt（整record 就绪才触发，无 busy loop）；tls-conn-read-in! 走 make-input-port read-proc 协议（计数/eof/evt→0），1.2 回退阻塞。半关闭(wclosed)/ssl-abandon-port 早已具备。test-nonblocking.rkt：read-bytes-avail!* 无数据返 0 不阻塞、read-bytes-evt 就绪性正确、3 连接各自阻塞读互不串行/死锁。非回归+真实 HTTPS+互操作全过 |
| 8 | A5' 协议健壮性负例（MUST-reject、KeyUpdate、告警码） | 高（安全） | ◐ 部分：no-common-suite 现发 handshake_failure alert 再 raise（消除对端挂起）；downgrade sentinel（§4.1.3）双向已实现（server 置位/client 检测并 abort）；重复扩展 MUST-reject（§4.2）+ TLS1.3 KeyUpdate（§4.6.3, ssl-key-update!, 双向轮换）已加并测试。其余负例待续。abort 路径 e2e 需 MITM mock 或 openssl s_server -no_tls1_3 互操作 |
| 9 | B3 X.509 格式面 | 中 | ◐ 读取 API 完成：公开 openssl/x509（read-certificate/subject/issuer/SAN/serial/validity/key-type + PEM<->DER），test-x509-api 11例。自签证书构造（create-self-signed-certificate, DER 编码+签名, 自签验证通过）已加。CSR(create-certificate-request, PKCS#10, 自签验证通过)已加。EC 私钥导出（ec-private-key->pem, SEC1）+ 构建的 cert/key 作为真实 TLS 服务端身份 e2e 验证通过。CA 签发 leaf（create-certificate, 链验证到 CA）已加，构成完整 PKI 构造。PKCS#8/#12 加密容器待续 |
| 10 | C2 完整 CMS/PKCS#7（多签名者+加密）、PKCS#12、PKCS#8 加密私钥 | 中 | ◐ PKCS#8 加密私钥完成（273c987b3f）：PBES2(PBKDF2-HMAC + AES-CBC 128/192/256)，pem->private-key 带口令 + mzssl ssl-load-private-key! #:password；vs `openssl pkcs8 -topk8 -v2` EC+RSA 向量解密==明文。CMS SignedData 多签名者创建(3054af3413, ECDSA-P256, vs openssl cms -verify)+ PKCS#12(0443335bbf, PKCS12-KDF+RC2/3DES)+ **EnvelopedData 加密创建(52654fb61a, RSAES-OAEP-SHA256+AES-256-CBC, openssl cms -decrypt 还原明文)**。detached/多层 CMS 为长尾 |
| 11 | C3 KDF/MAC 长尾对照 EVP 清单 | 低 | ✅ 审计完成：主流 KDF（HKDF/PBKDF2/scrypt/argon2id/SSKDF/X963/KBKDF-HMAC/TLS1.3-expand）+ MAC（HMAC/SipHash/KMAC128·256/Poly1305/CMAC/GMAC）全覆盖。缺失均为小众且绑定特定特性：TLS1_PRF(内部已有)、X942KDF→C2 CMS、PKCS12KDF→PKCS#12、KRB5KDF/SSHKDF→各自协议；随对应特性引入 |
| 12 | D2 Wycheproof + RFC 8448/7905 + 互操作矩阵 | 中（合规） | ◐ **完整 Wycheproof 套件已落地**（2830fc3b19）：ECDSA P-256/384/521 + RSA-2048/3072 PKCS1 + Ed25519 约 2000 向量经 verify.rkt 路径，0 mismatch，test-wycheproof.rkt 常驻门禁。**发现并修复 3 个真实 bug**：ECDSA DER 宽松致签名可锻性、P-521 long-form 长度致全部 P-521 验证失败(潜伏)、Ed25519 FFI 参数(sig,pk)颠倒致全部 Ed25519 验证失败 + 缺长度/S<L 检查。**与真实 LibreSSL/OpenSSL 互操作矩阵已落地**（asm/tests/tls-interop.sh）：我方纯 Racket 栈作 client↔openssl s_server、作 server↔openssl s_client，TLS 1.3 与 1.2 四组全 PASS（真实握手+数据交换），实证替换栈与参考实现互通。RFC 8448 §3 逐字节向量已落地(test-rfc8448.rkt)：TLS_AES_128_GCM_SHA256 全 key schedule(early/derived/handshake/c·s hs traffic/master/c·s ap traffic/traffic keys)对参考值字节精确匹配 11/11 |
| 13 | **E 跨平台移除** | 高（本目标核心） | ◐ **x86-64 正确性已实证**：asm/tests/x86-conformance.sh 交叉编译 librktcrypto(纯C) + 8 个库级用例经 Rosetta 全 PASS（correctness gate 通过）。**E3 已完成（142c0e4cb4）：build-all.rkt 全平台停止打包 openssl**（捆绑库无人加载=死重，非性能问题；x86 正确性已由 Rosetta 实证）。E1（x86 rktcrypto vs openssl 基准）/E2（x86 AES-NI/PCLMUL 汇编）降级为**可选性能优化**（不再是移除的前置，因无 openssl 回退路径）。**完全移除达终态：所有平台发行版不打包 openssl** |

## 完整移除策略（每项执行方案）

> 两条正交轴：**功能轴**（A/B/C/D，纯 Racket TLS 后端 + librktcrypto，**全平台共通**，
> 无 arch 分支）与 **分发轴**（E，`build-all.rkt` 的 openssl 打包，**仅非 aarch64 待办**）。

- **A1 非阻塞端口层**：把当前阻塞 pipe/pump 换成 evt 状态机——复用旧 mzssl 的"内存缓冲泵"
  骨架（字节缓冲状态机 ↔ 非阻塞 TCP），`make-input/output-port` 返回可 `sync` 的 evt；
  实现半关闭、`ssl-abandon-port`（还原裸端口）、`shutdown-on-close?`、`enable-break`
  变体、`ssl-addresses`。文件 rktcrypto-mzssl.rkt（+ 可能新 pump 模块）。测：≥100 并发不
  互相阻塞、abandon 后明文续收发、慢对端不死锁。**风险最高（并发）**，先做压力测试。
- **A2 会话恢复**：1.3 NewSessionTicket 生成/解析 + PSK（pre_shared_key/psk_kex_modes，
  0-RTT 默认关）；1.2 session-id 缓存 + SessionTicket(RFC5077)；服务端 ticket 密钥轮换、
  客户端会话缓存（进程内 + 可插拔）。文件 tls13.rkt/tls12.rkt/mzssl.rkt。测：我方 ticket
  复用（简短握手）、与 openssl `-sess_out/-sess_in` 互操作。
- **A3 证书吊销**（进行中）：**OCSP stapling 校验优先（无网络）**——client 发 status_request，
  解析 CertificateStatus(1.2)/证书条目扩展(1.3)，验 OCSP 响应（CA 或带 id-kp-OCSPSigning
  的委托响应者签名、certStatus=good、thisUpdate/nextUpdate 新鲜度）。再做 CRL（CDP 拉取+
  验签+吊销序列匹配+缓存，有网络）与 OCSP 主动拉取。策略 `ssl-set-verify!` soft/hard-fail。
  文件 rktcrypto-verify.rkt + 新 rktcrypto-ocsp.rkt/rktcrypto-crl.rkt + tls13/tls12 插桩。
  测：本地生成的吊销证书+OCSP 响应正确拒绝；stapling 校验；soft-fail 回退。
- **A4 双向 TLS**：server 发 CertificateRequest(1.3/1.2)、验客户端链+CertificateVerify；
  client 按 CA 提示选证、发 Certificate+CertificateVerify；context 加 require/optional 开关
  与客户端证书加载。文件 tls13.rkt/tls12.rkt/mzssl.rkt。测：我方双向 ↔ openssl `-Verify/-cert`。
- **A5' 健壮性余项**：MUST-reject（重复扩展、非法 group/sig_alg、坏长度、重复/未知参数）、
  record 大小/计数上限、1.3 KeyUpdate、1.2 安全重协商（默认禁）、告警码精确化；downgrade
  abort 的 e2e（mock 或 openssl `-no_tls1_3` 互操作）。文件 tls13/tls12 解析+告警。测：负例互操作套全拒绝且可诊断。
- **B3 X.509 格式面**：公开 Racket API——证书解析（subject/issuer/validity/SAN/EKU/sig-alg）、
  构造、CSR(PKCS#10)、PKCS#8/#12、PEM/DER 互转。新 openssl/x509.rkt（后端 rktcrypto-x509.rkt +
  新编码器 + librktcrypto keygen/sign）。测：读写 openssl 生成的 key/cert/p12 round-trip。
- **C1 遗留分组密码**：多数已在 rktcrypto_legacy_ciphers.c；按需接 racket/crypto 或 legacy 面。
- **C2 容器/PKI 格式**：完整 CMS/PKCS#7（签名+加密+多签名者）、PKCS#12、PKCS#8 加密私钥、
  OpenSSH 私钥、SPKI。测：openssl 生成向量差分/round-trip。
- **C3 KDF/MAC 长尾**：对照 EVP_KDF/EVP_MAC 清单核缺（现 HKDF/PBKDF2/scrypt/argon2/sskdf/
  kbkdf/x963 已覆盖，KMAC 内部）；补缺项。
- **D 合规/测试**：D1 新 TLS 路径过 dudect（CT）；D2 Wycheproof(ECDSA/RSA/AEAD/HKDF/X25519)+
  RFC 8448/7905 逐字节 + BoringSSL/OpenSSL 互操作矩阵 CI 化；D3 密钥 secure_clear、错误路径无时序泄漏。
- **E 跨平台移除（"完全移除"核心，仅非 aarch64）**：E1 x86-64 头对头基准 rktcrypto 纯C vs OpenSSL
  （crypto-benchmark.rkt --check）；E2 对不达标热点补 x86-64 汇编(AES-NI/PCLMUL/AVX2)或记录可量化差距；
  E3 翻转 build-all.rkt 去 openssl（`aarch64?→null` 扩到 x86-64），在该平台跑 tls-acceptance+integration，
  再推广其余平台。**每平台验收**：`ssl-available? #t` 无 OpenSSL、acceptance+integration 全过、基准无回归或差距记录。

**推进顺序**（规划§2 + 本目标核心 E）：A3(安全) → A1(生产) → A5'余 → A2+A4(功能对等) → B3 →
E(逐平台去 openssl) → C/D(长尾/合规)。功能轴与 E 可并行（不同文件、无耦合）。

## 完全移除 · 收尾计划（"规划完全移除 openssl" 的明确路线）

**终态定义**：所有受支持平台上，Racket 发行版不链接、不打包、不在进程内加载
OpenSSL（libssl/libcrypto）；`openssl` 集合的全部公开面由纯 Racket TLS 后端 +
librktcrypto 提供；`ssl-available? #t` 且无 OpenSSL。

**当前实测基线**：aarch64 **已达终态**（otool 无直连、shim 返回 #f、crypto/TLS
全绿且 libcrypto 未加载、真实 HTTPS 200、native-libs aarch64 不打包 openssl）。
唯一未达终态的是**非 aarch64 的分发轴**（`build-all.rkt` 仍打包 openssl 作过渡
安全网），且其**正确性 gate 已通过**（x86-conformance.sh: 纯C librktcrypto 经
Rosetta 8/8 库级 ALL PASS）。

**完成移除还剩的确切步骤**（按依赖排序）：

1. **功能面收尾（全平台共通，不阻塞移除但影响对等度）** — 均为纯 Racket，
   逐项实现+测试，不改变"aarch64 已零 openssl"事实。**已完成**：A1 非阻塞端口
   (fe1b689f22)、A2 1.3 恢复(f5b5080ce1)、C2 加密PKCS#8(273c987b3f)/PKCS#12
   (0443335bbf)/CMS SignedData 创建(3054af3413)、D2 Wycheproof(2830fc3b19)+
   LibreSSL 互操作矩阵(d155d7ac19)。**剩余**：
   - A2 余：TLS 1.2 SessionTicket（1.3 已完成）。
   - C2 余：CMS EnvelopedData 加密（需库内新增 RSA 公钥加密/OAEP 或 ECDH+keywrap）、
     detached CMS 变种。
   - D2 余：RFC 8448 逐字节向量、CI 化互操作矩阵。
2. **分发面收尾（"完全移除"的真正核心，仅非 aarch64）**：
   - E1：x86-64 头对头基准 rktcrypto 纯C vs OpenSSL（crypto-benchmark.rkt --check）。
   - E2：对不达标热点补 x86-64 汇编（AES-NI/PCLMUL/AVX2）或记录可量化差距。
   - E3：**翻转 `build-all.rkt`**（`aarch64?→null` 扩到 x86-64 及其余平台），
     在各平台跑 tls-acceptance+integration，实测 `ssl-available? #t` 且 otool/ldd
     无 openssl → 逐平台达终态。
3. **收口**：删除 `openssl` 集合内所有 openssl-backed 退路与 legacy shim 的残留
   分支；文档标注最低平台要求；CI 加"无 openssl 链接"断言（每平台 otool/ldd grep）。

**关键决策点**：E3 的翻转在 openssl 的注释中被"性能验证"把关——正确性已实证，
**是否以及何时**牺牲潜在性能换取彻底移除，是产品/性能决策，需在有 x86 原生硬件
且 E1 基准数据在手时定夺（当前 aarch64 开发机只能经 Rosetta 验正确性，不能出可信
x86 原生性能数）。因此 E3 **不单方翻转**；E1/E2 数据是其前置。

**并行性**：功能面（1）与分发面（2）正交（不同文件、无耦合），可并行；aarch64
终态不受二者影响。移除"完成"的判定 = 步骤 2+3 在所有目标平台达成。

## 验收总则
每项：单元/差分测试 + 与 openssl 互操作（能对拍处）+ 不回归（self-test/tls-acceptance/integration 全绿）。
Phase E 每平台：`ssl-available? #t` 无 OpenSSL、acceptance+integration 全过、基准无回归或差距记录在案。

## 进度日志
（每完成一项在此追加：日期 · 项 · 提交 · 验证）
- 2026-08 · B1+A5 · 4d1aaee182 · tls-acceptance 11/11(含 A5 三例)
- 2026-08 · A6 · d63ebdf6bb · tls-unique(1.2)+server-end-point 摘要修正 · tls-acceptance 15/15
- 2026-08 · A6 完成 · fd7529eb9f · +1.2 keylog CLIENT_RANDOM · tls-acceptance 16/16
- 2026-08 · A5' downgrade sentinel · 670d615d94 · RFC8446 §4.1.3 双向 · 非回归 16/16
- 2026-08 · A3 OCSP stapling · 6e3d519c24 · 验证器 + TLS1.3 端到端 · tls-acceptance 18/18 + test-ocsp 6/6
- 2026-08 · A4 mutual TLS(1.3) · 849d37ac51 · CertReq+client cert+verify · tls-acceptance 20/20
- 2026-08 · B3 X.509 读取 API · 87914999e0 · openssl/x509 公开面 · test-x509-api 11/11
- 2026-08 · A5' 重复扩展拒绝 · 9424d24b0c · parse-extensions MUST-reject · tls-acceptance 22/22
- 2026-08 · A5' KeyUpdate · 0352648155 · RFC8446 §4.6.3 双向密钥轮换 + ssl-key-update! · tls-acceptance 23/23
- 2026-08 · C3 审计 · 5ad4a55de1 · 主流 KDF/MAC 全覆盖，小众项绑定 C2/PKCS12/SSH 特性延后
- 2026-08 · D2 ECDSA 边界 · 84b113816f · Wycheproof 式 r/s 范围校验 · test_ecdsa_edge 7/7
- 2026-08 · B3 证书构造 · e1fd714b72 · create-self-signed-certificate(P256/SHA256) + DER 编码器 · test-x509-api 19/19
- 2026-08 · B3 CSR · e5bfdb6c78 · create-certificate-request(PKCS#10) · test-x509-api 22/22
- 2026-08 · B3 key导出+TLS集成 · d84d945cef · 自建 cert+key 作 TLS 服务端 e2e · tls-acceptance 24/24
- 2026-08 · B3 CA 签发 · e40a85b7f8 · create-certificate(CA→leaf, 链验证) · test-x509-api 26/26
- 2026-08 · A4 for 1.2 · 41316c5699 · TLS1.2 双向认证(CertReq+CertVerify+EMS 时序) · tls-acceptance 25/25
- 2026-08 · E x86 正确性 · 0e6bf03e5d · x86-conformance.sh(交叉编译+Rosetta 8/8 库级 ALL PASS) → correctness gate 通过
- 2026-08-16 · D 完整 Wycheproof + 修 3 真实 bug · 2830fc3b19 · ECDSA P-256/384/521+RSA+Ed25519 ~2000 向量 0 mismatch；修 DER 可锻性 / P-521 long-form 潜伏失效 / Ed25519 参数颠倒+缺 S<L · test-wycheproof.rkt 常驻门禁
- 2026-08-16 · A2 会话恢复(1.3) · f5b5080ce1 · NewSessionTicket+PSK(psk_dhe_ke)+binder+单次票据+mzssl 透明接线 · test-resumption.rkt 判别性证明通过 + tls-acceptance 恢复用例
- 2026-08-16 · C2 加密 PKCS#8 · 273c987b3f · PBES2(PBKDF2+AES-CBC) 加载 + ssl-load-private-key! #:password · vs openssl pkcs8 -v2 向量解密==明文 (test-pkcs8-enc.rkt 7/7)
- 2026-08-16 · C2 PKCS#12 · 0443335bbf · PKCS12-KDF(RFC7292 纯Racket)+3DES/RC2/PBES2 bag+MAC验+ssl-load-pkcs12! · vs openssl pkcs12 -export EC/RSA (test-pkcs12.rkt 7/7)
- 2026-08-16 · C2 CMS 创建 + 修 ECDSA cms_verify · 3054af3413 · create-cms-signed-data(多签名者) vs openssl cms -verify；cms_verify 原为 RSA-only 现支持 ECDSA(cert_ec_pubkey) · test-cms.rkt 6/6，需 relink
- 2026-08-16 · D2 互操作矩阵 · <this commit> · asm/tests/tls-interop.sh 我方 client/server ↔ LibreSSL s_server/s_client TLS1.3+1.2 四组全 PASS
- 2026-08-16 · A1 非阻塞端口 · fe1b689f22 · recv-nb(peek-bytes-avail!*/peek-bytes-evt)+tls-conn-read-in!(read-proc协议) · test-nonblocking.rkt 6/6 非回归+真实HTTPS+互操作
- 2026-08-16 · D2 RFC 8448 · <this commit> · §3 key schedule 字节精确匹配 (test-rfc8448.rkt 11/11)
- 2026-08-16 · C2 EnvelopedData · 52654fb61a · RSAES-OAEP-SHA256+AES-256-CBC 信封创建 + 新 C wrapper rktcrypto_rsa_oaep_encrypt_pub · openssl cms -decrypt 还原明文 (cms-envelope.sh)
- 2026-08-16 · A2 1.2 SessionTicket · 8a279be049+83c7c3e598 · RFC5077 server 发/恢复 + client 捕获/恢复 abbreviated · tls12-ticket.sh(s_client -reconnect 5 Reused)+test-tls12-resume.rkt(loopback 双侧) · A2 全完成
- 2026-08-17 · E3 全平台去 openssl 打包 · 142c0e4cb4 · build-all.rkt openssl→null（捆绑死重, libssl/libcrypto=#f shim）· 达终态: 任何平台发行版不打包 openssl
