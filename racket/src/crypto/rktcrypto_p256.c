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

/* __builtin_addcll/__builtin_subcll are Clang builtins that GCC only grew
   in GCC 14, so the distro compilers (Ubuntu 24.04 = 13, EL9 = 11, openEuler
   = 10/12) fail to link them. Route through these wrappers: the builtin when
   the compiler has it, otherwise u128 carry arithmetic that GCC folds into
   the same adc/sbb chains at -O2. */
#if defined(__has_builtin)
# if __has_builtin(__builtin_addcll) && __has_builtin(__builtin_subcll)
#  define P256_HAVE_CARRY_BUILTINS 1
# endif
#endif

#ifdef P256_HAVE_CARRY_BUILTINS
# define p256_addc(a,b,ci,co) __builtin_addcll((a),(b),(ci),(co))
# define p256_subb(a,b,bi,bo) __builtin_subcll((a),(b),(bi),(bo))
#else
static inline unsigned long long p256_addc(unsigned long long a, unsigned long long b,
                                           unsigned long long ci, unsigned long long *co) {
  u128 s = (u128)a + b + ci;
  *co = (unsigned long long)(s >> 64);
  return (unsigned long long)s;
}
static inline unsigned long long p256_subb(unsigned long long a, unsigned long long b,
                                           unsigned long long bi, unsigned long long *bo) {
  u128 d = (u128)a - b - bi;
  *bo = (unsigned long long)((d >> 64) & 1);
  return (unsigned long long)d;
}
#endif

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
extern void mont_sqrn_asm(u64 r[4],const u64 a[4],u64 rep,const mont_ctx *ctx);
extern void mont_sqrn_p256(u64 r[4],const u64 a[4],u64 rep);
#define HAVE_MONT_SQRN_ASM 1
static inline void mont_mul_dispatch(u64 r[4],const u64 a[4],const u64 b[4],const mont_ctx *ctx){
  if (ctx == &FP) mont_mul_p256(r,a,b);
  else            mont_mul_asm(r,a,b,ctx);
}
#define mont_mul mont_mul_dispatch
/* Direct field-prime multiply/square for the hot point arithmetic -- skips
   the ctx dispatch branch (which does not always fold), ~7% faster per
   point op. */
#define fp_mul(r,a,b) mont_mul_p256((r),(a),(b))
#define fp_sqr(r,a)   mont_mul_p256((r),(a),(a))
#else
#define mont_mul mont_mul_portable
#define fp_mul(r,a,b) mont_mul_portable((r),(a),(b),&FP)
#define fp_sqr(r,a)   mont_mul_portable((r),(a),(a),&FP)
#endif

/* Field add/sub mod m, written with carry intrinsics so the compiler emits
   a tight adcs/sbcs + csel chain (~13 instr) rather than the ~45 the u128 +
   bn_sub form produced -- the add/sub sit on the point-op critical path, so
   this directly shortens jac_double/mixed_add. */
static void mont_add(u64 r[4],const u64 a[4],const u64 b[4],const u64 m[4]){
  unsigned long long c,br,t0,t1,t2,t3,s0,s1,s2,s3,ge;
  t0=p256_addc(a[0],b[0],0,&c);  t1=p256_addc(a[1],b[1],c,&c);
  t2=p256_addc(a[2],b[2],c,&c);  t3=p256_addc(a[3],b[3],c,&c);
  s0=p256_subb(t0,m[0],0,&br);   s1=p256_subb(t1,m[1],br,&br);
  s2=p256_subb(t2,m[2],br,&br);  s3=p256_subb(t3,m[3],br,&br);
  ge = c | (br^1);                       /* carry-out OR (t >= m) */
  r[0]=ge?s0:t0; r[1]=ge?s1:t1; r[2]=ge?s2:t2; r[3]=ge?s3:t3;
}
static void mont_sub(u64 r[4],const u64 a[4],const u64 b[4],const u64 m[4]){
  unsigned long long br,c,t0,t1,t2,t3,mask;
  t0=p256_subb(a[0],b[0],0,&br);  t1=p256_subb(a[1],b[1],br,&br);
  t2=p256_subb(a[2],b[2],br,&br); t3=p256_subb(a[3],b[3],br,&br);
  mask=0-br;                             /* all-ones iff a<b */
  r[0]=p256_addc(t0,m[0]&mask,0,&c);  r[1]=p256_addc(t1,m[1]&mask,c,&c);
  r[2]=p256_addc(t2,m[2]&mask,c,&c);  r[3]=p256_addc(t3,m[3]&mask,c,&c);
}
/* Squaring uses the CIOS multiply: its interleaved reduction gives higher
   throughput than a separate SOS symmetric squarer on this core. */
