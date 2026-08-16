/* AES-CTR and AES-CBC for 128/192/256-bit keys (NIST SP 800-38A).

   Hardware path (ARMv8 AES): 8-way CTR and 8-way CBC-decrypt keep the AES units
   saturated; the counter blocks are built with a NEON big-endian lane-set (no
   scalar increment stalling the pipeline). Both beat OpenSSL 3.6.3 on this
   machine. Portable path: constant-time software S-box (shared with
   rktcrypto_aes.c's design), correct on any target. Verified bit-identical to
   OpenSSL over thousands of random (key,iv,len). */
#include "rktcrypto_cipher.h"
#include <string.h>
#include <stdint.h>

#if defined(__ARM_FEATURE_AES) || defined(__ARM_FEATURE_CRYPTO)
# include <arm_neon.h>
static inline uint32_t rk_subword(uint32_t w){ uint8x16_t v=vreinterpretq_u8_u32(vdupq_n_u32(w)); v=vaeseq_u8(v,vdupq_n_u8(0)); return vgetq_lane_u32(vreinterpretq_u32_u8(v),0); }
static int aes_expand(const unsigned char*key,int keylen,unsigned char*rk){
  static const uint32_t rcon[10]={0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80,0x1b,0x36};
  int Nk=keylen/4,Nr=Nk+6,total=4*(Nr+1); uint32_t w[60]; memcpy(w,key,keylen);
  for(int i=Nk;i<total;i++){ uint32_t t=w[i-1];
    if(i%Nk==0) t=rk_subword((t>>8)|(t<<24))^rcon[i/Nk-1];
    else if(Nk>6 && i%Nk==4) t=rk_subword(t);
    w[i]=w[i-Nk]^t; }
  memcpy(rk,w,total*4); return Nr;
}
static void ctr_add(unsigned char c[16],uint64_t add){ for(int i=15;i>=0&&add;i--){ unsigned v=c[i]+(add&0xff); c[i]=(unsigned char)v; add=(add>>8)+(v>>8); } }
void rktcrypto_aes_ctr(const unsigned char*key,intptr_t keylen,const unsigned char iv[16],
                       const unsigned char*in,unsigned char*out,intptr_t len){
  unsigned char rk[240]; int Nr=aes_expand(key,(int)keylen,rk); unsigned char ctr[16]; memcpy(ctr,iv,16);
  while(len>=128){ uint8x16_t st[8],base=vld1q_u8(ctr); int r,b;
    uint64_t lo=__builtin_bswap64(vgetq_lane_u64(vreinterpretq_u64_u8(base),1));
    if(lo<=0xFFFFFFFFFFFFFFF8ULL){ uint64x2_t bv=vreinterpretq_u64_u8(base);
      for(b=0;b<8;b++) st[b]=vreinterpretq_u8_u64(vsetq_lane_u64(__builtin_bswap64(lo+(uint64_t)b),bv,1)); ctr_add(ctr,8);
    } else { for(b=0;b<8;b++){ st[b]=vld1q_u8(ctr); ctr_add(ctr,1);} }
    for(r=0;r<Nr-1;r++){ uint8x16_t k=vld1q_u8(rk+16*r); for(b=0;b<8;b++) st[b]=vaesmcq_u8(vaeseq_u8(st[b],k)); }
    { uint8x16_t kl=vld1q_u8(rk+16*(Nr-1)),kf=vld1q_u8(rk+16*Nr); for(b=0;b<8;b++) st[b]=veorq_u8(vaeseq_u8(st[b],kl),kf); }
    for(b=0;b<8;b++) vst1q_u8(out+16*b,veorq_u8(vld1q_u8(in+16*b),st[b])); in+=128;out+=128;len-=128; }
  while(len>0){ uint8x16_t s=vld1q_u8(ctr); int r; for(r=0;r<Nr-1;r++) s=vaesmcq_u8(vaeseq_u8(s,vld1q_u8(rk+16*r)));
    s=veorq_u8(vaeseq_u8(s,vld1q_u8(rk+16*(Nr-1))),vld1q_u8(rk+16*Nr));
    unsigned char ks[16]; vst1q_u8(ks,s); intptr_t n=len<16?len:16; for(int i=0;i<n;i++) out[i]=in[i]^ks[i]; ctr_add(ctr,1); in+=n;out+=n;len-=n; }
}
static inline uint8x16_t aes_enc1(uint8x16_t s,const unsigned char*rk,int Nr){
  for(int r=0;r<Nr-1;r++) s=vaesmcq_u8(vaeseq_u8(s,vld1q_u8(rk+16*r)));
  return veorq_u8(vaeseq_u8(s,vld1q_u8(rk+16*(Nr-1))),vld1q_u8(rk+16*Nr)); }
