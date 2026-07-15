#ifndef __RKTCRYPTO_H__
#define __RKTCRYPTO_H__ 1

/*

The rktcrypto library is Racket's built-in cryptography subsystem. It
is a static library parallel to rktio, linked into the Racket
executable for both the CS and BC backends, with bindings generated
by "../rktio/parse.rkt" (which recognizes the RKTCRYPTO_ macro
vocabulary in addition to RKTIO_).

Conventions:

 - All functions are stateless or use only internal, thread-safe
   state; any function can be called concurrently with anything else.
   No `rktio_t`-style context is needed.

 - Buffer arguments follow the rktio SHA convention: a byte-string
   pointer plus `start` and `end` offsets, so callers can pass Racket
   byte strings without copying.

 - Functions never allocate memory that the caller must free.

 - A return type `int` used as a boolean is 1 for success/true and 0
   for failure/false; no further error information is available,
   deliberately, so that failures cannot be distinguished by callers
   (or by timing).

 - Functions that operate on secret data are constant-time with
   respect to the secret contents: no data-dependent branches or
   memory indexing. Constant-time discipline is with respect to
   buffer *contents*; buffer *lengths* are not treated as secrets.

*/

#include <stdint.h>
#include <stddef.h>

#ifndef RKTCRYPTO_EXTERN
# define RKTCRYPTO_EXTERN extern
#endif

#define RKTCRYPTO_EXTERN_NOERR RKTCRYPTO_EXTERN

/*************************************************/
/* System entropy                                */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_system_random(unsigned char *buf, intptr_t start, intptr_t end);
/* Fills `buf[start..end)` with cryptographically secure random bytes
   from the operating system (getentropy, getrandom, BCryptGenRandom,
   or /dev/urandom as a last resort). Returns 1 on success, 0 on
   failure; on failure, the buffer contents are unspecified and must
   not be used. */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_random_bytes(unsigned char *buf, intptr_t start, intptr_t end);
/* Like rktcrypto_system_random, but served from a per-thread ChaCha20
   generator seeded from the OS: much faster for frequent small
   requests, forward-secret (each request re-keys), and reseeded after
   fork() so a parent and child never share state. This is the default
   source for `crypto-random-bytes`. Returns 1 on success, 0 on a
   seeding failure. */

/*************************************************/
/* Constant-time utilities                       */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_ct_bytes_equal(const unsigned char *a, intptr_t a_start, const unsigned char *b, intptr_t b_start, intptr_t len);
/* Compares `a[a_start..a_start+len)` and `b[b_start..b_start+len)`
   in constant time with respect to the buffer contents. Returns 1 if
   equal, 0 otherwise. `len` is not treated as a secret. */

RKTCRYPTO_EXTERN_NOERR void rktcrypto_secure_clear(unsigned char *buf, intptr_t start, intptr_t end);
/* Zeroes `buf[start..end)` in a way that will not be elided by
   compiler optimization (memset_s, explicit_bzero,
   SecureZeroMemory, or a volatile fallback). */

/*************************************************/
/* Message digests                               */

/* Algorithm ids. These become Racket-side constants via parse.rkt. */
#define RKTCRYPTO_SHA224      1
#define RKTCRYPTO_SHA256      2
#define RKTCRYPTO_SHA384      3
#define RKTCRYPTO_SHA512      4
#define RKTCRYPTO_SHA512_256  5
#define RKTCRYPTO_SHA3_224    6
#define RKTCRYPTO_SHA3_256    7
#define RKTCRYPTO_SHA3_384    8
#define RKTCRYPTO_SHA3_512    9
#define RKTCRYPTO_SHAKE128   10
#define RKTCRYPTO_SHAKE256   11
#define RKTCRYPTO_BLAKE2B    12
#define RKTCRYPTO_BLAKE3     13

/* Upper bound on the incremental context size across all algorithms;
   Racket allocates a byte string of at least this many bytes to hold
   a digest context. (BLAKE3's CV stack dominates.) */
#define RKTCRYPTO_DIGEST_CTX_MAXSIZE 2048

RKTCRYPTO_EXTERN_NOERR intptr_t rktcrypto_digest_ctx_size(int alg);
/* Bytes needed to hold a context for `alg`, or 0 if `alg` is unknown. */

RKTCRYPTO_EXTERN_NOERR intptr_t rktcrypto_digest_size(int alg);
/* Default output size in bytes, or 0 for extendable-output functions
   (SHAKE), or -1 if `alg` is unknown. */

