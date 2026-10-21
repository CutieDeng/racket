/* Differential + BENCH for the P-256 Montgomery multiply kernel (rktcrypto_p256_mul_x86.S):
   bit-exact against a u128 CIOS reference in this file on random and edge inputs, then the
   public P-256 API (pubkey, ECDH, ECDSA sign/verify) with the BMI2/ADX bit cleared as the
   oracle. Build (from racket/src/crypto, on BMI2+ADX hardware):
     gcc -O2 -I. -o /tmp/test_p256_x86 asm/tests/test_p256_x86.c rktcrypto_*.S rktcrypto_p256.c \
         rktcrypto_cpu.c rktcrypto_x86.c rktcrypto_sha256.c rktcrypto_drbg.c rktcrypto_entropy.c rktcrypto_ct.c ... */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <time.h>
#include "rktcrypto.h"
#include "rktcrypto_cpu.h"

void mont_mul_p256_x86(uint64_t r[4], const uint64_t a[4], const uint64_t b[4]);
void mont_sqr_p256_x86(uint64_t r[4], const uint64_t a[4]);
typedef struct { uint64_t m[4]; uint64_t n0; uint64_t rr[4]; } mont_ctx_t;
void mont_mul_x86(uint64_t r[4], const uint64_t a[4], const uint64_t b[4], const mont_ctx_t *ctx);
/* the group order n and its -n^-1 mod 2^64 */
static const uint64_t N[4] = {0xf3b9cac2fc632551ULL, 0xbce6faada7179e84ULL, 0xffffffffffffffffULL, 0xffffffff00000000ULL};
static uint64_t compute_n0(uint64_t m0)
{
  uint64_t inv = m0;
  inv *= 2 - m0 * inv; inv *= 2 - m0 * inv; inv *= 2 - m0 * inv; inv *= 2 - m0 * inv; inv *= 2 - m0 * inv;
  return (uint64_t)(0 - inv);
}
/* generic CIOS with modulus M and n0 */
static void ref_mont_mul_gen(uint64_t r[4], const uint64_t a[4], const uint64_t b[4], const uint64_t M[4], uint64_t n0)
{
  uint64_t t[6] = {0, 0, 0, 0, 0, 0}; int i, j;
  for (i = 0; i < 4; i++) {
    unsigned __int128 c = 0; uint64_t m;
    for (j = 0; j < 4; j++) { c += (unsigned __int128)t[j] + (unsigned __int128)a[i] * b[j]; t[j] = (uint64_t)c; c >>= 64; }
    c += t[4]; t[4] = (uint64_t)c; t[5] = (uint64_t)(c >> 64);
    m = t[0] * n0;
    c = 0;
    for (j = 0; j < 4; j++) { c += (unsigned __int128)t[j] + (unsigned __int128)m * M[j]; t[j] = (uint64_t)c; c >>= 64; }
    c += t[4]; t[4] = (uint64_t)c; c >>= 64; t[5] += (uint64_t)c;
    for (j = 0; j < 5; j++) t[j] = t[j + 1];
    t[5] = 0;
  }
  { uint64_t s[4]; unsigned __int128 br = 0; int k;
    for (k = 0; k < 4; k++) { unsigned __int128 x = (unsigned __int128)t[k] - M[k] - br; s[k] = (uint64_t)x; br = (x >> 64) & 1; }
    if (t[4] || !br) memcpy(r, s, 32); else memcpy(r, t, 32); }
}

static const uint64_t P[4] = {0xffffffffffffffffULL, 0x00000000ffffffffULL, 0ULL, 0xffffffff00000001ULL};
static uint64_t st = 0x9b05688c2b3e6c1fULL;
static uint64_t rnd64(void) { st = st * 6364136223846793005ULL + 1442695040888963407ULL; return st ^ (st >> 29); }
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec * 1e-9; }

