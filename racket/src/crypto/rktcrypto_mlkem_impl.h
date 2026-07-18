/* ML-KEM (Kyber) parameterized implementation template, FIPS 203.

   Included once per parameter set from a thin wrapper .c that defines,
   before the include:
     MLK_K       module rank (2 / 3 / 4)
     MLK_ETA1    CBD parameter for s,e,y (3 for ML-KEM-512, else 2)
     MLK_DU      ciphertext u compression bits (10, or 11 for ML-KEM-1024)
     MLK_DV      ciphertext v compression bits (4,  or 5  for ML-KEM-1024)
     MLK_NAME(x) expands to the exported symbol rktcrypto_mlkem<lvl>_##x
   Each wrapper is a separate translation unit, so the static helpers
   here never collide across parameter sets. From scratch, no external
   code. */

#include "rktcrypto.h"
#include "rktcrypto_digest.h"
#include <string.h>
#include <stdint.h>

#define KYBER_N 256
#define KYBER_Q 3329
#define KYBER_K MLK_K
#define KYBER_ETA1 MLK_ETA1
#define KYBER_ETA2 2
#define KYBER_DU MLK_DU
#define KYBER_DV MLK_DV
#define KYBER_SYMBYTES 32
#define KYBER_POLYBYTES 384
#define KYBER_POLYVECBYTES (KYBER_K*KYBER_POLYBYTES)
#if KYBER_DV == 5
#define KYBER_POLYCOMPRESSEDBYTES 160
#else
#define KYBER_POLYCOMPRESSEDBYTES 128
#endif
#if KYBER_DU == 11
#define KYBER_POLYVECCOMPRESSEDBYTES (KYBER_K*352)
#else
#define KYBER_POLYVECCOMPRESSEDBYTES (KYBER_K*320)
#endif
#define KYBER_INDCPA_PUBLICKEYBYTES (KYBER_POLYVECBYTES + KYBER_SYMBYTES)
#define KYBER_INDCPA_SECRETKEYBYTES (KYBER_POLYVECBYTES)
#define KYBER_INDCPA_BYTES (KYBER_POLYVECCOMPRESSEDBYTES + KYBER_POLYCOMPRESSEDBYTES)
#define KYBER_PUBLICKEYBYTES KYBER_INDCPA_PUBLICKEYBYTES
#define KYBER_SECRETKEYBYTES (KYBER_INDCPA_SECRETKEYBYTES + KYBER_INDCPA_PUBLICKEYBYTES + 2*KYBER_SYMBYTES)
#define KYBER_CIPHERTEXTBYTES KYBER_INDCPA_BYTES

#define MONT 2285
#define QINV 62209

typedef struct { int16_t coeffs[KYBER_N]; } poly;
typedef struct { poly vec[KYBER_K]; } polyvec;

static const int16_t zetas[128] = {
  -1044,-758,-359,-1517,1493,1422,287,202,-171,622,1577,182,962,-1202,-1474,1468,
  573,-1325,264,383,-829,1458,-1602,-130,-681,1017,732,608,-1542,411,-205,-1571,
  1223,652,-552,1015,-1293,1491,-282,-1544,516,-8,-320,-666,-1618,-1162,126,1469,
  -853,-90,-271,830,107,-1421,-247,-951,-398,961,-1508,-725,448,-1065,677,-1275,
  -1103,430,555,843,-1251,871,1550,105,422,587,177,-235,-291,-460,1574,1653,
  -246,778,1159,-147,-777,1483,-602,1119,-1590,644,-872,349,418,329,-156,-75,
  817,1097,603,610,1322,-1285,-1465,384,-1215,-136,1218,-1335,-874,220,-1187,-1659,
  -1185,-1530,-1278,794,-1510,-854,-870,478,-108,-308,996,991,958,-1460,1522,1628
};

static int16_t montgomery_reduce(int32_t a){
  int16_t t; t=(int16_t)(a*QINV); t=(int16_t)((a-(int32_t)t*KYBER_Q)>>16); return t;
}
static int16_t barrett_reduce(int16_t a){
  int16_t t; const int16_t v=((1<<26)+KYBER_Q/2)/KYBER_Q;
  t=(int16_t)(((int32_t)v*a+(1<<25))>>26); t=(int16_t)(t*KYBER_Q); return (int16_t)(a-t);
}
static int16_t fqmul(int16_t a,int16_t b){ return montgomery_reduce((int32_t)a*b); }

