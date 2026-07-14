/* SHA-3 (SHA3-224/256/384/512) and SHAKE128/256, per FIPS 202.

   From-scratch public-domain-style Keccak-f[1600] implementation,
   validated by the NIST test vectors in rktcrypto_selftest.c. The
   sponge construction here serves both fixed-output SHA-3 (domain
   byte 0x06) and the SHAKE XOFs (domain byte 0x1f). Portable
   reference; AVX2 acceleration may be added later behind dispatch. */

#include "rktcrypto_digest.h"

#define ROTL64(x, n) (((x) << (n)) | ((x) >> (64 - (n))))

static const uint64_t RC[24] = {
  0x0000000000000001ULL, 0x0000000000008082ULL, 0x800000000000808aULL, 0x8000000080008000ULL,
  0x000000000000808bULL, 0x0000000080000001ULL, 0x8000000080008081ULL, 0x8000000000008009ULL,
  0x000000000000008aULL, 0x0000000000000088ULL, 0x0000000080008009ULL, 0x000000008000000aULL,
  0x000000008000808bULL, 0x800000000000008bULL, 0x8000000000008089ULL, 0x8000000000008003ULL,
  0x8000000000008002ULL, 0x8000000000000080ULL, 0x000000000000800aULL, 0x800000008000000aULL,
  0x8000000080008081ULL, 0x8000000000008080ULL, 0x0000000080000001ULL, 0x8000000080008008ULL
};

static const int RHO[24] = {
  1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 2, 14,
  27, 41, 56, 8, 25, 43, 62, 18, 39, 61, 20, 44
};

static const int PI[24] = {
  10, 7, 11, 17, 18, 3, 5, 16, 8, 21, 24, 4,
  15, 23, 19, 13, 12, 2, 20, 14, 22, 9, 6, 1
};

static void keccak_f(uint64_t s[25])
{
  int round, i;
  for (round = 0; round < 24; round++) {
    uint64_t bc[5], t;

    /* Theta */
    for (i = 0; i < 5; i++)
      bc[i] = s[i] ^ s[i+5] ^ s[i+10] ^ s[i+15] ^ s[i+20];
    for (i = 0; i < 5; i++) {
      t = bc[(i+4)%5] ^ ROTL64(bc[(i+1)%5], 1);
      s[i] ^= t; s[i+5] ^= t; s[i+10] ^= t; s[i+15] ^= t; s[i+20] ^= t;
    }

    /* Rho and Pi */
    t = s[1];
    for (i = 0; i < 24; i++) {
      int j = PI[i];
      uint64_t tmp = s[j];
      s[j] = ROTL64(t, RHO[i]);
      t = tmp;
    }

    /* Chi */
    for (i = 0; i < 25; i += 5) {
      uint64_t a0 = s[i], a1 = s[i+1], a2 = s[i+2], a3 = s[i+3], a4 = s[i+4];
      s[i]   = a0 ^ (~a1 & a2);
      s[i+1] = a1 ^ (~a2 & a3);
      s[i+2] = a2 ^ (~a3 & a4);
      s[i+3] = a3 ^ (~a4 & a0);
      s[i+4] = a4 ^ (~a0 & a1);
    }

    /* Iota */
    s[0] ^= RC[round];
  }
}

static void absorb_byte(rktcrypto_keccak_ctx_t *ctx, unsigned char b)
{
  ctx->state[ctx->pos >> 3] ^= (uint64_t)b << (8 * (ctx->pos & 7));
  ctx->pos++;
  if (ctx->pos == ctx->rate) {
    keccak_f(ctx->state);
    ctx->pos = 0;
  }
}

void rktcrypto_keccak_core_init(rktcrypto_keccak_ctx_t *ctx, intptr_t rate, unsigned char pad)
{
  int i;
  for (i = 0; i < 25; i++) ctx->state[i] = 0;
  ctx->rate = rate;
  ctx->pos = 0;
  ctx->pad = pad;
}

void rktcrypto_keccak_core_update(rktcrypto_keccak_ctx_t *ctx,
                                  const unsigned char *data, intptr_t len)
{
  intptr_t i;
  for (i = 0; i < len; i++)
    absorb_byte(ctx, data[i]);
}

void rktcrypto_keccak_core_final(rktcrypto_keccak_ctx_t *ctx,
                                 unsigned char *out, intptr_t out_len)
{
  intptr_t i;

  /* Pad: domain byte at pos, 0x80 at the last rate byte (may coincide). */
  ctx->state[ctx->pos >> 3] ^= (uint64_t)ctx->pad << (8 * (ctx->pos & 7));
  ctx->state[(ctx->rate - 1) >> 3] ^= (uint64_t)0x80 << (8 * ((ctx->rate - 1) & 7));
  keccak_f(ctx->state);
  ctx->pos = 0;

  /* Squeeze */
  for (i = 0; i < out_len; i++) {
    if (ctx->pos == ctx->rate) {
      keccak_f(ctx->state);
      ctx->pos = 0;
    }
    out[i] = (unsigned char)(ctx->state[ctx->pos >> 3] >> (8 * (ctx->pos & 7)));
    ctx->pos++;
  }
}
