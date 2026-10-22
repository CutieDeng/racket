# openssl collection(rktcrypto 实现)已知缺陷与兼容性差异

记录日期:2026-10-22。对象:私有分支 `v9.3-dev` 中以 rktcrypto 重写的 `openssl` collection
(`racket/collects/openssl/private/rktcrypto-*.rkt`)。本目录的测试是**当前失败、修复后应通过**的测试。

## 0. 结论

| ID | 问题 | 类别 | 严重度 | 状态 | 失败测试 |
|---|---|---|---|---|---|
| C1 | `ssl-set-verify-hostname!` 被忽略:只开证书验证时仍检查主机名;只开主机名验证时完全不检查 | 安全 + 兼容 | 高(fail-open 方向) | 已验证 | `verify-hostname.rkt` |
| C2 | `ssl-try-verify!` 与 `ssl-set-verify!` 实现相同,服务端对无证书客户端也拒绝 | 兼容 | 中 | 已验证 | `try-verify.rkt` |
| C3 | 服务端开启客户端验证但未加载信任根时,接受任意客户端证书 | 安全 | 中 | 已验证 | `verify-without-anchors.rkt` |
| C4 | 服务端从不记录客户端证书:`ssl-peer-verified?`/`ssl-peer-subject-name` 在服务端恒为 `#f` | 兼容(双向 TLS 身份不可用) | 中 | 已验证 | `client-identity.rkt`、`try-verify.rkt` |
| C5 | `ssl-peer-verified?` 读 context 的当前标志,不是本连接的验证结果 | 安全 | 中 | 已验证 | `peer-verified.rkt` |
| C6 | 双方同时写、底层缓冲小时死锁(`basic.rkt` 卡死的原因) | 健壮性 | 中 | 已验证 | `small-buffer.rkt`、`../basic.rkt` |
| C7 | 不支持 DHE 与 CBC 套件,`ssl-set-ciphers!` 对其报错 | 兼容(需决策) | 低 | 已验证 | `../test-ephemeral.rkt` |
| C8 | 对端 alert 的报告不准确(`bad_record_mac` / `EOF` 代替真实 alert) | 诊断 | 低 | 已验证(现象)/ 推断(根因) | 无专门测试,见 C2/C3 输出 |
| S1 | 读密钥安装后仍接受明文非 application_data 记录 | 安全 | 中 | 已验证(记录层) | `repro/record-plaintext-after-keys.rkt` |
| S2 | 握手前的明文 application_data 无上限缓冲 | 安全(DoS) | 中 | 已验证 | `repro/handshake-unbounded-buffer.rkt` |
| S3 | 畸形握手消息抛 `exn:fail:contract` 而非网络异常 | 兼容 | 低 | 推断 | 无 |
| S4 | 客户端不按 `ssl-set-ciphers!` 检查服务端选定的 TLS 1.3 套件 | 信息 | 信息 | 已验证(代码) | 无 |

已在本分支修复(不在上表):TLS 1.3 客户端未要求 CertificateVerify;`'secure` 不开启验证。回归测试为
`../test-certverify-required.rkt`、`../test-secure-local.rkt`。

不是 rktcrypto 缺陷:`../test-sni.rkt` 在本机(macOS,`/usr/bin/openssl` = LibreSSL 3.3.6)上对上游
libssl 版 Racket 9.2 同样 3/4 失败,见第 4 节。

状态标注:**已验证** = 有实测输出;**推断** = 有代码证据但未实测;**未知** = 无法判定。

## 1. 基准与运行方法

- 代码基准:分支 `fix/tls13-handshake`(基于 `v9.3-dev@a4f5675a42`,含 TLS-01/02 修复)。下文行号以该分支为准。
  与 `a4f5675a42` 的换算:`rktcrypto-tls13.rkt` 第 802 行之后 +19 行;`rktcrypto-mzssl.rkt` 第 90 行之后 +5 行;
  其他文件行号相同。
- 语义基准:上游 libssl 版 Racket 9.2(`98b92f8ba3`)的**实测行为**。当文档与实现不一致时以实测为准(见 C2)。
- 每个测试都在两个构建上运行过:上游 9.2 全部通过;rktcrypto 全部失败(结果见各节)。

