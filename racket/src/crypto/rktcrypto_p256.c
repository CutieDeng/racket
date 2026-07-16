/* NIST P-256 (secp256r1): ECDH and ECDSA.

   From-scratch public-domain-style implementation. Field and scalar
   arithmetic use 4x64-bit limbs with generic Montgomery reduction
   (parameterized by the modulus, so the same code serves the field
   prime p and the group order n). Points use Jacobian coordinates;
   scalar multiplication is a constant-time double-and-add. ECDSA
   signing draws a random nonce by rejection sampling from the built-in
   CSPRNG. SHA-256 comes from the existing digest core. No external
   code. */

#include "rktcrypto.h"
#include <string.h>
#include <stdint.h>

typedef uint64_t u64;
typedef unsigned __int128 u128;

/* ---- modulus contexts ---- */
typedef struct { u64 m[4]; u64 n0; u64 rr[4]; } mont_ctx;

/* P-256 field prime p and group order n, little-endian limbs. */
static const u64 P[4]={0xffffffffffffffffULL,0x00000000ffffffffULL,0x0000000000000000ULL,0xffffffff00000001ULL};
static const u64 N[4]={0xf3b9cac2fc632551ULL,0xbce6faada7179e84ULL,0xffffffffffffffffULL,0xffffffff00000000ULL};

static int bn_geq(const u64 a[4],const u64 b[4]){
  int i; for(i=3;i>=0;i--){ if(a[i]>b[i])return 1; if(a[i]<b[i])return 0; } return 1;
}
static u64 bn_sub(u64 r[4],const u64 a[4],const u64 b[4]){
  u128 br=0; int i;
  for(i=0;i<4;i++){ u128 t=(u128)a[i]-b[i]-br; r[i]=(u64)t; br=(t>>64)&1; }
  return (u64)br;
}
static void bn_cadd(u64 r[4],const u64 m[4],u64 cond){
  u128 c=0; u64 mask=0-cond; int i;
  for(i=0;i<4;i++){ u128 t=(u128)r[i]+(m[i]&mask)+c; r[i]=(u64)t; c=t>>64; }
}

/* Montgomery multiply: r = a*b*R^-1 mod m.

   On AArch64 the hot path routes to mont_mul_asm (an asmp-generated,
   fully register-resident CIOS; ~2.2x this portable C, drop-in same ABI,
   reads ctx->m/ctx->n0). The portable version below stays as the
   non-AArch64 implementation and the differential-test oracle. */
static void __attribute__((unused))
mont_mul_portable(u64 r[4],const u64 a[4],const u64 b[4],const mont_ctx *ctx){
  u64 t[6]={0,0,0,0,0,0}; int i,j;
  const u64 *m=ctx->m; u64 n0=ctx->n0;
  for(i=0;i<4;i++){
    u128 carry=0;
    for(j=0;j<4;j++){ u128 s=(u128)a[i]*b[j]+t[j]+carry; t[j]=(u64)s; carry=s>>64; }
    { u128 s=(u128)t[4]+carry; t[4]=(u64)s; t[5]+=(u64)(s>>64); }
    { u64 mm=t[0]*n0; carry=0;
      for(j=0;j<4;j++){ u128 s=(u128)mm*m[j]+t[j]+carry; t[j]=(u64)s; carry=s>>64; }
      { u128 s=(u128)t[4]+carry; t[4]=(u64)s; t[5]+=(u64)(s>>64); } }
    for(j=0;j<5;j++)t[j]=t[j+1]; t[5]=0;
  }
  { u64 out[4]; int k; for(k=0;k<4;k++)out[k]=t[k];
    /* if t>=m (including the overflow limb t[4]) subtract m */
    u64 borrow; u64 tmp[4]; borrow=bn_sub(tmp,out,m);
    u64 ge=(t[4]!=0)|(borrow==0);
    for(k=0;k<4;k++)r[k]=ge?tmp[k]:out[k]; }
}

/* Route every field/scalar multiply to the fastest available backend.
   AArch64/Apple: asmp-generated register-resident assembly -- the field
   prime p (all point arithmetic) uses mont_mul_p256, whose Montgomery
   reduction is pure shifts/subtracts (n0=1, Solinas limbs), 1.28x the
   generic CIOS; the scalar order n keeps the generic mont_mul_asm. The ctx
   pointer is a compile-time constant at essentially every call site, so the
   dispatch branch folds away under inlining. Otherwise: portable C. */
static mont_ctx FP, FN;   /* defined (initialised) in p256_init below */
#if defined(__aarch64__) && defined(__APPLE__) && !defined(RKTCRYPTO_P256_NO_ASM)
extern void mont_mul_asm(u64 r[4],const u64 a[4],const u64 b[4],const mont_ctx *ctx);
extern void mont_mul_p256(u64 r[4],const u64 a[4],const u64 b[4]);
static inline void mont_mul_dispatch(u64 r[4],const u64 a[4],const u64 b[4],const mont_ctx *ctx){
  if (ctx == &FP) mont_mul_p256(r,a,b);
  else            mont_mul_asm(r,a,b,ctx);
}
#define mont_mul mont_mul_dispatch
#else
#define mont_mul mont_mul_portable
#endif

