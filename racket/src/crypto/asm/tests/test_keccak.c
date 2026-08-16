/* Differential + ABI-clobber + bench harness for the fused Keccak absorb
   kernels (rktcrypto_keccak_asm.S). Oracle = a from-scratch FIPS 202
   Keccak-f[1600] written here (no dependency on the library's intrinsics
   implementation). Build (from racket/src/crypto):
     cc -O2 -o /tmp/test_keccak asm/tests/test_keccak.c rktcrypto_keccak_asm.S
     /tmp/test_keccak

   Kernel semantics (per rktcrypto_sha3.c:206-220 and gen_keccak_absorb.py):
     void keccak_absorb<W>_asm(uint64_t st[25], const unsigned char *data,
                               intptr_t nblk, const uint64_t rc[24]);
   For each of nblk (>=1) blocks: XOR W little-endian 64-bit words from data
   into st[0..W-1], then run the full 24-round Keccak-f[1600] using rc.
   All nblk blocks are processed (including the last one); the state is
   written back to st. No return value. data may be unaligned. */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <mach/mach_time.h>

void keccak_absorb21_asm(uint64_t*, const unsigned char*, intptr_t, const uint64_t*);
void keccak_absorb18_asm(uint64_t*, const unsigned char*, intptr_t, const uint64_t*);
void keccak_absorb17_asm(uint64_t*, const unsigned char*, intptr_t, const uint64_t*);
void keccak_absorb13_asm(uint64_t*, const unsigned char*, intptr_t, const uint64_t*);
void keccak_absorb9_asm (uint64_t*, const unsigned char*, intptr_t, const uint64_t*);

typedef void (*absorb_fn)(uint64_t*, const unsigned char*, intptr_t, const uint64_t*);

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

/* reference absorb loop: per block XOR `words` LE lanes then permute */
static void ref_absorb(uint64_t st[25], const unsigned char *data,
                       intptr_t nblk, int words)
{
  intptr_t b; int w;
  for (b = 0; b < nblk; b++) {
    for (w = 0; w < words; w++) {
      const unsigned char *p = data + 8*w;
      st[w] ^= (uint64_t)p[0]        | ((uint64_t)p[1] << 8)
             | ((uint64_t)p[2] << 16) | ((uint64_t)p[3] << 24)
             | ((uint64_t)p[4] << 32) | ((uint64_t)p[5] << 40)
             | ((uint64_t)p[6] << 48) | ((uint64_t)p[7] << 56);
    }
    keccak_f_ref(st);
    data += 8*words;
  }
}

/* sanity for the oracle itself: Keccak-f[1600] of the zero state
   (KeccakF-1600-IntermediateValues.txt) and SHA3-256("") via ref_absorb. */
static int oracle_selfcheck(void)
{
  uint64_t st[25];
  unsigned char blk[136], dig[32];
  static const unsigned char sha3_256_empty[32] = {
    0xa7,0xff,0xc6,0xf8,0xbf,0x1e,0xd7,0x66,0x51,0xc1,0x47,0x56,0xa0,0x61,0xd6,0x62,
    0xf5,0x80,0xff,0x4d,0xe4,0x3b,0x49,0xfa,0x82,0xd8,0x0a,0x4b,0x80,0xf8,0x43,0x4a };
  int i;
  memset(st, 0, sizeof st);
  keccak_f_ref(st);
  if (st[0] != 0xF1258F7940E1DDE7ULL || st[1] != 0x84D5CCF933C0478AULL ||
      st[2] != 0xD598261EA65AA9EEULL || st[3] != 0xBD1547306F80494DULL) {
    printf("oracle self-check FAILED (Keccak-f zero-state vector)\n");
    return 1;
  }
  /* SHA3-256(""): one 136-byte block = pad only (0x06 ... 0x80) */
  memset(st, 0, sizeof st);
  memset(blk, 0, sizeof blk);
  blk[0] = 0x06; blk[135] = 0x80;
  ref_absorb(st, blk, 1, 17);
  memcpy(dig, st, 32);
  if (memcmp(dig, sha3_256_empty, 32) != 0) {
    printf("oracle self-check FAILED (SHA3-256 empty digest)\n");
    return 1;
  }
  for (i = 0; i < 24; i++) if (!KRC[i]) return 1; /* keep i used */
  return 0;
}

/* ---- rng ---- */
static uint64_t rst = 0x9e3779b97f4a7c15ULL;
static uint64_t xs(void) { rst ^= rst << 13; rst ^= rst >> 7; rst ^= rst << 17; return rst; }

/* ---- differential ---- */
#define MAXBLK 8
#define MAXWORDS 21