```sh
# 运行一个失败测试(在本分支构建的 racket 上)
racket/bin/raco test pkgs/racket-test/tests/openssl/compat/verify-hostname.rkt
# 全部
racket/bin/raco test pkgs/racket-test/tests/openssl/compat
# 复现脚本(不是测试,info.rkt 已排除于 raco test)
racket/bin/racket pkgs/racket-test/tests/openssl/compat/repro/record-plaintext-after-keys.rkt
```

注意:这些测试当前失败。若 CI 对 `tests/openssl` 运行 `raco test`,在修复前会变红;
如需暂时排除,在本目录加 `info.rkt`:`(define test-omit-paths 'all)`。

测试共用 `common.rkt`:本地 TLS 服务端(每个连接一个线程,经 channel 报告服务端观察到的
`(list 'ok peer-verified? peer-subject)` 或 `(list 'exn message)`),客户端以显式主机名连接。
证书来自 `../`:`server_crt.pem`(server.example.com)、`client_crt.pem`(client.example.com)均由
`cacert.pem`(测试 CA,不在系统信任源)签发;自签证书用 `openssl/test.pem`(CN=lambda)。

## 2. 安全与兼容缺陷

### C1 `ssl-set-verify-hostname!` 被忽略

- 上游语义(`pkgs/racket-doc/openssl/openssl.scrbl:889-904`):主机名验证与证书验证相互独立。
  "Hostname verification does not imply certificate verification";开启时,主机名不匹配或对端无证书均拒绝连接。
- 代码:
  - `rktcrypto-mzssl.rkt:175` `ssl-set-verify-hostname!` 只设置 context 的 `'verify-hostname?`。
  - `rktcrypto-mzssl.rkt:306` 把 `'verify-hostname?` 放进传给 `tls13-connect` 的 opts。
  - `rktcrypto-tls13.rkt:557-559`(`tls13-connect`)只读取 `'host` 与 `'verify?`,**从不读取 `'verify-hostname?`**。
  - `rktcrypto-tls13.rkt:824-825`(`finish-client-handshake-with-suite`):
    `(when (and verify? (not resuming?)) (verify-chain-and-host (unbox peer-certs) host anchors))`。
  - `rktcrypto-verify.rkt:264-266` `verify-chain-and-host`:只要 `host` 非 `#f` 就做主机名检查。
  - TLS 1.2 同样:`rktcrypto-tls12.rkt:140-141` 只读 `'host`/`'verify?`;`:191-193` 在 `verify?` 内检查主机名。
- 后果:
  1. 只开 `ssl-set-verify!`:连接主机名不在证书中即失败(比上游严格)。`../peer-verif.rkt` 因此失败。
  2. 只开 `ssl-set-verify-hostname!`:**完全不检查主机名**(比上游宽松,fail-open)。
- 修复方向:主机名检查由 `verify-hostname?` 单独控制;`verify?` 只控制链校验。`verify-hostname?` 为真而对端无证书时拒绝。
  两个握手实现(1.3 与 1.2)都要改。
- 失败测试 `verify-hostname.rkt`(两种协议各 4 项),当前 4/8 失败:
  ```
  hostname 127.0.0.1 does not match certificate ((server.example.com))     ← "verify only, other hostname"(auto、tls12)
  message: "auto: hostname only, wrong hostname"   (No exception raised)
  message: "tls12: hostname only, wrong hostname"  (No exception raised)
  ```

### C2 `ssl-try-verify!` 等同 `ssl-set-verify!`

- 上游实现(`e20421d429:racket/collects/openssl/mzssl.rkt:759-768`):`ssl-try-verify!` 设 `SSL_VERIFY_PEER`;
  `ssl-set-verify!` 设 `SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT`;均无 verify 回调。
  实测语义(9.2):服务端 try-verify 时,客户端**不出示**证书 → 连接继续,`ssl-peer-verified?` = `#f`;
  出示了但**验证失败**的证书 → 握手失败(`unknown ca`)。
  注:`ssl-try-verify!` 文档写"验证失败时连接继续",与上游实现不符;测试按上游实测行为编写。
