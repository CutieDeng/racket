/* X448 (RFC 7748): ECDH over Curve448. Montgomery ladder on the x-coordinate,
   constant-time in the scalar. Field p = 2^448 - 2^224 - 1 held in reduced-radix
   8x56-bit limbs: because 224 = 4*56, the fast reduction 2^448 = 2^224 + 1 is
   limb-aligned (a high digit at position 8+k folds into limbs k and k+4), so
   field multiplies avoid Montgomery reduction entirely. From scratch, no external
   code. */

#include "rktcrypto.h"
#include <string.h>
#include <stdint.h>

typedef uint64_t u64;
typedef unsigned __int128 u128;
#define M56 0xffffffffffffffULL
typedef u64 fe[8];

/* p in 8x56-bit limbs */
static const u64 P448R[8]={
  0xffffffffffffffULL,0xffffffffffffffULL,0xffffffffffffffULL,0xffffffffffffffULL,
  0xfffffffffffffeULL,0xffffffffffffffULL,0xffffffffffffffULL,0xffffffffffffffULL};
/* 2*p per limb (constant added by fe_sub to avoid underflow; value = 2p = 0 mod p) */
static const u64 TWOP[8]={
  0x1fffffffffffffeULL,0x1fffffffffffffeULL,0x1fffffffffffffeULL,0x1fffffffffffffeULL,
  0x1fffffffffffffcULL,0x1fffffffffffffeULL,0x1fffffffffffffeULL,0x1fffffffffffffeULL};

static void fe_0(fe h){ int i; for(i=0;i<8;i++) h[i]=0; }
static void fe_1(fe h){ fe_0(h); h[0]=1; }
static void fe_copy(fe h,const fe f){ int i; for(i=0;i<8;i++) h[i]=f[i]; }
static void fe_add(fe h,const fe f,const fe g){ int i; for(i=0;i<8;i++) h[i]=f[i]+g[i]; }
static void fe_sub(fe h,const fe f,const fe g){ int i; for(i=0;i<8;i++) h[i]=f[i]+TWOP[i]-g[i]; }
static void fe_frombytes(fe h,const unsigned char*s){ int i,j; for(i=0;i<8;i++){ u64 v=0; for(j=0;j<7;j++) v|=(u64)s[7*i+j]<<(8*j); h[i]=v; } }
static void fe_carry_fold(fe h,u128 acc[8]){
  u64 c=0,c0,c4; int i;
  for(i=0;i<8;i++){ u128 v=acc[i]+c; h[i]=(u64)v&M56; c=(u64)(v>>56); }
  h[0]+=c; h[4]+=c;
  /* the fold lands the final carry only in limbs 0 and 4; propagate those two
     into 1 and 5 (lazy: limbs stay < 2^57, valid input for the next multiply). */
  c0=h[0]>>56; h[0]&=M56; h[1]+=c0;
  c4=h[4]>>56; h[4]&=M56; h[5]+=c4;
}
static void fe_mul(fe h,const fe f,const fe g){
  u128 acc[15]; int i,j; for(i=0;i<15;i++) acc[i]=0;
  for(i=0;i<8;i++) for(j=0;j<8;j++) acc[i+j]+=(u128)f[i]*g[j];
  for(i=14;i>=8;i--){ acc[i-8]+=acc[i]; acc[i-4]+=acc[i]; }
  fe_carry_fold(h,acc);
}
static void fe_sq(fe h,const fe f){        /* 36 products via doubled cross terms */
  u128 acc[15]; int i,j; for(i=0;i<15;i++) acc[i]=0;
  for(i=0;i<8;i++){ acc[2*i]+=(u128)f[i]*f[i]; for(j=i+1;j<8;j++) acc[i+j]+=(u128)(2*(u128)f[i]*f[j]); }
  for(i=14;i>=8;i--){ acc[i-8]+=acc[i]; acc[i-4]+=acc[i]; }
  fe_carry_fold(h,acc);
}
static void fe_mul_a24(fe h,const fe f){   /* * 39081 = (156326-2)/4 for Curve448 */
  u128 acc[8]; int i; for(i=0;i<8;i++) acc[i]=(u128)f[i]*39081;
  fe_carry_fold(h,acc);
}
static void fe_reduce(fe h){ u128 acc[8]; int i; for(i=0;i<8;i++) acc[i]=h[i]; fe_carry_fold(h,acc); }
static void fe_tobytes(unsigned char*s,const fe hh){
  fe h; int i,j; u64 t[8],bb; fe_copy(h,hh); fe_reduce(h);
  bb=0; for(i=0;i<8;i++){ u128 d=(u128)h[i]-P448R[i]-bb; t[i]=(u64)d&M56; bb=(u64)((d>>64)&1); }
  if(!bb) for(i=0;i<8;i++) h[i]=t[i];               /* h >= p -> subtract p */
  for(i=0;i<8;i++) for(j=0;j<7;j++) s[7*i+j]=(unsigned char)(h[i]>>(8*j));
}
static void fe_cswap(u64 swap,fe a,fe b){ u64 m=0-swap; int i; for(i=0;i<8;i++){ u64 t=m&(a[i]^b[i]); a[i]^=t; b[i]^=t; } }

