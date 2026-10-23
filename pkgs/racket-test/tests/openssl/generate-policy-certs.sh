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
rm -f *.srl
ls *.crt | tr '\n' ' '; echo
