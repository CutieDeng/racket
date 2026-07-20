#lang racket/base

;; TLS acceptance harness for the OpenSSL removal.
;;
;; The last hard dependency on OpenSSL is the TLS stack: `openssl/mzssl`
;; is a thin wrapper over libssl, and it is what a from-scratch rktcrypto
;; TLS backend must replace. This file is the ACCEPTANCE ORACLE for that
;; replacement: a client<->server loopback handshake + data exchange
;; driven entirely through the public `openssl` API (`ports->ssl-ports`,
;; `ssl-make-{client,server}-context`), so it does not care which backend
;; is underneath.
;;
;;   racket/bin/racket racket/src/crypto/tests/tls-acceptance.rkt
;;   raco test racket/src/crypto/tests/tls-acceptance.rkt
;;
;; Today: with OpenSSL's libssl present it exercises the current backend
;; (baseline). With no TLS backend present -- as in a build that has
;; already dropped the OpenSSL binaries -- it SKIPS rather than fails, and
;; says so. When the rktcrypto TLS backend lands behind the same API,
;; this same file becomes its functional gate with no changes.
;;
;; `ssl-available?` gates the whole thing: it is #t iff a TLS backend
;; loaded. The migration goal is to make it #t again with rktcrypto and
;; have this suite pass.

(require openssl
         racket/port
         racket/runtime-path)

(define-runtime-path test-pem "../../../collects/openssl/test.pem")

(define failures 0)
(define (check! name ok?)
  (unless ok? (set! failures (add1 failures)) (eprintf "FAIL: ~a\n" name)))

;; One in-process TLS handshake over a pair of pipes: server thread and
;; client thread each wrap their pipe ends with ports->ssl-ports, then
;; exchange a payload both directions. Returns #t on a clean round-trip.
(define (loopback-roundtrip)
  (define server-ctx (ssl-make-server-context 'auto))
  (ssl-load-certificate-chain! server-ctx test-pem)
  (ssl-load-private-key! server-ctx test-pem)
  (define client-ctx (ssl-make-client-context 'auto))
  ;; self-signed test cert -> don't verify the peer for this loopback
  (define payload (make-bytes 4096))
  (for ([i (in-range (bytes-length payload))]) (bytes-set! payload i (bitwise-and i 255)))
  ;; two pipes: c->s and s->c
  (define-values (c->s-in c->s-out) (make-pipe))
  (define-values (s->c-in s->c-out) (make-pipe))
  (define result (make-channel))
  (define server
    (thread
     (lambda ()
       (with-handlers ([(lambda (_) #t) (lambda (e) (channel-put result (cons 'server-error e)))])
         (define-values (si so)
           (ports->ssl-ports c->s-in s->c-out #:mode 'accept #:context server-ctx))
         (define got (read-bytes (bytes-length payload) si))
         (write-bytes got so) (flush-output so)   ; echo back
         (channel-put result 'server-ok)))))
  (define client-got
    (with-handlers ([(lambda (_) #t) (lambda (e) (cons 'client-error e))])
      (define-values (ci co)
        (ports->ssl-ports s->c-in c->s-out #:mode 'connect #:context client-ctx))
      (write-bytes payload co) (flush-output co)
      (define echo (read-bytes (bytes-length payload) ci))
      echo))
  (define server-result (sync/timeout 20 result))
  (and (equal? server-result 'server-ok)
       (bytes? client-got)
       (equal? client-got payload)))

(define (run-all)
  (cond
    [(not ssl-available?)
     (printf "TLS acceptance: SKIP -- no TLS backend loaded (ssl-available? = #f).\n")
     (printf "  This is expected on a build with OpenSSL removed and no rktcrypto\n")
     (printf "  TLS backend yet. When a backend is present this suite exercises it.\n")]
    [else
     (printf "TLS acceptance: backend present (ssl-available? = #t); running loopback.\n")
     (check! "loopback handshake + echo round-trip" (loopback-roundtrip))
     (printf "TLS acceptance: ~a failure(s)\n" failures)
     (when (> failures 0) (error 'tls-acceptance "~a check(s) failed" failures))]))

(module+ main (run-all))
(module+ test (run-all))