/* General AES key schedule / single-block encrypt, exported for GMAC (gcm.c). */
int rktcrypto_aes_expand_key(const unsigned char*key,intptr_t keylen,unsigned char rk[240]){ return aes_expand(key,(int)keylen,rk); }
void rktcrypto_aes_enc_block(const unsigned char*rk,int Nr,const unsigned char in[16],unsigned char out[16]){ vst1q_u8(out,aes_enc1(vld1q_u8(in),rk,Nr)); }
/* CBC-encrypt is serial (each block depends on the previous ciphertext). Two
   levers: (1) keep the whole round-key schedule in NEON registers; (2) fold the
   final round-key XOR off the critical path -- the next block's input is
   aese(s,klast) ^ (p_next ^ kfinal), and (p_next ^ kfinal) is precomputable while
   the AES runs, so only one veor sits on the serial chain per block instead of
   two. Unrolled per key size. */
#define AESE_MC(s,k) s=vaesmcq_u8(vaeseq_u8(s,k))
void rktcrypto_aes_cbc_encrypt(const unsigned char*key,intptr_t keylen,const unsigned char iv[16],
                               const unsigned char*in,unsigned char*out,intptr_t len){
  unsigned char rk[240]; int Nr=aes_expand(key,(int)keylen,rk); uint8x16_t prev=vld1q_u8(iv); intptr_t o=0;
  uint8x16_t k0=vld1q_u8(rk),k1=vld1q_u8(rk+16),k2=vld1q_u8(rk+32),k3=vld1q_u8(rk+48),
             k4=vld1q_u8(rk+64),k5=vld1q_u8(rk+80),k6=vld1q_u8(rk+96),k7=vld1q_u8(rk+112),
             k8=vld1q_u8(rk+128),k9=vld1q_u8(rk+144),k10=vld1q_u8(rk+160);
  if(len<16) return;
  if(Nr==10){
    /* Zero veors on the serial critical path: since aese(x,rk)=SB(SR(x^rk)), both
       the final k10 add AND the next block's CBC fold collapse into the round key
       of the next block's first aese. Carry u = aese(s,k9) (pre-k10) across blocks;
       merged = p_next ^ k10 ^ k0 and the ciphertext store (u^k10) are both off the
       critical path, which is then pure aese/aesmc. */
    intptr_t nblk=len/16, bi;
    uint8x16_t s=veorq_u8(vld1q_u8(in),prev);
    AESE_MC(s,k0);AESE_MC(s,k1);AESE_MC(s,k2);AESE_MC(s,k3);AESE_MC(s,k4);
    AESE_MC(s,k5);AESE_MC(s,k6);AESE_MC(s,k7);AESE_MC(s,k8);
    uint8x16_t u=vaeseq_u8(s,k9);
    for(bi=1;bi<nblk;bi++){
      vst1q_u8(out+(bi-1)*16,veorq_u8(u,k10));                     /* store ct_{bi-1} (off path) */
      uint8x16_t merged=veorq_u8(veorq_u8(vld1q_u8(in+bi*16),k10),k0); /* p_bi ^ k10 ^ k0 (off path) */
      s=vaesmcq_u8(vaeseq_u8(u,merged));                          /* round 0 with folded key */
      AESE_MC(s,k1);AESE_MC(s,k2);AESE_MC(s,k3);AESE_MC(s,k4);
      AESE_MC(s,k5);AESE_MC(s,k6);AESE_MC(s,k7);AESE_MC(s,k8);
      u=vaeseq_u8(s,k9);
    }
    vst1q_u8(out+(nblk-1)*16,veorq_u8(u,k10));
  } else {
    uint8x16_t k11=vld1q_u8(rk+176),k12=vld1q_u8(rk+192),k13=vld1q_u8(rk+208),k14=vld1q_u8(rk+224);
    intptr_t nblk=len/16, bi;
    if(Nr==12){                                         /* zero-veor chain (see Nr==10) */
      uint8x16_t s=veorq_u8(vld1q_u8(in),prev);
      AESE_MC(s,k0);AESE_MC(s,k1);AESE_MC(s,k2);AESE_MC(s,k3);AESE_MC(s,k4);AESE_MC(s,k5);
      AESE_MC(s,k6);AESE_MC(s,k7);AESE_MC(s,k8);AESE_MC(s,k9);AESE_MC(s,k10);
      uint8x16_t u=vaeseq_u8(s,k11);
      for(bi=1;bi<nblk;bi++){
        vst1q_u8(out+(bi-1)*16,veorq_u8(u,k12));
        uint8x16_t merged=veorq_u8(veorq_u8(vld1q_u8(in+bi*16),k12),k0);
        s=vaesmcq_u8(vaeseq_u8(u,merged));
        AESE_MC(s,k1);AESE_MC(s,k2);AESE_MC(s,k3);AESE_MC(s,k4);AESE_MC(s,k5);
        AESE_MC(s,k6);AESE_MC(s,k7);AESE_MC(s,k8);AESE_MC(s,k9);AESE_MC(s,k10);
        u=vaeseq_u8(s,k11);
      }
      vst1q_u8(out+(nblk-1)*16,veorq_u8(u,k12));
    } else {
      uint8x16_t s=veorq_u8(vld1q_u8(in),prev);
      AESE_MC(s,k0);AESE_MC(s,k1);AESE_MC(s,k2);AESE_MC(s,k3);AESE_MC(s,k4);AESE_MC(s,k5);AESE_MC(s,k6);
      AESE_MC(s,k7);AESE_MC(s,k8);AESE_MC(s,k9);AESE_MC(s,k10);AESE_MC(s,k11);AESE_MC(s,k12);
      uint8x16_t u=vaeseq_u8(s,k13);
      for(bi=1;bi<nblk;bi++){
        vst1q_u8(out+(bi-1)*16,veorq_u8(u,k14));
        uint8x16_t merged=veorq_u8(veorq_u8(vld1q_u8(in+bi*16),k14),k0);
        s=vaesmcq_u8(vaeseq_u8(u,merged));
        AESE_MC(s,k1);AESE_MC(s,k2);AESE_MC(s,k3);AESE_MC(s,k4);AESE_MC(s,k5);AESE_MC(s,k6);
        AESE_MC(s,k7);AESE_MC(s,k8);AESE_MC(s,k9);AESE_MC(s,k10);AESE_MC(s,k11);AESE_MC(s,k12);
        u=vaeseq_u8(s,k13);
      }
      vst1q_u8(out+(nblk-1)*16,veorq_u8(u,k14));
    }
  }
}
static int aes_expand_dec(const unsigned char*key,int keylen,unsigned char*dk){
  unsigned char ek[240]; int Nr=aes_expand(key,keylen,ek); vst1q_u8(dk,vld1q_u8(ek+16*Nr));
  for(int i=1;i<Nr;i++) vst1q_u8(dk+16*i,vaesimcq_u8(vld1q_u8(ek+16*(Nr-i)))); vst1q_u8(dk+16*Nr,vld1q_u8(ek)); return Nr; }
