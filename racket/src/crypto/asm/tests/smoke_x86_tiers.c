/* Cross-tier smoke for the x86-64 kernels through the public API, meant to run under CPU models that
   the test host does not have. Build from racket/src/crypto:
     gcc -O2 -I. -o /tmp/smoke asm/tests/smoke_x86_tiers.c rktcrypto_*.S rktcrypto_*.c -lm
   then run natively and under qemu-x86_64-static -cpu Haswell (AVX2 tier, no AVX-512), -cpu Westmere
   (AES-NI + PCLMUL + SSSE3, no AVX) and -cpu qemu64 (no AES-NI: portable C + the SSE2 Poly1305): the
   printed digest must be the same for all of them. This is what catches a kernel reached on a tier
   that cannot execute it (the GCM table kernel, 2026-10-24), which the feature overrides of the
   gate harnesses cannot: they change the dispatch, not what the setup code executes. */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include "rktcrypto.h"
#include "rktcrypto_cpu.h"
static unsigned char acc[64], tmp[32];
static void fold(const unsigned char *p, intptr_t n) { unsigned char ctx[64 + 32]; memcpy(ctx, acc, 32); if (n > 0) memcpy(ctx + 32, p, n > 32 ? 32 : n); 
  /* chain: acc = SHA256(acc || SHA256(p)) */
  rktcrypto_digest_oneshot(RKTCRYPTO_SHA256, p, 0, n, tmp, 0, 32); memcpy(ctx + 32, tmp, 32); rktcrypto_digest_oneshot(RKTCRYPTO_SHA256, ctx, 0, 64, acc, 0, 32); }
static unsigned char pt[70000], ct[70000 + 32], back[70000], aad[300];
int main(void) { int alg, i; long sizes[] = {0, 1, 15, 16, 17, 63, 64, 65, 127, 128, 255, 256, 257, 383, 511, 512, 513, 1023, 1024, 1025, 2047, 2048, 4095, 4096, 16384, 20000, 65536, 65537};
  unsigned char key[32], nonce[24], out[64];
  for (i = 0; i < (int)sizeof pt; i++) pt[i] = (unsigned char)(i * 131 + (i >> 8));
  for (i = 0; i < 300; i++) aad[i] = (unsigned char)(i * 7 + 1);
  for (i = 0; i < 32; i++) key[i] = (unsigned char)(i + 100); for (i = 0; i < 24; i++) nonce[i] = (unsigned char)(i * 3);
  printf("features=0x%x\n", rktcrypto_cpu_features());
  for (alg = 1; alg <= 6; alg++) { intptr_t kl = rktcrypto_aead_key_size(alg), nl = rktcrypto_aead_nonce_size(alg), tl = rktcrypto_aead_tag_size(alg); unsigned s;
    for (s = 0; s < sizeof sizes / sizeof sizes[0]; s++) { long n = sizes[s]; long al = (long)(n % 300);
      if (!rktcrypto_aead_seal(alg, key, kl, nonce, nl, aad, 0, al, pt, 0, n, ct, 0)) { printf("seal failed alg=%d n=%ld\n", alg, n); return 1; }
      fold(ct, n + tl);
      if (!rktcrypto_aead_open(alg, key, kl, nonce, nl, aad, 0, al, ct, 0, n + tl, back, 0) || memcmp(back, pt, n)) { printf("open failed alg=%d n=%ld\n", alg, n); return 1; }
      memcpy(back, pt, n); if (!rktcrypto_aead_seal(alg, key, kl, nonce, nl, aad, 0, al, back, 0, n, back, 0) || memcmp(back, ct, n + tl)) { printf("in-place seal differs alg=%d n=%ld\n", alg, n); if (alg < 5) return 1; }
      memcpy(back, ct, n + tl); if (!rktcrypto_aead_open(alg, key, kl, nonce, nl, aad, 0, al, back, 0, n + tl, back, 0) || memcmp(back, pt, n)) { printf("in-place open failed alg=%d n=%ld\n", alg, n); if (alg < 5) return 1; }
      ct[n / 2] ^= 1; if (rktcrypto_aead_open(alg, key, kl, nonce, nl, aad, 0, al, ct, 0, n + tl, back, 0)) { printf("tamper accepted alg=%d n=%ld\n", alg, n); return 1; } ct[n / 2] ^= 1; } }
  { int d[] = {RKTCRYPTO_SHA256, RKTCRYPTO_SHA512, RKTCRYPTO_SHA3_256}; unsigned s, k; long hs[] = {0, 1, 55, 56, 63, 64, 65, 119, 128, 129, 1000, 4096, 65537};
    for (k = 0; k < 3; k++) for (s = 0; s < sizeof hs / sizeof hs[0]; s++) { intptr_t ol = rktcrypto_digest_size(d[k]); rktcrypto_digest_oneshot(d[k], pt, 0, hs[s], out, 0, ol); fold(out, ol); } }
  { unsigned char sk[32], pk[32], sig[64], sh[32]; for (i = 0; i < 32; i++) sk[i] = (unsigned char)(i * 9 + 1);
    rktcrypto_ed25519_pubkey(pk, sk); rktcrypto_ed25519_sign(sig, pt, 1000, sk); fold(sig, 64); fold(pk, 32);
    if (!rktcrypto_ed25519_verify(sig, pt, 1000, pk)) { puts("ed25519 verify failed"); return 1; }
    rktcrypto_x25519(sh, sk, pk); fold(sh, 32); }
  { unsigned char pub[65], sh[32]; unsigned char d[32]; for (i = 0; i < 32; i++) d[i] = (unsigned char)(i * 5 + 3); rktcrypto_p256_pubkey(pub, d); rktcrypto_p256_ecdh(sh, key, pub); fold(pub, 65); fold(sh, 32); }
  printf("digest="); for (i = 0; i < 32; i++) printf("%02x", acc[i]); printf("\n"); return 0; }
