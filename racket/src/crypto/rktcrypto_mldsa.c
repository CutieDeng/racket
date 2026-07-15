/* ML-DSA-65 (Dilithium), FIPS 204.

   From-scratch public-domain-style implementation. Lattice signature
   over Z_q[X]/(X^256+1) with q=8380417. Matrix expansion, noise, mask,
   and challenge sampling use SHAKE128/256 from the digest core. The
   Fiat-Shamir-with-aborts structure gives EUF-CMA security. This is the
   "pure" variant with an application context string (empty by default,
   matching typical interop). No external code. */

#include "rktcrypto.h"
#include "rktcrypto_digest.h"
#include <string.h>
#include <stdint.h>

#define DIL_N 256
#define DIL_Q 8380417
#define DIL_D 13
#define DIL_K 6                 /* ML-DSA-65 */
#define DIL_L 5
#define DIL_ETA 4
#define DIL_TAU 49
#define DIL_BETA 196
#define DIL_GAMMA1 (1 << 19)
#define DIL_GAMMA2 ((DIL_Q - 1) / 32)
#define DIL_OMEGA 55
#define DIL_CTILDEBYTES 48

#define DIL_SEEDBYTES 32
#define DIL_CRHBYTES 64
#define DIL_TRBYTES 64
#define DIL_RNDBYTES 32

#define DIL_POLYT1_PACKEDBYTES 320
#define DIL_POLYT0_PACKEDBYTES 416
#define DIL_POLYVECH_PACKEDBYTES (DIL_OMEGA + DIL_K)
#define DIL_POLYZ_PACKEDBYTES 640
#define DIL_POLYW1_PACKEDBYTES 128
#define DIL_POLYETA_PACKEDBYTES 128

#define DIL_PUBLICKEYBYTES (DIL_SEEDBYTES + DIL_K*DIL_POLYT1_PACKEDBYTES)
#define DIL_SECRETKEYBYTES (2*DIL_SEEDBYTES + DIL_TRBYTES \
    + DIL_L*DIL_POLYETA_PACKEDBYTES + DIL_K*DIL_POLYETA_PACKEDBYTES \
    + DIL_K*DIL_POLYT0_PACKEDBYTES)
#define DIL_SIGBYTES (DIL_CTILDEBYTES + DIL_L*DIL_POLYZ_PACKEDBYTES + DIL_POLYVECH_PACKEDBYTES)

#define DIL_MONT (-4186625)     /* 2^32 mod q, signed */
#define DIL_QINV 58728449       /* q^-1 mod 2^32 */

typedef struct { int32_t coeffs[DIL_N]; } poly;
typedef struct { poly vec[DIL_L]; } polyvecl;
typedef struct { poly vec[DIL_K]; } polyveck;

static const int32_t zetas[DIL_N] = {
-4186625,25847,-2608894,-518909,237124,-777960,-876248,466468,
1826347,2353451,-359251,-2091905,3119733,-2884855,3111497,2680103,
2725464,1024112,-1079900,3585928,-549488,-1119584,2619752,-2108549,
-2118186,-3859737,-1399561,-3277672,1757237,-19422,4010497,280005,
2706023,95776,3077325,3530437,-1661693,-3592148,-2537516,3915439,
-3861115,-3043716,3574422,-2867647,3539968,-300467,2348700,-539299,
-1699267,-1643818,3505694,-3821735,3507263,-2140649,-1600420,3699596,
811944,531354,954230,3881043,3900724,-2556880,2071892,-2797779,
-3930395,-1528703,-3677745,-3041255,-1452451,3475950,2176455,-1585221,
-1257611,1939314,-4083598,-1000202,-3190144,-3157330,-3632928,126922,
3412210,-983419,2147896,2715295,-2967645,-3693493,-411027,-2477047,
-671102,-1228525,-22981,-1308169,-381987,1349076,1852771,-1430430,
-3343383,264944,508951,3097992,44288,-1100098,904516,3958618,
-3724342,-8578,1653064,-3249728,2389356,-210977,759969,-1316856,
189548,-3553272,3159746,-1851402,-2409325,-177440,1315589,1341330,
1285669,-1584928,-812732,-1439742,-3019102,-3881060,-3628969,3839961,
2091667,3407706,2316500,3817976,-3342478,2244091,-2446433,-3562462,
266997,2434439,-1235728,3513181,-3520352,-3759364,-1197226,-3193378,
900702,1859098,909542,819034,495491,-1613174,-43260,-522500,
-655327,-3122442,2031748,3207046,-3556995,-525098,-768622,-3595838,
342297,286988,-2437823,4108315,3437287,-3342277,1735879,203044,
2842341,2691481,-2590150,1265009,4055324,1247620,2486353,1595974,
-3767016,1250494,2635921,-3548272,-2994039,1869119,1903435,-1050970,
-1333058,1237275,-3318210,-1430225,-451100,1312455,3306115,-1962642,
-1279661,1917081,-2546312,-1374803,1500165,777191,2235880,3406031,
-542412,-2831860,-1671176,-1846953,-2584293,-3724270,594136,-3776993,
-2013608,2432395,2454455,-164721,1957272,3369112,185531,-1207385,
-3183426,162844,1616392,3014001,810149,1652634,-3694233,-1799107,
-3038916,3523897,3866901,269760,2213111,-975884,1717735,472078,
-426683,1723600,-1803090,1910376,-1667432,-1104333,-260646,-3833893,
-2939036,-2235985,-420899,-2286327,183443,-976891,1612842,-3545687,
-554416,3919660,-48306,-1362209,3937738,1400424,-846154,1976782,
};

