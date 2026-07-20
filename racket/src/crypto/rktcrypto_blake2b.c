/* BLAKE2b, per RFC 7693.

   From-scratch public-domain-style implementation, validated by the
   RFC 7693 / official test vectors in rktcrypto_selftest.c. Supports
   arbitrary output length 1..64 and optional keying (BLAKE2b MAC).
   Portable reference; SIMD acceleration may be added later. */

#include "rktcrypto_digest.h"

#define ROTR64(x, n) (((x) >> (n)) | ((x) << (64 - (n))))

static const uint64_t BLAKE2B_IV[8] = {
  0x6a09e667f3bcc908ULL, 0xbb67ae8584caa73bULL, 0x3c6ef372fe94f82bULL, 0xa54ff53a5f1d36f1ULL,
  0x510e527fade682d1ULL, 0x9b05688c2b3e6c1fULL, 0x1f83d9abfb41bd6bULL, 0x5be0cd19137e2179ULL
};

static const unsigned char SIGMA[12][16] = {
  { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15},
  {14,10, 4, 8, 9,15,13, 6, 1,12, 0, 2,11, 7, 5, 3},
  {11, 8,12, 0, 5, 2,15,13,10,14, 3, 6, 7, 1, 9, 4},
  { 7, 9, 3, 1,13,12,11,14, 2, 6, 5,10, 4, 0,15, 8},
  { 9, 0, 5, 7, 2, 4,10,15,14, 1,11,12, 6, 8, 3,13},
  { 2,12, 6,10, 0,11, 8, 3, 4,13, 7, 5,15,14, 1, 9},
  {12, 5, 1,15,14,13, 4,10, 0, 7, 6, 3, 9, 2, 8,11},
  {13,11, 7,14,12, 1, 3, 9, 5, 0,15, 4, 8, 6, 2,10},
  { 6,15,14, 9,11, 3, 0, 8,12, 2,13, 7, 1, 4,10, 5},
  {10, 2, 8, 4, 7, 6, 1, 5,15,11, 9,14, 3,12,13, 0},
  { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15},
  {14,10, 4, 8, 9,15,13, 6, 1,12, 0, 2,11, 7, 5, 3}
};

#define G(r, i, a, b, c, d)                       \
  do {                                            \
    a = a + b + m[SIGMA[r][2*i]];                 \
    d = ROTR64(d ^ a, 32);                        \
    c = c + d;                                    \
    b = ROTR64(b ^ c, 24);                        \
    a = a + b + m[SIGMA[r][2*i+1]];               \
    d = ROTR64(d ^ a, 16);                        \
    c = c + d;                                    \
    b = ROTR64(b ^ c, 63);                        \
  } while (0)

static void blake2b_compress(rktcrypto_blake2b_ctx_t *ctx, const unsigned char *block, int last)
{
  uint64_t m[16], v[16];
  int i;

  for (i = 0; i < 16; i++) {
    const unsigned char *p = block + 8 * i;
    m[i] = ((uint64_t)p[0]) | ((uint64_t)p[1] << 8) | ((uint64_t)p[2] << 16) | ((uint64_t)p[3] << 24)
         | ((uint64_t)p[4] << 32) | ((uint64_t)p[5] << 40) | ((uint64_t)p[6] << 48) | ((uint64_t)p[7] << 56);
  }

  for (i = 0; i < 8; i++) { v[i] = ctx->h[i]; v[i+8] = BLAKE2B_IV[i]; }
  v[12] ^= ctx->t[0];
  v[13] ^= ctx->t[1];
  if (last) v[14] = ~v[14];

  /* Fully unrolled: with a literal round index every SIGMA[r][*] folds to a
     compile-time constant, so m[] reads become direct immediate-offset loads
     (no SIGMA table lookup, no indexed addressing) -- matches OpenSSL's
     unrolled ROUND structure. */
#define ROUND(r)                             \
    G(r, 0, v[0], v[4], v[ 8], v[12]);       \
    G(r, 1, v[1], v[5], v[ 9], v[13]);       \
    G(r, 2, v[2], v[6], v[10], v[14]);       \
    G(r, 3, v[3], v[7], v[11], v[15]);       \
    G(r, 4, v[0], v[5], v[10], v[15]);       \
    G(r, 5, v[1], v[6], v[11], v[12]);       \
    G(r, 6, v[2], v[7], v[ 8], v[13]);       \
    G(r, 7, v[3], v[4], v[ 9], v[14]);
  ROUND(0)  ROUND(1)  ROUND(2)  ROUND(3)
  ROUND(4)  ROUND(5)  ROUND(6)  ROUND(7)
  ROUND(8)  ROUND(9)  ROUND(10) ROUND(11)
#undef ROUND

  for (i = 0; i < 8; i++) ctx->h[i] ^= v[i] ^ v[i+8];
}

void rktcrypto_blake2b_core_init(rktcrypto_blake2b_ctx_t *ctx, intptr_t outlen,
                                 const unsigned char *key, intptr_t keylen)
{
  int i;
  for (i = 0; i < 8; i++) ctx->h[i] = BLAKE2B_IV[i];
  /* Parameter block: digest length, key length, fanout=1, depth=1 */
  ctx->h[0] ^= 0x01010000ULL ^ ((uint64_t)keylen << 8) ^ (uint64_t)outlen;
  ctx->t[0] = 0;
  ctx->t[1] = 0;
  ctx->buf_len = 0;
  ctx->outlen = outlen;

  if (keylen > 0) {
    unsigned char block[128];
    for (i = 0; i < 128; i++) block[i] = 0;
    for (i = 0; i < keylen; i++) block[i] = key[i];
    rktcrypto_blake2b_core_update(ctx, block, 128);
  }
}

static void inc_counter(rktcrypto_blake2b_ctx_t *ctx, uint64_t n)
{
  ctx->t[0] += n;
  if (ctx->t[0] < n) ctx->t[1]++;
}

void rktcrypto_blake2b_core_update(rktcrypto_blake2b_ctx_t *ctx,
                                   const unsigned char *data, intptr_t len)
{
  while (len > 0) {
    if (ctx->buf_len == 128) {
      /* buffer full and more data follows: it is not the last block */
      inc_counter(ctx, 128);
      blake2b_compress(ctx, ctx->buf, 0);
      ctx->buf_len = 0;
    }
    {
      intptr_t n = 128 - ctx->buf_len;
      intptr_t i;
      if (n > len) n = len;
      for (i = 0; i < n; i++) ctx->buf[ctx->buf_len + i] = data[i];
      ctx->buf_len += n;
      data += n;
      len -= n;
    }
  }
}

void rktcrypto_blake2b_core_final(rktcrypto_blake2b_ctx_t *ctx,
                                  unsigned char *out, intptr_t out_len)
{
  int i;
  unsigned char full[64];

  inc_counter(ctx, (uint64_t)ctx->buf_len);
  while (ctx->buf_len < 128) ctx->buf[ctx->buf_len++] = 0;
  blake2b_compress(ctx, ctx->buf, 1);

  for (i = 0; i < 64; i++)
    full[i] = (unsigned char)(ctx->h[i >> 3] >> (8 * (i & 7)));
  for (i = 0; i < out_len; i++)
    out[i] = full[i];
}
