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

## 1. 修复后仍存在的差异(需决策或后续工作)

1. **已建立连接上的 `ssl-set-verify!` / `ssl-try-verify!`**:上游通过 TLS 1.2 重协商实现;本实现无重协商,
   且端口与 listener 共享 context,原先静默改写 context 会影响之后所有连接。现改为报错
   `ssl-set-verify!: failed (verification cannot be changed on an established connection; ...)`。
   后果:`peer-verif.rkt` 的三个 `#:later` 用例失败(握手期三个用例通过)。可选方案:TLS 1.3
   post-handshake authentication(RFC 8446 §4.6.2),但该测试强制 'tls12。
2. **DHE 客户端策略**:只接受 RFC 7919 命名群(ffdhe2048/3072/4096,g = 2),否则发 insufficient_security(71)
   中止(RFC 7919 §4 允许)。实测:OpenSSL 3.6.3 `s_server` 默认 auto-DH 即使客户端通告了 ffdhe 群,
   仍发 RFC 3526 MODP-2048,被本客户端拒绝;`-dhparam ffdhe2048.pem` 时握手成功。LibreSSL 3.3.6 同样被拒绝。
   由于客户端优先 ECDHE,仅"只开 DHE"的服务端受影响。若要接受 MODP 14/15/16,需 C 侧导出通用
   modexp(当前 `rktcrypto_ffdhe_derive` 只支持命名群)并重建。
3. **CBC 解密非常数时间**:填充与 MAC 都检查、MAC 总是计算(Lucky 13 的常见缓解形态),但不是常数时间实现。
4. `ssl-try-verify!` 文档写"验证失败时连接继续",与上游实现(及现在的本实现)不一致:出示但验证失败的证书
   会被拒绝。文档未改。
5. 关闭写方向时若对端已先关闭(已收到其 close_notify 或传输层 EOF),不再发送 close_notify:对端已停止
   在 TLS 层读取,发送只会阻塞或污染传输层;上游在该状态下实测也不发送(`basic.rkt` 依赖:关闭后复用原始管道)。

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
