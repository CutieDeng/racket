/* Generic NIST prime-curve engine for P-384 (secp384r1) and P-521
   (secp521r1): variable-width Montgomery field/scalar arithmetic plus the
   Renes-Costello-Batina complete addition formulas for a = -3 (no
   exceptional cases, so the scalar ladder is uniform), ECDH and
   ECDSA. P-256 keeps its dedicated hardware path; these two reuse a
   portable engine. From scratch, no external code. */

#include "rktcrypto.h"
#include <string.h>
#include <stdint.h>

typedef uint64_t u64;
typedef unsigned __int128 u128;
#define MAXL 9

typedef struct {
  int nl, nbytes, pbits, nbits;
  int hash_alg;               /* digest for ECDSA (SHA-384 / SHA-512) */
  int fast;                   /* 521 or 384 = special-prime reduction; 0 = Montgomery */
  u64 p[MAXL], n[MAXL], b[MAXL], gx[MAXL], gy[MAXL];
  u64 rr_p[MAXL], rr_n[MAXL], amont[MAXL], b3mont[MAXL], n0_p, n0_n;
} curve;

/* ---- generic fixed-MAXL bignum (only low nl limbs are significant) ---- */
static void bn_zero(u64 *a){ int i; for(i=0;i<MAXL;i++) a[i]=0; }
static void bn_cpy(u64 *r,const u64 *a){ int i; for(i=0;i<MAXL;i++) r[i]=a[i]; }
static int bn_cmp(const u64 *a,const u64 *b,int nl){ int i; for(i=nl-1;i>=0;i--){ if(a[i]<b[i])return -1; if(a[i]>b[i])return 1; } return 0; }
static int bn_iszero(const u64 *a,int nl){ int i; u64 x=0; for(i=0;i<nl;i++) x|=a[i]; return x==0; }
static u64 bn_add(u64 *r,const u64 *a,const u64 *b,int nl){ int i; u64 c=0; for(i=0;i<nl;i++){ u128 s=(u128)a[i]+b[i]+c; r[i]=(u64)s; c=(u64)(s>>64); } return c; }
static u64 bn_sub(u64 *r,const u64 *a,const u64 *b,int nl){ int i; u64 br=0; for(i=0;i<nl;i++){ u128 d=(u128)a[i]-b[i]-br; r[i]=(u64)d; br=(u64)((d>>64)&1); } return br; }

static void bytes_to_limbs(u64 *a,const unsigned char *s,int nbytes,int nl){
  int i; bn_zero(a);
  for(i=0;i<nbytes;i++){ int bit=(nbytes-1-i)*8; a[bit/64]|=(u64)s[i]<<(bit%64); }
  (void)nl;
}
static void limbs_to_bytes(unsigned char *s,const u64 *a,int nbytes){
  int i; for(i=0;i<nbytes;i++){ int bit=(nbytes-1-i)*8; s[i]=(unsigned char)(a[bit/64]>>(bit%64)); }
}

/* Montgomery CIOS multiply: r = a*b*R^-1 mod m, R = 2^(64*nl). */
static void montmul(u64 *r,const u64 *a,const u64 *b,const u64 *m,u64 n0,int nl){
  u64 t[MAXL+2]; int i,j; for(i=0;i<nl+2;i++) t[i]=0;
  for(i=0;i<nl;i++){
    u64 c=0; u128 p;
    for(j=0;j<nl;j++){ p=(u128)a[j]*b[i]+t[j]+c; t[j]=(u64)p; c=(u64)(p>>64); }
    { u128 s=(u128)t[nl]+c; t[nl]=(u64)s; t[nl+1]=(u64)(s>>64); }
    { u64 mm=(u64)((u128)t[0]*n0); u64 cc=0;
      p=(u128)mm*m[0]+t[0]; cc=(u64)(p>>64);
      for(j=1;j<nl;j++){ p=(u128)mm*m[j]+t[j]+cc; t[j-1]=(u64)p; cc=(u64)(p>>64); }
      { u128 s=(u128)t[nl]+cc; t[nl-1]=(u64)s; t[nl]=t[nl+1]+(u64)(s>>64); }
    }
  }
  { u64 tmp[MAXL]; u64 borrow; int k;
    borrow=0; for(k=0;k<nl;k++){ u128 d=(u128)t[k]-m[k]-borrow; tmp[k]=(u64)d; borrow=(u64)((d>>64)&1); }
    borrow = (t[nl]!=0) ? 0 : borrow;   /* if high limb set, definitely >= m */
    if(borrow==0){ for(k=0;k<nl;k++) r[k]=tmp[k]; } else { for(k=0;k<nl;k++) r[k]=t[k]; }
    for(k=nl;k<MAXL;k++) r[k]=0;
  }
}
static u64 mont_n0(u64 m0){ u64 x=1; int i; for(i=0;i<6;i++) x*=2-m0*x; return (u64)(0-x); }
static void compute_rr(u64 *rr,const u64 *m,int nl){
  u64 t[MAXL]; int i; bn_zero(t); t[0]=1;   /* t = 1; double 2*nl*64 times mod m */
  for(i=0;i<2*64*nl;i++){ u64 c=bn_add(t,t,t,nl); if(c || bn_cmp(t,m,nl)>=0) bn_sub(t,t,m,nl); }
  bn_cpy(rr,t);
}
static void to_mont(u64 *r,const u64 *a,const u64 *m,const u64 *rr,u64 n0,int nl){ montmul(r,a,rr,m,n0,nl); }
static void from_mont(u64 *r,const u64 *a,const u64 *m,u64 n0,int nl){ u64 one[MAXL]; bn_zero(one); one[0]=1; montmul(r,a,one,m,n0,nl); }

