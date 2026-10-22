#lang racket/base
(require rackunit
         openssl
         "common.rkt")

;; A server that requires client verification but has no trusted roots
;; loaded cannot verify any client certificate, so it must reject every
;; client that presents one, as the libssl-based implementation does
;; ("certificate verify failed").

(define server-ctx (ssl-make-server-context 'auto))
(ssl-load-private-key! server-ctx server-key)
(ssl-load-certificate-chain! server-ctx server-crt)
(ssl-set-verify! server-ctx #t)            ; no verify sources loaded

(define (server-view protocol key cert)
  (define-values (port results) (start-server server-ctx))
  (define ctx (ssl-make-client-context protocol))
  (ssl-load-private-key! ctx key)
  (ssl-load-certificate-chain! ctx cert)
  (with-handlers ([exn:fail? void])
    (connect-and-read port ctx "server.example.com"))
  (server-result results))

(module+ test
  (for* ([protocol (in-list '(auto tls12))]
         [client (in-list (list (list "self-signed" self-signed-pem self-signed-pem)
                                (list "CA-signed" client-key client-crt)))])
    (define r (server-view protocol (cadr client) (caddr client)))
    (check-equal? (car r) 'exn
                  (format "~a, ~a client certificate: server accepted: ~s"
                          protocol (car client) r))))
