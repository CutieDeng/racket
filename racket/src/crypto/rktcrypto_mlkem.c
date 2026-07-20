/* ML-KEM-768 (Kyber), FIPS 203. Thin wrapper: sets the parameter set and
   includes the shared parameterized implementation. */

#define MLK_K 3
#define MLK_ETA1 2
#define MLK_DU 10
#define MLK_DV 4
#define MLK_NAME(x) rktcrypto_mlkem768_##x
#include "rktcrypto_mlkem_impl.h"
