/* Differential + performance harness for the extra P-256 asm kernels in
   rktcrypto_p256_asm.S that mont_mul_test.c / mont_mul_p256_test.c do NOT
   cover:
     mont_sqrn_p256  (n back-to-back Montgomery squarings mod p, Solinas)
     mont_sqrn_asm   (n back-to-back Montgomery squarings, generic ctx)
     jac_double_hw   (Jacobian point doubling, jac layout X@0 Y@32 Z@64)
   Oracle = the portable C in rktcrypto_p256.c (mont_mul_portable looped, and
   jac_double_portable). Build (from racket/src/crypto):
     cc -O2 -o /tmp/test_p256_extra asm/tests/test_p256_extra.c rktcrypto_p256_asm.S
*/
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <time.h>
#define P256_SELFTEST
#include "../../rktcrypto_p256.c"
int rktcrypto_random_bytes(unsigned char*b,intptr_t s,intptr_t e){(void)b;(void)s;(void)e;return 0;}
int rktcrypto_digest_oneshot(int a,const unsigned char*m,intptr_t s,intptr_t e,unsigned char*o,intptr_t os,intptr_t ol){(void)a;(void)m;(void)s;(void)e;(void)o;(void)os;(void)ol;return 0;}

/* Kernel externs already declared inside rktcrypto_p256.c:
     void mont_sqrn_p256(u64 r[4],const u64 a[4],u64 rep);
     void mont_sqrn_asm (u64 r[4],const u64 a[4],u64 rep,const mont_ctx *ctx);
     void jac_double_hw (jac *r,const jac *p);   // jac { u64 X[4],Y[4],Z[4]; }
   All are called with rep >= 1 / Z != 0 by the library (the jac_double
   wrapper peels Z==0 before entering the asm), so the tests do the same. */

static uint64_t st=0x9e3779b97f4a7c15ULL;
static uint64_t xs(void){ st^=st<<13; st^=st>>7; st^=st<<17; return st; }

static void rand_residue(u64 a[4],const u64 m[4]){
  int i; for(i=0;i<4;i++) a[i]=xs();
  if(bn_geq(a,m)) bn_sub(a,a,m);
}

static double now_ns(void){
  struct timespec ts; clock_gettime(CLOCK_MONOTONIC,&ts);
  return (double)ts.tv_sec*1e9 + (double)ts.tv_nsec;
}

/* Oracle: n back-to-back Montgomery squarings via the portable CIOS. */
static void sqrn_oracle(u64 r[4],const u64 a[4],u64 n,const mont_ctx *ctx){
  u64 t[4]; int i; for(i=0;i<4;i++)t[i]=a[i];
  while(n-->0) mont_mul_portable(t,t,t,ctx);
  for(i=0;i<4;i++)r[i]=t[i];
}

/* ---------------- differential: mont_sqrn_p256 (mod p only) ------------- */
static int diff_sqrn_p256(void){
  int fails=0,t;
  for(t=0;t<200000;t++){
    u64 a[4],r1[4],r2[4]; u64 n=1+(xs()&7);          /* rep in 1..8 */
    rand_residue(a,FP.m);
    if(t==0){ memset(a,0,32); n=1; }                 /* 0 */
    if(t==1){ memset(a,0,32); a[0]=1; n=8; }         /* 1 */
    if(t==2){ int i; for(i=0;i<4;i++)a[i]=FP.m[i]; a[0]--; n=8; }  /* p-1 */
    sqrn_oracle(r1,a,n,&FP);
    mont_sqrn_p256(r2,a,n);
    if(memcmp(r1,r2,32)!=0){ if(++fails<=3) printf("  mont_sqrn_p256 MISMATCH t=%d n=%llu\n",t,(unsigned long long)n); }
  }
  printf("mont_sqrn_p256 vs C loop [mod p]: %d/200000 mismatches\n",fails);
  return fails;
}

