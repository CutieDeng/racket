#include <stdio.h>
#include <string.h>
#include <stdint.h>
#define P256_SELFTEST
#include "rktcrypto_p256.c"
int rktcrypto_random_bytes(unsigned char*b,intptr_t s,intptr_t e){(void)b;(void)s;(void)e;return 0;}
int rktcrypto_digest_oneshot(int a,const unsigned char*m,intptr_t s,intptr_t e,unsigned char*o,intptr_t os,intptr_t ol){(void)a;(void)m;(void)s;(void)e;(void)o;(void)os;(void)ol;return 0;}
extern void mont_sqr_p256(u64 r[4],const u64 a[4]);
static uint64_t st=0xabcdef;static uint64_t xs(void){st^=st<<13;st^=st>>7;st^=st<<17;return st;}
int main(void){p256_init();int fails=0;
 for(int t=0;t<1000000;t++){u64 a[4],r1[4],r2[4];int i;
  for(i=0;i<4;i++)a[i]=xs(); if(bn_geq(a,P))bn_sub(a,a,P);
  if(t==0)memset(a,0,32); if(t==1){for(i=0;i<4;i++)a[i]=P[i];a[0]--;}
  mont_mul_portable(r1,a,a,&FP); mont_sqr_p256(r2,a);
  if(memcmp(r1,r2,32)){if(++fails<=4)printf("MISMATCH t=%d\n",t);}}
 printf("mont_sqr_p256 vs C: %d/1000000 mismatches\n",fails); return fails!=0;}
