/* AES-256 block cipher (encryption only), per FIPS 197.

   From-scratch public-domain-style implementation. To avoid the
   cache-timing side channel of table-based S-boxes, SubBytes is
   computed with finite-field arithmetic: the multiplicative inverse
   in GF(2^8) via x^254 (Fermat), followed by the affine map. All
   operations are constant-time with respect to the data. Only
   encryption is implemented, which is all AES-GCM (CTR mode) needs. */

#include "rktcrypto_cipher.h"

#include <stdint.h>

/* Constant-time multiply in GF(2^8) with the AES polynomial 0x11b. */
static unsigned char gf_mul(unsigned char a, unsigned char b)
{
  unsigned char p = 0;
  int i;
  for (i = 0; i < 8; i++) {
    p ^= (unsigned char)(-(b & 1)) & a;
    /* a = xtime(a) */
    {
      unsigned char hi = (unsigned char)(-((a >> 7) & 1)) & 0x1b;
      a = (unsigned char)((a << 1) ^ hi);
    }
    b >>= 1;
  }
  return p;
}

static unsigned char gf_sq(unsigned char a) { return gf_mul(a, a); }

/* Multiplicative inverse via a^254 = a^-1 in GF(2^8) (a=0 -> 0). */
static unsigned char gf_inv(unsigned char a)
{
  unsigned char a2 = gf_sq(a);         /* a^2 */
  unsigned char a4 = gf_sq(a2);        /* a^4 */
  unsigned char a8 = gf_sq(a4);        /* a^8 */
  unsigned char a16 = gf_sq(a8);
  unsigned char a32 = gf_sq(a16);
  unsigned char a64 = gf_sq(a32);
  unsigned char a128 = gf_sq(a64);
  /* a^254 = a^128 * a^64 * a^32 * a^16 * a^8 * a^4 * a^2 */
  unsigned char r = gf_mul(a128, a64);
  r = gf_mul(r, a32);
  r = gf_mul(r, a16);
  r = gf_mul(r, a8);
  r = gf_mul(r, a4);
  r = gf_mul(r, a2);
  return r;
}

static unsigned char rotl8(unsigned char x, int n)
{
  return (unsigned char)((x << n) | (x >> (8 - n)));
}

static unsigned char aes_sbox(unsigned char a)
{
  unsigned char inv = gf_inv(a);
  /* Affine transform: b = inv ^ rotl(inv,1) ^ rotl(inv,2) ^ rotl(inv,3)
     ^ rotl(inv,4) ^ 0x63 */
  return (unsigned char)(inv ^ rotl8(inv, 1) ^ rotl8(inv, 2)
                         ^ rotl8(inv, 3) ^ rotl8(inv, 4) ^ 0x63);
}

/* AES-256 key expansion: 15 round keys (240 bytes). */
static void aes256_expand(const unsigned char key[32], unsigned char rk[240])
{
  int i;
  unsigned char rcon = 1;
  for (i = 0; i < 32; i++) rk[i] = key[i];
  for (i = 32; i < 240; i += 4) {
    unsigned char t0 = rk[i-4], t1 = rk[i-3], t2 = rk[i-2], t3 = rk[i-1];
    if ((i % 32) == 0) {
      /* RotWord + SubWord + Rcon */
      unsigned char u0 = aes_sbox(t1), u1 = aes_sbox(t2),
                    u2 = aes_sbox(t3), u3 = aes_sbox(t0);
      t0 = (unsigned char)(u0 ^ rcon); t1 = u1; t2 = u2; t3 = u3;
      rcon = gf_mul(rcon, 2);
    } else if ((i % 32) == 16) {
      /* SubWord only (AES-256 extra step) */
      t0 = aes_sbox(t0); t1 = aes_sbox(t1);
      t2 = aes_sbox(t2); t3 = aes_sbox(t3);
    }
    rk[i]   = (unsigned char)(rk[i-32]   ^ t0);
    rk[i+1] = (unsigned char)(rk[i-32+1] ^ t1);
    rk[i+2] = (unsigned char)(rk[i-32+2] ^ t2);
    rk[i+3] = (unsigned char)(rk[i-32+3] ^ t3);
  }
}

