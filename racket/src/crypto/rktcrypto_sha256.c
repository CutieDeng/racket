/* SHA-224 / SHA-256, per FIPS 180-4.

   From-scratch public-domain-style implementation, validated by the
   NIST test vectors in rktcrypto_selftest.c. Portable reference path;
   SHA-NI / ARMv8 acceleration may be added later behind dispatch. */

#include "rktcrypto_digest.h"
#if defined(__x86_64__) || defined(__i386__)
# include "rktcrypto_cpu.h"
# include "rktcrypto_x86.h"
#endif

#define ROTR32(x, n) (((x) >> (n)) | ((x) << (32 - (n))))
#define SHR32(x, n)  ((x) >> (n))

#define BSIG0(x) (ROTR32(x, 2) ^ ROTR32(x, 13) ^ ROTR32(x, 22))
#define BSIG1(x) (ROTR32(x, 6) ^ ROTR32(x, 11) ^ ROTR32(x, 25))
#define SSIG0(x) (ROTR32(x, 7) ^ ROTR32(x, 18) ^ SHR32(x, 3))
#define SSIG1(x) (ROTR32(x, 17) ^ ROTR32(x, 19) ^ SHR32(x, 10))
#define CH(x, y, z)  (((x) & (y)) ^ (~(x) & (z)))
#define MAJ(x, y, z) (((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))

const uint32_t rktcrypto_sha256_iv[8] = {
  0x6a09e667U, 0xbb67ae85U, 0x3c6ef372U, 0xa54ff53aU,
  0x510e527fU, 0x9b05688cU, 0x1f83d9abU, 0x5be0cd19U
};
const uint32_t rktcrypto_sha224_iv[8] = {
  0xc1059ed8U, 0x367cd507U, 0x3070dd17U, 0xf70e5939U,
  0xffc00b31U, 0x68581511U, 0x64f98fa7U, 0xbefa4fa4U
};

static const uint32_t K256[64] = {
  0x428a2f98U, 0x71374491U, 0xb5c0fbcfU, 0xe9b5dba5U, 0x3956c25bU, 0x59f111f1U, 0x923f82a4U, 0xab1c5ed5U,
  0xd807aa98U, 0x12835b01U, 0x243185beU, 0x550c7dc3U, 0x72be5d74U, 0x80deb1feU, 0x9bdc06a7U, 0xc19bf174U,
  0xe49b69c1U, 0xefbe4786U, 0x0fc19dc6U, 0x240ca1ccU, 0x2de92c6fU, 0x4a7484aaU, 0x5cb0a9dcU, 0x76f988daU,
  0x983e5152U, 0xa831c66dU, 0xb00327c8U, 0xbf597fc7U, 0xc6e00bf3U, 0xd5a79147U, 0x06ca6351U, 0x14292967U,
  0x27b70a85U, 0x2e1b2138U, 0x4d2c6dfcU, 0x53380d13U, 0x650a7354U, 0x766a0abbU, 0x81c2c92eU, 0x92722c85U,
  0xa2bfe8a1U, 0xa81a664bU, 0xc24b8b70U, 0xc76c51a3U, 0xd192e819U, 0xd6990624U, 0xf40e3585U, 0x106aa070U,
  0x19a4c116U, 0x1e376c08U, 0x2748774cU, 0x34b0bcb5U, 0x391c0cb3U, 0x4ed8aa4aU, 0x5b9cca4fU, 0x682e6ff3U,
  0x748f82eeU, 0x78a5636fU, 0x84c87814U, 0x8cc70208U, 0x90befffaU, 0xa4506cebU, 0xbef9a3f7U, 0xc67178f2U
};

void rktcrypto_sha256_core_init(rktcrypto_sha256_ctx_t *ctx, const uint32_t iv[8])
{
  int i;
  for (i = 0; i < 8; i++) ctx->h[i] = iv[i];
  ctx->len = 0;
  ctx->buf_len = 0;
}

