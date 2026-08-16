/* x86-64 hardware-accelerated paths for the rktcrypto dispatch layer.

   These mirror the ARMv8 paths one-to-one and are selected at runtime by
   rktcrypto_cpu (CPUID), so a single binary uses AES-NI / PCLMULQDQ /
   SHA-NI when the CPU has them and the portable code otherwise. Each
   function carries a __attribute__((target(...))) so it compiles even
   when the translation unit is not built with -maes/-mpclmul/-msha
   globally -- exactly how OpenSSL and the compilers' function
   multi-versioning arrange runtime dispatch.

   Verification status (this tree was developed on Apple Silicon):
   - AES-256 block (AES-NI) and GHASH (PCLMULQDQ) were verified bit-exact
     against the portable implementations, and the full AES-256-GCM was
     checked, running x86-64 under Rosetta 2 (which emulates AES-NI and
     PCLMULQDQ). The AES-NI block also passes the FIPS-197 C.3 KAT.
   - SHA-256 (SHA-NI) follows the canonical Intel intrinsic sequence and
     compiles cleanly, but Rosetta does not emulate the SHA extension, so
     it is correct-by-construction and compile-checked only here; it
     wants validation on real SHA-NI hardware. Until then the runtime
     dispatch still has the verified portable SHA-256 as the fallback. */

#if defined(__x86_64__) || defined(__i386__)

#include <stdint.h>
#include <string.h>
#include <immintrin.h>

/* SHA-256 round constants (FIPS 180-4), local so the module is
   self-contained (the core's K256 is file-static). */
static const uint32_t rktcrypto_sha256_k[64] = {
  0x428a2f98u,0x71374491u,0xb5c0fbcfu,0xe9b5dba5u,0x3956c25bu,0x59f111f1u,0x923f82a4u,0xab1c5ed5u,
  0xd807aa98u,0x12835b01u,0x243185beu,0x550c7dc3u,0x72be5d74u,0x80deb1feu,0x9bdc06a7u,0xc19bf174u,
  0xe49b69c1u,0xefbe4786u,0x0fc19dc6u,0x240ca1ccu,0x2de92c6fu,0x4a7484aau,0x5cb0a9dcu,0x76f988dau,
  0x983e5152u,0xa831c66du,0xb00327c8u,0xbf597fc7u,0xc6e00bf3u,0xd5a79147u,0x06ca6351u,0x14292967u,
  0x27b70a85u,0x2e1b2138u,0x4d2c6dfcu,0x53380d13u,0x650a7354u,0x766a0abbu,0x81c2c92eu,0x92722c85u,
  0xa2bfe8a1u,0xa81a664bu,0xc24b8b70u,0xc76c51a3u,0xd192e819u,0xd6990624u,0xf40e3585u,0x106aa070u,
  0x19a4c116u,0x1e376c08u,0x2748774cu,0x34b0bcb5u,0x391c0cb3u,0x4ed8aa4au,0x5b9cca4fu,0x682e6ff3u,
  0x748f82eeu,0x78a5636fu,0x84c87814u,0x8cc70208u,0x90befffau,0xa4506cebu,0xbef9a3f7u,0xc67178f2u};

/* ===================== AES-256 block (AES-NI) ===================== */
__attribute__((target("aes,sse2")))
void rktcrypto_aes256_block_aesni(const unsigned char rk[240],
                                  const unsigned char in[16], unsigned char out[16])
{
  __m128i s = _mm_xor_si128(_mm_loadu_si128((const __m128i *)in),
                            _mm_loadu_si128((const __m128i *)rk));
  int r;
  for (r = 1; r < 14; r++)
    s = _mm_aesenc_si128(s, _mm_loadu_si128((const __m128i *)(rk + 16 * r)));
  s = _mm_aesenclast_si128(s, _mm_loadu_si128((const __m128i *)(rk + 16 * 14)));
  _mm_storeu_si128((__m128i *)out, s);
}

/* ===================== GHASH (PCLMULQDQ) ===================== */
/* Carryless 128x128 multiply and GF(2^128) reduction (the classic Intel
   "Carry-Less Multiplication and GCM" sequence). Operands are in the
   byte-reversed internal representation; the shift-by-one folded into the
   reduction absorbs GCM's bit convention, so no bit-reversal is needed. */
