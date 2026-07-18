/* RSA (RSAES/RSASSA) on top of rktcrypto_bn. CRT private operation, public
   operation, PKCS#1 v1.5 SHA-256 signatures, plus RSASSA-PSS and RSAES-OAEP
   (both with SHA-256 and MGF1-SHA256). Verified against OpenSSL 3.6.3: v1.5
   signatures are bit-identical, and PSS/OAEP interoperate bidirectionally
   (our output verifies/decrypts under OpenSSL and vice versa). Keys are
   imported by component (n,e,d,p,q,dP,dQ,qInv); keygen is a follow-up. */
#include "rktcrypto.h"
#include "rktcrypto_bn.h"
#include "rktcrypto_rsa.h"
#include <string.h>
int bn_bits(const BN*);
void bn_from_be(BN*,const unsigned char*,int); void bn_to_be(unsigned char*,int,const BN*);
void bn_mod(BN*,const BN*,const BN*);
void bn_sub(BN*,const BN*,const BN*); void bn_add(BN*,const BN*,const BN*);
void bn_mul(BN*,const BN*,const BN*); int bn_cmp(const BN*,const BN*); void bn_copy(BN*,const BN*);
/* RSA key (2048-bit assumed here; klen = modulus bytes) */
void bn_mont_setup(uint64_t*,BN*,const BN*);
void bn_modexp_pre(BN*,const BN*,const BN*,const BN*,uint64_t,const BN*);
/* Public: out = in^e mod n */
void rsa_key_precompute(rsa_key*k){ bn_mont_setup(&k->n0_n,&k->rr_n,&k->n); bn_mont_setup(&k->n0_p,&k->rr_p,&k->p); bn_mont_setup(&k->n0_q,&k->rr_q,&k->q); }
void rsa_public(unsigned char*out,const unsigned char*in,const rsa_key*k){
  BN c,m; bn_from_be(&c,in,k->klen); bn_modexp_pre(&m,&c,&k->e,&k->n,k->n0_n,&k->rr_n); bn_to_be(out,k->klen,&m);
}
/* Private via CRT: m = c^d mod n */
void rsa_private_crt(unsigned char*out,const unsigned char*in,const rsa_key*k){
  BN c,m1,m2,h,t,cp; bn_from_be(&c,in,k->klen);
  bn_mod(&cp,&c,&k->p); bn_modexp_pre(&m1,&cp,&k->dP,&k->p,k->n0_p,&k->rr_p);
  bn_mod(&cp,&c,&k->q); bn_modexp_pre(&m2,&cp,&k->dQ,&k->q,k->n0_q,&k->rr_q);
  /* h = qInv*(m1-m2) mod p */
  if(bn_cmp(&m1,&m2)<0){ BN tmp; bn_add(&tmp,&m1,&k->p); bn_sub(&t,&tmp,&m2); } else bn_sub(&t,&m1,&m2);
  { BN prod; bn_mul(&prod,&k->qInv,&t); bn_mod(&h,&prod,&k->p); }
  { BN hq; bn_mul(&hq,&h,&k->q); bn_add(&m2,&m2,&hq); }   /* m = m2 + h*q */
  bn_to_be(out,k->klen,&m2);
}
/* PKCS#1 v1.5 signature encoding for SHA-256 (DigestInfo prefix + digest) */
static const unsigned char SHA256_DI[19]={0x30,0x31,0x30,0x0d,0x06,0x09,0x60,0x86,0x48,0x01,0x65,0x03,0x04,0x02,0x01,0x05,0x00,0x04,0x20};
static void pkcs1_v15_sign_encode(unsigned char*em,int klen,const unsigned char*hash){
  int tlen=19+32; em[0]=0;em[1]=1; int ps=klen-tlen-3;
  memset(em+2,0xff,ps); em[2+ps]=0; memcpy(em+3+ps,SHA256_DI,19); memcpy(em+3+ps+19,hash,32);
}
int rsa_pkcs1_sha256_sign(unsigned char*sig,const unsigned char*hash,const rsa_key*k){
  unsigned char em[512]; pkcs1_v15_sign_encode(em,k->klen,hash); rsa_private_crt(sig,em,k); return 1;
}
int rsa_pkcs1_sha256_verify(const unsigned char*sig,const unsigned char*hash,const rsa_key*k){
  unsigned char em[512],exp[512]; rsa_public(em,sig,k); pkcs1_v15_sign_encode(exp,k->klen,hash);
  return memcmp(em,exp,k->klen)==0;
}

