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
         "rktcrypto-ocsp.rkt"
         racket/port
         racket/lazy-require)

;; TLS 1.2 lives in a sibling module that requires this one; break the cycle
;; with a lazy require so the 1.2 continuation loads on first use.
(lazy-require
 ["rktcrypto-tls12.rkt" (tls12-client-finish tls12-accept tls12-suites tls12-dhe-suite? tls12-server-can?)])

(provide tls13-connect
         tls13-accept
         (struct-out tls-conn)
         tls-conn-read-bytes
         tls-conn-read-in!
         tls-conn-write-bytes
         tls-conn-close-notify
         tls-conn-abandon-write!
         tls-conn-channel-binding
         tls-conn-request-key-update)

;; ---- byte building ----
(define (u8 n) (bytes n))
(define (u16 n) (bytes (arithmetic-shift n -8) (bitwise-and n 255)))
(define (u24 n) (bytes (bitwise-and (arithmetic-shift n -16) 255)
                       (bitwise-and (arithmetic-shift n -8) 255)
                       (bitwise-and n 255)))
(define (u32 n) (bytes (bitwise-and (arithmetic-shift n -24) 255)
                       (bitwise-and (arithmetic-shift n -16) 255)
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
;; ssl-set-ciphers! policy (from parse-cipher-policy): order/filter a default
;; suite list by an allowed-id list. #f = no constraint; 'none = match nothing.
(define (order-by-policy defaults policy)
  (cond [(not policy) defaults]
        [(eq? policy 'none) '()]
        [else (filter (lambda (s) (memv s defaults)) policy)]))

;; ---- named groups ----
(define GROUP-X25519 #x001d)
(define GROUP-P256   #x0017)
(define GROUP-P384   #x0018)
;; RFC 7919 finite-field groups, advertised for the TLS 1.2 DHE suites only
;; (no TLS 1.3 key share is offered for them)
(define FFDHE-GROUPS (list #x0100 #x0101 #x0102))   ; ffdhe2048 ffdhe3072 ffdhe4096

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
            [waead #:mutable] [wkey #:mutable] [wiv #:mutable] [wseq #:mutable]
            lock                  ; held while a thread reads from `in`
            [pending #:mutable]   ; records read while draining during a write: list of (type . payload)
            [inbuf #:mutable]     ; partial record accumulated by the non-blocking reader
            [handshake-done? #:mutable])) ; application keys installed: no plaintext CCS any more

(define (make-rl in out)
  (rl in out #f #f #f 0 #f #f #f 0 (make-semaphore 1) '() #"" #f))

;; Upper bound on records queued by a draining write before it stops
;; draining (a peer that floods while never reading must not grow our
;; memory without limit; ~16 MB at the maximum record size).
(define MAX-PENDING-RECORDS 1024)

;; Writes all of `bs` to `out` without blocking indefinitely while the
;; peer has data for us. A plain blocking write deadlocks when both sides
;; write at once into full transport buffers and neither reads -- which
;; happens routinely: the server writes NewSessionTicket right after the
;; handshake, while the client has started writing application data.
;; When the transport cannot take more, wait for it to drain OR for input
;; to arrive; in the latter case `read-one!` reads one record and queues
;; it for the next read. `lock` is the read lock: if another thread is
;; already reading (and thus draining the peer), wait for it instead.
;; `read-one!` returns #f at transport EOF, after which only the output
;; side is waited on.
(define (write-draining out in bs lock read-one!)
  (define len (bytes-length bs))
  (let loop ([off 0] [drain? #t])
    (when (< off len)
      (define n (write-bytes-avail* bs out off len))
      (cond
        [(and n (> n 0)) (loop (+ off n) drain?)]
        [(not drain?) (sync out) (loop off #f)]
        [else
         (define which (sync (handle-evt out (lambda (_) 'out)) (handle-evt in (lambda (_) 'in))))
         (cond
           [(eq? which 'out) (loop off #t)]
           [(semaphore-try-wait? lock)
            (define more? (dynamic-wind void read-one! (lambda () (semaphore-post lock))))
            (loop off (and more? #t))]
           [else
            ;; another thread is reading: it keeps the peer draining
            (sync (handle-evt out void) (semaphore-peek-evt lock))
            (loop off #t)])]))))
(provide write-draining)

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

;; ---- partial-record buffering, shared with the 1.2 record layer ----
;; `get-buf`/`set-buf!` access the layer's partial-record buffer. The
;; read lock is held by the caller.
;; Exactly `n` bytes: first from the buffer, then (blocking) from the port.
(define (buffered-read-exact! in get-buf set-buf! n)
  (define buf (get-buf))
  (cond
    [(>= (bytes-length buf) n)
     (set-buf! (subbytes buf n))
     (subbytes buf 0 n)]
    [else
     (define rest (read-n in (- n (bytes-length buf))))
     (set-buf! #"")
     (bytes-append buf rest)]))
;; Pull whatever the transport has right now into the buffer, never
;; blocking: 'record once a whole record (5-byte header + length) is
;; buffered, 'eof at a transport EOF with nothing buffered, 'wait when more
;; input is needed. A partial record stays buffered, so progress never
;; depends on the transport holding a whole record at once (a pipe of
;; capacity 1 must work), nor on the peer finishing a record before we
;; finish ours.
(define (fill-record-nb! in get-buf set-buf!)
  (let loop ()
    (define buf (get-buf))
    (define have (bytes-length buf))
    (define need (if (< have 5) 5 (+ 5 (be->int buf 3 5))))
    (cond
      [(>= have need) 'record]
      [else
       (define tmp (make-bytes (- need have)))
       (define g (with-transport-errors (read-bytes-avail!* tmp in)))
       (cond
         [(eof-object? g)
          (if (zero? have) 'eof (raise (tls-error "unexpected EOF from peer")))]
         [(and (exact-integer? g) (> g 0))
          (set-buf! (bytes-append buf (subbytes tmp 0 g)))
          (loop)]
         [else 'wait])])))
(provide buffered-read-exact! fill-record-nb! read-n)

(define (rl-read-exact! r n)
  (buffered-read-exact! (rl-in r) (lambda () (rl-inbuf r)) (lambda (b) (set-rl-inbuf! r b)) n))
(define (rl-fill-nb! r)
  (fill-record-nb! (rl-in r) (lambda () (rl-inbuf r)) (lambda (b) (set-rl-inbuf! r b))))

;; Reads one record; returns (values content-type payload-bytes). Decrypts
;; when a read key is installed (skipping the outer app_data type and the
;; inner content-type/padding). Records queued by a draining write come
;; first.
(define (rl-read-record r)
  (call-with-semaphore
   (rl-lock r)
   (lambda ()
     (define pending (rl-pending r))
     (cond
       [(pair? pending)
        (set-rl-pending! r (cdr pending))
        (values (caar pending) (cdar pending))]
       [else (rl-read-record/raw r)]))))

;; Non-blocking variant: (values type payload) when a whole record is
;; available (queued, or assembled from what the transport has right now),
;; (values 'eof #f) at a clean transport EOF, or (values #f evt) with an evt
;; that becomes ready when more input arrives.
(define (rl-try-read-record r)
  (call-with-semaphore
   (rl-lock r)
   (lambda ()
     (define pending (rl-pending r))
     (cond
       [(pair? pending)
        (set-rl-pending! r (cdr pending))
        (values (caar pending) (cdar pending))]
       [else
        (case (rl-fill-nb! r)
          [(record) (rl-read-record/raw r)]
          [(eof) (values 'eof #f)]
          [else (values #f (rl-in r))])]))))

;; One step of reading for the draining writer (read lock held by the
;; caller): queue a record if a whole one is available now; never blocks.
;; Returns #f at transport EOF.
(define (rl-drain-one! r)
  (with-handlers ([(lambda (e) (and (exn:tls? e) (not (exn:tls-alert e)))) (lambda (_) #f)])
    (case (if (>= (length (rl-pending r)) MAX-PENDING-RECORDS) 'full (rl-fill-nb! r))
      [(record)
       (define-values (type payload) (rl-read-record/raw r))
       (set-rl-pending! r (append (rl-pending r) (list (cons type payload))))
       #t]
      [(eof full) #f]
      [else #t])))

(define (rl-read-record/raw r)
  (define hdr (rl-read-exact! r 5))
  (define len (be->int hdr 3 5))
  ;; RFC 8446 §5.2: TLSCiphertext.length MUST NOT exceed 2^14 + 256.
  (when (> len 16640) (raise (tls-alert 22 "record_overflow")))
  (define body (rl-read-exact! r len))
  (define type (bytes-ref hdr 0))
  (cond
    ;; RFC 8446 §5: once a read key is installed, everything the peer sends
    ;; is protected (outer type application_data, 23). The only plaintext
    ;; record still allowed is the middlebox-compatibility ChangeCipherSpec,
    ;; and only until the handshake completes. Anything else unprotected --
    ;; an alert, a handshake message, a KeyUpdate -- is attacker-writable
    ;; and is rejected (an injected plaintext close_notify would otherwise
    ;; truncate the stream silently).
    [(and (rl-rkey r) (not (= type 23)))
     (cond
       [(and (= type 20) (not (rl-handshake-done? r)) (equal? body #"\1")) (values 20 body)]
       [else (raise (tls-alert 10 (format "unprotected record of type ~a after keys were installed" type)))])]
    [(rl-rkey r)
     (define rec (bytes-append hdr body))
     (define inner (tls13-open (rl-raead r) (rl-rkey r) (rl-riv r) (rl-rseq r) rec))
     (unless inner (raise (tls-alert 20 "bad_record_mac")))
     (set-rl-rseq! r (add1 (rl-rseq r)))
     ;; strip trailing zero padding, then the content-type byte
     (let loop ([i (sub1 (bytes-length inner))])
       (cond [(< i 0) (raise (tls-error "empty inner plaintext"))]
             [(zero? (bytes-ref inner i)) (loop (sub1 i))]
             ;; RFC 8446 §5.2: decrypted TLSInnerPlaintext.content is <= 2^14.
             [(> i 16384) (raise (tls-alert 22 "record_overflow"))]
             [else (values (bytes-ref inner i) (subbytes inner 0 i))]))]
    [else (values type body)]))
;; After the application read key is installed: plaintext CCS no longer allowed.
(define (rl-finish-handshake! r) (set-rl-handshake-done?! r #t))

;; Writes a record of `type` with `payload`, encrypting when a write key is
;; installed. Splits >16KiB payloads.
(define (rl-write-record r type payload)
  (define rec
    (cond
      [(rl-wkey r)
       (define inner (bytes-append payload (u8 type)))
       (begin0 (tls13-seal (rl-waead r) (rl-wkey r) (rl-wiv r) (rl-wseq r) inner)
               (set-rl-wseq! r (add1 (rl-wseq r))))]
      [else (bytes-append (u8 type) (u16 #x0303) (u16 (bytes-length payload)) payload)]))
  (with-transport-errors
    (write-draining (rl-out r) (rl-in r) rec (rl-lock r) (lambda () (rl-drain-one! r)))))

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

;; RFC 8446 §6 / RFC 5246 §7.2 AlertDescription names, for reporting what
;; the peer sent (libssl reports the alert by name too).
(define (alert-name code)
  (case code
    [(0) "close_notify"] [(10) "unexpected_message"] [(20) "bad_record_mac"]
    [(21) "decryption_failed"] [(22) "record_overflow"] [(30) "decompression_failure"]
    [(40) "handshake_failure"] [(41) "no_certificate"] [(42) "bad_certificate"]
    [(43) "unsupported_certificate"] [(44) "certificate_revoked"] [(45) "certificate_expired"]
    [(46) "certificate_unknown"] [(47) "illegal_parameter"] [(48) "unknown_ca"]
    [(49) "access_denied"] [(50) "decode_error"] [(51) "decrypt_error"]
    [(60) "export_restriction"] [(70) "protocol_version"] [(71) "insufficient_security"]
    [(80) "internal_error"] [(86) "inappropriate_fallback"] [(90) "user_canceled"]
    [(100) "no_renegotiation"] [(109) "missing_extension"] [(110) "unsupported_extension"]
    [(111) "certificate_unobtainable"] [(112) "unrecognized_name"]
    [(113) "bad_certificate_status_response"] [(114) "bad_certificate_hash_value"]
    [(115) "unknown_psk_identity"] [(116) "certificate_required"]
    [(120) "no_application_protocol"]
    [else "unknown"]))
;; An alert record's payload (level, description) received from the peer
;; -> the exception to raise for it.
(define (peer-alert payload)
  (define code (if (>= (bytes-length payload) 2) (bytes-ref payload 1) 0))
  (tls-alert code (format "received ~a" (alert-name code))))
;; On the application-data read path: close_notify and warning-level alerts
;; end the stream; any other fatal alert is an error, as with libssl.
(define (alert->eof payload)
  (if (and (>= (bytes-length payload) 2) (= 2 (bytes-ref payload 0)) (not (zero? (bytes-ref payload 1))))
      (raise (peer-alert payload))
      eof))
(provide alert-name peer-alert alert->eof)

;; =====================================================================
;; Handshake message reader (reassembles across records)
;; =====================================================================
;; Buffers handshake bytes; hands back complete messages. Also transparently
;; skips ChangeCipherSpec records and surfaces alerts.
(struct hsr (rl [buf #:mutable]))
(define (make-hsr r) (hsr r #""))
;; Largest handshake message accepted (the 24-bit length field allows 16 MB;
;; libssl caps certificate chains at 100 KB). Bounds the reassembly buffer.
(define MAX-HANDSHAKE-MESSAGE (* 128 1024))

(define (hsr-fill r)
  (let loop ()
    (define-values (type payload) (rl-read-record (hsr-rl r)))
    (cond
      [(= type 20) (loop)]                       ; change_cipher_spec: ignore
      [(= type 21)
       (if (and (>= (bytes-length payload) 2) (= 1 (bytes-ref payload 0)))
           (loop)                                ; warning alert (e.g. close_notify handled elsewhere)
           (raise (peer-alert payload)))]
      [(= type 22)
       (when (> (+ (bytes-length (hsr-buf r)) (bytes-length payload)) (+ MAX-HANDSHAKE-MESSAGE 4))
         (raise (tls-alert 50 "handshake message too large")))   ; decode_error
       (set-hsr-buf! r (bytes-append (hsr-buf r) payload))]
      ;; application data before the handshake is complete: nothing of ours
      ;; expects it (no early data is offered or accepted), and buffering it
      ;; would let the peer grow our memory without limit
      [(= type 23) (raise (tls-alert 10 "application data before the handshake completed"))]
      [else (raise (tls-alert 10 (format "unexpected record type ~a" type)))])))

;; Returns (values msg-type full-message-bytes) where full-message includes
;; the 4-byte handshake header (needed verbatim for the transcript).
(define (hsr-next r)
  (let loop ()
    (define buf (hsr-buf r))
    (cond
      [(< (bytes-length buf) 4) (hsr-fill r) (loop)]
      [else
       (define mlen (be->int buf 1 4))
       (when (> mlen MAX-HANDSHAKE-MESSAGE) (raise (tls-alert 50 "handshake message too large")))
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
          ;; RFC 8446 §4.2: at most one extension of each type per block.
          (when (assv type acc) (raise (tls-alert 47 "duplicate extension")))  ; illegal_parameter
          (loop (+ pos 4 len) (cons (cons type body) acc))))))
(provide parse-extensions)

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

;; handshake secret from ECDHE shared secret. `psk` (or #f) seeds the Early
;; Secret: for a fresh handshake Early = HKDF-Extract(0,0); for PSK resumption
;; (RFC 8446 §7.1) Early = HKDF-Extract(0, PSK).
(define (ks-derive-handshake! k ecdhe [psk #f])
  (define alg (ks-alg k))
  (define early (tls13-extract alg #f psk))
  (define derived (derive-secret alg early #"derived" (empty-hash alg)))
  (define hs (tls13-extract alg derived ecdhe))
  (set-ks-hs-secret! k hs))

;; =====================================================================
;; TLS 1.3 session resumption (RFC 8446 §2.2, §4.6.1, §4.2.11) — psk_dhe_ke
;; =====================================================================
;; A resumable session cached by the client (and re-offered as a PSK).
;; peer-certs carries the originally-authenticated chain so a resumed connection
;; still reports the peer identity (server-side sessions leave it '()).
;; verified? records whether that chain was verified, so a resumed connection
;; reports the same `ssl-peer-verified?` as the original.
(struct tls-session (psk ticket suite alpn issued-ms age-add lifetime peer-certs verified?) #:transparent)
(provide (struct-out tls-session))

;; resumption_master_secret = Derive-Secret(master, "res master", Hash(msgs..CF))
(define (res-master-secret alg master th) (derive-secret alg master #"res master" th))
;; PSK = HKDF-Expand-Label(resumption_master, "resumption", ticket_nonce, Hash.len)
(define (psk-from-ticket alg res-master nonce)
  (expand-label alg res-master #"resumption" nonce (digest-size alg)))
;; binder = HMAC(finished_key(binder_key), Transcript-Hash(Truncate(ClientHello)))
;; where binder_key = Derive-Secret(Early=Extract(0,PSK), "res binder", "").
;; finished-verify-data computes HMAC(finished_key(base), th) — exactly the binder.
(define (compute-psk-binder alg psk th)
  (define early (tls13-extract alg #f psk))
  (define binder-key (derive-secret alg early #"res binder" (empty-hash alg)))
  (finished-verify-data alg binder-key th))

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
                  binding                ; binding: hash for channel binding, or #f
                  key-update             ; thunk to send a post-handshake KeyUpdate, or #f
                  recv-nb                ; A1: non-blocking recv (-> bytes | eof | evt), or #f
                  verified)              ; this connection's peer-verification result (boolean)
  #:mutable)

;; Post-handshake key-update state (RFC 8446 §4.6.3): key schedule + AEAD + the
;; current receive/send application traffic secrets (boxed, advanced per update).
(struct ku (k aead recv send) #:mutable)
(define (ku-advance! secret-box alg) ; secret_{N+1} = HKDF-Expand-Label(secret_N,"traffic upd","",Hash.len)
  (define n (expand-label alg (unbox secret-box) #"traffic upd" #"" (digest-size alg)))
  (set-box! secret-box n) n)

;; Build the 1.3 tls-conn from an installed record layer. `kus` (a ku struct or
;; #f) enables post-handshake KeyUpdate processing on the read path.
(define (tls13-make-conn r alpn peer-certs [binding #f] [kus #f] [resume #f] [verified? #f])
  ;; A2: on the client, capture a server NewSessionTicket into resume's
  ;; 'session-box so a later connect can offer it as a PSK.
  (define (capture-nst! payload)
    (when resume
      (define alg (hash-ref resume 'alg))
      (define rm (hash-ref resume 'res-master))
      (define lifetime (be->int payload 4 8))
      (define age-add (be->int payload 8 12))
      (define nlen (bytes-ref payload 12))
      (define nonce (subbytes payload 13 (+ 13 nlen)))
      (define tpos (+ 13 nlen))
      (define tlen (be->int payload tpos (+ tpos 2)))
      (define ticket (subbytes payload (+ tpos 2) (+ tpos 2 tlen)))
      (when (positive? tlen)
        (set-box! (hash-ref resume 'session-box)
                  (tls-session (psk-from-ticket alg rm nonce) ticket
                               (hash-ref resume 'suite) (hash-ref resume 'alpn)
                               (current-inexact-milliseconds) age-add lifetime
                               (hash-ref resume 'peer-certs '())
                               (hash-ref resume 'verified? #f))))))
  (define (do-key-update! payload)
    ;; peer updated its send key -> advance our receive key; if it requested an
    ;; update, reply with our own KeyUpdate and advance our send key.
    (define alg (ks-alg (ku-k kus)))
    (define-values (rk riv) (traffic->keys (ku-k kus) (ku-advance! (ku-recv kus) alg)))
    (rl-set-read-key! r (ku-aead kus) rk riv)
    (when (and (>= (bytes-length payload) 5) (= 1 (bytes-ref payload 4)))  ; update_requested
      (rl-write-record r 22 (bytes 24 0 0 1 0))                            ; KeyUpdate{not_requested}
      (define-values (sk siv) (traffic->keys (ku-k kus) (ku-advance! (ku-send kus) alg)))
      (rl-set-write-key! r (ku-aead kus) sk siv)))
  ;; one record -> application bytes, eof, or 'again (nothing for the caller)
  (define (dispatch type payload)
    (cond
      [(and (= type 23) (positive? (bytes-length payload))) payload]
      [(= type 21) (alert->eof payload)]                 ; close_notify -> eof; fatal -> raise
      [(= type 22)                                       ; NewSessionTicket(4) / KeyUpdate(24)
       (cond
         [(and kus (>= (bytes-length payload) 1) (= 24 (bytes-ref payload 0))) (do-key-update! payload)]
         [(and (>= (bytes-length payload) 1) (= 4 (bytes-ref payload 0))) (capture-nst! payload)])
       'again]
      [else 'again]))
  (define (transport-eof? e) (and (exn:tls? e) (not (exn:tls-alert e))))
  (define (recv)
    (let loop ()
      (with-handlers ([transport-eof? (lambda (_) eof)])
        (define-values (type payload) (rl-read-record r))
        (define v (dispatch type payload))
        (if (eq? v 'again) (loop) v))))
  ;; A1: non-blocking receive. Returns one app-data chunk (bytes), eof, or an
  ;; evt that becomes ready when more input has arrived -- so a caller can
  ;; sync without a busy loop. Handshake/NST/KeyUpdate records are consumed
  ;; inline exactly as the blocking `recv` does.
  (define (recv-nb)
    (let loop ()
      (with-handlers ([transport-eof? (lambda (_) eof)])
        (define-values (type payload) (rl-try-read-record r))
        (cond
          [(not type) payload]                           ; an evt: more input needed
          [(eq? type 'eof) eof]
          [else
           (define v (dispatch type payload))
           (if (eq? v 'again) (loop) v)]))))
  (define (send bs)
    (let loop ([off 0])
      (when (< off (bytes-length bs))
        (define chunk (min 16384 (- (bytes-length bs) off)))
        (rl-write-record r 23 (subbytes bs off (+ off chunk)))
        (loop (+ off chunk)))))
  (define (shut) (with-handlers ([exn:fail? void]) (rl-write-record r 21 (bytes 1 0))))
  (define (request-key-update)      ; RFC 8446 §4.6.3: ask the peer to update too
    (when kus
      (rl-write-record r 22 (bytes 24 0 0 1 1))  ; KeyUpdate{update_requested}
      (define alg (ks-alg (ku-k kus)))
      (define-values (sk siv) (traffic->keys (ku-k kus) (ku-advance! (ku-send kus) alg)))
      (rl-set-write-key! r (ku-aead kus) sk siv)))
  (tls-conn recv send shut #"" #f #f alpn peer-certs 'tls1.3 binding request-key-update recv-nb
            (and verified? #t)))

;; Post-handshake KeyUpdate: advance our send key and ask the peer to update its
;; keys too (RFC 8446 §4.6.3). No-op on a connection without key-update support.
(define (tls-conn-request-key-update c)
  (define f (tls-conn-key-update c))
  (when f (f)))

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

;; A1: a make-input-port-compatible read step. Returns the number of bytes
;; copied into `bstr` (progress), eof, or an evt whose result is 0 (no bytes
;; now — sync on it and retry). TLS 1.3 uses the non-blocking `recv-nb`; TLS 1.2
;; (no recv-nb) falls back to a blocking recv, still honoring buffered data.
(define (tls-conn-read-in! c bstr)
  (cond
    [(and (tls-conn-closed c) (zero? (bytes-length (tls-conn-rbuf c)))) eof]
    [(positive? (bytes-length (tls-conn-rbuf c)))
     (define buf (tls-conn-rbuf c))
     (define take (min (bytes-length bstr) (bytes-length buf)))
     (bytes-copy! bstr 0 buf 0 take)
     (set-tls-conn-rbuf! c (subbytes buf take))
     take]
    [(tls-conn-recv-nb c)
     (define st ((tls-conn-recv-nb c)))
     (cond
       [(eof-object? st) (set-tls-conn-closed! c #t) eof]
       [(bytes? st) (set-tls-conn-rbuf! c st) (tls-conn-read-in! c bstr)]
       [else (wrap-evt st (lambda (_) 0))])]           ; evt: more input has arrived
    [else
     (define got ((tls-conn-recv c)))
     (cond
       [(eof-object? got) (set-tls-conn-closed! c #t) eof]
       [else (set-tls-conn-rbuf! c got) (tls-conn-read-in! c bstr)])]))

(define (tls-conn-write-bytes c bs)
  (when (tls-conn-wclosed c)
    (raise (tls-error "write after the TLS write direction was closed")))
  ((tls-conn-send c) bs)
  (bytes-length bs))

;; close_notify only closes the write direction (RFC 8446 6.1); reads keep
;; draining until the peer's close_notify or transport EOF sets `closed`.
;; Once the peer has closed its side, nothing is sent: the peer has
;; stopped reading at the TLS level, so a close_notify could only sit in
;; (or block on) the transport, and the libssl-based implementation sent
;; nothing in this state either (callers reuse the underlying ports after
;; both sides closed and expect them to be clean).
(define (tls-conn-close-notify c)
  (unless (tls-conn-wclosed c)
    (set-tls-conn-wclosed! c #t)
    (unless (tls-conn-closed c)
      ((tls-conn-shut c)))))

;; Close the write direction without sending close_notify, for
;; ssl-abandon-port: the peer sees no shutdown and keeps sending.
(define (tls-conn-abandon-write! c)
  (set-tls-conn-wclosed! c #t))

;; RFC 5929 §4.1: the tls-server-end-point hash uses the certificate's signature
;; hash algorithm; MD5/SHA-1/unknown map to SHA-256.
(define (server-end-point-digest der)
  (case (with-handlers ([exn:fail? (lambda (_) #f)])
          (certificate-sig-digest (parse-certificate der)))
    [(sha384) SHA384]
    [(sha512) SHA512]
    [else SHA256]))

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
     ;; RFC 5929 §4.1: hash the leaf with the certificate's own signature hash;
     ;; if that is MD5 or SHA-1 (or unknown), use SHA-256.
     (digest (server-end-point-digest der) der)]
    [(tls-unique)
     ;; RFC 5929 §3.1: the first Finished's verify_data. Defined for TLS 1.2;
     ;; TLS 1.3 has no tls-unique (RFC 9266 directs callers to tls-exporter).
     (define u (and b (hash-ref b 'tls-unique #f)))
     (unless u (raise (tls-error "tls-unique channel binding unavailable (TLS 1.3 uses tls-exporter)")))
     u]
    [else (raise (tls-error (format "unsupported channel binding ~a" kind)))]))
;; Generic tls-conn constructor used by the TLS 1.2 engine.
(define (make-tls-conn recv send shut peer-ders protocol [binding #f] [verified? #f])
  (tls-conn recv send shut #"" #f #f #f peer-ders protocol binding #f #f (and verified? #t)))

;; Peer verification outcome for a connection. Chain validation
;; (`verify?`) and hostname matching (`verify-hostname?`) are independent
;; switches, as in the libssl-based implementation: enabling one does not
;; enable the other. The chain is validated whenever a certificate was
;; presented, so that `ssl-peer-verified?` reports the outcome even on a
;; connection that does not enforce it; a failure aborts the handshake
;; only for the checks that are enforced. Returns #t when the chain
;; validates against `anchors` and, with `verify-hostname?`, the leaf
;; matches `host`.
(define (peer-verification-result certs anchors host verify? verify-hostname?)
  (when (and (null? certs) (or verify? verify-hostname?))
    (raise (tls-alert 42 "peer sent no certificate")))          ; bad_certificate
  (define chain-ok?
    (and (pair? certs)
         (with-handlers ([exn:fail? (lambda (e) (if verify? (raise e) #f))])
           (verify-chain certs anchors)
           #t)))
  (define host-ok?
    (and verify-hostname?
         (begin
           (unless host (raise (tls-error "hostname not provided for verification")))
           (check-hostname (parse-certificate (car certs)) host)
           #t)))
  (and chain-ok? (or (not verify-hostname?) host-ok?) #t))
(provide peer-verification-result)

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
         make-hsr hsr-next rl-finish-handshake!
         (struct-out transcript) make-transcript tr-add! tr-hash tr-set-alg!
         u8 u16 u24 u32 vec be->int ext parse-extensions
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
  (define verify-hostname? (hash-ref opts 'verify-hostname? #f))
  (when (and verify-hostname? (not host))
    (raise (tls-error "hostname not provided for verification")))
  (define anchors (hash-ref opts 'trust-anchors '()))
  (define want-ocsp? (hash-ref opts 'check-revocation #f))   ; OCSP stapling (A3)
  (define client-auth (let ([k (hash-ref opts 'client-key #f)]  ; A4: (cons cert-ders key) or #f
                            [c (hash-ref opts 'client-cert-ders '())])
                        (and k (pair? c) (cons c k))))
  (define groups (hash-ref opts 'groups (list GROUP-X25519 GROUP-P256)))
  (define resume-box (hash-ref opts 'resume-session-box #f))   ; A2: box for NST capture / PSK offer
  (define ticket12-box (hash-ref opts 'ticket12-box #f))       ; A2 (1.2): box for a SessionTicket (RFC 5077)
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
                  (bytes-append (u16 group) (vec 2 pub)))]
      [else (raise (tls-alert 47 (format "server requested a key share for unsupported group ~a" group)))]))

  (define session-id (random-bytes 32))

  (define only-12? (hash-ref opts 'tls12-only? #f))
  (define offer-12? (or only-12? (hash-ref opts 'offer-12? #t)))
  (define client-random (random-bytes 32))
  (define policy (hash-ref opts 'suite-policy #f))               ; ssl-set-ciphers!
  (define eff-13 (order-by-policy client-suites policy))
  (define eff-12 (order-by-policy (tls12-suites) policy))
  (when (and policy (null? eff-13) (null? eff-12))
    (raise (tls-error "ssl-set-ciphers!: no supported cipher suite matches the policy")))
  ;; A2: a cached session to re-offer as a PSK (psk_dhe_ke). Offered only when a
  ;; TLS 1.3 handshake is happening (not only-12?) and the box holds a session.
  (define psk-sess (and resume-box (not only-12?) (tls-session? (unbox resume-box)) (unbox resume-box)))
  (define psk-alg (and psk-sess (let-values ([(a _1 _2 _3 _4) (suite-params (tls-session-suite psk-sess))]) a)))
  (define base-suites (cond [only-12? eff-12]
                            [offer-12? (append eff-13 eff-12)]
                            [else eff-13]))
  ;; the resumed suite must be offered first so the negotiated hash matches the
  ;; binder's hash (PSKs are bound to a cipher-suite hash).
  (define all-suites
    (if psk-sess
        (cons (tls-session-suite psk-sess)
              (remove (tls-session-suite psk-sess) base-suites))
        base-suites))
  ;; supported_groups: the ECDHE groups we hold key shares for, then (when a
  ;; 1.2 DHE suite is offered) the RFC 7919 groups, listed last so a 1.3
  ;; server keeps preferring a group with a key share
  (define advertised-groups
    (append groups (if (and offer-12? (ormap tls12-dhe-suite? eff-12)) FFDHE-GROUPS '())))
  (define (build-client-hello key-share-entries [cookie #f])
    (define psk? (and psk-sess (not cookie)))    ; only in the first flight
    (define exts
      (bytes-append
       (ext #x002b (vec 1 (cond [only-12? (u16 #x0303)]
                                [offer-12? (bytes-append (u16 #x0304) (u16 #x0303))]
                                [else (u16 #x0304)]))) ; supported_versions
       (ext #x000a (vec 2 (apply bytes-append (map u16 advertised-groups))))  ; supported_groups
       (ext #x000b (vec 1 (bytes 0)))                          ; ec_point_formats: uncompressed
       ;; status_request (OCSP stapling): status_type=1(ocsp), empty responder/exts
       (if want-ocsp? (ext #x0005 (bytes 1 0 0 0 0)) #"")
       (ext #x000d (vec 2 (apply bytes-append (map u16 sig-schemes)))) ; signature_algorithms
       (ext #x0033 (vec 2 (apply bytes-append key-share-entries)))    ; key_share
       (ext #x0017 #"")                                        ; extended_master_secret
       (ext #xff01 (vec 1 #""))                                ; renegotiation_info (empty)
       (if cookie (ext #x002c (vec 2 cookie)) #"")
       (if host (ext #x0000 (vec 2 (bytes-append (u8 0) (vec 2 (string->bytes/latin-1 host))))) #"")  ; SNI
       (if (pair? alpn)
           (ext #x0010 (vec 2 (apply bytes-append (map (lambda (p) (vec 1 p)) alpn))))
           #"")
       ;; A2 (1.2): SessionTicket (RFC 5077) — offer a cached ticket, or empty to
       ;; signal support. Only when a 1.2 ticket box is provided and 1.2 is offered.
       (if (and ticket12-box offer-12? (not cookie))
           (ext #x0023 (let ([t (unbox ticket12-box)]) (if (and t (bytes? (vector-ref t 0))) (vector-ref t 0) #"")))
           #"")
       ;; psk_key_exchange_modes (psk_dhe_ke) must precede pre_shared_key
       (if psk? (ext #x002d (vec 1 (bytes 1))) #"")))
    (cond
      [psk?
       ;; pre_shared_key MUST be the last extension; the binder is an HMAC over
       ;; the ClientHello truncated just before the binders list (RFC 8446 §4.2.11.2).
       (define hl (digest-size psk-alg))
       (define obf (modulo (+ (inexact->exact (round (- (current-inexact-milliseconds)
                                                        (tls-session-issued-ms psk-sess))))
                              (tls-session-age-add psk-sess))
                           (expt 2 32)))
       (define identities (vec 2 (bytes-append (vec 2 (tls-session-ticket psk-sess)) (u32 obf))))
       (define psk-ext (ext #x0029 (bytes-append identities (vec 2 (vec 1 (make-bytes hl 0))))))
       (define all-exts (bytes-append exts psk-ext))
       (define body (bytes-append (u16 #x0303) client-random (vec 1 session-id)
                                  (vec 2 (apply bytes-append (map u16 all-suites)))
                                  (vec 1 (bytes 0)) (vec 2 all-exts)))
       (define ch0 (bytes-append (u8 1) (u24 (bytes-length body)) body))
       (define trunc (- (bytes-length ch0) (+ 2 1 hl)))   ; binders = u16 len + u8 entry-len + hl
       (define binder (compute-psk-binder psk-alg (tls-session-psk psk-sess)
                                          (digest psk-alg (subbytes ch0 0 trunc))))
       (bytes-append (subbytes ch0 0 (+ trunc 2 1)) binder)]   ; splice binder over the zeros
      [else
       (define body (bytes-append (u16 #x0303) client-random (vec 1 session-id)
                                  (vec 2 (apply bytes-append (map u16 all-suites)))
                                  (vec 1 (bytes 0)) (vec 2 exts)))
       (bytes-append (u8 1) (u24 (bytes-length body)) body)]))

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
     (finish-client-handshake r hs tr sh2 want-group privs verify? verify-hostname? host anchors alpn want-ocsp? client-auth resume-box)]
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
        (finish-client-handshake-with-suite r hs tr sh suite exts grp privs verify? verify-hostname? host anchors alpn want-ocsp? client-auth resume-box)]
       [else
        ;; Server negotiated TLS 1.2. Hand off to the 1.2 continuation with
        ;; the raw transcript (ClientHello || ServerHello) so far.
        ;; RFC 8446 §4.1.3: we offered 1.3 (only-12? is #f); if this 1.2
        ;; ServerHello.random ends in the DOWNGRD sentinel, a 1.3-capable server
        ;; was forced down to 1.2 (a version-downgrade attack) -> abort.
        (when (not only-12?)
          (let ([tail (subbytes sh-random 24 32)])
            (when (or (equal? tail #"\x44\x4f\x57\x4e\x47\x52\x44\x01")
                      (equal? tail #"\x44\x4f\x57\x4e\x47\x52\x44\x00"))
              (raise (tls-error "TLS downgrade attack detected (RFC 8446 §4.1.3 downgrade sentinel)")))))
        (tls12-client-finish (rl-in r) (rl-out r) hs (bytes-append ch1 sh) sh client-random
                             (hash 'host host 'verify? verify? 'verify-hostname? verify-hostname?
                                   'trust-anchors anchors
                                   'keylog (hash-ref opts 'keylog #f)
                                   'client-key (hash-ref opts 'client-key #f)          ; A4 (1.2)
                                   'client-cert-ders (hash-ref opts 'client-cert-ders '())
                                   'ticket12-box ticket12-box))])])))                  ; A2 (1.2) SessionTicket

;; After a (possibly retried) ServerHello whose suite/exts we've parsed.
(define (finish-client-handshake r hs tr sh want-group privs verify? verify-hostname? host anchors alpn want-ocsp? client-auth [resume-box #f])
  (define-values (suite exts) (let ()
    (define sid-len (bytes-ref sh 38))
    (define pos (+ 39 sid-len))
    (values (be->int sh pos (+ pos 2))
            (parse-extensions (let ([el (be->int sh (+ pos 3) (+ pos 5))]) (subbytes sh (+ pos 5) (+ pos 5 el)))))))
  (tr-add! tr sh)   ; SH2 after HelloRetryRequest joins the transcript
  (finish-client-handshake-with-suite r hs tr sh suite exts want-group privs verify? verify-hostname? host anchors alpn want-ocsp? client-auth resume-box))

(define (finish-client-handshake-with-suite r hs tr sh suite exts grp privs verify? verify-hostname? host anchors alpn want-ocsp? client-auth [resume-box #f])
  (define-values (alg aead klen ilen dname) (suite-params suite))
  (unless alg (raise (tls-error "server chose unsupported cipher suite")))
  (tr-set-alg! tr alg)
  ;; server key_share
  (define ks-ext (assoc #x0033 exts))
  (define peer-pub (subbytes (cdr ks-ext) 4))
  (define ecdhe (compute-ecdhe grp (hash-ref privs grp) peer-pub))
  (define k (ks alg aead klen ilen #f #f #f #f #f #f))
  ;; A2: did the server accept our PSK? (pre_shared_key in ServerHello) — if so,
  ;; seed the key schedule with the PSK and expect an abbreviated handshake
  ;; (EncryptedExtensions + Finished, no Certificate/CertificateVerify).
  (define offered-psk (and resume-box (tls-session? (unbox resume-box)) (unbox resume-box)))
  (define resuming? (and offered-psk (assoc #x0029 exts) #t))
  (ks-derive-handshake! k ecdhe (and resuming? (tls-session-psk offered-psk)))
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
  (define peer-staple (box #f))
  (define cert-req-ctx (box #f))            ; A4: set to the request context if the server asks for a client cert
  ;; RFC 8446 §2, §4.4: EncryptedExtensions, then for a certificate-based
  ;; handshake [CertificateRequest] Certificate CertificateVerify, then
  ;; Finished. A PSK resumption goes from EncryptedExtensions straight to
  ;; Finished. The order is enforced, because the server's Finished only
  ;; proves knowledge of the (EC)DHE secret; CertificateVerify is the only
  ;; proof that the server holds the certificate's private key.
  (define (unexpected-msg mt)
    (raise (tls-alert 10 (format "unexpected handshake msg ~a" mt))))
  (let loop ([state 'encrypted-extensions])
    (define-values (mt msg) (hsr-next hs))
    (case mt
      [(8)   ; EncryptedExtensions
       (unless (eq? state 'encrypted-extensions) (unexpected-msg mt))
       (define ee-exts (parse-extensions (subbytes msg 6 (+ 6 (be->int msg 4 6)))))
       (define ap (assoc #x0010 ee-exts))
       (when ap (set-box! selected-alpn (let ([b (cdr ap)]) (subbytes b 3 (+ 3 (bytes-ref b 2))))))
       (tr-add! tr msg)
       (loop (if resuming? 'finished 'certificate-or-request))]
      [(13)  ; CertificateRequest (server wants a client cert) — echo its context
       (unless (eq? state 'certificate-or-request) (unexpected-msg mt))
       (set-box! cert-req-ctx (subbytes msg 5 (+ 5 (bytes-ref msg 4))))
       (tr-add! tr msg)
       (loop 'certificate)]
      [(11)  ; Certificate
       (unless (memq state '(certificate-or-request certificate)) (unexpected-msg mt))
       (set-box! peer-certs (parse-certificate-msg msg))
       (when (null? (unbox peer-certs))
         (raise (tls-alert 50 "empty server Certificate")))
       (set-box! peer-staple (certificate-msg-staple msg))
       (tr-add! tr msg)
       (loop 'certificate-verify)]
      [(15)  ; CertificateVerify
       (unless (eq? state 'certificate-verify) (unexpected-msg mt))
       (define th (tr-hash tr))
       (verify-certificate-verify msg (unbox peer-certs) th)
       (tr-add! tr msg)
       (loop 'finished)]
      [(20)  ; Finished (server)
       (unless (eq? state 'finished) (unexpected-msg mt))
       (define expected (finished-verify-data alg (ks-s-hs k) (tr-hash tr)))
       (define got (subbytes msg 4))
       (unless (ct-equal? expected got) (raise (tls-alert 51 "server Finished mismatch")))
       (tr-add! tr msg)]
      [else (unexpected-msg mt)]))
  ;; chain validation / hostname check per the context's switches. Skipped on
  ;; resumption: a PSK handshake sends no certificate — trust derives from the
  ;; ticket, and the original chain and its verification result are restored
  ;; so the connection still reports the peer identity (ssl-peer-verified? etc.)
  (define verified?
    (cond
      [resuming?
       (set-box! peer-certs (tls-session-peer-certs offered-psk))
       (tls-session-verified? offered-psk)]
      [else (peer-verification-result (unbox peer-certs) anchors host verify? verify-hostname?)]))
  ;; A3: if we asked for OCSP stapling and got a stapled response, verify it and
  ;; abort on a revoked status (soft-fail on a missing/unparseable staple).
  (when (and want-ocsp? (unbox peer-staple) (pair? (unbox peer-certs)))
    (define certs (unbox peer-certs))
    (define issuer (if (pair? (cdr certs)) (cadr certs) (car certs)))
    (when (eq? 'revoked (verify-ocsp-staple (unbox peer-staple) (car certs) issuer (current-seconds)))
      (raise (tls-error "peer certificate revoked (OCSP stapled response)"))))
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
  ;; A4: client authentication — answer the server's CertificateRequest (if any)
  ;; with our client Certificate + CertificateVerify, else an empty Certificate.
  (when (unbox cert-req-ctx)
    (define ctx (unbox cert-req-ctx))
    (cond
      [client-auth
       (define ccerts (car client-auth))
       (define ck (cdr client-auth))
       (define clist (apply bytes-append (for/list ([d (in-list ccerts)]) (bytes-append (vec 3 d) (vec 2 #"")))))
       (define cbody (bytes-append (vec 1 ctx) (vec 3 clist)))
       (define cmsg (bytes-append (u8 11) (u24 (bytes-length cbody)) cbody))
       (tr-add! tr cmsg) (rl-write-record r 22 cmsg)
       (define scheme (server-sig-scheme ck))
       (define cvc (bytes-append (make-bytes 64 #x20) #"TLS 1.3, client CertificateVerify" (bytes 0) (tr-hash tr)))
       (define csig (server-sign ck scheme cvc))
       (define cvbody (bytes-append (u16 scheme) (vec 2 csig)))
       (define cvmsg (bytes-append (u8 15) (u24 (bytes-length cvbody)) cvbody))
       (tr-add! tr cvmsg) (rl-write-record r 22 cvmsg)]
      [else
       (define cbody (bytes-append (vec 1 ctx) (vec 3 #"")))
       (define cmsg (bytes-append (u8 11) (u24 (bytes-length cbody)) cbody))
       (tr-add! tr cmsg) (rl-write-record r 22 cmsg)]))
  ;; middlebox-compat CCS (plaintext) is optional; skip.
  (define cfin (finished-verify-data alg (ks-c-hs k) (tr-hash tr)))
  (define fin-msg (bytes-append (u8 20) (u24 (bytes-length cfin)) cfin))
  (rl-write-record r 22 fin-msg)
  (tr-add! tr fin-msg)   ; A2: resumption_master_secret binds the transcript through client Finished
  ;; A2: resumption master + a 'resume descriptor so the recv loop can turn an
  ;; incoming NewSessionTicket into a cached PSK (only when a session-box is given).
  (define resume
    (and resume-box
         (hash 'alg alg 'suite suite 'alpn (unbox selected-alpn) 'session-box resume-box
               'peer-certs (unbox peer-certs) 'verified? verified?
               'res-master (res-master-secret alg (ks-master k) (tr-hash tr)))))
  ;; install application keys both directions
  (define-values (sapk sapiv) (traffic->keys k (ks-s-ap k)))
  (define-values (capk capiv) (traffic->keys k (ks-c-ap k)))
  (rl-set-read-key! r aead sapk sapiv)
  (rl-finish-handshake! r)
  (rl-set-write-key! r aead capk capiv)
  (tls13-make-conn r (unbox selected-alpn) (unbox peer-certs)
                   (hash 'alg alg 'exporter-master exporter-master
                         'server-cert-der (let ([pc (unbox peer-certs)])
                                            (and (pair? pc) (car pc))))
                   (ku k aead (box (ks-s-ap k)) (box (ks-c-ap k)))  ; recv=server, send=client
                   resume
                   verified?))

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

;; The first (leaf) CertificateEntry's status_request (type 5) extension, whose
;; body is CertificateStatus { status_type=1, OCSPResponse<3> } -> OCSP DER or #f.
(define (certificate-msg-staple msg)
  (define ctx-len (bytes-ref msg 4))
  (define lp (+ 5 ctx-len))
  (define p0 (+ lp 3))                              ; first CertificateEntry
  (define clen (be->int msg p0 (+ p0 3)))
  (define es (+ p0 3 clen))                         ; entry extensions vec2
  (define eend (+ es 2 (be->int msg es (+ es 2))))
  (let loop ([pos (+ es 2)])
    (if (>= pos eend) #f
        (let ([etype (be->int msg pos (+ pos 2))]
              [elen (be->int msg (+ pos 2) (+ pos 4))]
              [d (+ pos 4)])
          (if (and (= etype 5) (>= elen 4) (= 1 (bytes-ref msg d)))
              (let ([olen (be->int msg (+ d 1) (+ d 4))]) (subbytes msg (+ d 4) (+ d 4 olen)))
              (loop (+ d elen)))))))

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
  (define policy (hash-ref opts 'suite-policy #f))               ; ssl-set-ciphers!
  (define (pol-ok? id) (or (not policy) (and (list? policy) (memv id policy) #t)))
  (define suite13 (and client-13? (for/or ([s (in-list ch-suites)] #:when (and (suite-supported? s) (pol-ok? s))) s)))
  (cond
    [(not suite13)
     (define s12 (for/or ([s (in-list ch-suites)]
                          #:when (and (pol-ok? s) (tls12-server-can? s key))) s))
     (unless s12
       ;; RFC 8446 §4.1.1: send a fatal handshake_failure alert so the peer fails
       ;; cleanly instead of blocking on a silent drop.
       (with-handlers ([exn:fail? void]) (rl-write-record r 21 (bytes 2 40)))
       (raise (tls-error "no common cipher suite")))
     (tls12-accept in out hs ch ch-random s12 opts)]
    [else (tls13-accept/13 in out opts r hs ch ch-suites ch-exts ch-random suite13)]))

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

  ;; A2: session resumption. If the client offered a PSK (pre_shared_key +
  ;; psk_key_exchange_modes) whose ticket we issued, and its binder verifies,
  ;; resume: seed the key schedule with the PSK, echo pre_shared_key in
  ;; ServerHello, and skip sending Certificate/CertificateVerify.
  (define resume-psk #f)
  (define resume-sess #f)      ; the resumed session (carries the client's identity)
  (let ([store (hash-ref opts 'ticket-store #f)]
        [psk-body (let ([e (assoc #x0029 ch-exts)]) (and e (cdr e)))]
        [modes (assoc #x002d ch-exts)])
    (when (and store psk-body modes)
      (define id-len (be->int psk-body 0 2))
      (define tlen (be->int psk-body 2 4))
      (define ticket (subbytes psk-body 4 (+ 4 tlen)))
      (define binders-off (+ 2 id-len))
      (define blen (bytes-ref psk-body (+ binders-off 2)))
      (define recv-binder (subbytes psk-body (+ binders-off 3) (+ binders-off 3 blen)))
      (define sess (hash-ref store ticket #f))
      (when (and sess (= (tls-session-suite sess) suite) (= blen (digest-size alg))
                 ;; freshness: within the advertised ticket lifetime (seconds)
                 (< (- (current-inexact-milliseconds) (tls-session-issued-ms sess))
                    (* 1000 (tls-session-lifetime sess))))
        (define trunc (- (bytes-length ch) (+ 2 1 blen)))    ; binders are the trailing bytes
        (define expected (compute-psk-binder alg (tls-session-psk sess)
                                             (digest alg (subbytes ch 0 trunc))))
        (when (ct-equal? expected recv-binder)
          (set! resume-psk (tls-session-psk sess))
          (set! resume-sess sess)
          (hash-remove! store ticket)))))       ; single-use ticket

  ;; our ephemeral share
  (define-values (our-priv our-pub) (gen-server-share chosen))
  (define ecdhe (compute-ecdhe chosen our-priv peer-pub))

  ;; ServerHello (echo pre_shared_key with selected_identity=0 when resuming)
  (define sid-echo (parse-session-id ch))
  (define sh-exts (bytes-append
                   (ext #x002b (u16 #x0304))
                   (ext #x0033 (bytes-append (u16 chosen) (vec 2 our-pub)))
                   (if resume-psk (ext #x0029 (u16 0)) #"")))
  (define sh-body (bytes-append (u16 #x0303) (random-bytes 32)
                                (vec 1 sid-echo)
                                (u16 suite) (u8 0)
                                (vec 2 sh-exts)))
  (define sh (bytes-append (u8 2) (u24 (bytes-length sh-body)) sh-body))
  (tr-add! tr sh)
  (rl-write-record r 22 sh)

  ;; key schedule (PSK-seeded on resumption)
  (define k (ks alg aead klen ilen #f #f #f #f #f #f))
  (ks-derive-handshake! k ecdhe resume-psk)
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

  ;; A4: CertificateRequest (ask the client to authenticate) if configured.
  ;; Skipped on resumption (a PSK handshake omits server/client certificates).
  (define request-client-cert? (and (hash-ref opts 'request-client-cert #f) (not resume-psk)))
  (when request-client-cert?
    (define creq-body (bytes-append (vec 1 #"")   ; empty certificate_request_context
                                    (vec 2 (ext #x000d (vec 2 (apply bytes-append (map u16 sig-schemes)))))))
    (define creq (bytes-append (u8 13) (u24 (bytes-length creq-body)) creq-body))
    (tr-add! tr creq)
    (rl-write-record r 22 creq))

  ;; Certificate + CertificateVerify — omitted entirely on PSK resumption.
  (unless resume-psk
    ;; Certificate (staple an OCSP response on the leaf entry if configured +
    ;; the client asked via status_request)
    (define staple (and (assoc #x0005 ch-exts) (hash-ref opts 'ocsp-staple #f)))
    (define cert-list
      (apply bytes-append
             (for/list ([d (in-list cert-ders)] [i (in-naturals)])
               (bytes-append (vec 3 d)
                             (vec 2 (if (and (= i 0) staple)
                                        (ext #x0005 (bytes-append (bytes 1) (vec 3 staple))) ; CertificateStatus{ocsp}
                                        #""))))))
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
    (rl-write-record r 22 cv))

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
  ;; RFC 8446 §7.2: everything the server writes after its Finished -- an
  ;; alert about the client's flight included -- is protected with the
  ;; server application traffic key, which is what the client reads with.
  (define-values (sapk sapiv) (traffic->keys k (ks-s-ap k)))
  (define-values (capk capiv) (traffic->keys k (ks-c-ap k)))
  (rl-set-write-key! r aead sapk sapiv)

  ;; read client authentication (if requested) + client Finished under client keys
  (rl-set-read-key! r aead ckey civ)
  (define client-certs (box '()))
  (define client-cv (box #f))
  (define client-cv-th (box #f))
  (let loop ([state (if request-client-cert? 'certificate 'finished)])
    (define-values (mt msg) (hsr-next hs))
    (case mt
      [(20)
       (unless (eq? state 'finished) (fatal-alert! r 10 (format "unexpected handshake msg ~a from client" mt)))
       (define expected (finished-verify-data alg (ks-c-hs k) (tr-hash tr)))
       (unless (ct-equal? expected (subbytes msg 4)) (fatal-alert! r 51 "client Finished mismatch"))
       (tr-add! tr msg)]
      [(11)
       (unless (eq? state 'certificate) (fatal-alert! r 10 (format "unexpected handshake msg ~a from client" mt)))
       (set-box! client-certs (parse-certificate-msg msg)) (tr-add! tr msg)
       (loop (if (pair? (unbox client-certs)) 'certificate-verify 'finished))]
      [(15)
       (unless (eq? state 'certificate-verify) (fatal-alert! r 10 (format "unexpected handshake msg ~a from client" mt)))
       (set-box! client-cv msg) (set-box! client-cv-th (tr-hash tr)) (tr-add! tr msg)
       (loop 'finished)]
      [else (fatal-alert! r 10 (format "unexpected handshake msg ~a from client" mt))]))
  ;; The client's identity. A presented certificate must carry a valid
  ;; CertificateVerify and chain to a loaded anchor -- with no anchors
  ;; loaded every certificate is rejected, as with libssl; there is no
  ;; "accept anything" mode. A missing certificate is fatal only when the
  ;; context requires one (ssl-set-verify!); with ssl-try-verify! the
  ;; connection proceeds unauthenticated.
  (define client-verified?
    (cond
      [(pair? (unbox client-certs))
       (with-handlers ([exn:fail? (lambda (e) (fatal-alert! r (verify-failure-alert e) (exn-message e)))])
         (verify-certificate-verify (unbox client-cv) (unbox client-certs) (unbox client-cv-th) 'client)
         (verify-chain (unbox client-certs) (hash-ref opts 'client-ca-anchors '())))
       #t]
      [(hash-ref opts 'require-client-cert #f)
       (fatal-alert! r 116 "client certificate required")]           ; certificate_required
      [else #f]))

  ;; on resumption the client's identity comes from the original session
  (define peer-certs (if resume-sess (tls-session-peer-certs resume-sess) (unbox client-certs)))
  (define peer-verified? (if resume-sess (tls-session-verified? resume-sess) client-verified?))

  ;; install the client's application read key
  (rl-set-read-key! r aead capk capiv)
  (rl-finish-handshake! r)
  ;; A2: issue a NewSessionTicket (RFC 8446 §4.6.1) when a ticket store is
  ;; provided, so the client can resume. resumption_master binds the transcript
  ;; through the client Finished (added above); PSK is derived per-ticket.
  (let ([store (hash-ref opts 'ticket-store #f)])
    (when store
      (define res-master (res-master-secret alg (ks-master k) (tr-hash tr)))
      (define nonce (bytes 0 0 0 0))
      (define psk (psk-from-ticket alg res-master nonce))
      (define ticket (random-bytes 32))
      (define age-add-bytes (random-bytes 4))
      (define lifetime 7200)
      ;; the session carries the client's identity so a resumed connection
      ;; reports it again (a PSK handshake exchanges no certificates)
      (hash-set! store ticket
                 (tls-session psk ticket suite neg-alpn (current-inexact-milliseconds)
                              (be->int age-add-bytes) lifetime peer-certs peer-verified?))
      (define body (bytes-append (u32 lifetime) age-add-bytes (vec 1 nonce)
                                 (vec 2 ticket) (vec 2 #"")))
      (rl-write-record r 22 (bytes-append (u8 4) (u24 (bytes-length body)) body))))
  (tls13-make-conn r neg-alpn peer-certs
                   (hash 'alg alg 'exporter-master exporter-master
                         'server-cert-der (and (pair? cert-ders) (car cert-ders)))
                   (ku k aead (box (ks-c-ap k)) (box (ks-s-ap k)))   ; recv=client, send=server
                   #f
                   peer-verified?)))

;; Send a fatal alert (best effort) and raise it.
(define (fatal-alert! r code msg)
  (with-handlers ([exn:fail? void]) (rl-write-record r 21 (bytes 2 code)))
  (raise (tls-alert code msg)))

;; Alert to send when the peer's certificate fails verification.
(define (verify-failure-alert e)
  (define m (exn-message e))
  (cond
    [(and (exn:tls? e) (exn:tls-alert e)) => values]
    [(regexp-match? #rx"anchor" m) 48]                           ; unknown_ca
    [(regexp-match? #rx"expired|not yet valid" m) 45]            ; certificate_expired
    [(regexp-match? #rx"CertificateVerify" m) 51]                ; decrypt_error
    [else 42]))                                                  ; bad_certificate
(provide fatal-alert! verify-failure-alert)

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