/* ---- modular reduction ---- */
static int32_t montgomery_reduce(int64_t a){
  int32_t t;
  t = (int32_t)((uint64_t)a * (uint32_t)DIL_QINV);
  t = (int32_t)((a - (int64_t)t*DIL_Q) >> 32);
  return t;
}
static int32_t reduce32(int32_t a){
  int32_t t;
  t = (a + (1<<22)) >> 23;
  t = a - t*DIL_Q;
  return t;
}
static int32_t caddq(int32_t a){ a += (a >> 31) & DIL_Q; return a; }

/* ---- NTT ---- */
static void ntt(int32_t a[DIL_N]){
  unsigned int len,start,j,k=0; int32_t zeta,t;
  for(len=128;len>0;len>>=1){
    for(start=0;start<DIL_N;start=j+len){
      zeta=zetas[++k];
      for(j=start;j<start+len;j++){
        t=montgomery_reduce((int64_t)zeta*a[j+len]);
        a[j+len]=a[j]-t;
        a[j]=a[j]+t;
      }
    }
  }
}
static void invntt_tomont(int32_t a[DIL_N]){
  unsigned int start,len,j,k=256; int32_t t,zeta;
  const int32_t f=41978;  /* mont^2/256 */
  for(len=1;len<DIL_N;len<<=1){
    for(start=0;start<DIL_N;start=j+len){
      zeta=-zetas[--k];
      for(j=start;j<start+len;j++){
        t=a[j];
        a[j]=t+a[j+len];
        a[j+len]=t-a[j+len];
        a[j+len]=montgomery_reduce((int64_t)zeta*a[j+len]);
      }
    }
  }
  for(j=0;j<DIL_N;j++) a[j]=montgomery_reduce((int64_t)f*a[j]);
}

/* ---- poly arithmetic ---- */
static void poly_reduce(poly *a){ int i; for(i=0;i<DIL_N;i++) a->coeffs[i]=reduce32(a->coeffs[i]); }
static void poly_caddq(poly *a){ int i; for(i=0;i<DIL_N;i++) a->coeffs[i]=caddq(a->coeffs[i]); }
static void poly_add(poly *c,const poly *a,const poly *b){ int i; for(i=0;i<DIL_N;i++) c->coeffs[i]=a->coeffs[i]+b->coeffs[i]; }
static void poly_sub(poly *c,const poly *a,const poly *b){ int i; for(i=0;i<DIL_N;i++) c->coeffs[i]=a->coeffs[i]-b->coeffs[i]; }
static void poly_shiftl(poly *a){ int i; for(i=0;i<DIL_N;i++) a->coeffs[i]<<=DIL_D; }
static void poly_ntt(poly *a){ ntt(a->coeffs); }
static void poly_invntt_tomont(poly *a){ invntt_tomont(a->coeffs); }
static void poly_pointwise_montgomery(poly *c,const poly *a,const poly *b){
  int i; for(i=0;i<DIL_N;i++) c->coeffs[i]=montgomery_reduce((int64_t)a->coeffs[i]*b->coeffs[i]);
}

/* ---- rounding ---- */
static int32_t power2round(int32_t *a0,int32_t a){
  int32_t a1;
  a1 = (a + (1 << (DIL_D-1)) - 1) >> DIL_D;
  *a0 = a - (a1 << DIL_D);
  return a1;
}
static int32_t decompose(int32_t *a0,int32_t a){
  int32_t a1;
  a1 = (a + 127) >> 7;
  a1 = (a1*1025 + (1 << 21)) >> 22;
  a1 &= 15;
  *a0 = a - a1*2*DIL_GAMMA2;
  *a0 -= (((DIL_Q-1)/2 - *a0) >> 31) & DIL_Q;
  return a1;
}
static unsigned int make_hint(int32_t a0,int32_t a1){
  if(a0 > DIL_GAMMA2 || a0 < -DIL_GAMMA2 || (a0 == -DIL_GAMMA2 && a1 != 0)) return 1;
  return 0;
}
static int32_t use_hint(int32_t a,unsigned int hint){
  int32_t a0,a1;
  a1 = decompose(&a0,a);
  if(hint == 0) return a1;
  if(a0 > 0) return (a1 + 1) & 15;
  return (a1 - 1) & 15;
}
static void poly_power2round(poly *a1,poly *a0,const poly *a){
  int i; for(i=0;i<DIL_N;i++) a1->coeffs[i]=power2round(&a0->coeffs[i],a->coeffs[i]);
}
static void poly_decompose(poly *a1,poly *a0,const poly *a){
  int i; for(i=0;i<DIL_N;i++) a1->coeffs[i]=decompose(&a0->coeffs[i],a->coeffs[i]);
}
static unsigned int poly_make_hint(poly *h,const poly *a0,const poly *a1){
  int i; unsigned int s=0;
  for(i=0;i<DIL_N;i++){ h->coeffs[i]=make_hint(a0->coeffs[i],a1->coeffs[i]); s+=h->coeffs[i]; }
  return s;
}
static void poly_use_hint(poly *b,const poly *a,const poly *h){
  int i; for(i=0;i<DIL_N;i++) b->coeffs[i]=use_hint(a->coeffs[i],h->coeffs[i]);
}
static int poly_chknorm(const poly *a,int32_t B){
  int i; int32_t t;
  if(B > (DIL_Q-1)/8) return 1;
  for(i=0;i<DIL_N;i++){
    t = a->coeffs[i] >> 31;
    t = a->coeffs[i] - (t & 2*a->coeffs[i]);
    if(t >= B) return 1;
  }
  return 0;
}

/* ---- SHAKE helpers ---- */
static void shake128(unsigned char *out,size_t outlen,const unsigned char *in,size_t inlen){
  rktcrypto_keccak_ctx_t c; rktcrypto_keccak_core_init(&c,168,0x1f);
  rktcrypto_keccak_core_update(&c,in,(intptr_t)inlen); rktcrypto_keccak_core_final(&c,out,(intptr_t)outlen);
}
static void shake256(unsigned char *out,size_t outlen,const unsigned char *in,size_t inlen){
  rktcrypto_keccak_ctx_t c; rktcrypto_keccak_core_init(&c,136,0x1f);
  rktcrypto_keccak_core_update(&c,in,(intptr_t)inlen); rktcrypto_keccak_core_final(&c,out,(intptr_t)outlen);
}

