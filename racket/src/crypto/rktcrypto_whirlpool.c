/* Whirlpool (ISO/IEC 10118-3:2004, Barreto/Rijmen, final 2003 tweak).

   512-bit hash: Miyaguchi-Preneel over the dedicated 512-bit block cipher
   W (an AES-like SPN on an 8x8 byte matrix, 10 rounds). The S-box and the
   eight 64-bit round tables (S-box fused with the cir(1,1,4,1,8,5,2,9)
   MixRows layer) are generated once from the spec's E/E^-1/R mini-boxes,
   guaranteeing the table contents match the standard by construction.
   From scratch, no external code. */

#include "rktcrypto_digest.h"
#include <string.h>

/* GF(2^8) with reduction polynomial x^8+x^4+x^3+x^2+1 (0x11d). */
static unsigned char wp_xtime(unsigned char x)
{
  return (unsigned char)((x << 1) ^ ((x & 0x80) ? 0x1d : 0));
}

static unsigned char WP_SBOX[256];
static uint64_t WP_T[8][256];    /* WP_T[j][b] byte k = S[b] * c[(k-j) mod 8] */
static uint64_t WP_RC[11];       /* round constants, rows 1..7 zero */
static int wp_inited = 0;

static void wp_init(void)
{
  static const unsigned char E[16] =
    {0x1,0xB,0x9,0xC,0xD,0x6,0xF,0x3,0xE,0x8,0x7,0x4,0xA,0x2,0x5,0x0};
  static const unsigned char R[16] =
    {0x7,0xC,0xB,0xD,0xE,0x4,0x9,0xF,0x6,0x3,0x8,0xA,0x2,0x5,0x1,0x0};
  static const unsigned char CIR[8] = {1,1,4,1,8,5,2,9};
  unsigned char Einv[16];
  int i, j, b, r;

  for (i = 0; i < 16; i++) Einv[E[i]] = (unsigned char)i;
  for (b = 0; b < 256; b++) {
    unsigned char a1 = E[(b >> 4) & 0xF], b1 = Einv[b & 0xF];
    unsigned char rr = R[a1 ^ b1];
    WP_SBOX[b] = (unsigned char)((E[a1 ^ rr] << 4) | Einv[b1 ^ rr]);
  }
  for (b = 0; b < 256; b++) {
    unsigned char s = WP_SBOX[b], mul[16];
    uint64_t row = 0;
    /* mul[c] = s * c for the five circulant coefficients used */
    mul[1] = s; mul[2] = wp_xtime(s); mul[4] = wp_xtime(mul[2]);
    mul[8] = wp_xtime(mul[4]); mul[5] = (unsigned char)(mul[4] ^ s);
    mul[9] = (unsigned char)(mul[8] ^ s);
    for (j = 0; j < 8; j++) row = (row << 8) | mul[CIR[j]];
    WP_T[0][b] = row;
    for (j = 1; j < 8; j++)
      WP_T[j][b] = (row >> (8*j)) | (row << (64 - 8*j));
  }
  for (r = 1; r <= 10; r++) {
    uint64_t rc = 0;
    for (j = 0; j < 8; j++) rc = (rc << 8) | WP_SBOX[8*(r-1)+j];
    WP_RC[r] = rc;
  }
  wp_inited = 1;
}

/* One rho application: dst_i = XOR_j T[j][byte_j(src_{(i-j) mod 8})] ^ key_i.
   byte_j extracts the j-th byte from the MSB end (big-endian row packing). */
#define WP_B(x,j) ((unsigned char)((x) >> (56 - 8*(j))))
#define WP_RHO(dst, src, i, keyword) \
  dst = WP_T[0][WP_B(src[(i)&7],0)]     ^ WP_T[1][WP_B(src[((i)+7)&7],1)] \
      ^ WP_T[2][WP_B(src[((i)+6)&7],2)] ^ WP_T[3][WP_B(src[((i)+5)&7],3)] \
      ^ WP_T[4][WP_B(src[((i)+4)&7],4)] ^ WP_T[5][WP_B(src[((i)+3)&7],5)] \
      ^ WP_T[6][WP_B(src[((i)+2)&7],6)] ^ WP_T[7][WP_B(src[((i)+1)&7],7)] \
      ^ (keyword)

