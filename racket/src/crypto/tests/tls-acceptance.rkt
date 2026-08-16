#lang racket/base

;; TLS acceptance harness for the OpenSSL removal.
;;
;; The last hard dependency on OpenSSL is the TLS stack. This file is the
;; ACCEPTANCE ORACLE for the from-scratch rktcrypto TLS backend: it drives
;; client<->server loopback handshakes + data exchange entirely through the
;; public `openssl` API (`ports->ssl-ports`, `ssl-make-{client,server}-
;; context`), so it does not care which backend is underneath.
;;
;;   racket/bin/racket racket/src/crypto/tests/tls-acceptance.rkt
;;
;; With no TLS backend present it SKIPS; with a backend present it is the
;; functional gate. `ssl-available?` is #t iff a backend loaded.

(require openssl
         openssl/x509
         racket/port
         racket/file
         racket/runtime-path
         (only-in (file "../../../collects/openssl/private/rktcrypto-tls13.rkt") parse-extensions))

(define-runtime-path test-pem "../../../collects/openssl/test.pem")
(define-runtime-path ocsp-dir "ocsp-vectors")
(define-runtime-path mtls-dir "mtls-vectors")

(define failures 0)
(define (check! name ok?)
  (if ok? (printf "  ok: ~a\n" name)
      (begin (set! failures (add1 failures)) (eprintf "FAIL: ~a\n" name))))

