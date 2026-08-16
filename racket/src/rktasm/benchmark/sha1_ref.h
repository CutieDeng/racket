// sha1_ref.h - Reference SHA1 C implementation (portable, no SIMD)
#ifndef SHA1_REF_H
#define SHA1_REF_H

#include <stdint.h>
#include <stddef.h>

// Initialize SHA1 state to IV
void sha1_ref_init(uint32_t state[5]);

// Process a single 64-byte block
void sha1_ref_block(uint32_t state[5], const uint8_t block[64]);

// Finalize and output 20-byte digest
// data: remaining bytes (< 64), total_bits: total message bits
void sha1_ref_digest(uint32_t state[5], const uint8_t *data,
                     uint64_t total_bits, uint8_t digest[20]);

// Convenience: hash entire message at once
void sha1_ref(const uint8_t *msg, size_t len, uint8_t digest[20]);

#endif
