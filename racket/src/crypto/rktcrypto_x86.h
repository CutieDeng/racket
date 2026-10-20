#ifndef __RKTCRYPTO_X86_H__
#define __RKTCRYPTO_X86_H__

/* x86-64 hardware paths, selected at runtime via rktcrypto_cpu. Declared
   for the dispatchers in the AES, GCM, and SHA-256 cores. Only meaningful
   on x86; guarded at every call site by a CPUID feature check. */

#include <stdint.h>

#if defined(__x86_64__) || defined(__i386__)

void rktcrypto_aes256_block_aesni(const unsigned char rk[240],
                                  const unsigned char in[16], unsigned char out[16]);

void rktcrypto_ghash_x86(const uint64_t h[2],
                         const unsigned char *aad, intptr_t aad_len,
                         const unsigned char *ct, intptr_t ct_len,
                         unsigned char s[16]);

void rktcrypto_sha256_block_shani(uint32_t state[8], const unsigned char *data);
void rktcrypto_sha1_blocks_shani(uint32_t state[5], const unsigned char *data, intptr_t nblk);
/* rktasm/x86 kernel (rktcrypto_sha256_x86.S, from asm/x86/sha256.asm); x86-64 ELF only */
void rktcrypto_sha256_blocks_x86(uint32_t state[8], const unsigned char *data, intptr_t nblk);

/* AES-NI key schedules and block/mode kernels for all key sizes (Nr = 10/12/14).
   rk/dk are the 16*(Nr+1)-byte FIPS-197 schedules in encryption order; dk is
   the equivalent-inverse-cipher schedule (aesimc applied) for aesdec. The CTR
   kernel keeps `ctr` (big-endian counter block) updated in place; inc32 selects
   GCM's 32-bit counter increment, otherwise the whole 128-bit value steps. */
int  rktcrypto_aes_expand_x86(const unsigned char *key, int keylen, unsigned char rk[240]);
void rktcrypto_aes_expand_dec_x86(const unsigned char rk[240], int Nr, unsigned char dk[240]);
void rktcrypto_aes_enc_blk_x86(const unsigned char *rk, int Nr,
                               const unsigned char in[16], unsigned char out[16]);
void rktcrypto_aes_dec_blk_x86(const unsigned char *dk, int Nr,
                               const unsigned char in[16], unsigned char out[16]);
/* AES-NI, eight blocks in flight (the oracle for the VAES kernel) */
void rktcrypto_aes_ctr_aesni(const unsigned char *rk, int Nr, unsigned char ctr[16],
                             const unsigned char *in, unsigned char *out, intptr_t len, int inc32);
/* rktasm/x86 kernel (rktcrypto_aes_ctr_vaes.S): VAES+AVX-512, len a multiple of 64, nr_inc32 = Nr | inc32 << 8 */
void rktcrypto_aes_ctr_vaes(const unsigned char *rk, int nr_inc32, unsigned char ctr[16],
                            const unsigned char *in, unsigned char *out, intptr_t len);
/* rktasm/x86 kernel (rktcrypto_ghash_vpclmul.S): htab[16k..] = H^(16-k), byte-reversed representation,
   len a multiple of 64, acc updated in place */
void rktcrypto_ghash_vpclmul(const unsigned char htab[256], unsigned char acc[16],
                             const unsigned char *data, intptr_t len);
/* Fused AES-GCM bulk pass (rktcrypto_gcm_vaes.S): the context layout is shared with the kernel */
struct rktcrypto_gcm_vaes_ctx {
  const unsigned char *rk;     /* 0  */
  const unsigned char *htab;   /* 8  H^16..H^1 descending, byte-reversed (rktcrypto_gcm_vaes_setup) */
  unsigned char *ctr;          /* 16 big-endian counter block, advanced by the kernel */
  unsigned char *acc;          /* 24 GHASH accumulator, byte-reversed, updated by the kernel */
  intptr_t nr;                 /* 32 */
  intptr_t enc;                /* 40 1 = encrypt (GHASH the output), 0 = decrypt (GHASH the input) */
};
intptr_t rktcrypto_gcm_crypt_vaes(const struct rktcrypto_gcm_vaes_ctx *c,
                                  const unsigned char *in, unsigned char *out, intptr_t len);
/* H^16..H^1 (descending, byte-reversed) from the GCM hash key h = (hi, lo) big-endian words;
   htab[240..255] is H itself. */
void rktcrypto_gcm_vaes_setup(const uint64_t h[2], unsigned char htab[256]);
/* GHASH a region into acc (byte-reversed): the VPCLMULQDQ kernel for the 64-byte multiple prefix
   of regions of 256 bytes and more, the PCLMUL intrinsics for the rest; a partial final block is
   zero-padded. */
void rktcrypto_ghash_region_x86(const unsigned char htab[256], unsigned char acc[16],
                                const unsigned char *data, intptr_t len);
/* dispatcher: VAES kernel for the 64-byte multiple prefix when available, AES-NI for the rest */
void rktcrypto_aes_ctr_x86(const unsigned char *rk, int Nr, unsigned char ctr[16],
                           const unsigned char *in, unsigned char *out, intptr_t len, int inc32);
void rktcrypto_aes_cbc_enc_x86(const unsigned char *rk, int Nr, const unsigned char iv[16],
                               const unsigned char *in, unsigned char *out, intptr_t len);
void rktcrypto_aes_cbc_dec_x86(const unsigned char *dk, int Nr, const unsigned char iv[16],
                               const unsigned char *in, unsigned char *out, intptr_t len);

#endif

#endif
