/* test_kdf_aesmodes.c -- conformance tests for KDF and AES-mode entry points
 * in librktcrypto that lacked direct coverage.
 *
 * Build (from the crypto dir):
 *   cc -O2 -I. -o /tmp/tk asm/tests/test_kdf_aesmodes.c \
 *      ../build/cs/c/rktcrypto/librktcrypto.a
 *   /tmp/tk
 *
 * KAT sources
 * -----------
 * Group 1 -- KDFs (public, rktcrypto.h)
 *   scrypt      : RFC 7914 section 12 published vector
 *                 scrypt("password","NaCl", N=1024, r=8, p=16, dkLen=64).
 *                 Cross-checked against python `cryptography` 49 Scrypt.
 *   x963kdf     : python `cryptography` 49 X963KDF (SHA-256) interop vector.
 *   sskdf       : SP 800-56C one-step hash KDF. python `cryptography` has no
 *                 SSKDF, so the expected bytes come from a SELF-CONTAINED
 *                 reference computed with an INDEPENDENT oracle (python
 *                 hashlib SHA-256): out = H(ctr32 || Z || info) repeated with a
 *                 big-endian 32-bit counter starting at 1. This matches the
 *                 implementation's documented construction.
 *   kbkdf_hmac  : python `cryptography` 49 KBKDFHMAC, CounterMode,
 *                 CounterLocation.BeforeFixed, SHA-256, rlen=4, llen=4
 *                 (fixed input = counter||label||0x00||context||L-in-bits).
 *
 * Group 2 -- AES modes (internal to the archive; prototypes declared below)
 *   AES-XTS  : python `cryptography` 49 Cipher(AES(key1||key2), XTS(tweak)).
 *              Block-aligned (48 B) and ciphertext-stealing (20 B) cases.
 *   AES-CMAC : NIST SP 800-38B example (key 2b7e1516..., single block);
 *              matches python `cryptography` cmac. Includes NEGATIVE check.
 *   AES-GMAC : GMAC == AES-GCM tag over msg-as-AAD with empty plaintext,
 *              from python AESGCM/Cipher+GCM. Includes NEGATIVE check.
 *
 * Output: one OK/FAIL line per function; final line "ALL PASS" or "FAILURES";
 * nonzero exit on any failure.
 */

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include "rktcrypto.h"

/* ---- prototypes for the INTERNAL AES-mode functions (from
 *      rktcrypto_cipher.h / rktcrypto_aes_modes.c / rktcrypto_gcm.c). These are
 *      linkable from the archive but not part of rktcrypto.h. ---- */
void rktcrypto_aes_cmac(const unsigned char *key, intptr_t keylen,
                        const unsigned char *msg, intptr_t len, unsigned char tag[16]);
void rktcrypto_aes_xts(const unsigned char *key, intptr_t keylen, const unsigned char iv[16],
                       const unsigned char *in, unsigned char *out, intptr_t len, int encrypt);
void rktcrypto_aes_gmac(const unsigned char *key, intptr_t keylen, const unsigned char iv[12],
                        const unsigned char *msg, intptr_t len, unsigned char tag[16]);

static int failures = 0;

static void report(const char *name, int ok) {
    printf("%s %s\n", ok ? "OK  " : "FAIL", name);
    if (!ok) failures++;
}

static int eq(const unsigned char *a, const unsigned char *b, size_t n) {
    return memcmp(a, b, n) == 0;
}

/* ================= generated reference vectors ================= */