/* ---- sampling ---- */
static unsigned int rej_uniform(int32_t *a,unsigned int len,const unsigned char *buf,unsigned int buflen){
  unsigned int ctr=0,pos=0; uint32_t t;
  while(ctr<len && pos+3<=buflen){
    t  = buf[pos++];
    t |= (uint32_t)buf[pos++] << 8;
    t |= (uint32_t)buf[pos++] << 16;
    t &= 0x7FFFFF;
    if(t < DIL_Q) a[ctr++]=t;
  }
  return ctr;
}
/* Matrix entry A[i][j] from rho, nonce=(i<<8)+j. */
static void poly_uniform(poly *a,const unsigned char rho[DIL_SEEDBYTES],uint16_t nonce){
  unsigned char seed[DIL_SEEDBYTES+2]; unsigned char buf[168*6];  /* 6 blocks */
  memcpy(seed,rho,DIL_SEEDBYTES); seed[DIL_SEEDBYTES]=(unsigned char)(nonce&0xFF); seed[DIL_SEEDBYTES+1]=(unsigned char)(nonce>>8);
  shake128(buf,sizeof(buf),seed,DIL_SEEDBYTES+2);
  rej_uniform(a->coeffs,DIL_N,buf,sizeof(buf));
}
static unsigned int rej_eta(int32_t *a,unsigned int len,const unsigned char *buf,unsigned int buflen){
  unsigned int ctr=0,pos=0; uint32_t t0,t1;
  while(ctr<len && pos<buflen){
    t0 = buf[pos] & 0x0F;
    t1 = buf[pos++] >> 4;
    if(t0 < 9) a[ctr++]=4-(int32_t)t0;
    if(t1 < 9 && ctr<len) a[ctr++]=4-(int32_t)t1;
  }
  return ctr;
}
static void poly_uniform_eta(poly *a,const unsigned char seed[DIL_CRHBYTES],uint16_t nonce){
  unsigned char in[DIL_CRHBYTES+2]; unsigned char buf[136*3];  /* 3 blocks */
  memcpy(in,seed,DIL_CRHBYTES); in[DIL_CRHBYTES]=(unsigned char)(nonce&0xFF); in[DIL_CRHBYTES+1]=(unsigned char)(nonce>>8);
  shake256(buf,sizeof(buf),in,DIL_CRHBYTES+2);
  rej_eta(a->coeffs,DIL_N,buf,sizeof(buf));
}
static void polyz_unpack(poly *r,const unsigned char *a);
static void poly_uniform_gamma1(poly *a,const unsigned char seed[DIL_CRHBYTES],uint16_t nonce){
  unsigned char in[DIL_CRHBYTES+2]; unsigned char buf[DIL_POLYZ_PACKEDBYTES];
  memcpy(in,seed,DIL_CRHBYTES); in[DIL_CRHBYTES]=(unsigned char)(nonce&0xFF); in[DIL_CRHBYTES+1]=(unsigned char)(nonce>>8);
  shake256(buf,sizeof(buf),in,DIL_CRHBYTES+2);
  polyz_unpack(a,buf);
}
static void poly_challenge(poly *c,const unsigned char seed[DIL_CTILDEBYTES]){
  unsigned int i,b,pos; uint64_t signs; unsigned char buf[136*5]; /* 5 blocks: plenty */
  shake256(buf,sizeof(buf),seed,DIL_CTILDEBYTES);
  signs=0;
  for(i=0;i<8;i++) signs |= (uint64_t)buf[i] << (8*i);
  pos=8;
  for(i=0;i<DIL_N;i++) c->coeffs[i]=0;
  for(i=DIL_N-DIL_TAU;i<DIL_N;i++){
    do { b=buf[pos++]; } while(b > i);
    c->coeffs[i]=c->coeffs[b];
    c->coeffs[b]=1 - 2*(int32_t)(signs & 1);
    signs >>= 1;
  }
}

