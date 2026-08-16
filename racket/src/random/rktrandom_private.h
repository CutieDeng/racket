#ifndef __RKTRANDOM_PRIVATE_H__
#define __RKTRANDOM_PRIVATE_H__ 1

/* Internal entry points shared between rktrandom compilation units,
   the self-test, and the offline differential/benchmark harnesses.
   Not part of the parse.rkt-facing surface in "rktrandom.h" (these
   use uint64_t, which the binding generator does not handle). */

#include "rktrandom.h"

uint64_t rktrandom_next64(int gen, unsigned char *state);
/* The generator's next uint64. For tests and the self-test; bulk
   consumers use rktrandom_fill. A bad `gen` returns 0. */

int rktrandom_init_u64(int gen, unsigned char *state, uint64_t seed, uint64_t seq);
/* Full-width seeding; rktrandom_init_int is the public wrapper. */

#endif /* __RKTRANDOM_PRIVATE_H__ */
