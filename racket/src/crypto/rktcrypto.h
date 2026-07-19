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
#define RKTCRYPTO_SHA1       14   /* legacy, broken; compatibility only */
#define RKTCRYPTO_MD5        15   /* legacy, broken; compatibility only */

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
   fails or on bad arguments. On authentication failure no valid plaintext
   is released -- `out` is either left unwritten or zeroed. */

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
/* PBKDF2 and scrypt password KDFs               */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_pbkdf2(int alg,
                                            const unsigned char *pw, intptr_t pwlen,
                                            const unsigned char *salt, intptr_t saltlen,
                                            uint32_t iterations,
                                            unsigned char *dk, intptr_t dklen);
/* PBKDF2-HMAC-<alg> (RFC 8018) for any fixed-size built-in digest.
   Returns 1 on success, 0 on bad algorithm or zero iterations. */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_scrypt(const unsigned char *pw, intptr_t pwlen,
                                            const unsigned char *salt, intptr_t saltlen,
                                            uint32_t N, uint32_t r, uint32_t p,
                                            unsigned char *dk, intptr_t dklen);
/* scrypt (RFC 7914). N must be a power of two > 1; r, p > 0. Allocates
   128*r*(N+p) bytes. Returns 1 on success, 0 on invalid parameters or
   allocation failure. */

/*************************************************/
/* HMAC, HKDF, and misc KDFs over the digests    */

RKTCRYPTO_EXTERN_NOERR void rktcrypto_hmac(int alg, const unsigned char *key, intptr_t keylen,
                                           const unsigned char *msg, intptr_t msglen, unsigned char *out);
/* One-shot HMAC-<alg>; out receives digest_size(alg) bytes. */

RKTCRYPTO_EXTERN_NOERR void rktcrypto_hkdf_extract(int alg, const unsigned char *ikm, intptr_t ikmlen,
                                                   const unsigned char *salt, intptr_t saltlen, unsigned char *prk);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_hkdf_expand(int alg, const unsigned char *prk, intptr_t prklen,
                                                 const unsigned char *info, intptr_t infolen,
                                                 unsigned char *out, intptr_t outlen);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_hkdf(int alg, const unsigned char *ikm, intptr_t ikmlen,
                                          const unsigned char *salt, intptr_t saltlen,
                                          const unsigned char *info, intptr_t infolen,
                                          unsigned char *out, intptr_t outlen);
/* HKDF (RFC 5869). Expand returns 0 if outlen > 255*digest_size. */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_tls13_expand_label(int alg, const unsigned char *secret, intptr_t secretlen,
                                                        const unsigned char *label, intptr_t labellen,
                                                        const unsigned char *context, intptr_t contextlen,
                                                        unsigned char *out, intptr_t outlen);
/* TLS 1.3 HKDF-Expand-Label (RFC 8446); prepends "tls13 " to label. */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_kbkdf_hmac(int alg, const unsigned char *key, intptr_t keylen,
                                                const unsigned char *label, intptr_t labellen,
                                                const unsigned char *context, intptr_t contextlen,
                                                unsigned char *out, intptr_t outlen);
/* SP 800-108 counter-mode KBKDF with HMAC (OpenSSL's fixed-input layout). */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_sskdf(int alg, const unsigned char *z, intptr_t zlen,
                                           const unsigned char *info, intptr_t infolen,
                                           unsigned char *out, intptr_t outlen);
/* SP 800-56C one-step KDF, hash variant. */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_x963kdf(int alg, const unsigned char *z, intptr_t zlen,
                                             const unsigned char *info, intptr_t infolen,
                                             unsigned char *out, intptr_t outlen);
/* ANSI X9.63 KDF (hash). */

/*************************************************/
/* TLS 1.3 protocol core (RFC 8446)              */
/* Key schedule, traffic-key derivation, Finished, and the AEAD record layer,
   built on the HKDF/HMAC/digest/AEAD primitives above. `alg` is the handshake
   hash (RKTCRYPTO_SHA256 / _SHA384). Verified byte-for-byte against the RFC
   8448 test vectors by rktcrypto_tls13_selftest(). */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_tls13_transcript_hash(int alg, const unsigned char *msgs,
                                                           intptr_t start, intptr_t end, unsigned char *out);
/* Transcript-Hash(messages) = Hash(msgs[start..end)). */

RKTCRYPTO_EXTERN_NOERR void rktcrypto_tls13_extract(int alg, const unsigned char *salt, intptr_t saltlen,
                                                    const unsigned char *ikm, intptr_t ikmlen, unsigned char *prk);
