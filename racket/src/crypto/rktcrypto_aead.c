/* AEAD constructions for the rktcrypto subsystem.

   Currently ChaCha20-Poly1305 (RFC 8439) and its extended-nonce
   variant XChaCha20-Poly1305 (draft-irtf-cfrg-xchacha). Software
   ChaCha20-Poly1305 is constant-time. AES-GCM will be added as a
   separate construction. */

#include "rktcrypto.h"
#include "rktcrypto_cipher.h"
#include <string.h>

static void poly1305_pad16(rktcrypto_poly1305_ctx_t *ctx, intptr_t len)
{
  static const unsigned char zeros[16] = {0};
  intptr_t rem = len & 15;
  if (rem != 0)
    rktcrypto_poly1305_update(ctx, zeros, 16 - rem);
}

static void poly1305_le64(rktcrypto_poly1305_ctx_t *ctx, uint64_t v)
{
  unsigned char b[8];
  int i;
  for (i = 0; i < 8; i++) b[i] = (unsigned char)(v >> (8 * i));
  rktcrypto_poly1305_update(ctx, b, 8);
}

/* Computes the Poly1305 tag over aad || pad || ct || pad || lens. */
static void __attribute__((unused))
chacha20poly1305_tag(const unsigned char key[32],
                                 const unsigned char nonce[12],
                                 const unsigned char *aad, intptr_t aad_len,
                                 const unsigned char *ct, intptr_t ct_len,
                                 unsigned char tag[16])
{
  unsigned char otk[64];
  rktcrypto_poly1305_ctx_t poly;

  rktcrypto_chacha20_block(key, nonce, 0, otk);   /* one-time key = block 0 */
  rktcrypto_poly1305_init(&poly, otk);

  rktcrypto_poly1305_update(&poly, aad, aad_len);
  poly1305_pad16(&poly, aad_len);
  rktcrypto_poly1305_update(&poly, ct, ct_len);
  poly1305_pad16(&poly, ct_len);
  poly1305_le64(&poly, (uint64_t)aad_len);
  poly1305_le64(&poly, (uint64_t)ct_len);

  rktcrypto_poly1305_final(&poly, tag);
  rktcrypto_secure_clear(otk, 0, 64);
}

/* Encrypts plaintext[pt_start..pt_end) to out[out_start..], appending
   the 16-byte tag. `out` must have room for (pt_len + 16) bytes at
   out_start. Returns 1. */
static int rktcrypto_chacha20poly1305_seal(const unsigned char key[32],
                                    const unsigned char nonce[12],
                                    const unsigned char *aad, intptr_t aad_start, intptr_t aad_end,
                                    const unsigned char *pt, intptr_t pt_start, intptr_t pt_end,
                                    unsigned char *out, intptr_t out_start)
{
  intptr_t pt_len = pt_end - pt_start;
  intptr_t aad_len = aad_end - aad_start;
  unsigned char *ct = out + out_start;

  if (pt_len < 0 || aad_len < 0) return 0;

#if defined(__aarch64__)
  {
    /* Fused: ChaCha20 keystream and Poly1305 MAC run concurrently (separate
       execution ports), nearly hiding the MAC under the cipher. */
    unsigned char otk[64];
    rktcrypto_poly1305_ctx_t poly;
    intptr_t done;
    rktcrypto_chacha20_block(key, nonce, 0, otk);
    rktcrypto_poly1305_init(&poly, otk);
    rktcrypto_poly1305_update(&poly, aad + aad_start, aad_len);
    poly1305_pad16(&poly, aad_len);
    done = rktcrypto_chacha20poly1305_fused(key, nonce, pt + pt_start, ct, pt_len, 1, &poly);
    if (done < pt_len) {
      rktcrypto_chacha20_xor(key, nonce, (uint32_t)(1 + done / 64),
                             pt + pt_start + done, ct + done, pt_len - done);
      rktcrypto_poly1305_update(&poly, ct + done, pt_len - done);
    }
    poly1305_pad16(&poly, pt_len);
    poly1305_le64(&poly, (uint64_t)aad_len);
    poly1305_le64(&poly, (uint64_t)pt_len);
    rktcrypto_poly1305_final(&poly, ct + pt_len);
  }
#else
  rktcrypto_chacha20_xor(key, nonce, 1, pt + pt_start, ct, pt_len);
  chacha20poly1305_tag(key, nonce, aad + aad_start, aad_len, ct, pt_len, ct + pt_len);
#endif
  return 1;
}

