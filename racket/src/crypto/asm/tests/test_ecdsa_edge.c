/* Wycheproof-style edge cases for NIST-curve ECDSA verification (P-256/384/521):
   a correct verifier must reject r or s outside [1, n-1] (r=0, s=0, r=n, s=n)
   and any tampered signature/wrong message, while accepting a valid one. Guards
   librktcrypto's signature input validation.
   Build: cc -O2 -I. test_ecdsa_edge.c librktcrypto.a */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include "rktcrypto.h"
extern int rktcrypto_p256_pubkey(unsigned char*,const unsigned char*);
extern int rktcrypto_p256_ecdsa_sign(unsigned char*,const unsigned char*,intptr_t,const unsigned char*);
extern int rktcrypto_p256_ecdsa_verify(const unsigned char*,const unsigned char*,intptr_t,const unsigned char*);
extern int rktcrypto_p384_pubkey(unsigned char*,const unsigned char*);
extern int rktcrypto_p384_ecdsa_sign(unsigned char*,const unsigned char*,intptr_t,const unsigned char*);
extern int rktcrypto_p384_ecdsa_verify(const unsigned char*,const unsigned char*,intptr_t,const unsigned char*);
extern int rktcrypto_p521_pubkey(unsigned char*,const unsigned char*);
extern int rktcrypto_p521_ecdsa_sign(unsigned char*,const unsigned char*,intptr_t,const unsigned char*);
extern int rktcrypto_p521_ecdsa_verify(const unsigned char*,const unsigned char*,intptr_t,const unsigned char*);

static const unsigned char N256[32]={
0xff,0xff,0xff,0xff,0x00,0x00,0x00,0x00,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
0xbc,0xe6,0xfa,0xad,0xa7,0x17,0x9e,0x84,0xf3,0xb9,0xca,0xc2,0xfc,0x63,0x25,0x51};
static const unsigned char N384[48]={
0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xc7,0x63,0x4d,0x81,0xf4,0x37,0x2d,0xdf,
0x58,0x1a,0x0d,0xb2,0x48,0xb0,0xa7,0x7a,0xec,0xec,0x19,0x6a,0xcc,0x52,0x97,0x3};
static const unsigned char N521[66]={
0x01,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
0xff,0xfa,0x51,0x86,0x87,0x83,0xbf,0x2f,0x96,0x6b,0x7f,0xcc,0x01,0x48,0xf7,0x09,
0xa5,0xd0,0x3b,0xb5,0xc9,0xb8,0x89,0x9c,0x47,0xae,0xbb,0x6f,0xb7,0x1e,0x91,0x38,0x64,0x09};

typedef int(*pkfn)(unsigned char*,const unsigned char*);
typedef int(*sgfn)(unsigned char*,const unsigned char*,intptr_t,const unsigned char*);
typedef int(*vffn)(const unsigned char*,const unsigned char*,intptr_t,const unsigned char*);

static int fail=0;
static void ck(const char*name,int cond){ if(!cond){printf("  FAIL %s\n",name);fail=1;} else printf("  ok %s\n",name);}

static void one(const char*curve,int nb,int pkb,pkfn pk,sgfn sign,vffn verify,const unsigned char*N){
  unsigned char priv[66],pub[133],sig[132],b[132]; for(int i=0;i<nb;i++)priv[i]=(unsigned char)(i+7);
  priv[0]=0;                        /* scalar < 2^(8*(nb-1)) < n for every NIST curve */
  char t[64]; snprintf(t,sizeof t,"%s edge", curve);
  const unsigned char*m=(const unsigned char*)"wycheproof edge"; intptr_t ml=15;
  if(!pk(pub,priv)){printf("  FAIL %s pubkey\n",curve);fail=1;return;}
  if(!sign(sig,m,ml,priv)){printf("  FAIL %s sign\n",curve);fail=1;return;}
  int L=2*nb;
  snprintf(t,sizeof t,"%s valid accepted",curve);     ck(t, verify(sig,m,ml,pub)==1);
  memcpy(b,sig,L); memset(b,0,nb);      snprintf(t,sizeof t,"%s r=0 rejected",curve); ck(t, verify(b,m,ml,pub)!=1);
  memcpy(b,sig,L); memset(b+nb,0,nb);   snprintf(t,sizeof t,"%s s=0 rejected",curve); ck(t, verify(b,m,ml,pub)!=1);
  memcpy(b,sig,L); memcpy(b,N,nb);      snprintf(t,sizeof t,"%s r=n rejected",curve); ck(t, verify(b,m,ml,pub)!=1);
  memcpy(b,sig,L); memcpy(b+nb,N,nb);   snprintf(t,sizeof t,"%s s=n rejected",curve); ck(t, verify(b,m,ml,pub)!=1);
  memcpy(b,sig,L); b[nb+2]^=1;          snprintf(t,sizeof t,"%s tampered rejected",curve); ck(t, verify(b,m,ml,pub)!=1);
  snprintf(t,sizeof t,"%s wrong msg rejected",curve); ck(t, verify(sig,(const unsigned char*)"different",9,pub)!=1);
  (void)pkb;
}
int main(void){
  one("P-256",32,65,rktcrypto_p256_pubkey,rktcrypto_p256_ecdsa_sign,rktcrypto_p256_ecdsa_verify,N256);
  one("P-384",48,97,rktcrypto_p384_pubkey,rktcrypto_p384_ecdsa_sign,rktcrypto_p384_ecdsa_verify,N384);
  one("P-521",66,133,rktcrypto_p521_pubkey,rktcrypto_p521_ecdsa_sign,rktcrypto_p521_ecdsa_verify,N521);
  printf("%s\n", fail?"FAILURES":"ALL PASS"); return fail;
}