static void mont_add(u64 r[4],const u64 a[4],const u64 b[4],const u64 m[4]){
  u128 c=0; int i; u64 t[4];
  for(i=0;i<4;i++){ u128 s=(u128)a[i]+b[i]+c; t[i]=(u64)s; c=s>>64; }
  u64 tmp[4]; u64 borrow=bn_sub(tmp,t,m);
  u64 ge=(c!=0)|(borrow==0);
  for(i=0;i<4;i++)r[i]=ge?tmp[i]:t[i];
}
static void mont_sub(u64 r[4],const u64 a[4],const u64 b[4],const u64 m[4]){
  u64 t[4]; u64 borrow=bn_sub(t,a,b);
  bn_cadd(t,m,borrow);
  for(int i=0;i<4;i++)r[i]=t[i];
}
/* Squaring uses the CIOS multiply: its interleaved reduction gives higher
   throughput than a separate SOS symmetric squarer on this core. */
static void mont_sqr(u64 r[4],const u64 a[4],const mont_ctx *ctx){ mont_mul(r,a,a,ctx); }

/* n0 = -m^-1 mod 2^64 via Newton iteration. */
static u64 compute_n0(u64 m0){
  u64 inv=m0;           /* inv = m0^-1 mod 2^... doubling */
  inv*=2-m0*inv; inv*=2-m0*inv; inv*=2-m0*inv; inv*=2-m0*inv; inv*=2-m0*inv;
  return (u64)(0-inv);
}
/* Compute R^2 mod m by repeated doubling of R mod m. R=2^256. */
static void compute_rr(u64 rr[4],const u64 m[4]){
  /* start with R mod m = 2^256 mod m. Compute via (2^256 - m*floor) but
     simpler: begin t = (2^256 mod m) by subtracting m from 2^256.
     We build R mod m by: t = -m mod 2^256 if m<2^256 (which holds), i.e.
     t = 2^256 - m. */
  u64 t[4]; u128 br=0; int i;
  for(i=0;i<4;i++){ u128 x=(u128)0-m[i]-br; t[i]=(u64)x; br=(x>>64)&1; } /* t = 2^256 - m = R mod m */
  /* Now double t 256 times mod m to get R^2 mod m = R*R mod m. */
  for(i=0;i<256;i++){
    u64 c=0,k; u128 s; u64 d[4];
    for(k=0;k<4;k++){ s=((u128)t[k]<<1)|c; d[k]=(u64)s; c=(u64)(s>>64); }
    /* reduce: if c or d>=m subtract m */
    u64 tmp[4]; u64 borrow=bn_sub(tmp,d,m); u64 ge=(c!=0)|(borrow==0);
    for(k=0;k<4;k++)t[k]=ge?tmp[k]:d[k];
  }
  for(i=0;i<4;i++)rr[i]=t[i];
}

static void ctx_init(mont_ctx *ctx,const u64 m[4]){
  int i; for(i=0;i<4;i++)ctx->m[i]=m[i];
  ctx->n0=compute_n0(m[0]);
  compute_rr(ctx->rr,m);
}
static void to_mont(u64 r[4],const u64 a[4],const mont_ctx *ctx){ mont_mul(r,a,ctx->rr,ctx); }
static void from_mont(u64 r[4],const u64 a[4],const mont_ctx *ctx){ u64 one[4]={1,0,0,0}; mont_mul(r,a,one,ctx); }

/* Modular inverse via Fermat: a^(m-2). Works for prime m. In Montgomery.
   Superseded in production by fp_inv (mod p) and scn_inv (mod n); retained
   as the oracle those are checked against. */
#ifdef P256_SELFTEST
static void mont_inv(u64 r[4],const u64 a[4],const mont_ctx *ctx,const u64 m[4]){
  /* exponent = m-2 */
  u64 e[4]; u64 two[4]={2,0,0,0}; bn_sub(e,m,two);
  u64 base[4],acc[4]; int i,bit;
  for(i=0;i<4;i++)base[i]=a[i];
  /* acc = 1 in Montgomery = R mod m = rr * 1 * R^-1... just to_mont(1) */
  { u64 one[4]={1,0,0,0}; to_mont(acc,one,ctx); }
  for(i=255;i>=0;i--){
    mont_sqr(acc,acc,ctx);
    bit=(e[i>>6]>>(i&63))&1;
    if(bit) mont_mul(acc,acc,base,ctx);
  }
  for(i=0;i<4;i++)r[i]=acc[i];
}
#endif

static void bytes_to_bn(u64 a[4],const unsigned char s[32]){
  int i; for(i=0;i<4;i++){ u64 v=0;int j; for(j=0;j<8;j++)v=(v<<8)|s[i*8+j]; a[3-i]=v; }
}
static void bn_to_bytes(unsigned char s[32],const u64 a[4]){
  int i,j; for(i=0;i<4;i++){ u64 v=a[3-i]; for(j=0;j<8;j++)s[i*8+j]=(unsigned char)(v>>(56-8*j)); }
}

