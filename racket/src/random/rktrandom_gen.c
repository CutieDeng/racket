/* Core pseudo-random generators: xoshiro256++, xoshiro256**,
   xoroshiro128++, SFC64, PCG64-DXSM, and Philox4x64-10.

   From-scratch implementations, written to be bit-exact with the
   de-facto reference implementations (Vigna's xoshiro/xoroshiro C,
   NumPy's sfc64/pcg64/philox) and validated against them by an
   offline differential harness plus the built-in known-answer
   self-test.

   State is caller-provided memory holding native-endian uint64_t
   words at 8-byte offsets; see rktrandom.h for the per-generator
   layouts. Hot paths load the state into locals once per call so
   that fill loops keep everything in registers. */

#include "rktrandom_private.h"
#include <string.h>

#define ROTL64(x, k) (((x) << (k)) | ((x) >> (64 - (k))))

static uint64_t get64(const unsigned char *state, int i) {
  uint64_t v;
  memcpy(&v, state + 8 * i, 8);
  return v;
}

static void put64(unsigned char *state, int i, uint64_t v) {
  memcpy(state + 8 * i, &v, 8);
}

/* Writes the low `n` (1..8) bytes of `v`, little-endian. */
static void put_partial_le(unsigned char *p, uint64_t v, int n) {
  int i;
  for (i = 0; i < n; i++)
    p[i] = (unsigned char)(v >> (8 * i));
}

static void put_word_le(unsigned char *p, uint64_t v) {
#if defined(__LITTLE_ENDIAN__) || (defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__) \
    || defined(_M_X64) || defined(_M_ARM64) || defined(__x86_64__) || defined(__i386__)
  memcpy(p, &v, 8);
#else
  put_partial_le(p, v, 8);
#endif
}

/*************************************************/
/* splitmix64 (seeder; Vigna's reference)        */

static uint64_t splitmix64_mix(uint64_t z) {
  z = (z ^ (z >> 30)) * (uint64_t)0xBF58476D1CE4E5B9;
  z = (z ^ (z >> 27)) * (uint64_t)0x94D049BB133111EB;
  return z ^ (z >> 31);
}

static uint64_t splitmix64_next(uint64_t *x) {
  *x += (uint64_t)0x9E3779B97F4A7C15;
  return splitmix64_mix(*x);
}

/*************************************************/
/* xoshiro256++ and xoshiro256**                 */

static uint64_t xoshiro256_step(uint64_t s[4], int plusplus) {
  uint64_t result, t;
  if (plusplus)
    result = ROTL64(s[0] + s[3], 23) + s[0];
  else
    result = ROTL64(s[1] * 5, 7) * 9;
  t = s[1] << 17;
  s[2] ^= s[0];
  s[3] ^= s[1];
  s[1] ^= s[2];
  s[0] ^= s[3];
  s[2] ^= t;
  s[3] = ROTL64(s[3], 45);
  return result;
}

/* Accumulate-and-step jump, shared by the xoshiro256 variants (they
   have the same linear engine, hence the same jump polynomials). */
static void xoshiro256_jump_poly(uint64_t s[4], const uint64_t poly[4]) {
  uint64_t j[4] = {0, 0, 0, 0};
  int i, b;
  for (i = 0; i < 4; i++)
    for (b = 0; b < 64; b++) {
      if (poly[i] & ((uint64_t)1 << b)) {
        j[0] ^= s[0]; j[1] ^= s[1]; j[2] ^= s[2]; j[3] ^= s[3];
      }
      (void)xoshiro256_step(s, 1);
    }
  s[0] = j[0]; s[1] = j[1]; s[2] = j[2]; s[3] = j[3];
}

static const uint64_t xoshiro256_jump[4] =
  {0x180ec6d33cfd0aba, 0xd5a61266f0c9392c, 0xa9582618e03fc9aa, 0x39abdc4529b1661c};
static const uint64_t xoshiro256_long_jump[4] =
  {0x76e15d3efefdcbbf, 0xc5004e441c522fb3, 0x77710069854ee241, 0x39109bb02acbe635};

/*************************************************/
/* xoroshiro128++                                */

static uint64_t xoroshiro128pp_step(uint64_t s[2]) {
  uint64_t s0 = s[0], s1 = s[1];
  uint64_t result = ROTL64(s0 + s1, 17) + s0;
  s1 ^= s0;
  s[0] = ROTL64(s0, 49) ^ s1 ^ (s1 << 21);
  s[1] = ROTL64(s1, 28);
  return result;
}

