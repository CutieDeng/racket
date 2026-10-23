#lang racket/base
(require rackunit
         racket/tcp
         racket/port
         racket/system
         racket/runtime-path
         openssl
         "local-server.rkt")

;; API behaviors that match the libssl-based implementation:
;;  - a server context made with 'tls12 negotiates TLS 1.2 only;
;;  - cipher strings: "!" is permanent, "-" is not, COMPLEMENTOFDEFAULT is
;;    empty, and a specification matching nothing fails in ssl-set-ciphers!;
;;  - DER private keys (asn1? #t and the 'der #:private-key form);
;;  - ssl-load-verify-root-certificates! accepts an SSL port;
;;  - closing the output port sends close_notify only with #:shutdown-on-close?.

(define-runtime-path dir ".")
(define openssl
  (for/first ([p (in-list (list "/opt/homebrew/opt/openssl@3/bin/openssl" "/usr/local/opt/openssl@3/bin/openssl"
                                "/opt/homebrew/bin/openssl" "/usr/bin/openssl"))]
              #:when (file-exists? p))
    p))

(module+ test
  ;; 'tls12 server context
  (let ()
    (define sctx (ssl-make-server-context 'tls12))
    (ssl-load-private-key! sctx server-key)
    (ssl-load-certificate-chain! sctx server-crt)
    (define-values (port results) (start-server sctx))
    (define-values (ti to) (tcp-connect "127.0.0.1" port))
    (define-values (in out)
      (ports->ssl-ports ti to #:mode 'connect #:context (ssl-make-client-context 'auto)
                        #:hostname "server.example.com" #:close-original? #t))
    (check-equal? (ssl-protocol-version in) 'tls12 "'tls12 server context pins TLS 1.2")
    (check-equal? (read-line in) "hello")
    (close-input-port in) (close-output-port out))

  ;; cipher strings
  (let ()
    (define (policy str)
      (define ctx (ssl-make-client-context))
      (ssl-set-ciphers! ctx str)
      ctx)
    (check-not-exn (lambda () (policy "ALL:!COMPLEMENTOFDEFAULT")) "COMPLEMENTOFDEFAULT is empty")
    (check-exn #rx"no cipher match" (lambda () (policy "RC4")) "nothing matches")
    (check-exn #rx"no cipher match" (lambda () (policy "ALL:!AESGCM:!CHACHA20:!AESCBC:AESGCM"))
               "! removes permanently")
    (check-not-exn (lambda () (policy "ALL:-AESGCM:-CHACHA20:-AESCBC:AESGCM")) "- can be re-added"))

  ;; DER private keys
  (when openssl
    (define der-path (build-path (find-system-path 'temp-dir) "racket-openssl-test-key.der"))
    (system* openssl "pkcs8" "-topk8" "-nocrypt" "-in" (path->string server-key) "-outform" "DER" "-out" (path->string der-path))
    (define sctx (ssl-make-server-context 'auto))
    (ssl-load-private-key! sctx der-path #t #t)
    (ssl-load-certificate-chain! sctx server-crt)
    (define-values (port results) (start-server sctx))
    (check-equal? (connect-and-read port (ssl-make-client-context 'auto) "server.example.com") "hello"
                  "server identity from a DER (PKCS#8) key")
    (define sctx2 (ssl-make-server-context 'auto #:private-key (list 'der der-path) #:certificate-chain server-crt))
    (define-values (port2 results2) (start-server sctx2))
    (check-equal? (connect-and-read port2 (ssl-make-client-context 'auto) "server.example.com") "hello"
                  "'der #:private-key form")
    (delete-file der-path))

  ;; verify roots loaded through an SSL port's context
  (let ()
    (define sctx (ssl-make-server-context 'auto))
    (ssl-load-private-key! sctx server-key)
    (ssl-load-certificate-chain! sctx server-crt)
    (define-values (port results) (start-server sctx))
    (define cctx (ssl-make-client-context 'auto))
    (define-values (ti to) (tcp-connect "127.0.0.1" port))
    (define-values (in out)
      (ports->ssl-ports ti to #:mode 'connect #:context cctx #:hostname "server.example.com" #:close-original? #t))
    (check-not-exn (lambda () (ssl-load-verify-root-certificates! in cacert)) "port accepted")
    (close-input-port in) (close-output-port out))

  ;; shutdown-on-close?: without it, the peer sees a transport EOF, not close_notify
  (for ([shutdown? (in-list '(#t #f))])
    (define-values (r1 w2) (make-pipe))
    (define-values (r2 w1) (make-pipe))
    (define pem (collection-file-path "test.pem" "openssl"))
    (define server
      (thread (lambda ()
                (define ctx (ssl-make-server-context))
                (ssl-load-certificate-chain! ctx pem) (ssl-load-private-key! ctx pem)
                (define-values (r w) (ports->ssl-ports r2 w2 #:context ctx #:mode 'accept))
                (read-bytes 5 r)
                (close-output-port w) (close-input-port r))))
    (define-values (r w) (ports->ssl-ports r1 w1 #:mode 'connect #:shutdown-on-close? shutdown?))
    (write-bytes #"hello" w) (flush-output w)
    (sync server)
    (close-output-port w)
    ;; what the client wrote into the raw pipe after "hello": a close_notify record or nothing
    (define leftover (let ([b (make-bytes 64)]) (read-bytes-avail!* b r2)))
    (check-equal? (and (exact-integer? leftover) (> leftover 0)) shutdown?
                  (format "shutdown-on-close? ~a" shutdown?))))
