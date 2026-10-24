# openssl collection(rktcrypto 实现):兼容性缺陷清单与修复状态

记录日期:2026-10-22;修复完成:2026-10-23。对象:私有分支 `v9.3-dev` 中以 rktcrypto 重写的
`openssl` collection(`racket/collects/openssl/private/rktcrypto-*.rkt`),分支 `fix/tls13-handshake`。

本目录原先存放"当前失败、修复后应通过"的测试;全部修复后,测试已移入 `tests/openssl/`
(见下表),本目录只剩本文件与 `repro/` 下两个演示脚本(`info.rkt` 将其排除于 `raco test`)。

## 0. 结论

| ID | 问题 | 状态 | 修复提交 | 回归测试(`tests/openssl/`) |
|---|---|---|---|---|
| C1 | `ssl-set-verify-hostname!` 被忽略 | 已修复 | b0b3ff1e75 | `test-verify-hostname.rkt`(8) |
| C2 | `ssl-try-verify!` 等同 `ssl-set-verify!` | 已修复 | ae27376cad | `test-try-verify.rkt`(6) |
| C3 | 未加载信任根时接受任意客户端证书 | 已修复 | ae27376cad | `test-verify-without-anchors.rkt`(4) |
| C4 | 服务端不记录客户端证书 | 已修复 | ae27376cad | `test-client-identity.rkt`(4)、`peer-verif2.rkt` |
| C5 | `ssl-peer-verified?` 读 context 标志 | 已修复 | b0b3ff1e75 | `test-peer-verified.rkt`(3) |
| C6 | 双方同时写入时死锁 | 已修复 | c403621a69 | `test-small-buffer.rkt`(3)、`basic.rkt`(9 用例全过) |
| C7 | 不支持 DHE/CBC 套件 | 已实现 | 8523104d3b | `test-ephemeral.rkt`(2)、`test-suites.rkt`(28) |
| C8 | alert 报告不准确 | 已修复 | ae27376cad | 无专门测试;C2/C3 测试的异常文本含 alert 名 |
| S1 | 读密钥安装后接受明文记录 | 已修复 | 3177a562d8 | `repro/record-plaintext-after-keys.rkt` 输出 REJECTED |
| S2 | 握手前明文 application_data 无界缓冲 | 已修复 | 3177a562d8 | `repro/handshake-unbounded-buffer.rkt` 输出 REJECTED |
| S3 | 畸形握手消息抛 `exn:fail:contract` | 未处理 | — | — |
| S4 | 客户端不按策略检查服务端所选 1.3 套件 | 未处理(信息) | — | — |

另有两项修复不在原清单:握手失败异常文本改为上游形式 `<who>: connect failed (...)` /
`accept failed (...)`(`peer-verif2.rkt` 依赖),`ssl-peer-subject-name` / `ssl-peer-issuer-name`
改为 `X509_NAME_oneline` 形式 `/C=US/O=.../CN=...`(`peer-verif.rkt`、`peer-verif2.rkt` 依赖)。

状态标注:**已验证** = 有实测输出;**推断** = 有代码证据但未实测;**未知** = 无法判定。

## 1. 第二轮(2026-10-23,提交 05031a47e8)

用户决策:C 侧导出通用 modexp 并接受 MODP 群;实现 TLS 1.3 post-handshake authentication;分支保留不合入;
"推断"项按源码正向分析。

