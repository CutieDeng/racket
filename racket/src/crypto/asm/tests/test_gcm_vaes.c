/* Differential + BENCH for the fused AES-GCM path (rktcrypto_gcm_vaes.S through gcm_x86_fused)
   against the two-pass path with the VAES and VPCLMULQDQ feature bits cleared (the AES-NI +
   PCLMUL intrinsics, themselves checked against the portable cipher by test_aes_x86.c).
   Build (from racket/src/crypto, on VAES + VPCLMULQDQ + AVX-512 hardware):
     gcc -O2 -I. -o /tmp/test_gcm_vaes asm/tests/test_gcm_vaes.c rktcrypto_gcm_vaes.S rktcrypto_aes_ctr_vaes.S \
         rktcrypto_ghash_vpclmul.S rktcrypto_sha256_x86.S rktcrypto_x86.c rktcrypto_cpu.c rktcrypto_gcm.c \
         rktcrypto_aes_modes.c rktcrypto_ccm.c rktcrypto_ct.c */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <time.h>
#include "rktcrypto_cpu.h"
#include "rktcrypto_cipher.h"

static uint64_t st = 0x7a3f9c1e5b2d4f61ULL;
static unsigned rnd(void) { st = st * 6364136223846793005ULL + 1442695040888963407ULL; return (unsigned)(st >> 33); }
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec * 1e-9; }
#define MAXLEN (1 << 20)
static unsigned char pt[MAXLEN + 64], cta[MAXLEN + 64], ctb[MAXLEN + 64], pa[MAXLEN + 64], pb[MAXLEN + 64], aad[512], buf[MAXLEN + 64];

static void fused(int on)
{
  if (on) rktcrypto_cpu_override_features(0, 0);
  else rktcrypto_cpu_override_features(rktcrypto_cpu_features() & ~(RKTCRYPTO_CPU_X86_VAES | RKTCRYPTO_CPU_X86_VPCLMULQDQ), 1);
}
static int seal(int k256, const unsigned char *key, const unsigned char *nonce, const unsigned char *a, long alen,
                const unsigned char *p, long len, unsigned char *out)
{
  return k256 ? rktcrypto_aes256gcm_seal(key, nonce, a, 0, alen, p, 0, len, out, 0)
              : rktcrypto_aes128gcm_seal(key, nonce, a, 0, alen, p, 0, len, out, 0);
}
static int open_(int k256, const unsigned char *key, const unsigned char *nonce, const unsigned char *a, long alen,
                 const unsigned char *c, long clen, unsigned char *out)
{
  return k256 ? rktcrypto_aes256gcm_open(key, nonce, a, 0, alen, c, 0, clen, out, 0)
              : rktcrypto_aes128gcm_open(key, nonce, a, 0, alen, c, 0, clen, out, 0);
}