static void xoroshiro128pp_jump_poly(uint64_t s[2], const uint64_t poly[2]) {
  uint64_t j0 = 0, j1 = 0;
  int i, b;
  for (i = 0; i < 2; i++)
    for (b = 0; b < 64; b++) {
      if (poly[i] & ((uint64_t)1 << b)) {
        j0 ^= s[0]; j1 ^= s[1];
      }
      (void)xoroshiro128pp_step(s);
    }
  s[0] = j0; s[1] = j1;
}

static const uint64_t xoroshiro128pp_jump[2] =
  {0x2bd7a6a6e99c2ddc, 0x0992ccaf6a6fca05};
static const uint64_t xoroshiro128pp_long_jump[2] =
  {0x360fd5f2cf8d5d99, 0x9c6e6877736c46e3};

/*************************************************/
/* SFC64 (Doty-Humphrey; NumPy's variant)        */

static uint64_t sfc64_step(uint64_t s[4]) {
  uint64_t out = s[0] + s[1] + s[3]++;
  s[0] = s[1] ^ (s[1] >> 11);
  s[1] = s[2] + (s[2] << 3);
  s[2] = ROTL64(s[2], 24) + out;
  return out;
}

/*************************************************/
/* PCG64-DXSM (O'Neill; NumPy's default)         */

/* 128-bit state as hi/lo pairs; multiply is 128x64 by the cheap
   multiplier, so only one 64x64->128 widening multiply per step. */

#define PCG_CHEAP_MULT ((uint64_t)0xda942042e4dd58b5)

static void mul64x64_128(uint64_t a, uint64_t b, uint64_t *hi, uint64_t *lo) {
#if defined(__SIZEOF_INT128__)
  __uint128_t p = (__uint128_t)a * b;
  *hi = (uint64_t)(p >> 64);
  *lo = (uint64_t)p;
#else
  uint64_t a0 = a & 0xFFFFFFFF, a1 = a >> 32;
  uint64_t b0 = b & 0xFFFFFFFF, b1 = b >> 32;
  uint64_t w0 = a0 * b0;
  uint64_t t = a1 * b0 + (w0 >> 32);
  uint64_t w1 = (t & 0xFFFFFFFF) + a0 * b1;
  *hi = a1 * b1 + (t >> 32) + (w1 >> 32);
  *lo = a * b;
#endif
}

static void pcg64dxsm_step(uint64_t *state_hi, uint64_t *state_lo,
                           uint64_t inc_hi, uint64_t inc_lo) {
  uint64_t hi, lo;
  mul64x64_128(*state_lo, PCG_CHEAP_MULT, &hi, &lo);
  hi += *state_hi * PCG_CHEAP_MULT;
  lo += inc_lo;
  hi += inc_hi + (lo < inc_lo);
  *state_hi = hi;
  *state_lo = lo;
}

/* DXSM output of the pre-iterated state. */
static uint64_t pcg64dxsm_output(uint64_t hi, uint64_t lo) {
  lo |= 1;
  hi ^= hi >> 32;
  hi *= PCG_CHEAP_MULT;
  hi ^= hi >> 48;
  hi *= lo;
  return hi;
}

/*************************************************/
/* Philox4x64-10 (Salmon et al., Random123)      */

#define PHILOX_M0 ((uint64_t)0xD2E7470EE14C6C93)
#define PHILOX_M1 ((uint64_t)0xCA5A826395121157)
#define PHILOX_W0 ((uint64_t)0x9E3779B97F4A7C15)
#define PHILOX_W1 ((uint64_t)0xBB67AE8584CAA73B)

static void philox4x64_block(const uint64_t ctr[4], const uint64_t key[2],
                             uint64_t out[4]) {
  uint64_t v0 = ctr[0], v1 = ctr[1], v2 = ctr[2], v3 = ctr[3];
  uint64_t k0 = key[0], k1 = key[1];
  int r;
  for (r = 0; r < 10; r++) {
    uint64_t hi0, lo0, hi1, lo1, t1, t3;
    if (r != 0) { k0 += PHILOX_W0; k1 += PHILOX_W1; }
    mul64x64_128(PHILOX_M0, v0, &hi0, &lo0);
    mul64x64_128(PHILOX_M1, v2, &hi1, &lo1);
    t1 = v1; t3 = v3;
    v0 = hi1 ^ t1 ^ k0;
    v1 = lo1;
    v2 = hi0 ^ t3 ^ k1;
    v3 = lo0;
  }
  out[0] = v0; out[1] = v1; out[2] = v2; out[3] = v3;
}

