/* SHA-384 / SHA-512 / SHA-512-256, per FIPS 180-4.

   A from-scratch public-domain-style implementation, written against
   the standard and validated by the NIST test vectors in
   rktcrypto_selftest.c. No external dependencies; the same code runs
   on every platform. Hardware-accelerated paths may be added later
   behind the dispatch layer without changing this reference path. */

#include "rktcrypto_digest.h"

/* Initial hash values, FIPS 180-4 sections 5.3.3-5.3.6 */
const uint64_t rktcrypto_sha512_iv[8] = {
  0x6a09e667f3bcc908ULL, 0xbb67ae8584caa73bULL, 0x3c6ef372fe94f82bULL, 0xa54ff53a5f1d36f1ULL,
  0x510e527fade682d1ULL, 0x9b05688c2b3e6c1fULL, 0x1f83d9abfb41bd6bULL, 0x5be0cd19137e2179ULL
};
const uint64_t rktcrypto_sha384_iv[8] = {
  0xcbbb9d5dc1059ed8ULL, 0x629a292a367cd507ULL, 0x9159015a3070dd17ULL, 0x152fecd8f70e5939ULL,
  0x67332667ffc00b31ULL, 0x8eb44a8768581511ULL, 0xdb0c2e0d64f98fa7ULL, 0x47b5481dbefa4fa4ULL
};
const uint64_t rktcrypto_sha512_256_iv[8] = {
  0x22312194fc2bf72cULL, 0x9f555fa3c84c64c2ULL, 0x2393b86b6f53b151ULL, 0x963877195940eabdULL,
  0x96283ee2a88effe3ULL, 0xbe5e1e2553863992ULL, 0x2b0199fc2c85b8aaULL, 0x0eb72ddc81c52ca2ULL
};

#define ROTR64(x, n) (((x) >> (n)) | ((x) << (64 - (n))))
#define SHR64(x, n)  ((x) >> (n))

#define BSIG0(x) (ROTR64(x, 28) ^ ROTR64(x, 34) ^ ROTR64(x, 39))
#define BSIG1(x) (ROTR64(x, 14) ^ ROTR64(x, 18) ^ ROTR64(x, 41))
#define SSIG0(x) (ROTR64(x, 1) ^ ROTR64(x, 8) ^ SHR64(x, 7))
#define SSIG1(x) (ROTR64(x, 19) ^ ROTR64(x, 61) ^ SHR64(x, 6))
#define CH(x, y, z)  (((x) & (y)) ^ (~(x) & (z)))
#define MAJ(x, y, z) (((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))

static const uint64_t K512[80] = {
  0x428a2f98d728ae22ULL, 0x7137449123ef65cdULL, 0xb5c0fbcfec4d3b2fULL, 0xe9b5dba58189dbbcULL,
  0x3956c25bf348b538ULL, 0x59f111f1b605d019ULL, 0x923f82a4af194f9bULL, 0xab1c5ed5da6d8118ULL,
  0xd807aa98a3030242ULL, 0x12835b0145706fbeULL, 0x243185be4ee4b28cULL, 0x550c7dc3d5ffb4e2ULL,
  0x72be5d74f27b896fULL, 0x80deb1fe3b1696b1ULL, 0x9bdc06a725c71235ULL, 0xc19bf174cf692694ULL,
  0xe49b69c19ef14ad2ULL, 0xefbe4786384f25e3ULL, 0x0fc19dc68b8cd5b5ULL, 0x240ca1cc77ac9c65ULL,
  0x2de92c6f592b0275ULL, 0x4a7484aa6ea6e483ULL, 0x5cb0a9dcbd41fbd4ULL, 0x76f988da831153b5ULL,
  0x983e5152ee66dfabULL, 0xa831c66d2db43210ULL, 0xb00327c898fb213fULL, 0xbf597fc7beef0ee4ULL,
  0xc6e00bf33da88fc2ULL, 0xd5a79147930aa725ULL, 0x06ca6351e003826fULL, 0x142929670a0e6e70ULL,
  0x27b70a8546d22ffcULL, 0x2e1b21385c26c926ULL, 0x4d2c6dfc5ac42aedULL, 0x53380d139d95b3dfULL,
  0x650a73548baf63deULL, 0x766a0abb3c77b2a8ULL, 0x81c2c92e47edaee6ULL, 0x92722c851482353bULL,
  0xa2bfe8a14cf10364ULL, 0xa81a664bbc423001ULL, 0xc24b8b70d0f89791ULL, 0xc76c51a30654be30ULL,
  0xd192e819d6ef5218ULL, 0xd69906245565a910ULL, 0xf40e35855771202aULL, 0x106aa07032bbd1b8ULL,
  0x19a4c116b8d2d0c8ULL, 0x1e376c085141ab53ULL, 0x2748774cdf8eeb99ULL, 0x34b0bcb5e19b48a8ULL,
  0x391c0cb3c5c95a63ULL, 0x4ed8aa4ae3418acbULL, 0x5b9cca4f7763e373ULL, 0x682e6ff3d6b2b8a3ULL,
  0x748f82ee5defb2fcULL, 0x78a5636f43172f60ULL, 0x84c87814a1f0ab72ULL, 0x8cc702081a6439ecULL,
  0x90befffa23631e28ULL, 0xa4506cebde82bde9ULL, 0xbef9a3f7b2c67915ULL, 0xc67178f2e372532bULL,
  0xca273eceea26619cULL, 0xd186b8c721c0c207ULL, 0xeada7dd6cde0eb1eULL, 0xf57d4f7fee6ed178ULL,
  0x06f067aa72176fbaULL, 0x0a637dc5a2c898a6ULL, 0x113f9804bef90daeULL, 0x1b710b35131c471bULL,
  0x28db77f523047d84ULL, 0x32caab7b40c72493ULL, 0x3c9ebe0a15c9bebcULL, 0x431d67c49c100d4cULL,
  0x4cc5d4becb3e42b6ULL, 0x597f299cfc657e2aULL, 0x5fcb6fab3ad6faecULL, 0x6c44198c4a475817ULL
};