static void wp_compress(rktcrypto_whirlpool_ctx_t *ctx, const unsigned char *p, intptr_t nblk)
{
  while (nblk-- > 0) {
    uint64_t K[8], S[8], LK[8], LS[8], M[8];
    int i, r;
    for (i = 0; i < 8; i++) {
      uint64_t m;
      m = ((uint64_t)p[8*i]   << 56) | ((uint64_t)p[8*i+1] << 48)
        | ((uint64_t)p[8*i+2] << 40) | ((uint64_t)p[8*i+3] << 32)
        | ((uint64_t)p[8*i+4] << 24) | ((uint64_t)p[8*i+5] << 16)
        | ((uint64_t)p[8*i+6] <<  8) |  (uint64_t)p[8*i+7];
      M[i] = m;
      K[i] = ctx->h[i];
      S[i] = m ^ K[i];
    }
    for (r = 1; r <= 10; r++) {
      for (i = 0; i < 8; i++) { WP_RHO(LK[i], K, i, (i == 0) ? WP_RC[r] : 0); }
      for (i = 0; i < 8; i++) { WP_RHO(LS[i], S, i, LK[i]); }
      for (i = 0; i < 8; i++) { K[i] = LK[i]; S[i] = LS[i]; }
    }
    for (i = 0; i < 8; i++) ctx->h[i] ^= S[i] ^ M[i];   /* Miyaguchi-Preneel */
    p += 64;
  }
}

void rktcrypto_whirlpool_core_init(rktcrypto_whirlpool_ctx_t *ctx)
{
  if (!wp_inited) wp_init();
  memset(ctx->h, 0, sizeof(ctx->h));
  ctx->len = 0; ctx->buf_len = 0;
}

void rktcrypto_whirlpool_core_update(rktcrypto_whirlpool_ctx_t *ctx,
                                     const unsigned char *data, intptr_t len)
{
  ctx->len += (uint64_t)len * 8;
  if (ctx->buf_len) {
    while (len && ctx->buf_len < 64) { ctx->buf[ctx->buf_len++] = *data++; len--; }
    if (ctx->buf_len == 64) { wp_compress(ctx, ctx->buf, 1); ctx->buf_len = 0; }
  }
  if (len >= 64) { intptr_t nb = len >> 6; wp_compress(ctx, data, nb); data += nb<<6; len -= nb<<6; }
  while (len) { ctx->buf[ctx->buf_len++] = *data++; len--; }
}

void rktcrypto_whirlpool_core_final(rktcrypto_whirlpool_ctx_t *ctx,
                                    unsigned char *out, intptr_t out_len)
{
  uint64_t bits = ctx->len;
  int i;
  unsigned char pad = 0x80;
  (void)out_len;
  rktcrypto_whirlpool_core_update(ctx, &pad, 1);
  ctx->len -= 8;
  pad = 0;
  /* pad to 32 mod 64, then a 256-bit big-endian length (top 192 bits zero
     here: the incremental API keeps a 64-bit byte count). */
  while (ctx->buf_len != 32) { rktcrypto_whirlpool_core_update(ctx, &pad, 1); ctx->len -= 8; }
  for (i = 0; i < 24; i++) ctx->buf[ctx->buf_len++] = 0;
  for (i = 0; i < 8; i++) ctx->buf[ctx->buf_len++] = (unsigned char)(bits >> (56 - 8*i));
  wp_compress(ctx, ctx->buf, 1); ctx->buf_len = 0;
  for (i = 0; i < 8; i++) {
    out[8*i+0] = (unsigned char)(ctx->h[i] >> 56);
    out[8*i+1] = (unsigned char)(ctx->h[i] >> 48);
    out[8*i+2] = (unsigned char)(ctx->h[i] >> 40);
    out[8*i+3] = (unsigned char)(ctx->h[i] >> 32);
    out[8*i+4] = (unsigned char)(ctx->h[i] >> 24);
    out[8*i+5] = (unsigned char)(ctx->h[i] >> 16);
    out[8*i+6] = (unsigned char)(ctx->h[i] >> 8);
    out[8*i+7] = (unsigned char)(ctx->h[i]);
  }
}
