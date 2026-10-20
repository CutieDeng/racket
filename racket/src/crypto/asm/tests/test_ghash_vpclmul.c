/* Differential + BENCH for the VPCLMULQDQ GHASH kernel through rktcrypto_ghash_x86:
   the same call with the VPCLMULQDQ feature disabled (test hook) is the oracle, i.e. the
   PCLMUL intrinsics path, itself KAT-verified by the integration suite.
   Build (from racket/src/crypto, on VPCLMULQDQ + AVX-512 hardware):
     gcc -O2 -I. -o /tmp/test_ghash_vpclmul asm/tests/test_ghash_vpclmul.c rktcrypto_ghash_vpclmul.S rktcrypto_aes_ctr_vaes.S rktcrypto_x86.c rktcrypto_cpu.c */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <time.h>
#include "rktcrypto_cpu.h"
#include "rktcrypto_x86.h"

static uint64_t st = 0x2545f4914f6cdd1dULL;
static unsigned rnd(void) { st = st * 6364136223846793005ULL + 1442695040888963407ULL; return (unsigned)(st >> 33); }
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec * 1e-9; }
static unsigned char aad[4096], ct[1 << 20];

int main(void)
{
  long bad = 0, tot = 0; int t, i;
  if (!(rktcrypto_cpu_has(RKTCRYPTO_CPU_X86_VPCLMULQDQ) && rktcrypto_cpu_has(RKTCRYPTO_CPU_X86_AVX512))) { printf("no VPCLMULQDQ/AVX-512\n"); return 2; }
  for (t = 0; t < 3000; t++) {
    uint64_t h[2]; unsigned char sa[16], sb[16];
    long alen = (t & 2) ? (long)(rnd() % 700) : (long)(rnd() % 40);
    long clen = (t < 64) ? 64 * t : (t & 1) ? (long)(rnd() % 3000) : 256 + 64 * (long)(rnd() % 40);
    h[0] = ((uint64_t)rnd() << 32) ^ rnd(); h[1] = ((uint64_t)rnd() << 32) ^ rnd();
    for (i = 0; i < alen; i++) aad[i] = (unsigned char)rnd();
    for (i = 0; i < clen; i++) ct[i] = (unsigned char)rnd();
    rktcrypto_ghash_x86(h, aad, alen, ct, clen, sa);
    rktcrypto_cpu_override_features(rktcrypto_cpu_features() & ~RKTCRYPTO_CPU_X86_VPCLMULQDQ, 1);
    rktcrypto_ghash_x86(h, aad, alen, ct, clen, sb);
    rktcrypto_cpu_override_features(0, 0);
    tot++;
    if (memcmp(sa, sb, 16)) { bad++; if (bad <= 5) printf("MISMATCH t=%d alen=%ld clen=%ld\n", t, alen, clen); }
  }
  /* BENCH: GHASH over 1 MiB, best of 5, kernel path vs intrinsics path */
  { uint64_t h[2] = {0x66e94bd4ef8a2c3bULL, 0x884cfa59ca342b2eULL}; unsigned char s[16]; int r; double best_a = 0, best_b = 0;
    for (r = 0; r < 5; r++) {
      double t0 = now(); for (i = 0; i < 10; i++) rktcrypto_ghash_x86(h, aad, 0, ct, sizeof(ct), s); double t1 = now();
      double v = 10.0 * sizeof(ct) / (t1 - t0) / 1e6; if (v > best_a) best_a = v;
      rktcrypto_cpu_override_features(rktcrypto_cpu_features() & ~RKTCRYPTO_CPU_X86_VPCLMULQDQ, 1);
      t0 = now(); for (i = 0; i < 10; i++) rktcrypto_ghash_x86(h, aad, 0, ct, sizeof(ct), s); t1 = now();
      rktcrypto_cpu_override_features(0, 0);
      v = 10.0 * sizeof(ct) / (t1 - t0) / 1e6; if (v > best_b) best_b = v;
    }
    printf("BENCH ghash-vpclmul: %.0f MB/s\nBENCH ghash-pclmul: %.0f MB/s\n", best_a, best_b); }
  printf("%ld/%ld mismatches\n%s\n", bad, tot, bad ? "FAIL" : "PASS");
  return bad ? 1 : 0;
}
