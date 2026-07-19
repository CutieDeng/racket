/* Dedicated P-521 (secp521r1) engine on a reduced-radix 9x58-bit field with
   lazy reduction, plus Jacobian point arithmetic -- the representation OpenSSL's
   ecp_nistp521 uses, which makes P-521 field multiplies competitive with (even
   faster than) smaller curves. Written from scratch; the 9x58 layout, the
   fold-during-multiply (positions >=9 land one bit up so are folded via x2), and
   the dbl-2001-b / add-2007-bl formulas are standard techniques referenced from
   the literature and OpenSSL's structure, reimplemented here. No external code.

   This file provides the reduced-radix field + point ops + felem scalar mults.
   rktcrypto_ecc.c routes the P-521 public entry points here when built in. */

#include <string.h>
#include <stdint.h>

typedef uint64_t p521_u64;
typedef unsigned __int128 p521_u128;
typedef p521_u64 felem[9];
typedef p521_u128 largefelem[9];

#define BOT58 ((p521_u64)0x3ffffffffffffffULL)
#define BOT57 ((p521_u64)0x1ffffffffffffffULL)
#define BOT52 ((p521_u64)0xfffffffffffffULL)

static const felem p521_kPrime = {
  0x03ffffffffffffffULL,0x03ffffffffffffffULL,0x03ffffffffffffffULL,
  0x03ffffffffffffffULL,0x03ffffffffffffffULL,0x03ffffffffffffffULL,
  0x03ffffffffffffffULL,0x03ffffffffffffffULL,0x01ffffffffffffffULL };

/* ---- conversions: canonical 9x64-bit limbs (value = sum in[i]*2^64i, little
   endian, <2^521) <-> reduced-radix felem (2^58 radix). Go via 66 LE bytes. */
static void limbs9_to_le66(unsigned char b[66],const p521_u64 in[9]){
  int j; for(j=0;j<66;j++) b[j]=(unsigned char)(in[j>>3]>>(8*(j&7)));
}
static void le66_to_limbs9(p521_u64 out[9],const unsigned char b[66]){
  int j; for(j=0;j<9;j++) out[j]=0;
  for(j=0;j<66;j++) out[j>>3]|=((p521_u64)b[j])<<(8*(j&7));
}
static void felem_from_le66(felem out,const unsigned char in[66]){
  /* read overlapping 58-bit windows (2 bits shift accumulates per group) */
  p521_u64 v; unsigned char t[72]; int i;
  memcpy(t,in,66); memset(t+66,0,6);
  #define RD(off) ((p521_u64)t[off]|((p521_u64)t[off+1]<<8)|((p521_u64)t[off+2]<<16)|((p521_u64)t[off+3]<<24)|((p521_u64)t[off+4]<<32)|((p521_u64)t[off+5]<<40)|((p521_u64)t[off+6]<<48)|((p521_u64)t[off+7]<<56))
  v=RD(0);  out[0]=v&BOT58;
  v=RD(7);  out[1]=(v>>2)&BOT58;
  v=RD(14); out[2]=(v>>4)&BOT58;
  v=RD(21); out[3]=(v>>6)&BOT58;
  v=RD(29); out[4]=v&BOT58;
  v=RD(36); out[5]=(v>>2)&BOT58;
  v=RD(43); out[6]=(v>>4)&BOT58;
  v=RD(50); out[7]=(v>>6)&BOT58;
  v=RD(58); out[8]=v&BOT57;
  (void)i;
  #undef RD
}
static void felem_to_le66(unsigned char out[66],const felem in){
  unsigned char t[72]; int j; for(j=0;j<72;j++)t[j]=0;
  #define WR(off,val) do{ p521_u64 _v=(val); int _k; for(_k=0;_k<8;_k++) t[off+_k]|=(unsigned char)(_v>>(8*_k)); }while(0)
  WR(0,in[0]); WR(7,in[1]<<2); WR(14,in[2]<<4); WR(21,in[3]<<6);
  WR(29,in[4]); WR(36,in[5]<<2); WR(43,in[6]<<4); WR(50,in[7]<<6); WR(58,in[8]);
  memcpy(out,t,66);
  #undef WR
}
static void felem_from_limbs(felem out,const p521_u64 in[9]){ unsigned char b[66]; limbs9_to_le66(b,in); felem_from_le66(out,b); }
static void felem_to_limbs(p521_u64 out[9],const felem in){ unsigned char b[66]; felem_to_le66(b,in); le66_to_limbs9(out,b); }

