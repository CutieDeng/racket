/* Differential + performance harness for the MD5/SHA-1 asmp kernels.
   Oracles are self-contained reference compressions written straight from
   RFC 1321 (MD5) and FIPS 180-4 (SHA-1) -- deliberately NOT including
   rktcrypto_legacy.c, which on aarch64 routes to the very asm under test.

   Kernels (aarch64/Apple, see rktcrypto_legacy.c:79-80 and 222-223):
     void md5_blocks_asm (uint32_t *st, const unsigned char *p, long nblk);
     void sha1_blocks_asm(uint32_t *st, const unsigned char *p, long nblk);
   st is updated in place across all nblk 64-byte blocks (MD5: 4 words,
   SHA-1: 5 words). nblk must be >= 1 (library caller guarantees this).

   Build (from racket/src/crypto):
     cc -O2 -o /tmp/test_md5_sha1 asm/tests/test_md5_sha1.c \
        rktcrypto_md5_asm.S rktcrypto_sha1_asm.S
   Exit status is nonzero iff any mismatch or ABI-guard failure. */

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <mach/mach_time.h>

extern void md5_blocks_asm(uint32_t *st, const unsigned char *p, long nblk);
extern void sha1_blocks_asm(uint32_t *st, const unsigned char *p, long nblk);

typedef void (*blocks_fn)(uint32_t *, const unsigned char *, long);

/* ---------------- xorshift PRNG (as in mont_mul_test.c) ---------------- */
static uint64_t st64 = 0x9e3779b97f4a7c15ULL;
static uint64_t xs(void) { st64 ^= st64 << 13; st64 ^= st64 >> 7; st64 ^= st64 << 17; return st64; }

#define ROTL32(x,n) (((x) << (n)) | ((x) >> (32 - (n))))

/* ---------------- MD5 reference compression (RFC 1321) ---------------- */

static const uint32_t MD5K[64] = {
  0xd76aa478u,0xe8c7b756u,0x242070dbu,0xc1bdceeeu,0xf57c0fafu,0x4787c62au,0xa8304613u,0xfd469501u,
  0x698098d8u,0x8b44f7afu,0xffff5bb1u,0x895cd7beu,0x6b901122u,0xfd987193u,0xa679438eu,0x49b40821u,
  0xf61e2562u,0xc040b340u,0x265e5a51u,0xe9b6c7aau,0xd62f105du,0x02441453u,0xd8a1e681u,0xe7d3fbc8u,
  0x21e1cde6u,0xc33707d6u,0xf4d50d87u,0x455a14edu,0xa9e3e905u,0xfcefa3f8u,0x676f02d9u,0x8d2a4c8au,
  0xfffa3942u,0x8771f681u,0x6d9d6122u,0xfde5380cu,0xa4beea44u,0x4bdecfa9u,0xf6bb4b60u,0xbebfbc70u,
  0x289b7ec6u,0xeaa127fau,0xd4ef3085u,0x04881d05u,0xd9d4d039u,0xe6db99e5u,0x1fa27cf8u,0xc4ac5665u,
  0xf4292244u,0x432aff97u,0xab9423a7u,0xfc93a039u,0x655b59c3u,0x8f0ccc92u,0xffeff47du,0x85845dd1u,
  0x6fa87e4fu,0xfe2ce6e0u,0xa3014314u,0x4e0811a1u,0xf7537e82u,0xbd3af235u,0x2ad7d2bbu,0xeb86d391u
};
static const int MD5S[64] = {
  7,12,17,22, 7,12,17,22, 7,12,17,22, 7,12,17,22,
  5, 9,14,20, 5, 9,14,20, 5, 9,14,20, 5, 9,14,20,
  4,11,16,23, 4,11,16,23, 4,11,16,23, 4,11,16,23,
  6,10,15,21, 6,10,15,21, 6,10,15,21, 6,10,15,21
};

