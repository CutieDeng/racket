#lang racket/base
(require openssl
         rackunit
         racket/runtime-path)

(define-runtime-path server-key "server_key.pem")
(define-runtime-path server-crt "server_crt.pem")
(define-runtime-path this-dir ".")

(define (call/custodian proc)
  (define cust (make-custodian))
  (parameterize ((current-custodian cust))
    (dynamic-wind void proc (lambda () (custodian-shutdown-all cust)))))

;; ----------------------------------------

(define PORT 55009)

(define (get-cb port)
  ;; the rktcrypto backend supports tls-exporter (Extended Master
  ;; Secret is always negotiated) and tls-server-end-point, but not
  ;; the legacy tls-unique binding
  (list (ssl-channel-binding port 'tls-exporter)
        (ssl-channel-binding port 'tls-server-end-point)))

(define server-ctx
  (ssl-make-server-context 'auto
                           #:private-key `(pem ,server-key)
                           #:certificate-chain server-crt))

;; the rktcrypto TLS 1.2 engine does not provide channel bindings yet,
;; so only the TLS 1.3 protocols are exercised here
(for ([proto '(auto tls13)]
      #:when (member proto (supported-client-protocols)))
  (test-case (format "channel binding agreement, proto = ~v" proto)
    (call/custodian
     (lambda ()
       (define chan (make-channel))
       (define listener (ssl-listen PORT 4 #t "localhost" server-ctx))
       (thread (lambda ()
                 (define-values (sin sout) (ssl-accept listener))
                 (channel-put chan (get-cb sin))
                 (channel-put chan (get-cb sout))))
       (define-values (cin cout) (ssl-connect "localhost" PORT proto))
       (define client-cb (get-cb cin))
       (define server-cb1 (channel-get chan))
       (define server-cb2 (channel-get chan))
       (check-equal? client-cb server-cb1)
       (check-equal? client-cb server-cb2)
       (check-equal? client-cb (get-cb cout))
       (sleep 0.05)))))

;; ----------------------------------------

(define PORT2 5556) ;; must agree with channel-binding/server.c

(require racket/promise
         racket/port
         racket/system
         (only-in openssl/sha1 bytes->hex-string))

(define-runtime-path server-bin "channel-binding/server")

(cond [(and (file-exists? server-bin)
            (memq 'execute (file-or-directory-permissions server-bin)))
       (test-case "channel binding agrees w/ gnutls server"
         (parameterize ((current-subprocess-custodian-mode 'kill)
                        (current-directory this-dir))
           (call/custodian
            (lambda ()
              (define server-cb
                (delay/thread (with-output-to-string (lambda () (system* server-bin)))))
              (sleep 0.2) ;; let the server get started
              (define-values (cin cout)
                ;; Use TLS 1.2 for testing tls-unique.
                (ssl-connect "localhost" PORT2 'tls12))
              (define client-cb
                (format "tls-unique ~a\n"
                        (bytes->hex-string (ssl-channel-binding cin 'tls-unique))))
              (check-equal? client-cb (force server-cb))))))]
      [else (printf "Skipped test against gnutls.\n")])

;; FIXME: find external test for tls-server-end-point?
