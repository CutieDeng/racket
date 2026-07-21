/* Fused distribution fills over the core generators: uniform
   doubles, ziggurat normal/exponential, and Lemire bounded integers.

   From-scratch implementations. The ziggurat method follows
   Marsaglia & Tsang, "The Ziggurat Method for Generating Random
   Variables" (2000), with 256 layers and 52-bit uniforms as in
   modern practice (NumPy uses the same shape). Tables are computed
   once at first use; the computation is deterministic for a given
   libm, and the fast path (~98.5% of draws) does not touch libm at
   all. */

#include "rktrandom.h"
#include <string.h>
#include <math.h>

/*************************************************/
/* Chunked word source                           */

/* Rejection samplers consume a variable number of generator words;
   drawing them through a chunk keeps the generator's fill loop (and
   its register-resident state) as the only generator entry point.
   The chunk remainder is discarded at the end of a fill call, as
   documented in rktrandom.h. */

#define WSRC_CHUNK 512

typedef struct {
  uint64_t w[WSRC_CHUNK];
  int pos;
  int gen;
  unsigned char *state;
} wsrc;

static void wsrc_init(wsrc *s, int gen, unsigned char *state) {
  s->pos = WSRC_CHUNK;
  s->gen = gen;
  s->state = state;
}

static uint64_t wsrc_next(wsrc *s) {
  if (s->pos >= WSRC_CHUNK) {
    (void)rktrandom_fill(s->gen, s->state, (unsigned char *)s->w, 0, WSRC_CHUNK * 8);
    s->pos = 0;
  }
  return s->w[s->pos++];
}

/* Words serialized by rktrandom_fill are little-endian; reload as
   native. On little-endian targets this is the identity. */
static uint64_t load_le64(const unsigned char *p) {
  uint64_t v;
  int i;
#if defined(__LITTLE_ENDIAN__) || (defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__) \
    || defined(_M_X64) || defined(_M_ARM64) || defined(__x86_64__) || defined(__i386__)
  memcpy(&v, p, 8);
#else
  v = 0;
  for (i = 0; i < 8; i++) v |= (uint64_t)p[i] << (8 * i);
  (void)i;
#endif
  return v;
}

static void store_f64(unsigned char *p, double d) {
  memcpy(p, &d, 8);
}

#define U53_SCALE 1.11022302462515654042e-16 /* 2^-53 */

/*************************************************/
/* Uniform doubles                               */

int rktrandom_fill_f64(int gen, unsigned char *state,
                       unsigned char *buf, intptr_t start, intptr_t end) {
  unsigned char *p = buf + start;
  intptr_t len = end - start, i, n;
  if (len < 0 || (len & 7))
    return 0;
  n = len >> 3;
  /* one word per double: fill in place, then transform */
  if (!rktrandom_fill(gen, state, p, 0, len))
    return 0;
  for (i = 0; i < n; i++, p += 8)
    store_f64(p, (double)(load_le64(p) >> 11) * U53_SCALE);
  return 1;
}

/*************************************************/
/* Ziggurat tables                               */

/* 256 layers; the constants r (rightmost layer edge) and v (area
   per layer) are the standard published values for this layer
   count. Tables hold layer edges as 52-bit integer thresholds
   (kn/ke), scale factors (wn/we), and pdf values (fn/fe). */

#define ZIG_M52 4503599627370496.0 /* 2^52 */

#define ZIG_NOR_R 3.6541528853610088
#define ZIG_NOR_V 0.00492867323399

#define ZIG_EXP_R 7.69711747013104972
#define ZIG_EXP_V 0.0039496598225815571993

static uint64_t zig_kn[256], zig_ke[256];
static double zig_wn[256], zig_fn[256];
static double zig_we[256], zig_fe[256];
static volatile int zig_ready = 0;

static void zig_setup(void) {
  double dn = ZIG_NOR_R, tn = ZIG_NOR_R;
  double de = ZIG_EXP_R, te = ZIG_EXP_R;
  double q;
  int i;

  /* normal */
  q = ZIG_NOR_V / exp(-0.5 * dn * dn);
  zig_kn[0] = (uint64_t)((dn / q) * ZIG_M52);
  zig_kn[1] = 0;
  zig_wn[0] = q / ZIG_M52;
  zig_wn[255] = dn / ZIG_M52;
  zig_fn[0] = 1.0;
  zig_fn[255] = exp(-0.5 * dn * dn);
  for (i = 254; i >= 1; i--) {
    dn = sqrt(-2.0 * log(ZIG_NOR_V / dn + exp(-0.5 * dn * dn)));
    zig_kn[i + 1] = (uint64_t)((dn / tn) * ZIG_M52);
    tn = dn;
    zig_fn[i] = exp(-0.5 * dn * dn);
    zig_wn[i] = dn / ZIG_M52;
  }

  /* exponential */
  q = ZIG_EXP_V / exp(-de);
  zig_ke[0] = (uint64_t)((de / q) * ZIG_M52);
  zig_ke[1] = 0;
  zig_we[0] = q / ZIG_M52;
  zig_we[255] = de / ZIG_M52;
  zig_fe[0] = 1.0;
  zig_fe[255] = exp(-de);
  for (i = 254; i >= 1; i--) {
    de = -log(ZIG_EXP_V / de + exp(-de));
    zig_ke[i + 1] = (uint64_t)((de / te) * ZIG_M52);
    te = de;
    zig_fe[i] = exp(-de);
    zig_we[i] = de / ZIG_M52;
  }

  zig_ready = 1; /* idempotent: concurrent setup writes identical values */
}

