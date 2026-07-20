/* Ed448 signatures (RFC 8032), pure mode with empty context. Edwards curve
   edwards448 (a=1, d=-39081) over p = 2^448-2^224-1, SHAKE256 hashing, and
   scalar arithmetic mod the group order L via the in-tree bignum. Field
   elements use a reduced-radix 8x56 Goldilocks field; point arithmetic uses extended
   coordinates with the complete a=1 Edwards addition. From scratch, no
   external code. */

#include "rktcrypto.h"
#include "rktcrypto_digest.h"
#include "rktcrypto_bn.h"
#include <string.h>
#include <stdint.h>

typedef uint64_t u64;
#define NL 8
#define M56 0xffffffffffffffULL

/* p = 2^448 - 2^224 - 1 in reduced-radix 8x56 (224 = 4*56 -> limb-aligned fold) */
static const u64 P448[NL]={0xffffffffffffffULL,0xffffffffffffffULL,0xffffffffffffffULL,0xffffffffffffffULL,0xfffffffffffffeULL,0xffffffffffffffULL,0xffffffffffffffULL,0xffffffffffffffULL};
static const u64 TWOP[NL]={0x1fffffffffffffeULL,0x1fffffffffffffeULL,0x1fffffffffffffeULL,0x1fffffffffffffeULL,0x1fffffffffffffcULL,0x1fffffffffffffeULL,0x1fffffffffffffeULL,0x1fffffffffffffeULL};

/* group order L (big-endian, 56 bytes) = 2^446 - 138380...503885 */
static const unsigned char L_BE[56]={
  0x3f,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x7c,0xca,0x23,0xe9,
  0xc4,0x4e,0xdb,0x49,0xae,0xd6,0x36,0x90,0x21,0x6c,0xc2,0x72,0x8d,0xc5,0x8f,0x55,
  0x23,0x78,0xc2,0x92,0xab,0x58,0x44,0xf3};

/* base point (big-endian, 56 bytes) */
static const unsigned char GX_BE[56]={
  0x4f,0x19,0x70,0xc6,0x6b,0xed,0x0d,0xed,0x22,0x1d,0x15,0xa6,0x22,0xbf,0x36,0xda,
  0x9e,0x14,0x65,0x70,0x47,0x0f,0x17,0x67,0xea,0x6d,0xe3,0x24,0xa3,0xd3,0xa4,0x64,
  0x12,0xae,0x1a,0xf7,0x2a,0xb6,0x65,0x11,0x43,0x3b,0x80,0xe1,0x8b,0x00,0x93,0x8e,
  0x26,0x26,0xa8,0x2b,0xc7,0x0c,0xc0,0x5e};
static const unsigned char GY_BE[56]={
  0x69,0x3f,0x46,0x71,0x6e,0xb6,0xbc,0x24,0x88,0x76,0x20,0x37,0x56,0xc9,0xc7,0x62,
  0x4b,0xea,0x73,0x73,0x6c,0xa3,0x98,0x40,0x87,0x78,0x9c,0x1e,0x05,0xa0,0xc2,0xd7,
  0x3a,0xd3,0xff,0x1c,0xe6,0x7c,0x39,0xc4,0xfd,0xbd,0x13,0x2c,0x4e,0xd7,0xc8,0xad,
  0x98,0x08,0x79,0x5b,0xf2,0x30,0xfa,0x14};

static u64 g_dmont[NL]; static int inited=0;

