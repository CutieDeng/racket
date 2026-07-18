/* Fixed-width big-integer arithmetic for RSA (and future DH/DSA).

   From-scratch: little-endian 64-bit limbs, Montgomery multiplication (CIOS),
   4-bit/5-bit fixed-window modular exponentiation. bn_modexp is bit-exact with
   OpenSSL BN_mod_exp over random 2048-bit inputs. Performance note: the CIOS
   montmul is portable C; matching OpenSSL's bn_mul_mont throughput needs an
   asm carry-chain kernel (a scoped follow-up, like the P-256 field kernels). */
#include "rktcrypto_bn.h"
static void bn_norm(BN*a){ while(a->top>0 && a->d[a->top-1]==0) a->top--; }
void bn_zero(BN*a){ memset(a->d,0,sizeof a->d); a->top=0; }
void bn_copy(BN*r,const BN*a){ memcpy(r->d,a->d,sizeof r->d); r->top=a->top; }
void bn_set_u64(BN*a,uint64_t v){ bn_zero(a); if(v){a->d[0]=v;a->top=1;} }
int  bn_is_zero(const BN*a){ return a->top==0; }
int  bn_cmp(const BN*a,const BN*b){
  if(a->top!=b->top) return a->top>b->top?1:-1;
  for(int i=a->top-1;i>=0;i--) if(a->d[i]!=b->d[i]) return a->d[i]>b->d[i]?1:-1;
  return 0;
}
void bn_from_be(BN*a,const unsigned char*p,int len){
  bn_zero(a); int limb=0,sh=0;
  for(int i=len-1;i>=0;i--){ a->d[limb]|=(uint64_t)p[i]<<sh; sh+=8; if(sh==64){sh=0;limb++;} }
  a->top=(len*8+63)/64; bn_norm(a);
}
void bn_to_be(unsigned char*p,int len,const BN*a){
  for(int i=0;i<len;i++){ int bit=(len-1-i)*8; int limb=bit/64,sh=bit%64;
    p[i]=(limb<a->top)?(unsigned char)(a->d[limb]>>sh):0; }
}
int bn_bits(const BN*a){ if(a->top==0)return 0; uint64_t hi=a->d[a->top-1]; int b=(a->top-1)*64; while(hi){b++;hi>>=1;} return b; }
int bn_getbit(const BN*a,int i){ int limb=i/64,sh=i%64; return (limb<a->top)?(int)((a->d[limb]>>sh)&1):0; }
void bn_add(BN*r,const BN*a,const BN*b){
  int n=a->top>b->top?a->top:b->top; u128 c=0;
  for(int i=0;i<n;i++){ u128 s=(u128)(i<a->top?a->d[i]:0)+(i<b->top?b->d[i]:0)+c; r->d[i]=(uint64_t)s; c=s>>64; }
  r->d[n]=(uint64_t)c; for(int i=n+1;i<BN_LIMBS;i++)r->d[i]=0; r->top=n+(c?1:0); bn_norm(r);
}
void bn_sub(BN*r,const BN*a,const BN*b){   /* a>=b */
  u128 br=0;
  for(int i=0;i<a->top;i++){ u128 s=(u128)a->d[i]-(i<b->top?b->d[i]:0)-br; r->d[i]=(uint64_t)s; br=(s>>64)&1; }
  for(int i=a->top;i<BN_LIMBS;i++)r->d[i]=0; r->top=a->top; bn_norm(r);
}
void bn_mul(BN*r,const BN*a,const BN*b){
  uint64_t t[BN_LIMBS]; int n=a->top+b->top; for(int i=0;i<=n&&i<BN_LIMBS;i++)t[i]=0;
  for(int i=0;i<a->top;i++){ u128 c=0;
    for(int j=0;j<b->top;j++){ u128 s=(u128)a->d[i]*b->d[j]+t[i+j]+c; t[i+j]=(uint64_t)s; c=s>>64; }
    t[i+b->top]+=(uint64_t)c; }
  for(int i=0;i<n&&i<BN_LIMBS;i++)r->d[i]=t[i]; for(int i=n;i<BN_LIMBS;i++)r->d[i]=0; r->top=n; bn_norm(r);
}
void bn_shl(BN*r,const BN*a,int s){
  int wsh=s/64,bsh=s%64; uint64_t t[BN_LIMBS]; memset(t,0,sizeof t);
  for(int i=a->top-1;i>=0;i--){ u128 v=(u128)a->d[i]<<bsh; t[i+wsh]|=(uint64_t)v; if(bsh)t[i+wsh+1]|=(uint64_t)(v>>64); }
  memcpy(r->d,t,sizeof r->d); r->top=a->top+wsh+1; bn_norm(r);
}
void bn_mod(BN*r,const BN*a,const BN*m){
  BN x; bn_copy(&x,a); int sh=bn_bits(&x)-bn_bits(m);
  for(int s=sh;s>=0;s--){ BN ms; bn_shl(&ms,m,s); if(bn_cmp(&x,&ms)>=0) bn_sub(&x,&x,&ms); }
  bn_copy(r,&x);
}
uint64_t bn_mont_n0(const BN*m){ uint64_t x=m->d[0],y=x; for(int i=0;i<5;i++)y*=2-x*y; return (uint64_t)(0-y); }
void bn_mont_rr(BN*rr,const BN*m){   /* R^2 mod m via 128*k modular doublings from 1 */
  int k=m->top; BN t; bn_set_u64(&t,1);
  for(int i=0;i<128*k;i++){ BN d; bn_add(&d,&t,&t); if(bn_cmp(&d,m)>=0) bn_sub(&d,&d,m); bn_copy(&t,&d); }
  bn_copy(rr,&t);
}
void bn_mont_setup(uint64_t*n0,BN*rr,const BN*m){ *n0=bn_mont_n0(m); bn_mont_rr(rr,m); }
/* Fixed-size CIOS montmul: with K a compile-time constant clang unrolls the
   inner loops (no branch/counter overhead, better carry scheduling). */
