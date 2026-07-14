#ifndef __RKTCRYPTO_DIGEST_H__
#define __RKTCRYPTO_DIGEST_H__

/* Internal digest interfaces for the rktcrypto subsystem. The public,
   binding-generated API in rktcrypto.h dispatches to these. Each
   algorithm family exposes fixed-size context structs so that Racket
   can hold the context in a byte string with no malloc/free across
   the FFI boundary. */

#include "rktcrypto_private.h"

/* ---- SHA-224 / SHA-256 (FIPS 180-4) ---- */

typedef struct rktcrypto_sha256_ctx_t {
  uint32_t h[8];
  uint64_t len;         /* message length in bits */
  unsigned char buf[64];
  intptr_t buf_len;
} rktcrypto_sha256_ctx_t;

extern const uint32_t rktcrypto_sha256_iv[8];
extern const uint32_t rktcrypto_sha224_iv[8];

void rktcrypto_sha256_core_init(rktcrypto_sha256_ctx_t *ctx, const uint32_t iv[8]);
void rktcrypto_sha256_core_update(rktcrypto_sha256_ctx_t *ctx,
                                  const unsigned char *data, intptr_t len);
void rktcrypto_sha256_core_final(rktcrypto_sha256_ctx_t *ctx,
                                 unsigned char *out, intptr_t out_len);

/* ---- SHA-384 / SHA-512 / SHA-512-256 (FIPS 180-4) ---- */

typedef struct rktcrypto_sha512_ctx_t {
  uint64_t h[8];
  uint64_t len_hi;      /* message length in bits, high 64 */
  uint64_t len_lo;      /* message length in bits, low 64 */
  unsigned char buf[128];
  intptr_t buf_len;
} rktcrypto_sha512_ctx_t;

extern const uint64_t rktcrypto_sha512_iv[8];
extern const uint64_t rktcrypto_sha384_iv[8];
extern const uint64_t rktcrypto_sha512_256_iv[8];

void rktcrypto_sha512_core_init(rktcrypto_sha512_ctx_t *ctx, const uint64_t iv[8]);
void rktcrypto_sha512_core_update(rktcrypto_sha512_ctx_t *ctx,
                                  const unsigned char *data, intptr_t len);
void rktcrypto_sha512_core_final(rktcrypto_sha512_ctx_t *ctx,
                                 unsigned char *out, intptr_t out_len);

/* ---- SHA-3 and SHAKE (FIPS 202), Keccak-f[1600] ---- */

typedef struct rktcrypto_keccak_ctx_t {
  uint64_t state[25];   /* 1600-bit sponge state */
  intptr_t rate;        /* rate in bytes (block size) */
  intptr_t pos;         /* bytes absorbed into current block */
  unsigned char pad;    /* domain-separation byte: 0x06 SHA-3, 0x1f SHAKE */
} rktcrypto_keccak_ctx_t;

/* rate is 200 - 2*capacity/8 bytes; e.g. SHA3-256 -> 136, SHAKE256 -> 136 */
void rktcrypto_keccak_core_init(rktcrypto_keccak_ctx_t *ctx, intptr_t rate, unsigned char pad);
void rktcrypto_keccak_core_update(rktcrypto_keccak_ctx_t *ctx,
                                  const unsigned char *data, intptr_t len);
/* Squeeze out_len bytes (any length, for XOF); for fixed SHA-3 pass the
   digest size. Must be called at most once per context. */
void rktcrypto_keccak_core_final(rktcrypto_keccak_ctx_t *ctx,
                                 unsigned char *out, intptr_t out_len);

/* ---- BLAKE2b (RFC 7693) ---- */

typedef struct rktcrypto_blake2b_ctx_t {
  uint64_t h[8];
  uint64_t t[2];        /* message byte counter (128-bit) */
  unsigned char buf[128];
  intptr_t buf_len;
  intptr_t outlen;      /* digest length in bytes, 1..64 */
} rktcrypto_blake2b_ctx_t;

/* Initialize for `outlen`-byte output (1..64). If keylen > 0, the key
   is absorbed as the first block for keyed hashing (MAC); keylen 1..64. */
void rktcrypto_blake2b_core_init(rktcrypto_blake2b_ctx_t *ctx, intptr_t outlen,
                                 const unsigned char *key, intptr_t keylen);
void rktcrypto_blake2b_core_update(rktcrypto_blake2b_ctx_t *ctx,
                                   const unsigned char *data, intptr_t len);
void rktcrypto_blake2b_core_final(rktcrypto_blake2b_ctx_t *ctx,
                                  unsigned char *out, intptr_t out_len);

#endif
