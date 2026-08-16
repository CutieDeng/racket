/* Differential + KAT harness for the RC2 asmp kernels (rc2_enc/dec_core_asm).
   Includes the tree rktcrypto_legacy_ciphers.c (its rc2 core routes to the
   kernels on aarch64/Apple). Oracles: the RFC 2268 section-5 KATs (absolute)
   plus a local portable core for the random differential, plus an optional
   openssl rc2-ecb cross-check.

   Build (from racket/src/crypto):
     cc -O2 -I. -o /tmp/test_rc2 asm/tests/test_rc2.c rktcrypto_rc2_asm.S
   openssl cross-check args: key.hex(32) pt.bin ct.bin  (16-byte key, T1=128)
   Exit status nonzero iff any mismatch. */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include "rktcrypto_legacy_ciphers.c"

/* local portable RC2 core (independent oracle for the differential) */
static void rc2_enc_ref(const uint16_t K[64], const unsigned char in[8], unsigned char out[8]){
  uint16_t R[4]; int i,j=0; static const int s[4]={1,2,3,5};
  for(i=0;i<4;i++) R[i]=(uint16_t)(in[2*i]|(in[2*i+1]<<8));
  for(int r=0;r<16;r++){ for(i=0;i<4;i++){ R[i]=(uint16_t)(R[i]+K[j]+(R[(i+3)&3]&R[(i+2)&3])+((~R[(i+3)&3])&R[(i+1)&3]));
    j++; R[i]=(uint16_t)((R[i]<<s[i])|(R[i]>>(16-s[i]))); }
    if(r==4||r==10){ for(i=0;i<4;i++) R[i]=(uint16_t)(R[i]+K[R[(i+3)&3]&63]); } }
  for(i=0;i<4;i++){ out[2*i]=(unsigned char)R[i]; out[2*i+1]=(unsigned char)(R[i]>>8); }
}
static uint64_t st=0x1122334455667788ULL;
static uint64_t xr(void){st^=st<<13;st^=st>>7;st^=st<<17;return st;}
static int hxb(const char*h,unsigned char*b){int n=0;while(h[2*n]){unsigned v;sscanf(h+2*n,"%2x",&v);b[n]=(unsigned char)v;n++;}return n;}
static int kat(const char*kh,int T1,const char*ph,const char*ch){
  unsigned char key[16],pt[8],ct[8],got[8],dec[8]; int T=hxb(kh,key); hxb(ph,pt); hxb(ch,ct);
  rktcrypto_rc2_ecb(key,T,T1,pt,got,1,1); rktcrypto_rc2_ecb(key,T,T1,got,dec,1,0);
  return (memcmp(got,ct,8)==0)&&(memcmp(dec,pt,8)==0);
}
static int rd(const char*p,unsigned char*b,long n){FILE*f=fopen(p,"rb");if(!f)return 0;long g=fread(b,1,n,f);fclose(f);return g==n;}

int main(int argc,char**argv){
  long fails=0;
  /* (1) kernel (via rktcrypto_rc2_ecb) vs portable oracle, random key/T1, enc+dec */
  for(int t=0;t<200000;t++){
    unsigned char key[16],pt[8],ce[8],re[8],dd[8]; uint16_t K[64];
    int T=1+(xr()%16),T1=1+(xr()%128);
    for(int i=0;i<T;i++)key[i]=(unsigned char)xr();
    for(int i=0;i<8;i++)pt[i]=(unsigned char)xr();
    rc2_expand(key,T,T1,K); rc2_enc_ref(K,pt,re);
    rktcrypto_rc2_ecb(key,T,T1,pt,ce,1,1);
    if(memcmp(ce,re,8)){if(fails<3)printf("  enc diff t=%d\n",t);fails++;}
    rktcrypto_rc2_ecb(key,T,T1,ce,dd,1,0);           /* decrypt back */
    if(memcmp(dd,pt,8)){if(fails<3)printf("  rt diff t=%d\n",t);fails++;}
  }
  printf("(1) kernel vs portable + round-trip (400k, random key/T1): %s\n", fails?"FAIL":"OK");

  /* (2) RFC 2268 section-5 KATs through the kernels */
  { int k=1;
    k&=kat("0000000000000000",63,"0000000000000000","ebb773f993278eff");
    k&=kat("ffffffffffffffff",64,"ffffffffffffffff","278b27e42e2f0d49");
    k&=kat("3000000000000000",64,"1000000000000001","30649edf9be7d2c2");
    k&=kat("88",64,"0000000000000000","61a8a244adacccf0");
    k&=kat("88bca90e90875a",64,"0000000000000000","6ccf4308974c267f");
    k&=kat("88bca90e90875a7f0f79c384627bafb2",128,"0000000000000000","2269552ab0f85ca6");
    k&=kat("88bca90e90875a7f0f79c384627bafb2",64,"0000000000000000","1a807d272bbe5db1");
    printf("(2) RFC 2268 KATs (7 vectors): %s\n", k?"OK":"FAIL"); if(!k)fails++;
  }
  /* (3) openssl rc2-ecb cross-check (16-byte key, T1=128) */
  if(argc==4){ unsigned char key[16]; for(int i=0;i<16;i++){unsigned x;sscanf(argv[1]+2*i,"%2x",&x);key[i]=x;}
    unsigned char P[1024],C[1024],M[1024];
    if(rd(argv[2],P,1024)&&rd(argv[3],C,1024)){
      rktcrypto_rc2_ecb(key,16,128,P,M,128,1); int e=(memcmp(M,C,1024)==0);
      printf("(3) openssl rc2-ecb (128 blk, T1=128): %s\n", e?"OK":"FAIL"); if(!e)fails++;
    }
  }
  printf("\n%s\n", fails?"FAILURES":"ALL PASS");
  return fails?1:0;
}