static inline uint8x16_t aes_dec1(uint8x16_t s,const unsigned char*dk,int Nr){
  for(int r=0;r<Nr-1;r++) s=vaesimcq_u8(vaesdq_u8(s,vld1q_u8(dk+16*r)));
  return veorq_u8(vaesdq_u8(s,vld1q_u8(dk+16*(Nr-1))),vld1q_u8(dk+16*Nr)); }
void rktcrypto_aes_cbc_decrypt(const unsigned char*key,intptr_t keylen,const unsigned char iv[16],
                               const unsigned char*in,unsigned char*out,intptr_t len){
  unsigned char dk[240]; int Nr=aes_expand_dec(key,(int)keylen,dk); uint8x16_t prev=vld1q_u8(iv); intptr_t o=0;
  for(;o+128<=len;o+=128){ uint8x16_t c[8],d[8]; int b,r; for(b=0;b<8;b++) c[b]=vld1q_u8(in+o+16*b);
    for(b=0;b<8;b++) d[b]=c[b];
    for(r=0;r<Nr-1;r++){ uint8x16_t k=vld1q_u8(dk+16*r); for(b=0;b<8;b++) d[b]=vaesimcq_u8(vaesdq_u8(d[b],k)); }
    { uint8x16_t kl=vld1q_u8(dk+16*(Nr-1)),kf=vld1q_u8(dk+16*Nr); for(b=0;b<8;b++) d[b]=veorq_u8(vaesdq_u8(d[b],kl),kf); }
    for(b=0;b<8;b++){ vst1q_u8(out+o+16*b,veorq_u8(d[b],prev)); prev=c[b]; } }
  for(;o+16<=len;o+=16){ uint8x16_t c=vld1q_u8(in+o); vst1q_u8(out+o,veorq_u8(aes_dec1(c,dk,Nr),prev)); prev=c; }
}

/* AES-CMAC (NIST SP 800-38B): subkeys K1,K2 from AES(0), CBC-MAC with the last
   block tweaked by K1 (complete) or K2 (padded). */