/* ---- curve: y^2 = x^3 - 3x + b, Jacobian coords (X,Y,Z) ---- */
/* FP, FN declared above (before the mont_mul dispatch). */
static u64 CURVE_B[4];       /* b in Montgomery (mod p) */
static u64 GX[4],GY[4];      /* base point in Montgomery */
static int inited=0;

static void p256_init(void){
  static const unsigned char bb[32]={0x5a,0xc6,0x35,0xd8,0xaa,0x3a,0x93,0xe7,0xb3,0xeb,0xbd,0x55,0x76,0x98,0x86,0xbc,0x65,0x1d,0x06,0xb0,0xcc,0x53,0xb0,0xf6,0x3b,0xce,0x3c,0x3e,0x27,0xd2,0x60,0x4b};
  static const unsigned char gx[32]={0x6b,0x17,0xd1,0xf2,0xe1,0x2c,0x42,0x47,0xf8,0xbc,0xe6,0xe5,0x63,0xa4,0x40,0xf2,0x77,0x03,0x7d,0x81,0x2d,0xeb,0x33,0xa0,0xf4,0xa1,0x39,0x45,0xd8,0x98,0xc2,0x96};
  static const unsigned char gy[32]={0x4f,0xe3,0x42,0xe2,0xfe,0x1a,0x7f,0x9b,0x8e,0xe7,0xeb,0x4a,0x7c,0x0f,0x9e,0x16,0x2b,0xce,0x33,0x57,0x6b,0x31,0x5e,0xce,0xcb,0xb6,0x40,0x68,0x37,0xbf,0x51,0xf5};
  u64 t[4];
  ctx_init(&FP,P); ctx_init(&FN,N);
  bytes_to_bn(t,bb); to_mont(CURVE_B,t,&FP);
  bytes_to_bn(t,gx); to_mont(GX,t,&FP);
  bytes_to_bn(t,gy); to_mont(GY,t,&FP);
  inited=1;
}

typedef struct { u64 X[4],Y[4],Z[4]; } jac;

/* Fixed-base windowing table for k*G. comb_win[i][d] = d * 2^(4i) * G in
   affine (Z = mont(1)), for nibble position i (0..63) and digit d (1..15).
   Then k*G = sum_i comb_win[i][digit_i]: 64 additions and NO doublings (the
   doublings are baked into the precomputed table). ~98 KiB, built once. */
static jac comb_win[64][16];
static int comb_inited = 0;

static int fp_iszero(const u64 a[4]){ return (a[0]|a[1]|a[2]|a[3])==0; }
static void fp_cmov(u64 r[4],const u64 a[4],u64 b){ u64 mask=0-b; int i; for(i=0;i<4;i++)r[i]^=mask&(r[i]^a[i]); }

/* Field inverse mod p via a p-2 addition chain (~13 mults + 255 squarings),
   replacing the generic Fermat mont_inv (~128 mults + 256 squarings) for the
   field prime. p = 2^256-2^224+2^192+2^96-1, so p-2 (MSB->LSB) is
   [32 ones][31 zeros][1][96 zeros][94 ones][0][1]; the one-runs assemble from
   (2^k-1)-ones blocks x_k. Montgomery domain. Bit-exact with mont_inv(.,&FP).*/
static void fp_sqrn(u64 r[4],const u64 a[4],int n){
  int i; u64 t[4]; for(i=0;i<4;i++)t[i]=a[i];
  while(n-->0) mont_sqr(t,t,&FP);
  for(i=0;i<4;i++)r[i]=t[i];
}
static void fp_inv(u64 r[4],const u64 a[4]){
  u64 x1[4],x2[4],x4[4],x6[4],x8[4],x14[4],x16[4],x30[4],x32[4],t[4];
  int i;
  for(i=0;i<4;i++)x1[i]=a[i];
  fp_sqrn(t,x1,1);  mont_mul(x2,t,x1,&FP);    /* 2^2-1  */
  fp_sqrn(t,x2,2);  mont_mul(x4,t,x2,&FP);    /* 2^4-1  */
  fp_sqrn(t,x4,2);  mont_mul(x6,t,x2,&FP);    /* 2^6-1  = 4+2 */
  fp_sqrn(t,x4,4);  mont_mul(x8,t,x4,&FP);    /* 2^8-1  */
  fp_sqrn(t,x8,6);  mont_mul(x14,t,x6,&FP);   /* 2^14-1 = 8+6 */
  fp_sqrn(t,x8,8);  mont_mul(x16,t,x8,&FP);   /* 2^16-1 */
  fp_sqrn(t,x16,14);mont_mul(x30,t,x14,&FP);  /* 2^30-1 = 16+14 */
  fp_sqrn(t,x16,16);mont_mul(x32,t,x16,&FP);  /* 2^32-1 */
  for(i=0;i<4;i++)t[i]=x32[i];                /* top 32 ones */
  fp_sqrn(t,t,31);                            /* 31 zeros (bits 223..193) */
  fp_sqrn(t,t,1);  mont_mul(t,t,x1,&FP);      /* bit 192 = 1 */
  fp_sqrn(t,t,96);                            /* 96 zeros (bits 191..96) */
  fp_sqrn(t,t,32); mont_mul(t,t,x32,&FP);     /* 94-ones run = 32 +      */
  fp_sqrn(t,t,32); mont_mul(t,t,x32,&FP);     /*   32 +                  */
  fp_sqrn(t,t,30); mont_mul(t,t,x30,&FP);     /*   30 (reusing x32/x30)  */
  fp_sqrn(t,t,1);                             /* bit 1 = 0 */
  fp_sqrn(t,t,1);  mont_mul(t,t,x1,&FP);      /* bit 0 = 1 */
  for(i=0;i<4;i++)r[i]=t[i];
}