/* ---- MGF1-SHA256 and the SHA-256/MGF1 PSS + OAEP schemes ---- */
static void rsa_sha256(const unsigned char*in,intptr_t n,unsigned char out[32]){
  rktcrypto_digest_oneshot(RKTCRYPTO_SHA256,in,0,n,out,0,32);
}
static void mgf1_sha256(unsigned char*mask,int masklen,const unsigned char*seed,int seedlen){
  unsigned char buf[512+4],h[32]; int off=0; uint32_t c=0;
  memcpy(buf,seed,seedlen);
  while(off<masklen){
    buf[seedlen]=(unsigned char)(c>>24); buf[seedlen+1]=(unsigned char)(c>>16);
    buf[seedlen+2]=(unsigned char)(c>>8); buf[seedlen+3]=(unsigned char)c;
    rsa_sha256(buf,seedlen+4,h); { int n=masklen-off; if(n>32)n=32; memcpy(mask+off,h,n); off+=n; } c++;
  }
}

/* EMSA-PSS-ENCODE with an explicit salt (mHash is the 32-byte SHA-256 of M). */
int rsa_pss_sha256_sign_salt(unsigned char*sig,const unsigned char*mHash,
                             const unsigned char*salt,int slen,const rsa_key*k){
  int embits=bn_bits(&k->n)-1, emlen=(embits+7)/8, hlen=32, dblen=emlen-hlen-1, i, zerobits, pad;
  unsigned char mp[8+32+64], H[32], db[512], dbmask[512], em[512], emfull[512];
  if(emlen<hlen+slen+2 || slen>64) return 0;
  memset(mp,0,8); memcpy(mp+8,mHash,32); memcpy(mp+40,salt,slen);
  rsa_sha256(mp,40+slen,H);
  memset(db,0,dblen); db[dblen-slen-1]=0x01; memcpy(db+dblen-slen,salt,slen);
  mgf1_sha256(dbmask,dblen,H,32);
  for(i=0;i<dblen;i++) db[i]^=dbmask[i];
  zerobits=8*emlen-embits; db[0]&=(unsigned char)(0xFF>>zerobits);
  memcpy(em,db,dblen); memcpy(em+dblen,H,32); em[emlen-1]=0xbc;
  pad=k->klen-emlen; memset(emfull,0,pad); memcpy(emfull+pad,em,emlen);
  rsa_private_crt(sig,emfull,k); return 1;
}
/* Hedged PSS: a fresh 32-byte random salt (sLen = hLen), OpenSSL's default. */
int rsa_pss_sha256_sign(unsigned char*sig,const unsigned char*mHash,const rsa_key*k){
  unsigned char salt[32]; if(!rktcrypto_random_bytes(salt,0,32)) return 0;
  return rsa_pss_sha256_sign_salt(sig,mHash,salt,32,k);
}
int rsa_pss_sha256_verify(const unsigned char*sig,const unsigned char*mHash,int slen,const rsa_key*k){
  int embits=bn_bits(&k->n)-1, emlen=(embits+7)/8, hlen=32, dblen=emlen-hlen-1, i, zerobits;
  unsigned char m[512], db[512], dbmask[512], mp[8+32+64], H2[32];
  const unsigned char *em, *H, *salt;
  if(emlen<hlen+slen+2 || slen>64) return 0;
  rsa_public(m,sig,k); em=m+(k->klen-emlen);
  if(em[emlen-1]!=0xbc) return 0;
  H=em+dblen; zerobits=8*emlen-embits;
  if(em[0]&(unsigned char)(0xFF<<(8-zerobits))) return 0;
  mgf1_sha256(dbmask,dblen,H,32);
  for(i=0;i<dblen;i++) db[i]=em[i]^dbmask[i];
  db[0]&=(unsigned char)(0xFF>>zerobits);
  i=0; while(i<dblen-slen-1 && db[i]==0) i++;
  if(i!=dblen-slen-1 || db[i]!=0x01) return 0;
  salt=db+dblen-slen;
  memset(mp,0,8); memcpy(mp+8,mHash,32); memcpy(mp+40,salt,slen);
  rsa_sha256(mp,40+slen,H2); return memcmp(H,H2,32)==0;
}

