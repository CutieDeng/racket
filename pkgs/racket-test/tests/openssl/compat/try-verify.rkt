#lang racket/base
(require rackunit
         openssl
         "common.rkt")

;; A server using `ssl-try-verify!` asks for a client certificate, and
;; the connection proceeds when the client sends none, with
;; `ssl-peer-verified?` reporting #f. A server using `ssl-set-verify!`
;; rejects such a client.
;;
;; The expectations follow the libssl-based implementation (Racket 9.2,
;; `SSL_VERIFY_PEER` without a verify callback), which also rejects a
;; client certificate that is presented but does not verify, although
;; the `ssl-try-verify!` documentation says that the connection
;; continues when verification fails.

(define (server-ctx verify!)
  (define ctx (ssl-make-server-context 'auto))
  (ssl-load-private-key! ctx server-key)
  (ssl-load-certificate-chain! ctx server-crt)
  (ssl-load-verify-root-certificates! ctx cacert)
  (verify! ctx #t)
  ctx)

(define (client-ctx #:key [key #f] #:cert [cert #f])
  (define ctx (ssl-make-client-context 'auto))
  (when key (ssl-load-private-key! ctx key))
  (when cert (ssl-load-certificate-chain! ctx cert))
  ctx)

(define no-cert-client (client-ctx))
(define trusted-client (client-ctx #:key client-key #:cert client-crt))
(define untrusted-client (client-ctx #:key self-signed-pem #:cert self-signed-pem))

(module+ test
  ;; a fresh server per connection, so that a failed connection's
  ;; result cannot be read as the next connection's
  (define (try-connect ctx)
    (define-values (port results) (start-server (server-ctx ssl-try-verify!)))
    (define line
      (with-handlers ([exn:fail? (lambda (e) (list 'client-exn (exn-message e)))])
        (connect-and-read port ctx "server.example.com")))
    (list line (server-result results)))

  (let ([r (try-connect no-cert-client)])
    (check-equal? (car r) "hello" "try-verify, no client certificate: connection proceeds")
    (check-equal? (list-ref (cadr r) 1) #f "try-verify, no client certificate: not verified"))

  (let-values ([(port results) (start-server (server-ctx ssl-try-verify!))])
    (with-handlers ([exn:fail? void])
      (connect-and-read port untrusted-client "server.example.com"))
    (check-equal? (car (server-result results)) 'exn
                  "try-verify, untrusted certificate: server rejects"))

  (let ([r (try-connect trusted-client)])
    (check-equal? (car r) "hello" "try-verify, trusted certificate: connection proceeds")
    (check-equal? (list-ref (cadr r) 1) #t "try-verify, trusted certificate: verified"))

  ;; control: `ssl-set-verify!` rejects a client without a certificate
  (define-values (set-port set-results) (start-server (server-ctx ssl-set-verify!)))
  (with-handlers ([exn:fail? void])
    (connect-and-read set-port no-cert-client "server.example.com"))
  (check-equal? (car (server-result set-results)) 'exn
                "set-verify, no client certificate: server rejects"))
