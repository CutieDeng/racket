/* Differential + ABI-clobber + bench harness for the 2-way batched
   Keccak-f[1600] kernel (rktcrypto_keccak_f2_asm.S). Oracle = a from-scratch
   FIPS 202 Keccak-f[1600] written here, run once per lane (no dependency on
   the library's intrinsics implementation). Build (from racket/src/crypto):
     cc -O2 -o /tmp/test_keccak_f2 asm/tests/test_keccak_f2.c rktcrypto_keccak_f2_asm.S
     /tmp/test_keccak_f2

   Kernel semantics (per rktcrypto_slhdsa.c:75/84-94 and gen_keccak_f2.py):
     void keccak_f2_asm(uint64_t st[50], const uint64_t rc[24]);
   st is two Keccak states interleaved lane-major: st[2*i] = state0 word i,
   st[2*i+1] = state1 word i (i = 0..24). One call runs the full 24-round
   Keccak-f[1600] on both states (both NEON lanes) and writes st back. */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <mach/mach_time.h>

void keccak_f2_asm(uint64_t st[50], const uint64_t rc[24]);

/* ---- reference Keccak-f[1600], straight from FIPS 202 ---- */
static const uint64_t KRC[24] = {
  0x0000000000000001ULL, 0x0000000000008082ULL, 0x800000000000808aULL,
  0x8000000080008000ULL, 0x000000000000808bULL, 0x0000000080000001ULL,
  0x8000000080008081ULL, 0x8000000000008009ULL, 0x000000000000008aULL,
  0x0000000000000088ULL, 0x0000000080008009ULL, 0x000000008000000aULL,
  0x000000008000808bULL, 0x800000000000008bULL, 0x8000000000008089ULL,
  0x8000000000008003ULL, 0x8000000000008002ULL, 0x8000000000000080ULL,
  0x000000000000800aULL, 0x800000008000000aULL, 0x8000000080008081ULL,
  0x8000000000008080ULL, 0x0000000080000001ULL, 0x8000000080008008ULL
};

/* n == 0 must be handled: v >> 64 is UB and KRHO[0] is 0 */
static uint64_t rotl64(uint64_t v, int n) { return n ? (v << n) | (v >> (64 - n)) : v; }

/* rho offsets, indexed by lane x + 5*y */
static const int KRHO[25] = {
   0,  1, 62, 28, 27,
  36, 44,  6, 55, 20,
   3, 10, 43, 25, 39,
  41, 45, 15, 21,  8,
  18,  2, 61, 56, 14
};

static void keccak_f_ref(uint64_t A[25])
{
  int round, x, y;
  for (round = 0; round < 24; round++) {
    uint64_t C[5], D, B[25];
    /* theta */
    for (x = 0; x < 5; x++)
      C[x] = A[x] ^ A[x+5] ^ A[x+10] ^ A[x+15] ^ A[x+20];
    for (x = 0; x < 5; x++) {
      D = C[(x+4)%5] ^ rotl64(C[(x+1)%5], 1);
      for (y = 0; y < 5; y++) A[x+5*y] ^= D;
    }
    /* rho + pi: B[y, 2x+3y] = rot(A[x, y]) */
    for (x = 0; x < 5; x++)
      for (y = 0; y < 5; y++)
        B[y + 5*((2*x+3*y)%5)] = rotl64(A[x+5*y], KRHO[x+5*y]);
    /* chi */
    for (y = 0; y < 5; y++)
      for (x = 0; x < 5; x++)
        A[x+5*y] = B[x+5*y] ^ (~B[(x+1)%5 + 5*y] & B[(x+2)%5 + 5*y]);
    /* iota */
    A[0] ^= KRC[round];
  }
}

/* oracle self-check: Keccak-f[1600] of the zero state
   (KeccakF-1600-IntermediateValues.txt, first four lanes) */
static int oracle_selfcheck(void)
{
  uint64_t st[25];
  memset(st, 0, sizeof st);
  keccak_f_ref(st);
  if (st[0] != 0xF1258F7940E1DDE7ULL || st[1] != 0x84D5CCF933C0478AULL ||
      st[2] != 0xD598261EA65AA9EEULL || st[3] != 0xBD1547306F80494DULL) {
    printf("oracle self-check FAILED (Keccak-f zero-state vector)\n");
    return 1;
  }
  return 0;
}

/* ---- rng ---- */
static uint64_t rst = 0x9e3779b97f4a7c15ULL;
static uint64_t xs(void) { rst ^= rst << 13; rst ^= rst >> 7; rst ^= rst << 17; return rst; }

/* ---- differential: asm 2-way vs one reference permutation per lane ---- */
static int diff_f2(void)
{
  int fails = 0;
  long t;
  for (t = 0; t < 200000; t++) {
    uint64_t st[50], a[25], b[25];
    int i, bad = 0;
    for (i = 0; i < 50; i++) st[i] = xs();
    if (t == 0) memset(st, 0, sizeof st);          /* both lanes zero state */
    if (t == 1) memset(st, 0xFF, sizeof st);       /* both lanes all-FF */
    if (t == 2) { memset(st, 0, sizeof st);        /* asymmetric lanes */
                  for (i = 0; i < 25; i++) st[2*i+1] = 0xFFFFFFFFFFFFFFFFULL; }
    for (i = 0; i < 25; i++) { a[i] = st[2*i]; b[i] = st[2*i+1]; }
    keccak_f2_asm(st, KRC);
    keccak_f_ref(a);
    keccak_f_ref(b);
    for (i = 0; i < 25; i++)
      if (st[2*i] != a[i] || st[2*i+1] != b[i]) bad = 1;
    if (bad) { if (++fails <= 3) printf("  keccak_f2_asm MISMATCH t=%ld\n", t); }
  }
  printf("keccak_f2_asm vs ref: %d/200000 mismatches\n", fails);
  return fails;
}

