/* Differential + performance harness for the three bn Montgomery asm kernels:
     bn_mul_mont_op16   (rktcrypto_bn_op.S,   k=16 CIOS multiply)
     bn_mul_mont_fips32 (rktcrypto_bn_fips.S, k=32 fused multiply)
     bn_sqr_mont_8w     (rktcrypto_bn_sqr.S,  sqrx8x-layout squaring, num%8==0)
   Oracle = bn_montmul_gen (portable any-k CIOS montmul) from rktcrypto_bn.c,
   pulled in via #include so the static function is visible. For the squaring
   kernel the oracle is portable montmul(a,a).
   Build (from racket/src/crypto):
     cc -O2 -I.. -o /tmp/test_bn asm/tests/test_bn.c \
        rktcrypto_bn_op.S rktcrypto_bn_fips.S rktcrypto_bn_sqr.S && /tmp/test_bn
   Exit status is nonzero iff any differential mismatch or ABI guard failure. */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <mach/mach_time.h>
#include "../../rktcrypto_bn.c"

/* The three asm kernels are declared inside rktcrypto_bn.c (aarch64+Apple
   guard); this harness only targets that platform, same as the .S files. */

#define DIFF_ITERS 200000
#define BENCH_ITERS 1000000
#define WARMUP_ITERS 100000

static uint64_t st = 0x9e3779b97f4a7c15ULL;
static uint64_t xs(void){ st ^= st<<13; st ^= st>>7; st ^= st<<17; return st; }

static double tick_ns;
static void time_init(void){
  mach_timebase_info_data_t tb; mach_timebase_info(&tb);
  tick_ns = (double)tb.numer / (double)tb.denom;
}
static double now_ns(void){ return (double)mach_absolute_time() * tick_ns; }

/* Random real odd modulus: k limbs, top bit set (full width), low bit set. */
static void gen_modulus(BN *m, int k){
  int i;
  bn_zero(m);
  for(i = 0; i < k; i++) m->d[i] = xs();
  m->d[0]   |= 1ULL;
  m->d[k-1] |= 0x8000000000000000ULL;
  m->top = k;
}

static int raw_geq(const uint64_t *a, const uint64_t *m, int k){
  int i;
  for(i = k-1; i >= 0; i--) if(a[i] != m[i]) return a[i] > m[i];
  return 1;
}
static void raw_sub_m(uint64_t *a, const uint64_t *m, int k){
  u128 br = 0; int i;
  for(i = 0; i < k; i++){ u128 s = (u128)a[i] - m[i] - br; a[i] = (uint64_t)s; br = (s>>64)&1; }
}
/* Random valid Montgomery residue: k random limbs, reduced below m (m's top
   bit is set, so at most one conditional subtract is needed). */
static void gen_below(uint64_t *a, const BN *m, int k){
  int i;
  for(i = 0; i < k; i++) a[i] = xs();
  if(raw_geq(a, m->d, k)) raw_sub_m(a, m->d, k);
}
static void set_m_minus_1(uint64_t *a, const BN *m, int k){
  memcpy(a, m->d, (size_t)k*8);
  a[0] -= 1;              /* m odd => no borrow */
}
static void bn_from_raw(BN *x, const uint64_t *a, int k){
  bn_zero(x);
  memcpy(x->d, a, (size_t)k*8);
  x->top = k;
  while(x->top > 0 && x->d[x->top-1] == 0) x->top--;
}

/* ---------------- differential: k-fixed multiply kernels ---------------- */
typedef void (*mm_fn)(uint64_t*, const uint64_t*, const uint64_t*, const uint64_t*, uint64_t);

