/* Differential + KAT + BENCH for the X25519 radix-2^64 path (rktcrypto_x25519_x86.S + the fe64
   ladder in rktcrypto_x25519.c) against the radix-2^51 ladder with the BMI2/ADX bit cleared,
   through the public rktcrypto_x25519. Build (from racket/src/crypto, on BMI2+ADX hardware):
     gcc -O2 -I. -o /tmp/test_x25519_x86 asm/tests/test_x25519_x86.c rktcrypto_*.S rktcrypto_x25519.c rktcrypto_cpu.c rktcrypto_x86.c */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <time.h>
#include "rktcrypto.h"
#include "rktcrypto_cpu.h"

static uint64_t st = 0x1f83d9abfb41bd6bULL;
static unsigned rnd(void) { st = st * 6364136223846793005ULL + 1442695040888963407ULL; return (unsigned)(st >> 33); }
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec * 1e-9; }
static void kernel(int on)
{
  if (on) rktcrypto_cpu_override_features(0, 0);
  else rktcrypto_cpu_override_features(rktcrypto_cpu_features() & ~RKTCRYPTO_CPU_X86_BMI2ADX, 1);
}
static void special_point(unsigned char u[32], int kind)
{
  int i;
  for (i = 0; i < 32; i++) u[i] = (unsigned char)rnd();
  switch (kind % 10) {
    case 0: memset(u, 0, 32); break;                                   /* 0 (low order) */
    case 1: memset(u, 0, 32); u[0] = 1; break;                         /* 1 (low order) */
    case 2: memset(u, 0xff, 32); u[0] = 0xec; u[31] = 0x7f; break;     /* p - 1 */
    case 3: memset(u, 0xff, 32); u[0] = 0xed; u[31] = 0x7f; break;     /* p (non-canonical 0) */
    case 4: memset(u, 0xff, 32); u[0] = 0xee; u[31] = 0x7f; break;     /* p + 1 (non-canonical 1) */
    case 5: memset(u, 0xff, 32); u[31] = 0xff; break;                  /* 2^256 - 1, top bit set */
    case 6: memset(u, 0, 32); u[0] = 9; break;                         /* base point */
    default: break;
  }
}

int main(void)
{
  long bad = 0, tot = 0; int t, i;
  if (!rktcrypto_cpu_has(RKTCRYPTO_CPU_X86_BMI2ADX)) { printf("no BMI2/ADX\n"); return 2; }
  for (t = 0; t < 3000; t++) {
    unsigned char k[32], u[32], a[32], b[32]; int ra, rb;
    for (i = 0; i < 32; i++) k[i] = (unsigned char)rnd();
    special_point(u, (int)(rnd() % 10));
    kernel(1); ra = rktcrypto_x25519(a, k, u);
    kernel(0); rb = rktcrypto_x25519(b, k, u); kernel(1);
    tot++; if (ra != rb || memcmp(a, b, 32)) { bad++; if (bad <= 5) printf("MISMATCH t=%d (%d/%d) u0=%02x u31=%02x\n", t, ra, rb, u[0], u[31]); }
  }
  /* RFC 7748 section 5.2 vector 1 */
  { static const unsigned char k[32] = {0xa5,0x46,0xe3,0x6b,0xf0,0x52,0x7c,0x9d,0x3b,0x16,0x15,0x4b,0x82,0x46,0x5e,0xdd,0x62,0x14,0x4c,0x0a,0xc1,0xfc,0x5a,0x18,0x50,0x6a,0x22,0x44,0xba,0x44,0x9a,0xc4};
    static const unsigned char u[32] = {0xe6,0xdb,0x68,0x67,0x58,0x30,0x30,0xdb,0x35,0x94,0xc1,0xa4,0x24,0xb1,0x5f,0x7c,0x72,0x66,0x24,0xec,0x26,0xb3,0x35,0x3b,0x10,0xa9,0x03,0xa6,0xd0,0xab,0x1c,0x4c};
    static const unsigned char want[32] = {0xc3,0xda,0x55,0x37,0x9d,0xe9,0xc6,0x90,0x8e,0x94,0xea,0x4d,0xf2,0x8d,0x08,0x4f,0x32,0xec,0xcf,0x03,0x49,0x1c,0x71,0xf7,0x54,0xb4,0x07,0x55,0x77,0xa2,0x85,0x52};
    unsigned char out[32]; int r = rktcrypto_x25519(out, k, u);
    tot++; if (r != 1 || memcmp(out, want, 32)) { bad++; printf("RFC 7748 vector mismatch\n"); } }
  { unsigned char k[32], u[32], out[32]; int r; double ba = 0, bb = 0;
    for (i = 0; i < 32; i++) { k[i] = (unsigned char)(i + 3); u[i] = (unsigned char)(i * 7 + 1); } u[31] &= 0x7f;
    for (r = 0; r < 5; r++) {
      double t0, t1, v;
      kernel(1); t0 = now(); for (i = 0; i < 4000; i++) rktcrypto_x25519(out, k, u); t1 = now();
      v = 4000.0 / (t1 - t0) / 1e3; if (v > ba) ba = v;
      kernel(0); t0 = now(); for (i = 0; i < 4000; i++) rktcrypto_x25519(out, k, u); t1 = now(); kernel(1);
      v = 4000.0 / (t1 - t0) / 1e3; if (v > bb) bb = v;
    }
    printf("BENCH x25519-fe64-x86: %.1f kops/s\nBENCH x25519-fe51-c: %.1f kops/s\n", ba, bb); }
  printf("%ld/%ld mismatches\n%s\n", bad, tot, bad ? "FAIL" : "PASS");
  return bad ? 1 : 0;
}
