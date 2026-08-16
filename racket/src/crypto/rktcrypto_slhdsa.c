/* SLH-DSA-SHAKE-128s (FIPS 205 / SPHINCS+). Stateless hash-based signatures:
   WOTS+ one-time signatures, FORS few-time signatures, and a hypertree of
   XMSS Merkle trees, all keyed by SHAKE256. Parameters n=16, h=63, d=7,
   h'=9, a=12, k=14, w=16 (SHAKE-128s). From scratch, no external code. */

#include "rktcrypto.h"
#include "rktcrypto_digest.h"
#include "rktcrypto_cpu.h"
#include <string.h>
#include <stdint.h>

#define N   16
#define H   63
#define D   7
#define HP  9        /* h' = h/d */
#define A   12
#define K   14
#define LGW 4
#define W   16
#define LEN1 32
#define LEN2 3
#define LEN  35      /* len1+len2 */
#define M_DIGEST 30
#define KA   21      /* ceil(k*a/8) = ceil(168/8) */
#define IDXTREE_BYTES 7   /* ceil((h - h/d)/8) = ceil(54/8) */
#define IDXLEAF_BYTES 2   /* ceil(h/d / 8) = ceil(9/8) */

#define PK_BYTES (2*N)     /* PK.seed || PK.root = 32 */
#define SIG_BYTES (N + K*(A+1)*N + (H + D*LEN)*N)  /* 7856 */

/* streaming SHAKE256 over up to a few segments */
typedef struct { rktcrypto_keccak_ctx_t c; } shk;
static void shk_init(shk *s){ rktcrypto_keccak_core_init(&s->c,136,0x1f); }
static void shk_up(shk *s,const unsigned char *d,size_t n){ rktcrypto_keccak_core_update(&s->c,d,(intptr_t)n); }
static void shk_out(shk *s,unsigned char *o,size_t n){ rktcrypto_keccak_core_final(&s->c,o,(intptr_t)n); }

/* ---- ADRS (32 bytes) ---- */
typedef unsigned char ADRS[32];
static void adrs_zero(ADRS a){ memset(a,0,32); }
static void put4(unsigned char *p,uint32_t v){ p[0]=(unsigned char)(v>>24); p[1]=(unsigned char)(v>>16); p[2]=(unsigned char)(v>>8); p[3]=(unsigned char)v; }
static void adrs_layer(ADRS a,uint32_t x){ put4(a+0,x); }
static void adrs_tree(ADRS a,uint64_t x){ memset(a+4,0,12); a[8]=(unsigned char)(x>>56);a[9]=(unsigned char)(x>>48);a[10]=(unsigned char)(x>>40);a[11]=(unsigned char)(x>>32);a[12]=(unsigned char)(x>>24);a[13]=(unsigned char)(x>>16);a[14]=(unsigned char)(x>>8);a[15]=(unsigned char)x; }
static void adrs_type(ADRS a,uint32_t y){ put4(a+16,y); memset(a+20,0,12); }
static void adrs_kp(ADRS a,uint32_t x){ put4(a+20,x); }
static void adrs_chain(ADRS a,uint32_t x){ put4(a+24,x); }
static void adrs_hash(ADRS a,uint32_t x){ put4(a+28,x); }
static void adrs_height(ADRS a,uint32_t x){ put4(a+24,x); }
static void adrs_index(ADRS a,uint32_t x){ put4(a+28,x); }
static uint32_t adrs_get_kp(const ADRS a){ return ((uint32_t)a[20]<<24)|((uint32_t)a[21]<<16)|((uint32_t)a[22]<<8)|a[23]; }
static uint32_t adrs_get_index(const ADRS a){ return ((uint32_t)a[28]<<24)|((uint32_t)a[29]<<16)|((uint32_t)a[30]<<8)|a[31]; }

#define WOTS_HASH 0
#define WOTS_PK   1
#define TREE      2
#define FORS_TREE 3
#define FORS_ROOTS 4
#define WOTS_PRF  5
#define FORS_PRF  6

