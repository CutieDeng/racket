// debug_sha1_v2.c - Detailed SHA1 debug
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "sha1_ref.h"

extern void sha1_init(uint32_t state[5]);
extern void sha1_consume(uint32_t state[5], const uint8_t block[64]);

void print_state(const char *label, uint32_t state[5]) {
    printf("%s: A=%08x B=%08x C=%08x D=%08x E=%08x\n",
           label, state[0], state[1], state[2], state[3], state[4]);
}

// Test what element layout the ASM uses
void test_element_layout() {
    uint32_t state[5] = {0x11111111, 0x22222222, 0x33333333, 0x44444444, 0x55555555};
    printf("Test state: ");
    print_state("", state);

    // If we store this to a Q register and load from memory,
    // which element is which?
    uint8_t *bytes = (uint8_t*)state;
    printf("Memory layout: ");
    for (int i = 0; i < 16; i++) {
        printf("%02x ", bytes[i]);
    }
    printf("\n");
}

int main() {
    test_element_layout();

    uint8_t block[64];
    memset(block, 0x61, 64);  // 64 bytes of 'a'

    // C reference
    uint32_t state_c[5];
    sha1_ref_init(state_c);
    print_state("C init", state_c);

    // Simulate first round manually
    // A = state[0], B = state[1], C = state[2], D = state[3], E = state[4]
    // After sha1c, new_E should be ROTL(A, 30)
    uint32_t expected_new_E = (state_c[0] << 30) | (state_c[0] >> 2);
    printf("Expected new E after round 0-3: %08x (ROTL(A=%08x, 30))\n",
           expected_new_E, state_c[0]);

    sha1_ref_block(state_c, block);
    print_state("C block", state_c);

    // ASM
    uint32_t state_asm[5];
    sha1_init(state_asm);
    print_state("ASM init", state_asm);
    sha1_consume(state_asm, block);
    print_state("ASM block", state_asm);

    return 0;
}