/* ---- field ops (ported structure; bounds per OpenSSL ecp_nistp521 comments) */
static void felem_assign(felem o,const felem a){ memcpy(o,a,sizeof(felem)); }
static void felem_one(felem o){ o[0]=1;o[1]=o[2]=o[3]=o[4]=o[5]=o[6]=o[7]=o[8]=0; }
static void felem_sum64(felem o,const felem a){ int i; for(i=0;i<9;i++)o[i]+=a[i]; }
static void felem_scalar(felem o,const felem a,p521_u64 s){ int i; for(i=0;i<9;i++)o[i]=a[i]*s; }
static void felem_scalar64(felem o,p521_u64 s){ int i; for(i=0;i<9;i++)o[i]*=s; }
static void felem_scalar128(largefelem o,p521_u64 s){ int i; for(i=0;i<9;i++)o[i]*=s; }
static void __attribute__((unused)) felem_neg(felem o,const felem a){
  const p521_u64 t3=(((p521_u64)1)<<62)-(((p521_u64)1)<<5), t2=(((p521_u64)1)<<62)-(((p521_u64)1)<<4);
  o[0]=t3-a[0]; o[1]=t2-a[1]; o[2]=t2-a[2]; o[3]=t2-a[3]; o[4]=t2-a[4];
  o[5]=t2-a[5]; o[6]=t2-a[6]; o[7]=t2-a[7]; o[8]=t2-a[8];
}
static void felem_diff64(felem o,const felem a){
  const p521_u64 t3=(((p521_u64)1)<<62)-(((p521_u64)1)<<5), t2=(((p521_u64)1)<<62)-(((p521_u64)1)<<4);
  o[0]+=t3-a[0]; o[1]+=t2-a[1]; o[2]+=t2-a[2]; o[3]+=t2-a[3]; o[4]+=t2-a[4];
  o[5]+=t2-a[5]; o[6]+=t2-a[6]; o[7]+=t2-a[7]; o[8]+=t2-a[8];
}
static void felem_diff_128_64(largefelem o,const felem a){
  const p521_u64 t6=(((p521_u64)1)<<63)-(((p521_u64)1)<<6), t5=(((p521_u64)1)<<63)-(((p521_u64)1)<<5);
  o[0]+=t6-a[0]; o[1]+=t5-a[1]; o[2]+=t5-a[2]; o[3]+=t5-a[3]; o[4]+=t5-a[4];
  o[5]+=t5-a[5]; o[6]+=t5-a[6]; o[7]+=t5-a[7]; o[8]+=t5-a[8];
}
static void felem_diff128(largefelem o,const largefelem a){
  const p521_u128 t70=(((p521_u128)1)<<127)-(((p521_u128)1)<<70), t69=(((p521_u128)1)<<127)-(((p521_u128)1)<<69);
  o[0]+=t70-a[0]; o[1]+=t69-a[1]; o[2]+=t69-a[2]; o[3]+=t69-a[3]; o[4]+=t69-a[4];
  o[5]+=t69-a[5]; o[6]+=t69-a[6]; o[7]+=t69-a[7]; o[8]+=t69-a[8];
}
static void felem_square(largefelem o,const felem in){
  felem x2,x4; felem_scalar(x2,in,2); felem_scalar(x4,in,4);
  o[0]=(p521_u128)in[0]*in[0];
  o[1]=(p521_u128)in[0]*x2[1];
  o[2]=(p521_u128)in[0]*x2[2]+(p521_u128)in[1]*in[1];
  o[3]=(p521_u128)in[0]*x2[3]+(p521_u128)in[1]*x2[2];
  o[4]=(p521_u128)in[0]*x2[4]+(p521_u128)in[1]*x2[3]+(p521_u128)in[2]*in[2];
  o[5]=(p521_u128)in[0]*x2[5]+(p521_u128)in[1]*x2[4]+(p521_u128)in[2]*x2[3];
  o[6]=(p521_u128)in[0]*x2[6]+(p521_u128)in[1]*x2[5]+(p521_u128)in[2]*x2[4]+(p521_u128)in[3]*in[3];
  o[7]=(p521_u128)in[0]*x2[7]+(p521_u128)in[1]*x2[6]+(p521_u128)in[2]*x2[5]+(p521_u128)in[3]*x2[4];
  o[8]=(p521_u128)in[0]*x2[8]+(p521_u128)in[1]*x2[7]+(p521_u128)in[2]*x2[6]+(p521_u128)in[3]*x2[5]+(p521_u128)in[4]*in[4];
  o[0]+=(p521_u128)in[1]*x4[8]+(p521_u128)in[2]*x4[7]+(p521_u128)in[3]*x4[6]+(p521_u128)in[4]*x4[5];
  o[1]+=(p521_u128)in[2]*x4[8]+(p521_u128)in[3]*x4[7]+(p521_u128)in[4]*x4[6]+(p521_u128)in[5]*x2[5];
  o[2]+=(p521_u128)in[3]*x4[8]+(p521_u128)in[4]*x4[7]+(p521_u128)in[5]*x4[6];
  o[3]+=(p521_u128)in[4]*x4[8]+(p521_u128)in[5]*x4[7]+(p521_u128)in[6]*x2[6];
  o[4]+=(p521_u128)in[5]*x4[8]+(p521_u128)in[6]*x4[7];
  o[5]+=(p521_u128)in[6]*x4[8]+(p521_u128)in[7]*x2[7];
  o[6]+=(p521_u128)in[7]*x4[8];
  o[7]+=(p521_u128)in[8]*x2[8];
}
static void felem_mul(largefelem o,const felem a,const felem b){
  felem b2; felem_scalar(b2,b,2);
  o[0]=(p521_u128)a[0]*b[0];
  o[1]=(p521_u128)a[0]*b[1]+(p521_u128)a[1]*b[0];
  o[2]=(p521_u128)a[0]*b[2]+(p521_u128)a[1]*b[1]+(p521_u128)a[2]*b[0];
  o[3]=(p521_u128)a[0]*b[3]+(p521_u128)a[1]*b[2]+(p521_u128)a[2]*b[1]+(p521_u128)a[3]*b[0];
  o[4]=(p521_u128)a[0]*b[4]+(p521_u128)a[1]*b[3]+(p521_u128)a[2]*b[2]+(p521_u128)a[3]*b[1]+(p521_u128)a[4]*b[0];
  o[5]=(p521_u128)a[0]*b[5]+(p521_u128)a[1]*b[4]+(p521_u128)a[2]*b[3]+(p521_u128)a[3]*b[2]+(p521_u128)a[4]*b[1]+(p521_u128)a[5]*b[0];
  o[6]=(p521_u128)a[0]*b[6]+(p521_u128)a[1]*b[5]+(p521_u128)a[2]*b[4]+(p521_u128)a[3]*b[3]+(p521_u128)a[4]*b[2]+(p521_u128)a[5]*b[1]+(p521_u128)a[6]*b[0];
  o[7]=(p521_u128)a[0]*b[7]+(p521_u128)a[1]*b[6]+(p521_u128)a[2]*b[5]+(p521_u128)a[3]*b[4]+(p521_u128)a[4]*b[3]+(p521_u128)a[5]*b[2]+(p521_u128)a[6]*b[1]+(p521_u128)a[7]*b[0];
  o[8]=(p521_u128)a[0]*b[8]+(p521_u128)a[1]*b[7]+(p521_u128)a[2]*b[6]+(p521_u128)a[3]*b[5]+(p521_u128)a[4]*b[4]+(p521_u128)a[5]*b[3]+(p521_u128)a[6]*b[2]+(p521_u128)a[7]*b[1]+(p521_u128)a[8]*b[0];
  o[0]+=(p521_u128)a[1]*b2[8]+(p521_u128)a[2]*b2[7]+(p521_u128)a[3]*b2[6]+(p521_u128)a[4]*b2[5]+(p521_u128)a[5]*b2[4]+(p521_u128)a[6]*b2[3]+(p521_u128)a[7]*b2[2]+(p521_u128)a[8]*b2[1];
  o[1]+=(p521_u128)a[2]*b2[8]+(p521_u128)a[3]*b2[7]+(p521_u128)a[4]*b2[6]+(p521_u128)a[5]*b2[5]+(p521_u128)a[6]*b2[4]+(p521_u128)a[7]*b2[3]+(p521_u128)a[8]*b2[2];
  o[2]+=(p521_u128)a[3]*b2[8]+(p521_u128)a[4]*b2[7]+(p521_u128)a[5]*b2[6]+(p521_u128)a[6]*b2[5]+(p521_u128)a[7]*b2[4]+(p521_u128)a[8]*b2[3];
  o[3]+=(p521_u128)a[4]*b2[8]+(p521_u128)a[5]*b2[7]+(p521_u128)a[6]*b2[6]+(p521_u128)a[7]*b2[5]+(p521_u128)a[8]*b2[4];
  o[4]+=(p521_u128)a[5]*b2[8]+(p521_u128)a[6]*b2[7]+(p521_u128)a[7]*b2[6]+(p521_u128)a[8]*b2[5];
  o[5]+=(p521_u128)a[6]*b2[8]+(p521_u128)a[7]*b2[7]+(p521_u128)a[8]*b2[6];
  o[6]+=(p521_u128)a[7]*b2[8]+(p521_u128)a[8]*b2[7];
  o[7]+=(p521_u128)a[8]*b2[8];
}
static void felem_reduce(felem out,const largefelem in){
  p521_u64 o1,o2; int i; largefelem t; for(i=0;i<9;i++)t[i]=in[i];
  out[0]=(p521_u64)t[0]&BOT58; out[1]=(p521_u64)t[1]&BOT58; out[2]=(p521_u64)t[2]&BOT58;
  out[3]=(p521_u64)t[3]&BOT58; out[4]=(p521_u64)t[4]&BOT58; out[5]=(p521_u64)t[5]&BOT58;
  out[6]=(p521_u64)t[6]&BOT58; out[7]=(p521_u64)t[7]&BOT58; out[8]=(p521_u64)t[8]&BOT58;
  out[1]+=(p521_u64)t[0]>>58; out[1]+=(((p521_u64)(t[0]>>64))&BOT52)<<6; out[2]+=((p521_u64)(t[0]>>64))>>52;
  out[2]+=(p521_u64)t[1]>>58; out[2]+=(((p521_u64)(t[1]>>64))&BOT52)<<6; out[3]+=((p521_u64)(t[1]>>64))>>52;
  out[3]+=(p521_u64)t[2]>>58; out[3]+=(((p521_u64)(t[2]>>64))&BOT52)<<6; out[4]+=((p521_u64)(t[2]>>64))>>52;
  out[4]+=(p521_u64)t[3]>>58; out[4]+=(((p521_u64)(t[3]>>64))&BOT52)<<6; out[5]+=((p521_u64)(t[3]>>64))>>52;
  out[5]+=(p521_u64)t[4]>>58; out[5]+=(((p521_u64)(t[4]>>64))&BOT52)<<6; out[6]+=((p521_u64)(t[4]>>64))>>52;
  out[6]+=(p521_u64)t[5]>>58; out[6]+=(((p521_u64)(t[5]>>64))&BOT52)<<6; out[7]+=((p521_u64)(t[5]>>64))>>52;
  out[7]+=(p521_u64)t[6]>>58; out[7]+=(((p521_u64)(t[6]>>64))&BOT52)<<6; out[8]+=((p521_u64)(t[6]>>64))>>52;
  out[8]+=(p521_u64)t[7]>>58; out[8]+=(((p521_u64)(t[7]>>64))&BOT52)<<6;
  o1=((p521_u64)(t[7]>>64))>>52;
  o1+=(p521_u64)t[8]>>58; o1+=(((p521_u64)(t[8]>>64))&BOT52)<<6; o2=((p521_u64)(t[8]>>64))>>52;
  o1<<=1; o2<<=1;
  out[0]+=o1; out[1]+=o2;
  out[1]+=out[0]>>58; out[0]&=BOT58;
}
static void __attribute__((unused)) felem_square_reduce(felem o,const felem a){ largefelem t; felem_square(t,a); felem_reduce(o,t); }
static void felem_mul_reduce(felem o,const felem a,const felem b){ largefelem t; felem_mul(t,a,b); felem_reduce(o,t); }
static void felem_inv(felem out,const felem in){
  felem ftmp,ftmp2,ftmp3,ftmp4; largefelem tmp; unsigned i;
  felem_square(tmp,in); felem_reduce(ftmp,tmp);
  felem_mul(tmp,in,ftmp); felem_reduce(ftmp,tmp);
  felem_assign(ftmp2,ftmp);
  felem_square(tmp,ftmp); felem_reduce(ftmp,tmp);
  felem_mul(tmp,in,ftmp); felem_reduce(ftmp,tmp);
  felem_square(tmp,ftmp); felem_reduce(ftmp,tmp);
  felem_square(tmp,ftmp2); felem_reduce(ftmp3,tmp);
  felem_square(tmp,ftmp3); felem_reduce(ftmp3,tmp);
  felem_mul(tmp,ftmp3,ftmp2); felem_reduce(ftmp3,tmp);
  felem_assign(ftmp2,ftmp3);
  felem_square(tmp,ftmp3); felem_reduce(ftmp3,tmp);
  felem_square(tmp,ftmp3); felem_reduce(ftmp3,tmp);
  felem_square(tmp,ftmp3); felem_reduce(ftmp3,tmp);
  felem_square(tmp,ftmp3); felem_reduce(ftmp3,tmp);
  felem_mul(tmp,ftmp3,ftmp); felem_reduce(ftmp4,tmp);
  felem_square(tmp,ftmp4); felem_reduce(ftmp4,tmp);
  felem_mul(tmp,ftmp3,ftmp2); felem_reduce(ftmp3,tmp);
  felem_assign(ftmp2,ftmp3);
  for(i=0;i<8;i++){ felem_square(tmp,ftmp3); felem_reduce(ftmp3,tmp); }
  felem_mul(tmp,ftmp3,ftmp2); felem_reduce(ftmp3,tmp); felem_assign(ftmp2,ftmp3);
  for(i=0;i<16;i++){ felem_square(tmp,ftmp3); felem_reduce(ftmp3,tmp); }
  felem_mul(tmp,ftmp3,ftmp2); felem_reduce(ftmp3,tmp); felem_assign(ftmp2,ftmp3);
  for(i=0;i<32;i++){ felem_square(tmp,ftmp3); felem_reduce(ftmp3,tmp); }
  felem_mul(tmp,ftmp3,ftmp2); felem_reduce(ftmp3,tmp); felem_assign(ftmp2,ftmp3);
  for(i=0;i<64;i++){ felem_square(tmp,ftmp3); felem_reduce(ftmp3,tmp); }
  felem_mul(tmp,ftmp3,ftmp2); felem_reduce(ftmp3,tmp); felem_assign(ftmp2,ftmp3);
  for(i=0;i<128;i++){ felem_square(tmp,ftmp3); felem_reduce(ftmp3,tmp); }
  felem_mul(tmp,ftmp3,ftmp2); felem_reduce(ftmp3,tmp); felem_assign(ftmp2,ftmp3);
  for(i=0;i<256;i++){ felem_square(tmp,ftmp3); felem_reduce(ftmp3,tmp); }
  felem_mul(tmp,ftmp3,ftmp2); felem_reduce(ftmp3,tmp);
  for(i=0;i<9;i++){ felem_square(tmp,ftmp3); felem_reduce(ftmp3,tmp); }
  felem_mul(tmp,ftmp3,ftmp4); felem_reduce(ftmp3,tmp);
  felem_mul(tmp,ftmp3,in); felem_reduce(out,tmp);
}
static p521_u64 felem_is_zero(const felem in){
  felem f; p521_u64 iz,ip; felem_assign(f,in);
  f[0]+=f[8]>>57; f[8]&=BOT57;
  f[1]+=f[0]>>58; f[0]&=BOT58; f[2]+=f[1]>>58; f[1]&=BOT58; f[3]+=f[2]>>58; f[2]&=BOT58;
  f[4]+=f[3]>>58; f[3]&=BOT58; f[5]+=f[4]>>58; f[4]&=BOT58; f[6]+=f[5]>>58; f[5]&=BOT58;
  f[7]+=f[6]>>58; f[6]&=BOT58; f[8]+=f[7]>>58; f[7]&=BOT58;
  iz=f[0]|f[1]|f[2]|f[3]|f[4]|f[5]|f[6]|f[7]|f[8]; iz--; iz=0-(iz>>63);
  ip=(f[0]^p521_kPrime[0])|(f[1]^p521_kPrime[1])|(f[2]^p521_kPrime[2])|(f[3]^p521_kPrime[3])
    |(f[4]^p521_kPrime[4])|(f[5]^p521_kPrime[5])|(f[6]^p521_kPrime[6])|(f[7]^p521_kPrime[7])|(f[8]^p521_kPrime[8]);
  ip--; ip=0-(ip>>63);
  return iz|ip;
}
static void felem_contract(felem out,const felem in){
  p521_u64 ip,ig,sg; const p521_u64 two58=((p521_u64)1)<<58; felem_assign(out,in);
  out[0]+=out[8]>>57; out[8]&=BOT57;
  out[1]+=out[0]>>58; out[0]&=BOT58; out[2]+=out[1]>>58; out[1]&=BOT58; out[3]+=out[2]>>58; out[2]&=BOT58;
  out[4]+=out[3]>>58; out[3]&=BOT58; out[5]+=out[4]>>58; out[4]&=BOT58; out[6]+=out[5]>>58; out[5]&=BOT58;
  out[7]+=out[6]>>58; out[6]&=BOT58; out[8]+=out[7]>>58; out[7]&=BOT58;
  ip=(out[0]^p521_kPrime[0])|(out[1]^p521_kPrime[1])|(out[2]^p521_kPrime[2])|(out[3]^p521_kPrime[3])
    |(out[4]^p521_kPrime[4])|(out[5]^p521_kPrime[5])|(out[6]^p521_kPrime[6])|(out[7]^p521_kPrime[7])|(out[8]^p521_kPrime[8]);
  ip--; ip&=ip<<32; ip&=ip<<16; ip&=ip<<8; ip&=ip<<4; ip&=ip<<2; ip&=ip<<1; ip=0-(ip>>63); ip=~ip;
  out[0]&=ip; out[1]&=ip; out[2]&=ip; out[3]&=ip; out[4]&=ip; out[5]&=ip; out[6]&=ip; out[7]&=ip; out[8]&=ip;
  ig=out[8]>>57; ig|=ig<<32; ig|=ig<<16; ig|=ig<<8; ig|=ig<<4; ig|=ig<<2; ig|=ig<<1; ig=0-(ig>>63);
  out[0]-=p521_kPrime[0]&ig; out[1]-=p521_kPrime[1]&ig; out[2]-=p521_kPrime[2]&ig; out[3]-=p521_kPrime[3]&ig;
  out[4]-=p521_kPrime[4]&ig; out[5]-=p521_kPrime[5]&ig; out[6]-=p521_kPrime[6]&ig; out[7]-=p521_kPrime[7]&ig; out[8]-=p521_kPrime[8]&ig;
  sg=-(out[0]>>63); out[0]+=two58&sg; out[1]-=1&sg;
  sg=-(out[1]>>63); out[1]+=two58&sg; out[2]-=1&sg;
  sg=-(out[2]>>63); out[2]+=two58&sg; out[3]-=1&sg;
  sg=-(out[3]>>63); out[3]+=two58&sg; out[4]-=1&sg;
  sg=-(out[4]>>63); out[4]+=two58&sg; out[5]-=1&sg;
  sg=-(out[5]>>63); out[5]+=two58&sg; out[6]-=1&sg;
  sg=-(out[6]>>63); out[6]+=two58&sg; out[7]-=1&sg;
  sg=-(out[7]>>63); out[7]+=two58&sg; out[8]-=1&sg;
}

