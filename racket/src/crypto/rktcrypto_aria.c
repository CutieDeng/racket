/* ARIA (RFC 5794, KS X 1213-1).

   Korean national standard 128-bit block cipher (128/192/256-bit keys,
   12/14/16 rounds): an SPN with two S-boxes (SB1 = the AES S-box, SB2 a
   second affine-transformed power map) plus their inverses, and a 16x16
   binary involutory diffusion matrix A. Each round substitutes all 16
   state bytes independently (wide ILP by construction), then applies A
   computed with shared subexpressions (72 XORs instead of the naive 96;
   every equation verified against the RFC's list). SB3/SB4 are derived
   from SB1/SB2 by table inversion at init, so only the two standard
   tables are transcribed. Modes: ECB, CBC, CTR. From scratch, no
   external code. */

#include "rktcrypto_cipher.h"
#include <string.h>
#include <stdint.h>

static const unsigned char ARIA_SB1[256] = {
0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,
0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0,
0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15,
0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75,
0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84,
0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf,
0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8,
0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2,
0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73,
0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb,
0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79,
0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08,
0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a,
0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e,
0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf,
0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16};

static const unsigned char ARIA_SB2[256] = {
0xe2,0x4e,0x54,0xfc,0x94,0xc2,0x4a,0xcc,0x62,0x0d,0x6a,0x46,0x3c,0x4d,0x8b,0xd1,
0x5e,0xfa,0x64,0xcb,0xb4,0x97,0xbe,0x2b,0xbc,0x77,0x2e,0x03,0xd3,0x19,0x59,0xc1,
0x1d,0x06,0x41,0x6b,0x55,0xf0,0x99,0x69,0xea,0x9c,0x18,0xae,0x63,0xdf,0xe7,0xbb,
0x00,0x73,0x66,0xfb,0x96,0x4c,0x85,0xe4,0x3a,0x09,0x45,0xaa,0x0f,0xee,0x10,0xeb,
0x2d,0x7f,0xf4,0x29,0xac,0xcf,0xad,0x91,0x8d,0x78,0xc8,0x95,0xf9,0x2f,0xce,0xcd,
0x08,0x7a,0x88,0x38,0x5c,0x83,0x2a,0x28,0x47,0xdb,0xb8,0xc7,0x93,0xa4,0x12,0x53,
0xff,0x87,0x0e,0x31,0x36,0x21,0x58,0x48,0x01,0x8e,0x37,0x74,0x32,0xca,0xe9,0xb1,
0xb7,0xab,0x0c,0xd7,0xc4,0x56,0x42,0x26,0x07,0x98,0x60,0xd9,0xb6,0xb9,0x11,0x40,
0xec,0x20,0x8c,0xbd,0xa0,0xc9,0x84,0x04,0x49,0x23,0xf1,0x4f,0x50,0x1f,0x13,0xdc,
0xd8,0xc0,0x9e,0x57,0xe3,0xc3,0x7b,0x65,0x3b,0x02,0x8f,0x3e,0xe8,0x25,0x92,0xe5,
0x15,0xdd,0xfd,0x17,0xa9,0xbf,0xd4,0x9a,0x7e,0xc5,0x39,0x67,0xfe,0x76,0x9d,0x43,
0xa7,0xe1,0xd0,0xf5,0x68,0xf2,0x1b,0x34,0x70,0x05,0xa3,0x8a,0xd5,0x79,0x86,0xa8,
0x30,0xc6,0x51,0x4b,0x1e,0xa6,0x27,0xf6,0x35,0xd2,0x6e,0x24,0x16,0x82,0x5f,0xda,
0xe6,0x75,0xa2,0xef,0x2c,0xb2,0x1c,0x9f,0x5d,0x6f,0x80,0x0a,0x72,0x44,0x9b,0x6c,
0x90,0x0b,0x5b,0x33,0x7d,0x5a,0x52,0xf3,0x61,0xa1,0xf7,0xb0,0xd6,0x3f,0x7c,0x6d,
0xed,0x14,0xe0,0xa5,0x3d,0x22,0xb3,0xf8,0x89,0xde,0x71,0x1a,0xaf,0xba,0xb5,0x81};

