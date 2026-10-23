#lang racket/base
(require rackunit
         racket/port
         racket/runtime-path
         openssl)

;; Every TLS 1.2 cipher suite this implementation offers, negotiated between
;; the in-tree client and server over in-memory pipes: a small one
;; (handshake flights and records cross the pipe in pieces) and a large
;; one. The client's cipher policy pins the suite, so the server has no
;; other choice; 20000 bytes are echoed so that several records of odd
;; length are exchanged (CBC padding). RSA suites use "test.pem", ECDSA
;; suites the P-256 identity "server_ec_{key,crt}.pem".

(define rsa-pem (collection-file-path "test.pem" "openssl"))
(define-runtime-path ec-key "server_ec_key.pem")
(define-runtime-path ec-crt "server_ec_crt.pem")

(define suites
  '("ECDHE-RSA-AES128-GCM-SHA256" "ECDHE-RSA-AES256-GCM-SHA384" "ECDHE-RSA-CHACHA20-POLY1305"
    "DHE-RSA-AES128-GCM-SHA256" "DHE-RSA-AES256-GCM-SHA384" "DHE-RSA-CHACHA20-POLY1305"
    "ECDHE-RSA-AES128-SHA256" "ECDHE-RSA-AES256-SHA384" "ECDHE-RSA-AES128-SHA" "ECDHE-RSA-AES256-SHA"
    "DHE-RSA-AES128-SHA256" "DHE-RSA-AES256-SHA256" "DHE-RSA-AES128-SHA" "DHE-RSA-AES256-SHA"
    "ECDHE-ECDSA-AES128-GCM-SHA256" "ECDHE-ECDSA-AES256-GCM-SHA384" "ECDHE-ECDSA-CHACHA20-POLY1305"
    "ECDHE-ECDSA-AES128-SHA256" "ECDHE-ECDSA-AES256-SHA384" "ECDHE-ECDSA-AES128-SHA" "ECDHE-ECDSA-AES256-SHA"))

(define msg (make-bytes 20001 (char->integer #\x)))

;; -> the echoed bytes, or an error message
(define (exchange suite limit)
  (define-values (r1 w2) (make-pipe limit))
  (define-values (r2 w1) (make-pipe limit))
  (define server-error #f)
  (define ecdsa? (regexp-match? #rx"ECDSA" suite))
  (define server
    (thread
     (lambda ()
       (with-handlers ([exn:fail? (lambda (e) (set! server-error (exn-message e)))])
         (define ctx (ssl-make-server-context 'tls12))
         (ssl-load-certificate-chain! ctx (if ecdsa? ec-crt rsa-pem))
         (ssl-load-private-key! ctx (if ecdsa? ec-key rsa-pem))
         (define-values (r w)
           (ports->ssl-ports r2 w2 #:context ctx #:mode 'accept
                             #:close-original? #t #:shutdown-on-close? #t))
         (define got (port->bytes r))
         (write-bytes got w)
         (close-output-port w)
         (close-input-port r)))))
  (define result
    (with-handlers ([exn:fail? (lambda (e) (exn-message e))])
      (define ctx (ssl-make-client-context 'tls12))
      (ssl-set-ciphers! ctx suite)
      (define-values (r w)
        (ports->ssl-ports r1 w1 #:context ctx #:mode 'connect
                          #:close-original? #t #:shutdown-on-close? #t))
      (write-bytes msg w)
      (close-output-port w)
      (begin0 (port->bytes r)
        (close-input-port r))))
  (unless (sync/timeout 30 server)
    (kill-thread server)
    (set! server-error "server timed out"))
  (or server-error result))

(module+ test
  (for* ([suite (in-list suites)]
         [limit (in-list '(10 4096))])
    (check-equal? (exchange suite limit) msg (format "~a over a pipe of capacity ~a" suite limit))))
