/* Ed25519 signatures (RFC 8032).

   From-scratch public-domain-style implementation. Field arithmetic in
   GF(2^255-19) uses five 51-bit limbs (as in X25519); group elements use
   extended twisted-Edwards coordinates; scalars are reduced modulo the
   group order L with the standard 21-bit-limb method. SHA-512 comes from
   the existing digest core. Signing is constant-time in the secret scalar
   (fixed-base double-and-add with a constant-time conditional move);
   verification handles only public data. No external code. */

#include "rktcrypto_digest.h"
#include <string.h>
#include <stdint.h>

/* ---------------- field arithmetic (radix 2^51) ---------------- */

typedef uint64_t fe[5];
#define MASK51 0x7ffffffffffffULL

static uint64_t load64_le(const unsigned char *p){uint64_t r=0;int i;for(i=0;i<8;i++)r|=(uint64_t)p[i]<<(8*i);return r;}
static void store64_le(unsigned char *p,uint64_t v){int i;for(i=0;i<8;i++)p[i]=(unsigned char)(v>>(8*i));}

static void fe_0(fe h){int i;for(i=0;i<5;i++)h[i]=0;}
static void fe_1(fe h){fe_0(h);h[0]=1;}
static void fe_copy(fe h,const fe f){int i;for(i=0;i<5;i++)h[i]=f[i];}
static void fe_add(fe h,const fe f,const fe g){int i;for(i=0;i<5;i++)h[i]=f[i]+g[i];}
static void fe_sub(fe h,const fe f,const fe g){
  h[0]=f[0]+0xfffffffffffdaULL-g[0]; h[1]=f[1]+0xffffffffffffeULL-g[1];
  h[2]=f[2]+0xffffffffffffeULL-g[2]; h[3]=f[3]+0xffffffffffffeULL-g[3];
  h[4]=f[4]+0xffffffffffffeULL-g[4];
}
static void fe_carry(fe h,__uint128_t r0,__uint128_t r1,__uint128_t r2,__uint128_t r3,__uint128_t r4){
  uint64_t c;
  c=(uint64_t)(r0>>51);r1+=c;h[0]=(uint64_t)r0&MASK51;
  c=(uint64_t)(r1>>51);r2+=c;h[1]=(uint64_t)r1&MASK51;
  c=(uint64_t)(r2>>51);r3+=c;h[2]=(uint64_t)r2&MASK51;
  c=(uint64_t)(r3>>51);r4+=c;h[3]=(uint64_t)r3&MASK51;
  c=(uint64_t)(r4>>51);h[4]=(uint64_t)r4&MASK51;
  h[0]+=19*c; c=h[0]>>51;h[0]&=MASK51;h[1]+=c;
}
static void fe_mul(fe h,const fe f,const fe g){
  uint64_t f0=f[0],f1=f[1],f2=f[2],f3=f[3],f4=f[4];
  uint64_t g0=g[0],g1=g[1],g2=g[2],g3=g[3],g4=g[4];
  uint64_t g1_19=19*g1,g2_19=19*g2,g3_19=19*g3,g4_19=19*g4;
  __uint128_t r0,r1,r2,r3,r4;
  r0=(__uint128_t)f0*g0+(__uint128_t)f1*g4_19+(__uint128_t)f2*g3_19+(__uint128_t)f3*g2_19+(__uint128_t)f4*g1_19;
  r1=(__uint128_t)f0*g1+(__uint128_t)f1*g0+(__uint128_t)f2*g4_19+(__uint128_t)f3*g3_19+(__uint128_t)f4*g2_19;
  r2=(__uint128_t)f0*g2+(__uint128_t)f1*g1+(__uint128_t)f2*g0+(__uint128_t)f3*g4_19+(__uint128_t)f4*g3_19;
  r3=(__uint128_t)f0*g3+(__uint128_t)f1*g2+(__uint128_t)f2*g1+(__uint128_t)f3*g0+(__uint128_t)f4*g4_19;
  r4=(__uint128_t)f0*g4+(__uint128_t)f1*g3+(__uint128_t)f2*g2+(__uint128_t)f3*g1+(__uint128_t)f4*g0;
  fe_carry(h,r0,r1,r2,r3,r4);
}
/* Dedicated squaring: 15 multiplies (vs the mul's 25) by folding the symmetric
   cross terms into doubled inputs. h = f^2 mod 2^255-19. */
static void fe_sq(fe h,const fe f){
  uint64_t f0=f[0],f1=f[1],f2=f[2],f3=f[3],f4=f[4];
  uint64_t f0_2=2*f0,f1_2=2*f1;
  uint64_t f1_38=38*f1,f2_38=38*f2,f3_38=38*f3,f3_19=19*f3,f4_19=19*f4;
  __uint128_t r0,r1,r2,r3,r4;
  r0=(__uint128_t)f0*f0 + (__uint128_t)f1_38*f4 + (__uint128_t)f2_38*f3;
  r1=(__uint128_t)f0_2*f1 + (__uint128_t)f2_38*f4 + (__uint128_t)f3_19*f3;
  r2=(__uint128_t)f0_2*f2 + (__uint128_t)f1*f1 + (__uint128_t)f3_38*f4;
  r3=(__uint128_t)f0_2*f3 + (__uint128_t)f1_2*f2 + (__uint128_t)f4_19*f4;
  r4=(__uint128_t)f0_2*f4 + (__uint128_t)f1_2*f3 + (__uint128_t)f2*f2;
  fe_carry(h,r0,r1,r2,r3,r4);
}
static void fe_neg(fe h,const fe f){fe z;fe_0(z);fe_sub(h,z,f);}
static void fe_cmov(fe f,const fe g,uint64_t b){uint64_t m=0-b;int i;for(i=0;i<5;i++)f[i]^=m&(f[i]^g[i]);}

