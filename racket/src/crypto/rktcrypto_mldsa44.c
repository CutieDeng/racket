/* ML-DSA-44 (Dilithium), FIPS 204. eta=2, gamma1=2^17, gamma2=(q-1)/88. */

#define MLD_K 4
#define MLD_L 4
#define MLD_ETA 2
#define MLD_TAU 39
#define MLD_BETA 78
#define MLD_GAMMA1 (1 << 17)
#define MLD_GAMMA2 ((8380417 - 1) / 88)
#define MLD_OMEGA 80
#define MLD_CTILDE 32
#define MLD_NAME(x) rktcrypto_mldsa44_##x
#include "rktcrypto_mldsa_impl.h"
