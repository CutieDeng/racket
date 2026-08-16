/* System entropy for rktcrypto.

   Preferred sources, in order:
     - macOS / BSD: getentropy(), looping over its 256-byte limit
     - Linux: getrandom() via syscall, with ENOSYS fallback
     - Windows: BCryptGenRandom with the system-preferred RNG
     - fallback: read /dev/urandom through a cached descriptor

   All paths are safe to call concurrently from multiple threads. */

#include "rktcrypto_private.h"

#ifdef RKTCRYPTO_OS_WINDOWS

# include <windows.h>
# include <bcrypt.h>

int rktcrypto_system_random(unsigned char *buf, intptr_t start, intptr_t end)
{
  intptr_t len = end - start;
  if (len < 0) return 0;
  if (len == 0) return 1;
  return BCRYPT_SUCCESS(BCryptGenRandom(NULL, buf + start, (ULONG)len,
                                        BCRYPT_USE_SYSTEM_PREFERRED_RNG));
}

#else /* !RKTCRYPTO_OS_WINDOWS */

# include <errno.h>
# include <fcntl.h>
# include <unistd.h>

# if defined(RKTCRYPTO_OS_MACOS) || defined(RKTCRYPTO_OS_BSD)
#  include <sys/random.h>
#  define RKTCRYPTO_HAVE_GETENTROPY 1
# elif defined(RKTCRYPTO_OS_LINUX)
#  include <sys/syscall.h>
#  if defined(SYS_getrandom)
#   define RKTCRYPTO_HAVE_GETRANDOM_SYSCALL 1
#  endif
# endif

/* The /dev/urandom descriptor is cached across calls. Racing opens
   can leak at most one descriptor per thread once, and a leaked
   descriptor is still a valid urandom handle; we accept that rather
   than requiring a lock here. */
static int urandom_fd = -1;

static int read_urandom(unsigned char *p, intptr_t len)
{
  int fd = urandom_fd;

  if (fd < 0) {
    do {
      fd = open("/dev/urandom", O_RDONLY | O_CLOEXEC);
    } while ((fd < 0) && (errno == EINTR));
    if (fd < 0) return 0;
    urandom_fd = fd;
  }

  while (len > 0) {
    ssize_t got = read(fd, p, (size_t)len);
    if (got < 0) {
      if (errno == EINTR) continue;
      return 0;
    }
    if (got == 0) return 0;
    p += got;
    len -= got;
  }
  return 1;
}

int rktcrypto_system_random(unsigned char *buf, intptr_t start, intptr_t end)
{
  unsigned char *p = buf + start;
  intptr_t len = end - start;

  if (len < 0) return 0;
  if (len == 0) return 1;

# if defined(RKTCRYPTO_HAVE_GETENTROPY)
  {
    intptr_t remain = len;
    unsigned char *q = p;
    while (remain > 0) {
      size_t amt = (remain > 256) ? 256 : (size_t)remain;
      if (getentropy(q, amt) != 0) {
        if (errno == EINTR) continue;
        return read_urandom(p, len);
      }
      q += amt;
      remain -= amt;
    }
    return 1;
  }
# elif defined(RKTCRYPTO_HAVE_GETRANDOM_SYSCALL)
  {
    intptr_t remain = len;
    unsigned char *q = p;
    while (remain > 0) {
      long got = syscall(SYS_getrandom, q, (size_t)remain, 0);
      if (got < 0) {
        if (errno == EINTR) continue;
        /* ENOSYS on pre-3.17 kernels, or any other failure */
        return read_urandom(p, len);
      }
      q += got;
      remain -= got;
    }
    return 1;
  }
# else
  return read_urandom(p, len);
# endif
}

#endif /* !RKTCRYPTO_OS_WINDOWS */