static void ntt(int16_t r[256]){
  int len,start,j,k=1; int16_t t,zeta;
  for(len=128;len>=2;len>>=1) for(start=0;start<256;start=j+len){
    zeta=zetas[k++];
    for(j=start;j<start+len;j++){ t=fqmul(zeta,r[j+len]); r[j+len]=(int16_t)(r[j]-t); r[j]=(int16_t)(r[j]+t); }
  }
}
static void invntt(int16_t r[256]){
  int start,len,j,k=127; int16_t t,zeta; const int16_t f=1441;
  for(len=2;len<=128;len<<=1) for(start=0;start<256;start=j+len){
    zeta=zetas[k--];
    for(j=start;j<start+len;j++){ t=r[j]; r[j]=barrett_reduce((int16_t)(t+r[j+len])); r[j+len]=(int16_t)(r[j+len]-t); r[j+len]=fqmul(zeta,r[j+len]); }
  }
  for(j=0;j<256;j++) r[j]=fqmul(r[j],f);
}
static void basemul(int16_t r[2],const int16_t a[2],const int16_t b[2],int16_t zeta){
  r[0]=fqmul(a[1],b[1]); r[0]=fqmul(r[0],zeta); r[0]=(int16_t)(r[0]+fqmul(a[0],b[0]));
  r[1]=fqmul(a[0],b[1]); r[1]=(int16_t)(r[1]+fqmul(a[1],b[0]));
}
static void poly_ntt(poly *r){ ntt(r->coeffs); }
static void poly_invntt(poly *r){ invntt(r->coeffs); }
static void poly_basemul(poly *r,const poly *a,const poly *b){
  int i; for(i=0;i<KYBER_N/4;i++){
    basemul(&r->coeffs[4*i],&a->coeffs[4*i],&b->coeffs[4*i],zetas[64+i]);
    basemul(&r->coeffs[4*i+2],&a->coeffs[4*i+2],&b->coeffs[4*i+2],(int16_t)(-zetas[64+i]));
  }
}
static void poly_add(poly *r,const poly *a,const poly *b){ int i; for(i=0;i<KYBER_N;i++)r->coeffs[i]=(int16_t)(a->coeffs[i]+b->coeffs[i]); }
static void poly_sub(poly *r,const poly *a,const poly *b){ int i; for(i=0;i<KYBER_N;i++)r->coeffs[i]=(int16_t)(a->coeffs[i]-b->coeffs[i]); }
static void poly_reduce(poly *r){ int i; for(i=0;i<KYBER_N;i++)r->coeffs[i]=barrett_reduce(r->coeffs[i]); }
static void poly_tomont(poly *r){ int i; const int16_t f=(int16_t)((1ULL<<32)%KYBER_Q); for(i=0;i<KYBER_N;i++)r->coeffs[i]=montgomery_reduce((int32_t)r->coeffs[i]*f); }

static void sha3_256(unsigned char out[32],const unsigned char *in,size_t inlen){
  rktcrypto_keccak_ctx_t c; rktcrypto_keccak_core_init(&c,136,0x06);
  rktcrypto_keccak_core_update(&c,in,(intptr_t)inlen); rktcrypto_keccak_core_final(&c,out,32);
}
static void sha3_512(unsigned char out[64],const unsigned char *in,size_t inlen){
  rktcrypto_keccak_ctx_t c; rktcrypto_keccak_core_init(&c,72,0x06);
  rktcrypto_keccak_core_update(&c,in,(intptr_t)inlen); rktcrypto_keccak_core_final(&c,out,64);
}
static void shake256(unsigned char *out,size_t outlen,const unsigned char *in,size_t inlen){
  rktcrypto_keccak_ctx_t c; rktcrypto_keccak_core_init(&c,136,0x1f);
  rktcrypto_keccak_core_update(&c,in,(intptr_t)inlen); rktcrypto_keccak_core_final(&c,out,(intptr_t)outlen);
}
static void shake128_abs_sq(unsigned char *out,size_t outlen,const unsigned char *in,size_t inlen){
  rktcrypto_keccak_ctx_t c; rktcrypto_keccak_core_init(&c,168,0x1f);
  rktcrypto_keccak_core_update(&c,in,(intptr_t)inlen); rktcrypto_keccak_core_final(&c,out,(intptr_t)outlen);
}