static void philox_ctr_inc(uint64_t ctr[4]) {
  if (++ctr[0] == 0)
    if (++ctr[1] == 0)
      if (++ctr[2] == 0)
        ++ctr[3];
}

/* State words: 0..3 ctr, 4..5 key, 6..9 buffer, 10 buffer position.
   The buffered semantics (pre-increment counter, refill of 4)
   reproduce NumPy's next64 stream exactly. */
#define PHILOX_CTR 0
#define PHILOX_KEY 4
#define PHILOX_BUF 6
#define PHILOX_POS 10

/*************************************************/
/* Dispatch                                      */

int rktrandom_state_size(int gen) {
  switch (gen) {
    case RKTRANDOM_XOSHIRO256PP:
    case RKTRANDOM_XOSHIRO256SS: return 32;
    case RKTRANDOM_XOROSHIRO128PP: return 16;
    case RKTRANDOM_SFC64: return 32;
    case RKTRANDOM_PCG64DXSM: return 32;
    case RKTRANDOM_PHILOX4X64: return 88;
    default: return 0;
  }
}

static int do_init(int gen, unsigned char *state,
                   const unsigned char *seed, intptr_t seed_start,
                   uint64_t seq) {
  uint64_t sd[4], x;
  int i;
  for (i = 0; i < 4; i++)
    sd[i] = get64(seed + seed_start, i);

  /* Decorrelate the stream selector before mixing it in, so that
     adjacent `seq` values do not yield related splitmix positions. */
  x = sd[0] ^ splitmix64_mix(seq + (uint64_t)0x9E3779B97F4A7C15);

  switch (gen) {
    case RKTRANDOM_XOSHIRO256PP:
    case RKTRANDOM_XOSHIRO256SS:
    case RKTRANDOM_SFC64: {
      uint64_t s0, s1, s2, s3;
      s0 = sd[1] ^ splitmix64_next(&x);
      s1 = sd[2] ^ splitmix64_next(&x);
      s2 = sd[3] ^ splitmix64_next(&x);
      s3 = splitmix64_next(&x);
      if (gen == RKTRANDOM_SFC64) {
        /* a b c counter=1, then discard 12 warm-up outputs, as NumPy
           seeds SFC64. */
        uint64_t s[4];
        s[0] = s0; s[1] = s1; s[2] = s2; s[3] = 1;
        for (i = 0; i < 12; i++) (void)sfc64_step(s);
        for (i = 0; i < 4; i++) put64(state, i, s[i]);
      } else {
        if ((s0 | s1 | s2 | s3) == 0) s0 = 1; /* never all-zero */
        put64(state, 0, s0); put64(state, 1, s1);
        put64(state, 2, s2); put64(state, 3, s3);
      }
      return 1;
    }
    case RKTRANDOM_XOROSHIRO128PP: {
      uint64_t s0 = sd[1] ^ splitmix64_next(&x);
      uint64_t s1 = sd[2] ^ splitmix64_next(&x);
      if ((s0 | s1) == 0) s0 = 1;
      put64(state, 0, s0); put64(state, 1, s1);
      return 1;
    }
    case RKTRANDOM_PCG64DXSM: {
      /* pcg_cm_srandom_r with initstate from the seed material and
         initseq = seq directly: distinct seq => distinct odd
         increment => a mathematically distinct stream. */
      uint64_t hi = 0, lo = 0;
      uint64_t inc_hi = seq >> 63, inc_lo = (seq << 1) | 1;
      uint64_t init_hi = sd[1] ^ splitmix64_next(&x);
      uint64_t init_lo = sd[2] ^ splitmix64_next(&x);
      pcg64dxsm_step(&hi, &lo, inc_hi, inc_lo);
      lo += init_lo;
      hi += init_hi + (lo < init_lo);
      pcg64dxsm_step(&hi, &lo, inc_hi, inc_lo);
      put64(state, 0, hi); put64(state, 1, lo);
      put64(state, 2, inc_hi); put64(state, 3, inc_lo);
      return 1;
    }
    case RKTRANDOM_PHILOX4X64: {
      /* Key from the seed material; seq lands in the top counter
         word, giving 2^128-block-separated streams. */
      put64(state, PHILOX_CTR + 0, 0);
      put64(state, PHILOX_CTR + 1, 0);
      put64(state, PHILOX_CTR + 2, 0);
      put64(state, PHILOX_CTR + 3, seq);
      put64(state, PHILOX_KEY + 0, sd[1] ^ splitmix64_next(&x));
      put64(state, PHILOX_KEY + 1, sd[2] ^ splitmix64_next(&x));
      put64(state, PHILOX_POS, 4); /* buffer empty */
      return 1;
    }
    default:
      return 0;
  }
}