- 代码:
  - `rktcrypto-mzssl.rkt:173-174` 两个函数体逐字相同:`(cx-set! (->context c/l) 'verify? (and on? #t))`。
  - `rktcrypto-mzssl.rkt:340-341` 服务端 `'request-client-cert` 与 `'require-client-cert` 都取 `'verify?`。
  - `rktcrypto-tls13.rkt:1149-1158`、`rktcrypto-tls12.rkt:434-445`:`require-client-cert` 为真且无证书 → alert 116 / 40。
- 修复方向:context 记录三态验证模式(none / try / require);`request-client-cert` = 模式非 none,
  `require-client-cert` = 模式为 require。客户端侧 try 模式的语义同样按上游核对。
- 失败测试 `try-verify.rkt`,当前 3/6 失败:
  ```
  "try-verify, no client certificate: connection proceeds"  actual: (client-exn "TLS alert: bad_record_mac (20)")
  "try-verify, no client certificate: not verified"         actual: "TLS alert: client certificate required (116)"
  "try-verify, trusted certificate: verified"               actual: #f     ← 见 C4
  ```
  `../peer-verif2.rkt` 因此失败(其服务端用 `ssl-try-verify!`)。

### C3 未加载信任根时接受任意客户端证书

- 上游实测(9.2):服务端 `ssl-set-verify!` 且未加载任何验证源,客户端出示自签或 CA 签发证书 →
  服务端 `certificate verify failed`,握手失败。
- 代码:`rktcrypto-tls13.rkt:1150-1154`、`rktcrypto-tls12.rkt:436-441`:
  ```racket
  [(pair? (unbox client-certs))
   (verify-certificate-verify ...)
   (let ([anchors (hash-ref opts 'client-ca-anchors '())])
     (when (pair? anchors) (verify-chain (unbox client-certs) anchors)))]
  ```
  信任根为空时跳过链校验。只校验 CertificateVerify(证明持有私钥),不校验证书是否可信。
- 后果:服务端以"开启客户端验证"作为访问控制、但未(或未成功)加载 CA 时,任何自签证书都能通过握手。
- 修复方向:去掉 `(when (pair? anchors) …)` 条件,信任根为空时 `verify-chain` 必须失败。
- 失败测试 `verify-without-anchors.rkt`,当前 4/4 失败:
  ```
  "auto, self-signed client certificate: server accepted: (ok #f #f)"
  "auto, CA-signed client certificate: server accepted: (ok #f #f)"
  (tls12 两项相同)
  ```

### C4 服务端从不记录客户端证书

- 代码:服务端建立连接对象时 peer 证书固定为空表:
  - `rktcrypto-tls13.rkt:1182` `(tls13-make-conn r neg-alpn '() …)`
  - `rktcrypto-tls12.rkt:479`、`:512` `(make-conn-12 r '() …)`
  握手中收到的 `client-certs`(tls13:1145)/ `client-ders`(tls12)没有传入连接对象。
- 后果:服务端 `ssl-peer-verified?`、`ssl-peer-subject-name`、`ssl-peer-issuer-name` 等对客户端恒为 `#f`,
  即使客户端证书已通过验证。依赖客户端身份的双向 TLS 应用无法工作;依赖 `ssl-peer-verified?` 放行的应用一律拒绝(fail-closed)。
- 修复方向:把已验证的客户端证书链存入连接对象(同时修 C5,记录"本连接是否验证通过")。
- 失败测试 `client-identity.rkt`,当前 2/4 失败:
  ```
  "auto: server's view of the client"   actual: (ok #f #f)  expected: (ok #t #"/C=US/.../CN=client.example.com/...")
  "tls12: server's view of the client"  actual: (ok #f #f)
  ```

### C5 `ssl-peer-verified?` 读取 context 标志

- 上游(`mzssl.rkt:1525-1529`):`SSL_get_verify_result` = `X509_V_OK` 且有对端证书,即本连接的验证结果。
- 代码:`rktcrypto-mzssl.rkt:424-426`:
  ```racket
  (and obj (cx-ref (ssl-port-obj-ctx obj) 'verify?) (pair? (tls-conn-peer-certs (ssl-port-obj-conn obj))))
  ```
  读的是 context **当前**的 `'verify?` 与对端是否发过证书。
- 后果:未验证建立的连接,事后对 context 调用 `ssl-set-verify! #t`,旧端口的 `ssl-peer-verified?` 由 `#f` 变 `#t`。
  在 TLS-01 修复前,它还会对冒充者返回 `#t`。
