# openssl collection(rktcrypto 实现):兼容性缺陷清单与修复状态

记录日期:2026-10-22;修复完成:2026-10-23。对象:私有分支 `v9.3-dev` 中以 rktcrypto 重写的
`openssl` collection(`racket/collects/openssl/private/rktcrypto-*.rkt`),分支 `fix/tls13-handshake`。

本目录原先存放"当前失败、修复后应通过"的测试;全部修复后,测试已移入 `tests/openssl/`
(见下表),本目录只剩本文件与 `repro/` 下两个演示脚本(`info.rkt` 将其排除于 `raco test`)。

## 0. 结论

| ID | 问题 | 状态 | 修复提交 | 回归测试(`tests/openssl/`) |
|---|---|---|---|---|
| C1 | `ssl-set-verify-hostname!` 被忽略 | 已修复 | 5f3c1c5171 | `test-verify-hostname.rkt`(8) |
| C2 | `ssl-try-verify!` 等同 `ssl-set-verify!` | 已修复 | 977915ee1f | `test-try-verify.rkt`(6) |
| C3 | 未加载信任根时接受任意客户端证书 | 已修复 | 977915ee1f | `test-verify-without-anchors.rkt`(4) |
| C4 | 服务端不记录客户端证书 | 已修复 | 977915ee1f | `test-client-identity.rkt`(4)、`peer-verif2.rkt` |
| C5 | `ssl-peer-verified?` 读 context 标志 | 已修复 | 5f3c1c5171 | `test-peer-verified.rkt`(3) |
| C6 | 双方同时写入时死锁 | 已修复 | ba85f0392b | `test-small-buffer.rkt`(3)、`basic.rkt`(9 用例全过) |
| C7 | 不支持 DHE/CBC 套件 | 已实现 | f655e53388 | `test-ephemeral.rkt`(2)、`test-suites.rkt`(28) |
| C8 | alert 报告不准确 | 已修复 | 977915ee1f | 无专门测试;C2/C3 测试的异常文本含 alert 名 |
| S1 | 读密钥安装后接受明文记录 | 已修复 | 922eb6ff17 | `repro/record-plaintext-after-keys.rkt` 输出 REJECTED |
| S2 | 握手前明文 application_data 无界缓冲 | 已修复 | 922eb6ff17 | `repro/handshake-unbounded-buffer.rkt` 输出 REJECTED |
| S3 | 畸形握手消息抛 `exn:fail:contract` | 未处理 | — | — |
| S4 | 客户端不按策略检查服务端所选 1.3 套件 | 未处理(信息) | — | — |

另有两项修复不在原清单:握手失败异常文本改为上游形式 `<who>: connect failed (...)` /
`accept failed (...)`(`peer-verif2.rkt` 依赖),`ssl-peer-subject-name` / `ssl-peer-issuer-name`
改为 `X509_NAME_oneline` 形式 `/C=US/O=.../CN=...`(`peer-verif.rkt`、`peer-verif2.rkt` 依赖)。

状态标注:**已验证** = 有实测输出;**推断** = 有代码证据但未实测;**未知** = 无法判定。

## 1. 第二轮(2026-10-23,提交 da9c4bd8e5)

用户决策:C 侧导出通用 modexp 并接受 MODP 群;实现 TLS 1.3 post-handshake authentication;分支保留不合入;
"推断"项按源码正向分析。

| 项 | 做法 | 验证 |
|---|---|---|
| DHE 客户端策略 | `rktcrypto_dh_keygen/derive`(任意素数);白名单 = RFC 7919 ffdhe2048/3072/4096 + RFC 3526 MODP 14/15/16(g=2),素数由公式计算并与 C 常量/OpenSSL 内置群逐字节核对;其余仍发 insufficient_security | OpenSSL 3.6.3 默认 auto-DH(MODP-2048)与 LibreSSL 3.3.6:9 组套件双向 18/18 通过 |
| 端口上 `ssl-set-verify!`/`ssl-try-verify!` | TLS 1.3 post-handshake auth(RFC 8446 §4.6.2):客户端通告 post_handshake_auth,服务端发 CertificateRequest 并同步等待 Certificate/CertificateVerify/Finished,期间到达的应用数据排队;TLS 1.2 仍报错 | `test-post-handshake-auth.rkt` 14 项;`peer-verif.rkt` 强制 'tls12,其 `#:later` 3 用例仍失败 |
| CBC 时序 | 双方协商 encrypt_then_mac(RFC 7366):MAC 覆盖公开长度的密文,先验 MAC 再看填充,无 Lucky 13 信号;会话票记录该框架,不一致则全握手。MtE 保留给无扩展的对端,填充检查改为 256 字节固定窗口掩码扫描 | `test-suites.rkt` 42 项(我方两端协商 EtM);OpenSSL/LibreSSL 对拍 |
| ECDSA 套件自互通 | 新增 P-256 服务端证书 `server_ec_{key,crt}.pem`(`generate-certs.sh`) | `test-suites.rkt` 7 个 ECDHE-ECDSA 套件 × 管道 10/4096 |

### 1.1 MtE 路径的正向分析(仍存在的泄漏,已验证于源码)

`cbc-open`(`rktcrypto-tls12.rkt`)MtE 分支:解密后取末字节 padlen → `padding-ok?` 对最后 256 字节做掩码扫描
(循环次数与 padlen 无关,无数据相关分支)→ `frag-len = ptlen - padlen - 1 - mac-len` → `hmac` 覆盖 `13 + frag-len` 字节。
HMAC 的压缩块数 = ⌈(13 + frag-len + 9) / 64⌉(SHA-1/256)或 /128(SHA-384),随 padlen 变化,即 Lucky 13 可观测量;
`ct-equal?` 为常数时间。消除需要按 libssl `ssl3_cbc_digest_record` 的方式在哈希内部状态上做固定块数的 HMAC,本轮未做。
该路径只在对端不支持 encrypt_then_mac 时进入;OpenSSL ≥ 1.0.1、GnuTLS、mbedTLS 均支持;LibreSSL 不支持
(对拍中 LibreSSL 走 MtE 路径,功能正确)。

### 1.2 仍存在的差异

1. `peer-verif.rkt` 的三个 `#:later` 用例:强制 'tls12,需重协商;TLS 1.3 下同样的调用已可用(见上表)。
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
# 全部 openssl 测试(peer-verif.rkt 的 #:later 用例会失败并等待超时,见第 1 节)
racket/bin/raco test --timeout 120 pkgs/racket-test/tests/openssl
# 演示脚本(不是测试)
racket/bin/racket pkgs/racket-test/tests/openssl/compat/repro/record-plaintext-after-keys.rkt
racket/bin/racket pkgs/racket-test/tests/openssl/compat/repro/handshake-unbounded-buffer.rkt
```

语义基准仍为上游 libssl 版 Racket 9.2(`98b92f8ba3`,本机构建于 `~/Y2026/M07/D16/racket-baseline`)的实测行为。
