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

#endif
