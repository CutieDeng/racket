/* SHA-1 (FIPS 180-4) and MD5 (RFC 1321).

   Both are cryptographically broken and MUST NOT be used where collision
   or preimage resistance matters. They remain here only for legacy
   compatibility -- Git object ids, old checksums, HOTP-style HMAC-SHA1,
   and similar -- so that those code paths need no external library. From
   scratch, no external code. */

#include "rktcrypto_digest.h"
#include <string.h>

/* ======================= SHA-1 ======================= */

void rktcrypto_sha1_core_init(rktcrypto_sha1_ctx_t *ctx)
{
  ctx->h[0] = 0x67452301u; ctx->h[1] = 0xEFCDAB89u; ctx->h[2] = 0x98BADCFEu;
  ctx->h[3] = 0x10325476u; ctx->h[4] = 0xC3D2E1F0u;
  ctx->len = 0; ctx->buf_len = 0;
}

#define ROTL32(x,n) (((x) << (n)) | ((x) >> (32 - (n))))

/* Unrolled block with a rolling 16-word schedule -- avoids the 80-word
   array and the per-round branch on the round number. */
#define SHA1_F1(b,c,d) ((((c) ^ (d)) & (b)) ^ (d))       /* choose  0..19 */
#define SHA1_F2(b,c,d) ((b) ^ (c) ^ (d))                 /* parity  20..39,60..79 */
#define SHA1_F3(b,c,d) (((b) & (c)) | (((b) | (c)) & (d)))/* majority 40..59 */
#define SHA1_BLK(i) (w[(i)&15] = ROTL32(w[((i)+13)&15] ^ w[((i)+8)&15] ^ \
                                        w[((i)+2)&15] ^ w[(i)&15], 1))
#define SHA1_R0(a,b,c,d,e,i) e += SHA1_F1(b,c,d) + 0x5A827999u + w[(i)&15] + ROTL32(a,5); b = ROTL32(b,30);
#define SHA1_R1(a,b,c,d,e,i) e += SHA1_F1(b,c,d) + 0x5A827999u + SHA1_BLK(i) + ROTL32(a,5); b = ROTL32(b,30);
#define SHA1_R2(a,b,c,d,e,i) e += SHA1_F2(b,c,d) + 0x6ED9EBA1u + SHA1_BLK(i) + ROTL32(a,5); b = ROTL32(b,30);
#define SHA1_R3(a,b,c,d,e,i) e += SHA1_F3(b,c,d) + 0x8F1BBCDCu + SHA1_BLK(i) + ROTL32(a,5); b = ROTL32(b,30);
#define SHA1_R4(a,b,c,d,e,i) e += SHA1_F2(b,c,d) + 0xCA62C1D6u + SHA1_BLK(i) + ROTL32(a,5); b = ROTL32(b,30);

