/* SM3 (GB/T 32905-2016, ISO/IEC 10118-3:2018).

   Chinese national standard 256-bit hash, structurally a Merkle-Damgard
   compression like SHA-256 but with a double-word feed (W and W') and a
   boomerang-resistant P0/P1 diffusion. Required for SM2/SM9 and for GB
   interoperability (TLS ciphersuites, digital envelopes). From scratch,
   no external code. */

#include "rktcrypto_digest.h"
#include <string.h>

#define ROTL32(x,n) (((x) << (n)) | ((x) >> (32 - (n))))

void rktcrypto_sm3_core_init(rktcrypto_sm3_ctx_t *ctx)
{
  ctx->h[0] = 0x7380166fu; ctx->h[1] = 0x4914b2b9u; ctx->h[2] = 0x172442d7u;
  ctx->h[3] = 0xda8a0600u; ctx->h[4] = 0xa96f30bcu; ctx->h[5] = 0x163138aau;
  ctx->h[6] = 0xe38dee4du; ctx->h[7] = 0xb0fb0e4eu;
  ctx->len = 0; ctx->buf_len = 0;
}

#define SM3_P0(x) ((x) ^ ROTL32((x), 9) ^ ROTL32((x),17))
#define SM3_P1(x) ((x) ^ ROTL32((x),15) ^ ROTL32((x),23))
#define SM3_FF0(x,y,z) ((x) ^ (y) ^ (z))
#define SM3_FF1(x,y,z) (((x) & (y)) | (((x) | (y)) & (z)))
#define SM3_GG0(x,y,z) ((x) ^ (y) ^ (z))
#define SM3_GG1(x,y,z) ((((y) ^ (z)) & (x)) ^ (z))

/* One round, in-place: only B, D, F, H are written (B/F get their rotates,
   D receives TT1, H receives P0(TT2)); the register renaming that the spec
   expresses as an 8-variable shift is baked into the call sites with a
   period-4 pattern. TJ is the pre-rotated round constant. */
#define SM3_R(A,B,C,D,E,F,G,H, TJ, Wi, Wj, FF, GG) do { \
    uint32_t A12 = ROTL32(A,12); \
    uint32_t SS1 = ROTL32(A12 + (E) + (TJ), 7); \
    uint32_t TT1 = FF((A),(B),(C)) + (D) + (SS1 ^ A12) + (Wj); \
    uint32_t TT2 = GG((E),(F),(G)) + (H) + SS1 + (Wi); \
    (B) = ROTL32((B),9); (D) = TT1; \
    (F) = ROTL32((F),19); (H) = SM3_P0(TT2); } while (0)

/* W[t] = P1(W[t-16]^W[t-9]^rol15(W[t-3])) ^ rol7(W[t-13]) ^ W[t-6], on a
   16-name register-resident window. */
#define SM3_EXP(w0,w7,w13,w3,w10) \
    (SM3_P1((w0) ^ (w7) ^ ROTL32((w13),15)) ^ ROTL32((w3),7) ^ (w10))

#define SM3_LOAD(i) \
    (((uint32_t)p[4*(i)] << 24) | ((uint32_t)p[4*(i)+1] << 16) | \
     ((uint32_t)p[4*(i)+2] << 8) | (uint32_t)p[4*(i)+3])

