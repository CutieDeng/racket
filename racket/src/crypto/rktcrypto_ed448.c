/* Ed448 signatures (RFC 8032), pure mode with empty context. Edwards curve
   edwards448 (a=1, d=-39081) over p = 2^448-2^224-1, SHAKE256 hashing, and
   scalar arithmetic mod the group order L via the in-tree bignum. Field
   elements are 7-limb Montgomery; point arithmetic uses extended
   coordinates with the complete a=1 Edwards addition. From scratch, no
   external code. */

#include "rktcrypto.h"
#include "rktcrypto_digest.h"
#include "rktcrypto_bn.h"
#include <string.h>
#include <stdint.h>

typedef uint64_t u64;
#define NL 7

static const u64 P448[NL]={
  0xffffffffffffffffULL,0xffffffffffffffffULL,0xffffffffffffffffULL,0xfffffffeffffffffULL,
  0xffffffffffffffffULL,0xffffffffffffffffULL,0xffffffffffffffffULL};

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

static u64 g_n0; static u64 g_rr[NL], g_dmont[NL]; static int inited=0;
static u64 g_e_sqrt[NL];   /* (p+1)/4 as limbs, for sqrt */

/* ---- field ---- */
static int fbn_cmp(const u64 *a,const u64 *b){ int i; for(i=NL-1;i>=0;i--){ if(a[i]<b[i])return -1; if(a[i]>b[i])return 1; } return 0; }
static u64 fbn_add(u64 *r,const u64 *a,const u64 *b){ int i; u64 c=0; for(i=0;i<NL;i++){ u128 s=(u128)a[i]+b[i]+c; r[i]=(u64)s; c=(u64)(s>>64);} return c; }
static u64 fbn_sub(u64 *r,const u64 *a,const u64 *b){ int i; u64 br=0; for(i=0;i<NL;i++){ u128 d=(u128)a[i]-b[i]-br; r[i]=(u64)d; br=(u64)((d>>64)&1);} return br; }
static void montmul(u64 *r,const u64 *a,const u64 *b){
  u64 t[NL+2]; int i,j; for(i=0;i<NL+2;i++) t[i]=0;
  for(i=0;i<NL;i++){
    u64 c=0; u128 p;
    for(j=0;j<NL;j++){ p=(u128)a[j]*b[i]+t[j]+c; t[j]=(u64)p; c=(u64)(p>>64); }
    { u128 s=(u128)t[NL]+c; t[NL]=(u64)s; t[NL+1]=(u64)(s>>64); }
    { u64 mm=(u64)((u128)t[0]*g_n0); u64 cc; p=(u128)mm*P448[0]+t[0]; cc=(u64)(p>>64);
      for(j=1;j<NL;j++){ p=(u128)mm*P448[j]+t[j]+cc; t[j-1]=(u64)p; cc=(u64)(p>>64); }
      { u128 s=(u128)t[NL]+cc; t[NL-1]=(u64)s; t[NL]=t[NL+1]+(u64)(s>>64); } }
  }
  { u64 tmp[NL],borrow; int k; borrow=0;
    for(k=0;k<NL;k++){ u128 d=(u128)t[k]-P448[k]-borrow; tmp[k]=(u64)d; borrow=(u64)((d>>64)&1); }
    borrow=(t[NL]!=0)?0:borrow;
    if(borrow==0){ for(k=0;k<NL;k++) r[k]=tmp[k]; } else { for(k=0;k<NL;k++) r[k]=t[k]; } }
}
static void fadd(u64 *r,const u64 *a,const u64 *b){ u64 c=fbn_add(r,a,b); if(c||fbn_cmp(r,P448)>=0) fbn_sub(r,r,P448); }
static void fsub(u64 *r,const u64 *a,const u64 *b){ u64 br=fbn_sub(r,a,b); if(br) fbn_add(r,r,P448); }
static void fmul(u64 *r,const u64 *a,const u64 *b){ montmul(r,a,b); }
static void fsqr(u64 *r,const u64 *a){ montmul(r,a,a); }
static u64 mont_n0(u64 m0){ u64 x=1; int i; for(i=0;i<6;i++) x*=2-m0*x; return (u64)(0-x); }
static void to_mont(u64 *r,const u64 *a){ montmul(r,a,g_rr); }
static void from_mont(u64 *r,const u64 *a){ u64 one[NL]={1,0,0,0,0,0,0}; montmul(r,a,one); }
static int fis_zero(const u64 *a){ int i; u64 x=0; for(i=0;i<NL;i++) x|=a[i]; return x==0; }
static void fpow(u64 *r,const u64 *a,const u64 *e,int ebits){
  u64 acc[NL],base[NL]; int i; u64 one[NL]={1,0,0,0,0,0,0};
  to_mont(acc,one); for(i=0;i<NL;i++) base[i]=a[i];
  for(i=0;i<ebits;i++){ if((e[i/64]>>(i%64))&1) fmul(acc,acc,base); fsqr(base,base); }
  for(i=0;i<NL;i++) r[i]=acc[i];
}
static void finv(u64 *r,const u64 *a){ u64 e[NL]; u64 two[NL]={2,0,0,0,0,0,0}; fbn_sub(e,P448,two); fpow(r,a,e,448); }

