/* Digest dispatch for the rktcrypto subsystem.

   Presents one algorithm-id-indexed API over the per-family cores.
   The incremental context lives in a Racket byte string; to stay
   correct under a moving garbage collector and without alignment
   assumptions on byte-string data, each call copies the context into
   an aligned local union, operates, and copies it back. */

#include "rktcrypto_digest.h"
#include <string.h>

union digest_ctx {
  rktcrypto_sha256_ctx_t sha256;
  rktcrypto_sha512_ctx_t sha512;
  rktcrypto_keccak_ctx_t keccak;
  rktcrypto_blake2b_ctx_t blake2b;
};

/* Family selector plus fixed parameters for each algorithm id. */
enum family { F_SHA256, F_SHA512, F_KECCAK, F_BLAKE2B, F_NONE };

struct alg_info {
  enum family family;
  intptr_t digest_size;   /* 0 for XOF */
  intptr_t block_size;
  int is_xof;
};

static struct alg_info info_for(int alg)
{
  struct alg_info a;
  a.family = F_NONE; a.digest_size = -1; a.block_size = -1; a.is_xof = 0;
  switch (alg) {
    case RKTCRYPTO_SHA224:     a.family = F_SHA256;  a.digest_size = 28; a.block_size = 64;  break;
    case RKTCRYPTO_SHA256:     a.family = F_SHA256;  a.digest_size = 32; a.block_size = 64;  break;
    case RKTCRYPTO_SHA384:     a.family = F_SHA512;  a.digest_size = 48; a.block_size = 128; break;
    case RKTCRYPTO_SHA512:     a.family = F_SHA512;  a.digest_size = 64; a.block_size = 128; break;
    case RKTCRYPTO_SHA512_256: a.family = F_SHA512;  a.digest_size = 32; a.block_size = 128; break;
    case RKTCRYPTO_SHA3_224:   a.family = F_KECCAK;  a.digest_size = 28; a.block_size = 144; break;
    case RKTCRYPTO_SHA3_256:   a.family = F_KECCAK;  a.digest_size = 32; a.block_size = 136; break;
    case RKTCRYPTO_SHA3_384:   a.family = F_KECCAK;  a.digest_size = 48; a.block_size = 104; break;
    case RKTCRYPTO_SHA3_512:   a.family = F_KECCAK;  a.digest_size = 64; a.block_size = 72;  break;
    case RKTCRYPTO_SHAKE128:   a.family = F_KECCAK;  a.digest_size = 0;  a.block_size = 168; a.is_xof = 1; break;
    case RKTCRYPTO_SHAKE256:   a.family = F_KECCAK;  a.digest_size = 0;  a.block_size = 136; a.is_xof = 1; break;
    case RKTCRYPTO_BLAKE2B:    a.family = F_BLAKE2B; a.digest_size = 64; a.block_size = 128; break;
    default: break;
  }
  return a;
}

intptr_t rktcrypto_digest_ctx_size(int alg)
{
  return (info_for(alg).family == F_NONE) ? 0 : (intptr_t)sizeof(union digest_ctx);
}

intptr_t rktcrypto_digest_size(int alg)      { return info_for(alg).digest_size; }
intptr_t rktcrypto_digest_block_size(int alg){ return info_for(alg).block_size; }
int rktcrypto_digest_is_xof(int alg)         { return info_for(alg).is_xof; }

static const uint32_t *sha256_iv_for(int alg)
{
  return (alg == RKTCRYPTO_SHA224) ? rktcrypto_sha224_iv : rktcrypto_sha256_iv;
}

static const uint64_t *sha512_iv_for(int alg)
{
  switch (alg) {
    case RKTCRYPTO_SHA384:     return rktcrypto_sha384_iv;
    case RKTCRYPTO_SHA512_256: return rktcrypto_sha512_256_iv;
    default:                   return rktcrypto_sha512_iv;
  }
}