// scrypt N=1024 r=8 p=16 pw=password salt=NaCl (RFC7914 sec12)
static const unsigned char SCRYPT_PW[8] = {112,97,115,115,119,111,114,100};
static const unsigned char SCRYPT_SALT[4] = {78,97,67,108};
static const unsigned char SCRYPT_EXP[64] = {253,186,190,28,157,52,114,0,120,86,231,25,13,1,233,254,124,106,215,203,200,35,120,48,231,115,118,99,75,55,49,98,46,175,48,217,46,34,163,136,111,241,9,39,157,152,48,218,199,39,175,185,74,131,238,109,131,96,203,223,162,204,6,64};
// x963kdf SHA256 (python cryptography oracle)
static const unsigned char X963_Z[24] = {34,81,139,16,231,15,42,63,36,56,16,174,50,84,19,158,251,238,4,170,87,199,175,125};
static const unsigned char X963_INFO[16] = {117,238,248,26,163,4,30,51,184,9,113,32,61,44,12,82};
static const unsigned char X963_EXP[48] = {196,152,175,119,22,28,197,159,41,98,185,167,19,226,178,21,21,45,19,151,102,206,52,167,118,223,17,134,106,105,191,46,82,161,61,156,124,111,200,120,197,12,94,160,188,123,0,224};
// sskdf SHA256 (self-contained hashlib reference: H(ctr32||Z||info))
static const unsigned char SSKDF_Z[16] = {63,137,43,216,184,77,174,100,167,130,163,95,110,170,143,0};
static const unsigned char SSKDF_INFO[6] = {161,178,195,212,229,246};
static const unsigned char SSKDF_EXP[48] = {137,14,190,140,129,87,197,2,140,146,135,3,27,222,72,223,210,95,152,72,192,93,1,240,103,165,82,208,249,80,52,119,14,166,191,106,178,58,8,150,75,182,167,252,209,104,173,172};
// kbkdf_hmac SHA256 counter BeforeFixed rlen=4 llen=4 (python KBKDFHMAC)
static const unsigned char KB_KEY[32] = {221,221,221,221,221,221,221,221,221,221,221,221,221,221,221,221,221,221,221,221,221,221,221,221,221,221,221,221,221,221,221,221};
static const unsigned char KB_LABEL[10] = {108,97,98,101,108,45,100,97,116,97};
static const unsigned char KB_CTX[8] = {99,116,120,45,100,97,116,97};
static const unsigned char KB_EXP[48] = {2,44,163,36,18,180,189,242,252,237,125,40,48,187,65,103,208,10,0,235,119,141,0,59,158,181,140,4,230,209,2,51,83,89,177,129,17,244,77,121,6,154,233,226,171,147,34,178};
// AES-XTS-256 (python cryptography, 48 bytes, block-aligned)
static const unsigned char XTS_K1[32] = {39,24,40,24,40,69,144,69,35,83,96,40,116,113,53,38,98,73,119,87,36,112,147,105,153,89,87,73,102,150,118,39};
static const unsigned char XTS_K2[32] = {49,65,89,38,83,88,151,147,35,132,98,100,51,131,39,149,2,136,65,151,22,147,153,55,81,5,130,9,116,148,69,146};
static const unsigned char XTS_TWEAK[16] = {255,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
static const unsigned char XTS_PT[48] = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47};
static const unsigned char XTS_CT[48] = {28,59,58,16,47,119,3,134,228,131,108,153,227,112,207,155,234,0,128,63,94,72,35,87,164,174,18,212,20,163,230,59,93,49,226,118,248,254,74,141,102,179,23,249,172,104,63,68};
// AES-XTS-256 ciphertext stealing (20 bytes)
static const unsigned char XTS_PT2[20] = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19};
static const unsigned char XTS_CT2[20] = {191,76,98,48,253,11,82,9,18,56,48,100,241,33,39,62,28,59,58,16};
// AES-CMAC-128 (NIST SP800-38B example / python cmac)
static const unsigned char CMAC_KEY[16] = {43,126,21,22,40,174,210,166,171,247,21,136,9,207,79,60};
static const unsigned char CMAC_MSG[16] = {107,193,190,226,46,64,159,150,233,61,126,17,115,147,23,42};
static const unsigned char CMAC_TAG[16] = {7,10,22,180,107,77,65,68,247,155,221,157,208,74,40,124};
// AES-GMAC-128 (AES-GCM empty PT, msg as AAD; python)
static const unsigned char GMAC_KEY[16] = {254,255,233,146,134,101,115,28,109,106,143,148,103,48,131,8};
static const unsigned char GMAC_IV[12] = {202,254,186,190,250,206,219,173,222,202,248,136};
static const unsigned char GMAC_MSG[20] = {254,237,250,206,222,173,190,239,254,237,250,206,222,173,190,239,171,173,218,210};
static const unsigned char GMAC_TAG[16] = {52,100,52,253,81,213,205,12,88,135,236,99,227,155,144,122};

/* ================= tests ================= */

static void test_scrypt(void) {
    unsigned char out[64];
    int rc = rktcrypto_scrypt(SCRYPT_PW, sizeof SCRYPT_PW, SCRYPT_SALT, sizeof SCRYPT_SALT,
                              1024, 8, 16, out, sizeof out);
    report("scrypt (RFC7914)", rc && eq(out, SCRYPT_EXP, 64));
}