/* ---- tweakable hashes ---- */
/* T_l / F / H: SHAKE256(PKseed || ADRS || M) -> n bytes */
static void Th(const unsigned char *pkseed,const ADRS adrs,const unsigned char *m,size_t mlen,unsigned char out[N]){
  shk s; shk_init(&s); shk_up(&s,pkseed,N); shk_up(&s,adrs,32); shk_up(&s,m,mlen); shk_out(&s,out,N);
}
static void PRF(const unsigned char *pkseed,const unsigned char *skseed,const ADRS adrs,unsigned char out[N]){
  shk s; shk_init(&s); shk_up(&s,pkseed,N); shk_up(&s,adrs,32); shk_up(&s,skseed,N); shk_out(&s,out,N);
}

/* ---- 2-way batched SHAKE256 (asm/gen_keccak_f2.py) ----
   SLH-DSA's WOTS+ hash chains are independent, so pairs run through one 2-way
   Keccak-f (both NEON lanes) at ~2x throughput. Th/PRF inputs are exactly one
   rate block (PKseed 16 + ADRS 32 + M 16 = 64 <= 135) with an N=16 squeeze, so a
   single 2-way permutation suffices -- no streaming. */
#if defined(__aarch64__)
#define SLH_HAVE_2WAY 1
void keccak_f2_asm(uint64_t st[50], const uint64_t rc[24]);
static const uint64_t SLH_RC[24]={
0x0000000000000001ULL,0x0000000000008082ULL,0x800000000000808aULL,0x8000000080008000ULL,
0x000000000000808bULL,0x0000000080000001ULL,0x8000000080008081ULL,0x8000000000008009ULL,
0x000000000000008aULL,0x0000000000000088ULL,0x0000000080008009ULL,0x000000008000000aULL,
0x000000008000808bULL,0x800000000000008bULL,0x8000000000008089ULL,0x8000000000008003ULL,
0x8000000000008002ULL,0x8000000000000080ULL,0x000000000000800aULL,0x800000008000000aULL,
0x8000000080008081ULL,0x8000000000008080ULL,0x0000000080000001ULL,0x8000000080008008ULL};
/* two 1-block SHAKE256 in parallel: in{0,1} are inlen(<=135) bytes, out{0,1} are N bytes. */
static void shake256_2x(const unsigned char *in0,const unsigned char *in1,size_t inlen,
                        unsigned char out0[N],unsigned char out1[N]){
  unsigned char b0[136],b1[136]; uint64_t st[50]; int i;
  /* keccak_f2_asm uses FEAT_SHA3 (eor3/rax1/bcax/xar). On a generic aarch64
     core lacking SHA3, run the two lanes as independent scalar SHAKE256 (the
     2-way batch is exactly two standard SHAKE256, so this is bit-identical). On
     Apple the flag is always set, so this branch is never taken. */
  if (!rktcrypto_cpu_has(RKTCRYPTO_CPU_ARM_SHA3)) {
    shk s0, s1;
    shk_init(&s0); shk_up(&s0, in0, inlen); shk_out(&s0, out0, N);
    shk_init(&s1); shk_up(&s1, in1, inlen); shk_out(&s1, out1, N);
    return;
  }
  memset(b0,0,136); memset(b1,0,136); memcpy(b0,in0,inlen); memcpy(b1,in1,inlen);
  b0[inlen]^=0x1f; b0[135]^=0x80; b1[inlen]^=0x1f; b1[135]^=0x80;
  for(i=0;i<17;i++){ uint64_t w0,w1; memcpy(&w0,b0+8*i,8); memcpy(&w1,b1+8*i,8); st[2*i]=w0; st[2*i+1]=w1; }
  for(i=17;i<25;i++){ st[2*i]=0; st[2*i+1]=0; }
  keccak_f2_asm(st,SLH_RC);
  memcpy(out0,&st[0],8); memcpy(out0+8,&st[2],8);   /* lane 0 = state0's first 16 B */
  memcpy(out1,&st[1],8); memcpy(out1+8,&st[3],8);   /* lane 1 = state1 */
}
static void Th2(const unsigned char *pkseed,const ADRS a0,const unsigned char *m0,
                const ADRS a1,const unsigned char *m1,unsigned char o0[N],unsigned char o1[N]){
  unsigned char in0[64],in1[64];
  memcpy(in0,pkseed,N); memcpy(in0+N,a0,32); memcpy(in0+N+32,m0,N);
  memcpy(in1,pkseed,N); memcpy(in1+N,a1,32); memcpy(in1+N+32,m1,N);
  shake256_2x(in0,in1,64,o0,o1);
}
static void PRF2(const unsigned char *pkseed,const unsigned char *skseed,const ADRS a0,const ADRS a1,
                 unsigned char o0[N],unsigned char o1[N]){
  unsigned char in0[64],in1[64];
  memcpy(in0,pkseed,N); memcpy(in0+N,a0,32); memcpy(in0+N+32,skseed,N);
  memcpy(in1,pkseed,N); memcpy(in1+N,a1,32); memcpy(in1+N+32,skseed,N);
  shake256_2x(in0,in1,64,o0,o1);
}
/* two WOTS+ chains in lockstep: chain b runs step index j from ib for sb steps.
   Batched 2-way while both have steps left, single tail for the longer one. */