/* ---- packing ---- */
static void polyeta_pack(unsigned char *r,const poly *a){
  int i; unsigned char t0,t1;
  for(i=0;i<DIL_N/2;i++){
    t0=(unsigned char)(DIL_ETA - a->coeffs[2*i+0]);
    t1=(unsigned char)(DIL_ETA - a->coeffs[2*i+1]);
    r[i]=(unsigned char)(t0 | (t1<<4));
  }
}
static void polyeta_unpack(poly *r,const unsigned char *a){
  int i;
  for(i=0;i<DIL_N/2;i++){
    r->coeffs[2*i+0]=a[i] & 0x0F;
    r->coeffs[2*i+1]=a[i] >> 4;
    r->coeffs[2*i+0]=DIL_ETA - r->coeffs[2*i+0];
    r->coeffs[2*i+1]=DIL_ETA - r->coeffs[2*i+1];
  }
}
static void polyt1_pack(unsigned char *r,const poly *a){
  int i;
  for(i=0;i<DIL_N/4;i++){
    r[5*i+0]=(unsigned char)(a->coeffs[4*i+0]);
    r[5*i+1]=(unsigned char)((a->coeffs[4*i+0]>>8)|(a->coeffs[4*i+1]<<2));
    r[5*i+2]=(unsigned char)((a->coeffs[4*i+1]>>6)|(a->coeffs[4*i+2]<<4));
    r[5*i+3]=(unsigned char)((a->coeffs[4*i+2]>>4)|(a->coeffs[4*i+3]<<6));
    r[5*i+4]=(unsigned char)(a->coeffs[4*i+3]>>2);
  }
}
static void polyt1_unpack(poly *r,const unsigned char *a){
  int i;
  for(i=0;i<DIL_N/4;i++){
    r->coeffs[4*i+0]=((a[5*i+0]>>0)|((uint32_t)a[5*i+1]<<8)) & 0x3FF;
    r->coeffs[4*i+1]=((a[5*i+1]>>2)|((uint32_t)a[5*i+2]<<6)) & 0x3FF;
    r->coeffs[4*i+2]=((a[5*i+2]>>4)|((uint32_t)a[5*i+3]<<4)) & 0x3FF;
    r->coeffs[4*i+3]=((a[5*i+3]>>6)|((uint32_t)a[5*i+4]<<2)) & 0x3FF;
  }
}
static void polyt0_pack(unsigned char *r,const poly *a){
  int i; uint32_t t[8];
  for(i=0;i<DIL_N/8;i++){
    t[0]=(1<<(DIL_D-1)) - a->coeffs[8*i+0];
    t[1]=(1<<(DIL_D-1)) - a->coeffs[8*i+1];
    t[2]=(1<<(DIL_D-1)) - a->coeffs[8*i+2];
    t[3]=(1<<(DIL_D-1)) - a->coeffs[8*i+3];
    t[4]=(1<<(DIL_D-1)) - a->coeffs[8*i+4];
    t[5]=(1<<(DIL_D-1)) - a->coeffs[8*i+5];
    t[6]=(1<<(DIL_D-1)) - a->coeffs[8*i+6];
    t[7]=(1<<(DIL_D-1)) - a->coeffs[8*i+7];
    r[13*i+0]=(unsigned char)(t[0]);
    r[13*i+1]=(unsigned char)(t[0]>>8);   r[13*i+1]|=(unsigned char)(t[1]<<5);
    r[13*i+2]=(unsigned char)(t[1]>>3);
    r[13*i+3]=(unsigned char)(t[1]>>11);  r[13*i+3]|=(unsigned char)(t[2]<<2);
    r[13*i+4]=(unsigned char)(t[2]>>6);   r[13*i+4]|=(unsigned char)(t[3]<<7);
    r[13*i+5]=(unsigned char)(t[3]>>1);
    r[13*i+6]=(unsigned char)(t[3]>>9);   r[13*i+6]|=(unsigned char)(t[4]<<4);
    r[13*i+7]=(unsigned char)(t[4]>>4);
    r[13*i+8]=(unsigned char)(t[4]>>12);  r[13*i+8]|=(unsigned char)(t[5]<<1);
    r[13*i+9]=(unsigned char)(t[5]>>7);   r[13*i+9]|=(unsigned char)(t[6]<<6);
    r[13*i+10]=(unsigned char)(t[6]>>2);
    r[13*i+11]=(unsigned char)(t[6]>>10); r[13*i+11]|=(unsigned char)(t[7]<<3);
    r[13*i+12]=(unsigned char)(t[7]>>5);
  }
}
static void polyt0_unpack(poly *r,const unsigned char *a){
  int i;
  for(i=0;i<DIL_N/8;i++){
    r->coeffs[8*i+0]=a[13*i+0];
    r->coeffs[8*i+0]|=(uint32_t)a[13*i+1]<<8;  r->coeffs[8*i+0]&=0x1FFF;
    r->coeffs[8*i+1]=a[13*i+1]>>5;
    r->coeffs[8*i+1]|=(uint32_t)a[13*i+2]<<3;
    r->coeffs[8*i+1]|=(uint32_t)a[13*i+3]<<11; r->coeffs[8*i+1]&=0x1FFF;
    r->coeffs[8*i+2]=a[13*i+3]>>2;
    r->coeffs[8*i+2]|=(uint32_t)a[13*i+4]<<6;  r->coeffs[8*i+2]&=0x1FFF;
    r->coeffs[8*i+3]=a[13*i+4]>>7;
    r->coeffs[8*i+3]|=(uint32_t)a[13*i+5]<<1;
    r->coeffs[8*i+3]|=(uint32_t)a[13*i+6]<<9;  r->coeffs[8*i+3]&=0x1FFF;
    r->coeffs[8*i+4]=a[13*i+6]>>4;
    r->coeffs[8*i+4]|=(uint32_t)a[13*i+7]<<4;
    r->coeffs[8*i+4]|=(uint32_t)a[13*i+8]<<12; r->coeffs[8*i+4]&=0x1FFF;
    r->coeffs[8*i+5]=a[13*i+8]>>1;
    r->coeffs[8*i+5]|=(uint32_t)a[13*i+9]<<7;  r->coeffs[8*i+5]&=0x1FFF;
    r->coeffs[8*i+6]=a[13*i+9]>>6;
    r->coeffs[8*i+6]|=(uint32_t)a[13*i+10]<<2;
    r->coeffs[8*i+6]|=(uint32_t)a[13*i+11]<<10; r->coeffs[8*i+6]&=0x1FFF;
    r->coeffs[8*i+7]=a[13*i+11]>>3;
    r->coeffs[8*i+7]|=(uint32_t)a[13*i+12]<<5;  r->coeffs[8*i+7]&=0x1FFF;
    r->coeffs[8*i+0]=(1<<(DIL_D-1)) - r->coeffs[8*i+0];
    r->coeffs[8*i+1]=(1<<(DIL_D-1)) - r->coeffs[8*i+1];
    r->coeffs[8*i+2]=(1<<(DIL_D-1)) - r->coeffs[8*i+2];
    r->coeffs[8*i+3]=(1<<(DIL_D-1)) - r->coeffs[8*i+3];
    r->coeffs[8*i+4]=(1<<(DIL_D-1)) - r->coeffs[8*i+4];
    r->coeffs[8*i+5]=(1<<(DIL_D-1)) - r->coeffs[8*i+5];
    r->coeffs[8*i+6]=(1<<(DIL_D-1)) - r->coeffs[8*i+6];
    r->coeffs[8*i+7]=(1<<(DIL_D-1)) - r->coeffs[8*i+7];
  }
}
static void polyz_pack(unsigned char *r,const poly *a){
  int i; uint32_t t[2];
  for(i=0;i<DIL_N/2;i++){
    t[0]=DIL_GAMMA1 - a->coeffs[2*i+0];
    t[1]=DIL_GAMMA1 - a->coeffs[2*i+1];
    r[5*i+0]=(unsigned char)(t[0]);
    r[5*i+1]=(unsigned char)(t[0]>>8);
    r[5*i+2]=(unsigned char)(t[0]>>16);  r[5*i+2]|=(unsigned char)(t[1]<<4);
    r[5*i+3]=(unsigned char)(t[1]>>4);
    r[5*i+4]=(unsigned char)(t[1]>>12);
  }
}
static void polyz_unpack(poly *r,const unsigned char *a){
  int i;
  for(i=0;i<DIL_N/2;i++){
    r->coeffs[2*i+0]=a[5*i+0];
    r->coeffs[2*i+0]|=(uint32_t)a[5*i+1]<<8;
    r->coeffs[2*i+0]|=(uint32_t)a[5*i+2]<<16;  r->coeffs[2*i+0]&=0xFFFFF;
    r->coeffs[2*i+1]=a[5*i+2]>>4;
    r->coeffs[2*i+1]|=(uint32_t)a[5*i+3]<<4;
    r->coeffs[2*i+1]|=(uint32_t)a[5*i+4]<<12;  r->coeffs[2*i+1]&=0xFFFFF;
    r->coeffs[2*i+0]=DIL_GAMMA1 - r->coeffs[2*i+0];
    r->coeffs[2*i+1]=DIL_GAMMA1 - r->coeffs[2*i+1];
  }
}
static void polyw1_pack(unsigned char *r,const poly *a){
  int i;
  for(i=0;i<DIL_N/2;i++) r[i]=(unsigned char)(a->coeffs[2*i+0] | (a->coeffs[2*i+1]<<4));
}

