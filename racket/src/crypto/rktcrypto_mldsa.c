/* ML-DSA-65 (Dilithium), FIPS 204. Thin wrapper: sets the parameter set
   and includes the shared parameterized implementation. */

#define MLD_K 6
#define MLD_L 5
#define MLD_ETA 4
#define MLD_TAU 49
#define MLD_BETA 196
#define MLD_GAMMA1 (1 << 19)
#define MLD_GAMMA2 ((8380417 - 1) / 32)
#define MLD_OMEGA 55
#define MLD_CTILDE 48
#define MLD_NAME(x) rktcrypto_mldsa65_##x
#include "rktcrypto_mldsa_impl.h"