static void chain2(unsigned char *o0,const unsigned char *X0,ADRS a0,uint32_t i0,uint32_t s0,
                   unsigned char *o1,const unsigned char *X1,ADRS a1,uint32_t i1,uint32_t s1,
                   const unsigned char *pkseed){
  uint32_t j0=i0,e0=i0+s0,j1=i1,e1=i1+s1;
  memcpy(o0,X0,N); memcpy(o1,X1,N);
  while(j0<e0 && j1<e1){ adrs_hash(a0,j0); adrs_hash(a1,j1); Th2(pkseed,a0,o0,a1,o1,o0,o1); j0++; j1++; }
  for(;j0<e0;j0++){ adrs_hash(a0,j0); Th(pkseed,a0,o0,N,o0); }
  for(;j1<e1;j1++){ adrs_hash(a1,j1); Th(pkseed,a1,o1,N,o1); }
}
#endif

/* ---- WOTS+ ---- */
static void chain(unsigned char *out,const unsigned char *X,uint32_t i,uint32_t s,const unsigned char *pkseed,ADRS adrs){
  uint32_t j; memcpy(out,X,N);
  for(j=i;j<i+s;j++){ adrs_hash(adrs,j); Th(pkseed,adrs,out,N,out); }
}
static void wots_pkgen(unsigned char pk[N],const unsigned char *skseed,const unsigned char *pkseed,ADRS adrs){
  ADRS skadrs,wpk; unsigned char tmp[LEN*N],sk[N]; uint32_t i;
  memcpy(skadrs,adrs,32); adrs_type(skadrs,WOTS_PRF); adrs_kp(skadrs,adrs_get_kp(adrs));
#ifdef SLH_HAVE_2WAY
  for(i=0;i+2<=LEN;i+=2){ ADRS s0a,s1a,a0,a1; unsigned char sk0[N],sk1[N];
    memcpy(s0a,skadrs,32); adrs_chain(s0a,i);   adrs_hash(s0a,0);
    memcpy(s1a,skadrs,32); adrs_chain(s1a,i+1); adrs_hash(s1a,0);
    PRF2(pkseed,skseed,s0a,s1a,sk0,sk1);
    memcpy(a0,adrs,32); adrs_chain(a0,i);
    memcpy(a1,adrs,32); adrs_chain(a1,i+1);
    chain2(tmp+i*N,sk0,a0,0,W-1, tmp+(i+1)*N,sk1,a1,0,W-1, pkseed); }
  if(i<LEN){ adrs_chain(skadrs,i); adrs_hash(skadrs,0); PRF(pkseed,skseed,skadrs,sk);
    adrs_chain(adrs,i); chain(tmp+i*N,sk,0,W-1,pkseed,adrs); }
#else
  for(i=0;i<LEN;i++){ adrs_chain(skadrs,i); adrs_hash(skadrs,0); PRF(pkseed,skseed,skadrs,sk);
    adrs_chain(adrs,i); chain(tmp+i*N,sk,0,W-1,pkseed,adrs); }
#endif
  memcpy(wpk,adrs,32); adrs_type(wpk,WOTS_PK); adrs_kp(wpk,adrs_get_kp(adrs));
  Th(pkseed,wpk,tmp,LEN*N,pk);
}
/* base-w digits of msg (n bytes -> len1 digits) plus checksum (len2 digits) */
static void wots_msg_digits(const unsigned char msg[N],unsigned int d[LEN]){
  unsigned int i,csum=0;
  for(i=0;i<LEN1;i++){ int byte=(i*LGW)/8, sh=4-((i*LGW)%8); d[i]=(msg[byte]>>sh)&0xF; }  /* w=16 nibbles */
  for(i=0;i<LEN1;i++) csum += (W-1)-d[i];
  csum <<= (8 - ((LEN2*LGW)%8))%8;   /* left shift; LEN2*LGW=12 -> shift 4 */
  { unsigned char cb[2]; cb[0]=(unsigned char)(csum>>8); cb[1]=(unsigned char)csum;
    for(i=0;i<LEN2;i++){ int bit=i*LGW; d[LEN1+i]=(cb[bit/8]>>(4-(bit%8)))&0xF; } }
}
static void wots_sign(unsigned char *sig,const unsigned char msg[N],const unsigned char *skseed,const unsigned char *pkseed,ADRS adrs){
  unsigned int d[LEN],i; ADRS skadrs; unsigned char sk[N];
  wots_msg_digits(msg,d);
  memcpy(skadrs,adrs,32); adrs_type(skadrs,WOTS_PRF); adrs_kp(skadrs,adrs_get_kp(adrs));
#ifdef SLH_HAVE_2WAY
  for(i=0;i+2<=LEN;i+=2){ ADRS s0a,s1a,a0,a1; unsigned char sk0[N],sk1[N];
    memcpy(s0a,skadrs,32); adrs_chain(s0a,i);   adrs_hash(s0a,0);
    memcpy(s1a,skadrs,32); adrs_chain(s1a,i+1); adrs_hash(s1a,0);
    PRF2(pkseed,skseed,s0a,s1a,sk0,sk1);
    memcpy(a0,adrs,32); adrs_chain(a0,i);
    memcpy(a1,adrs,32); adrs_chain(a1,i+1);
    chain2(sig+i*N,sk0,a0,0,d[i], sig+(i+1)*N,sk1,a1,0,d[i+1], pkseed); }
  if(i<LEN){ adrs_chain(skadrs,i); adrs_hash(skadrs,0); PRF(pkseed,skseed,skadrs,sk);
    adrs_chain(adrs,i); chain(sig+i*N,sk,0,d[i],pkseed,adrs); }
#else
  for(i=0;i<LEN;i++){ adrs_chain(skadrs,i); adrs_hash(skadrs,0); PRF(pkseed,skseed,skadrs,sk);
    adrs_chain(adrs,i); chain(sig+i*N,sk,0,d[i],pkseed,adrs); }
#endif
}
static void wots_pkfromsig(unsigned char pk[N],const unsigned char *sig,const unsigned char msg[N],const unsigned char *pkseed,ADRS adrs){
  unsigned int d[LEN],i; unsigned char tmp[LEN*N]; ADRS wpk;
  wots_msg_digits(msg,d);
#ifdef SLH_HAVE_2WAY
  for(i=0;i+2<=LEN;i+=2){ ADRS a0,a1;
    memcpy(a0,adrs,32); adrs_chain(a0,i);
    memcpy(a1,adrs,32); adrs_chain(a1,i+1);
    chain2(tmp+i*N,sig+i*N,a0,d[i],(W-1)-d[i], tmp+(i+1)*N,sig+(i+1)*N,a1,d[i+1],(W-1)-d[i+1], pkseed); }
  if(i<LEN){ adrs_chain(adrs,i); chain(tmp+i*N,sig+i*N,d[i],(W-1)-d[i],pkseed,adrs); }
#else
  for(i=0;i<LEN;i++){ adrs_chain(adrs,i); chain(tmp+i*N,sig+i*N,d[i],(W-1)-d[i],pkseed,adrs); }
#endif
  memcpy(wpk,adrs,32); adrs_type(wpk,WOTS_PK); adrs_kp(wpk,adrs_get_kp(adrs));
  Th(pkseed,wpk,tmp,LEN*N,pk);
}