/* RSAES-OAEP-ENCRYPT with an explicit seed and an empty label. */
int rsa_oaep_sha256_encrypt_seed(unsigned char*out,const unsigned char*msg,int mlen,
                                 const unsigned char*seed,const rsa_key*k){
  int hlen=32, K=k->klen, dblen=K-hlen-1, i, pslen;
  unsigned char lHash[32], em[512], db[512], dbmask[512], smask[32];
  unsigned char *maskedSeed=em+1, *maskedDB=em+1+hlen;
  if(mlen>K-2*hlen-2 || mlen<0) return 0;
  rsa_sha256((const unsigned char*)"",0,lHash);
  em[0]=0;
  memcpy(db,lHash,32); pslen=K-mlen-2*hlen-2; memset(db+32,0,pslen); db[32+pslen]=1; memcpy(db+33+pslen,msg,mlen);
  mgf1_sha256(dbmask,dblen,seed,hlen); for(i=0;i<dblen;i++) maskedDB[i]=db[i]^dbmask[i];
  mgf1_sha256(smask,hlen,maskedDB,dblen); for(i=0;i<hlen;i++) maskedSeed[i]=seed[i]^smask[i];
  rsa_public(out,em,k); return 1;
}
int rsa_oaep_sha256_encrypt(unsigned char*out,const unsigned char*msg,int mlen,const rsa_key*k){
  unsigned char seed[32]; if(!rktcrypto_random_bytes(seed,0,32)) return 0;
  return rsa_oaep_sha256_encrypt_seed(out,msg,mlen,seed,k);
}
int rsa_oaep_sha256_decrypt(unsigned char*msg,int*mlen,const unsigned char*in,const rsa_key*k){
  int hlen=32, K=k->klen, dblen=K-hlen-1, i;
  unsigned char em[512], lHash[32], smask[32], seed[32], dbmask[512], db[512];
  unsigned char *maskedSeed=em+1, *maskedDB=em+1+hlen;
  rsa_private_crt(em,in,k);
  rsa_sha256((const unsigned char*)"",0,lHash);
  mgf1_sha256(smask,hlen,maskedDB,dblen); for(i=0;i<hlen;i++) seed[i]=maskedSeed[i]^smask[i];
  mgf1_sha256(dbmask,dblen,seed,hlen); for(i=0;i<dblen;i++) db[i]=maskedDB[i]^dbmask[i];
  if(em[0]!=0) return 0; if(memcmp(db,lHash,32)) return 0;
  i=32; while(i<dblen && db[i]==0) i++; if(i==dblen || db[i]!=1) return 0; i++;
  *mlen=dblen-i; memcpy(msg,db+i,*mlen); return 1;
}

/* RSAES-PKCS1-v1_5 (RFC 8017 sec 7.2): EM = 0x00 || 0x02 || PS || 0x00 || M,
   where PS is >= 8 nonzero random bytes. */
int rsa_pkcs1_v15_encrypt(unsigned char*out,const unsigned char*msg,int mlen,const rsa_key*k){
  int K=k->klen, pslen=K-mlen-3, i; unsigned char em[512];
  if(mlen>K-11 || mlen<0) return 0;
  em[0]=0; em[1]=2;
  if(!rktcrypto_random_bytes(em+2,0,pslen)) return 0;
  for(i=2;i<2+pslen;i++) while(em[i]==0){ if(!rktcrypto_random_bytes(em+i,0,1)) return 0; }  /* PS must be nonzero */
  em[2+pslen]=0; memcpy(em+3+pslen,msg,mlen);
  rsa_public(out,em,k); return 1;
}
int rsa_pkcs1_v15_decrypt(unsigned char*msg,int*mlen,const unsigned char*in,const rsa_key*k){
  int K=k->klen, i; unsigned char em[512];
  rsa_private_crt(em,in,k);
  if(em[0]!=0 || em[1]!=2) return 0;
  i=2; while(i<K && em[i]!=0) i++;
  if(i<10 || i==K) return 0;   /* PS must be >= 8 bytes and terminator present */
  i++;
  *mlen=K-i; memcpy(msg,em+i,*mlen); return 1;
}
