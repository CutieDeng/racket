#ifndef RKTCRYPTO_RSA_H
#define RKTCRYPTO_RSA_H
#include "rktcrypto_bn.h"
typedef struct { int klen; BN n,e,d,p,q,dP,dQ,qInv;
  uint64_t n0_n,n0_p,n0_q; BN rr_n,rr_p,rr_q; } rsa_key;
void rsa_key_precompute(rsa_key*k);
void rsa_public(unsigned char*out,const unsigned char*in,const rsa_key*k);
void rsa_private_crt(unsigned char*out,const unsigned char*in,const rsa_key*k);
int rsa_pkcs1_sha256_sign(unsigned char*sig,const unsigned char*hash,const rsa_key*k);
int rsa_pkcs1_sha256_verify(const unsigned char*sig,const unsigned char*hash,const rsa_key*k);
#endif
