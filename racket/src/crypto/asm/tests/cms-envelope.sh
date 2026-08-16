#!/bin/bash
# cms-envelope.sh — CMS EnvelopedData (RFC 5652) creation, verified by decrypting
# with the reference OpenSSL/LibreSSL. Our pure-Racket builder (librktcrypto,
# RSAES-OAEP-SHA256 key transport + AES-256-CBC content) must produce a structure
# `openssl cms -decrypt` accepts and recovers byte-for-byte.
#
#   asm/tests/cms-envelope.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
RACKET="${RACKET:-$HERE/../../../../bin/racket}"
OPENSSL="${OPENSSL:-openssl}"
BUILD="$HERE/../../../../collects/openssl/private/rktcrypto-x509-build.rkt"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
rc=0

command -v "$OPENSSL" >/dev/null || { echo "SKIP: no openssl on PATH"; exit 0; }
[ -x "$RACKET" ] || { echo "SKIP: tree racket not found"; exit 0; }

echo "== CMS EnvelopedData: our builder -> $("$OPENSSL" version) decrypt =="
"$OPENSSL" req -new -x509 -newkey rsa:2048 -nodes -subj "/CN=recip" -days 2 \
  -keyout "$TMP/k.pem" -out "$TMP/c.pem" 2>/dev/null

MSG="enveloped-payload-$$-librktcrypto-oaep"
"$RACKET" -e "(require (only-in (file \"$BUILD\") create-cms-enveloped-data) net/base64)
(define pem (file->bytes \"$TMP/c.pem\"))
(define der (base64-decode (cadr (regexp-match #rx#\"CERTIFICATE-----(.*?)-----END\" pem))))
(void (call-with-output-file \"$TMP/env.der\" #:exists 'replace
  (lambda (o) (write-bytes (create-cms-enveloped-data (string->bytes/utf-8 \"$MSG\") der) o))))" 2>"$TMP/err"
if [ ! -s "$TMP/env.der" ]; then echo "  FAIL  builder produced no output"; sed 's/^/    /' "$TMP/err" | head -3; exit 1; fi

GOT=$("$OPENSSL" cms -decrypt -inform DER -in "$TMP/env.der" -inkey "$TMP/k.pem" 2>/dev/null)
if [ "$GOT" = "$MSG" ]; then
  printf "  PASS  openssl recovered the plaintext (%d bytes, RSAES-OAEP-SHA256 + AES-256-CBC)\n" "${#GOT}"
else
  printf "  FAIL  openssl decrypt mismatch: got '%s' want '%s'\n" "$GOT" "$MSG"; rc=1
fi
echo "----"
[ $rc -eq 0 ] && echo "CMS ENVELOPE OK" || echo "CMS ENVELOPE FAIL"
exit $rc
