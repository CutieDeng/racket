/* Differential + BENCH for the fused ChaCha20-Poly1305 paths (rktcrypto_chacha20poly1305_{x86,avx2,ssse3}.S
   through rktcrypto_chacha20poly1305_fused) against the same AEAD with BMI2/ADX cleared on each tier
   (its two-pass path; RFC 8439 checked by the integration suite).
   Build (from racket/src/crypto, on AVX-512 + BMI2/ADX hardware):
     gcc -O2 -I. -o /tmp/test_chacha20poly1305_x86 asm/tests/test_chacha20poly1305_x86.c rktcrypto_*.S \
         rktcrypto_poly1305.c rktcrypto_chacha20.c rktcrypto_cpu.c rktcrypto_x86.c rktcrypto_aead.c \
         rktcrypto_gcm.c rktcrypto_aes_modes.c rktcrypto_ccm.c rktcrypto_ct.c */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <time.h>
#include "rktcrypto.h"
#include "rktcrypto_cpu.h"
#include "rktcrypto_cipher.h"
#define CP RKTCRYPTO_AEAD_CHACHA20_POLY1305

static uint64_t st = 0x5be0cd19137e2179ULL;
static unsigned rnd(void) { st = st * 6364136223846793005ULL + 1442695040888963407ULL; return (unsigned)(st >> 33); }
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec * 1e-9; }
#define MAXLEN (1 << 20)
static unsigned char pt[MAXLEN + 64], cta[MAXLEN + 64], ctb[MAXLEN + 64], pa[MAXLEN + 64], pb[MAXLEN + 64], aad[512], buf[MAXLEN + 64];

/* tier 3 = AVX-512 fused, 2 = AVX2 fused (AVX-512 cleared), 1 = SSSE3 fused (AVX2 cleared too);
   fused(0) clears BMI2/ADX as well, which leaves the tier's two-pass path as the oracle */
static int tier = 3;
static unsigned base;   /* the hardware's features, read before any override (overrides are visible through rktcrypto_cpu_features) */
static void fused(int on)
{
  unsigned f = base;
  if (tier <= 2) f &= ~RKTCRYPTO_CPU_X86_AVX512;
  if (tier <= 1) f &= ~RKTCRYPTO_CPU_X86_AVX2;
  if (!on) f &= ~RKTCRYPTO_CPU_X86_BMI2ADX;
  rktcrypto_cpu_override_features(f, 1);
}