static void md5_ref(uint32_t st[4], const unsigned char *p, long nblk)
{
  while (nblk-- > 0) {
    uint32_t m[16], a, b, c, d;
    int i;
    for (i = 0; i < 16; i++)
      m[i] = (uint32_t)p[4*i] | ((uint32_t)p[4*i+1] << 8)
           | ((uint32_t)p[4*i+2] << 16) | ((uint32_t)p[4*i+3] << 24);
    a = st[0]; b = st[1]; c = st[2]; d = st[3];
    for (i = 0; i < 64; i++) {
      uint32_t f, tmp;
      int g;
      if (i < 16)      { f = (b & c) | (~b & d);  g = i; }
      else if (i < 32) { f = (d & b) | (~d & c);  g = (5*i + 1) & 15; }
      else if (i < 48) { f = b ^ c ^ d;           g = (3*i + 5) & 15; }
      else             { f = c ^ (b | ~d);        g = (7*i) & 15; }
      tmp = d; d = c; c = b;
      b = b + ROTL32(a + f + MD5K[i] + m[g], MD5S[i]);
      a = tmp;
    }
    st[0] += a; st[1] += b; st[2] += c; st[3] += d;
    p += 64;
  }
}

/* ---------------- SHA-1 reference compression (FIPS 180-4) ---------------- */

static void sha1_ref(uint32_t st[5], const unsigned char *p, long nblk)
{
  while (nblk-- > 0) {
    uint32_t w[80], a, b, c, d, e;
    int i;
    for (i = 0; i < 16; i++)
      w[i] = ((uint32_t)p[4*i] << 24) | ((uint32_t)p[4*i+1] << 16)
           | ((uint32_t)p[4*i+2] << 8) | (uint32_t)p[4*i+3];
    for (i = 16; i < 80; i++)
      w[i] = ROTL32(w[i-3] ^ w[i-8] ^ w[i-14] ^ w[i-16], 1);
    a = st[0]; b = st[1]; c = st[2]; d = st[3]; e = st[4];
    for (i = 0; i < 80; i++) {
      uint32_t f, k, t;
      if (i < 20)      { f = (b & c) | (~b & d);            k = 0x5A827999u; }
      else if (i < 40) { f = b ^ c ^ d;                     k = 0x6ED9EBA1u; }
      else if (i < 60) { f = (b & c) | (b & d) | (c & d);   k = 0x8F1BBCDCu; }
      else             { f = b ^ c ^ d;                     k = 0xCA62C1D6u; }
      t = ROTL32(a, 5) + f + e + k + w[i];
      e = d; d = c; c = ROTL32(b, 30); b = a; a = t;
    }
    st[0] += a; st[1] += b; st[2] += c; st[3] += d; st[4] += e;
    p += 64;
  }
}

/* ---------------- ABI clobber guard (as in mont_mul_test.c) ---------------- */

static int abi_guard(blocks_fn fn, uint32_t *state, int nwords)
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
  static unsigned char data[3*64];
  (void)nwords;
  memset(data, 0xa5, sizeof data);
  asm volatile("":"+r"(s19),"+r"(s20),"+r"(s21),"+r"(s22),"+r"(s23),"+r"(s24),"+r"(s25),"+r"(s26),"+r"(s27),"+r"(s28));
  fn(state, data, 3);
  asm volatile("":"+r"(s19),"+r"(s20),"+r"(s21),"+r"(s22),"+r"(s23),"+r"(s24),"+r"(s25),"+r"(s26),"+r"(s27),"+r"(s28));
  return s19==0x1919191919191919ULL && s20==0x2020202020202020ULL && s21==0x2121212121212121ULL &&
         s22==0x2222222222222222ULL && s23==0x2323232323232323ULL && s24==0x2424242424242424ULL &&
         s25==0x2525252525252525ULL && s26==0x2626262626262626ULL && s27==0x2727272727272727ULL &&
         s28==0x2828282828282828ULL;
}

/* ---------------- differential testing ---------------- */

#define NRAND 200000
#define MAXBLK 8

typedef void (*ref_fn)(uint32_t *, const unsigned char *, long);

