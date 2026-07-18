/* KMAC128 / KMAC256 (NIST SP 800-185).

   KMAC is a keyed MAC built on cSHAKE, which is Keccak with a distinct
   domain-separation pad byte (0x04) and a prefixed encoding of the
   function name "KMAC" and a caller-supplied customization string S.

     KMAC(K, X, L, S):
       T    = bytepad(encode_string("KMAC") || encode_string(S), rate)
       newX = bytepad(encode_string(K), rate) || X || right_encode(L)
       out  = cSHAKE(T || newX, L)          (Keccak with pad byte 0x04)

   rate is 168 bytes for KMAC128 and 136 for KMAC256. Lengths in the
   encodings are in BITS. This is the fixed-output (non-XOF) variant, in
   which the requested output length L is bound into the input via
   right_encode(L*8); it matches OpenSSL's EVP_MAC "KMAC-128"/"KMAC-256"
   with xof=0. From scratch, no external code. */

#include "rktcrypto_digest.h"
#include <string.h>

/* left_encode(x): a length-prefixed big-endian encoding -- first byte is
   the number of value bytes n, followed by n bytes, most significant
   first. right_encode is the same with the count byte at the end. */
static intptr_t kmac_left_encode(unsigned char *o, uint64_t x)
{
  unsigned char t[8];
  int n = 0;
  uint64_t v = x;
  do { t[n++] = (unsigned char)(v & 0xff); v >>= 8; } while (v);
  o[0] = (unsigned char)n;
  { int i; for (i = 0; i < n; i++) o[1 + i] = t[n - 1 - i]; }
  return n + 1;
}

static intptr_t kmac_right_encode(unsigned char *o, uint64_t x)
{
  unsigned char t[8];
  int n = 0;
  uint64_t v = x;
  do { t[n++] = (unsigned char)(v & 0xff); v >>= 8; } while (v);
  { int i; for (i = 0; i < n; i++) o[i] = t[n - 1 - i]; }
  o[n] = (unsigned char)n;
  return n + 1;
}

/* Absorbs encode_string(S) = left_encode(bitlen(S)) || S. */
static void kmac_absorb_string(rktcrypto_keccak_ctx_t *c,
                               const unsigned char *s, intptr_t slen,
                               intptr_t *bp)
{
  unsigned char e[9];
  intptr_t n = kmac_left_encode(e, (uint64_t)slen * 8);
  rktcrypto_keccak_core_update(c, e, n);
  *bp += n;
  if (slen) { rktcrypto_keccak_core_update(c, s, slen); *bp += slen; }
}

static void kmac_zero_pad(rktcrypto_keccak_ctx_t *c, intptr_t rate, intptr_t *bp)
{
  unsigned char z = 0;
  while (*bp % rate) { rktcrypto_keccak_core_update(c, &z, 1); (*bp)++; }
}

static void kmac_run(intptr_t rate,
                     const unsigned char *key, intptr_t klen,
                     const unsigned char *msg, intptr_t mlen,
                     const unsigned char *cust, intptr_t clen,
                     unsigned char *out, intptr_t outlen)
{
  rktcrypto_keccak_ctx_t c;
  unsigned char e[9];
  intptr_t bp, n;

  rktcrypto_keccak_core_init(&c, rate, 0x04);  /* cSHAKE domain pad */

  /* T = bytepad(encode_string("KMAC") || encode_string(S), rate) */
  bp = 0;
  n = kmac_left_encode(e, (uint64_t)rate);
  rktcrypto_keccak_core_update(&c, e, n); bp += n;
  kmac_absorb_string(&c, (const unsigned char *)"KMAC", 4, &bp);
  kmac_absorb_string(&c, cust, clen, &bp);
  kmac_zero_pad(&c, rate, &bp);

  /* bytepad(encode_string(K), rate) */
  bp = 0;
  n = kmac_left_encode(e, (uint64_t)rate);
  rktcrypto_keccak_core_update(&c, e, n); bp += n;
  kmac_absorb_string(&c, key, klen, &bp);
  kmac_zero_pad(&c, rate, &bp);

  /* X || right_encode(L*8) */
  if (mlen) rktcrypto_keccak_core_update(&c, msg, mlen);
  n = kmac_right_encode(e, (uint64_t)outlen * 8);
  rktcrypto_keccak_core_update(&c, e, n);

  rktcrypto_keccak_core_final(&c, out, outlen);
}

void rktcrypto_kmac128(const unsigned char *key, intptr_t klen,
                       const unsigned char *msg, intptr_t mlen,
                       const unsigned char *cust, intptr_t clen,
                       unsigned char *out, intptr_t outlen)
{
  kmac_run(168, key, klen, msg, mlen, cust, clen, out, outlen);
}

void rktcrypto_kmac256(const unsigned char *key, intptr_t klen,
                       const unsigned char *msg, intptr_t mlen,
                       const unsigned char *cust, intptr_t clen,
                       unsigned char *out, intptr_t outlen)
{
  kmac_run(136, key, klen, msg, mlen, cust, clen, out, outlen);
}
