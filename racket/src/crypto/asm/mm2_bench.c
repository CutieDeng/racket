#include <stdio.h>
#include <stdint.h>
#include <time.h>
#define P256_SELFTEST
#include "rktcrypto_p256.c"
int rktcrypto_random_bytes(unsigned char*b,intptr_t s,intptr_t e){(void)b;(void)s;(void)e;return 0;}
int rktcrypto_digest_oneshot(int a,const unsigned char*m,intptr_t s,intptr_t e,unsigned char*o,intptr_t os,intptr_t ol){(void)a;(void)m;(void)s;(void)e;(void)o;(void)os;(void)ol;return 0;}
extern void mont_mul_p256(u64 r[4],const u64 a[4],const u64 b[4]);     /* CIOS (mm2.o) */
extern void mont_mul_p256_sos(u64 r[4],const u64 a[4],const u64 b[4]); /* SOS (renamed) */
static double now(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec+t.tv_nsec*1e-9;}
int main(void){p256_init();
 u64 a[4]={0x1234,0x5678,0x9abc,0xdef0},b[4]={0xfeed,0xface,0xcafe,0xbabe},r[4];
 to_mont(a,a,&FP);to_mont(b,b,&FP);
 int reps=40000000;double t0,ds,dc;
 t0=now();for(int i=0;i<reps;i++){mont_mul_p256_sos(r,a,b);a[0]^=r[0];}ds=now()-t0;
 t0=now();for(int i=0;i<reps;i++){mont_mul_p256(r,a,b);a[0]^=r[0];}dc=now()-t0;
 printf("SOS  mont_mul_p256: %.1f Mmul/s\n",reps/ds/1e6);
 printf("CIOS mont_mul_p256: %.1f Mmul/s (%.2fx SOS)\n",reps/dc/1e6,ds/dc);
 return 0;}