/* Decrypts ct[ct_start..ct_end) (which includes the trailing 16-byte
   tag) to out[out_start..]. Returns 1 on success, 0 if authentication
   fails -- in which case the plaintext output is zeroed (never released). */
static int rktcrypto_chacha20poly1305_open(const unsigned char key[32],
                                    const unsigned char nonce[12],
                                    const unsigned char *aad, intptr_t aad_start, intptr_t aad_end,
                                    const unsigned char *ct, intptr_t ct_start, intptr_t ct_end,
                                    unsigned char *out, intptr_t out_start)
{
  intptr_t total = ct_end - ct_start;
  intptr_t aad_len = aad_end - aad_start;
  intptr_t ct_len;
  const unsigned char *cbody = ct + ct_start;
  unsigned char tag[16];

  if (total < 16 || aad_len < 0) return 0;
  ct_len = total - 16;

#if defined(__aarch64__)
  {
    /* Fused: Poly1305 authenticates the ciphertext while ChaCha20 decrypts it,
       both in one interleaved pass. The tag is verified afterwards; on failure
       the plaintext (already written) is zeroed so nothing unauthenticated
       leaves the function. */
    unsigned char otk[64];
    rktcrypto_poly1305_ctx_t poly;
    unsigned char *pt = out + out_start;
    intptr_t done;
    int i, ok;
    rktcrypto_chacha20_block(key, nonce, 0, otk);
    rktcrypto_poly1305_init(&poly, otk);
    rktcrypto_poly1305_update(&poly, aad + aad_start, aad_len);
    poly1305_pad16(&poly, aad_len);
    done = rktcrypto_chacha20poly1305_fused(key, nonce, cbody, pt, ct_len, 0, &poly);
    if (done < ct_len) {
      rktcrypto_chacha20_xor(key, nonce, (uint32_t)(1 + done / 64),
                             cbody + done, pt + done, ct_len - done);
      rktcrypto_poly1305_update(&poly, cbody + done, ct_len - done);
    }
    poly1305_pad16(&poly, ct_len);
    poly1305_le64(&poly, (uint64_t)aad_len);
    poly1305_le64(&poly, (uint64_t)ct_len);
    rktcrypto_poly1305_final(&poly, tag);
    ok = rktcrypto_ct_bytes_equal(tag, 0, cbody + ct_len, 0, 16);
    if (!ok) for (i = 0; i < ct_len; i++) pt[i] = 0;
    return ok;
  }
#else
  chacha20poly1305_tag(key, nonce, aad + aad_start, aad_len, cbody, ct_len, tag);
  if (!rktcrypto_ct_bytes_equal(tag, 0, cbody + ct_len, 0, 16))
    return 0;
  rktcrypto_chacha20_xor(key, nonce, 1, cbody, out + out_start, ct_len);
  return 1;
#endif
}

/* ---- XChaCha20-Poly1305 (24-byte nonce) ---- */

/* Derives the (subkey, 12-byte nonce) pair for an XChaCha20 operation
   from a 32-byte key and 24-byte nonce. */
static void xchacha20_subkey(const unsigned char key[32], const unsigned char nonce24[24],
                             unsigned char subkey[32], unsigned char subnonce[12])
{
  rktcrypto_hchacha20(key, nonce24, subkey);
  subnonce[0] = subnonce[1] = subnonce[2] = subnonce[3] = 0;
  memcpy(subnonce + 4, nonce24 + 16, 8);
}

static int rktcrypto_xchacha20poly1305_seal(const unsigned char key[32],
                                     const unsigned char nonce[24],
                                     const unsigned char *aad, intptr_t aad_start, intptr_t aad_end,
                                     const unsigned char *pt, intptr_t pt_start, intptr_t pt_end,
                                     unsigned char *out, intptr_t out_start)
{
  unsigned char subkey[32], subnonce[12];
  int r;
  xchacha20_subkey(key, nonce, subkey, subnonce);
  r = rktcrypto_chacha20poly1305_seal(subkey, subnonce, aad, aad_start, aad_end,
                                      pt, pt_start, pt_end, out, out_start);
  rktcrypto_secure_clear(subkey, 0, 32);
  return r;
}

