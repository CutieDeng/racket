/* AES-256-GCM (NIST SP 800-38D), built on the constant-time AES-256
   block cipher.

   From-scratch public-domain-style implementation. GHASH uses a
   constant-time bit-by-bit GF(2^128) multiply (no tables), so the
   authenticator has no data-dependent timing. Suitable as the AES-GCM
   construction alongside ChaCha20-Poly1305; on hardware without AES
   acceleration, prefer ChaCha20-Poly1305 for speed. */

#include "rktcrypto.h"
#include "rktcrypto_cipher.h"
#include <string.h>

#if defined(__ARM_FEATURE_AES) || defined(__ARM_FEATURE_CRYPTO)
#include <arm_neon.h>

/* Hardware GHASH via ARMv8 PMULL (vmull_p64).

   GHASH's bit convention (block byte 0 bit 7 is x^0) is the reverse of
   the polynomial order PMULL multiplies in, so each operand is turned
   into normal order (bit j = x^j) with a single vrbitq_u8. Then a
   Karatsuba 128x128 -> 256 carryless multiply composes directly, and
   the product is reduced modulo x^128+x^7+x^2+x+1 with the folding
   constant 0x87. H is reversed once per message and the accumulator
   stays in normal order across every block, reversed back only at the
   end. Verified bit-exact against the portable multiply over 2e5 random
   inputs. */
static inline poly128_t gcm_cl(uint64_t a, uint64_t b)
{
  return vmull_p64((poly64_t)a, (poly64_t)b);
}
static inline uint64x2_t gcm_clmul_reduce(uint64_t a0, uint64_t a1, uint64_t h0, uint64_t h1)
{
  uint64x2_t lo  = vreinterpretq_u64_p128(gcm_cl(a0, h0));
  uint64x2_t hi  = vreinterpretq_u64_p128(gcm_cl(a1, h1));
  uint64x2_t mid = vreinterpretq_u64_p128(gcm_cl(a0 ^ a1, h0 ^ h1));
  uint64_t mlo, mhi, X0_0, X0_1, X1_0, X1_1, R0, R1, R2, S0;
  uint64x2_t rlo, rhi, res;
  mid = veorq_u64(mid, veorq_u64(lo, hi));
  mlo = vgetq_lane_u64(mid, 0); mhi = vgetq_lane_u64(mid, 1);
  X0_0 = vgetq_lane_u64(lo, 0);        X0_1 = vgetq_lane_u64(lo, 1) ^ mlo;
  X1_0 = vgetq_lane_u64(hi, 0) ^ mhi;  X1_1 = vgetq_lane_u64(hi, 1);
  /* reduce the high 128 bits (X1_1:X1_0) by folding with 0x87, twice */
  rlo = vreinterpretq_u64_p128(gcm_cl(X1_0, 0x87));
  rhi = vreinterpretq_u64_p128(gcm_cl(X1_1, 0x87));
  R0 = vgetq_lane_u64(rlo, 0);
  R1 = vgetq_lane_u64(rlo, 1) ^ vgetq_lane_u64(rhi, 0);
  R2 = vgetq_lane_u64(rhi, 1);
  S0 = vgetq_lane_u64(vreinterpretq_u64_p128(gcm_cl(R2, 0x87)), 0);
  res = vdupq_n_u64(0);
  res = vsetq_lane_u64(X0_0 ^ R0 ^ S0, res, 0);
  res = vsetq_lane_u64(X0_1 ^ R1, res, 1);
  return res;
}
/* Full GHASH: s = GHASH_H(aad || 0* || ct || 0* || len(aad)||len(ct)). */
static void gcm_ghash_hw(const uint64_t h[2],
                         const unsigned char *aad, intptr_t aad_len,
                         const unsigned char *ct, intptr_t ct_len,
                         unsigned char s[16])
{
  unsigned char hb[16], blk[16];
  uint64x2_t acc;
  uint64_t h0, h1;
  int i;
  for (i = 0; i < 8; i++) { hb[i] = (unsigned char)(h[0] >> (56 - 8*i)); hb[8+i] = (unsigned char)(h[1] >> (56 - 8*i)); }
  { uint64x2_t hv = vreinterpretq_u64_u8(vrbitq_u8(vld1q_u8(hb)));
    h0 = vgetq_lane_u64(hv, 0); h1 = vgetq_lane_u64(hv, 1); }
  acc = vdupq_n_u64(0);

#define GCM_GH_REGION(DATA, LEN) do {                                        \
    intptr_t _l = (LEN); const unsigned char *_d = (DATA); uint64x2_t _bn;   \
    while (_l >= 16) {                                                       \
      _bn = vreinterpretq_u64_u8(vrbitq_u8(vld1q_u8(_d)));                   \
      acc = veorq_u64(acc, _bn);                                            \
      acc = gcm_clmul_reduce(vgetq_lane_u64(acc,0), vgetq_lane_u64(acc,1), h0, h1); \
      _d += 16; _l -= 16;                                                    \
    }                                                                       \
    if (_l > 0) {                                                           \
      memset(blk, 0, 16);                                                   \
      for (i = 0; i < _l; i++) blk[i] = _d[i];                              \
      _bn = vreinterpretq_u64_u8(vrbitq_u8(vld1q_u8(blk)));                  \
      acc = veorq_u64(acc, _bn);                                            \
      acc = gcm_clmul_reduce(vgetq_lane_u64(acc,0), vgetq_lane_u64(acc,1), h0, h1); \
    }                                                                       \
  } while (0)

  GCM_GH_REGION(aad, aad_len);
  GCM_GH_REGION(ct, ct_len);