static void __attribute__((unused)) sha1_block(rktcrypto_sha1_ctx_t *ctx, const unsigned char *p)
{
  uint32_t w[16], a, b, c, d, e;
  int i;
  for (i = 0; i < 16; i++)
    w[i] = ((uint32_t)p[4*i] << 24) | ((uint32_t)p[4*i+1] << 16)
         | ((uint32_t)p[4*i+2] << 8) | (uint32_t)p[4*i+3];
  a = ctx->h[0]; b = ctx->h[1]; c = ctx->h[2]; d = ctx->h[3]; e = ctx->h[4];
  /* 0..19 */
  SHA1_R0(a,b,c,d,e, 0) SHA1_R0(e,a,b,c,d, 1) SHA1_R0(d,e,a,b,c, 2) SHA1_R0(c,d,e,a,b, 3) SHA1_R0(b,c,d,e,a, 4)
  SHA1_R0(a,b,c,d,e, 5) SHA1_R0(e,a,b,c,d, 6) SHA1_R0(d,e,a,b,c, 7) SHA1_R0(c,d,e,a,b, 8) SHA1_R0(b,c,d,e,a, 9)
  SHA1_R0(a,b,c,d,e,10) SHA1_R0(e,a,b,c,d,11) SHA1_R0(d,e,a,b,c,12) SHA1_R0(c,d,e,a,b,13) SHA1_R0(b,c,d,e,a,14)
  SHA1_R0(a,b,c,d,e,15) SHA1_R1(e,a,b,c,d,16) SHA1_R1(d,e,a,b,c,17) SHA1_R1(c,d,e,a,b,18) SHA1_R1(b,c,d,e,a,19)
  /* 20..39 */
  SHA1_R2(a,b,c,d,e,20) SHA1_R2(e,a,b,c,d,21) SHA1_R2(d,e,a,b,c,22) SHA1_R2(c,d,e,a,b,23) SHA1_R2(b,c,d,e,a,24)
  SHA1_R2(a,b,c,d,e,25) SHA1_R2(e,a,b,c,d,26) SHA1_R2(d,e,a,b,c,27) SHA1_R2(c,d,e,a,b,28) SHA1_R2(b,c,d,e,a,29)
  SHA1_R2(a,b,c,d,e,30) SHA1_R2(e,a,b,c,d,31) SHA1_R2(d,e,a,b,c,32) SHA1_R2(c,d,e,a,b,33) SHA1_R2(b,c,d,e,a,34)
  SHA1_R2(a,b,c,d,e,35) SHA1_R2(e,a,b,c,d,36) SHA1_R2(d,e,a,b,c,37) SHA1_R2(c,d,e,a,b,38) SHA1_R2(b,c,d,e,a,39)
  /* 40..59 */
  SHA1_R3(a,b,c,d,e,40) SHA1_R3(e,a,b,c,d,41) SHA1_R3(d,e,a,b,c,42) SHA1_R3(c,d,e,a,b,43) SHA1_R3(b,c,d,e,a,44)
  SHA1_R3(a,b,c,d,e,45) SHA1_R3(e,a,b,c,d,46) SHA1_R3(d,e,a,b,c,47) SHA1_R3(c,d,e,a,b,48) SHA1_R3(b,c,d,e,a,49)
  SHA1_R3(a,b,c,d,e,50) SHA1_R3(e,a,b,c,d,51) SHA1_R3(d,e,a,b,c,52) SHA1_R3(c,d,e,a,b,53) SHA1_R3(b,c,d,e,a,54)
  SHA1_R3(a,b,c,d,e,55) SHA1_R3(e,a,b,c,d,56) SHA1_R3(d,e,a,b,c,57) SHA1_R3(c,d,e,a,b,58) SHA1_R3(b,c,d,e,a,59)
  /* 60..79 */
  SHA1_R4(a,b,c,d,e,60) SHA1_R4(e,a,b,c,d,61) SHA1_R4(d,e,a,b,c,62) SHA1_R4(c,d,e,a,b,63) SHA1_R4(b,c,d,e,a,64)
  SHA1_R4(a,b,c,d,e,65) SHA1_R4(e,a,b,c,d,66) SHA1_R4(d,e,a,b,c,67) SHA1_R4(c,d,e,a,b,68) SHA1_R4(b,c,d,e,a,69)
  SHA1_R4(a,b,c,d,e,70) SHA1_R4(e,a,b,c,d,71) SHA1_R4(d,e,a,b,c,72) SHA1_R4(c,d,e,a,b,73) SHA1_R4(b,c,d,e,a,74)
  SHA1_R4(a,b,c,d,e,75) SHA1_R4(e,a,b,c,d,76) SHA1_R4(d,e,a,b,c,77) SHA1_R4(c,d,e,a,b,78) SHA1_R4(b,c,d,e,a,79)
  ctx->h[0] += a; ctx->h[1] += b; ctx->h[2] += c; ctx->h[3] += d; ctx->h[4] += e;
}

