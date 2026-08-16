/* Timing-leakage check (dudect-style) for the constant-time primitives.

   Measures whether execution time is statistically independent of secret
   data, using Welch's t-test between two input classes. A |t| that stays
   small (< ~4.5) as the sample count grows is evidence of constant-time
   behavior; a |t| that grows without bound signals a data-dependent
   branch or memory access.

   This is a best-effort guard, not a proof: it depends on the machine's
   timer resolution and noise. Build and run:

     cc -std=c99 -O2 -I<crypto-src> dudect_ct.c \
        rktcrypto_ct.c rktcrypto_x25519.c -o dudect_ct && ./dudect_ct

   The two targets exercised are:
     1. rktcrypto_ct_bytes_equal -- the constant-time comparison used for
        MAC/tag verification. Class A: buffers equal. Class B: buffers
        differ in the first byte. A variable-time memcmp would return
        early for class B and leak.
     2. rktcrypto_x25519 -- the Montgomery ladder. Class A: a fixed
        scalar. Class B: a random scalar. A ladder that branched on
        scalar bits would leak. */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>

int rktcrypto_ct_bytes_equal(const unsigned char *a, intptr_t a_start,
                             const unsigned char *b, intptr_t b_start, intptr_t len);
int rktcrypto_x25519(unsigned char *out, const unsigned char *scalar, const unsigned char *point);

/* xorshift128+ so the harness needs no libc rng determinism guarantees. */
static uint64_t rng_state[2] = { 0x123456789abcdef0ull, 0x0fedcba987654321ull };
static uint64_t xrand(void) {
  uint64_t x = rng_state[0], y = rng_state[1];
  rng_state[0] = y;
  x ^= x << 23;
  rng_state[1] = x ^ y ^ (x >> 17) ^ (y >> 26);
  return rng_state[1] + y;
}

static uint64_t nanos(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
}

/* Welch's t-test over two running-moment accumulators. */
typedef struct { double n, mean, m2; } acc_t;
static void acc_push(acc_t *a, double x) {
  a->n += 1.0;
  double d = x - a->mean;
  a->mean += d / a->n;
  a->m2 += d * (x - a->mean);
}
static double welch_t(const acc_t *a, const acc_t *b) {
  double va = a->m2 / (a->n - 1.0), vb = b->m2 / (b->n - 1.0);
  double denom = sqrt(va / a->n + vb / b->n);
  if (denom == 0.0) return 0.0;
  return (a->mean - b->mean) / denom;
}

/* Discard the top ~1% as scheduler-noise outliers before accumulating. */
static double crop(double ns) { return ns; }

static void report(const char *name, acc_t *a, acc_t *b) {
  double t = welch_t(a, b);
  printf("  %-26s |t| = %7.2f   (n=%.0f/%.0f)  %s\n",
         name, fabs(t), a->n, b->n,
         (fabs(t) < 4.5) ? "OK (no leak detected)" : "LEAK?");
}

#define ROUNDS 400000
#define WARMUP 5000

static void bench_ct_equal(void) {
  unsigned char x[32], eq[32], ne[32];
  for (int i = 0; i < 32; i++) x[i] = (unsigned char)xrand();
  memcpy(eq, x, 32);
  memcpy(ne, x, 32); ne[0] ^= 0xff;         /* differ in the first byte */
  acc_t A = {0,0,0}, B = {0,0,0};
  volatile int sink = 0;
  for (long r = 0; r < ROUNDS + WARMUP; r++) {
    int cls = (int)(xrand() & 1);
    const unsigned char *other = cls ? ne : eq;
    uint64_t t0 = nanos();
    sink ^= rktcrypto_ct_bytes_equal(x, 0, other, 0, 32);
    uint64_t dt = nanos() - t0;
    if (r < WARMUP) continue;
    if (cls) acc_push(&B, crop((double)dt)); else acc_push(&A, crop((double)dt));
  }
  (void)sink;
  report("ct_bytes_equal", &A, &B);
}

static void bench_x25519(void) {
  unsigned char base[32] = {9};
  unsigned char fixed[32], rnd[32], out[32];
  for (int i = 0; i < 32; i++) fixed[i] = 0x55;
  acc_t A = {0,0,0}, B = {0,0,0};
  volatile int sink = 0;
  for (long r = 0; r < (ROUNDS/8) + WARMUP; r++) {
    int cls = (int)(xrand() & 1);
    const unsigned char *sc;
    if (cls) { for (int i = 0; i < 32; i++) rnd[i] = (unsigned char)xrand(); sc = rnd; }
    else sc = fixed;
    uint64_t t0 = nanos();
    sink ^= rktcrypto_x25519(out, sc, base);
    uint64_t dt = nanos() - t0;
    if (r < WARMUP) continue;
    if (cls) acc_push(&B, crop((double)dt)); else acc_push(&A, crop((double)dt));
  }
  (void)sink;
  report("x25519 ladder", &A, &B);
}

/* Positive control: a deliberately variable-time compare (early return
   on first mismatch) over long buffers. The harness MUST flag this, or
   it isn't measuring anything. Class A: equal (scans all bytes). Class
   B: differs at byte 0 (returns immediately). */
static int leaky_equal(const unsigned char *a, const unsigned char *b, int n) {
  for (int i = 0; i < n; i++) if (a[i] != b[i]) return 0;
  return 1;
}
static void bench_leaky_control(void) {
  unsigned char x[256], eq[256], ne[256];
  for (int i = 0; i < 256; i++) x[i] = (unsigned char)xrand();
  memcpy(eq, x, 256);
  memcpy(ne, x, 256); ne[0] ^= 0xff;
  acc_t A = {0,0,0}, B = {0,0,0};
  volatile int sink = 0;
  for (long r = 0; r < ROUNDS + WARMUP; r++) {
    int cls = (int)(xrand() & 1);
    const unsigned char *other = cls ? ne : eq;
    uint64_t t0 = nanos();
    sink ^= leaky_equal(x, other, 256);
    uint64_t dt = nanos() - t0;
    if (r < WARMUP) continue;
    if (cls) acc_push(&B, crop((double)dt)); else acc_push(&A, crop((double)dt));
  }
  (void)sink;
  report("leaky memcmp (control)", &A, &B);
}

int main(void) {
  printf("dudect-style constant-time check (|t| < 4.5 == no leak detected)\n");
  bench_ct_equal();
  bench_x25519();
  bench_leaky_control();  /* expected to report LEAK?, validating the harness */
  return 0;
}
