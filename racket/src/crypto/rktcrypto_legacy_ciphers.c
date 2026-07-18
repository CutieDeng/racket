/* Legacy ciphers: Triple-DES (FIPS 46-3, EDE) and RC4 (Rivest's cipher 4).

   Both are legacy and cryptographically weak -- 3DES has a 64-bit block
   (Sweet32) and RC4 has biased keystream. They exist only so code paths
   that must interoperate with old protocols and file formats need no
   external library. From scratch, no external code; NOT for new designs. */

#include "rktcrypto_cipher.h"
#include <string.h>
#include <stdint.h>

/* ============================ DES / 3DES ============================ */
/* FIPS bit numbering: bit 1 is the most significant bit of the block. */

static const unsigned char DES_IP[64]={58,50,42,34,26,18,10,2,60,52,44,36,28,20,12,4,62,54,46,38,30,22,14,6,64,56,48,40,32,24,16,8,57,49,41,33,25,17,9,1,59,51,43,35,27,19,11,3,61,53,45,37,29,21,13,5,63,55,47,39,31,23,15,7};
static const unsigned char DES_FP[64]={40,8,48,16,56,24,64,32,39,7,47,15,55,23,63,31,38,6,46,14,54,22,62,30,37,5,45,13,53,21,61,29,36,4,44,12,52,20,60,28,35,3,43,11,51,19,59,27,34,2,42,10,50,18,58,26,33,1,41,9,49,17,57,25};
static const unsigned char DES_E[48]={32,1,2,3,4,5,4,5,6,7,8,9,8,9,10,11,12,13,12,13,14,15,16,17,16,17,18,19,20,21,20,21,22,23,24,25,24,25,26,27,28,29,28,29,30,31,32,1};
static const unsigned char DES_P[32]={16,7,20,21,29,12,28,17,1,15,23,26,5,18,31,10,2,8,24,14,32,27,3,9,19,13,30,6,22,11,4,25};
static const unsigned char DES_PC1[56]={57,49,41,33,25,17,9,1,58,50,42,34,26,18,10,2,59,51,43,35,27,19,11,3,60,52,44,36,63,55,47,39,31,23,15,7,62,54,46,38,30,22,14,6,61,53,45,37,29,21,13,5,28,20,12,4};
static const unsigned char DES_PC2[48]={14,17,11,24,1,5,3,28,15,6,21,10,23,19,12,4,26,8,16,7,27,20,13,2,41,52,31,37,47,55,30,40,51,45,33,48,44,49,39,56,34,53,46,42,50,36,29,32};
static const unsigned char DES_SH[16]={1,1,2,2,2,2,2,2,1,2,2,2,2,2,2,1};
static const unsigned char DES_S[8][64]={
{14,4,13,1,2,15,11,8,3,10,6,12,5,9,0,7,0,15,7,4,14,2,13,1,10,6,12,11,9,5,3,8,4,1,14,8,13,6,2,11,15,12,9,7,3,10,5,0,15,12,8,2,4,9,1,7,5,11,3,14,10,0,6,13},
{15,1,8,14,6,11,3,4,9,7,2,13,12,0,5,10,3,13,4,7,15,2,8,14,12,0,1,10,6,9,11,5,0,14,7,11,10,4,13,1,5,8,12,6,9,3,2,15,13,8,10,1,3,15,4,2,11,6,7,12,0,5,14,9},
{10,0,9,14,6,3,15,5,1,13,12,7,11,4,2,8,13,7,0,9,3,4,6,10,2,8,5,14,12,11,15,1,13,6,4,9,8,15,3,0,11,1,2,12,5,10,14,7,1,10,13,0,6,9,8,7,4,15,14,3,11,5,2,12},
{7,13,14,3,0,6,9,10,1,2,8,5,11,12,4,15,13,8,11,5,6,15,0,3,4,7,2,12,1,10,14,9,10,6,9,0,12,11,7,13,15,1,3,14,5,2,8,4,3,15,0,6,10,1,13,8,9,4,5,11,12,7,2,14},
{2,12,4,1,7,10,11,6,8,5,3,15,13,0,14,9,14,11,2,12,4,7,13,1,5,0,15,10,3,9,8,6,4,2,1,11,10,13,7,8,15,9,12,5,6,3,0,14,11,8,12,7,1,14,2,13,6,15,0,9,10,4,5,3},
{12,1,10,15,9,2,6,8,0,13,3,4,14,7,5,11,10,15,4,2,7,12,9,5,6,1,13,14,0,11,3,8,9,14,15,5,2,8,12,3,7,0,4,10,1,13,11,6,4,3,2,12,9,5,15,10,11,14,1,7,6,0,8,13},
{4,11,2,14,15,0,8,13,3,12,9,7,5,10,6,1,13,0,11,7,4,9,1,10,14,3,5,12,2,15,8,6,1,4,11,13,12,3,7,14,10,15,6,8,0,5,9,2,6,11,13,8,1,4,10,7,9,5,0,15,14,2,3,12},
{13,2,8,4,6,15,11,1,10,9,3,14,5,0,12,7,1,15,13,8,10,3,7,4,12,5,6,11,0,14,9,2,7,11,4,1,9,12,14,2,0,6,10,13,15,3,5,8,2,1,14,7,4,10,8,13,15,12,9,0,3,5,6,11}};

