/* Differential + performance harness for the P-384 Solinas reduction asm
   kernel reduce_p384_asm (asm/reduce_p384.asm -> /tmp/reduce_p384.S, committed
   as rktcrypto_ecc_asm.S content on integration).

   Oracle = the static C reduce_p384 in rktcrypto_ecc.c, pulled in via #include
   so the static function, the P384_PL prime and bn_cmp/bn_sub are visible.
   ecc.c needs three library symbols (digest/random) it never reaches on the
   reduction path; they are stubbed here with the exact rktcrypto.h signatures
   (digest_size returns intptr_t; oneshot/random_bytes take intptr_t offsets).

   Build (from racket/src/crypto):
     cc -O2 -I.. -o /tmp/test_reduce_p384 asm/tests/test_reduce_p384.c \
        /tmp/reduce_p384.S rktcrypto_ecc_asm.S rktcrypto_bn.c rktcrypto_bn_op.S \
        rktcrypto_bn_fips.S rktcrypto_bn_sqr.S rktcrypto_p521rr.c && /tmp/test_reduce_p384

   Exit status is nonzero iff any differential mismatch or ABI guard failure. */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <mach/mach_time.h>

/* --- stubs for the library symbols ecc.c references (never hit here) --- */
int rktcrypto_random_bytes(unsigned char *buf, intptr_t start, intptr_t end){
  (void)buf; (void)start; (void)end; return 0;
}
intptr_t rktcrypto_digest_size(int alg){ (void)alg; return 0; }
int rktcrypto_digest_oneshot(int alg, const unsigned char *data, intptr_t start,
                             intptr_t end, unsigned char *out, intptr_t out_start,
                             intptr_t out_len){
  (void)alg; (void)data; (void)start; (void)end; (void)out; (void)out_start;
  (void)out_len; return 0;
}

#include "../../rktcrypto_ecc.c"   /* reduce_p384 (oracle), P384_PL, bn_cmp/sub, u64 */

extern void reduce_p384_asm(u64 *r, const u64 *prod);   /* subject (/tmp/reduce_p384.S) */

#ifndef DIFF_RAND
#define DIFF_RAND   200000
#endif
#define BENCH_ITERS 5000000
#define WARMUP      200000

#ifndef DIFF_SEED
#define DIFF_SEED   0x9e3779b97f4a7c15ULL
#endif
static uint64_t st = DIFF_SEED;
static uint64_t xs(void){ st ^= st<<13; st ^= st>>7; st ^= st<<17; return st; }

static double tick_ns;
static void time_init(void){
  mach_timebase_info_data_t tb; mach_timebase_info(&tb);
  tick_ns = (double)tb.numer / (double)tb.denom;
}
static double now_ns(void){ return (double)mach_absolute_time() * tick_ns; }

/* c' = 2^384 - p, as a 6-limb array (only limbs 0..2 nonzero). */
static const u64 CP[6] = {0xFFFFFFFF00000001ULL, 0x00000000FFFFFFFFULL, 1ULL, 0, 0, 0};

static int fails = 0;
static int shown = 0;
static void check(const u64 *prod, const char *tag){
  u64 r1[6], r2[6];
  reduce_p384(r1, prod);                 /* oracle */
  memset(r2, 0xa5, sizeof r2);           /* catch unwritten limbs */
  reduce_p384_asm(r2, prod);             /* subject */
  if(memcmp(r1, r2, sizeof r1) != 0){
    if(++fails <= 5){
      printf("  MISMATCH [%s]\n", tag);
      printf("    prod ="); for(int i=0;i<12;i++) printf(" %016llx",(unsigned long long)prod[i]); printf("\n");
      printf("    C   ="); for(int i=0;i<6;i++)  printf(" %016llx",(unsigned long long)r1[i]);  printf("\n");
      printf("    asm ="); for(int i=0;i<6;i++)  printf(" %016llx",(unsigned long long)r2[i]);  printf("\n");
    }
  }
}