static void __attribute__((unused)) mont_sqr(u64 r[4],const u64 a[4],const mont_ctx *ctx){ mont_mul(r,a,a,ctx); }

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
typedef struct { u64 X[4],Y[4]; } aff;   /* affine point (Z implicitly mont(1)) */

/* Fixed-base signed width-7 comb table for k*G (OpenSSL ecp_nistz256 scheme).
   comb7[i][d] = d * 2^(7i) * G in affine, for window i (0..36) and magnitude
   d (1..64); index 0 is the masked-out digit-zero slot. The scalar is Booth-
   recoded into 37 signed digits in [-64,64], so k*G = sum_i (+/-)comb7[i][|d_i|]:
   37 additions and NO doublings (baked into the table), with the sign applied
   by a constant-time conditional Y-negation. ~150 KiB, built once.
   Signed width-7 (vs the old unsigned width-4) halves the additions 64->37 --
   the additions dominate the base mult ~10:1 over the constant-time table scan
   (measured), so this cuts k*G ~5.1 -> ~3.4 us, helping both ECDSA sign (k*G)
   and verify (u1*G). */
static aff comb7[37][65];
static int comb_inited = 0;

/* OpenSSL width-7 Booth recoding: maps an 8-bit window (7 value bits + 1
   overlap) to a packed (magnitude<<1)|sign, magnitude in [0,64]. Branch-free. */
static unsigned booth_recode_w7(unsigned in){
  unsigned s,d;
  s = ~((in >> 7) - 1);            /* all-ones iff top bit set (negative) */
  d = (1u << 8) - in - 1;          /* 255 - in */
  d = (d & s) | (in & ~s);         /* |value| pre-halving */
  d = (d >> 1) + (d & 1);
  return (d << 1) + (s & 1);
}
/* Width-5 Booth recoding: 6-bit window (5 value bits + 1 overlap) -> packed
   (magnitude<<1)|sign, magnitude in [0,16]. Branch-free. */
static unsigned booth_recode_w5(unsigned in){
  unsigned s,d;
  s = ~((in >> 5) - 1);
  d = (1u << 6) - in - 1;
  d = (d & s) | (in & ~s);
  d = (d >> 1) + (d & 1);
  return (d << 1) + (s & 1);
}

static int fp_iszero(const u64 a[4]){ return (a[0]|a[1]|a[2]|a[3])==0; }
static void fp_cmov(u64 r[4],const u64 a[4],u64 b){ u64 mask=0-b; int i; for(i=0;i<4;i++)r[i]^=mask&(r[i]^a[i]); }

/* Field inverse mod p via a p-2 addition chain (~13 mults + 255 squarings),
   replacing the generic Fermat mont_inv (~128 mults + 256 squarings) for the
   field prime. p = 2^256-2^224+2^192+2^96-1, so p-2 (MSB->LSB) is
   [32 ones][31 zeros][1][96 zeros][94 ones][0][1]; the one-runs assemble from
   (2^k-1)-ones blocks x_k. Montgomery domain. Bit-exact with mont_inv(.,&FP).*/
