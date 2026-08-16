/* SM4 (GB/T 32907-2016, RFC 8998 ciphersuites).

   Chinese national standard 128-bit block cipher: 32-round unbalanced
   Feistel over four 32-bit words. The round function's S-box + linear
   layer L are fused into four 1KB tables (generated once from the
   standard's S-box, so the table contents are correct by construction).
   Modes: ECB, CBC, CTR. ECB / CBC-decrypt / CTR run a 4-way interleaved
   core (independent blocks hide the 32-round table-load latency);
   CBC-encrypt is a direction-specialized serial chain. From scratch, no
   external code. */

#include "rktcrypto_cipher.h"
#include <string.h>
#include <stdint.h>

/* The standard's S-box (GB/T 32907-2016, table constant). */
static const unsigned char SM4_SBOX[256] = {
0xd6,0x90,0xe9,0xfe,0xcc,0xe1,0x3d,0xb7,0x16,0xb6,0x14,0xc2,0x28,0xfb,0x2c,0x05,
0x2b,0x67,0x9a,0x76,0x2a,0xbe,0x04,0xc3,0xaa,0x44,0x13,0x26,0x49,0x86,0x06,0x99,
0x9c,0x42,0x50,0xf4,0x91,0xef,0x98,0x7a,0x33,0x54,0x0b,0x43,0xed,0xcf,0xac,0x62,
0xe4,0xb3,0x1c,0xa9,0xc9,0x08,0xe8,0x95,0x80,0xdf,0x94,0xfa,0x75,0x8f,0x3f,0xa6,
0x47,0x07,0xa7,0xfc,0xf3,0x73,0x17,0xba,0x83,0x59,0x3c,0x19,0xe6,0x85,0x4f,0xa8,
0x68,0x6b,0x81,0xb2,0x71,0x64,0xda,0x8b,0xf8,0xeb,0x0f,0x4b,0x70,0x56,0x9d,0x35,
0x1e,0x24,0x0e,0x5e,0x63,0x58,0xd1,0xa2,0x25,0x22,0x7c,0x3b,0x01,0x21,0x78,0x87,
0xd4,0x00,0x46,0x57,0x9f,0xd3,0x27,0x52,0x4c,0x36,0x02,0xe7,0xa0,0xc4,0xc8,0x9e,
0xea,0xbf,0x8a,0xd2,0x40,0xc7,0x38,0xb5,0xa3,0xf7,0xf2,0xce,0xf9,0x61,0x15,0xa1,
0xe0,0xae,0x5d,0xa4,0x9b,0x34,0x1a,0x55,0xad,0x93,0x32,0x30,0xf5,0x8c,0xb1,0xe3,
0x1d,0xf6,0xe2,0x2e,0x82,0x66,0xca,0x60,0xc0,0x29,0x23,0xab,0x0d,0x53,0x4e,0x6f,
0xd5,0xdb,0x37,0x45,0xde,0xfd,0x8e,0x2f,0x03,0xff,0x6a,0x72,0x6d,0x6c,0x5b,0x51,
0x8d,0x1b,0xaf,0x92,0xbb,0xdd,0xbc,0x7f,0x11,0xd9,0x5c,0x41,0x1f,0x10,0x5a,0xd8,
0x0a,0xc1,0x31,0x88,0xa5,0xcd,0x7b,0xbd,0x2d,0x74,0xd0,0x12,0xb8,0xe5,0xb4,0xb0,
0x89,0x69,0x97,0x4a,0x0c,0x96,0x77,0x7e,0x65,0xb9,0xf1,0x09,0xc5,0x6e,0xc6,0x84,
0x18,0xf0,0x7d,0xec,0x3a,0xdc,0x4d,0x20,0x79,0xee,0x5f,0x3e,0xd7,0xcb,0x39,0x48};

#define SM4_ROTL(x,n) (((x) << (n)) | ((x) >> (32 - (n))))

