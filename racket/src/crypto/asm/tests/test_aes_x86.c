/* Differential: the x86 AES-NI paths (key schedule, block, CTR, CBC, CMAC, XTS,
   GCM, CCM) vs the portable software AES in the same binary, by toggling the
   cached CPU feature word (rktcrypto_cpu_override_features). Run on real
   AES-NI hardware (lan-11). Build (from racket/src/crypto):
     gcc -O2 -I. -o /tmp/test_aes_x86 asm/tests/test_aes_x86.c rktcrypto_aes_modes.c rktcrypto_aes_ctr_vaes.S rktcrypto_ghash_vpclmul.S rktcrypto_gcm_vaes.S rktcrypto_chacha20_avx512.S rktcrypto_poly1305_x86.S rktcrypto_chacha20poly1305_x86.S \
         rktcrypto_x86.c rktcrypto_cpu.c rktcrypto_gcm.c rktcrypto_ccm.c rktcrypto_ct.c */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include "rktcrypto_cipher.h"
#include "rktcrypto_cpu.h"

static uint64_t st = 0x1234567890abcdefULL;
static unsigned rnd(void) { st = st * 6364136223846793005ULL + 1; return (unsigned)(st >> 33); }
static void fill(unsigned char *b, int n) { int i; for (i = 0; i < n; i++) b[i] = (unsigned char)rnd(); }
static long bad = 0, tot = 0;
static void check(const char *what, const void *a, const void *b, long n, int kl, long len)
{
  tot++;
  if (memcmp(a, b, (size_t)n) != 0) { bad++; if (bad <= 10) printf("MISMATCH %s kl=%d len=%ld\n", what, kl, len); }
}
static void checki(const char *what, int a, int b, int kl, long len)
{
  tot++;
  if (a != b) { bad++; if (bad <= 10) printf("MISMATCH %s rc %d vs %d kl=%d len=%ld\n", what, a, b, kl, len); }
}

#define BUF 5000
static unsigned char key[64], iv[16], in[BUF], aad[256], oa[BUF + 16], ob[BUF + 16], pa[BUF], pb[BUF];

