# rktcrypto 汇编内核性能基线（Phase 0 门禁）

> 一切内核/生成器/asmp 侧改动，重提交前必须：① `asm/tests/` 差分全绿
> （0 mismatch + ABI guard PASS）；② 本表对应项 **±2%** 内。
> 基线随硬件失效：换机须重测全表。
>
> 机器：Apple Silicon (Darwin 25.4.0)，测量日 2026-07-26。
> 内核级 = `asm/tests/test_*.c`（cache-resident 重复调用，mach_absolute_time）；
> 端到端 = `benchmarks/crypto-benchmark.rkt`（racket 9.2.6 in-place 构建）。

## 内核级（asm/tests/）

| 内核 | 配置 | ns/op | 备注 |
|---|---|---|---|
| bn_mul_mont_op16 | k=16 | 106.3 | RSA-CRT mod p/q 热路径 |
| bn_mul_mont_fips32 | k=32 | 470.3 | RSA-2048 公开运算 |
| bn_sqr_mont_8w | k=8 | 24.9 | |
| bn_sqr_mont_8w | k=16 | 87.5 | |
| bn_sqr_mont_8w | k=32 | 323.2 | RSA verify 平方主内核 |
| md5_blocks_asm | 4 块/调用 | 69.1 /块 | 926.9 MB/s |
| sha1_blocks_asm | 4 块/调用 | 20.3 /块 | 3149 MB/s |
| mont_mul_asm (mod n) | 4 limb | ~11.5 | 既有数字（asm/README.md） |
| mont_mul_p256 (mod p) | 4 limb | — | 170 Mmul/s 吞吐（asm/README.md） |
| mont_sqrn_p256 (mod p) | 专用对称平方 | ~6.3 每平方(rep=255) | 10 积 vs mul-based 16；bit-exact 0/200000；rep=255 摊销 0.876x 旧版；fp_inv 2139→1933ns |
| mont_sqrn_asm (mod n) | rep=1 / rep=8 | 12.0 / 11.7 每平方 | |
| jac_double_hw | 含 r==p 别名 | 56.5 | 0/210000 差分（含真曲线点链） |
| mixed_add_hw | P-256 Jacobian 混合加 | ~0.90x C | 手写 register-resident（p256_hand.S），bit-exact 0/200000；交织比值 0.90（C 86→asm 78ns）；使 P-256 ECDH vs OpenSSL 1.17→1.14x |
| mul_plain6 | 6×6→12 limb | 11.3 | 轻串行依赖测法 |
| mul_plain9 | 9×9→18 limb | 19.9 | 同上 |
| reduce_p384_asm | P-384 Solinas 约简 | ~7（孤立）/ 见注 | vs C reduce_p384 15ns：孤立 2x；但 asm 是 `bl` 调用而 C 内联进 fp_mul，故 **field-mul 层实测 +16%**（交织采样载入免疫，C 18.4→asm 15.5ns）。端到端 P-384 ~+10-16%。correctness 由差分 0/9.2M bit-exact 保证 |
| keccak_absorb21_asm | nblk=4 | 119.3 /块 | 五 rate 恒 ≈118-119（24 轮置换主导） |
| keccak_absorb18_asm | nblk=4 | 119.1 /块 | |
| keccak_absorb17_asm | nblk=4 | 118.7 /块 | |
| keccak_absorb13_asm | nblk=4 | 118.5 /块 | |
| keccak_absorb9_asm | nblk=4 | 117.7 /块 | |
| keccak_f2_asm | 2 路/调用 | 123.3（≈61.6/路） | lane-major 交错布局 |

## 端到端（crypto-benchmark.rkt, 1 MiB 块 / fresh keys）