/*************************************************/
/* Normal                                        */

static double zig_normal(wsrc *s) {
  for (;;) {
    uint64_t r = wsrc_next(s);
    int idx = (int)(r & 0xFF);
    int sign = (int)((r >> 8) & 1);
    uint64_t j = r >> 12; /* 52 bits */
    double x = (double)j * zig_wn[idx];
    if (j < zig_kn[idx])
      return sign ? -x : x;
    if (idx == 0) {
      /* tail: Marsaglia's method */
      double xx, yy;
      do {
        xx = -log(((double)(wsrc_next(s) >> 11) + 0.5) * U53_SCALE) / ZIG_NOR_R;
        yy = -log(((double)(wsrc_next(s) >> 11) + 0.5) * U53_SCALE);
      } while (yy + yy < xx * xx);
      return sign ? -(ZIG_NOR_R + xx) : (ZIG_NOR_R + xx);
    }
    {
      double u = ((double)(wsrc_next(s) >> 11)) * U53_SCALE;
      if (zig_fn[idx] + u * (zig_fn[idx - 1] - zig_fn[idx]) < exp(-0.5 * x * x))
        return sign ? -x : x;
    }
  }
}

int rktrandom_fill_normal(int gen, unsigned char *state,
                          unsigned char *buf, intptr_t start, intptr_t end) {
  unsigned char *p = buf + start;
  intptr_t len = end - start, i, n;
  wsrc s;
  if (len < 0 || (len & 7))
    return 0;
  if (!rktrandom_state_size(gen))
    return 0;
  if (!zig_ready) zig_setup();
  wsrc_init(&s, gen, state);
  n = len >> 3;
  for (i = 0; i < n; i++, p += 8)
    store_f64(p, zig_normal(&s));
  return 1;
}

/*************************************************/
/* Exponential                                   */

static double zig_exp(wsrc *s) {
  for (;;) {
    uint64_t r = wsrc_next(s);
    int idx = (int)(r & 0xFF);
    uint64_t j = r >> 12; /* 52 bits */
    double x = (double)j * zig_we[idx];
    if (j < zig_ke[idx])
      return x;
    if (idx == 0)
      return ZIG_EXP_R - log(1.0 - ((double)(wsrc_next(s) >> 11)) * U53_SCALE);
    {
      double u = ((double)(wsrc_next(s) >> 11)) * U53_SCALE;
      if (zig_fe[idx] + u * (zig_fe[idx - 1] - zig_fe[idx]) < exp(-x))
        return x;
    }
  }
}

int rktrandom_fill_exp(int gen, unsigned char *state,
                       unsigned char *buf, intptr_t start, intptr_t end) {
  unsigned char *p = buf + start;
  intptr_t len = end - start, i, n;
  wsrc s;
  if (len < 0 || (len & 7))
    return 0;
  if (!rktrandom_state_size(gen))
    return 0;
  if (!zig_ready) zig_setup();
  wsrc_init(&s, gen, state);
  n = len >> 3;
  for (i = 0; i < n; i++, p += 8)
    store_f64(p, zig_exp(&s));
  return 1;
}

/*************************************************/
/* Bounded integers (Lemire)                     */

static void mul64x64_128d(uint64_t a, uint64_t b, uint64_t *hi, uint64_t *lo) {
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

static void store_le64(unsigned char *p, uint64_t v) {
#if defined(__LITTLE_ENDIAN__) || (defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__) \
    || defined(_M_X64) || defined(_M_ARM64) || defined(__x86_64__) || defined(__i386__)
  memcpy(p, &v, 8);
#else
  int i;
  for (i = 0; i < 8; i++) p[i] = (unsigned char)(v >> (8 * i));
#endif
}

int rktrandom_fill_bounded(int gen, unsigned char *state,
                           unsigned char *buf, intptr_t start, intptr_t end,
                           intptr_t bound) {
  unsigned char *p = buf + start;
  intptr_t len = end - start, i, n;
  uint64_t b, thresh;
  wsrc s;
  if (len < 0 || (len & 7) || bound <= 0)
    return 0;
  if (!rktrandom_state_size(gen))
    return 0;
  b = (uint64_t)bound;
  /* rejection threshold: 2^64 mod b */
  thresh = (uint64_t)(-(int64_t)b) % b;
  wsrc_init(&s, gen, state);
  n = len >> 3;
  for (i = 0; i < n; i++, p += 8) {
    uint64_t hi, lo;
    for (;;) {
      mul64x64_128d(wsrc_next(&s), b, &hi, &lo);
      if (lo >= thresh)
        break;
    }
    store_le64(p, hi);
  }
  return 1;
}