#if defined(__ARM_FEATURE_SHA2) || defined(__ARM_FEATURE_CRYPTO)
#include <arm_neon.h>
/* ARMv8 crypto-extension SHA-1: state stays in NEON registers across the whole
   run of blocks. 5 groups of 4 rounds per constant, message schedule via
   sha1su0/su1, round function sha1c (0-19) / sha1p (20-39,60-79) / sha1m (40-59). */
static void sha1_compress(rktcrypto_sha1_ctx_t *ctx, const unsigned char *p, intptr_t nblk)
{
  uint32x4_t ABCD, ABCD0, MSG0, MSG1, MSG2, MSG3, T0, T1;
  uint32_t E0, E0S, E1;
  const uint32x4_t C0=vdupq_n_u32(0x5A827999u), C1=vdupq_n_u32(0x6ED9EBA1u),
                   C2=vdupq_n_u32(0x8F1BBCDCu), C3=vdupq_n_u32(0xCA62C1D6u);
  ABCD = vld1q_u32(ctx->h); E0 = ctx->h[4];
  while (nblk-- > 0) {
    ABCD0 = ABCD; E0S = E0;
    MSG0 = vreinterpretq_u32_u8(vrev32q_u8(vld1q_u8(p)));
    MSG1 = vreinterpretq_u32_u8(vrev32q_u8(vld1q_u8(p+16)));
    MSG2 = vreinterpretq_u32_u8(vrev32q_u8(vld1q_u8(p+32)));
    MSG3 = vreinterpretq_u32_u8(vrev32q_u8(vld1q_u8(p+48)));
    T0 = vaddq_u32(MSG0, C0); T1 = vaddq_u32(MSG1, C0);
    E1=vsha1h_u32(vgetq_lane_u32(ABCD,0)); ABCD=vsha1cq_u32(ABCD,E0,T0); T0=vaddq_u32(MSG2,C0); MSG0=vsha1su0q_u32(MSG0,MSG1,MSG2);
    E0=vsha1h_u32(vgetq_lane_u32(ABCD,0)); ABCD=vsha1cq_u32(ABCD,E1,T1); T1=vaddq_u32(MSG3,C0); MSG0=vsha1su1q_u32(MSG0,MSG3); MSG1=vsha1su0q_u32(MSG1,MSG2,MSG3);
    E1=vsha1h_u32(vgetq_lane_u32(ABCD,0)); ABCD=vsha1cq_u32(ABCD,E0,T0); T0=vaddq_u32(MSG0,C0); MSG1=vsha1su1q_u32(MSG1,MSG0); MSG2=vsha1su0q_u32(MSG2,MSG3,MSG0);
    E0=vsha1h_u32(vgetq_lane_u32(ABCD,0)); ABCD=vsha1cq_u32(ABCD,E1,T1); T1=vaddq_u32(MSG1,C1); MSG2=vsha1su1q_u32(MSG2,MSG1); MSG3=vsha1su0q_u32(MSG3,MSG0,MSG1);
    E1=vsha1h_u32(vgetq_lane_u32(ABCD,0)); ABCD=vsha1cq_u32(ABCD,E0,T0); T0=vaddq_u32(MSG2,C1); MSG3=vsha1su1q_u32(MSG3,MSG2); MSG0=vsha1su0q_u32(MSG0,MSG1,MSG2);
    E0=vsha1h_u32(vgetq_lane_u32(ABCD,0)); ABCD=vsha1pq_u32(ABCD,E1,T1); T1=vaddq_u32(MSG3,C1); MSG0=vsha1su1q_u32(MSG0,MSG3); MSG1=vsha1su0q_u32(MSG1,MSG2,MSG3);
    E1=vsha1h_u32(vgetq_lane_u32(ABCD,0)); ABCD=vsha1pq_u32(ABCD,E0,T0); T0=vaddq_u32(MSG0,C1); MSG1=vsha1su1q_u32(MSG1,MSG0); MSG2=vsha1su0q_u32(MSG2,MSG3,MSG0);
    E0=vsha1h_u32(vgetq_lane_u32(ABCD,0)); ABCD=vsha1pq_u32(ABCD,E1,T1); T1=vaddq_u32(MSG1,C1); MSG2=vsha1su1q_u32(MSG2,MSG1); MSG3=vsha1su0q_u32(MSG3,MSG0,MSG1);
    E1=vsha1h_u32(vgetq_lane_u32(ABCD,0)); ABCD=vsha1pq_u32(ABCD,E0,T0); T0=vaddq_u32(MSG2,C2); MSG3=vsha1su1q_u32(MSG3,MSG2); MSG0=vsha1su0q_u32(MSG0,MSG1,MSG2);
    E0=vsha1h_u32(vgetq_lane_u32(ABCD,0)); ABCD=vsha1pq_u32(ABCD,E1,T1); T1=vaddq_u32(MSG3,C2); MSG0=vsha1su1q_u32(MSG0,MSG3); MSG1=vsha1su0q_u32(MSG1,MSG2,MSG3);
    E1=vsha1h_u32(vgetq_lane_u32(ABCD,0)); ABCD=vsha1mq_u32(ABCD,E0,T0); T0=vaddq_u32(MSG0,C2); MSG1=vsha1su1q_u32(MSG1,MSG0); MSG2=vsha1su0q_u32(MSG2,MSG3,MSG0);
    E0=vsha1h_u32(vgetq_lane_u32(ABCD,0)); ABCD=vsha1mq_u32(ABCD,E1,T1); T1=vaddq_u32(MSG1,C2); MSG2=vsha1su1q_u32(MSG2,MSG1); MSG3=vsha1su0q_u32(MSG3,MSG0,MSG1);
    E1=vsha1h_u32(vgetq_lane_u32(ABCD,0)); ABCD=vsha1mq_u32(ABCD,E0,T0); T0=vaddq_u32(MSG2,C2); MSG3=vsha1su1q_u32(MSG3,MSG2); MSG0=vsha1su0q_u32(MSG0,MSG1,MSG2);
    E0=vsha1h_u32(vgetq_lane_u32(ABCD,0)); ABCD=vsha1mq_u32(ABCD,E1,T1); T1=vaddq_u32(MSG3,C3); MSG0=vsha1su1q_u32(MSG0,MSG3); MSG1=vsha1su0q_u32(MSG1,MSG2,MSG3);
    E1=vsha1h_u32(vgetq_lane_u32(ABCD,0)); ABCD=vsha1mq_u32(ABCD,E0,T0); T0=vaddq_u32(MSG0,C3); MSG1=vsha1su1q_u32(MSG1,MSG0); MSG2=vsha1su0q_u32(MSG2,MSG3,MSG0);
    E0=vsha1h_u32(vgetq_lane_u32(ABCD,0)); ABCD=vsha1pq_u32(ABCD,E1,T1); T1=vaddq_u32(MSG1,C3); MSG2=vsha1su1q_u32(MSG2,MSG1); MSG3=vsha1su0q_u32(MSG3,MSG0,MSG1);
    E1=vsha1h_u32(vgetq_lane_u32(ABCD,0)); ABCD=vsha1pq_u32(ABCD,E0,T0); T0=vaddq_u32(MSG2,C3); MSG3=vsha1su1q_u32(MSG3,MSG2);
    E0=vsha1h_u32(vgetq_lane_u32(ABCD,0)); ABCD=vsha1pq_u32(ABCD,E1,T1); T1=vaddq_u32(MSG3,C3);
    E1=vsha1h_u32(vgetq_lane_u32(ABCD,0)); ABCD=vsha1pq_u32(ABCD,E0,T0);
    E0=vsha1h_u32(vgetq_lane_u32(ABCD,0)); ABCD=vsha1pq_u32(ABCD,E1,T1);
    E0 += E0S; ABCD = vaddq_u32(ABCD0, ABCD);
    p += 64;
  }
  vst1q_u32(ctx->h, ABCD); ctx->h[4] = E0;
}
#else
static void sha1_compress(rktcrypto_sha1_ctx_t *ctx, const unsigned char *p, intptr_t nblk)
{ while (nblk-- > 0) { sha1_block(ctx, p); p += 64; } }
#endif

