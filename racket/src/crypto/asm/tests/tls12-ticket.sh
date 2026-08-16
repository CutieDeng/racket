#!/bin/bash
# tls12-ticket.sh — TLS 1.2 SessionTicket resumption (RFC 5077), server side.
# Our pure-Racket server (librktcrypto) must issue a NewSessionTicket and then
# accept an abbreviated handshake when a real OpenSSL/LibreSSL client presents
# that ticket. `openssl s_client -reconnect` does a full handshake then 5
# reconnects reusing the ticket; we require at least one "Reused".
#
#   asm/tests/tls12-ticket.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
RACKET="${RACKET:-$HERE/../../../../bin/racket}"
OPENSSL="${OPENSSL:-openssl}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"; jobs -p | xargs kill 2>/dev/null' EXIT

command -v "$OPENSSL" >/dev/null || { echo "SKIP: no openssl on PATH"; exit 0; }
[ -x "$RACKET" ] || { echo "SKIP: tree racket not found"; exit 0; }

"$OPENSSL" req -new -x509 -newkey rsa:2048 -nodes -subj "/CN=localhost" -days 2 \
  -keyout "$TMP/k.pem" -out "$TMP/c.pem" 2>/dev/null
PORT=$((16000 + RANDOM % 40000))

# server: one shared context (its ticket store persists across connections),
# accept in a loop so -reconnect's repeated connects are served.
"$RACKET" -e "(require openssl)
(define ctx (ssl-make-server-context (quote auto)))
(ssl-load-certificate-chain! ctx \"$TMP/c.pem\")
(ssl-load-private-key! ctx \"$TMP/k.pem\")
(define lsnr (ssl-listen $PORT 8 #t #f ctx))
(printf \"ready\n\") (flush-output)
(let loop ()
  (with-handlers ([exn:fail? void])
    (define-values (i o) (ssl-accept lsnr))
    (thread (lambda () (with-handlers ([exn:fail? void])
              (fprintf o \"hi\n\") (flush-output o) (close-output-port o) (close-input-port i)))))
  (loop))" > "$TMP/srv.log" 2>&1 &
for _ in $(seq 1 40); do grep -q ready "$TMP/srv.log" 2>/dev/null && break; sleep 0.2; done
sleep 0.3

echo "== TLS 1.2 SessionTicket: our server <- $("$OPENSSL" version) s_client -reconnect =="
OUT=$( (sleep 2) | "$OPENSSL" s_client -connect "127.0.0.1:$PORT" -tls1_2 -reconnect 2>&1 )
NEW=$(printf '%s\n' "$OUT" | grep -c '^New,')
REUSED=$(printf '%s\n' "$OUT" | grep -c '^Reused,')
printf "  new handshakes: %s, resumed (Reused): %s\n" "$NEW" "$REUSED"
if [ "$REUSED" -ge 1 ]; then echo "----"; echo "TLS1.2 TICKET OK — server issued a ticket and resumed an abbreviated handshake"; exit 0
else echo "----"; echo "TLS1.2 TICKET FAIL — no resumption observed"; exit 1; fi