/* ---- Jacobian point ops (dbl-2001-b / add-2007-bl on the reduced field) ---- */
static void p521_point_double(felem x_out,felem y_out,felem z_out,
                              const felem x_in,const felem y_in,const felem z_in){
  largefelem tmp,tmp2; felem delta,gamma,beta,alpha,ftmp,ftmp2;
  if(felem_is_zero(z_in)&1){ felem_assign(x_out,x_in); felem_assign(y_out,y_in); felem_assign(z_out,z_in); return; }
  felem_assign(ftmp,x_in); felem_assign(ftmp2,x_in);
  felem_square(tmp,z_in); felem_reduce(delta,tmp);
  felem_square(tmp,y_in); felem_reduce(gamma,tmp);
  felem_mul(tmp,x_in,gamma); felem_reduce(beta,tmp);
  felem_diff64(ftmp,delta); felem_sum64(ftmp2,delta); felem_scalar64(ftmp2,3);
  felem_mul(tmp,ftmp,ftmp2); felem_reduce(alpha,tmp);
  felem_square(tmp,alpha);
  felem_assign(ftmp,beta); felem_scalar64(ftmp,8);
  felem_diff_128_64(tmp,ftmp); felem_reduce(x_out,tmp);
  felem_sum64(delta,gamma);
  felem_assign(ftmp,y_in); felem_sum64(ftmp,z_in);
  felem_square(tmp,ftmp); felem_diff_128_64(tmp,delta); felem_reduce(z_out,tmp);
  felem_scalar64(beta,4); felem_diff64(beta,x_out);
  felem_mul(tmp,alpha,beta);
  felem_square(tmp2,gamma); felem_scalar128(tmp2,8);
  felem_diff128(tmp,tmp2); felem_reduce(y_out,tmp);
}
static void p521_copy_conditional(felem out,const felem in,p521_u64 mask){
  int i; for(i=0;i<9;i++){ p521_u64 t=mask&(in[i]^out[i]); out[i]^=t; }
}
/* (x1,y1,z1) + (x2,y2,z2); mixed => z2==1. Handles infinity via is_zero masks. */
static void p521_point_add(felem x3,felem y3,felem z3,
                           const felem x1,const felem y1,const felem z1,
                           int mixed,const felem x2,const felem y2,const felem z2){
  felem ftmp,ftmp2,ftmp3,ftmp4,ftmp5,ftmp6,x_out,y_out,z_out;
  largefelem tmp,tmp2; p521_u64 x_equal,y_equal,z1z,z2z,peq;
  z1z=felem_is_zero(z1); z2z=felem_is_zero(z2);
  felem_square(tmp,z1); felem_reduce(ftmp,tmp);
  if(!mixed){
    felem_square(tmp,z2); felem_reduce(ftmp2,tmp);
    felem_mul(tmp,x1,ftmp2); felem_reduce(ftmp3,tmp);
    felem_assign(ftmp5,z1); felem_sum64(ftmp5,z2);
    felem_square(tmp,ftmp5); felem_diff_128_64(tmp,ftmp); felem_diff_128_64(tmp,ftmp2); felem_reduce(ftmp5,tmp);
    felem_mul(tmp,ftmp2,z2); felem_reduce(ftmp2,tmp);
    felem_mul(tmp,y1,ftmp2); felem_reduce(ftmp6,tmp);
  } else {
    felem_assign(ftmp3,x1); felem_scalar(ftmp5,z1,2); felem_assign(ftmp6,y1);
  }
  felem_mul(tmp,x2,ftmp); felem_diff_128_64(tmp,ftmp3); felem_reduce(ftmp4,tmp);
  x_equal=felem_is_zero(ftmp4);
  felem_mul(tmp,ftmp5,ftmp4); felem_reduce(z_out,tmp);
  felem_mul(tmp,ftmp,z1); felem_reduce(ftmp,tmp);
  felem_mul(tmp,y2,ftmp); felem_diff_128_64(tmp,ftmp6); felem_reduce(ftmp5,tmp);
  y_equal=felem_is_zero(ftmp5); felem_scalar64(ftmp5,2);
  peq=(x_equal&y_equal&(~z1z)&(~z2z));
  if(peq&1){ p521_point_double(x3,y3,z3,x1,y1,z1); return; }
  felem_assign(ftmp,ftmp4); felem_scalar64(ftmp,2); felem_square(tmp,ftmp); felem_reduce(ftmp,tmp);
  felem_mul(tmp,ftmp4,ftmp); felem_reduce(ftmp2,tmp);
  felem_mul(tmp,ftmp3,ftmp); felem_reduce(ftmp4,tmp);
  felem_square(tmp,ftmp5); felem_diff_128_64(tmp,ftmp2);
  felem_assign(ftmp3,ftmp4); felem_scalar64(ftmp4,2); felem_diff_128_64(tmp,ftmp4); felem_reduce(x_out,tmp);
  felem_diff64(ftmp3,x_out);
  felem_mul(tmp,ftmp5,ftmp3);
  felem_mul(tmp2,ftmp6,ftmp2); felem_scalar128(tmp2,2);
  felem_diff128(tmp,tmp2); felem_reduce(y_out,tmp);
  p521_copy_conditional(x_out,x2,z1z); p521_copy_conditional(x_out,x1,z2z);
  p521_copy_conditional(y_out,y2,z1z); p521_copy_conditional(y_out,y1,z2z);
  p521_copy_conditional(z_out,z2,z1z); p521_copy_conditional(z_out,z1,z2z);
  felem_assign(x3,x_out); felem_assign(y3,y_out); felem_assign(z3,z_out);
}