/* CIOS Montgomery multiplication, R = 2^256, n0 = 1 (p = -1 mod 2^64) */
static void ref_mont_mul(uint64_t r[4], const uint64_t a[4], const uint64_t b[4])
{
  uint64_t t[6] = {0, 0, 0, 0, 0, 0}; int i, j;
  for (i = 0; i < 4; i++) {
    unsigned __int128 c = 0; uint64_t m;
    for (j = 0; j < 4; j++) { c += (unsigned __int128)t[j] + (unsigned __int128)a[i] * b[j]; t[j] = (uint64_t)c; c >>= 64; }
    c += t[4]; t[4] = (uint64_t)c; t[5] = (uint64_t)(c >> 64);
    m = t[0];
    c = 0;
    for (j = 0; j < 4; j++) { c += (unsigned __int128)t[j] + (unsigned __int128)m * P[j]; t[j] = (uint64_t)c; c >>= 64; }
    c += t[4]; t[4] = (uint64_t)c; c >>= 64; t[5] += (uint64_t)c;
    for (j = 0; j < 5; j++) t[j] = t[j + 1];
    t[5] = 0;
  }
  { uint64_t s[4]; unsigned __int128 br = 0; int k;
    for (k = 0; k < 4; k++) { unsigned __int128 x = (unsigned __int128)t[k] - P[k] - br; s[k] = (uint64_t)x; br = (x >> 64) & 1; }
    if (t[4] || !br) memcpy(r, s, 32); else memcpy(r, t, 32); }
}
static void special(uint64_t x[4], int kind)
{
  int i;
  switch (kind % 8) {
    case 0: for (i = 0; i < 4; i++) x[i] = rnd64(); x[3] &= 0xfffffffeffffffffULL; break;   /* < p (almost surely) */
    case 1: memcpy(x, P, 32); x[0] -= 1 + (rnd64() % 3); break;                                    /* p - small */
    case 2: memset(x, 0, 32); x[0] = rnd64() % 5; break;                                           /* tiny */
    case 3: memset(x, 0xff, 32); x[3] = 0xffffffff00000000ULL; break;                              /* p - 1 pattern */
    case 4: memset(x, 0, 32); x[rnd64() % 4] = 1ULL << (rnd64() % 64); break;                      /* single bit */
    case 5: for (i = 0; i < 4; i++) x[i] = 0xffffffff00000000ULL; break;
    case 6: for (i = 0; i < 4; i++) x[i] = 0x00000000ffffffffULL; break;
    default: for (i = 0; i < 4; i++) x[i] = rnd64(); x[3] = 0xffffffff00000000ULL; break;          /* near the top */
  }
}
static void kernel(int on)
{
  if (on) rktcrypto_cpu_override_features(0, 0);
  else rktcrypto_cpu_override_features(rktcrypto_cpu_features() & ~RKTCRYPTO_CPU_X86_BMI2ADX, 1);
}