int rktrandom_init(int gen, unsigned char *state,
                   const unsigned char *seed, intptr_t seed_start,
                   intptr_t seq) {
  return do_init(gen, state, seed, seed_start, (uint64_t)seq);
}

int rktrandom_init_u64(int gen, unsigned char *state, uint64_t seed, uint64_t seq) {
  unsigned char sd[32];
  uint64_t x = seed;
  put64(sd, 0, splitmix64_next(&x));
  put64(sd, 1, splitmix64_next(&x));
  put64(sd, 2, splitmix64_next(&x));
  put64(sd, 3, splitmix64_next(&x));
  return do_init(gen, state, sd, 0, seq);
}

int rktrandom_init_int(int gen, unsigned char *state, intptr_t seed, intptr_t seq) {
  return rktrandom_init_u64(gen, state, (uint64_t)seed, (uint64_t)seq);
}

uint64_t rktrandom_next64(int gen, unsigned char *state) {
  switch (gen) {
    case RKTRANDOM_XOSHIRO256PP:
    case RKTRANDOM_XOSHIRO256SS: {
      uint64_t s[4], r;
      int i;
      for (i = 0; i < 4; i++) s[i] = get64(state, i);
      r = xoshiro256_step(s, gen == RKTRANDOM_XOSHIRO256PP);
      for (i = 0; i < 4; i++) put64(state, i, s[i]);
      return r;
    }
    case RKTRANDOM_XOROSHIRO128PP: {
      uint64_t s[2], r;
      s[0] = get64(state, 0); s[1] = get64(state, 1);
      r = xoroshiro128pp_step(s);
      put64(state, 0, s[0]); put64(state, 1, s[1]);
      return r;
    }
    case RKTRANDOM_SFC64: {
      uint64_t s[4], r;
      int i;
      for (i = 0; i < 4; i++) s[i] = get64(state, i);
      r = sfc64_step(s);
      for (i = 0; i < 4; i++) put64(state, i, s[i]);
      return r;
    }
    case RKTRANDOM_PCG64DXSM: {
      uint64_t hi = get64(state, 0), lo = get64(state, 1);
      uint64_t r = pcg64dxsm_output(hi, lo);
      pcg64dxsm_step(&hi, &lo, get64(state, 2), get64(state, 3));
      put64(state, 0, hi); put64(state, 1, lo);
      return r;
    }
    case RKTRANDOM_PHILOX4X64: {
      uint64_t pos = get64(state, PHILOX_POS);
      uint64_t ctr[4], key[2], out[4];
      int i;
      if (pos < 4) {
        put64(state, PHILOX_POS, pos + 1);
        return get64(state, PHILOX_BUF + (int)pos);
      }
      for (i = 0; i < 4; i++) ctr[i] = get64(state, PHILOX_CTR + i);
      key[0] = get64(state, PHILOX_KEY + 0);
      key[1] = get64(state, PHILOX_KEY + 1);
      philox_ctr_inc(ctr);
      philox4x64_block(ctr, key, out);
      for (i = 0; i < 4; i++) {
        put64(state, PHILOX_CTR + i, ctr[i]);
        put64(state, PHILOX_BUF + i, out[i]);
      }
      put64(state, PHILOX_POS, 1);
      return out[0];
    }
    default:
      return 0;
  }
}

/* Bulk fill: whole words then a truncated final word. Each case
   keeps the generator state in locals across the loop. */
