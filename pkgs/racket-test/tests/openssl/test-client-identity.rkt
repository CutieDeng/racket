#lang racket/base
(require rackunit
         openssl
         "local-server.rkt")

;; A server that verifies clients against the test CA sees the identity
;; of a client that presents a certificate issued by that CA.

(define client-subject
  #"/C=US/ST=Racketa/O=Testing Examples/OU=Testing/CN=client.example.com/emailAddress=client@example.com")

(define server-ctx (ssl-make-server-context 'auto))
(ssl-load-private-key! server-ctx server-key)
(ssl-load-certificate-chain! server-ctx server-crt)
(ssl-load-verify-root-certificates! server-ctx cacert)
(ssl-set-verify! server-ctx #t)

(module+ test
  (for ([protocol (in-list '(auto tls12))])
    (define-values (port results) (start-server server-ctx))
    (define ctx (ssl-make-client-context protocol))
    (ssl-load-private-key! ctx client-key)
    (ssl-load-certificate-chain! ctx client-crt)
    (check-equal? (connect-and-read port ctx "server.example.com") "hello"
                  (format "~a: connection" protocol))
    (check-equal? (server-result results) (list 'ok #t client-subject)
                  (format "~a: server's view of the client" protocol))))
