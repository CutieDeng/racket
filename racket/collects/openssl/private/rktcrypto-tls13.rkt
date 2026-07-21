#lang racket/base

;; TLS 1.3 (RFC 8446) handshake state machine and record layer, driven over
;; a pair of blocking Racket ports (the underlying TCP input/output). All
;; cryptography -- key schedule, AEAD record protection, ECDHE, signature
;; verification -- runs in the in-tree rktcrypto C library via
;; rktcrypto-ffi. This module implements the message encode/decode and the
;; control flow: everything that is I/O-bound rather than a crypto hot loop.
;;
;; Provides `tls13-connect` (client) and `tls13-accept` (server), each
;; returning a `tls-conn` with `tls-conn-read`/`tls-conn-write`/close over
;; application data.

(require "rktcrypto-ffi.rkt"
         "rktcrypto-x509.rkt"
         "rktcrypto-verify.rkt"
         racket/port
         racket/lazy-require)

;; TLS 1.2 lives in a sibling module that requires this one; break the cycle
;; with a lazy require so the 1.2 continuation loads on first use.
(lazy-require
 ["rktcrypto-tls12.rkt" (tls12-client-finish tls12-accept tls12-suites)])

(provide tls13-connect
         tls13-accept
         (struct-out tls-conn)
         tls-conn-read-bytes
         tls-conn-write-bytes
         tls-conn-close-notify
         tls-conn-abandon-write!
         tls-conn-channel-binding)

;; ---- byte building ----
(define (u8 n) (bytes n))
(define (u16 n) (bytes (arithmetic-shift n -8) (bitwise-and n 255)))
(define (u24 n) (bytes (bitwise-and (arithmetic-shift n -16) 255)
                       (bitwise-and (arithmetic-shift n -8) 255)
                       (bitwise-and n 255)))
(define (vec len-bytes bs)
  (bytes-append (case len-bytes [(1) (u8 (bytes-length bs))]
                                [(2) (u16 (bytes-length bs))]
                                [(3) (u24 (bytes-length bs))])
                bs))
(define (be->int bs [start 0] [end (bytes-length bs)])
  (let loop ([i start] [acc 0]) (if (= i end) acc (loop (add1 i) (+ (* acc 256) (bytes-ref bs i))))))