int rktrandom_fill(int gen, unsigned char *state,
                   unsigned char *buf, intptr_t start, intptr_t end) {
  unsigned char *p = buf + start;
  intptr_t len = end - start;
  intptr_t nwords = len >> 3;
  int tail = (int)(len & 7);
  intptr_t w;

  if (len <= 0)
    return (len == 0) ? 1 : 0;

  switch (gen) {
    /* The two xoshiro256 loops are written out separately so the
       scrambler selection constant-folds; a shared loop with a
       runtime flag costs ~25% throughput. */
    case RKTRANDOM_XOSHIRO256PP: {
      uint64_t s[4];
      int i;
      for (i = 0; i < 4; i++) s[i] = get64(state, i);
      for (w = 0; w < nwords; w++, p += 8)
        put_word_le(p, xoshiro256_step(s, 1));
      if (tail)
        put_partial_le(p, xoshiro256_step(s, 1), tail);
      for (i = 0; i < 4; i++) put64(state, i, s[i]);
      return 1;
    }
    case RKTRANDOM_XOSHIRO256SS: {
      uint64_t s[4];
      int i;
      for (i = 0; i < 4; i++) s[i] = get64(state, i);
      for (w = 0; w < nwords; w++, p += 8)
        put_word_le(p, xoshiro256_step(s, 0));
      if (tail)
        put_partial_le(p, xoshiro256_step(s, 0), tail);
      for (i = 0; i < 4; i++) put64(state, i, s[i]);
      return 1;
    }
    case RKTRANDOM_XOROSHIRO128PP: {
      uint64_t s[2];
      s[0] = get64(state, 0); s[1] = get64(state, 1);
      for (w = 0; w < nwords; w++, p += 8)
        put_word_le(p, xoroshiro128pp_step(s));
      if (tail)
        put_partial_le(p, xoroshiro128pp_step(s), tail);
      put64(state, 0, s[0]); put64(state, 1, s[1]);
      return 1;
    }
    case RKTRANDOM_SFC64: {
      uint64_t s[4];
      int i;
      for (i = 0; i < 4; i++) s[i] = get64(state, i);
      for (w = 0; w < nwords; w++, p += 8)
        put_word_le(p, sfc64_step(s));
      if (tail)
        put_partial_le(p, sfc64_step(s), tail);
      for (i = 0; i < 4; i++) put64(state, i, s[i]);
      return 1;
    }
    case RKTRANDOM_PCG64DXSM: {
      uint64_t hi = get64(state, 0), lo = get64(state, 1);
      uint64_t inc_hi = get64(state, 2), inc_lo = get64(state, 3);
      for (w = 0; w < nwords; w++, p += 8) {
        put_word_le(p, pcg64dxsm_output(hi, lo));
        pcg64dxsm_step(&hi, &lo, inc_hi, inc_lo);
      }
      if (tail) {
        put_partial_le(p, pcg64dxsm_output(hi, lo), tail);
        pcg64dxsm_step(&hi, &lo, inc_hi, inc_lo);
      }
      put64(state, 0, hi); put64(state, 1, lo);
      return 1;
    }
    case RKTRANDOM_PHILOX4X64: {
      uint64_t ctr[4], key[2], out[4];
      uint64_t pos = get64(state, PHILOX_POS);
      int i;
      for (i = 0; i < 4; i++) ctr[i] = get64(state, PHILOX_CTR + i);
      key[0] = get64(state, PHILOX_KEY + 0);
      key[1] = get64(state, PHILOX_KEY + 1);
      /* Drain any buffered words first to stay stream-exact. */
      while (nwords > 0 && pos < 4) {
        put_word_le(p, get64(state, PHILOX_BUF + (int)pos));
        pos++; p += 8; nwords--;
      }
      /* Whole blocks straight into the output. */
      while (nwords >= 4) {
        philox_ctr_inc(ctr);
        philox4x64_block(ctr, key, out);
        for (i = 0; i < 4; i++, p += 8) put_word_le(p, out[i]);
        nwords -= 4;
      }
      /* Final partial block (plus tail bytes) goes through the
         buffer so the leftover words are not lost. */
      if (nwords > 0 || tail) {
        if (pos >= 4) {
          philox_ctr_inc(ctr);
          philox4x64_block(ctr, key, out);
          for (i = 0; i < 4; i++) put64(state, PHILOX_BUF + i, out[i]);
          pos = 0;
        }
        while (nwords > 0) {
          if (pos >= 4) {
            philox_ctr_inc(ctr);
            philox4x64_block(ctr, key, out);
            for (i = 0; i < 4; i++) put64(state, PHILOX_BUF + i, out[i]);
            pos = 0;
          }
          put_word_le(p, get64(state, PHILOX_BUF + (int)pos));
          pos++; p += 8; nwords--;
        }
        if (tail) {
          if (pos >= 4) {
            philox_ctr_inc(ctr);
            philox4x64_block(ctr, key, out);
            for (i = 0; i < 4; i++) put64(state, PHILOX_BUF + i, out[i]);
            pos = 0;
          }
          put_partial_le(p, get64(state, PHILOX_BUF + (int)pos), tail);
          pos++;
        }
      }
      for (i = 0; i < 4; i++) put64(state, PHILOX_CTR + i, ctr[i]);
      put64(state, PHILOX_POS, pos);
      return 1;
    }
    default:
      return 0;
  }
}