/* ---- reduced-radix 8x56 field (2^448=2^224+1 fold: digit@8+k -> limb k & k+4) ---- */
static void fe_copy(u64 *r,const u64 *a){ int i; for(i=0;i<8;i++) r[i]=a[i]; }
static void fadd(u64 *r,const u64 *a,const u64 *b){ int i; for(i=0;i<8;i++) r[i]=a[i]+b[i]; }
static void fsub(u64 *r,const u64 *a,const u64 *b){ int i; for(i=0;i<8;i++) r[i]=a[i]+TWOP[i]-b[i]; }
static void fe_carry_fold(u64 *h,u128 acc[8]){
  u64 c=0,c0,c4; int i;
  for(i=0;i<8;i++){ u128 v=acc[i]+c; h[i]=(u64)v&M56; c=(u64)(v>>56); }
  h[0]+=c; h[4]+=c;
  /* lazy: propagate the fold carries (only in limbs 0,4) into 1,5; limbs stay
     < 2^57, a valid input for the next multiply. */
  c0=h[0]>>56; h[0]&=M56; h[1]+=c0;
  c4=h[4]>>56; h[4]&=M56; h[5]+=c4;
}
static void mul4(u128 o[7],const u64 a[4],const u64 b[4]){
  int i,j; for(i=0;i<7;i++) o[i]=0;
  for(i=0;i<4;i++) for(j=0;j<4;j++) o[i+j]+=(u128)a[i]*b[j];
}
/* One-level Karatsuba over the limb-aligned 4+4 split: 48 muls vs 64. */
static void fmul(u64 *h,const u64 *f,const u64 *g){
  u128 P00[7],P11[7],Ps[7],acc[15]; u64 s0[4],s1[4]; int k;
  mul4(P00,f,g); mul4(P11,f+4,g+4);
  for(k=0;k<4;k++){ s0[k]=f[k]+f[k+4]; s1[k]=g[k]+g[k+4]; }
  mul4(Ps,s0,s1);
  for(k=0;k<15;k++) acc[k]=0;
  for(k=0;k<7;k++){ acc[k]+=P00[k]+P11[k]; acc[k+4]+=(Ps[k]-P00[k]-P11[k])+P11[k]; }
  for(k=14;k>=8;k--){ acc[k-8]+=acc[k]; acc[k-4]+=acc[k]; }
  fe_carry_fold(h,acc);
}
static void fsqr(u64 *h,const u64 *f){
  u128 acc[15]; int i,j; for(i=0;i<15;i++) acc[i]=0;
  for(i=0;i<8;i++){ acc[2*i]+=(u128)f[i]*f[i]; for(j=i+1;j<8;j++) acc[i+j]+=(u128)(2*(u128)f[i]*f[j]); }
  for(i=14;i>=8;i--){ acc[i-8]+=acc[i]; acc[i-4]+=acc[i]; }
  fe_carry_fold(h,acc);
}
static void fe_canon(u64 *h){
  u128 acc[8]; int i; u64 t[8],bb; for(i=0;i<8;i++) acc[i]=h[i]; fe_carry_fold(h,acc);
  bb=0; for(i=0;i<8;i++){ u128 d=(u128)h[i]-P448[i]-bb; t[i]=(u64)d&M56; bb=(u64)((d>>64)&1); }
  if(!bb) for(i=0;i<8;i++) h[i]=t[i];
}
static void to_mont(u64 *r,const u64 *a){ fe_copy(r,a); }
static int fbn_cmp(const u64 *a,const u64 *b){ int i; for(i=7;i>=0;i--){ if(a[i]<b[i])return -1; if(a[i]>b[i])return 1; } return 0; }
static int fis_zero(const u64 *a){ u64 t[8]; int i; u64 x=0; fe_copy(t,a); fe_canon(t); for(i=0;i<8;i++) x|=t[i]; return x==0; }
static int fe_eq(const u64 *a,const u64 *b){ u64 x[8],y[8]; fe_copy(x,a); fe_copy(y,b); fe_canon(x); fe_canon(y); return fbn_cmp(x,y)==0; }
static void pow2k(u64 *o,const u64 *in,int k){ u64 t[NL]; int i; fe_copy(t,in); for(i=0;i<k;i++) fsqr(t,t); fe_copy(o,t); }
/* a^(p-2) via an addition chain (~454 sq + 13 mul vs bit-by-bit's 448 sq + 224
   mul). p-2 = 1 + 2^2*(2^222-1) + 2^225*(2^223-1). */