#define MONTMUL_FIXED(K) \
static void __attribute__((unused)) bn_montmul_k##K(BN*r,const BN*a,const BN*b,const BN*m,uint64_t n0){ \
  uint64_t t[K+2]; for(int i=0;i<K+2;i++)t[i]=0; \
  const uint64_t*bd=b->d,*md=m->d,*ad=a->d; int at=a->top; \
  for(int i=0;i<K;i++){ u128 c=0; uint64_t ai=(i<at)?ad[i]:0; \
    for(int j=0;j<K;j++){ u128 s=(u128)ai*bd[j]+t[j]+c; t[j]=(uint64_t)s; c=s>>64; } \
    { u128 s=(u128)t[K]+c; t[K]=(uint64_t)s; t[K+1]+=(uint64_t)(s>>64); } \
    uint64_t mi=t[0]*n0; c=0; \
    for(int j=0;j<K;j++){ u128 s=(u128)mi*md[j]+t[j]+c; t[j]=(uint64_t)s; c=s>>64; } \
    { u128 s=(u128)t[K]+c; t[K]=(uint64_t)s; t[K+1]+=(uint64_t)(s>>64); } \
    for(int j=0;j<=K;j++)t[j]=t[j+1]; t[K+1]=0; } \
  int ge=(t[K]!=0); \
  if(!ge) for(int i=K-1;i>=0;i--){ if(t[i]!=md[i]){ge=t[i]>md[i];break;} } \
  if(ge){ u128 br=0; for(int i=0;i<K;i++){ u128 s=(u128)t[i]-md[i]-br; t[i]=(uint64_t)s; br=(s>>64)&1; } } \
  for(int i=0;i<K;i++)r->d[i]=t[i]; for(int i=K;i<BN_LIMBS;i++)r->d[i]=0; r->top=K; \
  while(r->top>0&&r->d[r->top-1]==0)r->top--; }
MONTMUL_FIXED(16)
/* k=32: full unroll spills 32 limbs; an 8x-unrolled rolled loop keeps register
   pressure sane while cutting branch overhead. */
static void bn_montmul_k32u(BN*r,const BN*a,const BN*b,const BN*m,uint64_t n0){
  const int K=32; uint64_t t[34]; for(int i=0;i<K+2;i++)t[i]=0;
  const uint64_t*bd=b->d,*md=m->d,*ad=a->d; int at=a->top;
  for(int i=0;i<K;i++){ u128 c=0; uint64_t ai=(i<at)?ad[i]:0;
    _Pragma("clang loop unroll_count(8)")
    for(int j=0;j<K;j++){ u128 s=(u128)ai*bd[j]+t[j]+c; t[j]=(uint64_t)s; c=s>>64; }
    { u128 s=(u128)t[K]+c; t[K]=(uint64_t)s; t[K+1]+=(uint64_t)(s>>64); }
    uint64_t mi=t[0]*n0; c=0;
    _Pragma("clang loop unroll_count(8)")
    for(int j=0;j<K;j++){ u128 s=(u128)mi*md[j]+t[j]+c; t[j]=(uint64_t)s; c=s>>64; }
    { u128 s=(u128)t[K]+c; t[K]=(uint64_t)s; t[K+1]+=(uint64_t)(s>>64); }
    for(int j=0;j<=K;j++)t[j]=t[j+1]; t[K+1]=0; }
  int ge=(t[K]!=0);
  if(!ge) for(int i=K-1;i>=0;i--){ if(t[i]!=md[i]){ge=t[i]>md[i];break;} }
  if(ge){ u128 br=0; for(int i=0;i<K;i++){ u128 s=(u128)t[i]-md[i]-br; t[i]=(uint64_t)s; br=(s>>64)&1; } }
  for(int i=0;i<K;i++)r->d[i]=t[i]; for(int i=K;i<BN_LIMBS;i++)r->d[i]=0; r->top=K;
  while(r->top>0&&r->d[r->top-1]==0)r->top--; }