static int rktcrypto_xchacha20poly1305_open(const unsigned char key[32],
                                     const unsigned char nonce[24],
                                     const unsigned char *aad, intptr_t aad_start, intptr_t aad_end,
                                     const unsigned char *ct, intptr_t ct_start, intptr_t ct_end,
                                     unsigned char *out, intptr_t out_start)
{
  unsigned char subkey[32], subnonce[12];
  int r;
  xchacha20_subkey(key, nonce, subkey, subnonce);
  r = rktcrypto_chacha20poly1305_open(subkey, subnonce, aad, aad_start, aad_end,
                                      ct, ct_start, ct_end, out, out_start);
  rktcrypto_secure_clear(subkey, 0, 32);
  return r;
}

/* ---- Public AEAD dispatch ---- */

intptr_t rktcrypto_aead_key_size(int alg)
{
  switch (alg) {
    case RKTCRYPTO_AEAD_CHACHA20_POLY1305:
    case RKTCRYPTO_AEAD_XCHACHA20_POLY1305:
    case RKTCRYPTO_AEAD_AES256_GCM: return 32;
    default: return -1;
  }
}

intptr_t rktcrypto_aead_nonce_size(int alg)
{
  switch (alg) {
    case RKTCRYPTO_AEAD_CHACHA20_POLY1305:  return 12;
    case RKTCRYPTO_AEAD_XCHACHA20_POLY1305: return 24;
    case RKTCRYPTO_AEAD_AES256_GCM:         return 12;
    default: return -1;
  }
}

intptr_t rktcrypto_aead_tag_size(int alg)
{
  switch (alg) {
    case RKTCRYPTO_AEAD_CHACHA20_POLY1305:
    case RKTCRYPTO_AEAD_XCHACHA20_POLY1305:
    case RKTCRYPTO_AEAD_AES256_GCM: return 16;
    default: return -1;
  }
}

int rktcrypto_aead_seal(int alg,
                        const unsigned char *key, intptr_t key_len,
                        const unsigned char *nonce, intptr_t nonce_len,
                        const unsigned char *aad, intptr_t aad_start, intptr_t aad_end,
                        const unsigned char *pt, intptr_t pt_start, intptr_t pt_end,
                        unsigned char *out, intptr_t out_start)
{
  if (key_len != rktcrypto_aead_key_size(alg)) return 0;
  if (nonce_len != rktcrypto_aead_nonce_size(alg)) return 0;
  switch (alg) {
    case RKTCRYPTO_AEAD_CHACHA20_POLY1305:
      return rktcrypto_chacha20poly1305_seal(key, nonce, aad, aad_start, aad_end,
                                             pt, pt_start, pt_end, out, out_start);
    case RKTCRYPTO_AEAD_XCHACHA20_POLY1305:
      return rktcrypto_xchacha20poly1305_seal(key, nonce, aad, aad_start, aad_end,
                                              pt, pt_start, pt_end, out, out_start);
    case RKTCRYPTO_AEAD_AES256_GCM:
      return rktcrypto_aes256gcm_seal(key, nonce, aad, aad_start, aad_end,
                                      pt, pt_start, pt_end, out, out_start);
    default: return 0;
  }
}

int rktcrypto_aead_open(int alg,
                        const unsigned char *key, intptr_t key_len,
                        const unsigned char *nonce, intptr_t nonce_len,
                        const unsigned char *aad, intptr_t aad_start, intptr_t aad_end,
                        const unsigned char *ct, intptr_t ct_start, intptr_t ct_end,
                        unsigned char *out, intptr_t out_start)
{
  if (key_len != rktcrypto_aead_key_size(alg)) return 0;
  if (nonce_len != rktcrypto_aead_nonce_size(alg)) return 0;
  switch (alg) {
    case RKTCRYPTO_AEAD_CHACHA20_POLY1305:
      return rktcrypto_chacha20poly1305_open(key, nonce, aad, aad_start, aad_end,
                                             ct, ct_start, ct_end, out, out_start);
    case RKTCRYPTO_AEAD_XCHACHA20_POLY1305:
      return rktcrypto_xchacha20poly1305_open(key, nonce, aad, aad_start, aad_end,
                                              ct, ct_start, ct_end, out, out_start);
    case RKTCRYPTO_AEAD_AES256_GCM:
      return rktcrypto_aes256gcm_open(key, nonce, aad, aad_start, aad_end,
                                      ct, ct_start, ct_end, out, out_start);
    default: return 0;
  }
}
