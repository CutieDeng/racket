/* test_mont_mul.c — differential gate for the P-256 Montgomery multiply kernels
   in rktcrypto_p256_asm.S:
     mont_mul_p256(r,a,b)      — field prime p (all point arithmetic; fp_mul/fp_sqr)
     mont_mul_asm(r,a,b,ctx)   — group order n (ECDSA scn_inv scalar ops)
   Oracle = mont_mul_portable() (the C reference Montgomery reduction) with FP/FN
   set up by p256_init(). Both are static in rktcrypto_p256.c, so we #include it
   (the two ECDSA-only externs it references — random_bytes / digest_oneshot — are
   stubbed since this harness never drives sign/verify).

   Why this file exists: these two kernels are the P-256 core multiplies but had NO
   standing differential harness (only end-to-end coverage), and mont_mul_p256 is a
   regen.sh known-drift (current asmp allocates it differently than the committed
   .S). This harness re-gates them directly so a regenerated .S is bit-exact-checked
   before it can be committed.

   Build (from racket/src/crypto):
     cc -O2 -I. -o /tmp/test_mont_mul asm/tests/test_mont_mul.c \
        rktcrypto_p256_asm.S rktcrypto_p256_hand.S
   Apple AArch64 only. Expect: both 0/200000 mismatches. */
#include <stdint.h>
#include <stdio.h>
#include <string.h>
typedef uint64_t u64;

/* ECDSA-path externs referenced (not called) by rktcrypto_p256.c — signatures
   must match rktcrypto.h. */
int rktcrypto_random_bytes(unsigned char *b, intptr_t s, intptr_t e) {
  (void)b; (void)s; (void)e; return 0;
}
int rktcrypto_digest_oneshot(int a, const unsigned char *d, intptr_t s, intptr_t e,
                             unsigned char *o, intptr_t os, intptr_t ol) {
  (void)a; (void)d; (void)s; (void)e; (void)o; (void)os; (void)ol; return 0;
}

#define main p256_c_main
#include "rktcrypto_p256.c"
#undef main

extern void mont_mul_asm(u64 r[4], const u64 a[4], const u64 b[4], const mont_ctx *);

int main(void) {
  p256_init();                       /* initialises FP (mod p) and FN (mod n) */
  u64 s = 0xf00dcafe12345678ULL, a[4], b[4], r1[4], r2[4];
  long mp = 0, mn = 0;
  #define NX() (s ^= s << 13, s ^= s >> 7, s ^= s << 17, s)
  for (long i = 0; i < 200000; i++) {
    for (int j = 0; j < 4; j++) a[j] = NX();
    for (int j = 0; j < 4; j++) b[j] = NX();
    mont_mul_p256(r1, a, b);   mont_mul_portable(r2, a, b, &FP);
    if (memcmp(r1, r2, 32)) mp++;
    mont_mul_asm(r1, a, b, &FN); mont_mul_portable(r2, a, b, &FN);
    if (memcmp(r1, r2, 32)) mn++;
  }
  printf("mont_mul_p256 vs portable [mod p]: %ld/200000 mismatches\n", mp);
  printf("mont_mul_asm  vs portable [mod n]: %ld/200000 mismatches\n", mn);
  if (mp || mn) { printf("=> FAIL\n"); return 1; }
  printf("=> ALL PASS\n");
  return 0;
}