static void finv(u64 *r,const u64 *a){
  u64 t1[NL],t2[NL],t3[NL],t6[NL],t12[NL],t24[NL],t30[NL],t48[NL],t96[NL],t192[NL],t222[NL],t223[NL],tmp[NL];
  fe_copy(t1,a);
  pow2k(tmp,t1,1);  fmul(t2,tmp,t1);
  pow2k(tmp,t2,1);  fmul(t3,tmp,t1);
  pow2k(tmp,t3,3);  fmul(t6,tmp,t3);
  pow2k(tmp,t6,6);  fmul(t12,tmp,t6);
  pow2k(tmp,t12,12);fmul(t24,tmp,t12);
  pow2k(tmp,t24,6); fmul(t30,tmp,t6);
  pow2k(tmp,t24,24);fmul(t48,tmp,t24);
  pow2k(tmp,t48,48);fmul(t96,tmp,t48);
  pow2k(tmp,t96,96);fmul(t192,tmp,t96);
  pow2k(tmp,t192,30);fmul(t222,tmp,t30);
  pow2k(tmp,t222,1);fmul(t223,tmp,t1);
  pow2k(tmp,t222,2);fmul(r,tmp,t1);
  pow2k(tmp,t223,225);fmul(r,r,tmp);
}
/* sqrt via a^((p+1)/4); (p+1)/4 = 2^222*(2^224-1) = pow2k(a^(2^224-1), 222). */
static void fsqrt(u64 *r,const u64 *a){
  u64 t1[NL],t2[NL],t3[NL],t6[NL],t12[NL],t24[NL],t30[NL],t48[NL],t96[NL],t192[NL],t222[NL],t224[NL],tmp[NL];
  fe_copy(t1,a);
  pow2k(tmp,t1,1);  fmul(t2,tmp,t1);
  pow2k(tmp,t2,1);  fmul(t3,tmp,t1);
  pow2k(tmp,t3,3);  fmul(t6,tmp,t3);
  pow2k(tmp,t6,6);  fmul(t12,tmp,t6);
  pow2k(tmp,t12,12);fmul(t24,tmp,t12);
  pow2k(tmp,t24,6); fmul(t30,tmp,t6);
  pow2k(tmp,t24,24);fmul(t48,tmp,t24);
  pow2k(tmp,t48,48);fmul(t96,tmp,t48);
  pow2k(tmp,t96,96);fmul(t192,tmp,t96);
  pow2k(tmp,t192,30);fmul(t222,tmp,t30);
  pow2k(tmp,t222,2);fmul(t224,tmp,t2);
  pow2k(r,t224,222);
}
static void le56_to_limbs(u64 *a,const unsigned char *s){ int i,j; for(i=0;i<8;i++){ u64 v=0; for(j=0;j<7;j++) v|=(u64)s[7*i+j]<<(8*j); a[i]=v; } }
static void be56_to_limbs(u64 *a,const unsigned char *s){ unsigned char le[56]; int i; for(i=0;i<56;i++) le[i]=s[55-i]; le56_to_limbs(a,le); }
static void limbs_to_le56(unsigned char *s,const u64 *a){ u64 h[8]; int i,j; fe_copy(h,a); fe_canon(h); for(i=0;i<8;i++) for(j=0;j<7;j++) s[7*i+j]=(unsigned char)(h[i]>>(8*j)); }

/* ---- SHAKE256 ---- */
static void shake256(unsigned char *out,size_t outlen,const unsigned char *in,size_t inlen){
  rktcrypto_keccak_ctx_t c; rktcrypto_keccak_core_init(&c,136,0x1f);
  rktcrypto_keccak_core_update(&c,in,(intptr_t)inlen); rktcrypto_keccak_core_final(&c,out,(intptr_t)outlen);
}
/* dom4(0,"") = "SigEd448" || 0x00 || 0x00 */
static const unsigned char DOM4[10]={'S','i','g','E','d','4','4','8',0x00,0x00};

/* ---- extended point (X:Y:Z:T), a=1 Edwards ---- */
typedef struct { u64 X[NL],Y[NL],Z[NL],T[NL]; } ept;

static void pt_identity(ept *P){ int i; u64 one[NL]={1,0,0,0,0,0,0},zero[NL]={0,0,0,0,0,0,0};
  to_mont(P->X,zero); to_mont(P->Y,one); to_mont(P->Z,one); to_mont(P->T,zero); (void)i; }

