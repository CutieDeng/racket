#lang racket
;; A1: the SSL input port is non-blocking / sync-able. A read attempt with no
;; whole TLS record buffered must NOT block the thread — read-bytes-avail!*
;; returns 0 and (read-bytes-evt ...) stays unready — yet blocking reads and
;; concurrent connections still work.
(require openssl
         (only-in "../../../collects/openssl/private/rktcrypto-x509-build.rkt"
                  create-self-signed-certificate ec-private-key->pkcs8-pem)
         net/base64)

(define fails 0)
(define (check! name ok?) (printf "  ~a ~a\n" (if ok? "ok:" "FAIL:") name) (unless ok? (set! fails (add1 fails))))

;; write a self-signed cert + key to temp PEM files and build a server context
(define-values (cert-der key) (create-self-signed-certificate #:common-name "nb.test"))
(define cert-pem (make-temporary-file "nbcert~a.pem"))
(define key-pem  (make-temporary-file "nbkey~a.pem"))
(void (call-with-output-file cert-pem #:exists 'replace
        (lambda (o) (fprintf o "-----BEGIN CERTIFICATE-----\n") (write-bytes (base64-encode cert-der #"\n") o)
                    (fprintf o "-----END CERTIFICATE-----\n"))))
(void (call-with-output-file key-pem #:exists 'replace (lambda (o) (write-string (ec-private-key->pkcs8-pem key) o))))

(define (server-ctx)
  (define c (ssl-make-server-context 'tls13))
  (ssl-load-certificate-chain! c cert-pem)
  (ssl-load-private-key! c key-pem)
  c)

;; one connected client<->server pair over pipes; the server sends only when told
(define (make-pair)
  (define-values (c->s-in c->s-out) (make-pipe))
  (define-values (s->c-in s->c-out) (make-pipe))
  (define go (make-semaphore 0))
  (define sready (make-channel))
  (thread (lambda ()
            (with-handlers ([(lambda (_) #t) (lambda (e) (channel-put sready (cons 'err e)))])
              (define-values (si so) (ports->ssl-ports c->s-in s->c-out #:mode 'accept #:context (server-ctx)))
              (channel-put sready 'up)
              (semaphore-wait go)
              (write-bytes #"DATA" so) (flush-output so))))
  (define-values (ci co) (ports->ssl-ports s->c-in c->s-out #:mode 'connect #:context (ssl-make-client-context 'tls13)))
  (values ci co go sready))

(printf "A1 non-blocking / sync-able SSL ports:\n")

(define-values (ci co go sready) (make-pair))
(check! "server handshake completed" (eq? 'up (sync/timeout 5 sready)))

;; 1. no application data yet → a non-blocking read must return 0, not block
(check! "read-bytes-avail!* returns 0 with no data (does not block)"
        (eqv? 0 (read-bytes-avail!* (make-bytes 16) ci)))
;; 2. an event-based read stays unready while there is no data
(check! "read-bytes-evt is unready with no data"
        (eq? #f (sync/timeout 0.4 (read-bytes-evt 4 ci))))
;; 3. once the server sends, the event becomes ready and yields the data
(semaphore-post go)
(check! "read-bytes-evt delivers the data once sent"
        (equal? #"DATA" (sync/timeout 5 (read-bytes-evt 4 ci))))

;; 4. concurrency: 3 connections, each blocked waiting on its own read, must not
;;    serialize — releasing them in reverse order still completes all promptly.
(define trios (for/list ([i 3]) (call-with-values make-pair list)))
(for ([t (in-list trios)]) (sync/timeout 5 (cadddr t)))   ; wait each server 'up (item 4 = sready)
(define readers
  (for/list ([t (in-list trios)])
    (define ci* (car t))
    (thread (lambda () (read-bytes 4 ci*)))))   ; each blocks until its server sends
(sleep 0.3)
(check! "all readers still blocked before any send" (andmap thread-running? readers))
(for ([t (in-list (reverse trios))]) (semaphore-post (caddr t)))  ; release in reverse
(check! "all readers complete after sends (no serialization/deadlock)"
        (for/and ([r (in-list readers)]) (sync/timeout 5 (thread-dead-evt r))))

(delete-file cert-pem) (delete-file key-pem)
(printf (if (zero? fails) "nonblocking: 0 failure(s)\n" (format "nonblocking: ~a FAILURE(S)\n" fails)))
(exit (if (zero? fails) 0 1))
