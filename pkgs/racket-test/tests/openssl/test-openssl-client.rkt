#lang racket/base
(require rackunit
         racket/port
         racket/system
         racket/string
         racket/runtime-path
         openssl)

;; Server-side behaviors observed with an external OpenSSL `s_client`:
;;  - the TLS 1.2 ServerKeyExchange signature scheme follows the client's
;;    signature_algorithms (a client that offers only RSA PKCS#1 gets one);
;;  - the CertificateRequest carries the names loaded with
;;    ssl-load-suggested-certificate-authorities! (s_client prints them as
;;    "Acceptable client certificate CA names").
;; Skipped when no OpenSSL with -sigalgs support is available.

(define-runtime-path server-key "server_key.pem")
(define-runtime-path server-crt "server_crt.pem")
(define-runtime-path cacert "cacert.pem")
(define-runtime-path dir ".")

(define openssl
  (for/first ([p (in-list (list "/opt/homebrew/opt/openssl@3/bin/openssl" "/usr/local/opt/openssl@3/bin/openssl"
                                "/opt/homebrew/bin/openssl" "/usr/local/bin/openssl" "/usr/bin/openssl"))]
              #:when (and (file-exists? p)
                          (regexp-match? #rx"^OpenSSL [3-9]" (with-output-to-string (lambda () (system* p "version"))))))
    p))

;; -> (values server-report s_client-output)
(define (run-s_client ctx . args)
  (define listener (ssl-listen 0 4 #t "127.0.0.1" ctx))
  (define-values (addr port other-addr other-port) (ssl-addresses listener #t))
  (define report (make-channel))
  (thread
   (lambda ()
     (channel-put report
                  (with-handlers ([exn:fail? (lambda (e) (list 'exn (exn-message e)))])
                    (define-values (in out) (ssl-accept listener))
                    (define line (read-line in))
                    (write-bytes #"pong\n" out) (flush-output out)
                    (close-output-port out) (close-input-port in)
                    (list 'ok line (ssl-protocol-version in))))))
  (define-values (sp out in err)
    (apply subprocess #f #f #f openssl "s_client" "-connect" (format "127.0.0.1:~a" port) "-ign_eof" args))
  (write-bytes #"ping\n" in) (flush-output in)
  (define text (let ([o (open-output-string)])
                 (define t (thread (lambda () (copy-port out o))))
                 (sync/timeout 10 t)
                 (get-output-string o)))
  (close-output-port in)
  (subprocess-kill sp #t) (subprocess-wait sp)
  (define errtext (port->string err))
  (close-input-port out) (close-input-port err)
  (ssl-close listener)
  (values (or (sync/timeout 5 report) 'timeout) (string-append text errtext)))

(define (server-ctx)
  (define ctx (ssl-make-server-context 'auto))
  (ssl-load-private-key! ctx server-key)
  (ssl-load-certificate-chain! ctx server-crt)
  ctx)

(module+ test
  (cond
    [(not openssl) (printf "no OpenSSL 3 found; skipping\n")]
    [else
     ;; RSA PKCS#1 only client, TLS 1.2
     (let-values ([(report text) (run-s_client (server-ctx) "-tls1_2" "-sigalgs" "RSA+SHA256")])
       (check-equal? report (list 'ok "ping" 'tls12) "client offering only rsa_pkcs1_sha256")
       (check-regexp-match #rx"pong" text))
     ;; PSS-only client, TLS 1.2
     (let-values ([(report text) (run-s_client (server-ctx) "-tls1_2" "-sigalgs" "RSA-PSS+SHA384")])
       (check-equal? report (list 'ok "ping" 'tls12) "client offering only rsa_pss_rsae_sha384"))
     ;; each identity key type as our server, with an OpenSSL client, TLS 1.3 and 1.2
     (for* ([kt (in-list '("server_ec" "server_p384" "server_p521" "server_ed25519"))]
            [version (in-list '("-tls1_3" "-tls1_2"))])
       (define ctx (ssl-make-server-context 'auto))
       (ssl-load-private-key! ctx (build-path dir (string-append kt "_key.pem")))
       (ssl-load-certificate-chain! ctx (build-path dir (string-append kt "_crt.pem")))
       (let-values ([(report text) (run-s_client ctx version "-CAfile" (path->string cacert) "-verify_return_error")])
         (check-equal? (car report) 'ok (format "~a ~a" kt version))
         (check-regexp-match #rx"Verify return code: 0" text (format "~a ~a verified by s_client" kt version))))
     ;; suggested CA names in the CertificateRequest, TLS 1.3 and 1.2
     (for ([version (in-list '("-tls1_3" "-tls1_2"))])
       (define ctx (server-ctx))
       (ssl-load-verify-root-certificates! ctx cacert)
       (ssl-load-suggested-certificate-authorities! ctx cacert)
       (ssl-try-verify! ctx #t)
       (let-values ([(report text) (run-s_client ctx version)])
         (check-equal? (car report) 'ok (format "~a with a CertificateRequest" version))
         (check-regexp-match #rx"Acceptable client certificate CA names\n[^\n]*CN *= *example.com" text
                             (format "~a: CA names sent" version))))]))
