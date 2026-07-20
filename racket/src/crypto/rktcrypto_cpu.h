#ifndef __RKTCRYPTO_CPU_H__
#define __RKTCRYPTO_CPU_H__

/* Runtime CPU feature detection. The flags are resolved once (on the
   first call) from cpuid on x86 or the OS feature interface on ARM, then
   cached, so the hot paths pay no per-call dispatch cost -- they read a
   cached word and branch to the best available implementation. This is
   what makes a single binary use hardware acceleration when the CPU has
   it and fall back to the portable code when it does not, rather than
   baking the decision in at compile time. */

enum {
  RKTCRYPTO_CPU_X86_AESNI  = 1u << 0,
  RKTCRYPTO_CPU_X86_PCLMUL = 1u << 1,
  RKTCRYPTO_CPU_X86_SHA    = 1u << 2,
  RKTCRYPTO_CPU_X86_AVX2   = 1u << 3,
  RKTCRYPTO_CPU_ARM_AES    = 1u << 8,
  RKTCRYPTO_CPU_ARM_PMULL  = 1u << 9,
  RKTCRYPTO_CPU_ARM_SHA2   = 1u << 10,
  RKTCRYPTO_CPU_ARM_SHA512 = 1u << 11
};

/* Returns the cached feature bitmask (detects on first call). */
unsigned rktcrypto_cpu_features(void);

/* Convenience predicate. */
static inline int rktcrypto_cpu_has(unsigned feature)
{
  return (rktcrypto_cpu_features() & feature) != 0;
}

#endif