static void fp_sqrn(u64 r[4],const u64 a[4],int n){
#ifdef HAVE_MONT_SQRN_ASM
  mont_sqrn_p256(r,a,(u64)n);           /* value register-resident across the run */
#else
  int i; u64 t[4]; for(i=0;i<4;i++)t[i]=a[i];
  while(n-->0) fp_sqr(t,t);
  for(i=0;i<4;i++)r[i]=t[i];
#endif
}
static void fp_inv(u64 r[4],const u64 a[4]){
  u64 x1[4],x2[4],x4[4],x6[4],x8[4],x14[4],x16[4],x30[4],x32[4],t[4];
  int i;
  for(i=0;i<4;i++)x1[i]=a[i];
  fp_sqrn(t,x1,1);  fp_mul(x2,t,x1);    /* 2^2-1  */
  fp_sqrn(t,x2,2);  fp_mul(x4,t,x2);    /* 2^4-1  */
  fp_sqrn(t,x4,2);  fp_mul(x6,t,x2);    /* 2^6-1  = 4+2 */
  fp_sqrn(t,x4,4);  fp_mul(x8,t,x4);    /* 2^8-1  */
  fp_sqrn(t,x8,6);  fp_mul(x14,t,x6);   /* 2^14-1 = 8+6 */
  fp_sqrn(t,x8,8);  fp_mul(x16,t,x8);   /* 2^16-1 */
  fp_sqrn(t,x16,14);fp_mul(x30,t,x14);  /* 2^30-1 = 16+14 */
  fp_sqrn(t,x16,16);fp_mul(x32,t,x16);  /* 2^32-1 */
  for(i=0;i<4;i++)t[i]=x32[i];                /* top 32 ones */
  fp_sqrn(t,t,31);                            /* 31 zeros (bits 223..193) */
  fp_sqrn(t,t,1);  fp_mul(t,t,x1);      /* bit 192 = 1 */
  fp_sqrn(t,t,96);                            /* 96 zeros (bits 191..96) */
  fp_sqrn(t,t,32); fp_mul(t,t,x32);     /* 94-ones run = 32 +      */
  fp_sqrn(t,t,32); fp_mul(t,t,x32);     /*   32 +                  */
  fp_sqrn(t,t,30); fp_mul(t,t,x30);     /*   30 (reusing x32/x30)  */
  fp_sqrn(t,t,1);                             /* bit 1 = 0 */
  fp_sqrn(t,t,1);  fp_mul(t,t,x1);      /* bit 0 = 1 */
  for(i=0;i<4;i++)r[i]=t[i];
}

/* Scalar inverse mod n: a^(n-2) via the fixed briansmith addition chain (same
   as OpenSSL ecp_nistz256_inv_mod_ord): 253 squarings + 41 multiplications, vs
   the old 4-bit window's 256 sqr + 79 mul. The chain is a fixed operation
   sequence independent of a, so it is constant-time in the secret nonce (sign's
   k^-1). Montgomery domain in and out (a = a*R -> a^-1*R). Bit-exact with the
   old windowed scn_inv / mont_inv(.,&FN). */
