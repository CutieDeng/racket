/* Differential + KAT harness for the Blowfish asmp kernel (bf_core_asm).
   Includes the tree .c (its bf core routes to the kernel on aarch64/Apple).
   Build (from racket/src/crypto):
     cc -O2 -I. -o /tmp/test_bf asm/tests/test_bf.c rktcrypto_bf_asm.S
   openssl args: keyhex ptbin ctbin nblocks (bf-ecb). */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include "rktcrypto_legacy_ciphers.c"
static void bf_ref(const bf_ctx*b,uint32_t*xl,uint32_t*xr,int enc){
  uint32_t L=*xl,R=*xr,t;int i;
  if(enc){for(i=0;i<16;i++){L^=b->P[i];R^=bf_F(b,L);t=L;L=R;R=t;}t=L;L=R;R=t;R^=b->P[16];L^=b->P[17];}
  else{for(i=17;i>1;i--){L^=b->P[i];R^=bf_F(b,L);t=L;L=R;R=t;}t=L;L=R;R=t;R^=b->P[1];L^=b->P[0];}
  *xl=L;*xr=R;
}
static uint64_t st=0xf00dcafe12345678ULL; static uint64_t xr(void){st^=st<<13;st^=st>>7;st^=st<<17;return st;}
static int rd(const char*p,unsigned char*b,long n){FILE*f=fopen(p,"rb");if(!f)return 0;long g=fread(b,1,n,f);fclose(f);return g==n;}
int main(int argc,char**argv){
  long fails=0; bf_ctx b;
  for(int t=0;t<200000;t++){ unsigned char key[16];int kl=1+(xr()%16);
    for(int i=0;i<kl;i++)key[i]=(unsigned char)xr(); bf_expand(&b,key,kl);
    uint32_t L=(uint32_t)xr(),R=(uint32_t)xr();
    uint32_t al=L,ar=R; bf_block(&b,&al,&ar,1);   /* asm-routed */
    uint32_t rl=L,rr=R; bf_ref(&b,&rl,&rr,1);
    if(al!=rl||ar!=rr)fails++;
    uint32_t dl=al,dr=ar; bf_block(&b,&dl,&dr,0);
    if(dl!=L||dr!=R)fails++;
  }
  printf("(1) kernel vs portable + round-trip (400k): %s\n", fails?"FAIL":"OK");
  if(argc==5){ long nb=atol(argv[4]); unsigned char key[16]; int kl=0;
    for(int i=0;argv[1][2*i];i++){unsigned x;sscanf(argv[1]+2*i,"%2x",&x);key[i]=x;kl++;}
    unsigned char *P=malloc(nb*8),*C=malloc(nb*8),*M=malloc(nb*8);
    if(rd(argv[2],P,nb*8)&&rd(argv[3],C,nb*8)){
      rktcrypto_blowfish_ecb(key,kl,P,M,nb,1);int e=!memcmp(M,C,nb*8);
      rktcrypto_blowfish_ecb(key,kl,C,M,nb,0);int d=!memcmp(M,P,nb*8);
      printf("(2) openssl bf-ecb (%ld blk): enc %s dec %s\n",nb,e?"OK":"FAIL",d?"OK":"FAIL"); if(!e||!d)fails++; }
    free(P);free(C);free(M);
  }
  printf("\n%s\n", fails?"FAILURES":"ALL PASS"); return fails?1:0;
}
