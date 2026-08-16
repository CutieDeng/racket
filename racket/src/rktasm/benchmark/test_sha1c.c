// test_sha1c.c - Minimal sha1c test
#include <stdio.h>
#include <stdint.h>
#include <arm_neon.h>

// Test sha1c instruction directly
void test_sha1c() {
    // Initial state: A=0x67452301, B=0xEFCDAB89, C=0x98BADCFE, D=0x10325476, E=0xC3D2E1F0
    // W+K for first round (W=0x61616161, K=0x5A827999) = 0xbbe3dafa

    // Load state into Q register in SHA1 format (A in high bits)
    uint32_t state[] = {0x10325476, 0x98BADCFE, 0xEFCDAB89, 0x67452301}; // [D,C,B,A]
    uint32x4_t abcd = vld1q_u32(state);
    uint32_t e = 0xC3D2E1F0;

    printf("Before sha1c:\n");
    printf("  ABCD (Q): D=%08x C=%08x B=%08x A=%08x\n",
           vgetq_lane_u32(abcd, 0), vgetq_lane_u32(abcd, 1),
           vgetq_lane_u32(abcd, 2), vgetq_lane_u32(abcd, 3));
    printf("  E: %08x\n", e);

    // W+K
    uint32x4_t wk = vdupq_n_u32(0xBBE3DAFA);  // W0+K0

    // Perform one sha1c (4 rounds)
    uint32_t new_e = vsha1h_u32(e);  // E' = ROTL(E, 30)
    abcd = vsha1cq_u32(abcd, e, wk);

    printf("After sha1c:\n");
    printf("  ABCD (Q): D=%08x C=%08x B=%08x A=%08x\n",
           vgetq_lane_u32(abcd, 0), vgetq_lane_u32(abcd, 1),
           vgetq_lane_u32(abcd, 2), vgetq_lane_u32(abcd, 3));
    printf("  sha1h result: %08x\n", new_e);

    // What should new E be? ROTL(A, 30) where A = 0x67452301
    uint32_t A = 0x67452301;
    uint32_t expected_e = (A << 30) | (A >> 2);
    printf("  Expected new E (ROTL(A,30)): %08x\n", expected_e);
}

int main() {
    test_sha1c();
    return 0;
}
