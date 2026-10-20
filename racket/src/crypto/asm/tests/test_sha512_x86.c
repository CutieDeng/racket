/* Differential + KAT + BENCH for the SHA-512 kernel (rktcrypto_sha512_x86.S) through the core API:
   the same hashing with the BMI2/ADX bit cleared is the oracle (the portable transform, checked by
   the integration suite against FIPS 180-4). Build (from racket/src/crypto, on BMI2 hardware):
     gcc -O2 -I. -o /tmp/test_sha512_x86 asm/tests/test_sha512_x86.c rktcrypto_*.S rktcrypto_sha512.c rktcrypto_cpu.c rktcrypto_x86.c */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <time.h>
#include "rktcrypto_cpu.h"
#include "rktcrypto_digest.h"

static uint64_t st = 0x510e527fade682d1ULL;
static unsigned rnd(void) { st = st * 6364136223846793005ULL + 1442695040888963407ULL; return (unsigned)(st >> 33); }
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec * 1e-9; }
#define MAXLEN (1 << 20)
static unsigned char msg[MAXLEN + 64];

static void kernel(int on)
{
  if (on) rktcrypto_cpu_override_features(0, 0);
  else rktcrypto_cpu_override_features(rktcrypto_cpu_features() & ~RKTCRYPTO_CPU_X86_BMI2ADX, 1);
}
static void hash(const uint64_t *iv, long len, unsigned seed, unsigned char out[64])
{
  rktcrypto_sha512_ctx_t ctx; long pos = 0; uint64_t s = seed;
  rktcrypto_sha512_core_init(&ctx, iv);
  while (pos < len) {
    long n; s = s * 6364136223846793005ULL + 1; n = (long)((s >> 33) % 900); if (n > len - pos) n = len - pos;
    rktcrypto_sha512_core_update(&ctx, msg + pos, n); pos += n;
  }
  rktcrypto_sha512_core_final(&ctx, out, 64);
}

int main(void)
{
  long bad = 0, tot = 0; int t, i;
  if (!rktcrypto_cpu_has(RKTCRYPTO_CPU_X86_BMI2ADX)) { printf("no BMI2/ADX\n"); return 2; }
  for (t = 0; t < 3000; t++) {
    unsigned char a[64], b[64]; unsigned seed = rnd();
    long len = (t < 40) ? 128 * t : (t & 1) ? (long)(rnd() % 5000) : 128 * (long)(rnd() % 30) + ((rnd() % 3) ? (long)(rnd() % 128) : 0);
    const uint64_t *iv = (t % 3 == 0) ? rktcrypto_sha384_iv : rktcrypto_sha512_iv;
    for (i = 0; i < len; i++) msg[i] = (unsigned char)rnd();
    kernel(1); hash(iv, len, seed, a);
    kernel(0); hash(iv, len, seed, b); kernel(1);
    tot++; if (memcmp(a, b, 64)) { bad++; if (bad <= 5) printf("HASH MISMATCH t=%d len=%ld\n", t, len); }
  }
  /* FIPS 180-4 SHA-512("abc") */
  { static const unsigned char want[16] = {0xdd,0xaf,0x35,0xa1,0x93,0x61,0x7a,0xba,0xcc,0x41,0x73,0x49,0xae,0x20,0x41,0x31};
    unsigned char out[64]; rktcrypto_sha512_ctx_t ctx;
    rktcrypto_sha512_core_init(&ctx, rktcrypto_sha512_iv); rktcrypto_sha512_core_update(&ctx, (const unsigned char *)"abc", 3); rktcrypto_sha512_core_final(&ctx, out, 64);
    tot++; if (memcmp(out, want, 16)) { bad++; printf("KAT sha512(abc) mismatch\n"); } }
  { int r; double ba = 0, bb = 0; unsigned char out[64]; rktcrypto_sha512_ctx_t ctx;
    for (i = 0; i < MAXLEN; i++) msg[i] = (unsigned char)i;
    for (r = 0; r < 5; r++) {
      double t0, t1, v;
      kernel(1); t0 = now(); for (i = 0; i < 4; i++) { rktcrypto_sha512_core_init(&ctx, rktcrypto_sha512_iv); rktcrypto_sha512_core_update(&ctx, msg, MAXLEN); rktcrypto_sha512_core_final(&ctx, out, 64); } t1 = now();
      v = 4.0 * MAXLEN / (t1 - t0) / 1e6; if (v > ba) ba = v;
      kernel(0); t0 = now(); for (i = 0; i < 2; i++) { rktcrypto_sha512_core_init(&ctx, rktcrypto_sha512_iv); rktcrypto_sha512_core_update(&ctx, msg, MAXLEN); rktcrypto_sha512_core_final(&ctx, out, 64); } t1 = now(); kernel(1);
      v = 2.0 * MAXLEN / (t1 - t0) / 1e6; if (v > bb) bb = v;
    }
    printf("BENCH sha512-x86: %.0f MB/s\nBENCH sha512-portable: %.0f MB/s\n", ba, bb); }
  printf("%ld/%ld mismatches\n%s\n", bad, tot, bad ? "FAIL" : "PASS");
  return bad ? 1 : 0;
}
