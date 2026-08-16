#include <stdio.h>
#include <stdint.h>

/* Assembled from frame_a.asm / alloca_a.asm by rktasm (M3 .frame). */
extern uint64_t frame_local(uint64_t x);   /* returns x + 100 via FP-relative local */
extern uint64_t alloca_sum(uint64_t n);     /* returns sum 0..2n-1 = n*(2n-1) */

int main(void) {
    int fails = 0;

    /* .frame + FP-relative local round-trip */
    uint64_t in[] = {0, 1, 42, 12345, 0xdeadbeefULL};
    for (unsigned i = 0; i < sizeof(in)/sizeof(in[0]); i++) {
        uint64_t got = frame_local(in[i]);
        uint64_t exp = in[i] + 100;
        printf("frame_local(%llu) = %llu (expect %llu) %s\n",
               (unsigned long long)in[i], (unsigned long long)got,
               (unsigned long long)exp, got == exp ? "OK" : "FAIL");
        if (got != exp) fails++;
    }

    /* variable-length .alloca: sum of 0..2n-1 = n*(2n-1) */
    uint64_t ns[] = {1, 2, 3, 8, 64};
    for (unsigned i = 0; i < sizeof(ns)/sizeof(ns[0]); i++) {
        uint64_t n = ns[i];
        uint64_t got = alloca_sum(n);
        uint64_t exp = n * (2*n - 1);
        printf("alloca_sum(%llu) = %llu (expect %llu) %s\n",
               (unsigned long long)n, (unsigned long long)got,
               (unsigned long long)exp, got == exp ? "OK" : "FAIL");
        if (got != exp) fails++;
    }

    /* Prove sp/callee-saved integrity: interleave many alloca calls and keep
       using locals afterward. If sp were not restored from fp, the process
       would corrupt its stack and crash or misbehave here. */
    uint64_t acc = 0;
    for (uint64_t n = 1; n <= 200; n++) acc += alloca_sum(n);
    uint64_t exp_acc = 0;
    for (uint64_t n = 1; n <= 200; n++) exp_acc += n * (2*n - 1);
    printf("alloca_sum loop acc = %llu (expect %llu) %s\n",
           (unsigned long long)acc, (unsigned long long)exp_acc,
           acc == exp_acc ? "OK" : "FAIL");
    if (acc != exp_acc) fails++;

    printf(fails ? "RESULT: FAIL (%d)\n" : "RESULT: ALL PASS\n", fails);
    return fails ? 1 : 0;
}