/* Round-function tables: SM4_T[0][b] = L(S[b] << 24) with
   L(x) = x ^ rol2 ^ rol10 ^ rol18 ^ rol24; L commutes with byte rotation,
   so SM4_T[j] is a byte-rotate of SM4_T[0]. */
static uint32_t SM4_T[4][256];
static int sm4_inited = 0;
static void sm4_init(void)
{
  int b;
  for (b = 0; b < 256; b++) {
    uint32_t x = (uint32_t)SM4_SBOX[b] << 24;
    uint32_t l = x ^ SM4_ROTL(x,2) ^ SM4_ROTL(x,10) ^ SM4_ROTL(x,18) ^ SM4_ROTL(x,24);
    SM4_T[0][b] = l;
    SM4_T[1][b] = (l >> 8) | (l << 24);
    SM4_T[2][b] = (l >> 16) | (l << 16);
    SM4_T[3][b] = (l >> 24) | (l << 8);
  }
  sm4_inited = 1;
}

static uint32_t sm4_ld32(const unsigned char *p){ uint32_t v; memcpy(&v,p,4); return __builtin_bswap32(v); }
static void sm4_st32(unsigned char *p, uint32_t v){ v = __builtin_bswap32(v); memcpy(p,&v,4); }

#define SM4_TT(x) (SM4_T[0][(x) >> 24] ^ SM4_T[1][((x) >> 16) & 0xff] \
                 ^ SM4_T[2][((x) >> 8) & 0xff] ^ SM4_T[3][(x) & 0xff])

typedef struct { uint32_t rk[32]; } sm4_ks;

/* Key schedule: L'(x) = x ^ rol13 ^ rol23; CK words generated per the
   standard: byte j of CK_i is (4i+j)*7 mod 256. */
static void sm4_schedule(const unsigned char key[16], sm4_ks *ks)
{
  static const uint32_t FK[4] =
    {0xa3b1bac6u, 0x56aa3350u, 0x677d9197u, 0xb27022dcu};
  uint32_t k0, k1, k2, k3;
  int i;
  if (!sm4_inited) sm4_init();
  k0 = sm4_ld32(key)    ^ FK[0]; k1 = sm4_ld32(key+4)  ^ FK[1];
  k2 = sm4_ld32(key+8)  ^ FK[2]; k3 = sm4_ld32(key+12) ^ FK[3];
  for (i = 0; i < 32; i++) {
    uint32_t ck = (uint32_t)(((4*i+0)*7 & 0xff) << 24) | (uint32_t)(((4*i+1)*7 & 0xff) << 16)
                | (uint32_t)(((4*i+2)*7 & 0xff) << 8)  | (uint32_t)((4*i+3)*7 & 0xff);
    uint32_t x = k1 ^ k2 ^ k3 ^ ck;
    uint32_t t = ((uint32_t)SM4_SBOX[x >> 24] << 24) | ((uint32_t)SM4_SBOX[(x >> 16) & 0xff] << 16)
               | ((uint32_t)SM4_SBOX[(x >> 8) & 0xff] << 8) | (uint32_t)SM4_SBOX[x & 0xff];
    t = t ^ SM4_ROTL(t,13) ^ SM4_ROTL(t,23);
    t ^= k0;
    ks->rk[i] = t;
    k0 = k1; k1 = k2; k2 = k3; k3 = t;
  }
}

#define SM4_R(x0,x1,x2,x3,rk) do { uint32_t u_ = (x1)^(x2)^(x3)^(rk); (x0) ^= SM4_TT(u_); } while (0)

/* One block, 32 rounds unrolled with period-4 renaming; rk order gives the
   direction (schedule order encrypts, reversed decrypts). */
static void sm4_block(const uint32_t rk[32], const unsigned char in[16], unsigned char out[16])
{
  uint32_t x0 = sm4_ld32(in), x1 = sm4_ld32(in+4), x2 = sm4_ld32(in+8), x3 = sm4_ld32(in+12);
  int i;
  for (i = 0; i < 32; i += 4) {
    SM4_R(x0,x1,x2,x3, rk[i]);
    SM4_R(x1,x2,x3,x0, rk[i+1]);
    SM4_R(x2,x3,x0,x1, rk[i+2]);
    SM4_R(x3,x0,x1,x2, rk[i+3]);
  }
  sm4_st32(out, x3); sm4_st32(out+4, x2); sm4_st32(out+8, x1); sm4_st32(out+12, x0);
}

