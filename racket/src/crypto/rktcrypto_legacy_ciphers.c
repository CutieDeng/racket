/* Legacy ciphers: Triple-DES (FIPS 46-3, EDE), RC4 (Rivest's cipher 4), and
   Camellia (RFC 3713).

   3DES (64-bit block, Sweet32) and RC4 (keystream bias) are cryptographically
   weak; Camellia is sound but legacy relative to AES. All exist so code paths
   that must interoperate with old protocols and file formats (TLS/CMS/etc.)
   need no external library. From scratch, no external code; not for new
   designs. */

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

/* SP tables fuse each S-box with the P permutation: SP[b][6bit] already holds
   the P-permuted 32-bit contribution, so the feistel is 8 lookups XORed --
   no per-bit P loop. Built once from the S/P tables. */
static uint32_t DES_SP[8][64];
/* Byte-indexed IP/FP: IP_T[i][v] = IP applied to value v placed at input byte i.
   IP(x) = OR_i IP_T[i][byte_i(x)] -- no 64-bit permutation loop per block. */
static uint64_t DES_IP_T[8][256], DES_FP_T[8][256];
static int des_sp_inited=0;
static void des_sp_init(void){
  int b,j,v;
  for(b=0;b<8;b++) for(j=0;j<64;j++){
    int row=((j>>5)<<1)|(j&1), col=(j>>1)&0xF;
    uint32_t sval=DES_S[b][row*16+col];
    DES_SP[b][j]=(uint32_t)des_perm((uint32_t)sval<<(28-4*b),DES_P,32,32);
  }
  for(b=0;b<8;b++) for(v=0;v<256;v++){
    uint64_t in=(uint64_t)v<<(56-8*b);
    DES_IP_T[b][v]=des_perm(in,DES_IP,64,64);
    DES_FP_T[b][v]=des_perm(in,DES_FP,64,64);
  }
  des_sp_inited=1;
}
static void des_schedule(const unsigned char k[8], uint64_t sk[16]){
  uint64_t key=0, cd; uint32_t C,D; int r;
  if(!des_sp_inited) des_sp_init();
  { int i; for(i=0;i<8;i++) key=(key<<8)|k[i]; }
  cd=des_perm(key,DES_PC1,56,64); C=(cd>>28)&0xFFFFFFF; D=cd&0xFFFFFFF;
  for(r=0;r<16;r++){ int s=DES_SH[r];
    C=((C<<s)|(C>>(28-s)))&0xFFFFFFF; D=((D<<s)|(D>>(28-s)))&0xFFFFFFF;
    sk[r]=des_perm(((uint64_t)C<<28)|D,DES_PC2,48,56); }
}

/* E-expansion via shifts (no 48-bit permutation loop): the eight overlapping
   6-bit groups of E(R) are contiguous windows of R (with wraparound at the ends).
   Each group is XORed with the matching 6 bits of the subkey and indexes SP. */
static uint32_t des_feistel(uint32_t R, uint64_t k){
  return DES_SP[0][(((((R&1)<<5)|((R>>27)&0x1F)) ^ (uint32_t)(k>>42)) & 0x3F)]
        ^DES_SP[1][((((R>>23)&0x3F)) ^ (uint32_t)(k>>36)) & 0x3F]
        ^DES_SP[2][((((R>>19)&0x3F)) ^ (uint32_t)(k>>30)) & 0x3F]
        ^DES_SP[3][((((R>>15)&0x3F)) ^ (uint32_t)(k>>24)) & 0x3F]
        ^DES_SP[4][((((R>>11)&0x3F)) ^ (uint32_t)(k>>18)) & 0x3F]
        ^DES_SP[5][((((R>>7)&0x3F)) ^ (uint32_t)(k>>12)) & 0x3F]
        ^DES_SP[6][((((R>>3)&0x3F)) ^ (uint32_t)(k>>6)) & 0x3F]
        ^DES_SP[7][((((R&0x1F)<<1)|((R>>31)&1)) ^ (uint32_t)k) & 0x3F];
}