static void fe_invert(fe out,const fe z){
  fe t0,t1,t2,t3;int i;
  fe_sq(t0,z);fe_sq(t1,t0);fe_sq(t1,t1);fe_mul(t1,z,t1);fe_mul(t0,t0,t1);
  fe_sq(t2,t0);fe_mul(t1,t1,t2);fe_sq(t2,t1);for(i=1;i<5;i++)fe_sq(t2,t2);fe_mul(t1,t2,t1);
  fe_sq(t2,t1);for(i=1;i<10;i++)fe_sq(t2,t2);fe_mul(t2,t2,t1);
  fe_sq(t3,t2);for(i=1;i<20;i++)fe_sq(t3,t3);fe_mul(t2,t3,t2);
  fe_sq(t2,t2);for(i=1;i<10;i++)fe_sq(t2,t2);fe_mul(t1,t2,t1);
  fe_sq(t2,t1);for(i=1;i<50;i++)fe_sq(t2,t2);fe_mul(t2,t2,t1);
  fe_sq(t3,t2);for(i=1;i<100;i++)fe_sq(t3,t3);fe_mul(t2,t3,t2);
  fe_sq(t2,t2);for(i=1;i<50;i++)fe_sq(t2,t2);fe_mul(t1,t2,t1);
  fe_sq(t1,t1);for(i=1;i<5;i++)fe_sq(t1,t1);fe_mul(out,t1,t0);
}
static void fe_pow22523(fe out,const fe z){
  fe t0,t1,t2;int i;
  fe_sq(t0,z);fe_sq(t1,t0);fe_sq(t1,t1);fe_mul(t1,z,t1);fe_mul(t0,t0,t1);
  fe_sq(t0,t0);fe_mul(t0,t1,t0);
  fe_sq(t1,t0);for(i=1;i<5;i++)fe_sq(t1,t1);fe_mul(t0,t1,t0);
  fe_sq(t1,t0);for(i=1;i<10;i++)fe_sq(t1,t1);fe_mul(t1,t1,t0);
  fe_sq(t2,t1);for(i=1;i<20;i++)fe_sq(t2,t2);fe_mul(t1,t2,t1);
  fe_sq(t1,t1);for(i=1;i<10;i++)fe_sq(t1,t1);fe_mul(t0,t1,t0);
  fe_sq(t1,t0);for(i=1;i<50;i++)fe_sq(t1,t1);fe_mul(t1,t1,t0);
  fe_sq(t2,t1);for(i=1;i<100;i++)fe_sq(t2,t2);fe_mul(t1,t2,t1);
  fe_sq(t1,t1);for(i=1;i<50;i++)fe_sq(t1,t1);fe_mul(t0,t1,t0);
  fe_sq(t0,t0);fe_sq(t0,t0);fe_mul(out,t0,z);
}

static void fe_frombytes(fe h,const unsigned char *s){
  uint64_t a0=load64_le(s),a1=load64_le(s+8),a2=load64_le(s+16),a3=load64_le(s+24);
  h[0]=a0&MASK51;
  h[1]=((a0>>51)|(a1<<13))&MASK51;
  h[2]=((a1>>38)|(a2<<26))&MASK51;
  h[3]=((a2>>25)|(a3<<39))&MASK51;
  h[4]=(a3>>12)&0x7ffffffffffffULL;
}
static void fe_reduce(fe t){
  uint64_t c;
  c=t[0]>>51;t[0]&=MASK51;t[1]+=c; c=t[1]>>51;t[1]&=MASK51;t[2]+=c;
  c=t[2]>>51;t[2]&=MASK51;t[3]+=c; c=t[3]>>51;t[3]&=MASK51;t[4]+=c;
  c=t[4]>>51;t[4]&=MASK51;t[0]+=19*c;
  { uint64_t q=(t[0]+19)>>51; q=(t[1]+q)>>51;q=(t[2]+q)>>51;q=(t[3]+q)>>51;q=(t[4]+q)>>51;
    t[0]+=19*q;
    c=t[0]>>51;t[0]&=MASK51;t[1]+=c;c=t[1]>>51;t[1]&=MASK51;t[2]+=c;
    c=t[2]>>51;t[2]&=MASK51;t[3]+=c;c=t[3]>>51;t[3]&=MASK51;t[4]+=c;t[4]&=MASK51; }
}
static void fe_tobytes(unsigned char *s,const fe h){
  fe t;fe_copy(t,h);fe_reduce(t);
  uint64_t o0=t[0]|(t[1]<<51),o1=(t[1]>>13)|(t[2]<<38),o2=(t[2]>>26)|(t[3]<<25),o3=(t[3]>>39)|(t[4]<<12);
  store64_le(s,o0);store64_le(s+8,o1);store64_le(s+16,o2);store64_le(s+24,o3);
}
static int fe_isnegative(const fe f){unsigned char s[32];fe_tobytes(s,f);return s[0]&1;}
static int fe_iszero(const fe f){unsigned char s[32];int i;unsigned char acc=0;fe_tobytes(s,f);for(i=0;i<32;i++)acc|=s[i];return acc==0;}

static void curve_d(fe d){
  fe num,den; fe_0(num);num[0]=121665;fe_neg(num,num); fe_0(den);den[0]=121666;fe_invert(den,den); fe_mul(d,num,den);
}
static void curve_d2(fe d2){ fe d; curve_d(d); fe_add(d2,d,d); }
static void curve_sqrtm1(fe out){
  static const unsigned char S[32]={
    0xb0,0xa0,0x0e,0x4a,0x27,0x1b,0xee,0xc4,0x78,0xe4,0x2f,0xad,0x06,0x18,0x43,0x2f,
    0xa7,0xd7,0xfb,0x3d,0x99,0x00,0x4d,0x2b,0x0b,0xdf,0xc1,0x4f,0x80,0x24,0x83,0x2b};
  fe_frombytes(out,S);
}

/* ---------------- extended-coordinate points ---------------- */

typedef struct { fe X,Y,Z,T; } ge;

