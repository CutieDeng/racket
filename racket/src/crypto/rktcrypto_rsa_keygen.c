/* RSA key generation: random probable-prime search (Miller-Rabin) plus the
   bignum division-with-quotient, gcd, and modular inverse needed to derive
   d, dP, dQ, and qInv. Builds on rktcrypto_bn. Produces keys OpenSSL imports
   and interoperates with. From scratch, no external code. */

#include "rktcrypto.h"
#include "rktcrypto_bn.h"
#include "rktcrypto_rsa.h"
#include <string.h>

/* bn primitives from rktcrypto_bn.c */
void bn_zero(BN*); void bn_copy(BN*,const BN*); void bn_set_u64(BN*,uint64_t);
int  bn_is_zero(const BN*); int bn_cmp(const BN*,const BN*);
void bn_from_be(BN*,const unsigned char*,int); void bn_to_be(unsigned char*,int,const BN*);
int  bn_bits(const BN*); int bn_getbit(const BN*,int);
void bn_add(BN*,const BN*,const BN*); void bn_sub(BN*,const BN*,const BN*); void bn_mul(BN*,const BN*,const BN*);
void bn_shl(BN*,const BN*,int); void bn_mod(BN*,const BN*,const BN*);
void bn_modexp(BN*,const BN*,const BN*,const BN*);

/* q = a / m, r = a % m (m != 0), by shift-and-subtract long division. */
static void bn_divmod(BN*q,BN*r,const BN*a,const BN*m){
  BN x, ms; int s, sh;
  bn_copy(&x,a); bn_zero(q);
  sh = bn_bits(&x) - bn_bits(m);
  for(s=sh; s>=0; s--){
    bn_shl(&ms,m,s);
    if(bn_cmp(&x,&ms)>=0){
      bn_sub(&x,&x,&ms);
      q->d[s/64] |= (uint64_t)1<<(s%64);
      if(q->top < s/64+1) q->top = s/64+1;
    }
  }
  bn_copy(r,&x);
}

static void bn_gcd(BN*g,const BN*a,const BN*b){
  BN x,y,q,r; bn_copy(&x,a); bn_copy(&y,b);
  while(!bn_is_zero(&y)){ bn_divmod(&q,&r,&x,&y); bn_copy(&x,&y); bn_copy(&y,&r); }
  bn_copy(g,&x);
}

/* Modular inverse a^-1 mod m (assumes gcd(a,m)=1). Non-negative extended
   Euclid: the t sequence is kept reduced mod m, so no signed bignums. */
static int bn_modinv(BN*inv,const BN*a,const BN*m){
  BN r0,r1,t0,t1,q,tmp,qt1;
  bn_copy(&r0,m); bn_mod(&r1,a,m);
  bn_set_u64(&t0,0); bn_set_u64(&t1,1);
  while(!bn_is_zero(&r1)){
    BN r2,t2;
    bn_divmod(&q,&r2,&r0,&r1);         /* q = r0/r1, r2 = r0 mod r1 */
    bn_mul(&tmp,&q,&t1); bn_mod(&qt1,&tmp,m);   /* qt1 = q*t1 mod m */
    if(bn_cmp(&t0,&qt1)>=0) bn_sub(&t2,&t0,&qt1);
    else { BN s; bn_sub(&s,m,&qt1); bn_add(&t2,&t0,&s); }   /* t2 = (t0 - qt1) mod m */
    bn_copy(&r0,&r1); bn_copy(&r1,&r2);
    bn_copy(&t0,&t1); bn_copy(&t1,&t2);
  }
  { BN one; bn_set_u64(&one,1); if(bn_cmp(&r0,&one)!=0) return 0; }   /* not invertible */
  bn_copy(inv,&t0); return 1;
}

/* Small odd primes for trial division. */
static const int SMALL_PRIMES[] = {
  3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89,97,
  101,103,107,109,113,127,131,137,139,149,151,157,163,167,173,179,181,191,193,197,199,
  211,223,227,229,233,239,241,251 };
#define NSMALL ((int)(sizeof(SMALL_PRIMES)/sizeof(SMALL_PRIMES[0])))

static int bn_small_divisible(const BN*n){
  BN q,r,sp; int i;
  for(i=0;i<NSMALL;i++){ bn_set_u64(&sp,(uint64_t)SMALL_PRIMES[i]); bn_divmod(&q,&r,n,&sp); if(bn_is_zero(&r)) return 1; }
  return 0;
}

