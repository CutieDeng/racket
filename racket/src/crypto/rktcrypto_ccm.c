/* AES-CCM (RFC 3610 / NIST SP 800-38C) — 12-byte nonce (L=3), 16-byte tag.
   The hot full-block CTR+CBC-MAC pass is the rktasm kernel in
   rktcrypto_ccm_asm.S (ccm_bulk_{seal,open}_asm); this file owns B0/AAD
   formatting, the S0 tag, and the final partial block, and provides the
   portable bulk that is BOTH the non-Apple fallback and the differential
   oracle for the kernel (asm/tests/test_ccm.c). CCM always authenticates the
   plaintext: seal MACs the input, open MACs the decrypted output. */
#include "rktcrypto.h"
#include "rktcrypto_cipher.h"
#include <string.h>
#include <stdint.h>

#if defined(__aarch64__) && defined(__APPLE__)
extern void ccm_bulk_seal_asm(const unsigned char *rk, intptr_t Nr, unsigned char X[16],
                              unsigned char ctr[16], const unsigned char *in,
                              unsigned char *out, intptr_t nblocks);
extern void ccm_bulk_open_asm(const unsigned char *rk, intptr_t Nr, unsigned char X[16],
                              unsigned char ctr[16], const unsigned char *in,
                              unsigned char *out, intptr_t nblocks);
#endif

/* Portable mirror of the kernels (oracle + non-Apple path). mac_out=0: MAC the
   input (seal); mac_out=1: MAC the produced output (open). */
static void ccm_bulk_portable(const unsigned char *rk, int Nr, unsigned char X[16],
                              unsigned char ctr[16], const unsigned char *in,
                              unsigned char *out, intptr_t nblocks, int mac_out) {
  intptr_t b;
  for (b = 0; b < nblocks; b++) {
    unsigned char S[16]; const unsigned char *ib = in + 16*b, *macp;
    unsigned char *ob = out + 16*b; uint64_t c; int i;
    rktcrypto_aes_enc_block(rk, Nr, ctr, S);
    for (i = 0; i < 16; i++) ob[i] = (unsigned char)(ib[i] ^ S[i]);
    c = 0; for (i = 0; i < 8; i++) c = (c << 8) | ctr[8 + i];
    c++; for (i = 0; i < 8; i++) ctr[15 - i] = (unsigned char)(c >> (8 * i));
    macp = mac_out ? ob : ib;
    for (i = 0; i < 16; i++) X[i] ^= macp[i];
    rktcrypto_aes_enc_block(rk, Nr, X, X);
  }
}

static void ccm_bulk_seal(const unsigned char *rk, int Nr, unsigned char X[16],
                          unsigned char ctr[16], const unsigned char *in,
                          unsigned char *out, intptr_t nblocks) {
#if defined(__aarch64__) && defined(__APPLE__)
  ccm_bulk_seal_asm(rk, Nr, X, ctr, in, out, nblocks);
#else
  ccm_bulk_portable(rk, Nr, X, ctr, in, out, nblocks, 0);
#endif
}
static void ccm_bulk_open(const unsigned char *rk, int Nr, unsigned char X[16],
                          unsigned char ctr[16], const unsigned char *in,
                          unsigned char *out, intptr_t nblocks) {
#if defined(__aarch64__) && defined(__APPLE__)
  ccm_bulk_open_asm(rk, Nr, X, ctr, in, out, nblocks);
#else
  ccm_bulk_portable(rk, Nr, X, ctr, in, out, nblocks, 1);
#endif
}

/* Silence -Wunused when both bulk paths route to the kernel (Apple). */
static void ccm_bulk_portable_ref(void) __attribute__((unused));
static void ccm_bulk_portable_ref(void) { (void)ccm_bulk_portable; }

#define CCM_N 12          /* nonce bytes */
#define CCM_M 16          /* tag bytes   */
#define CCM_L (15 - CCM_N)/* length field bytes (=3) */

static void ccm_ctr_block(const unsigned char *nonce, uint64_t counter, unsigned char A[16]) {
  int i;
  A[0] = (unsigned char)(CCM_L - 1);
  for (i = 0; i < CCM_N; i++) A[1 + i] = nonce[i];
  for (i = 0; i < CCM_L; i++) A[15 - i] = (unsigned char)(counter >> (8 * i));
}