/* ---- polyvec helpers ---- */
static void polyvec_matrix_expand(polyvecl mat[DIL_K],const unsigned char rho[DIL_SEEDBYTES]){
  unsigned int i,j;
  for(i=0;i<DIL_K;i++) for(j=0;j<DIL_L;j++) poly_uniform(&mat[i].vec[j],rho,(uint16_t)((i<<8)+j));
}
static void polyvecl_ntt(polyvecl *v){ int i; for(i=0;i<DIL_L;i++) poly_ntt(&v->vec[i]); }
static void polyvecl_invntt_tomont(polyvecl *v){ int i; for(i=0;i<DIL_L;i++) poly_invntt_tomont(&v->vec[i]); }
static void polyvecl_reduce(polyvecl *v){ int i; for(i=0;i<DIL_L;i++) poly_reduce(&v->vec[i]); }
static void polyvecl_add(polyvecl *c,const polyvecl *a,const polyvecl *b){ int i; for(i=0;i<DIL_L;i++) poly_add(&c->vec[i],&a->vec[i],&b->vec[i]); }
static void polyvecl_pointwise_poly_montgomery(polyvecl *r,const poly *a,const polyvecl *v){ int i; for(i=0;i<DIL_L;i++) poly_pointwise_montgomery(&r->vec[i],a,&v->vec[i]); }
static int polyvecl_chknorm(const polyvecl *v,int32_t B){ int i; for(i=0;i<DIL_L;i++) if(poly_chknorm(&v->vec[i],B)) return 1; return 0; }
static void polyvecl_pointwise_acc_montgomery(poly *w,const polyvecl *u,const polyvecl *v){
  int i; poly t;
  poly_pointwise_montgomery(w,&u->vec[0],&v->vec[0]);
  for(i=1;i<DIL_L;i++){ poly_pointwise_montgomery(&t,&u->vec[i],&v->vec[i]); poly_add(w,w,&t); }
}
static void polyvec_matrix_pointwise_montgomery(polyveck *t,const polyvecl mat[DIL_K],const polyvecl *v){
  int i; for(i=0;i<DIL_K;i++) polyvecl_pointwise_acc_montgomery(&t->vec[i],&mat[i],v);
}
static void polyveck_ntt(polyveck *v){ int i; for(i=0;i<DIL_K;i++) poly_ntt(&v->vec[i]); }
static void polyveck_invntt_tomont(polyveck *v){ int i; for(i=0;i<DIL_K;i++) poly_invntt_tomont(&v->vec[i]); }
static void polyveck_reduce(polyveck *v){ int i; for(i=0;i<DIL_K;i++) poly_reduce(&v->vec[i]); }
static void polyveck_caddq(polyveck *v){ int i; for(i=0;i<DIL_K;i++) poly_caddq(&v->vec[i]); }
static void polyveck_add(polyveck *c,const polyveck *a,const polyveck *b){ int i; for(i=0;i<DIL_K;i++) poly_add(&c->vec[i],&a->vec[i],&b->vec[i]); }
static void polyveck_sub(polyveck *c,const polyveck *a,const polyveck *b){ int i; for(i=0;i<DIL_K;i++) poly_sub(&c->vec[i],&a->vec[i],&b->vec[i]); }
static void polyveck_shiftl(polyveck *v){ int i; for(i=0;i<DIL_K;i++) poly_shiftl(&v->vec[i]); }
static void polyveck_pointwise_poly_montgomery(polyveck *r,const poly *a,const polyveck *v){ int i; for(i=0;i<DIL_K;i++) poly_pointwise_montgomery(&r->vec[i],a,&v->vec[i]); }
static int polyveck_chknorm(const polyveck *v,int32_t B){ int i; for(i=0;i<DIL_K;i++) if(poly_chknorm(&v->vec[i],B)) return 1; return 0; }
static void polyveck_power2round(polyveck *a1,polyveck *a0,const polyveck *a){ int i; for(i=0;i<DIL_K;i++) poly_power2round(&a1->vec[i],&a0->vec[i],&a->vec[i]); }
static void polyveck_decompose(polyveck *a1,polyveck *a0,const polyveck *a){ int i; for(i=0;i<DIL_K;i++) poly_decompose(&a1->vec[i],&a0->vec[i],&a->vec[i]); }
static unsigned int polyveck_make_hint(polyveck *h,const polyveck *a0,const polyveck *a1){ int i; unsigned int s=0; for(i=0;i<DIL_K;i++) s+=poly_make_hint(&h->vec[i],&a0->vec[i],&a1->vec[i]); return s; }
static void polyveck_use_hint(polyveck *b,const polyveck *a,const polyveck *h){ int i; for(i=0;i<DIL_K;i++) poly_use_hint(&b->vec[i],&a->vec[i],&h->vec[i]); }
static void polyveck_pack_w1(unsigned char *r,const polyveck *w1){ int i; for(i=0;i<DIL_K;i++) polyw1_pack(&r[i*DIL_POLYW1_PACKEDBYTES],&w1->vec[i]); }

