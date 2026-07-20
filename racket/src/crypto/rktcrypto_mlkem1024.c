/* ML-KEM-1024 (Kyber), FIPS 203. eta1=2, du=11, dv=5. */

#define MLK_K 4
#define MLK_ETA1 2
#define MLK_DU 11
#define MLK_DV 5
#define MLK_NAME(x) rktcrypto_mlkem1024_##x
#include "rktcrypto_mlkem_impl.h"
