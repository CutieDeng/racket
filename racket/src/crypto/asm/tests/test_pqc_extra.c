/* test_pqc_extra.c - conformance tests for previously-untested PQC entry points.
 *
 * Covers the sibling parameter sets and SLH-DSA that had ZERO coverage:
 *   - ML-KEM-512  and ML-KEM-1024  : keypair / encaps / decaps (+ derand variants)
 *   - ML-DSA-44   and ML-DSA-87    : keypair / sign / verify   (+ derand variants)
 *   - SLH-DSA-SHAKE-128s           : keygen / sign / verify     (+ derand keygen)
 *
 * ORACLE MODE: SELF-CONSISTENCY KATs.
 *   Python `cryptography` 49.0.0 (the only oracle available offline here) does
 *   NOT expose ml_kem / ml_dsa / slh_dsa, and no NIST ACVP/FIPS-203/204/205
 *   known-answer vectors were available offline. We therefore assert internal
 *   consistency rather than interop:
 *     KEM: keypair -> encaps -> decaps recovers the encapsulator's shared
 *          secret; flipping a ciphertext byte yields a DIFFERENT secret
 *          (implicit rejection) that is never the original.
 *     SIG: keypair -> sign(msg) -> verify accepts; a tampered message and a
 *          mangled signature are both rejected.
 *     DERAND: where deterministic variants exist, a fixed seed produces
 *          byte-identical output across two independent calls (catches
 *          uninitialized-memory / RNG-plumbing bugs the roundtrip misses).
 *
 * Convention: one OK/FAIL line per (algorithm,paramset); final line is exactly
 * "ALL PASS" or "FAILURES"; process exits nonzero on any failure.
 *
 * Return conventions verified from the impl headers:
 *   keypair / encaps / decaps / sign  -> 1 on success, 0 on failure
 *   verify                            -> 1 = valid, 0 = invalid
 */
#include "rktcrypto.h"
#include <stdio.h>
#include <string.h>

static int g_failures = 0;

static void report(const char *name, int ok) {
    printf("%-22s %s\n", name, ok ? "OK" : "FAIL");
    if (!ok) g_failures++;
}

