/* RIPEMD-160 (ISO/IEC 10118-3, Dobbertin/Bosselaers/Preneel 1996).

   160-bit digest over 512-bit blocks: two independent 80-step lines (left
   and right) over the same message words, combined into the chaining
   value. Not broken, but 80-bit collision security is below modern
   requirements; provided for interoperability (notably Bitcoin-style
   HASH160 and PGP fingerprints). From scratch, no external code. */

#include "rktcrypto_digest.h"
#include <string.h>

#define ROTL32(x,n) (((x) << (n)) | ((x) >> (32 - (n))))

void rktcrypto_rmd160_core_init(rktcrypto_rmd160_ctx_t *ctx)
{
  ctx->h[0] = 0x67452301u; ctx->h[1] = 0xEFCDAB89u; ctx->h[2] = 0x98BADCFEu;
  ctx->h[3] = 0x10325476u; ctx->h[4] = 0xC3D2E1F0u;
  ctx->len = 0; ctx->buf_len = 0;
}

/* Boolean functions f1..f5; the left line applies them in order 1..5 over
   its five 16-step phases, the right line in order 5..1. */
#define RMD_F1(x,y,z) ((x) ^ (y) ^ (z))
#define RMD_F2(x,y,z) (((x) & (y)) | ((~(x)) & (z)))
#define RMD_F3(x,y,z) (((x) | ~(y)) ^ (z))
#define RMD_F4(x,y,z) (((x) & (z)) | ((y) & (~(z))))
#define RMD_F5(x,y,z) ((x) ^ ((y) | ~(z)))


/* One step: a += f(b,c,d) + X + K; a = rol_s(a) + e; c = rol10(c).
   The caller rotates the role of the five variables. */
#define RMD_STEP(f,a,b,c,d,e,x,k,s) do { \
    (a) += f((b),(c),(d)) + (x) + (k); \
    (a) = ROTL32((a),(s)) + (e); \
    (c) = ROTL32((c),10); } while (0)