/* Scalar inverse mod n via 4-bit windowed exponentiation of the fixed public
   exponent n-2. The group order has no exploitable structure for a short
   addition chain, but windowing still cuts mults ~128 -> 79 vs Fermat. The
   window/nibble pattern comes from n-2 (public), not the base, so this is
   constant-time in the secret scalar. Montgomery domain. Bit-exact with
   mont_inv(.,&FN). */
static void scn_inv(u64 r[4],const u64 a[4]){
  u64 e[4],two[4]={2,0,0,0}, pw[16][4], acc[4]; int w,i,j;
  bn_sub(e,N,two);
  { u64 one[4]={1,0,0,0}; to_mont(pw[0],one,&FN); }   /* pw[i] = a^i */
  for(j=0;j<4;j++)pw[1][j]=a[j];
  for(i=2;i<16;i++) mont_mul(pw[i],pw[i-1],a,&FN);
  for(j=0;j<4;j++)acc[j]=pw[0][j];                    /* acc = 1 */
  for(w=63;w>=0;w--){
    int shift=w*4; unsigned nib=(e[shift>>6]>>(shift&63))&0xF;
    mont_sqr(acc,acc,&FN); mont_sqr(acc,acc,&FN);
    mont_sqr(acc,acc,&FN); mont_sqr(acc,acc,&FN);
    mont_mul(acc,acc,pw[nib],&FN);                    /* nib=0 -> * mont(1) */
  }
  for(j=0;j<4;j++)r[j]=acc[j];
}

static void jac_double(jac *r,const jac *p){
  u64 YY[4],ZZ[4],S[4],M[4],X3[4],Y3[4],Z3[4],t[4],Y4[4];
  int i;
  u64 xm[4],xp[4],prod[4];
  if(fp_iszero(p->Z)){ *r=*p; return; }
  /* Ops are ordered so independent field multiplies sit adjacent (the "pair"
     comments): the out-of-order core then overlaps them, running the
     doubling nearer field-mul throughput than latency (~1.2x). */
  mont_sqr(YY,p->Y,&FP);      mont_sqr(ZZ,p->Z,&FP);          /* pair 1 */
  mont_sub(xm,p->X,ZZ,FP.m);  mont_add(xp,p->X,ZZ,FP.m);
  mont_mul(S,p->X,YY,&FP);    mont_mul(prod,xm,xp,&FP);        /* pair 2: S=X*YY, prod=(X-ZZ)(X+ZZ) */
  mont_add(S,S,S,FP.m); mont_add(S,S,S,FP.m);                 /* S = 4*X*Y^2 */
  mont_add(M,prod,prod,FP.m); mont_add(M,M,prod,FP.m);        /* M = 3*prod */
  mont_sqr(X3,M,&FP);         mont_sqr(Y4,YY,&FP);            /* pair 3: M^2, Y^4 */
  mont_add(Y4,Y4,Y4,FP.m); mont_add(Y4,Y4,Y4,FP.m); mont_add(Y4,Y4,Y4,FP.m); /* 8*Y^4 */
  mont_sub(X3,X3,S,FP.m); mont_sub(X3,X3,S,FP.m);             /* X3 = M^2 - 2S */
  mont_sub(t,S,X3,FP.m);
  mont_mul(t,M,t,&FP);        mont_mul(Z3,p->Y,p->Z,&FP);     /* pair 4: M*(S-X3), Y*Z */
  mont_sub(Y3,t,Y4,FP.m);                                     /* Y3 = M*(S-X3) - 8*Y^4 */
  mont_add(Z3,Z3,Z3,FP.m);                                    /* Z3 = 2*Y*Z */
  for(i=0;i<4;i++){ r->X[i]=X3[i]; r->Y[i]=Y3[i]; r->Z[i]=Z3[i]; }
}

