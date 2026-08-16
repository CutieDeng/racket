/* Differential + KAT harness for the SEED asmp kernel (seed_core_asm).
   Build: cc -O2 -I. -o /tmp/test_seed asm/tests/test_seed.c rktcrypto_seed_asm.S
   python-oracle args: keyhex ptbin ctbin nblocks (16-byte blocks) */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include "rktcrypto_legacy_ciphers.c"
static uint64_t s=0xfeedface12345678ULL;static uint64_t xr(void){s^=s<<13;s^=s>>7;s^=s<<17;return s;}
static int rd(const char*p,unsigned char*b,long n){FILE*f=fopen(p,"rb");if(!f)return 0;long g=fread(b,1,n,f);fclose(f);return g==n;}
int main(int argc,char**argv){ long fails=0;
  for(int t=0;t<200000;t++){ unsigned char key[16],in[16],ct[16],pt[16];
    for(int i=0;i<16;i++)key[i]=(unsigned char)xr(); for(int i=0;i<16;i++)in[i]=(unsigned char)xr();
    rktcrypto_seed_ecb(key,in,ct,1,1); rktcrypto_seed_ecb(key,ct,pt,1,0);
    if(memcmp(pt,in,16))fails++; }
  printf("(1) round-trip (200k): %s\n",fails?"FAIL":"OK");
  if(argc==5){ long nb=atol(argv[4]);unsigned char key[16];for(int i=0;i<16;i++){unsigned x;sscanf(argv[1]+2*i,"%2x",&x);key[i]=x;}
    unsigned char*P=malloc(nb*16),*C=malloc(nb*16),*M=malloc(nb*16);
    if(rd(argv[2],P,nb*16)&&rd(argv[3],C,nb*16)){ rktcrypto_seed_ecb(key,P,M,nb,1);int e=!memcmp(M,C,nb*16);
      rktcrypto_seed_ecb(key,C,M,nb,0);int dd=!memcmp(M,P,nb*16);
      printf("(2) python seed (%ld blk): enc %s dec %s\n",nb,e?"OK":"FAIL",dd?"OK":"FAIL");if(!e||!dd)fails++;}
    free(P);free(C);free(M);}
  printf("\n%s\n",fails?"FAILURES":"ALL PASS");return fails?1:0;
}
