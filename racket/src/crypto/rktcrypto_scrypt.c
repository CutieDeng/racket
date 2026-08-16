/* scrypt (RFC 7914) and a C PBKDF2-HMAC (RFC 8018).

   scrypt is the memory-hard password KDF: PBKDF2-HMAC-SHA256 spreads the
   password over a large buffer, ROMix makes it sequentially memory-hard
   via the Salsa20/8 core, and a final PBKDF2 pass extracts the key.

   PBKDF2 is exposed generically (over any built-in digest) so the Racket
   KDF layer can replace its interpreted inner loop with this C one. From
   scratch, no external code. */

#include "rktcrypto.h"
#include <string.h>
#include <stdint.h>
#include <stdlib.h>

/* ---- HMAC over any fixed-size built-in digest (incremental) ---- */

typedef struct {
  int alg;
  intptr_t bs, ds;
  unsigned char octx[RKTCRYPTO_DIGEST_CTX_MAXSIZE];  /* primed with opad key */
  unsigned char ictx[RKTCRYPTO_DIGEST_CTX_MAXSIZE];  /* running inner digest */
  intptr_t ctxlen;
} hmac_ctx;

static int hmac_init(hmac_ctx *h, int alg, const unsigned char *key, intptr_t klen)
{
  unsigned char k0[168], ip[168], op[168], kh[64];
  intptr_t i;
  h->alg = alg;
  h->bs = rktcrypto_digest_block_size(alg);
  h->ds = rktcrypto_digest_size(alg);
  h->ctxlen = rktcrypto_digest_ctx_size(alg);
  if (h->bs <= 0 || h->ds <= 0 || h->bs > (intptr_t)sizeof k0) return 0;
  if (klen > h->bs) {
    if (!rktcrypto_digest_oneshot(alg, key, 0, klen, kh, 0, h->ds)) return 0;
    key = kh; klen = h->ds;
  }
  memset(k0, 0, h->bs);
  memcpy(k0, key, klen);
  for (i = 0; i < h->bs; i++) { ip[i] = k0[i] ^ 0x36; op[i] = k0[i] ^ 0x5c; }
  if (!rktcrypto_digest_init(alg, h->ictx, h->ctxlen, h->ds)) return 0;
  if (!rktcrypto_digest_update(alg, h->ictx, h->ctxlen, ip, 0, h->bs)) return 0;
  if (!rktcrypto_digest_init(alg, h->octx, h->ctxlen, h->ds)) return 0;
  if (!rktcrypto_digest_update(alg, h->octx, h->ctxlen, op, 0, h->bs)) return 0;
  return 1;
}

static void hmac_update(hmac_ctx *h, const unsigned char *d, intptr_t len)
{
  rktcrypto_digest_update(h->alg, h->ictx, h->ctxlen, d, 0, len);
}

/* Finalizes into out (h->ds bytes) and re-primes both halves so the ctx
   can be reused for the next PBKDF2 block (same key). */
static void hmac_final_reset(hmac_ctx *h, const unsigned char *ip_key_state,
                             const unsigned char *op_key_state, unsigned char *out)
{
  unsigned char inner[64];
  rktcrypto_digest_final(h->alg, h->ictx, h->ctxlen, inner, 0, h->ds);
  memcpy(h->octx, op_key_state, h->ctxlen);      /* restore opad-primed */
  rktcrypto_digest_update(h->alg, h->octx, h->ctxlen, inner, 0, h->ds);
  rktcrypto_digest_final(h->alg, h->octx, h->ctxlen, out, 0, h->ds);
  memcpy(h->ictx, ip_key_state, h->ctxlen);      /* restore ipad-primed */
  memcpy(h->octx, op_key_state, h->ctxlen);
}

/* ---- PBKDF2-HMAC (RFC 8018) ---- */

int rktcrypto_pbkdf2(int alg, const unsigned char *pw, intptr_t pl,
                     const unsigned char *salt, intptr_t sl,
                     uint32_t iterations, unsigned char *dk, intptr_t dklen)
{
  hmac_ctx h;
  unsigned char ip_state[RKTCRYPTO_DIGEST_CTX_MAXSIZE];
  unsigned char op_state[RKTCRYPTO_DIGEST_CTX_MAXSIZE];
  unsigned char u[64], t[64], be[4];
  intptr_t hlen, blocks, off, n;
  uint32_t b, it;
  int j;

  if (iterations == 0 || dklen < 0) return 0;
  if (!hmac_init(&h, alg, pw, pl)) return 0;
  hlen = h.ds;
  memcpy(ip_state, h.ictx, h.ctxlen);
  memcpy(op_state, h.octx, h.ctxlen);
  blocks = (dklen + hlen - 1) / hlen;

  for (b = 1; (intptr_t)b <= blocks; b++) {
    be[0]=(unsigned char)(b>>24); be[1]=(unsigned char)(b>>16); be[2]=(unsigned char)(b>>8); be[3]=(unsigned char)b;
    hmac_update(&h, salt, sl);
    hmac_update(&h, be, 4);
    hmac_final_reset(&h, ip_state, op_state, u);
    memcpy(t, u, hlen);
    for (it = 1; it < iterations; it++) {
      hmac_update(&h, u, hlen);
      hmac_final_reset(&h, ip_state, op_state, u);
      for (j = 0; j < hlen; j++) t[j] ^= u[j];
    }
    off = (intptr_t)(b - 1) * hlen; n = dklen - off; if (n > hlen) n = hlen;
    memcpy(dk + off, t, n);
  }
  return 1;
}

