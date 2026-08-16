/* Differential + KAT harness for the IDEA asmp kernel (idea_core_asm).
   Build (from racket/src/crypto): cc -O2 -I. -o /tmp/test_idea asm/tests/test_idea.c rktcrypto_idea_asm.S
   python-oracle args: keyhex ptbin ctbin nblocks */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include "rktcrypto_legacy_ciphers.c"
static void idea_ref(const uint16_t Z[52],const unsigned char in[8],unsigned char out[8]){
  uint16_t X1=(in[0]<<8)|in[1],X2=(in[2]<<8)|in[3],X3=(in[4]<<8)|in[5],X4=(in[6]<<8)|in[7];const uint16_t*z=Z;int r;
  for(r=0;r<8;r++){X1=idea_mul(X1,z[0]);X2=(uint16_t)(X2+z[1]);X3=(uint16_t)(X3+z[2]);X4=idea_mul(X4,z[3]);
    uint16_t t0=idea_mul((uint16_t)(X1^X3),z[4]),t1=idea_mul((uint16_t)((uint16_t)(X2^X4)+t0),z[5]);
    t0=(uint16_t)(t0+t1);X1^=t1;X4^=t0;uint16_t x=(uint16_t)(X2^t0);X2=(uint16_t)(X3^t1);X3=x;z+=6;}
  uint16_t Y1=idea_mul(X1,z[0]),Y2=(uint16_t)(X3+z[1]),Y3=(uint16_t)(X2+z[2]),Y4=idea_mul(X4,z[3]);
  out[0]=Y1>>8;out[1]=Y1;out[2]=Y2>>8;out[3]=Y2;out[4]=Y3>>8;out[5]=Y3;out[6]=Y4>>8;out[7]=Y4;
}
static uint64_t s=0x1357924680abcdefULL;static uint64_t xr(void){s^=s<<13;s^=s>>7;s^=s<<17;return s;}
static int rd(const char*p,unsigned char*b,long n){FILE*f=fopen(p,"rb");if(!f)return 0;long g=fread(b,1,n,f);fclose(f);return g==n;}
int main(int argc,char**argv){ long fails=0;
  for(int t=0;t<200000;t++){ unsigned char key[16],in[8];for(int i=0;i<16;i++)key[i]=(unsigned char)xr();for(int i=0;i<8;i++)in[i]=(unsigned char)xr();
    uint16_t Z[52];idea_enc_key(key,Z); unsigned char a[8],r[8];
    rktcrypto_idea_ecb(key,in,a,1,1); idea_ref(Z,in,r); if(memcmp(a,r,8))fails++;
    unsigned char d[8]; rktcrypto_idea_ecb(key,a,d,1,0); if(memcmp(d,in,8))fails++; }
  printf("(1) kernel vs portable + round-trip (400k): %s\n",fails?"FAIL":"OK");
  if(argc==5){ long nb=atol(argv[4]);unsigned char key[16];for(int i=0;i<16;i++){unsigned x;sscanf(argv[1]+2*i,"%2x",&x);key[i]=x;}
    unsigned char*P=malloc(nb*8),*C=malloc(nb*8),*M=malloc(nb*8);
    if(rd(argv[2],P,nb*8)&&rd(argv[3],C,nb*8)){ rktcrypto_idea_ecb(key,P,M,nb,1);int e=!memcmp(M,C,nb*8);
      rktcrypto_idea_ecb(key,C,M,nb,0);int dd=!memcmp(M,P,nb*8);
      printf("(2) python IDEA (%ld blk): enc %s dec %s\n",nb,e?"OK":"FAIL",dd?"OK":"FAIL");if(!e||!dd)fails++;}
    free(P);free(C);free(M);}
  printf("\n%s\n",fails?"FAILURES":"ALL PASS");return fails?1:0;
}