int main(void)
{
  long bad = 0, tot = 0; int t, i;
  if (!(rktcrypto_cpu_has(RKTCRYPTO_CPU_X86_VAES) && rktcrypto_cpu_has(RKTCRYPTO_CPU_X86_VPCLMULQDQ) && rktcrypto_cpu_has(RKTCRYPTO_CPU_X86_AVX512))) {
    printf("no VAES/VPCLMULQDQ/AVX-512\n"); return 2; }
  for (t = 0; t < 1500; t++) {
    unsigned char key[32], nonce[12]; int k256 = rnd() & 1, ra, rb;
    long alen = (t & 2) ? (long)(rnd() % 400) : (long)(rnd() % 20);
    long len = (t < 48) ? 256 * t : (t & 1) ? (long)(rnd() % 6000) : 256 * (long)(rnd() % 16) + ((rnd() % 3) ? (long)(rnd() % 256) : 0);
    for (i = 0; i < 32; i++) key[i] = (unsigned char)rnd();
    for (i = 0; i < 12; i++) nonce[i] = (unsigned char)rnd();
    for (i = 0; i < alen; i++) aad[i] = (unsigned char)rnd();
    for (i = 0; i < len; i++) pt[i] = (unsigned char)rnd();
    /* seal: fused vs two-pass */
    fused(1); ra = seal(k256, key, nonce, aad, alen, pt, len, cta);
    fused(0); rb = seal(k256, key, nonce, aad, alen, pt, len, ctb); fused(1);
    tot++;
    if (ra != 1 || rb != 1 || memcmp(cta, ctb, len + 16)) { bad++; if (bad <= 5) printf("SEAL MISMATCH t=%d k256=%d alen=%ld len=%ld (%d/%d)\n", t, k256, alen, len, ra, rb); continue; }
    /* open: fused vs two-pass, both must recover pt */
    fused(1); ra = open_(k256, key, nonce, aad, alen, cta, len + 16, pa);
    fused(0); rb = open_(k256, key, nonce, aad, alen, cta, len + 16, pb); fused(1);
    tot++;
    if (ra != 1 || rb != 1 || memcmp(pa, pt, len) || memcmp(pb, pt, len)) { bad++; if (bad <= 5) printf("OPEN MISMATCH t=%d len=%ld (%d/%d)\n", t, len, ra, rb); continue; }
    /* in-place seal and open through the fused path */
    memcpy(buf, pt, len);
    ra = seal(k256, key, nonce, aad, alen, buf, len, buf);
    tot++; if (ra != 1 || memcmp(buf, cta, len + 16)) { bad++; if (bad <= 5) printf("INPLACE SEAL MISMATCH t=%d len=%ld\n", t, len); continue; }
    ra = open_(k256, key, nonce, aad, alen, buf, len + 16, buf);
    tot++; if (ra != 1 || memcmp(buf, pt, len)) { bad++; if (bad <= 5) printf("INPLACE OPEN MISMATCH t=%d len=%ld\n", t, len); continue; }
    /* tamper: one flipped byte (body or tag) must fail and, on the fused path (>= 512 bytes), wipe the output */
    { long pos = (long)(rnd() % (unsigned)(len + 16)); int wiped = 1;
      memcpy(buf, cta, len + 16); buf[pos] ^= 0x40;
      memset(pa, 0x5a, len);
      ra = open_(k256, key, nonce, aad, alen, buf, len + 16, pa);
      for (i = 0; i < len; i++) if (pa[i] != 0) { wiped = 0; break; }
      tot++; if (ra != 0 || (len >= 512 && !wiped)) { bad++; if (bad <= 5) printf("TAMPER t=%d len=%ld pos=%ld ra=%d wiped=%d\n", t, len, pos, ra, wiped); } }
  }
  /* BENCH: AES-256-GCM seal, 16 KiB and 1 MiB, best of 5, fused vs two-pass */
  { unsigned char key[32] = {1, 2, 3}, nonce[12] = {4, 5, 6}; long sizes[2] = {16384, MAXLEN}; int s;
    for (s = 0; s < 2; s++) {
      long n = sizes[s]; int reps = (int)(MAXLEN / n) * 4, r; double best_a = 0, best_b = 0;
      for (r = 0; r < 5; r++) {
        double t0, t1, v;
        fused(1); t0 = now(); for (i = 0; i < reps; i++) rktcrypto_aes256gcm_seal(key, nonce, aad, 0, 0, pt, 0, n, cta, 0); t1 = now();
        v = (double)reps * n / (t1 - t0) / 1e6; if (v > best_a) best_a = v;
        fused(0); t0 = now(); for (i = 0; i < reps; i++) rktcrypto_aes256gcm_seal(key, nonce, aad, 0, 0, pt, 0, n, ctb, 0); t1 = now(); fused(1);
        v = (double)reps * n / (t1 - t0) / 1e6; if (v > best_b) best_b = v;
      }
      printf("BENCH aes-256-gcm-seal-%ldk-fused: %.0f MB/s\nBENCH aes-256-gcm-seal-%ldk-twopass: %.0f MB/s\n", n / 1024, best_a, n / 1024, best_b);
    } }
  printf("%ld/%ld mismatches\n%s\n", bad, tot, bad ? "FAIL" : "PASS");
  return bad ? 1 : 0;
}