/* HKDF-Extract in TLS order (salt = prior secret, ikm = PSK/(EC)DHE); a NULL
   salt or ikm means Hash.length zero bytes. */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_tls13_derive_secret(int alg, const unsigned char *secret,
                                                         const unsigned char *label, intptr_t llen,
                                                         const unsigned char *thash, unsigned char *out);
/* Derive-Secret(Secret, Label, Messages); thash = Transcript-Hash(Messages). */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_tls13_traffic_keys(int alg, const unsigned char *secret,
                                                        unsigned char *key, intptr_t key_len,
                                                        unsigned char *iv, intptr_t iv_len);
/* key = Expand-Label(secret,"key",...); iv = Expand-Label(secret,"iv",...). */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_tls13_finished_key(int alg, const unsigned char *base_key, unsigned char *out);
RKTCRYPTO_EXTERN_NOERR void rktcrypto_tls13_verify_data(int alg, const unsigned char *finished_key,
                                                        const unsigned char *thash, unsigned char *out);
/* finished_key = Expand-Label(base_key,"finished",...); verify_data =
   HMAC(finished_key, Transcript-Hash(handshake up to this Finished)). */

RKTCRYPTO_EXTERN_NOERR void rktcrypto_tls13_record_nonce(const unsigned char *iv, intptr_t iv_len,
                                                         uint64_t seq, unsigned char *nonce);
/* Per-record nonce = static IV XOR left-padded 64-bit sequence number. */

RKTCRYPTO_EXTERN_NOERR intptr_t rktcrypto_tls13_record_seal(int aead, const unsigned char *key, intptr_t key_len,
                                                            const unsigned char *iv, intptr_t iv_len, uint64_t seq,
                                                            const unsigned char *inner, intptr_t inner_len,
                                                            unsigned char *out);
RKTCRYPTO_EXTERN_NOERR intptr_t rktcrypto_tls13_record_open(int aead, const unsigned char *key, intptr_t key_len,
                                                            const unsigned char *iv, intptr_t iv_len, uint64_t seq,
                                                            const unsigned char *rec, intptr_t rec_len,
                                                            unsigned char *out);
/* AEAD-protect / recover one TLSCiphertext record (5-byte header AAD, trailing
   content-type in the inner plaintext). seal returns record length or 0; open
   returns inner-plaintext length or -1 on auth failure. */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_tls13_selftest(void);
/* Returns 0 if the RFC 8448 key-schedule vectors and a record round-trip all
   pass, else a nonzero step index. */

/*************************************************/
/* X25519 key exchange (RFC 7748)                */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_x25519(unsigned char *out,
                                            const unsigned char *scalar,
                                            const unsigned char *point);
/* Computes the X25519 shared secret out = scalar * point on
   Curve25519. out, scalar, and point are all 32 bytes. Constant-time
   in the scalar. Returns 1 on success, 0 if the result is all-zero
   (a low-order input point), in which case the output must be
   rejected. */

/*************************************************/
/* X448 key exchange (RFC 7748)                  */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_x448(unsigned char *out, const unsigned char *scalar,
                                          const unsigned char *point);
/* X448 shared secret out = scalar*point on Curve448. All three are 56
   bytes. Returns 1, or 0 if the result is all-zero (low-order point). */
RKTCRYPTO_EXTERN_NOERR int rktcrypto_x448_pubkey(unsigned char *out, const unsigned char *scalar);
/* Public key = X448(scalar, 5); out and scalar are 56 bytes. */

/*************************************************/
/* Ed448 signatures (RFC 8032), pure mode        */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_ed448_pubkey(unsigned char *pk, const unsigned char *sk);
/* 57-byte public key from a 57-byte secret key. Returns 1. */
RKTCRYPTO_EXTERN_NOERR int rktcrypto_ed448_sign(unsigned char *sig,
                                                const unsigned char *msg, intptr_t msglen,
                                                const unsigned char *sk);
/* Deterministic 114-byte Ed448 signature (pure mode, empty context). Returns 1. */
RKTCRYPTO_EXTERN_NOERR int rktcrypto_ed448_verify(const unsigned char *sig,
                                                  const unsigned char *msg, intptr_t msglen,
                                                  const unsigned char *pk);
/* Verifies a 114-byte Ed448 signature. Returns 1 if valid, 0 otherwise. */

