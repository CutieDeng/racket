/* Differential + BENCH for the ChaCha20 AVX-512 kernel through rktcrypto_chacha20_xor: the same
   call with the AVX-512 feature bit cleared is the oracle (the scalar chacha20_core path, which
   the integration suite checks against the RFC 8439 vectors). Also checks the ChaCha20-Poly1305
   AEAD through the public API. Build (from racket/src/crypto, on AVX-512 hardware):
     gcc -O2 -I. -o /tmp/test_chacha20_avx512 asm/tests/test_chacha20_avx512.c rktcrypto_chacha20_avx512.S \
         rktcrypto_chacha20.c rktcrypto_cpu.c rktcrypto_x86.c rktcrypto_sha256_x86.S rktcrypto_aes_ctr_vaes.S \
         rktcrypto_ghash_vpclmul.S rktcrypto_gcm_vaes.S rktcrypto_poly1305.c rktcrypto_aead.c rktcrypto_gcm.c \
         rktcrypto_aes_modes.c rktcrypto_ccm.c rktcrypto_ct.c */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <time.h>
#include "rktcrypto.h"
#include "rktcrypto_cpu.h"
#include "rktcrypto_cipher.h"
#define CP RKTCRYPTO_AEAD_CHACHA20_POLY1305

static uint64_t st = 0x1f83d9abfb41bd6bULL;
static unsigned rnd(void) { st = st * 6364136223846793005ULL + 1442695040888963407ULL; return (unsigned)(st >> 33); }
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec * 1e-9; }
#define MAXLEN (1 << 20)
static unsigned char in[MAXLEN + 64], oa[MAXLEN + 64], ob[MAXLEN + 64], aad[256];

static void avx512(int on)   /* 1: everything; 0: scalar oracle (no AVX-512, no AVX2 kernel) */
{
  if (on) rktcrypto_cpu_override_features(0, 0);
  else rktcrypto_cpu_override_features(rktcrypto_cpu_features() & ~(RKTCRYPTO_CPU_X86_AVX512 | RKTCRYPTO_CPU_X86_AVX2 | RKTCRYPTO_CPU_X86_SSSE3), 1);
}
static void avx2_tier(void) { rktcrypto_cpu_override_features(rktcrypto_cpu_features() & ~RKTCRYPTO_CPU_X86_AVX512, 1); }
static void ssse3_tier(void) { rktcrypto_cpu_override_features(rktcrypto_cpu_features() & ~(RKTCRYPTO_CPU_X86_AVX512 | RKTCRYPTO_CPU_X86_AVX2), 1); }