/* Schoolbook wide multiply: prod[0..2nl-1] = a*b (nl limbs each). */
static void mul_wide(u64 *prod,const u64 *a,const u64 *b,int nl){
  int i,j; for(i=0;i<2*nl;i++) prod[i]=0;
  for(i=0;i<nl;i++){ u64 c=0; for(j=0;j<nl;j++){ u128 p=(u128)a[i]*b[j]+prod[i+j]+c; prod[i+j]=(u64)p; c=(u64)(p>>64); } prod[i+nl]=c; }
}
/* P-521 reduction mod 2^521-1 (Mersenne). prod has 18 significant limbs.
   prod = A*2^521 + B, and 2^521 == 1, so result = A + B (mod p). */
static const u64 P521_PL[9]={~0ULL,~0ULL,~0ULL,~0ULL,~0ULL,~0ULL,~0ULL,~0ULL,0x1ffULL};
static void reduce_p521(u64 *r,const u64 *prod){
  u64 t[9],hi[9],extra,cc; int i;
  for(i=0;i<8;i++) t[i]=prod[i];
  t[8]=prod[8]&0x1ffULL;                        /* B = low 521 bits */
  for(i=0;i<9;i++){                             /* A = prod >> 521 (=>> (512+9)) */
    u64 lo=prod[8+i]>>9;
    u64 up=(9+i<18)?(prod[9+i]<<55):0ULL;
    hi[i]=lo|up;
  }
  { u64 c=bn_add(t,t,hi,9);                      /* t = A + B (< 2^522) */
    extra=(t[8]>>9)|(c<<55); t[8]&=0x1ffULL; }   /* fold bits >= 521 back (2^521==1) */
  { u128 s=(u128)t[0]+extra; t[0]=(u64)s; cc=(u64)(s>>64);
    for(i=1;i<9&&cc;i++){ u128 s2=(u128)t[i]+cc; t[i]=(u64)s2; cc=(u64)(s2>>64); } }
  if(bn_cmp(t,P521_PL,9)>=0) bn_sub(t,t,P521_PL,9);
  for(i=0;i<9;i++) r[i]=t[i];
}
/* P-384 reduction: p = 2^384 - c, c = 2^128 + 2^96 - 2^32 + 1. So a 768-bit
   product folds as lo + hi*c, iterated until hi vanishes, then subtract p. */
static const u64 P384_C[3]={0xffffffff00000001ULL,0x00000000ffffffffULL,1ULL};
static const u64 P384_PL[6]={0x00000000ffffffffULL,0xffffffff00000000ULL,0xfffffffffffffffeULL,~0ULL,~0ULL,~0ULL};
static void reduce_p384(u64 *r,const u64 *prod){
  u64 v[13]; int i,iter;
  for(i=0;i<12;i++) v[i]=prod[i]; v[12]=0;
  for(iter=0;iter<5;iter++){
    u64 hz=0; for(i=6;i<13;i++) hz|=v[i]; if(!hz) break;
    u64 H[13],hc[13];
    for(i=0;i<13;i++){ H[i]=(6+i<13)?v[6+i]:0; hc[i]=0; }
    for(i=0;i<7;i++){ u64 carry=0; int b,k;
      for(b=0;b<3;b++){ if(i+b<13){ u128 p=(u128)H[i]*P384_C[b]+hc[i+b]+carry; hc[i+b]=(u64)p; carry=(u64)(p>>64); } }
      k=i+3; while(carry&&k<13){ u128 p=(u128)hc[k]+carry; hc[k]=(u64)p; carry=(u64)(p>>64); k++; } }
    for(i=6;i<13;i++) v[i]=0;
    bn_add(v,v,hc,13);
  }
  for(i=0;i<6;i++){ if(bn_cmp(v,P384_PL,6)>=0) bn_sub(v,v,P384_PL,6); }
  for(i=0;i<6;i++) r[i]=v[i];
}
static void fp_reduce(u64 *r,const u64 *prod,const curve *cv){
  if(cv->fast==521) reduce_p521(r,prod);
  else reduce_p384(r,prod);
}