/* ---- XMSS ---- */
static void xmss_node(unsigned char node[N],const unsigned char *skseed,uint32_t i,uint32_t z,const unsigned char *pkseed,ADRS adrs){
  if(z==0){ adrs_type(adrs,WOTS_HASH); adrs_kp(adrs,i); wots_pkgen(node,skseed,pkseed,adrs); }
  else { unsigned char l[N],r[N],cat[2*N]; ADRS a2;
    xmss_node(l,skseed,2*i,z-1,pkseed,adrs); xmss_node(r,skseed,2*i+1,z-1,pkseed,adrs);
    memcpy(a2,adrs,32); adrs_type(a2,TREE); adrs_height(a2,z); adrs_index(a2,i);
    memcpy(cat,l,N); memcpy(cat+N,r,N); Th(pkseed,a2,cat,2*N,node); }
}
static void xmss_sign(unsigned char *sig,const unsigned char msg[N],const unsigned char *skseed,uint32_t idx,const unsigned char *pkseed,ADRS adrs){
  uint32_t j; unsigned char *auth=sig+LEN*N;
  for(j=0;j<HP;j++){ uint32_t k=(idx>>j)^1; xmss_node(auth+j*N,skseed,k,j,pkseed,adrs); }
  adrs_type(adrs,WOTS_HASH); adrs_kp(adrs,idx); wots_sign(sig,msg,skseed,pkseed,adrs);
}
static void xmss_pkfromsig(unsigned char root[N],uint32_t idx,const unsigned char *sig,const unsigned char msg[N],const unsigned char *pkseed,ADRS adrs){
  uint32_t k; const unsigned char *auth=sig+LEN*N; unsigned char node[N],tmp[2*N];
  adrs_type(adrs,WOTS_HASH); adrs_kp(adrs,idx); wots_pkfromsig(node,sig,msg,pkseed,adrs);
  adrs_type(adrs,TREE);
  for(k=0;k<HP;k++){ adrs_height(adrs,k+1);
    if(((idx>>k)&1)==0){ adrs_index(adrs,idx>>(k+1)); memcpy(tmp,node,N); memcpy(tmp+N,auth+k*N,N); }
    else { adrs_index(adrs,idx>>(k+1)); memcpy(tmp,auth+k*N,N); memcpy(tmp+N,node,N); }
    Th(pkseed,adrs,tmp,2*N,node); }
  memcpy(root,node,N);
}