static void des_block(const uint64_t sk[16], const unsigned char in[8], unsigned char out[8], int enc){
  uint64_t b,pre,o; uint32_t L,R; int r;
  b=DES_IP_T[0][in[0]]|DES_IP_T[1][in[1]]|DES_IP_T[2][in[2]]|DES_IP_T[3][in[3]]
   |DES_IP_T[4][in[4]]|DES_IP_T[5][in[5]]|DES_IP_T[6][in[6]]|DES_IP_T[7][in[7]];
  L=b>>32; R=b&0xFFFFFFFF;
  for(r=0;r<16;r++){ int rr=enc?r:15-r; uint32_t nR=L^des_feistel(R,sk[rr]); L=R; R=nR; }
  pre=((uint64_t)R<<32)|L;
  o=DES_FP_T[0][(pre>>56)&0xFF]|DES_FP_T[1][(pre>>48)&0xFF]|DES_FP_T[2][(pre>>40)&0xFF]|DES_FP_T[3][(pre>>32)&0xFF]
   |DES_FP_T[4][(pre>>24)&0xFF]|DES_FP_T[5][(pre>>16)&0xFF]|DES_FP_T[6][(pre>>8)&0xFF]|DES_FP_T[7][pre&0xFF];
  out[0]=(o>>56)&0xFF;out[1]=(o>>48)&0xFF;out[2]=(o>>40)&0xFF;out[3]=(o>>32)&0xFF;
  out[4]=(o>>24)&0xFF;out[5]=(o>>16)&0xFF;out[6]=(o>>8)&0xFF;out[7]=o&0xFF;
}

/* Fused 3DES block: the intermediate FP (end of stage k) and IP (start of stage
   k+1) are inverses and cancel, so one IP + 48 rounds (swap between stages) +
   one FP instead of 3 IP + 3 FP. */
static void des3_block(const uint64_t s1[16],const uint64_t s2[16],const uint64_t s3[16],
                       const unsigned char in[8], unsigned char out[8], int encrypt){
  const uint64_t *S[3]; int fwd[3],st,r; uint64_t b,o,pre; uint32_t L,R,t;
  if(encrypt){ S[0]=s1;fwd[0]=1; S[1]=s2;fwd[1]=0; S[2]=s3;fwd[2]=1; }
  else       { S[0]=s3;fwd[0]=0; S[1]=s2;fwd[1]=1; S[2]=s1;fwd[2]=0; }
  b=DES_IP_T[0][in[0]]|DES_IP_T[1][in[1]]|DES_IP_T[2][in[2]]|DES_IP_T[3][in[3]]
   |DES_IP_T[4][in[4]]|DES_IP_T[5][in[5]]|DES_IP_T[6][in[6]]|DES_IP_T[7][in[7]];
  L=(uint32_t)(b>>32); R=(uint32_t)b;
  for(st=0;st<3;st++){
    for(r=0;r<16;r++){ int rr=fwd[st]?r:15-r; uint32_t nR=L^des_feistel(R,S[st][rr]); L=R; R=nR; }
    t=L; L=R; R=t;                                   /* inter-stage / preoutput swap */
  }
  pre=((uint64_t)L<<32)|R;
  o=DES_FP_T[0][(pre>>56)&0xFF]|DES_FP_T[1][(pre>>48)&0xFF]|DES_FP_T[2][(pre>>40)&0xFF]|DES_FP_T[3][(pre>>32)&0xFF]
   |DES_FP_T[4][(pre>>24)&0xFF]|DES_FP_T[5][(pre>>16)&0xFF]|DES_FP_T[6][(pre>>8)&0xFF]|DES_FP_T[7][pre&0xFF];
  out[0]=(o>>56)&0xFF;out[1]=(o>>48)&0xFF;out[2]=(o>>40)&0xFF;out[3]=(o>>32)&0xFF;
  out[4]=(o>>24)&0xFF;out[5]=(o>>16)&0xFF;out[6]=(o>>8)&0xFF;out[7]=o&0xFF;
}

/* 3DES-EDE, key = k1||k2||k3 (24 bytes). encrypt!=0 -> EDE, else DED. */
void rktcrypto_des3_ecb(const unsigned char key[24], const unsigned char *in,
                        unsigned char *out, intptr_t nblk, int encrypt){
  uint64_t s1[16],s2[16],s3[16]; intptr_t i;
  des_schedule(key,s1); des_schedule(key+8,s2); des_schedule(key+16,s3);
  for(i=0;i<nblk;i++) des3_block(s1,s2,s3,in+8*i,out+8*i,encrypt);
}

