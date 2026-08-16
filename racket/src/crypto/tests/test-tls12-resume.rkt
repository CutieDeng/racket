#lang racket
;; A2 (1.2): TLS 1.2 SessionTicket resumption (RFC 5077) end to end, our client
;; (1.2-only) <-> our server, over in-memory pipes on SHARED contexts so the
;; server ticket store and the client ticket cache persist across connections.
;; The second connection resumes: an abbreviated handshake sends no certificate,
;; so the resumed client port reports no peer certificate — the observable proof.
(require openssl
         (only-in "../../../collects/openssl/private/rktcrypto-x509-build.rkt"
                  create-self-signed-certificate ec-private-key->pkcs8-pem)
         net/base64)

(define fails 0)
(define (check! name ok?) (printf "  ~a ~a\n" (if ok? "ok:" "FAIL:") name) (unless ok? (set! fails (add1 fails))))

(define-values (cert-der key) (create-self-signed-certificate #:common-name "t12.test"))
(define cert-pem (make-temporary-file "t12c~a.pem"))
(define key-pem  (make-temporary-file "t12k~a.pem"))
(void (call-with-output-file cert-pem #:exists 'replace
        (lambda (o) (fprintf o "-----BEGIN CERTIFICATE-----\n") (write-bytes (base64-encode cert-der #"\n") o)
                    (fprintf o "-----END CERTIFICATE-----\n"))))
(void (call-with-output-file key-pem #:exists 'replace (lambda (o) (write-string (ec-private-key->pkcs8-pem key) o))))

(define server-ctx (ssl-make-server-context 'tls12))
(ssl-load-certificate-chain! server-ctx cert-pem)
(ssl-load-private-key! server-ctx key-pem)
(define client-ctx (ssl-make-client-context 'tls12))   ; 1.2-only -> no 1.3 offer

;; one connection on the shared contexts; returns the client input port
(define (one-connection)
  (define-values (c->s-in c->s-out) (make-pipe))
  (define-values (s->c-in s->c-out) (make-pipe))
  (define done (make-channel))
  (thread (lambda ()
            (with-handlers ([(lambda (_) #t) (lambda (e) (channel-put done (cons 'err e)))])
              (define-values (si so) (ports->ssl-ports c->s-in s->c-out #:mode 'accept #:context server-ctx))
              (write-bytes #"DATA" so) (flush-output so)
              (channel-put done 'ok))))
  (define-values (ci co) (ports->ssl-ports s->c-in c->s-out #:mode 'connect #:context client-ctx #:hostname "t12.test"))
  (define got (read-bytes 4 ci))
  (values (sync/timeout 10 done) got ci))

(printf "A2 TLS 1.2 SessionTicket resumption (loopback):\n")

(define-values (s1 d1 ci1) (one-connection))
(check! "conn 1 full handshake + data" (and (eq? s1 'ok) (equal? d1 #"DATA")))
(check! "conn 1 presents the server certificate" (regexp-match? #rx#"CN=t12.test" (or (ssl-peer-subject-name ci1) #"")))

(define-values (s2 d2 ci2) (one-connection))
(check! "conn 2 resumed handshake + data" (and (eq? s2 'ok) (equal? d2 #"DATA")))
(check! "conn 2 is abbreviated (no certificate sent — resumption)" (not (ssl-peer-subject-name ci2)))

(delete-file cert-pem) (delete-file key-pem)
(printf (if (zero? fails) "tls12-resume: 0 failure(s)\n" (format "tls12-resume: ~a FAILURE(S)\n" fails)))
(exit (if (zero? fails) 0 1))