/* Montgomery multiply r=a*b*R^-1 mod m (CIOS). a,b<m. Buffers sized to k. */
static void bn_montmul_gen(BN*r,const BN*a,const BN*b,const BN*m,uint64_t n0){
  int k=m->top; uint64_t t[BN_LIMBS+2]; for(int i=0;i<=k+1;i++)t[i]=0;
  const uint64_t*bd=b->d; int bt=b->top, at=a->top; const uint64_t*ad=a->d,*md=m->d;
  for(int i=0;i<k;i++){
    u128 c=0; uint64_t ai=(i<at)?ad[i]:0;
    for(int j=0;j<bt;j++){ u128 s=(u128)ai*bd[j]+t[j]+c; t[j]=(uint64_t)s; c=s>>64; }
    for(int j=bt;j<k&&c;j++){ u128 s=(u128)t[j]+c; t[j]=(uint64_t)s; c=s>>64; }
    { u128 s=(u128)t[k]+c; t[k]=(uint64_t)s; t[k+1]+=(uint64_t)(s>>64); }
    uint64_t mi=t[0]*n0; c=0;
    for(int j=0;j<k;j++){ u128 s=(u128)mi*md[j]+t[j]+c; t[j]=(uint64_t)s; c=s>>64; }
    { u128 s=(u128)t[k]+c; t[k]=(uint64_t)s; t[k+1]+=(uint64_t)(s>>64); }
    for(int j=0;j<=k;j++)t[j]=t[j+1]; t[k+1]=0;
  }
  int ge=(t[k]!=0);
  if(!ge) for(int i=k-1;i>=0;i--){ if(t[i]!=md[i]){ge=t[i]>md[i];break;} }
  if(ge){ u128 br=0; for(int i=0;i<k;i++){ u128 s=(u128)t[i]-md[i]-br; t[i]=(uint64_t)s; br=(s>>64)&1; } }
  for(int i=0;i<k;i++)r->d[i]=t[i]; for(int i=k;i<BN_LIMBS;i++)r->d[i]=0; r->top=k; bn_norm(r);
}
#if defined(__aarch64__) && defined(__APPLE__)
/* Streaming asm kernel (rktcrypto_bn_asm.S): register-resident accumulator,
   1.23x over the unrolled C at k=16 -- the RSA-CRT (mod p/q) hot path. */
extern void bn_mul_mont_k16(uint64_t*r,const uint64_t*a,const uint64_t*b,const uint64_t*m,uint64_t n0);
static void bn_montmul_k16asm(BN*r,const BN*a,const BN*b,const BN*m,uint64_t n0){
  uint64_t ab[16],bb[16]; int i;
  for(i=0;i<16;i++){ ab[i]=(i<a->top)?a->d[i]:0; bb[i]=(i<b->top)?b->d[i]:0; }
  bn_mul_mont_k16(r->d, ab, bb, m->d, n0);
  for(i=16;i<BN_LIMBS;i++) r->d[i]=0; r->top=16; while(r->top>0&&r->d[r->top-1]==0) r->top--;
}
#endif
void bn_montmul(BN*r,const BN*a,const BN*b,const BN*m,uint64_t n0){
  if(m->top==32) bn_montmul_k32u(r,a,b,m,n0);
  else if(m->top==16)
#if defined(__aarch64__) && defined(__APPLE__)
    bn_montmul_k16asm(r,a,b,m,n0);
#else
    bn_montmul_k16(r,a,b,m,n0);
#endif
  else bn_montmul_gen(r,a,b,m,n0);
}
void bn_modexp_pre(BN*r,const BN*base,const BN*exp,const BN*m,uint64_t n0,const BN*rr){
  BN one,mbase,acc,br; bn_set_u64(&one,1);
  bn_mod(&br,base,m); bn_montmul(&mbase,&br,rr,m,n0);
  int eb=bn_bits(exp);
  int w = eb<=32 ? 1 : (eb<=256 ? 4 : 5); int tn=1<<w;
  BN tbl[32];
  bn_montmul(&tbl[0],&one,rr,m,n0); bn_copy(&tbl[1],&mbase);
  for(int i=2;i<tn;i++) bn_montmul(&tbl[i],&tbl[i-1],&mbase,m,n0);
  bn_copy(&acc,&tbl[0]);
  int top=((eb+w-1)/w)*w;
  for(int i=top-w;i>=0;i-=w){
    for(int s=0;s<w;s++) bn_montmul(&acc,&acc,&acc,m,n0);
    int d=0; for(int j=w-1;j>=0;j--) d=(d<<1)|bn_getbit(exp,i+j);
    if(d) bn_montmul(&acc,&acc,&tbl[d],m,n0);
  }
  bn_montmul(r,&acc,&one,m,n0);
}
void bn_modexp(BN*r,const BN*base,const BN*exp,const BN*m){
  uint64_t n0; BN rr; bn_mont_setup(&n0,&rr,m); bn_modexp_pre(r,base,exp,m,n0,&rr);
}