static int diff_absorb(absorb_fn fn, int words, const char *name)
{
  int fails = 0;
  long t;
  static unsigned char buf[MAXBLK*MAXWORDS*8 + 8];
  for (t = 0; t < 200000; t++) {
    uint64_t s_ref[25], s_asm[25];
    intptr_t nblk = 1 + (intptr_t)(xs() % MAXBLK);
    size_t off = (size_t)(xs() % 8);          /* exercise unaligned data */
    unsigned char *data = buf + off;
    size_t bytes = (size_t)nblk * words * 8;
    size_t i;
    for (i = 0; i < 25; i++) s_ref[i] = xs();
    for (i = 0; i < bytes; i++) data[i] = (unsigned char)xs();
    if (t == 0) { nblk = 1; bytes = (size_t)words*8; data = buf;
                  memset(s_ref, 0, sizeof s_ref); memset(data, 0, bytes); }
    if (t == 1) { nblk = MAXBLK; bytes = (size_t)nblk*words*8; data = buf;
                  memset(s_ref, 0, sizeof s_ref); memset(data, 0xFF, bytes); }
    if (t == 2) { memset(s_ref, 0xFF, sizeof s_ref); memset(data, 0xFF, bytes); }
    memcpy(s_asm, s_ref, sizeof s_ref);
    ref_absorb(s_ref, data, nblk, words);
    fn(s_asm, data, nblk, KRC);
    if (memcmp(s_ref, s_asm, 200) != 0) {
      if (++fails <= 3) printf("  %s MISMATCH t=%ld nblk=%ld off=%zu\n",
                               name, t, (long)nblk, off);
    }
  }
  printf("%s vs ref: %d/200000 mismatches\n", name, fails);
  return fails;
}

/* ---- ABI clobber guard ----
   Sentinels in all callee-saved GPRs x19-x28 AND in d8-d15 (the low 64 bits
   of v8-v15, which are callee-saved under AAPCS64; these kernels use NEON
   v0-v31 and save/restore q8-q15 in their prologue). One kernel call per
   invocation: with more calls the compiler steals x19 for a loop-invariant
   and spills that sentinel, making its check vacuous (verified by otool). */
static int abi_guard(absorb_fn fn)
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
  uint64_t st[25];
  unsigned char data[21*8];
  size_t i;
  for (i = 0; i < 25; i++) st[i] = xs();
  for (i = 0; i < sizeof data; i++) data[i] = (unsigned char)xs();
  /* Two barriers: a single asm with 18 read-write ("+") operands exceeds gcc's
     30-operand inline-asm cap (each "+" counts as an in+out pair). Splitting GPR
     and FP pins into separate statements keeps each <=30 and is equivalent. */
  asm volatile("":"+r"(s19),"+r"(s20),"+r"(s21),"+r"(s22),"+r"(s23),
                 "+r"(s24),"+r"(s25),"+r"(s26),"+r"(s27),"+r"(s28));
  asm volatile("":"+w"(f8),"+w"(f9),"+w"(f10),"+w"(f11),
                 "+w"(f12),"+w"(f13),"+w"(f14),"+w"(f15));
  fn(st, data, 2, KRC);
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

static void bench_absorb(absorb_fn fn, int words, const char *name)
{
  static unsigned char buf[4*MAXWORDS*8];
  uint64_t st[25];
  const long iters = 200000, nblk = 4;
  long i;
  uint64_t t0, t1;
  double ns;
  for (i = 0; i < 25; i++) st[i] = xs();
  for (i = 0; i < (long)sizeof buf; i++) buf[i] = (unsigned char)xs();
  for (i = 0; i < 20000; i++) fn(st, buf, nblk, KRC);    /* warmup */
  t0 = mach_absolute_time();
  for (i = 0; i < iters; i++) fn(st, buf, nblk, KRC);
  t1 = mach_absolute_time();
  ns = (double)(t1 - t0) * ns_scale();
  printf("BENCH %s: %.2f ns/op  %.2f ns/block\n",
         name, ns / iters, ns / ((double)iters * nblk));
  if (st[0] == 0x5a5a5a5a5a5a5a5aULL) printf("(unlikely)\n"); /* keep state live */
}

int main(void)
{
  int fails = 0, abi;
  fails += oracle_selfcheck();
  fails += diff_absorb(keccak_absorb21_asm, 21, "keccak_absorb21_asm");
  fails += diff_absorb(keccak_absorb18_asm, 18, "keccak_absorb18_asm");
  fails += diff_absorb(keccak_absorb17_asm, 17, "keccak_absorb17_asm");
  fails += diff_absorb(keccak_absorb13_asm, 13, "keccak_absorb13_asm");
  fails += diff_absorb(keccak_absorb9_asm,   9, "keccak_absorb9_asm");
  abi = abi_guard(keccak_absorb21_asm) & abi_guard(keccak_absorb18_asm)
      & abi_guard(keccak_absorb17_asm) & abi_guard(keccak_absorb13_asm)
      & abi_guard(keccak_absorb9_asm);
  printf("ABI callee-saved guard (x19-x28 + d8-d15, all 5 kernels): %s\n",
         abi ? "PASS" : "FAIL (clobbered)");
  if (!abi) fails++;
  bench_absorb(keccak_absorb21_asm, 21, "keccak_absorb21_asm");
  bench_absorb(keccak_absorb18_asm, 18, "keccak_absorb18_asm");
  bench_absorb(keccak_absorb17_asm, 17, "keccak_absorb17_asm");
  bench_absorb(keccak_absorb13_asm, 13, "keccak_absorb13_asm");
  bench_absorb(keccak_absorb9_asm,   9, "keccak_absorb9_asm");
  printf("=> %s\n", fails ? "FAIL" : "ALL PASS");
  return fails != 0;
}
