/* Differential: SHA-1 on SHA-NI vs the portable block, same binary, by toggling the
   cached CPU feature word. Build (from racket/src/crypto):
     gcc -O2 -I. -o /tmp/test_sha1_x86 asm/tests/test_sha1_x86.c rktcrypto_legacy.c rktcrypto_x86.c rktcrypto_cpu.c */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include "rktcrypto_digest.h"
#include "rktcrypto_cpu.h"
static uint64_t st = 0x9e3779b97f4a7c15ULL;
static unsigned rnd(void) { st = st * 6364136223846793005ULL + 1; return (unsigned)(st >> 33); }
int main(void)
{
  unsigned hw = rktcrypto_cpu_features();
  static unsigned char msg[70000];
  unsigned char da[20], db[20];
  long bad = 0, tot = 0; int t;
  if (!(hw & RKTCRYPTO_CPU_X86_SHA)) { printf("no SHA-NI\n"); return 2; }
  for (t = 0; t < 3000; t++) {
    long len = (t < 200) ? t : (long)(rnd() % 70000), i, cut;
    rktcrypto_sha1_ctx_t c;
    for (i = 0; i < len; i++) msg[i] = (unsigned char)rnd();
    cut = (len > 0) ? (long)(rnd() % (unsigned)len) : 0;   /* split the update to exercise buffering */
    rktcrypto_cpu_override_features(hw, 1);
    rktcrypto_sha1_core_init(&c); rktcrypto_sha1_core_update(&c, msg, cut); rktcrypto_sha1_core_update(&c, msg + cut, len - cut); rktcrypto_sha1_core_final(&c, da, 20);
    rktcrypto_cpu_override_features(0, 1);
    rktcrypto_sha1_core_init(&c); rktcrypto_sha1_core_update(&c, msg, len); rktcrypto_sha1_core_final(&c, db, 20);
    tot++; if (memcmp(da, db, 20)) { bad++; if (bad <= 5) printf("MISMATCH len=%ld cut=%ld\n", len, cut); }
  }
  /* FIPS 180-4 "abc" KAT on the hardware path */
  { static const unsigned char kat[20] = {0xa9,0x99,0x3e,0x36,0x47,0x06,0x81,0x6a,0xba,0x3e,0x25,0x71,0x78,0x50,0xc2,0x6c,0x9c,0xd0,0xd8,0x9d};
    rktcrypto_sha1_ctx_t c; rktcrypto_cpu_override_features(hw, 1);
    rktcrypto_sha1_core_init(&c); rktcrypto_sha1_core_update(&c, (const unsigned char *)"abc", 3); rktcrypto_sha1_core_final(&c, da, 20);
    tot++; if (memcmp(da, kat, 20)) { bad++; printf("KAT abc mismatch\n"); } }
  rktcrypto_cpu_override_features(0, 0);
  printf("%ld/%ld mismatches\n%s\n", bad, tot, bad ? "FAIL" : "PASS");
  return bad ? 1 : 0;
}
