/* Known-answer test for the brainpoolP256r1/P384r1/P512r1 curves (RFC 5639),
   added to the ECC engine (rktcrypto_ecc.c) with general-a point doubling.
   Vectors generated from python cryptography; validates pubkey (d*G) and ECDH.
   Build (from racket/src/crypto):
     cc -O2 -I. -o /tmp/test_brainpool asm/tests/test_brainpool.c \
        rktcrypto_ecc.c rktcrypto_ecc_asm.S rktcrypto_p521rr.c
   Exit nonzero on any mismatch. */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
/* brainpool KAT (from python cryptography), generated. */
static const char *BPK256_D1="0000000000000000000000000000000022446688aaccef113201557799bbddff",*BPK256_D2="00000000000000000000000000000001fdb97530eca8642002468acf13579bdf";
static const char *BPK256_X1="245f148b77921893bc08c8d477bbf276e3707a8f796ce7148ea71de7d747003a",*BPK256_Y1="5606b70fe8bd5f0d07f53899a6b2cc235470a9ef026c0fb842404d5334204dd6";
static const char *BPK256_X2="30a9b0069870baa1efaba1dc42eb5ff4943b37e42b528a448e8e9fcbd528d0a7",*BPK256_Y2="36b9005979fe7bafc378b7e110c92dd72edc1936849d1386afab9f3ea1eb9329";
static const char *BPK256_SH="6bcdee0c01c50ab282a671cd7f89b685ecbac2c4d0af575f29d9931f97f76274";
static const char *BPK384_D1="0000000000000000000000000000000000000000000000000000000000000000336699cd00336699cb0200336699ccfe",*BPK384_D2="0000000000000000000000000000000000000000000000000000000000000002fc962fc962fc96300369d0369d0369ce";
static const char *BPK384_X1="3f7c61cb5ea5f9397a05fcd9c603fa2e6a5492fd78a42b8668ad9c39c484dc8ba2e04c3d2a248f54ec9798c0666300db",*BPK384_Y1="39a8b2b86ce45638e97ae35a8466e22e4537c431c00b6f6d988284915b772aec8d71faddecca0f9fc7eab97b05cb5ea5";
static const char *BPK384_X2="4cee0d4fc5549fa89dc52e42b7c167aaa935cbbdd44075a91109d087d28d53807ccaf06bc494ec877e00ab264e7dbfef",*BPK384_Y2="60fab7816ed55a2e5625bc8c0bbb962beb5161517485de2eda0ea03eee55a8404e1d8773522efae86f82c11b177878eb";
static const char *BPK384_SH="4bf7271189ade3b0a3906f82628738b0d856bd750291477a7ef3db2dd85f68724d8927f0b8074bd3753e92d7f9e6050e";
static const char *BPK512_D1="0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004488cd115599de226402aaef3377bbfd",*BPK512_D2="000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003fb72ea61d950c840048d159e26af37bd";
static const char *BPK512_X1="4eafdb08beb0a17f40c7f68642af7e42c636f95dad0563b66f2fc5998a9e0225bc3839b059d365005b9514b5deb8214ebfe3b4f7f2e27d2d332d889417d3428f",*BPK512_Y1="1537335b010ef3769721a437d24343be9c8357248504d6464bca61091b9b50b4cdf615cf2f83aef325ed72e5ed2703feb79c724e3f674f6176ee4215a3e0f090";
static const char *BPK512_X2="899113637728922147b2e37ba56a0726766a96ef02cdaa58f3e6284eaa1e56f709f981bdd878cd47cd6d8235057a4e0590595695c1c93fc5fad3f924415a9b54",*BPK512_Y2="1e33d05c8f8d558142c52f23fcb1a49949db2b60c682eeb788b88ac0af1d31ad347f17dde5973ca9f6de9fdaf36a45786fb15fa627876368b6157e657cc94053";
static const char *BPK512_SH="a9b9326ca5d85e876ea5a460974c69a0e03ed17d0f520076d7ec1b0c1a5a66f9f88175f8ddfed89d399eb6b57cb6454aca0fcf7205f79a142424fc98073efef3";
extern int rktcrypto_brainpoolP256_pubkey(unsigned char*,const unsigned char*);
extern int rktcrypto_brainpoolP256_ecdh(unsigned char*,const unsigned char*,const unsigned char*);
extern int rktcrypto_brainpoolP384_pubkey(unsigned char*,const unsigned char*);
extern int rktcrypto_brainpoolP384_ecdh(unsigned char*,const unsigned char*,const unsigned char*);
extern int rktcrypto_brainpoolP512_pubkey(unsigned char*,const unsigned char*);
extern int rktcrypto_brainpoolP512_ecdh(unsigned char*,const unsigned char*,const unsigned char*);
/* ECDSA-only deps of the ecc object, not exercised here */
intptr_t rktcrypto_digest_size(int a){(void)a;return 64;}
int rktcrypto_digest_oneshot(int a,const unsigned char*d,intptr_t s,intptr_t e,unsigned char*o,intptr_t os,intptr_t ol){(void)a;(void)d;(void)s;(void)e;(void)o;(void)os;(void)ol;return 1;}
int rktcrypto_random_bytes(unsigned char*b,intptr_t s,intptr_t e){for(intptr_t i=s;i<e;i++)b[i]=0;return 1;}
static void hx(const char*h,unsigned char*b,int n){for(int i=0;i<n;i++){unsigned x;sscanf(h+2*i,"%2x",&x);b[i]=x;}}
static int eqx(const unsigned char*b,const char*h,int n){for(int i=0;i<n;i++){unsigned x;sscanf(h+2*i,"%2x",&x);if(b[i]!=(unsigned char)x)return 0;}return 1;}
static int chk(const char*name,int nb,int(*pk)(unsigned char*,const unsigned char*),int(*dh)(unsigned char*,const unsigned char*,const unsigned char*),
  const char*d1,const char*d2,const char*x1,const char*y1,const char*x2,const char*y2,const char*sh){
  unsigned char db1[64],db2[64],pub1[129],pub2[129],out[64];
  hx(d1,db1,nb); hx(d2,db2,nb);
  int p1=pk(pub1,db1)&&pub1[0]==4&&eqx(pub1+1,x1,nb)&&eqx(pub1+1+nb,y1,nb);
  int p2=pk(pub2,db2)&&pub2[0]==4&&eqx(pub2+1,x2,nb)&&eqx(pub2+1+nb,y2,nb);
  int e1=dh(out,db1,pub2)&&eqx(out,sh,nb);
  int e2=dh(out,db2,pub1)&&eqx(out,sh,nb);   /* ECDH is symmetric */
  printf("  %s: pubkeys %s  ecdh %s\n",name,(p1&&p2)?"OK":"FAIL",(e1&&e2)?"OK":"FAIL");
  return p1&&p2&&e1&&e2; }
int main(void){ int ok=1;
  ok&=chk("brainpoolP256r1",32,rktcrypto_brainpoolP256_pubkey,rktcrypto_brainpoolP256_ecdh,BPK256_D1,BPK256_D2,BPK256_X1,BPK256_Y1,BPK256_X2,BPK256_Y2,BPK256_SH);
  ok&=chk("brainpoolP384r1",48,rktcrypto_brainpoolP384_pubkey,rktcrypto_brainpoolP384_ecdh,BPK384_D1,BPK384_D2,BPK384_X1,BPK384_Y1,BPK384_X2,BPK384_Y2,BPK384_SH);
  ok&=chk("brainpoolP512r1",64,rktcrypto_brainpoolP512_pubkey,rktcrypto_brainpoolP512_ecdh,BPK512_D1,BPK512_D2,BPK512_X1,BPK512_Y1,BPK512_X2,BPK512_Y2,BPK512_SH);
  printf("\n%s\n",ok?"ALL PASS":"FAILURES"); return ok?0:1; }