/* 4-way interleaved core: four independent blocks share each round key, so
   four table-load chains overlap (throughput- not latency-bound). */
static void sm4_block4(const uint32_t rk[32],
                       const unsigned char *in, unsigned char *out)
{
  uint32_t a0 = sm4_ld32(in),    a1 = sm4_ld32(in+4),  a2 = sm4_ld32(in+8),  a3 = sm4_ld32(in+12);
  uint32_t b0 = sm4_ld32(in+16), b1 = sm4_ld32(in+20), b2 = sm4_ld32(in+24), b3 = sm4_ld32(in+28);
  uint32_t c0 = sm4_ld32(in+32), c1 = sm4_ld32(in+36), c2 = sm4_ld32(in+40), c3 = sm4_ld32(in+44);
  uint32_t d0 = sm4_ld32(in+48), d1 = sm4_ld32(in+52), d2 = sm4_ld32(in+56), d3 = sm4_ld32(in+60);
  int i;
  for (i = 0; i < 32; i += 4) {
    uint32_t k;
    k = rk[i];
    SM4_R(a0,a1,a2,a3,k); SM4_R(b0,b1,b2,b3,k); SM4_R(c0,c1,c2,c3,k); SM4_R(d0,d1,d2,d3,k);
    k = rk[i+1];
    SM4_R(a1,a2,a3,a0,k); SM4_R(b1,b2,b3,b0,k); SM4_R(c1,c2,c3,c0,k); SM4_R(d1,d2,d3,d0,k);
    k = rk[i+2];
    SM4_R(a2,a3,a0,a1,k); SM4_R(b2,b3,b0,b1,k); SM4_R(c2,c3,c0,c1,k); SM4_R(d2,d3,d0,d1,k);
    k = rk[i+3];
    SM4_R(a3,a0,a1,a2,k); SM4_R(b3,b0,b1,b2,k); SM4_R(c3,c0,c1,c2,k); SM4_R(d3,d0,d1,d2,k);
  }
  sm4_st32(out,    a3); sm4_st32(out+4,  a2); sm4_st32(out+8,  a1); sm4_st32(out+12, a0);
  sm4_st32(out+16, b3); sm4_st32(out+20, b2); sm4_st32(out+24, b1); sm4_st32(out+28, b0);
  sm4_st32(out+32, c3); sm4_st32(out+36, c2); sm4_st32(out+40, c1); sm4_st32(out+44, c0);
  sm4_st32(out+48, d3); sm4_st32(out+52, d2); sm4_st32(out+56, d1); sm4_st32(out+60, d0);
}

static void sm4_dir_keys(const unsigned char key[16], int encrypt, sm4_ks *ks)
{
  sm4_schedule(key, ks);
  if (!encrypt) {
    int i;
    for (i = 0; i < 16; i++) { uint32_t t = ks->rk[i]; ks->rk[i] = ks->rk[31-i]; ks->rk[31-i] = t; }
  }
}

void rktcrypto_sm4_ecb(const unsigned char key[16], const unsigned char *in,
                       unsigned char *out, intptr_t nblk, int encrypt)
{
  sm4_ks ks; intptr_t i = 0;
  sm4_dir_keys(key, encrypt, &ks);
  for (; i + 4 <= nblk; i += 4) sm4_block4(ks.rk, in + 16*i, out + 16*i);
  for (; i < nblk; i++) sm4_block(ks.rk, in + 16*i, out + 16*i);
}

