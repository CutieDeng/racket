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
/* rktasm/x86 kernel (rktcrypto_sha256_avx2.S): the tier without SHA-NI (BMI2 rorx rounds, AVX schedule) */
void rktcrypto_sha256_blocks_avx2(uint32_t state[8], const unsigned char *data, intptr_t nblk);

/* AES-NI key schedules and block/mode kernels for all key sizes (Nr = 10/12/14).
   rk/dk are the 16*(Nr+1)-byte FIPS-197 schedules in encryption order; dk is
   the equivalent-inverse-cipher schedule (aesimc applied) for aesdec. The CTR
   kernel keeps `ctr` (big-endian counter block) updated in place; inc32 selects
   GCM's 32-bit counter increment, otherwise the whole 128-bit value steps. */
int  rktcrypto_aes_expand_x86(const unsigned char *key, int keylen, unsigned char rk[240]);
void rktcrypto_aes_expand_dec_x86(const unsigned char rk[240], int Nr, unsigned char dk[240]);
void rktcrypto_aes_enc_blk_x86(const unsigned char *rk, int Nr,
                               const unsigned char in[16], unsigned char out[16]);
/* two independent blocks with their rounds interleaved (one AES latency for both) */
void rktcrypto_aes_enc_blk2_x86(const unsigned char *rk, int Nr, const unsigned char in0[16], const unsigned char in1[16],
                                unsigned char out0[16], unsigned char out1[16]);
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
  const unsigned char *htab;   /* 8  H^32..H^1 times x^-1 in eight 64-byte rows, then eight rows of their (lo ^ hi) halves (rktcrypto_gcm_vaes_setup) */
  unsigned char *ctr;          /* 16 big-endian counter block, advanced by the kernel */
  unsigned char *acc;          /* 24 GHASH accumulator, byte-reversed, updated by the kernel */
  intptr_t nr;                 /* 32 */
  intptr_t enc;                /* 40 1 = encrypt (GHASH the output), 0 = decrypt (GHASH the input) */
};
intptr_t rktcrypto_gcm_crypt_vaes(const struct rktcrypto_gcm_vaes_ctx *c,
                                  const unsigned char *in, unsigned char *out, intptr_t len);
/* the AES-NI + PCLMULQDQ + AVX2 tier (rktcrypto_gcm_aesni.S): same context, 128-byte chunks */
intptr_t rktcrypto_gcm_crypt_aesni(const struct rktcrypto_gcm_vaes_ctx *c,
                                   const unsigned char *in, unsigned char *out, intptr_t len);
/* the SSE tier (rktcrypto_gcm_aesni_sse.S): legacy encodings; rk and htab must be 16-byte aligned */
intptr_t rktcrypto_gcm_crypt_aesni_sse(const struct rktcrypto_gcm_vaes_ctx *c,
                                       const unsigned char *in, unsigned char *out, intptr_t len);
/* From the GCM hash key h = (hi, lo) big-endian words: htab[0..511] = H^32..H^1 times x^-1
   (descending, byte-reversed) for the fused kernel, htab[512..1023] = the (lo ^ hi) halves of
   those entries duplicated per lane (its Karatsuba cross term), htab[1024..1279] = plain
   H^16..H^1, the table the region helper takes (htab[1264..1279] is H itself). */
void rktcrypto_gcm_vaes_setup(const uint64_t h[2], unsigned char htab[1280]);
/* rktasm/x86 kernel (rktcrypto_gcm_vaes.S): the whole 1280-byte table from the hash key block H = AES_K(0) */
void rktcrypto_gcm_htab_vaes(unsigned char htab[1280], const unsigned char hblock[16]);
/* GHASH a region into acc (byte-reversed): the VPCLMULQDQ kernel for the 64-byte multiple prefix
   of regions of 256 bytes and more, the PCLMUL intrinsics for the rest; a partial final block is
   zero-padded. */
void rktcrypto_ghash_region_x86(const unsigned char htab[256], unsigned char acc[16],
                                const unsigned char *data, intptr_t len);