static void rmd160_block(rktcrypto_rmd160_ctx_t *ctx, const unsigned char *p)
{
  uint32_t m[16];
  uint32_t al, bl, cl, dl, el, ar, br, cr, dr, er, t;
  int i;
  for (i = 0; i < 16; i++)
    m[i] = (uint32_t)p[4*i] | ((uint32_t)p[4*i+1] << 8)
         | ((uint32_t)p[4*i+2] << 16) | ((uint32_t)p[4*i+3] << 24);
  al = ar = ctx->h[0]; bl = br = ctx->h[1]; cl = cr = ctx->h[2];
  dl = dr = ctx->h[3]; el = er = ctx->h[4];

  /* All 160 steps unrolled (script-generated from the spec tables), left and
     right lines interleaved step-by-step: each line is a serial dependency
     chain, the two chains are independent, so interleaving doubles ILP. The
     five-variable role rotation is baked into the call sites. */
  RMD_STEP(RMD_F1, al,bl,cl,dl,el, m[ 0], 0x00000000u, 11);
  RMD_STEP(RMD_F5, ar,br,cr,dr,er, m[ 5], 0x50A28BE6u,  8);
  RMD_STEP(RMD_F1, el,al,bl,cl,dl, m[ 1], 0x00000000u, 14);
  RMD_STEP(RMD_F5, er,ar,br,cr,dr, m[14], 0x50A28BE6u,  9);
  RMD_STEP(RMD_F1, dl,el,al,bl,cl, m[ 2], 0x00000000u, 15);
  RMD_STEP(RMD_F5, dr,er,ar,br,cr, m[ 7], 0x50A28BE6u,  9);
  RMD_STEP(RMD_F1, cl,dl,el,al,bl, m[ 3], 0x00000000u, 12);
  RMD_STEP(RMD_F5, cr,dr,er,ar,br, m[ 0], 0x50A28BE6u, 11);
  RMD_STEP(RMD_F1, bl,cl,dl,el,al, m[ 4], 0x00000000u,  5);
  RMD_STEP(RMD_F5, br,cr,dr,er,ar, m[ 9], 0x50A28BE6u, 13);
  RMD_STEP(RMD_F1, al,bl,cl,dl,el, m[ 5], 0x00000000u,  8);
  RMD_STEP(RMD_F5, ar,br,cr,dr,er, m[ 2], 0x50A28BE6u, 15);
  RMD_STEP(RMD_F1, el,al,bl,cl,dl, m[ 6], 0x00000000u,  7);
  RMD_STEP(RMD_F5, er,ar,br,cr,dr, m[11], 0x50A28BE6u, 15);
  RMD_STEP(RMD_F1, dl,el,al,bl,cl, m[ 7], 0x00000000u,  9);
  RMD_STEP(RMD_F5, dr,er,ar,br,cr, m[ 4], 0x50A28BE6u,  5);
  RMD_STEP(RMD_F1, cl,dl,el,al,bl, m[ 8], 0x00000000u, 11);
  RMD_STEP(RMD_F5, cr,dr,er,ar,br, m[13], 0x50A28BE6u,  7);
  RMD_STEP(RMD_F1, bl,cl,dl,el,al, m[ 9], 0x00000000u, 13);
  RMD_STEP(RMD_F5, br,cr,dr,er,ar, m[ 6], 0x50A28BE6u,  7);
  RMD_STEP(RMD_F1, al,bl,cl,dl,el, m[10], 0x00000000u, 14);
  RMD_STEP(RMD_F5, ar,br,cr,dr,er, m[15], 0x50A28BE6u,  8);
  RMD_STEP(RMD_F1, el,al,bl,cl,dl, m[11], 0x00000000u, 15);
  RMD_STEP(RMD_F5, er,ar,br,cr,dr, m[ 8], 0x50A28BE6u, 11);
  RMD_STEP(RMD_F1, dl,el,al,bl,cl, m[12], 0x00000000u,  6);
  RMD_STEP(RMD_F5, dr,er,ar,br,cr, m[ 1], 0x50A28BE6u, 14);
  RMD_STEP(RMD_F1, cl,dl,el,al,bl, m[13], 0x00000000u,  7);
  RMD_STEP(RMD_F5, cr,dr,er,ar,br, m[10], 0x50A28BE6u, 14);
  RMD_STEP(RMD_F1, bl,cl,dl,el,al, m[14], 0x00000000u,  9);
  RMD_STEP(RMD_F5, br,cr,dr,er,ar, m[ 3], 0x50A28BE6u, 12);
  RMD_STEP(RMD_F1, al,bl,cl,dl,el, m[15], 0x00000000u,  8);
  RMD_STEP(RMD_F5, ar,br,cr,dr,er, m[12], 0x50A28BE6u,  6);
  RMD_STEP(RMD_F2, el,al,bl,cl,dl, m[ 7], 0x5A827999u,  7);
  RMD_STEP(RMD_F4, er,ar,br,cr,dr, m[ 6], 0x5C4DD124u,  9);
  RMD_STEP(RMD_F2, dl,el,al,bl,cl, m[ 4], 0x5A827999u,  6);
  RMD_STEP(RMD_F4, dr,er,ar,br,cr, m[11], 0x5C4DD124u, 13);
  RMD_STEP(RMD_F2, cl,dl,el,al,bl, m[13], 0x5A827999u,  8);
  RMD_STEP(RMD_F4, cr,dr,er,ar,br, m[ 3], 0x5C4DD124u, 15);
  RMD_STEP(RMD_F2, bl,cl,dl,el,al, m[ 1], 0x5A827999u, 13);
  RMD_STEP(RMD_F4, br,cr,dr,er,ar, m[ 7], 0x5C4DD124u,  7);
  RMD_STEP(RMD_F2, al,bl,cl,dl,el, m[10], 0x5A827999u, 11);
  RMD_STEP(RMD_F4, ar,br,cr,dr,er, m[ 0], 0x5C4DD124u, 12);
  RMD_STEP(RMD_F2, el,al,bl,cl,dl, m[ 6], 0x5A827999u,  9);
  RMD_STEP(RMD_F4, er,ar,br,cr,dr, m[13], 0x5C4DD124u,  8);
  RMD_STEP(RMD_F2, dl,el,al,bl,cl, m[15], 0x5A827999u,  7);
  RMD_STEP(RMD_F4, dr,er,ar,br,cr, m[ 5], 0x5C4DD124u,  9);
  RMD_STEP(RMD_F2, cl,dl,el,al,bl, m[ 3], 0x5A827999u, 15);
  RMD_STEP(RMD_F4, cr,dr,er,ar,br, m[10], 0x5C4DD124u, 11);
  RMD_STEP(RMD_F2, bl,cl,dl,el,al, m[12], 0x5A827999u,  7);
  RMD_STEP(RMD_F4, br,cr,dr,er,ar, m[14], 0x5C4DD124u,  7);
  RMD_STEP(RMD_F2, al,bl,cl,dl,el, m[ 0], 0x5A827999u, 12);
  RMD_STEP(RMD_F4, ar,br,cr,dr,er, m[15], 0x5C4DD124u,  7);
  RMD_STEP(RMD_F2, el,al,bl,cl,dl, m[ 9], 0x5A827999u, 15);
  RMD_STEP(RMD_F4, er,ar,br,cr,dr, m[ 8], 0x5C4DD124u, 12);
  RMD_STEP(RMD_F2, dl,el,al,bl,cl, m[ 5], 0x5A827999u,  9);
  RMD_STEP(RMD_F4, dr,er,ar,br,cr, m[12], 0x5C4DD124u,  7);
  RMD_STEP(RMD_F2, cl,dl,el,al,bl, m[ 2], 0x5A827999u, 11);
  RMD_STEP(RMD_F4, cr,dr,er,ar,br, m[ 4], 0x5C4DD124u,  6);
  RMD_STEP(RMD_F2, bl,cl,dl,el,al, m[14], 0x5A827999u,  7);
  RMD_STEP(RMD_F4, br,cr,dr,er,ar, m[ 9], 0x5C4DD124u, 15);
  RMD_STEP(RMD_F2, al,bl,cl,dl,el, m[11], 0x5A827999u, 13);
  RMD_STEP(RMD_F4, ar,br,cr,dr,er, m[ 1], 0x5C4DD124u, 13);
  RMD_STEP(RMD_F2, el,al,bl,cl,dl, m[ 8], 0x5A827999u, 12);
  RMD_STEP(RMD_F4, er,ar,br,cr,dr, m[ 2], 0x5C4DD124u, 11);
  RMD_STEP(RMD_F3, dl,el,al,bl,cl, m[ 3], 0x6ED9EBA1u, 11);
  RMD_STEP(RMD_F3, dr,er,ar,br,cr, m[15], 0x6D703EF3u,  9);
  RMD_STEP(RMD_F3, cl,dl,el,al,bl, m[10], 0x6ED9EBA1u, 13);
  RMD_STEP(RMD_F3, cr,dr,er,ar,br, m[ 5], 0x6D703EF3u,  7);
  RMD_STEP(RMD_F3, bl,cl,dl,el,al, m[14], 0x6ED9EBA1u,  6);
  RMD_STEP(RMD_F3, br,cr,dr,er,ar, m[ 1], 0x6D703EF3u, 15);
  RMD_STEP(RMD_F3, al,bl,cl,dl,el, m[ 4], 0x6ED9EBA1u,  7);
  RMD_STEP(RMD_F3, ar,br,cr,dr,er, m[ 3], 0x6D703EF3u, 11);
  RMD_STEP(RMD_F3, el,al,bl,cl,dl, m[ 9], 0x6ED9EBA1u, 14);
  RMD_STEP(RMD_F3, er,ar,br,cr,dr, m[ 7], 0x6D703EF3u,  8);
  RMD_STEP(RMD_F3, dl,el,al,bl,cl, m[15], 0x6ED9EBA1u,  9);
  RMD_STEP(RMD_F3, dr,er,ar,br,cr, m[14], 0x6D703EF3u,  6);
  RMD_STEP(RMD_F3, cl,dl,el,al,bl, m[ 8], 0x6ED9EBA1u, 13);
  RMD_STEP(RMD_F3, cr,dr,er,ar,br, m[ 6], 0x6D703EF3u,  6);
  RMD_STEP(RMD_F3, bl,cl,dl,el,al, m[ 1], 0x6ED9EBA1u, 15);
  RMD_STEP(RMD_F3, br,cr,dr,er,ar, m[ 9], 0x6D703EF3u, 14);
  RMD_STEP(RMD_F3, al,bl,cl,dl,el, m[ 2], 0x6ED9EBA1u, 14);
  RMD_STEP(RMD_F3, ar,br,cr,dr,er, m[11], 0x6D703EF3u, 12);
  RMD_STEP(RMD_F3, el,al,bl,cl,dl, m[ 7], 0x6ED9EBA1u,  8);
  RMD_STEP(RMD_F3, er,ar,br,cr,dr, m[ 8], 0x6D703EF3u, 13);
  RMD_STEP(RMD_F3, dl,el,al,bl,cl, m[ 0], 0x6ED9EBA1u, 13);
  RMD_STEP(RMD_F3, dr,er,ar,br,cr, m[12], 0x6D703EF3u,  5);
  RMD_STEP(RMD_F3, cl,dl,el,al,bl, m[ 6], 0x6ED9EBA1u,  6);
  RMD_STEP(RMD_F3, cr,dr,er,ar,br, m[ 2], 0x6D703EF3u, 14);
  RMD_STEP(RMD_F3, bl,cl,dl,el,al, m[13], 0x6ED9EBA1u,  5);
  RMD_STEP(RMD_F3, br,cr,dr,er,ar, m[10], 0x6D703EF3u, 13);
  RMD_STEP(RMD_F3, al,bl,cl,dl,el, m[11], 0x6ED9EBA1u, 12);
  RMD_STEP(RMD_F3, ar,br,cr,dr,er, m[ 0], 0x6D703EF3u, 13);
  RMD_STEP(RMD_F3, el,al,bl,cl,dl, m[ 5], 0x6ED9EBA1u,  7);
  RMD_STEP(RMD_F3, er,ar,br,cr,dr, m[ 4], 0x6D703EF3u,  7);
  RMD_STEP(RMD_F3, dl,el,al,bl,cl, m[12], 0x6ED9EBA1u,  5);
  RMD_STEP(RMD_F3, dr,er,ar,br,cr, m[13], 0x6D703EF3u,  5);
  RMD_STEP(RMD_F4, cl,dl,el,al,bl, m[ 1], 0x8F1BBCDCu, 11);
  RMD_STEP(RMD_F2, cr,dr,er,ar,br, m[ 8], 0x7A6D76E9u, 15);
  RMD_STEP(RMD_F4, bl,cl,dl,el,al, m[ 9], 0x8F1BBCDCu, 12);
  RMD_STEP(RMD_F2, br,cr,dr,er,ar, m[ 6], 0x7A6D76E9u,  5);
  RMD_STEP(RMD_F4, al,bl,cl,dl,el, m[11], 0x8F1BBCDCu, 14);
  RMD_STEP(RMD_F2, ar,br,cr,dr,er, m[ 4], 0x7A6D76E9u,  8);
  RMD_STEP(RMD_F4, el,al,bl,cl,dl, m[10], 0x8F1BBCDCu, 15);
  RMD_STEP(RMD_F2, er,ar,br,cr,dr, m[ 1], 0x7A6D76E9u, 11);
  RMD_STEP(RMD_F4, dl,el,al,bl,cl, m[ 0], 0x8F1BBCDCu, 14);
  RMD_STEP(RMD_F2, dr,er,ar,br,cr, m[ 3], 0x7A6D76E9u, 14);
  RMD_STEP(RMD_F4, cl,dl,el,al,bl, m[ 8], 0x8F1BBCDCu, 15);
  RMD_STEP(RMD_F2, cr,dr,er,ar,br, m[11], 0x7A6D76E9u, 14);
  RMD_STEP(RMD_F4, bl,cl,dl,el,al, m[12], 0x8F1BBCDCu,  9);
  RMD_STEP(RMD_F2, br,cr,dr,er,ar, m[15], 0x7A6D76E9u,  6);
  RMD_STEP(RMD_F4, al,bl,cl,dl,el, m[ 4], 0x8F1BBCDCu,  8);
  RMD_STEP(RMD_F2, ar,br,cr,dr,er, m[ 0], 0x7A6D76E9u, 14);
  RMD_STEP(RMD_F4, el,al,bl,cl,dl, m[13], 0x8F1BBCDCu,  9);
  RMD_STEP(RMD_F2, er,ar,br,cr,dr, m[ 5], 0x7A6D76E9u,  6);
  RMD_STEP(RMD_F4, dl,el,al,bl,cl, m[ 3], 0x8F1BBCDCu, 14);
  RMD_STEP(RMD_F2, dr,er,ar,br,cr, m[12], 0x7A6D76E9u,  9);
  RMD_STEP(RMD_F4, cl,dl,el,al,bl, m[ 7], 0x8F1BBCDCu,  5);
  RMD_STEP(RMD_F2, cr,dr,er,ar,br, m[ 2], 0x7A6D76E9u, 12);
  RMD_STEP(RMD_F4, bl,cl,dl,el,al, m[15], 0x8F1BBCDCu,  6);
  RMD_STEP(RMD_F2, br,cr,dr,er,ar, m[13], 0x7A6D76E9u,  9);
  RMD_STEP(RMD_F4, al,bl,cl,dl,el, m[14], 0x8F1BBCDCu,  8);
  RMD_STEP(RMD_F2, ar,br,cr,dr,er, m[ 9], 0x7A6D76E9u, 12);
  RMD_STEP(RMD_F4, el,al,bl,cl,dl, m[ 5], 0x8F1BBCDCu,  6);
  RMD_STEP(RMD_F2, er,ar,br,cr,dr, m[ 7], 0x7A6D76E9u,  5);
  RMD_STEP(RMD_F4, dl,el,al,bl,cl, m[ 6], 0x8F1BBCDCu,  5);
  RMD_STEP(RMD_F2, dr,er,ar,br,cr, m[10], 0x7A6D76E9u, 15);
  RMD_STEP(RMD_F4, cl,dl,el,al,bl, m[ 2], 0x8F1BBCDCu, 12);
  RMD_STEP(RMD_F2, cr,dr,er,ar,br, m[14], 0x7A6D76E9u,  8);
  RMD_STEP(RMD_F5, bl,cl,dl,el,al, m[ 4], 0xA953FD4Eu,  9);
  RMD_STEP(RMD_F1, br,cr,dr,er,ar, m[12], 0x00000000u,  8);
  RMD_STEP(RMD_F5, al,bl,cl,dl,el, m[ 0], 0xA953FD4Eu, 15);
  RMD_STEP(RMD_F1, ar,br,cr,dr,er, m[15], 0x00000000u,  5);
  RMD_STEP(RMD_F5, el,al,bl,cl,dl, m[ 5], 0xA953FD4Eu,  5);
  RMD_STEP(RMD_F1, er,ar,br,cr,dr, m[10], 0x00000000u, 12);
  RMD_STEP(RMD_F5, dl,el,al,bl,cl, m[ 9], 0xA953FD4Eu, 11);
  RMD_STEP(RMD_F1, dr,er,ar,br,cr, m[ 4], 0x00000000u,  9);
  RMD_STEP(RMD_F5, cl,dl,el,al,bl, m[ 7], 0xA953FD4Eu,  6);
  RMD_STEP(RMD_F1, cr,dr,er,ar,br, m[ 1], 0x00000000u, 12);
  RMD_STEP(RMD_F5, bl,cl,dl,el,al, m[12], 0xA953FD4Eu,  8);
  RMD_STEP(RMD_F1, br,cr,dr,er,ar, m[ 5], 0x00000000u,  5);
  RMD_STEP(RMD_F5, al,bl,cl,dl,el, m[ 2], 0xA953FD4Eu, 13);
  RMD_STEP(RMD_F1, ar,br,cr,dr,er, m[ 8], 0x00000000u, 14);
  RMD_STEP(RMD_F5, el,al,bl,cl,dl, m[10], 0xA953FD4Eu, 12);
  RMD_STEP(RMD_F1, er,ar,br,cr,dr, m[ 7], 0x00000000u,  6);
  RMD_STEP(RMD_F5, dl,el,al,bl,cl, m[14], 0xA953FD4Eu,  5);
  RMD_STEP(RMD_F1, dr,er,ar,br,cr, m[ 6], 0x00000000u,  8);
  RMD_STEP(RMD_F5, cl,dl,el,al,bl, m[ 1], 0xA953FD4Eu, 12);
  RMD_STEP(RMD_F1, cr,dr,er,ar,br, m[ 2], 0x00000000u, 13);
  RMD_STEP(RMD_F5, bl,cl,dl,el,al, m[ 3], 0xA953FD4Eu, 13);
  RMD_STEP(RMD_F1, br,cr,dr,er,ar, m[13], 0x00000000u,  6);
  RMD_STEP(RMD_F5, al,bl,cl,dl,el, m[ 8], 0xA953FD4Eu, 14);
  RMD_STEP(RMD_F1, ar,br,cr,dr,er, m[14], 0x00000000u,  5);
  RMD_STEP(RMD_F5, el,al,bl,cl,dl, m[11], 0xA953FD4Eu, 11);
  RMD_STEP(RMD_F1, er,ar,br,cr,dr, m[ 0], 0x00000000u, 15);
  RMD_STEP(RMD_F5, dl,el,al,bl,cl, m[ 6], 0xA953FD4Eu,  8);
  RMD_STEP(RMD_F1, dr,er,ar,br,cr, m[ 3], 0x00000000u, 13);
  RMD_STEP(RMD_F5, cl,dl,el,al,bl, m[15], 0xA953FD4Eu,  5);
  RMD_STEP(RMD_F1, cr,dr,er,ar,br, m[ 9], 0x00000000u, 11);
  RMD_STEP(RMD_F5, bl,cl,dl,el,al, m[13], 0xA953FD4Eu,  6);
  RMD_STEP(RMD_F1, br,cr,dr,er,ar, m[11], 0x00000000u, 11);

  t          = ctx->h[1] + cl + dr;
  ctx->h[1]  = ctx->h[2] + dl + er;
  ctx->h[2]  = ctx->h[3] + el + ar;
  ctx->h[3]  = ctx->h[4] + al + br;
  ctx->h[4]  = ctx->h[0] + bl + cr;
  ctx->h[0]  = t;
}