static int diff_mul(mm_fn fn, int k, const char *name){
  int fails = 0, t;
  for(t = 0; t < DIFF_ITERS; t++){
    BN M, A, B, R1;
    uint64_t a[32], b[32], r2[32];
    uint64_t n0;
    gen_modulus(&M, k);
    gen_below(a, &M, k);
    gen_below(b, &M, k);
    /* boundary cases (against this iteration's random modulus) */
    if(t == 0){ memset(a, 0, (size_t)k*8); memset(b, 0, (size_t)k*8); }
    if(t == 1){ memset(a, 0, (size_t)k*8); a[0] = 1; set_m_minus_1(b, &M, k); }
    if(t == 2){ set_m_minus_1(a, &M, k); set_m_minus_1(b, &M, k); }
    if(t == 3){ memset(a, 0, (size_t)k*8); set_m_minus_1(b, &M, k); }
    if(t == 4){ memset(a, 0, (size_t)k*8); a[0] = 1; memset(b, 0, (size_t)k*8); b[0] = 1; }
    n0 = bn_mont_n0(&M);
    bn_from_raw(&A, a, k);
    bn_from_raw(&B, b, k);
    bn_montmul_gen(&R1, &A, &B, &M, n0);   /* oracle: portable CIOS */
    fn(r2, a, b, M.d, n0);
    if(memcmp(R1.d, r2, (size_t)k*8) != 0){
      if(++fails <= 3) printf("  %s MISMATCH t=%d\n", name, t);
    }
  }
  printf("%s vs portable CIOS (k=%d): %d/%d mismatches\n", name, k, fails, DIFF_ITERS);
  return fails;
}

/* ---------------- differential: squaring kernel ---------------- */
static int diff_sqr(int k, const char *name){
  int fails = 0, t;
  for(t = 0; t < DIFF_ITERS; t++){
    BN M, A, R1;
    uint64_t a[32], r2[32];
    uint64_t n0;
    gen_modulus(&M, k);
    gen_below(a, &M, k);
    if(t == 0) memset(a, 0, (size_t)k*8);
    if(t == 1){ memset(a, 0, (size_t)k*8); a[0] = 1; }
    if(t == 2) set_m_minus_1(a, &M, k);
    n0 = bn_mont_n0(&M);
    bn_from_raw(&A, a, k);
    bn_montmul_gen(&R1, &A, &A, &M, n0);   /* oracle: portable montmul(a,a) */
    bn_sqr_mont_8w(r2, a, M.d, &n0, k);
    if(memcmp(R1.d, r2, (size_t)k*8) != 0){
      if(++fails <= 3) printf("  %s MISMATCH t=%d\n", name, t);
    }
  }
  printf("%s vs portable montmul(a,a) (k=%d): %d/%d mismatches\n", name, k, fails, DIFF_ITERS);
  return fails;
}

/* ---------------- ABI clobber guards ----------------
   Same pattern as asm/mont_mul_test.c: pin sentinels in the callee-saved GPRs
   x19-x28, call the kernel, verify they survive. */
#define ABI_SENTINELS \
  register uint64_t s19 asm("x19")=0x1919191919191919ULL; \
  register uint64_t s20 asm("x20")=0x2020202020202020ULL; \
  register uint64_t s21 asm("x21")=0x2121212121212121ULL; \
  register uint64_t s22 asm("x22")=0x2222222222222222ULL; \
  register uint64_t s23 asm("x23")=0x2323232323232323ULL; \
  register uint64_t s24 asm("x24")=0x2424242424242424ULL; \
  register uint64_t s25 asm("x25")=0x2525252525252525ULL; \
  register uint64_t s26 asm("x26")=0x2626262626262626ULL; \
  register uint64_t s27 asm("x27")=0x2727272727272727ULL; \
  register uint64_t s28 asm("x28")=0x2828282828282828ULL
#define ABI_BARRIER \
  asm volatile("":"+r"(s19),"+r"(s20),"+r"(s21),"+r"(s22),"+r"(s23),"+r"(s24),"+r"(s25),"+r"(s26),"+r"(s27),"+r"(s28))
#define ABI_CHECK \
  (s19==0x1919191919191919ULL&&s20==0x2020202020202020ULL&&s21==0x2121212121212121ULL&& \
   s22==0x2222222222222222ULL&&s23==0x2323232323232323ULL&&s24==0x2424242424242424ULL&& \
   s25==0x2525252525252525ULL&&s26==0x2626262626262626ULL&&s27==0x2727272727272727ULL&& \
   s28==0x2828282828282828ULL)