static unsigned char ARIA_SB3[256], ARIA_SB4[256];  /* inverses, built once */

/* Pre-diffused 32-bit tables for the word-level hot path: the byte at
   lane j is substituted and spread to the other three lanes of its word
   (the within-word mix M = J - I). With W the across-words J-I mix and
   P the per-word byte permutations (identity, badc, cdab=ror16, dcba=
   bswap), the diffusion satisfies A = W o P o W o M -- verified against
   the RFC's 16 equations by the involution self-test in the test suite.
   Lane patterns: multiply the substituted byte by 0x01010101 minus its
   own lane. WT1..WT4 substitute SB1/SB2/SB3/SB4 for lanes 0/1/2/3 of
   odd rounds; even rounds use them in the order WT3/WT4/WT1/WT2. */
static uint32_t ARIA_WT1[256], ARIA_WT2[256], ARIA_WT3[256], ARIA_WT4[256];
static int aria_inited = 0;
static void aria_init(void)
{
  int i;
  for (i = 0; i < 256; i++) {
    ARIA_SB3[ARIA_SB1[i]] = (unsigned char)i;
    ARIA_SB4[ARIA_SB2[i]] = (unsigned char)i;
  }
  for (i = 0; i < 256; i++) {
    ARIA_WT1[i] = 0x00010101u * ARIA_SB1[i];
    ARIA_WT2[i] = 0x01000101u * ARIA_SB2[i];
    ARIA_WT3[i] = 0x01010001u * ARIA_SB3[i];
    ARIA_WT4[i] = 0x01010100u * ARIA_SB4[i];
  }
  aria_inited = 1;
}

/* Diffusion layer A (involution), byte-array form for the key schedule. */
static void aria_A(unsigned char *y, const unsigned char *x)
{
  unsigned char q89=x[8]^x[9], q1011=x[10]^x[11], a=x[13]^x[14], b=x[12]^x[15];
  unsigned char c=x[4]^x[6], d=x[5]^x[7];
  unsigned char e=x[14]^x[15], f=x[12]^x[13], g=x[0]^x[2], h=x[1]^x[3];
  unsigned char i2=x[8]^x[11], j2=x[9]^x[10];
  unsigned char k=x[0]^x[1], l=x[2]^x[3], m=x[4]^x[7], n2=x[5]^x[6];
  unsigned char o=x[13]^x[15], p2=x[12]^x[14];
  unsigned char q=x[6]^x[7], r=x[4]^x[5], s=x[1]^x[2], t=x[0]^x[3];
  unsigned char u=x[9]^x[11], v=x[8]^x[10];
  y[0]=x[3]^c^q89^a;   y[1]=x[2]^d^q89^b;   y[2]=x[1]^c^q1011^b; y[3]=x[0]^d^q1011^a;
  y[4]=g^x[5]^i2^e;    y[5]=h^x[4]^j2^e;    y[6]=g^x[7]^j2^f;    y[7]=h^x[6]^i2^f;
  y[8]=k^m^x[10]^o;    y[9]=k^n2^x[11]^p2;  y[10]=l^n2^x[8]^o;   y[11]=l^m^x[9]^p2;
  y[12]=s^q^u^x[12];   y[13]=t^q^v^x[13];   y[14]=t^r^u^x[14];   y[15]=s^r^v^x[15];
}

/* FO/FE for the key schedule (cold path; byte arrays). */
static void aria_FO(unsigned char *out, const unsigned char *d, const unsigned char *rk)
{
  unsigned char t[16]; int i;
  for (i = 0; i < 16; i += 4) {
    t[i]   = ARIA_SB1[d[i]   ^ rk[i]];
    t[i+1] = ARIA_SB2[d[i+1] ^ rk[i+1]];
    t[i+2] = ARIA_SB3[d[i+2] ^ rk[i+2]];
    t[i+3] = ARIA_SB4[d[i+3] ^ rk[i+3]];
  }
  aria_A(out, t);
}
static void aria_FE(unsigned char *out, const unsigned char *d, const unsigned char *rk)
{
  unsigned char t[16]; int i;
  for (i = 0; i < 16; i += 4) {
    t[i]   = ARIA_SB3[d[i]   ^ rk[i]];
    t[i+1] = ARIA_SB4[d[i+1] ^ rk[i+1]];
    t[i+2] = ARIA_SB1[d[i+2] ^ rk[i+2]];
    t[i+3] = ARIA_SB2[d[i+3] ^ rk[i+3]];
  }
  aria_A(out, t);
}