static void sm3_compress(rktcrypto_sm3_ctx_t *ctx, const unsigned char *p, intptr_t nblk)
{
  uint32_t A = ctx->h[0], B = ctx->h[1], C = ctx->h[2], D = ctx->h[3];
  uint32_t E = ctx->h[4], F = ctx->h[5], G = ctx->h[6], H = ctx->h[7];
  while (nblk-- > 0) {
    uint32_t W00,W01,W02,W03,W04,W05,W06,W07,W08,W09,W10,W11,W12,W13,W14,W15;
    uint32_t sA=A, sB=B, sC=C, sD=D, sE=E, sF=F, sG=G, sH=H;
    W00=SM3_LOAD(0);  W01=SM3_LOAD(1);  W02=SM3_LOAD(2);  W03=SM3_LOAD(3);
    W04=SM3_LOAD(4);  W05=SM3_LOAD(5);  W06=SM3_LOAD(6);  W07=SM3_LOAD(7);
    W08=SM3_LOAD(8);  W09=SM3_LOAD(9);  W10=SM3_LOAD(10); W11=SM3_LOAD(11);
    W12=SM3_LOAD(12); W13=SM3_LOAD(13); W14=SM3_LOAD(14); W15=SM3_LOAD(15);
    SM3_R(A, B, C, D, E, F, G, H, 0x79cc4519u, W00, W00 ^ W04, SM3_FF0, SM3_GG0);
    W00 = SM3_EXP(W00, W07, W13, W03, W10);
    SM3_R(D, A, B, C, H, E, F, G, 0xf3988a32u, W01, W01 ^ W05, SM3_FF0, SM3_GG0);
    W01 = SM3_EXP(W01, W08, W14, W04, W11);
    SM3_R(C, D, A, B, G, H, E, F, 0xe7311465u, W02, W02 ^ W06, SM3_FF0, SM3_GG0);
    W02 = SM3_EXP(W02, W09, W15, W05, W12);
    SM3_R(B, C, D, A, F, G, H, E, 0xce6228cbu, W03, W03 ^ W07, SM3_FF0, SM3_GG0);
    W03 = SM3_EXP(W03, W10, W00, W06, W13);
    SM3_R(A, B, C, D, E, F, G, H, 0x9cc45197u, W04, W04 ^ W08, SM3_FF0, SM3_GG0);
    W04 = SM3_EXP(W04, W11, W01, W07, W14);
    SM3_R(D, A, B, C, H, E, F, G, 0x3988a32fu, W05, W05 ^ W09, SM3_FF0, SM3_GG0);
    W05 = SM3_EXP(W05, W12, W02, W08, W15);
    SM3_R(C, D, A, B, G, H, E, F, 0x7311465eu, W06, W06 ^ W10, SM3_FF0, SM3_GG0);
    W06 = SM3_EXP(W06, W13, W03, W09, W00);
    SM3_R(B, C, D, A, F, G, H, E, 0xe6228cbcu, W07, W07 ^ W11, SM3_FF0, SM3_GG0);
    W07 = SM3_EXP(W07, W14, W04, W10, W01);
    SM3_R(A, B, C, D, E, F, G, H, 0xcc451979u, W08, W08 ^ W12, SM3_FF0, SM3_GG0);
    W08 = SM3_EXP(W08, W15, W05, W11, W02);
    SM3_R(D, A, B, C, H, E, F, G, 0x988a32f3u, W09, W09 ^ W13, SM3_FF0, SM3_GG0);
    W09 = SM3_EXP(W09, W00, W06, W12, W03);
    SM3_R(C, D, A, B, G, H, E, F, 0x311465e7u, W10, W10 ^ W14, SM3_FF0, SM3_GG0);
    W10 = SM3_EXP(W10, W01, W07, W13, W04);
    SM3_R(B, C, D, A, F, G, H, E, 0x6228cbceu, W11, W11 ^ W15, SM3_FF0, SM3_GG0);
    W11 = SM3_EXP(W11, W02, W08, W14, W05);
    SM3_R(A, B, C, D, E, F, G, H, 0xc451979cu, W12, W12 ^ W00, SM3_FF0, SM3_GG0);
    W12 = SM3_EXP(W12, W03, W09, W15, W06);
    SM3_R(D, A, B, C, H, E, F, G, 0x88a32f39u, W13, W13 ^ W01, SM3_FF0, SM3_GG0);
    W13 = SM3_EXP(W13, W04, W10, W00, W07);
    SM3_R(C, D, A, B, G, H, E, F, 0x11465e73u, W14, W14 ^ W02, SM3_FF0, SM3_GG0);
    W14 = SM3_EXP(W14, W05, W11, W01, W08);
    SM3_R(B, C, D, A, F, G, H, E, 0x228cbce6u, W15, W15 ^ W03, SM3_FF0, SM3_GG0);
    W15 = SM3_EXP(W15, W06, W12, W02, W09);
    SM3_R(A, B, C, D, E, F, G, H, 0x9d8a7a87u, W00, W00 ^ W04, SM3_FF1, SM3_GG1);
    W00 = SM3_EXP(W00, W07, W13, W03, W10);
    SM3_R(D, A, B, C, H, E, F, G, 0x3b14f50fu, W01, W01 ^ W05, SM3_FF1, SM3_GG1);
    W01 = SM3_EXP(W01, W08, W14, W04, W11);
    SM3_R(C, D, A, B, G, H, E, F, 0x7629ea1eu, W02, W02 ^ W06, SM3_FF1, SM3_GG1);
    W02 = SM3_EXP(W02, W09, W15, W05, W12);
    SM3_R(B, C, D, A, F, G, H, E, 0xec53d43cu, W03, W03 ^ W07, SM3_FF1, SM3_GG1);
    W03 = SM3_EXP(W03, W10, W00, W06, W13);
    SM3_R(A, B, C, D, E, F, G, H, 0xd8a7a879u, W04, W04 ^ W08, SM3_FF1, SM3_GG1);
    W04 = SM3_EXP(W04, W11, W01, W07, W14);
    SM3_R(D, A, B, C, H, E, F, G, 0xb14f50f3u, W05, W05 ^ W09, SM3_FF1, SM3_GG1);
    W05 = SM3_EXP(W05, W12, W02, W08, W15);
    SM3_R(C, D, A, B, G, H, E, F, 0x629ea1e7u, W06, W06 ^ W10, SM3_FF1, SM3_GG1);
    W06 = SM3_EXP(W06, W13, W03, W09, W00);
    SM3_R(B, C, D, A, F, G, H, E, 0xc53d43ceu, W07, W07 ^ W11, SM3_FF1, SM3_GG1);
    W07 = SM3_EXP(W07, W14, W04, W10, W01);
    SM3_R(A, B, C, D, E, F, G, H, 0x8a7a879du, W08, W08 ^ W12, SM3_FF1, SM3_GG1);
    W08 = SM3_EXP(W08, W15, W05, W11, W02);
    SM3_R(D, A, B, C, H, E, F, G, 0x14f50f3bu, W09, W09 ^ W13, SM3_FF1, SM3_GG1);
    W09 = SM3_EXP(W09, W00, W06, W12, W03);
    SM3_R(C, D, A, B, G, H, E, F, 0x29ea1e76u, W10, W10 ^ W14, SM3_FF1, SM3_GG1);
    W10 = SM3_EXP(W10, W01, W07, W13, W04);
    SM3_R(B, C, D, A, F, G, H, E, 0x53d43cecu, W11, W11 ^ W15, SM3_FF1, SM3_GG1);
    W11 = SM3_EXP(W11, W02, W08, W14, W05);
    SM3_R(A, B, C, D, E, F, G, H, 0xa7a879d8u, W12, W12 ^ W00, SM3_FF1, SM3_GG1);
    W12 = SM3_EXP(W12, W03, W09, W15, W06);
    SM3_R(D, A, B, C, H, E, F, G, 0x4f50f3b1u, W13, W13 ^ W01, SM3_FF1, SM3_GG1);
    W13 = SM3_EXP(W13, W04, W10, W00, W07);
    SM3_R(C, D, A, B, G, H, E, F, 0x9ea1e762u, W14, W14 ^ W02, SM3_FF1, SM3_GG1);
    W14 = SM3_EXP(W14, W05, W11, W01, W08);
    SM3_R(B, C, D, A, F, G, H, E, 0x3d43cec5u, W15, W15 ^ W03, SM3_FF1, SM3_GG1);
    W15 = SM3_EXP(W15, W06, W12, W02, W09);
    SM3_R(A, B, C, D, E, F, G, H, 0x7a879d8au, W00, W00 ^ W04, SM3_FF1, SM3_GG1);
    W00 = SM3_EXP(W00, W07, W13, W03, W10);
    SM3_R(D, A, B, C, H, E, F, G, 0xf50f3b14u, W01, W01 ^ W05, SM3_FF1, SM3_GG1);
    W01 = SM3_EXP(W01, W08, W14, W04, W11);
    SM3_R(C, D, A, B, G, H, E, F, 0xea1e7629u, W02, W02 ^ W06, SM3_FF1, SM3_GG1);
    W02 = SM3_EXP(W02, W09, W15, W05, W12);
    SM3_R(B, C, D, A, F, G, H, E, 0xd43cec53u, W03, W03 ^ W07, SM3_FF1, SM3_GG1);
    W03 = SM3_EXP(W03, W10, W00, W06, W13);
    SM3_R(A, B, C, D, E, F, G, H, 0xa879d8a7u, W04, W04 ^ W08, SM3_FF1, SM3_GG1);
    W04 = SM3_EXP(W04, W11, W01, W07, W14);
    SM3_R(D, A, B, C, H, E, F, G, 0x50f3b14fu, W05, W05 ^ W09, SM3_FF1, SM3_GG1);
    W05 = SM3_EXP(W05, W12, W02, W08, W15);
    SM3_R(C, D, A, B, G, H, E, F, 0xa1e7629eu, W06, W06 ^ W10, SM3_FF1, SM3_GG1);
    W06 = SM3_EXP(W06, W13, W03, W09, W00);
    SM3_R(B, C, D, A, F, G, H, E, 0x43cec53du, W07, W07 ^ W11, SM3_FF1, SM3_GG1);
    W07 = SM3_EXP(W07, W14, W04, W10, W01);
    SM3_R(A, B, C, D, E, F, G, H, 0x879d8a7au, W08, W08 ^ W12, SM3_FF1, SM3_GG1);
    W08 = SM3_EXP(W08, W15, W05, W11, W02);
    SM3_R(D, A, B, C, H, E, F, G, 0x0f3b14f5u, W09, W09 ^ W13, SM3_FF1, SM3_GG1);
    W09 = SM3_EXP(W09, W00, W06, W12, W03);
    SM3_R(C, D, A, B, G, H, E, F, 0x1e7629eau, W10, W10 ^ W14, SM3_FF1, SM3_GG1);
    W10 = SM3_EXP(W10, W01, W07, W13, W04);
    SM3_R(B, C, D, A, F, G, H, E, 0x3cec53d4u, W11, W11 ^ W15, SM3_FF1, SM3_GG1);
    W11 = SM3_EXP(W11, W02, W08, W14, W05);
    SM3_R(A, B, C, D, E, F, G, H, 0x79d8a7a8u, W12, W12 ^ W00, SM3_FF1, SM3_GG1);
    W12 = SM3_EXP(W12, W03, W09, W15, W06);
    SM3_R(D, A, B, C, H, E, F, G, 0xf3b14f50u, W13, W13 ^ W01, SM3_FF1, SM3_GG1);
    W13 = SM3_EXP(W13, W04, W10, W00, W07);
    SM3_R(C, D, A, B, G, H, E, F, 0xe7629ea1u, W14, W14 ^ W02, SM3_FF1, SM3_GG1);
    W14 = SM3_EXP(W14, W05, W11, W01, W08);
    SM3_R(B, C, D, A, F, G, H, E, 0xcec53d43u, W15, W15 ^ W03, SM3_FF1, SM3_GG1);
    W15 = SM3_EXP(W15, W06, W12, W02, W09);
    SM3_R(A, B, C, D, E, F, G, H, 0x9d8a7a87u, W00, W00 ^ W04, SM3_FF1, SM3_GG1);
    W00 = SM3_EXP(W00, W07, W13, W03, W10);
    SM3_R(D, A, B, C, H, E, F, G, 0x3b14f50fu, W01, W01 ^ W05, SM3_FF1, SM3_GG1);
    W01 = SM3_EXP(W01, W08, W14, W04, W11);
    SM3_R(C, D, A, B, G, H, E, F, 0x7629ea1eu, W02, W02 ^ W06, SM3_FF1, SM3_GG1);
    W02 = SM3_EXP(W02, W09, W15, W05, W12);
    SM3_R(B, C, D, A, F, G, H, E, 0xec53d43cu, W03, W03 ^ W07, SM3_FF1, SM3_GG1);
    W03 = SM3_EXP(W03, W10, W00, W06, W13);
    SM3_R(A, B, C, D, E, F, G, H, 0xd8a7a879u, W04, W04 ^ W08, SM3_FF1, SM3_GG1);
    SM3_R(D, A, B, C, H, E, F, G, 0xb14f50f3u, W05, W05 ^ W09, SM3_FF1, SM3_GG1);
    SM3_R(C, D, A, B, G, H, E, F, 0x629ea1e7u, W06, W06 ^ W10, SM3_FF1, SM3_GG1);
    SM3_R(B, C, D, A, F, G, H, E, 0xc53d43ceu, W07, W07 ^ W11, SM3_FF1, SM3_GG1);
    SM3_R(A, B, C, D, E, F, G, H, 0x8a7a879du, W08, W08 ^ W12, SM3_FF1, SM3_GG1);
    SM3_R(D, A, B, C, H, E, F, G, 0x14f50f3bu, W09, W09 ^ W13, SM3_FF1, SM3_GG1);
    SM3_R(C, D, A, B, G, H, E, F, 0x29ea1e76u, W10, W10 ^ W14, SM3_FF1, SM3_GG1);
    SM3_R(B, C, D, A, F, G, H, E, 0x53d43cecu, W11, W11 ^ W15, SM3_FF1, SM3_GG1);
    SM3_R(A, B, C, D, E, F, G, H, 0xa7a879d8u, W12, W12 ^ W00, SM3_FF1, SM3_GG1);
    SM3_R(D, A, B, C, H, E, F, G, 0x4f50f3b1u, W13, W13 ^ W01, SM3_FF1, SM3_GG1);
    SM3_R(C, D, A, B, G, H, E, F, 0x9ea1e762u, W14, W14 ^ W02, SM3_FF1, SM3_GG1);
    SM3_R(B, C, D, A, F, G, H, E, 0x3d43cec5u, W15, W15 ^ W03, SM3_FF1, SM3_GG1);
    A ^= sA; B ^= sB; C ^= sC; D ^= sD; E ^= sE; F ^= sF; G ^= sG; H ^= sH;
    p += 64;
  }
  ctx->h[0]=A; ctx->h[1]=B; ctx->h[2]=C; ctx->h[3]=D;
  ctx->h[4]=E; ctx->h[5]=F; ctx->h[6]=G; ctx->h[7]=H;
}