static void poly_parse(poly *r,const unsigned char *rho,unsigned char i,unsigned char j){
  unsigned char seed[34]; unsigned char buf[672]; unsigned int ctr=0,pos=0; uint16_t d1,d2;
  memcpy(seed,rho,32); seed[32]=i; seed[33]=j;
  shake128_abs_sq(buf,sizeof(buf),seed,34);
  while(ctr<KYBER_N && pos+3<=sizeof(buf)){
    d1=(uint16_t)(((buf[pos]>>0)|((uint16_t)buf[pos+1]<<8))&0xFFF);
    d2=(uint16_t)(((buf[pos+1]>>4)|((uint16_t)buf[pos+2]<<4))&0xFFF);
    pos+=3;
    if(d1<KYBER_Q) r->coeffs[ctr++]=(int16_t)d1;
    if(ctr<KYBER_N && d2<KYBER_Q) r->coeffs[ctr++]=(int16_t)d2;
  }
}
static void cbd2(poly *r,const unsigned char buf[128]){
  int i,j; uint32_t t,d; int16_t a,b;
  for(i=0;i<KYBER_N/8;i++){
    t=(uint32_t)buf[4*i]|((uint32_t)buf[4*i+1]<<8)|((uint32_t)buf[4*i+2]<<16)|((uint32_t)buf[4*i+3]<<24);
    d=t&0x55555555; d+=(t>>1)&0x55555555;
    for(j=0;j<8;j++){ a=(int16_t)((d>>(4*j))&0x3); b=(int16_t)((d>>(4*j+2))&0x3); r->coeffs[8*i+j]=(int16_t)(a-b); }
  }
}
#if KYBER_ETA1 == 3
static void cbd3(poly *r,const unsigned char buf[192]){
  int i,j; uint32_t t,d; int16_t a,b;
  for(i=0;i<KYBER_N/4;i++){
    t=(uint32_t)buf[3*i]|((uint32_t)buf[3*i+1]<<8)|((uint32_t)buf[3*i+2]<<16);
    d=t&0x00249249; d+=(t>>1)&0x00249249; d+=(t>>2)&0x00249249;
    for(j=0;j<4;j++){ a=(int16_t)((d>>(6*j))&0x7); b=(int16_t)((d>>(6*j+3))&0x7); r->coeffs[4*i+j]=(int16_t)(a-b); }
  }
}
static void poly_getnoise_eta1(poly *r,const unsigned char seed[32],unsigned char nonce){
  unsigned char extseed[33],buf[192]; memcpy(extseed,seed,32); extseed[32]=nonce;
  shake256(buf,192,extseed,33); cbd3(r,buf);
}
#else
static void poly_getnoise_eta1(poly *r,const unsigned char seed[32],unsigned char nonce){
  unsigned char extseed[33],buf[128]; memcpy(extseed,seed,32); extseed[32]=nonce;
  shake256(buf,128,extseed,33); cbd2(r,buf);
}
#endif
static void poly_getnoise_eta2(poly *r,const unsigned char seed[32],unsigned char nonce){
  unsigned char extseed[33],buf[128]; memcpy(extseed,seed,32); extseed[32]=nonce;
  shake256(buf,128,extseed,33); cbd2(r,buf);
}

static void poly_tobytes(unsigned char r[384],const poly *a){
  int i; uint16_t t0,t1;
  for(i=0;i<KYBER_N/2;i++){
    t0=(uint16_t)a->coeffs[2*i];   t0=(uint16_t)(t0+(((int16_t)t0>>15)&KYBER_Q));
    t1=(uint16_t)a->coeffs[2*i+1]; t1=(uint16_t)(t1+(((int16_t)t1>>15)&KYBER_Q));
    r[3*i+0]=(unsigned char)(t0>>0); r[3*i+1]=(unsigned char)((t0>>8)|(t1<<4)); r[3*i+2]=(unsigned char)(t1>>4);
  }
}
static void poly_frombytes(poly *r,const unsigned char a[384]){
  int i; for(i=0;i<KYBER_N/2;i++){
    r->coeffs[2*i]=(int16_t)(((a[3*i+0]>>0)|((uint16_t)a[3*i+1]<<8))&0xFFF);
    r->coeffs[2*i+1]=(int16_t)(((a[3*i+1]>>4)|((uint16_t)a[3*i+2]<<4))&0xFFF);
  }
}
static uint32_t freeze_mod(int16_t x){ int16_t r=barrett_reduce(x); r+=(int16_t)((r>>15)&KYBER_Q); return (uint32_t)r; }