typedef struct {
  unsigned char rk[17][16];   /* byte form (last round + schedule work) */
  uint32_t rkw[17][4];        /* big-endian words, pre-swapped for the hot path */
  int nr;
} aria_ks;

/* 128-bit rotate-right on big-endian byte strings via two u64 halves. */
static void aria_ror(unsigned char *dst, const unsigned char *w, int n)
{
  uint64_t hi, lo, h2, l2; uint64_t v;
  memcpy(&v, w, 8);   hi = __builtin_bswap64(v);
  memcpy(&v, w+8, 8); lo = __builtin_bswap64(v);
  n &= 127;
  if (n >= 64) { uint64_t t = hi; hi = lo; lo = t; n -= 64; }
  if (n == 0) { h2 = hi; l2 = lo; }
  else { h2 = (hi >> n) | (lo << (64-n)); l2 = (lo >> n) | (hi << (64-n)); }
  v = __builtin_bswap64(h2); memcpy(dst, &v, 8);
  v = __builtin_bswap64(l2); memcpy(dst+8, &v, 8);
}

static void aria_xor16(unsigned char *d, const unsigned char *a, const unsigned char *b)
{ int i; for (i = 0; i < 16; i++) d[i] = a[i] ^ b[i]; }

/* Key schedule (RFC 5794 section 2.2): W0..W3 from a 3-round 256-bit
   Feistel over KL||KR with the 1/pi constants, then ek1..17 as rotated
   combinations. Decryption keys reverse the list and pass the middle
   ones through A. */
static void aria_schedule(const unsigned char *key, int keylen, int encrypt, aria_ks *ks)
{
  static const unsigned char C1[16] = {0x51,0x7c,0xc1,0xb7,0x27,0x22,0x0a,0x94,0xfe,0x13,0xab,0xe8,0xfa,0x9a,0x6e,0xe0};
  static const unsigned char C2[16] = {0x6d,0xb1,0x4a,0xcc,0x9e,0x21,0xc8,0x20,0xff,0x28,0xb1,0xd5,0xef,0x5d,0xe2,0xb0};
  static const unsigned char C3[16] = {0xdb,0x92,0x37,0x1d,0x21,0x26,0xe9,0x70,0x03,0x24,0x97,0x75,0x04,0xe8,0xc9,0x0e};
  const unsigned char *CK1, *CK2, *CK3;
  unsigned char KL[16], KR[16], W0[16], W1[16], W2[16], W3[16], t[16], rot[16];
  unsigned char ek[17][16];
  int i;

  if (!aria_inited) aria_init();
  memcpy(KL, key, 16);
  memset(KR, 0, 16);
  if (keylen > 16) memcpy(KR, key + 16, keylen - 16);
  if (keylen == 16)      { CK1 = C1; CK2 = C2; CK3 = C3; ks->nr = 12; }
  else if (keylen == 24) { CK1 = C2; CK2 = C3; CK3 = C1; ks->nr = 14; }
  else                   { CK1 = C3; CK2 = C1; CK3 = C2; ks->nr = 16; }

  memcpy(W0, KL, 16);
  aria_FO(t, W0, CK1); aria_xor16(W1, t, KR);
  aria_FE(t, W1, CK2); aria_xor16(W2, t, W0);
  aria_FO(t, W2, CK3); aria_xor16(W3, t, W1);

  { /* ek1..16 in groups of 4: rotations 19, 31, 128-61, 128-31; the W
       pairing cycles (W0,W1) (W1,W2) (W2,W3) (W3,W0). */
    static const int rots[4] = {19, 31, 67, 97};   /* <<<61 = >>>67, <<<31 = >>>97 */
    const unsigned char *W[4]; int g;
    W[0] = W0; W[1] = W1; W[2] = W2; W[3] = W3;
    for (g = 0; g < 4; g++) {
      for (i = 0; i < 4; i++) {
        aria_ror(rot, W[(i+1) & 3], rots[g]);
        aria_xor16(ek[4*g + i], W[i], rot);
      }
    }
    aria_ror(rot, W1, 109);                        /* <<<19 = >>>109 */
    aria_xor16(ek[16], W0, rot);
  }

  if (encrypt) {
    for (i = 0; i <= ks->nr; i++) memcpy(ks->rk[i], ek[i], 16);
  } else {
    int n = ks->nr;
    memcpy(ks->rk[0], ek[n], 16);
    for (i = 1; i < n; i++) aria_A(ks->rk[i], ek[n - i]);
    memcpy(ks->rk[n], ek[0], 16);
  }
  for (i = 0; i <= ks->nr; i++) {
    int w; uint32_t v;
    for (w = 0; w < 4; w++) {
      memcpy(&v, ks->rk[i] + 4*w, 4);
      ks->rkw[i][w] = __builtin_bswap32(v);
    }
  }
}

