/* Differential + ABI-clobber harness for the asmp mont_mul.
   Oracle = the C mont_mul in rktcrypto_p256.c. Build:
     cc -O2 -I<crypto> montmul_test.c montmul.o -o /tmp/mmt && /tmp/mmt */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#define P256_SELFTEST
#include "rktcrypto_p256.c"
int rktcrypto_random_bytes(unsigned char*b,intptr_t s,intptr_t e){(void)b;(void)s;(void)e;return 0;}
int rktcrypto_digest_oneshot(int a,const unsigned char*m,intptr_t s,intptr_t e,unsigned char*o,intptr_t os,intptr_t ol){(void)a;(void)m;(void)s;(void)e;(void)o;(void)os;(void)ol;return 0;}

extern void mont_mul_asm(u64 r[4], const u64 a[4], const u64 b[4], const mont_ctx *ctx);

static uint64_t st=0x9e3779b97f4a7c15ULL;
static uint64_t xs(void){ st^=st<<13; st^=st>>7; st^=st<<17; return st; }

/* ABI clobber guard: set all callee-saved GPRs to sentinels, call the asm,
   verify they survive. A bad prologue/epilogue corrupts these. */
static int abi_guard(void){
  register uint64_t s19 asm("x19")=0x1919191919191919ULL;
  register uint64_t s20 asm("x20")=0x2020202020202020ULL;
  register uint64_t s21 asm("x21")=0x2121212121212121ULL;
  register uint64_t s22 asm("x22")=0x2222222222222222ULL;
  register uint64_t s23 asm("x23")=0x2323232323232323ULL;
  register uint64_t s24 asm("x24")=0x2424242424242424ULL;
  register uint64_t s25 asm("x25")=0x2525252525252525ULL;
  register uint64_t s26 asm("x26")=0x2626262626262626ULL;
  register uint64_t s27 asm("x27")=0x2727272727272727ULL;
  register uint64_t s28 asm("x28")=0x2828282828282828ULL;
  u64 a[4]={1,2,3,4}, b[4]={5,6,7,8}, r[4];
  asm volatile("":"+r"(s19),"+r"(s20),"+r"(s21),"+r"(s22),"+r"(s23),"+r"(s24),"+r"(s25),"+r"(s26),"+r"(s27),"+r"(s28));
  mont_mul_asm(r,a,b,&FP);
  asm volatile("":"+r"(s19),"+r"(s20),"+r"(s21),"+r"(s22),"+r"(s23),"+r"(s24),"+r"(s25),"+r"(s26),"+r"(s27),"+r"(s28));
  return s19==0x1919191919191919ULL&&s20==0x2020202020202020ULL&&s21==0x2121212121212121ULL&&
         s22==0x2222222222222222ULL&&s23==0x2323232323232323ULL&&s24==0x2424242424242424ULL&&
         s25==0x2525252525252525ULL&&s26==0x2626262626262626ULL&&s27==0x2727272727272727ULL&&s28==0x2828282828282828ULL;
}

static int diff(const mont_ctx *ctx, const char *name){
  int fails=0, t;
  for(t=0;t<200000;t++){
    u64 a[4],b[4],r1[4],r2[4]; int i;
    for(i=0;i<4;i++){ a[i]=xs(); b[i]=xs(); }
    /* reduce inputs below modulus so they're valid Montgomery residues */
    if(bn_geq(a,ctx->m)) bn_sub(a,a,ctx->m);
    if(bn_geq(b,ctx->m)) bn_sub(b,b,ctx->m);
    if(t==0){ memset(a,0,32); memset(b,0,32); }
    if(t==1){ memset(a,0,32); a[0]=1; for(i=0;i<4;i++)b[i]=ctx->m[i]; b[0]--; }
    mont_mul_portable(r1,a,b,ctx);
    mont_mul_asm(r2,a,b,ctx);
    if(memcmp(r1,r2,32)!=0){ if(++fails<=3) printf("  %s MISMATCH t=%d\n",name,t); }
  }
  printf("mont_mul_asm vs C [%s]: %d/200000 mismatches\n", name, fails);
  return fails;
}

int main(void){
  int fails=0;
  p256_init();
  fails += diff(&FP, "mod p");
  fails += diff(&FN, "mod n");
  int abi = abi_guard();
  printf("ABI callee-saved guard: %s\n", abi?"PASS":"FAIL (clobbered x19-x28)");
  if(!abi) fails++;
  printf("=> %s\n", fails?"FAIL":"ALL PASS");
  return fails!=0;
}
