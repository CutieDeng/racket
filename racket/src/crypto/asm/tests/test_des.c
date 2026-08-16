/* Differential + KAT harness for the single-DES asmp kernel (des1_core_asm).
   Includes the tree rktcrypto_legacy_ciphers.c to reuse its DES tables/schedule;
   on aarch64/Apple its des1_core routes to the kernel under test. The portable
   oracle here is a local 16-round loop over the C des_feistel (always C), so the
   differential compares kernel vs portable independent of the routing.

   Build (from racket/src/crypto):
     cc -O2 -I. -o /tmp/test_des asm/tests/test_des.c rktcrypto_des_asm.S
   With the openssl cross-check (optional args key.bin pt.bin ct.bin nblocks):
     openssl enc -des-ecb -K <hex> -nopad -in pt.bin > ct.bin
   Exit status is nonzero iff any mismatch. */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include "rktcrypto_legacy_ciphers.c"

/* portable reference core (16 rounds over the C SP-table feistel) */
static uint64_t des1_ref(const des_ks *ks, int encrypt, uint64_t b){
  uint32_t L=(uint32_t)(b>>32), R=(uint32_t)b, nR; int r;
  for(r=0;r<16;r++){ int rr = encrypt ? r : 15-r; nR = L ^ des_feistel(R, ks->g[rr]); L=R; R=nR; }
  return ((uint64_t)R<<32)|L;
}
static void des_ecb_ref(const unsigned char key[8], const unsigned char *in,
                        unsigned char *out, long nblk, int enc){
  des_ks ks; long i; des_schedule(key,&ks);
  for(i=0;i<nblk;i++) des_fp_store(des1_ref(&ks,enc,des_ip(in+8*i)),out+8*i);
}

static uint64_t s=0x0f1e2d3c4b5a6978ULL;
static uint64_t xs(void){s^=s<<13;s^=s>>7;s^=s<<17;return s;}
static int rd(const char*p,unsigned char*b,long n){FILE*f=fopen(p,"rb");if(!f)return 0;long g=fread(b,1,n,f);fclose(f);return g==n;}

int main(int argc,char**argv){
  long fails=0;
  /* (1) kernel vs portable differential over random keys/blocks, enc+dec */
  for(int t=0;t<200000;t++){
    unsigned char key[8],blk[8],a[8],b[8];
    for(int i=0;i<8;i++)key[i]=(unsigned char)xs();
    for(int i=0;i<8;i++)blk[i]=(unsigned char)xs();
    rktcrypto_des_ecb(key,blk,a,1,1); des_ecb_ref(key,blk,b,1,1);
    if(memcmp(a,b,8)){if(fails<3)printf("  ENC diff at t=%d\n",t);fails++;}
    rktcrypto_des_ecb(key,blk,a,1,0); des_ecb_ref(key,blk,b,1,0);
    if(memcmp(a,b,8)){if(fails<3)printf("  DEC diff at t=%d\n",t);fails++;}
  }
  printf("(1) kernel vs portable differential (400k, enc+dec): %s\n", fails?"FAIL":"OK");

  /* (2) classic DES KAT: key=0123456789ABCDEF pt="Now is t" ct=3FA40E8A984D4815 */
  { unsigned char k[8]={0x01,0x23,0x45,0x67,0x89,0xAB,0xCD,0xEF};
    unsigned char pt[8]={0x4E,0x6F,0x77,0x20,0x69,0x73,0x20,0x74};
    unsigned char exp[8]={0x3F,0xA4,0x0E,0x8A,0x98,0x4D,0x48,0x15}, ct[8], dec[8];
    rktcrypto_des_ecb(k,pt,ct,1,1); rktcrypto_des_ecb(k,ct,dec,1,0);
    int kat=(memcmp(ct,exp,8)==0), rt=(memcmp(dec,pt,8)==0);
    printf("(2) classic KAT: %s   round-trip: %s\n", kat?"OK":"FAIL", rt?"OK":"FAIL");
    if(!kat||!rt) fails++;
  }

  /* (3) openssl des-ecb cross-check (optional) */
  if(argc==5){ long nb=atol(argv[4]); unsigned char key[8];
    unsigned char *P=malloc(nb*8),*C=malloc(nb*8),*M=malloc(nb*8);
    if(rd(argv[1],key,8)&&rd(argv[2],P,nb*8)&&rd(argv[3],C,nb*8)){
      rktcrypto_des_ecb(key,P,M,nb,1); int e=(memcmp(M,C,nb*8)==0);
      rktcrypto_des_ecb(key,C,M,nb,0); int d=(memcmp(M,P,nb*8)==0);
      printf("(3) openssl des-ecb (%ld blk): enc %s dec %s\n",nb,e?"OK":"FAIL",d?"OK":"FAIL");
      if(!e||!d) fails++;
    }
    free(P);free(C);free(M);
  }
  /* (4) DES-X reuses the DES kernel: zero whitening must equal single-DES, and
     encrypt/decrypt must round-trip. */
  { long fx=0;
    for(int t=0;t<100000;t++){
      unsigned char xk[24]={0}, blk[8], dx[8], d[8];
      for(int i=0;i<8;i++){ xk[8+i]=(unsigned char)xs(); blk[i]=(unsigned char)xs(); }
      rktcrypto_desx_ecb(xk,blk,dx,1,1); rktcrypto_des_ecb(xk+8,blk,d,1,1);
      if(memcmp(dx,d,8)) fx++;
      unsigned char fk[24],pt[24],ct[24],de[24];
      for(int i=0;i<24;i++){ fk[i]=(unsigned char)xs(); pt[i]=(unsigned char)xs(); }
      rktcrypto_desx_ecb(fk,pt,ct,3,1); rktcrypto_desx_ecb(fk,ct,de,3,0);
      if(memcmp(de,pt,24)) fx++;
    }
    printf("(4) DES-X: zero-whitening==DES + round-trip (100k): %s\n", fx?"FAIL":"OK");
    if(fx) fails++;
  }

  printf("\n%s\n", fails?"FAILURES":"ALL PASS");
  return fails?1:0;
}
