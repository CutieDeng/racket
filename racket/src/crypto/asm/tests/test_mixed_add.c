/* Differential + interleaved bench for the hand-scheduled _mixed_add_hw
   (rktcrypto_p256_hand.S) vs the portable C mixed_add_portable. Build (from
   racket/src/crypto):
     cc -O2 -I.. -o /tmp/t_ma asm/tests/test_mixed_add.c rktcrypto_p256_asm.S \
        rktcrypto_p256_hand.S rktcrypto_bn.c rktcrypto_bn_op.S rktcrypto_bn_fips.S \
        rktcrypto_bn_sqr.S && /tmp/t_ma
   On aarch64+apple the library routes mixed_add -> mixed_add_hw; the C body is
   kept as mixed_add_portable (the oracle here). */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <mach/mach_time.h>
#define P256_SELFTEST
#include "../../rktcrypto_p256.c"
int rktcrypto_random_bytes(unsigned char*b,intptr_t s,intptr_t e){for(intptr_t i=s;i<e;i++)b[i]=(unsigned char)(i*7+1);return 0;}
int rktcrypto_digest_oneshot(int a,const unsigned char*m,intptr_t s,intptr_t e,unsigned char*o,intptr_t os,intptr_t ol){return 0;}
static uint64_t st=0x243f6a8885a308d3ULL; static uint64_t xs(void){st^=st<<13;st^=st>>7;st^=st<<17;return st;}
static mach_timebase_info_data_t tb;
int main(void){
  p256_init();
  jac base,acc,r1,r2; base_point(&base); acc=base;
  int fails=0;
  for(int t=0;t<200000;t++){
    jac p=acc, q; int kk=(int)(xs()%16)+1; q=base;
    for(int i=1;i<kk;i++) mixed_add_portable(&q,&q,&base);
    { jac qa[1]; qa[0]=q; batch_affine(qa,1); q=qa[0]; }
    if(t==0){ for(int i=0;i<4;i++) p.Z[i]=0; }   /* p=identity */
    if(t==1){ p=base; q=base; }                   /* q==p -> double */
    mixed_add_hw(&r1,&p,&q);
    mixed_add_portable(&r2,&p,&q);
    if(memcmp(&r1,&r2,sizeof(jac))!=0){ if(++fails<=3) printf("  MISMATCH t=%d\n",t); }
    if(t%3==0) jac_double(&acc,&acc); else mixed_add_portable(&acc,&acc,&base);
    if(fp_iszero(acc.Z)) acc=base;
  }
  printf("mixed_add_hw vs mixed_add_portable: %d/200000 mismatches\n",fails);
  /* interleaved bench (load-immune ratio) */
  jac p=base,q; { jac qa[1]; qa[0]=base; mixed_add_portable(&qa[0],&qa[0],&base); batch_affine(qa,1); q=qa[0]; }
  mach_timebase_info(&tb); double aC=0,aH=0; long RN=2000,BR=3000;
  for(int i=0;i<5000;i++){ mixed_add_hw(&r1,&p,&q); mixed_add_portable(&r2,&p,&q); }
  for(long r=0;r<RN;r++){
    uint64_t t0=mach_absolute_time(); for(long i=0;i<BR;i++) mixed_add_portable(&r2,&p,&q);
    uint64_t t1=mach_absolute_time(); for(long i=0;i<BR;i++) mixed_add_hw(&r1,&p,&q);
    uint64_t t2=mach_absolute_time(); aC+=(double)(t1-t0); aH+=(double)(t2-t1);
  }
  double c=aC*tb.numer/tb.denom/(RN*BR), h=aH*tb.numer/tb.denom/(RN*BR);
  printf("mixed_add: C %.1f ns, asm %.1f ns, ratio %.3f\n",c,h,h/c);
  return fails?1:0;
}
