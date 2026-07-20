#ifndef __RKTCRYPTO_X86_H__
#define __RKTCRYPTO_X86_H__

/* x86-64 hardware paths, selected at runtime via rktcrypto_cpu. Declared
   for the dispatchers in the AES, GCM, and SHA-256 cores. Only meaningful
   on x86; guarded at every call site by a CPUID feature check. */

#include <stdint.h>

#if defined(__x86_64__) || defined(__i386__)

void rktcrypto_aes256_block_aesni(const unsigned char rk[240],
                                  const unsigned char in[16], unsigned char out[16]);

void rktcrypto_ghash_x86(const uint64_t h[2],
                         const unsigned char *aad, intptr_t aad_len,
                         const unsigned char *ct, intptr_t ct_len,
                         unsigned char s[16]);

void rktcrypto_sha256_block_shani(uint32_t state[8], const unsigned char *data);

#endif

#endif