int main(void)
{
  long bad = 0, tot = 0; int t, i;
  if (!rktcrypto_cpu_has(RKTCRYPTO_CPU_X86_BMI2ADX)) { printf("no BMI2/ADX\n"); return 2; }
  for (t = 0; t < 200000; t++) {
    uint64_t a[4], b[4], r1[4], r2[4];
    special(a, (int)(rnd64() % 8)); special(b, (int)(rnd64() % 8));
    if (t & 1) memcpy(b, a, 32);   /* squarings */
    ref_mont_mul(r1, a, b);
    mont_mul_p256_x86(r2, a, b);
    tot++; if (memcmp(r1, r2, 32)) { bad++; if (bad <= 5) printf("MUL MISMATCH t=%d a=%016llx.. b=%016llx..\n", t, (unsigned long long)a[3], (unsigned long long)b[3]); }
  }
  /* dedicated squaring against the reference multiply */
  for (t = 0; t < 100000; t++) {
    uint64_t a[4], r1[4], r2[4];
    special(a, (int)(rnd64() % 8));
    ref_mont_mul(r1, a, a);
    mont_sqr_p256_x86(r2, a);
    tot++; if (memcmp(r1, r2, 32)) { bad++; if (bad <= 5) printf("SQR MISMATCH t=%d a=%016llx..\n", t, (unsigned long long)a[3]); }
  }
  /* generic kernel against the generic reference, modulus n (and p through the generic path) */
  { mont_ctx_t cn, cp; memcpy(cn.m, N, 32); cn.n0 = compute_n0(N[0]); memcpy(cp.m, P, 32); cp.n0 = compute_n0(P[0]);
    for (t = 0; t < 100000; t++) {
      uint64_t a[4], b[4], r1[4], r2[4]; const mont_ctx_t *c = (t & 4) ? &cp : &cn;
      special(a, (int)(rnd64() % 8)); special(b, (int)(rnd64() % 8));
      if (c == &cn) { a[3] &= 0xfffffffeffffffffULL; b[3] &= 0xfffffffeffffffffULL; }   /* keep below n */
      if (t & 1) memcpy(b, a, 32);
      ref_mont_mul_gen(r1, a, b, c->m, c->n0);
      mont_mul_x86(r2, a, b, c);
      tot++; if (memcmp(r1, r2, 32)) { bad++; if (bad <= 5) printf("GENERIC MUL MISMATCH t=%d ctx=%s\n", t, c == &cn ? "n" : "p"); }
    } }
  /* public API: pubkey / ECDH / ECDSA with the kernel vs without */
  for (t = 0; t < 300; t++) {
    unsigned char priv[32], priv2[32], pub_a[65], pub_b[65], pub2[65], sh_a[32], sh_b[32], sig[64], msg[48]; int ra, rb;
    for (i = 0; i < 32; i++) { priv[i] = (unsigned char)rnd64(); priv2[i] = (unsigned char)rnd64(); }
    for (i = 0; i < 48; i++) msg[i] = (unsigned char)rnd64();
    priv[0] &= 0x7f; priv2[0] &= 0x7f;
    kernel(1); ra = rktcrypto_p256_pubkey(pub_a, priv);
    kernel(0); rb = rktcrypto_p256_pubkey(pub_b, priv); kernel(1);
    tot++; if (ra != 1 || rb != 1 || memcmp(pub_a, pub_b, 65)) { bad++; if (bad <= 5) printf("PUBKEY MISMATCH t=%d\n", t); continue; }
    rktcrypto_p256_pubkey(pub2, priv2);
    kernel(1); ra = rktcrypto_p256_ecdh(sh_a, priv, pub2);
    kernel(0); rb = rktcrypto_p256_ecdh(sh_b, priv, pub2); kernel(1);
    tot++; if (ra != 1 || rb != 1 || memcmp(sh_a, sh_b, 32)) { bad++; if (bad <= 5) printf("ECDH MISMATCH t=%d\n", t); continue; }
    kernel(1); ra = rktcrypto_p256_ecdsa_sign(sig, msg, 48, priv);
    kernel(0); rb = rktcrypto_p256_ecdsa_verify(sig, msg, 48, pub_a); kernel(1);
    tot++; if (ra != 1 || rb != 1) { bad++; if (bad <= 5) printf("SIGN(kernel)/VERIFY(plain) t=%d %d/%d\n", t, ra, rb); continue; }
    kernel(0); ra = rktcrypto_p256_ecdsa_sign(sig, msg, 48, priv); kernel(1);
    rb = rktcrypto_p256_ecdsa_verify(sig, msg, 48, pub_a);
    tot++; if (ra != 1 || rb != 1) { bad++; if (bad <= 5) printf("SIGN(plain)/VERIFY(kernel) t=%d %d/%d\n", t, ra, rb); continue; }
    sig[5] ^= 1;
    tot++; if (rktcrypto_p256_ecdsa_verify(sig, msg, 48, pub_a) != 0) { bad++; if (bad <= 5) printf("TAMPERED SIG ACCEPTED t=%d\n", t); }
  }
  /* BENCH: field multiplications per second and pubkey (fixed-base scalar mult) ops, kernel vs portable */
  { uint64_t a[4], b[4]; unsigned char priv[32], pub[65]; int r; double ma = 0, mb = 0, sq = 0, pa = 0, pb = 0;
    special(a, 0); special(b, 0); for (i = 0; i < 32; i++) priv[i] = (unsigned char)(i + 1);
    for (r = 0; r < 5; r++) {
      double t0, t1, v;
      t0 = now(); for (i = 0; i < 2000000; i++) mont_mul_p256_x86(a, a, b); t1 = now();
      v = 2000000.0 / (t1 - t0) / 1e6; if (v > ma) ma = v;
      t0 = now(); for (i = 0; i < 2000000; i++) ref_mont_mul(a, a, b); t1 = now();
      v = 2000000.0 / (t1 - t0) / 1e6; if (v > mb) mb = v;
      t0 = now(); for (i = 0; i < 2000000; i++) mont_sqr_p256_x86(a, a); t1 = now();
      v = 2000000.0 / (t1 - t0) / 1e6; if (v > sq) sq = v;
      kernel(1); t0 = now(); for (i = 0; i < 2000; i++) rktcrypto_p256_pubkey(pub, priv); t1 = now();
      v = 2000.0 / (t1 - t0) / 1e3; if (v > pa) pa = v;
      kernel(0); t0 = now(); for (i = 0; i < 2000; i++) rktcrypto_p256_pubkey(pub, priv); t1 = now(); kernel(1);
      v = 2000.0 / (t1 - t0) / 1e3; if (v > pb) pb = v;
    }
    printf("BENCH p256-mont-mul-x86: %.1f Mops/s\nBENCH p256-mont-sqr-x86: %.1f Mops/s\nBENCH p256-mont-mul-ref: %.1f Mops/s\nBENCH p256-pubkey-x86: %.1f kops/s\nBENCH p256-pubkey-portable: %.1f kops/s\n", ma, sq, mb, pa, pb); }
  printf("%ld/%ld mismatches\n%s\n", bad, tot, bad ? "FAIL" : "PASS");
  return bad ? 1 : 0;
}
