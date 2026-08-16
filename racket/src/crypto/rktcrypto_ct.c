/* Constant-time utilities for rktcrypto.

   These must live in C: at the Racket/Chez level there is no way to
   keep a comparison from short-circuiting under optimization, and no
   way to keep a clearing store from being elided as dead. */

#define __STDC_WANT_LIB_EXT1__ 1

#include "rktcrypto_private.h"

#ifdef RKTCRYPTO_OS_WINDOWS
# include <windows.h>
#else
# include <string.h>
#endif

#if defined(RKTCRYPTO_OS_MACOS) && !defined(__STDC_LIB_EXT1__)
/* macOS provides memset_s but does not advertise __STDC_LIB_EXT1__
   unless asked; the prototype comes from <string.h> with
   __STDC_WANT_LIB_EXT1__ defined, which we did above. If the SDK
   still does not declare it, fall back to the volatile loop. */
#endif

int rktcrypto_ct_bytes_equal(const unsigned char *a, intptr_t a_start,
                             const unsigned char *b, intptr_t b_start,
                             intptr_t len)
{
  const unsigned char *pa = a + a_start;
  const unsigned char *pb = b + b_start;
  unsigned char acc = 0;
  intptr_t i;

  if (len < 0) return 0;

  for (i = 0; i < len; i++)
    acc |= (unsigned char)(pa[i] ^ pb[i]);

  /* acc == 0  =>  1; acc != 0  =>  0, without a branch */
  return (int)(1 & (((unsigned int)acc - 1) >> 8));
}

void rktcrypto_secure_clear(unsigned char *buf, intptr_t start, intptr_t end)
{
  intptr_t len = end - start;

  if (len <= 0) return;

#if defined(RKTCRYPTO_OS_WINDOWS)
  SecureZeroMemory(buf + start, (SIZE_T)len);
#elif defined(RKTCRYPTO_OS_MACOS)
  memset_s(buf + start, (size_t)len, 0, (size_t)len);
#elif defined(__GLIBC__) && ((__GLIBC__ > 2) || (__GLIBC_MINOR__ >= 25))
  explicit_bzero(buf + start, (size_t)len);
#elif defined(RKTCRYPTO_OS_BSD)
  explicit_bzero(buf + start, (size_t)len);
#else
  {
    volatile unsigned char *p = (volatile unsigned char *)(buf + start);
    intptr_t i;
    for (i = 0; i < len; i++)
      p[i] = 0;
  }
#endif
}