/* Hot block path: state as four big-endian 32-bit words. Each round is
   AddRoundKey + 16 pre-diffused table lookups (M fused into the tables)
   + across-words mix W (6 XORs) + per-word byte permutations P + W
   again: A o SL in ~47 ALU ops and 16 L1 loads. */
#define ARIA_BADC(x) ((((x) << 8) & 0xff00ff00u) | (((x) >> 8) & 0x00ff00ffu))
#define ARIA_CDAB(x) (((x) >> 16) | ((x) << 16))

#define ARIA_W(T0,T1,T2,T3) do { \
    (T1) ^= (T2); (T2) ^= (T3); (T0) ^= (T1); \
    (T3) ^= (T1); (T2) ^= (T0); (T1) ^= (T2); } while (0)

#define ARIA_SL_PRE(T, A0, A1, A2, A3) \
    ((A0)[(T) >> 24] ^ (A1)[((T) >> 16) & 0xff] ^ (A2)[((T) >> 8) & 0xff] ^ (A3)[(T) & 0xff])

#define ARIA_ROUND_ODD(rkw) do { \
    T0 ^= (rkw)[0]; T1 ^= (rkw)[1]; T2 ^= (rkw)[2]; T3 ^= (rkw)[3]; \
    T0 = ARIA_SL_PRE(T0, ARIA_WT1, ARIA_WT2, ARIA_WT3, ARIA_WT4); \
    T1 = ARIA_SL_PRE(T1, ARIA_WT1, ARIA_WT2, ARIA_WT3, ARIA_WT4); \
    T2 = ARIA_SL_PRE(T2, ARIA_WT1, ARIA_WT2, ARIA_WT3, ARIA_WT4); \
    T3 = ARIA_SL_PRE(T3, ARIA_WT1, ARIA_WT2, ARIA_WT3, ARIA_WT4); \
    ARIA_W(T0,T1,T2,T3); \
    T1 = ARIA_BADC(T1); T2 = ARIA_CDAB(T2); T3 = __builtin_bswap32(T3); \
    ARIA_W(T0,T1,T2,T3); } while (0)

#define ARIA_ROUND_EVEN(rkw) do { \
    T0 ^= (rkw)[0]; T1 ^= (rkw)[1]; T2 ^= (rkw)[2]; T3 ^= (rkw)[3]; \
    T0 = ARIA_SL_PRE(T0, ARIA_WT3, ARIA_WT4, ARIA_WT1, ARIA_WT2); \
    T1 = ARIA_SL_PRE(T1, ARIA_WT3, ARIA_WT4, ARIA_WT1, ARIA_WT2); \
    T2 = ARIA_SL_PRE(T2, ARIA_WT3, ARIA_WT4, ARIA_WT1, ARIA_WT2); \
    T3 = ARIA_SL_PRE(T3, ARIA_WT3, ARIA_WT4, ARIA_WT1, ARIA_WT2); \
    ARIA_W(T0,T1,T2,T3); \
    T0 = ARIA_CDAB(T0); T1 = __builtin_bswap32(T1); T3 = ARIA_BADC(T3); \
    ARIA_W(T0,T1,T2,T3); } while (0)

static uint32_t aria_ld32(const unsigned char *p){ uint32_t v; memcpy(&v,p,4); return __builtin_bswap32(v); }
static void aria_st32(unsigned char *p, uint32_t v){ v = __builtin_bswap32(v); memcpy(p,&v,4); }