#if !(defined(__ARM_FEATURE_AES) || defined(__ARM_FEATURE_CRYPTO))
static void add_round_key(unsigned char s[16], const unsigned char *rk)
{
  int i;
  for (i = 0; i < 16; i++) s[i] ^= rk[i];
}

static void sub_bytes(unsigned char s[16])
{
  int i;
  for (i = 0; i < 16; i++) s[i] = aes_sbox(s[i]);
}

static void shift_rows(unsigned char s[16])
{
  unsigned char t;
  /* state is column-major: s[r + 4*c]. Row r is shifted left by r. */
  /* row 1 */
  t = s[1]; s[1] = s[5]; s[5] = s[9]; s[9] = s[13]; s[13] = t;
  /* row 2 */
  t = s[2]; s[2] = s[10]; s[10] = t; t = s[6]; s[6] = s[14]; s[14] = t;
  /* row 3 */
  t = s[15]; s[15] = s[11]; s[11] = s[7]; s[7] = s[3]; s[3] = t;
}

static void mix_columns(unsigned char s[16])
{
  int c;
  for (c = 0; c < 4; c++) {
    unsigned char *col = s + 4 * c;
    unsigned char a0 = col[0], a1 = col[1], a2 = col[2], a3 = col[3];
    col[0] = (unsigned char)(gf_mul(a0,2) ^ gf_mul(a1,3) ^ a2 ^ a3);
    col[1] = (unsigned char)(a0 ^ gf_mul(a1,2) ^ gf_mul(a2,3) ^ a3);
    col[2] = (unsigned char)(a0 ^ a1 ^ gf_mul(a2,2) ^ gf_mul(a3,3));
    col[3] = (unsigned char)(gf_mul(a0,3) ^ a1 ^ a2 ^ gf_mul(a3,2));
  }
}

/* Portable constant-time block encryption (used where there is no
   hardware AES). */
static void aes256_encrypt_block_portable(const unsigned char rk[240],
                                          const unsigned char in[16],
                                          unsigned char out[16])
{
  unsigned char s[16];
  int r, i;
  for (i = 0; i < 16; i++) s[i] = in[i];

  add_round_key(s, rk);
  for (r = 1; r < 14; r++) {
    sub_bytes(s);
    shift_rows(s);
    mix_columns(s);
    add_round_key(s, rk + 16 * r);
  }
  sub_bytes(s);
  shift_rows(s);
  add_round_key(s, rk + 16 * 14);

  for (i = 0; i < 16; i++) out[i] = s[i];
}
#endif

#if defined(__ARM_FEATURE_AES) || defined(__ARM_FEATURE_CRYPTO)
# include <arm_neon.h>
/* Hardware AES-256 using the ARMv8 Crypto Extensions. The AESE
   instruction does AddRoundKey then SubBytes then ShiftRows; AESMC
   does MixColumns. The instructions are constant-time in hardware.
   Uses the same expanded round keys as the portable path. */
static void aes256_encrypt_block_hw(const unsigned char rk[240],
                                    const unsigned char in[16],
                                    unsigned char out[16])
{
  uint8x16_t state = vld1q_u8(in);
  int r;
  for (r = 0; r < 13; r++) {
    state = vaeseq_u8(state, vld1q_u8(rk + 16 * r));
    state = vaesmcq_u8(state);
  }
  state = vaeseq_u8(state, vld1q_u8(rk + 16 * 13));
  state = veorq_u8(state, vld1q_u8(rk + 16 * 14));
  vst1q_u8(out, state);
}
#endif

/* Encrypts a single 16-byte block using expanded round keys. Uses the
   hardware path on platforms with AES acceleration, the portable
   constant-time path otherwise. */
void rktcrypto_aes256_encrypt_block(const unsigned char rk[240],
                                    const unsigned char in[16],
                                    unsigned char out[16])
{
#if defined(__ARM_FEATURE_AES) || defined(__ARM_FEATURE_CRYPTO)
  aes256_encrypt_block_hw(rk, in, out);
#else
  aes256_encrypt_block_portable(rk, in, out);
#endif
}

void rktcrypto_aes256_expand_key(const unsigned char key[32], unsigned char rk[240])
{
  aes256_expand(key, rk);
}