#if defined(__ARM_FEATURE_SHA2) || (defined(__ARM_FEATURE_CRYPTO) && defined(__ARM_NEON))
# include <arm_neon.h>
/* Hardware SHA-256 block transform using the ARMv8 SHA-256 extension.
   Produces the same result as the portable path; validated by the
   NIST vectors. */
/* Multi-block hardware SHA-256. The running state (abef/cdgh) stays in registers
   across all blocks -- loaded once, stored once -- instead of the previous
   load-transform-store per block. Per round the message schedule is split
   (sha256su0 issued before the compression, sha256su1 after) so the independent
   schedule work fills the sha256h/h2 dependency-chain latency, matching OpenSSL's
   sha256_block_armv8. Bit-exact with the portable path (NIST vectors). */
static void sha256_transform_hw(rktcrypto_sha256_ctx_t *ctx, const unsigned char *p, intptr_t nblocks)
{
  uint32x4_t abef = vld1q_u32(&ctx->h[0]);
  uint32x4_t cdgh = vld1q_u32(&ctx->h[4]);

# define RND(m0, m1, m2, m3, koff)                              \
  do {                                                          \
    uint32x4_t _t0 = vaddq_u32(m0, vld1q_u32(&K256[koff]));     \
    uint32x4_t _s;                                              \
    m0 = vsha256su0q_u32(m0, m1);              /* schedule, pre-compress */ \
    _s = abef;                                                  \
    abef = vsha256hq_u32(abef, cdgh, _t0);                      \
    cdgh = vsha256h2q_u32(cdgh, _s, _t0);                       \
    m0 = vsha256su1q_u32(m0, m2, m3);          /* schedule, post-compress */ \
  } while (0)
# define RNDL(m, koff)                                          \
  do {                                                          \
    uint32x4_t _t0 = vaddq_u32(m, vld1q_u32(&K256[koff]));      \
    uint32x4_t _s = abef;                                       \
    abef = vsha256hq_u32(abef, cdgh, _t0);                      \
    cdgh = vsha256h2q_u32(cdgh, _s, _t0);                       \
  } while (0)

  while (nblocks-- > 0) {
    uint32x4_t s0 = abef, s1 = cdgh;
    uint32x4_t msg0 = vreinterpretq_u32_u8(vrev32q_u8(vld1q_u8(p + 0)));
    uint32x4_t msg1 = vreinterpretq_u32_u8(vrev32q_u8(vld1q_u8(p + 16)));
    uint32x4_t msg2 = vreinterpretq_u32_u8(vrev32q_u8(vld1q_u8(p + 32)));
    uint32x4_t msg3 = vreinterpretq_u32_u8(vrev32q_u8(vld1q_u8(p + 48)));
    RND(msg0, msg1, msg2, msg3, 0);   RND(msg1, msg2, msg3, msg0, 4);
    RND(msg2, msg3, msg0, msg1, 8);   RND(msg3, msg0, msg1, msg2, 12);
    RND(msg0, msg1, msg2, msg3, 16);  RND(msg1, msg2, msg3, msg0, 20);
    RND(msg2, msg3, msg0, msg1, 24);  RND(msg3, msg0, msg1, msg2, 28);
    RND(msg0, msg1, msg2, msg3, 32);  RND(msg1, msg2, msg3, msg0, 36);
    RND(msg2, msg3, msg0, msg1, 40);  RND(msg3, msg0, msg1, msg2, 44);
    RNDL(msg0, 48); RNDL(msg1, 52); RNDL(msg2, 56); RNDL(msg3, 60);
    abef = vaddq_u32(abef, s0);
    cdgh = vaddq_u32(cdgh, s1);
    p += 64;
  }
# undef RND
# undef RNDL
  vst1q_u32(&ctx->h[0], abef);
  vst1q_u32(&ctx->h[4], cdgh);
}
#endif

