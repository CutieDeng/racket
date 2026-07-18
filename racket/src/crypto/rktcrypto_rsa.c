/* RSA (RSAES/RSASSA) on top of rktcrypto_bn. CRT private operation, public
   operation, and PKCS#1 v1.5 SHA-256 signatures. Verified against OpenSSL 3.6.3:
   our signatures are bit-identical to OpenSSL's and each verifies the other's.
   Keys are imported by component (n,e,d,p,q,dP,dQ,qInv); keygen, OAEP, and PSS
   are follow-ups. */
#include "rktcrypto_bn.h"
#include "rktcrypto_rsa.h"
#include <string.h>
void bn_from_be(BN*,const unsigned char*,int); void bn_to_be(unsigned char*,int,const BN*);
void bn_mod(BN*,const BN*,const BN*);
void bn_sub(BN*,const BN*,const BN*); void bn_add(BN*,const BN*,const BN*);
void bn_mul(BN*,const BN*,const BN*); int bn_cmp(const BN*,const BN*); void bn_copy(BN*,const BN*);
/* RSA key (2048-bit assumed here; klen = modulus bytes) */
void bn_mont_setup(uint64_t*,BN*,const BN*);
void bn_modexp_pre(BN*,const BN*,const BN*,const BN*,uint64_t,const BN*);
/* Public: out = in^e mod n */
void rsa_key_precompute(rsa_key*k){ bn_mont_setup(&k->n0_n,&k->rr_n,&k->n); bn_mont_setup(&k->n0_p,&k->rr_p,&k->p); bn_mont_setup(&k->n0_q,&k->rr_q,&k->q); }
void rsa_public(unsigned char*out,const unsigned char*in,const rsa_key*k){
  BN c,m; bn_from_be(&c,in,k->klen); bn_modexp_pre(&m,&c,&k->e,&k->n,k->n0_n,&k->rr_n); bn_to_be(out,k->klen,&m);
}
/* Private via CRT: m = c^d mod n */
void rsa_private_crt(unsigned char*out,const unsigned char*in,const rsa_key*k){
  BN c,m1,m2,h,t,cp; bn_from_be(&c,in,k->klen);
  bn_mod(&cp,&c,&k->p); bn_modexp_pre(&m1,&cp,&k->dP,&k->p,k->n0_p,&k->rr_p);
  bn_mod(&cp,&c,&k->q); bn_modexp_pre(&m2,&cp,&k->dQ,&k->q,k->n0_q,&k->rr_q);
  /* h = qInv*(m1-m2) mod p */
  if(bn_cmp(&m1,&m2)<0){ BN tmp; bn_add(&tmp,&m1,&k->p); bn_sub(&t,&tmp,&m2); } else bn_sub(&t,&m1,&m2);
  { BN prod; bn_mul(&prod,&k->qInv,&t); bn_mod(&h,&prod,&k->p); }
  { BN hq; bn_mul(&hq,&h,&k->q); bn_add(&m2,&m2,&hq); }   /* m = m2 + h*q */
  bn_to_be(out,k->klen,&m2);
}
/* PKCS#1 v1.5 signature encoding for SHA-256 (DigestInfo prefix + digest) */
static const unsigned char SHA256_DI[19]={0x30,0x31,0x30,0x0d,0x06,0x09,0x60,0x86,0x48,0x01,0x65,0x03,0x04,0x02,0x01,0x05,0x00,0x04,0x20};
static void pkcs1_v15_sign_encode(unsigned char*em,int klen,const unsigned char*hash){
  int tlen=19+32; em[0]=0;em[1]=1; int ps=klen-tlen-3;
  memset(em+2,0xff,ps); em[2+ps]=0; memcpy(em+3+ps,SHA256_DI,19); memcpy(em+3+ps+19,hash,32);
}
int rsa_pkcs1_sha256_sign(unsigned char*sig,const unsigned char*hash,const rsa_key*k){
  unsigned char em[512]; pkcs1_v15_sign_encode(em,k->klen,hash); rsa_private_crt(sig,em,k); return 1;
}
int rsa_pkcs1_sha256_verify(const unsigned char*sig,const unsigned char*hash,const rsa_key*k){
  unsigned char em[512],exp[512]; rsa_public(em,sig,k); pkcs1_v15_sign_encode(exp,k->klen,hash);
  return memcmp(em,exp,k->klen)==0;
}