/* ---- v compression (dv) ---- */
#if KYBER_DV == 5
static void poly_compress_dv(unsigned char r[160],const poly *a){
  int i,j; uint8_t t[8]; uint32_t u;
  for(i=0;i<KYBER_N/8;i++){
    for(j=0;j<8;j++){ u=freeze_mod(a->coeffs[8*i+j]); t[j]=(uint8_t)(((((uint32_t)u<<5)+KYBER_Q/2)/KYBER_Q)&31); }
    r[0]=(unsigned char)(t[0]|(t[1]<<5));
    r[1]=(unsigned char)((t[1]>>3)|(t[2]<<2)|(t[3]<<7));
    r[2]=(unsigned char)((t[3]>>1)|(t[4]<<4));
    r[3]=(unsigned char)((t[4]>>4)|(t[5]<<1)|(t[6]<<6));
    r[4]=(unsigned char)((t[6]>>2)|(t[7]<<3));
    r+=5;
  }
}
static void poly_decompress_dv(poly *r,const unsigned char a[160]){
  int i,j; uint8_t t[8];
  for(i=0;i<KYBER_N/8;i++){
    t[0]=a[0]; t[1]=(uint8_t)((a[0]>>5)|(a[1]<<3)); t[2]=(uint8_t)(a[1]>>2); t[3]=(uint8_t)((a[1]>>7)|(a[2]<<1));
    t[4]=(uint8_t)((a[2]>>4)|(a[3]<<4)); t[5]=(uint8_t)(a[3]>>1); t[6]=(uint8_t)((a[3]>>6)|(a[4]<<2)); t[7]=(uint8_t)(a[4]>>3);
    for(j=0;j<8;j++) r->coeffs[8*i+j]=(int16_t)(((uint32_t)(t[j]&31)*KYBER_Q+16)>>5);
    a+=5;
  }
}
#else
static void poly_compress_dv(unsigned char r[128],const poly *a){
  int i,j; uint8_t t[8]; uint32_t u;
  for(i=0;i<KYBER_N/8;i++){
    for(j=0;j<8;j++){ u=freeze_mod(a->coeffs[8*i+j]); t[j]=(uint8_t)(((((uint32_t)u<<4)+KYBER_Q/2)/KYBER_Q)&15); }
    r[4*i+0]=(unsigned char)(t[0]|(t[1]<<4)); r[4*i+1]=(unsigned char)(t[2]|(t[3]<<4));
    r[4*i+2]=(unsigned char)(t[4]|(t[5]<<4)); r[4*i+3]=(unsigned char)(t[6]|(t[7]<<4));
  }
}
static void poly_decompress_dv(poly *r,const unsigned char a[128]){
  int i; for(i=0;i<KYBER_N/2;i++){
    r->coeffs[2*i]=(int16_t)(((uint32_t)(a[i]&15)*KYBER_Q+8)>>4);
    r->coeffs[2*i+1]=(int16_t)(((uint32_t)(a[i]>>4)*KYBER_Q+8)>>4);
  }
}
#endif