static uint64_t des_perm(uint64_t in, const unsigned char *tab, int n, int inbits){
  uint64_t o=0; int i;
  for(i=0;i<n;i++){ o=(o<<1)|((in>>(inbits-tab[i]))&1); }
  return o;
}

static void des_schedule(const unsigned char k[8], uint64_t sk[16]){
  uint64_t key=0, cd; uint32_t C,D; int r;
  { int i; for(i=0;i<8;i++) key=(key<<8)|k[i]; }
  cd=des_perm(key,DES_PC1,56,64); C=(cd>>28)&0xFFFFFFF; D=cd&0xFFFFFFF;
  for(r=0;r<16;r++){ int s=DES_SH[r];
    C=((C<<s)|(C>>(28-s)))&0xFFFFFFF; D=((D<<s)|(D>>(28-s)))&0xFFFFFFF;
    sk[r]=des_perm(((uint64_t)C<<28)|D,DES_PC2,48,56); }
}

static uint32_t des_feistel(uint32_t R, uint64_t k){
  uint64_t e=des_perm(R,DES_E,48,32)^k; uint32_t out=0; int i;
  for(i=0;i<8;i++){ int six=(e>>(42-6*i))&0x3F; int row=((six>>5)<<1)|(six&1); int col=(six>>1)&0xF;
    out=(out<<4)|DES_S[i][row*16+col]; }
  return (uint32_t)des_perm(out,DES_P,32,32);
}

static void des_block(const uint64_t sk[16], const unsigned char in[8], unsigned char out[8], int enc){
  uint64_t b=0,pre,o; uint32_t L,R; int i,r;
  for(i=0;i<8;i++) b=(b<<8)|in[i];
  b=des_perm(b,DES_IP,64,64); L=b>>32; R=b&0xFFFFFFFF;
  for(r=0;r<16;r++){ int rr=enc?r:15-r; uint32_t nR=L^des_feistel(R,sk[rr]); L=R; R=nR; }
  pre=((uint64_t)R<<32)|L; o=des_perm(pre,DES_FP,64,64);
  for(i=0;i<8;i++) out[i]=(o>>(56-8*i))&0xFF;
}

/* 3DES-EDE, key = k1||k2||k3 (24 bytes). encrypt!=0 -> EDE, else DED. */
void rktcrypto_des3_ecb(const unsigned char key[24], const unsigned char *in,
                        unsigned char *out, intptr_t nblk, int encrypt){
  uint64_t s1[16],s2[16],s3[16]; intptr_t i;
  des_schedule(key,s1); des_schedule(key+8,s2); des_schedule(key+16,s3);
  for(i=0;i<nblk;i++){ unsigned char t[8];
    if(encrypt){ des_block(s1,in+8*i,t,1); des_block(s2,t,t,0); des_block(s3,t,out+8*i,1); }
    else       { des_block(s3,in+8*i,t,0); des_block(s2,t,t,1); des_block(s1,t,out+8*i,0); } }
}

void rktcrypto_des3_cbc(const unsigned char key[24], const unsigned char iv[8],
                        const unsigned char *in, unsigned char *out, intptr_t nblk, int encrypt){
  uint64_t s1[16],s2[16],s3[16]; unsigned char prev[8]; intptr_t i; int j;
  des_schedule(key,s1); des_schedule(key+8,s2); des_schedule(key+16,s3);
  memcpy(prev,iv,8);
  if(encrypt){
    for(i=0;i<nblk;i++){ unsigned char t[8];
      for(j=0;j<8;j++) t[j]=in[8*i+j]^prev[j];
      des_block(s1,t,t,1); des_block(s2,t,t,0); des_block(s3,t,out+8*i,1);
      memcpy(prev,out+8*i,8); }
  } else {
    for(i=0;i<nblk;i++){ unsigned char t[8],c[8];
      memcpy(c,in+8*i,8);
      des_block(s3,c,t,0); des_block(s2,t,t,1); des_block(s1,t,t,0);
      for(j=0;j<8;j++) out[8*i+j]=t[j]^prev[j];
      memcpy(prev,c,8); }
  }
}

/* =============================== RC4 =============================== */

void rktcrypto_rc4(const unsigned char *key, intptr_t keylen,
                   const unsigned char *in, unsigned char *out, intptr_t len){
  unsigned char s[256]; int i,j=0,a=0,b=0; intptr_t n;
  for(i=0;i<256;i++) s[i]=(unsigned char)i;
  for(i=0;i<256;i++){ j=(j+s[i]+key[i%keylen])&0xFF; { unsigned char t=s[i]; s[i]=s[j]; s[j]=t; } }
  for(n=0;n<len;n++){ a=(a+1)&0xFF; b=(b+s[a])&0xFF; { unsigned char t=s[a]; s[a]=s[b]; s[b]=t; }
    out[n]=in[n]^s[(s[a]+s[b])&0xFF]; }
}