/* field ops mod p (Montgomery domain for mul; plain reps for add/sub) */
static void fp_add(u64 *r,const u64 *a,const u64 *b,const curve *cv){ u64 c=bn_add(r,a,b,cv->nl); if(c||bn_cmp(r,cv->p,cv->nl)>=0) bn_sub(r,r,cv->p,cv->nl); }
static void fp_sub(u64 *r,const u64 *a,const u64 *b,const curve *cv){ u64 br=bn_sub(r,a,b,cv->nl); if(br) bn_add(r,r,cv->p,cv->nl); }
static void fp_mul(u64 *r,const u64 *a,const u64 *b,const curve *cv){
  if(cv->fast){ u64 prod[2*MAXL]; mul_wide(prod,a,b,cv->nl); fp_reduce(r,prod,cv); }
  else montmul(r,a,b,cv->p,cv->n0_p,cv->nl);
}
/* p-domain conversions: identity for fast (plain) curves, Montgomery otherwise. */
static void fp_to_mont(u64 *r,const u64 *a,const curve *cv){
  if(cv->fast) bn_cpy(r,a); else to_mont(r,a,cv->p,cv->rr_p,cv->n0_p,cv->nl);
}
static void fp_from_mont(u64 *r,const u64 *a,const curve *cv){
  if(cv->fast) bn_cpy(r,a); else from_mont(r,a,cv->p,cv->n0_p,cv->nl);
}
/* Fermat inverse in Montgomery domain: a^(p-2). */
static void fp_inv(u64 *r,const u64 *a,const curve *cv){
  u64 e[MAXL],acc[MAXL],base[MAXL],one[MAXL]; int i,bit; bn_zero(one); one[0]=1;
  { u64 two[MAXL]; bn_zero(two); two[0]=2; bn_sub(e,cv->p,two,cv->nl); }
  fp_to_mont(acc,one,cv); bn_cpy(base,a);
  for(i=0;i<cv->pbits;i++){
    bit=(int)((e[i/64]>>(i%64))&1);
    if(bit) fp_mul(acc,acc,base,cv);
    fp_mul(base,base,base,cv);
  }
  bn_cpy(r,acc);
}

/* ---- projective points (X:Y:Z), RCB complete formulas (a = -3) ---- */
typedef struct { u64 X[MAXL],Y[MAXL],Z[MAXL]; } jpt;
/* Renes-Costello-Batina 2016, Algorithm 1: complete addition for any short
   Weierstrass curve, using constants a and b3 = 3b. No exceptional cases. */
static void pt_add(jpt *R,const jpt *P,const jpt *Q,const curve *cv){
  u64 t0[MAXL],t1[MAXL],t2[MAXL],t3[MAXL],t4[MAXL],t5[MAXL],X3[MAXL],Y3[MAXL],Z3[MAXL];
  const u64 *a=cv->amont,*b3=cv->b3mont;
  fp_mul(t0,P->X,Q->X,cv); fp_mul(t1,P->Y,Q->Y,cv); fp_mul(t2,P->Z,Q->Z,cv);
  fp_add(t3,P->X,P->Y,cv); fp_add(t4,Q->X,Q->Y,cv); fp_mul(t3,t3,t4,cv);
  fp_add(t4,t0,t1,cv); fp_sub(t3,t3,t4,cv); fp_add(t4,P->X,P->Z,cv);
  fp_add(t5,Q->X,Q->Z,cv); fp_mul(t4,t4,t5,cv); fp_add(t5,t0,t2,cv);
  fp_sub(t4,t4,t5,cv); fp_add(t5,P->Y,P->Z,cv); fp_add(X3,Q->Y,Q->Z,cv);
  fp_mul(t5,t5,X3,cv); fp_add(X3,t1,t2,cv); fp_sub(t5,t5,X3,cv);
  fp_mul(Z3,a,t4,cv); fp_mul(X3,b3,t2,cv); fp_add(Z3,X3,Z3,cv);
  fp_sub(X3,t1,Z3,cv); fp_add(Z3,t1,Z3,cv); fp_mul(Y3,X3,Z3,cv);
  fp_add(t1,t0,t0,cv); fp_add(t1,t1,t0,cv); fp_mul(t2,a,t2,cv);
  fp_mul(t4,b3,t4,cv); fp_add(t1,t1,t2,cv); fp_sub(t2,t0,t2,cv);
  fp_mul(t2,a,t2,cv); fp_add(t4,t4,t2,cv); fp_mul(t0,t1,t4,cv);
  fp_add(Y3,Y3,t0,cv); fp_mul(t0,t5,t4,cv); fp_mul(X3,t3,X3,cv);
  fp_sub(X3,X3,t0,cv); fp_mul(t0,t3,t1,cv); fp_mul(Z3,t5,Z3,cv);
  fp_add(Z3,Z3,t0,cv);
  bn_cpy(R->X,X3); bn_cpy(R->Y,Y3); bn_cpy(R->Z,Z3);
}
static void pt_cmov(jpt *R,const jpt *A,u64 b,int nl){
  u64 mask=0-b; int i;
  for(i=0;i<nl;i++){ R->X[i]^=mask&(R->X[i]^A->X[i]); R->Y[i]^=mask&(R->Y[i]^A->Y[i]); R->Z[i]^=mask&(R->Z[i]^A->Z[i]); }
}
/* Constant-time width-4 fixed window. Precompute T[i] = i*P (i=0..15), then per
   4-bit window (MSB first): 4 complete doublings + one complete add of the
   window multiple, selected by scanning the whole table with cmov so the memory
   access pattern is independent of the (secret) scalar. Cuts the point-adds from
   ~2 per bit to ~1.25 per bit vs the bit-at-a-time ladder. */