/* Miller-Rabin with `rounds` random bases; returns 1 if probably prime. */
static int bn_probable_prime(const BN*n,int rounds){
  BN nm1,d,two,a,x,q,r; int s,i,j,bits;
  { BN one; bn_set_u64(&one,1); if(bn_cmp(n,&one)<=0) return 0; }
  if(bn_small_divisible(n)) return 0;   /* also rejects the small primes themselves; n is huge so fine */
  bn_set_u64(&two,2);
  bn_copy(&nm1,n); { BN one; bn_set_u64(&one,1); bn_sub(&nm1,&nm1,&one); }
  /* n-1 = 2^s * d, d odd */
  bn_copy(&d,&nm1); s=0;
  while(bn_getbit(&d,0)==0){ BN h; bn_divmod(&h,&r,&d,&two); bn_copy(&d,&h); s++; }
  bits=bn_bits(n);
  for(i=0;i<rounds;i++){
    unsigned char buf[512]; int nb=(bits+7)/8;
    /* random base a in [2, n-2] */
    do {
      if(!rktcrypto_random_bytes(buf,0,nb)) return 0;
      bn_from_be(&a,buf,nb); bn_mod(&a,&a,n);
    } while(bn_cmp(&a,&two)<0);
    bn_modexp(&x,&a,&d,n);
    { BN one; bn_set_u64(&one,1); if(bn_cmp(&x,&one)==0 || bn_cmp(&x,&nm1)==0) continue; }
    for(j=0;j<s-1;j++){
      bn_mul(&q,&x,&x); bn_mod(&x,&q,n);
      if(bn_cmp(&x,&nm1)==0) break;
    }
    if(j==s-1) return 0;   /* composite */
  }
  return 1;
}

/* Generate a random probable prime of exactly `bytes` bytes with the top two
   bits set (so the product has the full modulus width) and odd. */
static int gen_prime(BN*p,int bytes){
  unsigned char buf[256]; int tries;
  for(tries=0; tries<100000; tries++){
    if(!rktcrypto_random_bytes(buf,0,bytes)) return 0;
    buf[0] |= 0xC0; buf[bytes-1] |= 1;
    bn_from_be(p,buf,bytes);
    if(bn_probable_prime(p,40)) return 1;
  }
  return 0;
}

/* Generates an RSA key of `klen` bytes with public exponent e (e.g. 65537),
   filling every field of `k` and precomputing the Montgomery contexts.
   Returns 1 on success, 0 on failure. */
int rsa_keygen(rsa_key*k, int klen, uint64_t e){
  BN one,p1,q1,g,lam,tmp,r,phip,phiq;
  int half=klen/2, attempts;
  bn_set_u64(&one,1);
  bn_set_u64(&k->e,e);
  k->klen = klen;
  for(attempts=0; attempts<200; attempts++){
    if(!gen_prime(&k->p,half)) return 0;
    /* gcd(e, p-1) == 1 */
    bn_sub(&p1,&k->p,&one); { BN eg; bn_gcd(&eg,&k->e,&p1); if(bn_cmp(&eg,&one)!=0) continue; }
    if(!gen_prime(&k->q,half)) return 0;
    if(bn_cmp(&k->p,&k->q)==0) continue;
    bn_sub(&q1,&k->q,&one); { BN eg; bn_gcd(&eg,&k->e,&q1); if(bn_cmp(&eg,&one)!=0) continue; }
    bn_mul(&k->n,&k->p,&k->q);
    if(bn_bits(&k->n) != klen*8) continue;   /* need full width */
    /* ensure p > q so qInv = q^-1 mod p is the standard orientation */
    if(bn_cmp(&k->p,&k->q)<0){ BN t; bn_copy(&t,&k->p); bn_copy(&k->p,&k->q); bn_copy(&k->q,&t);
      bn_sub(&p1,&k->p,&one); bn_sub(&q1,&k->q,&one); }
    /* lambda = (p-1)(q-1)/gcd(p-1,q-1); d = e^-1 mod lambda */
    bn_gcd(&g,&p1,&q1); bn_mul(&tmp,&p1,&q1); { BN qq; bn_divmod(&lam,&r,&tmp,&g); (void)qq; }
    if(!bn_modinv(&k->d,&k->e,&lam)) continue;
    bn_mod(&k->dP,&k->d,&p1);
    bn_mod(&k->dQ,&k->d,&q1);
    if(!bn_modinv(&k->qInv,&k->q,&k->p)) continue;
    (void)phip; (void)phiq;
    rsa_key_precompute(k);
    return 1;
  }
  return 0;
}
