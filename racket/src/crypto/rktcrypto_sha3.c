/* SHA-3 (SHA3-224/256/384/512) and SHAKE128/256, per FIPS 202.

   From-scratch public-domain-style Keccak-f[1600] implementation,
   validated by the NIST test vectors in rktcrypto_selftest.c. The
   sponge construction here serves both fixed-output SHA-3 (domain
   byte 0x06) and the SHAKE XOFs (domain byte 0x1f). Portable
   reference; AVX2 acceleration may be added later behind dispatch. */

#include "rktcrypto_digest.h"
#include "rktcrypto_cpu.h"

#define ROTL64(x, n) (((x) << (n)) | ((x) >> (64 - (n))))

static const uint64_t RC[24] = {
  0x0000000000000001ULL, 0x0000000000008082ULL, 0x800000000000808aULL, 0x8000000080008000ULL,
  0x000000000000808bULL, 0x0000000080000001ULL, 0x8000000080008081ULL, 0x8000000000008009ULL,
  0x000000000000008aULL, 0x0000000000000088ULL, 0x0000000080008009ULL, 0x000000008000000aULL,
  0x000000008000808bULL, 0x800000000000008bULL, 0x8000000000008089ULL, 0x8000000000008003ULL,
  0x8000000000008002ULL, 0x8000000000000080ULL, 0x000000000000800aULL, 0x800000008000000aULL,
  0x8000000080008081ULL, 0x8000000000008080ULL, 0x0000000080000001ULL, 0x8000000080008008ULL
};

static const int RHO[24] = {
  1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 2, 14,
  27, 41, 56, 8, 25, 43, 62, 18, 39, 61, 20, 44
};

static const int PI[24] = {
  10, 7, 11, 17, 18, 3, 5, 16, 8, 21, 24, 4,
  15, 23, 19, 13, 12, 2, 20, 14, 22, 9, 6, 1
};

static void keccak_f_portable(uint64_t s[25])
{
  int round, i;
  for (round = 0; round < 24; round++) {
    uint64_t bc[5], t;

    /* Theta */
    for (i = 0; i < 5; i++)
      bc[i] = s[i] ^ s[i+5] ^ s[i+10] ^ s[i+15] ^ s[i+20];
    for (i = 0; i < 5; i++) {
      t = bc[(i+4)%5] ^ ROTL64(bc[(i+1)%5], 1);
      s[i] ^= t; s[i+5] ^= t; s[i+10] ^= t; s[i+15] ^= t; s[i+20] ^= t;
    }

    /* Rho and Pi */
    t = s[1];
    for (i = 0; i < 24; i++) {
      int j = PI[i];
      uint64_t tmp = s[j];
      s[j] = ROTL64(t, RHO[i]);
      t = tmp;
    }

    /* Chi */
    for (i = 0; i < 25; i += 5) {
      uint64_t a0 = s[i], a1 = s[i+1], a2 = s[i+2], a3 = s[i+3], a4 = s[i+4];
      s[i]   = a0 ^ (~a1 & a2);
      s[i+1] = a1 ^ (~a2 & a3);
      s[i+2] = a2 ^ (~a3 & a4);
      s[i+3] = a3 ^ (~a4 & a0);
      s[i+4] = a4 ^ (~a0 & a1);
    }

    /* Iota */
    s[0] ^= RC[round];
  }
}


#if defined(__ARM_FEATURE_SHA3)
# include <arm_neon.h>
/* Keccak-f[1600] using the ARMv8.2 SHA-3 extension: EOR3 fuses the theta
   column parities, RAX1 the theta D terms, XAR the fused theta-apply +
   rho rotate, BCAX the chi step. State lives in vector registers (low
   lane) across all 24 rounds. Verified bit-exact against the portable
   permutation over 1e5 random states. */