/* ------------- differential: mont_sqrn_asm (generic, both ctx) ---------- */
static int diff_sqrn_asm(const mont_ctx *ctx,const char *name){
  int fails=0,t;
  for(t=0;t<200000;t++){
    u64 a[4],r1[4],r2[4]; u64 n=1+(xs()&7);          /* rep in 1..8 */
    rand_residue(a,ctx->m);
    if(t==0){ memset(a,0,32); n=1; }                 /* 0 */
    if(t==1){ memset(a,0,32); a[0]=1; n=8; }         /* 1 */
    if(t==2){ int i; for(i=0;i<4;i++)a[i]=ctx->m[i]; a[0]--; n=8; }  /* m-1 */
    sqrn_oracle(r1,a,n,ctx);
    mont_sqrn_asm(r2,a,n,ctx);
    if(memcmp(r1,r2,32)!=0){ if(++fails<=3) printf("  mont_sqrn_asm[%s] MISMATCH t=%d n=%llu\n",name,t,(unsigned long long)n); }
  }
  printf("mont_sqrn_asm vs C loop [%s]: %d/200000 mismatches\n",name,fails);
  return fails;
}

/* ---------------- differential: jac_double_hw --------------------------- */
/* The doubling formula is defined for arbitrary residues X,Y,Z (Z != 0), so
   random residue triples must match the portable formula bit for bit. Also
   walk a chain of genuine curve points (repeated doubling of G) and check
   the in-place r==p aliasing form the library relies on
   (jac_double(&acc,&acc)). */
