/* ChaCha20 stream cipher, per RFC 8439.

   From-scratch public-domain-style implementation, validated by the
   RFC 8439 test vectors. Software ChaCha20 is naturally constant-time
   (no data-dependent branches or table lookups). SIMD acceleration
   may be added later behind dispatch. */

#include "rktcrypto_cipher.h"
#include <string.h>
#if defined(__aarch64__)
# include <arm_neon.h>
#endif

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

#if defined(__aarch64__)
/* Four ChaCha20 blocks in parallel (vertical SIMD: each 32-bit state
   word held across the four counter lanes), XORed straight into the
   output. Bit-exact with the scalar core. */
/* Fewer instructions than shift-or: rot16 is a 16-bit element reverse,
   rot8 a byte-permute, rot12/rot7 a shift-right-insert. */
static const unsigned char CC_ROT8IDX[16] =
  { 3,0,1,2, 7,4,5,6, 11,8,9,10, 15,12,13,14 };
# define CC_R16(x) vreinterpretq_u32_u16(vrev32q_u16(vreinterpretq_u16_u32(x)))
# define CC_R12(x) vsriq_n_u32(vshlq_n_u32(x, 12), x, 20)
# define CC_R8(x)  vreinterpretq_u32_u8(vqtbl1q_u8(vreinterpretq_u8_u32(x), idx8))
# define CC_R7(x)  vsriq_n_u32(vshlq_n_u32(x, 7), x, 25)
# define CC_QR4(a, b, c, d) do {                                            \
    a = vaddq_u32(a, b); d = veorq_u32(d, a); d = CC_R16(d);                \
    c = vaddq_u32(c, d); b = veorq_u32(b, c); b = CC_R12(b);                \
    a = vaddq_u32(a, b); d = veorq_u32(d, a); d = CC_R8(d);                 \
    c = vaddq_u32(c, d); b = veorq_u32(b, c); b = CC_R7(b);                 \
  } while (0)
/* Transpose one 4-block group (state words held vertically across 4 counter
   lanes) back to serial block order, XOR the input at byte offset `base`,
   and store. */
static inline void cc_store4(const uint32x4_t v[16], const unsigned char *in,
                             unsigned char *out, int base)
{
  int g;
  for (g = 0; g < 4; g++) {
    uint32x4x2_t t0 = vtrnq_u32(v[4*g], v[4*g+1]);
    uint32x4x2_t t1 = vtrnq_u32(v[4*g+2], v[4*g+3]);
    uint32x4_t r0 = vcombine_u32(vget_low_u32(t0.val[0]), vget_low_u32(t1.val[0]));
    uint32x4_t r1 = vcombine_u32(vget_low_u32(t0.val[1]), vget_low_u32(t1.val[1]));
    uint32x4_t r2 = vcombine_u32(vget_high_u32(t0.val[0]), vget_high_u32(t1.val[0]));
    uint32x4_t r3 = vcombine_u32(vget_high_u32(t0.val[1]), vget_high_u32(t1.val[1]));
    vst1q_u8(out + base +   0 + g*16, veorq_u8(vld1q_u8(in + base +   0 + g*16), vreinterpretq_u8_u32(r0)));
    vst1q_u8(out + base +  64 + g*16, veorq_u8(vld1q_u8(in + base +  64 + g*16), vreinterpretq_u8_u32(r1)));
    vst1q_u8(out + base + 128 + g*16, veorq_u8(vld1q_u8(in + base + 128 + g*16), vreinterpretq_u8_u32(r2)));
    vst1q_u8(out + base + 192 + g*16, veorq_u8(vld1q_u8(in + base + 192 + g*16), vreinterpretq_u8_u32(r3)));
  }
}
static void chacha20_4block_xor(const uint32_t s[16], uint32_t ctr,
                                const unsigned char *in, unsigned char *out)
{
  uint8x16_t idx8 = vld1q_u8(CC_ROT8IDX);
  uint32x4_t v[16], o[16];
  uint32x4_t ctrs = vsetq_lane_u32(ctr, vdupq_n_u32(0), 0);
  int i, r;
  ctrs = vsetq_lane_u32(ctr + 1, ctrs, 1);
  ctrs = vsetq_lane_u32(ctr + 2, ctrs, 2);
  ctrs = vsetq_lane_u32(ctr + 3, ctrs, 3);
  for (i = 0; i < 16; i++) v[i] = vdupq_n_u32(s[i]);
  v[12] = ctrs;
  for (i = 0; i < 16; i++) o[i] = v[i];
  for (r = 0; r < 10; r++) {
    CC_QR4(v[0], v[4], v[ 8], v[12]); CC_QR4(v[1], v[5], v[ 9], v[13]);
    CC_QR4(v[2], v[6], v[10], v[14]); CC_QR4(v[3], v[7], v[11], v[15]);
    CC_QR4(v[0], v[5], v[10], v[15]); CC_QR4(v[1], v[6], v[11], v[12]);
    CC_QR4(v[2], v[7], v[ 8], v[13]); CC_QR4(v[3], v[4], v[ 9], v[14]);
  }
  for (i = 0; i < 16; i++) v[i] = vaddq_u32(v[i], o[i]);
  cc_store4(v, in, out, 0);
}

