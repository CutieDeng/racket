/* Classic DSA (FIPS 186-4) over caller-supplied (p, q, g) domain
   parameters, on the fixed-width bn layer. Legacy: superseded by ECDSA
   and EdDSA, provided for X.509/CMS/SSH interoperability with old
   deployments. From scratch, no external code.

   The per-message secret k is random (rejection-sampled below q) and
   inverted with Fermat's little theorem (q is prime), so the sensitive
   modular operations reuse the same constant-time-hardened Montgomery
   exponentiation the RSA path uses. */

#include "rktcrypto_private.h"
#include "rktcrypto_ffc.h"
#include "rktcrypto_bn.h"

/* z = leftmost min(bits(digest), bits(q)) bits of digest, reduced mod q
   only by the callers that need it. */
static void dsa_digest_to_z(BN *z, const unsigned char *digest, intptr_t dlen, const BN *q)
{
  int qbits = bn_bits(q);
  intptr_t take = (dlen * 8 <= (intptr_t)qbits) ? dlen : (intptr_t)((qbits + 7) / 8);
  int shift = (int)(take * 8 - qbits);
  bn_from_be(z, digest, (int)take);
  if (take * 8 > (intptr_t)qbits && shift > 0) {
    /* drop the excess low bits so exactly qbits leftmost bits remain */
    int i;
    for (i = 0; i < z->top; i++) {
      uint64_t lo = z->d[i] >> shift;
      uint64_t hi = (i + 1 < z->top) ? (z->d[i+1] << (64 - shift)) : 0;
      z->d[i] = lo | hi;
    }
    while (z->top > 0 && z->d[z->top-1] == 0) z->top--;
  }
}

/* inv = a^(q-2) mod q (q prime, a nonzero mod q) */
static void dsa_inv_mod_q(BN *inv, const BN *a, const BN *q)
{
  BN e, two;
  bn_set_u64(&two, 2);
  bn_sub(&e, q, &two);
  bn_modexp(inv, a, &e, q);
}

static void dsa_mulmod(BN *r, const BN *a, const BN *b, const BN *m)
{
  BN t;
  bn_mul(&t, a, b);
  bn_mod(r, &t, m);
}

/* random value in [1, q-1] by rejection sampling */
static int dsa_rand_mod_q(BN *k, const BN *q)
{
  int qbits = bn_bits(q);
  int nb = (qbits + 7) / 8;
  unsigned char buf[64];
  int tries;
  if (nb > (int)sizeof(buf)) return 0;
  for (tries = 0; tries < 200; tries++) {
    if (!rktcrypto_random_bytes(buf, 0, nb)) return 0;
    if (qbits % 8) buf[0] &= (unsigned char)(0xff >> (8 - qbits % 8));
    bn_from_be(k, buf, nb);
    if (!bn_is_zero(k) && bn_cmp(k, q) < 0) return 1;
  }
  return 0;
}

int rktcrypto_dsa_keygen(const unsigned char *p, intptr_t plen,
                         const unsigned char *q, intptr_t qlen,
                         const unsigned char *g, intptr_t glen,
                         unsigned char *x_out, unsigned char *y_out)
{
  BN P, Q, G, X, Y;
  bn_from_be(&P, p, (int)plen); bn_from_be(&Q, q, (int)qlen); bn_from_be(&G, g, (int)glen);
  if (bn_is_zero(&P) || bn_is_zero(&Q) || bn_is_zero(&G)) return 0;
  if (!dsa_rand_mod_q(&X, &Q)) return 0;
  bn_modexp(&Y, &G, &X, &P);
  bn_to_be(x_out, (int)qlen, &X);
  bn_to_be(y_out, (int)plen, &Y);
  return 1;
}

int rktcrypto_dsa_sign(const unsigned char *p, intptr_t plen,
                       const unsigned char *q, intptr_t qlen,
                       const unsigned char *g, intptr_t glen,
                       const unsigned char *x, intptr_t xlen,
                       const unsigned char *digest, intptr_t dlen,
                       unsigned char *r_out, unsigned char *s_out)
{
  BN P, Q, G, X, Z, K, Kinv, R, S, T;
  int tries;
  bn_from_be(&P, p, (int)plen); bn_from_be(&Q, q, (int)qlen); bn_from_be(&G, g, (int)glen);
  bn_from_be(&X, x, (int)xlen);
  if (bn_is_zero(&P) || bn_is_zero(&Q) || bn_is_zero(&G)) return 0;
  dsa_digest_to_z(&Z, digest, dlen, &Q);
  bn_mod(&Z, &Z, &Q);
  for (tries = 0; tries < 64; tries++) {
    if (!dsa_rand_mod_q(&K, &Q)) return 0;
    bn_modexp(&R, &G, &K, &P);        /* r = (g^k mod p) mod q */
    bn_mod(&R, &R, &Q);
    if (bn_is_zero(&R)) continue;
    dsa_mulmod(&S, &X, &R, &Q);       /* s = k^-1 (z + x r) mod q */
    bn_add(&S, &S, &Z);
    bn_mod(&S, &S, &Q);
    dsa_inv_mod_q(&Kinv, &K, &Q);
    dsa_mulmod(&S, &S, &Kinv, &Q);
    if (bn_is_zero(&S)) continue;
    bn_to_be(r_out, (int)qlen, &R);
    bn_to_be(s_out, (int)qlen, &S);
    /* wipe secrets */
    bn_zero(&K); bn_zero(&Kinv); bn_zero(&T);
    return 1;
  }
  return 0;
}

int rktcrypto_dsa_verify(const unsigned char *p, intptr_t plen,
                         const unsigned char *q, intptr_t qlen,
                         const unsigned char *g, intptr_t glen,
                         const unsigned char *y, intptr_t ylen,
                         const unsigned char *digest, intptr_t dlen,
                         const unsigned char *r, intptr_t rlen,
                         const unsigned char *s, intptr_t slen)
{
  BN P, Q, G, Y, Z, R, S, W, U1, U2, V;
  uint64_t n0; BN rr;
  bn_from_be(&P, p, (int)plen); bn_from_be(&Q, q, (int)qlen); bn_from_be(&G, g, (int)glen);
  bn_from_be(&Y, y, (int)ylen); bn_from_be(&R, r, (int)rlen); bn_from_be(&S, s, (int)slen);
  if (bn_is_zero(&P) || bn_is_zero(&Q) || bn_is_zero(&G)) return 0;
  if (bn_is_zero(&R) || bn_cmp(&R, &Q) >= 0) return 0;
  if (bn_is_zero(&S) || bn_cmp(&S, &Q) >= 0) return 0;
  dsa_digest_to_z(&Z, digest, dlen, &Q);
  bn_mod(&Z, &Z, &Q);
  dsa_inv_mod_q(&W, &S, &Q);          /* w = s^-1 mod q */
  dsa_mulmod(&U1, &Z, &W, &Q);
  dsa_mulmod(&U2, &R, &W, &Q);
  /* v = (g^u1 y^u2 mod p) mod q: one simultaneous double exponentiation
     (public values -> the variable-time shared-squaring path is fine) */
  bn_mont_setup(&n0, &rr, &P);
  bn_modexp2_pre(&V, &G, &U1, &Y, &U2, &P, n0, &rr);
  bn_mod(&V, &V, &Q);
  return bn_cmp(&V, &R) == 0;
}