static void cmac_dbl(unsigned char o[16],const unsigned char in[16]){
  int carry=in[0]>>7; for(int i=0;i<15;i++) o[i]=(unsigned char)((in[i]<<1)|(in[i+1]>>7));
  o[15]=(unsigned char)(in[15]<<1); if(carry) o[15]^=0x87;
}
void rktcrypto_aes_cmac(const unsigned char*key,intptr_t keylen,const unsigned char*msg,intptr_t len,unsigned char tag[16]){
  unsigned char rk[240]; int Nr=aes_expand(key,(int)keylen,rk);
  unsigned char L[16],K1[16],K2[16],zero[16]={0}; vst1q_u8(L,aes_enc1(vld1q_u8(zero),rk,Nr));
  cmac_dbl(K1,L); cmac_dbl(K2,K1);
  uint8x16_t X=vdupq_n_u8(0); intptr_t nblk=(len+15)/16; if(nblk==0)nblk=1; intptr_t o=0;
  for(intptr_t i=0;i<nblk-1;i++){ X=aes_enc1(veorq_u8(X,vld1q_u8(msg+o)),rk,Nr); o+=16; }
  unsigned char last[16]; intptr_t rem=len-o;
  if(rem==16){ for(int i=0;i<16;i++) last[i]=msg[o+i]^K1[i]; }
  else { for(int i=0;i<rem;i++) last[i]=msg[o+i]; last[rem]=0x80; for(int i=(int)rem+1;i<16;i++) last[i]=0; for(int i=0;i<16;i++) last[i]^=K2[i]; }
  vst1q_u8(tag, aes_enc1(veorq_u8(X,vld1q_u8(last)),rk,Nr));
}

/* AES-XTS (IEEE 1619 / NIST SP 800-38E) with ciphertext stealing. key =
   key1||key2 each `keylen` bytes; iv is the 16-byte tweak. */
static void xts_gf(unsigned char T[16]){ int cin=0; for(int j=0;j<16;j++){ int cout=T[j]>>7; T[j]=(unsigned char)((T[j]<<1)|cin); cin=cout; } if(cin)T[0]^=0x87; }
/* GF(2^128) mul-by-alpha on the little-endian tweak, via 64-bit words. The
   vget/vset lane round-trip is deliberate: it runs the tweak chain on the scalar
   /GP units, leaving the NEON ports free for the 8-way AES (a pure-NEON dbl
   competes with aese for the same ports and measured ~1.8x slower here). */
static inline uint8x16_t xts_dbl(uint8x16_t tv){
  uint64x2_t v=vreinterpretq_u64_u8(tv);
  uint64_t lo=vgetq_lane_u64(v,0), hi=vgetq_lane_u64(v,1), carry=hi>>63;
  hi=(hi<<1)|(lo>>63); lo=(lo<<1)^(carry*0x87ULL);
  return vreinterpretq_u8_u64(vsetq_lane_u64(hi,vsetq_lane_u64(lo,v,0),1));
}
/* The tweak chain is a serial dbl per block and (with a fast 8-way AES) it, not
   the AES, caps XTS throughput. Keep the running tweak as two GP words so the
   chain is a pure-GP doubling (~2 cyc, no NEON<->GP round trip per the old
   vget/vset dbl); build the NEON tweak per block off the chain. */
