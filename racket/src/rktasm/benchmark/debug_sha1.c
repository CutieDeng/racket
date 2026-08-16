// debug_sha1.c - Debug SHA1 implementations
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "sha1_ref.h"

extern void sha1_init(uint32_t state[5]);
extern void sha1_consume(uint32_t state[5], const uint8_t block[64]);

void print_state(const char *label, uint32_t state[5]) {
    printf("%s: %08x %08x %08x %08x %08x\n",
           label, state[0], state[1], state[2], state[3], state[4]);
}

int main() {
    uint8_t block[64];
    memset(block, 0x61, 64);  // 64 bytes of 'a'

    // C reference
    uint32_t state_c[5];
    sha1_ref_init(state_c);
    print_state("C init", state_c);
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