static void pt_select(jpt *R,const jpt T[16],int idx,int nl){
  int i; *R=T[0];
  for(i=1;i<16;i++){ u64 m=(u64)((i^idx)==0); pt_cmov(R,&T[i],m,nl); }
}
static void scalar_mul(jpt *R,const u64 *k,const jpt *P,const curve *cv){
  jpt T[16],acc,sel; int i,j,nb=cv->nbits,top; u64 one[MAXL],zero[MAXL];
  bn_zero(one); one[0]=1; bn_zero(zero);
  fp_to_mont(T[0].X,zero,cv); fp_to_mont(T[0].Y,one,cv); bn_cpy(T[0].Z,T[0].X);  /* O */
  T[1]=*P;
  for(i=2;i<16;i++) pt_add(&T[i],&T[i-1],P,cv);
  acc=T[0];
  top=((nb+3)/4)*4;
  for(i=top-4;i>=0;i-=4){
    int nib=0;
    pt_add(&acc,&acc,&acc,cv); pt_add(&acc,&acc,&acc,cv);
    pt_add(&acc,&acc,&acc,cv); pt_add(&acc,&acc,&acc,cv);
    for(j=3;j>=0;j--){ int bit=(i+j<nb)?(int)((k[(i+j)/64]>>((i+j)%64))&1):0; nib=(nib<<1)|bit; }
    pt_select(&sel,T,nib,cv->nl);
    pt_add(&acc,&acc,&sel,cv);
  }
  *R=acc;
}
/* Fixed-base comb for k*G: COMB[i][d] = d * 2^(4i) * G, so k*G = sum over
   4-bit windows of COMB[i][nibble_i(k)] with ZERO online doublings. The table
   is precomputed once per curve at init. Used for the generator-based scalar
   mults (pubkey, sign, and verify's u1*G); variable-base stays on scalar_mul. */
static jpt COMB384[96][16], COMB521[131][16];
static void scalar_mul_base(jpt *R,const u64 *k,const curve *cv){
  jpt (*comb)[16]=(cv->fast==521)?COMB521:COMB384;
  int nwin=(cv->nbits+3)/4, i,j,d; jpt acc,sel; u64 one[MAXL],zero[MAXL];
  bn_zero(one); one[0]=1; bn_zero(zero);
  fp_to_mont(acc.X,zero,cv); fp_to_mont(acc.Y,one,cv); bn_cpy(acc.Z,acc.X);  /* O */
  for(i=0;i<nwin;i++){
    int nib=0;
    for(j=3;j>=0;j--){ int b=(4*i+j<cv->nbits)?(int)((k[(4*i+j)/64]>>((4*i+j)%64))&1):0; nib=(nib<<1)|b; }
    sel=comb[i][0];
    for(d=1;d<16;d++){ u64 m=(u64)((d^nib)==0); pt_cmov(&sel,&comb[i][d],m,cv->nl); }
    pt_add(&acc,&acc,&sel,cv);
  }
  *R=acc;
}
static void pt_to_affine(u64 *x,u64 *y,const jpt *P,const curve *cv){
  u64 zi[MAXL],xm[MAXL],ym[MAXL];
  fp_inv(zi,P->Z,cv);
  fp_mul(xm,P->X,zi,cv); fp_mul(ym,P->Y,zi,cv);
  fp_from_mont(x,xm,cv); fp_from_mont(y,ym,cv);
}
static void set_generator(jpt *G,const curve *cv){
  u64 one[MAXL]; bn_zero(one); one[0]=1;
  fp_to_mont(G->X,cv->gx,cv);
  fp_to_mont(G->Y,cv->gy,cv);
  fp_to_mont(G->Z,one,cv);
}
static void build_comb(const curve *cv){
  jpt (*comb)[16]=(cv->fast==521)?COMB521:COMB384;
  int nwin=(cv->nbits+3)/4, i,d; jpt base,O; u64 one[MAXL],zero[MAXL];
  bn_zero(one); one[0]=1; bn_zero(zero);
  fp_to_mont(O.X,zero,cv); fp_to_mont(O.Y,one,cv); bn_cpy(O.Z,O.X);
  set_generator(&base,cv);
  for(i=0;i<nwin;i++){
    comb[i][0]=O; comb[i][1]=base;
    for(d=2;d<16;d++) pt_add(&comb[i][d],&comb[i][d-1],&base,cv);
    if(i+1<nwin){ pt_add(&base,&base,&base,cv); pt_add(&base,&base,&base,cv);
                  pt_add(&base,&base,&base,cv); pt_add(&base,&base,&base,cv); }  /* base *= 2^4 */
  }
}

