#include <stdio.h>
#include <string.h>
#include <stdint.h>
#define P256_SELFTEST
#include "rktcrypto_p256.c"
int rktcrypto_random_bytes(unsigned char*b,intptr_t s,intptr_t e){(void)b;(void)s;(void)e;return 0;}
int rktcrypto_digest_oneshot(int a,const unsigned char*m,intptr_t s,intptr_t e,unsigned char*o,intptr_t os,intptr_t ol){(void)a;(void)m;(void)s;(void)e;(void)o;(void)os;(void)ol;return 0;}
extern void mont_mul_p256(u64 r[4],const u64 a[4],const u64 b[4]);
static uint64_t st=0xda3e39cb94b95bdbULL;
static uint64_t xs(void){st^=st<<13;st^=st>>7;st^=st<<17;return st;}
int main(void){p256_init();
 int fails=0;
 for(int t=0;t<1000000;t++){
   u64 a[4],b[4],r1[4],r2[4];int i;
   for(i=0;i<4;i++){a[i]=xs();b[i]=xs();}
   if(bn_geq(a,P))bn_sub(a,a,P); if(bn_geq(b,P))bn_sub(b,b,P);
   if(t==0){memset(a,0,32);memset(b,0,32);}
   if(t==1){memset(a,0,32);a[0]=1;for(i=0;i<4;i++)b[i]=P[i];b[0]--;}       /* 1 * (p-1) */
   if(t==2){for(i=0;i<4;i++){a[i]=P[i];b[i]=P[i];}a[0]--;b[0]--;}          /* (p-1)^2 */
   mont_mul_portable(r1,a,b,&FP);
   mont_mul_p256(r2,a,b);
   if(memcmp(r1,r2,32)){ if(++fails<=4) printf("MISMATCH t=%d a0=%llx b0=%llx\n",t,(unsigned long long)a[0],(unsigned long long)b[0]); }
 }
 printf("mont_mul_p256 vs C[mod p]: %d/1000000 mismatches\n",fails);
 return fails!=0;}