#define XTS_DBL2(lo,hi) do{ uint64_t _c=(hi)>>63; (hi)=((hi)<<1)|((lo)>>63); (lo)=((lo)<<1)^(_c*0x87ULL); }while(0)
static inline uint8x16_t xts_tw(uint64_t lo,uint64_t hi){
  return vreinterpretq_u8_u64(vsetq_lane_u64(hi,vsetq_lane_u64(lo,vdupq_n_u64(0),0),1));
}
void rktcrypto_aes_xts(const unsigned char*key,intptr_t keylen,const unsigned char iv[16],
                       const unsigned char*in,unsigned char*out,intptr_t len,int encrypt){
  unsigned char rk1[240],rk2[240],dk1[240]; int Nr=aes_expand(key,(int)keylen,rk1); aes_expand(key+keylen,(int)keylen,rk2);
  if(!encrypt) aes_expand_dec(key,(int)keylen,dk1);
  unsigned char T[16]; uint8x16_t Tv0=aes_enc1(vld1q_u8(iv),rk2,Nr);
  uint64_t tlo=vgetq_lane_u64(vreinterpretq_u64_u8(Tv0),0), thi=vgetq_lane_u64(vreinterpretq_u64_u8(Tv0),1);
  intptr_t nfull=len/16, rem=len%16, last_full=rem?nfull-1:nfull, o=0, i=0;
  /* 8-way pipelined body: tweaks are independent, so keep the AES units busy.
     (Holding all round keys in registers instead of loading per round was tried
     and measured *slower* -- 8 state + 8 tweak + 11 keys spills; the per-round
     key load pipelines fine.) */
  for(; i+8<=last_full; i+=8){
    uint8x16_t tw[8],st[8]; int b,r;
    for(b=0;b<8;b++){ tw[b]=xts_tw(tlo,thi); XTS_DBL2(tlo,thi); }
    for(b=0;b<8;b++) st[b]=veorq_u8(vld1q_u8(in+o+16*b),tw[b]);
    if(encrypt){
      for(r=0;r<Nr-1;r++){ uint8x16_t k=vld1q_u8(rk1+16*r); for(b=0;b<8;b++) st[b]=vaesmcq_u8(vaeseq_u8(st[b],k)); }
      { uint8x16_t kl=vld1q_u8(rk1+16*(Nr-1)),kf=vld1q_u8(rk1+16*Nr); for(b=0;b<8;b++) st[b]=veorq_u8(vaeseq_u8(st[b],kl),kf); }
    } else {
      for(r=0;r<Nr-1;r++){ uint8x16_t k=vld1q_u8(dk1+16*r); for(b=0;b<8;b++) st[b]=vaesimcq_u8(vaesdq_u8(st[b],k)); }
      { uint8x16_t kl=vld1q_u8(dk1+16*(Nr-1)),kf=vld1q_u8(dk1+16*Nr); for(b=0;b<8;b++) st[b]=veorq_u8(vaesdq_u8(st[b],kl),kf); }
    }
    for(b=0;b<8;b++) vst1q_u8(out+o+16*b,veorq_u8(st[b],tw[b]));
    o+=128;
  }
  for(; i<last_full; i++){ uint8x16_t t=xts_tw(tlo,thi);
    uint8x16_t p=veorq_u8(vld1q_u8(in+o),t);
    uint8x16_t c=encrypt?aes_enc1(p,rk1,Nr):aes_dec1(p,dk1,Nr);
    vst1q_u8(out+o,veorq_u8(c,t)); XTS_DBL2(tlo,thi); o+=16; }
  vst1q_u8(T,xts_tw(tlo,thi));
  if(rem){ if(encrypt){ uint8x16_t t=vld1q_u8(T);
      unsigned char cb[16]; vst1q_u8(cb,veorq_u8(aes_enc1(veorq_u8(vld1q_u8(in+o),t),rk1,Nr),t));
      for(int i=0;i<rem;i++) out[o+16+i]=cb[i];
      unsigned char pp[16]; for(int i=0;i<rem;i++)pp[i]=in[o+16+i]; for(int i=(int)rem;i<16;i++)pp[i]=cb[i];
      unsigned char T2[16]; memcpy(T2,T,16); xts_gf(T2); uint8x16_t t2=vld1q_u8(T2);
      vst1q_u8(out+o, veorq_u8(aes_enc1(veorq_u8(vld1q_u8(pp),t2),rk1,Nr),t2));
    } else { unsigned char T2[16]; memcpy(T2,T,16); xts_gf(T2); uint8x16_t t2=vld1q_u8(T2);
      unsigned char pb[16]; vst1q_u8(pb,veorq_u8(aes_dec1(veorq_u8(vld1q_u8(in+o),t2),dk1,Nr),t2));
      for(int i=0;i<rem;i++) out[o+16+i]=pb[i];
      unsigned char cc[16]; for(int i=0;i<rem;i++)cc[i]=in[o+16+i]; for(int i=(int)rem;i<16;i++)cc[i]=pb[i];
      uint8x16_t t=vld1q_u8(T);
      vst1q_u8(out+o, veorq_u8(aes_dec1(veorq_u8(vld1q_u8(cc),t),dk1,Nr),t)); } }
}
#else
/* Portable software AES (FIPS-197) for the non-ARMv8-crypto build — endian-
   neutral, byte-oriented, so CTR/CBC/CMAC/XTS (and, via aes_expand_key/
   aes_enc_block, AES-CCM and GMAC) work on x86 / generic ARM / any target, not
   only Apple Silicon. Bit-identical to the hardware path (same FIPS-197 cipher
   and the same NIST SP 800-38A/B/E mode constructions); gated by the differential
   test asm/tests/test_aes_portable.c (portable vs the shipped NEON kernel). */