#if !(defined(__ARM_FEATURE_SHA2) || (defined(__ARM_FEATURE_CRYPTO) && defined(__ARM_NEON)))
static void sha256_transform_portable(rktcrypto_sha256_ctx_t *ctx, const unsigned char *p)
{
  uint32_t w[64];
  uint32_t a, b, c, d, e, f, g, h;
  int t;

  for (t = 0; t < 16; t++) {
    w[t] = ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16)
         | ((uint32_t)p[2] << 8)  | ((uint32_t)p[3]);
    p += 4;
  }
  for (t = 16; t < 64; t++)
    w[t] = SSIG1(w[t-2]) + w[t-7] + SSIG0(w[t-15]) + w[t-16];

  a = ctx->h[0]; b = ctx->h[1]; c = ctx->h[2]; d = ctx->h[3];
  e = ctx->h[4]; f = ctx->h[5]; g = ctx->h[6]; h = ctx->h[7];

  for (t = 0; t < 64; t++) {
    uint32_t t1 = h + BSIG1(e) + CH(e, f, g) + K256[t] + w[t];
    uint32_t t2 = BSIG0(a) + MAJ(a, b, c);
    h = g; g = f; f = e; e = d + t1;
    d = c; c = b; b = a; a = t1 + t2;
  }

  ctx->h[0] += a; ctx->h[1] += b; ctx->h[2] += c; ctx->h[3] += d;
  ctx->h[4] += e; ctx->h[5] += f; ctx->h[6] += g; ctx->h[7] += h;
}
#endif

static void sha256_transform(rktcrypto_sha256_ctx_t *ctx, const unsigned char *p, intptr_t nblocks)
{
#if defined(__ARM_FEATURE_SHA2) || (defined(__ARM_FEATURE_CRYPTO) && defined(__ARM_NEON))
  sha256_transform_hw(ctx, p, nblocks);
#elif defined(__x86_64__) || defined(__i386__)
  if (rktcrypto_cpu_has(RKTCRYPTO_CPU_X86_SHA)) {
    while (nblocks-- > 0) { rktcrypto_sha256_block_shani(ctx->h, p); p += 64; }
  } else {
    while (nblocks-- > 0) { sha256_transform_portable(ctx, p); p += 64; }
  }
#else
  while (nblocks-- > 0) { sha256_transform_portable(ctx, p); p += 64; }
#endif
}

void rktcrypto_sha256_core_update(rktcrypto_sha256_ctx_t *ctx,
                                  const unsigned char *data, intptr_t len)
{
  intptr_t i;
  /* complete a pending partial block first */
  if (ctx->buf_len) {
    intptr_t n = 64 - ctx->buf_len;
    if (n > len) n = len;
    for (i = 0; i < n; i++) ctx->buf[ctx->buf_len + i] = data[i];
    ctx->buf_len += n; ctx->len += (uint64_t)n << 3; data += n; len -= n;
    if (ctx->buf_len == 64) { sha256_transform(ctx, ctx->buf, 1); ctx->buf_len = 0; }
  }
  /* process whole blocks straight from the input (no copy, state stays resident) */
  if (len >= 64) {
    intptr_t nb = len >> 6, bytes = nb << 6;
    sha256_transform(ctx, data, nb);
    ctx->len += (uint64_t)bytes << 3; data += bytes; len -= bytes;
  }
  /* buffer the remaining tail */
  if (len > 0) {
    for (i = 0; i < len; i++) ctx->buf[i] = data[i];
    ctx->buf_len = len; ctx->len += (uint64_t)len << 3;
  }
}

void rktcrypto_sha256_core_final(rktcrypto_sha256_ctx_t *ctx,
                                 unsigned char *out, intptr_t out_len)
{
  uint64_t bit_len = ctx->len;
  int i;
  unsigned char pad = 0x80, zero = 0;

  rktcrypto_sha256_core_update(ctx, &pad, 1);
  while (ctx->buf_len != 56)
    rktcrypto_sha256_core_update(ctx, &zero, 1);

  for (i = 0; i < 8; i++)
    ctx->buf[56 + i] = (unsigned char)(bit_len >> (56 - 8 * i));
  sha256_transform(ctx, ctx->buf, 1);
  ctx->buf_len = 0;

  for (i = 0; i < out_len; i++)
    out[i] = (unsigned char)(ctx->h[i >> 2] >> (24 - 8 * (i & 3)));
}