/* ---- generator, comb, scalar multiplication ---- */
typedef struct { felem X,Y,Z; } p521pt;
typedef struct { felem x,y; } p521aff;

static const unsigned char P521_GX_BE[66]={0x00,0xc6,0x85,0x8e,0x06,0xb7,0x04,0x04,0xe9,0xcd,0x9e,0x3e,0xcb,0x66,0x23,0x95,0xb4,0x42,0x9c,0x64,0x81,0x39,0x05,0x3f,0xb5,0x21,0xf8,0x28,0xaf,0x60,0x6b,0x4d,0x3d,0xba,0xa1,0x4b,0x5e,0x77,0xef,0xe7,0x59,0x28,0xfe,0x1d,0xc1,0x27,0xa2,0xff,0xa8,0xde,0x33,0x48,0xb3,0xc1,0x85,0x6a,0x42,0x9b,0xf9,0x7e,0x7e,0x31,0xc2,0xe5,0xbd,0x66};
static const unsigned char P521_GY_BE[66]={0x01,0x18,0x39,0x29,0x6a,0x78,0x9a,0x3b,0xc0,0x04,0x5c,0x8a,0x5f,0xb4,0x2c,0x7d,0x1b,0xd9,0x98,0xf5,0x44,0x49,0x57,0x9b,0x44,0x68,0x17,0xaf,0xbd,0x17,0x27,0x3e,0x66,0x2c,0x97,0xee,0x72,0x99,0x5e,0xf4,0x26,0x40,0xc5,0x50,0xb9,0x01,0x3f,0xad,0x07,0x61,0x35,0x3c,0x70,0x86,0xa2,0x72,0xc2,0x40,0x88,0xbe,0x94,0x76,0x9f,0xd1,0x66,0x50};