void rktcrypto_sha1_core_update(rktcrypto_sha1_ctx_t *ctx,
                                const unsigned char *data, intptr_t len)
{
  ctx->len += (uint64_t)len * 8;
  if (ctx->buf_len) {
    while (len && ctx->buf_len < 64) { ctx->buf[ctx->buf_len++] = *data++; len--; }
    if (ctx->buf_len == 64) { sha1_compress(ctx, ctx->buf, 1); ctx->buf_len = 0; }
  }
  if (len >= 64) { intptr_t nb = len >> 6; sha1_compress(ctx, data, nb); data += nb<<6; len -= nb<<6; }
  while (len) { ctx->buf[ctx->buf_len++] = *data++; len--; }
}

void rktcrypto_sha1_core_final(rktcrypto_sha1_ctx_t *ctx,
                               unsigned char *out, intptr_t out_len)
{
  uint64_t bits = ctx->len;
  int i;
  unsigned char pad = 0x80;
  intptr_t n;
  (void)out_len;
  rktcrypto_sha1_core_update(ctx, &pad, 1);
  ctx->len -= 8;  /* padding does not count toward message length */
  pad = 0;
  while (ctx->buf_len != 56) { rktcrypto_sha1_core_update(ctx, &pad, 1); ctx->len -= 8; }
  {
    unsigned char lb[8];
    for (i = 0; i < 8; i++) lb[i] = (unsigned char)(bits >> (56 - 8*i));
    for (n = 0; n < 8; n++) { ctx->buf[ctx->buf_len++] = lb[n]; }
    sha1_compress(ctx, ctx->buf, 1); ctx->buf_len = 0;
  }
  for (i = 0; i < 5; i++) {
    out[4*i+0] = (unsigned char)(ctx->h[i] >> 24);
    out[4*i+1] = (unsigned char)(ctx->h[i] >> 16);
    out[4*i+2] = (unsigned char)(ctx->h[i] >> 8);
    out[4*i+3] = (unsigned char)(ctx->h[i]);
  }
}