__attribute__((target("pclmul,sse4.1,ssse3")))
static __m128i gcm_gfmul(__m128i a, __m128i b)
{
  __m128i t2, t3, t4, t5, t6, t7, t8, t9;
  t3 = _mm_clmulepi64_si128(a, b, 0x00);
  t4 = _mm_clmulepi64_si128(a, b, 0x10);
  t5 = _mm_clmulepi64_si128(a, b, 0x01);
  t6 = _mm_clmulepi64_si128(a, b, 0x11);
  t4 = _mm_xor_si128(t4, t5);
  t5 = _mm_slli_si128(t4, 8);
  t4 = _mm_srli_si128(t4, 8);
  t3 = _mm_xor_si128(t3, t5);
  t6 = _mm_xor_si128(t6, t4);
  t7 = _mm_srli_epi32(t3, 31);
  t8 = _mm_srli_epi32(t6, 31);
  t3 = _mm_slli_epi32(t3, 1);
  t6 = _mm_slli_epi32(t6, 1);
  t9 = _mm_srli_si128(t7, 12);
  t8 = _mm_slli_si128(t8, 4);
  t7 = _mm_slli_si128(t7, 4);
  t3 = _mm_or_si128(t3, t7);
  t6 = _mm_or_si128(t6, t8);
  t6 = _mm_or_si128(t6, t9);
  t7 = _mm_slli_epi32(t3, 31);
  t8 = _mm_slli_epi32(t3, 30);
  t9 = _mm_slli_epi32(t3, 25);
  t7 = _mm_xor_si128(t7, t8);
  t7 = _mm_xor_si128(t7, t9);
  t8 = _mm_srli_si128(t7, 4);
  t7 = _mm_slli_si128(t7, 12);
  t3 = _mm_xor_si128(t3, t7);
  t2 = _mm_srli_epi32(t3, 1);
  t4 = _mm_srli_epi32(t3, 2);
  t5 = _mm_srli_epi32(t3, 7);
  t2 = _mm_xor_si128(t2, t4);
  t2 = _mm_xor_si128(t2, t5);
  t2 = _mm_xor_si128(t2, t8);
  t3 = _mm_xor_si128(t3, t2);
  t6 = _mm_xor_si128(t6, t3);
  return t6;
}

/* Full GHASH: s = GHASH_H(aad || 0* || ct || 0* || len(aad)||len(ct)). */
__attribute__((target("pclmul,sse4.1,ssse3")))
void rktcrypto_ghash_x86(const uint64_t h[2],
                         const unsigned char *aad, intptr_t aad_len,
                         const unsigned char *ct, intptr_t ct_len,
                         unsigned char s[16])
{
  const __m128i bswap = _mm_set_epi8(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
  unsigned char hb[16], blk[16];
  __m128i H, acc;
  int i;
  for (i = 0; i < 8; i++) { hb[i] = (unsigned char)(h[0] >> (56 - 8*i)); hb[8+i] = (unsigned char)(h[1] >> (56 - 8*i)); }
  H   = _mm_shuffle_epi8(_mm_loadu_si128((const __m128i *)hb), bswap);
  acc = _mm_setzero_si128();

#define GCM_X86_REGION(DATA, LEN) do {                                      \
    intptr_t _l = (LEN); const unsigned char *_d = (DATA); __m128i _x;      \
    while (_l >= 16) {                                                      \
      _x = _mm_shuffle_epi8(_mm_loadu_si128((const __m128i *)_d), bswap);   \
      acc = gcm_gfmul(_mm_xor_si128(acc, _x), H);                          \
      _d += 16; _l -= 16;                                                   \
    }                                                                      \
    if (_l > 0) {                                                          \
      memset(blk, 0, 16);                                                  \
      for (i = 0; i < _l; i++) blk[i] = _d[i];                             \
      _x = _mm_shuffle_epi8(_mm_loadu_si128((const __m128i *)blk), bswap);  \
      acc = gcm_gfmul(_mm_xor_si128(acc, _x), H);                          \
    }                                                                      \
  } while (0)

  GCM_X86_REGION(aad, aad_len);
  GCM_X86_REGION(ct, ct_len);
#undef GCM_X86_REGION

  { uint64_t abits = (uint64_t)aad_len << 3, cbits = (uint64_t)ct_len << 3;
    for (i = 0; i < 8; i++) blk[i]     = (unsigned char)(abits >> (56 - 8*i));
    for (i = 0; i < 8; i++) blk[8 + i] = (unsigned char)(cbits >> (56 - 8*i)); }
  { __m128i x = _mm_shuffle_epi8(_mm_loadu_si128((const __m128i *)blk), bswap);
    acc = gcm_gfmul(_mm_xor_si128(acc, x), H); }

  _mm_storeu_si128((__m128i *)s, _mm_shuffle_epi8(acc, bswap));
}

/* ===================== SHA-256 block (SHA-NI) ===================== */
/* Canonical Intel SHA-NI compression (sha256rnds2 / sha256msg1 /
   sha256msg2). Compile-checked here; validate on real SHA-NI hardware. */