static void be56_to_limbs(u64 *a,const unsigned char *s){ int i; for(i=0;i<NL;i++) a[i]=0;
  for(i=0;i<56;i++){ int bit=(56-1-i)*8; a[bit/64]|=(u64)s[i]<<(bit%64); } }
static void le56_to_limbs(u64 *a,const unsigned char *s){ int i; for(i=0;i<NL;i++) a[i]=0;
  for(i=0;i<56;i++) a[i/8]|=(u64)s[i]<<(8*(i%8)); }
static void limbs_to_le56(unsigned char *s,const u64 *a){ int i; for(i=0;i<56;i++) s[i]=(unsigned char)(a[i/8]>>(8*(i%8))); }

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
static void pt_dbl(ept *R,const ept *P){ pt_add(R,P,P); }

static void pt_cmov(ept *R,const ept *A,u64 b){ u64 mask=0-b; int i;
  for(i=0;i<NL;i++){ R->X[i]^=mask&(R->X[i]^A->X[i]); R->Y[i]^=mask&(R->Y[i]^A->Y[i]);
    R->Z[i]^=mask&(R->Z[i]^A->Z[i]); R->T[i]^=mask&(R->T[i]^A->T[i]); } }

/* R = k*P where k is a big-endian byte scalar of kbytes length; MSB-first
   double-and-add, constant-time (always add, cmov the result). */
static void pt_scalarmul(ept *R,const unsigned char *k_be,int kbytes,const ept *P){
  ept acc,T2; int i; pt_identity(&acc);
  for(i=kbytes*8-1;i>=0;i--){
    int bit=(k_be[kbytes-1-(i/8)]>>(i%8))&1;
    pt_dbl(&acc,&acc);
    pt_add(&T2,&acc,P);
    pt_cmov(&acc,&T2,(u64)bit);
  }
  *R=acc;
}

/* encode point to 57 bytes: y little-endian (56) + sign(x) in bit 7 of byte 56. */
static void pt_encode(unsigned char out[57],const ept *P){
  u64 zi[NL],x[NL],y[NL],xr[NL],yr[NL];
  finv(zi,P->Z); fmul(x,P->X,zi); fmul(y,P->Y,zi);
  from_mont(xr,x); from_mont(yr,y);
  limbs_to_le56(out,yr); out[56]=(unsigned char)((xr[0]&1)<<7);
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
  fpow(x,u,g_e_sqrt,448);                 /* x = u^((p+1)/4) = sqrt(u) */
  fsqr(x2,x);
  if(fbn_cmp(x2,u)!=0) return 0;          /* not a square -> invalid */
  { u64 xr[NL]; from_mont(xr,x); if((int)(xr[0]&1)!=sign){ u64 z[NL]={0,0,0,0,0,0,0}; fsub(x,z,x); } }
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
  u64 t[NL]; int i;
  if(inited) return;
  g_n0=mont_n0(P448[0]);
  for(i=0;i<NL;i++) t[i]=0; t[0]=1;
  for(i=0;i<2*64*NL;i++){ u64 c=fbn_add(t,t,t); if(c||fbn_cmp(t,P448)>=0) fbn_sub(t,t,P448); }
  for(i=0;i<NL;i++) g_rr[i]=t[i];
  { u64 dd[NL]={39081,0,0,0,0,0,0},pmd[NL]; fbn_sub(pmd,P448,dd); to_mont(g_dmont,pmd); }  /* d=-39081 */
  { u64 one[NL]={1,0,0,0,0,0,0},e[NL]; fbn_add(e,P448,one);   /* e=(p+1)/4 */
    for(i=0;i<NL-1;i++) e[i]=(e[i]>>2)|(e[i+1]<<62); e[NL-1]>>=2; for(i=0;i<NL;i++) g_e_sqrt[i]=e[i]; }
  inited=1;
}