void rktcrypto_sha512_core_init(rktcrypto_sha512_ctx_t *ctx, const uint64_t iv[8])
{
  int i;
  for (i = 0; i < 8; i++) ctx->h[i] = iv[i];
  ctx->len_hi = 0;
  ctx->len_lo = 0;
  ctx->buf_len = 0;
}

static void sha512_transform_portable(rktcrypto_sha512_ctx_t *ctx, const unsigned char *p)
{
  uint64_t w[80];
  uint64_t a, b, c, d, e, f, g, h;
  int t;

  for (t = 0; t < 16; t++) {
    w[t] = ((uint64_t)p[0] << 56) | ((uint64_t)p[1] << 48)
         | ((uint64_t)p[2] << 40) | ((uint64_t)p[3] << 32)
         | ((uint64_t)p[4] << 24) | ((uint64_t)p[5] << 16)
         | ((uint64_t)p[6] << 8)  | ((uint64_t)p[7]);
    p += 8;
  }
  for (t = 16; t < 80; t++)
    w[t] = SSIG1(w[t-2]) + w[t-7] + SSIG0(w[t-15]) + w[t-16];

  a = ctx->h[0]; b = ctx->h[1]; c = ctx->h[2]; d = ctx->h[3];
  e = ctx->h[4]; f = ctx->h[5]; g = ctx->h[6]; h = ctx->h[7];

  for (t = 0; t < 80; t++) {
    uint64_t t1 = h + BSIG1(e) + CH(e, f, g) + K512[t] + w[t];
    uint64_t t2 = BSIG0(a) + MAJ(a, b, c);
    h = g; g = f; f = e; e = d + t1;
    d = c; c = b; b = a; a = t1 + t2;
  }

  ctx->h[0] += a; ctx->h[1] += b; ctx->h[2] += c; ctx->h[3] += d;
  ctx->h[4] += e; ctx->h[5] += f; ctx->h[6] += g; ctx->h[7] += h;
}

#if defined(__ARM_FEATURE_SHA512)
# include <arm_neon.h>
/* Hardware SHA-512 using the ARMv8.2 FEAT_SHA512 instructions. The
   message schedule uses SHA512SU0/SU1 and the compression uses
   SHA512H/H2, two rounds per step across four 128-bit state vectors
   {a,b},{c,d},{e,f},{g,h}. Verified bit-exact against the portable
   transform over 5e4 random blocks and by the NIST self-test vectors.
   The instructions are constant-time in hardware. */