/* add-2008-hwcd for a=1: H = B - A */
static void pt_add(ept *R,const ept *P,const ept *Q){
  u64 A[NL],B[NL],C[NL],D[NL],E[NL],F[NL],G[NL],H[NL],t0[NL],t1[NL];
  fmul(A,P->X,Q->X); fmul(B,P->Y,Q->Y);
  fmul(C,P->T,g_dmont); fmul(C,C,Q->T); fmul(D,P->Z,Q->Z);
  fadd(t0,P->X,P->Y); fadd(t1,Q->X,Q->Y); fmul(E,t0,t1); fsub(E,E,A); fsub(E,E,B);
  fsub(F,D,C); fadd(G,D,C); fsub(H,B,A);
  fmul(R->X,E,F); fmul(R->Y,G,H); fmul(R->T,E,H); fmul(R->Z,F,G);
}
/* dbl-2008-hwcd for a=1: 4 squarings + 3 muls (cheaper than the 9-mul add) */
static void pt_dbl(ept *R,const ept *P){
  u64 A[NL],B[NL],C[NL],E[NL],F[NL],G[NL],H[NL],t[NL];
  fsqr(A,P->X); fsqr(B,P->Y); fsqr(C,P->Z); fadd(C,C,C);
  fadd(t,P->X,P->Y); fsqr(E,t); fsub(E,E,A); fsub(E,E,B);   /* E = (X+Y)^2 - A - B */
  fadd(G,A,B);                                              /* G = A + B (a=1: D=A) */
  fsub(F,G,C); fsub(H,A,B);
  fmul(R->X,E,F); fmul(R->Y,G,H); fmul(R->T,E,H); fmul(R->Z,F,G);
}
/* Variable-base k*P via a width-4 window (verify only; k is public -> direct
   table index). The complete a=1 addition needs no special cases. */
/* Doubling that skips the extended T output (a multiply): valid when the next
   op is another doubling, which reads only X,Y,Z. */
static void pt_dbl_noT(ept *R,const ept *P){
  u64 A[NL],B[NL],C[NL],E[NL],F[NL],G[NL],H[NL],t[NL];
  fsqr(A,P->X); fsqr(B,P->Y); fsqr(C,P->Z); fadd(C,C,C);
  fadd(t,P->X,P->Y); fsqr(E,t); fsub(E,E,A); fsub(E,E,B);
  fadd(G,A,B); fsub(F,G,C); fsub(H,A,B);
  fmul(R->X,E,F); fmul(R->Y,G,H); fmul(R->Z,F,G);
}
static void pt_neg(ept *R,const ept *P){ u64 z[NL]={0,0,0,0,0,0,0,0};
  fsub(R->X,z,P->X); fe_copy(R->Y,P->Y); fe_copy(R->Z,P->Z); fsub(R->T,z,P->T); }
/* Variable-base k*P via width-5 wNAF (verify only; k public -> variable time ok).
   ~448 doublings (unavoidable) but only ~75 adds + 8-entry odd-multiple table,
   vs a fixed width-4 window's ~114 window-adds + 15-entry table. */
