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
#include "rktcrypto_cpu.h"
#include "rktcrypto_x86.h"

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

/* ===================== SHA-1 blocks (SHA-NI) ===================== */
/* The canonical sha1rnds4 / sha1nexte / sha1msg1 / sha1msg2 sequence: the
   state A..D stays in one register across all blocks, E rides in the top lane
   of its own register, and the 16-word schedule is four registers rotated
   through the msg1/msg2 recurrence. Verified against the portable block by
   asm/tests/test_sha1_x86.c. */
__attribute__((target("sha,sse4.1,ssse3")))
void rktcrypto_sha1_blocks_shani(uint32_t state[5], const unsigned char *data, intptr_t nblk)
{
  const __m128i MASK = _mm_set_epi64x(0x0001020304050607LL, 0x08090a0b0c0d0e0fLL);
  __m128i ABCD, ABCD_SAVE, E0, E0_SAVE, E1, MSG0, MSG1, MSG2, MSG3;

  ABCD = _mm_shuffle_epi32(_mm_loadu_si128((const __m128i *)state), 0x1B);
  E0 = _mm_set_epi32((int)state[4], 0, 0, 0);

  while (nblk-- > 0) {
    ABCD_SAVE = ABCD; E0_SAVE = E0;

    MSG0 = _mm_shuffle_epi8(_mm_loadu_si128((const __m128i *)(data + 0)), MASK);
    E0 = _mm_add_epi32(E0, MSG0); E1 = ABCD;
    ABCD = _mm_sha1rnds4_epu32(ABCD, E0, 0);                                        /* 0-3 */

    MSG1 = _mm_shuffle_epi8(_mm_loadu_si128((const __m128i *)(data + 16)), MASK);
    E1 = _mm_sha1nexte_epu32(E1, MSG1); E0 = ABCD;
    ABCD = _mm_sha1rnds4_epu32(ABCD, E1, 0); MSG0 = _mm_sha1msg1_epu32(MSG0, MSG1);  /* 4-7 */

    MSG2 = _mm_shuffle_epi8(_mm_loadu_si128((const __m128i *)(data + 32)), MASK);
    E0 = _mm_sha1nexte_epu32(E0, MSG2); E1 = ABCD;
    ABCD = _mm_sha1rnds4_epu32(ABCD, E0, 0); MSG1 = _mm_sha1msg1_epu32(MSG1, MSG2);  /* 8-11 */
    MSG0 = _mm_xor_si128(MSG0, MSG2);

    MSG3 = _mm_shuffle_epi8(_mm_loadu_si128((const __m128i *)(data + 48)), MASK);
    E1 = _mm_sha1nexte_epu32(E1, MSG3); E0 = ABCD;
    MSG0 = _mm_sha1msg2_epu32(MSG0, MSG3);
    ABCD = _mm_sha1rnds4_epu32(ABCD, E1, 0); MSG2 = _mm_sha1msg1_epu32(MSG2, MSG3);  /* 12-15 */
    MSG1 = _mm_xor_si128(MSG1, MSG3);

#define SHA1_X86_ROUNDS(EA, EB, MA, MB, MC, MD, F)                                   \
    EA = _mm_sha1nexte_epu32(EA, MA); EB = ABCD;                                    \
    MB = _mm_sha1msg2_epu32(MB, MA);                                                 \
    ABCD = _mm_sha1rnds4_epu32(ABCD, EA, F);                                         \
    MD = _mm_sha1msg1_epu32(MD, MA);                                                 \
    MC = _mm_xor_si128(MC, MA);

    SHA1_X86_ROUNDS(E0, E1, MSG0, MSG1, MSG2, MSG3, 0)   /* 16-19 */
    SHA1_X86_ROUNDS(E1, E0, MSG1, MSG2, MSG3, MSG0, 1)   /* 20-23 */
    SHA1_X86_ROUNDS(E0, E1, MSG2, MSG3, MSG0, MSG1, 1)   /* 24-27 */
    SHA1_X86_ROUNDS(E1, E0, MSG3, MSG0, MSG1, MSG2, 1)   /* 28-31 */
    SHA1_X86_ROUNDS(E0, E1, MSG0, MSG1, MSG2, MSG3, 1)   /* 32-35 */
    SHA1_X86_ROUNDS(E1, E0, MSG1, MSG2, MSG3, MSG0, 1)   /* 36-39 */
    SHA1_X86_ROUNDS(E0, E1, MSG2, MSG3, MSG0, MSG1, 2)   /* 40-43 */
    SHA1_X86_ROUNDS(E1, E0, MSG3, MSG0, MSG1, MSG2, 2)   /* 44-47 */
    SHA1_X86_ROUNDS(E0, E1, MSG0, MSG1, MSG2, MSG3, 2)   /* 48-51 */
    SHA1_X86_ROUNDS(E1, E0, MSG1, MSG2, MSG3, MSG0, 2)   /* 52-55 */
    SHA1_X86_ROUNDS(E0, E1, MSG2, MSG3, MSG0, MSG1, 2)   /* 56-59 */
    SHA1_X86_ROUNDS(E1, E0, MSG3, MSG0, MSG1, MSG2, 3)   /* 60-63 */
    SHA1_X86_ROUNDS(E0, E1, MSG0, MSG1, MSG2, MSG3, 3)   /* 64-67 */
#undef SHA1_X86_ROUNDS

    /* 68-71: schedule words beyond 79 are not needed, so msg1 drops out */
    E1 = _mm_sha1nexte_epu32(E1, MSG1); E0 = ABCD;
    MSG2 = _mm_sha1msg2_epu32(MSG2, MSG1);
    ABCD = _mm_sha1rnds4_epu32(ABCD, E1, 3);
    MSG3 = _mm_xor_si128(MSG3, MSG1);
    /* 72-75 */
    E0 = _mm_sha1nexte_epu32(E0, MSG2); E1 = ABCD;
    MSG3 = _mm_sha1msg2_epu32(MSG3, MSG2);
    ABCD = _mm_sha1rnds4_epu32(ABCD, E0, 3);
    /* 76-79 */
    E1 = _mm_sha1nexte_epu32(E1, MSG3); E0 = ABCD;
    ABCD = _mm_sha1rnds4_epu32(ABCD, E1, 3);

    E0 = _mm_sha1nexte_epu32(E0, E0_SAVE);
    ABCD = _mm_add_epi32(ABCD, ABCD_SAVE);
    data += 64;
  }
  _mm_storeu_si128((__m128i *)state, _mm_shuffle_epi32(ABCD, 0x1B));
  state[4] = (uint32_t)_mm_extract_epi32(E0, 3);
}

