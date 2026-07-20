#ifndef RKTCRYPTO_FFC_H
#define RKTCRYPTO_FFC_H

/* Finite-field public-key algorithms over the bn layer: classic DSA
   (FIPS 186-4) and finite-field Diffie-Hellman over the RFC 7919
   (ffdhe) named groups. All values are big-endian byte strings; lengths
   are in bytes. Internal interfaces (like RSA): consumed by X.509/TLS
   and the self-tests, not exported through the Racket FFI surface. */

#include <stdint.h>
#include <stddef.h>

/* ---- DSA (FIPS 186-4), caller-supplied domain parameters ---- */

/* x_out gets qlen bytes (private key), y_out gets plen bytes (public).
   Returns 1 on success, 0 on failure (bad params / RNG failure). */
int rktcrypto_dsa_keygen(const unsigned char *p, intptr_t plen,
                         const unsigned char *q, intptr_t qlen,
                         const unsigned char *g, intptr_t glen,
                         unsigned char *x_out, unsigned char *y_out);

/* Signs `digest` (raw hash output; leftmost bits are used if longer than
   q). r_out and s_out each get qlen bytes. Returns 1 on success. */
int rktcrypto_dsa_sign(const unsigned char *p, intptr_t plen,
                       const unsigned char *q, intptr_t qlen,
                       const unsigned char *g, intptr_t glen,
                       const unsigned char *x, intptr_t xlen,
                       const unsigned char *digest, intptr_t dlen,
                       unsigned char *r_out, unsigned char *s_out);

/* Returns 1 iff (r,s) is a valid signature on digest under public key y. */
int rktcrypto_dsa_verify(const unsigned char *p, intptr_t plen,
                         const unsigned char *q, intptr_t qlen,
                         const unsigned char *g, intptr_t glen,
                         const unsigned char *y, intptr_t ylen,
                         const unsigned char *digest, intptr_t dlen,
                         const unsigned char *r, intptr_t rlen,
                         const unsigned char *s, intptr_t slen);

/* ---- Finite-field Diffie-Hellman, RFC 7919 named groups ---- */

#define RKTCRYPTO_FFDHE2048 2048
#define RKTCRYPTO_FFDHE3072 3072
#define RKTCRYPTO_FFDHE4096 4096

/* Returns the prime size in bytes for a named group id, or 0 if unknown. */
intptr_t rktcrypto_ffdhe_size(int group);

/* Generates a private/public pair for the named group. priv_out gets
   2*s bytes of private exponent material where s is the group's security
   level in bytes (RFC 7919 section 5.2); its actual length is written to
   *privlen. pub_out gets the full group size. Returns 1 on success. */
int rktcrypto_ffdhe_keygen(int group, unsigned char *priv_out, intptr_t *privlen,
                           unsigned char *pub_out);

/* Computes the shared secret from our private key and the peer's public
   value; out gets the full group size (leading zeros preserved).
   Returns 1 on success, 0 for an invalid peer key (out of range, or
   degenerate shared secret). */
int rktcrypto_ffdhe_derive(int group, const unsigned char *priv, intptr_t privlen,
                           const unsigned char *peer, intptr_t peerlen,
                           unsigned char *out);

#endif