/* ======================= MD5 ======================= */

void rktcrypto_md5_core_init(rktcrypto_md5_ctx_t *ctx)
{
  ctx->h[0] = 0x67452301u; ctx->h[1] = 0xefcdab89u;
  ctx->h[2] = 0x98badcfeu; ctx->h[3] = 0x10325476u;
  ctx->len = 0; ctx->buf_len = 0;
}

/* Fully unrolled RFC 1321 transform (branchless). */
#define MD5_F(x,y,z) (((x) & (y)) | ((~(x)) & (z)))
#define MD5_G(x,y,z) (((x) & (z)) | ((y) & (~(z))))
#define MD5_H(x,y,z) ((x) ^ (y) ^ (z))
#define MD5_I(x,y,z) ((y) ^ ((x) | (~(z))))
#define MD5_FF(a,b,c,d,x,s,ac) a = b + ROTL32(a + MD5_F(b,c,d) + (x) + (ac), s);
#define MD5_GG(a,b,c,d,x,s,ac) a = b + ROTL32(a + MD5_G(b,c,d) + (x) + (ac), s);
#define MD5_HH(a,b,c,d,x,s,ac) a = b + ROTL32(a + MD5_H(b,c,d) + (x) + (ac), s);
#define MD5_II(a,b,c,d,x,s,ac) a = b + ROTL32(a + MD5_I(b,c,d) + (x) + (ac), s);

