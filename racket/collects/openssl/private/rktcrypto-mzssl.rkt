#lang racket/base

;; The public `openssl` API (ssl-connect / ssl-listen / ports->ssl-ports and
;; friends) implemented on the in-tree rktcrypto TLS engine -- no libssl, no
;; dynamically loaded OpenSSL. This is the module `openssl/main` uses; it
;; keeps the exact export surface of the historical `openssl/mzssl` so that
;; net/http-client, net/git-checkout, net/url-connect and user code are
;; unaffected by the backend swap.

(require racket/contract/base
         racket/tcp
         racket/port
         racket/list
         (rename-in racket/contract/base [-> c->])
         "rktcrypto-tls13.rkt"
         "rktcrypto-x509.rkt"
         "rktcrypto-verify.rkt"
         "rktcrypto-ffi.rkt")

(define protocol-symbol/c
  (or/c 'secure 'auto 'sslv2-or-v3 'sslv2 'sslv3 'tls 'tls11 'tls12 'tls13))
(define (alpn-protocol-bytes/c v) (and (bytes? v) (< 0 (bytes-length v) 256)))
(define verify-source/c
  (or/c path-string?
        (list/c 'directory path-string?)
        (list/c 'win32-store string?)
        (list/c 'macosx-keychain path-string?)))

;; ---- context ----
(struct ssl-context (mutable) #:mutable)   ; base
(struct ssl-client-context ssl-context () )
(struct ssl-server-context ssl-context () )

;; The actual settings live in a hash carried by `mutable` so both context
;; kinds share one representation.
(define (new-context kind protocol)
  (define h (make-hasheq))
  (hash-set! h 'protocol protocol)
  (hash-set! h 'cert-ders '())
  (hash-set! h 'private-key #f)
  (hash-set! h 'verify? #f)
  (hash-set! h 'verify-hostname? #f)
  (hash-set! h 'trust-anchors '())
  (hash-set! h 'alpn '())
  (hash-set! h 'server-alpn '())
  (hash-set! h 'sni-callback #f)
  (hash-set! h 'sealed? #f)
  (hash-set! h 'keylogger #f)
  (case kind
    [(client) (ssl-client-context h)]
    [(server) (ssl-server-context h)]))

(define (cx-ref c k [d #f]) (hash-ref (ssl-context-mutable c) k d))
(define (cx-set! c k v)
  (when (hash-ref (ssl-context-mutable c) 'sealed? #f)
    (error 'ssl "context is sealed"))
  (hash-set! (ssl-context-mutable c) k v))

(define (ssl-make-client-context [protocol 'auto]
                                 #:private-key [pk #f] #:certificate-chain [cc #f])
  (define c (new-context 'client protocol))
  (when cc (ssl-load-certificate-chain! c cc))
  (when pk (load-private-key-spec c pk))
  c)

(define (ssl-make-server-context [protocol 'auto]
                                 #:private-key [pk #f] #:certificate-chain [cc #f])
  (define c (new-context 'server protocol))
  (when cc (ssl-load-certificate-chain! c cc))
  (when pk (load-private-key-spec c pk))
  c)

(define (ssl-secure-client-context)
  (define c (ssl-make-client-context 'secure))
  (cx-set! c 'verify? #t)
  (cx-set! c 'verify-hostname? #t)
  (ssl-load-default-verify-sources! c)
  (ssl-seal-context! c)
  c)

(define (ssl-seal-context! c) (hash-set! (ssl-context-mutable c) 'sealed? #t))

;; ---- loaders ----
(define (read-file-bytes p) (call-with-input-file p port->bytes))

(define (ssl-load-certificate-chain! c/l path)
  (define c (->context c/l))
  (cx-set! c 'cert-ders (pem->der-list (read-file-bytes path))))

(define (load-private-key-spec c spec)
  (cond
    [(and (list? spec) (eq? (car spec) 'pem)) (ssl-load-private-key! c (cadr spec))]
    [(and (list? spec) (eq? (car spec) 'pem-data)) (cx-set! c 'private-key (pem->private-key (cadr spec)))]
    [(and (list? spec) (eq? (car spec) 'der)) (ssl-load-private-key! c (cadr spec))]
    [else (void)]))

(define (ssl-load-private-key! c/l path-or-data [rsa? #t] [asn1? #f])
  (define c (->context c/l))
  (define bs (if (and (list? path-or-data) (eq? (car path-or-data) 'data))
                 (cadr path-or-data)
                 (read-file-bytes path-or-data)))
  (cx-set! c 'private-key (pem->private-key bs)))

(define (ssl-load-verify-root-certificates! c/l path)
  (define c (->context c/l))
  (cx-set! c 'trust-anchors
           (append (cx-ref c 'trust-anchors) (pem->der-list (read-file-bytes path)))))

(define (ssl-load-verify-source! c src #:try? [try? #f])
  (with-handlers ([exn:fail? (lambda (e) (unless try? (raise e)))])
    (cond
      [(path-string? src) (ssl-load-verify-root-certificates! c src)]
      [(and (pair? src) (eq? (car src) 'macosx-keychain)) (load-macosx-anchors c (cadr src))]
      [else (void)])))

(define ssl-default-verify-sources
  (make-parameter
   (case (system-type 'os*)
     [(macosx) (list '(macosx-keychain "/System/Library/Keychains/SystemRootCertificates.keychain"))]
     [else (filter (lambda (p) (and (path-string? p) (file-exists? p)))
                   '("/etc/ssl/certs/ca-certificates.crt"
                     "/etc/pki/tls/certs/ca-bundle.crt"
                     "/etc/ssl/cert.pem"))])))

(define (ssl-load-default-verify-sources! c)
  (for ([src (in-list (ssl-default-verify-sources))])
    (ssl-load-verify-source! c src #:try? #t)))

;; macOS: export the system roots as PEM via /usr/bin/security, then parse.
(define (load-macosx-anchors c keychain)
  (define-values (sp out in err)
    (subprocess #f #f #f "/usr/bin/security" "find-certificate" "-a" "-p" keychain))
  (close-output-port in)
  (define pem (port->bytes out))
  (close-input-port out) (close-input-port err)
  (subprocess-wait sp)
  (cx-set! c 'trust-anchors (append (cx-ref c 'trust-anchors) (pem->der-list pem))))

(define (ssl-load-suggested-certificate-authorities! c/l path) (void))

;; ---- verify / options ----
(define (ssl-set-verify! c/l on?) (cx-set! (->context c/l) 'verify? (and on? #t)))
(define (ssl-try-verify! c/l on?) (cx-set! (->context c/l) 'verify? (and on? #t)))
(define (ssl-set-verify-hostname! c on?) (cx-set! c 'verify-hostname? (and on? #t)))
(define (ssl-set-ciphers! c str) (void))            ; suite policy is fixed (AEAD-only)
(define (ssl-set-server-alpn! c protos [prefer-server? #t]) (cx-set! c 'server-alpn protos))
(define (ssl-set-server-name-identification-callback! c proc) (cx-set! c 'sni-callback proc))
(define (ssl-set-keylogger! c lg) (cx-set! c 'keylogger lg))
(define (ssl-server-context-enable-dhe! c [p 'auto]) (void))
(define (ssl-server-context-enable-ecdhe! c [n 'auto]) (void))

;; Turn a keylogger (a logger) into a line emitter for the engine, or #f.
;; Lines are the NSS Key Log format; a receiver on the logger (or an
;; SSLKEYLOGFILE bridge) can write them for Wireshark.
(define (keylog-emitter lg)
  (and lg (lambda (line) (log-message lg 'info 'ssl-keylog line #f))))

(define (->context c/l)
  (cond [(ssl-context? c/l) c/l]
        [(ssl-listener? c/l) (ssl-listener-ctx c/l)]
        [(ssl-port-obj? c/l) (ssl-port-obj-ctx c/l)]
        [else (error 'ssl "not a context/listener/port: ~e" c/l)]))

;; =====================================================================
;; SSL ports
;; =====================================================================
;; We wrap a `tls-conn` in a Racket input/output port pair. Reads/writes are
;; blocking, which is sufficient for the threaded client/server model that
;; ports->ssl-ports is used in.
(struct ssl-port-obj (conn ctx in-orig out-orig close-original? [in #:mutable] [out #:mutable]))

;; global registry: map a wrapped port -> ssl-port-obj (for ssl-port? etc.)
(define port->obj (make-weak-hasheq))
(define (register-port! p obj) (hash-set! port->obj p obj))
(define (ssl-port? p) (and (hash-ref port->obj p #f) #t))
(define (port-obj p) (hash-ref port->obj p #f))

(define (make-ssl-input conn name on-close)
  (define buf #"")
  (define (read-in bstr)
    (cond
      [(positive? (bytes-length buf))
       (define n (min (bytes-length bstr) (bytes-length buf)))
       (bytes-copy! bstr 0 buf 0 n)
       (set! buf (subbytes buf n))
       n]
      [else
       (define got (tls-conn-read-bytes conn (max 1 (bytes-length bstr))))
       (cond
         [(eof-object? got) eof]
         [else (set! buf got) (read-in bstr)])]))
  ;; Closing the input port must not send close_notify: TLS shutdown is a
  ;; write-direction action, and it belongs to the output port's close.
  (make-input-port name read-in #f on-close))

(define (make-ssl-output conn name on-close)
  (make-output-port name always-evt
                    (lambda (bstr start end non-block? breakable?)
                      (if (= start end) 0
                          (tls-conn-write-bytes conn (subbytes bstr start end))))
                    (lambda () (tls-conn-close-notify conn) (on-close))))

(define (ports->ssl-ports i o
                          #:mode [mode 'connect]
                          #:context [ctx #f]
                          #:encrypt [encrypt 'auto]
                          #:close-original? [close? #f]
                          #:shutdown-on-close? [shutdown? #f]
                          #:error/ssl [error/ssl error]
                          #:hostname [hostname #f]
                          #:alpn [alpn '()])
  (define context (or ctx (if (eq? mode 'connect)
                              (ssl-make-client-context encrypt)
                              (ssl-make-server-context encrypt))))
  (define conn
    (cond
      [(eq? mode 'connect)
       (define anchors (cx-ref context 'trust-anchors))
       ;; The `encrypt`/context protocol symbol pins the max version: 'tls12
       ;; forces TLS 1.2, everything else negotiates (prefers 1.3).
       (define proto (cx-ref context 'protocol))
       (tls13-connect i o
                      (hash 'host hostname
                            'alpn (if (pair? alpn) alpn (cx-ref context 'alpn))
                            'verify? (cx-ref context 'verify?)
                            'verify-hostname? (cx-ref context 'verify-hostname?)
                            'trust-anchors anchors
                            'keylog (keylog-emitter (cx-ref context 'keylogger))
                            'tls12-only? (memq proto '(tls12 tls11 tls))))]
      [else
       (define key (cx-ref context 'private-key))
       (unless key (error/ssl "ssl-accept: server context has no private key"))
       (define sni-cb (cx-ref context 'sni-callback))
       (define (sni-select name)
         (and sni-cb
              (let ([c2 (sni-cb name)])
                (and c2 (cx-ref c2 'private-key)
                     (cons (cx-ref c2 'cert-ders) (cx-ref c2 'private-key))))))
       (tls13-accept i o
                     (hash 'cert-ders (cx-ref context 'cert-ders)
                           'key key
                           'sni-select sni-select
                           'keylog (keylog-emitter (cx-ref context 'keylogger))
                           'alpn (let ([sa (cx-ref context 'server-alpn)])
                                   (if (pair? sa) sa alpn))))]))
  (define name (object-name i))
  ;; The two SSL ports share one transport: closing just the output port
  ;; must not FIN the underlying TCP stream while the input port is still
  ;; draining the response (servers treat an early client FIN as an abort),
  ;; so the original ports close only after BOTH SSL ports are closed.
  (define close-lock (make-semaphore 1))
  (define closed-sides 0)
  (define (one-side-closed!)
    (call-with-semaphore
     close-lock
     (lambda ()
       (set! closed-sides (add1 closed-sides))
       (when (and close? (= closed-sides 2))
         (close-input-port i)
         (close-output-port o)))))
  (define in (make-ssl-input conn name one-side-closed!))
  (define out (make-ssl-output conn name one-side-closed!))
  (define obj (ssl-port-obj conn context i o close? in out))
  (register-port! in obj) (register-port! out obj)
  (values in out))

;; ---- connect / listen / accept ----
(define (ssl-connect host port [ctx-or-proto 'auto] #:alpn [alpn '()])
  (do-ssl-connect host port ctx-or-proto alpn tcp-connect))
(define (ssl-connect/enable-break host port [ctx-or-proto 'auto] #:alpn [alpn '()])
  (do-ssl-connect host port ctx-or-proto alpn tcp-connect/enable-break))

(define (do-ssl-connect host port ctx-or-proto alpn connect)
  (define ctx (if (ssl-context? ctx-or-proto) ctx-or-proto (ssl-make-client-context ctx-or-proto)))
  (define-values (i o) (connect host port))
  (with-handlers ([(lambda (e) #t) (lambda (e) (close-input-port i) (close-output-port o) (raise e))])
    (ports->ssl-ports i o #:mode 'connect #:context ctx #:hostname host #:alpn alpn #:close-original? #t)))

(struct ssl-listener (tcp ctx)
  #:property prop:evt (lambda (l) (wrap-evt (ssl-listener-tcp l) (lambda (_) l))))

(define (ssl-listen port [backlog 4] [reuse? #f] [hostname #f] [ctx-or-proto 'auto])
  (define ctx (if (ssl-context? ctx-or-proto) ctx-or-proto (ssl-make-server-context ctx-or-proto)))
  (ssl-listener (tcp-listen port backlog reuse? hostname) ctx))

(define (ssl-close l) (tcp-close (ssl-listener-tcp l)))

(define (do-accept who accept l)
  (define-values (i o) (accept (ssl-listener-tcp l)))
  (with-handlers ([(lambda (e) #t) (lambda (e) (close-input-port i) (close-output-port o) (raise e))])
    (ports->ssl-ports i o #:mode 'accept #:context (ssl-listener-ctx l) #:close-original? #t)))
(define (ssl-accept l) (do-accept 'ssl-accept tcp-accept l))
(define (ssl-accept/enable-break l) (do-accept 'ssl-accept/enable-break tcp-accept/enable-break l))

(define (ssl-abandon-port p)
  (define obj (port-obj p))
  (when obj
    (cond [(input-port? p) (close-input-port p)]
          [else
           ;; Abandon means: stop writing without a TLS shutdown, so the
           ;; peer keeps sending and the read direction stays usable
           ;; (net/http-client abandons the request side before reading).
           (tls-conn-abandon-write! (ssl-port-obj-conn obj))
           (close-output-port p)])))

(define (ssl-addresses p [port-numbers? #f])
  (define obj (port-obj p))
  (cond
    [(ssl-listener? p) (tcp-addresses (ssl-listener-tcp p) port-numbers?)]
    [obj (tcp-addresses (ssl-port-obj-in-orig obj) port-numbers?)]
    [else (error 'ssl-addresses "not an ssl port/listener")]))

;; ---- peer / info accessors ----
(define (ssl-get-alpn-selected p)
  (define obj (port-obj p)) (and obj (tls-conn-alpn (ssl-port-obj-conn obj))))
(define (ssl-protocol-version p)
  (define obj (port-obj p)) (and obj (tls-conn-protocol (ssl-port-obj-conn obj))))
(define (peer-leaf p)
  (define obj (port-obj p))
  (define certs (and obj (tls-conn-peer-certs (ssl-port-obj-conn obj))))
  (and (pair? certs) (parse-certificate (car certs))))
(define (ssl-peer-verified? p)
  (define obj (port-obj p))
  (and obj (cx-ref (ssl-port-obj-ctx obj) 'verify?) (pair? (tls-conn-peer-certs (ssl-port-obj-conn obj)))))
(define (ssl-peer-certificate-hostnames p)
  (define leaf (peer-leaf p))
  (if leaf
      (let ([san (certificate-san-dns leaf)])
        (if (pair? san) san
            (let ([cn (assoc "2.5.4.3" (certificate-subject leaf))])
              (if cn (list (bytes->string/latin-1 (cdr cn))) '()))))
      '()))
(define (ssl-peer-check-hostname p host)
  (define leaf (peer-leaf p))
  (and leaf (with-handlers ([exn:fail? (lambda (_) #f)]) (check-hostname leaf host) #t)))
(define (ssl-peer-subject-name p)
  (define leaf (peer-leaf p))
  (and leaf (string->bytes/utf-8 (name->string (certificate-subject leaf)))))
(define (ssl-peer-issuer-name p)
  (define leaf (peer-leaf p))
  (and leaf (string->bytes/utf-8 (name->string (certificate-issuer leaf)))))

(define (ssl-channel-binding p kind)
  (define obj (port-obj p))
  (unless obj (error 'ssl-channel-binding "not an SSL port"))
  (tls-conn-channel-binding (ssl-port-obj-conn obj) kind))
(define (ssl-default-channel-binding p) (list 'tls-exporter (ssl-channel-binding p 'tls-exporter)))

;; ---- misc provides expected by consumers ----
(define ssl-available? #t)
(define ssl-load-fail-reason #f)
;; Protocol enumerations (functions, matching the historical API).
(define the-supported-protocols '(secure auto tls tls12 tls13))
(define (supported-client-protocols) the-supported-protocols)
(define (supported-server-protocols) the-supported-protocols)
(define (ssl-max-client-protocol) 'tls13)
(define (ssl-max-server-protocol) 'tls13)
(define ssl-dh4096-param-bytes #f)

(provide
 ssl-dh4096-param-bytes
 (rename-out [protocol-symbol/c ssl-protocol-symbol/c])
 ssl-max-client-protocol ssl-max-server-protocol
 supported-client-protocols supported-server-protocols
 (contract-out
  [ssl-available? boolean?]
  [ssl-load-fail-reason (or/c #f string?)]
  [ssl-make-client-context (->* () (protocol-symbol/c
                                     #:private-key (or/c (list/c 'pem path-string?) (list/c 'pem-data bytes?) (list/c 'der path-string?) #f)
                                     #:certificate-chain (or/c path-string? #f)) ssl-client-context?)]
  [ssl-secure-client-context (c-> ssl-client-context?)]
  [ssl-make-server-context (->* () (protocol-symbol/c
                                     #:private-key (or/c (list/c 'pem path-string?) (list/c 'pem-data bytes?) (list/c 'der path-string?) #f)
                                     #:certificate-chain (or/c path-string? #f)) ssl-server-context?)]
  [ssl-server-context-enable-dhe! (->* (ssl-server-context?) ((or/c 'auto path-string? bytes?)) void?)]
  [ssl-server-context-enable-ecdhe! (->* (ssl-server-context?) (symbol?) void?)]
  [ssl-client-context? (c-> any/c boolean?)]
  [ssl-server-context? (c-> any/c boolean?)]
  [ssl-context? (c-> any/c boolean?)]
  [ssl-load-certificate-chain! (c-> (or/c ssl-context? ssl-listener?) path-string? void?)]
  [ssl-load-private-key! (->* ((or/c ssl-context? ssl-listener?) (or/c path-string? (list/c 'data bytes?))) (any/c any/c) void?)]
  [ssl-load-verify-root-certificates! (c-> (or/c ssl-context? ssl-listener? ssl-port?) path-string? void?)]
  [ssl-load-verify-source! (->* (ssl-context? verify-source/c) (#:try? any/c) void?)]
  [ssl-load-suggested-certificate-authorities! (c-> (or/c ssl-context? ssl-listener?) path-string? void?)]
  [ssl-set-ciphers! (c-> ssl-context? string? void?)]
  [ssl-set-server-name-identification-callback! (c-> ssl-server-context? (c-> string? (or/c ssl-server-context? #f)) void?)]
  [ssl-set-server-alpn! (->* [ssl-server-context? (listof alpn-protocol-bytes/c)] [boolean?] void?)]
  [ssl-seal-context! (c-> ssl-context? void?)]
  [ssl-default-verify-sources (parameter/c (listof verify-source/c))]
  [ssl-load-default-verify-sources! (c-> ssl-context? void?)]
  [ssl-set-verify! (c-> (or/c ssl-context? ssl-listener? ssl-port?) any/c void?)]
  [ssl-try-verify! (c-> (or/c ssl-context? ssl-listener? ssl-port?) any/c void?)]
  [ssl-set-verify-hostname! (c-> ssl-context? any/c void?)]
  [ssl-set-keylogger! (c-> ssl-context? (or/c #f logger?) void?)]
  [ssl-peer-verified? (c-> ssl-port? boolean?)]
  [ssl-peer-certificate-hostnames (c-> ssl-port? (listof string?))]
  [ssl-peer-check-hostname (c-> ssl-port? string? boolean?)]
  [ssl-peer-subject-name (c-> ssl-port? (or/c bytes? #f))]
  [ssl-peer-issuer-name (c-> ssl-port? (or/c bytes? #f))]
  [ssl-channel-binding (c-> ssl-port? (or/c 'tls-exporter 'tls-unique 'tls-server-end-point) bytes?)]
  [ssl-default-channel-binding (c-> ssl-port? (list/c symbol? bytes?))]
  [ssl-protocol-version (c-> ssl-port? (or/c symbol? #f))]
  [ssl-get-alpn-selected (c-> ssl-port? (or/c bytes? #f))]
  [ports->ssl-ports (->* [input-port? output-port?]
                         [#:mode (or/c 'connect 'accept)
                          #:context ssl-context?
                          #:encrypt protocol-symbol/c
                          #:close-original? any/c
                          #:shutdown-on-close? any/c
                          #:error/ssl procedure?
                          #:hostname (or/c string? #f)
                          #:alpn (listof alpn-protocol-bytes/c)]
                         (values input-port? output-port?))]
  [ssl-listen (->* [listen-port-number?] [exact-nonnegative-integer? any/c (or/c string? #f)
                    (or/c ssl-server-context? protocol-symbol/c)] ssl-listener?)]
  [ssl-close (c-> ssl-listener? void?)]
  [ssl-accept (c-> ssl-listener? (values input-port? output-port?))]
  [ssl-accept/enable-break (c-> ssl-listener? (values input-port? output-port?))]
  [ssl-connect (->* [string? (integer-in 1 (sub1 (expt 2 16)))]
                    [(or/c ssl-client-context? protocol-symbol/c) #:alpn (listof alpn-protocol-bytes/c)]
                    (values input-port? output-port?))]
  [ssl-connect/enable-break (->* [string? (integer-in 1 (sub1 (expt 2 16)))]
                                 [(or/c ssl-client-context? protocol-symbol/c) #:alpn (listof alpn-protocol-bytes/c)]
                                 (values input-port? output-port?))]
  [ssl-listener? (c-> any/c boolean?)]
  [ssl-addresses (->* [(or/c ssl-listener? ssl-port?)] [any/c] any)]
  [ssl-abandon-port (c-> ssl-port? void?)]
  [ssl-port? (c-> any/c boolean?)]))