/* ---------------- structured boundary cases ---------------- */
static void edge_cases(void){
  u64 p[12]; int i, k;

  memset(p,0,sizeof p);                              check(p,"all-zero");
  memset(p,0xff,sizeof p);                           check(p,"all-FF");
  memset(p,0,sizeof p); for(i=0;i<6;i++) p[i]=~0ULL; check(p,"lo=FF hi=0");
  memset(p,0,sizeof p); for(i=6;i<12;i++) p[i]=~0ULL;check(p,"lo=0 hi=FF");

  /* hi = 0 => value == lo; sweep lo across the p / 0 / 2^384 boundaries so the
     final conditional subtract is exercised on both sides. */
  for(k=0;k<=12;k++){
    memset(p,0,sizeof p);
    for(i=0;i<6;i++) p[i]=P384_PL[i];                /* lo = p */
    { u64 br=0; for(i=0;i<6;i++){ u128 d=(u128)p[i]-(u64)k-br; p[i]=(u64)d; br=(u64)((d>>64)&1);} } /* lo = p-k */
    check(p,"hi=0 lo=p-k");
    memset(p,0,sizeof p);
    for(i=0;i<6;i++) p[i]=P384_PL[i];
    { u64 c=(u64)k; for(i=0;i<6&&c;i++){ u128 s=(u128)p[i]+c; p[i]=(u64)s; c=(u64)(s>>64);} }       /* lo = p+k */
    check(p,"hi=0 lo=p+k");
  }
  /* lo = 2^384-1-k (top of the 6-limb range) */
  for(k=0;k<=8;k++){
    memset(p,0xff,48); memset(p+6,0,48);
    p[0]-=(u64)k;
    check(p,"hi=0 lo=2^384-1-k");
  }

  /* hi = 1 (hi[0]=1) => v = lo + c'; choose lo = p - c' - k so the folded value
     lands right around p. */
  for(k=0;k<=8;k++){
    memset(p,0,sizeof p);
    u64 lo[6]; bn_sub(lo,P384_PL,CP,6);              /* lo = p - c' */
    { u64 br=0; for(i=0;i<6;i++){ u128 d=(u128)lo[i]-(u64)k-br; lo[i]=(u64)d; br=(u64)((d>>64)&1);} }
    for(i=0;i<6;i++) p[i]=lo[i];
    p[6]=1;
    check(p,"hi=1 lo=p-c'-k");
  }

  /* hi with only the very top limb set (drives v8=1 and the stage-2/3 folds) */
  for(k=0;k<8;k++){
    memset(p,0,sizeof p);
    for(i=0;i<6;i++) p[i]=xs();
    p[11]=~0ULL - (u64)k;
    check(p,"hi5=FF-k");
  }
  /* hi = all-FF, lo random (max fold magnitude) */
  for(k=0;k<8;k++){
    for(i=0;i<6;i++) p[i]=xs();
    for(i=6;i<12;i++) p[i]=~0ULL;
    check(p,"hi=FF lo=rand");
  }
  /* single-limb spikes */
  for(k=0;k<12;k++){ memset(p,0,sizeof p); p[k]=~0ULL; check(p,"one-limb-FF"); }
  for(k=0;k<12;k++){ memset(p,0,sizeof p); p[k]=1;     check(p,"one-limb-1");  }
}

/* ---------------- random differential ---------------- */
static void random_diff(void){
  int t, i;
  for(t=0;t<DIFF_RAND;t++){
    u64 p[12];
    for(i=0;i<12;i++) p[i]=xs();                     /* full 64-bit domain */
    /* bias ~1/8 toward a small hi so v stays near 2^384 (subtract boundary) */
    if((t & 7)==0){ for(i=6;i<12;i++) p[i]=0; p[6]=xs()&0xff; }
    /* bias ~1/8 toward hi with a full top limb (max fold) */
    if((t & 7)==1){ p[11]=~0ULL; }
    check(p,"rand");
  }
}

