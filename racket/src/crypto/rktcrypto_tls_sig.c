/* TLS signature schemes over the RSA core: RSASSA-PKCS1-v1_5 and RSASSA-PSS
   generalized over SHA-256/384/512, taking public keys as raw big-endian
   (n, e) components (as parsed out of an X.509 SubjectPublicKeyInfo) and
   private keys as PKCS#1 RSAPrivateKey DER. These are the entry points the
   rktcrypto TLS backend calls for certificate-chain and CertificateVerify /
   ServerKeyExchange signatures. From scratch, no external code. */

#include "rktcrypto.h"
#include "rktcrypto_bn.h"
#include "rktcrypto_rsa.h"
#include <string.h>

#define RSA_MAX 512   /* modulus bytes: up to RSA-4096 */

static intptr_t hash_len(int alg)
{
  switch (alg) {
    case RKTCRYPTO_SHA256: return 32;
    case RKTCRYPTO_SHA384: return 48;
    case RKTCRYPTO_SHA512: return 64;
    default: return 0;   /* only the TLS 1.2+ digests are accepted */
  }
}

/* DigestInfo prefixes (RFC 8017 sec 9.2 notes) */
static const unsigned char DI_SHA256[19] = {
  0x30,0x31,0x30,0x0d,0x06,0x09,0x60,0x86,0x48,0x01,0x65,0x03,0x04,0x02,0x01,0x05,0x00,0x04,0x20 };
static const unsigned char DI_SHA384[19] = {
  0x30,0x41,0x30,0x0d,0x06,0x09,0x60,0x86,0x48,0x01,0x65,0x03,0x04,0x02,0x02,0x05,0x00,0x04,0x30 };
static const unsigned char DI_SHA512[19] = {
  0x30,0x51,0x30,0x0d,0x06,0x09,0x60,0x86,0x48,0x01,0x65,0x03,0x04,0x02,0x03,0x05,0x00,0x04,0x40 };

static const unsigned char *digest_info(int alg)
{
  switch (alg) {
    case RKTCRYPTO_SHA256: return DI_SHA256;
    case RKTCRYPTO_SHA384: return DI_SHA384;
    default: return DI_SHA512;
  }
}

/* EMSA-PKCS1-v1_5: EM = 0x00 0x01 FF..FF 0x00 DigestInfo(alg) mHash.
   Returns 0 if the modulus is too small for the encoding. */
static int pkcs1_v15_encode(unsigned char *em, intptr_t klen, int alg, const unsigned char *mHash)
{
  intptr_t hlen = hash_len(alg), tlen = 19 + hlen, ps = klen - tlen - 3;
  if (ps < 8) return 0;
  em[0] = 0; em[1] = 1;
  memset(em + 2, 0xff, (size_t)ps);
  em[2 + ps] = 0;
  memcpy(em + 3 + ps, digest_info(alg), 19);
  memcpy(em + 3 + ps + 19, mHash, (size_t)hlen);
  return 1;
}

/* MGF1 over the scheme digest. seedlen <= 64. */
static void mgf1(int alg, unsigned char *mask, intptr_t masklen,
                 const unsigned char *seed, intptr_t seedlen)
{
  unsigned char buf[64 + 4], h[64];
  intptr_t hlen = hash_len(alg), off = 0;
  uint32_t c = 0;
  memcpy(buf, seed, (size_t)seedlen);
  while (off < masklen) {
    intptr_t n = masklen - off;
    buf[seedlen] = (unsigned char)(c >> 24); buf[seedlen+1] = (unsigned char)(c >> 16);
    buf[seedlen+2] = (unsigned char)(c >> 8); buf[seedlen+3] = (unsigned char)c;
    rktcrypto_digest_oneshot(alg, buf, 0, seedlen + 4, h, 0, hlen);
    if (n > hlen) n = hlen;
    memcpy(mask + off, h, (size_t)n);
    off += n;
    c++;
  }
}

/* EMSA-PSS-VERIFY (RFC 8017 sec 9.1.2) with MGF1 over the same digest and
   the salt length recovered from the encoding (OpenSSL "auto" behavior;
   covers both the TLS 1.3 sLen = hLen requirement and RFC 4055 certificate
   parameters). `m` is the RSA-public-recovered block of klen bytes. */