__attribute__((target("sha,sse4.1,ssse3")))
void rktcrypto_sha256_block_shani(uint32_t state[8], const unsigned char *data)
{
  const __m128i shuf = _mm_set_epi64x(0x0c0d0e0f08090a0bULL, 0x0405060700010203ULL);
  __m128i STATE0, STATE1, MSG, TMP, MSG0, MSG1, MSG2, MSG3, ABEF_SAVE, CDGH_SAVE;

  TMP    = _mm_loadu_si128((const __m128i *)&state[0]);   /* a b c d */
  STATE1 = _mm_loadu_si128((const __m128i *)&state[4]);   /* e f g h */
  TMP    = _mm_shuffle_epi32(TMP, 0xB1);                  /* c d a b */
  STATE1 = _mm_shuffle_epi32(STATE1, 0x1B);              /* h g f e */
  STATE0 = _mm_alignr_epi8(TMP, STATE1, 8);              /* a b e f */
  STATE1 = _mm_blend_epi16(STATE1, TMP, 0xF0);           /* c d g h */

  ABEF_SAVE = STATE0; CDGH_SAVE = STATE1;

  MSG0 = _mm_shuffle_epi8(_mm_loadu_si128((const __m128i *)(data + 0)),  shuf);
  MSG1 = _mm_shuffle_epi8(_mm_loadu_si128((const __m128i *)(data + 16)), shuf);
  MSG2 = _mm_shuffle_epi8(_mm_loadu_si128((const __m128i *)(data + 32)), shuf);
  MSG3 = _mm_shuffle_epi8(_mm_loadu_si128((const __m128i *)(data + 48)), shuf);

#define SHANI_4ROUNDS(Mi, ki) do {                                          \
    MSG = _mm_add_epi32(Mi, _mm_loadu_si128((const __m128i *)&rktcrypto_sha256_k[ki])); \
    STATE1 = _mm_sha256rnds2_epu32(STATE1, STATE0, MSG);                    \
    MSG = _mm_shuffle_epi32(MSG, 0x0E);                                     \
    STATE0 = _mm_sha256rnds2_epu32(STATE0, STATE1, MSG);                    \
  } while (0)
#define SHANI_SCHED(A, B, C, D) do {                                        \
    A = _mm_sha256msg1_epu32(A, B);                                         \
    TMP = _mm_alignr_epi8(D, C, 4);                                         \
    A = _mm_add_epi32(A, TMP);                                              \
    A = _mm_sha256msg2_epu32(A, D);                                         \
  } while (0)

  SHANI_4ROUNDS(MSG0, 0);   SHANI_4ROUNDS(MSG1, 4);
  SHANI_4ROUNDS(MSG2, 8);   SHANI_4ROUNDS(MSG3, 12);
  SHANI_SCHED(MSG0, MSG1, MSG2, MSG3); SHANI_4ROUNDS(MSG0, 16);
  SHANI_SCHED(MSG1, MSG2, MSG3, MSG0); SHANI_4ROUNDS(MSG1, 20);
  SHANI_SCHED(MSG2, MSG3, MSG0, MSG1); SHANI_4ROUNDS(MSG2, 24);
  SHANI_SCHED(MSG3, MSG0, MSG1, MSG2); SHANI_4ROUNDS(MSG3, 28);
  SHANI_SCHED(MSG0, MSG1, MSG2, MSG3); SHANI_4ROUNDS(MSG0, 32);
  SHANI_SCHED(MSG1, MSG2, MSG3, MSG0); SHANI_4ROUNDS(MSG1, 36);
  SHANI_SCHED(MSG2, MSG3, MSG0, MSG1); SHANI_4ROUNDS(MSG2, 40);
  SHANI_SCHED(MSG3, MSG0, MSG1, MSG2); SHANI_4ROUNDS(MSG3, 44);
  SHANI_SCHED(MSG0, MSG1, MSG2, MSG3); SHANI_4ROUNDS(MSG0, 48);
  SHANI_SCHED(MSG1, MSG2, MSG3, MSG0); SHANI_4ROUNDS(MSG1, 52);
  SHANI_SCHED(MSG2, MSG3, MSG0, MSG1); SHANI_4ROUNDS(MSG2, 56);
  SHANI_SCHED(MSG3, MSG0, MSG1, MSG2); SHANI_4ROUNDS(MSG3, 60);
#undef SHANI_4ROUNDS
#undef SHANI_SCHED

  STATE0 = _mm_add_epi32(STATE0, ABEF_SAVE);
  STATE1 = _mm_add_epi32(STATE1, CDGH_SAVE);

  TMP    = _mm_shuffle_epi32(STATE0, 0x1B);   /* f e b a */
  STATE1 = _mm_shuffle_epi32(STATE1, 0xB1);   /* d c h g */
  STATE0 = _mm_blend_epi16(TMP, STATE1, 0xF0);/* a b c d */
  STATE1 = _mm_alignr_epi8(STATE1, TMP, 8);   /* e f g h */

  _mm_storeu_si128((__m128i *)&state[0], STATE0);
  _mm_storeu_si128((__m128i *)&state[4], STATE1);
}

#endif  /* x86 */