void rktcrypto_des3_cbc(const unsigned char key[24], const unsigned char iv[8],
                        const unsigned char *in, unsigned char *out, intptr_t nblk, int encrypt){
  uint64_t s1[16],s2[16],s3[16]; unsigned char prev[8]; intptr_t i; int j;
  des_schedule(key,s1); des_schedule(key+8,s2); des_schedule(key+16,s3);
  memcpy(prev,iv,8);
  if(encrypt){
    for(i=0;i<nblk;i++){ unsigned char t[8];
      for(j=0;j<8;j++) t[j]=in[8*i+j]^prev[j];
      des3_block(s1,s2,s3,t,out+8*i,1);
      memcpy(prev,out+8*i,8); }
  } else {
    for(i=0;i<nblk;i++){ unsigned char t[8],c[8];
      memcpy(c,in+8*i,8);
      des3_block(s1,s2,s3,c,t,0);
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

/* ============================ Camellia (RFC 3713) ============================
   128-bit block, 128/192/256-bit keys. Not broken, but legacy relative to AES;
   included for TLS/CMS interoperability. */

static const unsigned char CAM_SBOX1[256]={
0x70,0x82,0x2c,0xec,0xb3,0x27,0xc0,0xe5,0xe4,0x85,0x57,0x35,0xea,0x0c,0xae,0x41,
0x23,0xef,0x6b,0x93,0x45,0x19,0xa5,0x21,0xed,0x0e,0x4f,0x4e,0x1d,0x65,0x92,0xbd,
0x86,0xb8,0xaf,0x8f,0x7c,0xeb,0x1f,0xce,0x3e,0x30,0xdc,0x5f,0x5e,0xc5,0x0b,0x1a,
0xa6,0xe1,0x39,0xca,0xd5,0x47,0x5d,0x3d,0xd9,0x01,0x5a,0xd6,0x51,0x56,0x6c,0x4d,
0x8b,0x0d,0x9a,0x66,0xfb,0xcc,0xb0,0x2d,0x74,0x12,0x2b,0x20,0xf0,0xb1,0x84,0x99,
0xdf,0x4c,0xcb,0xc2,0x34,0x7e,0x76,0x05,0x6d,0xb7,0xa9,0x31,0xd1,0x17,0x04,0xd7,
0x14,0x58,0x3a,0x61,0xde,0x1b,0x11,0x1c,0x32,0x0f,0x9c,0x16,0x53,0x18,0xf2,0x22,
0xfe,0x44,0xcf,0xb2,0xc3,0xb5,0x7a,0x91,0x24,0x08,0xe8,0xa8,0x60,0xfc,0x69,0x50,
0xaa,0xd0,0xa0,0x7d,0xa1,0x89,0x62,0x97,0x54,0x5b,0x1e,0x95,0xe0,0xff,0x64,0xd2,
0x10,0xc4,0x00,0x48,0xa3,0xf7,0x75,0xdb,0x8a,0x03,0xe6,0xda,0x09,0x3f,0xdd,0x94,
0x87,0x5c,0x83,0x02,0xcd,0x4a,0x90,0x33,0x73,0x67,0xf6,0xf3,0x9d,0x7f,0xbf,0xe2,
0x52,0x9b,0xd8,0x26,0xc8,0x37,0xc6,0x3b,0x81,0x96,0x6f,0x4b,0x13,0xbe,0x63,0x2e,
0xe9,0x79,0xa7,0x8c,0x9f,0x6e,0xbc,0x8e,0x29,0xf5,0xf9,0xb6,0x2f,0xfd,0xb4,0x59,
0x78,0x98,0x06,0x6a,0xe7,0x46,0x71,0xba,0xd4,0x25,0xab,0x42,0x88,0xa2,0x8d,0xfa,
0x72,0x07,0xb9,0x55,0xf8,0xee,0xac,0x0a,0x36,0x49,0x2a,0x68,0x3c,0x38,0xf1,0xa4,
0x40,0x28,0xd3,0x7b,0xbb,0xc9,0x43,0xc1,0x15,0xe3,0xad,0xf4,0x77,0xc7,0x80,0x9e};

typedef unsigned __int128 cam_u128;
static unsigned char cam_rol8(unsigned char x,int n){ return (unsigned char)((x<<n)|(x>>(8-n))); }
static const uint64_t CAM_SIG[6]={0xA09E667F3BCC908BULL,0xB67AE8584CAA73B2ULL,0xC6EF372FE94F82BEULL,
                                  0x54FF53A5F1D36F1CULL,0x10E527FADE682D1DULL,0xB05688C2B3E6C1FDULL};
static uint64_t cam_load64(const unsigned char *p){ uint64_t v; memcpy(&v,p,8); return __builtin_bswap64(v); }
static void cam_store64(unsigned char *p,uint64_t v){ v=__builtin_bswap64(v); memcpy(p,&v,8); }

/* SP tables fuse each byte's S-box variant with the linear P-layer, so cam_F is
   8 XORed 64-bit lookups. Generated once by evaluating the exact z-formulas with
   a single active y (guaranteed bit-identical to the byte-wise version). */
static uint64_t CAM_SP[8][256];
static int cam_sp_inited=0;
static void cam_sp_init(void){
  int j,b,i;
  for(j=0;j<8;j++) for(b=0;b<256;b++){
    unsigned char y[8]={0,0,0,0,0,0,0,0}, z[8]; uint64_t r=0;
    switch(j){
      case 0: y[0]=CAM_SBOX1[b]; break;
      case 1: y[1]=cam_rol8(CAM_SBOX1[b],1); break;
      case 2: y[2]=cam_rol8(CAM_SBOX1[b],7); break;
      case 3: y[3]=CAM_SBOX1[cam_rol8((unsigned char)b,1)]; break;
      case 4: y[4]=cam_rol8(CAM_SBOX1[b],1); break;
      case 5: y[5]=cam_rol8(CAM_SBOX1[b],7); break;
      case 6: y[6]=CAM_SBOX1[cam_rol8((unsigned char)b,1)]; break;
      case 7: y[7]=CAM_SBOX1[b]; break;
    }
    z[0]=y[0]^y[2]^y[3]^y[5]^y[6]^y[7]; z[1]=y[0]^y[1]^y[3]^y[4]^y[6]^y[7];
    z[2]=y[0]^y[1]^y[2]^y[4]^y[5]^y[7]; z[3]=y[1]^y[2]^y[3]^y[4]^y[5]^y[6];
    z[4]=y[0]^y[1]^y[5]^y[6]^y[7]; z[5]=y[1]^y[2]^y[4]^y[6]^y[7];
    z[6]=y[2]^y[3]^y[4]^y[5]^y[7]; z[7]=y[0]^y[3]^y[4]^y[5]^y[6];
    for(i=0;i<8;i++) r=(r<<8)|z[i];
    CAM_SP[j][b]=r;
  }
  cam_sp_inited=1;
}
static uint64_t cam_F(uint64_t X,uint64_t k){
  uint64_t u=X^k;
  return CAM_SP[0][(u>>56)&0xff]^CAM_SP[1][(u>>48)&0xff]^CAM_SP[2][(u>>40)&0xff]^CAM_SP[3][(u>>32)&0xff]
        ^CAM_SP[4][(u>>24)&0xff]^CAM_SP[5][(u>>16)&0xff]^CAM_SP[6][(u>>8)&0xff]^CAM_SP[7][u&0xff];
}
static uint64_t cam_rol32(uint64_t x,int n){ uint32_t v=(uint32_t)x; return (uint64_t)((v<<n)|(v>>(32-n))); }
static uint64_t cam_FL(uint64_t X,uint64_t ke){ uint32_t x1=(uint32_t)(X>>32),x2=(uint32_t)X,k1=(uint32_t)(ke>>32),k2=(uint32_t)ke;
  x2^=(uint32_t)cam_rol32(x1&k1,1); x1^=(x2|k2); return ((uint64_t)x1<<32)|x2; }
static uint64_t cam_FLINV(uint64_t Y,uint64_t ke){ uint32_t y1=(uint32_t)(Y>>32),y2=(uint32_t)Y,k1=(uint32_t)(ke>>32),k2=(uint32_t)ke;
  y1^=(y2|k2); y2^=(uint32_t)cam_rol32(y1&k1,1); return ((uint64_t)y1<<32)|y2; }
static cam_u128 cam_rol128(cam_u128 x,int n){ return (x<<n)|(x>>(128-n)); }
static uint64_t CAM_HI(cam_u128 x){ return (uint64_t)(x>>64); }
static uint64_t CAM_LO(cam_u128 x){ return (uint64_t)x; }

typedef struct { uint64_t kw[4],k[24],ke[6]; int nr; } cam_key;
static void cam_schedule(const unsigned char *key,int keylen,cam_key *ck){
  cam_u128 KL,KR=0,KA,KB=0; uint64_t D1,D2;
  if(!cam_sp_inited) cam_sp_init();
  KL=((cam_u128)cam_load64(key)<<64)|cam_load64(key+8);
  if(keylen==24){ uint64_t hi=cam_load64(key+16); KR=((cam_u128)hi<<64)|(uint64_t)(~hi); }
  else if(keylen==32){ KR=((cam_u128)cam_load64(key+16)<<64)|cam_load64(key+24); }
  D1=CAM_HI(KL^KR); D2=CAM_LO(KL^KR);
  D2^=cam_F(D1,CAM_SIG[0]); D1^=cam_F(D2,CAM_SIG[1]); D1^=CAM_HI(KL); D2^=CAM_LO(KL);
  D2^=cam_F(D1,CAM_SIG[2]); D1^=cam_F(D2,CAM_SIG[3]); KA=((cam_u128)D1<<64)|D2;
  if(keylen>16){ D1=CAM_HI(KA^KR); D2=CAM_LO(KA^KR); D2^=cam_F(D1,CAM_SIG[4]); D1^=cam_F(D2,CAM_SIG[5]); KB=((cam_u128)D1<<64)|D2; }
  if(keylen==16){ ck->nr=18;
    ck->kw[0]=CAM_HI(KL); ck->kw[1]=CAM_LO(KL);
    ck->k[0]=CAM_HI(KA); ck->k[1]=CAM_LO(KA);
    ck->k[2]=CAM_HI(cam_rol128(KL,15)); ck->k[3]=CAM_LO(cam_rol128(KL,15));
    ck->k[4]=CAM_HI(cam_rol128(KA,15)); ck->k[5]=CAM_LO(cam_rol128(KA,15));
    ck->ke[0]=CAM_HI(cam_rol128(KA,30)); ck->ke[1]=CAM_LO(cam_rol128(KA,30));
    ck->k[6]=CAM_HI(cam_rol128(KL,45)); ck->k[7]=CAM_LO(cam_rol128(KL,45));
    ck->k[8]=CAM_HI(cam_rol128(KA,45)); ck->k[9]=CAM_LO(cam_rol128(KL,60));
    ck->k[10]=CAM_HI(cam_rol128(KA,60)); ck->k[11]=CAM_LO(cam_rol128(KA,60));
    ck->ke[2]=CAM_HI(cam_rol128(KL,77)); ck->ke[3]=CAM_LO(cam_rol128(KL,77));
    ck->k[12]=CAM_HI(cam_rol128(KL,94)); ck->k[13]=CAM_LO(cam_rol128(KL,94));
    ck->k[14]=CAM_HI(cam_rol128(KA,94)); ck->k[15]=CAM_LO(cam_rol128(KA,94));
    ck->k[16]=CAM_HI(cam_rol128(KL,111)); ck->k[17]=CAM_LO(cam_rol128(KL,111));
    ck->kw[2]=CAM_HI(cam_rol128(KA,111)); ck->kw[3]=CAM_LO(cam_rol128(KA,111));
  } else { ck->nr=24;
    ck->kw[0]=CAM_HI(KL); ck->kw[1]=CAM_LO(KL);
    ck->k[0]=CAM_HI(KB); ck->k[1]=CAM_LO(KB);
    ck->k[2]=CAM_HI(cam_rol128(KR,15)); ck->k[3]=CAM_LO(cam_rol128(KR,15));
    ck->k[4]=CAM_HI(cam_rol128(KA,15)); ck->k[5]=CAM_LO(cam_rol128(KA,15));
    ck->ke[0]=CAM_HI(cam_rol128(KR,30)); ck->ke[1]=CAM_LO(cam_rol128(KR,30));
    ck->k[6]=CAM_HI(cam_rol128(KB,30)); ck->k[7]=CAM_LO(cam_rol128(KB,30));
    ck->k[8]=CAM_HI(cam_rol128(KL,45)); ck->k[9]=CAM_LO(cam_rol128(KL,45));
    ck->k[10]=CAM_HI(cam_rol128(KA,45)); ck->k[11]=CAM_LO(cam_rol128(KA,45));
    ck->ke[2]=CAM_HI(cam_rol128(KL,60)); ck->ke[3]=CAM_LO(cam_rol128(KL,60));
    ck->k[12]=CAM_HI(cam_rol128(KR,60)); ck->k[13]=CAM_LO(cam_rol128(KR,60));
    ck->k[14]=CAM_HI(cam_rol128(KB,60)); ck->k[15]=CAM_LO(cam_rol128(KB,60));
    ck->k[16]=CAM_HI(cam_rol128(KL,77)); ck->k[17]=CAM_LO(cam_rol128(KL,77));
    ck->ke[4]=CAM_HI(cam_rol128(KA,77)); ck->ke[5]=CAM_LO(cam_rol128(KA,77));
    ck->k[18]=CAM_HI(cam_rol128(KR,94)); ck->k[19]=CAM_LO(cam_rol128(KR,94));
    ck->k[20]=CAM_HI(cam_rol128(KA,94)); ck->k[21]=CAM_LO(cam_rol128(KA,94));
    ck->k[22]=CAM_HI(cam_rol128(KL,111)); ck->k[23]=CAM_LO(cam_rol128(KL,111));
    ck->kw[2]=CAM_HI(cam_rol128(KB,111)); ck->kw[3]=CAM_LO(cam_rol128(KB,111));
  }
}
static void cam_crypt_block(const cam_key *ck,const unsigned char in[16],unsigned char out[16]){
  uint64_t D1=cam_load64(in),D2=cam_load64(in+8); int stage,i,r=0,fl=0;
  D1^=ck->kw[0]; D2^=ck->kw[1];
  for(stage=0;stage<ck->nr/6;stage++){
    for(i=0;i<6;i++){ if(i%2==0) D2^=cam_F(D1,ck->k[r]); else D1^=cam_F(D2,ck->k[r]); r++; }
    if(stage<ck->nr/6-1){ D1=cam_FL(D1,ck->ke[fl*2]); D2=cam_FLINV(D2,ck->ke[fl*2+1]); fl++; }
  }
  D2^=ck->kw[2]; D1^=ck->kw[3];
  cam_store64(out,D2); cam_store64(out+8,D1);
}
static void cam_reverse_key(const cam_key *ck,cam_key *d){
  int i,ne=ck->nr/6-1; *d=*ck;
  d->kw[0]=ck->kw[2]; d->kw[1]=ck->kw[3]; d->kw[2]=ck->kw[0]; d->kw[3]=ck->kw[1];
  for(i=0;i<ck->nr;i++) d->k[i]=ck->k[ck->nr-1-i];
  for(i=0;i<ne;i++){ d->ke[2*i]=ck->ke[2*(ne-1-i)+1]; d->ke[2*i+1]=ck->ke[2*(ne-1-i)]; }
}

void rktcrypto_camellia_ecb(const unsigned char *key,intptr_t keylen,const unsigned char *in,
                            unsigned char *out,intptr_t nblk,int encrypt){
  cam_key ck,d; intptr_t i; cam_schedule(key,(int)keylen,&ck);
  if(!encrypt){ cam_reverse_key(&ck,&d); ck=d; }
  for(i=0;i<nblk;i++) cam_crypt_block(&ck,in+16*i,out+16*i);
}
void rktcrypto_camellia_cbc(const unsigned char *key,intptr_t keylen,const unsigned char iv[16],
                            const unsigned char *in,unsigned char *out,intptr_t nblk,int encrypt){
  cam_key ck,d; unsigned char prev[16],tmp[16]; intptr_t i; int j;
  cam_schedule(key,(int)keylen,&ck); memcpy(prev,iv,16);
  if(encrypt){
    for(i=0;i<nblk;i++){ for(j=0;j<16;j++) tmp[j]=in[16*i+j]^prev[j]; cam_crypt_block(&ck,tmp,out+16*i); memcpy(prev,out+16*i,16); }
  } else {
    cam_reverse_key(&ck,&d); ck=d;
    for(i=0;i<nblk;i++){ unsigned char c[16]; memcpy(c,in+16*i,16); cam_crypt_block(&ck,c,tmp);
      for(j=0;j<16;j++) out[16*i+j]=tmp[j]^prev[j]; memcpy(prev,c,16); }
  }
}
