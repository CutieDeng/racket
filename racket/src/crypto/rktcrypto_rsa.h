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
/* RSASSA-PSS (SHA-256 / MGF1-SHA256). mHash is the 32-byte SHA-256 of the
   message. _sign draws a fresh 32-byte salt (sLen=hLen); _salt takes one. */
int rsa_pss_sha256_sign(unsigned char*sig,const unsigned char*mHash,const rsa_key*k);
int rsa_pss_sha256_sign_salt(unsigned char*sig,const unsigned char*mHash,const unsigned char*salt,int slen,const rsa_key*k);
int rsa_pss_sha256_verify(const unsigned char*sig,const unsigned char*mHash,int slen,const rsa_key*k);
/* RSAES-OAEP (SHA-256 / MGF1-SHA256, empty label). _encrypt draws a fresh
   32-byte seed; _seed takes one. decrypt writes the plaintext length to *mlen. */
int rsa_oaep_sha256_encrypt(unsigned char*out,const unsigned char*msg,int mlen,const rsa_key*k);
int rsa_oaep_sha256_encrypt_seed(unsigned char*out,const unsigned char*msg,int mlen,const unsigned char*seed,const rsa_key*k);
int rsa_oaep_sha256_decrypt(unsigned char*msg,int*mlen,const unsigned char*in,const rsa_key*k);
/* RSAES-PKCS1-v1_5 encryption. msg up to klen-11 bytes. */
int rsa_pkcs1_v15_encrypt(unsigned char*out,const unsigned char*msg,int mlen,const rsa_key*k);
int rsa_pkcs1_v15_decrypt(unsigned char*msg,int*mlen,const unsigned char*in,const rsa_key*k);
#endif
