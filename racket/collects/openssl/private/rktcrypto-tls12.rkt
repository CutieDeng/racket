#lang racket/base

;; TLS 1.2 (RFC 5246 + RFC 5288 GCM + RFC 7905 ChaCha20-Poly1305 + RFC 7627
;; extended master secret) client and server, sharing the record framing,
;; transcript, and byte helpers with the 1.3 engine. Key exchange: ECDHE
;; (X25519 / P-256 / P-384) or finite-field DHE over the RFC 7919 named
;; groups. Cipher suites: AEAD (AES-GCM, ChaCha20-Poly1305) and AES-CBC
;; with HMAC (MAC-then-encrypt, RFC 5246 6.2.3.2). The PRF is HMAC-based
;; (SHA-256 or SHA-384 per suite). All crypto is in rktcrypto C.

(require "rktcrypto-ffi.rkt"
         "rktcrypto-x509.rkt"
         "rktcrypto-verify.rkt"
         "rktcrypto-tls13.rkt")   ; shared record layer, hsr, transcript, helpers

(provide tls12-client-finish
         tls12-accept
         tls12-suites
         tls12-dhe-suite?
         tls12-server-can?)

;; ---- cipher suites (IANA) -> (values kx sig cipher mac key-len prf-alg) ----
;;   kx     : 'ecdhe | 'dhe
;;   sig    : 'rsa | 'ecdsa      (server authentication; also which key type the server needs)
;;   cipher : an AEAD id, or 'aes-cbc
;;   mac    : #f for AEAD, else the HMAC digest id (SHA-1 only for the legacy
;;            *-SHA suites; the PRF of those suites is still SHA-256)
(define (suite12 id)
  (case id
    ;; ECDHE, AEAD
    [(#xC02F) (values 'ecdhe 'rsa   AEAD-AES128-GCM #f 16 SHA256)]        ; ECDHE-RSA-AES128-GCM-SHA256
    [(#xC02B) (values 'ecdhe 'ecdsa AEAD-AES128-GCM #f 16 SHA256)]        ; ECDHE-ECDSA-AES128-GCM-SHA256
    [(#xC030) (values 'ecdhe 'rsa   AEAD-AES256-GCM #f 32 SHA384)]        ; ECDHE-RSA-AES256-GCM-SHA384
    [(#xC02C) (values 'ecdhe 'ecdsa AEAD-AES256-GCM #f 32 SHA384)]        ; ECDHE-ECDSA-AES256-GCM-SHA384
    [(#xCCA8) (values 'ecdhe 'rsa   AEAD-CHACHA20-POLY1305 #f 32 SHA256)] ; ECDHE-RSA-CHACHA20-POLY1305
    [(#xCCA9) (values 'ecdhe 'ecdsa AEAD-CHACHA20-POLY1305 #f 32 SHA256)] ; ECDHE-ECDSA-CHACHA20-POLY1305
    ;; DHE, AEAD
    [(#x009E) (values 'dhe 'rsa AEAD-AES128-GCM #f 16 SHA256)]            ; DHE-RSA-AES128-GCM-SHA256
    [(#x009F) (values 'dhe 'rsa AEAD-AES256-GCM #f 32 SHA384)]            ; DHE-RSA-AES256-GCM-SHA384
    [(#xCCAA) (values 'dhe 'rsa AEAD-CHACHA20-POLY1305 #f 32 SHA256)]     ; DHE-RSA-CHACHA20-POLY1305
    ;; ECDHE, AES-CBC + HMAC
    [(#xC027) (values 'ecdhe 'rsa   'aes-cbc SHA256 16 SHA256)]           ; ECDHE-RSA-AES128-SHA256
    [(#xC028) (values 'ecdhe 'rsa   'aes-cbc SHA384 32 SHA384)]           ; ECDHE-RSA-AES256-SHA384
    [(#xC023) (values 'ecdhe 'ecdsa 'aes-cbc SHA256 16 SHA256)]           ; ECDHE-ECDSA-AES128-SHA256
    [(#xC024) (values 'ecdhe 'ecdsa 'aes-cbc SHA384 32 SHA384)]           ; ECDHE-ECDSA-AES256-SHA384
    [(#xC013) (values 'ecdhe 'rsa   'aes-cbc SHA1   16 SHA256)]           ; ECDHE-RSA-AES128-SHA
    [(#xC014) (values 'ecdhe 'rsa   'aes-cbc SHA1   32 SHA256)]           ; ECDHE-RSA-AES256-SHA
    [(#xC009) (values 'ecdhe 'ecdsa 'aes-cbc SHA1   16 SHA256)]           ; ECDHE-ECDSA-AES128-SHA
    [(#xC00A) (values 'ecdhe 'ecdsa 'aes-cbc SHA1   32 SHA256)]           ; ECDHE-ECDSA-AES256-SHA
    ;; DHE, AES-CBC + HMAC
    [(#x0067) (values 'dhe 'rsa 'aes-cbc SHA256 16 SHA256)]               ; DHE-RSA-AES128-SHA256
    [(#x006B) (values 'dhe 'rsa 'aes-cbc SHA256 32 SHA256)]               ; DHE-RSA-AES256-SHA256
    [(#x0033) (values 'dhe 'rsa 'aes-cbc SHA1   16 SHA256)]               ; DHE-RSA-AES128-SHA
    [(#x0039) (values 'dhe 'rsa 'aes-cbc SHA1   32 SHA256)]               ; DHE-RSA-AES256-SHA
    [else (values #f #f #f #f #f #f)]))
;; Client offer order: ECDHE before DHE, AEAD before CBC (the server auth
;; type is filtered by the cert at runtime). A function so it can be
;; lazy-required from the 1.3 module without a cycle.
(define (tls12-suites)
  (list #xC02B #xC02F #xC02C #xC030 #xCCA9 #xCCA8
        #x009E #x009F #xCCAA
        #xC023 #xC027 #xC024 #xC028 #xC009 #xC013 #xC00A #xC014
        #x0067 #x006B #x0033 #x0039))
;; Does suite `s` use finite-field DHE? (The client then advertises the
;; RFC 7919 groups in supported_groups; without that a libssl server uses
;; its own built-in parameters, which this client refuses.)
(define (tls12-dhe-suite? s)
  (define-values (kx sig cipher mac key-len prf) (suite12 s))
  (eq? kx 'dhe))
;; Can a server holding `key` ((cons 'rsa der) / (cons 'p256 scalar)) serve suite `s`?
(define (tls12-server-can? s key)
  (define-values (kx sig cipher mac key-len prf) (suite12 s))
  (and kx (eq? (car key) (if (eq? sig 'ecdsa) 'p256 'rsa))))

(define GROUP-X25519 #x001d)
(define GROUP-P256   #x0017)
(define GROUP-P384   #x0018)

;; ---- HMAC-based PRF (RFC 5246 sec 5) ----
(define (p-hash alg secret seed out-len)
  ;; A(0)=seed; A(i)=HMAC(secret,A(i-1)); output = HMAC(secret,A(i)||seed)...
  (let loop ([a (hmac alg secret seed)] [acc #""])
    (if (>= (bytes-length acc) out-len)
        (subbytes acc 0 out-len)
        (loop (hmac alg secret a)
              (bytes-append acc (hmac alg secret (bytes-append a seed)))))))
(define (prf alg secret label seed out-len)
  (p-hash alg secret (bytes-append label seed) out-len))

;; =====================================================================
;; 1.2 AEAD record layer
;; =====================================================================
;; keys: client/server write key + fixed IV. GCM uses a 4-byte fixed IV +
;; 8-byte explicit nonce (sent on the wire); ChaCha20 uses a 12-byte fixed
;; IV XORed with the sequence number (RFC 7905), no explicit nonce.
;; cipher: AEAD id or 'aes-cbc; mac: HMAC digest id for CBC suites (else #f),
;; with cmac/smac the client/server MAC keys.
(struct r12 (in out cipher mac etm?
             ckey cfixed skey sfixed cmac smac
             chacha?
             [rseq #:mutable] [wseq #:mutable]
             we-are-client?
             lock                   ; held while a thread reads from `in`
             [pending #:mutable]    ; records read while draining during a write
             [inbuf #:mutable]))    ; partial record pulled in by a draining write

;; Key block (RFC 5246 6.3): client/server MAC keys (CBC suites only), then
;; write keys, then fixed IVs (AEAD only; CBC uses an explicit per-record IV).
(define (make-r12/keys in out cipher mac etm? key-len prf-alg master server-random client-random client?)
  (define chacha? (eqv? cipher AEAD-CHACHA20-POLY1305))
  (define mac-len (if mac (digest-size mac) 0))
  (define fixed-iv-len (cond [(eq? cipher 'aes-cbc) 0] [chacha? 12] [else 4]))
  (define kb (prf prf-alg master #"key expansion" (bytes-append server-random client-random)
                  (+ (* 2 mac-len) (* 2 key-len) (* 2 fixed-iv-len))))
  (define (slice start len) (subbytes kb start (+ start len)))
  (define cmac (slice 0 mac-len))
  (define smac (slice mac-len mac-len))
  (define ckey (slice (* 2 mac-len) key-len))
  (define skey (slice (+ (* 2 mac-len) key-len) key-len))
  (define cfixed (slice (+ (* 2 mac-len) (* 2 key-len)) fixed-iv-len))
  (define sfixed (slice (+ (* 2 mac-len) (* 2 key-len) fixed-iv-len) fixed-iv-len))
  (r12 in out cipher mac (and etm? #t) ckey cfixed skey sfixed cmac smac chacha? 0 0 client? (make-semaphore 1) '() #""))
(define (r12-read-exact! r n)
  (buffered-read-exact! (r12-in r) (lambda () (r12-inbuf r)) (lambda (b) (set-r12-inbuf! r b)) n))
(define (r12-fill-nb! r)
  (fill-record-nb! (r12-in r) (lambda () (r12-inbuf r)) (lambda (b) (set-r12-inbuf! r b))))

(define (seq->bytes n)
  (bytes (bitwise-and (arithmetic-shift n -56) 255) (bitwise-and (arithmetic-shift n -48) 255)
         (bitwise-and (arithmetic-shift n -40) 255) (bitwise-and (arithmetic-shift n -32) 255)
         (bitwise-and (arithmetic-shift n -24) 255) (bitwise-and (arithmetic-shift n -16) 255)
         (bitwise-and (arithmetic-shift n -8) 255) (bitwise-and n 255)))

(define (aad seq type len)
  (bytes-append (seq->bytes seq) (bytes type 3 3)
                (bytes (arithmetic-shift len -8) (bitwise-and len 255))))

(define (xor-iv fixed seq)
  (define n (bytes-copy fixed))       ; 12 bytes
  (define s (seq->bytes seq))
  (for ([i (in-range 8)])
    (bytes-set! n (+ 4 i) (bitwise-xor (bytes-ref n (+ 4 i)) (bytes-ref s i))))
  n)

;; write one record (already the plaintext fragment for `type`)
(define (r12-write r type frag)
  (define seq (r12-wseq r))
  (define key (if (r12-we-are-client? r) (r12-ckey r) (r12-skey r)))
  (define a (aad seq type (bytes-length frag)))
  (define body
    (cond
      [(eq? (r12-cipher r) 'aes-cbc)
       (cbc-seal key (if (r12-we-are-client? r) (r12-cmac r) (r12-smac r)) (r12-mac r) (r12-etm? r) seq type frag)]
      [(r12-chacha? r)
       (define nonce (xor-iv (if (r12-we-are-client? r) (r12-cfixed r) (r12-sfixed r)) seq))
       (aead-seal (r12-cipher r) key nonce a frag)]
      [else
       (define expl (subbytes (seq->bytes seq) 0 8))
       (define nonce (bytes-append (if (r12-we-are-client? r) (r12-cfixed r) (r12-sfixed r)) expl))
       (bytes-append expl (aead-seal (r12-cipher r) key nonce a frag))]))
  (set-r12-wseq! r (add1 seq))
  (define rec (bytes-append (bytes type 3 3)
                            (bytes (arithmetic-shift (bytes-length body) -8) (bitwise-and (bytes-length body) 255))
                            body))
  ;; see `write-draining`: never block on a full transport while the peer
  ;; is sending to us (queue what it sends instead)
  (with-transport-errors
    (write-draining (r12-out r) (r12-in r) rec (r12-lock r)
                    (lambda ()
                      (with-handlers ([(lambda (e) (and (exn:tls? e) (not (exn:tls-alert e)))) (lambda (_) #f)])
                        (case (r12-fill-nb! r)
                          [(record)
                           (define-values (type pt) (r12-read/raw r))
                           (set-r12-pending! r (append (r12-pending r) (list (cons type pt))))
                           #t]
                          [(eof) #f]
                          [else #t]))))))

(define (read-exact in n)
  (define bs (with-transport-errors (read-bytes n in)))
  (when (or (eof-object? bs) (< (bytes-length bs) n)) (raise (tls-error "EOF in 1.2 record")))
  bs)

;; read one record -> (values type plaintext)  (plaintext #f for pass-through CCS)
(define (r12-read r)
  (call-with-semaphore
   (r12-lock r)
   (lambda ()
     (define pending (r12-pending r))
     (cond
       [(pair? pending)
        (set-r12-pending! r (cdr pending))
        (values (caar pending) (cdar pending))]
       [else (r12-read/raw r)]))))

(define (r12-read/raw r)
  (define hdr (r12-read-exact! r 5))
  (define type (bytes-ref hdr 0))
  (define len (+ (* 256 (bytes-ref hdr 3)) (bytes-ref hdr 4)))
  (define body (r12-read-exact! r len))
  (cond
    ;; this layer exists only once both ChangeCipherSpecs have passed, so
    ;; every record is protected; an unprotected one is attacker-writable
    [(= type 20) (raise (tls-alert 10 "unprotected ChangeCipherSpec after keys were installed"))]
    [else
     (define seq (r12-rseq r))
     (define key (if (r12-we-are-client? r) (r12-skey r) (r12-ckey r)))
     (define pt
       (cond
         [(eq? (r12-cipher r) 'aes-cbc)
          (cbc-open key (if (r12-we-are-client? r) (r12-smac r) (r12-cmac r)) (r12-mac r) (r12-etm? r) seq type body)]
         [else
          (define fixed (if (r12-we-are-client? r) (r12-sfixed r) (r12-cfixed r)))
          (define-values (nonce ct)
            (if (r12-chacha? r)
                (values (xor-iv fixed seq) body)
                (values (bytes-append fixed (subbytes body 0 (min 8 (bytes-length body))))
                        (subbytes body (min 8 (bytes-length body))))))
          (define a (aad seq type (- (bytes-length ct) (aead-tag (r12-cipher r)))))
          (aead-open (r12-cipher r) key nonce a ct)]))
     (unless pt (raise (tls-alert 20 "bad_record_mac")))
     (when (> (bytes-length pt) 16384) (raise (tls-alert 22 "record_overflow")))
     (set-r12-rseq! r (add1 seq))
     (values type pt)]))

(define (aead-tag aead) (rktcrypto_aead_tag_size aead))

;; ---- AES-CBC with HMAC ----
;; Two framings, chosen per connection by the encrypt_then_mac extension
;; (RFC 7366), which both our client and server offer/accept:
;;   encrypt-then-MAC: IV(16) || CBC(fragment || padding) || MAC, with
;;     MAC = HMAC(mac_key, seq(8) || type || 0303 || len(IV||ciphertext) || IV || ciphertext).
;;     The MAC covers only public-length data, so verification time does not
;;     depend on the plaintext padding (no Lucky 13 class leak), and padding
;;     is examined only after the MAC verified.
;;   MAC-then-encrypt (RFC 5246 6.2.3.2), for peers without the extension:
;;     IV(16) || CBC(fragment || MAC || padding || padding_length), with
;;     MAC = HMAC(mac_key, seq(8) || type || 0303 || len(fragment) || fragment).
;;     The padding check scans a fixed window of 256 bytes with no
;;     data-dependent branches, and a MAC is always computed; what remains is
;;     the length of the HMAC input (hence its number of compression blocks),
;;     which depends on the secret padding length -- the Lucky 13 signal. It
;;     is not eliminated here (that needs a constant-block-count HMAC over the
;;     hash's internal state); it is only present for peers that do not
;;     negotiate encrypt-then-MAC.
(define (cbc-seal key mac-key mac-alg etm? seq type frag)
  (define iv (random-bytes 16))
  (define (pad bs)                                ; -> bs || padding, a multiple of 16
    (define padlen (- 15 (modulo (bytes-length bs) 16)))     ; 0..15
    (bytes-append bs (make-bytes (add1 padlen) padlen)))
  (define (encrypt padded)
    (define out (make-bytes (bytes-length padded)))
    (rktcrypto_aes_cbc_encrypt key (bytes-length key) iv padded out (bytes-length padded))
    out)
  (cond
    [etm?
     (define ct (bytes-append iv (encrypt (pad frag))))
     (bytes-append ct (hmac mac-alg mac-key (bytes-append (aad seq type (bytes-length ct)) ct)))]
    [else
     (define mac (hmac mac-alg mac-key (bytes-append (aad seq type (bytes-length frag)) frag)))
     (bytes-append iv (encrypt (pad (bytes-append frag mac))))]))

;; -> fragment, or #f when padding or MAC is wrong.
(define (cbc-open key mac-key mac-alg etm? seq type body)
  (define mac-len (digest-size mac-alg))
  (define n (bytes-length body))
  (define (decrypt iv ct)
    (define pt (make-bytes (bytes-length ct)))
    (rktcrypto_aes_cbc_decrypt key (bytes-length key) iv ct pt (bytes-length ct))
    pt)
  ;; padding check without data-dependent control flow: the last byte is the
  ;; padding length; every byte in the last padlen+1 positions must equal it.
  ;; A fixed 256-byte window is scanned (the padding length is at most 255),
  ;; each position masked by whether it lies inside the padding.
  (define (padding-ok? pt)
    (define ptlen (bytes-length pt))
    (define padlen (bytes-ref pt (sub1 ptlen)))
    (define in-range? (<= (+ padlen 1) ptlen))
    (define start (max 0 (- ptlen 256)))
    (define bad
      (for/fold ([bad 0]) ([i (in-range start ptlen)])
        (define inside (if (>= i (- ptlen padlen 1)) #xff 0))           ; mask: in padding
        (bitwise-ior bad (bitwise-and inside (bitwise-xor (bytes-ref pt i) padlen)))))
    (and in-range? (zero? bad) padlen))
  (cond
    [etm?
     (and (>= n (+ 16 16 mac-len))
          (let* ([ct (subbytes body 0 (- n mac-len))]
                 [got-mac (subbytes body (- n mac-len))]
                 [exp-mac (hmac mac-alg mac-key (bytes-append (aad seq type (bytes-length ct)) ct))])
            (and (ct-equal? got-mac exp-mac)
                 (zero? (modulo (bytes-length ct) 16))
                 (let* ([pt (decrypt (subbytes ct 0 16) (subbytes ct 16))]
                        [padlen (padding-ok? pt)])
                   (and padlen (subbytes pt 0 (- (bytes-length pt) padlen 1)))))))]
    [else
     (and (>= n (+ 16 16)) (zero? (modulo n 16))
          (let* ([pt (decrypt (subbytes body 0 16) (subbytes body 16))]
                 [ptlen (bytes-length pt)]
                 [padlen (padding-ok? pt)]
                 [len-ok? (and padlen (<= (+ padlen 1 mac-len) ptlen))]
                 [frag-len (if len-ok? (- ptlen padlen 1 mac-len) (max 0 (- ptlen mac-len)))]
                 [frag (subbytes pt 0 frag-len)]
                 [got-mac (subbytes pt frag-len (+ frag-len mac-len))]
                 [exp-mac (hmac mac-alg mac-key (bytes-append (aad seq type frag-len) frag))]
                 [mac-ok? (ct-equal? got-mac exp-mac)])
            (and len-ok? mac-ok? frag)))]))

;; =====================================================================
;; Client: continue after ServerHello chose TLS 1.2
;; =====================================================================
;; Args: r (record layer from tls13, plaintext), hs (hsr), transcript-bytes
;; (CH||SH already accumulated as raw bytes), sh (ServerHello msg),
;; client-random, server chosen fields, opts.
(define (tls12-client-finish rl-in rl-out hs raw-transcript sh client-random opts)
  (define host (hash-ref opts 'host #f))
  (define verify? (hash-ref opts 'verify? #t))
  (define verify-hostname? (hash-ref opts 'verify-hostname? #f))
  (define anchors (hash-ref opts 'trust-anchors '()))
  ;; parse ServerHello
  (define server-random (subbytes sh 6 38))
  (define sid-len (bytes-ref sh 38))
  (define pos (+ 39 sid-len))
  (define suite (+ (* 256 (bytes-ref sh pos)) (bytes-ref sh (add1 pos))))
  (define exts-em? (sh-has-ext? sh pos #x0017))
  (define etm? (sh-has-ext? sh pos #x0016))          ; encrypt_then_mac (RFC 7366)
  ;; A2 (1.2): resumption is signalled by the server echoing our (non-empty)
  ;; session_id (RFC 5077 §3.4) when we offered a ticket.
  (define ticket12-box (hash-ref opts 'ticket12-box #f))
  (define resuming?
    (and ticket12-box (vector? (unbox ticket12-box))
         (let* ([ch1 (subbytes raw-transcript 0 (- (bytes-length raw-transcript) (bytes-length sh)))]
                [csid (subbytes ch1 39 (+ 39 (bytes-ref ch1 38)))]
                [ssid (subbytes sh 39 (+ 39 sid-len))])
           (and (positive? (bytes-length csid)) (equal? csid ssid)))))
  (cond
   [resuming? (tls12-client-resume rl-in rl-out raw-transcript sh client-random ticket12-box)]
   [else
  (define-values (kx sig-type cipher mac key-len prf-alg) (suite12 suite))
  (unless kx (raise (tls-error "server chose unsupported 1.2 suite")))
  (define tr (box raw-transcript))
  (define (tr+ b) (set-box! tr (bytes-append (unbox tr) b)))

  ;; read Certificate, ServerKeyExchange, [CertificateRequest], ServerHelloDone
  (define peer-ders (box '()))
  (define ske (box #f))
  (define cert-requested? (box #f))
  (let loop ()
    (define-values (mt msg) (hsr-next hs))
    (tr+ msg)
    (case mt
      [(11) (set-box! peer-ders (parse-certificate-msg-12 msg)) (loop)]
      [(12) (set-box! ske msg) (loop)]
      [(13) (set-box! cert-requested? #t) (loop)]   ; CertificateRequest (A4)
      [(14) (void)]                              ; ServerHelloDone
      [else (raise (tls-error (format "unexpected 1.2 msg ~a" mt)))]))

  (when (null? (unbox peer-ders)) (raise (tls-error "server sent no certificate")))
  (define leaf (parse-certificate (car (unbox peer-ders))))

  ;; parse ServerKeyExchange: ECParams or ServerDHParams, then the signature
  ;; over client_random || server_random || params
  (unless (unbox ske) (raise (tls-alert 10 "missing ServerKeyExchange")))
  (define-values (group server-pub params ske-sig-scheme ske-sig) (parse-ske kx (unbox ske)))
  (define signed (bytes-append client-random server-random params))
  (unless (verify-signature-over ske-sig-scheme (certificate-pub leaf) signed ske-sig)
    (raise (tls-alert 51 "ServerKeyExchange signature invalid")))
  ;; chain validation / hostname check per the context's switches (independent)
  (define verified? (peer-verification-result (unbox peer-ders) anchors host verify? verify-hostname?))

  ;; our ephemeral key + premaster secret
  (define-values (our-priv our-pub) (gen-kx group))
  (define pms (kx-secret group our-priv server-pub))

  ;; A4: if the server asked for a client cert and we have one, send Certificate
  ;; before ClientKeyExchange (it precedes CKE in the flight and the transcript).
  (define client-key (hash-ref opts 'client-key #f))
  (define client-cert-ders (hash-ref opts 'client-cert-ders '()))
  (define send-client-cert? (and (unbox cert-requested?) client-key (pair? client-cert-ders)))
  (define ccert
    (and (unbox cert-requested?)
         (let ([b (vec 3 (apply bytes-append (for/list ([d (in-list client-cert-ders)]) (vec 3 d))))])
           (bytes-append (u8 11) (u24 (bytes-length b)) b))))     ; empty list -> empty Certificate
  (when ccert (tr+ ccert))

  ;; ClientKeyExchange (must be in the transcript before the extended-master-
  ;; secret session hash and the Finished hash are taken)
  (define cke-body (if (eq? kx 'dhe) (vec 2 our-pub) (vec 1 our-pub)))   ; dh_Yc<2> / ECPoint<1>
  (define cke (bytes-append (u8 16) (u24 (bytes-length cke-body)) cke-body))
  (tr+ cke)

  ;; master secret (extended master secret if negotiated: session hash covers
  ;; ClientHello..ClientKeyExchange)
  (define master
    (if exts-em?
        (prf prf-alg pms #"extended master secret" (digest prf-alg (unbox tr)) 48)
        (prf prf-alg pms #"master secret" (bytes-append client-random server-random) 48)))

  ;; SSLKEYLOGFILE line so Wireshark can decrypt a 1.2 session (de-facto format):
  ;; CLIENT_RANDOM <client_random> <master_secret>.
  (let ([kl (hash-ref opts 'keylog #f)])
    (when kl
      (define (hx bs) (apply string-append (for/list ([b (in-bytes bs)])
                        (let ([s (number->string b 16)]) (if (= 1 (string-length s)) (string-append "0" s) s)))))
      (kl (string-append "CLIENT_RANDOM " (hx client-random) " " (hx master)))))

  ;; A4: CertificateVerify signs the handshake so far (CH..Certificate..CKE).
  (define ccv
    (and send-client-cert?
         (let* ([scheme (if (eq? (car client-key) 'p256) #x0403 #x0804)]
                [sig (sign-12 client-key scheme (unbox tr))]
                [body (bytes-append (u16 scheme) (vec 2 sig))])
           (bytes-append (u8 15) (u24 (bytes-length body)) body))))
  (when ccv (tr+ ccv))

  ;; send [Certificate], CKE, [CertificateVerify], CCS, then encrypted Finished
  (when ccert (write-plaintext rl-out 22 ccert))
  (write-plaintext rl-out 22 cke)
  (when ccv (write-plaintext rl-out 22 ccv))
  (write-plaintext rl-out 20 (bytes 1))         ; ChangeCipherSpec

  (define r (make-r12/keys rl-in rl-out cipher mac etm? key-len prf-alg master server-random client-random #t))

  ;; client Finished: PRF(master,"client finished",Hash(handshake))[0:12]
  (define cfin-vd (prf prf-alg master #"client finished" (digest prf-alg (unbox tr)) 12))
  (define cfin (bytes-append (u8 20) (u24 12) cfin-vd))
  (tr+ cfin)
  (r12-write r 22 cfin)

  ;; read the server's second flight: an optional NewSessionTicket (plaintext,
  ;; before the server ChangeCipherSpec, and covered by the server Finished
  ;; hash), then CCS, then the encrypted Finished. A2 (1.2): cache the ticket.
  (let loop ()
    (define hdr (read-exact rl-in 5))
    (define rlen (+ (* 256 (bytes-ref hdr 3)) (bytes-ref hdr 4)))
    (define body (read-exact rl-in rlen))
    (cond
      [(= (bytes-ref hdr 0) 20) (void)]                                        ; ChangeCipherSpec
      [(= (bytes-ref hdr 0) 21) (raise (peer-alert body))]                     ; plaintext alert (server pre-CCS)
      [(and (= (bytes-ref hdr 0) 22) (>= (bytes-length body) 1) (= (bytes-ref body 0) 4)) ; NewSessionTicket
       (tr+ body)
       (when ticket12-box
         (let ([tlen (+ (* 256 (bytes-ref body 8)) (bytes-ref body 9))])
           (when (positive? tlen)
             (set-box! ticket12-box (vector (subbytes body 10 (+ 10 tlen)) master suite (and exts-em? #t)
                                            (unbox peer-ders) verified?)))))
       (loop)]
      [else (loop)]))
  (define-values (ftype fmsg) (r12-read-handshake r))
  (unless (= ftype 20) (raise (tls-error "expected server Finished")))
  (define expect-sfin (prf prf-alg master #"server finished" (digest prf-alg (unbox tr)) 12))
  (unless (ct-equal? expect-sfin (subbytes fmsg 4)) (raise (tls-alert 51 "server Finished mismatch")))

  (make-conn-12 r (unbox peer-ders) cfin-vd verified?)]))

;; A2 (1.2): abbreviated (resumption) client handshake. Keys come from the cached
;; master secret; read the server's [NewSessionTicket] + CCS + Finished, then send
;; our CCS + Finished. No Certificate/ServerKeyExchange in either direction.
;; The ticket record #(ticket master suite ems? peer-ders verified?) also carries
;; the originally authenticated server chain and its verification result.
(define (tls12-client-resume rl-in rl-out raw-transcript sh client-random ticket12-box)
  (define server-random (subbytes sh 6 38))
  (define sid-len (bytes-ref sh 38))
  (define etm? (sh-has-ext? sh (+ 39 sid-len) #x0016))   ; RFC 7366: re-signalled on resumption
  (define suite (let ([p (+ 39 sid-len)]) (+ (* 256 (bytes-ref sh p)) (bytes-ref sh (add1 p)))))
  (define-values (kx sig-type cipher mac key-len prf-alg) (suite12 suite))
  (define rec (unbox ticket12-box))            ; #(ticket master suite ems? peer-ders verified?)
  (define master (vector-ref rec 1))
  (define ems? (vector-ref rec 3))
  (define peer-ders (vector-ref rec 4))
  (define verified? (vector-ref rec 5))
  (define tr (box raw-transcript))             ; CH1 || SH
  (define (tr+ b) (set-box! tr (bytes-append (unbox tr) b)))
  (define r (make-r12/keys rl-in rl-out cipher mac etm? key-len prf-alg master server-random client-random #t))
  ;; server flight: optional NewSessionTicket (plaintext) then ChangeCipherSpec
  (let loop ()
    (define hdr (read-exact rl-in 5))
    (define rlen (+ (* 256 (bytes-ref hdr 3)) (bytes-ref hdr 4)))
    (define body (read-exact rl-in rlen))
    (cond
      [(= (bytes-ref hdr 0) 20) (void)]                                        ; ChangeCipherSpec
      [(= (bytes-ref hdr 0) 21) (raise (peer-alert body))]                     ; plaintext alert (server pre-CCS)
      [(and (= (bytes-ref hdr 0) 22) (>= (bytes-length body) 1) (= (bytes-ref body 0) 4)) ; NewSessionTicket
       (tr+ body)
       (let ([tlen (+ (* 256 (bytes-ref body 8)) (bytes-ref body 9))])
         (when (positive? tlen)
           (set-box! ticket12-box (vector (subbytes body 10 (+ 10 tlen)) master suite ems? peer-ders verified?))))
       (loop)]
      [else (loop)]))
  (define-values (ft fmsg) (r12-read-handshake r))     ; encrypted server Finished
  (unless (= ft 20) (raise (tls-error "expected server Finished (resume)")))
  (define expect-sfin (prf prf-alg master #"server finished" (digest prf-alg (unbox tr)) 12))
  (unless (ct-equal? expect-sfin (subbytes fmsg 4)) (raise (tls-alert 51 "server Finished mismatch (resume)")))
  (tr+ fmsg)
  (write-plaintext rl-out 20 (bytes 1))                ; client ChangeCipherSpec
  (define cfin-vd (prf prf-alg master #"client finished" (digest prf-alg (unbox tr)) 12))
  (r12-write r 22 (bytes-append (u8 20) (u24 12) cfin-vd))
  (make-conn-12 r peer-ders cfin-vd verified?))

;; =====================================================================
;; Server (1.2)
;; =====================================================================
;; RFC 8446 §4.1.3 downgrade-protection sentinel a TLS-1.3-capable server writes
;; into the last 8 bytes of ServerHello.random when it negotiates TLS 1.2.
(define DOWNGRADE-12 #"\x44\x4f\x57\x4e\x47\x52\x44\x01")
(define (tls12-accept rl-in rl-out hs ch client-random suite opts)
  (define cert-ders (hash-ref opts 'cert-ders))
  (define key (hash-ref opts 'key))
  (define-values (kx sig-type cipher mac key-len prf-alg) (suite12 suite))
  (unless kx (raise (tls-error "unsupported 1.2 suite (server)")))
  (define ch-exts (client-hello-exts ch))
  (define ems? (assoc #x0017 ch-exts))          ; extended_master_secret ext type = 0x0017
  (define etm? (and (eq? cipher 'aes-cbc) (assoc #x0016 ch-exts) #t))   ; encrypt_then_mac, CBC only
  ;; A2 (1.2) SessionTicket (RFC 5077): a store maps ticket bytes -> a session
  ;; record #(master suite ems? issued-ms). If the client presents a live ticket
  ;; for this suite we do an abbreviated handshake; otherwise, if it signalled
  ;; support (SessionTicket ext present), we issue one after the full handshake.
  (define ticket-store (hash-ref opts 'ticket-store #f))
  (define ticket-ext (assoc #x0023 ch-exts))
  (define presented-ticket (and ticket-ext (positive? (bytes-length (cdr ticket-ext))) (cdr ticket-ext)))
  (define resume-entry
    (and ticket-store presented-ticket
         (let ([e (hash-ref ticket-store presented-ticket #f)])
           (and e (= (vector-ref e 1) suite)
                (eq? (vector-ref e 4) etm?)        ; RFC 7366 3: the framing cannot change on resumption
                (< (- (current-inexact-milliseconds) (vector-ref e 3)) (* 1000 7200)) e))))
  (define tr (box ch))                           ; transcript begins with ClientHello
  (define (tr+ b) (set-box! tr (bytes-append (unbox tr) b)))

  (cond
   [resume-entry
    ;; abbreviated handshake: recover the master secret, skip cert/kx
    (tls12-server-resume rl-in rl-out hs ch client-random suite etm? (vector-ref resume-entry 0))]
   [else
  (define server-random
    (let ([r (random-bytes 32)]) (bytes-copy! r 24 DOWNGRADE-12) r)) ; downgrade sentinel
  ;; ServerHello (1.2)
  (define issue-ticket? (and ticket-store ticket-ext))    ; both sides support tickets
  (define sh-exts (bytes-append
                   (if ems? (ext #x0017 #"") #"")
                   (if etm? (ext #x0016 #"") #"")
                   (if issue-ticket? (ext #x0023 #"") #"")  ; SessionTicket: negotiate (empty in SH)
                   (ext #xff01 (vec 1 #""))))    ; renegotiation_info (empty)
  (define sh-body (bytes-append (u16 #x0303) server-random (vec 1 #"")
                                (u16 suite) (u8 0) (vec 2 sh-exts)))
  (define sh (bytes-append (u8 2) (u24 (bytes-length sh-body)) sh-body))
  (tr+ sh) (write-plaintext rl-out 22 sh)

  ;; Certificate
  (define cert-list (apply bytes-append (for/list ([d (in-list cert-ders)]) (vec 3 d))))
  (define cert-msg (let ([b (vec 3 cert-list)]) (bytes-append (u8 11) (u24 (bytes-length b)) b)))
  (tr+ cert-msg) (write-plaintext rl-out 22 cert-msg)

  ;; ServerKeyExchange: ECDHE with a group from the client's supported_groups,
  ;; or DHE over ffdhe2048 (RFC 7919; what libssl's automatic DH picks for a
  ;; 2048-bit certificate key)
  (define group (if (eq? kx 'dhe) (ffdhe-prime FFDHE2048) (choose-group ch-exts)))
  (define-values (our-priv our-pub) (gen-kx group))
  (define kx-params
    (if (eq? kx 'dhe)
        (bytes-append (vec 2 group) (vec 2 (bytes 2)) (vec 2 our-pub))   ; ServerDHParams
        (bytes-append (u8 3) (u16 group) (vec 1 our-pub))))                           ; ECParams: named_curve
  (define scheme (if (eq? sig-type 'ecdsa) #x0403 #x0804))
  (define signed (bytes-append client-random server-random kx-params))
  (define sig (sign-12 key scheme signed))
  (define ske-body (bytes-append kx-params (u16 scheme) (vec 2 sig)))
  (define ske (bytes-append (u8 12) (u24 (bytes-length ske-body)) ske-body))
  (tr+ ske) (write-plaintext rl-out 22 ske)

  ;; A4: CertificateRequest (ask the client to authenticate) if configured.
  (define request-client-cert? (hash-ref opts 'request-client-cert #f))
  (when request-client-cert?
    (define creq-body (bytes-append (vec 1 (bytes 64 1))                     ; ecdsa_sign, rsa_sign
                                    (vec 2 (bytes #x04 #x03 #x08 #x04 #x04 #x01)) ; sigalgs: ecdsa/rsapss/rsapkcs1-sha256
                                    (vec 2 #"")))                            ; certificate_authorities: empty
    (define creq (bytes-append (u8 13) (u24 (bytes-length creq-body)) creq-body))
    (tr+ creq) (write-plaintext rl-out 22 creq))

  ;; ServerHelloDone
  (define shd (bytes-append (u8 14) (u24 0)))
  (tr+ shd) (write-plaintext rl-out 22 shd)

  ;; read [Certificate], ClientKeyExchange, [CertificateVerify] (all plaintext)
  (define client-ders (box '()))
  (define cv-content (box #f)) (define cv-sig (box #f)) (define cv-scheme (box #f))
  (define cke (box #f))
  (let loop ()
    (define-values (mt msg) (hsr-next hs))
    (case mt
      [(11) (set-box! client-ders (parse-certificate-msg-12 msg)) (tr+ msg) (loop)]
      [(16) (set-box! cke msg) (tr+ msg)]                 ; ClientKeyExchange ends this flight
      [else (raise (tls-error (format "expected Certificate/ClientKeyExchange, got ~a" mt)))]))
  ;; EMS session hash is taken up to and including ClientKeyExchange (RFC 7627).
  (define ems-session-hash (digest prf-alg (unbox tr)))
  (when (pair? (unbox client-ders))                       ; client authenticated -> CertificateVerify
    (set-box! cv-content (bytes-copy (unbox tr)))          ; signed content = CH..CKE (raw)
    (define-values (cvt cvmsg) (hsr-next hs))
    (unless (= cvt 15) (raise (tls-error "expected CertificateVerify")))
    (set-box! cv-scheme (be->int cvmsg 4 6))
    (set-box! cv-sig (subbytes cvmsg 8 (+ 8 (be->int cvmsg 6 8))))
    (tr+ cvmsg))
  (define client-pub
    (if (eq? kx 'dhe)
        (subbytes (unbox cke) 6 (+ 6 (be->int (unbox cke) 4 6)))          ; dh_Yc<2>
        (subbytes (unbox cke) 5 (+ 5 (bytes-ref (unbox cke) 4)))))         ; ECPoint<1>
  (define pms (kx-secret group our-priv client-pub))
  (define master
    (if ems?
        (prf prf-alg pms #"extended master secret" ems-session-hash 48)
        (prf prf-alg pms #"master secret" (bytes-append client-random server-random) 48)))
  ;; The client's identity (same policy as the 1.3 server): a presented
  ;; certificate must carry a valid CertificateVerify and chain to a loaded
  ;; anchor; a missing one is fatal only when the context requires it. The
  ;; server's write side is still plaintext here (its ChangeCipherSpec comes
  ;; later), so alerts go out unprotected.
  (define (fatal-plain! code msg)
    (with-handlers ([exn:fail? void]) (write-plaintext rl-out 21 (bytes 2 code)))
    (raise (tls-alert code msg)))
  (define client-verified?
    (cond
      [(pair? (unbox client-ders))
       (unless request-client-cert? (fatal-plain! 10 "unsolicited client Certificate"))   ; unexpected_message
       (with-handlers ([exn:fail? (lambda (e) (fatal-plain! (verify-failure-alert e) (exn-message e)))])
         (unless (verify-signature-over (unbox cv-scheme) (certificate-pub (parse-certificate (car (unbox client-ders))))
                                        (unbox cv-content) (unbox cv-sig))
           (raise (tls-alert 51 "client CertificateVerify invalid")))
         (verify-chain (unbox client-ders) (hash-ref opts 'client-ca-anchors '())))
       #t]
      [(hash-ref opts 'require-client-cert #f)
       (fatal-plain! 40 "client certificate required")]           ; handshake_failure
      [else #f]))
  (define r (make-r12/keys rl-in rl-out cipher mac etm? key-len prf-alg master server-random client-random #f))

  ;; read client CCS + Finished
  (read-until-ccs rl-in)
  (define-values (cft cfmsg) (r12-read-handshake r))
  (unless (= cft 20) (raise (tls-error "expected client Finished")))
  (define expect-cfin (prf prf-alg master #"client finished" (digest prf-alg (unbox tr)) 12))
  (unless (ct-equal? expect-cfin (subbytes cfmsg 4)) (raise (tls-alert 51 "client Finished mismatch")))
  (define cfin-vd expect-cfin)   ; RFC 5929 tls-unique = client Finished verify_data
  (tr+ cfmsg)

  ;; A2 (1.2): issue a NewSessionTicket (RFC 5077) when the client signalled
  ;; SessionTicket support; it precedes the server ChangeCipherSpec (plaintext)
  ;; and is covered by the server Finished hash.
  (when (and ticket-store ticket-ext)
    (define ticket (random-bytes 48))
    (hash-set! ticket-store ticket (vector master suite (and ems? #t) (current-inexact-milliseconds) etm?))
    (define nst-body (bytes-append (u32 7200) (vec 2 ticket)))
    (define nst (bytes-append (u8 4) (u24 (bytes-length nst-body)) nst-body))
    (tr+ nst)
    (write-plaintext rl-out 22 nst))

  ;; server CCS + Finished
  (write-plaintext rl-out 20 (bytes 1))
  (define sfin-vd (prf prf-alg master #"server finished" (digest prf-alg (unbox tr)) 12))
  (r12-write r 22 (bytes-append (u8 20) (u24 12) sfin-vd))
  (make-conn-12 r (unbox client-ders) cfin-vd client-verified?)]))

;; A2 (1.2): abbreviated (resumption) server handshake — ServerHello + CCS +
;; Finished first, then read the client's CCS + Finished. Keys come from the
;; recovered master secret and the new randoms (no Certificate/ServerKeyExchange).
(define (tls12-server-resume rl-in rl-out hs ch client-random suite etm? master)
  (define-values (kx sig-type cipher mac key-len prf-alg) (suite12 suite))
  (define tr (box ch))
  (define (tr+ b) (set-box! tr (bytes-append (unbox tr) b)))
  (define server-random (let ([r (random-bytes 32)]) (bytes-copy! r 24 DOWNGRADE-12) r))
  (define sid (let ([sl (bytes-ref ch 38)]) (subbytes ch 39 (+ 39 sl)))) ; echo the client's session id
  (define sh-exts (bytes-append (ext #x0023 #"") (if etm? (ext #x0016 #"") #"") (ext #xff01 (vec 1 #""))))
  (define sh-body (bytes-append (u16 #x0303) server-random (vec 1 sid) (u16 suite) (u8 0) (vec 2 sh-exts)))
  (define sh (bytes-append (u8 2) (u24 (bytes-length sh-body)) sh-body))
  (tr+ sh) (write-plaintext rl-out 22 sh)
  (define r (make-r12/keys rl-in rl-out cipher mac etm? key-len prf-alg master server-random client-random #f))
  (write-plaintext rl-out 20 (bytes 1))                       ; server ChangeCipherSpec
  (define sfin-vd (prf prf-alg master #"server finished" (digest prf-alg (unbox tr)) 12))
  (tr+ (bytes-append (u8 20) (u24 12) sfin-vd))               ; server Finished in the transcript
  (r12-write r 22 (bytes-append (u8 20) (u24 12) sfin-vd))
  (read-until-ccs rl-in)
  (define-values (cft cfmsg) (r12-read-handshake r))
  (unless (= cft 20) (raise (tls-error "expected client Finished (resume)")))
  (define expect-cfin (prf prf-alg master #"client finished" (digest prf-alg (unbox tr)) 12))
  (unless (ct-equal? expect-cfin (subbytes cfmsg 4)) (raise (tls-alert 51 "client Finished mismatch (resume)")))
  (make-conn-12 r '() expect-cfin))

;; =====================================================================
;; helpers
;; =====================================================================
(define (write-plaintext out type payload)
  (with-transport-errors
    (write-bytes (bytes-append (bytes type 3 3)
                               (bytes (arithmetic-shift (bytes-length payload) -8) (bitwise-and (bytes-length payload) 255))
                               payload) out)
    (flush-output out)))

;; Read raw records until a ChangeCipherSpec passes (discard it). Handshake
;; records that arrive before are buffered by the caller's hsr already.
(define (read-until-ccs in)
  (let loop ()
    (define hdr (read-exact in 5))
    (define len (+ (* 256 (bytes-ref hdr 3)) (bytes-ref hdr 4)))
    (define body (read-exact in len))
    (unless (= (bytes-ref hdr 0) 20) (loop))))

;; Read one handshake message from the encrypted 1.2 stream.
(define (r12-read-handshake r)
  (let loop ()
    (define-values (type pt) (r12-read r))
    (cond
      [(= type 20) (loop)]
      [(= type 22) (values (bytes-ref pt 0) pt)]
      [(= type 21) (raise (peer-alert pt))]
      [else (loop)])))

(define (parse-certificate-msg-12 msg)
  ;; handshake header(4) certificate_list(vec3 of vec3 cert)
  (define list-len (+ (* 65536 (bytes-ref msg 4)) (* 256 (bytes-ref msg 5)) (bytes-ref msg 6)))
  (let loop ([pos 7] [acc '()])
    (if (>= pos (+ 7 list-len))
        (reverse acc)
        (let ([clen (+ (* 65536 (bytes-ref msg pos)) (* 256 (bytes-ref msg (+ pos 1))) (bytes-ref msg (+ pos 2)))])
          (loop (+ pos 3 clen) (cons (subbytes msg (+ pos 3) (+ pos 3 clen)) acc))))))

;; ServerKeyExchange body starts at msg[4]: the key-exchange parameters --
;; ECParams(curve_type=3, named_curve(2), point<1>) or ServerDHParams(p<2>,
;; g<2>, Ys<2>) -- then SignatureAndHashAlgorithm(2) + signature<2>.
;; -> (values group peer-public params-bytes scheme signature)
(define (parse-ske kx msg)
  (define-values (group pub end)
    (case kx
      [(dhe)
       (define plen (be->int msg 4 6))
       (define p (subbytes msg 6 (+ 6 plen)))
       (define gpos (+ 6 plen))
       (define glen (be->int msg gpos (+ gpos 2)))
       (define g (subbytes msg (+ gpos 2) (+ gpos 2 glen)))
       (define ypos (+ gpos 2 glen))
       (define ylen (be->int msg ypos (+ ypos 2)))
       (define ys (subbytes msg (+ ypos 2) (+ ypos 2 ylen)))
       (values (or (ffdhe-group-of p g)
                   (raise (tls-alert 71 "server DH parameters are not an RFC 7919 group")))  ; insufficient_security
               ys (+ ypos 2 ylen))]
      [else
       (unless (= 3 (bytes-ref msg 4)) (raise (tls-alert 47 "ServerKeyExchange: not a named curve")))
       (define pt-len (bytes-ref msg 7))
       (values (be->int msg 5 7) (subbytes msg 8 (+ 8 pt-len)) (+ 8 pt-len))]))
  (define scheme (be->int msg end (+ end 2)))
  (define sig-len (be->int msg (+ end 2) (+ end 4)))
  (define sig (subbytes msg (+ end 4) (+ end 4 sig-len)))
  (values group pub (subbytes msg 4 end) scheme sig))

(define (sh-has-ext? sh pos want)
  ;; pos points at cipher_suite; after suite(2)+compression(1) come extensions
  (define ep (+ pos 3))
  (and (< ep (bytes-length sh))
       (let ([elen (+ (* 256 (bytes-ref sh ep)) (bytes-ref sh (add1 ep)))])
         (let loop ([p (+ ep 2)] [end (+ ep 2 elen)])
           (and (< p end)
                (let ([t (+ (* 256 (bytes-ref sh p)) (bytes-ref sh (add1 p)))]
                      [l (+ (* 256 (bytes-ref sh (+ p 2))) (bytes-ref sh (+ p 3)))])
                  (or (= t want) (loop (+ p 4 l) end))))))))

(define (client-hello-exts ch)
  (define sid-len (bytes-ref ch 38))
  (define pos (+ 39 sid-len))
  (define cs-len (+ (* 256 (bytes-ref ch pos)) (bytes-ref ch (add1 pos))))
  (set! pos (+ pos 2 cs-len))
  (define comp-len (bytes-ref ch pos))
  (set! pos (+ pos 1 comp-len))
  (if (>= (+ pos 2) (bytes-length ch)) '()
      (let ([elen (+ (* 256 (bytes-ref ch pos)) (bytes-ref ch (add1 pos)))])
        (let loop ([p (+ pos 2)] [end (+ pos 2 elen)] [acc '()])
          (if (>= p end) (reverse acc)
              (let ([t (+ (* 256 (bytes-ref ch p)) (bytes-ref ch (add1 p)))]
                    [l (+ (* 256 (bytes-ref ch (+ p 2))) (bytes-ref ch (+ p 3)))])
                (loop (+ p 4 l) end (cons (cons t (subbytes ch (+ p 4) (+ p 4 l))) acc))))))))

(define (choose-group ch-exts)
  (define sg (assoc #x000a ch-exts))
  (or (and sg
           (let* ([body (cdr sg)]
                  [len (+ (* 256 (bytes-ref body 0)) (bytes-ref body 1))])
             (let loop ([p 2])
               (and (< p (+ 2 len))
                    (let ([g (+ (* 256 (bytes-ref body p)) (bytes-ref body (add1 p)))])
                      (if (memv g (list GROUP-X25519 GROUP-P256 GROUP-P384)) g (loop (+ p 2))))))))
      GROUP-X25519))

;; ---- finite-field DHE over the RFC 7919 named groups ----
;; Group ids are the prime sizes in bits (RKTCRYPTO_FFDHE*); the prime
;; itself is what RFC 7919 appendix A defines, p = 2^b - 2^(b-64) +
;; (floor(2^(b-130) e) + X) * 2^64 - 1, computed once from that formula
;; (the C side holds the same constants and does the arithmetic). A server's
;; parameters are accepted only when they are exactly one of these groups:
;; custom or small primes are refused rather than checked.
;; ---- finite-field DHE ----
;; A DH group is represented by its prime as big-endian bytes (generator 2).
;; Only well-known safe primes are accepted from a peer: the RFC 7919 groups
;; ffdhe2048/3072/4096 and the RFC 3526 MODP groups 14/15/16 (what libssl's
;; automatic DH sends when the client does not advertise named groups).
;; Both families are defined by a formula over a transcendental constant,
;;   RFC 7919: p = 2^b - 2^(b-64) + (floor(2^(b-130) e)  + X) 2^64 - 1
;;   RFC 3526: p = 2^b - 2^(b-64) + (floor(2^(b-130) pi) + X) 2^64 - 1
;; and are computed here once from those formulas (checked byte-for-byte
;; against the constants in rktcrypto_dh.c and OpenSSL's built-in groups).
;; Custom primes are refused rather than tested: the arithmetic in C takes
;; whatever prime it is given, so the whitelist is the whole policy.
(define FFDHE2048 2048)
(define (floor-2^n*x n x-series)
  ;; floor(2^n x) for x given as an exact rational accurate to 2^-(n+100);
  ;; the fractional part is checked to be well away from an integer.
  (define v (* (expt 2 n) (x-series (+ n 100))))
  (define f (floor v))
  (define frac (- v f))
  (unless (< (expt 2 -60) frac (- 1 (expt 2 -60))) (error 'dh-prime "ambiguous floor"))
  f)
(define (e-series bits)                          ; sum 1/k!, tail below 2^-bits
  (let loop ([k 0] [term 1] [acc 0])
    (if (< term (expt 2 (- bits))) acc (loop (add1 k) (/ term (add1 k)) (+ acc term)))))
(define (pi-series bits)                         ; Machin: 16 atan(1/5) - 4 atan(1/239)
  (define (atan-inv x)
    (let loop ([k 0] [acc 0])
      (define term (/ 1 (* (+ (* 2 k) 1) (expt x (+ (* 2 k) 1)))))
      (if (< term (expt 2 (- bits))) acc (loop (add1 k) (if (even? k) (+ acc term) (- acc term))))))
  (- (* 16 (atan-inv 5)) (* 4 (atan-inv 239))))
(define dh-primes (make-hash))                   ; (family . bits) -> prime bytes
(define (dh-prime family bits)
  (hash-ref! dh-primes (cons family bits)
             (lambda ()
               (define-values (series X)
                 (case family
                   [(ffdhe) (values e-series (case bits [(2048) 560316] [(3072) 2625351] [(4096) 5736041]))]
                   [(modp) (values pi-series (case bits [(2048) 124476] [(3072) 1690314] [(4096) 240904]))]))
               (define p (+ (- (expt 2 bits) (expt 2 (- bits 64)))
                            (* (+ (floor-2^n*x (- bits 130) series) X) (expt 2 64))
                            -1))
               (define out (make-bytes (quotient bits 8)))
               (let loop ([i (sub1 (bytes-length out))] [n p])
                 (when (>= i 0) (bytes-set! out i (bitwise-and n 255)) (loop (sub1 i) (arithmetic-shift n -8))))
               out)))
(define (ffdhe-prime bits) (dh-prime 'ffdhe bits))
(define (strip-leading-zeros bs)
  (let loop ([i 0]) (if (and (< i (sub1 (bytes-length bs))) (zero? (bytes-ref bs i))) (loop (add1 i)) (subbytes bs i))))
;; p, g as sent by the server -> the prime (as our group id), or #f
(define (ffdhe-group-of p g)
  (define p* (strip-leading-zeros p))
  (define bits (* 8 (bytes-length p*)))
  (and (memv bits '(2048 3072 4096))
       (equal? (strip-leading-zeros g) (bytes 2))
       (or (equal? p* (dh-prime 'ffdhe bits)) (equal? p* (dh-prime 'modp bits)))
       p*))
;; private exponent size per prime size (RFC 7919 section 5.2; twice the
;; security level, as libssl uses for these groups)
(define (dh-privbits p) (case (bytes-length p) [(256) 225] [(384) 275] [else 325]))

(define (gen-kx group)
  (cond
    [(bytes? group)                               ; a DH prime
     (define priv (make-bytes 64))
     (define pub (make-bytes (bytes-length group)))
     (define-values (ok privlen)
       (rktcrypto_dh_keygen group (bytes-length group) (bytes 2) 1 (dh-privbits group) priv pub))
     (unless (eqv? ok 1) (raise (tls-error "DH keygen failed")))
     (values (subbytes priv 0 privlen) pub)]
    [else
     (case group
       [(#x001d) (let ([priv (random-bytes 32)] [pub (make-bytes 32)])
                   (rktcrypto_x25519 pub priv (bytes-append (bytes 9) (make-bytes 31 0)))
                   (values priv pub))]
       [(#x0017) (let loop () (let ([priv (random-bytes 32)] [pub (make-bytes 65)])
                                (if (eqv? 1 (rktcrypto_p256_pubkey pub priv)) (values priv pub) (loop))))]
       [(#x0018) (let ([priv (random-bytes 48)] [pub (make-bytes 97)])
                   (rktcrypto_p384_pubkey pub priv) (values priv pub))])]))

;; premaster secret from our private key and the peer's public value
(define (kx-secret group priv peer)
  (cond
    [(bytes? group)
     (define out (make-bytes (bytes-length group)))
     (unless (eqv? 1 (rktcrypto_dh_derive group (bytes-length group) priv (bytes-length priv)
                                          peer (bytes-length peer) out))
       (raise (tls-alert 47 "invalid DH public value")))
     ;; RFC 5246 8.1.2: leading zero bytes of Z are stripped
     (strip-leading-zeros out)]
    [else
     (case group
       [(#x001d) (let ([o (make-bytes 32)]) (unless (eqv? 1 (rktcrypto_x25519 o priv peer)) (raise (tls-error "x25519"))) o)]
       [(#x0017) (let ([o (make-bytes 32)]) (unless (eqv? 1 (rktcrypto_p256_ecdh o priv peer)) (raise (tls-error "p256"))) o)]
       [(#x0018) (let ([o (make-bytes 48)]) (unless (eqv? 1 (rktcrypto_p384_ecdh o priv peer)) (raise (tls-error "p384"))) o)])]))

(define (sign-12 key scheme content)
  (case (car key)
    [(rsa) (let* ([kd (cdr key)] [sig (make-bytes 512)]
                  [n (rktcrypto_rsa_sign_msg 1 SHA256 kd (bytes-length kd) content (bytes-length content) sig)])
             (when (zero? n) (raise (tls-error "RSA sign failed"))) (subbytes sig 0 n))]
    [(p256) (let ([sig (make-bytes 64)])
              (unless (eqv? 1 (rktcrypto_p256_ecdsa_sign sig content (bytes-length content) (cdr key)))
                (raise (tls-error "ECDSA sign failed")))
              (raw->der sig 32))]))

(define (raw->der raw fb)
  (define (di b)
    (define v (let s ([i 0]) (if (and (< i (sub1 (bytes-length b))) (zero? (bytes-ref b i))) (s (add1 i)) (subbytes b i))))
    (define v2 (if (>= (bytes-ref v 0) #x80) (bytes-append (bytes 0) v) v))
    (bytes-append (bytes 2 (bytes-length v2)) v2))
  (define r (di (subbytes raw 0 fb))) (define s (di (subbytes raw fb (* 2 fb))))
  (bytes-append (bytes #x30 (+ (bytes-length r) (bytes-length s))) r s))

;; Build a tls-conn from the 1.2 record layer. tls-unique (RFC 5929 §3.1) is the
;; first Finished's verify_data = the client Finished for a full handshake.
(define (make-conn-12 r peer-ders [tls-unique #f] [verified? #f])
  (define (recv)
    (let loop ()
      (with-handlers ([(lambda (e) (and (exn:tls? e) (not (exn:tls-alert e)))) (lambda (_) eof)])
        (define-values (type pt) (r12-read r))
        (cond
          [(and (= type 23) (positive? (bytes-length pt))) pt]
          [(= type 23) (loop)]
          [(= type 21) (alert->eof pt)]
          [(= type 20) (loop)]
          [(= type 22) (loop)]
          [else (loop)]))))
  (define (send bs)
    (let loop ([off 0])
      (when (< off (bytes-length bs))
        (define chunk (min 16384 (- (bytes-length bs) off)))
        (r12-write r 23 (subbytes bs off (+ off chunk)))
        (loop (+ off chunk)))))
  (define (shut) (with-handlers ([exn:fail? void]) (r12-write r 21 (bytes 1 0))))
  (make-tls-conn recv send shut peer-ders 'tls1.2 (and tls-unique (hash 'tls-unique tls-unique)) verified?))