int rktrandom_jump(int gen, unsigned char *state) {
  switch (gen) {
    case RKTRANDOM_XOSHIRO256PP:
    case RKTRANDOM_XOSHIRO256SS: {
      uint64_t s[4];
      int i;
      for (i = 0; i < 4; i++) s[i] = get64(state, i);
      xoshiro256_jump_poly(s, xoshiro256_jump);
      for (i = 0; i < 4; i++) put64(state, i, s[i]);
      return 1;
    }
    case RKTRANDOM_XOROSHIRO128PP: {
      uint64_t s[2];
      s[0] = get64(state, 0); s[1] = get64(state, 1);
      xoroshiro128pp_jump_poly(s, xoroshiro128pp_jump);
      put64(state, 0, s[0]); put64(state, 1, s[1]);
      return 1;
    }
    case RKTRANDOM_PCG64DXSM: {
      /* Advance by 2^64 steps: fast exponentiation of the LCG map
         (Brown, "Random Number Generation with Arbitrary Stride"):
         for delta = 2^64, square the (mult,inc) affine map 64
         times. */
      uint64_t hi = get64(state, 0), lo = get64(state, 1);
      uint64_t inc_hi = get64(state, 2), inc_lo = get64(state, 3);
      /* affine map acc: x -> m*x + a, starting as one step */
      uint64_t m_hi = 0, m_lo = PCG_CHEAP_MULT;
      uint64_t a_hi = inc_hi, a_lo = inc_lo;
      int i;
      for (i = 0; i < 64; i++) {
        /* a = (m+1)*a; m = m*m, all mod 2^128, m 128x128 via parts */
        uint64_t t_hi, t_lo, u_hi, u_lo;
        /* u = m*a */
        mul64x64_128(m_lo, a_lo, &u_hi, &u_lo);
        u_hi += m_lo * a_hi + m_hi * a_lo;
        /* a = u + a */
        a_lo = u_lo + a_lo;
        a_hi = u_hi + a_hi + (a_lo < u_lo);
        /* m = m*m */
        mul64x64_128(m_lo, m_lo, &t_hi, &t_lo);
        t_hi += 2 * m_hi * m_lo;
        m_hi = t_hi; m_lo = t_lo;
      }
      {
        uint64_t u_hi, u_lo;
        mul64x64_128(m_lo, lo, &u_hi, &u_lo);
        u_hi += m_lo * hi + m_hi * lo;
        lo = u_lo + a_lo;
        hi = u_hi + a_hi + (lo < u_lo);
      }
      put64(state, 0, hi); put64(state, 1, lo);
      return 1;
    }
    case RKTRANDOM_PHILOX4X64: {
      /* 2^64 counter blocks: bump ctr[1] (with carry). */
      uint64_t c1 = get64(state, PHILOX_CTR + 1) + 1;
      put64(state, PHILOX_CTR + 1, c1);
      if (c1 == 0) {
        uint64_t c2 = get64(state, PHILOX_CTR + 2) + 1;
        put64(state, PHILOX_CTR + 2, c2);
        if (c2 == 0)
          put64(state, PHILOX_CTR + 3, get64(state, PHILOX_CTR + 3) + 1);
      }
      return 1;
    }
    default:
      return 0;
  }
}

int rktrandom_long_jump(int gen, unsigned char *state) {
  switch (gen) {
    case RKTRANDOM_XOSHIRO256PP:
    case RKTRANDOM_XOSHIRO256SS: {
      uint64_t s[4];
      int i;
      for (i = 0; i < 4; i++) s[i] = get64(state, i);
      xoshiro256_jump_poly(s, xoshiro256_long_jump);
      for (i = 0; i < 4; i++) put64(state, i, s[i]);
      return 1;
    }
    case RKTRANDOM_XOROSHIRO128PP: {
      uint64_t s[2];
      s[0] = get64(state, 0); s[1] = get64(state, 1);
      xoroshiro128pp_jump_poly(s, xoroshiro128pp_long_jump);
      put64(state, 0, s[0]); put64(state, 1, s[1]);
      return 1;
    }
    default:
      return 0;
  }
}