static void aria_block(const aria_ks *ks, const unsigned char in[16], unsigned char out[16])
{
  uint32_t T0 = aria_ld32(in), T1 = aria_ld32(in+4), T2 = aria_ld32(in+8), T3 = aria_ld32(in+12);
  const unsigned char *rk;
  int r, i;
  for (r = 0; r + 2 < ks->nr; r += 2) {
    ARIA_ROUND_ODD(ks->rkw[r]);
    ARIA_ROUND_EVEN(ks->rkw[r+1]);
  }
  ARIA_ROUND_ODD(ks->rkw[ks->nr-2]);
  /* last round: SL2 without A, then the final key addition, byte-wise */
  rk = ks->rk[ks->nr-1];
  {
    unsigned char x[16];
    const unsigned char *fk = ks->rk[ks->nr];
    aria_st32(x, T0); aria_st32(x+4, T1); aria_st32(x+8, T2); aria_st32(x+12, T3);
    for (i = 0; i < 16; i += 4) {
      out[i]   = (unsigned char)(ARIA_SB3[x[i]   ^ rk[i]]   ^ fk[i]);
      out[i+1] = (unsigned char)(ARIA_SB4[x[i+1] ^ rk[i+1]] ^ fk[i+1]);
      out[i+2] = (unsigned char)(ARIA_SB1[x[i+2] ^ rk[i+2]] ^ fk[i+2]);
      out[i+3] = (unsigned char)(ARIA_SB2[x[i+3] ^ rk[i+3]] ^ fk[i+3]);
    }
  }
}

/* 2-way interleaved core for the parallel modes (ECB, CBC-decrypt, CTR):
   two independent blocks share each round's key words, overlapping the
   two table-load chains. */
static void aria_block2(const aria_ks *ks, const unsigned char in[32], unsigned char out[32])
{
  uint32_t T0 = aria_ld32(in),    T1 = aria_ld32(in+4),  T2 = aria_ld32(in+8),  T3 = aria_ld32(in+12);
  uint32_t U0 = aria_ld32(in+16), U1 = aria_ld32(in+20), U2 = aria_ld32(in+24), U3 = aria_ld32(in+28);
  const unsigned char *rk;
  int r, i;
#define ARIA_R2() do { \
    { uint32_t s0=T0,s1=T1,s2=T2,s3=T3; \
      T0=U0; T1=U1; T2=U2; T3=U3; U0=s0; U1=s1; U2=s2; U3=s3; } \
  } while (0)
  for (r = 0; r + 2 < ks->nr; r += 2) {
    ARIA_ROUND_ODD(ks->rkw[r]); ARIA_R2(); ARIA_ROUND_ODD(ks->rkw[r]); ARIA_R2();
    ARIA_ROUND_EVEN(ks->rkw[r+1]); ARIA_R2(); ARIA_ROUND_EVEN(ks->rkw[r+1]); ARIA_R2();
  }
  ARIA_ROUND_ODD(ks->rkw[ks->nr-2]); ARIA_R2(); ARIA_ROUND_ODD(ks->rkw[ks->nr-2]); ARIA_R2();
#undef ARIA_R2
  rk = ks->rk[ks->nr-1];
  {
    unsigned char x[32];
    const unsigned char *fk = ks->rk[ks->nr];
    aria_st32(x, T0); aria_st32(x+4, T1); aria_st32(x+8, T2); aria_st32(x+12, T3);
    aria_st32(x+16, U0); aria_st32(x+20, U1); aria_st32(x+24, U2); aria_st32(x+28, U3);
    for (i = 0; i < 16; i += 4) {
      out[i]      = (unsigned char)(ARIA_SB3[x[i]      ^ rk[i]]   ^ fk[i]);
      out[i+1]    = (unsigned char)(ARIA_SB4[x[i+1]    ^ rk[i+1]] ^ fk[i+1]);
      out[i+2]    = (unsigned char)(ARIA_SB1[x[i+2]    ^ rk[i+2]] ^ fk[i+2]);
      out[i+3]    = (unsigned char)(ARIA_SB2[x[i+3]    ^ rk[i+3]] ^ fk[i+3]);
      out[16+i]   = (unsigned char)(ARIA_SB3[x[16+i]   ^ rk[i]]   ^ fk[i]);
      out[16+i+1] = (unsigned char)(ARIA_SB4[x[16+i+1] ^ rk[i+1]] ^ fk[i+1]);
      out[16+i+2] = (unsigned char)(ARIA_SB1[x[16+i+2] ^ rk[i+2]] ^ fk[i+2]);
      out[16+i+3] = (unsigned char)(ARIA_SB2[x[16+i+3] ^ rk[i+3]] ^ fk[i+3]);
    }
  }
}