/* ---- Salsa20/8 core + BlockMix + ROMix ---- */

static uint32_t rotl32(uint32_t x, int c) { return (x << c) | (x >> (32 - c)); }

static void salsa20_8(uint32_t out[16], const uint32_t in[16])
{
  uint32_t x[16];
  int i, r;
  for (i = 0; i < 16; i++) x[i] = in[i];
  for (r = 0; r < 4; r++) {
    x[ 4]^=rotl32(x[ 0]+x[12], 7); x[ 8]^=rotl32(x[ 4]+x[ 0], 9); x[12]^=rotl32(x[ 8]+x[ 4],13); x[ 0]^=rotl32(x[12]+x[ 8],18);
    x[ 9]^=rotl32(x[ 5]+x[ 1], 7); x[13]^=rotl32(x[ 9]+x[ 5], 9); x[ 1]^=rotl32(x[13]+x[ 9],13); x[ 5]^=rotl32(x[ 1]+x[13],18);
    x[14]^=rotl32(x[10]+x[ 6], 7); x[ 2]^=rotl32(x[14]+x[10], 9); x[ 6]^=rotl32(x[ 2]+x[14],13); x[10]^=rotl32(x[ 6]+x[ 2],18);
    x[ 3]^=rotl32(x[15]+x[11], 7); x[ 7]^=rotl32(x[ 3]+x[15], 9); x[11]^=rotl32(x[ 7]+x[ 3],13); x[15]^=rotl32(x[11]+x[ 7],18);
    x[ 1]^=rotl32(x[ 0]+x[ 3], 7); x[ 2]^=rotl32(x[ 1]+x[ 0], 9); x[ 3]^=rotl32(x[ 2]+x[ 1],13); x[ 0]^=rotl32(x[ 3]+x[ 2],18);
    x[ 6]^=rotl32(x[ 5]+x[ 4], 7); x[ 7]^=rotl32(x[ 6]+x[ 5], 9); x[ 4]^=rotl32(x[ 7]+x[ 6],13); x[ 5]^=rotl32(x[ 4]+x[ 7],18);
    x[11]^=rotl32(x[10]+x[ 9], 7); x[ 8]^=rotl32(x[11]+x[10], 9); x[ 9]^=rotl32(x[ 8]+x[11],13); x[10]^=rotl32(x[ 9]+x[ 8],18);
    x[12]^=rotl32(x[15]+x[14], 7); x[13]^=rotl32(x[12]+x[15], 9); x[14]^=rotl32(x[13]+x[12],13); x[15]^=rotl32(x[14]+x[13],18);
  }
  for (i = 0; i < 16; i++) out[i] = x[i] + in[i];
}

/* B is 2r blocks of 16 words; Y receives the shuffled BlockMix output. */
static void blockmix(const uint32_t *B, uint32_t *Y, uint32_t r)
{
  uint32_t X[16], T[16];
  uint32_t i;
  int j;
  memcpy(X, B + 16 * (2 * r - 1), 64);
  for (i = 0; i < 2 * r; i++) {
    for (j = 0; j < 16; j++) T[j] = X[j] ^ B[16 * i + j];
    salsa20_8(X, T);
    memcpy(Y + 16 * ((i % 2) * r + (i / 2)), X, 64);
  }
}

static int romix(uint32_t *B, uint32_t r, uint32_t N)
{
  uint32_t blk = 32 * r;                 /* words per B (2r * 16) */
  uint32_t *V = malloc((size_t)N * blk * 4);
  uint32_t *X = malloc(blk * 4), *Y = malloc(blk * 4);
  uint32_t i; uint32_t k;
  if (!V || !X || !Y) { free(V); free(X); free(Y); return 0; }
  memcpy(X, B, blk * 4);
  for (i = 0; i < N; i++) { memcpy(V + (size_t)i * blk, X, blk * 4); blockmix(X, Y, r); memcpy(X, Y, blk * 4); }
  for (i = 0; i < N; i++) {
    uint32_t j = X[16 * (2 * r - 1)] & (N - 1);   /* integerify mod N (N a power of 2) */
    for (k = 0; k < blk; k++) X[k] ^= V[(size_t)j * blk + k];
    blockmix(X, Y, r); memcpy(X, Y, blk * 4);
  }
  memcpy(B, X, blk * 4);
  free(V); free(X); free(Y);
  return 1;
}

int rktcrypto_scrypt(const unsigned char *pw, intptr_t pl,
                     const unsigned char *salt, intptr_t sl,
                     uint32_t N, uint32_t r, uint32_t p,
                     unsigned char *dk, intptr_t dklen)
{
  intptr_t Blen;
  unsigned char *B;
  uint32_t i;

  if (N < 2 || (N & (N - 1)) != 0) return 0;   /* N must be a power of two > 1 */
  if (r == 0 || p == 0) return 0;
  Blen = (intptr_t)128 * r * p;
  B = malloc(Blen);
  if (!B) return 0;

  if (!rktcrypto_pbkdf2(RKTCRYPTO_SHA256, pw, pl, salt, sl, 1, B, Blen)) { free(B); return 0; }
  for (i = 0; i < p; i++) {
    if (!romix((uint32_t *)(B + (size_t)128 * r * i), r, N)) { free(B); return 0; }
  }
  if (!rktcrypto_pbkdf2(RKTCRYPTO_SHA256, pw, pl, B, Blen, 1, dk, dklen)) { free(B); return 0; }
  free(B);
  return 1;
}
