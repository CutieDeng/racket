#lang racket/base
(require rackunit
         racket/tcp
         openssl
         "common.rkt")

;; `ssl-peer-verified?` describes the connection: enabling verification
;; on the context after the connection was made without it must not make
;; the existing connection count as verified.

(define server-ctx (ssl-make-server-context 'auto))
(ssl-load-private-key! server-ctx server-key)
(ssl-load-certificate-chain! server-ctx server-crt)

(define-values (port results) (start-server server-ctx))

(module+ test
  (define ctx (ssl-make-client-context 'auto))   ; no verification
  (define-values (ti to) (tcp-connect "127.0.0.1" port))
  (define-values (in out)
    (ports->ssl-ports ti to #:mode 'connect #:context ctx #:hostname "server.example.com"
                      #:close-original? #t))
  (check-equal? (read-line in) "hello")
  (check-false (ssl-peer-verified? in) "before changing the context")
  (ssl-set-verify! ctx #t)
  (check-false (ssl-peer-verified? in) "after enabling verification on the context")
  (close-input-port in)
  (close-output-port out))