static int diff(const char *name, blocks_fn asm_fn, ref_fn ref, int nwords,
                const uint32_t *iv)
{
  static unsigned char buf[MAXBLK*64 + 8];
  int fails = 0, t;
  size_t i;
  for (t = 0; t < NRAND; t++) {
    uint32_t s1[5], s2[5];
    long nblk = 1 + (long)(xs() % MAXBLK);
    unsigned char *p = buf + (xs() & 7);   /* vary data alignment 0..7 */
    int w;
    for (w = 0; w < nwords; w++) s1[w] = (uint32_t)xs();
    if (t == 0) {                          /* edge: standard IV, all-zero data */
      nblk = MAXBLK; p = buf;
      memcpy(s1, iv, 4*(size_t)nwords);
      memset(p, 0x00, MAXBLK*64);
    } else if (t == 1) {                   /* edge: standard IV, all-FF data */
      nblk = MAXBLK; p = buf;
      memcpy(s1, iv, 4*(size_t)nwords);
      memset(p, 0xff, MAXBLK*64);
    } else {
      for (i = 0; i < (size_t)nblk*64; i++) p[i] = (unsigned char)xs();
    }
    memcpy(s2, s1, 4*(size_t)nwords);
    ref(s1, p, nblk);
    asm_fn(s2, p, nblk);
    if (memcmp(s1, s2, 4*(size_t)nwords) != 0) {
      if (++fails <= 3) printf("  %s MISMATCH t=%d nblk=%ld\n", name, t, nblk);
    }
  }
  printf("%s vs C ref: %d/%d mismatches\n", name, fails, NRAND);
  return fails;
}

/* ---------------- standard "abc" vectors (single padded block) ---------------- */

static int vector_abc(void)
{
  /* Both vectors are the full hash of "abc": 3 message bytes + 0x80 + zeros +
     64-bit bit length 24 in the trailing 8 bytes (LE for MD5, BE for SHA-1).
     Feed the padded block to ref and asm, compare states, then serialize the
     asm state per algorithm convention and check against the known digest. */
  static const unsigned char md5_abc[16] = {
    0x90,0x01,0x50,0x98,0x3c,0xd2,0x4f,0xb0,0xd6,0x96,0x3f,0x7d,0x28,0xe1,0x7f,0x72 };
  static const unsigned char sha1_abc[20] = {
    0xa9,0x99,0x3e,0x36,0x47,0x06,0x81,0x6a,0xba,0x3e,0x25,0x71,
    0x78,0x50,0xc2,0x6c,0x9c,0xd0,0xd8,0x9d };
  unsigned char blk[64], out[20];
  uint32_t s1[5], s2[5];
  int i, fails = 0;

  /* MD5("abc") */
  memset(blk, 0, 64); blk[0]='a'; blk[1]='b'; blk[2]='c'; blk[3]=0x80;
  blk[56] = 24;  /* bit length, little-endian */
  s1[0]=s2[0]=0x67452301u; s1[1]=s2[1]=0xefcdab89u;
  s1[2]=s2[2]=0x98badcfeu; s1[3]=s2[3]=0x10325476u;
  md5_ref(s1, blk, 1);
  md5_blocks_asm(s2, blk, 1);
  if (memcmp(s1, s2, 16) != 0) { printf("  MD5(\"abc\") asm != ref\n"); fails++; }
  for (i = 0; i < 4; i++) {
    out[4*i+0]=(unsigned char)(s2[i]); out[4*i+1]=(unsigned char)(s2[i]>>8);
    out[4*i+2]=(unsigned char)(s2[i]>>16); out[4*i+3]=(unsigned char)(s2[i]>>24);
  }
  if (memcmp(out, md5_abc, 16) != 0) { printf("  MD5(\"abc\") digest wrong\n"); fails++; }
  printf("vector MD5(\"abc\")  = 900150983cd24fb0d6963f7d28e17f72: %s\n",
         fails ? "FAIL" : "PASS");

  /* SHA1("abc") */
  {
    int f0 = fails;
    memset(blk, 0, 64); blk[0]='a'; blk[1]='b'; blk[2]='c'; blk[3]=0x80;
    blk[63] = 24;  /* bit length, big-endian */
    s1[0]=s2[0]=0x67452301u; s1[1]=s2[1]=0xefcdab89u; s1[2]=s2[2]=0x98badcfeu;
    s1[3]=s2[3]=0x10325476u; s1[4]=s2[4]=0xc3d2e1f0u;
    sha1_ref(s1, blk, 1);
    sha1_blocks_asm(s2, blk, 1);
    if (memcmp(s1, s2, 20) != 0) { printf("  SHA1(\"abc\") asm != ref\n"); fails++; }
    for (i = 0; i < 5; i++) {
      out[4*i+0]=(unsigned char)(s2[i]>>24); out[4*i+1]=(unsigned char)(s2[i]>>16);
      out[4*i+2]=(unsigned char)(s2[i]>>8);  out[4*i+3]=(unsigned char)(s2[i]);
    }
    if (memcmp(out, sha1_abc, 20) != 0) { printf("  SHA1(\"abc\") digest wrong\n"); fails++; }
    printf("vector SHA1(\"abc\") = a9993e364706816aba3e25717850c26c9cd0d89d: %s\n",
           (fails - f0) ? "FAIL" : "PASS");
  }
  return fails;
}

