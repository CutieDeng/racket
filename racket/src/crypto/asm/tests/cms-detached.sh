#!/bin/bash
# cms-detached.sh — detached CMS/PKCS#7 SignedData (RFC 5652): the signature is
# over external content (no encapsulated eContent). Our pure-Racket builder
# (librktcrypto, ECDSA P-256 / SHA-256, signed attributes) must produce a
# structure `openssl cms -verify -content` accepts, and reject a mismatched
# content.
#
#   asm/tests/cms-detached.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
RACKET="${RACKET:-$HERE/../../../../bin/racket}"
OPENSSL="${OPENSSL:-openssl}"
BUILD="$HERE/../../../../collects/openssl/private/rktcrypto-x509-build.rkt"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
rc=0

command -v "$OPENSSL" >/dev/null || { echo "SKIP: no openssl on PATH"; exit 0; }
[ -x "$RACKET" ] || { echo "SKIP: tree racket not found"; exit 0; }

echo "== detached CMS SignedData: our builder -> $("$OPENSSL" version) verify =="
printf 'external detached content — librktcrypto ECDSA-P256' > "$TMP/content.bin"

"$RACKET" -e "(require (only-in (file \"$BUILD\") create-self-signed-certificate create-cms-signed-data) net/base64)
(define-values (cert key) (create-self-signed-certificate #:common-name \"detached.signer\"))
(define content (file->bytes \"$TMP/content.bin\"))
(void (call-with-output-file \"$TMP/cms.der\" #:exists 'replace
  (lambda (o) (write-bytes (create-cms-signed-data content (list (cons cert (cons 'p256 key))) #:detached? #t) o))))
(void (call-with-output-file \"$TMP/signer.pem\" #:exists 'replace
  (lambda (o) (fprintf o \"-----BEGIN CERTIFICATE-----\n\") (write-bytes (base64-encode cert #\"\n\") o) (fprintf o \"-----END CERTIFICATE-----\n\"))))" 2>"$TMP/err"
if [ ! -s "$TMP/cms.der" ]; then echo "  FAIL  builder produced no output"; sed 's/^/    /' "$TMP/err" | head -3; exit 1; fi

if "$OPENSSL" cms -verify -inform DER -in "$TMP/cms.der" -content "$TMP/content.bin" \
     -certfile "$TMP/signer.pem" -noverify -no_signer_cert_verify -out /dev/null 2>/dev/null; then
  echo "  PASS  openssl verified the detached signature over the real content"
else echo "  FAIL  openssl rejected a valid detached signature"; rc=1; fi

printf 'tampered content' > "$TMP/wrong.bin"
if "$OPENSSL" cms -verify -inform DER -in "$TMP/cms.der" -content "$TMP/wrong.bin" \
     -certfile "$TMP/signer.pem" -noverify -no_signer_cert_verify -out /dev/null 2>/dev/null; then
  echo "  FAIL  openssl accepted a mismatched content"; rc=1
else echo "  PASS  mismatched content rejected (messageDigest binding)"; fi

echo "----"
[ $rc -eq 0 ] && echo "CMS DETACHED OK" || echo "CMS DETACHED FAIL"
exit $rc