/* Eight blocks as two independent 4-block groups (A: ctr..ctr+3,
   B: ctr+4..ctr+7). Doubling the in-flight dependency chains keeps the wide
   NEON units busier than a single 4-way group; ~1.5x its throughput.
   Bit-exact with the scalar core. */
static void chacha20_8block_xor(const uint32_t s[16], uint32_t ctr,
                                const unsigned char *in, unsigned char *out)
{
  uint8x16_t idx8 = vld1q_u8(CC_ROT8IDX);
  uint32x4_t a[16], b[16], oa[16], ob[16];
  uint32x4_t ca = vsetq_lane_u32(ctr,   vdupq_n_u32(0), 0);
  uint32x4_t cb = vsetq_lane_u32(ctr+4, vdupq_n_u32(0), 0);
  int i, r;
  ca = vsetq_lane_u32(ctr+1, ca, 1); ca = vsetq_lane_u32(ctr+2, ca, 2); ca = vsetq_lane_u32(ctr+3, ca, 3);
  cb = vsetq_lane_u32(ctr+5, cb, 1); cb = vsetq_lane_u32(ctr+6, cb, 2); cb = vsetq_lane_u32(ctr+7, cb, 3);
  for (i = 0; i < 16; i++) { a[i] = vdupq_n_u32(s[i]); b[i] = a[i]; }
  a[12] = ca; b[12] = cb;
  for (i = 0; i < 16; i++) { oa[i] = a[i]; ob[i] = b[i]; }
  for (r = 0; r < 10; r++) {
    CC_QR4(a[0],a[4],a[ 8],a[12]); CC_QR4(b[0],b[4],b[ 8],b[12]);
    CC_QR4(a[1],a[5],a[ 9],a[13]); CC_QR4(b[1],b[5],b[ 9],b[13]);
    CC_QR4(a[2],a[6],a[10],a[14]); CC_QR4(b[2],b[6],b[10],b[14]);
    CC_QR4(a[3],a[7],a[11],a[15]); CC_QR4(b[3],b[7],b[11],b[15]);
    CC_QR4(a[0],a[5],a[10],a[15]); CC_QR4(b[0],b[5],b[10],b[15]);
    CC_QR4(a[1],a[6],a[11],a[12]); CC_QR4(b[1],b[6],b[11],b[12]);
    CC_QR4(a[2],a[7],a[ 8],a[13]); CC_QR4(b[2],b[7],b[ 8],b[13]);
    CC_QR4(a[3],a[4],a[ 9],a[14]); CC_QR4(b[3],b[4],b[ 9],b[14]);
  }
  for (i = 0; i < 16; i++) { a[i] = vaddq_u32(a[i], oa[i]); b[i] = vaddq_u32(b[i], ob[i]); }
  cc_store4(a, in, out, 0);
  cc_store4(b, in, out, 256);
}
#endif

void rktcrypto_chacha20_xor(const unsigned char key[32],
                            const unsigned char nonce[12],
                            uint32_t counter,
                            const unsigned char *in, unsigned char *out,
                            intptr_t len)
{
  uint32_t state[16];
  unsigned char block[64];
  chacha20_setup(state, key, nonce, counter);

#if defined(__aarch64__)
  while (len >= 512) {
    chacha20_8block_xor(state, state[12], in, out);
    state[12] += 8;
    in += 512; out += 512; len -= 512;
  }
  while (len >= 256) {
    chacha20_4block_xor(state, state[12], in, out);
    state[12] += 4;
    in += 256; out += 256; len -= 256;
  }
#endif

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
