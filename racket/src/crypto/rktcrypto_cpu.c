/* Runtime CPU feature detection for the rktcrypto dispatch layer.

   x86: CPUID leaves 1 and 7. ARM: the OS feature interface --
   sysctlbyname on macOS, getauxval(AT_HWCAP) on Linux. The result is
   cached in a static word; the benign race on first use is harmless
   because every thread computes the same value. */

#include "rktcrypto_cpu.h"

static int rktcrypto_cpu_initialized = 0;
static unsigned rktcrypto_cpu_flags = 0;

#if defined(__x86_64__) || defined(__i386__)
# include <cpuid.h>
static unsigned rktcrypto_cpu_detect(void)
{
  unsigned f = 0, a, b, c, d;
  if (__get_cpuid(1, &a, &b, &c, &d)) {
    if (c & (1u << 25)) f |= RKTCRYPTO_CPU_X86_AESNI;   /* AES-NI      */
    if (c & (1u << 1))  f |= RKTCRYPTO_CPU_X86_PCLMUL;  /* PCLMULQDQ   */
  }
  if (__get_cpuid_count(7, 0, &a, &b, &c, &d)) {
    if (b & (1u << 29)) f |= RKTCRYPTO_CPU_X86_SHA;     /* SHA-NI      */
    if (b & (1u << 5))  f |= RKTCRYPTO_CPU_X86_AVX2;    /* AVX2        */
    if ((b & (1u << 16)) && (b & (1u << 17)) && (b & (1u << 30)) && (b & (1u << 31)))
      f |= RKTCRYPTO_CPU_X86_AVX512;                    /* AVX512 F+DQ+BW+VL */
    if (c & (1u << 9))  f |= RKTCRYPTO_CPU_X86_VAES;    /* VAES        */
    if (c & (1u << 10)) f |= RKTCRYPTO_CPU_X86_VPCLMULQDQ;
    if ((b & (1u << 8)) && (b & (1u << 19))) f |= RKTCRYPTO_CPU_X86_BMI2ADX;   /* BMI2 + ADX */
    if (b & (1u << 21)) f |= RKTCRYPTO_CPU_X86_IFMA;                          /* AVX512_IFMA */
  }
  /* The OS must have enabled the wider register state (XCR0 via xgetbv): bits 1,2 for
     YMM, 5,6,7 for opmask/ZMM. Without it the AVX families are reported absent. */
  {
    unsigned xcr0 = 0;
    if (__get_cpuid(1, &a, &b, &c, &d) && (c & (1u << 27))) {   /* OSXSAVE */
      unsigned lo, hi;
      __asm__ volatile("xgetbv" : "=a"(lo), "=d"(hi) : "c"(0));
      xcr0 = lo;
    }
    if ((xcr0 & 0x6) != 0x6)
      f &= ~(RKTCRYPTO_CPU_X86_AVX2 | RKTCRYPTO_CPU_X86_AVX512 | RKTCRYPTO_CPU_X86_VAES | RKTCRYPTO_CPU_X86_VPCLMULQDQ);
    if ((xcr0 & 0xe6) != 0xe6)
      f &= ~(RKTCRYPTO_CPU_X86_AVX512 | RKTCRYPTO_CPU_X86_IFMA);
  }
  return f;
}

#elif defined(__aarch64__) || defined(__arm64__)
# if defined(__APPLE__)
#  include <sys/sysctl.h>
static int sysctl_flag(const char *name)
{
  int v = 0;
  size_t sz = sizeof(v);
  if (sysctlbyname(name, &v, &sz, (void *)0, 0) != 0) return 0;
  return v;
}
static unsigned rktcrypto_cpu_detect(void)
{
  unsigned f = 0;
  if (sysctl_flag("hw.optional.arm.FEAT_AES"))    f |= RKTCRYPTO_CPU_ARM_AES;
  if (sysctl_flag("hw.optional.arm.FEAT_PMULL"))  f |= RKTCRYPTO_CPU_ARM_PMULL;
  if (sysctl_flag("hw.optional.arm.FEAT_SHA256")) f |= RKTCRYPTO_CPU_ARM_SHA2;
  if (sysctl_flag("hw.optional.arm.FEAT_SHA512")) f |= RKTCRYPTO_CPU_ARM_SHA512;
  if (sysctl_flag("hw.optional.arm.FEAT_SHA1"))   f |= RKTCRYPTO_CPU_ARM_SHA1;
  if (sysctl_flag("hw.optional.arm.FEAT_SHA3"))   f |= RKTCRYPTO_CPU_ARM_SHA3;
  return f;
}
# elif defined(__linux__)
#  include <sys/auxv.h>
#  include <asm/hwcap.h>
static unsigned rktcrypto_cpu_detect(void)
{
  unsigned f = 0;
  unsigned long hwcap = getauxval(AT_HWCAP);
  unsigned long hwcap2 = getauxval(AT_HWCAP2);
#  ifdef HWCAP_AES
  if (hwcap & HWCAP_AES)    f |= RKTCRYPTO_CPU_ARM_AES;
#  endif
#  ifdef HWCAP_PMULL
  if (hwcap & HWCAP_PMULL)  f |= RKTCRYPTO_CPU_ARM_PMULL;
#  endif
#  ifdef HWCAP_SHA2
  if (hwcap & HWCAP_SHA2)   f |= RKTCRYPTO_CPU_ARM_SHA2;
#  endif
#  ifdef HWCAP_SHA512
  if (hwcap & HWCAP_SHA512) f |= RKTCRYPTO_CPU_ARM_SHA512;
#  endif
#  ifdef HWCAP_SHA1
  if (hwcap & HWCAP_SHA1)   f |= RKTCRYPTO_CPU_ARM_SHA1;
#  endif
#  ifdef HWCAP2_SHA3
  if (hwcap2 & HWCAP2_SHA3) f |= RKTCRYPTO_CPU_ARM_SHA3;
#  else
  (void)hwcap2;
#  endif
  return f;
}
# else
static unsigned rktcrypto_cpu_detect(void) { return 0; }
# endif

#else
static unsigned rktcrypto_cpu_detect(void) { return 0; }
#endif

void rktcrypto_cpu_override_features(unsigned features, int enable)
{
  rktcrypto_cpu_flags = features;
  rktcrypto_cpu_initialized = enable ? 1 : 0;
}

unsigned rktcrypto_cpu_features(void)
{
  if (!rktcrypto_cpu_initialized) {
    rktcrypto_cpu_flags = rktcrypto_cpu_detect();
    rktcrypto_cpu_initialized = 1;
  }
  return rktcrypto_cpu_flags;
}