/* ---- ABI clobber guard ----
   Sentinels in all callee-saved GPRs x19-x28 AND in d8-d15 (the low 64 bits
   of v8-v15, callee-saved under AAPCS64; the kernel uses NEON v0-v31 and
   saves/restores q8-q15 in its prologue). */
static int abi_guard(void)
{
  register uint64_t s19 asm("x19") = 0x1919191919191919ULL;
  register uint64_t s20 asm("x20") = 0x2020202020202020ULL;
  register uint64_t s21 asm("x21") = 0x2121212121212121ULL;
  register uint64_t s22 asm("x22") = 0x2222222222222222ULL;
  register uint64_t s23 asm("x23") = 0x2323232323232323ULL;
  register uint64_t s24 asm("x24") = 0x2424242424242424ULL;
  register uint64_t s25 asm("x25") = 0x2525252525252525ULL;
  register uint64_t s26 asm("x26") = 0x2626262626262626ULL;
  register uint64_t s27 asm("x27") = 0x2727272727272727ULL;
  register uint64_t s28 asm("x28") = 0x2828282828282828ULL;
  register double f8  asm("d8")  =  8.5;
  register double f9  asm("d9")  =  9.5;
  register double f10 asm("d10") = 10.5;
  register double f11 asm("d11") = 11.5;
  register double f12 asm("d12") = 12.5;
  register double f13 asm("d13") = 13.5;
  register double f14 asm("d14") = 14.5;
  register double f15 asm("d15") = 15.5;
  uint64_t st[50];
  int i;
  for (i = 0; i < 50; i++) st[i] = xs();
  /* Two barriers: a single asm with 18 read-write ("+") operands exceeds gcc's
     30-operand inline-asm cap (each "+" counts as an in+out pair). Splitting GPR
     and FP pins into separate statements keeps each <=30 and is equivalent. */
  asm volatile("":"+r"(s19),"+r"(s20),"+r"(s21),"+r"(s22),"+r"(s23),
                 "+r"(s24),"+r"(s25),"+r"(s26),"+r"(s27),"+r"(s28));
  asm volatile("":"+w"(f8),"+w"(f9),"+w"(f10),"+w"(f11),
                 "+w"(f12),"+w"(f13),"+w"(f14),"+w"(f15));
  keccak_f2_asm(st, KRC);
  /* Two barriers: a single asm with 18 read-write ("+") operands exceeds gcc's
     30-operand inline-asm cap (each "+" counts as an in+out pair). Splitting GPR
     and FP pins into separate statements keeps each <=30 and is equivalent. */
  asm volatile("":"+r"(s19),"+r"(s20),"+r"(s21),"+r"(s22),"+r"(s23),
                 "+r"(s24),"+r"(s25),"+r"(s26),"+r"(s27),"+r"(s28));
  asm volatile("":"+w"(f8),"+w"(f9),"+w"(f10),"+w"(f11),
                 "+w"(f12),"+w"(f13),"+w"(f14),"+w"(f15));
  return s19==0x1919191919191919ULL && s20==0x2020202020202020ULL &&
         s21==0x2121212121212121ULL && s22==0x2222222222222222ULL &&
         s23==0x2323232323232323ULL && s24==0x2424242424242424ULL &&
         s25==0x2525252525252525ULL && s26==0x2626262626262626ULL &&
         s27==0x2727272727272727ULL && s28==0x2828282828282828ULL &&
         f8==8.5 && f9==9.5 && f10==10.5 && f11==11.5 &&
         f12==12.5 && f13==13.5 && f14==14.5 && f15==15.5;
}

/* ---- bench ---- */
static double ns_scale(void)
{
  static mach_timebase_info_data_t tb;
  if (!tb.denom) mach_timebase_info(&tb);
  return (double)tb.numer / (double)tb.denom;
}

static void bench_f2(void)
{
  uint64_t st[50];
  const long iters = 200000;
  long i;
  uint64_t t0, t1;
  double ns;
  for (i = 0; i < 50; i++) st[i] = xs();
  for (i = 0; i < 20000; i++) keccak_f2_asm(st, KRC);    /* warmup */
  t0 = mach_absolute_time();
  for (i = 0; i < iters; i++) keccak_f2_asm(st, KRC);
  t1 = mach_absolute_time();
  ns = (double)(t1 - t0) * ns_scale();
  printf("BENCH keccak_f2_asm: %.2f ns/op\n", ns / iters);
  if (st[0] == 0x5a5a5a5a5a5a5a5aULL) printf("(unlikely)\n"); /* keep state live */
}

int main(void)
{
  int fails = 0, abi;
  fails += oracle_selfcheck();
  fails += diff_f2();
  abi = abi_guard();
  printf("ABI callee-saved guard (x19-x28 + d8-d15): %s\n",
         abi ? "PASS" : "FAIL (clobbered)");
  if (!abi) fails++;
  bench_f2();
  printf("=> %s\n", fails ? "FAIL" : "ALL PASS");
  return fails != 0;
}
