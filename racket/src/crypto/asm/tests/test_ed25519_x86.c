/* Differential + KAT + BENCH for the Ed25519 x86 path (fe64 field and point kernels in
   rktcrypto_x25519_x86.S) through the public API: the same operations with the BMI2/ADX bit
   cleared run the radix-2^51 C code, which is the oracle (checked by the integration suite
   against RFC 8032). Build (from racket/src/crypto, on BMI2+ADX+AVX-512 hardware):
     gcc -O2 -I. -o /tmp/test_ed25519_x86 asm/tests/test_ed25519_x86.c rktcrypto_*.S rktcrypto_ed25519.c \
         rktcrypto_sha512.c rktcrypto_cpu.c rktcrypto_x86.c */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <time.h>
#include "rktcrypto.h"
#include "rktcrypto_cpu.h"

static uint64_t st = 0x2ed25519a5a5a5a5ULL;
static unsigned rnd(void) { st = st * 6364136223846793005ULL + 1442695040888963407ULL; return (unsigned)(st >> 33); }
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec * 1e-9; }
static void x86(int on)
{
  if (on) rktcrypto_cpu_override_features(0, 0);
  else rktcrypto_cpu_override_features(rktcrypto_cpu_features() & ~RKTCRYPTO_CPU_X86_BMI2ADX, 1);
}
static void avx2_tier(void) { rktcrypto_cpu_override_features(rktcrypto_cpu_features() & ~RKTCRYPTO_CPU_X86_AVX512, 1); }
static int hexeq(const unsigned char *b, const char *hex, int n)
{
  int i; for (i = 0; i < n; i++) { unsigned v; if (sscanf(hex + 2 * i, "%2x", &v) != 1 || v != b[i]) return 0; } return 1;
}

int main(void)
{
  long bad = 0, tot = 0; int t, i;
  static unsigned char msg[400];
  if (!(rktcrypto_cpu_has(RKTCRYPTO_CPU_X86_BMI2ADX) && rktcrypto_cpu_has(RKTCRYPTO_CPU_X86_AVX512))) { printf("no BMI2/ADX + AVX-512\n"); return 2; }
  for (t = 0; t < 1500; t++) {
    unsigned char seed[32], pka[32], pkb[32], siga[64], sigb[64]; long len = (t < 8) ? t : (long)(rnd() % 400);
    for (i = 0; i < 32; i++) seed[i] = (unsigned char)rnd();
    for (i = 0; i < len; i++) msg[i] = (unsigned char)rnd();
    x86(1); rktcrypto_ed25519_pubkey(pka, seed); rktcrypto_ed25519_sign(siga, msg, len, seed);
    x86(0); rktcrypto_ed25519_pubkey(pkb, seed); rktcrypto_ed25519_sign(sigb, msg, len, seed); x86(1);
    tot++; if (memcmp(pka, pkb, 32)) { bad++; if (bad <= 5) printf("PUBKEY MISMATCH t=%d\n", t); continue; }
    tot++; if (memcmp(siga, sigb, 64)) { bad++; if (bad <= 5) printf("SIGN MISMATCH t=%d len=%ld\n", t, len); continue; }
    avx2_tier(); rktcrypto_ed25519_sign(sigb, msg, len, seed); i = rktcrypto_ed25519_verify(siga, msg, len, pka); x86(1);
    tot++; if (memcmp(siga, sigb, 64) || i != 1) { bad++; if (bad <= 5) printf("AVX2-TIER MISMATCH t=%d len=%ld\n", t, len); continue; }
    tot++; if (rktcrypto_ed25519_verify(siga, msg, len, pka) != 1) { bad++; if (bad <= 5) printf("VERIFY FAIL (x86) t=%d\n", t); continue; }
    x86(0); i = rktcrypto_ed25519_verify(siga, msg, len, pka); x86(1);
    tot++; if (i != 1) { bad++; if (bad <= 5) printf("VERIFY FAIL (portable) t=%d\n", t); continue; }
    if (len) { msg[rnd() % len] ^= 1 << (rnd() % 8);
      tot++; if (rktcrypto_ed25519_verify(siga, msg, len, pka) != 0) { bad++; if (bad <= 5) printf("TAMPER ACCEPTED t=%d\n", t); } }
    else { siga[rnd() % 32] ^= 1 << (rnd() % 8);
      tot++; if (rktcrypto_ed25519_verify(siga, msg, len, pka) != 0) { bad++; if (bad <= 5) printf("TAMPERED SIG ACCEPTED t=%d\n", t); } }
  }
  /* RFC 8032 section 7.1 test 1 (empty message) on the x86 path */
  { unsigned char seed[32], pk[32], sig[64];
    const char *seedh = "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60";
    for (i = 0; i < 32; i++) { unsigned v; sscanf(seedh + 2 * i, "%2x", &v); seed[i] = (unsigned char)v; }
    rktcrypto_ed25519_pubkey(pk, seed); rktcrypto_ed25519_sign(sig, msg, 0, seed);
    tot++; if (!hexeq(pk, "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a", 32)) { bad++; printf("KAT pubkey mismatch\n"); }
    tot++; if (!hexeq(sig, "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b", 64)) { bad++; printf("KAT signature mismatch\n"); }
    tot++; if (rktcrypto_ed25519_verify(sig, msg, 0, pk) != 1) { bad++; printf("KAT verify failed\n"); } }
  /* BENCH: sign and verify of a 64-byte message, best of 5 x 1000, x86 vs portable */
  { unsigned char seed[32] = {1, 2, 3}, pk[32], sig[64]; int r; double sa = 1e9, sb = 1e9, va = 1e9, vb = 1e9;
    for (i = 0; i < 64; i++) msg[i] = (unsigned char)i;
    rktcrypto_ed25519_pubkey(pk, seed);
    for (r = 0; r < 5; r++) {
      double t0, t1;
      x86(1); t0 = now(); for (i = 0; i < 1000; i++) rktcrypto_ed25519_sign(sig, msg, 64, seed); t1 = now(); if (t1 - t0 < sa) sa = t1 - t0;
      t0 = now(); for (i = 0; i < 1000; i++) rktcrypto_ed25519_verify(sig, msg, 64, pk); t1 = now(); if (t1 - t0 < va) va = t1 - t0;
      x86(0); t0 = now(); for (i = 0; i < 1000; i++) rktcrypto_ed25519_sign(sig, msg, 64, seed); t1 = now(); if (t1 - t0 < sb) sb = t1 - t0;
      t0 = now(); for (i = 0; i < 1000; i++) rktcrypto_ed25519_verify(sig, msg, 64, pk); t1 = now(); if (t1 - t0 < vb) vb = t1 - t0; x86(1);
    }
    { double sc = 1e9; for (r = 0; r < 5; r++) { double t0, t1;
        avx2_tier(); t0 = now(); for (i = 0; i < 1000; i++) rktcrypto_ed25519_sign(sig, msg, 64, seed); t1 = now(); x86(1); if (t1 - t0 < sc) sc = t1 - t0; }
      printf("BENCH ed25519-sign-avx2-tier: %.2f us\n", sc * 1e3); }
    printf("BENCH ed25519-sign-x86: %.2f us\nBENCH ed25519-verify-x86: %.2f us\nBENCH ed25519-sign-portable: %.2f us\nBENCH ed25519-verify-portable: %.2f us\n",
           sa * 1e3, va * 1e3, sb * 1e3, vb * 1e3); }
  printf("%ld/%ld mismatches\n%s\n", bad, tot, bad ? "FAIL" : "PASS");
  return bad ? 1 : 0;
}