static void scn_sqrn(u64 d[4],const u64 s[4],int n){
#ifdef HAVE_MONT_SQRN_ASM
  mont_sqrn_asm(d,s,(u64)n,&FN);        /* value register-resident across the run */
#else
  u64 t[4]; int i; for(i=0;i<4;i++)t[i]=s[i];
  for(i=0;i<n;i++) mont_sqr(t,t,&FN);
  for(i=0;i<4;i++)d[i]=t[i];
#endif
}
static void scn_inv(u64 r[4],const u64 a[4]){
  /* named powers of a (Montgomery); index order matches OpenSSL's enum */
  u64 t[14][4], acc[4]; int i;
  enum { i_1,i_10,i_11,i_101,i_111,i_1010,i_1111,i_10101,i_101010,i_101111,i_x6,i_x8,i_x16,i_x32 };
  for(i=0;i<4;i++)t[i_1][i]=a[i];
  scn_sqrn(t[i_10],t[i_1],1);
  mont_mul(t[i_11],  t[i_1],   t[i_10], &FN);
  mont_mul(t[i_101], t[i_11],  t[i_10], &FN);
  mont_mul(t[i_111], t[i_101], t[i_10], &FN);
  scn_sqrn(t[i_1010],t[i_101],1);
  mont_mul(t[i_1111],t[i_1010],t[i_101],&FN);
  scn_sqrn(t[i_10101],t[i_1010],1);  mont_mul(t[i_10101],t[i_10101],t[i_1],&FN);
  scn_sqrn(t[i_101010],t[i_10101],1);
  mont_mul(t[i_101111],t[i_101010],t[i_101],&FN);
  mont_mul(t[i_x6],  t[i_101010],t[i_10101],&FN);
  scn_sqrn(t[i_x8], t[i_x6],2);  mont_mul(t[i_x8], t[i_x8], t[i_11], &FN);
  scn_sqrn(t[i_x16],t[i_x8],8);  mont_mul(t[i_x16],t[i_x16],t[i_x8], &FN);
  scn_sqrn(t[i_x32],t[i_x16],16);mont_mul(t[i_x32],t[i_x32],t[i_x16],&FN);
  scn_sqrn(acc,t[i_x32],64);     mont_mul(acc,acc,t[i_x32],&FN);
  { static const unsigned char cp[27]={32,6,5,4,5,5,4,3,3,5,9,6,2,5,6,5,4,5,5,3,10,2,5,5,3,7,6};
    static const unsigned char ci[27]={i_x32,i_101111,i_111,i_11,i_1111,i_10101,i_101,i_101,i_101,
      i_111,i_101111,i_1111,i_1,i_1,i_1111,i_111,i_111,i_111,i_101,i_11,i_101111,i_11,i_11,i_11,i_1,i_10101,i_1111};
    for(i=0;i<27;i++){ scn_sqrn(acc,acc,cp[i]); mont_mul(acc,acc,t[ci[i]],&FN); }
  }
  for(i=0;i<4;i++)r[i]=acc[i];
}

#if defined(__aarch64__) && defined(__APPLE__) && !defined(RKTCRYPTO_P256_NO_ASM)
/* Scheduled asm point-doubling (asmp: operation-level list scheduler +
   critical-path-aware spilling; jac layout X@0,Y@32,Z@64 matches this struct).
   Bit-exact with the portable formula below (P-256 differential KAT 0/200000). */
extern void jac_double_hw(jac *r,const jac *p);
static void jac_double(jac *r,const jac *p){
  if(fp_iszero(p->Z)){ *r=*p; return; }   /* identity: asm assumes Z!=0 path */
  jac_double_hw(r,p);
}
#define JAC_DOUBLE_ASM 1
#endif
static void __attribute__((unused)) jac_double_portable(jac *r,const jac *p){
  u64 YY[4],ZZ[4],S[4],M[4],X3[4],Y3[4],Z3[4],t[4],Y4[4];
  int i;
  u64 xm[4],xp[4],prod[4];
  if(fp_iszero(p->Z)){ *r=*p; return; }
  /* Ordered into 3-wide groups of independent field multiplies so the OoO
     core keeps three in flight (2-way pairs left ILP unused). Each group's
     multiplies depend only on earlier groups. */
  fp_sqr(YY,p->Y);  fp_sqr(ZZ,p->Z);  fp_mul(Z3,p->Y,p->Z);   /* group 1: Y^2, Z^2, Y*Z */
  mont_sub(xm,p->X,ZZ,FP.m);  mont_add(xp,p->X,ZZ,FP.m);
  fp_mul(S,p->X,YY);  fp_sqr(Y4,YY);  fp_mul(prod,xm,xp);     /* group 2: X*YY, YY^2, (X-ZZ)(X+ZZ) */
  mont_add(S,S,S,FP.m); mont_add(S,S,S,FP.m);                 /* S = 4*X*Y^2 */
  mont_add(M,prod,prod,FP.m); mont_add(M,M,prod,FP.m);        /* M = 3*prod */
  mont_add(Y4,Y4,Y4,FP.m); mont_add(Y4,Y4,Y4,FP.m); mont_add(Y4,Y4,Y4,FP.m); /* 8*Y^4 */
  fp_sqr(X3,M);                                               /* X3 = M^2 (critical path) */
  mont_sub(X3,X3,S,FP.m); mont_sub(X3,X3,S,FP.m);             /* X3 = M^2 - 2S */
  mont_sub(t,S,X3,FP.m);
  fp_mul(t,M,t);                                              /* M*(S-X3) (critical path) */
  mont_sub(Y3,t,Y4,FP.m);                                     /* Y3 = M*(S-X3) - 8*Y^4 */
  mont_add(Z3,Z3,Z3,FP.m);                                    /* Z3 = 2*Y*Z */
  for(i=0;i<4;i++){ r->X[i]=X3[i]; r->Y[i]=Y3[i]; r->Z[i]=Z3[i]; }
}
#ifndef JAC_DOUBLE_ASM
static void jac_double(jac *r,const jac *p){ jac_double_portable(r,p); }
#endif

