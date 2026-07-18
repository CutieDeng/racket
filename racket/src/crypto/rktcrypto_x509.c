/* Minimal DER/ASN.1 + PEM + X.509 parsing, enough to decode a certificate,
   extract its subjectPublicKeyInfo, and verify the certificate signature
   (RSA PKCS#1 v1.5 SHA-256 or ECDSA-SHA256 over P-256/384/521). This is the
   foundation of the format/protocol layer; the higher TLS/CMS machinery
   builds on it. From scratch, no external code. */

#include "rktcrypto.h"
#include "rktcrypto_bn.h"
#include "rktcrypto_rsa.h"
#include <string.h>

/* ---- base64 / PEM ---- */
static int b64val(int c){
  if(c>='A'&&c<='Z') return c-'A'; if(c>='a'&&c<='z') return c-'a'+26;
  if(c>='0'&&c<='9') return c-'0'+52; if(c=='+') return 62; if(c=='/') return 63; return -1;
}
/* Decodes base64 (ignoring whitespace) into out; returns byte count or -1. */
intptr_t rktcrypto_base64_decode(const unsigned char *in, intptr_t inlen, unsigned char *out){
  int acc=0,nbits=0; intptr_t o=0,i;
  for(i=0;i<inlen;i++){ int c=in[i],v; if(c=='='||c=='\n'||c=='\r'||c==' '||c=='\t') continue;
    v=b64val(c); if(v<0) return -1; acc=(acc<<6)|v; nbits+=6; if(nbits>=8){ nbits-=8; out[o++]=(unsigned char)(acc>>nbits); } }
  return o;
}
/* Extracts the DER between -----BEGIN X----- / -----END X----- and base64-
   decodes it into out. Returns DER length or -1. */
intptr_t rktcrypto_pem_to_der(const unsigned char *pem, intptr_t pemlen, unsigned char *out){
  const char *b="-----BEGIN"; intptr_t i=0,s,e;
  while(i<pemlen){ intptr_t j=0; while(j<10 && i+j<pemlen && pem[i+j]==(unsigned char)b[j]) j++; if(j==10) break; i++; }
  if(i>=pemlen) return -1;
  while(i<pemlen && pem[i]!='\n') i++; i++; s=i;                 /* start of base64 body */
  while(i<pemlen){ if(pem[i]=='-'&&i+5<=pemlen && memcmp(pem+i,"-----",5)==0) break; i++; }
  e=i;
  return rktcrypto_base64_decode(pem+s, e-s, out);
}

/* ---- DER cursor ---- */
typedef struct { const unsigned char *p, *end; } der;
/* Reads one TLV; on success sets *tag and the content window [cp,ce), advances d past it. */
static int der_tlv(der *d, int *tag, const unsigned char **cp, const unsigned char **ce){
  const unsigned char *p=d->p; uintptr_t len; int first;
  if(p>=d->end) return 0;
  *tag=*p++; first=*p++;
  if(first<0x80){ len=(uintptr_t)first; }
  else { int nb=first&0x7f; len=0; if(nb<1||nb>4||p+nb>d->end) return 0; while(nb--){ len=(len<<8)|*p++; } }
  if(p+len>d->end) return 0;
  *cp=p; *ce=p+len; d->p=p+len; return 1;
}
/* Enters a constructed TLV (returns its content as a sub-cursor). */
static int der_into(der *d, int wanttag, der *sub){
  int tag; const unsigned char *cp,*ce; if(!der_tlv(d,&tag,&cp,&ce)) return 0;
  if(wanttag>=0 && tag!=wanttag) return 0; sub->p=cp; sub->end=ce; return 1;
}
static int der_skip(der *d){ int tag; const unsigned char *cp,*ce; return der_tlv(d,&tag,&cp,&ce); }

/* Strips a leading 0x00 sign byte from a DER INTEGER content. */
static void trim_int(const unsigned char **p, intptr_t *len){
  while(*len>1 && (*p)[0]==0){ (*p)++; (*len)--; }
}

/* ---- public-key-only RSA verify context ---- */
void bn_mont_setup(uint64_t*,BN*,const BN*);

/* Parses a certificate (DER) and verifies its signature under the issuer's
   public key contained in the same cert (self-signed) using SHA-256. Returns
   1 if valid, 0 otherwise. Supports RSA (PKCS#1 v1.5) and ECDSA P-256/384/521. */
