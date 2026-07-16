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

/* Montgomery multiply: r = a*b*R^-1 mod m. */
static void mont_mul(u64 r[4],const u64 a[4],const u64 b[4],const mont_ctx *ctx){
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

/* Modular inverse via Fermat: a^(m-2). Works for prime m. In Montgomery. */
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

static void bytes_to_bn(u64 a[4],const unsigned char s[32]){
  int i; for(i=0;i<4;i++){ u64 v=0;int j; for(j=0;j<8;j++)v=(v<<8)|s[i*8+j]; a[3-i]=v; }
}
static void bn_to_bytes(unsigned char s[32],const u64 a[4]){
  int i,j; for(i=0;i<4;i++){ u64 v=a[3-i]; for(j=0;j<8;j++)s[i*8+j]=(unsigned char)(v>>(56-8*j)); }
}

/* ---- curve: y^2 = x^3 - 3x + b, Jacobian coords (X,Y,Z) ---- */
static mont_ctx FP, FN;
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

/* Fixed-base comb table for k*G: comb_tbl[I] = sum over set bits i of I
   of 2^(64i)*G, in affine (Z = mont(1)). Built once, lazily. */
static jac comb_tbl[16];
static int comb_inited = 0;

static int fp_iszero(const u64 a[4]){ return (a[0]|a[1]|a[2]|a[3])==0; }
static void fp_cmov(u64 r[4],const u64 a[4],u64 b){ u64 mask=0-b; int i; for(i=0;i<4;i++)r[i]^=mask&(r[i]^a[i]); }

static void jac_double(jac *r,const jac *p){
  u64 YY[4],ZZ[4],S[4],M[4],X3[4],Y3[4],Z3[4],t[4],Y4[4];
  int i;
  if(fp_iszero(p->Z)){ *r=*p; return; }
  mont_sqr(YY,p->Y,&FP);
  mont_sqr(ZZ,p->Z,&FP);
  /* S = 4*X*Y^2 */
  mont_mul(S,p->X,YY,&FP); mont_add(S,S,S,FP.m); mont_add(S,S,S,FP.m);
  /* M = 3*(X-Z^2)*(X+Z^2)  [since a=-3] */
  { u64 xm[4],xp[4],prod[4]; mont_sub(xm,p->X,ZZ,FP.m); mont_add(xp,p->X,ZZ,FP.m); mont_mul(prod,xm,xp,&FP);
    mont_add(M,prod,prod,FP.m); mont_add(M,M,prod,FP.m); }
  /* X3 = M^2 - 2S */
  mont_sqr(X3,M,&FP); mont_sub(X3,X3,S,FP.m); mont_sub(X3,X3,S,FP.m);
  /* Y3 = M*(S - X3) - 8*Y^4 */
  mont_sqr(Y4,YY,&FP); mont_add(Y4,Y4,Y4,FP.m); mont_add(Y4,Y4,Y4,FP.m); mont_add(Y4,Y4,Y4,FP.m);
  mont_sub(t,S,X3,FP.m); mont_mul(t,M,t,&FP); mont_sub(Y3,t,Y4,FP.m);
  /* Z3 = 2*Y*Z */
  mont_mul(Z3,p->Y,p->Z,&FP); mont_add(Z3,Z3,Z3,FP.m);
  for(i=0;i<4;i++){ r->X[i]=X3[i]; r->Y[i]=Y3[i]; r->Z[i]=Z3[i]; }
}

static void jac_add(jac *r,const jac *p,const jac *q){
  /* If p is identity (Z=0), return q; if q identity, return p. */
  u64 Z1Z1[4],Z2Z2[4],U1[4],U2[4],S1[4],S2[4],H[4],Rr[4],HH[4],HHH[4],t[4],t2[4];
  int i;
  int pz=fp_iszero(p->Z), qz=fp_iszero(q->Z);
  if(pz){ *r=*q; return; }
  if(qz){ *r=*p; return; }
  mont_sqr(Z1Z1,p->Z,&FP); mont_sqr(Z2Z2,q->Z,&FP);
  mont_mul(U1,p->X,Z2Z2,&FP); mont_mul(U2,q->X,Z1Z1,&FP);
  mont_mul(S1,p->Y,q->Z,&FP); mont_mul(S1,S1,Z2Z2,&FP);
  mont_mul(S2,q->Y,p->Z,&FP); mont_mul(S2,S2,Z1Z1,&FP);
  mont_sub(H,U2,U1,FP.m);
  mont_sub(Rr,S2,S1,FP.m);
  if(fp_iszero(H)){
    if(fp_iszero(Rr)){ jac_double(r,p); return; }
    /* opposite points -> identity */
    for(i=0;i<4;i++){ r->X[i]=0;r->Y[i]=0;r->Z[i]=0;} r->X[0]=1;r->Y[0]=1; return;
  }
  mont_sqr(HH,H,&FP); mont_mul(HHH,HH,H,&FP);
  mont_mul(t,U1,HH,&FP);         /* U1*HH */
  mont_sqr(r->X,Rr,&FP);
  mont_sub(r->X,r->X,HHH,FP.m);
  mont_sub(r->X,r->X,t,FP.m); mont_sub(r->X,r->X,t,FP.m);   /* X3 = R^2 - HHH - 2*U1*HH */
  mont_sub(t2,t,r->X,FP.m); mont_mul(t2,Rr,t2,&FP);
  mont_mul(t,S1,HHH,&FP);
  mont_sub(r->Y,t2,t,FP.m);
  mont_mul(r->Z,p->Z,q->Z,&FP); mont_mul(r->Z,r->Z,H,&FP);
}

/* Mixed Jacobian + affine addition: q must be affine (q->Z == mont(1)).
   Identical result to jac_add for such q, but skips the ~7 field
   multiplications by 1 that a full Jacobian add would waste on Z2. Every
   jac_scalarmult caller passes an affine base point, so this is what the
   inner loop uses. */
static void mixed_add(jac *r,const jac *p,const jac *q){
  u64 Z1Z1[4],U2[4],S2[4],H[4],Rr[4],HH[4],HHH[4],t[4],t2[4],tt[4];
  int i;
  if(fp_iszero(p->Z)){ *r=*q; return; }         /* p identity -> q (already affine) */
  mont_sqr(Z1Z1,p->Z,&FP);
  mont_mul(U2,q->X,Z1Z1,&FP);
  mont_mul(S2,q->Y,p->Z,&FP); mont_mul(S2,S2,Z1Z1,&FP);
  mont_sub(H,U2,p->X,FP.m);                     /* H  = U2 - X1 */
  mont_sub(Rr,S2,p->Y,FP.m);                    /* R  = S2 - Y1 */
  if(fp_iszero(H)){
    if(fp_iszero(Rr)){ jac_double(r,p); return; }
    for(i=0;i<4;i++){ r->X[i]=0;r->Y[i]=0;r->Z[i]=0;} r->X[0]=1;r->Y[0]=1; return;
  }
  mont_sqr(HH,H,&FP); mont_mul(HHH,HH,H,&FP);
  mont_mul(t,p->X,HH,&FP);                       /* t = X1*HH */
  mont_sqr(r->X,Rr,&FP);
  mont_sub(r->X,r->X,HHH,FP.m);
  mont_sub(r->X,r->X,t,FP.m); mont_sub(r->X,r->X,t,FP.m);   /* X3 = R^2 - HHH - 2*X1*HH */
  mont_sub(t2,t,r->X,FP.m); mont_mul(t2,Rr,t2,&FP);
  mont_mul(tt,p->Y,HHH,&FP);                     /* Y1*HHH */
  mont_sub(r->Y,t2,tt,FP.m);
  mont_mul(r->Z,p->Z,H,&FP);                     /* Z3 = Z1*H */
}

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

/* Convert Jacobian to affine bytes (x,y). Returns 0 if point at infinity. */
static int jac_to_affine(unsigned char x[32],unsigned char y[32],const jac *p){
  u64 zinv[4],zinv2[4],zinv3[4],xa[4],ya[4],tmp[4];
  if(fp_iszero(p->Z)) return 0;
  mont_inv(zinv,p->Z,&FP,FP.m);
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

/* Jacobian -> affine (Montgomery coords, Z set to mont(1)). */
static void affine_normalize(jac *out,const jac *p){
  u64 zinv[4],zinv2[4],zinv3[4];
  mont_inv(zinv,p->Z,&FP,FP.m);
  mont_sqr(zinv2,zinv,&FP); mont_mul(zinv3,zinv2,zinv,&FP);
  mont_mul(out->X,p->X,zinv2,&FP); mont_mul(out->Y,p->Y,zinv3,&FP);
  { u64 one[4]={1,0,0,0}; to_mont(out->Z,one,&FP); }
}

/* Build the width-4 comb table (one-time). comb_tbl[I] = sum_{i:bit i of I}
   2^(64i)*G. Uses branchy point ops -- inputs are the public base point. */
static void comb_init(void){
  jac Pw[4], acc; int I,i,j,first;
  base_point(&Pw[0]);
  for(i=1;i<4;i++){ Pw[i]=Pw[i-1]; for(j=0;j<64;j++) jac_double(&Pw[i],&Pw[i]); }
  for(i=0;i<4;i++){ comb_tbl[0].X[i]=0;comb_tbl[0].Y[i]=0;comb_tbl[0].Z[i]=0; }
  comb_tbl[0].X[0]=1; comb_tbl[0].Y[0]=1;               /* O (unused, kept valid) */
  for(I=1;I<16;I++){
    first=1;
    for(i=0;i<4;i++) if(I&(1<<i)){ if(first){acc=Pw[i];first=0;} else jac_add(&acc,&acc,&Pw[i]); }
    affine_normalize(&comb_tbl[I],&acc);
  }
  comb_inited=1;
}

/* Fixed-base k*G via the width-4 comb: 64 columns, each a doubling plus a
   constant-time-selected table add. Table lookup scans all entries with
   cmov (no secret-dependent memory access); the add of the zero digit is
   masked out. */
static void jac_scalarmult_base(jac *r,const u64 k[4]){
  jac acc, sel, tmp; int j, idx, i;
  if(!comb_inited) comb_init();
  for(i=0;i<4;i++){acc.X[i]=0;acc.Y[i]=0;acc.Z[i]=0;} acc.X[0]=1;acc.Y[0]=1; /* identity */
  for(j=63;j>=0;j--){
    u64 I = ((k[0]>>j)&1) | (((k[1]>>j)&1)<<1) | (((k[2]>>j)&1)<<2) | (((k[3]>>j)&1)<<3);
    jac_double(&acc,&acc);
    sel=comb_tbl[1];
    for(idx=1;idx<16;idx++){ u64 m=(idx==(int)I); fp_cmov(sel.X,comb_tbl[idx].X,m);fp_cmov(sel.Y,comb_tbl[idx].Y,m);fp_cmov(sel.Z,comb_tbl[idx].Z,m); }
    mixed_add(&tmp,&acc,&sel);
    { u64 m=(I!=0); fp_cmov(acc.X,tmp.X,m);fp_cmov(acc.Y,tmp.Y,m);fp_cmov(acc.Z,tmp.Z,m); }
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
  jac_scalarmult(&R,k,&P_);
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
    mont_inv(kinv,kmont,&FN,FN.m);           /* k^-1 */
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
  to_mont(smont,s_,&FN); mont_inv(winv,smont,&FN,FN.m);
  to_mont(zmont,z,&FN); to_mont(rmont,r_,&FN);
  mont_mul(u1m,zmont,winv,&FN); mont_mul(u2m,rmont,winv,&FN);
  from_mont(u1,u1m,&FN); from_mont(u2,u2m,&FN); (void)w;
  /* R = u1*G + u2*Pub */
  bytes_to_bn(px,pub65+1); bytes_to_bn(py,pub65+33);
  to_mont(Pub.X,px,&FP); to_mont(Pub.Y,py,&FP);
  { u64 one[4]={1,0,0,0}; to_mont(Pub.Z,one,&FP); }
  jac_scalarmult_base(&A1,u1);
  jac_scalarmult(&A2,u2,&Pub);
  jac_add(&R,&A1,&A2);
  if(!jac_to_affine(xa,ya,&R)) return 0;
  bytes_to_bn(rx,xa);
  if(bn_geq(rx,N)) bn_sub(rx,rx,N);
  /* valid iff rx == r */
  { int i,diff=0; for(i=0;i<4;i++) diff|=(rx[i]!=r_[i]); return diff==0; }
}
