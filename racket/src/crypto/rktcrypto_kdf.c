/* Key-derivation functions over the built-in digests: HMAC (one-shot),
   HKDF (RFC 5869) extract/expand, the TLS 1.3 HKDF-Expand-Label
   (RFC 8446), SP 800-108 counter-mode KBKDF, SP 800-56C one-step SSKDF,
   and the ANSI X9.63 KDF.

   All are thin, non-secret-dependent constructions over the C digest
   cores and this file's HMAC, so the Racket KDF layer can call them
   directly instead of looping in interpreted code. From scratch, no
   external code. */

#include "rktcrypto.h"
#include <string.h>
#include <stdint.h>
#include <stdlib.h>

/* One-shot HMAC over any fixed-size built-in digest (out is the digest
   size). key may be longer than the block size (it is pre-hashed). */
void rktcrypto_hmac(int alg, const unsigned char *key, intptr_t keylen,
                    const unsigned char *msg, intptr_t msglen, unsigned char *out)
{
  intptr_t bs = rktcrypto_digest_block_size(alg);
  intptr_t ds = rktcrypto_digest_size(alg);
  intptr_t cl = rktcrypto_digest_ctx_size(alg);
  unsigned char k0[168], ik[168], ok[168], kh[64], ih[64];
  unsigned char ctx[RKTCRYPTO_DIGEST_CTX_MAXSIZE];
  intptr_t i;

  if (bs <= 0 || bs > (intptr_t)sizeof k0 || ds <= 0) return;
  if (keylen > bs) { rktcrypto_digest_oneshot(alg, key, 0, keylen, kh, 0, ds); key = kh; keylen = ds; }
  memset(k0, 0, bs); memcpy(k0, key, keylen);
  for (i = 0; i < bs; i++) { ik[i] = k0[i] ^ 0x36; ok[i] = k0[i] ^ 0x5c; }
  rktcrypto_digest_init(alg, ctx, cl, ds);
  rktcrypto_digest_update(alg, ctx, cl, ik, 0, bs);
  rktcrypto_digest_update(alg, ctx, cl, msg, 0, msglen);
  rktcrypto_digest_final(alg, ctx, cl, ih, 0, ds);
  rktcrypto_digest_init(alg, ctx, cl, ds);
  rktcrypto_digest_update(alg, ctx, cl, ok, 0, bs);
  rktcrypto_digest_update(alg, ctx, cl, ih, 0, ds);
  rktcrypto_digest_final(alg, ctx, cl, out, 0, ds);
}

/* HKDF-Extract: PRK = HMAC(salt, ikm); an empty salt is hlen zero bytes. */
void rktcrypto_hkdf_extract(int alg, const unsigned char *ikm, intptr_t ikmlen,
                            const unsigned char *salt, intptr_t saltlen, unsigned char *prk)
{
  unsigned char z[64];
  intptr_t ds = rktcrypto_digest_size(alg);
  if (saltlen == 0) { memset(z, 0, ds); salt = z; saltlen = ds; }
  rktcrypto_hmac(alg, salt, saltlen, ikm, ikmlen, prk);
}

/* HKDF-Expand: OKM = T(1) || T(2) || ...  T(i) = HMAC(PRK, T(i-1)||info||i). */
int rktcrypto_hkdf_expand(int alg, const unsigned char *prk, intptr_t prklen,
                          const unsigned char *info, intptr_t infolen,
                          unsigned char *out, intptr_t outlen)
{
  intptr_t ds = rktcrypto_digest_size(alg);
  unsigned char t[64];
  unsigned char *buf;
  intptr_t tl = 0, off = 0;
  unsigned int c = 1;

  if (outlen > 255 * ds) return 0;
  buf = malloc(ds + infolen + 1);
  if (!buf) return 0;
  while (off < outlen) {
    intptr_t n, o = 0;
    if (tl) { memcpy(buf, t, tl); o = tl; }
    memcpy(buf + o, info, infolen); o += infolen;
    buf[o++] = (unsigned char)c;
    rktcrypto_hmac(alg, prk, prklen, buf, o, t); tl = ds;
    n = outlen - off; if (n > ds) n = ds;
    memcpy(out + off, t, n); off += n; c++;
  }
  free(buf);
  return 1;
}

int rktcrypto_hkdf(int alg, const unsigned char *ikm, intptr_t ikmlen,
                   const unsigned char *salt, intptr_t saltlen,
                   const unsigned char *info, intptr_t infolen,
                   unsigned char *out, intptr_t outlen)
{
  unsigned char prk[64];
  rktcrypto_hkdf_extract(alg, ikm, ikmlen, salt, saltlen, prk);
  return rktcrypto_hkdf_expand(alg, prk, rktcrypto_digest_size(alg), info, infolen, out, outlen);
}

/* TLS 1.3 HKDF-Expand-Label (RFC 8446 sec 7.1):
     HkdfLabel = uint16(len) || uint8(6+llen) || "tls13 "||label
                 || uint8(clen) || context
     out = HKDF-Expand(secret, HkdfLabel, len) */