/* ===================== AES key schedules and modes (AES-NI) ===================== */
/* The key expansion is the FIPS-197 word recurrence; the only per-word
   nonlinear step is taken from aeskeygenassist (lane 1 of the result is
   RotWord(SubWord(x)) and lane 0 is SubWord(x) for x in lane 1 of the
   source, with RCON = 0), so no table lookup indexes key material.
   The schedule layout and the round-key order are the portable code's. */
#define X86_AES_TARGET __attribute__((target("aes,sse4.1,ssse3")))

X86_AES_TARGET
int rktcrypto_aes_expand_x86(const unsigned char *key, int keylen, unsigned char rk[240])
{
  static const uint32_t rcon[15] = {0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80,0x1b,0x36,0x6c,0xd8,0xab,0x4d,0x9a};
  int Nk = keylen / 4, Nr = Nk + 6, total = 4 * (Nr + 1), i;
  uint32_t w[60];
  memcpy(w, key, (size_t)keylen);
  for (i = Nk; i < total; i++) {
    uint32_t t = w[i - 1];
    if (i % Nk == 0) {
      __m128i v = _mm_aeskeygenassist_si128(_mm_insert_epi32(_mm_setzero_si128(), (int)t, 1), 0);
      t = (uint32_t)_mm_extract_epi32(v, 1) ^ rcon[i / Nk - 1];
    } else if (Nk > 6 && i % Nk == 4) {
      __m128i v = _mm_aeskeygenassist_si128(_mm_insert_epi32(_mm_setzero_si128(), (int)t, 1), 0);
      t = (uint32_t)_mm_extract_epi32(v, 0);
    }
    w[i] = w[i - Nk] ^ t;
  }
  memcpy(rk, w, 16 * (size_t)(Nr + 1));
  return Nr;
}