static int pss_verify_em(int alg, const unsigned char *m, intptr_t klen, int modbits,
                         const unsigned char *mHash)
{
  intptr_t hlen = hash_len(alg);
  intptr_t embits = modbits - 1, emlen = (embits + 7) / 8;
  intptr_t dblen = emlen - hlen - 1, slen, i;
  const unsigned char *em = m + (klen - emlen), *H, *salt;
  unsigned char db[RSA_MAX], dbmask[RSA_MAX], mp[8 + 64 + RSA_MAX], H2[64];
  int zerobits = (int)(8 * emlen - embits);
  if (emlen < hlen + 2) return 0;
  for (i = 0; i < klen - emlen; i++) if (m[i]) return 0;
  if (em[emlen - 1] != 0xbc) return 0;
  H = em + dblen;
  if (zerobits && (em[0] & (unsigned char)(0xFF << (8 - zerobits)))) return 0;
  mgf1(alg, dbmask, dblen, H, hlen);
  for (i = 0; i < dblen; i++) db[i] = em[i] ^ dbmask[i];
  db[0] &= (unsigned char)(0xFF >> zerobits);
  i = 0;
  while (i < dblen && db[i] == 0) i++;
  if (i == dblen || db[i] != 0x01) return 0;
  salt = db + i + 1; slen = dblen - i - 1;
  memset(mp, 0, 8);
  memcpy(mp + 8, mHash, (size_t)hlen);
  memcpy(mp + 8 + hlen, salt, (size_t)slen);
  rktcrypto_digest_oneshot(alg, mp, 0, 8 + hlen + slen, H2, 0, hlen);
  return memcmp(H, H2, (size_t)hlen) == 0;
}

/* EMSA-PSS-ENCODE with sLen = hLen (the TLS 1.3 requirement) and a fresh
   random salt. Writes the full klen-byte block to em. */
static int pss_encode(int alg, unsigned char *em, intptr_t klen, int modbits,
                      const unsigned char *mHash)
{
  intptr_t hlen = hash_len(alg);
  intptr_t embits = modbits - 1, emlen = (embits + 7) / 8;
  intptr_t dblen = emlen - hlen - 1, i;
  unsigned char salt[64], mp[8 + 64 + 64], H[64], db[RSA_MAX], dbmask[RSA_MAX];
  int zerobits = (int)(8 * emlen - embits);
  if (emlen < 2 * hlen + 2) return 0;
  if (!rktcrypto_random_bytes(salt, 0, hlen)) return 0;
  memset(mp, 0, 8);
  memcpy(mp + 8, mHash, (size_t)hlen);
  memcpy(mp + 8 + hlen, salt, (size_t)hlen);
  rktcrypto_digest_oneshot(alg, mp, 0, 8 + 2 * hlen, H, 0, hlen);
  memset(db, 0, (size_t)dblen);
  db[dblen - hlen - 1] = 0x01;
  memcpy(db + dblen - hlen, salt, (size_t)hlen);
  mgf1(alg, dbmask, dblen, H, hlen);
  for (i = 0; i < dblen; i++) db[i] ^= dbmask[i];
  db[0] &= (unsigned char)(0xFF >> zerobits);
  memset(em, 0, (size_t)(klen - emlen));
  memcpy(em + (klen - emlen), db, (size_t)dblen);
  memcpy(em + (klen - emlen) + dblen, H, (size_t)hlen);
  em[klen - 1] = 0xbc;
  return 1;
}

/* Builds a verify-only key from raw big-endian n and e. */
static int rsa_pub_from_raw(rsa_key *k, const unsigned char *n, intptr_t nlen,
                            const unsigned char *e, intptr_t elen)
{
  while (nlen > 1 && n[0] == 0) { n++; nlen--; }
  while (elen > 1 && e[0] == 0) { e++; elen--; }
  if (nlen < 128 || nlen > RSA_MAX || elen < 1 || elen > 16) return 0;
  if (!(n[nlen-1] & 1)) return 0;                 /* even modulus */
  memset(k, 0, sizeof *k);
  k->klen = (int)nlen;
  bn_from_be(&k->n, n, (int)nlen);
  bn_from_be(&k->e, e, (int)elen);
  if (bn_is_zero(&k->e)) return 0;
  bn_mont_setup(&k->n0_n, &k->rr_n, &k->n);
  return 1;
}

/* Verifies `sig` over `msg` under the raw (n,e) public key.
   pss = 0 for RSASSA-PKCS1-v1_5, 1 for RSASSA-PSS (MGF1 same digest, salt
   length recovered). Returns 1 iff valid. */
int rktcrypto_rsa_verify_msg(int pss, int alg,
                             const unsigned char *n, intptr_t nlen,
                             const unsigned char *e, intptr_t elen,
                             const unsigned char *msg, intptr_t msglen,
                             const unsigned char *sig, intptr_t siglen)
{
  rsa_key k;
  unsigned char mHash[64], m[RSA_MAX], exp[RSA_MAX];
  intptr_t hlen = hash_len(alg);
  if (!hlen) return 0;
  if (!rsa_pub_from_raw(&k, n, nlen, e, elen)) return 0;
  if (siglen != k.klen) return 0;
  /* reject sig >= n */
  { BN s; bn_from_be(&s, sig, (int)siglen); if (bn_cmp(&s, &k.n) >= 0) return 0; }
  rktcrypto_digest_oneshot(alg, msg, 0, msglen, mHash, 0, hlen);
  rsa_public(m, sig, &k);
  if (pss)
    return pss_verify_em(alg, m, k.klen, bn_bits(&k.n), mHash);
  if (!pkcs1_v15_encode(exp, k.klen, alg, mHash)) return 0;
  return memcmp(m, exp, (size_t)k.klen) == 0;
}