static int diff_jac_double(void){
  int fails=0,t;
  /* phase 1: 150000 random residue triples, distinct r */
  for(t=0;t<150000;t++){
    jac p,o1,o2;
    rand_residue(p.X,FP.m); rand_residue(p.Y,FP.m); rand_residue(p.Z,FP.m);
    if(fp_iszero(p.Z)) p.Z[0]=1;                 /* asm contract: Z != 0 */
    if(t==0){ memset(p.X,0,32); }                /* X = 0 edge */
    if(t==1){ memset(p.Y,0,32); }                /* Y = 0 edge (2-torsion shape) */
    if(t==2){ int i; for(i=0;i<4;i++){p.X[i]=FP.m[i];p.Y[i]=FP.m[i];p.Z[i]=FP.m[i];} p.X[0]--;p.Y[0]--;p.Z[0]--; } /* p-1 */
    if(t==3){ memset(p.Z,0,32); p.Z[0]=1; }      /* Z = raw 1 */
    jac_double_portable(&o1,&p);
    jac_double_hw(&o2,&p);
    if(memcmp(&o1,&o2,sizeof(jac))!=0){ if(++fails<=3) printf("  jac_double_hw MISMATCH (random) t=%d\n",t); }
  }
  /* phase 2: 50000 random residue triples, in-place r==p on both sides */
  for(t=0;t<50000;t++){
    jac a1,a2;
    rand_residue(a1.X,FP.m); rand_residue(a1.Y,FP.m); rand_residue(a1.Z,FP.m);
    if(fp_iszero(a1.Z)) a1.Z[0]=1;
    a2=a1;
    jac_double_portable(&a1,&a1);
    jac_double_hw(&a2,&a2);
    if(memcmp(&a1,&a2,sizeof(jac))!=0){ if(++fails<=3) printf("  jac_double_hw MISMATCH (aliased) t=%d\n",t); }
  }
  /* phase 3: 10000-step chain of genuine points 2^k * G (Montgomery form) */
  { jac acc; int i; u64 one[4]={1,0,0,0};
    for(i=0;i<4;i++){ acc.X[i]=GX[i]; acc.Y[i]=GY[i]; }
    to_mont(acc.Z,one,&FP);
    for(t=0;t<10000;t++){
      jac o1,o2;
      jac_double_portable(&o1,&acc);
      jac_double_hw(&o2,&acc);
      if(memcmp(&o1,&o2,sizeof(jac))!=0){ if(++fails<=3) printf("  jac_double_hw MISMATCH (chain) t=%d\n",t); }
      acc=o1;                                    /* advance via the oracle */
    }
  }
  printf("jac_double_hw vs C [random+aliased+chain]: %d/210000 mismatches\n",fails);
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

static int abi_guard_sqrn_p256(void){
  u64 a[4]={1,2,3,4},r[4];
  GUARD_BODY(mont_sqrn_p256(r,a,8))
}
static int abi_guard_sqrn_asm(void){
  u64 a[4]={1,2,3,4},r[4];
  GUARD_BODY(mont_sqrn_asm(r,a,8,&FN))
}
static int abi_guard_jac_double(void){
  jac p,r; int i; u64 one[4]={1,0,0,0};
  for(i=0;i<4;i++){ p.X[i]=GX[i]; p.Y[i]=GY[i]; }
  to_mont(p.Z,one,&FP);
  GUARD_BODY(jac_double_hw(&r,&p))
}

/* ---------------- benchmarks ------------------------------------------- */
static void bench_all(void){
  int i; double t0,t1;
  /* mont_sqrn_p256: serial in-place chain, rep=1 per call (per-call cost),
     plus rep=8 amortized per squaring. */
  { u64 x[4]; rand_residue(x,FP.m);
    for(i=0;i<20000;i++) mont_sqrn_p256(x,x,1);            /* warmup */
    t0=now_ns(); for(i=0;i<500000;i++) mont_sqrn_p256(x,x,1); t1=now_ns();
    printf("BENCH mont_sqrn_p256 (rep=1): %.2f ns/op\n",(t1-t0)/500000.0);
    t0=now_ns(); for(i=0;i<500000;i++) mont_sqrn_p256(x,x,8); t1=now_ns();
    printf("BENCH mont_sqrn_p256 (rep=8 amortized): %.2f ns/sqr\n",(t1-t0)/500000.0/8.0);
    if(fp_iszero(x)) printf("(sink)\n"); }
  { u64 x[4]; rand_residue(x,FN.m);
    for(i=0;i<20000;i++) mont_sqrn_asm(x,x,1,&FN);         /* warmup */
    t0=now_ns(); for(i=0;i<500000;i++) mont_sqrn_asm(x,x,1,&FN); t1=now_ns();
    printf("BENCH mont_sqrn_asm (rep=1, mod n): %.2f ns/op\n",(t1-t0)/500000.0);
    t0=now_ns(); for(i=0;i<500000;i++) mont_sqrn_asm(x,x,8,&FN); t1=now_ns();
    printf("BENCH mont_sqrn_asm (rep=8 amortized, mod n): %.2f ns/sqr\n",(t1-t0)/500000.0/8.0);
    if(fp_iszero(x)) printf("(sink)\n"); }
  /* jac_double_hw: serial in-place doubling chain starting from G (2^k G is
     never the identity since ord(G)=n is prime, so Z stays nonzero). */
  { jac acc; u64 one[4]={1,0,0,0};
    for(i=0;i<4;i++){ acc.X[i]=GX[i]; acc.Y[i]=GY[i]; }
    to_mont(acc.Z,one,&FP);
    for(i=0;i<20000;i++) jac_double_hw(&acc,&acc);         /* warmup */
    t0=now_ns(); for(i=0;i<500000;i++) jac_double_hw(&acc,&acc); t1=now_ns();
    printf("BENCH jac_double_hw: %.2f ns/op\n",(t1-t0)/500000.0);
    if(fp_iszero(acc.Z)) printf("(sink)\n"); }
}

int main(void){
  int fails=0,g;
  p256_init();
  fails += diff_sqrn_p256();
  fails += diff_sqrn_asm(&FN,"mod n");   /* production ctx (scn_sqrn) */
  fails += diff_sqrn_asm(&FP,"mod p");   /* generic ctx cross-check */
  fails += diff_jac_double();
  g=abi_guard_sqrn_p256();
  printf("ABI guard mont_sqrn_p256: %s\n",g?"PASS":"FAIL (clobbered x19-x28)"); if(!g)fails++;
  g=abi_guard_sqrn_asm();
  printf("ABI guard mont_sqrn_asm:  %s\n",g?"PASS":"FAIL (clobbered x19-x28)"); if(!g)fails++;
  g=abi_guard_jac_double();
  printf("ABI guard jac_double_hw:  %s\n",g?"PASS":"FAIL (clobbered x19-x28)"); if(!g)fails++;
  bench_all();
  printf("=> %s\n",fails?"FAIL":"ALL PASS");
  return fails!=0;
}