/* inverse via Fermat a^(p-2); p-2 = 2^448 - 2^224 - 3 (LE bytes) */
static void fe_invert(fe r,const fe a){
  static const unsigned char E[56]={
    0xfd,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
    0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xfe,0xff,0xff,0xff,
    0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
    0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff};
  fe acc,base; int i; fe_1(acc); fe_copy(base,a);
  for(i=0;i<448;i++){ if((E[i>>3]>>(i&7))&1) fe_mul(acc,acc,base); fe_sq(base,base); }
  fe_copy(r,acc);
}

int rktcrypto_x448(unsigned char *out, const unsigned char *scalar, const unsigned char *point){
  unsigned char e[56]; fe x1,x2,z2,x3,z3; int i,t; u64 swap=0;
  memcpy(e,scalar,56); e[0]&=252; e[55]|=128;                 /* clamp */
  { unsigned char pb[56]; memcpy(pb,point,56); fe_frombytes(x1,pb); }
  fe_1(x2); fe_0(z2); fe_copy(x3,x1); fe_1(z3);
  for(t=447;t>=0;t--){
    u64 kt=(e[t/8]>>(t%8))&1;
    fe A,AA,B,BB,E2,C,D,DA,CB,t0,t1;
    swap^=kt; fe_cswap(swap,x2,x3); fe_cswap(swap,z2,z3); swap=kt;
    fe_add(A,x2,z2); fe_sq(AA,A); fe_sub(B,x2,z2); fe_sq(BB,B); fe_sub(E2,AA,BB);
    fe_add(C,x3,z3); fe_sub(D,x3,z3); fe_mul(DA,D,A); fe_mul(CB,C,B);
    fe_add(t0,DA,CB); fe_sq(x3,t0); fe_sub(t1,DA,CB); fe_sq(t1,t1); fe_mul(z3,x1,t1);
    fe_mul(x2,AA,BB);
    fe_mul_a24(t0,E2); fe_add(t0,AA,t0); fe_mul(z2,E2,t0);
  }
  fe_cswap(swap,x2,x3); fe_cswap(swap,z2,z3);
  { fe zi,res; fe_invert(zi,z2); fe_mul(res,x2,zi); fe_tobytes(out,res); }
  { unsigned char z=0; for(i=0;i<56;i++) z|=out[i]; return z!=0; }
}

/* Public key = X448(scalar, 5). */
int rktcrypto_x448_pubkey(unsigned char *out, const unsigned char *scalar){
  unsigned char base[56]; memset(base,0,56); base[0]=5;
  return rktcrypto_x448(out,scalar,base);
}
