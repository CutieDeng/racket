#lang racket/base
(require rackunit
         racket/runtime-path
         openssl
         "local-server.rkt")

;; Identity key types: RSA, P-256, P-384, P-521 and Ed25519 private keys
;; (PKCS#8 and SEC1 PEM) as the server's identity under TLS 1.3 and 1.2,
;; verified by the client (chain + hostname), and as the client's identity
;; with a server that asks for a certificate. The identities are signed by
;; the test CA (generate-certs.sh).

(define-runtime-path dir ".")
(define identities
  (for/list ([kt (in-list '("rsa" "p256" "p384" "p521" "ed25519"))])
    (define base (case kt [("rsa") "server"] [("p256") "server_ec"] [else (string-append "server_" kt)]))
    (list kt (build-path dir (string-append base "_key.pem")) (build-path dir (string-append base "_crt.pem")))))

(define (verifying-client protocol)
  (define ctx (ssl-make-client-context protocol))
  (ssl-load-verify-root-certificates! ctx cacert)
  (ssl-set-verify! ctx #t)
  (ssl-set-verify-hostname! ctx #t)
  ctx)

(module+ test
  (for* ([id (in-list identities)] [protocol (in-list '(auto tls12))])
    (define-values (kt key crt) (apply values id))
    ;; as the server's identity
    (define sctx (ssl-make-server-context 'auto))
    (ssl-load-private-key! sctx key)
    (ssl-load-certificate-chain! sctx crt)
    (define-values (port results) (start-server sctx))
    (check-equal? (connect-and-read port (verifying-client protocol) "server.example.com") "hello"
                  (format "~a server identity, ~a" kt protocol))
    (check-equal? (car (server-result results)) 'ok)
    ;; as the client's identity (the server verifies it against the test CA)
    (define sctx2 (ssl-make-server-context 'auto))
    (ssl-load-private-key! sctx2 server-key)
    (ssl-load-certificate-chain! sctx2 server-crt)
    (ssl-load-verify-root-certificates! sctx2 cacert)
    (ssl-set-verify! sctx2 #t)
    (define-values (port2 results2) (start-server sctx2))
    (define cctx (ssl-make-client-context protocol))
    (ssl-load-private-key! cctx key)
    (ssl-load-certificate-chain! cctx crt)
    (check-equal? (connect-and-read port2 cctx "server.example.com") "hello"
                  (format "~a client identity, ~a" kt protocol))
    (define r (server-result results2))
    (check-equal? (list (car r) (cadr r)) '(ok #t) (format "~a client identity verified, ~a" kt protocol))))