static void jac_add(jac *r,const jac *p,const jac *q){
  /* If p is identity (Z=0), return q; if q identity, return p. */
  u64 Z1Z1[4],Z2Z2[4],U1[4],U2[4],S1[4],S2[4],H[4],Rr[4],HH[4],HHH[4],t[4],t2[4],tt[4],X3[4],ZZ[4];
  int i;
  int pz=fp_iszero(p->Z), qz=fp_iszero(q->Z);
  if(pz){ *r=*q; return; }
  if(qz){ *r=*p; return; }
  /* independent multiplies grouped into pairs for OoO overlap */
  mont_sqr(Z1Z1,p->Z,&FP);    mont_sqr(Z2Z2,q->Z,&FP);       /* pair */
  mont_mul(U1,p->X,Z2Z2,&FP); mont_mul(U2,q->X,Z1Z1,&FP);    /* pair */
  mont_mul(S1,p->Y,q->Z,&FP); mont_mul(S2,q->Y,p->Z,&FP);    /* pair */
  mont_mul(S1,S1,Z2Z2,&FP);   mont_mul(S2,S2,Z1Z1,&FP);      /* pair */
  mont_sub(H,U2,U1,FP.m);
  mont_sub(Rr,S2,S1,FP.m);
  if(fp_iszero(H)){
    if(fp_iszero(Rr)){ jac_double(r,p); return; }
    /* opposite points -> identity */
    for(i=0;i<4;i++){ r->X[i]=0;r->Y[i]=0;r->Z[i]=0;} r->X[0]=1;r->Y[0]=1; return;
  }
  mont_sqr(HH,H,&FP);         mont_sqr(X3,Rr,&FP);           /* pair: H^2, R^2 */
  mont_mul(HHH,HH,H,&FP);     mont_mul(t,U1,HH,&FP);         /* pair: HH*H, U1*HH */
  mont_sub(X3,X3,HHH,FP.m);
  mont_sub(X3,X3,t,FP.m); mont_sub(X3,X3,t,FP.m);            /* X3 = R^2 - HHH - 2*U1*HH */
  mont_mul(ZZ,p->Z,q->Z,&FP); mont_mul(tt,S1,HHH,&FP);       /* pair: Z1*Z2, S1*HHH */
  mont_sub(t2,t,X3,FP.m); mont_mul(t2,Rr,t2,&FP);
  mont_sub(r->Y,t2,tt,FP.m);
  mont_mul(r->Z,ZZ,H,&FP);
  for(i=0;i<4;i++) r->X[i]=X3[i];
}

/* Mixed Jacobian + affine addition: q must be affine (q->Z == mont(1)).
   Identical result to jac_add for such q, but skips the ~7 field
   multiplications by 1 that a full Jacobian add would waste on Z2. Every
   scalar-mult inner loop passes an affine base point, so this is what they
   use. */
static void mixed_add(jac *r,const jac *p,const jac *q){
  u64 Z1Z1[4],U2[4],S2[4],H[4],Rr[4],HH[4],HHH[4],t[4],t2[4],tt[4],X3[4],Z3[4];
  int i;
  if(fp_iszero(p->Z)){ *r=*q; return; }         /* p identity -> q (already affine) */
  /* Ordered so independent multiplies are adjacent (pair comments); the
     out-of-order core overlaps them (~field-mul throughput not latency). */
  mont_sqr(Z1Z1,p->Z,&FP);    mont_mul(S2,q->Y,p->Z,&FP);   /* pair 1: Z1^2, Y2*Z1 */
  mont_mul(U2,q->X,Z1Z1,&FP); mont_mul(S2,S2,Z1Z1,&FP);     /* pair 2 */
  mont_sub(H,U2,p->X,FP.m);                     /* H  = U2 - X1 */
  mont_sub(Rr,S2,p->Y,FP.m);                    /* R  = S2 - Y1 */
  if(fp_iszero(H)){
    if(fp_iszero(Rr)){ jac_double(r,p); return; }
    for(i=0;i<4;i++){ r->X[i]=0;r->Y[i]=0;r->Z[i]=0;} r->X[0]=1;r->Y[0]=1; return;
  }
  mont_sqr(HH,H,&FP);         mont_sqr(X3,Rr,&FP);          /* pair 3: H^2, R^2 */
  mont_mul(HHH,HH,H,&FP);     mont_mul(t,p->X,HH,&FP);      /* pair 4: HH*H, X1*HH */
  mont_sub(X3,X3,HHH,FP.m);
  mont_sub(X3,X3,t,FP.m); mont_sub(X3,X3,t,FP.m);           /* X3 = R^2 - HHH - 2*X1*HH */
  mont_mul(tt,p->Y,HHH,&FP);  mont_mul(Z3,p->Z,H,&FP);      /* pair 5: Y1*HHH, Z1*H */
  mont_sub(t2,t,X3,FP.m); mont_mul(t2,Rr,t2,&FP);
  mont_sub(t2,t2,tt,FP.m);                                  /* Y3 = R*(X1*HH - X3) - Y1*HHH */
  for(i=0;i<4;i++){ r->X[i]=X3[i]; r->Y[i]=t2[i]; r->Z[i]=Z3[i]; }
}

