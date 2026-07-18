/* AES-256-GCM (NIST SP 800-38D), built on the constant-time AES-256
   block cipher.

   From-scratch public-domain-style implementation. GHASH uses a
   constant-time bit-by-bit GF(2^128) multiply (no tables), so the
   authenticator has no data-dependent timing. Suitable as the AES-GCM
   construction alongside ChaCha20-Poly1305; on hardware without AES
   acceleration, prefer ChaCha20-Poly1305 for speed. */

#include "rktcrypto.h"
#include "rktcrypto_cipher.h"
#if defined(__x86_64__) || defined(__i386__)
# include "rktcrypto_cpu.h"
# include "rktcrypto_x86.h"
#endif
#include <string.h>

static void inc32(unsigned char ctr[16]);   /* forward decl for the pipelined path */

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

/* ---- pipelined AES-GCM: 4-way AES-CTR fused with aggregated GHASH ----
   The GHASH of four blocks c0..c3 with subkey powers H^4..H^1 is
   (acc^c0)*H^4 ^ c1*H^3 ^ c2*H^2 ^ c3*H^1, computed as four
   carryless multiplies summed as 256-bit products with a SINGLE final
   reduction (instead of four). Verified bit-exact against the portable
   GHASH over 2e4 random multi-block inputs. */
