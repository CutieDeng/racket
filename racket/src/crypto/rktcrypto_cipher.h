#ifndef __RKTCRYPTO_CIPHER_H__
#define __RKTCRYPTO_CIPHER_H__

/* Internal symmetric-cipher and MAC interfaces for the rktcrypto
   subsystem. The public AEAD dispatch in rktcrypto.h builds on these. */

#include "rktcrypto_private.h"

/* ---- ChaCha20 (RFC 8439) ---- */

/* Produces the ChaCha20 keystream for `len` bytes and XORs it into
   out[0..len) from in[0..len). key is 32 bytes, nonce is 12 bytes,
   `counter` is the initial 32-bit block counter. in and out may alias
   exactly (in == out) for in-place operation. */
void rktcrypto_chacha20_xor(const unsigned char key[32],
                            const unsigned char nonce[12],
                            uint32_t counter,
                            const unsigned char *in, unsigned char *out,
                            intptr_t len);

/* Writes one 64-byte ChaCha20 keystream block for the given counter
   (used to derive the Poly1305 one-time key). */
void rktcrypto_chacha20_block(const unsigned char key[32],
                              const unsigned char nonce[12],
                              uint32_t counter,
                              unsigned char out[64]);

/* HChaCha20: derives a 32-byte subkey from a 32-byte key and a 16-byte
   nonce (used by XChaCha20). */
void rktcrypto_hchacha20(const unsigned char key[32],
                         const unsigned char nonce16[16],
                         unsigned char subkey[32]);

/* ---- Poly1305 (RFC 8439) ---- */

typedef struct rktcrypto_poly1305_ctx_t {
  uint32_t r[5];
  uint32_t h[5];
  uint32_t pad[4];
  unsigned char buffer[16];
  intptr_t buf_len;
} rktcrypto_poly1305_ctx_t;

/* key is the 32-byte one-time key (r || s). */
void rktcrypto_poly1305_init(rktcrypto_poly1305_ctx_t *ctx, const unsigned char key[32]);
void rktcrypto_poly1305_update(rktcrypto_poly1305_ctx_t *ctx,
                               const unsigned char *data, intptr_t len);
void rktcrypto_poly1305_final(rktcrypto_poly1305_ctx_t *ctx, unsigned char tag[16]);

#if defined(__aarch64__)
/* Fused ChaCha20 (en/decrypt) + Poly1305 absorb over whole 512-byte units,
   interleaved so the SIMD keystream and the scalar MAC run concurrently. Writes
   in..in+consumed to out; folds the ciphertext (out if encrypt, else in) into
   `poly` (its 16-byte buffer must be empty). Returns whole-unit bytes consumed
   (multiple of 512); the caller finishes the tail with the two-pass path. */
intptr_t rktcrypto_chacha20poly1305_fused(const unsigned char key[32], const unsigned char nonce[12],
                                          const unsigned char *in, unsigned char *out, intptr_t len,
                                          int encrypt, rktcrypto_poly1305_ctx_t *poly);
#endif

/* ---- AES-256 (FIPS 197), encryption only, constant-time ---- */

void rktcrypto_aes256_expand_key(const unsigned char key[32], unsigned char rk[240]);
void rktcrypto_aes256_encrypt_block(const unsigned char rk[240],
                                    const unsigned char in[16],
                                    unsigned char out[16]);

/* ---- AES-256-GCM (SP 800-38D), 12-byte nonce ---- */

int rktcrypto_aes256gcm_seal(const unsigned char key[32], const unsigned char nonce[12],
                             const unsigned char *aad, intptr_t aad_start, intptr_t aad_end,
                             const unsigned char *pt, intptr_t pt_start, intptr_t pt_end,
                             unsigned char *out, intptr_t out_start);
int rktcrypto_aes256gcm_open(const unsigned char key[32], const unsigned char nonce[12],
                             const unsigned char *aad, intptr_t aad_start, intptr_t aad_end,
                             const unsigned char *ct, intptr_t ct_start, intptr_t ct_end,
                             unsigned char *out, intptr_t out_start);

#endif