int main(void)
{
  long bad = 0, tot = 0; int t, i;
  base = rktcrypto_cpu_features();
  if (!(rktcrypto_cpu_has(RKTCRYPTO_CPU_X86_AVX512) && rktcrypto_cpu_has(RKTCRYPTO_CPU_X86_BMI2ADX))) { printf("no AVX-512/BMI2-ADX\n"); return 2; }
  for (t = 0; t < 1800; t++) {
    unsigned char key[32], nonce[12]; int ra, rb;
    tier = 3 - t % 3;
    long alen = (t & 2) ? (long)(rnd() % 400) : (long)(rnd() % 20);
    long len = (t < 24) ? 1024 * t : (t & 1) ? (long)(rnd() % 12000) : 1024 * (long)(rnd() % 10) + ((rnd() % 3) ? (long)(rnd() % 1024) : 0);
    for (i = 0; i < 32; i++) key[i] = (unsigned char)rnd();
    for (i = 0; i < 12; i++) nonce[i] = (unsigned char)rnd();
    for (i = 0; i < alen; i++) aad[i] = (unsigned char)rnd();
    for (i = 0; i < len; i++) pt[i] = (unsigned char)rnd();
    fused(1); ra = rktcrypto_aead_seal(CP, key, 32, nonce, 12, aad, 0, alen, pt, 0, len, cta, 0);
    fused(0); rb = rktcrypto_aead_seal(CP, key, 32, nonce, 12, aad, 0, alen, pt, 0, len, ctb, 0); fused(1);
    tot++; if (ra != 1 || rb != 1 || memcmp(cta, ctb, len + 16)) { bad++; if (bad <= 5) printf("SEAL MISMATCH t=%d alen=%ld len=%ld\n", t, alen, len); continue; }
    fused(1); ra = rktcrypto_aead_open(CP, key, 32, nonce, 12, aad, 0, alen, cta, 0, len + 16, pa, 0);
    fused(0); rb = rktcrypto_aead_open(CP, key, 32, nonce, 12, aad, 0, alen, cta, 0, len + 16, pb, 0); fused(1);
    tot++; if (ra != 1 || rb != 1 || memcmp(pa, pt, len) || memcmp(pb, pt, len)) { bad++; if (bad <= 5) printf("OPEN MISMATCH t=%d len=%ld (%d/%d)\n", t, len, ra, rb); continue; }
    memcpy(buf, pt, len);
    ra = rktcrypto_aead_seal(CP, key, 32, nonce, 12, aad, 0, alen, buf, 0, len, buf, 0);
    tot++; if (ra != 1 || memcmp(buf, cta, len + 16)) { bad++; if (bad <= 5) printf("INPLACE SEAL MISMATCH t=%d len=%ld\n", t, len); continue; }
    ra = rktcrypto_aead_open(CP, key, 32, nonce, 12, aad, 0, alen, buf, 0, len + 16, buf, 0);
    tot++; if (ra != 1 || memcmp(buf, pt, len)) { bad++; if (bad <= 5) printf("INPLACE OPEN MISMATCH t=%d len=%ld\n", t, len); continue; }
    { long pos = (long)(rnd() % (unsigned)(len + 16)); int wiped = 1;
      memcpy(buf, cta, len + 16); buf[pos] ^= 0x20;
      memset(pa, 0x5a, len);
      ra = rktcrypto_aead_open(CP, key, 32, nonce, 12, aad, 0, alen, buf, 0, len + 16, pa, 0);
      for (i = 0; i < len; i++) if (pa[i] != 0) { wiped = 0; break; }
      tot++; if (ra != 0 || !wiped) { bad++; if (bad <= 5) printf("TAMPER t=%d len=%ld pos=%ld ra=%d wiped=%d\n", t, len, pos, ra, wiped); } }
  }
  for (tier = 3; tier >= 1; tier--)
  { unsigned char key[32] = {1, 2, 3}, nonce[12] = {4, 5, 6}; long sizes[2] = {16384, MAXLEN}; int s;
    for (s = 0; s < 2; s++) {
      long n = sizes[s]; int reps = (int)(MAXLEN / n) * 2, r; double best_a = 0, best_b = 0;
      for (r = 0; r < 5; r++) {
        double t0, t1, v;
        fused(1); t0 = now(); for (i = 0; i < reps; i++) rktcrypto_aead_seal(CP, key, 32, nonce, 12, aad, 0, 0, pt, 0, n, cta, 0); t1 = now();
        v = (double)reps * n / (t1 - t0) / 1e6; if (v > best_a) best_a = v;
        fused(0); t0 = now(); for (i = 0; i < reps / 2 + 1; i++) rktcrypto_aead_seal(CP, key, 32, nonce, 12, aad, 0, 0, pt, 0, n, ctb, 0); t1 = now(); fused(1);
        v = (double)(reps / 2 + 1) * n / (t1 - t0) / 1e6; if (v > best_b) best_b = v;
      }
      printf("BENCH chacha20-poly1305-seal-%ldk-fused-tier%d: %.0f MB/s\nBENCH chacha20-poly1305-seal-%ldk-twopass-tier%d: %.0f MB/s\n", n / 1024, tier, best_a, n / 1024, tier, best_b);
    } }
  printf("%ld/%ld mismatches\n%s\n", bad, tot, bad ? "FAIL" : "PASS");
  return bad ? 1 : 0;
}