X86_AES_TARGET
void rktcrypto_aes_expand_dec_x86(const unsigned char rk[240], int Nr, unsigned char dk[240])
{
  int r;
  _mm_storeu_si128((__m128i *)dk, _mm_loadu_si128((const __m128i *)(rk + 16 * Nr)));
  for (r = 1; r < Nr; r++)
    _mm_storeu_si128((__m128i *)(dk + 16 * r),
                     _mm_aesimc_si128(_mm_loadu_si128((const __m128i *)(rk + 16 * (Nr - r)))));
  _mm_storeu_si128((__m128i *)(dk + 16 * Nr), _mm_loadu_si128((const __m128i *)rk));
}

X86_AES_TARGET static inline __m128i x86_aes_enc1(__m128i s, const unsigned char *rk, int Nr)
{
  int r;
  s = _mm_xor_si128(s, _mm_loadu_si128((const __m128i *)rk));
  for (r = 1; r < Nr; r++) s = _mm_aesenc_si128(s, _mm_loadu_si128((const __m128i *)(rk + 16 * r)));
  return _mm_aesenclast_si128(s, _mm_loadu_si128((const __m128i *)(rk + 16 * Nr)));
}

X86_AES_TARGET static inline __m128i x86_aes_dec1(__m128i s, const unsigned char *dk, int Nr)
{
  int r;
  s = _mm_xor_si128(s, _mm_loadu_si128((const __m128i *)dk));
  for (r = 1; r < Nr; r++) s = _mm_aesdec_si128(s, _mm_loadu_si128((const __m128i *)(dk + 16 * r)));
  return _mm_aesdeclast_si128(s, _mm_loadu_si128((const __m128i *)(dk + 16 * Nr)));
}

X86_AES_TARGET
void rktcrypto_aes_enc_blk_x86(const unsigned char *rk, int Nr, const unsigned char in[16], unsigned char out[16])
{
  _mm_storeu_si128((__m128i *)out, x86_aes_enc1(_mm_loadu_si128((const __m128i *)in), rk, Nr));
}

X86_AES_TARGET
void rktcrypto_aes_dec_blk_x86(const unsigned char *dk, int Nr, const unsigned char in[16], unsigned char out[16])
{
  _mm_storeu_si128((__m128i *)out, x86_aes_dec1(_mm_loadu_si128((const __m128i *)in), dk, Nr));
}

static inline uint64_t x86_load_be64(const unsigned char *p)
{
  uint64_t v = 0; int i;
  for (i = 0; i < 8; i++) v = (v << 8) | p[i];
  return v;
}
static inline void x86_store_be64(unsigned char *p, uint64_t v)
{
  int i;
  for (i = 0; i < 8; i++) p[i] = (unsigned char)(v >> (56 - 8 * i));
}
/* Counter block from the big-endian (hi, lo) halves: memory bytes 0..7 are
   `hi`, so the low 64-bit lane holds bswap(hi). */
X86_AES_TARGET static inline __m128i x86_ctr_block(uint64_t hi, uint64_t lo)
{
  return _mm_set_epi64x((long long)__builtin_bswap64(lo), (long long)__builtin_bswap64(hi));
}
static inline void x86_ctr_step(uint64_t *hi, uint64_t *lo, int inc32)
{
  if (inc32) *lo = (*lo & 0xffffffff00000000ULL) | ((*lo + 1) & 0xffffffffULL);
  else { *lo += 1; if (*lo == 0) *hi += 1; }
}

/* CTR keystream XOR, eight blocks in flight (AES-NI latency is ~4 cycles per
   round per block; eight independent chains keep the unit busy). */
