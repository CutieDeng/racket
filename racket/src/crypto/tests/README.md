# rktcrypto test & acceptance suite

Verification harness for the built-in cryptography subsystem
(`racket/src/crypto`, exposed through `racket/crypto/*`), and the
acceptance gate for **removing the OpenSSL dependency on aarch64** (and
every other platform — nothing here is arch-specific).

## What runs today

| File | Kind | Runs with the in-tree Racket |
|------|------|------------------------------|
| `integration.rkt` | Functional acceptance | `racket .../integration.rkt` or `raco test` |
| `../benchmarks/crypto-benchmark.rkt` | Performance report + regression tripwire | `racket .../crypto-benchmark.rkt [--check\|--update-baseline]` |
| `tls-acceptance.rkt` | TLS backend acceptance (loopback) | `racket .../tls-acceptance.rkt` — SKIPs when no TLS backend |
| `../rktcrypto_selftest.c` | C-level KAT (one per family) | linked into the runtime; `crypto-subsystem-self-test?` |

`integration.rkt` is deliberately `#lang racket/base` + `file/sha1` +
`racket/crypto` only — no rackunit, no packages. A suite whose job is to
prove "the crypto stack needs nothing external" must itself need nothing
external. It reports the OpenSSL loader state at the end so a regression
that re-introduces a hard `libcrypto` dependency is visible.

### Functional coverage (`integration.rkt`)

Digests (KAT + one-shot == incremental == port-stream, all 19 algorithms
incl. SM3/RIPEMD-160/Whirlpool/MD4; SHAKE XOF prefix), AEAD (roundtrip +
ciphertext-tamper + wrong-AAD rejection, all algorithms), secretbox,
MAC (HMAC-SHA256 RFC 4231, SipHash), KDF (HKDF RFC 5869, PBKDF2 RFC 6070,
Argon2id), key exchange (X25519 RFC 7748 + agreement, P-256 ECDH),
signatures (Ed25519 RFC 8032, P-256 ECDSA, ML-DSA-65 + tamper), KEM
(ML-KEM-768 + hybrid X25519MLKEM768 + implicit-reject divergence),
`openssl/sha1` & `openssl/md5` compatibility wrappers, `crypto-random`.

### Performance regression (`crypto-benchmark.rkt`)

- default: human-readable throughput / ops report.
- `--update-baseline`: record current numbers to
  `crypto-benchmark-baseline.rktd` (machine-local; not committed — absolute
  MB/s vary by host, so record once per machine/build).
- `--check`: rerun and fail (exit 1) if any metric regressed more than
  20% below the recorded baseline. This is the throughput tripwire that
  guards against a silent perf loss during the migration.

The head-to-head-vs-OpenSSL differential + benchmark tooling used during
development (links `libcrypto`, proves bit-exactness) lives outside the
tree by design; the in-tree suite is the regression gate, not the
bit-exact oracle.

## OpenSSL removal status (aarch64 and all platforms)

**Primitive layer: already free of OpenSSL.** `openssl/sha1`,
`openssl/md5` dispatch to `racket/crypto`; `crypto-random-bytes` uses the
rktcrypto DRBG; the whole `racket/crypto/*` surface is from-scratch C.
None of these load `libcrypto`. `integration.rkt` demonstrates this.

**Only remaining dependency: the TLS stack (`openssl/mzssl`).** It is a
thin wrapper over `libssl`'s state machine (handshake, record I/O) with a
Racket port/BIO pump. `ssl-available?` is `#t` iff `libssl` loaded. On a
build that ships without the OpenSSL binaries, `ssl-available?` is `#f`
and there is no TLS — that is the gap the rktcrypto TLS backend must fill.

`tls-acceptance.rkt` is the oracle for that backend: a client<->server
loopback handshake + bidirectional echo, driven only through the public
`openssl` API (`ports->ssl-ports`, `ssl-make-{client,server}-context`).
It skips when no backend is loaded and passes when one is — unchanged
whether the backend is libssl (today's baseline) or rktcrypto (the goal).

### Phased plan to replace `libssl`

Build on `rktcrypto_tls13.c` (RFC 8448-verified key schedule + record
layer) and the existing primitives (AES-128/256-GCM, ChaCha20-Poly1305,
X25519/P-256 ECDHE, RSA/ECDSA/Ed25519 signatures, HKDF, X.509 parse).
Keep the `ssl-connect`/`ssl-listen`/`ports->ssl-ports` API; swap the
backend behind it. Each phase is gated by `tls-acceptance.rkt` (extended
per phase) plus interop against a real OpenSSL peer.

1. **TLS 1.3 client handshake state machine** — message parse/generate +
   extensions (SNI, ALPN, supported_groups, key_share, signature_algs),
   on top of `tls13.c`. Interoperable with modern HTTPS servers. Unblocks
   `net/http-client` HTTPS and `net/git-checkout` over the new backend.
2. **X.509 chain path validation + trust store** — chain building,
   signature/validity/name-constraint checks, hostname verification
   (RFC 6125), system trust anchors (macOS keychain / Windows store /
   PEM bundle). Today `mzssl` delegates all of this to libssl.
3. **TLS 1.2** — different PRF, record, and handshake flows, for peers
   without 1.3.
4. **Server side + ALPN/SNI selection + session resumption + the port
   integration (BIO pump) layer**, reaching feature parity with the
   `mzssl` surface (renegotiation, key-log, exporter, channel binding).

This is the largest single piece of the from-scratch effort (≈ rewriting
`libssl`); it is multi-session and is the scope decision to make before
starting. Until then, the acceptance suites above lock in the primitive
layer and stand ready to gate the TLS backend the moment it exists.