#define P521_NWIN 131
static p521aff p521_comb[P521_NWIN][16];
static felem p521_Gx, p521_Gy;
static int p521_inited=0;

static void be66_to_felem(felem out,const unsigned char be[66]){
  unsigned char le[66]; int i; for(i=0;i<66;i++) le[i]=be[65-i]; felem_from_le66(out,le);
}
/* Montgomery-trick batch normalize pts[0..n-1] to affine (Z=1). */
static void p521_batch_affine(p521pt *pts,int n){
  felem prefix[16],inv,zi,zi2,zi3; int i;
  felem_assign(prefix[0],pts[0].Z);
  for(i=1;i<n;i++) felem_mul_reduce(prefix[i],prefix[i-1],pts[i].Z);
  felem_inv(inv,prefix[n-1]);
  for(i=n-1;i>=0;i--){
    if(i>0){ felem_mul_reduce(zi,inv,prefix[i-1]); felem_mul_reduce(inv,inv,pts[i].Z); } else felem_assign(zi,inv);
    felem_mul_reduce(zi2,zi,zi); felem_mul_reduce(zi3,zi2,zi);
    felem_mul_reduce(pts[i].X,pts[i].X,zi2); felem_mul_reduce(pts[i].Y,pts[i].Y,zi3);
    felem_one(pts[i].Z);
  }
}
static void p521_set_id(p521pt *P){ int i; for(i=0;i<9;i++){P->X[i]=0;P->Y[i]=0;P->Z[i]=0;} P->X[0]=1; P->Y[0]=1; }
static void p521_init(void){
  p521pt tbl[16]; felem base_x,base_y,base_z; int i,d;
  if(p521_inited) return;
  be66_to_felem(p521_Gx,P521_GX_BE); be66_to_felem(p521_Gy,P521_GY_BE);
  felem_assign(base_x,p521_Gx); felem_assign(base_y,p521_Gy); felem_one(base_z);
  for(i=0;i<P521_NWIN;i++){
    /* tbl[d] = d * base (d=1..15), projective */
    felem_assign(tbl[1].X,base_x); felem_assign(tbl[1].Y,base_y); felem_assign(tbl[1].Z,base_z);
    for(d=2;d<16;d++) p521_point_add(tbl[d].X,tbl[d].Y,tbl[d].Z, tbl[d-1].X,tbl[d-1].Y,tbl[d-1].Z, 0, base_x,base_y,base_z);
    p521_batch_affine(&tbl[1],15);
    for(d=1;d<16;d++){ felem_assign(p521_comb[i][d].x,tbl[d].X); felem_assign(p521_comb[i][d].y,tbl[d].Y); }
    if(i+1<P521_NWIN){ /* base *= 2^4 */
      p521_point_double(base_x,base_y,base_z, base_x,base_y,base_z);
      p521_point_double(base_x,base_y,base_z, base_x,base_y,base_z);
      p521_point_double(base_x,base_y,base_z, base_x,base_y,base_z);
      p521_point_double(base_x,base_y,base_z, base_x,base_y,base_z);
    }
  }
  p521_inited=1;
}
static void aff_cmov(p521aff *r,const p521aff *a,p521_u64 b){
  p521_u64 m=0-b; int i; for(i=0;i<9;i++){ r->x[i]^=m&(r->x[i]^a->x[i]); r->y[i]^=m&(r->y[i]^a->y[i]); }
}
static void pt_cmov3(p521pt *r,const p521pt *a,p521_u64 b){
  p521_u64 m=0-b; int i; for(i=0;i<9;i++){ r->X[i]^=m&(r->X[i]^a->X[i]); r->Y[i]^=m&(r->Y[i]^a->Y[i]); r->Z[i]^=m&(r->Z[i]^a->Z[i]); }
}
static int nib_at(const p521_u64 k[9],int i){ int b=4*i; return (int)((k[b>>6]>>(b&63))&0xf); }
/* k*G via comb (fixed base): 131 windows, one masked mixed add each, no doublings */
static void p521_scalarmult_base(p521pt *R,const p521_u64 k[9]){
  p521aff sel; p521pt acc,tmp; int i,d; p521_u64 m;
  p521_set_id(&acc);
  for(i=0;i<P521_NWIN;i++){
    int nib=nib_at(k,i);
    sel=p521_comb[i][1];
    for(d=2;d<16;d++){ m=(p521_u64)((d^nib)==0); aff_cmov(&sel,&p521_comb[i][d],m); }
    { felem one; felem_one(one); p521_point_add(tmp.X,tmp.Y,tmp.Z, acc.X,acc.Y,acc.Z, 1, sel.x,sel.y,one); }
    m=(p521_u64)(nib!=0); pt_cmov3(&acc,&tmp,m);
  }
  *R=acc;
}
/* k*P via width-4 window (variable base) */
static void p521_scalarmult_var(p521pt *R,const p521_u64 k[9],const felem px,const felem py){
  p521pt T[16],acc,tmp,sel; int i,d,top; p521_u64 m; felem one; felem_one(one);
  p521_set_id(&T[0]);
  felem_assign(T[1].X,px); felem_assign(T[1].Y,py); felem_one(T[1].Z);
  for(i=2;i<16;i++) p521_point_add(T[i].X,T[i].Y,T[i].Z, T[i-1].X,T[i-1].Y,T[i-1].Z, 1, px,py,one);
  p521_batch_affine(&T[1],15);
  p521_set_id(&acc);
  top=P521_NWIN-1;
  for(i=top;i>=0;i--){
    int nib=nib_at(k,i);
    p521_point_double(acc.X,acc.Y,acc.Z, acc.X,acc.Y,acc.Z);
    p521_point_double(acc.X,acc.Y,acc.Z, acc.X,acc.Y,acc.Z);
    p521_point_double(acc.X,acc.Y,acc.Z, acc.X,acc.Y,acc.Z);
    p521_point_double(acc.X,acc.Y,acc.Z, acc.X,acc.Y,acc.Z);
    sel=T[1];
    for(d=2;d<16;d++){ m=(p521_u64)((d^nib)==0); pt_cmov3(&sel,&T[d],m); }
    p521_point_add(tmp.X,tmp.Y,tmp.Z, acc.X,acc.Y,acc.Z, 1, sel.X,sel.Y,one);
    m=(p521_u64)(nib!=0); pt_cmov3(&acc,&tmp,m);
  }
  *R=acc;
}
static int p521_to_affine(p521_u64 x[9],p521_u64 y[9],const p521pt *P){
  felem zi,zi2,zi3,xa,ya,xc,yc;
  if(felem_is_zero(P->Z)&1) return 0;
  felem_inv(zi,P->Z); felem_mul_reduce(zi2,zi,zi); felem_mul_reduce(zi3,zi2,zi);
  felem_mul_reduce(xa,P->X,zi2); felem_mul_reduce(ya,P->Y,zi3);
  felem_contract(xc,xa); felem_contract(yc,ya);
  felem_to_limbs(x,xc); felem_to_limbs(y,yc); return 1;
}