/* ---- scalar field mod n ---- */
static void fn_mul(u64 *r,const u64 *a,const u64 *b,const curve *cv){ montmul(r,a,b,cv->n,cv->n0_n,cv->nl); }
static void fn_add(u64 *r,const u64 *a,const u64 *b,const curve *cv){ u64 c=bn_add(r,a,b,cv->nl); if(c||bn_cmp(r,cv->n,cv->nl)>=0) bn_sub(r,r,cv->n,cv->nl); }
static void fn_inv(u64 *r,const u64 *a,const curve *cv){   /* a^(n-2) mod n, plain domain in/out */
  u64 e[MAXL],acc[MAXL],one[MAXL],am[MAXL]; int i;
  bn_zero(one); one[0]=1; { u64 two[MAXL]; bn_zero(two); two[0]=2; bn_sub(e,cv->n,two,cv->nl); }
  to_mont(am,a,cv->n,cv->rr_n,cv->n0_n,cv->nl);
  to_mont(acc,one,cv->n,cv->rr_n,cv->n0_n,cv->nl);
  for(i=0;i<cv->nbits;i++){ if((e[i/64]>>(i%64))&1) fn_mul(acc,acc,am,cv); fn_mul(am,am,am,cv); }
  from_mont(r,acc,cv->n,cv->n0_n,cv->nl);
}
/* z = leftmost nbits of hash, reduced mod n. */
static void hash_to_scalar(u64 *z,const unsigned char *h,int hlen,const curve *cv){
  u64 t[MAXL]; int hbits=hlen*8;
  bytes_to_limbs(t,h,hlen,cv->nl);
  if(hbits>cv->nbits){ int sh=hbits-cv->nbits,i; /* shift right by sh bits */
    for(i=0;i<cv->nl;i++){ int b=i*64+sh; u64 v=0; if(b/64<MAXL) v=t[b/64]>>(b%64); if((b%64)&&(b/64+1<MAXL)) v|=t[b/64+1]<<(64-(b%64)); z[i]=v; }
    for(i=cv->nl;i<MAXL;i++) z[i]=0;
  } else bn_cpy(z,t);
  if(bn_cmp(z,cv->n,cv->nl)>=0) bn_sub(z,z,cv->n,cv->nl);
}

/* ---- curve tables ---- */
static const unsigned char P384_P[48]={0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xfe,0xff,0xff,0xff,0xff,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xff,0xff,0xff,0xff};
static const unsigned char P384_N[48]={0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xc7,0x63,0x4d,0x81,0xf4,0x37,0x2d,0xdf,0x58,0x1a,0x0d,0xb2,0x48,0xb0,0xa7,0x7a,0xec,0xec,0x19,0x6a,0xcc,0xc5,0x29,0x73};
static const unsigned char P384_B[48]={0xb3,0x31,0x2f,0xa7,0xe2,0x3e,0xe7,0xe4,0x98,0x8e,0x05,0x6b,0xe3,0xf8,0x2d,0x19,0x18,0x1d,0x9c,0x6e,0xfe,0x81,0x41,0x12,0x03,0x14,0x08,0x8f,0x50,0x13,0x87,0x5a,0xc6,0x56,0x39,0x8d,0x8a,0x2e,0xd1,0x9d,0x2a,0x85,0xc8,0xed,0xd3,0xec,0x2a,0xef};
static const unsigned char P384_GX[48]={0xaa,0x87,0xca,0x22,0xbe,0x8b,0x05,0x37,0x8e,0xb1,0xc7,0x1e,0xf3,0x20,0xad,0x74,0x6e,0x1d,0x3b,0x62,0x8b,0xa7,0x9b,0x98,0x59,0xf7,0x41,0xe0,0x82,0x54,0x2a,0x38,0x55,0x02,0xf2,0x5d,0xbf,0x55,0x29,0x6c,0x3a,0x54,0x5e,0x38,0x72,0x76,0x0a,0xb7};
static const unsigned char P384_GY[48]={0x36,0x17,0xde,0x4a,0x96,0x26,0x2c,0x6f,0x5d,0x9e,0x98,0xbf,0x92,0x92,0xdc,0x29,0xf8,0xf4,0x1d,0xbd,0x28,0x9a,0x14,0x7c,0xe9,0xda,0x31,0x13,0xb5,0xf0,0xb8,0xc0,0x0a,0x60,0xb1,0xce,0x1d,0x7e,0x81,0x9d,0x7a,0x43,0x1d,0x7c,0x90,0xea,0x0e,0x5f};