| 项 | 做法 | 验证 |
|---|---|---|
| DHE 客户端策略 | `rktcrypto_dh_keygen/derive`(任意素数);白名单 = RFC 7919 ffdhe2048/3072/4096 + RFC 3526 MODP 14/15/16(g=2),素数由公式计算并与 C 常量/OpenSSL 内置群逐字节核对;其余仍发 insufficient_security | OpenSSL 3.6.3 默认 auto-DH(MODP-2048)与 LibreSSL 3.3.6:9 组套件双向 18/18 通过 |
| 端口上 `ssl-set-verify!`/`ssl-try-verify!` | TLS 1.3 post-handshake auth(RFC 8446 §4.6.2):客户端通告 post_handshake_auth,服务端发 CertificateRequest 并同步等待 Certificate/CertificateVerify/Finished,期间到达的应用数据排队;TLS 1.2 安全重协商(RFC 5746):服务端发 HelloRequest,在受保护流上跑完整握手(renegotiation_info 带上一次的 verify_data,新密钥于双方 CCS 后接管,期间应用数据排队),客户端读到 HelloRequest 时以同样方式应答;客户端主动的重协商请求以 no_renegotiation 警告拒绝 | `test-post-handshake-auth.rkt` 14 项;`peer-verif.rkt` 8 用例(含 `#:later` 3 用例)全过;与 OpenSSL s_client(被动应答)/s_server(`R` 命令)双向互通 |
| CBC 时序 | 双方协商 encrypt_then_mac(RFC 7366):MAC 覆盖公开长度的密文,先验 MAC 再看填充,无 Lucky 13 信号;会话票记录该框架,不一致则全握手。MtE 保留给无扩展的对端,填充检查改为 256 字节固定窗口掩码扫描,HMAC 压缩块数定值(§1.1) | `test-suites.rkt` 42 项(我方两端协商 EtM);OpenSSL/LibreSSL 对拍 |
| ECDSA 套件自互通 | 新增 P-256 服务端证书 `server_ec_{key,crt}.pem`(`generate-certs.sh`) | `test-suites.rkt` 7 个 ECDHE-ECDSA 套件 × 管道 10/4096 |

### 1.1 MtE 路径的正向分析与消除(第三轮)

`cbc-open`(`rktcrypto-tls12.rkt`)MtE 分支:解密后取末字节 padlen → `padding-ok?` 对最后 256 字节做掩码扫描
(循环次数与 padlen 无关)→ `frag-len = ptlen − padlen − 1 − mac-len` → HMAC 覆盖 `13 + frag-len` 字节。
HMAC 内层哈希压缩块数 = 1 + ⌈(13 + frag-len + 1 + L)/B⌉(B = 64/128,L = 8/16),随 padlen 变化 —— Lucky 13 可观测量。

**消除**:`hmac/fixed-blocks` 用增量摘要 API 手算 HMAC,内层哈希完成后在一次性上下文上补足压缩次数到该记录的最大值
(frag-len = ptlen − mac-len 时的块数),外层哈希定长。`ct-equal?` 常数时间。仍随长度变化的只有簿记(字节拷入部分块缓冲、
`final` 的逐字节填充循环),无压缩调用。

**实测**(`cbc-open` MtE,AES-128,HMAC-SHA256,密文 512 字节,padlen 0..255,每点 7 轮取中位,ns/次):

| padlen | 0 | 15 | 63 | 127 | 191 | 255 |
|---|---|---|---|---|---|---|
| 内层块数 | 9 | 9 | 8 | 7 | 6 | 5 |
| 改前 | 1564 | 1548 | 1518 | 1490 | 1418 | 1404 |
| 改后 | 2525 | 2489 | 2484 | 2455 | 2471 | 2458 |

改前单调下降,约 40 ns/块;改后无趋势,离散 ±2%(与块数无关)。代价约 +900 ns/记录(增量 API 每次调用拷贝 2KB 上下文),
只在未协商 EtM 的对端上发生。与 `rktcrypto_hmac` 的一致性:SHA-1/256/384 × 12 个边界长度 0 mismatch。

### 1.2 第三轮:对标检查后的补齐(2026-10-23)

对标检查方法:导出面对比、我方测试目录在上游 9.2 构建上逐文件运行、源码定位。发现并补齐:

