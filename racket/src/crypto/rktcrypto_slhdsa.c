/* SLH-DSA-SHAKE-128s (FIPS 205 / SPHINCS+). Stateless hash-based signatures:
   WOTS+ one-time signatures, FORS few-time signatures, and a hypertree of
   XMSS Merkle trees, all keyed by SHAKE256. Parameters n=16, h=63, d=7,
   h'=9, a=12, k=14, w=16 (SHAKE-128s). From scratch, no external code. */

#include "rktcrypto.h"
#include "rktcrypto_digest.h"
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

/* ---- WOTS+ ---- */
static void chain(unsigned char *out,const unsigned char *X,uint32_t i,uint32_t s,const unsigned char *pkseed,ADRS adrs){
  uint32_t j; memcpy(out,X,N);
  for(j=i;j<i+s;j++){ adrs_hash(adrs,j); Th(pkseed,adrs,out,N,out); }
}
static void wots_pkgen(unsigned char pk[N],const unsigned char *skseed,const unsigned char *pkseed,ADRS adrs){
  ADRS skadrs,wpk; unsigned char tmp[LEN*N],sk[N]; uint32_t i;
  memcpy(skadrs,adrs,32); adrs_type(skadrs,WOTS_PRF); adrs_kp(skadrs,adrs_get_kp(adrs));
  for(i=0;i<LEN;i++){ adrs_chain(skadrs,i); adrs_hash(skadrs,0); PRF(pkseed,skseed,skadrs,sk);
    adrs_chain(adrs,i); chain(tmp+i*N,sk,0,W-1,pkseed,adrs); }
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
  for(i=0;i<LEN;i++){ adrs_chain(skadrs,i); adrs_hash(skadrs,0); PRF(pkseed,skseed,skadrs,sk);
    adrs_chain(adrs,i); chain(sig+i*N,sk,0,d[i],pkseed,adrs); }
}
static void wots_pkfromsig(unsigned char pk[N],const unsigned char *sig,const unsigned char msg[N],const unsigned char *pkseed,ADRS adrs){
  unsigned int d[LEN],i; unsigned char tmp[LEN*N]; ADRS wpk;
  wots_msg_digits(msg,d);
  for(i=0;i<LEN;i++){ adrs_chain(adrs,i); chain(tmp+i*N,sig+i*N,d[i],(W-1)-d[i],pkseed,adrs); }
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