/* ---- key/sig packing ---- */
static void pack_pk(unsigned char *pk,const unsigned char rho[DIL_SEEDBYTES],const polyveck *t1){
  int i; memcpy(pk,rho,DIL_SEEDBYTES); pk+=DIL_SEEDBYTES;
  for(i=0;i<DIL_K;i++) polyt1_pack(pk+i*DIL_POLYT1_PACKEDBYTES,&t1->vec[i]);
}
static void unpack_pk(unsigned char rho[DIL_SEEDBYTES],polyveck *t1,const unsigned char *pk){
  int i; memcpy(rho,pk,DIL_SEEDBYTES); pk+=DIL_SEEDBYTES;
  for(i=0;i<DIL_K;i++) polyt1_unpack(&t1->vec[i],pk+i*DIL_POLYT1_PACKEDBYTES);
}
static void pack_sk(unsigned char *sk,const unsigned char rho[DIL_SEEDBYTES],
                    const unsigned char tr[DIL_TRBYTES],const unsigned char key[DIL_SEEDBYTES],
                    const polyveck *t0,const polyvecl *s1,const polyveck *s2){
  int i;
  memcpy(sk,rho,DIL_SEEDBYTES); sk+=DIL_SEEDBYTES;
  memcpy(sk,key,DIL_SEEDBYTES); sk+=DIL_SEEDBYTES;
  memcpy(sk,tr,DIL_TRBYTES);    sk+=DIL_TRBYTES;
  for(i=0;i<DIL_L;i++) polyeta_pack(sk+i*DIL_POLYETA_PACKEDBYTES,&s1->vec[i]);
  sk+=DIL_L*DIL_POLYETA_PACKEDBYTES;
  for(i=0;i<DIL_K;i++) polyeta_pack(sk+i*DIL_POLYETA_PACKEDBYTES,&s2->vec[i]);
  sk+=DIL_K*DIL_POLYETA_PACKEDBYTES;
  for(i=0;i<DIL_K;i++) polyt0_pack(sk+i*DIL_POLYT0_PACKEDBYTES,&t0->vec[i]);
}
static void unpack_sk(unsigned char rho[DIL_SEEDBYTES],unsigned char tr[DIL_TRBYTES],
                      unsigned char key[DIL_SEEDBYTES],polyveck *t0,polyvecl *s1,polyveck *s2,
                      const unsigned char *sk){
  int i;
  memcpy(rho,sk,DIL_SEEDBYTES); sk+=DIL_SEEDBYTES;
  memcpy(key,sk,DIL_SEEDBYTES); sk+=DIL_SEEDBYTES;
  memcpy(tr,sk,DIL_TRBYTES);    sk+=DIL_TRBYTES;
  for(i=0;i<DIL_L;i++) polyeta_unpack(&s1->vec[i],sk+i*DIL_POLYETA_PACKEDBYTES);
  sk+=DIL_L*DIL_POLYETA_PACKEDBYTES;
  for(i=0;i<DIL_K;i++) polyeta_unpack(&s2->vec[i],sk+i*DIL_POLYETA_PACKEDBYTES);
  sk+=DIL_K*DIL_POLYETA_PACKEDBYTES;
  for(i=0;i<DIL_K;i++) polyt0_unpack(&t0->vec[i],sk+i*DIL_POLYT0_PACKEDBYTES);
}
static void pack_sig(unsigned char *sig,const unsigned char c[DIL_CTILDEBYTES],const polyvecl *z,const polyveck *h){
  int i,j; unsigned int k;
  memcpy(sig,c,DIL_CTILDEBYTES); sig+=DIL_CTILDEBYTES;
  for(i=0;i<DIL_L;i++) polyz_pack(sig+i*DIL_POLYZ_PACKEDBYTES,&z->vec[i]);
  sig+=DIL_L*DIL_POLYZ_PACKEDBYTES;
  for(i=0;i<DIL_OMEGA+DIL_K;i++) sig[i]=0;
  k=0;
  for(i=0;i<DIL_K;i++){
    for(j=0;j<DIL_N;j++) if(h->vec[i].coeffs[j] != 0) sig[k++]=(unsigned char)j;
    sig[DIL_OMEGA+i]=(unsigned char)k;
  }
}
static int unpack_sig(unsigned char c[DIL_CTILDEBYTES],polyvecl *z,polyveck *h,const unsigned char *sig){
  int i,j; unsigned int k;
  memcpy(c,sig,DIL_CTILDEBYTES); sig+=DIL_CTILDEBYTES;
  for(i=0;i<DIL_L;i++) polyz_unpack(&z->vec[i],sig+i*DIL_POLYZ_PACKEDBYTES);
  sig+=DIL_L*DIL_POLYZ_PACKEDBYTES;
  k=0;
  for(i=0;i<DIL_K;i++){
    for(j=0;j<DIL_N;j++) h->vec[i].coeffs[j]=0;
    if(sig[DIL_OMEGA+i] < k || sig[DIL_OMEGA+i] > DIL_OMEGA) return 1;
    for(j=k;j<sig[DIL_OMEGA+i];j++){
      if(j>(int)k && sig[j] <= sig[j-1]) return 1;
      h->vec[i].coeffs[sig[j]]=1;
    }
    k=sig[DIL_OMEGA+i];
  }
  for(j=k;j<DIL_OMEGA;j++) if(sig[j]) return 1;
  return 0;
}

