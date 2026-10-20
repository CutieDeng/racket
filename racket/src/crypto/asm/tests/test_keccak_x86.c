/* Differential + KAT + BENCH for the Keccak-f[1600] AVX-512 kernel (rktcrypto_keccak_avx512.S)
   against a copy of the portable permutation (rktcrypto_sha3.c), plus the FIPS 202 SHA3-256("abc")
   vector through a sponge built on the kernel. Build (from racket/src/crypto, on AVX-512 hardware):
     gcc -O2 -I. -o /tmp/test_keccak_x86 asm/tests/test_keccak_x86.c rktcrypto_*.S rktcrypto_cpu.c rktcrypto_x86.c */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <time.h>
#include "rktcrypto_cpu.h"
#include "rktcrypto_x86.h"

#define ROTL64(x, n) (((x) << (n)) | ((x) >> (64 - (n))))
static const uint64_t RC[24] = {
  0x0000000000000001ULL, 0x0000000000008082ULL, 0x800000000000808aULL, 0x8000000080008000ULL,
  0x000000000000808bULL, 0x0000000080000001ULL, 0x8000000080008081ULL, 0x8000000000008009ULL,
  0x000000000000008aULL, 0x0000000000000088ULL, 0x0000000080008009ULL, 0x000000008000000aULL,
  0x000000008000808bULL, 0x800000000000008bULL, 0x8000000000008089ULL, 0x8000000000008003ULL,
  0x8000000000008002ULL, 0x8000000000000080ULL, 0x000000000000800aULL, 0x800000008000000aULL,
  0x8000000080008081ULL, 0x8000000000008080ULL, 0x0000000080000001ULL, 0x8000000080008008ULL};
static const int RHO[24] = {1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 2, 14, 27, 41, 56, 8, 25, 43, 62, 18, 39, 61, 20, 44};
static const int PI[24] = {10, 7, 11, 17, 18, 3, 5, 16, 8, 21, 24, 4, 15, 23, 19, 13, 12, 2, 20, 14, 22, 9, 6, 1};
static void ref_keccak_f(uint64_t s[25])
{
  int round, i;
  for (round = 0; round < 24; round++) {
    uint64_t bc[5], t;
    for (i = 0; i < 5; i++) bc[i] = s[i] ^ s[i+5] ^ s[i+10] ^ s[i+15] ^ s[i+20];
    for (i = 0; i < 5; i++) { t = bc[(i+4)%5] ^ ROTL64(bc[(i+1)%5], 1); s[i] ^= t; s[i+5] ^= t; s[i+10] ^= t; s[i+15] ^= t; s[i+20] ^= t; }
    t = s[1];
    for (i = 0; i < 24; i++) { int j = PI[i]; uint64_t tmp = s[j]; s[j] = ROTL64(t, RHO[i]); t = tmp; }
    for (i = 0; i < 25; i += 5) { uint64_t a0 = s[i], a1 = s[i+1], a2 = s[i+2], a3 = s[i+3], a4 = s[i+4];
      s[i] = a0 ^ (~a1 & a2); s[i+1] = a1 ^ (~a2 & a3); s[i+2] = a2 ^ (~a3 & a4); s[i+3] = a3 ^ (~a4 & a0); s[i+4] = a4 ^ (~a0 & a1); }
    s[0] ^= RC[round];
  }
}
static uint64_t st = 0xa54ff53a5f1d36f1ULL;
static uint64_t rnd64(void) { st = st * 6364136223846793005ULL + 1442695040888963407ULL; return st ^ (st >> 31); }
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec * 1e-9; }

int main(void)
{
  long bad = 0, tot = 0; int t, i;
  if (!rktcrypto_cpu_has(RKTCRYPTO_CPU_X86_AVX512)) { printf("no AVX-512\n"); return 2; }
  for (t = 0; t < 20000; t++) {
    uint64_t a[25], b[25];
    for (i = 0; i < 25; i++) a[i] = (t % 7 == 0) ? ((rnd64() & 1) ? ~0ULL : 0ULL) : rnd64();
    memcpy(b, a, sizeof a);
    keccak_f1600_x86(a);
    ref_keccak_f(b);
    tot++; if (memcmp(a, b, sizeof a)) { bad++; if (bad <= 5) printf("PERM MISMATCH t=%d\n", t); }
  }
  /* SHA3-256("abc") = 3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532 */
  { uint64_t s[25]; unsigned char blk[136], got[32];
    static const unsigned char want[32] = {0x3a,0x98,0x5d,0xa7,0x4f,0xe2,0x25,0xb2,0x04,0x5c,0x17,0x2d,0x6b,0xd3,0x90,0xbd,0x85,0x5f,0x08,0x6e,0x3e,0x9d,0x52,0x5b,0x46,0xbf,0xe2,0x45,0x11,0x43,0x15,0x32};
    memset(s, 0, sizeof s); memset(blk, 0, sizeof blk);
    blk[0] = 'a'; blk[1] = 'b'; blk[2] = 'c'; blk[3] = 0x06; blk[135] |= 0x80;
    for (i = 0; i < 17; i++) { uint64_t w = 0; int k; for (k = 0; k < 8; k++) w |= (uint64_t)blk[8 * i + k] << (8 * k); s[i] ^= w; }
    keccak_f1600_x86(s);
    for (i = 0; i < 32; i++) got[i] = (unsigned char)(s[i / 8] >> (8 * (i % 8)));
    tot++; if (memcmp(got, want, 32)) { bad++; printf("KAT sha3-256(abc) mismatch\n"); } }
  /* BENCH: permutations per second, expressed as SHA3-256 rate bytes (136 per permutation) */
  { uint64_t s[25]; int r; double ba = 0, bb = 0; memset(s, 0, sizeof s);
    for (r = 0; r < 5; r++) {
      double t0 = now(); for (i = 0; i < 200000; i++) keccak_f1600_x86(s); double t1 = now();
      double v = 200000.0 * 136 / (t1 - t0) / 1e6; if (v > ba) ba = v;
      t0 = now(); for (i = 0; i < 200000; i++) ref_keccak_f(s); t1 = now();
      v = 200000.0 * 136 / (t1 - t0) / 1e6; if (v > bb) bb = v;
    }
    printf("BENCH keccak-avx512 (sha3-256 rate): %.0f MB/s\nBENCH keccak-portable (sha3-256 rate): %.0f MB/s\n", ba, bb); }
  printf("%ld/%ld mismatches\n%s\n", bad, tot, bad ? "FAIL" : "PASS");
  return bad ? 1 : 0;
}
