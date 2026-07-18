/* X448 (RFC 7748): ECDH over Curve448. Montgomery ladder on the
   x-coordinate, constant-time in the scalar. Field is p = 2^448 - 2^224 - 1,
   held in 7-limb Montgomery form. From scratch, no external code. */

#include "rktcrypto.h"
#include <string.h>
#include <stdint.h>

typedef uint64_t u64;
typedef unsigned __int128 u128;
#define NL 7    /* 448 bits */

/* p = 2^448 - 2^224 - 1 */
static const u64 P448[NL]={
  0xffffffffffffffffULL,0xffffffffffffffffULL,0xffffffffffffffffULL,0xfffffffeffffffffULL,
  0xffffffffffffffffULL,0xffffffffffffffffULL,0xffffffffffffffffULL};

static u64 g_n0; static u64 g_rr[NL]; static u64 g_a24m[NL]; static int inited=0;

static int bn_cmp(const u64 *a,const u64 *b){ int i; for(i=NL-1;i>=0;i--){ if(a[i]<b[i])return -1; if(a[i]>b[i])return 1; } return 0; }
static u64 bn_add(u64 *r,const u64 *a,const u64 *b){ int i; u64 c=0; for(i=0;i<NL;i++){ u128 s=(u128)a[i]+b[i]+c; r[i]=(u64)s; c=(u64)(s>>64);} return c; }
static u64 bn_sub(u64 *r,const u64 *a,const u64 *b){ int i; u64 br=0; for(i=0;i<NL;i++){ u128 d=(u128)a[i]-b[i]-br; r[i]=(u64)d; br=(u64)((d>>64)&1);} return br; }

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
    borrow = (t[NL]!=0)?0:borrow;
    if(borrow==0){ for(k=0;k<NL;k++) r[k]=tmp[k]; } else { for(k=0;k<NL;k++) r[k]=t[k]; } }
}
static void fadd(u64 *r,const u64 *a,const u64 *b){ u64 c=bn_add(r,a,b); if(c||bn_cmp(r,P448)>=0) bn_sub(r,r,P448); }
static void fsub(u64 *r,const u64 *a,const u64 *b){ u64 br=bn_sub(r,a,b); if(br) bn_add(r,r,P448); }
static void fmul(u64 *r,const u64 *a,const u64 *b){ montmul(r,a,b); }
static void fsqr(u64 *r,const u64 *a){ montmul(r,a,a); }

static u64 mont_n0(u64 m0){ u64 x=1; int i; for(i=0;i<6;i++) x*=2-m0*x; return (u64)(0-x); }
static void to_mont(u64 *r,const u64 *a){ montmul(r,a,g_rr); }
static void from_mont(u64 *r,const u64 *a){ u64 one[NL]={1,0,0,0,0,0,0}; montmul(r,a,one); }

static void x448_init(void){
  u64 t[NL]; int i;
  if(inited) return;
  g_n0=mont_n0(P448[0]);
  /* rr = 2^(2*64*NL) mod p, via 2*64*NL modular doublings of 1 */
  for(i=0;i<NL;i++) t[i]=0; t[0]=1;
  for(i=0;i<2*64*NL;i++){ u64 c=bn_add(t,t,t); if(c||bn_cmp(t,P448)>=0) bn_sub(t,t,P448); }
  for(i=0;i<NL;i++) g_rr[i]=t[i];
  { u64 a24[NL]={39081,0,0,0,0,0,0}; to_mont(g_a24m,a24); }   /* (A-2)/4 = 39081 */
  inited=1;
}

/* fe inverse via Fermat: a^(p-2), Montgomery domain. */
static void finv(u64 *r,const u64 *a){
  u64 e[NL],acc[NL],base[NL]; int i; u64 one[NL]={1,0,0,0,0,0,0};
  { u64 two[NL]={2,0,0,0,0,0,0}; bn_sub(e,P448,two); }
  to_mont(acc,one); for(i=0;i<NL;i++) base[i]=a[i];
  for(i=0;i<448;i++){ if((e[i/64]>>(i%64))&1) fmul(acc,acc,base); fsqr(base,base); }
  for(i=0;i<NL;i++) r[i]=acc[i];
}

static void cswap(u64 swap,u64 *a,u64 *b){ u64 mask=0-swap; int i; for(i=0;i<NL;i++){ u64 t=mask&(a[i]^b[i]); a[i]^=t; b[i]^=t; } }

/* out = scalar * point (both 56-byte little-endian). Returns 1, or 0 if the
   result is all-zero (low-order point). */
int rktcrypto_x448(unsigned char *out, const unsigned char *scalar, const unsigned char *point){
  unsigned char e[56]; u64 u[NL],x1[NL],x2[NL],z2[NL],x3[NL],z3[NL],zero[NL]; int i,t; u64 swap=0;
  x448_init();
  memcpy(e,scalar,56); e[0]&=252; e[55]|=128;    /* clamp */
  for(i=0;i<NL;i++){ u64 v=0; int b; for(b=0;b<8;b++){ int idx=8*i+b; if(idx<56) v|=(u64)point[idx]<<(8*b); } u[i]=v; }
  { u64 um[NL]; to_mont(um,u); for(i=0;i<NL;i++) u[i]=um[i]; }   /* x1 = u (mont) */
  for(i=0;i<NL;i++){ x1[i]=u[i]; x3[i]=u[i]; z2[i]=0; z3[i]=0; x2[i]=0; }
  to_mont(x2,(u64[NL]){1,0,0,0,0,0,0}); to_mont(z3,(u64[NL]){1,0,0,0,0,0,0});
  for(i=0;i<NL;i++) zero[i]=0;
  for(t=447;t>=0;t--){
    u64 kt=(e[t/8]>>(t%8))&1;
    u64 A[NL],AA[NL],B[NL],BB[NL],E[NL],C[NL],D[NL],DA[NL],CB[NL],t0[NL],t1[NL];
    swap^=kt; cswap(swap,x2,x3); cswap(swap,z2,z3); swap=kt;
    fadd(A,x2,z2); fsqr(AA,A); fsub(B,x2,z2); fsqr(BB,B); fsub(E,AA,BB);
    fadd(C,x3,z3); fsub(D,x3,z3); fmul(DA,D,A); fmul(CB,C,B);
    fadd(t0,DA,CB); fsqr(x3,t0); fsub(t1,DA,CB); fsqr(t1,t1); fmul(z3,x1,t1);
    fmul(x2,AA,BB);
    fmul(t0,g_a24m,E); fadd(t0,AA,t0); fmul(z2,E,t0);
  }
  cswap(swap,x2,x3); cswap(swap,z2,z3);
  { u64 zi[NL],res[NL],rp[NL]; finv(zi,z2); fmul(res,x2,zi); from_mont(rp,res);
    for(i=0;i<NL;i++){ int b; for(b=0;b<8;b++){ int idx=8*i+b; if(idx<56) out[idx]=(unsigned char)(rp[i]>>(8*b)); } }
    (void)zero; { unsigned char z=0; for(i=0;i<56;i++) z|=out[i]; return z!=0; } }
}

/* Public key = X448(scalar, 5). Base u=5. */
int rktcrypto_x448_pubkey(unsigned char *out, const unsigned char *scalar){
  unsigned char base[56]; memset(base,0,56); base[0]=5;
  return rktcrypto_x448(out,scalar,base);
}
