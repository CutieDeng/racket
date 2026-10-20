/* Differential + BENCH for the Poly1305 MULX kernel through rktcrypto_poly1305_update/final:
   the same computation with the BMI2/ADX feature bit cleared is the oracle (the radix-2^26 C
   code, checked against RFC 8439 by the integration suite). Also checks the ChaCha20-Poly1305
   AEAD through the public API. Build (from racket/src/crypto, on BMI2+ADX hardware):
     gcc -O2 -I. -o /tmp/test_poly1305_x86 asm/tests/test_poly1305_x86.c rktcrypto_poly1305_x86.S \
         rktcrypto_chacha20_avx512.S rktcrypto_sha256_x86.S rktcrypto_aes_ctr_vaes.S rktcrypto_ghash_vpclmul.S \
         rktcrypto_gcm_vaes.S rktcrypto_poly1305.c rktcrypto_chacha20.c rktcrypto_cpu.c rktcrypto_x86.c \
         rktcrypto_aead.c rktcrypto_gcm.c rktcrypto_aes_modes.c rktcrypto_ccm.c rktcrypto_ct.c */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <time.h>
#include "rktcrypto.h"
#include "rktcrypto_cpu.h"
#include "rktcrypto_cipher.h"
#define CP RKTCRYPTO_AEAD_CHACHA20_POLY1305

static uint64_t st = 0x3c6ef372fe94f82bULL;
static unsigned rnd(void) { st = st * 6364136223846793005ULL + 1442695040888963407ULL; return (unsigned)(st >> 33); }
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec * 1e-9; }
#define MAXLEN (1 << 20)
static unsigned char msg[MAXLEN + 64], oa[MAXLEN + 64], ob[MAXLEN + 64], aad[256];

static void mulx(int on)
{
  if (on) rktcrypto_cpu_override_features(0, 0);
  else rktcrypto_cpu_override_features(rktcrypto_cpu_features() & ~RKTCRYPTO_CPU_X86_BMI2ADX, 1);
}
/* MAC over msg[0..len) fed in random pieces (the piece boundaries exercise the buffer path) */
static void mac(const unsigned char *key, long len, unsigned seed, unsigned char tag[16])
{
  rktcrypto_poly1305_ctx_t ctx; long pos = 0; uint64_t s = seed;
  rktcrypto_poly1305_init(&ctx, key);
  while (pos < len) {
    long n; s = s * 6364136223846793005ULL + 1; n = (long)((s >> 33) % 700); if (n > len - pos) n = len - pos;
    rktcrypto_poly1305_update(&ctx, msg + pos, n); pos += n;
  }
  rktcrypto_poly1305_final(&ctx, tag);
}

int main(void)
{
  long bad = 0, tot = 0; int t, i;
  if (!rktcrypto_cpu_has(RKTCRYPTO_CPU_X86_BMI2ADX)) { printf("no BMI2/ADX\n"); return 2; }
  for (t = 0; t < 3000; t++) {
    unsigned char key[32], ta[16], tb[16]; unsigned seed = rnd();
    long len = (t < 64) ? 16 * t : (t & 1) ? (long)(rnd() % 5000) : 64 * (long)(rnd() % 40) + ((rnd() % 3) ? (long)(rnd() % 64) : 0);
    for (i = 0; i < 32; i++) key[i] = (unsigned char)rnd();
    if (t % 7 == 0) memset(key, 0xff, 16);                  /* r at the clamp limit */
    for (i = 0; i < len; i++) msg[i] = (t % 11 == 0) ? 0xff : (unsigned char)rnd();   /* all-ones blocks: maximal h */
    mulx(1); mac(key, len, seed, ta);
    mulx(0); mac(key, len, seed, tb); mulx(1);
    tot++; if (memcmp(ta, tb, 16)) { bad++; if (bad <= 5) printf("MAC MISMATCH t=%d len=%ld\n", t, len); continue; }
    if (t % 5 == 0) {
      unsigned char nonce[12]; long alen = (long)(rnd() % 100); int ra, rb;
      for (i = 0; i < 12; i++) nonce[i] = (unsigned char)rnd();
      for (i = 0; i < alen; i++) aad[i] = (unsigned char)rnd();
      mulx(1); ra = rktcrypto_aead_seal(CP, key, 32, nonce, 12, aad, 0, alen, msg, 0, len, oa, 0);
      mulx(0); rb = rktcrypto_aead_seal(CP, key, 32, nonce, 12, aad, 0, alen, msg, 0, len, ob, 0); mulx(1);
      tot++; if (ra != 1 || rb != 1 || memcmp(oa, ob, len + 16)) { bad++; if (bad <= 5) printf("AEAD SEAL MISMATCH t=%d len=%ld\n", t, len); continue; }
      ra = rktcrypto_aead_open(CP, key, 32, nonce, 12, aad, 0, alen, oa, 0, len + 16, ob, 0);
      tot++; if (ra != 1 || memcmp(ob, msg, len)) { bad++; if (bad <= 5) printf("AEAD OPEN MISMATCH t=%d len=%ld\n", t, len); continue; }
    }
  }
  /* BENCH: 1 MiB MAC and AEAD seal, best of 5, MULX vs radix-2^26 */
  { unsigned char key[32] = {1, 2, 3}, nonce[12] = {4, 5, 6}, tag[16]; int r; double ma = 0, mb = 0, sa = 0, sb = 0;
    for (i = 0; i < MAXLEN; i++) msg[i] = (unsigned char)i;
    for (r = 0; r < 5; r++) {
      double t0, t1, v; rktcrypto_poly1305_ctx_t ctx;
      mulx(1); t0 = now(); for (i = 0; i < 8; i++) { rktcrypto_poly1305_init(&ctx, key); rktcrypto_poly1305_update(&ctx, msg, MAXLEN); rktcrypto_poly1305_final(&ctx, tag); } t1 = now();
      v = 8.0 * MAXLEN / (t1 - t0) / 1e6; if (v > ma) ma = v;
      mulx(0); t0 = now(); for (i = 0; i < 4; i++) { rktcrypto_poly1305_init(&ctx, key); rktcrypto_poly1305_update(&ctx, msg, MAXLEN); rktcrypto_poly1305_final(&ctx, tag); } t1 = now(); mulx(1);
      v = 4.0 * MAXLEN / (t1 - t0) / 1e6; if (v > mb) mb = v;
      mulx(1); t0 = now(); for (i = 0; i < 4; i++) rktcrypto_aead_seal(CP, key, 32, nonce, 12, aad, 0, 0, msg, 0, MAXLEN, oa, 0); t1 = now();
      v = 4.0 * MAXLEN / (t1 - t0) / 1e6; if (v > sa) sa = v;
      mulx(0); t0 = now(); for (i = 0; i < 2; i++) rktcrypto_aead_seal(CP, key, 32, nonce, 12, aad, 0, 0, msg, 0, MAXLEN, ob, 0); t1 = now(); mulx(1);
      v = 2.0 * MAXLEN / (t1 - t0) / 1e6; if (v > sb) sb = v;
    }
    printf("BENCH poly1305-mulx: %.0f MB/s\nBENCH poly1305-radix26: %.0f MB/s\nBENCH chacha20-poly1305-seal-mulx: %.0f MB/s\nBENCH chacha20-poly1305-seal-radix26: %.0f MB/s\n", ma, mb, sa, sb); }
  printf("%ld/%ld mismatches\n%s\n", bad, tot, bad ? "FAIL" : "PASS");
  return bad ? 1 : 0;
}
