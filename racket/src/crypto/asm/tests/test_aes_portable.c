/* Differential: the portable (#else, software FIPS-197) AES modes vs the shipped
   NEON kernel, over random (key,iv,len,keysize). Guards the non-ARMv8-crypto
   build. Build: compile rktcrypto_aes_modes.c a second time with -march=armv8-a
   (forces the portable branch) and the public symbols renamed to p_*, then link
   the NEON versions from librktcrypto.a. */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
/* NEON (from librktcrypto.a) */
void rktcrypto_aes_ctr(const unsigned char*,intptr_t,const unsigned char[16],const unsigned char*,unsigned char*,intptr_t);
void rktcrypto_aes_cbc_encrypt(const unsigned char*,intptr_t,const unsigned char[16],const unsigned char*,unsigned char*,intptr_t);
void rktcrypto_aes_cbc_decrypt(const unsigned char*,intptr_t,const unsigned char[16],const unsigned char*,unsigned char*,intptr_t);
void rktcrypto_aes_cmac(const unsigned char*,intptr_t,const unsigned char*,intptr_t,unsigned char[16]);
void rktcrypto_aes_xts(const unsigned char*,intptr_t,const unsigned char[16],const unsigned char*,unsigned char*,intptr_t,int);
/* portable (renamed) */
void p_ctr(const unsigned char*,intptr_t,const unsigned char[16],const unsigned char*,unsigned char*,intptr_t);
void p_cbce(const unsigned char*,intptr_t,const unsigned char[16],const unsigned char*,unsigned char*,intptr_t);
void p_cbcd(const unsigned char*,intptr_t,const unsigned char[16],const unsigned char*,unsigned char*,intptr_t);
void p_cmac(const unsigned char*,intptr_t,const unsigned char*,intptr_t,unsigned char[16]);
void p_xts(const unsigned char*,intptr_t,const unsigned char[16],const unsigned char*,unsigned char*,intptr_t,int);
static uint64_t st=0x1234567890abcdefULL;
static unsigned rnd(void){ st=st*6364136223846793005ULL+1; return (unsigned)(st>>33); }
static void fill(unsigned char*b,int n){ for(int i=0;i<n;i++) b[i]=(unsigned char)rnd(); }
static int eq(const unsigned char*a,const unsigned char*b,int n){ return memcmp(a,b,n)==0; }
int main(void){
  long bad=0,tot=0; int ks[3]={16,24,32};
  for(int t=0;t<20000;t++){
    int kl=ks[rnd()%3]; unsigned char key[64],iv[16]; fill(key,64); fill(iv,16);
    int len=(rnd()%512)+1; unsigned char in[600],a[600],b[600];
    fill(in,len);
    int blk=(len/16)*16;
    /* CTR (any length) */
    rktcrypto_aes_ctr(key,kl,iv,in,a,len); p_ctr(key,kl,iv,in,b,len); tot++; if(!eq(a,b,len)){bad++; if(bad<=3)printf("CTR kl=%d len=%d\n",kl,len);}
    if(blk>=16){
      /* CBC enc/dec (block-aligned) */
      rktcrypto_aes_cbc_encrypt(key,kl,iv,in,a,blk); p_cbce(key,kl,iv,in,b,blk); tot++; if(!eq(a,b,blk)){bad++; if(bad<=3)printf("CBCe kl=%d\n",kl);}
      rktcrypto_aes_cbc_decrypt(key,kl,iv,a,b,blk); tot++; if(!eq(b,in,blk)){bad++; if(bad<=3)printf("CBCd roundtrip kl=%d\n",kl);}
      unsigned char b2[600]; p_cbcd(key,kl,iv,a,b2,blk); tot++; if(!eq(b2,in,blk)){bad++; if(bad<=3)printf("CBCd-port kl=%d\n",kl);}
    }
    /* CMAC (any length >=1) */
    { unsigned char ta[16],tb[16]; rktcrypto_aes_cmac(key,kl,in,len,ta); p_cmac(key,kl,in,len,tb); tot++; if(!eq(ta,tb,16)){bad++; if(bad<=3)printf("CMAC kl=%d len=%d\n",kl,len);} }
    /* XTS (kl 16 or 32; len>=16). key1||key2 = key[0..2kl) */
    if((kl==16||kl==32) && len>=16){ int xl=len;
      rktcrypto_aes_xts(key,kl,iv,in,a,xl,1); p_xts(key,kl,iv,in,b,xl,1); tot++; if(!eq(a,b,xl)){bad++; if(bad<=3)printf("XTSenc kl=%d len=%d\n",kl,xl);}
      rktcrypto_aes_xts(key,kl,iv,a,b,xl,0); tot++; if(!eq(b,in,xl)){bad++; if(bad<=3)printf("XTSdec roundtrip kl=%d\n",kl);}
    }
  }
  printf("%ld/%ld mismatches\n",bad,tot); printf("%s\n",bad?"FAIL":"PASS"); return bad?1:0;
}
