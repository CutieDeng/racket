/* Known-answer self-tests for the rktrandom generators.

   The vectors were produced by an offline differential harness that
   first verified every generator bit-exact against its reference
   implementation (Vigna's xoshiro/xoroshiro C for the xoshiro
   family, NumPy's random/src for SFC64, PCG64-DXSM, and Philox4x64),
   including jump/advance functions and fill/next consistency; the
   values below therefore pin both our seeding convention and the
   reference-checked streams. */

#include "rktrandom_private.h"
#include <string.h>

typedef struct {
  int gen;
  uint64_t first[4];      /* init_u64(gen, 42, 0), first 4 outputs */
  uint64_t post_jump[2];  /* after rktrandom_jump, 2 outputs; 0s if no jump */
} rktrandom_kat;

static const rktrandom_kat kats[] = {
  { RKTRANDOM_XOSHIRO256PP,
    { UINT64_C(0xf08ee810b06b8f82), UINT64_C(0x0e25fe820cdd423a), UINT64_C(0x99b7792183aae613), UINT64_C(0xb72b894319cffe66) },
    { UINT64_C(0x38ef2817f5e83c6f), UINT64_C(0x7ac8e3314845a416) } },
  { RKTRANDOM_XOSHIRO256SS,
    { UINT64_C(0x3886bb5945a0ee4b), UINT64_C(0xeaa336a6ccfbc54a), UINT64_C(0x91628125d0e55778), UINT64_C(0xe0cdbd36ed375012) },
    { UINT64_C(0xb8f296c7f1f68a78), UINT64_C(0x14eabf3721f9461e) } },
  { RKTRANDOM_XOROSHIRO128PP,
    { UINT64_C(0x824089d6751943b6), UINT64_C(0xda331f832efcd135), UINT64_C(0x2ccf97eaa0ebe30f), UINT64_C(0x2142525f637fb9ed) },
    { UINT64_C(0x037e25621882e793), UINT64_C(0xbda67c132eb89fb4) } },
  { RKTRANDOM_SFC64,
    { UINT64_C(0xfb7bd9e5e10690c6), UINT64_C(0xedd071b4abad55f7), UINT64_C(0x9efefc91e7b8dc94), UINT64_C(0x56ec6d8c9563b444) },
    { UINT64_C(0), UINT64_C(0) } },
  { RKTRANDOM_PCG64DXSM,
    { UINT64_C(0x55b2b9dc333a909a), UINT64_C(0xb903ff14a70cfca3), UINT64_C(0x41bbacd3a1be1feb), UINT64_C(0x3b2be07b96bfca1b) },
    { UINT64_C(0x2fb4ac63ef5222af), UINT64_C(0xbc2e8cc8bd6e59dd) } },
  { RKTRANDOM_PHILOX4X64,
    { UINT64_C(0xcf76141e410305df), UINT64_C(0x6a7ebdde2fc662c9), UINT64_C(0x4f79001ee34b6ebf), UINT64_C(0x37a8938067a50730) },
    { UINT64_C(0xb9b90128f8fab9c2), UINT64_C(0x35a151b3f2128aa2) } },
};

int rktrandom_selftest(void) {
  unsigned char st[RKTRANDOM_STATE_SIZE], st2[RKTRANDOM_STATE_SIZE];
  unsigned char buf[64];
  int t, i;

  for (t = 0; t < (int)(sizeof kats / sizeof kats[0]); t++) {
    const rktrandom_kat *k = &kats[t];
    int jumps = 0;

    if (!rktrandom_init_u64(k->gen, st, 42, 0))
      return 0;
    memcpy(st2, st, sizeof st);

    for (i = 0; i < 4; i++)
      if (rktrandom_next64(k->gen, st) != k->first[i])
        return 0;

    jumps = rktrandom_jump(k->gen, st);
    if (jumps) {
      for (i = 0; i < 2; i++)
        if (rktrandom_next64(k->gen, st) != k->post_jump[i])
          return 0;
    } else if (k->post_jump[0] || k->post_jump[1]) {
      return 0;
    }

    /* fill must serialize the same stream (33 = 4 words + 1 tail byte) */
    if (!rktrandom_fill(k->gen, st2, buf, 0, 33))
      return 0;
    for (i = 0; i < 4; i++) {
      uint64_t v = 0;
      int b;
      for (b = 7; b >= 0; b--) v = (v << 8) | buf[8 * i + b];
      if (v != k->first[i])
        return 0;
    }
  }

  /* tail check: byte 32 of a 33-byte fill is the low byte of the 5th draw */
  for (t = 0; t < (int)(sizeof kats / sizeof kats[0]); t++) {
    const rktrandom_kat *k = &kats[t];
    uint64_t fifth;
    rktrandom_init_u64(k->gen, st, 42, 0);
    for (i = 0; i < 4; i++) (void)rktrandom_next64(k->gen, st);
    fifth = rktrandom_next64(k->gen, st);
    rktrandom_init_u64(k->gen, st2, 42, 0);
    rktrandom_fill(k->gen, st2, buf, 0, 33);
    if (buf[32] != (unsigned char)fifth)
      return 0;
  }

  return 1;
}
