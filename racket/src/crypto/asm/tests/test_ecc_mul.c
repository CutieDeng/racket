/* Differential + performance harness for the ECC schoolbook multiply asm
   kernels in rktcrypto_ecc_asm.S (used by rktcrypto_ecc.c mul_wide for
   P-384 / P-521):
     mul_plain6  (6x6 limb -> 12 limb full product)
     mul_plain9  (9x9 limb -> 18 limb full product)
   Oracle = self-contained naive schoolbook (64x64->128 via __int128); the
   kernels are plain integer multiplies, so inputs range over the full
   64-bit limb domain (no modulus reduction). Build (from racket/src/crypto):
     cc -O2 -o /tmp/test_ecc_mul asm/tests/test_ecc_mul.c rktcrypto_ecc_asm.S
*/
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <time.h>

typedef uint64_t u64;
typedef unsigned __int128 u128;

extern void mul_plain6(u64 *r,const u64 *a,const u64 *b);   /* r[12] = a[6]*b[6] */
extern void mul_plain9(u64 *r,const u64 *a,const u64 *b);   /* r[18] = a[9]*b[9] */

static uint64_t st=0x243f6a8885a308d3ULL;
static uint64_t xs(void){ st^=st<<13; st^=st>>7; st^=st<<17; return st; }

static double now_ns(void){
  struct timespec ts; clock_gettime(CLOCK_MONOTONIC,&ts);
  return (double)ts.tv_sec*1e9 + (double)ts.tv_nsec;
}

/* Oracle: naive operand-scanning schoolbook, r[2n] = a[n]*b[n]. Row i writes
   r[i..i+n-1] plus the fresh top limb r[i+n], so zero-init is unnecessary
   beyond the first row's implicit zeros -- keep the memset for clarity. */
static void school_mul(u64 *r,const u64 *a,const u64 *b,int n){
  int i,j; memset(r,0,2*n*sizeof(u64));
  for(i=0;i<n;i++){
    u64 c=0;
    for(j=0;j<n;j++){
      u128 t=(u128)a[i]*b[j]+r[i+j]+c;
      r[i+j]=(u64)t; c=(u64)(t>>64);
    }
    r[i+n]=c;
  }
}

static int diff(int n,void(*krn)(u64*,const u64*,const u64*),const char *name){
  int fails=0,t,i;
  for(t=0;t<200000;t++){
    u64 a[9],b[9],r1[18],r2[18];
    for(i=0;i<n;i++){ a[i]=xs(); b[i]=xs(); }          /* full 64-bit domain */
    if(t==0){ memset(a,0,sizeof a); memset(b,0,sizeof b); }              /* 0 * 0 */
    if(t==1){ memset(a,0xff,n*8); memset(b,0xff,n*8); }                  /* max * max */
    if(t==2){ memset(a,0xff,n*8); memset(b,0,sizeof b); b[0]=1; }        /* max * 1 */
    if(t==3){ memset(a,0,sizeof a); memset(b,0xff,n*8); }                /* 0 * max */
    memset(r2,0xa5,sizeof r2);                          /* catch unwritten limbs */
    school_mul(r1,a,b,n);
    krn(r2,a,b);
    if(memcmp(r1,r2,2*n*8)!=0){ if(++fails<=3) printf("  %s MISMATCH t=%d\n",name,t); }
  }
  printf("%s vs C schoolbook: %d/200000 mismatches\n",name,fails);
  return fails;
}

/* ---------------- ABI callee-saved guard (x19-x28 sentinels) ------------ */
#define GUARD_BODY(CALL)                                                     \
  register uint64_t s19 asm("x19")=0x1919191919191919ULL;                    \
  register uint64_t s20 asm("x20")=0x2020202020202020ULL;                    \
  register uint64_t s21 asm("x21")=0x2121212121212121ULL;                    \
  register uint64_t s22 asm("x22")=0x2222222222222222ULL;                    \
  register uint64_t s23 asm("x23")=0x2323232323232323ULL;                    \
  register uint64_t s24 asm("x24")=0x2424242424242424ULL;                    \
  register uint64_t s25 asm("x25")=0x2525252525252525ULL;                    \
  register uint64_t s26 asm("x26")=0x2626262626262626ULL;                    \
  register uint64_t s27 asm("x27")=0x2727272727272727ULL;                    \
  register uint64_t s28 asm("x28")=0x2828282828282828ULL;                    \
  asm volatile("":"+r"(s19),"+r"(s20),"+r"(s21),"+r"(s22),"+r"(s23),         \
                 "+r"(s24),"+r"(s25),"+r"(s26),"+r"(s27),"+r"(s28));         \
  CALL;                                                                      \
  asm volatile("":"+r"(s19),"+r"(s20),"+r"(s21),"+r"(s22),"+r"(s23),         \
                 "+r"(s24),"+r"(s25),"+r"(s26),"+r"(s27),"+r"(s28));         \
  return s19==0x1919191919191919ULL&&s20==0x2020202020202020ULL&&            \
         s21==0x2121212121212121ULL&&s22==0x2222222222222222ULL&&            \
         s23==0x2323232323232323ULL&&s24==0x2424242424242424ULL&&            \
         s25==0x2525252525252525ULL&&s26==0x2626262626262626ULL&&            \
         s27==0x2727272727272727ULL&&s28==0x2828282828282828ULL;

static int abi_guard6(void){
  u64 a[6]={1,2,3,4,5,6},b[6]={7,8,9,10,11,12},r[12];
  GUARD_BODY(mul_plain6(r,a,b))
}
static int abi_guard9(void){
  u64 a[9]={1,2,3,4,5,6,7,8,9},b[9]={10,11,12,13,14,15,16,17,18},r[18];
  GUARD_BODY(mul_plain9(r,a,b))
}

/* ---------------- benchmarks (>= 1,000,000 calls each) ------------------ */
static void bench(int n,void(*krn)(u64*,const u64*,const u64*),const char *name){
  u64 a[9],b[9],r[18]; int i; double t0,t1;
  for(i=0;i<n;i++){ a[i]=xs(); b[i]=xs(); }
  for(i=0;i<50000;i++){ krn(r,a,b); a[0]^=r[2*n-1]; }        /* warmup */
  t0=now_ns();
  for(i=0;i<1000000;i++){ krn(r,a,b); a[0]^=r[2*n-1]; }      /* light serial dep */
  t1=now_ns();
  printf("BENCH %s: %.2f ns/op\n",name,(t1-t0)/1000000.0);
  if((r[0]|a[0])==0x12345678ULL) printf("(sink)\n");
}

int main(void){
  int fails=0,g;
  fails += diff(6,mul_plain6,"mul_plain6");
  fails += diff(9,mul_plain9,"mul_plain9");
  g=abi_guard6();
  printf("ABI guard mul_plain6: %s\n",g?"PASS":"FAIL (clobbered x19-x28)"); if(!g)fails++;
  g=abi_guard9();
  printf("ABI guard mul_plain9: %s\n",g?"PASS":"FAIL (clobbered x19-x28)"); if(!g)fails++;
  bench(6,mul_plain6,"mul_plain6");
  bench(9,mul_plain9,"mul_plain9");
  printf("=> %s\n",fails?"FAIL":"ALL PASS");
  return fails!=0;
}
