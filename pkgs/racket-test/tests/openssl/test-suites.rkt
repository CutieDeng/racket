#lang racket/base
(require rackunit
         racket/port
         openssl)

;; Every TLS 1.2 cipher suite this implementation offers for an RSA
;; certificate, negotiated between the in-tree client and server over
;; in-memory pipes: a small one (handshake flights and records cross the
;; pipe in pieces) and a large one. The client's cipher policy pins the
;; suite, so the server has no other choice; 20000 bytes are echoed so
;; that several records of odd length are exchanged (CBC padding).
;;
;; The ECDSA variants need a P-256 certificate, which this directory does
;; not have; they are exercised by the interop runs against OpenSSL.

(define pem (collection-file-path "test.pem" "openssl"))

(define suites
  '("ECDHE-RSA-AES128-GCM-SHA256" "ECDHE-RSA-AES256-GCM-SHA384" "ECDHE-RSA-CHACHA20-POLY1305"
    "DHE-RSA-AES128-GCM-SHA256" "DHE-RSA-AES256-GCM-SHA384" "DHE-RSA-CHACHA20-POLY1305"
    "ECDHE-RSA-AES128-SHA256" "ECDHE-RSA-AES256-SHA384" "ECDHE-RSA-AES128-SHA" "ECDHE-RSA-AES256-SHA"
    "DHE-RSA-AES128-SHA256" "DHE-RSA-AES256-SHA256" "DHE-RSA-AES128-SHA" "DHE-RSA-AES256-SHA"))

(define msg (make-bytes 20001 (char->integer #\x)))

;; -> the echoed bytes, or an error message
(define (exchange suite limit)
  (define-values (r1 w2) (make-pipe limit))
  (define-values (r2 w1) (make-pipe limit))
  (define server-error #f)
  (define server
    (thread
     (lambda ()
       (with-handlers ([exn:fail? (lambda (e) (set! server-error (exn-message e)))])
         (define ctx (ssl-make-server-context 'tls12))
         (ssl-load-certificate-chain! ctx pem)
         (ssl-load-private-key! ctx pem)
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