- 修复方向:握手结束时把"本连接是否完成链校验(及主机名校验)"写入连接对象,`ssl-peer-verified?` 只读该字段。
- 失败测试 `peer-verified.rkt`,当前 1/3 失败:`"after enabling verification on the context"`,实际 `#t`。

### C6 双方同时写入时死锁

- 现象:`../basic.rkt` 在 rktcrypto 构建上卡死(未改动的审计点构建同样卡死,4/4 次 90 秒超时);上游 9.2 通过。
  按管道容量实测(`basic.rkt` 第一种用例,30 秒上限):

  | 管道容量(字节) | 1 | 100 | 4096 | 65536 |
  |---|---|---|---|---|
  | rktcrypto | 卡死 | 卡死 | 通过 | 通过 |
  | 上游 9.2 | 通过 | 通过 | 通过 | 通过 |

  (`small-buffer.rkt` 单独运行时容量 100 有时通过,容量 1 稳定失败。)
- 卡死时两个线程的调用栈(实测):
  - 客户端:`write-bytes` → `tls-conn-write-bytes`(`rktcrypto-tls13.rkt:475`)→ `send`(`:414`)→ `rl-write-record`(`:142-152`)中的 `write-bytes`。
  - 服务端:仍在 `tls13-accept/13`(`:995`)→ `rl-write-record`(`:142-152`)。
- 根因:服务端收到客户端 Finished 后同步写 NewSessionTicket(`rktcrypto-tls13.rkt:1165-1181`);
  客户端握手已结束,同步写应用数据。`rl-write-record` 直接对底层端口 `write-bytes`,写满时阻塞且不读取对端数据;
  双方都只写不读。TCP 场景下系统缓冲通常能容纳,但双方同时写入超过 socket 缓冲的数据量时同样会死锁。
  上游 libssl 封装在写阻塞时会继续处理读。
- 修复方向:写路径在底层端口不可写时同时消费输入(例如等待 `write-evt` 与读事件,把读到的记录放入接收缓冲),
  或由单独的线程负责写出。
- 失败测试 `small-buffer.rkt`:`"pipe capacity 1"` 失败(10 秒内未完成)。

### C7 套件支持范围

- 代码:`rktcrypto-mzssl.rkt:189-200` `cipher-alias->ids` 只认 TLS 1.3 三个套件与 TLS 1.2 的
  ECDHE + AES-GCM / ChaCha20-Poly1305;`:201-227` `parse-cipher-policy`/`ssl-set-ciphers!` 无匹配时记 `'none` 并在连接时报
  `no supported cipher suite matches the policy`;`:231-232` `ssl-server-context-enable-dhe!`/`-ecdhe!` 为空操作。
  OpenSSL 的 `+` 组合语法(如 `"AES+EDH"`)不被解析(按 `[:, ]+` 切分,整串查表失败)。
- 现象:`../test-ephemeral.rkt` 2/2 失败(`"AES+EDH"`、`"ECDHE-RSA-AES128-SHA256"`);上游通过。
- 需决策:(a) 实现 DHE 与 CBC 套件以兼容;(b) 维持仅 AEAD 套件(安全上更保守),则修改文档与 `test-ephemeral.rkt`,
  并让 `ssl-set-ciphers!` 对不支持的套件给出明确错误。

### C8 alert 报告不准确

- 服务端在 TLS 1.3 下因缺少客户端证书发 alert 116 时,客户端报 `TLS alert: bad_record_mac (20)`(实测,见 C2 输出)。
  推断:服务端在 `rktcrypto-tls13.rkt:1156` 发 alert 时仍用握手写密钥,应用密钥在其后才安装(`:1160` 起),
  而客户端此时已用应用读密钥。
- TLS 1.2 对应情形客户端报 `EOF in 1.2 record`(实测);服务端以明文写 alert(`rktcrypto-tls12.rkt:443`)。
- 对端以 alert 关闭时,客户端常报 `unexpected EOF from peer`(`rktcrypto-tls13.rkt:107-111` `read-n`),
  而上游报出 alert 名称(如 `tlsv1 unrecognized name`,见第 4 节)。
- 修复方向:alert 用对端当前可解密的密钥阶段发送;读取方解析并报告收到的 alert。

## 3. 审计发现的其余安全问题