/* rktasm/x86 kernel (rktcrypto_chacha20_avx512.S): `units` x 1024 bytes of ChaCha20 keystream XOR,
   state[12] advanced by 16 per unit */
void rktcrypto_chacha20_blocks_avx512(uint32_t state[16], const unsigned char *in, unsigned char *out, intptr_t units);
/* same kernel file: `units` x 2048 bytes, two sixteen-block sets interleaved in all 32 registers (state[12] += 32 per unit) */
void rktcrypto_chacha20_blocks2_avx512(uint32_t state[16], const unsigned char *in, unsigned char *out, intptr_t units);
/* rktasm/x86 kernel (rktcrypto_chacha20_avx2.S): the AVX2 tier, `units` x 512 bytes, eight blocks per unit */
void rktcrypto_chacha20_blocks_avx2(uint32_t state[16], const unsigned char *in, unsigned char *out, intptr_t units);
/* rktasm/x86 kernel (rktcrypto_chacha20_ssse3.S): the SSSE3 tier, `units` x 256 bytes, four blocks per unit */
void rktcrypto_chacha20_blocks_ssse3(uint32_t state[16], const unsigned char *in, unsigned char *out, intptr_t units);
void rktcrypto_chacha20_blocks_ssse3_4(uint32_t state[16], const unsigned char *in, unsigned char *out, intptr_t units);   /* one four-block group per 256-byte unit */
/* rktasm/x86 kernel (rktcrypto_poly1305_x86.S): radix-2^64 Poly1305 blocks on MULX; r = {r0, r1, s1 = r1 + r1>>2},
   hibit = 1 for full blocks */
void rktcrypto_poly1305_blocks_x86(uint64_t h[3], const uint64_t r[3], const unsigned char *m, intptr_t nblk, uint64_t hibit);
/* rktasm/x86 kernel (rktcrypto_poly1305_ifma.S): eight blocks per vector in radix 2^44; h44 in = lane 0,
   out = the lane sum; tab = the 10 x 8 qword table from rktcrypto_poly1305_ifma_table; groups x 128 bytes */
void rktcrypto_poly1305_blocks_ifma(uint64_t h44[3], const uint64_t tab[80], const unsigned char *m, intptr_t groups);
/* rktasm/x86 kernel (rktcrypto_poly1305_avx2.S): four blocks per vector in radix 2^26; h in = lane 0, out = the
   lane sums (below 2^29); tab = the 18 x 4 qword table from rktcrypto_poly1305_avx2_table; groups x 64 bytes */
void rktcrypto_poly1305_blocks_avx2(uint64_t h[5], const uint64_t tab[72], const unsigned char *m, intptr_t groups);
void rktcrypto_poly1305_avx2_table(const uint32_t r[5], uint64_t tab[72]);
/* rktasm/x86 kernel (rktcrypto_poly1305_sse2.S): four blocks per group as two two-lane accumulator sets in
   radix 2^26; tab = 27 x 2 qwords (steady r^4 rows, then the final powers of each set), 16-aligned */
void rktcrypto_poly1305_blocks_sse2(uint64_t h[5], const uint64_t tab[54], const unsigned char *m, intptr_t groups);
void rktcrypto_poly1305_sse2_table(const uint32_t r[5], uint64_t tab[54]);
void rktcrypto_poly1305_ifma_table(const uint64_t r[3], uint64_t tab[80]);
/* rktasm/x86 kernel (rktcrypto_chacha20poly1305_x86.S): `units` x 1024 bytes of ChaCha20 XOR while Poly1305
   absorbs the preceding unit's ciphertext at mac; hr = {h0 h1 h2 r0 r1 s1} radix 2^64, h updated */
void rktcrypto_chacha20poly1305_units_x86(uint32_t state[16], const unsigned char *in, unsigned char *out,
                                          intptr_t units, const unsigned char *mac, uint64_t hr[6]);
/* the same fused loop on the AVX2 tier (512-byte units, 32 Poly1305 blocks each) and the SSSE3 tier
   (256-byte units, 16 blocks); both need MULX (BMI2) */