int rktcrypto_x509_verify_selfsigned(const unsigned char *der_buf, intptr_t derlen){
  der top,cert,tbs_cur,spki,algid,pk_bits; int tag; const unsigned char *cp,*ce;
  const unsigned char *tbs_start; intptr_t tbs_len;
  unsigned char hash[32];
  const unsigned char *sigalg_oid; intptr_t sigalg_oidlen;
  const unsigned char *sig; intptr_t siglen;
  int is_rsa=0, is_ec=0;

  top.p=der_buf; top.end=der_buf+derlen;
  if(!der_into(&top,0x30,&cert)) return 0;          /* Certificate SEQUENCE */
  /* TBSCertificate: capture its full DER (tag..end) for hashing */
  tbs_start=cert.p;
  if(!der_tlv(&cert,&tag,&cp,&ce) || tag!=0x30) return 0;
  tbs_len=ce - tbs_start;
  tbs_cur.p=cp; tbs_cur.end=ce;
  /* signatureAlgorithm SEQUENCE { OID } */
  if(!der_into(&cert,0x30,&algid)) return 0;
  if(!der_tlv(&algid,&tag,&cp,&ce) || tag!=0x06) return 0; sigalg_oid=cp; sigalg_oidlen=ce-cp;
  /* signatureValue BIT STRING */
  if(!der_tlv(&cert,&tag,&cp,&ce) || tag!=0x03) return 0;
  sig=cp+1; siglen=(ce-cp)-1;                         /* skip unused-bits octet */

  /* classify signature algorithm by OID: sha256WithRSA = 1.2.840.113549.1.1.11
     ecdsa-with-SHA256 = 1.2.840.10045.4.3.2 */
  { static const unsigned char RSA_SHA256[]={0x2a,0x86,0x48,0x86,0xf7,0x0d,0x01,0x01,0x0b};
    static const unsigned char ECDSA_SHA256[]={0x2a,0x86,0x48,0xce,0x3d,0x04,0x03,0x02};
    if(sigalg_oidlen==(intptr_t)sizeof RSA_SHA256 && memcmp(sigalg_oid,RSA_SHA256,sizeof RSA_SHA256)==0) is_rsa=1;
    else if(sigalg_oidlen==(intptr_t)sizeof ECDSA_SHA256 && memcmp(sigalg_oid,ECDSA_SHA256,sizeof ECDSA_SHA256)==0) is_ec=1;
    else return 0;
  }

  /* Walk TBSCertificate to subjectPublicKeyInfo (7th element; version is [0]). */
  { der t=tbs_cur; const unsigned char *scp,*sce; int stag;
    /* optional version [0] */
    if(t.p<t.end && (unsigned char)*t.p==0xA0){ if(!der_skip(&t)) return 0; }
    if(!der_skip(&t)) return 0;   /* serialNumber */
    if(!der_skip(&t)) return 0;   /* signature alg */
    if(!der_skip(&t)) return 0;   /* issuer */
    if(!der_skip(&t)) return 0;   /* validity */
    if(!der_skip(&t)) return 0;   /* subject */
    if(!der_into(&t,0x30,&spki)) return 0;   /* SubjectPublicKeyInfo SEQUENCE */
    (void)scp;(void)sce;(void)stag;
  }
  /* SPKI = { AlgorithmIdentifier, subjectPublicKey BIT STRING } */
  { der a; if(!der_into(&spki,0x30,&a)) return 0;   /* algorithm */
    /* skip alg OID + params; we already know RSA vs EC from sig alg */
  }
  if(!der_tlv(&spki,&tag,&cp,&ce) || tag!=0x03) return 0;   /* subjectPublicKey BIT STRING */
  pk_bits.p=cp+1; pk_bits.end=ce;                            /* skip unused-bits octet */

  rktcrypto_digest_oneshot(RKTCRYPTO_SHA256, tbs_start, 0, tbs_len, hash, 0, 32);

  if(is_rsa){
    /* RSAPublicKey ::= SEQUENCE { modulus INTEGER, publicExponent INTEGER } */
    der rk; const unsigned char *np,*ep; intptr_t nlen,elen; rsa_key k; uint64_t ev=0; int i;
    if(!der_into(&pk_bits,0x30,&rk)) return 0;
    if(!der_tlv(&rk,&tag,&cp,&ce)||tag!=0x02) return 0; np=cp; nlen=ce-cp; trim_int(&np,&nlen);
    if(!der_tlv(&rk,&tag,&cp,&ce)||tag!=0x02) return 0; ep=cp; elen=ce-cp; trim_int(&ep,&elen);
    memset(&k,0,sizeof k); k.klen=(int)nlen;
    bn_from_be(&k.n,np,(int)nlen);
    for(i=0;i<elen;i++) ev=(ev<<8)|ep[i];
    { unsigned char eb[16]; int j; for(j=0;j<16;j++) eb[j]=(unsigned char)(ev>>(120-8*j)); bn_from_be(&k.e,eb,16); }
    bn_mont_setup(&k.n0_n,&k.rr_n,&k.n);
    return rsa_pkcs1_sha256_verify(sig,hash,&k);
  }
  if(is_ec){
    /* subjectPublicKey = 0x04 || X || Y ; curve inferred from key length. sig
       = SEQUENCE { r INTEGER, s INTEGER }. Only P-256 SHA-256 is handled here. */
    intptr_t klen=pk_bits.end-pk_bits.p; int fb;
    der sq; const unsigned char *rp,*sp; intptr_t rlen,slen2; unsigned char pub[200],rawsig[132];
    if(klen==65) fb=32; else if(klen==97) fb=48; else if(klen==133) fb=66; else return 0;
    memcpy(pub,pk_bits.p,klen);
    { der ss; ss.p=sig; ss.end=sig+siglen; if(!der_into(&ss,0x30,&sq)) return 0; }
    if(!der_tlv(&sq,&tag,&cp,&ce)||tag!=0x02) return 0; rp=cp; rlen=ce-cp; trim_int(&rp,&rlen);
    if(!der_tlv(&sq,&tag,&cp,&ce)||tag!=0x02) return 0; sp=cp; slen2=ce-cp; trim_int(&sp,&slen2);
    memset(rawsig,0,2*fb);
    memcpy(rawsig+fb-rlen,rp,rlen); memcpy(rawsig+2*fb-slen2,sp,slen2);
    /* Only P-256/SHA-256 wired here (the ecdsa-with-SHA256 OID) */
    if(fb==32) return rktcrypto_p256_ecdsa_verify(rawsig,tbs_start,tbs_len,pub);
    return 0;
  }
  return 0;
}
