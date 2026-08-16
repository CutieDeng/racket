/* ML-DSA-87 (Dilithium), FIPS 204. eta=2, gamma1=2^19, gamma2=(q-1)/32. */

#define MLD_K 8
#define MLD_L 7
#define MLD_ETA 2
#define MLD_TAU 60
#define MLD_BETA 120
#define MLD_GAMMA1 (1 << 19)
#define MLD_GAMMA2 ((8380417 - 1) / 32)
#define MLD_OMEGA 75
#define MLD_CTILDE 64
#define MLD_NAME(x) rktcrypto_mldsa87_##x
#include "rktcrypto_mldsa_impl.h"