/* ---- Hypertree ---- */
static void ht_sign(unsigned char *sig,const unsigned char msg[N],const unsigned char *skseed,const unsigned char *pkseed,uint64_t idx_tree,uint32_t idx_leaf){
  ADRS adrs; unsigned char root[N]; uint32_t layer; unsigned char sigtmp[(LEN+HP)*N];
  adrs_zero(adrs); adrs_tree(adrs,idx_tree);
  xmss_sign(sigtmp,msg,skseed,idx_leaf,pkseed,adrs);
  memcpy(sig,sigtmp,(LEN+HP)*N);
  xmss_pkfromsig(root,idx_leaf,sigtmp,msg,pkseed,adrs);
  for(layer=1;layer<D;layer++){
    idx_leaf=(uint32_t)(idx_tree & ((1u<<HP)-1)); idx_tree >>= HP;
    adrs_zero(adrs); adrs_layer(adrs,layer); adrs_tree(adrs,idx_tree);
    xmss_sign(sigtmp,root,skseed,idx_leaf,pkseed,adrs);
    memcpy(sig+layer*(LEN+HP)*N,sigtmp,(LEN+HP)*N);
    if(layer<D-1) xmss_pkfromsig(root,idx_leaf,sigtmp,root,pkseed,adrs);
  }
}
static int ht_verify(const unsigned char *sig,const unsigned char msg[N],const unsigned char *pkseed,uint64_t idx_tree,uint32_t idx_leaf,const unsigned char pkroot[N]){
  ADRS adrs; unsigned char node[N]; uint32_t layer;
  adrs_zero(adrs); adrs_tree(adrs,idx_tree);
  xmss_pkfromsig(node,idx_leaf,sig,msg,pkseed,adrs);
  for(layer=1;layer<D;layer++){
    idx_leaf=(uint32_t)(idx_tree & ((1u<<HP)-1)); idx_tree >>= HP;
    adrs_zero(adrs); adrs_layer(adrs,layer); adrs_tree(adrs,idx_tree);
    xmss_pkfromsig(node,idx_leaf,sig+layer*(LEN+HP)*N,node,pkseed,adrs);
  }
  return memcmp(node,pkroot,N)==0;
}