void rktcrypto_chacha20poly1305_units_avx2(uint32_t state[16], const unsigned char *in, unsigned char *out,
                                           intptr_t units, const unsigned char *mac, uint64_t hr[6]);
void rktcrypto_chacha20poly1305_units_ssse3(uint32_t state[16], const unsigned char *in, unsigned char *out,
                                            intptr_t units, const unsigned char *mac, uint64_t hr[6]);
/* Poly1305 state in radix 2^64 for the kernels (rktcrypto_poly1305.c); the context buffer must be empty */
struct rktcrypto_poly1305_ctx_t;
void rktcrypto_poly1305_export64(const struct rktcrypto_poly1305_ctx_t *ctx, uint64_t hr[6]);
void rktcrypto_poly1305_import64(struct rktcrypto_poly1305_ctx_t *ctx, const uint64_t hr[6]);
/* rktasm/x86 kernels (rktcrypto_keccak_avx512.S): Keccak-f[1600] in place, and two states interleaved */
void keccak_f1600_x86(uint64_t s[25]);
void keccak_f1600_x2_x86(uint64_t sA[25], uint64_t sB[25]);
/* rktasm/x86 kernel (rktcrypto_keccak_scalar.S): single-state Keccak-f[1600] on the integer unit (BMI1 andn) */
void keccak_f1600_scalar_x86(uint64_t s[25]);
/* rktasm/x86 kernel (rktcrypto_sha512_x86.S): hw[0..7] = state (updated), hw[8..23] = schedule scratch */
void rktcrypto_sha512_blocks_x86(uint64_t hw[24], const unsigned char *data, intptr_t nblk);
/* rktasm/x86 kernel (rktcrypto_sha512_avx512.S): same contract, vectorised schedule (AVX-512VL + BMI2) */
void rktcrypto_sha512_blocks_avx512_x86(uint64_t hw[24], const unsigned char *data, intptr_t nblk);
/* rktasm/x86 kernels (rktcrypto_x25519_x86.S): GF(2^255-19) in four 64-bit limbs, loosely reduced */
void fe64_mul_x86(uint64_t r[4], const uint64_t a[4], const uint64_t b[4]);
void fe64_sqr_x86(uint64_t r[4], const uint64_t a[4]);
void fe64_mul121665_x86(uint64_t r[4], const uint64_t a[4]);
/* one ladder step on st = {x2, z2, x3, z3} with the base coordinate x1, all in registers/frame slots */
void x25519_step_x86(uint64_t st[16], const uint64_t x1[4]);
/* Ed25519 point kernels on the same field (same .S): ge = {X, Y, Z, T} (128 bytes), gec = {Y+X, Y-X, 2dXY}
   (96 bytes, 128 in the comb table); the result may alias the first input */
void ed25519_madd_x86(uint64_t r[16], const uint64_t p[16], const uint64_t q[12]);
void ed25519_add_x86(uint64_t r[16], const uint64_t p[16], const uint64_t q[16], const uint64_t d2[4]);
void ed25519_dbl_x86(uint64_t r[16], const uint64_t p[16]);
/* constant-time selection of entry nib (0..15) of a 16 x 128-byte comb window (AVX-512) */
void ed25519_lookup_x86(uint64_t out[16], const uint64_t table[256], uint64_t nib);
void ed25519_lookup_avx2_x86(uint64_t out[16], const uint64_t table[256], uint64_t nib);   /* the AVX2 tier */
/* dispatcher: VAES kernel for the 64-byte multiple prefix when available, AES-NI for the rest */
void rktcrypto_aes_ctr_x86(const unsigned char *rk, int Nr, unsigned char ctr[16],
                           const unsigned char *in, unsigned char *out, intptr_t len, int inc32);
void rktcrypto_aes_cbc_enc_x86(const unsigned char *rk, int Nr, const unsigned char iv[16],
                               const unsigned char *in, unsigned char *out, intptr_t len);
void rktcrypto_aes_cbc_dec_x86(const unsigned char *dk, int Nr, const unsigned char iv[16],
                               const unsigned char *in, unsigned char *out, intptr_t len);

#endif

#endif
