/* Differential + BENCH for the VAES CTR kernel (rktcrypto_aes_ctr_vaes.S) and its
   dispatcher against the AES-NI intrinsics path (rktcrypto_aes_ctr_aesni, itself
   differential-tested against the portable cipher by test_aes_x86.c).
   Build (from racket/src/crypto, on VAES + AVX-512 hardware):
     gcc -O2 -I. -o /tmp/test_aes_ctr_vaes asm/tests/test_aes_ctr_vaes.c rktcrypto_aes_ctr_vaes.S rktcrypto_x86.c rktcrypto_cpu.c */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <time.h>
#include "rktcrypto_cpu.h"
#include "rktcrypto_x86.h"

static uint64_t st = 0x9e3779b97f4a7c15ULL;
static unsigned rnd(void) { st = st * 6364136223846793005ULL + 1442695040888963407ULL; return (unsigned)(st >> 33); }
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec * 1e-9; }
static unsigned char in[1 << 20], outa[1 << 20], outb[1 << 20];

static void random_ctr(unsigned char ctr[16])
{
  int i; unsigned k = rnd() % 8;
  for (i = 0; i < 16; i++) ctr[i] = (unsigned char)rnd();
  if (k == 0) { ctr[12] = ctr[13] = ctr[14] = 0xff; ctr[15] = (unsigned char)(0xff - rnd() % 20); }   /* 32-bit wrap */
  if (k == 1) { memset(ctr + 8, 0xff, 8); ctr[15] = (unsigned char)(0xff - rnd() % 20); }              /* 64-bit wrap */
  if (k == 2) { memset(ctr, 0xff, 16); ctr[15] = (unsigned char)(0xff - rnd() % 20); }                 /* 128-bit wrap */
}

int main(void)
{
  long bad = 0, tot = 0; int t, i;
  if (!(rktcrypto_cpu_has(RKTCRYPTO_CPU_X86_VAES) && rktcrypto_cpu_has(RKTCRYPTO_CPU_X86_AVX512))) { printf("no VAES/AVX-512\n"); return 2; }
  for (t = 0; t < 4000; t++) {
    unsigned char key[32], rk[240], ctra[16], ctrb[16]; int keylen = 16 + 8 * (rnd() % 3), Nr, inc32 = rnd() & 1;
    long len = (t < 40) ? 64 * t : (long)(rnd() % 1500);
    if (t & 1) len &= ~63L;            /* half the trials exercise the kernel alone */
    for (i = 0; i < keylen; i++) key[i] = (unsigned char)rnd();
    Nr = rktcrypto_aes_expand_x86(key, keylen, rk);
    random_ctr(ctra); memcpy(ctrb, ctra, 16);
    for (i = 0; i < len; i++) in[i] = (unsigned char)rnd();
    memset(outa, 0xaa, len + 64); memset(outb, 0xaa, len + 64);
    if (t & 1) rktcrypto_aes_ctr_vaes(rk, Nr | (inc32 ? 0x100 : 0), ctra, in, outa, len);
    else rktcrypto_aes_ctr_x86(rk, Nr, ctra, in, outa, len, inc32);
    rktcrypto_aes_ctr_aesni(rk, Nr, ctrb, in, outb, len, inc32);
    tot++;
    if (memcmp(outa, outb, len + 64) || memcmp(ctra, ctrb, 16)) {
      bad++;
      if (bad <= 5) printf("MISMATCH t=%d keylen=%d inc32=%d len=%ld (%s) data %d ctr %d\n", t, keylen, inc32, len,
                           (t & 1) ? "kernel" : "dispatcher", memcmp(outa, outb, len + 64) != 0, memcmp(ctra, ctrb, 16) != 0);
    }
  }
  /* BENCH: 1 MiB inc32 keystream, AES-256, best of 5 */
  { unsigned char key[32] = {1,2,3}, rk[240], ctr[16] = {0}; int Nr = rktcrypto_aes_expand_x86(key, 32, rk); int r;
    double best_a = 0, best_b = 0;
    for (r = 0; r < 5; r++) {
      double t0 = now(); for (i = 0; i < 20; i++) rktcrypto_aes_ctr_vaes(rk, Nr | 0x100, ctr, in, outa, sizeof(in)); double t1 = now();
      double v = 20.0 * sizeof(in) / (t1 - t0) / 1e6; if (v > best_a) best_a = v;
      t0 = now(); for (i = 0; i < 20; i++) rktcrypto_aes_ctr_aesni(rk, Nr, ctr, in, outb, sizeof(in), 1); t1 = now();
      v = 20.0 * sizeof(in) / (t1 - t0) / 1e6; if (v > best_b) best_b = v;
    }
    printf("BENCH aes-256-ctr-vaes: %.0f MB/s\nBENCH aes-256-ctr-aesni: %.0f MB/s\n", best_a, best_b); }
  printf("%ld/%ld mismatches\n%s\n", bad, tot, bad ? "FAIL" : "PASS");
  return bad ? 1 : 0;
}