/* ---- FORS ---- */
static void fors_skgen(unsigned char sk[N],const unsigned char *skseed,const unsigned char *pkseed,ADRS adrs,uint32_t idx){
  ADRS skadrs; memcpy(skadrs,adrs,32); adrs_type(skadrs,FORS_PRF); adrs_kp(skadrs,adrs_get_kp(adrs)); adrs_index(skadrs,idx);
  PRF(pkseed,skseed,skadrs,sk);
}
static void fors_node(unsigned char node[N],const unsigned char *skseed,uint32_t i,uint32_t z,const unsigned char *pkseed,ADRS adrs){
  if(z==0){ unsigned char sk[N]; fors_skgen(sk,skseed,pkseed,adrs,i); adrs_height(adrs,0); adrs_index(adrs,i); Th(pkseed,adrs,sk,N,node); }
  else { unsigned char l[N],r[N],cat[2*N]; fors_node(l,skseed,2*i,z-1,pkseed,adrs); fors_node(r,skseed,2*i+1,z-1,pkseed,adrs);
    adrs_height(adrs,z); adrs_index(adrs,i); memcpy(cat,l,N); memcpy(cat+N,r,N); Th(pkseed,adrs,cat,2*N,node); }
}
/* md is KA bytes; extract k indices of a bits each (MSB-first) */
static void fors_indices(const unsigned char *md,uint32_t idx[K]){
  uint32_t i; unsigned int bit=0;
  for(i=0;i<K;i++){ unsigned int j,v=0; for(j=0;j<A;j++){ v=(v<<1)|((md[bit/8]>>(7-(bit%8)))&1); bit++; } idx[i]=v; }
}
static void fors_sign(unsigned char *sig,const unsigned char *md,const unsigned char *skseed,const unsigned char *pkseed,ADRS adrs){
  uint32_t idx[K],i,j; fors_indices(md,idx);
  for(i=0;i<K;i++){ unsigned char *p=sig+i*(A+1)*N; uint32_t treeidx=(i<<A)+idx[i];
    fors_skgen(p,skseed,pkseed,adrs,treeidx);
    for(j=0;j<A;j++){ uint32_t s=(idx[i]>>j)^1; fors_node(p+N+j*N,skseed,(i<<(A-j))+s,j,pkseed,adrs); }
  }
}
static void fors_pkfromsig(unsigned char pk[N],const unsigned char *sig,const unsigned char *md,const unsigned char *pkseed,ADRS adrs){
  uint32_t idx[K],i,j; unsigned char roots[K*N],node[N],tmp[2*N]; ADRS fpk; fors_indices(md,idx);
  for(i=0;i<K;i++){ const unsigned char *p=sig+i*(A+1)*N; uint32_t treeidx=(i<<A)+idx[i];
    adrs_height(adrs,0); adrs_index(adrs,treeidx); Th(pkseed,adrs,p,N,node);
    for(j=0;j<A;j++){ const unsigned char *au=p+N+j*N; adrs_height(adrs,j+1);
      if(((idx[i]>>j)&1)==0){ adrs_index(adrs,adrs_get_index(adrs)/2); memcpy(tmp,node,N); memcpy(tmp+N,au,N); }
      else { adrs_index(adrs,adrs_get_index(adrs)/2); memcpy(tmp,au,N); memcpy(tmp+N,node,N); }
      Th(pkseed,adrs,tmp,2*N,node); }
    memcpy(roots+i*N,node,N);
  }
  memcpy(fpk,adrs,32); adrs_type(fpk,FORS_ROOTS); adrs_kp(fpk,adrs_get_kp(adrs));
  Th(pkseed,fpk,roots,K*N,pk);
}

/* ---- SLH-DSA ---- */
int rktcrypto_slhdsa_shake_128s_keygen_derand(unsigned char *pk,unsigned char *sk,const unsigned char seed[3*N]){
  /* sk = SKseed || SKprf || PKseed || PKroot ; pk = PKseed || PKroot */
  ADRS adrs; unsigned char root[N];
  memcpy(sk,seed,N);       /* SKseed */
  memcpy(sk+N,seed+N,N);   /* SKprf */
  memcpy(sk+2*N,seed+2*N,N);  /* PKseed */
  adrs_zero(adrs); adrs_layer(adrs,D-1);
  xmss_node(root,sk,0,HP,sk+2*N,adrs);
  memcpy(sk+3*N,root,N);
  memcpy(pk,sk+2*N,N); memcpy(pk+N,root,N);
  return 1;
}
int rktcrypto_slhdsa_shake_128s_keygen(unsigned char *pk,unsigned char *sk){
  unsigned char seed[3*N]; if(!rktcrypto_random_bytes(seed,0,3*N)) return 0;
  return rktcrypto_slhdsa_shake_128s_keygen_derand(pk,sk,seed);
}
/* Streams the pure-mode M' = 0x00 || 0x00 || msg (empty context) into a
   running SHAKE, avoiding a full-message copy. */