static const unsigned char P521_P[66]={0x01,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff};
static const unsigned char P521_N[66]={0x01,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xfa,0x51,0x86,0x87,0x83,0xbf,0x2f,0x96,0x6b,0x7f,0xcc,0x01,0x48,0xf7,0x09,0xa5,0xd0,0x3b,0xb5,0xc9,0xb8,0x89,0x9c,0x47,0xae,0xbb,0x6f,0xb7,0x1e,0x91,0x38,0x64,0x09};
static const unsigned char P521_B[66]={0x00,0x51,0x95,0x3e,0xb9,0x61,0x8e,0x1c,0x9a,0x1f,0x92,0x9a,0x21,0xa0,0xb6,0x85,0x40,0xee,0xa2,0xda,0x72,0x5b,0x99,0xb3,0x15,0xf3,0xb8,0xb4,0x89,0x91,0x8e,0xf1,0x09,0xe1,0x56,0x19,0x39,0x51,0xec,0x7e,0x93,0x7b,0x16,0x52,0xc0,0xbd,0x3b,0xb1,0xbf,0x07,0x35,0x73,0xdf,0x88,0x3d,0x2c,0x34,0xf1,0xef,0x45,0x1f,0xd4,0x6b,0x50,0x3f,0x00};
static const unsigned char P521_GX[66]={0x00,0xc6,0x85,0x8e,0x06,0xb7,0x04,0x04,0xe9,0xcd,0x9e,0x3e,0xcb,0x66,0x23,0x95,0xb4,0x42,0x9c,0x64,0x81,0x39,0x05,0x3f,0xb5,0x21,0xf8,0x28,0xaf,0x60,0x6b,0x4d,0x3d,0xba,0xa1,0x4b,0x5e,0x77,0xef,0xe7,0x59,0x28,0xfe,0x1d,0xc1,0x27,0xa2,0xff,0xa8,0xde,0x33,0x48,0xb3,0xc1,0x85,0x6a,0x42,0x9b,0xf9,0x7e,0x7e,0x31,0xc2,0xe5,0xbd,0x66};
static const unsigned char P521_GY[66]={0x01,0x18,0x39,0x29,0x6a,0x78,0x9a,0x3b,0xc0,0x04,0x5c,0x8a,0x5f,0xb4,0x2c,0x7d,0x1b,0xd9,0x98,0xf5,0x44,0x49,0x57,0x9b,0x44,0x68,0x17,0xaf,0xbd,0x17,0x27,0x3e,0x66,0x2c,0x97,0xee,0x72,0x99,0x5e,0xf4,0x26,0x40,0xc5,0x50,0xb9,0x01,0x3f,0xad,0x07,0x61,0x35,0x3c,0x70,0x86,0xa2,0x72,0xc2,0x40,0x88,0xbe,0x94,0x76,0x9f,0xd1,0x66,0x50};

static curve C384, C521; static int inited=0;
static void init_curve(curve *cv,int nbytes,int pbits,int nbits,int halg,int fast,
  const unsigned char*p,const unsigned char*n,const unsigned char*b,const unsigned char*gx,const unsigned char*gy){
  cv->nbytes=nbytes; cv->pbits=pbits; cv->nbits=nbits; cv->hash_alg=halg; cv->fast=fast;
  cv->nl=(nbytes+7)/8;
  bytes_to_limbs(cv->p,p,nbytes,cv->nl); bytes_to_limbs(cv->n,n,nbytes,cv->nl);
  bytes_to_limbs(cv->b,b,nbytes,cv->nl); bytes_to_limbs(cv->gx,gx,nbytes,cv->nl); bytes_to_limbs(cv->gy,gy,nbytes,cv->nl);
  cv->n0_p=mont_n0(cv->p[0]); cv->n0_n=mont_n0(cv->n[0]);
  compute_rr(cv->rr_p,cv->p,cv->nl); compute_rr(cv->rr_n,cv->n,cv->nl);
  { u64 am[MAXL],three[MAXL],b3[MAXL];
    bn_zero(three); three[0]=3; bn_sub(am,cv->p,three,cv->nl);       /* a = -3 mod p */
    fp_to_mont(cv->amont,am,cv);
    { u64 t[MAXL],c; c=bn_add(t,cv->b,cv->b,cv->nl); if(c||bn_cmp(t,cv->p,cv->nl)>=0) bn_sub(t,t,cv->p,cv->nl);
      c=bn_add(b3,t,cv->b,cv->nl); if(c||bn_cmp(b3,cv->p,cv->nl)>=0) bn_sub(b3,b3,cv->p,cv->nl); }
    fp_to_mont(cv->b3mont,b3,cv);
  }
  build_comb(cv);
}
static void ecc_init(void){
  if(inited) return;
  init_curve(&C384,48,384,384,RKTCRYPTO_SHA384,384,P384_P,P384_N,P384_B,P384_GX,P384_GY);
  init_curve(&C521,66,521,521,RKTCRYPTO_SHA512,521,P521_P,P521_N,P521_B,P521_GX,P521_GY);
  inited=1;
}