static void ge_identity(ge *p){fe_0(p->X);fe_1(p->Y);fe_1(p->Z);fe_0(p->T);}

/* Unified twisted-Edwards (a=-1) addition; correct for doubling too. */
static void ge_add(ge *r,const ge *p,const ge *q,const fe d2){
  fe a,b,c,dd,e,f,g,h,t0,t1;
  fe_sub(t0,p->Y,p->X); fe_sub(t1,q->Y,q->X); fe_mul(a,t0,t1);
  fe_add(t0,p->Y,p->X); fe_add(t1,q->Y,q->X); fe_mul(b,t0,t1);
  fe_mul(c,p->T,q->T); fe_mul(c,c,d2);
  fe_mul(dd,p->Z,q->Z); fe_add(dd,dd,dd);
  fe_sub(e,b,a); fe_sub(f,dd,c); fe_add(g,dd,c); fe_add(h,b,a);
  fe_mul(r->X,e,f); fe_mul(r->Y,g,h); fe_mul(r->T,e,h); fe_mul(r->Z,f,g);
}

#ifdef ED25519_SELFTEST
/* Reference bit-by-bit double-and-add. Superseded in production by the
   fixed-base comb and the variable-base window; kept as the oracle the
   offline selftest checks those against. */
static void ge_scalarmult(ge *r,const unsigned char s[32],const ge *p,const fe d2){
  int i;
  ge_identity(r);
  for(i=255;i>=0;i--){
    ge t,q;
    uint64_t bit=(s[i>>3]>>(i&7))&1;
    ge_add(&t,r,r,d2);
    ge_add(&q,&t,p,d2);
    fe_cmov(t.X,q.X,bit);fe_cmov(t.Y,q.Y,bit);fe_cmov(t.Z,q.Z,bit);fe_cmov(t.T,q.T,bit);
    *r=t;
  }
}
#endif

/* Fixed-base comb for s*B, width-4 with ZERO online doublings (as in the EC
   combs): ed_comb[w][d] = d * 16^w * B for window w (0..63) and digit d (1..15),
   precomputed once. s*B is then just 64 constant-time table-adds -- no doublings
   at all (was 64 doublings + 64 adds). The twisted-Edwards (a=-1) law is complete
   so there are no exceptional cases; entries are chosen with a full cmov scan
   (no secret-dependent memory access) and d=0 selects the identity. */
static void ge_base(ge *B);
static ge ed_comb[64][16];
static int ed_comb_inited=0;
static void ge_cmov(ge *r,const ge *a,uint64_t b){
  fe_cmov(r->X,a->X,b);fe_cmov(r->Y,a->Y,b);fe_cmov(r->Z,a->Z,b);fe_cmov(r->T,a->T,b);
}
static void ed_comb_init(const fe d2){
  ge base; int w,d;
  ge_base(&base);
  for(w=0;w<64;w++){
    ge_identity(&ed_comb[w][0]); ed_comb[w][1]=base;
    for(d=2;d<16;d++) ge_add(&ed_comb[w][d],&ed_comb[w][d-1],&base,d2);
    if(w+1<64){ for(d=0;d<4;d++) ge_add(&base,&base,&base,d2); }   /* base *= 16 */
  }
  ed_comb_inited=1;
}
static void ge_scalarmult_base(ge *r,const unsigned char s[32],const fe d2){
  int w,d; ge sel;
  if(!ed_comb_inited) ed_comb_init(d2);
  ge_identity(r);
  for(w=0;w<64;w++){
    unsigned nib=(s[w>>1]>>((w&1)*4))&0xF;
    sel=ed_comb[w][0];
    for(d=1;d<16;d++) ge_cmov(&sel,&ed_comb[w][d],(uint64_t)(d==(int)nib));
    ge_add(r,r,&sel,d2);
  }
}

/* Variable-base s*P via a width-4 window (verification only, all public
   data -- direct table indexing, no constant-time scan). Builds T[i]=i*P
   for i=0..15 and runs 64 nibbles of 4 doublings + 1 add. The complete
   addition law means the projective table needs no affine normalization.
   Bit-exact with ge_scalarmult. */
static void ge_scalarmult_win(ge *r,const unsigned char s[32],const ge *p,const fe d2){
  ge T[16]; int i,w;
  ge_identity(&T[0]); T[1]=*p;
  for(i=2;i<16;i++) ge_add(&T[i],&T[i-1],p,d2);
  ge_identity(r);
  for(w=63;w>=0;w--){
    unsigned digit=(s[w>>1]>>((w&1)*4))&0xF;
    ge_add(r,r,r,d2); ge_add(r,r,r,d2); ge_add(r,r,r,d2); ge_add(r,r,r,d2);
    ge_add(r,r,&T[digit],d2);
  }
}

static void ge_tobytes(unsigned char *s,const ge *p){
  fe recip,x,y;
  fe_invert(recip,p->Z);
  fe_mul(x,p->X,recip); fe_mul(y,p->Y,recip);
  fe_tobytes(s,y);
  s[31]^=(unsigned char)(fe_isnegative(x)<<7);
}

static int ge_frombytes(ge *h,const unsigned char *s){
  fe u,v,v3,vxx,check,d,x,y,one;
  unsigned char sign=s[31]>>7;
  fe_frombytes(y,s);
  fe_1(one);
  curve_d(d);
  fe_sq(u,y);
  fe_mul(v,u,d);
  fe_sub(u,u,one);      /* u = y^2 - 1 */
  fe_add(v,v,one);      /* v = d*y^2 + 1 */
  fe_sq(v3,v);fe_mul(v3,v3,v);
  fe_sq(x,v3);fe_mul(x,x,v);fe_mul(x,x,u);   /* u*v^7 */
  fe_pow22523(x,x);
  fe_mul(x,x,v3);fe_mul(x,x,u);
  fe_sq(vxx,x);fe_mul(vxx,vxx,v);
  fe_sub(check,vxx,u);
  if(!fe_iszero(check)){
    fe sqrtm1;
    fe_add(check,vxx,u);
    if(!fe_iszero(check)) return 0;
    curve_sqrtm1(sqrtm1); fe_mul(x,x,sqrtm1);
  }
  if(fe_isnegative(x)!=(int)sign) fe_neg(x,x);
  fe_copy(h->X,x); fe_copy(h->Y,y); fe_1(h->Z); fe_mul(h->T,x,y);
  return 1;
}