/* RSAES-OAEP-SHA256 public-key encrypt with (n,e) big-endian. `out` receives the
   ciphertext (modulus length). Returns the ciphertext length, or 0 on failure
   (bad key / message too long for OAEP). Used for CMS EnvelopedData key
   transport. */
int rktcrypto_rsa_oaep_encrypt_pub(const unsigned char *n, intptr_t nlen,
                                   const unsigned char *e, intptr_t elen,
                                   const unsigned char *msg, intptr_t mlen,
                                   unsigned char *out)
{
  rsa_key k;
  if (!rsa_pub_from_raw(&k, n, nlen, e, elen)) return 0;
  if (!rsa_oaep_sha256_encrypt(out, msg, (int)mlen, &k)) return 0;
  return (int)k.klen;
}

/* ---- PKCS#1 RSAPrivateKey (DER) parsing ---- */
typedef struct { const unsigned char *p, *end; } derc;

static int derc_tlv(derc *d, int *tag, const unsigned char **cp, const unsigned char **ce)
{
  const unsigned char *p = d->p; uintptr_t len; int first;
  if (d->end - p < 2) return 0;
  *tag = *p++; first = *p++;
  if (first < 0x80) len = (uintptr_t)first;
  else {
    int nb = first & 0x7f;
    if (nb < 1 || nb > 4 || d->end - p < nb) return 0;
    len = 0;
    while (nb--) len = (len << 8) | *p++;
  }
  if ((uintptr_t)(d->end - p) < len) return 0;
  *cp = p; *ce = p + len; d->p = p + len;
  return 1;
}

static int derc_int(derc *d, const unsigned char **cp, intptr_t *len)
{
  int tag; const unsigned char *p, *e;
  if (!derc_tlv(d, &tag, &p, &e) || tag != 0x02) return 0;
  while (e - p > 1 && p[0] == 0) p++;
  *cp = p; *len = e - p;
  return 1;
}

/* Parses a PKCS#1 RSAPrivateKey and fills every rsa_key field (Montgomery
   contexts included). Returns 1 on success. */
static int rsa_priv_from_der(rsa_key *k, const unsigned char *der, intptr_t derlen)
{
  derc top, seq;
  int tag; const unsigned char *cp, *ce;
  const unsigned char *np; intptr_t nlen;
  struct { BN *bn; } fields[7];
  int i;
  top.p = der; top.end = der + derlen;
  if (!derc_tlv(&top, &tag, &cp, &ce) || tag != 0x30) return 0;
  seq.p = cp; seq.end = ce;
  if (!derc_int(&seq, &np, &nlen)) return 0;      /* version */
  if (nlen != 1 || np[0] != 0) return 0;
  memset(k, 0, sizeof *k);
  if (!derc_int(&seq, &np, &nlen)) return 0;      /* modulus */
  if (nlen < 128 || nlen > RSA_MAX) return 0;
  k->klen = (int)nlen;
  bn_from_be(&k->n, np, (int)nlen);
  fields[0].bn = &k->e;  fields[1].bn = &k->d;
  fields[2].bn = &k->p;  fields[3].bn = &k->q;
  fields[4].bn = &k->dP; fields[5].bn = &k->dQ;
  fields[6].bn = &k->qInv;
  for (i = 0; i < 7; i++) {
    if (!derc_int(&seq, &np, &nlen) || nlen > RSA_MAX) return 0;
    bn_from_be(fields[i].bn, np, (int)nlen);
  }
  if (bn_is_zero(&k->p) || bn_is_zero(&k->q)) return 0;
  rsa_key_precompute(k);
  return 1;
}

/* Signs Hash(msg) under a PKCS#1 RSAPrivateKey (DER). pss as above (PSS
   uses a fresh salt of hLen). Writes the signature (klen bytes) to sig;
   returns its length, or 0 on failure. */
intptr_t rktcrypto_rsa_sign_msg(int pss, int alg,
                                const unsigned char *key_der, intptr_t key_der_len,
                                const unsigned char *msg, intptr_t msglen,
                                unsigned char *sig)
{
  rsa_key k;
  unsigned char mHash[64], em[RSA_MAX];
  intptr_t hlen = hash_len(alg);
  if (!hlen) return 0;
  if (!rsa_priv_from_der(&k, key_der, key_der_len)) return 0;
  rktcrypto_digest_oneshot(alg, msg, 0, msglen, mHash, 0, hlen);
  if (pss) {
    if (!pss_encode(alg, em, k.klen, bn_bits(&k.n), mHash)) return 0;
  } else {
    if (!pkcs1_v15_encode(em, k.klen, alg, mHash)) return 0;
  }
  rsa_private_crt(sig, em, &k);
  /* verify-after-sign: guards against CRT fault / key inconsistency */
  {
    unsigned char m[RSA_MAX];
    rsa_public(m, sig, &k);
    if (pss) {
      if (!pss_verify_em(alg, m, k.klen, bn_bits(&k.n), mHash)) return 0;
    } else {
      if (memcmp(m, em, (size_t)k.klen) != 0) return 0;
    }
  }
  return k.klen;
}
