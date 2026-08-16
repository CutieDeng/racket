#!/bin/bash
# tls-interop.sh — real interoperability matrix between the fork's pure-Racket
# TLS stack (openssl collection on librktcrypto, no OpenSSL linked) and the
# system OpenSSL/LibreSSL `s_server`/`s_client`, for TLS 1.3 and TLS 1.2, in
# both roles. Proves the removal-replacement stack talks to a reference peer.
#
#   asm/tests/tls-interop.sh
#
# Requires: an `openssl` on PATH (LibreSSL is fine) and the tree racket. Uses an
# RSA server certificate (LibreSSL 3.3's s_server mishandles EC certs under
# TLS 1.3 — a peer quirk, not ours; our EC certs interoperate elsewhere).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
RACKET="${RACKET:-$HERE/../../../../bin/racket}"
OPENSSL="${OPENSSL:-openssl}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"; jobs -p | xargs kill 2>/dev/null' EXIT
CERT="$TMP/cert.pem"; KEY="$TMP/key.pem"
rc=0

command -v "$OPENSSL" >/dev/null || { echo "SKIP: no openssl on PATH"; exit 0; }
[ -x "$RACKET" ] || { echo "SKIP: tree racket not found at $RACKET"; exit 0; }

"$OPENSSL" req -new -x509 -newkey rsa:2048 -nodes -subj "/CN=localhost" \
  -days 2 -keyout "$KEY" -out "$CERT" 2>/dev/null

port(){ echo $((15000 + RANDOM % 40000)); }
wait_ready(){ for _ in $(seq 1 40); do grep -q ready "$1" 2>/dev/null && return 0; sleep 0.2; done; return 1; }
# poll a listening TCP port (s_server accepts many, so probing is harmless)
wait_port(){ for _ in $(seq 1 40); do
  if command -v nc >/dev/null; then nc -z 127.0.0.1 "$1" 2>/dev/null && return 0;
  else sleep 2; return 0; fi; sleep 0.2; done; return 1; }

# ---- forward: our client -> openssl s_server ----
forward(){
  local proto="$1" p; p="$(port)"
  "$OPENSSL" s_server -"$proto" -cert "$CERT" -key "$KEY" -accept "$p" -www >/dev/null 2>&1 &
  local sp=$!; wait_port "$p"
  local got
  got=$("$RACKET" -e "(require openssl racket/port)
(with-handlers ([exn:fail? (lambda (e) (printf \"ERR ~a\n\" (exn-message e)))])
  (define-values (i o) (ssl-connect \"127.0.0.1\" $p (quote auto)))
  (fprintf o \"GET / HTTP/1.0\r\n\r\n\") (flush-output o)
  (printf \"~a ~a\n\" (string-length (port->string i)) (ssl-protocol-version i)))" 2>&1 | tail -1)
  kill $sp 2>/dev/null; wait $sp 2>/dev/null
  if echo "$got" | grep -qE "^[0-9]+ tls"; then
    printf "  PASS  our-client -> openssl s_server (%s): %s bytes\n" "$proto" "${got%% *}"
  else printf "  FAIL  our-client -> openssl s_server (%s): %s\n" "$proto" "$got"; rc=1; fi
}

# ---- reverse: openssl s_client -> our server ----
reverse(){
  local proto="$1" p; p="$(port)"
  local log="$TMP/srv_$proto.log"
  "$RACKET" -e "(require openssl)
(define ctx (ssl-make-server-context (quote auto)))
(ssl-load-certificate-chain! ctx \"$CERT\")
(ssl-load-private-key! ctx \"$KEY\")
(define lsnr (ssl-listen $p 4 #t #f ctx))
(printf \"ready\n\") (flush-output)
(define-values (i o) (ssl-accept lsnr))
(define line (read-line i))
(fprintf o \"echo:~a\n\" line) (flush-output o) (close-output-port o)" > "$log" 2>&1 &
  local sp=$!
  wait_ready "$log"; sleep 0.3
  local got
  got=$( (printf "ping-%s\n" "$proto"; sleep 0.8) | "$OPENSSL" s_client -connect "127.0.0.1:$p" -"$proto" -quiet 2>/dev/null | grep "echo:" | head -1 )
  kill $sp 2>/dev/null; wait $sp 2>/dev/null
  if [ "$got" = "echo:ping-$proto" ]; then
    printf "  PASS  openssl s_client -> our-server (%s)\n" "$proto"
  else printf "  FAIL  openssl s_client -> our-server (%s): got '%s'\n" "$proto" "$got"; rc=1; fi
}

echo "== TLS interop: fork's pure-Racket stack <-> $("$OPENSSL" version) =="
for proto in tls1_3 tls1_2; do forward "$proto"; done
for proto in tls1_3 tls1_2; do reverse "$proto"; done
echo "----"
[ $rc -eq 0 ] && echo "TLS INTEROP OK — our client & server interoperate with OpenSSL/LibreSSL on 1.3 and 1.2" \
             || echo "TLS INTEROP FAIL"
exit $rc