| 类别 | 项 | 数字 |
|---|---|---|
| digest | sha1 | 3097 MB/s |
| digest | md5 | 879 MB/s |
| digest | md4 | 1373 MB/s |
| digest | sha256 | 3096 MB/s |
| digest | sha512 | 1569 MB/s |
| digest | sha3-256 | 948 MB/s |
| digest | sha3-512 | 514 MB/s |
| digest | blake2b | 1468 MB/s |
| digest | blake3 | 1041 MB/s |
| digest | ripemd160 | 638 MB/s |
| digest | sm3 | 502 MB/s |
| digest | whirlpool | 398 MB/s |
| MAC | hmac-sha256 | 2680 MB/s |
| MAC | siphash-2-4 | 2934 MB/s |
| AEAD | chacha20-poly1305 | 2046 MB/s |
| AEAD | xchacha20-poly1305 | 1995 MB/s |
| AEAD | aes-256-gcm | 5846 MB/s |
| KDF | pbkdf2-sha256 10k | 15.38 ms |
| KDF | argon2id t=3 m=64MiB | 68.5 ms |
| PK | x25519 keygen / shared | 19.3 / 19.1 us |
| PK | ed25519 sign / verify | 15.1 / 36 us |
| PK | p256 ecdh | 26.8 us |
| PK | p256 ecdsa sign / verify | 10.8 / 33.1 us |
| PQC | ml-kem-768 kg/enc/dec | 12.8 / 12.7 / 13.9 us |
| PQC | ml-dsa-65 kg/sign/verify | 73.8 / 172.6 / 60.5 us |
| PQC | x25519mlkem768 kg/enc/dec | 31.4 / 48.9 / 31.5 us |

## 运行方式

```sh
# 内核级（在 crypto/ 目录）
cc -O2 -I.. -o /tmp/test_bn asm/tests/test_bn.c rktcrypto_bn_op.S rktcrypto_bn_fips.S rktcrypto_bn_sqr.S && /tmp/test_bn
cc -O2 -o /tmp/test_md5_sha1 asm/tests/test_md5_sha1.c rktcrypto_md5_asm.S rktcrypto_sha1_asm.S && /tmp/test_md5_sha1
cc -O2 -o /tmp/test_p256_extra asm/tests/test_p256_extra.c rktcrypto_p256_asm.S && /tmp/test_p256_extra
cc -O2 -o /tmp/test_ecc_mul asm/tests/test_ecc_mul.c rktcrypto_ecc_asm.S && /tmp/test_ecc_mul
# （其余 harness 见 asm/tests/ 各文件头部构建行）

# 端到端
racket benchmarks/crypto-benchmark.rkt

# 再生一致性
asm/regen.sh check
```

## 发射器静态成本 (sched-cost, F3)

`asm/gen/sched-cost.rkt` 查询 rktasm 的 apple-m 调度模型 (装配用同一份),
给每个可发射内核算三个**周期下界/建议值**——纯模型确定值, 无测量噪声,
与本机负载无关:

| kernel | instrs | issue-bound | port-bound | chain-latency |
|--------|-------:|------------:|-----------:|--------------:|
| bn_op     |  3300 | 1100 | 520 | 358 |
| bn_fips   | 15613 | 5205 | 2064 | 49 |
| ecc       |   828 |  276 | 117 | 42 |
| keccak    |   841 |  281 |  85 | 265 |
| keccak_f2 |   135 |   45 |  13 | 53 |
| sha1      |   119 |   40 |  14 | 18 |

- **issue-bound** = ⌈指令数 / issue-width(3)⌉，前端吞吐下界。
- **port-bound** = max_p ⌈count_p / capacity_p⌉，执行端口吞吐下界。
- **chain-latency** = 同名寄存器 + NZCV 进位链的最长延迟和 (pre-regalloc
  建议值; 重命名/内存别名不建模)。

读法印证内核设计: `bn_fips` 指令数最大但 chain-latency 仅 49——A/B 双
累加器为 ILP 而设, 端口/前端受限而非延迟受限; `bn_op` chain 358 是 CIOS
串行进位链, 延迟受限; keccak chain 265 是 θ→ρπ→χ 依赖深度。

**定位 = 回归诊断, 非增益猎取** (D1 已证宽乱序 M 核静态重调度无可靠增益)。
快照 `asm/gen/sched-cost.snapshot` 挂进 `regen.sh check`: 发射器改动若改变
任一内核的指令数/端口压力/关键路径即非零退出。有意改动后 `--snapshot` 重写。
真·性能裁决仍是交织 A/B (`regen.sh gate`)。