/* ---- u compression (du) ---- */
#if KYBER_DU == 11
static void polyvec_compress_du(unsigned char *r,const polyvec *a){
  int i,j,kk; uint16_t t[8]; unsigned char *p=r;
  for(i=0;i<KYBER_K;i++) for(j=0;j<KYBER_N/8;j++){
    for(kk=0;kk<8;kk++){ uint32_t u=freeze_mod(a->vec[i].coeffs[8*j+kk]); t[kk]=(uint16_t)(((((uint32_t)u<<11)+KYBER_Q/2)/KYBER_Q)&0x7ff); }
    p[0]=(unsigned char)(t[0]>>0); p[1]=(unsigned char)((t[0]>>8)|(t[1]<<3)); p[2]=(unsigned char)((t[1]>>5)|(t[2]<<6));
    p[3]=(unsigned char)(t[2]>>2); p[4]=(unsigned char)((t[2]>>10)|(t[3]<<1)); p[5]=(unsigned char)((t[3]>>7)|(t[4]<<4));
    p[6]=(unsigned char)((t[4]>>4)|(t[5]<<7)); p[7]=(unsigned char)(t[5]>>1); p[8]=(unsigned char)((t[5]>>9)|(t[6]<<2));
    p[9]=(unsigned char)((t[6]>>6)|(t[7]<<5)); p[10]=(unsigned char)(t[7]>>3); p+=11;
  }
}
static void polyvec_decompress_du(polyvec *r,const unsigned char *a){
  int i,j,kk; uint16_t t[8]; const unsigned char *p=a;
  for(i=0;i<KYBER_K;i++) for(j=0;j<KYBER_N/8;j++){
    t[0]=(uint16_t)((p[0]>>0)|((uint16_t)p[1]<<8)); t[1]=(uint16_t)((p[1]>>3)|((uint16_t)p[2]<<5));
    t[2]=(uint16_t)((p[2]>>6)|((uint16_t)p[3]<<2)|((uint16_t)p[4]<<10)); t[3]=(uint16_t)((p[4]>>1)|((uint16_t)p[5]<<7));
    t[4]=(uint16_t)((p[5]>>4)|((uint16_t)p[6]<<4)); t[5]=(uint16_t)((p[6]>>7)|((uint16_t)p[7]<<1)|((uint16_t)p[8]<<9));
    t[6]=(uint16_t)((p[8]>>2)|((uint16_t)p[9]<<6)); t[7]=(uint16_t)((p[9]>>5)|((uint16_t)p[10]<<3));
    p+=11;
    for(kk=0;kk<8;kk++) r->vec[i].coeffs[8*j+kk]=(int16_t)(((uint32_t)(t[kk]&0x7ff)*KYBER_Q+1024)>>11);
  }
}
#else
static void polyvec_compress_du(unsigned char *r,const polyvec *a){
  int i,j,kk; uint16_t t[4]; unsigned char *p=r;
  for(i=0;i<KYBER_K;i++) for(j=0;j<KYBER_N/4;j++){
    for(kk=0;kk<4;kk++){ uint32_t u=freeze_mod(a->vec[i].coeffs[4*j+kk]); t[kk]=(uint16_t)(((((uint32_t)u<<10)+KYBER_Q/2)/KYBER_Q)&0x3ff); }
    p[0]=(unsigned char)(t[0]>>0); p[1]=(unsigned char)((t[0]>>8)|(t[1]<<2)); p[2]=(unsigned char)((t[1]>>6)|(t[2]<<4));
    p[3]=(unsigned char)((t[2]>>4)|(t[3]<<6)); p[4]=(unsigned char)(t[3]>>2); p+=5;
  }
}
static void polyvec_decompress_du(polyvec *r,const unsigned char *a){
  int i,j,kk; uint16_t t[4]; const unsigned char *p=a;
  for(i=0;i<KYBER_K;i++) for(j=0;j<KYBER_N/4;j++){
    t[0]=(uint16_t)((p[0]>>0)|((uint16_t)p[1]<<8)); t[1]=(uint16_t)((p[1]>>2)|((uint16_t)p[2]<<6));
    t[2]=(uint16_t)((p[2]>>4)|((uint16_t)p[3]<<4)); t[3]=(uint16_t)((p[3]>>6)|((uint16_t)p[4]<<2));
    p+=5;
    for(kk=0;kk<4;kk++) r->vec[i].coeffs[4*j+kk]=(int16_t)(((uint32_t)(t[kk]&0x3ff)*KYBER_Q+512)>>10);
  }
}
#endif

