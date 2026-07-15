/* Fast userspace CSPRNG for the rktcrypto subsystem.

   A per-OS-thread ChaCha20 generator in the fast-key-erasure style of
   arc4random: the operating system seeds it once, and each request
   re-keys from a fresh keystream block so that a later state
   compromise cannot recover earlier output (forward secrecy). A
   getpid() check reseeds after fork(), so a parent and child never
   share generator state.

   Racket's green threads within a place run on one OS thread and enter
   this code under an atomic FFI call, so the thread-local state needs
   no additional locking. */

#include "rktcrypto.h"
#include "rktcrypto_cipher.h"
#include "rktcrypto_private.h"
#include <string.h>

#if defined(_MSC_VER)
# define RKT_THREAD_LOCAL __declspec(thread)
#else
# define RKT_THREAD_LOCAL __thread
#endif

#ifndef RKTCRYPTO_OS_WINDOWS
# include <unistd.h>
# include <sys/types.h>
#endif

typedef struct {
  unsigned char key[32];
  int seeded;
#ifndef RKTCRYPTO_OS_WINDOWS
  pid_t pid;
#endif
} drbg_state_t;

static RKT_THREAD_LOCAL drbg_state_t g_drbg;

static const unsigned char ZERO_NONCE[12] = {0};

/* Returns 1 if the generator is seeded and current for this process. */
static int ensure_seeded(void)
{
#ifndef RKTCRYPTO_OS_WINDOWS
  pid_t cur = getpid();
  if (!g_drbg.seeded || g_drbg.pid != cur) {
    if (!rktcrypto_system_random(g_drbg.key, 0, 32)) return 0;
    g_drbg.pid = cur;
    g_drbg.seeded = 1;
  }
#else
  if (!g_drbg.seeded) {
    if (!rktcrypto_system_random(g_drbg.key, 0, 32)) return 0;
    g_drbg.seeded = 1;
  }
#endif
  return 1;
}

int rktcrypto_random_bytes(unsigned char *out, intptr_t start, intptr_t end)
{
  intptr_t n = end - start;
  unsigned char rekey[64];

  if (n < 0) return 0;
  if (!ensure_seeded()) return 0;

  /* Output uses keystream blocks 1.. (counter starts at 1); block 0 is
     reserved to derive the next key. */
  if (n > 0) {
    memset(out + start, 0, (size_t)n);
    rktcrypto_chacha20_xor(g_drbg.key, ZERO_NONCE, 1, out + start, out + start, n);
  }

  /* Re-key from block 0 for forward secrecy, then erase the material. */
  memset(rekey, 0, sizeof(rekey));
  rktcrypto_chacha20_xor(g_drbg.key, ZERO_NONCE, 0, rekey, rekey, 32);
  memcpy(g_drbg.key, rekey, 32);
  rktcrypto_secure_clear(rekey, 0, 32);

  return 1;
}