/* ---- top-level, deterministic keygen from 32-byte seed ---- */
int rktcrypto_mldsa65_keypair_derand(unsigned char *pk,unsigned char *sk,const unsigned char *seed){
  unsigned char seedbuf[2*DIL_SEEDBYTES+DIL_CRHBYTES];
  unsigned char inbuf[DIL_SEEDBYTES+2];
  const unsigned char *rho,*rhoprime,*key;
  unsigned char tr[DIL_TRBYTES];
  polyvecl mat[DIL_K],s1,s1hat;
  polyveck s2,t1,t0,t;
  memcpy(inbuf,seed,DIL_SEEDBYTES);
  inbuf[DIL_SEEDBYTES]=DIL_K; inbuf[DIL_SEEDBYTES+1]=DIL_L;
  shake256(seedbuf,sizeof(seedbuf),inbuf,DIL_SEEDBYTES+2);
  rho=seedbuf; rhoprime=rho+DIL_SEEDBYTES; key=rhoprime+DIL_CRHBYTES;

  polyvec_matrix_expand(mat,rho);
  { int i; for(i=0;i<DIL_L;i++) poly_uniform_eta(&s1.vec[i],rhoprime,(uint16_t)i); }
  { int i; for(i=0;i<DIL_K;i++) poly_uniform_eta(&s2.vec[i],rhoprime,(uint16_t)(DIL_L+i)); }
  s1hat=s1;
  polyvecl_ntt(&s1hat);
  polyvec_matrix_pointwise_montgomery(&t,mat,&s1hat);
  polyveck_reduce(&t);
  polyveck_invntt_tomont(&t);
  polyveck_add(&t,&t,&s2);
  polyveck_caddq(&t);
  polyveck_power2round(&t1,&t0,&t);
  pack_pk(pk,rho,&t1);
  shake256(tr,DIL_TRBYTES,pk,DIL_PUBLICKEYBYTES);
  pack_sk(sk,rho,tr,key,&t0,&s1,&s2);
  return 1;
}

/* ---- signing; ctx may be NULL/0 (empty context, pure ML-DSA) ---- */
static int mldsa65_sign_internal(unsigned char *sig,
                                 const unsigned char *m,size_t mlen,
                                 const unsigned char *ctx,size_t ctxlen,
                                 const unsigned char *sk,const unsigned char *rnd){
  unsigned char rho[DIL_SEEDBYTES],tr[DIL_TRBYTES],key[DIL_SEEDBYTES];
  unsigned char mu[DIL_CRHBYTES],rhoprime[DIL_CRHBYTES];
  unsigned char ctilde[DIL_CTILDEBYTES];
  unsigned char w1packed[DIL_K*DIL_POLYW1_PACKEDBYTES];
  unsigned char keymu[DIL_SEEDBYTES+DIL_RNDBYTES+DIL_CRHBYTES];
  unsigned char pfx[2];
  polyvecl mat[DIL_K],s1,y,z;
  polyveck t0,s2,w1,w0,h;
  poly cp;
  uint16_t nonce=0;
  rktcrypto_keccak_ctx_t kc;

  if(ctxlen > 255) return 0;
  unpack_sk(rho,tr,key,&t0,&s1,&s2,sk);

  /* mu = H(tr || 0x00 || ctxlen || ctx || m) */
  pfx[0]=0; pfx[1]=(unsigned char)ctxlen;
  rktcrypto_keccak_core_init(&kc,136,0x1f);
  rktcrypto_keccak_core_update(&kc,tr,DIL_TRBYTES);
  rktcrypto_keccak_core_update(&kc,pfx,2);
  if(ctxlen) rktcrypto_keccak_core_update(&kc,ctx,(intptr_t)ctxlen);
  rktcrypto_keccak_core_update(&kc,m,(intptr_t)mlen);
  rktcrypto_keccak_core_final(&kc,mu,DIL_CRHBYTES);

  /* rhoprime = H(key || rnd || mu) */
  memcpy(keymu,key,DIL_SEEDBYTES);
  memcpy(keymu+DIL_SEEDBYTES,rnd,DIL_RNDBYTES);
  memcpy(keymu+DIL_SEEDBYTES+DIL_RNDBYTES,mu,DIL_CRHBYTES);
  shake256(rhoprime,DIL_CRHBYTES,keymu,sizeof(keymu));

  polyvec_matrix_expand(mat,rho);
  polyvecl_ntt(&s1);
  polyveck_ntt(&s2);
  polyveck_ntt(&t0);

  for(;;){
    int i;
    /* y = mask */
    for(i=0;i<DIL_L;i++) poly_uniform_gamma1(&y.vec[i],rhoprime,(uint16_t)(DIL_L*nonce+i));
    nonce++;
    /* w = A*y */
    z=y;
    polyvecl_ntt(&z);
    polyvec_matrix_pointwise_montgomery(&w1,mat,&z);
    polyveck_reduce(&w1);
    polyveck_invntt_tomont(&w1);
    polyveck_caddq(&w1);
    polyveck_decompose(&w1,&w0,&w1);
    polyveck_pack_w1(w1packed,&w1);
    /* ctilde = H(mu || w1) */
    rktcrypto_keccak_core_init(&kc,136,0x1f);
    rktcrypto_keccak_core_update(&kc,mu,DIL_CRHBYTES);
    rktcrypto_keccak_core_update(&kc,w1packed,sizeof(w1packed));
    rktcrypto_keccak_core_final(&kc,ctilde,DIL_CTILDEBYTES);
    poly_challenge(&cp,ctilde);
    poly_ntt(&cp);
    /* z = y + c*s1 */
    polyvecl_pointwise_poly_montgomery(&z,&cp,&s1);
    polyvecl_invntt_tomont(&z);
    polyvecl_add(&z,&z,&y);
    polyvecl_reduce(&z);
    if(polyvecl_chknorm(&z,DIL_GAMMA1-DIL_BETA)) continue;
    /* w0 -= c*s2 */
    polyveck_pointwise_poly_montgomery(&h,&cp,&s2);
    polyveck_invntt_tomont(&h);
    polyveck_sub(&w0,&w0,&h);
    polyveck_reduce(&w0);
    if(polyveck_chknorm(&w0,DIL_GAMMA2-DIL_BETA)) continue;
    /* hints from c*t0 */
    polyveck_pointwise_poly_montgomery(&h,&cp,&t0);
    polyveck_invntt_tomont(&h);
    polyveck_reduce(&h);
    if(polyveck_chknorm(&h,DIL_GAMMA2)) continue;
    polyveck_add(&w0,&w0,&h);
    if(polyveck_make_hint(&h,&w0,&w1) > DIL_OMEGA) continue;
    pack_sig(sig,ctilde,&z,&h);
    return 1;
  }
}