#ifdef P256_SELFTEST
/* Reference bit-by-bit double-and-add: 256 doublings + 256 masked mixed-adds.
   Superseded in production by the width-4 window below; retained as the
   correctness oracle the selftest compares against. */
static void jac_scalarmult(jac *r,const u64 k[4],const jac *p){
  jac acc; int i; int bit;
  for(i=0;i<4;i++){acc.X[i]=0;acc.Y[i]=0;acc.Z[i]=0;} acc.X[0]=1;acc.Y[0]=1; /* identity */
  for(i=255;i>=0;i--){
    jac t,s;
    jac_double(&t,&acc);
    mixed_add(&s,&t,p);
    bit=(k[i>>6]>>(i&63))&1;
    acc=t; fp_cmov(acc.X,s.X,bit);fp_cmov(acc.Y,s.Y,bit);fp_cmov(acc.Z,s.Z,bit);
  }
  *r=acc;
}
#endif

/* Batch Jacobian->affine (Z = mont(1)) for pts[0..n-1] using Montgomery's
   trick: one field inversion for the whole array instead of one per point.
   All Z must be nonzero (true for small multiples i*P of a curve point). */
static void batch_affine(jac *pts,int n){
  u64 prefix[16][4], acc[4], inv[4], zi[4], zi2[4], zi3[4];
  u64 one[4]={1,0,0,0}, montone[4]; int i,j;
  to_mont(montone,one,&FP);
  for(j=0;j<4;j++){ acc[j]=pts[0].Z[j]; prefix[0][j]=pts[0].Z[j]; }
  for(i=1;i<n;i++){ mont_mul(acc,acc,pts[i].Z,&FP); for(j=0;j<4;j++) prefix[i][j]=acc[j]; }
  fp_inv(inv,acc);                               /* inv = (prod Z_i)^-1 */
  for(i=n-1;i>=0;i--){
    if(i>0) mont_mul(zi,inv,prefix[i-1],&FP);    /* zi = Z_i^-1 */
    else    for(j=0;j<4;j++) zi[j]=inv[j];
    mont_mul(inv,inv,pts[i].Z,&FP);              /* strip Z_i for next round */
    mont_sqr(zi2,zi,&FP); mont_mul(zi3,zi2,zi,&FP);
    mont_mul(pts[i].X,pts[i].X,zi2,&FP);
    mont_mul(pts[i].Y,pts[i].Y,zi3,&FP);
    for(j=0;j<4;j++) pts[i].Z[j]=montone[j];
  }
}

/* Variable-base k*P via a width-4 fixed window. Builds T[i]=i*P for
   i=1..15, batch-normalizes to affine, then runs 64 windows of 4 doublings
   plus one constant-time-selected masked add. Bit-exact with jac_scalarmult.
   The point P is public in every caller (peer key / signature term); only
   the per-window digit is secret, so it is handled constant-time (cmov scan
   over the table + mask of the zero digit), mirroring the comb. */
static void jac_scalarmult_win(jac *r,const u64 k[4],const jac *p){
  jac T[16], acc, sel, tmp; int i,w,idx;
  for(i=0;i<4;i++){T[0].X[i]=0;T[0].Y[i]=0;T[0].Z[i]=0;} T[0].X[0]=1;T[0].Y[0]=1; /* O */
  T[1]=*p;
  jac_double(&T[2],p);
  for(i=3;i<16;i++) jac_add(&T[i],&T[i-1],p);    /* branchy build: P is public */
  batch_affine(&T[1],15);                         /* T[1..15] -> affine */
  for(i=0;i<4;i++){acc.X[i]=0;acc.Y[i]=0;acc.Z[i]=0;} acc.X[0]=1;acc.Y[0]=1; /* identity */
  for(w=63;w>=0;w--){
    int shift=w*4;                                /* multiple of 4 -> digit within one limb */
    u64 digit=(k[shift>>6]>>(shift&63))&0xF;
    jac_double(&acc,&acc); jac_double(&acc,&acc);
    jac_double(&acc,&acc); jac_double(&acc,&acc);
    sel=T[1];
    for(idx=1;idx<16;idx++){ u64 m=(idx==(int)digit); fp_cmov(sel.X,T[idx].X,m);fp_cmov(sel.Y,T[idx].Y,m);fp_cmov(sel.Z,T[idx].Z,m); }
    mixed_add(&tmp,&acc,&sel);
    { u64 m=(digit!=0); fp_cmov(acc.X,tmp.X,m);fp_cmov(acc.Y,tmp.Y,m);fp_cmov(acc.Z,tmp.Z,m); }
  }
  *r=acc;
}

/* Convert Jacobian to affine bytes (x,y). Returns 0 if point at infinity. */
static int jac_to_affine(unsigned char x[32],unsigned char y[32],const jac *p){
  u64 zinv[4],zinv2[4],zinv3[4],xa[4],ya[4],tmp[4];
  if(fp_iszero(p->Z)) return 0;
  fp_inv(zinv,p->Z);
  mont_sqr(zinv2,zinv,&FP); mont_mul(zinv3,zinv2,zinv,&FP);
  mont_mul(xa,p->X,zinv2,&FP); mont_mul(ya,p->Y,zinv3,&FP);
  from_mont(tmp,xa,&FP); bn_to_bytes(x,tmp);
  from_mont(tmp,ya,&FP); bn_to_bytes(y,tmp);
  return 1;
}

