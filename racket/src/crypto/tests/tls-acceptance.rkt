#lang racket/base

;; TLS acceptance harness for the OpenSSL removal.
;;
;; The last hard dependency on OpenSSL is the TLS stack. This file is the
;; ACCEPTANCE ORACLE for the from-scratch rktcrypto TLS backend: it drives
;; client<->server loopback handshakes + data exchange entirely through the
;; public `openssl` API (`ports->ssl-ports`, `ssl-make-{client,server}-
;; context`), so it does not care which backend is underneath.
;;
;;   racket/bin/racket racket/src/crypto/tests/tls-acceptance.rkt
;;
;; With no TLS backend present it SKIPS; with a backend present it is the
;; functional gate. `ssl-available?` is #t iff a backend loaded.

(require openssl
         racket/port
         racket/runtime-path)

(define-runtime-path test-pem "../../../collects/openssl/test.pem")

(define failures 0)
(define (check! name ok?)
  (if ok? (printf "  ok: ~a\n" name)
      (begin (set! failures (add1 failures)) (eprintf "FAIL: ~a\n" name))))

;; A full in-process TLS session over two pipes. `client-ctx`/`server-ctx`
;; are built by the caller; `hostname` is passed to the client;
;; `payload-size` bytes are echoed. Returns 'ok, or (cons 'role exn) on the
;; first failing side. When `expect-fail` is 'client the client handshake is
;; expected to raise (negative test): returns 'ok iff it did.
(define (loopback #:server-ctx server-ctx
                  #:client-ctx client-ctx
                  #:hostname [hostname #f]
                  #:client-alpn [client-alpn '()]
                  #:payload-size [payload-size 4096]
                  #:expect-client-fail [expect-client-fail #f])
  (define payload (make-bytes payload-size))
  (for ([i (in-range payload-size)]) (bytes-set! payload i (bitwise-and i 255)))
  (define-values (c->s-in c->s-out) (make-pipe))
  (define-values (s->c-in s->c-out) (make-pipe))
  (define result (make-channel))
  (thread
   (lambda ()
     (with-handlers ([(lambda (_) #t) (lambda (e) (channel-put result (cons 'server e)))])
       (define-values (si so)
         (ports->ssl-ports c->s-in s->c-out #:mode 'accept #:context server-ctx))
       (let loop ([left payload-size])
         (when (> left 0)
           (define chunk (read-bytes (min left 65536) si))
           (when (bytes? chunk) (write-bytes chunk so) (flush-output so)
                 (loop (- left (bytes-length chunk))))))
       (channel-put result 'server-ok))))
  (define client-outcome
    (with-handlers ([(lambda (_) #t) (lambda (e) (cons 'client e))])
      (define-values (ci co)
        (ports->ssl-ports s->c-in c->s-out #:mode 'connect #:context client-ctx
                          #:hostname hostname #:alpn client-alpn))
      (write-bytes payload co) (flush-output co)
      (let loop ([acc #""])
        (if (>= (bytes-length acc) payload-size)
            (list 'client-ok ci acc)
            (let ([b (read-bytes (- payload-size (bytes-length acc)) ci)])
              (if (eof-object? b) (list 'client-ok ci acc) (loop (bytes-append acc b))))))))
  (cond
    [expect-client-fail
     ;; negative test: the client handshake must have raised
     (and (pair? client-outcome) (eq? (car client-outcome) 'client))]
    [(and (pair? client-outcome) (eq? (car client-outcome) 'client)) client-outcome]
    [else
     (define sr (sync/timeout 30 result))
     (and (eq? sr 'server-ok)
          (equal? (caddr client-outcome) payload)
          (cadr client-outcome))]))   ; return the client input port for inspection

(define (server-ctx-with-test-cert)
  (define c (ssl-make-server-context 'tls13))
  (ssl-load-certificate-chain! c test-pem)
  (ssl-load-private-key! c test-pem)
  c)

(define (run-all)
  (cond
    [(not ssl-available?)
     (printf "TLS acceptance: SKIP -- no TLS backend loaded (ssl-available? = #f).\n")]
    [else
     (printf "TLS acceptance: backend present (ssl-available? = #t).\n")

     ;; 1. Basic TLS 1.3 loopback, no verification.
     (check! "TLS 1.3 loopback handshake + 4KiB echo"
             (port? (loopback #:server-ctx (server-ctx-with-test-cert)
                              #:client-ctx (ssl-make-client-context 'tls13))))

     ;; 2. ALPN negotiation across the loopback.
     (let ([sc (server-ctx-with-test-cert)])
       (ssl-set-server-alpn! sc (list #"h2" #"http/1.1"))
       (define ci (loopback #:server-ctx sc
                            #:client-ctx (ssl-make-client-context 'tls13)
                            #:client-alpn (list #"http/1.1")))
       (check! "ALPN negotiated (http/1.1)"
               (and (port? ci) (equal? (ssl-get-alpn-selected ci) #"http/1.1"))))

     ;; 3. Large (1 MiB) chunked transfer.
     (check! "1 MiB echo round-trip"
             (port? (loopback #:server-ctx (server-ctx-with-test-cert)
                              #:client-ctx (ssl-make-client-context 'tls13)
                              #:payload-size (* 1024 1024))))

     ;; 4. Verified loopback: client trusts the test cert as a root and
     ;;    checks the hostname (test.pem CN=lambda).
     (let ([cc (ssl-make-client-context 'tls13)])
       (ssl-set-verify! cc #t)
       (ssl-set-verify-hostname! cc #t)
       (ssl-load-verify-root-certificates! cc test-pem)
       (define ci (loopback #:server-ctx (server-ctx-with-test-cert)
                            #:client-ctx cc #:hostname "lambda"))
       (check! "verified loopback (trusted root + hostname)"
               (and (port? ci) (ssl-peer-verified? ci)
                    (regexp-match? #rx#"CN=lambda" (ssl-peer-subject-name ci)))))

     ;; 5. Negative: wrong hostname must be rejected.
     (let ([cc (ssl-make-client-context 'tls13)])
       (ssl-set-verify! cc #t)
       (ssl-set-verify-hostname! cc #t)
       (ssl-load-verify-root-certificates! cc test-pem)
       (check! "wrong hostname rejected"
               (loopback #:server-ctx (server-ctx-with-test-cert)
                         #:client-ctx cc #:hostname "not-lambda.example"
                         #:expect-client-fail #t)))

     ;; 6. Negative: untrusted root must be rejected (empty trust store).
     (let ([cc (ssl-make-client-context 'tls13)])
       (ssl-set-verify! cc #t)
       (check! "untrusted certificate rejected"
               (loopback #:server-ctx (server-ctx-with-test-cert)
                         #:client-ctx cc #:hostname "lambda"
                         #:expect-client-fail #t)))

     (printf "TLS acceptance: ~a failure(s)\n" failures)
     (when (> failures 0) (error 'tls-acceptance "~a check(s) failed" failures))]))

(module+ main (run-all))
(module+ test (run-all))
