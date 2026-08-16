#ifndef __RKTCRYPTO_DIGEST_H__
#define __RKTCRYPTO_DIGEST_H__

/* Internal digest interfaces for the rktcrypto subsystem. The public,
   binding-generated API in rktcrypto.h dispatches to these. Each
   algorithm family exposes fixed-size context structs so that Racket
   can hold the context in a byte string with no malloc/free across
   the FFI boundary.

   API contract: every context struct is flat and position-independent
   -- no pointers (internal or external), no heap allocation, all
   state inline -- so a byte-for-byte copy of a context is a valid
   independent fork of the digest state at any point in the stream.
   `digest-copy` at the Racket level relies on this to hash many
   inputs sharing a common prefix without recomputation; any new
   algorithm added here must preserve the property. */

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

/* ---- SHA-1 (FIPS 180-4) and MD5 (RFC 1321): legacy, broken ---- */

typedef struct rktcrypto_sha1_ctx_t {
  uint32_t h[5];
  uint64_t len;         /* message length in bits */
  unsigned char buf[64];
  intptr_t buf_len;
} rktcrypto_sha1_ctx_t;

void rktcrypto_sha1_core_init(rktcrypto_sha1_ctx_t *ctx);
void rktcrypto_sha1_core_update(rktcrypto_sha1_ctx_t *ctx,
                                const unsigned char *data, intptr_t len);
void rktcrypto_sha1_core_final(rktcrypto_sha1_ctx_t *ctx,
                               unsigned char *out, intptr_t out_len);

typedef struct rktcrypto_md5_ctx_t {
  uint32_t h[4];
  uint64_t len;         /* message length in bits */
  unsigned char buf[64];
  intptr_t buf_len;
} rktcrypto_md5_ctx_t;

void rktcrypto_md5_core_init(rktcrypto_md5_ctx_t *ctx);
void rktcrypto_md5_core_update(rktcrypto_md5_ctx_t *ctx,
                               const unsigned char *data, intptr_t len);
void rktcrypto_md5_core_final(rktcrypto_md5_ctx_t *ctx,
                              unsigned char *out, intptr_t out_len);

/* ---- MD4 (RFC 1320): legacy, broken ---- */

typedef struct rktcrypto_md4_ctx_t {
  uint32_t h[4];
  uint64_t len;         /* message length in bits */
  unsigned char buf[64];
  intptr_t buf_len;
} rktcrypto_md4_ctx_t;

void rktcrypto_md4_core_init(rktcrypto_md4_ctx_t *ctx);
void rktcrypto_md4_core_update(rktcrypto_md4_ctx_t *ctx,
                               const unsigned char *data, intptr_t len);
void rktcrypto_md4_core_final(rktcrypto_md4_ctx_t *ctx,
                              unsigned char *out, intptr_t out_len);

/* ---- RIPEMD-160 (ISO/IEC 10118-3) ---- */

typedef struct rktcrypto_rmd160_ctx_t {
  uint32_t h[5];
  uint64_t len;         /* message length in bits */
  unsigned char buf[64];
  intptr_t buf_len;
} rktcrypto_rmd160_ctx_t;

void rktcrypto_rmd160_core_init(rktcrypto_rmd160_ctx_t *ctx);
void rktcrypto_rmd160_core_update(rktcrypto_rmd160_ctx_t *ctx,
                                  const unsigned char *data, intptr_t len);
void rktcrypto_rmd160_core_final(rktcrypto_rmd160_ctx_t *ctx,
                                 unsigned char *out, intptr_t out_len);

/* ---- SM3 (GB/T 32905-2016) ---- */

typedef struct rktcrypto_sm3_ctx_t {
  uint32_t h[8];
  uint64_t len;         /* message length in bits */
  unsigned char buf[64];
  intptr_t buf_len;
} rktcrypto_sm3_ctx_t;

void rktcrypto_sm3_core_init(rktcrypto_sm3_ctx_t *ctx);
void rktcrypto_sm3_core_update(rktcrypto_sm3_ctx_t *ctx,
                               const unsigned char *data, intptr_t len);
void rktcrypto_sm3_core_final(rktcrypto_sm3_ctx_t *ctx,
                              unsigned char *out, intptr_t out_len);

/* ---- Whirlpool (ISO/IEC 10118-3, final 2003 version) ---- */

typedef struct rktcrypto_whirlpool_ctx_t {
  uint64_t h[8];
  uint64_t len;         /* message length in bits (< 2^64) */
  unsigned char buf[64];
  intptr_t buf_len;
} rktcrypto_whirlpool_ctx_t;

void rktcrypto_whirlpool_core_init(rktcrypto_whirlpool_ctx_t *ctx);
void rktcrypto_whirlpool_core_update(rktcrypto_whirlpool_ctx_t *ctx,
                                     const unsigned char *data, intptr_t len);
void rktcrypto_whirlpool_core_final(rktcrypto_whirlpool_ctx_t *ctx,
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

/* ---- KMAC128 / KMAC256 (SP 800-185), fixed-output variant ----
   key/msg/cust may be empty (pass len 0); cust is the customization
   string S. Writes outlen bytes to out (bound into the tag). */
void rktcrypto_kmac128(const unsigned char *key, intptr_t klen,
                       const unsigned char *msg, intptr_t mlen,
                       const unsigned char *cust, intptr_t clen,
                       unsigned char *out, intptr_t outlen);
void rktcrypto_kmac256(const unsigned char *key, intptr_t klen,
                       const unsigned char *msg, intptr_t mlen,
                       const unsigned char *cust, intptr_t clen,
                       unsigned char *out, intptr_t outlen);

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

/* ---- BLAKE3 (official specification) ---- */

#define RKTCRYPTO_BLAKE3_MAX_DEPTH 54

typedef struct rktcrypto_blake3_ctx_t {
  uint32_t key[8];
  /* chunk state */
  uint32_t cv[8];
  unsigned char block[64];
  uint8_t block_len;
  uint8_t blocks_compressed;      /* blocks compressed in the current chunk */
  uint64_t chunk_counter;
  /* CV stack: one slot (8 words) per set bit of the chunk count */
  uint32_t cv_stack[(RKTCRYPTO_BLAKE3_MAX_DEPTH + 1) * 8];
  uint8_t cv_stack_len;           /* number of CVs on the stack */
} rktcrypto_blake3_ctx_t;

void rktcrypto_blake3_core_init(rktcrypto_blake3_ctx_t *ctx);
void rktcrypto_blake3_core_update(rktcrypto_blake3_ctx_t *ctx,
                                  const unsigned char *data, intptr_t len);
void rktcrypto_blake3_core_final(rktcrypto_blake3_ctx_t *ctx,
                                 unsigned char *out, intptr_t out_len);

#endif