| 项 | 做法 | 验证 |
|---|---|---|
| `ssl-protocol-version` 返回 `'tls1.3`(契约要求 `'tls13`) | 改为 `'tls13`/`'tls12` | test-alpn、test-openssl-client |
| `ssl-set-server-alpn!` 的 `allow-no-match?` 被忽略;TLS 1.2 不协商 ALPN | `#f` 时发 no_application_protocol(120)拒绝;1.2 客户端/服务端(含恢复)协商 ALPN | test-alpn 25 项(auto/tls12 × 拒绝/无 ALPN) |
| `'(directory p)` 验证源静默不加载 | 加载目录内所有可解析 PEM | 手工 |
| `ssl-load-suggested-certificate-authorities!` 空操作 | CertificateRequest 携带 certificate_authorities(1.3 ext 47 / 1.2 DN 列表,含 PHA) | test-openssl-client:s_client 打印 "Acceptable client certificate CA names" |
| `ssl-dh4096-param-bytes` 为 `#f` | `#""`(同上游) | 手工 |
| TLS 1.2 签名方案不协商 | 服务端按客户端 signature_algorithms 选(PSS→PKCS#1 SHA-256/384/512),客户端 CertificateVerify 按 CertificateRequest 选 | test-openssl-client:`-sigalgs RSA+SHA256` 与 `RSA-PSS+SHA384` 均握手 |
| 链校验只查 CA 位/签名/有效期 | `verify-chain`:路径构建(乱序链、多余证书、链含根)、pathLenConstraint、签发者 keyCertSign、EKU(按 server/client 用途,全链)、叶子 keyUsage、nameConstraints(dNSName/rfc822/iPAddress/directoryName/URI)、未知 critical 扩展拒绝 | test-chain-policy 16 项(证书由 generate-policy-certs.sh 生成,OpenSSL `verify` 对同样链给出同样判定) |
| 主机名不匹配 iPAddress SAN | IP 字面量匹配 iPAddress(上游 `X509_check_host` 不做,本实现超出上游) | test-chain-policy |

### 1.2.1 身份密钥类型扩展(第五轮)

| 项 | 做法 | 验证 |
|---|---|---|
| 自有身份密钥 | `pem->private-key` 识别 SEC1/PKCS#8 的 P-256/P-384/P-521(曲线取自参数)与 Ed25519(RFC 8410);`server-sign` 统一签名(RSA PSS/PKCS#1 ×3 摘要、ECDSA 三曲线、Ed25519),TLS 1.2/1.3 服务端与客户端 CertificateVerify 均按对端 signature_algorithms 选方案 | test-key-types 40 项(5 种密钥 × 1.3/1.2 × 服务端身份/客户端身份) |
| 附带修复 | TLS 1.2 的 ECDSA 方案 id 只定哈希、曲线取自密钥(此前按 1.3 的曲线配对解析,P-384 服务端用 ecdsa+SHA-256 签名时报 "INTEGER exceeds field size");1.3 仍强制配对;ECDSA DER 编码 SEQUENCE 长度超 127 时用长格式(P-521 签名此前为畸形 DER);客户端 supported_groups 增加 P-384/P-521(libssl 要求证书曲线在客户端列表内,否则 TLS 1.2 下 handshake_failure);P-521 ECDHE 密钥交换(C 原语 p521_pubkey/ecdh);1.2 CertificateRequest 的 sigalgs 列表补全 | test-openssl-client 23 项(s_client 对每种密钥 1.3/1.2 验证通过);我方客户端对 OpenSSL s_server 各密钥 1.3/1.2 全通过;LibreSSL s_server 不支持 Ed25519 证书(其自身限制) |

仍未对标(设计如此):TLS 1.0/1.1、RSA 密钥交换、客户端主动重协商(以 no_renegotiation 拒绝)。

### 1.2.2 subagent 评审后的修复(第六轮)

两个独立评审(TLS 引擎/记录层/DH;校验器/X.509/API)共报 27 项,已核对并全部修复(除按设计不做的);
分组列于下表,每项对应测试:

| 组 | 修复 | 验证 |
|---|---|---|
| 安全 | S1 对端 ECDH 公钥长度校验+NIST 曲线上点校验(Racket 公开数据大数运算,曲线常量以测试证书公钥自检)、X25519 全零共享密钥拒绝;S2 CN 作主机名时一律受 nameConstraints 约束;S3 rfc822Name/URI 约束无前导点时精确匹配主机、本地部分区分大小写;S4 通配符至少两级(`*.com` 无效) | test-chain-policy 28(新增 CN/邮箱/通配符等固件,OpenSSL `verify` 同判) |
| 记录层 | C1 排空队列存原始密文、出队时解密(对端 KeyUpdate 后的记录不再用旧密钥);C4 >16KB 载荷分记录;R1 1.2 短记录(GCM <24/ChaCha <16/CBC 不足 MAC+1)返回 bad_record_mac 而非合约错误;1.2 排空队列上限;对端长度字段引发的合约错误统一转为 decode_error(50) | test-key-update-drain 4(1MB 对写 + KeyUpdate);test-suites/basic 不变 |
| 校验器 | C6 自签发中间证书不计 pathLen、不受名称约束;C7 v1 自签名根(无扩展)与自签名叶子作锚;C8 critical 的 inhibitAnyPolicy/policyMappings/CRLDP/proxyCertInfo 视为已知;C9 anyEKU 不满足 serverAuth/clientAuth(同 libssl);R2 不可解析的锚/目录文件跳过;R4 私钥解析:坏 base64、Ed25519 种子长度、EC 标量长度 | test-chain-policy |
| API | C3 `'tls12` 服务端 context 只协商 1.2(且不写 DOWNGRD 哨兵);C5 cipher 串:`!` 永久、`-` 可恢复、COMPLEMENTOFDEFAULT 为空、无匹配在 `ssl-set-ciphers!` 报错;C10 DER 私钥(`asn1? #t`、`'der`);C11 `'(macosx-keychain #f)`;C12 端口可传给 `ssl-load-verify-root-certificates!`;C13 `#:shutdown-on-close?` 为假时关闭输出端口不发 close_notify(同文档) | test-api-compat 11 |
| 协议 | C14 客户端检查 session_id 回显(仅 1.3)、HRR 群/套件一致、PSK selected_identity 与哈希;1.2 恢复套件/EMS 一致;C2 1.2 服务端恢复回显 extended_master_secret、保留客户端身份、不再在恢复 SH 里带 SessionTicket 扩展(RFC 5077 §3.3 否则须发 NST) | OpenSSL `s_client -tls1_2 -reconnect`:5 次恢复均成功、无错误 |

低优先级项亦已修(第七轮,提交见 git log):记录层写锁(KeyUpdate 应答与写密钥切换原子);PHA 请求改为非阻塞等待完成信号量,
各读路径对接收缓冲只追加不覆盖;默认验证源按源缓存 10 分钟(`ssl-secure-client-context` 19ms→1ms);C 侧
`rktcrypto_p256_ecdh` 与通用 `ecc_ecdh` 加曲线上点校验(y² = x³ − 3x + b,Montgomery 域),三曲线对篡改一位的点均返回 0
(需 make cs 重链,已在 tmux racket-tls13 完成)。

### 1.3 仍存在的差异

1. (已解决)`peer-verif.rkt` 的三个 `#:later` 用例曾因无 TLS 1.2 重协商失败;现服务端主动的安全重协商已实现(见上表)。
2. `bn_modexp`(C)的固定窗口幂在窗口值为 0 时跳过乘法(`if(d) bn_montmul`),对私钥指数非严格常数时间;命名群路径
   原本即用此函数,本轮未改。
3. `ssl-try-verify!` 文档已改为与实现一致(出示但验证失败的证书被拒绝)。
4. 关闭写方向时若对端已先关闭,不发送 close_notify(与上游实测一致,`basic.rkt` 依赖)。
5. S3/S4 未处理。

## 2. 不属于 rktcrypto 的失败

- `test-sni.rkt`:对端是 `/usr/bin/openssl s_server`,macOS 上为 LibreSSL 3.3.6。上游 libssl 版 9.2 在本机同样 3/4 失败:
  SNI 与 `-servername test.com` 不符时 LibreSSL 发 `unrecognized name`;用例 #1 期望 OpenSSL 的输出
  `TLS client extension "server name"`,LibreSSL 打印 `TLS server extension "server name"`。
- `test-secure.rkt`:`pre-release.racket-lang.org` 在 2026-10-23 对 OpenSSL 3.6.3 `s_client` 与上游 9.2 同样
  "unexpected EOF",为服务端问题;其余 12 项通过。
- `hostname.rkt`、`test-keylog.rkt` 需要访问公网,未在本次运行。

## 3. 运行方法

```sh
# 全部 openssl 测试
racket/bin/raco test --timeout 120 pkgs/racket-test/tests/openssl
# 演示脚本(不是测试)
racket/bin/racket pkgs/racket-test/tests/openssl/compat/repro/record-plaintext-after-keys.rkt
racket/bin/racket pkgs/racket-test/tests/openssl/compat/repro/handshake-unbounded-buffer.rkt
```

语义基准仍为上游 libssl 版 Racket 9.2(`98b92f8ba3`,本机构建于 `~/Y2026/M07/D16/racket-baseline`)的实测行为。