#undef GCM_GH_REGION

  { uint64_t abits = (uint64_t)aad_len << 3, cbits = (uint64_t)ct_len << 3;
    for (i = 0; i < 8; i++) blk[i]     = (unsigned char)(abits >> (56 - 8*i));
    for (i = 0; i < 8; i++) blk[8 + i] = (unsigned char)(cbits >> (56 - 8*i)); }
  { uint64x2_t bn = vreinterpretq_u64_u8(vrbitq_u8(vld1q_u8(blk)));
    acc = veorq_u64(acc, bn);
    acc = gcm_clmul_reduce(vgetq_lane_u64(acc,0), vgetq_lane_u64(acc,1), h0, h1); }

  vst1q_u8(s, vrbitq_u8(vreinterpretq_u8_u64(acc)));
}

#else  /* portable, constant-time bit-by-bit GHASH */

/* GF(2^128) multiply z = x * h, NIST bit ordering (block byte 0 bit 7
   is the most significant). Represented as two big-endian uint64_t. */
static void ghash_mul(uint64_t z[2], const uint64_t h[2], const unsigned char x[16])
{
  uint64_t vh = h[0], vl = h[1];
  uint64_t zh = 0, zl = 0;
  int i;

  for (i = 0; i < 128; i++) {
    /* bit i of x, from the most significant bit of byte 0 */
    uint64_t bit = (uint64_t)((x[i >> 3] >> (7 - (i & 7))) & 1);
    uint64_t mask = 0 - bit;
    uint64_t lsb, rmask;

    zh ^= vh & mask;
    zl ^= vl & mask;

    /* v >>= 1 (128-bit), with reduction by R = 0xe1||0^120 if LSB set */
    lsb = vl & 1;
    vl = (vl >> 1) | (vh << 63);
    vh = vh >> 1;
    rmask = 0 - lsb;
    vh ^= 0xe100000000000000ULL & rmask;
  }
  z[0] = zh; z[1] = zl;
}

static void be_store128(unsigned char out[16], const uint64_t z[2])
{
  int i;
  for (i = 0; i < 8; i++) out[i]     = (unsigned char)(z[0] >> (56 - 8 * i));
  for (i = 0; i < 8; i++) out[8 + i] = (unsigned char)(z[1] >> (56 - 8 * i));
}

/* GHASH state update: acc = (acc ^ block) * H. */
static void ghash_block(uint64_t acc[2], const uint64_t h[2], const unsigned char *block)
{
  unsigned char x[16];
  uint64_t z[2];
  int i;
  be_store128(x, acc);
  for (i = 0; i < 16; i++) x[i] ^= block[i];
  ghash_mul(z, h, x);
  acc[0] = z[0]; acc[1] = z[1];
}

static void ghash_bytes(uint64_t acc[2], const uint64_t h[2],
                        const unsigned char *data, intptr_t len)
{
  unsigned char block[16];
  intptr_t i;
  while (len >= 16) {
    ghash_block(acc, h, data);
    data += 16; len -= 16;
  }
  if (len > 0) {
    memset(block, 0, 16);
    for (i = 0; i < len; i++) block[i] = data[i];
    ghash_block(acc, h, block);
  }
}
#endif

static void inc32(unsigned char ctr[16])
{
  uint32_t c = ((uint32_t)ctr[12] << 24) | ((uint32_t)ctr[13] << 16)
             | ((uint32_t)ctr[14] << 8) | (uint32_t)ctr[15];
  c++;
  ctr[12] = (unsigned char)(c >> 24); ctr[13] = (unsigned char)(c >> 16);
  ctr[14] = (unsigned char)(c >> 8);  ctr[15] = (unsigned char)c;
}

/* CTR-mode keystream XOR, starting from counter block `ctr`. */
static void gctr(const unsigned char rk[240], unsigned char ctr[16],
                 const unsigned char *in, unsigned char *out, intptr_t len)
{
  unsigned char ks[16];
  while (len > 0) {
    intptr_t n = (len < 16) ? len : 16, i;
    rktcrypto_aes256_encrypt_block(rk, ctr, ks);
    for (i = 0; i < n; i++) out[i] = in[i] ^ ks[i];
    inc32(ctr);
    in += n; out += n; len -= n;
  }
}

