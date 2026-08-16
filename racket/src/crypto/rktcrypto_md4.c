/* MD4 (RFC 1320).

   Cryptographically broken (practical collisions since 1995) and MUST NOT
   be used where any collision or preimage resistance matters. It exists
   only for legacy interoperability -- NTLM hashes, old file formats,
   rsync-style rolling checksums -- so those code paths need no external
   library. From scratch, no external code. */

#include "rktcrypto_digest.h"
#include <string.h>

#define ROTL32(x,n) (((x) << (n)) | ((x) >> (32 - (n))))

void rktcrypto_md4_core_init(rktcrypto_md4_ctx_t *ctx)
{
  ctx->h[0] = 0x67452301u; ctx->h[1] = 0xefcdab89u;
  ctx->h[2] = 0x98badcfeu; ctx->h[3] = 0x10325476u;
  ctx->len = 0; ctx->buf_len = 0;
}

/* Fully unrolled RFC 1320 transform (branchless). */
#define MD4_F(x,y,z) (((x) & (y)) | ((~(x)) & (z)))
#define MD4_G(x,y,z) (((x) & (y)) | ((x) & (z)) | ((y) & (z)))
#define MD4_H(x,y,z) ((x) ^ (y) ^ (z))
#define MD4_FF(a,b,c,d,x,s) a = ROTL32(a + MD4_F(b,c,d) + (x), s);
#define MD4_GG(a,b,c,d,x,s) a = ROTL32(a + MD4_G(b,c,d) + (x) + 0x5a827999u, s);
#define MD4_HH(a,b,c,d,x,s) a = ROTL32(a + MD4_H(b,c,d) + (x) + 0x6ed9eba1u, s);

static void md4_block(rktcrypto_md4_ctx_t *ctx, const unsigned char *p)
{
  uint32_t m[16], a, b, c, d;
  int i;
  for (i = 0; i < 16; i++)
    m[i] = (uint32_t)p[4*i] | ((uint32_t)p[4*i+1] << 8)
         | ((uint32_t)p[4*i+2] << 16) | ((uint32_t)p[4*i+3] << 24);
  a = ctx->h[0]; b = ctx->h[1]; c = ctx->h[2]; d = ctx->h[3];
  /* Round 1 */
  MD4_FF(a,b,c,d,m[ 0], 3) MD4_FF(d,a,b,c,m[ 1], 7) MD4_FF(c,d,a,b,m[ 2],11) MD4_FF(b,c,d,a,m[ 3],19)
  MD4_FF(a,b,c,d,m[ 4], 3) MD4_FF(d,a,b,c,m[ 5], 7) MD4_FF(c,d,a,b,m[ 6],11) MD4_FF(b,c,d,a,m[ 7],19)
  MD4_FF(a,b,c,d,m[ 8], 3) MD4_FF(d,a,b,c,m[ 9], 7) MD4_FF(c,d,a,b,m[10],11) MD4_FF(b,c,d,a,m[11],19)
  MD4_FF(a,b,c,d,m[12], 3) MD4_FF(d,a,b,c,m[13], 7) MD4_FF(c,d,a,b,m[14],11) MD4_FF(b,c,d,a,m[15],19)
  /* Round 2 */
  MD4_GG(a,b,c,d,m[ 0], 3) MD4_GG(d,a,b,c,m[ 4], 5) MD4_GG(c,d,a,b,m[ 8], 9) MD4_GG(b,c,d,a,m[12],13)
  MD4_GG(a,b,c,d,m[ 1], 3) MD4_GG(d,a,b,c,m[ 5], 5) MD4_GG(c,d,a,b,m[ 9], 9) MD4_GG(b,c,d,a,m[13],13)
  MD4_GG(a,b,c,d,m[ 2], 3) MD4_GG(d,a,b,c,m[ 6], 5) MD4_GG(c,d,a,b,m[10], 9) MD4_GG(b,c,d,a,m[14],13)
  MD4_GG(a,b,c,d,m[ 3], 3) MD4_GG(d,a,b,c,m[ 7], 5) MD4_GG(c,d,a,b,m[11], 9) MD4_GG(b,c,d,a,m[15],13)
  /* Round 3 */
  MD4_HH(a,b,c,d,m[ 0], 3) MD4_HH(d,a,b,c,m[ 8], 9) MD4_HH(c,d,a,b,m[ 4],11) MD4_HH(b,c,d,a,m[12],15)
  MD4_HH(a,b,c,d,m[ 2], 3) MD4_HH(d,a,b,c,m[10], 9) MD4_HH(c,d,a,b,m[ 6],11) MD4_HH(b,c,d,a,m[14],15)
  MD4_HH(a,b,c,d,m[ 1], 3) MD4_HH(d,a,b,c,m[ 9], 9) MD4_HH(c,d,a,b,m[ 5],11) MD4_HH(b,c,d,a,m[13],15)
  MD4_HH(a,b,c,d,m[ 3], 3) MD4_HH(d,a,b,c,m[11], 9) MD4_HH(c,d,a,b,m[ 7],11) MD4_HH(b,c,d,a,m[15],15)
  ctx->h[0] += a; ctx->h[1] += b; ctx->h[2] += c; ctx->h[3] += d;
}

void rktcrypto_md4_core_update(rktcrypto_md4_ctx_t *ctx,
                               const unsigned char *data, intptr_t len)
{
  ctx->len += (uint64_t)len * 8;
  if (ctx->buf_len) {
    while (len && ctx->buf_len < 64) { ctx->buf[ctx->buf_len++] = *data++; len--; }
    if (ctx->buf_len == 64) { md4_block(ctx, ctx->buf); ctx->buf_len = 0; }
  }
  while (len >= 64) { md4_block(ctx, data); data += 64; len -= 64; }
  while (len) { ctx->buf[ctx->buf_len++] = *data++; len--; }
}

void rktcrypto_md4_core_final(rktcrypto_md4_ctx_t *ctx,
                              unsigned char *out, intptr_t out_len)
{
  uint64_t bits = ctx->len;
  int i;
  unsigned char pad = 0x80;
  (void)out_len;
  rktcrypto_md4_core_update(ctx, &pad, 1);
  ctx->len -= 8;
  pad = 0;
  while (ctx->buf_len != 56) { rktcrypto_md4_core_update(ctx, &pad, 1); ctx->len -= 8; }
  for (i = 0; i < 8; i++) ctx->buf[ctx->buf_len++] = (unsigned char)(bits >> (8*i));
  md4_block(ctx, ctx->buf); ctx->buf_len = 0;
  for (i = 0; i < 4; i++) {
    out[4*i+0] = (unsigned char)(ctx->h[i]);
    out[4*i+1] = (unsigned char)(ctx->h[i] >> 8);
    out[4*i+2] = (unsigned char)(ctx->h[i] >> 16);
    out[4*i+3] = (unsigned char)(ctx->h[i] >> 24);
  }
}