/* ---- public per-curve entry points ---- */
static int ecc_pubkey(const curve *cv,unsigned char *out,const unsigned char *priv){
  u64 d[MAXL],x[MAXL],y[MAXL]; jpt R;
  bytes_to_limbs(d,priv,cv->nbytes,cv->nl);
  if(bn_iszero(d,cv->nl)||bn_cmp(d,cv->n,cv->nl)>=0) return 0;
  scalar_mul_base(&R,d,cv);
  if(bn_iszero(R.Z,cv->nl)) return 0;
  pt_to_affine(x,y,&R,cv);
  out[0]=4; limbs_to_bytes(out+1,x,cv->nbytes); limbs_to_bytes(out+1+cv->nbytes,y,cv->nbytes); return 1;
}
static int ecc_ecdh(const curve *cv,unsigned char *out,const unsigned char *scalar,const unsigned char *point){
  u64 d[MAXL],x[MAXL],y[MAXL]; jpt P,R; u64 one[MAXL];
  if(point[0]!=4) return 0;
  bytes_to_limbs(d,scalar,cv->nbytes,cv->nl);
  if(bn_iszero(d,cv->nl)||bn_cmp(d,cv->n,cv->nl)>=0) return 0;
  bytes_to_limbs(x,point+1,cv->nbytes,cv->nl); bytes_to_limbs(y,point+1+cv->nbytes,cv->nbytes,cv->nl);
  if(bn_cmp(x,cv->p,cv->nl)>=0||bn_cmp(y,cv->p,cv->nl)>=0) return 0;
  bn_zero(one); one[0]=1;
  fp_to_mont(P.X,x,cv); fp_to_mont(P.Y,y,cv);
  fp_to_mont(P.Z,one,cv);
  scalar_mul(&R,d,&P,cv);
  if(bn_iszero(R.Z,cv->nl)) return 0;
  pt_to_affine(x,y,&R,cv); limbs_to_bytes(out,x,cv->nbytes); return 1;
}
static int ecc_sign(const curve *cv,unsigned char *sig,const unsigned char *msg,intptr_t mlen,const unsigned char *priv){
  unsigned char h[64]; int hlen=(int)rktcrypto_digest_size(cv->hash_alg);
  u64 d[MAXL],z[MAXL],k[MAXL],x[MAXL],y[MAXL],r[MAXL],s[MAXL],kinv[MAXL],tmp[MAXL]; jpt R;
  int tries;
  rktcrypto_digest_oneshot(cv->hash_alg,msg,0,mlen,h,0,hlen);
  hash_to_scalar(z,h,hlen,cv);
  bytes_to_limbs(d,priv,cv->nbytes,cv->nl);
  for(tries=0;tries<64;tries++){
    unsigned char kb[66];
    if(!rktcrypto_random_bytes(kb,0,cv->nbytes)) return 0;
    bytes_to_limbs(k,kb,cv->nbytes,cv->nl);
    if(cv->nbits%8){ int excess=8-(cv->nbits%8); k[cv->nl-1]&=(~(u64)0)>>(64-((cv->nbits-1)%64+1)); (void)excess; }
    if(bn_iszero(k,cv->nl)||bn_cmp(k,cv->n,cv->nl)>=0) continue;
    scalar_mul_base(&R,k,cv); if(bn_iszero(R.Z,cv->nl)) continue;
    pt_to_affine(x,y,&R,cv);
    bn_cpy(r,x); if(bn_cmp(r,cv->n,cv->nl)>=0) bn_sub(r,r,cv->n,cv->nl);
    if(bn_iszero(r,cv->nl)) continue;
    fn_inv(kinv,k,cv);
    /* tmp = r*d mod n (plain modular multiply via Montgomery round-trip) */
    { u64 rm[MAXL],dm[MAXL],pm[MAXL]; to_mont(rm,r,cv->n,cv->rr_n,cv->n0_n,cv->nl); to_mont(dm,d,cv->n,cv->rr_n,cv->n0_n,cv->nl); fn_mul(pm,rm,dm,cv); from_mont(tmp,pm,cv->n,cv->n0_n,cv->nl); }
    fn_add(tmp,z,tmp,cv);      /* z + r*d */
    { u64 km[MAXL],tm[MAXL],pm[MAXL]; to_mont(km,kinv,cv->n,cv->rr_n,cv->n0_n,cv->nl); to_mont(tm,tmp,cv->n,cv->rr_n,cv->n0_n,cv->nl); fn_mul(pm,km,tm,cv); from_mont(s,pm,cv->n,cv->n0_n,cv->nl); }
    if(bn_iszero(s,cv->nl)) continue;
    limbs_to_bytes(sig,r,cv->nbytes); limbs_to_bytes(sig+cv->nbytes,s,cv->nbytes); return 1;
  }
  return 0;
}
static int ecc_verify(const curve *cv,const unsigned char *sig,const unsigned char *msg,intptr_t mlen,const unsigned char *pub){
  unsigned char h[64]; int hlen=(int)rktcrypto_digest_size(cv->hash_alg);
  u64 r[MAXL],s[MAXL],z[MAXL],w[MAXL],u1[MAXL],u2[MAXL],qx[MAXL],qy[MAXL],x[MAXL],y[MAXL],one[MAXL],v[MAXL];
  jpt Q,R1,R2,R;
  if(pub[0]!=4) return 0;
  bytes_to_limbs(r,sig,cv->nbytes,cv->nl); bytes_to_limbs(s,sig+cv->nbytes,cv->nbytes,cv->nl);
  if(bn_iszero(r,cv->nl)||bn_cmp(r,cv->n,cv->nl)>=0||bn_iszero(s,cv->nl)||bn_cmp(s,cv->n,cv->nl)>=0) return 0;
  rktcrypto_digest_oneshot(cv->hash_alg,msg,0,mlen,h,0,hlen); hash_to_scalar(z,h,hlen,cv);
  fn_inv(w,s,cv);
  { u64 zm[MAXL],wm[MAXL],pm[MAXL]; to_mont(zm,z,cv->n,cv->rr_n,cv->n0_n,cv->nl); to_mont(wm,w,cv->n,cv->rr_n,cv->n0_n,cv->nl); fn_mul(pm,zm,wm,cv); from_mont(u1,pm,cv->n,cv->n0_n,cv->nl); }
  { u64 rm[MAXL],wm[MAXL],pm[MAXL]; to_mont(rm,r,cv->n,cv->rr_n,cv->n0_n,cv->nl); to_mont(wm,w,cv->n,cv->rr_n,cv->n0_n,cv->nl); fn_mul(pm,rm,wm,cv); from_mont(u2,pm,cv->n,cv->n0_n,cv->nl); }
  bytes_to_limbs(qx,pub+1,cv->nbytes,cv->nl); bytes_to_limbs(qy,pub+1+cv->nbytes,cv->nbytes,cv->nl);
  bn_zero(one); one[0]=1;
  fp_to_mont(Q.X,qx,cv); fp_to_mont(Q.Y,qy,cv); fp_to_mont(Q.Z,one,cv);
  scalar_mul_base(&R1,u1,cv); scalar_mul(&R2,u2,&Q,cv);
  pt_add(&R,&R1,&R2,cv);
  if(bn_iszero(R.Z,cv->nl)) return 0;
  pt_to_affine(x,y,&R,cv);
  bn_cpy(v,x); if(bn_cmp(v,cv->n,cv->nl)>=0) bn_sub(v,v,cv->n,cv->nl);
  return bn_cmp(v,r,cv->nl)==0;
}