/* CBC-MAC init: X = E(B0); then fold the length-prefixed AAD, zero-padded. */
static void ccm_mac_header(const unsigned char *rk, int Nr, const unsigned char *nonce,
                           intptr_t alen, intptr_t mlen, const unsigned char *aad,
                           unsigned char X[16]) {
  unsigned char B0[16], hdr[10]; int i, hlen = 0, bi;
  B0[0] = (unsigned char)((alen > 0 ? 0x40 : 0) | (((CCM_M - 2) / 2) << 3) | (CCM_L - 1));
  for (i = 0; i < CCM_N; i++) B0[1 + i] = nonce[i];
  for (i = 0; i < CCM_L; i++) B0[15 - i] = (unsigned char)((uint64_t)mlen >> (8 * i));
  rktcrypto_aes_enc_block(rk, Nr, B0, X);
  if (alen <= 0) return;
  if (alen < 0xFF00) {
    hdr[0] = (unsigned char)(alen >> 8); hdr[1] = (unsigned char)alen; hlen = 2;
  } else if ((uint64_t)alen <= 0xFFFFFFFFULL) {
    hdr[0] = 0xFF; hdr[1] = 0xFE;
    hdr[2] = (unsigned char)(alen >> 24); hdr[3] = (unsigned char)(alen >> 16);
    hdr[4] = (unsigned char)(alen >> 8);  hdr[5] = (unsigned char)alen; hlen = 6;
  } else {
    hdr[0] = 0xFF; hdr[1] = 0xFF;
    for (i = 0; i < 8; i++) hdr[2 + i] = (unsigned char)((uint64_t)alen >> (8 * (7 - i)));
    hlen = 10;
  }
  bi = 0;
  for (i = 0; i < hlen; i++) { X[bi] ^= hdr[i]; if (++bi == 16) { rktcrypto_aes_enc_block(rk, Nr, X, X); bi = 0; } }
  for (i = 0; i < alen; i++) { X[bi] ^= aad[i]; if (++bi == 16) { rktcrypto_aes_enc_block(rk, Nr, X, X); bi = 0; } }
  if (bi) rktcrypto_aes_enc_block(rk, Nr, X, X);
}

static int ccm_seal_core(const unsigned char *key, intptr_t keylen, const unsigned char *nonce,
                         const unsigned char *aad, intptr_t aad_start, intptr_t aad_end,
                         const unsigned char *pt, intptr_t pt_start, intptr_t pt_end,
                         unsigned char *out, intptr_t out_start) {
  unsigned char rk[240], X[16], ctr[16], S[16], A0[16], S0[16], padded[16];
  const unsigned char *A = aad + aad_start, *P = pt + pt_start;
  unsigned char *O = out + out_start;
  intptr_t alen = aad_end - aad_start, mlen = pt_end - pt_start, nfull, tail, i;
  int Nr;
  if (alen < 0 || mlen < 0) return 0;
  if ((uint64_t)mlen >> (8 * CCM_L)) return 0;            /* too long for L=3 */
  Nr = rktcrypto_aes_expand_key(key, keylen, rk);
  ccm_mac_header(rk, Nr, nonce, alen, mlen, A, X);
  ccm_ctr_block(nonce, 1, ctr);                           /* payload counter A_1 */
  nfull = mlen / 16; tail = mlen % 16;
  ccm_bulk_seal(rk, Nr, X, ctr, P, O, nfull);
  if (tail) {
    rktcrypto_aes_enc_block(rk, Nr, ctr, S);              /* keystream for tail */
    for (i = 0; i < tail; i++) O[nfull * 16 + i] = (unsigned char)(P[nfull * 16 + i] ^ S[i]);
    memset(padded, 0, 16); memcpy(padded, P + nfull * 16, (size_t)tail);
    for (i = 0; i < 16; i++) X[i] ^= padded[i];
    rktcrypto_aes_enc_block(rk, Nr, X, X);
  }
  ccm_ctr_block(nonce, 0, A0);
  rktcrypto_aes_enc_block(rk, Nr, A0, S0);
  for (i = 0; i < CCM_M; i++) O[mlen + i] = (unsigned char)(X[i] ^ S0[i]);
  return 1;
}