/* ---- public API ---- */
static void ed448_genA(unsigned char A[57],const unsigned char *sk){
  unsigned char h[114]; ept G,R; u64 gx[NL],gy[NL];
  shake256(h,114,sk,57);
  h[0]&=0xfc; h[55]|=0x80; h[56]=0;   /* clamp; low 448 bits = secret scalar s (little-endian) */
  be56_to_limbs(gx,GX_BE); be56_to_limbs(gy,GY_BE);
  to_mont(G.X,gx); to_mont(G.Y,gy); { u64 one[NL]={1,0,0,0,0,0,0}; to_mont(G.Z,one); } fmul(G.T,G.X,G.Y);
  { unsigned char sbe[57]; int i; for(i=0;i<57;i++) sbe[i]=h[56-i]; pt_scalarmul(&R,sbe,57,&G); }
  pt_encode(A,&R);
}

int rktcrypto_ed448_pubkey(unsigned char *pk,const unsigned char *sk){
  ed448_init(); ed448_genA(pk,sk); return 1;
}
int rktcrypto_ed448_sign(unsigned char *sig,const unsigned char *msg,intptr_t mlen,const unsigned char *sk){
  unsigned char h[114],A[57],rbuf[114],r57[57],R[57],kbuf[114],k57[57],S57[57],sbe[57]; ept G,Rp; u64 gx[NL],gy[NL]; int i;
  ed448_init();
  shake256(h,114,sk,57); h[0]&=0xfc; h[55]|=0x80; h[56]=0;
  be56_to_limbs(gx,GX_BE); be56_to_limbs(gy,GY_BE);
  to_mont(G.X,gx); to_mont(G.Y,gy); { u64 one[NL]={1,0,0,0,0,0,0}; to_mont(G.Z,one); } fmul(G.T,G.X,G.Y);
  ed448_genA(A,sk);
  /* r = SHAKE256(dom4 || prefix || M) mod L ; prefix = h[57..113] */
  { rktcrypto_keccak_ctx_t c; rktcrypto_keccak_core_init(&c,136,0x1f);
    rktcrypto_keccak_core_update(&c,DOM4,10); rktcrypto_keccak_core_update(&c,h+57,57);
    rktcrypto_keccak_core_update(&c,msg,mlen); rktcrypto_keccak_core_final(&c,rbuf,114); }
  sc_reduce_le(r57,rbuf,114);
  for(i=0;i<57;i++) sbe[i]=r57[56-i]; pt_scalarmul(&Rp,sbe,57,&G); pt_encode(R,&Rp);
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
  unsigned char kbuf[114],k57[57],sbe[57],kbe[57]; ept G,A,Rp,SB,kA,rhs; u64 gx[NL],gy[NL]; int i;
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
  for(i=0;i<57;i++) sbe[i]=S[56-i]; pt_scalarmul(&SB,sbe,57,&G);        /* S*B */
  for(i=0;i<57;i++) kbe[i]=k57[56-i]; pt_scalarmul(&kA,kbe,57,&A);      /* k*A */
  if(!pt_decode(&Rp,R)) return 0;
  pt_add(&rhs,&Rp,&kA);                                                  /* R + k*A */
  { unsigned char e1[57],e2[57]; pt_encode(e1,&SB); pt_encode(e2,&rhs); return memcmp(e1,e2,57)==0; }
}