static void poly_frommsg(poly *r,const unsigned char msg[32]){
  int i,j; for(i=0;i<KYBER_N/8;i++) for(j=0;j<8;j++){ int16_t mask=(int16_t)(-(int16_t)((msg[i]>>j)&1)); r->coeffs[8*i+j]=(int16_t)(mask&((KYBER_Q+1)/2)); }
}
static void poly_tomsg(unsigned char msg[32],const poly *a){
  int i,j; uint32_t t; memset(msg,0,32);
  for(i=0;i<KYBER_N/8;i++) for(j=0;j<8;j++){ t=freeze_mod(a->coeffs[8*i+j]); t=(((t<<1)+KYBER_Q/2)/KYBER_Q)&1; msg[i]|=(unsigned char)(t<<j); }
}
static void polyvec_tobytes(unsigned char *r,const polyvec *a){ int i; for(i=0;i<KYBER_K;i++) poly_tobytes(r+i*384,&a->vec[i]); }
static void polyvec_frombytes(polyvec *r,const unsigned char *a){ int i; for(i=0;i<KYBER_K;i++) poly_frombytes(&r->vec[i],a+i*384); }
static void polyvec_ntt(polyvec *r){ int i; for(i=0;i<KYBER_K;i++)poly_ntt(&r->vec[i]); }
static void polyvec_invntt(polyvec *r){ int i; for(i=0;i<KYBER_K;i++)poly_invntt(&r->vec[i]); }
static void polyvec_reduce(polyvec *r){ int i; for(i=0;i<KYBER_K;i++)poly_reduce(&r->vec[i]); }
static void polyvec_add(polyvec *r,const polyvec *a,const polyvec *b){ int i; for(i=0;i<KYBER_K;i++)poly_add(&r->vec[i],&a->vec[i],&b->vec[i]); }
static void polyvec_basemul_acc(poly *r,const polyvec *a,const polyvec *b){
  int i; poly t; poly_basemul(r,&a->vec[0],&b->vec[0]);
  for(i=1;i<KYBER_K;i++){ poly_basemul(&t,&a->vec[i],&b->vec[i]); poly_add(r,r,&t); }
  poly_reduce(r);
}
static void gen_matrix(polyvec a[KYBER_K],const unsigned char rho[32],int transposed){
  int i,j; for(i=0;i<KYBER_K;i++) for(j=0;j<KYBER_K;j++){
    if(transposed) poly_parse(&a[i].vec[j],rho,(unsigned char)i,(unsigned char)j);
    else poly_parse(&a[i].vec[j],rho,(unsigned char)j,(unsigned char)i);
  }
}
static void indcpa_keypair(unsigned char *pk,unsigned char *sk,const unsigned char coins[32]){
  unsigned char buf[64]; const unsigned char *rho,*sigma; unsigned char nonce=0;
  polyvec a[KYBER_K],e,pkpv,skpv; int i;
  unsigned char inbuf[33]; memcpy(inbuf,coins,32); inbuf[32]=KYBER_K;
  sha3_512(buf,inbuf,33); rho=buf; sigma=buf+32;
  gen_matrix(a,rho,0);
  for(i=0;i<KYBER_K;i++) poly_getnoise_eta1(&skpv.vec[i],sigma,nonce++);
  for(i=0;i<KYBER_K;i++) poly_getnoise_eta1(&e.vec[i],sigma,nonce++);
  polyvec_ntt(&skpv); polyvec_ntt(&e);
  for(i=0;i<KYBER_K;i++){ polyvec_basemul_acc(&pkpv.vec[i],&a[i],&skpv); poly_tomont(&pkpv.vec[i]); }
  polyvec_add(&pkpv,&pkpv,&e); polyvec_reduce(&pkpv); polyvec_reduce(&skpv);
  polyvec_tobytes(sk,&skpv);
  polyvec_tobytes(pk,&pkpv); memcpy(pk+KYBER_POLYVECBYTES,rho,32);
}
static void indcpa_enc(unsigned char *c,const unsigned char m[32],const unsigned char *pk,const unsigned char coins[32]){
  unsigned char rho[32]; polyvec at[KYBER_K],sp,ep,bp,pkpv; poly v,k,epp; int i; unsigned char nonce=0;
  polyvec_frombytes(&pkpv,pk); memcpy(rho,pk+KYBER_POLYVECBYTES,32);
  poly_frommsg(&k,m); gen_matrix(at,rho,1);
  for(i=0;i<KYBER_K;i++) poly_getnoise_eta1(&sp.vec[i],coins,nonce++);
  for(i=0;i<KYBER_K;i++) poly_getnoise_eta2(&ep.vec[i],coins,nonce++);
  poly_getnoise_eta2(&epp,coins,nonce++);
  polyvec_ntt(&sp);
  for(i=0;i<KYBER_K;i++) polyvec_basemul_acc(&bp.vec[i],&at[i],&sp);
  polyvec_basemul_acc(&v,&pkpv,&sp);
  polyvec_invntt(&bp); poly_invntt(&v);
  polyvec_add(&bp,&bp,&ep); polyvec_reduce(&bp);
  poly_add(&v,&v,&epp); poly_add(&v,&v,&k); poly_reduce(&v);
  polyvec_compress_du(c,&bp);
  poly_compress_dv(c+KYBER_POLYVECCOMPRESSEDBYTES,&v);
}
static void indcpa_dec(unsigned char m[32],const unsigned char *c,const unsigned char *sk){
  polyvec bp,skpv; poly v,mp;
  polyvec_decompress_du(&bp,c); poly_decompress_dv(&v,c+KYBER_POLYVECCOMPRESSEDBYTES);
  polyvec_frombytes(&skpv,sk); polyvec_ntt(&bp);
  polyvec_basemul_acc(&mp,&skpv,&bp); poly_invntt(&mp);
  poly_sub(&mp,&v,&mp); poly_reduce(&mp); poly_tomsg(m,&mp);
}