int rktcrypto_p384_pubkey(unsigned char *out,const unsigned char *priv){ ecc_init(); return ecc_pubkey(&C384,out,priv); }
int rktcrypto_p384_ecdh(unsigned char *out,const unsigned char *scalar,const unsigned char *point){ ecc_init(); return ecc_ecdh(&C384,out,scalar,point); }
int rktcrypto_p384_ecdsa_sign(unsigned char *sig,const unsigned char *msg,intptr_t mlen,const unsigned char *priv){ ecc_init(); return ecc_sign(&C384,sig,msg,mlen,priv); }
int rktcrypto_p384_ecdsa_verify(const unsigned char *sig,const unsigned char *msg,intptr_t mlen,const unsigned char *pub){ ecc_init(); return ecc_verify(&C384,sig,msg,mlen,pub); }
int rktcrypto_p521_pubkey(unsigned char *out,const unsigned char *priv){ ecc_init(); return ecc_pubkey(&C521,out,priv); }
int rktcrypto_p521_ecdh(unsigned char *out,const unsigned char *scalar,const unsigned char *point){ ecc_init(); return ecc_ecdh(&C521,out,scalar,point); }
int rktcrypto_p521_ecdsa_sign(unsigned char *sig,const unsigned char *msg,intptr_t mlen,const unsigned char *priv){ ecc_init(); return ecc_sign(&C521,sig,msg,mlen,priv); }
int rktcrypto_p521_ecdsa_verify(const unsigned char *sig,const unsigned char *msg,intptr_t mlen,const unsigned char *pub){ ecc_init(); return ecc_verify(&C521,sig,msg,mlen,pub); }
