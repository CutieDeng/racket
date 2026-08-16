// sha1_ref.c - Reference SHA1 C implementation (portable, no SIMD)
// Based on RFC 3174

#include "sha1_ref.h"
#include <string.h>

// Rotate left
#define ROTL(x, n) (((x) << (n)) | ((x) >> (32 - (n))))

// SHA1 round functions
#define F0(b, c, d) (((b) & (c)) | ((~(b)) & (d)))
#define F1(b, c, d) ((b) ^ (c) ^ (d))
#define F2(b, c, d) (((b) & (c)) | ((b) & (d)) | ((c) & (d)))
#define F3(b, c, d) ((b) ^ (c) ^ (d))

// SHA1 constants
static const uint32_t K[4] = {
    0x5A827999, 0x6ED9EBA1, 0x8F1BBCDC, 0xCA62C1D6
};

// SHA1 initial values
static const uint32_t IV[5] = {
    0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0
};

void sha1_ref_init(uint32_t state[5]) {
    state[0] = IV[0];
    state[1] = IV[1];
    state[2] = IV[2];
    state[3] = IV[3];
    state[4] = IV[4];
}

void sha1_ref_block(uint32_t state[5], const uint8_t block[64]) {
    uint32_t W[80];
    uint32_t a, b, c, d, e;

    // Load message block as big-endian words
    for (int i = 0; i < 16; i++) {
        W[i] = ((uint32_t)block[i*4] << 24) |
               ((uint32_t)block[i*4+1] << 16) |
               ((uint32_t)block[i*4+2] << 8) |
               ((uint32_t)block[i*4+3]);
    }

    // Extend to 80 words
    for (int i = 16; i < 80; i++) {
        W[i] = ROTL(W[i-3] ^ W[i-8] ^ W[i-14] ^ W[i-16], 1);
    }

    // Initialize working variables
    a = state[0];
    b = state[1];
    c = state[2];
    d = state[3];
    e = state[4];

    // 80 rounds
    for (int i = 0; i < 20; i++) {
        uint32_t temp = ROTL(a, 5) + F0(b, c, d) + e + K[0] + W[i];
        e = d; d = c; c = ROTL(b, 30); b = a; a = temp;
    }
    for (int i = 20; i < 40; i++) {
        uint32_t temp = ROTL(a, 5) + F1(b, c, d) + e + K[1] + W[i];
        e = d; d = c; c = ROTL(b, 30); b = a; a = temp;
    }
    for (int i = 40; i < 60; i++) {
        uint32_t temp = ROTL(a, 5) + F2(b, c, d) + e + K[2] + W[i];
        e = d; d = c; c = ROTL(b, 30); b = a; a = temp;
    }
    for (int i = 60; i < 80; i++) {
        uint32_t temp = ROTL(a, 5) + F3(b, c, d) + e + K[3] + W[i];
        e = d; d = c; c = ROTL(b, 30); b = a; a = temp;
    }

    // Add to state
    state[0] += a;
    state[1] += b;
    state[2] += c;
    state[3] += d;
    state[4] += e;
}

void sha1_ref_digest(uint32_t state[5], const uint8_t *data,
                     uint64_t total_bits, uint8_t digest[20]) {
    uint8_t block[128] = {0};  // Up to 2 blocks for padding
    size_t remaining = (total_bits / 8) % 64;

    // Copy remaining data
    if (remaining > 0) {
        memcpy(block, data, remaining);
    }

    // Append 0x80
    block[remaining] = 0x80;

    // Check if we need two blocks
    if (remaining >= 56) {
        // Process first block
        sha1_ref_block(state, block);
        // Clear and prepare second block
        memset(block, 0, 64);
        // Length goes at offset 56 of second block
        for (int i = 0; i < 8; i++) {
            block[56 + i] = (total_bits >> (56 - i*8)) & 0xFF;
        }
        sha1_ref_block(state, block);
    } else {
        // Single block: length at offset 56
        for (int i = 0; i < 8; i++) {
            block[56 + i] = (total_bits >> (56 - i*8)) & 0xFF;
        }
        sha1_ref_block(state, block);
    }

    // Output digest (big-endian)
    for (int i = 0; i < 5; i++) {
        digest[i*4]   = (state[i] >> 24) & 0xFF;
        digest[i*4+1] = (state[i] >> 16) & 0xFF;
        digest[i*4+2] = (state[i] >> 8) & 0xFF;
        digest[i*4+3] = state[i] & 0xFF;
    }
}

void sha1_ref(const uint8_t *msg, size_t len, uint8_t digest[20]) {
    uint32_t state[5];
    sha1_ref_init(state);

    // Process full blocks
    size_t blocks = len / 64;
    for (size_t i = 0; i < blocks; i++) {
        sha1_ref_block(state, msg + i * 64);
    }

    // Finalize
    sha1_ref_digest(state, msg + blocks * 64, len * 8, digest);
}