static int ccm_open_core(const unsigned char *key, intptr_t keylen, const unsigned char *nonce,
                         const unsigned char *aad, intptr_t aad_start, intptr_t aad_end,
                         const unsigned char *ct, intptr_t ct_start, intptr_t ct_end,
                         unsigned char *out, intptr_t out_start) {
  unsigned char rk[240], X[16], ctr[16], S[16], A0[16], S0[16], padded[16], T[16];
  const unsigned char *A = aad + aad_start, *C = ct + ct_start, *tagp;
  unsigned char *O = out + out_start;
  intptr_t alen = aad_end - aad_start, clen = ct_end - ct_start, mlen, nfull, tail, i;
  int Nr; unsigned char diff = 0;
  if (alen < 0 || clen < CCM_M) return 0;
  mlen = clen - CCM_M; tagp = C + mlen;
  if ((uint64_t)mlen >> (8 * CCM_L)) return 0;
  Nr = rktcrypto_aes_expand_key(key, keylen, rk);
  ccm_mac_header(rk, Nr, nonce, alen, mlen, A, X);
  ccm_ctr_block(nonce, 1, ctr);
  nfull = mlen / 16; tail = mlen % 16;
  ccm_bulk_open(rk, Nr, X, ctr, C, O, nfull);             /* decrypt + MAC plaintext */
  if (tail) {
    rktcrypto_aes_enc_block(rk, Nr, ctr, S);
    for (i = 0; i < tail; i++) O[nfull * 16 + i] = (unsigned char)(C[nfull * 16 + i] ^ S[i]);
    memset(padded, 0, 16); memcpy(padded, O + nfull * 16, (size_t)tail);
    for (i = 0; i < 16; i++) X[i] ^= padded[i];
    rktcrypto_aes_enc_block(rk, Nr, X, X);
  }
  ccm_ctr_block(nonce, 0, A0);
  rktcrypto_aes_enc_block(rk, Nr, A0, S0);
  for (i = 0; i < CCM_M; i++) T[i] = (unsigned char)(X[i] ^ S0[i]);
  for (i = 0; i < CCM_M; i++) diff |= (unsigned char)(T[i] ^ tagp[i]);
  if (diff) { memset(O, 0, (size_t)mlen); return 0; }     /* auth fail: release nothing */
  return 1;
}

int rktcrypto_aes256ccm_seal(const unsigned char key[32], const unsigned char nonce[12],
                             const unsigned char *aad, intptr_t aad_start, intptr_t aad_end,
                             const unsigned char *pt, intptr_t pt_start, intptr_t pt_end,
                             unsigned char *out, intptr_t out_start)
{ return ccm_seal_core(key, 32, nonce, aad, aad_start, aad_end, pt, pt_start, pt_end, out, out_start); }

int rktcrypto_aes256ccm_open(const unsigned char key[32], const unsigned char nonce[12],
                             const unsigned char *aad, intptr_t aad_start, intptr_t aad_end,
                             const unsigned char *ct, intptr_t ct_start, intptr_t ct_end,
                             unsigned char *out, intptr_t out_start)
{ return ccm_open_core(key, 32, nonce, aad, aad_start, aad_end, ct, ct_start, ct_end, out, out_start); }

int rktcrypto_aes128ccm_seal(const unsigned char key[16], const unsigned char nonce[12],
                             const unsigned char *aad, intptr_t aad_start, intptr_t aad_end,
                             const unsigned char *pt, intptr_t pt_start, intptr_t pt_end,
                             unsigned char *out, intptr_t out_start)
{ return ccm_seal_core(key, 16, nonce, aad, aad_start, aad_end, pt, pt_start, pt_end, out, out_start); }

int rktcrypto_aes128ccm_open(const unsigned char key[16], const unsigned char nonce[12],
                             const unsigned char *aad, intptr_t aad_start, intptr_t aad_end,
                             const unsigned char *ct, intptr_t ct_start, intptr_t ct_end,
                             unsigned char *out, intptr_t out_start)
{ return ccm_open_core(key, 16, nonce, aad, aad_start, aad_end, ct, ct_start, ct_end, out, out_start); }