int MLK_NAME(keypair_derand)(unsigned char *pk,unsigned char *sk,const unsigned char coins[64]){
  indcpa_keypair(pk,sk,coins);
  memcpy(sk+KYBER_INDCPA_SECRETKEYBYTES,pk,KYBER_INDCPA_PUBLICKEYBYTES);
  sha3_256(sk+KYBER_SECRETKEYBYTES-2*KYBER_SYMBYTES,pk,KYBER_INDCPA_PUBLICKEYBYTES);
  memcpy(sk+KYBER_SECRETKEYBYTES-KYBER_SYMBYTES,coins+32,32);
  return 1;
}
int MLK_NAME(enc_derand)(unsigned char *ct,unsigned char *ss,const unsigned char *pk,const unsigned char m[32]){
  unsigned char buf[64],kr[64];
  memcpy(buf,m,32); sha3_256(buf+32,pk,KYBER_INDCPA_PUBLICKEYBYTES);
  sha3_512(kr,buf,64); indcpa_enc(ct,m,pk,kr+32); memcpy(ss,kr,32); return 1;
}
int MLK_NAME(decaps)(unsigned char *ss,const unsigned char *ct,const unsigned char *sk){
  unsigned char buf[64],kr[64],cmp[KYBER_CIPHERTEXTBYTES],m[32]; int i; unsigned char fail;
  const unsigned char *pk=sk+KYBER_INDCPA_SECRETKEYBYTES;
  indcpa_dec(m,ct,sk);
  memcpy(buf,m,32); memcpy(buf+32,sk+KYBER_SECRETKEYBYTES-2*KYBER_SYMBYTES,32);
  sha3_512(kr,buf,64); indcpa_enc(cmp,m,pk,kr+32);
  fail=0; for(i=0;i<KYBER_CIPHERTEXTBYTES;i++) fail|=ct[i]^cmp[i];
  fail=(unsigned char)((-(int)(fail!=0))&0xff);
  { unsigned char kfail[32]; unsigned char zc[KYBER_SYMBYTES+KYBER_CIPHERTEXTBYTES];
    memcpy(zc,sk+KYBER_SECRETKEYBYTES-KYBER_SYMBYTES,32); memcpy(zc+32,ct,KYBER_CIPHERTEXTBYTES);
    shake256(kfail,32,zc,sizeof(zc));
    for(i=0;i<32;i++) ss[i]=(unsigned char)((kr[i]&~fail)|(kfail[i]&fail));
  }
  return 1;
}
int MLK_NAME(keypair)(unsigned char *pk,unsigned char *sk){
  unsigned char coins[64]; if(!rktcrypto_random_bytes(coins,0,64)) return 0;
  return MLK_NAME(keypair_derand)(pk,sk,coins);
}
int MLK_NAME(encaps)(unsigned char *ct,unsigned char *ss,const unsigned char *pk){
  unsigned char m[32]; if(!rktcrypto_random_bytes(m,0,32)) return 0;
  return MLK_NAME(enc_derand)(ct,ss,pk,m);
}
