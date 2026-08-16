/* Differential + end-to-end harness for the AES-CCM asmp kernels.
   Oracle AES is a self-contained reference (FIPS 197) -- deliberately NOT
   including rktcrypto_aes.c / rktcrypto_ccm.c, which on aarch64/Apple route to
   the very kernels under test.

   Kernels (aarch64/Apple, see rktcrypto_ccm.c and asm/ccm.asm):
     void ccm_bulk_seal_asm(rk, Nr, X[16], ctr[16], in, out, nblocks);  // MAC in
     void ccm_bulk_open_asm(rk, Nr, X[16], ctr[16], in, out, nblocks);  // MAC out
   Per whole 16-byte block: out = in ^ AES(ctr); ctr += 1 (big-endian, trailing
   64 bits); X = AES(X ^ <plaintext>). rk = (Nr+1) contiguous 16-byte round keys.

   Two gates:
     (1) bit-exact differential vs the portable oracle, >=200k, both Nr (10,14);
     (2) RFC 3610 packet vectors #1..#3 driven END-TO-END through the kernels.

   Build (from racket/src/crypto):
     cc -O2 -o /tmp/test_ccm asm/tests/test_ccm.c rktcrypto_ccm_asm.S
   Exit status is nonzero iff any mismatch or vector failure. */
#include <stdio.h>
#include <string.h>
#include <stdint.h>

extern void ccm_bulk_seal_asm(const unsigned char *rk, intptr_t Nr, unsigned char X[16],
                              unsigned char ctr[16], const unsigned char *in,
                              unsigned char *out, intptr_t nblocks);
extern void ccm_bulk_open_asm(const unsigned char *rk, intptr_t Nr, unsigned char X[16],
                              unsigned char ctr[16], const unsigned char *in,
                              unsigned char *out, intptr_t nblocks);