/* ---------------- ABI callee-saved guard (x19-x28 sentinels) ---------------- */
static int abi_guard(void){
  u64 p[12], r[6]; int i;
  for(i=0;i<12;i++) p[i]=xs();
  {
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
    asm volatile("":"+r"(s19),"+r"(s20),"+r"(s21),"+r"(s22),"+r"(s23),
                    "+r"(s24),"+r"(s25),"+r"(s26),"+r"(s27),"+r"(s28));
    reduce_p384_asm(r, p);
    asm volatile("":"+r"(s19),"+r"(s20),"+r"(s21),"+r"(s22),"+r"(s23),
                    "+r"(s24),"+r"(s25),"+r"(s26),"+r"(s27),"+r"(s28));
    return s19==0x1919191919191919ULL&&s20==0x2020202020202020ULL&&
           s21==0x2121212121212121ULL&&s22==0x2222222222222222ULL&&
           s23==0x2323232323232323ULL&&s24==0x2424242424242424ULL&&
           s25==0x2525252525252525ULL&&s26==0x2626262626262626ULL&&
           s27==0x2727272727272727ULL&&s28==0x2828282828282828ULL;
  }
}

/* ---------------- performance ----------------
   throughput: input varies by the loop counter (no dependency on the previous
   output, and not hoistable), the number field arithmetic actually sees when
   independent multiplies pipeline.  latency: feed the output back into the input
   to serialise, an upper bound. */
static u64 sink;
static double bench_tput(void(*fn)(u64*,const u64*), const char *name){
  u64 p[12], r[6]; int i; double t0,t1; u64 s0;
  for(i=0;i<12;i++) p[i]=xs(); s0=p[0];
  for(i=0;i<WARMUP;i++){ p[0]=s0^(u64)i; fn(r,p); sink^=r[0]; }
  t0=now_ns();
  for(i=0;i<BENCH_ITERS;i++){ p[0]=s0^(u64)i; fn(r,p); sink^=r[0]; }
  t1=now_ns();
  double ns=(t1-t0)/(double)BENCH_ITERS;
  printf("BENCH %s (throughput): %.2f ns\n", name, ns);
  return ns;
}
static double bench_lat(void(*fn)(u64*,const u64*), const char *name){
  u64 p[12], r[6]; int i; double t0,t1;
  for(i=0;i<12;i++) p[i]=xs();
  for(i=0;i<WARMUP;i++){ fn(r,p); p[0]^=r[0]; }
  t0=now_ns();
  for(i=0;i<BENCH_ITERS;i++){ fn(r,p); p[0]^=r[0]; }
  t1=now_ns();
  sink += r[0];
  double ns=(t1-t0)/(double)BENCH_ITERS;
  printf("BENCH %s (latency):    %.2f ns\n", name, ns);
  return ns;
}
/* thin wrapper so the C oracle (static, non-extern type) fits the fn pointer */
static void c_reduce(u64 *r, const u64 *prod){ reduce_p384(r, prod); }

int main(void){
  int abi;
  time_init();

  edge_cases();
  random_diff();
  printf("reduce_p384_asm vs C reduce_p384: %d/%d mismatches\n",
         fails, DIFF_RAND);

  abi = abi_guard();
  printf("ABI guard reduce_p384_asm: %s\n", abi ? "PASS" : "FAIL (clobbered x19-x28)");

  bench_tput(c_reduce,        "reduce_p384_C  ");
  bench_tput(reduce_p384_asm, "reduce_p384_asm");
  bench_lat (c_reduce,        "reduce_p384_C  ");
  bench_lat (reduce_p384_asm, "reduce_p384_asm");

  (void)shown;
  int bad = (fails != 0) || !abi;
  printf("=> %s\n", bad ? "FAIL" : "ALL PASS");
  return bad ? 1 : 0;
}
