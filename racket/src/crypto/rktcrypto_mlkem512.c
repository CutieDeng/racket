/* ML-KEM-512 (Kyber), FIPS 203. eta1=3 (CBD3), du=10, dv=4. */

#define MLK_K 2
#define MLK_ETA1 3
#define MLK_DU 10
#define MLK_DV 4
#define MLK_NAME(x) rktcrypto_mlkem512_##x
#include "rktcrypto_mlkem_impl.h"