/*************************************************/
/* Ed25519 signatures (RFC 8032)                 */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_ed25519_pubkey(unsigned char *pk, const unsigned char *seed);
/* Derives the 32-byte public key from a 32-byte seed (private key). */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_ed25519_sign(unsigned char *sig,
                                                  const unsigned char *msg, intptr_t msglen,
                                                  const unsigned char *seed);
/* Signs msg[0..msglen) with the 32-byte seed, writing a 64-byte
   signature to sig. Constant-time in the secret. Returns 1. */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_ed25519_verify(const unsigned char *sig,
                                                    const unsigned char *msg, intptr_t msglen,
                                                    const unsigned char *pk);
/* Verifies a 64-byte signature over msg under the 32-byte public key.
   Returns 1 if valid, 0 otherwise. */

/*************************************************/
/* NIST P-256 (secp256r1)                        */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_p256_pubkey(unsigned char *out65, const unsigned char *priv);
/* Public key (65-byte uncompressed 0x04||x||y) from a 32-byte private
   scalar. Returns 1, or 0 for a degenerate key. */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_p256_ecdh(unsigned char *out, const unsigned char *scalar,
                                               const unsigned char *point65);
/* ECDH: writes the 32-byte x-coordinate of scalar*point to out.
   Returns 1, or 0 on a bad point or point at infinity. */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_p256_ecdsa_sign(unsigned char *sig,
                                                     const unsigned char *msg, intptr_t msglen,
                                                     const unsigned char *priv);
/* ECDSA-with-SHA-256: writes a 64-byte r||s signature. Uses a random
   nonce from the built-in CSPRNG. Returns 1, or 0 on failure. */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_p256_ecdsa_verify(const unsigned char *sig,
                                                       const unsigned char *msg, intptr_t msglen,
                                                       const unsigned char *pub65);
/* Verifies a 64-byte ECDSA signature. Returns 1 if valid, 0 otherwise. */

/*************************************************/
/* NIST P-384 (secp384r1) and P-521 (secp521r1)  */
/* Uncompressed points 0x04||x||y; ECDSA uses SHA-384 (P-384) / SHA-512
   (P-521). priv/coord widths: P-384 = 48 bytes, P-521 = 66 bytes. */
RKTCRYPTO_EXTERN_NOERR int rktcrypto_p384_pubkey(unsigned char *out97, const unsigned char *priv);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_p384_ecdh(unsigned char *out48, const unsigned char *scalar, const unsigned char *point97);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_p384_ecdsa_sign(unsigned char *sig96, const unsigned char *msg, intptr_t msglen, const unsigned char *priv);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_p384_ecdsa_verify(const unsigned char *sig96, const unsigned char *msg, intptr_t msglen, const unsigned char *pub97);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_p521_pubkey(unsigned char *out133, const unsigned char *priv);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_p521_ecdh(unsigned char *out66, const unsigned char *scalar, const unsigned char *point133);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_p521_ecdsa_sign(unsigned char *sig132, const unsigned char *msg, intptr_t msglen, const unsigned char *priv);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_p521_ecdsa_verify(const unsigned char *sig132, const unsigned char *msg, intptr_t msglen, const unsigned char *pub133);

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
/* ML-KEM-512 / 1024 (Kyber), FIPS 203           */

#define RKTCRYPTO_MLKEM512_PUBLICKEYBYTES   800
#define RKTCRYPTO_MLKEM512_SECRETKEYBYTES  1632
#define RKTCRYPTO_MLKEM512_CIPHERTEXTBYTES  768
#define RKTCRYPTO_MLKEM512_BYTES             32
#define RKTCRYPTO_MLKEM1024_PUBLICKEYBYTES  1568
#define RKTCRYPTO_MLKEM1024_SECRETKEYBYTES  3168
#define RKTCRYPTO_MLKEM1024_CIPHERTEXTBYTES 1568
#define RKTCRYPTO_MLKEM1024_BYTES             32

/* Same API shape as ML-KEM-768 below; derand keygen takes 64 coins (d||z),
   enc_derand a 32-byte message. Returns 1, or 0 on RNG failure. */
RKTCRYPTO_EXTERN_NOERR int rktcrypto_mlkem512_keypair(unsigned char *pk, unsigned char *sk);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_mlkem512_encaps(unsigned char *ct, unsigned char *ss, const unsigned char *pk);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_mlkem512_decaps(unsigned char *ss, const unsigned char *ct, const unsigned char *sk);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_mlkem512_keypair_derand(unsigned char *pk, unsigned char *sk, const unsigned char *coins);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_mlkem512_enc_derand(unsigned char *ct, unsigned char *ss, const unsigned char *pk, const unsigned char *m);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_mlkem1024_keypair(unsigned char *pk, unsigned char *sk);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_mlkem1024_encaps(unsigned char *ct, unsigned char *ss, const unsigned char *pk);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_mlkem1024_decaps(unsigned char *ss, const unsigned char *ct, const unsigned char *sk);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_mlkem1024_keypair_derand(unsigned char *pk, unsigned char *sk, const unsigned char *coins);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_mlkem1024_enc_derand(unsigned char *ct, unsigned char *ss, const unsigned char *pk, const unsigned char *m);