static void ge_base(ge *B){
  static const unsigned char Bc[32]={
    0x58,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,
    0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66};
  ge_frombytes(B,Bc);
}

/* ---------------- scalar arithmetic mod L (ref10 method) ---------------- */

static int64_t load3(const unsigned char *in){return (int64_t)in[0]|((int64_t)in[1]<<8)|((int64_t)in[2]<<16);}
static int64_t load4(const unsigned char *in){return (int64_t)in[0]|((int64_t)in[1]<<8)|((int64_t)in[2]<<16)|((int64_t)in[3]<<24);}

/* s[0..63] (512-bit LE) reduced mod L, result in s[0..31]. */
static void sc_reduce(unsigned char *s){
  int64_t s0=2097151&load3(s), s1=2097151&(load4(s+2)>>5), s2=2097151&(load3(s+5)>>2),
    s3=2097151&(load4(s+7)>>7), s4=2097151&(load4(s+10)>>4), s5=2097151&(load3(s+13)>>1),
    s6=2097151&(load4(s+15)>>6), s7=2097151&(load3(s+18)>>3), s8=2097151&load3(s+21),
    s9=2097151&(load4(s+23)>>5), s10=2097151&(load3(s+26)>>2), s11=2097151&(load4(s+28)>>7),
    s12=2097151&(load4(s+31)>>4), s13=2097151&(load3(s+34)>>1), s14=2097151&(load4(s+36)>>6),
    s15=2097151&(load3(s+39)>>3), s16=2097151&load3(s+42), s17=2097151&(load4(s+44)>>5),
    s18=2097151&(load3(s+47)>>2), s19=2097151&(load4(s+49)>>7), s20=2097151&(load4(s+52)>>4),
    s21=2097151&(load3(s+55)>>1), s22=2097151&(load4(s+57)>>6), s23=(load4(s+60)>>3);
  int64_t carry[17];
  s11+=s23*666643;s12+=s23*470296;s13+=s23*654183;s14-=s23*997805;s15+=s23*136657;s16-=s23*683901;
  s10+=s22*666643;s11+=s22*470296;s12+=s22*654183;s13-=s22*997805;s14+=s22*136657;s15-=s22*683901;
  s9+=s21*666643;s10+=s21*470296;s11+=s21*654183;s12-=s21*997805;s13+=s21*136657;s14-=s21*683901;
  s8+=s20*666643;s9+=s20*470296;s10+=s20*654183;s11-=s20*997805;s12+=s20*136657;s13-=s20*683901;
  s7+=s19*666643;s8+=s19*470296;s9+=s19*654183;s10-=s19*997805;s11+=s19*136657;s12-=s19*683901;
  s6+=s18*666643;s7+=s18*470296;s8+=s18*654183;s9-=s18*997805;s10+=s18*136657;s11-=s18*683901;
  carry[6]=(s6+(1<<20))>>21;s7+=carry[6];s6-=carry[6]<<21;
  carry[8]=(s8+(1<<20))>>21;s9+=carry[8];s8-=carry[8]<<21;
  carry[10]=(s10+(1<<20))>>21;s11+=carry[10];s10-=carry[10]<<21;
  carry[12]=(s12+(1<<20))>>21;s13+=carry[12];s12-=carry[12]<<21;
  carry[14]=(s14+(1<<20))>>21;s15+=carry[14];s14-=carry[14]<<21;
  carry[16]=(s16+(1<<20))>>21;s17+=carry[16];s16-=carry[16]<<21;
  carry[7]=(s7+(1<<20))>>21;s8+=carry[7];s7-=carry[7]<<21;
  carry[9]=(s9+(1<<20))>>21;s10+=carry[9];s9-=carry[9]<<21;
  carry[11]=(s11+(1<<20))>>21;s12+=carry[11];s11-=carry[11]<<21;
  carry[13]=(s13+(1<<20))>>21;s14+=carry[13];s13-=carry[13]<<21;
  carry[15]=(s15+(1<<20))>>21;s16+=carry[15];s15-=carry[15]<<21;
  s5+=s17*666643;s6+=s17*470296;s7+=s17*654183;s8-=s17*997805;s9+=s17*136657;s10-=s17*683901;
  s4+=s16*666643;s5+=s16*470296;s6+=s16*654183;s7-=s16*997805;s8+=s16*136657;s9-=s16*683901;
  s3+=s15*666643;s4+=s15*470296;s5+=s15*654183;s6-=s15*997805;s7+=s15*136657;s8-=s15*683901;
  s2+=s14*666643;s3+=s14*470296;s4+=s14*654183;s5-=s14*997805;s6+=s14*136657;s7-=s14*683901;
  s1+=s13*666643;s2+=s13*470296;s3+=s13*654183;s4-=s13*997805;s5+=s13*136657;s6-=s13*683901;
  s0+=s12*666643;s1+=s12*470296;s2+=s12*654183;s3-=s12*997805;s4+=s12*136657;s5-=s12*683901;s12=0;
  carry[0]=(s0+(1<<20))>>21;s1+=carry[0];s0-=carry[0]<<21;
  carry[2]=(s2+(1<<20))>>21;s3+=carry[2];s2-=carry[2]<<21;
  carry[4]=(s4+(1<<20))>>21;s5+=carry[4];s4-=carry[4]<<21;
  carry[6]=(s6+(1<<20))>>21;s7+=carry[6];s6-=carry[6]<<21;
  carry[8]=(s8+(1<<20))>>21;s9+=carry[8];s8-=carry[8]<<21;
  carry[10]=(s10+(1<<20))>>21;s11+=carry[10];s10-=carry[10]<<21;
  carry[1]=(s1+(1<<20))>>21;s2+=carry[1];s1-=carry[1]<<21;
  carry[3]=(s3+(1<<20))>>21;s4+=carry[3];s3-=carry[3]<<21;
  carry[5]=(s5+(1<<20))>>21;s6+=carry[5];s5-=carry[5]<<21;
  carry[7]=(s7+(1<<20))>>21;s8+=carry[7];s7-=carry[7]<<21;
  carry[9]=(s9+(1<<20))>>21;s10+=carry[9];s9-=carry[9]<<21;
  carry[11]=(s11+(1<<20))>>21;s12+=carry[11];s11-=carry[11]<<21;
  s0+=s12*666643;s1+=s12*470296;s2+=s12*654183;s3-=s12*997805;s4+=s12*136657;s5-=s12*683901;s12=0;
  carry[0]=s0>>21;s1+=carry[0];s0-=carry[0]<<21;
  carry[1]=s1>>21;s2+=carry[1];s1-=carry[1]<<21;
  carry[2]=s2>>21;s3+=carry[2];s2-=carry[2]<<21;
  carry[3]=s3>>21;s4+=carry[3];s3-=carry[3]<<21;
  carry[4]=s4>>21;s5+=carry[4];s4-=carry[4]<<21;
  carry[5]=s5>>21;s6+=carry[5];s5-=carry[5]<<21;
  carry[6]=s6>>21;s7+=carry[6];s6-=carry[6]<<21;
  carry[7]=s7>>21;s8+=carry[7];s7-=carry[7]<<21;
  carry[8]=s8>>21;s9+=carry[8];s8-=carry[8]<<21;
  carry[9]=s9>>21;s10+=carry[9];s9-=carry[9]<<21;
  carry[10]=s10>>21;s11+=carry[10];s10-=carry[10]<<21;
  carry[11]=s11>>21;s12+=carry[11];s11-=carry[11]<<21;
  s0+=s12*666643;s1+=s12*470296;s2+=s12*654183;s3-=s12*997805;s4+=s12*136657;s5-=s12*683901;
  carry[0]=s0>>21;s1+=carry[0];s0-=carry[0]<<21;
  carry[1]=s1>>21;s2+=carry[1];s1-=carry[1]<<21;
  carry[2]=s2>>21;s3+=carry[2];s2-=carry[2]<<21;
  carry[3]=s3>>21;s4+=carry[3];s3-=carry[3]<<21;
  carry[4]=s4>>21;s5+=carry[4];s4-=carry[4]<<21;
  carry[5]=s5>>21;s6+=carry[5];s5-=carry[5]<<21;
  carry[6]=s6>>21;s7+=carry[6];s6-=carry[6]<<21;
  carry[7]=s7>>21;s8+=carry[7];s7-=carry[7]<<21;
  carry[8]=s8>>21;s9+=carry[8];s8-=carry[8]<<21;
  carry[9]=s9>>21;s10+=carry[9];s9-=carry[9]<<21;
  carry[10]=s10>>21;s11+=carry[10];s10-=carry[10]<<21;
  s[0]=(unsigned char)s0;s[1]=(unsigned char)(s0>>8);s[2]=(unsigned char)((s0>>16)|(s1<<5));
  s[3]=(unsigned char)(s1>>3);s[4]=(unsigned char)(s1>>11);s[5]=(unsigned char)((s1>>19)|(s2<<2));
  s[6]=(unsigned char)(s2>>6);s[7]=(unsigned char)((s2>>14)|(s3<<7));s[8]=(unsigned char)(s3>>1);
  s[9]=(unsigned char)(s3>>9);s[10]=(unsigned char)((s3>>17)|(s4<<4));s[11]=(unsigned char)(s4>>4);
  s[12]=(unsigned char)(s4>>12);s[13]=(unsigned char)((s4>>20)|(s5<<1));s[14]=(unsigned char)(s5>>7);
  s[15]=(unsigned char)((s5>>15)|(s6<<6));s[16]=(unsigned char)(s6>>2);s[17]=(unsigned char)(s6>>10);
  s[18]=(unsigned char)((s6>>18)|(s7<<3));s[19]=(unsigned char)(s7>>5);s[20]=(unsigned char)(s7>>13);
  s[21]=(unsigned char)s8;s[22]=(unsigned char)(s8>>8);s[23]=(unsigned char)((s8>>16)|(s9<<5));
  s[24]=(unsigned char)(s9>>3);s[25]=(unsigned char)(s9>>11);s[26]=(unsigned char)((s9>>19)|(s10<<2));
  s[27]=(unsigned char)(s10>>6);s[28]=(unsigned char)((s10>>14)|(s11<<7));s[29]=(unsigned char)(s11>>1);
  s[30]=(unsigned char)(s11>>9);s[31]=(unsigned char)(s11>>17);
}

