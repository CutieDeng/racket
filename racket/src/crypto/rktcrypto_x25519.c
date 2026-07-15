/* X25519 (RFC 7748): Diffie-Hellman on Curve25519.

   From-scratch public-domain-style implementation. Field arithmetic in
   GF(2^255 - 19) uses five 51-bit limbs; the Montgomery ladder uses a
   constant-time conditional swap, and the scalar's bits drive it
   uniformly, so the whole operation is constant-time with respect to
   secret scalars. No external code. */

#include <string.h>
#include <stdint.h>

typedef uint64_t fe[5];   /* radix 2^51 field element */

#define MASK51 0x7ffffffffffffULL

static uint64_t load64_le(const unsigned char *p)
{
  uint64_t r = 0; int i;
  for (i = 0; i < 8; i++) r |= (uint64_t)p[i] << (8 * i);
  return r;
}
static void store64_le(unsigned char *p, uint64_t v)
{
  int i;
  for (i = 0; i < 8; i++) p[i] = (unsigned char)(v >> (8 * i));
}

static void fe_0(fe h) { int i; for (i = 0; i < 5; i++) h[i] = 0; }
static void fe_1(fe h) { fe_0(h); h[0] = 1; }
static void fe_copy(fe h, const fe f) { int i; for (i = 0; i < 5; i++) h[i] = f[i]; }

static void fe_add(fe h, const fe f, const fe g)
{
  int i;
  for (i = 0; i < 5; i++) h[i] = f[i] + g[i];
}

/* h = f - g. Add 2p first to stay nonnegative; 2p = 2^256 - 38 in limbs. */
static void fe_sub(fe h, const fe f, const fe g)
{
  h[0] = f[0] + 0xfffffffffffdaULL - g[0];
  h[1] = f[1] + 0xffffffffffffeULL - g[1];
  h[2] = f[2] + 0xffffffffffffeULL - g[2];
  h[3] = f[3] + 0xffffffffffffeULL - g[3];
  h[4] = f[4] + 0xffffffffffffeULL - g[4];
}

static void fe_carry(fe h, __uint128_t r0, __uint128_t r1, __uint128_t r2,
                     __uint128_t r3, __uint128_t r4)
{
  uint64_t c;
  c = (uint64_t)(r0 >> 51); r1 += c; h[0] = (uint64_t)r0 & MASK51;
  c = (uint64_t)(r1 >> 51); r2 += c; h[1] = (uint64_t)r1 & MASK51;
  c = (uint64_t)(r2 >> 51); r3 += c; h[2] = (uint64_t)r2 & MASK51;
  c = (uint64_t)(r3 >> 51); r4 += c; h[3] = (uint64_t)r3 & MASK51;
  c = (uint64_t)(r4 >> 51); h[4] = (uint64_t)r4 & MASK51;
  h[0] += 19 * c;
  c = h[0] >> 51; h[0] &= MASK51; h[1] += c;
}

static void fe_mul(fe h, const fe f, const fe g)
{
  uint64_t f0 = f[0], f1 = f[1], f2 = f[2], f3 = f[3], f4 = f[4];
  uint64_t g0 = g[0], g1 = g[1], g2 = g[2], g3 = g[3], g4 = g[4];
  uint64_t g1_19 = 19 * g1, g2_19 = 19 * g2, g3_19 = 19 * g3, g4_19 = 19 * g4;
  __uint128_t r0, r1, r2, r3, r4;

  r0 = (__uint128_t)f0*g0 + (__uint128_t)f1*g4_19 + (__uint128_t)f2*g3_19 + (__uint128_t)f3*g2_19 + (__uint128_t)f4*g1_19;
  r1 = (__uint128_t)f0*g1 + (__uint128_t)f1*g0    + (__uint128_t)f2*g4_19 + (__uint128_t)f3*g3_19 + (__uint128_t)f4*g2_19;
  r2 = (__uint128_t)f0*g2 + (__uint128_t)f1*g1    + (__uint128_t)f2*g0    + (__uint128_t)f3*g4_19 + (__uint128_t)f4*g3_19;
  r3 = (__uint128_t)f0*g3 + (__uint128_t)f1*g2    + (__uint128_t)f2*g1    + (__uint128_t)f3*g0    + (__uint128_t)f4*g4_19;
  r4 = (__uint128_t)f0*g4 + (__uint128_t)f1*g3    + (__uint128_t)f2*g2    + (__uint128_t)f3*g1    + (__uint128_t)f4*g0;

  fe_carry(h, r0, r1, r2, r3, r4);
}

