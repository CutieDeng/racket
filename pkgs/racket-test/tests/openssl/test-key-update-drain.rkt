#lang racket/base
(require rackunit
         racket/port
         openssl)

;; A KeyUpdate from the peer while our own write is draining incoming
;; records: the drained records must be decrypted in order under the key
;; in force when they arrive, i.e. after the KeyUpdate has been applied.
;; The server writes 1 MB into a small pipe while the client rotates its
;; keys and then writes; the server's write used to fail with
;; bad_record_mac when it decrypted the client's post-update records
;; under the old key at drain time.

(define pem (collection-file-path "test.pem" "openssl"))

(define (exchange limit)
  (define-values (r1 w2) (make-pipe limit))
  (define-values (r2 w1) (make-pipe limit))
  (define big (make-bytes 1000000 (char->integer #\z)))
  (define server
    (thread
     (lambda ()
       (define ctx (ssl-make-server-context))
       (ssl-load-certificate-chain! ctx pem)
       (ssl-load-private-key! ctx pem)
       (define-values (r w) (ports->ssl-ports r2 w2 #:context ctx #:mode 'accept
                                             #:close-original? #t #:shutdown-on-close? #t))
       (write-bytes big w)
       (flush-output w)
       (define got (read-bytes 5 r))
       (close-output-port w)
       (close-input-port r)
       got)))
  (define-values (r w) (ports->ssl-ports r1 w1 #:mode 'connect #:close-original? #t #:shutdown-on-close? #t))
  (ssl-key-update! w)
  (write-bytes #"hello" w)
  (flush-output w)
  (define back (read-bytes 1000000 r))
  (close-output-port w)
  (close-input-port r)
  (define got (sync/timeout 30 (thread-dead-evt server)))
  (values (and got (equal? back big)) (sync/timeout 1 server)))

(module+ test
  (for ([limit (in-list '(4096 65536))])
    (define-values (ok? server-got) (exchange limit))
    (check-true ok? (format "pipe ~a: server data received" limit))
    (check-equal? (and server-got #t) #t (format "pipe ~a: server finished" limit))))