/* s = (a*b + c) mod L, all 32-byte LE. */
static void sc_muladd(unsigned char *s,const unsigned char *a,const unsigned char *b,const unsigned char *c){
  int64_t a0=2097151&load3(a),a1=2097151&(load4(a+2)>>5),a2=2097151&(load3(a+5)>>2),a3=2097151&(load4(a+7)>>7),
    a4=2097151&(load4(a+10)>>4),a5=2097151&(load3(a+13)>>1),a6=2097151&(load4(a+15)>>6),a7=2097151&(load3(a+18)>>3),
    a8=2097151&load3(a+21),a9=2097151&(load4(a+23)>>5),a10=2097151&(load3(a+26)>>2),a11=(load4(a+28)>>7);
  int64_t b0=2097151&load3(b),b1=2097151&(load4(b+2)>>5),b2=2097151&(load3(b+5)>>2),b3=2097151&(load4(b+7)>>7),
    b4=2097151&(load4(b+10)>>4),b5=2097151&(load3(b+13)>>1),b6=2097151&(load4(b+15)>>6),b7=2097151&(load3(b+18)>>3),
    b8=2097151&load3(b+21),b9=2097151&(load4(b+23)>>5),b10=2097151&(load3(b+26)>>2),b11=(load4(b+28)>>7);
  int64_t c0=2097151&load3(c),c1=2097151&(load4(c+2)>>5),c2=2097151&(load3(c+5)>>2),c3=2097151&(load4(c+7)>>7),
    c4=2097151&(load4(c+10)>>4),c5=2097151&(load3(c+13)>>1),c6=2097151&(load4(c+15)>>6),c7=2097151&(load3(c+18)>>3),
    c8=2097151&load3(c+21),c9=2097151&(load4(c+23)>>5),c10=2097151&(load3(c+26)>>2),c11=(load4(c+28)>>7);
  int64_t s0,s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11,s12,s13,s14,s15,s16,s17,s18,s19,s20,s21,s22,s23;
  int64_t carry[23];
  s0=c0+a0*b0;
  s1=c1+a0*b1+a1*b0;
  s2=c2+a0*b2+a1*b1+a2*b0;
  s3=c3+a0*b3+a1*b2+a2*b1+a3*b0;
  s4=c4+a0*b4+a1*b3+a2*b2+a3*b1+a4*b0;
  s5=c5+a0*b5+a1*b4+a2*b3+a3*b2+a4*b1+a5*b0;
  s6=c6+a0*b6+a1*b5+a2*b4+a3*b3+a4*b2+a5*b1+a6*b0;
  s7=c7+a0*b7+a1*b6+a2*b5+a3*b4+a4*b3+a5*b2+a6*b1+a7*b0;
  s8=c8+a0*b8+a1*b7+a2*b6+a3*b5+a4*b4+a5*b3+a6*b2+a7*b1+a8*b0;
  s9=c9+a0*b9+a1*b8+a2*b7+a3*b6+a4*b5+a5*b4+a6*b3+a7*b2+a8*b1+a9*b0;
  s10=c10+a0*b10+a1*b9+a2*b8+a3*b7+a4*b6+a5*b5+a6*b4+a7*b3+a8*b2+a9*b1+a10*b0;
  s11=c11+a0*b11+a1*b10+a2*b9+a3*b8+a4*b7+a5*b6+a6*b5+a7*b4+a8*b3+a9*b2+a10*b1+a11*b0;
  s12=a1*b11+a2*b10+a3*b9+a4*b8+a5*b7+a6*b6+a7*b5+a8*b4+a9*b3+a10*b2+a11*b1;
  s13=a2*b11+a3*b10+a4*b9+a5*b8+a6*b7+a7*b6+a8*b5+a9*b4+a10*b3+a11*b2;
  s14=a3*b11+a4*b10+a5*b9+a6*b8+a7*b7+a8*b6+a9*b5+a10*b4+a11*b3;
  s15=a4*b11+a5*b10+a6*b9+a7*b8+a8*b7+a9*b6+a10*b5+a11*b4;
  s16=a5*b11+a6*b10+a7*b9+a8*b8+a9*b7+a10*b6+a11*b5;
  s17=a6*b11+a7*b10+a8*b9+a9*b8+a10*b7+a11*b6;
  s18=a7*b11+a8*b10+a9*b9+a10*b8+a11*b7;
  s19=a8*b11+a9*b10+a10*b9+a11*b8;
  s20=a9*b11+a10*b10+a11*b9;
  s21=a10*b11+a11*b10;
  s22=a11*b11;
  s23=0;
  carry[0]=(s0+(1<<20))>>21;s1+=carry[0];s0-=carry[0]<<21;
  carry[2]=(s2+(1<<20))>>21;s3+=carry[2];s2-=carry[2]<<21;
  carry[4]=(s4+(1<<20))>>21;s5+=carry[4];s4-=carry[4]<<21;
  carry[6]=(s6+(1<<20))>>21;s7+=carry[6];s6-=carry[6]<<21;
  carry[8]=(s8+(1<<20))>>21;s9+=carry[8];s8-=carry[8]<<21;
  carry[10]=(s10+(1<<20))>>21;s11+=carry[10];s10-=carry[10]<<21;
  carry[12]=(s12+(1<<20))>>21;s13+=carry[12];s12-=carry[12]<<21;
  carry[14]=(s14+(1<<20))>>21;s15+=carry[14];s14-=carry[14]<<21;
  carry[16]=(s16+(1<<20))>>21;s17+=carry[16];s16-=carry[16]<<21;
  carry[18]=(s18+(1<<20))>>21;s19+=carry[18];s18-=carry[18]<<21;
  carry[20]=(s20+(1<<20))>>21;s21+=carry[20];s20-=carry[20]<<21;
  carry[22]=(s22+(1<<20))>>21;s23+=carry[22];s22-=carry[22]<<21;
  carry[1]=(s1+(1<<20))>>21;s2+=carry[1];s1-=carry[1]<<21;
  carry[3]=(s3+(1<<20))>>21;s4+=carry[3];s3-=carry[3]<<21;
  carry[5]=(s5+(1<<20))>>21;s6+=carry[5];s5-=carry[5]<<21;
  carry[7]=(s7+(1<<20))>>21;s8+=carry[7];s7-=carry[7]<<21;
  carry[9]=(s9+(1<<20))>>21;s10+=carry[9];s9-=carry[9]<<21;
  carry[11]=(s11+(1<<20))>>21;s12+=carry[11];s11-=carry[11]<<21;
  carry[13]=(s13+(1<<20))>>21;s14+=carry[13];s13-=carry[13]<<21;
  carry[15]=(s15+(1<<20))>>21;s16+=carry[15];s15-=carry[15]<<21;
  carry[17]=(s17+(1<<20))>>21;s18+=carry[17];s17-=carry[17]<<21;
  carry[19]=(s19+(1<<20))>>21;s20+=carry[19];s19-=carry[19]<<21;
  carry[21]=(s21+(1<<20))>>21;s22+=carry[21];s21-=carry[21]<<21;
  s11+=s23*666643;s12+=s23*470296;s13+=s23*654183;s14-=s23*997805;s15+=s23*136657;s16-=s23*683901;
  s10+=s22*666643;s11+=s22*470296;s12+=s22*654183;s13-=s22*997805;s14+=s22*136657;s15-=s22*683901;
  s9+=s21*666643;s10+=s21*470296;s11+=s21*654183;s12-=s21*997805;s13+=s21*136657;s14-=s21*683901;
  s8+=s20*666643;s9+=s20*470296;s10+=s20*654183;s11-=s20*997805;s12+=s20*136657;s13-=s20*683901;
  s7+=s19*666643;s8+=s19*470296;s9+=s19*654183;s10-=s19*997805;s11+=s19*136657;s12-=s19*683901;
  s6+=s18*666643;s7+=s18*470296;s8+=s18*654183;s9-=s18*997805;s10+=s18*136657;s11-=s18*683901;
  carry[6]=(s6+(1<<20))>>21;s7+=carry[6];s6-=carry[6]<<21;
  carry[8]=(s8+(1<<20))>>21;s9+=carry[8];s8-=carry[8]<<21;
  carry[10]=(s10+(1<<20))>>21;s11+=carry[10];s10-=carry[10]<<21;
  carry[12]=(s12+(1<<20))>>21;s13+=carry[12];s12-=carry[12]<<21;
  carry[14]=(s14+(1<<20))>>21;s15+=carry[14];s14-=carry[14]<<21;
  carry[16]=(s16+(1<<20))>>21;s17+=carry[16];s16-=carry[16]<<21;
  carry[7]=(s7+(1<<20))>>21;s8+=carry[7];s7-=carry[7]<<21;
  carry[9]=(s9+(1<<20))>>21;s10+=carry[9];s9-=carry[9]<<21;
  carry[11]=(s11+(1<<20))>>21;s12+=carry[11];s11-=carry[11]<<21;
  carry[13]=(s13+(1<<20))>>21;s14+=carry[13];s13-=carry[13]<<21;
  carry[15]=(s15+(1<<20))>>21;s16+=carry[15];s15-=carry[15]<<21;
  s5+=s17*666643;s6+=s17*470296;s7+=s17*654183;s8-=s17*997805;s9+=s17*136657;s10-=s17*683901;
  s4+=s16*666643;s5+=s16*470296;s6+=s16*654183;s7-=s16*997805;s8+=s16*136657;s9-=s16*683901;
  s3+=s15*666643;s4+=s15*470296;s5+=s15*654183;s6-=s15*997805;s7+=s15*136657;s8-=s15*683901;
  s2+=s14*666643;s3+=s14*470296;s4+=s14*654183;s5-=s14*997805;s6+=s14*136657;s7-=s14*683901;
  s1+=s13*666643;s2+=s13*470296;s3+=s13*654183;s4-=s13*997805;s5+=s13*136657;s6-=s13*683901;
  s0+=s12*666643;s1+=s12*470296;s2+=s12*654183;s3-=s12*997805;s4+=s12*136657;s5-=s12*683901;s12=0;
  carry[0]=(s0+(1<<20))>>21;s1+=carry[0];s0-=carry[0]<<21;
  carry[2]=(s2+(1<<20))>>21;s3+=carry[2];s2-=carry[2]<<21;
  carry[4]=(s4+(1<<20))>>21;s5+=carry[4];s4-=carry[4]<<21;
  carry[6]=(s6+(1<<20))>>21;s7+=carry[6];s6-=carry[6]<<21;
  carry[8]=(s8+(1<<20))>>21;s9+=carry[8];s8-=carry[8]<<21;
  carry[10]=(s10+(1<<20))>>21;s11+=carry[10];s10-=carry[10]<<21;
  carry[1]=(s1+(1<<20))>>21;s2+=carry[1];s1-=carry[1]<<21;
  carry[3]=(s3+(1<<20))>>21;s4+=carry[3];s3-=carry[3]<<21;
  carry[5]=(s5+(1<<20))>>21;s6+=carry[5];s5-=carry[5]<<21;
  carry[7]=(s7+(1<<20))>>21;s8+=carry[7];s7-=carry[7]<<21;
  carry[9]=(s9+(1<<20))>>21;s10+=carry[9];s9-=carry[9]<<21;
  carry[11]=(s11+(1<<20))>>21;s12+=carry[11];s11-=carry[11]<<21;
  s0+=s12*666643;s1+=s12*470296;s2+=s12*654183;s3-=s12*997805;s4+=s12*136657;s5-=s12*683901;s12=0;
  carry[0]=s0>>21;s1+=carry[0];s0-=carry[0]<<21;
  carry[1]=s1>>21;s2+=carry[1];s1-=carry[1]<<21;
  carry[2]=s2>>21;s3+=carry[2];s2-=carry[2]<<21;
  carry[3]=s3>>21;s4+=carry[3];s3-=carry[3]<<21;
  carry[4]=s4>>21;s5+=carry[4];s4-=carry[4]<<21;
  carry[5]=s5>>21;s6+=carry[5];s5-=carry[5]<<21;
  carry[6]=s6>>21;s7+=carry[6];s6-=carry[6]<<21;
  carry[7]=s7>>21;s8+=carry[7];s7-=carry[7]<<21;
  carry[8]=s8>>21;s9+=carry[8];s8-=carry[8]<<21;
  carry[9]=s9>>21;s10+=carry[9];s9-=carry[9]<<21;
  carry[10]=s10>>21;s11+=carry[10];s10-=carry[10]<<21;
  carry[11]=s11>>21;s12+=carry[11];s11-=carry[11]<<21;
  s0+=s12*666643;s1+=s12*470296;s2+=s12*654183;s3-=s12*997805;s4+=s12*136657;s5-=s12*683901;
  carry[0]=s0>>21;s1+=carry[0];s0-=carry[0]<<21;
  carry[1]=s1>>21;s2+=carry[1];s1-=carry[1]<<21;
  carry[2]=s2>>21;s3+=carry[2];s2-=carry[2]<<21;
  carry[3]=s3>>21;s4+=carry[3];s3-=carry[3]<<21;
  carry[4]=s4>>21;s5+=carry[4];s4-=carry[4]<<21;
  carry[5]=s5>>21;s6+=carry[5];s5-=carry[5]<<21;
  carry[6]=s6>>21;s7+=carry[6];s6-=carry[6]<<21;
  carry[7]=s7>>21;s8+=carry[7];s7-=carry[7]<<21;
  carry[8]=s8>>21;s9+=carry[8];s8-=carry[8]<<21;
  carry[9]=s9>>21;s10+=carry[9];s9-=carry[9]<<21;
  carry[10]=s10>>21;s11+=carry[10];s10-=carry[10]<<21;
  s[0]=(unsigned char)s0;s[1]=(unsigned char)(s0>>8);s[2]=(unsigned char)((s0>>16)|(s1<<5));
  s[3]=(unsigned char)(s1>>3);s[4]=(unsigned char)(s1>>11);s[5]=(unsigned char)((s1>>19)|(s2<<2));
  s[6]=(unsigned char)(s2>>6);s[7]=(unsigned char)((s2>>14)|(s3<<7));s[8]=(unsigned char)(s3>>1);
  s[9]=(unsigned char)(s3>>9);s[10]=(unsigned char)((s3>>17)|(s4<<4));s[11]=(unsigned char)(s4>>4);
  s[12]=(unsigned char)(s4>>12);s[13]=(unsigned char)((s4>>20)|(s5<<1));s[14]=(unsigned char)(s5>>7);
  s[15]=(unsigned char)((s5>>15)|(s6<<6));s[16]=(unsigned char)(s6>>2);s[17]=(unsigned char)(s6>>10);
  s[18]=(unsigned char)((s6>>18)|(s7<<3));s[19]=(unsigned char)(s7>>5);s[20]=(unsigned char)(s7>>13);
  s[21]=(unsigned char)s8;s[22]=(unsigned char)(s8>>8);s[23]=(unsigned char)((s8>>16)|(s9<<5));
  s[24]=(unsigned char)(s9>>3);s[25]=(unsigned char)(s9>>11);s[26]=(unsigned char)((s9>>19)|(s10<<2));
  s[27]=(unsigned char)(s10>>6);s[28]=(unsigned char)((s10>>14)|(s11<<7));s[29]=(unsigned char)(s11>>1);
  s[30]=(unsigned char)(s11>>9);s[31]=(unsigned char)(s11>>17);
}