static void pt_scalarmul_win(ept *R,const unsigned char *k_be,int kbytes,const ept *P){
  ept odd[8],dP,acc; signed char wnaf[456]; unsigned char k[64]; int i,wlen=0,nz;
  /* k as little-endian bytes */
  for(i=0;i<kbytes;i++) k[i]=k_be[kbytes-1-i];
  for(i=kbytes;i<64;i++) k[i]=0;
  /* width-5 wNAF digits (LSB first): each nonzero is odd, |d| < 16 */
  for(;;){ nz=0; for(i=0;i<64;i++) if(k[i]){nz=1;break;} if(!nz) break;
    if(k[0]&1){ int d=k[0]&31; if(d>=16) d-=32; wnaf[wlen++]=(signed char)d;
      if(d>0){ int b=d,j=0; while(b){ int v=k[j]-(b&0xff); k[j]=(unsigned char)v; b=(b>>8)+(v<0?1:0); j++; } }
      else   { int b=-d,j=0; while(b){ int v=k[j]+(b&0xff); k[j]=(unsigned char)v; b=(b>>8)+(v>>8); j++; } }
    } else wnaf[wlen++]=0;
    for(i=0;i<63;i++) k[i]=(unsigned char)((k[i]>>1)|(k[i+1]<<7)); k[63]>>=1;   /* k >>= 1 */
  }
  /* odd[j] = (2j+1)*P : P,3P,5P,...,15P */
  odd[0]=*P; pt_dbl(&dP,P);
  for(i=1;i<8;i++) pt_add(&odd[i],&odd[i-1],&dP);
  pt_identity(&acc);
  for(i=wlen-1;i>=0;i--){
    if(wnaf[i]){ pt_dbl(&acc,&acc);
      if(wnaf[i]>0) pt_add(&acc,&acc,&odd[(wnaf[i]-1)>>1]);
      else { ept ng; pt_neg(&ng,&odd[(-wnaf[i]-1)>>1]); pt_add(&acc,&acc,&ng); }
    } else if(i==0) pt_dbl(&acc,&acc);   /* last op must leave a valid T for the caller */
    else pt_dbl_noT(&acc,&acc);
  }
  *R=acc;
}



/* Fixed-base comb for s*B with zero online doublings: ed448_comb[w][d] =
   d*16^w*B, precomputed once. r*B becomes 114 constant-time table-adds (was
   ~456 doublings + adds). Same scheme as the P-256/384/521 and Ed25519 combs.
   The edwards448 addition law is complete, so no exceptional cases. */
#define ED448_NWIN 114
/* cached affine point (X, Y, d*X*Y) for the mixed-add comb; a=1 madd is 8 muls
   (vs the unified add's 10) and its cmov scan touches 3 field elements not 4. */
typedef struct { u64 x[NL],y[NL],dt[NL]; } cached;
static void pt_madd(ept *r,const ept *p,const cached *q){
  u64 A[NL],B[NL],C[NL],E[NL],F[NL],G[NL],H[NL],t0[NL],t1[NL];
  fmul(A,p->X,q->x); fmul(B,p->Y,q->y); fmul(C,p->T,q->dt);
  fadd(t0,p->X,p->Y); fadd(t1,q->x,q->y); fmul(E,t0,t1); fsub(E,E,A); fsub(E,E,B);
  fsub(F,p->Z,C); fadd(G,p->Z,C); fsub(H,B,A);          /* Z2=1 so D=Z1 */
  fmul(r->X,E,F); fmul(r->Y,G,H); fmul(r->T,E,H); fmul(r->Z,F,G);
}
static void cached_cmov(cached *r,const cached *a,u64 b){ u64 m=0-b; int i;
  for(i=0;i<NL;i++){ r->x[i]^=m&(r->x[i]^a->x[i]); r->y[i]^=m&(r->y[i]^a->y[i]); r->dt[i]^=m&(r->dt[i]^a->dt[i]); } }
