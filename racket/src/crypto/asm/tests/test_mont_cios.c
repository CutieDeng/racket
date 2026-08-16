/* Differential gate for the generic CIOS Montgomery multiply kernel
   (asm/mont_cios.asm -> rktcrypto_mont_cios_asm.S) against a portable
   reference identical to rktcrypto_ecc.c's montmul. Random odd moduli and
   reduced operands at the brainpool widths nl = 4/6/8 (and 5/7 for good
   measure). Prints "<n>/<total> mismatches" and PASS/FAIL.
   Build: cc -O2 test_mont_cios.c rktcrypto_mont_cios_asm.S */
#include <stdio.h>
#include <stdint.h>
#include <time.h>
typedef uint64_t u64; typedef unsigned __int128 u128;
#define MAXL 9

/* ns clock (CLOCK_MONOTONIC; works on Apple and the ELF shim) */
static double now_ns(void){ struct timespec ts; clock_gettime(CLOCK_MONOTONIC,&ts);
  return (double)ts.tv_sec*1e9 + (double)ts.tv_nsec; }

extern void mont_cios_asm(u64 *r,const u64 *a,const u64 *b,const u64 *m,
                          u64 n0,intptr_t nl,u64 *t);

/* reference: byte-for-byte the algorithm in rktcrypto_ecc.c */
static void montmul_ref(u64 *r,const u64 *a,const u64 *b,const u64 *m,u64 n0,int nl){
  u64 t[MAXL+2]; int i,j; for(i=0;i<nl+2;i++) t[i]=0;
  for(i=0;i<nl;i++){
    u64 c=0; u128 p;
    for(j=0;j<nl;j++){ p=(u128)a[j]*b[i]+t[j]+c; t[j]=(u64)p; c=(u64)(p>>64); }
    { u128 s=(u128)t[nl]+c; t[nl]=(u64)s; t[nl+1]=(u64)(s>>64); }
    { u64 mm=(u64)((u128)t[0]*n0); u64 cc=0;
      p=(u128)mm*m[0]+t[0]; cc=(u64)(p>>64);
      for(j=1;j<nl;j++){ p=(u128)mm*m[j]+t[j]+cc; t[j-1]=(u64)p; cc=(u64)(p>>64); }
      { u128 s=(u128)t[nl]+cc; t[nl-1]=(u64)s; t[nl]=t[nl+1]+(u64)(s>>64); }
    }
  }
  { u64 tmp[MAXL]; u64 borrow; int k;
    borrow=0; for(k=0;k<nl;k++){ u128 d=(u128)t[k]-m[k]-borrow; tmp[k]=(u64)d; borrow=(u64)((d>>64)&1); }
    borrow = (t[nl]!=0) ? 0 : borrow;
    if(borrow==0){ for(k=0;k<nl;k++) r[k]=tmp[k]; } else { for(k=0;k<nl;k++) r[k]=t[k]; }
    for(k=nl;k<MAXL;k++) r[k]=0;
  }
}
static u64 mont_n0(u64 m0){ u64 x=1; int i; for(i=0;i<6;i++) x*=2-m0*x; return (u64)(0-x); }

/* deterministic PRNG (splitmix64) so the gate is reproducible */
static u64 st=0x9e3779b97f4a7c15ULL;
static u64 rnd(void){ u64 z=(st+=0x9e3779b97f4a7c15ULL);
  z=(z^(z>>30))*0xbf58476d1ce4e5b9ULL; z=(z^(z>>27))*0x94d049bb133111ebULL; return z^(z>>31); }

/* r = a mod m (schoolbook), nl limbs; m has its top limb's high bit set */
static int bn_cmp(const u64*a,const u64*b,int nl){ int i; for(i=nl-1;i>=0;i--){ if(a[i]!=b[i]) return a[i]<b[i]?-1:1; } return 0; }
static void bn_sub(u64*r,const u64*a,const u64*b,int nl){ u128 br=0; int i; for(i=0;i<nl;i++){ u128 d=(u128)a[i]-b[i]-br; r[i]=(u64)d; br=(d>>64)&1; } }
static void reduce(u64*a,const u64*m,int nl){ while(bn_cmp(a,m,nl)>=0) bn_sub(a,a,m,nl); }

int main(void){
  int widths[]={4,5,6,7,8}; int nw=5;
  long total=0, bad=0;
  for(int wi=0; wi<nw; wi++){
    int nl=widths[wi];
    for(int it=0; it<20000; it++){
      u64 m[MAXL],a[MAXL],b[MAXL],r1[MAXL],r2[MAXL],t[MAXL+2];
      for(int i=0;i<nl;i++) m[i]=rnd();
      m[0]|=1ULL;                 /* odd */
      m[nl-1]|=0x8000000000000000ULL; /* full width so a,b<m<R */
      for(int i=0;i<nl;i++){ a[i]=rnd(); b[i]=rnd(); }
      reduce(a,m,nl); reduce(b,m,nl);
      u64 n0=mont_n0(m[0]);
      montmul_ref(r1,a,b,m,n0,nl);
      mont_cios_asm(r2,a,b,m,n0,(intptr_t)nl,t);
      total++;
      for(int i=0;i<nl;i++){ if(r1[i]!=r2[i]){ bad++;
        if(bad<=3){ fprintf(stderr,"MISMATCH nl=%d it=%d limb %d: ref=%016llx asm=%016llx\n",
                            nl,it,i,(unsigned long long)r1[i],(unsigned long long)r2[i]); }
        break; } }
    }
  }
  printf("%ld/%ld mismatches\n", bad, total);
  printf("%s\n", bad?"FAIL":"PASS");

  /* --- perf (BENCH <key>: ns/op) for the brainpool field-mul widths --- */
  { const int W[3]={4,6,8}; const long ITERS=2000000, WARM=100000;
    for(int wi=0; wi<3; wi++){ int nl=W[wi];
      u64 m[MAXL],a[MAXL],b[MAXL],r[MAXL],t[MAXL+2];
      for(int i=0;i<nl;i++){ m[i]=rnd(); a[i]=rnd(); b[i]=rnd(); }
      m[0]|=1ULL; m[nl-1]|=0x8000000000000000ULL; reduce(a,m,nl); reduce(b,m,nl);
      u64 n0=mont_n0(m[0]);
      for(long i=0;i<WARM;i++){ mont_cios_asm(r,a,b,m,n0,(intptr_t)nl,t); a[0]^=r[0]; }
      double t0=now_ns();
      for(long i=0;i<ITERS;i++){ mont_cios_asm(r,a,b,m,n0,(intptr_t)nl,t); a[0]^=r[0]; }
      double t1=now_ns();
      printf("BENCH mont_cios_nl%d: %.3f ns/op\n", nl, (t1-t0)/(double)ITERS);
    }
  }
  return bad?1:0;
}