### S1 读密钥安装后接受明文记录

- 代码:`rktcrypto-tls13.rkt:116-138` `rl-read-record` 只在 `(and (rl-rkey r) (= type 23))` 时解密;
  其他类型走 `:138` `[else (values (bytes-ref hdr 0) body)]` 明文交付。
  `recv`(`:366-381`)把 type 21 映射为 EOF(`:373`);type 22 进入 `capture-nst!`(`:339-355`)或 `do-key-update!`(`:356-365`)。
- 后果(RFC 8446 §5:密钥就位后除兼容用 CCS 外不应出现明文记录):on-path 注入明文 close_notify → 静默截断;
  注入明文 KeyUpdate → 接收密钥错位(DoS);注入明文 NewSessionTicket → 会话缓存写入攻击者数据。
- 复现:`repro/record-plaintext-after-keys.rkt`(实测输出:`record 2: type=21 payload=#"\1\0" <-- forged PLAINTEXT alert ACCEPTED post-key`)。
  端到端注入未实测(推断)。
- 修复方向:读密钥安装后,除握手期间的 CCS 外,非 type 23 记录一律以 `unexpected_message`/`bad_record_mac` 中止。

### S2 握手前明文 application_data 无上限缓冲

- 代码:`rktcrypto-tls13.rkt:186-198` `hsr-fill`,`:196` `[(= type 23) (set-hsr-app! r (bytes-append (hsr-app r) payload))]`
  无上限追加并继续循环;`hsr-buf`、transcript 同样以 `bytes-append` 累加(O(n²) 复制)。
- 复现:`repro/handshake-unbounded-buffer.rkt`(实测:32 000 000 字节输入,内存增长约 146 MB)。持续发送时 `hsr-fill` 不返回(推断)。
- 修复方向:握手完成前收到 application_data 即中止(TLS 1.3 不允许 0-RTT 之外的早期数据);为握手缓冲设上限。

### S3 畸形握手消息的异常类型(推断)

- 解析函数(`parse-extensions`、`parse-certificate-msg` 等)以对端给出的长度做 `subbytes`/`bytes-ref`,越界抛
  `exn:fail:contract`;`with-transport-errors`(`rktcrypto-tls13.rkt:102-105`)只包住原始 I/O。
  上游协议错误多为 `exn:fail:network`,`raco pkg` 的网络重试据此判断。未逐一注入实测。

### S4 客户端不检查服务端所选 TLS 1.3 套件是否在策略内

- 代码:`rktcrypto-tls13.rkt:751` 只用 `suite-params` 判断套件是否受支持,不检查是否在 `ssl-set-ciphers!` 策略内。
  三个 1.3 套件都是 AEAD,无降级风险;服务端侧有 `pol-ok?` 过滤(`:974-979`)。

## 4. 不属于 rktcrypto 的失败

- `../test-sni.rkt`:对端是 `/usr/bin/openssl s_server`,macOS 上为 LibreSSL 3.3.6。上游 libssl 版 9.2 在本机同样 3/4 失败:
  SNI 与 `-servername test.com` 不符时 LibreSSL 发 `unrecognized name`;用例 #1 期望 OpenSSL 的输出
  `TLS client extension "server name"`,LibreSSL 打印 `TLS server extension "server name"`。
  rktcrypto 与该服务端的基本握手和 SNI 发送正常(手工探测:TLS 1.3 握手完成,服务端日志含 `localhost`)。
- `../hostname.rkt`、`../test-keylog.rkt`、`../test-secure.rkt` 需要访问公网,未在本次运行。

## 5. 修复后的验收标准

1. 本目录每个测试在 rktcrypto 构建上通过。
2. `../peer-verif.rkt`、`../peer-verif2.rkt`、`../basic.rkt` 通过(C1、C2/C4、C6);`../test-ephemeral.rkt` 按 C7 的决策通过或被修改。
3. `../test-certverify-required.rkt`、`../test-secure-local.rkt`、`../test-alpn.rkt`、`../test-server-sni.rkt`、
   `../test-channel-binding.rkt`、`../legacy.rkt`、`../https.rkt` 保持通过。
4. S1、S2 的复现脚本输出改为拒绝 / 有界。
5. 测试移出本目录、并入 `tests/openssl/` 时,删除本 README 中对应条目。
