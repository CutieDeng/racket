/* SipHash-2-4 and SipHash-1-3, per the SipHash specification.

   From-scratch public-domain-style implementation, validated by the
   reference test vectors. SipHash is a keyed PRF used for short-input
   authentication and, notably, for hash-flooding-resistant hash
   tables. 64-bit output. */

#include "rktcrypto.h"

#define ROTL64(x, b) (((x) << (b)) | ((x) >> (64 - (b))))

#define SIPROUND(v0, v1, v2, v3)                 \
  do {                                           \
    v0 += v1; v1 = ROTL64(v1, 13); v1 ^= v0; v0 = ROTL64(v0, 32); \
    v2 += v3; v3 = ROTL64(v3, 16); v3 ^= v2;     \
    v0 += v3; v3 = ROTL64(v3, 21); v3 ^= v0;     \
    v2 += v1; v1 = ROTL64(v1, 17); v1 ^= v2; v2 = ROTL64(v2, 32); \
  } while (0)

static uint64_t load64_le(const unsigned char *p)
{
  uint64_t r = 0;
  int i;
  for (i = 0; i < 8; i++) r |= (uint64_t)p[i] << (8 * i);
  return r;
}

/* Computes SipHash-`crounds`-`drounds` of data[start..end) under the
   16-byte key, writing the 8-byte little-endian result to
   out[out_start..out_start+8). Returns 1, or 0 on a bad range. */
int rktcrypto_siphash(const unsigned char *key, intptr_t key_len,
                      int crounds, int drounds,
                      const unsigned char *data, intptr_t start, intptr_t end,
                      unsigned char *out, intptr_t out_start)
{
  uint64_t k0, k1, v0, v1, v2, v3, b;
  intptr_t len = end - start;
  const unsigned char *p, *pend;
  unsigned char *o = out + out_start;
  int i;

  if (key_len != 16) return 0;
  if (len < 0) return 0;

  k0 = load64_le(key); k1 = load64_le(key + 8);
  v0 = k0 ^ 0x736f6d6570736575ULL;
  v1 = k1 ^ 0x646f72616e646f6dULL;
  v2 = k0 ^ 0x6c7967656e657261ULL;
  v3 = k1 ^ 0x7465646279746573ULL;
  p = data + start;
  pend = p + (len & ~(intptr_t)7);

  for (; p != pend; p += 8) {
    uint64_t m = load64_le(p);
    v3 ^= m;
    for (i = 0; i < crounds; i++) SIPROUND(v0, v1, v2, v3);
    v0 ^= m;
  }

  b = (uint64_t)(len & 0xff) << 56;
  {
    intptr_t left = len & 7, j;
    for (j = 0; j < left; j++) b |= (uint64_t)p[j] << (8 * j);
  }
  v3 ^= b;
  for (i = 0; i < crounds; i++) SIPROUND(v0, v1, v2, v3);
  v0 ^= b;

  v2 ^= 0xff;
  for (i = 0; i < drounds; i++) SIPROUND(v0, v1, v2, v3);

  {
    uint64_t h = v0 ^ v1 ^ v2 ^ v3;
    for (i = 0; i < 8; i++) o[i] = (unsigned char)(h >> (8 * i));
  }
  return 1;
}