/* ---------------- Ed25519 operations ---------------- */

static void sha512_3(const unsigned char *m1,intptr_t l1,const unsigned char *m2,intptr_t l2,
                     const unsigned char *m3,intptr_t l3,unsigned char out[64]){
  rktcrypto_sha512_ctx_t c;
  rktcrypto_sha512_core_init(&c,rktcrypto_sha512_iv);
  if(l1)rktcrypto_sha512_core_update(&c,m1,l1);
  if(l2)rktcrypto_sha512_core_update(&c,m2,l2);
  if(l3)rktcrypto_sha512_core_update(&c,m3,l3);
  rktcrypto_sha512_core_final(&c,out,64);
}

int rktcrypto_ed25519_pubkey(unsigned char pk[32],const unsigned char seed[32]){
  unsigned char h[64]; ge A,B; fe d2;
  sha512_3(seed,32,0,0,0,0,h);
  h[0]&=248;h[31]&=127;h[31]|=64;
  curve_d2(d2); (void)B;
  ge_scalarmult_base(&A,h,d2);
  ge_tobytes(pk,&A);
  return 1;
}

int rktcrypto_ed25519_sign(unsigned char sig[64],
                           const unsigned char *msg,intptr_t msglen,
                           const unsigned char seed[32]){
  unsigned char h[64],rr[64],k[64],pk[32],a[32]; ge R,A,B; fe d2;
  sha512_3(seed,32,0,0,0,0,h);
  h[0]&=248;h[31]&=127;h[31]|=64;
  memcpy(a,h,32);
  curve_d2(d2); (void)B;
  ge_scalarmult_base(&A,a,d2); ge_tobytes(pk,&A);
  sha512_3(h+32,32,msg,msglen,0,0,rr);
  sc_reduce(rr);
  ge_scalarmult_base(&R,rr,d2); ge_tobytes(sig,&R);
  sha512_3(sig,32,pk,32,msg,msglen,k);
  sc_reduce(k);
  sc_muladd(sig+32,k,a,rr);
  return 1;
}

int rktcrypto_ed25519_verify(const unsigned char sig[64],
                             const unsigned char *msg,intptr_t msglen,
                             const unsigned char pk[32]){
  unsigned char h[64],rcheck[32]; ge A,B,R,sB,hA,neg,sBmhA; fe d2; int i,diff=0;
  if(sig[63]&224) return 0;
  curve_d2(d2); ge_base(&B);
  if(!ge_frombytes(&A,pk)) return 0;
  if(!ge_frombytes(&R,sig)) return 0;
  sha512_3(sig,32,pk,32,msg,msglen,h);
  sc_reduce(h);
  ge_scalarmult_base(&sB,sig+32,d2); (void)B;
  ge_scalarmult_win(&hA,h,&A,d2);
  neg=hA; fe_neg(neg.X,hA.X); fe_neg(neg.T,hA.T);
  ge_add(&sBmhA,&sB,&neg,d2);
  ge_tobytes(rcheck,&sBmhA);
  for(i=0;i<32;i++) diff|=rcheck[i]^sig[i];
  return diff==0;
}