static cached ed448_comb[ED448_NWIN][16];
static int ed448_comb_inited=0;
static void ed448_comb_init(void){
  ept base,tmp[16]; u64 gx[NL],gy[NL],one[NL]={1,0,0,0,0,0,0};
  u64 prefix[16][NL],inv[NL],zi[NL],x[NL],y[NL]; int w,d;
  if(ed448_comb_inited) return;
  be56_to_limbs(gx,GX_BE); be56_to_limbs(gy,GY_BE);
  fe_copy(base.X,gx); fe_copy(base.Y,gy); fe_copy(base.Z,one); fmul(base.T,base.X,base.Y);
  for(w=0;w<ED448_NWIN;w++){
    pt_identity(&tmp[0]); tmp[1]=base;
    for(d=2;d<16;d++) pt_add(&tmp[d],&tmp[d-1],&base);
    fe_copy(prefix[0],tmp[0].Z);                         /* batch-normalize to affine */
    for(d=1;d<16;d++) fmul(prefix[d],prefix[d-1],tmp[d].Z);
    finv(inv,prefix[15]);
    for(d=15;d>=0;d--){
      if(d>0){ fmul(zi,inv,prefix[d-1]); fmul(inv,inv,tmp[d].Z); } else fe_copy(zi,inv);
      fmul(x,tmp[d].X,zi); fmul(y,tmp[d].Y,zi);
      fe_copy(ed448_comb[w][d].x,x); fe_copy(ed448_comb[w][d].y,y);
      fmul(ed448_comb[w][d].dt,x,y); fmul(ed448_comb[w][d].dt,ed448_comb[w][d].dt,g_dmont);
    }
    if(w+1<ED448_NWIN){ for(d=0;d<4;d++) pt_dbl(&base,&base); }
  }
  ed448_comb_inited=1;
}
/* r*B from a big-endian scalar (kbytes bytes); constant-time cmov table scan. */
static void pt_scalarmul_base(ept *R,const unsigned char *k_be,int kbytes){
  int w,d,nw=kbytes*2; cached sel; ept acc; pt_identity(&acc);
  ed448_comb_init();
  for(w=0;w<nw && w<ED448_NWIN;w++){
    int nib=(k_be[kbytes-1-(w>>1)]>>((w&1)*4))&0xF;
    sel=ed448_comb[w][0];
    for(d=1;d<16;d++) cached_cmov(&sel,&ed448_comb[w][d],(u64)(d==nib));
    pt_madd(&acc,&acc,&sel);
  }
  *R=acc;
}

/* encode point to 57 bytes: y little-endian (56) + sign(x) in bit 7 of byte 56. */
static void pt_encode(unsigned char out[57],const ept *P){
  u64 zi[NL],x[NL],y[NL],xc[NL];
  finv(zi,P->Z); fmul(x,P->X,zi); fmul(y,P->Y,zi);
  limbs_to_le56(out,y);                                    /* canonical y */
  fe_copy(xc,x); fe_canon(xc); out[56]=(unsigned char)((xc[0]&1)<<7);
}
/* encode two points with a single inversion (Montgomery's trick): inv = 1/(ZA*ZR). */
static void pt_encode2(unsigned char oA[57],unsigned char oR[57],const ept *A,const ept *R){
  u64 prod[NL],inv[NL],zi[NL],x[NL],y[NL],xc[NL];
  fmul(prod,A->Z,R->Z); finv(inv,prod);
  fmul(zi,inv,R->Z);   /* 1/ZA */
  fmul(x,A->X,zi); fmul(y,A->Y,zi); limbs_to_le56(oA,y); fe_copy(xc,x); fe_canon(xc); oA[56]=(unsigned char)((xc[0]&1)<<7);
  fmul(zi,inv,A->Z);   /* 1/ZR */
  fmul(x,R->X,zi); fmul(y,R->Y,zi); limbs_to_le56(oR,y); fe_copy(xc,x); fe_canon(xc); oR[56]=(unsigned char)((xc[0]&1)<<7);
}
/* decode 57-byte encoding to a point; returns 1 on success. */
static int pt_decode(ept *P,const unsigned char in[57]){
  u64 y[NL],y2[NL],num[NL],den[NL],x[NL],x2[NL],dinv[NL],u[NL],om[NL],one[NL]={1,0,0,0,0,0,0};
  int sign=in[56]>>7, j;
  unsigned char yb[56]; memcpy(yb,in,56);
  { u64 yl[NL]; le56_to_limbs(yl,yb); if(fbn_cmp(yl,P448)>=0) return 0; to_mont(y,yl); }
  to_mont(om,one);
  fsqr(y2,y);
  fsub(num,y2,om);                        /* num = y^2 - 1 */
  fmul(den,g_dmont,y2); fsub(den,den,om); /* den = d*y^2 - 1 */
  finv(dinv,den); fmul(u,num,dinv);       /* u = num/den */
  fsqrt(x,u);                             /* x = sqrt(u) via addition chain */
  fsqr(x2,x);
  if(!fe_eq(x2,u)) return 0;              /* not a square -> invalid */
  { u64 xc[NL]; fe_copy(xc,x); fe_canon(xc); if((int)(xc[0]&1)!=sign){ u64 z[NL]={0,0,0,0,0,0,0,0}; fsub(x,z,x); } }
  if(fis_zero(x) && sign) return 0;
  for(j=0;j<NL;j++){ P->X[j]=x[j]; P->Y[j]=y[j]; P->Z[j]=om[j]; }
  fmul(P->T,x,y);
  return 1;
}