static const unsigned char MP_PREFIX[2]={0,0};

/* M' = 0x00 || 0x00 || M  (pure mode, empty context) */
static void slh_sign_internal(unsigned char *sig,const unsigned char *msg,size_t mlen,const unsigned char *sk){
  const unsigned char *skseed=sk,*skprf=sk+N,*pkseed=sk+2*N,*pkroot=sk+3*N;
  unsigned char R[N],digest[M_DIGEST]; const unsigned char *md; uint64_t idx_tree; uint32_t idx_leaf; ADRS adrs;
  unsigned char forspk[N];
  { shk s; shk_init(&s); shk_up(&s,skprf,N); shk_up(&s,pkseed,N); shk_up(&s,MP_PREFIX,2); shk_up(&s,msg,mlen); shk_out(&s,R,N); }  /* opt_rand=PKseed (deterministic) */
  memcpy(sig,R,N);
  { shk s; shk_init(&s); shk_up(&s,R,N); shk_up(&s,pkseed,N); shk_up(&s,pkroot,N); shk_up(&s,MP_PREFIX,2); shk_up(&s,msg,mlen); shk_out(&s,digest,M_DIGEST); }
  md=digest;
  { const unsigned char *pt=digest+KA; uint64_t v=0; int i; for(i=0;i<IDXTREE_BYTES;i++) v=(v<<8)|pt[i];
    idx_tree = v & (((uint64_t)1<<(H-HP))-1); }
  { const unsigned char *pl=digest+KA+IDXTREE_BYTES; uint32_t v=0; int i; for(i=0;i<IDXLEAF_BYTES;i++) v=(v<<8)|pl[i];
    idx_leaf = v & ((1u<<HP)-1); }
  adrs_zero(adrs); adrs_tree(adrs,idx_tree); adrs_type(adrs,FORS_TREE); adrs_kp(adrs,idx_leaf);
  fors_sign(sig+N,md,skseed,pkseed,adrs);
  fors_pkfromsig(forspk,sig+N,md,pkseed,adrs);
  ht_sign(sig+N+K*(A+1)*N,forspk,skseed,pkseed,idx_tree,idx_leaf);
}
static int slh_verify_internal(const unsigned char *sig,size_t siglen,const unsigned char *msg,size_t mlen,const unsigned char *pk){
  const unsigned char *pkseed=pk,*pkroot=pk+N;
  const unsigned char *R=sig,*sig_fors=sig+N,*sig_ht=sig+N+K*(A+1)*N;
  unsigned char digest[M_DIGEST],forspk[N]; uint64_t idx_tree; uint32_t idx_leaf; ADRS adrs;
  if(siglen!=SIG_BYTES) return 0;
  { shk s; shk_init(&s); shk_up(&s,R,N); shk_up(&s,pkseed,N); shk_up(&s,pkroot,N); shk_up(&s,MP_PREFIX,2); shk_up(&s,msg,mlen); shk_out(&s,digest,M_DIGEST); }
  { const unsigned char *pt=digest+KA; uint64_t v=0; int i; for(i=0;i<IDXTREE_BYTES;i++) v=(v<<8)|pt[i]; idx_tree=v&(((uint64_t)1<<(H-HP))-1); }
  { const unsigned char *pl=digest+KA+IDXTREE_BYTES; uint32_t v=0; int i; for(i=0;i<IDXLEAF_BYTES;i++) v=(v<<8)|pl[i]; idx_leaf=v&((1u<<HP)-1); }
  adrs_zero(adrs); adrs_tree(adrs,idx_tree); adrs_type(adrs,FORS_TREE); adrs_kp(adrs,idx_leaf);
  fors_pkfromsig(forspk,sig_fors,digest,pkseed,adrs);
  return ht_verify(sig_ht,forspk,pkseed,idx_tree,idx_leaf,pkroot);
}
int rktcrypto_slhdsa_shake_128s_sign(unsigned char *sig,const unsigned char *msg,intptr_t mlen,const unsigned char *sk){
  slh_sign_internal(sig,msg,(size_t)mlen,sk); return 1;
}
int rktcrypto_slhdsa_shake_128s_verify(const unsigned char *sig,intptr_t siglen,const unsigned char *msg,intptr_t mlen,const unsigned char *pk){
  return slh_verify_internal(sig,(size_t)siglen,msg,(size_t)mlen,pk);
}
