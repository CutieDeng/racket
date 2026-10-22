#lang racket/base
(require racket/tcp
         racket/runtime-path
         openssl)

;; Helpers for the tests in this directory: a local TLS server that
;; reports, per accepted connection, what it observed about the client,
;; and a client that connects with an explicit hostname.

(provide server-key server-crt server-crt2 client-key client-crt cacert self-signed-pem
         start-server
         server-result
         connect-and-read)

(define-runtime-path server-key "../server_key.pem")
(define-runtime-path server-crt "../server_crt.pem")     ; server.example.com, signed by cacert
(define-runtime-path server-crt2 "../server_crt2.pem")   ; server2.example.com, signed by cacert
(define-runtime-path client-key "../client_key.pem")
(define-runtime-path client-crt "../client_crt.pem")     ; client.example.com, signed by cacert
(define-runtime-path cacert "../cacert.pem")             ; test CA, not a default verify source
;; self-signed certificate and key (CN=lambda), not issued by the test CA
(define self-signed-pem (collection-file-path "test.pem" "openssl"))

;; Starts a server on a fresh port; returns the port number and a
;; channel. For each connection, the channel receives either
;;   (list 'ok peer-verified? peer-subject)
;; or
;;   (list 'exn message)
;; Each connection is handled in its own thread, so a client that gives
;; up during a handshake does not block later connections.
(define (start-server server-ctx)
  (define listener (tcp-listen 0 8 #t "127.0.0.1"))
  (define-values (addr port other-addr other-port) (tcp-addresses listener #t))
  (define results (make-channel))
  (void
   (thread
    (lambda ()
      (let loop ()
        (define-values (ti to) (tcp-accept listener))
        (thread
         (lambda ()
           (define result
             (with-handlers ([exn:fail? (lambda (e)
                                          (close-input-port ti)
                                          (close-output-port to)
                                          (list 'exn (exn-message e)))])
               (define-values (in out)
                 (ports->ssl-ports ti to #:mode 'accept #:context server-ctx
                                   #:close-original? #t))
               (define r (list 'ok (ssl-peer-verified? in) (ssl-peer-subject-name in)))
               (write-bytes #"hello\n" out)
               (flush-output out)
               (close-output-port out)
               (close-input-port in)
               r))
           (sync/timeout 10 (channel-put-evt results result))))
        (loop)))))
  (values port results))

;; The server's observation for the most recent connection, or 'timeout
(define (server-result results)
  (or (sync/timeout 10 results) 'timeout))

;; Connects to the local server, checking the peer against `hostname`;
;; returns the line the server sends
(define (connect-and-read port ctx hostname)
  (define-values (ti to) (tcp-connect "127.0.0.1" port))
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