/* ---- scalar mod L via the in-tree bignum (big-endian) ---- */
static void sc_reduce_le(unsigned char out57[57],const unsigned char *in_le,int inlen){
  unsigned char be[114]; BN a,L,r; int i;
  for(i=0;i<inlen;i++) be[i]=in_le[inlen-1-i];      /* reverse to big-endian */
  bn_from_be(&a,be,inlen);
  bn_from_be(&L,L_BE,56);
  bn_mod(&r,&a,&L);
  { unsigned char rb[57]; bn_to_be(rb,57,&r); for(i=0;i<57;i++) out57[i]=rb[57-1-i]; }  /* little-endian */
}
/* out = (a + b*c) mod L, all little-endian 57-byte (a,b,c < L). */
static void sc_muladd_le(unsigned char out57[57],const unsigned char *a_le,const unsigned char *b_le,const unsigned char *c_le){
  unsigned char abe[57],bbe[57],cbe[57]; BN A,B,C,L,prod,sum,r; int i;
  for(i=0;i<57;i++){ abe[i]=a_le[56-i]; bbe[i]=b_le[56-i]; cbe[i]=c_le[56-i]; }
  bn_from_be(&A,abe,57); bn_from_be(&B,bbe,57); bn_from_be(&C,cbe,57); bn_from_be(&L,L_BE,56);
  bn_mul(&prod,&B,&C); bn_add(&sum,&prod,&A); bn_mod(&r,&sum,&L);
  { unsigned char rb[57]; bn_to_be(rb,57,&r); for(i=0;i<57;i++) out57[i]=rb[56-i]; }
}

static void ed448_init(void){
  u64 z[NL],dd[NL]; int i;
  if(inited) return;
  for(i=0;i<8;i++){ z[i]=0; dd[i]=0; } dd[0]=39081;
  fsub(g_dmont,z,dd); fe_canon(g_dmont);   /* d = -39081 mod p */
  inited=1;
}

/* ---- public API ---- */
static void ed448_genA(unsigned char A[57],const unsigned char *sk){
  unsigned char h[114]; ept G,R; u64 gx[NL],gy[NL];
  shake256(h,114,sk,57);
  h[0]&=0xfc; h[55]|=0x80; h[56]=0;   /* clamp; low 448 bits = secret scalar s (little-endian) */
  be56_to_limbs(gx,GX_BE); be56_to_limbs(gy,GY_BE);
  to_mont(G.X,gx); to_mont(G.Y,gy); { u64 one[NL]={1,0,0,0,0,0,0}; to_mont(G.Z,one); } fmul(G.T,G.X,G.Y);
  { unsigned char sbe[57]; int i; for(i=0;i<57;i++) sbe[i]=h[56-i]; pt_scalarmul_base(&R,sbe,57); }
  pt_encode(A,&R);
}

