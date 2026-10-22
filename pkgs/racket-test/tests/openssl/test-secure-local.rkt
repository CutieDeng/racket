#lang racket/base
(require rackunit
         racket/tcp
         racket/runtime-path
         openssl)

;; Offline counterpart of "test-secure.rkt": the 'secure protocol
;; symbol must produce a context that verifies the peer's certificate
;; and hostname. The server below uses a certificate signed by the test
;; CA in "cacert.pem", which is not among the default verify sources.

(define-runtime-path server-key "server_key.pem")
(define-runtime-path server-crt "server_crt.pem")
(define-runtime-path client-key "client_key.pem")
(define-runtime-path client-crt "client_crt.pem")
(define-runtime-path cacert "cacert.pem")

(define server-ctx (ssl-make-server-context 'auto))
(ssl-load-private-key! server-ctx server-key)
(ssl-load-certificate-chain! server-ctx server-crt)

(define listener (tcp-listen 0 4 #t "127.0.0.1"))
(define port-no
  (let-values ([(addr port other-addr other-port) (tcp-addresses listener #t)])
    port))

;; each connection gets its own thread, so that a client that gives up
;; in the middle of a handshake does not block later connections
(void
 (thread
  (lambda ()
    (let loop ()
      (define-values (ti to) (tcp-accept listener))
      (thread
       (lambda ()
         (with-handlers ([exn:fail? (lambda (e) (close-input-port ti) (close-output-port to))])
           (define-values (in out)
             (ports->ssl-ports ti to #:mode 'accept #:context server-ctx
                               #:close-original? #t))
           (write-bytes #"hello\n" out)
           (close-output-port out)
           (close-input-port in))))
      (loop)))))

;; connects to the local server, checking the certificate against `hostname`
(define (connect-and-read ctx hostname)
  (define-values (ti to) (tcp-connect "127.0.0.1" port-no))
  (define-values (in out)
    (with-handlers ([exn:fail? (lambda (e)
                                 (close-input-port ti)
                                 (close-output-port to)
                                 (raise e))])
      (ports->ssl-ports ti to #:mode 'connect #:context ctx #:hostname hostname
                        #:close-original? #t)))
  (begin0
    (read-line in)
    (close-input-port in)
    (close-output-port out)))

(module+ test
  ;; 'secure, with and without a client certificate, rejects the
  ;; untrusted server certificate
  (check-exn exn:fail?
             (lambda () (ssl-connect "127.0.0.1" port-no 'secure)))
  (check-exn exn:fail?
             (lambda () (connect-and-read (ssl-make-client-context 'secure)
                                          "server.example.com")))
  (check-exn exn:fail?
             (lambda () (connect-and-read (ssl-make-client-context
                                           'secure
                                           #:private-key `(pem ,client-key)
                                           #:certificate-chain client-crt)
                                          "server.example.com")))
  (check-exn exn:fail?
             (lambda () (connect-and-read (ssl-secure-client-context)
                                          "server.example.com")))

  ;; a 'secure context is sealed, so verification cannot be turned off
  (check-exn exn:fail?
             (lambda () (ssl-set-verify! (ssl-make-client-context 'secure) #f)))
  (check-exn exn:fail?
             (lambda () (ssl-set-verify-hostname! (ssl-make-client-context 'secure) #f)))

  ;; controls: trusting the test CA makes the same server acceptable,
  ;; but only under the hostname in its certificate
  (define (verifying-ctx)
    (define ctx (ssl-make-client-context 'auto))
    (ssl-load-verify-root-certificates! ctx cacert)
    (ssl-set-verify! ctx #t)
    (ssl-set-verify-hostname! ctx #t)
    ctx)
  (check-equal? (connect-and-read (verifying-ctx) "server.example.com") "hello")
  (check-exn exn:fail?
             (lambda () (connect-and-read (verifying-ctx) "wrong.example.com")))

  ;; 'auto does not verify
  (check-equal? (connect-and-read (ssl-make-client-context 'auto) "server.example.com")
                "hello"))
