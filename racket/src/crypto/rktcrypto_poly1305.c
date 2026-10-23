/* Poly1305 one-time authenticator, per RFC 8439.

   From-scratch public-domain-style implementation using 32-bit limbs
   (radix 2^26), validated by the RFC 8439 test vectors. The reduction
   is constant-time with respect to the message contents. */

#include "rktcrypto_cipher.h"
#include <string.h>
#if defined(__x86_64__) && defined(__ELF__)
# include "rktcrypto_cpu.h"
# include "rktcrypto_x86.h"
#endif

static uint32_t load32_le(const unsigned char *p)
{
  return ((uint32_t)p[0]) | ((uint32_t)p[1] << 8)
       | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

void rktcrypto_poly1305_init(rktcrypto_poly1305_ctx_t *ctx, const unsigned char key[32])
{
  /* r &= 0xffffffc0ffffffc0ffffffc0fffffff */
  ctx->r[0] = (load32_le(&key[0]))        & 0x3ffffff;
  ctx->r[1] = (load32_le(&key[3]) >> 2)   & 0x3ffff03;
  ctx->r[2] = (load32_le(&key[6]) >> 4)   & 0x3ffc0ff;
  ctx->r[3] = (load32_le(&key[9]) >> 6)   & 0x3f03fff;
  ctx->r[4] = (load32_le(&key[12]) >> 8)  & 0x00fffff;

  ctx->h[0] = ctx->h[1] = ctx->h[2] = ctx->h[3] = ctx->h[4] = 0;

  ctx->pad[0] = load32_le(&key[16]);
  ctx->pad[1] = load32_le(&key[20]);
  ctx->pad[2] = load32_le(&key[24]);
  ctx->pad[3] = load32_le(&key[28]);

  ctx->buf_len = 0;
}

/* Processes complete 16-byte blocks from `m` (nblocks of them). If
   `final` is set, the high bit is not added (the caller has already
   placed the 0x01 byte in the padded final block). */
#if defined(__x86_64__) && defined(__ELF__)
/* radix 2^26 -> 2^64 (carries normalised first so the sum fits 131 bits) and back; h4 may come
   back up to 2^27, which the radix-2^26 products absorb. */
void rktcrypto_poly1305_export64(const rktcrypto_poly1305_ctx_t *ctx, uint64_t hr[6])
{
  uint64_t l0 = ctx->h[0], l1 = ctx->h[1], l2 = ctx->h[2], l3 = ctx->h[3], l4 = ctx->h[4], c;
  unsigned __int128 acc;
  c = l0 >> 26; l0 &= 0x3ffffff; l1 += c; c = l1 >> 26; l1 &= 0x3ffffff; l2 += c;
  c = l2 >> 26; l2 &= 0x3ffffff; l3 += c; c = l3 >> 26; l3 &= 0x3ffffff; l4 += c;
  acc = (unsigned __int128)l0 | ((unsigned __int128)l1 << 26) | ((unsigned __int128)l2 << 52) |
        ((unsigned __int128)l3 << 78) | ((unsigned __int128)(l4 & 0xffffff) << 104);
  hr[0] = (uint64_t)acc; hr[1] = (uint64_t)(acc >> 64); hr[2] = l4 >> 24;
  hr[3] = (uint64_t)ctx->r[0] | ((uint64_t)ctx->r[1] << 26) | ((uint64_t)ctx->r[2] << 52);
  hr[4] = ((uint64_t)ctx->r[2] >> 12) | ((uint64_t)ctx->r[3] << 14) | ((uint64_t)ctx->r[4] << 40);
  hr[5] = hr[4] + (hr[4] >> 2);
}
void rktcrypto_poly1305_import64(rktcrypto_poly1305_ctx_t *ctx, const uint64_t hr[6])
{
  ctx->h[0] = (uint32_t)(hr[0] & 0x3ffffff);
  ctx->h[1] = (uint32_t)((hr[0] >> 26) & 0x3ffffff);
  ctx->h[2] = (uint32_t)(((hr[0] >> 52) | (hr[1] << 12)) & 0x3ffffff);
  ctx->h[3] = (uint32_t)((hr[1] >> 14) & 0x3ffffff);
  ctx->h[4] = (uint32_t)((hr[1] >> 40) | (hr[2] << 24));
}
#endif

#if defined(__x86_64__) && defined(__ELF__)
/* h = h * r mod 2^130 - 5 in radix 2^64, the same arithmetic as the MULX kernel (r = {r0, r1, s1},
   r clamped so r0, r1 < 2^60 and s1 = r1 + r1>>2 < 2^61; h2 small). Partially reduced result. */
static void poly_mul130(uint64_t h[3], const uint64_t r[3])
{
  unsigned __int128 p;
  uint64_t h0 = h[0], h1 = h[1], h2 = h[2], r0 = r[0], r1 = r[1], s1 = r[2];
  uint64_t n0, d1, d2, d3, lo, hi, t, c;
  p = (unsigned __int128)h0 * r0; n0 = (uint64_t)p; d1 = (uint64_t)(p >> 64);
  p = (unsigned __int128)h0 * r1; d2 = (uint64_t)p; d3 = (uint64_t)(p >> 64);
  p = (unsigned __int128)h1 * r0; lo = (uint64_t)p; hi = (uint64_t)(p >> 64);
  d2 += lo; c = d2 < lo; d3 += hi + c;
  p = (unsigned __int128)h1 * s1; lo = (uint64_t)p; hi = (uint64_t)(p >> 64);
  n0 += lo; c = n0 < lo; d1 += hi + c;
  t = h2 * s1; d2 += t; c = d2 < t; d3 += c;
  h2 = h2 * r0;
  d1 += d2; c = d1 < d2; d3 += h2 + c;
  t = d3 & ~(uint64_t)3; h2 = d3 & 3; d3 >>= 2; t += d3;        /* 5 * (d3 >> 2) */
  h0 = n0 + t; c = h0 < t;
  h1 = d1 + c; c = h1 < c;
  h2 += c;
  h[0] = h0; h[1] = h1; h[2] = h2;
}
/* full reduction of a partially reduced value: subtract p when h >= 2^130 - 5 */
static void poly_reduce130(uint64_t h[3])
{
  uint64_t g0, g1, g2, c;
  g0 = h[0] + 5; c = g0 < 5;
  g1 = h[1] + c; c = g1 < c;
  g2 = h[2] + c;
  if (g2 >> 2) { h[0] = g0; h[1] = g1; h[2] = g2 & 3; }
}
static void poly_to44(const uint64_t x[3], uint64_t l[3])
{
  l[0] = x[0] & 0xfffffffffffULL;
  l[1] = ((x[0] >> 44) | (x[1] << 20)) & 0xfffffffffffULL;
  l[2] = (x[1] >> 24) | (x[2] << 40);
}
/* rows 0..4: r^8 limbs and 20*limbs broadcast; rows 5..9: lane k = r^(8-k) likewise */
void rktcrypto_poly1305_ifma_table(const uint64_t r[3], uint64_t tab[80])
{
  uint64_t pw[9][3], l[3]; int k, j;
  pw[1][0] = r[0]; pw[1][1] = r[1]; pw[1][2] = 0;
  for (k = 2; k <= 8; k++) { memcpy(pw[k], pw[k - 1], 24); poly_mul130(pw[k], r); poly_reduce130(pw[k]); }
  poly_to44(pw[8], l);
  for (j = 0; j < 8; j++) { tab[j] = l[0]; tab[8 + j] = l[1]; tab[16 + j] = l[2]; tab[24 + j] = 20 * l[1]; tab[32 + j] = 20 * l[2]; }
  for (k = 0; k < 8; k++) {
    poly_to44(pw[8 - k], l);
    tab[40 + k] = l[0]; tab[48 + k] = l[1]; tab[56 + k] = l[2]; tab[64 + k] = 20 * l[1]; tab[72 + k] = 20 * l[2];
  }
}
#endif

#if defined(__x86_64__) && defined(__ELF__)
/* radix-2^26 product a*b (limbs below 2^27), partially reduced, for the AVX2 kernel's table */
static void poly26_mul(uint32_t o[5], const uint32_t a[5], const uint32_t b[5])
{
  uint64_t d0, d1, d2, d3, d4; uint32_t c;
  const uint64_t s1 = (uint64_t)b[1] * 5, s2 = (uint64_t)b[2] * 5, s3 = (uint64_t)b[3] * 5, s4 = (uint64_t)b[4] * 5;
  d0 = (uint64_t)a[0]*b[0] + a[1]*s4 + a[2]*s3 + a[3]*s2 + a[4]*s1;
  d1 = (uint64_t)a[0]*b[1] + (uint64_t)a[1]*b[0] + a[2]*s4 + a[3]*s3 + a[4]*s2;
  d2 = (uint64_t)a[0]*b[2] + (uint64_t)a[1]*b[1] + (uint64_t)a[2]*b[0] + a[3]*s4 + a[4]*s3;
  d3 = (uint64_t)a[0]*b[3] + (uint64_t)a[1]*b[2] + (uint64_t)a[2]*b[1] + (uint64_t)a[3]*b[0] + a[4]*s4;
  d4 = (uint64_t)a[0]*b[4] + (uint64_t)a[1]*b[3] + (uint64_t)a[2]*b[2] + (uint64_t)a[3]*b[1] + (uint64_t)a[4]*b[0];
  c = (uint32_t)(d0 >> 26); o[0] = (uint32_t)d0 & 0x3ffffff;
  d1 += c; c = (uint32_t)(d1 >> 26); o[1] = (uint32_t)d1 & 0x3ffffff;
  d2 += c; c = (uint32_t)(d2 >> 26); o[2] = (uint32_t)d2 & 0x3ffffff;
  d3 += c; c = (uint32_t)(d3 >> 26); o[3] = (uint32_t)d3 & 0x3ffffff;
  d4 += c; c = (uint32_t)(d4 >> 26); o[4] = (uint32_t)d4 & 0x3ffffff;
  o[0] += c * 5; c = o[0] >> 26; o[0] &= 0x3ffffff; o[1] += c;
}
/* rows 0..4: r^4 limbs broadcast; 5..8: 5 * r^4 limbs 1..4; rows 9..17: the same per lane for the
   final group, lanes in the kernel's block order (0, 2, 1, 3) -> powers (r^4, r^2, r^3, r) */
void rktcrypto_poly1305_avx2_table(const uint32_t r[5], uint64_t tab[72])
{
  uint32_t r2[5], r3[5], r4[5]; const uint32_t *pw[4]; int i, k;
  poly26_mul(r2, r, r); poly26_mul(r3, r2, r); poly26_mul(r4, r2, r2);
  pw[0] = r4; pw[1] = r2; pw[2] = r3; pw[3] = r;
  for (i = 0; i < 5; i++) for (k = 0; k < 4; k++) { tab[4*i + k] = r4[i]; tab[36 + 4*i + k] = pw[k][i]; }
  for (i = 1; i < 5; i++) for (k = 0; k < 4; k++) { tab[4*(4+i) + k] = (uint64_t)r4[i] * 5; tab[36 + 4*(4+i) + k] = (uint64_t)pw[k][i] * 5; }
}
#endif

static void poly1305_blocks(rktcrypto_poly1305_ctx_t *ctx, const unsigned char *m,
                            intptr_t bytes, uint32_t hibit)
{
  const uint32_t r0 = ctx->r[0], r1 = ctx->r[1], r2 = ctx->r[2], r3 = ctx->r[3], r4 = ctx->r[4];
  const uint32_t s1 = r1 * 5, s2 = r2 * 5, s3 = r3 * 5, s4 = r4 * 5;
  uint32_t h0 = ctx->h[0], h1 = ctx->h[1], h2 = ctx->h[2], h3 = ctx->h[3], h4 = ctx->h[4];

#if defined(__x86_64__) && defined(__ELF__)
  /* the AVX2 tier (no IFMA): four-way radix 2^26 on whole groups of four blocks */
  if (bytes >= 256 && hibit && rktcrypto_cpu_has(RKTCRYPTO_CPU_X86_AVX2) && !rktcrypto_cpu_has(RKTCRYPTO_CPU_X86_IFMA)) {
    uint64_t tab[72] __attribute__((aligned(32))), hv[5];
    intptr_t groups = bytes / 64;
    uint64_t c;
    rktcrypto_poly1305_avx2_table(ctx->r, tab);
    hv[0] = h0; hv[1] = h1; hv[2] = h2; hv[3] = h3; hv[4] = h4;
    rktcrypto_poly1305_blocks_avx2(hv, tab, m, groups);
    /* lane sums (below 2^29) back to 26-bit limbs */
    c = hv[0] >> 26; h0 = (uint32_t)hv[0] & 0x3ffffff;
    hv[1] += c; c = hv[1] >> 26; h1 = (uint32_t)hv[1] & 0x3ffffff;
    hv[2] += c; c = hv[2] >> 26; h2 = (uint32_t)hv[2] & 0x3ffffff;
    hv[3] += c; c = hv[3] >> 26; h3 = (uint32_t)hv[3] & 0x3ffffff;
    hv[4] += c; c = hv[4] >> 26; h4 = (uint32_t)hv[4] & 0x3ffffff;
    h0 += (uint32_t)c * 5; c = h0 >> 26; h0 &= 0x3ffffff; h1 += (uint32_t)c;
    ctx->h[0] = h0; ctx->h[1] = h1; ctx->h[2] = h2; ctx->h[3] = h3; ctx->h[4] = h4;
    m += groups * 64; bytes -= groups * 64;
  }
  /* rktasm/x86 kernel in radix 2^64: convert the accumulator and r, run the whole-block
     prefix, convert back (h4 may come back up to 2^27, which the radix-2^26 math absorbs). */
  if (bytes >= 64 && rktcrypto_cpu_has(RKTCRYPTO_CPU_X86_BMI2ADX)) {
    uint64_t hr[6];
    intptr_t nblk;
    rktcrypto_poly1305_export64(ctx, hr);           /* ctx->h still equals h0..h4 here */
    if (bytes >= 256 && hibit && rktcrypto_cpu_has(RKTCRYPTO_CPU_X86_IFMA)) {
      /* eight-way IFMA on whole groups of eight blocks; radix 2^64 <-> 2^44 around it */
      uint64_t tab[80] __attribute__((aligned(64))), l[3];
      unsigned __int128 x;
      intptr_t groups = bytes / 128;
      rktcrypto_poly1305_ifma_table(hr + 3, tab);
      poly_to44(hr, l);
      rktcrypto_poly1305_blocks_ifma(l, tab, m, groups);
      /* radix 2^44 lane sums (limbs below 2^48) back to radix 2^64: l0 + l1*2^44 + l2*2^88 */
      x = (unsigned __int128)l[0] + ((unsigned __int128)l[1] << 44);
      hr[0] = (uint64_t)x;
      x = (x >> 64) + ((unsigned __int128)l[2] << 24);
      hr[1] = (uint64_t)x;
      hr[2] = (uint64_t)(x >> 64);
      /* the lane sum can exceed 2^130 by a few bits; the radix-2^64 kernel needs h2 small, so
         fold the bits above 2^130 back (2^130 = 5) */
      { uint64_t top = hr[2] >> 2;
        hr[2] &= 3;
        x = (unsigned __int128)hr[0] + top * 5; hr[0] = (uint64_t)x;
        x = (x >> 64) + hr[1]; hr[1] = (uint64_t)x;
        hr[2] += (uint64_t)(x >> 64); }
      m += groups * 128; bytes -= groups * 128;
    }
    nblk = bytes / 16;
    if (nblk > 0) rktcrypto_poly1305_blocks_x86(hr, hr + 3, m, nblk, hibit ? 1 : 0);
    rktcrypto_poly1305_import64(ctx, hr);
    h0 = ctx->h[0]; h1 = ctx->h[1]; h2 = ctx->h[2]; h3 = ctx->h[3]; h4 = ctx->h[4];
    m += nblk * 16; bytes -= nblk * 16;
  }
#endif
  while (bytes >= 16) {
    uint64_t d0, d1, d2, d3, d4;
    uint32_t c;

    h0 += (load32_le(&m[0]))       & 0x3ffffff;
    h1 += (load32_le(&m[3]) >> 2)  & 0x3ffffff;
    h2 += (load32_le(&m[6]) >> 4)  & 0x3ffffff;
    h3 += (load32_le(&m[9]) >> 6)  & 0x3ffffff;
    h4 += (load32_le(&m[12]) >> 8) | hibit;

    d0 = (uint64_t)h0*r0 + (uint64_t)h1*s4 + (uint64_t)h2*s3 + (uint64_t)h3*s2 + (uint64_t)h4*s1;
    d1 = (uint64_t)h0*r1 + (uint64_t)h1*r0 + (uint64_t)h2*s4 + (uint64_t)h3*s3 + (uint64_t)h4*s2;
    d2 = (uint64_t)h0*r2 + (uint64_t)h1*r1 + (uint64_t)h2*r0 + (uint64_t)h3*s4 + (uint64_t)h4*s3;
    d3 = (uint64_t)h0*r3 + (uint64_t)h1*r2 + (uint64_t)h2*r1 + (uint64_t)h3*r0 + (uint64_t)h4*s4;
    d4 = (uint64_t)h0*r4 + (uint64_t)h1*r3 + (uint64_t)h2*r2 + (uint64_t)h3*r1 + (uint64_t)h4*r0;

    c = (uint32_t)(d0 >> 26); h0 = (uint32_t)d0 & 0x3ffffff;
    d1 += c; c = (uint32_t)(d1 >> 26); h1 = (uint32_t)d1 & 0x3ffffff;
    d2 += c; c = (uint32_t)(d2 >> 26); h2 = (uint32_t)d2 & 0x3ffffff;
    d3 += c; c = (uint32_t)(d3 >> 26); h3 = (uint32_t)d3 & 0x3ffffff;
    d4 += c; c = (uint32_t)(d4 >> 26); h4 = (uint32_t)d4 & 0x3ffffff;
    h0 += c * 5; c = h0 >> 26; h0 &= 0x3ffffff;
    h1 += c;

    m += 16;
    bytes -= 16;
  }

  ctx->h[0] = h0; ctx->h[1] = h1; ctx->h[2] = h2; ctx->h[3] = h3; ctx->h[4] = h4;
}

void rktcrypto_poly1305_update(rktcrypto_poly1305_ctx_t *ctx,
                               const unsigned char *data, intptr_t len)
{
  /* Fill and flush any buffered partial block first. */
  if (ctx->buf_len > 0) {
    intptr_t want = 16 - ctx->buf_len;
    intptr_t n = (want < len) ? want : len;
    intptr_t i;
    for (i = 0; i < n; i++) ctx->buffer[ctx->buf_len + i] = data[i];
    ctx->buf_len += n;
    data += n;
    len -= n;
    if (ctx->buf_len == 16) {
      poly1305_blocks(ctx, ctx->buffer, 16, 1u << 24);
      ctx->buf_len = 0;
    }
  }

  if (len >= 16) {
    intptr_t whole = len & ~(intptr_t)15;
    poly1305_blocks(ctx, data, whole, 1u << 24);
    data += whole;
    len -= whole;
  }

  if (len > 0) {
    intptr_t i;
    for (i = 0; i < len; i++) ctx->buffer[i] = data[i];
    ctx->buf_len = len;
  }
}

void rktcrypto_poly1305_final(rktcrypto_poly1305_ctx_t *ctx, unsigned char tag[16])
{
  uint32_t h0, h1, h2, h3, h4, c;
  uint32_t g0, g1, g2, g3, g4;
  uint32_t mask;
  uint64_t f;

  /* Process the final partial block, if any, with the 0x01 pad byte. */
  if (ctx->buf_len > 0) {
    intptr_t i = ctx->buf_len;
    ctx->buffer[i++] = 1;
    while (i < 16) ctx->buffer[i++] = 0;
    poly1305_blocks(ctx, ctx->buffer, 16, 0);   /* hibit already in the byte */
    ctx->buf_len = 0;
  }

  h0 = ctx->h[0]; h1 = ctx->h[1]; h2 = ctx->h[2]; h3 = ctx->h[3]; h4 = ctx->h[4];

  /* Fully carry h */
  c = h1 >> 26; h1 &= 0x3ffffff;
  h2 += c; c = h2 >> 26; h2 &= 0x3ffffff;
  h3 += c; c = h3 >> 26; h3 &= 0x3ffffff;
  h4 += c; c = h4 >> 26; h4 &= 0x3ffffff;
  h0 += c * 5; c = h0 >> 26; h0 &= 0x3ffffff;
  h1 += c;

  /* Compute h + -p */
  g0 = h0 + 5; c = g0 >> 26; g0 &= 0x3ffffff;
  g1 = h1 + c; c = g1 >> 26; g1 &= 0x3ffffff;
  g2 = h2 + c; c = g2 >> 26; g2 &= 0x3ffffff;
  g3 = h3 + c; c = g3 >> 26; g3 &= 0x3ffffff;
  g4 = h4 + c - (1u << 26);

  /* Select h if h < p, or h + -p if h >= p */
  mask = (g4 >> 31) - 1;   /* 0xffffffff if g4 did not borrow (h >= p) */
  g0 &= mask; g1 &= mask; g2 &= mask; g3 &= mask; g4 &= mask;
  mask = ~mask;
  h0 = (h0 & mask) | g0;
  h1 = (h1 & mask) | g1;
  h2 = (h2 & mask) | g2;
  h3 = (h3 & mask) | g3;
  h4 = (h4 & mask) | g4;

  /* Serialize h to 128 bits */
  h0 = (h0)        | (h1 << 26);
  h1 = (h1 >>  6)  | (h2 << 20);
  h2 = (h2 >> 12)  | (h3 << 14);
  h3 = (h3 >> 18)  | (h4 <<  8);

  /* mac = (h + pad) mod 2^128 */
  f = (uint64_t)h0 + ctx->pad[0];             h0 = (uint32_t)f;
  f = (uint64_t)h1 + ctx->pad[1] + (f >> 32); h1 = (uint32_t)f;
  f = (uint64_t)h2 + ctx->pad[2] + (f >> 32); h2 = (uint32_t)f;
  f = (uint64_t)h3 + ctx->pad[3] + (f >> 32); h3 = (uint32_t)f;

  tag[0] = (unsigned char)h0;  tag[1] = (unsigned char)(h0 >> 8);
  tag[2] = (unsigned char)(h0 >> 16); tag[3] = (unsigned char)(h0 >> 24);
  tag[4] = (unsigned char)h1;  tag[5] = (unsigned char)(h1 >> 8);
  tag[6] = (unsigned char)(h1 >> 16); tag[7] = (unsigned char)(h1 >> 24);
  tag[8] = (unsigned char)h2;  tag[9] = (unsigned char)(h2 >> 8);
  tag[10] = (unsigned char)(h2 >> 16); tag[11] = (unsigned char)(h2 >> 24);
  tag[12] = (unsigned char)h3; tag[13] = (unsigned char)(h3 >> 8);
  tag[14] = (unsigned char)(h3 >> 16); tag[15] = (unsigned char)(h3 >> 24);
}
