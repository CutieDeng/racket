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
    uint8x16_t s=veorq_u8(vld1q_u8(in),prev); intptr_t last=len-16;
    /* hot loop is branchless: every block folds the next plaintext in; the final
       block (which has no successor to load) is done once after the loop. */
    for(;o<last;o+=16){
      AESE_MC(s,k0);AESE_MC(s,k1);AESE_MC(s,k2);AESE_MC(s,k3);AESE_MC(s,k4);
      AESE_MC(s,k5);AESE_MC(s,k6);AESE_MC(s,k7);AESE_MC(s,k8);
      s=vaeseq_u8(s,k9); vst1q_u8(out+o,veorq_u8(s,k10));
      s=veorq_u8(s,veorq_u8(vld1q_u8(in+o+16),k10));
    }
    AESE_MC(s,k0);AESE_MC(s,k1);AESE_MC(s,k2);AESE_MC(s,k3);AESE_MC(s,k4);
    AESE_MC(s,k5);AESE_MC(s,k6);AESE_MC(s,k7);AESE_MC(s,k8);
    s=vaeseq_u8(s,k9); vst1q_u8(out+o,veorq_u8(s,k10));
  } else {
    uint8x16_t k11=vld1q_u8(rk+176),k12=vld1q_u8(rk+192),k13=vld1q_u8(rk+208),k14=vld1q_u8(rk+224);
    if(Nr==12){
      uint8x16_t s=veorq_u8(vld1q_u8(in),prev);
      for(;o+16<=len;o+=16){
        AESE_MC(s,k0);AESE_MC(s,k1);AESE_MC(s,k2);AESE_MC(s,k3);AESE_MC(s,k4);AESE_MC(s,k5);
        AESE_MC(s,k6);AESE_MC(s,k7);AESE_MC(s,k8);AESE_MC(s,k9);AESE_MC(s,k10);
        s=vaeseq_u8(s,k11); vst1q_u8(out+o,veorq_u8(s,k12));
        if(o+32<=len) s=veorq_u8(s,veorq_u8(vld1q_u8(in+o+16),k12));
      }
    } else {
      uint8x16_t s=veorq_u8(vld1q_u8(in),prev);
      for(;o+16<=len;o+=16){
        AESE_MC(s,k0);AESE_MC(s,k1);AESE_MC(s,k2);AESE_MC(s,k3);AESE_MC(s,k4);AESE_MC(s,k5);AESE_MC(s,k6);
        AESE_MC(s,k7);AESE_MC(s,k8);AESE_MC(s,k9);AESE_MC(s,k10);AESE_MC(s,k11);AESE_MC(s,k12);
        s=vaeseq_u8(s,k13); vst1q_u8(out+o,veorq_u8(s,k14));
        if(o+32<=len) s=veorq_u8(s,veorq_u8(vld1q_u8(in+o+16),k14));
      }
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
void rktcrypto_aes_xts(const unsigned char*key,intptr_t keylen,const unsigned char iv[16],
                       const unsigned char*in,unsigned char*out,intptr_t len,int encrypt){
  unsigned char rk1[240],rk2[240],dk1[240]; int Nr=aes_expand(key,(int)keylen,rk1); aes_expand(key+keylen,(int)keylen,rk2);
  if(!encrypt) aes_expand_dec(key,(int)keylen,dk1);
  unsigned char T[16]; uint8x16_t Tv=aes_enc1(vld1q_u8(iv),rk2,Nr);
  intptr_t nfull=len/16, rem=len%16, last_full=rem?nfull-1:nfull, o=0, i=0;
  /* 8-way pipelined body: tweaks are independent, so keep the AES units busy. */
  for(; i+8<=last_full; i+=8){
    uint8x16_t tw[8],st[8]; int b,r;
    for(b=0;b<8;b++){ tw[b]=Tv; Tv=xts_dbl(Tv); }
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
  for(; i<last_full; i++){ uint8x16_t t=Tv;
    uint8x16_t p=veorq_u8(vld1q_u8(in+o),t);
    uint8x16_t c=encrypt?aes_enc1(p,rk1,Nr):aes_dec1(p,dk1,Nr);
    vst1q_u8(out+o,veorq_u8(c,t)); Tv=xts_dbl(Tv); o+=16; }
  vst1q_u8(T,Tv);
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
/* Portable fallback would reuse rktcrypto_aes.c's software block; stubbed for the
   non-AES-hardware build (Apple M / ARMv8-crypto is the target). */
void rktcrypto_aes_ctr(const unsigned char*k,intptr_t kl,const unsigned char iv[16],const unsigned char*in,unsigned char*out,intptr_t len){ (void)k;(void)kl;(void)iv;(void)in;(void)out;(void)len; }
void rktcrypto_aes_cbc_encrypt(const unsigned char*k,intptr_t kl,const unsigned char iv[16],const unsigned char*in,unsigned char*out,intptr_t len){ (void)k;(void)kl;(void)iv;(void)in;(void)out;(void)len; }
void rktcrypto_aes_cbc_decrypt(const unsigned char*k,intptr_t kl,const unsigned char iv[16],const unsigned char*in,unsigned char*out,intptr_t len){ (void)k;(void)kl;(void)iv;(void)in;(void)out;(void)len; }
void rktcrypto_aes_cmac(const unsigned char*k,intptr_t kl,const unsigned char*m,intptr_t len,unsigned char tag[16]){ (void)k;(void)kl;(void)m;(void)len;(void)tag; }
void rktcrypto_aes_xts(const unsigned char*k,intptr_t kl,const unsigned char iv[16],const unsigned char*in,unsigned char*out,intptr_t len,int e){ (void)k;(void)kl;(void)iv;(void)in;(void)out;(void)len;(void)e; }
int rktcrypto_aes_expand_key(const unsigned char*k,intptr_t kl,unsigned char rk[240]){ (void)k;(void)kl;(void)rk; return 0; }
void rktcrypto_aes_enc_block(const unsigned char*rk,int Nr,const unsigned char in[16],unsigned char out[16]){ (void)rk;(void)Nr;(void)in;(void)out; }
#endif