void rktcrypto_rmd160_core_update(rktcrypto_rmd160_ctx_t *ctx,
                                  const unsigned char *data, intptr_t len)
{
  ctx->len += (uint64_t)len * 8;
  if (ctx->buf_len) {
    while (len && ctx->buf_len < 64) { ctx->buf[ctx->buf_len++] = *data++; len--; }
    if (ctx->buf_len == 64) { rmd160_block(ctx, ctx->buf); ctx->buf_len = 0; }
  }
  while (len >= 64) { rmd160_block(ctx, data); data += 64; len -= 64; }
  while (len) { ctx->buf[ctx->buf_len++] = *data++; len--; }
}

void rktcrypto_rmd160_core_final(rktcrypto_rmd160_ctx_t *ctx,
                                 unsigned char *out, intptr_t out_len)
{
  uint64_t bits = ctx->len;
  int i;
  unsigned char pad = 0x80;
  (void)out_len;
  rktcrypto_rmd160_core_update(ctx, &pad, 1);
  ctx->len -= 8;
  pad = 0;
  while (ctx->buf_len != 56) { rktcrypto_rmd160_core_update(ctx, &pad, 1); ctx->len -= 8; }
  for (i = 0; i < 8; i++) ctx->buf[ctx->buf_len++] = (unsigned char)(bits >> (8*i));
  rmd160_block(ctx, ctx->buf); ctx->buf_len = 0;
  for (i = 0; i < 5; i++) {
    out[4*i+0] = (unsigned char)(ctx->h[i]);
    out[4*i+1] = (unsigned char)(ctx->h[i] >> 8);
    out[4*i+2] = (unsigned char)(ctx->h[i] >> 16);
    out[4*i+3] = (unsigned char)(ctx->h[i] >> 24);
  }
}