X86_AES_TARGET
void rktcrypto_aes_ctr_aesni(const unsigned char *rk, int Nr, unsigned char ctr[16],
                             const unsigned char *in, unsigned char *out, intptr_t len, int inc32)
{
  uint64_t hi = x86_load_be64(ctr), lo = x86_load_be64(ctr + 8);
  const __m128i k0 = _mm_loadu_si128((const __m128i *)rk);
  const __m128i klast = _mm_loadu_si128((const __m128i *)(rk + 16 * Nr));
  while (len >= 128) {
    __m128i s0, s1, s2, s3, s4, s5, s6, s7, k;
    int r;
    s0 = _mm_xor_si128(x86_ctr_block(hi, lo), k0); x86_ctr_step(&hi, &lo, inc32);
    s1 = _mm_xor_si128(x86_ctr_block(hi, lo), k0); x86_ctr_step(&hi, &lo, inc32);
    s2 = _mm_xor_si128(x86_ctr_block(hi, lo), k0); x86_ctr_step(&hi, &lo, inc32);
    s3 = _mm_xor_si128(x86_ctr_block(hi, lo), k0); x86_ctr_step(&hi, &lo, inc32);
    s4 = _mm_xor_si128(x86_ctr_block(hi, lo), k0); x86_ctr_step(&hi, &lo, inc32);
    s5 = _mm_xor_si128(x86_ctr_block(hi, lo), k0); x86_ctr_step(&hi, &lo, inc32);
    s6 = _mm_xor_si128(x86_ctr_block(hi, lo), k0); x86_ctr_step(&hi, &lo, inc32);
    s7 = _mm_xor_si128(x86_ctr_block(hi, lo), k0); x86_ctr_step(&hi, &lo, inc32);
    for (r = 1; r < Nr; r++) {
      k = _mm_loadu_si128((const __m128i *)(rk + 16 * r));
      s0 = _mm_aesenc_si128(s0, k); s1 = _mm_aesenc_si128(s1, k);
      s2 = _mm_aesenc_si128(s2, k); s3 = _mm_aesenc_si128(s3, k);
      s4 = _mm_aesenc_si128(s4, k); s5 = _mm_aesenc_si128(s5, k);
      s6 = _mm_aesenc_si128(s6, k); s7 = _mm_aesenc_si128(s7, k);
    }
    s0 = _mm_aesenclast_si128(s0, klast); s1 = _mm_aesenclast_si128(s1, klast);
    s2 = _mm_aesenclast_si128(s2, klast); s3 = _mm_aesenclast_si128(s3, klast);
    s4 = _mm_aesenclast_si128(s4, klast); s5 = _mm_aesenclast_si128(s5, klast);
    s6 = _mm_aesenclast_si128(s6, klast); s7 = _mm_aesenclast_si128(s7, klast);
#define X86_CTR_OUT(i, s) _mm_storeu_si128((__m128i *)(out + 16 * (i)), \
      _mm_xor_si128(s, _mm_loadu_si128((const __m128i *)(in + 16 * (i)))))
    X86_CTR_OUT(0, s0); X86_CTR_OUT(1, s1); X86_CTR_OUT(2, s2); X86_CTR_OUT(3, s3);
    X86_CTR_OUT(4, s4); X86_CTR_OUT(5, s5); X86_CTR_OUT(6, s6); X86_CTR_OUT(7, s7);
#undef X86_CTR_OUT
    in += 128; out += 128; len -= 128;
  }
  while (len > 0) {
    __m128i s = x86_aes_enc1(x86_ctr_block(hi, lo), rk, Nr);
    x86_ctr_step(&hi, &lo, inc32);
    if (len >= 16) {
      _mm_storeu_si128((__m128i *)out, _mm_xor_si128(s, _mm_loadu_si128((const __m128i *)in)));
      in += 16; out += 16; len -= 16;
    } else {
      unsigned char ks[16]; intptr_t i;
      _mm_storeu_si128((__m128i *)ks, s);
      for (i = 0; i < len; i++) out[i] = (unsigned char)(in[i] ^ ks[i]);
      len = 0;
    }
  }
  x86_store_be64(ctr, hi); x86_store_be64(ctr + 8, lo);
}

X86_AES_TARGET
void rktcrypto_aes_cbc_enc_x86(const unsigned char *rk, int Nr, const unsigned char iv[16],
                               const unsigned char *in, unsigned char *out, intptr_t len)
{
  __m128i prev = _mm_loadu_si128((const __m128i *)iv);
  while (len >= 16) {
    prev = x86_aes_enc1(_mm_xor_si128(prev, _mm_loadu_si128((const __m128i *)in)), rk, Nr);
    _mm_storeu_si128((__m128i *)out, prev);
    in += 16; out += 16; len -= 16;
  }
}

/* CBC decryption is parallel: eight ciphertext blocks are decrypted together
   and each is XORed with its predecessor afterwards. */
