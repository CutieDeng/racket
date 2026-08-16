/* Differential for the dedicated symmetric mod-p repeated squarer _mont_sqrn_p256
   (rktcrypto_p256_hand.S) vs a portable C oracle (mont_mul_portable looped).
   Build (from racket/src/crypto):
     cc -O2 -o /tmp/t_msqn asm/tests/test_mont_sqrn.c rktcrypto_p256_asm.S \
        rktcrypto_p256_hand.S rktcrypto_bn.c rktcrypto_bn_op.S rktcrypto_bn_fips.S \
        rktcrypto_bn_sqr.S && /tmp/t_msqn */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <mach/mach_time.h>
#define P256_SELFTEST
#include "../../rktcrypto_p256.c"
int rktcrypto_random_bytes(unsigned char*b,intptr_t s,intptr_t e){return 0;}
int rktcrypto_digest_oneshot(int a,const unsigned char*m,intptr_t s,intptr_t e,unsigned char*o,intptr_t os,intptr_t ol){return 0;}
static uint64_t st=0x2545f4914f6cdd1dULL; static uint64_t xs(void){st^=st<<13;st^=st>>7;st^=st<<17;return st;}
static void oracle(u64 r[4],const u64 a[4],u64 rep){ u64 v[4]; memcpy(v,a,32); for(u64 i=0;i<rep;i++) mont_mul_portable(v,v,v,&FP); memcpy(r,v,32); }
int main(void){
  p256_init();
  static const u64 REPS[5]={1,2,5,8,255};
  int fails=0;
  for(int t=0;t<200000;t++){
    u64 a[4],r1[4],r2[4]; for(int i=0;i<4;i++)a[i]=xs();
    if(bn_geq(a,FP.m)) bn_sub(a,a,FP.m);
    u64 rep=REPS[t%5];
    if(t==0)memset(a,0,32);
    if(t==1){memset(a,0,32);a[0]=1;}
    if(t==2){for(int i=0;i<4;i++)a[i]=FP.m[i];a[0]--;}
    mont_sqrn_p256(r1,a,rep);
    oracle(r2,a,rep);
    if(memcmp(r1,r2,32)!=0){ if(++fails<=3) printf("  MISMATCH t=%d rep=%llu\n",t,(unsigned long long)rep); }
  }
  printf("mont_sqrn_p256 (dedicated) vs C oracle: %d/200000 mismatches\n",fails);
  return fails?1:0;
}
