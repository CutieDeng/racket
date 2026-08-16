/* Differential + KAT harness for the CAST-128 asmp kernel (cast_core_asm).
   Build: cc -O2 -I. -o /tmp/test_cast5 asm/tests/test_cast5.c rktcrypto_cast5_asm.S
   python-oracle args: keyhex ptbin ctbin nblocks */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include "rktcrypto_legacy_ciphers.c"
static uint64_t s=0x2468ace013579bdfULL;static uint64_t xr(void){s^=s<<13;s^=s>>7;s^=s<<17;return s;}
static int rd(const char*p,unsigned char*b,long n){FILE*f=fopen(p,"rb");if(!f)return 0;long g=fread(b,1,n,f);fclose(f);return g==n;}
int main(int argc,char**argv){ long fails=0;
  /* kernel(via rktcrypto_cast5_ecb, asm) round-trips over random keys */
  for(int t=0;t<200000;t++){ unsigned char key[16],in[8],ct[8],pt[8];
    for(int i=0;i<16;i++)key[i]=(unsigned char)xr(); for(int i=0;i<8;i++)in[i]=(unsigned char)xr();
    rktcrypto_cast5_ecb(key,in,ct,1,1); rktcrypto_cast5_ecb(key,ct,pt,1,0);
    if(memcmp(pt,in,8))fails++; }
  printf("(1) round-trip (200k): %s\n",fails?"FAIL":"OK");
  /* RFC 2144 KAT */
  { unsigned char k[16]={0x01,0x23,0x45,0x67,0x12,0x34,0x56,0x78,0x23,0x45,0x67,0x89,0x34,0x56,0x78,0x9a};
    unsigned char pt[8]={0x01,0x23,0x45,0x67,0x89,0xab,0xcd,0xef},exp[8]={0x23,0x8b,0x4f,0xe5,0x84,0x7e,0x44,0xb2},ct[8];
    rktcrypto_cast5_ecb(k,pt,ct,1,1); int ok=!memcmp(ct,exp,8);
    printf("(2) RFC 2144 KAT: %s\n",ok?"OK":"FAIL"); if(!ok)fails++; }
  /* python cross-check */
  if(argc==5){ long nb=atol(argv[4]);unsigned char key[16];for(int i=0;i<16;i++){unsigned x;sscanf(argv[1]+2*i,"%2x",&x);key[i]=x;}
    unsigned char*P=malloc(nb*8),*C=malloc(nb*8),*M=malloc(nb*8);
    if(rd(argv[2],P,nb*8)&&rd(argv[3],C,nb*8)){ rktcrypto_cast5_ecb(key,P,M,nb,1);int e=!memcmp(M,C,nb*8);
      rktcrypto_cast5_ecb(key,C,M,nb,0);int dd=!memcmp(M,P,nb*8);
      printf("(3) python cast5 (%ld blk): enc %s dec %s\n",nb,e?"OK":"FAIL",dd?"OK":"FAIL");if(!e||!dd)fails++;}
    free(P);free(C);free(M);}
  printf("\n%s\n",fails?"FAILURES":"ALL PASS");return fails?1:0;
}