;; ---- cipher suites ----
;; id -> (values hash-alg aead key-len iv-len digest-name)
(define (suite-params id)
  (case id
    [(#x1301) (values SHA256 AEAD-AES128-GCM 16 12 'sha256)]        ; TLS_AES_128_GCM_SHA256
    [(#x1302) (values SHA384 AEAD-AES256-GCM 32 12 'sha384)]        ; TLS_AES_256_GCM_SHA384
    [(#x1303) (values SHA256 AEAD-CHACHA20-POLY1305 32 12 'sha256)] ; TLS_CHACHA20_POLY1305_SHA256
    [else (values #f #f #f #f #f)]))
(define client-suites (list #x1301 #x1302 #x1303))
(define (suite-supported? id) (and (memv id client-suites) #t))

;; ---- named groups ----
(define GROUP-X25519 #x001d)
(define GROUP-P256   #x0017)
(define GROUP-P384   #x0018)

;; ---- signature scheme ids (for signature_algorithms) ----
(define sig-schemes
  (list #x0403   ; ecdsa_secp256r1_sha256
        #x0503   ; ecdsa_secp384r1_sha384
        #x0804   ; rsa_pss_rsae_sha256
        #x0805   ; rsa_pss_rsae_sha384
        #x0806   ; rsa_pss_rsae_sha512
        #x0401   ; rsa_pkcs1_sha256
        #x0501   ; rsa_pkcs1_sha384
        #x0601   ; rsa_pkcs1_sha512
        #x0807)) ; ed25519

;; =====================================================================
;; Record layer
;; =====================================================================
(struct rl (in out
            [raead #:mutable] [rkey #:mutable] [riv #:mutable] [rseq #:mutable]
            [waead #:mutable] [wkey #:mutable] [wiv #:mutable] [wseq #:mutable]))

(define (make-rl in out)
  (rl in out #f #f #f 0 #f #f #f 0))

;; report raw transport I/O errors as TLS (network) errors, so that
;; callers' network-retry logic applies to them as it did with the
;; OpenSSL-based `mzssl`
(define-syntax-rule (with-transport-errors body ...)
  (with-handlers ([(lambda (e) (and (exn:fail? e) (not (exn:fail:network? e))))
                   (lambda (e) (raise (tls-error (exn-message e))))])
    body ...))

(define (read-n in n)
  (define bs (with-transport-errors (read-bytes n in)))
  (when (or (eof-object? bs) (< (bytes-length bs) n))
    (raise (tls-error "unexpected EOF from peer")))
  bs)

;; Reads one record; returns (values content-type payload-bytes). Decrypts
;; when a read key is installed (skipping the outer app_data type and the
;; inner content-type/padding).
(define (rl-read-record r)
  (define hdr (read-n (rl-in r) 5))
  (define len (be->int hdr 3 5))
  (when (> len 18432) (raise (tls-error "record too large")))
  (define body (read-n (rl-in r) len))
  (cond
    ;; Only application_data (23) records are AEAD-protected in TLS 1.3.
    ;; ChangeCipherSpec (20) and any plaintext alert (21) pass through even
    ;; after keys are installed (middlebox-compat CCS is sent unencrypted).
    [(and (rl-rkey r) (= (bytes-ref hdr 0) 23))
     (define rec (bytes-append hdr body))
     (define inner (tls13-open (rl-raead r) (rl-rkey r) (rl-riv r) (rl-rseq r) rec))
     (unless inner (raise (tls-alert 20 "bad_record_mac")))
     (set-rl-rseq! r (add1 (rl-rseq r)))
     ;; strip trailing zero padding, then the content-type byte
     (let loop ([i (sub1 (bytes-length inner))])
       (cond [(< i 0) (raise (tls-error "empty inner plaintext"))]
             [(zero? (bytes-ref inner i)) (loop (sub1 i))]
             [else (values (bytes-ref inner i) (subbytes inner 0 i))]))]
    [else (values (bytes-ref hdr 0) body)]))

;; Writes a record of `type` with `payload`, encrypting when a write key is
;; installed. Splits >16KiB payloads.
(define (rl-write-record r type payload)
  (with-transport-errors
    (cond
      [(rl-wkey r)
       (define inner (bytes-append payload (u8 type)))
       (define rec (tls13-seal (rl-waead r) (rl-wkey r) (rl-wiv r) (rl-wseq r) inner))
       (set-rl-wseq! r (add1 (rl-wseq r)))
       (write-bytes rec (rl-out r))]
      [else
       (write-bytes (bytes-append (u8 type) (u16 #x0303) (u16 (bytes-length payload)) payload)
                    (rl-out r))])
    (flush-output (rl-out r))))

(define (rl-set-read-key! r aead key iv) (set-rl-raead! r aead) (set-rl-rkey! r key) (set-rl-riv! r iv) (set-rl-rseq! r 0))
(define (rl-set-write-key! r aead key iv) (set-rl-waead! r aead) (set-rl-wkey! r key) (set-rl-wiv! r iv) (set-rl-wseq! r 0))

;; ---- key logging (SSLKEYLOGFILE) ----
;; A procedure (line-string -> void) installed for the current handshake;
;; secret-derivation points emit NSS Key Log lines through it.
(define keylog-proc (make-parameter #f))
(define keylog-cr (make-parameter #""))   ; client_random for the current handshake
(define (hex bs) (apply string-append (for/list ([b (in-bytes bs)])
                                        (let ([s (number->string b 16)]) (if (= 1 (string-length s)) (string-append "0" s) s)))))
(define (klog! label client-random secret)
  (define f (keylog-proc))
  (when f (f (string-append label " " (hex client-random) " " (hex secret)))))

;; ---- errors ----
;; a subtype of `exn:fail:network` so that network-level retry logic
;; (e.g., `raco pkg`'s `call-with-network-retries`) treats TLS
;; failures as retryable, matching the OpenSSL-based `mzssl`
(struct exn:tls exn:fail:network (alert) #:transparent)
(define (tls-error msg) (exn:tls msg (current-continuation-marks) #f))
(define (tls-alert code msg) (exn:tls (format "TLS alert: ~a (~a)" msg code) (current-continuation-marks) code))
(provide (struct-out exn:tls) with-transport-errors)

;; =====================================================================
;; Handshake message reader (reassembles across records)
;; =====================================================================
;; Buffers handshake bytes; hands back complete messages. Also transparently
;; skips ChangeCipherSpec records and surfaces alerts.
(struct hsr (rl [buf #:mutable] [app #:mutable]))
(define (make-hsr r) (hsr r #"" #""))

(define (hsr-fill r)
  (let loop ()
    (define-values (type payload) (rl-read-record (hsr-rl r)))
    (cond
      [(= type 20) (loop)]                       ; change_cipher_spec: ignore
      [(= type 21)
       (if (and (>= (bytes-length payload) 2) (= 1 (bytes-ref payload 0)))
           (loop)                                ; warning alert (e.g. close_notify handled elsewhere)
           (raise (tls-alert (if (>= (bytes-length payload) 2) (bytes-ref payload 1) 0) "fatal")))]
      [(= type 22) (set-hsr-buf! r (bytes-append (hsr-buf r) payload))]
      [(= type 23) (set-hsr-app! r (bytes-append (hsr-app r) payload))
                   (loop)]                       ; stray early app data: stash
      [else (raise (tls-error (format "unexpected record type ~a" type)))])))

;; Returns (values msg-type full-message-bytes) where full-message includes
;; the 4-byte handshake header (needed verbatim for the transcript).
(define (hsr-next r)
  (let loop ()
    (define buf (hsr-buf r))
    (cond
      [(< (bytes-length buf) 4) (hsr-fill r) (loop)]
      [else
       (define mlen (be->int buf 1 4))
       (cond
         [(< (bytes-length buf) (+ 4 mlen)) (hsr-fill r) (loop)]
         [else
          (define msg (subbytes buf 0 (+ 4 mlen)))
          (set-hsr-buf! r (subbytes buf (+ 4 mlen)))
          (values (bytes-ref msg 0) msg)])])))

;; =====================================================================
;; Transcript hash
;; =====================================================================
(struct transcript ([alg #:mutable] [data #:mutable]))
(define (make-transcript alg) (transcript alg #""))
(define (tr-add! t msg) (set-transcript-data! t (bytes-append (transcript-data t) msg)))
(define (tr-hash t) (digest (transcript-alg t) (transcript-data t)))
;; Re-hash under a possibly-different digest (HRR / suite selection).
(define (tr-set-alg! t alg) (set-transcript-alg! t alg))

;; =====================================================================
;; Extensions
;; =====================================================================
;; Build an extension: type(2) + vec2(body)
(define (ext type body) (bytes-append (u16 type) (vec 2 body)))

;; Parse an extensions block (bytes) into a list of (type . body-bytes).
(define (parse-extensions bs)
  (let loop ([pos 0] [acc '()])
    (if (>= pos (bytes-length bs))
        (reverse acc)
        (let* ([type (be->int bs pos (+ pos 2))]
               [len (be->int bs (+ pos 2) (+ pos 4))]
               [body (subbytes bs (+ pos 4) (+ pos 4 len))])
          (loop (+ pos 4 len) (cons (cons type body) acc))))))

;; =====================================================================
;; Key schedule helpers
;; =====================================================================
(struct ks (alg aead key-len iv-len
            [hs-secret #:mutable]
            [c-hs #:mutable] [s-hs #:mutable]
            [master #:mutable]
            [c-ap #:mutable] [s-ap #:mutable]))

(define empty-hash-cache (make-hash))
(define (empty-hash alg)
  (hash-ref! empty-hash-cache alg (lambda () (digest alg #""))))

;; handshake secret from ECDHE shared secret
(define (ks-derive-handshake! k ecdhe)
  (define alg (ks-alg k))
  (define early (tls13-extract alg #f #f))
  (define derived (derive-secret alg early #"derived" (empty-hash alg)))
  (define hs (tls13-extract alg derived ecdhe))
  (set-ks-hs-secret! k hs))

(define (ks-hs-traffic! k th)
  (define alg (ks-alg k))
  (define hs (ks-hs-secret k))
  (set-ks-c-hs! k (derive-secret alg hs #"c hs traffic" th))
  (set-ks-s-hs! k (derive-secret alg hs #"s hs traffic" th)))

(define (ks-master! k)
  (define alg (ks-alg k))
  (define derived2 (derive-secret alg (ks-hs-secret k) #"derived" (empty-hash alg)))
  (set-ks-master! k (tls13-extract alg derived2 #f)))

(define (ks-ap-traffic! k th)
  (define alg (ks-alg k))
  (set-ks-c-ap! k (derive-secret alg (ks-master k) #"c ap traffic" th))
  (set-ks-s-ap! k (derive-secret alg (ks-master k) #"s ap traffic" th)))

(define (traffic->keys k secret)
  (traffic-keys (ks-alg k) secret (ks-key-len k) (ks-iv-len k)))

;; =====================================================================
;; The connection object exposed to callers
;; =====================================================================
;; Transport-agnostic so both the TLS 1.3 record layer (here) and the TLS
;; 1.2 record layer (rktcrypto-tls12.rkt) plug into the same interface.
;;   recv : (-> (or/c bytes eof))     one application-data chunk
;;   send : (-> bytes void)           protect+write application data
;;   shut : (-> void)                 write close_notify
;; closed  : read direction reached EOF (peer close_notify or transport EOF)
;; wclosed : write direction closed (we sent close_notify, or the write side
;;           was abandoned); the read direction stays usable (TLS half-close)
(struct tls-conn (recv send shut
                  rbuf closed wclosed
                  alpn peer-certs protocol
                  binding) #:mutable)   ; binding: hash for channel binding, or #f

;; Build the 1.3 tls-conn from an installed record layer.
(define (tls13-make-conn r alpn peer-certs [binding #f])
  (define (recv)
    (let loop ()
      (with-handlers ([(lambda (e) (and (exn:tls? e) (not (exn:tls-alert e)))) (lambda (_) eof)])
        (define-values (type payload) (rl-read-record r))
        (cond
          [(and (= type 23) (positive? (bytes-length payload))) payload]
          [(= type 23) (loop)]
          [(= type 21) eof]                                  ; close_notify
          [(= type 22) (loop)]                               ; NewSessionTicket / KeyUpdate
          [else (loop)]))))
  (define (send bs)
    (let loop ([off 0])
      (when (< off (bytes-length bs))
        (define chunk (min 16384 (- (bytes-length bs) off)))
        (rl-write-record r 23 (subbytes bs off (+ off chunk)))
        (loop (+ off chunk)))))
  (define (shut) (with-handlers ([exn:fail? void]) (rl-write-record r 21 (bytes 1 0))))
  (tls-conn recv send shut #"" #f #f alpn peer-certs 'tls1.3 binding))

;; Reads up to `n` application bytes; returns bytes or eof.
(define (tls-conn-read-bytes c n)
  (cond
    [(and (tls-conn-closed c) (zero? (bytes-length (tls-conn-rbuf c)))) eof]
    [(positive? (bytes-length (tls-conn-rbuf c)))
     (define buf (tls-conn-rbuf c))
     (define take (min n (bytes-length buf)))
     (set-tls-conn-rbuf! c (subbytes buf take))
     (subbytes buf 0 take)]
    [else
     (define got ((tls-conn-recv c)))
     (cond
       [(eof-object? got) (set-tls-conn-closed! c #t) eof]
       [else (set-tls-conn-rbuf! c got) (tls-conn-read-bytes c n)])]))

(define (tls-conn-write-bytes c bs)
  (when (tls-conn-wclosed c)
    (raise (tls-error "write after the TLS write direction was closed")))
  ((tls-conn-send c) bs)
  (bytes-length bs))

;; close_notify only closes the write direction (RFC 8446 6.1); reads keep
;; draining until the peer's close_notify or transport EOF sets `closed`.
(define (tls-conn-close-notify c)
  (unless (tls-conn-wclosed c)
    (set-tls-conn-wclosed! c #t)
    ((tls-conn-shut c))))

;; Close the write direction without sending close_notify, for
;; ssl-abandon-port: the peer sees no shutdown and keeps sending.
(define (tls-conn-abandon-write! c)
  (set-tls-conn-wclosed! c #t))

;; Channel binding (RFC 9266 tls-exporter, plus tls-server-end-point).
;; Returns bytes, or raises if unavailable for this connection/kind.
(define (tls-conn-channel-binding c kind)
  (define b (tls-conn-binding c))
  (case kind
    [(tls-exporter)
     (unless (and b (hash-ref b 'exporter-master #f))
       (raise (tls-error "tls-exporter channel binding unavailable")))
     (tls13-exporter (hash-ref b 'alg) (hash-ref b 'exporter-master)
                     #"EXPORTER-Channel-Binding" #"" 32)]
    [(tls-server-end-point)
     ;; RFC 5929: both sides hash the *server's* certificate, so the
     ;; server must use its own certificate, not the peer's
     (define der (or (and b (hash-ref b 'server-cert-der #f))
                     (let ([certs (tls-conn-peer-certs c)])
                       (and (pair? certs) (car certs)))))
     (unless der (raise (tls-error "no server certificate for tls-server-end-point")))
     ;; hash of the DER leaf (SHA-256; sufficient for RFC 5929 in practice)
     (digest SHA256 der)]
    [else (raise (tls-error (format "unsupported channel binding ~a" kind)))]))
;; Generic tls-conn constructor used by the TLS 1.2 engine.
(define (make-tls-conn recv send shut peer-ders protocol [binding #f])
  (tls-conn recv send shut #"" #f #f #f peer-ders protocol binding))

;; TLS 1.3 exporter (RFC 8446 sec 7.5) for channel binding (RFC 9266).
;;   exporter_secret = Derive-Secret(exporter_master, label, "")
;;   output = HKDF-Expand-Label(exporter_secret, "exporter", Hash(context), len)
(define (tls13-exporter alg exporter-master label context len)
  (define hl (digest-size alg))
  (define es (derive-secret alg exporter-master label (digest alg #"")))
  (expand-label alg es #"exporter" (digest alg context) len))
(provide tls13-exporter)

(provide tls13-make-conn make-tls-conn
         (struct-out rl) make-rl rl-read-record rl-write-record
         rl-set-read-key! rl-set-write-key!
         make-hsr hsr-next hsr-app
         (struct-out transcript) make-transcript tr-add! tr-hash tr-set-alg!
         u8 u16 u24 vec be->int ext parse-extensions
         tls-error tls-alert exn:tls-alert
         digest hmac random-bytes ct-equal?)

;; =====================================================================
;; Client handshake
;; =====================================================================
;; opts: hash with keys 'host 'alpn (list of bytes) 'verify? 'trust-anchors
;;       'groups (subset for HRR testing)
(define (tls13-connect in out opts)
  (define host (hash-ref opts 'host #f))
  (define alpn (hash-ref opts 'alpn '()))
  (define verify? (hash-ref opts 'verify? #t))
  (define anchors (hash-ref opts 'trust-anchors '()))
  (define groups (hash-ref opts 'groups (list GROUP-X25519 GROUP-P256)))
  (define r (make-rl in out))
  (define hs (make-hsr r))
  (define tr (make-transcript SHA256))   ; provisional; may switch to SHA384

  ;; generate key shares for offered groups (default: x25519 only in first flight)
  (define share-groups (list (car groups)))
  (define privs (make-hash))    ; group -> private key bytes
  (define (gen-share group)
    (case group
      [(#x001d) (let* ([priv (random-bytes 32)]
                       [pub (make-bytes 32)])
                  (rktcrypto_x25519 pub priv (bytes-append (bytes 9) (make-bytes 31 0)))
                  (hash-set! privs group priv)
                  (bytes-append (u16 group) (vec 2 pub)))]
      [(#x0017) (let* ([priv (p256-priv)]
                       [pub (make-bytes 65)])
                  (rktcrypto_p256_pubkey pub priv)
                  (hash-set! privs group priv)
                  (bytes-append (u16 group) (vec 2 pub)))]
      [(#x0018) (let* ([priv (random-bytes 48)]
                       [pub (make-bytes 97)])
                  (rktcrypto_p384_pubkey pub priv)
                  (hash-set! privs group priv)
                  (bytes-append (u16 group) (vec 2 pub)))]))

  (define session-id (random-bytes 32))

  (define only-12? (hash-ref opts 'tls12-only? #f))
  (define offer-12? (or only-12? (hash-ref opts 'offer-12? #t)))
  (define client-random (random-bytes 32))
  (define all-suites (cond [only-12? (tls12-suites)]
                           [offer-12? (append client-suites (tls12-suites))]
                           [else client-suites]))
  (define (build-client-hello key-share-entries [cookie #f])
    (define exts
      (bytes-append
       (ext #x002b (vec 1 (cond [only-12? (u16 #x0303)]
                                [offer-12? (bytes-append (u16 #x0304) (u16 #x0303))]
                                [else (u16 #x0304)]))) ; supported_versions
       (ext #x000a (vec 2 (apply bytes-append (map u16 groups))))  ; supported_groups
       (ext #x000b (vec 1 (bytes 0)))                          ; ec_point_formats: uncompressed
       (ext #x000d (vec 2 (apply bytes-append (map u16 sig-schemes)))) ; signature_algorithms
       (ext #x0033 (vec 2 (apply bytes-append key-share-entries)))    ; key_share
       (ext #x0017 #"")                                        ; extended_master_secret
       (ext #xff01 (vec 1 #""))                                ; renegotiation_info (empty)
       (if cookie (ext #x002c (vec 2 cookie)) #"")
       (if host (ext #x0000 (vec 2 (bytes-append (u8 0) (vec 2 (string->bytes/latin-1 host))))) #"")  ; SNI
       (if (pair? alpn)
           (ext #x0010 (vec 2 (apply bytes-append (map (lambda (p) (vec 1 p)) alpn))))
           #"")))
    (define body
      (bytes-append (u16 #x0303) client-random
                    (vec 1 session-id)
                    (vec 2 (apply bytes-append (map u16 all-suites)))
                    (vec 1 (bytes 0))               ; compression: null
                    (vec 2 exts)))
    (bytes-append (u8 1) (u24 (bytes-length body)) body))

  (define ch1 (build-client-hello (map gen-share share-groups)))
  (parameterize ([keylog-proc (hash-ref opts 'keylog #f)] [keylog-cr client-random])
  (tr-add! tr ch1)
  (rl-write-record r 22 ch1)

  ;; read ServerHello (or HelloRetryRequest)
  (define-values (sh-type sh) (hsr-next hs))
  (unless (= sh-type 2) (raise (tls-error "expected ServerHello")))

  ;; HelloRetryRequest sentinel random
  (define HRR-RANDOM #"\xcf\x21\xad\x74\xe5\x9a\x61\x11\xbe\x1d\x8c\x02\x1e\x65\xb8\x91\xc2\xa2\x11\x16\x7a\xbb\x8c\x5e\x07\x9e\x09\xe2\xc8\xa8\x33\x9c")
  (define sh-random (subbytes sh 6 38))

  (define (parse-server-hello sh)
    (define sid-len (bytes-ref sh 38))
    (define pos (+ 39 sid-len))
    (define suite (be->int sh pos (+ pos 2)))
    (set! pos (+ pos 3))                          ; suite + compression
    (define ext-len (be->int sh pos (+ pos 2)))
    (define exts (parse-extensions (subbytes sh (+ pos 2) (+ pos 2 ext-len))))
    (values suite exts))

  (cond
    [(equal? sh-random HRR-RANDOM)
     ;; server told us which group to use
     (define-values (suite exts) (parse-server-hello sh))
     (define ks-ext (assoc #x0033 exts))
     (define cookie (let ([c (assoc #x002c exts)]) (and c (subbytes (cdr c) 2))))
     (define want-group (be->int (cdr ks-ext) 0 2))
     ;; switch transcript to synthetic-message form: replace CH with hash-of-CH msg
     (define-values (h aead klen ilen dname) (suite-params suite))
     (tr-set-alg! tr h)
     (define ch-hash (digest h ch1))
     (set-transcript-data! tr (bytes-append (u8 254) (u24 (digest-size h)) ch-hash))  ; message_hash
     (tr-add! tr sh)
     (define ch2 (build-client-hello (list (gen-share want-group)) cookie))
     (tr-add! tr ch2)
     (rl-write-record r 22 ch2)
     (define-values (sh2-type sh2) (hsr-next hs))
     (unless (= sh2-type 2) (raise (tls-error "expected ServerHello after HRR")))
     (finish-client-handshake r hs tr sh2 want-group privs verify? host anchors alpn)]
    [else
     (define-values (suite exts) (parse-server-hello sh))
     (define sv-ext (assoc #x002b exts))
     (define chose-13? (and sv-ext (>= (bytes-length (cdr sv-ext)) 2)
                            (= #x0304 (be->int (cdr sv-ext) 0 2))))
     (cond
       [chose-13?
        (tr-add! tr sh)
        (define ks-ext (assoc #x0033 exts))
        (define grp (be->int (cdr ks-ext) 0 2))
        (finish-client-handshake-with-suite r hs tr sh suite exts grp privs verify? host anchors alpn)]
       [else
        ;; Server negotiated TLS 1.2. Hand off to the 1.2 continuation with
        ;; the raw transcript (ClientHello || ServerHello) so far.
        (tls12-client-finish (rl-in r) (rl-out r) hs (bytes-append ch1 sh) sh client-random
                             (hash 'host host 'verify? verify? 'trust-anchors anchors))])])))

;; After a (possibly retried) ServerHello whose suite/exts we've parsed.
(define (finish-client-handshake r hs tr sh want-group privs verify? host anchors alpn)
  (define-values (suite exts) (let ()
    (define sid-len (bytes-ref sh 38))
    (define pos (+ 39 sid-len))
    (values (be->int sh pos (+ pos 2))
            (parse-extensions (let ([el (be->int sh (+ pos 3) (+ pos 5))]) (subbytes sh (+ pos 5) (+ pos 5 el)))))))
  (tr-add! tr sh)   ; SH2 after HelloRetryRequest joins the transcript
  (finish-client-handshake-with-suite r hs tr sh suite exts want-group privs verify? host anchors alpn))

(define (finish-client-handshake-with-suite r hs tr sh suite exts grp privs verify? host anchors alpn)
  (define-values (alg aead klen ilen dname) (suite-params suite))
  (unless alg (raise (tls-error "server chose unsupported cipher suite")))
  (tr-set-alg! tr alg)
  ;; server key_share
  (define ks-ext (assoc #x0033 exts))
  (define peer-pub (subbytes (cdr ks-ext) 4))
  (define ecdhe (compute-ecdhe grp (hash-ref privs grp) peer-pub))
  (define k (ks alg aead klen ilen #f #f #f #f #f #f))
  (ks-derive-handshake! k ecdhe)
  (define th-chsh (tr-hash tr))
  (ks-hs-traffic! k th-chsh)
  (klog! "CLIENT_HANDSHAKE_TRAFFIC_SECRET" (keylog-cr) (ks-c-hs k))
  (klog! "SERVER_HANDSHAKE_TRAFFIC_SECRET" (keylog-cr) (ks-s-hs k))
  ;; install handshake keys
  (define-values (skey siv) (traffic->keys k (ks-s-hs k)))
  (define-values (ckey civ) (traffic->keys k (ks-c-hs k)))
  (rl-set-read-key! r aead skey siv)
  ;; read EncryptedExtensions, Certificate, CertificateVerify, Finished
  (define selected-alpn (box #f))
  (define peer-certs (box '()))
  (let loop ()
    (define-values (mt msg) (hsr-next hs))
    (case mt
      [(8)   ; EncryptedExtensions
       (define ee-exts (parse-extensions (subbytes msg 6 (+ 6 (be->int msg 4 6)))))
       (define ap (assoc #x0010 ee-exts))
       (when ap (set-box! selected-alpn (let ([b (cdr ap)]) (subbytes b 3 (+ 3 (bytes-ref b 2))))))
       (tr-add! tr msg) (loop)]
      [(11)  ; Certificate
       (set-box! peer-certs (parse-certificate-msg msg))
       (tr-add! tr msg) (loop)]
      [(15)  ; CertificateVerify
       (define th (tr-hash tr))
       (verify-certificate-verify msg (unbox peer-certs) th)
       (tr-add! tr msg) (loop)]
      [(20)  ; Finished (server)
       (define expected (finished-verify-data alg (ks-s-hs k) (tr-hash tr)))
       (define got (subbytes msg 4))
       (unless (ct-equal? expected got) (raise (tls-alert 51 "server Finished mismatch")))
       (tr-add! tr msg)]
      [else (raise (tls-error (format "unexpected handshake msg ~a" mt)))]))
  ;; verify certificate chain + hostname if requested
  (when verify?
    (verify-chain-and-host (unbox peer-certs) host anchors))
  ;; compute application secrets (transcript up to server Finished)
  (ks-master! k)
  (define th-sfin (tr-hash tr))
  (ks-ap-traffic! k th-sfin)
  (define exporter-master (derive-secret alg (ks-master k) #"exp master" th-sfin))
  (klog! "CLIENT_TRAFFIC_SECRET_0" (keylog-cr) (ks-c-ap k))
  (klog! "SERVER_TRAFFIC_SECRET_0" (keylog-cr) (ks-s-ap k))
  (klog! "EXPORTER_SECRET" (keylog-cr) exporter-master)
  ;; send client Finished under handshake write keys
  (rl-set-write-key! r aead ckey civ)
  ;; middlebox-compat CCS (plaintext) is optional; skip.
  (define cfin (finished-verify-data alg (ks-c-hs k) (tr-hash tr)))
  (define fin-msg (bytes-append (u8 20) (u24 (bytes-length cfin)) cfin))
  (rl-write-record r 22 fin-msg)
  ;; install application keys both directions
  (define-values (sapk sapiv) (traffic->keys k (ks-s-ap k)))
  (define-values (capk capiv) (traffic->keys k (ks-c-ap k)))
  (rl-set-read-key! r aead sapk sapiv)
  (rl-set-write-key! r aead capk capiv)
  (tls13-make-conn r (unbox selected-alpn) (unbox peer-certs)
                   (hash 'alg alg 'exporter-master exporter-master
                         'server-cert-der (let ([pc (unbox peer-certs)])
                                            (and (pair? pc) (car pc))))))

;; ---- helpers for client ----
(define (p256-priv)
  ;; a scalar in [1, n-1]; rejection-sample via pubkey success
  (let loop ()
    (define k (random-bytes 32))
    (if (eqv? 1 (rktcrypto_p256_pubkey (make-bytes 65) k)) k (loop))))

(define (compute-ecdhe group priv peer-pub)
  (case group
    [(#x001d) (let ([out (make-bytes 32)])
                (unless (eqv? 1 (rktcrypto_x25519 out priv peer-pub)) (raise (tls-error "x25519 failed")))
                out)]
    [(#x0017) (let ([out (make-bytes 32)])
                (unless (eqv? 1 (rktcrypto_p256_ecdh out priv peer-pub)) (raise (tls-error "p256 ecdh failed")))
                out)]
    [(#x0018) (let ([out (make-bytes 48)])
                (unless (eqv? 1 (rktcrypto_p384_ecdh out priv peer-pub)) (raise (tls-error "p384 ecdh failed")))
                out)]
    [else (raise (tls-error "unsupported group"))]))

;; Certificate message -> list of DER certs (leaf first).
(define (parse-certificate-msg msg)
  ;; handshake header(4) certificate_request_context(vec1) certificate_list(vec3)
  (define ctx-len (bytes-ref msg 4))
  (define pos (+ 5 ctx-len))
  (define list-len (be->int msg pos (+ pos 3)))
  (set! pos (+ pos 3))
  (define end (+ pos list-len))
  (let loop ([pos pos] [acc '()])
    (if (>= pos end)
        (reverse acc)
        (let* ([clen (be->int msg pos (+ pos 3))]
               [cert (subbytes msg (+ pos 3) (+ pos 3 clen))]
               [ext-len (be->int msg (+ pos 3 clen) (+ pos 5 clen))])
          (loop (+ pos 5 clen ext-len) (cons cert acc))))))

(provide GROUP-X25519 GROUP-P256 GROUP-P384)

;; =====================================================================
;; Server handshake
;; =====================================================================
;; opts: hash with 'cert-ders (list of DER, leaf first), 'key (private-key
;;       struct: (cons type der)), 'alpn (list of bytes we support)
(define (tls13-accept in out opts)
  (define cert-ders (hash-ref opts 'cert-ders))
  (define key (hash-ref opts 'key))       ; (cons 'rsa der) or (cons 'p256 raw-scalar)
  (define our-alpn (hash-ref opts 'alpn '()))
  (define r (make-rl in out))
  (define hs (make-hsr r))

  ;; read ClientHello
  (define-values (ch-type ch) (hsr-next hs))
  (unless (= ch-type 1) (raise (tls-error "expected ClientHello")))
  (define-values (ch-suites ch-exts) (parse-client-hello ch))
  (define ch-random (subbytes ch 6 38))
  ;; Prefer TLS 1.3 only when the client advertises it (supported_versions
  ;; carries 0x0304) and offers a 1.3 suite; otherwise fall to TLS 1.2.
  (define sv (let ([e (assoc #x002b ch-exts)]) (and e (cdr e))))
  (define client-13?
    (and sv (positive? (bytes-length sv))
         (let ([n (bytes-ref sv 0)])
           (let loop ([i 1]) (and (< i (+ 1 n))
                                  (or (= #x0304 (be->int sv i (+ i 2))) (loop (+ i 2))))))))
  (define suite13 (and client-13? (for/or ([s (in-list ch-suites)] #:when (suite-supported? s)) s)))
  (cond
    [(not suite13)
     (define s12 (for/or ([s (in-list ch-suites)]
                          #:when (and (>= s #xC000) (server-can-12? s key))) s))
     (unless s12 (raise (tls-error "no common cipher suite")))
     (tls12-accept in out hs ch ch-random s12 opts)]
    [else (tls13-accept/13 in out opts r hs ch ch-suites ch-exts ch-random suite13)]))

(define (server-can-12? s key)
  ;; ECDHE-RSA suites need an RSA key; ECDHE-ECDSA need a P-256 key.
  (case s
    [(#xC02F #xC030 #xCCA8) (eq? (car key) 'rsa)]
    [(#xC02B #xC02C #xCCA9) (eq? (car key) 'p256)]
    [else #f]))

(define (tls13-accept/13 in out opts r hs ch ch-suites ch-exts ch-random suite)
  (parameterize ([keylog-proc (hash-ref opts 'keylog #f)] [keylog-cr ch-random])
  (define our-alpn (hash-ref opts 'alpn '()))
  (define-values (alg aead klen ilen dname) (suite-params suite))
  (define tr (make-transcript alg))
  ;; key_share: find a group we both support
  (define offered (parse-key-share-list (cdr (assoc #x0033 ch-exts))))
  (define chosen (or (for/or ([g (in-list (list GROUP-X25519 GROUP-P256 GROUP-P384))])
                       (and (assoc g offered) g))
                     (raise (tls-error "no common key-share group"))))
  (define peer-pub (cdr (assoc chosen offered)))
  ;; SNI + ALPN from client
  (define sni (let ([e (assoc #x0000 ch-exts)]) (and e (parse-sni (cdr e)))))
  ;; Server Name Indication callback: pick the cert/key for the requested
  ;; host. Falls back to the context's default cert when it returns #f.
  (define sel (let ([f (hash-ref opts 'sni-select #f)]) (and f sni (f sni))))
  (define cert-ders (if sel (car sel) (hash-ref opts 'cert-ders)))
  (define key (if sel (cdr sel) (hash-ref opts 'key)))
  (define client-alpn (let ([e (assoc #x0010 ch-exts)]) (and e (parse-alpn-list (cdr e)))))
  (define neg-alpn (and client-alpn (for/or ([p (in-list our-alpn)]
                                             #:when (member p client-alpn)) p)))
  (tr-add! tr ch)

  ;; our ephemeral share
  (define-values (our-priv our-pub) (gen-server-share chosen))
  (define ecdhe (compute-ecdhe chosen our-priv peer-pub))

  ;; ServerHello
  (define sid-echo (parse-session-id ch))
  (define sh-exts (bytes-append
                   (ext #x002b (u16 #x0304))
                   (ext #x0033 (bytes-append (u16 chosen) (vec 2 our-pub)))))
  (define sh-body (bytes-append (u16 #x0303) (random-bytes 32)
                                (vec 1 sid-echo)
                                (u16 suite) (u8 0)
                                (vec 2 sh-exts)))
  (define sh (bytes-append (u8 2) (u24 (bytes-length sh-body)) sh-body))
  (tr-add! tr sh)
  (rl-write-record r 22 sh)

  ;; key schedule
  (define k (ks alg aead klen ilen #f #f #f #f #f #f))
  (ks-derive-handshake! k ecdhe)
  (ks-hs-traffic! k (tr-hash tr))
  (klog! "CLIENT_HANDSHAKE_TRAFFIC_SECRET" ch-random (ks-c-hs k))
  (klog! "SERVER_HANDSHAKE_TRAFFIC_SECRET" ch-random (ks-s-hs k))
  (define-values (skey siv) (traffic->keys k (ks-s-hs k)))
  (define-values (ckey civ) (traffic->keys k (ks-c-hs k)))
  (rl-set-write-key! r aead skey siv)   ; server writes with s hs traffic

  ;; EncryptedExtensions
  (define ee-body (vec 2 (if neg-alpn
                             (ext #x0010 (vec 2 (vec 1 neg-alpn)))
                             #"")))
  (define ee (bytes-append (u8 8) (u24 (bytes-length ee-body)) ee-body))
  (tr-add! tr ee)
  (rl-write-record r 22 ee)

  ;; Certificate
  (define cert-list
    (apply bytes-append
           (for/list ([d (in-list cert-ders)]) (bytes-append (vec 3 d) (vec 2 #"")))))
  (define cert-body (bytes-append (vec 1 #"") (vec 3 cert-list)))
  (define cert-msg (bytes-append (u8 11) (u24 (bytes-length cert-body)) cert-body))
  (tr-add! tr cert-msg)
  (rl-write-record r 22 cert-msg)

  ;; CertificateVerify
  (define scheme (server-sig-scheme key))
  (define cv-content (bytes-append (make-bytes 64 #x20)
                                   #"TLS 1.3, server CertificateVerify" (bytes 0)
                                   (tr-hash tr)))
  (define sig (server-sign key scheme cv-content))
  (define cv-body (bytes-append (u16 scheme) (vec 2 sig)))
  (define cv (bytes-append (u8 15) (u24 (bytes-length cv-body)) cv-body))
  (tr-add! tr cv)
  (rl-write-record r 22 cv)

  ;; Finished
  (define sfin (finished-verify-data alg (ks-s-hs k) (tr-hash tr)))
  (define fin (bytes-append (u8 20) (u24 (bytes-length sfin)) sfin))
  (tr-add! tr fin)
  (rl-write-record r 22 fin)

  ;; application secrets (transcript through server Finished)
  (ks-master! k)
  (define th-sfin (tr-hash tr))
  (ks-ap-traffic! k th-sfin)
  (define exporter-master (derive-secret alg (ks-master k) #"exp master" th-sfin))
  (klog! "CLIENT_TRAFFIC_SECRET_0" ch-random (ks-c-ap k))
  (klog! "SERVER_TRAFFIC_SECRET_0" ch-random (ks-s-ap k))
  (klog! "EXPORTER_SECRET" ch-random exporter-master)

  ;; read client Finished under client handshake keys
  (rl-set-read-key! r aead ckey civ)
  (let loop ()
    (define-values (mt msg) (hsr-next hs))
    (case mt
      [(20)
       (define expected (finished-verify-data alg (ks-c-hs k) (tr-hash tr)))
       (unless (ct-equal? expected (subbytes msg 4)) (raise (tls-alert 51 "client Finished mismatch")))
       (tr-add! tr msg)]
      [(11 15) (tr-add! tr msg) (loop)]   ; optional client cert / cert-verify (unrequested: ignore)
      [else (raise (tls-error (format "unexpected msg ~a from client" mt)))]))

  ;; install application keys
  (define-values (sapk sapiv) (traffic->keys k (ks-s-ap k)))
  (define-values (capk capiv) (traffic->keys k (ks-c-ap k)))
  (rl-set-write-key! r aead sapk sapiv)
  (rl-set-read-key! r aead capk capiv)
  (tls13-make-conn r neg-alpn '() (hash 'alg alg 'exporter-master exporter-master
                                        'server-cert-der (and (pair? cert-ders)
                                                              (car cert-ders))))))

;; ---- server helpers ----
(define (gen-server-share group)
  (case group
    [(#x001d) (let ([priv (random-bytes 32)] [pub (make-bytes 32)])
                (rktcrypto_x25519 pub priv (bytes-append (bytes 9) (make-bytes 31 0)))
                (values priv pub))]
    [(#x0017) (let ([priv (p256-priv)] [pub (make-bytes 65)])
                (rktcrypto_p256_pubkey pub priv) (values priv pub))]
    [(#x0018) (let ([priv (random-bytes 48)] [pub (make-bytes 97)])
                (rktcrypto_p384_pubkey pub priv) (values priv pub))]))

(define (server-sig-scheme key)
  (case (car key) [(rsa) #x0804] [(p256) #x0403] [else (raise (tls-error "unsupported server key type"))]))

(define (server-sign key scheme content)
  (case (car key)
    [(rsa)
     (define kd (cdr key))
     (define sig (make-bytes 512))
     (define n (rktcrypto_rsa_sign_msg 1 SHA256 kd (bytes-length kd) content (bytes-length content) sig))
     (when (zero? n) (raise (tls-error "RSA signing failed")))
     (subbytes sig 0 n)]
    [(p256)
     (define sig (make-bytes 64))
     (unless (eqv? 1 (rktcrypto_p256_ecdsa_sign sig content (bytes-length content) (cdr key)))
       (raise (tls-error "ECDSA signing failed")))
     ;; raw r||s -> DER SEQUENCE
     (raw->ecdsa-der sig 32)]))

(define (raw->ecdsa-der raw fb)
  (define (der-int b)
    (define v (let strip ([i 0]) (if (and (< i (sub1 (bytes-length b))) (zero? (bytes-ref b i))) (strip (add1 i)) (subbytes b i))))
    (define v2 (if (>= (bytes-ref v 0) #x80) (bytes-append (bytes 0) v) v))
    (bytes-append (bytes #x02 (bytes-length v2)) v2))
  (define r (der-int (subbytes raw 0 fb)))
  (define s (der-int (subbytes raw fb (* 2 fb))))
  (bytes-append (bytes #x30 (+ (bytes-length r) (bytes-length s))) r s))

;; ---- ClientHello parsing (server side) ----
(define (parse-client-hello ch)
  ;; header(4) legacy_version(2) random(32) session_id(vec1) cipher_suites(vec2)
  ;; compression(vec1) extensions(vec2)
  (define sid-len (bytes-ref ch 38))
  (define pos (+ 39 sid-len))
  (define cs-len (be->int ch pos (+ pos 2)))
  (define suites (let loop ([p (+ pos 2)] [acc '()])
                   (if (>= p (+ pos 2 cs-len)) (reverse acc)
                       (loop (+ p 2) (cons (be->int ch p (+ p 2)) acc)))))
  (set! pos (+ pos 2 cs-len))
  (define comp-len (bytes-ref ch pos))
  (set! pos (+ pos 1 comp-len))
  (define ext-len (be->int ch pos (+ pos 2)))
  (values suites (parse-extensions (subbytes ch (+ pos 2) (+ pos 2 ext-len)))))

(define (parse-session-id ch)
  (define sid-len (bytes-ref ch 38))
  (subbytes ch 39 (+ 39 sid-len)))

(define (parse-key-share-list body)
  ;; body: vec2( KeyShareEntry* ) where entry = group(2) vec2(key)
  (define len (be->int body 0 2))
  (let loop ([p 2] [acc '()])
    (if (>= p (+ 2 len)) (reverse acc)
        (let* ([g (be->int body p (+ p 2))]
               [klen (be->int body (+ p 2) (+ p 4))]
               [key (subbytes body (+ p 4) (+ p 4 klen))])
          (loop (+ p 4 klen) (cons (cons g key) acc))))))

(define (parse-sni body)
  ;; vec2( ServerNameList ): entry type(1) vec2(name)
  (define list-len (be->int body 0 2))
  (and (>= list-len 3)
       (let ([nlen (be->int body 3 5)])
         (bytes->string/latin-1 (subbytes body 5 (+ 5 nlen))))))

(define (parse-alpn-list body)
  (define list-len (be->int body 0 2))
  (let loop ([p 2] [acc '()])
    (if (>= p (+ 2 list-len)) (reverse acc)
        (let ([l (bytes-ref body p)])
          (loop (+ p 1 l) (cons (subbytes body (+ p 1) (+ p 1 l)) acc))))))

(provide parse-alpn-list parse-key-share-list)