static void fe_sq(fe h, const fe f) { fe_mul(h, f, f); }

/* h = f * 121665 (the (A-2)/4 Montgomery constant). */
static void fe_mul121665(fe h, const fe f)
{
  __uint128_t r0, r1, r2, r3, r4;
  r0 = (__uint128_t)f[0] * 121665;
  r1 = (__uint128_t)f[1] * 121665;
  r2 = (__uint128_t)f[2] * 121665;
  r3 = (__uint128_t)f[3] * 121665;
  r4 = (__uint128_t)f[4] * 121665;
  fe_carry(h, r0, r1, r2, r3, r4);
}

/* z = 1/z via z^(p-2), p-2 = 2^255 - 21. Standard addition chain. */
static void fe_invert(fe out, const fe z)
{
  fe t0, t1, t2, t3;
  int i;
  fe_sq(t0, z);
  fe_sq(t1, t0); fe_sq(t1, t1);
  fe_mul(t1, z, t1);
  fe_mul(t0, t0, t1);
  fe_sq(t2, t0);
  fe_mul(t1, t1, t2);
  fe_sq(t2, t1); for (i = 1; i < 5; i++) fe_sq(t2, t2);
  fe_mul(t1, t2, t1);
  fe_sq(t2, t1); for (i = 1; i < 10; i++) fe_sq(t2, t2);
  fe_mul(t2, t2, t1);
  fe_sq(t3, t2); for (i = 1; i < 20; i++) fe_sq(t3, t3);
  fe_mul(t2, t3, t2);
  fe_sq(t2, t2); for (i = 1; i < 10; i++) fe_sq(t2, t2);
  fe_mul(t1, t2, t1);
  fe_sq(t2, t1); for (i = 1; i < 50; i++) fe_sq(t2, t2);
  fe_mul(t2, t2, t1);
  fe_sq(t3, t2); for (i = 1; i < 100; i++) fe_sq(t3, t3);
  fe_mul(t2, t3, t2);
  fe_sq(t2, t2); for (i = 1; i < 50; i++) fe_sq(t2, t2);
  fe_mul(t1, t2, t1);
  fe_sq(t1, t1); for (i = 1; i < 5; i++) fe_sq(t1, t1);
  fe_mul(out, t1, t0);
}

static void fe_frombytes(fe h, const unsigned char *s)
{
  uint64_t a0 = load64_le(s);
  uint64_t a1 = load64_le(s + 8);
  uint64_t a2 = load64_le(s + 16);
  uint64_t a3 = load64_le(s + 24);
  h[0] = a0 & MASK51;
  h[1] = ((a0 >> 51) | (a1 << 13)) & MASK51;
  h[2] = ((a1 >> 38) | (a2 << 26)) & MASK51;
  h[3] = ((a2 >> 25) | (a3 << 39)) & MASK51;
  h[4] = (a3 >> 12) & MASK51;   /* top bit ignored per RFC 7748 */
}