static void jac_add(jac *r,const jac *p,const jac *q){
  /* If p is identity (Z=0), return q; if q identity, return p. */
  u64 Z1Z1[4],Z2Z2[4],U1[4],U2[4],S1[4],S2[4],H[4],Rr[4],HH[4],HHH[4],t[4],t2[4],tt[4],X3[4],ZZ[4];
  int i;
  int pz=fp_iszero(p->Z), qz=fp_iszero(q->Z);
  if(pz){ *r=*q; return; }
  if(qz){ *r=*p; return; }
  /* independent multiplies grouped into pairs for OoO overlap */
  fp_sqr(Z1Z1,p->Z);    fp_sqr(Z2Z2,q->Z);       /* pair */
  fp_mul(U1,p->X,Z2Z2); fp_mul(U2,q->X,Z1Z1);    /* pair */
  fp_mul(S1,p->Y,q->Z); fp_mul(S2,q->Y,p->Z);    /* pair */
  fp_mul(S1,S1,Z2Z2);   fp_mul(S2,S2,Z1Z1);      /* pair */
  mont_sub(H,U2,U1,FP.m);
  mont_sub(Rr,S2,S1,FP.m);
  if(fp_iszero(H)){
    if(fp_iszero(Rr)){ jac_double(r,p); return; }
    /* opposite points -> identity */
    for(i=0;i<4;i++){ r->X[i]=0;r->Y[i]=0;r->Z[i]=0;} r->X[0]=1;r->Y[0]=1; return;
  }
  fp_sqr(HH,H);         fp_sqr(X3,Rr);           /* pair: H^2, R^2 */
  fp_mul(HHH,HH,H);     fp_mul(t,U1,HH);         /* pair: HH*H, U1*HH */
  mont_sub(X3,X3,HHH,FP.m);
  mont_sub(X3,X3,t,FP.m); mont_sub(X3,X3,t,FP.m);            /* X3 = R^2 - HHH - 2*U1*HH */
  fp_mul(ZZ,p->Z,q->Z); fp_mul(tt,S1,HHH);       /* pair: Z1*Z2, S1*HHH */
  mont_sub(t2,t,X3,FP.m); fp_mul(t2,Rr,t2);
  mont_sub(r->Y,t2,tt,FP.m);
  fp_mul(r->Z,ZZ,H);
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
  fp_sqr(Z1Z1,p->Z);    fp_mul(S2,q->Y,p->Z);   /* pair 1: Z1^2, Y2*Z1 */
  fp_mul(U2,q->X,Z1Z1); fp_mul(S2,S2,Z1Z1);     /* pair 2 */
  mont_sub(H,U2,p->X,FP.m);                     /* H  = U2 - X1 */
  mont_sub(Rr,S2,p->Y,FP.m);                    /* R  = S2 - Y1 */
  if(fp_iszero(H)){
    if(fp_iszero(Rr)){ jac_double(r,p); return; }
    for(i=0;i<4;i++){ r->X[i]=0;r->Y[i]=0;r->Z[i]=0;} r->X[0]=1;r->Y[0]=1; return;
  }
  fp_sqr(HH,H);         fp_sqr(X3,Rr);          /* pair 3: H^2, R^2 */
  fp_mul(HHH,HH,H);     fp_mul(t,p->X,HH);      /* pair 4: HH*H, X1*HH */
  mont_sub(X3,X3,HHH,FP.m);
  mont_sub(X3,X3,t,FP.m); mont_sub(X3,X3,t,FP.m);           /* X3 = R^2 - HHH - 2*X1*HH */
  fp_mul(tt,p->Y,HHH);  fp_mul(Z3,p->Z,H);      /* pair 5: Y1*HHH, Z1*H */
  mont_sub(t2,t,X3,FP.m); fp_mul(t2,Rr,t2);
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
  u64 prefix[64][4], acc[4], inv[4], zi[4], zi2[4], zi3[4];
  u64 one[4]={1,0,0,0}, montone[4]; int i,j;
  to_mont(montone,one,&FP);
  for(j=0;j<4;j++){ acc[j]=pts[0].Z[j]; prefix[0][j]=pts[0].Z[j]; }
  for(i=1;i<n;i++){ fp_mul(acc,acc,pts[i].Z); for(j=0;j<4;j++) prefix[i][j]=acc[j]; }
  fp_inv(inv,acc);                               /* inv = (prod Z_i)^-1 */
  for(i=n-1;i>=0;i--){
    if(i>0) fp_mul(zi,inv,prefix[i-1]);    /* zi = Z_i^-1 */
    else    for(j=0;j<4;j++) zi[j]=inv[j];
    fp_mul(inv,inv,pts[i].Z);              /* strip Z_i for next round */
    fp_sqr(zi2,zi); fp_mul(zi3,zi2,zi);
    fp_mul(pts[i].X,pts[i].X,zi2);
    fp_mul(pts[i].Y,pts[i].Y,zi3);
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
  jac T[17], acc, sel, tmp; int i,j,d;
  unsigned char p_str[33]; u64 negY[4], zero[4]={0,0,0,0};
  /* signed width-5 window: table of |digit| multiples 1P..16P, affine. P is
     affine (Z=mont1) in every caller, so build with mixed_add. */
  for(i=0;i<4;i++){T[0].X[i]=0;T[0].Y[i]=0;T[0].Z[i]=0;} T[0].X[0]=1;T[0].Y[0]=1; /* O */
  T[1]=*p;
  jac_double(&T[2],p);
  for(i=3;i<=16;i++) mixed_add(&T[i],&T[i-1],p);
  batch_affine(&T[1],16);                          /* T[1..16] -> affine */
  /* scalar -> 33 little-endian bytes (top zero, for the Booth overlap) */
  for(i=0;i<4;i++){ u64 wv=k[i]; for(j=0;j<8;j++) p_str[i*8+j]=(unsigned char)(wv>>(8*j)); }
  p_str[32]=0;
  for(i=0;i<4;i++){acc.X[i]=0;acc.Y[i]=0;acc.Z[i]=0;} acc.X[0]=1;acc.Y[0]=1; /* identity */
  for(j=51;j>=0;j--){                              /* 52 signed width-5 windows, MSB first */
    unsigned wv,digit,sign; int lo=5*j-1;
    jac_double(&acc,&acc); jac_double(&acc,&acc); jac_double(&acc,&acc);
    jac_double(&acc,&acc); jac_double(&acc,&acc);
    if(lo<0) wv=((unsigned)p_str[0]<<1)&0x3F;
    else { int off=lo>>3; wv=(((unsigned)p_str[off])|((unsigned)p_str[off+1]<<8))>>(lo&7); wv&=0x3F; }
    wv=booth_recode_w5(wv); digit=wv>>1; sign=wv&1;
    for(i=0;i<4;i++){sel.X[i]=T[1].X[i];sel.Y[i]=T[1].Y[i];sel.Z[i]=T[1].Z[i];}
    for(d=1;d<=16;d++){ u64 m=(d==(int)digit); fp_cmov(sel.X,T[d].X,m);fp_cmov(sel.Y,T[d].Y,m);fp_cmov(sel.Z,T[d].Z,m); }
    mont_sub(negY,zero,sel.Y,FP.m); fp_cmov(sel.Y,negY,(u64)sign);   /* conditional negate for sign */
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
  fp_sqr(zinv2,zinv); fp_mul(zinv3,zinv2,zinv);
  fp_mul(xa,p->X,zinv2); fp_mul(ya,p->Y,zinv3);
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
  fp_sqr(zinv2,zinv); fp_mul(zinv3,zinv2,zinv);
  fp_mul(out->X,p->X,zinv2); fp_mul(out->Y,p->Y,zinv3);
  { u64 one[4]={1,0,0,0}; to_mont(out->Z,one,&FP); }
}

/* Build the fixed-base signed width-7 comb table (one-time, lazy). For window
   position i, comb7[i][d] = d * 2^(7i) * G, d=1..64. The 64 multiples per
   position are normalized to affine with a single field inversion (Montgomery's
   trick), so init costs 37 inversions rather than 37*64. Branchy point ops --
   the base point is public. */
static void comb_init(void){
  jac P, mult[64]; int i,d,k;
  base_point(&P);                                    /* P = 2^(7i)*G, starts at G */
  for(i=0;i<37;i++){
    mult[0]=P;
    for(d=1;d<64;d++) jac_add(&mult[d],&mult[d-1],&P);   /* (d+1)*P -> 1*P..64*P */
    batch_affine(mult,64);                              /* one inversion for 64 pts */
    for(d=0;d<64;d++){ for(k=0;k<4;k++){ comb7[i][d+1].X[k]=mult[d].X[k]; comb7[i][d+1].Y[k]=mult[d].Y[k]; } }
    for(k=0;k<4;k++){ comb7[i][0].X[k]=0; comb7[i][0].Y[k]=0; }   /* digit 0, masked out */
    if(i<36){ for(k=0;k<7;k++) jac_double(&P,&P); }               /* P *= 2^7 */
  }
  comb_inited=1;
}

/* Fixed-base k*G via a signed width-7 comb (OpenSSL scheme). The scalar is
   Booth-recoded into 37 signed digits d_i in [-64,64]: k = sum_i d_i*2^(7i), so
   k*G = sum_i sign(d_i)*comb7[i][|d_i|] -- 37 constant-time additions, no
   doublings. Constant-time throughout: the table scan cmov's over all 64 entries
   (no secret-dependent access), the sign is applied by a masked Y-negation, and
   the digit-zero add is masked out. */
static void jac_scalarmult_base(jac *r,const u64 k[4]){
  jac acc, sel, tmp; int i, d, j;
  unsigned char p_str[33];
  u64 montone[4], negY[4], zero[4]={0,0,0,0};
  if(!comb_inited) comb_init();
  { u64 one[4]={1,0,0,0}; to_mont(montone,one,&FP); }
  /* scalar -> 33 little-endian bytes (top byte zero, for the Booth overlap) */
  for(i=0;i<4;i++){ u64 w=k[i]; for(j=0;j<8;j++) p_str[i*8+j]=(unsigned char)(w>>(8*j)); }
  p_str[32]=0;
  for(i=0;i<4;i++){acc.X[i]=0;acc.Y[i]=0;acc.Z[i]=0;} acc.X[0]=1;acc.Y[0]=1; /* identity */
  for(i=0;i<37;i++){
    unsigned wv, digit, sign;
    if(i==0) wv = (unsigned)(p_str[0] << 1) & 0xFF;
    else { int idx=7*i, off=(idx-1)>>3; wv = ((unsigned)p_str[off] | ((unsigned)p_str[off+1]<<8)) >> ((idx-1)&7); wv &= 0xFF; }
    wv = booth_recode_w7(wv);
    digit = wv >> 1; sign = wv & 1;
    /* constant-time gather of the magnitude point */
    for(j=0;j<4;j++){ sel.X[j]=comb7[i][1].X[j]; sel.Y[j]=comb7[i][1].Y[j]; }
    for(d=1;d<=64;d++){ u64 m=(d==(int)digit); fp_cmov(sel.X,comb7[i][d].X,m); fp_cmov(sel.Y,comb7[i][d].Y,m); }
    for(j=0;j<4;j++) sel.Z[j]=montone[j];
    /* conditional negate Y for a negative digit */
    mont_sub(negY,zero,sel.Y,FP.m); fp_cmov(sel.Y,negY,(u64)sign);
    mixed_add(&tmp,&acc,&sel);
    { u64 m=(digit!=0); fp_cmov(acc.X,tmp.X,m);fp_cmov(acc.Y,tmp.Y,m);fp_cmov(acc.Z,tmp.Z,m); }
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

static int p256_verify_digest32(const unsigned char sig[64],const unsigned char digest[32],const unsigned char pub65[65]){
  u64 z[4],r_[4],s_[4],w[4],u1[4],u2[4];
  u64 smont[4],winv[4],zmont[4],rmont[4],u1m[4],u2m[4];
  jac Pub,A1,A2,R; u64 px[4],py[4];
  if(!inited)p256_init();
  if(pub65[0]!=4) return 0;
  bytes_to_bn(r_,sig); bytes_to_bn(s_,sig+32);
  if(fp_iszero(r_)||fp_iszero(s_)||bn_geq(r_,N)||bn_geq(s_,N)) return 0;
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
  /* Verify is entirely public data, so compare the x-coordinate projectively
     and skip the final field inversion: affine_x(R) = X/Z^2, and the signature
     is valid iff affine_x == r (mod n), i.e. X == r*Z^2 (mod p) -- or, when the
     x-coordinate landed in [n,p), the wrapped case X == (r+n)*Z^2 (mod p).
     Replaces a ~2.6 us fp_inv + affine conversion with one square + two muls. */
  if(fp_iszero(R.Z)) return 0;                 /* R at infinity -> invalid */
  { u64 z2[4],rp[4],t[4],rn[4]; int i,eq; u128 c=0;
    fp_sqr(z2,R.Z);                            /* mont(Z^2) */
    to_mont(rp,r_,&FP); fp_mul(t,rp,z2);       /* mont(r*Z^2) */
    eq=1; for(i=0;i<4;i++) eq&=(t[i]==R.X[i]);
    if(eq) return 1;
    /* wrapped x == r + n, valid only if r + n < p */
    for(i=0;i<4;i++){ u128 s=(u128)r_[i]+N[i]+c; rn[i]=(u64)s; c=s>>64; }
    if(c==0 && !bn_geq(rn,P)){
      to_mont(rp,rn,&FP); fp_mul(t,rp,z2);
      eq=1; for(i=0;i<4;i++) eq&=(t[i]==R.X[i]);
      if(eq) return 1;
    }
  }
  return 0;
}

int rktcrypto_p256_ecdsa_verify(const unsigned char sig[64],const unsigned char *msg,intptr_t msglen,const unsigned char pub65[65]){
  unsigned char digest[32];
  sha256(msg,msglen,digest);
  return p256_verify_digest32(sig,digest,pub65);
}

/* Precomputed-digest variant (X.509 chains with a non-SHA-256 digest over a
   P-256 key): z = leftmost 256 bits of the digest, per ECDSA. */
int rktcrypto_p256_ecdsa_verify_h(const unsigned char sig[64],const unsigned char *h,intptr_t hlen,const unsigned char pub65[65]){
  unsigned char d32[32];
  if(hlen<20||hlen>64) return 0;
  if(hlen>=32) memcpy(d32,h,32);
  else { memset(d32,0,(size_t)(32-hlen)); memcpy(d32+(32-hlen),h,(size_t)hlen); }
  return p256_verify_digest32(sig,d32,pub65);
}
