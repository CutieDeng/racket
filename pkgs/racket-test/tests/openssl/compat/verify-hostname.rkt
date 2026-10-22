#lang racket/base
(require rackunit
         openssl
         "common.rkt")

;; `ssl-set-verify!` and `ssl-set-verify-hostname!` are independent
;; (see the `ssl-set-verify-hostname!` documentation): certificate
;; verification alone does not check the hostname, and hostname
;; verification alone still rejects a certificate that does not match.

(define server-ctx (ssl-make-server-context 'auto))
(ssl-load-private-key! server-ctx server-key)
(ssl-load-certificate-chain! server-ctx server-crt)   ; for server.example.com

(define-values (port results) (start-server server-ctx))

(define (client-ctx protocol #:verify? verify? #:hostname? hostname?)
  (define ctx (ssl-make-client-context protocol))
  (ssl-load-verify-root-certificates! ctx cacert)
  (ssl-set-verify! ctx verify?)
  (ssl-set-verify-hostname! ctx hostname?)
  ctx)

(define (connect protocol hostname #:verify? verify? #:hostname? hostname?)
  (begin0
    (connect-and-read port
                      (client-ctx protocol #:verify? verify? #:hostname? hostname?)
                      hostname)
    (server-result results)))

(module+ test
  (for ([protocol (in-list '(auto tls12))])
    (define (label what) (format "~a: ~a" protocol what))

    ;; certificate verification only: a hostname that is not in the
    ;; certificate is fine
    (check-equal? (connect protocol "127.0.0.1" #:verify? #t #:hostname? #f)
                  "hello"
                  (label "verify only, other hostname"))

    ;; hostname verification only: a hostname that is not in the
    ;; certificate is rejected
    (check-exn exn:fail?
               (lambda () (connect protocol "wrong.example.com" #:verify? #f #:hostname? #t))
               (label "hostname only, wrong hostname"))

    ;; both
    (check-equal? (connect protocol "server.example.com" #:verify? #t #:hostname? #t)
                  "hello"
                  (label "both, right hostname"))
    (check-exn exn:fail?
               (lambda () (connect protocol "wrong.example.com" #:verify? #t #:hostname? #t))
               (label "both, wrong hostname"))))