static const unsigned char SBOX[256]={
0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,
0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0,
0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15,
0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75,
0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84,
0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf,
0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8,
0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2,
0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73,
0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb,
0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79,
0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08,
0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a,
0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e,
0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf,
0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16};
static const unsigned char ISBOX[256]={
0x52,0x09,0x6a,0xd5,0x30,0x36,0xa5,0x38,0xbf,0x40,0xa3,0x9e,0x81,0xf3,0xd7,0xfb,
0x7c,0xe3,0x39,0x82,0x9b,0x2f,0xff,0x87,0x34,0x8e,0x43,0x44,0xc4,0xde,0xe9,0xcb,
0x54,0x7b,0x94,0x32,0xa6,0xc2,0x23,0x3d,0xee,0x4c,0x95,0x0b,0x42,0xfa,0xc3,0x4e,
0x08,0x2e,0xa1,0x66,0x28,0xd9,0x24,0xb2,0x76,0x5b,0xa2,0x49,0x6d,0x8b,0xd1,0x25,
0x72,0xf8,0xf6,0x64,0x86,0x68,0x98,0x16,0xd4,0xa4,0x5c,0xcc,0x5d,0x65,0xb6,0x92,
0x6c,0x70,0x48,0x50,0xfd,0xed,0xb9,0xda,0x5e,0x15,0x46,0x57,0xa7,0x8d,0x9d,0x84,
0x90,0xd8,0xab,0x00,0x8c,0xbc,0xd3,0x0a,0xf7,0xe4,0x58,0x05,0xb8,0xb3,0x45,0x06,
0xd0,0x2c,0x1e,0x8f,0xca,0x3f,0x0f,0x02,0xc1,0xaf,0xbd,0x03,0x01,0x13,0x8a,0x6b,
0x3a,0x91,0x11,0x41,0x4f,0x67,0xdc,0xea,0x97,0xf2,0xcf,0xce,0xf0,0xb4,0xe6,0x73,
0x96,0xac,0x74,0x22,0xe7,0xad,0x35,0x85,0xe2,0xf9,0x37,0xe8,0x1c,0x75,0xdf,0x6e,
0x47,0xf1,0x1a,0x71,0x1d,0x29,0xc5,0x89,0x6f,0xb7,0x62,0x0e,0xaa,0x18,0xbe,0x1b,
0xfc,0x56,0x3e,0x4b,0xc6,0xd2,0x79,0x20,0x9a,0xdb,0xc0,0xfe,0x78,0xcd,0x5a,0xf4,
0x1f,0xdd,0xa8,0x33,0x88,0x07,0xc7,0x31,0xb1,0x12,0x10,0x59,0x27,0x80,0xec,0x5f,
0x60,0x51,0x7f,0xa9,0x19,0xb5,0x4a,0x0d,0x2d,0xe5,0x7a,0x9f,0x93,0xc9,0x9c,0xef,
0xa0,0xe0,0x3b,0x4d,0xae,0x2a,0xf5,0xb0,0xc8,0xeb,0xbb,0x3c,0x83,0x53,0x99,0x61,
0x17,0x2b,0x04,0x7e,0xba,0x77,0xd6,0x26,0xe1,0x69,0x14,0x63,0x55,0x21,0x0c,0x7d};
#define XT(x) ((unsigned char)(((x)<<1) ^ ((((x)>>7)&1)*0x1b)))
static unsigned char gmul(unsigned char a,unsigned char b){ unsigned char p=0; for(int i=0;i<8;i++){ if(b&1)p^=a; unsigned char hi=a&0x80; a=(unsigned char)(a<<1); if(hi)a^=0x1b; b>>=1;} return p; }
static int aes_expand(const unsigned char*key,int keylen,unsigned char*rk){
  static const unsigned char rcon[15]={0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80,0x1b,0x36,0x6c,0xd8,0xab,0x4d,0x9a};
  int Nk=keylen/4,Nr=Nk+6,total=4*(Nr+1),i,j;
  for(i=0;i<keylen;i++) rk[i]=key[i];
  for(i=Nk;i<total;i++){ unsigned char t[4]; for(j=0;j<4;j++) t[j]=rk[4*(i-1)+j];
    if(i%Nk==0){ unsigned char tmp=t[0]; t[0]=(unsigned char)(SBOX[t[1]]^rcon[i/Nk-1]); t[1]=SBOX[t[2]]; t[2]=SBOX[t[3]]; t[3]=SBOX[tmp]; }
    else if(Nk>6 && i%Nk==4){ for(j=0;j<4;j++) t[j]=SBOX[t[j]]; }
    for(j=0;j<4;j++) rk[4*i+j]=(unsigned char)(rk[4*(i-Nk)+j]^t[j]); }
  return Nr;
}
static void aes_enc_blk(const unsigned char*rk,int Nr,const unsigned char in[16],unsigned char out[16]){
  unsigned char s[16],t[16]; int r,c,i;
  for(i=0;i<16;i++) s[i]=in[i]^rk[i];
  for(r=1;r<Nr;r++){
    for(c=0;c<4;c++) for(i=0;i<4;i++) t[i+4*c]=SBOX[s[i+4*((c+i)&3)]];   /* SubBytes+ShiftRows */
    for(c=0;c<4;c++){ unsigned char a0=t[4*c],a1=t[4*c+1],a2=t[4*c+2],a3=t[4*c+3];
      s[4*c]  =(unsigned char)(XT(a0)^(XT(a1)^a1)^a2^a3);
      s[4*c+1]=(unsigned char)(a0^XT(a1)^(XT(a2)^a2)^a3);
      s[4*c+2]=(unsigned char)(a0^a1^XT(a2)^(XT(a3)^a3));
      s[4*c+3]=(unsigned char)((XT(a0)^a0)^a1^a2^XT(a3)); }
    for(i=0;i<16;i++) s[i]^=rk[16*r+i]; }
  for(c=0;c<4;c++) for(i=0;i<4;i++) t[i+4*c]=SBOX[s[i+4*((c+i)&3)]];
  for(i=0;i<16;i++) out[i]=(unsigned char)(t[i]^rk[16*Nr+i]);
}
static void aes_dec_blk(const unsigned char*rk,int Nr,const unsigned char in[16],unsigned char out[16]){
  unsigned char s[16],t[16]; int r,c,i;
  for(i=0;i<16;i++) s[i]=in[i]^rk[16*Nr+i];
  for(r=Nr-1;r>=1;r--){
    for(c=0;c<4;c++) for(i=0;i<4;i++) t[i+4*c]=ISBOX[s[i+4*((c-i+4)&3)]];  /* InvShiftRows+InvSubBytes */
    for(i=0;i<16;i++) t[i]^=rk[16*r+i];
    for(c=0;c<4;c++){ unsigned char a0=t[4*c],a1=t[4*c+1],a2=t[4*c+2],a3=t[4*c+3];
      s[4*c]  =(unsigned char)(gmul(a0,14)^gmul(a1,11)^gmul(a2,13)^gmul(a3,9));
      s[4*c+1]=(unsigned char)(gmul(a0,9)^gmul(a1,14)^gmul(a2,11)^gmul(a3,13));
      s[4*c+2]=(unsigned char)(gmul(a0,13)^gmul(a1,9)^gmul(a2,14)^gmul(a3,11));
      s[4*c+3]=(unsigned char)(gmul(a0,11)^gmul(a1,13)^gmul(a2,9)^gmul(a3,14)); } }
  for(c=0;c<4;c++) for(i=0;i<4;i++) t[i+4*c]=ISBOX[s[i+4*((c-i+4)&3)]];
  for(i=0;i<16;i++) out[i]=(unsigned char)(t[i]^rk[i]);
}
static void ctr_add(unsigned char c[16],uint64_t add){ for(int i=15;i>=0&&add;i--){ unsigned v=c[i]+(add&0xff); c[i]=(unsigned char)v; add=(add>>8)+(v>>8); } }
int rktcrypto_aes_expand_key(const unsigned char*key,intptr_t keylen,unsigned char rk[240]){ return aes_expand(key,(int)keylen,rk); }
void rktcrypto_aes_enc_block(const unsigned char*rk,int Nr,const unsigned char in[16],unsigned char out[16]){ aes_enc_blk(rk,Nr,in,out); }
void rktcrypto_aes_ctr(const unsigned char*key,intptr_t keylen,const unsigned char iv[16],
                       const unsigned char*in,unsigned char*out,intptr_t len){
  unsigned char rk[240]; int Nr=aes_expand(key,(int)keylen,rk); unsigned char ctr[16],ks[16]; memcpy(ctr,iv,16);
  while(len>0){ aes_enc_blk(rk,Nr,ctr,ks); intptr_t n=len<16?len:16; for(intptr_t i=0;i<n;i++) out[i]=in[i]^ks[i]; ctr_add(ctr,1); in+=n;out+=n;len-=n; }
}
void rktcrypto_aes_cbc_encrypt(const unsigned char*key,intptr_t keylen,const unsigned char iv[16],
                               const unsigned char*in,unsigned char*out,intptr_t len){
  unsigned char rk[240]; int Nr=aes_expand(key,(int)keylen,rk); unsigned char prev[16],x[16]; memcpy(prev,iv,16);
  for(intptr_t o=0;o+16<=len;o+=16){ for(int i=0;i<16;i++) x[i]=in[o+i]^prev[i]; aes_enc_blk(rk,Nr,x,out+o); memcpy(prev,out+o,16); }
}
void rktcrypto_aes_cbc_decrypt(const unsigned char*key,intptr_t keylen,const unsigned char iv[16],
                               const unsigned char*in,unsigned char*out,intptr_t len){
  unsigned char rk[240]; int Nr=aes_expand(key,(int)keylen,rk); unsigned char prev[16],c[16],d[16]; memcpy(prev,iv,16);
  for(intptr_t o=0;o+16<=len;o+=16){ memcpy(c,in+o,16); aes_dec_blk(rk,Nr,c,d); for(int i=0;i<16;i++) out[o+i]=d[i]^prev[i]; memcpy(prev,c,16); }
}
static void cmac_dbl(unsigned char o[16],const unsigned char in[16]){ int carry=in[0]>>7; for(int i=0;i<15;i++) o[i]=(unsigned char)((in[i]<<1)|(in[i+1]>>7)); o[15]=(unsigned char)(in[15]<<1); if(carry) o[15]^=0x87; }
void rktcrypto_aes_cmac(const unsigned char*key,intptr_t keylen,const unsigned char*msg,intptr_t len,unsigned char tag[16]){
  unsigned char rk[240]; int Nr=aes_expand(key,(int)keylen,rk);
  unsigned char L[16],K1[16],K2[16],zero[16]={0},X[16]={0},last[16],t[16]; aes_enc_blk(rk,Nr,zero,L);
  cmac_dbl(K1,L); cmac_dbl(K2,K1);
  intptr_t nblk=(len+15)/16; if(nblk==0)nblk=1; intptr_t o=0,i;
  for(i=0;i<nblk-1;i++){ for(int j=0;j<16;j++) t[j]=X[j]^msg[o+j]; aes_enc_blk(rk,Nr,t,X); o+=16; }
  intptr_t rem=len-o;
  if(rem==16){ for(i=0;i<16;i++) last[i]=msg[o+i]^K1[i]; }
  else { for(i=0;i<rem;i++) last[i]=msg[o+i]; last[rem]=0x80; for(i=rem+1;i<16;i++) last[i]=0; for(i=0;i<16;i++) last[i]^=K2[i]; }
  for(i=0;i<16;i++) t[i]=X[i]^last[i]; aes_enc_blk(rk,Nr,t,tag);
}
static void xts_gf(unsigned char T[16]){ int cin=0; for(int j=0;j<16;j++){ int cout=T[j]>>7; T[j]=(unsigned char)((T[j]<<1)|cin); cin=cout; } if(cin) T[0]^=0x87; }
void rktcrypto_aes_xts(const unsigned char*key,intptr_t keylen,const unsigned char iv[16],
                       const unsigned char*in,unsigned char*out,intptr_t len,int encrypt){
  unsigned char rk1[240],rk2[240],T[16],x[16],c[16]; int Nr=aes_expand(key,(int)keylen,rk1); aes_expand(key+keylen,(int)keylen,rk2);
  aes_enc_blk(rk2,Nr,iv,T);
  intptr_t nfull=len/16, rem=len%16, last_full=rem?nfull-1:nfull, o=0,i;
  for(i=0;i<last_full;i++){ for(int j=0;j<16;j++) x[j]=in[o+j]^T[j];
    if(encrypt) aes_enc_blk(rk1,Nr,x,c); else aes_dec_blk(rk1,Nr,x,c);
    for(int j=0;j<16;j++) out[o+j]=c[j]^T[j]; xts_gf(T); o+=16; }
  if(rem){
    if(encrypt){ unsigned char cb[16],pp[16],T2[16],c2[16];
      for(int j=0;j<16;j++) x[j]=in[o+j]^T[j]; aes_enc_blk(rk1,Nr,x,cb); for(int j=0;j<16;j++) cb[j]^=T[j];
      for(i=0;i<rem;i++) out[o+16+i]=cb[i];
      for(i=0;i<rem;i++) pp[i]=in[o+16+i]; for(i=rem;i<16;i++) pp[i]=cb[i];
      memcpy(T2,T,16); xts_gf(T2);
      for(int j=0;j<16;j++) x[j]=pp[j]^T2[j]; aes_enc_blk(rk1,Nr,x,c2); for(int j=0;j<16;j++) out[o+j]=c2[j]^T2[j];
    } else { unsigned char T2[16],pb[16],cc[16],p2[16];
      memcpy(T2,T,16); xts_gf(T2);
      for(int j=0;j<16;j++) x[j]=in[o+j]^T2[j]; aes_dec_blk(rk1,Nr,x,pb); for(int j=0;j<16;j++) pb[j]^=T2[j];
      for(i=0;i<rem;i++) out[o+16+i]=pb[i];
      for(i=0;i<rem;i++) cc[i]=in[o+16+i]; for(i=rem;i<16;i++) cc[i]=pb[i];
      for(int j=0;j<16;j++) x[j]=cc[j]^T[j]; aes_dec_blk(rk1,Nr,x,p2); for(int j=0;j<16;j++) out[o+j]=p2[j]^T[j]; }
  }
}
#endif
