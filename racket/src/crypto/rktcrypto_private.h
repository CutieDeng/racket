#ifndef __RKTCRYPTO_PRIVATE_H__
#define __RKTCRYPTO_PRIVATE_H__

#include "rktcrypto.h"

#if defined(_WIN32) || defined(_WIN64)
# define RKTCRYPTO_OS_WINDOWS 1
#elif defined(__APPLE__)
# define RKTCRYPTO_OS_MACOS 1
#elif defined(__linux__)
# define RKTCRYPTO_OS_LINUX 1
#elif defined(__FreeBSD__) || defined(__OpenBSD__) || defined(__NetBSD__) || defined(__DragonFly__)
# define RKTCRYPTO_OS_BSD 1
#endif

#endif