X86_AES_TARGET
void rktcrypto_aes_cbc_dec_x86(const unsigned char *dk, int Nr, const unsigned char iv[16],
                               const unsigned char *in, unsigned char *out, intptr_t len)
{
  __m128i prev = _mm_loadu_si128((const __m128i *)iv);
  const __m128i k0 = _mm_loadu_si128((const __m128i *)dk);
  const __m128i klast = _mm_loadu_si128((const __m128i *)(dk + 16 * Nr));
  while (len >= 128) {
    __m128i c0 = _mm_loadu_si128((const __m128i *)(in +   0)), c1 = _mm_loadu_si128((const __m128i *)(in +  16));
    __m128i c2 = _mm_loadu_si128((const __m128i *)(in +  32)), c3 = _mm_loadu_si128((const __m128i *)(in +  48));
    __m128i c4 = _mm_loadu_si128((const __m128i *)(in +  64)), c5 = _mm_loadu_si128((const __m128i *)(in +  80));
    __m128i c6 = _mm_loadu_si128((const __m128i *)(in +  96)), c7 = _mm_loadu_si128((const __m128i *)(in + 112));
    __m128i s0 = _mm_xor_si128(c0, k0), s1 = _mm_xor_si128(c1, k0), s2 = _mm_xor_si128(c2, k0), s3 = _mm_xor_si128(c3, k0);
    __m128i s4 = _mm_xor_si128(c4, k0), s5 = _mm_xor_si128(c5, k0), s6 = _mm_xor_si128(c6, k0), s7 = _mm_xor_si128(c7, k0);
    __m128i k; int r;
    for (r = 1; r < Nr; r++) {
      k = _mm_loadu_si128((const __m128i *)(dk + 16 * r));
      s0 = _mm_aesdec_si128(s0, k); s1 = _mm_aesdec_si128(s1, k);
      s2 = _mm_aesdec_si128(s2, k); s3 = _mm_aesdec_si128(s3, k);
      s4 = _mm_aesdec_si128(s4, k); s5 = _mm_aesdec_si128(s5, k);
      s6 = _mm_aesdec_si128(s6, k); s7 = _mm_aesdec_si128(s7, k);
    }
    _mm_storeu_si128((__m128i *)(out +   0), _mm_xor_si128(_mm_aesdeclast_si128(s0, klast), prev));
    _mm_storeu_si128((__m128i *)(out +  16), _mm_xor_si128(_mm_aesdeclast_si128(s1, klast), c0));
    _mm_storeu_si128((__m128i *)(out +  32), _mm_xor_si128(_mm_aesdeclast_si128(s2, klast), c1));
    _mm_storeu_si128((__m128i *)(out +  48), _mm_xor_si128(_mm_aesdeclast_si128(s3, klast), c2));
    _mm_storeu_si128((__m128i *)(out +  64), _mm_xor_si128(_mm_aesdeclast_si128(s4, klast), c3));
    _mm_storeu_si128((__m128i *)(out +  80), _mm_xor_si128(_mm_aesdeclast_si128(s5, klast), c4));
    _mm_storeu_si128((__m128i *)(out +  96), _mm_xor_si128(_mm_aesdeclast_si128(s6, klast), c5));
    _mm_storeu_si128((__m128i *)(out + 112), _mm_xor_si128(_mm_aesdeclast_si128(s7, klast), c6));
    prev = c7;
    in += 128; out += 128; len -= 128;
  }
  while (len >= 16) {
    __m128i c = _mm_loadu_si128((const __m128i *)in);
    _mm_storeu_si128((__m128i *)out, _mm_xor_si128(x86_aes_dec1(c, dk, Nr), prev));
    prev = c;
    in += 16; out += 16; len -= 16;
  }
}

/* ===================== GHASH (PCLMULQDQ) ===================== */
/* Carryless 128x128 multiply and GF(2^128) reduction (the classic Intel
   "Carry-Less Multiplication and GCM" sequence). Operands are in the
   byte-reversed internal representation; the shift-by-one folded into the
   reduction absorbs GCM's bit convention, so no bit-reversal is needed. */