int rktcrypto_tls13_expand_label(int alg, const unsigned char *secret, intptr_t secretlen,
                                 const unsigned char *label, intptr_t labellen,
                                 const unsigned char *context, intptr_t contextlen,
                                 unsigned char *out, intptr_t outlen)
{
  unsigned char hl[2 + 1 + 6 + 255 + 1 + 255];
  intptr_t o = 0, i;
  if (labellen > 249 || contextlen > 255 || outlen > 65535) return 0;
  hl[o++] = (unsigned char)(outlen >> 8); hl[o++] = (unsigned char)outlen;
  hl[o++] = (unsigned char)(6 + labellen);
  memcpy(hl + o, "tls13 ", 6); o += 6;
  memcpy(hl + o, label, labellen); o += labellen;
  hl[o++] = (unsigned char)contextlen;
  for (i = 0; i < contextlen; i++) hl[o++] = context[i];
  return rktcrypto_hkdf_expand(alg, secret, secretlen, hl, o, out, outlen);
}

/* SP 800-108 counter-mode KBKDF with HMAC. Fixed input (OpenSSL default):
     counter(be32) || label || 0x00 || context || L(be32, in bits) */
int rktcrypto_kbkdf_hmac(int alg, const unsigned char *key, intptr_t keylen,
                         const unsigned char *label, intptr_t labellen,
                         const unsigned char *context, intptr_t contextlen,
                         unsigned char *out, intptr_t outlen)
{
  intptr_t ds = rktcrypto_digest_size(alg);
  uint32_t L = (uint32_t)outlen * 8, i = 1;
  unsigned char t[64], *fx;
  intptr_t off = 0, flen = 4 + labellen + 1 + contextlen + 4;

  fx = malloc(flen);
  if (!fx) return 0;
  while (off < outlen) {
    intptr_t n, o = 0;
    fx[o++]=(unsigned char)(i>>24); fx[o++]=(unsigned char)(i>>16); fx[o++]=(unsigned char)(i>>8); fx[o++]=(unsigned char)i;
    memcpy(fx+o, label, labellen); o += labellen;
    fx[o++] = 0;
    memcpy(fx+o, context, contextlen); o += contextlen;
    fx[o++]=(unsigned char)(L>>24); fx[o++]=(unsigned char)(L>>16); fx[o++]=(unsigned char)(L>>8); fx[o++]=(unsigned char)L;
    rktcrypto_hmac(alg, key, keylen, fx, o, t);
    n = outlen - off; if (n > ds) n = ds;
    memcpy(out + off, t, n); off += n; i++;
  }
  free(fx);
  return 1;
}

/* SP 800-56C one-step KDF (hash variant): K = H(counter||Z||info) || ... */
int rktcrypto_sskdf(int alg, const unsigned char *z, intptr_t zlen,
                    const unsigned char *info, intptr_t infolen,
                    unsigned char *out, intptr_t outlen)
{
  intptr_t ds = rktcrypto_digest_size(alg);
  unsigned char t[64], *b;
  intptr_t off = 0; uint32_t c = 1;
  b = malloc(4 + zlen + infolen);
  if (!b) return 0;
  while (off < outlen) {
    intptr_t n, o = 0;
    b[o++]=(unsigned char)(c>>24); b[o++]=(unsigned char)(c>>16); b[o++]=(unsigned char)(c>>8); b[o++]=(unsigned char)c;
    memcpy(b+o, z, zlen); o += zlen; memcpy(b+o, info, infolen); o += infolen;
    rktcrypto_digest_oneshot(alg, b, 0, o, t, 0, ds);
    n = outlen - off; if (n > ds) n = ds;
    memcpy(out + off, t, n); off += n; c++;
  }
  free(b);
  return 1;
}

/* ANSI X9.63 KDF (hash): K = H(Z||counter||info) || ... */
int rktcrypto_x963kdf(int alg, const unsigned char *z, intptr_t zlen,
                      const unsigned char *info, intptr_t infolen,
                      unsigned char *out, intptr_t outlen)
{
  intptr_t ds = rktcrypto_digest_size(alg);
  unsigned char t[64], *b;
  intptr_t off = 0; uint32_t c = 1;
  b = malloc(zlen + 4 + infolen);
  if (!b) return 0;
  while (off < outlen) {
    intptr_t n, o = 0;
    memcpy(b+o, z, zlen); o += zlen;
    b[o++]=(unsigned char)(c>>24); b[o++]=(unsigned char)(c>>16); b[o++]=(unsigned char)(c>>8); b[o++]=(unsigned char)c;
    memcpy(b+o, info, infolen); o += infolen;
    rktcrypto_digest_oneshot(alg, b, 0, o, t, 0, ds);
    n = outlen - off; if (n > ds) n = ds;
    memcpy(out + off, t, n); off += n; c++;
  }
  free(b);
  return 1;
}