static void md5_block(rktcrypto_md5_ctx_t *ctx, const unsigned char *p)
{
  uint32_t m[16], a, b, c, d;
  int i;
  for (i = 0; i < 16; i++)
    m[i] = (uint32_t)p[4*i] | ((uint32_t)p[4*i+1] << 8)
         | ((uint32_t)p[4*i+2] << 16) | ((uint32_t)p[4*i+3] << 24);
  a = ctx->h[0]; b = ctx->h[1]; c = ctx->h[2]; d = ctx->h[3];
  MD5_FF(a,b,c,d,m[ 0], 7,0xd76aa478u) MD5_FF(d,a,b,c,m[ 1],12,0xe8c7b756u) MD5_FF(c,d,a,b,m[ 2],17,0x242070dbu) MD5_FF(b,c,d,a,m[ 3],22,0xc1bdceeeu)
  MD5_FF(a,b,c,d,m[ 4], 7,0xf57c0fafu) MD5_FF(d,a,b,c,m[ 5],12,0x4787c62au) MD5_FF(c,d,a,b,m[ 6],17,0xa8304613u) MD5_FF(b,c,d,a,m[ 7],22,0xfd469501u)
  MD5_FF(a,b,c,d,m[ 8], 7,0x698098d8u) MD5_FF(d,a,b,c,m[ 9],12,0x8b44f7afu) MD5_FF(c,d,a,b,m[10],17,0xffff5bb1u) MD5_FF(b,c,d,a,m[11],22,0x895cd7beu)
  MD5_FF(a,b,c,d,m[12], 7,0x6b901122u) MD5_FF(d,a,b,c,m[13],12,0xfd987193u) MD5_FF(c,d,a,b,m[14],17,0xa679438eu) MD5_FF(b,c,d,a,m[15],22,0x49b40821u)
  MD5_GG(a,b,c,d,m[ 1], 5,0xf61e2562u) MD5_GG(d,a,b,c,m[ 6], 9,0xc040b340u) MD5_GG(c,d,a,b,m[11],14,0x265e5a51u) MD5_GG(b,c,d,a,m[ 0],20,0xe9b6c7aau)
  MD5_GG(a,b,c,d,m[ 5], 5,0xd62f105du) MD5_GG(d,a,b,c,m[10], 9,0x02441453u) MD5_GG(c,d,a,b,m[15],14,0xd8a1e681u) MD5_GG(b,c,d,a,m[ 4],20,0xe7d3fbc8u)
  MD5_GG(a,b,c,d,m[ 9], 5,0x21e1cde6u) MD5_GG(d,a,b,c,m[14], 9,0xc33707d6u) MD5_GG(c,d,a,b,m[ 3],14,0xf4d50d87u) MD5_GG(b,c,d,a,m[ 8],20,0x455a14edu)
  MD5_GG(a,b,c,d,m[13], 5,0xa9e3e905u) MD5_GG(d,a,b,c,m[ 2], 9,0xfcefa3f8u) MD5_GG(c,d,a,b,m[ 7],14,0x676f02d9u) MD5_GG(b,c,d,a,m[12],20,0x8d2a4c8au)
  MD5_HH(a,b,c,d,m[ 5], 4,0xfffa3942u) MD5_HH(d,a,b,c,m[ 8],11,0x8771f681u) MD5_HH(c,d,a,b,m[11],16,0x6d9d6122u) MD5_HH(b,c,d,a,m[14],23,0xfde5380cu)
  MD5_HH(a,b,c,d,m[ 1], 4,0xa4beea44u) MD5_HH(d,a,b,c,m[ 4],11,0x4bdecfa9u) MD5_HH(c,d,a,b,m[ 7],16,0xf6bb4b60u) MD5_HH(b,c,d,a,m[10],23,0xbebfbc70u)
  MD5_HH(a,b,c,d,m[13], 4,0x289b7ec6u) MD5_HH(d,a,b,c,m[ 0],11,0xeaa127fau) MD5_HH(c,d,a,b,m[ 3],16,0xd4ef3085u) MD5_HH(b,c,d,a,m[ 6],23,0x04881d05u)
  MD5_HH(a,b,c,d,m[ 9], 4,0xd9d4d039u) MD5_HH(d,a,b,c,m[12],11,0xe6db99e5u) MD5_HH(c,d,a,b,m[15],16,0x1fa27cf8u) MD5_HH(b,c,d,a,m[ 2],23,0xc4ac5665u)
  MD5_II(a,b,c,d,m[ 0], 6,0xf4292244u) MD5_II(d,a,b,c,m[ 7],10,0x432aff97u) MD5_II(c,d,a,b,m[14],15,0xab9423a7u) MD5_II(b,c,d,a,m[ 5],21,0xfc93a039u)
  MD5_II(a,b,c,d,m[12], 6,0x655b59c3u) MD5_II(d,a,b,c,m[ 3],10,0x8f0ccc92u) MD5_II(c,d,a,b,m[10],15,0xffeff47du) MD5_II(b,c,d,a,m[ 1],21,0x85845dd1u)
  MD5_II(a,b,c,d,m[ 8], 6,0x6fa87e4fu) MD5_II(d,a,b,c,m[15],10,0xfe2ce6e0u) MD5_II(c,d,a,b,m[ 6],15,0xa3014314u) MD5_II(b,c,d,a,m[13],21,0x4e0811a1u)
  MD5_II(a,b,c,d,m[ 4], 6,0xf7537e82u) MD5_II(d,a,b,c,m[11],10,0xbd3af235u) MD5_II(c,d,a,b,m[ 2],15,0x2ad7d2bbu) MD5_II(b,c,d,a,m[ 9],21,0xeb86d391u)
  ctx->h[0] += a; ctx->h[1] += b; ctx->h[2] += c; ctx->h[3] += d;
}