static inline uint64x2_t gcm_mk2(uint64_t a, uint64_t b)
{
  return vsetq_lane_u64(b, vdupq_n_u64(a), 1);
}
static inline void gcm_clmul256(uint64_t a0, uint64_t a1, uint64_t hh0, uint64_t hh1,
                                uint64x2_t *lo, uint64x2_t *hi)
{
  uint64x2_t l  = vreinterpretq_u64_p128(gcm_cl(a0, hh0));
  uint64x2_t h  = vreinterpretq_u64_p128(gcm_cl(a1, hh1));
  uint64x2_t md = vreinterpretq_u64_p128(gcm_cl(a0 ^ a1, hh0 ^ hh1));
  uint64_t mlo, mhi;
  md = veorq_u64(md, veorq_u64(l, h));
  mlo = vgetq_lane_u64(md, 0); mhi = vgetq_lane_u64(md, 1);
  *lo = gcm_mk2(vgetq_lane_u64(l, 0),       vgetq_lane_u64(l, 1) ^ mlo);
  *hi = gcm_mk2(vgetq_lane_u64(h, 0) ^ mhi, vgetq_lane_u64(h, 1));
}
static inline uint64x2_t gcm_reduce256(uint64x2_t X0, uint64x2_t X1)
{
  uint64_t X1_0 = vgetq_lane_u64(X1, 0), X1_1 = vgetq_lane_u64(X1, 1);
  uint64x2_t rlo = vreinterpretq_u64_p128(gcm_cl(X1_0, 0x87));
  uint64x2_t rhi = vreinterpretq_u64_p128(gcm_cl(X1_1, 0x87));
  uint64_t R0 = vgetq_lane_u64(rlo, 0);
  uint64_t R1 = vgetq_lane_u64(rlo, 1) ^ vgetq_lane_u64(rhi, 0);
  uint64_t R2 = vgetq_lane_u64(rhi, 1);
  uint64_t S0 = vgetq_lane_u64(vreinterpretq_u64_p128(gcm_cl(R2, 0x87)), 0);
  return gcm_mk2(vgetq_lane_u64(X0, 0) ^ R0 ^ S0, vgetq_lane_u64(X0, 1) ^ R1);
}
static inline uint64x2_t gcm_revbits(uint64x2_t v)
{
  return vreinterpretq_u64_u8(vrbitq_u8(vreinterpretq_u8_u64(v)));
}
static inline uint64x2_t gcm_gfmul_n(uint64x2_t a, uint64x2_t hh)
{
  uint64x2_t lo, hi;
  gcm_clmul256(vgetq_lane_u64(a,0), vgetq_lane_u64(a,1), vgetq_lane_u64(hh,0), vgetq_lane_u64(hh,1), &lo, &hi);
  return gcm_reduce256(lo, hi);
}
static inline uint64x2_t gcm_agg4(uint64x2_t acc, uint64x2_t c0, uint64x2_t c1, uint64x2_t c2, uint64x2_t c3,
                                  uint64x2_t H1, uint64x2_t H2, uint64x2_t H3, uint64x2_t H4)
{
  uint64x2_t a0 = veorq_u64(acc, c0), lo, hi, lo1, hi1;
  gcm_clmul256(vgetq_lane_u64(a0,0), vgetq_lane_u64(a0,1), vgetq_lane_u64(H4,0), vgetq_lane_u64(H4,1), &lo, &hi);
  gcm_clmul256(vgetq_lane_u64(c1,0), vgetq_lane_u64(c1,1), vgetq_lane_u64(H3,0), vgetq_lane_u64(H3,1), &lo1, &hi1); lo=veorq_u64(lo,lo1); hi=veorq_u64(hi,hi1);
  gcm_clmul256(vgetq_lane_u64(c2,0), vgetq_lane_u64(c2,1), vgetq_lane_u64(H2,0), vgetq_lane_u64(H2,1), &lo1, &hi1); lo=veorq_u64(lo,lo1); hi=veorq_u64(hi,hi1);
  gcm_clmul256(vgetq_lane_u64(c3,0), vgetq_lane_u64(c3,1), vgetq_lane_u64(H1,0), vgetq_lane_u64(H1,1), &lo1, &hi1); lo=veorq_u64(lo,lo1); hi=veorq_u64(hi,hi1);
  return gcm_reduce256(lo, hi);
}
static inline uint64x2_t gcm_ghash1(uint64x2_t acc, uint64x2_t crev, uint64_t h0, uint64_t h1)
{
  acc = veorq_u64(acc, crev);
  return gcm_clmul_reduce(vgetq_lane_u64(acc,0), vgetq_lane_u64(acc,1), h0, h1);
}
/* Eight-block aggregation: (acc^c0)*H^8 ^ c1*H^7 ^ ... ^ c7*H^1, one reduction. */
static inline uint64x2_t gcm_agg8(uint64x2_t acc, const uint64x2_t c[8], const uint64x2_t Hp[8])
{
  /* Hp[k] = H^(k+1); the block that acc folds into uses the highest power. */
  uint64x2_t a0 = veorq_u64(acc, c[0]), lo, hi, lo1, hi1;
  int j;
  gcm_clmul256(vgetq_lane_u64(a0,0), vgetq_lane_u64(a0,1), vgetq_lane_u64(Hp[7],0), vgetq_lane_u64(Hp[7],1), &lo, &hi);
  for (j = 1; j < 8; j++) {
    gcm_clmul256(vgetq_lane_u64(c[j],0), vgetq_lane_u64(c[j],1), vgetq_lane_u64(Hp[7-j],0), vgetq_lane_u64(Hp[7-j],1), &lo1, &hi1);
    lo = veorq_u64(lo, lo1); hi = veorq_u64(hi, hi1);
  }
  return gcm_reduce256(lo, hi);
}

/* Full seal (encrypt=1) or open (encrypt=0) core: encrypts/decrypts and
   authenticates in a single pass, four blocks at a time. `tag` gets the
   16-byte authenticator (the caller compares it on open). */
