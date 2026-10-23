#!/bin/bash
# Certificates for test-chain-policy.rkt: chains that a verifier must reject
# (path length, keyUsage, extendedKeyUsage, name constraints, an unknown
# critical extension) and chains it must accept (unordered chain with an
# extra certificate, IP-address SAN). Keys are throwaway P-256 keys.
set -euo pipefail
cd "$(dirname "$0")/policy"
DAYS=3650
SUBJ="/C=US/O=Policy Tests"
key() { [ -f "$1" ] || openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$1" 2>/dev/null; }
# self-signed root CA
key root.key
openssl req -x509 -new -key root.key -sha256 -days $DAYS -out root.crt -subj "$SUBJ/CN=Policy Root" \
  -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null
# sign: name key cert subject extfile-contents [issuer-key issuer-cert]
sign() {
  local name=$1 subj=$2 exts=$3 ikey=${4:-root.key} icrt=${5:-root.crt}
  key "$name.key"
  openssl req -new -key "$name.key" -out "$name.csr" -subj "$subj" 2>/dev/null
  printf '%s\n' "$exts" > "$name.ext"
  openssl x509 -req -in "$name.csr" -out "$name.crt" -days $DAYS -sha256 -CA "$icrt" -CAkey "$ikey" -CAcreateserial -extfile "$name.ext" 2>/dev/null
  rm -f "$name.csr" "$name.ext"
}
LEAF_EXTS="basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature
extendedKeyUsage=serverAuth"
# 1. path length: inter-p0 (pathlen 0) -> inter-p0-sub -> leaf-p0  (must fail)
sign inter-p0 "$SUBJ/CN=Inter pathlen 0" "basicConstraints=critical,CA:TRUE,pathlen:0
keyUsage=critical,keyCertSign"
sign inter-p0-sub "$SUBJ/CN=Inter below pathlen 0" "basicConstraints=critical,CA:TRUE
keyUsage=critical,keyCertSign" inter-p0.key inter-p0.crt
sign leaf-p0 "$SUBJ/CN=leaf-p0.example.test" "$LEAF_EXTS
subjectAltName=DNS:leaf-p0.example.test" inter-p0-sub.key inter-p0-sub.crt
# 2. issuer without keyCertSign -> leaf (must fail)
sign inter-noku "$SUBJ/CN=Inter no keyCertSign" "basicConstraints=critical,CA:TRUE
keyUsage=critical,digitalSignature"
sign leaf-noku "$SUBJ/CN=leaf-noku.example.test" "$LEAF_EXTS
subjectAltName=DNS:leaf-noku.example.test" inter-noku.key inter-noku.crt
# 3. leaf with clientAuth EKU only (must fail as a server, pass as a client)
sign leaf-clientauth "$SUBJ/CN=leaf-clientauth.example.test" "basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature
extendedKeyUsage=clientAuth
subjectAltName=DNS:leaf-clientauth.example.test"
# 4. name constraints: inter-nc permits .example.test only
sign inter-nc "$SUBJ/CN=Inter name constrained" "basicConstraints=critical,CA:TRUE
keyUsage=critical,keyCertSign
nameConstraints=critical,permitted;DNS:example.test"
sign leaf-nc-ok "$SUBJ/CN=ok.example.test" "$LEAF_EXTS
subjectAltName=DNS:ok.example.test" inter-nc.key inter-nc.crt
sign leaf-nc-bad "$SUBJ/CN=bad.other.test" "$LEAF_EXTS
subjectAltName=DNS:bad.other.test" inter-nc.key inter-nc.crt
# 5. unknown critical extension (must fail)
sign leaf-critical "$SUBJ/CN=leaf-critical.example.test" "$LEAF_EXTS
subjectAltName=DNS:leaf-critical.example.test
1.2.3.4.5.6.7.8=critical,ASN1:UTF8String:unknown"
# 6. plain intermediate -> leaf, for ordering / extra-certificate / IP tests
sign inter-plain "$SUBJ/CN=Inter plain" "basicConstraints=critical,CA:TRUE
keyUsage=critical,keyCertSign"
sign leaf-ip "$SUBJ/CN=leaf-ip.example.test" "$LEAF_EXTS
subjectAltName=DNS:leaf-ip.example.test,IP:127.0.0.1,IP:::1" inter-plain.key inter-plain.crt
# 7. self-issued intermediate (key rollover) under a pathlen:1 root (must pass)
key root-p1.key
openssl req -x509 -new -key root-p1.key -sha256 -days $DAYS -out root-p1.crt -subj "$SUBJ/CN=Policy Root p1" \
  -addext "basicConstraints=critical,CA:TRUE,pathlen:1" -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null
sign inter-si "$SUBJ/CN=Inter self-issued" "basicConstraints=critical,CA:TRUE
keyUsage=critical,keyCertSign" root-p1.key root-p1.crt
sign inter-si2 "$SUBJ/CN=Inter self-issued" "basicConstraints=critical,CA:TRUE
keyUsage=critical,keyCertSign" inter-si.key inter-si.crt         # same subject as its issuer
sign leaf-si "$SUBJ/CN=leaf-si.example.test" "$LEAF_EXTS
subjectAltName=DNS:leaf-si.example.test" inter-si2.key inter-si2.crt
# 8. X.509 v1 self-signed root (no extensions) issuing a leaf (must pass)
key root-v1.key
printf '[req]\ndistinguished_name=dn\n[dn]\n' > v1.cnf     # no extension section: a real v1 certificate
openssl req -x509 -x509v1 -config v1.cnf -new -key root-v1.key -sha256 -days $DAYS -out root-v1.crt -subj "$SUBJ/CN=Policy Root v1" 2>/dev/null
rm -f v1.cnf
sign leaf-v1 "$SUBJ/CN=leaf-v1.example.test" "$LEAF_EXTS
subjectAltName=DNS:leaf-v1.example.test" root-v1.key root-v1.crt
# 9. self-signed end entity used directly as its own anchor (must pass)
key selfsigned.key
openssl req -x509 -new -key selfsigned.key -sha256 -days $DAYS -out selfsigned.crt -subj "$SUBJ/CN=selfsigned.example.test" \
  -addext "basicConstraints=critical,CA:FALSE" -addext "keyUsage=critical,digitalSignature" \
  -addext "subjectAltName=DNS:selfsigned.example.test" 2>/dev/null
# 10. intermediate with anyExtendedKeyUsage only (libssl rejects for TLS)
sign inter-anyeku "$SUBJ/CN=Inter anyEKU" "basicConstraints=critical,CA:TRUE
keyUsage=critical,keyCertSign
extendedKeyUsage=anyExtendedKeyUsage"
sign leaf-anyeku "$SUBJ/CN=leaf-anyeku.example.test" "$LEAF_EXTS
subjectAltName=DNS:leaf-anyeku.example.test" inter-anyeku.key inter-anyeku.crt
# 11. name constraints via the CN (no SAN) and via rfc822Name
sign leaf-nc-cn "$SUBJ/CN=my_host.other.test" "basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature
extendedKeyUsage=serverAuth" inter-nc.key inter-nc.crt
sign inter-nc-email "$SUBJ/CN=Inter email constrained" "basicConstraints=critical,CA:TRUE
keyUsage=critical,keyCertSign
nameConstraints=critical,permitted;email:example.test"
sign leaf-nc-email-ok "$SUBJ/CN=mailer" "basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature
subjectAltName=email:user@example.test" inter-nc-email.key inter-nc-email.crt
sign leaf-nc-email-bad "$SUBJ/CN=mailer2" "basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature
subjectAltName=email:user@sub.example.test" inter-nc-email.key inter-nc-email.crt
# 12. a "*.test" wildcard (too broad) and a critical inhibitAnyPolicy
sign leaf-wild "$SUBJ/CN=wildcard" "$LEAF_EXTS
subjectAltName=DNS:*.test,DNS:*.example.test" inter-plain.key inter-plain.crt
sign inter-iap "$SUBJ/CN=Inter inhibitAnyPolicy" "basicConstraints=critical,CA:TRUE
keyUsage=critical,keyCertSign
inhibitAnyPolicy=critical,0"
sign leaf-iap "$SUBJ/CN=leaf-iap.example.test" "$LEAF_EXTS
subjectAltName=DNS:leaf-iap.example.test" inter-iap.key inter-iap.crt
rm -f *.srl
ls *.crt | tr '\n' ' '; echo