static void base_point(jac *B){
  int i; for(i=0;i<4;i++){B->X[i]=GX[i];B->Y[i]=GY[i];B->Z[i]=0;}
  { u64 one[4]={1,0,0,0}; to_mont(B->Z,one,&FP); }
}

/* Jacobian -> affine (Montgomery coords, Z set to mont(1)). Retained for the
   offline selftest harness (comb_init now batch-normalizes instead). */
static void __attribute__((unused)) affine_normalize(jac *out,const jac *p){
  u64 zinv[4],zinv2[4],zinv3[4];
  fp_inv(zinv,p->Z);
  mont_sqr(zinv2,zinv,&FP); mont_mul(zinv3,zinv2,zinv,&FP);
  mont_mul(out->X,p->X,zinv2,&FP); mont_mul(out->Y,p->Y,zinv3,&FP);
  { u64 one[4]={1,0,0,0}; to_mont(out->Z,one,&FP); }
}

/* Build the fixed-base windowing table (one-time, lazy). For each nibble
   position i, comb_win[i][d] = d * 2^(4i) * G. The 15 multiples per position
   are normalized to affine with a single field inversion (Montgomery's
   trick), so init costs 64 inversions rather than 960. Branchy point ops --
   the base point is public. */
static void comb_init(void){
  jac P, mult[15]; int i,d,k;
  base_point(&P);                                    /* P = 2^(4i)*G, starts at G */
  for(i=0;i<64;i++){
    mult[0]=P;
    for(d=1;d<15;d++) jac_add(&mult[d],&mult[d-1],&P);   /* (d+1)*P */
    batch_affine(mult,15);                              /* one inversion for 15 pts */
    for(d=0;d<15;d++) comb_win[i][d+1]=mult[d];          /* comb_win[i][1..15] */
    for(k=0;k<4;k++){comb_win[i][0].X[k]=0;comb_win[i][0].Y[k]=0;comb_win[i][0].Z[k]=0;}
    comb_win[i][0].X[0]=1; comb_win[i][0].Y[0]=1;        /* O (digit 0, masked out) */
    if(i<63){ jac_double(&P,&P); jac_double(&P,&P); jac_double(&P,&P); jac_double(&P,&P); } /* P *= 2^4 */
  }
  comb_inited=1;
}

/* Fixed-base k*G via 4-bit windowing: k = sum_i d_i*2^(4i), so
   k*G = sum_i comb_win[i][d_i] -- 64 constant-time-selected additions, no
   doublings. Table lookup scans all entries with cmov (no secret-dependent
   memory access); the add of the zero digit is masked out. */
static void jac_scalarmult_base(jac *r,const u64 k[4]){
  jac acc, sel, tmp; int i, idx;
  if(!comb_inited) comb_init();
  for(i=0;i<4;i++){acc.X[i]=0;acc.Y[i]=0;acc.Z[i]=0;} acc.X[0]=1;acc.Y[0]=1; /* identity */
  for(i=0;i<64;i++){
    int sh=(4*i)&63;
    u64 d=(k[(4*i)>>6]>>sh)&0xF;
    sel=comb_win[i][1];
    for(idx=1;idx<16;idx++){ u64 m=(idx==(int)d); fp_cmov(sel.X,comb_win[i][idx].X,m);fp_cmov(sel.Y,comb_win[i][idx].Y,m);fp_cmov(sel.Z,comb_win[i][idx].Z,m); }
    mixed_add(&tmp,&acc,&sel);
    { u64 m=(d!=0); fp_cmov(acc.X,tmp.X,m);fp_cmov(acc.Y,tmp.Y,m);fp_cmov(acc.Z,tmp.Z,m); }
  }
  *r=acc;
}

/* ---- public API ---- */

/* ECDH: out = scalar * point (65-byte uncompressed point 0x04||x||y in, 32-byte x out). */
int rktcrypto_p256_ecdh(unsigned char out[32],const unsigned char scalar[32],const unsigned char point65[65]){
  jac P_,R; u64 k[4],px[4],py[4]; unsigned char xa[32],ya[32];
  if(!inited)p256_init();
  if(point65[0]!=4) return 0;
  bytes_to_bn(k,scalar);
  bytes_to_bn(px,point65+1); bytes_to_bn(py,point65+33);
  to_mont(P_.X,px,&FP); to_mont(P_.Y,py,&FP);
  { u64 one[4]={1,0,0,0}; to_mont(P_.Z,one,&FP); }
  jac_scalarmult_win(&R,k,&P_);
  if(!jac_to_affine(xa,ya,&R)) return 0;
  memcpy(out,xa,32);
  return 1;
}

