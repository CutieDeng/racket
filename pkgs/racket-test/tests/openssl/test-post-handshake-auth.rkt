#lang racket/base
(require rackunit
         racket/tcp
         openssl
         "local-server.rkt")

;; `ssl-set-verify!` / `ssl-try-verify!` on an established connection: the
;; server asks the client for its certificate after the handshake (TLS 1.3
;; post-handshake authentication) and `ssl-peer-verified?` reflects the
;; answer when the call returns. On a TLS 1.2 connection the call fails
;; (libssl renegotiated there; this implementation does not).

(define (server-ctx)
  (define ctx (ssl-make-server-context 'auto))
  (ssl-load-private-key! ctx server-key)
  (ssl-load-certificate-chain! ctx server-crt)
  (ssl-load-verify-root-certificates! ctx cacert)
  ctx)

(define (client-ctx protocol #:key [key #f] #:cert [cert #f])
  (define ctx (ssl-make-client-context protocol))
  (when key (ssl-load-private-key! ctx key))
  (when cert (ssl-load-certificate-chain! ctx cert))
  ctx)

(define client-subject
  #"/C=US/ST=Racketa/O=Testing Examples/OU=Testing/CN=client.example.com/emailAddress=client@example.com")

;; Runs one connection: the server reads a line, applies `verify!` to its
;; input port (catching the error), writes a line, and reports what it
;; saw. Returns (values server-report client-line).
(define (run verify! client)
  (define listener (tcp-listen 0 4 #t "127.0.0.1"))
  (define-values (addr port other-addr other-port) (tcp-addresses listener #t))
  (define report (make-channel))
  (thread
   (lambda ()
     (define-values (ti to) (tcp-accept listener))
     (channel-put
      report
      (with-handlers ([exn:fail? (lambda (e) (list 'exn (exn-message e)))])
        (define-values (in out)
          (ports->ssl-ports ti to #:mode 'accept #:context (server-ctx) #:close-original? #t))
        (define first-line (read-line in))
        (define verify-result
          (with-handlers ([exn:fail? (lambda (e) (list 'verify-exn (exn-message e)))])
            (verify! in #t)
            'ok))
        (write-bytes #"after\n" out)
        (flush-output out)
        (begin0 (list first-line verify-result (ssl-peer-verified? in) (ssl-peer-subject-name in))
          (close-output-port out)
          (close-input-port in))))))
  (define-values (ti to) (tcp-connect "127.0.0.1" port))
  (define-values (in out)
    (ports->ssl-ports ti to #:mode 'connect #:context client #:hostname "server.example.com"
                      #:close-original? #t))
  (write-bytes #"before\n" out)
  (flush-output out)
  ;; a rejected authentication reaches the client as a fatal alert, which
  ;; its read raises as an exception
  (define line
    (with-handlers ([exn:fail? (lambda (e) (list 'exn (exn-message e)))])
      (read-line in)))
  (close-output-port out)
  (close-input-port in)
  (tcp-close listener)
  (values (sync/timeout 10 report) line))

(module+ test
  ;; try-verify, client without a certificate: proceeds, not verified
  (let-values ([(report line) (run ssl-try-verify! (client-ctx 'auto))])
    (check-equal? report (list "before" 'ok #f #f) "try-verify, no client certificate")
    (check-equal? line "after"))
  ;; try-verify, client with a CA-signed certificate: verified, identity known
  (let-values ([(report line) (run ssl-try-verify! (client-ctx 'auto #:key client-key #:cert client-crt))])
    (check-equal? report (list "before" 'ok #t client-subject) "try-verify, trusted client certificate")
    (check-equal? line "after"))
  ;; set-verify (required), client with a certificate
  (let-values ([(report line) (run ssl-set-verify! (client-ctx 'auto #:key client-key #:cert client-crt))])
    (check-equal? report (list "before" 'ok #t client-subject) "set-verify, trusted client certificate"))
  ;; set-verify (required), client without a certificate: the request fails
  ;; on the server, and the client sees the certificate_required alert
  (let-values ([(report line) (run ssl-set-verify! (client-ctx 'auto))])
    (check-equal? (car report) "before")
    (check-regexp-match #rx"ssl-set-verify!: failed .*certificate required" (cadr (cadr report)))
    (check-false (caddr report))
    (check-regexp-match #rx"certificate_required" (cadr line)))
  ;; a self-signed client certificate is rejected (unknown_ca)
  (let-values ([(report line) (run ssl-try-verify! (client-ctx 'auto #:key self-signed-pem #:cert self-signed-pem))])
    (check-regexp-match #rx"ssl-try-verify!: failed" (cadr (cadr report)))
    (check-false (caddr report))
    (check-regexp-match #rx"unknown_ca" (cadr line)))
  ;; TLS 1.2: the server renegotiates (RFC 5746) and gets the client's certificate
  (let-values ([(report line) (run ssl-set-verify! (client-ctx 'tls12 #:key client-key #:cert client-crt))])
    (check-equal? report (list "before" 'ok #t client-subject) "TLS 1.2 renegotiation, trusted client certificate")
    (check-equal? line "after"))
  ;; TLS 1.2 try-verify without a client certificate: the renegotiation proceeds, not verified
  (let-values ([(report line) (run ssl-try-verify! (client-ctx 'tls12))])
    (check-equal? report (list "before" 'ok #f #f) "TLS 1.2 renegotiation, no client certificate")
    (check-equal? line "after"))
  ;; TLS 1.2 set-verify without a client certificate: the renegotiation fails on the server
  (let-values ([(report line) (run ssl-set-verify! (client-ctx 'tls12))])
    (check-equal? (car report) "before")
    (check-regexp-match #rx"ssl-set-verify!: failed .*certificate required" (cadr (cadr report)))
    (check-false (caddr report))))