static void keccak_f_sha3(uint64_t s[25])
{
  uint64x2_t a[25], C[5], D[5], b[25];
  int i, round;
  for (i = 0; i < 25; i++) a[i] = vsetq_lane_u64(s[i], vdupq_n_u64(0), 0);
  for (round = 0; round < 24; round++) {
    for (i = 0; i < 5; i++)
      C[i] = veor3q_u64(veor3q_u64(a[i], a[i+5], a[i+10]), a[i+15], a[i+20]);
    for (i = 0; i < 5; i++)
      D[i] = vrax1q_u64(C[(i+4)%5], C[(i+1)%5]);
    b[0] = veorq_u64(a[0], D[0]);
    b[10]=vxarq_u64(a[ 1],D[1],63);
    b[ 7]=vxarq_u64(a[10],D[0],61);
    b[11]=vxarq_u64(a[ 7],D[2],58);
    b[17]=vxarq_u64(a[11],D[1],54);
    b[18]=vxarq_u64(a[17],D[2],49);
    b[ 3]=vxarq_u64(a[18],D[3],43);
    b[ 5]=vxarq_u64(a[ 3],D[3],36);
    b[16]=vxarq_u64(a[ 5],D[0],28);
    b[ 8]=vxarq_u64(a[16],D[1],19);
    b[21]=vxarq_u64(a[ 8],D[3],9);
    b[24]=vxarq_u64(a[21],D[1],62);
    b[ 4]=vxarq_u64(a[24],D[4],50);
    b[15]=vxarq_u64(a[ 4],D[4],37);
    b[23]=vxarq_u64(a[15],D[0],23);
    b[19]=vxarq_u64(a[23],D[3],8);
    b[13]=vxarq_u64(a[19],D[4],56);
    b[12]=vxarq_u64(a[13],D[3],39);
    b[ 2]=vxarq_u64(a[12],D[2],21);
    b[20]=vxarq_u64(a[ 2],D[2],2);
    b[14]=vxarq_u64(a[20],D[0],46);
    b[22]=vxarq_u64(a[14],D[4],25);
    b[ 9]=vxarq_u64(a[22],D[2],3);
    b[ 6]=vxarq_u64(a[ 9],D[4],44);
    b[ 1]=vxarq_u64(a[ 6],D[1],20);
    for (i = 0; i < 25; i += 5) {
      a[i+0] = vbcaxq_u64(b[i+0], b[i+2], b[i+1]);
      a[i+1] = vbcaxq_u64(b[i+1], b[i+3], b[i+2]);
      a[i+2] = vbcaxq_u64(b[i+2], b[i+4], b[i+3]);
      a[i+3] = vbcaxq_u64(b[i+3], b[i+0], b[i+4]);
      a[i+4] = vbcaxq_u64(b[i+4], b[i+1], b[i+0]);
    }
    a[0] = veorq_u64(a[0], vsetq_lane_u64(RC[round], vdupq_n_u64(0), 0));
  }
  for (i = 0; i < 25; i++) s[i] = vgetq_lane_u64(a[i], 0);
}
#endif

static void keccak_f(uint64_t s[25])
{
#if defined(__ARM_FEATURE_SHA3)
  keccak_f_sha3(s);
#else
  keccak_f_portable(s);
#endif
}

/* Two independent Keccak-f[1600] states permuted together in the two lanes of
   each SHA3 vector op (same cost as one). Used to run pairs of independent XOFs
   -- e.g. ML-KEM matrix expansion / noise sampling. */
void rktcrypto_keccak_f1600_x2(uint64_t sA[25], uint64_t sB[25])
{
#if defined(__ARM_FEATURE_SHA3)
  uint64x2_t a[25], C[5], D[5], b[25];
  int i, round;
  for (i = 0; i < 25; i++) a[i] = vsetq_lane_u64(sB[i], vdupq_n_u64(sA[i]), 1);
  for (round = 0; round < 24; round++) {
    for (i = 0; i < 5; i++)
      C[i] = veor3q_u64(veor3q_u64(a[i], a[i+5], a[i+10]), a[i+15], a[i+20]);
    for (i = 0; i < 5; i++)
      D[i] = vrax1q_u64(C[(i+4)%5], C[(i+1)%5]);
    b[0] = veorq_u64(a[0], D[0]);
    b[10]=vxarq_u64(a[ 1],D[1],63); b[ 7]=vxarq_u64(a[10],D[0],61); b[11]=vxarq_u64(a[ 7],D[2],58);
    b[17]=vxarq_u64(a[11],D[1],54); b[18]=vxarq_u64(a[17],D[2],49); b[ 3]=vxarq_u64(a[18],D[3],43);
    b[ 5]=vxarq_u64(a[ 3],D[3],36); b[16]=vxarq_u64(a[ 5],D[0],28); b[ 8]=vxarq_u64(a[16],D[1],19);
    b[21]=vxarq_u64(a[ 8],D[3],9);  b[24]=vxarq_u64(a[21],D[1],62); b[ 4]=vxarq_u64(a[24],D[4],50);
    b[15]=vxarq_u64(a[ 4],D[4],37); b[23]=vxarq_u64(a[15],D[0],23); b[19]=vxarq_u64(a[23],D[3],8);
    b[13]=vxarq_u64(a[19],D[4],56); b[12]=vxarq_u64(a[13],D[3],39); b[ 2]=vxarq_u64(a[12],D[2],21);
    b[20]=vxarq_u64(a[ 2],D[2],2);  b[14]=vxarq_u64(a[20],D[0],46); b[22]=vxarq_u64(a[14],D[4],25);
    b[ 9]=vxarq_u64(a[22],D[2],3);  b[ 6]=vxarq_u64(a[ 9],D[4],44); b[ 1]=vxarq_u64(a[ 6],D[1],20);
    for (i = 0; i < 25; i += 5) {
      a[i+0]=vbcaxq_u64(b[i+0],b[i+2],b[i+1]); a[i+1]=vbcaxq_u64(b[i+1],b[i+3],b[i+2]);
      a[i+2]=vbcaxq_u64(b[i+2],b[i+4],b[i+3]); a[i+3]=vbcaxq_u64(b[i+3],b[i+0],b[i+4]);
      a[i+4]=vbcaxq_u64(b[i+4],b[i+1],b[i+0]);
    }
    a[0] = veorq_u64(a[0], vdupq_n_u64(RC[round]));
  }
  for (i = 0; i < 25; i++) { sA[i]=vgetq_lane_u64(a[i],0); sB[i]=vgetq_lane_u64(a[i],1); }
#else
  keccak_f(sA); keccak_f(sB);
#endif
}

