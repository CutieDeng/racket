/* ELF/Linux compatibility shim for the crypto differential harnesses.

   The harnesses (asm/tests/test_*.c) were written on Apple aarch64 and time
   with <mach/mach_time.h>.  On aarch64-linux that header does not exist, so
   this drop-in provides the two symbols the harnesses use, backed by
   clock_gettime(CLOCK_MONOTONIC).  With numer==denom==1 the harness computes
   tick_ns==1 and now_ns() returns nanoseconds directly -- identical meaning to
   the Apple timebase, so the BENCH/differential logic is unchanged.

   Reached only via -I asm/tests/elf-shim, i.e. it satisfies the harness'
   `#include <mach/mach_time.h>`.  Everything is guarded by __ASSEMBLER__ so that
   if this directory is ever put on the include path of a .S cpp pass it cannot
   leak C typedefs/inline functions into the assembler input. */
#ifndef RKTCRYPTO_ELF_SHIM_MACH_TIME_H
#define RKTCRYPTO_ELF_SHIM_MACH_TIME_H

#ifndef __ASSEMBLER__
#include <stdint.h>
#include <time.h>

typedef struct { uint32_t numer; uint32_t denom; } mach_timebase_info_data_t;

static inline int mach_timebase_info(mach_timebase_info_data_t *t)
{
  t->numer = 1;
  t->denom = 1;
  return 0;
}

static inline uint64_t mach_absolute_time(void)
{
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
}
#endif /* __ASSEMBLER__ */

#endif