static int abi_guard_mul(mm_fn fn, int k){
  BN M; uint64_t a[32], b[32], r[32], n0;
  gen_modulus(&M, k); gen_below(a, &M, k); gen_below(b, &M, k); n0 = bn_mont_n0(&M);
  {
    ABI_SENTINELS;
    ABI_BARRIER;
    fn(r, a, b, M.d, n0);
    ABI_BARRIER;
    return ABI_CHECK;
  }
}
static int abi_guard_sqr(int k){
  BN M; uint64_t a[32], r[32], n0;
  gen_modulus(&M, k); gen_below(a, &M, k); n0 = bn_mont_n0(&M);
  {
    ABI_SENTINELS;
    ABI_BARRIER;
    bn_sqr_mont_8w(r, a, M.d, &n0, k);
    ABI_BARRIER;
    return ABI_CHECK;
  }
}

/* ---------------- performance ----------------
   One fixed input set stays cache-resident; warm up, then time BENCH_ITERS
   back-to-back calls with mach_absolute_time. */
static uint64_t sink;

static void bench_mul(mm_fn fn, int k, const char *name){
  BN M; uint64_t a[32], b[32], r[32], n0;
  int i; double t0, t1;
  gen_modulus(&M, k); gen_below(a, &M, k); gen_below(b, &M, k); n0 = bn_mont_n0(&M);
  for(i = 0; i < WARMUP_ITERS; i++) fn(r, a, b, M.d, n0);
  t0 = now_ns();
  for(i = 0; i < BENCH_ITERS; i++) fn(r, a, b, M.d, n0);
  t1 = now_ns();
  sink += r[0];
  printf("BENCH %s: %.2f ns/op\n", name, (t1 - t0) / (double)BENCH_ITERS);
}
static void bench_sqr(int k, const char *name){
  BN M; uint64_t a[32], r[32], n0;
  int i; double t0, t1;
  gen_modulus(&M, k); gen_below(a, &M, k); n0 = bn_mont_n0(&M);
  for(i = 0; i < WARMUP_ITERS; i++) bn_sqr_mont_8w(r, a, M.d, &n0, k);
  t0 = now_ns();
  for(i = 0; i < BENCH_ITERS; i++) bn_sqr_mont_8w(r, a, M.d, &n0, k);
  t1 = now_ns();
  sink += r[0];
  printf("BENCH %s: %.2f ns/op\n", name, (t1 - t0) / (double)BENCH_ITERS);
}

int main(void){
  int fails = 0, abi;
  time_init();

  /* differential */
  fails += diff_mul(bn_mul_mont_op16,   16, "bn_mul_mont_op16");
  fails += diff_mul(bn_mul_mont_fips32, 32, "bn_mul_mont_fips32");
  fails += diff_sqr(8,  "bn_sqr_mont_8w");
  /* extra coverage at the sizes the library actually routes to the kernel */
  fails += diff_sqr(16, "bn_sqr_mont_8w");
  fails += diff_sqr(32, "bn_sqr_mont_8w");

  /* ABI clobber guards */
  abi = abi_guard_mul(bn_mul_mont_op16, 16);
  printf("ABI guard bn_mul_mont_op16:   %s\n", abi ? "PASS" : "FAIL (clobbered x19-x28)");
  if(!abi) fails++;
  abi = abi_guard_mul(bn_mul_mont_fips32, 32);
  printf("ABI guard bn_mul_mont_fips32: %s\n", abi ? "PASS" : "FAIL (clobbered x19-x28)");
  if(!abi) fails++;
  abi = abi_guard_sqr(8);
  printf("ABI guard bn_sqr_mont_8w:     %s\n", abi ? "PASS" : "FAIL (clobbered x19-x28)");
  if(!abi) fails++;

  /* performance */
  bench_mul(bn_mul_mont_op16,   16, "bn_mul_mont_op16");
  bench_mul(bn_mul_mont_fips32, 32, "bn_mul_mont_fips32");
  bench_sqr(8,  "bn_sqr_mont_8w");
  bench_sqr(16, "bn_sqr_mont_8w_k16");
  bench_sqr(32, "bn_sqr_mont_8w_k32");

  printf("=> %s\n", fails ? "FAIL" : "ALL PASS");
  return fails != 0;
}