static void absorb_byte(rktcrypto_keccak_ctx_t *ctx, unsigned char b)
{
  ctx->state[ctx->pos >> 3] ^= (uint64_t)b << (8 * (ctx->pos & 7));
  ctx->pos++;
  if (ctx->pos == ctx->rate) {
    keccak_f(ctx->state);
    ctx->pos = 0;
  }
}

void rktcrypto_keccak_core_init(rktcrypto_keccak_ctx_t *ctx, intptr_t rate, unsigned char pad)
{
  int i;
  for (i = 0; i < 25; i++) ctx->state[i] = 0;
  ctx->rate = rate;
  ctx->pos = 0;
  ctx->pad = pad;
}

void rktcrypto_keccak_core_update(rktcrypto_keccak_ctx_t *ctx,
                                  const unsigned char *data, intptr_t len)
{
  while (len > 0) {
    /* Bulk fast path: on a rate boundary with a full block available,
       XOR the rate 64-bit words directly and permute, avoiding the
       per-byte shift-and-branch (which otherwise dominates once the
       permutation is hardware-accelerated). rate is a multiple of 8. */
    if (ctx->pos == 0 && len >= ctx->rate) {
      intptr_t words = ctx->rate >> 3;
      intptr_t nblk = len / ctx->rate;
#if defined(__aarch64__)
      /* Fused absorb (FEAT_SHA3): the state stays resident in vector registers
         across all blocks (input XORed straight into the register state,
         permuted in place) -- no per-block state load/store round-trip. One
         kernel per sponge rate; other rates fall through to the portable word
         loop. Runtime-gated on SHA3 so a single aarch64 binary falls back to
         the portable loop on a core lacking it (on Apple the flag is always
         set, so this is taken and behavior is unchanged). */
      if (rktcrypto_cpu_has(RKTCRYPTO_CPU_ARM_SHA3)) {
        void keccak_absorb21_asm(uint64_t*,const unsigned char*,intptr_t,const uint64_t*);
        void keccak_absorb18_asm(uint64_t*,const unsigned char*,intptr_t,const uint64_t*);
        void keccak_absorb17_asm(uint64_t*,const unsigned char*,intptr_t,const uint64_t*);
        void keccak_absorb13_asm(uint64_t*,const unsigned char*,intptr_t,const uint64_t*);
        void keccak_absorb9_asm (uint64_t*,const unsigned char*,intptr_t,const uint64_t*);
        int fused = 1;
        switch (words) {
          case 21: keccak_absorb21_asm(ctx->state, data, nblk, RC); break;
          case 18: keccak_absorb18_asm(ctx->state, data, nblk, RC); break;
          case 17: keccak_absorb17_asm(ctx->state, data, nblk, RC); break;
          case 13: keccak_absorb13_asm(ctx->state, data, nblk, RC); break;
          case 9:  keccak_absorb9_asm (ctx->state, data, nblk, RC); break;
          default: fused = 0; break;
        }
        if (fused) { data += nblk * ctx->rate; len -= nblk * ctx->rate; continue; }
      }
#endif
      while (len >= ctx->rate) {
        intptr_t w;
        for (w = 0; w < words; w++) {
          const unsigned char *p = data + 8 * w;
          ctx->state[w] ^= (uint64_t)p[0]        | ((uint64_t)p[1] << 8)
                         | ((uint64_t)p[2] << 16) | ((uint64_t)p[3] << 24)
                         | ((uint64_t)p[4] << 32) | ((uint64_t)p[5] << 40)
                         | ((uint64_t)p[6] << 48) | ((uint64_t)p[7] << 56);
        }
        keccak_f(ctx->state);
        data += ctx->rate;
        len  -= ctx->rate;
      }
      continue;
    }
    absorb_byte(ctx, data[0]);   /* partial: one byte, then re-check bulk */
    data += 1;
    len  -= 1;
  }
}

void rktcrypto_keccak_core_final(rktcrypto_keccak_ctx_t *ctx,
                                 unsigned char *out, intptr_t out_len)
{
  intptr_t i;

  /* Pad: domain byte at pos, 0x80 at the last rate byte (may coincide). */
  ctx->state[ctx->pos >> 3] ^= (uint64_t)ctx->pad << (8 * (ctx->pos & 7));
  ctx->state[(ctx->rate - 1) >> 3] ^= (uint64_t)0x80 << (8 * ((ctx->rate - 1) & 7));
  keccak_f(ctx->state);
  ctx->pos = 0;

  /* Squeeze */
  for (i = 0; i < out_len; i++) {
    if (ctx->pos == ctx->rate) {
      keccak_f(ctx->state);
      ctx->pos = 0;
    }
    out[i] = (unsigned char)(ctx->state[ctx->pos >> 3] >> (8 * (ctx->pos & 7)));
    ctx->pos++;
  }
}
