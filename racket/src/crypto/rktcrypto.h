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
/* Self-test                                     */

RKTCRYPTO_EXTERN_NOERR int rktcrypto_selftest_core(void);
/* Runs known-answer tests for the core utilities. Returns 1 if all
   pass, 0 otherwise. Cheap enough to run at startup or first use. */

#endif
