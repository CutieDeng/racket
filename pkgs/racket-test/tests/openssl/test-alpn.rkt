#lang racket/base
(require openssl
         rackunit
         racket/tcp
         racket/runtime-path
         racket/system)

;; The system `openssl` on macOS is LibreSSL, whose `s_server` closes the
;; connection on these handshakes; prefer an OpenSSL 3+ build when one is
;; installed, as test-openssl-client.rkt does.
(define openssl-exe
  (or (for/first ([p '("/opt/homebrew/opt/openssl@3/bin/openssl"
                       "/opt/homebrew/bin/openssl"
                       "/usr/local/opt/openssl@3/bin/openssl"
                       "/usr/local/bin/openssl")]
                  #:when (file-exists? p))
        p)
      "/usr/bin/openssl"))


;; Tests for ALPN client support

(define-runtime-path server-key "server_key.pem")
(define-runtime-path server-crt "server_crt.pem")

;; server listens on localhost:PORT+counter
;; (need to change port, otherwise get "Address still in use")
(define PORT 4493)

;; Set up server
(define server-cust (make-custodian))
(define srvout (open-output-string))
(define-values (_srvout _srvin srvpid _srverr srvctl)
  (parameterize ((current-custodian server-cust)
                 (current-subprocess-custodian-mode 'kill))
    (apply values
           (process* openssl-exe "s_server"
                     "-accept" (number->string PORT)
                     "-cert" server-crt "-key" server-key
                     "-alpn" "rkt-proto,other"))))
(sleep 0.2) ;; wait for server to bind the port

(let ()
  ;; Check no protocol is selected if none is requested.
  (define-values (in out)
    (ssl-connect "localhost" PORT))
  (check-equal? (ssl-get-alpn-selected in) #f)
  (check-equal? (ssl-get-alpn-selected out) #f)
  (begin (close-input-port in) (close-output-port out)))

(let ()
  ;; Check supported protocol is selected.
  (define-values (in out)
    (ssl-connect "localhost" PORT #:alpn '(#"rkt-proto")))
  (check-equal? (ssl-get-alpn-selected in) #"rkt-proto")
  (check-equal? (ssl-get-alpn-selected out) #"rkt-proto")
  (begin (close-input-port in) (close-output-port out)))

(let ()
  ;; Check unsupported protocol is not selected.
  (define-values (in out)
    (ssl-connect "localhost" PORT #:alpn '(#"unsupported" #"rkt-proto")))
  (check-equal? (ssl-get-alpn-selected in) #"rkt-proto")
  (check-equal? (ssl-get-alpn-selected out) #"rkt-proto")
  (begin (close-input-port in) (close-output-port out)))

;; Don't test case when client requests only unsupported protocols,
;; because there are buggy versions of OpenSSL that accept the
;; connection without setting a protocol. (Spec says connection
;; should fail.)

(custodian-shutdown-all server-cust)

;; ----------------------------------------

(define sctx (ssl-make-server-context))
(ssl-load-private-key! sctx server-key)
(ssl-load-certificate-chain! sctx server-crt)
(ssl-set-server-alpn! sctx '(#"rkt-proto" #"other") #t)
(define listener (ssl-listen 0 5 #f #f sctx))

(define-values (listener-addr listener-port ignore-addr ignore-port)
   (ssl-addresses listener #t))

(define server2-cust (make-custodian))
(define server2-chan (make-channel))
(define (server2)
  (define-values (in out) (ssl-accept listener))
  (channel-put server2-chan (ssl-get-alpn-selected in))
  (close-input-port in)
  (close-output-port out)
  (server2))
(parameterize ((current-custodian server2-cust))
  (void (thread server2)))
(sleep 0.2)

(let ()
  ;; Shared proto is selected.
  (define-values (in out)
    (ssl-connect "localhost" listener-port #:alpn '(#"unsupported" #"rkt-proto")))
  (check-equal? (ssl-get-alpn-selected in) #"rkt-proto")
  (check-equal? (channel-get server2-chan) #"rkt-proto"))

(let ()
  ;; Server selects shared proto according to its priorities.
  (define-values (in out)
    (ssl-connect "localhost" listener-port #:alpn '(#"other" #"rkt-proto")))
  (check-equal? (ssl-get-alpn-selected in) #"rkt-proto")
  (check-equal? (channel-get server2-chan) #"rkt-proto"))

(let ()
  ;; Client w/o ALPN can still connect.
  (define-values (in out) (ssl-connect "localhost" listener-port))
  (check-equal? (ssl-get-alpn-selected in) #f)
  (check-equal? (channel-get server2-chan) #f))

(let ()
  ;; Client w/ no shared ALPN protocols can still connect.  It's not
  ;; clear whether this is allowed by RFC 7301, but this behavior is
  ;; popular and seems beneficial. See discussions here:
  ;; - https://github.com/openssl/openssl/pull/2570
  ;; - https://bugs.chromium.org/p/chromium/issues/detail?id=497770
  ;; - https://github.com/postmanlabs/httpbin/issues/497
  (define-values (in out)
    (ssl-connect "localhost" listener-port #:alpn '(#"stuff" #"nonsense")))
  (check-equal? (ssl-get-alpn-selected in) #f)
  (check-equal? (channel-get server2-chan) #f))

(let ()
  ;; TLS 1.2 negotiates ALPN too.
  (define ctx (ssl-make-client-context 'tls12))
  (define-values (in out)
    (ssl-connect "localhost" listener-port ctx #:alpn '(#"other" #"rkt-proto")))
  (check-equal? (ssl-protocol-version in) 'tls12)
  (check-equal? (ssl-get-alpn-selected in) #"rkt-proto")
  (check-equal? (channel-get server2-chan) #"rkt-proto"))

(custodian-shutdown-all server2-cust)

;; ----------------------------------------
;; allow-no-match? = #f: a client that uses ALPN but shares no protocol is
;; rejected (no_application_protocol); a client without ALPN still connects.

(define sctx3 (ssl-make-server-context))
(ssl-load-private-key! sctx3 server-key)
(ssl-load-certificate-chain! sctx3 server-crt)
(ssl-set-server-alpn! sctx3 '(#"rkt-proto") #f)
(define listener3 (ssl-listen 0 5 #f #f sctx3))
(define-values (l3-addr l3-port l3-ignore-addr l3-ignore-port) (ssl-addresses listener3 #t))
(define server3-cust (make-custodian))
(define server3-chan (make-channel))
(define (server3)
  (channel-put server3-chan
               (with-handlers ([exn:fail? (lambda (e) (list 'exn (exn-message e)))])
                 (define-values (in out) (ssl-accept listener3))
                 (begin0 (ssl-get-alpn-selected in)
                   (close-input-port in)
                   (close-output-port out))))
  (server3))
(parameterize ((current-custodian server3-cust))
  (void (thread server3)))
(sleep 0.2)

(for ([protocol (in-list '(auto tls12))])
  (let ()
    (define ctx (ssl-make-client-context protocol))
    (check-exn #rx"no_application_protocol"
               (lambda () (ssl-connect "localhost" l3-port ctx #:alpn '(#"stuff"))))
    (check-regexp-match #rx"no application protocol" (cadr (channel-get server3-chan))))
  (let ()
    (define ctx (ssl-make-client-context protocol))
    (define-values (in out) (ssl-connect "localhost" l3-port ctx))
    (check-equal? (ssl-get-alpn-selected in) #f)
    (check-equal? (channel-get server3-chan) #f)
    (close-input-port in) (close-output-port out)))

(custodian-shutdown-all server3-cust)