void rktcrypto_aria_ecb(const unsigned char *key, intptr_t keylen, const unsigned char *in,
                        unsigned char *out, intptr_t nblk, int encrypt)
{
  aria_ks ks; intptr_t i = 0;
  aria_schedule(key, (int)keylen, encrypt, &ks);
  for (; i + 2 <= nblk; i += 2) aria_block2(&ks, in + 16*i, out + 16*i);
  for (; i < nblk; i++) aria_block(&ks, in + 16*i, out + 16*i);
}

void rktcrypto_aria_cbc(const unsigned char *key, intptr_t keylen, const unsigned char iv[16],
                        const unsigned char *in, unsigned char *out, intptr_t nblk, int encrypt)
{
  aria_ks ks; intptr_t i; int q;
  aria_schedule(key, (int)keylen, encrypt, &ks);
  if (encrypt) {
    unsigned char x[16];
    memcpy(x, iv, 16);
    for (i = 0; i < nblk; i++) {
      for (q = 0; q < 16; q++) x[q] ^= in[16*i + q];
      aria_block(&ks, x, x);
      memcpy(out + 16*i, x, 16);
    }
  } else {
    unsigned char prev[16], c[32], pt[32];
    intptr_t j = 0;
    memcpy(prev, iv, 16);
    for (; j + 2 <= nblk; j += 2) {
      memcpy(c, in + 16*j, 32);
      aria_block2(&ks, c, pt);
      for (q = 0; q < 16; q++) out[16*j + q] = pt[q] ^ prev[q];
      for (q = 0; q < 16; q++) out[16*j + 16 + q] = pt[16 + q] ^ c[q];
      memcpy(prev, c + 16, 16);
    }
    for (; j < nblk; j++) {
      memcpy(c, in + 16*j, 16);
      aria_block(&ks, c, pt);
      for (q = 0; q < 16; q++) out[16*j + q] = pt[q] ^ prev[q];
      memcpy(prev, c, 16);
    }
  }
}

void rktcrypto_aria_ctr(const unsigned char *key, intptr_t keylen, const unsigned char iv[16],
                        const unsigned char *in, unsigned char *out, intptr_t len)
{
  aria_ks ks;
  uint64_t chi, clo;
  intptr_t off = 0;
  aria_schedule(key, (int)keylen, 1, &ks);
  { uint64_t v; memcpy(&v, iv, 8); chi = __builtin_bswap64(v);
    memcpy(&v, iv+8, 8); clo = __builtin_bswap64(v); }
#define ARIA_CTRBLK(dst) do { \
    uint64_t w0_ = __builtin_bswap64(chi), w1_ = __builtin_bswap64(clo); \
    memcpy((dst), &w0_, 8); memcpy((dst)+8, &w1_, 8); \
    clo++; if (clo == 0) chi++; } while (0)
  while (len - off >= 32) {
    unsigned char cnt[32], kstr[32];
    int q;
    ARIA_CTRBLK(cnt); ARIA_CTRBLK(cnt+16);
    aria_block2(&ks, cnt, kstr);
    for (q = 0; q < 32; q++) out[off+q] = in[off+q] ^ kstr[q];
    off += 32;
  }
  while (off < len) {
    unsigned char cnt[16], kstr[16];
    intptr_t n = len - off; int q;
    ARIA_CTRBLK(cnt);
    if (n > 16) n = 16;
    aria_block(&ks, cnt, kstr);
    for (q = 0; q < n; q++) out[off+q] = in[off+q] ^ kstr[q];
    off += n;
  }
#undef ARIA_CTRBLK
}