/* ------------------------------------------------------------------ ML-KEM */
#define KEM_TEST(FNNAME, PFX, LABEL, PKB, SKB, CTB, SSB)                       \
static int FNNAME(void) {                                                      \
    unsigned char pk[PKB], sk[SKB], ct[CTB], ss_a[SSB], ss_b[SSB];            \
    int ok = 1;                                                                \
    /* random roundtrip: encaps secret == decaps secret */                    \
    if (PFX##_keypair(pk, sk) != 1) ok = 0;                                    \
    if (ok && PFX##_encaps(ct, ss_a, pk) != 1) ok = 0;                         \
    if (ok && PFX##_decaps(ss_b, ct, sk) != 1) ok = 0;                         \
    if (ok && memcmp(ss_a, ss_b, SSB) != 0) ok = 0;                            \
    /* implicit rejection: flipped ciphertext -> different, never-original */  \
    if (ok) {                                                                  \
        unsigned char ctx[CTB], ss_r[SSB];                                     \
        memcpy(ctx, ct, CTB);                                                  \
        ctx[CTB / 2] ^= 0x01;                                                  \
        if (PFX##_decaps(ss_r, ctx, sk) != 1) ok = 0;                          \
        if (ok && memcmp(ss_r, ss_a, SSB) == 0) ok = 0; /* leaked real ss */   \
    }                                                                          \
    /* derand determinism: fixed coins -> identical keypair */                \
    if (ok) {                                                                  \
        unsigned char coins[64], pk1[PKB], sk1[SKB], pk2[PKB], sk2[SKB];       \
        unsigned char m[32], ct1[CTB], s1[SSB], ct2[CTB], s2[SSB];             \
        int i;                                                                 \
        for (i = 0; i < 64; i++) coins[i] = (unsigned char)(i * 7 + 1);        \
        for (i = 0; i < 32; i++) m[i] = (unsigned char)(0xA5 ^ i);             \
        if (PFX##_keypair_derand(pk1, sk1, coins) != 1) ok = 0;                \
        if (ok && PFX##_keypair_derand(pk2, sk2, coins) != 1) ok = 0;          \
        if (ok && (memcmp(pk1, pk2, PKB) || memcmp(sk1, sk2, SKB))) ok = 0;    \
        /* derand encaps determinism + decaps consistency under fixed m */     \
        if (ok && PFX##_enc_derand(ct1, s1, pk1, m) != 1) ok = 0;              \
        if (ok && PFX##_enc_derand(ct2, s2, pk1, m) != 1) ok = 0;              \
        if (ok && (memcmp(ct1, ct2, CTB) || memcmp(s1, s2, SSB))) ok = 0;      \
        if (ok && PFX##_decaps(ss_b, ct1, sk1) != 1) ok = 0;                   \
        if (ok && memcmp(ss_b, s1, SSB) != 0) ok = 0;                          \
    }                                                                          \
    report(LABEL, ok);                                                         \
    return ok;                                                                 \
}

KEM_TEST(test_mlkem512, rktcrypto_mlkem512, "ML-KEM-512",
         RKTCRYPTO_MLKEM512_PUBLICKEYBYTES, RKTCRYPTO_MLKEM512_SECRETKEYBYTES,
         RKTCRYPTO_MLKEM512_CIPHERTEXTBYTES, RKTCRYPTO_MLKEM512_BYTES)
KEM_TEST(test_mlkem1024, rktcrypto_mlkem1024, "ML-KEM-1024",
         RKTCRYPTO_MLKEM1024_PUBLICKEYBYTES, RKTCRYPTO_MLKEM1024_SECRETKEYBYTES,
         RKTCRYPTO_MLKEM1024_CIPHERTEXTBYTES, RKTCRYPTO_MLKEM1024_BYTES)

/* ------------------------------------------------------------------ ML-DSA */
#define DSA_TEST(FNNAME, PFX, LABEL, PKB, SKB, SIGB)                           \
static int FNNAME(void) {                                                      \
    static unsigned char pk[PKB], sk[SKB], sig[SIGB];                          \
    const unsigned char msg[] = "rktcrypto ML-DSA self-consistency KAT";       \
    const intptr_t mlen = (intptr_t)sizeof(msg) - 1;                           \
    int ok = 1;                                                                \
    if (PFX##_keypair(pk, sk) != 1) ok = 0;                                    \
    if (ok && PFX##_sign(sig, msg, mlen, sk) != 1) ok = 0;                     \
    if (ok && PFX##_verify(sig, msg, mlen, pk) != 1) ok = 0; /* accept */      \
    /* reject tampered message */                                             \
    if (ok) {                                                                  \
        unsigned char bad[sizeof(msg)];                                        \
        memcpy(bad, msg, sizeof(msg));                                         \
        bad[0] ^= 0x01;                                                        \
        if (PFX##_verify(sig, bad, mlen, pk) != 0) ok = 0;                     \
    }                                                                          \
    /* reject mangled signature */                                            \
    if (ok) {                                                                  \
        unsigned char sbad[SIGB];                                              \
        memcpy(sbad, sig, SIGB);                                               \
        sbad[SIGB / 2] ^= 0x01;                                                \
        if (PFX##_verify(sbad, msg, mlen, pk) != 0) ok = 0;                    \
    }                                                                          \
    /* derand determinism: fixed seed -> identical keypair; fixed sk ->        \
       identical signature (ML-DSA hedged sign is randomized; _derand is not) */\
    if (ok) {                                                                  \
        static unsigned char pk1[PKB], sk1[SKB], pk2[PKB], sk2[SKB];           \
        static unsigned char sig1[SIGB], sig2[SIGB];                           \
        unsigned char seed[32];                                                \
        int i;                                                                 \
        for (i = 0; i < 32; i++) seed[i] = (unsigned char)(0x3C + i);          \
        if (PFX##_keypair_derand(pk1, sk1, seed) != 1) ok = 0;                 \
        if (ok && PFX##_keypair_derand(pk2, sk2, seed) != 1) ok = 0;           \
        if (ok && (memcmp(pk1, pk2, PKB) || memcmp(sk1, sk2, SKB))) ok = 0;    \
        if (ok && PFX##_sign_derand(sig1, msg, mlen, sk1) != 1) ok = 0;        \
        if (ok && PFX##_sign_derand(sig2, msg, mlen, sk1) != 1) ok = 0;        \
        if (ok && memcmp(sig1, sig2, SIGB) != 0) ok = 0;                       \
        if (ok && PFX##_verify(sig1, msg, mlen, pk1) != 1) ok = 0;             \
    }                                                                          \
    report(LABEL, ok);                                                         \
    return ok;                                                                 \
}

DSA_TEST(test_mldsa44, rktcrypto_mldsa44, "ML-DSA-44",
         RKTCRYPTO_MLDSA44_PUBLICKEYBYTES, RKTCRYPTO_MLDSA44_SECRETKEYBYTES,
         RKTCRYPTO_MLDSA44_SIGBYTES)
DSA_TEST(test_mldsa87, rktcrypto_mldsa87, "ML-DSA-87",
         RKTCRYPTO_MLDSA87_PUBLICKEYBYTES, RKTCRYPTO_MLDSA87_SECRETKEYBYTES,
         RKTCRYPTO_MLDSA87_SIGBYTES)

/* --------------------------------------------------------------- SLH-DSA */
static int test_slhdsa_128s(void) {
    enum {
        PKB  = RKTCRYPTO_SLHDSA_128S_PUBLICKEYBYTES,
        SKB  = RKTCRYPTO_SLHDSA_128S_SECRETKEYBYTES,
        SIGB = RKTCRYPTO_SLHDSA_128S_SIGBYTES
    };
    static unsigned char pk[PKB], sk[SKB], sig[SIGB];
    const unsigned char msg[] = "rktcrypto SLH-DSA-SHAKE-128s self-consistency KAT";
    const intptr_t mlen = (intptr_t)sizeof(msg) - 1;
    int ok = 1;

    if (rktcrypto_slhdsa_shake_128s_keygen(pk, sk) != 1) ok = 0;
    if (ok && rktcrypto_slhdsa_shake_128s_sign(sig, msg, mlen, sk) != 1) ok = 0;
    if (ok && rktcrypto_slhdsa_shake_128s_verify(sig, SIGB, msg, mlen, pk) != 1) ok = 0;

    /* reject tampered message */
    if (ok) {
        unsigned char bad[sizeof(msg)];
        memcpy(bad, msg, sizeof(msg));
        bad[3] ^= 0x01;
        if (rktcrypto_slhdsa_shake_128s_verify(sig, SIGB, bad, mlen, pk) != 0) ok = 0;
    }
    /* reject mangled signature */
    if (ok) {
        static unsigned char sbad[SIGB];
        memcpy(sbad, sig, SIGB);
        sbad[SIGB / 2] ^= 0x01;
        if (rktcrypto_slhdsa_shake_128s_verify(sbad, SIGB, msg, mlen, pk) != 0) ok = 0;
    }
    /* derand keygen determinism: fixed 48-byte seed -> identical keypair.
       SLH-DSA signing here is deterministic, so sign is stable too. */
    if (ok) {
        static unsigned char pk1[PKB], sk1[SKB], pk2[PKB], sk2[SKB];
        static unsigned char sig1[SIGB], sig2[SIGB];
        unsigned char seed48[48];
        int i;
        for (i = 0; i < 48; i++) seed48[i] = (unsigned char)(0x11 * (i + 1));
        if (rktcrypto_slhdsa_shake_128s_keygen_derand(pk1, sk1, seed48) != 1) ok = 0;
        if (ok && rktcrypto_slhdsa_shake_128s_keygen_derand(pk2, sk2, seed48) != 1) ok = 0;
        if (ok && (memcmp(pk1, pk2, PKB) || memcmp(sk1, sk2, SKB))) ok = 0;
        if (ok && rktcrypto_slhdsa_shake_128s_sign(sig1, msg, mlen, sk1) != 1) ok = 0;
        if (ok && rktcrypto_slhdsa_shake_128s_sign(sig2, msg, mlen, sk1) != 1) ok = 0;
        if (ok && memcmp(sig1, sig2, SIGB) != 0) ok = 0;
        if (ok && rktcrypto_slhdsa_shake_128s_verify(sig1, SIGB, msg, mlen, pk1) != 1) ok = 0;
    }
    report("SLH-DSA-SHAKE-128s", ok);
    return ok;
}

int main(void) {
    printf("PQC extra conformance (self-consistency KATs)\n");
    test_mlkem512();
    test_mlkem1024();
    test_mldsa44();
    test_mldsa87();
    test_slhdsa_128s();
    if (g_failures) {
        printf("FAILURES\n");
        return 1;
    }
    printf("ALL PASS\n");
    return 0;
}