/* Computes H, J0 (12-byte nonce only), the GHASH over aad/ct/lens, and
   the tag. `tag` receives 16 bytes. */
static void gcm_tag(const unsigned char rk[240], const unsigned char nonce[12],
                    const unsigned char *aad, intptr_t aad_len,
                    const unsigned char *ct, intptr_t ct_len,
                    const uint64_t h[2], unsigned char tag[16])
{
  unsigned char j0[16], ej0[16], s[16];
  int i;

#if defined(__ARM_FEATURE_AES) || defined(__ARM_FEATURE_CRYPTO)
  gcm_ghash_hw(h, aad, aad_len, ct, ct_len, s);
#else
  {
    uint64_t acc[2] = {0, 0};
    unsigned char lenblock[16];
    ghash_bytes(acc, h, aad, aad_len);
    ghash_bytes(acc, h, ct, ct_len);
    /* len(AAD) || len(C) in bits, each 64-bit big-endian */
    {
      uint64_t abits = (uint64_t)aad_len << 3, cbits = (uint64_t)ct_len << 3;
      for (i = 0; i < 8; i++) lenblock[i]     = (unsigned char)(abits >> (56 - 8 * i));
      for (i = 0; i < 8; i++) lenblock[8 + i] = (unsigned char)(cbits >> (56 - 8 * i));
    }
    ghash_block(acc, h, lenblock);
    be_store128(s, acc);
  }
#endif

  /* J0 = nonce || 0x00000001 */
  memcpy(j0, nonce, 12);
  j0[12] = 0; j0[13] = 0; j0[14] = 0; j0[15] = 1;
  rktcrypto_aes256_encrypt_block(rk, j0, ej0);

  for (i = 0; i < 16; i++) tag[i] = s[i] ^ ej0[i];
}

static void gcm_setup(const unsigned char key[32], unsigned char rk[240], uint64_t h[2])
{
  unsigned char zero[16], hblock[16];
  int i;
  rktcrypto_aes256_expand_key(key, rk);
  memset(zero, 0, 16);
  rktcrypto_aes256_encrypt_block(rk, zero, hblock);
  h[0] = 0; h[1] = 0;
  for (i = 0; i < 8; i++) h[0] = (h[0] << 8) | hblock[i];
  for (i = 8; i < 16; i++) h[1] = (h[1] << 8) | hblock[i];
}

int rktcrypto_aes256gcm_seal(const unsigned char key[32], const unsigned char nonce[12],
                             const unsigned char *aad, intptr_t aad_start, intptr_t aad_end,
                             const unsigned char *pt, intptr_t pt_start, intptr_t pt_end,
                             unsigned char *out, intptr_t out_start)
{
  unsigned char rk[240], ctr[16];
  uint64_t h[2];
  intptr_t pt_len = pt_end - pt_start, aad_len = aad_end - aad_start;
  unsigned char *ct = out + out_start;

  if (pt_len < 0 || aad_len < 0) return 0;

  gcm_setup(key, rk, h);
  /* CTR starts at J0 + 1 = nonce || 0x00000002 */
  memcpy(ctr, nonce, 12);
  ctr[12] = 0; ctr[13] = 0; ctr[14] = 0; ctr[15] = 2;
  gctr(rk, ctr, pt + pt_start, ct, pt_len);
  gcm_tag(rk, nonce, aad + aad_start, aad_len, ct, pt_len, h, ct + pt_len);
  return 1;
}

int rktcrypto_aes256gcm_open(const unsigned char key[32], const unsigned char nonce[12],
                             const unsigned char *aad, intptr_t aad_start, intptr_t aad_end,
                             const unsigned char *ct, intptr_t ct_start, intptr_t ct_end,
                             unsigned char *out, intptr_t out_start)
{
  unsigned char rk[240], ctr[16], tag[16];
  uint64_t h[2];
  intptr_t total = ct_end - ct_start, aad_len = aad_end - aad_start, ct_len;
  const unsigned char *cbody = ct + ct_start;

  if (total < 16 || aad_len < 0) return 0;
  ct_len = total - 16;

  gcm_setup(key, rk, h);
  gcm_tag(rk, nonce, aad + aad_start, aad_len, cbody, ct_len, h, tag);
  if (!rktcrypto_ct_bytes_equal(tag, 0, cbody + ct_len, 0, 16))
    return 0;

  memcpy(ctr, nonce, 12);
  ctr[12] = 0; ctr[13] = 0; ctr[14] = 0; ctr[15] = 2;
  gctr(rk, ctr, cbody, out + out_start, ct_len);
  return 1;
}