int main(void)
{
  unsigned hw = rktcrypto_cpu_features();
  const int ks[3] = {16, 24, 32};
  int t, kl, sel;
  long len, alen;
  printf("cpu features 0x%x (AES-NI %s, PCLMUL %s)\n", hw,
         (hw & RKTCRYPTO_CPU_X86_AESNI) ? "yes" : "NO", (hw & RKTCRYPTO_CPU_X86_PCLMUL) ? "yes" : "NO");
  if (!(hw & RKTCRYPTO_CPU_X86_AESNI)) { printf("no AES-NI: nothing to compare\n"); return 2; }
  for (t = 0; t < 4000; t++) {
    kl = ks[rnd() % 3];
    fill(key, 64); fill(iv, 16);
    sel = rnd() % 4;
    len = (sel == 0) ? (long)(rnd() % 64) : (sel == 1) ? (long)(rnd() % 600) : (sel == 2) ? (long)(128 * (rnd() % 30)) : (long)(rnd() % BUF);
    if (len == 0 && (rnd() & 1)) len = 1;
    alen = rnd() % 200;
    fill(in, (int)len); fill(aad, (int)alen);
    {
      unsigned char rka[240], rkb[240], ba[16], bb[16];
      int nra, nrb;
      rktcrypto_cpu_override_features(hw, 1);
      nra = rktcrypto_aes_expand_key(key, kl, rka);
      rktcrypto_aes_enc_block(rka, nra, iv, ba);
      rktcrypto_cpu_override_features(0, 1);
      nrb = rktcrypto_aes_expand_key(key, kl, rkb);
      rktcrypto_aes_enc_block(rkb, nrb, iv, bb);
      checki("expand Nr", nra, nrb, kl, len);
      check("expand rk", rka, rkb, 16 * (nrb + 1), kl, len);
      check("enc block", ba, bb, 16, kl, len);
    }
    /* CTR, any length */
    rktcrypto_cpu_override_features(hw, 1); rktcrypto_aes_ctr(key, kl, iv, in, oa, len);
    rktcrypto_cpu_override_features(0, 1);  rktcrypto_aes_ctr(key, kl, iv, in, ob, len);
    check("ctr", oa, ob, len, kl, len);
    /* CBC enc/dec, block-aligned */
    if (len >= 16) {
      long blk = (len / 16) * 16;
      rktcrypto_cpu_override_features(hw, 1); rktcrypto_aes_cbc_encrypt(key, kl, iv, in, oa, blk);
      rktcrypto_cpu_override_features(0, 1);  rktcrypto_aes_cbc_encrypt(key, kl, iv, in, ob, blk);
      check("cbc-enc", oa, ob, blk, kl, blk);
      rktcrypto_cpu_override_features(hw, 1); rktcrypto_aes_cbc_decrypt(key, kl, iv, oa, pa, blk);
      rktcrypto_cpu_override_features(0, 1);  rktcrypto_aes_cbc_decrypt(key, kl, iv, oa, pb, blk);
      check("cbc-dec", pa, pb, blk, kl, blk);
      check("cbc-dec roundtrip", pa, in, blk, kl, blk);
    }
    /* CMAC */
    { unsigned char ta[16], tb[16];
      rktcrypto_cpu_override_features(hw, 1); rktcrypto_aes_cmac(key, kl, in, len, ta);
      rktcrypto_cpu_override_features(0, 1);  rktcrypto_aes_cmac(key, kl, in, len, tb);
      check("cmac", ta, tb, 16, kl, len); }
    /* XTS (key sizes 16/32; len >= 16) */
    if ((kl == 16 || kl == 32) && len >= 16) {
      rktcrypto_cpu_override_features(hw, 1); rktcrypto_aes_xts(key, kl, iv, in, oa, len, 1);
      rktcrypto_cpu_override_features(0, 1);  rktcrypto_aes_xts(key, kl, iv, in, ob, len, 1);
      check("xts-enc", oa, ob, len, kl, len);
      rktcrypto_cpu_override_features(hw, 1); rktcrypto_aes_xts(key, kl, iv, oa, pa, len, 0);
      rktcrypto_cpu_override_features(0, 1);  rktcrypto_aes_xts(key, kl, iv, oa, pb, len, 0);
      check("xts-dec", pa, pb, len, kl, len);
      check("xts-dec roundtrip", pa, in, len, kl, len);
    }
    /* GCM / CCM (key sizes 16 and 32 only; nonce = iv[0..12)) */
    if (kl == 16 || kl == 32) {
      int ra, rb;
      if (kl == 32) {
        rktcrypto_cpu_override_features(hw, 1); ra = rktcrypto_aes256gcm_seal(key, iv, aad, 0, alen, in, 0, len, oa, 0);
        rktcrypto_cpu_override_features(0, 1);  rb = rktcrypto_aes256gcm_seal(key, iv, aad, 0, alen, in, 0, len, ob, 0);
      } else {
        rktcrypto_cpu_override_features(hw, 1); ra = rktcrypto_aes128gcm_seal(key, iv, aad, 0, alen, in, 0, len, oa, 0);
        rktcrypto_cpu_override_features(0, 1);  rb = rktcrypto_aes128gcm_seal(key, iv, aad, 0, alen, in, 0, len, ob, 0);
      }
      checki("gcm-seal rc", ra, rb, kl, len);
      check("gcm-seal ct+tag", oa, ob, len + 16, kl, len);
      if (kl == 32) {
        rktcrypto_cpu_override_features(hw, 1); ra = rktcrypto_aes256gcm_open(key, iv, aad, 0, alen, oa, 0, len + 16, pa, 0);
        rktcrypto_cpu_override_features(0, 1);  rb = rktcrypto_aes256gcm_open(key, iv, aad, 0, alen, oa, 0, len + 16, pb, 0);
      } else {
        rktcrypto_cpu_override_features(hw, 1); ra = rktcrypto_aes128gcm_open(key, iv, aad, 0, alen, oa, 0, len + 16, pa, 0);
        rktcrypto_cpu_override_features(0, 1);  rb = rktcrypto_aes128gcm_open(key, iv, aad, 0, alen, oa, 0, len + 16, pb, 0);
      }
      checki("gcm-open rc", ra, rb, kl, len); checki("gcm-open accepted", ra, 1, kl, len);
      check("gcm-open pt", pa, in, len, kl, len);
      oa[len] ^= 1;   /* tamper the tag: both must reject */
      rktcrypto_cpu_override_features(hw, 1);
      ra = (kl == 32) ? rktcrypto_aes256gcm_open(key, iv, aad, 0, alen, oa, 0, len + 16, pa, 0)
                      : rktcrypto_aes128gcm_open(key, iv, aad, 0, alen, oa, 0, len + 16, pa, 0);
      checki("gcm-open tamper rejected", ra, 0, kl, len);
      /* CCM */
      if (kl == 32) {
        rktcrypto_cpu_override_features(hw, 1); ra = rktcrypto_aes256ccm_seal(key, iv, aad, 0, alen, in, 0, len, oa, 0);
        rktcrypto_cpu_override_features(0, 1);  rb = rktcrypto_aes256ccm_seal(key, iv, aad, 0, alen, in, 0, len, ob, 0);
      } else {
        rktcrypto_cpu_override_features(hw, 1); ra = rktcrypto_aes128ccm_seal(key, iv, aad, 0, alen, in, 0, len, oa, 0);
        rktcrypto_cpu_override_features(0, 1);  rb = rktcrypto_aes128ccm_seal(key, iv, aad, 0, alen, in, 0, len, ob, 0);
      }
      checki("ccm-seal rc", ra, rb, kl, len);
      check("ccm-seal ct+tag", oa, ob, len + 16, kl, len);
      rktcrypto_cpu_override_features(hw, 1);
      ra = (kl == 32) ? rktcrypto_aes256ccm_open(key, iv, aad, 0, alen, oa, 0, len + 16, pa, 0)
                      : rktcrypto_aes128ccm_open(key, iv, aad, 0, alen, oa, 0, len + 16, pa, 0);
      checki("ccm-open accepted", ra, 1, kl, len);
      check("ccm-open pt", pa, in, len, kl, len);
    }
  }
  rktcrypto_cpu_override_features(0, 0);
  printf("%ld/%ld mismatches\n", bad, tot);
  printf("%s\n", bad ? "FAIL" : "PASS");
  return bad ? 1 : 0;
}
