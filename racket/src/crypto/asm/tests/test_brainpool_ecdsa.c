/* Conformance test for brainpool ECDSA (rktcrypto_brainpoolP{256,384,512}_
   ecdsa_sign/verify). Interop KAT: a signature produced by python
   cryptography (randomized ECDSA, SHA-256/384/512) that our verify must
   accept — proves the hash-truncation and r||s encoding match the standard.
   Plus a sign->verify roundtrip and a tamper-rejection check.
   Links the built archive (real SHA + RNG needed by sign/verify):
     cc -O2 -I. -o t asm/tests/test_brainpool_ecdsa.c \
        <build>/cs/c/rktcrypto/librktcrypto.a */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include "rktcrypto.h"
/* brainpool ECDSA KAT: python-signed (r,s) our verify must accept. */
static const char *BPE_MSG="brainpool ecdsa KAT vector";
static const char *BPE256_D="000000000000000000000000000000001436587a9cbec0e30527496b8dafd1f3";
static const char *BPE256_X="2a7b96a1d067969a6e8298d70d3a73a372e76ea96e5f2e6e65b811c1dd1e001b",*BPE256_Y="175d73bd78316a9c22bdbef460b7b091d733247f5c1b12875f215bdd091a80d0";
static const char *BPE256_R="9312cf8d69106cf4e4324cf0cac0b36ecac06e7901232579579e99bc707b4b78",*BPE256_S="101b096a3dc373909ef921d01ee1cb08426ea68a787fe91d24c3ae1051af9d43";
static const char *BPE384_D="00000000000000000000000000000000000000000000000000000000000000001e5184b7eb1e215487baee215487baec";
static const char *BPE384_X="69c37d3aea9c3105f2f90a496b59362ddbb6fecd18be3444430c04ea21fe12266520b483ab47d1dfc3d2f91a5dc719c9",*BPE384_Y="0418973f12237e2cf039f974cee69b098e03881189d14375fcad11b08e5b5b92aa819616bfd7b2463c5e2a94821dac07";
static const char *BPE384_R="806ce391c4fbdda72c856836d8355b92d363153a59a2f810cd6523a8a6b8c62f293e2b5bc7433ba1cac1a721c08ab953",*BPE384_S="4460ca950e0e9ab03fa44faef192e8c60f07632347a25523130643fda3453a6d670102b75ce24583e8c6951359f7fd21";
static const char *BPE512_D="000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000286cb0f5397d81c60a4e92d71b5fa3e5";
static const char *BPE512_X="1d2ec11cf16f2c025ec87f95067963131d60444a802a41a3cbc75f21d8e431eecec50c45cc310589abff5a80711b0ff44a86e17ca2e57ff9109ab0235dca07a6",*BPE512_Y="2316914ec57cf3ee95756e4971433f005a7130f7f428de321043b6f0e62eb7c20bae86ec1b826054daa3dc138e71c5e575f5668d96b3a407e5a83d45b43799b6";
static const char *BPE512_R="7c65d39a3aa3df09c13036f5e528fe313e9880d513af7c73304890938bb96ae93263919ccf08505c81e0ef85911c145f472ba2e5748779787c2eb99312ff2710",*BPE512_S="1e33772971c6fdc444d43dfb6aea48bb301fb403bfbe04a965a7c789267330a071916e0f9c705bc52744c3996d11e768cc9a2fe2ab5374abc9915565cee6a4d9";
/* generated + python self-verified */
static int hx(const char*h,unsigned char*b,int n){for(int i=0;i<n;i++){unsigned x;if(sscanf(h+2*i,"%2x",&x)!=1)return 0;b[i]=x;}return 1;}
typedef int(*pkfn)(unsigned char*,const unsigned char*);
typedef int(*sgfn)(unsigned char*,const unsigned char*,intptr_t,const unsigned char*);
typedef int(*vffn)(const unsigned char*,const unsigned char*,intptr_t,const unsigned char*);
static int one(const char*name,int nb,pkfn pk,sgfn sign,vffn verify,
               const char*D,const char*X,const char*Y,const char*R,const char*S){
  unsigned char d[64],px[64],py[64],pub[129],sig[128],mine[128];
  hx(D,d,nb); hx(X,px,nb); hx(Y,py,nb);
  int mlen=(int)strlen(BPE_MSG);
  const unsigned char*msg=(const unsigned char*)BPE_MSG;
  /* 1) key agrees */
  if(!pk(pub,d)||pub[0]!=4||memcmp(pub+1,px,nb)||memcmp(pub+1+nb,py,nb)){printf("  %s: pubkey FAIL\n",name);return 0;}
  /* 2) interop: our verify accepts python's (r,s) */
  hx(R,sig,nb); hx(S,sig+nb,nb);
  int iv=verify(sig,msg,mlen,pub);
  /* 3) roundtrip: our sign then our verify */
  int rt=sign(mine,msg,mlen,d) && verify(mine,msg,mlen,pub);
  /* 4) tamper: modified message must be rejected */
  unsigned char bad[64]; memcpy(bad,msg,mlen); bad[0]^=0x01;
  int tj=(verify(sig,bad,mlen,pub)!=1);
  printf("  %s: interop-verify %s  roundtrip %s  tamper-reject %s\n",
         name, iv==1?"OK":"FAIL", rt?"OK":"FAIL", tj?"OK":"FAIL");
  return (iv==1)&&rt&&tj;
}
int main(void){ int ok=1;
  ok&=one("brainpoolP256r1",32,rktcrypto_brainpoolP256_pubkey,rktcrypto_brainpoolP256_ecdsa_sign,rktcrypto_brainpoolP256_ecdsa_verify,BPE256_D,BPE256_X,BPE256_Y,BPE256_R,BPE256_S);
  ok&=one("brainpoolP384r1",48,rktcrypto_brainpoolP384_pubkey,rktcrypto_brainpoolP384_ecdsa_sign,rktcrypto_brainpoolP384_ecdsa_verify,BPE384_D,BPE384_X,BPE384_Y,BPE384_R,BPE384_S);
  ok&=one("brainpoolP512r1",64,rktcrypto_brainpoolP512_pubkey,rktcrypto_brainpoolP512_ecdsa_sign,rktcrypto_brainpoolP512_ecdsa_verify,BPE512_D,BPE512_X,BPE512_Y,BPE512_R,BPE512_S);
  printf("\n%s\n",ok?"ALL PASS":"FAILURES"); return ok?0:1; }
