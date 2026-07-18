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
/* Remainder r = a mod m by Knuth Algorithm D (word-wise long division) --
   ~110x faster than the old bit-by-bit shift/subtract, which was 44 us per
   2048-mod-1024 and dominated RSA-CRT signing (3 such reductions). Bit-exact
   with the old version over 300k random inputs incl. all size/normalization
   edges. */
void bn_mod(BN*r,const BN*a,const BN*m){
  int n=m->top,i,j;
  if(n==0){ bn_copy(r,a); return; }
  if(n==1){ uint64_t d=m->d[0],rem=0; for(i=a->top-1;i>=0;i--){ u128 cur=((u128)rem<<64)|a->d[i]; rem=(uint64_t)(cur%d); }
    bn_zero(r); if(rem){ r->d[0]=rem; r->top=1; } return; }
  if(bn_cmp(a,m)<0){ bn_copy(r,a); return; }
  { int s=0; uint64_t vn[BN_LIMBS],un[BN_LIMBS+1]; int an=a->top,mlen;
    { uint64_t t=m->d[n-1]; while(!(t&0x8000000000000000ULL)){ t<<=1; s++; } }   /* normalize shift */
    for(i=0;i<BN_LIMBS;i++){ vn[i]=0; un[i]=0; } un[BN_LIMBS]=0;
    if(s){ for(i=n-1;i>0;i--) vn[i]=(m->d[i]<<s)|(m->d[i-1]>>(64-s)); vn[0]=m->d[0]<<s;
      un[an]=a->d[an-1]>>(64-s); for(i=an-1;i>0;i--) un[i]=(a->d[i]<<s)|(a->d[i-1]>>(64-s)); un[0]=a->d[0]<<s; }
    else { for(i=0;i<n;i++) vn[i]=m->d[i]; for(i=0;i<an;i++) un[i]=a->d[i]; un[an]=0; }
    mlen=an-n;
    for(j=mlen;j>=0;j--){
      u128 num=((u128)un[j+n]<<64)|un[j+n-1];
      uint64_t qhat=(uint64_t)(num/vn[n-1]); u128 rhat=num%vn[n-1];
      while(qhat!=0 && (u128)qhat*vn[n-2] > (((u128)(uint64_t)rhat<<64)|un[j+n-2])){ qhat--; rhat+=vn[n-1]; if(rhat>>64) break; }
      { u128 borrow=0,carry=0; for(i=0;i<n;i++){ u128 p=(u128)qhat*vn[i]+carry; carry=p>>64;
          u128 t=(u128)un[j+i]-(uint64_t)p-borrow; un[j+i]=(uint64_t)t; borrow=(t>>64)&1; }
        { u128 t=(u128)un[j+n]-carry-borrow; un[j+n]=(uint64_t)t;
          if((t>>64)&1){ u128 c=0; for(i=0;i<n;i++){ u128 s2=(u128)un[j+i]+vn[i]+c; un[j+i]=(uint64_t)s2; c=s2>>64; } un[j+n]+=(uint64_t)c; } } }
    }
    bn_zero(r);
    if(s){ for(i=0;i<n-1;i++) r->d[i]=(un[i]>>s)|(un[i+1]<<(64-s)); r->d[n-1]=un[n-1]>>s; }
    else for(i=0;i<n;i++) r->d[i]=un[i];
    r->top=n; bn_norm(r);
  }
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
static void __attribute__((unused)) bn_montmul_k32u(BN*r,const BN*a,const BN*b,const BN*m,uint64_t n0){
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
/* Operand-scanning 2-carry-chain asm kernel (rktcrypto_bn_op.S): 113 ns at k=16
   -- beats the FIPS kernel (129 ns) and OpenSSL (~116 ns). The RSA-CRT (mod
   p/q) hot path. (k=32 can't keep the accumulator register-resident, so it uses
   the FIPS kernel below.) */
extern void bn_mul_mont_op16(uint64_t*r,const uint64_t*a,const uint64_t*b,const uint64_t*m,uint64_t n0);
static void bn_montmul_k16asm(BN*r,const BN*a,const BN*b,const BN*m,uint64_t n0){
  uint64_t ab[16],bb[16]; int i;
  for(i=0;i<16;i++){ ab[i]=(i<a->top)?a->d[i]:0; bb[i]=(i<b->top)?b->d[i]:0; }
  bn_mul_mont_op16(r->d, ab, bb, m->d, n0);
  for(i=16;i<BN_LIMBS;i++) r->d[i]=0; r->top=16; while(r->top>0&&r->d[r->top-1]==0) r->top--;
}
#endif
#if defined(__aarch64__) && defined(__APPLE__)
/* FIPS fused product-scanning asm kernel (rktcrypto_bn_fips.S): one pass
   accumulating multiply + reduction products per column into a 3-word register
   accumulator (q computed on the fly, no separate serial reduction) -- 649 ns
   vs the unrolled C's 1167 ns at k=32. Used for the RSA-2048 public op. */
extern void bn_mul_mont_fips32(uint64_t*r,const uint64_t*a,const uint64_t*b,const uint64_t*m,uint64_t n0);
static void bn_montmul_k32asm(BN*r,const BN*a,const BN*b,const BN*m,uint64_t n0){
  uint64_t ab[32],bb[32]; int i;
  for(i=0;i<32;i++){ ab[i]=(i<a->top)?a->d[i]:0; bb[i]=(i<b->top)?b->d[i]:0; }
  bn_mul_mont_fips32(r->d, ab, bb, m->d, n0);
  for(i=32;i<BN_LIMBS;i++) r->d[i]=0; r->top=32; while(r->top>0&&r->d[r->top-1]==0) r->top--;
}
#endif
void bn_montmul(BN*r,const BN*a,const BN*b,const BN*m,uint64_t n0){
  if(m->top==32)
#if defined(__aarch64__) && defined(__APPLE__)
    bn_montmul_k32asm(r,a,b,m,n0);
#else
    bn_montmul_k32u(r,a,b,m,n0);
#endif
  else if(m->top==16)
#if defined(__aarch64__) && defined(__APPLE__)
    bn_montmul_k16asm(r,a,b,m,n0);
#else
    bn_montmul_k16(r,a,b,m,n0);
#endif
  else bn_montmul_gen(r,a,b,m,n0);
}
#if defined(__aarch64__) && defined(__APPLE__)
/* 8-way operand-scanning symmetric Montgomery squaring (rktcrypto_bn_sqr.S):
   off-diagonal products a[i]*a[j] once, doubled via shift-and-add with the
   diagonal squares folded in, then 512-bit-per-iteration reduction. 339 ns at
   k=32 -- matches OpenSSL (338 ns) and 1.41x the FIPS-via-montmul path. RSA
   verify is 16 squarings, so this is its dominant kernel. */
extern void bn_sqr_mont_8w(uint64_t*r,const uint64_t*a,const uint64_t*n,const uint64_t*n0p,int num);
static void bn_montsqr_8wasm(BN*r,const BN*a,const BN*m,uint64_t n0,int k){
  uint64_t ab[32]; int i;
  for(i=0;i<k;i++) ab[i]=(i<a->top)?a->d[i]:0;
  bn_sqr_mont_8w(r->d, ab, m->d, &n0, k);
  for(i=k;i<BN_LIMBS;i++) r->d[i]=0; r->top=k; while(r->top>0&&r->d[r->top-1]==0) r->top--;
}
#endif
/* Montgomery squaring: symmetric 2k-word square (each off-diagonal product
   once, then doubled) + SOS reduction. Bit-identical to bn_montmul(a,a); ~1.28x
   at k=32, so it speeds the squaring-dominated public exponentiation (verify).
   At k=16 the asm montmul is faster, so this routes there. */
void bn_montsqr(BN*r,const BN*a,const BN*m,uint64_t n0){
  int k=m->top,i,j; const uint64_t*ad=a->d,*md=m->d; int at=a->top;
  uint64_t z[BN_LIMBS*2];
#if defined(__aarch64__) && defined(__APPLE__)
  /* The 8-way symmetric squaring kernel wins at both k=16 and k=32. */
  if(k==16 || k==32){ bn_montsqr_8wasm(r,a,m,n0,k); return; }
#endif
  if(k!=32){ bn_montmul(r,a,a,m,n0); return; }
  for(i=0;i<2*k+1;i++)z[i]=0;
  for(i=0;i<k;i++){ u128 c=0; uint64_t ai=(i<at)?ad[i]:0;
    for(j=i+1;j<k;j++){ uint64_t aj=(j<at)?ad[j]:0; u128 s=(u128)ai*aj+z[i+j]+c; z[i+j]=(uint64_t)s; c=(uint64_t)(s>>64); }
    z[i+k]=(uint64_t)c; }
  { uint64_t carry=0; for(i=0;i<2*k;i++){ uint64_t nc=z[i]>>63; z[i]=(z[i]<<1)|carry; carry=nc; } z[2*k]=carry; }
  { u128 c=0; for(i=0;i<k;i++){ uint64_t ai=(i<at)?ad[i]:0; u128 s=(u128)ai*ai+z[2*i]+c; z[2*i]=(uint64_t)s; c=(uint64_t)(s>>64);
      s=(u128)z[2*i+1]+c; z[2*i+1]=(uint64_t)s; c=(uint64_t)(s>>64);
      { int p=2*i+2; while(c){ u128 s2=(u128)z[p]+c; z[p]=(uint64_t)s2; c=(uint64_t)(s2>>64); p++; } } } }
  for(i=0;i<k;i++){ uint64_t mi=z[i]*n0; u128 c=0;
    for(j=0;j<k;j++){ u128 s=(u128)mi*md[j]+z[i+j]+c; z[i+j]=(uint64_t)s; c=(uint64_t)(s>>64); }
    { int p=i+k; while(c){ u128 s2=(u128)z[p]+c; z[p]=(uint64_t)s2; c=(uint64_t)(s2>>64); p++; } } }
  { uint64_t *hi=z+k; int ge=(z[2*k]!=0);
    if(!ge) for(i=k-1;i>=0;i--){ if(hi[i]!=md[i]){ ge=hi[i]>md[i]; break; } }
    if(ge){ u128 br=0; for(i=0;i<k;i++){ u128 s=(u128)hi[i]-md[i]-br; hi[i]=(uint64_t)s; br=(uint64_t)((s>>64)&1); } }
    for(i=0;i<k;i++) r->d[i]=hi[i]; for(i=k;i<BN_LIMBS;i++) r->d[i]=0; r->top=k; bn_norm(r); }
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
    for(int s=0;s<w;s++) bn_montsqr(&acc,&acc,m,n0);
    int d=0; for(int j=w-1;j>=0;j--) d=(d<<1)|bn_getbit(exp,i+j);
    if(d) bn_montmul(&acc,&acc,&tbl[d],m,n0);
  }
  bn_montmul(r,&acc,&one,m,n0);
}
void bn_modexp(BN*r,const BN*base,const BN*exp,const BN*m){
  uint64_t n0; BN rr; bn_mont_setup(&n0,&rr,m); bn_modexp_pre(r,base,exp,m,n0,&rr);
}