int main(void)
{
  long bad = 0, tot = 0; int t, i;
  if (!rktcrypto_cpu_has(RKTCRYPTO_CPU_X86_AVX512)) { printf("no AVX-512\n"); return 2; }
  for (t = 0; t < 2500; t++) {
    unsigned char key[32], nonce[12]; uint32_t ctr;
    long len = (t < 40) ? 1024 * t : (t & 1) ? (long)(rnd() % 6000) : 1024 * (long)(rnd() % 6) + ((rnd() % 3) ? (long)(rnd() % 1024) : 0);
    for (i = 0; i < 32; i++) key[i] = (unsigned char)rnd();
    for (i = 0; i < 12; i++) nonce[i] = (unsigned char)rnd();
    ctr = (rnd() % 4 == 0) ? 0xffffffffu - (rnd() % 40) : (rnd() & 1) ? rnd() : 1;   /* includes the 2^32 wrap */
    for (i = 0; i < len; i++) in[i] = (unsigned char)rnd();
    memset(oa, 0x11, len + 64); memset(ob, 0x11, len + 64);
    avx512(1); rktcrypto_chacha20_xor(key, nonce, ctr, in, oa, len);
    avx512(0); rktcrypto_chacha20_xor(key, nonce, ctr, in, ob, len); avx512(1);
    tot++;
    if (memcmp(oa, ob, len + 64)) { bad++; if (bad <= 5) printf("XOR MISMATCH t=%d len=%ld ctr=%u\n", t, len, ctr); continue; }
    /* the AVX2 tier (AVX-512 cleared) must agree too */
    memset(oa, 0x11, len + 64);
    avx2_tier(); rktcrypto_chacha20_xor(key, nonce, ctr, in, oa, len); avx512(1);
    tot++;
    if (memcmp(oa, ob, len + 64)) { bad++; if (bad <= 5) printf("AVX2 XOR MISMATCH t=%d len=%ld ctr=%u\n", t, len, ctr); continue; }
    memset(oa, 0x11, len + 64);
    ssse3_tier(); rktcrypto_chacha20_xor(key, nonce, ctr, in, oa, len); avx512(1);
    tot++;
    if (memcmp(oa, ob, len + 64)) { bad++; if (bad <= 5) printf("SSSE3 XOR MISMATCH t=%d len=%ld ctr=%u\n", t, len, ctr); continue; }
    /* in place */
    memcpy(oa, in, len);
    rktcrypto_chacha20_xor(key, nonce, ctr, oa, oa, len);
    tot++; if (memcmp(oa, ob, len)) { bad++; if (bad <= 5) printf("INPLACE MISMATCH t=%d len=%ld\n", t, len); continue; }
    /* AEAD seal/open, fused-free comparison across the feature bit */
    if (t % 5 == 0) {
      long alen = (long)(rnd() % 100); int ra, rb;
      for (i = 0; i < alen; i++) aad[i] = (unsigned char)rnd();
      avx512(1); ra = rktcrypto_aead_seal(CP, key, 32, nonce, 12, aad, 0, alen, in, 0, len, oa, 0);
      avx512(0); rb = rktcrypto_aead_seal(CP, key, 32, nonce, 12, aad, 0, alen, in, 0, len, ob, 0); avx512(1);
      tot++; if (ra != 1 || rb != 1 || memcmp(oa, ob, len + 16)) { bad++; if (bad <= 5) printf("AEAD SEAL MISMATCH t=%d len=%ld\n", t, len); continue; }
      ra = rktcrypto_aead_open(CP, key, 32, nonce, 12, aad, 0, alen, oa, 0, len + 16, ob, 0);
      tot++; if (ra != 1 || memcmp(ob, in, len)) { bad++; if (bad <= 5) printf("AEAD OPEN MISMATCH t=%d len=%ld\n", t, len); continue; }
    }
  }
  /* BENCH: 1 MiB keystream XOR and AEAD seal, best of 5, AVX-512 vs scalar */
  { unsigned char key[32] = {1, 2, 3}, nonce[12] = {4, 5, 6}; int r; double ba = 0, bb = 0, sa = 0, sb = 0;
    for (r = 0; r < 5; r++) {
      double t0, t1, v;
      avx512(1); t0 = now(); for (i = 0; i < 8; i++) rktcrypto_chacha20_xor(key, nonce, 1, in, oa, MAXLEN); t1 = now();
      v = 8.0 * MAXLEN / (t1 - t0) / 1e6; if (v > ba) ba = v;
      avx512(0); t0 = now(); for (i = 0; i < 2; i++) rktcrypto_chacha20_xor(key, nonce, 1, in, ob, MAXLEN); t1 = now(); avx512(1);
      v = 2.0 * MAXLEN / (t1 - t0) / 1e6; if (v > bb) bb = v;
      avx512(1); t0 = now(); for (i = 0; i < 4; i++) rktcrypto_aead_seal(CP, key, 32, nonce, 12, aad, 0, 0, in, 0, MAXLEN, oa, 0); t1 = now();
      v = 4.0 * MAXLEN / (t1 - t0) / 1e6; if (v > sa) sa = v;
      avx512(0); t0 = now(); for (i = 0; i < 2; i++) rktcrypto_aead_seal(CP, key, 32, nonce, 12, aad, 0, 0, in, 0, MAXLEN, ob, 0); t1 = now(); avx512(1);
      v = 2.0 * MAXLEN / (t1 - t0) / 1e6; if (v > sb) sb = v;
    }
    { double bc = 0; for (r = 0; r < 5; r++) { double t0, t1, v;
        avx2_tier(); t0 = now(); for (i = 0; i < 4; i++) rktcrypto_chacha20_xor(key, nonce, 1, in, oa, MAXLEN); t1 = now(); avx512(1);
        v = 4.0 * MAXLEN / (t1 - t0) / 1e6; if (v > bc) bc = v; }
      printf("BENCH chacha20-avx2: %.0f MB/s\n", bc); }
    { double bd = 0; for (r = 0; r < 5; r++) { double t0, t1, v;
        ssse3_tier(); t0 = now(); for (i = 0; i < 2; i++) rktcrypto_chacha20_xor(key, nonce, 1, in, oa, MAXLEN); t1 = now(); avx512(1);
        v = 2.0 * MAXLEN / (t1 - t0) / 1e6; if (v > bd) bd = v; }
      printf("BENCH chacha20-ssse3: %.0f MB/s\n", bd); }
    printf("BENCH chacha20-avx512: %.0f MB/s\nBENCH chacha20-scalar: %.0f MB/s\nBENCH chacha20-poly1305-seal-avx512: %.0f MB/s\nBENCH chacha20-poly1305-seal-scalar: %.0f MB/s\n", ba, bb, sa, sb); }
  printf("%ld/%ld mismatches\n%s\n", bad, tot, bad ? "FAIL" : "PASS");
  return bad ? 1 : 0;
}