/* ---------------- performance ---------------- */

#define BENCH_CALL_BLOCKS 4
#define BENCH_ITERS 300000   /* x4 blocks = 1.2M blocks measured */
#define WARMUP_ITERS 30000

static void bench(const char *name, blocks_fn fn, const uint32_t *iv, int nwords)
{
  static unsigned char buf[BENCH_CALL_BLOCKS*64];
  uint32_t st[5];
  mach_timebase_info_data_t tb;
  uint64_t t0, t1;
  double ns, nsb;
  long i;
  size_t j;
  mach_timebase_info(&tb);
  for (j = 0; j < sizeof buf; j++) buf[j] = (unsigned char)xs();
  memcpy(st, iv, 4*(size_t)nwords);
  for (i = 0; i < WARMUP_ITERS; i++) fn(st, buf, BENCH_CALL_BLOCKS);
  t0 = mach_absolute_time();
  for (i = 0; i < BENCH_ITERS; i++) fn(st, buf, BENCH_CALL_BLOCKS);
  t1 = mach_absolute_time();
  ns = (double)(t1 - t0) * (double)tb.numer / (double)tb.denom;
  nsb = ns / ((double)BENCH_ITERS * BENCH_CALL_BLOCKS);
  printf("BENCH %s: %.2f ns/block  (%.1f MB/s)\n", name, nsb, 64.0/nsb*1000.0);
  /* consume state so the loop cannot be considered dead */
  if (st[0] == 0xdeadbeefu && st[1] == 0xdeadbeefu) printf("(unlikely)\n");
}

/* ---------------- main ---------------- */

int main(void)
{
  static const uint32_t md5_iv[4]  = {0x67452301u,0xefcdab89u,0x98badcfeu,0x10325476u};
  static const uint32_t sha1_iv[5] = {0x67452301u,0xefcdab89u,0x98badcfeu,0x10325476u,0xc3d2e1f0u};
  uint32_t gs[5];
  int fails = 0, abi_md5, abi_sha1;

  fails += diff("md5_blocks_asm",  md5_blocks_asm,  md5_ref,  4, md5_iv);
  fails += diff("sha1_blocks_asm", sha1_blocks_asm, sha1_ref, 5, sha1_iv);
  fails += vector_abc();

  memcpy(gs, md5_iv, sizeof md5_iv);
  abi_md5 = abi_guard(md5_blocks_asm, gs, 4);
  memcpy(gs, sha1_iv, sizeof sha1_iv);
  abi_sha1 = abi_guard(sha1_blocks_asm, gs, 5);
  printf("ABI callee-saved guard md5_blocks_asm : %s\n", abi_md5 ? "PASS" : "FAIL (clobbered x19-x28)");
  printf("ABI callee-saved guard sha1_blocks_asm: %s\n", abi_sha1 ? "PASS" : "FAIL (clobbered x19-x28)");
  if (!abi_md5) fails++;
  if (!abi_sha1) fails++;

  bench("md5_blocks_asm",  md5_blocks_asm,  md5_iv,  4);
  bench("sha1_blocks_asm", sha1_blocks_asm, sha1_iv, 5);

  printf("=> %s\n", fails ? "FAIL" : "ALL PASS");
  return fails != 0;
}