/*************************************************/
/* ML-KEM-768 (Kyber), FIPS 203                  */

#define RKTCRYPTO_MLKEM768_PUBLICKEYBYTES  1184
#define RKTCRYPTO_MLKEM768_SECRETKEYBYTES  2400
#define RKTCRYPTO_MLKEM768_CIPHERTEXTBYTES 1088
#define RKTCRYPTO_MLKEM768_BYTES           32

RKTCRYPTO_EXTERN_NOERR int rktcrypto_mlkem768_keypair(unsigned char *pk, unsigned char *sk);
/* Generates an ML-KEM-768 keypair using the built-in CSPRNG. pk is
   1184 bytes, sk is 2400 bytes. Returns 1, or 0 on RNG failure. */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_mlkem768_encaps(unsigned char *ct, unsigned char *ss,
                                                     const unsigned char *pk);
/* Encapsulates to public key pk, writing a 1088-byte ciphertext to ct
   and the 32-byte shared secret to ss, drawing the message from the
   built-in CSPRNG. Returns 1, or 0 on RNG failure. */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_mlkem768_decaps(unsigned char *ss,
                                                     const unsigned char *ct,
                                                     const unsigned char *sk);
/* Decapsulates ciphertext ct with secret key sk, writing the 32-byte
   shared secret to ss. Uses implicit rejection (FO transform), so a
   malformed ciphertext yields a pseudorandom secret rather than an
   error. Constant-time in the secret. Returns 1. */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_mlkem768_keypair_derand(unsigned char *pk, unsigned char *sk,
                                                             const unsigned char *coins);
/* Deterministic keygen from 64 bytes of coins (d||z), for known-answer
   tests. Returns 1. */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_mlkem768_enc_derand(unsigned char *ct, unsigned char *ss,
                                                         const unsigned char *pk,
                                                         const unsigned char *m);
/* Deterministic encapsulation from a 32-byte message m, for
   known-answer tests. Returns 1. */

/*************************************************/
/* ML-DSA-65 (Dilithium), FIPS 204               */

#define RKTCRYPTO_MLDSA44_PUBLICKEYBYTES 1312
#define RKTCRYPTO_MLDSA44_SECRETKEYBYTES 2560
#define RKTCRYPTO_MLDSA44_SIGBYTES       2420
#define RKTCRYPTO_MLDSA87_PUBLICKEYBYTES 2592
#define RKTCRYPTO_MLDSA87_SECRETKEYBYTES 4896
#define RKTCRYPTO_MLDSA87_SIGBYTES       4627

/* Same API shape as ML-DSA-65 below; derand keygen takes a 32-byte seed,
   sign_derand uses a zero randomizer (for known-answer tests). */
RKTCRYPTO_EXTERN_NOERR int rktcrypto_mldsa44_keypair(unsigned char *pk, unsigned char *sk);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_mldsa44_sign(unsigned char *sig, const unsigned char *m, intptr_t mlen, const unsigned char *sk);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_mldsa44_verify(const unsigned char *sig, const unsigned char *m, intptr_t mlen, const unsigned char *pk);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_mldsa44_keypair_derand(unsigned char *pk, unsigned char *sk, const unsigned char *seed);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_mldsa44_sign_derand(unsigned char *sig, const unsigned char *m, intptr_t mlen, const unsigned char *sk);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_mldsa87_keypair(unsigned char *pk, unsigned char *sk);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_mldsa87_sign(unsigned char *sig, const unsigned char *m, intptr_t mlen, const unsigned char *sk);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_mldsa87_verify(const unsigned char *sig, const unsigned char *m, intptr_t mlen, const unsigned char *pk);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_mldsa87_keypair_derand(unsigned char *pk, unsigned char *sk, const unsigned char *seed);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_mldsa87_sign_derand(unsigned char *sig, const unsigned char *m, intptr_t mlen, const unsigned char *sk);