void rktcrypto_md5_core_update(rktcrypto_md5_ctx_t *ctx,
                               const unsigned char *data, intptr_t len)
{
  ctx->len += (uint64_t)len * 8;
  if (ctx->buf_len) {
    while (len && ctx->buf_len < 64) { ctx->buf[ctx->buf_len++] = *data++; len--; }
    if (ctx->buf_len == 64) { md5_block(ctx, ctx->buf); ctx->buf_len = 0; }
  }
  while (len >= 64) { md5_block(ctx, data); data += 64; len -= 64; }
  while (len) { ctx->buf[ctx->buf_len++] = *data++; len--; }
}

void rktcrypto_md5_core_final(rktcrypto_md5_ctx_t *ctx,
                              unsigned char *out, intptr_t out_len)
{
  uint64_t bits = ctx->len;
  int i;
  unsigned char pad = 0x80;
  (void)out_len;
  rktcrypto_md5_core_update(ctx, &pad, 1);
  ctx->len -= 8;
  pad = 0;
  while (ctx->buf_len != 56) { rktcrypto_md5_core_update(ctx, &pad, 1); ctx->len -= 8; }
  {
    unsigned char lb[8];
    for (i = 0; i < 8; i++) lb[i] = (unsigned char)(bits >> (8*i));  /* little-endian */
    for (i = 0; i < 8; i++) ctx->buf[ctx->buf_len++] = lb[i];
    md5_block(ctx, ctx->buf); ctx->buf_len = 0;
  }
  for (i = 0; i < 4; i++) {
    out[4*i+0] = (unsigned char)(ctx->h[i]);
    out[4*i+1] = (unsigned char)(ctx->h[i] >> 8);
    out[4*i+2] = (unsigned char)(ctx->h[i] >> 16);
    out[4*i+3] = (unsigned char)(ctx->h[i] >> 24);
  }
}