;; A full in-process TLS session over two pipes. `client-ctx`/`server-ctx`
;; are built by the caller; `hostname` is passed to the client;
;; `payload-size` bytes are echoed. Returns 'ok, or (cons 'role exn) on the
;; first failing side. When `expect-fail` is 'client the client handshake is
;; expected to raise (negative test): returns 'ok iff it did.
(define (loopback #:server-ctx server-ctx
                  #:client-ctx client-ctx
                  #:hostname [hostname #f]
                  #:client-alpn [client-alpn '()]
                  #:payload-size [payload-size 4096]
                  #:expect-client-fail [expect-client-fail #f])
  (define payload (make-bytes payload-size))
  (for ([i (in-range payload-size)]) (bytes-set! payload i (bitwise-and i 255)))
  (define-values (c->s-in c->s-out) (make-pipe))
  (define-values (s->c-in s->c-out) (make-pipe))
  (define result (make-channel))
  (thread
   (lambda ()
     (with-handlers ([(lambda (_) #t) (lambda (e) (channel-put result (cons 'server e)))])
       (define-values (si so)
         (ports->ssl-ports c->s-in s->c-out #:mode 'accept #:context server-ctx))
       (let loop ([left payload-size])
         (when (> left 0)
           (define chunk (read-bytes (min left 65536) si))
           (when (bytes? chunk) (write-bytes chunk so) (flush-output so)
                 (loop (- left (bytes-length chunk))))))
       (channel-put result 'server-ok))))
  (define client-outcome
    (with-handlers ([(lambda (_) #t) (lambda (e) (cons 'client e))])
      (define-values (ci co)
        (ports->ssl-ports s->c-in c->s-out #:mode 'connect #:context client-ctx
                          #:hostname hostname #:alpn client-alpn))
      (write-bytes payload co) (flush-output co)
      (let loop ([acc #""])
        (if (>= (bytes-length acc) payload-size)
            (list 'client-ok ci acc)
            (let ([b (read-bytes (- payload-size (bytes-length acc)) ci)])
              (if (eof-object? b) (list 'client-ok ci acc) (loop (bytes-append acc b))))))))
  (cond
    [expect-client-fail
     ;; negative test: the client handshake must have raised
     (and (pair? client-outcome) (eq? (car client-outcome) 'client))]
    [(and (pair? client-outcome) (eq? (car client-outcome) 'client)) client-outcome]
    [else
     (define sr (sync/timeout 30 result))
     (and (eq? sr 'server-ok)
          (equal? (caddr client-outcome) payload)
          (cadr client-outcome))]))   ; return the client input port for inspection

(define (server-ctx-with-test-cert)
  (define c (ssl-make-server-context 'tls13))
  (ssl-load-certificate-chain! c test-pem)
  (ssl-load-private-key! c test-pem)
  c)

(define (run-all)
  (cond
    [(not ssl-available?)
     (printf "TLS acceptance: SKIP -- no TLS backend loaded (ssl-available? = #f).\n")]
    [else
     (printf "TLS acceptance: backend present (ssl-available? = #t).\n")

     ;; 1. Basic TLS 1.3 loopback, no verification.
     (check! "TLS 1.3 loopback handshake + 4KiB echo"
             (port? (loopback #:server-ctx (server-ctx-with-test-cert)
                              #:client-ctx (ssl-make-client-context 'tls13))))

     ;; 2. ALPN negotiation across the loopback.
     (let ([sc (server-ctx-with-test-cert)])
       (ssl-set-server-alpn! sc (list #"h2" #"http/1.1"))
       (define ci (loopback #:server-ctx sc
                            #:client-ctx (ssl-make-client-context 'tls13)
                            #:client-alpn (list #"http/1.1")))
       (check! "ALPN negotiated (http/1.1)"
               (and (port? ci) (equal? (ssl-get-alpn-selected ci) #"http/1.1"))))

     ;; 3. Large (1 MiB) chunked transfer.
     (check! "1 MiB echo round-trip"
             (port? (loopback #:server-ctx (server-ctx-with-test-cert)
                              #:client-ctx (ssl-make-client-context 'tls13)
                              #:payload-size (* 1024 1024))))

     ;; 3b. tls-exporter channel binding is available and 32 bytes.
     (check! "tls-exporter channel binding"
             (let ([ci (loopback #:server-ctx (server-ctx-with-test-cert)
                                 #:client-ctx (ssl-make-client-context 'tls13))])
               (and (port? ci)
                    (let ([cb (ssl-channel-binding ci 'tls-exporter)])
                      (and (bytes? cb) (= 32 (bytes-length cb)))))))

     ;; 4. Verified loopback: client trusts the test cert as a root and
     ;;    checks the hostname (test.pem CN=lambda).
     (let ([cc (ssl-make-client-context 'tls13)])
       (ssl-set-verify! cc #t)
       (ssl-set-verify-hostname! cc #t)
       (ssl-load-verify-root-certificates! cc test-pem)
       (define ci (loopback #:server-ctx (server-ctx-with-test-cert)
                            #:client-ctx cc #:hostname "lambda"))
       (check! "verified loopback (trusted root + hostname)"
               (and (port? ci) (ssl-peer-verified? ci)
                    (regexp-match? #rx#"CN=lambda" (ssl-peer-subject-name ci)))))

     ;; 4b. A2 resumption through the public API: two connections on the SAME
     ;;     client+server contexts. The first caches a NewSessionTicket; the
     ;;     second re-offers it as a PSK. Both verify + report the peer identity
     ;;     (the resumed one restores it from the cached session).
     (let ([sc (server-ctx-with-test-cert)]
           [cc (ssl-make-client-context 'tls13)])
       (ssl-set-verify! cc #t)
       (ssl-set-verify-hostname! cc #t)
       (ssl-load-verify-root-certificates! cc test-pem)
       (define ci1 (loopback #:server-ctx sc #:client-ctx cc #:hostname "lambda"))
       (define ci2 (loopback #:server-ctx sc #:client-ctx cc #:hostname "lambda"))
       (check! "A2 resumption: 2 connections on shared contexts, both verified"
               (and (port? ci1) (port? ci2)
                    (ssl-peer-verified? ci2)
                    (regexp-match? #rx#"CN=lambda" (ssl-peer-subject-name ci2)))))

     ;; 5. Negative: wrong hostname must be rejected.
     (let ([cc (ssl-make-client-context 'tls13)])
       (ssl-set-verify! cc #t)
       (ssl-set-verify-hostname! cc #t)
       (ssl-load-verify-root-certificates! cc test-pem)
       (check! "wrong hostname rejected"
               (loopback #:server-ctx (server-ctx-with-test-cert)
                         #:client-ctx cc #:hostname "not-lambda.example"
                         #:expect-client-fail #t)))

     ;; 6. TLS 1.2 loopback (client pinned to 1.2; server negotiates down).
     (check! "TLS 1.2 loopback handshake + echo"
             (let ([ci (loopback #:server-ctx (server-ctx-with-test-cert)
                                 #:client-ctx (ssl-make-client-context 'tls12))])
               (and (port? ci) (eq? (ssl-protocol-version ci) 'tls1.2))))

     ;; 7. Negative: untrusted root must be rejected (empty trust store).
     (let ([cc (ssl-make-client-context 'tls13)])
       (ssl-set-verify! cc #t)
       (check! "untrusted certificate rejected"
               (loopback #:server-ctx (server-ctx-with-test-cert)
                         #:client-ctx cc #:hostname "lambda"
                         #:expect-client-fail #t)))

     ;; 8. ssl-set-ciphers! (A5): client restricts to CHACHA20 only; server
     ;;    unrestricted -> handshake still succeeds (client offer honored).
     (let ([cc (ssl-make-client-context 'tls13)])
       (ssl-set-ciphers! cc "TLS_CHACHA20_POLY1305_SHA256")
       (check! "ssl-set-ciphers! client CHACHA20-only handshakes"
               (port? (loopback #:server-ctx (server-ctx-with-test-cert) #:client-ctx cc))))

     ;; 9. ssl-set-ciphers! (A5): a policy matching no supported suite makes the
     ;;    client refuse to connect (like OpenSSL "no cipher match").
     (let ([cc (ssl-make-client-context 'tls13)])
       (ssl-set-ciphers! cc "AES128-CCM:DES-CBC3-SHA")   ; none supported by this AEAD-only backend
       (check! "ssl-set-ciphers! empty policy refuses to connect"
               (loopback #:server-ctx (server-ctx-with-test-cert)
                         #:client-ctx cc #:expect-client-fail #t)))

     ;; 10. ssl-set-ciphers! (A5): server restricts via the "AES256" alias; client
     ;;     offers all -> server picks an AES-256 suite -> succeeds.
     (let ([sc (server-ctx-with-test-cert)])
       (ssl-set-ciphers! sc "AES256")
       (check! "ssl-set-ciphers! server AES256 alias handshakes"
               (port? (loopback #:server-ctx sc #:client-ctx (ssl-make-client-context 'tls13)))))

     ;; 11. ssl-set-ciphers! (A5/A8): disjoint client/server policies -> server
     ;;     has no common suite -> sends handshake_failure alert -> client fails
     ;;     cleanly (does not hang).
     (let ([cc (ssl-make-client-context 'tls13)]
           [sc (server-ctx-with-test-cert)])
       (ssl-set-ciphers! cc "TLS_AES_128_GCM_SHA256")
       (ssl-set-ciphers! sc "TLS_CHACHA20_POLY1305_SHA256")
       (check! "ssl-set-ciphers! disjoint policies rejected via alert (no hang)"
               (loopback #:server-ctx sc #:client-ctx cc #:expect-client-fail #t)))

     ;; 12. A6: tls-unique available on TLS 1.2 (client Finished verify_data, 12 bytes).
     (let ([ci (loopback #:server-ctx (server-ctx-with-test-cert)
                         #:client-ctx (ssl-make-client-context 'tls12))])
       (check! "tls-unique channel binding on TLS 1.2 (12 bytes)"
               (and (port? ci) (= 12 (bytes-length (ssl-channel-binding ci 'tls-unique))))))

     ;; 13. A6: tls-unique unavailable on TLS 1.3 (RFC 9266 -> use tls-exporter).
     (let ([ci (loopback #:server-ctx (server-ctx-with-test-cert)
                         #:client-ctx (ssl-make-client-context 'tls13))])
       (check! "tls-unique unavailable on TLS 1.3 (raises)"
               (and (port? ci)
                    (with-handlers ([exn:fail? (lambda (_) #t)])
                      (ssl-channel-binding ci 'tls-unique) #f))))

     ;; 14. A6: tls-server-end-point uses the cert's signature hash (SHA-256 test
     ;;     cert -> 32-byte binding).
     (let ([ci (loopback #:server-ctx (server-ctx-with-test-cert)
                         #:client-ctx (ssl-make-client-context 'tls13))])
       (check! "tls-server-end-point binding (cert sig hash, 32 bytes)"
               (and (port? ci) (= 32 (bytes-length (ssl-channel-binding ci 'tls-server-end-point))))))

     ;; 15. A6: TLS 1.2 keylog emits a CLIENT_RANDOM line (Wireshark decryptable).
     (let* ([lg (make-logger)]
            [rc (make-log-receiver lg 'info 'ssl-keylog)]
            [cc (ssl-make-client-context 'tls12)])
       (ssl-set-keylogger! cc lg)
       (loopback #:server-ctx (server-ctx-with-test-cert) #:client-ctx cc)
       (check! "TLS 1.2 keylog CLIENT_RANDOM emitted"
               (let loop ()
                 (define m (sync/timeout 0.5 rc))
                 (cond [(not m) #f]
                       [(and (string? (vector-ref m 1))
                             ;; log strings carry a "ssl-keylog: " topic prefix
                             (regexp-match? #rx"CLIENT_RANDOM [0-9a-f]+ [0-9a-f]+" (vector-ref m 1))) #t]
                       [else (loop)]))))

     ;; 16/17. A3: OCSP stapling — server staples a response for its cert, the
     ;;     client (revocation-check on) verifies it; a revoked staple aborts.
     (let ()
       (define (mk-server staple)
         (define c (ssl-make-server-context 'tls13))
         (ssl-load-certificate-chain! c (build-path ocsp-dir "server.pem"))
         (ssl-load-private-key! c (build-path ocsp-dir "server.pem"))
         (ssl-set-ocsp-staple! c (file->bytes (build-path ocsp-dir staple)))
         c)
       (define (mk-client)
         (define c (ssl-make-client-context 'tls13))
         (ssl-set-verify! c #t)
         (ssl-load-verify-root-certificates! c (build-path ocsp-dir "ca.pem"))
         (ssl-set-revocation-check! c #t)
         c)
       (check! "OCSP stapling: good status accepted"
               (port? (loopback #:server-ctx (mk-server "good.der")
                                #:client-ctx (mk-client) #:hostname "leaf.example")))
       (check! "OCSP stapling: revoked status rejected"
               (loopback #:server-ctx (mk-server "revoked.der")
                         #:client-ctx (mk-client) #:hostname "leaf.example"
                         #:expect-client-fail #t)))

     ;; 19/20. A4: mutual TLS — server requests+requires a client certificate.
     (let ()
       (define (mtls-server)
         (define c (ssl-make-server-context 'tls13))
         (ssl-load-certificate-chain! c (build-path mtls-dir "server.pem"))
         (ssl-load-private-key! c (build-path mtls-dir "server.pem"))
         (ssl-set-verify! c #t)                              ; require + verify client cert
         (ssl-load-verify-root-certificates! c (build-path mtls-dir "ca.pem"))
         c)
       (define (mtls-client with-cert?)
         (define c (ssl-make-client-context 'tls13))
         (ssl-set-verify! c #t)
         (ssl-load-verify-root-certificates! c (build-path mtls-dir "ca.pem"))
         (when with-cert?
           (ssl-load-certificate-chain! c (build-path mtls-dir "client.pem"))
           (ssl-load-private-key! c (build-path mtls-dir "client.pem")))
         c)
       (check! "mutual TLS: valid client cert accepted"
               (port? (loopback #:server-ctx (mtls-server) #:client-ctx (mtls-client #t)
                                #:hostname "leaf.example")))
       (check! "mutual TLS: missing client cert rejected"
               (with-handlers ([exn:fail? (lambda (_) #t)])
                 (not (port? (loopback #:server-ctx (mtls-server) #:client-ctx (mtls-client #f)
                                       #:hostname "leaf.example"))))))

     ;; 21. A5': duplicate extensions in a hello block are rejected (RFC 8446 §4.2).
     (check! "duplicate extension rejected"
             (with-handlers ([exn:fail? (lambda (_) #t)])
               (parse-extensions (bytes 0 10 0 0 0 10 0 0)) #f))
     (check! "distinct extensions parse"
             (= 2 (length (parse-extensions (bytes 0 10 0 0 0 11 0 0)))))

     ;; 22. A5': TLS 1.3 KeyUpdate — rotate keys mid-stream, data keeps flowing.
     (let ()
       (define-values (c->s-in c->s-out) (make-pipe))
       (define-values (s->c-in s->c-out) (make-pipe))
       (thread
        (lambda ()
          (with-handlers ([(lambda (_) #t) void])
            (define-values (si so)
              (ports->ssl-ports c->s-in s->c-out #:mode 'accept
                                #:context (server-ctx-with-test-cert)))
            (let loop () (define b (read-bytes 5 si))
              (when (bytes? b) (write-bytes b so) (flush-output so) (loop))))))
       (define-values (ci co)
         (ports->ssl-ports s->c-in c->s-out #:mode 'connect
                           #:context (ssl-make-client-context 'tls13)))
       (define (rt msg) (write-bytes msg co) (flush-output co) (read-bytes 5 ci))
       (define r1 (rt #"aaaaa"))
       (ssl-key-update! ci)                       ; rotate keys, ask peer to rotate too
       (define r2 (rt #"bbbbb"))
       (check! "TLS 1.3 KeyUpdate keeps data flowing"
               (and (equal? r1 #"aaaaa") (equal? r2 #"bbbbb"))))

     ;; 23. B3+TLS: a certificate + key we built ourselves (openssl/x509) is a
     ;;     working TLS server identity; a client trusting it verifies the handshake.
     (let ()
       (define-values (cder priv)
         (create-self-signed-certificate #:common-name "built.example"
                                         #:dns-names '("built.example") #:ca? #t))
       (define cert-file (make-temporary-file))
       (define key-file (make-temporary-file))
       (call-with-output-file cert-file #:exists 'replace (lambda (o) (write-string (der->pem cder) o)))
       (call-with-output-file key-file #:exists 'replace (lambda (o) (write-string (ec-private-key->pem priv) o)))
       (define sc (ssl-make-server-context 'tls13))
       (ssl-load-certificate-chain! sc cert-file)
       (ssl-load-private-key! sc key-file)
       (define cc (ssl-make-client-context 'tls13))
       (ssl-set-verify! cc #t)
       (ssl-load-verify-root-certificates! cc cert-file)
       (check! "built cert+key works as a TLS server identity"
               (port? (loopback #:server-ctx sc #:client-ctx cc #:hostname "built.example")))
       (delete-file cert-file) (delete-file key-file))

     ;; 24. A4 on TLS 1.2: mutual auth — client pinned to 1.2 presents its cert,
     ;;     server (ssl-set-verify!) requests + verifies it.
     (let ()
       (define (mk-server)
         (define c (ssl-make-server-context 'tls13))
         (ssl-load-certificate-chain! c (build-path mtls-dir "server.pem"))
         (ssl-load-private-key! c (build-path mtls-dir "server.pem"))
         (ssl-set-verify! c #t)
         (ssl-load-verify-root-certificates! c (build-path mtls-dir "ca.pem"))
         c)
       (define (mk-client with-cert?)
         (define c (ssl-make-client-context 'tls12))
         (ssl-set-verify! c #t)
         (ssl-load-verify-root-certificates! c (build-path mtls-dir "ca.pem"))
         (when with-cert?
           (ssl-load-certificate-chain! c (build-path mtls-dir "client.pem"))
           (ssl-load-private-key! c (build-path mtls-dir "client.pem")))
         c)
       (check! "mutual TLS 1.2: valid client cert accepted"
               (let ([ci (loopback #:server-ctx (mk-server) #:client-ctx (mk-client #t)
                                   #:hostname "leaf.example")])
                 (and (port? ci) (eq? (ssl-protocol-version ci) 'tls1.2)))))

     (printf "TLS acceptance: ~a failure(s)\n" failures)
     (when (> failures 0) (error 'tls-acceptance "~a check(s) failed" failures))]))

(module+ main (run-all))
(module+ test (run-all))