#define RKTCRYPTO_MLDSA65_PUBLICKEYBYTES 1952
#define RKTCRYPTO_MLDSA65_SECRETKEYBYTES 4032
#define RKTCRYPTO_MLDSA65_SIGBYTES       3309

RKTCRYPTO_EXTERN_NOERR int rktcrypto_mldsa65_keypair(unsigned char *pk, unsigned char *sk);
/* Generates an ML-DSA-65 keypair using the built-in CSPRNG. pk is 1952
   bytes, sk is 4032 bytes. Returns 1, or 0 on RNG failure. */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_mldsa65_sign(unsigned char *sig,
                                                  const unsigned char *m, intptr_t mlen,
                                                  const unsigned char *sk);
/* Signs m[0..mlen) with secret key sk (pure ML-DSA, empty context),
   writing a 3309-byte signature to sig. Hedged: draws 32 random bytes
   from the CSPRNG, so signatures vary. Returns 1, or 0 on RNG failure. */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_mldsa65_verify(const unsigned char *sig,
                                                    const unsigned char *m, intptr_t mlen,
                                                    const unsigned char *pk);
/* Verifies a 3309-byte signature over m under public key pk. Returns 1
   if valid, 0 otherwise. */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_mldsa65_keypair_derand(unsigned char *pk, unsigned char *sk,
                                                            const unsigned char *seed);
/* Deterministic keygen from a 32-byte seed, for known-answer tests.
   Returns 1. */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_mldsa65_sign_derand(unsigned char *sig,
                                                         const unsigned char *m, intptr_t mlen,
                                                         const unsigned char *sk);
/* Deterministic signing (zero randomizer), for known-answer tests.
   Returns 1. */

/*************************************************/
/* SLH-DSA-SHAKE-128s (FIPS 205)                 */

#define RKTCRYPTO_SLHDSA_128S_PUBLICKEYBYTES 32
#define RKTCRYPTO_SLHDSA_128S_SECRETKEYBYTES 64
#define RKTCRYPTO_SLHDSA_128S_SIGBYTES       7856

RKTCRYPTO_EXTERN_NOERR int rktcrypto_slhdsa_shake_128s_keygen(unsigned char *pk, unsigned char *sk);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_slhdsa_shake_128s_keygen_derand(unsigned char *pk, unsigned char *sk, const unsigned char *seed48);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_slhdsa_shake_128s_sign(unsigned char *sig,
                                                            const unsigned char *msg, intptr_t msglen,
                                                            const unsigned char *sk);
RKTCRYPTO_EXTERN_NOERR int rktcrypto_slhdsa_shake_128s_verify(const unsigned char *sig, intptr_t siglen,
                                                              const unsigned char *msg, intptr_t msglen,
                                                              const unsigned char *pk);
/* SLH-DSA-SHAKE-128s (pure mode, empty context). keygen_derand takes 48
   seed bytes (SK.seed||SK.prf||PK.seed). Deterministic signing. */

/*************************************************/
/* PEM / DER / X.509 parsing                     */

RKTCRYPTO_EXTERN_NOERR intptr_t rktcrypto_base64_decode(const unsigned char *in, intptr_t inlen, unsigned char *out);
/* Decodes base64 (whitespace/'=' ignored). Returns byte count, or -1. out
   needs at most inlen*3/4 bytes. */
RKTCRYPTO_EXTERN_NOERR intptr_t rktcrypto_pem_to_der(const unsigned char *pem, intptr_t pemlen, unsigned char *out);
/* Extracts and base64-decodes the first PEM block's body. Returns DER length,
   or -1. */
RKTCRYPTO_EXTERN_NOERR int rktcrypto_x509_verify_selfsigned(const unsigned char *der, intptr_t derlen);
/* Parses an X.509 certificate (DER) and verifies its own signature under the
   embedded public key. Handles RSA PKCS#1 v1.5 SHA-256 and ECDSA-P-256
   SHA-256. Returns 1 if the signature is valid, 0 otherwise. */
RKTCRYPTO_EXTERN_NOERR int rktcrypto_cms_verify(const unsigned char *der, intptr_t derlen);
/* Verifies a CMS SignedData message (DER, RSA/SHA-256, embedded content, one
   signer): checks the signer's signature under the embedded certificate's key
   and that the messageDigest signed attribute equals SHA-256 of the
   encapsulated content. Returns 1 if valid, 0 otherwise. */

/*************************************************/
/* Self-test                                     */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_selftest_core(void);
/* Runs known-answer tests for the core utilities. Returns 1 if all
   pass, 0 otherwise. Cheap enough to run at startup or first use. */

#endif