void rktcrypto_sm4_cbc(const unsigned char key[16], const unsigned char iv[16],
                       const unsigned char *in, unsigned char *out, intptr_t nblk, int encrypt)
{
  sm4_ks ks; intptr_t i;
  sm4_dir_keys(key, encrypt, &ks);
  if (encrypt) {
    /* serial: chaining value stays in registers as big-endian words */
    uint32_t p0 = sm4_ld32(iv), p1 = sm4_ld32(iv+4), p2 = sm4_ld32(iv+8), p3 = sm4_ld32(iv+12);
    for (i = 0; i < nblk; i++) {
      uint32_t x0 = sm4_ld32(in+16*i)    ^ p0, x1 = sm4_ld32(in+16*i+4)  ^ p1;
      uint32_t x2 = sm4_ld32(in+16*i+8)  ^ p2, x3 = sm4_ld32(in+16*i+12) ^ p3;
      int r;
      for (r = 0; r < 32; r += 4) {
        SM4_R(x0,x1,x2,x3, ks.rk[r]);
        SM4_R(x1,x2,x3,x0, ks.rk[r+1]);
        SM4_R(x2,x3,x0,x1, ks.rk[r+2]);
        SM4_R(x3,x0,x1,x2, ks.rk[r+3]);
      }
      p0 = x3; p1 = x2; p2 = x1; p3 = x0;
      sm4_st32(out+16*i, p0); sm4_st32(out+16*i+4, p1);
      sm4_st32(out+16*i+8, p2); sm4_st32(out+16*i+12, p3);
    }
  } else {
    /* decrypt: blocks independent given ciphertext -> 4-way interleave */
    unsigned char prev[16], pt[64];
    intptr_t j = 0;
    memcpy(prev, iv, 16);
    for (; j + 4 <= nblk; j += 4) {
      const unsigned char *ip = in + 16*j; unsigned char *op = out + 16*j;
      int q;
      sm4_block4(ks.rk, ip, pt);
      for (q = 0; q < 16; q++) op[q] = pt[q] ^ prev[q];
      for (q = 0; q < 48; q++) op[16+q] = pt[16+q] ^ ip[q];
      memcpy(prev, ip + 48, 16);
    }
    for (; j < nblk; j++) {
      unsigned char c[16]; int q;
      memcpy(c, in + 16*j, 16);
      sm4_block(ks.rk, c, pt);
      for (q = 0; q < 16; q++) out[16*j+q] = pt[q] ^ prev[q];
      memcpy(prev, c, 16);
    }
  }
}

/* CTR mode, full 128-bit big-endian counter (SP 800-38A / EVP sm4-ctr
   semantics). in/out may alias exactly. */
void rktcrypto_sm4_ctr(const unsigned char key[16], const unsigned char iv[16],
                       const unsigned char *in, unsigned char *out, intptr_t len)
{
  sm4_ks ks;
  uint64_t chi, clo;
  intptr_t off = 0;
  sm4_schedule(key, &ks);
  { uint64_t v; memcpy(&v, iv, 8); chi = __builtin_bswap64(v);
    memcpy(&v, iv+8, 8); clo = __builtin_bswap64(v); }
#define SM4_CTRBLK(dst) do { \
    uint64_t w0_ = __builtin_bswap64(chi), w1_ = __builtin_bswap64(clo); \
    memcpy((dst), &w0_, 8); memcpy((dst)+8, &w1_, 8); \
    clo++; if (clo == 0) chi++; } while (0)
  while (len - off >= 64) {
    unsigned char cnt[64], kstr[64];
    int q;
    SM4_CTRBLK(cnt); SM4_CTRBLK(cnt+16); SM4_CTRBLK(cnt+32); SM4_CTRBLK(cnt+48);
    sm4_block4(ks.rk, cnt, kstr);
    for (q = 0; q < 64; q++) out[off+q] = in[off+q] ^ kstr[q];
    off += 64;
  }
  while (len - off > 0) {
    unsigned char cnt[16], kstr[16];
    intptr_t n = len - off; int q;
    if (n > 16) n = 16;
    SM4_CTRBLK(cnt);
    sm4_block(ks.rk, cnt, kstr);
    for (q = 0; q < n; q++) out[off+q] = in[off+q] ^ kstr[q];
    off += n;
  }
#undef SM4_CTRBLK
}