/* Public key (65-byte uncompressed) from a 32-byte private scalar. */
int rktcrypto_p256_pubkey(unsigned char out65[65],const unsigned char priv[32]){
  jac R; u64 k[4]; unsigned char xa[32],ya[32];
  if(!inited)p256_init();
  bytes_to_bn(k,priv);
  jac_scalarmult_base(&R,k);
  if(!jac_to_affine(xa,ya,&R)) return 0;
  out65[0]=4; memcpy(out65+1,xa,32); memcpy(out65+33,ya,32);
  return 1;
}

static void sha256(const unsigned char *m,intptr_t len,unsigned char out[32]){
  rktcrypto_digest_oneshot(RKTCRYPTO_SHA256,m,0,len,out,0,32);
}

/* ECDSA sign: sig = r||s (64 bytes). Random nonce via rejection sampling. */
int rktcrypto_p256_ecdsa_sign(unsigned char sig[64],const unsigned char *msg,intptr_t msglen,const unsigned char priv[32]){
  unsigned char digest[32]; u64 z[4],d[4],knum[4],r_[4],s_[4],tmp[4];
  jac R; int tries;
  if(!inited)p256_init();
  sha256(msg,msglen,digest);
  bytes_to_bn(z,digest);
  if(bn_geq(z,N)) bn_sub(z,z,N);
  bytes_to_bn(d,priv);
  for(tries=0;tries<256;tries++){
    unsigned char kb[32]; u64 kmont[4],dmont[4],zmont[4],rmont[4],kinv[4];
    unsigned char xa[32],ya[32]; u64 rx[4];
    if(!rktcrypto_random_bytes(kb,0,32)) return 0;
    bytes_to_bn(knum,kb);
    if(fp_iszero(knum)||bn_geq(knum,N)) continue;
    jac_scalarmult_base(&R,knum);
    if(!jac_to_affine(xa,ya,&R)) continue;
    bytes_to_bn(rx,xa);
    if(bn_geq(rx,N)) bn_sub(rx,rx,N);
    if(fp_iszero(rx)) continue;
    for(int i=0;i<4;i++)r_[i]=rx[i];
    /* s = k^-1 (z + r*d) mod n */
    to_mont(kmont,knum,&FN); to_mont(dmont,d,&FN); to_mont(zmont,z,&FN); to_mont(rmont,r_,&FN);
    mont_mul(tmp,rmont,dmont,&FN);           /* r*d */
    mont_add(tmp,tmp,zmont,FN.m);            /* z + r*d */
    scn_inv(kinv,kmont);                     /* k^-1 */
    mont_mul(s_,kinv,tmp,&FN);
    from_mont(s_,s_,&FN);
    if(fp_iszero(s_)) continue;
    bn_to_bytes(sig,r_); bn_to_bytes(sig+32,s_);
    return 1;
  }
  return 0;
}

int rktcrypto_p256_ecdsa_verify(const unsigned char sig[64],const unsigned char *msg,intptr_t msglen,const unsigned char pub65[65]){
  unsigned char digest[32]; u64 z[4],r_[4],s_[4],w[4],u1[4],u2[4];
  u64 smont[4],winv[4],zmont[4],rmont[4],u1m[4],u2m[4];
  jac Pub,A1,A2,R; u64 px[4],py[4]; unsigned char xa[32],ya[32]; u64 rx[4];
  if(!inited)p256_init();
  if(pub65[0]!=4) return 0;
  bytes_to_bn(r_,sig); bytes_to_bn(s_,sig+32);
  if(fp_iszero(r_)||fp_iszero(s_)||bn_geq(r_,N)||bn_geq(s_,N)) return 0;
  sha256(msg,msglen,digest);
  bytes_to_bn(z,digest);
  if(bn_geq(z,N)) bn_sub(z,z,N);
  /* w = s^-1 mod n; u1 = z*w; u2 = r*w */
  to_mont(smont,s_,&FN); scn_inv(winv,smont);
  to_mont(zmont,z,&FN); to_mont(rmont,r_,&FN);
  mont_mul(u1m,zmont,winv,&FN); mont_mul(u2m,rmont,winv,&FN);
  from_mont(u1,u1m,&FN); from_mont(u2,u2m,&FN); (void)w;
  /* R = u1*G + u2*Pub */
  bytes_to_bn(px,pub65+1); bytes_to_bn(py,pub65+33);
  to_mont(Pub.X,px,&FP); to_mont(Pub.Y,py,&FP);
  { u64 one[4]={1,0,0,0}; to_mont(Pub.Z,one,&FP); }
  jac_scalarmult_base(&A1,u1);
  jac_scalarmult_win(&A2,u2,&Pub);
  jac_add(&R,&A1,&A2);
  if(!jac_to_affine(xa,ya,&R)) return 0;
  bytes_to_bn(rx,xa);
  if(bn_geq(rx,N)) bn_sub(rx,rx,N);
  /* valid iff rx == r */
  { int i,diff=0; for(i=0;i<4;i++) diff|=(rx[i]!=r_[i]); return diff==0; }
}