static void fe_tobytes(unsigned char *s, const fe h)
{
  fe t;
  uint64_t c;
  int i;
  fe_copy(t, h);
  /* Final weak reduction to a canonical value < p. */
  c = t[0] >> 51; t[0] &= MASK51; t[1] += c;
  c = t[1] >> 51; t[1] &= MASK51; t[2] += c;
  c = t[2] >> 51; t[2] &= MASK51; t[3] += c;
  c = t[3] >> 51; t[3] &= MASK51; t[4] += c;
  c = t[4] >> 51; t[4] &= MASK51; t[0] += 19 * c;
  /* Now t < 2^255 + something; conditionally subtract p twice. */
  {
    uint64_t q = (t[0] + 19) >> 51;
    q = (t[1] + q) >> 51;
    q = (t[2] + q) >> 51;
    q = (t[3] + q) >> 51;
    q = (t[4] + q) >> 51;
    t[0] += 19 * q;
    c = t[0] >> 51; t[0] &= MASK51; t[1] += c;
    c = t[1] >> 51; t[1] &= MASK51; t[2] += c;
    c = t[2] >> 51; t[2] &= MASK51; t[3] += c;
    c = t[3] >> 51; t[3] &= MASK51; t[4] += c;
    t[4] &= MASK51;
  }
  {
    uint64_t o0 = t[0] | (t[1] << 51);
    uint64_t o1 = (t[1] >> 13) | (t[2] << 38);
    uint64_t o2 = (t[2] >> 26) | (t[3] << 25);
    uint64_t o3 = (t[3] >> 39) | (t[4] << 12);
    store64_le(s, o0); store64_le(s + 8, o1);
    store64_le(s + 16, o2); store64_le(s + 24, o3);
  }
  (void)i;
}

/* Constant-time conditional swap of f and g when b == 1. */
static void fe_cswap(fe f, fe g, uint64_t b)
{
  uint64_t mask = 0 - b;
  int i;
  for (i = 0; i < 5; i++) {
    uint64_t x = mask & (f[i] ^ g[i]);
    f[i] ^= x; g[i] ^= x;
  }
}

int rktcrypto_x25519(unsigned char out[32], const unsigned char scalar[32],
                     const unsigned char point[32])
{
  unsigned char e[32];
  fe x1, x2, z2, x3, z3;
  fe A, B, C, D, DA, CB, AA, BB, E, t0, t1;
  uint64_t swap = 0;
  int pos;

  memcpy(e, scalar, 32);
  e[0] &= 248;
  e[31] &= 127;
  e[31] |= 64;

  fe_frombytes(x1, point);
  fe_1(x2);
  fe_0(z2);
  fe_copy(x3, x1);
  fe_1(z3);

  for (pos = 254; pos >= 0; pos--) {
    uint64_t b = (e[pos >> 3] >> (pos & 7)) & 1;
    swap ^= b;
    fe_cswap(x2, x3, swap);
    fe_cswap(z2, z3, swap);
    swap = b;

    fe_add(A, x2, z2);          /* A = x2 + z2 */
    fe_sub(B, x2, z2);          /* B = x2 - z2 */
    fe_add(C, x3, z3);          /* C = x3 + z3 */
    fe_sub(D, x3, z3);          /* D = x3 - z3 */
    fe_mul(DA, D, A);
    fe_mul(CB, C, B);
    fe_add(t0, DA, CB);
    fe_sub(t1, DA, CB);
    fe_sq(x3, t0);              /* x3 = (DA + CB)^2 */
    fe_sq(t1, t1);
    fe_mul(z3, x1, t1);         /* z3 = x1 * (DA - CB)^2 */
    fe_sq(AA, A);
    fe_sq(BB, B);
    fe_mul(x2, AA, BB);         /* x2 = AA * BB */
    fe_sub(E, AA, BB);
    fe_mul121665(t0, E);
    fe_add(t0, t0, AA);         /* t0 = AA + a24 * E */
    fe_mul(z2, E, t0);          /* z2 = E * (AA + a24 * E) */
  }
  fe_cswap(x2, x3, swap);
  fe_cswap(z2, z3, swap);

  fe_invert(z2, z2);
  fe_mul(x2, x2, z2);
  fe_tobytes(out, x2);

  /* Reject an all-zero output (a low-order input point). */
  {
    unsigned char acc = 0;
    int i;
    for (i = 0; i < 32; i++) acc |= out[i];
    return acc != 0;
  }
}