static void gcm_hw(const unsigned char rk[240], const uint64_t h[2],
                   const unsigned char nonce[12],
                   const unsigned char *aad, intptr_t aad_len,
                   const unsigned char *in, unsigned char *out, intptr_t len,
                   int encrypt, unsigned char tag[16])
{
  unsigned char hb[16], blk[16], ctr[16], j0[16], ej0[16], s[16];
  uint64x2_t H1, H2, H3, H4, Hp[8], acc;
  uint64_t h0, h1;
  intptr_t l;
  int i;

  for (i = 0; i < 8; i++) { hb[i] = (unsigned char)(h[0] >> (56 - 8*i)); hb[8+i] = (unsigned char)(h[1] >> (56 - 8*i)); }
  H1 = gcm_revbits(vreinterpretq_u64_u8(vld1q_u8(hb)));
  H2 = gcm_gfmul_n(H1, H1); H3 = gcm_gfmul_n(H2, H1); H4 = gcm_gfmul_n(H3, H1);
  Hp[0]=H1; Hp[1]=H2; Hp[2]=H3; Hp[3]=H4;
  Hp[4]=gcm_gfmul_n(H4,H1); Hp[5]=gcm_gfmul_n(Hp[4],H1);
  Hp[6]=gcm_gfmul_n(Hp[5],H1); Hp[7]=gcm_gfmul_n(Hp[6],H1);
  h0 = vgetq_lane_u64(H1, 0); h1 = vgetq_lane_u64(H1, 1);
  acc = vdupq_n_u64(0);

  /* GHASH the AAD (aggregated 4-block, then 16-byte blocks, then partial). */
  l = aad_len;
  while (l >= 64) {
    acc = gcm_agg4(acc,
                   gcm_revbits(vreinterpretq_u64_u8(vld1q_u8(aad))),
                   gcm_revbits(vreinterpretq_u64_u8(vld1q_u8(aad+16))),
                   gcm_revbits(vreinterpretq_u64_u8(vld1q_u8(aad+32))),
                   gcm_revbits(vreinterpretq_u64_u8(vld1q_u8(aad+48))),
                   H1, H2, H3, H4);
    aad += 64; l -= 64;
  }
  while (l >= 16) { acc = gcm_ghash1(acc, gcm_revbits(vreinterpretq_u64_u8(vld1q_u8(aad))), h0, h1); aad += 16; l -= 16; }
  if (l > 0) { memset(blk, 0, 16); for (i = 0; i < l; i++) blk[i] = aad[i];
    acc = gcm_ghash1(acc, gcm_revbits(vreinterpretq_u64_u8(vld1q_u8(blk))), h0, h1); }

  memcpy(ctr, nonce, 12); ctr[12]=0; ctr[13]=0; ctr[14]=0; ctr[15]=2;

  l = len;
  /* Stitched 8-way: GHASH the previous block-set while the current set's AES is
     in flight. GHASH(prev) reads only already-stored ciphertext, so it is
     independent of AES(current); the wide OoO core issues the PMULL chain and
     the AES chain to their separate units concurrently -- roughly max(AES,GHASH)
     per iteration rather than AES+GHASH. */
  {
    uint64x2_t cg[8];
    int have_prev = 0;
    while (l >= 128) {
      uint8x16_t st8[8], k, iv8[8], ov8[8];
      uint32x4_t bv = vreinterpretq_u32_u8(vld1q_u8(ctr));
      uint32_t c0 = __builtin_bswap32(vgetq_lane_u32(bv, 3));   /* big-endian counter */
      int r, b;
      for (b = 0; b < 8; b++)
        st8[b] = vreinterpretq_u8_u32(vsetq_lane_u32(__builtin_bswap32(c0 + (uint32_t)b), bv, 3));
      for (r = 0; r < 13; r++) { k = vld1q_u8(rk+16*r);
        for (b = 0; b < 8; b++) st8[b] = vaesmcq_u8(vaeseq_u8(st8[b], k)); }
      { uint8x16_t k13=vld1q_u8(rk+16*13), k14=vld1q_u8(rk+16*14);
        for (b = 0; b < 8; b++) st8[b] = veorq_u8(vaeseq_u8(st8[b], k13), k14); }
      if (have_prev) acc = gcm_agg8(acc, cg, Hp);   /* fold prev, overlaps AES above */
      for (b = 0; b < 8; b++) {
        iv8[b] = vld1q_u8(in+16*b);
        ov8[b] = veorq_u8(iv8[b], st8[b]);
        vst1q_u8(out+16*b, ov8[b]);
        cg[b] = gcm_revbits(vreinterpretq_u64_u8(encrypt ? ov8[b] : iv8[b]));
      }
      have_prev = 1;
      vst1q_u8(ctr, vreinterpretq_u8_u32(vsetq_lane_u32(__builtin_bswap32(c0 + 8u), bv, 3)));
      in += 128; out += 128; l -= 128;
    }
    if (have_prev) acc = gcm_agg8(acc, cg, Hp);      /* final set */
  }
  while (l >= 64) {
    uint8x16_t s0, s1, s2, s3, k, i0, i1, i2, i3, o0, o1, o2, o3, g0, g1, g2, g3;
    uint32x4_t bv = vreinterpretq_u32_u8(vld1q_u8(ctr));
    uint32_t c0 = __builtin_bswap32(vgetq_lane_u32(bv, 3));
    int r;
    s0=vreinterpretq_u8_u32(vsetq_lane_u32(__builtin_bswap32(c0),    bv, 3));
    s1=vreinterpretq_u8_u32(vsetq_lane_u32(__builtin_bswap32(c0+1u), bv, 3));
    s2=vreinterpretq_u8_u32(vsetq_lane_u32(__builtin_bswap32(c0+2u), bv, 3));
    s3=vreinterpretq_u8_u32(vsetq_lane_u32(__builtin_bswap32(c0+3u), bv, 3));
    for (r=0;r<13;r++){ k=vld1q_u8(rk+16*r);
      s0=vaesmcq_u8(vaeseq_u8(s0,k)); s1=vaesmcq_u8(vaeseq_u8(s1,k));
      s2=vaesmcq_u8(vaeseq_u8(s2,k)); s3=vaesmcq_u8(vaeseq_u8(s3,k)); }
    { uint8x16_t k13=vld1q_u8(rk+16*13), k14=vld1q_u8(rk+16*14);
      s0=veorq_u8(vaeseq_u8(s0,k13),k14); s1=veorq_u8(vaeseq_u8(s1,k13),k14);
      s2=veorq_u8(vaeseq_u8(s2,k13),k14); s3=veorq_u8(vaeseq_u8(s3,k13),k14); }
    i0=vld1q_u8(in); i1=vld1q_u8(in+16); i2=vld1q_u8(in+32); i3=vld1q_u8(in+48);
    o0=veorq_u8(i0,s0); o1=veorq_u8(i1,s1); o2=veorq_u8(i2,s2); o3=veorq_u8(i3,s3);
    vst1q_u8(out,o0); vst1q_u8(out+16,o1); vst1q_u8(out+32,o2); vst1q_u8(out+48,o3);
    g0 = encrypt?o0:i0; g1 = encrypt?o1:i1; g2 = encrypt?o2:i2; g3 = encrypt?o3:i3;
    acc = gcm_agg4(acc,
                   gcm_revbits(vreinterpretq_u64_u8(g0)), gcm_revbits(vreinterpretq_u64_u8(g1)),
                   gcm_revbits(vreinterpretq_u64_u8(g2)), gcm_revbits(vreinterpretq_u64_u8(g3)),
                   H1, H2, H3, H4);
    vst1q_u8(ctr, vreinterpretq_u8_u32(vsetq_lane_u32(__builtin_bswap32(c0+4u), bv, 3)));
    in += 64; out += 64; l -= 64;
  }
  while (l > 0) {
    intptr_t n = l < 16 ? l : 16;
    unsigned char ks[16], ob[16];
    rktcrypto_aes256_encrypt_block(rk, ctr, ks);
    for (i = 0; i < n; i++) ob[i] = in[i] ^ ks[i];
    for (i = 0; i < n; i++) out[i] = ob[i];
    memset(blk, 0, 16);
    for (i = 0; i < n; i++) blk[i] = encrypt ? ob[i] : in[i];
    acc = gcm_ghash1(acc, gcm_revbits(vreinterpretq_u64_u8(vld1q_u8(blk))), h0, h1);
    inc32(ctr);
    in += n; out += n; l -= n;
  }

  { uint64_t abits=(uint64_t)aad_len<<3, cbits=(uint64_t)len<<3;
    for (i=0;i<8;i++) blk[i]=(unsigned char)(abits>>(56-8*i));
    for (i=0;i<8;i++) blk[8+i]=(unsigned char)(cbits>>(56-8*i)); }
  acc = gcm_ghash1(acc, gcm_revbits(vreinterpretq_u64_u8(vld1q_u8(blk))), h0, h1);

  vst1q_u8(s, vrbitq_u8(vreinterpretq_u8_u64(acc)));
  memcpy(j0, nonce, 12); j0[12]=0;j0[13]=0;j0[14]=0;j0[15]=1;
  rktcrypto_aes256_encrypt_block(rk, j0, ej0);
  for (i=0;i<16;i++) tag[i] = s[i] ^ ej0[i];
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

/* CTR-mode keystream XOR, starting from counter block `ctr`. The AES
   block itself uses the hardware path; the CTR latency is not the
   AES-GCM bottleneck (GHASH's serial reduction and the two-pass memory
   traffic are), so a wider pipeline here did not help in practice. */
static void __attribute__((unused))
gctr(const unsigned char rk[240], unsigned char ctr[16],
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
static void __attribute__((unused))
gcm_tag(const unsigned char rk[240], const unsigned char nonce[12],
                    const unsigned char *aad, intptr_t aad_len,
                    const unsigned char *ct, intptr_t ct_len,
                    const uint64_t h[2], unsigned char tag[16])
{
  unsigned char j0[16], ej0[16], s[16];
  int i;

#if defined(__ARM_FEATURE_AES) || defined(__ARM_FEATURE_CRYPTO)
  gcm_ghash_hw(h, aad, aad_len, ct, ct_len, s);
#else
# if defined(__x86_64__) || defined(__i386__)
  if (rktcrypto_cpu_has(RKTCRYPTO_CPU_X86_PCLMUL)) {
    rktcrypto_ghash_x86(h, aad, aad_len, ct, ct_len, s);
  } else
# endif
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
  unsigned char rk[240];
  uint64_t h[2];
  intptr_t pt_len = pt_end - pt_start, aad_len = aad_end - aad_start;
  unsigned char *ct = out + out_start;

  if (pt_len < 0 || aad_len < 0) return 0;

  gcm_setup(key, rk, h);
#if defined(__ARM_FEATURE_AES) || defined(__ARM_FEATURE_CRYPTO)
  gcm_hw(rk, h, nonce, aad + aad_start, aad_len, pt + pt_start, ct, pt_len, 1, ct + pt_len);
#else
  { unsigned char ctr[16];
    /* CTR starts at J0 + 1 = nonce || 0x00000002 */
    memcpy(ctr, nonce, 12);
    ctr[12] = 0; ctr[13] = 0; ctr[14] = 0; ctr[15] = 2;
    gctr(rk, ctr, pt + pt_start, ct, pt_len);
    gcm_tag(rk, nonce, aad + aad_start, aad_len, ct, pt_len, h, ct + pt_len); }
#endif
  return 1;
}

int rktcrypto_aes256gcm_open(const unsigned char key[32], const unsigned char nonce[12],
                             const unsigned char *aad, intptr_t aad_start, intptr_t aad_end,
                             const unsigned char *ct, intptr_t ct_start, intptr_t ct_end,
                             unsigned char *out, intptr_t out_start)
{
  unsigned char rk[240], tag[16];
  uint64_t h[2];
  intptr_t total = ct_end - ct_start, aad_len = aad_end - aad_start, ct_len;
  const unsigned char *cbody = ct + ct_start;

  if (total < 16 || aad_len < 0) return 0;
  ct_len = total - 16;

  gcm_setup(key, rk, h);
#if defined(__ARM_FEATURE_AES) || defined(__ARM_FEATURE_CRYPTO)
  /* Single pass: decrypt into out and compute the tag together. If the
     tag is wrong, zero the plaintext so no unverified data is exposed. */
  gcm_hw(rk, h, nonce, aad + aad_start, aad_len, cbody, out + out_start, ct_len, 0, tag);
  if (!rktcrypto_ct_bytes_equal(tag, 0, cbody + ct_len, 0, 16)) {
    memset(out + out_start, 0, (size_t)ct_len);
    return 0;
  }
  return 1;
#else
  gcm_tag(rk, nonce, aad + aad_start, aad_len, cbody, ct_len, h, tag);
  if (!rktcrypto_ct_bytes_equal(tag, 0, cbody + ct_len, 0, 16))
    return 0;
  { unsigned char ctr[16];
    memcpy(ctr, nonce, 12);
    ctr[12] = 0; ctr[13] = 0; ctr[14] = 0; ctr[15] = 2;
    gctr(rk, ctr, cbody, out + out_start, ct_len); }
  return 1;
#endif
}