int rktcrypto_mldsa65_sign(unsigned char *sig,
                           const unsigned char *m,intptr_t mlen,
                           const unsigned char *sk){
  unsigned char rnd[DIL_RNDBYTES];
  if(!rktcrypto_random_bytes(rnd,0,DIL_RNDBYTES)) return 0;
  return mldsa65_sign_internal(sig,m,(size_t)mlen,NULL,0,sk,rnd);
}
int rktcrypto_mldsa65_sign_derand(unsigned char *sig,
                                  const unsigned char *m,intptr_t mlen,
                                  const unsigned char *sk){
  unsigned char rnd[DIL_RNDBYTES]; memset(rnd,0,sizeof(rnd));
  return mldsa65_sign_internal(sig,m,(size_t)mlen,NULL,0,sk,rnd);
}

int rktcrypto_mldsa65_verify(const unsigned char *sig,
                             const unsigned char *m,intptr_t mlen,
                             const unsigned char *pk){
  unsigned char rho[DIL_SEEDBYTES],tr[DIL_TRBYTES],mu[DIL_CRHBYTES];
  unsigned char c[DIL_CTILDEBYTES],c2[DIL_CTILDEBYTES];
  unsigned char w1packed[DIL_K*DIL_POLYW1_PACKEDBYTES];
  unsigned char pfx[2];
  polyvecl mat[DIL_K],z;
  polyveck t1,w1,h;
  poly cp;
  rktcrypto_keccak_ctx_t kc;
  int i; size_t ctxlen=0;

  unpack_pk(rho,&t1,pk);
  if(unpack_sig(c,&z,&h,sig)) return 0;
  if(polyvecl_chknorm(&z,DIL_GAMMA1-DIL_BETA)) return 0;

  /* mu = H(H(pk) || 0x00 || ctxlen || ctx || m) */
  shake256(tr,DIL_TRBYTES,pk,DIL_PUBLICKEYBYTES);
  pfx[0]=0; pfx[1]=(unsigned char)ctxlen;
  rktcrypto_keccak_core_init(&kc,136,0x1f);
  rktcrypto_keccak_core_update(&kc,tr,DIL_TRBYTES);
  rktcrypto_keccak_core_update(&kc,pfx,2);
  rktcrypto_keccak_core_update(&kc,m,(intptr_t)mlen);
  rktcrypto_keccak_core_final(&kc,mu,DIL_CRHBYTES);

  poly_challenge(&cp,c);
  polyvec_matrix_expand(mat,rho);
  polyvecl_ntt(&z);
  polyvec_matrix_pointwise_montgomery(&w1,mat,&z);
  poly_ntt(&cp);
  polyveck_shiftl(&t1);
  polyveck_ntt(&t1);
  polyveck_pointwise_poly_montgomery(&t1,&cp,&t1);
  polyveck_sub(&w1,&w1,&t1);
  polyveck_reduce(&w1);
  polyveck_invntt_tomont(&w1);
  polyveck_caddq(&w1);
  polyveck_use_hint(&w1,&w1,&h);
  polyveck_pack_w1(w1packed,&w1);

  rktcrypto_keccak_core_init(&kc,136,0x1f);
  rktcrypto_keccak_core_update(&kc,mu,DIL_CRHBYTES);
  rktcrypto_keccak_core_update(&kc,w1packed,sizeof(w1packed));
  rktcrypto_keccak_core_final(&kc,c2,DIL_CTILDEBYTES);
  for(i=0;i<DIL_CTILDEBYTES;i++) if(c[i]!=c2[i]) return 0;
  return 1;
}

int rktcrypto_mldsa65_keypair(unsigned char *pk,unsigned char *sk){
  unsigned char seed[DIL_SEEDBYTES];
  if(!rktcrypto_random_bytes(seed,0,DIL_SEEDBYTES)) return 0;
  return rktcrypto_mldsa65_keypair_derand(pk,sk,seed);
}