int rktcrypto_ed448_pubkey(unsigned char *pk,const unsigned char *sk){
  ed448_init(); ed448_genA(pk,sk); return 1;
}
int rktcrypto_ed448_sign(unsigned char *sig,const unsigned char *msg,intptr_t mlen,const unsigned char *sk,const unsigned char *pk){
  unsigned char h[114],A[57],rbuf[114],r57[57],R[57],kbuf[114],k57[57],S57[57],sbe[57]; ept Rp; int i;
  ed448_init();
  shake256(h,114,sk,57); h[0]&=0xfc; h[55]|=0x80; h[56]=0;
  /* r = SHAKE256(dom4 || prefix || M) mod L ; prefix = h[57..113] */
  { rktcrypto_keccak_ctx_t c; rktcrypto_keccak_core_init(&c,136,0x1f);
    rktcrypto_keccak_core_update(&c,DOM4,10); rktcrypto_keccak_core_update(&c,h+57,57);
    rktcrypto_keccak_core_update(&c,msg,mlen); rktcrypto_keccak_core_final(&c,rbuf,114); }
  sc_reduce_le(r57,rbuf,114);
  for(i=0;i<57;i++) sbe[i]=r57[56-i]; pt_scalarmul_base(&Rp,sbe,57);
  /* The public key A is needed only (as bytes) for the k-hash. When the caller
     supplies it (the standard key model -- OpenSSL/NaCl store A with the key),
     use it directly and skip re-deriving A = s*G, halving the base-mult work.
     pk == NULL falls back to deriving A (seed-only callers). */
  if(pk){ memcpy(A,pk,57); pt_encode(R,&Rp); }
  else { ept Ap; for(i=0;i<57;i++) sbe[i]=h[56-i]; pt_scalarmul_base(&Ap,sbe,57);
         pt_encode2(A,R,&Ap,&Rp); }                          /* one inversion for both */
  /* k = SHAKE256(dom4 || R || A || M) mod L */
  { rktcrypto_keccak_ctx_t c; rktcrypto_keccak_core_init(&c,136,0x1f);
    rktcrypto_keccak_core_update(&c,DOM4,10); rktcrypto_keccak_core_update(&c,R,57);
    rktcrypto_keccak_core_update(&c,A,57); rktcrypto_keccak_core_update(&c,msg,mlen);
    rktcrypto_keccak_core_final(&c,kbuf,114); }
  sc_reduce_le(k57,kbuf,114);
  /* S = (r + k*s) mod L ; s = low 57 bytes of h (little-endian, already clamped) */
  { unsigned char s57[57]; memcpy(s57,h,57); sc_muladd_le(S57,r57,k57,s57); }
  memcpy(sig,R,57); memcpy(sig+57,S57,57);
  return 1;
}
int rktcrypto_ed448_verify(const unsigned char *sig,const unsigned char *msg,intptr_t mlen,const unsigned char *pk){
  unsigned char kbuf[114],k57[57],sbe[57],kbe[57]; ept G,A,SB,kA,rhs; u64 gx[NL],gy[NL]; int i;
  const unsigned char *R=sig,*S=sig+57;
  ed448_init();
  { BN Sn,L; unsigned char Sbe[57]; for(i=0;i<57;i++) Sbe[i]=S[56-i]; bn_from_be(&Sn,Sbe,57); bn_from_be(&L,L_BE,56); if(bn_cmp(&Sn,&L)>=0) return 0; }
  if(!pt_decode(&A,pk)) return 0;
  be56_to_limbs(gx,GX_BE); be56_to_limbs(gy,GY_BE);
  to_mont(G.X,gx); to_mont(G.Y,gy); { u64 one[NL]={1,0,0,0,0,0,0}; to_mont(G.Z,one); } fmul(G.T,G.X,G.Y);
  { rktcrypto_keccak_ctx_t c; rktcrypto_keccak_core_init(&c,136,0x1f);
    rktcrypto_keccak_core_update(&c,DOM4,10); rktcrypto_keccak_core_update(&c,R,57);
    rktcrypto_keccak_core_update(&c,pk,57); rktcrypto_keccak_core_update(&c,msg,mlen);
    rktcrypto_keccak_core_final(&c,kbuf,114); }
  sc_reduce_le(k57,kbuf,114);
  for(i=0;i<57;i++) sbe[i]=S[56-i]; pt_scalarmul_base(&SB,sbe,57);        /* S*B */
  for(i=0;i<57;i++) kbe[i]=k57[56-i]; pt_scalarmul_win(&kA,kbe,57,&A);  /* k*A */
  /* Verify S*B - k*A == R by encoding the LHS and comparing to the R bytes.
     This avoids decoding R (a field sqrt) and encoding a second point (a field
     inverse) vs comparing two re-encoded points. -P = (-X : Y : Z : -T). */
  { u64 z[NL]={0,0,0,0,0,0,0,0}; fsub(kA.X,z,kA.X); fsub(kA.T,z,kA.T); }  /* -k*A */
  pt_add(&rhs,&SB,&kA);                                                  /* S*B - k*A */
  { unsigned char e[57]; pt_encode(e,&rhs); return memcmp(e,R,57)==0; }
}