RKTCRYPTO_EXTERN_NOERR intptr_t rktcrypto_digest_block_size(int alg);
/* Input block size in bytes (for HMAC), or -1 if `alg` is unknown. */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_digest_is_xof(int alg);
/* 1 if `alg` is an extendable-output function, else 0. */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_digest_init(int alg, unsigned char *ctx, intptr_t ctx_len, intptr_t outlen);
/* Initialize `ctx` for `alg`. `outlen` sets the output length for
   BLAKE2b and the default for SHAKE; ignored for fixed-size hashes.
   Returns 1 on success, 0 on bad algorithm/size. */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_digest_update(int alg, unsigned char *ctx, intptr_t ctx_len,
                                                   const unsigned char *data, intptr_t start, intptr_t end);
/* Absorb data[start..end). Returns 1 on success, 0 on bad arguments. */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_digest_final(int alg, unsigned char *ctx, intptr_t ctx_len,
                                                  unsigned char *out, intptr_t out_start, intptr_t out_len);
/* Write out_len output bytes to out[out_start..]. For fixed-size
   hashes out_len must equal the digest size; for SHAKE it may be any
   length. Returns 1 on success, 0 on bad arguments. */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_digest_oneshot(int alg,
                                                    const unsigned char *data, intptr_t start, intptr_t end,
                                                    unsigned char *out, intptr_t out_start, intptr_t out_len);
/* One-shot init/update/final. Returns 1 on success, 0 on bad arguments. */

/*************************************************/
/* Authenticated encryption (AEAD)               */

#define RKTCRYPTO_AEAD_CHACHA20_POLY1305   1
#define RKTCRYPTO_AEAD_XCHACHA20_POLY1305  2
#define RKTCRYPTO_AEAD_AES256_GCM          3

RKTCRYPTO_EXTERN_NOERR intptr_t rktcrypto_aead_key_size(int alg);
/* Key size in bytes, or -1 if `alg` is unknown. */

RKTCRYPTO_EXTERN_NOERR intptr_t rktcrypto_aead_nonce_size(int alg);
/* Nonce size in bytes, or -1 if `alg` is unknown. */

RKTCRYPTO_EXTERN_NOERR intptr_t rktcrypto_aead_tag_size(int alg);
/* Authentication tag size in bytes, or -1 if `alg` is unknown. */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_aead_seal(int alg,
                                               const unsigned char *key, intptr_t key_len,
                                               const unsigned char *nonce, intptr_t nonce_len,
                                               const unsigned char *aad, intptr_t aad_start, intptr_t aad_end,
                                               const unsigned char *pt, intptr_t pt_start, intptr_t pt_end,
                                               unsigned char *out, intptr_t out_start);
/* Encrypts and authenticates; writes ciphertext followed by the tag
   to out[out_start..]. `out` must hold (pt_len + tag_size) bytes.
   Returns 1 on success, 0 on bad algorithm/key/nonce size. */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_aead_open(int alg,
                                               const unsigned char *key, intptr_t key_len,
                                               const unsigned char *nonce, intptr_t nonce_len,
                                               const unsigned char *aad, intptr_t aad_start, intptr_t aad_end,
                                               const unsigned char *ct, intptr_t ct_start, intptr_t ct_end,
                                               unsigned char *out, intptr_t out_start);
/* Verifies and decrypts ct[ct_start..ct_end) (ciphertext followed by
   tag) to out[out_start..]. Returns 1 on success, 0 if authentication
   fails or on bad arguments; on failure `out` is not written. */

/*************************************************/
/* Argon2id password hashing                     */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_argon2id(const unsigned char *pwd, intptr_t pwdlen,
                                              const unsigned char *salt, intptr_t saltlen,
                                              const unsigned char *secret, intptr_t secretlen,
                                              const unsigned char *ad, intptr_t adlen,
                                              intptr_t t_cost, intptr_t m_cost, intptr_t parallelism,
                                              unsigned char *out, intptr_t outlen);
/* Argon2id (RFC 9106). `secret` and `ad` may be NULL with length 0.
   t_cost is the iteration count, m_cost the memory in kibibytes,
   parallelism the number of lanes. Returns 1 on success, 0 on invalid
   parameters or allocation failure. */

/*************************************************/
/* SipHash keyed PRF                             */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_siphash(const unsigned char *key, intptr_t key_len,
                                             int crounds, int drounds,
                                             const unsigned char *data, intptr_t start, intptr_t end,
                                             unsigned char *out, intptr_t out_start);
/* Computes SipHash-crounds-drounds of data[start..end) under a 16-byte
   key, writing 8 little-endian bytes to out[out_start..]. Use (2,4)
   for SipHash-2-4 and (1,3) for SipHash-1-3. Returns 1, or 0 on a bad
   key length or range. */

/*************************************************/
/* Self-test                                     */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_selftest_core(void);
/* Runs known-answer tests for the core utilities. Returns 1 if all
   pass, 0 otherwise. Cheap enough to run at startup or first use. */

#endif
