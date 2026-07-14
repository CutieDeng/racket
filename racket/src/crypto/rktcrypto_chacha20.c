/* ChaCha20 stream cipher, per RFC 8439.

   From-scratch public-domain-style implementation, validated by the
   RFC 8439 test vectors. Software ChaCha20 is naturally constant-time
   (no data-dependent branches or table lookups). SIMD acceleration
   may be added later behind dispatch. */

#include "rktcrypto_cipher.h"
#include <string.h>

#define ROTL32(x, n) (((x) << (n)) | ((x) >> (32 - (n))))

#define QR(a, b, c, d)               \
  do {                               \
    a += b; d ^= a; d = ROTL32(d, 16); \
    c += d; b ^= c; b = ROTL32(b, 12); \
    a += b; d ^= a; d = ROTL32(d, 8);  \
    c += d; b ^= c; b = ROTL32(b, 7);  \
  } while (0)

static uint32_t load32_le(const unsigned char *p)
{
  return ((uint32_t)p[0]) | ((uint32_t)p[1] << 8)
       | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static void store32_le(unsigned char *p, uint32_t v)
{
  p[0] = (unsigned char)v;         p[1] = (unsigned char)(v >> 8);
  p[2] = (unsigned char)(v >> 16); p[3] = (unsigned char)(v >> 24);
}

static void chacha20_core(const uint32_t in[16], unsigned char out[64])
{
  uint32_t x[16];
  int i;
  memcpy(x, in, sizeof(x));
  for (i = 0; i < 10; i++) {
    QR(x[0], x[4], x[ 8], x[12]);
    QR(x[1], x[5], x[ 9], x[13]);
    QR(x[2], x[6], x[10], x[14]);
    QR(x[3], x[7], x[11], x[15]);
    QR(x[0], x[5], x[10], x[15]);
    QR(x[1], x[6], x[11], x[12]);
    QR(x[2], x[7], x[ 8], x[13]);
    QR(x[3], x[4], x[ 9], x[14]);
  }
  for (i = 0; i < 16; i++)
    store32_le(out + 4 * i, x[i] + in[i]);
}

static void chacha20_setup(uint32_t state[16], const unsigned char key[32],
                           const unsigned char nonce[12], uint32_t counter)
{
  int i;
  state[0] = 0x61707865; state[1] = 0x3320646e;
  state[2] = 0x79622d32; state[3] = 0x6b206574;
  for (i = 0; i < 8; i++) state[4 + i] = load32_le(key + 4 * i);
  state[12] = counter;
  state[13] = load32_le(nonce + 0);
  state[14] = load32_le(nonce + 4);
  state[15] = load32_le(nonce + 8);
}

void rktcrypto_chacha20_block(const unsigned char key[32],
                              const unsigned char nonce[12],
                              uint32_t counter,
                              unsigned char out[64])
{
  uint32_t state[16];
  chacha20_setup(state, key, nonce, counter);
  chacha20_core(state, out);
}

void rktcrypto_hchacha20(const unsigned char key[32],
                         const unsigned char nonce16[16],
                         unsigned char subkey[32])
{
  uint32_t x[16];
  int i;
  x[0] = 0x61707865; x[1] = 0x3320646e;
  x[2] = 0x79622d32; x[3] = 0x6b206574;
  for (i = 0; i < 8; i++) x[4 + i] = load32_le(key + 4 * i);
  for (i = 0; i < 4; i++) x[12 + i] = load32_le(nonce16 + 4 * i);

  for (i = 0; i < 10; i++) {
    QR(x[0], x[4], x[ 8], x[12]);
    QR(x[1], x[5], x[ 9], x[13]);
    QR(x[2], x[6], x[10], x[14]);
    QR(x[3], x[7], x[11], x[15]);
    QR(x[0], x[5], x[10], x[15]);
    QR(x[1], x[6], x[11], x[12]);
    QR(x[2], x[7], x[ 8], x[13]);
    QR(x[3], x[4], x[ 9], x[14]);
  }

  /* Output words 0..3 and 12..15, without the final addition. */
  for (i = 0; i < 4; i++) store32_le(subkey + 4 * i, x[i]);
  for (i = 0; i < 4; i++) store32_le(subkey + 16 + 4 * i, x[12 + i]);
}

void rktcrypto_chacha20_xor(const unsigned char key[32],
                            const unsigned char nonce[12],
                            uint32_t counter,
                            const unsigned char *in, unsigned char *out,
                            intptr_t len)
{
  uint32_t state[16];
  unsigned char block[64];
  chacha20_setup(state, key, nonce, counter);

  while (len > 0) {
    intptr_t n = (len < 64) ? len : 64;
    intptr_t i;
    chacha20_core(state, block);
    for (i = 0; i < n; i++)
      out[i] = in[i] ^ block[i];
    in += n;
    out += n;
    len -= n;
    state[12]++;   /* next block counter (wraps at 2^32 per spec) */
  }
}