int rktcrypto_digest_init(int alg, unsigned char *ctx, intptr_t ctx_len, intptr_t outlen)
{
  union digest_ctx u;
  struct alg_info a = info_for(alg);

  if (a.family == F_NONE) return 0;
  if (ctx_len < (intptr_t)sizeof(union digest_ctx)) return 0;

  memset(&u, 0, sizeof(u));
  switch (a.family) {
    case F_SHA256:
      rktcrypto_sha256_core_init(&u.sha256, sha256_iv_for(alg));
      break;
    case F_SHA512:
      rktcrypto_sha512_core_init(&u.sha512, sha512_iv_for(alg));
      break;
    case F_KECCAK:
      rktcrypto_keccak_core_init(&u.keccak, a.block_size, a.is_xof ? 0x1f : 0x06);
      break;
    case F_BLAKE2B:
      /* M1 exposes the fixed 512-bit output; keyed and variable-length
         BLAKE2b are available in the core for a later revision. */
      (void)outlen;
      rktcrypto_blake2b_core_init(&u.blake2b, 64, 0, 0);
      break;
    default: return 0;
  }
  memcpy(ctx, &u, sizeof(u));
  return 1;
}

int rktcrypto_digest_update(int alg, unsigned char *ctx, intptr_t ctx_len,
                            const unsigned char *data, intptr_t start, intptr_t end)
{
  union digest_ctx u;
  struct alg_info a = info_for(alg);
  intptr_t len = end - start;

  if (a.family == F_NONE) return 0;
  if (ctx_len < (intptr_t)sizeof(union digest_ctx)) return 0;
  if (len < 0) return 0;
  if (len == 0) return 1;

  memcpy(&u, ctx, sizeof(u));
  switch (a.family) {
    case F_SHA256:  rktcrypto_sha256_core_update(&u.sha256, data + start, len); break;
    case F_SHA512:  rktcrypto_sha512_core_update(&u.sha512, data + start, len); break;
    case F_KECCAK:  rktcrypto_keccak_core_update(&u.keccak, data + start, len); break;
    case F_BLAKE2B: rktcrypto_blake2b_core_update(&u.blake2b, data + start, len); break;
    default: return 0;
  }
  memcpy(ctx, &u, sizeof(u));
  return 1;
}

int rktcrypto_digest_final(int alg, unsigned char *ctx, intptr_t ctx_len,
                           unsigned char *out, intptr_t out_start, intptr_t out_len)
{
  union digest_ctx u;
  struct alg_info a = info_for(alg);

  if (a.family == F_NONE) return 0;
  if (ctx_len < (intptr_t)sizeof(union digest_ctx)) return 0;
  if (out_len < 0) return 0;
  if (!a.is_xof && out_len != a.digest_size) return 0;
  if (a.is_xof && out_len == 0) return 1;

  memcpy(&u, ctx, sizeof(u));
  switch (a.family) {
    case F_SHA256:  rktcrypto_sha256_core_final(&u.sha256, out + out_start, out_len); break;
    case F_SHA512:  rktcrypto_sha512_core_final(&u.sha512, out + out_start, out_len); break;
    case F_KECCAK:  rktcrypto_keccak_core_final(&u.keccak, out + out_start, out_len); break;
    case F_BLAKE2B: rktcrypto_blake2b_core_final(&u.blake2b, out + out_start, out_len); break;
    default: return 0;
  }
  memcpy(ctx, &u, sizeof(u));
  return 1;
}

int rktcrypto_digest_oneshot(int alg,
                             const unsigned char *data, intptr_t start, intptr_t end,
                             unsigned char *out, intptr_t out_start, intptr_t out_len)
{
  unsigned char ctx[sizeof(union digest_ctx)];
  intptr_t clen = (intptr_t)sizeof(ctx);
  intptr_t outlen_hint = (info_for(alg).is_xof) ? out_len : 0;

  if (!rktcrypto_digest_init(alg, ctx, clen, outlen_hint)) return 0;
  if (!rktcrypto_digest_update(alg, ctx, clen, data, start, end)) return 0;
  return rktcrypto_digest_final(alg, ctx, clen, out, out_start, out_len);
}
