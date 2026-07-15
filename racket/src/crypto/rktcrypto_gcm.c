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
  uint64_t acc[2] = {0, 0};
  unsigned char j0[16], ej0[16], lenblock[16];
  int i;

  ghash_bytes(acc, h, aad, aad_len);
  ghash_bytes(acc, h, ct, ct_len);

  /* len(AAD) || len(C) in bits, each 64-bit big-endian */
  {
    uint64_t abits = (uint64_t)aad_len << 3, cbits = (uint64_t)ct_len << 3;
    for (i = 0; i < 8; i++) lenblock[i]     = (unsigned char)(abits >> (56 - 8 * i));
    for (i = 0; i < 8; i++) lenblock[8 + i] = (unsigned char)(cbits >> (56 - 8 * i));
  }
  ghash_block(acc, h, lenblock);

  /* J0 = nonce || 0x00000001 */
  memcpy(j0, nonce, 12);
  j0[12] = 0; j0[13] = 0; j0[14] = 0; j0[15] = 1;
  rktcrypto_aes256_encrypt_block(rk, j0, ej0);

  be_store128(tag, acc);
  for (i = 0; i < 16; i++) tag[i] ^= ej0[i];
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