/* 128x128 carry-less product as a 256-bit value (lo:hi), not yet reduced. */
__attribute__((target("pclmul,sse4.1,ssse3")))
static inline void gcm_mul_raw(__m128i a, __m128i b, __m128i *lo, __m128i *hi)
{
  __m128i t3, t4, t5, t6;
  t3 = _mm_clmulepi64_si128(a, b, 0x00);
  t4 = _mm_clmulepi64_si128(a, b, 0x10);
  t5 = _mm_clmulepi64_si128(a, b, 0x01);
  t6 = _mm_clmulepi64_si128(a, b, 0x11);
  t4 = _mm_xor_si128(t4, t5);
  t5 = _mm_slli_si128(t4, 8);
  t4 = _mm_srli_si128(t4, 8);
  *lo = _mm_xor_si128(t3, t5);
  *hi = _mm_xor_si128(t6, t4);
}

/* Reduce a 256-bit product modulo the GCM polynomial (the classic Intel
   shift-by-one then fold sequence). Linear in its input, so several raw
   products may be XORed together before a single reduction. */
__attribute__((target("pclmul,sse4.1,ssse3")))
static inline __m128i gcm_reduce(__m128i t3, __m128i t6)
{
  __m128i t2, t4, t5, t7, t8, t9;
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

__attribute__((target("pclmul,sse4.1,ssse3")))
static inline __m128i gcm_gfmul(__m128i a, __m128i b)
{
  __m128i lo, hi;
  gcm_mul_raw(a, b, &lo, &hi);
  return gcm_reduce(lo, hi);
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
  __m128i H, H2, H3, H4, acc;
  int i;
  for (i = 0; i < 8; i++) { hb[i] = (unsigned char)(h[0] >> (56 - 8*i)); hb[8+i] = (unsigned char)(h[1] >> (56 - 8*i)); }
  H   = _mm_shuffle_epi8(_mm_loadu_si128((const __m128i *)hb), bswap);
  H2  = gcm_gfmul(H, H); H3 = gcm_gfmul(H2, H); H4 = gcm_gfmul(H3, H);
  acc = _mm_setzero_si128();

#define GCM_X86_REGION(DATA, LEN) do {                                      \
    intptr_t _l = (LEN); const unsigned char *_d = (DATA); __m128i _x;      \
    while (_l >= 64) {                                                      \
      __m128i _c0, _c1, _c2, _c3, _lo, _hi, _l2, _h2;                       \
      _c0 = _mm_shuffle_epi8(_mm_loadu_si128((const __m128i *)_d), bswap);  \
      _c1 = _mm_shuffle_epi8(_mm_loadu_si128((const __m128i *)(_d + 16)), bswap); \
      _c2 = _mm_shuffle_epi8(_mm_loadu_si128((const __m128i *)(_d + 32)), bswap); \
      _c3 = _mm_shuffle_epi8(_mm_loadu_si128((const __m128i *)(_d + 48)), bswap); \
      gcm_mul_raw(_mm_xor_si128(acc, _c0), H4, &_lo, &_hi);                 \
      gcm_mul_raw(_c1, H3, &_l2, &_h2); _lo = _mm_xor_si128(_lo, _l2); _hi = _mm_xor_si128(_hi, _h2); \
      gcm_mul_raw(_c2, H2, &_l2, &_h2); _lo = _mm_xor_si128(_lo, _l2); _hi = _mm_xor_si128(_hi, _h2); \
      gcm_mul_raw(_c3, H,  &_l2, &_h2); _lo = _mm_xor_si128(_lo, _l2); _hi = _mm_xor_si128(_hi, _h2); \
      acc = gcm_reduce(_lo, _hi);                                           \
      _d += 64; _l -= 64;                                                   \
    }                                                                      \
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

void rktcrypto_aes_ctr_x86(const unsigned char *rk, int Nr, unsigned char ctr[16],
                           const unsigned char *in, unsigned char *out, intptr_t len, int inc32)
{
#if defined(__x86_64__) && defined(__ELF__)
  if (len >= 64 && rktcrypto_cpu_has(RKTCRYPTO_CPU_X86_VAES) && rktcrypto_cpu_has(RKTCRYPTO_CPU_X86_AVX512)) {
    intptr_t head = len & ~(intptr_t)63;
    rktcrypto_aes_ctr_vaes(rk, Nr | (inc32 ? 0x100 : 0), ctr, in, out, head);
    in += head; out += head; len -= head;
    if (len == 0) return;
  }
#endif
  rktcrypto_aes_ctr_aesni(rk, Nr, ctr, in, out, len, inc32);
}

#endif  /* x86 */