static void sha512_transform_hw(rktcrypto_sha512_ctx_t *ctx, const unsigned char *p)
{
  uint64x2_t m[8], s0, s1, s2, s3, s0i, s1i, s2i, s3i;
  int i, k;
  for (k = 0; k < 8; k++)
    m[k] = vreinterpretq_u64_u8(vrev64q_u8(vld1q_u8(p + 16 * k)));
  s0 = vld1q_u64(&ctx->h[0]); s1 = vld1q_u64(&ctx->h[2]);
  s2 = vld1q_u64(&ctx->h[4]); s3 = vld1q_u64(&ctx->h[6]);
  s0i = s0; s1i = s1; s2i = s2; s3i = s3;
  for (i = 0; i < 40; i++) {
    int j = i & 7;
    uint64x2_t mk, t0, t1, ns1, ns3;
    if (i >= 8) {
      /* W[2i..2i+1] = SU1(SU0(W[i-16], W[i-15..]), W[i-2..], W[i-7..]) */
      uint64x2_t w7 = vextq_u64(m[(i - 4) & 7], m[(i - 3) & 7], 1);
      uint64x2_t w2 = m[(i - 1) & 7];
      m[j] = vsha512su1q_u64(vsha512su0q_u64(m[j], m[(j + 1) & 7]), w2, w7);
    }
    mk  = vaddq_u64(m[j], vld1q_u64(&K512[2 * i]));
    t0  = vaddq_u64(vextq_u64(mk, mk, 1), s3);
    t1  = vsha512hq_u64(t0, vextq_u64(s2, s3, 1), vextq_u64(s1, s2, 1));
    ns3 = vsha512h2q_u64(t1, s1, s0);
    ns1 = vaddq_u64(s1, t1);
    s3 = s2; s2 = ns1; s1 = s0; s0 = ns3;   /* rotate the four state vectors */
  }
  s0 = vaddq_u64(s0, s0i); s1 = vaddq_u64(s1, s1i);
  s2 = vaddq_u64(s2, s2i); s3 = vaddq_u64(s3, s3i);
  vst1q_u64(&ctx->h[0], s0); vst1q_u64(&ctx->h[2], s1);
  vst1q_u64(&ctx->h[4], s2); vst1q_u64(&ctx->h[6], s3);
}
#endif

static void sha512_transform(rktcrypto_sha512_ctx_t *ctx, const unsigned char *p)
{
#if defined(__ARM_FEATURE_SHA512)
  sha512_transform_hw(ctx, p);
#else
  sha512_transform_portable(ctx, p);
#endif
}

void rktcrypto_sha512_core_update(rktcrypto_sha512_ctx_t *ctx,
                                  const unsigned char *data, intptr_t len)
{
  while (len > 0) {
    /* Bulk fast path: when the buffer is empty, transform whole blocks
       straight from the input, avoiding a byte-by-byte copy through
       ctx->buf (which otherwise doubles the memory traffic and dominates
       once the transform is hardware-accelerated). */
    if (ctx->buf_len == 0 && len >= 128) {
      intptr_t nblocks = len / 128;
      intptr_t nbytes = nblocks * 128, b;
      uint64_t add = (uint64_t)nbytes << 3, old = ctx->len_lo;
      ctx->len_lo += add;
      if (ctx->len_lo < old) ctx->len_hi++;
      ctx->len_hi += (uint64_t)nbytes >> 61;
      for (b = 0; b < nblocks; b++) { sha512_transform(ctx, data); data += 128; }
      len -= nbytes;
      continue;
    }

    {
      intptr_t n = 128 - ctx->buf_len, i;
      if (n > len) n = len;
      for (i = 0; i < n; i++) ctx->buf[ctx->buf_len + i] = data[i];
      ctx->buf_len += n;
      data += n;
      len -= n;

      /* 128-bit message-length counter, in bits */
      {
        uint64_t add = (uint64_t)n << 3;
        uint64_t old = ctx->len_lo;
        ctx->len_lo += add;
        if (ctx->len_lo < old) ctx->len_hi++;
        ctx->len_hi += (uint64_t)n >> 61;
      }

      if (ctx->buf_len == 128) {
        sha512_transform(ctx, ctx->buf);
        ctx->buf_len = 0;
      }
    }
  }
}

void rktcrypto_sha512_core_final(rktcrypto_sha512_ctx_t *ctx,
                                 unsigned char *out, intptr_t out_len)
{
  uint64_t len_hi = ctx->len_hi;
  uint64_t len_lo = ctx->len_lo;
  int i;

  /* Append 0x80, then pad with zeros to 112 mod 128, then 128-bit
     big-endian bit length. */
  {
    unsigned char pad = 0x80;
    rktcrypto_sha512_core_update(ctx, &pad, 1);
  }
  {
    unsigned char zero = 0;
    while (ctx->buf_len != 112)
      rktcrypto_sha512_core_update(ctx, &zero, 1);
  }
  {
    unsigned char lenbuf[16];
    for (i = 0; i < 8; i++) lenbuf[i]     = (unsigned char)(len_hi >> (56 - 8 * i));
    for (i = 0; i < 8; i++) lenbuf[8 + i] = (unsigned char)(len_lo >> (56 - 8 * i));
    /* Directly transform; update would re-count these bytes. */
    for (i = 0; i < 16; i++) ctx->buf[112 + i] = lenbuf[i];
    sha512_transform(ctx, ctx->buf);
    ctx->buf_len = 0;
  }

  for (i = 0; i < out_len; i++)
    out[i] = (unsigned char)(ctx->h[i >> 3] >> (56 - 8 * (i & 7)));
}
