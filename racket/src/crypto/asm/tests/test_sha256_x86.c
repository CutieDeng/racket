/* Differential + KAT + BENCH for the x86 SHA-256 kernel (rktcrypto_sha256_x86.S)
   against the intrinsics path (rktcrypto_sha256_block_shani, itself KAT-verified
   through the integration suite). Build (from racket/src/crypto, on SHA-NI hardware):
     gcc -O2 -I. -o /tmp/test_sha256_x86 asm/tests/test_sha256_x86.c rktcrypto_sha256_x86.S rktcrypto_x86.c rktcrypto_cpu.c */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <time.h>
#include "rktcrypto_cpu.h"
void rktcrypto_sha256_blocks_x86(uint32_t state[8], const unsigned char *data, intptr_t nblk);
void rktcrypto_sha256_block_shani(uint32_t state[8], const unsigned char *data);
void rktcrypto_sha256_blocks_avx2(uint32_t state[8], const unsigned char *data, intptr_t nblk);

static uint64_t st = 0x243f6a8885a308d3ULL;
static unsigned rnd(void) { st = st * 6364136223846793005ULL + 1; return (unsigned)(st >> 33); }
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec * 1e-9; }
static unsigned char buf[1 << 20];

int main(void)
{
  long bad = 0, tot = 0; int t, i;
  if (!(rktcrypto_cpu_features() & RKTCRYPTO_CPU_X86_SHA)) { printf("no SHA-NI\n"); return 2; }
  for (t = 0; t < 3000; t++) {
    uint32_t a[8], b[8], c[8]; long nblk = (t < 64) ? t : (long)(rnd() % 40);
    for (i = 0; i < 8; i++) a[i] = b[i] = c[i] = ((uint32_t)rnd() << 1) ^ rnd();
    for (i = 0; i < nblk * 64; i++) buf[i] = (unsigned char)rnd();
    rktcrypto_sha256_blocks_x86(a, buf, nblk);
    for (i = 0; i < nblk; i++) rktcrypto_sha256_block_shani(b, buf + 64 * i);
    tot++; if (memcmp(a, b, 32)) { bad++; if (bad <= 5) printf("MISMATCH nblk=%ld\n", nblk); }
    rktcrypto_sha256_blocks_avx2(c, buf, nblk);   /* the tier without SHA-NI */
    tot++; if (memcmp(c, b, 32)) { bad++; if (bad <= 5) printf("AVX2 MISMATCH nblk=%ld\n", nblk); }
  }
  /* FIPS 180-4 "abc": one padded block */
  { static const uint32_t iv[8] = {0x6a09e667u,0xbb67ae85u,0x3c6ef372u,0xa54ff53au,0x510e527fu,0x9b05688cu,0x1f83d9abu,0x5be0cd19u};
    static const uint32_t want[8] = {0xba7816bfu,0x8f01cfeau,0x414140deu,0x5dae2223u,0xb00361a3u,0x96177a9cu,0xb410ff61u,0xf20015adu};
    uint32_t s[8]; unsigned char blk[64]; memcpy(s, iv, 32); memset(blk, 0, 64);
    blk[0] = 'a'; blk[1] = 'b'; blk[2] = 'c'; blk[3] = 0x80; blk[63] = 24;
    rktcrypto_sha256_blocks_x86(s, blk, 1);
    tot++; if (memcmp(s, want, 32)) { bad++; printf("KAT abc mismatch\n"); } }
  /* BENCH: MB/s over 1 MiB, best of 5 */
  { uint32_t s[8] = {0}; double best_a = 0, best_b = 0; int r; long nblk = sizeof(buf) / 64;
    for (r = 0; r < 5; r++) {
      double t0 = now(); for (i = 0; i < 20; i++) rktcrypto_sha256_blocks_x86(s, buf, nblk); double t1 = now();
      double v = 20.0 * sizeof(buf) / (t1 - t0) / 1e6; if (v > best_a) best_a = v;
      t0 = now(); for (i = 0; i < 20; i++) { long k; for (k = 0; k < nblk; k++) rktcrypto_sha256_block_shani(s, buf + 64 * k); } t1 = now();
      v = 20.0 * sizeof(buf) / (t1 - t0) / 1e6; if (v > best_b) best_b = v;
    }
    { double best_c = 0; int r; uint32_t s[8] = {1,2,3,4,5,6,7,8};
      for (r = 0; r < 5; r++) { double t0 = now(); rktcrypto_sha256_blocks_avx2(s, buf, (1 << 20) / 64); double v = (1 << 20) / (now() - t0) / 1e6; if (v > best_c) best_c = v; }
      printf("BENCH sha256-avx2-no-shani: %.0f MB/s\n", best_c); }
    printf("BENCH sha256-asm-x86: %.0f MB/s\nBENCH sha256-intrinsics: %.0f MB/s\n", best_a, best_b); }
  printf("%ld/%ld mismatches\n%s\n", bad, tot, bad ? "FAIL" : "PASS");
  return bad ? 1 : 0;
}