void rktcrypto_sm3_core_update(rktcrypto_sm3_ctx_t *ctx,
                               const unsigned char *data, intptr_t len)
{
  ctx->len += (uint64_t)len * 8;
  if (ctx->buf_len) {
    while (len && ctx->buf_len < 64) { ctx->buf[ctx->buf_len++] = *data++; len--; }
    if (ctx->buf_len == 64) { sm3_compress(ctx, ctx->buf, 1); ctx->buf_len = 0; }
  }
  if (len >= 64) { intptr_t nb = len >> 6; sm3_compress(ctx, data, nb); data += nb<<6; len -= nb<<6; }
  while (len) { ctx->buf[ctx->buf_len++] = *data++; len--; }
}

void rktcrypto_sm3_core_final(rktcrypto_sm3_ctx_t *ctx,
                              unsigned char *out, intptr_t out_len)
{
  uint64_t bits = ctx->len;
  int i;
  unsigned char pad = 0x80;
  (void)out_len;
  rktcrypto_sm3_core_update(ctx, &pad, 1);
  ctx->len -= 8;
  pad = 0;
  while (ctx->buf_len != 56) { rktcrypto_sm3_core_update(ctx, &pad, 1); ctx->len -= 8; }
  for (i = 0; i < 8; i++) ctx->buf[ctx->buf_len++] = (unsigned char)(bits >> (56 - 8*i));
  sm3_compress(ctx, ctx->buf, 1); ctx->buf_len = 0;
  for (i = 0; i < 8; i++) {
    out[4*i+0] = (unsigned char)(ctx->h[i] >> 24);
    out[4*i+1] = (unsigned char)(ctx->h[i] >> 16);
    out[4*i+2] = (unsigned char)(ctx->h[i] >> 8);
    out[4*i+3] = (unsigned char)(ctx->h[i]);
  }
}