/* ---- public helpers called from rktcrypto_ecc.c (canonical 9x64-bit limbs) ---- */
int p521rr_base_affine(p521_u64 x[9],p521_u64 y[9],const p521_u64 k[9]){
  p521pt R; p521_init(); p521_scalarmult_base(&R,k); return p521_to_affine(x,y,&R);
}
int p521rr_var_affine(p521_u64 x[9],p521_u64 y[9],const p521_u64 k[9],const p521_u64 px[9],const p521_u64 py[9]){
  p521pt R; felem fx,fy; p521_init(); felem_from_limbs(fx,px); felem_from_limbs(fy,py);
  p521_scalarmult_var(&R,k,fx,fy); return p521_to_affine(x,y,&R);
}
int p521rr_double_affine(p521_u64 x[9],p521_u64 y[9],const p521_u64 u1[9],const p521_u64 u2[9],const p521_u64 qx[9],const p521_u64 qy[9]){
  p521pt R1,R2,R3; felem fx,fy; p521_init();
  p521_scalarmult_base(&R1,u1);
  felem_from_limbs(fx,qx); felem_from_limbs(fy,qy); p521_scalarmult_var(&R2,u2,fx,fy);
  p521_point_add(R3.X,R3.Y,R3.Z, R1.X,R1.Y,R1.Z, 0, R2.X,R2.Y,R2.Z);
  return p521_to_affine(x,y,&R3);
}
