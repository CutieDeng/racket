/* Known-answer self-tests for rktcrypto.

   Each algorithm added to rktcrypto must extend this file with a
   known-answer test that runs in well under a millisecond. The tests
   guard against miscompilation, broken platform dispatch, and
   bad links; they are not a substitute for the full test suite. */

#include "rktcrypto.h"

static int test_ct_bytes_equal(void)
{
  unsigned char a[7] = {0, 1, 2, 3, 4, 5, 255};
  unsigned char b[7] = {0, 1, 2, 3, 4, 5, 255};

  if (!rktcrypto_ct_bytes_equal(a, 0, b, 0, 7)) return 0;
  if (!rktcrypto_ct_bytes_equal(a, 0, a, 0, 7)) return 0;
  if (!rktcrypto_ct_bytes_equal(a, 0, b, 0, 0)) return 0;
  if (!rktcrypto_ct_bytes_equal(a, 2, b, 2, 5)) return 0;

  b[6] = 254; /* differ in last byte */
  if (rktcrypto_ct_bytes_equal(a, 0, b, 0, 7)) return 0;
  b[6] = 255;
  b[0] = 1; /* differ in first byte */
  if (rktcrypto_ct_bytes_equal(a, 0, b, 0, 7)) return 0;
  if (!rktcrypto_ct_bytes_equal(a, 1, b, 1, 6)) return 0;

  if (rktcrypto_ct_bytes_equal(a, 0, b, 0, -1)) return 0;

  return 1;
}

static int test_secure_clear(void)
{
  unsigned char buf[8] = {1, 2, 3, 4, 5, 6, 7, 8};
  int i;

  rktcrypto_secure_clear(buf, 2, 6);
  if ((buf[0] != 1) || (buf[1] != 2)) return 0;
  for (i = 2; i < 6; i++)
    if (buf[i] != 0) return 0;
  if ((buf[6] != 7) || (buf[7] != 8)) return 0;

  rktcrypto_secure_clear(buf, 4, 4); /* empty range is a no-op */
  rktcrypto_secure_clear(buf, 4, 2); /* reversed range is a no-op */
  if (buf[6] != 7) return 0;

  return 1;
}

static int test_system_random(void)
{
  /* Sanity only: correct fill region, and output is not all-zeros
     for a request long enough that all-zeros means a broken source
     rather than bad luck (probability 2^-256). */
  unsigned char buf[40];
  unsigned char acc = 0;
  int i;

  for (i = 0; i < 40; i++) buf[i] = 0xAA;

  if (!rktcrypto_system_random(buf, 4, 36)) return 0;
  if ((buf[0] != 0xAA) || (buf[3] != 0xAA)
      || (buf[36] != 0xAA) || (buf[39] != 0xAA))
    return 0;

  for (i = 4; i < 36; i++) acc |= buf[i];
  if (acc == 0) return 0;

  if (!rktcrypto_system_random(buf, 0, 0)) return 0;

  return 1;
}

int rktcrypto_selftest_core(void)
{
  if (!test_ct_bytes_equal()) return 0;
  if (!test_secure_clear()) return 0;
  if (!test_system_random()) return 0;
  return 1;
}