/* ---------------- reference AES (FIPS 197), any Nr ---------------- */
static const unsigned char SB[256]={
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
static unsigned char xt(unsigned char x){return (unsigned char)((x<<1)^((x>>7)*0x1b));}
static void aes_expand(const unsigned char*key,int Nk,unsigned char*rk){
  int Nr=Nk+6,tw=4*(Nr+1); memcpy(rk,key,4*Nk); unsigned char rc=1;
  for(int i=Nk;i<tw;i++){ unsigned char t[4]; memcpy(t,rk+4*(i-1),4);
    if(i%Nk==0){unsigned char s=t[0];t[0]=SB[t[1]];t[1]=SB[t[2]];t[2]=SB[t[3]];t[3]=SB[s];t[0]^=rc;rc=xt(rc);}
    else if(Nk>6 && i%Nk==4){for(int j=0;j<4;j++)t[j]=SB[t[j]];}
    for(int j=0;j<4;j++) rk[4*i+j]=rk[4*(i-Nk)+j]^t[j]; }
}
static void aes_block(const unsigned char*rk,int Nr,const unsigned char*in,unsigned char*out){
  unsigned char s[16]; memcpy(s,in,16); for(int i=0;i<16;i++)s[i]^=rk[i];
  for(int r=1;r<=Nr;r++){ unsigned char t[16]; for(int i=0;i<16;i++)t[i]=SB[s[i]];
    unsigned char sr[16]={t[0],t[5],t[10],t[15],t[4],t[9],t[14],t[3],t[8],t[13],t[2],t[7],t[12],t[1],t[6],t[11]};
    if(r!=Nr){for(int c=0;c<4;c++){unsigned char*col=sr+4*c,a0=col[0],a1=col[1],a2=col[2],a3=col[3];
      col[0]=(unsigned char)(xt(a0)^(xt(a1)^a1)^a2^a3); col[1]=(unsigned char)(a0^xt(a1)^(xt(a2)^a2)^a3);
      col[2]=(unsigned char)(a0^a1^xt(a2)^(xt(a3)^a3)); col[3]=(unsigned char)((xt(a0)^a0)^a1^a2^xt(a3));}}
    for(int i=0;i<16;i++)s[i]=(unsigned char)(sr[i]^rk[16*r+i]); }
  memcpy(out,s,16);
}

/* portable oracle for the kernel (mac_out: 0=seal MAC-in, 1=open MAC-out) */
static void bulk_ref(const unsigned char*rk,int Nr,unsigned char X[16],unsigned char ctr[16],
                     const unsigned char*in,unsigned char*out,intptr_t nb,int mac_out){
  for(intptr_t b=0;b<nb;b++){ unsigned char S[16]; const unsigned char*ib=in+16*b,*mp; unsigned char*ob=out+16*b;
    aes_block(rk,Nr,ctr,S); for(int i=0;i<16;i++)ob[i]=(unsigned char)(ib[i]^S[i]);
    uint64_t c=0; for(int i=0;i<8;i++)c=(c<<8)|ctr[8+i]; c++; for(int i=0;i<8;i++)ctr[15-i]=(unsigned char)(c>>(8*i));
    mp=mac_out?ob:ib; for(int i=0;i<16;i++)X[i]^=mp[i]; aes_block(rk,Nr,X,X); }
}

/* ---- full CCM driven THROUGH the asm kernels (mirrors rktcrypto_ccm.c) ---- */
static void ctrb(const unsigned char*nonce,int N,uint64_t ctr,unsigned char A[16]){
  int L=15-N; A[0]=(unsigned char)(L-1); for(int i=0;i<N;i++)A[1+i]=nonce[i];
  for(int i=0;i<L;i++)A[15-i]=(unsigned char)(ctr>>(8*i));
}
static void mac_hdr(const unsigned char*rk,int Nr,const unsigned char*nonce,int N,int M,
                    intptr_t alen,intptr_t mlen,const unsigned char*aad,unsigned char X[16]){
  int L=15-N; unsigned char B0[16],hdr[10]; int hlen=0,bi;
  B0[0]=(unsigned char)((alen>0?0x40:0)|(((M-2)/2)<<3)|(L-1));
  for(int i=0;i<N;i++)B0[1+i]=nonce[i]; for(int i=0;i<L;i++)B0[15-i]=(unsigned char)((uint64_t)mlen>>(8*i));
  aes_block(rk,Nr,B0,X); if(alen<=0)return;
  if(alen<0xFF00){hdr[0]=(unsigned char)(alen>>8);hdr[1]=(unsigned char)alen;hlen=2;}
  else{hdr[0]=0xFF;hdr[1]=0xFE;hdr[2]=(unsigned char)(alen>>24);hdr[3]=(unsigned char)(alen>>16);
       hdr[4]=(unsigned char)(alen>>8);hdr[5]=(unsigned char)alen;hlen=6;}
  bi=0; for(int i=0;i<hlen;i++){X[bi]^=hdr[i];if(++bi==16){aes_block(rk,Nr,X,X);bi=0;}}
  for(int i=0;i<alen;i++){X[bi]^=aad[i];if(++bi==16){aes_block(rk,Nr,X,X);bi=0;}}
  if(bi)aes_block(rk,Nr,X,X);
}
static void ccm_seal(const unsigned char*rk,int Nr,const unsigned char*nonce,int N,int M,
                     const unsigned char*aad,intptr_t alen,const unsigned char*pt,intptr_t mlen,unsigned char*out){
  unsigned char X[16],ctr[16],S[16],A0[16],S0[16],pad[16];
  mac_hdr(rk,Nr,nonce,N,M,alen,mlen,aad,X);
  ctrb(nonce,N,1,ctr); intptr_t nf=mlen/16,tl=mlen%16;
  ccm_bulk_seal_asm(rk,Nr,X,ctr,pt,out,nf);
  if(tl){aes_block(rk,Nr,ctr,S); for(int i=0;i<tl;i++)out[nf*16+i]=(unsigned char)(pt[nf*16+i]^S[i]);
    memset(pad,0,16);memcpy(pad,pt+nf*16,tl); for(int i=0;i<16;i++)X[i]^=pad[i]; aes_block(rk,Nr,X,X);}
  ctrb(nonce,N,0,A0); aes_block(rk,Nr,A0,S0);
  for(int i=0;i<M;i++)out[mlen+i]=(unsigned char)(X[i]^S0[i]);
}
static int ccm_open(const unsigned char*rk,int Nr,const unsigned char*nonce,int N,int M,
                    const unsigned char*aad,intptr_t alen,const unsigned char*in,intptr_t clen,unsigned char*out){
  if(clen<M)return 0; intptr_t mlen=clen-M; const unsigned char*tag=in+mlen;
  unsigned char X[16],ctr[16],S[16],A0[16],S0[16],pad[16],T[16]; unsigned char d=0;
  mac_hdr(rk,Nr,nonce,N,M,alen,mlen,aad,X);
  ctrb(nonce,N,1,ctr); intptr_t nf=mlen/16,tl=mlen%16;
  ccm_bulk_open_asm(rk,Nr,X,ctr,in,out,nf);
  if(tl){aes_block(rk,Nr,ctr,S); for(int i=0;i<tl;i++)out[nf*16+i]=(unsigned char)(in[nf*16+i]^S[i]);
    memset(pad,0,16);memcpy(pad,out+nf*16,tl); for(int i=0;i<16;i++)X[i]^=pad[i]; aes_block(rk,Nr,X,X);}
  ctrb(nonce,N,0,A0); aes_block(rk,Nr,A0,S0);
  for(int i=0;i<M;i++)T[i]=(unsigned char)(X[i]^S0[i]);
  for(int i=0;i<M;i++)d|=(unsigned char)(T[i]^tag[i]);
  if(d){memset(out,0,mlen);return 0;} return 1;
}

static uint64_t st64=0x243f6a8885a308d3ULL;
static unsigned rnd(void){st64^=st64<<13;st64^=st64>>7;st64^=st64<<17;return (unsigned)(st64>>32);}
static void fill(unsigned char*p,int n){for(int i=0;i<n;i++)p[i]=(unsigned char)rnd();}
static int hexeq(const unsigned char*g,const char*h,int n){for(int i=0;i<n;i++){unsigned v;sscanf(h+2*i,"%2x",&v);if(g[i]!=(unsigned char)v)return 0;}return 1;}

int main(void){
  int fails=0; long trials=0;

  /* (1) kernel differential, both Nr, seal+open, >=200k */
  int Nks[2]={4,8};
  for(int ki=0;ki<2;ki++){ int Nk=Nks[ki],Nr=Nk+6; unsigned char key[32],rk[240];
    for(int t=0;t<60000;t++){ fill(key,4*Nk); aes_expand(key,Nk,rk); int nb=rnd()%21;
      unsigned char X0[16],C0[16],in[16*20],Xa[16],Ca[16],oa[16*20],Xp[16],Cp[16],op[16*20];
      fill(X0,16);fill(C0,16);fill(in,16*nb);
      memcpy(Xa,X0,16);memcpy(Ca,C0,16);memcpy(Xp,X0,16);memcpy(Cp,C0,16);
      ccm_bulk_seal_asm(rk,Nr,Xa,Ca,in,oa,nb); bulk_ref(rk,Nr,Xp,Cp,in,op,nb,0);
      if(memcmp(Xa,Xp,16)||memcmp(Ca,Cp,16)||(nb&&memcmp(oa,op,16*nb))){if(fails<5)printf("  SEAL diff Nk=%d nb=%d\n",Nk,nb);fails++;}
      memcpy(Xa,X0,16);memcpy(Ca,C0,16);memcpy(Xp,X0,16);memcpy(Cp,C0,16);
      ccm_bulk_open_asm(rk,Nr,Xa,Ca,in,oa,nb); bulk_ref(rk,Nr,Xp,Cp,in,op,nb,1);
      if(memcmp(Xa,Xp,16)||memcmp(Ca,Cp,16)||(nb&&memcmp(oa,op,16*nb))){if(fails<5)printf("  OPEN diff Nk=%d nb=%d\n",Nk,nb);fails++;}
      trials+=2; }
  }
  printf("(1) kernel differential: %ld trials (AES-128 & AES-256, seal+open), %d mismatches\n",trials,fails);

  /* (2) RFC 3610 packet vectors #1..#3 (AES-128, N=13, M=8) through the kernels */
  { unsigned char key[16]={0xC0,0xC1,0xC2,0xC3,0xC4,0xC5,0xC6,0xC7,0xC8,0xC9,0xCA,0xCB,0xCC,0xCD,0xCE,0xCF},rk[176];
    aes_expand(key,4,rk); int N=13,M=8,vf=0;
    { unsigned char nn[13]={0,0,0,3,2,1,0,0xA0,0xA1,0xA2,0xA3,0xA4,0xA5},h[8]={0,1,2,3,4,5,6,7},pt[23],o[31],dec[23];
      for(int i=0;i<23;i++)pt[i]=(unsigned char)(8+i); ccm_seal(rk,10,nn,N,M,h,8,pt,23,o);
      vf|=!hexeq(o,"588c979a61c663d2f066d0c2c0f989806d5f6b61dac384",23); vf|=!hexeq(o+23,"17e8d12cfdf926e0",8);
      vf|=!(ccm_open(rk,10,nn,N,M,h,8,o,31,dec)&&!memcmp(dec,pt,23)); }
    { unsigned char nn[13]={0,0,0,4,3,2,1,0xA0,0xA1,0xA2,0xA3,0xA4,0xA5},h[8]={0,1,2,3,4,5,6,7},pt[24],o[32];
      for(int i=0;i<24;i++)pt[i]=(unsigned char)(8+i); ccm_seal(rk,10,nn,N,M,h,8,pt,24,o);
      vf|=!hexeq(o,"72c91a36e135f8cf291ca894085c87e3cc15c439c9e43a3b",24); vf|=!hexeq(o+24,"a091d56e10400916",8); }
    { unsigned char nn[13]={0,0,0,5,4,3,2,0xA0,0xA1,0xA2,0xA3,0xA4,0xA5},h[8]={0,1,2,3,4,5,6,7},pt[25],o[33];
      for(int i=0;i<25;i++)pt[i]=(unsigned char)(8+i); ccm_seal(rk,10,nn,N,M,h,8,pt,25,o);
      vf|=!hexeq(o,"51b1e5f44a197d1da46b0f8e2d282ae871e838bb64da859657",25); vf|=!hexeq(o+25,"4adaa76fbd9fb0c5",8); }
    printf("(2) RFC 3610 vectors #1..#3 (via kernels): %s\n", vf?"FAIL":"OK"); fails+=vf; }

  /* (3) TLS-style N=12,M=16 round-trip + tamper over lengths, both Nr */
  { int rt=0;
    for(int Nk=4;Nk<=8;Nk+=4){ int Nr=Nk+6; unsigned char key[32],rk[240]; fill(key,4*Nk); aes_expand(key,Nk,rk);
      unsigned char nn[12]; for(int i=0;i<12;i++)nn[i]=(unsigned char)(0x30+i);
      for(int mlen=0;mlen<=67;mlen++){ unsigned char pt[67],aad[9],o[67+16],dec[67];
        for(int i=0;i<mlen;i++)pt[i]=(unsigned char)(i*5+1); for(int i=0;i<9;i++)aad[i]=(unsigned char)(i+7);
        ccm_seal(rk,Nr,nn,12,16,aad,9,pt,mlen,o);
        if(!ccm_open(rk,Nr,nn,12,16,aad,9,o,mlen+16,dec)||memcmp(dec,pt,mlen))rt=1;
        o[mlen?0:mlen]^=0x80; if(mlen&&ccm_open(rk,Nr,nn,12,16,aad,9,o,mlen+16,dec))rt=1; } }
    printf("(3) TLS-style round-trip + tamper (N=12,M=16): %s\n", rt?"FAIL":"OK"); fails+=rt; }

  printf("\n%s\n", fails?"FAILURES":"ALL PASS");
  return fails?1:0;
}