static void test_x963kdf(void) {
    unsigned char out[48];
    int rc = rktcrypto_x963kdf(RKTCRYPTO_SHA256, X963_Z, sizeof X963_Z,
                               X963_INFO, sizeof X963_INFO, out, sizeof out);
    report("x963kdf (SHA256)", rc && eq(out, X963_EXP, 48));
}

static void test_sskdf(void) {
    unsigned char out[48];
    int rc = rktcrypto_sskdf(RKTCRYPTO_SHA256, SSKDF_Z, sizeof SSKDF_Z,
                             SSKDF_INFO, sizeof SSKDF_INFO, out, sizeof out);
    report("sskdf (SHA256)", rc && eq(out, SSKDF_EXP, 48));
}

static void test_kbkdf_hmac(void) {
    unsigned char out[48];
    int rc = rktcrypto_kbkdf_hmac(RKTCRYPTO_SHA256, KB_KEY, sizeof KB_KEY,
                                  KB_LABEL, sizeof KB_LABEL, KB_CTX, sizeof KB_CTX,
                                  out, sizeof out);
    report("kbkdf_hmac (SHA256)", rc && eq(out, KB_EXP, 48));
}

static void test_aes_xts(void) {
    unsigned char key[64], out[48], out2[20];
    int ok;
    memcpy(key, XTS_K1, 32);
    memcpy(key + 32, XTS_K2, 32);
    /* keylen is the per-key length (32 => AES-256-XTS). */
    rktcrypto_aes_xts(key, 32, XTS_TWEAK, XTS_PT, out, sizeof out, 1);
    ok = eq(out, XTS_CT, 48);
    /* round-trip decrypt */
    if (ok) {
        unsigned char back[48];
        rktcrypto_aes_xts(key, 32, XTS_TWEAK, XTS_CT, back, sizeof back, 0);
        ok = eq(back, XTS_PT, 48);
    }
    report("aes_xts (48B, enc+dec)", ok);

    /* ciphertext-stealing case (non block-aligned) */
    rktcrypto_aes_xts(key, 32, XTS_TWEAK, XTS_PT2, out2, sizeof out2, 1);
    ok = eq(out2, XTS_CT2, 20);
    if (ok) {
        unsigned char back2[20];
        rktcrypto_aes_xts(key, 32, XTS_TWEAK, XTS_CT2, back2, sizeof back2, 0);
        ok = eq(back2, XTS_PT2, 20);
    }
    report("aes_xts (20B ciphertext-stealing)", ok);
}

static void test_aes_cmac(void) {
    unsigned char tag[16], badtag[16];
    unsigned char badmsg[16];
    int ok;
    rktcrypto_aes_cmac(CMAC_KEY, sizeof CMAC_KEY, CMAC_MSG, sizeof CMAC_MSG, tag);
    ok = eq(tag, CMAC_TAG, 16);
    /* NEGATIVE: flip one message bit; tag must NOT match the known-good tag. */
    memcpy(badmsg, CMAC_MSG, sizeof CMAC_MSG);
    badmsg[0] ^= 0x01;
    rktcrypto_aes_cmac(CMAC_KEY, sizeof CMAC_KEY, badmsg, sizeof badmsg, badtag);
    ok = ok && !eq(badtag, CMAC_TAG, 16);
    report("aes_cmac (KAT + negative)", ok);
}

static void test_aes_gmac(void) {
    unsigned char tag[16], badtag[16];
    unsigned char badmsg[20];
    int ok;
    rktcrypto_aes_gmac(GMAC_KEY, sizeof GMAC_KEY, GMAC_IV, GMAC_MSG, sizeof GMAC_MSG, tag);
    ok = eq(tag, GMAC_TAG, 16);
    /* NEGATIVE: tamper the message; tag must NOT match the known-good tag. */
    memcpy(badmsg, GMAC_MSG, sizeof GMAC_MSG);
    badmsg[sizeof badmsg - 1] ^= 0x80;
    rktcrypto_aes_gmac(GMAC_KEY, sizeof GMAC_KEY, GMAC_IV, badmsg, sizeof badmsg, badtag);
    ok = ok && !eq(badtag, GMAC_TAG, 16);
    report("aes_gmac (KAT + negative)", ok);
}

int main(void) {
    test_scrypt();
    test_x963kdf();
    test_sskdf();
    test_kbkdf_hmac();
    test_aes_xts();
    test_aes_cmac();
    test_aes_gmac();

    printf("%s\n", failures ? "FAILURES" : "ALL PASS");
    return failures ? 1 : 0;
}
