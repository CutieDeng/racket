#ifndef RKTCRYPTO_BN_H
#define RKTCRYPTO_BN_H
#include <stdint.h>
#include <string.h>
/* Fixed-max bignum: little-endian 64-bit limbs. BN_LIMBS covers RSA-4096 (64
   limbs) products (128) with headroom. top = number of significant limbs. */
#define BN_LIMBS 160
typedef struct { uint64_t d[BN_LIMBS]; int top; } BN;
typedef unsigned __int128 u128;

void bn_zero(BN*); void bn_copy(BN*,const BN*); void bn_set_u64(BN*,uint64_t);
int  bn_is_zero(const BN*); int bn_cmp(const BN*,const BN*);
void bn_from_be(BN*,const unsigned char*,int); void bn_to_be(unsigned char*,int,const BN*);
int  bn_bits(const BN*); int bn_getbit(const BN*,int);
void bn_add(BN*,const BN*,const BN*); void bn_sub(BN*,const BN*,const BN*); void bn_mul(BN*,const BN*,const BN*);
void bn_shl(BN*,const BN*,int); void bn_mod(BN*,const BN*,const BN*);
uint64_t bn_mont_n0(const BN*); void bn_mont_rr(BN*,const BN*);
void bn_mont_setup(uint64_t*,BN*,const BN*);
void bn_montmul(BN*,const BN*,const BN*,const BN*,uint64_t);
void bn_montsqr(BN*,const BN*,const BN*,uint64_t);
void bn_modexp_pre(BN*,const BN*,const BN*,const BN*,uint64_t,const BN*);
void bn_modexp(BN*,const BN*,const BN*,const BN*);
#endif
