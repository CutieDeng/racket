#lang racket/base
(require rackunit
         openssl)

;; Focused form of the first case in "../basic.rkt": client and server
;; talk over in-memory pipes with a small capacity. After the handshake,
;; both sides write at the same time (the server's post-handshake
;; messages and the client's data); an implementation that blocks on a
;; full pipe without also reading from the peer deadlocks here.

(define pem (collection-file-path "test.pem" "openssl"))

;; returns #t if the exchange completes within `secs`
(define (exchange limit secs)
  (define-values (r1 w2) (make-pipe limit))
  (define-values (r2 w1) (make-pipe limit))
  (define client
    (thread (lambda ()
              (define-values (r w)
                (ports->ssl-ports r1 w1 #:mode 'connect #:close-original? #t
                                  #:shutdown-on-close? #t))
              (write-bytes #"abcde" w)
              (flush-output w)
              (unless (equal? (read-string 5 r) "hello") (error 'client "bad reply"))
              (close-input-port r)
              (close-output-port w))))
  (define server
    (thread (lambda ()
              (define ctx (ssl-make-server-context))
              (ssl-load-certificate-chain! ctx pem)
              (ssl-load-private-key! ctx pem)
              (define-values (r w)
                (ports->ssl-ports r2 w2 #:context ctx #:mode 'accept #:close-original? #t
                                  #:shutdown-on-close? #t))
              (unless (equal? (read-bytes 5 r) #"abcde") (error 'server "bad request"))
              (write-string "hello" w)
              (close-output-port w))))
  (define done?
    (and (sync/timeout secs client)
         (sync/timeout secs server)
         #t))
  (kill-thread client)
  (kill-thread server)
  done?)

(module+ test
  (for ([limit (in-list '(1 100 4096))])
    (check-true (exchange limit 10) (format "pipe capacity ~a" limit))))
